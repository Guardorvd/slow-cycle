extends SceneTree

const Audit = preload("res://scripts/test/capture_audit_support.gd")
const Contract = preload("res://scripts/test/test_surface_audit_contract.gd")
var audit := Audit.new()
var viewport: SubViewport

func _init() -> void:
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if audit.tree and not audit.finished and not audit.alive():
		_end()
	return false

func _end() -> void:
	if is_instance_valid(viewport):
		viewport.free()
		viewport = null
	audit.finish(4)

func _run() -> void:
	if not audit.begin(self, "surface_culling_production_fixture", [184729]):
		_end()
		return
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_driver_name() != "vulkan":
		audit.reject("REAL_VULKAN_REQUIRED")
		_end()
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0.7)
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var mesh_instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0, 0)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	mesh_instance.material_override = material
	viewport.add_child(mesh_instance)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 80
	camera.far = 250
	viewport.add_child(camera)
	camera.make_current()
	for wedge in [false, true]:
		var prep = Contract.flat_fixture(wedge)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prep.terrain_arrays)
		mesh_instance.mesh = mesh
		for side in ["top", "bottom"]:
			camera.position = Vector3(0, 100 if side == "top" else -100, -25)
			camera.look_at(Vector3(0, 0, -25), Vector3.FORWARD)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := viewport.get_texture().get_image()
			var reason := Audit.image_reason(img, viewport.size)
			if not reason.is_empty():
				audit.reject(reason)
				_end()
				return
			var terrain_pixels := 0
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var pixel := img.get_pixel(x, y)
					if pixel.r > 0.5 and pixel.g < 0.2 and pixel.b < 0.2:
						terrain_pixels += 1
			var expected := terrain_pixels > 500 if side == "top" else terrain_pixels == 0
			var name: String = ("wedge" if wedge else "ordinary") + "_" + side
			var png := audit.run_dir.path_join(name + ".png")
			var save_error := Audit.save_image(img, viewport.size, png)
			var data := {"run_id": audit.manifest.run_id, "seed": 184729, "fixture": "production_flat_path_wedge" if wedge else "production_flat_path", "side": side, "camera_pose": Audit.pose(camera.global_transform), "cull_mode": "BACK", "terrain_pixels": terrain_pixels, "expected": expected, "png": png, "save_error": save_error, "renderer": audit.manifest.renderer, "driver": audit.manifest.driver, "source_digest": audit.manifest.source_digest, "actual_fork": false, "status": "PASS" if expected and save_error.is_empty() else "FAIL"}
			var metadata := audit.run_dir.path_join(name + ".json")
			var io := Audit.write_json(metadata, data)
			audit.manifest.frames.append({"png": png, "metadata": metadata, "terrain_pixels": terrain_pixels})
			if not expected or not save_error.is_empty() or not io.is_empty():
				audit.reject("CULLING_CONTRACT_FAILED:" + name + ":" + save_error + ":" + io)
				_end()
				return
	_end()
