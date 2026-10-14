extends RefCounted

## BC1 trail realization (pure: no scene, no I/O). Owns the trail line, its
## mode, its reasons and (from SHAPED on) its operations; FinalSurface keeps
## the geometry, RealizedRoadNetwork the connectivity.
##
## Input: an explicit trail configuration (schema below, e.g.
## res://resources/regions/bc1_trail_184729.json) and the published products
## of one region: its seed/region identity, the RealizedRoadNetwork data and
## the FinalSurface the network was built on (the trail never changes it).
## Mode NATURAL: the trail follows the existing surface. Its line is a
## centripetal Catmull-Rom curve through the configured control points,
## resampled every SAMPLE_M metres with heights of that surface; nothing is
## cut or filled - only the trace (material, collision layer within the band)
## and the vegetation clearance change downstream.
##
## A trail is published only complete: it starts on the riding plane of a
## piece of its first node and ends on one of its second node, leaves the
## road once and meets no other road, water or bridge deck in between, and is
## rideable in both directions within the declared limits. Otherwise it is
## rejected with one reason (the network stays as it was):
##   ERR_TRAIL_INPUT       malformed configuration, nonfinite or out-of-bounds data
##   ERR_TRAIL_IDENTITY    configured for another seed, region or node layout
##   ERR_TRAIL_CONNECTION  ends not joined to their nodes, or another road met
##   ERR_TRAIL_UNRIDEABLE  water, a deck, grade, side slope or radius limit
##   ERR_TRAIL_BUDGET      a shaping operation beyond its declared budget
##
## SHAPED (BC1 amendment A1): at most one operation per trail, BENCH - a local
## traverse bench where the trail crosses a side slope. Over its interval the
## band is levelled across (uphill edge cut, downhill edge filled by the design
## cross slope c(s), tapered by a smoothstep over taper_m at both ends) and a
## daylight strip on each side blends back to the surface; the centre line
## keeps its height. c(s) is the straight fit across the band of the surface
## the bench levels, (h(+hw) - h(-hw)) / (2 hw): realize() screens it on the
## design surface, shape() measures it on the published (pre-bench) surface
## and checks the amplitude budgets there. The record carries per-sample
## amplitudes a = c * taper;
## FinalSurface.trail_displacement() evaluates the displacement d(s, t):
##   |t| <= hw                  d = -a * t
##   hw < |t| <= hw + daylight  d = -a * sign(t) * hw * (hw + daylight - |t|) / daylight
## Budgets (fixed before implementation, never enlarged to pass): one
## operation, interval <= BENCH_MAX_LENGTH_M inside the trail interior,
## daylight / taper ranges, |d| <= BENCH_MAX_DISPLACEMENT_M, earthwork
## <= BENCH_MAX_VOLUME_M3, published band side slope <= BENCH_CROSS_MAX, and
## footprint + BENCH_CLEARANCE_M clear of water and road planes and
## BENCH_BORDER_M from every tile border.
##
## Configuration (JSON object):
##   {"schema": SCHEMA, "seed": int, "region": [x, z], "trails": [{
##     "id": "trail:<name>", "mode": "NATURAL", "purpose": text,
##     "nodes": [{"id": int, "x_m": float, "z_m": float}, {...}]   (region-local),
##     "half_width_m": float, "control_points": [[x_m, z_m], ...]  (region-local),
##     "operations": [{"kind": "BENCH", "from": [x_m, z_m], "to": [x_m, z_m],
##                     "daylight_m": float, "taper_m": float}]      (optional),
##     "class": "SINGLETRACK" | "TECHNICAL"   (optional, BC2; default SINGLETRACK),
##     "join_max_m": float                    (optional, BC2; default JOIN_MAX_M)}]}
##
## BC2 classes (limits()): SINGLETRACK as above, rideable both ways.
## TECHNICAL is a descent from its first node to its second (directions
## FORWARD only; the road is the way back up): descents up to the class
## grade of RoadSynthesisPolicy (15 deg, measured descent hold of the
## bicycle), forward climbs only up to FORWARD_CLIMB_TECHNICAL, turns down to
## RADIUS_MIN_TECHNICAL_M. A configuration without "class" is realized exactly
## as before.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const SCHEMA := "slow_cycle.trail_config/1"
const MODES: Array[String] = ["NATURAL"]
## Every BC1 trail is a SINGLETRACK; class limits come from the road policy.
const TRAIL_CLASS: int = Graph.RouteClass.SINGLETRACK
const SAMPLE_M: float = 1.0
## Distance the line keeps from the region edge.
const MARGIN_M: float = 16.0
## A trail end joins a piece of its node no farther than this from the node
## (beyond the node's junction connectors, on the incident edge).
const JOIN_MAX_M: float = 200.0
const HALF_WIDTH_MIN_M: float = 0.5
const HALF_WIDTH_MAX_M: float = 1.0
## Node layout tolerance of the identity check.
const NODE_TOLERANCE_M: float = 1.0
## PROVISIONAL screening limits, not NATURAL norms (BC1 amendment A1): grade
## over GRADE_WINDOW_M reuses the SINGLETRACK class value (10 deg); radius over
## +-RADIUS_WINDOW_M is RADIUS_MIN_M, the BicycleController's full-lock radius
## at 8 m/s (its exported steering defaults, as mirrored by the ride bot), not
## R6's road radius; side slope of the untouched ground across the band
## outside a bench; short pitches over one sample (road shoulders and
## earthwork at the joins). Real two-way rideability is established by Input
## rides of the existing BicycleController; NATURAL norms are owned by BC2.
const GRADE_WINDOW_M: float = 4.0
const RADIUS_WINDOW_M: float = 3.0
const RADIUS_MIN_M: float = 8.0
const CROSS_SLOPE_MAX: float = 0.35
const PITCH_GRADE_MAX: float = 0.30
## BENCH budgets (amendment A1).
const BENCH_MAX_LENGTH_M: float = 60.0
const BENCH_DAYLIGHT_RANGE_M := Vector2(0.5, 2.0)
const BENCH_TAPER_RANGE_M := Vector2(2.0, 8.0)
const BENCH_MAX_DISPLACEMENT_M: float = 0.30
const BENCH_MAX_VOLUME_M3: float = 30.0
const BENCH_CROSS_MAX: float = 0.06
const BENCH_CLEARANCE_M: float = 1.5
const BENCH_BORDER_M: float = 2.0
## BC2 TECHNICAL: the comfortable lateral load of the measured riding envelope
## (2.45 m/s^2, RoadSynthesisPolicy.MEASUREMENT) at 3.8 m/s (13.8 km/h, reached
## by braking on the descent) turns on 6 m; the bicycle's full-lock radius at
## that speed is ~3 m. Forward climbs on a descent stay below the measured
## sustained climb on rough ground (5.6 deg).
const RADIUS_MIN_TECHNICAL_M: float = 6.0
const FORWARD_CLIMB_TECHNICAL: float = 0.095
## Upper bound of a configured join_max_m (a join anywhere on an incident edge).
const JOIN_MAX_EDGE_M: float = 3000.0
const TILE_M: float = 512.0


## Validated configuration or ERR_TRAIL_INPUT. `value`: the parsed JSON.
static func parse(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema", "") != SCHEMA or not value.get("trails") is Array:
		return _reject("", "ERR_TRAIL_INPUT", {"stage": "schema"})
	if not _int_like(value.get("seed")) or not value.get("region") is Array or value.region.size() != 2 or not _int_like(value.region[0]) or not _int_like(value.region[1]):
		return _reject("", "ERR_TRAIL_INPUT", {"stage": "identity fields"})
	var ids: Dictionary = {}
	for trail: Variant in value.trails:
		if not trail is Dictionary:
			return _reject("", "ERR_TRAIL_INPUT", {"stage": "trail record"})
		var id: Variant = trail.get("id")
		if not id is String or not String(id).begins_with("trail:") or ids.has(id):
			return _reject(str(id), "ERR_TRAIL_INPUT", {"stage": "id"})
		ids[id] = true
	return {"is_valid": true, "reason_code": "", "config": value}


## Realize every configured trail. context: {seed: int, region: Vector2i,
## network: RealizedRoadNetwork data, surface: FinalSurface (no trails),
## field: HydrologyField}. Returns {trails: [record], rejected: [{id,
## reason_code, detail}]}; a malformed configuration rejects as a whole.
static func realize_all(value: Variant, context: Dictionary) -> Dictionary:
	var parsed: Dictionary = parse(value)
	if not parsed.is_valid:
		return {"trails": [], "rejected": [{"id": parsed.id, "reason_code": parsed.reason_code, "detail": parsed.detail}]}
	var config: Dictionary = parsed.config
	var trails: Array = []
	var rejected: Array = []
	for trail: Dictionary in config.trails:
		var made: Dictionary = realize(trail, config, context)
		if made.is_valid:
			trails.append(made.trail)
		else:
			rejected.append({"id": made.id, "reason_code": made.reason_code, "detail": made.detail})
	return {"trails": trails, "rejected": rejected}


## Riding limits of a trail class name ({} for an unknown class).
static func limits(class_name_value: String) -> Dictionary:
	if class_name_value == "SINGLETRACK":
		return {"class": Graph.RouteClass.SINGLETRACK, "grade": Policy.grade_hard(Graph.RouteClass.SINGLETRACK), "radius": RADIUS_MIN_M, "climb": INF,
			"directions": ["FORWARD", "REVERSE"]}
	if class_name_value == "TECHNICAL":
		return {"class": Graph.RouteClass.TECHNICAL, "grade": Policy.grade_hard(Graph.RouteClass.TECHNICAL), "radius": RADIUS_MIN_TECHNICAL_M,
			"climb": FORWARD_CLIMB_TECHNICAL, "directions": ["FORWARD"]}
	return {}


static func _limits_of(record: Dictionary) -> Dictionary:
	return limits("TECHNICAL" if int(record.get("class", TRAIL_CLASS)) == Graph.RouteClass.TECHNICAL else "SINGLETRACK")


static func realize(trail: Dictionary, config: Dictionary, context: Dictionary) -> Dictionary:
	var id: String = trail.id
	var class_limits: Dictionary = limits(str(trail.get("class", "SINGLETRACK")))
	if class_limits.is_empty():
		return _reject(id, "ERR_TRAIL_INPUT", {"stage": "class", "value": str(trail.get("class"))})
	var join_max: float = JOIN_MAX_M
	if trail.has("join_max_m"):
		if not _number(trail.join_max_m) or float(trail.join_max_m) <= 0.0 or float(trail.join_max_m) > JOIN_MAX_EDGE_M:
			return _reject(id, "ERR_TRAIL_INPUT", {"stage": "join_max_m", "value": str(trail.join_max_m)})
		join_max = float(trail.join_max_m)
	var bounds: Dictionary = context.surface.get_bounds_m()
	var size_x: float = bounds.max_x - bounds.min_x
	var size_z: float = bounds.max_z - bounds.min_z
	# Input.
	if not trail.get("mode", "") in MODES or not trail.get("nodes") is Array or trail.nodes.size() != 2 or not trail.get("control_points") is Array or trail.control_points.size() < 2:
		return _reject(id, "ERR_TRAIL_INPUT", {"stage": "fields"})
	var half: Variant = trail.get("half_width_m")
	if not (half is float or half is int) or not is_finite(float(half)) or float(half) < HALF_WIDTH_MIN_M or float(half) > HALF_WIDTH_MAX_M:
		return _reject(id, "ERR_TRAIL_INPUT", {"stage": "half_width_m", "value": str(half)})
	var points: Array[Vector2] = []
	for p: Variant in trail.control_points:
		if not p is Array or p.size() != 2 or not (p[0] is float or p[0] is int) or not (p[1] is float or p[1] is int) or not is_finite(float(p[0])) or not is_finite(float(p[1])):
			return _reject(id, "ERR_TRAIL_INPUT", {"stage": "control point", "value": str(p)})
		var q := Vector2(float(p[0]), float(p[1]))
		if q.x < MARGIN_M or q.y < MARGIN_M or q.x > size_x - MARGIN_M or q.y > size_z - MARGIN_M:
			return _reject(id, "ERR_TRAIL_INPUT", {"stage": "bounds", "point": [q.x, q.y]})
		if not points.is_empty() and q.distance_to(points[points.size() - 1]) < 0.5:
			return _reject(id, "ERR_TRAIL_INPUT", {"stage": "duplicate control point", "point": [q.x, q.y]})
		points.append(q)
	var node_ids: Array[int] = []
	for n: Variant in trail.nodes:
		if not n is Dictionary or not _int_like(n.get("id")) or not (n.get("x_m") is float or n.get("x_m") is int) or not (n.get("z_m") is float or n.get("z_m") is int):
			return _reject(id, "ERR_TRAIL_INPUT", {"stage": "node", "value": str(n)})
		node_ids.append(int(n.id))
	if node_ids[0] == node_ids[1]:
		return _reject(id, "ERR_TRAIL_INPUT", {"stage": "nodes", "value": node_ids})
	# Identity: seed, region and the configured node layout.
	var region: Vector2i = context.region
	if int(config.seed) != int(context.seed) or int(config.region[0]) != region.x or int(config.region[1]) != region.y:
		return _reject(id, "ERR_TRAIL_IDENTITY", {"stage": "seed/region", "config": [config.seed, config.region], "world": [context.seed, [region.x, region.y]]})
	var data: Dictionary = context.network
	var nodes: Dictionary = {}
	for node: Dictionary in data.nodes:
		nodes[node.id] = node
	for k in range(2):
		var expected: Dictionary = trail.nodes[k]
		if not nodes.has(node_ids[k]):
			return _reject(id, "ERR_TRAIL_IDENTITY", {"stage": "node missing", "node": node_ids[k]})
		var node: Dictionary = nodes[node_ids[k]]
		var offset: float = Vector2(node.x_m - float(expected.x_m), node.z_m - float(expected.z_m)).length()
		if offset > NODE_TOLERANCE_M:
			return _reject(id, "ERR_TRAIL_IDENTITY", {"stage": "node moved", "node": node_ids[k], "offset_m": offset})
	# Line.
	var line: Dictionary = _line(points, float(half), context.surface, bounds)
	if not line.is_valid:
		return _reject(id, "ERR_TRAIL_INPUT", line.detail)
	# Connection: a road prefix on a piece of the first node, a road suffix on
	# a piece of the second, and no road in between.
	var n: int = line.s.size()
	var owners: Array[String] = []
	for k in range(n):
		owners.append(context.surface.road_owner(bounds.min_x + line.x[k], bounds.min_z + line.z[k]))
	var first_off: int = 0
	while first_off < n and not owners[first_off].is_empty():
		first_off += 1
	var last_off: int = n - 1
	while last_off >= 0 and not owners[last_off].is_empty():
		last_off -= 1
	if first_off == 0 or last_off == n - 1 or first_off >= last_off:
		return _reject(id, "ERR_TRAIL_CONNECTION", {"stage": "ends on road", "first_off": first_off, "last_off": last_off, "samples": n})
	for k in range(first_off, last_off + 1):
		if not owners[k].is_empty():
			return _reject(id, "ERR_TRAIL_CONNECTION", {"stage": "road between the joins", "s_m": line.s[k], "piece": owners[k]})
	var joins: Array = []
	for end in range(2):
		var node: Dictionary = nodes[node_ids[end]]
		var incident: Dictionary = _incident_pieces(data, node.id)
		var span: Array = range(0, first_off) if end == 0 else range(last_off + 1, n)
		for k: int in span:
			if not incident.has(owners[k]):
				return _reject(id, "ERR_TRAIL_CONNECTION", {"stage": "join on a foreign piece", "node": node.id, "s_m": line.s[k], "piece": owners[k]})
		var k_end: int = 0 if end == 0 else n - 1
		var distance: float = Vector2(line.x[k_end] - node.x_m, line.z[k_end] - node.z_m).length()
		if distance > join_max:
			return _reject(id, "ERR_TRAIL_CONNECTION", {"stage": "join too far from its node", "node": node.id, "distance_m": distance})
		var k_edge: int = first_off if end == 0 else last_off
		joins.append({"node": node.id, "piece": owners[k_end], "end_s_m": line.s[k_end], "leave_s_m": line.s[k_edge], "leave_index": k_edge, "x_m": line.x[k_end],
			"z_m": line.z[k_end], "y_m": line.y[k_end], "node_distance_m": distance})
	# Shaping operation (budgets before riding limits: its interval replaces the
	# NATURAL side-slope screening there).
	var shaped: Dictionary = _operations(trail, line, float(half), first_off, last_off, context, bounds)
	if not shaped.is_valid:
		return _reject(id, shaped.reason_code, shaped.detail)
	# Rideability on the existing surface.
	var check: Dictionary = _rideability(line, float(half), first_off, last_off, context, bounds, _bench(shaped.operations), INF, class_limits)
	if not check.is_valid:
		return _reject(id, "ERR_TRAIL_UNRIDEABLE", check.detail)
	var metrics: Dictionary = check.metrics
	metrics["shaped_length_m"] = 0.0
	for op: Dictionary in shaped.operations:
		metrics.shaped_length_m += op.s1_m - op.s0_m
	metrics["shaped_fraction"] = metrics.shaped_length_m / line.s[n - 1]
	var record := {"id": id, "mode": trail.mode, "class": class_limits["class"], "purpose": str(trail.get("purpose", "")), "nodes": node_ids.duplicate(), "half_width_m": float(half),
		"line": {"s": line.s, "x": line.x, "y": line.y, "z": line.z, "tx": line.tx, "tz": line.tz}, "length_m": line.s[n - 1], "joins": joins,
		"directions": class_limits.directions.duplicate(), "metrics": metrics, "operations": shaped.operations, "config_sha256": JSON.stringify(trail, "", true).sha256_text()}
	return {"is_valid": true, "id": id, "reason_code": "", "detail": {}, "trail": record}


## The configured shaping operation (amendment A1: at most one BENCH), its
## per-sample amplitudes and budget checks. {is_valid, operations} or
## {is_valid: false, reason_code, detail}.
static func _operations(trail: Dictionary, line: Dictionary, half: float, first_off: int, last_off: int, context: Dictionary, bounds: Dictionary) -> Dictionary:
	var configured: Variant = trail.get("operations", [])
	if not configured is Array:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "operations"}}
	if configured.is_empty():
		return {"is_valid": true, "operations": []}
	if configured.size() > 1:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "one operation", "count": configured.size()}}
	var op: Variant = configured[0]
	if not op is Dictionary or op.get("kind", "") != "BENCH" or not _point(op.get("from")) or not _point(op.get("to")) or not _number(op.get("daylight_m")) or not _number(op.get("taper_m")):
		return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "operation fields", "value": str(op)}}
	var daylight: float = float(op.daylight_m)
	var taper: float = float(op.taper_m)
	if daylight < BENCH_DAYLIGHT_RANGE_M.x or daylight > BENCH_DAYLIGHT_RANGE_M.y or taper < BENCH_TAPER_RANGE_M.x or taper > BENCH_TAPER_RANGE_M.y:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "daylight/taper", "daylight_m": daylight, "taper_m": taper}}
	var ends: Array[int] = [_nearest_sample(line, Vector2(float(op.from[0]), float(op.from[1]))), _nearest_sample(line, Vector2(float(op.to[0]), float(op.to[1])))]
	var k0: int = mini(ends[0], ends[1])
	var k1: int = maxi(ends[0], ends[1])
	var s0: float = line.s[k0]
	var s1: float = line.s[k1]
	if k0 <= first_off or k1 >= last_off or k1 - k0 < 2:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "interior", "s0_m": s0, "s1_m": s1}}
	if s1 - s0 > BENCH_MAX_LENGTH_M:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "length", "length_m": s1 - s0, "limit": BENCH_MAX_LENGTH_M}}
	var surface: RefCounted = context.surface
	for k in range(k0, k1 + 1):
		var p := Vector2(line.x[k], line.z[k])
		var normal := Vector2(-line.tz[k], line.tx[k])
		for side: float in [-1.0, 1.0]:
			for reach: float in [half, half + daylight, half + daylight + BENCH_CLEARANCE_M]:
				var q: Vector2 = p + normal * side * reach
				if context.field.sample_water(bounds.min_x + q.x, bounds.min_z + q.y).get("is_water", false):
					return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "water clearance", "s_m": line.s[k], "lateral_m": side * reach}}
				if not surface.road_owner(bounds.min_x + q.x, bounds.min_z + q.y).is_empty():
					return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "road clearance", "s_m": line.s[k], "lateral_m": side * reach}}
				var wx: float = bounds.min_x + q.x
				var wz: float = bounds.min_z + q.y
				var border: float = minf(minf(fposmod(wx, TILE_M), TILE_M - fposmod(wx, TILE_M)), minf(fposmod(wz, TILE_M), TILE_M - fposmod(wz, TILE_M)))
				if reach <= half + daylight and border < BENCH_BORDER_M:
					return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "tile border", "s_m": line.s[k], "border_m": border}}
	var op_record := {"kind": "BENCH", "mode": "SHAPED", "k0": k0, "k1": k1, "s0_m": s0, "s1_m": s1, "daylight_m": daylight, "taper_m": taper}
	var amplitudes: Dictionary = _amplitudes(op_record, line, half, surface, bounds)
	if not amplitudes.is_valid:
		return amplitudes
	op_record.merge(amplitudes.op, true)
	return {"is_valid": true, "operations": [op_record]}


## The bench amplitudes of `op` (k0, k1, s0_m, s1_m, daylight_m, taper_m) on
## `surface` - c(s) the straight fit across the band - with the amplitude
## budgets (|d|, volume). {is_valid, op: {amplitude, metrics}} or a rejection.
static func _amplitudes(op: Dictionary, line: Dictionary, half: float, surface: RefCounted, bounds: Dictionary) -> Dictionary:
	var amplitude := PackedFloat64Array()
	var volume: float = 0.0
	var largest: float = 0.0
	var cross_before: float = 0.0
	for k in range(op.k0, op.k1 + 1):
		var p := Vector2(line.x[k], line.z[k])
		var normal := Vector2(-line.tz[k], line.tx[k])
		var c: Variant = _band_fit(surface, bounds, p, normal, half)
		if c == null:
			return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "bench surface", "s_m": line.s[k]}}
		var f: float = smoothstep(0.0, op.taper_m, line.s[k] - op.s0_m) * smoothstep(0.0, op.taper_m, op.s1_m - line.s[k])
		amplitude.append(c * f)
		cross_before = maxf(cross_before, absf(c))
		largest = maxf(largest, absf(c * f) * half)
		if k > op.k0:
			volume += 0.5 * (absf(amplitude[k - op.k0]) + absf(amplitude[k - op.k0 - 1])) * half * (half + op.daylight_m) * (line.s[k] - line.s[k - 1])
	if largest > BENCH_MAX_DISPLACEMENT_M:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "displacement", "max_m": largest, "limit": BENCH_MAX_DISPLACEMENT_M}}
	if volume > BENCH_MAX_VOLUME_M3:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_BUDGET", "detail": {"stage": "volume", "volume_m3": volume, "limit": BENCH_MAX_VOLUME_M3}}
	return {"is_valid": true, "op": {"amplitude": amplitude, "metrics": {"length_m": op.s1_m - op.s0_m, "max_displacement_m": largest, "volume_m3": volume,
		"cross_before_max": cross_before, "attempts": 1}}}


## Straight fit of the surface across the band at p: (h(+hw) - h(-hw)) / 2hw
## (null off the surface).
static func _band_fit(surface: RefCounted, bounds: Dictionary, p: Vector2, normal: Vector2, half: float) -> Variant:
	var hi: Dictionary = surface.sample_height(bounds.min_x + p.x + normal.x * half, bounds.min_z + p.y + normal.y * half)
	var lo: Dictionary = surface.sample_height(bounds.min_x + p.x - normal.x * half, bounds.min_z + p.y - normal.y * half)
	if not hi.is_valid or not lo.is_valid:
		return null
	return (hi.height_m - lo.height_m) / (2.0 * half)


## A realized trail's bench measured on the published pre-bench surface
## (FinalSurface.with_published of the prototype-off tiles of its zone): the
## amplitudes the tiles are shaped with, budgets checked on them
## (ERR_TRAIL_BUDGET). Trails without a bench come back unchanged.
static func shape(trail: Dictionary, published: RefCounted) -> Dictionary:
	var record: Dictionary = trail.duplicate(true)
	for op: Dictionary in record.operations:
		if op.kind != "BENCH":
			continue
		var made: Dictionary = _amplitudes(op, record.line, record.half_width_m, published, published.get_bounds_m())
		if not made.is_valid:
			return _reject(record.id, made.reason_code, made.detail)
		op.merge(made.op, true)
	return {"is_valid": true, "id": record.id, "reason_code": "", "detail": {}, "trail": record}


## A trail's bench operation ({} without one).
static func _bench(operations: Array) -> Dictionary:
	for op: Dictionary in operations:
		if op.kind == "BENCH":
			return op
	return {}


static func _nearest_sample(line: Dictionary, p: Vector2) -> int:
	var best: int = 0
	var best_d: float = INF
	for k in range(line.s.size()):
		var d: float = Vector2(line.x[k], line.z[k]).distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = k
	return best


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])


## A realized trail on the published surface (FinalSurface.with_published):
## line heights become the final ones and the riding limits are checked again
## on them (ERR_TRAIL_UNRIDEABLE, stage "published ..."). metrics gain
## design_parity_max_m, the largest design-to-published height difference
## along the line. context: as realize().
static func finalize(trail: Dictionary, published: RefCounted, context: Dictionary) -> Dictionary:
	var bounds: Dictionary = published.get_bounds_m()
	var record: Dictionary = trail.duplicate(true)
	var line: Dictionary = record.line
	var heights := PackedFloat64Array()
	var deviation: float = 0.0
	for k in range(line.s.size()):
		var h: Dictionary = published.sample_height(bounds.min_x + line.x[k], bounds.min_z + line.z[k])
		if not h.is_valid:
			return _reject(record.id, "ERR_TRAIL_UNRIDEABLE", {"stage": "published surface", "s_m": line.s[k], "reason": h.reason_code})
		deviation = maxf(deviation, absf(h.height_m - line.y[k]))
		heights.append(h.height_m)
	line.y = heights
	var checked := context.duplicate()
	checked.surface = published
	var check: Dictionary = _rideability(line, record.half_width_m, record.joins[0].leave_index, record.joins[1].leave_index, checked, bounds, _bench(record.operations), BENCH_CROSS_MAX,
		_limits_of(record))
	if not check.is_valid:
		var detail: Dictionary = check.detail.duplicate()
		detail.stage = "published " + str(detail.get("stage", ""))
		return _reject(record.id, "ERR_TRAIL_BUDGET" if detail.get("bench", false) else "ERR_TRAIL_UNRIDEABLE", detail)
	var shaped_length: float = record.metrics.get("shaped_length_m", 0.0)
	record.metrics = check.metrics
	record.metrics["shaped_length_m"] = shaped_length
	record.metrics["shaped_fraction"] = shaped_length / record.length_m
	record.metrics["design_parity_max_m"] = deviation
	for op: Dictionary in record.operations:
		op.metrics["cross_after_max"] = check.bench_cross_max
	record.joins[0].y_m = heights[0]
	record.joins[1].y_m = heights[heights.size() - 1]
	return {"is_valid": true, "id": record.id, "reason_code": "", "detail": {}, "trail": record}


## Edge pieces ending at `node_id` and its movement connectors.
static func _incident_pieces(data: Dictionary, node_id: int) -> Dictionary:
	var out: Dictionary = {}
	for e: Dictionary in data.edges:
		if e.a == node_id or e.b == node_id:
			out[e.piece_id] = true
	for m: Dictionary in data.movements:
		if int(String(m.piece_id).get_slice(":", 1)) == node_id:
			out[m.piece_id] = true
	return out


## Centripetal Catmull-Rom through `points` (mirrored end tangents), resampled
## every SAMPLE_M by arc length (last sample at the curve end); heights from
## the surface. Region-local coordinates.
static func _line(points: Array[Vector2], half: float, surface: RefCounted, bounds: Dictionary) -> Dictionary:
	var dense: Array[Vector2] = []
	var count: int = points.size()
	for i in range(count - 1):
		var p0: Vector2 = points[i - 1] if i > 0 else 2.0 * points[0] - points[1]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[i + 2] if i + 2 < count else 2.0 * points[count - 1] - points[count - 2]
		var t0: float = 0.0
		var t1: float = t0 + sqrt(p0.distance_to(p1))
		var t2: float = t1 + sqrt(p1.distance_to(p2))
		var t3: float = t2 + sqrt(p2.distance_to(p3))
		var steps: int = maxi(8, int(ceil(p1.distance_to(p2) / 0.25)))
		for k in range(steps):
			var t: float = lerpf(t1, t2, float(k) / steps)
			var a1: Vector2 = p0 * (t1 - t) / (t1 - t0) + p1 * (t - t0) / (t1 - t0)
			var a2: Vector2 = p1 * (t2 - t) / (t2 - t1) + p2 * (t - t1) / (t2 - t1)
			var a3: Vector2 = p2 * (t3 - t) / (t3 - t2) + p3 * (t - t2) / (t3 - t2)
			var b1: Vector2 = a1 * (t2 - t) / (t2 - t0) + a2 * (t - t0) / (t2 - t0)
			var b2: Vector2 = a2 * (t3 - t) / (t3 - t1) + a3 * (t - t1) / (t3 - t1)
			dense.append(b1 * (t2 - t) / (t2 - t1) + b2 * (t - t1) / (t2 - t1))
	dense.append(points[count - 1])
	var cumulative := PackedFloat64Array([0.0])
	for k in range(1, dense.size()):
		cumulative.append(cumulative[k - 1] + dense[k].distance_to(dense[k - 1]))
	var total: float = cumulative[cumulative.size() - 1]
	var samples: int = int(ceil(total / SAMPLE_M))
	var out := {"s": PackedFloat64Array(), "x": PackedFloat64Array(), "y": PackedFloat64Array(), "z": PackedFloat64Array(), "tx": PackedFloat64Array(), "tz": PackedFloat64Array()}
	var j: int = 0
	for k in range(samples + 1):
		var s: float = minf(k * SAMPLE_M, total)
		while j < cumulative.size() - 2 and cumulative[j + 1] < s:
			j += 1
		var u: float = (s - cumulative[j]) / maxf(cumulative[j + 1] - cumulative[j], 1e-12)
		var p: Vector2 = dense[j].lerp(dense[j + 1], clampf(u, 0.0, 1.0))
		var h: Dictionary = surface.sample_height(bounds.min_x + p.x, bounds.min_z + p.y)
		if not h.is_valid:
			return {"is_valid": false, "detail": {"stage": "surface", "s_m": s, "reason": h.reason_code}}
		out.s.append(s)
		out.x.append(p.x)
		out.z.append(p.y)
		out.y.append(h.height_m)
	var n: int = out.s.size()
	for k in range(n):
		var a: int = maxi(0, k - 1)
		var b: int = mini(n - 1, k + 1)
		var t := Vector2(out.x[b] - out.x[a], out.z[b] - out.z[a]).normalized()
		out.tx.append(t.x)
		out.tz.append(t.y)
	out["is_valid"] = true
	return out


## Water, decks, grade, pitch, side slope and radius along the realized line.
## Where `bench` (an operation, {} for none) is fully formed (taper 1) the side
## slope limit is `bench_limit` (INF before shaping, BENCH_CROSS_MAX on the
## published bench); its tapers keep the NATURAL limit.
## `class_limits` (limits(); SINGLETRACK when empty): a class with a finite
## climb is checked in its forward direction - rises over the grade window
## above it and a line that does not end lower than it starts are rejected.
static func _rideability(line: Dictionary, half: float, first_off: int, last_off: int, context: Dictionary, bounds: Dictionary, bench: Dictionary = {},
		bench_limit: float = INF, class_limits: Dictionary = {}) -> Dictionary:
	var surface: RefCounted = context.surface
	var field: RefCounted = context.field
	var n: int = line.s.size()
	var chosen: Dictionary = class_limits if not class_limits.is_empty() else limits("SINGLETRACK")
	var grade_max: float = chosen.grade
	var radius_min: float = chosen.radius
	var climb_max: float = chosen.climb
	if is_finite(climb_max) and line.y[n - 1] >= line.y[0]:
		return {"is_valid": false, "detail": {"stage": "direction", "rise_m": line.y[n - 1] - line.y[0]}}
	var decks: Array = _deck_lines(context.network)
	var metrics := {"max_grade": 0.0, "max_pitch_grade": 0.0, "max_cross_slope": 0.0, "min_radius_m": INF, "climb_m": 0.0, "descent_m": 0.0}
	var bench_cross: float = 0.0
	var w: int = int(round(GRADE_WINDOW_M / SAMPLE_M / 2.0))
	var r: int = int(round(RADIUS_WINDOW_M / SAMPLE_M))
	for k in range(n):
		var p := Vector2(line.x[k], line.z[k])
		var normal := Vector2(-line.tz[k], line.tx[k])
		for side: float in [-half, 0.0, half]:
			var q: Vector2 = p + normal * side
			var water: Dictionary = field.sample_water(bounds.min_x + q.x, bounds.min_z + q.y)
			if water.get("is_water", false):
				return {"is_valid": false, "detail": {"stage": "water", "s_m": line.s[k], "lateral_m": side}}
		for deck: Array in decks:
			for m in range(deck[0].size() - 1):
				if Geometry2D.get_closest_point_to_segment(p, deck[0][m], deck[0][m + 1]).distance_to(p) <= deck[1] + half + 2.0:
					return {"is_valid": false, "detail": {"stage": "bridge deck", "s_m": line.s[k]}}
		if k > 0:
			var rise: float = line.y[k] - line.y[k - 1]
			var pitch: float = absf(rise) / maxf(line.s[k] - line.s[k - 1], 1e-9)
			metrics.max_pitch_grade = maxf(metrics.max_pitch_grade, pitch)
			metrics.climb_m += maxf(rise, 0.0)
			metrics.descent_m += maxf(-rise, 0.0)
			if pitch > PITCH_GRADE_MAX:
				return {"is_valid": false, "detail": {"stage": "pitch", "s_m": line.s[k], "grade": pitch}}
		var a: int = maxi(0, k - w)
		var b: int = mini(n - 1, k + w)
		if b > a:
			var grade: float = absf(line.y[b] - line.y[a]) / (line.s[b] - line.s[a])
			metrics.max_grade = maxf(metrics.max_grade, grade)
			if grade > grade_max:
				return {"is_valid": false, "detail": {"stage": "grade", "s_m": line.s[k], "grade": grade, "limit": grade_max}}
			if is_finite(climb_max):
				var climb: float = (line.y[b] - line.y[a]) / (line.s[b] - line.s[a])
				metrics["max_forward_climb"] = maxf(metrics.get("max_forward_climb", 0.0), climb)
				if climb > climb_max and k >= first_off and k <= last_off:
					return {"is_valid": false, "detail": {"stage": "forward climb", "s_m": line.s[k], "grade": climb, "limit": climb_max}}
		if k >= first_off and k <= last_off:
			var g: Dictionary = surface.sample_gradient(bounds.min_x + p.x, bounds.min_z + p.y)
			if not g.is_valid:
				return {"is_valid": false, "detail": {"stage": "gradient", "s_m": line.s[k]}}
			var cross: float = absf(g.gradient.dot(normal))
			var on_bench: bool = not bench.is_empty() and line.s[k] >= bench.s0_m and line.s[k] <= bench.s1_m and 				smoothstep(0.0, bench.taper_m, line.s[k] - bench.s0_m) * smoothstep(0.0, bench.taper_m, bench.s1_m - line.s[k]) >= 0.999
			if on_bench:
				# The bench levels the band: its side slope is the band fit.
				var fit: Variant = _band_fit(surface, bounds, p, normal, half)
				cross = absf(fit) if fit != null else INF
			var limit: float = bench_limit if on_bench else CROSS_SLOPE_MAX
			if on_bench:
				bench_cross = maxf(bench_cross, cross)
			else:
				metrics.max_cross_slope = maxf(metrics.max_cross_slope, cross)
			if cross > limit:
				return {"is_valid": false, "detail": {"stage": "side slope", "s_m": line.s[k], "slope": cross, "limit": limit, "bench": on_bench}}
		if k - r >= 0 and k + r < n:
			var pa := Vector2(line.x[k - r], line.z[k - r])
			var pc := Vector2(line.x[k + r], line.z[k + r])
			var area: float = (p - pa).cross(pc - pa)
			var denominator: float = pa.distance_to(p) * p.distance_to(pc) * pa.distance_to(pc)
			var radius: float = denominator / maxf(2.0 * absf(area), 1e-12)
			metrics.min_radius_m = minf(metrics.min_radius_m, radius)
			if radius < radius_min:
				return {"is_valid": false, "detail": {"stage": "radius", "s_m": line.s[k], "radius_m": radius, "limit": radius_min}}
	return {"is_valid": true, "metrics": metrics, "bench_cross_max": bench_cross}


## Centre lines and half widths of declared bridge decks: [[Vector2...], half].
static func _deck_lines(data: Dictionary) -> Array:
	var designs: Dictionary = {}
	for piece: Dictionary in data.pieces:
		designs[piece.id] = piece.design
	var out: Array = []
	for c: Dictionary in data.crossings:
		if c.get("support", "") != "BRIDGE_DECK" or not c.has("deck_span_m"):
			continue
		var d: Dictionary = designs.get("edge:%d" % c.edge_id, {})
		if d.is_empty():
			continue
		var line: Array[Vector2] = []
		var widest: float = 0.0
		for k in range(d.s.size()):
			if d.s[k] >= c.deck_span_m[0] - 0.001 and d.s[k] <= c.deck_span_m[1] + 0.001:
				line.append(Vector2(d.x[k], d.z[k]))
				widest = maxf(widest, d.width[k] / 2.0)
		if line.size() >= 2:
			out.append([line, widest])
	return out


static func _int_like(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floorf(value))


static func _reject(id: String, reason: String, detail: Dictionary) -> Dictionary:
	return {"is_valid": false, "id": id, "reason_code": reason, "detail": detail, "trail": {}}
