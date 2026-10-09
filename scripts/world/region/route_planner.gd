class_name RoutePlanner
extends RefCounted

## R5 regional route planning (ExecPlan v1.0 + approval conditions, §§5-10).
## The single producer of RegionRouteGraph. Composes its own R3/R4 views from
## (RegionPlan, TerrainField, HydrologyPlan) so input identity is guaranteed,
## builds the plan-local 32 m raster, finds geographic anchors, then:
##   stage 0  backbone: lowest-cost valley road between valley-end gateways;
##   rounds   purpose-driven candidates (loop through an anchor, shortcut /
##            technical / cross-connection pairs). Path geometry is always the
##            plausible traversal-cost path (RouteSearch); journey purpose
##            (RouteJourneyScoring JVS, saturating novelty) only decides which
##            candidates exist and which are kept;
##   assembly junctions, edges with corridors, loops, anchors, validation.
## No hidden fallback: failures carry reasons; missing composition is reported
## through DEGRADED_* codes. Deterministic: stable enumeration, id tie-breaks,
## the registered `route` seed only between near-equal options.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Search = preload("res://scripts/world/region/route_search.gd")
const Scoring = preload("res://scripts/world/region/route_journey_scoring.gd")
const Builder = preload("res://scripts/world/region/route_corridor_builder.gd")
const Anchors = preload("res://scripts/world/region/route_anchor_finder.gd")
const Region = preload("res://scripts/world/region/region_plan.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const MODEL := "planner/1;separation=160:5;attach_spacing=200;loop_attach=800;second_ratio=2.5;cap=34000;bridges=4;spurs=2:1500;max_route=6000,5000,2000;tie=.03,.05;gateway_passable=128;floors=1.2,1,.7,.7;spur_scale=.7;connector=12000:1000:24:.6"
const SEPARATION_M: float = 160.0
const SEPARATION_K: float = 5.0
const ATTACH_SPACING_M: float = 200.0
const LOOP_ATTACH_M: float = 800.0
const SECOND_ATTACH_RATIO: float = 2.5
const NETWORK_CAP_M: float = 34000.0
const BRIDGE_BUDGET: int = 4
const MAX_SPURS: int = 2
const MAX_SPUR_M: float = 1500.0
## Per-class hard length caps: technical lines are short options; very long
## loops must be split into purposeful pieces rather than one sprawling route.
const MAX_ROUTE_M: Array[float] = [INF, 6000.0, 5000.0, 2000.0]
const TIE_BACKBONE: float = 0.03
const TIE_CANDIDATE: float = 0.05
const GATEWAY_PASSABLE_M: float = 128.0
const SPUR_SCALE: float = 0.7
const MAX_SEARCH_COST: float = 60000.0
const CONNECTOR_COST: float = 12000.0
const CONNECTOR_ALONG_M: float = 1000.0
const CONNECTOR_STATIONS: int = 24
const MAX_REJECTED: int = 96
const SPUR_KINDS := {Graph.AnchorKind.PASS: Graph.Justification.PASS, Graph.AnchorKind.SHOULDER: Graph.Justification.SHOULDER, Graph.AnchorKind.LAKE_SHORE: Graph.Justification.LAKE_SHORE,
	Graph.AnchorKind.UPLAND_BASIN: Graph.Justification.UPLAND_BASIN, Graph.AnchorKind.SIDE_VALLEY_HEAD: Graph.Justification.SIDE_VALLEY_HEAD}
const MAJOR_KINDS := [Graph.AnchorKind.PASS, Graph.AnchorKind.BENCH, Graph.AnchorKind.SIDE_VALLEY_HEAD, Graph.AnchorKind.UPLAND_BASIN, Graph.AnchorKind.LAKE_SHORE]
const ROUNDS: Array[Dictionary] = [
	{"name": "secondary", "class": Graph.RouteClass.SECONDARY, "pairs": "", "min": 2, "max": 4, "floor": 1.2,
		"kinds": [Graph.AnchorKind.RIVER_REACH, Graph.AnchorKind.BENCH, Graph.AnchorKind.SIDE_VALLEY_HEAD, Graph.AnchorKind.UPLAND_BASIN, Graph.AnchorKind.LAKE_SHORE, Graph.AnchorKind.MEADOW, Graph.AnchorKind.AUTUMN_POCKET, Graph.AnchorKind.SIDE_VALLEY_MOUTH]},
	{"name": "singletrack", "class": Graph.RouteClass.SINGLETRACK, "pairs": "shortcut", "min": 2, "max": 4, "floor": 1.0,
		"kinds": [Graph.AnchorKind.SHOULDER, Graph.AnchorKind.BENCH, Graph.AnchorKind.MEADOW, Graph.AnchorKind.LAKE_SHORE, Graph.AnchorKind.SIDE_VALLEY_HEAD, Graph.AnchorKind.PASS, Graph.AnchorKind.AUTUMN_POCKET, Graph.AnchorKind.UPLAND_BASIN]},
	{"name": "technical", "class": Graph.RouteClass.TECHNICAL, "pairs": "technical", "min": 1, "max": 2, "floor": 0.7,
		"kinds": [Graph.AnchorKind.SHOULDER, Graph.AnchorKind.SPUR_NOSE, Graph.AnchorKind.PASS]},
	{"name": "cross_connection", "class": -1, "pairs": "cross", "min": 1, "max": 3, "floor": 0.7, "kinds": []},
]

var _region_plan: RefCounted
var _hydrology_plan: RefCounted
var _rideability: RefCounted
var _surface: RefCounted
var _hydro_field: RefCounted
var _raster: Raster
var _grid: Dictionary
var _builder: Builder
var _anchors: Array = []
var _route_seed: int
var _relief_m: float
var _symmetry: int
var _passable := PackedByteArray()
var _tables: Dictionary = {}
var _routes: Array = []
var _occupied := PackedByteArray()
var _node_routes: Dictionary = {}
var _endpoints: Dictionary = {}
var _net_adj: Dictionary = {}
var _distance := PackedFloat64Array()
var _version: int = 0
var _along_cache: Dictionary = {}
var _kinds_visited: Dictionary = {}
var _rejected: Array = []
var _bridges: int = 0
var _total_length: float = 0.0
var _spurs: int = 0
var _metrics := {"searches": 0, "expanded": 0, "regenerations": 0, "replans": 0, "candidates": 0, "trial_rejects": 0}
var _rounds_log: Array = []
var _backbone_options: Array = []
var _explanations: Array = []
## Built, certified corridor pieces keyed "route:i0:i1" (the final edges).
var _pieces: Dictionary = {}


static func _failure(reason: String, detail: String = "") -> Dictionary:
	return {"is_valid": false, "graph": null, "reason_code": reason, "detail": detail, "diagnostics": {}}


static func plan(region_plan: RefCounted, terrain_field: RefCounted, hydrology_plan: RefCounted) -> Dictionary:
	if region_plan == null or terrain_field == null or hydrology_plan == null:
		return _failure("ERR_ROUTE_INPUT_MISSING")
	if not region_plan is Region or not terrain_field is Terrain or not hydrology_plan is Hydro or not region_plan.validate().is_valid:
		return _failure("ERR_ROUTE_INPUT_INVALID")
	if terrain_field.get_region_signature() != region_plan.signature() or hydrology_plan.get_region_signature() != region_plan.signature():
		return _failure("ERR_ROUTE_INPUT_MISMATCH")
	var context: Dictionary = Context.create(region_plan, terrain_field, hydrology_plan)
	if not context.is_valid:
		return _failure("ERR_ROUTE_DEPENDENCY", context.reason_code)
	var biome: Dictionary = Biome.create(context.context)
	if not biome.is_valid:
		return _failure("ERR_ROUTE_DEPENDENCY", biome.reason_code)
	var ride: Dictionary = Ride.create(context.context, biome.field)
	if not ride.is_valid:
		return _failure("ERR_ROUTE_DEPENDENCY", ride.reason_code)
	var hydro: Dictionary = HField.create(hydrology_plan, terrain_field)
	if not hydro.is_valid:
		return _failure("ERR_ROUTE_DEPENDENCY", hydro.reason_code)
	var surface: Dictionary = Surface.create(terrain_field, hydro.field)
	if not surface.is_valid:
		return _failure("ERR_ROUTE_DEPENDENCY", surface.reason_code)
	var planner := RoutePlanner.new()
	planner._region_plan = region_plan
	planner._hydrology_plan = hydrology_plan
	planner._rideability = ride.field
	planner._surface = surface.surface
	planner._hydro_field = hydro.field
	var macro: Dictionary = region_plan.get_macro_terrain().get_data()
	planner._symmetry = macro.frame_symmetry
	planner._relief_m = macro.relief_cm / 100.0
	planner._route_seed = Seeds.route_seed(region_plan.get_identity().get_region_seed())
	planner._raster = Raster.create(ride.field, surface.surface, hydro.field, hydrology_plan)
	planner._grid = planner._raster.grid()
	planner._builder = Builder.create(planner._raster, ride.field, surface.surface, hydro.field)
	planner._anchors = Anchors.find(planner._raster, macro, hydrology_plan, biome.field.get_descriptor())
	return planner._run()


# --- Network state ---

static func _smooth(a: float, b: float, value: float) -> float:
	var t: float = clampf((value - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func tie_value(seed_value: int, round_index: int, key: String) -> int:
	var digest: PackedByteArray = ("slow_cycle.route_tie/1\n%d\n%d\n%s" % [seed_value, round_index, key]).sha256_buffer()
	return (int(digest[0]) << 16) | (int(digest[1]) << 8) | int(digest[2])


func _tables_for(route_class: int) -> Dictionary:
	if not _tables.has(route_class):
		_tables[route_class] = Search.build_tables(_grid, route_class, _passable)
	return _tables[route_class]


## Standing nodes: dry, no natural barrier, no water body, inside the region
## margin except near the given gateway nodes (all gateway candidates for the
## backbone search, only the chosen two afterwards).
func _prepare_passable(gateway_nodes: PackedInt32Array) -> void:
	_passable.resize(Raster.NODES)
	_passable.fill(0)
	_tables.clear()
	var gateways: Array = []
	for node: int in gateway_nodes:
		gateways.append(Raster.local_of(node))
	for k in range(Raster.NODES):
		if _raster.water[k] == 1 or _raster.blocked[k] == 1 or _raster.body[k] >= 0:
			continue
		var ok: bool = _raster.edge_dist[k] >= Anchors.EDGE_MARGIN_M
		if not ok:
			for g: Vector2 in gateways:
				ok = ok or Raster.local_of(k).distance_to(g) <= GATEWAY_PASSABLE_M
		_passable[k] = 1 if ok else 0


func _separation(distance: PackedFloat64Array) -> PackedFloat64Array:
	var sep := PackedFloat64Array()
	sep.resize(Raster.NODES)
	for k in range(Raster.NODES):
		sep[k] = 1.0 + SEPARATION_K * (1.0 - _smooth(0.0, SEPARATION_M, distance[k]))
	return sep


func _path_distance(extra: PackedInt32Array) -> PackedFloat64Array:
	var seeds := PackedByteArray()
	seeds.resize(Raster.NODES)
	for node: int in _node_routes:
		seeds[node] = 1
	for node: int in extra:
		seeds[node] = 1
	return Raster.chamfer(seeds)


static func _step_nodes(a: int, b: int) -> Array[int]:
	var n: int = Raster.N
	var d := Vector2i((b % n) - (a % n), (b / n) - (a / n))
	var result: Array[int] = []
	if Raster.DIRS.find(d) >= 0:
		for s: Vector2i in Raster.swept(a % n, a / n, d):
			result.append(s.y * n + s.x)
		return result
	var steps: int = maxi(absi(d.x), absi(d.y))
	for m in range(1, steps):
		result.append((a / n + d.y * m / steps) * n + a % n + d.x * m / steps)
	return result


func _bridges_on(path: PackedInt32Array, route_class: int) -> int:
	var count: int = 0
	for m in range(1, path.size()):
		var key: int = Raster.pair_key(path[m - 1], path[m])
		if _grid.move_crossings.has(key):
			for record: Dictionary in _grid.move_crossings[key].crossings:
				count += 1 if Search.crossing_hint(record) == Graph.Hint.BRIDGE else 0
	return count


func _crossing_count(path: PackedInt32Array) -> int:
	var count: int = 0
	for m in range(1, path.size()):
		var key: int = Raster.pair_key(path[m - 1], path[m])
		if _grid.move_crossings.has(key):
			count += _grid.move_crossings[key].crossings.size()
	return count


func _add_route(route: Dictionary) -> void:
	var index: int = _routes.size()
	# A route whose two ends attach to two different existing routes connects
	# separate parts of the network (cross-connection by function).
	var start_hosts: Array = _route_classes_at(route.path[0])
	var end_hosts: Array = _route_classes_at(route.path[route.path.size() - 1])
	var shared: bool = false
	for h: int in start_hosts:
		shared = shared or h in end_hosts
	route["connects"] = not start_hosts.is_empty() and not end_hosts.is_empty() and not shared
	for key: String in route.trial.removed:
		_pieces.erase(key)
	for key: String in route.trial.added:
		_pieces[key] = route.trial.added[key]
	route.erase("trial")
	_routes.append(route)
	var path: PackedInt32Array = route.path
	for m in range(path.size()):
		var node: int = path[m]
		if not _node_routes.has(node):
			_node_routes[node] = []
		_node_routes[node].append([index, m])
		_occupied[node] = 1
		if m > 0:
			var a: int = path[m - 1]
			for s: int in _step_nodes(a, node):
				if _occupied[s] == 0:
					_occupied[s] = 2
			var length: float = Scoring.move_length(a, node)
			if not _net_adj.has(a):
				_net_adj[a] = []
			if not _net_adj.has(node):
				_net_adj[node] = []
			_net_adj[a].append([node, length])
			_net_adj[node].append([a, length])
	_endpoints[path[0]] = true
	_endpoints[path[path.size() - 1]] = true
	_distance = _path_distance(PackedInt32Array())
	for a in range(_anchors.size()):
		var anchor: Dictionary = _anchors[a]
		if anchor.node >= 0 and _distance[anchor.node] <= Scoring.VISITED_M:
			_kinds_visited[anchor.kind] = true
	_total_length += Scoring.path_length(path)
	_bridges += _bridges_on(path, route.class)
	if route.purpose == Graph.Purpose.JUSTIFIED_SPUR:
		_spurs += 1
	_version += 1
	_along_cache.clear()


## Along-network distances from source nodes (Dijkstra over route paths).
func _along(sources: PackedInt32Array, limit: float) -> Dictionary:
	var cache_key: String = str(sources) + ":" + str(limit)
	if _along_cache.has(cache_key):
		return _along_cache[cache_key]
	var dist: Dictionary = {}
	var heap = Search._Heap.new()
	for s: int in sources:
		dist[s] = 0.0
		heap.push(0.0, s)
	while not heap.is_empty():
		var k: int = heap.pop()
		var key: float = heap.popped_key
		if key > dist.get(k, INF) or key > limit:
			continue
		for pair: Array in _net_adj.get(k, []):
			var nd: float = key + pair[1]
			if nd < dist.get(pair[0], INF):
				dist[pair[0]] = nd
				heap.push(nd, pair[0])
	_along_cache[cache_key] = dist
	return dist


func _degree(node: int) -> int:
	var d: int = 0
	for entry: Array in _node_routes.get(node, []):
		var path: PackedInt32Array = _routes[entry[0]].path
		d += 1 if entry[1] == 0 or entry[1] == path.size() - 1 else 2
	return d


## Attach mask for a class: route nodes the class may rely on (semantic
## hierarchy), >= ATTACH_SPACING_M along-network from every junction/endpoint
## or an existing junction of degree 3.
func _targets(route_class: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(Raster.NODES)
	var endpoints := PackedInt32Array(_endpoints.keys())
	endpoints.sort()
	var near: Dictionary = _along(endpoints, ATTACH_SPACING_M)
	var allowed: Array = Graph.RELIES_ON[route_class].duplicate()
	# Technical lines are options on an easier network: they never hang off
	# other technical lines (the network must stay connected without them).
	allowed.erase(Graph.RouteClass.TECHNICAL)
	for node: int in _node_routes:
		var host_ok: bool = false
		for entry: Array in _node_routes[node]:
			host_ok = host_ok or _routes[entry[0]].class in allowed
		if not host_ok:
			continue
		if _endpoints.has(node):
			mask[node] = 1 if _degree(node) == 3 else 0
		elif near.get(node, INF) >= ATTACH_SPACING_M:
			mask[node] = 1
	return mask


func _closed(targets: PackedByteArray, extra: PackedInt32Array) -> PackedByteArray:
	var closed := PackedByteArray()
	closed.resize(Raster.NODES)
	for k in range(Raster.NODES):
		closed[k] = 1 if _occupied[k] != 0 and targets[k] == 0 else 0
	for k: int in extra:
		closed[k] = 1
	return closed


func _search(route_class: int, sep: PackedFloat64Array, sources: PackedInt32Array, targets: PackedByteArray, goal: int, closed: PackedByteArray, max_cost: float = MAX_SEARCH_COST) -> Dictionary:
	var result: Dictionary = Search.search(_grid, _tables_for(route_class), sep, sources, targets, goal, closed, max_cost)
	_metrics.searches += 1
	_metrics.expanded += result.expanded
	return result


static func _point_on_path(path: PackedInt32Array, distance_m: float) -> Vector2:
	var remaining: float = distance_m
	for m in range(1, path.size()):
		var a: Vector2 = Raster.local_of(path[m - 1])
		var b: Vector2 = Raster.local_of(path[m])
		var l: float = a.distance_to(b)
		if l >= remaining:
			return a.lerp(b, remaining / l)
		remaining -= l
	return Raster.local_of(path[path.size() - 1])


## Junction legibility at an attach node for a new path leaving it.
func _angle_ok(node: int, leaving: PackedInt32Array) -> bool:
	var origin: Vector2 = Raster.local_of(node)
	var direction: Vector2 = (_point_on_path(leaving, Graph.JUNCTION_ZONE_M) - origin).normalized()
	for entry: Array in _node_routes.get(node, []):
		var path: PackedInt32Array = _routes[entry[0]].path
		var m: int = entry[1]
		if m < path.size() - 1:
			if Graph.angle_between_deg(direction, (_point_on_path(path.slice(m), Graph.JUNCTION_ZONE_M) - origin).normalized()) < Graph.JUNCTION_ANGLE_DEG:
				return false
		if m > 0:
			var back: PackedInt32Array = path.slice(0, m + 1)
			back.reverse()
			if Graph.angle_between_deg(direction, (_point_on_path(back, Graph.JUNCTION_ZONE_M) - origin).normalized()) < Graph.JUNCTION_ANGLE_DEG:
				return false
	return true


## Shortest along-network node path between two network nodes.
func _network_path(a: int, b: int) -> PackedInt32Array:
	var dist: Dictionary = {a: 0.0}
	var parent: Dictionary = {}
	var heap = Search._Heap.new()
	heap.push(0.0, a)
	while not heap.is_empty():
		var k: int = heap.pop()
		var key: float = heap.popped_key
		if key > dist.get(k, INF):
			continue
		if k == b:
			break
		for pair: Array in _net_adj.get(k, []):
			var nd: float = key + pair[1]
			if nd < dist.get(pair[0], INF):
				dist[pair[0]] = nd
				parent[pair[0]] = k
				heap.push(nd, pair[0])
	var path := PackedInt32Array()
	if not dist.has(b):
		return path
	var at: int = b
	while at != a:
		path.append(at)
		at = parent[at]
	path.append(a)
	path.reverse()
	return path


# --- Candidates ---

func _candidate(key: String, route_class: int, purpose: int) -> Dictionary:
	_metrics.candidates += 1
	return {"key": key, "class": route_class, "purpose": purpose, "valid": false, "reject": "", "path": PackedInt32Array(), "reference": PackedInt32Array(),
		"start_kind": Graph.NodeKind.JUNCTION, "end_kind": Graph.NodeKind.JUNCTION, "terminus_anchor": -1, "jvs": -INF, "eval": {}, "version": _version, "closed": PackedInt32Array(), "anchor": -1, "pair": PackedInt32Array()}


func _loop_candidate(anchor_index: int, route_class: int, closed_extra: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var anchor: Dictionary = _anchors[anchor_index]
	var c: Dictionary = _candidate("loop:%d:%s" % [anchor_index, Graph.CLASS_NAMES[route_class]], route_class, Graph.Purpose.LOOP_ALTERNATIVE)
	c.anchor = anchor_index
	c.closed = closed_extra
	var src: int = anchor.node
	if _distance[src] <= Scoring.VISITED_M or _occupied[src] != 0 or _passable[src] == 0:
		c.reject = "ANCHOR_VISITED"
		return c
	var targets: PackedByteArray = _targets(route_class)
	var sep: PackedFloat64Array = _separation(_distance)
	var first: Dictionary = _search(route_class, sep, PackedInt32Array([src]), targets, -1, _closed(targets, closed_extra))
	if not first.found:
		c.reject = "REJECT_NO_ATTACH"
		return c
	var p1: PackedInt32Array = first.path
	var t1: int = p1[p1.size() - 1]
	var near_t1: Dictionary = _along(PackedInt32Array([t1]), LOOP_ATTACH_M)
	var targets2: PackedByteArray = targets.duplicate()
	for node: int in near_t1:
		if near_t1[node] < LOOP_ATTACH_M:
			targets2[node] = 0
	var blocked2: PackedInt32Array = closed_extra.duplicate()
	blocked2.append_array(p1.slice(1))
	var distance2: PackedFloat64Array = _path_distance(p1)
	var second: Dictionary = _search(route_class, _separation(distance2), PackedInt32Array([src]), targets2, -1, _closed(targets2, blocked2))
	var reversed: PackedInt32Array = p1.duplicate()
	reversed.reverse()
	var cost1: float = Search.path_cost(_grid, _tables_for(route_class), p1)
	if second.found and Search.path_cost(_grid, _tables_for(route_class), second.path) <= SECOND_ATTACH_RATIO * cost1 + 2000.0:
		var p2: PackedInt32Array = second.path
		# Loop branches must not collapse onto each other (out-and-back).
		var own := PackedByteArray()
		own.resize(Raster.NODES)
		for node: int in p1:
			own[node] = 1
		if Scoring.near_share(p2, Raster.chamfer(own), Scoring.DUPLICATE_DISTANCE_M) > Scoring.DUPLICATE_FRACTION:
			c.reject = "REJECT_DUPLICATE"
			c.path = reversed + p2.slice(1)
			return c
		c.path = reversed + p2.slice(1)
		c.reference = _network_path(t1, p2[p2.size() - 1])
	elif SPUR_KINDS.has(anchor.kind) and route_class != Graph.RouteClass.TECHNICAL:
		c.purpose = Graph.Purpose.JUSTIFIED_SPUR
		c.path = reversed
		c.end_kind = Graph.NodeKind.TERMINUS
		c.terminus_anchor = anchor_index
	else:
		c.reject = "REJECT_NO_SECOND_ATTACH"
		c.path = reversed
		return c
	return _finish(c)


func _pair_candidate(u: int, w: int, route_class: int, purpose: int, closed_extra: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var c: Dictionary = _candidate("pair:%d-%d:%s:%s" % [u, w, Graph.CLASS_NAMES[route_class], Graph.PURPOSE_NAMES[purpose]], route_class, purpose)
	c.pair = PackedInt32Array([u, w])
	c.closed = closed_extra
	var targets: PackedByteArray = _targets(route_class)
	if targets[u] == 0 or targets[w] == 0:
		c.reject = "REJECT_JUNCTION_SPACING"
		return c
	var only_w := PackedByteArray()
	only_w.resize(Raster.NODES)
	only_w[w] = 1
	var result: Dictionary = _search(route_class, _separation(_distance), PackedInt32Array([u]), only_w, w, _closed(only_w, closed_extra))
	if not result.found:
		c.reject = "REJECT_NO_ATTACH"
		return c
	c.path = result.path
	c.reference = _network_path(u, w)
	var along: float = Scoring.path_length(c.reference)
	if Scoring.path_length(c.path) > 0.75 * along:
		c.reject = "REJECT_DETOUR"
		return c
	return _finish(c)


## Cross-connection from a station on a non-backbone route: bounded search to
## the nearest attachable node of a *different* route that is far away along
## the network (the connector ends where geography first allows).
func _connector_candidate(u: int, route_class: int, closed_extra: PackedInt32Array = PackedInt32Array()) -> Dictionary:
	var c: Dictionary = _candidate("connector:%d:%s" % [u, Graph.CLASS_NAMES[route_class]], route_class, Graph.Purpose.CROSS_CONNECTION)
	c.pair = PackedInt32Array([u, -1])
	c.closed = closed_extra
	var targets: PackedByteArray = _targets(route_class)
	if targets[u] == 0:
		c.reject = "REJECT_JUNCTION_SPACING"
		return c
	var own: Array = _route_classes_at(u)
	var along: Dictionary = _along(PackedInt32Array([u]), CONNECTOR_ALONG_M)
	var far := PackedByteArray()
	far.resize(Raster.NODES)
	for node: int in _node_routes:
		if targets[node] == 0 or along.get(node, INF) < CONNECTOR_ALONG_M:
			continue
		var other: bool = true
		for entry: Array in _node_routes[node]:
			other = other and not entry[0] in own
		far[node] = 1 if other else 0
	# A connector starts and ends on routes: no separation multiplier (it would
	# only tax both ends); duplicate screening still rejects parallel geometry.
	var flat := PackedFloat64Array()
	flat.resize(Raster.NODES)
	flat.fill(1.0)
	var result: Dictionary = _search(route_class, flat, PackedInt32Array([u]), far, -1, _closed(far, closed_extra), CONNECTOR_COST)
	if not result.found:
		c.reject = "REJECT_NO_ATTACH"
		return c
	c.path = result.path
	var w: int = c.path[c.path.size() - 1]
	c.pair[1] = w
	c.reference = _network_path(u, w)
	if Scoring.path_length(c.path) > 0.6 * Scoring.path_length(c.reference):
		c.reject = "REJECT_DETOUR"
		return c
	return _finish(c)


## Hard rejects and JVS for a generated path.
func _finish(c: Dictionary) -> Dictionary:
	var path: PackedInt32Array = c.path
	var length: float = Scoring.path_length(path)
	if _duplicates(path):
		c.reject = "REJECT_DUPLICATE"
		return c
	if c.purpose != Graph.Purpose.JUSTIFIED_SPUR and length + Scoring.path_length(c.reference) < Graph.MIN_LOOP_CYCLE_M:
		c.reject = "REJECT_LOOP_TOO_SHORT"
		return c
	if length < 250.0:
		c.reject = "REJECT_LOW_VALUE"
		return c
	# A technical line must actually be steep (mean |grade| >= 0.10).
	if c.class == Graph.RouteClass.TECHNICAL:
		var vertical: float = 0.0
		for m in range(1, path.size()):
			vertical += absf(_raster.height[path[m]] - _raster.height[path[m - 1]])
		if vertical / length < 0.10:
			c.reject = "REJECT_NOT_TECHNICAL"
			return c
	if not _angle_ok(path[0], path):
		c.reject = "REJECT_JUNCTION_ANGLE"
		return c
	if c.end_kind == Graph.NodeKind.JUNCTION:
		var back: PackedInt32Array = path.duplicate()
		back.reverse()
		if not _angle_ok(back[0], back):
			c.reject = "REJECT_JUNCTION_ANGLE"
			return c
	if _total_length + length > NETWORK_CAP_M or _bridges + _bridges_on(path, c.class) > BRIDGE_BUDGET:
		c.reject = "REJECT_BUDGET"
		return c
	if c.purpose == Graph.Purpose.JUSTIFIED_SPUR and _spurs >= MAX_SPURS:
		c.reject = "REJECT_BUDGET"
		return c
	if length > MAX_ROUTE_M[c.class]:
		c.reject = "REJECT_TOO_LONG"
		return c
	if c.purpose == Graph.Purpose.JUSTIFIED_SPUR and length > MAX_SPUR_M:
		c.reject = "REJECT_UNJUSTIFIED_SPUR"
		return c
	var cost: float = Search.path_cost(_grid, _tables_for(c.class), path, false)
	var evaluation: Dictionary = Scoring.evaluate(path, {"raster": _raster, "anchors": _anchors, "network_distance": _distance, "kinds_visited": _kinds_visited,
		"reference": c.reference, "route_class": c.class, "cost": cost, "relief_m": _relief_m, "crossings": _crossing_count(path)})
	c.eval = evaluation
	c.jvs = evaluation.jvs * (SPUR_SCALE if c.purpose == Graph.Purpose.JUSTIFIED_SPUR else 1.0)
	c.valid = true
	c.version = _version
	return c


## Duplicate geometry screening per future edge, in both directions: the
## candidate against the network, and every existing edge piece (split at
## current endpoints and at the candidate's attach nodes) against the
## candidate. Mirrors the validator's per-edge rule conservatively.
func _duplicates(path: PackedInt32Array) -> bool:
	if Scoring.near_share(path, _distance, Scoring.SCREEN_DISTANCE_M, Graph.JUNCTION_ZONE_M) > Scoring.DUPLICATE_FRACTION:
		return true
	var own := PackedByteArray()
	own.resize(Raster.NODES)
	for node: int in path:
		own[node] = 1
	var near_candidate: PackedFloat64Array = Raster.chamfer(own)
	var splits: Dictionary = _endpoints.duplicate()
	splits[path[0]] = true
	splits[path[path.size() - 1]] = true
	for route: Dictionary in _routes:
		var host: PackedInt32Array = route.path
		var start: int = 0
		for m in range(1, host.size()):
			if splits.has(host[m]) or m == host.size() - 1:
				var piece: PackedInt32Array = host.slice(start, m + 1)
				if piece.size() >= 2 and Scoring.near_share(piece, near_candidate, Scoring.SCREEN_DISTANCE_M, Graph.JUNCTION_ZONE_M) > Scoring.DUPLICATE_FRACTION:
					return true
				start = m
	return false


func _regenerate(c: Dictionary) -> Dictionary:
	_metrics.regenerations += 1
	if c.anchor >= 0:
		return _loop_candidate(c.anchor, c.class, c.closed)
	if c.purpose == Graph.Purpose.CROSS_CONNECTION:
		return _connector_candidate(c.pair[0], c.class, c.closed)
	return _pair_candidate(c.pair[0], c.pair[1], c.class, c.purpose, c.closed)


func _station_nodes(route_filter: Callable) -> PackedInt32Array:
	var result := PackedInt32Array()
	for r in range(_routes.size()):
		if not route_filter.call(_routes[r]):
			continue
		var path: PackedInt32Array = _routes[r].path
		for m in range(3, path.size() - 3, 6):
			if not path[m] in result:
				result.append(path[m])
	return result


## Evenly spread stations on non-backbone, non-technical routes with the
## connector class of their route (hierarchy: never easier than its host).
func _connector_stations() -> Array:
	var stations: Array = []
	for r in range(1, _routes.size()):
		var route: Dictionary = _routes[r]
		if route.class == Graph.RouteClass.TECHNICAL:
			continue
		for m in range(4, route.path.size() - 4, 6):
			stations.append([route.path[m], route.class])
	if stations.size() <= CONNECTOR_STATIONS:
		return stations
	var picked: Array = []
	for k in range(CONNECTOR_STATIONS):
		picked.append(stations[k * stations.size() / CONNECTOR_STATIONS])
	return picked


func _harder(a: int, b: int) -> int:
	return a if b in Graph.RELIES_ON[a] else b


func _route_classes_at(node: int) -> Array:  # route indices hosting the node
	var result: Array = []
	for entry: Array in _node_routes.get(node, []):
		result.append(entry[0])
	return result


func _pair_candidates(mode: String, route_class: int) -> Array:
	var stations: PackedInt32Array
	stations = _station_nodes(func(_route: Dictionary) -> bool: return true)
	# Only attachable stations (semantic hierarchy, junction spacing) pair.
	var attach: Dictionary = {}
	for cls: int in [Graph.RouteClass.SECONDARY, Graph.RouteClass.SINGLETRACK, Graph.RouteClass.TECHNICAL]:
		attach[cls] = _targets(cls)
	var ranked: Array = []
	for x in range(stations.size()):
		var u: int = stations[x]
		var along: Dictionary = _along(PackedInt32Array([u]), 6000.0)
		for y in range(x + 1, stations.size()):
			var w: int = stations[y]
			var e: float = Scoring.move_length(u, w)
			var a: float = along.get(w, INF)
			var dh: float = absf(_raster.height[u] - _raster.height[w])
			var score: float = -1.0
			var cls: int = route_class
			var purpose: int = Graph.Purpose.SHORTCUT
			match mode:
				"shortcut":
					if e >= 300.0 and e <= 1500.0 and a >= 1.8 * e and dh >= 40.0:
						score = a / e * dh
				"technical":
					if e >= 200.0 and e <= 1200.0 and a >= 1.5 * e and dh >= 60.0 and dh / e >= 0.10:
						score = dh / e * a / e
			if score > 0.0 and cls != Graph.RouteClass.BACKBONE and attach[cls][u] == 1 and attach[cls][w] == 1:
				ranked.append([score, u, w, cls, purpose])
	ranked.sort_custom(func(p: Array, q: Array) -> bool: return p[0] > q[0] or (p[0] == q[0] and (p[1] < q[1] or (p[1] == q[1] and p[2] < q[2]))))
	return ranked.slice(0, 12)


func _reject(c: Dictionary, round_name: String) -> void:
	if _rejected.size() >= MAX_REJECTED or c.path.is_empty():
		return
	var line := PackedInt32Array()
	for m in range(0, c.path.size(), 3):
		var p: Vector2 = Raster.local_of(c.path[m])
		line.append_array([roundi(p.x * 100.0), roundi(p.y * 100.0)])
	var p_last: Vector2 = Raster.local_of(c.path[c.path.size() - 1])
	line.append_array([roundi(p_last.x * 100.0), roundi(p_last.y * 100.0)])
	_rejected.append({"round": round_name, "key": c.key, "class": c.class, "purpose": c.purpose, "anchor": c.anchor, "reason_code": c.reject, "jvs_milli": roundi(c.jvs * 1000.0) if c.jvs > -INF else 0, "line_cm": line})


## Piece index ranges [i0, i1] of a node path split at `splits` nodes.
static func _split(path: PackedInt32Array, splits: Dictionary) -> Array:
	var ranges: Array = []
	var start: int = 0
	for m in range(1, path.size()):
		if splits.has(path[m]) or m == path.size() - 1:
			ranges.append([start, m])
			start = m
	return ranges


## Final node kind of a network node given the route being tried.
func _kind_of(node: int, c: Dictionary) -> int:
	var backbone: PackedInt32Array = _routes[0].path if not _routes.is_empty() else c.path
	if node == backbone[0] or node == backbone[backbone.size() - 1]:
		return Graph.NodeKind.GATEWAY
	if c.end_kind == Graph.NodeKind.TERMINUS and node == c.path[c.path.size() - 1]:
		return Graph.NodeKind.TERMINUS
	for route: Dictionary in _routes:
		if route.end_kind == Graph.NodeKind.TERMINUS and node == route.path[route.path.size() - 1]:
			return Graph.NodeKind.TERMINUS
	return Graph.NodeKind.JUNCTION


func _build_piece(path: PackedInt32Array, route_class: int, range_: Array, c: Dictionary) -> Dictionary:
	var built: Dictionary = _builder.build(path.slice(range_[0], range_[1] + 1), route_class, _kind_of(path[range_[0]], c) == Graph.NodeKind.JUNCTION, _kind_of(path[range_[1]], c) == Graph.NodeKind.JUNCTION)
	built["ends"] = PackedInt32Array([path[range_[0]], path[range_[1]]])
	return built


## Trial split (acceptance-time equivalent of final assembly): builds and
## certifies the candidate and every host piece its attach points create, then
## applies the validator's duplicate rule on station lines against all current
## pieces. Returns "" (pieces kept in c.trial), "REPLAN" (candidate defect
## nodes closed) or a reject code.
func _trial(c: Dictionary) -> String:
	var index: int = _routes.size()
	var splits: Dictionary = _endpoints.duplicate()
	splits[c.path[0]] = true
	splits[c.path[c.path.size() - 1]] = true
	var added: Dictionary = {}
	var removed: Array = []
	for range_: Array in _split(c.path, splits):
		var built: Dictionary = _build_piece(c.path, c.class, range_, c)
		if built.pinch_reject:
			return "REJECT_UNCERTIFIED_BARRIER"
		if not built.defects.is_empty():
			var closed: PackedInt32Array = c.closed.duplicate()
			for node: int in built.defects:
				if node != c.path[0] and node != c.path[c.path.size() - 1] and not node in closed:
					closed.append(node)
			if closed.size() == c.closed.size():
				return "REJECT_UNCERTIFIED_BARRIER"
			c.closed = closed
			return "REPLAN"
		added["%d:%d:%d" % [index, range_[0], range_[1]]] = built
	for r in range(_routes.size()):
		var path: PackedInt32Array = _routes[r].path
		var before: Array = _split(path, _endpoints)
		var after: Array = _split(path, splits)
		if before == after:
			continue
		for range_: Array in before:
			if not range_ in after:
				removed.append("%d:%d:%d" % [r, range_[0], range_[1]])
		for range_: Array in after:
			if range_ in before:
				continue
			var built: Dictionary = _build_piece(path, _routes[r].class, range_, c)
			if built.pinch_reject or not built.defects.is_empty():
				return "REJECT_UNCERTIFIED_BARRIER"
			added["%d:%d:%d" % [r, range_[0], range_[1]]] = built
	# Junction legibility on the final station lines (validator rule): angles
	# at every junction end of a newly built piece (its line may have changed);
	# junction-to-junction pieces >= 200 m.
	var pieces: Array = []
	for key: String in _pieces:
		if not key in removed:
			pieces.append(_pieces[key])
	for key: String in added:
		pieces.append(added[key])
		var ends: PackedInt32Array = added[key].ends
		if _kind_of(ends[0], c) == Graph.NodeKind.JUNCTION and _kind_of(ends[1], c) == Graph.NodeKind.JUNCTION and added[key].length_cm < Graph.JUNCTION_SPACING_M * 100.0:
			return "REJECT_JUNCTION_SPACING"
	var junctions: Dictionary = {}
	for key: String in added:
		for node: int in added[key].ends:
			if _kind_of(node, c) == Graph.NodeKind.JUNCTION:
				junctions[node] = true
	var ordered: Array = junctions.keys()
	ordered.sort()
	for node: int in ordered:
		var origin: Vector2 = Raster.local_of(node) * 100.0
		var directions: Array = []
		for piece: Dictionary in pieces:
			if piece.ends[0] != node and piece.ends[1] != node:
				continue
			var tip: Vector2 = Graph.point_along(piece.corridor.x_cm, piece.corridor.z_cm, Graph.JUNCTION_ZONE_M * 100.0, piece.ends[1] == node and piece.ends[0] != node)
			directions.append((tip - origin).normalized())
		for i in range(directions.size()):
			for j in range(i + 1, directions.size()):
				if Graph.angle_between_deg(directions[i], directions[j]) < Graph.JUNCTION_ANGLE_DEG:
					return "REJECT_JUNCTION_ANGLE"
	var lines: Array = []
	var fresh: Array = []
	for key: String in _pieces:
		if not key in removed:
			lines.append([_pieces[key].corridor.x_cm, _pieces[key].corridor.z_cm])
	var first_fresh: int = lines.size()
	for key: String in added:
		lines.append([added[key].corridor.x_cm, added[key].corridor.z_cm])
		fresh.append(lines[lines.size() - 1])
	for i in range(lines.size()):
		var is_fresh: bool = i >= first_fresh
		var shares: PackedFloat64Array = Graph.line_duplicate_shares(lines[i][0], lines[i][1], lines if is_fresh else fresh, i if is_fresh else -1)
		for share: float in shares:
			if share > Graph.DUPLICATE_FRACTION:
				return "REJECT_DUPLICATE"
	c["trial"] = {"added": added, "removed": removed}
	return ""


func _run_round(round_index: int, config: Dictionary) -> Dictionary:
	var candidates: Array = []
	var route_class: int = config.class
	if not config.kinds.is_empty():
		for a in range(_anchors.size()):
			if _anchors[a].node >= 0 and _anchors[a].kind in config.kinds:
				candidates.append(_loop_candidate(a, route_class))
	if config.pairs == "cross":
		for station: Array in _connector_stations():
			candidates.append(_connector_candidate(station[0], station[1]))
	elif not config.pairs.is_empty():
		for pair: Array in _pair_candidates(config.pairs, route_class):
			candidates.append(_pair_candidate(pair[1], pair[2], pair[3], pair[4]))
	var generated: int = candidates.size()
	var accepted: int = 0
	var replans: Dictionary = {}
	while accepted < config.max:
		var pool: Array = []
		for c: Dictionary in candidates:
			if c.valid and c.jvs >= config.floor:
				pool.append(c)
		if pool.is_empty():
			break
		pool.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.jvs > q.jvs or (p.jvs == q.jvs and p.key < q.key))
		var stale: bool = false
		for c: Dictionary in pool:
			if c.jvs < (1.0 - TIE_CANDIDATE) * pool[0].jvs:
				break
			if c.version != _version:
				candidates[candidates.find(c)] = _regenerate(c)
				stale = true
		if stale:
			continue
		var group: Array = []
		for c: Dictionary in pool:
			if c.jvs >= (1.0 - TIE_CANDIDATE) * pool[0].jvs:
				group.append(c)
		group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return tie_value(_route_seed, round_index, p.key) > tie_value(_route_seed, round_index, q.key) or (tie_value(_route_seed, round_index, p.key) == tie_value(_route_seed, round_index, q.key) and p.key < q.key))
		var chosen: Dictionary = group[0]
		var index: int = candidates.find(chosen)
		var verdict: String = _trial(chosen)
		if verdict == "REPLAN" and replans.get(chosen.key, 0) < 2:
			replans[chosen.key] = replans.get(chosen.key, 0) + 1
			_metrics.replans += 1
			candidates[index] = _regenerate(chosen)
			continue
		if not verdict.is_empty():
			chosen.valid = false
			chosen.reject = verdict if verdict != "REPLAN" else "REJECT_UNCERTIFIED_BARRIER"
			_metrics.trial_rejects += 1
			continue
		_add_route({"class": chosen.class, "purpose": chosen.purpose, "path": chosen.path, "reference": chosen.reference, "start_kind": Graph.NodeKind.JUNCTION,
			"end_kind": chosen.end_kind, "terminus_anchor": chosen.terminus_anchor, "jvs": chosen.jvs, "eval": chosen.eval, "key": chosen.key, "round": config.name, "trial": chosen.trial})
		candidates.remove_at(index)
		accepted += 1
	var histogram: Dictionary = {}
	for c: Dictionary in candidates:
		if c.valid and c.jvs < config.floor:
			c.reject = "REJECT_LOW_VALUE"
		elif c.valid and c.reject.is_empty():
			c.reject = "NOT_SELECTED"
		histogram[c.reject] = histogram.get(c.reject, 0) + 1
		if c.reject != "ANCHOR_VISITED":
			_reject(c, config.name)
	var summary := {"round": config.name, "generated": generated, "accepted": accepted, "target": config.min, "max": config.max, "outcomes": histogram}
	_rounds_log.append(summary)
	return summary


func _backbone() -> String:
	var ups: Array = []
	var downs: Array = []
	for anchor: Dictionary in _anchors:
		if anchor.kind == Graph.AnchorKind.GATEWAY and anchor.node >= 0:
			(ups if ".upstream." in anchor.source else downs).append(anchor)
	if ups.is_empty() or downs.is_empty():
		return "ERR_ROUTE_NO_GATEWAY"
	var none := PackedByteArray()
	none.resize(Raster.NODES)
	var flat := PackedFloat64Array()
	flat.resize(Raster.NODES)
	flat.fill(1.0)
	var options: Array = []
	for up: Dictionary in ups:
		for down: Dictionary in downs:
			var result: Dictionary = _search(Graph.RouteClass.BACKBONE, flat, PackedInt32Array([up.node]), none, down.node, none)
			_backbone_options.append({"from": up.source, "to": down.source, "found": result.found, "cost": result.cost if result.found else -1.0, "length_m": Scoring.path_length(result.path) if result.found else 0.0, "bridges": _bridges_on(result.path, Graph.RouteClass.BACKBONE) if result.found else 0})
			if result.found:
				options.append({"key": up.source + ">" + down.source, "path": result.path, "cost": result.cost})
	if options.is_empty():
		return "ERR_ROUTE_NO_BACKBONE"
	options.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.cost < q.cost or (p.cost == q.cost and p.key < q.key))
	var group: Array = []
	for option: Dictionary in options:
		if option.cost <= (1.0 + TIE_BACKBONE) * options[0].cost:
			group.append(option)
	group.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return tie_value(_route_seed, 0, p.key) > tie_value(_route_seed, 0, q.key) or (tie_value(_route_seed, 0, p.key) == tie_value(_route_seed, 0, q.key) and p.key < q.key))
	var chosen: Dictionary = group[0]
	var trial := {"path": chosen.path, "class": Graph.RouteClass.BACKBONE, "end_kind": Graph.NodeKind.GATEWAY, "closed": PackedInt32Array()}
	var verdict: String = _trial(trial)
	var attempts: int = 0
	while verdict == "REPLAN" and attempts < 3:
		attempts += 1
		_metrics.replans += 1
		var closed := PackedByteArray()
		closed.resize(Raster.NODES)
		for node: int in trial.closed:
			closed[node] = 1
		var again: Dictionary = _search(Graph.RouteClass.BACKBONE, flat, PackedInt32Array([chosen.path[0]]), none, chosen.path[chosen.path.size() - 1], closed)
		if not again.found:
			break
		trial.path = again.path
		verdict = _trial(trial)
	if not verdict.is_empty():
		return "ERR_ROUTE_NO_BACKBONE"
	_add_route({"class": Graph.RouteClass.BACKBONE, "purpose": Graph.Purpose.BACKBONE, "path": trial.path, "reference": PackedInt32Array(), "start_kind": Graph.NodeKind.GATEWAY,
		"end_kind": Graph.NodeKind.GATEWAY, "terminus_anchor": -1, "jvs": 0.0, "eval": {"chosen": chosen.key, "near_equal_options": group.size(), "certification_replans": attempts}, "key": "backbone:" + chosen.key, "round": "backbone", "trial": trial.trial})
	return ""


func _run() -> Dictionary:
	_occupied.resize(Raster.NODES)
	_distance.resize(Raster.NODES)
	_distance.fill(INF)
	var gateway_nodes := PackedInt32Array()
	for anchor: Dictionary in _anchors:
		if anchor.kind == Graph.AnchorKind.GATEWAY and anchor.node >= 0:
			gateway_nodes.append(anchor.node)
	_prepare_passable(gateway_nodes)
	var backbone: String = _backbone()
	if not backbone.is_empty():
		return _failure(backbone)
	var backbone_path: PackedInt32Array = _routes[0].path
	_prepare_passable(PackedInt32Array([backbone_path[0], backbone_path[backbone_path.size() - 1]]))
	for r in range(ROUNDS.size()):
		_run_round(r + 1, ROUNDS[r])
	return _assemble()


# --- Assembly ---

func _assemble() -> Dictionary:
	var node_ids: Dictionary = {}
	var nodes: Array = []
	var special: Dictionary = {}
	for route: Dictionary in _routes:
		special[route.path[0]] = true
		special[route.path[route.path.size() - 1]] = true
	for r in range(_routes.size()):
		var route: Dictionary = _routes[r]
		for m in range(route.path.size()):
			var k: int = route.path[m]
			if not special.has(k) or node_ids.has(k):
				continue
			node_ids[k] = nodes.size()
			var p: Vector2 = Raster.local_of(k)
			var kind: int = Graph.NodeKind.JUNCTION
			var justification: int = Graph.Justification.NONE
			var anchor_id: int = -1
			if r == 0 and (m == 0 or m == route.path.size() - 1):
				kind = Graph.NodeKind.GATEWAY
				justification = Graph.Justification.REGION_GATEWAY
				for a in range(_anchors.size()):
					if _anchors[a].kind == Graph.AnchorKind.GATEWAY and _anchors[a].node == k:
						anchor_id = a
			elif route.end_kind == Graph.NodeKind.TERMINUS and m == route.path.size() - 1:
				kind = Graph.NodeKind.TERMINUS
				anchor_id = route.terminus_anchor
				justification = SPUR_KINDS[_anchors[anchor_id].kind]
			nodes.append({"id": nodes.size(), "kind": kind, "x_cm": roundi(p.x * 100.0), "z_cm": roundi(p.y * 100.0), "elevation_cm": roundi(_raster.height[k] * 100.0), "anchor_id": anchor_id, "justification": justification})
	var edges: Array = []
	var routes: Array = []
	var used: Dictionary = {}
	var defects: int = 0
	var missing_pieces: int = 0
	for r in range(_routes.size()):
		var route: Dictionary = _routes[r]
		var path: PackedInt32Array = route.path
		var edge_ids := PackedInt32Array()
		var route_reasons: int = 0
		var route_anchors := PackedInt32Array()
		for range_: Array in _split(path, special):
			var a: int = node_ids[path[range_[0]]]
			var b: int = node_ids[path[range_[1]]]
			var key: String = "%d:%d:%d" % [r, range_[0], range_[1]]
			# Certified at acceptance (trial split); a missing piece is a defect.
			if not _pieces.has(key):
				missing_pieces += 1
				continue
			var built: Dictionary = _pieces[key]
			defects += built.defects.size() + (1 if built.pinch_reject else 0)
			var passed := PackedInt32Array()
			var kinds: Array = []
			for an in range(_anchors.size()):
				var anchor: Dictionary = _anchors[an]
				if anchor.node < 0:
					continue
				var q := Vector2(anchor.x_cm, anchor.z_cm) / 100.0
				for s in range(built.line.size()):
					if built.line[s].distance_to(q) <= Scoring.ANCHOR_REACH_M:
						passed.append_array([an, s])
						kinds.append(anchor.kind)
						used[an] = true
						if not an in route_anchors:
							route_anchors.append(an)
						break
			var contrast_value: float = route.eval.get("contrast_value", 0.0)
			var reasons: int = Scoring.edge_reasons(built.signals, kinds, built.crossings, route.purpose, contrast_value)
			if route.get("connects", false):
				reasons |= Graph.Reason.CONNECTS_LOOPS
			route_reasons |= reasons
			edge_ids.append(edges.size())
			edges.append({"id": edges.size(), "a": a, "b": b, "route_id": r, "class": route.class, "length_cm": built.length_cm, "climb_cm": built.climb_cm, "descent_cm": built.descent_cm,
				"reasons": reasons, "crossings": built.crossings.duplicate(true), "anchors_passed": passed, "corridor": built.corridor.duplicate(true)})
		if route.terminus_anchor >= 0:
			used[route.terminus_anchor] = true
			if not route.terminus_anchor in route_anchors:
				route_anchors.append(route.terminus_anchor)
		routes.append({"id": r, "class": route.class, "purpose": route.purpose, "edge_ids": edge_ids, "start_node": node_ids[path[0]], "end_node": node_ids[path[path.size() - 1]],
			"anchor_ids": route_anchors, "score_milli": roundi(route.jvs * 1000.0), "reasons": route_reasons})
	var loops: Array = _loops(routes, edges, nodes)
	var anchors: Array = []
	for a in range(_anchors.size()):
		var anchor: Dictionary = _anchors[a]
		var status: int = anchor.status
		if status != Graph.AnchorStatus.REJECTED:
			status = Graph.AnchorStatus.USED if used.has(a) else Graph.AnchorStatus.UNUSED
		anchors.append({"id": a, "kind": anchor.kind, "x_cm": anchor.x_cm, "z_cm": anchor.z_cm, "elevation_cm": anchor.elevation_cm, "status": status, "source": anchor.source, "reason_code": anchor.reason_code})
	var bounds: Dictionary = _rideability.get_bounds_m()
	var data := {"region_signature": _region_plan.signature(), "hydrology_signature": _hydrology_plan.signature(), "rideability_signature": _rideability.signature(),
		"model": Search.MODEL + "|" + Anchors.MODEL + "|" + Scoring.MODEL + "|" + Builder.MODEL + "|" + MODEL, "route_seed": _route_seed,
		"origin_x_m": bounds.min_x, "origin_z_m": bounds.min_z, "frame_symmetry": _symmetry, "planning_spacing_m": int(Raster.SPACING_M),
		"nodes": nodes, "edges": edges, "routes": routes, "loops": loops, "anchors": anchors}
	var composition: Dictionary = _composition(routes, loops, anchors)
	var diagnostics := {"degrade_codes": composition.degrade_codes, "composition": composition.counts, "rounds": _rounds_log, "rejected": _rejected, "backbone_options": _backbone_options,
		"explanations": _explain(), "metrics": _metrics.merged({"raster": _raster.metrics, "raster_storage_bytes": _raster.storage_bytes(), "certify_samples": _builder.certify_samples,
		"network_length_m": _total_length, "bridges": _bridges, "final_defects": defects, "missing_pieces": missing_pieces})}
	var graph := Graph.new(data, diagnostics)
	var validation: Dictionary = graph.validate()
	if not validation.is_valid:
		var failed: Dictionary = _failure("ERR_ROUTE_GRAPH_INVALID", ",".join(validation.reason_codes))
		failed.diagnostics = diagnostics
		failed["graph_data"] = data
		return failed
	var audit: Array[String] = Builder.audit_crossings(graph, _hydro_field)
	if not audit.is_empty() or defects > 0 or missing_pieces > 0:
		var failed_audit: Dictionary = _failure("ERR_ROUTE_GRAPH_INVALID", ",".join(audit) + ("" if defects == 0 else "ERR_ROUTE_UNCERTIFIED_BARRIER:%d" % defects) + ("" if missing_pieces == 0 else "ERR_ROUTE_MISSING_PIECE:%d" % missing_pieces))
		failed_audit.diagnostics = diagnostics
		return failed_audit
	return {"is_valid": true, "graph": graph, "reason_code": "", "detail": "", "diagnostics": diagnostics}


func _edge_path_between(edges: Array, nodes: Array, excluded: Dictionary, a: int, b: int) -> PackedInt32Array:
	var dist: Dictionary = {a: 0}
	var via: Dictionary = {}
	var heap = Search._Heap.new()
	heap.push(0.0, a)
	while not heap.is_empty():
		var k: int = heap.pop()
		var key: float = heap.popped_key
		if key > dist.get(k, INF):
			continue
		if k == b:
			break
		for edge: Dictionary in edges:
			if excluded.has(edge.id) or (edge.a != k and edge.b != k):
				continue
			var other: int = edge.b if edge.a == k else edge.a
			var nd: float = key + edge.length_cm
			if nd < dist.get(other, INF):
				dist[other] = nd
				via[other] = edge.id
				heap.push(nd, other)
	var result := PackedInt32Array()
	if not dist.has(b):
		return result
	var at: int = b
	while at != a:
		var e: int = via[at]
		result.append(e)
		at = edges[e].b if edges[e].a == at else edges[e].a
	result.reverse()
	return result


func _loops(routes: Array, edges: Array, nodes: Array) -> Array:
	var loops: Array = []
	for route: Dictionary in routes:
		if route.purpose == Graph.Purpose.BACKBONE or route.purpose == Graph.Purpose.JUSTIFIED_SPUR:
			continue
		var excluded: Dictionary = {}
		var branch_length: int = 0
		for e: int in route.edge_ids:
			excluded[e] = true
			branch_length += edges[e].length_cm
		var reference: PackedInt32Array = _edge_path_between(edges, nodes, excluded, route.start_node, route.end_node)
		if reference.is_empty():
			continue
		var reference_length: int = 0
		for e: int in reference:
			reference_length += edges[e].length_cm
		if branch_length + reference_length < Graph.MIN_LOOP_CYCLE_M * 100.0:
			continue
		loops.append({"id": loops.size(), "fork_node": route.start_node, "merge_node": route.end_node, "branch_edge_ids": route.edge_ids.duplicate(), "reference_edge_ids": reference,
			"branch_length_cm": branch_length, "reference_length_cm": reference_length, "route_id": route.id})
	return loops


func _composition(routes: Array, loops: Array, anchors: Array) -> Dictionary:
	var counts := {"routes": routes.size(), "loops": loops.size(), "secondary": 0, "singletrack": 0, "technical": 0, "cross_connection": 0, "shortcut": 0, "spurs": 0, "backbone": 0}
	for route: Dictionary in routes:
		match route.class:
			Graph.RouteClass.BACKBONE:
				counts.backbone += 1
			Graph.RouteClass.SECONDARY:
				counts.secondary += 1
			Graph.RouteClass.SINGLETRACK:
				counts.singletrack += 1
			Graph.RouteClass.TECHNICAL:
				counts.technical += 1
		match route.purpose:
			Graph.Purpose.SHORTCUT:
				counts.shortcut += 1
			Graph.Purpose.JUSTIFIED_SPUR:
				counts.spurs += 1
	for route: Dictionary in routes:
		if route.purpose == Graph.Purpose.CROSS_CONNECTION or route.reasons & Graph.Reason.CONNECTS_LOOPS:
			counts.cross_connection += 1
	var codes := PackedStringArray()
	if loops.is_empty():
		codes.append("DEGRADED_NO_LOOP")
	elif loops.size() < 2:
		codes.append("DEGRADED_FEW_LOOPS")
	if counts.secondary < 2:
		codes.append("DEGRADED_FEW_SECONDARY")
	if counts.singletrack < 2:
		codes.append("DEGRADED_FEW_SINGLETRACK")
	if counts.technical < 1:
		codes.append("DEGRADED_NO_TECHNICAL_SITE")
	if counts.cross_connection < 1:
		codes.append("DEGRADED_NO_CROSS_CONNECTION")
	for kind: int in MAJOR_KINDS:
		var present: bool = false
		var reached: bool = false
		for anchor: Dictionary in anchors:
			if anchor.kind == kind and anchor.status != Graph.AnchorStatus.REJECTED:
				present = true
				reached = reached or anchor.status == Graph.AnchorStatus.USED
		if present and not reached:
			codes.append("DEGRADED_ANCHOR_KIND_UNREACHED:" + Graph.ANCHOR_KIND_NAMES[kind])
	return {"counts": counts, "degrade_codes": codes}


## Human-readable reasons for each accepted route (diagnostic, deterministic).
func _explain() -> Array:
	var result: Array = []
	for r in range(_routes.size()):
		var route: Dictionary = _routes[r]
		var entry := {"route_id": r, "key": route.key, "round": route.round, "class": Graph.CLASS_NAMES[route.class], "purpose": Graph.PURPOSE_NAMES[route.purpose],
			"length_m": roundi(Scoring.path_length(route.path)), "reference_length_m": roundi(Scoring.path_length(route.reference))}
		var evaluation: Dictionary = route.eval
		for key: String in evaluation:
			var value: Variant = evaluation[key]
			if value is float:
				entry[key] = snappedf(value, 0.001)
			elif value is PackedInt32Array:
				var names := PackedStringArray()
				for a: int in value:
					names.append("%s#%d" % [Graph.ANCHOR_KIND_NAMES[_anchors[a].kind], a])
				entry[key] = names
			else:
				entry[key] = value
		result.append(entry)
	return result
