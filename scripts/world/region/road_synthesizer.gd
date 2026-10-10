class_name RoadSynthesizer
extends RefCounted

## R6 regional road synthesis (ExecPlan v1.0 + Director conditions C1-C5):
## the single producer of RoadSynthesisPlan. Consumes the accepted R5 graph
## through its RouteCorridor views and composes its own R3/R4 views from
## (RegionPlan, TerrainField, HydrologyPlan) exactly as RoutePlanner does, so
## input identity is checked, never assumed. One invocation owns its query
## caches, candidate workspaces and diagnostics and releases them on return.
##
## Stages (stable order, no request-order dependence):
##   1. inputs, signatures, settings;      2. bands for every edge;
##   3. junctions: shared patch, ports, movements (RoadJunctionPlanner);
##   4. edges by (class, edge id): terrain-led design (RoadAlignmentDesigner),
##      road-road conflicts against already accepted edges retried once with
##      avoidance, then diagnosed;
##   5. certification of every piece (RoadFeasibilityValidator), seams at
##      every port, overlaps, feature realisation;
##   6. roadbed intents, network continuity, plan assembly and signature.
## Outcomes: READY (everything available), PARTIAL (every outcome recorded,
## some unavailable), REJECT (invalid inputs/settings; no plan), FAIL
## (internal invariant; no plan). The graph is never edited; nothing failed is
## exported; there is no straight or emergency fallback.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const Plan = preload("res://scripts/world/region/road_synthesis_plan.gd")
const Geo = preload("res://scripts/world/region/road_corridor_geometry.gd")
const Designer = preload("res://scripts/world/region/road_alignment_designer.gd")
const Junctions = preload("res://scripts/world/region/road_junction_planner.gd")
const Validator = preload("res://scripts/world/region/road_feasibility_validator.gd")
const Intent = preload("res://scripts/world/region/roadbed_intent.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Region = preload("res://scripts/world/region/region_plan.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")

var _graph: RefCounted
var _region_plan: RefCounted
var _hydrology_plan: RefCounted
var _ride: RefCounted
var _natural: Geo.Natural
var _designer: Designer
var _junctions: Junctions
var _validator: Validator
var _settings: Dictionary
var _bands: Array = []
var _timings: Dictionary = {}


static func _result(status: int, plan: RefCounted, reason: String, diagnostics: Dictionary) -> Dictionary:
	return {"schema": Policy.RESULT_SCHEMA, "status": Policy.STATUS_NAMES[status], "is_valid": status == Policy.Status.READY, "plan": plan, "reason_code": reason, "diagnostics": diagnostics}


static func synthesize(region_plan: RefCounted, terrain_field: RefCounted, hydrology_plan: RefCounted, graph: RefCounted, settings: Variant = {}) -> Dictionary:
	if region_plan == null or terrain_field == null or hydrology_plan == null or graph == null:
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_MISSING", {})
	if not region_plan is Region or not terrain_field is Terrain or not hydrology_plan is Hydro or not graph is Graph:
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_INVALID", {})
	if not region_plan.validate().is_valid or not graph.validate().is_valid:
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_INVALID", {"note": "region plan or route graph does not validate"})
	var resolved: Dictionary = Policy.resolve_settings(settings)
	if not resolved.is_valid:
		return _result(Policy.Status.REJECT, null, resolved.reason_code, {})
	var data: Dictionary = graph.get_data()
	var bounds: RefCounted = region_plan.get_bounds()
	if terrain_field.get_region_signature() != region_plan.signature() or hydrology_plan.get_region_signature() != region_plan.signature() \
			or data.region_signature != region_plan.signature() or data.hydrology_signature != hydrology_plan.signature() \
			or graph.get_origin_x_m() != bounds.get_min_x_m() or graph.get_origin_z_m() != bounds.get_min_z_m():
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_MISMATCH", {})
	var context: Dictionary = Context.create(region_plan, terrain_field, hydrology_plan)
	if not context.is_valid:
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_INVALID", {"dependency": context.reason_code})
	var biome: Dictionary = Biome.create(context.context)
	var ride: Dictionary = Ride.create(context.context, biome.field) if biome.is_valid else {"is_valid": false, "reason_code": biome.reason_code}
	var hydro: Dictionary = HField.create(hydrology_plan, terrain_field)
	var surface: Dictionary = Surface.create(terrain_field, hydro.field) if hydro.is_valid else {"is_valid": false, "reason_code": hydro.reason_code}
	if not ride.is_valid or not surface.is_valid:
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_INVALID", {"dependency": [ride.reason_code, surface.reason_code]})
	if data.rideability_signature != ride.field.signature():
		return _result(Policy.Status.REJECT, null, "ERR_R6_INPUT_MISMATCH", {"note": "rideability signature"})
	var synthesizer := RoadSynthesizer.new()
	synthesizer._graph = graph
	synthesizer._region_plan = region_plan
	synthesizer._hydrology_plan = hydrology_plan
	synthesizer._ride = ride.field
	synthesizer._settings = resolved.settings
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	synthesizer._natural = Geo.Natural.create(surface.surface, ride.field, hydro.field, hydrology_plan, ox, oz, resolved.settings.max_natural_queries)
	synthesizer._designer = Designer.create(synthesizer._natural, resolved.settings.max_fit_evaluations)
	synthesizer._junctions = Junctions.create(synthesizer._natural)
	synthesizer._validator = Validator.create(synthesizer._natural)
	return synthesizer._run()


func _tick(stage: String, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	_timings[stage] = _timings.get(stage, 0.0) + (now - since) / 1e6
	return now


func _run() -> Dictionary:
	var t: int = Time.get_ticks_usec()
	var graph: RefCounted = _graph
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var edge_count: int = graph.get_edge_count()
	var edges: Array = []
	for e in range(edge_count):
		edges.append(graph.get_edge(e))
		_bands.append(Geo.Band.from_corridor(graph.get_corridor(e), ox, oz))
	var nodes: Array = []
	for n in range(graph.get_route_node_count()):
		nodes.append(graph.get_route_node(n))
	var routes: Array = []
	for r in range(graph.get_route_count()):
		routes.append(graph.get_route(r))
	t = _tick("inputs", t)
	# --- 3. Junctions ---
	var junctions: Dictionary = {}
	var ports: Dictionary = {}
	for node: Dictionary in nodes:
		if node.kind != Graph.NodeKind.JUNCTION:
			continue
		var incident: Array = []
		for e: int in graph.edges_at(node.id):
			var band: Geo.Band = _bands[e]
			var at_start: bool = edges[e].a == node.id
			var cap: float = INF
			for crossing: Dictionary in graph.get_corridor(e).crossings:
				var u: float = band.project_u(crossing.x_cm / 100.0, crossing.z_cm / 100.0)
				var from_node: float = u if at_start else band.length() - u
				if from_node < 60.0:
					cap = minf(cap, from_node - 10.0)
			incident.append({"edge_id": e, "class": edges[e].class, "band": band, "at_start": at_start, "route_id": edges[e].route_id, "radius_cap": cap})
		incident.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.edge_id < b.edge_id)
		var record: Dictionary = _junctions.plan_junction(node, incident, routes)
		junctions[node.id] = record
		for port: Dictionary in record.ports:
			ports[Vector2i(node.id, port.edge_id)] = port
	t = _tick("junctions", t)
	# --- 4. Edges in (class, id) order ---
	var order: Array = range(edge_count)
	order.sort_custom(func(a: int, b: int) -> bool: return edges[a].class < edges[b].class or (edges[a].class == edges[b].class and a < b))
	var edge_records: Dictionary = {}
	var pieces: Dictionary = {}
	var crossing_records: Array = []
	var accepted: Array = []
	for e: int in order:
		var outcome: Dictionary = _edge(e, edges, nodes, junctions, ports, accepted)
		edge_records[e] = outcome.record
		crossing_records.append_array(outcome.crossings)
		if outcome.has("piece"):
			pieces[outcome.piece.piece_id] = outcome.piece
			accepted.append({"piece_id": outcome.piece.piece_id, "design": outcome.piece.design, "zones": outcome.zones, "shoulder_m": Policy.CLASSES[edges[e].class].shoulder_m, "edge": e})
	t = _tick("edges", t)
	# --- 5. Connectors, seams ---
	var junction_records: Array = []
	var node_ids: Array = junctions.keys()
	node_ids.sort()
	for node_id: int in node_ids:
		var record: Dictionary = junctions[node_id]
		var incident_bands: Array = []
		for e: int in graph.edges_at(node_id):
			incident_bands.append(_bands[e])
		for movement: Dictionary in record.movements:
			movement["seams"] = []
			if movement.status != Policy.MOVEMENT_READY:
				movement.erase("design")
				continue
			var check: Dictionary = _validator.validate_piece(movement.design, {"route_class": movement.limit_class, "band_request": {"union_bands": incident_bands}, "is_connector": true})
			movement["certification"] = check.measured
			if not check.is_valid:
				movement.status = Policy.MOVEMENT_UNAVAILABLE
				movement.reasons.append_array(check.reasons)
				movement.erase("design")
				continue
			var lower: int = movement.edges[0]
			var upper: int = movement.edges[1]
			for pair: Array in [[lower, false], [upper, true]]:
				var e: int = pair[0]
				var piece_id: String = "edge:%d" % e
				if not pieces.has(piece_id):
					movement.seams.append({"edge_id": e, "status": "EDGE_UNAVAILABLE"})
					continue
				var design: Dictionary = pieces[piece_id].design
				var edge_at_start: bool = edges[e].a == node_id
				var result: Dictionary
				if not pair[1]:
					# Travel edge -> connector: edge arrives at the node.
					var arrive: Dictionary = Validator.end_row(design, not edge_at_start, edge_at_start)
					result = Validator.seam(arrive, Validator.end_row(movement.design, false, false))
				else:
					var leave: Dictionary = Validator.end_row(design, not edge_at_start, not edge_at_start)
					result = Validator.seam(Validator.end_row(movement.design, true, false), leave)
				result["edge_id"] = e
				result["status"] = "OK" if result.reasons.is_empty() else "FAIL"
				movement.seams.append(result)
				if not result.reasons.is_empty():
					movement.status = Policy.MOVEMENT_UNAVAILABLE
					movement.reasons.append("ERR_R6_SEAM")
			if movement.status == Policy.MOVEMENT_READY:
				pieces[movement.piece_id] = {"piece_id": movement.piece_id, "kind": "MOVEMENT", "owner": {"node_id": node_id, "edges": movement.edges}, "route_class": movement.limit_class,
					"design": movement.design}
			movement.erase("design")
		_junction_status(record)
		junction_records.append(record)
	t = _tick("connectors", t)
	# Overlaps among all accepted edge pieces (final state, informative).
	var overlap: Array = Validator.overlaps(accepted)
	t = _tick("overlaps", t)
	# --- 6. Intents, network, plan ---
	var signatures := {"origin": {"x_m": graph.get_origin_x_m(), "z_m": graph.get_origin_z_m(), "y_m": 0},
		"natural": (_region_plan.signature() + _hydrology_plan.signature() + _ride.signature()).sha256_text(), "policy": Policy.digest()}
	var intents: Array = []
	for piece_id: String in _sorted_keys(pieces):
		var piece: Dictionary = pieces[piece_id]
		var refs: Array = []
		for c: Dictionary in crossing_records:
			if piece.kind == "EDGE" and c.edge_id == piece.owner.edge_id and c.status == "RESOLVED":
				refs.append(c.design)
		var intent: Dictionary = Intent.from_piece(piece_id, piece.owner, piece.route_class, piece.design, refs, signatures, piece.kind == "MOVEMENT")
		var check: Dictionary = Intent.validate(intent)
		if not check.is_valid:
			intent.status = "UNSUPPORTED"
			intent["reasons"] = check.reason_codes
		intents.append(intent)
	for record: Dictionary in junction_records:
		var patch_intent: Dictionary = Intent.from_patch(record, signatures)
		var check: Dictionary = Intent.validate(patch_intent)
		if not check.is_valid:
			patch_intent.status = "UNSUPPORTED"
			patch_intent["reasons"] = check.reason_codes
		record.patch.erase("samples")
		intents.append(patch_intent)
	var network: Dictionary = _network(edges, nodes, routes, edge_records, junctions)
	t = _tick("intents_network", t)
	var edge_list: Array = []
	for e in range(edge_count):
		edge_list.append(edge_records[e])
	for c: Dictionary in crossing_records:
		c.erase("design")
	crossing_records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.crossing_id < b.crossing_id)
	var all_edges: bool = true
	for record: Dictionary in edge_list:
		all_edges = all_edges and record.status == "READY"
	var all_junctions: bool = true
	for record: Dictionary in junction_records:
		all_junctions = all_junctions and record.status == Policy.JUNCTION_READY
	var all_crossings: bool = true
	for c: Dictionary in crossing_records:
		all_crossings = all_crossings and c.status == "RESOLVED"
	var reasons: Array = []
	for record: Dictionary in edge_list:
		for r: String in record.reasons:
			if not r in reasons:
				reasons.append(r)
	for record: Dictionary in junction_records:
		for r: String in record.reasons:
			if not r in reasons:
				reasons.append(r)
	var status: int = Policy.Status.READY if all_edges and all_junctions and all_crossings and overlap.is_empty() else Policy.Status.PARTIAL
	var region_seed: int = _region_plan.get_identity().get_region_seed()
	# Pieces carry their export digest (float32 RoadPathData identity).
	for piece_id: String in pieces:
		var path: RefCounted = Plan.export_path(pieces[piece_id].design, false)
		pieces[piece_id]["export_sha256"] = Plan._sha256(Plan.export_bytes(path))
		pieces[piece_id]["samples"] = pieces[piece_id].design.s.size()
		pieces[piece_id]["length_m"] = pieces[piece_id].design.s[pieces[piece_id].design.s.size() - 1]
	var data := {"schema": Policy.PLAN_SCHEMA, "policy_id": Policy.POLICY_ID, "policy_digest": Policy.digest(), "algorithm": Policy.ALGORITHM,
		"effective_seed": Seeds.road_synthesis_seed(region_seed), "origin_x_m": graph.get_origin_x_m(), "origin_z_m": graph.get_origin_z_m(), "origin_y_m": 0,
		"region_signature": _region_plan.signature(), "graph_signature": graph.signature(), "hydrology_signature": _hydrology_plan.signature(), "rideability_signature": _ride.signature(),
		"settings": _settings, "status": Policy.STATUS_NAMES[status], "reason_codes": reasons, "edges": edge_list, "junctions": junction_records, "crossings": crossing_records,
		"pieces": pieces, "intents": intents, "network": network, "overlaps": overlap}
	var diagnostics := {"timings_s": _timings, "natural_queries": _natural.queries, "ride_queries": _natural.ride_queries, "validator_ride_samples": _validator.ride_samples,
		"fit_evaluations": _designer.fit_evaluations + _junctions.fit_evaluations, "dp_transitions": _designer.dp_transitions, "budgets": _settings}
	# Diagnostic records may hold unbounded measures (e.g. no sight station
	# checked, no feasible connector). Canonical encoding refuses non-finite
	# numbers, so they become null and are counted. Design arrays are never
	# touched here: they are certified finite by the validator.
	var counter: Array = [0]
	for key: String in ["edges", "junctions", "crossings", "intents", "network", "overlaps"]:
		data[key] = _finite(data[key], counter)
	data["nonfinite_diagnostics"] = counter[0]
	var plan := Plan.new(data, diagnostics)
	var self_check: Dictionary = plan.validate()
	if not self_check.is_valid:
		return _result(Policy.Status.FAIL, null, self_check.reason_codes[0], {"self_check": self_check, "timings_s": _timings})
	var first_reason: String = "" if reasons.is_empty() else reasons[0]
	return _result(status, plan, first_reason if status != Policy.Status.READY else "", diagnostics)


static func _finite(value: Variant, counter: Array) -> Variant:
	if value is float:
		if not is_finite(value):
			counter[0] += 1
			return null
		return value
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _finite(value[key], counter)
		return out
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_finite(item, counter))
		return out
	if value is PackedFloat64Array:
		for v: float in value:
			if not is_finite(v):
				var out: Array = []
				for w: float in value:
					out.append(w if is_finite(w) else null)
				counter[0] += 1
				return out
	return value


static func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = d.keys()
	keys.sort()
	return keys


static func _junction_status(record: Dictionary) -> void:
	var patch_failed: bool = "ERR_R6_JUNCTION_HEIGHT" in record.reasons or "ERR_R6_CROSSING_APPROACH" in record.reasons
	var all_ready: bool = true
	var essential_ready: bool = true
	for movement: Dictionary in record.movements:
		if movement.status != Policy.MOVEMENT_READY:
			all_ready = false
			if movement.essential:
				essential_ready = false
	record.reasons = record.reasons.filter(func(r: String) -> bool: return r != "ERR_R6_JUNCTION_MOVEMENT")
	if not all_ready:
		record.reasons.append("ERR_R6_JUNCTION_MOVEMENT")
	if patch_failed or not essential_ready:
		record.status = Policy.JUNCTION_BLOCKED
	elif not all_ready:
		record.status = Policy.JUNCTION_USABLE
	else:
		record.status = Policy.JUNCTION_READY


## One edge interior: request, design, conflict retry, certification.
func _edge(e: int, edges: Array, nodes: Array, junctions: Dictionary, ports: Dictionary, accepted: Array) -> Dictionary:
	var graph: RefCounted = _graph
	var edge: Dictionary = edges[e]
	var corridor: Dictionary = graph.get_corridor(e)
	var band: Geo.Band = _bands[e]
	var route_class: int = edge.class
	var record := {"edge_id": e, "route_id": edge.route_id, "class": route_class, "class_name": Graph.CLASS_NAMES[route_class], "a": edge.a, "b": edge.b,
		"port_a": "", "port_b": "", "status": "REPLAN_REQUIRED", "reasons": [], "piece_id": "", "features": [], "crossing_ids": [], "candidates": [], "metrics": {}, "detail": {}}
	var ends: Array = []
	var zones: Array = []
	for which: int in [0, 1]:
		var node_id: int = edge.a if which == 0 else edge.b
		var node: Dictionary = nodes[node_id]
		if node.kind == Graph.NodeKind.JUNCTION and ports.has(Vector2i(node_id, e)):
			var port: Dictionary = ports[Vector2i(node_id, e)]
			var sign: float = 1.0 if which == 0 else -1.0
			ends.append({"x": port.x, "z": port.z, "y": port.y, "tx": sign * port.tx, "tz": sign * port.tz, "grade": sign * port.grade_out, "grade_pinned": true,
				"bank_deg": sign * port.bank_out_deg, "port_id": port.port_id, "radius_m": port.radius_m})
			var others: Array = []
			for other: int in graph.edges_at(node_id):
				if other != e:
					others.append(_bands[other])
			zones.append({"x": node.x_cm / 100.0, "z": node.z_cm / 100.0, "bands": others, "node_id": node_id})
		else:
			var nx: float = node.x_cm / 100.0
			var nz: float = node.z_cm / 100.0
			var probe: PackedFloat64Array = band.at_u(20.0 if which == 0 else band.length() - 20.0)
			var dx: float = (probe[0] - nx) if which == 0 else (nx - probe[0])
			var dz: float = (probe[1] - nz) if which == 0 else (nz - probe[1])
			var length: float = sqrt(dx * dx + dz * dz)
			ends.append({"x": nx, "z": nz, "y": _natural.height(clampf(nx, 0.0, Geo.DOMAIN_M), clampf(nz, 0.0, Geo.DOMAIN_M)), "y_free": true, "tx": dx / length, "tz": dz / length,
				"grade": 0.0, "grade_pinned": false, "bank_deg": 0.0, "port_id": "end:%d:%d" % [node_id, e], "radius_m": 0.0})
	record.port_a = ends[0].port_id
	record.port_b = ends[1].port_id
	# Pins: R5 crossings in order; those inside a junction port radius cannot
	# be reached by the interior and stay unresolved (recorded, C2 accounting).
	var pins: Array = []
	var crossings: Array = []
	var u0: float = band.project_u(ends[0].x, ends[0].z)
	var u1: float = band.project_u(ends[1].x, ends[1].z)
	for k in range(corridor.crossings.size()):
		var c: Dictionary = corridor.crossings[k]
		var crossing_id: String = "cross:%d:%d" % [e, k]
		record.crossing_ids.append(crossing_id)
		var px: float = c.x_cm / 100.0
		var pz: float = c.z_cm / 100.0
		var u: float = band.project_u(px, pz)
		var entry := {"crossing_id": crossing_id, "edge_id": e, "index": k, "channel_id": c.channel_id, "water_kind": Graph.WATER_KIND_NAMES[c.water_kind], "r5_hint": Graph.HINT_NAMES[c.hint],
			"r5_x_cm": c.x_cm, "r5_z_cm": c.z_cm, "r5_width_cm": c.width_cm, "r5_depth_cm": c.depth_cm, "r5_angle_deg": c.angle_deg, "status": "UNRESOLVED", "reasons": []}
		if u <= u0 + 4.0 or u >= u1 - 4.0:
			entry.reasons.append("ERR_R6_CROSSING_MISSING")
			entry["note"] = "R5 crossing inside a junction port radius: not reachable by the edge interior"
		else:
			pins.append({"index": k, "x": px, "z": pz, "channel_id": c.channel_id, "hint": c.hint, "water_kind": c.water_kind, "width_m": c.width_cm / 100.0, "angle_deg": float(c.angle_deg)})
		crossings.append(entry)
	var gateway: bool = nodes[edge.a].kind == Graph.NodeKind.GATEWAY or nodes[edge.b].kind == Graph.NodeKind.GATEWAY
	var request := {"edge_id": e, "route_class": route_class, "band": band, "start": ends[0], "end": ends[1], "pins": pins, "zones": zones,
		"allowed_hints": Graph.ALLOWED_HINTS[route_class], "gateway_ends": gateway, "avoid": []}
	var designed: Dictionary = _designer.design(request)
	var conflicts: Array = []
	if designed.is_valid:
		conflicts = _conflicts(designed.design, zones, route_class, accepted)
		if not conflicts.is_empty():
			# One bounded retry keeping clear of the conflicting roads.
			var avoid: Array = []
			for c: Dictionary in conflicts:
				var other: Dictionary = c.other
				for i in range(0, other.design.s.size(), 2):
					avoid.append(PackedFloat64Array([other.design.x[i], other.design.z[i], 0.5 * other.design.width[i] + Policy.half_footprint(route_class) + 2.0]))
			request.avoid = avoid
			var retry: Dictionary = _designer.design(request)
			if retry.is_valid and _conflicts(retry.design, zones, route_class, accepted).is_empty():
				designed = retry
				conflicts = []
				record.detail["conflict_retry"] = "resolved by avoidance"
			else:
				record.detail["conflict_retry"] = "unresolved"
	record.candidates = designed.get("candidates", [])
	record.detail["lattice"] = designed.get("lattice", {})
	if not designed.is_valid or not conflicts.is_empty():
		var reason: String = designed.reason_code if not designed.is_valid else "ERR_R6_UNPLANNED_INTERSECTION"
		record.reasons.append(reason)
		record.detail["failure"] = designed.get("detail", {}) if not designed.is_valid else {"conflicts": conflicts.map(func(c: Dictionary) -> Dictionary: return {"with": c.other.piece_id, "s": c.s, "x": c.x, "z": c.z})}
		for entry: Dictionary in crossings:
			if entry.reasons.is_empty():
				entry.reasons.append("ERR_R6_EDGE_UNAVAILABLE")
		return {"record": record, "crossings": crossings, "zones": zones}
	var design: Dictionary = designed.design
	var context := {"route_class": route_class, "band_request": request, "pins": pins, "crossings": designed.crossings}
	var check: Dictionary = _validator.validate_piece(design, context)
	record.metrics = designed.metrics
	record.metrics["profile"] = designed.profile
	record["certification"] = check.measured
	var features: Array = Validator.measure_features(designed.features, design)
	record.features = features
	record["intent_curvature"] = _intent_curvature(designed.fair_line, design)
	# Crossing records: matched designer crossings by pin index.
	for entry: Dictionary in crossings:
		for r: Dictionary in designed.crossings:
			if r.pin_index == entry.index:
				entry.status = "RESOLVED"
				entry["r6_x"] = r.actual_x
				entry["r6_z"] = r.actual_z
				entry["s_m"] = r.s
				entry["displacement_m"] = r.displacement_m
				entry["justification"] = r.justification
				entry["support"] = Policy.SUPPORT_NAMES[r.support]
				entry["r6_hint"] = Graph.HINT_NAMES[r.r6_hint]
				entry["refinement"] = r.refinement
				entry["depth_m"] = r.depth_m
				entry["clear_span_m"] = r.clear_span_m
				entry["wet_span_m"] = [r.wet_s0, r.wet_s1]
				entry["deck_span_m"] = [r.deck_s0, r.deck_s1]
				entry["angle_deg"] = r.angle_deg
				var design_ref: Dictionary = r.duplicate(true)
				design_ref["crossing_id"] = entry.crossing_id
				entry["design"] = design_ref
		if entry.status == "RESOLVED":
			# Independent hydrology validation: the validator's own re-derived
			# crossing on the same channel within the C2 envelope.
			var confirmed: bool = false
			for m: Dictionary in check.measured.water.matched:
				if m.pin == entry.index and m.shift_m <= Policy.CROSSING_MAX_DISPLACEMENT_M:
					confirmed = true
					entry["hydrology_validation"] = {"channel_id": m.found.channel_id, "x": m.found.x, "z": m.found.z, "shift_m": m.shift_m, "angle_deg": m.found.angle_deg}
			if not confirmed:
				entry.status = "UNRESOLVED"
				entry.reasons.append("ERR_R6_CROSSING_MISSING")
	if not check.is_valid:
		record.reasons.append_array(check.reasons)
		record.detail["failure"] = {"certification": check.measured}
		for entry: Dictionary in crossings:
			entry.status = "UNRESOLVED" if entry.status == "RESOLVED" else entry.status
			entry.erase("design")
		return {"record": record, "crossings": crossings, "zones": zones}
	var piece_id: String = "edge:%d" % e
	record.status = "READY"
	record.piece_id = piece_id
	var unresolved: bool = false
	for entry: Dictionary in crossings:
		unresolved = unresolved or entry.status != "RESOLVED"
	if unresolved:
		record.reasons.append("ERR_R6_CROSSING_MISSING")
	var zone_centres: Array = []
	for z: Dictionary in zones:
		zone_centres.append([z.x, z.z])
	return {"record": record, "crossings": crossings, "zones": zone_centres,
		"piece": {"piece_id": piece_id, "kind": "EDGE", "owner": {"edge_id": e, "route_id": edge.route_id}, "route_class": route_class, "design": design}}


## Signed curvature of the selected candidate's faired plan line (the intent
## before the quintic fit), at its stations mapped proportionally onto the
## final arc length: the "intended" overlay of the profile diagnostics.
static func _intent_curvature(fair_line: Array, design: Dictionary) -> Dictionary:
	var fx: PackedFloat64Array = fair_line[0]
	var fz: PackedFloat64Array = fair_line[1]
	var n: int = fx.size()
	var arc := PackedFloat64Array([0.0])
	for i in range(1, n):
		arc.append(arc[i - 1] + sqrt((fx[i] - fx[i - 1]) ** 2 + (fz[i] - fz[i - 1]) ** 2))
	var scale: float = design.s[design.s.size() - 1] / maxf(arc[n - 1], 1e-9)
	var s := PackedFloat64Array()
	var k := PackedFloat64Array()
	for i in range(n):
		s.append(arc[i] * scale)
		k.append(0.0 if i == 0 or i == n - 1 else RMath.three_point_curvature(fx[i - 1], fz[i - 1], fx[i], fz[i], fx[i + 1], fz[i + 1]))
	return {"s": s, "k_at_design_s": k}


## Conflicts of a new design with accepted edges outside shared junction zones.
func _conflicts(design: Dictionary, zones: Array, route_class: int, accepted: Array) -> Array:
	var centres: Array = []
	for z: Dictionary in zones:
		centres.append([z.x, z.z])
	var found: Array = []
	for other: Dictionary in accepted:
		var pair: Array = [{"piece_id": "new", "design": design, "zones": centres, "shoulder_m": Policy.CLASSES[route_class].shoulder_m}, other]
		for o: Dictionary in Validator.overlaps(pair):
			if o.a == "new" and o.b == other.piece_id:
				found.append({"other": other, "s": o.s_a, "x": o.x, "z": o.z, "kind": o.kind})
	return found


## Continuity of the synthesized network: components over usable edges and
## READY movements, per-route traversability (route-through movements), loop
## traversability and backbone continuity (C1/C5 measures).
func _network(edges: Array, nodes: Array, routes: Array, edge_records: Dictionary, junctions: Dictionary) -> Dictionary:
	var usable: Dictionary = {}
	for e in range(edges.size()):
		usable[e] = edge_records[e].status == "READY"
	var ready_moves: Dictionary = {}
	for node_id: int in junctions:
		for movement: Dictionary in junctions[node_id].movements:
			if movement.status == Policy.MOVEMENT_READY:
				ready_moves[Junctions.movement_piece_id(node_id, movement.edges[0], movement.edges[1])] = true
	var route_status: Array = []
	var backbone_ok: bool = true
	for route: Dictionary in routes:
		var ok: bool = true
		var broken: Array = []
		var list: PackedInt32Array = route.edge_ids
		for m in range(list.size()):
			if not usable[list[m]]:
				ok = false
				broken.append("edge:%d" % list[m])
			if m > 0:
				var shared: int = _shared_node(edges[list[m - 1]], edges[list[m]])
				if shared >= 0 and nodes[shared].kind == Graph.NodeKind.JUNCTION and not ready_moves.has(Junctions.movement_piece_id(shared, list[m - 1], list[m])):
					ok = false
					broken.append(Junctions.movement_piece_id(shared, list[m - 1], list[m]))
		route_status.append({"route_id": route.id, "class": Graph.CLASS_NAMES[route.class], "purpose": Graph.PURPOSE_NAMES[route.purpose], "traversable": ok, "broken": broken,
			"length_m": _route_length(route, edges)})
		if route.purpose == Graph.Purpose.BACKBONE:
			backbone_ok = ok
	var loops: Array = []
	for l in range(_graph.get_loop_count()):
		var loop: Dictionary = _graph.get_loop(l)
		var ok: bool = true
		for e: int in loop.branch_edge_ids + loop.reference_edge_ids:
			ok = ok and usable[e]
		loops.append({"loop_id": loop.id, "edges_usable": ok})
	# Components: nodes joined by usable edges whose junction ends have at
	# least one READY movement involving that edge.
	var parent: Array = range(nodes.size())
	var find := func(x: int) -> int:
		while parent[x] != x:
			x = parent[x]
		return x
	for e in range(edges.size()):
		if usable[e]:
			var a: int = find.call(edges[e].a)
			var b: int = find.call(edges[e].b)
			if a != b:
				parent[a] = b
	var components: Dictionary = {}
	for n in range(nodes.size()):
		components[find.call(n)] = true
	var usable_m: float = 0.0
	var total_m: float = 0.0
	for e in range(edges.size()):
		total_m += edges[e].length_cm / 100.0
		if usable[e]:
			usable_m += edge_records[e].metrics.get("length_m", 0.0)
	return {"routes": route_status, "backbone_continuous": backbone_ok, "loops": loops, "edge_components": components.size(), "usable_edges": usable.values().count(true),
		"edges": edges.size(), "usable_length_m": usable_m, "r5_length_m": total_m}


static func _shared_node(a: Dictionary, b: Dictionary) -> int:
	if a.a == b.a or a.a == b.b:
		return a.a
	if a.b == b.a or a.b == b.b:
		return a.b
	return -1


static func _route_length(route: Dictionary, edges: Array) -> float:
	var total: float = 0.0
	for e: int in route.edge_ids:
		total += edges[e].length_cm / 100.0
	return total
