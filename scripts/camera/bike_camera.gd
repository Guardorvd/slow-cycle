class_name BikeCameraRig
extends Node3D

@export_group("Cameras")
@export var first_person_cam: Camera3D
@export var third_person_cam: Camera3D
@export var spring_arm: SpringArm3D
@export var is_first_person: bool = true

@export_group("Stabilization & Motion")
@export var horizon_stabilization: float = 0.35 ## 0 = perfectly level horizon, 1 = locked to bike roll (Invariant: <= 35%)
@export var roll_damping: float = 8.0
@export var vertical_bob_intensity: float = 0.015 ## Subtle breathing/pedal bob

@export_group("Terrain Micro-Motion")
@export var gravel_shake_intensity: float = 0.0018 ## Base road grain amplitude in meters
@export var grass_shake_multiplier: float = 1.6 ## Relative roughness on grass verge
@export var rough_gravel_shake_multiplier: float = 2.4 ## Relative washboard roughness on rough gravel
@export var shake_frequency: float = 8.0 ## Spatial noise frequency scaling

@export_group("Surge & Dive Dynamics")
@export var max_surge_backward: float = 0.045 ## Max torso lag under acceleration (meters)
@export var max_surge_forward: float = 0.060 ## Max torso lead under deceleration (meters)
@export var surge_gain: float = 0.008 ## Longitudinal surge sensitivity per m/s²
@export var surge_attack_speed: float = 5.5 ## Rapid response to acceleration onset (~0.18s)
@export var surge_release_speed: float = 3.5 ## Smooth return to neutral on coasting (~0.28s)
@export var max_dive_pitch_deg: float = 1.5 ## Max nose-dip angle under braking in degrees
@export var dive_y_drop: float = 0.025 ## Vertical eye level drop under braking (meters)
@export var dive_attack_speed: float = 6.6 ## Rapid dive onset on braking bite (~0.15s)
@export var dive_release_speed: float = 5.0 ## Smooth return on brake release (~0.20s)

@export_group("Secondary Dynamics")
@export var max_apex_look_deg: float = 2.5 ## Max gaze lead into turns in degrees (Priority 2)
@export var apex_look_gain: float = 0.10 ## Gaze lead factor from visual_steer
@export var apex_look_speed: float = 6.0 ## Look lead smoothing rate
@export var cadence_sway_intensity: float = 0.005 ## Max lateral torso sway from pedaling in meters
@export var speed_breathing_amplitude: float = 0.0 ## FOV micro-oscillation (OFF by default: 0.0)

@export_group("Speed FOV")
@export var fp_base_fov: float = 78.0
@export var fp_max_fov: float = 83.0
@export var tp_base_fov: float = 68.0
@export var tp_max_fov: float = 72.0
@export var fov_speed_range: float = 12.0 ## Speed in m/s (~43.2 km/h) for max FOV
@export var fov_lerp_speed: float = 3.5

# Base transform caches
var base_fp_pos: Vector3 = Vector3(0.0, 1.12, 0.05)
var base_fp_rot: Vector3 = Vector3.ZERO
var base_tp_spring_length: float = 2.8
const BASE_FP_HEIGHT: float = 1.12 ## Backward compatibility alias

# Smoothed dynamic state
var current_roll: float = 0.0
var current_surge_z: float = 0.0
var current_dive_pitch: float = 0.0
var current_dive_y: float = 0.0
var current_look_yaw: float = 0.0
var current_shake_x: float = 0.0
var current_shake_y: float = 0.0
var current_shake_rot: float = 0.0
var current_bob_y: float = 0.0
var bob_phase: float = 0.0
var travel_distance: float = 0.0
var shake_time: float = 0.0 ## Backward compatibility alias

# Noise engine (single cached generator)
var noise_gen: FastNoiseLite = FastNoiseLite.new()

@onready var bike = get_parent()

func _ready() -> void:
	if not bike:
		bike = get_parent()
	if not first_person_cam:
		first_person_cam = get_node_or_null("FirstPersonCamera")
	if not third_person_cam:
		third_person_cam = get_node_or_null("SpringArm3D/ThirdPersonCamera")
	if not spring_arm:
		spring_arm = get_node_or_null("SpringArm3D")

	if first_person_cam:
		base_fp_pos = first_person_cam.position
		base_fp_rot = first_person_cam.rotation
	
	if spring_arm:
		base_tp_spring_length = spring_arm.spring_length

	noise_gen.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_gen.seed = 1337
	noise_gen.frequency = 0.15

	_apply_camera_mode()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_camera"):
		is_first_person = not is_first_person
		_apply_camera_mode()

	if not bike:
		bike = get_parent()
	if not bike:
		return

	var current_speed: float = bike.get("current_speed") if "current_speed" in bike else 0.0
	var long_accel: float = bike.get("longitudinal_acceleration") if "longitudinal_acceleration" in bike else 0.0
	var brake_in: float = bike.get("brake_input") if "brake_input" in bike else 0.0
	var bike_bank: float = bike.get("current_bank") if "current_bank" in bike else 0.0
	var vis_steer: float = bike.get("visual_steer") if "visual_steer" in bike else 0.0
	var is_pedaling: bool = bike.get("is_pedaling") if "is_pedaling" in bike else false
	var is_sprinting: bool = bike.get("is_sprinting") if "is_sprinting" in bike else false
	var sprint_boost_val: float = bike.get("sprint_boost") if "sprint_boost" in bike else 0.0
	var is_coasting: bool = bike.get("is_coasting") if "is_coasting" in bike else false
	var crank_rot: float = bike.get("crank_rotation") if "crank_rotation" in bike else 0.0
	var pedal_power: float = bike.get("pedal_power") if "pedal_power" in bike else 0.0
	var terrain_rough: float = bike.get("terrain_roughness") if "terrain_roughness" in bike else 0.16
	var is_on_grass: bool = bike.get("is_on_grass") if "is_on_grass" in bike else false
	var current_surf: int = bike.get("current_surface") if "current_surface" in bike else 0

	# -------------------------------------------------------------
	# 1. CORE PRIORITY 1: Horizon Roll Stabilization (VOR Invariant <= 35%)
	# -------------------------------------------------------------
	var target_roll: float = bike_bank * horizon_stabilization
	var roll_t: float = 1.0 - exp(-roll_damping * delta)
	current_roll = lerpf(current_roll, target_roll, roll_t)

	# -------------------------------------------------------------
	# 2. CORE PRIORITY 1: Longitudinal Surge (Inertial Torso Lag/Lead)
	# -------------------------------------------------------------
	var target_surge_z: float = clampf(long_accel * surge_gain, -max_surge_forward, max_surge_backward)
	var is_surge_expanding: bool = absf(target_surge_z) > absf(current_surge_z) or (target_surge_z * current_surge_z < 0.0)
	var surge_rate: float = surge_attack_speed if is_surge_expanding else surge_release_speed
	var surge_t: float = 1.0 - exp(-surge_rate * delta)
	current_surge_z = lerpf(current_surge_z, target_surge_z, surge_t)

	# -------------------------------------------------------------
	# 3. CORE PRIORITY 1: Braking Dive & Vertical Eye Drop
	# -------------------------------------------------------------
	var dive_curve: float = smoothstep(0.0, 1.0, brake_in)
	var target_dive_pitch: float = -deg_to_rad(max_dive_pitch_deg) * dive_curve
	var target_dive_y: float = -dive_y_drop * (brake_in * brake_in)
	var is_dive_increasing: bool = absf(target_dive_pitch) > absf(current_dive_pitch)
	var dive_rate: float = dive_attack_speed if is_dive_increasing else dive_release_speed
	var dive_t: float = 1.0 - exp(-dive_rate * delta)
	current_dive_pitch = lerpf(current_dive_pitch, target_dive_pitch, dive_t)
	current_dive_y = lerpf(current_dive_y, target_dive_y, dive_t)

	# -------------------------------------------------------------
	# 4. CORE PRIORITY 1: Coherent Road Noise (Distance-Driven & Zero-Speed Gated)
	# -------------------------------------------------------------
	var zero_speed_gate: float = smoothstep(0.10, 0.60, current_speed)
	if current_speed > 0.05:
		travel_distance += current_speed * delta
		shake_time = travel_distance # Backward compatibility

	var surface_mult: float = 1.0
	if is_on_grass or current_surf == 1:
		surface_mult = grass_shake_multiplier
	elif current_surf == 2:
		surface_mult = rough_gravel_shake_multiplier

	var speed_factor: float = clampf(current_speed / 8.0, 0.0, 1.25)
	var roughness_factor: float = 1.0 + 1.8 * clampf(terrain_rough, 0.0, 1.0)
	var noise_amp: float = gravel_shake_intensity * surface_mult * speed_factor * roughness_factor * zero_speed_gate

	var sample_coord: float = travel_distance * (shake_frequency * 0.5)
	var raw_ny: float = noise_gen.get_noise_2d(sample_coord, 0.0) if noise_gen else 0.0
	var raw_nx: float = noise_gen.get_noise_2d(0.0, sample_coord) if noise_gen else 0.0
	var raw_nr: float = noise_gen.get_noise_2d(sample_coord * 0.5, sample_coord * 0.5) if noise_gen else 0.0

	var target_shake_y: float = raw_ny * noise_amp
	var target_shake_x: float = raw_nx * noise_amp * 0.6
	var target_shake_rot: float = raw_nr * deg_to_rad(0.15) * zero_speed_gate * speed_factor

	var noise_t: float = 1.0 - exp(-14.0 * delta)
	current_shake_x = lerpf(current_shake_x, target_shake_x, noise_t)
	current_shake_y = lerpf(current_shake_y, target_shake_y, noise_t)
	current_shake_rot = lerpf(current_shake_rot, target_shake_rot, noise_t)

	# -------------------------------------------------------------
	# 5. SECONDARY PRIORITY 2: Apex Look-Ahead (Subtle Gaze Lead <= 2.5°)
	# -------------------------------------------------------------
	var target_look_yaw: float = clampf(vis_steer * apex_look_gain, -deg_to_rad(max_apex_look_deg), deg_to_rad(max_apex_look_deg))
	var look_t: float = 1.0 - exp(-apex_look_speed * delta)
	current_look_yaw = lerpf(current_look_yaw, target_look_yaw, look_t)

	# -------------------------------------------------------------
	# 6. SECONDARY PRIORITY 2: Cadence Sway & Vertical Pedal Bob
	# -------------------------------------------------------------
	var sway_offset_x: float = 0.0
	var target_bob_y: float = 0.0
	var is_working_pedals: bool = is_pedaling or is_sprinting
	var eff_pedal_power: float = pedal_power if is_pedaling else clampf(sprint_boost_val / 3.0, 0.5, 1.0)
	if is_working_pedals and current_speed > 0.5:
		bob_phase += delta * (current_speed * 1.4)
		target_bob_y = sin(bob_phase) * vertical_bob_intensity
		sway_offset_x = sin(crank_rot) * cadence_sway_intensity * eff_pedal_power
	elif is_coasting or current_speed <= 0.5:
		target_bob_y = 0.0
		sway_offset_x = 0.0

	var bob_t: float = 1.0 - exp(-10.0 * delta)
	current_bob_y = lerpf(current_bob_y, target_bob_y, bob_t)

	# -------------------------------------------------------------
	# 7. Speed FOV & Speed Breathing (Breathing OFF by default)
	# -------------------------------------------------------------
	var speed_ratio: float = clampf(current_speed / fov_speed_range, 0.0, 1.0)
	var breathing_deg: float = 0.0
	if speed_breathing_amplitude > 0.001 and current_speed > 10.0:
		breathing_deg = sin(travel_distance * 8.0) * speed_breathing_amplitude

	var target_fp_fov: float = lerpf(fp_base_fov, fp_max_fov, speed_ratio) + breathing_deg
	var target_tp_fov: float = lerpf(tp_base_fov, tp_max_fov, speed_ratio)

	var fov_t: float = 1.0 - exp(-fov_lerp_speed * delta)
	if first_person_cam:
		first_person_cam.fov = lerpf(first_person_cam.fov, target_fp_fov, fov_t)
	if third_person_cam:
		third_person_cam.fov = lerpf(third_person_cam.fov, target_tp_fov, fov_t)

	# -------------------------------------------------------------
	# 8. Apply Transforms to First-Person Cockpit Camera
	# -------------------------------------------------------------
	if first_person_cam:
		# Position: base + lateral sway + shake_x, base_y + bob + dive_y + shake_y, base_z + surge_z + dive_tuck
		var dive_forward_shift: float = current_dive_pitch * 0.03 # Subtle forward tuck in braking (-Z towards handlebars)
		first_person_cam.position.x = base_fp_pos.x + current_shake_x + sway_offset_x
		first_person_cam.position.y = base_fp_pos.y + current_bob_y + current_dive_y + current_shake_y
		first_person_cam.position.z = base_fp_pos.z + current_surge_z + dive_forward_shift

		# Rotation: base_pitch + dive_pitch, look_yaw, current_roll + shake_rot
		first_person_cam.rotation.x = base_fp_rot.x + current_dive_pitch
		first_person_cam.rotation.y = base_fp_rot.y + current_look_yaw
		first_person_cam.rotation.z = current_roll + current_shake_rot

	# -------------------------------------------------------------
	# 9. Apply Transforms to Third-Person Chase Camera (SpringArm Profile)
	# -------------------------------------------------------------
	if third_person_cam:
		# Third person maintains calm perspective: zero angular road noise, zero apex yaw
		third_person_cam.rotation.z = current_roll * 0.5
		third_person_cam.rotation.x = 0.0
		third_person_cam.rotation.y = 0.0

		# Linear noise heavily attenuated to 20%
		third_person_cam.position.x = current_shake_x * 0.20
		third_person_cam.position.y = current_shake_y * 0.20

		# Surge breathes spring length smoothly
		if spring_arm:
			var target_spring: float = base_tp_spring_length + current_surge_z * 1.5
			var arm_t: float = 1.0 - exp(-6.0 * delta)
			spring_arm.spring_length = lerpf(spring_arm.spring_length, target_spring, arm_t)

func _apply_camera_mode() -> void:
	if first_person_cam and third_person_cam:
		first_person_cam.current = is_first_person
		third_person_cam.current = not is_first_person

## Resets dynamic camera state upon teleportation / recovery to prevent visual spikes
func reset_camera_dynamics() -> void:
	current_surge_z = 0.0
	current_dive_pitch = 0.0
	current_dive_y = 0.0
	current_look_yaw = 0.0
	current_shake_x = 0.0
	current_shake_y = 0.0
	current_shake_rot = 0.0
	current_bob_y = 0.0
	current_roll = 0.0
	bob_phase = 0.0
	travel_distance = 0.0
	shake_time = 0.0
	if first_person_cam:
		first_person_cam.position = base_fp_pos
		first_person_cam.rotation = base_fp_rot
	if spring_arm:
		spring_arm.spring_length = base_tp_spring_length
	if third_person_cam:
		third_person_cam.position = Vector3.ZERO
		third_person_cam.rotation = Vector3.ZERO
