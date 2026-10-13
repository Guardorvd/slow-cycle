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
## (ERR_TRAIL_BUDGET belongs to the shaping operations of a later mode.)
##
## Configuration (JSON object):
##   {"schema": SCHEMA, "seed": int, "region": [x, z], "trails": [{
##     "id": "trail:<name>", "mode": "NATURAL", "purpose": text,
##     "nodes": [{"id": int, "x_m": float, "z_m": float}, {...}]   (region-local),
##     "half_width_m": float, "control_points": [[x_m, z_m], ...]  (region-local)}]}

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
## PROVISIONAL screening limits for the first BC1 line, not NATURAL norms:
## grade over GRADE_WINDOW_M and radius over +-RADIUS_WINDOW_M reuse the
## SINGLETRACK/R6 class values (10 deg, 19 m) as conservative stand-ins; side
## slope of the untouched ground across the band (no benching in NATURAL);
## short pitches over one sample (road shoulders and earthwork the trail
## crosses at its joins). Real two-way rideability is established by Input
## rides of the existing BicycleController (BC1 runtime check), and NATURAL
## norms are owned by BC2.
const GRADE_WINDOW_M: float = 4.0
const RADIUS_WINDOW_M: float = 3.0
const CROSS_SLOPE_MAX: float = 0.35
const PITCH_GRADE_MAX: float = 0.30


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


static func realize(trail: Dictionary, config: Dictionary, context: Dictionary) -> Dictionary:
	var id: String = trail.id
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
		if distance > JOIN_MAX_M:
			return _reject(id, "ERR_TRAIL_CONNECTION", {"stage": "join too far from its node", "node": node.id, "distance_m": distance})
		var k_edge: int = first_off if end == 0 else last_off
		joins.append({"node": node.id, "piece": owners[k_end], "end_s_m": line.s[k_end], "leave_s_m": line.s[k_edge], "leave_index": k_edge, "x_m": line.x[k_end],
			"z_m": line.z[k_end], "y_m": line.y[k_end], "node_distance_m": distance})
	# Rideability on the existing surface.
	var check: Dictionary = _rideability(line, float(half), first_off, last_off, context, bounds)
	if not check.is_valid:
		return _reject(id, "ERR_TRAIL_UNRIDEABLE", check.detail)
	var record := {"id": id, "mode": trail.mode, "class": TRAIL_CLASS, "purpose": str(trail.get("purpose", "")), "nodes": node_ids.duplicate(), "half_width_m": float(half),
		"line": {"s": line.s, "x": line.x, "y": line.y, "z": line.z, "tx": line.tx, "tz": line.tz}, "length_m": line.s[n - 1], "joins": joins,
		"directions": ["FORWARD", "REVERSE"], "metrics": check.metrics, "operations": [], "config_sha256": JSON.stringify(trail, "", true).sha256_text()}
	return {"is_valid": true, "id": id, "reason_code": "", "detail": {}, "trail": record}


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
	var check: Dictionary = _rideability(line, record.half_width_m, record.joins[0].leave_index, record.joins[1].leave_index, checked, bounds)
	if not check.is_valid:
		var detail: Dictionary = check.detail.duplicate()
		detail.stage = "published " + str(detail.get("stage", ""))
		return _reject(record.id, "ERR_TRAIL_UNRIDEABLE", detail)
	record.metrics = check.metrics
	record.metrics["design_parity_max_m"] = deviation
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
static func _rideability(line: Dictionary, half: float, first_off: int, last_off: int, context: Dictionary, bounds: Dictionary) -> Dictionary:
	var surface: RefCounted = context.surface
	var field: RefCounted = context.field
	var n: int = line.s.size()
	var grade_max: float = Policy.grade_hard(TRAIL_CLASS)
	var radius_min: float = Policy.CLASSES[TRAIL_CLASS].radius_hard_m
	var decks: Array = _deck_lines(context.network)
	var metrics := {"max_grade": 0.0, "max_pitch_grade": 0.0, "max_cross_slope": 0.0, "min_radius_m": INF, "climb_m": 0.0, "descent_m": 0.0}
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
		if k >= first_off and k <= last_off:
			var g: Dictionary = surface.sample_gradient(bounds.min_x + p.x, bounds.min_z + p.y)
			if not g.is_valid:
				return {"is_valid": false, "detail": {"stage": "gradient", "s_m": line.s[k]}}
			var cross: float = absf(g.gradient.dot(normal))
			metrics.max_cross_slope = maxf(metrics.max_cross_slope, cross)
			if cross > CROSS_SLOPE_MAX:
				return {"is_valid": false, "detail": {"stage": "side slope", "s_m": line.s[k], "slope": cross, "limit": CROSS_SLOPE_MAX}}
		if k - r >= 0 and k + r < n:
			var pa := Vector2(line.x[k - r], line.z[k - r])
			var pc := Vector2(line.x[k + r], line.z[k + r])
			var area: float = (p - pa).cross(pc - pa)
			var denominator: float = pa.distance_to(p) * p.distance_to(pc) * pa.distance_to(pc)
			var radius: float = denominator / maxf(2.0 * absf(area), 1e-12)
			metrics.min_radius_m = minf(metrics.min_radius_m, radius)
			if radius < radius_min:
				return {"is_valid": false, "detail": {"stage": "radius", "s_m": line.s[k], "radius_m": radius, "limit": radius_min}}
	return {"is_valid": true, "metrics": metrics}


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
