extends RefCounted

## BC2 trail planning policy (pure data): the procedural trail classes and the
## search / screening values TrailNetworkPlanner uses to propose trails. They
## are planning values of the trail network, separate from R6's road classes
## (RoadSynthesisPolicy); the riding limits a published trail must meet stay
## those of TrailRealization, which validates every proposal. A search value
## is set inside the realization limit so a proposal is not rejected for a
## margin the search could have kept.
##
## Configuration (JSON object, e.g. res://resources/regions/bc2_trails.json):
##   {"schema": SCHEMA, "mode": "PROCEDURAL", "classes": ["SINGLETRACK"],
##    "max_trails": int | {class: int}}   (per class; classes planned in the
##    listed order, a later class keeps clear of the earlier selections)
## The configuration is seed-independent: the region (seed, geography and its
## published road network) decides where trails go.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const SCHEMA := "slow_cycle.trail_network/1"
const CLASSES: Array[String] = ["SINGLETRACK", "TECHNICAL"]
const MAX_TRAILS_LIMIT: int = 8

## Ports: stations on an edge piece at these distances (m) from one of its
## nodes, on either side of the road, PORT_OFFSET_M beyond the road edge.
const PORT_STATIONS_M: Array[float] = [45.0, 75.0, 105.0, 135.0, 165.0]
const PORT_OFFSET_M: float = 5.0
## A port keeps this distance (m) from both ends of its edge (junctions).
const PORT_END_CLEAR_M: float = 20.0
## A port keeps this distance (m) along its edge from a crossing span.
const PORT_CROSSING_CLEAR_M: float = 30.0
## Lead-out (m) from the port, skewed along the road towards the other port.
const LEAD_M: float = 10.0
const LEAD_SKEW: float = 0.7
## Extra corner-cutting passes tried while only the radius fails.
const EXTRA_SMOOTHING: int = 2
## TECHNICAL ports: every ALONG_STEP_M along a whole edge.
const ALONG_STEP_M: float = 40.0
## Band (m) around a selected trail: later trails cross it at no less than
## CROSS_SEARCH_DEG (search steps) / CROSS_SCREEN_DEG (the smoothed line),
## each crossing costing W_CROSSING per metre in the band, at most
## MAX_CROSSINGS per trail; they never run along it.
const TRAIL_CLEAR_M: float = 10.0
const CROSS_SEARCH_DEG: float = 45.0
const CROSS_SCREEN_DEG: float = 40.0
const W_CROSSING: float = 1.0
const MAX_CROSSINGS: int = 2
## TECHNICAL linked turns: (wavelength, amplitude) of the sideways offset of
## the corridor, tried in this order; turn radius ~ wavelength^2 / (4 pi^2
## amplitude) - 14.8 m (54, 5) down to 6.8 m (40, 6); the screen decides.
const TURN_SHAPES: Array[Vector2] = [Vector2(54.0, 5.0), Vector2(54.0, 8.0), Vector2(46.0, 5.0), Vector2(46.0, 7.0), Vector2(40.0, 4.0), Vector2(40.0, 6.0), Vector2(34.0, 4.0)]
## Offsets fade in / out over this distance (m) from the lead-outs.
const TURN_FADE_M: float = 14.0
## A turn: heading change of at least TURN_MIN_DEG over TURN_WINDOW_M.
const TURN_WINDOW_M: float = 12.0
const TURN_MIN_DEG: float = 25.0
## Descent counted as steep (rise over run, 4 m windows).
const STEEP_DESCENT: float = 0.12
## SINGLETRACK pairs along edges: one per pair of STRETCH_M edge stretches.
const STRETCH_M: float = 150.0
## Destinations (TrailNetworkPlanner._destinations): lattice step, top
## radius, prominence ring, minimum prominence, gentle top, how many, and
## the reach of a port (min, max) and apex angle (min, max, deg) of a loop;
## SINGLETRACK loops rise at least DEST_RISE_MIN_M and climb at most
## DEST_CLIMB on average.
const DEST_STEP_M: float = 24.0
const DEST_TOP_M: float = 24.0
const DEST_RING_M: float = 72.0
const DEST_PROMINENCE_M: float = 5.0
const DEST_TOP_RISE_M: float = 1.5
const DEST_OPEN_SHARE: float = 0.25
const DEST_TOP_SLOPE: float = 0.12
const DEST_MAX: int = 24
const DEST_REACH_M := Vector2(90.0, 420.0)
const DEST_APEX_DEG := Vector2(55.0, 150.0)
const DEST_RISE_MIN_M: float = 4.0
const DEST_CLIMB: float = 0.09
const DEST_RISE_MAX_M: float = 40.0
## Largest ground slope from the road edge to the port (shoulder / earthwork).
const PORT_SHOULDER_MAX: float = 0.22

## Search grid cell (m) and the ground raster cell (m) it samples.
const CELL_M: float = 4.0
const GROUND_CELL_M: float = 2.0
## A* work budget (expanded cells) per pair.
const SEARCH_BUDGET: int = 90000
## Pairs searched / exactly checked per bake (work budget).
const MAX_SEARCHES: int = 40
const MAX_CHECKS: int = 8
## Destination pairs searched per class (their own budget).
const DEST_MAX_SEARCHES: int = 16
## Clearance (m) from water and from road planes (except at the ports).
const WATER_CLEAR_M: float = 3.0
const ROAD_CLEAR_M: float = 6.0
## Ground within this distance (m) of a road costs extra (a trail is not a
## road shoulder).
const ROAD_NEAR_M: float = 18.0

## Class profiles. SINGLETRACK climb_mean_max: the average grade a two-way
## pair may need along its straight line - the measured sustained climb on
## rough ground (5.6 deg, RoadSynthesisPolicy.MEASUREMENT).
## grade_* are rise over run on the published ground between
## search cells; cross_* the side slope across the step; length / straight
## distances in m; detour = road distance / straight distance between ports.
const PROFILES := {
	"SINGLETRACK": {
		"route_class": Graph.RouteClass.SINGLETRACK, "directed": false, "along": false, "id_prefix": "st",
		"half_width_m": 0.65,
		"grade_pref": 0.07, "grade_hard": 0.135,
		"cross_pref": 0.12, "cross_hard": 0.28,
		"w_grade": 1.2, "w_cross": 0.8, "w_road_near": 0.6,
		"straight_min_m": 140.0, "straight_max_m": 520.0,
		"detour_min": 1.45, "gain_min_m": 120.0, "climb_mean_max": 0.098,
		"length_min_m": 180.0, "length_max_m": 900.0,
		"control_spacing_m": 14.0, "simplify_m": 1.5, "chaikin": 2,
	},
	## A descent (directed): from a high port to a low one, forward climbs
	## above climb_hard impassable, cost around descent_target; pairs need
	## drop_min_m and drop_ratio_min and a way back by road detour_min times
	## longer than the straight distance.
	"TECHNICAL": {
		"route_class": Graph.RouteClass.TECHNICAL, "directed": true, "along": true, "id_prefix": "tech",
		"half_width_m": 0.5,
		"grade_pref": 0.10, "grade_hard": 0.23, "climb_hard": 0.06,
		"descent_target": 0.15, "descent_band": 0.08,
		"cross_pref": 0.15, "cross_hard": 0.31,
		"w_grade": 1.0, "w_cross": 0.5, "w_road_near": 0.6,
		"straight_min_m": 70.0, "straight_max_m": 320.0,
		"drop_min_m": 12.0, "drop_ratio_min": 0.09, "detour_min": 1.3,
		"control_spacing_m": 7.0, "simplify_m": 1.5, "chaikin": 1,
	},
}


## Validated policy configuration {is_valid, reason_code, config}.
static func parse(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema", "") != SCHEMA or value.get("mode", "") != "PROCEDURAL":
		return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "schema"}}
	var classes: Variant = value.get("classes", [])
	if not classes is Array or classes.is_empty():
		return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "classes"}}
	for name: Variant in classes:
		if not name is String or not CLASSES.has(name):
			return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "class", "value": str(name)}}
	var limit: Variant = value.get("max_trails", 1)
	for name: String in classes:
		var count: Variant = limit.get(name, 0) if limit is Dictionary else limit
		if not (count is int or (count is float and count == floorf(count))) or int(count) < 1 or int(count) > MAX_TRAILS_LIMIT:
			return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "max_trails", "class": name, "value": str(count)}}
	return {"is_valid": true, "reason_code": "", "config": value}


## Trails wanted of a class: max_trails as one number for every class or
## {class: number} (a parsed configuration).
static func wanted(config: Dictionary, class_name_value: String) -> int:
	var limit: Variant = config.get("max_trails", 1)
	return int(limit.get(class_name_value, 0) if limit is Dictionary else limit)


static func is_procedural(value: Variant) -> bool:
	return value is Dictionary and value.get("schema", "") == SCHEMA
