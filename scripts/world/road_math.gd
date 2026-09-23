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
