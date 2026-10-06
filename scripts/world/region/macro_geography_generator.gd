class_name MacroGeographyGenerator
extends RefCounted

## Builds the R1 MOUNTAIN_RIVER_VALLEY descriptor for one region.
##
## Construction (canonical frame, +v = mountain side):
##   0. composition: valley form, range form, crest shape and far-side form
##      are drawn first, so regions differ in layout, not only in jitter;
##   1. major valley: a C1 axis through 9 points, varying floor width, one
##      floodplain basin opening to the far side, varying valley walls;
##   2. main mountain crest: a polyline of END, SUMMIT, (SADDLE, SUMMIT)*, END
##      nodes - summits, passes and shoulders of one connected range;
##   3. spurs branching off the crest towards the valley;
##   4. the far side: a lower ridge, a double-humped hill ridge, or open upland;
##   5. valley-wall benches and an optional far-side upland basin;
##   6. bounded noise budget, then one exact frame symmetry.
## Every value is drawn from a fixed or already-derived feasible integer
## interval of one local RNG seeded by the macro_structure seed.

const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SIZE: int = 4096


static func _axis_v(points: Array, u: float) -> float:
	var values: Array = []
	for point: Dictionary in points:
		values.append(point.v_m)
	return Macro.spline(values, u).x


static func _half_width(points: Array, u: float) -> float:
	var values: Array = []
	for point: Dictionary in points:
		values.append(point.floor_half_width_m)
	return Macro.spline(values, u).x


## Crest polyline sample at arc fraction: [point, height_cm].
static func _crest_at(nodes: Array, fraction: float) -> Array:
	var lengths: Array[float] = []
	var total: float = 0.0
	for i in range(nodes.size() - 1):
		lengths.append(Vector2(nodes[i].u_m, nodes[i].v_m).distance_to(Vector2(nodes[i + 1].u_m, nodes[i + 1].v_m)))
		total += lengths[-1]
	var walked: float = fraction * total
	for i in range(lengths.size()):
		if walked <= lengths[i] or i == lengths.size() - 1:
			var t: float = clampf(walked / lengths[i], 0.0, 1.0)
			var a := Vector2(nodes[i].u_m, nodes[i].v_m)
			var b := Vector2(nodes[i + 1].u_m, nodes[i + 1].v_m)
			return [a.lerp(b, t), Macro.ease_height(nodes[i].height_cm, nodes[i + 1].height_cm, t)]
		walked -= lengths[i]
	return []


## Point on the crest segment from node j towards its neighbour j + step, at
## fraction t: [point, height_cm].
static func _crest_near(nodes: Array, j: int, step: int, t: float) -> Array:
	var a: Dictionary = nodes[j]
	var b: Dictionary = nodes[j + step]
	var point: Vector2 = Vector2(a.u_m, a.v_m).lerp(Vector2(b.u_m, b.v_m), t)
	return [point, Macro.ease_height(a.height_cm, b.height_cm, t)]


## Crest nodes END, SUMMIT, (SADDLE, SUMMIT)*, END spread over [u_first,
## u_last]; a positive tail moves the final END beyond u_last so the crest
## descends gradually instead of ending in a cone.
static func _ridge_nodes(rng: RandomNumberGenerator, u_first: int, u_last: int, tail: int, summit_count: int, offsets: Callable, summit_range: Vector2i, end_scale: Array) -> Array:
	var count: int = 2 * summit_count + 1
	var spacing: float = float(u_last - u_first) / (count - (2 if tail > 0 else 1))
	var nodes: Array = []
	for j in range(count):
		var u: int = u_first + roundi(j * spacing)
		if j == count - 1:
			u = u_last + tail if tail > 0 else u_last
		if j > 0 and j < count - 1:
			var jitter: int = floori(0.2 * spacing)
			u += rng.randi_range(-jitter, jitter)
		var kind: int = Macro.NODE_END if j == 0 or j == count - 1 else (Macro.NODE_SUMMIT if j % 2 == 1 else Macro.NODE_SADDLE)
		nodes.append({"u_m": u, "v_m": offsets.call(j, count, u), "kind": kind, "height_cm": 0, "near_width_m": 0, "far_width_m": 0})
	for node: Dictionary in nodes:
		if node.kind == Macro.NODE_SUMMIT:
			node.height_cm = rng.randi_range(summit_range.x, summit_range.y)
	for j in range(count):
		var node: Dictionary = nodes[j]
		if node.kind == Macro.NODE_SADDLE:
			var lower: int = mini(nodes[j - 1].height_cm, nodes[j + 1].height_cm)
			node.height_cm = rng.randi_range(ceili(0.55 * lower), mini(floori(0.80 * lower), lower - 6000))
		elif node.kind == Macro.NODE_END:
			var neighbour: int = nodes[1 if j == 0 else j - 1].height_cm
			var scale: Vector2 = end_scale[0 if j == 0 else 1]
			node.height_cm = rng.randi_range(ceili(scale.x * neighbour), floori(scale.y * neighbour))
	return nodes


static func generate(identity: RefCounted, bounds: RefCounted) -> Macro:
	var structure_seed: int = Seeds.macro_structure_seed(identity.get_region_seed())
	var rng := RandomNumberGenerator.new()
	rng.seed = structure_seed

	# 0. Composition.
	var composition: Dictionary = {"valley_form": rng.randi_range(0, 1), "range_form": rng.randi_range(0, 2), "crest_shape": rng.randi_range(0, 2), "far_form": rng.randi_range(0, 2)}

	# 1. Major valley: central, or offset towards the far edge (larger range).
	var base: Dictionary = {"floor_elevation_cm": rng.randi_range(15000, 30000), "floor_drop_cm": rng.randi_range(2000, 6000)}
	var band: Vector2i = Vector2i(1550, 1900) if composition.valley_form == Macro.VALLEY_CENTRAL else Vector2i(1150, 1350)
	var v_start: int = rng.randi_range(band.x, band.y)
	var v_end: int = rng.randi_range(band.x, band.y)
	var points: Array = []
	var meander_limit: int = rng.randi_range(80, 150)
	var meander: int = rng.randi_range(-meander_limit, meander_limit)
	var half: int = rng.randi_range(70, 150)
	var near_wall: int = rng.randi_range(700, 1300)
	var far_wall: int = rng.randi_range(700, 1300)
	for i in range(Macro.VALLEY_POINT_COUNT):
		if i > 0:
			meander = rng.randi_range(maxi(-meander_limit, meander - 170), mini(meander_limit, meander + 170))
			half = rng.randi_range(maxi(70, half - 45), mini(150, half + 45))
			near_wall = rng.randi_range(maxi(650, near_wall - 280), mini(1350, near_wall + 280))
			far_wall = rng.randi_range(maxi(650, far_wall - 280), mini(1350, far_wall + 280))
		points.append({"v_m": v_start + roundi((v_end - v_start) * i / 8.0) + meander, "floor_half_width_m": half, "near_wall_permille": near_wall, "far_wall_permille": far_wall})
	var valley: Dictionary = {
		"basin_u_m": rng.randi_range(700, 3400), "basin_extra_m": rng.randi_range(220, 480), "basin_half_length_m": rng.randi_range(450, 850),
		"near_wall_width_m": rng.randi_range(320, 560), "near_wall_height_cm": rng.randi_range(5000, 11000), "near_upland_permille": rng.randi_range(40, 90),
		"far_wall_width_m": rng.randi_range(300, 520), "far_wall_height_cm": rng.randi_range(3500, 8000), "far_upland_permille": rng.randi_range(20, 60),
	}

	# 2. Main crest: one connected range crossing the region, a massif ending
	#    inside it, or twin massifs joined by a broad high pass. Its plan shape is
	#    straight/oblique, a bowl opening to the valley, or a headland pushing
	#    towards it.
	var spans_region: bool = composition.range_form != Macro.RANGE_MASSIF
	var u_first: int = rng.randi_range(0, 200)
	var u_last: int = rng.randi_range(3896, 4096) if spans_region else rng.randi_range(2500, 3200)
	var tail: int = 0 if spans_region else rng.randi_range(500, 850)
	var summit_count: int = rng.randi_range(2, 4 if u_last - u_first >= 3300 else 3)
	var end_offsets: Vector2i = [Vector2i(1000, 1800), Vector2i(1000, 1350), Vector2i(1350, 1850)][composition.crest_shape]
	var bow: int = [0, rng.randi_range(300, 550), -rng.randi_range(300, 500)][composition.crest_shape]
	var off_a: int = rng.randi_range(end_offsets.x, end_offsets.y)
	var off_b: int = rng.randi_range(end_offsets.x, end_offsets.y)
	var main_offsets := func(j: int, count: int, u: int) -> int:
		var axis: int = roundi(_axis_v(points, u))
		var f: float = j / float(count - 1)
		var line: int = off_a + roundi((off_b - off_a) * f + bow * sin(PI * f))
		if j == 0 or j == count - 1:
			return axis + line
		var hi: int = maxi(950, mini(line + 220, 3880 - axis))
		return axis + rng.randi_range(mini(hi, maxi(950, line - 220)), hi)
	var main: Array = _ridge_nodes(rng, u_first, u_last, tail, summit_count, main_offsets, Vector2i(50000, 85000), [Vector2(0.45, 0.75), Vector2(0.45, 0.75) if spans_region else Vector2(0.15, 0.30)])
	if composition.range_form == Macro.RANGE_TWIN:
		# Deepen the most central saddle into a broad high pass that splits the
		# range into two massifs while keeping them connected.
		var gap: int = 2 * ((summit_count + 1) / 2)
		var lower: int = mini(main[gap - 1].height_cm, main[gap + 1].height_cm)
		main[gap].height_cm = rng.randi_range(ceili(0.40 * lower), floori(0.50 * lower))
	for node: Dictionary in main:
		node.near_width_m = roundi((node.v_m - _axis_v(points, node.u_m)) * rng.randi_range(550, 780) / 1000.0)
		node.far_width_m = rng.randi_range(1000, 1700)

	# 3. Spurs descend from summits and their shoulders towards the valley
	#    (one major spur), each with up to two second-order branches. Every
	#    summit sends one spur; extra spurs leave a shoulder part-way towards
	#    a neighbouring node.
	var spurs: Array = []
	var spur_count: int = rng.randi_range(3, mini(6, summit_count + 3))
	var major: int = rng.randi_range(0, spur_count - 1)
	var first_summit: int = rng.randi_range(0, summit_count - 1)
	for k in range(spur_count):
		var summit_index: int = 2 * ((first_summit + k) % summit_count) + 1
		var step: int = rng.randi_range(0, 1) * 2 - 1
		var shoulder: float = rng.randi_range(0, 100) / 1000.0 if k < summit_count else rng.randi_range(300, 450) / 1000.0
		var junction: Array = _crest_near(main, summit_index, step, shoulder)
		var a: Vector2i = Vector2i(roundi(junction[0].x), roundi(junction[0].y))
		var start_cm: int = roundi(junction[1]) - rng.randi_range(1500, 5000)
		# Summit spurs head roughly straight down; shoulder spurs diverge away
		# from their summit so neighbouring spurs never converge.
		var drift: Vector2i = Vector2i(-250, 250) if k < summit_count else (Vector2i(150, 500) if step > 0 else Vector2i(-500, -150))
		var end_u: int = rng.randi_range(clampi(a.x + drift.x, 60, SIZE - 60), clampi(a.x + drift.y, 60, SIZE - 60))
		var end_v: int = roundi(_axis_v(points, end_u) + _half_width(points, end_u)) + roundi(valley.near_wall_width_m * rng.randi_range(760, 1100) / 1000.0)
		var b := Vector2i(end_u, end_v)
		var direction: Vector2 = Vector2(b - a).normalized()
		var middle: Vector2 = Vector2(a).lerp(Vector2(b), rng.randi_range(400, 620) / 1000.0) + Vector2(-direction.y, direction.x) * rng.randi_range(-160, 160)
		# Spur noses end just above the valley-wall rise they descend onto.
		var end_cm: int = mini(start_cm, valley.near_wall_height_cm + rng.randi_range(1500, 6000))
		var middle_cm: int = roundi(start_cm * rng.randi_range(680, 840) / 1000.0)
		var width: int = rng.randi_range(420, 700)
		if k == major:
			width = roundi(width * 1.3)
			middle_cm = roundi(start_cm * rng.randi_range(850, 930) / 1000.0)
		var middle_i := Vector2i(clampi(roundi(middle.x), 0, SIZE), clampi(roundi(middle.y), 0, SIZE))
		# Second-order branches leave the spur shoulder on alternating sides.
		var branch_side: int = rng.randi_range(0, 1) * 2 - 1
		for n in range(rng.randi_range(0, 2)):
			var angle: float = deg_to_rad(branch_side * rng.randi_range(35, 70))
			var heading: Vector2 = direction.rotated(angle)
			var tip: Vector2 = Vector2(middle_i) + heading * rng.randi_range(300, 600)
			var branch_end := Vector2i(clampi(roundi(tip.x), 0, SIZE), clampi(roundi(tip.y), 0, SIZE))
			var branch_start: int = middle_cm - rng.randi_range(500, 2500)
			var branch_tip: int = roundi(branch_start * rng.randi_range(250, 450) / 1000.0)
			var branch_mid: Vector2i = (middle_i + branch_end) / 2
			spurs.append({"group": Macro.GROUP_MAIN, "kind": Macro.SPUR_BRANCH, "au_m": middle_i.x, "av_m": middle_i.y, "mu_m": branch_mid.x, "mv_m": branch_mid.y, "bu_m": branch_end.x, "bv_m": branch_end.y, "start_cm": branch_start, "middle_cm": roundi(branch_start * 0.75), "end_cm": branch_tip, "width_m": rng.randi_range(300, 480)})
			branch_side = -branch_side
		spurs.append({"group": Macro.GROUP_MAIN, "kind": Macro.SPUR_VALLEY, "au_m": a.x, "av_m": a.y, "mu_m": middle_i.x, "mv_m": middle_i.y, "bu_m": b.x, "bv_m": b.y, "start_cm": start_cm, "middle_cm": middle_cm, "end_cm": end_cm, "width_m": width})

	# 4. Far side: a lower ridge over part of the valley length, a double-
	#    humped ridge of two hills, or open upland without a ridge.
	var far_first: int = rng.randi_range(0, 1600)
	var far_last: int = rng.randi_range(far_first + 1600, mini(SIZE, far_first + 2800))
	var far_a: int = rng.randi_range(600, 1250)
	var far_b: int = rng.randi_range(600, 1250)
	var far_offsets := func(j: int, count: int, u: int) -> int:
		var axis: int = roundi(_axis_v(points, u))
		var line: int = far_a + roundi((far_b - far_a) * j / float(count - 1))
		return axis - rng.randi_range(maxi(600, line - 220), mini(line + 220, axis - 80))
	var far: Array = []
	if composition.far_form != Macro.FAR_OPEN:
		var hills: bool = composition.far_form == Macro.FAR_HILLS
		far = _ridge_nodes(rng, far_first, far_last, 0, 2 if hills else rng.randi_range(1, 2), far_offsets, Vector2i(18000, 36000), [Vector2(0.22, 0.40), Vector2(0.22, 0.40)])
		if hills:
			var lower: int = mini(far[1].height_cm, far[3].height_cm)
			far[2].height_cm = rng.randi_range(ceili(0.45 * lower), floori(0.60 * lower))
	for node: Dictionary in far:
		node.near_width_m = rng.randi_range(400, 750)
		node.far_width_m = rng.randi_range(400, 750)
	var far_spurs: int = 0 if far.is_empty() else rng.randi_range(1, 3)
	for k in range(far_spurs):
		var junction: Array = _crest_at(far, (k + 0.5) / far_spurs)
		var a: Vector2i = Vector2i(roundi(junction[0].x), roundi(junction[0].y))
		var wall_top: int = roundi(_axis_v(points, a.x) - _half_width(points, a.x) - Macro.basin_widening(valley, a.x) - valley.far_wall_width_m * 1.175 * 0.8)
		if wall_top - a.y < 250:
			continue
		var b := Vector2i(clampi(a.x + rng.randi_range(-300, 300), 0, SIZE), a.y + roundi((wall_top - a.y) * rng.randi_range(600, 900) / 1000.0))
		var start_cm: int = roundi(junction[1]) - rng.randi_range(500, 2000)
		var end_cm: int = mini(start_cm, valley.far_wall_height_cm + rng.randi_range(1000, 3000))
		var middle: Vector2i = (a + b) / 2
		spurs.append({"group": Macro.GROUP_FAR, "kind": Macro.SPUR_VALLEY, "au_m": a.x, "av_m": a.y, "mu_m": middle.x, "mv_m": middle.y, "bu_m": b.x, "bv_m": b.y, "start_cm": start_cm, "middle_cm": (start_cm + end_cm) / 2, "end_cm": end_cm, "width_m": rng.randi_range(300, 480)})

	# 5. Benches on the valley walls; optional far-side upland basin placed
	#    beside (not under) the far ridge.
	var benches: Array = []
	var bench_side: int = rng.randi_range(0, 1) * 2 - 1
	for k in range(rng.randi_range(1, 2)):
		var u_a: int = rng.randi_range(200, 2600)
		benches.append({"side": bench_side if k == 0 else -bench_side, "u_a_m": u_a, "u_b_m": u_a + rng.randi_range(800, 1400), "height_permille": rng.randi_range(350, 650), "width_m": rng.randi_range(120, 260)})
	var basins: Array = []
	var elongation: int = rng.randi_range(1200, 1900)
	var orientation: int = posmod(rng.randi_range(-15, 15), 180)
	var radius: int = rng.randi_range(250, 480)
	var free_start: int = 0 if far.is_empty() or far_first >= SIZE - far_last else far_last
	var free_end: int = SIZE if far.is_empty() else (far_first if far_first >= SIZE - far_last else SIZE)
	var reach: Vector2i = Macro.basin_reach(radius, elongation, orientation)
	if free_end - free_start >= 2 * reach.x + 200:
		var u_c: int = rng.randi_range(free_start + reach.x + 100, free_end - reach.x - 100)
		var outer: int = roundi(_axis_v(points, u_c) - _half_width(points, u_c) - Macro.basin_widening(valley, u_c)) - roundi(valley.far_wall_width_m * 1.175) - rng.randi_range(60, 200)
		# Shrink to the feasible radius; omit the basin when none remains.
		while radius >= 250 and outer - 2 * Macro.basin_reach(radius, elongation, orientation).y < 40:
			radius -= 10
		if radius >= 250:
			basins.append({"u_m": u_c, "v_m": outer - Macro.basin_reach(radius, elongation, orientation).y, "radius_m": radius, "depth_cm": rng.randi_range(1500, 3500), "orientation_deg": orientation, "elongation_permille": elongation})

	# 6. Noise budget and frame symmetry.
	var max_summit: int = 0
	for node: Dictionary in main:
		max_summit = maxi(max_summit, node.height_cm)
	var relief: int = max_summit + valley.near_wall_height_cm + base.floor_drop_cm
	var noise: Dictionary = {"algorithm": "slow_cycle.lattice_value_noise/2", "amplitude_cm": rng.randi_range(ceili(0.03 * relief), floori(0.05 * relief)), "wavelengths_m": [640, 320, 160], "weights_permille": [550, 300, 150], "ridged_permille": rng.randi_range(250, 500), "valley_floor_permille": 300, "bench_permille": 300, "basin_permille": 300}
	var ridge: Dictionary = {"profile_permille": rng.randi_range(1500, 2000), "spur_profile_permille": rng.randi_range(1150, 1450), "crest_rounding_m": rng.randi_range(20, 45), "rib_permille": rng.randi_range(60, 110), "rib_wavelength_m": rng.randi_range(280, 420), "warp_amplitude_m": rng.randi_range(100, 170), "warp_wavelength_m": rng.randi_range(800, 1300)}
	var symmetry: int = rng.randi_range(0, 7)
	return Macro.new({"archetype": Macro.ARCHETYPE_MOUNTAIN_RIVER_VALLEY, "structure_seed": structure_seed, "noise_seed": Seeds.macro_noise_seed(identity.get_region_seed()), "domain_size_m": bounds.get_size_m(), "frame_symmetry": symmetry, "relief_cm": relief, "composition": composition, "base": base, "valley": valley, "ridge": ridge, "noise": noise, "valley_points": points, "main_nodes": main, "far_nodes": far, "spurs": spurs, "benches": benches, "basins": basins})
