class_name RoadValidityValidator
extends RefCounted

## Slow Cycle — Road Validity Validator (v5.1.0)
## Pure algorithmic validator that verifies road splines, gradients, curvature derivatives,
## seam continuity (C0/C1), sight distances, and airborne/landing state transitions
## against RoadGenerationContract and RoadAirborneContract.

const Contract = preload("res://scripts/world/road_generation_contract.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

enum SegmentStatus {
	VALID_GROUNDED = 0,         ## Continuously grounded and strictly valid
	VALID_MICRO_DROP = 1,       ## Valid micro-drop / crest unweighting
	VALID_AIRBORNE = 2,         ## Valid intentional airborne flight section
	VALID_LANDING = 3,          ## Valid landing ramp and recovery
	INVALID_GEOMETRY = 4,       ## Geometric limit violation (grade, curvature, seam, etc.)
	INVALID_UNCONTROLLED_GAP = 5 ## Missing landing, excessive drop, or broken mesh gap
}

class ValidityReport extends RefCounted:
	var is_valid: bool = true
	var segment_status: int = SegmentStatus.VALID_GROUNDED
	var error_count: int = 0
	var warning_count: int = 0
	var violations: Array[Dictionary] = []
	var stats: Dictionary = {}

	func add_violation(code: String, s_idx: int, s_dist: float, measured: float, limit: float, msg: String, is_critical: bool = true) -> void:
		var item := {
			"code": code,
			"sample_idx": s_idx,
			"distance_s": s_dist,
			"measured": measured,
			"limit": limit,
			"message": msg,
			"is_critical": is_critical
		}
		violations.append(item)
		if is_critical:
			is_valid = false
			error_count += 1
		else:
			warning_count += 1

## Validates a contiguous sequence of samples in a RoadPathData
static func validate_segment(path_data: RefCounted, start_idx: int = 0, end_idx: int = -1) -> ValidityReport:
	var report := ValidityReport.new()
	var total_pts: int = path_data.size()
	if total_pts < 2:
		return report

	var s_idx: int = clampi(start_idx, 0, total_pts - 1)
	var e_idx: int = total_pts - 1 if end_idx < 0 else clampi(end_idx, s_idx, total_pts - 1)
	if e_idx <= s_idx:
		return report

	var min_slope: float = 999.0
	var max_slope: float = -999.0
	var min_radius: float = 9999.0
	var max_grade_rate: float = 0.0
	var max_curv_rate: float = 0.0

	var has_micro_drop: bool = false
	var has_airborne: bool = false
	var has_landing: bool = false
	var airborne_dist: float = 0.0
	var airborne_start_height: float = 0.0

	var p_points: PackedVector3Array = path_data.points
	var p_tangents: PackedVector3Array = path_data.tangents
	var p_normals: PackedVector3Array = path_data.normals
	var p_distances: PackedFloat32Array = path_data.cumulative_distances
	var p_slopes: PackedFloat32Array = path_data.slopes
	var p_curvatures: PackedFloat32Array = path_data.curvatures
	var p_states: PackedByteArray = path_data.surface_contact_states
	var p_banking: PackedFloat32Array = path_data.banking_angles

	var prev_mode: int = Airborne.SurfaceContactMode.GROUNDED
	if p_states.size() > s_idx:
		prev_mode = p_states[s_idx]

	for i in range(s_idx + 1, e_idx + 1):
		var p0: Vector3 = p_points[i - 1]
		var p1: Vector3 = p_points[i]
		var ds: float = p0.distance_to(p1)
		var s_dist: float = p_distances[i]

		var cur_mode: int = Airborne.SurfaceContactMode.GROUNDED
		if p_states.size() > i:
			cur_mode = p_states[i]

		# 1. SAMPLING RESOLUTION
		if ds > Contract.MAX_SAMPLE_SPACING:
			report.add_violation("ERR_SAMPLE_GAP", i, s_dist, ds, Contract.MAX_SAMPLE_SPACING,
				"Sample spacing %.2fm exceeds maximum limit %.2fm" % [ds, Contract.MAX_SAMPLE_SPACING])

		if ds < 0.0001:
			report.add_violation("ERR_COLLOCATED_SAMPLES", i, s_dist, ds, 0.0001,
				"Duplicate or collocated points detected (zero distance)")
			continue

		# 2. GRADE & GRADE DERIVATIVE BY ARC LENGTH Δs
		var slope: float = p_slopes[i]
		var prev_slope: float = p_slopes[i - 1]
		min_slope = minf(min_slope, slope)
		max_slope = maxf(max_slope, slope)

		if slope > Contract.MAX_GRADE_UPHILL + 0.05:
			report.add_violation("ERR_GRADE_UPHILL", i, s_dist, slope, Contract.MAX_GRADE_UPHILL,
				"Climb slope %.1f° exceeds pedaling limit +%.1f°" % [slope, Contract.MAX_GRADE_UPHILL])
		elif slope < Contract.MAX_GRADE_DOWNHILL - 0.05:
			report.add_violation("ERR_GRADE_DOWNHILL", i, s_dist, slope, Contract.MAX_GRADE_DOWNHILL,
				"Descent slope %.1f° exceeds gravity limit %.1f°" % [slope, Contract.MAX_GRADE_DOWNHILL])

		var grade_rate: float = absf(slope - prev_slope) / ds
		max_grade_rate = maxf(max_grade_rate, grade_rate)
		if cur_mode == Airborne.SurfaceContactMode.GROUNDED and prev_mode == Airborne.SurfaceContactMode.GROUNDED:
			if grade_rate > Contract.MAX_GRADE_CHANGE_PER_METER + 0.05:
				report.add_violation("ERR_GRADE_DERIVATIVE", i, s_dist, grade_rate, Contract.MAX_GRADE_CHANGE_PER_METER,
					"Grade change rate %.2f°/m exceeds limit %.2f°/m" % [grade_rate, Contract.MAX_GRADE_CHANGE_PER_METER])

		# 3. CURVATURE & CURVATURE DERIVATIVE BY ARC LENGTH Δs
		var curv: float = p_curvatures[i]
		var prev_curv: float = p_curvatures[i - 1]
		var r: float = 1.0 / maxf(curv, 0.00001)
		min_radius = minf(min_radius, r)

		if curv > Contract.MAX_CURVATURE + 0.001:
			report.add_violation("ERR_MIN_RADIUS", i, s_dist, r, Contract.MIN_RADIUS,
				"Curvature radius %.1fm is tighter than minimum %.1fm" % [r, Contract.MIN_RADIUS])

		var curv_rate: float = absf(curv - prev_curv) / ds
		max_curv_rate = maxf(max_curv_rate, curv_rate)
		if curv_rate > Contract.MAX_CURVATURE_CHANGE_PER_METER + 0.0005:
			report.add_violation("ERR_CURVATURE_DERIVATIVE", i, s_dist, curv_rate, Contract.MAX_CURVATURE_CHANGE_PER_METER,
				"Curvature change rate %.4f exceeds limit %.4f" % [curv_rate, Contract.MAX_CURVATURE_CHANGE_PER_METER])

		# 4. NORMAL ORTHONORMALITY
		var tang: Vector3 = p_tangents[i]
		var norm: Vector3 = p_normals[i]
		var dot_tn: float = absf(tang.dot(norm))
		if dot_tn > 0.05:
			report.add_violation("ERR_NORMAL_SKEW", i, s_dist, dot_tn, 0.05,
				"Normal vector not perpendicular to tangent (dot = %.3f)" % dot_tn)

		# 5. SURFACE CONTACT MODE & FSM TRANSITION

		if cur_mode == Airborne.SurfaceContactMode.MICRO_DROP:
			has_micro_drop = true
		elif cur_mode == Airborne.SurfaceContactMode.AIRBORNE:
			has_airborne = true
		elif cur_mode == Airborne.SurfaceContactMode.LANDING:
			has_landing = true

		if not Airborne.is_valid_transition(prev_mode, cur_mode):
			report.add_violation("ERR_INVALID_MODE_TRANSITION", i, s_dist, float(cur_mode), float(prev_mode),
				"Illegal contact transition from %d to %d" % [prev_mode, cur_mode])

		# Airborne bounds tracking
		if cur_mode == Airborne.SurfaceContactMode.AIRBORNE:
			if prev_mode != Airborne.SurfaceContactMode.AIRBORNE:
				airborne_dist = 0.0
				airborne_start_height = p0.y
			airborne_dist += ds
			var drop_h: float = airborne_start_height - p1.y
			if airborne_dist > Airborne.AIRBORNE_MAX_DIST:
				report.add_violation("ERR_AIRBORNE_LENGTH", i, s_dist, airborne_dist, Airborne.AIRBORNE_MAX_DIST,
					"Airborne distance %.1fm exceeds maximum safe limit %.1fm" % [airborne_dist, Airborne.AIRBORNE_MAX_DIST])
			if drop_h > Airborne.AIRBORNE_MAX_HEIGHT + 0.1:
				report.add_violation("ERR_DROP_HEIGHT", i, s_dist, drop_h, Airborne.AIRBORNE_MAX_HEIGHT,
					"Drop height %.2fm exceeds maximum limit %.2fm" % [drop_h, Airborne.AIRBORNE_MAX_HEIGHT])

		# Landing ramp validation
		if cur_mode == Airborne.SurfaceContactMode.LANDING:
			var banking: float = p_banking[i] if p_banking.size() > i else 0.0
			var land_check := Airborne.validate_landing_parameters(slope, prev_slope, r, banking)
			if not land_check["is_valid"]:
				for v_msg in land_check["violations"]:
					report.add_violation("ERR_LANDING_DEFECT", i, s_dist, slope, 0.0, v_msg)

		# 6. COMBINATION LIMITS: Steep downhill + sharp turn
		if slope < Contract.EXTREME_DOWNHILL_THRESHOLD and r < Contract.HIGH_SPEED_MIN_RADIUS:
			report.add_violation("ERR_COMBINATION_HAZARD", i, s_dist, slope, r,
				"Hazardous combination: extreme slope (%.1f°) entering sharp curve (R=%.1fm) without braking zone" % [slope, r])

		prev_mode = cur_mode

	# Uncontrolled gap detection: airborne without landing
	if has_airborne and not has_landing:
		report.add_violation("ERR_UNCONTROLLED_GAP", e_idx, path_data.cumulative_distances[e_idx], 0.0, 0.0,
			"Airborne section terminates without a declared LANDING ramp")

	# Determine final segment classification
	if not report.is_valid:
		report.segment_status = SegmentStatus.INVALID_UNCONTROLLED_GAP if (has_airborne and not has_landing) else SegmentStatus.INVALID_GEOMETRY
	elif has_airborne:
		report.segment_status = SegmentStatus.VALID_AIRBORNE
	elif has_landing:
		report.segment_status = SegmentStatus.VALID_LANDING
	elif has_micro_drop:
		report.segment_status = SegmentStatus.VALID_MICRO_DROP
	else:
		report.segment_status = SegmentStatus.VALID_GROUNDED

	report.stats = {
		"min_slope": min_slope,
		"max_slope": max_slope,
		"min_radius": min_radius,
		"max_grade_rate": max_grade_rate,
		"max_curv_rate": max_curv_rate
	}

	return report

## Validates the geometric seam between two consecutive chunks or branches
static func validate_seam(path_a: RefCounted, idx_a: int, path_b: RefCounted, idx_b: int) -> ValidityReport:
	var report := ValidityReport.new()

	var p_a: Vector3 = path_a.points[idx_a]
	var p_b: Vector3 = path_b.points[idx_b]
	var pos_err: float = p_a.distance_to(p_b)
	var s_dist: float = path_a.cumulative_distances[idx_a]

	# C0: Position error
	if pos_err > Contract.MAX_SEAM_POS_ERROR:
		report.add_violation("ERR_SEAM_C0_POSITION", idx_a, s_dist, pos_err, Contract.MAX_SEAM_POS_ERROR,
			"Seam position gap %.4fm exceeds tolerance %.4fm" % [pos_err, Contract.MAX_SEAM_POS_ERROR])

	# C1: Tangent angle deviation
	var t_a: Vector3 = path_a.tangents[idx_a].normalized()
	var t_b: Vector3 = path_b.tangents[idx_b].normalized()
	var dot_tang: float = clampf(t_a.dot(t_b), -1.0, 1.0)
	var tang_angle_deg: float = rad_to_deg(acos(dot_tang))
	if tang_angle_deg > Contract.MAX_SEAM_TANGENT_ANGLE_DEG:
		report.add_violation("ERR_SEAM_C1_TANGENT", idx_a, s_dist, tang_angle_deg, Contract.MAX_SEAM_TANGENT_ANGLE_DEG,
			"Seam tangent deviation %.3f° exceeds tolerance %.3f°" % [tang_angle_deg, Contract.MAX_SEAM_TANGENT_ANGLE_DEG])

	# Slope difference
	var slope_a: float = path_a.slopes[idx_a]
	var slope_b: float = path_b.slopes[idx_b]
	var slope_delta: float = absf(slope_a - slope_b)
	if slope_delta > Contract.MAX_SEAM_SLOPE_DELTA_DEG:
		report.add_violation("ERR_SEAM_SLOPE_DELTA", idx_a, s_dist, slope_delta, Contract.MAX_SEAM_SLOPE_DELTA_DEG,
			"Seam slope step %.3f° exceeds tolerance %.3f°" % [slope_delta, Contract.MAX_SEAM_SLOPE_DELTA_DEG])

	# Normal difference
	var n_a: Vector3 = path_a.normals[idx_a].normalized()
	var n_b: Vector3 = path_b.normals[idx_b].normalized()
	var dot_norm: float = clampf(n_a.dot(n_b), -1.0, 1.0)
	var norm_angle_deg: float = rad_to_deg(acos(dot_norm))
	if norm_angle_deg > Contract.MAX_SEAM_NORMAL_ANGLE_DEG:
		report.add_violation("ERR_SEAM_NORMAL_ANGLE", idx_a, s_dist, norm_angle_deg, Contract.MAX_SEAM_NORMAL_ANGLE_DEG,
			"Seam normal angle deviation %.3f° exceeds tolerance %.3f°" % [norm_angle_deg, Contract.MAX_SEAM_NORMAL_ANGLE_DEG])

	return report

## Calculates clear line of sight from sample_idx along the road path
static func calculate_sight_distance_at(path_data: RefCounted, sample_idx: int, sight_type: String = "turn") -> float:
	var total_pts: int = path_data.size()
	if sample_idx >= total_pts - 1:
		return 100.0

	var eye_pos: Vector3 = path_data.points[sample_idx] + path_data.normals[sample_idx] * 1.2 # eye height ~1.2m
	var start_s: float = path_data.cumulative_distances[sample_idx]
	var max_range: float = 80.0
	var clear_dist: float = max_range

	for i in range(sample_idx + 1, mini(total_pts, sample_idx + 45)):
		var target_pos: Vector3 = path_data.points[i] + path_data.normals[i] * 0.3 # target 0.3m above ground
		var cur_s: float = path_data.cumulative_distances[i]
		var dist_along_road: float = cur_s - start_s

		if dist_along_road > max_range:
			break

		# Check for crest obstruction between eye_pos and target_pos
		var is_obstructed: bool = false
		for mid in range(sample_idx + 1, i):
			var mid_ground: Vector3 = path_data.points[mid]
			var t_mid: float = float(mid - sample_idx) / float(i - sample_idx)
			var los_y: float = lerpf(eye_pos.y, target_pos.y, t_mid)
			if mid_ground.y > (los_y + 0.05):
				is_obstructed = true
				break

		if is_obstructed:
			clear_dist = dist_along_road
			break

	return clear_dist
