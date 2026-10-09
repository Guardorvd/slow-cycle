extends SceneTree

## Headless R5 route-network diagnostics (not E5). Per region: a background
## from the plan-local 32 m planning raster (hillshade x dominant biome, water,
## natural barriers), a raster map with corridors / routes / junctions /
## anchors / crossings / rejected candidates, a cost map, a layered SVG with
## labels and route tooltips, route character cards (elevation + biome strip
## + crossings) and a JSON summary; a gallery index across regions.
## Holdout batches draw a light background (no raster) and keep full JSON.
## Benchmark mode measures stages separately (warm-up + three repetitions).
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Raster = preload("res://scripts/world/region/route_planning_raster.gd")
const Anchors = preload("res://scripts/world/region/route_anchor_finder.gd")
const Scoring = preload("res://scripts/world/region/route_journey_scoring.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Preview = preload("res://scripts/world/region_preview.gd")
const SIZE: int = 1025
const SCALE: float = 0.25
const CLASS_COLOURS: Array[Color] = [Color(1.0, 0.92, 0.35), Color(1.0, 0.55, 0.10), Color(0.90, 0.20, 0.75), Color(0.85, 0.05, 0.05)]
const CLASS_WIDTH: Array[float] = [6.0, 4.5, 3.5, 3.0]
const ANCHOR_LETTERS := ["G", "R", "m", "H", "P", "S", "n", "B", "U", "M", "L", "A"]
const ANCHOR_COLOURS: Array[Color] = [Color(1, 1, 1), Color(0.3, 0.6, 1.0), Color(0.3, 0.9, 0.9), Color(0.1, 0.8, 0.8), Color(1.0, 0.3, 0.3), Color(0.95, 0.5, 0.5), Color(0.7, 0.4, 0.3), Color(0.9, 0.8, 0.2), Color(0.6, 1.0, 0.4), Color(0.8, 1.0, 0.5), Color(0.2, 0.4, 0.9), Color(1.0, 0.5, 0.0)]
const HINT_COLOURS: Array[Color] = [Color(0.4, 0.9, 1.0), Color(0.2, 0.5, 1.0), Color(0.05, 0.1, 0.6)]
const SOURCES: Array[String] = ["region_route_graph", "route_planning_raster", "route_anchor_finder", "route_search", "route_journey_scoring", "route_corridor_builder", "route_planner", "hydrology_field", "region_seed_derivation"]


static func parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"is_valid": true, "reason_code": "", "seeds": [184729, 42, 77777], "region": Vector2i.ZERO, "holdout_batch": -1, "benchmark": false, "out": ""}
	var seen: Dictionary = {}
	for arg: String in args:
		var key: String = arg.split("=")[0]
		if seen.has(key):
			return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_DUPLICATE"}
		seen[key] = true
		if arg.begins_with("--seeds="):
			result.seeds = []
			for part: String in arg.substr(8).split(","):
				var parsed: Dictionary = Preview.parse_integer(part, 64)
				if not parsed.is_valid:
					return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_SEED"}
				result.seeds.append(parsed.value)
			if result.seeds.is_empty() or result.seeds.size() > 6:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_SEED"}
		elif arg.begins_with("--region="):
			var parts: PackedStringArray = arg.substr(9).split(",")
			if parts.size() != 2:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_REGION"}
			var x: Dictionary = Preview.parse_integer(parts[0], 32)
			var z: Dictionary = Preview.parse_integer(parts[1], 32)
			if not x.is_valid or not z.is_valid:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_REGION"}
			result.region = Vector2i(x.value, z.value)
		elif arg.begins_with("--holdout-batch="):
			var batch: String = arg.substr(16)
			if not batch in ["0", "1", "2", "3"]:
				return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_BATCH"}
			result.holdout_batch = batch.to_int()
		elif arg == "--benchmark":
			result.benchmark = true
		elif arg.begins_with("--out="):
			result.out = arg.substr(6).replace("\\", "/").simplify_path()
		else:
			return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_ARGUMENT"}
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if result.out.is_empty() or not result.out.is_absolute_path() or result.out.to_lower() == project or result.out.to_lower().begins_with(project + "/"):
		return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_OUTPUT"}
	if result.holdout_batch >= 0 and (seen.has("--seeds") or seen.has("--region") or result.benchmark):
		return {"is_valid": false, "reason_code": "ERR_ROUTE_CLI_ARGUMENT"}
	return result


static func holdout_rows(batch: int) -> Array:
	var regions: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, -1), Vector2i(3, -2), Vector2i(1, 2)]
	var rows: Array = []
	for k in range(batch * 8, batch * 8 + 8):
		rows.append([3000017 + 104729 * k, regions[k % 4]])
	return rows


func _init() -> void:
	var options: Dictionary = parse_options(OS.get_cmdline_user_args())
	if not options.is_valid:
		push_error("ROUTE_MAP_FAIL " + options.reason_code)
		print("ROUTE_MAP_FAIL " + options.reason_code)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(options.out)
	if options.benchmark:
		_benchmark(options)
		quit(0)
		return
	var rows: Array = holdout_rows(options.holdout_batch) if options.holdout_batch >= 0 else []
	if rows.is_empty():
		for seed_value: int in options.seeds:
			rows.append([seed_value, options.region])
	var summaries: Array = []
	var failures: int = 0
	for row: Array in rows:
		var summary: Dictionary = _region(row[0], row[1], options.out, options.holdout_batch < 0)
		failures += 0 if summary.is_valid else 1
		summaries.append(summary)
	_variation(summaries)
	var provenance: Dictionary = {}
	for name: String in SOURCES:
		provenance[name] = FileAccess.get_sha256("res://scripts/world/region/" + name + ".gd")
	var index := {"rows": summaries, "provenance": provenance, "holdout_batch": options.holdout_batch, "engine": Engine.get_version_info()}
	var file := FileAccess.open(options.out.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
	_gallery(summaries, options.out)
	print("ROUTE_MAP_SUMMARY rows=%d valid=%d failed=%d" % [summaries.size(), summaries.size() - failures, failures])
	quit(0 if failures == 0 else 1)


func _upstream(seed_value: int, region: Vector2i) -> Dictionary:
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	return {"plan": plan, "terrain": terrain, "hydrology": hydro.plan}


func _raster(up: Dictionary) -> Raster:
	var context: RefCounted = Context.create(up.plan, up.terrain, up.hydrology).context
	var biome: RefCounted = Biome.create(context).field
	var ride: RefCounted = Ride.create(context, biome).field
	var hydro_field: RefCounted = HField.create(up.hydrology, up.terrain).field
	var surface: RefCounted = Surface.create(up.terrain, hydro_field).surface
	return Raster.create(ride, surface, hydro_field, up.hydrology)


func _region(seed_value: int, region: Vector2i, out: String, full: bool) -> Dictionary:
	var name: String = "%d_%d_%d" % [seed_value, region.x, region.y]
	var directory: String = out.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	var t0: int = Time.get_ticks_usec()
	var up: Dictionary = _upstream(seed_value, region)
	var t1: int = Time.get_ticks_usec()
	var result: Dictionary = Planner.plan(up.plan, up.terrain, up.hydrology)
	var t2: int = Time.get_ticks_usec()
	var summary := {"name": name, "seed": seed_value, "region": [region.x, region.y], "is_valid": result.is_valid, "reason_code": result.reason_code, "detail": result.detail,
		"upstream_s": (t1 - t0) / 1e6, "plan_s": (t2 - t1) / 1e6, "region_signature": up.plan.signature()}
	var diagnostics: Dictionary = result.diagnostics
	summary.merge({"composition": diagnostics.get("composition", {}), "degrade_codes": diagnostics.get("degrade_codes", []), "rounds": diagnostics.get("rounds", []), "metrics": diagnostics.get("metrics", {}),
		"backbone_options": diagnostics.get("backbone_options", []), "explanations": diagnostics.get("explanations", [])})
	if not result.is_valid:
		print("ROUTE_MAP_REGION_FAIL %s %s %s" % [name, result.reason_code, result.detail])
		if not result.has("graph_data"):
			_write_json(directory.path_join("summary.json"), summary)
			return summary
	# An invalid assembled graph is still drawn (flagged) so the defect is visible.
	var graph: RefCounted = result.graph if result.is_valid else Graph.new(result.graph_data, diagnostics)
	summary.merge(_graph_stats(graph, up.plan.get_macro_terrain().get_data().frame_symmetry))
	summary["graph_signature"] = graph.signature()
	summary["diagnostics_signature"] = graph.diagnostics_signature()
	var validation: Dictionary = graph.validate()
	summary["validate"] = validation
	var t3: int = Time.get_ticks_usec()
	var raster: Raster = _raster(up) if full else null
	var base: Image = _base(raster, up.hydrology)
	base.save_png(directory.path_join("map_base.png"))
	var map: Image = base.duplicate()
	_draw_network(map, graph, diagnostics.rejected)
	map.save_png(directory.path_join("map.png"))
	if raster != null:
		var cost: Image = _cost(raster)
		_draw_routes_thin(cost, graph)
		cost.save_png(directory.path_join("cost.png"))
	_write_text(directory.path_join("map.svg"), _svg(graph, diagnostics, name))
	_write_text(directory.path_join("cards.svg"), _cards(graph))
	summary["render_s"] = (Time.get_ticks_usec() - t3) / 1e6
	_write_json(directory.path_join("summary.json"), summary)
	print("ROUTE_MAP_REGION %s valid=%s plan_s=%.1f composition=%s degrade=%s sig=%s" % [name, result.is_valid, summary.plan_s, JSON.stringify(summary.composition), JSON.stringify(summary.degrade_codes), summary.graph_signature.substr(0, 16)])
	return summary


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t"))


static func _px(x_cm: float, z_cm: float) -> Vector2:
	return Vector2(x_cm / 100.0 * SCALE, z_cm / 100.0 * SCALE)


# --- Statistics ---

func _graph_stats(graph: RefCounted, symmetry: int) -> Dictionary:
	var length_by_class := [0.0, 0.0, 0.0, 0.0]
	var crossings := {"FORD": 0, "SMALL_BRIDGE": 0, "BRIDGE": 0}
	var termini: Array = []
	var max_duplicate: float = 0.0
	var band_overlap_pairs: int = 0
	var development: int = 0
	var pinches: int = 0
	var stations: int = 0
	for e in range(graph.get_edge_count()):
		var edge: Dictionary = graph.get_edge(e)
		length_by_class[edge.class] += edge.length_cm / 100.0
		for crossing: Dictionary in edge.crossings:
			crossings[Graph.HINT_NAMES[crossing.hint]] += 1
		for share: float in graph.duplicate_shares(e).values():
			max_duplicate = maxf(max_duplicate, share)
		for k in range(edge.corridor.flags.size()):
			stations += 1
			development += 1 if edge.corridor.flags[k] & Graph.Flag.DEVELOPMENT_REQUIRED else 0
			pinches += 1 if edge.corridor.flags[k] & Graph.Flag.STEEP_PINCH else 0
	# Benign corridor band overlap (approval condition 2): recorded, not invalid.
	for e in range(graph.get_edge_count()):
		var ce: Dictionary = graph.get_corridor(e)
		for f in range(e + 1, graph.get_edge_count()):
			var cf: Dictionary = graph.get_corridor(f)
			var touching: bool = false
			for k in range(0, ce.station_count, 2):
				var p := Vector2(ce.x_m[k], ce.z_m[k])
				for m in range(0, cf.station_count, 2):
					var q := Vector2(cf.x_m[m], cf.z_m[m])
					if p.distance_to(q) < ce.half_left_m[k] + cf.half_left_m[m] and p.distance_to(q) > Graph.JUNCTION_ZONE_M:
						touching = true
						break
				if touching:
					break
			band_overlap_pairs += 1 if touching else 0
	for n in range(graph.get_route_node_count()):
		var node: Dictionary = graph.get_route_node(n)
		if node.kind == Graph.NodeKind.TERMINUS:
			termini.append(Graph.JUSTIFICATION_NAMES[node.justification])
	var routes: Array = []
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		var length: float = 0.0
		var climb: float = 0.0
		for e: int in route.edge_ids:
			length += graph.get_edge(e).length_cm / 100.0
			climb += graph.get_edge(e).climb_cm / 100.0
		var a: Dictionary = graph.get_route_node(route.start_node)
		var b: Dictionary = graph.get_route_node(route.end_node)
		var chord: float = Vector2(a.x_cm - b.x_cm, a.z_cm - b.z_cm).length() / 100.0
		routes.append({"id": r, "class": Graph.CLASS_NAMES[route.class], "purpose": Graph.PURPOSE_NAMES[route.purpose], "length_m": snappedf(length, 0.1), "climb_m": snappedf(climb, 0.1),
			"sinuosity": snappedf(length / chord, 0.01) if chord > 1.0 else -1.0, "reasons": Scoring.reason_names(route.reasons), "score": route.score_milli / 1000.0, "anchors": route.anchor_ids.size()})
	var anchors: Dictionary = {}
	for a in range(graph.get_anchor_count()):
		var anchor: Dictionary = graph.get_anchor(a)
		var key: String = Graph.ANCHOR_KIND_NAMES[anchor.kind] + ":" + Graph.ANCHOR_STATUS_NAMES[anchor.status]
		anchors[key] = anchors.get(key, 0) + 1
	# Canonical-frame occupancy (64 m cells) for seed-variation comparisons.
	var occupancy := PackedByteArray()
	occupancy.resize(64 * 64)
	for e in range(graph.get_edge_count()):
		var c: Dictionary = graph.get_edge(e).corridor
		for k in range(c.x_cm.size()):
			var frame: Vector2 = Macro.local_to_frame(symmetry, c.x_cm[k] / 100.0, c.z_cm[k] / 100.0)
			occupancy[clampi(int(frame.y / 64.0), 0, 63) * 64 + clampi(int(frame.x / 64.0), 0, 63)] = 1
	var occupied := PackedInt32Array()
	for k in range(occupancy.size()):
		if occupancy[k] == 1:
			occupied.append(k)
	var edges: int = graph.get_edge_count()
	var nodes: int = graph.get_route_node_count()
	return {"nodes": nodes, "edges": edges, "routes_count": graph.get_route_count(), "loops_count": graph.get_loop_count(), "cyclomatic": edges - nodes + 1,
		"length_by_class_m": length_by_class, "network_length_m": length_by_class[0] + length_by_class[1] + length_by_class[2] + length_by_class[3], "crossings": crossings, "termini": termini,
		"max_duplicate_share": max_duplicate, "benign_band_overlap_pairs": band_overlap_pairs, "development_station_share": float(development) / maxi(stations, 1), "steep_pinch_stations": pinches,
		"routes": routes, "anchors": anchors, "frame_occupancy": occupied}


func _variation(summaries: Array) -> void:
	for x in range(summaries.size()):
		if not summaries[x].is_valid:
			continue
		var worst: float = 0.0
		for y in range(summaries.size()):
			if x == y or not summaries[y].is_valid:
				continue
			var a: PackedInt32Array = summaries[x].frame_occupancy
			var b: PackedInt32Array = summaries[y].frame_occupancy
			var inter: int = 0
			for k: int in a:
				inter += 1 if b.has(k) else 0
			var union: int = a.size() + b.size() - inter
			worst = maxf(worst, float(inter) / maxi(union, 1))
		summaries[x]["max_frame_jaccard"] = snappedf(worst, 0.001)


# --- Images ---

static func _blend(image: Image, x: int, y: int, colour: Color, alpha: float) -> void:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return
	image.set_pixel(x, y, image.get_pixel(x, y).lerp(colour, alpha))


static func _disc(image: Image, centre: Vector2, radius: float, colour: Color, alpha: float) -> void:
	var r: int = ceili(radius)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= radius * radius:
				_blend(image, roundi(centre.x) + dx, roundi(centre.y) + dy, colour, alpha)


static func _line(image: Image, a: Vector2, b: Vector2, width: float, colour: Color, alpha: float, dash: float = 0.0) -> void:
	var length: float = a.distance_to(b)
	var steps: int = maxi(1, ceili(length / 1.0))
	var last := Vector2i(-99999, -99999)
	for s in range(steps + 1):
		var t: float = float(s) / steps
		if dash > 0.0 and fmod(t * length, 2.0 * dash) > dash:
			continue
		var p: Vector2 = a.lerp(b, t)
		if Vector2i(p.round()) == last:
			continue
		last = Vector2i(p.round())
		if width <= 1.0:
			_blend(image, last.x, last.y, colour, alpha)
		else:
			_disc(image, p, width * 0.5, colour, alpha)


static func _quad(image: Image, polygon: PackedVector2Array, colour: Color, alpha: float) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector2 in polygon:
		lo = lo.min(p)
		hi = hi.max(p)
	for y in range(maxi(0, floori(lo.y)), mini(SIZE - 1, ceili(hi.y)) + 1):
		for x in range(maxi(0, floori(lo.x)), mini(SIZE - 1, ceili(hi.x)) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
				_blend(image, x, y, colour, alpha)


func _base(raster: Raster, hydrology: RefCounted) -> Image:
	var image: Image
	if raster == null:
		image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		image.fill(Color(0.86, 0.86, 0.84))
	else:
		var small := Image.create(Raster.N, Raster.N, false, Image.FORMAT_RGB8)
		var light := Vector3(-1.0, 1.4, -1.0).normalized()
		for k in range(Raster.NODES):
			var normal := Vector3(-raster.grad_x[k], 1.0, -raster.grad_z[k]).normalized()
			var shade: float = clampf(normal.dot(light), 0.0, 1.0)
			var colour: Color = Biome.COLORS[raster.biome[k]] if raster.water[k] == 0 else Biome.COLORS[4]
			colour = colour * (0.45 + 0.65 * shade)
			if raster.blocked[k] == 1 and raster.water[k] == 0:
				colour = colour.lerp(Color(0.45, 0.05, 0.10), 0.55)
			colour.a = 1.0
			small.set_pixel(k % Raster.N, k / Raster.N, colour)
		small.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
		image = small
	for c in range(hydrology.get_channel_count()):
		var channel: Dictionary = hydrology.get_channel(c)
		for k in range(1, channel.x_cm.size()):
			_line(image, _px(channel.x_cm[k - 1], channel.z_cm[k - 1]), _px(channel.x_cm[k], channel.z_cm[k]), 3.0 if c == 0 else 1.0, Biome.COLORS[4], 0.9)
	return image


func _cost(raster: Raster) -> Image:
	var small := Image.create(Raster.N, Raster.N, false, Image.FORMAT_RGB8)
	for k in range(Raster.NODES):
		var colour: Color = Color(0.20, 0.70, 0.35).lerp(Color(0.92, 0.40, 0.15), clampf((raster.cost[k] - 1.0) / 8.0, 0.0, 1.0))
		if raster.blocked[k] == 1:
			colour = Color(0.65, 0.08, 0.18)
		if raster.water[k] == 1:
			colour = Color(0.12, 0.35, 0.80)
		small.set_pixel(k % Raster.N, k / Raster.N, colour)
	small.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return small


func _draw_routes_thin(image: Image, graph: RefCounted) -> void:
	for e in range(graph.get_edge_count()):
		var c: Dictionary = graph.get_edge(e).corridor
		for k in range(1, c.x_cm.size()):
			_line(image, _px(c.x_cm[k - 1], c.z_cm[k - 1]), _px(c.x_cm[k], c.z_cm[k]), 3.0, Color(0, 0, 0), 0.9)
			_line(image, _px(c.x_cm[k - 1], c.z_cm[k - 1]), _px(c.x_cm[k], c.z_cm[k]), 1.0, Color(1, 1, 1), 1.0)


func _draw_network(image: Image, graph: RefCounted, rejected: Array) -> void:
	for r: Dictionary in rejected:
		var line: PackedInt32Array = r.line_cm
		for k in range(2, line.size(), 2):
			_line(image, _px(line[k - 2], line[k - 1]), _px(line[k], line[k + 1]), 1.0, Color(0.15, 0.15, 0.15), 0.6, 4.0)
	for e in range(graph.get_edge_count()):
		var c: Dictionary = graph.get_corridor(e)
		var local: Dictionary = graph.get_edge(e).corridor
		var colour: Color = CLASS_COLOURS[c.class]
		for k in range(1, c.station_count):
			var a := Vector2(local.x_cm[k - 1], local.z_cm[k - 1]) / 100.0
			var b := Vector2(local.x_cm[k], local.z_cm[k]) / 100.0
			var side: Vector2 = (b - a).normalized().orthogonal()
			_quad(image, PackedVector2Array([(a + side * c.half_left_m[k - 1]) * SCALE, (b + side * c.half_left_m[k]) * SCALE, (b - side * c.half_right_m[k]) * SCALE, (a - side * c.half_right_m[k - 1]) * SCALE]), colour, 0.18)
	for e in range(graph.get_edge_count()):
		var edge: Dictionary = graph.get_edge(e)
		var c: Dictionary = edge.corridor
		for k in range(1, c.x_cm.size()):
			_line(image, _px(c.x_cm[k - 1], c.z_cm[k - 1]), _px(c.x_cm[k], c.z_cm[k]), CLASS_WIDTH[edge.class] + 2.0, Color(0, 0, 0), 0.8)
		for k in range(1, c.x_cm.size()):
			_line(image, _px(c.x_cm[k - 1], c.z_cm[k - 1]), _px(c.x_cm[k], c.z_cm[k]), CLASS_WIDTH[edge.class], CLASS_COLOURS[edge.class], 1.0)
		for crossing: Dictionary in edge.crossings:
			_disc(image, _px(crossing.x_cm, crossing.z_cm), 4.0, Color(0, 0, 0), 1.0)
			_disc(image, _px(crossing.x_cm, crossing.z_cm), 3.0, HINT_COLOURS[crossing.hint], 1.0)
	for a in range(graph.get_anchor_count()):
		var anchor: Dictionary = graph.get_anchor(a)
		if anchor.status == Graph.AnchorStatus.REJECTED:
			continue
		var p: Vector2 = _px(anchor.x_cm, anchor.z_cm)
		_disc(image, p, 4.5, Color(0, 0, 0), 1.0)
		_disc(image, p, 3.5, ANCHOR_COLOURS[anchor.kind], 1.0 if anchor.status == Graph.AnchorStatus.USED else 0.45)
	for n in range(graph.get_route_node_count()):
		var node: Dictionary = graph.get_route_node(n)
		var p: Vector2 = _px(node.x_cm, node.z_cm)
		_disc(image, p, 6.0, Color(0, 0, 0), 1.0)
		_disc(image, p, 4.5, Color(1, 1, 1) if node.kind == Graph.NodeKind.JUNCTION else (Color(0.2, 1.0, 0.2) if node.kind == Graph.NodeKind.GATEWAY else Color(1.0, 0.2, 0.2)), 1.0)


# --- SVG ---

static func _hex(colour: Color) -> String:
	return "#" + colour.to_html(false)


func _svg(graph: RefCounted, diagnostics: Dictionary, name: String) -> String:
	var s: PackedStringArray = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" font-family="sans-serif">' % [SIZE + 420, SIZE, SIZE + 420, SIZE],
		'<style>.lbl{font-size:11px;paint-order:stroke;stroke:#000;stroke-width:3px;fill:#fff}.small{font-size:9px}text{pointer-events:none}</style>',
		'<image href="map_base.png" x="0" y="0" width="%d" height="%d"/>' % [SIZE, SIZE], '<g id="rejected" opacity="0.7">']
	for r: Dictionary in diagnostics.rejected:
		var points: PackedStringArray = []
		var line: PackedInt32Array = r.line_cm
		for k in range(0, line.size(), 2):
			points.append("%.1f,%.1f" % [line[k] / 100.0 * SCALE, line[k + 1] / 100.0 * SCALE])
		s.append('<polyline points="%s" fill="none" stroke="#222" stroke-width="1.2" stroke-dasharray="4 4"><title>REJECTED %s %s %s jvs=%.2f</title></polyline>' % [" ".join(points), r.round, r.key, r.reason_code, r.jvs_milli / 1000.0])
	s.append('</g><g id="corridors" opacity="0.30">')
	for e in range(graph.get_edge_count()):
		var c: Dictionary = graph.get_corridor(e)
		var local: Dictionary = graph.get_edge(e).corridor
		var left: PackedStringArray = []
		var right: PackedStringArray = []
		for k in range(c.station_count):
			var a := Vector2(local.x_cm[maxi(k - 1, 0)], local.z_cm[maxi(k - 1, 0)]) / 100.0
			var b := Vector2(local.x_cm[mini(k + 1, c.station_count - 1)], local.z_cm[mini(k + 1, c.station_count - 1)]) / 100.0
			var p := Vector2(local.x_cm[k], local.z_cm[k]) / 100.0
			var side: Vector2 = (b - a).normalized().orthogonal()
			var l: Vector2 = (p + side * c.half_left_m[k]) * SCALE
			var rr: Vector2 = (p - side * c.half_right_m[k]) * SCALE
			left.append("%.1f,%.1f" % [l.x, l.y])
			right.insert(0, "%.1f,%.1f" % [rr.x, rr.y])
		s.append('<polygon points="%s %s" fill="%s"/>' % [" ".join(left), " ".join(right), _hex(CLASS_COLOURS[c.class])])
	s.append('</g><g id="routes">')
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		var title: String = "Route #%d %s %s score=%.2f | %s" % [r, Graph.CLASS_NAMES[route.class], Graph.PURPOSE_NAMES[route.purpose], route.score_milli / 1000.0, ", ".join(Scoring.reason_names(route.reasons))]
		for explanation: Dictionary in diagnostics.explanations:
			if explanation.route_id == r:
				title += "\n" + JSON.stringify(explanation)
		s.append('<g><title>%s</title>' % title.xml_escape())
		for e: int in route.edge_ids:
			var edge: Dictionary = graph.get_edge(e)
			var points: PackedStringArray = []
			for k in range(edge.corridor.x_cm.size()):
				points.append("%.1f,%.1f" % [edge.corridor.x_cm[k] / 100.0 * SCALE, edge.corridor.z_cm[k] / 100.0 * SCALE])
			s.append('<polyline points="%s" fill="none" stroke="#000" stroke-width="%.1f"/><polyline points="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % [" ".join(points), CLASS_WIDTH[route.class] + 2.0, " ".join(points), _hex(CLASS_COLOURS[route.class]), CLASS_WIDTH[route.class]])
		s.append('</g>')
	s.append('</g><g id="crossings">')
	for e in range(graph.get_edge_count()):
		for crossing: Dictionary in graph.get_edge(e).crossings:
			var p: Vector2 = _px(crossing.x_cm, crossing.z_cm)
			s.append('<rect x="%.1f" y="%.1f" width="7" height="7" fill="%s" stroke="#000"><title>%s %s width %.1f m depth %.2f m angle %d deg (planning hint)</title></rect>' % [p.x - 3.5, p.y - 3.5, _hex(HINT_COLOURS[crossing.hint]), Graph.HINT_NAMES[crossing.hint], Graph.WATER_KIND_NAMES[crossing.water_kind], crossing.width_cm / 100.0, crossing.depth_cm / 100.0, crossing.angle_deg])
	s.append('</g><g id="anchors">')
	for a in range(graph.get_anchor_count()):
		var anchor: Dictionary = graph.get_anchor(a)
		var p: Vector2 = _px(anchor.x_cm, anchor.z_cm)
		var status: String = Graph.ANCHOR_STATUS_NAMES[anchor.status]
		var shape: String = '<circle cx="%.1f" cy="%.1f" r="6" fill="%s" fill-opacity="%s" stroke="#000"/>' % [p.x, p.y, _hex(ANCHOR_COLOURS[anchor.kind]), "1" if status == "USED" else "0.35"]
		if status == "REJECTED":
			shape = '<path d="M%.1f %.1fl8 8m0 -8l-8 8" stroke="#000" stroke-width="2"/>' % [p.x - 4, p.y - 4]
		s.append('<g><title>Anchor #%d %s %s %s %s</title>%s<text x="%.1f" y="%.1f" class="lbl small" text-anchor="middle">%s</text></g>' % [a, Graph.ANCHOR_KIND_NAMES[anchor.kind], status, anchor.source.xml_escape(), anchor.reason_code, shape, p.x, p.y + 3, ANCHOR_LETTERS[anchor.kind]])
	s.append('</g><g id="nodes">')
	for n in range(graph.get_route_node_count()):
		var node: Dictionary = graph.get_route_node(n)
		var p: Vector2 = _px(node.x_cm, node.z_cm)
		var colour: String = "#fff" if node.kind == Graph.NodeKind.JUNCTION else ("#3f3" if node.kind == Graph.NodeKind.GATEWAY else "#f33")
		s.append('<g><title>Node #%d %s %s degree %d</title><rect x="%.1f" y="%.1f" width="10" height="10" fill="%s" stroke="#000" stroke-width="2"/></g>' % [n, Graph.NODE_KIND_NAMES[node.kind], Graph.JUSTIFICATION_NAMES[node.justification], graph.edges_at(n).size(), p.x - 5, p.y - 5, colour])
	s.append('</g><g id="labels">')
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		var longest: int = route.edge_ids[0]
		for e: int in route.edge_ids:
			if graph.get_edge(e).length_cm > graph.get_edge(longest).length_cm:
				longest = e
		var c: Dictionary = graph.get_edge(longest).corridor
		var middle: int = c.x_cm.size() / 2
		s.append('<text x="%.1f" y="%.1f" class="lbl">#%d %s</text>' % [c.x_cm[middle] / 100.0 * SCALE + 6, c.z_cm[middle] / 100.0 * SCALE - 6, r, Graph.CLASS_NAMES[route.class].substr(0, 3)])
	s.append('</g>')
	# Side panel: legend and route explanations.
	var y: float = 18.0
	s.append('<rect x="%d" y="0" width="420" height="%d" fill="#f6f6f2"/>' % [SIZE, SIZE])
	var lines: Array = ["R5 route network %s (north up, 4096 m)" % name, "Backbone yellow / Secondary orange / Singletrack magenta / Technical red",
		"Bands = corridors (R6 freedom, may overlap); dashed = rejected candidates", "Squares: white junction, green gateway, red terminus; crossings: light FORD, mid SMALL_BRIDGE, dark BRIDGE (planning hints)",
		"Anchors: G gateway R river reach m/H side-valley mouth/head P pass S shoulder n spur nose B bench U upland basin M meadow L lake A autumn; faint = unused, x = rejected",
		"Composition " + JSON.stringify(diagnostics.composition), "Degrade " + JSON.stringify(diagnostics.degrade_codes)]
	for r in range(graph.get_route_count()):
		var route: Dictionary = graph.get_route(r)
		lines.append("#%d %s %s score %.2f: %s" % [r, Graph.CLASS_NAMES[route.class], Graph.PURPOSE_NAMES[route.purpose], route.score_milli / 1000.0, ", ".join(Scoring.reason_names(route.reasons))])
	for line: String in lines:
		for chunk in range(0, line.length(), 70):
			s.append('<text x="%d" y="%.1f" font-size="11" fill="#111">%s</text>' % [SIZE + 8, y, line.substr(chunk, 70).xml_escape()])
			y += 14.0
		y += 4.0
	s.append('</svg>')
	return "\n".join(s)


## Route character cards: elevation profile, biome strip and crossings along
## each route (edges walked from the route's start node).
func _cards(graph: RefCounted) -> String:
	var width: int = 520
	var height: int = 130
	var count: int = graph.get_route_count()
	var s: PackedStringArray = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d" font-family="sans-serif" font-size="11">' % [width, height * count, width, height * count]]
	var biome_hex := []
	for colour: Color in Biome.COLORS:
		biome_hex.append(_hex(colour))
	for r in range(count):
		var route: Dictionary = graph.get_route(r)
		var at: int = route.start_node
		var distance := PackedFloat64Array()
		var elevation := PackedFloat64Array()
		var biomes := PackedByteArray()
		var crossing_at := PackedFloat64Array()
		var walked: float = 0.0
		for e: int in route.edge_ids:
			var edge: Dictionary = graph.get_edge(e)
			var c: Dictionary = edge.corridor
			var order: Array = range(c.x_cm.size())
			if edge.b == at:
				order.reverse()
			at = edge.a if edge.b == at else edge.b
			for m in range(order.size()):
				var k: int = order[m]
				if m > 0:
					var j: int = order[m - 1]
					walked += Vector2(c.x_cm[k] - c.x_cm[j], c.z_cm[k] - c.z_cm[j]).length() / 100.0
				distance.append(walked)
				elevation.append(c.elevation_cm[k] / 100.0)
				biomes.append(c.biome[k])
			for crossing: Dictionary in edge.crossings:
				crossing_at.append(distance[distance.size() - order.size() + order.find(crossing.station)])
		var lo: float = elevation[0]
		var hi: float = elevation[0]
		for h: float in elevation:
			lo = minf(lo, h)
			hi = maxf(hi, h)
		var oy: int = r * height
		s.append('<rect x="0" y="%d" width="%d" height="%d" fill="%s" stroke="#999"/>' % [oy, width, height - 4, "#fbfbf7"])
		s.append('<text x="6" y="%d" font-weight="bold">#%d %s %s %.2f km, climb %.0f m, relief %.0f m</text>' % [oy + 14, r, Graph.CLASS_NAMES[route.class], Graph.PURPOSE_NAMES[route.purpose], walked / 1000.0, _route_climb(graph, route), hi - lo])
		s.append('<text x="6" y="%d" fill="#444">%s</text>' % [oy + 28, ", ".join(Scoring.reason_names(route.reasons)).xml_escape()])
		var points: PackedStringArray = []
		for k in range(distance.size()):
			points.append("%.1f,%.1f" % [10.0 + distance[k] / maxf(walked, 1.0) * (width - 20), oy + 100.0 - (elevation[k] - lo) / maxf(hi - lo, 20.0) * 64.0])
		s.append('<polyline points="%s" fill="none" stroke="%s" stroke-width="2"/>' % [" ".join(points), _hex(CLASS_COLOURS[route.class].darkened(0.3))])
		for k in range(distance.size()):
			s.append('<rect x="%.1f" y="%d" width="%.1f" height="8" fill="%s"/>' % [10.0 + distance[k] / maxf(walked, 1.0) * (width - 20), oy + 108, maxf(1.0, 32.0 / maxf(walked, 1.0) * (width - 20)), biome_hex[biomes[k]]])
		for d: float in crossing_at:
			s.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" stroke="#1040c0" stroke-width="2"/>' % [10.0 + d / maxf(walked, 1.0) * (width - 20), 10.0 + d / maxf(walked, 1.0) * (width - 20), oy + 32, oy + 106])
	s.append('</svg>')
	return "\n".join(s)


func _route_climb(graph: RefCounted, route: Dictionary) -> float:
	var climb: float = 0.0
	for e: int in route.edge_ids:
		climb += graph.get_edge(e).climb_cm / 100.0
	return climb


func _gallery(summaries: Array, out: String) -> void:
	var s: PackedStringArray = ['<!doctype html><html><head><meta charset="utf-8"><title>R5 route maps</title><style>body{font-family:sans-serif;margin:16px;background:#fafaf7}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:4px 6px;font-size:12px;vertical-align:top}img{max-width:420px}</style></head><body><h1>R5 Region Route Planning — diagnostic maps</h1><p>Headless diagnostics (not E5). Network maps on the 32 m planning raster; SVG has labels/tooltips; cards show route character.</p><table><tr><th>Region</th><th>Map</th><th>Composition / degrade</th><th>Routes</th></tr>']
	for summary: Dictionary in summaries:
		s.append('<tr><td><b>%s</b><br>valid %s %s<br>plan %.1f s<br><a href="%s/map.svg">SVG</a> · <a href="%s/cards.svg">cards</a> · <a href="%s/cost.png">cost</a> · <a href="%s/summary.json">json</a></td>' % [summary.name, summary.is_valid, summary.reason_code, summary.plan_s, summary.name, summary.name, summary.name, summary.name])
		s.append('<td><a href="%s/map.png"><img src="%s/map.png"></a></td>' % [summary.name, summary.name])
		s.append('<td><pre>%s\n%s</pre></td><td><pre>' % [JSON.stringify(summary.get("composition", {}), " "), JSON.stringify(summary.get("degrade_codes", []))])
		for route: Dictionary in summary.get("routes", []):
			s.append(("#%d %s %s %.0f m climb %.0f sinuosity %.2f: %s\n" % [route.id, route.class, route.purpose, route.length_m, route.climb_m, route.sinuosity, ", ".join(route.reasons)]).xml_escape())
		s.append('</pre></td></tr>')
	s.append('</table></body></html>')
	_write_text(out.path_join("index.html"), "\n".join(s))


# --- Benchmark (observational E6) ---

func _benchmark(options: Dictionary) -> void:
	var records: Array = []
	for seed_value: int in options.seeds:
		var runs: Array = []
		for repetition in range(4):
			var t0: int = Time.get_ticks_usec()
			var up: Dictionary = _upstream(seed_value, options.region)
			var t1: int = Time.get_ticks_usec()
			var raster: Raster = _raster(up)
			var t2: int = Time.get_ticks_usec()
			var anchors: Array = Anchors.find(raster, up.plan.get_macro_terrain().get_data(), up.hydrology, Biome.create(Context.create(up.plan, up.terrain, up.hydrology).context).field.get_descriptor())
			var t3: int = Time.get_ticks_usec()
			var result: Dictionary = Planner.plan(up.plan, up.terrain, up.hydrology)
			var t4: int = Time.get_ticks_usec()
			runs.append({"repetition": repetition, "warmup": repetition == 0, "upstream_s": (t1 - t0) / 1e6, "raster_s": (t2 - t1) / 1e6, "anchors_s": (t3 - t2) / 1e6, "plan_total_s": (t4 - t3) / 1e6,
				"valid": result.is_valid, "signature": result.graph.signature() if result.is_valid else "", "metrics": result.diagnostics.get("metrics", {}), "raster_bytes": raster.storage_bytes(), "anchors": anchors.size()})
			print("ROUTE_BENCH seed=%d rep=%d raster=%.2fs anchors=%.2fs plan=%.2fs valid=%s" % [seed_value, repetition, runs[-1].raster_s, runs[-1].anchors_s, runs[-1].plan_total_s, result.is_valid])
		var cycles: Array = []
		for cycle in range(10):
			var up: Dictionary = _upstream(seed_value, options.region)
			var result: Dictionary = Planner.plan(up.plan, up.terrain, up.hydrology)
			result.clear()
			up.clear()
			cycles.append({"cycle": cycle, "static_memory_bytes": OS.get_static_memory_usage(), "object_count": Performance.get_monitor(Performance.OBJECT_COUNT)})
		records.append({"seed": seed_value, "region": [options.region.x, options.region.y], "runs": runs, "release_cycles": cycles})
	_write_json(options.out.path_join("benchmark.json"), {"records": records, "engine": Engine.get_version_info(), "processor": OS.get_processor_name()})
	print("ROUTE_BENCH_DONE records=%d" % records.size())
