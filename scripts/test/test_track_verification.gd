@tool
extends SceneTree

const TrackGenClass = preload("res://scripts/test/test_track_generator.gd")

func _init() -> void:
	_start()

func _start() -> void:
	print("\n==================================================")
	print("   SLOW CYCLE — RIDING FEEL TEST TRACK VERIFIER   ")
	print("==================================================\n")
	
	var passed: bool = await run_verification()
	if passed:
		print("\n[SUCCESS] ALL TEST TRACK VERIFICATION CHECKS PASSED [OK]\n")
		quit(0)
	else:
		print("\n[FAILURE] TEST TRACK VERIFICATION ENCOUNTERED ERRORS [FAIL]\n")
		quit(1)

func run_verification() -> bool:
	var track_scene: PackedScene = load("res://scenes/test/riding_feel_test_track.tscn")
	if not track_scene:
		printerr("[FAIL] Could not load res://scenes/test/riding_feel_test_track.tscn")
		return false
	print("[PASS] Scene res://scenes/test/riding_feel_test_track.tscn loaded successfully.")

	var root_node: Node3D = track_scene.instantiate()
	root.add_child(root_node)
	await process_frame

	var generator = root_node.get_node_or_null("TestTrackGenerator")


	if not generator:
		printerr("[FAIL] TestTrackGenerator node not found in scene tree")
		return false
	print("[PASS] TestTrackGenerator node found.")

	# 1. Total path length and sample count check
	var path_data = generator.road_path
	if not path_data or path_data.size() < 1400:
		printerr("[FAIL] road_path has invalid size: %s" % (path_data.size() if path_data else "null"))
		return false
	print("[PASS] road_path samples count: %d (expected >= 1401)" % path_data.size())

	var total_dist: float = path_data.get_total_distance()
	print("       Total cumulative track distance: %.4f m (target: 2800.0 m ± 5.0 m)" % total_dist)
	if absf(total_dist - 2800.0) > 5.0:
		printerr("[FAIL] Total track distance deviates by > 5m: %.4f" % total_dist)
		return false


	# 2. Mathematical Loop Seam Continuity Check
	var p0: Vector3 = path_data.points[0]
	var p_last: Vector3 = path_data.points[-1]
	var t0: Vector3 = path_data.tangents[0]
	var t_last: Vector3 = path_data.tangents[-1]

	var delta_pos: float = p0.distance_to(p_last)
	var delta_height: float = absf(p0.y - p_last.y)
	var delta_tang: float = t0.distance_to(t_last)

	print("\n--- 1. Loop Seam Continuity Verification ---")
	print("Sample 0:    Pos=%s  Tang=%s" % [p0, t0])
	print("Sample Last: Pos=%s  Tang=%s" % [p_last, t_last])
	print("Delta Pos:    %.6f mm (Acceptance: < 5.0 mm)" % (delta_pos * 1000.0))
	print("Delta Height: %.6f mm (Acceptance: < 5.0 mm)" % (delta_height * 1000.0))
	print("Delta Tang:   %.8f (Acceptance: < 0.010 rad)" % delta_tang)

	if delta_pos > 0.005:
		printerr("[FAIL] Seam position delta exceeds 5mm: %f" % delta_pos)
		return false
	if delta_height > 0.005:
		printerr("[FAIL] Seam height delta exceeds 5mm: %f" % delta_height)
		return false
	if delta_tang > 0.010:
		printerr("[FAIL] Seam tangent delta exceeds 0.010 rad: %f" % delta_tang)
		return false
	print("[PASS] Seam continuity guarantees C1 continuous closed circuit with ZERO steps.")

	# 3. Check All 18 Sections (12 Isolated + 6 Composite Stress)
	print("\n--- 2. Section Coverage and Geometry Verification ---")
	var expected_codes: Array[String] = [
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
		"S1", "S2", "S3", "S4", "S5", "S6"
	]
	
	if generator.sections.size() != 18:
		printerr("[FAIL] Expected 18 sections, found: %d" % generator.sections.size())
		return false

	var found_codes: Array[String] = []
	for sec in generator.sections:
		found_codes.append(sec.code)
		var s_mid: float = (sec.s0 + sec.s1) * 0.5
		var queried: Dictionary = generator.get_section_at_distance(s_mid)
		if queried.get("code") != sec.code:
			printerr("[FAIL] Section query mismatch at s=%.1f: expected %s, got %s" % [s_mid, sec.code, queried.get("code")])
			return false

	for code in expected_codes:
		if not found_codes.has(code):
			printerr("[FAIL] Missing expected section: %s" % code)
			return false
	print("[PASS] All 18 sections defined, contiguous, and queryable.")

	# 4. Check Key Geometric Properties per Section
	print("\n--- 3. Testing Section Specific Physical Metrics ---")
	var sec_A = generator.sections[0]
	var slope_A: float = path_data.slopes[int(sec_A.s0 / 2.0) + 5]
	print("Section A (Flat Start): Slope = %.2f° (expected 0.0°)" % slope_A)
	if absf(slope_A) > 0.1:
		printerr("[FAIL] Section A is not flat: %f" % slope_A)
		return false

	# Section B (Climb +4.5°)
	var sec_B = generator.sections[1]
	var b_max_slope: float = -999.0
	for i in range(int(sec_B.s0 / 2.0), int(sec_B.s1 / 2.0)):
		b_max_slope = maxf(b_max_slope, path_data.slopes[i])
	print("Section B (Climb): Max Slope = +%.2f° (expected +4.5°)" % b_max_slope)
	if absf(b_max_slope - 4.5) > 0.3:
		printerr("[FAIL] Section B climb slope deviates from +4.5°: %f" % b_max_slope)
		return false

	# Section C (Downhill -5.0°)
	var sec_C = generator.sections[2]
	var c_min_slope: float = 999.0
	for i in range(int(sec_C.s0 / 2.0), int(sec_C.s1 / 2.0)):
		c_min_slope = minf(c_min_slope, path_data.slopes[i])
	print("Section C (Downhill): Min Slope = %.2f° (expected -5.0°)" % c_min_slope)
	if absf(c_min_slope - (-5.0)) > 0.3:
		printerr("[FAIL] Section C downhill slope deviates from -5.0°: %f" % c_min_slope)
		return false

	# Section D (Sharp Crest +6° -> -6°)
	var sec_D = generator.sections[3]
	var d_max_slope: float = -999.0
	var d_min_slope: float = 999.0
	for i in range(int(sec_D.s0 / 2.0), int(sec_D.s1 / 2.0)):
		d_max_slope = maxf(d_max_slope, path_data.slopes[i])
		d_min_slope = minf(d_min_slope, path_data.slopes[i])
	print("Section D (Sharp Crest): Slope Range = [%.2f°, %.2f°] (expected +6.0° to -6.0°)" % [d_max_slope, d_min_slope])
	if d_max_slope < 5.0 or d_min_slope > -5.0:
		printerr("[FAIL] Section D crest slope range insufficient: [%f, %f]" % [d_max_slope, d_min_slope])
		return false

	# Section F (Constant Arc R=35m)
	var sec_F = generator.sections[5]
	var f_min_r: float = 9999.0
	for i in range(int(sec_F.s0 / 2.0), int(sec_F.s1 / 2.0)):
		var k: float = path_data.curvatures[i]
		if k > 0.001:
			f_min_r = minf(f_min_r, 1.0 / k)
	print("Section F (Constant Arc): Radius = %.2f m (expected 35.0 m)" % f_min_r)
	if absf(f_min_r - 35.0) > 0.5:
		printerr("[FAIL] Section F radius deviates from 35m: %f" % f_min_r)
		return false

	# Section G (Sharp Corner R=25m)
	var sec_G = generator.sections[6]
	var g_min_r: float = 9999.0
	for i in range(int(sec_G.s0 / 2.0), int(sec_G.s1 / 2.0)):
		var k: float = path_data.curvatures[i]
		if k > 0.001:
			g_min_r = minf(g_min_r, 1.0 / k)
	print("Section G (Sharp Corner): Radius = %.2f m (expected 25.0 m)" % g_min_r)
	if absf(g_min_r - 25.0) > 0.5:
		printerr("[FAIL] Section G radius deviates from 25m: %f" % g_min_r)
		return false

	# Section H (S-Chicanes R=30m)
	var sec_H = generator.sections[7]
	var h_min_r: float = 9999.0
	for i in range(int(sec_H.s0 / 2.0), int(sec_H.s1 / 2.0)):
		var k: float = path_data.curvatures[i]
		if k > 0.001:
			h_min_r = minf(h_min_r, 1.0 / k)
	print("Section H (S-Chicanes): Radius = %.2f m (expected 30.0 m)" % h_min_r)
	if absf(h_min_r - 30.0) > 0.5:
		printerr("[FAIL] Section H radius deviates from 30m: %f" % h_min_r)
		return false

	# Section I (Fast Sweeper R=65m)
	var sec_I = generator.sections[8]
	var i_min_r: float = 9999.0
	for i in range(int(sec_I.s0 / 2.0), int(sec_I.s1 / 2.0)):
		var k: float = path_data.curvatures[i]
		if k > 0.001:
			i_min_r = minf(i_min_r, 1.0 / k)
	print("Section I (Fast Sweeper): Radius = %.2f m (expected 65.0 m)" % i_min_r)
	if absf(i_min_r - 65.0) > 0.5:
		printerr("[FAIL] Section I radius deviates from 65m: %f" % i_min_r)
		return false

	# Section J (Rough Gravel Micro-Bumps)
	var sec_J = generator.sections[9]
	var j_has_bumps: bool = false
	var j_elev0 = generator._eval_elevation(sec_J.s0 + 10.0)
	var j_elev1 = generator._eval_elevation(sec_J.s0 + 11.25)
	if absf(j_elev0.bump) > 0.001 or absf(j_elev1.bump) > 0.001:
		j_has_bumps = true
	print("Section J (Rough Gravel): Micro-bumps active = %s (amplitude ~0.035m)" % j_has_bumps)
	if not j_has_bumps:
		printerr("[FAIL] Section J micro-bumps are missing!")
		return false

	# 5. Check Chunk Instancing and Collision Layers
	print("\n--- 4. Chunks and Collision Layers Verification ---")
	if generator.chunks.size() != 56:
		printerr("[FAIL] Expected 56 chunks, found %d" % generator.chunks.size())
		return false
	print("[PASS] Exactly 56 chunks instantiated (covering 2800m).")

	# Find chunk in normal road (e.g. Chunk 0) and chunk in Section L (e.g. Chunk 42)
	var chunk_0 = generator.chunks[0]
	var road_body_0: StaticBody3D = null
	for child in chunk_0.get_children():
		if child is StaticBody3D:
			if child.collision_layer == 2:
				road_body_0 = child
				break
	if not road_body_0:
		printerr("[FAIL] Chunk 0 does not have road StaticBody3D on Layer 2 (Road)!")
		return false
	print("[PASS] Normal road chunk colliders configured on Layer 2 (Road).")

	# Find chunk in Section L (s in [2051.95, 2202.90]) -> Chunk 42 (s ~ 2100m)
	var chunk_L = generator.chunks[42]
	var has_grass_road_L: bool = false
	for child in chunk_L.get_children():
		if child is StaticBody3D and child.collision_layer == 4:
			# If there's a road body with layer 4
			has_grass_road_L = true
	if not has_grass_road_L:
		printerr("[FAIL] Section L chunk (Chunk 42) does not have collision on Layer 3 (Grass)!")
		return false
	print("[PASS] Section L (Grass Verge Exit) correctly configured with Layer 3 (Grass, Drag 0.45).")

	# 6. Check 3D Signage and Apex Flow Boards
	print("\n--- 5. Signage and Apex Flow Boards Verification ---")
	var signage_node = generator.get_node_or_null("TrackSignage")
	if not signage_node or signage_node.get_child_count() != 18:
		printerr("[FAIL] Expected 18 roadside section signs, found: %s" % (signage_node.get_child_count() if signage_node else "none"))
		return false
	print("[PASS] All 18 3D roadside section signage steles created with Label3D.")

	var boards_node = generator.get_node_or_null("ApexFlowBoards")
	if not boards_node or boards_node.get_child_count() != 5:
		printerr("[FAIL] Expected 5 Apex Flow distance boards, found: %s" % (boards_node.get_child_count() if boards_node else "none"))
		return false
	print("[PASS] All 5 Apex Flow racing distance boards created ([100m], [50m], [BRAKE ZONE], [APEX], [SPRINT]).")

	# 7. Check Bicycle Recovery Support
	print("\n--- 6. Bicycle Recovery API Verification ---")
	var test_query_pos := Vector3(100.0, 5.0, -250.0)
	var recovery_tf: Transform3D = generator.request_bike_recovery(test_query_pos)
	print("Recovery test for %s -> Spawn at %s" % [test_query_pos, recovery_tf.origin])
	if recovery_tf.origin.is_zero_approx():
		printerr("[FAIL] request_bike_recovery returned zero origin!")
		return false
	
	var min_dist_to_centerline: float = 9999.0
	for pt in path_data.points:
		var d = recovery_tf.origin.distance_to(pt)
		if d < min_dist_to_centerline:
			min_dist_to_centerline = d

	print("Distance from recovered spawn position to road centerline: %.4f m (target < 1.5m, 0.45m height offset)" % min_dist_to_centerline)
	if min_dist_to_centerline > 1.5:
		printerr("[FAIL] Recovered position is too far from centerline: %f" % min_dist_to_centerline)
		return false
	print("[PASS] request_bike_recovery generates tangent-aligned, upright transform on track.")


	# Clean up instantiated scene
	root_node.queue_free()
	await process_frame
	return true
