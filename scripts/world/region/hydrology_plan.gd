class_name HydrologyPlan
extends RefCounted

## Immutable R3 hydrology of one region: the single owner of hydrological
## truth. Produced only by HydrologyGenerator from a RegionPlan and its
## TerrainField (base terrain); queried through HydrologyField.
##
## Storage is integer and region-local (like R1), so canonical text and
## signature are exact: positions in centimetres from the region minimum
## corner (world = origin + local), elevations in centimetres, areas in m^2.
##
## channels[]   one channel per stream from source to mouth (Horton main
##              stem). Vertices run downstream. Exactly one MAJOR_RIVER, edge
##              to edge. A tributary ends on its parent at mouth_station_cm.
## bodies[]     depressions kept as water: spilling (POND, outlet channel or
##              edge) or CLOSED (terminal; level below its spill point).
## river_frame  per 16 m valley station u = 16 k: river and R1 floor offsets
##              across the valley (cm) and the fitted floodplain level (cm).
## lattice      32 m drainage lattice (129^2 points, z outer): receiver (-1 =
##              terminal), terminal kind, contributing area (cells),
##              catchment channel (-1 = none). Every point ends at the major
##              river, a region-edge outlet or a CLOSED body.

const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SCHEMA_TAG := "slow_cycle.hydrology/1"
const STATE_GENERATED_R3 := "GENERATED_R3"
const DOMAIN_CM: int = 409600
const LATTICE_STEP_M: int = 32
const LATTICE_SIZE: int = 129
const RIVER_STATIONS: int = 257
const RIVER_STATION_SPACING_M: int = 16
const MAX_DEFORMATION_M: float = 15.0
const RIVER_CORRIDOR_M: float = 26.0

const CLASS_MAJOR_RIVER: int = 0
const CLASS_TRIBUTARY: int = 1
const CLASS_CREEK: int = 2
const OUTLET_CHANNEL: int = 0
const OUTLET_EDGE: int = 1
const OUTLET_BODY: int = 2
const BODY_POND: int = 0
const BODY_CLOSED: int = 1
const TERMINAL_NONE: int = 0
const TERMINAL_RIVER: int = 1
const TERMINAL_EDGE: int = 2
const TERMINAL_CLOSED: int = 3
const MAJOR_WIDTH_CM := Vector2i(1200, 6000)
const CHANNEL_WIDTH_CM := Vector2i(100, 800)

const SCALARS: Array[String] = ["region_signature", "terrain_schema", "hydrology_seed", "origin_x_m", "origin_z_m", "frame_symmetry"]
const CHARACTER: Array[String] = ["wetness", "river_style", "floodplain_wetness", "side_bias_permille", "meander_amplitude_permille", "meander_wavelength_m", "inflow_area_m2", "initiation_area_m2", "perennial_area_m2"]
const CHANNEL_KEYS: Array[String] = ["id", "class", "perennial", "order", "parent", "mouth_station_cm", "outlet_kind", "outlet_id"]
const CHANNEL_ARRAYS: Array[String] = ["x_cm", "z_cm", "station_cm", "surface_cm", "bed_cm", "width_cm", "area_m2"]
const BODY_KEYS: Array[String] = ["id", "kind", "level_cm", "outlet_kind", "outlet_id"]
const FRAME_ARRAYS: Array[String] = ["river_v_cm", "near_v_cm", "far_v_cm", "floor_cm"]
const LATTICE_ARRAYS: Array[String] = ["receiver", "terminal", "area_cells", "catchment"]

var _state: String = STATE_GENERATED_R3
var _data: Dictionary


func _init(data: Dictionary = {}) -> void:
	_data = data.duplicate(true)


func get_state() -> String:
	return _state


func get_data() -> Dictionary:
	return _data.duplicate(true)


func get_region_signature() -> String:
	return _data.get("region_signature", "")


func get_channel_count() -> int:
	return _data.get("channels", []).size()


## Copy of one channel record (see header for its fields).
func get_channel(index: int) -> Dictionary:
	return _data.channels[index].duplicate(true)


func get_body_count() -> int:
	return _data.get("bodies", []).size()


## Copy of one water-body record.
func get_body(index: int) -> Dictionary:
	return _data.bodies[index].duplicate(true)


func get_character() -> Dictionary:
	return _data.get("character", {}).duplicate(true)


static func _text(value: Variant) -> String:
	if value is PackedInt32Array or value is PackedInt64Array or value is PackedByteArray or value is Array:
		var parts: PackedStringArray = []
		for item: Variant in value:
			parts.append(str(item))
		return ",".join(parts)
	return str(value)


func canonical_text() -> String:
	var text: String = SCHEMA_TAG + "\nstate=" + _state + "\n"
	for key: String in SCALARS:
		text += key + "=" + _text(_data.get(key, "MISSING")) + "\n"
	var character: Dictionary = _data.get("character", {})
	for key: String in CHARACTER:
		text += "character." + key + "=" + _text(character.get(key, "MISSING")) + "\n"
	var channels: Array = _data.get("channels", [])
	text += "channels.count=" + str(channels.size()) + "\n"
	for channel: Dictionary in channels:
		for key: String in CHANNEL_KEYS + CHANNEL_ARRAYS:
			text += "channel." + str(channel.get("id", "?")) + "." + key + "=" + _text(channel.get(key, "MISSING")) + "\n"
	var bodies: Array = _data.get("bodies", [])
	text += "bodies.count=" + str(bodies.size()) + "\n"
	for body: Dictionary in bodies:
		for key: String in BODY_KEYS + ["cells"]:
			text += "body." + str(body.get("id", "?")) + "." + key + "=" + _text(body.get(key, "MISSING")) + "\n"
	for reach: Variant in _data.get("floodplain_reaches", []):
		text += "floodplain_reach=" + _text(reach) + "\n"
	var frame: Dictionary = _data.get("river_frame", {})
	for key: String in FRAME_ARRAYS:
		text += "river_frame." + key + "=" + _text(frame.get(key, "MISSING")) + "\n"
	var lattice: Dictionary = _data.get("lattice", {})
	for key: String in LATTICE_ARRAYS:
		# Large arrays enter the text through their digest.
		text += "lattice." + key + ".sha256=" + _text(lattice.get(key, "MISSING")).sha256_text() + "\n"
	return text


func signature() -> String:
	return canonical_text().sha256_text()


# --- Floodplain shaping: one definition, used by the generator (routing on
# the shaped floor) and by HydrologyField (deformation) ---

const FLOODPLAIN_MAX_M: float = 8.0
const FLOODPLAIN_FADE_M: float = 80.0
const FLOODPLAIN_LATERAL_SLOPE: float = 0.01


## Valley-frame values at a region-local point from river_frame arrays in
## metres [river_v, near_v, far_v, floor]: [v, river_v, near_v, far_v, floor].
static func frame_values(symmetry: int, frame_m: Array, lx: float, lz: float) -> Array:
	var frame: Vector2 = Macro.local_to_frame(symmetry, lx, lz)
	var s: float = clampf(frame.x / RIVER_STATION_SPACING_M, 0.0, RIVER_STATIONS - 1.0)
	var k: int = mini(floori(s), RIVER_STATIONS - 2)
	var t: float = s - k
	return [frame.y, lerpf(frame_m[0][k], frame_m[0][k + 1], t), lerpf(frame_m[1][k], frame_m[1][k + 1], t), lerpf(frame_m[2][k], frame_m[2][k + 1], t), lerpf(frame_m[3][k], frame_m[3][k + 1], t)]


static func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Floodplain shaping delta: inside the R1 floor the ground moves towards the
## fitted floodplain level plus a gentle lateral rise away from the river
## (so the floor drains to the river), fully near the river and by 75 %
## across the floor. Beyond the floor edge it only raises wall-foot troughs
## (where R1 noise grows faster than the wall rises), fading out within
## FLOODPLAIN_FADE_M: valley walls are never cut. Clamped to +-FLOODPLAIN_MAX_M.
static func floodplain_delta(values: Array, base: float) -> float:
	var v: float = values[0]
	var outside: float = maxf(v - values[2], values[3] - v)
	if outside >= FLOODPLAIN_FADE_M:
		return 0.0
	var off: float = absf(v - values[1])
	var target: float = values[4] + FLOODPLAIN_LATERAL_SLOPE * maxf(0.0, off - 20.0)
	var strength: float = lerpf(1.0, 0.75, _smooth((off - 60.0) / 80.0))
	var delta: float = clampf(target - base, -FLOODPLAIN_MAX_M, FLOODPLAIN_MAX_M)
	if delta < 0.0:
		# Cutting fades in from the floor edge (none at or beyond it).
		delta *= _smooth(-outside / 40.0)
	var weight: float = 1.0 if outside <= 0.0 else 1.0 - _smooth(outside / FLOODPLAIN_FADE_M)
	return weight * strength * delta


static func frame_arrays_m(river_frame: Dictionary) -> Array:
	var arrays: Array = []
	for key: String in FRAME_ARRAYS:
		var values := PackedFloat64Array()
		for value: int in river_frame[key]:
			values.append(value / 100.0)
		arrays.append(values)
	return arrays


# --- Geometry helpers shared by validation, HydrologyField and tests ---

## Position (cm, float) and attributes at a station along a channel.
static func point_at_station(channel: Dictionary, station_cm: float) -> Dictionary:
	var stations: PackedInt64Array = channel.station_cm
	var last: int = stations.size() - 1
	var k: int = 0
	while k < last - 1 and stations[k + 1] < station_cm:
		k += 1
	var span: float = float(stations[k + 1] - stations[k])
	var t: float = clampf((station_cm - stations[k]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return {"x": lerpf(channel.x_cm[k], channel.x_cm[k + 1], t), "z": lerpf(channel.z_cm[k], channel.z_cm[k + 1], t), "surface": lerpf(channel.surface_cm[k], channel.surface_cm[k + 1], t), "area": lerpf(channel.area_m2[k], channel.area_m2[k + 1], t)}


static func _segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var d1: float = (b - a).cross(c - a)
	var d2: float = (b - a).cross(d - a)
	var d3: float = (d - c).cross(a - c)
	var d4: float = (d - c).cross(b - c)
	return ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0))


static func _on_boundary(x: int, z: int) -> bool:
	return x == 0 or z == 0 or x == DOMAIN_CM or z == DOMAIN_CM


# --- Validation: diagnostic only, fixed check order, never repairs ---

func _schema_ok() -> bool:
	if _state != STATE_GENERATED_R3:
		return false
	for key: String in SCALARS + ["character", "channels", "bodies", "floodplain_reaches", "river_frame", "lattice"]:
		if not _data.has(key):
			return false
	if not _data.character is Dictionary or not _data.channels is Array or not _data.bodies is Array or not _data.river_frame is Dictionary or not _data.lattice is Dictionary:
		return false
	for key: String in CHARACTER:
		if not _data.character.get(key) is int:
			return false
	for channel: Variant in _data.channels:
		if not channel is Dictionary:
			return false
		for key: String in CHANNEL_KEYS:
			if not channel.get(key) is int:
				return false
		var count: int = -1
		for key: String in CHANNEL_ARRAYS:
			if not channel.get(key) is PackedInt64Array:
				return false
			count = channel[key].size() if count < 0 else count
			if channel[key].size() != count:
				return false
		if count < 2:
			return false
	for i in range(_data.channels.size()):
		if _data.channels[i].id != i:
			return false
	for body: Variant in _data.bodies:
		if not body is Dictionary or not body.get("cells") is PackedInt32Array or body.cells.is_empty():
			return false
		for key: String in BODY_KEYS:
			if not body.get(key) is int:
				return false
	for key: String in FRAME_ARRAYS:
		if not _data.river_frame.get(key) is PackedInt64Array or _data.river_frame[key].size() != RIVER_STATIONS:
			return false
	var n: int = LATTICE_SIZE * LATTICE_SIZE
	var lattice: Dictionary = _data.lattice
	return lattice.get("receiver") is PackedInt32Array and lattice.receiver.size() == n and lattice.get("terminal") is PackedByteArray and lattice.terminal.size() == n \
		and lattice.get("area_cells") is PackedInt32Array and lattice.area_cells.size() == n and lattice.get("catchment") is PackedInt32Array and lattice.catchment.size() == n


func validate() -> Dictionary:
	var reasons: Array[String] = []
	if not _schema_ok():
		reasons.append("ERR_HYDRO_SCHEMA")
		return {"is_valid": false, "reason_codes": reasons}
	var channels: Array = _data.channels
	var count: int = channels.size()
	# Major river: exactly one, a root, edge to edge on opposite region sides.
	var majors: Array = []
	for channel: Dictionary in channels:
		if channel.class == CLASS_MAJOR_RIVER:
			majors.append(channel)
	var major_ok: bool = majors.size() == 1
	if major_ok:
		var river: Dictionary = majors[0]
		var last: int = river.x_cm.size() - 1
		var x0: int = river.x_cm[0]
		var z0: int = river.z_cm[0]
		var x1: int = river.x_cm[last]
		var z1: int = river.z_cm[last]
		var opposite: bool = (x0 == 0 and x1 == DOMAIN_CM) or (x0 == DOMAIN_CM and x1 == 0) or (z0 == 0 and z1 == DOMAIN_CM) or (z0 == DOMAIN_CM and z1 == 0)
		major_ok = river.parent == -1 and river.outlet_kind == OUTLET_EDGE and opposite
	if not major_ok:
		reasons.append("ERR_HYDRO_MAJOR_RIVER")
	# Topology: valid parents, acyclic, mouths on parents, roots end at an edge or a closed body.
	var parent_ok := PackedByteArray()
	parent_ok.resize(count)
	var topology_ok: bool = true
	for channel: Dictionary in channels:
		var ok: bool
		if channel.parent == -1:
			ok = channel.outlet_kind == OUTLET_EDGE or (channel.outlet_kind == OUTLET_BODY and channel.outlet_id >= 0 and channel.outlet_id < _data.bodies.size() and _data.bodies[channel.outlet_id].kind == BODY_CLOSED)
		else:
			ok = channel.parent >= 0 and channel.parent < count and channel.parent != channel.id and channel.outlet_kind == OUTLET_CHANNEL and channel.outlet_id == channel.parent
			if ok:
				var steps: int = 0
				var cursor: int = channel.parent
				while cursor >= 0 and cursor < count and steps <= count:
					cursor = channels[cursor].parent
					steps += 1
				ok = steps <= count and cursor == -1
			if ok:
				var parent: Dictionary = channels[channel.parent]
				var length: int = parent.station_cm[parent.station_cm.size() - 1]
				ok = channel.mouth_station_cm >= 0 and channel.mouth_station_cm <= length
				if ok:
					var at: Dictionary = point_at_station(parent, channel.mouth_station_cm)
					var last: int = channel.x_cm.size() - 1
					ok = Vector2(at.x - channel.x_cm[last], at.z - channel.z_cm[last]).length() <= 2.0
		parent_ok[channel.id] = 1 if ok else 0
		topology_ok = topology_ok and ok
	if not topology_ok:
		reasons.append("ERR_HYDRO_TOPOLOGY")
	# Monotonic water: surface strictly decreasing downstream, bed below surface,
	# a mouth not below its parent's surface at the confluence.
	var monotonic_ok: bool = true
	for channel: Dictionary in channels:
		for k in range(channel.surface_cm.size()):
			monotonic_ok = monotonic_ok and channel.bed_cm[k] < channel.surface_cm[k]
			if k > 0:
				monotonic_ok = monotonic_ok and channel.surface_cm[k] < channel.surface_cm[k - 1]
		if channel.parent >= 0 and parent_ok[channel.id] != 0:
			var at: Dictionary = point_at_station(channels[channel.parent], channel.mouth_station_cm)
			monotonic_ok = monotonic_ok and channel.surface_cm[channel.surface_cm.size() - 1] >= at.surface - 1.0
	if not monotonic_ok:
		reasons.append("ERR_HYDRO_MONOTONIC")
	# Hierarchy: area and width grow downstream, a tributary is not larger
	# than its parent at the confluence, orders do not exceed the parent's,
	# and the major river carries more than any other channel.
	var hierarchy_ok: bool = true
	var major_area: int = 0
	if majors.size() == 1:
		major_area = majors[0].area_m2[0]
	for channel: Dictionary in channels:
		for k in range(1, channel.area_m2.size()):
			hierarchy_ok = hierarchy_ok and channel.area_m2[k] >= channel.area_m2[k - 1] and channel.width_cm[k] >= channel.width_cm[k - 1]
		hierarchy_ok = hierarchy_ok and channel.order >= 1 and channel.class >= CLASS_MAJOR_RIVER and channel.class <= CLASS_CREEK and channel.perennial in [0, 1]
		if channel.class != CLASS_MAJOR_RIVER and majors.size() == 1:
			hierarchy_ok = hierarchy_ok and channel.area_m2[channel.area_m2.size() - 1] < major_area
		if channel.parent >= 0 and parent_ok[channel.id] != 0:
			var parent: Dictionary = channels[channel.parent]
			var at: Dictionary = point_at_station(parent, channel.mouth_station_cm)
			hierarchy_ok = hierarchy_ok and channel.area_m2[channel.area_m2.size() - 1] <= at.area + 1.0 and (parent.class == CLASS_MAJOR_RIVER or channel.order <= parent.order)
	if not hierarchy_ok:
		reasons.append("ERR_HYDRO_HIERARCHY")
	# Bounds: inside the closed region square, class width ranges.
	var bounds_ok: bool = true
	for channel: Dictionary in channels:
		var widths: Vector2i = MAJOR_WIDTH_CM if channel.class == CLASS_MAJOR_RIVER else CHANNEL_WIDTH_CM
		for k in range(channel.x_cm.size()):
			bounds_ok = bounds_ok and channel.x_cm[k] >= 0 and channel.x_cm[k] <= DOMAIN_CM and channel.z_cm[k] >= 0 and channel.z_cm[k] <= DOMAIN_CM
			bounds_ok = bounds_ok and channel.width_cm[k] >= widths.x and channel.width_cm[k] <= widths.y and channel.area_m2[k] > 0
	for body: Dictionary in _data.bodies:
		for cell: int in body.cells:
			bounds_ok = bounds_ok and cell >= 0 and cell < LATTICE_SIZE * LATTICE_SIZE
	if not bounds_ok:
		reasons.append("ERR_HYDRO_BOUNDS")
	if not _geometry_ok():
		reasons.append("ERR_HYDRO_GEOMETRY")
	if not _drainage_ok():
		reasons.append("ERR_HYDRO_DRAINAGE")
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}


## Stations start at 0 and strictly increase (no degenerate segment); no two
## segments cross except a tributary's final vertex on its parent; no channel
## crosses itself.
func _geometry_ok() -> bool:
	var channels: Array = _data.channels
	const CELL: float = 12800.0 # 128 m buckets
	var buckets: Dictionary = {}
	var segments: Array = [] # [channel, k, a, b, parent if final segment else -2]
	for channel: Dictionary in channels:
		if channel.station_cm[0] != 0:
			return false
		var last: int = channel.x_cm.size() - 2
		for k in range(channel.x_cm.size() - 1):
			if channel.station_cm[k + 1] <= channel.station_cm[k]:
				return false
			var a := Vector2(channel.x_cm[k], channel.z_cm[k])
			var b := Vector2(channel.x_cm[k + 1], channel.z_cm[k + 1])
			var index: int = segments.size()
			segments.append([channel.id, k, a, b, channel.parent if k == last else -2])
			for bj in range(floori(minf(a.y, b.y) / CELL), floori(maxf(a.y, b.y) / CELL) + 1):
				for bi in range(floori(minf(a.x, b.x) / CELL), floori(maxf(a.x, b.x) / CELL) + 1):
					var key: int = bj * 64 + bi
					if not buckets.has(key):
						buckets[key] = PackedInt32Array()
					buckets[key].append(index)
	for key: int in buckets:
		var list: PackedInt32Array = buckets[key]
		for p in range(list.size()):
			for q in range(p + 1, list.size()):
				var s: Array = segments[list[p]]
				var t: Array = segments[list[q]]
				if s[0] == t[0] and absi(s[1] - t[1]) <= 1:
					continue
				# A final segment ends on its parent (the mouth lies on the parent
				# within the 2 cm quantisation checked under topology).
				if s[4] == t[0] or t[4] == s[0]:
					continue
				if _segments_cross(s[2], s[3], t[2], t[3]):
					return false
	return true


## Every lattice point ends at a terminal: the major river (a point inside
## its corridor), a region-edge point or a cell of a CLOSED body; receivers
## are 8-neighbours; no cycles.
func _drainage_ok() -> bool:
	var lattice: Dictionary = _data.lattice
	var n: int = LATTICE_SIZE * LATTICE_SIZE
	var closed_cells := PackedByteArray()
	closed_cells.resize(n)
	for body: Dictionary in _data.bodies:
		if body.kind == BODY_CLOSED:
			for cell: int in body.cells:
				if cell >= 0 and cell < n:
					closed_cells[cell] = 1
	var receiver: PackedInt32Array = lattice.receiver
	var terminal: PackedByteArray = lattice.terminal
	for c in range(n):
		var kind: int = terminal[c]
		var r: int = receiver[c]
		if (kind == TERMINAL_NONE) == (r < 0):
			return false
		if kind == TERMINAL_EDGE:
			var i: int = c % LATTICE_SIZE
			var j: int = c / LATTICE_SIZE
			if i != 0 and j != 0 and i != LATTICE_SIZE - 1 and j != LATTICE_SIZE - 1:
				return false
		elif kind == TERMINAL_CLOSED and closed_cells[c] == 0:
			return false
		elif kind == TERMINAL_RIVER and not _in_river_corridor(c):
			return false
		elif kind > TERMINAL_CLOSED:
			return false
		if r >= 0:
			if r >= n or absi(r % LATTICE_SIZE - c % LATTICE_SIZE) > 1 or absi(r / LATTICE_SIZE - c / LATTICE_SIZE) > 1 or r == c:
				return false
	# Acyclic: follow each chain, marking finished cells (0 new, 1 on path, 2 done).
	var state := PackedByteArray()
	state.resize(n)
	var path := PackedInt32Array()
	for start in range(n):
		if state[start] == 2:
			continue
		path.clear()
		var c: int = start
		while c >= 0 and state[c] == 0:
			state[c] = 1
			path.append(c)
			c = receiver[c]
		if c >= 0 and state[c] == 1:
			return false
		for p: int in path:
			state[p] = 2
	return true


## A lattice point lies inside the major river's outlet corridor (within
## RIVER_CORRIDOR_M of its centre line, plus 1 cm quantisation slack).
func _in_river_corridor(cell: int) -> bool:
	var river: Dictionary = {}
	for channel: Dictionary in _data.channels:
		if channel.class == CLASS_MAJOR_RIVER:
			river = channel
			break
	if river.is_empty():
		return false
	var p := Vector2((cell % LATTICE_SIZE) * LATTICE_STEP_M * 100.0, (cell / LATTICE_SIZE) * LATTICE_STEP_M * 100.0)
	var limit: float = RIVER_CORRIDOR_M * 100.0 + 1.0
	for k in range(river.x_cm.size() - 1):
		var a := Vector2(river.x_cm[k], river.z_cm[k])
		var b := Vector2(river.x_cm[k + 1], river.z_cm[k + 1])
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0) if ab.length_squared() > 0.0 else 0.0
		if p.distance_to(a + ab * t) <= limit:
			return true
	return false
