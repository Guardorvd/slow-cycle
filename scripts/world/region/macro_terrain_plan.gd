class_name MacroTerrainPlan
extends RefCounted

## Immutable R1 macro-geography descriptor for one region.
##
## All stored values are integers (metres, centimetres, per-mille, enums) in
## the canonical valley frame: u runs along the major valley (0 -> 4096),
## v runs across it, and +v is the mountain side. `frame_symmetry` (0..7)
## maps the frame onto region-local (x, z) exactly. Floats exist only in the
## shared geometry helpers below and in MacroTerrainEvaluator.

const SCHEMA_TAG := "slow_cycle.macro_terrain/2"
const STATE_GENERATED_R1 := "GENERATED_R1"
const ARCHETYPE_MOUNTAIN_RIVER_VALLEY := "MOUNTAIN_RIVER_VALLEY"
const DOMAIN_SIZE_M: int = 4096
const VALLEY_POINT_COUNT: int = 9
const VALLEY_POINT_SPACING_M: int = 512

const NODE_END: int = 0
const NODE_SUMMIT: int = 1
const NODE_SADDLE: int = 2
const GROUP_MAIN: int = 0
const GROUP_FAR: int = 1
const SPUR_VALLEY: int = 0
const SPUR_BRANCH: int = 1
const VALLEY_CENTRAL: int = 0
const VALLEY_OFFSET: int = 1
const RANGE_SPANNING: int = 0
const RANGE_MASSIF: int = 1
const RANGE_TWIN: int = 2
const CREST_LINEAR: int = 0
const CREST_BOWL: int = 1
const CREST_HEADLAND: int = 2
const FAR_RIDGE: int = 0
const FAR_HILLS: int = 1
const FAR_OPEN: int = 2

const SCALARS: Array[String] = ["archetype", "structure_seed", "noise_seed", "domain_size_m", "frame_symmetry", "relief_cm"]
const SECTIONS := {
	"composition": ["valley_form", "range_form", "crest_shape", "far_form"],
	"base": ["floor_elevation_cm", "floor_drop_cm"],
	"valley": ["basin_u_m", "basin_extra_m", "basin_half_length_m", "near_wall_width_m", "near_wall_height_cm", "near_upland_permille", "far_wall_width_m", "far_wall_height_cm", "far_upland_permille"],
	"ridge": ["profile_permille", "spur_profile_permille", "crest_rounding_m", "rib_permille", "rib_wavelength_m", "warp_amplitude_m", "warp_wavelength_m"],
	"noise": ["algorithm", "amplitude_cm", "wavelengths_m", "weights_permille", "ridged_permille", "valley_floor_permille", "bench_permille", "basin_permille"],
}
const COLLECTIONS := {
	"valley_points": ["v_m", "floor_half_width_m", "near_wall_permille", "far_wall_permille"],
	"main_nodes": ["u_m", "v_m", "kind", "height_cm", "near_width_m", "far_width_m"],
	"far_nodes": ["u_m", "v_m", "kind", "height_cm", "near_width_m", "far_width_m"],
	"spurs": ["group", "kind", "au_m", "av_m", "mu_m", "mv_m", "bu_m", "bv_m", "start_cm", "middle_cm", "end_cm", "width_m"],
	"benches": ["side", "u_a_m", "u_b_m", "height_permille", "width_m"],
	"basins": ["u_m", "v_m", "radius_m", "depth_cm", "orientation_deg", "elongation_permille"],
}

var _state: String = STATE_GENERATED_R1
var _data: Dictionary


func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)


func get_state() -> String:
	return _state


func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_structure_seed() -> int:
	return _data.get("structure_seed", -1)


func get_noise_seed() -> int:
	return _data.get("noise_seed", -1)


static func _text(value: Variant) -> String:
	if value is Array:
		var parts: PackedStringArray = []
		for item: Variant in value:
			parts.append(str(item))
		return ",".join(parts)
	return str(value)


func canonical_text() -> String:
	var text: String = SCHEMA_TAG + "\nstate=" + _state + "\n"
	for key: String in SCALARS:
		text += key + "=" + _text(_data.get(key, "MISSING")) + "\n"
	for section: String in SECTIONS:
		var values: Dictionary = _data.get(section, {})
		for key: String in SECTIONS[section]:
			text += section + "." + key + "=" + _text(values.get(key, "MISSING")) + "\n"
	for collection: String in COLLECTIONS:
		var items: Array = _data.get(collection, [])
		text += collection + ".count=" + str(items.size()) + "\n"
		for i in range(items.size()):
			var values: PackedStringArray = []
			for key: String in COLLECTIONS[collection]:
				values.append(str(items[i].get(key, "MISSING")))
			text += collection + "." + str(i) + "=" + ",".join(values) + "\n"
	return text


func signature() -> String:
	return canonical_text().sha256_text()


# --- Shared frame and valley geometry (used by generator, evaluator, tests) ---

## Canonical frame (u, v) -> region-local (x, z). Mirror first, then rotate.
static func frame_to_local(symmetry: int, u: float, v: float) -> Vector2:
	if symmetry >= 4:
		v = DOMAIN_SIZE_M - v
	match symmetry % 4:
		0: return Vector2(u, v)
		1: return Vector2(DOMAIN_SIZE_M - v, u)
		2: return Vector2(DOMAIN_SIZE_M - u, DOMAIN_SIZE_M - v)
		_: return Vector2(v, DOMAIN_SIZE_M - u)


## Exact inverse of frame_to_local.
static func local_to_frame(symmetry: int, x: float, z: float) -> Vector2:
	var result: Vector2
	match symmetry % 4:
		0: result = Vector2(x, z)
		1: result = Vector2(z, DOMAIN_SIZE_M - x)
		2: result = Vector2(DOMAIN_SIZE_M - x, DOMAIN_SIZE_M - z)
		_: result = Vector2(DOMAIN_SIZE_M - z, x)
	if symmetry >= 4:
		result.y = DOMAIN_SIZE_M - result.y
	return result


## Uniform cubic Hermite (Catmull-Rom) through values at u = i * 512.
## Returns Vector2(value, derivative per metre). C1, finite on [0, 4096].
static func spline(values: Variant, u: float) -> Vector2:
	var last: int = values.size() - 1
	var s: float = clampf(u / VALLEY_POINT_SPACING_M, 0.0, float(last))
	var i: int = mini(floori(s), last - 1)
	var t: float = s - i
	var p0: float = values[maxi(i - 1, 0)]
	var p1: float = values[i]
	var p2: float = values[i + 1]
	var p3: float = values[mini(i + 2, last)]
	var m1: float = (p2 - p0) / (2.0 if i > 0 else 1.0)
	var m2: float = (p3 - p1) / (2.0 if i + 1 < last else 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	var value: float = (2 * t3 - 3 * t2 + 1) * p1 + (t3 - 2 * t2 + t) * m1 + (-2 * t3 + 3 * t2) * p2 + (t3 - t2) * m2
	var slope: float = (6 * t2 - 6 * t) * p1 + (3 * t2 - 4 * t + 1) * m1 + (-6 * t2 + 6 * t) * p2 + (3 * t2 - 2 * t) * m2
	return Vector2(value, slope / VALLEY_POINT_SPACING_M)


static func valley_axis(data: Dictionary, u: float) -> Vector2:
	var values: Array = []
	for point: Dictionary in data.valley_points:
		values.append(point.v_m)
	return spline(values, u)


static func basin_widening(valley: Dictionary, u: float) -> float:
	var x: float = (u - valley.basin_u_m) / valley.basin_half_length_m
	return valley.basin_extra_m * pow(maxf(0.0, 1.0 - x * x), 3)


## Valley floor half-widths at u: Vector2(near side, far side). The basin
## widening opens the floor towards the far side only.
static func floor_half_widths(data: Dictionary, u: float) -> Vector2:
	var values: Array = []
	for point: Dictionary in data.valley_points:
		values.append(point.floor_half_width_m)
	var half: float = spline(values, u).x
	return Vector2(half, half + basin_widening(data.valley, u))


## Local valley wall Vector2(width m, height m) on one side at u. The
## per-point permille scales the height and half of the width.
static func valley_wall(data: Dictionary, u: float, near: bool) -> Vector2:
	var values: Array = []
	for point: Dictionary in data.valley_points:
		values.append(point.near_wall_permille if near else point.far_wall_permille)
	var scale: float = spline(values, u).x / 1000.0
	var width: float = data.valley.near_wall_width_m if near else data.valley.far_wall_width_m
	var height: float = (data.valley.near_wall_height_cm if near else data.valley.far_wall_height_cm) / 100.0
	return Vector2(width * (1.0 + scale) * 0.5, height * scale)


## Crest-height interpolation used for every ridge segment (cosine ease).
static func ease_height(a: float, b: float, t: float) -> float:
	return lerpf(a, b, 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0)))


## Integer half-extents (u, v) of an upland basin ellipse, rounded up.
static func basin_reach(radius_m: int, elongation_permille: int, orientation_deg: int) -> Vector2i:
	var a: float = radius_m * elongation_permille / 1000.0
	var b: float = radius_m
	var angle: float = deg_to_rad(orientation_deg)
	return Vector2i(ceili(sqrt(pow(a * cos(angle), 2) + pow(b * sin(angle), 2))), ceili(sqrt(pow(a * sin(angle), 2) + pow(b * cos(angle), 2))))


static func in_range(value: Variant, lo: int, hi: int) -> bool:
	return value is int and value >= lo and value <= hi


static func _integer_values(value: Variant) -> bool:
	if value is Dictionary:
		for item: Variant in value.values():
			if not _integer_values(item):
				return false
		return true
	if value is Array:
		for item: Variant in value:
			if not _integer_values(item):
				return false
		return true
	return value is int or value is String


func _has_layout() -> bool:
	for key: String in SCALARS:
		if not _data.has(key):
			return false
	for section: String in SECTIONS:
		if not _data.get(section) is Dictionary:
			return false
		for key: String in SECTIONS[section]:
			if not _data[section].has(key):
				return false
	for collection: String in COLLECTIONS:
		if not _data.get(collection) is Array:
			return false
		for item: Variant in _data[collection]:
			if not item is Dictionary:
				return false
			for key: String in COLLECTIONS[collection]:
				if not item.has(key):
					return false
	return _integer_values(_data)


static func _inside(u: Variant, v: Variant) -> bool:
	return in_range(u, 0, DOMAIN_SIZE_M) and in_range(v, 0, DOMAIN_SIZE_M)


## Descriptor-level validation. Diagnostic only: never mutates or repairs.
## Fixed check order; every reason code appears at most once.
func validate() -> Dictionary:
	var reasons: Array[String] = []
	if _state != STATE_GENERATED_R1 or not _has_layout() or _data.domain_size_m != DOMAIN_SIZE_M or not in_range(_data.frame_symmetry, 0, 7):
		reasons.append("ERR_MACRO_SCHEMA")
		return {"is_valid": false, "reason_codes": reasons}
	if _data.archetype != ARCHETYPE_MOUNTAIN_RIVER_VALLEY:
		reasons.append("ERR_MACRO_ARCHETYPE")
	var valley: Dictionary = _data.valley
	var points: Array = _data.valley_points
	var valley_ok: bool = points.size() == VALLEY_POINT_COUNT
	valley_ok = valley_ok and in_range(valley.basin_u_m, 600, 3500) and in_range(valley.basin_extra_m, 200, 500) and in_range(valley.basin_half_length_m, 400, 900)
	valley_ok = valley_ok and in_range(valley.near_wall_width_m, 300, 600) and in_range(valley.near_wall_height_cm, 4000, 12000) and in_range(valley.near_upland_permille, 20, 100)
	valley_ok = valley_ok and in_range(valley.far_wall_width_m, 280, 560) and in_range(valley.far_wall_height_cm, 3000, 9000) and in_range(valley.far_upland_permille, 10, 80)
	for i in range(points.size()):
		valley_ok = valley_ok and in_range(points[i].v_m, 1000, 2100) and in_range(points[i].floor_half_width_m, 60, 170) and in_range(points[i].near_wall_permille, 600, 1400) and in_range(points[i].far_wall_permille, 600, 1400)
		if i > 0:
			valley_ok = valley_ok and absi(points[i].v_m - points[i - 1].v_m) <= 260 and absi(points[i].floor_half_width_m - points[i - 1].floor_half_width_m) <= 50
			valley_ok = valley_ok and absi(points[i].near_wall_permille - points[i - 1].near_wall_permille) <= 300 and absi(points[i].far_wall_permille - points[i - 1].far_wall_permille) <= 300
	if not valley_ok:
		reasons.append("ERR_MACRO_VALLEY")
	var main: Array = _data.main_nodes
	var summits: int = 0
	var saddles: int = 0
	for node: Dictionary in main:
		summits += 1 if node.kind == NODE_SUMMIT else 0
		saddles += 1 if node.kind == NODE_SADDLE else 0
	if not in_range(summits, 2, 4):
		reasons.append("ERR_MACRO_MOUNTAIN_COUNT")
	var main_spurs: int = 0
	for spur: Dictionary in _data.spurs:
		main_spurs += 1 if spur.group == GROUP_MAIN and spur.kind == SPUR_VALLEY else 0
	if main.size() < 5 or not in_range(main_spurs, 3, 6):
		reasons.append("ERR_MACRO_RIDGE_COUNT")
	if saddles < 1 or saddles != summits - 1:
		reasons.append("ERR_MACRO_SADDLE_COUNT")
	if not in_range(_data.benches.size(), 1, 2):
		reasons.append("ERR_MACRO_BENCH_COUNT")
	if not in_range(_data.basins.size(), 0, 1):
		reasons.append("ERR_MACRO_BASIN_COUNT")
	var bounds_ok: bool = true
	for collection: String in ["main_nodes", "far_nodes", "basins"]:
		for item: Dictionary in _data[collection]:
			bounds_ok = bounds_ok and _inside(item.u_m, item.v_m)
	for spur: Dictionary in _data.spurs:
		bounds_ok = bounds_ok and _inside(spur.au_m, spur.av_m) and _inside(spur.mu_m, spur.mv_m) and _inside(spur.bu_m, spur.bv_m)
	for bench: Dictionary in _data.benches:
		bounds_ok = bounds_ok and in_range(bench.u_a_m, 0, DOMAIN_SIZE_M) and in_range(bench.u_b_m, 0, DOMAIN_SIZE_M)
	for basin: Dictionary in _data.basins:
		var reach: Vector2i = basin_reach(basin.radius_m, basin.elongation_permille, basin.orientation_deg)
		bounds_ok = bounds_ok and in_range(basin.u_m - reach.x, 0, DOMAIN_SIZE_M) and in_range(basin.u_m + reach.x, 0, DOMAIN_SIZE_M) and in_range(basin.v_m - reach.y, 0, DOMAIN_SIZE_M) and in_range(basin.v_m + reach.y, 0, DOMAIN_SIZE_M)
	if not bounds_ok:
		reasons.append("ERR_MACRO_FEATURE_BOUNDS")
	if not _shape_ok(valley_ok):
		reasons.append("ERR_MACRO_FEATURE_SHAPE")
	var noise: Dictionary = _data.noise
	var relief: int = _data.relief_cm
	if relief <= 0 or noise.algorithm != "slow_cycle.lattice_value_noise/2" or not in_range(noise.amplitude_cm, 1, 1000000) or 100 * noise.amplitude_cm > 6 * relief \
			or noise.wavelengths_m != [640, 320, 160] or noise.weights_permille != [550, 300, 150] or not in_range(noise.ridged_permille, 0, 600) \
			or noise.valley_floor_permille != 300 or noise.bench_permille != 300 or noise.basin_permille != 300:
		reasons.append("ERR_MACRO_NOISE_BUDGET")
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}


func _shape_ok(valley_ok: bool) -> bool:
	var ridge: Dictionary = _data.ridge
	var ok: bool = in_range(ridge.profile_permille, 1400, 2200) and in_range(ridge.spur_profile_permille, 1000, 1800) and in_range(ridge.crest_rounding_m, 20, 200) and in_range(ridge.rib_permille, 0, 250) and in_range(ridge.rib_wavelength_m, 200, 600) and in_range(ridge.warp_amplitude_m, 0, 200) and in_range(ridge.warp_wavelength_m, 600, 1600)
	var main: Array = _data.main_nodes
	# Crest grammar: END, SUMMIT, (SADDLE, SUMMIT)*, END along increasing u.
	for i in range(main.size()):
		var node: Dictionary = main[i]
		var expected: int = NODE_END if i == 0 or i == main.size() - 1 else (NODE_SUMMIT if i % 2 == 1 else NODE_SADDLE)
		ok = ok and node.kind == expected and in_range(node.near_width_m, 300, 2200) and in_range(node.far_width_m, 500, 1800)
		if i > 0:
			ok = ok and node.u_m > main[i - 1].u_m
		if node.kind == NODE_SUMMIT:
			ok = ok and in_range(node.height_cm, 30000, 90000)
		elif node.kind == NODE_SADDLE and i + 1 < main.size():
			# A saddle is a real pass: well below both neighbouring summits.
			ok = ok and node.height_cm >= 12000 and node.height_cm + 6000 <= mini(main[i - 1].height_cm, main[i + 1].height_cm)
		elif node.kind == NODE_END:
			ok = ok and in_range(node.height_cm, 5000, 70000)
	var far: Array = _data.far_nodes
	for i in range(far.size()):
		ok = ok and in_range(far[i].height_cm, 3000, 40000) and in_range(far[i].near_width_m, 250, 1000) and in_range(far[i].far_width_m, 250, 1000)
		if i > 0:
			ok = ok and far[i].u_m > far[i - 1].u_m
	# Composition enums and their structural consequences.
	var composition: Dictionary = _data.composition
	ok = ok and in_range(composition.valley_form, 0, 1) and in_range(composition.range_form, 0, 2) and in_range(composition.crest_shape, 0, 2) and in_range(composition.far_form, 0, 2)
	ok = ok and (far.is_empty() == (composition.far_form == FAR_OPEN)) and (far.is_empty() or (far.size() >= 3 and far.size() % 2 == 1))
	if composition.range_form == RANGE_TWIN and main.size() >= 5:
		var deep: bool = false
		for i in range(2, main.size() - 2, 2):
			deep = deep or 100 * main[i].height_cm <= 50 * mini(main[i - 1].height_cm, main[i + 1].height_cm)
		ok = ok and deep
	if valley_ok:
		for node: Dictionary in main:
			# The main crest stays on the mountain side, clear of the valley wall.
			var axis: Vector2 = valley_axis(_data, node.u_m)
			var half: Vector2 = floor_half_widths(_data, node.u_m)
			ok = ok and node.v_m - axis.x >= half.x + _data.valley.near_wall_width_m + 150
		for node: Dictionary in _data.far_nodes:
			var axis: Vector2 = valley_axis(_data, node.u_m)
			ok = ok and axis.x - node.v_m >= 400
	for spur: Dictionary in _data.spurs:
		ok = ok and in_range(spur.group, 0, 1) and in_range(spur.kind, 0, 1) and in_range(spur.width_m, 180, 1000) and spur.start_cm > 0 and spur.end_cm > 0 and spur.middle_cm > 0
		ok = ok and spur.end_cm <= spur.start_cm and spur.middle_cm <= spur.start_cm
	for bench: Dictionary in _data.benches:
		ok = ok and bench.side in [-1, 1] and bench.u_b_m - bench.u_a_m >= 600 and in_range(bench.height_permille, 300, 700) and in_range(bench.width_m, 100, 300)
	for basin: Dictionary in _data.basins:
		ok = ok and in_range(basin.radius_m, 250, 520) and in_range(basin.depth_cm, 1500, 4000) and in_range(basin.orientation_deg, 0, 179) and in_range(basin.elongation_permille, 1000, 2000)
	return ok
