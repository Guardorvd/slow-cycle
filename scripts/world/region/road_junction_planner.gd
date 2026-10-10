class_name RoadJunctionPlanner
extends RefCounted

## R6 shared junction planning (ExecPlan §7 + Director C1). For each R5
## junction node (degree 3-4), inside one synthesis invocation:
##   * one node-owned support patch: a plane fitted to the natural surface
##     around the node, gently graded (|G| <= PATCH_GRADE_MAX), never an
##     artificial flat platform on a slope, with bounded cut/fill;
##   * one port per incident edge at a common radius on that edge's reference
##     inside its band; edge interiors start / end exactly at the port with the
##     plane's height, directional grade and crossfall, curvature 0;
##   * one canonical connector per unordered pair of incident edges, lying on
##     the shared plane, G2 with zero curvature at both ports; geometric limits
##     from the stricter class of the two edges.
## Every movement is READY or UNAVAILABLE with its measured reason. Essential
## movements (route continuity: consecutive edges of one R5 route, and for any
## other edge at least one movement to a class it may rely on) decide the
## port radius: the smallest radius of PORT_RADII_M at which all essential
## movements fit. Nonessential turn movements never block usable edges (C1);
## a junction with any unavailable movement is not READY. The graph is never
## mutated.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const Geo = preload("res://scripts/world/region/road_corridor_geometry.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const RoadMath = preload("res://scripts/world/road_math.gd")

const CONNECTOR_LENGTH_FACTORS: Array[float] = [0.9, 1.0, 1.15, 1.3, 1.5]
## Analytic corner connector: share of the retained curvature-change limit used
## by its clothoids, candidate radii between the class preference and limit,
## integration step and knot spacing (m).
const CORNER_DK_SHARE: float = 0.9
const CORNER_RADIUS_STEPS: int = 6
const CORNER_STEP_M: float = 0.25
const CORNER_KNOT_M: float = 5.0

var natural: Geo.Natural
var fit_evaluations: int = 0


static func create(natural_: Geo.Natural) -> RoadJunctionPlanner:
	var planner := RoadJunctionPlanner.new()
	planner.natural = natural_
	return planner


## node: R5 node record; incident: [{edge_id, class, band (Geo.Band), at_start
## (node is the edge's a end), route_id}], sorted by edge id; routes: R5 route
## records. Returns the junction record (ports, patch, movements, connector
## designs) with status READY / USABLE / BLOCKED.
func plan_junction(node: Dictionary, incident: Array, routes: Array) -> Dictionary:
	var cx: float = node.x_cm / 100.0
	var cz: float = node.z_cm / 100.0
	var record := {"node_id": node.id, "x": cx, "z": cz, "status": Policy.JUNCTION_BLOCKED, "reasons": [], "ports": [], "movements": [], "patch": {}}
	# Shared plane fitted to natural heights on rings around the node, graded
	# up to the stricter incident class's preferred grade (C1).
	var grade_cap: float = Policy.PATCH_GRADE_MAX
	for inc: Dictionary in incident:
		grade_cap = minf(grade_cap, Policy.CLASSES[inc.class].grade_pref)
	var fit: Dictionary = _plane(cx, cz, grade_cap)
	if not fit.is_valid:
		record.reasons.append("ERR_R6_JUNCTION_HEIGHT")
		record.patch = fit
		return record
	var essential: Array = _essential_pairs(incident, routes)
	# Per-edge port radii: all start at the smallest admissible radius; while
	# an essential movement fails, the radii of the edges it involves grow to
	# the next PORT_RADII_M value (bounded; a recorded R5 crossing near the
	# node caps that edge's radius so ports stay out of the watercourse).
	var radii: Dictionary = {}
	var caps: Dictionary = {}
	for inc: Dictionary in incident:
		var cap: float = inc.get("radius_cap", INF)
		caps[inc.edge_id] = cap
		radii[inc.edge_id] = -1.0
		for r: float in Policy.PORT_RADII_M:
			if r <= cap:
				radii[inc.edge_id] = r
				break
		if radii[inc.edge_id] < 0.0:
			radii[inc.edge_id] = Policy.PORT_RADII_M[0]
			if not "ERR_R6_CROSSING_APPROACH" in record.reasons:
				record.reasons.append("ERR_R6_CROSSING_APPROACH")
			record["note"] = "R5 crossing within %.1f m of the node on edge %d: no admissible port radius" % [cap + 10.0, inc.edge_id]
	var best: Dictionary = {}
	var attempts: Array = []
	for iteration in range(2 * Policy.PORT_RADII_M.size()):
		var attempt: Dictionary = _attempt(record, fit, incident, essential, radii)
		var ready: int = 0
		var summary: Array = []
		for movement: Dictionary in attempt.movements:
			ready += 1 if movement.status == Policy.MOVEMENT_READY else 0
			summary.append([movement.key, movement.status, movement.reasons.duplicate()])
		attempt["ready"] = ready
		attempts.append({"radii": attempt.radii.duplicate(), "essential_ok": attempt.essential_ok, "movements": summary})
		# Best: most essential movements, then most movements, then the first.
		if best.is_empty() or attempt.essential_ok > best.essential_ok or (attempt.essential_ok == best.essential_ok and ready > best.ready):
			best = attempt
		if attempt.essential_ok == essential.size() and ready == attempt.movements.size():
			break
		var grown: bool = false
		var to_grow: Array = attempt.failing_edges
		if to_grow.is_empty():
			# Essentials fit: try to make the remaining turn movements fit too.
			var extra: Dictionary = {}
			for movement: Dictionary in attempt.movements:
				if movement.status != Policy.MOVEMENT_READY:
					extra[movement.edges[0]] = true
					extra[movement.edges[1]] = true
			to_grow = extra.keys()
			to_grow.sort()
		for edge_id: int in to_grow:
			var current: float = radii[edge_id]
			for r: float in Policy.PORT_RADII_M:
				if r > current and r <= caps[edge_id]:
					radii[edge_id] = r
					grown = true
					break
		if not grown:
			break
	record.ports = best.ports
	record.movements = best.movements
	record.patch = best.patch
	record["port_radii_m"] = best.radii
	record["essential_pairs"] = essential
	record["attempts"] = attempts
	if not best.patch_ok:
		record.reasons.append("ERR_R6_JUNCTION_HEIGHT")
	var all_ready: bool = true
	var essential_ready: bool = true
	for movement: Dictionary in record.movements:
		if movement.status != Policy.MOVEMENT_READY:
			all_ready = false
			if movement.essential:
				essential_ready = false
	if not best.patch_ok or not essential_ready or "ERR_R6_CROSSING_APPROACH" in record.reasons:
		record.status = Policy.JUNCTION_BLOCKED
	elif not all_ready:
		record.status = Policy.JUNCTION_USABLE
	else:
		record.status = Policy.JUNCTION_READY
	if not all_ready:
		record.reasons.append("ERR_R6_JUNCTION_MOVEMENT")
	return record


## Least-squares plane through natural heights on three rings (10/20/30 m)
## plus the node; gradient capped at grade_cap (gentle grading, C1).
func _plane(cx: float, cz: float, grade_cap: float) -> Dictionary:
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var hs := PackedFloat64Array()
	var points: Array = [[0.0, 0.0]]
	for ring: float in [10.0, 20.0, 30.0]:
		for q in range(Policy.PATCH_RING_SAMPLES):
			var a: float = TAU * q / Policy.PATCH_RING_SAMPLES
			points.append([ring * cos(a), ring * sin(a)])
	for p: Array in points:
		var h: float = natural.height(clampf(cx + p[0], 0.0, Geo.DOMAIN_M), clampf(cz + p[1], 0.0, Geo.DOMAIN_M))
		if not is_finite(h):
			return {"is_valid": false, "reason_code": "ERR_R6_JUNCTION_HEIGHT", "note": "natural height unavailable"}
		xs.append(p[0])
		zs.append(p[1])
		hs.append(h)
	var n: int = hs.size()
	var mean_h: float = 0.0
	for h: float in hs:
		mean_h += h
	mean_h /= n
	var sxx: float = 0.0
	var szz: float = 0.0
	var sxz: float = 0.0
	var sxh: float = 0.0
	var szh: float = 0.0
	for i in range(n):
		sxx += xs[i] * xs[i]
		szz += zs[i] * zs[i]
		sxz += xs[i] * zs[i]
		sxh += xs[i] * (hs[i] - mean_h)
		szh += zs[i] * (hs[i] - mean_h)
	var det: float = sxx * szz - sxz * sxz
	var gx: float = (sxh * szz - szh * sxz) / det
	var gz: float = (szh * sxx - sxh * sxz) / det
	var natural_grade: float = sqrt(gx * gx + gz * gz)
	if natural_grade > grade_cap:
		gx *= grade_cap / natural_grade
		gz *= grade_cap / natural_grade
	var y0: float = 0.0
	for i in range(n):
		y0 += hs[i] - gx * xs[i] - gz * zs[i]
	y0 /= n
	return {"is_valid": true, "y0": y0, "gx": gx, "gz": gz, "natural_grade": natural_grade, "grade_cap": grade_cap}


static func plane_height(fit: Dictionary, cx: float, cz: float, x: float, z: float) -> float:
	return fit.y0 + fit.gx * (x - cx) + fit.gz * (z - cz)


## Pairs (edge ids, ascending) whose movement is essential for continuity.
static func _essential_pairs(incident: Array, routes: Array) -> Array:
	var ids: Array = []
	for inc: Dictionary in incident:
		ids.append(inc.edge_id)
	var pairs: Dictionary = {}
	for route: Dictionary in routes:
		var list: PackedInt32Array = route.edge_ids
		for m in range(list.size() - 1):
			if list[m] in ids and list[m + 1] in ids:
				pairs[_pair_key(list[m], list[m + 1])] = true
	# Any edge without a route-through pair: one movement to an edge of a class
	# it may rely on (chosen later as the easiest feasible), recorded as a group.
	var result: Array = []
	for key: String in pairs:
		var parts: PackedStringArray = key.split("-")
		result.append({"kind": "ROUTE_THROUGH", "pair": [int(parts[0]), int(parts[1])]})
	for inc: Dictionary in incident:
		var covered: bool = false
		for key: String in pairs:
			var parts: PackedStringArray = key.split("-")
			covered = covered or int(parts[0]) == inc.edge_id or int(parts[1]) == inc.edge_id
		if covered:
			continue
		var options: Array = []
		for other: Dictionary in incident:
			if other.edge_id != inc.edge_id and other.class in Graph.RELIES_ON[inc.class]:
				options.append(other.edge_id)
		result.append({"kind": "CONNECT_ANY", "edge": inc.edge_id, "options": options})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a) < str(b))
	return result


static func _pair_key(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


static func movement_piece_id(node_id: int, a: int, b: int) -> String:
	return "move:%d:%d-%d" % [node_id, mini(a, b), maxi(a, b)]


static func port_id(node_id: int, edge_id: int) -> String:
	return "port:%d:%d" % [node_id, edge_id]


func _attempt(record: Dictionary, fit: Dictionary, incident: Array, essential: Array, radii: Dictionary) -> Dictionary:
	var cx: float = record.x
	var cz: float = record.z
	var result := {"radii": radii.duplicate(), "ports": [], "movements": [], "patch": {}, "patch_ok": true, "essential_ok": 0, "failing_edges": []}
	# Ports on each incident reference at arc distance radius_e from the node.
	var ports: Dictionary = {}
	for inc: Dictionary in incident:
		var band: Geo.Band = inc.band
		var radius: float = radii[inc.edge_id]
		var u: float = radius if inc.at_start else band.length() - radius
		var p: PackedFloat64Array = band.at_u(u)
		var dx: float = p[0] - cx
		var dz: float = p[1] - cz
		var length: float = sqrt(dx * dx + dz * dz)
		var tx: float = dx / length
		var tz: float = dz / length
		var y: float = plane_height(fit, cx, cz, p[0], p[1])
		var grade: float = fit.gx * tx + fit.gz * tz
		var port := {"port_id": port_id(record.node_id, inc.edge_id), "edge_id": inc.edge_id, "class": inc.class, "x": p[0], "z": p[1], "y": y, "tx": tx, "tz": tz,
			"grade_out": grade, "bank_out_deg": bank_on_plane(fit, tx, tz), "radius_m": radius, "clearance_m": band.clearance(p[0], p[1], -1)[0]}
		ports[inc.edge_id] = port
		result.ports.append(port)
	# Movements.
	var feasible: Dictionary = {}
	for i in range(incident.size()):
		for j in range(i + 1, incident.size()):
			var a: Dictionary = incident[i]
			var b: Dictionary = incident[j]
			var movement: Dictionary = _connector(record, fit, ports[a.edge_id], ports[b.edge_id], a, b, incident)
			result.movements.append(movement)
			feasible[_pair_key(a.edge_id, b.edge_id)] = movement.status == Policy.MOVEMENT_READY
	var failing: Dictionary = {}
	for item: Dictionary in essential:
		if item.kind == "ROUTE_THROUGH":
			if feasible.get(_pair_key(item.pair[0], item.pair[1]), false):
				result.essential_ok += 1
			else:
				failing[item.pair[0]] = true
				failing[item.pair[1]] = true
		else:
			var any: bool = false
			for other: int in item.options:
				any = any or feasible.get(_pair_key(item.edge, other), false)
			if any:
				result.essential_ok += 1
			else:
				failing[item.edge] = true
				for other: int in item.options:
					failing[other] = true
	var failing_edges: Array = failing.keys()
	failing_edges.sort()
	result.failing_edges = failing_edges
	# Mark essential movements (route-through, plus the easiest feasible
	# CONNECT_ANY option or, if none is feasible, all its options).
	var essential_keys: Dictionary = {}
	for item: Dictionary in essential:
		if item.kind == "ROUTE_THROUGH":
			essential_keys[_pair_key(item.pair[0], item.pair[1])] = item.kind
		else:
			var chosen: String = ""
			var chosen_k: float = INF
			for other: int in item.options:
				var key: String = _pair_key(item.edge, other)
				for movement: Dictionary in result.movements:
					if movement.key == key and movement.status == Policy.MOVEMENT_READY and movement.max_curvature < chosen_k:
						chosen_k = movement.max_curvature
						chosen = key
			if chosen.is_empty():
				for other: int in item.options:
					essential_keys[_pair_key(item.edge, other)] = "CONNECT_ANY"
			else:
				essential_keys[chosen] = "CONNECT_ANY"
	for movement: Dictionary in result.movements:
		movement["essential"] = essential_keys.has(movement.key)
		movement["essential_kind"] = essential_keys.get(movement.key, "TURN")
	# Shared patch: the plane under every READY connector ribbon (exact natural
	# heights every ~4 m on centre and both edges). A movement whose ribbon
	# needs more cut/fill than its stricter class allows is unavailable; the
	# patch itself reports its measured extremes (gently graded plane, C1).
	var max_cut: float = 0.0
	var max_fill: float = 0.0
	var samples: Array = []
	var reach: float = 0.0
	for movement: Dictionary in result.movements:
		if movement.status != Policy.MOVEMENT_READY:
			continue
		var cls: Dictionary = Policy.CLASSES[movement.limit_class]
		var d: Dictionary = movement.design
		var m_cut: float = 0.0
		var m_fill: float = 0.0
		var next_s: float = 0.0
		for i in range(d.s.size()):
			if d.s[i] < next_s and i != d.s.size() - 1:
				continue
			next_s = d.s[i] + 4.0
			var half: float = 0.5 * d.width[i]
			for o: float in [0.0, half, -half]:
				var x: float = d.x[i] - d.tz[i] * o
				var z: float = d.z[i] + d.tx[i] * o
				if not Geo.Natural.in_domain(x, z):
					continue
				var h: float = natural.height(x, z)
				var y: float = plane_height(fit, cx, cz, x, z)
				m_cut = maxf(m_cut, h - y)
				m_fill = maxf(m_fill, y - h)
				samples.append([x, z, h, y])
				reach = maxf(reach, Vector2(x - cx, z - cz).length())
		movement["patch_cut_m"] = m_cut
		movement["patch_fill_m"] = m_fill
		if m_cut > cls.cut_max_m or m_fill > cls.fill_max_m:
			movement.status = Policy.MOVEMENT_UNAVAILABLE
			movement.reasons.append("ERR_R6_JUNCTION_HEIGHT")
			movement.erase("design")
			continue
		max_cut = maxf(max_cut, m_cut)
		max_fill = maxf(max_fill, m_fill)
	var strict_cut: float = INF
	var strict_fill: float = INF
	for inc: Dictionary in incident:
		strict_cut = minf(strict_cut, Policy.CLASSES[inc.class].cut_max_m)
		strict_fill = minf(strict_fill, Policy.CLASSES[inc.class].fill_max_m)
	result.patch = {"y0": fit.y0, "gx": fit.gx, "gz": fit.gz, "natural_grade": fit.natural_grade, "radius_m": reach, "max_cut_m": max_cut, "max_fill_m": max_fill,
		"cut_limit_m": strict_cut, "fill_limit_m": strict_fill, "samples": samples}
	# Recount essential availability after the patch check.
	var ready: Dictionary = {}
	for movement: Dictionary in result.movements:
		ready[movement.key] = movement.status == Policy.MOVEMENT_READY
	var ok: int = 0
	for item: Dictionary in essential:
		if item.kind == "ROUTE_THROUGH":
			ok += 1 if ready.get(_pair_key(item.pair[0], item.pair[1]), false) else 0
		else:
			var any: bool = false
			for other: int in item.options:
				any = any or ready.get(_pair_key(item.edge, other), false)
			ok += 1 if any else 0
	result.essential_ok = ok
	return result


## Crossfall (bank) of a travel direction on the plane: rotation of the
## RoadMath base normal about the 3D tangent that yields the plane normal.
static func bank_on_plane(fit: Dictionary, tx: float, tz: float) -> float:
	var grade: float = fit.gx * tx + fit.gz * tz
	var tangent := Vector3(tx, grade, tz).normalized()
	var base: Vector3 = RoadMath.compute_ortho_normal(tangent, 0.0)
	var plane_normal := Vector3(-fit.gx, 1.0, -fit.gz).normalized()
	var side: Vector3 = tangent.cross(base)
	return rad_to_deg(atan2(plane_normal.dot(side), plane_normal.dot(base)))


## Canonical connector from port a (travelling into the node) to port b
## (travelling out), lowest edge id first. Samples carry the design arrays
## used for edges, on the shared plane.
func _connector(record: Dictionary, fit: Dictionary, pa: Dictionary, pb: Dictionary, a: Dictionary, b: Dictionary, incident: Array) -> Dictionary:
	var key: String = _pair_key(a.edge_id, b.edge_id)
	var stricter: int = mini(a.class, b.class)
	var k_hard: float = Policy.curvature_hard(stricter)
	var movement := {"key": key, "piece_id": movement_piece_id(record.node_id, a.edge_id, b.edge_id), "edges": [a.edge_id, b.edge_id], "status": Policy.MOVEMENT_UNAVAILABLE,
		"reasons": [], "limit_class": stricter, "max_curvature": INF, "design": {}}
	var chord: float = Vector2(pb.x - pa.x, pb.z - pa.z).length()
	var turn_deg: float = rad_to_deg(absf(RMath.wrap_angle(atan2(pb.tz, pb.tx) - atan2(-pa.tz, -pa.tx))))
	movement["turn_deg"] = turn_deg
	# Candidates: the 2-knot quintic at a few lengths, and the analytic corner
	# (straight leads, clothoid - arc - clothoid) where it fits inside the ports.
	var candidates: Array = []
	for factor: float in CONNECTOR_LENGTH_FACTORS:
		fit_evaluations += 1
		var spline := RMath.PlanSpline.new()
		spline.kx = PackedFloat64Array([pa.x, pb.x])
		spline.kz = PackedFloat64Array([pa.z, pb.z])
		spline.ktx = PackedFloat64Array([-pa.tx, pb.tx])
		spline.ktz = PackedFloat64Array([-pa.tz, pb.tz])
		spline.kk = PackedFloat64Array([0.0, 0.0])
		spline.span_param = PackedFloat64Array([chord * factor])
		spline.build()
		var stats: Dictionary = _spline_stats(spline)
		if stats.is_valid:
			candidates.append({"spline": spline, "k": stats.k, "dk": stats.dk})
	var corner: RMath.PlanSpline = _corner_spline(pa, pb, record.x, record.z, stricter)
	if corner != null:
		var corner_stats: Dictionary = _spline_stats(corner)
		if corner_stats.is_valid:
			candidates.append({"spline": corner, "k": corner_stats.k, "dk": corner_stats.dk})
	if candidates.is_empty():
		movement.reasons.append("ERR_R6_FRAME")
		return movement
	candidates.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		return p.k + (1.0 if p.dk > Policy.MAX_CURVATURE_CHANGE_PER_M2 else 0.0) < q.k + (1.0 if q.dk > Policy.MAX_CURVATURE_CHANGE_PER_M2 else 0.0))
	# First candidate that satisfies curvature and band clearance; otherwise the
	# lowest-curvature one reports its reasons.
	var hf: float = maxf(Policy.half_footprint(a.class), Policy.half_footprint(b.class))
	var chosen: Dictionary = candidates[0]
	var chosen_check: Dictionary = {}
	for candidate: Dictionary in candidates:
		var check: Dictionary = _connector_check(candidate, k_hard, hf, incident)
		if chosen_check.is_empty():
			chosen = candidate
			chosen_check = check
		if check.reasons.is_empty():
			chosen = candidate
			chosen_check = check
			break
	var best_spline: RMath.PlanSpline = chosen.spline
	movement.max_curvature = chosen.k
	movement["max_dk_ds"] = chosen.dk
	movement["length_m"] = best_spline.total_length
	if chosen.k > k_hard + 1e-9:
		movement["detail"] = {"min_radius_m": 1.0 / maxf(chosen.k, 1e-9), "required_radius_m": 1.0 / k_hard, "turn_deg": turn_deg}
	if chosen.dk > Policy.MAX_CURVATURE_CHANGE_PER_M2:
		movement["detail_dk"] = chosen.dk
	movement.reasons.append_array(chosen_check.reasons)
	movement["min_clearance_m"] = chosen_check.worst
	# No water under the connector ribbon (centre and edges, exact).
	if movement.reasons.is_empty():
		var wet: int = 0
		var steps3: int = maxi(4, ceili(best_spline.total_length / 2.0))
		for q in range(steps3 + 1):
			var e: PackedFloat64Array = best_spline.eval_s(best_spline.total_length * q / steps3)
			for o: float in [0.0, hf, -hf]:
				var w: Dictionary = natural.water_exact(e[0] - e[3] * o, e[1] + e[2] * o)
				if w.is_valid and w.is_water:
					wet += 1
		if wet > 0:
			movement.reasons.append("ERR_R6_WATER_OCCUPANCY")
			movement["wet_samples"] = wet
	if movement.reasons.is_empty():
		movement.status = Policy.MOVEMENT_READY
		movement.design = _connector_design(record, fit, best_spline, pa, pb, a, b)
	return movement


## Peak curvature and curvature change of a connector spline sampled at 0.5 m.
func _spline_stats(spline: RMath.PlanSpline) -> Dictionary:
	var max_k: float = 0.0
	var max_dk: float = 0.0
	var steps: int = maxi(8, ceili(spline.total_length / 0.5))
	for q in range(steps + 1):
		var e: PackedFloat64Array = spline.eval_s(spline.total_length * q / steps)
		if not is_finite(e[4]):
			return {"is_valid": false}
		max_k = maxf(max_k, absf(e[4]))
		max_dk = maxf(max_dk, absf(e[5]))
	return {"is_valid": true, "k": max_k, "dk": max_dk}


## Curvature, curvature-change and band-clearance reasons of a connector candidate.
func _connector_check(candidate: Dictionary, k_hard: float, hf: float, incident: Array) -> Dictionary:
	var reasons: Array = []
	if candidate.k > k_hard + 1e-9 or candidate.dk > Policy.MAX_CURVATURE_CHANGE_PER_M2:
		reasons.append("ERR_R6_JUNCTION_MOVEMENT")
	var spline: RMath.PlanSpline = candidate.spline
	var steps: int = maxi(8, ceili(spline.total_length / 1.0))
	var worst: float = INF
	for q in range(1, steps):
		var e: PackedFloat64Array = spline.eval_s(spline.total_length * q / steps)
		var c: float = -INF
		for inc: Dictionary in incident:
			c = maxf(c, inc.band.clearance(e[0], e[1], -1)[0])
		worst = minf(worst, c)
	if worst < hf:
		reasons.append("ERR_R6_CORRIDOR_CLEARANCE")
	return {"reasons": reasons, "worst": worst}


## Analytic corner through the node: a straight lead on each port line, then a
## clothoid - circular arc - clothoid of the corner's deflection with the
## largest radius (from the stricter class's preference down to its limit) whose
## tangent length fits inside the shorter port radius. Curvature rises and falls
## at CORNER_DK_SHARE of the retained curvature-change limit and is zero at both
## ports. Returns a G2 spline or null when no radius fits.
func _corner_spline(pa: Dictionary, pb: Dictionary, cx: float, cz: float, stricter: int) -> RMath.PlanSpline:
	var dax: float = -pa.tx
	var daz: float = -pa.tz
	var dbx: float = pb.tx
	var dbz: float = pb.tz
	var theta_a: float = atan2(daz, dax)
	var signed: float = RMath.wrap_angle(atan2(dbz, dbx) - theta_a)
	var delta: float = absf(signed)
	if delta < deg_to_rad(2.0) or delta > deg_to_rad(172.0):
		return null
	var sgn: float = 1.0 if signed > 0.0 else -1.0
	var ra: float = Vector2(pa.x - cx, pa.z - cz).length()
	var rb: float = Vector2(pb.x - cx, pb.z - cz).length()
	var available: float = minf(ra, rb) - 0.5
	var cls: Dictionary = Policy.CLASSES[stricter]
	var dk_limit: float = CORNER_DK_SHARE * Policy.MAX_CURVATURE_CHANGE_PER_M2
	for step in range(CORNER_RADIUS_STEPS):
		var radius: float = lerpf(cls.radius_pref_m, cls.radius_hard_m * 1.03, step / (CORNER_RADIUS_STEPS - 1.0))
		var kp: float = minf(1.0 / radius, sqrt(dk_limit * delta))
		var ramp: float = kp / dk_limit
		var arc: float = delta / kp - ramp
		var total: float = 2.0 * ramp + arc
		var count: int = maxi(8, ceili(total / CORNER_STEP_M))
		var ds: float = total / count
		# Local frame: start at the tangent point heading along +X, turning to +Y.
		var xs := PackedFloat64Array([0.0])
		var ys := PackedFloat64Array([0.0])
		var phis := PackedFloat64Array([0.0])
		var kappas := PackedFloat64Array([0.0])
		for i in range(1, count + 1):
			var s: float = ds * i
			var kappa: float = kp * minf(1.0, minf(s / ramp, (total - s) / ramp))
			var kappa_mid: float = kp * minf(1.0, minf((s - 0.5 * ds) / ramp, (total - s + 0.5 * ds) / ramp))
			var phi_mid: float = phis[i - 1] + 0.5 * kappa_mid * ds
			xs.append(xs[i - 1] + ds * cos(phi_mid))
			ys.append(ys[i - 1] + ds * sin(phi_mid))
			phis.append(phis[i - 1] + kappa_mid * ds)
			kappas.append(kappa)
		var phi_end: float = phis[count]
		var tangent_length: float = xs[count] - ys[count] / tan(phi_end)
		if tangent_length > available or tangent_length <= 0.0:
			continue
		# World knots: lead A, the corner every CORNER_KNOT_M, lead B.
		var spline := RMath.PlanSpline.new()
		var tx1: float = cx - dax * tangent_length
		var tz1: float = cz - daz * tangent_length
		var left_x: float = -daz
		var left_z: float = dax
		var lead_a: float = ra - tangent_length
		var lead_b: float = rb - tangent_length
		var knots: Array = []
		var pieces_a: int = maxi(1, ceili(lead_a / 12.0))
		for m in range(pieces_a):
			knots.append([pa.x + dax * lead_a * m / pieces_a, pa.z + daz * lead_a * m / pieces_a, dax, daz, 0.0])
		var index_step: int = maxi(1, roundi(CORNER_KNOT_M / ds))
		var i: int = 0
		while i <= count:
			var heading: float = theta_a + sgn * phis[i]
			knots.append([tx1 + dax * xs[i] + left_x * sgn * ys[i], tz1 + daz * xs[i] + left_z * sgn * ys[i], cos(heading), sin(heading), sgn * kappas[i]])
			if i == count:
				break
			i = mini(count, i + index_step)
		var pieces_b: int = maxi(1, ceili(lead_b / 12.0))
		for m in range(1, pieces_b + 1):
			var t2x: float = cx + dbx * tangent_length
			var t2z: float = cz + dbz * tangent_length
			knots.append([t2x + dbx * lead_b * m / pieces_b, t2z + dbz * lead_b * m / pieces_b, dbx, dbz, 0.0])
		for n in range(knots.size()):
			var knot: Array = knots[n]
			spline.kx.append(knot[0])
			spline.kz.append(knot[1])
			spline.ktx.append(knot[2])
			spline.ktz.append(knot[3])
			spline.kk.append(knot[4])
			if n > 0:
				var previous: Array = knots[n - 1]
				spline.span_param.append(maxf(Vector2(knot[0] - previous[0], knot[1] - previous[1]).length(), 1e-6))
		spline.build()
		return spline
	return null


## Export-density connector arrays (same keys as edge designs).
func _connector_design(record: Dictionary, fit: Dictionary, spline: RMath.PlanSpline, pa: Dictionary, pb: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var total: float = spline.total_length
	var positions := PackedFloat64Array([0.0])
	var s: float = 0.0
	while s < total:
		var e: PackedFloat64Array = spline.eval_s(s)
		var kk: float = maxf(absf(e[4]), absf(spline.eval_s(minf(total, s + 1.0))[4]))
		var step: float = clampf(sqrt(8.0 * Policy.CHORD_ERROR_M / maxf(kk, 1e-9)), Policy.MIN_SUBDIVISION_M * 2.0, Policy.NOMINAL_SAMPLE_M)
		s = minf(total, s + step)
		if total - s < 0.3 and s < total:
			s = total
		positions.append(s)
	var arrays := {}
	for name: String in ["s", "x", "y", "z", "tx", "tz", "grade", "k", "dk", "vk", "bank", "width", "nat_c", "nat_l", "nat_r", "fill_l", "fill_r", "tie_l", "tie_r", "sight_forward", "sight_backward"]:
		arrays[name] = PackedFloat64Array()
	var support := PackedByteArray()
	var wa: float = Policy.CLASSES[a.class].width_m
	var wb: float = Policy.CLASSES[b.class].width_m
	var cx: float = record.x
	var cz: float = record.z
	for c in range(positions.size()):
		var e: PackedFloat64Array = spline.eval_s(positions[c])
		var x: float = e[0]
		var z: float = e[1]
		if c == 0:
			x = pa.x
			z = pa.z
		elif c == positions.size() - 1:
			x = pb.x
			z = pb.z
		var grade: float = fit.gx * e[2] + fit.gz * e[3]
		var y: float = plane_height(fit, cx, cz, x, z)
		if c == 0:
			y = pa.y
		elif c == positions.size() - 1:
			y = pb.y
		# d(grade)/ds = G . dT/ds = k * (G . N), N = (-tz, tx).
		var vk: float = e[4] * (fit.gx * -e[3] + fit.gz * e[2])
		var t: float = positions[c] / total
		var w: float = lerpf(wa, wb, t * t * (3.0 - 2.0 * t))
		var hf: float = 0.5 * w
		var nl: float = natural.height_search(x - e[3] * hf, z + e[2] * hf)
		var nr: float = natural.height_search(x + e[3] * hf, z - e[2] * hf)
		var nc: float = natural.height_search(x, z)
		arrays.s.append(positions[c])
		arrays.x.append(x)
		arrays.y.append(y)
		arrays.z.append(z)
		arrays.tx.append(e[2])
		arrays.tz.append(e[3])
		arrays.grade.append(grade)
		arrays.k.append(e[4])
		arrays.dk.append(e[5])
		arrays.vk.append(vk)
		arrays.bank.append(bank_on_plane(fit, e[2], e[3]))
		arrays.width.append(w)
		arrays.nat_c.append(nc)
		arrays.nat_l.append(nl)
		arrays.nat_r.append(nr)
		var tb: float = tan(deg_to_rad(arrays.bank[c]))
		arrays.fill_l.append(y - hf * tb - nl)
		arrays.fill_r.append(y + hf * tb - nr)
		arrays.tie_l.append(0.0)
		arrays.tie_r.append(0.0)
		arrays.sight_forward.append(Policy.SIGHT_MAX_M)
		arrays.sight_backward.append(Policy.SIGHT_MAX_M)
		support.append(Policy.Support.JUNCTION_PATCH)
	arrays["support"] = support
	return arrays
