class_name HydrologySurface
extends RefCounted

## TRANSITIONAL (R3 -> R7): base terrain + hydrology deformation, with the
## TerrainField query API so the tile renderer and pre-R7 consumers can read
## river beds, banks, floodplain shaping and creek gullies. It owns no truth:
## TerrainField owns base terrain, HydrologyPlan / HydrologyField own
## hydrology, and FinalSurface (R7) becomes the single composed surface and
## absorbs this composition.
##
## height(x, z)   = TerrainField height + HydrologyField deformation;
## gradient/normal use TerrainField's shared stencil over composed heights;
## lattice blocks are bit-identical to point queries. Domain, lattice and
## reasons are TerrainField's.

const Field = preload("res://scripts/world/region/terrain_field.gd")
const HydroField = preload("res://scripts/world/region/hydrology_field.gd")
const SCHEMA_TAG := "slow_cycle.hydrology_surface/1"

var _terrain: Field
var _hydrology: HydroField
var _min_x: int
var _min_z: int
var _max_x: int
var _max_z: int


## Reasons: ERR_HYDRO_SURFACE_INPUT_MISSING, ERR_HYDRO_TERRAIN_MISMATCH.
static func create(terrain_field: RefCounted, hydrology_field: RefCounted) -> Dictionary:
	if terrain_field == null or not terrain_field is Field or hydrology_field == null or not hydrology_field is HydroField:
		return {"is_valid": false, "surface": null, "reason_code": "ERR_HYDRO_SURFACE_INPUT_MISSING"}
	if hydrology_field.get_region_signature() != terrain_field.get_region_signature():
		return {"is_valid": false, "surface": null, "reason_code": "ERR_HYDRO_TERRAIN_MISMATCH"}
	var surface := HydrologySurface.new()
	surface._terrain = terrain_field
	surface._hydrology = hydrology_field
	var bounds: Dictionary = terrain_field.get_bounds_m()
	surface._min_x = bounds.min_x
	surface._min_z = bounds.min_z
	surface._max_x = bounds.max_x
	surface._max_z = bounds.max_z
	return {"is_valid": true, "surface": surface, "reason_code": ""}


func get_bounds_m() -> Dictionary:
	return _terrain.get_bounds_m()


func get_region_signature() -> String:
	return _terrain.get_region_signature()


func _height(x: float, z: float) -> float:
	var base: float = _terrain.sample_height(x, z).height_m
	return base + _hydrology.deformation_local(x - _min_x, z - _min_z, base)


func _gradient(x: float, z: float) -> Vector2:
	var x0: float = maxf(_min_x, x - Field.GRADIENT_HALF_STEP_M)
	var x1: float = minf(_max_x, x + Field.GRADIENT_HALF_STEP_M)
	var z0: float = maxf(_min_z, z - Field.GRADIENT_HALF_STEP_M)
	var z1: float = minf(_max_z, z + Field.GRADIENT_HALF_STEP_M)
	return Field.gradient_from_samples(_height(x0, z), _height(x1, z), x1 - x0, _height(x, z0), _height(x, z1), z1 - z0)


func sample_height(x: float, z: float) -> Dictionary:
	var base: Dictionary = _terrain.sample_height(x, z)
	if not base.is_valid:
		return base
	return {"is_valid": true, "height_m": base.height_m + _hydrology.deformation_local(x - _min_x, z - _min_z, base.height_m), "reason_code": ""}


func sample_gradient(x: float, z: float) -> Dictionary:
	var base: Dictionary = _terrain.sample_height(x, z)
	if not base.is_valid:
		return {"is_valid": false, "gradient": Vector2(NAN, NAN), "reason_code": base.reason_code}
	return {"is_valid": true, "gradient": _gradient(x, z), "reason_code": ""}


func sample_normal(x: float, z: float) -> Dictionary:
	var base: Dictionary = _terrain.sample_height(x, z)
	if not base.is_valid:
		return {"is_valid": false, "normal": Vector3(NAN, NAN, NAN), "reason_code": base.reason_code}
	return {"is_valid": true, "normal": Field.normal_from_gradient(_gradient(x, z)), "reason_code": ""}


## Lattice block with TerrainField's indexing, reasons and check order.
func sample_lattice(i0: int, j0: int, count_x: int, count_z: int) -> Dictionary:
	var step: int = Field.LATTICE_STEP_M
	var min_i: int = _min_x / step
	var min_j: int = _min_z / step
	var max_i: int = _max_x / step
	var max_j: int = _max_z / step
	var failed := {"is_valid": false, "heights_m": PackedFloat64Array(), "gradients": PackedVector2Array(), "normals": PackedVector3Array(), "reason_code": ""}
	if count_x <= 0 or count_z <= 0:
		failed.reason_code = "ERR_TERRAIN_GRID_SHAPE"
		return failed
	if i0 < min_i or j0 < min_j or i0 > max_i or j0 > max_j or count_x - 1 > max_i - i0 or count_z - 1 > max_j - j0:
		failed.reason_code = "ERR_TERRAIN_OUT_OF_DOMAIN"
		return failed
	var hi0: int = maxi(i0 - 1, min_i)
	var hj0: int = maxi(j0 - 1, min_j)
	var hi1: int = mini(i0 + count_x, max_i)
	var hj1: int = mini(j0 + count_z, max_j)
	var width: int = hi1 - hi0 + 1
	var base: Dictionary = _terrain.sample_lattice(hi0, hj0, width, hj1 - hj0 + 1)
	if not base.is_valid:
		failed.reason_code = base.reason_code
		return failed
	var halo: PackedFloat64Array = base.heights_m
	for j in range(hj0, hj1 + 1):
		for i in range(hi0, hi1 + 1):
			var k: int = (j - hj0) * width + (i - hi0)
			halo[k] += _hydrology.deformation_local(float(i * step) - _min_x, float(j * step) - _min_z, halo[k])
	var heights := PackedFloat64Array()
	var gradients := PackedVector2Array()
	var normals := PackedVector3Array()
	heights.resize(count_x * count_z)
	gradients.resize(count_x * count_z)
	normals.resize(count_x * count_z)
	for j in range(j0, j0 + count_z):
		var j_lo: int = maxi(j - 1, min_j)
		var j_hi: int = mini(j + 1, max_j)
		for i in range(i0, i0 + count_x):
			var i_lo: int = maxi(i - 1, min_i)
			var i_hi: int = mini(i + 1, max_i)
			var row: int = (j - hj0) * width
			var gradient: Vector2 = Field.gradient_from_samples(halo[row + i_lo - hi0], halo[row + i_hi - hi0], float(i_hi * step) - float(i_lo * step),
				halo[(j_lo - hj0) * width + i - hi0], halo[(j_hi - hj0) * width + i - hi0], float(j_hi * step) - float(j_lo * step))
			var k: int = (j - j0) * count_x + (i - i0)
			heights[k] = halo[row + i - hi0]
			gradients[k] = gradient
			normals[k] = Field.normal_from_gradient(gradient)
	return {"is_valid": true, "heights_m": heights, "gradients": gradients, "normals": normals, "reason_code": ""}
