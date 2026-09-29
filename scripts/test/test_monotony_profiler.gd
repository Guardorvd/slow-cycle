extends SceneTree

## Slow Cycle — Quality Watchdog 2: Monotony & Relief Profiler (Sprint 6 v4)
## Scans generated road and roadside profile for dead straightaways and flat mountain terrain.
## On baseline code with straight corridors and uncoupled terrain, this watchdog MUST FAIL.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const SlowCycleLogger = preload("res://scripts/core/slow_cycle_logger.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777]
const DISTANCE_TO_SCAN_M: float = 600.0
const CHUNKS_TO_GENERATE: int = 12 # 12 * 50m = 600m

const MAX_DEAD_STRAIGHT_ALLOWED_M: float = 100.0 ## Corridor > 100m with |k| < 0.005 and |dh| < 0.2m is prohibited
const MIN_MOUNTAIN_RELIEF_OVER_40M: float = 1.0 ## On mountain sections, 40m window must have >= 1.0m elevation delta

func _init() -> void:
	print("\n========================================================")
	print("🔍 WATCHDOG #2: ROAD MONOTONY & RELIEF PROFILER")
	print("Scanning %d seeds over %.0fm for dead corridors & flat slopes" % [TEST_SEEDS.size(), DISTANCE_TO_SCAN_M])
	print("========================================================\n")
	
	SlowCycleLogger.log_world("Starting Monotony Profiler Watchdog...")

	var total_violations: int = 0

	for s in TEST_SEEDS:
		print("--- Analyzing Seed %d ---" % s)
		var path_data = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(s, path_data)

		for c in range(CHUNKS_TO_GENERATE):
			logic.plan_next_chunk()

		var pts_count: int = path_data.size()
		if pts_count < 20:
			printerr("  [ERROR] Not enough points generated: %d" % pts_count)
			quit(1)
			return

		# Scan for dead straight corridors:
		# Check intervals of ~100m (using cumulative distance)
		var longest_dead_corridor: float = 0.0
		var current_dead_start_s: float = -1.0
		var current_dead_len: float = 0.0

		for i in range(1, pts_count):
			var cur_s: float = path_data.cumulative_distances[i]
			var prev_s: float = path_data.cumulative_distances[i - 1]
			var ds: float = cur_s - prev_s

			var k: float = absf(path_data.curvatures[i])
			var p_cur: Vector3 = path_data.points[i]
			var p_prev: Vector3 = path_data.points[i - 1]
			var dh_rate: float = absf(p_cur.y - p_prev.y) / maxf(0.001, ds)

			# Dead condition: minimal curvature (|k| < 0.005) AND minimal vertical change (|dh/ds| < 0.005)
			var is_flat_dead: bool = (k < 0.005) and (dh_rate < 0.005)
			if is_flat_dead:
				if current_dead_start_s < 0.0:
					current_dead_start_s = prev_s
				current_dead_len = cur_s - current_dead_start_s
				if current_dead_len > longest_dead_corridor:
					longest_dead_corridor = current_dead_len
			else:
				current_dead_start_s = -1.0
				current_dead_len = 0.0

		print("  • Longest featureless dead straight corridor: %.1fm (Limit: <= %.1fm)" % [longest_dead_corridor, MAX_DEAD_STRAIGHT_ALLOWED_M])
		if longest_dead_corridor > MAX_DEAD_STRAIGHT_ALLOWED_M:
			printerr("    ❌ VIOLATION: Excessive dead corridor detected (%.1fm > %.1fm)!" % [longest_dead_corridor, MAX_DEAD_STRAIGHT_ALLOWED_M])
			total_violations += 1

		# Scan Mountain Relief (40m window in mountain zones)
		var mountain_weight_available: bool = logic.mountain_profile != null
		var min_mountain_relief: float = INF
		var mountain_samples_found: int = 0

		if mountain_weight_available:
			for i in range(pts_count):
				var s_start: float = path_data.cumulative_distances[i]
				var m_wt: float = logic.mountain_profile.get_mountain_weight_at(s_start)
				if m_wt > 0.65:
					# Check 40m window forward
					var s_target: float = s_start + 40.0
					if s_target <= path_data.cumulative_distances[pts_count - 1]:
						var idx_end: int = i
						while idx_end < pts_count - 1 and path_data.cumulative_distances[idx_end] < s_target:
							idx_end += 1
						var y_min: float = INF
						var y_max: float = -INF
						for j in range(i, idx_end + 1):
							var y: float = path_data.points[j].y
							if y < y_min: y_min = y
							if y > y_max: y_max = y
						var relief: float = y_max - y_min
						if relief < min_mountain_relief:
							min_mountain_relief = relief
						mountain_samples_found += 1

		if mountain_samples_found > 0:
			print("  • Minimum 40m elevation relief on mountain sections: %.2fm (Required: >= %.1fm)" % [min_mountain_relief, MIN_MOUNTAIN_RELIEF_OVER_40M])
			if min_mountain_relief < MIN_MOUNTAIN_RELIEF_OVER_40M:
				printerr("    ❌ VIOLATION: Flat slope on mountain section (%.2fm < %.1fm)!" % [min_mountain_relief, MIN_MOUNTAIN_RELIEF_OVER_40M])
				total_violations += 1
		else:
			print("  • Note: No mountain sections (>0.65) in first %.0fm." % DISTANCE_TO_SCAN_M)

	print("\n--------------------------------------------------------")
	print("Watchdog Summary: %d total violations found across %d seeds." % [total_violations, TEST_SEEDS.size()])
	print("--------------------------------------------------------\n")

	if total_violations > 0:
		printerr("❌ [FAIL] MONOTONY PROFILER WATCHDOG FAILED!")
		SlowCycleLogger.log_world("[FAIL] Monotony watchdog: %d violations" % total_violations)
		SlowCycleLogger.flush()
		quit(1)
	else:
		print("✅ [PASS] MONOTONY PROFILER WATCHDOG PASSED!")
		SlowCycleLogger.log_world("[PASS] Monotony watchdog: 0 violations")
		SlowCycleLogger.flush()
		quit(0)
