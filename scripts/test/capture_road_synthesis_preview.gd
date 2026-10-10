extends SceneTree

## Saved / read Forward+ Vulkan evidence (E5) of the isolated R6 diagnostic
## preview (scenes/test/road_synthesis_preview.tscn). Deterministic case
## selection from the synthesized plan (ExecPlan §12 categories): calm valley
## backbone, flowing secondary, winding singletrack, mountain climb / descent,
## optional technical, junction, water crossing; a category without a
## qualifying READY piece is recorded MISSING. Per selected case an oblique
## (terrain-aware) and a near-road view, plus region overview / top-down and
## views of failed edges. Every image is saved, reloaded and checked for
## non-uniform content; provenance per capture.
const SCENE = preload("res://scenes/test/road_synthesis_preview.tscn")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const Preview = preload("res://scripts/world/region_preview.gd")
const SOURCES: Array[String] = ["scripts/world/region/road_synthesizer.gd", "scripts/world/region/road_alignment_designer.gd", "scripts/world/region/road_junction_planner.gd",
	"scripts/world/region/road_feasibility_validator.gd", "scripts/world/region/road_synthesis_plan.gd", "scripts/world/region/road_corridor_geometry.gd",
	"scripts/world/region/regional_road_math.gd", "scripts/world/region/roadbed_intent.gd", "scripts/world/region/road_synthesis_policy.gd", "scripts/test/road_synthesis_preview.gd",
	"scripts/test/capture_road_synthesis_preview.gd", "scenes/test/road_synthesis_preview.tscn"]


static func parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"is_valid": true, "seed": 184729, "region": Vector2i.ZERO, "out": "", "selection": ""}
	for arg: String in args:
		if arg.begins_with("--case="):
			var parts: PackedStringArray = arg.substr(7).split(",")
			if parts.size() != 3:
				return {"is_valid": false}
			var s: Dictionary = Preview.parse_integer(parts[0], 64)
			var x: Dictionary = Preview.parse_integer(parts[1], 32)
			var z: Dictionary = Preview.parse_integer(parts[2], 32)
			if not s.is_valid or not x.is_valid or not z.is_valid:
				return {"is_valid": false}
			result.seed = s.value
			result.region = Vector2i(x.value, z.value)
		elif arg.begins_with("--out="):
			result.out = arg.substr(6).replace("\\", "/").simplify_path()
		elif arg.begins_with("--selection="):
			result.selection = arg.substr(12).replace("\\", "/")
		else:
			return {"is_valid": false}
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if result.out.is_empty() or not result.out.is_absolute_path() or result.out.to_lower().begins_with(project):
		return {"is_valid": false}
	return result


func _initialize() -> void:
	call_deferred("capture")


func _fail(reason: String) -> void:
	push_error("R6_CAPTURE_FAIL " + reason)
	print("R6_CAPTURE_FAIL " + reason)
	quit(1)


## Deterministic selection from plan records (stable tie-break: lower id).
static func select_cases(plan: RefCounted) -> Dictionary:
	var data: Dictionary = plan.get_data()
	var best: Dictionary = {}
	var score := func(key: String, value: float, payload: Dictionary) -> void:
		if not best.has(key) or value > best[key].score:
			best[key] = {"score": value, "payload": payload}
	for record: Dictionary in data.edges:
		if record.status != "READY":
			continue
		var counts: Dictionary = {}
		var calm_m: float = 0.0
		for f: Dictionary in record.features:
			if f.status == Policy.REALIZED:
				counts[f.kind] = counts.get(f.kind, 0) + 1
				if f.kind == "CALM":
					calm_m += f.s1 - f.s0
		var payload := {"piece_id": record.piece_id, "edge_id": record.edge_id, "class": record.class_name, "features": counts, "length_m": record.metrics.length_m}
		match record.class_name:
			"BACKBONE":
				score.call("calm_backbone", calm_m + 0.001 * record.metrics.length_m, payload)
			"SECONDARY":
				score.call("flowing_secondary", counts.get("SWEEP", 0) + 2.0 * counts.get("LINKED_TURNS", 0) + 0.0001 * record.metrics.length_m, payload)
			"SINGLETRACK":
				score.call("winding_singletrack", counts.get("SWEEP", 0) + 2.0 * counts.get("LINKED_TURNS", 0) + 2.0 * counts.get("SWITCHBACK", 0) + 0.0001 * record.metrics.length_m, payload)
			"TECHNICAL":
				score.call("optional_technical", record.metrics.length_m, payload)
		score.call("mountain_climb", record.metrics.climb_m + record.metrics.descent_m, payload)
	for j: Dictionary in data.junctions:
		var ready: Array = j.movements.filter(func(m: Dictionary) -> bool: return m.status == Policy.MOVEMENT_READY)
		if not ready.is_empty():
			score.call("junction", ready.size() + (10.0 if j.status == Policy.JUNCTION_READY else 0.0) - 0.0001 * j.node_id, {"piece_id": ready[0].piece_id, "node_id": j.node_id, "junction_status": j.status})
	for c: Dictionary in data.crossings:
		if c.status == "RESOLVED":
			var record: Dictionary = data.edges[c.edge_id]
			score.call("water_crossing", c.clear_span_m + (100.0 if c.support == "BRIDGE_DECK" else 0.0), {"piece_id": record.piece_id, "crossing_id": c.crossing_id, "support": c.support,
				"fraction": c.s_m / maxf(record.metrics.length_m, 1.0)})
	var result: Dictionary = {}
	for key: String in ["calm_backbone", "flowing_secondary", "winding_singletrack", "mountain_climb", "optional_technical", "junction", "water_crossing"]:
		result[key] = best[key].payload if best.has(key) else {"status": "MISSING"}
	var failed: Array = []
	for record: Dictionary in data.edges:
		if record.status != "READY" and failed.size() < 2:
			failed.append({"edge_id": record.edge_id, "class": record.class_name, "reasons": record.reasons})
	result["failed"] = failed
	return result


func capture() -> void:
	var options: Dictionary = parse_options(OS.get_cmdline_user_args())
	if not options.is_valid:
		_fail("ERR_R6_CLI_ARGUMENT")
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		_fail("ERR_R6_CAPTURE_VULKAN")
		return
	DirAccess.make_dir_recursive_absolute(options.out)
	var start: int = Time.get_ticks_usec()
	var preview: Node3D = SCENE.instantiate()
	preview.world_seed = options.seed
	preview.region_coordinate = options.region
	root.add_child(preview)
	if not preview.build_error.is_empty():
		_fail(preview.build_error)
		return
	var startup_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var selection: Dictionary = select_cases(preview.plan)
	var identity: Dictionary = {}
	for path: String in SOURCES:
		identity[path] = FileAccess.get_sha256("res://" + path)
	var shots: Array = [["overview", "framing", "overview"], ["top_down", "framing", "top_down"]]
	for key: String in ["calm_backbone", "flowing_secondary", "winding_singletrack", "mountain_climb", "optional_technical", "junction", "water_crossing"]:
		var item: Dictionary = selection[key]
		if item.has("status"):
			continue
		var fraction: float = item.get("fraction", 0.5)
		shots.append([key + "_oblique", "piece", item.piece_id, "oblique", fraction])
		shots.append([key + "_near", "piece", item.piece_id, "near", clampf(fraction - 0.04, 0.02, 0.98)])
	var records: Array = []
	var name: String = "%d_%d_%d" % [options.seed, options.region.x, options.region.y]
	var frame_times: Array = []
	for shot: Array in shots:
		var camera: Dictionary = preview.set_camera_framing(shot[2]) if shot[1] == "framing" else preview.frame_piece(shot[2], shot[3], shot[4])
		await process_frame
		await process_frame
		var t0: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		frame_times.append((Time.get_ticks_usec() - t0) / 1000.0)
		var image: Image = root.get_texture().get_image()
		var path: String = options.out.path_join("r6_%s_%s.png" % [name, shot[0]])
		if image.save_png(path) != OK:
			_fail("ERR_R6_CAPTURE_SAVE")
			return
		var reloaded := Image.load_from_file(path)
		if reloaded == null or reloaded.get_size() != image.get_size():
			_fail("ERR_R6_CAPTURE_RELOAD")
			return
		var first: Color = reloaded.get_pixel(0, 0)
		var nonuniform: bool = false
		for j in range(0, reloaded.get_height(), 8):
			for i in range(0, reloaded.get_width(), 8):
				nonuniform = nonuniform or reloaded.get_pixel(i, j) != first
		if not nonuniform:
			_fail("ERR_R6_CAPTURE_UNIFORM")
			return
		var record := {"case": name, "shot": shot[0], "camera": camera, "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
			"adapter": RenderingServer.get_video_adapter_name(), "path": path, "png_sha256": FileAccess.get_sha256(path), "size": [image.get_width(), image.get_height()], "reloaded": true, "nonuniform": true}
		records.append(record)
		print("R6_CAPTURE " + JSON.stringify(record))
	# Steady-frame sample after loading (overview).
	preview.set_camera_framing("overview")
	var steady: Array = []
	for f in range(60):
		var t0: int = Time.get_ticks_usec()
		await process_frame
		steady.append((Time.get_ticks_usec() - t0) / 1000.0)
	steady.sort()
	var manifest := {"case": name, "selection": selection, "metrics": preview.get_metrics(), "startup_ms": startup_ms, "steady_frame_ms": {"p50": steady[30], "p95": steady[56], "max": steady[59]},
		"source_identity": identity, "captures": records, "engine": Engine.get_version_info()}
	var file := FileAccess.open(options.out.path_join("capture_%s.json" % name), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	preview.queue_free()
	await process_frame
	var missing: Array = []
	for key: String in selection:
		if selection[key] is Dictionary and selection[key].get("status", "") == "MISSING":
			missing.append(key)
	print("R6_CAPTURE_SUMMARY completed=true captures=%d missing=%s startup_ms=%.0f" % [records.size(), JSON.stringify(missing), startup_ms])
	quit(0)
