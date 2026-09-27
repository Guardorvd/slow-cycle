extends SceneTree

const PlannerClass = preload("res://scripts/world/fork_site_planner.gd")
const PathClass = preload("res://scripts/world/road_path_data.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const StreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const LogicClass = preload("res://scripts/world/road_logic.gd")
const WorldManagerClass = preload("res://scripts/world/world_manager.gd")

class StubTerrain extends RefCounted:
	var danger_left: bool = false
	var danger_right: bool = false
	var invalid_result: bool = false

	func evaluate_profile(_pos: Vector3, _binorm: Vector3, _curvature: float) -> Dictionary:
		if invalid_result:
			return {}
		return {
			"left_profile": 0,
			"right_profile": 0,
			"danger_left": danger_left,
			"danger_right": danger_right
		}

class RejectPlanner extends RefCounted:
	func evaluate_site(_path: RefCounted, candidate_idx: int, _last_valid: bool, _terrain: RefCounted, _sight: float) -> Dictionary:
		return {"eligible": false, "reason_codes": ["forced_test_rejection"], "metrics": {"candidate_idx": candidate_idx}}

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_check_unit_contract()
	_check_rejected_site_falls_back_to_normal_chunk()
	_check_streamed_seed_decisions()
	print("FORK_SITE_PLANNER_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

func _check_unit_contract() -> void:
	var planner = PlannerClass.new()
	var terrain := StubTerrain.new()
	var path := _make_path()
	var before: PackedVector3Array = path.points.duplicate()
	var accepted: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_assert(accepted.eligible, "valid grounded singletrack site is accepted")
	_assert(accepted.reason_codes.is_empty(), "accepted site has no rejection reasons")
	_assert(path.points == before, "site evaluation does not mutate centerline data")
	var repeated: Dictionary = planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0)
	_assert(accepted == repeated, "identical planner input returns identical decision and metrics")

	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, false, terrain, 50.0), "previous_chunk_invalid"), "invalid preceding chunk is rejected")
	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, true, terrain, 44.9), "planned_approach_sight_short"), "short planned approach sightline is rejected")
	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, true, terrain, INF), "planned_approach_sight_short"), "non-finite planned sightline is rejected")
	terrain.invalid_result = true
	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0), "terrain_result_invalid"), "incomplete terrain profile is rejected")
	terrain.invalid_result = false
	terrain.danger_left = true
	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0), "left_fork_corridor_danger"), "left terrain corridor danger is rejected")
	terrain.danger_left = false
	terrain.danger_right = true
	_assert(_has_reason(planner.evaluate_site(path, path.size() - 1, true, terrain, 50.0), "right_fork_corridor_danger"), "right terrain corridor danger is rejected")
	terrain.danger_right = false

	var narrow := _make_path()
	narrow.road_widths[-3] = Contract.ROAD_STANDARD_WIDTH - 0.1
	_assert(_has_reason(planner.evaluate_site(narrow, narrow.size() - 1, true, terrain, 50.0), "road_too_narrow"), "narrow approach sample is rejected")
	var steep := _make_path()
	steep.slopes[-3] = Contract.MAX_GRADE_DOWNHILL - 1.0
	_assert(_has_reason(planner.evaluate_site(steep, steep.size() - 1, true, terrain, 50.0), "grade_out_of_bounds"), "out-of-contract grade is rejected")
	var sharp := _make_path()
	sharp.curvatures[-3] = Contract.MAX_CURVATURE + 0.01
	_assert(_has_reason(planner.evaluate_site(sharp, sharp.size() - 1, true, terrain, 50.0), "curvature_out_of_bounds"), "out-of-contract curvature is rejected")
	var airborne := _make_path()
	airborne.surface_contact_states[-3] = Airborne.SurfaceContactMode.AIRBORNE
	_assert(_has_reason(planner.evaluate_site(airborne, airborne.size() - 1, true, terrain, 50.0), "approach_not_grounded"), "non-grounded approach is rejected")
	var incomplete := _make_path()
	incomplete.road_widths.remove_at(incomplete.road_widths.size() - 1)
	_assert(_has_reason(planner.evaluate_site(incomplete, incomplete.size() - 1, true, terrain, 50.0), "path_arrays_incomplete"), "misaligned path arrays are rejected")
	var non_finite := _make_path()
	non_finite.cumulative_distances[-2] = INF
	_assert(_has_reason(planner.evaluate_site(non_finite, non_finite.size() - 1, true, terrain, 50.0), "non_finite_path_sample"), "non-finite path distance is rejected")
	var invalid_candidate: Dictionary = planner.evaluate_site(path, 0, true, terrain, 50.0)
	_assert(_has_reason(invalid_candidate, "candidate_index_invalid"), "invalid candidate index is rejected")

func _check_streamed_seed_decisions() -> void:
	for seed_value in [184729, 42, 99999]:
		var first: Dictionary = await _find_first_safe_site(seed_value)
		var second: Dictionary = await _find_first_safe_site(seed_value)
		print("FORK_SITE_SEED seed=%d found=%s deferred_chunks=%d endpoint_m=%.1f rejection_counts=%s" % [
			seed_value, str(first.get("found", false)), int(first.get("deferred_chunks", -1)),
			float(first.get("distance", 0.0)), str(first.get("rejection_counts", {}))
		])
		_assert(first.get("found", false), "seed %d reaches an eligible site within bounded deferral" % seed_value)
		_assert(first == second, "seed %d site decision trace repeats exactly" % seed_value)
		if first.get("found", false):
			_assert(int(first.get("deferred_chunks", -1)) >= 0, "seed %d reports deferred chunk count" % seed_value)

func _check_rejected_site_falls_back_to_normal_chunk() -> void:
	var manager = WorldManagerClass.new()
	manager._init_shared_resources()
	var path = PathClass.new()
	var logic = LogicClass.new(184729, path)
	var streamer = StreamerClass.new()
	streamer.setup(manager, path, logic, manager.shared_materials, manager.shared_meshes)
	var branch = streamer.get_active_branch()
	branch.next_fork_distance = 1.0
	streamer.fork_site_planner = RejectPlanner.new()
	var before_size: int = branch.road_path.size()
	var before_chunk_count: int = branch.active_chunks.size()
	var candidate_width: float = branch.road_path.road_widths[-1]
	print("FORK_SITE_REJECT_SETUP size=%d widths=%d total=%.2f next=%.2f fork=%s chunks=%d" % [before_size, branch.road_path.road_widths.size(), branch.get_total_distance(), branch.next_fork_distance, str(branch.is_fork_spawned), before_chunk_count])
	_assert(not streamer._is_safe_fork_site(branch), "forced candidate evaluator rejects current endpoint")
	streamer.update_streaming(branch.road_path.points[0])
	print("FORK_SITE_REJECT_RESULT size=%d widths=%d total=%.2f eval=%s" % [branch.road_path.size(), branch.road_path.road_widths.size(), branch.get_total_distance(), str(streamer.last_fork_site_evaluation)])
	_assert(branch.road_path.size() > before_size, "rejected fork candidate continues through ordinary chunk generation")
	_assert(branch.active_chunks.size() > before_chunk_count, "rejected candidate commits the ordinary chunk")
	_assert(not branch.is_fork_spawned and branch.child_branch_ids.is_empty(), "rejected candidate creates no fork or child branch")
	_assert(before_size - 1 < branch.road_path.road_widths.size() and is_equal_approx(branch.road_path.road_widths[before_size - 1], candidate_width), "rejected candidate does not widen the existing endpoint")
	_assert(streamer.last_fork_site_evaluation.reason_codes == ["forced_test_rejection"], "rejection reason is retained for diagnostics")
	streamer.free()
	manager.free()

func _find_first_safe_site(seed_value: int) -> Dictionary:
	var manager = WorldManagerClass.new()
	manager._init_shared_resources()
	var path = PathClass.new()
	var logic = LogicClass.new(seed_value, path)
	var streamer = StreamerClass.new()
	streamer.setup(manager, path, logic, manager.shared_materials, manager.shared_meshes)
	var branch = streamer.get_active_branch()
	var result := {"found": false, "deferred_chunks": 0, "distance": 0.0, "reasons": [], "rejection_counts": {}}
	for attempt in range(41):
		if streamer._is_safe_fork_site(branch):
			result = {
				"found": true,
				"deferred_chunks": attempt,
				"distance": branch.get_total_distance(),
				"reasons": streamer.last_fork_site_evaluation.reason_codes.duplicate(),
				"rejection_counts": result.rejection_counts.duplicate()
			}
			break
		var reason_codes: Array = streamer.last_fork_site_evaluation.reason_codes
		result.reasons = reason_codes.duplicate()
		for reason in reason_codes:
			result.rejection_counts[reason] = int(result.rejection_counts.get(reason, 0)) + 1
		streamer._spawn_chunk_sync(branch)
		result.deferred_chunks = attempt + 1
	result.distance = branch.get_total_distance() if not result.found else result.distance
	streamer.free()
	manager.free()
	return result

func _make_path() -> RefCounted:
	var path = PathClass.new()
	for idx in range(16):
		path.append_sample(
			Vector3(0.0, 0.0, -float(idx) * 2.0),
			Vector3(0.0, 0.0, -1.0),
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

func _has_reason(result: Dictionary, reason: String) -> bool:
	return result.get("reason_codes", []).has(reason)

func _assert(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("[PASS] %s" % label)
	else:
		failures += 1
		push_error("[FAIL] %s" % label)
