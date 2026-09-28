extends SceneTree

const Planner = preload("res://scripts/world/fork_pacing_planner.gd")
const StreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var planner = Planner.new()
	var waiting: Dictionary = planner.evaluate_candidate(700.0, 650.0, 0, true)
	_check(waiting.decision == "wait" and not waiting.eligible, "candidate before target waits even when safe")
	_check(waiting.reason_codes == ["before_scheduled_distance"], "early candidate has stable wait reason")
	var rejected: Dictionary = planner.evaluate_candidate(700.0, 700.0, 0, false)
	_check(rejected.decision == "defer" and not rejected.eligible, "unsafe candidate at target is deferred")
	_check(int(rejected.metrics.candidate_ordinal) == 1, "first real candidate ordinal is one")
	var accepted: Dictionary = planner.evaluate_candidate(700.0, 750.0, 2, true)
	_check(accepted.decision == "accept" and accepted.eligible, "first eligible later candidate is selected")
	_check(is_equal_approx(float(accepted.metrics.delay_m), 50.0), "accepted delay reports scheduled overshoot")
	var boundary: Dictionary = planner.evaluate_candidate(700.0, 900.0, 3, true)
	_check(not bool(boundary.metrics.pacing_overrun), "fourth candidate remains inside deferral window")
	var overrun: Dictionary = planner.evaluate_candidate(700.0, 950.0, 4, false)
	_check(bool(overrun.metrics.pacing_overrun), "fifth candidate reports pacing overrun")
	_check(overrun.decision == "defer", "pacing overrun never bypasses safety")
	_check(overrun.metrics.pacing_band == "long", "long route leg is classified")
	_check(planner.evaluate_candidate(700.0, 500.0, 0, true).metrics.pacing_band == "short", "short route leg is classified")
	_check(planner.evaluate_candidate(450.0, 500.0, 0, true, true).metrics.pacing_band == "initial", "initial fork uses a separate band")
	_check(planner.evaluate_candidate(NAN, 500.0, 0, true).reason_codes.has("scheduled_distance_invalid"), "non-finite target rejected")
	_check(planner.evaluate_candidate(500.0, INF, 0, true).reason_codes.has("candidate_distance_invalid"), "non-finite candidate rejected")
	_check(planner.evaluate_candidate(500.0, 550.0, -1, true).reason_codes.has("rejected_count_invalid"), "negative rejected count rejected")
	_check(planner.evaluate_candidate(700.0, 750.0, 2, true) == accepted, "identical candidate input is deterministic")
	_check(accepted.metrics == planner.evaluate_candidate(700.0, 750.0, 2, true).metrics, "candidate metrics serialize identically")
	_check(bool(overrun.metrics.pacing_overrun) and not overrun.eligible, "overrun is diagnostic and cannot force fork")
	_check(Planner.PACING_DEFERRAL_WINDOW_M == 200.0, "pacing review window is 200m")
	_check(Planner.MIN_LEG_BAND_M == 550.0 and Planner.MAX_LEG_BAND_M == 900.0, "diagnostic leg band matches roadmap proposal")
	_check(_check_trace_ring(planner), "production diagnostic history is deterministic and capped")

	# Phase 6D: Biome-aware continuous pacing checks
	var biome_planner = Planner.new()
	biome_planner.update_pacing_for_biome(1.0)
	_check(is_equal_approx(biome_planner.min_leg_m, Planner.MOUNTAIN_MIN_LEG_M), "mountain min leg is 200m")
	_check(is_equal_approx(biome_planner.max_leg_m, Planner.MOUNTAIN_MAX_LEG_M), "mountain max leg is 350m")
	_check(biome_planner.evaluate_candidate(250.0, 280.0, 0, true).metrics.pacing_band == "within", "mountain candidate in 200-350m is within band")
	_check(biome_planner.evaluate_candidate(250.0, 180.0, 0, true).metrics.pacing_band == "short", "mountain candidate under 200m is short")
	_check(biome_planner.evaluate_candidate(250.0, 380.0, 0, true).metrics.pacing_band == "long", "mountain candidate over 350m is long")

	biome_planner.update_pacing_for_biome(0.0)
	_check(is_equal_approx(biome_planner.min_leg_m, Planner.FOREST_MIN_LEG_M), "forest min leg is 450m")
	_check(is_equal_approx(biome_planner.max_leg_m, Planner.FOREST_MAX_LEG_M), "forest max leg is 650m")
	_check(biome_planner.evaluate_candidate(550.0, 550.0, 0, true).metrics.pacing_band == "within", "forest candidate in 450-650m is within band")
	_check(biome_planner.evaluate_candidate(550.0, 400.0, 0, true).metrics.pacing_band == "short", "forest candidate under 450m is short")
	_check(biome_planner.evaluate_candidate(550.0, 700.0, 0, true).metrics.pacing_band == "long", "forest candidate over 650m is long")

	biome_planner.update_pacing_for_biome(0.5)
	_check(is_equal_approx(biome_planner.min_leg_m, 325.0), "transition min leg interpolated to 325m")
	_check(is_equal_approx(biome_planner.max_leg_m, 500.0), "transition max leg interpolated to 500m")

	print("FORK_PACING_PLANNER_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check_trace_ring(planner: RefCounted) -> bool:
	var first = StreamerClass.new()
	var branch = StreamerClass.RoadBranch.new()
	branch.branch_id = 7
	branch.road_logic = RoadLogicClass.new(184729, load("res://scripts/world/road_path_data.gd").new())
	for i in range(70):
		var decision: Dictionary = planner.evaluate_candidate(700.0, 700.0 + float(i) * 50.0, i, false)
		first._record_fork_pacing_candidate(branch, decision)
	var capped: bool = first.fork_pacing_trace.size() == 64 and int(first.fork_pacing_trace[0].candidate_ordinal) == 7
	var signature: String = JSON.stringify(first.fork_pacing_trace, "", false).sha256_text()
	var second = StreamerClass.new()
	for i in range(70):
		var decision: Dictionary = planner.evaluate_candidate(700.0, 700.0 + float(i) * 50.0, i, false)
		second._record_fork_pacing_candidate(branch, decision)
	var deterministic: bool = signature == JSON.stringify(second.fork_pacing_trace, "", false).sha256_text()
	first.free()
	second.free()
	return capped and deterministic

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[FAIL] " + label)
	else:
		print("[PASS] " + label)
