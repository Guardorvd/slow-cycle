extends SceneTree

## Diagnostic-only audit for close non-connected route paths across several
## generated forks. Reports candidates; it does not assert that proximity alone
## is a gameplay defect.

const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const SEEDS: Array[int] = [184729, 42]
const FORKS_PER_SEED: int = 12
const MAX_STEPS: int = 12000
const MIN_EDGE_END_CLEARANCE: int = 3
const HORIZONTAL_NEAR_M: float = 3.0
const VERTICAL_NEAR_M: float = 2.0

var failures: int = 0
var candidate_count: int = 0

func _init() -> void:
	for seed_value: int in SEEDS:
		for choice_mode: String in ["LEFT_ONLY", "RIGHT_ONLY"]:
			await _audit_seed(seed_value, choice_mode)
	print("ROUTE_CLEARANCE_AUDIT_SUMMARY failures=%d candidates=%d seeds=%d choice_modes=2" % [failures, candidate_count, SEEDS.size()])
	quit(1 if failures > 0 else 0)

func _audit_seed(seed_value: int, choice_mode: String) -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var world_manager: Node = scene.get_node("WorldManager")
	world_manager.world_seed = seed_value
	root.add_child(scene)
	await process_frame
	await physics_frame

	var bike: CharacterBody3D = scene.get_node("Bicycle")
	var streamer: Node = world_manager.chunk_streamer
	world_manager.set_process(false)
	bike.set_process(false)
	bike.set_physics_process(false)
	# Preserve production fork scheduling: only deterministic path choice is
	# scripted for repeatable traversal.
	var initial_branch = streamer.get_active_branch()
	var initial_path = initial_branch.road_path
	var initial_end: int = initial_path.size() - 1
	bike.global_position = initial_path.points[initial_end] + initial_path.normals[initial_end] * 0.4
	bike.velocity = initial_path.tangents[initial_end] * 8.5
	bike.current_speed = 8.5
	var visited_forks: int = 0
	var steps: int = 0
	var road_ray_misses: int = 0
	var road_ray_misses_before_update: int = 0
	var road_ray_misses_after_update: int = 0
	var probe_hits_before: int = 0
	var probe_hits_after: int = 0
	var probe_count: int = 0
	var min_hit_height_delta: float = INF
	var max_hit_height_delta: float = -INF
	var checked_pairs: Dictionary = {}
	var last_fork_id: int = -1

	while steps < MAX_STEPS and visited_forks < FORKS_PER_SEED:
		steps += 1
		var active = streamer.get_active_branch()
		if active == null or active.road_path == null or active.road_path.size() < 2:
			_fail_seed(seed_value, "active route/path disappeared at step %d" % steps, scene)
			return
		var path = active.road_path
		var idx: int = mini(active.last_closest_idx + 2, path.size() - 1)
		var pos: Vector3 = path.points[idx] + path.normals[idx] * 0.4
		var vel: Vector3 = path.tangents[idx] * 8.5
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.5
		var before_results: Array[Dictionary] = _surface_probes(scene, bike, path, idx, pos)
		streamer.update_streaming(pos, vel, 0.1)
		await physics_frame
		var after_results: Array[Dictionary] = _surface_probes(scene, bike, path, idx, pos)
		probe_count += after_results.size()
		for probe_idx in range(after_results.size()):
			var before: Dictionary = before_results[probe_idx]
			var after: Dictionary = after_results[probe_idx]
			if not before.is_empty(): probe_hits_before += 1
			if not after.is_empty():
				probe_hits_after += 1
				var hit_delta: float = float(after.position.y) - path.points[idx].y
				min_hit_height_delta = minf(min_hit_height_delta, hit_delta)
				max_hit_height_delta = maxf(max_hit_height_delta, hit_delta)
		var road_hit: Dictionary = after_results[0]
		if before_results[0].is_empty(): road_ray_misses_before_update += 1
		if road_hit.is_empty():
			road_ray_misses += 1
			road_ray_misses_after_update += 1
			if road_ray_misses <= 5:
				var route_s: float = path.cumulative_distances[mini(idx, path.size() - 1)]
				var covering_chunks: Array[int] = []
				for chunk_id: int in active.chunk_end_distances:
					var chunk_end_s: float = float(active.chunk_end_distances[chunk_id])
					if route_s <= chunk_end_s + 0.01 and route_s >= chunk_end_s - 52.0:
						covering_chunks.append(chunk_id)
				var any_hit_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					pos + Vector3.UP * 5.0, pos - Vector3.UP * 5.0, 0x7FFFFFFF
				)
				any_hit_query.exclude = [bike.get_rid()]
				var any_hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(any_hit_query)
				var chunk_details: Array[String] = []
				for chunk_id: int in covering_chunks:
					var chunk = active.active_chunks.get(chunk_id, null)
					if chunk != null and chunk.road_body != null:
						chunk_details.append("%d:layer%d:shape=%s" % [chunk_id, chunk.road_body.collision_layer, str(chunk.road_body.get_child(0).shape)])
				var hit_layer: int = int(any_hit.collider.collision_layer) if any_hit.has("collider") and "collision_layer" in any_hit.collider else -1
				print("ROAD_COLLISION_MISS seed=%d step=%d branch=%d path_sample=%d route_s=%.2f pos=%s chunks=%s chunk_details=%s active_chunks=%d any_layer=%d any_hit=%s" % [
					seed_value, steps, active.branch_id, idx, route_s, pos, str(covering_chunks), str(chunk_details),
					active.active_chunks.size(), hit_layer, str(any_hit.get("collider", null))
				])

		active = streamer.get_active_branch()
		if active != null and not active.child_branch_ids.is_empty():
			var child = streamer.branches.get(active.child_branch_ids[0], null)
			if child != null and child.state == ChunkStreamerClass.BranchState.PRELOADED:
				if pos.distance_to(active.fork_node_pos) < 40.0:
					var choice: int = ForkDecisionModelClass.BranchChoice.LEFT if choice_mode == "LEFT_ONLY" else ForkDecisionModelClass.BranchChoice.RIGHT
					var fork_node_id: int = active.graph_fork_node_id
					streamer._on_branch_locked(active.fork_id, choice, active.branch_id)
					visited_forks += 1
					print("CLEARANCE_CHOICE seed=%d mode=%s fork=%d choice=%s active_branch=%d graph_node=%d step=%d" % [
						seed_value, choice_mode, visited_forks, "LEFT" if choice == ForkDecisionModelClass.BranchChoice.LEFT else "RIGHT",
						streamer.active_branch_id, fork_node_id, steps
					])
					if fork_node_id != last_fork_id:
						last_fork_id = fork_node_id
						_scan_new_edge_pairs(seed_value, visited_forks, streamer.road_graph, checked_pairs)

	if visited_forks < FORKS_PER_SEED:
		_fail_seed(seed_value, "only traversed %d/%d forks within %d steps" % [visited_forks, FORKS_PER_SEED, MAX_STEPS], scene)
		return
	print("CLEARANCE_SEED_SUMMARY seed=%d mode=%s forks=%d graph_edges=%d center_road_misses_after=%d center_road_misses_before=%d adjacent_probe_hit_rate_before=%d/%d after=%d/%d hit_y_delta_to_centerline=%.3f..%.3f_m" % [seed_value, choice_mode, visited_forks, streamer.road_graph.get_all_edges().size(), road_ray_misses_after_update, road_ray_misses_before_update, probe_hits_before, probe_count, probe_hits_after, probe_count, min_hit_height_delta, max_hit_height_delta])
	scene.queue_free()
	await process_frame
	await process_frame

func _scan_new_edge_pairs(seed_value: int, fork_count: int, graph: RefCounted, checked_pairs: Dictionary) -> void:
	var edges: Array = graph.get_all_edges()
	for i in range(edges.size()):
		var edge_a = edges[i]
		if edge_a.path_data == null or edge_a.path_data.size() <= MIN_EDGE_END_CLEARANCE * 2:
			continue
		for j in range(i + 1, edges.size()):
			var edge_b = edges[j]
			if edge_b.path_data == null or edge_b.path_data.size() <= MIN_EDGE_END_CLEARANCE * 2:
				continue
			var pair_key: String = "%d:%d" % [mini(edge_a.edge_id, edge_b.edge_id), maxi(edge_a.edge_id, edge_b.edge_id)]
			if checked_pairs.has(pair_key):
				continue
			checked_pairs[pair_key] = true
			if edge_a.path_data.fork_node_id == edge_b.path_data.fork_node_id:
				continue
			if _share_endpoint(edge_a, edge_b):
				continue
			var candidate: Dictionary = _nearest_clearance_candidate(edge_a.path_data, edge_b.path_data)
			if not candidate.is_empty():
				candidate_count += 1
				print("CLEARANCE_CANDIDATE seed=%d after_fork=%d edge_a=%d fork_a=%d branch_a=%d edge_b=%d fork_b=%d branch_b=%d horizontal=%.2fm vertical=%.2fm point_a=%s point_b=%s" % [
					seed_value, fork_count, edge_a.edge_id, edge_a.path_data.fork_node_id, edge_a.branch_id,
					edge_b.edge_id, edge_b.path_data.fork_node_id, edge_b.branch_id,
					candidate.horizontal, candidate.vertical, candidate.point_a, candidate.point_b
				])

func _nearest_clearance_candidate(path_a: RefCounted, path_b: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	var best_horizontal: float = HORIZONTAL_NEAR_M
	for i in range(MIN_EDGE_END_CLEARANCE, path_a.size() - MIN_EDGE_END_CLEARANCE):
		var p_a: Vector3 = path_a.points[i]
		for j in range(MIN_EDGE_END_CLEARANCE, path_b.size() - MIN_EDGE_END_CLEARANCE):
			var p_b: Vector3 = path_b.points[j]
			var horizontal: float = Vector2(p_a.x, p_a.z).distance_to(Vector2(p_b.x, p_b.z))
			var vertical: float = absf(p_a.y - p_b.y)
			if horizontal < best_horizontal and vertical <= VERTICAL_NEAR_M:
				best_horizontal = horizontal
				best = {"horizontal": horizontal, "vertical": vertical, "point_a": p_a, "point_b": p_b}
	return best

func _share_endpoint(edge_a: RefCounted, edge_b: RefCounted) -> bool:
	return edge_a.source_node_id == edge_b.source_node_id \
		or edge_a.source_node_id == edge_b.target_node_id \
		or edge_a.target_node_id == edge_b.source_node_id \
		or edge_a.target_node_id == edge_b.target_node_id

func _surface_probes(scene: Node, bike: CharacterBody3D, path: RefCounted, idx: int, pos: Vector3) -> Array[Dictionary]:
	var state: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var lateral: Vector3 = path.tangents[idx].cross(path.normals[idx]).normalized()
	var results: Array[Dictionary] = []
	for offset_m: float in [-0.5, 0.0, 0.5]:
		var sample: Vector3 = pos + lateral * offset_m
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			sample + Vector3.UP * 5.0, sample - Vector3.UP * 5.0, 2
		)
		query.exclude = [bike.get_rid()]
		results.append(state.intersect_ray(query))
	return results

func _fail_seed(seed_value: int, reason: String, scene: Node) -> void:
	failures += 1
	push_error("[CLEARANCE AUDIT FAIL] seed=%d %s" % [seed_value, reason])
	scene.queue_free()
	await process_frame
