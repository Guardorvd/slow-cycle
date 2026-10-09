class_name HydrologyField
extends RefCounted

## World-space query view over one HydrologyPlan and the TerrainField it was
## built from (R3). Derived only: it adds no hydrological truth. Immutable
## after create(); concurrent use is not claimed.
##
## sample_water       water at a point (channel width or body level), kind,
##                    feature id, water surface and depth;
## sample_proximity   distance to the nearest water and to the major river,
##                    nearest feature, R1 floor (floodplain) membership;
## sample_drainage    contributing area, catchment channel and terminal kind
##                    of the nearest 32 m drainage-lattice point;
## sample_deformation the hydrology deformation (the R7 FinalSurface addend):
##   1. floodplain shaping inside the R1 floor (HydrologyPlan.floodplain_delta:
##      towards the fitted floodplain level with a gentle rise away from the
##      river, so the floor drains to it; clamped; fading beyond the floor);
##   2. channel carving: river bed / bank and creek gully profiles below the
##      water surface, carving only, each tapering to zero at its corridor
##      edge (and a creek's at its head);
##   Delta is continuous, |Delta| <= HydrologyPlan.MAX_DEFORMATION_M, and
##   exactly 0 outside the floor margin and every channel corridor.
## Domain and reasons follow TerrainField (closed region square).

const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const SCHEMA_TAG := "slow_cycle.hydrology_field/1"
const BUCKET_M: float = 64.0
const BUCKETS: int = 65
const SEARCH_BUCKET_M: float = 128.0
const SEARCH_BUCKETS: int = 33
const RIVER_BANK_SLOPE: float = 0.12
const CREEK_SIDE_SLOPE: float = 0.35
const RIVER_FULL_M: float = 20.0
const RIVER_REACH_M: float = 50.0
const CREEK_FULL_M: float = 10.0
const CREEK_REACH_M: float = 30.0
const HEAD_TAPER_M: float = 64.0
const STRIDE: int = 14
const KIND_NAMES: Array[String] = ["MAJOR_RIVER", "TRIBUTARY", "CREEK"]
const BODY_NAMES: Array[String] = ["POND", "CLOSED"]
const TERMINAL_NAMES: Array[String] = ["", "MAJOR_RIVER", "EDGE", "CLOSED"]

var _terrain: Field
var _plan_signature: String
var _region_signature: String
var _min_x: int
var _min_z: int
var _max_x: int
var _max_z: int
var _symmetry: int
# Per segment: ax, az, bx, bz (local m), surface a/b, bed a/b, half width a/b,
# station a/b (m), channel id, class (stride 14).
var _segments := PackedFloat64Array()
var _carve_buckets: Array = []
var _search_buckets: Array = []
var _frame_m: Array = [] # river_frame in metres: river_v, near_v, far_v, floor
var _body_of := PackedInt32Array()
var _body_level := PackedFloat64Array()
var _body_kind := PackedInt32Array()
var _body_cells: Array = []
var _area := PackedInt32Array()
var _catchment := PackedInt32Array()
var _terminal_of := PackedByteArray()
var _body_proximity_buckets: Array = []
var _max_half_width: float = 0.0


## Reasons: ERR_HYDRO_PLAN_MISSING (null plan or terrain), ERR_HYDRO_PLAN_INVALID,
## ERR_HYDRO_TERRAIN_MISMATCH (plan built for another region or terrain schema).
static func create(hydrology_plan: RefCounted, terrain_field: RefCounted) -> Dictionary:
	if hydrology_plan == null or not hydrology_plan is Hydro or terrain_field == null or not terrain_field is Field:
		return {"is_valid": false, "field": null, "reason_code": "ERR_HYDRO_PLAN_MISSING"}
	if not hydrology_plan.validate().is_valid:
		return {"is_valid": false, "field": null, "reason_code": "ERR_HYDRO_PLAN_INVALID"}
	var data: Dictionary = hydrology_plan.get_data()
	var bounds: Dictionary = terrain_field.get_bounds_m()
	if data.region_signature != terrain_field.get_region_signature() or data.terrain_schema != Field.SCHEMA_TAG or data.origin_x_m != bounds.min_x or data.origin_z_m != bounds.min_z:
		return {"is_valid": false, "field": null, "reason_code": "ERR_HYDRO_TERRAIN_MISMATCH"}
	var field := HydrologyField.new()
	field._terrain = terrain_field
	field._plan_signature = hydrology_plan.signature()
	field._region_signature = data.region_signature
	field._min_x = bounds.min_x
	field._min_z = bounds.min_z
	field._max_x = bounds.max_x
	field._max_z = bounds.max_z
	field._symmetry = data.frame_symmetry
	field._build(data)
	return {"is_valid": true, "field": field, "reason_code": ""}


func _build(data: Dictionary) -> void:
	_frame_m = Hydro.frame_arrays_m(data.river_frame)
	for cell in range(BUCKETS * BUCKETS):
		_carve_buckets.append(PackedInt32Array())
	for cell in range(SEARCH_BUCKETS * SEARCH_BUCKETS):
		_search_buckets.append(PackedInt32Array())
		_body_proximity_buckets.append(PackedInt32Array())
	for channel: Dictionary in data.channels:
		var major: bool = channel.class == Hydro.CLASS_MAJOR_RIVER
		for k in range(channel.x_cm.size() - 1):
			var s: int = _segments.size() / STRIDE
			_segments.append_array([channel.x_cm[k] / 100.0, channel.z_cm[k] / 100.0, channel.x_cm[k + 1] / 100.0, channel.z_cm[k + 1] / 100.0,
				channel.surface_cm[k] / 100.0, channel.surface_cm[k + 1] / 100.0, channel.bed_cm[k] / 100.0, channel.bed_cm[k + 1] / 100.0,
				channel.width_cm[k] / 200.0, channel.width_cm[k + 1] / 200.0, channel.station_cm[k] / 100.0, channel.station_cm[k + 1] / 100.0, channel.id, channel.class])
			var base: int = s * STRIDE
			_max_half_width = maxf(_max_half_width, maxf(_segments[base + 8], _segments[base + 9]))
			var reach: float = maxf(_segments[base + 8], _segments[base + 9]) + (RIVER_REACH_M if major else CREEK_REACH_M)
			_register(_carve_buckets, BUCKETS, BUCKET_M, s, reach)
			_register(_search_buckets, SEARCH_BUCKETS, SEARCH_BUCKET_M, s, 0.0)
	var n: int = Hydro.LATTICE_SIZE * Hydro.LATTICE_SIZE
	_body_of.resize(n)
	_body_of.fill(-1)
	for body: Dictionary in data.bodies:
		_body_level.append(body.level_cm / 100.0)
		_body_kind.append(body.kind)
		_body_cells.append(body.cells)
		for cell: int in body.cells:
			_body_of[cell] = body.id
			var bi: int = (cell % Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M / int(SEARCH_BUCKET_M)
			var bj: int = (cell / Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M / int(SEARCH_BUCKET_M)
			_body_proximity_buckets[bj * SEARCH_BUCKETS + bi].append(cell)
	_area = data.lattice.area_cells
	_catchment = data.lattice.catchment
	# Terminal kind reached from every lattice point (path-compressed walk).
	var receiver: PackedInt32Array = data.lattice.receiver
	var terminal: PackedByteArray = data.lattice.terminal
	_terminal_of.resize(n)
	var path := PackedInt32Array()
	for start in range(n):
		if _terminal_of[start] != 0:
			continue
		path.clear()
		var c: int = start
		while receiver[c] >= 0 and _terminal_of[c] == 0:
			path.append(c)
			c = receiver[c]
		var kind: int = _terminal_of[c] if _terminal_of[c] != 0 else terminal[c]
		_terminal_of[c] = kind
		for p: int in path:
			_terminal_of[p] = kind


func _register(buckets: Array, count: int, size: float, s: int, reach: float) -> void:
	var base: int = s * STRIDE
	var i0: int = clampi(floori((minf(_segments[base], _segments[base + 2]) - reach) / size), 0, count - 1)
	var i1: int = clampi(floori((maxf(_segments[base], _segments[base + 2]) + reach) / size), 0, count - 1)
	var j0: int = clampi(floori((minf(_segments[base + 1], _segments[base + 3]) - reach) / size), 0, count - 1)
	var j1: int = clampi(floori((maxf(_segments[base + 1], _segments[base + 3]) + reach) / size), 0, count - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			buckets[j * count + i].append(s)


func get_bounds_m() -> Dictionary:
	return {"min_x": _min_x, "min_z": _min_z, "max_x": _max_x, "max_z": _max_z}


func get_region_signature() -> String:
	return _region_signature


func get_plan_signature() -> String:
	return _plan_signature


func _reason(x: float, z: float) -> String:
	if not is_finite(x) or not is_finite(z):
		return "ERR_HYDRO_NONFINITE_INPUT"
	if x < _min_x or z < _min_z or x > _max_x or z > _max_z:
		return "ERR_HYDRO_OUT_OF_DOMAIN"
	return ""


## Segment parameter t in [0, 1], distance from a local point and how far
## (m) the point lies behind the segment's upstream end: Vector3(t, d, behind).
func _project(s: int, lx: float, lz: float) -> Vector3:
	var base: int = s * STRIDE
	var ax: float = _segments[base]
	var az: float = _segments[base + 1]
	var dx: float = _segments[base + 2] - ax
	var dz: float = _segments[base + 3] - az
	var length_squared: float = dx * dx + dz * dz
	var raw: float = 0.0 if length_squared <= 0.0 else ((lx - ax) * dx + (lz - az) * dz) / length_squared
	var t: float = clampf(raw, 0.0, 1.0)
	var px: float = lx - (ax + t * dx)
	var pz: float = lz - (az + t * dz)
	return Vector3(t, sqrt(px * px + pz * pz), maxf(0.0, -raw) * sqrt(length_squared))


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Hydrology deformation at a region-local point with base height `base`.
func deformation_local(lx: float, lz: float, base: float) -> float:
	var floodplain: float = Hydro.floodplain_delta(Hydro.frame_values(_symmetry, _frame_m, lx, lz), base)
	var shaped: float = base + floodplain
	var carve: float = 0.0
	var bi: int = clampi(floori(lx / BUCKET_M), 0, BUCKETS - 1)
	var bj: int = clampi(floori(lz / BUCKET_M), 0, BUCKETS - 1)
	for s: int in _carve_buckets[bj * BUCKETS + bi]:
		var base_index: int = s * STRIDE
		var major: bool = int(_segments[base_index + 13]) == Hydro.CLASS_MAJOR_RIVER
		var projected: Vector3 = _project(s, lx, lz)
		var t: float = projected.x
		var d: float = projected.y
		var half: float = lerpf(_segments[base_index + 8], _segments[base_index + 9], t)
		var reach: float = RIVER_REACH_M if major else CREEK_REACH_M
		if d >= half + reach:
			continue
		var surface: float = lerpf(_segments[base_index + 4], _segments[base_index + 5], t)
		var bed: float = lerpf(_segments[base_index + 6], _segments[base_index + 7], t)
		var target: float
		if d <= half:
			target = bed + (surface - bed) * (d / half) * (d / half)
		else:
			target = surface + (d - half) * (RIVER_BANK_SLOPE if major else CREEK_SIDE_SLOPE)
		# Behind the upstream end the profile keeps rising with the channel's
		# own gradient, so a steep channel never undercuts its upstream bed.
		var length: float = _segments[base_index + 11] - _segments[base_index + 10]
		if projected.z > 0.0 and length > 0.0:
			target += projected.z * maxf(0.0, (_segments[base_index + 4] - _segments[base_index + 5]) / length)
		var full: float = RIVER_FULL_M if major else CREEK_FULL_M
		var taper: float = 1.0 - _smooth((d - half - full) / (reach - full))
		if not major:
			taper *= _smooth(lerpf(_segments[base_index + 10], _segments[base_index + 11], t) / HEAD_TAPER_M)
		carve = maxf(carve, taper * maxf(0.0, shaped - target))
	return clampf(floodplain - carve, -Hydro.MAX_DEFORMATION_M, Hydro.MAX_DEFORMATION_M)


func _base(x: float, z: float) -> float:
	return _terrain.sample_height(x, z).height_m


func sample_deformation(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "delta_m": NAN, "reason_code": reason}
	return {"is_valid": true, "delta_m": deformation_local(x - _min_x, z - _min_z, _base(x, z)), "reason_code": ""}


func _lattice_index(lx: float, lz: float) -> int:
	var i: int = clampi(roundi(lx / Hydro.LATTICE_STEP_M), 0, Hydro.LATTICE_SIZE - 1)
	var j: int = clampi(roundi(lz / Hydro.LATTICE_STEP_M), 0, Hydro.LATTICE_SIZE - 1)
	return j * Hydro.LATTICE_SIZE + i


## Water at a point: inside a channel's width with its surface above the
## hydrology-shaped ground, or inside a body's lattice cells below its level.
func sample_water(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "is_water": false, "kind": "", "id": -1, "water_surface_m": NAN, "depth_m": NAN, "reason_code": reason}
	var lx: float = x - _min_x
	var lz: float = z - _min_z
	var base: float = _base(x, z)
	var ground: float = base + deformation_local(lx, lz, base)
	var result := {"is_valid": true, "is_water": false, "kind": "", "id": -1, "water_surface_m": NAN, "depth_m": 0.0, "reason_code": ""}
	var body: int = _body_of[_lattice_index(lx, lz)]
	if body >= 0 and _body_level[body] > ground:
		result.merge({"is_water": true, "kind": BODY_NAMES[_body_kind[body]], "id": body, "water_surface_m": _body_level[body], "depth_m": _body_level[body] - ground}, true)
		return result
	var best: float = INF
	var bi: int = clampi(floori(lx / BUCKET_M), 0, BUCKETS - 1)
	var bj: int = clampi(floori(lz / BUCKET_M), 0, BUCKETS - 1)
	for s: int in _carve_buckets[bj * BUCKETS + bi]:
		var base_index: int = s * STRIDE
		var projected: Vector3 = _project(s, lx, lz)
		var half: float = lerpf(_segments[base_index + 8], _segments[base_index + 9], projected.x)
		var surface: float = lerpf(_segments[base_index + 4], _segments[base_index + 5], projected.x)
		if projected.y <= half and surface > ground and projected.y - half < best:
			best = projected.y - half
			result.merge({"is_water": true, "kind": KIND_NAMES[int(_segments[base_index + 13])], "id": int(_segments[base_index + 12]), "water_surface_m": surface, "depth_m": surface - ground}, true)
	return result


## Nearest water edge by expanding rings of 128 m buckets (exact for channels;
## bodies measured to their lattice cells). `major_only` restricts to the river.
func _nearest(lx: float, lz: float, major_only: bool) -> Dictionary:
	var best: float = INF
	var best_id: int = -1
	var best_kind: String = ""
	var bi: int = clampi(floori(lx / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1)
	var bj: int = clampi(floori(lz / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1)
	for ring in range(SEARCH_BUCKETS):
		if best <= (ring - 1) * SEARCH_BUCKET_M:
			break
		for j in range(bj - ring, bj + ring + 1):
			for i in range(bi - ring, bi + ring + 1):
				if i < 0 or j < 0 or i >= SEARCH_BUCKETS or j >= SEARCH_BUCKETS or maxi(absi(i - bi), absi(j - bj)) != ring:
					continue
				for s: int in _search_buckets[j * SEARCH_BUCKETS + i]:
					var base_index: int = s * STRIDE
					if major_only and int(_segments[base_index + 13]) != Hydro.CLASS_MAJOR_RIVER:
						continue
					var projected: Vector3 = _project(s, lx, lz)
					var edge: float = maxf(0.0, projected.y - lerpf(_segments[base_index + 8], _segments[base_index + 9], projected.x))
					if edge < best:
						best = edge
						best_id = int(_segments[base_index + 12])
						best_kind = KIND_NAMES[int(_segments[base_index + 13])]
	if not major_only:
		for body in range(_body_cells.size()):
			for cell: int in _body_cells[body]:
				var cx: float = (cell % Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M
				var cz: float = (cell / Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M
				var edge: float = maxf(0.0, Vector2(lx - cx, lz - cz).length() - 0.5 * Hydro.LATTICE_STEP_M)
				if edge < best:
					best = edge
					best_id = body
					best_kind = BODY_NAMES[_body_kind[body]]
	return {"distance": best, "id": best_id, "kind": best_kind}


func sample_proximity(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "distance_to_water_m": NAN, "nearest_kind": "", "nearest_id": -1, "distance_to_major_m": NAN, "in_floodplain": false, "reason_code": reason}
	var lx: float = x - _min_x
	var lz: float = z - _min_z
	var nearest: Dictionary = _nearest(lx, lz, false)
	var major: Dictionary = _nearest(lx, lz, true)
	var f: Array = Hydro.frame_values(_symmetry, _frame_m, lx, lz)
	return {"is_valid": true, "distance_to_water_m": nearest.distance, "nearest_kind": nearest.kind, "nearest_id": nearest.id, "distance_to_major_m": major.distance, "in_floodplain": f[0] >= f[3] and f[0] <= f[2], "reason_code": ""}


## Capped geometric distance only. A zero distance does not assert water.
## Per-call segment deduplication leaves immutable shared query state intact.
func sample_proximity_bounded(x: float, z: float, radius_m: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if reason.is_empty() and (not is_finite(radius_m) or radius_m <= 0.0 or radius_m > 256.0):
		reason = "ERR_HYDRO_PROXIMITY_RADIUS"
	if not reason.is_empty():
		return {"is_valid": false, "reason_code": reason}
	var lx: float = x - _min_x
	var lz: float = z - _min_z
	var best: float = radius_m
	var seen: Dictionary = {}
	var segment_candidates: int = 0
	var body_candidates: int = 0
	var reach: float = radius_m + _max_half_width
	for j in range(clampi(floori((lz - reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori((lz + reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
		for i in range(clampi(floori((lx - reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori((lx + reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
			for s: int in _search_buckets[j * SEARCH_BUCKETS + i]:
				if seen.has(s):
					continue
				seen[s] = true
				segment_candidates += 1
				var b: int = s * STRIDE
				var p: Vector3 = _project(s, lx, lz)
				best = minf(best, maxf(0.0, p.y - lerpf(_segments[b + 8], _segments[b + 9], p.x)))
	reach = radius_m + 16.0
	for j in range(clampi(floori((lz - reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori((lz + reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
		for i in range(clampi(floori((lx - reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori((lx + reach) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
			for cell: int in _body_proximity_buckets[j * SEARCH_BUCKETS + i]:
				body_candidates += 1
				var cx: float = (cell % Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M
				var cz: float = (cell / Hydro.LATTICE_SIZE) * Hydro.LATTICE_STEP_M
				best = minf(best, maxf(0.0, Vector2(lx - cx, lz - cz).length() - 16.0))
	return {"is_valid": true, "reason_code": "", "distance_to_water_m": best, "is_capped": best == radius_m, "segment_candidates": segment_candidates, "body_candidates": body_candidates}


## Additive R5 query: where a straight world-space segment crosses recorded
## channel centrelines, and which water bodies' lattice cells it passes. Each
## crossing carries the parameter t along the segment, world point, channel
## id/class/perennial/order, water width (m), surface and bed (m) and the
## crossing angle in degrees (90 = perpendicular). Exactly collinear overlaps
## are not crossings. Bodies: lattice cells nearest to samples every 8 m.
## Derived only; existing queries, schema and numerics are unchanged.
const MAX_CROSSING_SEGMENT_M: float = 256.0


func sample_segment_crossings(x0: float, z0: float, x1: float, z1: float) -> Dictionary:
	var reason: String = _reason(x0, z0)
	if reason.is_empty():
		reason = _reason(x1, z1)
	if reason.is_empty() and Vector2(x1 - x0, z1 - z0).length() > MAX_CROSSING_SEGMENT_M:
		reason = "ERR_HYDRO_SEGMENT_LENGTH"
	if not reason.is_empty():
		return {"is_valid": false, "reason_code": reason, "crossings": [], "body_ids": PackedInt32Array()}
	var a := Vector2(x0 - _min_x, z0 - _min_z)
	var b := Vector2(x1 - _min_x, z1 - _min_z)
	var r: Vector2 = b - a
	var crossings: Array = []
	var seen: Dictionary = {}
	for j in range(clampi(floori(minf(a.y, b.y) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori(maxf(a.y, b.y) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
		for i in range(clampi(floori(minf(a.x, b.x) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1), clampi(floori(maxf(a.x, b.x) / SEARCH_BUCKET_M), 0, SEARCH_BUCKETS - 1) + 1):
			for s: int in _search_buckets[j * SEARCH_BUCKETS + i]:
				if seen.has(s):
					continue
				seen[s] = true
				var base: int = s * STRIDE
				var p := Vector2(_segments[base], _segments[base + 1])
				var q: Vector2 = Vector2(_segments[base + 2], _segments[base + 3]) - p
				var denominator: float = r.cross(q)
				if denominator == 0.0:
					continue
				var t: float = (p - a).cross(q) / denominator
				var u: float = (p - a).cross(r) / denominator
				if t < 0.0 or t > 1.0 or u < 0.0 or u > 1.0:
					continue
				var surface: float = lerpf(_segments[base + 4], _segments[base + 5], u)
				var bed: float = lerpf(_segments[base + 6], _segments[base + 7], u)
				var cosine: float = absf(r.normalized().dot(q.normalized())) if r.length() > 0.0 else 1.0
				crossings.append({"t": t, "x": _min_x + a.x + t * r.x, "z": _min_z + a.y + t * r.y, "channel_id": int(_segments[base + 12]), "class": int(_segments[base + 13]),
					"width_m": 2.0 * lerpf(_segments[base + 8], _segments[base + 9], u), "surface_m": surface, "bed_m": bed, "angle_deg": rad_to_deg(acos(clampf(cosine, 0.0, 1.0))), "segment": s})
	crossings.sort_custom(func(m: Dictionary, n: Dictionary) -> bool: return m.t < n.t or (m.t == n.t and (m.channel_id < n.channel_id or (m.channel_id == n.channel_id and m.segment < n.segment))))
	# A hit exactly on a shared channel vertex is one crossing, not two.
	var unique: Array = []
	for crossing: Dictionary in crossings:
		if not unique.is_empty() and unique[-1].channel_id == crossing.channel_id and absf(unique[-1].t - crossing.t) <= 1e-9:
			continue
		unique.append(crossing)
	var bodies := PackedInt32Array()
	var steps: int = maxi(1, ceili(r.length() / 8.0))
	for k in range(steps + 1):
		var point: Vector2 = a + r * (float(k) / steps)
		var body: int = _body_of[_lattice_index(point.x, point.y)]
		if body >= 0 and not body in bodies:
			bodies.append(body)
	bodies.sort()
	return {"is_valid": true, "reason_code": "", "crossings": unique, "body_ids": bodies}


## Observational derived-index storage, excluding upstream plans/terrain.
func get_proximity_metrics() -> Dictionary:
	var entries: int = 0
	for bucket: PackedInt32Array in _body_proximity_buckets:
		entries += bucket.size()
	return {"segments": _segments.size() / STRIDE, "body_cells": entries, "body_index_packed_bytes": entries * 4, "body_index_buckets": _body_proximity_buckets.size()}


func sample_drainage(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "area_m2": NAN, "catchment_id": -1, "terminal_kind": "", "reason_code": reason}
	var cell: int = _lattice_index(x - _min_x, z - _min_z)
	return {"is_valid": true, "area_m2": float(_area[cell]) * Hydro.LATTICE_STEP_M * Hydro.LATTICE_STEP_M, "catchment_id": _catchment[cell], "terminal_kind": TERMINAL_NAMES[_terminal_of[cell]], "reason_code": ""}
