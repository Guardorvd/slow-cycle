class_name RoadGenerationContract
extends RefCounted

## Slow Cycle — Road Generation Contract (v5.1.0)
## Formal mathematical specification of road geometry invariants, gradients,
## curvature derivatives, sampling resolution, and seam continuity tolerances.

const ROAD_GENERATION_CONTRACT_VERSION := "5.1.0"

# --- 1. GRADE & SLOPE LIMITS (DEGREES) ---
const MAX_GRADE_UPHILL: float = 5.0 ## Maximum uphill climb angle (human pedaling limit)
const MAX_GRADE_DOWNHILL: float = -14.0 ## Maximum downhill gravity descent angle (hard limit)
const CRUISE_GRADE: float = -6.0 ## Ideal natural cruising descent slope
const PREF_DOWNHILL_MIN: float = -4.0 ## Comfortable cruising corridor upper bound
const PREF_DOWNHILL_MAX: float = -8.0 ## Comfortable cruising corridor lower bound
const EXTREME_DOWNHILL_THRESHOLD: float = -12.0 ## Grade below which a BRAKING_ZONE is mandatory

# --- 2. ARC-LENGTH DERIVATIVES (PER METER OF REAL ARC LENGTH Δs) ---
## Maximum rate of slope change per meter: |grade_i - grade_{i-1}| / Δs <= 1.2 deg/m
const MAX_GRADE_CHANGE_PER_METER: float = 1.2
## Maximum rate of horizontal curvature change per meter: |k_i - k_{i-1}| / Δs <= 0.003 m^-2
const MAX_CURVATURE_CHANGE_PER_METER: float = 0.003

# --- 3. CURVATURE & RADIUS ENVELOPES (METERS) ---
const MIN_RADIUS: float = 18.0 ## Physical minimum switchback radius (tested in 4K T4)
const MAX_CURVATURE: float = 1.0 / 18.0 ## 1 / MIN_RADIUS ≈ 0.055556 m^-1
const HIGH_SPEED_MIN_RADIUS: float = 25.0 ## Minimum curve radius at 40 km/h to prevent scrub > 1.8 m/s²

# --- 4. SAMPLING RESOLUTION & DISCRETIZATION (METERS) ---
const NOMINAL_SAMPLE_SPACING: float = 2.0 ## Standard spline discretization step
const MAX_SAMPLE_SPACING: float = 2.5 ## Maximum gap between consecutive samples before flagged as error

# --- 5. SIGHT DISTANCE ENVELOPES (METERS) ---
const TURN_SIGHT_DISTANCE_40KMH: float = 45.0 ## Required clear sightline before a sharp curve (R < 30m)
const DROP_SIGHT_DISTANCE_40KMH: float = 35.0 ## Required line of sight to drop lip from approach zone

# --- 6. GEOMETRIC SEAM TOLERANCES (CHUNK BOUNDARIES) ---
const MAX_SEAM_POS_ERROR: float = 0.001 ## 1.0 mm (strictly prevents trimesh collision lips)
const MAX_SEAM_TANGENT_ANGLE_DEG: float = 0.2 ## Maximum tangent heading deviation
const MAX_SEAM_SLOPE_DELTA_DEG: float = 0.1 ## Maximum vertical slope step
const MAX_SEAM_NORMAL_ANGLE_DEG: float = 0.5 ## Maximum surface normal deviation

# --- 7. CROSS-SECTION & BANKING ---
const ROAD_STANDARD_WIDTH: float = 4.0 ## Standard packed gravel road width
const ROAD_FORK_EXPANDED_WIDTH: float = 10.0 ## Maximum expanded width before a fork bifurcation
const MAX_BANKING_ANGLE_DEG: float = 8.0 ## Maximum visual superelevation/banking angle

# --- HELPER / VALIDATION CALCULATION METHODS ---

## Computes required sight distance for stopping at speed v (m/s) with reaction time and comfort braking.
static func calculate_required_turn_sight_distance(speed_kmh: float) -> float:
	var v_ms: float = speed_kmh / 3.6
	var a_brake_comfort: float = 2.2 # m/s²
	var t_react: float = 0.8 # seconds
	var stopping_dist: float = (v_ms * v_ms) / (2.0 * a_brake_comfort) + v_ms * t_react
	return maxf(20.0, stopping_dist)

## Computes required drop sight distance from approach zone
static func calculate_required_drop_sight_distance(speed_kmh: float) -> float:
	var v_ms: float = speed_kmh / 3.6
	var a_brake_medium: float = 3.0 # m/s²
	var t_react: float = 0.7 # seconds
	var dist: float = (v_ms * v_ms) / (2.0 * a_brake_medium) + v_ms * t_react
	return maxf(15.0, dist)

## Computes lateral acceleration for given speed and radius: a_lat = v^2 / R
static func calculate_lateral_accel(speed_kmh: float, radius: float) -> float:
	if radius <= 0.001:
		return 999.0
	var v_ms: float = speed_kmh / 3.6
	return (v_ms * v_ms) / radius

## Checks if slope angle in degrees is within safe bounds [-14.0, +5.0]
static func is_slope_within_bounds(slope_deg: float) -> bool:
	return slope_deg >= (MAX_GRADE_DOWNHILL - 0.01) and slope_deg <= (MAX_GRADE_UPHILL + 0.01)

## Checks if radius is safe (>= 18.0m)
static func is_radius_within_bounds(radius: float) -> bool:
	return radius >= (MIN_RADIUS - 0.05)
