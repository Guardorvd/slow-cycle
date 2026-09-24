class_name RoadKinematicModel
extends RefCounted

## Slow Cycle — Road Kinematic Model (v1.0.0)
## Pure mathematical utility providing the canonical source of truth for
## longitudinal bicycle deceleration, slope-compensated braking distance,
## and lateral cornering velocity envelopes across all world and road systems.

enum BrakingRegime {
	COMFORT = 0,    ## 2.2 m/s², t_react = 0.8s (sightlines, comfortable cruising)
	NORMAL = 1,     ## 3.5 m/s², t_react = 0.5s (controlled braking zone before turns/forks)
	EMERGENCY = 2   ## 5.5 m/s², t_react = 0.3s (maximum adhesion limit before wheel lockup)
}

const A_BRAKE_COMFORT: float = 2.2      ## m/s²
const A_BRAKE_NORMAL: float = 3.5       ## m/s²
const A_BRAKE_EMERGENCY: float = 5.5    ## m/s²

const T_REACT_COMFORT: float = 0.8      ## seconds
const T_REACT_NORMAL: float = 0.5       ## seconds
const T_REACT_EMERGENCY: float = 0.3    ## seconds

const MIN_USABLE_DECELERATION: float = 0.5 ## m/s² (below this, slope runaway occurs)
const GRAVITY: float = 9.80665          ## m/s²

## Result data contract for braking distance evaluation
class BrakingEvaluation extends RefCounted:
	var is_valid: bool = true
	var distance_m: float = 0.0
	var effective_deceleration: float = 0.0
	var reaction_distance_m: float = 0.0
	var braking_ramp_distance_m: float = 0.0
	var regime: int = BrakingRegime.NORMAL
	var status: String = "OK" # "OK", "ZERO_BRAKING_NEEDED", "BRAKING_PHYSICALLY_INSUFFICIENT"

## Computes effective deceleration on a given slope grade (degrees).
## For downhill (slope_deg < 0), gravity opposes braking: a_eff = a_base + g * sin(slope).
static func calculate_effective_deceleration(regime: int, slope_deg: float) -> float:
	var a_base: float = A_BRAKE_NORMAL
	match regime:
		BrakingRegime.COMFORT:
			a_base = A_BRAKE_COMFORT
		BrakingRegime.EMERGENCY:
			a_base = A_BRAKE_EMERGENCY

	var slope_rad: float = deg_to_rad(slope_deg)
	# Downhill slope_deg < 0 => sin(slope_rad) < 0 => reduces effective deceleration
	return a_base + GRAVITY * sin(slope_rad)

## Calculates total stopping or speed-matching distance from v_entry down to v_target (in m/s).
## Returns a BrakingEvaluation contract.
static func calculate_braking_distance(
	v_entry_mps: float,
	v_target_mps: float,
	slope_deg: float,
	regime: int = BrakingRegime.NORMAL
) -> BrakingEvaluation:
	var result := BrakingEvaluation.new()
	result.regime = regime

	# Invariant 1: If entry speed is already at or below target speed, zero braking is required
	if v_entry_mps <= v_target_mps:
		result.is_valid = true
		result.distance_m = 0.0
		result.effective_deceleration = calculate_effective_deceleration(regime, slope_deg)
		result.reaction_distance_m = 0.0
		result.braking_ramp_distance_m = 0.0
		result.status = "ZERO_BRAKING_NEEDED"
		return result

	var t_react: float = T_REACT_NORMAL
	match regime:
		BrakingRegime.COMFORT:
			t_react = T_REACT_COMFORT
		BrakingRegime.EMERGENCY:
			t_react = T_REACT_EMERGENCY

	var a_eff: float = calculate_effective_deceleration(regime, slope_deg)
	result.effective_deceleration = a_eff

	# Invariant 2: Runaway slope protection. Do NOT mask insufficient braking with an arbitrary clamp
	if a_eff <= MIN_USABLE_DECELERATION:
		result.is_valid = false
		result.distance_m = INF
		result.reaction_distance_m = v_entry_mps * t_react
		result.braking_ramp_distance_m = INF
		result.status = "BRAKING_PHYSICALLY_INSUFFICIENT"
		return result

	result.reaction_distance_m = v_entry_mps * t_react
	result.braking_ramp_distance_m = (v_entry_mps * v_entry_mps - v_target_mps * v_target_mps) / (2.0 * a_eff)
	result.distance_m = result.reaction_distance_m + result.braking_ramp_distance_m
	result.is_valid = true
	result.status = "OK"
	return result

## Computes safe curve speed (in m/s) given horizontal curve radius R (in meters)
## and maximum permissible lateral acceleration before tire scrub (default 1.8 m/s²).
static func calculate_safe_curve_speed(radius_m: float, max_lat_accel: float = 1.8) -> float:
	if radius_m <= 0.0:
		return 0.0
	return sqrt(max_lat_accel * radius_m)

## Helper to convert km/h to m/s
static func kmh_to_mps(speed_kmh: float) -> float:
	return speed_kmh / 3.6

## Helper to convert m/s to km/h
static func mps_to_kmh(speed_mps: float) -> float:
	return speed_mps * 3.6
