class_name RoadFeasibilityValidator
extends RefCounted

## Read-only R6 certification of designed pieces (ExecPlan §§5.8, 6-8, 13).
## Re-measures the stored design samples and their RoadPathData export; it
## never repairs. Checks:
##   structure  parallel arrays, finite values, increasing distance, spacing
##              <= MAX_SAMPLE_M, chord sagitta <= CHORD_ERROR_M (+tolerance);
##   geometry   tangent / curvature / grade agree with the sampled points;
##              grade, grade change, curvature, curvature change, bank;
##   frame      exported tangents / normals / binormals finite, unit,
##              orthogonal, upward, without flips; distances = 3D chords;
##   footprint  riding surface, shoulders and tie-ins inside the band (junction
##              zones: union of incident bands); earthwork within class limits;
##   water      crossings re-derived on every chord (HydrologyField), matched
##              one-to-one in order to R5 pins (same channel, C2 envelope),
##              deck / ford obligations, no water elsewhere (exact queries);
##   natural    R4 RideabilityField exact samples on centre and edges: no
##              natural barrier inside the earthwork footprint;
##   features   intents measured on the exported geometry (REALIZED / REJECTED);
##   seams      shared port rows: position, tangent, grade, normal;
##   overlap    unplanned road-road ribbon overlaps outside junction zones.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const Geo = preload("res://scripts/world/region/road_corridor_geometry.gd")
const Plan = preload("res://scripts/world/region/road_synthesis_plan.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Designer = preload("res://scripts/world/region/road_alignment_designer.gd")

var natural: Geo.Natural
var ride_samples: int = 0


static func create(natural_: Geo.Natural) -> RoadFeasibilityValidator:
	var v := RoadFeasibilityValidator.new()
	v.natural = natural_
	return v


## context: {route_class (limits), band_request (Designer request with band /
## zones), pins (edge only), crossings (designer records, edge only),
## is_connector}. Returns {is_valid, reasons, measured, crossings}.
func validate_piece(design: Dictionary, context: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	var measured: Dictionary = {}
	var structure: Dictionary = _structure(design)
	measured["structure"] = structure.measured
	_add(reasons, structure.reasons)
	if not structure.reasons.is_empty():
		return {"is_valid": false, "reasons": reasons, "measured": measured}
	var geometry: Dictionary = _geometry(design, context.route_class, context.get("is_connector", false))
	measured["geometry"] = geometry.measured
	_add(reasons, geometry.reasons)
	var frame: Dictionary = _frame(design)
	measured["frame"] = frame.measured
	_add(reasons, frame.reasons)
	var footprint: Dictionary = _footprint(design, context)
	measured["footprint"] = footprint.measured
	_add(reasons, footprint.reasons)
	var water: Dictionary = _water(design, context)
	measured["water"] = water.measured
	_add(reasons, water.reasons)
	var barrier: Dictionary = _natural(design, context)
	measured["natural"] = barrier.measured
	_add(reasons, barrier.reasons)
	return {"is_valid": reasons.is_empty(), "reasons": reasons, "measured": measured, "crossings": water.get("found", [])}


static func _add(reasons: Array[String], more: Array) -> void:
	for r: String in more:
		if not r in reasons:
			reasons.append(r)


func _structure(d: Dictionary) -> Dictionary:
	var reasons: Array = []
	var n: int = d.get("s", PackedFloat64Array()).size()
	if n < 2:
		return {"reasons": ["ERR_R6_PATH_STRUCTURE"], "measured": {"samples": n}}
	for key: String in Plan.DESIGN_KEYS:
		if not d.has(key) or not d[key] is PackedFloat64Array or d[key].size() != n:
			return {"reasons": ["ERR_R6_PATH_STRUCTURE"], "measured": {"missing": key}}
		for v: float in d[key]:
			if not is_finite(v):
				return {"reasons": ["ERR_R6_NONFINITE"], "measured": {"key": key}}
	if not d.has("support") or d.support.size() != n:
		return {"reasons": ["ERR_R6_PATH_STRUCTURE"], "measured": {"missing": "support"}}
	var max_step: float = 0.0
	var max_sagitta: float = 0.0
	var min_step: float = INF
	for i in range(1, n):
		var ds: float = d.s[i] - d.s[i - 1]
		var chord: float = sqrt((d.x[i] - d.x[i - 1]) ** 2 + (d.z[i] - d.z[i - 1]) ** 2)
		min_step = minf(min_step, chord)
		max_step = maxf(max_step, ds)
		var turn: float = absf(RMath.wrap_angle(atan2(d.tz[i], d.tx[i]) - atan2(d.tz[i - 1], d.tx[i - 1])))
		max_sagitta = maxf(max_sagitta, turn * ds / 8.0)
	if min_step <= 1e-4:
		reasons.append("ERR_R6_PATH_STRUCTURE")
	if max_step > Policy.MAX_SAMPLE_M + 1e-9:
		reasons.append("ERR_R6_SAMPLING")
	if max_sagitta > Policy.CHORD_ERROR_M * 1.25:
		reasons.append("ERR_R6_CERTIFICATION_UNRESOLVED")
	return {"reasons": reasons, "measured": {"samples": n, "max_step_m": max_step, "min_step_m": min_step, "max_sagitta_m": max_sagitta, "length_m": d.s[n - 1]}}


func _geometry(d: Dictionary, route_class: int, connector: bool) -> Dictionary:
	var reasons: Array = []
	var n: int = d.s.size()
	var g_hard: float = Policy.grade_hard(route_class) if not connector else Policy.PATCH_GRADE_MAX + 1e-9
	var k_hard: float = Policy.curvature_hard(route_class)
	var max_grade: float = 0.0
	var max_dgrade: float = 0.0
	var max_k: float = 0.0
	var max_dk: float = 0.0
	var max_bank: float = 0.0
	var max_dbank: float = 0.0
	var tangent_error: float = 0.0
	var grade_error: float = 0.0
	var curvature_error: float = 0.0
	for i in range(n):
		max_grade = maxf(max_grade, absf(d.grade[i]))
		max_k = maxf(max_k, absf(d.k[i]))
		max_bank = maxf(max_bank, absf(d.bank[i]))
		if i == 0:
			continue
		var ds: float = d.s[i] - d.s[i - 1]
		var cx: float = d.x[i] - d.x[i - 1]
		var cz: float = d.z[i] - d.z[i - 1]
		var chord: float = sqrt(cx * cx + cz * cz)
		# Chord direction vs the mean of the two sampled tangents.
		var mx: float = d.tx[i] + d.tx[i - 1]
		var mz: float = d.tz[i] + d.tz[i - 1]
		tangent_error = maxf(tangent_error, rad_to_deg(absf(RMath.wrap_angle(atan2(cz, cx) - atan2(mz, mx)))))
		grade_error = maxf(grade_error, absf((d.y[i] - d.y[i - 1]) / ds - 0.5 * (d.grade[i] + d.grade[i - 1])))
		var turn: float = RMath.wrap_angle(atan2(d.tz[i], d.tx[i]) - atan2(d.tz[i - 1], d.tx[i - 1]))
		curvature_error = maxf(curvature_error, absf(turn / ds - 0.5 * (d.k[i] + d.k[i - 1])))
		var a0: float = rad_to_deg(atan(d.grade[i - 1]))
		var a1: float = rad_to_deg(atan(d.grade[i]))
		max_dgrade = maxf(max_dgrade, absf(a1 - a0) / ds)
		max_dk = maxf(max_dk, absf(d.k[i] - d.k[i - 1]) / ds)
		max_dbank = maxf(max_dbank, absf(d.bank[i] - d.bank[i - 1]) / ds)
		var _unused: float = chord
	if max_grade > g_hard + 1e-6:
		reasons.append("ERR_R6_GRADE")
	if max_dgrade > Policy.MAX_GRADE_CHANGE_DEG_PER_M + 1e-6:
		reasons.append("ERR_R6_GRADE_TRANSITION")
	if max_k > k_hard + 1e-6:
		reasons.append("ERR_R6_CURVATURE")
	if max_dk > Policy.MAX_CURVATURE_CHANGE_PER_M2 + 1e-6:
		reasons.append("ERR_R6_CURVATURE")
	if max_bank > Policy.MAX_BANK_DEG + 1e-9:
		reasons.append("ERR_R6_BANK")
	# Internal consistency of the stored derivatives with the points (sampling
	# tolerance: half-degree headings, 0.5 % grade, 2e-3 1/m curvature).
	if tangent_error > 0.5 or grade_error > 0.005 or curvature_error > 0.002:
		reasons.append("ERR_R6_FRAME")
	return {"reasons": reasons, "measured": {"max_grade": max_grade, "grade_limit": g_hard, "max_dgrade_deg_per_m": max_dgrade, "max_curvature": max_k, "curvature_limit": k_hard,
		"max_dk_ds": max_dk, "max_bank_deg": max_bank, "max_dbank_deg_per_m": max_dbank, "tangent_error_deg": tangent_error, "grade_error": grade_error, "curvature_error": curvature_error}}


func _frame(d: Dictionary) -> Dictionary:
	var reasons: Array = []
	var path: RefCounted = Plan.export_path(d, false)
	var n: int = path.points.size()
	var worst_unit: float = 0.0
	var worst_ortho: float = 0.0
	var min_up: float = INF
	var min_flip: float = INF
	var distance_error: float = 0.0
	var worst_float32: float = 0.0
	for i in range(n):
		var t: Vector3 = path.tangents[i]
		var nn: Vector3 = path.normals[i]
		var b: Vector3 = path.binormals[i]
		if not (t.is_finite() and nn.is_finite() and b.is_finite() and path.points[i].is_finite()):
			return {"reasons": ["ERR_R6_NONFINITE"], "measured": {"index": i}}
		worst_unit = maxf(worst_unit, maxf(absf(t.length() - 1.0), maxf(absf(nn.length() - 1.0), absf(b.length() - 1.0))))
		worst_ortho = maxf(worst_ortho, maxf(absf(t.dot(nn)), maxf(absf(t.dot(b)), absf(nn.dot(b)))))
		min_up = minf(min_up, nn.y)
		worst_float32 = maxf(worst_float32, Vector3(path.points[i].x - d.x[i], path.points[i].y - d.y[i], path.points[i].z - d.z[i]).length())
		if i > 0:
			min_flip = minf(min_flip, nn.dot(path.normals[i - 1]))
			var chord: float = path.points[i].distance_to(path.points[i - 1])
			distance_error = maxf(distance_error, absf((path.cumulative_distances[i] - path.cumulative_distances[i - 1]) - chord))
	if worst_unit > 1e-4 or worst_ortho > 1e-4 or min_up < 0.5 or min_flip < cos(deg_to_rad(5.0)):
		reasons.append("ERR_R6_FRAME")
	if distance_error > 1e-3:
		reasons.append("ERR_R6_PATH_STRUCTURE")
	if worst_float32 > 1e-3:
		reasons.append("ERR_R6_PRECISION")
	return {"reasons": reasons, "measured": {"unit_error": worst_unit, "orthogonality_error": worst_ortho, "min_normal_up": min_up, "min_adjacent_normal_dot": min_flip,
		"distance_error_m": distance_error, "float32_export_error_m": worst_float32}}


func _footprint(d: Dictionary, context: Dictionary) -> Dictionary:
	var reasons: Array = []
	var cls: Dictionary = Policy.CLASSES[context.route_class]
	var request: Dictionary = context.band_request
	var n: int = d.s.size()
	var hint: int = -1
	var min_clearance: float = INF
	var worst_at: float = 0.0
	var max_cut: float = 0.0
	var max_fill: float = 0.0
	var max_tie: float = 0.0
	var connector: bool = context.get("is_connector", false)
	for i in range(n):
		var half: float = 0.5 * d.width[i] + (cls.shoulder_m if not connector else 0.0)
		var nx: float = -d.tz[i]
		var nz: float = d.tx[i]
		var points: Array = [[d.x[i], d.z[i]], [d.x[i] + nx * (half + d.tie_l[i]), d.z[i] + nz * (half + d.tie_l[i])], [d.x[i] - nx * (half + d.tie_r[i]), d.z[i] - nz * (half + d.tie_r[i])]]
		if not connector:
			hint = int(request.band.clearance(d.x[i], d.z[i], hint, 10)[1])
		for p: Array in points:
			var c: float = Designer.clearance(request, p[0], p[1], hint) if not connector else _union_clearance(request, p[0], p[1])
			if c < min_clearance:
				min_clearance = c
				worst_at = d.s[i]
		if d.support[i] == Policy.Support.EARTHWORK:
			max_cut = maxf(max_cut, maxf(-d.fill_l[i], -d.fill_r[i]))
			max_fill = maxf(max_fill, maxf(d.fill_l[i], d.fill_r[i]))
			max_tie = maxf(max_tie, maxf(d.tie_l[i], d.tie_r[i]))
	if min_clearance < -1e-6:
		reasons.append("ERR_R6_CORRIDOR_CLEARANCE")
	if max_cut > cls.cut_max_m + 1e-6 or max_fill > cls.fill_max_m + 1e-6 or max_tie > cls.tie_max_m + 1e-6:
		reasons.append("ERR_R6_EARTHWORK")
	return {"reasons": reasons, "measured": {"min_clearance_m": min_clearance, "worst_s": worst_at, "max_cut_m": max_cut, "max_fill_m": max_fill, "max_tie_m": max_tie}}


static func _union_clearance(request: Dictionary, x: float, z: float) -> float:
	var best: float = -INF
	for band: Geo.Band in request.get("union_bands", []):
		best = maxf(best, band.clearance(x, z, -1)[0])
	return best


## Water certification: crossings re-derived on every sample chord.
func _water(d: Dictionary, context: Dictionary) -> Dictionary:
	var reasons: Array = []
	var n: int = d.s.size()
	var found: Array = []
	var bodies: Array = []
	var query_failures: int = 0
	for i in range(1, n):
		# Gateway rows may touch the region edge: points within 0.5 m outside
		# are clamped to the boundary; farther stays a query failure.
		var ax: float = _domain(d.x[i - 1])
		var az: float = _domain(d.z[i - 1])
		var bx: float = _domain(d.x[i])
		var bz: float = _domain(d.z[i])
		var result: Dictionary = natural.segment_crossings(ax, az, bx, bz)
		if not result.is_valid:
			query_failures += 1
			continue
		for record: Dictionary in result.crossings:
			var lx: float = record.x - natural.origin_x
			var lz: float = record.z - natural.origin_z
			var sc: float = d.s[i - 1] + record.t * (d.s[i] - d.s[i - 1])
			# A hit exactly on a shared sample end is one crossing.
			if not found.is_empty() and found[-1].channel_id == record.channel_id and absf(found[-1].s - sc) <= 0.01:
				continue
			found.append({"s": sc, "x": lx, "z": lz, "channel_id": record.channel_id, "width_m": record.width_m, "surface_m": record.surface_m, "bed_m": record.bed_m, "angle_deg": record.angle_deg})
		for body: int in result.body_ids:
			bodies.append(body)
	if query_failures > 0:
		reasons.append("ERR_R6_CERTIFICATION_UNRESOLVED")
	if not bodies.is_empty():
		reasons.append("ERR_R6_WATER_BODY")
	var pins: Array = context.get("pins", [])
	var matched: Array = []
	var p: int = 0
	for f: Dictionary in found:
		if p < pins.size() and pins[p].channel_id == f.channel_id:
			var shift: float = Vector2(f.x - pins[p].x, f.z - pins[p].z).length()
			if shift > Policy.CROSSING_MAX_DISPLACEMENT_M + 1e-9:
				reasons.append("ERR_R6_CROSSING_DISPLACED")
			matched.append({"pin": pins[p].index, "found": f, "shift_m": shift})
			p += 1
		else:
			# A real crossing without a pin in order: an additional crossing.
			if not "ERR_R6_CROSSING_EXTRA" in reasons:
				reasons.append("ERR_R6_CROSSING_EXTRA")
	# Unmatched pins: MISSING when the pin's channel exists at the pin (the road
	# omitted it), PHANTOM when hydrology has no such channel there.
	while p < pins.size():
		var near: PackedFloat64Array = natural.water_search(pins[p].x, pins[p].z, 3.0)
		var reason: String = "ERR_R6_CROSSING_MISSING" if int(near[0]) == pins[p].channel_id else "ERR_R6_CROSSING_PHANTOM"
		if not reason in reasons:
			reasons.append(reason)
		p += 1
	# Support obligations for every designed crossing record.
	var designed: Array = context.get("crossings", [])
	for r: Dictionary in designed:
		var deck: bool = r.support == Policy.Support.BRIDGE_DECK
		for i in range(n):
			if d.s[i] < r.wet_s0 or d.s[i] > r.wet_s1:
				continue
			if deck and d.y[i] < r.surface_m + Policy.DECK_CLEARANCE_M + Policy.DECK_STRUCTURE_M - 1e-3:
				reasons.append("ERR_R6_CROSSING_SUPPORT")
				break
			if deck and d.support[i] != Policy.Support.BRIDGE_DECK:
				reasons.append("ERR_R6_CROSSING_SUPPORT")
				break
		if not deck and r.depth_m >= Policy.FORD_MAX_DEPTH_M:
			reasons.append("ERR_R6_WATER_OCCUPANCY")
		if deck and r.clear_span_m > Policy.BRIDGE_MAX_SPAN_M:
			reasons.append("ERR_R6_CROSSING_SUPPORT")
	# Occupancy: exact water on centre and riding edges near any channel,
	# outside the designed wet spans.
	var wet_hits: int = 0
	var checked: int = 0
	var wet_examples: Array = []
	for i in range(n):
		var near: PackedFloat64Array = natural.water_search(d.x[i], d.z[i], 10.0 + d.width[i])
		if near[0] < 0.0 and near[7] < 0.0:
			continue
		var inside: bool = false
		for r: Dictionary in designed:
			inside = inside or (d.s[i] >= r.wet_s0 - 0.5 and d.s[i] <= r.wet_s1 + 0.5)
		if inside:
			continue
		var nx: float = -d.tz[i]
		var nz: float = d.tx[i]
		for o: float in [0.0, 0.5 * d.width[i], -0.5 * d.width[i]]:
			checked += 1
			var wet: Dictionary = natural.water_exact(_domain(d.x[i] + nx * o), _domain(d.z[i] + nz * o))
			if wet.is_valid and wet.is_water:
				wet_hits += 1
				if wet_examples.size() < 6:
					wet_examples.append([snappedf(d.s[i], 0.1), o, wet.kind, wet.id, snappedf(wet.depth_m, 0.01)])
				var reason: String = "ERR_R6_WATER_BODY" if wet.kind in ["POND", "CLOSED"] else "ERR_R6_WATER_OCCUPANCY"
				if not reason in reasons:
					reasons.append(reason)
	return {"reasons": reasons, "found": found, "measured": {"crossings_found": found.size(), "pins": pins.size(), "matched": matched, "bodies": bodies, "occupancy_checks": checked, "wet_hits": wet_hits,
		"query_failures": query_failures, "wet_examples": wet_examples, "designed_spans": designed.map(func(r: Dictionary) -> Array: return [snappedf(r.wet_s0, 0.1), snappedf(r.wet_s1, 0.1), r.support])}}


static func _domain(v: float) -> float:
	return clampf(v, 0.0, Geo.DOMAIN_M) if v >= -0.5 and v <= Geo.DOMAIN_M + 0.5 else v


## R4 exact samples: centre every 4 m, riding edges every 8 m. A BLOCKED
## sample inside the earthwork footprint is a natural barrier; deep water is
## only admissible on a bridge deck (judged by the water check).
func _natural(d: Dictionary, context: Dictionary) -> Dictionary:
	var reasons: Array = []
	var n: int = d.s.size()
	var next_centre: float = 0.0
	var next_edge: float = 0.0
	var blocked_slope: int = 0
	var blocked_water: int = 0
	var samples: int = 0
	var worst: Dictionary = {}
	var wet_examples: Array = []
	for i in range(n):
		var points: Array = []
		if d.s[i] >= next_centre or i == n - 1:
			points.append([d.x[i], d.z[i]])
			next_centre = d.s[i] + 4.0
		if d.s[i] >= next_edge:
			var nx: float = -d.tz[i]
			var nz: float = d.tx[i]
			var half: float = 0.5 * d.width[i]
			points.append([d.x[i] + nx * half, d.z[i] + nz * half])
			points.append([d.x[i] - nx * half, d.z[i] - nz * half])
			next_edge = d.s[i] + 8.0
		for p: Array in points:
			samples += 1
			ride_samples += 1
			var r: Dictionary = natural.ride_exact(clampf(p[0], 0.0, Geo.DOMAIN_M), clampf(p[1], 0.0, Geo.DOMAIN_M))
			if not r.is_valid:
				if not "ERR_R6_CERTIFICATION_UNRESOLVED" in reasons:
					reasons.append("ERR_R6_CERTIFICATION_UNRESOLVED")
				continue
			if r.blocked:
				if r.reason_flags & Ride.Reason.EXCESSIVE_SLOPE:
					blocked_slope += 1
					if d.support[i] != Policy.Support.BRIDGE_DECK:
						if not "ERR_R6_NATURAL_BARRIER" in reasons:
							reasons.append("ERR_R6_NATURAL_BARRIER")
						worst = {"s": d.s[i], "flags": r.reason_flags, "slope_grade": r.slope_grade}
				if r.reason_flags & Ride.Reason.DEEP_WATER:
					blocked_water += 1
					if wet_examples.size() < 6:
						wet_examples.append([snappedf(d.s[i], 0.1), d.support[i], snappedf(r.water_depth_m, 0.01), snappedf(p[0], 0.1), snappedf(p[1], 0.1)])
					if d.support[i] != Policy.Support.BRIDGE_DECK and not "ERR_R6_WATER_OCCUPANCY" in reasons:
						reasons.append("ERR_R6_WATER_OCCUPANCY")
						worst = {"s": d.s[i], "flags": r.reason_flags, "water_depth_m": r.water_depth_m}
	return {"reasons": reasons, "measured": {"samples": samples, "blocked_slope": blocked_slope, "blocked_deep_water": blocked_water, "worst": worst, "deep_water_examples": wet_examples}}


# --- Features ---

## Realisation of intents measured on the exported samples. Rotational
## envelopes use the heading change of the final tangents over the intent's
## final s-range; vertical envelopes use the final elevation.
static func measure_features(features: Array, d: Dictionary) -> Array:
	var result: Array = []
	var heading := PackedFloat64Array()
	var n: int = d.s.size()
	var acc: float = atan2(d.tz[0], d.tx[0])
	heading.append(acc)
	for i in range(1, n):
		acc += RMath.wrap_angle(atan2(d.tz[i], d.tx[i]) - atan2(d.tz[i - 1], d.tx[i - 1]))
		heading.append(acc)
	for feature: Dictionary in features:
		var f: Dictionary = feature.duplicate(true)
		var a: int = clampi(d.s.bsearch(f.s0), 0, n - 1)
		var b: int = clampi(d.s.bsearch(f.s1), 0, n - 1)
		var env: Dictionary = f.envelope
		var ok: bool = true
		var measured: Dictionary = {"s0": d.s[a], "s1": d.s[b]}
		match f.kind:
			"SWEEP", "SWITCHBACK":
				var turn: float = rad_to_deg(heading[b] - heading[a])
				measured["turn_deg"] = turn
				ok = signf(turn) == env.sign and absf(turn) >= env.min_turn_deg
			"LINKED_TURNS":
				var lobes: Array = RMath.turn_lobes(d.s.slice(a, b + 1), d.k.slice(a, b + 1), 1.0 / 1500.0, 6.0)
				var signs := PackedFloat64Array()
				for lobe: Dictionary in lobes:
					if absf(rad_to_deg(lobe.turn)) >= env.min_lobe_deg:
						if signs.is_empty() or signs[signs.size() - 1] != signf(lobe.turn):
							signs.append(signf(lobe.turn))
				measured["signs"] = signs
				# The intended alternation must survive in order.
				var m: int = 0
				for sgn: float in signs:
					if m < env.signs.size() and sgn == env.signs[m]:
						m += 1
				ok = m >= mini(env.signs.size(), 2) and signs.size() >= 2
			"CALM":
				var max_k: float = 0.0
				for i in range(a, b + 1):
					max_k = maxf(max_k, absf(d.k[i]))
				var turn: float = absf(rad_to_deg(heading[b] - heading[a]))
				measured["max_curvature"] = max_k
				measured["turn_deg"] = turn
				ok = max_k <= env.max_curvature * 1.5 and turn <= env.max_turn_deg
			"CLIMB", "DESCENT":
				var rise: float = d.y[b] - d.y[a]
				measured["rise_m"] = rise
				ok = signf(rise) == signf(env.rise_m) and absf(rise) >= env.min_rise_m
			"CREST", "COMPRESSION":
				var apex: int = clampi(d.s.bsearch(env.apex_s), 0, n - 1)
				var best: float = d.y[apex]
				var lo_i: int = maxi(a, apex - 15)
				var hi_i: int = mini(b, apex + 15)
				for i in range(lo_i, hi_i + 1):
					best = maxf(best, d.y[i]) if f.kind == "CREST" else minf(best, d.y[i])
				var base: float = 0.5 * (d.y[a] + d.y[b])
				var prominence: float = (best - base) * (1.0 if f.kind == "CREST" else -1.0)
				measured["prominence_m"] = prominence
				ok = prominence >= env.min_prominence_m
		f.measured = measured
		f.status = Policy.REALIZED if ok else Policy.REJECTED
		if not ok:
			f.reasons = ["ERR_R6_FEATURE_UNREALIZED"]
		result.append(f)
	return result


# --- Seams and overlaps ---

## Seam between two exported ends meeting at one port (both oriented to
## travel through the port): position, tangent, grade, normal.
static func seam(a_end: Dictionary, b_start: Dictionary) -> Dictionary:
	var pos: float = Vector3(a_end.x - b_start.x, a_end.y - b_start.y, a_end.z - b_start.z).length()
	var ta := Vector3(a_end.tx, a_end.grade, a_end.tz).normalized()
	var tb := Vector3(b_start.tx, b_start.grade, b_start.tz).normalized()
	var tangent_deg: float = rad_to_deg(ta.angle_to(tb))
	var grade_deg: float = absf(rad_to_deg(atan(a_end.grade)) - rad_to_deg(atan(b_start.grade)))
	var na: Vector3 = preload("res://scripts/world/road_math.gd").compute_ortho_normal(ta, a_end.bank)
	var nb: Vector3 = preload("res://scripts/world/road_math.gd").compute_ortho_normal(tb, b_start.bank)
	var normal_deg: float = rad_to_deg(na.angle_to(nb))
	var reasons: Array[String] = []
	if pos > Policy.SEAM_POSITION_M or tangent_deg > Policy.SEAM_TANGENT_DEG or grade_deg > Policy.SEAM_GRADE_DEG or normal_deg > Policy.SEAM_NORMAL_DEG:
		reasons.append("ERR_R6_SEAM")
	return {"position_m": pos, "tangent_deg": tangent_deg, "grade_deg": grade_deg, "normal_deg": normal_deg, "reasons": reasons}


static func end_row(design: Dictionary, at_end: bool, reversed: bool) -> Dictionary:
	var n: int = design.s.size()
	var i: int = n - 1 if at_end else 0
	var sign: float = -1.0 if reversed else 1.0
	return {"x": design.x[i], "y": design.y[i], "z": design.z[i], "tx": sign * design.tx[i], "tz": sign * design.tz[i], "grade": sign * design.grade[i], "bank": sign * design.bank[i]}


## Road-road conflicts outside shared junction zones: riding ribbons closer
## than 0.5 m (unplanned intersection), or earthwork footprints overlapping at
## road heights more than 0.5 m apart (competing roadbed). Also self-conflicts
## of one piece more than 40 m apart along it (folded development).
## pieces: [{piece_id, design, zones ([x, z] junction centres at its ends),
## shoulder_m}] -> [{a, b, kind, s_a, x, z, gap_m}].
static func overlaps(pieces: Array) -> Array:
	var cell: float = 24.0
	var grid: Dictionary = {}
	var found: Array = []
	for p in range(pieces.size()):
		var d: Dictionary = pieces[p].design
		for i in range(0, d.s.size(), 2):
			var key := Vector2i(floori(d.x[i] / cell), floori(d.z[i] / cell))
			if not grid.has(key):
				grid[key] = []
			var half: float = 0.5 * d.width[i]
			var reach: float = half + pieces[p].get("shoulder_m", 0.0) + maxf(d.tie_l[i], d.tie_r[i])
			grid[key].append(PackedFloat64Array([p, d.x[i], d.z[i], half, d.s[i], d.y[i], reach]))
	var reported: Dictionary = {}
	for key: Vector2i in grid:
		for entry: PackedFloat64Array in grid[key]:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					var other_key := Vector2i(key.x + dx, key.y + dz)
					if not grid.has(other_key):
						continue
					for other: PackedFloat64Array in grid[other_key]:
						var p: int = int(entry[0])
						var q: int = int(other[0])
						if q < p or (q == p and other[4] - entry[4] <= 40.0):
							continue
						var distance: float = Vector2(entry[1] - other[1], entry[2] - other[2]).length()
						var ribbon_gap: float = distance - entry[3] - other[3]
						var footprint_gap: float = distance - entry[6] - other[6]
						var kind: String = ""
						if ribbon_gap < 0.5:
							kind = "ERR_R6_UNPLANNED_INTERSECTION"
						elif footprint_gap < 0.0 and absf(entry[5] - other[5]) > 0.5:
							kind = "ERR_R6_EARTHWORK"
						if kind.is_empty():
							continue
						var in_zone: bool = false
						if q != p:
							for zone: Array in pieces[p].zones:
								if Vector2(entry[1] - zone[0], entry[2] - zone[1]).length() <= Policy.JUNCTION_ZONE_M:
									for zone_q: Array in pieces[q].zones:
										if zone_q[0] == zone[0] and zone_q[1] == zone[1]:
											in_zone = true
						var pair_key: String = "%d-%d-%s" % [p, q, kind]
						if not in_zone and not reported.has(pair_key):
							reported[pair_key] = true
							found.append({"a": pieces[p].piece_id, "b": pieces[q].piece_id, "kind": kind, "s_a": entry[4], "s_b": other[4], "x": entry[1], "z": entry[2],
								"gap_m": ribbon_gap if kind == "ERR_R6_UNPLANNED_INTERSECTION" else footprint_gap, "dy_m": entry[5] - other[5]})
	return found
