extends SceneTree

## Saved/read Forward+ Vulkan evidence with source identity, optional external
## exact Git/diff provenance and honest diagnostic sampling resolution.
const PREVIEW = preload("res://scenes/world/region_preview.tscn")
const Maps = preload("res://scripts/test/capture_environment_map.gd")


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	var options: Dictionary = Maps.parse_options(OS.get_cmdline_user_args(), true)
	if not options.is_valid:
		push_error("ENV_CAPTURE_FAIL " + options.reason_code)
		quit(1)
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		push_error("ENV_CAPTURE_FAIL ERR_ENV_CAPTURE_VULKAN")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(options.out) != OK:
		push_error("ENV_CAPTURE_FAIL ERR_ENV_CLI_OUTPUT")
		quit(1)
		return
	var start: int = Time.get_ticks_usec()
	var preview: Node3D = PREVIEW.instantiate()
	preview.world_seed = options.seeds[0]
	preview.region_coordinate = options.region
	preview.environment_mode = options.environment
	root.add_child(preview)
	if not preview.build_error.is_empty():
		preview.queue_free()
		return
	var startup_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var identity: Dictionary = Maps.source_identity(options)
	var records: Array = []
	for framing: String in ["top_down", "oblique", "valley_a", "pocket"]:
		var camera: Dictionary = preview.set_camera_framing(framing)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = options.out.path_join("seed_%d_%s_%s.png" % [preview.world_seed, options.environment, framing])
		if image.save_png(path) != OK:
			push_error("ENV_CAPTURE_FAIL ERR_ENV_CAPTURE_SAVE")
			quit(1)
			return
		var reloaded := Image.load_from_file(path)
		if reloaded == null or reloaded.is_empty() or reloaded.get_size() != image.get_size():
			push_error("ENV_CAPTURE_FAIL ERR_ENV_CAPTURE_RELOAD")
			quit(1)
			return
		var first: Color = reloaded.get_pixel(0, 0)
		var nonuniform: bool = false
		for j in range(0, reloaded.get_height(), 8):
			for i in range(0, reloaded.get_width(), 8):
				if reloaded.get_pixel(i, j) != first:
					nonuniform = true
		if not nonuniform:
			push_error("ENV_CAPTURE_FAIL ERR_ENV_CAPTURE_UNIFORM")
			quit(1)
			return
		var record := {"seed": preview.world_seed, "region": [preview.region_coordinate.x, preview.region_coordinate.y], "environment": options.environment, "framing": framing, "camera": camera, "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "adapter": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name(), "startup_ms": startup_ms, "metrics": preview.get_metrics(), "source_identity": identity, "path": path, "png_sha256": FileAccess.get_sha256(path), "reloaded": true, "nonuniform": true, "size": [image.get_width(), image.get_height()]}
		records.append(record)
		print("ENV_CAPTURE " + JSON.stringify(record))
	Maps._write_json(options.out.path_join("capture_%d_%s.json" % [preview.world_seed, options.environment]), records)
	preview.queue_free()
	await process_frame
	print("ENV_CAPTURE_SUMMARY completed=true captures=%d" % records.size())
	quit(0)
