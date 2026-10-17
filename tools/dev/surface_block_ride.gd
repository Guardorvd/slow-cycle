extends SceneTree
## GEN2-S S2 dev ride: the prototype section (SurfaceBlocks of the cached
## ground stage + the trail config + one SHAPED platform) in the region world
## scene (same bicycle, camera, light, sky), without the region bake. A dev
## path only; the game's own region loading is unchanged.
##
##   godot --path . --script res://tools/dev/surface_block_ride.gd -- --seed=184729 --region=0,0
##     [--config=res://resources/regions/bc1_trail_184729.json] [--blocks=17,21,3,3]
##     [--check]            headless: place the bike on road / trail / platform / grass,
##                          let it settle, report what the wheels touch; quit
##     [--shots=DIR]        save one frame per view (entry, bench, platform, seam, top); quit
##
## Leaving the section (or falling below it) returns the bike to the nearest
## point of the trail (the scene's own recovery).

const WorldScene = preload("res://scenes/region/region_world.tscn")
const Section = preload("res://scripts/world/surface/surface_section.gd")
const Block = preload("res://scripts/world/surface/surface_block.gd")
const Ops = preload("res://scripts/world/surface/surface_ops.gd")
const Streamer = preload("res://scripts/world/surface_block_streamer.gd")

const INTO_TRAIL_M: float = 8.0
const SETTLE_FRAMES: int = 90
const GUARD_MARGIN_M: float = 2.0

var _args: Dictionary = {}
var _scene: Node3D
var _rect: Rect2
var _floor_m: float = 0.0
var _t0: int = 0


func _initialize() -> void:
	_t0 = Time.get_ticks_usec()
	_args = {"seed": 184729, "region": Vector2i.ZERO, "threads": 4, "config": "res://resources/regions/bc1_trail_184729.json",
		"blocks": [17, 21, 3, 3], "check": false, "shots": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_args.seed = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			_args.region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--threads="):
			_args.threads = maxi(1, arg.substr(10).to_int())
		elif arg.begins_with("--config="):
			_args.config = arg.substr(9)
		elif arg.begins_with("--blocks="):
			_args.blocks = Array(arg.substr(9).split(",")).map(func(v: String) -> int: return v.to_int())
		elif arg == "--check":
			_args.check = true
		elif arg.begins_with("--shots="):
			_args.shots = arg.substr(8).replace("\\", "/")
	call_deferred("_run")


func _run() -> void:
	_scene = WorldScene.instantiate()
	_scene.auto_bake = false
	root.add_child(_scene)
	var bike: Node3D = _scene.get_bike()
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	bike.visible = false
	var thread := Thread.new()
	thread.start(func() -> Dictionary: return _prepare())
	while thread.is_alive():
		await process_frame
	var made: Dictionary = thread.wait_to_finish()
	if not made.is_valid:
		print("SURFACE_RIDE_FAIL ", made.reason_code, " ", JSON.stringify(made.get("detail", {})))
		quit(1)
		return
	var prep: Dictionary = made.prep
	var bounds: Dictionary = prep.up.bounds
	var offset := Vector2(bounds.min_x, bounds.min_z)
	var streamer := Streamer.new()
	streamer.name = "SurfaceBlocks"
	_scene.attach_content(streamer)
	streamer.setup(made.blocks, offset, _scene._materials().terrain)
	streamer.add_flora(made.flora, made.ids, offset)
	var lo: Vector2 = made.blocks[0].origin
	_rect = Rect2(lo - offset, Vector2(_args.blocks[2], _args.blocks[3]) * Block.SIZE_M)
	_floor_m = INF
	for b: Dictionary in made.blocks:
		for h: float in b.heights:
			_floor_m = minf(_floor_m, h)
	var trail: Dictionary = prep.trails[0]
	var line: Dictionary = trail.line
	var path := PackedVector3Array()
	for k in range(line.s.size()):
		path.append(Vector3(line.x[k], _height(made.blocks, Vector2(line.x[k], line.z[k]) + offset), line.z[k]))
	_scene.set_recovery_paths([path])
	for _settle in range(2):
		await physics_frame
	var k0: int = _entry_index(trail)
	_scene.spawn_bike(path[k0], Vector3(line.tx[k0], 0.0, line.tz[k0]))
	bike.visible = true
	bike.process_mode = Node.PROCESS_MODE_INHERIT
	var ready_s: float = (Time.get_ticks_usec() - _t0) / 1e6
	print("SURFACE_RIDE_READY ", JSON.stringify({"seconds": snappedf(ready_s, 0.01), "prepare_s": made.timings, "streamer": streamer.stats,
		"spawn": [snappedf(path[k0].x, 0.1), snappedf(path[k0].y, 0.01), snappedf(path[k0].z, 0.1)]}))
	if _args.check:
		await _check(made, path, offset)
		quit(0)
		return
	if not _args.shots.is_empty():
		await _shots(made, path, offset)
		quit(0)
		return
	physics_frame.connect(_guard)


func _prepare() -> Dictionary:
	var t: int = Time.get_ticks_usec()
	var prep: Dictionary = Section.prepare(_args.seed, _args.region, _args.config, _args.threads)
	if not prep.is_valid:
		return prep
	var timings: Dictionary = prep.timings.duplicate()
	var t2: int = Time.get_ticks_usec()
	var ids: Array = Section.block_ids(_args.blocks)
	var blocks: Array = Section.build(prep.ops, ids, _args.threads)
	timings["blocks_s"] = (Time.get_ticks_usec() - t2) / 1e6
	for b: Dictionary in blocks:
		if not b.is_valid:
			return b
	var veg: Dictionary = Section.vegetation(prep.vegetation_planner, blocks, ids, _args.threads)
	timings["vegetation_s"] = veg.candidates_s + veg.place_s
	timings["total_s"] = (Time.get_ticks_usec() - t) / 1e6
	for b: Dictionary in blocks:
		if not b.is_valid:
			return b
	return {"is_valid": true, "prep": prep, "blocks": blocks, "ids": ids, "flora": veg.placed, "timings": timings}


## Out of the section or below its lowest point: back to the trail.
func _guard() -> void:
	var bike: Node3D = _scene.get_bike()
	var p: Vector3 = bike.global_position
	if _rect.grow(-GUARD_MARGIN_M).has_point(Vector2(p.x, p.z)) and p.y > _floor_m - 10.0:
		return
	bike.global_transform = _scene.request_bike_recovery(p)
	bike.velocity = Vector3.ZERO


## Station INTO_TRAIL_M past the trail's first road join (as ride_trail.gd).
static func _entry_index(trail: Dictionary) -> int:
	var line: Dictionary = trail.line
	var s0: float = line.s[clampi(trail.joins[0].leave_index, 0, line.s.size() - 1)]
	return clampi(line.s.bsearch(s0 + INTO_TRAIL_M), 1, line.s.size() - 2)


static func _height(blocks: Array, w: Vector2) -> float:
	for b: Dictionary in blocks:
		if Rect2(b.origin, Vector2(Block.SIZE_M, Block.SIZE_M)).grow(0.001).has_point(w):
			return Block.height_at(b, w.x, w.y)
	return NAN


## Places on road / trail / platform / grass: expected wheel layer bits.
func _places(made: Dictionary, path: PackedVector3Array, offset: Vector2) -> Array:
	var places: Array = []
	var prep: Dictionary = made.prep
	var line: Dictionary = prep.trails[0].line
	var mid: int = line.s.size() / 3
	places.append({"name": "trail", "at": path[mid], "dir": Vector3(line.tx[mid], 0, line.tz[mid]), "layer": Ops.LAYERS[Ops.Cover.TRAIL]})
	var c: Vector2 = prep.site.centre - offset
	places.append({"name": "platform", "at": Vector3(c.x, _height(made.blocks, prep.site.centre), c.y), "dir": Vector3(line.tx[0], 0, line.tz[0]), "layer": Ops.LAYERS[Ops.Cover.TRAIL]})
	# Road: the first sample of a block whose cover is ROAD; grass: 25 m off
	# the trail's middle on the side away from roads (first grass sample).
	for want: int in [Ops.Cover.ROAD, Ops.Cover.GRASS]:
		var found: bool = false
		for b: Dictionary in made.blocks:
			if found:
				break
			for q in range(Block.N * 40, Block.N * Block.N - Block.N * 40, 31):
				var i: int = q % Block.N
				if i < 40 or i > Block.N - 40 or b.material[q] != want:
					continue
				var ok: bool = true
				for d in [-4, 4, -4 * Block.N, 4 * Block.N]:
					ok = ok and b.material[q + d] == want
				if not ok:
					continue
				var w: Vector2 = b.origin + Vector2(i, q / Block.N) * Block.STEP_M - offset
				places.append({"name": "road" if want == Ops.Cover.ROAD else "grass", "at": Vector3(w.x, b.heights[q], w.y), "dir": Vector3(1, 0, 0), "layer": Ops.LAYERS[want]})
				found = true
				break
	return places


func _check(made: Dictionary, path: PackedVector3Array, offset: Vector2) -> void:
	var bike: BicycleController = _scene.get_bike()
	var all_ok: bool = true
	for place: Dictionary in _places(made, path, offset):
		_scene.spawn_bike(place.at, place.dir)
		for _f in range(SETTLE_FRAMES):
			await physics_frame
		var layers: Array = []
		for ray: RayCast3D in [bike.front_ray, bike.rear_ray]:
			var col: Object = ray.get_collider() if ray != null and ray.is_colliding() else null
			layers.append(col.collision_layer if col is CollisionObject3D else -1)
		var drift: float = Vector2(bike.global_position.x - place.at.x, bike.global_position.z - place.at.z).length()
		var height_gap: float = bike.global_position.y - place.at.y
		var ok: bool = layers[0] == place.layer and layers[1] == place.layer and drift < 1.0 and height_gap > -0.2 and height_gap < 1.0
		all_ok = all_ok and ok
		print("SURFACE_RIDE_CHECK ", JSON.stringify({"place": place.name, "verdict": "PASS" if ok else "FAIL", "expected_layer": place.layer, "wheel_layers": layers,
			"drift_m": snappedf(drift, 0.01), "height_above_ground_m": snappedf(height_gap, 0.01), "on_grass": bike.is_on_grass,
			"rough_weight": snappedf(bike.surface_rough_weight, 0.01)}))
	# The bike is live, not frozen: pedal 3 s along the trail from its entry.
	var line: Dictionary = made.prep.trails[0].line
	var k0: int = _entry_index(made.prep.trails[0])
	_scene.spawn_bike(path[k0], Vector3(line.tx[k0], 0.0, line.tz[k0]))
	for _f in range(SETTLE_FRAMES):
		await physics_frame
	var start: Vector3 = bike.global_position
	Input.action_press("pedal")
	for _f in range(180):
		await physics_frame
	Input.action_release("pedal")
	var moved: float = Vector2(bike.global_position.x - start.x, bike.global_position.z - start.z).length()
	var on_layers: Array = [bike.front_ray, bike.rear_ray].map(func(r: RayCast3D) -> int: return r.get_collider().collision_layer if r.is_colliding() and r.get_collider() is CollisionObject3D else -1)
	print("SURFACE_RIDE_CHECK ", JSON.stringify({"place": "pedal_3s", "moved_m": snappedf(moved, 0.01), "wheel_layers": on_layers, "verdict": "PASS" if moved > 2.0 else "FAIL"}))
	all_ok = all_ok and moved > 2.0
	var names: Array = _places(made, path, offset).map(func(p: Dictionary) -> String: return p.name)
	all_ok = all_ok and names.size() == 4
	print("SURFACE_RIDE_CHECKS ", "PASS" if all_ok else "FAIL", " places=", names)


## One frame per view: bike placed at the view point (its camera), and a top view.
func _shots(made: Dictionary, path: PackedVector3Array, offset: Vector2) -> void:
	DirAccess.make_dir_recursive_absolute(_args.shots)
	var prep: Dictionary = made.prep
	var line: Dictionary = prep.trails[0].line
	var views: Array = []
	views.append({"name": "1_entry", "k": _entry_index(prep.trails[0])})
	for op: Dictionary in prep.trails[0].get("operations", []):
		if op.kind == "BENCH":
			views.append({"name": "2_bench", "k": clampi(line.s.bsearch((op.s0_m + op.s1_m) * 0.5), 1, line.s.size() - 2)})
	views.append({"name": "3_platform", "k": clampi(line.s.bsearch(prep.site.s_m - 10.0), 1, line.s.size() - 2)})
	for k in range(1, line.s.size()):
		var a := Vector2i(floori(line.x[k - 1] / Block.SIZE_M), floori(line.z[k - 1] / Block.SIZE_M))
		var b := Vector2i(floori(line.x[k] / Block.SIZE_M), floori(line.z[k] / Block.SIZE_M))
		if a != b:
			views.append({"name": "4_seam", "k": clampi(k - 6, 1, line.s.size() - 2)})
			break
	var bike: Node3D = _scene.get_bike()
	for v: Dictionary in views:
		_scene.spawn_bike(path[v.k], Vector3(line.tx[v.k], 0.0, line.tz[v.k]))
		for _f in range(60):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(_args.shots.path_join(v.name + ".png"))
		print("SURFACE_RIDE_SHOT ", v.name, " bike=", bike.global_position)
	var cam := Camera3D.new()
	_scene.add_child(cam)
	var centre: Vector2 = _rect.get_center()
	var h: float = _height(made.blocks, centre + offset)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3(0, -1, 0.35).normalized(), Vector3(0, 0, -1)), Vector3(centre.x, h + 260.0, centre.y - 90.0))
	cam.far = 2000.0
	cam.make_current()
	for _f in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_args.shots.path_join("5_top.png"))
	print("SURFACE_RIDE_SHOT 5_top")
