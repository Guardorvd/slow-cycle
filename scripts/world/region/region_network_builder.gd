class_name RegionNetworkBuilder
extends RefCounted

## PR1 D4: R5 <-> R6 feedback rounds for one region, ending in the
## RealizedRoadNetwork that everything downstream consumes. Pure planning:
##   round 0   R5 plan (no hints) -> R6 synthesis -> realized network;
##   round k   failures of the previous rounds become additive R5 hints
##             (closed nodes / penalty zones per class at the diagnosed
##             points, attach closures at split junctions), R5 replans with the
##             same planning raster, R6 synthesizes again (<= MAX_REPLANS);
##   result    the round with the best network score (N1 backbone, N5 no split
##             junction, N4 class mix, N3 loops, N2 component length), with all
##             rounds' metrics, hints and DEGRADE records, plus every OK round as
##             a candidate in score order (the bake may prefer another round
##             when FinalSurface cannot construct pieces of the best one). The
##             R5 graph schema is never changed; R6 never edits the graph.
## Deterministic: fixed round order, stable hint order, no time-based choice;
## R5 and R6 never run on the main thread (RoadSynthesizer.off_main_thread).

const Planner = preload("res://scripts/world/region/route_planner.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const MAX_REPLANS: int = 2
const MODEL := "network_builder/1;replans=2;wall=close:64,penalty:6:96;crossing=penalty:8:48;other=penalty:5:96;junction=close:48;descent=penalty:3:160"
const WALL_REASONS: Array[String] = ["ERR_R6_EARTHWORK", "ERR_R6_NATURAL_BARRIER", "ERR_R6_CORRIDOR_CLEARANCE"]


## Returns {is_valid, reason_code, network, graph, plan, round, rounds,
## candidates: [{score, network, graph, plan, round}] best first (ties: earlier
## round)}.
## options.progress (optional Callable(stage: String, fraction: float in 0..1))
## is called from the building thread at every R5 / R6 step; options.cancelled
## (optional Callable() -> bool) is polled there and stops the build with
## ERR_BAKE_CANCELLED (never a network).
static func build(region_plan: RefCounted, terrain_field: RefCounted, hydrology_plan: RefCounted, options: Dictionary = {}) -> Dictionary:
	return Synth.off_main_thread(func() -> Dictionary: return _build(region_plan, terrain_field, hydrology_plan, options))


static func _build(region_plan: RefCounted, terrain_field: RefCounted, hydrology_plan: RefCounted, options: Dictionary) -> Dictionary:
	var engineered: bool = options.get("route_classes", "ALL") == "ENGINEERED"
	# Experiment variant: R5 plans every class (same layout), R6 builds only the
	# engineered ones.
	var r6_only: bool = options.get("route_classes", "ALL") == "R6_ENGINEERED"
	engineered = engineered or r6_only
	var spec := {"seed": options.get("seed", 0), "region": options.get("region", Vector2i.ZERO), "model": MODEL + ((";classes=r6_engineered" if r6_only else ";classes=engineered") if engineered else "")}
	var hints: Array = []
	var hint_keys: Dictionary = {}
	var raster: Variant = null
	var rounds: Array = []
	var best: Dictionary = {}
	var candidates: Array = []
	var max_replans: int = int(options.get("max_replans", MAX_REPLANS))
	var progress: Callable = options.get("progress", Callable())
	var cancelled: Callable = options.get("cancelled", Callable())
	for round_index in range(max_replans + 1):
		if cancelled.is_valid() and cancelled.call():
			return {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED", "network": null, "rounds": rounds}
		var t0: int = Time.get_ticks_usec()
		if progress.is_valid():
			progress.call("network: routes (round %d of up to %d)" % [round_index + 1, max_replans + 1], float(round_index) / (max_replans + 1))
		var settings: Dictionary = {"hints": hints.duplicate(true)}
		if engineered and not r6_only:
			settings["route_classes"] = "ENGINEERED"
		if raster != null:
			settings["raster"] = raster
		var routes: Dictionary = Planner.plan(region_plan, terrain_field, hydrology_plan, settings)
		var t1: int = Time.get_ticks_usec()
		if not routes.is_valid:
			rounds.append({"round": round_index, "status": "R5_FAILED", "reason_code": routes.reason_code, "hints": hints.size()})
			if round_index == 0:
				return {"is_valid": false, "reason_code": routes.reason_code, "network": null, "rounds": rounds}
			break
		raster = routes.get("raster")
		if cancelled.is_valid() and cancelled.call():
			return {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED", "network": null, "rounds": rounds}
		if progress.is_valid():
			progress.call("network: roads (round %d of up to %d)" % [round_index + 1, max_replans + 1], (round_index + 0.3) / (max_replans + 1))
		var synth: Dictionary = Synth.synthesize(region_plan, terrain_field, hydrology_plan, routes.graph, {}, int(options.get("threads", 1)),
			[Graph.RouteClass.SINGLETRACK, Graph.RouteClass.TECHNICAL] if r6_only else [])
		var t2: int = Time.get_ticks_usec()
		if synth.plan == null:
			rounds.append({"round": round_index, "status": "R6_" + str(synth.status), "reason_code": synth.reason_code, "hints": hints.size()})
			if round_index == 0:
				return {"is_valid": false, "reason_code": synth.reason_code, "network": null, "rounds": rounds}
			break
		var round_spec: Dictionary = spec.duplicate()
		round_spec["round"] = round_index
		var realized: Dictionary = Network.from_plan(synth.plan, routes.graph, round_spec)
		var t3: int = Time.get_ticks_usec()
		if not realized.is_valid:
			rounds.append({"round": round_index, "status": "NETWORK_FAILED", "reason_code": realized.reason_code, "hints": hints.size()})
			break
		var metrics: Dictionary = realized.network.get_metrics()
		var score: Array = score_of(metrics)
		var edges_ready: int = 0
		for record: Dictionary in synth.plan.get_data().edges:
			edges_ready += 1 if record.status == "READY" else 0
		rounds.append({"round": round_index, "status": "OK", "hints": hints.size(), "score": score, "metrics": metrics, "graph_signature": routes.graph.signature(),
			"plan_signature": synth.plan.signature(), "r6_status": synth.status, "edges": routes.graph.get_edge_count(), "edges_ready": edges_ready,
			"seconds": {"r5": (t1 - t0) / 1e6, "r6": (t2 - t1) / 1e6, "network": (t3 - t2) / 1e6}, "r6_timings": synth.diagnostics.get("timings_s", {}),
			"r6_edge_work": synth.diagnostics.get("edge_work", {}), "r5_work": _r5_work(routes.diagnostics), "r6_reasons": synth.plan.get_data().reason_codes})
		var candidate := {"score": score, "network": realized.network, "graph": routes.graph, "plan": synth.plan, "round": round_index}
		candidates.append(candidate)
		if best.is_empty() or score > best.score:
			best = candidate
		if (complete_engineered(metrics) if engineered else complete(metrics)) or round_index == max_replans:
			break
		var fresh: Array = hints_from(realized.analysis, routes.graph)
		var added: int = 0
		for h: Dictionary in fresh:
			var key: String = "%s|%d|%d|%d" % [h.kind, h["class"], roundi(h.x_m), roundi(h.z_m)]
			if hint_keys.has(key):
				continue
			hint_keys[key] = true
			hints.append(h)
			added += 1
		if added == 0:
			break
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score or (a.score == b.score and a.round < b.round))
	return {"is_valid": true, "reason_code": "", "network": best.network, "graph": best.graph, "plan": best.plan, "round": best.round, "rounds": rounds, "hints": hints,
		"candidates": candidates}


## R5 search work and round outcomes of one plan (diagnostics only).
static func _r5_work(diagnostics: Dictionary) -> Dictionary:
	var m: Dictionary = diagnostics.get("metrics", {})
	var rounds: Array = diagnostics.get("rounds", []).map(func(r: Dictionary) -> Dictionary: return {"round": r.round, "generated": r.generated, "accepted": r.accepted})
	return {"searches": m.get("searches", 0), "expanded": m.get("expanded", 0), "regenerations": m.get("regenerations", 0), "replans": m.get("replans", 0), "rounds": rounds,
		"composition": diagnostics.get("composition", {}), "degrade_codes": diagnostics.get("degrade_codes", [])}


## Lexicographic network score (higher is better).
static func score_of(m: Dictionary) -> Array:
	var classes: Dictionary = m.classes
	var mix: int = (1 if classes.has("SECONDARY") else 0) + (1 if classes.has("SINGLETRACK") else 0) + (1 if classes.has("TECHNICAL") else 0)
	return [1 if m.backbone_continuous else 0, 1 if m.blocked_nodes == 0 and m.dead_ends_not_terminus == 0 else 0, mix, mini(m.cycles, 2), snappedf(m.component_length_m, 1.0)]


## N1-N6 (TECHNICAL optional here; the acceptance decides per region kind).
static func complete(m: Dictionary) -> bool:
	return m.backbone_continuous and m.component_length_m >= 8000.0 and m.cycles >= 2 and m.classes.has("SECONDARY") and m.classes.has("SINGLETRACK") \
		and m.classes.has("TECHNICAL") and m.blocked_nodes == 0 and m.dead_ends_not_terminus == 0


## Experiment (post-BC2 B2): completeness of a road network whose natural
## classes come from the trail planner - N1-N6 without the SINGLETRACK /
## TECHNICAL class demands (length, loops, SECONDARY, no blocked node or
## stray dead end unchanged).
static func complete_engineered(m: Dictionary) -> bool:
	return m.backbone_continuous and m.component_length_m >= 8000.0 and m.cycles >= 2 and m.classes.has("SECONDARY") and m.blocked_nodes == 0 \
		and m.dead_ends_not_terminus == 0


## Additive R5 hints from one round's diagnosis (region-local metres).
static func hints_from(analysis: Dictionary, graph: RefCounted) -> Array:
	var out: Array = []
	for record: Dictionary in analysis.edge_records:
		if record.status == "READY" and record.reasons.is_empty():
			continue
		var point: Variant = record.get("failure_xz", [])
		if not point is Array or point.size() != 2:
			continue
		var reason: String = record.reasons[0] if not record.reasons.is_empty() else ""
		var cls: int = record["class"]
		if reason in WALL_REASONS and cls != Graph.RouteClass.BACKBONE:
			out.append({"kind": "CLOSE", "class": cls, "x_m": float(point[0]), "z_m": float(point[1]), "radius_m": 64.0, "factor": 1.0, "why": reason, "edge": record.edge_id})
		elif reason in WALL_REASONS:
			out.append({"kind": "PENALTY", "class": cls, "x_m": float(point[0]), "z_m": float(point[1]), "radius_m": 96.0, "factor": 6.0, "why": reason, "edge": record.edge_id})
		elif reason.begins_with("ERR_R6_CROSSING") or reason.begins_with("ERR_R6_WATER"):
			out.append({"kind": "PENALTY", "class": cls, "x_m": float(point[0]), "z_m": float(point[1]), "radius_m": 48.0, "factor": 8.0, "why": reason, "edge": record.edge_id})
		else:
			out.append({"kind": "PENALTY", "class": cls, "x_m": float(point[0]), "z_m": float(point[1]), "radius_m": 96.0, "factor": 5.0, "why": reason, "edge": record.edge_id})
	# Junctions whose essential movements failed or whose groups split: the
	# attaching (harder) classes may not attach there again.
	var split: Dictionary = {}
	for d: Dictionary in analysis.degrade:
		if d.reason == "JUNCTION_GROUP_SPLIT":
			split[int(d.detail[0])] = true
	for record: Dictionary in analysis.junctions:
		var essential_failed: bool = false
		for m: Dictionary in record.movements:
			essential_failed = essential_failed or (m.essential and m.status != "READY")
		if not essential_failed and not split.has(record.node_id) and record.status != "BLOCKED":
			continue
		var node: Dictionary = graph.get_route_node(record.node_id)
		var lowest: int = 9
		var classes: Dictionary = {}
		for e: int in graph.edges_at(record.node_id):
			var c: int = graph.get_edge(e)["class"]
			lowest = mini(lowest, c)
			classes[c] = true
		var keys: Array = classes.keys()
		keys.sort()
		for c: int in keys:
			if c > lowest:
				out.append({"kind": "CLOSE", "class": c, "x_m": node.x_cm / 100.0, "z_m": node.z_cm / 100.0, "radius_m": 48.0, "factor": 1.0, "why": "JUNCTION", "node": record.node_id})
	for d: Dictionary in analysis.degrade:
		if d.reason != "DESCENT_WITHOUT_EASIER_CONNECTION":
			continue
		var edge: Dictionary = graph.get_edge(d.id)
		var c: Dictionary = edge.corridor
		var mid: int = c.x_cm.size() / 2
		out.append({"kind": "PENALTY", "class": edge["class"], "x_m": c.x_cm[mid] / 100.0, "z_m": c.z_cm[mid] / 100.0, "radius_m": 160.0, "factor": 3.0, "why": d.reason, "edge": d.id})
	return out
