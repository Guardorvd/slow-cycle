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
	MEADOW = 5
}

var points: PackedVector3Array = PackedVector3Array()
var tangents: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var binormals: PackedVector3Array = PackedVector3Array()
var cumulative_distances: PackedFloat32Array = PackedFloat32Array()
var slopes: PackedFloat32Array = PackedFloat32Array()
var curvatures: PackedFloat32Array = PackedFloat32Array()
var segment_types: PackedInt32Array = PackedInt32Array()

func size() -> int:
	return points.size()

func get_total_distance() -> float:
	if cumulative_distances.is_empty():
		return 0.0
	return cumulative_distances[-1]

func append_sample(pos: Vector3, tang: Vector3, norm: Vector3, slope_deg: float, curv: float, seg_type: int) -> void:
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

	return prune_count


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

	# If too far from local window, search full array
	if min_dist_sq > 2500.0: # > 50m
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
