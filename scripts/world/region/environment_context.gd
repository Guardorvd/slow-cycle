class_name EnvironmentContext
extends RefCounted

## Derived sampling/composition helper; no world truth, public height surface,
## mutable upstream storage, cache, scene-tree or road dependency.
const Region = preload("res://scripts/world/region/region_plan.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const SCHEMA_TAG := "slow_cycle.environment_context/1"
const SURFACE_BASIS := "BASE_PLUS_HYDROLOGY_PRE_ROAD"
const MODEL := "signals/1;water_radius=160;valley_feather=80;area_log=1024:1048576;area_filter=1,2,1;moisture=.68,.12,.20;aspect_fade=.02:.15"

var _bounds: Dictionary
var _region_signature: String
var _input_signature: String
var _signature: String
var _biome_seed: int
var _hydro: HField
var _surface: Surface
var _symmetry: int
var _relief_m: float
var _frame: Array
var _drainage := PackedFloat64Array()


static func _failure(reason: String, detail: String = "") -> Dictionary:
	return {"is_valid": false, "context": null, "reason_code": reason, "detail": detail}


static func create(region_plan: RefCounted, terrain_field: RefCounted, hydrology_plan: RefCounted) -> Dictionary:
	if region_plan == null or terrain_field == null or hydrology_plan == null:
		return _failure("ERR_ENV_INPUT_MISSING")
	if not region_plan is Region or not terrain_field is Terrain or not hydrology_plan is Hydro:
		return _failure("ERR_ENV_INPUT_INVALID")
	if not region_plan.validate().is_valid:
		return _failure("ERR_ENV_INPUT_INVALID")
	var data: Dictionary = hydrology_plan.get_data()
	# Guard before calling the older validator/index constructor.
	if not _representation_ok(data) or not _consumed_data_ok(data):
		return _failure("ERR_ENV_HYDRO_DATA")
	if not hydrology_plan.validate().is_valid:
		return _failure("ERR_ENV_INPUT_INVALID")
	var bounds: Dictionary = terrain_field.get_bounds_m()
	var rb: RefCounted = region_plan.get_bounds()
	if region_plan.signature() != terrain_field.get_region_signature() or data.region_signature != region_plan.signature() or data.terrain_schema != Terrain.SCHEMA_TAG or data.origin_x_m != bounds.min_x or data.origin_z_m != bounds.min_z or bounds.min_x != rb.get_min_x_m() or bounds.min_z != rb.get_min_z_m() or bounds.max_x != rb.get_max_x_m() or bounds.max_z != rb.get_max_z_m():
		return _failure("ERR_ENV_INPUT_MISMATCH")
	var macro: Dictionary = region_plan.get_macro_terrain().get_data()
	if macro.relief_cm <= 0 or data.frame_symmetry != macro.frame_symmetry:
		return _failure("ERR_ENV_HYDRO_DATA")
	var made: Dictionary = HField.create(hydrology_plan, terrain_field)
	if not made.is_valid:
		return _failure("ERR_ENV_DEPENDENCY", made.reason_code)
	var composed: Dictionary = Surface.create(terrain_field, made.field)
	if not composed.is_valid:
		return _failure("ERR_ENV_DEPENDENCY", composed.reason_code)
	var context := EnvironmentContext.new()
	context._bounds = bounds.duplicate(true)
	context._region_signature = region_plan.signature()
	context._input_signature = (context._region_signature + "\n" + hydrology_plan.signature() + "\n" + Region.SCHEMA_TAG + "\n" + Terrain.SCHEMA_TAG + "\n" + Hydro.SCHEMA_TAG + "\n" + HField.SCHEMA_TAG + "\n" + Surface.SCHEMA_TAG + "\n" + SURFACE_BASIS).sha256_text()
	context._signature = (SCHEMA_TAG + "\n" + context._input_signature + "\n" + MODEL).sha256_text()
	context._biome_seed = Seeds.biome_seed(region_plan.get_identity().get_region_seed())
	context._hydro = made.field
	context._surface = composed.surface
	context._frame = Hydro.frame_arrays_m(data.river_frame)
	context._symmetry = data.frame_symmetry
	context._relief_m = macro.relief_cm / 100.0
	context._prepare_drainage(data.lattice.area_cells)
	return {"is_valid": true, "context": context, "reason_code": ""}


## Structural guard before the older dependency validator. Uses the public
## schema constants/data copy rather than calling a private validator helper.
static func _representation_ok(data: Dictionary) -> bool:
	for key: String in Hydro.SCALARS + ["character", "channels", "bodies", "floodplain_reaches", "river_frame", "lattice"]:
		if not data.has(key):
			return false
	if not data.character is Dictionary or not data.channels is Array or not data.bodies is Array or not data.river_frame is Dictionary or not data.lattice is Dictionary:
		return false
	for key: String in Hydro.CHARACTER:
		if not data.character.get(key) is int:
			return false
	for i in range(data.channels.size()):
		var channel: Variant = data.channels[i]
		if not channel is Dictionary:
			return false
		for key: String in Hydro.CHANNEL_KEYS:
			if not channel.get(key) is int:
				return false
		if channel.id != i:
			return false
		var count: int = -1
		for key: String in Hydro.CHANNEL_ARRAYS:
			if not channel.get(key) is PackedInt64Array:
				return false
			count = channel[key].size() if count < 0 else count
			if count < 2 or count != channel[key].size():
				return false
	for body: Variant in data.bodies:
		if not body is Dictionary or not body.get("cells") is PackedInt32Array or body.cells.is_empty():
			return false
		for key: String in Hydro.BODY_KEYS:
			if not body.get(key) is int:
				return false
	for key: String in Hydro.FRAME_ARRAYS:
		if not data.river_frame.get(key) is PackedInt64Array or data.river_frame[key].size() != 257:
			return false
	return data.lattice.get("area_cells") is PackedInt32Array and data.lattice.area_cells.size() == 16641 and data.lattice.get("receiver") is PackedInt32Array and data.lattice.receiver.size() == 16641 and data.lattice.get("terminal") is PackedByteArray and data.lattice.terminal.size() == 16641 and data.lattice.get("catchment") is PackedInt32Array and data.lattice.catchment.size() == 16641


static func _consumed_data_ok(data: Dictionary) -> bool:
	if not data.origin_x_m is int or not data.origin_z_m is int or not data.frame_symmetry is int or data.frame_symmetry < 0 or data.frame_symmetry > 7 or not data.region_signature is String or not data.terrain_schema is String:
		return false
	var occupied: Dictionary = {}
	for i in range(data.bodies.size()):
		var body: Dictionary = data.bodies[i]
		if body.id != i or body.kind not in [Hydro.BODY_POND, Hydro.BODY_CLOSED]:
			return false
		for cell: int in body.cells:
			if cell < 0 or cell >= 129 * 129 or occupied.has(cell):
				return false
			occupied[cell] = true
	for area: int in data.lattice.area_cells:
		if area < 0:
			return false
	for k in range(Hydro.RIVER_STATIONS):
		var frame: Dictionary = data.river_frame
		# Near is the +v mountain-side edge, far the -v edge (R3 frame).
		if frame.far_v_cm[k] < 0 or frame.near_v_cm[k] > Hydro.DOMAIN_CM or frame.far_v_cm[k] >= frame.near_v_cm[k] or frame.river_v_cm[k] < frame.far_v_cm[k] or frame.river_v_cm[k] > frame.near_v_cm[k]:
			return false
	return true


func _prepare_drainage(area: PackedInt32Array) -> void:
	var raw := PackedFloat64Array()
	raw.resize(area.size())
	for k in range(area.size()):
		raw[k] = clampf(log(1.0 + float(area[k]) * 1024.0) / log(1048577.0), 0.0, 1.0)
	var temp := PackedFloat64Array()
	temp.resize(raw.size())
	_drainage.resize(raw.size())
	for j in range(129):
		for i in range(129):
			temp[j * 129 + i] = (raw[j * 129 + maxi(0, i - 1)] + 2.0 * raw[j * 129 + i] + raw[j * 129 + mini(128, i + 1)]) * 0.25
	for j in range(129):
		for i in range(129):
			_drainage[j * 129 + i] = (temp[maxi(0, j - 1) * 129 + i] + 2.0 * temp[j * 129 + i] + temp[mini(128, j + 1) * 129 + i]) * 0.25


static func smooth(a: float, b: float, value: float) -> float:
	var t: float = clampf((value - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func get_bounds_m() -> Dictionary:
	return _bounds.duplicate(true)


func get_region_signature() -> String:
	return _region_signature


func get_input_signature() -> String:
	return _input_signature


func signature() -> String:
	return _signature


func get_biome_seed() -> int:
	return _biome_seed


func get_frame_symmetry() -> int:
	return _symmetry


func get_storage_metrics() -> Dictionary:
	var result: Dictionary = _hydro.get_proximity_metrics()
	result["drainage_packed_bytes"] = _drainage.size() * 8
	return result


func query_reason(x: float, z: float) -> String:
	if not is_finite(x) or not is_finite(z):
		return "ERR_ENV_NONFINITE_INPUT"
	if x < _bounds.min_x or z < _bounds.min_z or x > _bounds.max_x or z > _bounds.max_z:
		return "ERR_ENV_OUT_OF_DOMAIN"
	return ""


func grid_reason(i0: int, j0: int, nx: int, nz: int) -> String:
	if nx <= 0 or nz <= 0:
		return "ERR_ENV_GRID_SHAPE"
	var imin: int = _bounds.min_x / 16
	var jmin: int = _bounds.min_z / 16
	var imax: int = _bounds.max_x / 16
	var jmax: int = _bounds.max_z / 16
	if i0 < imin or i0 > imax or j0 < jmin or j0 > jmax or nx - 1 > imax - i0 or nz - 1 > jmax - j0:
		return "ERR_ENV_OUT_OF_DOMAIN"
	return ""


func _area_signal(lx: float, lz: float) -> float:
	var sx: float = lx / 32.0
	var sz: float = lz / 32.0
	var i: int = mini(127, floori(sx))
	var j: int = mini(127, floori(sz))
	return lerpf(lerpf(_drainage[j * 129 + i], _drainage[j * 129 + i + 1], sx - i), lerpf(_drainage[(j + 1) * 129 + i], _drainage[(j + 1) * 129 + i + 1], sx - i), sz - j)


## Shared production signal kernel. Point and block paths differ only in the
## source of natural height/gradient; water remains an exact point predicate.
func _signals(x: float, z: float, height: float, gradient: Vector2) -> Dictionary:
	var lx: float = x - _bounds.min_x
	var lz: float = z - _bounds.min_z
	var f: Array = Hydro.frame_values(_symmetry, _frame, lx, lz)
	var valley: float = 1.0 - smooth(-40.0, 80.0, maxf(f[0] - f[2], f[3] - f[0]))
	var distance: float = _hydro.sample_proximity_bounded(x, z, 160.0).distance_to_water_m
	var water_influence: float = 1.0 - smooth(0.0, 160.0, distance)
	var area: float = _area_signal(lx, lz)
	var water: Dictionary = _hydro.sample_water(x, z)
	var grade: float = gradient.length()
	# North is -Z in world coordinates; downslope north is a shaded aspect.
	var shade: float = aspect_shade(gradient)
	return {"is_valid": true, "reason_code": "", "local_x": lx, "local_z": lz, "relative_elevation": clampf((height - f[4]) / _relief_m, 0.0, 1.5), "gradient": gradient, "slope_grade": grade, "shade": shade, "valley_floor_weight": valley, "distance_to_water_m": distance, "drainage_influence": area, "moisture": clampf(0.68 * water_influence + 0.12 * valley + 0.20 * area, 0.0, 1.0), "is_water": water.is_water, "water_depth_m": water.depth_m}


static func aspect_shade(gradient: Vector2) -> float:
	var grade: float = gradient.length()
	return (gradient.y / maxf(grade, 0.000001)) * smooth(0.02, 0.15, grade)


func sample_signals(x: float, z: float) -> Dictionary:
	var reason: String = query_reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "reason_code": reason}
	return _signals(x, z, _surface.sample_height(x, z).height_m, _surface.sample_gradient(x, z).gradient)


func sample_signal_lattice(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	var reason: String = grid_reason(i0, j0, nx, nz)
	if not reason.is_empty():
		return {"is_valid": false, "reason_code": reason}
	var natural: Dictionary = _surface.sample_lattice(i0, j0, nx, nz)
	var signals: Array = []
	for j in range(nz):
		for i in range(nx):
			var k: int = j * nx + i
			signals.append(_signals(float((i0 + i) * 16), float((j0 + j) * 16), natural.heights_m[k], natural.gradients[k]))
	return {"is_valid": true, "reason_code": "", "signals": signals}
