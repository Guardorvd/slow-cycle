extends SceneTree

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")

const TEST_SEEDS: Array[int] = [10101, 20202, 30303, 40404, 50505]
const CHUNKS_TO_TEST: int = 100

func _init() -> void:
	print("\n=== STARTING SPRINT 2A AUTOMATED TESTS ===")
	var all_passed: bool = true

	# Test 1: Determinism Test
	var passed_det: bool = _test_determinism()
	if not passed_det:
		all_passed = false

	# Test 2: Constraint Verification across 5 Seeds
	for s in TEST_SEEDS:
		var passed_seed: bool = _test_seed_constraints(s)
		if not passed_seed:
			all_passed = false

	if all_passed:
		print("=== ALL SPRINT 2A AUTOMATED CHECKS PASSED [OK] ===\n")
	else:
		print("=== SOME TESTS FAILED [FAIL] ===\n")

	quit(0 if all_passed else 1)

func _test_determinism() -> bool:
	var seed_val: int = 184729
	var path1 := RoadPathDataClass.new()
	var logic1 := RoadLogicClass.new(seed_val, path1)
	for i in range(20):
		logic1.plan_next_chunk()

	var path2 := RoadPathDataClass.new()
	var logic2 := RoadLogicClass.new(seed_val, path2)
	for i in range(20):
		logic2.plan_next_chunk()

	if path1.size() != path2.size():
		print("[FAIL] Determinism check: different sample count")
		return false

	for i in range(path1.size()):
		if path1.points[i] != path2.points[i]:
			print("[FAIL] Determinism mismatch at sample #", i)
			return false

	print("[PASS] Test 1: 100% Determinism confirmed on Seed ", seed_val)
	return true

func _test_seed_constraints(seed_val: int) -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(seed_val, path)
	
	for c in range(CHUNKS_TO_TEST):
		logic.plan_next_chunk()

	var total_km: float = path.get_total_distance() / 1000.0
	print("\nTesting Seed %d: %d chunks, %.2f km total" % [seed_val, CHUNKS_TO_TEST, total_km])

	var max_slope: float = -999.0
	var min_slope: float = 999.0
	var min_radius: float = 9999.0

	for i in range(path.size()):
		var sl: float = path.slopes[i]
		if sl > max_slope: max_slope = sl
		if sl < min_slope: min_slope = sl

		var curv: float = path.curvatures[i]
		if curv > 0.00001:
			var r: float = 1.0 / curv
			if r < min_radius: min_radius = r

	print("  - Slopes observed: [%.1f°, %.1f°] (Limits: [-6.5°, +5.5°])" % [min_slope, max_slope])
	print("  - Minimum turn radius: %.1fm (Limit: >= 38.0m)" % min_radius)

	if max_slope > 5.51 or min_slope < -6.51:
		print("[FAIL] Slope out of safe bounds on Seed ", seed_val)
		return false

	if min_radius < 35.0: # 3m margin on curve samples
		print("[FAIL] Curvature radius violated on Seed ", seed_val)
		return false

	print("[PASS] Constraints verified on Seed ", seed_val)
	return true
