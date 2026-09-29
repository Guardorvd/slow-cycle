class_name ForkSitePlanner
extends RefCounted

## Pure, deterministic preflight for a fork at the currently generated path endpoint.

const Contract = preload("res://scripts/world/road_generation_contract.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const MountainProfile = preload("res://scripts/world/mountain_profile.gd")
const LOOKBACK_METERS: float = 25.0

var mountain_weight: float = 0.0
var biome_zone: int = MountainProfile.BiomeZone.FOREST

func set_mountain_weight(weight: float) -> void:
	mountain_weight = clampf(weight, 0.0, 1.0)
	if mountain_weight > 0.65:
		biome_zone = MountainProfile.BiomeZone.MOUNTAIN
	elif mountain_weight < 0.35:
		biome_zone = MountainProfile.BiomeZone.FOREST
	else:
		biome_zone = MountainProfile.BiomeZone.TRANSITION

func set_biome_zone(zone: int) -> void:
	biome_zone = zone
	if biome_zone == MountainProfile.BiomeZone.MOUNTAIN:
		mountain_weight = 1.0
	elif biome_zone == MountainProfile.BiomeZone.FOREST:
		mountain_weight = 0.0
	else:
		mountain_weight = 0.5

func _is_terrain_safe_for_fork(zone: int, danger_left: bool, danger_right: bool) -> bool:
	if danger_left and danger_right:
		return false
	if not danger_left and not danger_right:
		return true
	if zone == MountainProfile.BiomeZone.MOUNTAIN:
		return true
	return false

func evaluate_site(
	path: RefCounted,
	candidate_idx: int,
	last_chunk_passed: bool,
	terrain_carver: RefCounted,
	planned_sight_distance_m: float
) -> Dictionary:
	var reasons: Array[String] = []
	var metrics: Dictionary = {
		"candidate_idx": candidate_idx,
		"lookback_m": 0.0,
		"min_width_m": INF,
		"min_slope_deg": INF,
		"max_slope_deg": -INF,
		"max_abs_curvature": 0.0,
		"max_sample_gap_m": 0.0,
		"contact_modes": [],
		"left_profile": -1,
		"right_profile": -1,
		"danger_left": false,
		"danger_right": false,
		"planned_sight_distance_m": planned_sight_distance_m,
	}
	if path == null or not path.has_method("size") or path.size() < 2:
		reasons.append("path_unavailable")
		return _result(false, reasons, metrics)
	if candidate_idx < 1 or candidate_idx >= path.size():
		reasons.append("candidate_index_invalid")
		return _result(false, reasons, metrics)
	if not last_chunk_passed:
		reasons.append("previous_chunk_invalid")
	if not is_finite(planned_sight_distance_m) or planned_sight_distance_m < Contract.TURN_SIGHT_DISTANCE_40KMH:
		reasons.append("planned_approach_sight_short")
	if terrain_carver == null or not terrain_carver.has_method("evaluate_profile"):
		reasons.append("terrain_evaluator_unavailable")

	var required_arrays: Array[String] = [
		"points", "binormals", "cumulative_distances", "slopes", "curvatures",
		"surface_contact_states", "road_widths"
	]
	for property_name in required_arrays:
		var values: Variant = path.get(property_name)
		if values == null or values.size() != path.size():
			reasons.append("path_arrays_incomplete")
			return _result(false, _unique(reasons), metrics)

	var distances: PackedFloat32Array = path.cumulative_distances
	var candidate_s: float = distances[candidate_idx]
	if not is_finite(candidate_s):
		reasons.append("non_finite_path_sample")
		return _result(false, _unique(reasons), metrics)
	var start_idx: int = candidate_idx
	while start_idx > 0 and candidate_s - distances[start_idx - 1] <= LOOKBACK_METERS:
		start_idx -= 1
	metrics.lookback_m = candidate_s - distances[start_idx]
	if metrics.lookback_m < LOOKBACK_METERS - Contract.MAX_SAMPLE_SPACING:
		reasons.append("lookback_too_short")
	if candidate_idx > start_idx and metrics.lookback_m / float(candidate_idx - start_idx) > Contract.MAX_SAMPLE_SPACING:
		reasons.append("sample_gap_exceeds_contract")

	var contacts: Array[int] = []
	for idx in range(start_idx, candidate_idx + 1):
		var pos: Vector3 = path.points[idx]
		var binorm: Vector3 = path.binormals[idx]
		var sample_s: float = distances[idx]
		var slope: float = path.slopes[idx]
		var curvature: float = path.curvatures[idx]
		var width: float = path.road_widths[idx]
		var contact: int = int(path.surface_contact_states[idx])
		if not _finite_vector(pos) or not _finite_vector(binorm) or not is_finite(sample_s) or not is_finite(slope) or not is_finite(curvature) or not is_finite(width):
			reasons.append("non_finite_path_sample")
			break
		metrics.min_width_m = minf(metrics.min_width_m, width)
		metrics.min_slope_deg = minf(metrics.min_slope_deg, slope)
		metrics.max_slope_deg = maxf(metrics.max_slope_deg, slope)
		metrics.max_abs_curvature = maxf(metrics.max_abs_curvature, absf(curvature))
		if width < Contract.ROAD_MIN_SINGLETRACK_WIDTH - 0.01:
			reasons.append("road_too_narrow")
		if not Contract.is_slope_within_bounds(slope):
			reasons.append("grade_out_of_bounds")
		if absf(curvature) > Contract.MAX_CURVATURE + 0.0001:
			reasons.append("curvature_out_of_bounds")
		if contact != Airborne.SurfaceContactMode.GROUNDED:
			reasons.append("approach_not_grounded")
			contacts.append(contact)
		if idx > start_idx:
			var gap: float = distances[idx] - distances[idx - 1]
			metrics.max_sample_gap_m = maxf(metrics.max_sample_gap_m, gap)
			if gap <= 0.0 or gap > Contract.MAX_SAMPLE_SPACING:
				reasons.append("sample_gap_exceeds_contract")
	metrics.contact_modes = contacts
	if metrics.min_width_m == INF:
		metrics.min_width_m = 0.0
	if metrics.min_slope_deg == INF:
		metrics.min_slope_deg = 0.0
	if metrics.max_slope_deg == -INF:
		metrics.max_slope_deg = 0.0

	if terrain_carver != null and terrain_carver.has_method("evaluate_profile"):
		var terrain: Dictionary = terrain_carver.evaluate_profile(
			path.points[candidate_idx], path.binormals[candidate_idx], path.curvatures[candidate_idx]
		)
		if not terrain.has("left_profile") or not terrain.has("right_profile") or not terrain.has("danger_left") or not terrain.has("danger_right"):
			reasons.append("terrain_result_invalid")
			return _result(false, _unique(reasons), metrics)
		metrics.left_profile = int(terrain.get("left_profile", -1))
		metrics.right_profile = int(terrain.get("right_profile", -1))
		metrics.danger_left = bool(terrain.get("danger_left", false))
		metrics.danger_right = bool(terrain.get("danger_right", false))
		metrics.mountain_weight = mountain_weight
		metrics.biome_zone = biome_zone
		if not _is_terrain_safe_for_fork(biome_zone, metrics.danger_left, metrics.danger_right):
			if metrics.danger_left and metrics.danger_right:
				reasons.append("dual_fork_corridor_danger")
				reasons.append("left_fork_corridor_danger")
				reasons.append("right_fork_corridor_danger")
			elif metrics.danger_left:
				reasons.append("left_fork_corridor_danger")
			elif metrics.danger_right:
				reasons.append("right_fork_corridor_danger")

	return _result(reasons.is_empty(), _unique(reasons), metrics)

func _result(eligible: bool, reasons: Array[String], metrics: Dictionary) -> Dictionary:
	return {"eligible": eligible, "reason_codes": reasons, "metrics": metrics}

func _unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
