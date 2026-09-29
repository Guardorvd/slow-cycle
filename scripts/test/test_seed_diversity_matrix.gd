extends SceneTree

## Slow Cycle — Quality Watchdog 1: Seed Diversity Matrix (Sprint 6 v4)
## Verifies that different world seeds produce genuinely divergent road trajectories.
## On baseline code with 400m rigid opening curtain, this watchdog MUST FAIL.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const SlowCycleLogger = preload("res://scripts/core/slow_cycle_logger.gd")

const TEST_SEEDS: Array[int] = [
	184729, 42, 99999, 10101, 77777,
	12345, 54321, 999, 31415, 27182
]

const TARGET_DISTANCE_M: float = 500.0
const CHUNKS_TO_GENERATE: int = 10 # 10 * 50m = 500m
const CHECKPOINTS: Array[float] = [50.0, 100.0, 150.0, 200.0, 300.0, 400.0, 500.0]
const MIN_SPREAD_AT_200M: float = 30.0 # meters lateral spread required

func _init() -> void:
	print("\n========================================================")
	print("🔍 WATCHDOG #1: SEED DIVERSITY MATRIX PROFILER")
	print("Testing 10 Seeds across 500m of road generation")
	print("========================================================\n")
	
	SlowCycleLogger.log_world("Starting Seed Diversity Matrix Watchdog...")

	# Trajectory store: seed -> Array of checkpoint samples Dictionary { "dist": d, "pos": Vector3 }
	var trajectories: Dictionary = {}

	for s in TEST_SEEDS:
		var path_data = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(s, path_data)

		for c in range(CHUNKS_TO_GENERATE):
			logic.plan_next_chunk()

		var samples: Array[Dictionary] = []
		for cp in CHECKPOINTS:
			var sample = path_data.get_sample_at_distance(cp)
			var pos: Vector3 = sample.get("position", Vector3.ZERO)
			samples.append({"dist": cp, "pos": pos})
		trajectories[s] = samples

	# Print Diversity Table
	print("Distance Checkpoint Analysis:")
	print("%-8s | %-12s | %-12s | %-12s | %-12s" % ["Dist (m)", "Min X (m)", "Max X (m)", "Spread ΔX (m)", "Status"])
	print("-----------------------------------------------------------------")

	var spread_at_200m: float = 0.0
	var checkpoint_spreads: Dictionary = {}

	for i in range(CHECKPOINTS.size()):
		var cp: float = CHECKPOINTS[i]
		var min_x: float = INF
		var max_x: float = -INF
		
		for s in TEST_SEEDS:
			var pos: Vector3 = trajectories[s][i]["pos"]
			if pos.x < min_x: min_x = pos.x
			if pos.x > max_x: max_x = pos.x
			
		var spread: float = max_x - min_x
		checkpoint_spreads[cp] = spread
		if is_equal_approx(cp, 200.0):
			spread_at_200m = spread
			
		var pass_status := "PASS" if spread >= (MIN_SPREAD_AT_200M if cp >= 200.0 else 5.0) else "FAIL"
		print("%-8.0f | %-12.2f | %-12.2f | %-12.2f | %s" % [cp, min_x, max_x, spread, pass_status])

	# Render ASCII Mini-Map of Divergence
	print("\n--- ASCII TRAJECTORY DIVERGENCE MINI-MAP (X vs S) ---")
	print("S (Dist)  | Lateral Spread Corridor ([-60m, +60m])")
	for i in range(CHECKPOINTS.size()):
		var cp: float = CHECKPOINTS[i]
		var line_chars: Array[String] = []
		for col in range(61):
			line_chars.append(" ")
		line_chars[30] = "|" # Centerline marker (X = 0)

		for s_idx in range(TEST_SEEDS.size()):
			var s: int = TEST_SEEDS[s_idx]
			var x_val: float = trajectories[s][i]["pos"].x
			var col_idx: int = clampi(int(round(30 + (x_val / 2.0))), 0, 60)
			line_chars[col_idx] = str(s_idx)

		print("%-8.0fm | %s" % [cp, "".join(line_chars)])
	print("-----------------------------------------------------\n")

	# Evaluate Criteria (Multi-Metric Diversity Gate)
	var spread_at_50m: float = checkpoint_spreads.get(50.0, 0.0)
	var spread_at_100m: float = checkpoint_spreads.get(100.0, 0.0)
	var min_x_at_300m: float = INF
	var max_x_at_300m: float = -INF
	var right_turning_seeds: int = 0
	var left_turning_seeds: int = 0

	for s in TEST_SEEDS:
		var x_300: float = trajectories[s][4]["pos"].x # index 4 is 300m
		if x_300 < min_x_at_300m: min_x_at_300m = x_300
		if x_300 > max_x_at_300m: max_x_at_300m = x_300
		if x_300 > 10.0: right_turning_seeds += 1
		elif x_300 < -10.0: left_turning_seeds += 1

	print("Evaluation Criteria (Sprint 6 v4 Diversity Gate):")
	print("  1. Opening Fan-out at 50m: Spread = %.2fm (Required: >= 3.0m) -> %s" % [
		spread_at_50m, "PASS" if spread_at_50m >= 3.0 else "FAIL"
	])
	print("  2. Early Divergence at 100m: Spread = %.2fm (Required: >= 15.0m) -> %s" % [
		spread_at_100m, "PASS" if spread_at_100m >= 15.0 else "FAIL"
	])
	print("  3. Lateral Spread at 200m: Spread = %.2fm (Required: >= 30.0m) -> %s" % [
		spread_at_200m, "PASS" if spread_at_200m >= MIN_SPREAD_AT_200M else "FAIL"
	])
	print("  4. Bilateral Diversity at 300m: Left=%d seeds, Right=%d seeds (Both >= 2 required) -> %s" % [
		left_turning_seeds, right_turning_seeds,
		"PASS" if (left_turning_seeds >= 2 and right_turning_seeds >= 2) else "FAIL"
	])

	var passed: bool = (spread_at_50m >= 3.0) and (spread_at_100m >= 15.0) and (spread_at_200m >= MIN_SPREAD_AT_200M) and (left_turning_seeds >= 2 and right_turning_seeds >= 2)

	if not passed:
		printerr("\n❌ [FAIL] SEED DIVERSITY WATCHDOG FAILED!")
		if spread_at_50m < 3.0:
			printerr("  - Failure: Road is locked in a rigid narrow corridor at 50m (Spread %.2fm < 3.0m)." % spread_at_50m)
		if spread_at_100m < 15.0:
			printerr("  - Failure: Insufficient curve divergence at 100m (Spread %.2fm < 15.0m)." % spread_at_100m)
		if right_turning_seeds < 2 or left_turning_seeds < 2:
			printerr("  - Failure: One-sided bias detected! Left: %d, Right: %d. Missing bilateral branching." % [left_turning_seeds, right_turning_seeds])
		printerr("DIAGNOSIS: Seeds follow an identical or near-identical track. Rigid curtain or static curve direction detected.\n")
		SlowCycleLogger.log_world("[FAIL] Diversity watchdog triggered on baseline code")
		SlowCycleLogger.flush()
		quit(1)
	else:
		print("\n✅ [PASS] SEED DIVERSITY WATCHDOG PASSED!")
		print("Lateral divergence and bilateral branching validated across all 10 seeds.\n")
		SlowCycleLogger.log_world("[PASS] Diversity watchdog: all criteria passed")
		SlowCycleLogger.flush()
		quit(0)
