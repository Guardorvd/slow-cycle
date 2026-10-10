extends SceneTree

## Headless R6 road synthesis diagnostics (not E5; ExecPlan §§12, 14).
## Per region: real R1-R5 upstream, R6 synthesis, then
##   map.png        whole region: natural hillshade + contours, water, steep
##                  ground, faint R5 bands / reference lines, final R6 ribbons
##                  by class, connectors, ports / patches, crossings (deck /
##                  ford), feature intervals, failed edges (R5 line in red);
##   map.svg        the same as vectors in metres with labels;
##   edge_<id>.png  close-up of each edge (ribbon at true width, tie-ins);
##   profile_<id>.png / .svg  shared-arc panels: elevation (natural vs road,
##                  supports), grade with class limits, signed curvature (final
##                  vs selected-candidate intent) with feature intervals,
##                  cut / fill per side, bank;
##   summary.json   outcomes, failure inventory, character statistics (curvature
##                  and grade distributions, straight / calm fractions, turn
##                  runs, design-speed time windows), feature realisation,
##                  timings, provenance; R6_MAP_SUMMARY marker.
## Modes: --cases=s,x,z;s,x,z  --holdout (fresh seeds 9000011 + 104729 i)
##        --repeat (determinism: synthesize twice, compare signatures)
##        --benchmark (warm-up + 3 repeats per case; 10 construct / release
##        cycles of the first case) --no-closeups.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const Preview = preload("res://scripts/world/region_preview.gd")
const SOURCES: Array[String] = ["road_synthesis_policy", "road_synthesis_plan", "road_synthesizer", "road_corridor_geometry", "road_alignment_designer", "regional_road_math",
	"road_junction_planner", "road_feasibility_validator", "roadbed_intent", "region_seed_derivation", "region_route_graph", "route_planner", "hydrology_field"]
const CLASS_COLOURS: Array[Color] = [Color(1.0, 0.85, 0.15), Color(1.0, 0.5, 0.05), Color(0.85, 0.15, 0.8), Color(0.85, 0.05, 0.05)]
const FEATURE_COLOURS := {"SWEEP": Color(0.1, 0.75, 0.25), "LINKED_TURNS": Color(1.0, 0.45, 0.0), "SWITCHBACK": Color(0.6, 0.1, 0.9), "CALM": Color(0.4, 0.75, 1.0),
	"CLIMB": Color(0.55, 0.35, 0.2), "DESCENT": Color(0.3, 0.3, 0.3), "CREST": Color(0.9, 0.9, 0.2), "COMPRESSION": Color(0.2, 0.9, 0.9)}
const HOLDOUT_REGIONS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, -2), Vector2i(-1, -1), Vector2i(2, 1)]


static func parse_options(args: PackedStringArray) -> Dictionary:
	var result := {"is_valid": true, "reason_code": "", "cases": [], "holdout": false, "repeat": false, "benchmark": false, "closeups": true, "out": ""}
	var seen: Dictionary = {}
	for arg: String in args:
		var key: String = arg.split("=")[0]
		if seen.has(key):
			return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
		seen[key] = true
		if arg.begins_with("--cases=") or arg.begins_with("--case="):
			for item: String in arg.split("=", true, 1)[1].split(";"):
				var parts: PackedStringArray = item.split(",")
				if parts.size() != 3:
					return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
				var s: Dictionary = Preview.parse_integer(parts[0], 64)
				var x: Dictionary = Preview.parse_integer(parts[1], 32)
				var z: Dictionary = Preview.parse_integer(parts[2], 32)
				if not s.is_valid or not x.is_valid or not z.is_valid:
					return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
				result.cases.append([s.value, Vector2i(x.value, z.value)])
		elif arg == "--holdout":
			result.holdout = true
		elif arg == "--repeat":
			result.repeat = true
		elif arg == "--benchmark":
			result.benchmark = true
		elif arg == "--no-closeups":
			result.closeups = false
		elif arg.begins_with("--out="):
			result.out = arg.substr(6).replace("\\", "/").simplify_path()
		else:
			return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/").to_lower()
	if result.out.is_empty() or not result.out.is_absolute_path() or result.out.to_lower() == project or result.out.to_lower().begins_with(project + "/"):
		return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
	if result.holdout:
		if not result.cases.is_empty():
			return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
		for i in range(8):
			result.cases.append([9000011 + 104729 * i, HOLDOUT_REGIONS[i % 4]])
	if result.cases.is_empty():
		return {"is_valid": false, "reason_code": "ERR_R6_CLI_ARGUMENT"}
	return result


func _init() -> void:
	var options: Dictionary = parse_options(OS.get_cmdline_user_args())
	if not options.is_valid:
		push_error("R6_MAP_FAIL " + options.reason_code)
		print("R6_MAP_FAIL " + options.reason_code)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(options.out)
	if options.benchmark:
		_benchmark(options)
		quit(0)
		return
	var rows: Array = []
	var failures: int = 0
	for case: Array in options.cases:
		var row: Dictionary = _case(case[0], case[1], options)
		failures += 0 if row.completed else 1
		rows.append(row)
	var provenance: Dictionary = {}
	for name: String in SOURCES:
		provenance[name] = FileAccess.get_sha256("res://scripts/world/region/" + name + ".gd")
	provenance["capture_road_synthesis_map"] = FileAccess.get_sha256("res://scripts/test/capture_road_synthesis_map.gd")
	var index := {"rows": rows, "provenance": provenance, "engine": Engine.get_version_info(), "options": {"holdout": options.holdout, "repeat": options.repeat}}
	_write_json(options.out.path_join("summary.json"), index)
	var statuses: Dictionary = {}
	for row: Dictionary in rows:
		statuses[row.get("status", "NONE")] = statuses.get(row.get("status", "NONE"), 0) + 1
	print("R6_MAP_SUMMARY cases=%d completed=%d failed=%d statuses=%s" % [rows.size(), rows.size() - failures, failures, JSON.stringify(statuses)])
	quit(0 if failures == 0 else 1)


func _upstream(seed_value: int, region: Vector2i) -> Dictionary:
	var t0: int = Time.get_ticks_usec()
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	var t1: int = Time.get_ticks_usec()
	var routes: Dictionary = Planner.plan(plan, terrain, hydro.plan)
	var t2: int = Time.get_ticks_usec()
	return {"plan": plan, "terrain": terrain, "hydrology": hydro.plan, "routes": routes, "upstream_s": (t1 - t0) / 1e6, "r5_s": (t2 - t1) / 1e6}


func _case(seed_value: int, region: Vector2i, options: Dictionary) -> Dictionary:
	var name: String = "%d_%d_%d" % [seed_value, region.x, region.y]
	var directory: String = options.out.path_join(name)
	DirAccess.make_dir_recursive_absolute(directory)
	var up: Dictionary = _upstream(seed_value, region)
	var row := {"name": name, "seed": seed_value, "region": [region.x, region.y], "completed": false, "upstream_s": up.upstream_s, "r5_s": up.r5_s}
	if not up.routes.is_valid:
		row["status"] = "R5_INVALID"
		row["r5_reason"] = up.routes.reason_code
		row.completed = true
		_write_json(directory.path_join("summary.json"), row)
		print("R6_MAP_REGION %s R5 invalid: %s" % [name, up.routes.reason_code])
		return row
	var graph: RefCounted = up.routes.graph
	row["graph_signature"] = graph.signature()
	var t0: int = Time.get_ticks_usec()
	var result: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, graph)
	row["r6_s"] = (Time.get_ticks_usec() - t0) / 1e6
	row["status"] = result.status
	row["reason_code"] = result.reason_code
	row["diagnostics"] = result.diagnostics
	if result.plan == null:
		row.completed = true
		_write_json(directory.path_join("summary.json"), row)
		print("R6_MAP_REGION %s status=%s reason=%s (no plan)" % [name, result.status, result.reason_code])
		return row
	var plan: RefCounted = result.plan
	row["plan_signature"] = plan.signature()
	if options.repeat:
		var again: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, Graph.new(graph.get_data(), graph.get_diagnostics()))
		row["repeat_signature"] = again.plan.signature() if again.plan != null else ""
		row["repeat_identical"] = row.repeat_signature == row.plan_signature
	var data: Dictionary = plan.get_data()
	row["outcomes"] = _outcomes(data)
	row["failures"] = _failure_inventory(data)
	row["character"] = _character(plan, data)
	row["network"] = data.network
	var t1: int = Time.get_ticks_usec()
	var hydro_field: RefCounted = HField.create(up.hydrology, up.terrain).field
	var surface: RefCounted = Surface.create(up.terrain, hydro_field).surface
	var base: Dictionary = _base(surface, up.hydrology)
	var map: Image = base.image.duplicate()
	_draw_network(map, 2.0, Vector2.ZERO, plan, data, graph, 1.0)
	map.save_png(directory.path_join("map.png"))
	base.image.save_png(directory.path_join("map_base.png"))
	_write_text(directory.path_join("map.svg"), _svg(plan, data, graph, name))
	for record: Dictionary in data.edges:
		if not record.piece_id.is_empty():
			var design: Dictionary = plan.get_design(record.piece_id)
			_profile_png(design, record, Policy.CLASSES[record.class]).save_png(directory.path_join("profile_%d.png" % record.edge_id))
			_write_text(directory.path_join("profile_%d.svg" % record.edge_id), _profile_svg(design, record, name))
		if options.closeups:
			_closeup(surface, plan, data, graph, record).save_png(directory.path_join("edge_%d.png" % record.edge_id))
	row["render_s"] = (Time.get_ticks_usec() - t1) / 1e6
	row.completed = true
	_write_json(directory.path_join("summary.json"), row)
	print("R6_MAP_REGION %s status=%s edges_ready=%d/%d junctions=%s r6_s=%.1f sig=%s" % [name, result.status, row.outcomes.edges_ready, row.outcomes.edges,
		JSON.stringify(row.outcomes.junctions), row.r6_s, row.plan_signature.substr(0, 16)])
	return row


# --- Outcomes, failures, character ---

static func _outcomes(data: Dictionary) -> Dictionary:
	var out := {"edges": data.edges.size(), "edges_ready": 0, "by_class": {}, "junctions": {}, "movements": {"READY": 0, "UNAVAILABLE": 0}, "essential_unavailable": 0,
		"crossings": {}, "reasons": {}, "length_ready_m": 0.0, "length_r5_m": 0.0}
	for record: Dictionary in data.edges:
		var cls: String = record.class_name
		if not out.by_class.has(cls):
			out.by_class[cls] = {"edges": 0, "ready": 0, "ready_length_m": 0.0}
		out.by_class[cls].edges += 1
		if record.status == "READY":
			out.edges_ready += 1
			out.by_class[cls].ready += 1
			out.by_class[cls].ready_length_m += record.metrics.length_m
			out.length_ready_m += record.metrics.length_m
		for r: String in record.reasons:
			out.reasons[r] = out.reasons.get(r, 0) + 1
	for j: Dictionary in data.junctions:
		out.junctions[j.status] = out.junctions.get(j.status, 0) + 1
		for m: Dictionary in j.movements:
			out.movements[m.status] = out.movements.get(m.status, 0) + 1
			if m.status != Policy.MOVEMENT_READY and m.essential:
				out.essential_unavailable += 1
	for c: Dictionary in data.crossings:
		var key: String = c.status + ":" + c.get("support", "-")
		out.crossings[key] = out.crossings.get(key, 0) + 1
	out.length_r5_m = data.network.r5_length_m
	return out


static func _failure_inventory(data: Dictionary) -> Array:
	var items: Array = []
	for record: Dictionary in data.edges:
		if record.status != "READY":
			items.append({"kind": "EDGE", "id": record.edge_id, "class": record.class_name, "reasons": record.reasons, "detail": _short(record.detail.get("failure", {}))})
		elif not record.reasons.is_empty():
			items.append({"kind": "EDGE_LIMITATION", "id": record.edge_id, "class": record.class_name, "reasons": record.reasons})
	for j: Dictionary in data.junctions:
		for m: Dictionary in j.movements:
			if m.status != Policy.MOVEMENT_READY:
				items.append({"kind": "MOVEMENT", "id": m.piece_id, "essential": m.essential_kind, "reasons": m.reasons, "turn_deg": m.get("turn_deg", 0.0), "detail": m.get("detail", {})})
		if j.status == Policy.JUNCTION_BLOCKED:
			items.append({"kind": "JUNCTION", "id": j.node_id, "reasons": j.reasons, "note": j.get("note", "")})
	for c: Dictionary in data.crossings:
		if c.status != "RESOLVED":
			items.append({"kind": "CROSSING", "id": c.crossing_id, "reasons": c.reasons, "note": c.get("note", "")})
	for o: Dictionary in data.overlaps:
		items.append({"kind": "OVERLAP", "id": "%s/%s" % [o.a, o.b], "reasons": [o.kind]})
	return items


static func _short(value: Variant) -> Variant:
	var text: String = JSON.stringify(value)
	return JSON.parse_string(text) if text.length() <= 6000 else text.substr(0, 6000)


## Measured riding character of every READY edge interior, by class: length-
## weighted curvature histogram, straight (|k| < 1/1000) and calm fractions,
## signed turn lobes, total vs net turning per km, grade histogram, vertical
## curvature, design-speed time windows, feature realisation counts.
static func _character(plan: RefCounted, data: Dictionary) -> Dictionary:
	var by_class: Dictionary = {}
	var radius_bins: Array[float] = [19.0, 35.0, 60.0, 100.0, 200.0, 400.0, 1000.0, INF]
	var grade_bins: Array[float] = [0.02, 0.04, 0.06, 0.09, 0.12, 0.15, 0.18, INF]
	for record: Dictionary in data.edges:
		if record.status != "READY":
			continue
		var cls: String = record.class_name
		if not by_class.has(cls):
			var radius_hist := PackedFloat64Array()
			radius_hist.resize(radius_bins.size())
			var grade_hist := PackedFloat64Array()
			grade_hist.resize(grade_bins.size())
			by_class[cls] = {"length_m": 0.0, "radius_hist_m": radius_hist, "grade_hist_m": grade_hist, "straight_m": 0.0, "total_turn_deg": 0.0, "net_turn_deg": 0.0, "lobes": 0,
				"lobe_turns_deg": [], "lobe_lengths_m": [], "longest_straight_m": 0.0, "max_vertical_curvature": 0.0, "climb_m": 0.0, "descent_m": 0.0,
				"features": {}, "windows": {"short_turning": 0, "short_total": 0, "medium_turning": 0, "medium_total": 0}}
		var c: Dictionary = by_class[cls]
		var d: Dictionary = plan.get_design(record.piece_id)
		var n: int = d.s.size()
		var straight_run: float = 0.0
		var heading_sum: float = 0.0
		for i in range(1, n):
			var ds: float = d.s[i] - d.s[i - 1]
			var k: float = 0.5 * (absf(d.k[i]) + absf(d.k[i - 1]))
			var r: float = 1.0 / maxf(k, 1e-9)
			for b in range(radius_bins.size()):
				if r < radius_bins[b]:
					c.radius_hist_m[b] += ds
					break
			var g: float = absf(0.5 * (d.grade[i] + d.grade[i - 1]))
			for b in range(grade_bins.size()):
				if g < grade_bins[b]:
					c.grade_hist_m[b] += ds
					break
			if k < 1.0 / 1000.0:
				c.straight_m += ds
				straight_run += ds
				c.longest_straight_m = maxf(c.longest_straight_m, straight_run)
			else:
				straight_run = 0.0
			var turn: float = RMath.wrap_angle(atan2(d.tz[i], d.tx[i]) - atan2(d.tz[i - 1], d.tx[i - 1]))
			c.total_turn_deg += absf(rad_to_deg(turn))
			heading_sum += turn
			c.max_vertical_curvature = maxf(c.max_vertical_curvature, absf(d.vk[i]))
			var dy: float = d.y[i] - d.y[i - 1]
			c.climb_m += maxf(dy, 0.0)
			c.descent_m += maxf(-dy, 0.0)
		c.net_turn_deg += absf(rad_to_deg(heading_sum))
		c.length_m += d.s[n - 1]
		for lobe: Dictionary in RMath.turn_lobes(d.s, d.k, 1.0 / 600.0, 8.0):
			c.lobes += 1
			c.lobe_turns_deg.append(snappedf(rad_to_deg(lobe.turn), 0.1))
			c.lobe_lengths_m.append(snappedf(lobe.s1 - lobe.s0, 0.1))
		# Time windows at design speed: 3-10 s (short) and 20-60 s (medium).
		var v: float = Policy.CLASSES[record.class].design_speed_kmh / 3.6
		for spec: Array in [["short", 6.0 * v, 15.0], ["medium", 40.0 * v, 30.0]]:
			var span: float = spec[1]
			var start: float = 0.0
			while start + span <= d.s[n - 1]:
				var a: int = d.s.bsearch(start)
				var b: int = mini(d.s.bsearch(start + span), n - 1)
				var turn_window: float = 0.0
				for i in range(maxi(a, 1), b + 1):
					turn_window += absf(rad_to_deg(RMath.wrap_angle(atan2(d.tz[i], d.tx[i]) - atan2(d.tz[i - 1], d.tx[i - 1]))))
				c.windows[spec[0] + "_total"] += 1
				if turn_window >= spec[2]:
					c.windows[spec[0] + "_turning"] += 1
				start += span * 0.5
		for f: Dictionary in record.features:
			var key: String = f.kind
			if not c.features.has(key):
				c.features[key] = {"requested": 0, "realized": 0, "length_m": 0.0}
			c.features[key].requested += 1
			if f.status == Policy.REALIZED:
				c.features[key].realized += 1
				c.features[key].length_m += f.s1 - f.s0
	for cls: String in by_class:
		var c: Dictionary = by_class[cls]
		var km: float = maxf(c.length_m / 1000.0, 1e-9)
		c["straight_fraction"] = c.straight_m / maxf(c.length_m, 1e-9)
		c["turn_deg_per_km"] = c.total_turn_deg / km
		c["net_turn_deg_per_km"] = c.net_turn_deg / km
		c["radius_bins_m"] = ["<19", "19-35", "35-60", "60-100", "100-200", "200-400", "400-1000", ">=1000"]
		c["grade_bins"] = ["<2%", "2-4%", "4-6%", "6-9%", "9-12%", "12-15%", "15-18%", ">=18%"]
	return by_class


# --- Background ---

func _base(surface: RefCounted, hydrology: RefCounted) -> Dictionary:
	var bounds: Dictionary = surface.get_bounds_m()
	var lattice: Dictionary = surface.sample_lattice(bounds.min_x / 16, bounds.min_z / 16, 257, 257)
	var heights: PackedFloat64Array = lattice.heights_m
	var lo: float = INF
	var hi: float = -INF
	for h: float in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	var size: int = 2048
	var image := Image.create(size, size, false, Image.FORMAT_RGB8)
	var field := PackedFloat64Array()
	field.resize(size * size)
	for j in range(size):
		for i in range(size):
			var gx: float = i * 2.0 / 16.0
			var gz: float = j * 2.0 / 16.0
			var i0: int = mini(floori(gx), 255)
			var j0: int = mini(floori(gz), 255)
			var fx: float = gx - i0
			var fz: float = gz - j0
			field[j * size + i] = (heights[j0 * 257 + i0] * (1.0 - fx) + heights[j0 * 257 + i0 + 1] * fx) * (1.0 - fz) + (heights[(j0 + 1) * 257 + i0] * (1.0 - fx) + heights[(j0 + 1) * 257 + i0 + 1] * fx) * fz
	for j in range(size):
		for i in range(size):
			var h: float = field[j * size + i]
			var hx: float = field[j * size + mini(i + 1, size - 1)] - field[j * size + maxi(i - 1, 0)]
			var hz: float = field[mini(j + 1, size - 1) * size + i] - field[maxi(j - 1, 0) * size + i]
			var shade: float = clampf(0.78 - (hx + hz) / 4.0 * 0.45, 0.5, 1.08)
			var t: float = (h - lo) / maxf(hi - lo, 1.0)
			var colour: Color = Color(0.50, 0.58, 0.44).lerp(Color(0.80, 0.77, 0.68), smoothstep(0.0, 0.7, t)).lerp(Color(0.95, 0.95, 0.94), smoothstep(0.7, 1.0, t)) * shade
			var slope: float = sqrt(hx * hx + hz * hz) / 4.0
			if slope >= 1.0:
				colour = colour.lerp(Color(0.55, 0.25, 0.25), 0.55)
			var h1: float = field[j * size + mini(i + 1, size - 1)]
			var h2: float = field[mini(j + 1, size - 1) * size + i]
			if floorf(h / 50.0) != floorf(h1 / 50.0) or floorf(h / 50.0) != floorf(h2 / 50.0):
				colour = colour * 0.6
			elif floorf(h / 10.0) != floorf(h1 / 10.0) or floorf(h / 10.0) != floorf(h2 / 10.0):
				colour = colour * 0.85
			colour.a = 1.0
			image.set_pixel(i, j, colour)
	var painter := Painter.new(image, 2.0, Vector2.ZERO)
	for c in range(hydrology.get_channel_count()):
		var channel: Dictionary = hydrology.get_channel(c)
		for k in range(channel.x_cm.size() - 1):
			painter.line(Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0, Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / 100.0, Color(0.15, 0.35, 0.85), maxf(1.0, channel.width_cm[k] / 100.0 / 2.0), 1.0)
	for b in range(hydrology.get_body_count()):
		var body: Dictionary = hydrology.get_body(b)
		for cell: int in body.cells:
			painter.rect(Vector2((cell % 129) * 32.0 - 16.0, (cell / 129) * 32.0 - 16.0), Vector2(32.0, 32.0), Color(0.25, 0.55, 0.75), 0.6)
	return {"image": image, "low_m": lo, "high_m": hi}


# --- Network drawing (shared by the map and close-ups) ---

func _draw_network(image: Image, m_per_px: float, origin: Vector2, plan: RefCounted, data: Dictionary, graph: RefCounted, emphasis: float) -> void:
	var painter := Painter.new(image, m_per_px, origin)
	# R5 bands and reference lines (faint), failed edges in red.
	for e in range(graph.get_edge_count()):
		var corridor: Dictionary = graph.get_corridor(e)
		var ox: float = graph.get_origin_x_m()
		var oz: float = graph.get_origin_z_m()
		var failed: bool = data.edges[e].status != "READY"
		for k in range(corridor.station_count - 1):
			var a := Vector2(corridor.x_m[k] - ox, corridor.z_m[k] - oz)
			var b := Vector2(corridor.x_m[k + 1] - ox, corridor.z_m[k + 1] - oz)
			var dir: Vector2 = (b - a).normalized()
			var nrm := Vector2(-dir.y, dir.x)
			painter.line(a + nrm * corridor.half_left_m[k], b + nrm * corridor.half_left_m[k + 1], Color(1, 1, 1), 0.5 * m_per_px, 0.25)
			painter.line(a - nrm * corridor.half_right_m[k], b - nrm * corridor.half_right_m[k + 1], Color(1, 1, 1), 0.5 * m_per_px, 0.25)
			if failed:
				painter.line(a, b, Color(0.9, 0.05, 0.05), 2.0 * m_per_px, 0.9)
			else:
				painter.line(a, b, Color(1, 1, 1), 0.5 * m_per_px, 0.35)
	# R6 pieces.
	for piece_id: String in plan.get_piece_ids():
		var info: Dictionary = plan.get_piece_info(piece_id)
		var d: Dictionary = plan.get_design(piece_id)
		var connector: bool = info.kind == "MOVEMENT"
		var colour: Color = Color(1, 1, 1) if connector else CLASS_COLOURS[info.route_class]
		var outline: float = maxf(2.5 * m_per_px * emphasis, 0.0)
		for i in range(1, d.s.size()):
			var a := Vector2(d.x[i - 1], d.z[i - 1])
			var b := Vector2(d.x[i], d.z[i])
			painter.line(a, b, Color(0.05, 0.05, 0.05), d.width[i] + outline + m_per_px, 1.0)
		for i in range(1, d.s.size()):
			var a := Vector2(d.x[i - 1], d.z[i - 1])
			var b := Vector2(d.x[i], d.z[i])
			var c: Color = colour
			if d.support[i] == Policy.Support.BRIDGE_DECK:
				c = Color(0.3, 0.6, 1.0)
			elif d.support[i] == Policy.Support.FORD:
				c = Color(0.5, 0.95, 1.0)
			painter.line(a, b, c, maxf(d.width[i], 1.5 * m_per_px * emphasis), 1.0)
	# Feature intervals as offset strips beside the road.
	for record: Dictionary in data.edges:
		if record.piece_id.is_empty():
			continue
		var d: Dictionary = plan.get_design(record.piece_id)
		for f: Dictionary in record.features:
			if f.status != Policy.REALIZED or not FEATURE_COLOURS.has(f.kind):
				continue
			var offset: float = 3.0 * m_per_px * emphasis + d.width[0]
			for i in range(1, d.s.size()):
				if d.s[i] < f.s0 or d.s[i - 1] > f.s1:
					continue
				var nrm := Vector2(-d.tz[i], d.tx[i])
				painter.line(Vector2(d.x[i - 1], d.z[i - 1]) + nrm * offset, Vector2(d.x[i], d.z[i]) + nrm * offset, FEATURE_COLOURS[f.kind], 1.5 * m_per_px * emphasis, 0.9)
	# Junction ports / patches, crossings.
	for j: Dictionary in data.junctions:
		var colour: Color = Color(0.1, 0.9, 0.2) if j.status == Policy.JUNCTION_READY else (Color(1.0, 0.8, 0.1) if j.status == Policy.JUNCTION_USABLE else Color(1.0, 0.1, 0.1))
		painter.circle(Vector2(j.x, j.z), 4.0 * m_per_px * emphasis, colour, 1.0)
		for p: Dictionary in j.ports:
			painter.circle(Vector2(p.x, p.z), 1.6 * m_per_px * emphasis, Color(1, 1, 1), 1.0)
	for c: Dictionary in data.crossings:
		var p := Vector2(c.r5_x_cm / 100.0, c.r5_z_cm / 100.0)
		painter.circle(p, 2.0 * m_per_px * emphasis, Color(0.0, 0.0, 0.6) if c.status == "RESOLVED" else Color(1.0, 0.0, 0.0), 1.0)


func _closeup(surface: RefCounted, plan: RefCounted, data: Dictionary, graph: RefCounted, record: Dictionary) -> Image:
	var corridor: Dictionary = graph.get_corridor(record.edge_id)
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for k in range(corridor.station_count):
		var p := Vector2(corridor.x_m[k] - ox, corridor.z_m[k] - oz)
		var h: float = maxf(corridor.half_left_m[k], corridor.half_right_m[k]) + 25.0
		lo = Vector2(minf(lo.x, p.x - h), minf(lo.y, p.y - h))
		hi = Vector2(maxf(hi.x, p.x + h), maxf(hi.y, p.y + h))
	lo = lo.clamp(Vector2.ZERO, Vector2(4096, 4096))
	hi = hi.clamp(Vector2.ZERO, Vector2(4096, 4096))
	var extent: Vector2 = hi - lo
	var m_per_px: float = maxf(maxf(extent.x / 1600.0, extent.y / 1200.0), 0.5)
	var w: int = int(extent.x / m_per_px) + 1
	var h: int = int(extent.y / m_per_px) + 1
	var image := Image.create(w, h, false, Image.FORMAT_RGB8)
	var bounds: Dictionary = surface.get_bounds_m()
	# Exact natural surface on a coarse grid, bilinear per pixel.
	var step: float = maxf(4.0, m_per_px * 4.0)
	var gw: int = int(extent.x / step) + 2
	var gh: int = int(extent.y / step) + 2
	var grid := PackedFloat64Array()
	grid.resize(gw * gh)
	var hlo: float = INF
	var hhi: float = -INF
	for j in range(gh):
		for i in range(gw):
			var x: float = clampf(lo.x + i * step, 0.0, 4096.0)
			var z: float = clampf(lo.y + j * step, 0.0, 4096.0)
			var v: float = surface.sample_height(bounds.min_x + x, bounds.min_z + z).height_m
			grid[j * gw + i] = v
			hlo = minf(hlo, v)
			hhi = maxf(hhi, v)
	var field := PackedFloat64Array()
	field.resize(w * h)
	for j in range(h):
		for i in range(w):
			var gx: float = i * m_per_px / step
			var gz: float = j * m_per_px / step
			var i0: int = mini(floori(gx), gw - 2)
			var j0: int = mini(floori(gz), gh - 2)
			var fx: float = gx - i0
			var fz: float = gz - j0
			field[j * w + i] = (grid[j0 * gw + i0] * (1.0 - fx) + grid[j0 * gw + i0 + 1] * fx) * (1.0 - fz) + (grid[(j0 + 1) * gw + i0] * (1.0 - fx) + grid[(j0 + 1) * gw + i0 + 1] * fx) * fz
	for j in range(h):
		for i in range(w):
			var v: float = field[j * w + i]
			var hx: float = field[j * w + mini(i + 1, w - 1)] - field[j * w + maxi(i - 1, 0)]
			var hz: float = field[mini(j + 1, h - 1) * w + i] - field[maxi(j - 1, 0) * w + i]
			var shade: float = clampf(0.78 - (hx + hz) / (4.0 * m_per_px) * 0.45, 0.5, 1.08)
			var t: float = (v - hlo) / maxf(hhi - hlo, 1.0)
			var colour: Color = Color(0.50, 0.58, 0.44).lerp(Color(0.85, 0.82, 0.74), t) * shade
			var v1: float = field[j * w + mini(i + 1, w - 1)]
			var v2: float = field[mini(j + 1, h - 1) * w + i]
			if floorf(v / 10.0) != floorf(v1 / 10.0) or floorf(v / 10.0) != floorf(v2 / 10.0):
				colour = colour * 0.62
			elif floorf(v / 2.0) != floorf(v1 / 2.0) or floorf(v / 2.0) != floorf(v2 / 2.0):
				colour = colour * 0.88
			colour.a = 1.0
			image.set_pixel(i, j, colour)
	_draw_network(image, m_per_px, lo, plan, data, graph, 1.0)
	# Tie-in footprint of this edge (translucent), on top.
	if not record.piece_id.is_empty():
		var painter := Painter.new(image, m_per_px, lo)
		var d: Dictionary = plan.get_design(record.piece_id)
		var shoulder: float = Policy.CLASSES[record.class].shoulder_m
		for i in range(1, d.s.size()):
			var nrm := Vector2(-d.tz[i], d.tx[i])
			var c := Vector2(d.x[i], d.z[i])
			var half: float = 0.5 * d.width[i] + shoulder
			painter.line(c + nrm * half, c + nrm * (half + d.tie_l[i]), Color(0.9, 0.5, 0.2) if d.fill_l[i] < 0.0 else Color(0.3, 0.8, 0.3), m_per_px, 0.5)
			painter.line(c - nrm * half, c - nrm * (half + d.tie_r[i]), Color(0.9, 0.5, 0.2) if d.fill_r[i] < 0.0 else Color(0.3, 0.8, 0.3), m_per_px, 0.5)
	var label := Painter.new(image, 1.0, Vector2.ZERO)
	label.text(Vector2(8, 8), "EDGE %d %s %s %.0fM" % [record.edge_id, record.class_name, record.status, record.metrics.get("length_m", 0.0)], Color(1, 1, 1), 3)
	if not record.reasons.is_empty():
		label.text(Vector2(8, 36), " ".join(record.reasons).replace("ERR_R6_", ""), Color(1, 0.6, 0.6), 2)
	label.text(Vector2(8, h - 24), "%.2f M/PX" % m_per_px, Color(1, 1, 1), 2)
	return image


# --- Profiles ---

func _profile_png(d: Dictionary, record: Dictionary, cls: Dictionary) -> Image:
	var w: int = 1600
	var panel: int = 150
	var panels: int = 5
	var image := Image.create(w, panel * panels + 40, false, Image.FORMAT_RGB8)
	image.fill(Color(0.97, 0.97, 0.96))
	var total: float = d.s[d.s.size() - 1]
	var p := Painter.new(image, 1.0, Vector2.ZERO)
	var x_of := func(s: float) -> float: return 60.0 + (w - 80.0) * s / maxf(total, 1.0)
	# Feature intervals as background bands across all panels.
	for f: Dictionary in record.features:
		if not FEATURE_COLOURS.has(f.kind):
			continue
		var c: Color = FEATURE_COLOURS[f.kind]
		var alpha: float = 0.18 if f.status == Policy.REALIZED else 0.06
		p.rect(Vector2(x_of.call(f.s0), 20), Vector2(maxf(x_of.call(f.s1) - x_of.call(f.s0), 1.0), panel * panels), c, alpha)
	var series: Array = [
		["ELEVATION M", [d.nat_c, d.y], [Color(0.55, 0.55, 0.55), Color(0, 0, 0)], [], 0],
		["GRADE %", [_scaled(d.grade, 100.0)], [Color(0.1, 0.3, 0.8)], [100.0 * cls.grade_pref, -100.0 * cls.grade_pref, 100.0 * tan(deg_to_rad(cls.grade_hard_deg)), -100.0 * tan(deg_to_rad(cls.grade_hard_deg))], 1],
		["CURVATURE 1/M", [d.k], [Color(0.75, 0.1, 0.1)], [1.0 / cls.radius_hard_m, -1.0 / cls.radius_hard_m, 1.0 / cls.radius_pref_m, -1.0 / cls.radius_pref_m], 2],
		["FILL+ CUT- M", [d.fill_l, d.fill_r], [Color(0.2, 0.6, 0.2), Color(0.6, 0.4, 0.1)], [cls.fill_max_m, -cls.cut_max_m], 3],
		["BANK DEG", [d.bank], [Color(0.4, 0.2, 0.6)], [], 4]]
	if record.has("intent_curvature"):
		series[2][1] = [record.intent_curvature.k_at_design_s, d.k]
		series[2][2] = [Color(0.95, 0.65, 0.65), Color(0.75, 0.1, 0.1)]
	for spec: Array in series:
		var top: float = 20.0 + spec[4] * panel
		var lo: float = INF
		var hi: float = -INF
		for values: PackedFloat64Array in spec[1]:
			for v: float in values:
				lo = minf(lo, v)
				hi = maxf(hi, v)
		for v: float in spec[3]:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		if hi - lo < 1e-6:
			hi += 0.5
			lo -= 0.5
		var pad: float = 0.08 * (hi - lo)
		lo -= pad
		hi += pad
		var y_of := func(v: float) -> float: return top + panel - 14.0 - (panel - 28.0) * (v - lo) / (hi - lo)
		p.line_px(Vector2(60, top + panel - 2), Vector2(w - 20, top + panel - 2), Color(0.75, 0.75, 0.75), 1)
		if lo < 0.0 and hi > 0.0:
			p.line_px(Vector2(60, y_of.call(0.0)), Vector2(w - 20, y_of.call(0.0)), Color(0.6, 0.6, 0.6), 1)
		for v: float in spec[3]:
			p.line_px(Vector2(60, y_of.call(v)), Vector2(w - 20, y_of.call(v)), Color(0.9, 0.3, 0.3), 1)
		for q in range(spec[1].size()):
			var values: PackedFloat64Array = spec[1][q]
			var src: PackedFloat64Array = d.s if values.size() == d.s.size() else record.intent_curvature.s
			for i in range(1, values.size()):
				p.line_px(Vector2(x_of.call(src[i - 1]), y_of.call(values[i - 1])), Vector2(x_of.call(src[i]), y_of.call(values[i])), spec[2][q], 2)
		p.text(Vector2(64, top + 4), spec[0] + "  [%s, %s]" % [str(snappedf(lo + pad, 0.0001)), str(snappedf(hi - pad, 0.0001))], Color(0.1, 0.1, 0.1), 2)
	# Supports along the elevation panel.
	for i in range(1, d.s.size()):
		if d.support[i] == Policy.Support.BRIDGE_DECK:
			p.rect(Vector2(x_of.call(d.s[i - 1]), 20 + panel - 12), Vector2(maxf(x_of.call(d.s[i]) - x_of.call(d.s[i - 1]), 1.0), 8), Color(0.2, 0.5, 1.0), 1.0)
		elif d.support[i] == Policy.Support.FORD:
			p.rect(Vector2(x_of.call(d.s[i - 1]), 20 + panel - 12), Vector2(maxf(x_of.call(d.s[i]) - x_of.call(d.s[i - 1]), 1.0), 8), Color(0.4, 0.9, 1.0), 1.0)
	for m in range(0, int(total) + 1, 100):
		p.line_px(Vector2(x_of.call(m), 20), Vector2(x_of.call(m), 20 + panel * panels), Color(0.85, 0.85, 0.85), 1)
		p.text(Vector2(x_of.call(m) + 2, 20 + panel * panels + 4), str(m), Color(0.3, 0.3, 0.3), 2)
	p.text(Vector2(8, 2), "EDGE %d %s  L=%.0fM  S=0 AT PORT A" % [record.edge_id, record.class_name, total], Color(0, 0, 0), 2)
	return image


static func _scaled(values: PackedFloat64Array, factor: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for v: float in values:
		out.append(v * factor)
	return out


func _profile_svg(d: Dictionary, record: Dictionary, name: String) -> String:
	var w: float = 1600.0
	var total: float = d.s[d.s.size() - 1]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d 640" font-family="sans-serif" font-size="12">\n' % w
	svg += '<rect width="100%%" height="100%%" fill="#fafaf8"/><text x="8" y="14">%s edge %d %s, %.0f m (s = 0 at port a)</text>\n' % [name, record.edge_id, record.class_name, total]
	var panels: Array = [["elevation m (grey natural, black road)", [d.nat_c, d.y], ["#888", "#000"]], ["grade", [d.grade], ["#1a4dcc"]], ["signed curvature 1/m", [d.k], ["#c01a1a"]],
		["edge fill(+)/cut(-) m l / r", [d.fill_l, d.fill_r], ["#2a9a2a", "#9a661a"]]]
	for q in range(panels.size()):
		var top: float = 24.0 + q * 150.0
		var lo: float = INF
		var hi: float = -INF
		for values: PackedFloat64Array in panels[q][1]:
			for v: float in values:
				lo = minf(lo, v)
				hi = maxf(hi, v)
		if hi - lo < 1e-6:
			hi += 0.5
			lo -= 0.5
		svg += '<text x="64" y="%.1f">%s [%s, %s]</text>\n' % [top + 12, panels[q][0], str(snappedf(lo, 0.0001)), str(snappedf(hi, 0.0001))]
		for k in range(panels[q][1].size()):
			var values: PackedFloat64Array = panels[q][1][k]
			var points: PackedStringArray = []
			var stride: int = maxi(1, d.s.size() / 1500)
			for i in range(0, d.s.size(), stride):
				points.append("%.1f,%.1f" % [60.0 + (w - 80.0) * d.s[i] / total, top + 136.0 - 120.0 * (values[i] - lo) / (hi - lo)])
			svg += '<polyline fill="none" stroke="%s" stroke-width="1.2" points="%s"/>\n' % [panels[q][2][k], " ".join(points)]
	for f: Dictionary in record.features:
		svg += '<rect x="%.1f" y="24" width="%.1f" height="600" fill="%s" opacity="%.2f"><title>%s %s %s</title></rect>\n' % [60.0 + (w - 80.0) * f.s0 / total,
			maxf((w - 80.0) * (f.s1 - f.s0) / total, 1.0), "#" + FEATURE_COLOURS.get(f.kind, Color(0.5, 0.5, 0.5)).to_html(false), 0.15 if f.status == Policy.REALIZED else 0.05,
			f.kind, f.status, JSON.stringify(f.measured)]
	return svg + "</svg>\n"


# --- SVG network map ---

func _svg(plan: RefCounted, data: Dictionary, graph: RefCounted, name: String) -> String:
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4096 4096" font-family="sans-serif">\n<image href="map_base.png" x="0" y="0" width="4096" height="4096"/>\n'
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	for e in range(graph.get_edge_count()):
		var corridor: Dictionary = graph.get_corridor(e)
		var points: PackedStringArray = []
		for k in range(corridor.station_count):
			points.append("%.2f,%.2f" % [corridor.x_m[k] - ox, corridor.z_m[k] - oz])
		var failed: bool = data.edges[e].status != "READY"
		svg += '<polyline fill="none" stroke="%s" stroke-width="%s" stroke-dasharray="%s" opacity="%s" points="%s"><title>R5 edge %d %s: %s</title></polyline>\n' % [
			"#e01010" if failed else "#ffffff", "5" if failed else "1.5", "12,8" if failed else "6,6", "0.95" if failed else "0.5", " ".join(points), e, data.edges[e].class_name,
			", ".join(data.edges[e].reasons) if failed else "R6 READY"]
	for piece_id: String in plan.get_piece_ids():
		var info: Dictionary = plan.get_piece_info(piece_id)
		var d: Dictionary = plan.get_design(piece_id)
		var points: PackedStringArray = []
		for i in range(0, d.s.size()):
			points.append("%.2f,%.2f" % [d.x[i], d.z[i]])
		var colour: String = "#ffffff" if info.kind == "MOVEMENT" else "#" + CLASS_COLOURS[info.route_class].to_html(false)
		svg += '<polyline fill="none" stroke="#111" stroke-width="%.2f" points="%s"/>\n' % [d.width[0] + 2.5, " ".join(points)]
		svg += '<polyline fill="none" stroke="%s" stroke-width="%.2f" points="%s"><title>%s %.0f m</title></polyline>\n' % [colour, d.width[0], " ".join(points), piece_id, d.s[d.s.size() - 1]]
	for j: Dictionary in data.junctions:
		svg += '<circle cx="%.2f" cy="%.2f" r="9" fill="%s" stroke="#000"><title>junction %d %s %s</title></circle>\n' % [j.x, j.z,
			"#22dd33" if j.status == Policy.JUNCTION_READY else ("#ffcc11" if j.status == Policy.JUNCTION_USABLE else "#ff2222"), j.node_id, j.status, ", ".join(j.reasons)]
	for c: Dictionary in data.crossings:
		svg += '<circle cx="%.2f" cy="%.2f" r="6" fill="%s"><title>%s %s %s</title></circle>\n' % [c.r5_x_cm / 100.0, c.r5_z_cm / 100.0, "#1133aa" if c.status == "RESOLVED" else "#ff0000",
			c.crossing_id, c.status, c.get("support", ", ".join(c.reasons))]
	for record: Dictionary in data.edges:
		var corridor: Dictionary = graph.get_corridor(record.edge_id)
		var mid: int = corridor.station_count / 2
		svg += '<text x="%.1f" y="%.1f" font-size="34" fill="#000" stroke="#fff" stroke-width="0.8">e%d</text>\n' % [corridor.x_m[mid] - ox + 12, corridor.z_m[mid] - oz, record.edge_id]
	svg += '<text x="20" y="60" font-size="48" fill="#000" stroke="#fff" stroke-width="1">%s  R6 %s</text>\n' % [name, data.status]
	return svg + "</svg>\n"


# --- Benchmark ---

func _benchmark(options: Dictionary) -> void:
	var records: Array = []
	for case: Array in options.cases:
		var up: Dictionary = _upstream(case[0], case[1])
		var graph: RefCounted = up.routes.graph
		Synth.synthesize(up.plan, up.terrain, up.hydrology, graph)  # warm-up
		var repeats: Array = []
		for r in range(3):
			var memory0: int = OS.get_static_memory_usage()
			var t0: int = Time.get_ticks_usec()
			var result: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, graph)
			var elapsed: float = (Time.get_ticks_usec() - t0) / 1e6
			repeats.append({"r6_s": elapsed, "status": result.status, "signature": result.plan.signature() if result.plan != null else "", "timings_s": result.diagnostics.get("timings_s", {}),
				"natural_queries": result.diagnostics.get("natural_queries", 0), "fit_evaluations": result.diagnostics.get("fit_evaluations", 0),
				"static_memory_delta_bytes": OS.get_static_memory_usage() - memory0})
			result.clear()
		records.append({"case": [case[0], case[1].x, case[1].y], "upstream_s": up.upstream_s, "r5_s": up.r5_s, "repeats": repeats})
		print("R6_BENCH %s %s" % [case[0], JSON.stringify(repeats.map(func(x: Dictionary) -> float: return x.r6_s))])
	# Lifecycle: ten construct / release cycles of the first case.
	var up0: Dictionary = _upstream(options.cases[0][0], options.cases[0][1])
	var cycles: Array = []
	for c in range(10):
		var objects0: float = Performance.get_monitor(Performance.OBJECT_COUNT)
		var memory0: int = OS.get_static_memory_usage()
		var result: Dictionary = Synth.synthesize(up0.plan, up0.terrain, up0.hydrology, up0.routes.graph)
		result.clear()
		cycles.append({"cycle": c, "object_delta": Performance.get_monitor(Performance.OBJECT_COUNT) - objects0, "static_memory_delta_bytes": OS.get_static_memory_usage() - memory0,
			"static_memory_bytes": OS.get_static_memory_usage()})
	_write_json(options.out.path_join("benchmark.json"), {"records": records, "cycles": cycles, "engine": Engine.get_version_info()})
	print("R6_BENCH_SUMMARY cases=%d cycles=%d" % [records.size(), cycles.size()])


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _write_json(path: String, value: Variant) -> void:
	_write_text(path, JSON.stringify(value, "\t"))


## Minimal raster painter in metres (alpha blending, thick lines, 5x7 text).
class Painter extends RefCounted:
	var image: Image
	var scale: float
	var origin: Vector2
	const FONT := {"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31], "3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2],
		"5": [31, 16, 30, 1, 1, 17, 14], "6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14], "9": [14, 17, 17, 15, 1, 2, 12],
		"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14], "D": [28, 18, 17, 17, 17, 18, 28], "E": [31, 16, 16, 30, 16, 16, 31],
		"F": [31, 16, 16, 30, 16, 16, 16], "G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14], "J": [7, 2, 2, 2, 2, 18, 12],
		"K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31], "M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
		"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4],
		"U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17], "Y": [17, 17, 10, 4, 4, 4, 4],
		"Z": [31, 1, 2, 4, 8, 16, 31], ".": [0, 0, 0, 0, 0, 12, 12], "-": [0, 0, 0, 31, 0, 0, 0], "+": [0, 4, 4, 31, 4, 4, 0], "/": [1, 1, 2, 4, 8, 16, 16], ":": [0, 12, 12, 0, 12, 12, 0],
		"%": [24, 25, 2, 4, 8, 19, 3], "[": [14, 8, 8, 8, 8, 8, 14], "]": [14, 2, 2, 2, 2, 2, 14], ",": [0, 0, 0, 0, 12, 4, 8], "=": [0, 0, 31, 0, 31, 0, 0], "_": [0, 0, 0, 0, 0, 0, 31],
		"(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8], " ": [0, 0, 0, 0, 0, 0, 0]}

	func _init(image_: Image, scale_: float, origin_: Vector2) -> void:
		image = image_
		scale = scale_
		origin = origin_

	func _blend(x: int, y: int, colour: Color, alpha: float) -> void:
		if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
			return
		if alpha >= 1.0:
			image.set_pixel(x, y, colour)
		else:
			image.set_pixel(x, y, image.get_pixel(x, y).lerp(colour, alpha))

	func _disc(p: Vector2, radius_px: float, colour: Color, alpha: float) -> void:
		var r: int = ceili(radius_px)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= radius_px * radius_px + 0.25:
					_blend(roundi(p.x) + dx, roundi(p.y) + dy, colour, alpha)

	## Thick line in metres (width in metres).
	func line(a: Vector2, b: Vector2, colour: Color, width_m: float, alpha: float) -> void:
		var pa: Vector2 = (a - origin) / scale
		var pb: Vector2 = (b - origin) / scale
		var radius: float = maxf(0.5 * width_m / scale, 0.5)
		var steps: int = maxi(1, ceili(pa.distance_to(pb) / maxf(radius * 0.7, 0.5)))
		for i in range(steps + 1):
			_disc(pa.lerp(pb, float(i) / steps), radius, colour, alpha)

	func line_px(a: Vector2, b: Vector2, colour: Color, width_px: int) -> void:
		var steps: int = maxi(1, ceili(a.distance_to(b)))
		for i in range(steps + 1):
			var q: Vector2 = a.lerp(b, float(i) / steps)
			for d in range(width_px):
				_blend(roundi(q.x), roundi(q.y) + d, colour, 1.0)

	func circle(p: Vector2, radius_m: float, colour: Color, alpha: float) -> void:
		_disc((p - origin) / scale, radius_m / scale, colour, alpha)

	func rect(p: Vector2, size: Vector2, colour: Color, alpha: float) -> void:
		var a: Vector2 = (p - origin) / scale
		var b: Vector2 = (p + size - origin) / scale
		for y in range(floori(a.y), ceili(b.y)):
			for x in range(floori(a.x), ceili(b.x)):
				_blend(x, y, colour, alpha)

	func text(p: Vector2, value: String, colour: Color, size: int) -> void:
		var x: int = int(p.x)
		for ch: String in value.to_upper():
			var glyph: Array = FONT.get(ch, FONT[" "])
			for row in range(7):
				for col in range(5):
					if (int(glyph[row]) >> (4 - col)) & 1:
						for sy in range(size):
							for sx in range(size):
								_blend(x + col * size + sx, int(p.y) + row * size + sy, colour, 1.0)
			x += 6 * size
