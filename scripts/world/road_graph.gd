class_name RoadGraph
extends RefCounted

## Slow Cycle — Road Graph & Topological Foundation (v1.0.0)
## Pure memory Directed Acyclic Graph (DAG) for road topology, branching forks,
## and path continuity. Decoupled from Godot scene nodes (zero Node3D / Mesh / Collider).
## Serves as the finite active topological window across procedural generation.

const RoadKinematicModelClass = preload("res://scripts/world/road_kinematic_model.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")

## Distance downstream from fork node where branch divergence angle is measured
const DIVERGENCE_MEASUREMENT_DISTANCE: float = 15.0

# ==============================================================================
# INNER CLASSES: TOPOLOGICAL DATA STRUCTURES
# ==============================================================================

## Base topological junction / anchor point in the road network
class RoadNode extends RefCounted:
	enum NodeType {
		REGULAR = 0,
		FORK = 1,
		MERGE = 2,    ## Reserved for future multi-path confluence
		TERMINAL = 3
	}

	var node_id: int = -1
	var position: Vector3 = Vector3.ZERO
	var tangent: Vector3 = Vector3.FORWARD
	var normal: Vector3 = Vector3.UP
	var node_type: int = NodeType.REGULAR
	var incoming_edge_ids: Array[int] = []
	var outgoing_edge_ids: Array[int] = []

	func _init(id: int = -1, pos: Vector3 = Vector3.ZERO, tang: Vector3 = Vector3.FORWARD, norm: Vector3 = Vector3.UP, type: int = NodeType.REGULAR) -> void:
		node_id = id
		position = pos
		tangent = tang.normalized() if not tang.is_zero_approx() else Vector3.FORWARD
		normal = norm.normalized() if not norm.is_zero_approx() else Vector3.UP
		node_type = type

## Specialized bifurcation node storing approach context and branch preview definitions
class RoadForkNode extends RoadNode:
	var entry_speed_mps: float = 8.33          ## Baseline ~30 km/h
	var entry_slope_deg: float = -6.0          ## Approach descent slope
	var min_curve_radius_m: float = 19.0       ## Tightest downstream radius
	var preview_distance_m: float = 50.0       ## Distance upstream where fork becomes visible (>= 45m)
	var decision_zone_length_m: float = 25.0   ## Commit / steering choice zone length
	var branch_previews: Array[RefCounted] = [] ## Array[BranchPreviewContext]

	func _init(
		id: int = -1,
		pos: Vector3 = Vector3.ZERO,
		tang: Vector3 = Vector3.FORWARD,
		norm: Vector3 = Vector3.UP,
		speed_mps: float = 8.33,
		slope_deg: float = -6.0,
		radius_m: float = 19.0,
		preview_dist_m: float = 50.0
	) -> void:
		super(id, pos, tang, norm, NodeType.FORK)
		entry_speed_mps = speed_mps
		entry_slope_deg = slope_deg
		min_curve_radius_m = radius_m
		preview_distance_m = preview_dist_m

	## Queries canonical RoadKinematicModel for required speed-matching / stopping distance.
	## Returns 0.0 if already at or below target speed, or INF if downhill slope runaway occurs.
	func get_required_braking_distance(branch_idx: int, regime: int = 1) -> float:
		if branch_idx < 0 or branch_idx >= branch_previews.size():
			return 0.0
		var bp = branch_previews[branch_idx]
		var eval = RoadKinematicModelClass.calculate_braking_distance(
			entry_speed_mps,
			bp.target_speed_mps,
			entry_slope_deg,
			regime
		)
		return eval.distance_m if eval.is_valid else INF

	func add_branch_preview(bp: RefCounted) -> void:
		branch_previews.append(bp)

## Descriptor of an outgoing branch from a fork node
class BranchPreviewContext extends RefCounted:
	# 1. Topological & Physical facts
	var edge_id: int = -1
	var branch_index: int = 0                  ## 0 = Left, 1 = Right, etc.
	var divergence_angle_deg: float = 0.0      ## Relative heading angle measured at DIVERGENCE_MEASUREMENT_DISTANCE
	var target_speed_mps: float = 8.33
	var target_slope_deg: float = -6.0
	var min_curve_radius_m: float = 50.0
	var preview_distance_m: float = 50.0

	# 2. Opaque presentation & gameplay metadata (uninterpreted by RoadGraph)
	var metadata: Dictionary = {}

	func _init(
		e_id: int = -1,
		idx: int = 0,
		div_angle: float = 0.0,
		tgt_speed: float = 8.33,
		tgt_slope: float = -6.0,
		min_radius: float = 50.0,
		meta: Dictionary = {}
	) -> void:
		edge_id = e_id
		branch_index = idx
		divergence_angle_deg = div_angle
		target_speed_mps = tgt_speed
		target_slope_deg = tgt_slope
		min_curve_radius_m = min_radius
		metadata = meta

## Directed edge connecting source node to target node.
## References or holds spline data (RoadPathData). Does NOT generate spline geometry.
class RoadEdge extends RefCounted:
	var edge_id: int = -1
	var source_node_id: int = -1
	var target_node_id: int = -1
	var branch_id: int = RoadPathDataClass.UNASSIGNED_BRANCH_ID
	var length_m: float = 0.0
	var path_data: RefCounted = null           ## RoadPathData instance or null

	func _init(id: int = -1, src: int = -1, dst: int = -1, path: RefCounted = null, b_id: int = -1) -> void:
		edge_id = id
		source_node_id = src
		target_node_id = dst
		path_data = path
		branch_id = b_id
		if path != null and path.has_method("get_total_distance"):
			length_m = path.get_total_distance()

# ==============================================================================
# ROAD GRAPH CONTAINER & TOPOLOGICAL METHODS
# ==============================================================================

var nodes: Dictionary = {}  ## int -> RoadNode
var edges: Dictionary = {}  ## int -> RoadEdge
var root_node_id: int = -1
var _next_node_id: int = 1
var _next_edge_id: int = 1

## Adds a standard regular node
func add_node(
	pos: Vector3,
	tang: Vector3,
	norm: Vector3 = Vector3.UP,
	type: int = RoadNode.NodeType.REGULAR
) -> RoadNode:
	var id: int = _next_node_id
	_next_node_id += 1
	var node := RoadNode.new(id, pos, tang, norm, type)
	nodes[id] = node
	if root_node_id == -1:
		root_node_id = id
	return node

## Adds a specialized fork bifurcation node
func add_fork_node(
	pos: Vector3,
	tang: Vector3,
	norm: Vector3 = Vector3.UP,
	speed_mps: float = 8.33,
	slope_deg: float = -6.0,
	radius_m: float = 19.0,
	preview_dist_m: float = 50.0
) -> RoadForkNode:
	var id: int = _next_node_id
	_next_node_id += 1
	var fork := RoadForkNode.new(id, pos, tang, norm, speed_mps, slope_deg, radius_m, preview_dist_m)
	nodes[id] = fork
	if root_node_id == -1:
		root_node_id = id
	return fork

## Adds a directed edge between two existing nodes
func add_edge(
	src_id: int,
	dst_id: int,
	path: RefCounted = null,
	branch_id: int = RoadPathDataClass.UNASSIGNED_BRANCH_ID
) -> RoadEdge:
	if not nodes.has(src_id) or not nodes.has(dst_id):
		push_error("RoadGraph.add_edge: source %d or target %d node does not exist!" % [src_id, dst_id])
		return null

	var id: int = _next_edge_id
	_next_edge_id += 1
	var edge := RoadEdge.new(id, src_id, dst_id, path, branch_id)
	edges[id] = edge

	nodes[src_id].outgoing_edge_ids.append(id)
	nodes[dst_id].incoming_edge_ids.append(id)
	return edge

func get_node(id: int) -> RoadNode:
	return nodes.get(id, null)

func get_fork_node(id: int) -> RoadForkNode:
	var n = nodes.get(id, null)
	if n is RoadForkNode:
		return n
	return null

func get_edge(id: int) -> RoadEdge:
	return edges.get(id, null)

func get_outgoing_edges(node_id: int) -> Array[RoadEdge]:
	var result: Array[RoadEdge] = []
	var node = nodes.get(node_id, null)
	if node:
		for e_id: int in node.outgoing_edge_ids:
			if edges.has(e_id):
				result.append(edges[e_id])
	return result

func get_incoming_edges(node_id: int) -> Array[RoadEdge]:
	var result: Array[RoadEdge] = []
	var node = nodes.get(node_id, null)
	if node:
		for e_id: int in node.incoming_edge_ids:
			if edges.has(e_id):
				result.append(edges[e_id])
	return result

func get_fork_nodes() -> Array[RoadForkNode]:
	var result: Array[RoadForkNode] = []
	for n in nodes.values():
		if n is RoadForkNode:
			result.append(n)
	return result

func get_all_nodes() -> Array[RoadNode]:
	var result: Array[RoadNode] = []
	for n in nodes.values():
		result.append(n)
	return result

func get_all_edges() -> Array[RoadEdge]:
	var result: Array[RoadEdge] = []
	for e in edges.values():
		result.append(e)
	return result

# ==============================================================================
# TOPOLOGICAL INTEGRITY & DAG VALIDATION
# ==============================================================================

## Verifies that the graph is a strict Directed Acyclic Graph (DAG) using Kahn's Algorithm.
## Operates in O(V + E) time without recursion (zero stack overflow/underflow risk on large graphs).
func is_valid_dag() -> bool:
	if nodes.is_empty():
		return true

	var in_degrees: Dictionary = {}
	for id: int in nodes:
		in_degrees[id] = 0

	for e in edges.values():
		var dst: int = e.target_node_id
		if in_degrees.has(dst):
			in_degrees[dst] += 1

	var queue: Array[int] = []
	for id: int in in_degrees:
		if in_degrees[id] == 0:
			queue.append(id)

	var visited_count: int = 0
	var head: int = 0
	while head < queue.size():
		var u: int = queue[head]
		head += 1
		visited_count += 1

		var node: RoadNode = nodes[u]
		for e_id: int in node.outgoing_edge_ids:
			var edge: RoadEdge = edges.get(e_id, null)
			if edge == null:
				continue
			var v: int = edge.target_node_id
			if in_degrees.has(v):
				in_degrees[v] -= 1
				if in_degrees[v] == 0:
					queue.append(v)

	return visited_count == nodes.size()

## Validates geometric continuity at a node between its incoming edges, node transform, and outgoing edges.
func validate_node_continuity(node_id: int, tol_p: float = 0.001, tol_deg: float = 0.2) -> Dictionary:
	var result := {
		"is_valid": true,
		"node_id": node_id,
		"max_pos_error_m": 0.0,
		"max_tangent_angle_deg": 0.0,
		"errors": []
	}

	var node: RoadNode = nodes.get(node_id, null)
	if node == null:
		result["is_valid"] = false
		result["errors"].append("Node %d does not exist" % node_id)
		return result

	# Check outgoing edges: for fork nodes, all outgoing branches must originate at node position
	for e_id: int in node.outgoing_edge_ids:
		var edge: RoadEdge = edges.get(e_id, null)
		if edge == null or edge.path_data == null:
			continue
		if edge.path_data.size() > 0:
			var p0: Vector3 = edge.path_data.points[0]
			var d_pos: float = p0.distance_to(node.position)
			result["max_pos_error_m"] = maxf(result["max_pos_error_m"], d_pos)
			if d_pos > tol_p:
				result["is_valid"] = false
				result["errors"].append("Outgoing edge %d point[0] pos delta %.4fm > tol %.4fm" % [e_id, d_pos, tol_p])

			# For entry tangent at s=0: each branch must be C1 continuous with node tangent
			var t0: Vector3 = edge.path_data.tangents[0].normalized()
			var dot_t: float = clampf(t0.dot(node.tangent), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_t))
			result["max_tangent_angle_deg"] = maxf(result["max_tangent_angle_deg"], angle_deg)
			if angle_deg > tol_deg:
				result["is_valid"] = false
				result["errors"].append("Outgoing edge %d point[0] tangent dev %.2f deg > tol %.2f deg" % [e_id, angle_deg, tol_deg])

	# Check incoming edges: endpoint must match node position and tangent
	for e_id: int in node.incoming_edge_ids:
		var edge: RoadEdge = edges.get(e_id, null)
		if edge == null or edge.path_data == null:
			continue
		if edge.path_data.size() > 0:
			var p_last: Vector3 = edge.path_data.points[-1]
			var d_pos: float = p_last.distance_to(node.position)
			result["max_pos_error_m"] = maxf(result["max_pos_error_m"], d_pos)
			if d_pos > tol_p:
				result["is_valid"] = false
				result["errors"].append("Incoming edge %d point[-1] pos delta %.4fm > tol %.4fm" % [e_id, d_pos, tol_p])

			var t_last: Vector3 = edge.path_data.tangents[-1].normalized()
			var dot_t: float = clampf(t_last.dot(node.tangent), -1.0, 1.0)
			var angle_deg: float = rad_to_deg(acos(dot_t))
			result["max_tangent_angle_deg"] = maxf(result["max_tangent_angle_deg"], angle_deg)
			if angle_deg > tol_deg:
				result["is_valid"] = false
				result["errors"].append("Incoming edge %d point[-1] tangent dev %.2f deg > tol %.2f deg" % [e_id, angle_deg, tol_deg])

	return result

## Runs comprehensive validation on all nodes and edges in the graph
func validate_full_graph(tol_p: float = 0.001, tol_deg: float = 0.2) -> Dictionary:
	var report := {
		"is_valid": true,
		"dag_valid": true,
		"total_nodes": nodes.size(),
		"total_edges": edges.size(),
		"fork_count": 0,
		"error_count": 0,
		"errors": []
	}

	if not is_valid_dag():
		report["is_valid"] = false
		report["dag_valid"] = false
		report["errors"].append("Graph violates DAG invariant (cycle detected)")
		report["error_count"] += 1

	for n in nodes.values():
		if n is RoadForkNode:
			report["fork_count"] += 1
		var cont = validate_node_continuity(n.node_id, tol_p, tol_deg)
		if not cont["is_valid"]:
			report["is_valid"] = false
			report["error_count"] += cont["errors"].size()
			report["errors"].append_array(cont["errors"])

	return report

# ==============================================================================
# GEOMETRY EXPORT & BRANCH CONVERSION
# ==============================================================================

## Returns an independent deep-copy RoadPathData for a registered edge
func export_edge_to_path_data(edge_id: int) -> RefCounted:
	var edge = edges.get(edge_id, null)
	if edge == null or edge.path_data == null:
		return null
	if edge.path_data.has_method("clone"):
		return edge.path_data.clone()
	return edge.path_data

## Converts all outgoing branches from a fork node into independent RoadPathData instances.
## Returns Dictionary: branch_index (int) -> RoadPathData.
func convert_fork_branches_to_path_data(fork_node_id: int) -> Dictionary:
	var result: Dictionary = {}
	var fork = get_fork_node(fork_node_id)
	if fork == null:
		return result

	var out_edges = get_outgoing_edges(fork_node_id)
	for i in range(out_edges.size()):
		var edge = out_edges[i]
		if edge.path_data != null:
			var branch_copy = export_edge_to_path_data(edge.edge_id)
			if branch_copy != null:
				branch_copy.fork_node_id = fork_node_id
				branch_copy.branch_id = edge.branch_id
				result[i] = branch_copy

	return result

## Prunes nodes and edges with IDs strictly below the threshold (for finite DAG sliding window)
func prune_nodes_behind(node_id_threshold: int) -> int:
	var pruned_count: int = 0
	var nodes_to_remove: Array[int] = []

	for id in nodes:
		if id < node_id_threshold:
			nodes_to_remove.append(id)

	for id in nodes_to_remove:
		var node: RoadNode = nodes[id]
		# Remove associated edges
		for e_id: int in node.incoming_edge_ids:
			edges.erase(e_id)
		for e_id: int in node.outgoing_edge_ids:
			edges.erase(e_id)
		nodes.erase(id)
		pruned_count += 1

	return pruned_count
