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
##    "max_trails": int}
## The configuration is seed-independent: the region (seed, geography and its
## published road network) decides where trails go.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const SCHEMA := "slow_cycle.trail_network/1"
const CLASSES: Array[String] = ["SINGLETRACK"]
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
## Clearance (m) from water and from road planes (except at the ports).
const WATER_CLEAR_M: float = 3.0
const ROAD_CLEAR_M: float = 6.0
## Ground within this distance (m) of a road costs extra (a trail is not a
## road shoulder).
const ROAD_NEAR_M: float = 18.0

## Class profiles. grade_* are rise over run on the published ground between
## search cells; cross_* the side slope across the step; length / straight
## distances in m; detour = road distance / straight distance between ports.
const PROFILES := {
	"SINGLETRACK": {
		"route_class": Graph.RouteClass.SINGLETRACK,
		"half_width_m": 0.65,
		"grade_pref": 0.07, "grade_hard": 0.135,
		"cross_pref": 0.12, "cross_hard": 0.28,
		"w_grade": 1.2, "w_cross": 0.8, "w_road_near": 0.6,
		"straight_min_m": 140.0, "straight_max_m": 520.0,
		"detour_min": 1.45, "gain_min_m": 120.0,
		"length_min_m": 180.0, "length_max_m": 900.0,
		"control_spacing_m": 14.0, "simplify_m": 1.5, "chaikin": 2,
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
	var count: Variant = value.get("max_trails", 1)
	if not (count is int or (count is float and count == floorf(count))) or int(count) < 1 or int(count) > MAX_TRAILS_LIMIT:
		return {"is_valid": false, "reason_code": "ERR_TRAIL_INPUT", "detail": {"stage": "max_trails", "value": str(count)}}
	return {"is_valid": true, "reason_code": "", "config": value}


static func is_procedural(value: Variant) -> bool:
	return value is Dictionary and value.get("schema", "") == SCHEMA
