extends SceneTree

## Diagnostic trace for style-dependent fork-site delays. Does not modify runtime code.

const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const RoadGrammarClass = preload("res://scripts/world/road_grammar.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const SEEDS: Array[int] = [184729, 42]
const MAX_STEPS: int = 1200

var failures: int = 0
var summaries: Array[Dictionary] = []

func _init() -> void:
	print("STYLE_SPACING_AUDIT_START seeds=%s interval_override=100m fallback_attempt_visibility=NOT_EXPOSED" % str(SEEDS))
	for seed_value: int in SEEDS:
		for choice: int in [ForkDecisionModelClass.BranchChoice.LEFT, ForkDecisionModelClass.BranchChoice.RIGHT]:
			var summary: Dictionary = await _trace_route(seed_value, choice)
			if summary.is_empty():
				failures += 1
			else:
				summaries.append(summary)
	_check_role_summary()
	print("STYLE_SPACING_AUDIT_SUMMARY failures=%d traces=%d" % [failures, summaries.size()])
	quit(1 if failures > 0 else 0)

func _trace_route(seed_value: int, choice: int) -> Dictionary:
	var choice_name: String = "LEFT" if choice == ForkDecisionModelClass.BranchChoice.LEFT else "RIGHT"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var world_manager: Node = scene.get_node("WorldManager")
	world_manager.world_seed = seed_value
	root.add_child(scene)
	await process_frame
	await physics_frame

	var bike: CharacterBody3D = scene.get_node("Bicycle")
	var streamer: Node = world_manager.chunk_streamer
	# The diagnostic owns the exact update cadence; avoid a second background stream update.
	world_manager.set_process(false)
	bike.set_process(false)
	bike.set_physics_process(false)
	streamer.first_fork_distance = 100.0
	streamer.fork_interval_dist = 100.0
	streamer.fork_safety_radius = 25.0
	var trunk = streamer.get_active_branch()
	trunk.next_fork_distance = 100.0
	var trunk_path = trunk.road_path
	var trunk_end: int = trunk_path.size() - 1
	bike.global_position = trunk_path.points[trunk_end] + trunk_path.normals[trunk_end] * 0.5
	bike.velocity = trunk_path.tangents[trunk_end] * 8.5
	bike.current_speed = 8.5
	streamer.update_streaming(bike.global_position, bike.velocity)
	await process_frame

	trunk = streamer.get_active_branch()
	var first_fork_pos: Vector3 = trunk.fork_node_pos
	var fork_node_id: int = trunk.graph_fork_node_id
	var selected_edge = streamer.road_graph.get_fork_branch_edge(fork_node_id, choice)
	if selected_edge == null or trunk.decision_model == null:
		push_error("[AUDIT FAIL] seed=%d choice=%s failed to materialize initial graph edge" % [seed_value, choice_name])
		scene.queue_free()
		await process_frame
		return {}
	var selected_path = selected_edge.path_data
	var decision = trunk.decision_model
	var selected_branch_ref = streamer.branches.get(selected_edge.branch_id, null)
	var original_branch_decision = selected_branch_ref.decision_model
	var original_branch_fork_id: int = selected_branch_ref.graph_fork_node_id
	var selected_fork_origin_s: float = selected_branch_ref.road_path.cumulative_distances[_closest_index(selected_branch_ref.road_path, first_fork_pos)]
	var selected_style: int = selected_branch_ref.route_style
	var scheduled_interval_at_choice: float = selected_branch_ref.next_fork_distance
	var generated_chunks: int = 0
	var threshold_s: float = -1.0
	print("AUDIT_ROUTE_START seed=%d choice=%s selected_style=%s branch=%d origin_s=%.1f total_s=%.1f chunks=%d" % [
		seed_value, choice_name, _style_name(selected_style), selected_branch_ref.branch_id,
		selected_fork_origin_s, selected_branch_ref.road_path.get_total_distance(), selected_branch_ref.road_logic.chunks_generated
	])
	for idx in range(0, mini(12, selected_path.size()), 2):
		var chunks_before: Dictionary = _chunk_id_set(selected_branch_ref)
		var pre_update_distance: float = selected_branch_ref.road_path.get_total_distance() - selected_fork_origin_s
		var pre_update_interval: float = selected_branch_ref.next_fork_distance
		if threshold_s < 0.0 and pre_update_distance + 50.0 >= pre_update_interval:
			threshold_s = pre_update_distance
			print("AUDIT_THRESHOLD seed=%d choice=%s selected_style=%s route_m=%.1f interval=%.1f unresolved_fork=%s active_branch=%d safe=%s" % [
				seed_value, choice_name, _style_name(selected_style), threshold_s, pre_update_interval,
				str(selected_branch_ref.is_fork_spawned), streamer.active_branch_id, str(streamer._is_safe_fork_site(selected_branch_ref))
			])
		var pos: Vector3 = selected_path.points[idx] + selected_path.normals[idx] * 0.5
		var vel: Vector3 = selected_path.tangents[idx] * 8.5
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.5
		streamer.update_streaming(pos, vel, 0.1)
		var selected_now = streamer.get_active_branch()
		if selected_now.branch_id == selected_edge.branch_id:
			var choice_state: String = "LOCKED" if decision.is_locked() else "FORK_UNRESOLVED"
			for chunk_id: int in selected_branch_ref.chunk_end_distances:
				if not chunks_before.has(chunk_id):
					generated_chunks += 1
					_print_chunk_event(seed_value, choice_name, selected_style, selected_branch_ref, chunk_id, float(selected_branch_ref.chunk_end_distances[chunk_id]), threshold_s, selected_fork_origin_s, choice_state)
		await physics_frame

	var branch = streamer.get_active_branch()
	if not decision.is_locked() or branch.branch_id != selected_edge.branch_id:
		push_error("[AUDIT FAIL] seed=%d choice=%s choice lock mismatch active=%d expected=%d" % [seed_value, choice_name, branch.branch_id, selected_edge.branch_id])
		scene.queue_free()
		await process_frame
		return {}
	var fork_spawned_before_override: bool = branch.is_fork_spawned and branch.decision_model != null and branch.decision_model != original_branch_decision
	branch.next_fork_distance = 100.0
	var fork_origin_s: float = selected_fork_origin_s
	branch.last_closest_idx = _closest_index(branch.road_path, first_fork_pos)
	var fork_materialized: bool = false
	var actual_fork_distance: float = -1.0
	var steps: int = 0
	if fork_spawned_before_override:
		fork_materialized = true
		var existing_fork = streamer.road_graph.get_fork_node(branch.graph_fork_node_id)
		if existing_fork != null:
			actual_fork_distance = branch.road_path.cumulative_distances[_closest_index(branch.road_path, existing_fork.position)] - fork_origin_s

	while steps < MAX_STEPS and not (branch.is_fork_spawned and branch.decision_model != null and branch.decision_model != original_branch_decision):
		steps += 1
		branch = streamer.get_active_branch()
		var path = branch.road_path
		var closest: int = path.find_closest_index(bike.global_position, branch.last_closest_idx)
		var next_idx: int = mini(closest + 2, path.size() - 1)
		var pos: Vector3 = path.points[next_idx] + path.normals[next_idx] * 0.5
		var vel: Vector3 = path.tangents[next_idx] * 8.5
		var dist_before: float = path.get_total_distance() - fork_origin_s
		var threshold_met: bool = dist_before + 50.0 >= branch.next_fork_distance
		var chunks_before: Dictionary = _chunk_id_set(branch)
		if threshold_met and threshold_s < 0.0:
			threshold_s = dist_before
			print("AUDIT_THRESHOLD seed=%d choice=%s selected_style=%s route_m=%.1f interval=%.1f unresolved_fork=%s active_branch=%d safe=%s" % [
				seed_value, choice_name, _style_name(selected_style), threshold_s, branch.next_fork_distance,
				str(branch.is_fork_spawned), streamer.active_branch_id, str(streamer._is_safe_fork_site(branch))
			])
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.5
		streamer.update_streaming(pos, vel, 0.1)
		await physics_frame
		branch = streamer.get_active_branch()
		for chunk_id: int in branch.chunk_end_distances:
			if not chunks_before.has(chunk_id):
				generated_chunks += 1
				_print_chunk_event(seed_value, choice_name, selected_style, branch, chunk_id, float(branch.chunk_end_distances[chunk_id]), threshold_s, fork_origin_s, "TRAVERSING")
		if branch.is_fork_spawned and branch.decision_model != null and branch.decision_model != original_branch_decision:
			fork_materialized = true
			var next_fork_idx: int = _closest_index(branch.road_path, branch.fork_node_pos)
			actual_fork_distance = branch.road_path.cumulative_distances[next_fork_idx] - fork_origin_s

	if not fork_materialized:
		push_error("[AUDIT FAIL] seed=%d choice=%s no next fork within %d steps; pos=%s route_dist=%.1f last_valid=%s" % [
			seed_value, choice_name, MAX_STEPS, bike.global_position,
			branch.road_path.get_total_distance() - branch.distance_at_last_fork, str(branch.road_logic.last_chunk_passed)
		])
		print("AUDIT_STALL branch=%d style=%s path_total=%.1f fork_origin=%.1f last_idx=%d path_size=%d player_s=%.1f ahead=%.1f next_interval=%.1f safe=%s fork_spawned=%s decision=%s chunks=%d" % [
			branch.branch_id, _style_name(branch.route_style), branch.road_path.get_total_distance(), branch.distance_at_last_fork,
			branch.last_closest_idx, branch.road_path.size(), branch.road_path.cumulative_distances[branch.last_closest_idx],
			branch.road_path.get_total_distance() - branch.road_path.cumulative_distances[branch.last_closest_idx],
			branch.next_fork_distance, str(streamer._is_safe_fork_site(branch)), str(branch.is_fork_spawned),
			str(branch.decision_model != null), branch.road_logic.chunks_generated
		])
		scene.queue_free()
		await process_frame
		return {}

	var delay_m: float = actual_fork_distance - threshold_s if threshold_s >= 0.0 else -1.0
	var summary: Dictionary = {
		"seed": seed_value,
		"choice": choice_name,
		"style": _style_name(selected_style),
		"branch_id": branch.branch_id,
		"distance_to_fork_m": actual_fork_distance,
		"threshold_distance_m": threshold_s,
		"scheduled_interval_at_choice_m": scheduled_interval_at_choice,
		"fork_spawned_before_override": fork_spawned_before_override,
		"delay_after_threshold_m": delay_m,
		"generated_chunks_after_choice": generated_chunks,
		"next_fork_reached": fork_materialized
	}
	print("AUDIT_ROUTE seed=%d choice=%s selected_style=%s style_after_next_fork=%s branch=%d next_fork_m=%.1f threshold_m=%.1f scheduled_interval_m=%.1f override_too_late=%s distance_after_threshold_m=%.1f generated_chunks=%d reached=%s fallback_attempt=NOT_EXPOSED" % [
		seed_value, choice_name, summary.style, _style_name(branch.route_style), summary.branch_id, summary.distance_to_fork_m,
		summary.threshold_distance_m, summary.scheduled_interval_at_choice_m,
		str(summary.fork_spawned_before_override), summary.delay_after_threshold_m,
		summary.generated_chunks_after_choice, str(summary.next_fork_reached)
	])
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	return summary

func _print_chunk_event(seed_value: int, choice_name: String, selected_style: int, branch: RefCounted, chunk_id: int, chunk_end_s: float, threshold_s: float, fork_origin_s: float, rider_state: String) -> void:
	var logic = branch.road_logic
	var grammar = logic.grammar
	var phase: int = grammar.current_phase
	var phase_name: String = _phase_name(phase)
	var queue_names: Array[String] = []
	for queued_phase: int in grammar.phase_queue:
		queue_names.append(_phase_name(queued_phase))
	var path = branch.road_path
	var segment_end: int = _closest_distance_index(path, chunk_end_s)
	var segment_start: int = _closest_distance_index(path, chunk_end_s - 50.0)
	var segment_min: int = RoadPathDataClass.SegmentType.STRAIGHT
	var segment_max: int = RoadPathDataClass.SegmentType.STRAIGHT
	var contacts: Dictionary = {}
	for idx in range(segment_start, segment_end + 1):
		segment_min = mini(segment_min, path.segment_types[idx])
		segment_max = maxi(segment_max, path.segment_types[idx])
		contacts[int(path.surface_contact_states[idx])] = true
	var route_dist: float = chunk_end_s - fork_origin_s
	print("AUDIT_CHUNK seed=%d choice=%s selected_style=%s runtime_style=%s state=%s branch=%d chunk_id=%d route_end_m=%.1f threshold_at=%.1f interval=%.1f phase=%s queue=%s last_valid=%s validator_errors=%d segment_type_span=%d..%d contact_modes=%s recovery_flat_pattern=%s" % [
		seed_value, choice_name, _style_name(selected_style), _style_name(branch.route_style), rider_state, branch.branch_id, chunk_id,
		route_dist, threshold_s, branch.next_fork_distance, phase_name, str(queue_names),
		str(logic.last_chunk_passed), logic.get_last_error_count(), segment_min, segment_max,
		str(contacts.keys()), str(_recovery_flat_pattern(path, segment_start, segment_end))
	])

func _recovery_flat_pattern(path: RefCounted, start_idx: int, end_idx: int) -> bool:
	for idx in range(start_idx, end_idx + 1):
		if path.segment_types[idx] != RoadPathDataClass.SegmentType.RECOVERY_FLAT or absf(path.curvatures[idx]) > 0.00001:
			return false
	return true

func _closest_index(path: RefCounted, pos: Vector3) -> int:
	var best_idx: int = 0
	var best_sq: float = INF
	for idx in range(path.size()):
		var distance_sq: float = path.points[idx].distance_squared_to(pos)
		if distance_sq < best_sq:
			best_sq = distance_sq
			best_idx = idx
	return best_idx

func _closest_distance_index(path: RefCounted, target_s: float) -> int:
	var best_idx: int = 0
	var best_delta: float = INF
	for idx in range(path.size()):
		var delta: float = absf(path.cumulative_distances[idx] - target_s)
		if delta < best_delta:
			best_delta = delta
			best_idx = idx
	return best_idx

func _chunk_id_set(branch: RefCounted) -> Dictionary:
	var result: Dictionary = {}
	for chunk_id: int in branch.chunk_end_distances:
		result[chunk_id] = true
	return result

func _style_name(style: int) -> String:
	if style == RoadGrammarClass.RouteStyle.FLOW:
		return "FLOW"
	if style == RoadGrammarClass.RouteStyle.TECHNICAL:
		return "TECHNICAL"
	return "BALANCED"

func _phase_name(phase: int) -> String:
	match phase:
		RoadGrammarClass.FlowPhase.CRUISE_DOWNHILL: return "CRUISE_DOWNHILL"
		RoadGrammarClass.FlowPhase.FAST_GRAVITY_DESCENT: return "FAST_GRAVITY_DESCENT"
		RoadGrammarClass.FlowPhase.BRAKING_ZONE: return "BRAKING_ZONE"
		RoadGrammarClass.FlowPhase.SWITCHBACK: return "SWITCHBACK"
		RoadGrammarClass.FlowPhase.CREST_MICRO_DROP: return "CREST_MICRO_DROP"
		RoadGrammarClass.FlowPhase.AIRBORNE_DROP: return "AIRBORNE_DROP"
		RoadGrammarClass.FlowPhase.VALID_LANDING_SURFACE: return "VALID_LANDING_SURFACE"
		RoadGrammarClass.FlowPhase.RECOVERY_FLAT: return "RECOVERY_FLAT"
		RoadGrammarClass.FlowPhase.WINDING_SINGLETRACK: return "WINDING_SINGLETRACK"
		RoadGrammarClass.FlowPhase.FOREST_CRUISE: return "FOREST_CRUISE"
		_: return "UNKNOWN_%d" % phase

func _check_role_summary() -> void:
	if summaries.size() != 4:
		failures += 1
		return
	for summary: Dictionary in summaries:
		if not summary.next_fork_reached:
			failures += 1
