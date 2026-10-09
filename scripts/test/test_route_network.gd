extends SceneTree

## Additive R5 durable contracts (ExecPlan v1.0 §12, V1-V10). Kernels, the
## validator and the full RegionPlan -> terrain -> hydrology -> R4 -> planner
## -> graph chain run through real production code. Journey quality itself is
## judged on diagnostic maps, not by thresholds here.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Search = preload("res://scripts/world/region/route_search.gd")
const Scoring = preload("res://scripts/world/region/route_journey_scoring.gd")
const Builder = preload("res://scripts/world/region/route_corridor_builder.gd")
const Anchors = preload("res://scripts/world/region/route_anchor_finder.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Maps = preload("res://scripts/test/capture_route_map.gd")
const Captures = preload("res://scripts/test/capture_route_preview.gd")
const DOMAIN_FILES: Array[String] = ["region_route_graph", "route_planning_raster", "route_anchor_finder", "route_search", "route_journey_scoring", "route_corridor_builder", "route_planner"]
## The last three rows are holdout regions that exposed defects, kept as
## disclosed regression fixtures (the holdout battery is rerun in full):
## 3628391 @ (3,-2) node-path vs station-line junction angle (trial split);
## 3942578 @ (-1,-1) float32 crossing-query coordinates vs the float64 audit;
## 6037158 @ (-1,-1) gateway valley-floor rule applied after choosing the best
## node, so banks with valley-floor nodes were rejected (ERR_ROUTE_NO_GATEWAY).
const ROWS: Array = [[184729, 0, 0], [42, 0, 0], [77777, 0, 0], [10007, 3, -2], [-9223372036854775808, 2147483647, -2147483648], [3628391, 3, -2], [3942578, -1, -1], [6037158, -1, -1]]
var checks: int = 0
var failures: int = 0
var _occupancy: Array = []
var _compositions: Dictionary = {}
var _signatures: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ROUTE_CONTRACT_FAIL " + label)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	_v1_static()
	_v2_kernel()
	_v6_validator()
	_v10_cli()
	var first_graph: RefCounted = null
	for row: Array in ROWS:
		var graph: RefCounted = _real(row[0], Vector2i(row[1], row[2]))
		if graph == null:
			print("ROUTE_CONTRACT_SUMMARY checks=%d failures=%d completed=false" % [checks, failures])
			quit(1)
			return
		if first_graph == null:
			first_graph = graph
	_v7_determinism()
	_v9_variation()
	print("ROUTE_CONTRACT_SIGNATURES " + JSON.stringify(_signatures))
	print("ROUTE_CONTRACT_SUMMARY checks=%d failures=%d completed=true regions=%d" % [checks, failures, ROWS.size()])
	quit(1 if failures else 0)


# --- V1 ownership, identity, purity ---

func _v1_static() -> void:
	for name: String in DOMAIN_FILES:
		var text: String = FileAccess.get_file_as_string("res://scripts/world/region/" + name + ".gd")
		check(text.contains("extends RefCounted"), "V1 RefCounted " + name)
		for token: String in ["get_tree", "Node3D", "MeshInstance", "RenderingServer", "add_child", "randomize(", "randi()", "randf()", "RandomNumberGenerator", "Time.", "OS.", "RoadGraph", "BicycleController", "ForkDecisionModel", "RoadGrammar", "road_logic", "chunk_streamer", "world_manager"]:
			check(not text.contains(token), "V1 %s free of %s" % [name, token])
	var search_text: String = FileAccess.get_file_as_string("res://scripts/world/region/route_search.gd")
	check(not search_text.contains("route_journey_scoring.gd") and not search_text.contains("route_anchor_finder.gd") and not search_text.contains("route_planner.gd"), "V1 search has no journey/anchor/planner dependency")
	check(Seeds.PURPOSE_ROUTE == "route" and Seeds.route_seed_preimage(42) == "slow_cycle.seed/1\npurpose=route\ncount=1\nv0=42\n", "V1 route seed preimage")
	check(Seeds.route_seed(42) != Seeds.biome_seed(42) and Seeds.route_seed(42) != Seeds.hydrology_seed(42) and Seeds.route_seed(42) >= 0, "V1 route seed separation")
	check(Planner.plan(null, null, null).reason_code == "ERR_ROUTE_INPUT_MISSING", "V1 missing inputs")
	check(Planner.plan(RefCounted.new(), RefCounted.new(), RefCounted.new()).reason_code == "ERR_ROUTE_INPUT_INVALID", "V1 wrong input types")
	var a: RefCounted = Gen.build(5, Vector2i.ZERO)
	var b: RefCounted = Gen.build(6, Vector2i.ZERO)
	var ta: RefCounted = Terrain.create(a).field
	var tb: RefCounted = Terrain.create(b).field
	var hb: RefCounted = HGen.build(b, tb).plan
	check(Planner.plan(a, ta, hb).reason_code == "ERR_ROUTE_INPUT_MISMATCH", "V1 mismatched hydrology")
	check(Planner.plan(a, tb, hb).reason_code == "ERR_ROUTE_INPUT_MISMATCH", "V1 mismatched terrain")


# --- V2 search kernel on controlled grids (real production kernel) ---

func _grid(n: int, heights: Callable, costs: Callable) -> Dictionary:
	var g := {"n": n, "spacing": 32.0, "height": PackedFloat64Array(), "grad_x": PackedFloat64Array(), "grad_z": PackedFloat64Array(), "cost": PackedFloat64Array(), "valley": PackedFloat64Array(),
		"water": PackedByteArray(), "blocked": PackedByteArray(), "body": PackedInt32Array(), "edge_dist": PackedFloat64Array(), "move_crossings": {}, "jumps": {}}
	for k in range(n * n):
		g.height.append(heights.call(k % n, k / n))
		g.grad_x.append(0.0)
		g.grad_z.append(0.0)
		g.cost.append(costs.call(k % n, k / n))
		g.valley.append(1.0)
		g.water.append(0)
		g.blocked.append(0)
		g.body.append(-1)
		g.edge_dist.append(1000.0)
	return g


static func _ones(n: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(n * n)
	p.fill(1)
	return p


static func _zeros(n: int) -> PackedByteArray:
	var p := PackedByteArray()
	p.resize(n * n)
	return p


static func _sep(n: int, value: float) -> PackedFloat64Array:
	var p := PackedFloat64Array()
	p.resize(n * n)
	p.fill(value)
	return p


## Independent Bellman-Ford over the same move table (no heap/A*).
static func _brute(n: int, tables: Dictionary, source: int, goal: int) -> float:
	var dist := PackedFloat64Array()
	dist.resize(n * n)
	dist.fill(INF)
	dist[source] = 0.0
	var off: Dictionary = Search.offsets(n)
	for iteration in range(n * n):
		var changed: bool = false
		for k in range(n * n):
			if dist[k] == INF:
				continue
			for d in range(Search.DIRECTIONS):
				var c: float = tables.base[k * Search.DIRECTIONS + d]
				if c == INF:
					continue
				var t: int = k + off.step[d]
				var nd: float = dist[k] + c + tables.extra[k * Search.DIRECTIONS + d]
				if nd < dist[t] - 1e-12:
					dist[t] = nd
					changed = true
		if not changed:
			break
	return dist[goal]


func _v2_kernel() -> void:
	var n: int = 11
	var flat: Dictionary = _grid(n, func(_i: int, _j: int) -> float: return 0.0, func(_i: int, _j: int) -> float: return 1.0)
	var tables: Dictionary = Search.build_tables(flat, Graph.RouteClass.SECONDARY, _ones(n))
	var straight: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	check(straight.found and absf(straight.cost - 320.0) < 1e-9 and straight.path.size() == 11, "V2 flat straight path cost 320 m")
	var doubled: Dictionary = Search.search(flat, tables, _sep(n, 2.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	check(absf(doubled.cost - 640.0) < 1e-9, "V2 separation multiplies base cost")
	var again: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([0]), _zeros(n), n * n - 1, _zeros(n), INF)
	var repeat: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([0]), _zeros(n), n * n - 1, _zeros(n), INF)
	check(again.path == repeat.path and again.cost == repeat.cost, "V2 deterministic ties")
	# Optimality versus an independent relaxation on rough terrain.
	var m: int = 9
	var rough: Dictionary = _grid(m, func(i: int, j: int) -> float: return 6.0 * sin(i * 0.9) + 4.0 * cos(j * 1.3), func(i: int, j: int) -> float: return 1.0 + float((i * 7 + j * 13) % 5))
	for cls: int in [Graph.RouteClass.BACKBONE, Graph.RouteClass.SECONDARY, Graph.RouteClass.SINGLETRACK, Graph.RouteClass.TECHNICAL]:
		var t: Dictionary = Search.build_tables(rough, cls, _ones(m))
		for pair: Array in [[0, m * m - 1], [m - 1, m * (m - 1)], [4 * m, 4 * m + 8]]:
			var found: Dictionary = Search.search(rough, t, _sep(m, 1.0), PackedInt32Array([pair[0]]), _zeros(m), pair[1], _zeros(m), INF)
			var brute: float = _brute(m, t, pair[0], pair[1])
			check((not found.found and brute == INF) or (found.found and absf(found.cost - brute) < 1e-6 * maxf(1.0, brute)), "V2 A* optimal class %d %s" % [cls, str(pair)])
			if found.found:
				check(absf(Search.path_cost(rough, t, found.path) - found.cost) < 1e-6 * maxf(1.0, found.cost), "V2 path cost consistency class %d" % cls)
	# Barriers: wall with one gap; closed wall.
	var wall: Dictionary = flat.duplicate(true)
	for j in range(n):
		if j != 2:
			wall.blocked[j * n + 5] = 1
	var passable: PackedByteArray = _ones(n)
	for k in range(n * n):
		passable[k] = 0 if wall.blocked[k] == 1 else 1
	var gap: Dictionary = Search.search(wall, Search.build_tables(wall, Graph.RouteClass.SECONDARY, passable), _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	var crossed_gap: bool = gap.found
	for k: int in gap.path:
		crossed_gap = crossed_gap and wall.blocked[k] == 0
	check(crossed_gap and 2 * n + 5 in gap.path, "V2 barrier respected through gap")
	wall.blocked[2 * n + 5] = 1
	passable[2 * n + 5] = 0
	var sealed: Dictionary = Search.search(wall, Search.build_tables(wall, Graph.RouteClass.SECONDARY, passable), _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	check(not sealed.found, "V2 sealed barrier has no path")
	# Squeeze: a diagonal may not pass between two blocked orthogonal nodes.
	var squeeze: Dictionary = flat.duplicate(true)
	squeeze.blocked[1] = 1
	squeeze.blocked[n] = 1
	var squeeze_table: Dictionary = Search.build_tables(squeeze, Graph.RouteClass.SECONDARY, _ones(n))
	check(squeeze_table.base[0 * Search.DIRECTIONS + 4] == INF and squeeze_table.base[0 * Search.DIRECTIONS + 0] < INF, "V2 no squeeze past barriers")
	# Grade response: steeper never cheaper; development flagged or forbidden.
	for cls: int in range(4):
		var profile: Dictionary = Search.PROFILES[cls]
		var last: float = 0.0
		var monotone: bool = true
		for step in range(0, 61):
			var factor: Vector2 = Search.grade_factor(profile, step * 0.01)
			if factor.x == INF:
				break
			monotone = monotone and factor.x >= last
			last = factor.x
		check(monotone, "V2 grade factor monotone class %d" % cls)
		var above: Vector2 = Search.grade_factor(profile, profile.g_max * 1.2)
		check(above.y == 1.0 and ((above.x == INF) != profile.develop), "V2 development flagged/forbidden class %d" % cls)
		var cheap: float = Search.base_cost(flat, profile, 5 * n, 5 * n + 1, PackedInt32Array())
		var steep_grid: Dictionary = _grid(n, func(i: int, _j: int) -> float: return float(i) * 2.0, func(_i: int, _j: int) -> float: return 1.0)
		check(Search.base_cost(steep_grid, profile, 5 * n, 5 * n + 1, PackedInt32Array()) >= cheap, "V2 climbing never cheaper class %d" % cls)
		var cover_grid: Dictionary = _grid(n, func(_i: int, _j: int) -> float: return 0.0, func(_i: int, _j: int) -> float: return 3.0)
		check(Search.base_cost(cover_grid, profile, 5 * n, 5 * n + 1, PackedInt32Array()) >= cheap, "V2 higher ground cost never cheaper class %d" % cls)
		var sloped: Dictionary = flat.duplicate(true)
		sloped.grad_z.fill(0.3)
		check(Search.base_cost(sloped, profile, 5 * n, 5 * n + 1, PackedInt32Array()) >= cheap, "V2 cut/fill cross slope never cheaper class %d" % cls)
	# Crossing hints and costs (Alpha planning heuristics, condition 4).
	var creek := {"class": Graph.WaterKind.CREEK, "width_m": 2.0, "surface_m": 1.0, "bed_m": 0.9, "angle_deg": 90.0}
	check(Search.crossing_hint(creek) == Graph.Hint.FORD, "V2 narrow shallow creek is a ford")
	check(Search.crossing_hint(creek.merged({"width_m": 6.0}, true)) == Graph.Hint.SMALL_BRIDGE and Search.crossing_hint(creek.merged({"bed_m": 0.5}, true)) == Graph.Hint.SMALL_BRIDGE, "V2 wider/deeper creek small bridge")
	check(Search.crossing_hint(creek.merged({"width_m": 12.0}, true)) == Graph.Hint.BRIDGE and Search.crossing_hint(creek.merged({"class": Graph.WaterKind.MAJOR_RIVER}, true)) == Graph.Hint.BRIDGE, "V2 river bridge")
	check(Search.crossing_cost({"crossings": [creek], "body_ids": PackedInt32Array([0])}, Graph.RouteClass.SECONDARY) == INF, "V2 body crossing forbidden")
	check(Search.crossing_cost({"crossings": [creek.merged({"class": Graph.WaterKind.MAJOR_RIVER}, true)], "body_ids": PackedInt32Array()}, Graph.RouteClass.TECHNICAL) == INF, "V2 technical bridge forbidden")
	var square: float = Search.crossing_cost({"crossings": [creek], "body_ids": PackedInt32Array()}, Graph.RouteClass.SECONDARY)
	var oblique: float = Search.crossing_cost({"crossings": [creek.merged({"angle_deg": 20.0}, true)], "body_ids": PackedInt32Array()}, Graph.RouteClass.SECONDARY)
	check(absf(square - (Search.HINT_COST_M[0] + Search.CROSSING_WIDTH_COST * 2.0)) < 1e-9 and oblique > square, "V2 crossing cost and oblique penalty")
	# Water jumps: a river column is crossed only by a recorded jump.
	var river: Dictionary = flat.duplicate(true)
	for j in range(n):
		river.water[j * n + 5] = 1
	var dry: PackedByteArray = _ones(n)
	for j in range(n):
		dry[j * n + 5] = 0
	var none: Dictionary = Search.search(river, Search.build_tables(river, Graph.RouteClass.SECONDARY, dry), _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	check(not none.found, "V2 water never stood on or crossed without a recorded crossing")
	river.jumps = {5 * n + 4: [5 * n + 6], 5 * n + 6: [5 * n + 4]}
	river.move_crossings = {Raster.pair_key(5 * n + 4, 5 * n + 6): {"crossings": [creek.merged({"width_m": 20.0, "class": Graph.WaterKind.TRIBUTARY}, true)], "body_ids": PackedInt32Array()}}
	var jumped: Dictionary = Search.search(river, Search.build_tables(river, Graph.RouteClass.SECONDARY, dry), _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	var index: int = jumped.path.find(5 * n + 4)
	check(jumped.found and index >= 0 and jumped.path[index + 1] == 5 * n + 6, "V2 recorded water jump used")
	var technical_jump: Dictionary = Search.search(river, Search.build_tables(river, Graph.RouteClass.TECHNICAL, dry), _sep(n, 1.0), PackedInt32Array([5 * n]), _zeros(n), 5 * n + 10, _zeros(n), INF)
	check(not technical_jump.found, "V2 class-forbidden crossing not used")
	# Multi-target, closed nodes and squeeze past closed network nodes.
	var targets: PackedByteArray = _zeros(n)
	targets[5 * n + 9] = 1
	targets[5 * n + 2] = 1
	var near: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([5 * n]), targets, -1, _zeros(n), INF)
	check(near.found and near.path[near.path.size() - 1] == 5 * n + 2, "V2 multi-target finds nearest")
	var far: PackedByteArray = _zeros(n)
	far[5 * n + 9] = 1
	var closed: PackedByteArray = _zeros(n)
	for j in range(n):
		closed[j * n + 3] = 1
	var walled: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([5 * n]), far, -1, closed, INF)
	check(not walled.found, "V2 closed network nodes cannot be crossed")
	closed[5 * n + 3] = 0
	var through: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([5 * n]), far, -1, closed, INF)
	check(through.found and 5 * n + 3 in through.path, "V2 open junction gap usable")
	var diagonal_block: PackedByteArray = _zeros(n)
	diagonal_block[1] = 1
	diagonal_block[n] = 1
	var ring: PackedByteArray = _zeros(n)
	ring[n + 1] = 1
	var around: Dictionary = Search.search(flat, tables, _sep(n, 1.0), PackedInt32Array([0]), ring, -1, diagonal_block, INF)
	check(not around.found or not (around.path.size() == 2), "V2 no diagonal squeeze past closed nodes")
	# Scoring: saturating novelty; length beyond typical penalised.
	check(Scoring.biome_group(0) == 0 and Scoring.biome_group(3) == 0 and Scoring.biome_group(1) == 1 and Scoring.biome_group(2) == 2 and Scoring.biome_group(4) == -1, "V2 biome groups")


# --- V6 validator negatives on crafted graphs ---

func _crafted(spec: Dictionary) -> Dictionary:
	var nodes: Array = []
	for row: Array in spec.nodes:
		nodes.append({"id": nodes.size(), "kind": row[0], "x_cm": roundi(row[1] * 100.0), "z_cm": roundi(row[2] * 100.0), "elevation_cm": 0, "anchor_id": row[4] if row.size() > 4 else -1, "justification": row[3] if row.size() > 3 else Graph.Justification.NONE})
	var edges: Array = []
	for row: Array in spec.edges:
		var line := PackedVector2Array([Vector2(nodes[row[0]].x_cm, nodes[row[0]].z_cm) / 100.0])
		for p: Vector2 in row[4]:
			line.append(p)
		line.append(Vector2(nodes[row[1]].x_cm, nodes[row[1]].z_cm) / 100.0)
		var st: Array = Builder.stations_cm(line)
		var count: int = st[0].size()
		var corridor := {"x_cm": st[0], "z_cm": st[1], "elevation_cm": PackedInt64Array(), "grade_permille": PackedInt32Array(), "cross_permille": PackedInt32Array(), "half_left_cm": PackedInt32Array(), "half_right_cm": PackedInt32Array(), "cost_milli": PackedInt32Array(), "biome": PackedByteArray(), "flags": PackedInt32Array()}
		for k in range(count):
			corridor.elevation_cm.append(0)
			corridor.grade_permille.append(0)
			corridor.cross_permille.append(0)
			corridor.half_left_cm.append(3000)
			corridor.half_right_cm.append(3000)
			corridor.cost_milli.append(1000)
			corridor.biome.append(0)
			corridor.flags.append(0)
		edges.append({"id": edges.size(), "a": row[0], "b": row[1], "route_id": row[2], "class": row[3], "length_cm": roundi(Graph.polyline_length_cm(st[0], st[1])), "climb_cm": 0, "descent_cm": 0, "reasons": 0, "crossings": [], "anchors_passed": PackedInt32Array(), "corridor": corridor})
	var routes: Array = []
	for row: Array in spec.routes:
		routes.append({"id": routes.size(), "class": row[0], "purpose": row[1], "edge_ids": PackedInt32Array(row[2]), "start_node": row[3], "end_node": row[4], "anchor_ids": PackedInt32Array(), "score_milli": 0, "reasons": 0})
	var loops: Array = []
	for row: Array in spec.loops:
		var branch: int = 0
		var reference: int = 0
		for e: int in row[2]:
			branch += edges[e].length_cm
		for e: int in row[3]:
			reference += edges[e].length_cm
		loops.append({"id": loops.size(), "fork_node": row[0], "merge_node": row[1], "branch_edge_ids": PackedInt32Array(row[2]), "reference_edge_ids": PackedInt32Array(row[3]), "branch_length_cm": branch, "reference_length_cm": reference})
	var anchors: Array = []
	for row: Array in spec.anchors:
		anchors.append({"id": anchors.size(), "kind": row[0], "x_cm": roundi(row[1] * 100.0), "z_cm": roundi(row[2] * 100.0), "elevation_cm": 0, "status": Graph.AnchorStatus.USED, "source": "crafted", "reason_code": ""})
	return {"region_signature": "crafted", "hydrology_signature": "crafted", "rideability_signature": "crafted", "model": "crafted", "route_seed": 1, "origin_x_m": 0, "origin_z_m": 0, "frame_symmetry": 0, "planning_spacing_m": 32,
		"nodes": nodes, "edges": edges, "routes": routes, "loops": loops, "anchors": anchors}


## Crafted Mountain-River-like network: backbone G0-J1-J2-J3-G1 along z=2000,
## a secondary loop south (J1-J2), a singletrack loop north (J2-J4-J3) and a
## singletrack spur J4 -> PASS terminus.
func _base_spec() -> Dictionary:
	var S := Graph.RouteClass.SECONDARY
	var T := Graph.RouteClass.SINGLETRACK
	var B := Graph.RouteClass.BACKBONE
	return {"nodes": [[Graph.NodeKind.GATEWAY, 0.0, 2000.0, Graph.Justification.REGION_GATEWAY], [Graph.NodeKind.JUNCTION, 1000.0, 2000.0], [Graph.NodeKind.JUNCTION, 2000.0, 2000.0],
			[Graph.NodeKind.JUNCTION, 3000.0, 2000.0], [Graph.NodeKind.GATEWAY, 4096.0, 2000.0, Graph.Justification.REGION_GATEWAY], [Graph.NodeKind.JUNCTION, 2500.0, 2600.0],
			[Graph.NodeKind.TERMINUS, 2500.0, 3200.0, Graph.Justification.PASS, 0]],
		"edges": [[0, 1, 0, B, []], [1, 2, 0, B, []], [2, 3, 0, B, []], [3, 4, 0, B, []], [1, 2, 1, S, [Vector2(1500, 1500)]], [2, 5, 2, T, []], [5, 3, 2, T, []], [5, 6, 3, T, []]],
		"routes": [[B, Graph.Purpose.BACKBONE, [0, 1, 2, 3], 0, 4], [S, Graph.Purpose.LOOP_ALTERNATIVE, [4], 1, 2], [T, Graph.Purpose.LOOP_ALTERNATIVE, [5, 6], 2, 3], [T, Graph.Purpose.JUSTIFIED_SPUR, [7], 5, 6]],
		"loops": [[1, 2, [4], [1]], [2, 3, [5, 6], [2]]],
		"anchors": [[Graph.AnchorKind.PASS, 2500.0, 3200.0], [Graph.AnchorKind.LAKE_SHORE, 1500.0, 1500.0]]}


func _expect(data: Dictionary, reason: String, label: String) -> void:
	var result: Dictionary = Graph.new(data).validate()
	check(not result.is_valid and reason in result.reason_codes, "V6 %s -> %s (got %s)" % [label, reason, str(result.reason_codes)])


func _v6_validator() -> void:
	var base: Dictionary = _crafted(_base_spec())
	var valid: Dictionary = Graph.new(base).validate()
	check(valid.is_valid, "V6 crafted network valid %s" % str(valid.reason_codes))
	var graph := Graph.new(base)
	var node: Dictionary = graph.get_route_node(0)
	node.x_cm = 5
	check(graph.get_route_node(0).x_cm == 0 and graph.signature() == Graph.new(base).signature(), "V1 accessors return copies")
	var corridor: Dictionary = graph.get_corridor(4)
	check(corridor.schema == Graph.CORRIDOR_SCHEMA_TAG and corridor.station_count >= 2 and corridor.x_m.size() == corridor.station_count, "V1 RouteCorridor view")
	var d: Dictionary
	d = base.duplicate(true)
	d.erase("nodes")
	_expect(d, "ERR_GRAPH_SCHEMA", "missing nodes")
	d = base.duplicate(true)
	d.nodes[1].x_cm = 1.5
	_expect(d, "ERR_GRAPH_SCHEMA", "float coordinate")
	d = base.duplicate(true)
	d.nodes[1].id = 2
	_expect(d, "ERR_GRAPH_ID", "node id")
	d = base.duplicate(true)
	d.edges[2].b = 99
	_expect(d, "ERR_GRAPH_REFERENCE", "edge node reference")
	d = base.duplicate(true)
	d.nodes[6].anchor_id = 9
	_expect(d, "ERR_GRAPH_ANCHOR_REFERENCE", "anchor reference")
	d = base.duplicate(true)
	d.edges[7].b = 5
	_expect(d, "ERR_GRAPH_SELF_LOOP", "self loop")
	d = base.duplicate(true)
	d.nodes.append({"id": 7, "kind": Graph.NodeKind.JUNCTION, "x_cm": 300000, "z_cm": 100000, "elevation_cm": 0, "anchor_id": -1, "justification": 0})
	_expect(d, "ERR_GRAPH_ORPHAN", "isolated node")
	d = base.duplicate(true)
	d.routes[1].edge_ids = PackedInt32Array([4, 5])
	_expect(d, "ERR_GRAPH_ORPHAN", "edge in two routes")
	d = base.duplicate(true)
	d.nodes[1].kind = Graph.NodeKind.TERMINUS
	_expect(d, "ERR_GRAPH_NODE_DEGREE", "terminus with degree 3")
	var spec: Dictionary = _base_spec()
	spec.nodes.append_array([[Graph.NodeKind.JUNCTION, 1000.0, 3400.0], [Graph.NodeKind.JUNCTION, 1600.0, 3400.0]])
	spec.edges.append([7, 8, 4, Graph.RouteClass.SECONDARY, []])
	spec.routes.append([Graph.RouteClass.SECONDARY, Graph.Purpose.CROSS_CONNECTION, [8], 7, 8])
	_expect(_crafted(spec), "ERR_GRAPH_DISCONNECTED", "second component")
	d = base.duplicate(true)
	d.nodes[4].x_cm = 400000
	d.edges[3].corridor.x_cm[d.edges[3].corridor.x_cm.size() - 1] = 400000
	_expect(d, "ERR_GRAPH_BACKBONE", "gateway not at valley end")
	d = base.duplicate(true)
	d.routes[1].class = Graph.RouteClass.BACKBONE
	d.edges[4].class = Graph.RouteClass.BACKBONE
	_expect(d, "ERR_GRAPH_BACKBONE", "backbone not a single path")
	spec = _base_spec()
	spec.routes[3][0] = Graph.RouteClass.SECONDARY
	spec.edges[7][3] = Graph.RouteClass.SECONDARY
	_expect(_crafted(spec), "ERR_GRAPH_HIERARCHY", "secondary relying on singletrack")
	spec = _base_spec()
	spec.routes[3][0] = Graph.RouteClass.TECHNICAL
	spec.edges[7][3] = Graph.RouteClass.TECHNICAL
	_expect(_crafted(spec), "ERR_GRAPH_TECHNICAL_REQUIRED", "technical dead-end")
	spec = _base_spec()
	spec.routes[2][0] = Graph.RouteClass.TECHNICAL
	spec.edges[5][3] = Graph.RouteClass.TECHNICAL
	spec.edges[6][3] = Graph.RouteClass.TECHNICAL
	_expect(_crafted(spec), "ERR_GRAPH_TECHNICAL_REQUIRED", "network requires technical")
	d = base.duplicate(true)
	d.nodes[6].kind = Graph.NodeKind.GATEWAY
	d.nodes[6].justification = Graph.Justification.REGION_GATEWAY
	_expect(d, "ERR_GRAPH_BACKTRACK", "spur to a non-terminus leaf")
	d = base.duplicate(true)
	d.nodes[6].justification = Graph.Justification.NONE
	_expect(d, "ERR_GRAPH_UNJUSTIFIED_DEAD_END", "unjustified terminus")
	d = base.duplicate(true)
	d.nodes[6].justification = Graph.Justification.LAKE_SHORE
	_expect(d, "ERR_GRAPH_UNJUSTIFIED_DEAD_END", "justification without matching anchor")
	d = base.duplicate(true)
	d.loops[0].reference_edge_ids = PackedInt32Array([2])
	_expect(d, "ERR_GRAPH_LOOP_RECORD", "loop reference not a path")
	d = base.duplicate(true)
	d.loops[0].branch_length_cm += 1
	_expect(d, "ERR_GRAPH_LOOP_RECORD", "loop length mismatch")
	spec = _base_spec()
	spec.edges[4][4] = [Vector2(1100, 2030), Vector2(1500, 1500)]
	_expect(_crafted(spec), "ERR_GRAPH_JUNCTION_ANGLE", "acute junction")
	spec = _base_spec()
	spec.nodes[2][1] = 1150.0
	spec.edges[4][4] = [Vector2(1075, 1700)]
	_expect(_crafted(spec), "ERR_GRAPH_JUNCTION_SPACING", "junctions 150 m apart")
	spec = _base_spec()
	spec.edges.append([1, 3, 4, Graph.RouteClass.SECONDARY, [Vector2(1100, 1800), Vector2(1250, 2045), Vector2(2900, 2045)]])
	spec.routes.append([Graph.RouteClass.SECONDARY, Graph.Purpose.LOOP_ALTERNATIVE, [8], 1, 3])
	_expect(_crafted(spec), "ERR_GRAPH_DUPLICATE", "route parallel to backbone")
	d = base.duplicate(true)
	d.edges[4].corridor.half_left_cm[2] = 0
	_expect(d, "ERR_GRAPH_CORRIDOR", "zero half-width")
	d = base.duplicate(true)
	d.edges[4].corridor.x_cm.remove_at(3)
	d.edges[4].corridor.z_cm.remove_at(3)
	for key: String in ["elevation_cm", "grade_permille", "cross_permille", "half_left_cm", "half_right_cm", "cost_milli", "biome", "flags"]:
		d.edges[4].corridor[key].remove_at(3)
	_expect(d, "ERR_GRAPH_CORRIDOR", "station gap over 32 m")
	d = base.duplicate(true)
	d.edges[4].corridor.x_cm[0] += 500
	_expect(d, "ERR_GRAPH_CORRIDOR", "corridor not at its node")
	spec = _base_spec()
	spec.edges[7][4] = [Vector2(2500, 4080)]
	_expect(_crafted(spec), "ERR_GRAPH_CORRIDOR", "corridor at the region edge away from gateways")
	d = base.duplicate(true)
	d.edges[7].crossings.append({"station": 999, "water_kind": 2, "channel_id": 1, "x_cm": 0, "z_cm": 0, "width_cm": 100, "depth_cm": 10, "angle_deg": 90, "hint": 0})
	_expect(d, "ERR_GRAPH_CROSSING_RECORD", "crossing station range")
	spec = _base_spec()
	spec.routes[2][0] = Graph.RouteClass.SINGLETRACK
	d = _crafted(spec)
	d.edges[1].crossings.append({"station": 2, "water_kind": 0, "channel_id": 0, "x_cm": 0, "z_cm": 0, "width_cm": 2000, "depth_cm": 100, "angle_deg": 120, "hint": 2})
	_expect(d, "ERR_GRAPH_CROSSING_RECORD", "crossing angle out of range")
	d = _crafted(_base_spec())
	d.edges[4].crossings.append({"station": 1, "water_kind": 0, "channel_id": 0, "x_cm": 0, "z_cm": 0, "width_cm": 2000, "depth_cm": 100, "angle_deg": 90, "hint": 2})
	check(Graph.new(d).validate().is_valid, "V6 secondary may carry a bridge hint")
	d.edges[4].class = Graph.RouteClass.TECHNICAL
	d.routes[1].class = Graph.RouteClass.TECHNICAL
	check("ERR_GRAPH_CROSSING_RECORD" in Graph.new(d).validate().reason_codes, "V6 technical may not carry a bridge hint")


# --- Real regions: V3 V4 V5 V8 ---

func _independent_crossings(channels: Array, a: Vector2, b: Vector2) -> Array:
	var result: Array = []
	for channel: Dictionary in channels:
		for k in range(channel.x_cm.size() - 1):
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var q := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / 100.0
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, p, q)
			if hit != null:
				result.append([channel.id, a.distance_to(hit) / maxf(a.distance_to(b), 1e-9)])
	return result


func _real(seed_value: int, region: Vector2i) -> RefCounted:
	var label: String = "%d@%s" % [seed_value, str(region)]
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydrology: RefCounted = HGen.build(plan, terrain).plan
	var region_before: String = plan.signature()
	var hydro_before: String = hydrology.signature()
	var probe: Dictionary = terrain.sample_height(terrain.get_bounds_m().min_x + 1234.5, terrain.get_bounds_m().min_z + 2345.5)
	var result: Dictionary = Planner.plan(plan, terrain, hydrology)
	check(result.is_valid, "V8 %s planner result %s %s" % [label, result.reason_code, result.detail])
	if not result.is_valid:
		return null
	var graph: RefCounted = result.graph
	_signatures[label] = graph.signature()
	check(plan.signature() == region_before and hydrology.signature() == hydro_before and terrain.sample_height(terrain.get_bounds_m().min_x + 1234.5, terrain.get_bounds_m().min_z + 2345.5).height_m == probe.height_m, "V1 %s upstream unchanged by planning" % label)
	var validation: Dictionary = graph.validate()
	check(validation.is_valid, "V8 %s graph valid %s" % [label, str(validation.reason_codes)])
	check(graph.get_origin_x_m() == terrain.get_bounds_m().min_x and graph.get_origin_z_m() == terrain.get_bounds_m().min_z, "V1 %s int64 region origin preserved" % label)
	var hydro_field: RefCounted = HField.create(hydrology, terrain).field
	check(Builder.audit_crossings(graph, hydro_field).is_empty(), "V8 %s crossing audit" % label)
	var composition: Dictionary = result.diagnostics.composition
	_compositions[label] = composition
	check(composition.backbone == 1 and composition.loops >= 1 and graph.get_loop_count() == composition.loops, "V8 %s backbone and at least one loop" % label)
	for code: String in result.diagnostics.degrade_codes:
		check(code.begins_with("DEGRADED_"), "V8 %s explicit degrade code %s" % [label, code])
	check(not "DEGRADED_NO_LOOP" in result.diagnostics.degrade_codes, "V8 %s loops exist" % label)
	# Independent exact recertification: deep water only at recorded crossings.
	var context: RefCounted = Context.create(plan, terrain, hydrology).context
	var ride: RefCounted = Ride.create(context, Biome.create(context).field).field
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var uncrossed: int = 0
	var samples: int = 0
	for e in range(graph.get_edge_count()):
		var edge: Dictionary = graph.get_edge(e)
		var c: Dictionary = edge.corridor
		var length: float = Graph.polyline_length_cm(c.x_cm, c.z_cm)
		var steps: int = ceili(length / 800.0)
		for s in range(steps + 1):
			var p: Vector2 = Graph.point_along(c.x_cm, c.z_cm, length * s / steps, false) / 100.0
			var point: Dictionary = ride.sample(ox + p.x, oz + p.y)
			samples += 1
			if not point.is_valid:
				check(false, "V8 %s corridor sample valid (%s)" % [label, point.reason_code])
				continue
			if point.reason_flags & Ride.Reason.DEEP_WATER:
				var near_crossing: bool = false
				for crossing: Dictionary in edge.crossings:
					near_crossing = near_crossing or Vector2(crossing.x_cm, crossing.z_cm).distance_to(p * 100.0) <= 2400.0
				uncrossed += 0 if near_crossing else 1
	check(uncrossed == 0 and samples > 0, "V8 %s deep water only at recorded crossings (%d samples)" % [label, samples])
	# Hint/class compatibility, node/route consistency, termini justification.
	var data: Dictionary = graph.get_data()
	for edge: Dictionary in data.edges:
		for crossing: Dictionary in edge.crossings:
			check(crossing.hint in Graph.ALLOWED_HINTS[edge.class], "V8 %s crossing hint allowed" % label)
	# V3 segment crossings versus independent geometry.
	var channels: Array = []
	for k in range(hydrology.get_channel_count()):
		channels.append(hydrology.get_channel(k))
	var b: Dictionary = terrain.get_bounds_m()
	var compared: int = 0
	for c in range(0, channels.size(), 3):
		var channel: Dictionary = channels[c]
		var k: int = (channel.x_cm.size() - 1) / 2
		var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
		var q := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / 100.0
		var middle: Vector2 = (p + q) * 0.5
		var normal: Vector2 = (q - p).normalized().orthogonal() * 20.0
		var a: Vector2 = (middle - normal).clamp(Vector2.ZERO, Vector2(4096, 4096))
		var z: Vector2 = (middle + normal).clamp(Vector2.ZERO, Vector2(4096, 4096))
		var found: Dictionary = hydro_field.sample_segment_crossings(b.min_x + a.x, b.min_z + a.y, b.min_x + z.x, b.min_z + z.y)
		var expected: Array = _independent_crossings(channels, a, z)
		var actual: Array = []
		for record: Dictionary in found.crossings:
			actual.append([record.channel_id, snappedf(record.t, 1e-4)])
		check(found.is_valid and actual.size() == expected.size(), "V3 %s perpendicular crossing count channel %d" % [label, channel.id])
		var own: bool = false
		for record: Dictionary in found.crossings:
			if record.channel_id == channel.id:
				own = true
				check(absf(record.angle_deg - 90.0) < 1.0 and record.width_m > 0.0 and record.surface_m > record.bed_m, "V3 %s perpendicular crossing attributes" % label)
		check(own, "V3 %s crossing of the probed channel recorded" % label)
		compared += 1
	for gx in range(0, 4096, 333):
		for gz in range(0, 4096, 417):
			var a := Vector2(gx, gz)
			var z: Vector2 = (a + Vector2(137.0, -91.0)).clamp(Vector2.ZERO, Vector2(4096, 4096))
			var found: Dictionary = hydro_field.sample_segment_crossings(b.min_x + a.x, b.min_z + a.y, b.min_x + z.x, b.min_z + z.y)
			var expected: Array = _independent_crossings(channels, a, z)
			var actual: Array = []
			for record: Dictionary in found.crossings:
				actual.append([record.channel_id, record.t])
			expected.sort()
			actual.sort()
			var same: bool = actual.size() == expected.size()
			for m in range(mini(actual.size(), expected.size())):
				same = same and actual[m][0] == expected[m][0] and absf(actual[m][1] - expected[m][1]) < 1e-3
			check(same, "V3 %s grid segment %d,%d crossings" % [label, gx, gz])
	check(compared > 0, "V3 %s probed channels" % label)
	check(hydro_field.sample_segment_crossings(b.min_x + 10.0, b.min_z + 10.0, b.min_x + 300.0, b.min_z + 10.0).reason_code == "ERR_HYDRO_SEGMENT_LENGTH", "V3 %s segment length limit" % label)
	check(hydro_field.sample_segment_crossings(b.min_x - 10.0, b.min_z, b.min_x + 10.0, b.min_z).reason_code == "ERR_HYDRO_OUT_OF_DOMAIN", "V3 %s out of domain" % label)
	check(hydro_field.sample_segment_crossings(NAN, b.min_z, b.min_x, b.min_z).reason_code == "ERR_HYDRO_NONFINITE_INPUT", "V3 %s nonfinite" % label)
	# V3 crossing audit negatives on this real graph.
	var with_crossing: int = -1
	for edge: Dictionary in data.edges:
		if not edge.crossings.is_empty():
			with_crossing = edge.id
			break
	if with_crossing >= 0:
		var missing: Dictionary = data.duplicate(true)
		missing.edges[with_crossing].crossings.remove_at(0)
		check("ERR_ROUTE_CROSSING_MISSING" in Builder.audit_crossings(Graph.new(missing), hydro_field), "V3 %s missing crossing record detected" % label)
		var phantom: Dictionary = data.duplicate(true)
		var fake: Dictionary = phantom.edges[with_crossing].crossings[0].duplicate()
		fake.x_cm += 777
		phantom.edges[with_crossing].crossings.append(fake)
		check("ERR_ROUTE_CROSSING_PHANTOM" in Builder.audit_crossings(Graph.new(phantom), hydro_field), "V3 %s phantom crossing record detected" % label)
	# V4 raster parity with direct point queries (bit-identical).
	if seed_value == 184729 or region != Vector2i.ZERO:
		var surface: RefCounted = Surface.create(terrain, hydro_field).surface
		var raster: Raster = Raster.create(ride, surface, hydro_field, hydrology)
		var parity: bool = true
		for m in range(48):
			var k: int = (m * 3571 + 17) % Raster.NODES
			var x: float = b.min_x + Raster.SPACING_M * (k % Raster.N)
			var z: float = b.min_z + Raster.SPACING_M * (k / Raster.N)
			var point: Dictionary = ride.sample_combined(x, z)
			parity = parity and raster.cost[k] == point.rideability.cost and raster.blocked[k] == int(point.rideability.blocked) and raster.water[k] == int(point.rideability.is_water)
			parity = parity and raster.grad_x[k] == point.rideability.gradient.x and raster.grad_z[k] == point.rideability.gradient.y and raster.cover[k] == point.biome.woody_cover
			parity = parity and raster.height[k] == surface.sample_height(x, z).height_m and raster.valley[k] == point.signals.valley_floor_weight and raster.biome[k] == point.biome.dominant
		check(parity, "V4 %s raster bit-identical to point queries" % label)
		var bodies_ok: bool = true
		for body in range(hydrology.get_body_count()):
			for cell: int in hydrology.get_body(body).cells:
				bodies_ok = bodies_ok and raster.body[cell] == body
		check(bodies_ok, "V4 %s body membership exact per node" % label)
		# V5 anchors on the real raster.
		var macro: Dictionary = plan.get_macro_terrain().get_data()
		var descriptor: Dictionary = Biome.create(context).field.get_descriptor()
		var anchors: Array = Anchors.find(raster, macro, hydrology, descriptor)
		var again: Array = Anchors.find(raster, macro, hydrology, descriptor)
		check(JSON.stringify(anchors) == JSON.stringify(again), "V5 %s anchors deterministic" % label)
		var finder: RefCounted = Anchors.with_raster(raster, macro.frame_symmetry)
		var gateways: int = 0
		for anchor: Dictionary in anchors:
			if anchor.status == Graph.AnchorStatus.REJECTED:
				check(not anchor.reason_code.is_empty() and anchor.node == -1, "V5 %s rejected anchor has a reason" % label)
				continue
			check(finder.usable(anchor.node, anchor.kind != Graph.AnchorKind.GATEWAY), "V5 %s anchor %s usable" % [label, Graph.ANCHOR_KIND_NAMES[anchor.kind]])
			gateways += 1 if anchor.kind == Graph.AnchorKind.GATEWAY else 0
		check(gateways >= 2, "V5 %s gateways found" % label)
		# Gateway banks, restated independently from the raster: an accepted
		# gateway stands on the valley floor; a rejected bank has no dry,
		# non-blocked boundary node 40-384 m from the exit with valley >= 0.3.
		var river: Dictionary = hydrology.get_channel(0)
		var last: int = river.x_cm.size() - 1
		var ends := {"upstream": [0, 1], "downstream": [last, last - 1]}
		var ends_found := {}
		for anchor: Dictionary in anchors:
			if anchor.kind != Graph.AnchorKind.GATEWAY:
				continue
			var parts: PackedStringArray = anchor.source.split(".")
			var end: Array = ends[parts[2]]
			var p := Vector2(river.x_cm[end[0]], river.z_cm[end[0]]) / 100.0
			var inward := (Vector2(river.x_cm[end[1]], river.z_cm[end[1]]) / 100.0 - p).normalized()
			var side: float = -1.0 if parts[3] == "left" else 1.0
			if anchor.status != Graph.AnchorStatus.REJECTED:
				ends_found[parts[2]] = true
				check(raster.valley[anchor.node] >= 0.3 and raster.edge_dist[anchor.node] == 0.0, "V5 %s gateway %s on the valley floor at the boundary" % [label, anchor.source])
				continue
			var eligible: int = 0
			for k in range(Raster.NODES):
				var q: Vector2 = Raster.local_of(k)
				var d: float = q.distance_to(p)
				if raster.edge_dist[k] == 0.0 and d >= 40.0 and d <= 384.0 and signf(inward.cross(q - p)) == side and raster.water[k] == 0 and raster.blocked[k] == 0 and raster.body[k] < 0 and raster.valley[k] >= 0.3:
					eligible += 1
			check(eligible == 0, "V5 %s rejected gateway %s has no eligible valley-floor node (found %d)" % [label, anchor.source, eligible])
		check(ends_found.size() == 2, "V5 %s gateway at both valley ends" % label)
		for k in range(1, macro.main_nodes.size() - 1):
			if macro.main_nodes[k].kind != Macro.NODE_SADDLE:
				continue
			var s0: Vector2 = Macro.frame_to_local(macro.frame_symmetry, macro.main_nodes[k - 1].u_m, macro.main_nodes[k - 1].v_m)
			var s1: Vector2 = Macro.frame_to_local(macro.frame_symmetry, macro.main_nodes[k + 1].u_m, macro.main_nodes[k + 1].v_m)
			var a: int = Raster.index_of(s0.x, s0.y)
			var z: int = Raster.index_of(s1.x, s1.y)
			var saddle: int = finder.topographic_saddle(a, z, Rect2i(0, 0, Raster.N, Raster.N))
			var straight_min: float = INF
			for t in range(65):
				var p: Vector2 = s0.lerp(s1, t / 64.0)
				straight_min = minf(straight_min, raster.height[Raster.index_of(p.x, p.y)])
			check(saddle >= 0 and raster.height[saddle] >= straight_min - 1e-9, "V5 %s topographic pass is the highest ridge crossing (maximin)" % label)
	# V9 canonical-frame occupancy for seed variation.
	var occupancy: Dictionary = {}
	for edge: Dictionary in data.edges:
		for k in range(edge.corridor.x_cm.size()):
			var frame: Vector2 = Macro.local_to_frame(data.frame_symmetry, edge.corridor.x_cm[k] / 100.0, edge.corridor.z_cm[k] / 100.0)
			occupancy[clampi(int(frame.y / 64.0), 0, 63) * 64 + clampi(int(frame.x / 64.0), 0, 63)] = true
	_occupancy.append(occupancy)
	return graph


# --- V7 determinism ---

func _v7_determinism() -> void:
	var plan: RefCounted = Gen.build(184729, Vector2i.ZERO)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydrology: RefCounted = HGen.build(plan, terrain).plan
	seed(987654)
	var noise: int = randi()
	var first: Dictionary = Planner.plan(plan, terrain, hydrology)
	seed(noise)
	randf()
	var fresh_plan: RefCounted = Gen.build(184729, Vector2i.ZERO)
	var fresh_terrain: RefCounted = Terrain.create(fresh_plan).field
	var second: Dictionary = Planner.plan(fresh_plan, fresh_terrain, HGen.build(fresh_plan, fresh_terrain).plan)
	check(first.is_valid and second.is_valid and first.graph.signature() == second.graph.signature() and first.graph.signature() == _signatures["184729@(0, 0)"], "V7 fresh pipelines and global RNG disturbance reproduce the graph")
	check(first.graph.diagnostics_signature() == second.graph.diagnostics_signature(), "V7 diagnostics reproducible")
	check(first.graph.canonical_text() == second.graph.canonical_text(), "V7 canonical text identical")


# --- V9 seed variation ---

func _v9_variation() -> void:
	var labels: Array = _signatures.keys()
	var distinct: Dictionary = {}
	for label: String in labels:
		distinct[_signatures[label]] = true
	check(distinct.size() == labels.size(), "V9 distinct graph signatures")
	var worst: float = 0.0
	for x in range(_occupancy.size()):
		for y in range(x + 1, _occupancy.size()):
			var inter: int = 0
			for k: int in _occupancy[x]:
				inter += 1 if _occupancy[y].has(k) else 0
			worst = maxf(worst, float(inter) / maxi(1, _occupancy[x].size() + _occupancy[y].size() - inter))
	check(worst < 0.9, "V9 canonical-frame layouts differ (max Jaccard %.3f)" % worst)
	var shapes: Dictionary = {}
	for label: String in _compositions:
		var c: Dictionary = _compositions[label]
		shapes["%d/%d/%d/%d/%d" % [c.loops, c.secondary, c.singletrack, c.technical, c.cross_connection]] = true
	check(shapes.size() >= 2, "V9 network compositions vary across regions")
	print("ROUTE_CONTRACT_VARIATION max_jaccard=%.3f compositions=%s" % [worst, JSON.stringify(_compositions)])


# --- V10 tool CLI negatives ---

func _v10_cli() -> void:
	for fixture: Array in [["--seeds=no", "ERR_ROUTE_CLI_SEED"], ["--seeds=9223372036854775808", "ERR_ROUTE_CLI_SEED"], ["--seeds=1,2,3,4,5,6,7", "ERR_ROUTE_CLI_SEED"], ["--region=1", "ERR_ROUTE_CLI_REGION"],
			["--region=2147483648,0", "ERR_ROUTE_CLI_REGION"], ["--holdout-batch=4", "ERR_ROUTE_CLI_BATCH"], ["--unknown", "ERR_ROUTE_CLI_ARGUMENT"]]:
		check(Maps.parse_options(PackedStringArray([fixture[0], "--out=C:/r5-evidence"])).reason_code == fixture[1], "V10 CLI " + fixture[0])
	check(Maps.parse_options(PackedStringArray(["--seeds=1", "--seeds=2", "--out=C:/r5-evidence"])).reason_code == "ERR_ROUTE_CLI_DUPLICATE", "V10 duplicate CLI")
	check(Maps.parse_options(PackedStringArray(["--seeds=1", "--out=" + ProjectSettings.globalize_path("res://")])).reason_code == "ERR_ROUTE_CLI_OUTPUT", "V10 project output rejected")
	check(Maps.parse_options(PackedStringArray(["--out=relative"])).reason_code == "ERR_ROUTE_CLI_OUTPUT", "V10 relative output rejected")
	check(Maps.parse_options(PackedStringArray(["--holdout-batch=1", "--seeds=3", "--out=C:/r5-evidence"])).reason_code == "ERR_ROUTE_CLI_ARGUMENT", "V10 holdout excludes explicit seeds")
	check(Maps.parse_options(PackedStringArray(["--seeds=1,2", "--region=-1,-1", "--out=C:/r5-evidence"])).is_valid, "V10 valid CLI")
	check(Maps.holdout_rows(0).size() == 8 and Maps.holdout_rows(3)[7][0] == 3000017 + 104729 * 31, "V10 holdout rows fixed")
	for fixture: Array in [["--seed=x", "ERR_ROUTE_CLI_SEED"], ["--region=1,2,3", "ERR_ROUTE_CLI_REGION"], ["--environment=routes", "ERR_ROUTE_CLI_MODE"], ["--sweep=1", "ERR_ROUTE_CLI_ARGUMENT"]]:
		check(Captures.parse_options(PackedStringArray([fixture[0], "--out=C:/r5-evidence"])).reason_code == fixture[1], "V10 capture CLI " + fixture[0])
	check(Captures.parse_options(PackedStringArray(["--seed=1"])).reason_code == "ERR_ROUTE_CLI_OUTPUT", "V10 capture requires output")
	check(Captures.parse_options(PackedStringArray(["--seed=1", "--environment=rideability", "--out=C:/r5-evidence"])).is_valid, "V10 capture valid CLI")
