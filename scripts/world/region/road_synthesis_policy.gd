class_name RoadSynthesisPolicy
extends RefCounted

## R6 regional road policy `regional_road/1` (ExecPlan v1.0 §6 + Director
## conditions C1-C5). Versioned design bounds for road synthesis on R5
## corridors: class grade/radius/width/earthwork envelopes, retained global
## continuity limits, crossing and junction bounds, search budgets, outcome
## and reason vocabulary. A separate regional policy: the legacy
## RoadGenerationContract / RoadValidityValidator are not changed or used as
## the R6 certificate. Values are stylised Alpha design limits, not civil
## standards and not proof of bicycle performance (physical handling is R8).
##
## Grades are ratios (rise / horizontal run) unless named *_deg. Class index
## = RegionRouteGraph.RouteClass.

const POLICY_ID := "regional_road/1"
const RESULT_SCHEMA := "slow_cycle.road_synthesis_result/1"
const PLAN_SCHEMA := "slow_cycle.road_synthesis_plan/1"
const INTENT_SCHEMA := "slow_cycle.roadbed_intent/1"
const ALGORITHM := "road_synthesis/1;lattice_dp+fairing+g2_quintic+reachability_profile"

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
	"ERR_R6_CLI_ARGUMENT"]

## Per class: grade preference band and hard limit (ratio), radii (m), riding
## width (m), shoulders (m), earthwork bounds (m), daylight tie-in reach per
## side (m), documented design speed (km/h; design metadata only), bank cap.
const CLASSES: Array[Dictionary] = [
	{"name": "BACKBONE", "grade_pref_lo": 0.04, "grade_pref": 0.06, "grade_hard_deg": 5.0, "radius_pref_m": 80.0, "radius_hard_m": 35.0,
		"width_m": 3.6, "width_min_m": 3.0, "width_max_m": 4.5, "shoulder_m": 0.75, "cut_max_m": 3.0, "fill_max_m": 2.0, "tie_max_m": 12.0,
		"design_speed_kmh": 30.0, "bank_max_deg": 5.0},
	{"name": "SECONDARY", "grade_pref_lo": 0.06, "grade_pref": 0.09, "grade_hard_deg": 8.0, "radius_pref_m": 45.0, "radius_hard_m": 25.0,
		"width_m": 2.8, "width_min_m": 2.2, "width_max_m": 3.6, "shoulder_m": 0.5, "cut_max_m": 3.0, "fill_max_m": 2.0, "tie_max_m": 10.0,
		"design_speed_kmh": 28.0, "bank_max_deg": 6.0},
	{"name": "SINGLETRACK", "grade_pref_lo": 0.08, "grade_pref": 0.14, "grade_hard_deg": 10.0, "radius_pref_m": 28.0, "radius_hard_m": 19.0,
		"width_m": 1.8, "width_min_m": 1.3, "width_max_m": 2.0, "shoulder_m": 0.3, "cut_max_m": 1.5, "fill_max_m": 1.0, "tie_max_m": 6.0,
		"design_speed_kmh": 24.0, "bank_max_deg": 6.0},
	{"name": "TECHNICAL", "grade_pref_lo": 0.10, "grade_pref": 0.18, "grade_hard_deg": 12.0, "radius_pref_m": 22.0, "radius_hard_m": 19.0,
		"width_m": 1.5, "width_min_m": 1.3, "width_max_m": 1.8, "shoulder_m": 0.25, "cut_max_m": 1.5, "fill_max_m": 1.0, "tie_max_m": 5.0,
		"design_speed_kmh": 20.0, "bank_max_deg": 6.0},
]

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
const PORT_RADII_M: Array[float] = [14.0, 20.0, 28.0, 38.0, 50.0, 64.0]
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
			["search_grid", SEARCH_GRID_M], ["side_slopes", [CUT_SIDE_SLOPE, FILL_SIDE_SLOPE]]]:
		text += "%s=%s\n" % [pair[0], str(pair[1])]
	return text


static func digest() -> String:
	return canonical_text().sha256_text()
