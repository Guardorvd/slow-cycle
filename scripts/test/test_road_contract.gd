extends SceneTree

## Comprehensive Test Suite for RoadGenerationContract, RoadAirborneContract,
## and RoadValidityValidator (Sprint 5 Phase 1).
## Tests T01-T16 Synthetic Battery, Boundary Cases, Injected Faults, and Benchmark.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const Validator = preload("res://scripts/world/road_validity_validator.gd")

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — ROAD CONTRACT & VALIDATOR TEST SUITE          ")
	print("==================================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	var total_tests: int = 0
	var total_passed: int = 0

	print("[BATTERY 1] Synthetic Contract Tests T01-T16 (8 Valid, 8 Invalid)...")

	# --- VALID TESTS (T01 - T08) ---
	var t01_ok := _test_t01_straight()
	total_tests += 1; if t01_ok: total_passed += 1

	var t02_ok := _test_t02_constant_downhill()
	total_tests += 1; if t02_ok: total_passed += 1

	var t03_ok := _test_t03_switchback()
	total_tests += 1; if t03_ok: total_passed += 1

	var t04_ok := _test_t04_micro_drop()
	total_tests += 1; if t04_ok: total_passed += 1

	var t05_ok := _test_t05_short_airborne()
	total_tests += 1; if t05_ok: total_passed += 1

	var t06_ok := _test_t06_airborne_landing()
	total_tests += 1; if t06_ok: total_passed += 1

	var t07_ok := _test_t07_downhill_micro_drop()
	total_tests += 1; if t07_ok: total_passed += 1

	var t08_ok := _test_t08_downhill_airborne_recovery()
	total_tests += 1; if t08_ok: total_passed += 1

	# --- INVALID INJECTED TESTS (T09 - T16) ---
	var t09_ok := _test_t09_uncontrolled_gap()
	total_tests += 1; if t09_ok: total_passed += 1

	var t10_ok := _test_t10_excessive_airborne_distance()
	total_tests += 1; if t10_ok: total_passed += 1

	var t11_ok := _test_t11_excessive_drop_height()
	total_tests += 1; if t11_ok: total_passed += 1

	var t12_ok := _test_t12_impossible_landing_grade()
	total_tests += 1; if t12_ok: total_passed += 1

	var t13_ok := _test_t13_sharp_landing_curvature()
	total_tests += 1; if t13_ok: total_passed += 1

	var t14_ok := _test_t14_missing_landing_definition()
	total_tests += 1; if t14_ok: total_passed += 1

	var t15_ok := _test_t15_hidden_drop_sight_distance()
	total_tests += 1; if t15_ok: total_passed += 1

	var t16_ok := _test_t16_seam_faults()
	total_tests += 1; if t16_ok: total_passed += 1

	# --- BATTERY 2: EXISTING PROCEDURAL GENERATOR VERIFICATION ---
	print("\n[BATTERY 2] Validating Existing Procedural World Generation (5 Seeds)...")
	var seeds_ok := _test_existing_procedural_generator()
	total_tests += 1; if seeds_ok: total_passed += 1

	# --- BATTERY 3: PERFORMANCE BENCHMARK ---
	print("\n[BATTERY 3] Running Validator Micro-Benchmark (100 Chunks)...")
	var bench_ok := _test_validator_benchmark()
	total_tests += 1; if bench_ok: total_passed += 1

	print("\n==================================================================")
	print("                 ROAD CONTRACT TEST SUITE SUMMARY                 ")
	print("==================================================================")
	print("  TOTAL TESTS EVALUATED: %d / %d PASSED" % [total_passed, total_tests])
	print("==================================================================\n")

	var all_ok: bool = (total_passed == total_tests)
	quit(0 if all_ok else 1)

# --- T01: Straight Path ---
func _test_t01_straight() -> bool:
	var path := RoadPathDataClass.new()
	for i in range(15):
		path.append_sample(Vector3(0, 0, -i * 2.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0)
	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_GROUNDED)
	print("  - T01 Straight Path:                    %s" % ("PASS" if ok else "FAIL"))
	return ok

static func _ortho_norm(tang: Vector3) -> Vector3:
	var bitang := Vector3(-tang.z, 0.0, tang.x).normalized()
	if bitang.is_zero_approx():
		bitang = Vector3.RIGHT
	return bitang.cross(tang).normalized()

# --- T02: Constant Downhill (-6.0°) ---
func _test_t02_constant_downhill() -> bool:
	var path := RoadPathDataClass.new()
	var rad: float = deg_to_rad(-6.0)
	var tang := Vector3(0, sin(rad), -cos(rad)).normalized()
	var norm := _ortho_norm(tang)
	for i in range(15):
		var pos := tang * (i * 2.0)
		path.append_sample(pos, tang, norm, -6.0, 0.0, 4)
	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_GROUNDED)
	print("  - T02 Constant Downhill (-6.0°):        %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T03: Switchback (R = 19.0m) ---
func _test_t03_switchback() -> bool:
	var path := RoadPathDataClass.new()
	var r: float = 19.0
	var curv: float = 1.0 / r
	for i in range(20):
		var angle: float = (float(i) * 2.0) / r
		var pos := Vector3(sin(angle) * r, 0.0, -cos(angle) * r)
		var tang := Vector3(cos(angle), 0.0, sin(angle)).normalized()
		var norm := _ortho_norm(tang)
		path.append_sample(pos, tang, norm, 0.0, curv, 2)
	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_GROUNDED)
	print("  - T03 Switchback Arc (R = 19.0m):       %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T04: Micro-Drop (h = 0.25m, length = 1.5m) ---
func _test_t04_micro_drop() -> bool:
	var path := RoadPathDataClass.new()
	var t0 := Vector3(0, 0, -1); var n0 := _ortho_norm(t0)
	var t1 := Vector3(0, -0.1, -1).normalized(); var n1 := _ortho_norm(t1)
	path.append_sample(Vector3(0, 0.25, 0), t0, n0, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, 0.15, -1.5), t1, n1, -5.0, 0.0, 0, Airborne.SurfaceContactMode.MICRO_DROP)
	path.append_sample(Vector3(0, 0.0, -3.5), t0, n0, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_MICRO_DROP)
	print("  - T04 Micro-Drop (h=0.25m, L=1.5m):     %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T05: Short Airborne (h = 0.6m, length = 2.5m) ---
func _test_t05_short_airborne() -> bool:
	var path := RoadPathDataClass.new()
	var t0 := Vector3(0, 0, -1); var n0 := _ortho_norm(t0)
	var t1 := Vector3(0, -0.15, -1).normalized(); var n1 := _ortho_norm(t1)
	var t2 := Vector3(0, -0.10, -1).normalized(); var n2 := _ortho_norm(t2)
	# Approach -> Takeoff
	path.append_sample(Vector3(0, 0.6, 0), t0, n0, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	# Airborne (ds = 2.0m)
	path.append_sample(Vector3(0, 0.3, -2.0), t1, n1, -8.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Landing table (ds = 2.0m per step)
	path.append_sample(Vector3(0, 0.1, -4.0), t2, n2, -5.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)
	path.append_sample(Vector3(0, 0.0, -6.0), t0, n0, 0.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)
	path.append_sample(Vector3(0, 0.0, -8.0), t0, n0, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_AIRBORNE)
	print("  - T05 Short Airborne with Landing:      %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T06: Airborne + Dedicated Landing Table ---
func _test_t06_airborne_landing() -> bool:
	var path := RoadPathDataClass.new()
	var t_flat := Vector3(0, 0, -1); var n_flat := _ortho_norm(t_flat)
	# Approach
	for i in range(5):
		path.append_sample(Vector3(0, 0.8, -i * 2.0), t_flat, n_flat, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	# Airborne (2 samples of 2m = 4m span)
	var t_air1 := Vector3(0, -0.15, -1).normalized(); var n_air1 := _ortho_norm(t_air1)
	var t_air2 := Vector3(0, -0.20, -1).normalized(); var n_air2 := _ortho_norm(t_air2)
	path.append_sample(Vector3(0, 0.5, -10.0), t_air1, n_air1, -8.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	path.append_sample(Vector3(0, 0.2, -12.0), t_air2, n_air2, -10.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Landing table (ds = 2m, straight R >= 50m, slopes matching)
	var t_land := Vector3(0, -0.1, -1).normalized(); var n_land := _ortho_norm(t_land)
	for i in range(5):
		var z: float = -14.0 - i * 2.0
		path.append_sample(Vector3(0, -0.1 * i, z), t_land, n_land, -5.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)
	# Grounded recovery
	for i in range(5):
		var z: float = -24.0 - i * 2.0
		path.append_sample(Vector3(0, -0.5, z), t_flat, n_flat, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)

	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_AIRBORNE)
	print("  - T06 Full Airborne & Landing Chain:    %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T07: Downhill (-8°) + Micro-Drop Crest ---
func _test_t07_downhill_micro_drop() -> bool:
	var path := RoadPathDataClass.new()
	var t_down := Vector3(0, -0.14, -1).normalized(); var n_down := _ortho_norm(t_down)
	for i in range(8):
		path.append_sample(Vector3(0, -i * 0.28, -i * 2.0), t_down, n_down, -8.0, 0.0, 4, Airborne.SurfaceContactMode.GROUNDED)
	# Micro-drop crest
	var t_drop := Vector3(0, -0.18, -1).normalized(); var n_drop := _ortho_norm(t_drop)
	path.append_sample(Vector3(0, -2.6, -16.0), t_drop, n_drop, -10.0, 0.0, 4, Airborne.SurfaceContactMode.MICRO_DROP)
	# Grounded continuation
	for i in range(5):
		var z: float = -18.0 - i * 2.0
		path.append_sample(Vector3(0, -2.9 - i * 0.2, z), t_down, n_down, -8.0, 0.0, 4, Airborne.SurfaceContactMode.GROUNDED)

	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_MICRO_DROP)
	print("  - T07 Downhill + Micro-Drop Crest:      %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T08: Downhill (-10°) + Airborne + Recovery ---
func _test_t08_downhill_airborne_recovery() -> bool:
	var path := RoadPathDataClass.new()
	var t_down := Vector3(0, -0.17, -1).normalized(); var n_down := _ortho_norm(t_down)
	var t_air := Vector3(0, -0.22, -1).normalized(); var n_air := _ortho_norm(t_air)
	var t_land := Vector3(0, -0.18, -1).normalized(); var n_land := _ortho_norm(t_land)
	var t_flat := Vector3(0, 0, -1); var n_flat := _ortho_norm(t_flat)

	path.append_sample(Vector3(0, 0.0, 0.0), t_down, n_down, -10.0, 0.0, 4, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, -0.4, -2.0), t_air, n_air, -12.0, 0.0, 4, Airborne.SurfaceContactMode.AIRBORNE)
	path.append_sample(Vector3(0, -0.8, -4.0), t_land, n_land, -10.0, 0.0, 4, Airborne.SurfaceContactMode.LANDING)
	path.append_sample(Vector3(0, -1.0, -6.0), t_land, n_land, -8.0, 0.0, 4, Airborne.SurfaceContactMode.LANDING)
	path.append_sample(Vector3(0, -1.1, -8.0), t_flat, n_flat, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)

	var report = Validator.validate_segment(path)
	var ok: bool = report.is_valid and (report.segment_status == Validator.SegmentStatus.VALID_AIRBORNE)
	print("  - T08 Downhill + Airborne + Recovery:   %s" % ("PASS" if ok else "FAIL"))
	return ok

# --- T09: Invalid - Uncontrolled Gap (AIRBORNE without LANDING) ---
func _test_t09_uncontrolled_gap() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, -0.5, -2), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	path.append_sample(Vector3(0, -1.0, -4), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Ends in AIRBORNE without landing!
	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid) and (report.segment_status == Validator.SegmentStatus.INVALID_UNCONTROLLED_GAP)
	print("  - T09 Injected Uncontrolled Gap:        %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T10: Invalid - Excessive Airborne Distance (> 6.0m) ---
func _test_t10_excessive_airborne_distance() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	# Airborne span: 2 + 2 + 2 + 2 = 8m > 6.0m limit!
	for i in range(1, 5):
		path.append_sample(Vector3(0, -i * 0.2, -i * 2.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	path.append_sample(Vector3(0, -1.0, -10.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)

	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid)
	print("  - T10 Injected Excessive Airborne Dist: %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T11: Invalid - Excessive Drop Height (> 1.2m) ---
func _test_t11_excessive_drop_height() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 2.5, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	# Drop height 2.5 - 0.5 = 2.0m > 1.2m limit!
	path.append_sample(Vector3(0, 0.5, -2.5), Vector3(0, -0.6, -1).normalized(), Vector3.UP, -15.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	path.append_sample(Vector3(0, 0.0, -5.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)

	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid)
	print("  - T11 Injected Excessive Drop Height:   %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T12: Invalid - Impossible Landing Grade (Uphill +4.0°) ---
func _test_t12_impossible_landing_grade() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 0.8, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, 0.4, -2.0), Vector3(0, 0, -1), Vector3.UP, -8.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Landing ramp uphill +4.0° (flat/uphill landing from drop causes bottom-out!)
	path.append_sample(Vector3(0, 0.6, -4.0), Vector3(0, 0.1, -1).normalized(), Vector3.UP, 4.0, 0.0, 0, Airborne.SurfaceContactMode.LANDING)

	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid)
	print("  - T12 Injected Impossible Landing Slope:%s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T13: Invalid - Sharp Landing Curvature (R = 18m < 50m) ---
func _test_t13_sharp_landing_curvature() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 0.6, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, 0.3, -2.0), Vector3(0, 0, -1), Vector3.UP, -8.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Landing on a sharp curve (R = 18m, curv = 1/18)
	path.append_sample(Vector3(1.0, 0.0, -4.0), Vector3(0.5, 0, -1).normalized(), Vector3.UP, -5.0, 1.0 / 18.0, 0, Airborne.SurfaceContactMode.LANDING)

	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid)
	print("  - T13 Injected Sharp Landing Curvature: %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T14: Invalid - Missing Landing Definition (AIRBORNE directly to GROUNDED) ---
func _test_t14_missing_landing_definition() -> bool:
	var path := RoadPathDataClass.new()
	path.append_sample(Vector3(0, 0.5, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)
	path.append_sample(Vector3(0, 0.2, -2.0), Vector3(0, 0, -1), Vector3.UP, -8.0, 0.0, 0, Airborne.SurfaceContactMode.AIRBORNE)
	# Illegal FSM jump: AIRBORNE -> GROUNDED (without LANDING)
	path.append_sample(Vector3(0, 0.0, -4.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0, Airborne.SurfaceContactMode.GROUNDED)

	var report = Validator.validate_segment(path)
	var ok: bool = (not report.is_valid)
	print("  - T14 Missing Landing FSM Violation:    %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- T15: Invalid - Blind Drop Sight Distance ---
func _test_t15_hidden_drop_sight_distance() -> bool:
	var path := RoadPathDataClass.new()
	# Create sharp crest at s = 10 that completely occludes vision beyond s = 14
	path.append_sample(Vector3(0, 0.0, 0.0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0)
	path.append_sample(Vector3(0, 3.0, -10.0), Vector3(0, 0, -1), Vector3.UP, 10.0, 0.0, 0) # High crest
	path.append_sample(Vector3(0, -2.0, -20.0), Vector3(0, -0.3, -1).normalized(), Vector3.UP, -15.0, 0.0, 0) # Blind plunge
	var clear_sight: float = Validator.calculate_sight_distance_at(path, 0, "drop")
	var ok: bool = clear_sight < 25.0 # Sight is obstructed by the high crest
	print("  - T15 Sight Distance Occlusion Check:   %s (Clear dist = %.1fm)" % [("PASS" if ok else "FAIL"), clear_sight])
	return ok

# --- T16: Invalid - Seam Faults (C0 and C1) ---
func _test_t16_seam_faults() -> bool:
	var path_a := RoadPathDataClass.new()
	var path_b := RoadPathDataClass.new()
	path_a.append_sample(Vector3(0, 0, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0)
	# Injected C0 gap: 5mm (0.005m > 0.001m limit)
	path_b.append_sample(Vector3(0.005, 0, 0), Vector3(0, 0, -1), Vector3.UP, 0.0, 0.0, 0)

	var report = Validator.validate_seam(path_a, 0, path_b, 0)
	var ok: bool = (not report.is_valid) and (report.error_count > 0)
	print("  - T16 Injected Seam Tolerance Fault:    %s" % ("PASS [CORRECTLY CAUGHT]" if ok else "FAIL"))
	return ok

# --- BATTERY 2: EXISTING PROCEDURAL GENERATOR ---
func _test_existing_procedural_generator() -> bool:
	var test_seeds := [10101, 20202, 30303, 40404, 50505]
	var all_ok: bool = true

	for s in test_seeds:
		var path := RoadPathDataClass.new()
		var logic := RoadLogicClass.new(s, path)
		for _c in range(15): # 15 chunks = 375 samples = 750m
			logic.plan_next_chunk()

		var report = Validator.validate_segment(path)
		if not report.is_valid:
			all_ok = false
			print("    [FAIL] Seed %d reported violations: %d errors" % [s, report.error_count])
		else:
			print("    [PASS] Seed %d: 15 chunks (%.1fm) 100%% compliant with Contract v5.1.0" % [s, path.get_total_distance()])

	return all_ok

# --- BATTERY 3: BENCHMARK ---
func _test_validator_benchmark() -> bool:
	var path := RoadPathDataClass.new()
	var logic := RoadLogicClass.new(99999, path)
	for _c in range(100): # 100 chunks = 2500 samples = 5.0 km
		logic.plan_next_chunk()

	var t0: int = Time.get_ticks_usec()
	var report = Validator.validate_segment(path)
	var t1: int = Time.get_ticks_usec()
	var elapsed_ms: float = float(t1 - t0) / 1000.0

	print("    Benchmarked 100 chunks (2500 samples, 5.0 km): %.3f ms (Target: < 10.0 ms)" % elapsed_ms)
	var ok: bool = (elapsed_ms < 10.0) and report.is_valid
	print("    Benchmark Result:                     %s" % ("PASS" if ok else "FAIL"))
	return ok
