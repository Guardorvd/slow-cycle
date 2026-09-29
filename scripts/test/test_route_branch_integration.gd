extends SceneTree

## Drives both generated alternatives through the runtime fork decision model,
## then follows the selected branch to the next fork decision region and proves
## that a real graph edge is selected there. Streamer updates have one owner.

const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const RoadGrammarClass = preload("res://scripts/world/road_grammar.gd")
const TEST_SEEDS: Array[int] = [184729, 42]
const MAX_ROUTE_STEPS: int = 1200
const STEP_SAMPLES: int = 2
const FORK_ARRIVAL_RADIUS: float = 20.0
const ROUTE_MODES: Array[String] = ["CONTROLLED_100M", "SEEDED_DEFAULT"]

var failures: int = 0
var result_rows: Array[Dictionary] = []

func _init() -> void:
	for mode: String in ROUTE_MODES:
		for seed_value: int in TEST_SEEDS:
			for choice: int in [ForkDecisionModelClass.BranchChoice.LEFT, ForkDecisionModelClass.BranchChoice.RIGHT]:
				var row: Dictionary = await _run_route(seed_value, choice, mode)
				if row.is_empty():
					failures += 1
				else:
					result_rows.append(row)
	_check_route_diversity()
	print("ROUTE_INTEGRATION_SUMMARY failures=%d routes=%d" % [failures, result_rows.size()])
	quit(1 if failures > 0 else 0)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("[ROUTE FAIL] " + message)

func _run_route(seed_value: int, choice: int, mode: String) -> Dictionary:
	var choice_name: String = "LEFT" if choice == ForkDecisionModelClass.BranchChoice.LEFT else "RIGHT"
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var world_manager: Node = scene.get_node("WorldManager")
	world_manager.randomize_world_seed_on_start = false
	world_manager.world_seed = seed_value
	world_manager.set_process(false)
	root.add_child(scene)
	await process_frame
	await physics_frame

	var bike: CharacterBody3D = scene.get_node("Bicycle")
	var streamer: Node = world_manager.chunk_streamer
	# This runner is the sole owner of streaming cadence; WorldManager normally
	# calls update_streaming from _process as well.
	world_manager.set_process(false)
	bike.set_process(false)
	bike.set_physics_process(false)
	# Keep the initial junction consistently reachable in both modes. The
	# distinction under test is the schedule after that first choice.
	streamer.first_fork_distance = 100.0
	if mode == "CONTROLLED_100M":
		streamer.fork_interval_dist = 100.0
	streamer.fork_safety_radius = 25.0
	var trunk = streamer.get_active_branch()
	# The initial fork is a fixture for this route comparison; subsequent
	# branch intervals remain either controlled or seed-assigned by mode.
	trunk.next_fork_distance = 100.0
	var trunk_path = trunk.road_path
	var end_index: int = trunk_path.size() - 1
	bike.global_position = trunk_path.points[end_index] + trunk_path.normals[end_index] * 0.5
	bike.velocity = trunk_path.tangents[end_index] * 8.5
	bike.current_speed = 8.5
	streamer.update_streaming(bike.global_position, bike.velocity)
	await process_frame

	trunk = streamer.get_active_branch()
	var fork_node_id: int = trunk.graph_fork_node_id
	var first_fork_pos: Vector3 = trunk.fork_node_pos
	var left_edge = streamer.road_graph.get_fork_branch_edge(fork_node_id, ForkDecisionModelClass.BranchChoice.LEFT)
	var right_edge = streamer.road_graph.get_fork_branch_edge(fork_node_id, ForkDecisionModelClass.BranchChoice.RIGHT)
	_check(left_edge != null and right_edge != null, "seed %d generated graph LEFT and RIGHT edges" % seed_value)
	if left_edge == null or right_edge == null:
		scene.queue_free()
		await process_frame
		return {}

	var selected_edge = left_edge if choice == ForkDecisionModelClass.BranchChoice.LEFT else right_edge
	var selected_path = selected_edge.path_data
	var selected_style_at_choice: int = int(streamer.branches[selected_edge.branch_id].route_style)
	if mode == "CONTROLLED_100M":
		# Set both outgoing schedules before the rider can lock a choice or the
		# primary branch can materialize its next fork.
		streamer.branches[left_edge.branch_id].next_fork_distance = 100.0
		streamer.branches[right_edge.branch_id].next_fork_distance = 100.0
	var decision = trunk.decision_model
	_check(decision.left_branch_path == left_edge.path_data and decision.right_branch_path == right_edge.path_data,
		"seed %d choice %s model references generated graph centerlines" % [seed_value, choice_name])

	# Progress the actual choice model along the selected generated centerline.
	for idx in range(0, mini(12, selected_path.size()), 2):
		var pos: Vector3 = selected_path.points[idx] + selected_path.normals[idx] * 0.5
		var vel: Vector3 = selected_path.tangents[idx] * 8.5
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.5
		streamer.update_streaming(pos, vel, 0.1)
		await physics_frame
		if decision.is_locked():
			break

	var active = streamer.get_active_branch()
	_check(decision.is_locked(), "seed %d choice %s decision model locked" % [seed_value, choice_name])
	_check(active.branch_id == selected_edge.branch_id,
		"seed %d choice %s activates graph branch %d (active %d)" % [seed_value, choice_name, selected_edge.branch_id, active.branch_id])
	if active.branch_id != selected_edge.branch_id:
		scene.queue_free()
		await process_frame
		return {}
	var active_path = active.road_path
	var route_start_idx: int = _closest_index_full(active_path, first_fork_pos)
	active.last_closest_idx = route_start_idx
	var route_start_s: float = active_path.cumulative_distances[route_start_idx]
	var assigned_interval_m: float = active.next_fork_distance
	var prior_fork_origin_s: float = active.distance_at_last_fork
	var route_start_offset_from_origin_m: float = route_start_s - prior_fork_origin_s
	var next_fork_pre_materialized: bool = active.is_fork_spawned and active.decision_model != null
	var pacing_trace_start: int = streamer.fork_pacing_trace.size()
	var next_fork_pacing_record: Dictionary = {}
	var route_stats: Dictionary = {
		"last_s": route_start_s - 0.01,
		"start_s": route_start_s,
		"start_y": active_path.points[route_start_idx].y,
		"min_grade": INF,
		"max_grade": -INF,
		"min_curv": INF,
		"max_curv": -INF,
		"max_gap": 0.0,
		"contacts": [],
		"seen_contacts": {},
		"contact_counts": {},
		"last_point": Vector3.ZERO,
		"has_last_point": false,
		"solid_chunks": 0,
		"collision_coverage_ok": true
	}
	var step_count: int = 0
	while step_count < MAX_ROUTE_STEPS and not (active.is_fork_spawned and active.decision_model != null):
		step_count += 1
		active = streamer.get_active_branch()
		active_path = active.road_path
		var closest: int = active_path.find_closest_index(bike.global_position, active.last_closest_idx)
		var next_idx: int = mini(closest + STEP_SAMPLES, active_path.size() - 1)
		var pos: Vector3 = active_path.points[next_idx] + active_path.normals[next_idx] * 0.5
		var vel: Vector3 = active_path.tangents[next_idx] * 8.5
		_record_route_samples(active_path, next_idx, active, route_stats)
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.5
		streamer.update_streaming(pos, vel, 0.1)
		await physics_frame

	active = streamer.get_active_branch()
	var reached_next_fork: bool = active.is_fork_spawned and active.decision_model != null
	_check(reached_next_fork, "seed %d choice %s mode %s materializes next fork within %d traversal steps" % [seed_value, choice_name, mode, MAX_ROUTE_STEPS])
	if not reached_next_fork:
		push_error("[ROUTE DIAGNOSTIC] seed=%d choice=%s pos=%s speed=%.2f branch=%d sample=%d/%d fork_distance=%.2f" % [
			seed_value, choice_name, bike.global_position, bike.velocity.length(), active.branch_id,
			active.last_closest_idx, active.road_path.size(), bike.global_position.distance_to(active.fork_node_pos)
		])
		scene.queue_free()
		await process_frame
		return {}
	for trace_idx in range(streamer.fork_pacing_trace.size() - 1, pacing_trace_start - 1, -1):
		var trace_record: Dictionary = streamer.fork_pacing_trace[trace_idx]
		if int(trace_record.get("branch_id", -1)) == active.branch_id and trace_record.get("decision", "") == "accept":
			next_fork_pacing_record = trace_record.duplicate(true)
			break

	# Keep moving on the actual parent centerline until the rider is in the
	# decision region. The decision then consumes samples on one real outgoing
	# graph edge; verify its lock and selected runtime branch.
	var next_decision = active.decision_model
	var next_fork_pos: Vector3 = active.fork_node_pos
	var next_fork_id: int = active.graph_fork_node_id
	var route_end_idx: int = _closest_index_full(active_path, next_fork_pos)
	while step_count < MAX_ROUTE_STEPS and bike.global_position.distance_to(next_fork_pos) > FORK_ARRIVAL_RADIUS and not next_decision.is_locked():
		step_count += 1
		var approach_idx: int = active_path.find_closest_index(bike.global_position, active.last_closest_idx)
		route_end_idx = _closest_index_full(active_path, next_fork_pos)
		var approach_next: int = mini(approach_idx + STEP_SAMPLES, route_end_idx)
		var approach_pos: Vector3 = active_path.points[approach_next] + active_path.normals[approach_next] * 0.5
		var approach_vel: Vector3 = active_path.tangents[approach_next] * 8.5
		_record_route_samples(active_path, approach_next, active, route_stats)
		bike.global_position = approach_pos
		bike.velocity = approach_vel
		bike.current_speed = 8.5
		streamer.update_streaming(approach_pos, approach_vel, 0.1)
		await physics_frame
		active = streamer.branches.get(active.branch_id, active)
		active_path = active.road_path
	var distance_at_arrival: float = bike.global_position.distance_to(next_fork_pos)
	_check(distance_at_arrival <= FORK_ARRIVAL_RADIUS or next_decision.is_locked(),
		"seed %d choice %s mode %s rider reaches next fork decision region (%.2fm)" % [seed_value, choice_name, mode, distance_at_arrival])
	var next_choice: int = ForkDecisionModelClass.BranchChoice.RIGHT if choice == ForkDecisionModelClass.BranchChoice.LEFT else ForkDecisionModelClass.BranchChoice.LEFT
	var next_edge = streamer.road_graph.get_fork_branch_edge(next_fork_id, next_choice)
	_check(next_edge != null, "seed %d choice %s mode %s next fork exposes selected graph edge" % [seed_value, choice_name, mode])
	if next_edge != null and not next_decision.is_locked():
		var decision_path = next_edge.path_data
		for decision_idx in range(0, mini(12, decision_path.size()), 1):
			var decision_pos: Vector3 = decision_path.points[decision_idx] + decision_path.normals[decision_idx] * 0.5
			var decision_vel: Vector3 = decision_path.tangents[decision_idx] * 8.5
			bike.global_position = decision_pos
			bike.velocity = decision_vel
			bike.current_speed = 8.5
			streamer.update_streaming(decision_pos, decision_vel, 0.1)
			await physics_frame
			if next_decision.is_locked():
				break
	var next_active = streamer.get_active_branch()
	_check(next_decision.is_locked(), "seed %d choice %s mode %s next fork decision locks" % [seed_value, choice_name, mode])
	_check(next_decision.get_locked_branch() == next_choice,
		"seed %d choice %s mode %s next decision locks requested route edge" % [seed_value, choice_name, mode])
	_check(next_active.branch_id == next_edge.branch_id,
		"seed %d choice %s mode %s activates next graph edge branch %d (active %d)" % [seed_value, choice_name, mode, next_edge.branch_id, next_active.branch_id])
	route_end_idx = _closest_index_full(active_path, next_fork_pos)
	_record_route_samples(active_path, route_end_idx, active, route_stats)
	var row: Dictionary = {
		"seed": seed_value,
		"choice": choice_name,
		"mode": mode,
		"branch_id": selected_edge.branch_id,
		"style": _style_name(selected_style_at_choice),
		"assigned_interval_m": assigned_interval_m,
		"route_start_s": route_start_s,
		"prior_fork_origin_s": prior_fork_origin_s,
		"route_start_offset_from_origin_m": route_start_offset_from_origin_m,
		"next_fork_pre_materialized": next_fork_pre_materialized,
		"next_branch_id": next_edge.branch_id if next_edge != null else -1,
		"next_fork_distance_at_arrival_m": distance_at_arrival,
		"next_decision_locked": next_decision.is_locked(),
		"length_m": active_path.cumulative_distances[route_end_idx] - route_stats.start_s,
		"elevation_delta_m": active_path.points[route_end_idx].y - route_stats.start_y,
		"min_grade_deg": route_stats.min_grade,
		"max_grade_deg": route_stats.max_grade,
		"min_curvature": route_stats.min_curv,
		"max_curvature": route_stats.max_curv,
		"contact_sequence": route_stats.contacts,
		"contact_counts": route_stats.contact_counts,
		"max_sample_gap_m": route_stats.max_gap,
		"solid_road_chunks": route_stats.solid_chunks,
		"collision_coverage_ok": route_stats.collision_coverage_ok,
		"pacing_trace": next_fork_pacing_record
	}
	_check(row.length_m > 0.0, "seed %d choice %s route has positive measured length" % [seed_value, choice_name])
	_check(row.max_sample_gap_m <= 2.5, "seed %d choice %s centerline sample continuity <= 2.5m (%.3f)" % [seed_value, choice_name, row.max_sample_gap_m])
	_check(row.solid_road_chunks > 0, "seed %d choice %s has active solid road collision chunks" % [seed_value, choice_name])
	_check(row.collision_coverage_ok, "seed %d choice %s has solid collision chunk coverage across the measured route" % [seed_value, choice_name])
	if mode == "SEEDED_DEFAULT" and not next_fork_pre_materialized:
		_check(not next_fork_pacing_record.is_empty(), "seed %d choice %s default fork has a pacing trace" % [seed_value, choice_name])
		if not next_fork_pacing_record.is_empty():
			_check(absf(float(next_fork_pacing_record.candidate_distance_m) - row.length_m) < 0.1,
				"seed %d choice %s pacing trace matches generated fork distance" % [seed_value, choice_name])
			_check(next_fork_pacing_record.pacing_band == "within" and not next_fork_pacing_record.pacing_overrun,
				"seed %d choice %s default leg remains within diagnostic pacing band" % [seed_value, choice_name])
	print("ROUTE mode=%s seed=%d choice=%s branch=%d style_at_choice=%s target_interval=%.1f target_applies_to_measured_fork=%s fork_pre_materialized=%s route_origin_s=%.1f previous_fork_origin_s=%.1f origin_offset=%.1f actual_distance=%.1f overshoot=%.1f pacing_band=%s pacing_overrun=%s elevation_delta=%.2f grade=[%.2f,%.2f] curvature=[%.4f,%.4f] contact_sequence=%s contact_counts=%s gap=%.3f solid_chunks=%d collision_coverage=%s arrival_dist=%.2f next_locked=%s next_branch=%d" % [
		mode, seed_value, choice_name, row.branch_id, row.style, row.assigned_interval_m,
		str(not row.next_fork_pre_materialized), str(row.next_fork_pre_materialized),
		row.route_start_s, row.prior_fork_origin_s, row.route_start_offset_from_origin_m,
		row.length_m, row.length_m - row.assigned_interval_m,
		str(row.pacing_trace.get("pacing_band", "none")), str(row.pacing_trace.get("pacing_overrun", false)), row.elevation_delta_m,
		row.min_grade_deg, row.max_grade_deg, row.min_curvature, row.max_curvature,
		JSON.stringify(row.contact_sequence), JSON.stringify(row.contact_counts), row.max_sample_gap_m,
		row.solid_road_chunks, str(row.collision_coverage_ok), distance_at_arrival, str(row.next_decision_locked), row.next_branch_id
	])
	scene.queue_free()
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	return row

func _closest_index_full(path: RefCounted, position: Vector3) -> int:
	var best_idx: int = 0
	var best_distance: float = INF
	for idx in range(path.size()):
		var distance_sq: float = path.points[idx].distance_squared_to(position)
		if distance_sq < best_distance:
			best_distance = distance_sq
			best_idx = idx
	return best_idx

func _record_route_samples(path: RefCounted, target_idx: int, branch: RefCounted, stats: Dictionary) -> void:
	var solid_chunk_ends: Array[float] = []
	for chunk_id: int in branch.active_chunks:
		var chunk = branch.active_chunks[chunk_id]
		if is_instance_valid(chunk) and is_instance_valid(chunk.road_body) and chunk.road_body.collision_layer > 0:
			if branch.chunk_end_distances.has(chunk_id):
				solid_chunk_ends.append(float(branch.chunk_end_distances[chunk_id]))
	var last_s: float = stats.last_s
	for idx in range(path.size()):
		var sample_s: float = path.cumulative_distances[idx]
		if sample_s <= last_s or sample_s > path.cumulative_distances[target_idx] + 0.001:
			continue
		stats.min_grade = minf(stats.min_grade, path.slopes[idx])
		stats.max_grade = maxf(stats.max_grade, path.slopes[idx])
		stats.min_curv = minf(stats.min_curv, path.curvatures[idx])
		stats.max_curv = maxf(stats.max_curv, path.curvatures[idx])
		var contact: int = int(path.surface_contact_states[idx])
		stats.contact_counts[contact] = int(stats.contact_counts.get(contact, 0)) + 1
		if not stats.seen_contacts.has(contact):
			stats.seen_contacts[contact] = true
			stats.contacts.append(contact)
		if stats.has_last_point:
			stats.max_gap = maxf(stats.max_gap, stats.last_point.distance_to(path.points[idx]))
		stats.last_point = path.points[idx]
		stats.has_last_point = true
		var covered: bool = false
		for chunk_end_s: float in solid_chunk_ends:
			if sample_s <= chunk_end_s + 0.001 and sample_s >= chunk_end_s - 52.1:
				covered = true
				break
		if not covered:
			stats.collision_coverage_ok = false
	stats.solid_chunks = maxi(stats.solid_chunks, solid_chunk_ends.size())
	stats.last_s = path.cumulative_distances[target_idx]

func _style_name(style: int) -> String:
	if style == RoadGrammarClass.RouteStyle.FLOW:
		return "FLOW"
	if style == RoadGrammarClass.RouteStyle.TECHNICAL:
		return "TECHNICAL"
	return "BALANCED"

func _check_route_diversity() -> void:
	for seed_value: int in TEST_SEEDS:
		var left: Dictionary = {}
		var right: Dictionary = {}
		for row: Dictionary in result_rows:
			if row.seed == seed_value and row.mode == "CONTROLLED_100M":
				if row.choice == "LEFT":
					left = row
				else:
					right = row
		if left.is_empty() or right.is_empty():
			_check(false, "seed %d produced complete LEFT and RIGHT route metrics" % seed_value)
			continue
		var measurable_difference: bool = absf(left.length_m - right.length_m) > 1.0 \
			or absf(left.elevation_delta_m - right.elevation_delta_m) > 0.25 \
			or absf(left.max_curvature - right.max_curvature) > 0.001 \
			or left.contact_sequence != right.contact_sequence
		_check(measurable_difference, "seed %d LEFT/RIGHT routes differ in measured ride profile" % seed_value)
