extends SceneTree

func _init() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var instance: Node = main_scene.instantiate()
	root.add_child(instance)
	_run_procedural_test(instance)

func _run_procedural_test(main_node: Node) -> void:
	var bike: CharacterBody3D = main_node.get_node("Bicycle")
	var world_mgr: Node = main_node.get_node("WorldManager")
	var debug_hud: CanvasLayer = main_node.get_node("DebugHUD")

	print("\n--- RUNNING PROCEDURAL SIMULATION ---")
	
	await process_frame

	# Enable DebugHUD so it's visible on screenshot
	if debug_hud:
		debug_hud.visible = true

	# 1. Pedal forward down procedural road
	Input.action_press("pedal")

	for frame in range(120):
		await process_frame

	print("Riding on gravel road: Speed = %.1f km/h, Position = %s" % [bike.current_speed * 3.6, bike.global_position])

	var img1: Image = root.get_texture().get_image()
	if img1:
		img1.save_png("screenshot_procedural_road.png")
		print("[CAPTURED] screenshot_procedural_road.png")

	# 2. Steer off-road to the right onto grass
	Input.action_press("steer_right")
	for frame in range(110):
		await process_frame
	Input.action_release("steer_right")

	print("After steering off-road: is_on_grass = %s, speed = %.1f km/h, pos = %s" % [bike.is_on_grass, bike.current_speed * 3.6, bike.global_position])

	# 3. Test Recovery (Hold 'R' to recover back to road)
	var pre_recovery_pos: Vector3 = bike.global_position
	print("Triggering Recovery from off-road pos: ", pre_recovery_pos)
	Input.action_press("recover_ride")
	await process_frame
	Input.action_release("recover_ride")

	# Wait for fade-in / repositioning / fade back out (0.6s total ~ 40-50 frames)
	for frame in range(50):
		await process_frame

	print("Post-recovery pos: %s, Speed = %.1f km/h" % [bike.global_position, bike.current_speed * 3.6])

	var img2: Image = root.get_texture().get_image()
	if img2:
		img2.save_png("screenshot_post_recovery.png")
		print("[CAPTURED] screenshot_post_recovery.png")

	print("--- PROCEDURAL SIMULATION COMPLETED [OK] ---\n")
	quit(0)
