class_name BikeCameraRig
extends Node3D

const BicycleControllerScript = preload("res://scripts/player/bicycle_controller.gd")

@export_group("Cameras")
@export var first_person_cam: Camera3D
@export var third_person_cam: Camera3D
@export var is_first_person: bool = true

@export_group("Stabilization & Motion")
@export var horizon_stabilization: float = 0.35 ## 0 = perfectly level horizon, 1 = locked to bike roll
@export var roll_damping: float = 8.0
@export var vertical_bob_intensity: float = 0.015 ## Subtle breathing/pedal bob

@export_group("Terrain Micro-Motion")
@export var gravel_shake_intensity: float = 0.0018 ## Subtle high-frequency road grain
@export var grass_shake_multiplier: float = 1.6 ## Relative roughness on grass verge
@export var shake_frequency: float = 8.0 ## Low-frequency pseudo-noise (5-10 Hz)

@export_group("Speed FOV")
@export var fp_base_fov: float = 78.0
@export var fp_max_fov: float = 83.0
@export var tp_base_fov: float = 68.0
@export var tp_max_fov: float = 72.0
@export var fov_speed_range: float = 12.0 ## Speed in m/s (~43.2 km/h) for max FOV
@export var fov_lerp_speed: float = 3.5

var current_roll: float = 0.0
var bob_phase: float = 0.0
var shake_time: float = 0.0
var current_shake_x: float = 0.0
var current_shake_y: float = 0.0
const BASE_FP_HEIGHT: float = 1.12

@onready var bike = get_parent()

func _ready() -> void:
	_apply_camera_mode()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_camera"):
		is_first_person = not is_first_person
		_apply_camera_mode()

	if not bike:
		return

	# Damped camera roll into turns to prevent motion sickness
	var bike_bank: float = bike.get("current_bank") if "current_bank" in bike else 0.0
	var target_roll: float = bike_bank * horizon_stabilization
	current_roll = lerpf(current_roll, target_roll, roll_damping * delta)

	# Subtle cadence vertical bobbing when pedaling
	var is_pedaling: bool = bike.get("is_pedaling") if "is_pedaling" in bike else false
	var current_speed: float = bike.get("current_speed") if "current_speed" in bike else 0.0
	
	# Terrain micro-motion layer: smooth pseudo-noise at 5-10 Hz
	if current_speed > 0.2:
		shake_time += delta * shake_frequency
		var speed_factor: float = clampf(current_speed / 10.0, 0.0, 1.2)
		var is_on_grass: bool = bike.get("is_on_grass") if "is_on_grass" in bike else false
		var surface_mult: float = grass_shake_multiplier if is_on_grass else 1.0
		var amp: float = gravel_shake_intensity * speed_factor * surface_mult
		var target_shake_y: float = (sin(shake_time) * 0.6 + sin(shake_time * 1.414) * 0.4) * amp
		var target_shake_x: float = (cos(shake_time * 0.732) * 0.5 + cos(shake_time * 1.732) * 0.5) * amp * 0.6
		current_shake_x = lerpf(current_shake_x, target_shake_x, 14.0 * delta)
		current_shake_y = lerpf(current_shake_y, target_shake_y, 14.0 * delta)
	else:
		current_shake_x = lerpf(current_shake_x, 0.0, 10.0 * delta)
		current_shake_y = lerpf(current_shake_y, 0.0, 10.0 * delta)

	if is_pedaling and current_speed > 0.5:
		bob_phase += delta * (current_speed * 1.4)
		var bob_offset: float = sin(bob_phase) * vertical_bob_intensity
		if first_person_cam:
			first_person_cam.position.y = BASE_FP_HEIGHT + bob_offset + current_shake_y
	else:
		if first_person_cam:
			first_person_cam.position.y = lerpf(first_person_cam.position.y, BASE_FP_HEIGHT + current_shake_y, 6.0 * delta)

	if first_person_cam:
		first_person_cam.position.x = current_shake_x

	# Speed FOV dynamic expansion (FEAT-007.3)
	var speed_ratio: float = clampf(current_speed / fov_speed_range, 0.0, 1.0)
	var target_fp_fov: float = lerpf(fp_base_fov, fp_max_fov, speed_ratio)
	var target_tp_fov: float = lerpf(tp_base_fov, tp_max_fov, speed_ratio)

	if first_person_cam:
		first_person_cam.fov = lerpf(first_person_cam.fov, target_fp_fov, fov_lerp_speed * delta)
	if third_person_cam:
		third_person_cam.fov = lerpf(third_person_cam.fov, target_tp_fov, fov_lerp_speed * delta)

	# Apply roll rotation to cameras
	if is_first_person and first_person_cam:
		first_person_cam.rotation.z = current_roll
	elif not is_first_person and third_person_cam:
		third_person_cam.rotation.z = current_roll * 0.5

func _apply_camera_mode() -> void:
	if first_person_cam and third_person_cam:
		first_person_cam.current = is_first_person
		third_person_cam.current = not is_first_person
