extends SceneTree

## R3 Vulkan captures of the region preview in hydrology mode (E5 diagnostic
## evidence): standard framings plus two closer valley framings on the river.
## Usage: --script capture_hydrology_preview.gd -- --seed=<int> [--region=x,z]
##        --out=<absolute directory outside the project>
## Water is diagnostic (river at its true surface/width; creeks as draped
## overlays; bodies as level quads). Source identity covers R0-R3 sources.

const PREVIEW = preload("res://scenes/world/region_preview.tscn")
const FRAMINGS: Array[String] = ["oblique", "oblique_b", "top_down", "valley_a", "valley_b"]
const SOURCES: Array[String] = ["scripts/world/region/region_seed_derivation.gd", "scripts/world/region/region_identity.gd", "scripts/world/region/region_bounds.gd", "scripts/world/region/macro_terrain_plan.gd", "scripts/world/region/macro_geography_generator.gd", "scripts/world/region/macro_terrain_evaluator.gd", "scripts/world/region/region_plan.gd", "scripts/world/region/region_generator.gd", "scripts/world/region/terrain_field.gd", "scripts/world/region/terrain_tile_renderer.gd", "scripts/world/region/drainage_routing.gd", "scripts/world/region/hydrology_plan.gd", "scripts/world/region/hydrology_generator.gd", "scripts/world/region/hydrology_field.gd", "scripts/world/region/hydrology_surface.gd", "scripts/world/region_preview.gd", "scenes/world/region_preview.tscn", "scripts/test/capture_hydrology_preview.gd"]
var _output: String = ""


func _initialize() -> void:
	call_deferred("_capture")


func _fail(reason: String) -> void:
	push_error("HYDRO_CAPTURE_FAIL " + reason)
	quit(1)


func _capture() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_output = argument.substr(6).replace("\\", "/").simplify_path()
	var source_root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	if _output.is_empty() or not _output.is_absolute_path() or _output.to_lower().begins_with(source_root.to_lower() + "/") or _output.to_lower() == source_root.to_lower():
		_fail("ERR_CAPTURE_OUTPUT outside-project absolute directory required")
		return
	if RenderingServer.get_current_rendering_method() != "forward_plus" or DisplayServer.get_name() == "headless":
		_fail("ERR_CAPTURE_RENDERER Forward+ Vulkan required")
		return
	var preview: Node3D = PREVIEW.instantiate()
	preview.show_hydrology = true
	root.add_child(preview)
	if not preview.build_error.is_empty():
		preview.queue_free()
		return
	if DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("ERR_CAPTURE_OUTPUT create directory failed")
		return
	var source_identity: Dictionary = {}
	for path: String in SOURCES:
		source_identity[path] = FileAccess.get_sha256("res://" + path)
	for framing: String in FRAMINGS:
		var camera: Dictionary = preview.set_camera_framing(framing)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = _output.path_join("hydro_seed_%d_%s.png" % [preview.world_seed, framing])
		if image.save_png(path) != OK:
			_fail("ERR_CAPTURE_SAVE")
			return
		var reloaded := Image.load_from_file(path)
		if reloaded == null or reloaded.is_empty() or reloaded.get_size() != image.get_size():
			_fail("ERR_CAPTURE_RELOAD")
			return
		print("HYDRO_CAPTURE " + JSON.stringify({"world_seed": preview.world_seed, "region_coordinate": [preview.region_coordinate.x, preview.region_coordinate.y], "region_signature": preview.get_plan_signature(), "hydrology_signature": preview.get_hydrology_signature(), "metrics": preview.get_metrics(), "source_identity": source_identity, "camera_identity": camera, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "path": path, "png_sha256": FileAccess.get_sha256(path), "width": reloaded.get_width(), "height": reloaded.get_height(), "reloaded": true}))
	preview.queue_free()
	await process_frame
	quit(0)
