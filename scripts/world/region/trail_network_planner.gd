extends RefCounted

## BC2 TrailNetworkPlanner (pure: no scene, no I/O). Proposes the procedural
## trails of one region from its geography and its published road network;
## TrailRealization validates every proposal and owns the line, FinalSurface
## the geometry, RealizedRoadNetwork the connectivity (with_trails).
##
## Method (checkpoint 1, SINGLETRACK):
##  1. Ports: stations of edge pieces near their nodes (TrailPolicy), on either
##     side of the road, where the shoulder is gentle and no water lies.
##  2. Pairs: ports of two different nodes whose road distance is a real
##     detour over their straight distance - the reason to leave the road is a
##     shorter, different way through natural ground. Ranked by that gain, at
##     most a few per pair of road ends, up to MAX_SEARCHES.
##  3. Search: A* over a CELL_M lattice of the PUBLISHED ground (the tile
##     triangles, FinalSurface.published_ground), 16 neighbours; steps steeper
##     than the class grade or side slope are impassable, water and road planes
##     are blocked with clearances, cost grows with grade, side slope and road
##     proximity. A work budget bounds each search.
##  4. Line: road point -> searched cells -> road point, simplified, resampled
##     and corner-cut into control points (TrailRealization's curve).
##  5. Screen on the raster (grade, pitch, side slope, radius, water), then the
##     exact check: TrailRealization.realize on the published triangles of the
##     line's zone (FinalSurface.with_trails().with_published()).
## Checkpoint 2, TECHNICAL (profile "directed"): ports along whole edges; a
## pair is a high and a low port with a real drop between them and a longer
## way back by road; the search descends from the high port (forward climbs
## and too-steep descents impassable, cost around a steady target descent);
## the line is then given linked turns - a few sine offsets of the searched
## corridor (wavelength, amplitude) are screened and the most turning one
## that meets the TECHNICAL limits is kept (the plain corridor when no other
## passes). Trails are descents, ridden FORWARD; the road is the way back.
## Ports along whole edges (profile "along") join an incident node of their
## edge (TrailRealization join_max_m).
## Destinations (checkpoint 3): when road pairs leave a class short - a road
## network without loops or drops offers no alternative - a trail may go to a
## natural destination instead: a knoll with a gentle top off the road
## (_destinations), reached from one port and left to another (two searches,
## the way back keeping clear of the way out). SINGLETRACK: a viewpoint loop
## ridden both ways; TECHNICAL: a gentle climb to the knoll and a descent of
## its flank, FORWARD only.
## Classes are planned in configuration order; a selected trail's band
## (TRAIL_CLEAR_M) may be crossed by later trails at CROSS_SEARCH_DEG or more
## - a trail crossing, a fork of the network - but not followed; at most
## MAX_CROSSINGS per trail.
## Every rejection keeps its reason. Order is stable (sorted ids, fixed
## loops); the seed enters only through a derived tie-break, so the same
## seed, region and configuration give the same proposals.
##
## Returns {trails: [selected TrailRealization records, in class order],
## alternates: [records that passed but were not selected], rejected: [{id,
## reason_code, detail}], report: {...}}.

const Trail = preload("res://scripts/world/region/trail_realization.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const TILE_M: float = 512.0
## PERF-P2: ports within INTENT_PORT_M of a natural route intent's corridor
## may carry it (nearest port per INTENT_BIN_M of corridor), at most
## INTENT_PAIRS pairs per intent; an intent pair may span up to
## INTENT_STRAIGHT_FACTOR x the class's straight_max_m.
const INTENT_PORT_M: float = 160.0
const INTENT_BIN_M: float = 40.0
const INTENT_PAIRS: int = 3
const INTENT_STRAIGHT_FACTOR: float = 2.0
## Score bonus of a trail realizing an R5 natural route intent.
const INTENT_BONUS: float = 1.0
## Neighbour steps of the search lattice (16-connected).
const STEPS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	Vector2i(2, 1), Vector2i(2, -1), Vector2i(-2, 1), Vector2i(-2, -1), Vector2i(1, 2), Vector2i(1, -2), Vector2i(-1, 2), Vector2i(-1, -2)]


## config: parsed TrailPolicy configuration. context: {seed, region, network
## (RealizedRoadNetwork data), surface (FinalSurface, no trails), field
## (HydrologyField), ground (published_ground at GROUND_CELL_M), slots (the
## off tiles)}.
static func plan(config: Dictionary, context: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var bounds: Dictionary = context.surface.get_bounds_m()
	var state := _State.new()
	state.context = context
	state.bounds = bounds
	state.size = Vector2(bounds.max_x - bounds.min_x, bounds.max_z - bounds.min_z)
	state.lattice = Vector2i(int(state.size.x / TrailPolicy.CELL_M) + 1, int(state.size.y / TrailPolicy.CELL_M) + 1)
	state.water.resize(state.lattice.x * state.lattice.y)
	state.blocked.resize(state.lattice.x * state.lattice.y)
	state.zone_dir.resize(state.lattice.x * state.lattice.y)
	state.road = _road_distance(context.network, state)
	var selected: Array = []
	var alternates: Array = []
	var rejected: Array = []
	var classes: Array = []
	for class_name_value: String in config.classes:
		state.profile = TrailPolicy.PROFILES[class_name_value]
		state.class_name_value = class_name_value
		state.limits = Trail.limits(class_name_value)
		var wanted: int = TrailPolicy.wanted(config, class_name_value)
		var made: Dictionary = _plan_class(state, wanted)
		rejected.append_array(made.rejected)
		var chosen: int = 0
		for trail: Dictionary in made.passed:
			if chosen < wanted and _zone_check(trail.line, state).is_valid:
				selected.append(trail)
				_stamp(trail, state)
				chosen += 1
			else:
				alternates.append(trail)
		made.report["selected"] = chosen
		classes.append(made.report)
	var report := {"planner": "trail_network/2", "classes": classes, "seconds": (Time.get_ticks_usec() - t0) / 1e6,
		"proposed": (selected + alternates).map(func(t: Dictionary) -> Dictionary: return {"id": t.id, "class": t.class_name, "score": t.planner.score, "purpose": t.purpose,
			"length_m": t.length_m})}
	return {"trails": selected, "alternates": alternates, "rejected": rejected, "report": report}


## Proposals of the state's class, best first.
static func _plan_class(state: _State, wanted: int) -> Dictionary:
	var profile: Dictionary = state.profile
	var context: Dictionary = state.context
	var ports: Array = _ports(context.network, state)
	state.last_filtered = {}
	var pairs: Array = _descent_pairs(ports, context.network, state, int(context.seed)) if profile.directed else _pairs(ports, context.network, state, int(context.seed))
	var tally := {"passed": [], "rejected": [], "searches": 0, "checks": 0, "expanded": 0}
	# PERF-P2: the natural routes R5 planned for this class come first.
	var intent_pairs: Array = _intent_pairs(context.network, state, int(context.seed))
	_try_pairs(intent_pairs, state, wanted, tally, TrailPolicy.MAX_SEARCHES)
	_try_pairs(pairs, state, wanted, tally, TrailPolicy.MAX_SEARCHES)
	var destinations: Array = []
	var destination_pairs: Array = []
	if tally.passed.size() < wanted:
		destinations = _destinations(state, ports if profile.get("along", false) else _along_ports(context.network, state))
		var along: Array = ports if profile.get("along", false) else _along_ports(context.network, state)
		destination_pairs = _destination_pairs(along, destinations, context.network, state, int(context.seed))
		_try_pairs(destination_pairs, state, wanted, tally, TrailPolicy.DEST_MAX_SEARCHES)
	var passed: Array = tally.passed
	var rejected: Array = tally.rejected
	var searches: int = tally.searches
	var checks: int = tally.checks
	var expanded: int = tally.expanded
	passed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.planner.score > b.planner.score or (a.planner.score == b.planner.score and a.id < b.id))
	var report := {"class": state.class_name_value, "ports": ports.size(), "pairs": pairs.size(), "intent_pairs": intent_pairs.size(),
		"intent_trails": passed.filter(func(t: Dictionary) -> bool: return t.planner.has("intent")).size(), "searches": searches, "checks": checks, "expanded": expanded,
		"passed": passed.size(), "destinations": destinations.size(), "destination_pairs": destination_pairs.size(), "filtered": state.last_filtered.duplicate(),
		"destination_sample": destinations.slice(0, 4).map(func(d: Dictionary) -> Dictionary: return {"x_m": snappedf(d.p.x, 1.0), "z_m": snappedf(d.p.y, 1.0),
			"height_m": snappedf(d.h, 0.1), "prominence_m": snappedf(d.prominence, 0.1), "nearest_port_m": snappedf(_nearest_port(ports, d.p), 1.0)})}
	return {"passed": passed, "rejected": rejected, "report": report}


## Searches, screens and realizes `pairs` in order into `tally` ({passed,
## rejected, searches, checks, expanded}) within `budget` searches and
## MAX_CHECKS exact checks, until the class has wanted + 2 proposals.
static func _try_pairs(pairs: Array, state: _State, wanted: int, tally: Dictionary, budget: int) -> void:
	var start: int = tally.searches
	for pair: Dictionary in pairs:
		if tally.searches - start >= budget or tally.checks >= TrailPolicy.MAX_CHECKS or tally.passed.size() >= wanted + 2:
			return
		if _conflicts(pair, tally.passed):
			continue
		tally.searches += 1
		if not _leads(pair, state):
			tally.rejected.append({"id": pair.id, "reason_code": "ERR_TRAIL_SEARCH", "detail": {"stage": "lead-out"}})
			continue
		var found: Dictionary = _route(pair, state)
		tally.expanded += found.expanded
		if not found.is_valid:
			var detail := {"stage": found.stage, "expanded": found.expanded}
			detail.merge(_straight_profile(pair.a.q, pair.b.q, state))
			tally.rejected.append({"id": pair.id, "reason_code": "ERR_TRAIL_SEARCH", "detail": detail})
			continue
		var variants: Array = _variants(pair, found.path, state)
		if variants.is_empty():
			tally.rejected.append({"id": pair.id, "reason_code": "ERR_TRAIL_SCREEN", "detail": state.last_screen})
			continue
		var made: Dictionary = {}
		for variant: Dictionary in variants.slice(0, 3):
			tally.checks += 1
			made = _realize(pair, variant.points, variant.screened, state)
			if made.is_valid:
				made.trail.planner["shape"] = variant.shape
				break
		if not made.is_valid:
			tally.rejected.append({"id": pair.id, "reason_code": made.reason_code, "detail": made.detail})
			continue
		tally.passed.append(made.trail)


## A port faces a point when the point lies on its side of the road.
static func _faces(port: Dictionary, p: Vector2) -> bool:
	return (p - port.q).dot(port.normal) > 0.0


## What lies on the straight line between two points (refusal reasons):
## water samples, the share steeper than the class side slope, the largest
## ground slope, every 8 m.
static func _straight_profile(a: Vector2, b: Vector2, state: _State) -> Dictionary:
	var count: int = maxi(2, int(a.distance_to(b) / 8.0))
	var water: int = 0
	var road: int = 0
	var steep: int = 0
	var largest: float = 0.0
	for m in range(1, count):
		var p: Vector2 = a.lerp(b, float(m) / count)
		water += 1 if _water_node(state, int(round(p.x / TrailPolicy.CELL_M)), int(round(p.y / TrailPolicy.CELL_M))) else 0
		road += 1 if _road_at(state, p) < 0.0 else 0
		var g: float = _ground_gradient(state.context.ground, p.x, p.y).length()
		steep += 1 if g > state.profile.cross_hard else 0
		largest = maxf(largest, g)
	return {"straight_m": a.distance_to(b), "water_samples": water, "road_samples": road, "steep_share": float(steep) / (count - 1), "max_slope": largest}


## The searched path of a pair: one search between its lead-outs, or two
## through its destination (pair.via) - the second keeping clear of the
## first except around the destination.
static func _route(pair: Dictionary, state: _State) -> Dictionary:
	if not pair.has("via"):
		return _search(pair, state)
	var first: Dictionary = _search({"leads": [pair.leads[0], pair.via]}, state)
	if not first.is_valid:
		first.stage = "way out: " + str(first.stage)
		return first
	var saved: PackedByteArray = state.blocked.duplicate()
	var saved_dir: PackedVector2Array = state.zone_dir.duplicate()
	_stamp_points(first.path, state)
	var second: Dictionary = _search({"leads": [pair.via, pair.leads[1]]}, state)
	state.blocked = saved
	state.zone_dir = saved_dir
	if not second.is_valid:
		return {"is_valid": false, "stage": "way back: " + str(second.stage), "expanded": first.expanded + second.expanded}
	var path: Array[Vector2] = first.path.duplicate()
	path.append_array(second.path.slice(1))
	return {"is_valid": true, "path": path, "expanded": first.expanded + second.expanded, "stage": ""}


## Natural destinations off the road: lookouts - knoll tops and terrace
## rims with a gentle dry top and an open view (see the test below), beyond
## the road clearance, within DEST_REACH_M of a port and at most
## DEST_RISE_MAX_M above it.
## Highest prominence first (stable order).
static func _destinations(state: _State, ports: Array) -> Array:
	var ground: Dictionary = state.context.ground
	var out: Array = []
	var step: float = TrailPolicy.DEST_STEP_M
	var margin: float = Trail.MARGIN_M + TrailPolicy.DEST_RING_M
	var z: float = margin
	while z < state.size.y - margin:
		var x: float = margin
		while x < state.size.x - margin:
			var p := Vector2(x, z)
			x += step
			var h: float = Surface.ground_height(ground, p.x, p.y)
			if is_nan(h) or _road_at(state, p) < TrailPolicy.ROAD_NEAR_M:
				continue
			# A lookout: nothing within DEST_TOP_M rises more than DEST_TOP_RISE_M
			# above it (a knoll top, or the rim of a terrace whose top rises
			# gently behind), and at least DEST_OPEN_SHARE of the ring at
			# DEST_RING_M lies DEST_PROMINENCE_M or more below it (open view).
			var top: bool = true
			var low: float = INF
			var open: int = 0
			for m in range(16):
				var direction := Vector2.from_angle(TAU * m / 16.0)
				var near: float = Surface.ground_height(ground, p.x + direction.x * TrailPolicy.DEST_TOP_M, p.y + direction.y * TrailPolicy.DEST_TOP_M)
				var ring: float = Surface.ground_height(ground, p.x + direction.x * TrailPolicy.DEST_RING_M, p.y + direction.y * TrailPolicy.DEST_RING_M)
				if is_nan(near) or is_nan(ring) or near > h + TrailPolicy.DEST_TOP_RISE_M:
					top = false
					break
				low = minf(low, ring)
				open += 1 if h - ring >= TrailPolicy.DEST_PROMINENCE_M else 0
			if not top or open < int(16 * TrailPolicy.DEST_OPEN_SHARE) or _ground_gradient(ground, p.x, p.y).length() > TrailPolicy.DEST_TOP_SLOPE or _wet(p, state):
				continue
			# Within reach of a port and not far above it (a knoll, not a peak).
			var reachable: bool = false
			for port: Dictionary in ports:
				var reach: float = port.q.distance_to(p)
				if reach >= TrailPolicy.DEST_REACH_M.x and reach <= TrailPolicy.DEST_REACH_M.y and h - Surface.ground_height(ground, port.q.x, port.q.y) <= TrailPolicy.DEST_RISE_MAX_M:
					reachable = true
					break
			if not reachable:
				continue
			out.append({"p": p, "h": h, "prominence": h - low})
		z += step
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.prominence > b.prominence or (a.prominence == b.prominence and (a.p.y < b.p.y or (a.p.y == b.p.y and a.p.x < b.p.x))))
	return out.slice(0, TrailPolicy.DEST_MAX)


## Pairs through a destination: a port out and a port back, both within
## DEST_REACH_M of it, apart along the road and opening an apex angle of
## DEST_APEX_DEG at the destination (a loop, not an out-and-back), with
## distinct incident nodes. SINGLETRACK: the destination above both ports,
## a climb of at most DEST_CLIMB on the way out. TECHNICAL (directed): out
## from the higher port at most climb_hard on average, back down a drop of
## drop_min_m and drop_ratio_min. Best pair per destination, ranked.
static func _destination_pairs(ports: Array, destinations: Array, data: Dictionary, state: _State, seed_value: int) -> Array:
	var profile: Dictionary = state.profile
	var ground: Dictionary = state.context.ground
	var dist: Dictionary = _node_distances(data)
	var lengths: Dictionary = {}
	var ends: Dictionary = {}
	for edge: Dictionary in data.edges:
		lengths[edge.edge_id] = edge.length_m
		ends[edge.edge_id] = [edge.a, edge.b]
	var heights: Array = ports.map(func(p: Dictionary) -> float: return Surface.ground_height(ground, p.q.x, p.q.y))
	var out: Array = []
	for d: Dictionary in destinations:
		var w: Vector2 = d.p
		var near: Array = []
		for i in range(ports.size()):
			var reach: float = ports[i].q.distance_to(w)
			if reach >= TrailPolicy.DEST_REACH_M.x and reach <= TrailPolicy.DEST_REACH_M.y:
				near.append(i)
		var best: Dictionary = {}
		for i: int in near:
			for j: int in near:
				if i == j:
					continue
				var a: Dictionary = ports[i]
				var b: Dictionary = ports[j]
				if not _faces(a, w) or not _faces(b, w):
					continue
				var apex: float = rad_to_deg(absf((a.q - w).angle_to(b.q - w)))
				if apex < TrailPolicy.DEST_APEX_DEG.x or apex > TrailPolicy.DEST_APEX_DEG.y:
					continue
				var out_m: float = a.q.distance_to(w)
				var back_m: float = w.distance_to(b.q)
				var rise: float = d.h - heights[i]
				var drop: float = d.h - heights[j]
				var score: float = 0.0
				if profile.directed:
					if heights[j] >= heights[i] or rise / out_m > profile.climb_hard or drop < profile.drop_min_m or drop / back_m < profile.drop_ratio_min:
						continue
					score = minf(drop, 40.0) / 20.0 + 4.0 * minf(drop / back_m, 0.3)
				else:
					if j < i or minf(rise, drop) < TrailPolicy.DEST_RISE_MIN_M or maxf(rise / out_m, drop / back_m) > TrailPolicy.DEST_CLIMB:
						continue
					score = d.prominence / 10.0 + minf(minf(rise, drop), 30.0) / 15.0
				var nodes: Array = _distinct_nodes(a, b)
				if nodes.is_empty():
					continue
				var tie: int = ("%d|%s|%s|%d,%d" % [seed_value, a.id, b.id, int(w.x), int(w.y)]).hash()
				var entry := {"id": "dest:%d,%d:%s~%s" % [int(w.x), int(w.y), a.id, b.id], "a": a, "b": b, "via": w, "nodes": nodes, "straight_m": a.q.distance_to(b.q),
					"road_m": _road_between(a, b, dist, lengths, ends, data), "drop_m": drop, "rise_m": rise, "ground_slope": drop / back_m, "destination": d, "score": score, "tie": tie,
					"group": "%d,%d" % [int(w.x), int(w.y)]}
				if best.is_empty() or _better(entry, best):
					best = entry
		if not best.is_empty():
			out.append(best)
	out.sort_custom(_better)
	return out


static func _nearest_port(ports: Array, p: Vector2) -> float:
	var best: float = INF
	for port: Dictionary in ports:
		best = minf(best, port.q.distance_to(p))
	return best


static func _stamp_points(points: Array[Vector2], state: _State) -> void:
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	for p: Vector2 in points:
		xs.append(p.x)
		zs.append(p.y)
	_stamp({"line": {"x": xs, "z": zs}}, state, true)


## Line variants that pass the raster screen, best first. SINGLETRACK: the
## corridor, with more corner cutting while only the radius fails.
## TECHNICAL: the corridor with linked turns (TrailPolicy.TURN_SHAPES), the
## most technical first, the plain corridor among them.
static func _variants(pair: Dictionary, path: Array[Vector2], state: _State) -> Array:
	var profile: Dictionary = state.profile
	if not profile.directed:
		for extra in range(TrailPolicy.EXTRA_SMOOTHING + 1):
			var points: Array[Vector2] = _control_points(pair, path, state, int(profile.chaikin) + extra, Vector2.ZERO)
			var screened: Dictionary = _screen(points, state)
			state.last_screen = screened.get("detail", {})
			if screened.is_valid:
				return [{"points": points, "screened": screened, "shape": {"chaikin": int(profile.chaikin) + extra}}]
			if screened.detail.get("stage", "") != "radius":
				return []
		return []
	var out: Array = []
	var shapes: Array[Vector2] = [Vector2.ZERO]
	shapes.append_array(TrailPolicy.TURN_SHAPES)
	for shape: Vector2 in shapes:
		var points: Array[Vector2] = _control_points(pair, path, state, int(profile.chaikin), shape)
		var screened: Dictionary = _screen(points, state)
		if not screened.is_valid:
			if shape == Vector2.ZERO:
				state.last_screen = screened.detail
			continue
		out.append({"points": points, "screened": screened, "shape": {"wavelength_m": shape.x, "amplitude_m": shape.y}, "value": _technical_value(screened)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value > b.value or (a.value == b.value and a.shape.amplitude_m < b.shape.amplitude_m))
	return out


## How technical a screened line rides: its mean descent and the share of it
## descending at STEEP_DESCENT or more first (braking), then linked turns per
## 100 m (heading changes of at least TURN_MIN_DEG within TURN_WINDOW_M, one
## per turn, capped) - a long gentle line does not win by length.
static func _technical_value(screened: Dictionary) -> float:
	var m: Dictionary = screened.metrics
	var length: float = screened.line.s[screened.line.s.size() - 1]
	return 20.0 * (m.descent_m - m.climb_m) / length + 10.0 * m.steep_share + minf(100.0 * m.turns / length, 4.0)


class _State:
	extends RefCounted
	var context: Dictionary
	var bounds: Dictionary
	var profile: Dictionary
	var class_name_value: String
	var limits: Dictionary
	var last_screen: Dictionary = {}
	## Pairs dropped before any search, by reason (report).
	var last_filtered: Dictionary = {}
	## Lattice nodes near selected trails: 1 a crossable band (its trail's
	## direction in zone_dir), 2 blocked (the way out of a destination route).
	var blocked := PackedByteArray()
	var zone_dir := PackedVector2Array()
	var size: Vector2
	var lattice: Vector2i
	## Distance (m) from each lattice node to the nearest road plane edge
	## (INF beyond ROAD_NEAR_M).
	var road := PackedFloat32Array()
	## 0 unknown, 1 dry, 2 water (lazy, per lattice node).
	var water := PackedByteArray()


# --- ports and pairs ---

## Ports of every edge piece near its two nodes (stable order).
static func _ports(data: Dictionary, state: _State) -> Array:
	var designs: Dictionary = {}
	for piece: Dictionary in data.pieces:
		designs[piece.id] = piece.design
	var nodes: Dictionary = {}
	for node: Dictionary in data.nodes:
		nodes[node.id] = node
	var spans: Dictionary = {}
	for c: Dictionary in data.get("crossings", []):
		if c.has("span"):
			if not spans.has(c.edge_id):
				spans[c.edge_id] = []
			spans[c.edge_id].append(c.span)
	var edges: Array = data.edges.duplicate()
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.edge_id < b.edge_id)
	var out: Array = []
	var along_mode: bool = state.profile.get("along", false)
	for edge: Dictionary in edges:
		var d: Dictionary = designs.get(edge.piece_id, {})
		if d.is_empty() or d.s.size() < 2:
			continue
		var n: int = d.s.size()
		var length: float = d.s[n - 1]
		var start := Vector2(d.x[0], d.z[0])
		var a_at_start: bool = start.distance_to(Vector2(nodes[edge.a].x_m, nodes[edge.a].z_m)) <= start.distance_to(Vector2(nodes[edge.b].x_m, nodes[edge.b].z_m))
		for end_node: int in [edge.a, edge.b]:
			var node: Dictionary = nodes[end_node]
			var from_start: bool = (end_node == edge.a) == a_at_start
			var stations: Array = TrailPolicy.PORT_STATIONS_M
			if along_mode:
				# Along the whole edge, once (listed from its first node).
				if end_node != edge.a:
					continue
				stations = []
				var along: float = TrailPolicy.PORT_END_CLEAR_M + 10.0
				while along < length - TrailPolicy.PORT_END_CLEAR_M - 10.0:
					stations.append(along)
					along += TrailPolicy.ALONG_STEP_M
				from_start = true
			for distance: float in stations:
				var s: float = distance if from_start else length - distance
				if s < TrailPolicy.PORT_END_CLEAR_M or s > length - TrailPolicy.PORT_END_CLEAR_M:
					continue
				var near_crossing: bool = false
				for span: Array in spans.get(edge.edge_id, []):
					near_crossing = near_crossing or (s > span[0] - TrailPolicy.PORT_CROSSING_CLEAR_M and s < span[1] + TrailPolicy.PORT_CROSSING_CLEAR_M)
				if near_crossing:
					continue
				var k: int = clampi(d.s.bsearch(s) - 1, 0, n - 2)
				var u: float = clampf((s - d.s[k]) / maxf(d.s[k + 1] - d.s[k], 1e-9), 0.0, 1.0)
				var p := Vector2(lerpf(d.x[k], d.x[k + 1], u), lerpf(d.z[k], d.z[k + 1], u))
				if not along_mode and p.distance_to(Vector2(node.x_m, node.z_m)) > Trail.JOIN_MAX_M - 15.0:
					continue
				var tangent := Vector2(d.x[k + 1] - d.x[k], d.z[k + 1] - d.z[k]).normalized()
				var normal := Vector2(-tangent.y, tangent.x)
				var half: float = lerpf(d.width[k], d.width[k + 1], u) * 0.5
				for side: float in [-1.0, 1.0]:
					var q: Vector2 = p + normal * side * (half + TrailPolicy.PORT_OFFSET_M)
					var port := {"id": "%s@%d%s" % [edge.piece_id, int(round(s)), "L" if side > 0.0 else "R"], "node": end_node, "edge": edge.edge_id, "piece": edge.piece_id,
						"s": s, "road": p + normal * side * half * 0.4, "q": q, "half": half, "normal": normal * side, "tangent": tangent,
						"ends": [[edge.a, p.distance_to(Vector2(nodes[edge.a].x_m, nodes[edge.a].z_m))], [edge.b, p.distance_to(Vector2(nodes[edge.b].x_m, nodes[edge.b].z_m))]]}
					if along_mode:
						port.node = edge.a if port.ends[0][1] <= port.ends[1][1] else edge.b
					if _port_ok(port, p + normal * side * half, state):
						out.append(port)
	return out


## Ports along whole edges whatever the class's own ports (destinations).
static func _along_ports(data: Dictionary, state: _State) -> Array:
	var profile: Dictionary = state.profile
	state.profile = profile.duplicate()
	state.profile["along"] = true
	var out: Array = _ports(data, state)
	state.profile = profile
	return out


static func _port_ok(port: Dictionary, edge_point: Vector2, state: _State) -> bool:
	var q: Vector2 = port.q
	var margin: float = Trail.MARGIN_M + 8.0
	if q.x < margin or q.y < margin or q.x > state.size.x - margin or q.y > state.size.y - margin:
		return false
	var b: Dictionary = state.bounds
	if not state.context.surface.road_owner(b.min_x + q.x, b.min_z + q.y).is_empty():
		return false
	if _wet(q, state):
		return false
	var h_edge: float = Surface.ground_height(state.context.ground, edge_point.x, edge_point.y)
	var h_q: float = Surface.ground_height(state.context.ground, q.x, q.y)
	var h_out: float = Surface.ground_height(state.context.ground, q.x + port.normal.x * 4.0, q.y + port.normal.y * 4.0)
	if is_nan(h_edge) or is_nan(h_q) or is_nan(h_out):
		return false
	return absf(h_q - h_edge) / TrailPolicy.PORT_OFFSET_M <= TrailPolicy.PORT_SHOULDER_MAX and absf(h_out - h_q) / 4.0 <= TrailPolicy.PORT_SHOULDER_MAX


## Port pairs of different nodes that are a real detour by road, ranked.
static func _pairs(ports: Array, data: Dictionary, state: _State, seed_value: int) -> Array:
	var profile: Dictionary = state.profile
	var dist: Dictionary = _node_distances(data)
	var lengths: Dictionary = {}
	var ends: Dictionary = {}
	for edge: Dictionary in data.edges:
		lengths[edge.edge_id] = edge.length_m
		ends[edge.edge_id] = [edge.a, edge.b]
	var best: Dictionary = {}
	var ground: Dictionary = state.context.ground
	var heights: Array = ports.map(func(port: Dictionary) -> float: return Surface.ground_height(ground, port.q.x, port.q.y))
	var filtered := {"climb": 0}
	for i in range(ports.size()):
		var p: Dictionary = ports[i]
		for j in range(i + 1, ports.size()):
			var q: Dictionary = ports[j]
			var nodes: Array = _distinct_nodes(p, q) if p.has("ends") and state.profile.get("along", false) else ([] if p.node == q.node else [p.node, q.node, 0.0, 0.0])
			if nodes.is_empty():
				continue
			var straight: float = p.q.distance_to(q.q)
			if straight < profile.straight_min_m or straight > profile.straight_max_m:
				continue
			# Two-way: the straight line must be climbable at the class's
			# sustained climb.
			if absf(heights[i] - heights[j]) / straight > profile.climb_mean_max:
				filtered.climb += 1
				continue
			var road: float = _road_between(p, q, dist, lengths, ends, data)
			if road < profile.detour_min * straight or road - straight < profile.gain_min_m:
				continue
			if not _faces(p, q.q) or not _faces(q, p.q):
				filtered["facing"] = filtered.get("facing", 0) + 1
				continue
			if _straight_profile(p.q, q.q, state).road_samples > 0:
				filtered["road"] = filtered.get("road", 0) + 1
				continue
			var score: float = minf(road / straight, 4.0) - absf(straight - 320.0) / 600.0
			var group: String = "%d-%d:%d-%d" % [mini(p.node, q.node), maxi(p.node, q.node), mini(p.edge, q.edge), maxi(p.edge, q.edge)]
			if state.profile.get("along", false):
				group = "%d.%d-%d.%d" % [p.edge, int(p.s / TrailPolicy.STRETCH_M), q.edge, int(q.s / TrailPolicy.STRETCH_M)]
			var tie: int = ("%d|%s|%s" % [seed_value, p.id, q.id]).hash()
			var entry := {"id": "pair:%s~%s" % [p.id, q.id], "a": p, "b": q, "straight_m": straight, "road_m": road, "score": score, "tie": tie, "group": group}
			if state.profile.get("along", false):
				entry["nodes"] = nodes
			if not best.has(group):
				best[group] = []
			best[group].append(entry)
	var out: Array = []
	var groups: Array = best.keys()
	groups.sort()
	for group: String in groups:
		var list: Array = best[group]
		list.sort_custom(_better)
		out.append_array(list.slice(0, 1 if state.profile.get("along", false) else 2))
	out.sort_custom(_better)
	state.last_filtered = filtered
	return out


## PERF-P2: port pairs carrying the R5 natural route intents of the state's
## class (RealizedRoadNetwork natural_routes). R5 natural routes often end at
## natural-only nodes, so a pair takes any stretch of the intent corridor
## between two road ports: ports along the road edges within INTENT_PORT_M of
## a corridor station (the nearest port per INTENT_BIN_M of corridor), pairs
## on distinct incident nodes whose corridor stretch is at least the class's
## straight_min_m. The detour / gain filters are waived (R5 judged the
## route); straight length up to INTENT_STRAIGHT_FACTOR x the class maximum;
## facing, a straight line clear of roads, the class climb (SINGLETRACK) or
## drop (TECHNICAL, high port first) checks are kept. Longer stretches and
## nearer ports first, INTENT_PAIRS per intent; search, screening and
## realization are the normal ones.
static func _intent_pairs(data: Dictionary, state: _State, seed_value: int) -> Array:
	var routes: Array = data.get("natural_routes", []).filter(func(r: Dictionary) -> bool: return r["class"] == state.class_name_value)
	if routes.is_empty():
		return []
	var profile: Dictionary = state.profile
	var ports: Array = _along_ports(data, state)
	var ground: Dictionary = state.context.ground
	var heights: Array = ports.map(func(p: Dictionary) -> float: return Surface.ground_height(ground, p.q.x, p.q.y))
	var dist: Dictionary = _node_distances(data)
	var lengths: Dictionary = {}
	var ends: Dictionary = {}
	for edge: Dictionary in data.edges:
		lengths[edge.edge_id] = edge.length_m
		ends[edge.edge_id] = [edge.a, edge.b]
	var out: Array = []
	for route: Dictionary in routes:
		var xs: PackedFloat64Array = route.line.x
		var zs: PackedFloat64Array = route.line.z
		var along := PackedFloat64Array([0.0])
		for k in range(1, xs.size()):
			along.append(along[k - 1] + Vector2(xs[k], zs[k]).distance_to(Vector2(xs[k - 1], zs[k - 1])))
		# Nearest port per corridor bin: [distance, port index, corridor s].
		var bins: Dictionary = {}
		for i in range(ports.size()):
			if is_nan(heights[i]):
				continue
			var best: Array = [INF, -1]
			for k in range(xs.size()):
				var d: float = ports[i].q.distance_to(Vector2(xs[k], zs[k]))
				if d < best[0]:
					best = [d, k]
			if best[0] > INTENT_PORT_M:
				continue
			var bin: int = int(along[best[1]] / INTENT_BIN_M)
			if not bins.has(bin) or best[0] < bins[bin][0]:
				bins[bin] = [best[0], i, along[best[1]]]
		var near: Array = bins.values()
		near.sort()
		var found: Array = []
		for x: Array in near:
			for y: Array in near:
				if x[2] >= y[2] or y[2] - x[2] < profile.straight_min_m:
					continue
				var i: int = x[1]
				var j: int = y[1]
				if profile.directed and heights[j] > heights[i]:
					var swap: int = i
					i = j
					j = swap
				var p: Dictionary = ports[i]
				var q: Dictionary = ports[j]
				var nodes: Array = _distinct_nodes(p, q)
				if nodes.is_empty():
					continue
				var straight: float = p.q.distance_to(q.q)
				if straight < profile.straight_min_m or straight > INTENT_STRAIGHT_FACTOR * profile.straight_max_m:
					continue
				var drop: float = heights[i] - heights[j]
				if profile.directed and (drop < profile.drop_min_m or drop / straight < profile.drop_ratio_min):
					continue
				if not profile.directed and absf(drop) / straight > profile.climb_mean_max:
					continue
				if not _faces(p, q.q) or not _faces(q, p.q):
					continue
				if _straight_profile(p.q, q.q, state).road_samples > 0:
					continue
				var road: float = _road_between(p, q, dist, lengths, ends, data)
				var span: float = minf(y[2] - x[2], INTENT_STRAIGHT_FACTOR * profile.straight_max_m)
				var entry := {"id": "pair:%s~%s" % [p.id, q.id], "a": p, "b": q, "nodes": nodes, "straight_m": straight, "road_m": road, "intent": route.edge_id,
					"score": INTENT_BONUS + span / 1000.0 - (x[0] + y[0]) / 1000.0, "tie": ("%d|%s|%s" % [seed_value, p.id, q.id]).hash(), "group": "intent:%d" % route.edge_id}
				if profile.directed:
					var slope: float = 0.0
					for m in range(1, 10):
						var g: Vector2 = _ground_gradient(ground, lerpf(p.q.x, q.q.x, m / 10.0), lerpf(p.q.y, q.q.y, m / 10.0))
						slope += minf(g.length(), 0.6) / 9.0
					entry.merge({"drop_m": drop, "ground_slope": slope})
				found.append(entry)
		found.sort_custom(_better)
		out.append_array(found.slice(0, INTENT_PAIRS))
	return out


## TECHNICAL pairs: a high port and a low port (in that order) with a real
## drop, ground worth descending between them and a longer way back by road.
## The two ends get distinct incident nodes (the nearest such choice).
## Ranked by drop, ground steepness and the length of the way back; one per
## pair of edge stretches.
static func _descent_pairs(ports: Array, data: Dictionary, state: _State, seed_value: int) -> Array:
	var profile: Dictionary = state.profile
	var dist: Dictionary = _node_distances(data)
	var lengths: Dictionary = {}
	var ends: Dictionary = {}
	for edge: Dictionary in data.edges:
		lengths[edge.edge_id] = edge.length_m
		ends[edge.edge_id] = [edge.a, edge.b]
	var ground: Dictionary = state.context.ground
	var heights: Array = ports.map(func(p: Dictionary) -> float: return Surface.ground_height(ground, p.q.x, p.q.y))
	var best: Dictionary = {}
	for i in range(ports.size()):
		for j in range(ports.size()):
			if i == j or not heights[i] - heights[j] >= profile.drop_min_m:
				continue
			var hi: Dictionary = ports[i]
			var lo: Dictionary = ports[j]
			var straight: float = hi.q.distance_to(lo.q)
			var drop: float = heights[i] - heights[j]
			if straight < profile.straight_min_m or straight > profile.straight_max_m or drop / straight < profile.drop_ratio_min:
				continue
			if not _faces(hi, lo.q) or not _faces(lo, hi.q):
				continue
			var road: float = _road_between(hi, lo, dist, lengths, ends, data)
			if road < profile.detour_min * straight:
				continue
			if _straight_profile(hi.q, lo.q, state).road_samples > 0:
				continue
			var nodes: Array = _distinct_nodes(hi, lo)
			if nodes.is_empty():
				continue
			var slope: float = 0.0
			for m in range(1, 10):
				var g: Vector2 = _ground_gradient(ground, lerpf(hi.q.x, lo.q.x, m / 10.0), lerpf(hi.q.y, lo.q.y, m / 10.0))
				slope += minf(g.length(), 0.6) / 9.0
			var score: float = minf(drop, 40.0) / 20.0 + 4.0 * minf(slope, 0.3) + minf(road / straight, 4.0) / 4.0
			var group: String = "%d.%d-%d.%d" % [hi.edge, int(hi.s / 120.0), lo.edge, int(lo.s / 120.0)]
			var tie: int = ("%d|%s|%s" % [seed_value, hi.id, lo.id]).hash()
			var entry := {"id": "pair:%s~%s" % [hi.id, lo.id], "a": hi, "b": lo, "nodes": nodes, "straight_m": straight, "road_m": road, "drop_m": drop, "ground_slope": slope,
				"score": score, "tie": tie, "group": group}
			if not best.has(group) or _better(entry, best[group]):
				best[group] = entry
	var out: Array = best.values()
	out.sort_custom(_better)
	return out


## [high node, low node, high join distance, low join distance]: distinct
## incident nodes of the two ports' edges, nearest first ([] when none).
static func _distinct_nodes(hi: Dictionary, lo: Dictionary) -> Array:
	var options: Array = []
	for x: Array in hi.ends:
		for y: Array in lo.ends:
			if x[0] != y[0]:
				options.append([x[1] + y[1], x[0], y[0], x[1], y[1]])
	if options.is_empty():
		return []
	options.sort()
	return options[0].slice(1)


## Lattice nodes within TRAIL_CLEAR_M of a line become its band: crossable
## (1, with the line's direction) for a selected trail, blocked (2) for the
## way out of a destination route. A blocked node stays blocked.
static func _stamp(trail: Dictionary, state: _State, hard: bool = false) -> void:
	var cell: float = TrailPolicy.CELL_M
	var r: float = TrailPolicy.TRAIL_CLEAR_M
	var line: Dictionary = trail.line
	var n: int = line.x.size()
	for k in range(0, n, 2):
		var c := Vector2(line.x[k], line.z[k])
		var direction := (Vector2(line.x[mini(n - 1, k + 2)], line.z[mini(n - 1, k + 2)]) - Vector2(line.x[maxi(0, k - 2)], line.z[maxi(0, k - 2)])).normalized()
		for j in range(maxi(0, int(floor((c.y - r) / cell))), mini(state.lattice.y - 1, int(ceil((c.y + r) / cell))) + 1):
			for i in range(maxi(0, int(floor((c.x - r) / cell))), mini(state.lattice.x - 1, int(ceil((c.x + r) / cell))) + 1):
				var m: int = j * state.lattice.x + i
				if Vector2(i * cell, j * cell).distance_to(c) <= r and state.blocked[m] != 2:
					state.blocked[m] = 2 if hard else 1
					state.zone_dir[m] = direction


## A line against the selected trails' bands: it may cross a band at
## CROSS_SCREEN_DEG or more, at most MAX_CROSSINGS times, never run along
## one or enter a blocked node. {is_valid, crossings, stage, s_m}.
static func _zone_check(line: Dictionary, state: _State) -> Dictionary:
	var n: int = line.x.size()
	var crossings: int = 0
	var inside: bool = false
	var limit: float = cos(deg_to_rad(TrailPolicy.CROSS_SCREEN_DEG))
	for k in range(n):
		var p := Vector2(line.x[k], line.z[k])
		var zone: int = _zone_at(state, p)
		if zone == 0:
			inside = false
			continue
		if zone == 2:
			return {"is_valid": false, "crossings": crossings, "stage": "trail clearance", "s_m": line.s[k] if line.has("s") and k < line.s.size() else 0.0}
		var direction := (Vector2(line.x[mini(n - 1, k + 1)], line.z[mini(n - 1, k + 1)]) - Vector2(line.x[maxi(0, k - 1)], line.z[maxi(0, k - 1)])).normalized()
		if absf(direction.dot(_zone_dir_at(state, p))) > limit:
			return {"is_valid": false, "crossings": crossings, "stage": "along a trail", "s_m": line.s[k] if line.has("s") and k < line.s.size() else 0.0}
		if not inside:
			crossings += 1
			inside = true
	if crossings > TrailPolicy.MAX_CROSSINGS:
		return {"is_valid": false, "crossings": crossings, "stage": "crossings", "s_m": 0.0}
	return {"is_valid": true, "crossings": crossings, "stage": "", "s_m": 0.0}


static func _zone_at(state: _State, p: Vector2) -> int:
	var i: int = int(round(p.x / TrailPolicy.CELL_M))
	var j: int = int(round(p.y / TrailPolicy.CELL_M))
	if i < 0 or j < 0 or i >= state.lattice.x or j >= state.lattice.y:
		return 0
	return state.blocked[j * state.lattice.x + i]


static func _zone_dir_at(state: _State, p: Vector2) -> Vector2:
	var i: int = clampi(int(round(p.x / TrailPolicy.CELL_M)), 0, state.lattice.x - 1)
	var j: int = clampi(int(round(p.y / TrailPolicy.CELL_M)), 0, state.lattice.y - 1)
	return state.zone_dir[j * state.lattice.x + i]


static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.score != b.score:
		return a.score > b.score
	if a.tie != b.tie:
		return a.tie < b.tie
	return a.id < b.id


## A pair that repeats an accepted proposal's node pair or crosses its line.
static func _conflicts(pair: Dictionary, passed: Array) -> bool:
	var ends: Array = pair.nodes.slice(0, 2) if pair.has("nodes") else [pair.a.node, pair.b.node]
	for trail: Dictionary in passed:
		var nodes: Array = trail.nodes
		if (nodes[0] == ends[0] and nodes[1] == ends[1]) or (nodes[0] == ends[1] and nodes[1] == ends[0]):
			return true
	return false


## Shortest road distances between nodes (edges as undirected lengths).
static func _node_distances(data: Dictionary) -> Dictionary:
	var adjacency: Dictionary = {}
	var ids: Array = []
	for node: Dictionary in data.nodes:
		adjacency[node.id] = []
		ids.append(node.id)
	for edge: Dictionary in data.edges:
		adjacency[edge.a].append([edge.b, edge.length_m])
		adjacency[edge.b].append([edge.a, edge.length_m])
	ids.sort()
	var out: Dictionary = {}
	for source: int in ids:
		var best: Dictionary = {source: 0.0}
		var open: Array = [source]
		while not open.is_empty():
			var k: int = 0
			for m in range(1, open.size()):
				if best[open[m]] < best[open[k]]:
					k = m
			var node: int = open[k]
			open.remove_at(k)
			for link: Array in adjacency[node]:
				var d: float = best[node] + link[1]
				if not best.has(link[0]) or d < best[link[0]]:
					if not best.has(link[0]):
						open.append(link[0])
					best[link[0]] = d
		out[source] = best
	return out


static func _road_between(p: Dictionary, q: Dictionary, dist: Dictionary, lengths: Dictionary, ends: Dictionary, data: Dictionary) -> float:
	if p.edge == q.edge:
		return absf(p.s - q.s)
	var best: float = INF
	var pe: Array = _end_offsets(p, lengths, ends, data)
	var qe: Array = _end_offsets(q, lengths, ends, data)
	for x: Array in pe:
		for y: Array in qe:
			var between: float = dist.get(x[0], {}).get(y[0], INF)
			best = minf(best, x[1] + between + y[1])
	return best


## [[node, distance along the edge from the port]] for both ends of its edge.
static func _end_offsets(port: Dictionary, lengths: Dictionary, ends: Dictionary, data: Dictionary) -> Array:
	var length: float = lengths[port.edge]
	var pair: Array = ends[port.edge]
	var near: float = minf(port.s, length - port.s)
	var far: float = length - near
	var other: int = pair[1] if pair[0] == port.node else pair[0]
	return [[port.node, near], [other, far]]


# --- road distance and water ---

## Distance (m) from each lattice node to the nearest road plane edge, by
## stamping every road design sample (pieces and junction movements).
static func _road_distance(data: Dictionary, state: _State) -> PackedFloat32Array:
	var cell: float = TrailPolicy.CELL_M
	var out := PackedFloat32Array()
	out.resize(state.lattice.x * state.lattice.y)
	out.fill(INF)
	var reach: float = TrailPolicy.ROAD_NEAR_M
	for piece: Dictionary in data.pieces:
		var d: Dictionary = piece.design
		if d.is_empty() or not d.has("s"):
			continue
		for k in range(d.s.size()):
			var c := Vector2(d.x[k], d.z[k])
			var half: float = d.width[k] * 0.5
			var r: float = half + reach
			for j in range(maxi(0, int(floor((c.y - r) / cell))), mini(state.lattice.y - 1, int(ceil((c.y + r) / cell))) + 1):
				for i in range(maxi(0, int(floor((c.x - r) / cell))), mini(state.lattice.x - 1, int(ceil((c.x + r) / cell))) + 1):
					var e: float = Vector2(i * cell, j * cell).distance_to(c) - half
					var m: int = j * state.lattice.x + i
					if e < out[m]:
						out[m] = maxf(e, 0.0) if e > -half else -1.0
	return out


static func _road_at(state: _State, p: Vector2) -> float:
	var i: int = clampi(int(round(p.x / TrailPolicy.CELL_M)), 0, state.lattice.x - 1)
	var j: int = clampi(int(round(p.y / TrailPolicy.CELL_M)), 0, state.lattice.y - 1)
	return state.road[j * state.lattice.x + i]


## Water at a lattice node (lazy) - HydrologyField.sample_water.
static func _water_node(state: _State, i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= state.lattice.x or j >= state.lattice.y:
		return true
	var m: int = j * state.lattice.x + i
	if state.water[m] == 0:
		var b: Dictionary = state.bounds
		var w: Dictionary = state.context.field.sample_water(b.min_x + i * TrailPolicy.CELL_M, b.min_z + j * TrailPolicy.CELL_M)
		state.water[m] = 2 if w.get("is_water", false) or not w.get("is_valid", true) else 1
	return state.water[m] == 2


## Water within WATER_CLEAR_M of a point (its lattice node and neighbours).
static func _wet(p: Vector2, state: _State) -> bool:
	var i: int = int(round(p.x / TrailPolicy.CELL_M))
	var j: int = int(round(p.y / TrailPolicy.CELL_M))
	for dj in range(-1, 2):
		for di in range(-1, 2):
			if _water_node(state, i + di, j + dj):
				return true
	return false


# --- search ---

## A* over the lattice between the pair's ports. {is_valid, path:
## [Vector2 region-local], expanded, stage}.
static func _search(pair: Dictionary, state: _State) -> Dictionary:
	var cell: float = TrailPolicy.CELL_M
	var profile: Dictionary = state.profile
	var a: Vector2 = pair.leads[0]
	var b: Vector2 = pair.leads[1]
	var margin: float = maxf(60.0, 0.35 * a.distance_to(b))
	var lo := Vector2i(maxi(1, int(floor((minf(a.x, b.x) - margin) / cell))), maxi(1, int(floor((minf(a.y, b.y) - margin) / cell))))
	var limit := Vector2i(state.lattice.x - 2, state.lattice.y - 2)
	var edge_cells: int = int(ceil((Trail.MARGIN_M + 4.0) / cell))
	lo = Vector2i(maxi(lo.x, edge_cells), maxi(lo.y, edge_cells))
	var hi := Vector2i(mini(limit.x - edge_cells, int(ceil((maxf(a.x, b.x) + margin) / cell))), mini(limit.y - edge_cells, int(ceil((maxf(a.y, b.y) + margin) / cell))))
	var w: int = hi.x - lo.x + 1
	var h: int = hi.y - lo.y + 1
	var start := Vector2i(int(round(a.x / cell)), int(round(a.y / cell)))
	var goal := Vector2i(int(round(b.x / cell)), int(round(b.y / cell)))
	if start.x < lo.x or start.y < lo.y or start.x > hi.x or start.y > hi.y or goal.x < lo.x or goal.y < lo.y or goal.x > hi.x or goal.y > hi.y:
		return {"is_valid": false, "stage": "ports outside the search box", "expanded": 0}
	var count: int = w * h
	var g := PackedFloat32Array()
	g.resize(count)
	g.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-1)
	var closed := PackedByteArray()
	closed.resize(count)
	# Node state: 0 unknown, 1 free, 2 blocked.
	var free := PackedByteArray()
	free.resize(count)
	var heights := PackedFloat32Array()
	heights.resize(count)
	# Ground gradient per lattice node (lazy, NAN = not yet); a step uses the
	# mean of its two nodes.
	var grads := PackedVector2Array()
	grads.resize(count)
	grads.fill(Vector2(NAN, NAN))
	var heap := _Heap.new()
	var s_index: int = (start.y - lo.y) * w + start.x - lo.x
	var g_index: int = (goal.y - lo.y) * w + goal.x - lo.x
	g[s_index] = 0.0
	heap.push(a.distance_to(b), s_index)
	var expanded: int = 0
	var ground: Dictionary = state.context.ground
	var ratio: int = int(round(cell / ground.cell_m))
	var gnx: int = ground.nx
	var gh: PackedFloat32Array = ground.heights
	var ends: Array[Vector2] = [a, b]
	var cross_dot: float = cos(deg_to_rad(TrailPolicy.CROSS_SEARCH_DEG))
	while not heap.is_empty():
		var current: int = heap.pop()
		if closed[current] == 1:
			continue
		closed[current] = 1
		expanded += 1
		if current == g_index:
			break
		if expanded > TrailPolicy.SEARCH_BUDGET:
			return {"is_valid": false, "stage": "budget", "expanded": expanded}
		var ci: int = current % w + lo.x
		var cj: int = current / w + lo.y
		var hc: float = gh[cj * ratio * gnx + ci * ratio]
		if is_nan(grads[current].x):
			grads[current] = _ground_gradient(ground, ci * cell, cj * cell)
		var gc: Vector2 = grads[current]
		for step: Vector2i in STEPS:
			var ni: int = ci + step.x
			var nj: int = cj + step.y
			if ni < lo.x or nj < lo.y or ni > hi.x or nj > hi.y:
				continue
			var n_index: int = (nj - lo.y) * w + ni - lo.x
			if closed[n_index] == 1:
				continue
			if free[n_index] == 0:
				free[n_index] = 1 if _passable(state, ni, nj, ends) else 2
				heights[n_index] = gh[nj * ratio * gnx + ni * ratio]
			if free[n_index] == 2:
				continue
			if absi(step.x) + absi(step.y) == 3:
				# Knight step: both lattice nodes it passes between.
				var mi: int = ci + (step.x / 2 if absi(step.x) == 2 else 0)
				var mj: int = cj + (step.y / 2 if absi(step.y) == 2 else 0)
				if not _passable(state, mi, mj, ends) or not _passable(state, mi + (step.x if absi(step.x) == 1 else 0), mj + (step.y if absi(step.y) == 1 else 0), ends):
					continue
			var length: float = cell * Vector2(step).length()
			var hn: float = heights[n_index]
			var grade: float = absf(hn - hc) / length
			if grade > profile.grade_hard:
				continue
			var direction: Vector2 = Vector2(step).normalized()
			var band: float = 0.0
			if state.blocked[nj * state.lattice.x + ni] == 1:
				# A selected trail's band: crossed, never followed.
				if absf(direction.dot(state.zone_dir[nj * state.lattice.x + ni])) > cross_dot:
					continue
				band = TrailPolicy.W_CROSSING
			if is_nan(grads[n_index].x):
				grads[n_index] = _ground_gradient(ground, ni * cell, nj * cell)
			var cross: float = absf(((gc + grads[n_index]) * 0.5).dot(Vector2(-direction.y, direction.x)))
			if cross > profile.cross_hard:
				continue
			var road_d: float = state.road[nj * state.lattice.x + ni]
			var near: float = clampf(1.0 - (road_d - TrailPolicy.ROAD_CLEAR_M) / (TrailPolicy.ROAD_NEAR_M - TrailPolicy.ROAD_CLEAR_M), 0.0, 1.0)
			var shape_cost: float = profile.w_grade * pow(grade / profile.grade_pref, 2.0)
			if profile.directed:
				# Forward: a climb above climb_hard is impassable; a descent
				# costs its distance from the target descent.
				var descent: float = (hc - hn) / length
				if -descent > profile.climb_hard:
					continue
				shape_cost = profile.w_grade * pow((descent - profile.descent_target) / profile.descent_band, 2.0)
			var cost: float = length * (1.0 + shape_cost + profile.w_cross * pow(cross / profile.cross_pref, 2.0) + profile.w_road_near * near + band)
			var candidate: float = g[current] + cost
			if candidate < g[n_index]:
				g[n_index] = candidate
				parent[n_index] = current
				heap.push(candidate + Vector2(ni * cell, nj * cell).distance_to(b), n_index)
	if closed[g_index] == 0:
		return {"is_valid": false, "stage": "no path", "expanded": expanded}
	var path: Array[Vector2] = []
	var k: int = g_index
	while k >= 0:
		path.push_front(Vector2((k % w + lo.x) * cell, (k / w + lo.y) * cell))
		k = parent[k]
	return {"is_valid": true, "path": path, "expanded": expanded, "stage": ""}


## A lattice node the trail may use: published ground, dry within the water
## clearance, off road planes, ROAD_CLEAR_M from them except near the ports.
static func _passable(state: _State, i: int, j: int, ends: Array[Vector2]) -> bool:
	var cell: float = TrailPolicy.CELL_M
	var ground: Dictionary = state.context.ground
	var ratio: int = int(round(cell / ground.cell_m))
	if is_nan(ground.heights[j * ratio * ground.nx + i * ratio]):
		return false
	var road_d: float = state.road[j * state.lattice.x + i]
	var p := Vector2(i * cell, j * cell)
	if road_d < 0.0:
		return false
	if road_d < TrailPolicy.ROAD_CLEAR_M and p.distance_to(ends[0]) > 2.0 * TrailPolicy.ROAD_CLEAR_M and p.distance_to(ends[1]) > 2.0 * TrailPolicy.ROAD_CLEAR_M:
		return false
	if state.blocked[j * state.lattice.x + i] == 2 and p.distance_to(ends[0]) > 2.0 * TrailPolicy.ROAD_CLEAR_M and p.distance_to(ends[1]) > 2.0 * TrailPolicy.ROAD_CLEAR_M:
		return false
	return not _wet(p, state)


## Ground gradient (dh/dx, dh/dz) of the raster at a region-local point.
static func _ground_gradient(ground: Dictionary, x: float, z: float) -> Vector2:
	var d: float = ground.cell_m
	var hx0: float = Surface.ground_height(ground, x - d, z)
	var hx1: float = Surface.ground_height(ground, x + d, z)
	var hz0: float = Surface.ground_height(ground, x, z - d)
	var hz1: float = Surface.ground_height(ground, x, z + d)
	if is_nan(hx0) or is_nan(hx1) or is_nan(hz0) or is_nan(hz1):
		return Vector2(INF, INF)
	return Vector2((hx1 - hx0) / (2.0 * d), (hz1 - hz0) / (2.0 * d))


class _Heap:
	extends RefCounted
	var keys := PackedFloat64Array()
	var values := PackedInt32Array()

	func is_empty() -> bool:
		return values.is_empty()

	func push(key: float, value: int) -> void:
		keys.append(key)
		values.append(value)
		var k: int = values.size() - 1
		while k > 0:
			var up: int = (k - 1) / 2
			if keys[up] <= key:
				break
			keys[k] = keys[up]
			values[k] = values[up]
			k = up
		keys[k] = key
		values[k] = value

	func pop() -> int:
		var top: int = values[0]
		var last_key: float = keys[keys.size() - 1]
		var last_value: int = values[values.size() - 1]
		keys.resize(keys.size() - 1)
		values.resize(values.size() - 1)
		var n: int = values.size()
		if n == 0:
			return top
		var k: int = 0
		while true:
			var child: int = 2 * k + 1
			if child >= n:
				break
			if child + 1 < n and keys[child + 1] < keys[child]:
				child += 1
			if keys[child] >= last_key:
				break
			keys[k] = keys[child]
			values[k] = values[child]
			k = child
		keys[k] = last_key
		values[k] = last_value
		return top


# --- line ---

## Exit and lead-out of both ports (pair.exits, pair.leads): one straight
## line from the port's road point, obliquely away from the road and towards
## the other port, crossing the road edge and reaching the port's offset at
## the exit and LEAD_M beyond it at the lead-out, so the trail leaves the road
## without a bend there. A lead-out on blocked or steep ground rejects the pair.
static func _leads(pair: Dictionary, state: _State) -> bool:
	var exits: Array[Vector2] = []
	var leads: Array[Vector2] = []
	for end in range(2):
		var port: Dictionary = pair.a if end == 0 else pair.b
		var other: Dictionary = pair.b if end == 0 else pair.a
		var along: float = signf(port.tangent.dot(other.q - port.q))
		var direction: Vector2 = (port.normal + port.tangent * along * TrailPolicy.LEAD_SKEW).normalized()
		var reach: float = (port.q - port.road).dot(port.normal) / direction.dot(port.normal)
		var exit: Vector2 = port.road + direction * reach
		var lead: Vector2 = exit + direction * TrailPolicy.LEAD_M
		var near_port: Array[Vector2] = [exit, exit]
		for p: Vector2 in [exit, lead]:
			var cell := Vector2i(int(round(p.x / TrailPolicy.CELL_M)), int(round(p.y / TrailPolicy.CELL_M)))
			if cell.x < 1 or cell.y < 1 or cell.x >= state.lattice.x - 1 or cell.y >= state.lattice.y - 1 or not _passable(state, cell.x, cell.y, near_port):
				return false
		if not state.context.surface.road_owner(state.bounds.min_x + exit.x, state.bounds.min_z + exit.y).is_empty():
			return false
		var rise: float = Surface.ground_height(state.context.ground, lead.x, lead.y) - Surface.ground_height(state.context.ground, exit.x, exit.y)
		if not absf(rise) / TrailPolicy.LEAD_M <= state.profile.grade_hard:
			return false
		exits.append(exit)
		leads.append(lead)
	pair["exits"] = exits
	pair["leads"] = leads
	return true


## Control points: road point, port and lead-out of each end around the
## searched path simplified and resampled at control_spacing_m; `passes`
## corner cuts between the two ports (the road points and ports stay).
## `turns` (wavelength, amplitude; ZERO for none): linked turns - the
## corridor, smoothed, is offset sideways by amplitude * sin(2 pi s /
## wavelength), faded in and out over TURN_FADE_M at the lead-outs.
static func _control_points(pair: Dictionary, path: Array[Vector2], state: _State, passes: int, turns: Vector2) -> Array[Vector2]:
	var profile: Dictionary = state.profile
	var inner: Array[Vector2] = [pair.leads[0]]
	inner.append_array(path.slice(1, path.size() - 1))
	inner.append(pair.leads[1])
	var corridor: Array[Vector2] = _simplify(inner, profile.simplify_m)
	if turns != Vector2.ZERO:
		corridor = _linked_turns(corridor, turns.x, turns.y)
	var middle: Array[Vector2] = [pair.exits[0]]
	middle.append_array(_resample(corridor, profile.control_spacing_m))
	middle.append(pair.exits[1])
	for pass_index in range(passes):
		middle = _chaikin(middle)
	var out: Array[Vector2] = [pair.a.road]
	for p: Vector2 in middle:
		if p.distance_to(out[out.size() - 1]) >= 2.0:
			out.append(p)
	if out[out.size() - 1].distance_to(pair.b.road) < 2.0:
		out.remove_at(out.size() - 1)
	out.append(pair.b.road)
	return out


static func _linked_turns(corridor: Array[Vector2], wavelength: float, amplitude: float) -> Array[Vector2]:
	var smooth: Array[Vector2] = corridor
	for pass_index in range(3):
		smooth = _chaikin(smooth)
	var dense: Array[Vector2] = _resample(smooth, 2.0)
	var n: int = dense.size()
	var s := PackedFloat64Array([0.0])
	for k in range(1, n):
		s.append(s[k - 1] + dense[k].distance_to(dense[k - 1]))
	var total: float = s[n - 1]
	var out: Array[Vector2] = []
	for k in range(n):
		var direction: Vector2 = (dense[mini(n - 1, k + 3)] - dense[maxi(0, k - 3)]).normalized()
		var fade: float = smoothstep(0.0, TrailPolicy.TURN_FADE_M, s[k]) * smoothstep(0.0, TrailPolicy.TURN_FADE_M, total - s[k])
		out.append(dense[k] + Vector2(-direction.y, direction.x) * amplitude * fade * sin(TAU * s[k] / wavelength))
	return out


static func _simplify(points: Array[Vector2], tolerance: float) -> Array[Vector2]:
	if points.size() <= 2:
		return points.duplicate()
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep[0] = 1
	keep[points.size() - 1] = 1
	var stack: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not stack.is_empty():
		var span: Vector2i = stack.pop_back()
		var worst: float = 0.0
		var index: int = -1
		for k in range(span.x + 1, span.y):
			var d: float = Geometry2D.get_closest_point_to_segment(points[k], points[span.x], points[span.y]).distance_to(points[k])
			if d > worst:
				worst = d
				index = k
		if index >= 0 and worst > tolerance:
			keep[index] = 1
			stack.append(Vector2i(span.x, index))
			stack.append(Vector2i(index, span.y))
	var out: Array[Vector2] = []
	for k in range(points.size()):
		if keep[k] == 1:
			out.append(points[k])
	return out


static func _resample(points: Array[Vector2], spacing: float) -> Array[Vector2]:
	var out: Array[Vector2] = [points[0]]
	for k in range(1, points.size()):
		var a: Vector2 = points[k - 1]
		var b: Vector2 = points[k]
		var pieces: int = maxi(1, int(ceil(a.distance_to(b) / spacing)))
		for m in range(1, pieces + 1):
			out.append(a.lerp(b, float(m) / pieces))
	return out


## One corner-cutting pass; the end points stay.
static func _chaikin(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() < 3:
		return points.duplicate()
	var out: Array[Vector2] = [points[0]]
	for k in range(points.size() - 1):
		var a: Vector2 = points[k]
		var b: Vector2 = points[k + 1]
		if k > 0:
			out.append(a.lerp(b, 0.25))
		if k < points.size() - 2:
			out.append(a.lerp(b, 0.75))
	out.append(points[points.size() - 1])
	return out


# --- screening and the exact check ---

## The curve TrailRealization will build through `points`, measured on the
## raster: water, grade, pitch, side slope and radius (stage names as
## TrailRealization). {is_valid, line, metrics} or {is_valid: false, detail}.
static func _screen(points: Array[Vector2], state: _State) -> Dictionary:
	var made: Dictionary = Trail._line(points, state.profile.half_width_m, state.context.surface, state.bounds)
	if not made.is_valid:
		return {"is_valid": false, "detail": made.detail}
	var ground: Dictionary = state.context.ground
	var n: int = made.s.size()
	var heights := PackedFloat64Array()
	for k in range(n):
		var h: float = Surface.ground_height(ground, made.x[k], made.z[k])
		if is_nan(h):
			return {"is_valid": false, "detail": {"stage": "ground", "s_m": made.s[k]}}
		heights.append(h)
	var metrics := {"max_grade": 0.0, "max_cross_slope": 0.0, "climb_m": 0.0, "descent_m": 0.0, "water_near_m": 0.0, "min_radius_m": INF, "turns": 0, "steep_share": 0.0}
	var w: int = int(round(Trail.GRADE_WINDOW_M / Trail.SAMPLE_M / 2.0))
	var r: int = int(round(Trail.RADIUS_WINDOW_M / Trail.SAMPLE_M))
	var limits: Dictionary = state.limits
	var grade_limit: float = limits.grade * 0.97
	var climb_limit: float = limits.climb * 0.95
	if is_finite(limits.climb) and heights[n - 1] >= heights[0]:
		return {"is_valid": false, "detail": {"stage": "direction"}}
	var steep: float = 0.0
	for k in range(n):
		var p := Vector2(made.x[k], made.z[k])
		var road_d: float = _road_at(state, p)
		var on_road: bool = road_d < 0.0
		if not on_road and _wet(p, state):
			return {"is_valid": false, "detail": {"stage": "water", "s_m": made.s[k]}}
		if k > 0:
			var rise: float = heights[k] - heights[k - 1]
			metrics.climb_m += maxf(rise, 0.0)
			metrics.descent_m += maxf(-rise, 0.0)
			if absf(rise) / maxf(made.s[k] - made.s[k - 1], 1e-9) > Trail.PITCH_GRADE_MAX * 0.95:
				return {"is_valid": false, "detail": {"stage": "pitch", "s_m": made.s[k]}}
		var a: int = maxi(0, k - w)
		var b: int = mini(n - 1, k + w)
		if b > a:
			var grade: float = absf(heights[b] - heights[a]) / (made.s[b] - made.s[a])
			metrics.max_grade = maxf(metrics.max_grade, grade)
			if grade > grade_limit:
				return {"is_valid": false, "detail": {"stage": "grade", "s_m": made.s[k], "grade": grade}}
			var descent: float = (heights[a] - heights[b]) / (made.s[b] - made.s[a])
			if -descent > climb_limit and not on_road:
				return {"is_valid": false, "detail": {"stage": "forward climb", "s_m": made.s[k], "grade": -descent}}
			if descent >= TrailPolicy.STEEP_DESCENT and k > 0:
				steep += made.s[k] - made.s[k - 1]
		if not on_road:
			var gradient: Vector2 = _ground_gradient(ground, p.x, p.y)
			var cross: float = absf(gradient.dot(Vector2(-made.tz[k], made.tx[k])))
			metrics.max_cross_slope = maxf(metrics.max_cross_slope, cross)
			if cross > Trail.CROSS_SLOPE_MAX * 0.95:
				return {"is_valid": false, "detail": {"stage": "side slope", "s_m": made.s[k], "slope": cross}}
		if k - r >= 0 and k + r < n:
			var pa := Vector2(made.x[k - r], made.z[k - r])
			var pc := Vector2(made.x[k + r], made.z[k + r])
			var area: float = (p - pa).cross(pc - pa)
			var radius: float = pa.distance_to(p) * p.distance_to(pc) * pa.distance_to(pc) / maxf(2.0 * absf(area), 1e-12)
			metrics.min_radius_m = minf(metrics.min_radius_m, radius)
			if radius < limits.radius * 1.1:
				return {"is_valid": false, "detail": {"stage": "radius", "s_m": made.s[k], "radius_m": radius}}
		if k > 0 and not on_road:
			var near_water: bool = false
			for probe: float in [-12.0, 12.0]:
				var normal := Vector2(-made.tz[k], made.tx[k])
				near_water = near_water or _wet(p + normal * probe, state)
			if near_water:
				metrics.water_near_m += made.s[k] - made.s[k - 1]
	metrics.steep_share = steep / made.s[n - 1]
	metrics.turns = _turns(made)
	var zones: Dictionary = _zone_check(made, state)
	if not zones.is_valid:
		return {"is_valid": false, "detail": {"stage": zones.stage, "s_m": zones.s_m, "crossings": zones.crossings}}
	metrics["crossings"] = zones.crossings
	return {"is_valid": true, "line": made, "metrics": metrics}


## Linked turns of a line: maximal runs where the heading changes by at least
## TURN_MIN_DEG over TURN_WINDOW_M, one per run and alternating side counted
## once each.
static func _turns(line: Dictionary) -> int:
	var n: int = line.s.size()
	var h: int = int(round(TrailPolicy.TURN_WINDOW_M / Trail.SAMPLE_M / 2.0))
	var count: int = 0
	var inside: int = 0
	for k in range(h, n - h):
		var a := Vector2(line.tx[k - h], line.tz[k - h])
		var b := Vector2(line.tx[k + h], line.tz[k + h])
		var turn: float = rad_to_deg(a.angle_to(b))
		var side: int = 0 if absf(turn) < TrailPolicy.TURN_MIN_DEG else (1 if turn > 0.0 else -1)
		if side != 0 and side != inside:
			count += 1
		inside = side
	return count


## TrailRealization on the published triangles of the line's zone.
static func _realize(pair: Dictionary, points: Array[Vector2], screened: Dictionary, state: _State) -> Dictionary:
	var context: Dictionary = state.context
	var profile: Dictionary = state.profile
	var directed: bool = profile.directed
	var ends: Array = pair.nodes if pair.has("nodes") else [pair.a.node, pair.b.node]
	var node_a: Dictionary = _node(context.network, ends[0])
	var node_b: Dictionary = _node(context.network, ends[1])
	var purpose: String = _purpose(pair, screened, directed)
	if pair.has("intent"):
		purpose += "; realizes the R5 natural route edge:%d" % pair.intent
	var id: String = "trail:%s_%d_%d_%s_%s" % [profile.id_prefix, ends[0], ends[1], String(pair.a.id).replace("edge:", "e").replace("@", "_"),
		String(pair.b.id).replace("edge:", "e").replace("@", "_")]
	var control: Array = []
	for p: Vector2 in points:
		control.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
	var trail := {"id": id, "mode": "NATURAL", "purpose": purpose, "nodes": [{"id": node_a.id, "x_m": node_a.x_m, "z_m": node_a.z_m}, {"id": node_b.id, "x_m": node_b.x_m, "z_m": node_b.z_m}],
		"half_width_m": profile.half_width_m, "control_points": control, "operations": []}
	if directed:
		trail["class"] = state.class_name_value
	if pair.has("nodes"):
		# Joins anywhere on the ports' edges (a node of each edge, see _distinct_nodes).
		trail["join_max_m"] = snappedf(maxf(pair.nodes[2], pair.nodes[3]) + 20.0, 1.0)
	var config := {"schema": Trail.SCHEMA, "seed": context.seed, "region": [context.region.x, context.region.y], "trails": [trail]}
	var line: Dictionary = screened.line
	var zone := {"id": id, "half_width_m": profile.half_width_m, "operations": [], "line": {"s": line.s, "x": line.x, "y": line.y, "z": line.z, "tx": line.tx, "tz": line.tz}}
	var published: RefCounted = context.surface.with_trails([zone]).with_published(_tiles_near(line, context.slots, state.bounds))
	var checked := context.duplicate()
	checked.surface = published
	var made: Dictionary = Trail.realize(trail, config, checked)
	if not made.is_valid:
		return made
	var record: Dictionary = made.trail
	var gain: float = pair.road_m - record.length_m
	var relief: float = record.metrics.climb_m + record.metrics.descent_m
	var score: float = minf(pair.road_m / record.length_m, 3.0) + 0.02 * minf(relief, 30.0) + 0.5 * minf(screened.metrics.water_near_m / record.length_m, 0.5)
	if directed:
		score = _technical_value(screened) + minf(pair.drop_m, 40.0) / 20.0
	record["class_name"] = state.class_name_value
	record["origin"] = "PROCEDURAL"
	record["planner"] = {"pair": pair.id, "ports": [pair.a.id, pair.b.id], "road_m": pair.road_m, "straight_m": pair.straight_m, "gain_m": gain, "score": score,
		"water_near_m": screened.metrics.water_near_m, "config": trail}
	if pair.has("via"):
		record.planner["destination"] = {"x_m": pair.via.x, "z_m": pair.via.y, "height_m": pair.destination.h, "prominence_m": pair.destination.prominence}
		if not directed:
			score = pair.score + 1.0
	if pair.has("intent"):
		record.planner.score += INTENT_BONUS
		record.planner["intent"] = pair.intent
	if directed:
		record.planner.merge({"drop_m": pair.drop_m, "ground_slope": pair.ground_slope, "turns": screened.metrics.turns, "steep_share": screened.metrics.steep_share,
			"return": {"via": "road", "road_m": pair.road_m}})
	return {"is_valid": true, "trail": record}


static func _node(data: Dictionary, id: int) -> Dictionary:
	for node: Dictionary in data.nodes:
		if node.id == id:
			return node
	return {}


## Why the trail exists, from what its line meets.
static func _purpose(pair: Dictionary, screened: Dictionary, directed: bool) -> String:
	var m: Dictionary = screened.metrics
	var length: float = screened.line.s[screened.line.s.size() - 1]
	if pair.has("via"):
		if directed:
			return "KNOLL_DESCENT: climbs gently %d m from %s to a knoll and drops %d m down its flank to %s in %d linked turns over %d m; back by road %d m" % [
				int(round(pair.rise_m)), pair.a.piece, int(round(pair.drop_m)), pair.b.piece, m.turns, int(round(length)), int(round(pair.road_m))]
		return "VIEWPOINT_LOOP: leaves %s, climbs %d m to a knoll %d m above its surroundings and returns to %s; %d m of trail" % [pair.a.piece, int(round(pair.rise_m)),
			int(round(pair.destination.prominence)), pair.b.piece, int(round(length))]
	if directed:
		return "%s: drops %d m from %s down the %s to %s in %d linked turns over %d m; back up by road %d m" % ["SCARP_DESCENT" if pair.ground_slope >= 0.15 else "SLOPE_DESCENT",
			int(round(pair.drop_m)), pair.a.piece, "terrace scarp" if pair.ground_slope >= 0.15 else "slope", pair.b.piece, m.turns, int(round(length)), int(round(pair.road_m))]
	var kind: String = "MEADOW_SHORTCUT"
	if m.water_near_m >= 0.15 * length:
		kind = "CREEK_PASSAGE"
	elif m.climb_m + m.descent_m >= 18.0:
		kind = "HILLSIDE_CUT"
	elif m.max_cross_slope >= 0.15:
		kind = "SLOPE_TRAVERSE"
	return "%s: leaves %s near junction %d for natural ground and rejoins %s near junction %d; %d m of trail instead of %d m of road" % [kind, pair.a.piece, pair.a.node,
		pair.b.piece, pair.b.node, int(round(length)), int(round(pair.road_m))]


## Tile slots whose square (grown by the trail reach) holds a line sample.
static func _tiles_near(line: Dictionary, slots: Array, bounds: Dictionary) -> Array:
	var out: Array = []
	for slot: Dictionary in slots:
		var rect := Rect2(slot.tx * TILE_M - bounds.min_x, slot.tz * TILE_M - bounds.min_z, TILE_M, TILE_M).grow(Surface.TRAIL_REACH_M + 4.0)
		for k in range(0, line.s.size(), 2):
			if rect.has_point(Vector2(line.x[k], line.z[k])):
				out.append(slot)
				break
	return out
