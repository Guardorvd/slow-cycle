extends SceneTree

## Saved/read Forward+ Vulkan evidence (E5) of the opt-in `--routes` preview:
## corridor bands, reference lines and anchor posts over the R4 environmental
## tint, with source identity, camera and route metrics per capture.
const PREVIEW = preload("res://scenes/world/region_preview.tscn")
const Preview = preload("res://scripts/world/region_preview.gd")
const FRAMINGS: Array[String] = ["top_down", "oblique", "oblique_b", "valley_a"]
const SOURCES: Array[String] = ["scripts/world/region/region_route_graph.gd", "scripts/world/region/route_planning_raster.gd", "scripts/world/region/route_anchor_finder.gd", "scripts/world/region/route_search.gd",
	"scripts/world/region/route_journey_scoring.gd", "scripts/world/region/route_corridor_builder.gd", "scripts/world/region/route_planner.gd", "scripts/world/region/hydrology_field.gd", "scripts/world/region_preview.gd"]


static func parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"is_valid": true, "reason_code": "", "seed": 184729, "region": Vector2i.ZERO, "environment": "biome", "out": ""}
	var seen: Dictionary = {}
	for arg: String in args:
		var key: String = arg.split("=")[0]
		if seen.has(key):
			return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_DUPLICATE"}
		seen[key] = true
		if arg.begins_with("--seed="):
			var parsed: Dictionary = Preview.parse_integer(arg.substr(7), 64)
			if not parsed.is_valid:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_SEED"}
			result.seed = parsed.value
		elif arg.begins_with("--region="):
			var parts: PackedStringArray = arg.substr(9).split(",")
			if parts.size() != 2:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_REGION"}
			var x: Dictionary = Preview.parse_integer(parts[0], 32)
			var z: Dictionary = Preview.parse_integer(parts[1], 32)
			if not x.is_valid or not z.is_valid:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_REGION"}
			result.region = Vector2i(x.value, z.value)
		elif arg.begins_with("--environment="):
			result.environment = arg.substr(14)
			if not result.environment in ["biome", "rideability"]:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_MODE"}
		elif arg.begins_with("--out="):
			result.out = arg.substr(6).replace("\\", "/").simplify_path()
		else:
			return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_ARGUMENT"}
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if result.out.is_empty() or not result.out.is_absolute_path() or result.out.to_lower() == project or result.out.to_lower().begins_with(project + "/"):
		return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_OUTPUT"}
	return result


func _initialize() -> void:
	call_deferred("capture")


func _fail(reason: String) -> void:
	push_error("ROUTE_CAPTURE_FAIL " + reason)
	print("ROUTE_CAPTURE_FAIL " + reason)
	quit(1)


func capture() -> void:
	var options: Dictionary = parse_options(OS.get_cmdline_user_args())
	if not options.is_valid:
		_fail(options.reason_code)
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		_fail("ERR_ROUTE_CAPTURE_VULKAN")
		return
	if DirAccess.make_dir_recursive_absolute(options.out) != OK:
		_fail("ERR_ROUTE_CLI_OUTPUT")
		return
	var start: int = Time.get_ticks_usec()
	var preview: Node3D = PREVIEW.instantiate()
	preview.world_seed = options.seed
	preview.region_coordinate = options.region
	preview.environment_mode = options.environment
	preview.show_routes = true
	root.add_child(preview)
	if not preview.build_error.is_empty():
		preview.queue_free()
		return
	var startup_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var identity: Dictionary = {}
	for path: String in SOURCES:
		identity[path] = FileAccess.get_sha256("res://" + path)
	var records: Array = []
	for framing: String in FRAMINGS:
		var camera: Dictionary = preview.set_camera_framing(framing)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = options.out.path_join("seed_%d_%d_%d_routes_%s_%s.png" % [options.seed, options.region.x, options.region.y, options.environment, framing])
		if image.save_png(path) != OK:
			_fail("ERR_ROUTE_CAPTURE_SAVE")
			return
		var reloaded := Image.load_from_file(path)
		if reloaded == null or reloaded.is_empty() or reloaded.get_size() != image.get_size():
			_fail("ERR_ROUTE_CAPTURE_RELOAD")
			return
		var first: Color = reloaded.get_pixel(0, 0)
		var nonuniform: bool = false
		for j in range(0, reloaded.get_height(), 8):
			for i in range(0, reloaded.get_width(), 8):
				nonuniform = nonuniform or reloaded.get_pixel(i, j) != first
		if not nonuniform:
			_fail("ERR_ROUTE_CAPTURE_UNIFORM")
			return
		var record := {"seed": options.seed, "region": [options.region.x, options.region.y], "environment": options.environment, "framing": framing, "camera": camera, "renderer": RenderingServer.get_current_rendering_method(),
			"driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "startup_ms": startup_ms, "metrics": preview.get_metrics(),
			"route_signature": preview.get_route_signature(), "source_identity": identity, "path": path, "png_sha256": FileAccess.get_sha256(path), "reloaded": true, "nonuniform": true, "size": [image.get_width(), image.get_height()]}
		records.append(record)
		print("ROUTE_CAPTURE " + JSON.stringify(record))
	var file := FileAccess.open(options.out.path_join("capture_%d_%d_%d_routes.json" % [options.seed, options.region.x, options.region.y]), FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	preview.queue_free()
	await process_frame
	print("ROUTE_CAPTURE_SUMMARY completed=true captures=%d" % records.size())
	quit(0)
