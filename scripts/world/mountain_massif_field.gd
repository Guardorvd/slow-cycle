class_name MountainMassifField
extends RefCounted

## Slow Cycle — Mountain Massif Field (Layer 0)
## Continuous 2D terrain heightfield H(x, z) and analytical gradient ∇H(x, z).
## Synthesizes glacial U-shaped mountain valleys, sharp arêtes, and rock benches
## via Domain-Warped Ridged Multifractal noise.
## 100% deterministic by seed. Zero external dependencies.

const BASE_DESCENT_RATE: float = -0.080 # General mountain descent rate along primary axis (-Z)
const VALLEY_WIDTH: float = 85.0 # Half-width of primary valley floor
const WALL_STEEPNESS: float = 0.38 # Slope of mountain wall rising away from valley axis

var world_seed: int = 184729

var _warp_noise_x: FastNoiseLite
var _warp_noise_z: FastNoiseLite
var _ridge_noise_1: FastNoiseLite
var _ridge_noise_2: FastNoiseLite
var _valley_axis_noise: FastNoiseLite
var _detail_noise: FastNoiseLite

func _init(seed_val: int = 184729) -> void:
	world_seed = seed_val

	_warp_noise_x = FastNoiseLite.new()
	_warp_noise_x.seed = seed_val + 201
	_warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_noise_x.frequency = 0.0035

	_warp_noise_z = FastNoiseLite.new()
	_warp_noise_z.seed = seed_val + 301
	_warp_noise_z.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp_noise_z.frequency = 0.0035

	_valley_axis_noise = FastNoiseLite.new()
	_valley_axis_noise.seed = seed_val + 401
	_valley_axis_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_valley_axis_noise.frequency = 0.0018

	_ridge_noise_1 = FastNoiseLite.new()
	_ridge_noise_1.seed = seed_val + 501
	_ridge_noise_1.noise_type = FastNoiseLite.TYPE_PERLIN
	_ridge_noise_1.frequency = 0.004

	_ridge_noise_2 = FastNoiseLite.new()
	_ridge_noise_2.seed = seed_val + 601
	_ridge_noise_2.noise_type = FastNoiseLite.TYPE_PERLIN
	_ridge_noise_2.frequency = 0.009

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = seed_val + 701
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.frequency = 0.022

## Returns continuous terrain height H(wx, wz) in meters.
## Combines primary valley descent, glacial trough sidewalls, and domain-warped ridged spurs.
func get_elevation(wx: float, wz: float) -> float:
	# 1. Primary macro descent along -Z (wz is negative as road proceeds downhill)
	# wz * BASE_DESCENT_RATE produces positive elevation drop as wz becomes negative
	var base_elev: float = -wz * BASE_DESCENT_RATE

	# 2. Valley meander axis: center of glacial trough shifts gently with distance
	var valley_center_x: float = _valley_axis_noise.get_noise_1d(wz) * 110.0

	# 3. Domain warping for natural geological folding
	var warp_x: float = _warp_noise_x.get_noise_2d(wx, wz) * 45.0
	var warp_z: float = _warp_noise_z.get_noise_2d(wx, wz) * 45.0
	var qx: float = wx + warp_x
	var qz: float = wz + warp_z

	# 4. Glacial U-shaped valley profile relative to meander axis
	var dx: float = qx - valley_center_x
	var abs_dx: float = absf(dx)
	var valley_wall_elev: float = 0.0
	if abs_dx > VALLEY_WIDTH:
		var dist_up_wall: float = abs_dx - VALLEY_WIDTH
		# Smooth cubic transition onto steep rock wall
		valley_wall_elev = dist_up_wall * WALL_STEEPNESS + (dist_up_wall * dist_up_wall * 0.0015)
	else:
		# Floor of valley: gently rounded swale
		var norm_f: float = abs_dx / VALLEY_WIDTH
		valley_wall_elev = norm_f * norm_f * 4.5

	# 5. Ridged Multifractal rock spurs: 1.0 - 2.0 * |noise| creates sharp crests and chutes
	var n_ridge1: float = absf(_ridge_noise_1.get_noise_2d(qx, qz))
	var ridge_val1: float = (1.0 - n_ridge1 * 2.0) * 18.0

	var n_ridge2: float = absf(_ridge_noise_2.get_noise_2d(qx * 1.5, qz * 1.5))
	var ridge_val2: float = (1.0 - n_ridge2 * 2.0) * 7.5

	# 6. High-frequency rock outcrop relief
	var detail_val: float = _detail_noise.get_noise_2d(wx, wz) * 3.2

	return base_elev + valley_wall_elev + ridge_val1 + ridge_val2 + detail_val

## Returns 2D gradient vector ∇H = (dH/dx, dH/dz) via central finite differences.
func get_gradient(wx: float, wz: float, eps: float = 0.5) -> Vector2:
	var h_xp: float = get_elevation(wx + eps, wz)
	var h_xm: float = get_elevation(wx - eps, wz)
	var h_zp: float = get_elevation(wx, wz + eps)
	var h_zm: float = get_elevation(wx, wz - eps)

	var inv_2eps: float = 0.5 / eps
	return Vector2(
		(h_xp - h_xm) * inv_2eps,
		(h_zp - h_zm) * inv_2eps
	)

## Returns normalized direction vector of steepest descent in horizontal XZ plane.
func get_fall_line(wx: float, wz: float) -> Vector2:
	var grad: Vector2 = get_gradient(wx, wz)
	var len_sq: float = grad.length_squared()
	if len_sq < 0.000001:
		return Vector2(0.0, -1.0) # Default downhill towards -Z
	return -grad.normalized()

## Returns normalized contour tangent vector (along mountain level curve, perpendicular to gradient).
func get_contour_direction(wx: float, wz: float) -> Vector2:
	var grad: Vector2 = get_gradient(wx, wz)
	if grad.is_zero_approx():
		return Vector2(1.0, 0.0)
	# Perpendicular to gradient: (-dz, dx)
	return Vector2(-grad.y, grad.x).normalized()

## Returns terrain surface slope in degrees at world coordinates.
func get_steepness_deg(wx: float, wz: float) -> float:
	var grad: Vector2 = get_gradient(wx, wz)
	return rad_to_deg(atan(grad.length()))
