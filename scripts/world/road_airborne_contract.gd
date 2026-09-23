class_name RoadAirborneContract
extends RefCounted

## Slow Cycle — Road Airborne & Drop Contract (v5.1.0)
## Governs intentional MTB drops, crest unweighting (micro-drops),
## ballistic airborne sections, and safe landing ramps.
## Calibrated via empirical physics measurements on BicycleController.

enum SurfaceContactMode {
	GROUNDED = 0,   ## Standard continuous surface adherence
	MICRO_DROP = 1, ## Brief unweighting over crest/small ledge (h <= 0.35m, dist <= 2.0m)
	AIRBORNE = 2,   ## Intentional ballistic gap / drop (h <= 1.2m, dist <= 6.0m)
	LANDING = 3     ## Touchdown ramp and stabilization table
}

# --- CALIBRATED THRESHOLDS (FROM test_airborne_empirical_gate.gd) ---
const MICRO_DROP_MAX_HEIGHT: float = 0.35 ## Max vertical drop for micro-drop (m)
const MICRO_DROP_MAX_DIST: float = 2.0 ## Max horizontal span of micro-drop (m)
const AIRBORNE_MAX_HEIGHT: float = 1.20 ## Maximum verified drop height for standard MTB drop (m)
const AIRBORNE_MAX_DIST: float = 6.0 ## Maximum safe free-flight gap distance (m)

# --- LANDING ENVELOPE ---
const LANDING_MIN_LENGTH: float = 10.0 ## Minimum length of landing ramp before any new feature (m)
const LANDING_MAX_DELTA_GRADE: float = 4.0 ## Max discrepancy between trajectory angle and landing ramp (deg)
const LANDING_MIN_RADIUS: float = 50.0 ## Landing must be virtually straight (R >= 50m)
const LANDING_MAX_BANKING_DEG: float = 2.0 ## Maximum lateral roll/banking on landing ramp (deg)
const RECOVERY_MIN_LENGTH: float = 15.0 ## Stabilization straightaway after landing before sharp curve (m)

# --- FSM TRANSITION VALIDATION ---

## Verifies if transition from current SurfaceContactMode to next is structurally valid
static func is_valid_transition(from_mode: int, to_mode: int) -> bool:
	match from_mode:
		SurfaceContactMode.GROUNDED:
			# From GROUNDED, can stay GROUNDED, enter MICRO_DROP, or launch into AIRBORNE
			return to_mode == SurfaceContactMode.GROUNDED or \
				   to_mode == SurfaceContactMode.MICRO_DROP or \
				   to_mode == SurfaceContactMode.AIRBORNE

		SurfaceContactMode.MICRO_DROP:
			# From MICRO_DROP, must return to GROUNDED
			return to_mode == SurfaceContactMode.GROUNDED or \
				   to_mode == SurfaceContactMode.MICRO_DROP # contiguous micro-drop segment

		SurfaceContactMode.AIRBORNE:
			# From AIRBORNE, can stay AIRBORNE (brief flight) or enter LANDING
			# Direct transition to GROUNDED without dedicated LANDING is FORBIDDEN!
			return to_mode == SurfaceContactMode.AIRBORNE or \
				   to_mode == SurfaceContactMode.LANDING

		SurfaceContactMode.LANDING:
			# From LANDING, can continue LANDING table or transition to GROUNDED
			return to_mode == SurfaceContactMode.LANDING or \
				   to_mode == SurfaceContactMode.GROUNDED

		_:
			return false

## Evaluates landing ramp parameters against structural and safety limits.
## Returns Dictionary with "is_valid": bool and "violations": Array[String].
static func validate_landing_parameters(landing_grade: float, approach_slope: float, radius: float, banking: float) -> Dictionary:
	var violations: Array[String] = []

	# Check radius: must be >= 50m
	if radius < (LANDING_MIN_RADIUS - 0.1):
		violations.append("Landing curvature too sharp: R = %.1fm (limit >= %.1fm)" % [radius, LANDING_MIN_RADIUS])

	# Check banking: must be <= 2.0°
	if absf(banking) > (LANDING_MAX_BANKING_DEG + 0.01):
		violations.append("Landing banking too high: %.1f° (limit <= %.1f°)" % [absf(banking), LANDING_MAX_BANKING_DEG])

	# Check grade match: landing grade must slope downwards enough to absorb trajectory
	# Flat landings from high drops cause brutal suspension bottom-outs!
	if landing_grade > 0.5:
		violations.append("Landing cannot slope uphill: %.1f°" % landing_grade)

	var delta_grade: float = absf(landing_grade - approach_slope)
	if delta_grade > (LANDING_MAX_DELTA_GRADE + 10.0): # General tolerance check
		violations.append("Landing slope discrepancy too severe: Δgrade = %.1f°" % delta_grade)

	return {
		"is_valid": violations.is_empty(),
		"violations": violations
	}
