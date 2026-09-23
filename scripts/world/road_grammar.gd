class_name RoadGrammar
extends RefCounted

## Slow Cycle — Road Grammar (v5.3)
## Deterministic rhythm FSM governing the mountain MTB descent drama.
## Strictly enforces safety preparation zones, landing surfaces, and recovery flats.
## Separation of Concerns: WHAT player experiences and ALLOWED ENVELOPE.

const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")

enum FlowPhase {
	CRUISE_DOWNHILL = 0,     ## -5°..-8°, 25-30 km/h, comfortable coasting with ratchet click
	FAST_GRAVITY_DESCENT = 1, ## -9°..-12°, 38-42 km/h, wind rush, dynamic FOV expansion
	BRAKING_ZONE = 2,         ## -3°..0°, straight / gentle sightline >= 45m before sharp features
	SWITCHBACK = 3,           ## R = 18..22m, 90°-120° mountain serpentine hairpin with banking
	CREST_MICRO_DROP = 4,     ## h <= 0.35m, brief crest unweighting
	AIRBORNE_DROP = 5,        ## h <= 1.2m, L <= 6m, controlled ballistic lip
	VALID_LANDING_SURFACE = 6,## R >= 50m, matching downhill trajectory receiving wheels
	RECOVERY_FLAT = 7         ## -1.5°..+1.0°, wide sunny meadow for rollout and rest
}

class PhaseSpec extends RefCounted:
	var phase: int = FlowPhase.RECOVERY_FLAT
	var min_slope_deg: float = -2.0
	var max_slope_deg: float = 1.0
	var target_speed_kmh: float = 20.0
	var min_length_m: float = 50.0
	var max_length_m: float = 50.0
	var min_radius_m: float = 60.0
	var sight_distance_m: float = 50.0
	var surface_mode: int = 0 ## Airborne.SurfaceContactMode
	var banking_angle_deg: float = 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_phase: int = FlowPhase.RECOVERY_FLAT
var phase_queue: Array[int] = []
var curve_dir: float = 1.0
var total_chunks_planned: int = 0

func _init(seed_val: int) -> void:
	rng.seed = seed_val
	_setup_initial_dramatic_sequence()

## Seeds the immediate opening mountain descent sequence so the player experiences
## genuine MTB mountain topography immediately upon selecting "1. Бесконечная дорога".
func _setup_initial_dramatic_sequence() -> void:
	phase_queue.clear()
	# Opening Mountain Sequence:
	# 1. Flat Launch & Rollout (RECOVERY_FLAT)
	phase_queue.append(FlowPhase.RECOVERY_FLAT)
	# 2. Gentle Natural Descent (CRUISE_DOWNHILL, -6°)
	phase_queue.append(FlowPhase.CRUISE_DOWNHILL)
	# 3. High-Speed Gravity Descent (FAST_GRAVITY_DESCENT, -10°, 38-42 km/h)
	phase_queue.append(FlowPhase.FAST_GRAVITY_DESCENT)
	# 4. Mandatory Braking Zone (-2°, clear sightline >= 45m)
	phase_queue.append(FlowPhase.BRAKING_ZONE)
	# 5. Mountain Switchback Hairpin (R = 19m, banking 6°)
	phase_queue.append(FlowPhase.SWITCHBACK)
	# 6. Wide Recovery Meadow (RECOVERY_FLAT)
	phase_queue.append(FlowPhase.RECOVERY_FLAT)
	# 7. Crest Micro-Drop unweighting
	phase_queue.append(FlowPhase.CREST_MICRO_DROP)
	# 8. Cruise continuation
	phase_queue.append(FlowPhase.CRUISE_DOWNHILL)

func get_current_phase() -> int:
	return current_phase

func get_curve_direction() -> float:
	return curve_dir

## Advances FSM and returns the next PhaseSpec envelope
func advance_phase() -> PhaseSpec:
	if phase_queue.is_empty():
		_replenish_phase_queue()

	current_phase = phase_queue.pop_front()
	total_chunks_planned += 1
	return get_phase_spec(current_phase)

## Weighted FSM Transition Table with strict hard constraints
func _replenish_phase_queue() -> void:
	var roll: float = rng.randf()

	match current_phase:
		FlowPhase.FAST_GRAVITY_DESCENT:
			# Fast descent MUST NEVER transition directly to switchback or drop!
			# Always prepare with BRAKING_ZONE or decelerate to CRUISE_DOWNHILL.
			if roll < 0.65:
				phase_queue.append(FlowPhase.BRAKING_ZONE)
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			else:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)

		FlowPhase.BRAKING_ZONE:
			# Braking zone leads to planned maneuver
			if roll < 0.70:
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			else:
				phase_queue.append(FlowPhase.AIRBORNE_DROP)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)

		FlowPhase.SWITCHBACK:
			# After a tight switchback, always provide recovery or cruise
			if roll < 0.70:
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			else:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)

		FlowPhase.AIRBORNE_DROP:
			# Mandatory invariant: AIRBORNE chunk includes dedicated landing ramp; transition to rollout
			phase_queue.append(FlowPhase.RECOVERY_FLAT)

		FlowPhase.VALID_LANDING_SURFACE:
			# After landing, mandatory recovery straightaway
			phase_queue.append(FlowPhase.RECOVERY_FLAT)

		FlowPhase.CREST_MICRO_DROP:
			# From micro-drop, roll into downhill
			if roll < 0.60:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)
			else:
				phase_queue.append(FlowPhase.FAST_GRAVITY_DESCENT)

		FlowPhase.RECOVERY_FLAT:
			# From flat meadow, build downhill momentum
			if roll < 0.55:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)
			elif roll < 0.80:
				phase_queue.append(FlowPhase.FAST_GRAVITY_DESCENT)
			else:
				phase_queue.append(FlowPhase.CREST_MICRO_DROP)

		FlowPhase.CRUISE_DOWNHILL, _:
			# Normal cruising descent: branch into fast run, braking for turn, micro-drop, or meadow
			if roll < 0.35:
				phase_queue.append(FlowPhase.FAST_GRAVITY_DESCENT)
			elif roll < 0.65:
				phase_queue.append(FlowPhase.BRAKING_ZONE)
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			elif roll < 0.82:
				phase_queue.append(FlowPhase.CREST_MICRO_DROP)
			else:
				phase_queue.append(FlowPhase.RECOVERY_FLAT)

## Constructs pre-clamped PhaseSpec with allowed envelope bounds
func get_phase_spec(phase: int) -> PhaseSpec:
	var spec := PhaseSpec.new()
	spec.phase = phase

	match phase:
		FlowPhase.CRUISE_DOWNHILL:
			spec.min_slope_deg = -8.0
			spec.max_slope_deg = -5.0
			spec.target_speed_kmh = 28.0
			spec.min_radius_m = 45.0
			spec.sight_distance_m = 50.0
			spec.surface_mode = Airborne.SurfaceContactMode.GROUNDED
			spec.banking_angle_deg = 2.0

		FlowPhase.FAST_GRAVITY_DESCENT:
			spec.min_slope_deg = -12.0
			spec.max_slope_deg = -9.0
			spec.target_speed_kmh = 40.0
			spec.min_radius_m = 80.0
			spec.sight_distance_m = 60.0
			spec.surface_mode = Airborne.SurfaceContactMode.GROUNDED
			spec.banking_angle_deg = 1.0

		FlowPhase.BRAKING_ZONE:
			spec.min_slope_deg = -3.0
			spec.max_slope_deg = 0.0
			spec.target_speed_kmh = 22.0
			spec.min_radius_m = 100.0
			spec.sight_distance_m = 50.0 # Guarantee >= 45m straight line of sight
			spec.surface_mode = Airborne.SurfaceContactMode.GROUNDED
			spec.banking_angle_deg = 0.0

		FlowPhase.SWITCHBACK:
			spec.min_slope_deg = -6.0
			spec.max_slope_deg = -3.0
			spec.target_speed_kmh = 18.0
			spec.min_radius_m = 18.0 # R in [18, 22]m
			spec.sight_distance_m = 35.0
			spec.surface_mode = Airborne.SurfaceContactMode.GROUNDED
			spec.banking_angle_deg = 6.0 # Superelevation into turn

		FlowPhase.CREST_MICRO_DROP:
			spec.min_slope_deg = -8.0
			spec.max_slope_deg = 3.0
			spec.target_speed_kmh = 26.0
			spec.min_radius_m = 60.0
			spec.sight_distance_m = 40.0
			spec.surface_mode = Airborne.SurfaceContactMode.MICRO_DROP
			spec.banking_angle_deg = 0.0

		FlowPhase.AIRBORNE_DROP:
			spec.min_slope_deg = -12.0
			spec.max_slope_deg = 2.0
			spec.target_speed_kmh = 30.0
			spec.min_radius_m = 80.0
			spec.sight_distance_m = 40.0
			spec.surface_mode = Airborne.SurfaceContactMode.AIRBORNE
			spec.banking_angle_deg = 0.0

		FlowPhase.VALID_LANDING_SURFACE:
			spec.min_slope_deg = -8.0
			spec.max_slope_deg = -5.0
			spec.target_speed_kmh = 32.0
			spec.min_radius_m = 50.0 # Straight landing
			spec.sight_distance_m = 45.0
			spec.surface_mode = Airborne.SurfaceContactMode.LANDING
			spec.banking_angle_deg = 1.0 # <= 2.0 deg

		FlowPhase.RECOVERY_FLAT, _:
			spec.min_slope_deg = -1.5
			spec.max_slope_deg = 1.0
			spec.target_speed_kmh = 22.0
			spec.min_radius_m = 90.0
			spec.sight_distance_m = 50.0
			spec.surface_mode = Airborne.SurfaceContactMode.GROUNDED
			spec.banking_angle_deg = 0.0

	# Parameter Clamping against Contract
	spec.min_slope_deg = clampf(spec.min_slope_deg, Contract.MAX_GRADE_DOWNHILL, Contract.MAX_GRADE_UPHILL)
	spec.max_slope_deg = clampf(spec.max_slope_deg, Contract.MAX_GRADE_DOWNHILL, Contract.MAX_GRADE_UPHILL)
	spec.min_radius_m = maxf(spec.min_radius_m, Contract.MIN_RADIUS)
	spec.banking_angle_deg = clampf(spec.banking_angle_deg, -Contract.MAX_BANKING_ANGLE_DEG, Contract.MAX_BANKING_ANGLE_DEG)

	return spec
