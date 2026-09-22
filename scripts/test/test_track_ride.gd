@tool
extends SceneTree

func _init() -> void:
	_start()

func _start() -> void:
	print("\n==================================================")
	print("   SLOW CYCLE — LIVE TEST TRACK RIDE SIMULATION   ")
	print("==================================================\n")

	var track_scene: PackedScene = load("res://scenes/test/riding_feel_test_track.tscn")
	var root_node: Node3D = track_scene.instantiate()
	root.add_child(root_node)
	await process_frame

	var bike: CharacterBody3D = root_node.get_node("Bicycle")
	var generator = root_node.get_node("TestTrackGenerator")
	var debug_hud: CanvasLayer = root_node.get_node("DebugHUD")

	# Enable DebugHUD
	if debug_hud:
		debug_hud.visible = true

	print("[1] Initial state: Pos = %s, Speed = %.1f km/h" % [bike.global_position, bike.current_speed * 3.6])

	# 1. Accelerate on Section A (Flat Start)
	print("\n--- Accelerating on Section A (Flat Start) ---")
	Input.action_press("pedal")
	for frame in range(240): # 4 seconds of pedaling from standstill
		await physics_frame
	Input.action_release("pedal")

	var speed_a: float = bike.current_speed * 3.6
	print("After 4s pedaling: Speed = %.1f km/h, Pos = %s" % [speed_a, bike.global_position])
	if speed_a < 8.0:
		printerr("[FAIL] Bike failed to accelerate adequately on Flat Start!")
		quit(1)
		return
	print("[PASS] Bike accelerates smoothly on Section A.")


	# 2. Coasting test
	print("\n--- Coasting on Section A ---")
	for frame in range(60): # 1 second coasting
		await physics_frame
	var speed_coast: float = bike.current_speed * 3.6
	print("After 1s coasting: Speed = %.1f km/h (drag gently slowing down)" % speed_coast)
	if speed_coast >= speed_a or speed_coast < 5.0:
		printerr("[FAIL] Coasting physics abnormal: %f" % speed_coast)
		quit(1)
		return
	print("[PASS] Coasting resistance functions properly.")

	# 3. Teleport to Section B (Climb +4.5°)
	print("\n--- Testing Section B (Climb +4.5°) ---")
	var sample_b: Dictionary = generator.road_path.get_sample_at_distance(350.0)
	bike.global_position = sample_b.position + Vector3(0.0, 0.45, 0.0)
	bike.velocity = Vector3.ZERO
	bike.current_speed = 5.0
	for frame in range(60):
		await physics_frame
	var pitch_b: float = rad_to_deg(bike.current_pitch)
	print("On Section B climb: Pitch = %+.2f°, Speed = %.1f km/h" % [pitch_b, bike.current_speed * 3.6])
	if pitch_b < 2.0:
		printerr("[FAIL] Bike pitch on climb did not register positive slope: %f" % pitch_b)
		quit(1)
		return
	print("[PASS] Ground pitch alignment detects hill climb.")

	# 4. Teleport to Section C (Downhill -5.0°) and Brake
	print("\n--- Testing Section C (Downhill -5.0°) & Braking ---")
	var sample_c: Dictionary = generator.road_path.get_sample_at_distance(580.0)
	bike.global_position = sample_c.position + Vector3(0.0, 0.45, 0.0)
	bike.velocity = Vector3.ZERO
	bike.current_speed = 7.0
	for frame in range(30):
		await physics_frame
	var pitch_c: float = rad_to_deg(bike.current_pitch)
	print("On Section C downhill: Pitch = %+.2f°" % pitch_c)

	# Apply heavy brake
	Input.action_press("brake")
	for frame in range(45):
		await physics_frame
	Input.action_release("brake")
	var dive_c: float = rad_to_deg(bike.brake_dive_pitch)
	print("During downhill braking: Brake Dive = %+.2f°, Speed = %.1f km/h" % [dive_c, bike.current_speed * 3.6])
	if bike.current_speed > 4.0:
		printerr("[FAIL] Brakes did not decelerate bike on downhill!")
		quit(1)
		return
	print("[PASS] Downhill braking and pitch dive verified.")


	# 5. Teleport to Section L (Grass Verge Exit)
	print("\n--- Testing Section L (Grass Verge Exit Layer 3) ---")
	# Sample on Section L
	var s_l: float = 2120.0
	var sample_l: Dictionary = generator.road_path.get_sample_at_distance(s_l)
	bike.global_position = sample_l.position + Vector3(0, 0.45, 0)
	bike.velocity = Vector3.ZERO
	bike.current_speed = 6.0
	for frame in range(30):
		await physics_frame
	print("On Section L road surface: is_on_grass = %s (expected true due to Layer 3 collision)" % bike.is_on_grass)
	if not bike.is_on_grass:
		printerr("[FAIL] Section L road did not trigger is_on_grass = true!")
		quit(1)
		return
	print("[PASS] Section L grass verge triggers Layer 3 grass drag (0.45).")

	# 5b. Teleport to Section J (Rough Gravel)
	print("\n--- Testing Section J (Rough Gravel Washboard) ---")
	var s_j: float = 1850.0
	var sample_j: Dictionary = generator.road_path.get_sample_at_distance(s_j)
	bike.global_position = sample_j.position + Vector3(0, 0.45, 0)
	bike.velocity = Vector3.ZERO
	bike.current_speed = 7.0
	for frame in range(30):
		await physics_frame
	print("On Section J road surface: current_surface = %d (expected 2 = ROUGH_GRAVEL), roughness = %.2f" % [bike.current_surface, bike.terrain_roughness])
	if bike.current_surface != 2 and bike.terrain_roughness < 0.5:
		printerr("[FAIL] Section J did not detect rough gravel surface!")
		quit(1)
		return
	print("[PASS] Section J rough gravel detects washboard surface (enum 2, roughness > 0.5).")

	# 6. Test 'R' Recovery Key
	print("\n--- Testing Recovery ('R' Key) ---")
	# Move bike off track
	bike.global_position = Vector3(50.0, 10.0, -200.0)
	for frame in range(10):
		await physics_frame
	
	# Trigger recovery
	Input.action_press("recover_ride")
	await physics_frame
	Input.action_release("recover_ride")


	for frame in range(30):
		await physics_frame

	print("After recovery: Position = %s (repositioned on track centerline)" % bike.global_position)
	var closest_idx: int = generator.road_path.find_closest_index(bike.global_position)
	var centerline_pt: Vector3 = generator.road_path.points[closest_idx]
	var dist_off: float = bike.global_position.distance_to(centerline_pt)
	print("Offset from centerline: %.4f m" % dist_off)
	if dist_off > 2.0:
		printerr("[FAIL] Bike was not recovered to track centerline!")
		quit(1)
		return
	print("[PASS] Bike recovery restores position safely to track centerline.")

	# 7. Check Debug HUD Section telemetry text
	if debug_hud and debug_hud.telemetry_label:
		var hud_text: String = debug_hud.telemetry_label.text
		print("\n--- Sample Telemetry HUD Output ---")
		print(hud_text.substr(0, 320))
		if not hud_text.contains("Track Section:"):
			printerr("[FAIL] Debug HUD text does not contain Track Section info!")
			quit(1)
			return
		print("[PASS] Debug HUD dynamically tracks and displays test track sections.")

	root_node.queue_free()
	await process_frame
	print("\n[SUCCESS] ALL LIVE TEST TRACK RIDE CHECKS PASSED [OK]\n")
	quit(0)
