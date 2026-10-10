class_name RoadSynthesisPlan
extends RefCounted

## Immutable R6 road synthesis result of one region (`slow_cycle.road_synthesis_plan/1`,
## ExecPlan §4). Produced only by RoadSynthesizer. Every R5 edge, junction and
## crossing has a record, valid or diagnosed; failed pieces are never dropped
## and never exported. Accessors return deep copies; get_path() exports a
## fresh RoadPathData each call (never shared).
##
## Coordinates: region-local metres (world = int64 origin + local; origin_y = 0).
## Pieces: "edge:<id>" (edge interior, canonical direction a -> b, port to port)
## and "move:<node>:<a>-<b>" (junction connector, lowest edge id first). The
## canonical float64 design arrays are stored; RoadPathData (float32) is
## derived at export with RoadMath frames:
##   points       local (x, y, z); slopes in degrees; curvature |k| (1/m);
##   widths       full riding width (m); cumulative distance = 3D chords from 0;
##   contact      GROUNDED; macro offsets 0; branch / fork / parent ids -1
##                (regional ids live in the envelope, not in legacy fields);
##   segment type conservative compatibility label from measured curvature;
##   sight        measured forward sight distance for the travel direction.
## Reversal (§4): order reversed, tangents / signed curvature / grade / bank
## negated, distances rebuilt, sight forward <-> backward; physical normals
## unchanged. Two reversals reproduce the canonical piece.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const PathData = preload("res://scripts/world/road_path_data.gd")
const RoadMath = preload("res://scripts/world/road_math.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const DESIGN_KEYS: Array[String] = ["s", "x", "y", "z", "tx", "tz", "grade", "k", "dk", "vk", "bank", "width", "nat_c", "nat_l", "nat_r", "fill_l", "fill_r", "tie_l", "tie_r", "sight_forward", "sight_backward"]

var _data: Dictionary
var _diagnostics: Dictionary
var _signature: String = ""


func _init(data: Dictionary = {}, diagnostics: Dictionary = {}) -> void:
	_data = data.duplicate(true)
	_diagnostics = diagnostics.duplicate(true)
	_signature = _sha256(canonical_bytes())


# --- Accessors (deep copies) ---

func get_header() -> Dictionary:
	var header: Dictionary = {}
	for key: String in _data:
		if not key in ["edges", "junctions", "crossings", "pieces", "intents"]:
			header[key] = _data[key]
	return header.duplicate(true)


func get_status() -> String:
	return _data.get("status", "")


func get_origin() -> Dictionary:
	return {"origin_x_m": _data.origin_x_m, "origin_y_m": 0, "origin_z_m": _data.origin_z_m}


func get_edge_count() -> int:
	return _data.edges.size()


func get_edge(edge_id: int) -> Dictionary:
	for record: Dictionary in _data.edges:
		if record.edge_id == edge_id:
			return record.duplicate(true)
	return {}


func get_junction_count() -> int:
	return _data.junctions.size()


func get_junction_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for record: Dictionary in _data.junctions:
		ids.append(record.node_id)
	return ids


func get_junction(node_id: int) -> Dictionary:
	for record: Dictionary in _data.junctions:
		if record.node_id == node_id:
			return record.duplicate(true)
	return {}


func get_crossing_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for record: Dictionary in _data.crossings:
		ids.append(record.crossing_id)
	return ids


func get_crossing(crossing_id: String) -> Dictionary:
	for record: Dictionary in _data.crossings:
		if record.crossing_id == crossing_id:
			return record.duplicate(true)
	return {}


func get_piece_ids() -> PackedStringArray:
	var ids := PackedStringArray(_data.pieces.keys())
	ids.sort()
	return ids


## Piece record without its design arrays (identity, owner, status).
func get_piece_info(piece_id: String) -> Dictionary:
	if not _data.pieces.has(piece_id):
		return {}
	var info: Dictionary = {}
	for key: String in _data.pieces[piece_id]:
		if key != "design":
			info[key] = _data.pieces[piece_id][key]
	return info.duplicate(true)


## Canonical float64 design arrays of a valid piece (copy).
func get_design(piece_id: String) -> Dictionary:
	if not _data.pieces.has(piece_id):
		return {}
	return _data.pieces[piece_id].design.duplicate(true)


func get_intent_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for record: Dictionary in _data.intents:
		ids.append(record.intent_id)
	return ids


func get_intent(intent_id: String) -> Dictionary:
	for record: Dictionary in _data.intents:
		if record.intent_id == intent_id:
			return record.duplicate(true)
	return {}


func get_diagnostics() -> Dictionary:
	return _diagnostics.duplicate(true)


func get_data() -> Dictionary:
	return _data.duplicate(true)


## {piece_id, origin_x_m, origin_y_m, origin_z_m, path: RoadPathData, policy_id,
## direction} or {} for an unknown / failed piece.
func get_path(piece_id: String, reversed: bool = false) -> Dictionary:
	if not _data.pieces.has(piece_id):
		return {}
	var path: RefCounted = export_path(_data.pieces[piece_id].design, reversed)
	return {"piece_id": piece_id, "origin_x_m": _data.origin_x_m, "origin_y_m": 0, "origin_z_m": _data.origin_z_m, "path": path,
		"policy_id": _data.policy_id, "direction": "reversed" if reversed else "canonical"}


# --- Export ---

## Design arrays, optionally reversed (float64, physical meaning preserved).
static func oriented(design: Dictionary, reversed: bool) -> Dictionary:
	if not reversed:
		return design.duplicate(true)
	var out: Dictionary = {}
	var n: int = design.s.size()
	var total: float = design.s[n - 1]
	for key: String in DESIGN_KEYS:
		var source: PackedFloat64Array = design[key]
		var a := PackedFloat64Array()
		a.resize(n)
		for i in range(n):
			a[i] = source[n - 1 - i]
		out[key] = a
	for i in range(n):
		out.s[i] = total - design.s[n - 1 - i]
		out.tx[i] = -out.tx[i]
		out.tz[i] = -out.tz[i]
		out.grade[i] = -out.grade[i]
		out.k[i] = -out.k[i]
		out.bank[i] = -out.bank[i]
	# dk/ds: d(-k)/d(-s) = dk/ds; vertical curvature d2y/ds2 is unchanged.
	var swap: Array = [["nat_l", "nat_r"], ["fill_l", "fill_r"], ["tie_l", "tie_r"], ["sight_forward", "sight_backward"]]
	for pair: Array in swap:
		var t: PackedFloat64Array = out[pair[0]]
		out[pair[0]] = out[pair[1]]
		out[pair[1]] = t
	var support := PackedByteArray()
	support.resize(n)
	for i in range(n):
		support[i] = design.support[n - 1 - i]
	out["support"] = support
	return out


static func export_path(design: Dictionary, reversed: bool) -> RefCounted:
	var d: Dictionary = oriented(design, reversed)
	var path: RefCounted = PathData.new()
	path.branch_id = PathData.UNASSIGNED_BRANCH_ID
	path.fork_node_id = -1
	path.parent_branch_id = PathData.UNASSIGNED_BRANCH_ID
	var n: int = d.s.size()
	var types: PackedInt32Array = segment_types(d.s, d.k)
	var distance: float = 0.0
	for i in range(n):
		var tangent := Vector3(d.tx[i], d.grade[i], d.tz[i]).normalized()
		var normal: Vector3 = RoadMath.compute_ortho_normal(tangent, d.bank[i])
		path.points.append(Vector3(d.x[i], d.y[i], d.z[i]))
		path.tangents.append(tangent)
		path.normals.append(normal)
		path.binormals.append(tangent.cross(normal).normalized())
		if i > 0:
			# 3D chord accumulated in float64 from the float64 design points.
			distance += sqrt((d.x[i] - d.x[i - 1]) ** 2 + (d.y[i] - d.y[i - 1]) ** 2 + (d.z[i] - d.z[i - 1]) ** 2)
		path.cumulative_distances.append(distance)
		path.slopes.append(rad_to_deg(atan(d.grade[i])))
		path.curvatures.append(absf(d.k[i]))
		path.segment_types.append(types[i])
		path.surface_contact_states.append(Airborne.SurfaceContactMode.GROUNDED)
		path.banking_angles.append(d.bank[i])
		path.sight_distances.append(d.sight_forward[i])
		path.road_widths.append(d.width[i])
		path.macro_elevation_offsets.append(0.0)
	return path


## Conservative legacy labels from measured signed curvature: STRAIGHT below
## 1/400 m^-1, SWITCHBACK inside a lobe turning >= 100 deg, otherwise entry /
## full / exit thirds of the lobe in travel order.
static func segment_types(s: PackedFloat64Array, k: PackedFloat64Array) -> PackedInt32Array:
	var n: int = s.size()
	var types := PackedInt32Array()
	types.resize(n)
	types.fill(PathData.SegmentType.STRAIGHT)
	var lobes: Array = RMath.turn_lobes(s, k, 1.0 / 400.0, 8.0)
	var i: int = 0
	for lobe: Dictionary in lobes:
		var switchback: bool = absf(rad_to_deg(lobe.turn)) >= 100.0
		var length: float = maxf(lobe.s1 - lobe.s0, 1e-6)
		while i < n and s[i] < lobe.s0:
			i += 1
		while i < n and s[i] <= lobe.s1:
			var f: float = (s[i] - lobe.s0) / length
			if switchback:
				types[i] = PathData.SegmentType.SWITCHBACK
			elif f < 1.0 / 3.0:
				types[i] = PathData.SegmentType.GENTLE_ENTRY
			elif f > 2.0 / 3.0:
				types[i] = PathData.SegmentType.GENTLE_EXIT
			else:
				types[i] = PathData.SegmentType.FULL_CURVE
			i += 1
	return types


## Bytes of every exported RoadPathData array (float32 / int32 / byte) in a
## fixed order: the export identity of a piece.
static func export_bytes(path: RefCounted) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	buffer.put_32(path.points.size())
	for key: String in ["points", "tangents", "normals", "binormals"]:
		for v: Vector3 in path.get(key):
			buffer.put_float(v.x)
			buffer.put_float(v.y)
			buffer.put_float(v.z)
	for key: String in ["cumulative_distances", "slopes", "curvatures", "banking_angles", "sight_distances", "road_widths", "macro_elevation_offsets"]:
		for v: float in path.get(key):
			buffer.put_float(v)
	for v: int in path.segment_types:
		buffer.put_32(v)
	buffer.put_data(path.surface_contact_states)
	buffer.put_32(path.branch_id)
	buffer.put_32(path.fork_node_id)
	buffer.put_32(path.parent_branch_id)
	return buffer.data_array


# --- Canonical encoding and signature ---

## Typed, length-prefixed little-endian encoding with sorted dictionary keys.
## NaN / Inf are rejected (the producer validates before construction).
static func encode(value: Variant, buffer: StreamPeerBuffer) -> bool:
	match typeof(value):
		TYPE_NIL:
			buffer.put_u8(78)
		TYPE_BOOL:
			buffer.put_u8(66)
			buffer.put_u8(1 if value else 0)
		TYPE_INT:
			buffer.put_u8(73)
			buffer.put_64(value)
		TYPE_FLOAT:
			if not is_finite(value):
				return false
			buffer.put_u8(70)
			buffer.put_double(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var bytes: PackedByteArray = str(value).to_utf8_buffer()
			buffer.put_u8(83)
			buffer.put_32(bytes.size())
			buffer.put_data(bytes)
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			buffer.put_u8(68)
			buffer.put_32(keys.size())
			for key: Variant in keys:
				if not encode(str(key), buffer) or not encode(value[key], buffer):
					return false
		TYPE_ARRAY:
			buffer.put_u8(65)
			buffer.put_32(value.size())
			for item: Variant in value:
				if not encode(item, buffer):
					return false
		TYPE_PACKED_FLOAT64_ARRAY:
			buffer.put_u8(102)
			buffer.put_32(value.size())
			for v: float in value:
				if not is_finite(v):
					return false
				buffer.put_double(v)
		TYPE_PACKED_FLOAT32_ARRAY:
			buffer.put_u8(103)
			buffer.put_32(value.size())
			for v: float in value:
				if not is_finite(v):
					return false
				buffer.put_float(v)
		TYPE_PACKED_INT32_ARRAY:
			buffer.put_u8(105)
			buffer.put_32(value.size())
			for v: int in value:
				buffer.put_32(v)
		TYPE_PACKED_INT64_ARRAY:
			buffer.put_u8(108)
			buffer.put_32(value.size())
			for v: int in value:
				buffer.put_64(v)
		TYPE_PACKED_BYTE_ARRAY:
			buffer.put_u8(98)
			buffer.put_32(value.size())
			buffer.put_data(value)
		TYPE_PACKED_STRING_ARRAY:
			buffer.put_u8(115)
			buffer.put_32(value.size())
			for v: String in value:
				encode(v, buffer)
		_:
			return false
	return true


func canonical_bytes() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.big_endian = false
	var header: PackedByteArray = Policy.PLAN_SCHEMA.to_utf8_buffer()
	buffer.put_data(header)
	if not encode(_data, buffer):
		return PackedByteArray()
	return buffer.data_array


static func _sha256(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## SHA-256 of the canonical bytes (same engine / platform scope; excludes
## timings and other diagnostics). Empty if the data cannot be encoded.
func signature() -> String:
	return _signature


## Structural self-check of the envelope (schema, keys, finite encoding).
func validate() -> Dictionary:
	var reasons: Array[String] = []
	for key: String in ["schema", "policy_id", "policy_digest", "algorithm", "effective_seed", "origin_x_m", "origin_z_m", "origin_y_m", "region_signature",
			"graph_signature", "hydrology_signature", "rideability_signature", "status", "edges", "junctions", "crossings", "pieces", "intents"]:
		if not _data.has(key):
			reasons.append("ERR_R6_SCHEMA")
			break
	if reasons.is_empty() and _data.schema != Policy.PLAN_SCHEMA:
		reasons.append("ERR_R6_SCHEMA")
	if _signature.is_empty() or canonical_bytes().is_empty():
		reasons.append("ERR_R6_NONFINITE")
	if reasons.is_empty():
		# One owner per piece: one interior per edge, one connector per node pair.
		var owners: Dictionary = {}
		for piece_id: String in _data.pieces:
			var piece: Dictionary = _data.pieces[piece_id]
			var key: String = ("edge:%d" % piece.owner.edge_id) if piece.kind == "EDGE" else ("move:%d:%s" % [piece.owner.node_id, str(piece.owner.edges)])
			if owners.has(key) or (piece.kind == "EDGE" and piece_id != "edge:%d" % piece.owner.edge_id):
				reasons.append("ERR_R6_DUPLICATE_PIECE")
				break
			owners[key] = piece_id
		for record: Dictionary in _data.edges:
			if not record.piece_id.is_empty() and not _data.pieces.has(record.piece_id):
				reasons.append("ERR_R6_PATH_STRUCTURE")
				break
	if reasons.is_empty():
		for piece_id: String in _data.pieces:
			var design: Dictionary = _data.pieces[piece_id].design
			var n: int = design.s.size()
			for key: String in DESIGN_KEYS:
				if not design.has(key) or design[key].size() != n:
					reasons.append("ERR_R6_PATH_STRUCTURE")
					break
			if not reasons.is_empty():
				break
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}
