class_name RoadPathData
extends RefCounted

## Pure data contract between RoadLogic, RoadChunk, Recovery, and DebugHUD.
## Does not hold any visual Nodes or physics colliders.

enum SegmentType {
	STRAIGHT = 0,
	GENTLE_ENTRY = 1,
	FULL_CURVE = 2,
	GENTLE_EXIT = 3,
	DESCENT = 4,
	MEADOW = 5,
	ROUGH_GRAVEL = 6,
	CRUISE_DOWNHILL = 7,
	FAST_GRAVITY_DESCENT = 8,
	BRAKING_ZONE = 9,
	SWITCHBACK = 10,
	CREST_MICRO_DROP = 11,
	AIRBORNE_DROP = 12,
	VALID_LANDING_SURFACE = 13,
	RECOVERY_FLAT = 14
}

const UNASSIGNED_BRANCH_ID: int = -1
const MAIN_BRANCH_ID: int = 0

enum AppendPolicy {
	DROP_DUPLICATE_ENDPOINT = 0, ## If other[0] == self[-1] within tolerance, drop other[0]
	KEEP_BOTH = 1,               ## Keep both points regardless
	REQUIRE_CONTINUITY = 2       ## Push error and reject if seam distance > tolerance
}

var points: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var binormals: PackedVector3Array = PackedVector3Array()
var cumulative_distances: PackedFloat32Array = PackedFloat32Array()
var slopes: PackedFloat32Array = PackedFloat32Array()
var curvatures: PackedFloat32Array = PackedFloat32Array()
var segment_types: PackedInt32Array = PackedInt32Array()
var surface_contact_states: PackedByteArray = PackedByteArray()
var banking_angles: PackedFloat32Array = PackedFloat32Array()
var sight_distances: PackedFloat32Array = PackedFloat32Array()
var road_widths: PackedFloat32Array = PackedFloat32Array()
var branch_id: int = MAIN_BRANCH_ID
var fork_node_id: int = -1
var parent_branch_id: int = UNASSIGNED_BRANCH_ID

func size() -> int:
	return points.size()

func get_total_distance() -> float:
	if cumulative_distances.is_empty():
		return 0.0
	return cumulative_distances[-1]

func append_sample(
	pos: Vector3,
	tang: Vector3,
	norm: Vector3,
	slope_deg: float,
	curv: float,
	seg_type: int,
	contact_state: int = 0,
	banking_deg: float = 0.0,
	sight_dist: float = 50.0,
	road_w: float = 1.8
) -> void:
	var norm_tangent: Vector3 = tang.normalized()
	var norm_normal: Vector3 = norm.normalized()
	var binorm: Vector3 = norm_tangent.cross(norm_normal).normalized()

	var dist: float = 0.0
	if not cumulative_distances.is_empty():
		var prev_pt: Vector3 = points[-1]
		dist = cumulative_distances[-1] + prev_pt.distance_to(pos)

	points.append(pos)
	tangents.append(norm_tangent)
	normals.append(norm_normal)
	binormals.append(binorm)
	cumulative_distances.append(dist)
	slopes.append(slope_deg)
	curvatures.append(curv)
	segment_types.append(seg_type)
	surface_contact_states.append(contact_state)
	banking_angles.append(banking_deg)
	sight_distances.append(sight_dist)
	road_widths.append(road_w)

## Prunes historical spline samples further than cutoff_distance behind the player.
## Returns number of pruned samples so callers can adjust cached indices.
func prune_behind(cutoff_distance: float) -> int:
	if cumulative_distances.size() < 100:
		return 0

	var prune_count: int = 0
	# Always keep at least 75 samples (~150m) in memory for smooth lookups and Recovery
	var max_prune: int = cumulative_distances.size() - 75
	while prune_count < max_prune and cumulative_distances[prune_count] < cutoff_distance:
		prune_count += 1

	if prune_count <= 0:
		return 0

	points = points.slice(prune_count)
	tangents = tangents.slice(prune_count)
	normals = normals.slice(prune_count)
	binormals = binormals.slice(prune_count)
	cumulative_distances = cumulative_distances.slice(prune_count)
	slopes = slopes.slice(prune_count)
	curvatures = curvatures.slice(prune_count)
	segment_types = segment_types.slice(prune_count)
	surface_contact_states = surface_contact_states.slice(prune_count)
	banking_angles = banking_angles.slice(prune_count)
	sight_distances = sight_distances.slice(prune_count)
	road_widths = road_widths.slice(prune_count)

	return prune_count

## Truncates all sample arrays to new_size (used for rejecting invalid candidate chunks)
func truncate_to(new_size: int) -> void:
	if new_size < 0:
		new_size = 0
	if points.size() <= new_size:
		return
	points = points.slice(0, new_size)
	tangents = tangents.slice(0, new_size)
	normals = normals.slice(0, new_size)
	binormals = binormals.slice(0, new_size)
	cumulative_distances = cumulative_distances.slice(0, new_size)
	slopes = slopes.slice(0, new_size)
	curvatures = curvatures.slice(0, new_size)
	segment_types = segment_types.slice(0, new_size)
	surface_contact_states = surface_contact_states.slice(0, new_size)
	banking_angles = banking_angles.slice(0, new_size)
	sight_distances = sight_distances.slice(0, new_size)
	road_widths = road_widths.slice(0, new_size)


## Finds the closest centerline sample index to a given world position
func find_closest_index(target_pos: Vector3, start_idx: int = 0) -> int:
	if points.is_empty():
		return -1

	var best_idx: int = clampi(start_idx, 0, points.size() - 1)
	var min_dist_sq: float = target_pos.distance_squared_to(points[best_idx])

	# Local search first around start_idx for fast streaming lookups
	var search_min: int = maxi(0, start_idx - 100)
	var search_max: int = mini(points.size() - 1, start_idx + 100)

	for i in range(search_min, search_max + 1):
		var d_sq: float = target_pos.distance_squared_to(points[i])
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			best_idx = i

	# Wrap-around search for closed-circuit tracks (when track start and end points coincide)
	if points.size() > 200 and points[0].distance_squared_to(points[-1]) < 0.04:
		if start_idx > points.size() - 100:
			var wrap_max: int = mini(100 - (points.size() - 1 - start_idx), points.size() - 1)
			for i in range(wrap_max + 1):
				var d_sq: float = target_pos.distance_squared_to(points[i])
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq
					best_idx = i
		elif start_idx < 100:
			var wrap_min: int = maxi(0, points.size() - (100 - start_idx))
			for i in range(wrap_min, points.size()):
				var d_sq: float = target_pos.distance_squared_to(points[i])
				if d_sq < min_dist_sq:
					min_dist_sq = d_sq
					best_idx = i

	# If local minimum is at window edge or too far, search full array
	var at_window_edge: bool = (best_idx == search_min and search_min > 0) or (best_idx == search_max and search_max < points.size() - 1)
	if min_dist_sq > 2500.0 or at_window_edge:
		for i in range(points.size()):
			var d_sq: float = target_pos.distance_squared_to(points[i])
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_idx = i

	return best_idx

## Returns interpolated point, tangent, and normal at distance s along the spline
func get_sample_at_distance(target_dist: float) -> Dictionary:
	if points.is_empty():
		return {"position": Vector3.ZERO, "tangent": Vector3.FORWARD, "normal": Vector3.UP, "slope": 0.0}

	if target_dist <= 0.0:
		return {
			"position": points[0],
			"tangent": tangents[0],
			"normal": normals[0],
			"slope": slopes[0]
		}

	var total_dist: float = get_total_distance()
	if target_dist >= total_dist:
		var last_idx: int = points.size() - 1
		return {
			"position": points[last_idx],
			"tangent": tangents[last_idx],
			"normal": normals[last_idx],
			"slope": slopes[last_idx]
		}

	# Binary search to find segment
	var low: int = 0
	var high: int = cumulative_distances.size() - 1
	while low <= high:
		var mid: int = (low + high) / 2
		if cumulative_distances[mid] < target_dist:
			low = mid + 1
		else:
			high = mid - 1

	var idx0: int = maxi(0, low - 1)
	var idx1: int = mini(points.size() - 1, low)
	if idx0 == idx1:
		return {
			"position": points[idx0],
			"tangent": tangents[idx0],
			"normal": normals[idx0],
			"slope": slopes[idx0]
		}

	var d0: float = cumulative_distances[idx0]
	var d1: float = cumulative_distances[idx1]
	var t: float = clampf((target_dist - d0) / maxf(0.0001, d1 - d0), 0.0, 1.0)

	var interp_pos: Vector3 = points[idx0].lerp(points[idx1], t)
	var interp_tang: Vector3 = tangents[idx0].slerp(tangents[idx1], t).normalized()
	var interp_norm: Vector3 = normals[idx0].slerp(normals[idx1], t).normalized()
	var interp_slope: float = lerpf(slopes[idx0], slopes[idx1], t)

	return {
		"position": interp_pos,
		"tangent": interp_tang,
		"normal": interp_norm,
		"slope": interp_slope
	}

## Extracts an independent deep-copy segment with local cumulative_distances starting strictly at 0.0.
func slice_segment(start_idx: int, end_idx: int) -> RefCounted:
	var result = get_script().new()
	result.branch_id = branch_id
	result.fork_node_id = fork_node_id
	result.parent_branch_id = parent_branch_id

	if points.is_empty() or start_idx > end_idx or start_idx < 0:
		return result

	var s_min: int = clampi(start_idx, 0, points.size() - 1)
	var s_max: int = clampi(end_idx, 0, points.size() - 1)
	var count: int = s_max - s_min + 1

	result.points = points.slice(s_min, s_max + 1)
	result.tangents = tangents.slice(s_min, s_max + 1)
	result.normals = normals.slice(s_min, s_max + 1)
	result.binormals = binormals.slice(s_min, s_max + 1)
	result.slopes = slopes.slice(s_min, s_max + 1)
	result.curvatures = curvatures.slice(s_min, s_max + 1)
	result.segment_types = segment_types.slice(s_min, s_max + 1)
	result.surface_contact_states = surface_contact_states.slice(s_min, s_max + 1)
	result.banking_angles = banking_angles.slice(s_min, s_max + 1)
	result.sight_distances = sight_distances.slice(s_min, s_max + 1)
	result.road_widths = road_widths.slice(s_min, s_max + 1)

	# Local cumulative distances recalculation starting strictly at 0.0
	result.cumulative_distances.resize(count)
	result.cumulative_distances[0] = 0.0
	for i in range(1, count):
		result.cumulative_distances[i] = result.cumulative_distances[i - 1] + result.points[i - 1].distance_to(result.points[i])

	return result

## Appends another RoadPathData segment with duplicate seam protection
func append_path_data(other: RefCounted, policy: int = AppendPolicy.DROP_DUPLICATE_ENDPOINT) -> void:
	if other == null or other.points.is_empty():
		return

	if points.is_empty():
		points = other.points.duplicate()
		tangents = other.tangents.duplicate()
		normals = other.normals.duplicate()
		binormals = other.binormals.duplicate()
		cumulative_distances = other.cumulative_distances.duplicate()
		slopes = other.slopes.duplicate()
		curvatures = other.curvatures.duplicate()
		segment_types = other.segment_types.duplicate()
		surface_contact_states = other.surface_contact_states.duplicate()
		banking_angles = other.banking_angles.duplicate()
		sight_distances = other.sight_distances.duplicate()
		road_widths = other.road_widths.duplicate()
		return

	var seam_dist: float = points[-1].distance_to(other.points[0])
	var start_src: int = 0

	if policy == AppendPolicy.REQUIRE_CONTINUITY and seam_dist > 0.001:
		push_error("RoadPathData.append_path_data: seam discontinuity %.4f m > 0.001 m!" % seam_dist)
		return

	if policy == AppendPolicy.DROP_DUPLICATE_ENDPOINT and seam_dist <= 0.001:
		start_src = 1 # Skip first sample to prevent duplicate 0-distance vertex

	for i in range(start_src, other.points.size()):
		var rw: float = other.road_widths[i] if i < other.road_widths.size() else 1.8
		append_sample(
			other.points[i],
			other.tangents[i],
			other.normals[i],
			other.slopes[i],
			other.curvatures[i],
			other.segment_types[i],
			other.surface_contact_states[i],
			other.banking_angles[i],
			other.sight_distances[i],
			rw
		)

## Complete deep-copy of all 11 PackedArrays and metadata
func clone() -> RefCounted:
	var c = get_script().new()
	c.branch_id = branch_id
	c.fork_node_id = fork_node_id
	c.parent_branch_id = parent_branch_id
	c.points = points.duplicate()
	c.tangents = tangents.duplicate()
	c.normals = normals.duplicate()
	c.binormals = binormals.duplicate()
	c.cumulative_distances = cumulative_distances.duplicate()
	c.slopes = slopes.duplicate()
	c.curvatures = curvatures.duplicate()
	c.segment_types = segment_types.duplicate()
	c.surface_contact_states = surface_contact_states.duplicate()
	c.banking_angles = banking_angles.duplicate()
	c.sight_distances = sight_distances.duplicate()
	c.road_widths = road_widths.duplicate()
	return c

## Validates C0 position and C1 tangent continuity between the end of this path and start of next_path
func validate_continuity_with(next_path: RefCounted, tol_p: float = 0.001, tol_deg: float = 0.2) -> Dictionary:
	var res := {
		"is_continuous": true,
		"pos_error_m": 0.0,
		"tangent_angle_deg": 0.0,
		"normal_angle_deg": 0.0,
		"error_message": ""
	}

	if points.is_empty() or next_path == null or next_path.points.is_empty():
		res["is_continuous"] = false
		res["error_message"] = "Empty path segment in continuity check"
		return res

	var p_last: Vector3 = points[-1]
	var p_first: Vector3 = next_path.points[0]
	var p_dist: float = p_last.distance_to(p_first)
	res["pos_error_m"] = p_dist

	var t_last: Vector3 = tangents[-1].normalized()
	var t_first: Vector3 = next_path.tangents[0].normalized()
	var dot_t: float = clampf(t_last.dot(t_first), -1.0, 1.0)
	var t_angle_deg: float = rad_to_deg(acos(dot_t))
	res["tangent_angle_deg"] = t_angle_deg

	var n_last: Vector3 = normals[-1].normalized()
	var n_first: Vector3 = next_path.normals[0].normalized()
	var dot_n: float = clampf(n_last.dot(n_first), -1.0, 1.0)
	var n_angle_deg: float = rad_to_deg(acos(dot_n))
	res["normal_angle_deg"] = n_angle_deg

	if p_dist > tol_p:
		res["is_continuous"] = false
		res["error_message"] = "C0 position error: %.4f m > tolerance %.4f m" % [p_dist, tol_p]
	elif t_angle_deg > tol_deg:
		res["is_continuous"] = false
		res["error_message"] = "C1 tangent angle deviation: %.2f deg > tolerance %.2f deg" % [t_angle_deg, tol_deg]

	return res
