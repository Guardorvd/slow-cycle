extends SceneTree

func _init() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var instance: Node = main_scene.instantiate()
	root.add_child(instance)
	_run_simulation(instance)

func _run_simulation(main_node: Node) -> void:
	var bike: Node = main_node.get_node("Bicycle")
	var debug_hud: Node = main_node.get_node("DebugHUD")
	if debug_hud:
		debug_hud.visible = true

	# Simulate pedaling forward
	Input.action_press("pedal")

	for frame in range(180):
		if frame == 90:
			Input.action_press("steer_left")
		if frame == 160:
			Input.action_release("steer_left")
			Input.action_release("pedal")
			Input.action_press("brake")
		await process_frame

	Input.action_release("brake")

	print("\n=== SPRINT 3A RUNTIME SIMULATION RESULTS ===")
	print("Speed: %.1f km/h" % (bike.current_speed * 3.6))
	print("Physics Pitch: %.2f° | Visual Pitch: %.2f° | Dive: %.2f°" % [rad_to_deg(bike.physics_pitch), rad_to_deg(bike.visual_pitch), rad_to_deg(bike.brake_dive_pitch)])
	print("Steer: %.2f° | Bank: %.2f° | Turn Radius: %s" % [rad_to_deg(bike.current_steer), rad_to_deg(bike.current_bank), str(bike.turn_radius)])
	print("Pedal Power: %.0f%% | Brake Input: %.0f%%" % [bike.pedal_power * 100.0, bike.brake_input * 100.0])
	print("Bike Position: ", bike.global_position)

	var img: Image = root.get_texture().get_image()
	if img:
		img.save_png("screenshot_sprint3a.png")
		print("[PASS] screenshot_sprint3a.png captured successfully!")
	quit(0)
