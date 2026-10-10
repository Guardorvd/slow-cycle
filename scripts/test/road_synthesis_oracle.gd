extends RefCounted

## Independent R6 oracle (ExecPlan §§8, 10, 13). Measures exported RoadPathData
## and the public R3/R4/R5 data with its own geometry; it never calls the
## production RoadFeasibilityValidator, designer or corridor-band code. Limits
## are the approved regional_road/1 numbers (the specification), measurement
## is independent:
##   path_checks      arrays, finiteness, 3D chord distances, spacing, frames,
##                    tangent / slope / curvature against point differences,
##                    grade / grade change / curvature / curvature change / bank;
##   band_clearance   own implementation of the R5 band (linearly interpolated
##                    half-widths, round caps at station corners);
##   channel_hits     road polyline x HydrologyPlan channel centrelines (pure
##                    segment intersection) and body cells;
##   barrier_samples  RideabilityField.sample on the centre line;
##   seam             exported end rows of two pieces meeting at a port;
##   heading_change   integrated tangent turning over an arc range;
##   r5_recertify     R5 reference lines resampled every <= 4 m against public
##                    R4 samples and HydrologyPlan geometry (R5 DEBT-3), without
##                    the builder's defect counter or audit_crossings.

const RoadMath = preload("res://scripts/world/road_math.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")

## Approved class limits (regional_road/1 §6): grade hard deg, hard radius m.
const GRADE_HARD_DEG: Array[float] = [5.0, 8.0, 10.0, 12.0]
const RADIUS_HARD_M: Array[float] = [35.0, 25.0, 19.0, 19.0]
const PATCH_GRADE_MAX: float = 0.10


## Returns {failures: [String], measured: {...}} for one exported path.
static func path_checks(path: RefCounted, route_class: int, connector: bool) -> Dictionary:
	var failures: Array = []
	var n: int = path.points.size()
	var arrays: Array = [path.tangents, path.normals, path.binormals, path.cumulative_distances, path.slopes, path.curvatures, path.segment_types, path.surface_contact_states,
		path.banking_angles, path.sight_distances, path.road_widths, path.macro_elevation_offsets]
	for a: Variant in arrays:
		if a.size() != n:
			return {"failures": ["array_size"], "measured": {}}
	if n < 2:
		return {"failures": ["too_few_samples"], "measured": {}}
	var max_step: float = 0.0
	var dist_err: float = 0.0
	var max_unit: float = 0.0
	var max_ortho: float = 0.0
	var min_up: float = INF
	var min_flip: float = INF
	var max_tangent_dev: float = 0.0
	var max_slope_dev: float = 0.0
	var max_grade_deg: float = 0.0
	var max_dgrade: float = 0.0
	var max_k: float = 0.0
	var max_dk: float = 0.0
	var max_k_dev: float = 0.0
	var max_bank: float = 0.0
	var signed_k := PackedFloat64Array()
	signed_k.resize(n)
	for i in range(n):
		var p: Vector3 = path.points[i]
		var t: Vector3 = path.tangents[i]
		var nn: Vector3 = path.normals[i]
		var b: Vector3 = path.binormals[i]
		if not (p.is_finite() and t.is_finite() and nn.is_finite() and b.is_finite() and is_finite(path.cumulative_distances[i]) and is_finite(path.slopes[i]) and is_finite(path.curvatures[i])):
			return {"failures": ["nonfinite"], "measured": {"index": i}}
		max_unit = maxf(max_unit, maxf(absf(t.length() - 1.0), maxf(absf(nn.length() - 1.0), absf(b.length() - 1.0))))
		max_ortho = maxf(max_ortho, maxf(absf(t.dot(nn)), absf(t.dot(b))))
		min_up = minf(min_up, nn.y)
		max_bank = maxf(max_bank, absf(path.banking_angles[i]))
		max_grade_deg = maxf(max_grade_deg, absf(path.slopes[i]))
		max_k = maxf(max_k, path.curvatures[i])
		if path.surface_contact_states[i] != 0 or path.macro_elevation_offsets[i] != 0.0:
			failures.append("contact_or_offset")
		if i > 0:
			var q: Vector3 = path.points[i - 1]
			var chord: float = p.distance_to(q)
			max_step = maxf(max_step, chord)
			dist_err = maxf(dist_err, absf((path.cumulative_distances[i] - path.cumulative_distances[i - 1]) - chord))
			min_flip = minf(min_flip, nn.dot(path.normals[i - 1]))
			# Tangent vs the chord direction (mean of the two sampled tangents).
			var mean_t: Vector3 = (t + path.tangents[i - 1]).normalized()
			max_tangent_dev = maxf(max_tangent_dev, rad_to_deg(mean_t.angle_to(p - q)))
			var horizontal: float = Vector2(p.x - q.x, p.z - q.z).length()
			var chord_slope: float = rad_to_deg(atan2(p.y - q.y, horizontal))
			max_slope_dev = maxf(max_slope_dev, absf(chord_slope - 0.5 * (path.slopes[i] + path.slopes[i - 1])))
			max_dgrade = maxf(max_dgrade, absf(path.slopes[i] - path.slopes[i - 1]) / maxf(horizontal, 1e-6))
	# Signed horizontal curvature from points (circle through neighbours).
	for i in range(1, n - 1):
		var a := Vector2(path.points[i - 1].x, path.points[i - 1].z)
		var c := Vector2(path.points[i].x, path.points[i].z)
		var e := Vector2(path.points[i + 1].x, path.points[i + 1].z)
		var ab: Vector2 = c - a
		var bc: Vector2 = e - c
		var denominator: float = ab.length() * bc.length() * (e - a).length()
		signed_k[i] = 0.0 if denominator <= 1e-9 else 2.0 * ab.cross(bc) / denominator
		# float32 points: allow the position-rounding error of the 3-point estimate.
		var rounding: float = 2.0e-3 / maxf(ab.length() * bc.length(), 1e-6)
		max_k_dev = maxf(max_k_dev, absf(absf(signed_k[i]) - path.curvatures[i]) - rounding)
	for i in range(2, n - 1):
		var ds: float = Vector2(path.points[i].x - path.points[i - 1].x, path.points[i].z - path.points[i - 1].z).length()
		max_dk = maxf(max_dk, absf(path.curvatures[i] - path.curvatures[i - 1]) / maxf(ds, 1e-6))
	var grade_limit_deg: float = rad_to_deg(atan(PATCH_GRADE_MAX)) if connector else GRADE_HARD_DEG[route_class]
	var k_limit: float = 1.0 / RADIUS_HARD_M[route_class]
	if max_step > 2.5 + 1e-4:
		failures.append("spacing")
	if dist_err > 1e-3:
		failures.append("distance")
	if max_unit > 1e-4 or max_ortho > 1e-4 or min_up < 0.5 or min_flip < cos(deg_to_rad(5.0)):
		failures.append("frame")
	if max_tangent_dev > 0.5:
		failures.append("tangent_vs_points")
	if max_slope_dev > 0.3:
		failures.append("slope_vs_points")
	if max_grade_deg > grade_limit_deg + 1e-3:
		failures.append("grade")
	if max_dgrade > 1.2 + 0.05:
		failures.append("grade_change")
	if max_k > k_limit + 1e-5:
		failures.append("curvature")
	if max_k_dev > 0.004:
		failures.append("curvature_vs_points")
	if max_dk > 0.003 + 2e-4:
		failures.append("curvature_change")
	if max_bank > 8.0 + 1e-6:
		failures.append("bank")
	return {"failures": failures, "measured": {"samples": n, "max_step_m": max_step, "distance_error_m": dist_err, "unit_error": max_unit, "orthogonality_error": max_ortho,
		"min_normal_up": min_up, "min_adjacent_normal_dot": min_flip, "tangent_vs_points_deg": max_tangent_dev, "slope_vs_points_deg": max_slope_dev, "max_grade_deg": max_grade_deg,
		"max_grade_change_deg_per_m": max_dgrade, "max_curvature": max_k, "curvature_vs_points": max_k_dev, "max_curvature_change": max_dk, "max_bank_deg": max_bank}, "signed_k": signed_k}


## Two reversals reproduce the canonical export; one reversal mirrors it.
static func reversal_checks(forward: RefCounted, backward: RefCounted, twice: RefCounted) -> Array:
	var failures: Array = []
	var n: int = forward.points.size()
	if backward.points.size() != n or twice.points.size() != n:
		return ["reversal_size"]
	var total: float = forward.cumulative_distances[n - 1]
	for i in range(n):
		var j: int = n - 1 - i
		if forward.points[i].distance_to(backward.points[j]) > 1e-4 or forward.tangents[i].dot(backward.tangents[j]) > -0.9999:
			failures.append("reversal_mirror")
			break
		if forward.normals[i].dot(backward.normals[j]) < 0.9999:
			failures.append("reversal_normal")
			break
		if absf(forward.slopes[i] + backward.slopes[j]) > 1e-4 or absf(forward.banking_angles[i] + backward.banking_angles[j]) > 1e-4:
			failures.append("reversal_sign")
			break
		if absf((total - forward.cumulative_distances[i]) - backward.cumulative_distances[j]) > 2e-3:
			failures.append("reversal_distance")
			break
	for i in range(n):
		if forward.points[i] != twice.points[i] or forward.tangents[i] != twice.tangents[i] or forward.normals[i] != twice.normals[i] or forward.slopes[i] != twice.slopes[i]:
			failures.append("double_reversal")
			break
	return failures


## Band clearance (m, < 0 outside) of a world-local point for an R5 corridor
## view (own implementation: segment strips with interpolated half-widths and
## round caps per side at interior stations).
static func band_clearance(corridor: Dictionary, ox: float, oz: float, x: float, z: float) -> float:
	var best: float = -INF
	var n: int = corridor.station_count
	for k in range(n - 1):
		var ax: float = corridor.x_m[k] - ox
		var az: float = corridor.z_m[k] - oz
		var bx: float = corridor.x_m[k + 1] - ox
		var bz: float = corridor.z_m[k + 1] - oz
		var d := Vector2(bx - ax, bz - az)
		var length: float = d.length()
		var u: Vector2 = d / length
		var r := Vector2(x - ax, z - az)
		var t: float = r.dot(u) / length
		var lateral: float = -r.x * u.y + r.y * u.x
		if t >= 0.0 and t <= 1.0:
			var left: float = lerpf(corridor.half_left_m[k], corridor.half_left_m[k + 1], t)
			var right: float = lerpf(corridor.half_right_m[k], corridor.half_right_m[k + 1], t)
			best = maxf(best, minf(left - lateral, lateral + right))
	for k in range(1, n - 1):
		var px: float = corridor.x_m[k] - ox
		var pz: float = corridor.z_m[k] - oz
		var d0 := Vector2(px - (corridor.x_m[k - 1] - ox), pz - (corridor.z_m[k - 1] - oz)).normalized()
		var d1 := Vector2((corridor.x_m[k + 1] - ox) - px, (corridor.z_m[k + 1] - oz) - pz).normalized()
		var bis: Vector2 = Vector2(-d0.y, d0.x) + Vector2(-d1.y, d1.x)
		var r := Vector2(x - px, z - pz)
		var side: float = r.dot(bis)
		best = maxf(best, (corridor.half_left_m[k] if side >= 0.0 else corridor.half_right_m[k]) - r.length())
	return best


## Crossings of the road polyline with HydrologyPlan channel centrelines (pure
## geometry, local metres): [{s, x, z, channel_id}] in road order; body cells
## the road passes through (32 m lattice, nearest-point semantics as R3).
static func channel_hits(path: RefCounted, hydrology_plan: RefCounted) -> Dictionary:
	var hits: Array = []
	var segments: Array = []
	for c in range(hydrology_plan.get_channel_count()):
		var channel: Dictionary = hydrology_plan.get_channel(c)
		for k in range(channel.x_cm.size() - 1):
			segments.append([Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0, Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / 100.0, channel.id])
	var body_of: Dictionary = {}
	for b in range(hydrology_plan.get_body_count()):
		for cell: int in hydrology_plan.get_body(b).cells:
			body_of[cell] = hydrology_plan.get_body(b).id
	var bodies: Dictionary = {}
	for i in range(1, path.points.size()):
		var a := Vector2(path.points[i - 1].x, path.points[i - 1].z)
		var b := Vector2(path.points[i].x, path.points[i].z)
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
		for seg: Array in segments:
			var p: Vector2 = seg[0]
			var q: Vector2 = seg[1]
			if maxf(p.x, q.x) < lo.x or minf(p.x, q.x) > hi.x or maxf(p.y, q.y) < lo.y or minf(p.y, q.y) > hi.y:
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(a, b, p, q)
			if hit != null:
				var s: float = path.cumulative_distances[i - 1] + a.distance_to(hit)
				var duplicate: bool = false
				for h: Dictionary in hits:
					duplicate = duplicate or (h.channel_id == seg[2] and absf(h.s - s) <= 0.05)
				if not duplicate:
					hits.append({"s": s, "x": hit.x, "z": hit.y, "channel_id": seg[2]})
		var cell: int = clampi(roundi(b.y / 32.0), 0, 128) * 129 + clampi(roundi(b.x / 32.0), 0, 128)
		if body_of.has(cell):
			bodies[body_of[cell]] = true
	hits.sort_custom(func(m: Dictionary, k: Dictionary) -> bool: return m.s < k.s)
	return {"hits": hits, "bodies": bodies.keys()}


## Natural barrier samples (R4 public query) every `step` m on the centre line,
## skipping deck rows (`deck_ranges` in exported distance): [blocked count,
## samples, worst].
static func barrier_samples(path: RefCounted, rideability: RefCounted, ox: float, oz: float, step: float, deck_ranges: Array) -> Dictionary:
	var blocked: int = 0
	var samples: int = 0
	var next_s: float = 0.0
	var worst: Dictionary = {}
	for i in range(path.points.size()):
		var s: float = path.cumulative_distances[i]
		if s < next_s:
			continue
		next_s = s + step
		var on_deck: bool = false
		for r: Array in deck_ranges:
			on_deck = on_deck or (s >= r[0] and s <= r[1])
		if on_deck:
			continue
		samples += 1
		var p: Vector3 = path.points[i]
		var r: Dictionary = rideability.sample(ox + clampf(p.x, 0.0, 4096.0), oz + clampf(p.z, 0.0, 4096.0))
		if r.is_valid and r.blocked:
			blocked += 1
			worst = {"s": s, "flags": r.reason_flags, "slope_grade": r.slope_grade, "depth": r.water_depth_m}
	return {"blocked": blocked, "samples": samples, "worst": worst}


## Seam between the end of `a` and the start of `b` (both oriented to travel
## through the port).
static func seam(a: RefCounted, b: RefCounted) -> Dictionary:
	var i: int = a.points.size() - 1
	return {"position_m": a.points[i].distance_to(b.points[0]), "tangent_deg": rad_to_deg(a.tangents[i].angle_to(b.tangents[0])),
		"slope_deg": absf(a.slopes[i] - b.slopes[0]), "normal_deg": rad_to_deg(a.normals[i].angle_to(b.normals[0]))}


static func seam_ok(m: Dictionary) -> bool:
	return m.position_m <= 0.001 and m.tangent_deg <= 0.2 and m.slope_deg <= 0.1 and m.normal_deg <= 0.5


## Integrated horizontal heading change (deg, signed toward the R5 left normal
## (-dz, +dx)) between exported distances s0 and s1.
static func heading_change(path: RefCounted, s0: float, s1: float) -> float:
	var total: float = 0.0
	for i in range(1, path.points.size()):
		var s: float = path.cumulative_distances[i]
		if s <= s0 or path.cumulative_distances[i - 1] >= s1:
			continue
		var a := Vector2(path.tangents[i - 1].x, path.tangents[i - 1].z)
		var b := Vector2(path.tangents[i].x, path.tangents[i].z)
		total += a.angle_to(b)
	return rad_to_deg(total)


## R5 DEBT-3: every R5 reference line resampled every <= 4 m with public R4
## samples; blocked spans by reason; recorded STEEP_PINCH / crossing flags are
## compared with what is found (independent of the builder's certification).
static func r5_recertify(graph: RefCounted, rideability: RefCounted, hydrology_plan: RefCounted) -> Dictionary:
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var edges: Array = []
	var totals := {"samples": 0, "steep_blocked": 0, "deep_water_blocked": 0, "deep_water_unrecorded": 0, "steep_unflagged": 0}
	for e in range(graph.get_edge_count()):
		var c: Dictionary = graph.get_corridor(e)
		var length: float = 0.0
		var arcs := PackedFloat64Array([0.0])
		for k in range(1, c.station_count):
			length += Vector2(c.x_m[k] - c.x_m[k - 1], c.z_m[k] - c.z_m[k - 1]).length()
			arcs.append(length)
		var steps: int = maxi(1, ceili(length / 4.0))
		var record := {"edge_id": e, "samples": 0, "steep": 0, "deep_water": 0, "deep_water_unrecorded": 0, "steep_unflagged": 0}
		for q in range(steps + 1):
			var at: float = length * q / steps
			var k: int = clampi(arcs.bsearch(at) - 1, 0, c.station_count - 2)
			var t: float = (at - arcs[k]) / maxf(arcs[k + 1] - arcs[k], 1e-9)
			var x: float = lerpf(c.x_m[k], c.x_m[k + 1], t)
			var z: float = lerpf(c.z_m[k], c.z_m[k + 1], t)
			var r: Dictionary = rideability.sample(x, z)
			record.samples += 1
			if not r.is_valid:
				continue
			var nearest: int = k if t < 0.5 else k + 1
			if r.reason_flags & Ride.Reason.EXCESSIVE_SLOPE:
				record.steep += 1
				if (c.flags[nearest] & Graph.Flag.STEEP_PINCH) == 0 and (c.flags[k] & Graph.Flag.STEEP_PINCH) == 0 and (c.flags[k + 1] & Graph.Flag.STEEP_PINCH) == 0:
					record.steep_unflagged += 1
			if r.reason_flags & Ride.Reason.DEEP_WATER:
				record.deep_water += 1
				var recorded: bool = false
				for crossing: Dictionary in c.crossings:
					recorded = recorded or Vector2(crossing.x_m - x, crossing.z_m - z).length() <= 24.0
				if not recorded:
					record.deep_water_unrecorded += 1
		totals.samples += record.samples
		totals.steep_blocked += record.steep
		totals.deep_water_blocked += record.deep_water
		totals.deep_water_unrecorded += record.deep_water_unrecorded
		totals.steep_unflagged += record.steep_unflagged
		edges.append(record)
	return {"totals": totals, "edges": edges}
