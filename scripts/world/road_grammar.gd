class_name RoadGrammar
extends RefCounted

## Slow Cycle — Road Grammar (v5.4)
## Deterministic rhythm FSM governing the mountain MTB descent drama.
## Strictly enforces safety preparation zones, landing surfaces, and recovery flats.
## Separation of Concerns: WHAT player experiences and ALLOWED ENVELOPE.

const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const RouteIntentClass = preload("res://scripts/world/route_intent.gd")

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

enum RouteStyle {
	BALANCED = 0,
	FLOW = 1,
	TECHNICAL = 2
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
var route_style: int = RouteStyle.BALANCED
var route_style_seed: int = 0
var authored_switchbacks_planned: int = 0
const RHYTHM_WINDOW_PHASES: int = 12 ## 12 x 50m phase chunks form an observable 600m window.
const MAX_PHASES_WITHOUT_FEATURE: int = 8 ## A light crest is queued if choices leave this long a quiet stretch.
var recent_phase_history: Array[int] = []
var phases_since_last_feature: int = 0

func _init(seed_val: int) -> void:
	route_style_seed = seed_val
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

## Assigns a deterministic route identity to a branch and gives it a distinct opening rhythm.
## Both profiles retain the normal weighted grammar after their authored opening sequence.
func set_route_style(style: int, style_seed: int) -> void:
	route_style = clampi(style, RouteStyle.BALANCED, RouteStyle.TECHNICAL)
	route_style_seed = style_seed
	rng.seed = style_seed
	authored_switchbacks_planned = 0
	recent_phase_history.clear()
	phases_since_last_feature = 0
	curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
	phase_queue.clear()
	match route_style:
		RouteStyle.FLOW:
			phase_queue.assign([
				FlowPhase.CRUISE_DOWNHILL,
				FlowPhase.CREST_MICRO_DROP,
				FlowPhase.CRUISE_DOWNHILL,
				FlowPhase.CREST_MICRO_DROP,
				FlowPhase.RECOVERY_FLAT,
				FlowPhase.CRUISE_DOWNHILL,
				FlowPhase.RECOVERY_FLAT,
				FlowPhase.FAST_GRAVITY_DESCENT,
				FlowPhase.CRUISE_DOWNHILL
			])
		RouteStyle.TECHNICAL:
			phase_queue.assign([
				FlowPhase.BRAKING_ZONE,
				FlowPhase.SWITCHBACK,
				FlowPhase.RECOVERY_FLAT,
				FlowPhase.BRAKING_ZONE,
				FlowPhase.SWITCHBACK,
				FlowPhase.RECOVERY_FLAT,
				FlowPhase.CREST_MICRO_DROP,
				FlowPhase.RECOVERY_FLAT,
				FlowPhase.CRUISE_DOWNHILL
			])
		_:
			_setup_initial_dramatic_sequence()

## Exports the current authored phase queue as a pure route-planning contract.
## This reads grammar state only; it does not consume RNG or advance the queue.
func build_route_intent(
	world_seed: int,
	route_identity: String,
	branch_id: int,
	global_start_distance_m: float
) -> RefCounted:
	var intent = RouteIntentClass.new()
	var planned_phases: Array[int] = phase_queue.duplicate()
	var envelopes: Array[Dictionary] = []
	for phase_id: int in planned_phases:
		var spec: PhaseSpec = get_phase_spec(phase_id)
		envelopes.append({
			"phase_id": phase_id,
			"min_slope_deg": spec.min_slope_deg,
			"max_slope_deg": spec.max_slope_deg,
			"target_speed_kmh": spec.target_speed_kmh,
			"min_length_m": spec.min_length_m,
			"max_length_m": spec.max_length_m,
			"min_radius_m": spec.min_radius_m,
			"sight_distance_m": spec.sight_distance_m,
			"surface_mode": spec.surface_mode,
			"banking_angle_deg": spec.banking_angle_deg
		})
	intent.configure(world_seed, route_identity, branch_id, route_style, route_style_seed,
		global_start_distance_m, planned_phases, envelopes)
	return intent

## Guarantees that the next generated chunk is a clear, low-risk fork approach.
func queue_fork_approach() -> void:
	phase_queue.push_front(FlowPhase.BRAKING_ZONE)

## Advances FSM and returns the next PhaseSpec envelope
func advance_phase() -> PhaseSpec:
	if phase_queue.is_empty():
		if phases_since_last_feature >= MAX_PHASES_WITHOUT_FEATURE:
			# Preserve seeded freedom while avoiding long, unvaried runs: the forced
			# item is a gentle crest, never a jump or mandatory technical turn.
			phase_queue.append(FlowPhase.CREST_MICRO_DROP)
		else:
			_replenish_phase_queue()

	current_phase = phase_queue.pop_front()
	total_chunks_planned += 1
	_record_phase_for_rhythm(current_phase)
	if route_style == RouteStyle.TECHNICAL and current_phase == FlowPhase.SWITCHBACK:
		authored_switchbacks_planned += 1
		if authored_switchbacks_planned == 2:
			curve_dir *= -1.0
	return get_phase_spec(current_phase)

## Weighted FSM Transition Table with strict hard constraints
func _replenish_phase_queue() -> void:
	var roll: float = rng.randf()
	var profile: Dictionary = _get_rhythm_profile()
	var major_event_allowed: bool = _recent_major_event_count() < int(profile.major_event_limit)

	match current_phase:
		FlowPhase.FAST_GRAVITY_DESCENT:
			# Fast descent MUST NEVER transition directly to switchback or drop!
			# Always prepare with BRAKING_ZONE or decelerate to CRUISE_DOWNHILL.
			if roll < float(profile.fast_to_switchback_chance) and major_event_allowed:
				phase_queue.append(FlowPhase.BRAKING_ZONE)
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			else:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)

		FlowPhase.BRAKING_ZONE:
			# Braking zone leads to planned maneuver
			var switchback_chance: float = float(profile.braking_to_switchback_chance)
			var airborne_chance: float = float(profile.braking_to_airborne_chance)
			if major_event_allowed and roll < switchback_chance:
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			elif major_event_allowed and roll < switchback_chance + airborne_chance:
				phase_queue.append(FlowPhase.AIRBORNE_DROP)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			else:
				phase_queue.append(FlowPhase.CRUISE_DOWNHILL)

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
			var fast_chance: float = float(profile.cruise_to_fast_chance)
			var technical_chance: float = float(profile.cruise_to_technical_chance)
			var crest_chance: float = float(profile.cruise_to_crest_chance)
			if roll < fast_chance:
				phase_queue.append(FlowPhase.FAST_GRAVITY_DESCENT)
			elif roll < fast_chance + technical_chance and major_event_allowed:
				phase_queue.append(FlowPhase.BRAKING_ZONE)
				curve_dir = -1.0 if rng.randf() < 0.5 else 1.0
				phase_queue.append(FlowPhase.SWITCHBACK)
				phase_queue.append(FlowPhase.RECOVERY_FLAT)
			elif roll < fast_chance + technical_chance + crest_chance:
				phase_queue.append(FlowPhase.CREST_MICRO_DROP)
			else:
				phase_queue.append(FlowPhase.RECOVERY_FLAT)

func _get_rhythm_profile() -> Dictionary:
	match route_style:
		RouteStyle.FLOW:
			return {
				"major_event_limit": 2,
				"cruise_to_fast_chance": 0.38,
				"cruise_to_technical_chance": 0.18,
				"cruise_to_crest_chance": 0.26,
				"fast_to_switchback_chance": 0.40,
				"braking_to_switchback_chance": 0.45,
				"braking_to_airborne_chance": 0.18
			}
		RouteStyle.TECHNICAL:
			return {
				"major_event_limit": 4,
				"cruise_to_fast_chance": 0.20,
				"cruise_to_technical_chance": 0.55,
				"cruise_to_crest_chance": 0.15,
				"fast_to_switchback_chance": 0.75,
				"braking_to_switchback_chance": 0.82,
				"braking_to_airborne_chance": 0.12
			}
		_:
			return {
				"major_event_limit": 3,
				"cruise_to_fast_chance": 0.35,
				"cruise_to_technical_chance": 0.30,
				"cruise_to_crest_chance": 0.17,
				"fast_to_switchback_chance": 0.65,
				"braking_to_switchback_chance": 0.70,
				"braking_to_airborne_chance": 0.30
			}

func _record_phase_for_rhythm(phase: int) -> void:
	recent_phase_history.append(phase)
	if recent_phase_history.size() > RHYTHM_WINDOW_PHASES:
		recent_phase_history.pop_front()
	if phase in [FlowPhase.CREST_MICRO_DROP, FlowPhase.SWITCHBACK, FlowPhase.AIRBORNE_DROP]:
		phases_since_last_feature = 0
	else:
		phases_since_last_feature += 1

func _recent_major_event_count() -> int:
	var count: int = 0
	for phase: int in recent_phase_history:
		if phase in [FlowPhase.SWITCHBACK, FlowPhase.AIRBORNE_DROP]:
			count += 1
	return count

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
