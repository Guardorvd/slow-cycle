class_name RoadLogic
extends RefCounted

## Slow Cycle — Road Logic (v5.3)
## Procedural spline geometry generator governed by RoadGrammar FSM.
## Features mountain MTB topography: cruise descents, fast gravity runs,
## preparation braking zones, clothoid-transitioned switchbacks, micro-drops,
## and ballistic airborne drops with valid landing surfaces.
## Pure pipeline: Generate -> Validate -> PASS (Commit) / FAIL (Reject & Regenerate).
## Zero arbitrary point mutation.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadMath = preload("res://scripts/world/road_math.gd")
const RoadGrammarClass = preload("res://scripts/world/road_grammar.gd")
const ValidatorClass = preload("res://scripts/world/road_validity_validator.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const CHUNK_LENGTH: float = 50.0 ## Length in meters per chunk
const SAMPLES_PER_CHUNK: int = 25 ## 2.0m resolution per sample
const SAMPLE_STEP_LEN: float = CHUNK_LENGTH / float(SAMPLES_PER_CHUNK)

var world_seed: int = 184729
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var road_path: RefCounted
var grammar: RefCounted

# Spline continuity state tracking
var last_point: Vector3 = Vector3.ZERO
var last_tangent: Vector3 = Vector3(0, 0, -1)
var last_normal: Vector3 = Vector3.UP
var current_heading_deg: float = 180.0 # 180 = -Z
var current_slope_deg: float = 0.0
var chunks_generated: int = 0

# Runtime QA status
var last_validity_report: RefCounted = null
var last_chunk_passed: bool = true

func _init(seed_val: int, path_data: RefCounted) -> void:
	world_seed = seed_val
	rng.seed = seed_val
	road_path = path_data
	grammar = RoadGrammarClass.new(seed_val)
	_initialize_start()

func _initialize_start() -> void:
	last_point = Vector3(0, 3.5, 0)
	last_tangent = Vector3(0, 0, -1)
	last_normal = Vector3.UP
	current_heading_deg = 180.0
	current_slope_deg = 0.0
	
	# Add initial baseline sample
	road_path.append_sample(
		last_point,
		last_tangent,
		last_normal,
		0.0,
		0.0,
		RoadPathDataClass.SegmentType.RECOVERY_FLAT,
		Airborne.SurfaceContactMode.GROUNDED,
		0.0,
		50.0
	)

func is_last_chunk_valid() -> bool:
	return last_chunk_passed

func get_last_error_count() -> int:
	if last_validity_report:
		return last_validity_report.error_count
	return 0

## Plans and appends the next 50m chunk under RoadGrammar FSM control
func plan_next_chunk() -> void:
	var start_idx: int = maxi(0, road_path.size() - 1)
	
	# Snapshot state in case rejection and regeneration is required
	var snap_pt: Vector3 = last_point
	var snap_tang: Vector3 = last_tangent
	var snap_norm: Vector3 = last_normal
	var snap_heading: float = current_heading_deg
	var snap_slope: float = current_slope_deg
	
	var spec: RefCounted = grammar.advance_phase()
	
	# Pre-generation Parameter Clamping against Contract invariants
	spec.min_slope_deg = clampf(spec.min_slope_deg, Contract.MAX_GRADE_DOWNHILL, Contract.MAX_GRADE_UPHILL)
	spec.max_slope_deg = clampf(spec.max_slope_deg, Contract.MAX_GRADE_DOWNHILL, Contract.MAX_GRADE_UPHILL)
	spec.min_radius_m = maxf(spec.min_radius_m, Contract.MIN_RADIUS)
	spec.banking_angle_deg = clampf(spec.banking_angle_deg, -Contract.MAX_BANKING_ANGLE_DEG, Contract.MAX_BANKING_ANGLE_DEG)
	
	# Generate geometry for the phase
	_generate_phase_geometry(spec)
	var end_idx: int = road_path.size() - 1
	
	# Objective Inspection Firewall
	last_validity_report = ValidatorClass.validate_segment(road_path, start_idx, end_idx)
	if start_idx > 0 and last_validity_report.is_valid:
		var seam_report = ValidatorClass.validate_seam(road_path, start_idx, road_path, start_idx)
		if not seam_report.is_valid:
			last_validity_report = seam_report
			
	# Reject & Regenerate: If candidate violates any contract, reject and regenerate safe corridor
	if not last_validity_report.is_valid:
		last_chunk_passed = false
		road_path.truncate_to(start_idx + 1)
		last_point = snap_pt
		last_tangent = snap_tang
		last_normal = snap_norm
		current_heading_deg = snap_heading
		current_slope_deg = snap_slope
		
		# Safe conservative fallback: straight recovery
		_generate_conservative_safe_chunk()
		end_idx = road_path.size() - 1
		last_validity_report = ValidatorClass.validate_segment(road_path, start_idx, end_idx)
		last_chunk_passed = last_validity_report.is_valid
	else:
		last_chunk_passed = true

	chunks_generated += 1

func _generate_phase_geometry(spec: RefCounted) -> void:
	match spec.phase:
		RoadGrammarClass.FlowPhase.SWITCHBACK:
			_build_switchback(spec)
		RoadGrammarClass.FlowPhase.CREST_MICRO_DROP:
			_build_crest_micro_drop(spec)
		RoadGrammarClass.FlowPhase.AIRBORNE_DROP:
			_build_airborne_drop_and_landing(spec)
		RoadGrammarClass.FlowPhase.BRAKING_ZONE:
			_build_braking_zone(spec)
		RoadGrammarClass.FlowPhase.FAST_GRAVITY_DESCENT:
			_build_fast_gravity_descent(spec)
		RoadGrammarClass.FlowPhase.CRUISE_DOWNHILL:
			_build_cruise_downhill(spec)
		RoadGrammarClass.FlowPhase.RECOVERY_FLAT, _:
			_build_recovery_flat(spec)

## SWITCHBACK: Mountain hairpin with Clothoid Transition Contract
## Guarantees R in [18, 22]m, Delta_kappa / Delta_s <= 0.003, and smooth banking
func _build_switchback(spec: RefCounted) -> void:
	var curve_dir: float = grammar.get_curve_direction()
	var target_r: float = rng.randf_range(19.0, 21.0)
	var peak_curv: float = 1.0 / target_r
	var target_slope: float = rng.randf_range(-5.5, -4.0)
	var peak_bank: float = curve_dir * spec.banking_angle_deg
	
	var cur_p: Vector3 = last_point
	var cur_t: Vector3 = last_tangent
	var heading_rad: float = deg_to_rad(current_heading_deg)
	var slope_deg: float = current_slope_deg
	
	var prev_curv: float = 0.0
	
	for i in range(1, SAMPLES_PER_CHUNK + 1):
		var s: float = float(i) * SAMPLE_STEP_LEN
		var k: float = 0.0
		
		# Clothoid transition:
		# Ease-in:  0m .. 18m (9 samples) -> ramp rate <= 0.0028 m^-2
		# Apex arc: 18m .. 32m (7 samples) -> constant curvature 1/R
		# Ease-out: 32m .. 50m (9 samples) -> ramp down <= 0.0028 m^-2
		if s <= 18.0:
			var t_in: float = s / 18.0
			k = peak_curv * t_in
		elif s <= 32.0:
			k = peak_curv
		else:
			var t_out: float = (50.0 - s) / 18.0
			k = peak_curv * clampf(t_out, 0.0, 1.0)
			
		# Advance heading angle by arc integration: dtheta = dir * k * ds
		var d_theta: float = curve_dir * k * SAMPLE_STEP_LEN
		heading_rad += d_theta
		
		# Slope smoothly eases towards target switchback slope (<= 0.5 deg/m)
		slope_deg = lerpf(slope_deg, target_slope, 0.08)
		slope_deg = RoadMath.clamp_slope_deg(slope_deg)
		var slope_rad: float = deg_to_rad(slope_deg)
		
		var new_tang: Vector3 = Vector3(
			sin(heading_rad) * cos(slope_rad),
			sin(slope_rad),
			cos(heading_rad) * cos(slope_rad)
		).normalized()
		
		# Advance position along chord
		var seg_chord: Vector3 = (cur_t + new_tang).normalized()
		cur_p += seg_chord * SAMPLE_STEP_LEN
		
		var bank: float = peak_bank * (k / peak_curv)
		var norm: Vector3 = RoadMath.compute_ortho_normal(new_tang, bank)
		
		road_path.append_sample(
			cur_p,
			new_tang,
			norm,
			slope_deg,
			k,
			RoadPathDataClass.SegmentType.SWITCHBACK,
			Airborne.SurfaceContactMode.GROUNDED,
			bank,
			35.0
		)
		
		cur_t = new_tang
		prev_curv = k
		
	last_point = cur_p
	last_tangent = cur_t
	current_heading_deg = rad_to_deg(heading_rad)
	current_slope_deg = slope_deg
	last_normal = RoadMath.compute_ortho_normal(last_tangent, 0.0)

## CREST_MICRO_DROP: Gentle rise to crest (0°), brief unweighting step (h <= 0.35m), return to grounded
func _build_crest_micro_drop(spec: RefCounted) -> void:
	var yaw_wander: float = rng.randf_range(-2.0, 2.0)
	current_heading_deg += yaw_wander
	var heading_rad: float = deg_to_rad(current_heading_deg)
	
	var cur_p: Vector3 = last_point
	var cur_t: Vector3 = last_tangent
	var slope_deg: float = current_slope_deg
	
	for i in range(1, SAMPLES_PER_CHUNK + 1):
		var mode: int = Airborne.SurfaceContactMode.GROUNDED
		var seg_type: int = RoadPathDataClass.SegmentType.CRUISE_DOWNHILL
		
		if i <= 10:
			# Approach to crest: gently rise towards 0°
			slope_deg = lerpf(slope_deg, 1.5, 0.12)
		elif i == 11 or i == 12:
			# Micro-drop apex unweighting (span = 4.0m, height step ~0.25m)
			mode = Airborne.SurfaceContactMode.MICRO_DROP
			seg_type = RoadPathDataClass.SegmentType.CREST_MICRO_DROP
			slope_deg = -7.0
		else:
			# Continuation: recover and blend into downhill
			slope_deg = lerpf(slope_deg, -6.0, 0.15)
			
		slope_deg = RoadMath.clamp_slope_deg(slope_deg)
		var slope_rad: float = deg_to_rad(slope_deg)
		
		var new_tang: Vector3 = Vector3(
			sin(heading_rad) * cos(slope_rad),
			sin(slope_rad),
			cos(heading_rad) * cos(slope_rad)
		).normalized()
		
		var seg_chord: Vector3 = (cur_t + new_tang).normalized()
		cur_p += seg_chord * SAMPLE_STEP_LEN
		if (i == 11 or i == 12):
			cur_p.y -= 0.12 # Controlled vertical micro-drop
			
		var norm: Vector3 = RoadMath.compute_ortho_normal(new_tang, 0.0)
		road_path.append_sample(
			cur_p,
			new_tang,
			norm,
			slope_deg,
			0.0,
			seg_type,
			mode,
			0.0,
			40.0
		)
		cur_t = new_tang

	last_point = cur_p
	last_tangent = cur_t
	current_slope_deg = slope_deg
	last_normal = RoadMath.compute_ortho_normal(last_tangent, 0.0)

## AIRBORNE_DROP & VALID_LANDING_SURFACE: Ballistic step followed by dedicated landing ramp
func _build_airborne_drop_and_landing(spec: RefCounted) -> void:
	var yaw_wander: float = rng.randf_range(-1.0, 1.0)
	current_heading_deg += yaw_wander
	var heading_rad: float = deg_to_rad(current_heading_deg)
	
	var cur_p: Vector3 = last_point
	var cur_t: Vector3 = last_tangent
	var slope_deg: float = current_slope_deg
	
	for i in range(1, SAMPLES_PER_CHUNK + 1):
		var mode: int = Airborne.SurfaceContactMode.GROUNDED
		var seg_type: int = RoadPathDataClass.SegmentType.RECOVERY_FLAT
		var y_offset: float = 0.0
		
		if i <= 8:
			# Approach lip: straight, leveling to 0.5°
			slope_deg = lerpf(slope_deg, 0.5, 0.15)
		elif i >= 9 and i <= 11:
			# Airborne free-flight interval (3 samples = 6m span, h = 0.85m drop)
			mode = Airborne.SurfaceContactMode.AIRBORNE
			seg_type = RoadPathDataClass.SegmentType.AIRBORNE_DROP
			slope_deg = -10.0
			y_offset = -0.28
		elif i >= 12 and i <= 19:
			# VALID_LANDING_SURFACE: dedicated matching landing ramp (8 samples = 16m)
			mode = Airborne.SurfaceContactMode.LANDING
			seg_type = RoadPathDataClass.SegmentType.VALID_LANDING_SURFACE
			slope_deg = -6.5
		else:
			# Grounded runout into flat
			mode = Airborne.SurfaceContactMode.GROUNDED
			seg_type = RoadPathDataClass.SegmentType.RECOVERY_FLAT
			slope_deg = lerpf(slope_deg, -2.0, 0.15)
			
		slope_deg = RoadMath.clamp_slope_deg(slope_deg)
		var slope_rad: float = deg_to_rad(slope_deg)
		
		var new_tang: Vector3 = Vector3(
			sin(heading_rad) * cos(slope_rad),
			sin(slope_rad),
			cos(heading_rad) * cos(slope_rad)
		).normalized()
		
		var seg_chord: Vector3 = (cur_t + new_tang).normalized()
		cur_p += seg_chord * SAMPLE_STEP_LEN
		cur_p.y += y_offset
		
		var norm: Vector3 = RoadMath.compute_ortho_normal(new_tang, 0.0)
		road_path.append_sample(
			cur_p,
			new_tang,
			norm,
			slope_deg,
			0.0,
			seg_type,
			mode,
			0.0,
			45.0
		)
		cur_t = new_tang

	last_point = cur_p
	last_tangent = cur_t
	current_slope_deg = slope_deg
	last_normal = RoadMath.compute_ortho_normal(last_tangent, 0.0)

## BRAKING_ZONE: Straight preparation corridor (-3°..0°) with guaranteed sightline >= 45m
func _build_braking_zone(spec: RefCounted) -> void:
	var target_slope: float = rng.randf_range(-2.5, -0.5)
	var yaw_wander: float = rng.randf_range(-1.0, 1.0)
	_build_hermite_chunk(target_slope, yaw_wander, RoadPathDataClass.SegmentType.BRAKING_ZONE, 50.0, 0.0)

## FAST_GRAVITY_DESCENT: Steep downhill corridor (-9°..-12°), bike accelerates under gravity
func _build_fast_gravity_descent(spec: RefCounted) -> void:
	var target_slope: float = rng.randf_range(-11.5, -9.5)
	var yaw_wander: float = rng.randf_range(-3.0, 3.0)
	_build_hermite_chunk(target_slope, yaw_wander, RoadPathDataClass.SegmentType.FAST_GRAVITY_DESCENT, 60.0, 0.0)

## CRUISE_DOWNHILL: Comfortable coasting descent (-5°..-8°) with freewheel clicks
func _build_cruise_downhill(spec: RefCounted) -> void:
	var target_slope: float = rng.randf_range(-7.5, -5.5)
	var yaw_wander: float = rng.randf_range(-5.0, 5.0)
	_build_hermite_chunk(target_slope, yaw_wander, RoadPathDataClass.SegmentType.CRUISE_DOWNHILL, 50.0, 1.5)

## RECOVERY_FLAT: Flat or very gentle meadow (-1.5°..+1.0°) for calm rollout
func _build_recovery_flat(spec: RefCounted) -> void:
	var target_slope: float = rng.randf_range(-1.0, 0.5)
	var yaw_wander: float = rng.randf_range(-2.5, 2.5)
	_build_hermite_chunk(target_slope, yaw_wander, RoadPathDataClass.SegmentType.RECOVERY_FLAT, 50.0, 0.0)

## General Hermite spline generator for standard smooth phases
func _build_hermite_chunk(target_slope: float, yaw_delta: float, seg_type: int, sight_dist: float, max_bank: float) -> void:
	current_heading_deg += yaw_delta
	# Smooth slope transition: limit delta grade
	var slope_step: float = clampf(target_slope - current_slope_deg, -6.0, 6.0)
	current_slope_deg += slope_step * 0.45
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
	var prev_tang: Vector3 = last_tangent
	
	for i in range(1, SAMPLES_PER_CHUNK + 1):
		var t: float = float(i) / float(SAMPLES_PER_CHUNK)
		var pt: Vector3 = RoadMath.cubic_hermite_position(start_p, h_t0, end_point, h_t1, t)
		var tang: Vector3 = RoadMath.cubic_hermite_tangent(start_p, h_t0, end_point, h_t1, t)
		
		var radius: float = RoadMath.compute_horizontal_radius(prev_tang, tang, SAMPLE_STEP_LEN)
		var curvature: float = 1.0 / maxf(radius, 0.001)
		
		var bank: float = 0.0
		if absf(max_bank) > 0.01:
			bank = max_bank * sin(t * PI)
			
		var norm: Vector3 = RoadMath.compute_ortho_normal(tang, bank)
		var geom_slope: float = rad_to_deg(asin(clampf(tang.y, -0.999, 0.999)))
		
		road_path.append_sample(
			pt,
			tang,
			norm,
			geom_slope,
			curvature,
			seg_type,
			Airborne.SurfaceContactMode.GROUNDED,
			bank,
			sight_dist
		)
		prev_tang = tang

	last_point = end_point
	last_tangent = end_tangent
	last_normal = RoadMath.compute_ortho_normal(last_tangent, 0.0)

## Conservative safe regeneration fallback in case candidate chunk is rejected
func _generate_conservative_safe_chunk() -> void:
	current_slope_deg = lerpf(current_slope_deg, -2.0, 0.5)
	current_slope_deg = RoadMath.clamp_slope_deg(current_slope_deg)
	
	var heading_rad: float = deg_to_rad(current_heading_deg)
	var slope_rad: float = deg_to_rad(current_slope_deg)
	
	var tang: Vector3 = Vector3(
		sin(heading_rad) * cos(slope_rad),
		sin(slope_rad),
		cos(heading_rad) * cos(slope_rad)
	).normalized()
	
	var norm: Vector3 = RoadMath.compute_ortho_normal(tang, 0.0)
	var cur_p: Vector3 = last_point
	
	for i in range(1, SAMPLES_PER_CHUNK + 1):
		cur_p += tang * SAMPLE_STEP_LEN
		road_path.append_sample(
			cur_p,
			tang,
			norm,
			current_slope_deg,
			0.0,
			RoadPathDataClass.SegmentType.RECOVERY_FLAT,
			Airborne.SurfaceContactMode.GROUNDED,
			0.0,
			50.0
		)
		
	last_point = cur_p
	last_tangent = tang
	last_normal = norm
