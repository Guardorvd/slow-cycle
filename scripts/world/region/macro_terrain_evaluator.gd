class_name MacroTerrainEvaluator
extends RefCounted

## Stateless elevation math over a MacroTerrainPlan: the private height
## kernel of TerrainField (R2), which owns the public world-space terrain
## queries. New consumers use TerrainField, not this script. Never generates
## or caches into the plan. Sampling support is the closed square [0, 4096]^2.
##
## structure = valley floor
##           + smooth-max(valley rise [walls, benches, uplands],
##                        masked ridge networks [main crest + spurs, far ridge
##                        + spurs]: smooth-max of concave flank profiles around
##                        smoothed crest lines in a bounded domain-warped frame)
##           -> upland basin flattening
## Ridge heights are measured above the valley floor, so crest ordering
## (summits above passes) is not disturbed by the valley-side rise.
## final     = structure + bounded noise (|final - structure| <= amplitude)

const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SMOOTH_MAX_M: float = 35.0
const CREST_SUBDIVISION: int = 3
const SPUR_SUBDIVISION: int = 2
const CELL_M: float = 256.0
const CELLS: int = 18 # covers [-256, 4352) in the warped frame


## Derived read-only sampling data, rebuilt from the plan for every call
## (point API) or once per grid. Never stored in the plan.
class Context:
	extends RefCounted
	var symmetry: int
	var structure_seed: int
	var noise_seed: int
	var axis := PackedFloat64Array()
	var half := PackedFloat64Array()
	var near_wall := PackedFloat64Array()
	var far_wall := PackedFloat64Array()
	var floor_cm: float
	var drop_cm: float
	var basin_u: float
	var basin_extra: float
	var basin_half_length: float
	var wall_w := PackedFloat64Array([0, 0]) # [far, near]
	var wall_h := PackedFloat64Array([0, 0])
	var upland := PackedFloat64Array([0, 0])
	var benches: Array = [] # [side, u_a, u_b, fraction, width]
	var basins: Array = [] # [u, v, radius, depth, level, cos, sin, elongation]
	var crest_exponent: float
	var spur_exponent: float
	var rounding: float
	var rib_strength: float
	var rib_wavelength: float
	var warp_amplitude: float
	var warp_wavelength: float
	# Per segment: au, av, bu, bv, ha, hb, near_a, near_b, far_a, far_b,
	# exponent, group, then AABB min_u, min_v, max_u, max_v (stride 16).
	var segments := PackedFloat64Array()
	var cells: Array = [] # optional bucket grid: Array[PackedInt32Array]
	var noise_amplitude: float
	var noise_wavelengths := PackedFloat64Array()
	var noise_weights := PackedFloat64Array()
	var ridged: float
	var attenuation := PackedFloat64Array() # valley floor, bench, basin
	var max_summit: float


const STRIDE: int = 16


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## C1 ramp: 0 below -b, x above b, quadratic in between.
static func _soft_ramp(x: float, b: float) -> float:
	if x <= -b:
		return 0.0
	if x >= b:
		return x
	return (x + b) * (x + b) / (4.0 * b)


## Smooth maximum whose blend radius shrinks to zero with either operand, so a
## contribution fading to zero joins continuously.
static func _smooth_max(a: float, b: float) -> float:
	var k: float = minf(SMOOTH_MAX_M, minf(a, b))
	if k <= 0.0:
		return maxf(a, b)
	var h: float = clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)


## 31-bit lane integer hash; every product stays below 2^63 and all 63 seed
## bits enter through three lanes.
static func _hash(seed_value: int, ix: int, iz: int, salt: int) -> float:
	var h: int = (seed_value & 0x7fffffff) ^ (((seed_value >> 31) & 0x7fffffff) * 0x45d9f3b & 0x7fffffff) ^ (((seed_value >> 62) & 1) * 0x5bd1e995)
	h ^= ((ix & 0x7fffffff) * 0x27d4eb2d) & 0x7fffffff
	h = ((h ^ (h >> 15)) * 0x2c1b3c6d) & 0x7fffffff
	h ^= ((iz & 0x7fffffff) * 0x165667b1) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 0x297a2d39) & 0x7fffffff
	h ^= (salt * 0x3c6ef372) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x45d9f3b) & 0x7fffffff
	h ^= h >> 15
	return h / 2147483647.0 * 2.0 - 1.0


## Quintic value noise in [-1, 1].
static func _value_noise(seed_value: int, x: float, z: float, wavelength: float, salt: int) -> float:
	var sx: float = x / wavelength
	var sz: float = z / wavelength
	var ix: int = floori(sx)
	var iz: int = floori(sz)
	var tx: float = sx - ix
	var tz: float = sz - iz
	tx = tx * tx * tx * (tx * (tx * 6.0 - 15.0) + 10.0)
	tz = tz * tz * tz * (tz * (tz * 6.0 - 15.0) + 10.0)
	var a: float = lerpf(_hash(seed_value, ix, iz, salt), _hash(seed_value, ix + 1, iz, salt), tx)
	var b: float = lerpf(_hash(seed_value, ix, iz + 1, salt), _hash(seed_value, ix + 1, iz + 1, salt), tx)
	return lerpf(a, b, tz)


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2: float = t * t
	return 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t)


## Smooth a ridge polyline (Catmull-Rom through its nodes) into straight
## sub-segments. Rows: [u, v, height_m, near_w, far_w].
static func _append_line(context: Context, rows: Array, subdivision: int, exponent: float, group: int) -> void:
	if rows.size() < 2:
		return
	var points: Array = []
	for i in range(rows.size() - 1):
		var p0 := Vector2(rows[maxi(i - 1, 0)][0], rows[maxi(i - 1, 0)][1])
		var p1 := Vector2(rows[i][0], rows[i][1])
		var p2 := Vector2(rows[i + 1][0], rows[i + 1][1])
		var p3 := Vector2(rows[mini(i + 2, rows.size() - 1)][0], rows[mini(i + 2, rows.size() - 1)][1])
		for k in range(subdivision):
			var t: float = float(k) / subdivision
			var p: Vector2 = _catmull(p0, p1, p2, p3, t)
			points.append([p.x, p.y, Macro.ease_height(rows[i][2], rows[i + 1][2], t), lerpf(rows[i][3], rows[i + 1][3], t), lerpf(rows[i][4], rows[i + 1][4], t)])
	points.append(rows[-1])
	for i in range(points.size() - 1):
		var a: Array = points[i]
		var b: Array = points[i + 1]
		var reach: float = maxf(maxf(a[3], b[3]), maxf(a[4], b[4]))
		context.segments.append_array([a[0], a[1], b[0], b[1], a[2], b[2], a[3], b[3], a[4], b[4], exponent, group,
			minf(a[0], b[0]) - reach, minf(a[1], b[1]) - reach, maxf(a[0], b[0]) + reach, maxf(a[1], b[1]) + reach])


static func _context(plan: Macro, with_cells: bool) -> Context:
	var data: Dictionary = plan.get_data()
	var c := Context.new()
	c.symmetry = data.frame_symmetry
	c.structure_seed = data.structure_seed
	c.noise_seed = data.noise_seed
	for point: Dictionary in data.valley_points:
		c.axis.append(point.v_m)
		c.half.append(point.floor_half_width_m)
		c.near_wall.append(point.near_wall_permille / 1000.0)
		c.far_wall.append(point.far_wall_permille / 1000.0)
	c.floor_cm = data.base.floor_elevation_cm
	c.drop_cm = data.base.floor_drop_cm
	var valley: Dictionary = data.valley
	c.basin_u = valley.basin_u_m
	c.basin_extra = valley.basin_extra_m
	c.basin_half_length = valley.basin_half_length_m
	c.wall_w = PackedFloat64Array([valley.far_wall_width_m, valley.near_wall_width_m])
	c.wall_h = PackedFloat64Array([valley.far_wall_height_cm / 100.0, valley.near_wall_height_cm / 100.0])
	c.upland = PackedFloat64Array([valley.far_upland_permille / 1000.0, valley.near_upland_permille / 1000.0])
	for bench: Dictionary in data.benches:
		c.benches.append(PackedFloat64Array([bench.side, bench.u_a_m, bench.u_b_m, bench.height_permille / 1000.0, bench.width_m]))
	c.crest_exponent = data.ridge.profile_permille / 1000.0
	c.spur_exponent = data.ridge.spur_profile_permille / 1000.0
	c.rounding = data.ridge.crest_rounding_m
	c.rib_strength = data.ridge.rib_permille / 1000.0
	c.rib_wavelength = data.ridge.rib_wavelength_m
	c.warp_amplitude = data.ridge.warp_amplitude_m
	c.warp_wavelength = data.ridge.warp_wavelength_m
	c.max_summit = 1.0
	for group: Array in [[data.main_nodes, Macro.GROUP_MAIN], [data.far_nodes, Macro.GROUP_FAR]]:
		var rows: Array = []
		for node: Dictionary in group[0]:
			rows.append([float(node.u_m), float(node.v_m), node.height_cm / 100.0, float(node.near_width_m), float(node.far_width_m)])
			if group[1] == Macro.GROUP_MAIN:
				c.max_summit = maxf(c.max_summit, node.height_cm / 100.0)
		_append_line(c, rows, CREST_SUBDIVISION, c.crest_exponent, group[1])
	for spur: Dictionary in data.spurs:
		var w: float = spur.width_m
		_append_line(c, [[float(spur.au_m), float(spur.av_m), spur.start_cm / 100.0, w, w], [float(spur.mu_m), float(spur.mv_m), spur.middle_cm / 100.0, w, w], [float(spur.bu_m), float(spur.bv_m), spur.end_cm / 100.0, w, w]], SPUR_SUBDIVISION, c.spur_exponent, spur.group)
	var noise: Dictionary = data.noise
	c.noise_amplitude = noise.amplitude_cm / 100.0
	c.noise_wavelengths = PackedFloat64Array(noise.wavelengths_m)
	for weight: int in noise.weights_permille:
		c.noise_weights.append(weight / 1000.0)
	c.ridged = noise.ridged_permille / 1000.0
	c.attenuation = PackedFloat64Array([noise.valley_floor_permille / 1000.0, noise.bench_permille / 1000.0, noise.basin_permille / 1000.0])
	for basin: Dictionary in data.basins:
		var angle: float = deg_to_rad(basin.orientation_deg)
		var level: float = _floor(c, basin.u_m) + _base(c, basin.u_m, basin.v_m).x - basin.depth_cm / 100.0
		c.basins.append(PackedFloat64Array([basin.u_m, basin.v_m, basin.radius_m, basin.depth_cm / 100.0, level, cos(angle), sin(angle), basin.elongation_permille / 1000.0]))
	if with_cells:
		for cell in range(CELLS * CELLS):
			c.cells.append(PackedInt32Array())
		for s in range(0, c.segments.size(), STRIDE):
			var i0: int = clampi(floori(c.segments[s + 12] / CELL_M) + 1, 0, CELLS - 1)
			var j0: int = clampi(floori(c.segments[s + 13] / CELL_M) + 1, 0, CELLS - 1)
			var i1: int = clampi(floori(c.segments[s + 14] / CELL_M) + 1, 0, CELLS - 1)
			var j1: int = clampi(floori(c.segments[s + 15] / CELL_M) + 1, 0, CELLS - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					c.cells[j * CELLS + i].append(s)
	return c


static func _spline(values: PackedFloat64Array, u: float) -> Vector2:
	return Macro.spline(values, u)


## Local valley-wall (width, height) on one side; both vary along the valley.
static func _wall(c: Context, u: float, near: bool) -> Vector2:
	var k: int = 1 if near else 0
	var scale: float = _spline(c.near_wall if near else c.far_wall, u).x
	return Vector2(c.wall_w[k] * (1.0 + scale) * 0.5, c.wall_h[k] * scale)


static func _floor(c: Context, u: float) -> float:
	return (c.floor_cm + c.drop_cm * (1.0 - clampf(u / 4096.0, 0.0, 1.0))) / 100.0


## Valley rise above the floor: Vector3(rise m, excess past the floor edge on
## the point's side [m], side +1 mountain / -1 far).
static func _base(c: Context, u: float, v: float) -> Vector3:
	var axis: Vector2 = _spline(c.axis, u)
	var half: float = _spline(c.half, u).x
	var x: float = (u - c.basin_u) / c.basin_half_length
	var widening: float = c.basin_extra * pow(maxf(0.0, 1.0 - x * x), 3)
	var d: float = (v - axis.x) / sqrt(1.0 + axis.y * axis.y)
	var near: bool = d >= 0.0
	var excess: float = (d - half) if near else (-d - half - widening)
	var wall: Vector2 = _wall(c, u, near)
	var wall_w: float = wall.x
	var wall_h: float = wall.y
	var upland: float = c.upland[1 if near else 0]
	var rise: float = wall_h * _smooth(excess / wall_w) + upland * _soft_ramp(excess - wall_w, 120.0)
	for bench: PackedFloat64Array in c.benches:
		if (bench[0] > 0.0) != near:
			continue
		var weight: float = _smooth((u - bench[1]) / 250.0) * _smooth((bench[2] - u) / 250.0)
		if weight <= 0.0:
			continue
		var e1: float = 0.4 * wall_w
		var e2: float = e1 + bench[4]
		var benched: float = bench[3] * wall_h * _smooth(excess / e1) + 0.02 * clampf(excess - e1, 0.0, bench[4]) \
			+ (1.0 - bench[3]) * wall_h * _smooth((excess - e2) / (wall_w - e1)) + upland * _soft_ramp(excess - wall_w - bench[4], 120.0)
		rise = lerpf(rise, benched, weight)
	return Vector3(rise, excess, 1.0 if near else -1.0)


## Ridge field of one group at warped frame point (u, v). `rib` in [-1, 1]
## modulates every flank by up to rib_strength, vanishing at the crest and at
## the flank foot, so crest heights and continuity are unchanged.
static func _ridges(c: Context, group: int, u: float, v: float, rib: float) -> float:
	var list: PackedInt32Array
	var brute: bool = c.cells.is_empty()
	if not brute:
		var i: int = clampi(floori(u / CELL_M) + 1, 0, CELLS - 1)
		var j: int = clampi(floori(v / CELL_M) + 1, 0, CELLS - 1)
		list = c.cells[j * CELLS + i]
	var count: int = c.segments.size() / STRIDE if brute else list.size()
	var result: float = -1.0
	var seg: PackedFloat64Array = c.segments
	for n in range(count):
		var s: int = n * STRIDE if brute else list[n]
		if int(seg[s + 11]) != group or u < seg[s + 12] or v < seg[s + 13] or u > seg[s + 14] or v > seg[s + 15]:
			continue
		var au: float = seg[s]
		var av: float = seg[s + 1]
		var du: float = seg[s + 2] - au
		var dv: float = seg[s + 3] - av
		var length_squared: float = du * du + dv * dv
		var t: float = 0.0 if length_squared <= 0.0 else clampf(((u - au) * du + (v - av) * dv) / length_squared, 0.0, 1.0)
		var pu: float = u - (au + t * du)
		var pv: float = v - (av + t * dv)
		var distance: float = sqrt(pu * pu + pv * pv)
		var near: float = lerpf(seg[s + 6], seg[s + 7], t)
		var far: float = lerpf(seg[s + 8], seg[s + 9], t)
		if distance >= maxf(near, far):
			continue
		# Valley-facing flank uses the near width; blend by direction so the
		# field stays continuous around segment end caps.
		var toward_valley: float = (-pv if group == Macro.GROUP_MAIN else pv) / maxf(distance, 1e-6)
		var width: float = lerpf(far, near, _smooth(0.5 + toward_valley / 0.6))
		if distance >= width:
			continue
		# Rounded crest: hyperbolic soft distance, still exactly 0 at width.
		var soft: float = (sqrt(distance * distance + c.rounding * c.rounding) - c.rounding) / (sqrt(width * width + c.rounding * c.rounding) - c.rounding)
		var value: float = lerpf(seg[s + 4], seg[s + 5], t) * pow(1.0 - soft, seg[s + 10]) * (1.0 + c.rib_strength * rib * 4.0 * soft * (1.0 - soft))
		result = value if result < 0.0 else _smooth_max(result, value)
	return maxf(result, 0.0)


static func _sample(c: Context, x: float, z: float, include_noise: bool) -> float:
	var frame: Vector2 = Macro.local_to_frame(c.symmetry, x, z)
	var u: float = frame.x
	var v: float = frame.y
	var base: Vector3 = _base(c, u, v)
	var excess: float = base.y
	var near: bool = base.z > 0.0
	var wall_w: float = _wall(c, u, near).x
	var bench_shift: float = 0.0
	for bench: PackedFloat64Array in c.benches:
		if (bench[0] > 0.0) == near:
			bench_shift = maxf(bench_shift, bench[4] * _smooth((u - bench[1]) / 250.0) * _smooth((bench[2] - u) / 250.0))
	var mask: float = _smooth((excess - bench_shift - 0.25 * wall_w) / (0.85 * wall_w))
	var wu: float = u
	var wv: float = v
	if c.warp_amplitude > 0.0:
		wu += c.warp_amplitude * (0.7 * _value_noise(c.structure_seed, u, v, c.warp_wavelength, 1) + 0.3 * _value_noise(c.structure_seed, u, v, c.warp_wavelength * 0.5, 2))
		wv += c.warp_amplitude * (0.7 * _value_noise(c.structure_seed, u, v, c.warp_wavelength, 3) + 0.3 * _value_noise(c.structure_seed, u, v, c.warp_wavelength * 0.5, 4))
	var mountain: float = 0.0
	if mask > 0.0:
		var rib: float = 1.0 - 2.0 * absf(_value_noise(c.structure_seed, wu, wv, c.rib_wavelength, 5))
		mountain = mask * _ridges(c, Macro.GROUP_MAIN if near else Macro.GROUP_FAR, wu, wv, rib)
	var elevation: float = _floor(c, u) + _smooth_max(base.x, mountain)
	var basin_weight: float = 0.0
	for basin: PackedFloat64Array in c.basins:
		# Elongated, warp-irregular rim around a flat-floored upland basin.
		var du: float = wu - basin[0]
		var dv: float = wv - basin[1]
		var along: float = (du * basin[5] + dv * basin[6]) / basin[7]
		var across: float = -du * basin[6] + dv * basin[5]
		var r: float = sqrt(along * along + across * across) / basin[2]
		if r < 1.0:
			var weight: float = 1.0 - _smooth((r - 0.45) / 0.55)
			elevation = lerpf(elevation, basin[4] + 0.3 * basin[3] * r * r, weight)
			basin_weight = maxf(basin_weight, weight)
	if not include_noise:
		return elevation
	var fbm: float = 0.0
	for octave in range(c.noise_weights.size()):
		fbm += c.noise_weights[octave] * _value_noise(c.noise_seed, u, v, c.noise_wavelengths[octave], 10 + octave)
	var ridged: float = 1.0 - 2.0 * absf(_value_noise(c.noise_seed, u, v, 420.0, 20))
	var share: float = c.ridged * clampf(mountain / c.max_summit, 0.0, 1.0)
	var mixed: float = (1.0 - share) * fbm + share * ridged
	var attenuation: float = lerpf(c.attenuation[0], 1.0, _smooth(excess / (0.6 * wall_w)))
	var bench_mask: float = 0.0
	for bench: PackedFloat64Array in c.benches:
		if (bench[0] > 0.0) == near:
			var e1: float = 0.4 * wall_w
			var across_bench: float = _smooth((excess - e1 + 40.0) / 80.0) * _smooth((e1 + bench[4] + 40.0 - excess) / 80.0)
			bench_mask = maxf(bench_mask, across_bench * _smooth((u - bench[1]) / 250.0) * _smooth((bench[2] - u) / 250.0))
	attenuation = minf(attenuation, lerpf(1.0, c.attenuation[1], bench_mask))
	attenuation = minf(attenuation, lerpf(1.0, c.attenuation[2], basin_weight))
	return elevation + c.noise_amplitude * attenuation * mixed


static func _check(plan: Macro, x: float, z: float) -> String:
	if plan == null or plan.get_state() != Macro.STATE_GENERATED_R1:
		return "ERR_EVAL_PLAN_MISSING"
	if not is_finite(x) or not is_finite(z):
		return "ERR_EVAL_NONFINITE_INPUT"
	if x < 0.0 or z < 0.0 or x > 4096.0 or z > 4096.0:
		return "ERR_EVAL_OUT_OF_DOMAIN"
	return ""


static func _evaluate(plan: Macro, x: float, z: float, include_noise: bool) -> Dictionary:
	var reason: String = _check(plan, x, z)
	if not reason.is_empty():
		return {"is_valid": false, "elevation_m": NAN, "reason_code": reason}
	return {"is_valid": true, "elevation_m": _sample(_context(plan, false), x, z, include_noise), "reason_code": ""}


static func evaluate_structure_elevation_m(plan: Macro, local_x_m: float, local_z_m: float) -> Dictionary:
	return _evaluate(plan, local_x_m, local_z_m, false)


static func evaluate_elevation_m(plan: Macro, local_x_m: float, local_z_m: float) -> Dictionary:
	return _evaluate(plan, local_x_m, local_z_m, true)


## Row-major grid (z outer, x inner) of elevations at origin + (i, j) * step,
## bit-identical to the point API at the same coordinates (same segments in
## the same order; buckets only skip segments that cannot contribute).
static func sample_grid(plan: Macro, origin_x_m: float, origin_z_m: float, step_m: float, count_x: int, count_z: int, include_noise: bool) -> Dictionary:
	if count_x <= 0 or count_z <= 0 or not is_finite(step_m) or step_m <= 0.0:
		return {"is_valid": false, "elevations_m": PackedFloat64Array(), "reason_code": "ERR_EVAL_GRID_SHAPE"}
	for corner: Vector2 in [Vector2(origin_x_m, origin_z_m), Vector2(origin_x_m + step_m * (count_x - 1), origin_z_m + step_m * (count_z - 1))]:
		var reason: String = _check(plan, corner.x, corner.y)
		if not reason.is_empty():
			return {"is_valid": false, "elevations_m": PackedFloat64Array(), "reason_code": reason}
	var context: Context = prepare(plan)
	var result := PackedFloat64Array()
	result.resize(count_x * count_z)
	for j in range(count_z):
		for i in range(count_x):
			result[j * count_x + i] = _sample(context, origin_x_m + i * step_m, origin_z_m + j * step_m, include_noise)
	return {"is_valid": true, "elevations_m": result, "reason_code": ""}


## Bucketed sampling context for repeated queries over one plan (owned by the
## caller, read-only afterwards); null for a missing or non-generated plan.
static func prepare(plan: Macro) -> Context:
	if plan == null or plan.get_state() != Macro.STATE_GENERATED_R1:
		return null
	return _context(plan, true)


## Elevation from a prepared context, bit-identical to the point API. The
## caller guarantees finite region-local coordinates inside [0, 4096]^2.
static func sample_prepared(context: Context, local_x_m: float, local_z_m: float, include_noise: bool) -> float:
	return _sample(context, local_x_m, local_z_m, include_noise)
