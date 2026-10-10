class_name RegionalRoadMath
extends RefCounted

## Pure float64 mathematics for R6 regional roads (ExecPlan §5). Scalar
## float64 only (Vector2/Vector3 are float32): local metres, never world.
##
## Plan curves are G2 piecewise quintic Hermite splines: each knot carries
## position, unit tangent and signed curvature; a span of nominal length L
## uses P' = L T and P'' = L^2 k N at its knots (N = (-tz, tx), the R5 band
## "left" side), so position, tangent and curvature are continuous at every
## knot. Elevation is a 1D quintic Hermite spline over horizontal arc length
## with value / grade / vertical curvature at each knot. Arc length uses
## 5-point Gauss-Legendre on 16 sub-intervals per span plus Newton inversion.
## Signed curvature k > 0 turns towards N; RoadPathData calls that side the
## rider's right (binormal = tangent x up), so the sign conventions agree.

const GL_X := [-0.9061798459386640, -0.5384693101056831, 0.0, 0.5384693101056831, 0.9061798459386640]
const GL_W := [0.2369268850561891, 0.4786286704993665, 0.5688888888888889, 0.4786286704993665, 0.2369268850561891]
const ARC_SUBDIVISIONS: int = 16


## Monomial coefficients c0..c5 of the quintic on t in [0, 1] with value,
## first and second derivative (w.r.t. t) given at both ends.
static func quintic(p0: float, v0: float, a0: float, p1: float, v1: float, a1: float) -> PackedFloat64Array:
	var d: float = p1 - p0
	return PackedFloat64Array([p0, v0, 0.5 * a0,
		10.0 * d - 6.0 * v0 - 4.0 * v1 - 1.5 * a0 + 0.5 * a1,
		-15.0 * d + 8.0 * v0 + 7.0 * v1 + 1.5 * a0 - a1,
		6.0 * d - 3.0 * v0 - 3.0 * v1 - 0.5 * a0 + 0.5 * a1])


static func poly(c: PackedFloat64Array, o: int, t: float) -> float:
	return c[o] + t * (c[o + 1] + t * (c[o + 2] + t * (c[o + 3] + t * (c[o + 4] + t * c[o + 5]))))


static func poly_d1(c: PackedFloat64Array, o: int, t: float) -> float:
	return c[o + 1] + t * (2.0 * c[o + 2] + t * (3.0 * c[o + 3] + t * (4.0 * c[o + 4] + t * 5.0 * c[o + 5])))


static func poly_d2(c: PackedFloat64Array, o: int, t: float) -> float:
	return 2.0 * c[o + 2] + t * (6.0 * c[o + 3] + t * (12.0 * c[o + 4] + t * 20.0 * c[o + 5]))


static func poly_d3(c: PackedFloat64Array, o: int, t: float) -> float:
	return 6.0 * c[o + 3] + t * (24.0 * c[o + 4] + t * 60.0 * c[o + 5])


## G2 quintic plan spline. Knot arrays are parallel PackedFloat64Arrays.
class PlanSpline extends RefCounted:
	var kx := PackedFloat64Array()
	var kz := PackedFloat64Array()
	var ktx := PackedFloat64Array()
	var ktz := PackedFloat64Array()
	var kk := PackedFloat64Array()
	var span_param := PackedFloat64Array()   # nominal L per span
	var cx := PackedFloat64Array()           # 6 per span
	var cz := PackedFloat64Array()
	var span_start := PackedFloat64Array()   # cumulative arc length at span start
	var span_arc := PackedFloat64Array()     # ARC_SUBDIVISIONS + 1 per span (relative)
	var total_length: float = 0.0

	func span_count() -> int:
		return span_param.size()

	func build() -> void:
		cx.resize(0)
		cz.resize(0)
		span_start.resize(0)
		span_arc.resize(0)
		total_length = 0.0
		for i in range(span_param.size()):
			var length: float = span_param[i]
			var nx0: float = -ktz[i]
			var nz0: float = ktx[i]
			var nx1: float = -ktz[i + 1]
			var nz1: float = ktx[i + 1]
			cx.append_array(RegionalRoadMath.quintic(kx[i], length * ktx[i], length * length * kk[i] * nx0, kx[i + 1], length * ktx[i + 1], length * length * kk[i + 1] * nx1))
			cz.append_array(RegionalRoadMath.quintic(kz[i], length * ktz[i], length * length * kk[i] * nz0, kz[i + 1], length * ktz[i + 1], length * length * kk[i + 1] * nz1))
			span_start.append(total_length)
			var acc: float = 0.0
			span_arc.append(0.0)
			for j in range(RegionalRoadMath.ARC_SUBDIVISIONS):
				acc += _gl(i, float(j) / RegionalRoadMath.ARC_SUBDIVISIONS, float(j + 1) / RegionalRoadMath.ARC_SUBDIVISIONS)
				span_arc.append(acc)
			total_length += acc

	func speed(i: int, t: float) -> float:
		var o: int = 6 * i
		var dx: float = RegionalRoadMath.poly_d1(cx, o, t)
		var dz: float = RegionalRoadMath.poly_d1(cz, o, t)
		return sqrt(dx * dx + dz * dz)

	func _gl(i: int, a: float, b: float) -> float:
		var half: float = 0.5 * (b - a)
		var mid: float = 0.5 * (a + b)
		var total: float = 0.0
		for q in range(5):
			total += RegionalRoadMath.GL_W[q] * speed(i, mid + half * RegionalRoadMath.GL_X[q])
		return total * half

	## [span index, parameter t] at horizontal arc length s (clamped).
	func find(s: float) -> Array:
		var target: float = clampf(s, 0.0, total_length)
		var lo: int = 0
		var hi: int = span_start.size() - 1
		while lo < hi:
			var mid: int = (lo + hi + 1) / 2
			if span_start[mid] <= target:
				lo = mid
			else:
				hi = mid - 1
		var i: int = lo
		var local: float = target - span_start[i]
		var base: int = i * (RegionalRoadMath.ARC_SUBDIVISIONS + 1)
		var j: int = 0
		while j < RegionalRoadMath.ARC_SUBDIVISIONS - 1 and span_arc[base + j + 1] < local:
			j += 1
		var t0: float = float(j) / RegionalRoadMath.ARC_SUBDIVISIONS
		var t1: float = float(j + 1) / RegionalRoadMath.ARC_SUBDIVISIONS
		var a0: float = span_arc[base + j]
		var a1: float = span_arc[base + j + 1]
		var t: float = t0 + (t1 - t0) * ((local - a0) / maxf(a1 - a0, 1e-12))
		for _n in range(4):
			var err: float = a0 + _gl(i, t0, t) - local
			var v: float = speed(i, t)
			if v <= 1e-9:
				break
			t = clampf(t - err / v, t0, t1)
		return [i, t]

	## Position, unit tangent, signed curvature and curvature derivative d k/ds
	## at (span, t): [x, z, tx, tz, k, dk_ds, speed].
	func eval(i: int, t: float) -> PackedFloat64Array:
		var o: int = 6 * i
		var x: float = RegionalRoadMath.poly(cx, o, t)
		var z: float = RegionalRoadMath.poly(cz, o, t)
		var dx: float = RegionalRoadMath.poly_d1(cx, o, t)
		var dz: float = RegionalRoadMath.poly_d1(cz, o, t)
		var ddx: float = RegionalRoadMath.poly_d2(cx, o, t)
		var ddz: float = RegionalRoadMath.poly_d2(cz, o, t)
		var dddx: float = RegionalRoadMath.poly_d3(cx, o, t)
		var dddz: float = RegionalRoadMath.poly_d3(cz, o, t)
		var v2: float = dx * dx + dz * dz
		var v: float = sqrt(v2)
		if v <= 1e-12:
			return PackedFloat64Array([x, z, NAN, NAN, NAN, NAN, 0.0])
		var cross: float = dx * ddz - dz * ddx
		var k: float = cross / (v2 * v)
		# d/dt of cross/v^3 divided by v gives d k / d s.
		var dcross: float = dx * dddz - dz * dddx
		var dv: float = (dx * ddx + dz * ddz) / v
		var dk_dt: float = (dcross * v - 3.0 * cross * dv) / (v2 * v2)
		return PackedFloat64Array([x, z, dx / v, dz / v, k, dk_dt / v, v])

	func eval_s(s: float) -> PackedFloat64Array:
		var at: Array = find(s)
		return eval(at[0], at[1])


## 1D quintic Hermite elevation spline over horizontal arc length s.
class ProfileSpline extends RefCounted:
	var ks := PackedFloat64Array()
	var ky := PackedFloat64Array()
	var kg := PackedFloat64Array()
	var kc := PackedFloat64Array()
	var c := PackedFloat64Array()

	func build() -> void:
		c.resize(0)
		for i in range(ks.size() - 1):
			var h: float = ks[i + 1] - ks[i]
			c.append_array(RegionalRoadMath.quintic(ky[i], h * kg[i], h * h * kc[i], ky[i + 1], h * kg[i + 1], h * h * kc[i + 1]))

	func _find(s: float) -> int:
		var lo: int = 0
		var hi: int = ks.size() - 2
		while lo < hi:
			var mid: int = (lo + hi + 1) / 2
			if ks[mid] <= s:
				lo = mid
			else:
				hi = mid - 1
		return lo

	## [y, dy/ds, d2y/ds2] at s (clamped to the knot range).
	func eval(s: float) -> PackedFloat64Array:
		var target: float = clampf(s, ks[0], ks[ks.size() - 1])
		var i: int = _find(target)
		var h: float = ks[i + 1] - ks[i]
		var u: float = (target - ks[i]) / h
		var o: int = 6 * i
		return PackedFloat64Array([RegionalRoadMath.poly(c, o, u), RegionalRoadMath.poly_d1(c, o, u) / h, RegionalRoadMath.poly_d2(c, o, u) / (h * h)])


# --- Discrete smoothing helpers ---

## Gaussian smoothing with replicated ends (sigma in samples; 0 = copy).
static func gaussian(values: PackedFloat64Array, sigma: float) -> PackedFloat64Array:
	if sigma <= 0.0 or values.size() < 3:
		return values.duplicate()
	var radius: int = ceili(3.0 * sigma)
	var weights := PackedFloat64Array()
	var total: float = 0.0
	for k in range(-radius, radius + 1):
		var w: float = exp(-0.5 * (k * k) / (sigma * sigma))
		weights.append(w)
		total += w
	var n: int = values.size()
	var result := PackedFloat64Array()
	result.resize(n)
	for i in range(n):
		var acc: float = 0.0
		for k in range(-radius, radius + 1):
			acc += weights[k + radius] * values[clampi(i + k, 0, n - 1)]
		result[i] = acc / total
	return result


## Smallest / largest g-Lipschitz functions above / below the samples (uniform
## spacing ds): upper[i] = min_j (v_j + g |i-j| ds), lower = max_j (v_j - ...).
static func lipschitz_upper(values: PackedFloat64Array, g: float, ds: float) -> PackedFloat64Array:
	var n: int = values.size()
	var r: PackedFloat64Array = values.duplicate()
	for i in range(1, n):
		r[i] = minf(r[i], r[i - 1] + g * ds)
	for i in range(n - 2, -1, -1):
		r[i] = minf(r[i], r[i + 1] + g * ds)
	return r


static func lipschitz_lower(values: PackedFloat64Array, g: float, ds: float) -> PackedFloat64Array:
	var n: int = values.size()
	var r: PackedFloat64Array = values.duplicate()
	for i in range(1, n):
		r[i] = maxf(r[i], r[i - 1] - g * ds)
	for i in range(n - 2, -1, -1):
		r[i] = maxf(r[i], r[i + 1] - g * ds)
	return r


# --- Vertical profile reachability solver ---
#
# State per sample i: (y_i, p_i) with p_i = grade * ds (metres per sample).
# Dynamics over one sample: y' = y + p + q / 2, p' = p + q with the per-sample
# vertical curvature q = c * ds^2 limited to |q| <= cd. The set of states
# reachable from the start under the box constraints lo_i <= y_i <= hi_i and
# |p_i| <= gd is a convex polygon P_i; it is propagated forward exactly (shear,
# Minkowski sum with the segment of admissible q, clipping), so feasibility is
# decided exactly - an empty polygon names the first sample where the
# constraints cannot be met. A backward pass then selects a trajectory inside
# the stored polygons that tracks a target profile as closely as feasibility
# allows. Polygons are (xs, ps) pairs of PackedFloat64Array, counter-clockwise.

const POLY_EPS: float = 1e-9


static func _poly_clip(xs: PackedFloat64Array, ps: PackedFloat64Array, a: float, b: float, c: float) -> Array:
	var out_x := PackedFloat64Array()
	var out_p := PackedFloat64Array()
	var n: int = xs.size()
	for i in range(n):
		var j: int = (i + 1) % n
		var fp: float = a * xs[i] + b * ps[i] - c
		var fq: float = a * xs[j] + b * ps[j] - c
		if fp <= 0.0:
			out_x.append(xs[i])
			out_p.append(ps[i])
		if (fp < 0.0 and fq > 0.0) or (fp > 0.0 and fq < 0.0):
			var t: float = fp / (fp - fq)
			out_x.append(xs[i] + (xs[j] - xs[i]) * t)
			out_p.append(ps[i] + (ps[j] - ps[i]) * t)
	return [out_x, out_p]


## Drops repeated and collinear vertices.
static func _poly_clean(xs: PackedFloat64Array, ps: PackedFloat64Array) -> Array:
	var cur_x: PackedFloat64Array = xs
	var cur_p: PackedFloat64Array = ps
	for pass_index in range(2):
		var out_x := PackedFloat64Array()
		var out_p := PackedFloat64Array()
		var n: int = cur_x.size()
		for i in range(n):
			var prev: int = (i + n - 1) % n
			var next: int = (i + 1) % n
			var ax: float = cur_x[i] - cur_x[prev]
			var ap: float = cur_p[i] - cur_p[prev]
			var bx: float = cur_x[next] - cur_x[i]
			var bp: float = cur_p[next] - cur_p[i]
			if absf(ax) <= POLY_EPS and absf(ap) <= POLY_EPS:
				continue
			var cross: float = ax * bp - ap * bx
			if absf(cross) <= 1e-13 * (absf(ax) + absf(ap) + 1e-9) * (absf(bx) + absf(bp) + 1e-9) and ax * bx + ap * bp > 0.0:
				continue
			out_x.append(cur_x[i])
			out_p.append(cur_p[i])
		cur_x = out_x
		cur_p = out_p
		if cur_x.size() < 3:
			break
	return [cur_x, cur_p]


## Minkowski sum of a convex counter-clockwise polygon with the segment
## [-e, +e].
static func _poly_sum_segment(xs: PackedFloat64Array, ps: PackedFloat64Array, ex: float, ep: float) -> Array:
	var n: int = xs.size()
	var side := PackedByteArray()
	side.resize(n)
	for k in range(n):
		var m: int = (k + 1) % n
		var cross: float = ex * (ps[m] - ps[k]) - ep * (xs[m] - xs[k])
		side[k] = 1 if cross > 1e-15 else 0
	var k0: int = -1
	var j0: int = -1
	var transitions: int = 0
	for k in range(n):
		var before: int = side[(k + n - 1) % n]
		if before == 0 and side[k] == 1:
			k0 = k
			transitions += 1
		elif before == 1 and side[k] == 0:
			j0 = k
			transitions += 1
	var out_x := PackedFloat64Array()
	var out_p := PackedFloat64Array()
	if k0 < 0 or j0 < 0 or transitions != 2:
		# Degenerate or numerically ambiguous edge order: fall back to the hull of both
		# shifted copies, built by sorting.
		var pts: Array = []
		for k in range(n):
			pts.append([xs[k] - ex, ps[k] - ep])
			pts.append([xs[k] + ex, ps[k] + ep])
		pts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		var hull: Array = []
		for pass_index in range(2):
			var start: int = hull.size()
			var seq: Array = pts if pass_index == 0 else pts.duplicate()
			if pass_index == 1:
				seq.reverse()
			for pt: Array in seq:
				while hull.size() >= start + 2 and (hull[-1][0] - hull[-2][0]) * (pt[1] - hull[-2][1]) - (hull[-1][1] - hull[-2][1]) * (pt[0] - hull[-2][0]) <= 0.0:
					hull.pop_back()
				hull.append(pt)
			hull.pop_back()
		for pt: Array in hull:
			out_x.append(pt[0])
			out_p.append(pt[1])
		return [out_x, out_p]
	out_x.append(xs[k0] - ex)
	out_p.append(ps[k0] - ep)
	out_x.append(xs[k0] + ex)
	out_p.append(ps[k0] + ep)
	var k: int = (k0 + 1) % n
	while k != j0:
		out_x.append(xs[k] + ex)
		out_p.append(ps[k] + ep)
		k = (k + 1) % n
	out_x.append(xs[j0] + ex)
	out_p.append(ps[j0] + ep)
	out_x.append(xs[j0] - ex)
	out_p.append(ps[j0] - ep)
	k = (j0 + 1) % n
	while k != k0:
		out_x.append(xs[k] - ex)
		out_p.append(ps[k] - ep)
		k = (k + 1) % n
	return [out_x, out_p]


static func _poly_box(xs: PackedFloat64Array, ps: PackedFloat64Array, x_lo: float, x_hi: float, p_lo: float, p_hi: float) -> Array:
	var cur: Array = [xs, ps]
	cur = _poly_clip(cur[0], cur[1], 1.0, 0.0, x_hi)
	if cur[0].size() >= 3:
		cur = _poly_clip(cur[0], cur[1], -1.0, 0.0, -x_lo)
	if cur[0].size() >= 3:
		cur = _poly_clip(cur[0], cur[1], 0.0, 1.0, p_hi)
	if cur[0].size() >= 3:
		cur = _poly_clip(cur[0], cur[1], 0.0, -1.0, -p_lo)
	if cur[0].size() < 3:
		return [PackedFloat64Array(), PackedFloat64Array()]
	cur = _poly_clean(cur[0], cur[1])
	if cur[0].size() < 3:
		return [PackedFloat64Array(), PackedFloat64Array()]
	return cur


## Nearest point of a convex polygon to (tx, tp) (inside: the point itself).
static func _poly_nearest(xs: PackedFloat64Array, ps: PackedFloat64Array, tx: float, tp: float) -> PackedFloat64Array:
	var n: int = xs.size()
	var inside: bool = true
	for k in range(n):
		var m: int = (k + 1) % n
		if (xs[m] - xs[k]) * (tp - ps[k]) - (ps[m] - ps[k]) * (tx - xs[k]) < 0.0:
			inside = false
			break
	if inside:
		return PackedFloat64Array([tx, tp])
	var best := PackedFloat64Array([xs[0], ps[0]])
	var best_d: float = INF
	for k in range(n):
		var m: int = (k + 1) % n
		var dx: float = xs[m] - xs[k]
		var dp: float = ps[m] - ps[k]
		var len2: float = dx * dx + dp * dp
		var t: float = 0.0 if len2 <= 0.0 else clampf(((tx - xs[k]) * dx + (tp - ps[k]) * dp) / len2, 0.0, 1.0)
		var qx: float = xs[k] + dx * t
		var qp: float = ps[k] + dp * t
		var d: float = (qx - tx) * (qx - tx) + (qp - tp) * (qp - tp)
		if d < best_d:
			best_d = d
			best = PackedFloat64Array([qx, qp])
	return best


## Exact reachability solve of a sampled vertical profile.
##   lo, hi            per-sample height bounds (n + 1 samples; pinned: lo == hi)
##   grade_start/_end  [min, max] grade per sample (p) at the first / last
##                     sample (pinned grade: equal; free: +-gd)
##   gd, cd            grade limit p and curvature limit q per sample (metres)
##   target            desired heights (the tracking reference)
##   w_grade, w_jerk   tracking weight of the grade state / of curvature changes
## Returns {feasible, y, p, q, fail_index, fail_detail}; q has n entries (one
## per interval), p is grade * ds.
static func solve_profile(lo: PackedFloat64Array, hi: PackedFloat64Array, grade_start: Array, grade_end: Array, gd: float, cd: float,
		target: PackedFloat64Array, w_grade: float, w_jerk: float) -> Dictionary:
	var count: int = lo.size()
	var ref: float = 0.5 * (lo[0] + hi[0])
	var eps_y: float = 2e-5
	var eps_p: float = 2e-6
	var polys_x: Array = []
	var polys_p: Array = []
	var p_lo: float = maxf(-gd, grade_start[0] - eps_p)
	var p_hi: float = minf(gd, grade_start[1] + eps_p)
	var cur: Array = _poly_box(PackedFloat64Array([lo[0] - ref - eps_y, hi[0] - ref + eps_y, hi[0] - ref + eps_y, lo[0] - ref - eps_y]),
		PackedFloat64Array([p_lo, p_lo, p_hi, p_hi]), lo[0] - ref - eps_y, hi[0] - ref + eps_y, p_lo, p_hi)
	if cur[0].is_empty():
		return {"feasible": false, "fail_index": 0, "fail_detail": {"note": "start state outside its bounds"}}
	polys_x.append(cur[0])
	polys_p.append(cur[1])
	for i in range(1, count):
		var xs: PackedFloat64Array = polys_x[i - 1].duplicate()
		var ps: PackedFloat64Array = polys_p[i - 1]
		for k in range(xs.size()):
			xs[k] += ps[k]
		var sum: Array = _poly_sum_segment(xs, ps, 0.5 * cd, cd)
		var pl: float = -gd
		var ph: float = gd
		if i == count - 1:
			pl = maxf(-gd, grade_end[0] - eps_p)
			ph = minf(gd, grade_end[1] + eps_p)
		cur = _poly_box(sum[0], sum[1], lo[i] - ref - eps_y, hi[i] - ref + eps_y, pl, ph)
		if cur[0].is_empty():
			var prev_x: PackedFloat64Array = polys_x[i - 1]
			var prev_p: PackedFloat64Array = polys_p[i - 1]
			var reach_lo: float = INF
			var reach_hi: float = -INF
			for k in range(prev_x.size()):
				reach_lo = minf(reach_lo, prev_x[k] + prev_p[k] - cd * 0.5)
				reach_hi = maxf(reach_hi, prev_x[k] + prev_p[k] + cd * 0.5)
			return {"feasible": false, "fail_index": i, "fail_detail": {"reach_low_m": reach_lo + ref, "reach_high_m": reach_hi + ref, "bound_low_m": lo[i], "bound_high_m": hi[i]}}
		polys_x.append(cur[0])
		polys_p.append(cur[1])
	# Backward selection tracking the target.
	var y := PackedFloat64Array()
	var p := PackedFloat64Array()
	var q := PackedFloat64Array()
	y.resize(count)
	p.resize(count)
	q.resize(count - 1)
	var t_last: float = target[count - 1] - ref
	var t_grade_last: float = (target[count - 1] - target[maxi(count - 2, 0)])
	var end_state: PackedFloat64Array = _poly_nearest(polys_x[count - 1], polys_p[count - 1], t_last, t_grade_last)
	y[count - 1] = end_state[0]
	p[count - 1] = end_state[1]
	var q_next: float = 0.0
	var tol: float = 1e-9
	for i in range(count - 2, -1, -1):
		var px: PackedFloat64Array = polys_x[i]
		var pp: PackedFloat64Array = polys_p[i]
		# Predecessors of (y', p'): (y' - p' + q/2, p' - q), q in [-cd, cd].
		var base_x: float = y[i + 1] - p[i + 1]
		var base_p: float = p[i + 1]
		var q_lo: float = -cd
		var q_hi: float = cd
		var m: int = px.size()
		for k in range(m):
			var kk: int = (k + 1) % m
			var ex: float = px[kk] - px[k]
			var ep: float = pp[kk] - pp[k]
			# cross(edge, point - v_k) >= -tol, point = base + q (0.5, -1)
			var c0: float = ex * (base_p - pp[k]) - ep * (base_x - px[k])
			var c1: float = ex * (-1.0) - ep * 0.5
			if absf(c1) <= 1e-14:
				continue
			var bound: float = (-tol - c0) / c1
			if c1 > 0.0:
				q_lo = maxf(q_lo, bound)
			else:
				q_hi = minf(q_hi, bound)
		var t_y: float = target[i] - ref
		var t_g: float = (target[mini(i + 1, count - 1)] - target[maxi(i - 1, 0)]) * 0.5
		var a_err: float = base_x - t_y
		var b_err: float = base_p - t_g
		var q_star: float = (2.0 * w_grade * b_err - a_err + 2.0 * w_jerk * q_next) / (0.5 + 2.0 * w_grade + 2.0 * w_jerk)
		var q_pick: float = clampf(q_star, q_lo, q_hi) if q_lo <= q_hi else 0.5 * (q_lo + q_hi)
		q[i] = q_pick
		y[i] = base_x + 0.5 * q_pick
		p[i] = base_p - q_pick
		q_next = q_pick
	for i in range(count):
		y[i] += ref
	return {"feasible": true, "y": y, "p": p, "q": q}


## Discrete fairing: minimise sum w_i (x_i - p_i)^2 + sum lam_k (x_{k-1} - 2 x_k
## + x_{k+1})^2 for one coordinate (SPD pentadiagonal; banded Cholesky). Large
## weights pin points; lam is one value per point (row k uses lam[k]).
static func fair(p: PackedFloat64Array, w: PackedFloat64Array, lam_rows: PackedFloat64Array) -> PackedFloat64Array:
	var n: int = p.size()
	if n < 3:
		return p.duplicate()
	# Band storage: d0 main, d1 first super, d2 second super diagonal.
	var d0 := PackedFloat64Array()
	var d1 := PackedFloat64Array()
	var d2 := PackedFloat64Array()
	d0.resize(n)
	d1.resize(n)
	d2.resize(n)
	var rhs := PackedFloat64Array()
	rhs.resize(n)
	for i in range(n):
		d0[i] = w[i]
		rhs[i] = w[i] * p[i]
	for k in range(1, n - 1):
		# Row of D: [1, -2, 1] at k-1, k, k+1; add lam * D^T D.
		var idx := [k - 1, k, k + 1]
		var coef := [1.0, -2.0, 1.0]
		for a in range(3):
			for b in range(a, 3):
				var i: int = idx[a]
				var j: int = idx[b]
				var v: float = lam_rows[k] * coef[a] * coef[b]
				if j == i:
					d0[i] += v
				elif j == i + 1:
					d1[i] += v
				else:
					d2[i] += v
	# Banded Cholesky L D L^T (bandwidth 2).
	var l1 := PackedFloat64Array()
	var l2 := PackedFloat64Array()
	var dd := PackedFloat64Array()
	l1.resize(n)
	l2.resize(n)
	dd.resize(n)
	for i in range(n):
		var v: float = d0[i]
		if i >= 1:
			v -= l1[i - 1] * l1[i - 1] * dd[i - 1]
		if i >= 2:
			v -= l2[i - 2] * l2[i - 2] * dd[i - 2]
		dd[i] = v
		if i + 1 < n:
			var u1: float = d1[i]
			if i >= 1:
				u1 -= l1[i - 1] * l2[i - 1] * dd[i - 1]
			l1[i] = u1 / v
		if i + 2 < n:
			l2[i] = d2[i] / v
	var y: PackedFloat64Array = rhs.duplicate()
	for i in range(n):
		if i >= 1:
			y[i] -= l1[i - 1] * y[i - 1]
		if i >= 2:
			y[i] -= l2[i - 2] * y[i - 2]
	for i in range(n):
		y[i] /= dd[i]
	for i in range(n - 1, -1, -1):
		if i + 1 < n:
			y[i] -= l1[i] * y[i + 1]
		if i + 2 < n:
			y[i] -= l2[i] * y[i + 2]
	return y


## Signed curvature of the circle through three points (> 0 towards the left
## normal (-dz, dx) of the travel direction); 0 when degenerate.
static func three_point_curvature(ax: float, az: float, bx: float, bz: float, cx_: float, cz_: float) -> float:
	var abx: float = bx - ax
	var abz: float = bz - az
	var bcx: float = cx_ - bx
	var bcz: float = cz_ - bz
	var acx: float = cx_ - ax
	var acz: float = cz_ - az
	var denominator: float = sqrt((abx * abx + abz * abz) * (bcx * bcx + bcz * bcz) * (acx * acx + acz * acz))
	if denominator <= 1e-12:
		return 0.0
	return 2.0 * (abx * bcz - abz * bcx) / denominator


static func wrap_angle(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


## Signed turn lobes of a sampled curvature signal: maximal runs where
## |k| >= k_on with one sign, merged across same-sign gaps shorter than
## merge_gap_m. Each lobe: {s0, s1, turn (rad, signed integral of k ds)}.
static func turn_lobes(s: PackedFloat64Array, k: PackedFloat64Array, k_on: float, merge_gap_m: float) -> Array:
	var n: int = s.size()
	var runs: Array = []
	var i: int = 0
	while i < n:
		var sign: float = signf(k[i]) if absf(k[i]) >= k_on else 0.0
		if sign == 0.0:
			i += 1
			continue
		var j: int = i
		while j + 1 < n and absf(k[j + 1]) >= k_on and signf(k[j + 1]) == sign:
			j += 1
		runs.append([i, j, sign])
		i = j + 1
	var merged: Array = []
	for run: Array in runs:
		if not merged.is_empty() and merged[-1][2] == run[2] and s[run[0]] - s[merged[-1][1]] < merge_gap_m:
			merged[-1][1] = run[1]
		else:
			merged.append(run.duplicate())
	var lobes: Array = []
	for run: Array in merged:
		var a: int = maxi(run[0] - 1, 0)
		var b: int = mini(run[1] + 1, n - 1)
		var turn: float = 0.0
		for m in range(a, b):
			turn += 0.5 * (k[m] + k[m + 1]) * (s[m + 1] - s[m])
		lobes.append({"s0": s[run[0]], "s1": s[run[1]], "turn": turn})
	return lobes
