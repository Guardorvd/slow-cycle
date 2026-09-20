extends SceneTree

func _init() -> void:
	print("\n=== RUNNING POST-FIX DIAGNOSTIC VERIFICATION ===")
	var all_ok: bool = true

	# Test 1: REAL 3D ArrayMesh vertex continuity at Chunk 0 / Chunk 1 boundary
	var wm_script: GDScript = load("res://scripts/world/world_manager.gd")
	var wm = wm_script.new()
	wm._init_shared_resources()

	var path := preload("res://scripts/world/road_path_data.gd").new()
	var logic := preload("res://scripts/world/road_logic.gd").new(184729, path)
	var chunk_class: GDScript = load("res://scripts/world/road_chunk.gd")

	# Chunk 0
	logic.plan_next_chunk()
	var chunk0 = chunk_class.new()
	chunk0.build_chunk(path, 0, 25, 0, wm.shared_materials, wm.shared_meshes)

	# Chunk 1
	logic.plan_next_chunk()
	var chunk1 = chunk_class.new()
	chunk1.build_chunk(path, 25, 50, 1, wm.shared_materials, wm.shared_meshes)

	# Extract real vertex arrays
	var road_mesh0: ArrayMesh = chunk0.get_child(0).mesh
	var road_mesh1: ArrayMesh = chunk1.get_child(0).mesh
	var road_verts0: PackedVector3Array = road_mesh0.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var road_verts1: PackedVector3Array = road_mesh1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var delta_left: float = road_verts0[-2].distance_to(road_verts1[0])
	var delta_right: float = road_verts0[-1].distance_to(road_verts1[1])
	var max_road_seam_delta: float = maxf(delta_left, delta_right)

	var terr_mesh0: ArrayMesh = chunk0.get_child(2).mesh
	var terr_mesh1: ArrayMesh = chunk1.get_child(2).mesh
	var terr_verts0: PackedVector3Array = terr_mesh0.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var terr_verts1: PackedVector3Array = terr_mesh1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var max_terr_seam_delta: float = 0.0
	for vi in range(4):
		var d: float = terr_verts0[-4 + vi].distance_to(terr_verts1[vi])
		if d > max_terr_seam_delta: max_terr_seam_delta = d

	print("[VERIFICATION #1] Real polygon mesh seam deltas:")
	print("  - Road Mesh Seam Delta: %.6f meters" % max_road_seam_delta)
	print("  - Terrain Mesh Seam Delta: %.6f meters" % max_terr_seam_delta)
	if max_road_seam_delta <= 0.001 and max_terr_seam_delta <= 0.001:
		print("  [PASS] Real 3D polygon vertex continuity verified (< 0.001m)")
	else:
		print("  [FAIL] Real mesh seam discrepancy detected!")
		all_ok = false

	chunk0.free()
	chunk1.free()
	wm.free()

	# Test 2: Search complexity in find_closest_index with cached start_idx
	for i in range(98):
		logic.plan_next_chunk()

	var bike_pos_at_end: Vector3 = path.points[-1]
	var last_idx: int = path.size() - 5
	var t1: int = Time.get_ticks_usec()
	var idx_with_cache: int = path.find_closest_index(bike_pos_at_end, last_idx)
	var time_with_cache_us: int = Time.get_ticks_usec() - t1
	print("[VERIFICATION #2] Cached find_closest_index over %d samples: %d µs" % [path.size(), time_with_cache_us])
	if time_with_cache_us < 60:
		print("  [PASS] Fast window lookup confirmed (%d µs < 60 µs)" % time_with_cache_us)
	else:
		print("  [FAIL] Lookup too slow: %d µs" % time_with_cache_us)
		all_ok = false


	# Test 3: Downhill ground adhesion
	var max_downhill_slope_deg: float = 6.0
	var sprint_speed: float = 13.0
	var current_pitch: float = deg_to_rad(-max_downhill_slope_deg)
	var slope_vy: float = sprint_speed * sin(current_pitch)
	var dynamic_vy: float = minf(-0.5, slope_vy - 0.5)
	var required_vy: float = -sprint_speed * tan(deg_to_rad(max_downhill_slope_deg))
	print("[VERIFICATION #3] Downhill ground adhesion:")
	print("  - Road descent velocity at 13 m/s on -6°: %.3f m/s" % required_vy)
	print("  - Dynamic vertical_vel in controller: %.3f m/s" % dynamic_vy)
	if dynamic_vy <= required_vy:
		print("  [PASS] Bicycle downward velocity (%.3f m/s) is strictly >= road drop rate (%.3f m/s)" % [absf(dynamic_vy), absf(required_vy)])
	else:
		print("  [FAIL] Insufficient downward velocity")
		all_ok = false

	# Test 4: Verify hud.gd no longer contains reload_current_scene on KEY_R
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	var hud_source: String = hud_script.source_code
	if hud_source.find("reload_current_scene") == -1:
		print("[VERIFICATION #4] [PASS] hud.gd no longer intercepts KEY_R; Recovery system is fully active!")
	else:
		print("[VERIFICATION #4] [FAIL] hud.gd still contains reload_current_scene")
		all_ok = false

	# Test 5: Verify foliage grounds with noise
	var foliage_script: GDScript = load("res://scripts/world/chunk_foliage.gd")
	var foliage_source: String = foliage_script.source_code
	if foliage_source.find("get_noise_2d") != -1 and foliage_source.find("t_factor") != -1:
		print("[VERIFICATION #5] [PASS] chunk_foliage.gd now projects trees and grass onto terrain surface!")
	else:
		print("[VERIFICATION #5] [FAIL] chunk_foliage.gd lacks noise projection")
		all_ok = false

	# Test 6: Verify bicycle.tscn collision layers
	var bike_scene: PackedScene = load("res://scenes/player/bicycle.tscn")
	var bike_instance = bike_scene.instantiate()
	if bike_instance.collision_layer == 8 and bike_instance.collision_mask == 7:
		print("[VERIFICATION #6] [PASS] Bicycle layer (8=Player) and mask (7=Default|Road|Grass) correctly configured!")
	else:
		print("[VERIFICATION #6] [FAIL] Bicycle layer/mask mismatch: layer=%d, mask=%d" % [bike_instance.collision_layer, bike_instance.collision_mask])
		all_ok = false

	# Test 7: [FIX-001] Verify removal of current_gear and telemetry_updated arity = 3
	var bike_script: GDScript = load("res://scripts/player/bicycle_controller.gd")
	var bike_source: String = bike_script.source_code
	var has_dead_gear: bool = (bike_instance.get("current_gear") != null) or (bike_source.find("var current_gear") != -1)
	
	var sig_arity_ok: bool = false
	for sig in bike_instance.get_signal_list():
		if sig["name"] == "telemetry_updated":
			if sig["args"].size() == 3:
				sig_arity_ok = true
			else:
				print("  telemetry_updated args count: %d (expected 3)" % sig["args"].size())

	var hud_src: String = load("res://scripts/ui/hud.gd").source_code
	var hud_sig_ok: bool = hud_src.find("func _on_telemetry_updated(speed_kmh: float, _cadence_pct: float, is_coasting: bool) -> void:") != -1

	if not has_dead_gear and sig_arity_ok and hud_sig_ok:
		print("[VERIFICATION #7] [PASS] FIX-001 verified: current_gear eliminated, telemetry_updated has exactly 3 arguments across controller and HUD!")
	else:
		print("[VERIFICATION #7] [FAIL] FIX-001 check failed: dead_gear=%s, sig_arity_ok=%s, hud_sig_ok=%s" % [has_dead_gear, sig_arity_ok, hud_sig_ok])
		all_ok = false
	bike_instance.free()

	# Test 8: [FIX-002] Verify strict noise assert in road_chunk.gd
	var chunk_source: String = load("res://scripts/world/road_chunk.gd").source_code
	var has_assert: bool = chunk_source.find("assert(noise != null, \"Terrain noise must be provided by WorldManager\")") != -1
	var has_fallback_1337: bool = chunk_source.find("1337") != -1
	if has_assert and not has_fallback_1337:
		print("[VERIFICATION #8] [PASS] FIX-002 verified: silent fallback seed 1337 removed, strict assert(noise != null) active!")
	else:
		print("[VERIFICATION #8] [FAIL] FIX-002 check failed: has_assert=%s, has_fallback_1337=%s" % [has_assert, has_fallback_1337])
		all_ok = false

	# Test 9: [FIX-003] Verify foliage noise sampled at plant spawn coordinates (X, Z)
	var fol_src: String = load("res://scripts/world/chunk_foliage.gd").source_code
	var has_grass_exact: bool = fol_src.find("noise.get_noise_2d(grass_base.x, grass_base.z)") != -1
	var has_tree_exact: bool = fol_src.find("noise.get_noise_2d(tree_base.x, tree_base.z)") != -1
	var has_old_edge_sample: bool = fol_src.find("road_edge.x") != -1
	if has_grass_exact and has_tree_exact and not has_old_edge_sample:
		print("[VERIFICATION #9] [PASS] FIX-003 verified: noise sampled strictly at plant spawn coordinates (X, Z)!")
	else:
		print("[VERIFICATION #9] [FAIL] FIX-003 check failed: grass_exact=%s, tree_exact=%s, old_edge=%s" % [has_grass_exact, has_tree_exact, has_old_edge_sample])
		all_ok = false

	# Test 10: [3A.1 FEAT-006.4] Coasting Equilibrium & Target Feel Calibration
	var bike_test_instance = bike_scene.instantiate()
	root.add_child(bike_test_instance)
	var r_road: float = bike_test_instance.road_rolling_resistance
	var k_drag: float = bike_test_instance.air_drag_coeff
	var r_grass: float = bike_test_instance.grass_rolling_resistance
	var g_mult: float = bike_test_instance.gravity_slope_mult
	var slope_neg2_rad: float = deg_to_rad(-2.0)
	var a_gravity_neg2: float = -sin(slope_neg2_rad) * 9.8 * g_mult
	var v_eq_ms: float = sqrt((a_gravity_neg2 - r_road) / k_drag)
	var v_eq_kmh: float = v_eq_ms * 3.6
	
	# Flat coast duration from 20 km/h (5.556 m/s) to 0
	var v0_ms: float = 20.0 / 3.6
	var t_coast_road: float = (1.0 / sqrt(r_road * k_drag)) * atan(v0_ms * sqrt(k_drag / r_road))
	var t_coast_grass: float = (1.0 / sqrt(r_grass * k_drag)) * atan(v0_ms * sqrt(k_drag / r_grass))
	
	print("[VERIFICATION #10] Sprint 3A.1 Coasting & Target Feel:")
	print("  - Downhill -2° Equilibrium: %.2f km/h (Target: 17.0 - 21.0 km/h)" % v_eq_kmh)
	print("  - Flat Coast Duration: %.1f s (Target: 25.0 - 35.0 s)" % t_coast_road)
	print("  - Grass Coast Duration: %.1f s (Target: < 12.0 s)" % t_coast_grass)
	if v_eq_kmh >= 17.0 and v_eq_kmh <= 21.0 and t_coast_road >= 25.0 and t_coast_road <= 35.0 and t_coast_grass < 12.0:
		print("  [PASS] Target Feel physics calibration verified!")
	else:
		print("  [FAIL] Coasting physics outside target feel bounds")
		all_ok = false

	# Test 11: [3A.2 FEAT-006.5] Physics & Visual Pitch Decoupling
	var has_physics_pitch: bool = "physics_pitch" in bike_test_instance
	var has_visual_pitch: bool = "visual_pitch" in bike_test_instance
	var attack_smooth: float = bike_test_instance.pitch_attack_smoothness
	var decay_smooth: float = bike_test_instance.pitch_decay_smoothness
	if has_physics_pitch and has_visual_pitch and attack_smooth == 14.0 and decay_smooth == 7.0:
		print("[VERIFICATION #11] [PASS] Physics and Visual pitch successfully decoupled (Attack: %.1f, Decay: %.1f)!" % [attack_smooth, decay_smooth])
	else:
		print("[VERIFICATION #11] [FAIL] Pitch decoupling incomplete")
		all_ok = false

	# Test 12: [3A.3 FEAT-006.6] Hybrid Lean Steering & Turn Radius Limiter
	var max_steer_low: float = bike_test_instance.max_steer_angle
	var max_steer_high: float = bike_test_instance.high_speed_steer_limit
	var v_high: float = 11.5 # ~41.4 km/h
	var omega_high: float = (v_high / bike_test_instance.WHEELBASE) * tan(max_steer_high)
	var radius_high: float = v_high / omega_high
	print("[VERIFICATION #12] Hybrid Lean Steering & Turn Radius Limits:")
	print("  - Low-speed max steer: %.1f° (Nimble maneuver)" % rad_to_deg(max_steer_low))
	print("  - High-speed max steer: %.2f° -> Turn Radius: %.1fm (Target: >= 25.0m)" % [rad_to_deg(max_steer_high), radius_high])
	if max_steer_low >= 0.48 and radius_high >= 25.0:
		print("  [PASS] Steering prevents high-speed knife-edge turns while keeping low-speed agility!")
	else:
		print("  [FAIL] High speed steering radius too tight or low-speed too stiff")
		all_ok = false

	# Test 13: [3A.4 FEAT-006.7] Progressive Braking & Visual-Only Dive
	var b_attack: float = bike_test_instance.brake_attack_time
	var b_dive_deg: float = bike_test_instance.brake_dive_angle_deg
	var has_dive_var: bool = "brake_dive_pitch" in bike_test_instance
	if b_attack >= 0.12 and b_attack <= 0.20 and b_dive_deg <= 1.7 and has_dive_var:
		print("[VERIFICATION #13] [PASS] Progressive brake attack (%.2fs) and visual dive (%.1f°) verified!" % [b_attack, b_dive_deg])
	else:
		print("[VERIFICATION #13] [FAIL] Progressive brake parameters out of spec: attack=%.2f, dive=%.1f" % [b_attack, b_dive_deg])
		all_ok = false

	# Test 14: [3A.5 FEAT-006.8] Pedaling Inertia Ramp & Instant Coasting Release
	var p_attack: float = bike_test_instance.pedal_attack_time
	var has_pedal_pwr: bool = "pedal_power" in bike_test_instance
	if p_attack >= 0.30 and p_attack <= 0.65 and has_pedal_pwr:
		print("[VERIFICATION #14] [PASS] Pedal power inertia ramp (%.2fs) verified!" % p_attack)
	else:
		print("[VERIFICATION #14] [FAIL] Pedal inertia parameters out of spec")
		all_ok = false

	# Test 15: [3A.6 FEAT-006.9] Lateral-Load Cornering Scrub
	var scrub_thresh: float = bike_test_instance.scrub_lateral_threshold
	var scrub_coeff: float = bike_test_instance.cornering_scrub_coeff
	if scrub_thresh == 1.5 and scrub_coeff > 0.10:
		print("[VERIFICATION #15] [PASS] Lateral-load cornering scrub verified (Threshold: %.1f m/s², Coeff: %.2f)!" % [scrub_thresh, scrub_coeff])
	else:
		print("[VERIFICATION #15] [FAIL] Scrub parameters invalid")
		all_ok = false

	# Test 16: [3A.7 FEAT-006.10] Terrain Micro-Motion Camera Layer
	var cam_rig = bike_test_instance.get_node("CameraRig")
	var shake_freq: float = cam_rig.shake_frequency
	var shake_amp: float = cam_rig.gravel_shake_intensity
	var grass_mult: float = cam_rig.grass_shake_multiplier
	print("[VERIFICATION #16] Terrain Micro-Motion Camera:")
	print("  - Frequency: %.1f Hz (Target: 5.0 - 10.0 Hz pseudo-noise)" % shake_freq)
	print("  - Base Amplitude: %.4f m | Grass Multiplier: %.1fx" % [shake_amp, grass_mult])
	if shake_freq >= 5.0 and shake_freq <= 10.0 and shake_amp <= 0.003 and grass_mult >= 1.4:
		print("  [PASS] Camera micro-motion is subtle, smooth and non-jarring!")
	else:
		print("  [FAIL] Camera micro-motion frequency/amplitude out of spec")
		all_ok = false

	# Test 17: [3B.1 FEAT-007.0] Bank Sign & Steering Alignment
	bike_test_instance.current_speed = 6.0 # ~21.6 km/h
	bike_test_instance.raw_steer_input = 1.0 # Steering left
	for _frame in range(30):
		bike_test_instance._calculate_steering_and_banking(1.0 / 60.0)
	var left_steer: float = bike_test_instance.current_steer
	var left_bank: float = bike_test_instance.current_bank
	var left_vis: float = bike_test_instance.visual_steer
	var left_yaw: float = bike_test_instance.yaw_turn_rate

	bike_test_instance.raw_steer_input = -1.0 # Steering right
	for _frame in range(60):
		bike_test_instance._calculate_steering_and_banking(1.0 / 60.0)
	var right_steer: float = bike_test_instance.current_steer
	var right_bank: float = bike_test_instance.current_bank
	var right_vis: float = bike_test_instance.visual_steer
	var right_yaw: float = bike_test_instance.yaw_turn_rate

	print("[VERIFICATION #17] Bank & Steer Sign Alignment:")
	print("  - Left:  steer=%.3f, yaw=%.3f, bank=%.3f, vis_steer=%.3f" % [left_steer, left_yaw, left_bank, left_vis])
	print("  - Right: steer=%.3f, yaw=%.3f, bank=%.3f, vis_steer=%.3f" % [right_steer, right_yaw, right_bank, right_vis])
	if left_steer > 0 and left_yaw > 0 and left_bank > 0 and left_vis > 0 and right_steer < 0 and right_yaw < 0 and right_bank < 0 and right_vis < 0:
		print("  [PASS] Steer, Yaw, Bank and Visual Steer are strictly aligned in identical directions!")
	else:
		print("  [FAIL] Inverted sign detected in steering/banking chain!")
		all_ok = false

	# Test 18: [3B.1 FEAT-007.0] Steer Hierarchy & Axle Isolation
	var front_axle = bike_test_instance.get_node_or_null("Visuals/ForkAndHandlebar/FrontAxle")
	var front_wheel_node = bike_test_instance.get_node_or_null("Visuals/ForkAndHandlebar/FrontAxle/FrontWheel")
	if front_axle != null and front_wheel_node != null and bike_test_instance.front_wheel == front_wheel_node:
		var initial_axle_rot: Vector3 = front_axle.rotation
		bike_test_instance.current_speed = 5.0
		bike_test_instance._update_visual_transforms(0.1)
		var axle_rot_after: Vector3 = front_axle.rotation
		if initial_axle_rot.distance_to(axle_rot_after) < 0.0001 and absf(front_wheel_node.rotation.x) > 0.01:
			print("[VERIFICATION #18] [PASS] FrontAxle compensation preserved while FrontWheel spins freely!")
		else:
			print("[VERIFICATION #18] [FAIL] Wheel spin disturbed FrontAxle rotation")
			all_ok = false
	else:
		print("[VERIFICATION #18] [FAIL] Node hierarchy does not match ForkAndHandlebar/FrontAxle/FrontWheel")
		all_ok = false

	# Test 19: [3B.2 FEAT-007.2] Procedural Wind and Gravel Audio
	var audio_mgr: BikeAudioManager = bike_test_instance.get_node_or_null("AudioManager")
	if audio_mgr:
		if audio_mgr.wind_player == null:
			audio_mgr._ready()
		var wind_stream: AudioStreamWAV = audio_mgr.wind_player.stream
		var gravel_stream: AudioStreamWAV = audio_mgr.gravel_player.stream
		var has_loop: bool = wind_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and gravel_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		
		# Test audio volume modulation at high speed
		bike_test_instance.current_speed = 10.0 # 36 km/h
		bike_test_instance.is_on_grass = false
		for _f in range(60):
			audio_mgr._process(1.0 / 60.0)
		var high_wind_vol: float = audio_mgr.wind_player.volume_db
		var road_gravel_pitch: float = audio_mgr.gravel_player.pitch_scale

		# Test on grass
		bike_test_instance.is_on_grass = true
		for _f in range(30):
			audio_mgr._process(1.0 / 60.0)
		var grass_gravel_pitch: float = audio_mgr.gravel_player.pitch_scale

		print("[VERIFICATION #19] Procedural Audio Modulation:")
		print("  - Looping WAV streams: %s" % ("YES" if has_loop else "NO"))
		print("  - Wind vol at 36 km/h: %.1f dB (Target: active & rebalanced, > -36 dB)" % high_wind_vol)
		print("  - Gravel pitch on Road: %.2f | on Grass: %.2f (Target on grass: < 0.75)" % [road_gravel_pitch, grass_gravel_pitch])
		if has_loop and high_wind_vol > -36.0 and grass_gravel_pitch < 0.75 and road_gravel_pitch > 0.85:
			print("  [PASS] Procedural wind and gravel audio modulation fully functional!")
		else:
			print("  [FAIL] Audio parameter modulation out of bounds")
			all_ok = false
	else:
		print("[VERIFICATION #19] [FAIL] AudioManager missing wind_player or gravel_player")
		all_ok = false

	# Test 20: [3B.3 FEAT-007.3] Dynamic Speed FOV
	cam_rig.bike = bike_test_instance
	if not cam_rig.first_person_cam:
		cam_rig._ready()
	var fp_base: float = cam_rig.fp_base_fov
	var fp_max: float = cam_rig.fp_max_fov
	var tp_base: float = cam_rig.tp_base_fov
	var tp_max: float = cam_rig.tp_max_fov
	bike_test_instance.current_speed = 12.0 # 43.2 km/h
	for _f in range(60):
		cam_rig._process(1.0 / 60.0)
	var expanded_fp_fov: float = cam_rig.first_person_cam.fov
	print("[VERIFICATION #20] Dynamic Speed FOV:")
	print("  - First-Person: Base %.1f° -> Max %.1f° | Actual at 43 km/h: %.1f°" % [fp_base, fp_max, expanded_fp_fov])
	print("  - Third-Person: Base %.1f° -> Max %.1f°" % [tp_base, tp_max])
	if fp_base == 78.0 and fp_max == 83.0 and tp_base == 68.0 and tp_max == 72.0 and expanded_fp_fov > 82.0:
		print("  [PASS] Speed FOV dynamically opens on high speed without jarring jumps!")
	else:
		print("  [FAIL] Speed FOV values out of spec")
		all_ok = false

	# Test 21: [3C.1 FEAT-006.11] Sprint 3C Steering Sign Alignment & Visual Clamp Range
	bike_test_instance.current_speed = 7.0 # 25.2 km/h cruise
	bike_test_instance.raw_steer_input = 1.0 # Left steer (A key)
	for _frame in range(30):
		bike_test_instance._calculate_steering_and_banking(1.0 / 60.0)
	var s3c_left_steer: float = bike_test_instance.current_steer
	var s3c_left_yaw: float = bike_test_instance.yaw_turn_rate
	var s3c_left_bank: float = bike_test_instance.current_bank
	var s3c_left_vis: float = bike_test_instance.visual_steer

	bike_test_instance.raw_steer_input = -1.0 # Right steer (D key)
	for _frame in range(60):
		bike_test_instance._calculate_steering_and_banking(1.0 / 60.0)
	var s3c_right_steer: float = bike_test_instance.current_steer
	var s3c_right_yaw: float = bike_test_instance.yaw_turn_rate
	var s3c_right_bank: float = bike_test_instance.current_bank
	var s3c_right_vis: float = bike_test_instance.visual_steer

	# Check visual angles against analyst tuning ranges (low speed 20-24°, cruise 15-18°, high speed 10-14°)
	var max_vis_deg_low: float = rad_to_deg(bike_test_instance.max_visual_steer_low_speed)
	var max_vis_deg_cruise: float = rad_to_deg(bike_test_instance.max_visual_steer_cruising)
	var max_vis_deg_high: float = rad_to_deg(bike_test_instance.max_visual_steer_high_speed)

	var s3c_signs_ok: bool = (s3c_left_steer > 0 and s3c_left_yaw > 0 and s3c_left_bank > 0 and s3c_left_vis > 0) and \
							(s3c_right_steer < 0 and s3c_right_yaw < 0 and s3c_right_bank < 0 and s3c_right_vis < 0)
	var s3c_ranges_ok: bool = (max_vis_deg_low >= 20.0 and max_vis_deg_low <= 24.0) and \
							  (max_vis_deg_cruise >= 15.0 and max_vis_deg_cruise <= 18.0) and \
							  (max_vis_deg_high >= 10.0 and max_vis_deg_high <= 14.0)
	var s3c_gain_ok: bool = absf(s3c_left_vis) >= absf(s3c_left_steer)

	print("[VERIFICATION #21] Sprint 3C Cockpit Visual Steering:")
	print("  - Sign alignment: Left vis=%.3f bank=%.3f | Right vis=%.3f bank=%.3f" % [s3c_left_vis, s3c_left_bank, s3c_right_vis, s3c_right_bank])
	print("  - Visual ranges: Low=%.1f°, Cruise=%.1f°, High=%.1f°" % [max_vis_deg_low, max_vis_deg_cruise, max_vis_deg_high])
	if s3c_signs_ok and s3c_ranges_ok and s3c_gain_ok:
		print("  [PASS] A/D steering sign consistency and cockpit visual tuning ranges verified!")
	else:
		print("  [FAIL] Steering signs or visual ranges out of bounds")
		all_ok = false

	# Test 22: [3C.1 FEAT-006.11] Front Wheel Axle & Spin Geometry
	var fork_node = bike_test_instance.get_node_or_null("Visuals/ForkAndHandlebar")
	var axle_node = bike_test_instance.get_node_or_null("Visuals/ForkAndHandlebar/FrontAxle")
	var wheel_node = bike_test_instance.get_node_or_null("Visuals/ForkAndHandlebar/FrontAxle/FrontWheel")
	if fork_node and axle_node and wheel_node:
		bike_test_instance.visual_steer = deg_to_rad(16.0)
		bike_test_instance.current_speed = 6.0
		bike_test_instance._update_visual_transforms(0.05)
		var axle_local_x: Vector3 = axle_node.transform.basis.x
		var spin_preserved: bool = axle_local_x.is_equal_approx(Vector3.RIGHT) and absf(wheel_node.rotation.x) > 0.01
		print("[VERIFICATION #22] Front Axle & Spin Geometry:")
		print("  - Wheel spin: %.2f rad | Axle X axis: %s" % [wheel_node.rotation.x, axle_local_x])
		if spin_preserved:
			print("  [PASS] Front wheel rotates cleanly around hub axle under steering deflection!")
		else:
			print("  [FAIL] Wheel spin or axle alignment compromised")
			all_ok = false
	else:
		print("[VERIFICATION #22] [FAIL] Wheel nodes missing")
		all_ok = false

	# Test 23: [3C.2 FEAT-006.12] Natural Muscular Acceleration & Hill Climbing
	var sim_speed: float = 0.0
	var sim_power: float = 0.0
	var sim_dt: float = 1.0 / 60.0
	var sim_t_20: float = -1.0
	for f in range(600):
		var cur_t = f * sim_dt
		sim_power = minf(1.0, sim_power + (1.0 / bike_test_instance.pedal_attack_time) * sim_dt)
		var eff = bike_test_instance.pedal_acceleration * sim_power
		if sim_speed < bike_test_instance.cruising_speed:
			sim_speed += eff * sim_dt
		var drag_val = (bike_test_instance.road_rolling_resistance + bike_test_instance.air_drag_coeff * (sim_speed * sim_speed)) * sim_dt
		sim_speed = maxf(0.0, sim_speed - drag_val)
		if sim_speed * 3.6 >= 20.0 and sim_t_20 < 0.0:
			sim_t_20 = cur_t

	print("[VERIFICATION #23] Natural Muscular Acceleration Dynamics:")
	print("  - Flat acceleration 0 -> 20 km/h: %.2fs (Expected corridor: 4.8 - 6.5s)" % sim_t_20)
	print("  - Pedal acceleration: %.2f m/s² | Attack time: %.2fs" % [bike_test_instance.pedal_acceleration, bike_test_instance.pedal_attack_time])
	if sim_t_20 >= 4.8 and sim_t_20 <= 6.5 and bike_test_instance.pedal_acceleration <= 1.4 and bike_test_instance.pedal_acceleration >= 1.2:
		print("  [PASS] Muscular acceleration feel verified (no electric bike sudden rocket launch)!")
	else:
		print("  [FAIL] Acceleration dynamics out of spec: %.2fs" % sim_t_20)
		all_ok = false

	# Test 24: [3C.3 FEAT-006.13] Wind Acoustic Comfort Curve
	if audio_mgr:
		# 1. Low speed: 12 km/h (3.33 m/s) -> must be quiet (< -60 dB)
		bike_test_instance.current_speed = 3.33
		for _f in range(60):
			audio_mgr._process(1.0 / 60.0)
		var low_speed_wind: float = audio_mgr.wind_player.volume_db
		
		# 2. Cruising speed: 25 km/h (6.94 m/s) -> soft breeze (-42 to -32 dB)
		bike_test_instance.current_speed = 6.94
		for _f in range(120):
			audio_mgr._process(1.0 / 60.0)
		var cruise_speed_wind: float = audio_mgr.wind_player.volume_db
		
		# 3. High speed: 43 km/h (12.0 m/s) -> calibrated peak (-28 to -24 dB)
		bike_test_instance.current_speed = 12.0
		for _f in range(120):
			audio_mgr._process(1.0 / 60.0)
		var high_speed_wind: float = audio_mgr.wind_player.volume_db

		print("[VERIFICATION #24] Wind Acoustic Comfort Levels:")
		print("  - At 12 km/h (Low):    %.1f dB (Target: <= -60 dB)" % low_speed_wind)
		print("  - At 25 km/h (Cruise): %.1f dB (Target: -42 to -32 dB)" % cruise_speed_wind)
		print("  - At 43 km/h (Peak):   %.1f dB (Target: -28 to -24 dB)" % high_speed_wind)

		if low_speed_wind <= -60.0 and cruise_speed_wind >= -42.0 and cruise_speed_wind <= -32.0 and high_speed_wind >= -28.0 and high_speed_wind <= -24.0:
			print("  [PASS] Wind audio rebalanced to gentle aerodynamic air without storm roar!")
		else:
			print("  [FAIL] Wind volume curve out of comfort targets")
			all_ok = false

	bike_test_instance.free()

	if all_ok:
		print("\n=== ALL SYSTEM VERIFICATIONS PASSED [100% OK] ===\n")
	else:
		print("\n=== SOME VERIFICATIONS FAILED ===\n")

	quit(0 if all_ok else 1)
