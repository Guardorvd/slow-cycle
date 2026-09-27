class_name ForkCorridorPreviewPlanner
extends RefCounted

## Deterministic, allocation-only preview of both 50m production fork arms.
const ArmGeometry = preload("res://scripts/world/fork_arm_geometry.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")

func evaluate_pair(
	fork_pos: Vector3, fork_tang: Vector3, fork_binorm: Vector3,
	fork_heading: float, fork_slope: float, left_style: int, right_style: int,
	terrain_carver: RefCounted
) -> Dictionary:
	var reasons: Array[String] = []
	var arms: Array[Dictionary] = []
	var signatures: Array[String] = []
	if left_style == right_style or not [1, 2].has(left_style) or not [1, 2].has(right_style):
		reasons.append("route_style_pair_invalid")
	if terrain_carver == null or not terrain_carver.has_method("evaluate_profile"):
		return {"eligible": false, "reason_codes": ["terrain_evaluator_unavailable"], "arms": [], "signature": ""}
	for branch_idx in range(2):
		var style: int = left_style if branch_idx == 0 else right_style
		var arm: Dictionary = ArmGeometry.build(fork_pos, fork_tang, fork_binorm, fork_heading, fork_slope, branch_idx, style)
		var arm_reasons: Array[String] = []
		var points: Array[Vector3] = arm.points
		var tangents: Array[Vector3] = arm.tangents
		var binormals: Array[Vector3] = arm.binormals
		var widths: Array[float] = arm.widths
		var max_gap: float = 0.0
		var expected_start: Vector3 = fork_pos + fork_binorm * (-0.9 if branch_idx == 0 else 0.9)
		if points.is_empty() or points[0].distance_to(expected_start) > 0.001:
			arm_reasons.append("fork_seam_position_invalid")
		elif tangents[0].dot(fork_tang.normalized()) < 0.999:
			arm_reasons.append("fork_seam_tangent_invalid")
		for i in range(points.size()):
			if not _finite_vector(points[i]) or not _finite_vector(tangents[i]) or not _finite_vector(binormals[i]):
				arm_reasons.append("non_finite_geometry")
				break
			if widths[i] < 1.30:
				arm_reasons.append("arm_too_narrow")
			if not Contract.is_slope_within_bounds(fork_slope):
				arm_reasons.append("grade_out_of_bounds")
			if absf(float(arm.curvature)) > Contract.MAX_CURVATURE + 0.0001:
				arm_reasons.append("curvature_out_of_bounds")
			if i > 0:
				var gap: float = points[i - 1].distance_to(points[i])
				max_gap = maxf(max_gap, gap)
				if gap <= 0.0 or gap > Contract.MAX_SAMPLE_SPACING:
					arm_reasons.append("sample_gap_exceeds_contract")
			var terrain: Dictionary = terrain_carver.evaluate_profile(points[i], binormals[i], float(arm.curvature))
			if not terrain.has("danger_left") or not terrain.has("danger_right"):
				arm_reasons.append("terrain_result_invalid")
				break
			if bool(terrain.danger_left) or bool(terrain.danger_right):
				arm_reasons.append("arm_corridor_terrain_danger")
		arm_reasons = _unique(arm_reasons)
		for reason: String in arm_reasons:
			reasons.append("left_%s" % reason if branch_idx == 0 else "right_%s" % reason)
		var signature_data: Array = []
		for i in range(points.size()):
			signature_data.append([roundi(points[i].x * 10000.0), roundi(points[i].y * 10000.0), roundi(points[i].z * 10000.0), roundi(widths[i] * 10000.0)])
		signatures.append(JSON.stringify([branch_idx, style, signature_data], "", false).sha256_text())
		arms.append({
			"branch_index": branch_idx, "route_style": style,
			"sample_count": points.size(), "length_m": _length(points),
			"width_start_m": widths[0], "width_end_m": widths[-1],
			"max_sample_gap_m": max_gap, "reason_codes": arm_reasons,
			"signature": signatures[-1]
		})
	if arms.size() == 2:
		var left_points: Array[Vector3] = ArmGeometry.build(fork_pos, fork_tang, fork_binorm, fork_heading, fork_slope, 0, left_style).points
		var right_points: Array[Vector3] = ArmGeometry.build(fork_pos, fork_tang, fork_binorm, fork_heading, fork_slope, 1, right_style).points
		var end_separation: float = left_points[-1].distance_to(right_points[-1])
		if end_separation < 8.0:
			reasons.append("paired_arm_separation_short")
		arms[0]["paired_end_separation_m"] = end_separation
		arms[1]["paired_end_separation_m"] = end_separation
	return {"eligible": reasons.is_empty(), "reason_codes": _unique(reasons), "arms": arms,
		"signature": JSON.stringify(signatures, "", false).sha256_text()}

func _length(points: Array[Vector3]) -> float:
	var total: float = 0.0
	for i in range(1, points.size()):
		total += points[i - 1].distance_to(points[i])
	return total

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if not result.has(value):
			result.append(value)
	return result
