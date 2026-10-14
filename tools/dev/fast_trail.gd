extends SceneTree
## BC2 dev fast path (T3; never a production path): trails on the cached
## prototype-off products of a region, without the R5/R6 network and the full
## tile build. Runs the RegionBake steps that follow the network (_trails with
## a BC1 or procedural configuration, bridges, vegetation of the changed tiles
## and their neighbours, spawn); water from the cache. Writes nothing to the
## cache: products of this path are not a bake and never answer a key.
##   --seed=S --region=X,Z --config=res://... [--off-key=K] [--plan-only]
##   [--map=ABS.png [--window=x0,z0,size_m] [--contour=M]] [--out=ABS.json]
## --off-key: the off products to start from (default: the key of the current
## source closure). They are verified before use: a prototype-off bake (no
## trails, no dev marker) of the same seed and region whose region and
## hydrology signatures equal the ones computed now; the network and tiles of
## an older key are taken as they are (only for code that does not reach
## them - the caller's responsibility, printed as FAST_OFF_KEY).
## --plan-only: the planner alone (procedural configuration), no publication.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Bridges = preload("res://scripts/world/region/bridge_deck_builder.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Planner = preload("res://scripts/world/region/trail_network_planner.gd")

var _contour: float = 10.0


func _initialize() -> void:
	var seed_value: int = 184729
	var region := Vector2i.ZERO
	var off_key: String = ""
	var config_path: String = ""
	var plan_only: bool = false
	var map_path: String = ""
	var out_path: String = ""
	var window: Array = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--off-key="):
			off_key = arg.substr(10)
		elif arg.begins_with("--config="):
			config_path = arg.substr(9)
		elif arg == "--plan-only":
			plan_only = true
		elif arg.begins_with("--map="):
			map_path = arg.substr(6)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
		elif arg.begins_with("--contour="):
			_contour = arg.substr(10).to_float()
		elif arg.begins_with("--window="):
			var p: PackedStringArray = arg.substr(9).split(",")
			window = [float(p[0]), float(p[1]), float(p[2])]
	var current: String = Cache.key(seed_value, region, {})
	if off_key.is_empty():
		off_key = current
	var t0: int = Time.get_ticks_usec()
	var loaded: Dictionary = Cache.load_products(off_key)
	if not loaded.is_valid:
		print("FAST_FAIL no off cache ", off_key)
		quit(1)
		return
	var load_s: float = (Time.get_ticks_usec() - t0) / 1e6
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	var made: Dictionary = Synth.off_main_thread(func() -> Dictionary: return _work(seed_value, region, loaded, config, plan_only))
	if not made.is_valid:
		print("FAST_FAIL ", made.reason_code)
		quit(1)
		return
	made.timings["load_off_s"] = load_s
	made.timings["total_s"] = (Time.get_ticks_usec() - t0) / 1e6
	print("FAST_OFF_KEY ", JSON.stringify({"key": off_key, "current_closure": off_key == current, "upstream_verified": true}))
	var summary := {"timings": made.timings, "trails": made.report}
	if not plan_only:
		summary.merge({"tiles_digest": made.manifest.tiles_digest, "network_digest": made.manifest.network_digest, "vegetation_digest": made.manifest.vegetation.digest})
	print("FAST_TRAIL ", JSON.stringify(summary))
	if not out_path.is_empty():
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"summary": summary, "trails": made.trails}, "\t"))
		f.close()
	if not map_path.is_empty():
		_map(map_path, window, made, loaded)
	quit(0)


func _work(seed_value: int, region: Vector2i, loaded: Dictionary, config: Variant, plan_only: bool) -> Dictionary:
	var timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	var manifest: Dictionary = loaded.manifest
	if manifest.has("trails") or manifest.get("dev_fast_path", false) or int(manifest.seed) != seed_value or Vector2i(int(manifest.region[0]), int(manifest.region[1])) != region:
		return {"is_valid": false, "reason_code": "ERR_OFF_KEY_NOT_OFF"}
	if manifest.region_signature != plan.signature() or manifest.hydrology_signature != hydro.plan.signature():
		return {"is_valid": false, "reason_code": "ERR_OFF_KEY_UPSTREAM"}
	var field: RefCounted = HField.create(hydro.plan, terrain).field
	var surface: RefCounted = Surface.create(terrain, field, Deformer.create(loaded.network, field).deformer).surface
	var bounds: Dictionary = terrain.get_bounds_m()
	timings["upstream_surface_s"] = (Time.get_ticks_usec() - t) / 1e6
	t = Time.get_ticks_usec()
	if plan_only:
		var parsed: Dictionary = TrailPolicy.parse(config)
		if not parsed.is_valid:
			return {"is_valid": false, "reason_code": parsed.reason_code}
		var context := {"seed": seed_value, "region": region, "network": loaded.network.get_data(), "surface": surface, "field": field, "slots": loaded.tiles,
			"ground": Surface.published_ground(loaded.tiles, bounds, TrailPolicy.GROUND_CELL_M, 8)}
		timings["ground_s"] = (Time.get_ticks_usec() - t) / 1e6
		t = Time.get_ticks_usec()
		var planned: Dictionary = Planner.plan(parsed.config, context)
		timings["planner_s"] = (Time.get_ticks_usec() - t) / 1e6
		return {"is_valid": true, "report": {"planner": planned.report, "rejected": planned.rejected}, "trails": planned.trails, "timings": timings, "network": loaded.network,
			"bounds": bounds}
	var made: Dictionary = Bake._trails(config, seed_value, region, loaded.network, surface, field, bounds, loaded.tiles, 8)
	timings["trails_s"] = (Time.get_ticks_usec() - t) / 1e6
	t = Time.get_ticks_usec()
	var data: Dictionary = made.network.get_data()
	var ground := func(x: float, z: float) -> float:
		var h: Dictionary = made.surface.sample_height(x + bounds.min_x, z + bounds.min_z)
		return h.height_m if h.is_valid else NAN
	var bridges: Dictionary = Bridges.build(data, ground)
	var flora: Dictionary = Vegetation.create(plan, terrain, hydro.plan, made.surface)
	# Only tiles whose arrays changed and their 8 neighbours are planned again.
	var vegetation: Array = loaded.vegetation.duplicate()
	var near: Dictionary = {}
	for k in range(made.slots.size()):
		if made.slots[k] != loaded.tiles[k]:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					near[Vector2i(made.slots[k].tx + dx, made.slots[k].tz + dz)] = true
	var redo: Array = []
	for k in range(made.slots.size()):
		if near.has(Vector2i(made.slots[k].tx, made.slots[k].tz)):
			redo.append(k)
	var job := func(i: int) -> void:
		vegetation[redo[i]] = flora.planner.tile(made.slots[redo[i]].tx, made.slots[redo[i]].tz)
	if not redo.is_empty():
		var group: int = WorkerThreadPool.add_group_task(job, redo.size(), 8, true, "fast_trail_vegetation")
		WorkerThreadPool.wait_for_group_task_completion(group)
	timings["vegetation_tiles"] = redo.size()
	timings["bridges_vegetation_s"] = (Time.get_ticks_usec() - t) / 1e6
	var out_manifest: Dictionary = {"tiles_digest": Bake._tiles_digest(made.slots), "network_digest": made.network.digest(), "vegetation": Bake._vegetation_summary(vegetation),
		"dev_fast_path": true}
	return {"is_valid": true, "report": made.report, "trails": made.network.get_trails(), "manifest": out_manifest, "timings": timings, "network": made.network, "bounds": bounds}


## Top-down map: published ground hillshade with slope classes, roads, nodes
## and every trail (published: yellow; proposals of --plan-only: orange).
func _map(path: String, window: Array, made: Dictionary, loaded: Dictionary) -> void:
	var bounds: Dictionary = made.bounds
	if window.is_empty():
		window = [0.0, 0.0, bounds.max_x - bounds.min_x]
	var px: int = 1024
	var step: float = window[2] / px
	var ground: Dictionary = Surface.published_ground(loaded.tiles, bounds, 2.0, 8)
	var image := Image.create(px, px, false, Image.FORMAT_RGB8)
	for j in range(px):
		for i in range(px):
			var x: float = window[0] + (i + 0.5) * step
			var z: float = window[1] + (j + 0.5) * step
			var h: float = Surface.ground_height(ground, x, z)
			var hx: float = Surface.ground_height(ground, x + step, z) - Surface.ground_height(ground, x - step, z)
			var hz: float = Surface.ground_height(ground, x, z + step) - Surface.ground_height(ground, x, z - step)
			if is_nan(h) or is_nan(hx) or is_nan(hz):
				image.set_pixel(i, j, Color(0, 0, 0))
				continue
			var grade: float = Vector2(hx, hz).length() / (2.0 * step)
			var c: Color = Color(0.35, 0.65, 0.3) if grade < 0.06 else (Color(0.65, 0.75, 0.3) if grade < 0.10 else (Color(0.85, 0.7, 0.3) if grade < 0.15 else (Color(0.8, 0.45, 0.25) if grade < 0.25 else Color(0.55, 0.3, 0.3))))
			c = c * clampf(0.75 + 0.5 * (-hx - hz) / (2.0 * step), 0.4, 1.0)
			if int(floor(h / _contour)) != int(floor(Surface.ground_height(ground, x + step, z) / _contour)) or int(floor(h / _contour)) != int(floor(Surface.ground_height(ground, x, z + step) / _contour)):
				c = c.darkened(0.35)
			image.set_pixel(i, j, c)
	var data: Dictionary = loaded.network.get_data()
	var dot := func(p: Vector2, r: int, c: Color) -> void:
		var ci: int = int((p.x - window[0]) / step)
		var cj: int = int((p.y - window[1]) / step)
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if ci + di >= 0 and cj + dj >= 0 and ci + di < px and cj + dj < px and di * di + dj * dj <= r * r:
					image.set_pixel(ci + di, cj + dj, c)
	for piece: Dictionary in data.pieces:
		var d: Dictionary = piece.design
		for k in range(0, d.s.size(), 2):
			dot.call(Vector2(d.x[k], d.z[k]), 1, Color(0.95, 0.95, 0.9))
	for trail: Dictionary in made.trails:
		var line: Dictionary = trail.line
		var colour: Color = Color(1.0, 0.85, 0.1) if made.has("manifest") else Color(1.0, 0.5, 0.1)
		for k in range(line.s.size()):
			dot.call(Vector2(line.x[k], line.z[k]), 1, colour)
	for node: Dictionary in data.nodes:
		dot.call(Vector2(node.x_m, node.z_m), 4, Color(1, 0, 0) if node.kind == "JUNCTION" else Color(0, 1, 1))
	dot.call(Vector2(loaded.spawn.position.x, loaded.spawn.position.z), 5, Color(0.1, 0.9, 1.0))
	image.save_png(path)
	print("FAST_MAP ", path)
