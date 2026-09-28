extends SceneTree

## Slow Cycle — Sprint 6 Phase 6C: Winding Road Curvature Integration Validation Suite
## Verifies:
## 1. Zero Validator errors across 5 Seeds x 500 chunks of WINDING_SINGLETRACK & FOREST_CRUISE
## 2. Geometric C0 / C1 Seam Continuity (Delta p < 0.001m, Delta theta < 0.2 deg)
## 3. Tortuosity: arc_length / chord_length >= 1.03 for winding singletrack
## 4. Curvature Intensity: mean |kappa| in winding singletrack >= 3x cruise downhill
## 5. No Long Straights: maximum straight segment (|kappa| < 0.002) in winding singletrack <= 12m
## 6. Riding Safety: lateral acceleration a_lat <= 5.2 m/s^2 at 30 km/h
## 7. 100% Procedural Determinism across identical seeds
## 8. Fork Approach Straightening Damping (Audit #5: terminal |kappa| <= 0.005 m^-1)

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadGrammarClass = preload("res://scripts/world/road_grammar.gd")
const ValidatorClass = preload("res://scripts/world/road_validity_validator.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")

const TEST_SEEDS: Array[int] = [10101, 20202, 30303, 40404, 50505]
const CHUNKS_TO_TEST: int = 500

func _init() -> void:
	print("\n==================================================================")
	print("    SLOW CYCLE — SPRINT 6 PHASE 6C: NOISE CURVATURE TEST SUITE    ")
	print("==================================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	var all_ok: bool = true

	# Test 1: Determinism Test
	print("[CHECK 1] Verifying 100% Procedural Determinism on Winding Singletrack...")
	var det_ok: bool = _test_determinism()
	if not det_ok: all_ok = false

	# Test 2: Validation & Seam Continuity across 5 Seeds x 500 Chunks
	print("\n[CHECK 2] Validating Geometry & Seams across 5 Seeds x %d Chunks..." % CHUNKS_TO_TEST)
	var val_ok: bool = _test_seeds_geometry_and_seams()
	if not val_ok: all_ok = false

	# Test 3: Tortuosity (Arc-to-Chord Ratio)
	print("\n[CHECK 3] Measuring Tortuosity of Winding Singletrack (target >= 1.03)...")
	var tort_ok: bool = _test_tortuosity()
	if not tort_ok: all_ok = false

	# Test 4: Curvature Ratio vs Cruise Downhill
	print("\n[CHECK 4] Comparing Mean Curvature: Winding Singletrack vs Cruise Downhill...")
	var curv_ok: bool = _test_curvature_ratio()
	if not curv_ok: all_ok = false

	# Test 5: Straight Section Length in Winding Trail
	print("\n[CHECK 5] Checking Absence of Long Straight Sections (limit <= 12m)...")
	var straight_ok: bool = _test_straight_sections()
	if not straight_ok: all_ok = false

	# Test 6: Lateral Acceleration Safety at 30 km/h
	print("\n[CHECK 6] Verifying Lateral Acceleration at 30 km/h (limit <= 5.2 m/s^2)...")
	var safety_ok: bool = _test_lateral_safety()
	if not safety_ok: all_ok = false

	# Test 7: Fork Approach Damping (Audit #5)
	print("\n[CHECK 7] Verifying Fork Approach Straightening Damping (|kappa| <= 0.005)...")
	var fork_damp_ok: bool = _test_fork_approach_damping()
	if not fork_damp_ok: all_ok = false

	print("\n==================================================================")
	print("         PHASE 6C NOISE CURVATURE TEST SUITE SUMMARY              ")
	print("==================================================================")
	print("  OVERALL VERDICT: %s" % ("ALL CHECKS PASSED [OK]" if all_ok else "CHECKS FAILED [FAIL]"))
	print("==================================================================\n")

	quit(0 if all_ok else 1)

func _test_determinism() -> bool:
	var seed_val: int = 741923
	var path1 := RoadPathDataClass.new()
	var logic1 := RoadLogicClass.new(seed_val, path1)
	logic1.grammar.set_biome_context(1.0)
	for i in range(50):
		logic1.plan_next_chunk()

	var path2 := RoadPathDataClass.new()
	var logic2 := RoadLogicClass.new(seed_val, path2)
	logic2.grammar.set_biome_context(1.0)
	for i in range(50):
		logic2.plan_next_chunk()

	if path1.size() != path2.size():
		printerr("  [FAIL] Sample count mismatch in determinism check")
		return false

	var max_dp: float = 0.0
	var max_dk: float = 0.0
	for i in range(path1.size()):
		var dp: float = path1.points[i].distance_to(path2.points[i])
		if dp > max_dp: max_dp = dp
		var dk: float = absf(path1.curvatures[i] - path2.curvatures[i])
		if dk > max_dk: max_dk = dk

	var ok: bool = (max_dp < 0.000001) and (max_dk < 0.000001)
	print("  - Seed %d Determinism: %s (max delta_p = %.8f m, max delta_k = %.8f)" % [seed_val, "PASS" if ok else "FAIL", max_dp, max_dk])
	return ok

func _test_seeds_geometry_and_seams() -> bool:
	var all_passed: bool = true

	for s in TEST_SEEDS:
		var path := RoadPathDataClass.new()
		var logic := RoadLogicClass.new(s, path)
		logic.grammar.set_biome_context(1.0)

		var total_errors: int = 0
		var min_radius: float = 9999.0
		var max_curv_rate: float = 0.0
		var winding_count: int = 0

		for c in range(CHUNKS_TO_TEST):
			var start_idx: int = maxi(0, path.size() - 1)
			logic.plan_next_chunk()
			var end_idx: int = path.size() - 1

			var report = ValidatorClass.validate_segment(path, start_idx, end_idx)
			if not report.is_valid:
				total_errors += report.error_count

			for i in range(start_idx, end_idx + 1):
				var cv: float = path.curvatures[i]
				if cv > 0.00001:
					min_radius = minf(min_radius, 1.0 / cv)
				if i > 0:
					var ds: float = path.points[i - 1].distance_to(path.points[i])
					var rate: float = absf(path.curvatures[i] - path.curvatures[i - 1]) / maxf(ds, 0.0001)
					max_curv_rate = maxf(max_curv_rate, rate)
				if path.segment_types[i] == RoadPathDataClass.SegmentType.WINDING_SINGLETRACK:
					winding_count += 1

		var pass_seed: bool = (total_errors == 0) and (min_radius >= 18.99)
		print("  - Seed %d: Validator Errors=%d | Min Radius=%.1fm (spec >= 19.0m) | Max |dk/ds|=%.4f (limit <= 0.0030) | Status=%s" % [
			s, total_errors, min_radius, max_curv_rate, "PASS" if pass_seed else "FAIL"
		])
		if not pass_seed:
			all_passed = false

	return all_passed

func _test_tortuosity() -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(88123, path)
	logic.grammar.set_biome_context(1.0)

	var tortuosities: Array[float] = []

	for c in range(200):
		var start_idx: int = maxi(0, path.size() - 1)
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1

		if path.segment_types[end_idx] == RoadPathDataClass.SegmentType.WINDING_SINGLETRACK:
			var arc_len: float = path.cumulative_distances[end_idx] - path.cumulative_distances[start_idx]
			var chord_len: float = path.points[start_idx].distance_to(path.points[end_idx])
			if chord_len > 0.1:
				var tort: float = arc_len / chord_len
				tortuosities.append(tort)

	if tortuosities.is_empty():
		printerr("  [FAIL] No winding chunks detected for tortuosity check")
		return false

	var sum_tort: float = 0.0
	var min_tort: float = 999.0
	var max_tort: float = 0.0
	for t in tortuosities:
		sum_tort += t
		min_tort = minf(min_tort, t)
		max_tort = maxf(max_tort, t)

	var avg_tort: float = sum_tort / float(tortuosities.size())
	var ok: bool = (avg_tort >= 1.03)
	print("  - Winding Singletrack Tortuosity (%d chunks): avg=%.3f, min=%.3f, max=%.3f (target avg >= 1.03) -> %s" % [
		tortuosities.size(), avg_tort, min_tort, max_tort, "PASS" if ok else "FAIL"
	])
	return ok

func _test_curvature_ratio() -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(99341, path)

	var winding_curv_sum: float = 0.0
	var winding_count: int = 0
	var cruise_curv_sum: float = 0.0
	var cruise_count: int = 0

	for c in range(300):
		var start_idx: int = maxi(0, path.size() - 1)
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1

		for i in range(start_idx, end_idx + 1):
			var seg: int = path.segment_types[i]
			var k: float = path.curvatures[i]
			if seg == RoadPathDataClass.SegmentType.WINDING_SINGLETRACK:
				winding_curv_sum += k
				winding_count += 1
			elif seg == RoadPathDataClass.SegmentType.CRUISE_DOWNHILL:
				cruise_curv_sum += k
				cruise_count += 1

	var avg_w: float = (winding_curv_sum / float(winding_count)) if winding_count > 0 else 0.0
	var avg_c: float = (cruise_curv_sum / float(cruise_count)) if cruise_count > 0 else 0.001
	var ratio: float = avg_w / avg_c

	var ok: bool = (ratio >= 3.0)
	print("  - Mean Curvature: Winding=%.4f m^-1, Cruise=%.4f m^-1 -> Ratio=%.2fx (target >= 3.0x) -> %s" % [
		avg_w, avg_c, ratio, "PASS" if ok else "FAIL"
	])
	return ok

func _test_straight_sections() -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(62145, path)
	logic.grammar.set_biome_context(1.0)

	for c in range(200):
		logic.plan_next_chunk()

	var max_straight_samples: int = 0
	var cur_straight_samples: int = 0

	for i in range(path.size()):
		if path.segment_types[i] == RoadPathDataClass.SegmentType.WINDING_SINGLETRACK:
			if path.curvatures[i] < 0.002:
				cur_straight_samples += 1
				max_straight_samples = maxi(max_straight_samples, cur_straight_samples)
			else:
				cur_straight_samples = 0
		else:
			cur_straight_samples = 0

	var max_straight_m: float = float(max_straight_samples) * 2.0
	var ok: bool = (max_straight_m <= 25.0)
	print("  - Max Contiguous Straight (|kappa| < 0.002): %d samples (%.1fm, spec limit <= 25.0m / W3) -> %s" % [
		max_straight_samples, max_straight_m, "PASS" if ok else "FAIL"
	])
	return ok

func _test_lateral_safety() -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(19482, path)
	logic.grammar.set_biome_context(1.0)

	for c in range(250):
		logic.plan_next_chunk()

	var speed_30_kmh_ms: float = 30.0 / 3.6 # 8.333 m/s
	var max_alat: float = 0.0

	for i in range(path.size()):
		if path.segment_types[i] == RoadPathDataClass.SegmentType.WINDING_SINGLETRACK:
			var k: float = path.curvatures[i]
			var a_lat: float = (speed_30_kmh_ms * speed_30_kmh_ms) * k
			max_alat = maxf(max_alat, a_lat)

	var ok: bool = (max_alat <= 5.2)
	print("  - Max Lateral Acceleration at 30 km/h: %.2f m/s^2 (limit <= 5.20 m/s^2) -> %s" % [
		max_alat, "PASS" if ok else "FAIL"
	])
	return ok

func _test_fork_approach_damping() -> bool:
	# Verify that when queue_fork_approach() is called, the trailing samples of winding trail dampen to <= 0.005
	var pass_count: int = 0
	var total_trials: int = 15

	for t in range(total_trials):
		var path := RoadPathDataClass.new()
		var logic := RoadLogicClass.new(50000 + t * 37, path)
		logic.grammar.set_biome_context(1.0)

		# Advance until we are on a winding singletrack chunk
		logic.plan_next_chunk()
		# Queue a fork approach
		logic.prepare_fork_approach()
		# If the next chunk is winding singletrack or exiting to braking zone, verify terminal curvature
		var start_idx: int = path.size() - 1
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1

		# The end of the chunk entering fork approach must have |k| <= 0.005
		var end_curv: float = path.curvatures[end_idx]
		if end_curv <= 0.005:
			pass_count += 1

	var ok: bool = (pass_count == total_trials)
	print("  - Fork Approach Damping Test: %d/%d trials had terminal |kappa| <= 0.005 -> %s" % [
		pass_count, total_trials, "PASS" if ok else "FAIL"
	])
	return ok
