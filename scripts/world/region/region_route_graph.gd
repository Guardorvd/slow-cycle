class_name RegionRouteGraph
extends RefCounted

## Immutable R5 regional route network of one region: the R5 RouteNetworkPlan.
## Produced only by RoutePlanner; read by diagnostics now and by R6 road
## synthesis later through RouteCorridor views (`get_corridor`).
##
## Storage is integer and region-local (cm, permille, milli-units, enums), like
## R1/R3, so canonical text and signature are exact. World = origin + local.
##
## nodes[]   GATEWAY (valley-end region entry/exit, degree 1), JUNCTION (fork /
##           merge, degree 3-4) or TERMINUS (justified dead-end, degree 1).
## edges[]   one undirected corridor between two nodes, stations ordered a->b.
##           A corridor is NOT a spline: R6 may place a road anywhere inside
##           the per-station left/right half-widths, entering and leaving
##           through the junction zones. Bands of different edges may overlap
##           (they are search freedom, not land reservations); duplicate route
##           geometry is what is invalid.
## routes[]  the journey grouping of edges with one class and purpose.
## loops[]   explicit independent cycles: a branch route between a fork and a
##           merge node and the reference network path it is an alternative to.
## anchors[] geographic planning reasons (not landmarks, vistas or gameplay).
## Crossing hints FORD / SMALL_BRIDGE / BRIDGE record that a water crossing is
## required and its likely engineering class; they are R5 planning hints that
## R6/R12/R13 may refine (Alpha heuristics, not world contracts).

const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SCHEMA_TAG := "slow_cycle.region_route_graph/1"
const CORRIDOR_SCHEMA_TAG := "slow_cycle.route_corridor/1"
const DOMAIN_CM: int = 409600
const STATION_SPACING_CM: int = 3200
const JUNCTION_ZONE_M: float = 96.0
const JUNCTION_ANGLE_DEG: float = 30.0
const JUNCTION_SPACING_M: float = 200.0
## Validator tolerances: the planner stands only on nodes >= 64 m from the
## region edge (or <= 128 m from a chosen gateway); these limits absorb
## reference-line simplification and station spacing.
const EDGE_MARGIN_M: float = 40.0
const GATEWAY_APPROACH_M: float = 260.0
const MIN_HALF_WIDTH_CM: int = 800
const MAX_HALF_WIDTH_CM: int = 12000
const MIN_LOOP_CYCLE_M: float = 1200.0
const DUPLICATE_DISTANCE_M: float = 64.0
const DUPLICATE_FRACTION: float = 0.2

enum RouteClass { BACKBONE, SECONDARY, SINGLETRACK, TECHNICAL }
const CLASS_NAMES := ["BACKBONE", "SECONDARY", "SINGLETRACK", "TECHNICAL"]
## Semantic hierarchy (approval condition 3): the classes a route of each class
## may depend on to reach the backbone. A route never requires a harder class.
const RELIES_ON := {
	RouteClass.BACKBONE: [RouteClass.BACKBONE],
	RouteClass.SECONDARY: [RouteClass.BACKBONE, RouteClass.SECONDARY],
	RouteClass.SINGLETRACK: [RouteClass.BACKBONE, RouteClass.SECONDARY, RouteClass.SINGLETRACK],
	RouteClass.TECHNICAL: [RouteClass.BACKBONE, RouteClass.SECONDARY, RouteClass.SINGLETRACK, RouteClass.TECHNICAL],
}
enum NodeKind { GATEWAY, JUNCTION, TERMINUS }
const NODE_KIND_NAMES := ["GATEWAY", "JUNCTION", "TERMINUS"]
enum Justification { NONE, REGION_GATEWAY, PASS, SHOULDER, LAKE_SHORE, UPLAND_BASIN, SIDE_VALLEY_HEAD }
const JUSTIFICATION_NAMES := ["NONE", "REGION_GATEWAY", "PASS", "SHOULDER", "LAKE_SHORE", "UPLAND_BASIN", "SIDE_VALLEY_HEAD"]
enum Purpose { BACKBONE, LOOP_ALTERNATIVE, SHORTCUT, CROSS_CONNECTION, JUSTIFIED_SPUR }
const PURPOSE_NAMES := ["BACKBONE", "LOOP_ALTERNATIVE", "SHORTCUT", "CROSS_CONNECTION", "JUSTIFIED_SPUR"]
enum AnchorKind { GATEWAY, RIVER_REACH, SIDE_VALLEY_MOUTH, SIDE_VALLEY_HEAD, PASS, SHOULDER, SPUR_NOSE, BENCH, UPLAND_BASIN, MEADOW, LAKE_SHORE, AUTUMN_POCKET }
const ANCHOR_KIND_NAMES := ["GATEWAY", "RIVER_REACH", "SIDE_VALLEY_MOUTH", "SIDE_VALLEY_HEAD", "PASS", "SHOULDER", "SPUR_NOSE", "BENCH", "UPLAND_BASIN", "MEADOW", "LAKE_SHORE", "AUTUMN_POCKET"]
enum AnchorStatus { USED, UNUSED, REJECTED }
const ANCHOR_STATUS_NAMES := ["USED", "UNUSED", "REJECTED"]
## Terminus justification -> the anchor kind that must back it.
const JUSTIFYING_ANCHOR := {
	Justification.PASS: AnchorKind.PASS,
	Justification.SHOULDER: AnchorKind.SHOULDER,
	Justification.LAKE_SHORE: AnchorKind.LAKE_SHORE,
	Justification.UPLAND_BASIN: AnchorKind.UPLAND_BASIN,
	Justification.SIDE_VALLEY_HEAD: AnchorKind.SIDE_VALLEY_HEAD,
}
enum WaterKind { MAJOR_RIVER, TRIBUTARY, CREEK }
const WATER_KIND_NAMES := ["MAJOR_RIVER", "TRIBUTARY", "CREEK"]
enum Hint { FORD, SMALL_BRIDGE, BRIDGE }
const HINT_NAMES := ["FORD", "SMALL_BRIDGE", "BRIDGE"]
const ALLOWED_HINTS := {
	RouteClass.BACKBONE: [Hint.FORD, Hint.SMALL_BRIDGE, Hint.BRIDGE],
	RouteClass.SECONDARY: [Hint.FORD, Hint.SMALL_BRIDGE, Hint.BRIDGE],
	RouteClass.SINGLETRACK: [Hint.FORD, Hint.SMALL_BRIDGE, Hint.BRIDGE],
	RouteClass.TECHNICAL: [Hint.FORD, Hint.SMALL_BRIDGE],
}
enum Flag { NEAR_WATER = 1, CROSSING = 2, DEVELOPMENT_REQUIRED = 4, STEEP_PINCH = 8, WET = 16, OPEN = 32, DENSE_COVER = 64, JUNCTION_ZONE = 128 }
const FLAG_NAMES := ["NEAR_WATER", "CROSSING", "DEVELOPMENT_REQUIRED", "STEEP_PINCH", "WET", "OPEN", "DENSE_COVER", "JUNCTION_ZONE"]
enum Reason { FOLLOWS_RIVER = 1, CLIMBS_TO_BENCH = 2, REACHES_PASS = 4, ENTERS_SIDE_VALLEY = 8, HIGH_TRAVERSE = 16, VISITS_MEADOW = 32, LAKE_SHORE = 64, AUTUMN_WOODS = 128, FOREST_OPEN_TRANSITION = 256, DESCENDS_TO_WATER = 512, RIVER_CROSSING = 1024, CREEK_CROSSING = 2048, SCENIC_ALTERNATIVE = 4096, SHORTCUT = 8192, CONNECTS_LOOPS = 16384, VALLEY_ROAD = 32768 }
const REASON_NAMES := ["FOLLOWS_RIVER", "CLIMBS_TO_BENCH", "REACHES_PASS", "ENTERS_SIDE_VALLEY", "HIGH_TRAVERSE", "VISITS_MEADOW", "LAKE_SHORE", "AUTUMN_WOODS", "FOREST_OPEN_TRANSITION", "DESCENDS_TO_WATER", "RIVER_CROSSING", "CREEK_CROSSING", "SCENIC_ALTERNATIVE", "SHORTCUT", "CONNECTS_LOOPS", "VALLEY_ROAD"]

const SCALARS := {"region_signature": TYPE_STRING, "hydrology_signature": TYPE_STRING, "rideability_signature": TYPE_STRING, "model": TYPE_STRING, "route_seed": TYPE_INT, "origin_x_m": TYPE_INT, "origin_z_m": TYPE_INT, "frame_symmetry": TYPE_INT, "planning_spacing_m": TYPE_INT}
const NODE_KEYS: Array[String] = ["id", "kind", "x_cm", "z_cm", "elevation_cm", "anchor_id", "justification"]
const EDGE_KEYS: Array[String] = ["id", "a", "b", "route_id", "class", "length_cm", "climb_cm", "descent_cm", "reasons"]
const CORRIDOR_ARRAYS: Array[String] = ["x_cm", "z_cm", "elevation_cm", "grade_permille", "cross_permille", "half_left_cm", "half_right_cm", "cost_milli", "biome", "flags"]
const CROSSING_KEYS: Array[String] = ["station", "water_kind", "channel_id", "x_cm", "z_cm", "width_cm", "depth_cm", "angle_deg", "hint"]
const ROUTE_KEYS: Array[String] = ["id", "class", "purpose", "start_node", "end_node", "score_milli", "reasons"]
const LOOP_KEYS: Array[String] = ["id", "fork_node", "merge_node", "branch_length_cm", "reference_length_cm"]
const ANCHOR_KEYS: Array[String] = ["id", "kind", "x_cm", "z_cm", "elevation_cm", "status"]

var _data: Dictionary
var _diagnostics: Dictionary


func _init(data: Dictionary = {}, diagnostics: Dictionary = {}) -> void:
	_data = data.duplicate(true)
	_diagnostics = diagnostics.duplicate(true)


# --- Accessors (deep copies; the graph is immutable) ---

func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)


func get_route_node_count() -> int:
	return _data.get("nodes", []).size()


func get_route_node(index: int) -> Dictionary:
	return _data.nodes[index].duplicate(true)


func get_edge_count() -> int:
	return _data.get("edges", []).size()


func get_edge(index: int) -> Dictionary:
	return _data.edges[index].duplicate(true)


func get_route_count() -> int:
	return _data.get("routes", []).size()


func get_route(index: int) -> Dictionary:
	return _data.routes[index].duplicate(true)


func get_loop_count() -> int:
	return _data.get("loops", []).size()


func get_loop(index: int) -> Dictionary:
	return _data.loops[index].duplicate(true)


func get_anchor_count() -> int:
	return _data.get("anchors", []).size()


func get_anchor(index: int) -> Dictionary:
	return _data.anchors[index].duplicate(true)


## Region origin as int64 metres. Never pack it into Vector2/Vector2i
## (float32/int32): subtract it in scalar float64 first.
func get_origin_x_m() -> int:
	return _data.get("origin_x_m", 0)


func get_origin_z_m() -> int:
	return _data.get("origin_z_m", 0)


func edges_at(node: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for edge: Dictionary in _data.get("edges", []):
		if edge.a == node or edge.b == node:
			result.append(edge.id)
	return result


## RouteCorridor view (`slow_cycle.route_corridor/1`): the R6 input boundary.
## World-space metres are derived from the integer region-local storage.
func get_corridor(index: int) -> Dictionary:
	var edge: Dictionary = _data.edges[index]
	var corridor: Dictionary = edge.corridor
	var ox: float = float(_data.origin_x_m)
	var oz: float = float(_data.origin_z_m)
	var view := {"schema": CORRIDOR_SCHEMA_TAG, "edge_id": edge.id, "route_id": edge.route_id, "class": edge.class, "class_name": CLASS_NAMES[edge.class],
		"a": edge.a, "b": edge.b, "length_m": edge.length_cm / 100.0, "climb_m": edge.climb_cm / 100.0, "descent_m": edge.descent_cm / 100.0,
		"reasons": edge.reasons, "junction_zone_m": JUNCTION_ZONE_M, "station_count": corridor.x_cm.size(),
		"x_m": PackedFloat64Array(), "z_m": PackedFloat64Array(), "elevation_m": PackedFloat64Array(), "grade": PackedFloat64Array(), "cross_slope": PackedFloat64Array(),
		"half_left_m": PackedFloat64Array(), "half_right_m": PackedFloat64Array(), "cost": PackedFloat64Array(), "biome": corridor.biome.duplicate(), "flags": corridor.flags.duplicate(),
		"crossings": [], "anchors_passed": edge.anchors_passed.duplicate()}
	for k in range(corridor.x_cm.size()):
		view.x_m.append(ox + corridor.x_cm[k] / 100.0)
		view.z_m.append(oz + corridor.z_cm[k] / 100.0)
		view.elevation_m.append(corridor.elevation_cm[k] / 100.0)
		view.grade.append(corridor.grade_permille[k] / 1000.0)
		view.cross_slope.append(corridor.cross_permille[k] / 1000.0)
		view.half_left_m.append(corridor.half_left_cm[k] / 100.0)
		view.half_right_m.append(corridor.half_right_cm[k] / 100.0)
		view.cost.append(corridor.cost_milli[k] / 1000.0)
	for crossing: Dictionary in edge.crossings:
		var copy: Dictionary = crossing.duplicate(true)
		copy["x_m"] = ox + crossing.x_cm / 100.0
		copy["z_m"] = oz + crossing.z_cm / 100.0
		copy["hint_name"] = HINT_NAMES[crossing.hint]
		copy["water_kind_name"] = WATER_KIND_NAMES[crossing.water_kind]
		view.crossings.append(copy)
	return view


# --- Canonical text and signature ---

static func _text(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var parts: PackedStringArray = []
		for key: Variant in keys:
			parts.append(str(key) + ":" + _text(value[key]))
		return "{" + ";".join(parts) + "}"
	if value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedByteArray:
		var items: PackedStringArray = []
		for item: Variant in value:
			items.append(_text(item))
		return "[" + ",".join(items) + "]"
	return str(value)


func canonical_text() -> String:
	return SCHEMA_TAG + "\n" + _text(_data) + "\n"


func signature() -> String:
	return canonical_text().sha256_text()


func diagnostics_signature() -> String:
	return _text(_diagnostics).sha256_text()


# --- Geometry helpers shared by the planner, validator and tests ---

static func polyline_length_cm(xs: Variant, zs: Variant) -> float:
	var total: float = 0.0
	for k in range(1, xs.size()):
		total += Vector2(xs[k] - xs[k - 1], zs[k] - zs[k - 1]).length()
	return total


## Point at arc length `distance_cm` from the start (or end if reversed).
static func point_along(xs: Variant, zs: Variant, distance_cm: float, from_end: bool) -> Vector2:
	var count: int = xs.size()
	var remaining: float = distance_cm
	for step in range(1, count):
		var i0: int = count - step if from_end else step - 1
		var i1: int = count - step - 1 if from_end else step
		var a := Vector2(xs[i0], zs[i0])
		var b := Vector2(xs[i1], zs[i1])
		var length: float = a.distance_to(b)
		if length >= remaining and length > 0.0:
			return a.lerp(b, remaining / length)
		remaining -= length
	var last: int = 0 if from_end else count - 1
	return Vector2(xs[last], zs[last])


static func angle_between_deg(a: Vector2, b: Vector2) -> float:
	if a.length() <= 0.0 or b.length() <= 0.0:
		return 0.0
	return rad_to_deg(absf(a.angle_to(b)))


# --- Validation: diagnostic only, fixed check order, never repairs ---

static func _typed_array(value: Variant) -> bool:
	return value is PackedInt32Array or value is PackedInt64Array or value is PackedByteArray or value is Array


func _schema_ok() -> bool:
	for key: String in SCALARS:
		if not _data.has(key) or typeof(_data[key]) != SCALARS[key]:
			return false
	for key: String in ["nodes", "edges", "routes", "loops", "anchors"]:
		if not _data.get(key) is Array:
			return false
	for node: Variant in _data.nodes:
		if not node is Dictionary:
			return false
		for key: String in NODE_KEYS:
			if not node.get(key) is int:
				return false
	for edge: Variant in _data.edges:
		if not edge is Dictionary or not edge.get("corridor") is Dictionary or not edge.get("crossings") is Array or not edge.get("anchors_passed") is PackedInt32Array:
			return false
		for key: String in EDGE_KEYS:
			if not edge.get(key) is int:
				return false
		for key: String in CORRIDOR_ARRAYS:
			if not _typed_array(edge.corridor.get(key)):
				return false
		for crossing: Variant in edge.crossings:
			if not crossing is Dictionary:
				return false
			for key: String in CROSSING_KEYS:
				if not crossing.get(key) is int:
					return false
	for route: Variant in _data.routes:
		if not route is Dictionary or not route.get("edge_ids") is PackedInt32Array or not route.get("anchor_ids") is PackedInt32Array:
			return false
		for key: String in ROUTE_KEYS:
			if not route.get(key) is int:
				return false
	for loop: Variant in _data.loops:
		if not loop is Dictionary or not loop.get("branch_edge_ids") is PackedInt32Array or not loop.get("reference_edge_ids") is PackedInt32Array:
			return false
		for key: String in LOOP_KEYS:
			if not loop.get(key) is int:
				return false
	for anchor: Variant in _data.anchors:
		if not anchor is Dictionary or not anchor.get("source") is String or not anchor.get("reason_code") is String:
			return false
		for key: String in ANCHOR_KEYS:
			if not anchor.get(key) is int:
				return false
	return true


func _references_ok() -> Dictionary:
	var ids_ok: bool = true
	var refs_ok: bool = true
	var anchors_ok: bool = true
	var node_count: int = _data.nodes.size()
	var edge_count: int = _data.edges.size()
	var route_count: int = _data.routes.size()
	var anchor_count: int = _data.anchors.size()
	for key: String in ["nodes", "edges", "routes", "loops", "anchors"]:
		for i in range(_data[key].size()):
			ids_ok = ids_ok and _data[key][i].id == i
	for node: Dictionary in _data.nodes:
		refs_ok = refs_ok and node.kind >= 0 and node.kind < NODE_KIND_NAMES.size() and node.justification >= 0 and node.justification < JUSTIFICATION_NAMES.size()
		anchors_ok = anchors_ok and node.anchor_id >= -1 and node.anchor_id < anchor_count
	for edge: Dictionary in _data.edges:
		refs_ok = refs_ok and edge.a >= 0 and edge.a < node_count and edge.b >= 0 and edge.b < node_count and edge.route_id >= 0 and edge.route_id < route_count and edge.class >= 0 and edge.class < CLASS_NAMES.size()
		for k in range(0, edge.anchors_passed.size(), 2):
			anchors_ok = anchors_ok and edge.anchors_passed[k] >= 0 and edge.anchors_passed[k] < anchor_count
		anchors_ok = anchors_ok and edge.anchors_passed.size() % 2 == 0
	for route: Dictionary in _data.routes:
		refs_ok = refs_ok and route.class >= 0 and route.class < CLASS_NAMES.size() and route.purpose >= 0 and route.purpose < PURPOSE_NAMES.size() and not route.edge_ids.is_empty()
		refs_ok = refs_ok and route.start_node >= 0 and route.start_node < node_count and route.end_node >= 0 and route.end_node < node_count
		for e: int in route.edge_ids:
			refs_ok = refs_ok and e >= 0 and e < edge_count
		for a: int in route.anchor_ids:
			anchors_ok = anchors_ok and a >= 0 and a < anchor_count
	for loop: Dictionary in _data.loops:
		refs_ok = refs_ok and loop.fork_node >= 0 and loop.fork_node < node_count and loop.merge_node >= 0 and loop.merge_node < node_count
		for e: int in loop.branch_edge_ids + loop.reference_edge_ids:
			refs_ok = refs_ok and e >= 0 and e < edge_count
	for anchor: Dictionary in _data.anchors:
		anchors_ok = anchors_ok and anchor.kind >= 0 and anchor.kind < ANCHOR_KIND_NAMES.size() and anchor.status >= 0 and anchor.status < ANCHOR_STATUS_NAMES.size()
	return {"ids": ids_ok, "refs": refs_ok, "anchors": anchors_ok}


func _adjacency(edge_filter: Callable) -> Array:
	var adjacency: Array = []
	for i in range(_data.nodes.size()):
		adjacency.append(PackedInt32Array())
	for edge: Dictionary in _data.edges:
		if edge_filter.call(edge):
			adjacency[edge.a].append(edge.id)
			adjacency[edge.b].append(edge.id)
	return adjacency


## Nodes reached from `starts` over edges accepted by `edge_filter`.
func _reach(starts: PackedInt32Array, edge_filter: Callable) -> PackedByteArray:
	var adjacency: Array = _adjacency(edge_filter)
	var seen := PackedByteArray()
	seen.resize(_data.nodes.size())
	var stack: PackedInt32Array = starts.duplicate()
	for s: int in starts:
		seen[s] = 1
	while not stack.is_empty():
		var n: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		for e: int in adjacency[n]:
			var edge: Dictionary = _data.edges[e]
			var other: int = edge.b if edge.a == n else edge.a
			if seen[other] == 0:
				seen[other] = 1
				stack.append(other)
	return seen


func _node_xz(node: int) -> Vector2:
	return Vector2(_data.nodes[node].x_cm, _data.nodes[node].z_cm)


## Unit direction leaving `node` along edge `e`, measured at the junction zone
## distance on the corridor reference line (legibility measure).
func _leaving_direction(e: int, node: int) -> Vector2:
	var edge: Dictionary = _data.edges[e]
	var corridor: Dictionary = edge.corridor
	var p: Vector2 = point_along(corridor.x_cm, corridor.z_cm, JUNCTION_ZONE_M * 100.0, edge.b == node and edge.a != node)
	return (p - _node_xz(node)).normalized()


func validate() -> Dictionary:
	var reasons: Array[String] = []
	if not _schema_ok() or _data.planning_spacing_m <= 0:
		return {"is_valid": false, "reason_codes": ["ERR_GRAPH_SCHEMA"]}
	var refs: Dictionary = _references_ok()
	if not refs.ids:
		reasons.append("ERR_GRAPH_ID")
	if not refs.refs:
		reasons.append("ERR_GRAPH_REFERENCE")
	if not refs.anchors:
		reasons.append("ERR_GRAPH_ANCHOR_REFERENCE")
	if not reasons.is_empty():
		return {"is_valid": false, "reason_codes": reasons}
	var nodes: Array = _data.nodes
	var edges: Array = _data.edges
	var degree := PackedInt32Array()
	degree.resize(nodes.size())
	var self_loop: bool = false
	for edge: Dictionary in edges:
		if edge.a == edge.b:
			self_loop = true
		degree[edge.a] += 1
		degree[edge.b] += 1
	if self_loop:
		reasons.append("ERR_GRAPH_SELF_LOOP")
	# Orphans: isolated nodes, edges outside exactly one route.
	var membership := PackedInt32Array()
	membership.resize(edges.size())
	for route: Dictionary in _data.routes:
		for e: int in route.edge_ids:
			membership[e] += 1
			if edges[e].route_id != route.id or edges[e].class != route.class:
				membership[e] += 100
	var orphan: bool = nodes.is_empty() or edges.is_empty()
	for i in range(nodes.size()):
		orphan = orphan or degree[i] == 0
	for e in range(edges.size()):
		orphan = orphan or membership[e] != 1
	if orphan:
		reasons.append("ERR_GRAPH_ORPHAN")
	var degree_ok: bool = true
	for node: Dictionary in nodes:
		var d: int = degree[node.id]
		degree_ok = degree_ok and ((d == 1) if node.kind != NodeKind.JUNCTION else (d >= 3 and d <= 4))
	if not degree_ok:
		reasons.append("ERR_GRAPH_NODE_DEGREE")
	if nodes.is_empty() or edges.is_empty():
		return {"is_valid": false, "reason_codes": reasons}
	var all_edges := func(_edge: Dictionary) -> bool: return true
	var reached: PackedByteArray = _reach(PackedInt32Array([0]), all_edges)
	if reached.count(1) != nodes.size():
		reasons.append("ERR_GRAPH_DISCONNECTED")
	var backbone_nodes: PackedInt32Array = _backbone_check(reasons, degree)
	_hierarchy_check(reasons, backbone_nodes)
	_technical_check(reasons)
	_backtrack_check(reasons, degree)
	_justification_check(reasons)
	_loop_check(reasons)
	_corridor_check(reasons)
	_junction_check(reasons)
	_duplicate_check(reasons)
	_crossing_check(reasons)
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}


func _backbone_check(reasons: Array[String], degree: PackedInt32Array) -> PackedInt32Array:
	var nodes: Array = _data.nodes
	var bb_degree := PackedInt32Array()
	bb_degree.resize(nodes.size())
	var bb_edges: int = 0
	for edge: Dictionary in _data.edges:
		if edge.class == RouteClass.BACKBONE:
			bb_edges += 1
			bb_degree[edge.a] += 1
			bb_degree[edge.b] += 1
	var ok: bool = bb_edges > 0
	var ends := PackedInt32Array()
	var on_path := PackedInt32Array()
	for node: Dictionary in nodes:
		var d: int = bb_degree[node.id]
		if d > 0:
			on_path.append(node.id)
		ok = ok and d <= 2
		if d == 1:
			ends.append(node.id)
		if node.kind == NodeKind.GATEWAY:
			ok = ok and d == 1
	ok = ok and ends.size() == 2
	var gateways: int = 0
	for node: Dictionary in nodes:
		gateways += 1 if node.kind == NodeKind.GATEWAY else 0
	ok = ok and gateways == 2
	var backbone_routes: int = 0
	for route: Dictionary in _data.routes:
		if route.purpose == Purpose.BACKBONE or route.class == RouteClass.BACKBONE:
			backbone_routes += 1
			ok = ok and route.purpose == Purpose.BACKBONE and route.class == RouteClass.BACKBONE
	ok = ok and backbone_routes == 1
	if ok:
		var bb_filter := func(edge: Dictionary) -> bool: return edge.class == RouteClass.BACKBONE
		var reach: PackedByteArray = _reach(PackedInt32Array([ends[0]]), bb_filter)
		ok = reach.count(1) == on_path.size() and on_path.size() == bb_edges + 1
		var us := PackedFloat64Array()
		for end: int in ends:
			ok = ok and nodes[end].kind == NodeKind.GATEWAY
			us.append(Macro.local_to_frame(_data.frame_symmetry, nodes[end].x_cm / 100.0, nodes[end].z_cm / 100.0).x)
		if ok:
			ok = minf(us[0], us[1]) <= 1.0 and maxf(us[0], us[1]) >= DOMAIN_CM / 100.0 - 1.0
	if not ok:
		reasons.append("ERR_GRAPH_BACKBONE")
		return PackedInt32Array()
	return on_path


func _hierarchy_check(reasons: Array[String], backbone_nodes: PackedInt32Array) -> void:
	if backbone_nodes.is_empty():
		return
	for cls: int in [RouteClass.SECONDARY, RouteClass.SINGLETRACK, RouteClass.TECHNICAL]:
		var allowed: Array = RELIES_ON[cls]
		var filter := func(edge: Dictionary) -> bool: return edge.class in allowed
		var reach: PackedByteArray = _reach(backbone_nodes, filter)
		for edge: Dictionary in _data.edges:
			if edge.class == cls and (reach[edge.a] == 0 or reach[edge.b] == 0):
				reasons.append("ERR_GRAPH_HIERARCHY")
				return


func _technical_check(reasons: Array[String]) -> void:
	var touched := PackedByteArray()
	touched.resize(_data.nodes.size())
	var any_technical: bool = false
	for edge: Dictionary in _data.edges:
		if edge.class == RouteClass.TECHNICAL:
			any_technical = true
			if _data.nodes[edge.a].kind != NodeKind.JUNCTION or _data.nodes[edge.b].kind != NodeKind.JUNCTION:
				reasons.append("ERR_GRAPH_TECHNICAL_REQUIRED")
				return
		else:
			touched[edge.a] = 1
			touched[edge.b] = 1
	if not any_technical:
		return
	var filter := func(edge: Dictionary) -> bool: return edge.class != RouteClass.TECHNICAL
	var start: int = touched.find(1)
	var reach: PackedByteArray = _reach(PackedInt32Array([maxi(start, 0)]), filter)
	for i in range(_data.nodes.size()):
		if reach[i] == 0:
			reasons.append("ERR_GRAPH_TECHNICAL_REQUIRED")
			return


## No mandatory backtracking: a bridge edge lies on the backbone or leads to a
## side whose only leaves are (justified) termini.
func _backtrack_check(reasons: Array[String], degree: PackedInt32Array) -> void:
	for edge: Dictionary in _data.edges:
		if edge.class == RouteClass.BACKBONE:
			continue
		var removed: int = edge.id
		var filter := func(other: Dictionary) -> bool: return other.id != removed
		var side_a: PackedByteArray = _reach(PackedInt32Array([edge.a]), filter)
		if side_a[edge.b] == 1:
			continue
		var side_b: PackedByteArray = _reach(PackedInt32Array([edge.b]), filter)
		for side: PackedByteArray in [side_a, side_b]:
			var has_backbone: bool = false
			for other: Dictionary in _data.edges:
				if other.class == RouteClass.BACKBONE and side[other.a] == 1:
					has_backbone = true
			if has_backbone:
				continue
			for node: Dictionary in _data.nodes:
				if side[node.id] == 1 and degree[node.id] == 1 and node.kind != NodeKind.TERMINUS:
					reasons.append("ERR_GRAPH_BACKTRACK")
					return


func _justification_check(reasons: Array[String]) -> void:
	for node: Dictionary in _data.nodes:
		var ok: bool = true
		match node.kind:
			NodeKind.GATEWAY:
				ok = node.justification == Justification.REGION_GATEWAY
			NodeKind.JUNCTION:
				ok = node.justification == Justification.NONE
			NodeKind.TERMINUS:
				ok = JUSTIFYING_ANCHOR.has(node.justification) and node.anchor_id >= 0 and _data.anchors[node.anchor_id].kind == JUSTIFYING_ANCHOR[node.justification]
		if not ok:
			reasons.append("ERR_GRAPH_UNJUSTIFIED_DEAD_END")
			return


## Walks `edge_ids` as a path from `start`; returns the end node or -1.
func _walk(edge_ids: PackedInt32Array, start: int) -> int:
	var at: int = start
	var used: Dictionary = {}
	for e: int in edge_ids:
		if used.has(e):
			return -1
		used[e] = true
		var edge: Dictionary = _data.edges[e]
		if edge.a == at:
			at = edge.b
		elif edge.b == at:
			at = edge.a
		else:
			return -1
	return at


func _loop_check(reasons: Array[String]) -> void:
	var cyclomatic: int = _data.edges.size() - _data.nodes.size() + 1
	var ok: bool = _data.loops.size() <= cyclomatic
	for loop: Dictionary in _data.loops:
		ok = ok and loop.fork_node != loop.merge_node and not loop.branch_edge_ids.is_empty() and not loop.reference_edge_ids.is_empty()
		for e: int in loop.branch_edge_ids:
			ok = ok and not e in loop.reference_edge_ids
		if not ok:
			break
		ok = _walk(loop.branch_edge_ids, loop.fork_node) == loop.merge_node and _walk(loop.reference_edge_ids, loop.fork_node) == loop.merge_node
		var branch: int = 0
		var reference: int = 0
		for e: int in loop.branch_edge_ids:
			branch += _data.edges[e].length_cm
		for e: int in loop.reference_edge_ids:
			reference += _data.edges[e].length_cm
		ok = ok and branch == loop.branch_length_cm and reference == loop.reference_length_cm and branch + reference >= MIN_LOOP_CYCLE_M * 100.0
		if not ok:
			break
	if not ok:
		reasons.append("ERR_GRAPH_LOOP_RECORD")


func _near_gateway(p: Vector2) -> bool:
	for node: Dictionary in _data.nodes:
		if node.kind == NodeKind.GATEWAY and p.distance_to(_node_xz(node.id)) <= GATEWAY_APPROACH_M * 100.0:
			return true
	return false


func _corridor_check(reasons: Array[String]) -> void:
	var margin: float = EDGE_MARGIN_M * 100.0
	for edge: Dictionary in _data.edges:
		var c: Dictionary = edge.corridor
		var count: int = c.x_cm.size()
		var ok: bool = count >= 2
		for key: String in CORRIDOR_ARRAYS:
			ok = ok and c[key].size() == count
		if not ok:
			reasons.append("ERR_GRAPH_CORRIDOR")
			return
		ok = Vector2(c.x_cm[0], c.z_cm[0]) == _node_xz(edge.a) and Vector2(c.x_cm[count - 1], c.z_cm[count - 1]) == _node_xz(edge.b)
		for k in range(count):
			var p := Vector2(c.x_cm[k], c.z_cm[k])
			ok = ok and p.x >= 0.0 and p.y >= 0.0 and p.x <= DOMAIN_CM and p.y <= DOMAIN_CM
			ok = ok and c.half_left_cm[k] >= MIN_HALF_WIDTH_CM and c.half_left_cm[k] <= MAX_HALF_WIDTH_CM and c.half_right_cm[k] >= MIN_HALF_WIDTH_CM and c.half_right_cm[k] <= MAX_HALF_WIDTH_CM
			var edge_distance: float = minf(minf(p.x, p.y), minf(DOMAIN_CM - p.x, DOMAIN_CM - p.y))
			ok = ok and (edge_distance >= margin or _near_gateway(p))
			if k > 0:
				var step: float = p.distance_to(Vector2(c.x_cm[k - 1], c.z_cm[k - 1]))
				ok = ok and step > 0.0 and step <= STATION_SPACING_CM + 2.0
		var length: float = polyline_length_cm(c.x_cm, c.z_cm)
		ok = ok and absf(length - edge.length_cm) <= count + 1.0 and edge.climb_cm >= 0 and edge.descent_cm >= 0
		if not ok:
			reasons.append("ERR_GRAPH_CORRIDOR")
			return


func _junction_check(reasons: Array[String]) -> void:
	var angle_ok: bool = true
	var spacing_ok: bool = true
	for node: Dictionary in _data.nodes:
		if node.kind != NodeKind.JUNCTION:
			continue
		var directions: Array = []
		for e: int in edges_at(node.id):
			directions.append(_leaving_direction(e, node.id))
		for i in range(directions.size()):
			for j in range(i + 1, directions.size()):
				angle_ok = angle_ok and angle_between_deg(directions[i], directions[j]) >= JUNCTION_ANGLE_DEG
	for edge: Dictionary in _data.edges:
		if _data.nodes[edge.a].kind == NodeKind.JUNCTION and _data.nodes[edge.b].kind == NodeKind.JUNCTION:
			spacing_ok = spacing_ok and edge.length_cm >= JUNCTION_SPACING_M * 100.0
	if not angle_ok:
		reasons.append("ERR_GRAPH_JUNCTION_ANGLE")
	if not spacing_ok:
		reasons.append("ERR_GRAPH_JUNCTION_SPACING")


## Duplicate geometry (approval condition 2): an edge whose reference line runs
## within DUPLICATE_DISTANCE_M of another edge's line for more than
## DUPLICATE_FRACTION of its stations outside junction zones. Mere corridor
## band overlap is not checked here; it is recorded diagnostically.
func _duplicate_check(reasons: Array[String]) -> void:
	for edge: Dictionary in _data.edges:
		var share: Dictionary = duplicate_shares(edge.id)
		for other: int in share:
			if share[other] > DUPLICATE_FRACTION:
				reasons.append("ERR_GRAPH_DUPLICATE")
				return


## For one edge: other edge id -> share of its stations (outside the junction
## zones of its ends) within DUPLICATE_DISTANCE_M of that edge's line.
func duplicate_shares(edge_id: int) -> Dictionary:
	var lines: Array = []
	for edge: Dictionary in _data.edges:
		lines.append([edge.corridor.x_cm, edge.corridor.z_cm])
	var shares: PackedFloat64Array = line_duplicate_shares(lines[edge_id][0], lines[edge_id][1], lines, edge_id)
	var result: Dictionary = {}
	for other in range(lines.size()):
		if other != edge_id and shares[other] > 0.0:
			result[other] = shares[other]
	return result


## Shared duplicate measure (validator and planner acceptance): for one
## station line, the share of its stations outside JUNCTION_ZONE_M of its own
## ends lying within DUPLICATE_DISTANCE_M of each other line ([xs, zs] in cm).
## `self_index` (if >= 0) is the measured line's own entry in `others`.
static func line_duplicate_shares(xs: Variant, zs: Variant, others: Array, self_index: int = -1) -> PackedFloat64Array:
	var count: int = xs.size()
	var a := Vector2(xs[0], zs[0])
	var b := Vector2(xs[count - 1], zs[count - 1])
	var zone: float = JUNCTION_ZONE_M * 100.0
	var limit: float = DUPLICATE_DISTANCE_M * 100.0
	var near := PackedInt32Array()
	near.resize(others.size())
	var counted: int = 0
	for k in range(count):
		var p := Vector2(xs[k], zs[k])
		if p.distance_to(a) <= zone or p.distance_to(b) <= zone:
			continue
		counted += 1
		for o in range(others.size()):
			if o == self_index:
				continue
			var ox: Variant = others[o][0]
			var oz: Variant = others[o][1]
			for m in range(1, ox.size()):
				var p0 := Vector2(ox[m - 1], oz[m - 1])
				if absf(p.x - p0.x) > limit + 3300.0 or absf(p.y - p0.y) > limit + 3300.0:
					continue
				if Geometry2D.get_closest_point_to_segment(p, p0, Vector2(ox[m], oz[m])).distance_to(p) <= limit:
					near[o] += 1
					break
	var shares := PackedFloat64Array()
	shares.resize(others.size())
	for o in range(others.size()):
		shares[o] = float(near[o]) / float(maxi(counted, 1))
	return shares


func _crossing_check(reasons: Array[String]) -> void:
	for edge: Dictionary in _data.edges:
		var count: int = edge.corridor.x_cm.size()
		for crossing: Dictionary in edge.crossings:
			var ok: bool = crossing.station >= 0 and crossing.station < count and crossing.water_kind >= 0 and crossing.water_kind < WATER_KIND_NAMES.size()
			ok = ok and crossing.hint >= 0 and crossing.hint < HINT_NAMES.size() and crossing.hint in ALLOWED_HINTS[edge.class]
			ok = ok and crossing.width_cm >= 0 and crossing.depth_cm >= 0 and crossing.angle_deg >= 0 and crossing.angle_deg <= 90
			if not ok:
				reasons.append("ERR_GRAPH_CROSSING_RECORD")
				return
