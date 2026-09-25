extends SceneTree

## Slow Cycle — Fork Topology & Branch Decision Model Test Suite (FEAT-014.3)
## Verifies 4-phase decision FSM, multi-factor intent evaluation, sign consistency,
## hard-lock ambiguity fallback, FPS invariance, speed scaling, mirrored fork symmetry,
## and variable road width geometry.

const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const RoadMathClass = preload("res://scripts/world/road_math.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadGraphClass = preload("res://scripts/world/road_graph.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — FORK DECISION & GEOMETRY TEST SUITE           ")
	print("==================================================================\n")

	test_road_width_geometry_and_path_data()
	test_sign_and_factor_consistency()
	test_fsm_phases_and_preview_reversibility()
	test_hard_lock_and_dead_center_fallback()
	test_fps_invariance()
	test_speed_invariance_and_stationary_guard()
	test_mirrored_fork_symmetry()

	print("\n==================================================================")
	print("                  TEST SUITE SUMMARY                              ")
	print("==================================================================")
	print("  TOTAL ASSERTIONS : %d" % total_assertions)
	print("  PASSED           : %d" % passed_assertions)
	print("  FAILED           : %d" % failed_assertions)
	if failed_assertions == 0:
		print("  OVERALL VERDICT  : ALL CHECKS PASSED [OK]")
		print("==================================================================\n")
		quit(0)
	else:
		print("  OVERALL VERDICT  : SUITE FAILED WITH %d DEFECTS [FAIL]" % failed_assertions)
		print("==================================================================\n")
		quit(1)

func assert_true(condition: bool, description: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		print("  [PASS] %s" % description)
	else:
		failed_assertions += 1
		print("  [FAIL] %s" % description)

func assert_almost_equal(val: float, expected: float, tol: float, description: String) -> void:
	total_assertions += 1
	var delta: float = absf(val - expected)
	if delta <= tol:
		passed_assertions += 1
		print("  [PASS] %s (val=%.5f, exp=%.5f, delta=%.6f)" % [description, val, expected, delta])
	else:
		failed_assertions += 1
		print("  [FAIL] %s (val=%.5f, exp=%.5f, delta=%.6f > tol=%.6f)" % [description, val, expected, delta, tol])

# ==============================================================================
# TEST 1: ROAD WIDTH GEOMETRY & PATH DATA CHANNEL
# ==============================================================================
func test_road_width_geometry_and_path_data() -> void:
	print("--- Running Test 1: Road Width Geometry & Path Data ---")

	# 1. C1 Smoothstep Width Profile
	var w_far: float = RoadMathClass.compute_fork_width(-30.0, 25.0, 1.8, 3.6)
	assert_almost_equal(w_far, 1.8, 0.001, "Width far upstream is singletrack 1.8m")

	var w_start: float = RoadMathClass.compute_fork_width(-25.0, 25.0, 1.8, 3.6)
	assert_almost_equal(w_start, 1.8, 0.001, "Width at start of expansion (-25m) is 1.8m")

	var w_mid: float = RoadMathClass.compute_fork_width(-12.5, 25.0, 1.8, 3.6)
	assert_almost_equal(w_mid, 2.7, 0.01, "Width halfway through expansion (-12.5m) is 2.7m")

	var w_fork: float = RoadMathClass.compute_fork_width(0.0, 25.0, 1.8, 3.6)
	assert_almost_equal(w_fork, 3.6, 0.001, "Width at fork (0m) is 3.6m")

	var w_past: float = RoadMathClass.compute_fork_width(10.0, 25.0, 1.8, 3.6)
	assert_almost_equal(w_past, 3.6, 0.001, "Width downstream (> 0m) remains 3.6m")

	# Numerical derivative check: dW/ds at -25m and 0m must be approx 0 (C1 continuity)
	var eps: float = 0.001
	var deriv_start: float = (RoadMathClass.compute_fork_width(-25.0 + eps) - RoadMathClass.compute_fork_width(-25.0)) / eps
	assert_almost_equal(deriv_start, 0.0, 0.01, "dW/ds at s=-25m is approx 0.0 (C1 flat entrance)")

	var deriv_end: float = (RoadMathClass.compute_fork_width(0.0) - RoadMathClass.compute_fork_width(-eps)) / eps
	assert_almost_equal(deriv_end, 0.0, 0.01, "dW/ds at s=0m is approx 0.0 (C1 flat junction)")

	# 2. Branch Centerline Offset Profile
	var off_pre: float = RoadMathClass.compute_fork_branch_center_offset(-5.0, 15.0, 2.5)
	assert_almost_equal(off_pre, 0.0, 0.001, "Branch offset upstream is 0.0m")

	var off_mid: float = RoadMathClass.compute_fork_branch_center_offset(7.5, 15.0, 2.5)
	assert_almost_equal(off_mid, 1.25, 0.05, "Branch offset halfway (7.5m) is approx 1.25m")

	var off_end: float = RoadMathClass.compute_fork_branch_center_offset(15.0, 15.0, 2.5)
	assert_almost_equal(off_end, 2.5, 0.001, "Branch offset at end (15.0m) is 2.5m")

	# 3. RoadPathData road_widths array synchronization
	var rpd = RoadPathDataClass.new()
	rpd.append_sample(Vector3(0, 0, 0), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 4.0)
	rpd.append_sample(Vector3(0, 0, -10), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 6.0)
	rpd.append_sample(Vector3(0, 0, -20), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 8.0)
	rpd.append_sample(Vector3(0, 0, -30), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 10.0)

	assert_true(rpd.road_widths.size() == rpd.points.size(), "RoadPathData road_widths.size == points.size")
	assert_almost_equal(rpd.road_widths[1], 6.0, 0.001, "Sample 1 road width is 6.0m")
	assert_almost_equal(rpd.road_widths[3], 10.0, 0.001, "Sample 3 road width is 10.0m")

	var sliced = rpd.slice_segment(1, 3)
	assert_true(sliced.road_widths.size() == 3, "Sliced segment has 3 road widths (inclusive 1..3)")
	assert_almost_equal(sliced.road_widths[0], 6.0, 0.001, "Sliced segment start width matches")
	assert_almost_equal(sliced.road_widths[1], 8.0, 0.001, "Sliced segment mid width matches")
	assert_almost_equal(sliced.road_widths[2], 10.0, 0.001, "Sliced segment end width matches")

	var cloned = rpd.clone()
	assert_true(cloned.road_widths.size() == rpd.road_widths.size(), "Cloned path data preserves road_widths")
	cloned.road_widths[0] = 99.0
	assert_almost_equal(rpd.road_widths[0], 4.0, 0.001, "Original road_widths unaffected by clone mutation (deep copy)")

# ==============================================================================
# TEST 2: SIGN AND FACTOR CONSISTENCY (Analyst Point 1 & Point 15.A/B)
# ==============================================================================
func test_sign_and_factor_consistency() -> void:
	print("\n--- Running Test 2: Sign and Factor Consistency ---")

	var model = ForkDecisionModelClass.new()
	model.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

	# 1. Player positioned on LEFT (-X), moving straight forward
	# fork_tangent = FORWARD (0, 0, -1), fork_binormal = RIGHT (1, 0, 0)
	# Lateral offset x < 0 means LEFT
	model.update(Vector3(-2.0, 0.0, 0.0), Vector3(0.0, 0.0, -10.0), 0.05)
	assert_true(model.get_instant_tendency() == ForkDecisionModelClass.BranchChoice.LEFT, "Instant tendency is LEFT for lateral offset x = -2.0")
	assert_true(model.get_confidence() < 0.0, "Confidence is strictly negative (< 0) for LEFT position")

	# 2. Player positioned on RIGHT (+X), moving straight forward
	model.reset()
	model.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)
	model.update(Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, -10.0), 0.05)
	assert_true(model.get_instant_tendency() == ForkDecisionModelClass.BranchChoice.RIGHT, "Instant tendency is RIGHT for lateral offset x = +2.0")
	assert_true(model.get_confidence() > 0.0, "Confidence is strictly positive (> 0) for RIGHT position")

	# 3. Factor consistency: Steering LEFT while centered (x = 0, v_lat < 0)
	model.reset()
	model.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)
	model.update(Vector3(0.0, 0.0, 0.0), Vector3(-3.0, 0.0, -10.0), 0.05)
	assert_true(model.get_instant_tendency() == ForkDecisionModelClass.BranchChoice.LEFT, "Steering velocity to LEFT produces instant tendency LEFT")
	assert_true(model.get_confidence() < 0.0, "Steering velocity to LEFT produces negative confidence")

	# 4. Factor consistency: Steering RIGHT while centered (x = 0, v_lat > 0)
	model.reset()
	model.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)
	model.update(Vector3(0.0, 0.0, 0.0), Vector3(3.0, 0.0, -10.0), 0.05)
	assert_true(model.get_instant_tendency() == ForkDecisionModelClass.BranchChoice.RIGHT, "Steering velocity to RIGHT produces instant tendency RIGHT")
	assert_true(model.get_confidence() > 0.0, "Steering velocity to RIGHT produces positive confidence")

# ==============================================================================
# TEST 3: FSM PHASES AND PREVIEW REVERSIBILITY (Analyst Point 9 & 10)
# ==============================================================================
func test_fsm_phases_and_preview_reversibility() -> void:
	print("\n--- Running Test 3: FSM Phases & Preview Reversibility ---")

	var model = ForkDecisionModelClass.new()
	model.setup(100, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

	var signal_tracker := {
		"preview_count": 0,
		"preview_dist": 0.0
	}
	model.fork_preview_entered.connect(func(f_id: int, dist: float) -> void:
		signal_tracker["preview_count"] += 1
		signal_tracker["preview_dist"] = dist
	)

	# 1. Approach phase (s = -60m)
	# With fork at Vector3.ZERO and tangent FORWARD (0, 0, -1):
	# Position at (0, 0, 60) gives (pos - origin) . FORWARD = -60
	model.update(Vector3(0.0, 0.0, 60.0), Vector3(0.0, 0.0, -10.0), 0.016)
	assert_true(model.get_state() == ForkDecisionModelClass.ForkState.APPROACH, "State is APPROACH at s = -60m")
	assert_true(not model.is_locked(), "Not locked in APPROACH")

	# 2. Transition to FORK_PREVIEW (s = -30m)
	model.update(Vector3(0.0, 0.0, 30.0), Vector3(0.0, 0.0, -10.0), 0.016)
	assert_true(model.get_state() == ForkDecisionModelClass.ForkState.FORK_PREVIEW, "State is FORK_PREVIEW at s = -30m")
	assert_true(signal_tracker["preview_count"] == 1, "fork_preview_entered signal emitted once")
	assert_almost_equal(signal_tracker["preview_dist"], 30.0, 0.1, "Preview distance in signal is 30m")

	# 3. Weaving violently in FORK_PREVIEW must NEVER lock!
	for i in range(50):
		var x_weave: float = 3.5 if (i % 2 == 0) else -3.5
		var vx_weave: float = 5.0 if (i % 2 == 0) else -5.0
		model.update(Vector3(x_weave, 0.0, 25.0), Vector3(vx_weave, 0.0, -10.0), 0.016)
		assert_true(model.get_locked_branch() == ForkDecisionModelClass.BranchChoice.UNDECIDED, "Branch lock strictly forbidden during preview weave")
		assert_true(model.get_state() == ForkDecisionModelClass.ForkState.FORK_PREVIEW, "State remains FORK_PREVIEW during preview weave")

	# 4. Reversal: backing up from preview to approach
	model.update(Vector3(0.0, 0.0, 65.0), Vector3(0.0, 0.0, 10.0), 0.016)
	assert_true(model.get_state() == ForkDecisionModelClass.ForkState.APPROACH, "State gracefully reverts from PREVIEW to APPROACH on reverse")

	# 5. Entering COMMIT_ZONE (s = -10m)
	model.update(Vector3(0.0, 0.0, 10.0), Vector3(0.0, 0.0, -10.0), 0.016)
	assert_true(model.get_state() == ForkDecisionModelClass.ForkState.FORK_COMMIT_ZONE, "State enters FORK_COMMIT_ZONE at s = -10m")

	# 6. Reversal from COMMIT_ZONE back to PREVIEW
	model.update(Vector3(0.0, 0.0, 25.0), Vector3(0.0, 0.0, 10.0), 0.016)
	assert_true(model.get_state() == ForkDecisionModelClass.ForkState.FORK_PREVIEW, "State gracefully reverts from COMMIT_ZONE to PREVIEW on reverse")

# ==============================================================================
# TEST 4: HARD-LOCK AND DEAD-CENTER FALLBACK (Analyst Point 7 & 15.C)
# ==============================================================================
func test_hard_lock_and_dead_center_fallback() -> void:
	print("\n--- Running Test 4: Hard-Lock and Dead-Center Fallback ---")

	# 1. Normal lock via high confidence at s >= +8m
	var model1 = ForkDecisionModelClass.new()
	model1.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

	# Ride steadily on the RIGHT branch side from -10m through +12m
	for step in range(70):
		var s_pos: float = -10.0 + (step * 0.35) # reaches +14.5m
		var z_pos: float = -s_pos
		var x_pos: float = 2.5 + (maxf(0.0, s_pos) * 0.15) # follows right branch divergence
		model1.update(Vector3(x_pos, 0.0, z_pos), Vector3(2.0, 0.0, -10.0), 0.033)
		if model1.is_locked():
			break

	assert_true(model1.is_locked(), "Model successfully locked via confidence threshold")
	assert_true(model1.get_locked_branch() == ForkDecisionModelClass.BranchChoice.RIGHT, "Locked to RIGHT as rider stayed right")

	# 2. Dead-center approach (x = 0, vx = 0): confidence stays ~0
	var model2 = ForkDecisionModelClass.new()
	model2.setup(2, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

	for step in range(100):
		var s_pos: float = -15.0 + (step * 0.35) # reaches +20m
		var z_pos: float = -s_pos
		model2.update(Vector3(0.0, 0.0, z_pos), Vector3(0.0, 0.0, -10.0), 0.033)
		if model2.is_locked():
			break

	assert_true(model2.is_locked(), "Dead-center rider hard-locks at D_LOCK_HARD (+15m)")
	assert_true(model2.get_locked_branch() == ForkDecisionModelClass.BranchChoice.LEFT, "Dead-center rider deterministically falls back to default_branch (LEFT)")

	# 3. Dead-center approach with default_branch = RIGHT
	var model3 = ForkDecisionModelClass.new()
	model3.setup(3, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.RIGHT)

	for step in range(100):
		var s_pos: float = -15.0 + (step * 0.35) # reaches +20m
		var z_pos: float = -s_pos
		model3.update(Vector3(0.0, 0.0, z_pos), Vector3(0.0, 0.0, -10.0), 0.033)
		if model3.is_locked():
			break

	assert_true(model3.is_locked(), "Hard-locked at D_LOCK_HARD")
	assert_true(model3.get_locked_branch() == ForkDecisionModelClass.BranchChoice.RIGHT, "Dead-center rider falls back to specified default_branch (RIGHT)")

	# 4. Weak bias at D_LOCK_HARD (|C| = 0.28 >= FALLBACK_THRESHOLD 0.15, but < 0.65)
	var model4 = ForkDecisionModelClass.new()
	model4.setup(4, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.RIGHT)

	# Ride slightly left (offset x = -1.2m) with vx = 0 so |C| is ~0.28 (< 0.65)
	for step in range(100):
		var s_pos: float = -5.0 + (step * 0.25) # reaches +20m
		var z_pos: float = -s_pos
		model4.update(Vector3(-1.2, 0.0, z_pos), Vector3(0.0, 0.0, -10.0), 0.016)
		if model4.is_locked():
			break

	assert_true(model4.is_locked(), "Weak-bias rider hard-locks at D_LOCK_HARD")
	assert_true(model4.get_locked_branch() == ForkDecisionModelClass.BranchChoice.LEFT, "Weak bias (|C| >= 0.15) resolves to sign(C) rather than default RIGHT")

# ==============================================================================
# TEST 5: FPS INVARIANCE (Analyst Point 6 & 15.D)
# ==============================================================================
func test_fps_invariance() -> void:
	print("\n--- Running Test 5: FPS Invariance (30 vs 60 vs 120 FPS) ---")

	var run_sim = func(target_fps: int) -> Dictionary:
		var model = ForkDecisionModelClass.new()
		model.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

		var dt: float = 1.0 / float(target_fps)
		var speed: float = 10.0 # 10 m/s
		var dist_per_frame: float = speed * dt

		var s: float = -15.0
		var lock_s: float = -999.0

		for _i in range(1000):
			s += dist_per_frame
			var z_pos: float = -s
			# Steady rightward movement
			model.update(Vector3(1.5, 0.0, z_pos), Vector3(0.2, 0.0, -speed), dt)
			if model.is_locked():
				lock_s = s
				break

		return {
			"locked": model.is_locked(),
			"branch": model.get_locked_branch(),
			"lock_s": lock_s
		}

	var res_30 = run_sim.call(30)
	var res_60 = run_sim.call(60)
	var res_120 = run_sim.call(120)

	assert_true(res_30.locked and res_60.locked and res_120.locked, "All framerates successfully lock")
	assert_true(res_30.branch == res_60.branch and res_60.branch == res_120.branch, "All framerates reach identical branch decision (RIGHT)")

	print("  Lock distance: 30 FPS = %.3fm, 60 FPS = %.3fm, 120 FPS = %.3fm" % [res_30.lock_s, res_60.lock_s, res_120.lock_s])
	var delta_30_60: float = absf(res_30.lock_s - res_60.lock_s)
	var delta_60_120: float = absf(res_60.lock_s - res_120.lock_s)
	assert_true(delta_30_60 < 0.5, "Lock distance difference between 30 and 60 FPS is < 0.5m")
	assert_true(delta_60_120 < 0.25, "Lock distance difference between 60 and 120 FPS is < 0.25m")

# ==============================================================================
# TEST 6: SPEED INVARIANCE AND STATIONARY GUARD (Analyst Point 15.E)
# ==============================================================================
func test_speed_invariance_and_stationary_guard() -> void:
	print("\n--- Running Test 6: Speed Invariance & Stationary Guard ---")

	# 1. Test stationary bike (v = 0.0)
	var model_stat = ForkDecisionModelClass.new()
	model_stat.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

	# Bike stopped on left side
	model_stat.update(Vector3(-2.0, 0.0, 0.0), Vector3.ZERO, 0.016)
	assert_true(not is_nan(model_stat.get_confidence()), "Stationary bike confidence is not NaN")
	assert_true(model_stat.get_confidence() < 0.0, "Stationary bike on left side produces negative confidence")
	assert_true(model_stat.get_instant_tendency() == ForkDecisionModelClass.BranchChoice.LEFT, "Stationary bike produces LEFT tendency based on position")

	# 2. Test various speeds: 10 km/h (2.78 m/s), 20 km/h (5.56 m/s), 30 km/h (8.33 m/s), 45 km/h (12.5 m/s)
	var speeds_kmh: Array[float] = [10.0, 20.0, 30.0, 45.0]
	for spd in speeds_kmh:
		var mps: float = spd / 3.6
		var model = ForkDecisionModelClass.new()
		model.setup(int(spd), Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.LEFT)

		# Steer LEFT with corresponding lateral speed
		var s: float = -15.0
		var dt: float = 0.016
		var locked: bool = false
		for _step in range(800):
			s += mps * dt
			var z_pos: float = -s
			model.update(Vector3(-1.8, 0.0, z_pos), Vector3(-0.4, 0.0, -mps), dt)
			if model.is_locked():
				locked = true
				break

		assert_true(locked, "Rider at %.1f km/h successfully locks" % spd)
		assert_true(model.get_locked_branch() == ForkDecisionModelClass.BranchChoice.LEFT, "Rider at %.1f km/h locks to LEFT" % spd)

# ==============================================================================
# TEST 7: MIRRORED FORK SYMMETRY (Analyst Point 15.F & 15.G)
# ==============================================================================
func test_mirrored_fork_symmetry() -> void:
	print("\n--- Running Test 7: Mirrored Fork Symmetry ---")

	var model_left = ForkDecisionModelClass.new()
	model_left.setup(1, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.UNDECIDED)

	var model_right = ForkDecisionModelClass.new()
	model_right.setup(2, Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 20.0, ForkDecisionModelClass.BranchChoice.UNDECIDED)

	# Feed mirrored trajectories at each step through lock threshold
	var s: float = -10.0
	for step in range(50):
		s += 0.4 # reaches +10.0m (> +8.0m lock threshold)
		var z_pos: float = -s
		var dt: float = 0.016

		var x_val: float = 1.5 + (step * 0.05)
		var vx_val: float = 1.8

		model_left.update(Vector3(-x_val, 0.0, z_pos), Vector3(-vx_val, 0.0, -8.0), dt)
		model_right.update(Vector3(x_val, 0.0, z_pos), Vector3(vx_val, 0.0, -8.0), dt)

		var c_left: float = model_left.get_confidence()
		var c_right: float = model_right.get_confidence()
		var sum_c: float = c_left + c_right
		assert_almost_equal(sum_c, 0.0, 0.0001, "Mirrored confidence: C_left + C_right == 0.0 at step %d" % step)

	assert_true(model_left.is_locked(), "Left model is locked")
	assert_true(model_right.is_locked(), "Right model is locked")
	assert_true(model_left.get_locked_branch() == ForkDecisionModelClass.BranchChoice.LEFT, "Left-steered model chose LEFT")
	assert_true(model_right.get_locked_branch() == ForkDecisionModelClass.BranchChoice.RIGHT, "Right-steered model chose RIGHT")
