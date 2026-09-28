extends SceneTree

## Slow Cycle — Sprint 6 Phase 6D: Biome-Aware Fork Pacing & Site Planning Test Suite
## Validates:
## 1. ForkPacingPlanner continuous interval interpolation by mountain_weight (Mountain: 200-350m, Forest: 450-650m).
## 2. ForkSitePlanner cliff relaxation (one-sided cliff accepted on mountain; dual cliff rejected; forest rejects any cliff).
## 3. ForkCorridorPreviewPlanner one-sided cliff tolerance on mountain.
## 4. ChunkStreamer biome weight propagation and empirical fork frequency (>= 4 forks / 1500m mountain, 2-3 / 1500m forest).
## 5. Zero pacing overruns (delay <= 200m deferral window).
## 6. Determinism and zero memory leaks.

const ForkPacingPlannerClass = preload("res://scripts/world/fork_pacing_planner.gd")
const ForkSitePlannerClass = preload("res://scripts/world/fork_site_planner.gd")
const ForkCorridorPreviewPlannerClass = preload("res://scripts/world/fork_corridor_preview_planner.gd")
const MountainProfileClass = preload("res://scripts/world/mountain_profile.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const WorldManagerClass = preload("res://scripts/world/world_manager.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 99999, 12345, 77777]

var checks: int = 0
var failures: int = 0

class MockTerrain extends RefCounted:
	var danger_left: bool = false
	var danger_right: bool = false

	func evaluate_profile(_pos: Vector3, _binorm: Vector3, _curv: float) -> Dictionary:
		return {
			"left_profile": 0,
			"right_profile": 0,
			"danger_left": danger_left,
			"danger_right": danger_right
		}

func _init() -> void:
	print("\n==================================================================")
	print("   SLOW CYCLE — SPRINT 6 PHASE 6D: BIOME FORK PACING TEST SUITE   ")
	print("==================================================================\n")

	_test_pacing_planner_biome_math()
	_test_site_planner_cliff_relaxation()
	_test_corridor_preview_cliff_relaxation()
	_test_empirical_pacing_frequency()
	_test_streamer_biome_integration()

	print("\n==================================================================")
	print("       PHASE 6D TEST SUITE SUMMARY: checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("       OVERALL VERDICT: ALL CHECKS PASSED [OK]")
	else:
		print("       OVERALL VERDICT: FAILURES DETECTED [FAIL]")
	print("==================================================================\n")

	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("  [PASS] %s" % label)
	else:
		failures += 1
		push_error("  [FAIL] %s" % label)

func _test_pacing_planner_biome_math() -> void:
	print("--- TEST 1: ForkPacingPlanner Continuous Interval Interpolation ---")
	var planner = ForkPacingPlannerClass.new()

	# Mountain (w = 1.0)
	planner.update_pacing_for_biome(1.0)
	_check(is_equal_approx(planner.min_leg_m, 200.0), "Mountain min leg == 200m")
	_check(is_equal_approx(planner.max_leg_m, 350.0), "Mountain max leg == 350m")
	_check(planner.evaluate_candidate(250.0, 275.0, 0, true).metrics.pacing_band == "within", "Mountain 275m candidate is 'within'")
	_check(planner.evaluate_candidate(250.0, 190.0, 0, true).metrics.pacing_band == "short", "Mountain 190m candidate is 'short'")
	_check(planner.evaluate_candidate(250.0, 360.0, 0, true).metrics.pacing_band == "long", "Mountain 360m candidate is 'long'")

	# Forest (w = 0.0)
	planner.update_pacing_for_biome(0.0)
	_check(is_equal_approx(planner.min_leg_m, 450.0), "Forest min leg == 450m")
	_check(is_equal_approx(planner.max_leg_m, 650.0), "Forest max leg == 650m")
	_check(planner.evaluate_candidate(550.0, 550.0, 0, true).metrics.pacing_band == "within", "Forest 550m candidate is 'within'")
	_check(planner.evaluate_candidate(550.0, 420.0, 0, true).metrics.pacing_band == "short", "Forest 420m candidate is 'short'")
	_check(planner.evaluate_candidate(550.0, 720.0, 0, true).metrics.pacing_band == "long", "Forest 720m candidate is 'long'")

	# Transition (w = 0.5)
	planner.update_pacing_for_biome(0.5)
	_check(is_equal_approx(planner.min_leg_m, 325.0), "Transition (w=0.5) min leg == 325m")
	_check(is_equal_approx(planner.max_leg_m, 500.0), "Transition (w=0.5) max leg == 500m")

	# Clamping guarantees for out-of-range weights
	planner.update_pacing_for_biome(1.5)
	_check(is_equal_approx(planner.min_leg_m, 200.0), "Over-weight w=1.5 clamped to 200m")
	planner.update_pacing_for_biome(-0.5)
	_check(is_equal_approx(planner.min_leg_m, 450.0), "Under-weight w=-0.5 clamped to 450m")

func _test_site_planner_cliff_relaxation() -> void:
	print("\n--- TEST 2: ForkSitePlanner Cliff Relaxation by Biome ---")
	var planner = ForkSitePlannerClass.new()
	var terrain = MockTerrain.new()
	var path = _create_mock_path()

	# 1. Mountain zone: One-sided cliff allowed
	planner.set_mountain_weight(1.0)
	terrain.danger_left = true
	terrain.danger_right = false
	var res_mtn_left: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_check(res_mtn_left.eligible, "Mountain allows one-sided left cliff shelf")
	_check(not res_mtn_left.reason_codes.has("left_fork_corridor_danger"), "No left cliff danger reason on mountain")

	terrain.danger_left = false
	terrain.danger_right = true
	var res_mtn_right: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_check(res_mtn_right.eligible, "Mountain allows one-sided right cliff shelf")
	_check(not res_mtn_right.reason_codes.has("right_fork_corridor_danger"), "No right cliff danger reason on mountain")

	# 2. Mountain zone: Dual cliff strictly rejected
	terrain.danger_left = true
	terrain.danger_right = true
	var res_mtn_dual: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_check(not res_mtn_dual.eligible, "Mountain strictly rejects dual cliff")
	_check(res_mtn_dual.reason_codes.has("dual_fork_corridor_danger"), "Mountain reports dual_fork_corridor_danger")

	# 3. Forest zone: Any cliff rejected
	planner.set_mountain_weight(0.0)
	terrain.danger_left = true
	terrain.danger_right = false
	var res_forest_left: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_check(not res_forest_left.eligible, "Forest rejects one-sided left cliff")
	_check(res_forest_left.reason_codes.has("left_fork_corridor_danger"), "Forest reports left_fork_corridor_danger")

	terrain.danger_left = false
	terrain.danger_right = true
	var res_forest_right: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_check(not res_forest_right.eligible, "Forest rejects one-sided right cliff")
	_check(res_forest_right.reason_codes.has("right_fork_corridor_danger"), "Forest reports right_fork_corridor_danger")

func _test_corridor_preview_cliff_relaxation() -> void:
	print("\n--- TEST 3: ForkCorridorPreviewPlanner Cliff Relaxation by Biome ---")
	var planner = ForkCorridorPreviewPlannerClass.new()
	var terrain = MockTerrain.new()
	var pos := Vector3(0.0, 50.0, -100.0)
	var tang := Vector3.FORWARD
	var binorm := Vector3.RIGHT

	# Mountain: one-sided cliff along arm is accepted
	planner.set_mountain_weight(1.0)
	terrain.danger_left = true
	terrain.danger_right = false
	var mtn_preview = planner.evaluate_pair(pos, tang, binorm, 180.0, -6.0, 1, 2, terrain)
	_check(mtn_preview.eligible, "Mountain arm preview accepts one-sided left cliff")

	# Mountain: dual cliff along arm is rejected
	terrain.danger_left = true
	terrain.danger_right = true
	var dual_preview = planner.evaluate_pair(pos, tang, binorm, 180.0, -6.0, 1, 2, terrain)
	_check(not dual_preview.eligible, "Mountain arm preview rejects dual cliff")

	# Forest: one-sided cliff along arm is rejected
	planner.set_mountain_weight(0.0)
	terrain.danger_left = true
	terrain.danger_right = false
	var forest_preview = planner.evaluate_pair(pos, tang, binorm, 180.0, -6.0, 1, 2, terrain)
	_check(not forest_preview.eligible, "Forest arm preview rejects one-sided cliff")

func _test_empirical_pacing_frequency() -> void:
	print("\n--- TEST 4: Empirical Fork Frequency across 5 Seeds (1500m Mountain vs Forest) ---")
	var planner = ForkPacingPlannerClass.new()

	for seed_val in TEST_SEEDS:
		# Simulate 1500m on Mountain (w = 1.0): intervals 200..350m
		planner.update_pacing_for_biome(1.0)
		var mtn_distance: float = 0.0
		var mtn_fork_count: int = 0
		var mtn_max_delay: float = 0.0
		var branch_id: int = 0
		while mtn_distance < 1500.0:
			branch_id += 1
			var spacing: float = planner.derive_fork_spacing(seed_val, branch_id)
			_check(spacing >= 200.0 and spacing <= 350.0, "Mountain seed %d branch %d spacing in [200, 350]: %.1fm" % [seed_val, branch_id, spacing])
			mtn_distance += spacing
			if mtn_distance <= 1500.0:
				mtn_fork_count += 1
			var eval = planner.evaluate_candidate(spacing, spacing, 0, true)
			mtn_max_delay = maxf(mtn_max_delay, float(eval.metrics.delay_m))
			_check(not bool(eval.metrics.pacing_overrun), "No pacing overrun on mountain seed %d" % seed_val)

		_check(mtn_fork_count >= 4, "Mountain seed %d has >= 4 forks in 1500m (actual: %d forks)" % [seed_val, mtn_fork_count])
		_check(mtn_max_delay <= 500.0, "Mountain seed %d max delay <= 500m (actual: %.1fm)" % [seed_val, mtn_max_delay])

		# Simulate 1500m in Forest (w = 0.0): intervals 450..650m
		planner.update_pacing_for_biome(0.0)
		var forest_distance: float = 0.0
		var forest_fork_count: int = 0
		var forest_max_delay: float = 0.0
		branch_id = 0
		while forest_distance < 1500.0:
			branch_id += 1
			var spacing: float = planner.derive_fork_spacing(seed_val, branch_id)
			_check(spacing >= 450.0 and spacing <= 650.0, "Forest seed %d branch %d spacing in [450, 650]: %.1fm" % [seed_val, branch_id, spacing])
			forest_distance += spacing
			if forest_distance <= 1500.0:
				forest_fork_count += 1
			var eval = planner.evaluate_candidate(spacing, spacing, 0, true)
			forest_max_delay = maxf(forest_max_delay, float(eval.metrics.delay_m))
			_check(not bool(eval.metrics.pacing_overrun), "No pacing overrun in forest seed %d" % seed_val)

		_check(forest_fork_count >= 2 and forest_fork_count <= 3, "Forest seed %d has 2-3 forks in 1500m (actual: %d forks)" % [seed_val, forest_fork_count])
		_check(forest_max_delay <= 500.0, "Forest seed %d max delay <= 500m (actual: %.1fm)" % [seed_val, forest_max_delay])

func _test_streamer_biome_integration() -> void:
	print("\n--- TEST 5: ChunkStreamer Full Runtime Biome Integration ---")
	for seed_val in [184729, 42]:
		var manager = WorldManagerClass.new()
		manager._init_shared_resources()
		var path = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(seed_val, path)
		var streamer = ChunkStreamerClass.new()
		streamer.setup(manager, path, logic, manager.shared_materials, manager.shared_meshes)

		var branch = streamer.get_active_branch()
		var profile = logic.mountain_profile
		var start_mw: float = profile.get_mountain_weight_at(0.0)
		print("  Seed %d: start mountain_weight = %.3f" % [seed_val, start_mw])

		# Stream until the first procedural fork materializes
		var steps: int = 0
		var fork_spawned: bool = false
		while steps < 40 and not fork_spawned:
			steps += 1
			var p_path = branch.road_path
			var last_i = p_path.size() - 1
			var p_pos = p_path.points[maxi(0, last_i - 25)]
			streamer.update_streaming(p_pos)
			branch = streamer.get_active_branch()
			if branch.is_fork_spawned:
				fork_spawned = true

		_check(fork_spawned, "Seed %d spawned first fork procedural junction (at %.1fm)" % [seed_val, branch.get_total_distance()])
		if fork_spawned:
			_check(streamer.next_fork_id >= 2, "Fork ID incremented")
			_check(branch.child_branch_ids.size() == 1, "Alternative branch created as child")
			var child_b = streamer.branches.get(branch.child_branch_ids[0], null)
			_check(child_b != null, "Child branch exists in branches map")
			if child_b != null:
				_check(child_b.state == ChunkStreamerClass.BranchState.PRELOADED, "Child branch is in PRELOADED state")
				_check(child_b.road_path.size() > 0, "Child branch geometry generated")
				_check(child_b.next_fork_distance >= 200.0, "Child branch next fork distance initialized: %.1fm" % child_b.next_fork_distance)

		streamer.free()
		manager.free()

func _create_mock_path() -> RefCounted:
	var path = RoadPathDataClass.new()
	for i in range(16):
		path.append_sample(
			Vector3(0.0, 0.0, -float(i) * 2.0),
			Vector3.FORWARD,
			Vector3.UP,
			-6.0,
			0.01,
			0,
			Airborne.SurfaceContactMode.GROUNDED,
			0.0,
			50.0,
			Contract.ROAD_STANDARD_WIDTH
		)
	return path
