class_name ForkArmGeometry
extends RefCounted

## Pure shared source for the first 50m of both fork arms.
const RoadMath = preload("res://scripts/world/road_math.gd")

static func build(
	fork_pos: Vector3, fork_tang: Vector3, fork_binorm: Vector3,
	fork_heading: float, fork_slope: float, branch_idx: int, route_style: int,
	samples_count: int = 25, step_len: float = 2.0
) -> Dictionary:
	var points: Array[Vector3] = []
	var tangents: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var binormals: Array[Vector3] = []
	var widths: Array[float] = []
	var inner_edge: Array[Vector3] = []
	var angle_magnitude: float = 5.0 if route_style == 1 else 10.0
	var div_angle_deg: float = angle_magnitude if branch_idx == 0 else -angle_magnitude
	var w_start: float = 1.8
	var w_end: float = 1.6 if route_style == 1 else 1.35
	var curr_pos: Vector3 = fork_pos + fork_binorm * (-w_start * 0.5 if branch_idx == 0 else w_start * 0.5)
	var prev_pos: Vector3 = curr_pos
	var prev_tang: Vector3 = fork_tang
	for i in range(samples_count + 1):
		var t_norm: float = float(i) / float(samples_count)
		var curve_factor: float = smoothstep(0.0, 0.70, t_norm)
		var curr_heading: float = fork_heading + div_angle_deg * curve_factor
		var curr_w: float = lerpf(w_start, w_end, smoothstep(0.0, 1.0, t_norm))
		var h_rad: float = deg_to_rad(curr_heading)
		var s_rad: float = deg_to_rad(fork_slope)
		var curr_tang := Vector3(sin(h_rad) * cos(s_rad), sin(s_rad), cos(h_rad) * cos(s_rad)).normalized()
		var curr_norm: Vector3 = RoadMath.compute_ortho_normal(curr_tang, 0.0)
		var curr_binorm: Vector3 = curr_tang.cross(curr_norm).normalized()
		if i > 0:
			curr_pos = prev_pos + (prev_tang + curr_tang).normalized() * step_len
		prev_pos = curr_pos
		prev_tang = curr_tang
		points.append(curr_pos)
		tangents.append(curr_tang)
		normals.append(curr_norm)
		binormals.append(curr_binorm)
		widths.append(curr_w)
		inner_edge.append(curr_pos + curr_binorm * (curr_w * 0.5 if branch_idx == 0 else -curr_w * 0.5))
	return {
		"points": points, "tangents": tangents, "normals": normals,
		"binormals": binormals, "widths": widths, "inner_edge": inner_edge,
		"heading_end": fork_heading + div_angle_deg,
		"slope": fork_slope, "curvature": deg_to_rad(absf(div_angle_deg)) / 50.0,
		"divergence_deg": div_angle_deg
	}
