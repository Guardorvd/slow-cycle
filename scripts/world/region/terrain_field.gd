class_name TerrainField
extends RefCounted

## World-space base-terrain query contract for one region (R2): height,
## gradient and normal. The single public source of base-terrain height until
## FinalSurface (R7) composes deformations on top of it.
##
## height(x, z)   = R1 final elevation (structure + bounded noise) at the
##                  region-local point (x - min_x, z - min_z);
## gradient(x, z) = central difference over +-GRADIENT_HALF_STEP_M, one-sided
##                  at the region edge (the stencil is clamped to the domain);
## normal(x, z)   = Vector3(-gradient.x, 1, -gradient.y).normalized().
##
## Domain: the closed world square of the region. Grid queries use one
## world-anchored lattice (point (i, j) = world (16 i, 16 j), int64 indices),
## so a lattice point always yields the same answer whichever block, tile or
## field instance asks for it. Immutable after create(); concurrent use is not
## claimed. Failures are diagnosed with a reason, never repaired.

const RegionPlanScript = preload("res://scripts/world/region/region_plan.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const SCHEMA_TAG := "slow_cycle.terrain_field/1"
const LATTICE_STEP_M: int = 16
const GRADIENT_HALF_STEP_M: float = 16.0

var _context: Eval.Context
var _min_x: int
var _min_z: int
var _max_x: int
var _max_z: int
var _min_i: int
var _min_j: int
var _max_i: int
var _max_j: int
var _region_signature: String


## Field over a valid RegionPlan; reasons ERR_TERRAIN_PLAN_MISSING,
## ERR_TERRAIN_PLAN_INVALID. The plan is read once; later plan changes do
## not reach the field.
static func create(region_plan: RefCounted) -> Dictionary:
	if region_plan == null or not region_plan is RegionPlanScript or region_plan.get_macro_terrain() == null or region_plan.get_bounds() == null:
		return {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_MISSING"}
	if not region_plan.validate().is_valid:
		return {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_INVALID"}
	var field := TerrainField.new()
	var bounds: RefCounted = region_plan.get_bounds()
	field._context = Eval.prepare(region_plan.get_macro_terrain())
	field._min_x = bounds.get_min_x_m()
	field._min_z = bounds.get_min_z_m()
	field._max_x = bounds.get_max_x_m()
	field._max_z = bounds.get_max_z_m()
	field._min_i = field._min_x / LATTICE_STEP_M
	field._min_j = field._min_z / LATTICE_STEP_M
	field._max_i = field._max_x / LATTICE_STEP_M
	field._max_j = field._max_z / LATTICE_STEP_M
	field._region_signature = region_plan.signature()
	return {"is_valid": true, "field": field, "reason_code": ""}


func get_bounds_m() -> Dictionary:
	return {"min_x": _min_x, "min_z": _min_z, "max_x": _max_x, "max_z": _max_z}


func get_region_signature() -> String:
	return _region_signature


func _reason(x: float, z: float) -> String:
	if not is_finite(x) or not is_finite(z):
		return "ERR_TERRAIN_NONFINITE_INPUT"
	if x < _min_x or z < _min_z or x > _max_x or z > _max_z:
		return "ERR_TERRAIN_OUT_OF_DOMAIN"
	return ""


func _height(x: float, z: float) -> float:
	return Eval.sample_prepared(_context, x - _min_x, z - _min_z, true)


func _gradient(x: float, z: float) -> Vector2:
	var x0: float = maxf(_min_x, x - GRADIENT_HALF_STEP_M)
	var x1: float = minf(_max_x, x + GRADIENT_HALF_STEP_M)
	var z0: float = maxf(_min_z, z - GRADIENT_HALF_STEP_M)
	var z1: float = minf(_max_z, z + GRADIENT_HALF_STEP_M)
	return gradient_from_samples(_height(x0, z), _height(x1, z), x1 - x0, _height(x, z0), _height(x, z1), z1 - z0)


## The single gradient stencil definition, shared by the point and lattice
## paths here and by HydrologySurface (R3): difference quotients over the
## (possibly one-sided, clamped) +-GRADIENT_HALF_STEP_M spans.
static func gradient_from_samples(h_x0: float, h_x1: float, span_x: float, h_z0: float, h_z1: float, span_z: float) -> Vector2:
	return Vector2((h_x1 - h_x0) / span_x, (h_z1 - h_z0) / span_z)


static func normal_from_gradient(gradient: Vector2) -> Vector3:
	return Vector3(-gradient.x, 1.0, -gradient.y).normalized()


func sample_height(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "height_m": NAN, "reason_code": reason}
	return {"is_valid": true, "height_m": _height(x, z), "reason_code": ""}


func sample_gradient(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "gradient": Vector2(NAN, NAN), "reason_code": reason}
	return {"is_valid": true, "gradient": _gradient(x, z), "reason_code": ""}


func sample_normal(x: float, z: float) -> Dictionary:
	var reason: String = _reason(x, z)
	if not reason.is_empty():
		return {"is_valid": false, "normal": Vector3(NAN, NAN, NAN), "reason_code": reason}
	return {"is_valid": true, "normal": normal_from_gradient(_gradient(x, z)), "reason_code": ""}


## Lattice block of count_x * count_z points from lattice index (i0, j0),
## row-major (z outer). Values are bit-identical to the point queries at the
## same world points. Reasons: ERR_TERRAIN_GRID_SHAPE (count <= 0),
## ERR_TERRAIN_OUT_OF_DOMAIN (block not fully inside the region; integer
## bounds, so a block never exceeds one region's 257 x 257 points).
func sample_lattice(i0: int, j0: int, count_x: int, count_z: int) -> Dictionary:
	var failed := {"is_valid": false, "heights_m": PackedFloat64Array(), "gradients": PackedVector2Array(), "normals": PackedVector3Array(), "reason_code": ""}
	if count_x <= 0 or count_z <= 0:
		failed.reason_code = "ERR_TERRAIN_GRID_SHAPE"
		return failed
	if i0 < _min_i or j0 < _min_j or i0 > _max_i or j0 > _max_j or count_x - 1 > _max_i - i0 or count_z - 1 > _max_j - j0:
		failed.reason_code = "ERR_TERRAIN_OUT_OF_DOMAIN"
		return failed
	# Heights on the block plus a one-point halo clamped to the region; the
	# halo supplies the gradient stencil (GRADIENT_HALF_STEP_M = one lattice step).
	var hi0: int = maxi(i0 - 1, _min_i)
	var hj0: int = maxi(j0 - 1, _min_j)
	var hi1: int = mini(i0 + count_x, _max_i)
	var hj1: int = mini(j0 + count_z, _max_j)
	var width: int = hi1 - hi0 + 1
	var halo := PackedFloat64Array()
	halo.resize(width * (hj1 - hj0 + 1))
	for j in range(hj0, hj1 + 1):
		for i in range(hi0, hi1 + 1):
			halo[(j - hj0) * width + (i - hi0)] = _height(float(i * LATTICE_STEP_M), float(j * LATTICE_STEP_M))
	var heights := PackedFloat64Array()
	var gradients := PackedVector2Array()
	var normals := PackedVector3Array()
	heights.resize(count_x * count_z)
	gradients.resize(count_x * count_z)
	normals.resize(count_x * count_z)
	for j in range(j0, j0 + count_z):
		var j_lo: int = maxi(j - 1, _min_j)
		var j_hi: int = mini(j + 1, _max_j)
		for i in range(i0, i0 + count_x):
			var i_lo: int = maxi(i - 1, _min_i)
			var i_hi: int = mini(i + 1, _max_i)
			var row: int = (j - hj0) * width
			var gradient: Vector2 = gradient_from_samples(halo[row + i_lo - hi0], halo[row + i_hi - hi0], float(i_hi * LATTICE_STEP_M) - float(i_lo * LATTICE_STEP_M),
				halo[(j_lo - hj0) * width + i - hi0], halo[(j_hi - hj0) * width + i - hi0], float(j_hi * LATTICE_STEP_M) - float(j_lo * LATTICE_STEP_M))
			var k: int = (j - j0) * count_x + (i - i0)
			heights[k] = halo[row + i - hi0]
			gradients[k] = gradient
			normals[k] = normal_from_gradient(gradient)
	return {"is_valid": true, "heights_m": heights, "gradients": gradients, "normals": normals, "reason_code": ""}
