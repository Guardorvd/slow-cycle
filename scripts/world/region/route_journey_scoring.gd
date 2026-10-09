class_name RouteJourneyScoring
extends RefCounted

## Journey Value Score (ExecPlan §8, approval condition 1) and reason
## derivation. Journey purpose decides which plausible candidates are kept;
## it never changes path geometry (RouteSearch has no bonuses).
##
## JVS = novelty (saturating: 1.5 * (1 - exp(-novelty_km / 1.2)) scaled by the
##       novel share, so a longer route is not automatically better)
##     + anchors passed (value, 1.0 if the kind is new to the network else 0.5,
##       diminishing 1, .6, .36 ... over the sorted values)
##     + 0.5 * min(relief gain / (0.25 * region relief), 1)
##     + 0.3 * min(biome-group transitions, 3)
##     + 0.8 * character contrast with the parallel network path
##     - 0.6 * max(0, cost per metre / class norm - 1)
##     - 0.8 * max(0, loop detour ratio - class maximum)
## Weights are versioned Alpha parameters (MODEL), tuned on development seeds.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const MODEL := "jvs/1;novelty=1.5:1.2:150;anchor=80:.6;relief=.5:.25;transition=.3:3:96;contrast=.8;cost=.6:2.5,3,3.5,4.5;detour=.8:3.5;length=.6:3000,2500,1200;duplicate=64:.2:160;screen=80:96"
const NOVELTY_DISTANCE_M: float = 150.0
const ANCHOR_REACH_M: float = 80.0
const VISITED_M: float = 120.0
const COST_NORM: Array[float] = [2.5, 3.0, 3.5, 4.5]
const DETOUR_MAX: float = 3.5
## Typical route length per class: beyond it a route must earn its length
## (approval condition 1: length is not journey quality).
const TYPICAL_LENGTH_M: Array[float] = [INF, 3000.0, 2500.0, 1200.0]
const DUPLICATE_DISTANCE_M: float = 64.0
## Planner-side duplicate screening on 32 m nodes is conservative against the
## validator's 64 m reference-line rule (node rasterisation tolerance).
const SCREEN_DISTANCE_M: float = 80.0
const DUPLICATE_FRACTION: float = 0.2
const END_ZONE_M: float = 160.0
const MIN_RUN_M: float = 96.0


static func move_length(a: int, b: int) -> float:
	return Raster.local_of(a).distance_to(Raster.local_of(b))


static func path_length(path: PackedInt32Array) -> float:
	var total: float = 0.0
	for m in range(1, path.size()):
		total += move_length(path[m - 1], path[m])
	return total


## Biome group: 0 woody (conifer/autumn), 1 open meadow, 2 riparian, -1 water.
static func biome_group(biome: int) -> int:
	match biome:
		0, 3:
			return 0
		1:
			return 1
		2:
			return 2
	return -1


## Number of group changes between runs of at least MIN_RUN_M.
static func transitions(raster: Raster, path: PackedInt32Array) -> int:
	var runs: Array = []
	for m in range(path.size()):
		var group: int = biome_group(raster.biome[path[m]])
		if group < 0:
			continue
		var step: float = move_length(path[m - 1], path[m]) if m > 0 else 0.0
		if not runs.is_empty() and runs[-1][0] == group:
			runs[-1][1] += step
		else:
			runs.append([group, step])
	var kept: Array = []
	for run: Array in runs:
		if run[1] >= MIN_RUN_M and (kept.is_empty() or kept[-1] != run[0]):
			kept.append(run[0])
	return maxi(0, kept.size() - 1)


## Normalised character vector of a node path (all components in [0, 1]).
static func character(raster: Raster, path: PackedInt32Array, crossings: int) -> PackedFloat64Array:
	var length: float = maxf(path_length(path), 1.0)
	var rel: float = 0.0
	var rel_max: float = 0.0
	var woody: float = 0.0
	var open: float = 0.0
	var wet: float = 0.0
	var grade: float = 0.0
	for m in range(1, path.size()):
		var a: int = path[m - 1]
		var b: int = path[m]
		var l: float = move_length(a, b)
		rel += l * 0.5 * (raster.rel_elev[a] + raster.rel_elev[b])
		rel_max = maxf(rel_max, raster.rel_elev[b])
		woody += l if raster.cover[b] >= 0.5 else 0.0
		open += l if raster.travel_class[b] == 0 and raster.meadow[b] >= 0.4 else 0.0
		wet += l if raster.water_dist[b] <= 60.0 else 0.0
		grade += absf(raster.height[b] - raster.height[a])
	return PackedFloat64Array([clampf(rel / length, 0.0, 1.0), clampf(rel_max / 1.5, 0.0, 1.0), woody / length, open / length, wet / length,
		clampf(grade / length / 0.2, 0.0, 1.0), clampf(crossings / (length / 1000.0) / 2.0, 0.0, 1.0)])


static func contrast(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var total: float = 0.0
	for k in range(a.size()):
		total += absf(a[k] - b[k])
	return total / a.size()


## Share of the path (outside END_ZONE_M of both ends) within `distance_m` of
## the network described by the distance field: duplicate geometry measure.
static func near_share(path: PackedInt32Array, distance: PackedFloat64Array, distance_m: float, end_zone_m: float = END_ZONE_M) -> float:
	var total: float = path_length(path)
	var walked: float = 0.0
	var counted: float = 0.0
	var near: float = 0.0
	for m in range(1, path.size()):
		var l: float = move_length(path[m - 1], path[m])
		var mid: float = walked + 0.5 * l
		walked += l
		if mid < end_zone_m or total - mid < end_zone_m:
			continue
		counted += l
		if minf(distance[path[m - 1]], distance[path[m]]) <= distance_m:
			near += l
	return near / counted if counted > 0.0 else 0.0


## Anchors (not rejected, not already visited by the network) within reach of
## the path, as [anchor_index, ...] in anchor order.
static func anchors_passed(path: PackedInt32Array, anchors: Array, network_distance: PackedFloat64Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for a in range(anchors.size()):
		var anchor: Dictionary = anchors[a]
		if anchor.node < 0 or network_distance[anchor.node] <= VISITED_M:
			continue
		var p: Vector2 = Raster.local_of(anchor.node)
		for k: int in path:
			if Raster.local_of(k).distance_to(p) <= ANCHOR_REACH_M:
				result.append(a)
				break
	return result


## Journey Value Score with its breakdown. `context` keys: raster, anchors,
## network_distance, kinds_visited (Dictionary kind -> true), reference
## (node path or empty), route_class, cost (separation-free path cost),
## relief_m, crossings (count).
static func evaluate(path: PackedInt32Array, context: Dictionary) -> Dictionary:
	var raster: Raster = context.raster
	var length: float = maxf(path_length(path), 1.0)
	var distance: PackedFloat64Array = context.network_distance
	var novel: float = 0.0
	for m in range(1, path.size()):
		if minf(distance[path[m - 1]], distance[path[m]]) > NOVELTY_DISTANCE_M:
			novel += move_length(path[m - 1], path[m])
	var novelty: float = 1.5 * (1.0 - exp(-novel / 1000.0 / 1.2)) * (0.5 + 0.5 * novel / length)
	var passed: PackedInt32Array = anchors_passed(path, context.anchors, distance)
	var values: Array = []
	var new_kinds: Dictionary = {}
	for a: int in passed:
		var anchor: Dictionary = context.anchors[a]
		var fresh: bool = not context.kinds_visited.has(anchor.kind) and not new_kinds.has(anchor.kind)
		new_kinds[anchor.kind] = true
		values.append(anchor.value * (1.0 if fresh else 0.5))
	values.sort()
	values.reverse()
	var anchor_term: float = 0.0
	var weight: float = 1.0
	for v: float in values:
		anchor_term += weight * v
		weight *= 0.6
	var low: float = minf(raster.height[path[0]], raster.height[path[path.size() - 1]])
	var high: float = low
	for k: int in path:
		high = maxf(high, raster.height[k])
	var relief_term: float = 0.5 * minf((high - low) / (0.25 * context.relief_m), 1.0)
	var transition_count: int = transitions(raster, path)
	var transition_term: float = 0.3 * mini(transition_count, 3)
	var reference: PackedInt32Array = context.reference
	var contrast_value: float = 0.3
	var detour: float = 0.0
	if reference.size() >= 2:
		contrast_value = contrast(character(raster, path, context.crossings), character(raster, reference, 0))
		detour = length / maxf(path_length(reference), 1.0)
	var contrast_term: float = 0.8 * contrast_value
	var cost_ratio: float = context.cost / length
	var cost_penalty: float = 0.6 * maxf(0.0, cost_ratio / COST_NORM[context.route_class] - 1.0)
	var detour_penalty: float = 0.8 * maxf(0.0, detour - DETOUR_MAX) if reference.size() >= 2 else 0.0
	var length_penalty: float = 0.6 * maxf(0.0, length / TYPICAL_LENGTH_M[context.route_class] - 1.0)
	var total: float = novelty + anchor_term + relief_term + transition_term + contrast_term - cost_penalty - detour_penalty - length_penalty
	return {"jvs": total, "novelty": novelty, "novelty_km": novel / 1000.0, "anchors": anchor_term, "relief": relief_term, "transitions": transition_term,
		"contrast": contrast_term, "contrast_value": contrast_value, "cost_penalty": cost_penalty, "detour_penalty": detour_penalty, "length_penalty": length_penalty, "detour_ratio": detour,
		"length_m": length, "cost_ratio": cost_ratio, "anchors_passed": passed, "relief_gain_m": high - low, "transition_count": transition_count}


## Edge reason bits from its stations, anchors, crossings and route purpose.
static func edge_reasons(stations: Dictionary, anchor_kinds: Array, crossings: Array, purpose: int, contrast_value: float) -> int:
	var reasons: int = 0
	var count: int = stations.major_dist.size()
	var near_river: int = 0
	var high: int = 0
	var open: int = 0
	var autumn: int = 0
	for k in range(count):
		near_river += 1 if stations.major_dist[k] <= 120.0 else 0
		high += 1 if stations.rel_elev[k] >= 0.45 else 0
		open += 1 if stations.biome[k] == 1 else 0
		autumn += 1 if stations.biome[k] == 3 else 0
	if near_river >= 0.4 * count:
		reasons |= Graph.Reason.FOLLOWS_RIVER
	if Graph.AnchorKind.BENCH in anchor_kinds:
		reasons |= Graph.Reason.CLIMBS_TO_BENCH
	if Graph.AnchorKind.PASS in anchor_kinds:
		reasons |= Graph.Reason.REACHES_PASS
	if Graph.AnchorKind.SIDE_VALLEY_MOUTH in anchor_kinds or Graph.AnchorKind.SIDE_VALLEY_HEAD in anchor_kinds:
		reasons |= Graph.Reason.ENTERS_SIDE_VALLEY
	if high >= 0.3 * count and stations.length_m >= 500.0:
		reasons |= Graph.Reason.HIGH_TRAVERSE
	if Graph.AnchorKind.MEADOW in anchor_kinds or Graph.AnchorKind.UPLAND_BASIN in anchor_kinds or open >= 0.25 * count:
		reasons |= Graph.Reason.VISITS_MEADOW
	if Graph.AnchorKind.LAKE_SHORE in anchor_kinds:
		reasons |= Graph.Reason.LAKE_SHORE
	if Graph.AnchorKind.AUTUMN_POCKET in anchor_kinds or autumn >= 0.15 * count:
		reasons |= Graph.Reason.AUTUMN_WOODS
	if stations.transitions >= 1:
		reasons |= Graph.Reason.FOREST_OPEN_TRANSITION
	var first: float = stations.elevation[0]
	var last: float = stations.elevation[count - 1]
	var lower_end_wet: bool = stations.water_dist[count - 1 if last < first else 0] <= 120.0
	if absf(first - last) >= 40.0 and lower_end_wet:
		reasons |= Graph.Reason.DESCENDS_TO_WATER
	for crossing: Dictionary in crossings:
		reasons |= Graph.Reason.RIVER_CROSSING if crossing.water_kind == Graph.WaterKind.MAJOR_RIVER or crossing.hint == Graph.Hint.BRIDGE else Graph.Reason.CREEK_CROSSING
	match purpose:
		Graph.Purpose.BACKBONE:
			reasons |= Graph.Reason.VALLEY_ROAD
		Graph.Purpose.LOOP_ALTERNATIVE:
			if contrast_value >= 0.15:
				reasons |= Graph.Reason.SCENIC_ALTERNATIVE
		Graph.Purpose.SHORTCUT:
			reasons |= Graph.Reason.SHORTCUT
		Graph.Purpose.CROSS_CONNECTION:
			reasons |= Graph.Reason.CONNECTS_LOOPS
	return reasons


static func reason_names(bits: int) -> PackedStringArray:
	var names := PackedStringArray()
	for k in range(Graph.REASON_NAMES.size()):
		if bits & (1 << k):
			names.append(Graph.REASON_NAMES[k])
	return names
