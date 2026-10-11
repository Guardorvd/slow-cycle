class_name RoadSynthesisPolicy
extends RefCounted

## Regional road policy `regional_road/2` (PR1 D2/D3; R6 ExecPlan v1.0 §6 +
## Director conditions C1-C5 for everything not changed here). The single
## source of class limits for R5 (coarse feasibility) and R6 (synthesis):
## class grade/radius/width/earthwork envelopes, retained global continuity
## limits, crossing and junction bounds, search budgets, outcome and reason
## vocabulary. The legacy RoadGenerationContract / RoadValidityValidator are
## not changed or used as the R6 certificate.
##
## v2 (PR1 M1 measurement of the existing BicycleController, Input-driven, on
## registered trimesh ramps; evidence MEASUREMENT below): climbing is limited
## three ways - a sustained grade over SUSTAINED_WINDOW_M held with the pedal
## at >= V_CLIMB_MS, a pointwise pitch grade and a pitch length from the
## measured table (entering at cruise, relaxed sprint taps) - and descents by
## descent_max. Climb limits only ever lower the A2 values; the one explicit
## raise is the TECHNICAL descent cap 15 deg with earthwork 3 / 2 / 8 m (R6 §19).
## grade_hard_deg is the pointwise |grade| ceiling in either direction
## (= max(climb_pitch, descent_max)); direction-specific climb limits are the
## validator's `_climb` stage. BACKBONE / SECONDARY are bidirectional;
## SINGLETRACK / TECHNICAL may be designed descent-preferred (climb limits in
## the recommended direction only) when the realized network keeps an easier
## connection between the same nodes.
##
## Grades are ratios (rise / horizontal run) unless named *_deg. Class index
## = RegionRouteGraph.RouteClass.

const POLICY_ID := "regional_road/2"
const RESULT_SCHEMA := "slow_cycle.road_synthesis_result/1"
const PLAN_SCHEMA := "slow_cycle.road_synthesis_plan/1"
const INTENT_SCHEMA := "slow_cycle.roadbed_intent/1"
const ALGORITHM := "road_synthesis/2;lattice_dp+fairing+g2_quintic+reachability_profile+climb_stage+speed_junctions"

enum Status { READY, PARTIAL, REPLAN_REQUIRED, REJECT, FAIL }
const STATUS_NAMES := ["READY", "PARTIAL", "REPLAN_REQUIRED", "REJECT", "FAIL"]
## Junction states (C1): READY = every movement available; USABLE = every
## essential (route-continuity) movement available, some turn movement
## explicitly unavailable; BLOCKED = an essential movement or the shared
## patch failed. Only READY counts towards a READY plan.
const JUNCTION_READY := "READY"
const JUNCTION_USABLE := "USABLE"
const JUNCTION_BLOCKED := "BLOCKED"
const MOVEMENT_READY := "READY"
const MOVEMENT_UNAVAILABLE := "UNAVAILABLE"

## Feature realisation states (§12).
const REALIZED := "REALIZED"
const REJECTED := "REJECTED"
const REPLACED_EXPLICITLY := "REPLACED_EXPLICITLY"

## Roadbed support kinds (§9).
enum Support { EARTHWORK, FORD, BRIDGE_DECK, JUNCTION_PATCH }
const SUPPORT_NAMES := ["EARTHWORK", "FORD", "BRIDGE_DECK", "JUNCTION_PATCH"]

const REASONS: Array[String] = [
	"ERR_R6_INPUT_MISSING", "ERR_R6_INPUT_INVALID", "ERR_R6_INPUT_MISMATCH", "ERR_R6_SCHEMA", "ERR_R6_CONFIG",
	"ERR_R6_NONFINITE", "ERR_R6_FRAME", "ERR_R6_PATH_STRUCTURE", "ERR_R6_CORRIDOR_CLEARANCE", "ERR_R6_GRADE",
	"ERR_R6_CURVATURE", "ERR_R6_GRADE_TRANSITION", "ERR_R6_NATURAL_BARRIER", "ERR_R6_EARTHWORK",
	"ERR_R6_CROSSING_MISSING", "ERR_R6_CROSSING_PHANTOM", "ERR_R6_CROSSING_EXTRA", "ERR_R6_CROSSING_DISPLACED",
	"ERR_R6_WATER_OCCUPANCY", "ERR_R6_WATER_BODY", "ERR_R6_CROSSING_APPROACH", "ERR_R6_CROSSING_SUPPORT",
	"ERR_R6_JUNCTION_HEIGHT", "ERR_R6_JUNCTION_MOVEMENT", "ERR_R6_UNPLANNED_INTERSECTION", "ERR_R6_SEAM",
	"ERR_R6_DUPLICATE_PIECE", "ERR_R6_FEATURE_UNREALIZED", "ERR_R6_APPROACH", "ERR_R6_SEARCH_BUDGET",
	"ERR_R6_CERTIFICATION_UNRESOLVED", "ERR_R6_PRECISION", "ERR_R6_BANK", "ERR_R6_SAMPLING", "ERR_R6_INTERNAL",
	"ERR_R6_CLI_ARGUMENT", "ERR_R6_SUSTAINED_GRADE", "ERR_R6_PITCH_LENGTH"]

## Per class: grade preference band and hard limit (ratio), radii (m), riding
## width (m), shoulders (m), earthwork bounds (m), daylight tie-in reach per
## side (m), documented design speed (km/h; design metadata only), bank cap.
const CLASSES: Array[Dictionary] = [
	{"name": "BACKBONE", "grade_pref_lo": 0.04, "grade_pref": 0.06, "grade_hard_deg": 5.0, "radius_pref_m": 80.0, "radius_hard_m": 35.0,
		"width_m": 3.6, "width_min_m": 3.0, "width_max_m": 4.5, "shoulder_m": 0.75, "cut_max_m": 3.0, "fill_max_m": 2.0, "tie_max_m": 12.0,
		"design_speed_kmh": 30.0, "bank_max_deg": 5.0,
		"climb_sustained_deg": 5.0, "climb_pitch_deg": 5.0, "descent_max_deg": 5.0, "descent_pref": 0.06, "descent_preferred": false, "surface": "gravel"},
	{"name": "SECONDARY", "grade_pref_lo": 0.06, "grade_pref": 0.085, "grade_hard_deg": 8.0, "radius_pref_m": 45.0, "radius_hard_m": 25.0,
		"width_m": 2.8, "width_min_m": 2.2, "width_max_m": 3.6, "shoulder_m": 0.5, "cut_max_m": 3.0, "fill_max_m": 2.0, "tie_max_m": 10.0,
		"design_speed_kmh": 28.0, "bank_max_deg": 6.0,
		"climb_sustained_deg": 6.0, "climb_pitch_deg": 8.0, "descent_max_deg": 8.0, "descent_pref": 0.085, "descent_preferred": false, "surface": "gravel"},
	{"name": "SINGLETRACK", "grade_pref_lo": 0.06, "grade_pref": 0.08, "grade_hard_deg": 10.0, "radius_pref_m": 28.0, "radius_hard_m": 19.0,
		"width_m": 1.8, "width_min_m": 1.3, "width_max_m": 2.0, "shoulder_m": 0.3, "cut_max_m": 1.5, "fill_max_m": 1.0, "tie_max_m": 6.0,
		"design_speed_kmh": 24.0, "bank_max_deg": 6.0,
		"climb_sustained_deg": 5.5, "climb_pitch_deg": 10.0, "descent_max_deg": 10.0, "descent_pref": 0.14, "descent_preferred": true, "surface": "rough"},
	{"name": "TECHNICAL", "grade_pref_lo": 0.06, "grade_pref": 0.08, "grade_hard_deg": 15.0, "radius_pref_m": 22.0, "radius_hard_m": 19.0,
		"width_m": 1.5, "width_min_m": 1.3, "width_max_m": 1.8, "shoulder_m": 0.25, "cut_max_m": 3.0, "fill_max_m": 2.0, "tie_max_m": 8.0,
		"design_speed_kmh": 20.0, "bank_max_deg": 6.0,
		"climb_sustained_deg": 5.5, "climb_pitch_deg": 12.0, "descent_max_deg": 15.0, "descent_pref": 0.18, "descent_preferred": true, "surface": "rough"},
]

# --- Measured riding envelope (PR1 M1, policy v2 inputs) ---
## Evidence: test_ride_envelope.gd --group=all (run m1_envelope_all_final),
## existing BicycleController/bicycle.tscn, 60 Hz, Input actions only.
const MEASUREMENT := "pr1-m1/test_ride_envelope/all(m1_envelope_all_final);v_climb=2.0;sustained=gravel:6.02,rough:5.58,grass:3.58;descent_hold8=15;lateral=2.45;r_low=7.99;brake=5.47"
const V_CLIMB_MS: float = 2.0
const SUSTAINED_WINDOW_M: float = 100.0
## Pitch length above v_climb by grade (deg -> m), entering at cruise with one
## sprint tap per 2 s; below the first grade the run outlasted the measured
## horizon (PITCH_HORIZON_M), which then bounds it. Values floored to 1 m.
const PITCH_HORIZON_M: float = 320.0
const PITCH_LENGTH_M: Dictionary = {
	"gravel": [[8.0, 320.0], [9.0, 42.0], [10.0, 30.0], [12.0, 23.0], [15.0, 18.0]],
	"rough": [[7.0, 320.0], [8.0, 61.0], [9.0, 37.0], [10.0, 29.0], [12.0, 22.0], [15.0, 18.0]],
}
## Junction movement kinematics (D3): steady lateral design load, comfortable
## approach braking, low-speed minimum radius and the slowest movement speed.
const MOVEMENT_LATERAL_MS2: float = 2.4
const MOVEMENT_BRAKE_MS2: float = 2.0
const MOVEMENT_RADIUS_LOW_M: float = 8.0
const MOVEMENT_SPEED_FLOOR_MS: float = 3.0

# --- Retained global geometry limits (§6) ---
const MAX_GRADE_CHANGE_DEG_PER_M: float = 1.2
const MAX_CURVATURE_CHANGE_PER_M2: float = 0.003
const MAX_BANK_DEG: float = 8.0
const NOMINAL_SAMPLE_M: float = 2.0
const MAX_SAMPLE_M: float = 2.5
const MIN_SUBDIVISION_M: float = 0.125
const CHORD_ERROR_M: float = 0.01
const SEAM_POSITION_M: float = 0.001
const SEAM_TANGENT_DEG: float = 0.2
const SEAM_GRADE_DEG: float = 0.1
const SEAM_NORMAL_DEG: float = 0.5
## Stylised side slopes: cut 1 V : 1 H, fill 1 V : 2 H (upper bounds).
const CUT_SIDE_SLOPE: float = 1.0
const FILL_SIDE_SLOPE: float = 0.5

# --- Junctions (§7 + C1) ---
## Candidate port radii from the node (per incident edge, inside the 96 m
## junction zone); each edge starts at the smallest and grows only while an
## essential movement it takes part in does not fit (bounded, finite).
const PORT_RADII_M: Array[float] = [14.0, 20.0, 28.0, 38.0, 50.0, 64.0, 80.0, 96.0]
## Ports beyond this radius need the proven D3 conditions (band union, no
## conflict, no crossing, earthwork, continuity) before a movement uses them.
const PORT_RADIUS_PLAIN_M: float = 64.0
const JUNCTION_ZONE_M: float = 96.0
## Shared patch plane: gently graded (C1: no forced flat platform on a slope):
## at most the stricter incident class's preferred grade, never above this
## ceiling (its crossfall stays below ~6 deg on any connector).
const PATCH_GRADE_MAX: float = 0.10
const PATCH_RING_SAMPLES: int = 16

# --- Water (§8 + C2) ---
const FORD_MAX_DEPTH_M: float = 0.35
const DECK_CLEARANCE_M: float = 1.0
const DECK_STRUCTURE_M: float = 0.5
const BRIDGE_BEARING_M: float = 2.0
const BRIDGE_MAX_SPAN_M: float = 80.0
const SMALL_BRIDGE_MAX_SPAN_M: float = 12.0
## C2 crossing adjustment envelope, fixed before implementation: same channel,
## <= 12 m from the R5 pin, inside the R5 band. Displacement > 2 cm is
## recorded with its justification.
const CROSSING_MAX_DISPLACEMENT_M: float = 12.0
const CROSSING_RECORD_TOLERANCE_M: float = 0.02
const CROSSING_QUERY_SEGMENT_M: float = 64.0

# --- Sight / approach (§6) ---
const EYE_HEIGHT_M: float = 1.4
const OBJECT_HEIGHT_M: float = 0.4
const SIGHT_MAX_M: float = 120.0
const SIGHT_STEP_M: float = 10.0
const SIGHT_STATION_M: float = 10.0

# --- Search and work budgets (§5) ---
const MAX_CANDIDATES_PER_SPAN: int = 12
const MAX_FIT_EVALUATIONS: int = 200000
const MAX_NATURAL_QUERIES: int = 2000000
const MAX_FINAL_SAMPLES: int = 250000
const FIT_SWEEPS: int = 3
const FIT_ITERATIONS: int = 6
## Natural search grid: world-anchored lattice used only for candidate search;
## final geometry is certified with exact point queries.
const SEARCH_GRID_M: float = 8.0

## Settings accepted by RoadSynthesizer.synthesize (versioned, finite, in range).
const SETTINGS_SCHEMA := "slow_cycle.road_synthesis_settings/1"
const SETTINGS_RANGES := {
	"max_fit_evaluations": [1000, MAX_FIT_EVALUATIONS],
	"max_natural_queries": [10000, MAX_NATURAL_QUERIES],
	"max_final_samples": [1000, MAX_FINAL_SAMPLES],
}


static func grade_hard(route_class: int) -> float:
	return tan(deg_to_rad(CLASSES[route_class].grade_hard_deg))


static func curvature_hard(route_class: int) -> float:
	return 1.0 / CLASSES[route_class].radius_hard_m


static func half_footprint(route_class: int) -> float:
	return 0.5 * CLASSES[route_class].width_m + CLASSES[route_class].shoulder_m


static func climb_sustained(route_class: int) -> float:
	return tan(deg_to_rad(CLASSES[route_class].climb_sustained_deg))


static func climb_pitch(route_class: int) -> float:
	return tan(deg_to_rad(CLASSES[route_class].climb_pitch_deg))


static func descent_max(route_class: int) -> float:
	return tan(deg_to_rad(CLASSES[route_class].descent_max_deg))


## Longest climb run steeper than the sustained grade whose steepest grade is
## `grade_deg` (measured table of the class surface, linear between rows).
static func pitch_length_limit(route_class: int, grade_deg: float) -> float:
	var rows: Array = PITCH_LENGTH_M[CLASSES[route_class].surface]
	if grade_deg <= rows[0][0]:
		return PITCH_HORIZON_M
	for k in range(1, rows.size()):
		if grade_deg <= rows[k][0]:
			var t: float = (grade_deg - rows[k - 1][0]) / (rows[k][0] - rows[k - 1][0])
			return lerpf(rows[k - 1][1], rows[k][1], t)
	return 0.0


## Steepest natural cross slope on which the class roadbed can be built at all:
## the edge heights 2 hf sx apart must fit inside the class cut bound and inside
## the cut the class tie-in reach can daylight (cut slope 1:1). Shared by R5
## (node closure) and R6 (lattice / bench condition).
const CROSS_LIMIT_SHARE: float = 0.97
const SLOPE_BLOCK: float = 0.9


static func cross_limit(route_class: int) -> float:
	var cls: Dictionary = CLASSES[route_class]
	var hf: float = half_footprint(route_class)
	return CROSS_LIMIT_SHARE * minf(cls.cut_max_m / (2.0 * hf), cls.tie_max_m / (cls.tie_max_m + 2.0 * hf))


## Steepest natural slope the class can be built on in any direction: a road at
## grade g across slope s has cross slope sqrt(s^2 - g^2) (g = pointwise hard).
static func buildable_slope(route_class: int) -> float:
	return traverse_slope(route_class, grade_hard(route_class))


## Steepest natural slope a contour traverse of the class can climb across at
## `grade`: its cross slope sqrt(s^2 - g^2) must stay within cross_limit.
static func traverse_slope(route_class: int, grade: float) -> float:
	var c: float = cross_limit(route_class)
	return minf(SLOPE_BLOCK, sqrt(grade * grade + c * c))


## D3 movement kinematics: design speed of a movement entering from a road of
## class `in_class` with `approach_m` of braking room, leaving onto `out_class`.
static func movement_speed(in_class: int, out_class: int, approach_m: float) -> float:
	var v_in: float = CLASSES[in_class].design_speed_kmh / 3.6
	var v_out: float = CLASSES[out_class].design_speed_kmh / 3.6
	var reachable: float = sqrt(maxf(0.0, v_in * v_in - 2.0 * MOVEMENT_BRAKE_MS2 * maxf(approach_m, 0.0)))
	return minf(minf(v_in, v_out), maxf(MOVEMENT_SPEED_FLOOR_MS, reachable))


static func movement_radius(speed_ms: float) -> float:
	return maxf(MOVEMENT_RADIUS_LOW_M, speed_ms * speed_ms / MOVEMENT_LATERAL_MS2)


## Validates a settings dictionary; returns {is_valid, reason_code, settings}
## with every recognised key resolved (defaults are the policy ceilings).
static func resolve_settings(settings: Variant) -> Dictionary:
	var resolved := {"max_fit_evaluations": MAX_FIT_EVALUATIONS, "max_natural_queries": MAX_NATURAL_QUERIES, "max_final_samples": MAX_FINAL_SAMPLES}
	if not settings is Dictionary:
		return {"is_valid": false, "reason_code": "ERR_R6_SCHEMA", "settings": {}}
	for key: Variant in settings:
		if not key is String:
			return {"is_valid": false, "reason_code": "ERR_R6_SCHEMA", "settings": {}}
		if key == "schema":
			if settings[key] != SETTINGS_SCHEMA:
				return {"is_valid": false, "reason_code": "ERR_R6_SCHEMA", "settings": {}}
			continue
		if not SETTINGS_RANGES.has(key):
			return {"is_valid": false, "reason_code": "ERR_R6_SCHEMA", "settings": {}}
		var value: Variant = settings[key]
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)):
			return {"is_valid": false, "reason_code": "ERR_R6_CONFIG", "settings": {}}
		var bounds: Array = SETTINGS_RANGES[key]
		if int(value) < bounds[0] or int(value) > bounds[1]:
			return {"is_valid": false, "reason_code": "ERR_R6_CONFIG", "settings": {}}
		resolved[key] = int(value)
	return {"is_valid": true, "reason_code": "", "settings": resolved}


## Canonical text of the policy (digest input): every bound that shapes output.
static func canonical_text() -> String:
	var text: String = POLICY_ID + "\n" + ALGORITHM + "\n"
	for c: Dictionary in CLASSES:
		var keys: Array = c.keys()
		keys.sort()
		for key: Variant in keys:
			text += "%s.%s=%s\n" % [c.name, key, str(c[key])]
	for pair: Array in [["grade_change", MAX_GRADE_CHANGE_DEG_PER_M], ["curvature_change", MAX_CURVATURE_CHANGE_PER_M2], ["bank", MAX_BANK_DEG],
			["sample", MAX_SAMPLE_M], ["nominal", NOMINAL_SAMPLE_M], ["chord", CHORD_ERROR_M], ["seam", SEAM_POSITION_M], ["port_radii", PORT_RADII_M],
			["patch_grade", PATCH_GRADE_MAX], ["ford_depth", FORD_MAX_DEPTH_M], ["deck", DECK_CLEARANCE_M + DECK_STRUCTURE_M], ["bearing", BRIDGE_BEARING_M],
			["span", [BRIDGE_MAX_SPAN_M, SMALL_BRIDGE_MAX_SPAN_M]], ["crossing_shift", CROSSING_MAX_DISPLACEMENT_M], ["sight", [EYE_HEIGHT_M, OBJECT_HEIGHT_M, SIGHT_MAX_M]],
			["search_grid", SEARCH_GRID_M], ["side_slopes", [CUT_SIDE_SLOPE, FILL_SIDE_SLOPE]], ["measurement", MEASUREMENT], ["v_climb", V_CLIMB_MS],
			["sustained_window", SUSTAINED_WINDOW_M], ["pitch_length", PITCH_LENGTH_M], ["pitch_horizon", PITCH_HORIZON_M],
			["movement", [MOVEMENT_LATERAL_MS2, MOVEMENT_BRAKE_MS2, MOVEMENT_RADIUS_LOW_M, MOVEMENT_SPEED_FLOOR_MS]], ["port_plain", PORT_RADIUS_PLAIN_M],
			["cross_share", [CROSS_LIMIT_SHARE, SLOPE_BLOCK]]]:
		text += "%s=%s\n" % [pair[0], str(pair[1])]
	return text


static func digest() -> String:
	return canonical_text().sha256_text()
