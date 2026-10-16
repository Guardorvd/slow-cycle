extends SceneTree
## Dev profiling probe (no products): loads the stored ground / trail stages
## of a region (RegionStageCache; run tools/dev/dev_bake.gd first) and times,
## on one thread, the parts of the finish stage and of the tile build:
## per-tile tile_arrays + finish_slot, per-tile vegetation, and a breakdown
## of the vegetation queries over a sample of tiles.
##   --seed=S --region=X,Z [--tiles=k,k,...] [--what=veg,tiles,breakdown]
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Stage = preload("res://scripts/world/region_stage_cache.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")


func _initialize() -> void:
	var seed_value: int = 184729
	var region := Vector2i.ZERO
	var picks: Array = []
	var what: String = "veg,tiles,breakdown"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--tiles="):
			picks = Array(arg.substr(8).split(",")).map(func(s: String) -> int: return s.to_int())
		elif arg.begins_with("--what="):
			what = arg.substr(7)
	Synth.off_main_thread(func() -> Dictionary: return _work(seed_value, region, picks, what))
	quit(0)


func _work(seed_value: int, region: Vector2i, picks: Array, what: String) -> Dictionary:
	var t: int = Time.get_ticks_usec()
	var up: Dictionary = Ground.upstream(seed_value, region)
	print("PROFILE upstream_s ", _lap(t))
	var options := {"max_replans": Builder.MAX_REPLANS}
	var gkey: Dictionary = Stage.ground_key(seed_value, region, options)
	var config_path := "res://resources/regions/trail_network.json"
	var tkey: Dictionary = Stage.trails_key(gkey.key, Cache.trail_settings(config_path))
	t = Time.get_ticks_usec()
	var ground: Dictionary = Stage.load_ground(gkey.key, seed_value, region, up)
	print("PROFILE ground_load_s ", _lap(t), " ", ground.reason_code)
	if not ground.is_valid:
		return {}
	t = Time.get_ticks_usec()
	var trailed: Dictionary = Stage.load_trails(tkey.key, gkey.key, ground)
	print("PROFILE trails_load_s ", _lap(t), " ", trailed.get("reason_code", ""))
	if picks.is_empty():
		picks = range(64)
	if "tiles" in what:
		var piece_class: Dictionary = Ground.piece_classes(ground.network.get_data())
		var rows: Array = []
		for k: int in picks:
			var slot: Dictionary = {"tx": ground.slots[k].tx, "tz": ground.slots[k].tz}
			t = Time.get_ticks_usec()
			var tile: Dictionary = Renderer.tile_arrays(ground.surface, slot.tx, slot.tz)
			var arrays_s: float = _lap(t)
			t = Time.get_ticks_usec()
			Ground.finish_slot(ground.surface, up.bounds, piece_class, slot, tile, [])
			rows.append([k, snappedf(arrays_s, 0.01), snappedf(_lap(t), 0.01), slot.get("triangle_count", 0), slot.get("sha256", "") == ground.slots[k].sha256])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] + a[2] > b[1] + b[2])
		var total: float = 0.0
		for r: Array in rows:
			total += r[1] + r[2]
		print("PROFILE tiles total_cpu_s ", total, " heaviest [k, arrays_s, finish_s, triangles, same] ", JSON.stringify(rows.slice(0, 12)))
	if "veg" in what and trailed.get("is_valid", false):
		var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, trailed.surface)
		var rows: Array = []
		var total: float = 0.0
		for k: int in picks:
			t = Time.get_ticks_usec()
			flora.planner.tile(trailed.slots[k].tx, trailed.slots[k].tz)
			var s: float = _lap(t)
			total += s
			rows.append([k, snappedf(s, 0.01)])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
		print("PROFILE veg total_cpu_s ", total, " heaviest ", JSON.stringify(rows.slice(0, 8)), " lightest ", JSON.stringify(rows.slice(rows.size() - 4)))
	if "breakdown" in what and trailed.get("is_valid", false):
		var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, trailed.surface)
		var planner: RefCounted = flora.planner
		var surface: RefCounted = trailed.surface
		var ctx: RefCounted = planner._context
		var biome: RefCounted = planner._biome
		var hydro_surface: RefCounted = ctx._surface
		var times: Dictionary = {}
		var n: int = 0
		for k: int in picks.slice(0, 4):
			var x0: float = trailed.slots[k].tx * 512
			var z0: float = trailed.slots[k].tz * 512
			for cj in range(64):
				for ci in range(64):
					var x: float = x0 + ci * 8.0 + 3.0
					var z: float = z0 + cj * 8.0 + 3.0
					n += 1
					t = Time.get_ticks_usec()
					var signals: Dictionary = ctx.sample_signals(x, z)
					times["signals"] = times.get("signals", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					hydro_surface.sample_height(x, z)
					times["signals.height"] = times.get("signals.height", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					hydro_surface.sample_gradient(x, z)
					times["signals.gradient"] = times.get("signals.gradient", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					ctx._hydro.sample_proximity_bounded(x, z, 160.0)
					times["signals.proximity"] = times.get("signals.proximity", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					ctx._hydro.sample_water(x, z)
					times["signals.water"] = times.get("signals.water", 0.0) + _lap(t)
					if signals.is_valid:
						t = Time.get_ticks_usec()
						biome.evaluate_signals(signals)
						times["biome"] = times.get("biome", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					planner._road_clear(x, z, 3.5)
					times["road_clear"] = times.get("road_clear", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					planner._trail_clear(x, z, 1.2)
					times["trail_clear"] = times.get("trail_clear", 0.0) + _lap(t)
					t = Time.get_ticks_usec()
					surface.sample_height(x, z)
					times["final_height"] = times.get("final_height", 0.0) + _lap(t)
		for key: String in times:
			times[key] = snappedf(times[key] * 1e6 / n, 0.1)
		print("PROFILE veg_breakdown_us_per_cell ", JSON.stringify(times), " cells ", n)
	return {}


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
