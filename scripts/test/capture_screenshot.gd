extends SceneTree

func _init() -> void:
	var sandbox_scene: PackedScene = load("res://scenes/test/sandbox.tscn")
	var instance: Node = sandbox_scene.instantiate()
	root.add_child(instance)
	_wait_and_capture()

func _wait_and_capture() -> void:
	for i in range(15):
		await process_frame
	var img: Image = root.get_texture().get_image()
	if img:
		img.save_png("screenshot.png")
		print("SCREENSHOT_SAVED_SUCCESS")
	quit()
