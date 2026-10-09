class_name RouteCorridorBuilder
extends RefCounted

## Node path -> RouteCorridor data (ExecPlan §9). Reference line: Douglas-
## Peucker over node centres (ends and water-crossing moves kept), stations
## every <= 32 m. Station attributes come from the planning raster, except
## elevation (exact natural surface). Band half-widths: class base, widened
## where the natural grade needs development, clipped laterally at natural
## barriers/water/region edge only (bands of different edges may overlap:
## approval condition 2). Certification samples the exact R4 field every
## <= 8 m: deep water away from a recorded crossing, a crossing the class may
## not use, or a body crossing is a defect (planner replans or rejects);
## excessive slope becomes a STEEP_PINCH station flag. Barriers are never
## smoothed away.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Search = preload("res://scripts/world/region/route_search.gd")
const Scoring = preload("res://scripts/world/region/route_journey_scoring.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const MODEL := "corridor/1;dp=20;station=32;certify=8;crossing_tol=24;pinch_room=16;lateral=16;develop_width=2:120;min_half=8"
const DP_EPSILON_M: float = 20.0
const STATION_M: float = 32.0
const CERTIFY_STEP_M: float = 8.0
const CROSSING_TOLERANCE_M: float = 24.0
const PINCH_ROOM_M: float = 16.0
const LATERAL_STEP_M: float = 16.0
const MIN_HALF_M: float = 8.0
const MAX_HALF_M: float = 120.0

var _raster: Raster
var _rideability: RefCounted
var _surface: RefCounted
var _hydro: RefCounted
## Region origin as float64 scalars (Vector2 is float32: precision loss far
## from the world origin).
var _origin_x: float
var _origin_z: float
var certify_samples: int = 0


static func create(raster: Raster, rideability: RefCounted, surface: RefCounted, hydro_field: RefCounted) -> RouteCorridorBuilder:
	var builder := RouteCorridorBuilder.new()
	builder._raster = raster
	builder._rideability = rideability
	builder._surface = surface
	builder._hydro = hydro_field
	builder._origin_x = raster.origin_x
	builder._origin_z = raster.origin_z
	return builder


static func _dp(points: PackedVector2Array, first: int, last: int, keep: PackedByteArray) -> void:
	if last - first < 2:
		return
	var worst: int = -1
	var worst_distance: float = DP_EPSILON_M
	for k in range(first + 1, last):
		var d: float = Geometry2D.get_closest_point_to_segment(points[k], points[first], points[last]).distance_to(points[k])
		if d > worst_distance:
			worst_distance = d
			worst = k
	if worst >= 0:
		keep[worst] = 1
		_dp(points, first, worst, keep)
		_dp(points, worst, last, keep)


## Simplified reference line (region-local metres) of a node path.
static func reference_line(path: PackedInt32Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	var keep := PackedByteArray()
	keep.resize(path.size())
	for k: int in path:
		points.append(Raster.local_of(k))
	keep[0] = 1
	keep[path.size() - 1] = 1
	for m in range(1, path.size()):
		if Search.direction_index(path[m - 1], path[m], Raster.N) < 0:
			keep[m - 1] = 1
			keep[m] = 1
	var start: int = 0
	for m in range(1, path.size()):
		if keep[m] == 1:
			_dp(points, start, m, keep)
			start = m
	var line := PackedVector2Array()
	for m in range(path.size()):
		if keep[m] == 1:
			line.append(points[m])
	return line


## Stations every <= 32 m along a line, in integer region-local centimetres.
static func stations_cm(line: PackedVector2Array) -> Array:
	var xs := PackedInt64Array([roundi(line[0].x * 100.0)])
	var zs := PackedInt64Array([roundi(line[0].y * 100.0)])
	for m in range(1, line.size()):
		var a: Vector2 = line[m - 1]
		var b: Vector2 = line[m]
		var parts: int = maxi(1, ceili(a.distance_to(b) / STATION_M - 1e-9))
		for p in range(1, parts + 1):
			var q: Vector2 = a.lerp(b, float(p) / parts)
			xs.append(roundi(q.x * 100.0))
			zs.append(roundi(q.y * 100.0))
	return [xs, zs]


func _lateral(p: Vector2, normal: Vector2, limit: float) -> float:
	var d: float = LATERAL_STEP_M
	while d <= limit:
		var q: Vector2 = p + normal * d
		if q.x < 0.0 or q.y < 0.0 or q.x > 4096.0 or q.y > 4096.0:
			return maxf(MIN_HALF_M, d - LATERAL_STEP_M)
		var k: int = Raster.index_of(q.x, q.y)
		if _raster.water[k] == 1 or _raster.blocked[k] == 1 or _raster.body[k] >= 0:
			return maxf(MIN_HALF_M, d - LATERAL_STEP_M)
		d += LATERAL_STEP_M
	return limit


## Builds one corridor. Returns corridor arrays, crossings, totals, station
## signals for reasons, `defects` (raster nodes to close on replan) and
## `pinch_reject` (a steep pinch without lateral room).
func build(path: PackedInt32Array, route_class: int, junction_a: bool, junction_b: bool) -> Dictionary:
	var profile: Dictionary = Search.PROFILES[route_class]
	var line: PackedVector2Array = reference_line(path)
	var st: Array = stations_cm(line)
	var xs: PackedInt64Array = st[0]
	var zs: PackedInt64Array = st[1]
	var count: int = xs.size()
	var local := PackedVector2Array()
	var elevation := PackedFloat64Array()
	for k in range(count):
		var p := Vector2(xs[k] / 100.0, zs[k] / 100.0)
		local.append(p)
		elevation.append(_surface.sample_height(_origin_x + p.x, _origin_z + p.y).height_m)
	var length: float = 0.0
	var climb: float = 0.0
	var descent: float = 0.0
	var arc := PackedFloat64Array([0.0])
	for k in range(1, count):
		length += local[k].distance_to(local[k - 1])
		arc.append(length)
		var dh: float = elevation[k] - elevation[k - 1]
		climb += maxf(dh, 0.0)
		descent += maxf(-dh, 0.0)
	# Crossings on the final reference segments (authoritative geometry).
	var crossings: Array = []
	var defects := PackedInt32Array()
	var crossing_points := PackedVector2Array()
	for k in range(1, count):
		# float64 from the integer stations (exactly as audit_crossings), never
		# from float32 Vector2 copies: records must be bit-reproducible.
		var result: Dictionary = _hydro.sample_segment_crossings(_origin_x + xs[k - 1] / 100.0, _origin_z + zs[k - 1] / 100.0, _origin_x + xs[k] / 100.0, _origin_z + zs[k] / 100.0)
		if not result.body_ids.is_empty():
			defects.append(Raster.index_of(0.5 * (local[k - 1].x + local[k].x), 0.5 * (local[k - 1].y + local[k].y)))
		for record: Dictionary in result.crossings:
			var point := Vector2(record.x - _origin_x, record.z - _origin_z)
			var x_cm: int = roundi((record.x - _origin_x) * 100.0)
			var z_cm: int = roundi((record.z - _origin_z) * 100.0)
			# One physical crossing, one record (a hit at a shared station end).
			if not crossings.is_empty() and crossings[-1].channel_id == record.channel_id and Vector2(crossings[-1].x_cm, crossings[-1].z_cm).distance_to(Vector2(x_cm, z_cm)) <= 1.0:
				continue
			var hint: int = Search.crossing_hint(record)
			if not hint in Graph.ALLOWED_HINTS[route_class]:
				defects.append(Raster.index_of(point.x, point.y))
			crossing_points.append(point)
			crossings.append({"station": k - 1 if point.distance_to(local[k - 1]) <= point.distance_to(local[k]) else k, "water_kind": record.class, "channel_id": record.channel_id,
				"x_cm": x_cm, "z_cm": z_cm, "width_cm": roundi(record.width_m * 100.0), "depth_cm": maxi(0, roundi((record.surface_m - record.bed_m) * 100.0)),
				"angle_deg": clampi(roundi(record.angle_deg), 0, 90), "hint": hint})
	var corridor := {"x_cm": xs, "z_cm": zs, "elevation_cm": PackedInt64Array(), "grade_permille": PackedInt32Array(), "cross_permille": PackedInt32Array(),
		"half_left_cm": PackedInt32Array(), "half_right_cm": PackedInt32Array(), "cost_milli": PackedInt32Array(), "biome": PackedByteArray(), "flags": PackedInt32Array()}
	var signals := {"major_dist": PackedFloat64Array(), "rel_elev": PackedFloat64Array(), "biome": PackedByteArray(), "water_dist": PackedFloat64Array(), "elevation": elevation, "length_m": length, "transitions": 0}
	var a_point: Vector2 = local[0]
	var b_point: Vector2 = local[count - 1]
	var development := 0
	var pinch_reject: bool = false
	var pinch_stations: Dictionary = {}
	# Exact certification every <= 8 m.
	var samples: int = maxi(1, ceili(length / CERTIFY_STEP_M))
	for s in range(samples + 1):
		var at: float = length * s / samples
		var p: Vector2 = Graph.point_along(xs, zs, at * 100.0, false) / 100.0
		var point: Dictionary = _rideability.sample(_origin_x + p.x, _origin_z + p.y)
		certify_samples += 1
		if not point.is_valid:
			# An unverifiable sample is a defect, never silently skipped.
			defects.append(Raster.index_of(p.x, p.y))
			continue
		if point.reason_flags & Ride.Reason.DEEP_WATER:
			var crossed: bool = false
			for c: Vector2 in crossing_points:
				crossed = crossed or c.distance_to(p) <= CROSSING_TOLERANCE_M
			if not crossed:
				defects.append(Raster.index_of(p.x, p.y))
		if point.reason_flags & Ride.Reason.EXCESSIVE_SLOPE:
			var nearest: int = clampi(arc.bsearch(at), 0, count - 1)
			if nearest > 0 and at - arc[nearest - 1] < arc[nearest] - at:
				nearest -= 1
			pinch_stations[nearest] = true
	for k in range(count):
		var p: Vector2 = local[k]
		var forward: Vector2 = (local[mini(k + 1, count - 1)] - local[maxi(k - 1, 0)]).normalized()
		var normal := Vector2(-forward.y, forward.x)
		var grade: float = (elevation[k + 1] - elevation[k]) / maxf(local[k + 1].distance_to(p), 0.01) if k < count - 1 else (elevation[k] - elevation[k - 1]) / maxf(p.distance_to(local[k - 1]), 0.01)
		var gx: float = Raster.bilinear(_raster.grad_x, p.x, p.y)
		var gz: float = Raster.bilinear(_raster.grad_z, p.x, p.y)
		var cross: float = absf(gx * forward.y - gz * forward.x)
		var node: int = Raster.index_of(p.x, p.y)
		var flags: int = 0
		var water_dist: float = Raster.bilinear(_raster.water_dist, p.x, p.y)
		if water_dist <= 60.0:
			flags |= Graph.Flag.NEAR_WATER
		if Raster.bilinear(_raster.moisture, p.x, p.y) >= 0.6:
			flags |= Graph.Flag.WET
		if _raster.travel_class[node] == 0:
			flags |= Graph.Flag.OPEN
		if Raster.bilinear(_raster.cover, p.x, p.y) >= 0.65:
			flags |= Graph.Flag.DENSE_COVER
		var develop: bool = absf(grade) > profile.g_max
		if develop:
			flags |= Graph.Flag.DEVELOPMENT_REQUIRED
			development += 1
		if (junction_a and p.distance_to(a_point) <= Graph.JUNCTION_ZONE_M) or (junction_b and p.distance_to(b_point) <= Graph.JUNCTION_ZONE_M):
			flags |= Graph.Flag.JUNCTION_ZONE
		for c: Vector2 in crossing_points:
			if c.distance_to(p) <= STATION_M:
				flags |= Graph.Flag.CROSSING
		var limit: float = minf(MAX_HALF_M, profile.half_width_m * (2.0 if develop else 1.0))
		var left: float = _lateral(p, normal, limit)
		var right: float = _lateral(p, -normal, limit)
		if pinch_stations.has(k):
			flags |= Graph.Flag.STEEP_PINCH
			if left < PINCH_ROOM_M and right < PINCH_ROOM_M:
				pinch_reject = true
		corridor.elevation_cm.append(roundi(elevation[k] * 100.0))
		corridor.grade_permille.append(roundi(grade * 1000.0))
		corridor.cross_permille.append(roundi(cross * 1000.0))
		corridor.half_left_cm.append(roundi(left * 100.0))
		corridor.half_right_cm.append(roundi(right * 100.0))
		corridor.cost_milli.append(roundi(Raster.bilinear(_raster.cost, p.x, p.y) * 1000.0))
		corridor.biome.append(_raster.biome[node])
		corridor.flags.append(flags)
		signals.major_dist.append(Raster.bilinear(_raster.major_dist, p.x, p.y))
		signals.rel_elev.append(Raster.bilinear(_raster.rel_elev, p.x, p.y))
		signals.biome.append(_raster.biome[node])
		signals.water_dist.append(water_dist)
	var run_path := PackedInt32Array()
	for k in range(count):
		run_path.append(Raster.index_of(local[k].x, local[k].y))
	signals.transitions = Scoring.transitions(_raster, run_path)
	return {"corridor": corridor, "crossings": crossings, "length_cm": roundi(Graph.polyline_length_cm(xs, zs)), "climb_cm": roundi(climb * 100.0), "descent_cm": roundi(descent * 100.0),
		"signals": signals, "defects": defects, "pinch_reject": pinch_reject, "pinches": pinch_stations.size(), "development_stations": development, "line": local}


## Hydrology audit (ExecPlan §10): every reference segment crossing a channel
## has a record and every record matches a real crossing.
static func audit_crossings(graph: RefCounted, hydro_field: RefCounted) -> Array[String]:
	var reasons: Array[String] = []
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	for e in range(graph.get_edge_count()):
		var edge: Dictionary = graph.get_edge(e)
		var c: Dictionary = edge.corridor
		var found: Array = []
		for k in range(1, c.x_cm.size()):
			var result: Dictionary = hydro_field.sample_segment_crossings(ox + c.x_cm[k - 1] / 100.0, oz + c.z_cm[k - 1] / 100.0, ox + c.x_cm[k] / 100.0, oz + c.z_cm[k] / 100.0)
			for record: Dictionary in result.crossings:
				var hit := Vector3(roundi((record.x - ox) * 100.0), roundi((record.z - oz) * 100.0), record.channel_id)
				if found.is_empty() or Vector2(found[-1].x, found[-1].y).distance_to(Vector2(hit.x, hit.y)) > 1.0 or found[-1].z != hit.z:
					found.append(hit)
		var recorded: Array = []
		for crossing: Dictionary in edge.crossings:
			recorded.append(Vector3(crossing.x_cm, crossing.z_cm, crossing.channel_id))
		# Exact multiset comparison: every found crossing recorded exactly once.
		var unmatched: Array = recorded.duplicate()
		for f: Vector3 in found:
			var index: int = unmatched.find(f)
			if index < 0:
				if not "ERR_ROUTE_CROSSING_MISSING" in reasons:
					reasons.append("ERR_ROUTE_CROSSING_MISSING")
			else:
				unmatched.remove_at(index)
		if not unmatched.is_empty() and not "ERR_ROUTE_CROSSING_PHANTOM" in reasons:
			reasons.append("ERR_ROUTE_CROSSING_PHANTOM")
	return reasons
