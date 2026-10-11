class_name RegionWorld
extends Node3D

## PR1 runtime composition root of one procedural region scene (Mountain
## River Valley). Composes the environment, the existing bicycle, HUD and
## fader with region content owned elsewhere: by default it loads (or bakes on
## a worker thread, then caches) the RegionBake products and hands them to a
## RegionStreamer; a test harness may instead attach its own content
## (auto_bake = false). Owns: the recorded session seed, the loading overlay,
## spawn placement, the duck-typed `request_bike_recovery(pos) -> Transform3D`
## used by BicycleController, recovery from deep water (no riding under water
## deeper than a ford) and the descent-preferred direction markers. Owns no
## generation math and never writes bicycle motion other than the recovery
## transform the controller itself requests.
##   --seed=N (int64; default: random, logged)   --region=X,Z (default 0,0)
##   --bake-threads=N (default 8)

const Bake = preload("res://scripts/world/region/region_bake.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Streamer = preload("res://scripts/world/region_streamer.gd")
const RoadShader = preload("res://assets/shaders/region_road.gdshader")
const SPAWN_CLEARANCE_M: float = 0.45
const RECOVERY_BACKOFF_M: float = 20.0
const FORD_DEPTH_M: float = 0.35

@export var bike_path: NodePath = NodePath("Bicycle")
@export var auto_bake: bool = true

var session_seed: int = 0
var region := Vector2i.ZERO
var products: Dictionary = {}
var streamer: Node3D
var load_seconds: float = 0.0
var source: String = ""
var _recovery_paths: Array = []
var _recovery_recommended: Array = []
var _content: Node3D
var _thread: Thread
var _mutex := Mutex.new()
var _progress := {"stage": "", "fraction": 0.0}
var _overlay: CanvasLayer
var _label: Label
var _t0: int = 0
var _water_segments: Array = []
var _water_grid: Dictionary = {}
var _ready_to_ride: bool = false
var _water_cooldown_ms: int = 0
var water_recoveries: int = 0


func get_bike() -> BicycleController:
	return get_node_or_null(bike_path) as BicycleController


func is_ready_to_ride() -> bool:
	return _ready_to_ride


func _ready() -> void:
	if not auto_bake:
		_ready_to_ride = true
		return
	var bike: BicycleController = get_bike()
	if bike != null:
		bike.process_mode = Node.PROCESS_MODE_DISABLED
		bike.visible = false
	var threads: int = 8
	session_seed = 0
	var seeded: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			session_seed = arg.substr(7).to_int()
			seeded = true
		elif arg.begins_with("--region="):
			var parts: PackedStringArray = arg.substr(9).split(",")
			if parts.size() == 2:
				region = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--bake-threads="):
			threads = maxi(1, arg.substr(15).to_int())
	if not seeded:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		session_seed = (int(rng.randi()) << 31) ^ int(rng.randi())
	print("REGION_SESSION seed=%d region=%d,%d" % [session_seed, region.x, region.y])
	_build_overlay()
	_t0 = Time.get_ticks_usec()
	var key: String = Cache.key(session_seed, region, {})
	var cached: Dictionary = Cache.load_products(key)
	if cached.is_valid:
		source = "cache"
		_finish_load(cached)
		return
	source = "bake"
	_set_progress("bake", 0.0)
	_thread = Thread.new()
	_thread.start(_bake_job.bind(key, threads))


func _bake_job(key: String, threads: int) -> void:
	var baked: Dictionary = Bake.bake(session_seed, region, {"threads": threads}, _set_progress)
	if baked.is_valid:
		_set_progress("cache_write", 0.99)
		Cache.save(key, baked)
	_mutex.lock()
	_progress["result"] = baked
	_mutex.unlock()


func _set_progress(stage: String, fraction: float) -> void:
	_mutex.lock()
	_progress.stage = stage
	_progress.fraction = fraction
	_mutex.unlock()


func _process(_delta: float) -> void:
	if _thread == null:
		return
	_mutex.lock()
	var stage: String = _progress.stage
	var fraction: float = _progress.fraction
	var result: Variant = _progress.get("result")
	_mutex.unlock()
	if _label != null:
		_label.text = "Mountain River Valley\nseed %d  region %d,%d\n%s  %d%%  (%.0f s)" % [session_seed, region.x, region.y, stage, int(fraction * 100.0), (Time.get_ticks_usec() - _t0) / 1e6]
	if result == null:
		return
	_thread.wait_to_finish()
	_thread = null
	if not result.is_valid:
		push_error("REGION_BAKE_FAILED %s" % result.reason_code)
		if _label != null:
			_label.text = "Region bake failed: %s" % result.reason_code
		return
	_finish_load(result)


func _finish_load(baked: Dictionary) -> void:
	products = baked
	var materials: Dictionary = _materials()
	streamer = Streamer.new()
	streamer.name = "RegionStreamer"
	streamer.setup(baked, materials)
	add_child(streamer)
	_index_water(baked.water)
	_set_recovery_from_network(baked.network.get_data())
	_build_direction_markers(baked.network.get_data())
	var bike: BicycleController = get_bike()
	var spawn: Dictionary = baked.spawn
	if bike != null and not spawn.is_empty():
		streamer.ensure_around(spawn.position)
		spawn_bike(spawn.position, spawn.direction)
		streamer.tracked = bike
		bike.visible = true
		bike.process_mode = Node.PROCESS_MODE_INHERIT
	load_seconds = (Time.get_ticks_usec() - _t0) / 1e6
	print("REGION_READY source=%s seconds=%.3f seed=%d network_m=%.0f" % [source, load_seconds, session_seed, baked.network.get_metrics().component_length_m])
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	_ready_to_ride = true


func _materials() -> Dictionary:
	var terrain := ShaderMaterial.new()
	terrain.shader = RoadShader
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.17, 0.36, 0.42, 0.72)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08
	water.metallic_specular = 0.6
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bridge := StandardMaterial3D.new()
	bridge.albedo_color = Color(0.43, 0.31, 0.20)
	bridge.roughness = 0.9
	return {"terrain": terrain, "water": water, "bridge": bridge}


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	var back := ColorRect.new()
	back.color = Color(0.08, 0.11, 0.10, 1.0)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(back)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 26)
	_label.text = "Mountain River Valley"
	_overlay.add_child(_label)
	add_child(_overlay)


## Region content (render, collision, water ...) is owned by the caller's
## node; this root only parents it (test harness path).
func attach_content(content: Node3D) -> void:
	if _content != null and is_instance_valid(_content):
		_content.queue_free()
	_content = content
	add_child(content)


## World-space riding polylines (PackedVector3Array, ground heights) used for
## recovery: nearest point, stepped back along the path, facing along it.
## `recommended` (optional, per path): +1 forward only, -1 backward only, 0 both.
func set_recovery_paths(paths: Array, recommended: Array = []) -> void:
	_recovery_paths = paths.duplicate()
	_recovery_recommended = recommended.duplicate()


func _set_recovery_from_network(data: Dictionary) -> void:
	var paths: Array = []
	var recommended: Array = []
	for piece: Dictionary in data.pieces:
		var d: Dictionary = piece.design
		var line := PackedVector3Array()
		for k in range(d.s.size()):
			line.append(Vector3(d.x[k], d.y[k], d.z[k]))
		paths.append(line)
		recommended.append(int(piece.info.get("recommended", 0)))
	set_recovery_paths(paths, recommended)


## Places the bicycle on ground point `ground` facing horizontal `direction`.
func spawn_bike(ground: Vector3, direction: Vector3) -> void:
	var bike: BicycleController = get_bike()
	if bike == null:
		return
	# The root stays at the world origin, so local equals world before entry.
	if bike.is_inside_tree():
		bike.global_transform = _pose(ground, direction)
	else:
		bike.transform = _pose(ground, direction)
	bike.velocity = Vector3.ZERO


static func _pose(ground: Vector3, direction: Vector3) -> Transform3D:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 1e-8:
		flat = Vector3.FORWARD
	return Transform3D(Basis.looking_at(flat.normalized(), Vector3.UP), ground + Vector3(0.0, SPAWN_CLEARANCE_M, 0.0))


func request_bike_recovery(query: Vector3) -> Transform3D:
	var best: float = INF
	var best_path: PackedVector3Array
	var best_i: int = -1
	var best_rec: int = 0
	for p in range(_recovery_paths.size()):
		var path: PackedVector3Array = _recovery_paths[p]
		for i in range(path.size()):
			var d: float = Vector2(path[i].x - query.x, path[i].z - query.z).length_squared()
			if d < best:
				best = d
				best_path = path
				best_i = i
				best_rec = _recovery_recommended[p] if p < _recovery_recommended.size() else 0
	if best_i < 0:
		return Transform3D(Basis.IDENTITY, query + Vector3(0.0, 2.0, 0.0))
	# Travel direction along the path: the recommended one on descent-preferred
	# pieces, else the rider's own heading (public transform); step back
	# against it and face along it.
	var travel: int = best_rec
	if travel == 0:
		travel = 1
		var bike: BicycleController = get_bike()
		if bike != null and bike.is_inside_tree() and best_path.size() > 1:
			var a: int = clampi(best_i, 0, best_path.size() - 2)
			var tangent: Vector3 = best_path[a + 1] - best_path[a]
			var forward: Vector3 = -bike.global_transform.basis.z
			travel = 1 if forward.x * tangent.x + forward.z * tangent.z >= 0.0 else -1
	var step: int = -travel
	var i: int = best_i
	var travelled: float = 0.0
	while i + step >= 0 and i + step < best_path.size() and travelled < RECOVERY_BACKOFF_M:
		travelled += best_path[i].distance_to(best_path[i + step])
		i += step
	var j: int = clampi(i - step, 0, best_path.size() - 1)
	var direction: Vector3 = best_path[j] - best_path[i] if j != i else Vector3.FORWARD
	if streamer != null:
		streamer.ensure_around(best_path[i])
	return _pose(best_path[i], direction)


# --- Deep water: recovery instead of riding under water deeper than a ford ---

func _index_water(water: Dictionary) -> void:
	_water_segments.clear()
	_water_grid.clear()
	for ribbon: Dictionary in water.ribbons:
		var v: PackedVector3Array = ribbon.vertices
		for k in range(0, v.size() - 2, 2):
			var a: Vector3 = (v[k] + v[k + 1]) * 0.5
			var b: Vector3 = (v[k + 2] + v[k + 3]) * 0.5
			var half: float = maxf(v[k].distance_to(v[k + 1]), v[k + 2].distance_to(v[k + 3])) * 0.5
			_add_water([a, b, half, false])
	for lake: Dictionary in water.lakes:
		var v: PackedVector3Array = lake.vertices
		for k in range(0, v.size(), 4):
			_add_water([(v[k] + v[k + 3]) * 0.5, (v[k] + v[k + 3]) * 0.5, 16.0, true])


func _add_water(segment: Array) -> void:
	var index: int = _water_segments.size()
	_water_segments.append(segment)
	var lo: Vector3 = Vector3(minf(segment[0].x, segment[1].x), 0.0, minf(segment[0].z, segment[1].z)) - Vector3(segment[2], 0.0, segment[2])
	var hi: Vector3 = Vector3(maxf(segment[0].x, segment[1].x), 0.0, maxf(segment[0].z, segment[1].z)) + Vector3(segment[2], 0.0, segment[2])
	for j in range(int(floor(lo.z / 32.0)), int(floor(hi.z / 32.0)) + 1):
		for i in range(int(floor(lo.x / 32.0)), int(floor(hi.x / 32.0)) + 1):
			var cell := Vector2i(i, j)
			if not _water_grid.has(cell):
				_water_grid[cell] = []
			_water_grid[cell].append(index)


## Water surface above `p` (NAN when dry).
func water_surface_at(p: Vector3) -> float:
	var surface: float = NAN
	for index: int in _water_grid.get(Vector2i(int(floor(p.x / 32.0)), int(floor(p.z / 32.0))), []):
		var s: Array = _water_segments[index]
		var a := Vector2(s[0].x, s[0].z)
		var b := Vector2(s[1].x, s[1].z)
		var q := Vector2(p.x, p.z)
		var inside: bool
		var t: float = 0.0
		if s[3]:
			inside = absf(q.x - a.x) <= 16.0 and absf(q.y - a.y) <= 16.0
		else:
			var ab: Vector2 = b - a
			t = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
			inside = (a + ab * t).distance_to(q) <= s[2]
		if inside:
			var y: float = lerpf(s[0].y, s[1].y, t)
			surface = y if is_nan(surface) else maxf(surface, y)
	return surface


func _physics_process(_delta: float) -> void:
	if not _ready_to_ride or _water_segments.is_empty():
		return
	var bike: BicycleController = get_bike()
	if bike == null or not bike.is_inside_tree():
		return
	var now: int = Time.get_ticks_msec()
	if now < _water_cooldown_ms:
		return
	var surface: float = water_surface_at(bike.global_position)
	# A ford's riding plane lies up to the ford depth below the water: only
	# off the road (no Road-layer collider under a wheel) is it deep water.
	if not is_nan(surface) and bike.global_position.y < surface - FORD_DEPTH_M and not _on_road(bike):
		# The controller's own recovery path (fade + request_bike_recovery).
		water_recoveries += 1
		_water_cooldown_ms = now + 2500
		Input.action_press("recover_ride")
		_release_recover.call_deferred()


static func _on_road(bike: BicycleController) -> bool:
	for ray: RayCast3D in [bike.front_ray, bike.rear_ray]:
		if ray != null and ray.is_colliding():
			var collider: Object = ray.get_collider()
			if collider is CollisionObject3D and (collider.collision_layer & 2) != 0:
				return true
	return false


func _release_recover() -> void:
	await get_tree().process_frame
	Input.action_release("recover_ride")


# --- Descent-preferred direction (Director condition 2) ---

## Small arrow posts at both ends of every descent-preferred piece, pointing
## along its recommended direction (render only).
func _build_direction_markers(data: Dictionary) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.86, 0.55, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.4, 0.22, 0.05)
	for piece: Dictionary in data.pieces:
		var rec: int = int(piece.info.get("recommended", 0))
		if rec == 0:
			continue
		var d: Dictionary = piece.design
		var n: int = d.s.size()
		for end in [0, n - 1]:
			var k: int = clampi(end + (6 if end == 0 else -6), 0, n - 1)
			var forward := Vector3(d.tx[k], 0.0, d.tz[k]) * rec
			var side := Vector3(-d.tz[k], 0.0, d.tx[k])
			var offset: float = d.width[k] * 0.5 + 0.9
			var base: Vector3 = Vector3(d.x[k], d.y[k], d.z[k]) + side * offset
			var post := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.05
			cylinder.bottom_radius = 0.05
			cylinder.height = 1.2
			post.mesh = cylinder
			post.material_override = material
			post.position = base + Vector3(0.0, 0.6, 0.0)
			add_child(post)
			var arrow := MeshInstance3D.new()
			var prism := PrismMesh.new()
			prism.size = Vector3(0.45, 0.55, 0.08)
			arrow.mesh = prism
			arrow.material_override = material
			arrow.position = base + Vector3(0.0, 1.35, 0.0)
			arrow.basis = Basis.looking_at(Vector3.UP, forward.normalized()) if forward.length_squared() > 0.0 else Basis.IDENTITY
			add_child(arrow)
