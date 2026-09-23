class_name RoadLogic
extends RefCounted

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadMath = preload("res://scripts/world/road_math.gd")

const MIN_RADIUS: float = 38.0 ## Minimum radius of curvature in meters
const MAX_DOWNHILL_SLOPE: float = -6.0 ## Maximum downhill angle in degrees
const MAX_UPHILL_SLOPE: float = 5.0 ## Maximum uphill angle in degrees
const CHUNK_LENGTH: float = 50.0 ## Length in meters per chunk
const SAMPLES_PER_CHUNK: int = 25 ## 2.0m resolution per sample

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var road_path: RefCounted

# Generator state tracking
var last_point: Vector3 = Vector3.ZERO
var last_tangent: Vector3 = Vector3(0, 0, -1) # Heading negative Z
var last_normal: Vector3 = Vector3.UP
var current_heading_deg: float = 180.0 # Degrees in XZ plane (180 = -Z)
var current_slope_deg: float = 0.0
var current_curve_dir: float = 1.0 # Consistent sign for ENTRY -> FULL -> EXIT

var segment_queue: Array[int] = []
var chunks_generated: int = 0

func _init(seed_val: int, path_data: RefCounted) -> void:
	rng.seed = seed_val
	road_path = path_data
	_initialize_start()

func _initialize_start() -> void:
	last_point = Vector3(0, 3.5, 0)
	last_tangent = Vector3(0, 0, -1)
	last_normal = Vector3.UP
	current_heading_deg = 180.0
	current_slope_deg = 0.0
	current_curve_dir = 1.0
	
	# Add initial baseline point
	road_path.append_sample(last_point, last_tangent, last_normal, 0.0, 0.0, RoadPathDataClass.SegmentType.STRAIGHT)
	
	# Pre-seed initial relaxing straightaway
	segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)
	segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)
	segment_queue.append(RoadPathDataClass.SegmentType.DESCENT)
	segment_queue.append(RoadPathDataClass.SegmentType.MEADOW)

func plan_next_chunk() -> void:
	if segment_queue.is_empty():
		_replenish_rhythm_queue()

	var seg_type: int = segment_queue.pop_front()
	_generate_chunk_geometry(seg_type)
	chunks_generated += 1

func _replenish_rhythm_queue() -> void:
	var roll: float = rng.randf()
	if roll < 0.30:
		segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)
		segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)
	elif roll < 0.60:
		current_curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
		segment_queue.append(RoadPathDataClass.SegmentType.GENTLE_ENTRY)
		segment_queue.append(RoadPathDataClass.SegmentType.FULL_CURVE)
		segment_queue.append(RoadPathDataClass.SegmentType.GENTLE_EXIT)
	elif roll < 0.75:
		segment_queue.append(RoadPathDataClass.SegmentType.DESCENT)
		segment_queue.append(RoadPathDataClass.SegmentType.DESCENT)
		segment_queue.append(RoadPathDataClass.SegmentType.MEADOW)
	elif roll < 0.88:
		# Rough gravel sector: rough washboard transition
		segment_queue.append(RoadPathDataClass.SegmentType.ROUGH_GRAVEL)
		segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)
	else:
		current_curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
		segment_queue.append(RoadPathDataClass.SegmentType.GENTLE_ENTRY)
		segment_queue.append(RoadPathDataClass.SegmentType.FULL_CURVE)
		segment_queue.append(RoadPathDataClass.SegmentType.GENTLE_EXIT)
		segment_queue.append(RoadPathDataClass.SegmentType.STRAIGHT)

func _generate_chunk_geometry(seg_type: int) -> void:
	var target_yaw_change: float = 0.0
	var target_slope: float = 0.0

	match seg_type:
		RoadPathDataClass.SegmentType.STRAIGHT:
			target_yaw_change = rng.randf_range(-3.0, 3.0)
			target_slope = rng.randf_range(-1.5, 1.0)
		RoadPathDataClass.SegmentType.GENTLE_ENTRY:
			target_yaw_change = current_curve_dir * rng.randf_range(6.0, 11.0)
			target_slope = rng.randf_range(-2.0, 0.5)
		RoadPathDataClass.SegmentType.FULL_CURVE:
			target_yaw_change = current_curve_dir * rng.randf_range(14.0, 22.0)
			target_slope = rng.randf_range(-2.5, 1.0)
		RoadPathDataClass.SegmentType.GENTLE_EXIT:
			target_yaw_change = current_curve_dir * rng.randf_range(4.0, 8.0)
			target_slope = rng.randf_range(-1.0, 1.0)
		RoadPathDataClass.SegmentType.DESCENT:
			target_yaw_change = rng.randf_range(-6.0, 6.0)
			target_slope = rng.randf_range(-5.5, -3.8)
		RoadPathDataClass.SegmentType.MEADOW:
			target_yaw_change = rng.randf_range(-4.0, 4.0)
			target_slope = rng.randf_range(-0.5, 1.5)
		RoadPathDataClass.SegmentType.ROUGH_GRAVEL:
			target_yaw_change = rng.randf_range(-4.0, 4.0)
			target_slope = rng.randf_range(-2.0, 1.0)

	# Pre-validation clamp: max 26 deg per 50m guarantees radius >= 38.0m (typically >= 100m)
	target_yaw_change = clampf(target_yaw_change, -26.0, 26.0)
	target_slope = clampf(target_slope, MAX_DOWNHILL_SLOPE, MAX_UPHILL_SLOPE)

	current_heading_deg += target_yaw_change
	current_slope_deg = lerpf(current_slope_deg, target_slope, 0.6)
	current_slope_deg = RoadMath.clamp_slope_deg(current_slope_deg)

	var heading_rad: float = deg_to_rad(current_heading_deg)
	var slope_rad: float = deg_to_rad(current_slope_deg)

	var end_tangent: Vector3 = Vector3(
		sin(heading_rad) * cos(slope_rad),
		sin(slope_rad),
		cos(heading_rad) * cos(slope_rad)
	).normalized()

	var horiz_chord := Vector2(last_tangent.x + end_tangent.x, last_tangent.z + end_tangent.z).normalized()
	var horiz_len: float = CHUNK_LENGTH * cos(slope_rad)
	var height_gain: float = sin(slope_rad) * CHUNK_LENGTH
	var end_point: Vector3 = last_point + Vector3(horiz_chord.x * horiz_len, height_gain, horiz_chord.y * horiz_len)

	var h_t0: Vector3 = last_tangent * CHUNK_LENGTH
	var h_t1: Vector3 = end_tangent * CHUNK_LENGTH

	var start_p: Vector3 = last_point
	var prev_sample_tang: Vector3 = last_tangent
	var sample_step_len: float = CHUNK_LENGTH / float(SAMPLES_PER_CHUNK)

	for i in range(1, SAMPLES_PER_CHUNK + 1):
		var t: float = float(i) / float(SAMPLES_PER_CHUNK)
		var pt: Vector3 = RoadMath.cubic_hermite_position(start_p, h_t0, end_point, h_t1, t)
		var tang: Vector3 = RoadMath.cubic_hermite_tangent(start_p, h_t0, end_point, h_t1, t)
		
		# Compute horizontal curvature radius between adjacent 2m samples
		var radius: float = RoadMath.compute_horizontal_radius(prev_sample_tang, tang, sample_step_len)
		if radius < MIN_RADIUS:
			radius = MIN_RADIUS
		var curvature: float = 1.0 / maxf(radius, 0.001)
		
		# Compute orthonormal road normal
		var bitangent: Vector3 = Vector3(-tang.z, 0.0, tang.x).normalized()
		var norm: Vector3 = bitangent.cross(tang).normalized()
		
		# Record actual geometric slope from unit tangent vertical component
		var actual_geom_slope_deg: float = rad_to_deg(asin(clampf(tang.y, -0.999, 0.999)))
		
		road_path.append_sample(pt, tang, norm, actual_geom_slope_deg, curvature, seg_type)
		prev_sample_tang = tang

	last_point = end_point
	last_tangent = end_tangent
	var end_bitang: Vector3 = Vector3(-end_tangent.z, 0.0, end_tangent.x).normalized()
	last_normal = end_bitang.cross(end_tangent).normalized()

