extends SceneTree

## BC2 network checks, FAST group (headless, seconds; D3 Fast Cycle).
##   --group=domain   RealizedRoadNetwork.trail_graph (production code) on
##                    small networks: a road loop with a two-way SINGLETRACK
##                    and a one-way TECHNICAL that cross - arcs by direction,
##                    the crossing as a fork, loops the trails add, the way
##                    back from a one-way exit,
##                    the road alternative of a trail; a one-way trail into a
##                    road stub that only it reaches is a trap; with_trails
##                    is atomic (a trail naming an unknown node or a repeated
##                    id publishes nothing) and its bytes survive
##                    to_bytes / from_bytes with the same digest and graph.
## Output: NET_CHECK lines for failures, DIR/region_network_<group>.json and
## NET_SUMMARY group=.. checks=.. failures=.. completed=true.
const Network = preload("res://scripts/world/region/realized_road_network.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"label": label, "detail": str(detail)})
		print("NET_CHECK FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	var out: String = ""
	var group: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--group="):
			group = arg.substr(8)
	if out.is_empty() or group != "domain":
		push_error("NET_FAIL usage: --group=domain --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var t0: int = Time.get_ticks_usec()
	var report: Dictionary = _domain()
	report["seconds"] = (Time.get_ticks_usec() - t0) / 1e6
	report["checks"] = _checks
	report["failures"] = _failures
	var file := FileAccess.open(out.path_join("region_network_%s.json" % group), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("NET_SUMMARY group=%s checks=%d failures=%d seconds=%.2f completed=true" % [group, _checks, _failures.size(), report.seconds])
	quit(0 if _failures.is_empty() else 1)


## A straight road design from a to b, sampled every 10 m.
func _design(a: Vector2, b: Vector2) -> Dictionary:
	var d := {"s": PackedFloat64Array(), "x": PackedFloat64Array(), "y": PackedFloat64Array(), "z": PackedFloat64Array(), "tx": PackedFloat64Array(), "tz": PackedFloat64Array(),
		"width": PackedFloat64Array()}
	var steps: int = int(ceil(a.distance_to(b) / 10.0))
	var t: Vector2 = (b - a).normalized()
	for k in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(k) / steps)
		d.s.append(a.distance_to(p))
		d.x.append(p.x)
		d.z.append(p.y)
		d.y.append(0.0)
		d.tx.append(t.x)
		d.tz.append(t.y)
		d.width.append(4.0)
	return d


## Square road loop 0-1-2-3 (400 m sides) plus a 300 m stub 1-4 ending at a
## terminus.
func _roads() -> Dictionary:
	var at: Array[Vector2] = [Vector2(0, 0), Vector2(400, 0), Vector2(400, 400), Vector2(0, 400), Vector2(700, 0)]
	var data := {"schema": Network.SCHEMA, "header": {"schema": Network.SCHEMA}, "nodes": [], "edges": [], "pieces": [], "movements": [], "crossings": [],
		"metrics": {"cycles": 1}}
	for i in range(at.size()):
		data.nodes.append({"id": i, "x_m": at[i].x, "z_m": at[i].y, "kind": "TERMINUS" if i == 4 else "JUNCTION"})
	var pairs: Array = [[0, 1], [1, 2], [2, 3], [3, 0], [1, 4]]
	for e in range(pairs.size()):
		var a: int = pairs[e][0]
		var b: int = pairs[e][1]
		data.edges.append({"edge_id": e, "a": a, "b": b, "piece_id": "edge:%d" % e, "length_m": at[a].distance_to(at[b])})
		data.pieces.append({"id": "edge:%d" % e, "design": _design(at[a], at[b]), "info": {"route_class": 0}})
	return data


## A trail record as TrailRealization publishes it (only what the graph
## reads): joins on edge pieces, a straight line between them, directions,
## class; length_m is the line's length.
func _trail(id: String, class_name_value: String, nodes: Array, pieces: Array, points: Array, directions: Array) -> Dictionary:
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	var line := {"s": PackedFloat64Array(), "x": PackedFloat64Array(), "y": PackedFloat64Array(), "z": PackedFloat64Array(), "tx": PackedFloat64Array(), "tz": PackedFloat64Array()}
	var steps: int = int(ceil(a.distance_to(b) / 5.0))
	for k in range(steps + 1):
		var p: Vector2 = a.lerp(b, float(k) / steps)
		line.s.append(a.distance_to(p))
		line.x.append(p.x)
		line.z.append(p.y)
		line.y.append(0.0)
		line.tx.append((b - a).normalized().x)
		line.tz.append((b - a).normalized().y)
	return {"id": id, "class_name": class_name_value, "nodes": nodes, "length_m": a.distance_to(b), "directions": directions, "mode": "NATURAL",
		"joins": [{"piece": pieces[0], "x_m": a.x, "z_m": a.y}, {"piece": pieces[1], "x_m": b.x, "z_m": b.y}], "line": line}


func _domain() -> Dictionary:
	var report := {}
	var roads: Dictionary = _roads()
	var bare: Dictionary = Network.trail_graph(roads)
	_check(bare.strongly_connected and bare.cycles_road == 1 and bare.cycles == 1 and bare.trail_loops == 0 and bare.forks == 0, "roads alone: one loop, no forks", bare)
	# A two-way SINGLETRACK across the loop (edge 0 at 100 m -> edge 2 at 100 m
	# from node 2), a one-way TECHNICAL from edge 1 to edge 3; they cross at
	# (250, 300).
	var st: Dictionary = _trail("trail:st", "SINGLETRACK", [0, 2], ["edge:0", "edge:2"], [Vector2(100, 0), Vector2(300, 400)], ["FORWARD", "REVERSE"])
	var tech: Dictionary = _trail("trail:tech", "TECHNICAL", [1, 3], ["edge:1", "edge:3"], [Vector2(400, 300), Vector2(0, 300)], ["FORWARD"])
	var with: Dictionary = roads.duplicate(true)
	with["trails"] = [st, tech]
	var graph: Dictionary = Network.trail_graph(with)
	report["graph"] = graph
	_check(graph.strongly_connected and graph.traps.is_empty(), "no traps with both trails", graph.traps)
	_check(graph.crossings == 1 and graph.forks == 5 and graph.trail_loops == 3, "the crossing is a fork: 4 joins + 1 crossing, 3 new loops", [graph.crossings, graph.forks, graph.trail_loops])
	_check(graph.classes == {"SINGLETRACK": 1, "TECHNICAL": 1}, "classes counted", graph.classes)
	var by_id: Dictionary = {}
	for row: Dictionary in graph.trails:
		by_id[row.id] = row
	# Road alternatives: st joins at (100,0) and (300,400): 300 + 400 + 100 = 800 m
	# by road; tech (400,300) -> (0,300): 100 + 400 + 100 = 600 m.
	_check(absf(by_id["trail:st"].road_m - 800.0) < 0.5 and absf(by_id["trail:tech"].road_m - 600.0) < 0.5, "road alternative of each trail", [by_id["trail:st"].road_m, by_id["trail:tech"].road_m])
	# Way back: two-way st returns by itself; one-way tech by road (600 m) -
	# its pieces past the crossing are never ridden backwards.
	_check(absf(by_id["trail:st"].return_m - st.length_m) < 0.5 and absf(by_id["trail:tech"].return_m - 600.0) < 0.5, "way back from each exit", [by_id["trail:st"].return_m, by_id["trail:tech"].return_m])
	_check(graph.arcs == bare.arcs + 4 * 2 + 2 * 2 + 2, "arcs: 4 road splits both ways, st's 2 pieces both ways, tech's 2 pieces one way", [graph.arcs, bare.arcs])
	# Trap: a road stub reached only by a one-way trail. Remove the stub's
	# road (edge 4) and let a one-way trail end on a piece of its own.
	var trapped: Dictionary = roads.duplicate(true)
	trapped.edges = trapped.edges.slice(0, 4)
	trapped.edges.append({"edge_id": 4, "a": 4, "b": 4, "piece_id": "edge:4", "length_m": 0.0})
	trapped.pieces[4].design = _design(Vector2(700, 0), Vector2(700, 50))
	trapped["trails"] = [_trail("trail:oneway", "TECHNICAL", [1, 4], ["edge:0", "edge:4"], [Vector2(350, 0), Vector2(700, 20)], ["FORWARD"])]
	var caught: Dictionary = Network.trail_graph(trapped)
	_check(not caught.strongly_connected and not caught.traps.is_empty(), "a one-way trail into a place only it reaches is a trap", caught.traps)
	report["trap"] = caught.traps
	# with_trails: atomic and serialization identity.
	var base = Network.from_bytes(var_to_bytes(roads)).network
	var joined: Dictionary = base.with_trails([st, tech])
	_check(joined.is_valid, "with_trails publishes both trails")
	var unknown: Dictionary = base.with_trails([st, _trail("trail:x", "SINGLETRACK", [0, 99], ["edge:0", "edge:2"], [Vector2(50, 0), Vector2(50, 400)], ["FORWARD", "REVERSE"])])
	_check(not unknown.is_valid and unknown.reason_code == "ERR_TRAIL_CONNECTION" and base.get_trails().is_empty(), "a trail naming an unknown node publishes nothing", unknown.reason_code)
	var repeated: Dictionary = base.with_trails([st, st])
	_check(not repeated.is_valid and repeated.reason_code == "ERR_TRAIL_CONNECTION", "a repeated id publishes nothing")
	if joined.is_valid:
		var bytes: PackedByteArray = joined.network.to_bytes()
		var back: Dictionary = Network.from_bytes(bytes)
		_check(back.is_valid and back.network.digest() == joined.network.digest(), "bytes round trip keeps the digest")
		_check(var_to_bytes(Network.trail_graph(back.network.get_data())) == var_to_bytes(Network.trail_graph(joined.network.get_data())), "graph identical after the round trip")
		_check(joined.network.get_metrics().trails.count == 2, "network metrics count the trails", joined.network.get_metrics().trails)
	return report
