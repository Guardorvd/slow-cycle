class_name BicycleController
extends CharacterBody3D

## Signals for HUD and Audio systems
signal telemetry_updated(speed_kmh: float, cadence_pct: float, is_coasting: bool)
signal bell_rung()

@export_group("Speed & Dynamics")
@export var cruising_speed: float = 7.0 ## Comfortable cruising speed (~25 km/h)
@export var max_sprint_speed: float = 13.0 ## Maximum downhill or sprint speed (~47 km/h)
@export var pedal_acceleration: float = 1.3 ## Natural muscular acceleration push (calibrated Sprint 3C)
@export var pedal_attack_time: float = 0.50 ## Progressive muscular effort onset in seconds (0.45-0.60s)
@export var brake_deceleration: float = 7.5 ## Deceleration when braking
@export var brake_attack_time: float = 0.15 ## Rapid initial bite and ramp-up time for braking
@export var brake_release_time: float = 0.10 ## Fast release time when releasing brake
@export var brake_dive_angle_deg: float = 1.7 ## Max visual nose-dive angle in degrees under hard braking
@export var road_rolling_resistance: float = 0.08 ## Calibrated rolling friction on gravel road (17-21 km/h cruise on -2°)
@export var grass_rolling_resistance: float = 0.45 ## Decisive rolling resistance when off-road on grass
@export var air_drag_coeff: float = 0.015 ## Quadratic aerodynamic drag
@export var gravity_slope_mult: float = 1.45 ## Effect of slope gravity on downhill coasting
@export var cornering_scrub_coeff: float = 0.18 ## Gentle speed bleed under high lateral cornering loads
@export var scrub_lateral_threshold: float = 1.5 ## Lateral acceleration threshold (m/s^2) before scrub occurs

@export_group("Steering & Banking")
@export var steer_sensitivity: float = 1.6 ## Turn rate (radians/sec)
@export var max_steer_angle: float = 0.50 ## ~28.6 degrees max handlebar rotation at low speed
@export var high_speed_steer_limit: float = 0.045 ## ~2.6 degrees max handlebar rotation at high speed (R >= 26-30m)
@export var max_bank_angle: float = 0.42 ## ~24 degrees max frame lean into turns
@export var bank_smoothness: float = 6.0 ## Lerp speed for frame roll into turn
@export var pitch_smoothness: float = 8.0 ## Legacy reference
@export var pitch_attack_smoothness: float = 14.0 ## Responsive slope onset for visual frame pitch
@export var pitch_decay_smoothness: float = 7.0 ## Smooth return to horizontal for visual frame pitch

@export_group("Visual Ergonomics")
@export var visual_steer_gain: float = 3.5 ## Visual handlebar amplification factor
@export var max_visual_steer_low_speed: float = deg_to_rad(22.0) ## Maximum visual steer angle at low speed (20-24°)
@export var max_visual_steer_cruising: float = deg_to_rad(16.0) ## Maximum visual steer angle at cruising speed (15-18°)
@export var max_visual_steer_high_speed: float = deg_to_rad(12.0) ## Maximum visual steer angle at sprint speed (10-14°)

@export_group("Node References")
@export var front_ray: RayCast3D
@export var rear_ray: RayCast3D
@export var visuals_root: Node3D
@export var handlebar_pivot: Node3D
@export var front_wheel: Node3D
@export var rear_wheel: Node3D
@export var world_manager: Node
@export var screen_fader: Node

# Internal kinematic state
var current_speed: float = 0.0 # Forward speed in m/s
var steer_input: float = 0.0
var raw_steer_input: float = 0.0
var filtered_steer_input: float = 0.0
var current_steer: float = 0.0
var visual_steer: float = 0.0
var base_fork_transform: Transform3D
var current_bank: float = 0.0
var current_pitch: float = 0.0 # Mirrors visual_pitch for external observers
var physics_pitch: float = 0.0 # Instant slope angle for gravity & ground adhesion
var visual_pitch: float = 0.0 # Decoupled smoothed slope for visual mesh
var pedal_power: float = 0.0 # 0.0 to 1.0 pedaling inertia
var brake_input: float = 0.0 # 0.0 to 1.0 progressive brake ramp
var brake_dive_pitch: float = 0.0 # Visual-only nose dive in radians
var yaw_turn_rate: float = 0.0 # Angular turn rate in rad/s
var turn_radius: float = INF # Computed curve radius
var lateral_acceleration: float = 0.0 # Current lateral load in m/s^2
var is_pedaling: bool = false
var is_braking: bool = false
var is_coasting: bool = false
var is_grounded: bool = true
var is_on_grass: bool = false
var prev_on_grass: bool = false
var prev_hard_brake: bool = false
var wheel_rotation: float = 0.0

const WHEELBASE: float = 1.15
const WHEEL_RADIUS: float = 0.34

func _ready() -> void:
	if front_ray:
		front_ray.enabled = true
		front_ray.collision_mask = 2 | 4 # Mask Layer 2 (Road) and Layer 3 (Grass)
	if rear_ray:
		rear_ray.enabled = true
		rear_ray.collision_mask = 2 | 4
	if handlebar_pivot:
		base_fork_transform = handlebar_pivot.transform

func _process(delta: float) -> void:
	var speed_kmh: float = current_speed * 3.6
	var cadence_factor: float = (current_speed / cruising_speed) * pedal_power if is_pedaling else 0.0
	telemetry_updated.emit(speed_kmh, cadence_factor, is_coasting)

	if Input.is_action_just_pressed("ring_bell"):
		bell_rung.emit()

	# Recovery on 'R' key
	if Input.is_action_just_pressed("recover_ride"):
		_trigger_recovery()

func _physics_process(delta: float) -> void:
	_handle_input()
	_calculate_ground_and_slope(delta)
	_calculate_forward_dynamics(delta)
	_calculate_steering_and_banking(delta)
	_apply_motion(delta)
	_update_visual_transforms(delta)

func _handle_input() -> void:
	# Steer analog support with stick power curve (preserves digital keyboard feel)
	var steer_stick: float = Input.get_axis("steer_right", "steer_left")
	var sign_val: float = signf(steer_stick)
	raw_steer_input = sign_val * pow(absf(steer_stick), 1.5)

	var pedal_strength: float = Input.get_action_strength("pedal")
	var brake_strength: float = Input.get_action_strength("brake")

	is_pedaling = pedal_strength > 0.1 and brake_strength <= 0.1
	is_braking = brake_strength > 0.1
	is_coasting = not is_pedaling and not is_braking and current_speed > 0.3

func _calculate_ground_and_slope(delta: float) -> void:
	var front_hit: bool = front_ray.is_colliding() if front_ray else true
	var rear_hit: bool = rear_ray.is_colliding() if rear_ray else true
	is_grounded = front_hit or rear_hit

	# Surface layer detection: Layer 2 (Road = mask 2) vs Layer 3 (Grass = mask 4)
	var front_grass: bool = false
	var rear_grass: bool = false
	if front_ray and front_hit:
		var col: Object = front_ray.get_collider()
		if col is CollisionObject3D and (col.collision_layer & 4) != 0:
			front_grass = true
	if rear_ray and rear_hit:
		var col: Object = rear_ray.get_collider()
		if col is CollisionObject3D and (col.collision_layer & 4) != 0:
			rear_grass = true

	is_on_grass = front_grass or rear_grass

	var target_pitch: float = 0.0
	if front_ray and rear_ray and front_hit and rear_hit:
		var front_point: Vector3 = front_ray.get_collision_point()
		var rear_point: Vector3 = rear_ray.get_collision_point()
		var height_diff: float = front_point.y - rear_point.y
		target_pitch = atan2(height_diff, WHEELBASE)

	# 1. Physics pitch: immediate response for gravity & vertical adhesion
	physics_pitch = target_pitch

	# 2. Visual pitch: decoupled asymmetric smoothing for visual frame
	var is_steepening: bool = absf(target_pitch) > absf(visual_pitch) or (target_pitch * visual_pitch < 0.0)
	var pitch_rate: float = pitch_attack_smoothness if is_steepening else pitch_decay_smoothness
	visual_pitch = lerpf(visual_pitch, target_pitch, pitch_rate * delta)
	current_pitch = visual_pitch

func _calculate_forward_dynamics(delta: float) -> void:
	# Active rolling resistance: road vs grass
	var active_roll_res: float = road_rolling_resistance
	if is_on_grass:
		active_roll_res = grass_rolling_resistance

	if not is_grounded:
		current_speed = maxf(0.0, current_speed - active_roll_res * delta)
		return

	# 1. Slope gravity acceleration using physics_pitch (instant slope response)
	var slope_gravity_accel: float = -sin(physics_pitch) * 9.8 * gravity_slope_mult
	current_speed += slope_gravity_accel * delta

	# 2. Pedaling with pedal_power inertia ramp and analog throttle
	if is_pedaling:
		var pedal_strength: float = Input.get_action_strength("pedal")
		if pedal_strength < 0.1:
			pedal_strength = 1.0 # Fallback for programmatic triggers/tests
		pedal_power = minf(pedal_strength, pedal_power + (1.0 / pedal_attack_time) * delta)
		var effective_cruising: float = cruising_speed * (0.6 if is_on_grass else 1.0)
		var effective_sprint: float = max_sprint_speed * (0.6 if is_on_grass else 1.0)
		var eff_accel: float = pedal_acceleration * pedal_power
		if current_speed < effective_cruising:
			current_speed += eff_accel * delta
		elif current_speed < effective_sprint:
			var efficiency: float = 1.0 - ((current_speed - effective_cruising) / (effective_sprint - effective_cruising))
			current_speed += eff_accel * efficiency * 0.5 * delta
	else:
		pedal_power = 0.0 # Instant transition to free coasting on release!

	# 3. Progressive braking with quadratic effort curve and analog brake
	if is_braking:
		var brake_strength: float = Input.get_action_strength("brake")
		if brake_strength < 0.1:
			brake_strength = 1.0 # Fallback for programmatic triggers/tests
		brake_input = minf(brake_strength, brake_input + (1.0 / brake_attack_time) * delta)
		var brake_curve: float = brake_input * brake_input
		current_speed = maxf(0.0, current_speed - (brake_deceleration * brake_curve) * delta)
	else:
		brake_input = maxf(0.0, brake_input - (1.0 / brake_release_time) * delta)

	# Visual-only nose dive under braking (smoothly tracking brake_input)
	var target_dive: float = -deg_to_rad(brake_dive_angle_deg) * brake_input
	brake_dive_pitch = lerpf(brake_dive_pitch, target_dive, 12.0 * delta)

	# 4. Drag and rolling resistance
	var drag: float = (active_roll_res + air_drag_coeff * (current_speed * current_speed)) * delta
	current_speed = maxf(0.0, current_speed - drag)

	# 5. Haptic feedback for surface transitions and hard braking
	if is_on_grass and not prev_on_grass:
		_trigger_haptic(0.2, 0.1, 0.12)
	prev_on_grass = is_on_grass

	var is_hard_braking: bool = is_braking and brake_input > 0.8 and current_speed > 2.0
	if is_hard_braking and not prev_hard_brake:
		_trigger_haptic(0.1, 0.35, 0.15)
	prev_hard_brake = is_hard_braking

func _calculate_steering_and_banking(delta: float) -> void:
	# 1. Soft-knee input filtering (gradual attack for micro-taps, firm return to center)
	var steer_attack_speed: float = 4.5
	var steer_decay_speed: float = 8.0
	var filter_rate: float = steer_decay_speed if absf(raw_steer_input) < 0.01 else steer_attack_speed
	filtered_steer_input = lerpf(filtered_steer_input, raw_steer_input, filter_rate * delta)
	steer_input = filtered_steer_input

	# 2. Hybrid Lean Steering & High-Speed Turn Radius Limiter
	# Low speed (<= 0.83 m/s ~ 3 km/h): Direct steering for nimble maneuvers
	# High speed (>= 11.5 m/s ~ 41 km/h): Clamped to high_speed_steer_limit (R >= 26-30m)
	var speed_norm: float = clampf((current_speed - 0.83) / 10.67, 0.0, 1.0)
	var dynamic_max_steer: float = lerpf(max_steer_angle, high_speed_steer_limit, speed_norm)
	var target_steer: float = filtered_steer_input * dynamic_max_steer

	# 3. Steering mass & centering moment
	var steer_inertia_rate: float = lerpf(8.0, 14.0, speed_norm)
	current_steer = lerpf(current_steer, target_steer, steer_inertia_rate * delta)

	# 4. Kinematic bicycle yaw rate: omega = (v / wheelbase) * tan(steer)
	if current_speed > 0.3:
		yaw_turn_rate = (current_speed / WHEELBASE) * tan(current_steer)
		yaw_turn_rate = clampf(yaw_turn_rate, -1.8, 1.8)
	else:
		yaw_turn_rate = current_steer * steer_sensitivity * 0.2

	# Compute turn radius for telemetry: R = v / |omega|
	if absf(yaw_turn_rate) > 0.005 and current_speed > 0.5:
		turn_radius = current_speed / absf(yaw_turn_rate)
	else:
		turn_radius = INF

	rotate_y(yaw_turn_rate * delta)

	# 5. Physics-based banking from centrifugal lateral acceleration: a_c = v * omega_yaw
	lateral_acceleration = current_speed * absf(yaw_turn_rate)
	var lateral_accel_signed: float = current_speed * yaw_turn_rate
	var physical_target_bank: float = atan2(lateral_accel_signed, 9.8)
	physical_target_bank = clampf(physical_target_bank, -max_bank_angle, max_bank_angle)

	current_bank = lerpf(current_bank, physical_target_bank, bank_smoothness * delta)

	# 6. Lateral-load cornering scrub:
	# Only triggers when lateral load exceeds scrub_lateral_threshold (1.5 m/s^2 ~ 0.15g)
	# Straightaways and micro-adjustments produce exactly 0 scrub
	if lateral_acceleration > scrub_lateral_threshold:
		var excess_lateral: float = lateral_acceleration - scrub_lateral_threshold
		var scrub_loss: float = excess_lateral * cornering_scrub_coeff * delta
		current_speed = maxf(0.0, current_speed - scrub_loss)

	# 7. Visual steering ergonomics (FEAT-006.11 / Sprint 3C)
	var dynamic_max_visual: float
	if current_speed <= cruising_speed:
		var speed_ratio: float = clampf(current_speed / cruising_speed, 0.0, 1.0)
		dynamic_max_visual = lerpf(max_visual_steer_low_speed, max_visual_steer_cruising, speed_ratio)
	else:
		var high_speed_ratio: float = clampf((current_speed - cruising_speed) / (max_sprint_speed - cruising_speed), 0.0, 1.0)
		dynamic_max_visual = lerpf(max_visual_steer_cruising, max_visual_steer_high_speed, high_speed_ratio)

	var target_visual_steer: float = clampf(current_steer * visual_steer_gain, -dynamic_max_visual, dynamic_max_visual)
	visual_steer = lerpf(visual_steer, target_visual_steer, 15.0 * delta)

func _apply_motion(delta: float) -> void:
	var forward_dir: Vector3 = -global_transform.basis.z
	var motion_horizontal: Vector3 = forward_dir * current_speed

	var vertical_vel: float = velocity.y
	if is_grounded:
		var slope_vy: float = current_speed * sin(physics_pitch)
		vertical_vel = minf(-0.5, slope_vy - 0.5)
	else:
		vertical_vel -= 9.8 * delta

	velocity = Vector3(motion_horizontal.x, vertical_vel, motion_horizontal.z)
	move_and_slide()

func _update_visual_transforms(delta: float) -> void:
	if visuals_root:
		visuals_root.rotation.z = current_bank
		visuals_root.rotation.x = visual_pitch + brake_dive_pitch

	if handlebar_pivot:
		handlebar_pivot.transform = base_fork_transform.rotated_local(Vector3.UP, visual_steer)

	var spin_delta: float = (current_speed / WHEEL_RADIUS) * delta
	wheel_rotation -= spin_delta
	if front_wheel:
		front_wheel.rotation.x = wheel_rotation
	if rear_wheel:
		rear_wheel.rotation.x = wheel_rotation

func _trigger_recovery() -> void:
	if not world_manager or not world_manager.has_method("request_bike_recovery"):
		return

	if screen_fader and screen_fader.has_method("fade_reposition"):
		screen_fader.fade_reposition(Callable(self, "_execute_recovery_teleport"))
	else:
		_execute_recovery_teleport()

func _execute_recovery_teleport() -> void:
	var safe_transform: Transform3D = world_manager.request_bike_recovery(global_position)
	global_transform = safe_transform
	current_speed = 3.0 # Smooth resumption speed
	current_bank = 0.0
	current_steer = 0.0
	visual_steer = 0.0
	pedal_power = 0.0
	brake_input = 0.0
	brake_dive_pitch = 0.0
	velocity = -global_transform.basis.z * current_speed

func _trigger_haptic(weak: float, strong: float, duration: float) -> void:
	Input.start_joy_vibration(0, weak, strong, duration)
