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
## BC1 (additive): with_trails() publishes realized trails (TrailRealization
## records) as complete connections between two of the network's nodes, in
## their own `trails` list - never as pieces, so the road deformer and every
## road rule above ignore them. Such a network carries SCHEMA_TRAILS; one
## without trails is byte-identical to before.

const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const Intent = preload("res://scripts/world/region/roadbed_intent.gd")
const SCHEMA := "slow_cycle.realized_road_network/1"
const SCHEMA_TRAILS := "slow_cycle.realized_road_network/2"
## This script's own path: instances are made from it, never through the
## global class_name (registered only by an editor import; a launch from a
## stale .godot class cache must still compile - PR1 launch fix).
const SELF_PATH := "res://scripts/world/region/realized_road_network.gd"
## N7 diagnostics: curvature below this counts as near-straight (R > 500 m).
const NEAR_STRAIGHT_K: float = 0.002

var _data: Dictionary = {}


static func sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## plan: RoadSynthesisPlan (READY or PARTIAL); graph: its RegionRouteGraph;
## spec: {seed, region, settings, round} recorded in the header. `excluded`
## (optional): piece id -> reason code of pieces a downstream consumer could
## not construct (FinalSurface); they leave the candidates as DEGRADE records
## "R7_<reason>" before the fixed point. Returns {is_valid, network,
## reason_code, analysis} (analysis feeds R5 hints).
static func from_plan(plan: RefCounted, graph: RefCounted, spec: Dictionary, excluded: Dictionary = {}) -> Dictionary:
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
	var excluded_ids: Array = excluded.keys()
	excluded_ids.sort()
	for id: String in excluded_ids:
		var edge_id: int = int(id.get_slice(":", 1))
		if id.begins_with("edge:") and ok_edges.erase(edge_id):
			degrade.append({"kind": "EDGE", "id": edge_id, "reason": "R7_" + str(excluded[id]), "detail": [], "class": edge_rec[edge_id].class})
		elif ok_moves.erase(id):
			degrade.append({"kind": "MOVEMENT", "id": id, "reason": "R7_" + str(excluded[id]), "detail": []})
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
	var network = _instance()
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


## A new network: this one plus `trails` (TrailRealization records, each
## joining two nodes of this network). Node records name their trails; the
## road metrics stay as they are and metrics.trails summarizes the trails.
## Returns {is_valid, network, reason_code}; ERR_TRAIL_CONNECTION when a
## trail names a node this network does not have or repeats an id.
func with_trails(trails: Array) -> Dictionary:
	var data: Dictionary = _data.duplicate(true)
	var by_node: Dictionary = {}
	var ids: Dictionary = {}
	for trail: Dictionary in data.get("trails", []) + trails:
		if ids.has(trail.id):
			return {"is_valid": false, "network": null, "reason_code": "ERR_TRAIL_CONNECTION"}
		ids[trail.id] = true
		for node_id: int in trail.nodes:
			if not by_node.has(node_id):
				by_node[node_id] = []
			by_node[node_id].append(trail.id)
	var known: Dictionary = {}
	for node: Dictionary in data.nodes:
		known[node.id] = true
		if by_node.has(node.id):
			node["trails"] = by_node[node.id]
	for node_id: int in by_node:
		if not known.has(node_id):
			return {"is_valid": false, "network": null, "reason_code": "ERR_TRAIL_CONNECTION"}
	data["trails"] = data.get("trails", []) + trails.duplicate(true)
	data["schema"] = SCHEMA_TRAILS
	data.header["schema"] = SCHEMA_TRAILS
	var summary := {"count": 0, "length_m": 0.0, "modes": {}}
	for trail: Dictionary in data.trails:
		summary.count += 1
		summary.length_m += trail.length_m
		summary.modes[trail.mode] = summary.modes.get(trail.mode, 0) + 1
	data.metrics["trails"] = summary
	var network = _instance()
	network._data = data
	return {"is_valid": true, "network": network, "reason_code": ""}


## BC2: the directed riding graph of a network's data (get_data()) with its
## trails, and what it offers (pure; not stored in the data, so a network's
## bytes do not change). Vertices: the road nodes and every trail join; each
## edge piece is split at the stations of the joins on it into road arcs
## ridden both ways (a join on a junction movement is its node). A trail is
## an arc between its two joins - split where it crosses another trail into
## pieces meeting at a crossing vertex (a fork off the road) - both ways or
## FORWARD only by its
## directions. Returns {vertices, arcs, strongly_connected, traps: [vertex
## ids not mutually reachable with the rest], cycles_road, cycles (both
## undirected cyclomatic numbers), trail_loops, forks (joins and crossings),
## crossings, trails:
## [{id, class, directions, length_m, road_m (shortest road-only way between
## its joins), return_m (shortest directed way back from its exit to its
## entry, INF when there is none)}], classes: {class: count}}.
static func trail_graph(data: Dictionary) -> Dictionary:
	var designs: Dictionary = {}
	for piece: Dictionary in data.pieces:
		designs[piece.id] = piece.design
	var vertices: Dictionary = {}
	for node: Dictionary in data.nodes:
		vertices["n%d" % node.id] = true
	# Join vertices on edge pieces, by station.
	var splits: Dictionary = {}
	var join_vertex: Dictionary = {}
	for trail: Dictionary in data.get("trails", []):
		for end in range(trail.joins.size()):
			var join: Dictionary = trail.joins[end]
			var vertex: String = ""
			var piece: String = str(join.piece)
			if piece.begins_with("edge:") and designs.has(piece):
				var station: float = _station_of(designs[piece], Vector2(join.x_m, join.z_m))
				vertex = "j:%s:%d" % [trail.id, end]
				if not splits.has(piece):
					splits[piece] = []
				splits[piece].append([station, vertex])
			else:
				vertex = "n%d" % int(trail.nodes[end])
			vertices[vertex] = true
			join_vertex["%s:%d" % [trail.id, end]] = vertex
	var arcs: Array = []
	var road_arcs: Array = []
	for edge: Dictionary in data.edges:
		var d: Dictionary = designs.get(edge.piece_id, {})
		var length: float = edge.length_m
		var a_first: bool = true
		if not d.is_empty():
			length = d.s[d.s.size() - 1]
			var start := Vector2(d.x[0], d.z[0])
			a_first = _node_distance(data, edge.a, start) <= _node_distance(data, edge.b, start)
		var chain: Array = [[0.0, "n%d" % edge.a]]
		for split: Array in splits.get(edge.piece_id, []):
			chain.append([split[0] if a_first else length - split[0], split[1]])
		chain.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
		chain.append([length, "n%d" % edge.b])
		for k in range(chain.size() - 1):
			road_arcs.append([chain[k][1], chain[k + 1][1], maxf(chain[k + 1][0] - chain[k][0], 0.0)])
	for arc: Array in road_arcs:
		arcs.append(arc)
		arcs.append([arc[1], arc[0], arc[2]])
	var both_ways: Array = arcs.duplicate()
	var road_ids: Array = vertices.keys()
	# Trail crossings: a vertex on both trails, splitting each.
	var stops: Dictionary = {}
	var list: Array = data.get("trails", [])
	var crossings: int = 0
	for i in range(list.size()):
		for j in range(i + 1, list.size()):
			for hit: Array in _line_crossings(list[i].line, list[j].line):
				var vertex: String = "x:%s:%s:%d" % [list[i].id, list[j].id, crossings]
				crossings += 1
				vertices[vertex] = true
				for side: Array in [[list[i].id, hit[0]], [list[j].id, hit[1]]]:
					if not stops.has(side[0]):
						stops[side[0]] = []
					stops[side[0]].append([side[1], vertex])
	var classes: Dictionary = {}
	var undirected: Array = road_arcs.duplicate()
	for trail: Dictionary in list:
		var chain: Array = [[0.0, join_vertex["%s:0" % trail.id]]]
		chain.append_array(stops.get(trail.id, []))
		chain.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
		chain.append([trail.length_m, join_vertex["%s:1" % trail.id]])
		for k in range(chain.size() - 1):
			var piece_m: float = maxf(chain[k + 1][0] - chain[k][0], 0.0)
			arcs.append([chain[k][1], chain[k + 1][1], piece_m])
			if "REVERSE" in trail.directions:
				arcs.append([chain[k + 1][1], chain[k][1], piece_m])
			undirected.append([chain[k][1], chain[k + 1][1], piece_m])
		var name: String = trail.get("class_name", "SINGLETRACK")
		classes[name] = classes.get(name, 0) + 1
	var trails: Array = []
	for trail: Dictionary in data.get("trails", []):
		var entry: String = join_vertex["%s:0" % trail.id]
		var exit: String = join_vertex["%s:1" % trail.id]
		trails.append({"id": trail.id, "class": trail.get("class_name", "SINGLETRACK"), "directions": trail.directions.duplicate(), "length_m": trail.length_m,
			"road_m": _shortest(both_ways, entry).get(exit, INF), "return_m": _shortest(arcs, exit).get(entry, INF)})
	var ids: Array = vertices.keys()
	ids.sort()
	var forward: Dictionary = _reach(arcs, ids[0], false)
	var backward: Dictionary = _reach(arcs, ids[0], true)
	var traps: Array = ids.filter(func(v: String) -> bool: return not forward.has(v) or not backward.has(v))
	# Road vertices: the nodes and the join splits (crossings lie off the road).
	var cycles_road: int = road_arcs.size() - road_ids.size() + _components(road_arcs, road_ids)
	var cycles: int = undirected.size() - ids.size() + _components(undirected, ids)
	return {"vertices": ids.size(), "arcs": arcs.size(), "strongly_connected": traps.is_empty(), "traps": traps, "cycles_road": cycles_road, "cycles": cycles,
		"trail_loops": cycles - cycles_road, "forks": join_vertex.size() + crossings, "crossings": crossings, "trails": trails, "classes": classes}


## Crossings of two trail lines: [[station on a, station on b]], in order
## along a (segments culled by chunk bounds).
static func _line_crossings(a: Dictionary, b: Dictionary) -> Array:
	var out: Array = []
	var chunk: int = 16
	var boxes: Array = []
	for j0 in range(0, b.s.size() - 1, chunk):
		var box := Rect2(Vector2(b.x[j0], b.z[j0]), Vector2.ZERO)
		for j in range(j0, mini(j0 + chunk, b.s.size() - 1) + 1):
			box = box.expand(Vector2(b.x[j], b.z[j]))
		boxes.append([j0, box.grow(0.01)])
	for i0 in range(0, a.s.size() - 1, chunk):
		var box_a := Rect2(Vector2(a.x[i0], a.z[i0]), Vector2.ZERO)
		for i in range(i0, mini(i0 + chunk, a.s.size() - 1) + 1):
			box_a = box_a.expand(Vector2(a.x[i], a.z[i]))
		for entry: Array in boxes:
			if not box_a.grow(0.01).intersects(entry[1]):
				continue
			for i in range(i0, mini(i0 + chunk, a.s.size() - 1)):
				var p := Vector2(a.x[i], a.z[i])
				var q := Vector2(a.x[i + 1], a.z[i + 1])
				for j in range(entry[0], mini(entry[0] + chunk, b.s.size() - 1)):
					var r := Vector2(b.x[j], b.z[j])
					var t := Vector2(b.x[j + 1], b.z[j + 1])
					var hit: Variant = Geometry2D.segment_intersects_segment(p, q, r, t)
					if hit != null:
						out.append([a.s[i] + p.distance_to(hit), b.s[j] + r.distance_to(hit)])
	out.sort_custom(func(m: Array, n: Array) -> bool: return m[0] < n[0])
	# A hit on a shared sample is found by both adjacent segments: one crossing.
	var merged: Array = []
	for hit: Array in out:
		if merged.is_empty() or absf(hit[0] - merged[-1][0]) > 1.0 or absf(hit[1] - merged[-1][1]) > 1.0:
			merged.append(hit)
	return merged


static func _station_of(d: Dictionary, p: Vector2) -> float:
	var best: float = INF
	var station: float = 0.0
	for k in range(d.s.size() - 1):
		var a := Vector2(d.x[k], d.z[k])
		var b := Vector2(d.x[k + 1], d.z[k + 1])
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		if q.distance_to(p) < best:
			best = q.distance_to(p)
			station = d.s[k] + a.distance_to(q)
	return station


static func _node_distance(data: Dictionary, id: int, p: Vector2) -> float:
	for node: Dictionary in data.nodes:
		if node.id == id:
			return Vector2(node.x_m, node.z_m).distance_to(p)
	return INF


## Vertices reachable from `source` along arcs [from, to, length]
## (`reverse`: against them).
static func _reach(arcs: Array, source: String, reverse: bool) -> Dictionary:
	var out: Dictionary = {}
	for arc: Array in arcs:
		var a: String = arc[1] if reverse else arc[0]
		if not out.has(a):
			out[a] = []
		out[a].append(arc[0] if reverse else arc[1])
	var seen: Dictionary = {source: true}
	var stack: Array = [source]
	while not stack.is_empty():
		for next: String in out.get(stack.pop_back(), []):
			if not seen.has(next):
				seen[next] = true
				stack.append(next)
	return seen


## Shortest directed distances from `source` (Dijkstra; small graphs).
static func _shortest(arcs: Array, source: String) -> Dictionary:
	var out: Dictionary = {}
	for arc: Array in arcs:
		if not out.has(arc[0]):
			out[arc[0]] = []
		out[arc[0]].append(arc)
	var best: Dictionary = {source: 0.0}
	var open: Array = [source]
	while not open.is_empty():
		var k: int = 0
		for m in range(1, open.size()):
			if best[open[m]] < best[open[k]]:
				k = m
		var vertex: String = open[k]
		open.remove_at(k)
		for arc: Array in out.get(vertex, []):
			var d: float = best[vertex] + arc[2]
			if not best.has(arc[1]) or d < best[arc[1]]:
				if not best.has(arc[1]):
					open.append(arc[1])
				best[arc[1]] = d
	return best


## Connected components of `vertices` under undirected arcs.
static func _components(arcs: Array, vertices: Array) -> int:
	var parent: Dictionary = {}
	for v: String in vertices:
		parent[v] = v
	var find := func(v: String) -> String:
		while parent[v] != v:
			v = parent[v]
		return v
	for arc: Array in arcs:
		if not parent.has(arc[0]) or not parent.has(arc[1]):
			continue
		var a: String = find.call(arc[0])
		var b: String = find.call(arc[1])
		if a != b:
			parent[a] = b
	var roots: Dictionary = {}
	for v: String in vertices:
		roots[find.call(v)] = true
	return roots.size()


func get_trails() -> Array:
	return _data.get("trails", []).duplicate(true)


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
	if not value is Dictionary or not value.get("schema", "") in [SCHEMA, SCHEMA_TRAILS]:
		return {"is_valid": false, "network": null, "reason_code": "ERR_NETWORK_SCHEMA"}
	var network = _instance()
	network._data = value
	return {"is_valid": true, "network": network, "reason_code": ""}


static func _instance() -> RefCounted:
	return load(SELF_PATH).new()
