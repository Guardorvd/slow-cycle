extends SceneTree

func _init() -> void:
	var sandbox_scene: PackedScene = load("res://scenes/test/sandbox.tscn")
	var instance: Node = sandbox_scene.instantiate()
	root.add_child(instance)
	_run_third_person(instance)

func _run_third_person(sandbox: Node) -> void:
	var bike: CharacterBody3D = sandbox.get_node("Bicycle")
	var cam_rig: Node3D = bike.get_node("CameraRig")
	cam_rig.is_first_person = false
	cam_rig._apply_camera_mode()

	for i in range(15):
		await process_frame

	var img: Image = root.get_texture().get_image()
	if img:
		img.save_png("screenshot_third_person.png")
		print("THIRD_PERSON_SCREENSHOT_SAVED")
	quit()
