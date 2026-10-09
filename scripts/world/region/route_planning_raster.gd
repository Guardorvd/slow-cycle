class_name RoutePlanningRaster
extends RefCounted

## Plan-local 32 m planning data for one R5 run (ExecPlan §5). Built once from
## public R3/R4 point queries; never stored in the graph, never shared, no
## global cache. Node (i, j) sits at region-local (32 i, 32 j), aligned with the
## 32 m hydrology drainage lattice, so water-body membership is exact per node
## and node index = j * 129 + i matches the hydrology lattice index.
##
## Besides per-node signals it precomputes, from HydrologyField geometry:
## * `move_crossings`: every 16-neighbour move that crosses a recorded channel
##   centreline (or passes body cells), keyed by the unordered node pair;
## * `jumps`: crossing moves from a dry node over 1-3 consecutive channel-water
##   nodes to the first dry node (axis/diagonal directions, <= 140 m).
## Water nodes are never standing nodes; rivers are crossed only by recorded
## crossing moves. Natural barriers stay barriers.

const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const N: int = 129
const NODES: int = N * N
const SPACING_M: float = 32.0
const CHANNEL_MASK_M: float = 40.0
const MAX_JUMP_M: float = 140.0
## 16-neighbour moves: axis, diagonal and knight steps.
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1),
	Vector2i(2, 1), Vector2i(1, 2), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1)]

var origin_x: int
var origin_z: int
var height := PackedFloat64Array()
var grad_x := PackedFloat64Array()
var grad_z := PackedFloat64Array()
var slope := PackedFloat64Array()
var cost := PackedFloat64Array()
var cover := PackedFloat64Array()
var moisture := PackedFloat64Array()
var meadow := PackedFloat64Array()
var valley := PackedFloat64Array()
var rel_elev := PackedFloat64Array()
var water_dist := PackedFloat64Array()
var depth := PackedFloat64Array()
var travel_class := PackedByteArray()
var blocked := PackedByteArray()
var flags := PackedByteArray()
var water := PackedByteArray()
var biome := PackedByteArray()
var channel_mask := PackedByteArray()
var body := PackedInt32Array()
var edge_dist := PackedFloat64Array()
var major_dist := PackedFloat64Array()
var move_crossings: Dictionary = {}
var jumps: Dictionary = {}
var metrics: Dictionary = {}


static func pair_key(a: int, b: int) -> int:
	return mini(a, b) * NODES + maxi(a, b)


## Swept nodes of a move: nodes whose cells the move passes between its ends
## (none for axis moves). A move may not squeeze past these.
static func swept(i: int, j: int, d: Vector2i) -> Array[Vector2i]:
	if absi(d.x) == 1 and absi(d.y) == 1:
		return [Vector2i(i + d.x, j), Vector2i(i, j + d.y)]
	if absi(d.x) == 2:
		return [Vector2i(i + d.x / 2, j), Vector2i(i + d.x / 2, j + d.y)]
	if absi(d.y) == 2:
		return [Vector2i(i, j + d.y / 2), Vector2i(i + d.x, j + d.y / 2)]
	return []


static func create(rideability: RefCounted, surface: RefCounted, hydro_field: RefCounted, hydrology_plan: RefCounted) -> RoutePlanningRaster:
	var raster := RoutePlanningRaster.new()
	var bounds: Dictionary = rideability.get_bounds_m()
	raster.origin_x = bounds.min_x
	raster.origin_z = bounds.min_z
	# Packed arrays are values: resize each member directly.
	raster.height.resize(NODES)
	raster.grad_x.resize(NODES)
	raster.grad_z.resize(NODES)
	raster.slope.resize(NODES)
	raster.cost.resize(NODES)
	raster.cover.resize(NODES)
	raster.moisture.resize(NODES)
	raster.meadow.resize(NODES)
	raster.valley.resize(NODES)
	raster.rel_elev.resize(NODES)
	raster.water_dist.resize(NODES)
	raster.depth.resize(NODES)
	raster.edge_dist.resize(NODES)
	raster.travel_class.resize(NODES)
	raster.blocked.resize(NODES)
	raster.flags.resize(NODES)
	raster.water.resize(NODES)
	raster.biome.resize(NODES)
	raster.channel_mask.resize(NODES)
	raster.body.resize(NODES)
	raster.body.fill(-1)
	for j in range(N):
		for i in range(N):
			var k: int = j * N + i
			var x: float = raster.origin_x + SPACING_M * i
			var z: float = raster.origin_z + SPACING_M * j
			var point: Dictionary = rideability.sample_combined(x, z)
			var ride: Dictionary = point.rideability
			var signals: Dictionary = point.signals
			raster.height[k] = surface.sample_height(x, z).height_m
			raster.grad_x[k] = ride.gradient.x
			raster.grad_z[k] = ride.gradient.y
			raster.slope[k] = ride.slope_grade
			raster.cost[k] = ride.cost
			raster.travel_class[k] = ride.class
			raster.blocked[k] = 1 if ride.blocked else 0
			raster.flags[k] = ride.reason_flags
			raster.water[k] = 1 if ride.is_water else 0
			raster.depth[k] = ride.water_depth_m
			raster.cover[k] = point.biome.woody_cover
			raster.moisture[k] = point.biome.moisture
			raster.meadow[k] = point.biome.weights[1]
			raster.biome[k] = point.biome.dominant
			raster.valley[k] = signals.valley_floor_weight
			raster.rel_elev[k] = signals.relative_elevation
			raster.water_dist[k] = signals.distance_to_water_m
			raster.edge_dist[k] = SPACING_M * mini(mini(i, j), mini(N - 1 - i, N - 1 - j))
	for b in range(hydrology_plan.get_body_count()):
		for cell: int in hydrology_plan.get_body(b).cells:
			raster.body[cell] = b
	raster._mask_channels(hydrology_plan)
	raster._prepare_crossings(hydro_field)
	return raster


func _mask_channels(hydrology_plan: RefCounted) -> void:
	var river := PackedByteArray()
	river.resize(NODES)
	for c in range(hydrology_plan.get_channel_count()):
		var channel: Dictionary = hydrology_plan.get_channel(c)
		for k in range(channel.x_cm.size() - 1):
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var q := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / 100.0
			var reach: float = maxf(channel.width_cm[k], channel.width_cm[k + 1]) / 200.0 + CHANNEL_MASK_M
			var i0: int = clampi(floori((minf(p.x, q.x) - reach) / SPACING_M), 0, N - 1)
			var i1: int = clampi(ceili((maxf(p.x, q.x) + reach) / SPACING_M), 0, N - 1)
			var j0: int = clampi(floori((minf(p.y, q.y) - reach) / SPACING_M), 0, N - 1)
			var j1: int = clampi(ceili((maxf(p.y, q.y) + reach) / SPACING_M), 0, N - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var node := Vector2(i * SPACING_M, j * SPACING_M)
					var gap: float = Geometry2D.get_closest_point_to_segment(node, p, q).distance_to(node)
					if gap <= reach:
						channel_mask[j * N + i] = 1
					if c == 0 and gap <= reach - CHANNEL_MASK_M + 16.0:
						river[j * N + i] = 1
	major_dist = chamfer(river)


## Two-pass 3x3 chamfer distance (m) from seed nodes; INF where unreachable.
static func chamfer(seeds: PackedByteArray) -> PackedFloat64Array:
	var d := PackedFloat64Array()
	d.resize(NODES)
	for k in range(NODES):
		d[k] = 0.0 if seeds[k] == 1 else INF
	var axis: float = SPACING_M
	var diagonal: float = SPACING_M * sqrt(2.0)
	for j in range(N):
		for i in range(N):
			var k: int = j * N + i
			var v: float = d[k]
			if i > 0:
				v = minf(v, d[k - 1] + axis)
			if j > 0:
				v = minf(v, d[k - N] + axis)
				if i > 0:
					v = minf(v, d[k - N - 1] + diagonal)
				if i < N - 1:
					v = minf(v, d[k - N + 1] + diagonal)
			d[k] = v
	for j in range(N - 1, -1, -1):
		for i in range(N - 1, -1, -1):
			var k: int = j * N + i
			var v: float = d[k]
			if i < N - 1:
				v = minf(v, d[k + 1] + axis)
			if j < N - 1:
				v = minf(v, d[k + N] + axis)
				if i < N - 1:
					v = minf(v, d[k + N + 1] + diagonal)
				if i > 0:
					v = minf(v, d[k + N - 1] + diagonal)
			d[k] = v
	return d


func _query(hydro_field: RefCounted, a: int, b: int) -> Dictionary:
	return hydro_field.sample_segment_crossings(origin_x + SPACING_M * (a % N), origin_z + SPACING_M * (a / N), origin_x + SPACING_M * (b % N), origin_z + SPACING_M * (b / N))


func _prepare_crossings(hydro_field: RefCounted) -> void:
	var queries: int = 0
	for k in range(NODES):
		var i: int = k % N
		var j: int = k / N
		for d: Vector2i in DIRS:
			var ti: int = i + d.x
			var tj: int = j + d.y
			if ti < 0 or tj < 0 or ti >= N or tj >= N:
				continue
			var t: int = tj * N + ti
			if t < k or (channel_mask[k] == 0 and channel_mask[t] == 0):
				continue
			var result: Dictionary = _query(hydro_field, k, t)
			queries += 1
			if not result.crossings.is_empty() or not result.body_ids.is_empty():
				move_crossings[pair_key(k, t)] = result
	# Water jumps from dry nodes over channel-water nodes (never body water).
	var jump_count: int = 0
	for k in range(NODES):
		if water[k] == 1 or blocked[k] == 1:
			continue
		var i: int = k % N
		var j: int = k / N
		for d_index in range(8):
			var d: Vector2i = DIRS[d_index]
			var steps: int = 1
			var valid: bool = true
			while true:
				var si: int = i + d.x * steps
				var sj: int = j + d.y * steps
				if si < 0 or sj < 0 or si >= N or sj >= N or SPACING_M * steps * Vector2(d).length() > MAX_JUMP_M:
					valid = false
					break
				var s: int = sj * N + si
				if water[s] == 0:
					break
				if body[s] >= 0:
					valid = false
					break
				steps += 1
			if not valid or steps < 2:
				continue
			var target: int = (j + d.y * steps) * N + (i + d.x * steps)
			if blocked[target] == 1 or target < k:
				continue
			var result: Dictionary = _query(hydro_field, k, target)
			queries += 1
			if result.crossings.is_empty() or not result.body_ids.is_empty():
				continue
			for pair: Array in [[k, target], [target, k]]:
				if not jumps.has(pair[0]):
					jumps[pair[0]] = []
				jumps[pair[0]].append(pair[1])
			move_crossings[pair_key(k, target)] = result
			jump_count += 1
	metrics = {"crossing_queries": queries, "crossing_moves": move_crossings.size(), "jumps": jump_count, "masked_nodes": channel_mask.count(1), "water_nodes": water.count(1), "blocked_nodes": blocked.count(1)}


## Kernel view: shared packed arrays (copy-on-write) for RouteSearch.
func grid() -> Dictionary:
	return {"n": N, "spacing": SPACING_M, "height": height, "grad_x": grad_x, "grad_z": grad_z, "cost": cost, "valley": valley,
		"water": water, "blocked": blocked, "body": body, "edge_dist": edge_dist, "move_crossings": move_crossings, "jumps": jumps}


static func index_of(lx: float, lz: float) -> int:
	return clampi(roundi(lz / SPACING_M), 0, N - 1) * N + clampi(roundi(lx / SPACING_M), 0, N - 1)


static func local_of(k: int) -> Vector2:
	return Vector2(SPACING_M * (k % N), SPACING_M * (k / N))


## Bilinear sample of a per-node scalar array at a region-local point.
static func bilinear(values: PackedFloat64Array, lx: float, lz: float) -> float:
	var sx: float = clampf(lx / SPACING_M, 0.0, N - 1.0)
	var sz: float = clampf(lz / SPACING_M, 0.0, N - 1.0)
	var i: int = mini(floori(sx), N - 2)
	var j: int = mini(floori(sz), N - 2)
	var tx: float = sx - i
	var tz: float = sz - j
	return lerpf(lerpf(values[j * N + i], values[j * N + i + 1], tx), lerpf(values[(j + 1) * N + i], values[(j + 1) * N + i + 1], tx), tz)


func storage_bytes() -> int:
	return 13 * NODES * 8 + 6 * NODES + NODES * 4
