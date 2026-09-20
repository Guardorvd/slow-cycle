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

var current_roll: float = 0.0
var bob_phase: float = 0.0
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
	
	if is_pedaling and current_speed > 0.5:
		bob_phase += delta * (current_speed * 1.4)
		var bob_offset: float = sin(bob_phase) * vertical_bob_intensity
		if first_person_cam:
			first_person_cam.position.y = BASE_FP_HEIGHT + bob_offset
	else:
		if first_person_cam:
			first_person_cam.position.y = lerpf(first_person_cam.position.y, BASE_FP_HEIGHT, 6.0 * delta)

	# Apply roll rotation to cameras
	if is_first_person and first_person_cam:
		first_person_cam.rotation.z = current_roll
	elif not is_first_person and third_person_cam:
		third_person_cam.rotation.z = current_roll * 0.5

func _apply_camera_mode() -> void:
	if first_person_cam and third_person_cam:
		first_person_cam.current = is_first_person
		third_person_cam.current = not is_first_person
