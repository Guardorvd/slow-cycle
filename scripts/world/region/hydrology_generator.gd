class_name HydrologyGenerator
extends RefCounted

## Builds the R3 HydrologyPlan of one MOUNTAIN_RIVER_VALLEY region from its
## RegionPlan (geographic intent: valley, floor, floodplain basin) and its
## TerrainField (authoritative base heights, read only through public queries).
##
##   0. character: wetness, river style, floodplain wetness, upstream river
##      size - drawn first from the registered `hydrology` seed;
##   1. major river: valley axis + seeded meander kept inside the R1 floor,
##      edge to edge along the valley's downstream direction (+u); water
##      surface = monotone fit of the base heights along it, minus a bank;
##   2. drainage routing on a 32 m sub-lattice of base heights, with the
##      floodplain shaping applied on the R1 floor (HydrologyPlan definition,
##      so the floor drains to the river as the composed surface does) and the
##      river corridor and the region boundary as outlets (DrainageRouting);
##   3. depressions: shallow ones are breached by channel profiles; deeper
##      ones become ponds/lakes whose outlet is cut down by up to BREACH_MAX_M
##      (a basin outlet; retained depth grows with wetness) and get an outlet
##      creek; only depressions too deep to drain within the deformation
##      bound stay CLOSED (terminal, a small wetland at the bottom);
##   4. channels where contributing area exceeds the initiation area, traced
##      as main stems with side tributaries; monotone water profiles;
##      Strahler order, class, perennial flag; smoothed geometry.
## No global RNG, time or materialisation order: one local RNG seeded by the
## hydrology seed for the character and meander, keyed hashes per catchment.

const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const RegionPlanScript = preload("res://scripts/world/region/region_plan.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const Routing = preload("res://scripts/world/region/drainage_routing.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")

const STEP: int = Hydro.LATTICE_STEP_M
const N: int = Hydro.LATTICE_SIZE
const STATIONS: int = Hydro.RIVER_STATIONS
const RIVER_MARGIN_M: float = 40.0
const CORRIDOR_M: float = Hydro.RIVER_CORRIDOR_M
const BANK_M: float = 1.5
const PROFILE_MIN_SLOPE: float = 0.0002
const PROFILE_HALF_WINDOW: int = 15
const DEPRESSION_M: float = 0.05
const DEEP_M: float = 0.5
const POND_DEPTH_M: Array[float] = [3.0, 2.0, 1.5] # by wetness
const POND_CELLS: int = 3
const POND_KEEP_M: Array[float] = [1.0, 2.0, 3.0] # retained lake depth by wetness
const BREACH_MAX_M: float = 10.0
const CLOSED_DEPTH_M: float = 18.0
const CLOSED_CELLS: int = 12
const CLOSED_WATER_M: float = 1.5
const MIN_SIDE_CELLS: int = 3
const TRIBUTARY_AREA_M2: float = 1.0e6
const SMOOTHING_PASSES: int = 2
const MEANDER_MAX_SLOPE: float = 0.9


static func _fail(reason: String, detail: String = "") -> Dictionary:
	return {"is_valid": false, "plan": null, "reason_code": reason, "detail": detail}


## Total producer; reasons ERR_HYDRO_INPUT_MISSING, ERR_HYDRO_INPUT_INVALID,
## ERR_HYDRO_ARCHETYPE, ERR_HYDRO_CONSTRUCTION, ERR_HYDRO_PLAN_INVALID. No fallback.
static func build(region_plan: RefCounted, terrain_field: RefCounted) -> Dictionary:
	if region_plan == null or not region_plan is RegionPlanScript or terrain_field == null or not terrain_field is Field:
		return _fail("ERR_HYDRO_INPUT_MISSING")
	if not region_plan.validate().is_valid or terrain_field.get_region_signature() != region_plan.signature():
		return _fail("ERR_HYDRO_INPUT_INVALID")
	var macro: Dictionary = region_plan.get_macro_terrain().get_data()
	if macro.archetype != Macro.ARCHETYPE_MOUNTAIN_RIVER_VALLEY:
		return _fail("ERR_HYDRO_ARCHETYPE")
	var hydrology_seed: int = Seeds.hydrology_seed(region_plan.get_identity().get_region_seed())
	var rng := RandomNumberGenerator.new()
	rng.seed = hydrology_seed
	var bounds: Dictionary = terrain_field.get_bounds_m()
	# int64 scalars: region origins reach 8.8e12 m and would truncate in Vector2i.
	var origin_x: int = bounds.min_x
	var origin_z: int = bounds.min_z
	var symmetry: int = macro.frame_symmetry

	# 0. Character.
	var wetness: int = rng.randi_range(0, 2)
	var style: int = rng.randi_range(0, 2)
	var floodplain_wetness: int = rng.randi_range(0, 2)
	var amplitude: int
	var wavelength: int
	match style:
		0:
			amplitude = rng.randi_range(300, 450)
			wavelength = rng.randi_range(700, 950)
		1:
			amplitude = rng.randi_range(450, 650)
			wavelength = rng.randi_range(450, 700)
		_:
			amplitude = rng.randi_range(650, 800)
			wavelength = rng.randi_range(300, 480)
	var bias: int = rng.randi_range(amplitude - 900, 900 - amplitude)
	var inflow_m2: int = rng.randi_range(30, 150) * 1000000
	var initiation_m2: int = roundi([250000, 160000, 100000][wetness] * rng.randi_range(900, 1100) / 1000.0)
	var perennial_m2: int = roundi(initiation_m2 * rng.randi_range(25, 40) / 10.0)
	var phase_a: float = rng.randi_range(0, 6283) / 1000.0
	var phase_b: float = rng.randi_range(0, 6283) / 1000.0
	var character: Dictionary = {"wetness": wetness, "river_style": style, "floodplain_wetness": floodplain_wetness, "side_bias_permille": bias, "meander_amplitude_permille": amplitude, "meander_wavelength_m": wavelength, "inflow_area_m2": inflow_m2, "initiation_area_m2": initiation_m2, "perennial_area_m2": perennial_m2}

	# 1. Major river in the valley frame: one vertex per 16 m of valley length.
	var frame: Dictionary = {"river_v_cm": PackedInt64Array(), "near_v_cm": PackedInt64Array(), "far_v_cm": PackedInt64Array(), "floor_cm": PackedInt64Array()}
	var river_points := PackedVector2Array() # local metres (float32 is exact enough inside 4096 m)
	var river_x := PackedInt64Array()
	var river_z := PackedInt64Array()
	for k in range(STATIONS):
		var u: float = k * Hydro.RIVER_STATION_SPACING_M
		var axis: float = Macro.valley_axis(macro, u).x
		var half: Vector2 = Macro.floor_half_widths(macro, u)
		var near: float = axis + half.x
		var far: float = axis - half.y
		var lo: float = far + RIVER_MARGIN_M
		var hi: float = near - RIVER_MARGIN_M
		var phi: float = phase_a + TAU * u / wavelength
		# Meander amplitude is capped so the across-valley slope of the centre
		# line stays below MEANDER_MAX_SLOPE: wide floors meander more, narrows
		# straighten, and no zig-zag appears where the floor is tight.
		var half_band: float = 0.5 * (hi - lo)
		var cap: float = MEANDER_MAX_SLOPE * wavelength / (TAU * 1.26 * maxf(half_band, 1.0))
		var t: float = bias / 1000.0 + minf(amplitude / 1000.0, cap) * (0.8 * sin(phi) + 0.2 * sin(2.3 * phi + phase_b))
		var v: float = 0.5 * (lo + hi) + half_band * t
		frame.river_v_cm.append(roundi(v * 100.0))
		frame.near_v_cm.append(roundi(near * 100.0))
		frame.far_v_cm.append(roundi(far * 100.0))
		var local: Vector2 = Macro.frame_to_local(symmetry, u, v)
		river_x.append(clampi(roundi(local.x * 100.0), 0, Hydro.DOMAIN_CM))
		river_z.append(clampi(roundi(local.y * 100.0), 0, Hydro.DOMAIN_CM))
		river_points.append(Vector2(river_x[k] / 100.0, river_z[k] / 100.0))
	var river_station := PackedInt64Array([0])
	for k in range(1, STATIONS):
		river_station.append(river_station[k - 1] + roundi(Vector2(river_x[k] - river_x[k - 1], river_z[k] - river_z[k - 1]).length()))
	var river_base := PackedFloat64Array()
	for k in range(STATIONS):
		river_base.append(terrain_field.sample_height(origin_x + river_x[k] / 100.0, origin_z + river_z[k] / 100.0).height_m)
	var floor_fit: PackedFloat64Array = _monotone_fit(river_base, river_station)
	for k in range(STATIONS):
		frame.floor_cm.append(roundi(floor_fit[k] * 100.0))

	# 2. Drainage routing over base heights on the 32 m sub-lattice.
	var frame_m: Array = Hydro.frame_arrays_m(frame)
	var heights := PackedFloat64Array()
	heights.resize(N * N)
	for j in range(N):
		for i in range(N):
			var base: float = terrain_field.sample_height(float(origin_x + STEP * i), float(origin_z + STEP * j)).height_m
			heights[j * N + i] = base + Hydro.floodplain_delta(Hydro.frame_values(symmetry, frame_m, float(STEP * i), float(STEP * j)), base)
	var outlets := PackedByteArray()
	outlets.resize(N * N)
	for k in range(STATIONS - 1):
		var a: Vector2 = river_points[k]
		var b: Vector2 = river_points[k + 1]
		for j in range(maxi(0, floori((minf(a.y, b.y) - CORRIDOR_M) / STEP)), mini(N - 1, ceili((maxf(a.y, b.y) + CORRIDOR_M) / STEP)) + 1):
			for i in range(maxi(0, floori((minf(a.x, b.x) - CORRIDOR_M) / STEP)), mini(N - 1, ceili((maxf(a.x, b.x) + CORRIDOR_M) / STEP)) + 1):
				if _segment_distance(Vector2(STEP * i, STEP * j), a, b) <= CORRIDOR_M:
					outlets[j * N + i] = 1
	var routed: Dictionary = Routing.route(heights, N, N, float(STEP), outlets)
	if not routed.is_valid:
		return _fail("ERR_HYDRO_CONSTRUCTION", "routing " + routed.reason_code)
	var receiver: PackedInt32Array = routed.receiver
	var order: PackedInt32Array = routed.order
	var filled: PackedFloat64Array = routed.filled_m
	var terminal := PackedByteArray()
	terminal.resize(N * N)
	for c in range(N * N):
		terminal[c] = Hydro.TERMINAL_RIVER if routed.terminal[c] == Routing.TERMINAL_OUTLET else (Hydro.TERMINAL_EDGE if routed.terminal[c] == Routing.TERMINAL_EDGE else Hydro.TERMINAL_NONE)

	# 3. Depressions -> ponds and closed bodies.
	var bodies: Array = []
	var body_of := PackedInt32Array()
	body_of.resize(N * N)
	body_of.fill(-1)
	var seen := PackedByteArray()
	seen.resize(N * N)
	for start in range(N * N):
		if seen[start] != 0 or terminal[start] != Hydro.TERMINAL_NONE or filled[start] - heights[start] <= DEPRESSION_M:
			continue
		var cells := PackedInt32Array([start])
		seen[start] = 1
		var head: int = 0
		while head < cells.size():
			var c: int = cells[head]
			head += 1
			for offset: Vector2i in Routing.NEIGHBOURS:
				var i: int = c % N + offset.x
				var j: int = c / N + offset.y
				if i < 0 or j < 0 or i >= N or j >= N:
					continue
				var nb: int = j * N + i
				if seen[nb] == 0 and terminal[nb] == Hydro.TERMINAL_NONE and filled[nb] - heights[nb] > DEPRESSION_M:
					seen[nb] = 1
					cells.append(nb)
		cells.sort()
		var depth: float = 0.0
		var deep: int = 0
		var level: float = -INF
		var bottom: float = INF
		for c: int in cells:
			depth = maxf(depth, filled[c] - heights[c])
			deep += 1 if filled[c] - heights[c] >= DEEP_M else 0
			level = maxf(level, filled[c])
			bottom = minf(bottom, heights[c])
		if depth < POND_DEPTH_M[wetness] or deep < POND_CELLS:
			continue
		var closed: bool = depth > CLOSED_DEPTH_M and deep >= CLOSED_CELLS
		var water: float = bottom + CLOSED_WATER_M if closed else level - clampf(depth - POND_KEEP_M[wetness], 0.0, BREACH_MAX_M)
		var id: int = bodies.size()
		bodies.append({"id": id, "kind": Hydro.BODY_CLOSED if closed else Hydro.BODY_POND, "level_cm": roundi(100.0 * water), "outlet_kind": Hydro.OUTLET_BODY if closed else Hydro.OUTLET_EDGE, "outlet_id": -1, "cells": cells})
		for c: int in cells:
			body_of[c] = id
			if closed:
				receiver[c] = -1
				terminal[c] = Hydro.TERMINAL_CLOSED
	var accumulated: Dictionary = Routing.accumulate(receiver, order)
	var area: PackedInt32Array = accumulated.area_cells

	# 4. River discharge: upstream inflow plus the water reaching each station.
	var station_inflow := PackedFloat64Array()
	station_inflow.resize(STATIONS)
	for c in range(N * N):
		if terminal[c] == Hydro.TERMINAL_RIVER:
			var u: float = Macro.local_to_frame(symmetry, float(STEP * (c % N)), float(STEP * (c / N))).x
			station_inflow[clampi(roundi(u / Hydro.RIVER_STATION_SPACING_M), 0, STATIONS - 1)] += area[c] * STEP * STEP
	var river: Dictionary = {"id": 0, "class": Hydro.CLASS_MAJOR_RIVER, "perennial": 1, "order": 1, "parent": -1, "mouth_station_cm": 0, "outlet_kind": Hydro.OUTLET_EDGE, "outlet_id": -1,
		"x_cm": river_x, "z_cm": river_z, "station_cm": river_station, "surface_cm": PackedInt64Array(), "bed_cm": PackedInt64Array(), "width_cm": PackedInt64Array(), "area_m2": PackedInt64Array()}
	var discharge: float = inflow_m2
	for k in range(STATIONS):
		discharge += station_inflow[k]
		var width: float = clampf(4.0 * sqrt(discharge / 1.0e6), 12.0, 60.0)
		var depth: float = clampf(0.8 + 0.04 * width, 1.2, 3.2)
		# Strict descent in integer storage: at least 1 cm per station (the
		# float fit decreases strictly, but by less than 1 cm on gentle reaches).
		var surface: int = roundi(100.0 * (floor_fit[k] - BANK_M))
		if k > 0:
			surface = mini(surface, river.surface_cm[k - 1] - 1)
		river.area_m2.append(roundi(discharge))
		river.width_cm.append(roundi(width * 100.0))
		river.surface_cm.append(surface)
		river.bed_cm.append(surface - roundi(depth * 100.0))
	var channels: Array = [river]

	# 5. Channel network: main stems from each outlet, side tributaries.
	# Shaped ground (base + floodplain shaping) at any region-local point; the
	# channel profiles are taken from it at their final (smoothed) vertices.
	var ground := func(lx: float, lz: float) -> float:
		var base: float = terrain_field.sample_height(origin_x + lx, origin_z + lz).height_m
		return base + Hydro.floodplain_delta(Hydro.frame_values(symmetry, frame_m, lx, lz), base)
	var initiation_cells: int = ceili(initiation_m2 / float(STEP * STEP))
	var is_channel := PackedByteArray()
	is_channel.resize(N * N)
	for c in range(N * N):
		is_channel[c] = 1 if terminal[c] == Hydro.TERMINAL_NONE and area[c] >= initiation_cells else 0
	# Every pond/lake gets an outlet creek from its last cell on the spill path.
	for body: Dictionary in bodies:
		if body.kind != Hydro.BODY_POND:
			continue
		var c: int = body.cells[0]
		for cell: int in body.cells:
			c = cell if heights[cell] < heights[c] else c
		while receiver[c] >= 0 and body_of[receiver[c]] == body.id:
			c = receiver[c]
		while c >= 0 and terminal[c] == Hydro.TERMINAL_NONE and is_channel[c] == 0:
			is_channel[c] = 1
			c = receiver[c]
	var upstream_cells := PackedInt32Array()
	upstream_cells.resize(N * N)
	var donors: Dictionary = {}
	for k in range(N * N - 1, -1, -1):
		var c: int = order[k]
		if is_channel[c] == 0:
			continue
		upstream_cells[c] = maxi(upstream_cells[c], 1)
		var r: int = receiver[c]
		if r >= 0 and is_channel[r] != 0:
			upstream_cells[r] = maxi(upstream_cells[r], upstream_cells[c] + 1)
	var roots: Array[int] = []
	for c in range(N * N):
		if is_channel[c] == 0:
			continue
		var r: int = receiver[c]
		if is_channel[r] != 0:
			if not donors.has(r):
				donors[r] = PackedInt32Array()
			donors[r].append(c)
		else:
			roots.append(c)
	roots.sort_custom(func(a: int, b: int) -> bool: return area[a] > area[b] or (area[a] == area[b] and a < b))
	var channel_of := PackedInt32Array()
	channel_of.resize(N * N)
	channel_of.fill(-1)
	var queue: Array = []
	for root: int in roots:
		queue.append([root, -1])
	var cell_lists: Array = [PackedInt32Array()]
	var cursor: int = 0
	while cursor < queue.size():
		var entry: Array = queue[cursor]
		cursor += 1
		var id: int = channels.size()
		var path := PackedInt32Array([entry[0]])
		var cell: int = entry[0]
		while donors.has(cell):
			var list: PackedInt32Array = donors[cell]
			var main: int = list[0]
			for d: int in list:
				if area[d] > area[main] or (area[d] == area[main] and d < main):
					main = d
			for d: int in list:
				if d != main and upstream_cells[d] >= MIN_SIDE_CELLS:
					queue.append([d, id])
			path.append(main)
			cell = main
		path.reverse()
		for c: int in path:
			channel_of[c] = id
		var built: Dictionary = _channel(id, entry[1], path, channels, receiver, terminal, area, bodies, body_of, initiation_m2, ground)
		if not built.is_valid:
			return _fail("ERR_HYDRO_CONSTRUCTION", built.detail)
		channels.append(built.channel)
		cell_lists.append(path)

	# 6. Strahler order on channel cells, class and perennial flag.
	var strahler := PackedInt32Array()
	strahler.resize(N * N)
	for k in range(N * N - 1, -1, -1):
		var c: int = order[k]
		if channel_of[c] < 0:
			continue
		strahler[c] = maxi(strahler[c], 1)
	for k in range(N * N - 1, -1, -1):
		var c: int = order[k]
		if channel_of[c] < 0 or not donors.has(c):
			continue
		var best: int = 0
		var ties: int = 0
		for d: int in donors[c]:
			if channel_of[d] < 0:
				continue
			if strahler[d] > best:
				best = strahler[d]
				ties = 1
			elif strahler[d] == best:
				ties += 1
		strahler[c] = maxi(strahler[c], best + (1 if ties >= 2 else 0))
	var river_order: int = 1
	for id in range(1, channels.size()):
		var channel: Dictionary = channels[id]
		var path: PackedInt32Array = cell_lists[id]
		channel.order = strahler[path[path.size() - 1]]
		var mouth_area: int = channel.area_m2[channel.area_m2.size() - 1]
		channel.class = Hydro.CLASS_TRIBUTARY if mouth_area >= TRIBUTARY_AREA_M2 or channel.order >= 3 else Hydro.CLASS_CREEK
		channel.perennial = 1 if mouth_area >= perennial_m2 * (0.75 + 0.5 * _keyed_unit(hydrology_seed, path[0])) else 0
		if channel.parent == 0:
			river_order = maxi(river_order, channel.order + 1)
	river.order = river_order

	# 7. Pond outlets: follow the spill path to the first channel or terminal.
	for body: Dictionary in bodies:
		if body.kind != Hydro.BODY_POND:
			continue
		var c: int = body.cells[0]
		while true:
			if body_of[c] != body.id and channel_of[c] >= 0:
				body.outlet_kind = Hydro.OUTLET_CHANNEL
				body.outlet_id = channel_of[c]
				break
			if receiver[c] < 0:
				match terminal[c]:
					Hydro.TERMINAL_RIVER:
						body.outlet_kind = Hydro.OUTLET_CHANNEL
						body.outlet_id = 0
					Hydro.TERMINAL_CLOSED:
						body.outlet_kind = Hydro.OUTLET_BODY
						body.outlet_id = body_of[c]
					_:
						body.outlet_kind = Hydro.OUTLET_EDGE
						body.outlet_id = -1
				break
			c = receiver[c]

	# 8. Catchments (first channel downstream of each lattice point).
	var catchment := PackedInt32Array()
	catchment.resize(N * N)
	for k in range(N * N):
		var c: int = order[k]
		if channel_of[c] >= 0:
			catchment[c] = channel_of[c]
		elif receiver[c] < 0:
			catchment[c] = 0 if terminal[c] == Hydro.TERMINAL_RIVER else -1
		else:
			catchment[c] = catchment[receiver[c]]

	# 9. Floodplain reach around the R1 floodplain basin, widened by wetness.
	var reaches: Array = []
	var first: int = -1
	var last: int = -1
	for k in range(STATIONS):
		if Macro.basin_widening(macro.valley, k * Hydro.RIVER_STATION_SPACING_M) > 40.0:
			first = k if first < 0 else first
			last = k
	if first >= 0:
		var extend: int = floodplain_wetness * 20
		reaches.append([river_station[maxi(0, first - extend)], river_station[mini(STATIONS - 1, last + extend)], 1 if floodplain_wetness >= 1 else 0])

	var data: Dictionary = {
		"region_signature": region_plan.signature(), "terrain_schema": Field.SCHEMA_TAG, "hydrology_seed": hydrology_seed,
		"origin_x_m": origin_x, "origin_z_m": origin_z, "frame_symmetry": symmetry, "character": character,
		"channels": channels, "bodies": bodies, "floodplain_reaches": reaches, "river_frame": frame,
		"lattice": {"receiver": receiver, "terminal": terminal, "area_cells": area, "catchment": catchment},
	}
	var plan := Hydro.new(data)
	var validation: Dictionary = plan.validate()
	if not validation.is_valid:
		return _fail("ERR_HYDRO_PLAN_INVALID", str(validation.reason_codes))
	return {"is_valid": true, "plan": plan, "reason_code": "", "detail": ""}


## One channel from its cell path (head -> mouth-most cell): mouth on its
## parent / the region edge / a closed body, monotone water profile, smoothing.
static func _channel(id: int, parent_id: int, path: PackedInt32Array, channels: Array, receiver: PackedInt32Array, terminal: PackedByteArray, area: PackedInt32Array, bodies: Array, body_of: PackedInt32Array, initiation_m2: int, ground: Callable) -> Dictionary:
	var points := PackedVector2Array()
	var areas := PackedFloat64Array()
	for c: int in path:
		points.append(Vector2(STEP * (c % N), STEP * (c / N)))
		areas.append(area[c] * STEP * STEP)
	var outlet_kind: int = Hydro.OUTLET_CHANNEL
	var outlet_id: int = -1
	var parent: int = parent_id
	var floor_surface: float = -INF
	var mouth_station: int = 0
	var end: int = receiver[path[path.size() - 1]]
	if parent < 0:
		match terminal[end]:
			Hydro.TERMINAL_RIVER:
				parent = 0
			Hydro.TERMINAL_EDGE:
				outlet_kind = Hydro.OUTLET_EDGE
			Hydro.TERMINAL_CLOSED:
				outlet_kind = Hydro.OUTLET_BODY
				outlet_id = body_of[end]
				floor_surface = bodies[outlet_id].level_cm / 100.0
			_:
				return {"is_valid": false, "detail": "channel %d root without terminal" % id}
		if parent < 0:
			points.append(Vector2(STEP * (end % N), STEP * (end / N)))
			areas.append(area[end] * STEP * STEP)
	if parent >= 0:
		outlet_id = parent
		# Project the confluence cell (a parent cell) onto a channel parent, so
		# the mouth lies where the parent already carries at least this area;
		# onto the river, project the channel's last cell.
		var anchor: Vector2 = points[points.size() - 1] if parent == 0 else Vector2(STEP * (end % N), STEP * (end / N))
		var projected: Dictionary = _project(channels[parent], anchor * 100.0)
		mouth_station = projected.station_cm
		var at: Dictionary = Hydro.point_at_station(channels[parent], mouth_station)
		points.append(Vector2(roundi(at.x) / 100.0, roundi(at.z) / 100.0))
		areas.append(areas[areas.size() - 1])
		floor_surface = at.surface / 100.0
	for pass_index in range(SMOOTHING_PASSES):
		var smoothed: Array = _chaikin(points, [areas])
		points = smoothed[0]
		areas = smoothed[1][0]
	# Water surface at the final vertices: running minimum of the shaped
	# ground (pond level inside ponds; breaching shallow pits) minus a gully
	# incision that grows with drainage area, never below the receiving water
	# (the parent at the mouth, or a closed body's level).
	var surfaces := PackedFloat64Array()
	var lowest: float = INF
	for k in range(points.size()):
		var x: float = clampf(points[k].x, 0.0, Hydro.DOMAIN_CM / 100.0)
		var z: float = clampf(points[k].y, 0.0, Hydro.DOMAIN_CM / 100.0)
		var level: float = ground.call(x, z)
		var cell: int = clampi(roundi(z / STEP), 0, N - 1) * N + clampi(roundi(x / STEP), 0, N - 1)
		if body_of[cell] >= 0 and bodies[body_of[cell]].kind == Hydro.BODY_POND:
			level = maxf(level, bodies[body_of[cell]].level_cm / 100.0)
		if not (parent >= 0 and k == points.size() - 1):
			lowest = minf(lowest, level)
		var incision: float = clampf(1.0 + 1.5 * log(areas[k] / initiation_m2) / log(10.0), 1.0, 4.0)
		surfaces.append(maxf(lowest - incision, floor_surface))
	if parent >= 0:
		surfaces[surfaces.size() - 1] = floor_surface
	var channel: Dictionary = {"id": id, "class": Hydro.CLASS_CREEK, "perennial": 0, "order": 1, "parent": parent, "mouth_station_cm": mouth_station, "outlet_kind": outlet_kind, "outlet_id": outlet_id,
		"x_cm": PackedInt64Array(), "z_cm": PackedInt64Array(), "station_cm": PackedInt64Array(), "surface_cm": PackedInt64Array(), "bed_cm": PackedInt64Array(), "width_cm": PackedInt64Array(), "area_m2": PackedInt64Array()}
	var station: float = 0.0
	for k in range(points.size()):
		var x: int = clampi(roundi(points[k].x * 100.0), 0, Hydro.DOMAIN_CM)
		var z: int = clampi(roundi(points[k].y * 100.0), 0, Hydro.DOMAIN_CM)
		var count: int = channel.x_cm.size()
		if count > 0:
			var step: float = Vector2(x - channel.x_cm[count - 1], z - channel.z_cm[count - 1]).length()
			if roundi(station + step) <= channel.station_cm[count - 1]:
				continue # quantisation merged two points
			station += step
		var width: float = clampf(1.0 + 1.6 * sqrt(areas[k] / 1.0e6), 1.0, 8.0)
		var surface: int = roundi(surfaces[k] * 100.0)
		channel.x_cm.append(x)
		channel.z_cm.append(z)
		channel.station_cm.append(roundi(station))
		channel.surface_cm.append(surface)
		channel.bed_cm.append(surface - maxi(1, roundi(100.0 * clampf(0.15 + 0.1 * width, 0.2, 1.0))))
		channel.width_cm.append(roundi(width * 100.0))
		channel.area_m2.append(roundi(areas[k]))
	if channel.x_cm.size() < 2:
		return {"is_valid": false, "detail": "channel %d degenerate" % id}
	# Strict descent in integer storage: from the fixed mouth upwards, every
	# vertex lies at least 1 cm above the next (flat reaches - lakes, the clamp
	# to the receiving water, breached flats - tilt by 1 cm per vertex).
	for k in range(channel.surface_cm.size() - 2, -1, -1):
		var raise: int = channel.surface_cm[k + 1] + 1 - channel.surface_cm[k]
		if raise > 0:
			channel.surface_cm[k] += raise
			channel.bed_cm[k] += raise
	return {"is_valid": true, "channel": channel}


## Corner cutting with fixed end points; attributes follow the same convex
## weights, so monotone attributes stay monotone.
static func _chaikin(points: PackedVector2Array, attributes: Array) -> Array:
	var last: int = points.size() - 1
	var out := PackedVector2Array([points[0]])
	var out_attributes: Array = []
	for values: PackedFloat64Array in attributes:
		out_attributes.append(PackedFloat64Array([values[0]]))
	for i in range(last):
		for weight: float in [0.25, 0.75]:
			if (weight == 0.25 and i == 0) or (weight == 0.75 and i == last - 1):
				continue
			out.append(points[i].lerp(points[i + 1], weight))
			for a in range(attributes.size()):
				out_attributes[a].append(lerpf(attributes[a][i], attributes[a][i + 1], weight))
	if last > 0:
		out.append(points[last])
		for a in range(attributes.size()):
			out_attributes[a].append(attributes[a][last])
	return [out, out_attributes]


## Nearest point of a channel polyline (cm) to p (cm): station in cm.
static func _project(channel: Dictionary, p: Vector2) -> Dictionary:
	var best: float = INF
	var best_station: float = 0.0
	for k in range(channel.x_cm.size() - 1):
		var a := Vector2(channel.x_cm[k], channel.z_cm[k])
		var b := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1])
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 0.0 else 0.0
		var distance: float = p.distance_to(a + ab * t)
		if distance < best:
			best = distance
			best_station = lerpf(channel.station_cm[k], channel.station_cm[k + 1], t)
	return {"station_cm": roundi(best_station), "distance_cm": best}


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 0.0 else 0.0
	return p.distance_to(a + ab * t)


## Monotone (non-increasing downstream) fit of base heights along the river:
## isotonic regression of h + slope * s (pool adjacent violators), minus the
## same slope, then a moving average - every step keeps a strict decrease in
## floats (integer storage then enforces at least 1 cm per station).
static func _monotone_fit(base: PackedFloat64Array, stations_cm: PackedInt64Array) -> PackedFloat64Array:
	var n: int = base.size()
	var means := PackedFloat64Array()
	var weights := PackedInt32Array()
	for k in range(n):
		means.append(base[k] + PROFILE_MIN_SLOPE * stations_cm[k] / 100.0)
		weights.append(1)
		while means.size() >= 2 and means[means.size() - 2] < means[means.size() - 1]:
			var w: int = weights[weights.size() - 2] + weights[weights.size() - 1]
			var m: float = (means[means.size() - 2] * weights[weights.size() - 2] + means[means.size() - 1] * weights[weights.size() - 1]) / w
			means.resize(means.size() - 1)
			weights.resize(weights.size() - 1)
			means[means.size() - 1] = m
			weights[weights.size() - 1] = w
	var iso := PackedFloat64Array()
	for b in range(means.size()):
		for w in range(weights[b]):
			iso.append(means[b])
	for k in range(n):
		iso[k] -= PROFILE_MIN_SLOPE * stations_cm[k] / 100.0
	var fit := PackedFloat64Array()
	for k in range(n):
		var sum: float = 0.0
		for w in range(-PROFILE_HALF_WINDOW, PROFILE_HALF_WINDOW + 1):
			sum += iso[clampi(k + w, 0, n - 1)]
		fit.append(sum / (2 * PROFILE_HALF_WINDOW + 1))
	return fit


## Deterministic value in [0, 1) keyed by seed and a stable lattice identity.
static func _keyed_unit(seed_value: int, key: int) -> float:
	var digest: PackedByteArray = ("slow_cycle.hydrology_key/1\n%d\n%d" % [seed_value, key]).sha256_buffer()
	return ((int(digest[0]) << 16) | (int(digest[1]) << 8) | int(digest[2])) / 16777216.0
