extends SceneTree

func _init() -> void:
	var sandbox_scene: PackedScene = load("res://scenes/test/sandbox.tscn")
	var instance: Node = sandbox_scene.instantiate()
	root.add_child(instance)
	_run_simulation(instance)

func _run_simulation(sandbox: Node) -> void:
	var bike: CharacterBody3D = sandbox.get_node("Bicycle")
	
	# Simulate pressing 'W' (pedal) via Godot Input system
	Input.action_press("pedal")

	for frame in range(120):
		if frame == 60:
			Input.action_press("steer_left")
		if frame == 100:
			Input.action_release("steer_left")
		await process_frame

	Input.action_release("pedal")

	print("SPEED_AFTER_DOWNHILL: ", bike.current_speed * 3.6, " km/h")
	print("BANK_ANGLE: ", rad_to_deg(bike.current_bank), " deg")
	print("BIKE_POSITION: ", bike.global_position)

	var img: Image = root.get_texture().get_image()
	if img:
		img.save_png("screenshot_riding.png")
		print("RIDING_SCREENSHOT_SAVED")
	quit()
