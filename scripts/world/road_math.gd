class_name RoadMath
extends RefCounted

## Mathematical utilities for Hermite splines, Frenet frames, and cross-section extrusion.

static func cubic_hermite_position(p0: Vector3, t0: Vector3, p1: Vector3, t1: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10: float = t3 - 2.0 * t2 + t
	var h01: float = -2.0 * t3 + 3.0 * t2
	var h11: float = t3 - t2
	return h00 * p0 + h10 * t0 + h01 * p1 + h11 * t1

static func cubic_hermite_tangent(p0: Vector3, t0: Vector3, p1: Vector3, t1: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var dh00: float = 6.0 * t2 - 6.0 * t
	var dh10: float = 3.0 * t2 - 4.0 * t + 1.0
	var dh01: float = -6.0 * t2 + 6.0 * t
	var dh11: float = 3.0 * t2 - 2.0 * t
	return (dh00 * p0 + dh10 * t0 + dh01 * p1 + dh11 * t1).normalized()

## Computes curvature radius in horizontal XZ plane
static func compute_horizontal_radius(tangent_start: Vector3, tangent_end: Vector3, arc_len: float) -> float:
	var t0_2d: Vector2 = Vector2(tangent_start.x, tangent_start.z).normalized()
	var t1_2d: Vector2 = Vector2(tangent_end.x, tangent_end.z).normalized()
	var angle_delta: float = absf(t0_2d.angle_to(t1_2d))
	if angle_delta < 0.0001:
		return 9999.0 # Effectively straight line
	return arc_len / angle_delta

const Contract = preload("res://scripts/world/road_generation_contract.gd")

## Clamps slope angle in degrees within safe envelope [-14.0, +5.0]
static func clamp_slope_deg(slope_deg: float) -> float:
	return clampf(slope_deg, Contract.MAX_GRADE_DOWNHILL, Contract.MAX_GRADE_UPHILL)

## Computes orthonormal normal vector for a tangent, optionally tilted by banking angle
static func compute_ortho_normal(tangent: Vector3, bank_deg: float = 0.0) -> Vector3:
	var t: Vector3 = tangent.normalized()
	var bitangent: Vector3 = Vector3(-t.z, 0.0, t.x).normalized()
	if bitangent.is_zero_approx():
		bitangent = Vector3.RIGHT
	var base_norm: Vector3 = bitangent.cross(t).normalized()
	if absf(bank_deg) > 0.001:
		var bank_rad: float = deg_to_rad(bank_deg)
		# Rotate normal around tangent vector
		return base_norm.rotated(t, bank_rad).normalized()
	return base_norm

## Computes continuous road width approaching and through a fork using C1 smoothstep expansion.
## s_rel: longitudinal distance relative to fork point (negative approaching, 0 at fork).
## When s_rel <= -approach_len: returns standard width (4.0m).
## When s_rel >= 0.0: returns expanded width (10.0m).
static func compute_fork_width(
	s_rel: float,
	approach_len: float = 25.0,
	w_std: float = 4.0,
	w_exp: float = 10.0
) -> float:
	if s_rel <= -approach_len:
		return w_std
	if s_rel >= 0.0:
		return w_exp
	var t: float = clampf((s_rel + approach_len) / maxf(0.0001, approach_len), 0.0, 1.0)
	return w_std + (w_exp - w_std) * smoothstep(0.0, 1.0, t)

## Computes branch centerline lateral offset along a smooth transition curve past the fork point.
## s_past_fork: longitudinal distance past the fork point (>= 0).
## Returns lateral offset magnitude (meters) from the approach centerline.
static func compute_fork_branch_center_offset(
	s_past_fork: float,
	div_len: float = 15.0,
	max_offset: float = 2.5
) -> float:
	if s_past_fork <= 0.0:
		return 0.0
	if s_past_fork >= div_len:
		return max_offset
	var t: float = clampf(s_past_fork / maxf(0.0001, div_len), 0.0, 1.0)
	return max_offset * smoothstep(0.0, 1.0, t)

