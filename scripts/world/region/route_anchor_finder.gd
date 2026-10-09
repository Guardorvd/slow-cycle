class_name RouteAnchorFinder
extends RefCounted

## R5 geographic anchors (ExecPlan §6): planning reasons for a route to go
## somewhere. Not landmarks, vistas, destinations or gameplay objects; no
## visibility is computed. R1/R3/R4 descriptors only seed a local search;
## acceptance always depends on the sampled planning raster. Passes are
## located topographically (R1-D2): the lowest node of the highest ridge path
## between adjacent crest summits, the descriptor saddle only bounding the
## search window.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const Search = preload("res://scripts/world/region/route_search.gd")
const MODEL := "anchors/2;gateway=384:.3;reach=512:40-160;tributary=600;head=500:.25;pass_window=400;shoulder=150:.35;bench=.15:.08-.5;meadow=12:6;lake=4:64;duplicate=160"
const N: int = Raster.N
const SPACING: float = Raster.SPACING_M
const EDGE_MARGIN_M: float = 64.0
const DUPLICATE_M: float = 160.0
const GATEWAY_RADIUS_M: float = 384.0
## Minimum valley-floor weight of a gateway node. Part of acceptance, so the
## best-scoring node is chosen among valley-floor nodes only.
const GATEWAY_VALLEY: float = 0.3
## Alpha anchor values used by journey scoring (ExecPlan §6).
const VALUES := {
	Graph.AnchorKind.GATEWAY: 0.0, Graph.AnchorKind.RIVER_REACH: 0.5, Graph.AnchorKind.SIDE_VALLEY_MOUTH: 0.5,
	Graph.AnchorKind.SIDE_VALLEY_HEAD: 0.8, Graph.AnchorKind.PASS: 1.2, Graph.AnchorKind.SHOULDER: 0.9,
	Graph.AnchorKind.SPUR_NOSE: 0.4, Graph.AnchorKind.BENCH: 0.8, Graph.AnchorKind.UPLAND_BASIN: 1.0,
	Graph.AnchorKind.MEADOW: 0.6, Graph.AnchorKind.LAKE_SHORE: 0.8, Graph.AnchorKind.AUTUMN_POCKET: 0.7,
}

var _raster: Raster
var _symmetry: int
var _candidates: Array = []


## Finder bound to one planning raster (also used for direct topographic
## queries such as `topographic_saddle` and `usable`).
static func with_raster(raster: Raster, symmetry: int = 0) -> RouteAnchorFinder:
	var finder := RouteAnchorFinder.new()
	finder._raster = raster
	finder._symmetry = symmetry
	return finder


static func find(raster: Raster, macro_data: Dictionary, hydrology_plan: RefCounted, biome_descriptor: Dictionary) -> Array:
	var finder: RouteAnchorFinder = with_raster(raster, macro_data.frame_symmetry)
	finder._gateways(hydrology_plan)
	finder._river_reaches(hydrology_plan)
	finder._side_valleys(hydrology_plan)
	finder._passes(macro_data)
	finder._spurs(macro_data)
	finder._benches(macro_data)
	finder._basins(macro_data)
	finder._meadows()
	finder._lakes(hydrology_plan)
	finder._autumn(biome_descriptor)
	return finder._resolve()


func _frame_node(u: float, v: float) -> int:
	var local: Vector2 = Macro.frame_to_local(_symmetry, u, v)
	return Raster.index_of(local.x, local.y)


## Standing node usable by a route (dry, not a natural barrier, inside margin).
func usable(k: int, margin: bool = true) -> bool:
	return _raster.water[k] == 0 and _raster.blocked[k] == 0 and _raster.body[k] < 0 and (not margin or _raster.edge_dist[k] >= EDGE_MARGIN_M)


func _add(kind: int, node: int, source: String, reason: String = "", hint: Vector2 = Vector2(-1, -1)) -> void:
	var position: Vector2 = Raster.local_of(node) if node >= 0 else hint
	_candidates.append({"kind": kind, "node": node, "x_cm": roundi(position.x * 100.0), "z_cm": roundi(position.y * 100.0),
		"elevation_cm": roundi(_raster.height[node] * 100.0) if node >= 0 else 0, "source": source, "reason_code": reason})


## Best node by `score` (lower is better; ties by index) within radius of p.
func _best_near(p: Vector2, radius: float, accept: Callable, score: Callable) -> int:
	var best: int = -1
	var best_score: float = INF
	var r: int = ceili(radius / SPACING)
	var ci: int = clampi(roundi(p.x / SPACING), 0, N - 1)
	var cj: int = clampi(roundi(p.y / SPACING), 0, N - 1)
	for j in range(maxi(0, cj - r), mini(N - 1, cj + r) + 1):
		for i in range(maxi(0, ci - r), mini(N - 1, ci + r) + 1):
			var k: int = j * N + i
			if Raster.local_of(k).distance_to(p) > radius or not accept.call(k):
				continue
			var s: float = score.call(k)
			if s < best_score:
				best_score = s
				best = k
	return best


## Gateway acceptance for river exit p on one bank (side -1 left, 1 right of
## the inward direction): dry, non-blocked region-boundary node 40-384 m from
## the exit on the valley floor.
func gateway_eligible(k: int, p: Vector2, inward: Vector2, side: int) -> bool:
	var q: Vector2 = Raster.local_of(k)
	var d: float = q.distance_to(p)
	return _raster.edge_dist[k] == 0.0 and usable(k, false) and signf(inward.cross(q - p)) == side and d >= 40.0 and d <= GATEWAY_RADIUS_M and _raster.valley[k] >= GATEWAY_VALLEY


func _gateways(hydrology_plan: RefCounted) -> void:
	var river: Dictionary = hydrology_plan.get_channel(0)
	var last: int = river.x_cm.size() - 1
	for end: Array in [[0, 1, "upstream"], [last, last - 1, "downstream"]]:
		var p := Vector2(river.x_cm[end[0]], river.z_cm[end[0]]) / 100.0
		var inward := (Vector2(river.x_cm[end[1]], river.z_cm[end[1]]) / 100.0 - p).normalized()
		for side: int in [-1, 1]:
			var accept := func(k: int) -> bool:
				return gateway_eligible(k, p, inward, side)
			var score := func(k: int) -> float:
				return _raster.cost[k] + 3.0 * maxf(0.0, 0.5 - _raster.valley[k]) + 0.002 * absf(Raster.local_of(k).distance_to(p) - 100.0)
			var node: int = _best_near(p, GATEWAY_RADIUS_M, accept, score)
			var name: String = "hydro.channel[0].%s.%s" % [end[2], "left" if side < 0 else "right"]
			if node >= 0:
				_add(Graph.AnchorKind.GATEWAY, node, name)
			else:
				_add(Graph.AnchorKind.GATEWAY, -1, name, "ANCHOR_BLOCKED", p)


func _river_reaches(hydrology_plan: RefCounted) -> void:
	var river: Dictionary = hydrology_plan.get_channel(0)
	var stations: PackedInt64Array = river.station_cm
	var total: float = stations[stations.size() - 1] - stations[0]
	var s: float = 38400.0
	while s <= total - 38400.0:
		var at: Dictionary = Hydro.point_at_station(river, stations[0] + s)
		var ahead: Dictionary = Hydro.point_at_station(river, stations[0] + minf(s + 3200.0, total))
		var p := Vector2(at.x, at.z) / 100.0
		var tangent: Vector2 = (Vector2(ahead.x, ahead.z) / 100.0 - p).normalized()
		for side: int in [-1, 1]:
			var normal: Vector2 = Vector2(-tangent.y, tangent.x) * side
			var node: int = -1
			var reason: String = "ANCHOR_WATER"
			var d: float = 24.0
			while d <= 192.0:
				var k: int = Raster.index_of(p.x + normal.x * d, p.y + normal.y * d)
				if usable(k) and _raster.water_dist[k] >= 40.0 and _raster.travel_class[k] <= 1:
					node = k
					break
				if _raster.blocked[k] == 1:
					reason = "ANCHOR_BLOCKED"
				d += 16.0
			var name: String = "hydro.river@%dm.%s" % [roundi(s / 100.0), "left" if side < 0 else "right"]
			if node >= 0:
				_add(Graph.AnchorKind.RIVER_REACH, node, name)
			else:
				_add(Graph.AnchorKind.RIVER_REACH, -1, name, reason, p + normal * 96.0)
		s += 51200.0


func _side_valleys(hydrology_plan: RefCounted) -> void:
	for c in range(1, hydrology_plan.get_channel_count()):
		var channel: Dictionary = hydrology_plan.get_channel(c)
		var stations: PackedInt64Array = channel.station_cm
		var last: int = stations.size() - 1
		if channel.parent != 0 or stations[last] - stations[0] < 60000:
			continue
		var mouth := Vector2(channel.x_cm[last], channel.z_cm[last]) / 100.0
		var nearest := func(k: int) -> float: return Raster.local_of(k).distance_to(mouth) + 10.0 * _raster.cost[k]
		var node: int = _best_near(mouth, 96.0, func(k: int) -> bool: return usable(k), nearest)
		if node >= 0:
			_add(Graph.AnchorKind.SIDE_VALLEY_MOUTH, node, "hydro.channel[%d].mouth" % c)
		else:
			_add(Graph.AnchorKind.SIDE_VALLEY_MOUTH, -1, "hydro.channel[%d].mouth" % c, "ANCHOR_BLOCKED", mouth)
		var head: int = -1
		for k in range(last + 1):
			if stations[last] - stations[k] < 50000:
				break
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var candidate: int = _best_near(p, 64.0, func(m: int) -> bool: return usable(m) and _raster.slope[m] <= 0.25, func(m: int) -> float: return Raster.local_of(m).distance_to(p))
			if candidate >= 0:
				head = candidate
				break
		if head >= 0:
			_add(Graph.AnchorKind.SIDE_VALLEY_HEAD, head, "hydro.channel[%d].head" % c)
		else:
			_add(Graph.AnchorKind.SIDE_VALLEY_HEAD, -1, "hydro.channel[%d].head" % c, "ANCHOR_BLOCKED", Vector2(channel.x_cm[0], channel.z_cm[0]) / 100.0)


## Highest ridge path (maximin height) between two nodes inside a window; the
## pass is its lowest interior node.
func topographic_saddle(a: int, b: int, window: Rect2i) -> int:
	var best := PackedFloat64Array()
	best.resize(N * N)
	best.fill(-INF)
	var parent := PackedInt32Array()
	parent.resize(N * N)
	parent.fill(-1)
	var done := PackedByteArray()
	done.resize(N * N)
	best[a] = _raster.height[a]
	var heap = Search._Heap.new()
	heap.push(-best[a], a)
	while not heap.is_empty():
		var k: int = heap.pop()
		if done[k] == 1:
			continue
		done[k] = 1
		if k == b:
			break
		var i: int = k % N
		var j: int = k / N
		for d in range(8):
			var step: Vector2i = Raster.DIRS[d]
			var t := Vector2i(i + step.x, j + step.y)
			if not window.has_point(t):
				continue
			var tk: int = t.y * N + t.x
			if done[tk] == 1:
				continue
			var value: float = minf(best[k], _raster.height[tk])
			if value > best[tk]:
				best[tk] = value
				parent[tk] = k
				heap.push(-value, tk)
	if done[b] == 0:
		return -1
	var low: int = -1
	var at: int = parent[b]
	while at >= 0 and at != a:
		if low < 0 or _raster.height[at] < _raster.height[low] or (_raster.height[at] == _raster.height[low] and at < low):
			low = at
		at = parent[at]
	return low


func _passes(macro_data: Dictionary) -> void:
	for group: String in ["main_nodes", "far_nodes"]:
		var nodes: Array = macro_data[group]
		for k in range(1, nodes.size() - 1):
			if nodes[k].kind != Macro.NODE_SADDLE:
				continue
			var a: int = _frame_node(nodes[k - 1].u_m, nodes[k - 1].v_m)
			var b: int = _frame_node(nodes[k + 1].u_m, nodes[k + 1].v_m)
			var hint: int = _frame_node(nodes[k].u_m, nodes[k].v_m)
			var lo := Vector2i(mini(mini(a % N, b % N), hint % N), mini(mini(a / N, b / N), hint / N)) - Vector2i(13, 13)
			var hi := Vector2i(maxi(maxi(a % N, b % N), hint % N), maxi(maxi(a / N, b / N), hint / N)) + Vector2i(13, 13)
			var window := Rect2i(lo, hi - lo + Vector2i.ONE).intersection(Rect2i(0, 0, N, N))
			var saddle: int = topographic_saddle(a, b, window)
			var name: String = "macro.%s[%d]" % [group, k]
			if saddle < 0:
				_add(Graph.AnchorKind.PASS, -1, name, "PASS_NOT_TOPOGRAPHIC", Raster.local_of(hint))
				continue
			var node: int = saddle
			if not usable(node):
				var level: float = _raster.height[saddle]
				node = _best_near(Raster.local_of(saddle), 64.0, func(m: int) -> bool: return usable(m) and absf(_raster.height[m] - level) <= 10.0, func(m: int) -> float: return Raster.local_of(m).distance_to(Raster.local_of(saddle)))
			if node < 0:
				_add(Graph.AnchorKind.PASS, -1, name, "ANCHOR_EDGE_MARGIN" if _raster.edge_dist[saddle] < EDGE_MARGIN_M else "ANCHOR_BLOCKED", Raster.local_of(saddle))
			else:
				_add(Graph.AnchorKind.PASS, node, name + ";offset_m=%d" % roundi(Raster.local_of(node).distance_to(Raster.local_of(hint))))


func _spurs(macro_data: Dictionary) -> void:
	var spurs: Array = macro_data.spurs
	for k in range(spurs.size()):
		var spur: Dictionary = spurs[k]
		var middle: Vector2 = Macro.frame_to_local(_symmetry, spur.mu_m, spur.mv_m)
		var shoulder: int = _best_near(middle, 150.0, func(m: int) -> bool: return usable(m) and _raster.slope[m] <= 0.35, func(m: int) -> float: return -_raster.height[m])
		if shoulder >= 0:
			_add(Graph.AnchorKind.SHOULDER, shoulder, "macro.spurs[%d].middle" % k)
		else:
			_add(Graph.AnchorKind.SHOULDER, -1, "macro.spurs[%d].middle" % k, "ANCHOR_BLOCKED", middle)
		if spur.group != Macro.GROUP_MAIN or spur.kind != Macro.SPUR_VALLEY:
			continue
		var nose_point: Vector2 = Macro.frame_to_local(_symmetry, spur.bu_m, spur.bv_m)
		var nose: int = _best_near(nose_point, 96.0, func(m: int) -> bool: return usable(m), func(m: int) -> float: return Raster.local_of(m).distance_to(nose_point))
		if nose >= 0:
			_add(Graph.AnchorKind.SPUR_NOSE, nose, "macro.spurs[%d].end" % k)
		else:
			_add(Graph.AnchorKind.SPUR_NOSE, -1, "macro.spurs[%d].end" % k, "ANCHOR_BLOCKED", nose_point)


func _benches(macro_data: Dictionary) -> void:
	var benches: Array = macro_data.benches
	for k in range(benches.size()):
		var bench: Dictionary = benches[k]
		var run: Array = []
		var best_run: Array = []
		var u: float = bench.u_a_m + 250.0
		while u <= bench.u_b_m - 250.0:
			var axis: float = Macro.valley_axis(macro_data, u).x
			var found: int = -1
			var offset: float = 96.0
			while offset <= 1000.0:
				var k_node: int = _frame_node(u, axis + bench.side * offset)
				if usable(k_node) and _raster.slope[k_node] <= 0.15 and _raster.rel_elev[k_node] >= 0.08 and _raster.rel_elev[k_node] <= 0.5 and _raster.valley[k_node] < 0.3:
					found = k_node
					break
				offset += 32.0
			if found >= 0:
				run.append(found)
				if run.size() > best_run.size():
					best_run = run.duplicate()
			else:
				run.clear()
			u += 64.0
		var hint: Vector2 = Macro.frame_to_local(_symmetry, 0.5 * (bench.u_a_m + bench.u_b_m), Macro.valley_axis(macro_data, 0.5 * (bench.u_a_m + bench.u_b_m)).x + bench.side * 300.0)
		if best_run.size() >= 3:
			_add(Graph.AnchorKind.BENCH, best_run[best_run.size() / 2], "macro.benches[%d];run_m=%d" % [k, best_run.size() * 64])
		else:
			_add(Graph.AnchorKind.BENCH, -1, "macro.benches[%d]" % k, "BENCH_NOT_FOUND", hint)


func _basins(macro_data: Dictionary) -> void:
	var basins: Array = macro_data.basins
	for k in range(basins.size()):
		var basin: Dictionary = basins[k]
		var centre: Vector2 = Macro.frame_to_local(_symmetry, basin.u_m, basin.v_m)
		var node: int = _best_near(centre, basin.radius_m, func(m: int) -> bool: return usable(m), func(m: int) -> float: return _raster.slope[m] - 0.05 * _raster.meadow[m])
		if node >= 0:
			_add(Graph.AnchorKind.UPLAND_BASIN, node, "macro.basins[%d]" % k)
		else:
			_add(Graph.AnchorKind.UPLAND_BASIN, -1, "macro.basins[%d]" % k, "ANCHOR_BLOCKED", centre)


func _meadows() -> void:
	var member := PackedByteArray()
	member.resize(N * N)
	for k in range(N * N):
		member[k] = 1 if usable(k) and _raster.travel_class[k] == 0 and _raster.biome[k] == 1 else 0
	var label := PackedInt32Array()
	label.resize(N * N)
	label.fill(-1)
	var components: Array = []
	for start in range(N * N):
		if member[start] == 0 or label[start] >= 0:
			continue
		var cells := PackedInt32Array([start])
		label[start] = components.size()
		var head: int = 0
		while head < cells.size():
			var k: int = cells[head]
			head += 1
			for d in range(8):
				var step: Vector2i = Raster.DIRS[d]
				var i: int = k % N + step.x
				var j: int = k / N + step.y
				if i < 0 or j < 0 or i >= N or j >= N:
					continue
				var t: int = j * N + i
				if member[t] == 1 and label[t] < 0:
					label[t] = components.size()
					cells.append(t)
		components.append(cells)
	var ranked: Array = []
	for c in range(components.size()):
		if components[c].size() >= 12:
			ranked.append(c)
	ranked.sort_custom(func(x: int, y: int) -> bool: return components[x].size() > components[y].size() or (components[x].size() == components[y].size() and x < y))
	for r in range(mini(6, ranked.size())):
		var cells: PackedInt32Array = components[ranked[r]]
		# Most interior member: farthest (grid steps) from any non-member.
		var depth := {}
		var queue: Array = []
		for k: int in cells:
			for d in range(4):
				var step: Vector2i = Raster.DIRS[d]
				var i: int = k % N + step.x
				var j: int = k / N + step.y
				if i < 0 or j < 0 or i >= N or j >= N or label[j * N + i] != ranked[r]:
					depth[k] = 0
					queue.append(k)
					break
		var head: int = 0
		while head < queue.size():
			var k: int = queue[head]
			head += 1
			for d in range(4):
				var step: Vector2i = Raster.DIRS[d]
				var i: int = k % N + step.x
				var j: int = k / N + step.y
				if i < 0 or j < 0 or i >= N or j >= N:
					continue
				var t: int = j * N + i
				if label[t] == ranked[r] and not depth.has(t):
					depth[t] = depth[k] + 1
					queue.append(t)
		var best: int = cells[0]
		for k: int in cells:
			if depth.get(k, 0) > depth.get(best, 0) or (depth.get(k, 0) == depth.get(best, 0) and k < best):
				best = k
		_add(Graph.AnchorKind.MEADOW, best, "raster.meadow[%d];nodes=%d" % [r, cells.size()])


func _lakes(hydrology_plan: RefCounted) -> void:
	for b in range(hydrology_plan.get_body_count()):
		var cells: PackedInt32Array = hydrology_plan.get_body(b).cells
		if cells.size() < 4:
			continue
		var best: int = -1
		for cell: int in cells:
			var candidate: int = _best_near(Raster.local_of(cell), 64.0, func(m: int) -> bool: return usable(m), func(m: int) -> float: return _raster.cost[m] + 0.0001 * m)
			if candidate >= 0 and (best < 0 or _raster.cost[candidate] < _raster.cost[best] or (_raster.cost[candidate] == _raster.cost[best] and candidate < best)):
				best = candidate
		if best >= 0:
			_add(Graph.AnchorKind.LAKE_SHORE, best, "hydro.body[%d];cells=%d" % [b, cells.size()])
		else:
			_add(Graph.AnchorKind.LAKE_SHORE, -1, "hydro.body[%d]" % b, "ANCHOR_BLOCKED", Raster.local_of(cells[0]))


func _autumn(descriptor: Dictionary) -> void:
	var pocket: Dictionary = descriptor.get("pocket", {})
	if not pocket.get("is_present", false):
		return
	var centre: Vector2 = Macro.frame_to_local(_symmetry, pocket.u_m, pocket.v_m)
	var node: int = _best_near(centre, 300.0, func(m: int) -> bool: return usable(m) and _raster.biome[m] == 3, func(m: int) -> float: return _raster.cost[m] + 0.001 * Raster.local_of(m).distance_to(centre))
	if node >= 0:
		_add(Graph.AnchorKind.AUTUMN_POCKET, node, "biome.pocket")
	else:
		_add(Graph.AnchorKind.AUTUMN_POCKET, -1, "biome.pocket", "ANCHOR_BLOCKED", centre)


## Margin and duplicate resolution, then stable ids in (kind, source order).
func _resolve() -> Array:
	for candidate: Dictionary in _candidates:
		if candidate.node >= 0 and candidate.kind != Graph.AnchorKind.GATEWAY and _raster.edge_dist[candidate.node] < EDGE_MARGIN_M:
			candidate.reason_code = "ANCHOR_EDGE_MARGIN"
	var order: Array = range(_candidates.size())
	order.sort_custom(func(x: int, y: int) -> bool:
		var vx: float = VALUES[_candidates[x].kind]
		var vy: float = VALUES[_candidates[y].kind]
		return vx > vy or (vx == vy and (_candidates[x].kind < _candidates[y].kind or (_candidates[x].kind == _candidates[y].kind and x < y))))
	var accepted: Array = []
	for index: int in order:
		var candidate: Dictionary = _candidates[index]
		if candidate.node < 0 or not candidate.reason_code.is_empty() or candidate.kind == Graph.AnchorKind.GATEWAY:
			continue
		var p: Vector2 = Raster.local_of(candidate.node)
		for other: int in accepted:
			if Raster.local_of(_candidates[other].node).distance_to(p) < DUPLICATE_M:
				candidate.reason_code = "ANCHOR_DUPLICATE"
				break
		if candidate.reason_code.is_empty():
			accepted.append(index)
	var stable: Array = range(_candidates.size())
	stable.sort_custom(func(x: int, y: int) -> bool: return _candidates[x].kind < _candidates[y].kind or (_candidates[x].kind == _candidates[y].kind and x < y))
	var result: Array = []
	for index: int in stable:
		var candidate: Dictionary = _candidates[index]
		var ok: bool = candidate.node >= 0 and candidate.reason_code.is_empty()
		result.append({"id": result.size(), "kind": candidate.kind, "node": candidate.node if ok else -1, "x_cm": candidate.x_cm, "z_cm": candidate.z_cm, "elevation_cm": candidate.elevation_cm,
			"source": candidate.source, "status": Graph.AnchorStatus.UNUSED if ok else Graph.AnchorStatus.REJECTED, "reason_code": candidate.reason_code, "value": VALUES[candidate.kind]})
	return result
