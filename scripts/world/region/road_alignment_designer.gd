class_name RoadAlignmentDesigner
extends RefCounted

## R6 terrain-led alignment design for one corridor piece (ExecPlan §5 +
## Director C4). Finite, deterministic pipeline:
##   1. lattice: a smoothed search axis between the two fixed ports with
##      lateral slots certified inside the R5 band (with footprint clearance),
##      crossing windows around each R5 pin (C2 envelope), water / natural
##      barrier nodes blocked;
##   2. candidates: a bounded set of lattice dynamic-programming alignments,
##      one per terrain weight profile (DIRECT / TERRAIN / FLOW). Each node
##      sequence is scored by length, natural grade against the class
##      envelope, cross-slope earthwork, R4 traversal cost and curvature above
##      the class preference (a modest curvature cost, never a straightness
##      objective); steep stretches allow wide lateral steps so development
##      (traverses with turns) can emerge from terrain, not from a pattern;
##   3. fit: discrete fairing of the selected node line, then a G2 quintic
##      plan spline through knots, certified on fine samples; bounded retries
##      (FIT_SWEEPS x FIT_ITERATIONS) adjust smoothing / local weights;
##   4. profile: exact natural heights along the curve; an exact reachability
##      solve of the sampled elevation (grade and vertical-curvature limits,
##      cut/fill, port, bridge-deck and ford bounds) that tracks the smoothed
##      natural profile, interpolated by quintic knots;
##   5. measure: banking, earthwork, tie-in footprint, crossings, sight lines,
##      feature intents. Hard constraints first; feasible candidates ranked
##      by roadbed work, grade excess and length.
## No hidden fallback: a piece without a feasible candidate reports the
## measured reasons of every candidate.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const Geo = preload("res://scripts/world/region/road_corridor_geometry.gd")
const Kinematic = preload("res://scripts/world/road_kinematic_model.gd")

## Candidate weight profiles (terrain-led families). len: directness; grade:
## natural grade against the class envelope; cross: cross-slope earthwork;
## ride: R4 cover/wetness cost; curv: curvature above the class preference.
const PROFILES: Array[Dictionary] = [
	{"name": "DIRECT", "len": 1.0, "grade": 2.0, "cross": 2.0, "ride": 0.25, "curv": 1.0},
	{"name": "TERRAIN", "len": 0.35, "grade": 7.0, "cross": 7.0, "ride": 0.6, "curv": 0.8},
	{"name": "FLOW", "len": 0.55, "grade": 4.0, "cross": 3.5, "ride": 0.45, "curv": 0.35},
]
## Per class search/fit scales: lattice step du / slot dd (m), fairing length
## scale (m), plan knot stride (lattice points), profile smoothing sigma and
## knot stride (2 m samples).
const SCALES: Array[Dictionary] = [
	{"du": 10.0, "dd": 4.0, "fair_m": 26.0, "knot": 3, "v_sigma": 8.0, "v_comfort": 0.006, "bank_gain": 0.5},
	{"du": 8.0, "dd": 3.0, "fair_m": 20.0, "knot": 3, "v_sigma": 6.0, "v_comfort": 0.008, "bank_gain": 0.5},
	{"du": 6.0, "dd": 2.5, "fair_m": 13.0, "knot": 3, "v_sigma": 4.0, "v_comfort": 0.012, "bank_gain": 0.5},
	{"du": 6.0, "dd": 2.0, "fair_m": 11.0, "knot": 3, "v_sigma": 3.0, "v_comfort": 0.015, "bank_gain": 0.5},
]
const MAX_LATERAL_M: float = 130.0
## Development probe: a length reward on the stretch against curvature limits and
## the cross-slope earthwork cost (a longer line must still be buildable).
const LONGEST_PROFILE := {"name": "LONGEST", "len": 0.0, "grade": 0.3, "cross": 1.0, "ride": 0.0, "curv": 1.0}
const DEVELOP_ROUNDS: int = 8
## Bounds of the fit escalation (stiffness as a multiple of the base, point
## weight): a repair that needs more is a diagnosed failure, never a degenerate
## straightened line.
const FIT_LAMBDA_CAP: float = 300.0
const FIT_WEIGHT_CAP: float = 1e4
## Curvature should build up from zero at the ports at no more than this share
## of the retained curvature-change limit (1/m per m of distance from the port):
## the lattice search is charged for more, so the fitted curve keeps room for
## the transition.
const PORT_RAMP_SHARE: float = 0.8
const SLOPE_BLOCK: float = 0.9
const PROFILE_DS: float = 2.0
const LATTICE_RESERVE_M: float = 1.0
## Fixed ladder of search settings [lattice curvature cut-off (x hard curvature),
## extra clearance to the band edge (m)]; attempts after the first run only for
## failures of the kinds below.
const SEARCH_ATTEMPTS: Array = [[1.2, 0.0], [1.6, 0.0], [1.2, 3.0], [1.6, 3.0], [1.6, 7.0]]
const RETRY_REASONS: Array[String] = ["ERR_R6_CORRIDOR_CLEARANCE", "ERR_R6_CURVATURE", "ERR_R6_CROSSING_APPROACH", "ERR_R6_GRADE_TRANSITION", "ERR_R6_EARTHWORK"]
const PLAN_RESERVE_M: float = 0.3
## Vertical profile. A bounded number of cyclic projections (least-movement
## repair of the smoothed natural profile against the bounds) prepares the
## tracking reference; the exact reachability solve then decides feasibility
## and tracks that reference as closely as the bounds allow. Weights of the
## tracking: grade state / change of vertical curvature between samples.
## Bounds already carry 3 cm margins.
const PROFILE_PREP_SWEEPS: int = 300
const PROFILE_PREP_TOLERANCE_M: float = 0.002
const JERK_SAMPLES: float = 4.0
## Over-relaxation of the slab projections (1 = plain projection).
const PROFILE_RELAX: float = 1.5
const PROFILE_TRACK_GRADE: float = 1.0
const PROFILE_TRACK_JERK: float = 0.1
## Profile grade bound as a share of the class hard grade (slack for the
## quintic interpolant between samples; the export is re-certified).
const PROFILE_GRADE_SHARE: float = 0.97

var natural: Geo.Natural
var fit_evaluations: int = 0
var fit_budget: int = Policy.MAX_FIT_EVALUATIONS
var dp_transitions: int = 0
var lattice_extra_reserve: float = 0.0
var curvature_cutoff: float = 1.2


static func create(natural_: Geo.Natural, fit_budget_: int) -> RoadAlignmentDesigner:
	var designer := RoadAlignmentDesigner.new()
	designer.natural = natural_
	designer.fit_budget = fit_budget_
	return designer


static func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"is_valid": false, "reason_code": reason, "detail": detail}


# =====================================================================
# Public entry point
# =====================================================================

## request: {edge_id, route_class, band, start, end, pins, avoid}
##   start / end: {x, z, y, tx, tz (travel direction a->b), grade, grade_pinned,
##                 bank_deg}; pins: R5 crossing pins (local m); avoid: other
##   roads' sample points [x, z, clearance] to keep away from (may be empty).
## Returns {is_valid, reason_code, design (arrays), candidates (summaries),
## selected, features (intents), crossings (actual), metrics}.
func design(request: Dictionary) -> Dictionary:
	lattice_extra_reserve = 0.0
	curvature_cutoff = SEARCH_ATTEMPTS[0][0]
	var result: Dictionary = _design_once(request)
	var attempt: int = 0
	# Bounded alternatives: a failure that depends on how tight the lattice line
	# may turn or how much room it keeps to the band edge (earthwork tie-ins,
	# curvature fit, bridge approaches) is searched again with the next setting
	# of the fixed ladder; a development / grade failure is not (its limit is the
	# corridor, measured separately).
	while not result.is_valid and attempt + 1 < SEARCH_ATTEMPTS.size() and result.get("reason_code", "") in RETRY_REASONS:
		attempt += 1
		curvature_cutoff = SEARCH_ATTEMPTS[attempt][0]
		lattice_extra_reserve = SEARCH_ATTEMPTS[attempt][1]
		var again: Dictionary = _design_once(request)
		again["search_attempt"] = attempt
		if again.is_valid or again.get("reason_code", "") != "ERR_R6_GRADE":
			result = again
		else:
			break
	lattice_extra_reserve = 0.0
	curvature_cutoff = SEARCH_ATTEMPTS[0][0]
	if result.is_valid:
		result["search_attempt"] = attempt
	return result


func _design_once(request: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var lattice: Dictionary = _lattice(request)
	if not lattice.is_valid:
		return {"is_valid": false, "reason_code": lattice.reason_code, "detail": lattice.get("detail", {}), "candidates": [], "selected": -1}
	var summaries: Array = []
	var results: Array = []
	var seen_lines: Dictionary = {}
	var lattice_limited: bool = false
	for p in range(PROFILES.size()):
		if fit_evaluations > fit_budget or natural.exhausted():
			summaries.append({"profile": PROFILES[p].name, "status": "NOT_RUN", "reason_code": "ERR_R6_SEARCH_BUDGET"})
			results.append(null)
			continue
		if lattice_limited:
			summaries.append({"profile": PROFILES[p].name, "status": "NOT_RUN", "reason_code": "ERR_R6_GRADE", "detail": {"note": "an earlier profile showed that the longest lattice line on a steep stretch is too short; the limit is profile-independent"}})
			results.append(null)
			continue
		var line: Dictionary = _dynamic_program(lattice, PROFILES[p], route_class)
		if not line.is_valid:
			summaries.append({"profile": PROFILES[p].name, "status": "REJECTED", "reason_code": line.reason_code, "detail": line.get("detail", {})})
			results.append(null)
			continue
		var reach: Dictionary = _grade_reach(line, route_class)
		# Development stage: where the necessary grade condition fails, the
		# length of the failing stretch is rewarded (bounded rounds, escalating
		# per stretch) until the line is long enough, or the longest line the
		# lattice offers there is shown to be too short.
		if not reach.is_valid:
			var developed: Dictionary = _develop(lattice, PROFILES[p], route_class, line, reach)
			line = developed.line
			reach = developed.reach
			if developed.lattice_limit:
				lattice_limited = true
		if not reach.is_valid:
			_reach_context(lattice, reach.detail)
			summaries.append({"profile": PROFILES[p].name, "status": "REJECTED", "reason_code": "ERR_R6_GRADE", "detail": reach.detail, "dp_cost": line.cost})
			results.append(null)
			continue
		var key: String = str(line.j)
		if seen_lines.has(key):
			# Identical node sequence: one fit, recorded once per profile.
			summaries.append({"profile": PROFILES[p].name, "status": "DUPLICATE", "same_as": seen_lines[key], "reason_code": ""})
			results.append(null)
			continue
		seen_lines[key] = PROFILES[p].name
		var candidate: Dictionary = _evaluate(request, lattice, line, p)
		results.append(candidate)
		summaries.append(candidate.summary)
	# Hard constraints first, then score; stable tie-break by profile order.
	var best: int = -1
	for i in range(results.size()):
		if results[i] == null or not results[i].is_valid:
			continue
		if best < 0 or results[i].score < results[best].score - 1e-9:
			best = i
	if best < 0:
		var reason: String = "ERR_R6_SEARCH_BUDGET" if fit_evaluations > fit_budget or natural.exhausted() else _dominant_reason(summaries)
		return {"is_valid": false, "reason_code": reason, "detail": {"candidates": summaries}, "candidates": summaries, "selected": -1, "lattice": _lattice_summary(lattice)}
	var chosen: Dictionary = results[best]
	chosen.summary["selected"] = true
	return {"is_valid": true, "reason_code": "", "design": chosen.design, "candidates": summaries, "selected": best, "profile": PROFILES[best].name,
		"features": chosen.features, "crossings": chosen.crossings, "metrics": chosen.metrics, "fair_line": chosen.fair_line, "lattice": _lattice_summary(lattice)}


## Development stage for a line failing the necessary grade condition: reward
## the length of each failing stretch (net length weight -mu, mu escalating
## 2.5x per round) and re-run the lattice search, at most DEVELOP_ROUNDS times.
## A first probe with a strongly negative weight finds the longest lattice line
## on the stretch; if even that is shorter than required the limit belongs to
## the corridor and lattice (recorded as measured lattice_max_length_m).
func _develop(lattice: Dictionary, profile: Dictionary, route_class: int, line: Dictionary, reach: Dictionary) -> Dictionary:
	var n: int = lattice.n
	var adjust := PackedFloat64Array()
	adjust.resize(n)
	var mu_of: Dictionary = {}
	var current: Dictionary = line
	var failing: Dictionary = reach
	for round_index in range(DEVELOP_ROUNDS):
		var a: int = clampi(int(failing.detail.i0), 0, n - 2)
		var b: int = clampi(int(failing.detail.i1), a + 1, n - 1)
		var first: bool = not mu_of.has(a)
		if first:
			# Feasibility probe on this stretch: the longest line the lattice offers.
			var probe := PackedFloat64Array()
			probe.resize(n)
			for i in range(a, b):
				probe[i] = -3.0
			var longest: Dictionary = _dynamic_program(lattice, LONGEST_PROFILE, route_class, probe)
			var longest_len: float = 0.0
			if longest.is_valid:
				for i in range(a, b):
					longest_len += Vector2(longest.x[i + 1] - longest.x[i], longest.z[i + 1] - longest.z[i]).length()
			if not longest.is_valid or longest_len < failing.detail.required_length_m:
				failing.detail["lattice_max_length_m"] = longest_len
				failing.detail["lattice_limited"] = true
				return {"line": current, "reach": failing, "lattice_limit": true}
			mu_of[a] = 0.5
		else:
			mu_of[a] *= 2.5
		for i in range(a, b):
			adjust[i] = -(profile.len + mu_of[a])
		var again: Dictionary = _dynamic_program(lattice, profile, route_class, adjust)
		if not again.is_valid:
			break
		current = again
		failing = _grade_reach(current, route_class)
		if failing.is_valid:
			return {"line": current, "reach": failing, "lattice_limit": false}
	if not failing.is_valid:
		return {"line": current, "reach": failing, "lattice_limit": false}
	failing.detail["development_rounds_exhausted"] = true
	return {"line": current, "reach": failing, "lattice_limit": false}


## Measured context of a failed necessary grade condition: how much admissible
## lateral room the lattice offered along the short stretch, whether a crossing
## window restricts it and the length ratio that would be required.
func _reach_context(lattice: Dictionary, detail: Dictionary) -> void:
	var i0: int = clampi(int(detail.i0), 0, lattice.n - 1)
	var i1: int = clampi(int(detail.i1), 0, lattice.n - 1)
	var room_min: float = INF
	var room_sum: float = 0.0
	var stations: int = 0
	for i in range(mini(i0, i1), maxi(i0, i1) + 1):
		var ok_count: int = 0
		for k in range(lattice.jcount[i]):
			if lattice.node_ok[lattice.first[i] + k] == 1:
				ok_count += 1
		var room: float = ok_count * lattice.dd
		room_min = minf(room_min, room)
		room_sum += room
		stations += 1
	var window: bool = false
	for w: Dictionary in lattice.windows:
		window = window or (w.station >= mini(i0, i1) - w.reach and w.station <= maxi(i0, i1) + w.reach)
	detail["lateral_room_min_m"] = room_min
	detail["lateral_room_mean_m"] = room_sum / maxf(stations, 1)
	detail["crossing_window_in_zone"] = window
	detail["required_length_ratio"] = detail.required_length_m / maxf(detail.line_length_m, 1.0)


static func _dominant_reason(summaries: Array) -> String:
	var order: Array[String] = ["ERR_R6_CROSSING_MISSING", "ERR_R6_CROSSING_DISPLACED", "ERR_R6_CROSSING_EXTRA", "ERR_R6_WATER_BODY", "ERR_R6_WATER_OCCUPANCY",
		"ERR_R6_CROSSING_SUPPORT", "ERR_R6_CROSSING_APPROACH", "ERR_R6_GRADE", "ERR_R6_EARTHWORK", "ERR_R6_NATURAL_BARRIER", "ERR_R6_CORRIDOR_CLEARANCE",
		"ERR_R6_CURVATURE", "ERR_R6_GRADE_TRANSITION", "ERR_R6_APPROACH", "ERR_R6_CERTIFICATION_UNRESOLVED"]
	var found: Dictionary = {}
	for s: Dictionary in summaries:
		found[s.get("reason_code", "")] = true
	# The most specific reason among candidates (water/crossing before others):
	# every candidate's own reason stays in the summaries.
	for reason: String in order:
		if found.has(reason):
			return reason
	for s: Dictionary in summaries:
		if not s.get("reason_code", "").is_empty():
			return s.reason_code
	return "ERR_R6_SEARCH_BUDGET"


static func pin_index_of(w: Dictionary) -> int:
	return w.pin.index


static func _lattice_summary(lattice: Dictionary) -> Dictionary:
	return {"stations": lattice.n, "nodes": lattice.node_x.size(), "axis_length_m": lattice.axis_length, "develop_stations": lattice.develop_count,
		"windows": lattice.windows.size(), "du": lattice.du, "dd": lattice.dd}


# =====================================================================
# 1. Lattice
# =====================================================================

func _lattice(request: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var scale: Dictionary = SCALES[route_class]
	var band: Geo.Band = request.band
	var start: Dictionary = request.start
	var finish: Dictionary = request.end
	var hf: float = Policy.half_footprint(route_class)
	var need: float = hf + LATTICE_RESERVE_M + lattice_extra_reserve
	var u0: float = band.project_u(start.x, start.z)
	var u1: float = band.project_u(finish.x, finish.z)
	if u1 <= u0 + 2.0 * scale.du:
		return _fail("ERR_R6_CORRIDOR_CLEARANCE", {"note": "ports leave no interior", "u0": u0, "u1": u1})
	var axis: Dictionary = band.axis(u0, u1, scale.du, start.x, start.z, finish.x, finish.z, Vector2(start.tx, start.tz), Vector2(finish.tx, finish.tz))
	var n: int = axis.x.size()
	var du: float = axis.length / (n - 1)
	var dd: float = scale.dd
	var grade_hard: float = Policy.grade_hard(route_class)
	# Natural reference grade along the axis -> development zones.
	var axis_h := PackedFloat64Array()
	for i in range(n):
		axis_h.append(natural.height_search(axis.x[i], axis.z[i]))
	var develop := PackedByteArray()
	develop.resize(n)
	var develop_count: int = 0
	for i in range(n):
		var a: int = maxi(0, i - 3)
		var b: int = mini(n - 1, i + 3)
		var g: float = absf(axis_h[b] - axis_h[a]) / maxf((b - a) * du, 1.0)
		if g > 0.7 * grade_hard:
			develop[i] = 1
			develop_count += 1
	# Crossing windows: the station nearest each pin (in pin order, monotone),
	# with the channel direction at the pin and the side each approach is on
	# (the road must pass from one side of the channel to the other there).
	var windows: Array = []
	var last_station: int = 0
	for pin: Dictionary in request.pins:
		# A pin on a channel tip (first / last vertex) is geometrically
		# degenerate: aim 6 m into the same channel (inside the C2 envelope).
		var cx: float = pin.x
		var cz: float = pin.z
		var tip: PackedFloat64Array = natural.channel_tip_inward(pin.channel_id, pin.x, pin.z, 3.0, 6.0)
		if not tip.is_empty():
			cx = tip[0]
			cz = tip[1]
		var best_i: int = -1
		var best_d: float = INF
		for i in range(last_station, n):
			var d: float = Vector2(axis.x[i] - cx, axis.z[i] - cz).length()
			if d < best_d:
				best_d = d
				best_i = i
		if best_i < 0 or best_d > 40.0:
			return _fail("ERR_R6_CROSSING_MISSING", {"pin": pin.index, "note": "pin not reachable from the search axis", "distance_m": best_d})
		best_i = clampi(best_i, 1, n - 2)
		var water: PackedFloat64Array = natural.water_search(cx, cz, 6.0)
		var cdx: float = water[4] if int(water[0]) == pin.channel_id else 0.0
		var cdz: float = water[5] if int(water[0]) == pin.channel_id else 0.0
		var before: int = maxi(0, best_i - 3)
		var side: float = signf((axis.x[before] - cx) * cdz - (axis.z[before] - cz) * cdx)
		# Window extent from the R5 crossing geometry: wet length along the
		# road and along-channel spread of an oblique crossing.
		var sine: float = maxf(sin(deg_to_rad(pin.get("angle_deg", 90.0))), 0.3)
		var half_w: float = 0.5 * pin.get("width_m", 2.0)
		var reach_stations: int = ceili((half_w / sine + 8.0) / du)
		var along_limit: float = 6.0 + half_w * sqrt(maxf(0.0, 1.0 - sine * sine)) / sine
		windows.append({"station": best_i, "pin": pin, "x": cx, "z": cz, "tip": not tip.is_empty(), "cdx": cdx, "cdz": cdz, "side": side,
			"reach": reach_stations, "along": along_limit})
		last_station = best_i
	var window_at: Dictionary = {}
	for w: Dictionary in windows:
		window_at[w.station] = w
	# Nodes.
	var node_x := PackedFloat64Array()
	var node_z := PackedFloat64Array()
	var node_h := PackedFloat64Array()
	var node_gx := PackedFloat64Array()
	var node_gz := PackedFloat64Array()
	var node_ride := PackedFloat64Array()
	var node_ok := PackedByteArray()
	var node_why := PackedByteArray()
	var node_near := PackedByteArray()
	var node_window := PackedInt32Array()
	var first := PackedInt32Array()
	var jlo := PackedInt32Array()
	var jcount := PackedInt32Array()
	var offsets: Array = []
	var hint: int = -1
	var avoid: Array = request.get("avoid", [])
	for i in range(n):
		var ax: float = axis.x[i]
		var az: float = axis.z[i]
		var nx: float = axis.nx[i]
		var nz: float = axis.nz[i]
		var c0: PackedFloat64Array = band.clearance(ax, az, hint, 10)
		hint = int(c0[1])
		var j_min: int = 0
		var j_max: int = 0
		if i > 0 and i < n - 1:
			var reach: float = minf(MAX_LATERAL_M, maxf(band.hl[mini(hint + 1, band.count() - 1)], band.hr[mini(hint + 1, band.count() - 1)]) + 8.0)
			reach = maxf(reach, maxf(band.hl[hint], band.hr[hint]) + 8.0)
			j_min = -ceili(minf(reach, MAX_LATERAL_M) / dd)
			j_max = ceili(minf(reach, MAX_LATERAL_M) / dd)
		first.append(node_x.size())
		jlo.append(j_min)
		jcount.append(j_max - j_min + 1)
		var r: float = axis.radius[i]
		var k_sign: float = 0.0
		if i > 0 and i < n - 1:
			k_sign = signf(RMath.three_point_curvature(axis.x[i - 1], axis.z[i - 1], ax, az, axis.x[i + 1], axis.z[i + 1]))
		for j in range(j_min, j_max + 1):
			var d: float = j * dd
			var px: float = ax + nx * d
			var pz: float = az + nz * d
			var ok: bool = Geo.Natural.in_domain(px, pz)
			var why: int = 0 if ok else 1
			# Fold guard: stay inside 0.85 R on the inner side of the axis bend.
			if ok and k_sign != 0.0 and d * k_sign > 0.85 * r:
				ok = false
				why = 2
			if ok and i > 0 and i < n - 1:
				ok = band.clearance(px, pz, hint, 10)[0] >= need
				if not ok:
					why = 3
			var h: float = NAN
			var g := Vector2.ZERO
			var ride: float = 1.0
			var near: int = 0
			var win: int = -1
			if ok:
				h = natural.height_search(px, pz)
				g = natural.gradient_search(px, pz)
				ride = natural.ride_cost_search(px, pz)
				if not is_finite(h) or g.length() >= SLOPE_BLOCK:
					ok = false
					why = 4
			if ok:
				var water: PackedFloat64Array = natural.water_search(px, pz, 14.0)
				if water[7] >= 0.0:
					ok = false
					why = 5
				elif water[0] >= 0.0:
					near = 1
					if water[2] <= water[3] + 4.0:
						ok = false
						why = 6
						for w: Dictionary in windows:
							var pin: Dictionary = w.pin
							if int(water[0]) == pin.channel_id and absi(i - w.station) <= w.reach:
								var along: float = absf((px - w.x) * water[4] + (pz - w.z) * water[5])
								if along <= w.along and Vector2(px - pin.x, pz - pin.z).length() <= Policy.CROSSING_MAX_DISPLACEMENT_M + w.along + water[3]:
									ok = true
									win = pin.index
			if ok and window_at.has(i):
				var w: Dictionary = window_at[i]
				ok = Vector2(px - w.x, pz - w.z).length() <= Policy.CROSSING_MAX_DISPLACEMENT_M - 2.0
				if not ok:
					why = 7
			# Approach sides: stations just before / after a window stay on the
			# channel side their end of the road lies on (near the pin).
			if ok:
				for w: Dictionary in windows:
					var offset: int = i - w.station
					if offset == 0 or absi(offset) > w.reach or w.side == 0.0:
						continue
					if Vector2(px - w.x, pz - w.z).length() > 30.0 + w.along:
						continue
					# Wet nodes of the window itself are on the crossing line.
					if win == pin_index_of(w):
						continue
					var side: float = signf((px - w.x) * w.cdz - (pz - w.z) * w.cdx)
					if side != (w.side if offset < 0 else -w.side):
						ok = false
						why = 8
			if ok and not avoid.is_empty():
				for a: PackedFloat64Array in avoid:
					if absf(a[0] - px) < a[2] and absf(a[1] - pz) < a[2] and Vector2(a[0] - px, a[1] - pz).length() < a[2]:
						ok = false
						why = 9
						break
			if i == 0 or i == n - 1:
				ok = true
				h = natural.height_search(px, pz)
				g = natural.gradient_search(px, pz)
			node_x.append(px)
			node_z.append(pz)
			node_h.append(h)
			node_gx.append(g.x)
			node_gz.append(g.y)
			node_ride.append(ride)
			node_ok.append(1 if ok else 0)
			node_why.append(why)
			node_near.append(near)
			node_window.append(win)
		# Development stations admit traverses up to ~80 deg off the axis.
		var m: int = ceili((5.5 if develop[i] == 1 else 1.25) * du / dd)
		offsets.append(_step_offsets(m))
	var lattice := {"is_valid": true, "n": n, "du": du, "dd": dd, "axis": axis, "axis_length": axis.length, "develop": develop, "develop_count": develop_count,
		"windows": windows, "window_at": window_at, "node_x": node_x, "node_z": node_z, "node_h": node_h, "node_gx": node_gx, "node_gz": node_gz, "node_ride": node_ride,
		"node_ok": node_ok, "node_near": node_near, "node_window": node_window, "first": first, "jlo": jlo, "jcount": jcount, "offsets": offsets,
		"start_heading": atan2(start.tz, start.tx), "end_heading": atan2(finish.tz, finish.tx)}
	for i in range(1, n - 1):
		var any: bool = false
		for k in range(jcount[i]):
			any = any or node_ok[first[i] + k] == 1
		if not any:
			var reason: String = "ERR_R6_CROSSING_APPROACH" if window_at.has(i) else "ERR_R6_CORRIDOR_CLEARANCE"
			var histogram: Dictionary = {}
			var names: Array[String] = ["", "outside_region", "axis_bend_fold", "band_clearance", "natural_slope_or_height", "deep_water", "water_not_crossable", "outside_crossing_window", "wrong_side_of_channel", "other_road"]
			for k in range(jcount[i]):
				var code: int = node_why[first[i] + k]
				histogram[names[code]] = histogram.get(names[code], 0) + 1
			var hint_i: int = int(band.clearance(axis.x[i], axis.z[i], -1, 10)[1])
			return _fail(reason, {"station": i, "x": axis.x[i], "z": axis.z[i], "note": "no admissible lateral slot (band clearance, water, barrier)", "blocked_by": histogram,
				"band_half_width_left_m": band.hl[hint_i], "band_half_width_right_m": band.hr[hint_i], "footprint_need_m": need})
	_transitions(lattice, route_class)
	return lattice


## Admissible lateral step offsets (in slots) of a station: every offset up to
## 4 slots, then strides of 2 (to 8) and 3 slots up to the widest step m, so
## wide traverses stay representable at a fraction of the search work.
static func _step_offsets(m: int) -> PackedInt32Array:
	var positive: Array[int] = []
	var o: int = 1
	while o < m:
		positive.append(o)
		o += 1 if o < 4 else (2 if o < 8 else 3)
	positive.append(m)
	var offs := PackedInt32Array()
	for k in range(positive.size() - 1, -1, -1):
		offs.append(-positive[k])
	offs.append(0)
	for k in range(positive.size()):
		offs.append(positive[k])
	return offs


## Profile-independent transition terms per (station, node, step).
func _transitions(lattice: Dictionary, route_class: int) -> void:
	var cls: Dictionary = Policy.CLASSES[route_class]
	var g_pref: float = cls.grade_pref
	var g_hard: float = Policy.grade_hard(route_class)
	var hf: float = Policy.half_footprint(route_class)
	var bench_cap: float = minf(cls.cut_max_m, cls.cut_max_m + cls.fill_max_m * 0.5)
	var n: int = lattice.n
	var t_len: Array = []
	var t_theta: Array = []
	var t_grade: Array = []
	var t_cross: Array = []
	var t_ride: Array = []
	var node_x: PackedFloat64Array = lattice.node_x
	var node_z: PackedFloat64Array = lattice.node_z
	var node_h: PackedFloat64Array = lattice.node_h
	var node_gx: PackedFloat64Array = lattice.node_gx
	var node_gz: PackedFloat64Array = lattice.node_gz
	var node_ride: PackedFloat64Array = lattice.node_ride
	var node_ok: PackedByteArray = lattice.node_ok
	var node_near: PackedByteArray = lattice.node_near
	var node_window: PackedInt32Array = lattice.node_window
	var first: PackedInt32Array = lattice.first
	var jlo: PackedInt32Array = lattice.jlo
	var jcount: PackedInt32Array = lattice.jcount
	var offsets: Array = lattice.offsets
	for i in range(n - 1):
		var offs: PackedInt32Array = offsets[i]
		var width: int = offs.size()
		var count: int = jcount[i]
		var lens := PackedFloat64Array()
		var thetas := PackedFloat64Array()
		var grades := PackedFloat64Array()
		var crosses := PackedFloat64Array()
		var rides := PackedFloat64Array()
		lens.resize(count * width)
		thetas.resize(count * width)
		grades.resize(count * width)
		crosses.resize(count * width)
		rides.resize(count * width)
		lens.fill(INF)
		for k in range(count):
			var a: int = first[i] + k
			if node_ok[a] == 0:
				continue
			var j: int = jlo[i] + k
			for b in range(width):
				var j2: int = j + offs[b]
				var k2: int = j2 - jlo[i + 1]
				if k2 < 0 or k2 >= jcount[i + 1]:
					continue
				var c: int = first[i + 1] + k2
				if node_ok[c] == 0:
					continue
				var ex: float = node_x[c] - node_x[a]
				var ez: float = node_z[c] - node_z[a]
				var length: float = sqrt(ex * ex + ez * ez)
				if length < 0.5:
					continue
				if (node_near[a] == 1 or node_near[c] == 1) and node_window[a] < 0 and node_window[c] < 0:
					var water: PackedFloat64Array = natural.water_search(0.5 * (node_x[a] + node_x[c]), 0.5 * (node_z[a] + node_z[c]), 3.0)
					if water[0] >= 0.0 and water[2] <= water[3] + 3.0:
						continue
				var g: float = absf(node_h[c] - node_h[a]) / length
				var fg: float
				var g_soft: float = 0.9 * g_hard
				if g <= g_pref:
					fg = 0.1 * (g / g_pref) * (g / g_pref)
				elif g <= g_soft:
					var q: float = (g - g_pref) / maxf(g_soft - g_pref, 1e-6)
					fg = 0.1 + q * q
				else:
					# Sustained grade above the class limit cannot be absorbed by
					# bounded earthwork: length (development) must be cheaper.
					var q: float = (g - g_soft) / (0.1 * g_hard)
					fg = 1.1 + 30.0 * q * q
				var px: float = -ez / length
				var pz: float = ex / length
				var sx: float = absf(0.5 * ((node_gx[a] + node_gx[c]) * px + (node_gz[a] + node_gz[c]) * pz))
				# Balanced section below ~0.4 cross slope; steeper ground needs a
				# full bench (no downhill fill can daylight): uphill cut 2 hf sx.
				var depth: float = sx * hf if sx < 0.4 else 2.0 * sx * hf
				var fx: float = (depth / bench_cap) * (depth / bench_cap)
				if depth > bench_cap:
					fx += 25.0 * (depth / bench_cap - 1.0)
				if sx >= 0.85:
					fx += 50.0
				var idx: int = k * width + b
				lens[idx] = length
				thetas[idx] = atan2(ez, ex)
				grades[idx] = fg
				crosses[idx] = fx
				rides[idx] = maxf(0.0, 0.5 * (node_ride[a] + node_ride[c]) - 1.0)
		t_len.append(lens)
		t_theta.append(thetas)
		t_grade.append(grades)
		t_cross.append(crosses)
		t_ride.append(rides)
	lattice["t_len"] = t_len
	lattice["t_theta"] = t_theta
	lattice["t_grade"] = t_grade
	lattice["t_cross"] = t_cross
	lattice["t_ride"] = t_ride


# =====================================================================
# 2. Dynamic programme over (station, slot, incoming step)
# =====================================================================

## Curvature implied by a polyline corner: the tightest circular fillet of
## deflection `turn` whose tangent length fits in half of the shorter leg,
## 1/R = 2 tan(turn/2) / min(L_in, L_out). Long legs cannot hide a reversal.
static func _corner_curvature(turn: float, len_in: float, len_out: float) -> float:
	if turn >= PI - 1e-6:
		return INF
	return 2.0 * tan(0.5 * turn) / maxf(minf(len_in, len_out), 1e-6)


## Lattice-polyline curvature cost: free up to the class preference, rising
## to 1 at the hard radius, steep beyond it (lattice quantisation; the fitted
## curve is certified against the hard limit), infeasible beyond the cut-off (1.2x, 1.6x on retry).
static func _curvature_penalty(kappa: float, k_pref: float, k_hard: float, cutoff: float) -> float:
	if kappa <= k_pref:
		return 0.0
	if kappa > cutoff * k_hard:
		return INF
	if kappa <= k_hard:
		var q: float = (kappa - k_pref) / maxf(k_hard - k_pref, 1e-6)
		return q * q
	var e: float = (kappa - k_hard) / ((cutoff - 1.0) * k_hard)
	return 1.0 + 40.0 * e * e


func _dynamic_program(lattice: Dictionary, profile: Dictionary, route_class: int, len_adjust: PackedFloat64Array = PackedFloat64Array()) -> Dictionary:
	var cls: Dictionary = Policy.CLASSES[route_class]
	var k_pref: float = 1.0 / cls.radius_pref_m
	var k_hard: float = 1.0 / cls.radius_hard_m
	var n: int = lattice.n
	var du: float = lattice.du
	var first: PackedInt32Array = lattice.first
	var jlo: PackedInt32Array = lattice.jlo
	var jcount: PackedInt32Array = lattice.jcount
	var offsets: Array = lattice.offsets
	var w_len: float = profile.len
	var w_grade: float = profile.grade
	var w_cross: float = profile.cross
	var w_ride: float = profile.ride
	var w_curv: float = profile.curv * 6.0
	var ramp: float = PORT_RAMP_SHARE * Policy.MAX_CURVATURE_CHANGE_PER_M2
	# value[i]: count(i) x width(i-1) (incoming step); back[i] likewise.
	var values: Array = []
	var backs: Array = []
	values.append(PackedFloat64Array([0.0]))
	backs.append(PackedInt32Array([-1]))
	var start_heading: float = lattice.start_heading
	for i in range(n - 1):
		var offs: PackedInt32Array = offsets[i]
		var width: int = offs.size()
		var count: int = jcount[i]
		var next_count: int = jcount[i + 1]
		var next_values := PackedFloat64Array()
		var next_backs := PackedInt32Array()
		next_values.resize(next_count * width)
		next_values.fill(INF)
		next_backs.resize(next_count * width)
		next_backs.fill(-1)
		var lens: PackedFloat64Array = lattice.t_len[i]
		var thetas: PackedFloat64Array = lattice.t_theta[i]
		var grades: PackedFloat64Array = lattice.t_grade[i]
		var crosses: PackedFloat64Array = lattice.t_cross[i]
		var rides: PackedFloat64Array = lattice.t_ride[i]
		var current: PackedFloat64Array = values[i]
		var w_len_i: float = w_len if len_adjust.is_empty() else w_len + len_adjust[i]
		var prev_offs: PackedInt32Array = PackedInt32Array() if i == 0 else offsets[i - 1]
		var in_width: int = 1 if i == 0 else prev_offs.size()
		var prev_lens: PackedFloat64Array = PackedFloat64Array() if i == 0 else lattice.t_len[i - 1]
		var prev_thetas: PackedFloat64Array = PackedFloat64Array() if i == 0 else lattice.t_theta[i - 1]
		var prev_width: int = in_width
		for k in range(count):
			var j: int = jlo[i] + k
			for a in range(in_width):
				var v: float = current[k * in_width + a]
				if v == INF:
					continue
				var theta_in: float
				var len_in: float
				if i == 0:
					theta_in = start_heading
					len_in = du
				else:
					var jp: int = j - prev_offs[a]
					var kp: int = jp - jlo[i - 1]
					theta_in = prev_thetas[kp * prev_width + a]
					len_in = prev_lens[kp * prev_width + a]
				for b in range(width):
					var idx: int = k * width + b
					var length: float = lens[idx]
					if length == INF:
						continue
					dp_transitions += 1
					var turn: float = absf(RMath.wrap_angle(thetas[idx] - theta_in))
					var half: float = 0.5 * (len_in + length)
					var corner: float = _corner_curvature(turn, len_in, length)
					var pen: float = _curvature_penalty(corner, k_pref, k_hard, curvature_cutoff)
					if pen == INF:
						continue
					# Curvature beyond what the retained curvature-change limit allows
					# at this distance from a port is discouraged (the fit needs the
					# room), not forbidden: a port heading may disagree with the axis.
					var ramp_allowed: float = ramp * minf(i, n - 1 - i) * du
					if i >= 1 and corner > ramp_allowed + 1e-9:
						var over: float = (corner - ramp_allowed) / k_hard
						pen += 20.0 * over * over
					var total: float = v + length * (w_len_i + w_grade * grades[idx] + w_cross * crosses[idx] + w_ride * rides[idx]) + w_curv * half * pen
					var k2: int = j + offs[b] - jlo[i + 1]
					var target: int = k2 * width + b
					if total < next_values[target]:
						next_values[target] = total
						next_backs[target] = a
		values.append(next_values)
		backs.append(next_backs)
	# Arrival: single end node; virtual outgoing segment along the end heading.
	var last: int = n - 1
	var final_values: PackedFloat64Array = values[last]
	var end_offs: PackedInt32Array = offsets[last - 1]
	var end_width: int = end_offs.size()
	var end_heading: float = lattice.end_heading
	var best: float = INF
	var best_a: int = -1
	for a in range(end_width):
		var v: float = final_values[a]
		if v == INF:
			continue
		var jp: int = 0 - end_offs[a]
		var kp: int = jp - jlo[last - 1]
		var theta_in: float = lattice.t_theta[last - 1][kp * end_width + a]
		var len_in: float = lattice.t_len[last - 1][kp * end_width + a]
		var turn: float = absf(RMath.wrap_angle(end_heading - theta_in))
		var half: float = 0.5 * (len_in + du)
		var pen: float = _curvature_penalty(_corner_curvature(turn, len_in, du), k_pref, k_hard, curvature_cutoff)
		if pen == INF:
			continue
		var total: float = v + w_curv * half * pen
		if total < best:
			best = total
			best_a = a
	if best_a < 0:
		return _fail("ERR_R6_CORRIDOR_CLEARANCE", {"note": "no lattice path between the ports within band, barrier, water and curvature limits", "profile": profile.name})
	# Backtrack: a_cur is the incoming-step index of the state at station i.
	var js := PackedInt32Array()
	js.resize(n)
	js[last] = 0
	var a_cur: int = best_a
	for i in range(last, 0, -1):
		js[i - 1] = js[i] - offsets[i - 1][a_cur]
		a_cur = backs[i][(js[i] - jlo[i]) * offsets[i - 1].size() + a_cur]
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	for i in range(n):
		var node: int = lattice.first[i] + js[i] - jlo[i]
		xs.append(lattice.node_x[node])
		zs.append(lattice.node_z[node])
	return {"is_valid": true, "x": xs, "z": zs, "j": js, "cost": best}


## Necessary grade condition on a lattice line (exact natural heights): between any
## two nodes the natural rise may exceed g_hard x path length by no more than
## the class cut + fill capacity. A line failing it cannot be profiled within
## bounds whatever the fit: the corridor needs more development room than this
## candidate found (diagnosed, with the worst stretch).
func _grade_reach(line: Dictionary, route_class: int) -> Dictionary:
	var cls: Dictionary = Policy.CLASSES[route_class]
	var g: float = Policy.grade_hard(route_class)
	var slack: float = cls.cut_max_m + cls.fill_max_m
	var xs: PackedFloat64Array = line.x
	var zs: PackedFloat64Array = line.z
	var n: int = xs.size()
	var arc := PackedFloat64Array([0.0])
	var h := PackedFloat64Array([natural.height(clampf(xs[0], 0.0, Geo.DOMAIN_M), clampf(zs[0], 0.0, Geo.DOMAIN_M))])
	for i in range(1, n):
		arc.append(arc[i - 1] + sqrt((xs[i] - xs[i - 1]) ** 2 + (zs[i] - zs[i - 1]) ** 2))
		h.append(natural.height(clampf(xs[i], 0.0, Geo.DOMAIN_M), clampf(zs[i], 0.0, Geo.DOMAIN_M)))
	# max over i<j of |h_j - h_i| - g (arc_j - arc_i): track running extrema of
	# h_i -/+ g arc_i.
	var best: float = -INF
	var best_pair := Vector2i.ZERO
	var low_i: int = 0
	var high_i: int = 0
	for j in range(1, n):
		if h[j - 1] - g * arc[j - 1] < h[low_i] - g * arc[low_i]:
			low_i = j - 1
		if h[j - 1] + g * arc[j - 1] > h[high_i] + g * arc[high_i]:
			high_i = j - 1
		var up: float = (h[j] - g * arc[j]) - (h[low_i] - g * arc[low_i])
		var down: float = (h[high_i] + g * arc[high_i]) - (h[j] + g * arc[j])
		if up > best:
			best = up
			best_pair = Vector2i(low_i, j)
		if down > best:
			best = down
			best_pair = Vector2i(high_i, j)
	if best <= slack:
		return {"is_valid": true}
	var a: int = best_pair.x
	var b: int = best_pair.y
	var length: float = arc[b] - arc[a]
	return {"is_valid": false, "detail": {"note": "natural rise exceeds the class grade times this line's length plus earthwork capacity: more development room needed than the band allowed this candidate",
		"s0": arc[a], "s1": arc[b], "i0": a, "i1": b, "rise_m": absf(h[b] - h[a]), "line_length_m": length, "required_length_m": absf(h[b] - h[a]) / g, "excess_m": best, "x": xs[b], "z": zs[b]}}


# =====================================================================
# 3-5. Candidate fit, profile and measurement
# =====================================================================

func _evaluate(request: Dictionary, lattice: Dictionary, line: Dictionary, profile_index: int) -> Dictionary:
	var route_class: int = request.route_class
	var profile_name: String = PROFILES[profile_index].name
	var summary := {"profile": profile_name, "status": "REJECTED", "reason_code": "", "dp_cost": line.cost}
	var fit: Dictionary = _fit_plan(request, lattice, line)
	summary["fit_iterations"] = fit.get("iterations", 0)
	if not fit.is_valid:
		summary.reason_code = fit.reason_code
		summary["detail"] = fit.get("detail", {})
		return {"is_valid": false, "summary": summary}
	var spline: RMath.PlanSpline = fit.spline
	summary["length_m"] = spline.total_length
	var section: Dictionary = _sections(request, spline)
	if not section.is_valid:
		summary.reason_code = section.reason_code
		summary["detail"] = section.get("detail", {})
		return {"is_valid": false, "summary": summary}
	var crossing: Dictionary = _crossings(request, spline, section)
	if not crossing.is_valid:
		summary.reason_code = crossing.reason_code
		summary["detail"] = crossing.get("detail", {})
		return {"is_valid": false, "summary": summary}
	var prof: Dictionary = _profile(request, spline, section, crossing)
	if not prof.is_valid and prof.reason_code == "ERR_R6_CROSSING_APPROACH":
		# Bounded refinement: fords whose bed approach failed become small
		# bridges where the class may use them (recorded on the crossing).
		var force: Dictionary = {}
		for r: Dictionary in crossing.records:
			if r.support == Policy.Support.FORD and 1 in request.get("allowed_hints", [0, 1, 2]):
				force[r.pin_index] = true
		if not force.is_empty():
			var retry: Dictionary = request.duplicate()
			retry["force_bridge"] = force
			var crossing_retry: Dictionary = _crossings(retry, spline, section)
			if crossing_retry.is_valid:
				var prof_retry: Dictionary = _profile(retry, spline, section, crossing_retry)
				if prof_retry.is_valid:
					crossing = crossing_retry
					prof = prof_retry
	if not prof.is_valid:
		summary.reason_code = prof.reason_code
		summary["detail"] = prof.get("detail", {})
		return {"is_valid": false, "summary": summary}
	var built: Dictionary = _build_design(request, spline, section, crossing, prof)
	if not built.is_valid:
		summary.reason_code = built.reason_code
		summary["detail"] = built.get("detail", {})
		return {"is_valid": false, "summary": summary}
	var design: Dictionary = built.design
	var sight: Dictionary = _sight(request, design)
	design["sight_forward"] = sight.forward
	design["sight_backward"] = sight.backward
	if not sight.is_valid:
		summary.reason_code = "ERR_R6_APPROACH"
		summary["detail"] = sight.detail
		return {"is_valid": false, "summary": summary}
	var features: Array = _intents(request, fit.fair_x, fit.fair_z, section, design)
	var metrics: Dictionary = built.metrics
	metrics["sight_min_ratio"] = sight.min_ratio
	var cls: Dictionary = Policy.CLASSES[route_class]
	# Score: roadbed work, grade excess above preference, length (no feature bonus).
	var score: float = spline.total_length * (1.0 + 0.6 * metrics.mean_abs_earthwork_m / cls.cut_max_m + 1.5 * metrics.mean_grade_excess + 0.2 * metrics.mean_ride_cost_excess)
	summary.status = "FEASIBLE"
	summary["score"] = score
	summary["metrics"] = metrics
	return {"is_valid": true, "summary": summary, "score": score, "design": design, "features": features, "crossings": crossing.records, "metrics": metrics,
		"fair_line": [fit.fair_x, fit.fair_z]}


## Fairing + G2 quintic knots, certified at <= 1 m; bounded retries.
func _fit_plan(request: Dictionary, lattice: Dictionary, line: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var scale: Dictionary = SCALES[route_class]
	var band: Geo.Band = request.band
	var n: int = lattice.n
	var du: float = lattice.du
	var k_hard: float = Policy.curvature_hard(route_class)
	var hf: float = Policy.half_footprint(route_class)
	var px: PackedFloat64Array = line.x.duplicate()
	var pz: PackedFloat64Array = line.z.duplicate()
	var start: Dictionary = request.start
	var finish: Dictionary = request.end
	# Heading at the ports: second / penultimate points on the port tangents.
	px[1] = start.x + start.tx * du
	pz[1] = start.z + start.tz * du
	px[n - 2] = finish.x - finish.tx * du
	pz[n - 2] = finish.z - finish.tz * du
	var weights := PackedFloat64Array()
	weights.resize(n)
	weights.fill(1.0)
	for i in [0, 1, n - 2, n - 1]:
		weights[i] = 1e9
	for w: Dictionary in lattice.windows:
		for d in range(-1, 2):
			var i: int = clampi(w.station + d, 2, n - 3)
			weights[i] = maxf(weights[i], 60.0 if d == 0 else 20.0)
	# Smoothing per lattice row: escalated only where the curve needs it, so
	# development elsewhere (traverses and their turns) is preserved.
	var base_lam: float = pow(scale.fair_m / du, 4.0)
	var lam := PackedFloat64Array()
	lam.resize(n)
	lam.fill(base_lam)
	var iterations: int = 0
	var last_reason: String = ""
	var last_detail: Dictionary = {}
	var first_detail: Dictionary = {}
	for sweep in range(Policy.FIT_SWEEPS):
		for iteration in range(Policy.FIT_ITERATIONS):
			iterations += 1
			fit_evaluations += 1
			var fx: PackedFloat64Array = RMath.fair(px, weights, lam)
			var fz: PackedFloat64Array = RMath.fair(pz, weights, lam)
			var spline: RMath.PlanSpline = _knots(fx, fz, scale.knot, start, finish, lattice.windows)
			var check: Dictionary = _certify_plan(spline, request, k_hard, hf + PLAN_RESERVE_M, fx, fz)
			if check.is_valid:
				return {"is_valid": true, "spline": spline, "fair_x": fx, "fair_z": fz, "iterations": iterations}
			last_reason = check.reason_code
			last_detail = check.detail
			if iterations == 1:
				first_detail = check.detail
			for i: int in check.curvature_stations:
				for d in range(-4, 5):
					var r: int = clampi(i + d, 1, n - 2)
					lam[r] = minf(lam[r] * 1.8, FIT_LAMBDA_CAP * base_lam)
			for i: int in check.clearance_stations:
				var w: int = clampi(i, 2, n - 3)
				weights[w] = minf(weights[w] * 6.0, FIT_WEIGHT_CAP)
			if check.curvature_stations.is_empty() and check.clearance_stations.is_empty():
				break
		# Next sweep: relax smoothing where it was not needed.
		for r in range(n):
			lam[r] = maxf(lam[r] * 0.8, base_lam * 0.5)
	last_detail = last_detail.duplicate()
	last_detail["first_attempt"] = first_detail
	return {"is_valid": false, "reason_code": last_reason, "detail": last_detail, "iterations": iterations}


func _knots(fx: PackedFloat64Array, fz: PackedFloat64Array, stride: int, start: Dictionary, finish: Dictionary, windows: Array) -> RMath.PlanSpline:
	var n: int = fx.size()
	var indices := PackedInt32Array([0])
	var forced: Dictionary = {}
	for w: Dictionary in windows:
		forced[w.station] = true
	var i: int = stride
	while i < n - 1:
		if n - 1 - i < maxi(2, stride / 2 + 1):
			break
		indices.append(i)
		i += stride
	for f: int in forced:
		if not f in indices and f > 0 and f < n - 1:
			indices.append(f)
	indices.sort()
	indices.append(n - 1)
	# Drop knots closer than 2 lattice steps to their neighbour (keep forced).
	var kept := PackedInt32Array([indices[0]])
	for m in range(1, indices.size() - 1):
		if indices[m] - kept[kept.size() - 1] >= 2 or forced.has(indices[m]):
			kept.append(indices[m])
	if indices[indices.size() - 1] - kept[kept.size() - 1] < 2 and kept.size() > 1:
		kept.resize(kept.size() - 1)
	kept.append(n - 1)
	var arc := PackedFloat64Array([0.0])
	for m in range(1, n):
		arc.append(arc[m - 1] + sqrt((fx[m] - fx[m - 1]) ** 2 + (fz[m] - fz[m - 1]) ** 2))
	var spline := RMath.PlanSpline.new()
	for m in range(kept.size()):
		var k: int = kept[m]
		spline.kx.append(fx[k])
		spline.kz.append(fz[k])
		var tx: float
		var tz: float
		var curvature: float = 0.0
		if k == 0:
			tx = start.tx
			tz = start.tz
		elif k == n - 1:
			tx = finish.tx
			tz = finish.tz
		else:
			tx = fx[k + 1] - fx[k - 1]
			tz = fz[k + 1] - fz[k - 1]
			var length: float = sqrt(tx * tx + tz * tz)
			tx /= length
			tz /= length
			curvature = RMath.three_point_curvature(fx[k - 1], fz[k - 1], fx[k], fz[k], fx[k + 1], fz[k + 1])
		spline.ktx.append(tx)
		spline.ktz.append(tz)
		spline.kk.append(curvature)
		if m > 0:
			spline.span_param.append(arc[k] - arc[kept[m - 1]])
	spline.build()
	return spline


func _certify_plan(spline: RMath.PlanSpline, request: Dictionary, k_hard: float, need: float, fx: PackedFloat64Array, fz: PackedFloat64Array) -> Dictionary:
	var band: Geo.Band = request.band
	var total: float = spline.total_length
	var count: int = maxi(4, ceili(total / 1.0))
	var hint: int = -1
	var curvature_bad: bool = false
	var clearance_stations: Array = []
	var curvature_stations: Array = []
	var k_station: int = 0
	var worst_k: float = 0.0
	var worst_dk: float = 0.0
	var worst_clearance: float = INF
	var worst_at := Vector2.ZERO
	var station: int = 0
	var n: int = fx.size()
	for c in range(count + 1):
		var s: float = total * c / count
		var e: PackedFloat64Array = spline.eval_s(s)
		if not is_finite(e[2]) or not is_finite(e[4]):
			return {"is_valid": false, "reason_code": "ERR_R6_FRAME", "detail": {"s": s}, "curvature_bad": true, "clearance_stations": [], "curvature_stations": [n / 2]}
		worst_k = maxf(worst_k, absf(e[4]))
		worst_dk = maxf(worst_dk, absf(e[5]))
		if absf(e[4]) > k_hard + 1e-6 or absf(e[5]) > Policy.MAX_CURVATURE_CHANGE_PER_M2:
			curvature_bad = true
			while k_station < n - 1 and Vector2(fx[k_station] - e[0], fz[k_station] - e[1]).length() > Vector2(fx[k_station + 1] - e[0], fz[k_station + 1] - e[1]).length():
				k_station += 1
			if curvature_stations.is_empty() or curvature_stations[-1] != k_station:
				curvature_stations.append(k_station)
		# Skip the port neighbourhood: ports are certified by the junction planner.
		if s < 3.0 or s > total - 3.0:
			continue
		var cl: PackedFloat64Array = band.clearance(e[0], e[1], hint, 10)
		hint = int(cl[1])
		var margin: float = cl[0] if cl[0] >= need else clearance(request, e[0], e[1], hint)
		if margin < worst_clearance:
			worst_clearance = margin
			worst_at = Vector2(e[0], e[1])
		if margin < need:
			while station < n - 1 and Vector2(fx[station] - e[0], fz[station] - e[1]).length() > Vector2(fx[station + 1] - e[0], fz[station + 1] - e[1]).length():
				station += 1
			if clearance_stations.is_empty() or clearance_stations[-1] != station:
				clearance_stations.append(station)
	if not curvature_bad and clearance_stations.is_empty():
		return {"is_valid": true}
	var reason: String = "ERR_R6_CURVATURE" if curvature_bad else "ERR_R6_CORRIDOR_CLEARANCE"
	return {"is_valid": false, "reason_code": reason, "curvature_bad": curvature_bad, "clearance_stations": clearance_stations, "curvature_stations": curvature_stations,
		"detail": {"max_curvature": worst_k, "max_dk_ds": worst_dk, "min_clearance_m": worst_clearance, "need_m": need, "at": [worst_at.x, worst_at.y]}}


## 2 m sections along the plan curve: centre / edge natural heights (exact),
## outward natural slopes (search grid), water proximity.
func _sections(request: Dictionary, spline: RMath.PlanSpline) -> Dictionary:
	var route_class: int = request.route_class
	var hf: float = Policy.half_footprint(route_class)
	var total: float = spline.total_length
	var n: int = maxi(2, ceili(total / PROFILE_DS))
	var ds: float = total / n
	var s := PackedFloat64Array()
	var x := PackedFloat64Array()
	var z := PackedFloat64Array()
	var tx := PackedFloat64Array()
	var tz := PackedFloat64Array()
	var k := PackedFloat64Array()
	var hc := PackedFloat64Array()
	var hl := PackedFloat64Array()
	var hr := PackedFloat64Array()
	var sl := PackedFloat64Array()
	var sr := PackedFloat64Array()
	var near := PackedByteArray()
	for i in range(n + 1):
		var e: PackedFloat64Array = spline.eval_s(ds * i)
		var nx: float = -e[3]
		var nz: float = e[2]
		s.append(ds * i)
		x.append(e[0])
		z.append(e[1])
		tx.append(e[2])
		tz.append(e[3])
		k.append(e[4])
		# Ribbons may touch the region edge at a gateway node: points within
		# 0.5 m outside are clamped to the boundary; farther is a failure.
		if e[0] < -0.5 or e[1] < -0.5 or e[0] > Geo.DOMAIN_M + 0.5 or e[1] > Geo.DOMAIN_M + 0.5:
			return _fail("ERR_R6_CORRIDOR_CLEARANCE", {"note": "centreline outside region domain", "s": ds * i})
		var c: float = natural.height(clampf(e[0], 0.0, Geo.DOMAIN_M), clampf(e[1], 0.0, Geo.DOMAIN_M))
		var lx: float = e[0] + nx * hf
		var lz: float = e[1] + nz * hf
		var rx: float = e[0] - nx * hf
		var rz: float = e[1] - nz * hf
		var left: float = natural.height(clampf(lx, 0.0, Geo.DOMAIN_M), clampf(lz, 0.0, Geo.DOMAIN_M))
		var right: float = natural.height(clampf(rx, 0.0, Geo.DOMAIN_M), clampf(rz, 0.0, Geo.DOMAIN_M))
		if not is_finite(c) or not is_finite(left) or not is_finite(right):
			return _fail("ERR_R6_CORRIDOR_CLEARANCE", {"note": "section outside region domain", "s": ds * i})
		hc.append(c)
		hl.append(left)
		hr.append(right)
		var gl: Vector2 = natural.gradient_search(lx, lz)
		var gr: Vector2 = natural.gradient_search(rx, rz)
		sl.append(gl.x * nx + gl.y * nz)
		sr.append(-(gr.x * nx + gr.y * nz))
		var water: PackedFloat64Array = natural.water_search(e[0], e[1], 8.0 + hf)
		near.append(1 if water[0] >= 0.0 or water[7] >= 0.0 else 0)
	return {"is_valid": true, "n": n, "ds": ds, "s": s, "x": x, "z": z, "tx": tx, "tz": tz, "k": k, "hc": hc, "hl": hl, "hr": hr, "slope_l": sl, "slope_r": sr, "near_water": near}


## Exact crossings along the final centreline chords, matched one-to-one in
## order to the R5 pins (same channel, <= CROSSING_MAX_DISPLACEMENT_M). Water
## occupancy outside the matched wet spans is a candidate rejection.
func _crossings(request: Dictionary, spline: RMath.PlanSpline, section: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var hf: float = 0.5 * Policy.CLASSES[route_class].width_m
	var n: int = section.n
	var xs: PackedFloat64Array = section.x
	var zs: PackedFloat64Array = section.z
	var s: PackedFloat64Array = section.s
	var found: Array = []
	var bodies: Array = []
	for i in range(n):
		if section.near_water[i] == 0 and section.near_water[i + 1] == 0:
			continue
		var result: Dictionary = natural.segment_crossings(xs[i], zs[i], xs[i + 1], zs[i + 1])
		if not result.is_valid:
			return _fail("ERR_R6_CERTIFICATION_UNRESOLVED", {"note": "crossing query invalid", "reason": result.reason_code, "s": s[i]})
		for record: Dictionary in result.crossings:
			var sc: float = s[i] + record.t * (s[i + 1] - s[i])
			var lx: float = record.x - natural.origin_x
			var lz: float = record.z - natural.origin_z
			if not found.is_empty() and found[-1].channel_id == record.channel_id and absf(found[-1].s - sc) <= 0.01:
				continue
			found.append({"s": sc, "x": lx, "z": lz, "channel_id": record.channel_id, "class": record.class, "width_m": record.width_m, "surface_m": record.surface_m,
				"bed_m": record.bed_m, "angle_deg": record.angle_deg})
		for body: int in result.body_ids:
			bodies.append({"s": s[i], "body": body})
	if not bodies.is_empty():
		return _fail("ERR_R6_WATER_BODY", {"bodies": bodies.slice(0, 4)})
	var pins: Array = request.pins
	var records: Array = []
	var p: int = 0
	for f: Dictionary in found:
		if p < pins.size() and pins[p].channel_id == f.channel_id:
			var shift: float = Vector2(f.x - pins[p].x, f.z - pins[p].z).length()
			if shift > Policy.CROSSING_MAX_DISPLACEMENT_M:
				return _fail("ERR_R6_CROSSING_DISPLACED", {"pin": pins[p].index, "shift_m": shift, "channel_id": f.channel_id})
			records.append(_crossing_record(pins[p], f, request))
			p += 1
		else:
			var reason: String = "ERR_R6_CROSSING_EXTRA"
			return _fail(reason, {"channel_id": f.channel_id, "s": f.s, "x": f.x, "z": f.z, "next_pin": pins[p].index if p < pins.size() else -1})
	if p < pins.size():
		var closest: float = INF
		for i in range(n + 1):
			closest = minf(closest, Vector2(xs[i] - pins[p].x, zs[i] - pins[p].z).length())
		var seen: Array = []
		for f: Dictionary in found:
			seen.append([f.channel_id, snappedf(f.s, 0.1), snappedf(f.x, 0.01), snappedf(f.z, 0.01)])
		return _fail("ERR_R6_CROSSING_MISSING", {"pin": pins[p].index, "channel_id": pins[p].channel_id, "closest_approach_m": closest, "found": seen.slice(0, 6),
			"tip": not natural.channel_tip_inward(pins[p].channel_id, pins[p].x, pins[p].z, 3.0, 6.0).is_empty()})
	# Wet spans and supports.
	for r: Dictionary in records:
		var wet: Dictionary = natural.water_exact(r.actual_x, r.actual_z)
		r["depth_m"] = wet.depth_m if wet.is_valid and wet.is_water else maxf(0.0, r.surface_m - r.bed_m)
		var sine: float = maxf(sin(deg_to_rad(r.angle_deg)), 0.25)
		var cosine: float = sqrt(maxf(0.0, 1.0 - sine * sine))
		# Wet length of the whole riding ribbon (edges cross obliquely).
		var half_span: float = 0.5 * r.width_m / sine + hf * cosine / sine + 0.5
		# The wet extent of the real ribbon (centre and both riding edges) is
		# measured on the exact water field; irregular banks of wide channels
		# can exceed the straight oblique-crossing estimate.
		var measured: Array = _wet_extent(spline, r.s, hf, spline.total_length)
		r["wet_s0"] = minf(r.s - half_span, measured[0])
		r["wet_s1"] = maxf(r.s + half_span, measured[1])
		r["bed_s0"] = r.s - 0.5 * r.width_m / sine
		r["bed_s1"] = r.s + 0.5 * r.width_m / sine
		var allowed: Array = request.get("allowed_hints", [0, 1, 2])
		var support: int = Policy.Support.FORD
		var refined: String = ""
		var hint: int = r.r5_hint
		if hint == 0 and (r.depth_m >= Policy.FORD_MAX_DEPTH_M or 2.0 * half_span > 10.0):
			hint = 1
			refined = "FORD->SMALL_BRIDGE: exact depth %.2f m / wet span %.1f m" % [r.depth_m, 2.0 * half_span]
		elif hint == 0 and request.get("force_bridge", {}).has(r.pin_index):
			hint = 1
			refined = "FORD->SMALL_BRIDGE: ford approach infeasible within grade and earthwork bounds"
		var span: float = 2.0 * half_span + 2.0 * Policy.BRIDGE_BEARING_M
		if hint == 1 and span > Policy.SMALL_BRIDGE_MAX_SPAN_M:
			hint = 2
			refined += ("; " if not refined.is_empty() else "") + "SMALL_BRIDGE->BRIDGE: clear span %.1f m" % span
		if hint >= 1:
			support = Policy.Support.BRIDGE_DECK
		if not hint in allowed:
			return _fail("ERR_R6_CROSSING_SUPPORT", {"pin": r.pin_index, "hint": hint, "note": "class may not use this crossing type"})
		if hint == 2 and span > Policy.BRIDGE_MAX_SPAN_M:
			return _fail("ERR_R6_CROSSING_SUPPORT", {"pin": r.pin_index, "span_m": span})
		r["support"] = support
		r["r6_hint"] = hint
		r["refinement"] = refined
		r["clear_span_m"] = span if support == Policy.Support.BRIDGE_DECK else 2.0 * half_span
		r["deck_s0"] = r.wet_s0 - (Policy.BRIDGE_BEARING_M if support == Policy.Support.BRIDGE_DECK else 0.0)
		r["deck_s1"] = r.wet_s1 + (Policy.BRIDGE_BEARING_M if support == Policy.Support.BRIDGE_DECK else 0.0)
	# Occupancy outside wet spans (centre and riding edges, exact).
	for i in range(n + 1):
		if section.near_water[i] == 0:
			continue
		var inside: bool = false
		for r: Dictionary in records:
			inside = inside or (s[i] >= r.wet_s0 - 1.0 and s[i] <= r.wet_s1 + 1.0)
		if inside:
			continue
		var nx: float = -section.tz[i]
		var nz: float = section.tx[i]
		for o: float in [0.0, hf, -hf]:
			var wet: Dictionary = natural.water_exact(xs[i] + nx * o, zs[i] + nz * o)
			if wet.is_valid and wet.is_water:
				var reason: String = "ERR_R6_WATER_BODY" if wet.kind in ["POND", "CLOSED"] else "ERR_R6_WATER_OCCUPANCY"
				return _fail(reason, {"s": s[i], "kind": wet.kind, "id": wet.id, "depth_m": wet.depth_m})
	return {"is_valid": true, "records": records}


## Contiguous wet interval [s0, s1] (arc length) around a crossing found on
## the centreline: the farthest wet point of the centreline or either riding
## edge on each side (1 m marching until 3 m stay dry, boundary bisected to
## ~2 cm), padded by 0.25 m.
func _wet_extent(spline: RMath.PlanSpline, s_cross: float, hf: float, total: float) -> Array:
	var result: Array = [s_cross, s_cross]
	for direction in [-1.0, 1.0]:
		var last_wet: float = s_cross
		var dry_run: int = 0
		var s_cur: float = s_cross
		while dry_run < 3:
			s_cur += direction
			if s_cur < 0.0 or s_cur > total or absf(s_cur - s_cross) > 150.0:
				break
			if _wet_at(spline, s_cur, hf):
				last_wet = s_cur
				dry_run = 0
			else:
				dry_run += 1
		var wet_s: float = last_wet
		var dry_s: float = last_wet + direction
		for refine in range(6):
			var mid: float = 0.5 * (wet_s + dry_s)
			if mid < 0.0 or mid > total:
				break
			if _wet_at(spline, mid, hf):
				wet_s = mid
			else:
				dry_s = mid
		result[0 if direction < 0.0 else 1] = wet_s + direction * 0.25
	return result


func _wet_at(spline: RMath.PlanSpline, s: float, hf: float) -> bool:
	var e: PackedFloat64Array = spline.eval_s(s)
	var nx: float = -e[3]
	var nz: float = e[2]
	for o: float in [0.0, hf, -hf]:
		var wet: Dictionary = natural.water_exact(clampf(e[0] + nx * o, 0.0, Geo.DOMAIN_M), clampf(e[1] + nz * o, 0.0, Geo.DOMAIN_M))
		if wet.is_valid and wet.is_water:
			return true
	return false


func _crossing_record(pin: Dictionary, f: Dictionary, request: Dictionary) -> Dictionary:
	var shift: float = Vector2(f.x - pin.x, f.z - pin.z).length()
	return {"pin_index": pin.index, "channel_id": f.channel_id, "water_kind": pin.water_kind, "r5_x": pin.x, "r5_z": pin.z, "r5_hint": pin.hint,
		"actual_x": f.x, "actual_z": f.z, "s": f.s, "displacement_m": shift, "angle_deg": f.angle_deg, "width_m": f.width_m, "surface_m": f.surface_m, "bed_m": f.bed_m,
		"justification": "" if shift <= Policy.CROSSING_RECORD_TOLERANCE_M else "terrain-led alignment fit within the C2 envelope (same channel, inside band)"}


## Elevation design on the 2 m sections. Bank comes first (plan curvature
## only), so every bound is exact for the banked cross-section:
##   * per edge: cut / fill within the class limits AND within what a 1:1 cut
##     or 1:2 fill can daylight inside the class tie-in reach (outward slope);
##   * centre cut / fill; bridge deck clearance; ford bed; port heights /
##     grades (pins);
## then the grade-limited (Lipschitz) feasible band, an initial profile near
## the smoothed natural surface, and bounded cyclic slab projections enforcing
## bounds, grade and vertical curvature (comfort limit first, then the hard
## limit). Non-convergence is a diagnosed failure, never a clamp.
func _profile(request: Dictionary, spline: RMath.PlanSpline, section: Dictionary, crossing: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var cls: Dictionary = Policy.CLASSES[route_class]
	var scale: Dictionary = SCALES[route_class]
	var n: int = section.n
	var ds: float = section.ds
	var g: float = Policy.grade_hard(route_class) * PROFILE_GRADE_SHARE
	var hf: float = Policy.half_footprint(route_class)
	var hc: PackedFloat64Array = section.hc
	var hl: PackedFloat64Array = section.hl
	var hr: PackedFloat64Array = section.hr
	var s: PackedFloat64Array = section.s
	var bank: PackedFloat64Array = _section_bank(request, section, crossing)
	var lo := PackedFloat64Array()
	var hi := PackedFloat64Array()
	var kind := PackedByteArray()
	lo.resize(n + 1)
	hi.resize(n + 1)
	kind.resize(n + 1)
	var margin: float = 0.03
	for i in range(n + 1):
		var e: float = hf * tan(deg_to_rad(bank[i]))
		var sl: float = section.slope_l[i]
		var sr: float = section.slope_r[i]
		var fill_l: float = minf(cls.fill_max_m, cls.tie_max_m * maxf(0.0, Policy.FILL_SIDE_SLOPE + sl))
		var cut_l: float = minf(cls.cut_max_m, cls.tie_max_m * maxf(0.0, Policy.CUT_SIDE_SLOPE - sl))
		var fill_r: float = minf(cls.fill_max_m, cls.tie_max_m * maxf(0.0, Policy.FILL_SIDE_SLOPE + sr))
		var cut_r: float = minf(cls.cut_max_m, cls.tie_max_m * maxf(0.0, Policy.CUT_SIDE_SLOPE - sr))
		# Left edge (R5 left, +N) sits at y - e; right edge at y + e.
		var lo_raw: float = maxf(maxf(hl[i] + e - cut_l, hr[i] - e - cut_r), hc[i] - cls.cut_max_m)
		var hi_raw: float = minf(minf(hl[i] + e + fill_l, hr[i] - e + fill_r), hc[i] + cls.fill_max_m)
		# 3 cm interpolation margin, shrunk on a section whose admissible
		# interval is narrower than 15 cm (never beyond a fifth per side).
		var m_i: float = minf(margin, 0.2 * maxf(hi_raw - lo_raw, 0.0))
		lo[i] = lo_raw + m_i
		hi[i] = hi_raw - m_i
		kind[i] = Policy.Support.EARTHWORK
	for r: Dictionary in crossing.records:
		for i in range(n + 1):
			if r.support == Policy.Support.BRIDGE_DECK and s[i] >= r.deck_s0 and s[i] <= r.deck_s1:
				# 2 cm above the required deck level: the interpolant between 2 m samples
				# must also clear it.
				lo[i] = r.surface_m + Policy.DECK_CLEARANCE_M + Policy.DECK_STRUCTURE_M + 0.02
				hi[i] = lo[i] + 3.0
				kind[i] = Policy.Support.BRIDGE_DECK
			elif r.support == Policy.Support.FORD and s[i] >= r.bed_s0 and s[i] <= r.bed_s1:
				# Riding surface on the natural bed over the wet centreline span;
				# approaches are ordinary bounded earthwork.
				lo[i] = hc[i] - 0.05
				hi[i] = hc[i] + 0.10
				kind[i] = Policy.Support.FORD
	var start: Dictionary = request.start
	var finish: Dictionary = request.end
	var pinned := PackedByteArray()
	pinned.resize(n + 1)
	# Gateway / terminus ends (y_free): height designed inside the section
	# bounds, not forced to the natural centre height.
	if not start.get("y_free", false):
		lo[0] = start.y
		hi[0] = start.y
		pinned[0] = 1
	if not finish.get("y_free", false):
		lo[n] = finish.y
		hi[n] = finish.y
		pinned[n] = 1
	var big_lo: PackedFloat64Array = RMath.lipschitz_lower(lo, g, ds)
	var big_hi: PackedFloat64Array = RMath.lipschitz_upper(hi, g, ds)
	for i in range(n + 1):
		if big_lo[i] > big_hi[i] + 1e-6:
			return _profile_failure(i, lo, hi, g, ds, section, kind)
	var target: PackedFloat64Array = RMath.gaussian(hc, 3.0)
	var upper: PackedFloat64Array = RMath.lipschitz_upper(target, g, ds)
	var lower: PackedFloat64Array = RMath.lipschitz_lower(target, g, ds)
	var y := PackedFloat64Array()
	y.resize(n + 1)
	for i in range(n + 1):
		y[i] = clampf(0.5 * (upper[i] + lower[i]), big_lo[i], big_hi[i])
	var smooth: PackedFloat64Array = RMath.gaussian(y, scale.v_sigma)
	for i in range(n + 1):
		y[i] = clampf(smooth[i], big_lo[i], big_hi[i]) if pinned[i] == 0 else y[i]
	# Vertical curvature limit in grade per metre: comfort, then hard (0.8 of
	# the retained 1.2 deg/m so the quintic interpolant stays inside).
	var hard_c: float = 0.8 * deg_to_rad(Policy.MAX_GRADE_CHANGE_DEG_PER_M)
	var comfort_c: float = minf(hard_c, scale.v_comfort)
	var grade_start: Array = [-g * ds, g * ds]
	var grade_end: Array = [-g * ds, g * ds]
	if start.grade_pinned:
		grade_start = [start.grade * ds, start.grade * ds]
	if finish.grade_pinned:
		grade_end = [finish.grade * ds, finish.grade * ds]
	# Bounded attempt ladder [vertical-curvature limit, grade share]: comfort
	# first, then the hard sampling limit; a certified failure of the quintic
	# interpolant between samples tightens the sampled limits. The retained
	# hard limits (grade, 1.2 deg/m) are never relaxed; the exact reachability
	# solve names the first sample where the bounds cannot be met.
	var ladder: Array = [[comfort_c, 1.0], [hard_c, 1.0], [0.8 * hard_c, 0.99], [0.6 * hard_c, 0.98]]
	var profile: RMath.ProfileSpline = null
	var last_failure: Dictionary = {}
	var attempt: int = 0
	var y_final := PackedFloat64Array()
	var start_y: PackedFloat64Array = y
	while attempt < ladder.size():
		var c_lim: float = ladder[attempt][0]
		var g_lim: float = g * ladder[attempt][1]
		attempt += 1
		fit_evaluations += 1
		var gs: Array = [maxf(grade_start[0], -g_lim * ds), minf(grade_start[1], g_lim * ds)] if not start.grade_pinned else grade_start
		var ge: Array = [maxf(grade_end[0], -g_lim * ds), minf(grade_end[1], g_lim * ds)] if not finish.grade_pinned else grade_end
		var prepared: Dictionary = _project_profile(start_y, big_lo, big_hi, pinned, g_lim * ds, c_lim * ds * ds)
		var solved: Dictionary = RMath.solve_profile(big_lo, big_hi, gs, ge, g_lim * ds, c_lim * ds * ds, prepared.y, PROFILE_TRACK_GRADE, PROFILE_TRACK_JERK)
		if not solved.feasible:
			var detail: Dictionary = solved.fail_detail.duplicate()
			detail["s"] = s[solved.fail_index]
			detail["x"] = section.x[solved.fail_index]
			detail["z"] = section.z[solved.fail_index]
			detail["curvature_limit_per_m"] = c_lim
			detail["note"] = "no vertical profile satisfies the grade, vertical-curvature and cut/fill bounds at this sample (exact reachability)"
			last_failure = _fail("ERR_R6_GRADE_TRANSITION", detail)
			if attempt >= 2 or c_lim >= hard_c:
				break
			continue
		for i in range(solved.y.size()):
			if pinned[i] == 1:
				solved.y[i] = lo[i]
		y_final = solved.y
		profile = _profile_spline_states(solved, s, ds)
		var worst: Dictionary = _certify_profile(profile, s[n], Policy.grade_hard(route_class))
		if worst.is_empty():
			last_failure = {}
			break
		last_failure = _fail(worst.reason, worst)
		profile = null
	if profile == null:
		return last_failure
	return {"is_valid": true, "spline": profile, "y": y_final, "kind": kind, "lo": big_lo, "hi": big_hi, "bank": bank, "attempts": attempt}


## Fine (0.5 m) check of the profile interpolant: grade and grade change.
static func _certify_profile(profile: RMath.ProfileSpline, total: float, g_hard: float) -> Dictionary:
	var steps: int = maxi(4, ceili(total / 0.5))
	for q in range(steps + 1):
		var p: PackedFloat64Array = profile.eval(total * q / steps)
		if absf(p[1]) > g_hard:
			return {"reason": "ERR_R6_GRADE", "s": total * q / steps, "value": absf(p[1])}
		var dgrade: float = rad_to_deg(absf(p[2]) / (1.0 + p[1] * p[1]))
		if dgrade > Policy.MAX_GRADE_CHANGE_DEG_PER_M:
			return {"reason": "ERR_R6_GRADE_TRANSITION", "s": total * q / steps, "value": dgrade}
	return {}


## Quintic Hermite elevation through the solved states: height, grade p / ds
## and the mean of the adjacent per-sample curvatures at every sample.
static func _profile_spline_states(solved: Dictionary, s: PackedFloat64Array, ds: float) -> RMath.ProfileSpline:
	var y: PackedFloat64Array = solved.y
	var p: PackedFloat64Array = solved.p
	var q: PackedFloat64Array = solved.q
	var n: int = y.size() - 1
	var profile := RMath.ProfileSpline.new()
	for i in range(n + 1):
		profile.ks.append(s[i])
		profile.ky.append(y[i])
		profile.kg.append(p[i] / ds)
		var curvature: float
		if i == 0:
			curvature = q[0]
		elif i == n:
			curvature = q[n - 1]
		else:
			curvature = 0.5 * (q[i - 1] + q[i])
		profile.kc.append(curvature / (ds * ds))
	profile.build()
	return profile


## Cyclic projections onto the box [lo, hi], the grade slabs |y_{i+1} - y_i|
## <= gd, the curvature slabs |y_{i-1} - 2 y_i + y_{i+1}| <= cd and the
## curvature-change slabs (third differences <= cd / JERK_SAMPLES); pinned
## samples never move. At most PROFILE_PREP_SWEEPS sweeps: the result is a
## near-feasible tracking reference, not a certificate.
static func _project_profile(start: PackedFloat64Array, lo: PackedFloat64Array, hi: PackedFloat64Array, pinned: PackedByteArray, gd: float, cd: float) -> Dictionary:
	var jd: float = cd / JERK_SAMPLES
	var y: PackedFloat64Array = start.duplicate()
	var n: int = y.size()
	var violation: float = INF
	for sweep in range(PROFILE_PREP_SWEEPS):
		for i in range(1, n - 1):
			var c: float = y[i - 1] - 2.0 * y[i] + y[i + 1]
			if absf(c) > cd:
				var excess: float = (c - signf(c) * cd) * PROFILE_RELAX
				var w0: float = 0.0 if pinned[i - 1] == 1 else 1.0
				var w1: float = 0.0 if pinned[i] == 1 else 1.0
				var w2: float = 0.0 if pinned[i + 1] == 1 else 1.0
				var norm: float = w0 + 4.0 * w1 + w2
				if norm > 0.0:
					var f: float = excess / norm
					y[i - 1] -= f * w0
					y[i] += 2.0 * f * w1
					y[i + 1] -= f * w2
		for i in range(1, n - 2):
			var j: float = -y[i - 1] + 3.0 * y[i] - 3.0 * y[i + 1] + y[i + 2]
			if absf(j) > jd:
				var excess: float = (j - signf(j) * jd) * PROFILE_RELAX
				var w0: float = 0.0 if pinned[i - 1] == 1 else 1.0
				var w1: float = 0.0 if pinned[i] == 1 else 1.0
				var w2: float = 0.0 if pinned[i + 1] == 1 else 1.0
				var w3: float = 0.0 if pinned[i + 2] == 1 else 1.0
				var norm: float = w0 + 9.0 * w1 + 9.0 * w2 + w3
				if norm > 0.0:
					var f: float = excess / norm
					y[i - 1] += f * w0
					y[i] -= 3.0 * f * w1
					y[i + 1] += 3.0 * f * w2
					y[i + 2] -= f * w3
		for i in range(n - 1):
			var d: float = y[i + 1] - y[i]
			if absf(d) > gd:
				var excess: float = d - signf(d) * gd
				var a: float = 0.0 if pinned[i] == 1 else 1.0
				var b: float = 0.0 if pinned[i + 1] == 1 else 1.0
				if a + b > 0.0:
					y[i] += excess * a / (a + b)
					y[i + 1] -= excess * b / (a + b)
		for i in range(n):
			if pinned[i] == 0:
				y[i] = clampf(y[i], lo[i], hi[i])
		if sweep % 20 == 19:
			violation = 0.0
			for i in range(n):
				var v: float = maxf(lo[i] - y[i], y[i] - hi[i])
				if i < n - 1:
					v = maxf(v, absf(y[i + 1] - y[i]) - gd)
				if i > 0 and i < n - 1:
					v = maxf(v, absf(y[i - 1] - 2.0 * y[i] + y[i + 1]) - cd)
				violation = maxf(violation, v)
			if violation <= PROFILE_PREP_TOLERANCE_M:
				break
	return {"y": y, "violation": violation}


## Bank on the 2 m sections: partial superelevation from plan curvature at
## the design speed, smoothed over 10 m, tapered to the port crossfall at the
## ends and to zero over crossing supports (with 15 m transitions).
func _section_bank(request: Dictionary, section: Dictionary, crossing: Dictionary) -> PackedFloat64Array:
	var route_class: int = request.route_class
	var cls: Dictionary = Policy.CLASSES[route_class]
	var v: float = cls.design_speed_kmh / 3.6
	var n: int = section.n
	var raw := PackedFloat64Array()
	raw.resize(n + 1)
	for i in range(n + 1):
		raw[i] = clampf(rad_to_deg(atan(v * v * section.k[i] / 9.80665)) * SCALES[route_class].bank_gain, -cls.bank_max_deg, cls.bank_max_deg)
	var bank: PackedFloat64Array = _smooth_by_distance(section.s, raw, 10.0)
	var total: float = section.s[n]
	var ramp: float = 20.0
	for i in range(n + 1):
		var sc: float = section.s[i]
		var value: float = lerpf(request.start.bank_deg, bank[i], _smoothstep(clampf(sc / ramp, 0.0, 1.0)))
		value = lerpf(request.end.bank_deg, value, _smoothstep(clampf((total - sc) / ramp, 0.0, 1.0)))
		for r: Dictionary in crossing.records:
			var d: float = 0.0
			if sc < r.deck_s0:
				d = r.deck_s0 - sc
			elif sc > r.deck_s1:
				d = sc - r.deck_s1
			value *= _smoothstep(clampf((d - 2.0) / 15.0, 0.0, 1.0))
		bank[i] = value
	return bank


func _profile_failure(i: int, lo: PackedFloat64Array, hi: PackedFloat64Array, g: float, ds: float, section: Dictionary, kind: PackedByteArray) -> Dictionary:
	var n: int = lo.size()
	var best_j: int = i
	var best_lo: float = -INF
	var best_k: int = i
	var best_hi: float = INF
	for j in range(n):
		var v: float = lo[j] - g * absf(i - j) * ds
		if v > best_lo:
			best_lo = v
			best_j = j
		var w: float = hi[j] + g * absf(i - j) * ds
		if w < best_hi:
			best_hi = w
			best_k = j
	var a: int = mini(best_j, best_k)
	var b: int = maxi(best_j, best_k)
	var natural_grade: float = absf(section.hc[b] - section.hc[a]) / maxf((b - a) * ds, ds)
	var reason: String = "ERR_R6_EARTHWORK"
	if kind[best_j] != Policy.Support.EARTHWORK or kind[best_k] != Policy.Support.EARTHWORK:
		reason = "ERR_R6_CROSSING_APPROACH"
	elif natural_grade > g or best_j == 0 or best_j == n - 1 or best_k == 0 or best_k == n - 1:
		reason = "ERR_R6_GRADE"
	return _fail(reason, {"s": section.s[i], "x": section.x[i], "z": section.z[i], "required_low_m": best_lo, "allowed_high_m": best_hi,
		"low_from_s": section.s[best_j], "high_from_s": section.s[best_k], "natural_grade": natural_grade, "grade_limit": g})


## Export-density design arrays with frames inputs, bank, earthwork and checks.
func _build_design(request: Dictionary, spline: RMath.PlanSpline, section: Dictionary, crossing: Dictionary, prof: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var cls: Dictionary = Policy.CLASSES[route_class]
	var profile: RMath.ProfileSpline = prof.spline
	var total: float = spline.total_length
	var g_hard: float = Policy.grade_hard(route_class)
	var k_hard: float = Policy.curvature_hard(route_class)
	var width: float = cls.width_m
	var hf: float = Policy.half_footprint(route_class)
	# Adaptive sample positions: chord error <= 1 cm, <= 2 m nominal, 1 m on decks.
	var positions := PackedFloat64Array([0.0])
	var s: float = 0.0
	while s < total:
		var e: PackedFloat64Array = spline.eval_s(s)
		var kk: float = maxf(absf(e[4]), absf(spline.eval_s(minf(total, s + 1.0))[4]))
		var step: float = minf(Policy.NOMINAL_SAMPLE_M, sqrt(8.0 * Policy.CHORD_ERROR_M / maxf(kk, 1e-9)))
		for r: Dictionary in crossing.records:
			if s >= r.deck_s0 - 4.0 and s <= r.deck_s1 + 4.0:
				step = minf(step, 1.0)
		step = maxf(step, Policy.MIN_SUBDIVISION_M * 2.0)
		s = minf(total, s + step)
		if total - s < 0.3 and s < total:
			s = total
		positions.append(s)
	positions = _refine_positions(spline, profile, positions)
	if positions.size() > Policy.MAX_FINAL_SAMPLES:
		return _fail("ERR_R6_SEARCH_BUDGET", {"samples": positions.size()})
	var count: int = positions.size()
	var arrays := {}
	for key: String in ["s", "x", "y", "z", "tx", "tz", "grade", "k", "dk", "vk", "bank", "width", "nat_c", "nat_l", "nat_r", "fill_l", "fill_r", "tie_l", "tie_r"]:
		var a := PackedFloat64Array()
		a.resize(count)
		arrays[key] = a
	var support := PackedByteArray()
	support.resize(count)
	var bank_raw := PackedFloat64Array()
	bank_raw.resize(count)
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat64Array()
	var txs := PackedFloat64Array()
	var tzs := PackedFloat64Array()
	var ks := PackedFloat64Array()
	var dks := PackedFloat64Array()
	var grades := PackedFloat64Array()
	var vks := PackedFloat64Array()
	for c in range(count):
		var e: PackedFloat64Array = spline.eval_s(positions[c])
		var p: PackedFloat64Array = profile.eval(positions[c])
		if not is_finite(e[0]) or not is_finite(e[2]) or not is_finite(e[4]) or not is_finite(p[0]) or not is_finite(p[1]):
			return _fail("ERR_R6_NONFINITE", {"s": positions[c]})
		xs.append(e[0])
		zs.append(e[1])
		txs.append(e[2])
		tzs.append(e[3])
		ks.append(e[4])
		dks.append(e[5])
		ys.append(p[0])
		grades.append(p[1])
		vks.append(p[2])
		bank_raw[c] = _interp(section.s, prof.bank, positions[c])
		var kind: int = Policy.Support.EARTHWORK
		for r: Dictionary in crossing.records:
			if positions[c] >= r.deck_s0 and positions[c] <= r.deck_s1:
				kind = r.support
		support[c] = kind
	# Bank: the profile stage's section bank (continuous, port crossfall at the
	# ends, zero over crossing supports), interpolated to the export samples.
	var bank: PackedFloat64Array = bank_raw
	bank[0] = request.start.bank_deg
	bank[count - 1] = request.end.bank_deg
	# Earthwork and tie-in per sample (natural heights linearly interpolated
	# from the exact 2 m sections).
	var nat_c := PackedFloat64Array()
	var nat_l := PackedFloat64Array()
	var nat_r := PackedFloat64Array()
	var fill_l := PackedFloat64Array()
	var fill_r := PackedFloat64Array()
	var tie_l := PackedFloat64Array()
	var tie_r := PackedFloat64Array()
	var sec_s: PackedFloat64Array = section.s
	var sum_work: float = 0.0
	var sum_grade_excess: float = 0.0
	var sum_ride: float = 0.0
	var max_cut: float = 0.0
	var max_fill: float = 0.0
	var max_tie: float = 0.0
	var max_grade: float = 0.0
	var max_dgrade: float = 0.0
	var max_k: float = 0.0
	var max_dk: float = 0.0
	var failures: Array = []
	var band: Geo.Band = request.band
	var hint: int = -1
	for c in range(count):
		var sc: float = positions[c]
		var j: int = clampi(floori(sc / section.ds), 0, section.n - 1)
		var f: float = clampf((sc - sec_s[j]) / section.ds, 0.0, 1.0)
		var c_nat: float = lerpf(section.hc[j], section.hc[j + 1], f)
		var l_nat: float = lerpf(section.hl[j], section.hl[j + 1], f)
		var r_nat: float = lerpf(section.hr[j], section.hr[j + 1], f)
		var l_slope: float = lerpf(section.slope_l[j], section.slope_l[j + 1], f)
		var r_slope: float = lerpf(section.slope_r[j], section.slope_r[j + 1], f)
		nat_c.append(c_nat)
		nat_l.append(l_nat)
		nat_r.append(r_nat)
		var tb: float = tan(deg_to_rad(bank[c]))
		# R5-left side (+N) is the rider's right: positive bank lowers it.
		var edge_l: float = ys[c] - hf * tb
		var edge_r: float = ys[c] + hf * tb
		var dl: float = edge_l - l_nat
		var dr: float = edge_r - r_nat
		fill_l.append(dl)
		fill_r.append(dr)
		var t_l: float = 0.0
		var t_r: float = 0.0
		if support[c] == Policy.Support.EARTHWORK:
			t_l = _tie(dl, l_slope)
			t_r = _tie(dr, r_slope)
			max_cut = maxf(max_cut, maxf(maxf(-dl, -dr), c_nat - ys[c]))
			max_fill = maxf(max_fill, maxf(maxf(dl, dr), ys[c] - c_nat))
			sum_work += (absf(dl) + absf(dr) + absf(ys[c] - c_nat)) / 3.0
			if -dl > cls.cut_max_m + 1e-6 or -dr > cls.cut_max_m + 1e-6 or c_nat - ys[c] > cls.cut_max_m + 1e-6:
				failures.append(["ERR_R6_EARTHWORK", sc, "cut", maxf(maxf(-dl, -dr), c_nat - ys[c])])
			if dl > cls.fill_max_m + 1e-6 or dr > cls.fill_max_m + 1e-6 or ys[c] - c_nat > cls.fill_max_m + 1e-6:
				failures.append(["ERR_R6_EARTHWORK", sc, "fill", maxf(maxf(dl, dr), ys[c] - c_nat)])
			if t_l > cls.tie_max_m or t_r > cls.tie_max_m:
				failures.append(["ERR_R6_EARTHWORK", sc, "tie_in", maxf(t_l, t_r)])
		tie_l.append(t_l)
		tie_r.append(t_r)
		max_tie = maxf(max_tie, maxf(t_l, t_r))
		var gabs: float = absf(grades[c])
		max_grade = maxf(max_grade, gabs)
		sum_grade_excess += maxf(0.0, gabs - cls.grade_pref) / maxf(g_hard - cls.grade_pref, 1e-6)
		var dgrade: float = rad_to_deg(absf(vks[c]) / (1.0 + grades[c] * grades[c]))
		max_dgrade = maxf(max_dgrade, dgrade)
		max_k = maxf(max_k, absf(ks[c]))
		max_dk = maxf(max_dk, absf(dks[c]))
		if gabs > g_hard + 1e-6:
			failures.append(["ERR_R6_GRADE", sc, "grade", gabs])
		if dgrade > Policy.MAX_GRADE_CHANGE_DEG_PER_M + 1e-6:
			failures.append(["ERR_R6_GRADE_TRANSITION", sc, "dgrade_deg_per_m", dgrade])
		if absf(ks[c]) > k_hard + 1e-6:
			failures.append(["ERR_R6_CURVATURE", sc, "curvature", absf(ks[c])])
		if absf(dks[c]) > Policy.MAX_CURVATURE_CHANGE_PER_M2 + 1e-9:
			failures.append(["ERR_R6_CURVATURE", sc, "dk_ds", absf(dks[c])])
		if absf(bank[c]) > Policy.MAX_BANK_DEG:
			failures.append(["ERR_R6_BANK", sc, "bank", bank[c]])
		# Footprint inside the band (or, inside a junction zone, the union of
		# the incident bands): centre, both shoulder edges and tie-ins.
		var nx: float = -tzs[c]
		var nz: float = txs[c]
		var cl: PackedFloat64Array = band.clearance(xs[c], zs[c], hint, 10)
		hint = int(cl[1])
		var reach_l: float = hf + t_l
		var reach_r: float = hf + t_r
		var c_min: float = minf(minf(clearance(request, xs[c], zs[c], hint), clearance(request, xs[c] + nx * reach_l, zs[c] + nz * reach_l, hint)),
			clearance(request, xs[c] - nx * reach_r, zs[c] - nz * reach_r, hint))
		if c_min < 0.0:
			failures.append(["ERR_R6_CORRIDOR_CLEARANCE", sc, "footprint", c_min])
		if failures.size() > 0:
			break
	if not failures.is_empty():
		var f0: Array = failures[0]
		return _fail(f0[0], {"s": f0[1], "what": f0[2], "value": f0[3]})
	arrays.s = positions
	arrays.x = xs
	arrays.y = ys
	arrays.z = zs
	arrays.tx = txs
	arrays.tz = tzs
	arrays.grade = grades
	arrays.k = ks
	arrays.dk = dks
	arrays.vk = vks
	arrays.bank = bank
	var widths := PackedFloat64Array()
	widths.resize(count)
	widths.fill(width)
	arrays.width = widths
	arrays.nat_c = nat_c
	arrays.nat_l = nat_l
	arrays.nat_r = nat_r
	arrays.fill_l = fill_l
	arrays.fill_r = fill_r
	arrays.tie_l = tie_l
	arrays.tie_r = tie_r
	arrays["support"] = support
	var metrics := {"length_m": total, "samples": count, "max_grade": max_grade, "max_dgrade_deg_per_m": max_dgrade, "max_curvature": max_k, "min_radius_m": 1.0 / maxf(max_k, 1e-9),
		"max_dk_ds": max_dk, "max_cut_m": max_cut, "max_fill_m": max_fill, "max_tie_m": max_tie, "mean_abs_earthwork_m": sum_work / count,
		"mean_grade_excess": sum_grade_excess / count, "mean_ride_cost_excess": 0.0, "climb_m": 0.0, "descent_m": 0.0}
	var climb: float = 0.0
	var descent: float = 0.0
	for c in range(1, count):
		var dy: float = ys[c] - ys[c - 1]
		climb += maxf(dy, 0.0)
		descent += maxf(-dy, 0.0)
	metrics.climb_m = climb
	metrics.descent_m = descent
	return {"is_valid": true, "design": arrays, "metrics": metrics}


## Subdivides export intervals where the stored derivatives would disagree with
## the sampled points (ExecPlan §5.8: subdivide at strong curvature and vertical
## transitions): chord heading vs mean tangent, chord slope vs mean grade, turn
## rate vs mean curvature, each kept below half of the validator tolerance.
func _refine_positions(spline: RMath.PlanSpline, profile: RMath.ProfileSpline, positions: PackedFloat64Array) -> PackedFloat64Array:
	var current: PackedFloat64Array = positions
	var min_interval: float = 2.0 * Policy.MIN_SUBDIVISION_M
	for pass_index in range(8):
		var evals: Array = []
		for position: float in current:
			evals.append([spline.eval_s(position), profile.eval(position)])
		var refined := PackedFloat64Array([current[0]])
		var changed: bool = false
		for i in range(1, current.size()):
			var a: Array = evals[i - 1]
			var b: Array = evals[i]
			var ds: float = current[i] - current[i - 1]
			var split: bool = false
			if ds > min_interval and current.size() < Policy.MAX_FINAL_SAMPLES:
				var cx: float = b[0][0] - a[0][0]
				var cz: float = b[0][1] - a[0][1]
				var heading: float = absf(rad_to_deg(RMath.wrap_angle(atan2(cz, cx) - atan2(a[0][3] + b[0][3], a[0][2] + b[0][2]))))
				var grade_error: float = absf((b[1][0] - a[1][0]) / ds - 0.5 * (b[1][1] + a[1][1]))
				var turn: float = RMath.wrap_angle(atan2(b[0][3], b[0][2]) - atan2(a[0][3], a[0][2]))
				var curvature_error: float = absf(turn / ds - 0.5 * (a[0][4] + b[0][4]))
				split = heading > 0.25 or grade_error > 0.0025 or curvature_error > 0.001
			if split:
				refined.append(0.5 * (current[i - 1] + current[i]))
				changed = true
			refined.append(current[i])
		current = refined
		if not changed:
			break
	return current


## Admissible-domain clearance (m, < 0 outside): the piece's own band; inside
## a junction zone (request.zones: [{x, z, bands}]) the union with the other
## incident bands (§7). Region edge is a hard limit except at gateway ends.
static func clearance(request: Dictionary, x: float, z: float, hint: int) -> float:
	var band: Geo.Band = request.band
	var best: float = band.clearance(x, z, hint, 10)[0]
	for zone: Dictionary in request.get("zones", []):
		if Vector2(x - zone.x, z - zone.z).length() > Policy.JUNCTION_ZONE_M:
			continue
		for other: Geo.Band in zone.bands:
			best = maxf(best, other.clearance(x, z, -1)[0])
	if not request.get("gateway_ends", false):
		best = minf(best, minf(minf(x, z), minf(Geo.DOMAIN_M - x, Geo.DOMAIN_M - z)))
	return best


## Horizontal daylight reach beyond the shoulder edge for a section with
## road-minus-natural `delta` (> 0 fill) and outward natural rise `slope`.
static func _tie(delta: float, slope: float) -> float:
	if delta < 0.0:
		var rate: float = Policy.CUT_SIDE_SLOPE - slope
		return INF if rate <= 0.0 else -delta / rate
	if delta > 0.0:
		var rate: float = Policy.FILL_SIDE_SLOPE + slope
		return INF if rate <= 0.0 else delta / rate
	return 0.0


static func _smoothstep(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## Gaussian smoothing over arc length for non-uniform samples (sigma in m).
static func _smooth_by_distance(s: PackedFloat64Array, values: PackedFloat64Array, sigma: float) -> PackedFloat64Array:
	var n: int = s.size()
	var result := PackedFloat64Array()
	result.resize(n)
	var lo: int = 0
	for i in range(n):
		while s[i] - s[lo] > 3.0 * sigma:
			lo += 1
		var acc: float = 0.0
		var wsum: float = 0.0
		var j: int = lo
		while j < n and s[j] - s[i] <= 3.0 * sigma:
			var d: float = s[j] - s[i]
			var w: float = exp(-0.5 * d * d / (sigma * sigma))
			acc += w * values[j]
			wsum += w
			j += 1
		result[i] = acc / wsum
	return result


# =====================================================================
# Sight lines and stopping distance (both directions)
# =====================================================================

func _sight(request: Dictionary, design: Dictionary) -> Dictionary:
	var route_class: int = request.route_class
	var cls: Dictionary = Policy.CLASSES[route_class]
	var s: PackedFloat64Array = design.s
	var n: int = s.size()
	var total: float = s[n - 1]
	var hf: float = Policy.half_footprint(route_class)
	var v: float = Kinematic.kmh_to_mps(cls.design_speed_kmh)
	var forward := PackedFloat64Array()
	var backward := PackedFloat64Array()
	forward.resize(n)
	backward.resize(n)
	var stations: int = maxi(1, ceili(total / Policy.SIGHT_STATION_M))
	var fwd_station := PackedFloat64Array()
	var back_station := PackedFloat64Array()
	var min_ratio: float = INF
	var worst: Dictionary = {}
	var unchecked: int = 0
	for q in range(stations + 1):
		var s0: float = total * q / stations
		for direction: int in [1, -1]:
			var seen: float = _sight_from(design, s0, direction, hf)
			var grade: float = _interp(design.s, design.grade, s0) * direction
			var slope_deg: float = rad_to_deg(atan(grade))
			var need: Kinematic.BrakingEvaluation = Kinematic.calculate_braking_distance(v, 0.0, slope_deg, Kinematic.BrakingRegime.NORMAL)
			var remaining: float = (total - s0) if direction == 1 else s0
			var required: float = need.distance_m if need.is_valid else INF
			# Within `required` of the piece end the sight line continues onto
			# the connected piece: not measurable here, counted as unchecked.
			if remaining < required and need.is_valid:
				unchecked += 1
			else:
				var ratio: float = seen / required if required > 0.0 else INF
				if ratio < min_ratio:
					min_ratio = ratio
					worst = {"s": s0, "direction": direction, "sight_m": seen, "required_m": required, "slope_deg": slope_deg, "braking": need.status}
			if direction == 1:
				fwd_station.append(seen)
			else:
				back_station.append(seen)
	for c in range(n):
		var f: float = s[c] / total * stations
		var a: int = clampi(floori(f), 0, stations)
		var b: int = mini(a + 1, stations)
		forward[c] = minf(fwd_station[a], fwd_station[b])
		backward[c] = minf(back_station[a], back_station[b])
	var ok: bool = min_ratio >= 1.0
	return {"is_valid": ok, "forward": forward, "backward": backward, "min_ratio": min_ratio, "detail": worst, "unchecked_end_stations": unchecked}


static func _interp(xs: PackedFloat64Array, ys: PackedFloat64Array, x: float) -> float:
	var n: int = xs.size()
	var i: int = clampi(xs.bsearch(x) - 1, 0, n - 2)
	var t: float = clampf((x - xs[i]) / maxf(xs[i + 1] - xs[i], 1e-12), 0.0, 1.0)
	return ys[i] + t * (ys[i + 1] - ys[i])


## First blocked target distance along the road from s0 (eye 1.4 m, object
## 0.4 m above the road); obstruction = natural search surface outside the
## road section, road surface inside it.
func _sight_from(design: Dictionary, s0: float, direction: int, hf: float) -> float:
	var s: PackedFloat64Array = design.s
	var total: float = s[s.size() - 1]
	var ex: float = _interp(s, design.x, s0)
	var ez: float = _interp(s, design.z, s0)
	var ey: float = _interp(s, design.y, s0) + Policy.EYE_HEIGHT_M
	var d: float = Policy.SIGHT_STEP_M
	while d <= Policy.SIGHT_MAX_M:
		var st: float = s0 + direction * d
		if st < 0.0 or st > total:
			# Clear up to the piece end (continuation is on the next piece).
			return (total - s0) if direction == 1 else s0
		var tx: float = _interp(s, design.x, st)
		var tz: float = _interp(s, design.z, st)
		var ty: float = _interp(s, design.y, st) + Policy.OBJECT_HEIGHT_M
		var samples: int = maxi(2, ceili(d / 5.0))
		for q in range(1, samples):
			var f: float = float(q) / samples
			var px: float = ex + (tx - ex) * f
			var pz: float = ez + (tz - ez) * f
			var line_y: float = ey + (ty - ey) * f
			var sr: float = s0 + direction * d * f
			var rx: float = _interp(s, design.x, sr)
			var rz: float = _interp(s, design.z, sr)
			var lateral: float = Vector2(px - rx, pz - rz).length()
			var ground: float = _interp(s, design.y, sr) if lateral <= hf else natural.height_search(px, pz)
			if ground > line_y:
				return d - Policy.SIGHT_STEP_M
		d += Policy.SIGHT_STEP_M
	return Policy.SIGHT_MAX_M


# =====================================================================
# Feature intents (selected candidate geometry, before final validation)
# =====================================================================

## Intents from the candidate's faired plan line and the natural terrain under
## it. Envelopes are fixed here; realisation is measured independently on the
## exported samples by the feasibility validator.
func _intents(request: Dictionary, fx: PackedFloat64Array, fz: PackedFloat64Array, section: Dictionary, design: Dictionary) -> Array:
	var route_class: int = request.route_class
	var cls: Dictionary = Policy.CLASSES[route_class]
	var n: int = fx.size()
	var arc := PackedFloat64Array([0.0])
	for i in range(1, n):
		arc.append(arc[i - 1] + sqrt((fx[i] - fx[i - 1]) ** 2 + (fz[i] - fz[i - 1]) ** 2))
	# Map faired-line arc to design arc (proportional; both span port to port).
	var scale_s: float = design.s[design.s.size() - 1] / maxf(arc[n - 1], 1e-9)
	var kappa := PackedFloat64Array()
	kappa.resize(n)
	for i in range(1, n - 1):
		kappa[i] = RMath.three_point_curvature(fx[i - 1], fz[i - 1], fx[i], fz[i], fx[i + 1], fz[i + 1])
	var lobes: Array = RMath.turn_lobes(arc, kappa, 1.0 / (6.0 * cls.radius_pref_m), 8.0)
	var features: Array = []
	for lobe: Dictionary in lobes:
		var turn: float = rad_to_deg(lobe.turn)
		var length: float = lobe.s1 - lobe.s0
		# A switchback is a tight reversal (>= 100 deg at a mean radius within
		# twice the class preference); wider reversals are sustained sweeps.
		if absf(turn) >= 100.0 and length / deg_to_rad(absf(turn)) <= 2.0 * cls.radius_pref_m:
			features.append(_feature("SWITCHBACK", lobe.s0 * scale_s, lobe.s1 * scale_s, {"turn_deg": turn, "min_turn_deg": 0.75 * absf(turn), "sign": signf(turn)}))
		elif absf(turn) >= 30.0 and length >= maxf(30.0, 0.9 * cls.radius_pref_m):
			features.append(_feature("SWEEP", lobe.s0 * scale_s, lobe.s1 * scale_s, {"turn_deg": turn, "min_turn_deg": 0.75 * absf(turn), "sign": signf(turn), "length_m": length * scale_s}))
	# Linked turns: >= 2 consecutive opposite lobes (each >= 12 deg) with gaps <= 30 m.
	var run: Array = []
	for lobe: Dictionary in lobes:
		if absf(rad_to_deg(lobe.turn)) < 12.0:
			if run.size() >= 2:
				features.append(_linked(run, scale_s))
			run = []
			continue
		if not run.is_empty() and (signf(run[-1].turn) == signf(lobe.turn) or lobe.s0 - run[-1].s1 > 30.0):
			if run.size() >= 2:
				features.append(_linked(run, scale_s))
			run = []
		run.append(lobe)
	if run.size() >= 2:
		features.append(_linked(run, scale_s))
	# Calm stretches: long, nearly straight, gentle-grade natural ground.
	var calm_k: float = 1.0 / (4.0 * cls.radius_pref_m)
	var calm_min: float = 150.0 if route_class <= 1 else 100.0
	var start_i: int = -1
	for i in range(n):
		var calm: bool = absf(kappa[i]) <= calm_k
		if calm and start_i < 0:
			start_i = i
		if (not calm or i == n - 1) and start_i >= 0:
			var end_i: int = i if calm else i - 1
			if arc[end_i] - arc[start_i] >= calm_min:
				var heading_change: float = 0.0
				for m in range(start_i, end_i):
					heading_change += kappa[m] * (arc[m + 1] - arc[m])
				features.append(_feature("CALM", arc[start_i] * scale_s, arc[end_i] * scale_s, {"max_curvature": calm_k, "max_turn_deg": maxf(12.0, absf(rad_to_deg(heading_change)) + 6.0)}))
			start_i = -1
	# Vertical intents from the natural surface under the candidate.
	var hs: PackedFloat64Array = RMath.gaussian(section.hc, 10.0)
	var ss: PackedFloat64Array = section.s
	var m0: int = 0
	var count: int = hs.size()
	while m0 < count - 1:
		var direction: float = signf(hs[mini(m0 + 1, count - 1)] - hs[m0])
		var m1: int = m0 + 1
		while m1 < count - 1 and signf(hs[m1 + 1] - hs[m1]) == direction:
			m1 += 1
		var rise: float = hs[m1] - hs[m0]
		var length: float = ss[m1] - ss[m0]
		if absf(rise) >= 12.0 and length > 0.0 and absf(rise) / length >= 0.03:
			features.append(_feature("CLIMB" if rise > 0.0 else "DESCENT", ss[m0], ss[m1], {"rise_m": rise, "min_rise_m": 0.7 * absf(rise)}))
		m0 = m1
	for i in range(1, count - 1):
		var is_max: bool = hs[i] > hs[i - 1] and hs[i] >= hs[i + 1]
		var is_min: bool = hs[i] < hs[i - 1] and hs[i] <= hs[i + 1]
		if not is_max and not is_min:
			continue
		var a: int = i
		var b: int = i
		while a > 0 and ss[i] - ss[a] < 60.0:
			a -= 1
		while b < count - 1 and ss[b] - ss[i] < 60.0:
			b += 1
		var base: float = 0.5 * (hs[a] + hs[b])
		var prominence: float = (hs[i] - base) * (1.0 if is_max else -1.0)
		if prominence >= 2.5:
			features.append(_feature("CREST" if is_max else "COMPRESSION", ss[a], ss[b], {"apex_s": ss[i], "prominence_m": prominence, "min_prominence_m": 0.5 * prominence}))
	return features


static func _feature(kind: String, s0: float, s1: float, envelope: Dictionary) -> Dictionary:
	return {"kind": kind, "s0": s0, "s1": s1, "envelope": envelope, "status": "", "measured": {}, "reasons": []}


static func _linked(run: Array, scale_s: float) -> Dictionary:
	var signs := PackedFloat64Array()
	var turns := PackedFloat64Array()
	for lobe: Dictionary in run:
		signs.append(signf(lobe.turn))
		turns.append(rad_to_deg(lobe.turn))
	return _feature("LINKED_TURNS", run[0].s0 * scale_s, run[-1].s1 * scale_s, {"signs": signs, "turns_deg": turns, "min_lobe_deg": 8.0})
