extends SceneTree

## R3 inspection tool (headless, no renderer): 2D hydrology maps and a
## generate + validate sweep. Diagnostic evidence for human judgement, not a
## contract test.
##
##   --seeds=a,b,...  --out=<abs dir outside the project>   maps (region 0,0)
##   --region=x,z                                           region coordinate
##   --sweep=N        --out=<dir>                           N-region sweep
##
## Map legend: hypsometric tint + hillshade of base terrain (TerrainField);
## grey lines = catchment boundaries (drainage lattice); river = dark blue at
## true width; tributaries = blue; perennial creeks = light blue; intermittent
## creeks = pale dotted; ponds = cyan; CLOSED bodies = violet; red dot = edge
## outlet; yellow dot = confluence on the major river; white frame = R1 floor.

const Generator = preload("res://scripts/world/region/region_generator.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const PX: int = 1024
const M_PER_PX: float = 4.0

var _out: String = ""


func _initialize() -> void:
	var seeds: Array = [184729, 42, 77777]
	var region := Vector2i.ZERO
	var sweep: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.substr(6).replace("\\", "/").simplify_path()
		elif argument.begins_with("--seeds="):
			seeds = []
			for part: String in argument.substr(8).split(","):
				seeds.append(part.to_int())
		elif argument.begins_with("--region="):
			var parts: PackedStringArray = argument.substr(9).split(",")
			region = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif argument.begins_with("--sweep="):
			sweep = argument.substr(8).to_int()
	var source_root: String = ProjectSettings.globalize_path("res://").replace("\\", "/").trim_suffix("/")
	if _out.is_empty() or not _out.is_absolute_path() or _out.to_lower().begins_with(source_root.to_lower() + "/"):
		push_error("HYDRO_MAP_FAIL ERR_MAP_OUTPUT outside-project absolute directory required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var identity: Dictionary = {}
	for path: String in ["scripts/world/region/region_seed_derivation.gd", "scripts/world/region/macro_terrain_plan.gd", "scripts/world/region/macro_geography_generator.gd", "scripts/world/region/macro_terrain_evaluator.gd", "scripts/world/region/terrain_field.gd", "scripts/world/region/drainage_routing.gd", "scripts/world/region/hydrology_generator.gd", "scripts/world/region/hydrology_plan.gd", "scripts/test/capture_hydrology_map.gd"]:
		identity[path] = FileAccess.get_sha256("res://" + path)
	print("HYDRO_MAP_SOURCES " + JSON.stringify(identity))
	if sweep > 0:
		quit(_sweep(sweep))
		return
	var tiles: Array = []
	for seed_value: int in seeds:
		var image: Image = _map(seed_value, region)
		if image == null:
			quit(1)
			return
		var path: String = _out.path_join("hydro_map_seed_%d_r%d_%d.png" % [seed_value, region.x, region.y])
		image.save_png(path)
		print("HYDRO_MAP " + JSON.stringify({"seed": seed_value, "region": [region.x, region.y], "path": path, "png_sha256": FileAccess.get_sha256(path)}))
		tiles.append(image)
	if tiles.size() > 1:
		var columns: int = mini(4, tiles.size())
		var rows: int = ceili(tiles.size() / float(columns))
		var sheet := Image.create(columns * 512, rows * 512, false, Image.FORMAT_RGB8)
		for k in range(tiles.size()):
			var small: Image = tiles[k].duplicate()
			small.resize(512, 512, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(small, Rect2i(0, 0, 512, 512), Vector2i((k % columns) * 512, (k / columns) * 512))
		var sheet_path: String = _out.path_join("hydro_map_sheet.png")
		sheet.save_png(sheet_path)
		print("HYDRO_MAP_SHEET " + JSON.stringify({"path": sheet_path, "seeds": seeds, "png_sha256": FileAccess.get_sha256(sheet_path)}))
	quit(0)


func _build(seed_value: int, region: Vector2i) -> Dictionary:
	var plan: RefCounted = Generator.build(seed_value, region)
	var field: RefCounted = Field.create(plan).field
	var built: Dictionary = HGen.build(plan, field)
	built.merge({"region_plan": plan, "field": field})
	return built


func _summary(seed_value: int, region: Vector2i, built: Dictionary, ms: int) -> Dictionary:
	var plan: RefCounted = built.plan
	var data: Dictionary = plan.get_data()
	var classes: Array = [0, 0, 0]
	var perennial: int = 0
	var river_children: int = 0
	var edge_roots: int = 0
	var body_roots: int = 0
	for channel: Dictionary in data.channels:
		classes[channel.class] += 1
		perennial += channel.perennial
		river_children += 1 if channel.parent == 0 else 0
		edge_roots += 1 if channel.class != Hydro.CLASS_MAJOR_RIVER and channel.outlet_kind == Hydro.OUTLET_EDGE else 0
		body_roots += 1 if channel.outlet_kind == Hydro.OUTLET_BODY else 0
	var ponds: int = 0
	var closed: int = 0
	var closed_cells: int = 0
	for body: Dictionary in data.bodies:
		ponds += 1 if body.kind == Hydro.BODY_POND else 0
		closed += 1 if body.kind == Hydro.BODY_CLOSED else 0
		closed_cells += body.cells.size() if body.kind == Hydro.BODY_CLOSED else 0
	var terminals: Array = [0, 0, 0, 0]
	for kind: int in data.lattice.terminal:
		terminals[kind] += 1
	# Share of lattice points whose water ends at the river / an edge / a closed body.
	var drains: Array = [0, 0, 0, 0]
	var receiver: PackedInt32Array = data.lattice.receiver
	for start in range(receiver.size()):
		var c: int = start
		while receiver[c] >= 0:
			c = receiver[c]
		drains[data.lattice.terminal[c]] += 1
	var river: Dictionary = data.channels[0]
	return {"seed": seed_value, "region": [region.x, region.y], "signature": plan.signature(), "ms": ms, "channels": data.channels.size(), "classes": classes, "perennial": perennial, "river_children": river_children, "edge_roots": edge_roots, "body_roots": body_roots,
		"ponds": ponds, "closed": closed, "closed_cells": closed_cells, "terminal_cells": terminals, "drain_share_permille": [roundi(1000.0 * drains[1] / receiver.size()), roundi(1000.0 * drains[2] / receiver.size()), roundi(1000.0 * drains[3] / receiver.size())], "sinuosity": snappedf(river.station_cm[river.station_cm.size() - 1] / float(Hydro.DOMAIN_CM), 0.001),
		"river_width_m": [river.width_cm[0] / 100.0, river.width_cm[river.width_cm.size() - 1] / 100.0], "river_drop_m": (river.surface_cm[0] - river.surface_cm[river.surface_cm.size() - 1]) / 100.0, "character": data.character}


func _sweep(count: int) -> int:
	var failures: int = 0
	var start: int = Time.get_ticks_msec()
	for k in range(count):
		var seed_value: int = 1000003 * k + 17
		var region := Vector2i(k % 7 - 3, (k / 7) % 5 - 2)
		var t0: int = Time.get_ticks_msec()
		var built: Dictionary = _build(seed_value, region)
		var ms: int = Time.get_ticks_msec() - t0
		if not built.is_valid:
			failures += 1
			print("HYDRO_SWEEP_REGION " + JSON.stringify({"seed": seed_value, "region": [region.x, region.y], "is_valid": false, "reason_code": built.reason_code, "detail": built.detail}))
			continue
		var summary: Dictionary = _summary(seed_value, region, built, ms)
		summary["is_valid"] = built.plan.validate().is_valid
		failures += 0 if summary.is_valid else 1
		print("HYDRO_SWEEP_REGION " + JSON.stringify(summary))
	print("HYDRO_SWEEP_SUMMARY " + JSON.stringify({"regions": count, "failures": failures, "seconds": (Time.get_ticks_msec() - start) / 1000.0}))
	return 1 if failures > 0 else 0


func _map(seed_value: int, region: Vector2i) -> Image:
	var t0: int = Time.get_ticks_msec()
	var built: Dictionary = _build(seed_value, region)
	if not built.is_valid:
		push_error("HYDRO_MAP_FAIL seed=%d %s %s" % [seed_value, built.reason_code, built.detail])
		return null
	print("HYDRO_MAP_SUMMARY " + JSON.stringify(_summary(seed_value, region, built, Time.get_ticks_msec() - t0)))
	var field: RefCounted = built.field
	var data: Dictionary = built.plan.get_data()
	var bounds: Dictionary = field.get_bounds_m()
	var lattice: Dictionary = field.sample_lattice(bounds.min_x / 16, bounds.min_z / 16, 257, 257)
	var heights: PackedFloat64Array = lattice.heights_m
	var low: float = INF
	var high: float = -INF
	for h: float in heights:
		low = minf(low, h)
		high = maxf(high, h)
	# Shaded colour per 16 m lattice point, bilinear to 4 m pixels.
	var colours: Array[Color] = []
	var light: Vector3 = Vector3(-1.0, 1.4, -0.8).normalized()
	for k in range(heights.size()):
		var t: float = (heights[k] - low) / maxf(high - low, 1.0)
		var tint: Color = Color(0.36, 0.48, 0.32).lerp(Color(0.62, 0.58, 0.48), smoothstep(0.0, 0.5, t)).lerp(Color(0.93, 0.93, 0.92), smoothstep(0.5, 1.0, t))
		var shade: float = clampf(lattice.normals[k].dot(light), 0.0, 1.0)
		colours.append(tint * (0.45 + 0.65 * shade))
	var image := Image.create(PX, PX, false, Image.FORMAT_RGB8)
	for py in range(PX):
		var fz: float = py * M_PER_PX / 16.0
		var j: int = mini(floori(fz), 255)
		var tz: float = fz - j
		for px in range(PX):
			var fx: float = px * M_PER_PX / 16.0
			var i: int = mini(floori(fx), 255)
			var tx: float = fx - i
			var a: Color = colours[j * 257 + i].lerp(colours[j * 257 + i + 1], tx)
			var b: Color = colours[(j + 1) * 257 + i].lerp(colours[(j + 1) * 257 + i + 1], tx)
			image.set_pixel(px, py, a.lerp(b, tz))
	# Catchment boundaries.
	var n: int = Hydro.LATTICE_SIZE
	var catchment: PackedInt32Array = data.lattice.catchment
	for j in range(n - 1):
		for i in range(n - 1):
			var c: int = catchment[j * n + i]
			if c != catchment[j * n + i + 1]:
				_line(image, Vector2((i + 0.5) * 8, (j - 0.5) * 8), Vector2((i + 0.5) * 8, (j + 0.5) * 8), Color(0.25, 0.25, 0.25), 0)
			if c != catchment[(j + 1) * n + i]:
				_line(image, Vector2((i - 0.5) * 8, (j + 0.5) * 8), Vector2((i + 0.5) * 8, (j + 0.5) * 8), Color(0.25, 0.25, 0.25), 0)
	# R1 floor edges (from the plan's river frame).
	var frame: Dictionary = data.river_frame
	for key: String in ["near_v_cm", "far_v_cm"]:
		for k in range(Hydro.RIVER_STATIONS - 1):
			var a: Vector2 = Macro.frame_to_local(data.frame_symmetry, k * 16.0, frame[key][k] / 100.0) / M_PER_PX
			var b: Vector2 = Macro.frame_to_local(data.frame_symmetry, (k + 1) * 16.0, frame[key][k + 1] / 100.0) / M_PER_PX
			_line(image, a, b, Color(0.95, 0.95, 0.95), 0)
	# Water bodies: lattice cells below the body level.
	for body: Dictionary in data.bodies:
		var colour: Color = Color(0.3, 0.8, 0.9) if body.kind == Hydro.BODY_POND else Color(0.55, 0.35, 0.85)
		for cell: int in body.cells:
			var ci: int = cell % n
			var cj: int = cell / n
			if heights[(2 * cj) * 257 + 2 * ci] >= body.level_cm / 100.0:
				continue
			for py in range(maxi(0, cj * 8 - 4), mini(PX, cj * 8 + 4)):
				for px in range(maxi(0, ci * 8 - 4), mini(PX, ci * 8 + 4)):
					image.set_pixel(px, py, colour)
	# Channels, smallest first so larger ones draw on top.
	var channels: Array = data.channels.duplicate()
	channels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area_m2[a.area_m2.size() - 1] < b.area_m2[b.area_m2.size() - 1])
	for channel: Dictionary in channels:
		var colour: Color
		var radius: int
		match channel.class:
			Hydro.CLASS_MAJOR_RIVER:
				colour = Color(0.05, 0.15, 0.6)
				radius = 0
			Hydro.CLASS_TRIBUTARY:
				colour = Color(0.1, 0.35, 0.95)
				radius = 2
			_:
				colour = Color(0.35, 0.6, 1.0) if channel.perennial == 1 else Color(0.7, 0.85, 1.0)
				radius = 1 if channel.perennial == 1 else 0
		for k in range(channel.x_cm.size() - 1):
			var a := Vector2(channel.x_cm[k], channel.z_cm[k]) / (100.0 * M_PER_PX)
			var b := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1]) / (100.0 * M_PER_PX)
			var r: int = radius if channel.class != Hydro.CLASS_MAJOR_RIVER else maxi(1, roundi(channel.width_cm[k] / 200.0 / M_PER_PX))
			if channel.class == Hydro.CLASS_CREEK and channel.perennial == 0 and k % 2 == 1:
				continue
			_line(image, a, b, colour, r)
		var last: int = channel.x_cm.size() - 1
		var end := Vector2(channel.x_cm[last], channel.z_cm[last]) / (100.0 * M_PER_PX)
		if channel.class != Hydro.CLASS_MAJOR_RIVER and channel.outlet_kind == Hydro.OUTLET_EDGE:
			_disc(image, end, 4, Color(0.9, 0.1, 0.1))
		elif channel.parent == 0:
			_disc(image, end, 3, Color(1.0, 0.85, 0.1))
	return image


func _disc(image: Image, centre: Vector2, radius: int, colour: Color) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				var x: int = roundi(centre.x) + dx
				var y: int = roundi(centre.y) + dy
				if x >= 0 and y >= 0 and x < PX and y < PX:
					image.set_pixel(x, y, colour)


func _line(image: Image, a: Vector2, b: Vector2, colour: Color, radius: int) -> void:
	var steps: int = maxi(1, ceili(a.distance_to(b)))
	for s in range(steps + 1):
		var p: Vector2 = a.lerp(b, s / float(steps))
		if radius == 0:
			var x: int = roundi(p.x)
			var y: int = roundi(p.y)
			if x >= 0 and y >= 0 and x < PX and y < PX:
				image.set_pixel(x, y, colour)
		else:
			_disc(image, p, radius, colour)
