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
##   P        optional per-class feedback penalty (R6 -> R5 hints, >= 1)
## Every multiplier is >= 1 and X >= 0, so Euclidean distance is an admissible
## and consistent A* heuristic. Policy v2 (PR1 D2, v1.1 §4a): grades come
## from the shared road policy; no new natural-slope ban. A move steeper than
## the class development grade pays the development length and is allowed
## only where it can be laid out at least one way - a serpentine (no barrier,
## water or region edge within R_min + half footprint of its nodes) or a contour
## traverse (natural slope within the class traverse slope at that grade);
## otherwise it is forbidden for that class only. Likewise a move whose own
## cross slope exceeds the class roadbed cross limit (R6 bench condition, with
## CROSS_MARGIN for the 32 m raster) cannot host that class's roadbed and is
## forbidden for that class only (PR1 M2 root cause: walls).

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const MODEL := "search/2;policy=regional_road/2;ground=1.3:1:.8:.5;cut_fill=3:2:1:.5;valley=.6:0:0:0;half=40:50:45:40;develop=all:1.1;layout=serpentine|traverse;hint=60,200,500;width=4;oblique=60;feedback=penalty,closed"
const DIRECTIONS: int = 16
## Per-class profiles, indexed by RouteClass. Grades and buildable slope from
## the road policy v2 (one source with R6): bidirectional classes climb at most
## their sustained grade before development; descent-capable classes may run
## up to descent_max (R6 designs such pieces descent-preferred). The other
## factors are R5 Alpha values; SINGLETRACK / TECHNICAL bands are wider
## (R6 §19: technical needs ~15 m more room per side).
static var PROFILES: Array[Dictionary] = _profiles()


static func _profiles() -> Array[Dictionary]:
	var ground: Array[float] = [1.3, 1.0, 0.8, 0.5]
	var cut_fill: Array[float] = [3.0, 2.0, 1.0, 0.5]
	var valley: Array[float] = [0.6, 0.0, 0.0, 0.0]
	var half: Array[float] = [40.0, 50.0, 45.0, 40.0]
	var out: Array[Dictionary] = []
	for c in range(4):
		var cls: Dictionary = Policy.CLASSES[c]
		var steep: bool = cls.descent_preferred
		var g_max: float = Policy.descent_max(c) if steep else Policy.climb_sustained(c)
		out.append({"g_pref": cls.descent_pref if steep else cls.grade_pref, "g_max": g_max, "develop": true,
			"ground": ground[c], "cut_fill": cut_fill[c], "valley": valley[c], "half_width_m": half[c],
			"traverse_slope": Policy.traverse_slope(c, g_max), "serpentine_room_m": cls.radius_hard_m + Policy.half_footprint(c),
			"cross_limit": CROSS_MARGIN * Policy.cross_limit(c)})
	return out


## Per node: 1 where a development of the class can be laid out (serpentine
## room or a buildable contour traverse), see the header.
static func development_mask(g: Dictionary, route_class: int) -> PackedByteArray:
	var profile: Dictionary = PROFILES[route_class]
	var n: int = g.n
	var room: PackedFloat64Array = _barrier_distance(g)
	var limit_sq: float = profile.traverse_slope * profile.traverse_slope
	var grad_x: PackedFloat64Array = g.grad_x
	var grad_z: PackedFloat64Array = g.grad_z
	var mask := PackedByteArray()
	mask.resize(n * n)
	for k in range(n * n):
		var traverse: bool = grad_x[k] * grad_x[k] + grad_z[k] * grad_z[k] <= limit_sq
		mask[k] = 1 if traverse or room[k] >= profile.serpentine_room_m else 0
	return mask


## Chamfer distance (m) to the nearest blocked / water / body node or the grid
## edge, on a grid of any size.
static func _barrier_distance(g: Dictionary) -> PackedFloat64Array:
	var n: int = g.n
	var s: float = g.spacing
	var d := PackedFloat64Array()
	d.resize(n * n)
	var body: PackedInt32Array = g.get("body", PackedInt32Array())
	for k in range(n * n):
		var i: int = k % n
		var j: int = k / n
		var edge: float = s * mini(mini(i, j), mini(n - 1 - i, n - 1 - j))
		var barrier: bool = g.blocked[k] == 1 or g.water[k] == 1 or (not body.is_empty() and body[k] >= 0)
		d[k] = 0.0 if barrier else edge + s
	var diagonal: float = s * sqrt(2.0)
	for sweep in range(2):
		var range_j: Array = range(n) if sweep == 0 else range(n - 1, -1, -1)
		var range_i: Array = range(n) if sweep == 0 else range(n - 1, -1, -1)
		var step: int = -1 if sweep == 0 else 1
		for j: int in range_j:
			for i: int in range_i:
				var k: int = j * n + i
				var v: float = d[k]
				var pi: int = i + step
				var pj: int = j + step
				if pi >= 0 and pi < n:
					v = minf(v, d[j * n + pi] + s)
				if pj >= 0 and pj < n:
					v = minf(v, d[pj * n + i] + s)
					if pi >= 0 and pi < n:
						v = minf(v, d[pj * n + pi] + diagonal)
					var qi: int = i - step
					if qi >= 0 and qi < n:
						v = minf(v, d[pj * n + qi] + diagonal)
				d[k] = v
	return d
## Raster allowance on the class roadbed cross limit (32 m nodes, +-16 m
## gradient stencil smooth local relief).
const CROSS_MARGIN: float = 1.1
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
## Nodes steeper than the class buildable slope are closed for the class.
## `hints` (optional, PR1 D4 feedback): `closed` (per node, 1 = closed for the
## class) and `penalty` (per node multiplier >= 1, mean of a move's ends).
static func build_tables(g: Dictionary, route_class: int, passable: PackedByteArray, hints: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = PROFILES[route_class]
	var closed: PackedByteArray = hints.get("closed", PackedByteArray())
	if closed.is_empty():
		closed.resize(g.n * g.n)
	var penalty: PackedFloat64Array = hints.get("penalty", PackedFloat64Array())
	var developable: PackedByteArray = development_mask(g, route_class)
	var heights: PackedFloat64Array = g.height
	var grad_x: PackedFloat64Array = g.grad_x
	var grad_z: PackedFloat64Array = g.grad_z
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
		if passable[k] == 0 or closed[k] == 1:
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
			if passable[t] == 0 or closed[t] == 1:
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
			# A development move needs a layout at both of its nodes; any move needs
			# a cross slope the class roadbed can be built on.
			if absf(heights[t] - heights[k]) > profile.g_max * step.length() * g.spacing and (developable[k] == 0 or developable[t] == 0):
				continue
			var direction: Vector2 = Vector2(step).normalized()
			if absf(0.5 * (grad_x[k] + grad_x[t]) * direction.y - 0.5 * (grad_z[k] + grad_z[t]) * direction.x) > profile.cross_limit:
				continue
			if not penalty.is_empty():
				cost *= 0.5 * (penalty[k] + penalty[t])
			var key: int = Raster.pair_key(k, t)
			if crossings.has(key):
				var x: float = crossing_cost(crossings[key], route_class)
				if x == INF:
					continue
				extra[k * DIRECTIONS + d] = x
			base[k * DIRECTIONS + d] = cost
	return {"base": base, "extra": extra, "class": route_class, "closed": closed}


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
	var class_closed: PackedByteArray = tables.get("closed", PackedByteArray())
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
				if closed[t] == 1 or (not class_closed.is_empty() and class_closed[t] == 1):
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
