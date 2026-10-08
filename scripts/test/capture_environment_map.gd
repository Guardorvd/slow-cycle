extends SceneTree

## Headless diagnostics, not E5. Full-region samples are a 16 m lattice;
## PNG enlargement is presentation only. Closeups/transects query real points.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Preview = preload("res://scripts/world/region_preview.gd")
const PANELS := ["blended", "dominant", "conifer", "meadow", "riparian", "autumn", "moisture", "woody_cover", "cost", "classes", "slope", "water", "valley", "reasons"]
const CLASS_COLORS := [Color(0.25, 0.75, 0.4), Color(0.75, 0.85, 0.35), Color(0.90, 0.48, 0.16), Color(0.65, 0.08, 0.18)]


static func parse_options(args: PackedStringArray, vulkan: bool = false) -> Dictionary:
	var result := {"is_valid": true, "reason_code": "", "seeds": [184729, 42, 77777], "region": Vector2i.ZERO, "sweep": 0, "benchmark": false, "out": "", "environment": "biome", "provenance": ""}
	var seen: Dictionary = {}
	for arg: String in args:
		var key: String = arg.split("=")[0]
		if seen.has(key):
			return {"is_valid": false, "reason_code": "ERR_ENV_CLI_DUPLICATE"}
		seen[key] = true
		if arg.begins_with("--seeds=") or arg.begins_with("--seed="):
			var text: String = arg.substr(8 if key == "--seeds" else 7)
			result.seeds = []
			for part: String in text.split(","):
				var parsed: Dictionary = Preview.parse_integer(part, 64)
				if not parsed.is_valid:
					return {"is_valid": false, "reason_code": "ERR_ENV_CLI_SEED"}
				result.seeds.append(parsed.value)
			if result.seeds.size() > 12 or (vulkan and result.seeds.size() != 1):
				return {"is_valid": false, "reason_code": "ERR_ENV_CLI_SEED"}
		elif arg.begins_with("--region="):
			var parts: PackedStringArray = arg.substr(9).split(",")
			if parts.size() != 2:
				return {"is_valid": false, "reason_code": "ERR_ENV_CLI_REGION"}
			var x: Dictionary = Preview.parse_integer(parts[0], 32)
			var z: Dictionary = Preview.parse_integer(parts[1], 32)
			if not x.is_valid or not z.is_valid:
				return {"is_valid": false, "reason_code": "ERR_ENV_CLI_REGION"}
			result.region = Vector2i(x.value, z.value)
		elif arg == "--sweep=64" and not vulkan:
			result.sweep = 64
		elif arg == "--benchmark" and not vulkan:
			result.benchmark = true
		elif arg.begins_with("--out="):
			result.out = arg.substr(6).replace("\\", "/").simplify_path()
		elif arg.begins_with("--provenance="):
			result.provenance = arg.substr(13).replace("\\", "/").simplify_path()
		elif arg.begins_with("--environment=") and vulkan:
			result.environment = arg.substr(14)
			if result.environment not in ["biome", "rideability"]:
				return {"is_valid": false, "reason_code": "ERR_ENV_CLI_MODE"}
		else:
			return {"is_valid": false, "reason_code": "ERR_ENV_CLI_ARGUMENT"}
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if result.out.is_empty() or not result.out.is_absolute_path() or result.out.to_lower() == project or result.out.to_lower().begins_with(project + "/"):
		return {"is_valid": false, "reason_code": "ERR_ENV_CLI_OUTPUT"}
	if (result.sweep > 0 and (seen.has("--seeds") or seen.has("--seed") or seen.has("--region") or result.benchmark)) or (seen.has("--seeds") and seen.has("--seed")):
		return {"is_valid": false, "reason_code": "ERR_ENV_CLI_MODE"}
	if vulkan and not seen.has("--seed"):
		return {"is_valid": false, "reason_code": "ERR_ENV_CLI_SEED"}
	if not result.provenance.is_empty() and (not result.provenance.is_absolute_path() or not FileAccess.file_exists(result.provenance)):
		return {"is_valid": false, "reason_code": "ERR_ENV_CLI_PROVENANCE"}
	return result


static func _sources(path: String, result: Dictionary) -> void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".gd") or file.ends_with(".uid") or file.ends_with(".tscn") or file.ends_with(".godot"):
			result[path.path_join(file)] = FileAccess.get_sha256(path.path_join(file))
	for directory: String in DirAccess.get_directories_at(path):
		if directory not in [".git", ".godot", "scratch", "tools", "assets", "screenshots"]:
			_sources(path.path_join(directory), result)


static func source_identity(options: Dictionary) -> Dictionary:
	var sources: Dictionary = {}
	_sources("res://scripts", sources)
	_sources("res://scenes", sources)
	sources["res://project.godot"] = FileAccess.get_sha256("res://project.godot")
	var result := {"sources": sources, "source_manifest_sha256": JSON.stringify(sources).sha256_text(), "engine_version": Engine.get_version_info(), "os": OS.get_name()}
	if not options.provenance.is_empty():
		result["external_provenance"] = JSON.parse_string(FileAccess.get_file_as_string(options.provenance))
		result["external_provenance_sha256"] = FileAccess.get_sha256(options.provenance)
	return result


static func build(seed_value: int, region: Vector2i) -> Dictionary:
	var start: int = Time.get_ticks_usec()
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var terrain_setup_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	var hydro: Dictionary = HGen.build(plan, terrain)
	if not hydro.is_valid:
		return hydro
	var hydrology_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	var context: Dictionary = Context.create(plan, terrain, hydro.plan)
	if not context.is_valid:
		return context
	var context_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	start = Time.get_ticks_usec()
	var biome: Dictionary = Biome.create(context.context)
	if not biome.is_valid:
		return biome
	var pocket_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var ride: Dictionary = Ride.create(context.context, biome.field)
	return {"is_valid": ride.is_valid, "reason_code": ride.reason_code, "region_plan": plan, "terrain": terrain, "hydrology": hydro.plan, "context": context.context, "biome": biome.field, "rideability": ride.field, "terrain_setup_ms": terrain_setup_ms, "hydrology_ms": hydrology_ms, "context_ms": context_ms, "pocket_ms": pocket_ms}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var options: Dictionary = parse_options(OS.get_cmdline_user_args())
	if not options.is_valid:
		push_error("ENV_MAP_FAIL " + options.reason_code)
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(options.out) != OK:
		push_error("ENV_MAP_FAIL ERR_ENV_CLI_OUTPUT")
		quit(1)
		return
	var identity: Dictionary = source_identity(options)
	_write_json(options.out.path_join("source_identity.json"), identity)
	var records: Array = []
	var seeds: Array = options.seeds
	if options.sweep > 0:
		seeds = []
		for k in range(64):
			seeds.append(1000003 + 7919 * k)
	for index in range(seeds.size()):
		var region: Vector2i = [Vector2i.ZERO, Vector2i(-1, -1), Vector2i(3, -2), Vector2i(1, 2)][index % 4] if options.sweep > 0 else options.region
		var built: Dictionary = build(seeds[index], region)
		if not built.is_valid:
			push_error("ENV_MAP_FAIL " + built.reason_code)
			quit(1)
			return
		var record: Dictionary = _map(built, options.out, seeds[index], region, options.sweep > 0 or options.benchmark)
		record["hydrology_ms"] = built.hydrology_ms
		record["context_ms"] = built.context_ms
		record["pocket_ms"] = built.pocket_ms
		record["source_manifest_sha256"] = identity.source_manifest_sha256
		records.append(record)
		print("ENV_MAP_RECORD " + JSON.stringify(record))
		if options.benchmark:
			_benchmark(built, options.out, seeds[index], region)
	_write_json(options.out.path_join("records.json"), records)
	print("ENV_MAP_SUMMARY completed=true regions=%d failures=0 sweep=%d" % [records.size(), options.sweep])
	quit(0)


static func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value, "  "))


static func color(panel: String, point: Dictionary) -> Color:
	var bio: Dictionary = point.biome
	var ride: Dictionary = point.rideability
	var s: Dictionary = point.signals
	match panel:
		"blended": return Biome.blend_color(bio)
		"dominant": return Biome.COLORS[bio.dominant]
		"cost": return Color(0.20, 0.70, 0.35).lerp(Color(0.92, 0.40, 0.15), clampf((ride.cost - 1.0) / 8.0, 0.0, 1.0)) if not ride.blocked else Color(0.65, 0.08, 0.18)
		"classes": return CLASS_COLORS[ride["class"]]
		"water": return Biome.COLORS[4] if bio.is_water else Color(0.92, 0.92, 0.86)
		"reasons": return Color(0.10, 0.35, 0.85) if (ride.reason_flags & Ride.Reason.DEEP_WATER) != 0 else (Color(0.72, 0.08, 0.18) if (ride.reason_flags & Ride.Reason.EXCESSIVE_SLOPE) != 0 else Color(0.65 if (ride.reason_flags & Ride.Reason.DENSE_COVER) != 0 else 0.15, 0.65 if (ride.reason_flags & Ride.Reason.WET_GROUND) != 0 else 0.15, 0.15))
	var value: float = 0.0
	match panel:
		"conifer": value = bio.weights[0]
		"meadow": value = bio.weights[1]
		"riparian": value = bio.weights[2]
		"autumn": value = bio.weights[3]
		"moisture": value = bio.moisture
		"woody_cover": value = bio.woody_cover
		"slope": value = clampf(ride.slope_grade, 0.0, 1.0)
		"valley": value = s.valley_floor_weight
	return Color(0.08, 0.10, 0.16).lerp(Color(0.95, 0.85, 0.30), value)


func _map(built: Dictionary, out: String, seed_value: int, region: Vector2i, coarse: bool) -> Dictionary:
	var bounds: Dictionary = built.context.get_bounds_m()
	var start: int = Time.get_ticks_usec()
	var block: Dictionary
	if coarse:
		# Coarse holdout through real point queries (64 m spacing).
		block = {"points": []}
		for j in range(65):
			for i in range(65):
				block.points.append(built.rideability.sample_combined(bounds.min_x + i * 64.0, bounds.min_z + j * 64.0))
	else:
		block = built.rideability.sample_combined_lattice(bounds.min_x / 16, bounds.min_z / 16, 257, 257)
	var query_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var side: int = 65 if coarse else 257
	var points: Array = []
	var means := PackedFloat64Array([0, 0, 0, 0])
	var dominant: Array = [0, 0, 0, 0, 0]
	var classes: Array = [0, 0, 0, 0]
	var cost_min: float = INF
	var cost_max: float = 0
	var construction_start: int = Time.get_ticks_usec()
	for k in range(side * side):
		var point: Dictionary
		if coarse:
			point = block.points[k]
		else:
			point = {"biome": {"weights": block.biome.weights.slice(k * 4, k * 4 + 4), "dominant": block.biome.dominant[k], "is_water": bool(block.biome.is_water[k]), "moisture": block.biome.moisture[k], "woody_cover": block.biome.woody_cover[k]}, "rideability": {}, "signals": block.signals[k]}
			for key: String in ["cost", "class", "blocked", "reason_flags", "slope_grade", "is_water", "water_depth_m"]:
				point.rideability[key] = block.rideability[key][k]
		points.append(point)
		dominant[point.biome.dominant] += 1
		classes[point.rideability["class"]] += 1
		cost_min = minf(cost_min, point.rideability.cost)
		cost_max = maxf(cost_max, point.rideability.cost)
		for w in range(4):
			means[w] += point.biome.weights[w] / float(side * side)
	var stem: String = "seed_%d_r%d_%d" % [seed_value, region.x, region.y]
	if not coarse:
		for panel: String in PANELS:
			var image := Image.create(side, side, false, Image.FORMAT_RGB8)
			for k in range(points.size()):
				image.set_pixel(k % side, k / side, color(panel, points[k]))
			image.resize(771, 771, Image.INTERPOLATE_NEAREST)
			image.save_png(out.path_join(stem + "_" + panel + ".png"))
		# Geometry overlay records ALL narrow channels, even missed raster water.
		_write_json(out.path_join(stem + "_geometry.json"), built.hydrology.get_data())
	var transects: Dictionary = _transects(built, out, stem, not coarse)
	return {"seed": seed_value, "region": [region.x, region.y], "basis": Context.SURFACE_BASIS, "context_signature": built.context.signature(), "biome_signature": built.biome.signature(), "rideability_signature": built.rideability.signature(), "descriptor": built.biome.get_descriptor(), "spacing_m": 64 if coarse else 16, "points": side * side, "query_ms": query_ms, "map_construction_and_transects_ms": (Time.get_ticks_usec() - construction_start) / 1000.0, "weight_means": means, "dominant_counts": dominant, "class_counts": classes, "cost_min": cost_min, "cost_max": cost_max, "transects": transects}


func _transects(built: Dictionary, out: String, stem: String, save_closeup: bool) -> Dictionary:
	var b: Dictionary = built.context.get_bounds_m()
	var pocket: Dictionary = built.biome.get_descriptor().pocket
	var sites: Array = []
	if pocket.is_present:
		var p: Vector2 = Macro.frame_to_local(built.context.get_frame_symmetry(), pocket.u_m, pocket.v_m)
		sites.append(["pocket", p.x, p.y, 4.0])
	var channel: Dictionary = built.hydrology.get_channel(0)
	var middle: int = channel.x_cm.size() / 2
	sites.append(["river", channel.x_cm[middle] / 100.0, channel.z_cm[middle] / 100.0, 1.0])
	var summary: Dictionary = {}
	for site: Array in sites:
		var rows: Array = []
		var transitions: int = 0
		var last_water: bool = false
		for k in range(-200, 201):
			var lx: float = site[1] + k * site[3]
			if lx < 0 or lx > 4096:
				continue
			var point: Dictionary = built.rideability.sample_combined(b.min_x + lx, b.min_z + site[2])
			if k > -200 and point.biome.is_water != last_water:
				transitions += 1
			last_water = point.biome.is_water
			rows.append({"offset_m": k * site[3], "biome": point.biome, "rideability": point.rideability, "signals": point.signals})
		_write_json(out.path_join(stem + "_" + site[0] + "_transect.json"), rows)
		summary[site[0]] = {"spacing_m": site[3], "samples": rows.size(), "water_transitions": transitions}
		if save_closeup:
			var image := Image.create(101, 101, false, Image.FORMAT_RGB8)
			for j in range(101):
				for i in range(101):
					var lx: float = site[1] + (i - 50) * 4.0
					var lz: float = site[2] + (j - 50) * 4.0
					if lx >= 0 and lz >= 0 and lx <= 4096 and lz <= 4096:
						image.set_pixel(i, j, color("blended", built.rideability.sample_combined(b.min_x + lx, b.min_z + lz)))
			image.resize(606, 606, Image.INTERPOLATE_NEAREST)
			image.save_png(out.path_join(stem + "_" + site[0] + "_closeup_4m.png"))
	return summary


func _benchmark(built: Dictionary, out: String, seed_value: int, region: Vector2i) -> void:
	var b: Dictionary = built.context.get_bounds_m()
	var hf: RefCounted = HField.create(built.hydrology, built.terrain).field
	var repetitions: Array = []
	for rep in range(4):
		var fresh: Dictionary = build(seed_value, region)
		var latency := PackedInt64Array()
		var start: int = Time.get_ticks_usec()
		for k in range(10000):
			var x: float = b.min_x + fmod(17.0 + k * 619.137, 4096.0)
			var z: float = b.min_z + fmod(89.0 + k * 397.231, 4096.0)
			var t: int = Time.get_ticks_usec()
			built.rideability.sample_combined(x, z)
			latency.append(Time.get_ticks_usec() - t)
		var point_ms: float = (Time.get_ticks_usec() - start) / 1000.0
		latency.sort()
		start = Time.get_ticks_usec()
		var block: Dictionary = built.rideability.sample_combined_lattice(b.min_x / 16, b.min_z / 16, 257, 257)
		var lattice_ms: float = (Time.get_ticks_usec() - start) / 1000.0
		block.clear()
		start = Time.get_ticks_usec()
		var candidates: int = 0
		for k in range(1000):
			var result: Dictionary = hf.sample_proximity_bounded(b.min_x + fmod(17.0 + k * 619.137, 4096.0), b.min_z + fmod(89.0 + k * 397.231, 4096.0), 160.0)
			candidates += result.segment_candidates + result.body_candidates
		var bounded_ms: float = (Time.get_ticks_usec() - start) / 1000.0
		start = Time.get_ticks_usec()
		for k in range(1000):
			hf.sample_proximity(b.min_x + fmod(17.0 + k * 619.137, 4096.0), b.min_z + fmod(89.0 + k * 397.231, 4096.0))
		var full_ms: float = (Time.get_ticks_usec() - start) / 1000.0
		if rep > 0:
			repetitions.append({"terrain_setup_ms": fresh.terrain_setup_ms, "hydrology_ms": fresh.hydrology_ms, "context_ms": fresh.context_ms, "pocket_ms": fresh.pocket_ms, "point_10000_ms": point_ms, "point_median_us": latency[5000], "point_p95_us": latency[9500], "lattice_257_ms": lattice_ms, "bounded_1000_ms": bounded_ms, "full_1000_ms": full_ms, "candidate_mean": candidates / 1000.0})
	var cycles: Array = []
	for k in range(10):
		var ctx: RefCounted = Context.create(built.region_plan, built.terrain, built.hydrology).context
		var bio: RefCounted = Biome.create(ctx).field
		var ride: RefCounted = Ride.create(ctx, bio).field
		ride.sample_combined(b.min_x + 2048.0, b.min_z + 2048.0)
		ride = null
		bio = null
		ctx = null
		var process_memory: Array = []
		OS.execute("powershell.exe", ["-NoProfile", "-Command", "(Get-Process -Id %d).WorkingSet64" % OS.get_process_id()], process_memory)
		cycles.append({"godot_static_bytes": OS.get_static_memory_usage(), "process_working_set_bytes": str(process_memory[0]).strip_edges().to_int() if not process_memory.is_empty() else -1})
	var record := {"seed": seed_value, "region": [region.x, region.y], "warmup_repetitions": 1, "measured_repetitions": repetitions, "hydrology_ms": built.hydrology_ms, "context_ms": built.context_ms, "pocket_ms": built.pocket_ms, "storage": built.context.get_storage_metrics(), "ten_release_cycles_godot_static_bytes": cycles, "process_peak_bytes": OS.get_memory_info().get("peak", -1)}
	_write_json(out.path_join("benchmark_%d.json" % seed_value), record)
	print("ENV_BENCHMARK " + JSON.stringify(record))
