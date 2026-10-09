class_name RouteSearch
extends RefCounted

## R5 traversal cost model and deterministic path search (ExecPlan §7).
## Pure functions over the plan-local kernel grid (RoutePlanningRaster.grid()
## or a controlled dictionary of the same shape): geometry follows plausible
## traversal cost only. There are no interest bonuses, negative costs or
## wiggle rules here; journey purpose lives in RoutePlanner/RouteJourneyScoring.
##
## move cost = L * G^ground * A(g_along) * (1 + cut_fill * g_cross) * V  (* S)  + X
##   G        mean R4 natural ground cost of the move's nodes (>= 1)
##   A        1 + (g/g_pref)^2 up to g_max; above it a developing class pays
##            for the extra length a traversing road needs (DEVELOPMENT flag),
##            a non-developing class may not move
##   g_cross  terrain gradient across the move: the cut/fill estimate
##   V        backbone valley-road affinity
##   S        separation from the existing network (per search, >= 1)
##   X        recorded water crossing cost (hint/width/angle); bodies forbidden
## Every multiplier is >= 1 and X >= 0, so Euclidean distance is an admissible
## and consistent A* heuristic.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const MODEL := "search/1;profiles=.06:.10:1.3:3:.6,.09:.15:1:2:0,.14:.22:.8:1:0,.22:.38:.5:.5:0;develop=all:1.1;hint=60,200,500;width=4;oblique=60"
const DIRECTIONS: int = 16
## Alpha starting values (ExecPlan §7 table), indexed by RouteClass.
const PROFILES: Array[Dictionary] = [
	{"g_pref": 0.06, "g_max": 0.10, "develop": true, "ground": 1.3, "cut_fill": 3.0, "valley": 0.6, "half_width_m": 40.0},
	{"g_pref": 0.09, "g_max": 0.15, "develop": true, "ground": 1.0, "cut_fill": 2.0, "valley": 0.0, "half_width_m": 50.0},
	{"g_pref": 0.14, "g_max": 0.22, "develop": true, "ground": 0.8, "cut_fill": 1.0, "valley": 0.0, "half_width_m": 35.0},
	{"g_pref": 0.22, "g_max": 0.38, "develop": true, "ground": 0.5, "cut_fill": 0.5, "valley": 0.0, "half_width_m": 25.0},
]
## Slightly cheaper than node-level zig-zagging, so steep corridors stay direct
## and carry DEVELOPMENT_REQUIRED for R6 instead of fake 32 m switchbacks.
const DEVELOPMENT_OVERHEAD: float = 1.1
const HINT_COST_M: Array[float] = [60.0, 200.0, 500.0]
const CROSSING_WIDTH_COST: float = 4.0
const OBLIQUE_DEG: float = 60.0


## Likely engineering class of one recorded crossing (approval condition 4:
## an Alpha planning heuristic, not a world contract).
static func crossing_hint(record: Dictionary) -> int:
	if record.class == Graph.WaterKind.MAJOR_RIVER or record.width_m > 8.0:
		return Graph.Hint.BRIDGE
	if record.width_m > 4.0 or record.surface_m - record.bed_m >= 0.35:
		return Graph.Hint.SMALL_BRIDGE
	return Graph.Hint.FORD


## Additive crossing cost for a class, INF when a body is crossed or a hint is
## not allowed for the class.
static func crossing_cost(result: Dictionary, route_class: int) -> float:
	if not result.body_ids.is_empty():
		return INF
	var total: float = 0.0
	for record: Dictionary in result.crossings:
		var hint: int = crossing_hint(record)
		if not hint in Graph.ALLOWED_HINTS[route_class]:
			return INF
		total += HINT_COST_M[hint] + CROSSING_WIDTH_COST * record.width_m
		if record.angle_deg < OBLIQUE_DEG:
			total += HINT_COST_M[hint] * (OBLIQUE_DEG - record.angle_deg) / OBLIQUE_DEG
	return total


## Grade factor A(g) and whether the move needs development (INF = forbidden).
static func grade_factor(profile: Dictionary, grade: float) -> Vector2:
	var g_pref: float = profile.g_pref
	var g_max: float = profile.g_max
	if grade <= g_max:
		return Vector2(1.0 + (grade / g_pref) * (grade / g_pref), 0.0)
	if not profile.develop:
		return Vector2(INF, 1.0)
	return Vector2((1.0 + (g_max / g_pref) * (g_max / g_pref)) * (grade / g_max) * DEVELOPMENT_OVERHEAD, 1.0)


## Base (separation-free, crossing-free) cost of a straight move between two
## grid nodes, using the given helper nodes for ground resistance.
static func base_cost(g: Dictionary, profile: Dictionary, a: int, b: int, helpers: PackedInt32Array) -> float:
	var n: int = g.n
	var delta := Vector2((b % n) - (a % n), (b / n) - (a / n))
	var length: float = delta.length() * g.spacing
	var ground: float = g.cost[a] + g.cost[b]
	for h: int in helpers:
		ground += g.cost[h]
	ground /= 2.0 + helpers.size()
	var grade: float = absf(g.height[b] - g.height[a]) / length
	var factor: Vector2 = grade_factor(profile, grade)
	if factor.x == INF:
		return INF
	var direction: Vector2 = delta.normalized()
	var gx: float = 0.5 * (g.grad_x[a] + g.grad_x[b])
	var gz: float = 0.5 * (g.grad_z[a] + g.grad_z[b])
	var cross: float = absf(gx * direction.y - gz * direction.x)
	var valley: float = 1.0 + profile.valley * (1.0 - 0.5 * (g.valley[a] + g.valley[b]))
	return length * pow(ground, profile.ground) * factor.x * (1.0 + profile.cut_fill * cross) * valley


## Static per-class move tables: `base` (NODES*16, INF = forbidden) and the
## additive crossing cost `extra`. `passable` marks standing nodes for the run.
static func build_tables(g: Dictionary, route_class: int, passable: PackedByteArray) -> Dictionary:
	var profile: Dictionary = PROFILES[route_class]
	var n: int = g.n
	var count: int = n * n
	var base := PackedFloat64Array()
	var extra := PackedFloat64Array()
	base.resize(count * DIRECTIONS)
	extra.resize(count * DIRECTIONS)
	base.fill(INF)
	var water: PackedByteArray = g.water
	var blocked: PackedByteArray = g.blocked
	var crossings: Dictionary = g.move_crossings
	var off: Dictionary = offsets(n)
	for k in range(count):
		if passable[k] == 0:
			continue
		var i: int = k % n
		var j: int = k / n
		for d in range(DIRECTIONS):
			var step: Vector2i = Raster.DIRS[d]
			var ti: int = i + step.x
			var tj: int = j + step.y
			if ti < 0 or tj < 0 or ti >= n or tj >= n:
				continue
			var t: int = tj * n + ti
			if passable[t] == 0:
				continue
			var helpers := PackedInt32Array()
			if d >= 4:
				helpers.append(k + off.swept_a[d])
				helpers.append(k + off.swept_b[d])
				if water[helpers[0]] == 1 or blocked[helpers[0]] == 1 or water[helpers[1]] == 1 or blocked[helpers[1]] == 1:
					continue
			var cost: float = base_cost(g, profile, k, t, helpers)
			if cost == INF:
				continue
			var key: int = Raster.pair_key(k, t)
			if crossings.has(key):
				var x: float = crossing_cost(crossings[key], route_class)
				if x == INF:
					continue
				extra[k * DIRECTIONS + d] = x
			base[k * DIRECTIONS + d] = cost
	return {"base": base, "extra": extra, "class": route_class}


## Cost of a recorded water jump (no separation), INF if not allowed.
static func jump_cost(g: Dictionary, route_class: int, a: int, b: int) -> float:
	var key: int = Raster.pair_key(a, b)
	if not g.move_crossings.has(key):
		return INF
	var x: float = crossing_cost(g.move_crossings[key], route_class)
	if x == INF:
		return INF
	var cost: float = base_cost(g, PROFILES[route_class], a, b, PackedInt32Array())
	return INF if cost == INF else cost + x


## Per-grid neighbour and swept-node index offsets (no per-move allocation).
static func offsets(n: int) -> Dictionary:
	var step := PackedInt32Array()
	var swept_a := PackedInt32Array()
	var swept_b := PackedInt32Array()
	for d in range(DIRECTIONS):
		var dir: Vector2i = Raster.DIRS[d]
		step.append(dir.y * n + dir.x)
		var cells: Array[Vector2i] = Raster.swept(0, 0, dir)
		swept_a.append(cells[0].y * n + cells[0].x if cells.size() > 0 else 0)
		swept_b.append(cells[1].y * n + cells[1].x if cells.size() > 1 else 0)
	return {"step": step, "swept_a": swept_a, "swept_b": swept_b}


static func direction_index(a: int, b: int, n: int) -> int:
	var step := Vector2i((b % n) - (a % n), (b / n) - (a / n))
	return Raster.DIRS.find(step)


## Separation-free cost of a node path under the class tables (INF if any step
## is forbidden). Without `crossings` the water-crossing additive is left out
## (riding effort only; crossings are engineering, recorded separately).
static func path_cost(g: Dictionary, tables: Dictionary, path: PackedInt32Array, crossings: bool = true) -> float:
	var total: float = 0.0
	var n: int = g.n
	for m in range(1, path.size()):
		var d: int = direction_index(path[m - 1], path[m], n)
		var step: float
		if d < 0:
			step = jump_cost(g, tables.class, path[m - 1], path[m]) if crossings else base_cost(g, PROFILES[tables.class], path[m - 1], path[m], PackedInt32Array())
		else:
			step = tables.base[path[m - 1] * DIRECTIONS + d] + (tables.extra[path[m - 1] * DIRECTIONS + d] if crossings else 0.0)
		if step == INF:
			return INF
		total += step
	return total


## Binary min-heap of (float64 key, node); ties by node index. `pop` returns
## the node and leaves its exact key in `popped_key` (no float32 rounding).
class _Heap:
	var keys := PackedFloat64Array()
	var nodes := PackedInt32Array()
	var popped_key: float = 0.0

	func _less(a: int, b: int) -> bool:
		return keys[a] < keys[b] or (keys[a] == keys[b] and nodes[a] < nodes[b])

	func push(key: float, node: int) -> void:
		keys.append(key)
		nodes.append(node)
		var c: int = keys.size() - 1
		while c > 0:
			var p: int = (c - 1) / 2
			if not _less(c, p):
				break
			_swap(c, p)
			c = p

	func _swap(a: int, b: int) -> void:
		var k: float = keys[a]
		keys[a] = keys[b]
		keys[b] = k
		var n: int = nodes[a]
		nodes[a] = nodes[b]
		nodes[b] = n

	func pop() -> int:
		popped_key = keys[0]
		var result: int = nodes[0]
		var last: int = keys.size() - 1
		_swap(0, last)
		keys.resize(last)
		nodes.resize(last)
		var c: int = 0
		while true:
			var l: int = 2 * c + 1
			var r: int = l + 1
			var m: int = c
			if l < last and _less(l, m):
				m = l
			if r < last and _less(r, m):
				m = r
			if m == c:
				break
			_swap(c, m)
			c = m
		return result

	func is_empty() -> bool:
		return keys.is_empty()


## Deterministic A* (goal >= 0) or multi-target Dijkstra (goal < 0, `targets`
## mask). `sep` (per node, >= 1) multiplies base move cost by the mean of its
## end nodes. `closed_extra` marks nodes this run may not enter or squeeze past
## unless they are targets (e.g. existing network away from attach points).
## Ties break on node index. Returns {found, path, cost, expanded}.
static func search(g: Dictionary, tables: Dictionary, sep: PackedFloat64Array, sources: PackedInt32Array, targets: PackedByteArray, goal: int, closed_extra: PackedByteArray, max_cost: float) -> Dictionary:
	var n: int = g.n
	var count: int = n * n
	var spacing: float = g.spacing
	var base: PackedFloat64Array = tables.base
	var extra: PackedFloat64Array = tables.extra
	var jumps: Dictionary = g.jumps
	var off: Dictionary = offsets(n)
	var step_off: PackedInt32Array = off.step
	var swept_a: PackedInt32Array = off.swept_a
	var swept_b: PackedInt32Array = off.swept_b
	var dist := PackedFloat64Array()
	dist.resize(count)
	dist.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-1)
	var closed := PackedByteArray()
	closed.resize(count)
	var heap := _Heap.new()
	var gi: int = goal % n if goal >= 0 else 0
	var gj: int = goal / n if goal >= 0 else 0
	for s: int in sources:
		dist[s] = 0.0
		var h: float = 0.0 if goal < 0 else spacing * Vector2(s % n - gi, s / n - gj).length()
		heap.push(h, s)
	var expanded: int = 0
	var found: int = -1
	while not heap.is_empty():
		var k: int = heap.pop()
		if closed[k] == 1:
			continue
		if heap.popped_key > max_cost:
			break
		closed[k] = 1
		expanded += 1
		if (goal >= 0 and k == goal) or (goal < 0 and targets[k] == 1):
			found = k
			break
		var dk: float = dist[k]
		var row: int = k * DIRECTIONS
		for d in range(DIRECTIONS):
			var c: float = base[row + d]
			if c == INF:
				continue
			var t: int = k + step_off[d]
			if closed[t] == 1:
				continue
			if closed_extra[t] == 1 and not (t == goal or (goal < 0 and targets[t] == 1)):
				continue
			if d >= 4:
				var sa: int = k + swept_a[d]
				var sb: int = k + swept_b[d]
				if (closed_extra[sa] == 1 and not (sa == goal or (goal < 0 and targets[sa] == 1))) or (closed_extra[sb] == 1 and not (sb == goal or (goal < 0 and targets[sb] == 1))):
					continue
			var nd: float = dk + c * 0.5 * (sep[k] + sep[t]) + extra[row + d]
			if nd < dist[t]:
				dist[t] = nd
				parent[t] = k
				var h: float = 0.0
				if goal >= 0:
					var dx: float = (t % n) - gi
					var dz: float = (t / n) - gj
					h = spacing * sqrt(dx * dx + dz * dz)
				heap.push(nd + h, t)
		if jumps.has(k):
			for t: int in jumps[k]:
				if closed[t] == 1:
					continue
				var is_target: bool = (goal >= 0 and t == goal) or (goal < 0 and targets[t] == 1)
				if closed_extra[t] == 1 and not is_target:
					continue
				var jc: float = jump_cost(g, tables.class, k, t)
				if jc == INF:
					continue
				var nd: float = dk + jc * 0.5 * (sep[k] + sep[t])
				if nd < dist[t]:
					dist[t] = nd
					parent[t] = k
					var h: float = 0.0 if goal < 0 else spacing * Vector2((t % n) - gi, (t / n) - gj).length()
					heap.push(nd + h, t)
	if found < 0:
		return {"found": false, "path": PackedInt32Array(), "cost": INF, "expanded": expanded}
	var path := PackedInt32Array()
	var at: int = found
	while at >= 0:
		path.append(at)
		at = parent[at]
	path.reverse()
	return {"found": true, "path": path, "cost": dist[found], "expanded": expanded}
