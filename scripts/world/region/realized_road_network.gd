class_name RealizedRoadNetwork
extends RefCounted

## PR1 consumable road network of one region (D4): the only network that
## FinalSurface, bake and runtime consume. Pure and immutable.
##
## Built from one RoadSynthesisPlan and its RegionRouteGraph:
##   * candidate pieces: READY edges with empty reasons and READY movements,
##     each with a valid roadbed intent;
##   * iterated to a fixed point (every exclusion is a DEGRADE record):
##       - only the largest connected component (edges joined by READY
##         movements at junctions) is kept;
##       - a descent-preferred piece needs an easier connection (non-descent-
##         preferred pieces of the component) between its two nodes;
##       - a junction whose kept edges fall into several movement groups is
##         reduced to the group holding the backbone (else the longest);
##       - a dead end is allowed only at an R5 TERMINUS or GATEWAY node.
## get_data() keeps the CertifiedRoadRoute shape (header, pieces, patches,
## crossings, edges, movements) so RoadTerrainDeformer composes it, plus
## topology, recommended directions with their easier return paths, DEGRADE
## records and network metrics N1-N7 (N7 diagnostic only).

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const Intent = preload("res://scripts/world/region/roadbed_intent.gd")
const SCHEMA := "slow_cycle.realized_road_network/1"
## N7 diagnostics: curvature below this counts as near-straight (R > 500 m).
const NEAR_STRAIGHT_K: float = 0.002

var _data: Dictionary = {}


static func sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## plan: RoadSynthesisPlan (READY or PARTIAL); graph: its RegionRouteGraph;
## spec: {seed, region, settings, round} recorded in the header. Returns
## {is_valid, network, reason_code, analysis} (analysis feeds R5 hints).
static func from_plan(plan: RefCounted, graph: RefCounted, spec: Dictionary) -> Dictionary:
	if plan == null or graph == null or plan.get_header().graph_signature != graph.signature():
		return {"is_valid": false, "network": null, "reason_code": "ERR_NETWORK_INPUT", "analysis": {}}
	var data: Dictionary = plan.get_data()
	var header: Dictionary = plan.get_header()
	var degrade: Array = []
	var edge_rec: Dictionary = {}
	for record: Dictionary in data.edges:
		edge_rec[record.edge_id] = record
	var nodes: Dictionary = {}
	for n in range(graph.get_route_node_count()):
		var node: Dictionary = graph.get_route_node(n)
		nodes[node.id] = node
	var graph_edges: Dictionary = {}
	for e in range(graph.get_edge_count()):
		graph_edges[e] = graph.get_edge(e)
	# Candidate edges.
	var ok_edges: Dictionary = {}
	for e: int in edge_rec:
		var record: Dictionary = edge_rec[e]
		var intent: Dictionary = plan.get_intent("intent:edge:%d" % e)
		if record.status != "READY":
			degrade.append({"kind": "EDGE", "id": e, "reason": "R6_" + str(record.status), "detail": record.reasons.duplicate(), "class": record.class})
		elif not record.reasons.is_empty():
			degrade.append({"kind": "EDGE", "id": e, "reason": "READY_WITH_REASONS", "detail": record.reasons.duplicate(), "class": record.class})
		elif intent.is_empty() or intent.status != "BOUNDED" or not Intent.validate(intent).is_valid:
			degrade.append({"kind": "EDGE", "id": e, "reason": "INTENT_UNSUPPORTED", "detail": [], "class": record.class})
		else:
			ok_edges[e] = true
	# Candidate movements per junction (keyed by piece id).
	var junction_rec: Dictionary = {}
	for record: Dictionary in data.junctions:
		junction_rec[record.node_id] = record
	var ok_moves: Dictionary = {}
	for node_id: int in junction_rec:
		var record: Dictionary = junction_rec[node_id]
		for m: Dictionary in record.movements:
			if m.status != Policy.MOVEMENT_READY:
				continue
			var intent: Dictionary = plan.get_intent("intent:" + m.piece_id)
			if intent.is_empty() or intent.status != "BOUNDED" or not Intent.validate(intent).is_valid:
				degrade.append({"kind": "MOVEMENT", "id": m.piece_id, "reason": "INTENT_UNSUPPORTED", "detail": []})
				continue
			ok_moves[m.piece_id] = {"node": node_id, "a": m.edges[0], "b": m.edges[1]}
	var lengths: Dictionary = {}
	for e: int in ok_edges:
		lengths[e] = plan.get_piece_info("edge:%d" % e).length_m
	var backbone_edges: Dictionary = {}
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		if route.purpose == Graph.Purpose.BACKBONE:
			for e: int in route.edge_ids:
				backbone_edges[e] = true
	var recommended: Dictionary = {}
	for e: int in ok_edges:
		recommended[e] = int(edge_rec[e].get("recommended", 0))
	# Fixed point of the exclusion rules.
	var easier: Dictionary = {}
	for iteration in range(4 * (ok_edges.size() + 1)):
		var changed: bool = false
		# Movements between kept edges only.
		for key: String in ok_moves.keys():
			var m: Dictionary = ok_moves[key]
			if not ok_edges.has(m.a) or not ok_edges.has(m.b):
				ok_moves.erase(key)
		# Junction groups: kept edges at a node joined by its kept movements.
		for node_id: int in junction_rec:
			var incident: Array = []
			for e: int in graph.edges_at(node_id):
				if ok_edges.has(e):
					incident.append(e)
			if incident.size() < 2:
				continue
			var groups: Array = _groups_at(node_id, incident, ok_moves)
			if groups.size() <= 1:
				continue
			# Keep the group with the backbone, else the longest group subtree.
			var best: int = 0
			var best_key: Array = []
			for g in range(groups.size()):
				var has_backbone: bool = false
				var total: float = 0.0
				for e: int in groups[g]:
					has_backbone = has_backbone or backbone_edges.has(e)
					total += lengths[e]
				var key: Array = [1 if has_backbone else 0, total, -groups[g][0]]
				if best_key.is_empty() or key > best_key:
					best_key = key
					best = g
			for g in range(groups.size()):
				if g == best:
					continue
				for e: int in groups[g]:
					if ok_edges.erase(e):
						degrade.append({"kind": "EDGE", "id": e, "reason": "JUNCTION_GROUP_SPLIT", "detail": [node_id], "class": edge_rec[e].class})
						changed = true
		if changed:
			continue
		# Dead ends: a junction end with no kept movement, not a terminus/gateway.
		for e: int in ok_edges.keys():
			var edge: Dictionary = graph_edges[e]
			for end_node: int in [edge.a, edge.b]:
				if nodes[end_node].kind != Graph.NodeKind.JUNCTION:
					continue
				var linked: bool = false
				for key: String in ok_moves:
					var m: Dictionary = ok_moves[key]
					linked = linked or (m.node == end_node and (m.a == e or m.b == e))
				if not linked and ok_edges.has(e):
					ok_edges.erase(e)
					degrade.append({"kind": "EDGE", "id": e, "reason": "DEAD_END_NOT_TERMINUS", "detail": [end_node], "class": edge_rec[e].class})
					changed = true
		if changed:
			continue
		# Largest component.
		var component: Dictionary = _largest_component(ok_edges, ok_moves, lengths)
		for e: int in ok_edges.keys():
			if not component.has(e):
				ok_edges.erase(e)
				degrade.append({"kind": "EDGE", "id": e, "reason": "OUTSIDE_MAIN_COMPONENT", "detail": [], "class": edge_rec[e].class})
				changed = true
		if changed:
			continue
		# Descent-preferred pieces need an easier connection between their nodes.
		easier.clear()
		for e: int in ok_edges.keys():
			if recommended[e] == 0:
				continue
			var path: Array = _easier_path(e, graph_edges, ok_edges, ok_moves, recommended, nodes)
			if path.is_empty():
				ok_edges.erase(e)
				degrade.append({"kind": "EDGE", "id": e, "reason": "DESCENT_WITHOUT_EASIER_CONNECTION", "detail": [], "class": edge_rec[e].class})
				changed = true
			else:
				easier[e] = path
		if not changed:
			break
	for key: String in ok_moves.keys():
		var m: Dictionary = ok_moves[key]
		if not ok_edges.has(m.a) or not ok_edges.has(m.b):
			ok_moves.erase(key)
	# Assemble the consumable network.
	var edge_ids: Array = ok_edges.keys()
	edge_ids.sort()
	var move_ids: Array = ok_moves.keys()
	move_ids.sort()
	var spec_out: Dictionary = spec.duplicate(true)
	var out_header := {"schema": SCHEMA, "origin_x_m": header.origin_x_m, "origin_z_m": header.origin_z_m, "region_signature": header.region_signature,
		"hydrology_signature": header.hydrology_signature, "graph_signature": header.graph_signature, "plan_signature": plan.signature(), "policy_digest": header.policy_digest,
		"rideability_signature": header.rideability_signature}
	var net := {"schema": SCHEMA, "header": out_header, "spec": spec_out, "pieces": [], "patches": [], "crossings": [], "edges": [], "movements": [], "nodes": [], "degrade": degrade}
	for e: int in edge_ids:
		var id: String = "edge:%d" % e
		var info: Dictionary = plan.get_piece_info(id)
		info["recommended"] = recommended[e]
		net.pieces.append({"id": id, "design": plan.get_design(id), "intent": plan.get_intent("intent:" + id), "info": info})
		var record: Dictionary = edge_rec[e].duplicate(true)
		var graph_edge: Dictionary = graph_edges[e]
		net.edges.append({"edge_id": e, "a": graph_edge.a, "b": graph_edge.b, "class": record.class, "route_id": record.route_id, "length_m": lengths[e], "recommended": recommended[e],
			"recommended_from": (graph_edge.a if recommended[e] > 0 else graph_edge.b) if recommended[e] != 0 else -1, "easier_path": easier.get(e, []), "piece_id": id,
			"status": record.status, "reasons": record.reasons})
	var patch_nodes: Dictionary = {}
	for key: String in move_ids:
		var m: Dictionary = ok_moves[key]
		var info: Dictionary = plan.get_piece_info(key)
		net.pieces.append({"id": key, "design": plan.get_design(key), "intent": plan.get_intent("intent:" + key), "info": info})
		patch_nodes[m.node] = true
		for movement: Dictionary in junction_rec[m.node].movements:
			if movement.piece_id == key:
				net.movements.append(movement.duplicate(true))
	var patch_ids: Array = patch_nodes.keys()
	patch_ids.sort()
	for node_id: int in patch_ids:
		net.patches.append(plan.get_intent("intent:patch:%d" % node_id))
	for id: String in plan.get_crossing_ids():
		var c: Dictionary = plan.get_crossing(id)
		if ok_edges.has(c.edge_id):
			net.crossings.append(c)
	var used_nodes: Dictionary = {}
	for e: int in edge_ids:
		used_nodes[graph_edges[e].a] = true
		used_nodes[graph_edges[e].b] = true
	var node_ids: Array = used_nodes.keys()
	node_ids.sort()
	for node_id: int in node_ids:
		var node: Dictionary = nodes[node_id]
		var incident: Array = []
		for e: int in graph.edges_at(node_id):
			if ok_edges.has(e):
				incident.append(e)
		net.nodes.append({"id": node_id, "kind": Graph.NODE_KIND_NAMES[node.kind], "x_m": node.x_cm / 100.0, "z_m": node.z_cm / 100.0, "edges": incident})
	var network := RealizedRoadNetwork.new()
	network._data = net
	net["metrics"] = network._metrics(graph, backbone_edges, junction_rec)
	return {"is_valid": true, "network": network, "reason_code": "", "analysis": {"degrade": degrade, "edge_records": data.edges, "junctions": data.junctions}}


## Movement groups of the kept edges at one junction (union-find).
static func _groups_at(node_id: int, incident: Array, moves: Dictionary) -> Array:
	var parent: Dictionary = {}
	for e: int in incident:
		parent[e] = e
	var find := func(x: int) -> int:
		while parent[x] != x:
			x = parent[x]
		return x
	for key: String in moves:
		var m: Dictionary = moves[key]
		if m.node == node_id and parent.has(m.a) and parent.has(m.b):
			var ra: int = find.call(m.a)
			var rb: int = find.call(m.b)
			if ra != rb:
				parent[maxi(ra, rb)] = mini(ra, rb)
	var groups: Dictionary = {}
	for e: int in incident:
		var r: int = find.call(e)
		if not groups.has(r):
			groups[r] = []
		groups[r].append(e)
	var out: Array = []
	var roots: Array = groups.keys()
	roots.sort()
	for r: int in roots:
		groups[r].sort()
		out.append(groups[r])
	return out


## Edges joined through kept movements; the component with the most length
## (ties: lowest edge id).
static func _largest_component(edges: Dictionary, moves: Dictionary, lengths: Dictionary) -> Dictionary:
	var parent: Dictionary = {}
	for e: int in edges:
		parent[e] = e
	var find := func(x: int) -> int:
		while parent[x] != x:
			x = parent[x]
		return x
	for key: String in moves:
		var m: Dictionary = moves[key]
		if parent.has(m.a) and parent.has(m.b):
			var ra: int = find.call(m.a)
			var rb: int = find.call(m.b)
			if ra != rb:
				parent[maxi(ra, rb)] = mini(ra, rb)
	var totals: Dictionary = {}
	for e: int in edges:
		var r: int = find.call(e)
		totals[r] = totals.get(r, 0.0) + lengths[e]
	var best: int = -1
	var roots: Array = totals.keys()
	roots.sort()
	for r: int in roots:
		if best < 0 or totals[r] > totals[best] + 1e-6:
			best = r
	var out: Dictionary = {}
	for e: int in edges:
		if find.call(e) == best:
			out[e] = true
	return out


## Shortest easier connection (fewest edges, then lowest ids) between the two
## nodes of descent-preferred edge `e` through kept bidirectional edges, moving
## between edges at junctions only through kept movements. [] when none.
static func _easier_path(e: int, edges: Dictionary, ok_edges: Dictionary, moves: Dictionary, recommended: Dictionary, nodes: Dictionary) -> Array:
	var start: int = edges[e].a
	var goal: int = edges[e].b
	# States: (edge, node at which we stand on it). Start on every bidirectional
	# edge touching `start`; finish when standing at `goal`.
	var frontier: Array = []
	var seen: Dictionary = {}
	var back: Dictionary = {}
	var starts: Array = []
	for f: int in ok_edges:
		if f != e and recommended[f] == 0 and (edges[f].a == start or edges[f].b == start):
			starts.append(f)
	starts.sort()
	for f: int in starts:
		var far: int = edges[f].b if edges[f].a == start else edges[f].a
		var state := Vector2i(f, far)
		seen[state] = true
		back[state] = Vector2i(-1, -1)
		frontier.append(state)
	while not frontier.is_empty():
		var next: Array = []
		for state: Vector2i in frontier:
			if state.y == goal:
				var path: Array = []
				var at: Vector2i = state
				while at.x >= 0:
					path.push_front(at.x)
					at = back[at]
				return path
			if nodes[state.y].kind != Graph.NodeKind.JUNCTION:
				continue
			var options: Array = []
			for key: String in moves:
				var m: Dictionary = moves[key]
				if m.node != state.y:
					continue
				var other: int = m.b if m.a == state.x else (m.a if m.b == state.x else -1)
				if other < 0 or other == e or not ok_edges.has(other) or recommended[other] != 0:
					continue
				options.append(other)
			options.sort()
			for other: int in options:
				var far2: int = edges[other].b if edges[other].a == state.y else edges[other].a
				var s2 := Vector2i(other, far2)
				if seen.has(s2):
					continue
				seen[s2] = true
				back[s2] = state
				next.append(s2)
		frontier = next
	return []


func _metrics(graph: RefCounted, backbone_edges: Dictionary, junctions: Dictionary) -> Dictionary:
	var kept: Dictionary = {}
	var total: float = 0.0
	var classes: Dictionary = {}
	for e: Dictionary in _data.edges:
		kept[e.edge_id] = e
		total += e.length_m
		classes[Graph.CLASS_NAMES[e["class"]]] = classes.get(Graph.CLASS_NAMES[e["class"]], 0) + 1
	for piece: Dictionary in _data.pieces:
		if piece.info.kind == "MOVEMENT":
			total += piece.design.s[piece.design.s.size() - 1]
	var moves: Dictionary = {}
	for m: Dictionary in _data.movements:
		moves[m.piece_id] = true
	# N1: every backbone edge kept, every backbone route-through movement kept.
	var backbone_ok: bool = not backbone_edges.is_empty()
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		if route.purpose != Graph.Purpose.BACKBONE:
			continue
		var list: PackedInt32Array = route.edge_ids
		for m in range(list.size()):
			backbone_ok = backbone_ok and kept.has(list[m])
			if m > 0:
				var e0: Dictionary = graph.get_edge(list[m - 1])
				var e1: Dictionary = graph.get_edge(list[m])
				var shared: int = e0.a if (e0.a == e1.a or e0.a == e1.b) else e0.b
				if graph.get_route_node(shared).kind == Graph.NodeKind.JUNCTION:
					backbone_ok = backbone_ok and moves.has("move:%d:%d-%d" % [shared, mini(list[m - 1], list[m]), maxi(list[m - 1], list[m])])
	# N3: independent cycles of the kept component (E - V + 1).
	var cycles: int = maxi(0, _data.edges.size() - _data.nodes.size() + (1 if not _data.edges.is_empty() else 0))
	# N5 / N6.
	var blocked: int = 0
	var dead_ends: int = 0
	for node: Dictionary in _data.nodes:
		if node.kind == "JUNCTION" and node.edges.size() >= 2:
			var groups: Array = _groups_at(node.id, node.edges, _move_table())
			blocked += 1 if groups.size() > 1 else 0
		if node.kind == "JUNCTION" and node.edges.size() == 1:
			dead_ends += 1
	var descent: int = 0
	for e: Dictionary in _data.edges:
		descent += 1 if e.recommended != 0 else 0
	return {"backbone_continuous": backbone_ok, "component_length_m": total, "edges": _data.edges.size(), "movements": _data.movements.size(), "nodes": _data.nodes.size(),
		"cycles": cycles, "classes": classes, "blocked_nodes": blocked, "dead_ends_not_terminus": dead_ends, "descent_preferred_edges": descent,
		"degraded": _data.degrade.size(), "n7": _character()}


func _move_table() -> Dictionary:
	var out: Dictionary = {}
	for m: Dictionary in _data.movements:
		out[m.piece_id] = {"node": int(m.piece_id.split(":")[1]), "a": m.edges[0], "b": m.edges[1]}
	return out


## N7 (diagnostic): near-straight share, heading change per km, sinuosity per class.
func _character() -> Dictionary:
	var out: Dictionary = {}
	for piece: Dictionary in _data.pieces:
		if piece.info.kind != "EDGE":
			continue
		var d: Dictionary = piece.design
		var name: String = Graph.CLASS_NAMES[piece.info.route_class]
		var row: Dictionary = out.get(name, {"length_m": 0.0, "straight_m": 0.0, "turn_rad": 0.0, "chord_m": 0.0})
		for i in range(1, d.s.size()):
			var ds: float = d.s[i] - d.s[i - 1]
			row.length_m += ds
			if absf(0.5 * (d.k[i] + d.k[i - 1])) < NEAR_STRAIGHT_K:
				row.straight_m += ds
			row.turn_rad += absf(0.5 * (d.k[i] + d.k[i - 1])) * ds
		row.chord_m += Vector2(d.x[d.s.size() - 1] - d.x[0], d.z[d.s.size() - 1] - d.z[0]).length()
		out[name] = row
	var summary: Dictionary = {}
	for name: String in out:
		var row: Dictionary = out[name]
		summary[name] = {"length_m": row.length_m, "near_straight_share": row.straight_m / maxf(row.length_m, 1e-9), "heading_change_deg_per_km": rad_to_deg(row.turn_rad) / maxf(row.length_m / 1000.0, 1e-9),
			"sinuosity": row.length_m / maxf(row.chord_m, 1e-9)}
	return summary


func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_metrics() -> Dictionary:
	return _data.metrics.duplicate(true)


func digest() -> String:
	var copy: Dictionary = _data.duplicate(true)
	return sha(var_to_bytes(copy))


func to_bytes() -> PackedByteArray:
	return var_to_bytes(_data)


static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	var value: Variant = bytes_to_var(bytes)
	if not value is Dictionary or value.get("schema", "") != SCHEMA:
		return {"is_valid": false, "network": null, "reason_code": "ERR_NETWORK_SCHEMA"}
	var network := RealizedRoadNetwork.new()
	network._data = value
	return {"is_valid": true, "network": network, "reason_code": ""}
