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

## Clamps slope angle in degrees within safe envelope [-6.5, +5.5]
static func clamp_slope_deg(slope_deg: float) -> float:
	return clampf(slope_deg, -6.5, 5.5)
