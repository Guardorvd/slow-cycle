class_name BicycleController
extends CharacterBody3D

## Signals for HUD and Audio systems
signal telemetry_updated(speed_kmh: float, cadence_pct: float, is_coasting: bool)
signal bell_rung()

@export_group("Speed & Dynamics")
@export var cruising_speed: float = 7.0 ## Comfortable cruising speed (~25 km/h)
@export var max_sprint_speed: float = 13.0 ## Maximum downhill or sprint speed (~47 km/h)
@export var pedal_acceleration: float = 3.5 ## Forward push rate when pedaling
@export var brake_deceleration: float = 7.5 ## Deceleration when braking
@export var road_rolling_resistance: float = 0.35 ## Rolling friction on gravel road
@export var grass_rolling_resistance: float = 1.35 ## High rolling resistance when off-road on grass
@export var air_drag_coeff: float = 0.015 ## Quadratic aerodynamic drag
@export var gravity_slope_mult: float = 1.45 ## Effect of slope gravity on downhill coasting

@export_group("Steering & Banking")
@export var steer_sensitivity: float = 1.6 ## Turn rate (radians/sec)
@export var max_steer_angle: float = 0.50 ## ~28.6 degrees max handlebar rotation at low speed
@export var max_bank_angle: float = 0.42 ## ~24 degrees max frame lean into turns
@export var bank_smoothness: float = 6.0 ## Lerp speed for frame roll into turn
@export var pitch_smoothness: float = 8.0 ## Lerp speed for slope alignment

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
var current_bank: float = 0.0
var current_pitch: float = 0.0
var is_pedaling: bool = false
var is_braking: bool = false
var is_coasting: bool = false
var is_grounded: bool = true
var is_on_grass: bool = false
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

func _process(delta: float) -> void:
	var speed_kmh: float = current_speed * 3.6
	var cadence_factor: float = (current_speed / cruising_speed) if is_pedaling else 0.0
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
	var target_raw: float = 0.0
	if Input.is_action_pressed("steer_left"):
		target_raw += 1.0
	if Input.is_action_pressed("steer_right"):
		target_raw -= 1.0
	raw_steer_input = target_raw

	is_pedaling = Input.is_action_pressed("pedal") and not Input.is_action_pressed("brake")
	is_braking = Input.is_action_pressed("brake")
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

	current_pitch = lerpf(current_pitch, target_pitch, pitch_smoothness * delta)

func _calculate_forward_dynamics(delta: float) -> void:
	# Active rolling resistance: road vs grass
	var active_roll_res: float = road_rolling_resistance
	if is_on_grass:
		active_roll_res = grass_rolling_resistance

	if not is_grounded:
		current_speed = maxf(0.0, current_speed - active_roll_res * delta)
		return

	# 1. Slope gravity acceleration
	var slope_gravity_accel: float = -sin(current_pitch) * 9.8 * gravity_slope_mult
	current_speed += slope_gravity_accel * delta

	# 2. Pedaling
	if is_pedaling:
		var effective_cruising: float = cruising_speed * (0.6 if is_on_grass else 1.0)
		var effective_sprint: float = max_sprint_speed * (0.6 if is_on_grass else 1.0)
		if current_speed < effective_cruising:
			current_speed += pedal_acceleration * delta
		elif current_speed < effective_sprint:
			var efficiency: float = 1.0 - ((current_speed - effective_cruising) / (effective_sprint - effective_cruising))
			current_speed += pedal_acceleration * efficiency * 0.5 * delta

	# 3. Braking
	if is_braking:
		current_speed = maxf(0.0, current_speed - brake_deceleration * delta)

	# 4. Drag and rolling resistance
	var drag: float = (active_roll_res + air_drag_coeff * (current_speed * current_speed)) * delta
	current_speed = maxf(0.0, current_speed - drag)

func _calculate_steering_and_banking(delta: float) -> void:
	# 1. Soft-knee input filtering (gradual attack for micro-taps, firm return to center)
	var steer_attack_speed: float = 4.5
	var steer_decay_speed: float = 8.0
	var filter_rate: float = steer_decay_speed if absf(raw_steer_input) < 0.01 else steer_attack_speed
	filtered_steer_input = lerpf(filtered_steer_input, raw_steer_input, filter_rate * delta)
	steer_input = filtered_steer_input

	# 2. Speed-sensitive steering limiter (High-speed damping)
	# At low speed (<= 2.8 m/s ~ 10 km/h): full angle ~28.6°
	# At high speed (>= 11.5 m/s ~ 41 km/h): narrow angle ~9.2°
	var speed_t: float = clampf((current_speed - 2.8) / 8.7, 0.0, 1.0)
	var dynamic_max_steer: float = lerpf(max_steer_angle, 0.16, speed_t)
	var target_steer: float = filtered_steer_input * dynamic_max_steer

	# 3. Steering mass & centering moment (handlebars feel heavier with speed)
	var steer_inertia_rate: float = lerpf(6.5, 12.0, speed_t)
	current_steer = lerpf(current_steer, target_steer, steer_inertia_rate * delta)

	# 4. Kinematic bicycle yaw rate: omega = (v / wheelbase) * tan(steer)
	var yaw_turn_rate: float = 0.0
	if current_speed > 0.3:
		yaw_turn_rate = (current_speed / WHEELBASE) * tan(current_steer)
		# Clamp yaw rate to prevent extreme lateral whips
		yaw_turn_rate = clampf(yaw_turn_rate, -1.8, 1.8)
	else:
		yaw_turn_rate = current_steer * steer_sensitivity * 0.2

	rotate_y(yaw_turn_rate * delta)

	# 5. Physics-based banking from centrifugal lateral acceleration: a_c = v * omega_yaw
	# Equilibrium roll angle: tan(phi) = a_c / g => phi = -atan2(a_c, g)
	var lateral_accel: float = current_speed * yaw_turn_rate
	var physical_target_bank: float = -atan2(lateral_accel, 9.8)
	physical_target_bank = clampf(physical_target_bank, -max_bank_angle, max_bank_angle)

	current_bank = lerpf(current_bank, physical_target_bank, bank_smoothness * delta)


func _apply_motion(delta: float) -> void:
	var forward_dir: Vector3 = -global_transform.basis.z
	var motion_horizontal: Vector3 = forward_dir * current_speed

	var vertical_vel: float = velocity.y
	if is_grounded:
		var slope_vy: float = current_speed * sin(current_pitch)
		vertical_vel = minf(-0.5, slope_vy - 0.5)
	else:
		vertical_vel -= 9.8 * delta

	velocity = Vector3(motion_horizontal.x, vertical_vel, motion_horizontal.z)
	move_and_slide()

func _update_visual_transforms(delta: float) -> void:
	if visuals_root:
		visuals_root.rotation.z = current_bank
		visuals_root.rotation.x = current_pitch

	if handlebar_pivot:
		handlebar_pivot.rotation.y = current_steer

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
	velocity = -global_transform.basis.z * current_speed
