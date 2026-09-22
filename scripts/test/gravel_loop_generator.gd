class_name GravelLoopGenerator
extends Node3D

## Gravel Training Loop (~1220m) — Dedicated Zen Flow training circuit.
## Designed for natural riding rhythm: steady muscular launch -> long sustained coasting ->
## sweeping high-speed corners (R=60-70m) with zero tire scrub -> gentle ascents and descents.
## Guarantees exact C1 continuity, zero seam defects, Layer 2/Layer 3/Layer 5 physics,
## full duck-typed compatibility with DebugHUD and BicycleController recovery.

const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")

const TOTAL_TRACK_LENGTH: float = 1220.43288
const SAMPLE_DS: float = 2.0
const SAMPLES_COUNT: int = 611 ## 610 segments * 2.0m ≈ 1220.43m (sample 610 wraps exactly to 0)
const CHUNK_LENGTH: float = 50.0
const CHUNKS_COUNT: int = 25 ## 25 chunks * 50m = 1250m (covers 1220.43m)
const ROAD_HALF_WIDTH: float = 2.0 ## 4.0m road width
const TERRAIN_WIDTH: float = 20.0 ## 20m roadside meadow strip

@export var player: Node3D
@export var world_seed: int = 4004

var road_path: RefCounted = RoadPathDataClass.new()

var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}
var sections: Array[Dictionary] = []
var chunks: Array[Node3D] = []

enum SegType { LINE, ARC }

class TrackSegment:
	var type: SegType
	var s_start: float
	var length: float
	var p_start: Vector2
	var dir_start: Vector2
	var p_end: Vector2
	var dir_end: Vector2
	var center: Vector2
	var radius: float
	var start_angle: float
	var delta_angle: float

	func eval_2d(s: float) -> Dictionary:
		var u: float = clampf(s - s_start, 0.0, length)
		if type == SegType.LINE:
			var p: Vector2 = p_start + dir_start * u
			return {"pos": p, "tang": dir_start, "curv": 0.0}
		else:
			var ang: float = start_angle + delta_angle * (u / length)
			var p: Vector2 = Vector2(center.x + radius * cos(ang), center.y + radius * sin(ang))
			var sign_turn: float = signf(delta_angle)
			var tang: Vector2 = Vector2(-sin(ang), cos(ang)) * sign_turn
			return {"pos": p, "tang": tang, "curv": 1.0 / radius}

class ElevKey:
	var s: float
	var y: float
	var slope_deg: float
	func _init(_s: float, _y: float, _deg: float) -> void:
		s = _s
		y = _y
		slope_deg = _deg

var segments: Array[TrackSegment] = []
var elev_keys: Array[ElevKey] = []

func _ready() -> void:
	_init_shared_resources()
	_define_sections()
	_build_path_data()
	_build_chunks()
	_build_signage()

func _init_shared_resources() -> void:
	var road_mat: Material = load("res://assets/materials/gravel_road.tres")
	var grass_mat: Material = load("res://assets/materials/roadside_grass.tres")
	shared_materials["road"] = road_mat
	shared_materials["grass"] = grass_mat

	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = world_seed
	terrain_noise.frequency = 0.04
	shared_materials["noise"] = terrain_noise

	shared_meshes["pine"] = _build_pine_mesh()
	shared_meshes["birch"] = _build_birch_mesh()
	shared_meshes["grass"] = _build_grass_mesh()

func _define_sections() -> void:
	sections = [
		{
			"code": "L1", "name": "Start & Launch", "desc": "Baseline Smooth Cruise Acceleration",
			"s0": 0.0, "s1": 100.0,
			"target": "FLAT | CRUISE 25 km/h",
			"test_id": "4L_L1_LAUNCH",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [0.0, 26.0],
			"expected_lean_range": [-2.0, 2.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L2", "name": "Pine Ridge Ascent", "desc": "Gentle Forest Climb +2.2°",
			"s0": 100.0, "s1": 240.0,
			"target": "CLIMB +2.2° | STEADY CADENCE",
			"test_id": "4L_L2_CLIMB",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 2.2],
			"expected_speed_range": [18.0, 24.0],
			"expected_lean_range": [-2.0, 2.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L3", "name": "North Meadow Sweeper", "desc": "Open Horizon Apex Flow R=70m",
			"s0": 240.0, "s1": 349.96,
			"target": "SWEEPER R=70m | ZERO SCRUB",
			"test_id": "4L_L3_SWEEPER",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [22.0, 28.0],
			"expected_lean_range": [-10.0, -4.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L4", "name": "Meadow Glide", "desc": "Free Coasting & Freewheel Chime",
			"s0": 349.96, "s1": 429.96,
			"target": "MEADOW | FREE COAST",
			"test_id": "4L_L4_GLIDE",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [20.0, 26.0],
			"expected_lean_range": [-2.0, 2.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L5", "name": "Forest Edge Chicane", "desc": "Gentle Roll Reversal R=65m ±18°",
			"s0": 429.96, "s1": 511.64,
			"target": "CHICANE R=65m | ROLL FLOW",
			"test_id": "4L_L5_CHICANE",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [22.0, 28.0],
			"expected_lean_range": [-8.0, 8.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L6", "name": "Crest Sweeper", "desc": "Gentle Crest Transition in Curve R=65m",
			"s0": 511.64, "s1": 613.74,
			"target": "CREST R=65m | UNWEIGHTING",
			"test_id": "4L_L6_CREST",
			"expected_surface": "ROAD",
			"expected_slope_range": [-0.5, 1.5],
			"expected_speed_range": [24.0, 30.0],
			"expected_lean_range": [-10.0, -4.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L7", "name": "Birch Valley Descent", "desc": "Sustained -2.5° Gravitational Glide",
			"s0": 613.74, "s1": 763.74,
			"target": "DESCENT -2.5° | SPEED 32 km/h",
			"test_id": "4L_L7_DESCENT",
			"expected_surface": "ROAD",
			"expected_slope_range": [-2.5, 0.0],
			"expected_speed_range": [26.0, 35.0],
			"expected_lean_range": [-3.0, 3.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L8", "name": "Lakeside Rough Strip", "desc": "Layer 5 Textured Gravel Washboard",
			"s0": 763.74, "s1": 833.74,
			"target": "ROUGH GRAVEL | SUBTLE CHATTER",
			"test_id": "4L_L8_ROUGH",
			"expected_surface": "ROUGH_GRAVEL",
			"expected_slope_range": [-1.0, 0.0],
			"expected_speed_range": [24.0, 32.0],
			"expected_lean_range": [-3.0, 3.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L9", "name": "South Sweeper & Turn", "desc": "High Speed Corner to Finish Approach R=65m",
			"s0": 833.74, "s1": 955.84,
			"target": "SOUTH TURN R=65m | LEAN 8°",
			"test_id": "4L_L9_SOUTH_TURN",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [22.0, 32.0],
			"expected_lean_range": [-10.0, -4.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L10", "name": "Shaded West Run", "desc": "Sprint Straightaway into Tree Shadows",
			"s0": 955.84, "s1": 1126.18,
			"target": "WEST RUN | OPTIONAL SPRINT",
			"test_id": "4L_L10_WEST_RUN",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.8],
			"expected_speed_range": [20.0, 42.0],
			"expected_lean_range": [-2.0, 2.0],
			"expected_ground_state": "GROUNDED"
		},
		{
			"code": "L11", "name": "Return Sweeper & Seam", "desc": "High Speed Finish Curve into Seam R=60m",
			"s0": 1126.18, "s1": 1220.43,
			"target": "RETURN R=60m | APEX & SEAM",
			"test_id": "4L_L11_RETURN",
			"expected_surface": "ROAD",
			"expected_slope_range": [0.0, 0.0],
			"expected_speed_range": [22.0, 34.0],
			"expected_lean_range": [-10.0, -4.0],
			"expected_ground_state": "GROUNDED"
		}
	]

func get_section_at_distance(dist_m: float) -> Dictionary:
	var wrapped_s: float = fposmod(dist_m, TOTAL_TRACK_LENGTH)
	for sec in sections:
		if wrapped_s >= sec.s0 and wrapped_s < sec.s1:
			return sec
	return sections[0]

func _add_line(cur_pos: Vector2, cur_dir: Vector2, cur_s: float, length: float) -> Array:
	var seg := TrackSegment.new()
	seg.type = SegType.LINE
	seg.s_start = cur_s
	seg.length = length
	seg.p_start = cur_pos
	seg.dir_start = cur_dir
	seg.p_end = cur_pos + cur_dir * length
	seg.dir_end = cur_dir
	segments.append(seg)
	return [seg.p_end, seg.dir_end, cur_s + length]

func _add_arc(cur_pos: Vector2, cur_dir: Vector2, cur_s: float, radius: float, turn_deg: float) -> Array:
	var seg := TrackSegment.new()
	seg.type = SegType.ARC
	seg.s_start = cur_s
	var delta_rad: float = deg_to_rad(turn_deg)
	seg.radius = radius
	seg.delta_angle = delta_rad
	seg.length = radius * absf(delta_rad)
	seg.p_start = cur_pos
	seg.dir_start = cur_dir

	var normal_right: Vector2 = Vector2(-cur_dir.y, cur_dir.x)
	var center_dir: Vector2 = normal_right if turn_deg > 0 else -normal_right
	seg.center = cur_pos + center_dir * radius

	var v0: Vector2 = cur_pos - seg.center
	seg.start_angle = atan2(v0.y, v0.x)
	var end_angle: float = seg.start_angle + delta_rad
	seg.p_end = Vector2(seg.center.x + radius * cos(end_angle), seg.center.y + radius * sin(end_angle))
	var sign_turn: float = signf(delta_rad)
	seg.dir_end = Vector2(-sin(end_angle), cos(end_angle)) * sign_turn

	segments.append(seg)
	return [seg.p_end, seg.dir_end, cur_s + seg.length]

func _add_symmetric_chicane(cur_pos: Vector2, cur_dir: Vector2, cur_s: float, radius: float, swing_deg: float, reps: int = 1) -> Array:
	var p: Vector2 = cur_pos
	var d: Vector2 = cur_dir
	var s: float = cur_s
	for i in range(reps):
		var res: Array = _add_arc(p, d, s, radius, swing_deg)
		p = res[0]; d = res[1]; s = res[2]
		res = _add_arc(p, d, s, radius, -2.0 * swing_deg)
		p = res[0]; d = res[1]; s = res[2]
		res = _add_arc(p, d, s, radius, swing_deg)
		p = res[0]; d = res[1]; s = res[2]
	return [p, d, s]

func _build_path_data() -> void:
	segments.clear()
	var cur_pos := Vector2.ZERO
	var cur_dir := Vector2(0, -1) # North
	var cur_s: float = 0.0

	# L1: Launch Straightaway (North, 100m)
	var r: Array = _add_line(cur_pos, cur_dir, cur_s, 100.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L2: Pine Ridge Ascent (North, 140m)
	r = _add_line(cur_pos, cur_dir, cur_s, 140.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 1: East Turn R=70m 90° right (109.96m)
	r = _add_arc(cur_pos, cur_dir, cur_s, 70.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L4: Meadow Glide (East, 80m)
	r = _add_line(cur_pos, cur_dir, cur_s, 80.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L5: Forest Edge Chicane R=65m ±18° on East (81.68m)
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 65.0, 18.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 2: South Turn R=65m 90° right (102.10m)
	r = _add_arc(cur_pos, cur_dir, cur_s, 65.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L7: Birch Valley Descent (South, 150m)
	r = _add_line(cur_pos, cur_dir, cur_s, 150.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L8: Lakeside Rough Strip (South, 70m)
	r = _add_line(cur_pos, cur_dir, cur_s, 70.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# South approach to West corner (rem_Y = 20.0m to guarantee exact R_final alignment)
	var R_final: float = 60.0
	var R_corner_west: float = 65.0
	var target_Y: float = R_final - R_corner_west # -5.0m
	var rem_Y: float = target_Y - cur_pos.y
	r = _add_line(cur_pos, cur_dir, cur_s, rem_Y)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 3: West Turn R=65m 90° right (102.10m)
	r = _add_arc(cur_pos, cur_dir, cur_s, R_corner_west, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L10: West Run approach to X = R_final (170.34m)
	var rem_X: float = cur_pos.x - R_final
	r = _add_line(cur_pos, cur_dir, cur_s, rem_X)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# L11: Return Sweeper Arc R=60m 90° right straight into (0, 0)! (94.25m)
	r = _add_arc(cur_pos, cur_dir, cur_s, R_final, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	_setup_elevation()

	# Sample analytical geometry into road_path
	road_path.points.clear()
	road_path.tangents.clear()
	road_path.normals.clear()
	road_path.binormals.clear()
	road_path.cumulative_distances.clear()
	road_path.slopes.clear()
	road_path.curvatures.clear()
	road_path.segment_types.clear()

	var seg_idx: int = 0
	for i in range(SAMPLES_COUNT):
		var s: float = float(i) * SAMPLE_DS
		if i == SAMPLES_COUNT - 1:
			s = TOTAL_TRACK_LENGTH

		while seg_idx < segments.size() - 1 and s > segments[seg_idx].s_start + segments[seg_idx].length:
			seg_idx += 1
		var seg: TrackSegment = segments[seg_idx]
		var s2d: Dictionary = seg.eval_2d(s)
		var p2d: Vector2 = s2d.pos
		var t2d: Vector2 = s2d.tang
		var kappa: float = s2d.curv

		var elev: Dictionary = _eval_elevation(s)
		var y: float = elev.y + elev.bump
		var slope_deg: float = elev.slope_deg
		var slope_rad: float = deg_to_rad(slope_deg)

		var p3d := Vector3(p2d.x, y, p2d.y)
		var t3d := Vector3(t2d.x * cos(slope_rad), sin(slope_rad), t2d.y * cos(slope_rad)).normalized()

		# Mathematical loop seam closure
		if i == SAMPLES_COUNT - 1:
			p3d = road_path.points[0]
			t3d = road_path.tangents[0]
			slope_deg = road_path.slopes[0]

		var norm_tangent: Vector3 = t3d
		var horiz_right := Vector3(-t2d.y, 0.0, t2d.x).normalized()
		var norm_normal: Vector3 = horiz_right.cross(norm_tangent).normalized()
		var binorm: Vector3 = norm_tangent.cross(norm_normal).normalized()

		var dist: float = 0.0
		if not road_path.cumulative_distances.is_empty():
			dist = road_path.cumulative_distances[-1] + road_path.points[-1].distance_to(p3d)

		# Segment Type assignment
		var seg_type: int = RoadPathDataClass.SegmentType.STRAIGHT
		if s >= 240.0 and s <= 430.0:
			seg_type = RoadPathDataClass.SegmentType.MEADOW # Open sunny meadow
		elif s >= 613.74 and s <= 763.74:
			seg_type = RoadPathDataClass.SegmentType.DESCENT # Birch valley descent
		elif s >= 763.74 and s <= 833.74:
			seg_type = RoadPathDataClass.SegmentType.ROUGH_GRAVEL # Lakeside washboard

		road_path.points.append(p3d)
		road_path.tangents.append(norm_tangent)
		road_path.normals.append(norm_normal)
		road_path.binormals.append(binorm)
		road_path.cumulative_distances.append(dist)
		road_path.slopes.append(slope_deg)
		road_path.curvatures.append(kappa)
		road_path.segment_types.append(seg_type)

func _setup_elevation() -> void:
	elev_keys.clear()
	# L1: Launch flat
	elev_keys.append(ElevKey.new(0.0, 0.0, 0.0))
	elev_keys.append(ElevKey.new(100.0, 0.0, 0.0))

	# L2: Pine Ridge Ascent +2.2°
	elev_keys.append(ElevKey.new(130.0, 0.65, 2.2))
	elev_keys.append(ElevKey.new(210.0, 3.72, 2.2))
	elev_keys.append(ElevKey.new(240.0, 4.30, 0.0))

	# L3 - L5: High Sunny Plateau (Flat)
	elev_keys.append(ElevKey.new(511.64, 4.30, 0.0))

	# L6: Gentle Crest Transition +1.5°
	elev_keys.append(ElevKey.new(562.64, 4.80, 1.5))
	elev_keys.append(ElevKey.new(613.74, 4.80, 0.0))

	# L7: Birch Valley Descent -2.5°
	elev_keys.append(ElevKey.new(643.74, 4.15, -2.5))
	elev_keys.append(ElevKey.new(733.74, 0.22, -2.5))
	elev_keys.append(ElevKey.new(763.74, -0.45, 0.0))

	# L8 - L9: Valley floor
	elev_keys.append(ElevKey.new(833.74, -0.45, 0.0))
	elev_keys.append(ElevKey.new(955.84, -0.45, 0.0))

	# L10: Gentle return climb +0.8° back to 0.0m
	elev_keys.append(ElevKey.new(1020.00, -0.10, 0.8))
	elev_keys.append(ElevKey.new(1100.00, 0.0, 0.0))
	elev_keys.append(ElevKey.new(TOTAL_TRACK_LENGTH, 0.0, 0.0))

func _eval_elevation(s: float) -> Dictionary:
	if elev_keys.is_empty():
		return {"y": 0.0, "slope_deg": 0.0, "bump": 0.0}

	var k_idx: int = 0
	for k in range(elev_keys.size() - 1):
		if s >= elev_keys[k].s and s <= elev_keys[k+1].s:
			k_idx = k
			break
	if s >= elev_keys[elev_keys.size() - 1].s:
		var last: ElevKey = elev_keys[elev_keys.size() - 1]
		return {"y": last.y, "slope_deg": last.slope_deg, "bump": 0.0}

	var k0: ElevKey = elev_keys[k_idx]
	var k1: ElevKey = elev_keys[k_idx + 1]
	var ds_k: float = k1.s - k0.s
	if ds_k <= 0.0001:
		return {"y": k0.y, "slope_deg": k0.slope_deg, "bump": 0.0}

	var t: float = (s - k0.s) / ds_k
	var t2: float = t * t
	var t3: float = t2 * t

	var m0: float = tan(deg_to_rad(k0.slope_deg)) * ds_k
	var m1: float = tan(deg_to_rad(k1.slope_deg)) * ds_k

	var h00: float = 2.0 * t3 - 3.0 * t2 + 1.0
	var h10: float = t3 - 2.0 * t2 + t
	var h01: float = -2.0 * t3 + 3.0 * t2
	var h11: float = t3 - t2

	var y: float = h00 * k0.y + h10 * m0 + h01 * k1.y + h11 * m1

	var dh00: float = 6.0 * t2 - 6.0 * t
	var dh10: float = 3.0 * t2 - 4.0 * t + 1.0
	var dh01: float = -6.0 * t2 + 6.0 * t
	var dh11: float = 3.0 * t2 - 2.0 * t

	var dyds: float = (dh00 * k0.y + dh10 * m0 + dh01 * k1.y + dh11 * m1) / ds_k
	var slope_deg: float = rad_to_deg(atan(dyds))

	# Subtle micro-bumps on rough gravel section L8 (763.74 .. 833.74)
	var bump: float = 0.0
	if s >= 763.74 and s <= 833.74:
		bump = 0.025 * sin(2.0 * PI * s / 2.5)

	return {"y": y, "slope_deg": slope_deg, "bump": bump}

func _build_chunks() -> void:
	var noise: FastNoiseLite = shared_materials.get("noise")
	var foliage_spawner = ChunkFoliageClass.new()
	var samples_per_chunk: int = 25 ## 25 samples * 2.0m = 50.0m

	for c in range(CHUNKS_COUNT):
		var s_idx: int = c * samples_per_chunk
		var e_idx: int = s_idx + samples_per_chunk
		if e_idx >= road_path.size():
			e_idx = road_path.size() - 1
		if s_idx >= road_path.size():
			break

		var chunk_node := Node3D.new()
		chunk_node.name = "LoopChunk_%d" % c
		chunk_node.set("chunk_id", c)
		add_child(chunk_node)
		chunks.append(chunk_node)

		var chunk_center_s: float = (road_path.cumulative_distances[s_idx] + road_path.cumulative_distances[e_idx]) * 0.5
		var is_rough_road: bool = (chunk_center_s >= 763.74 and chunk_center_s <= 833.74)

		# 1. Build Road Mesh
		var road_mat: Material = shared_materials.get("road")
		var road_col_layer: int = (2 | 16) if is_rough_road else 2
		_build_road_mesh_for_chunk(chunk_node, s_idx, e_idx, road_mat, road_col_layer, is_rough_road)

		# 2. Build Terrain Strip
		_build_terrain_mesh_for_chunk(chunk_node, s_idx, e_idx, shared_materials.get("grass"), noise)

		# 3. Populate Foliage
		foliage_spawner.populate_chunk(chunk_node, road_path, s_idx, e_idx, shared_meshes, noise)

func _build_road_mesh_for_chunk(parent: Node3D, s_idx: int, e_idx: int, mat: Material, col_layer: int, is_rough: bool = false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if mat:
		st.set_material(mat)

	var num_pts: int = e_idx - s_idx + 1
	for i in range(num_pts):
		var idx: int = s_idx + i
		var pt: Vector3 = road_path.points[idx]
		var binorm: Vector3 = road_path.binormals[idx]
		var norm: Vector3 = road_path.normals[idx]
		var dist: float = road_path.cumulative_distances[idx]

		var v_left: Vector3 = pt - binorm * ROAD_HALF_WIDTH
		var v_right: Vector3 = pt + binorm * ROAD_HALF_WIDTH
		var v_coord: float = dist * 0.25

		st.set_normal(norm)
		st.set_uv(Vector2(0.0, v_coord))
		st.add_vertex(v_left)

		st.set_normal(norm)
		st.set_uv(Vector2(1.0, v_coord))
		st.add_vertex(v_right)

	for i in range(num_pts - 1):
		var i0: int = i * 2
		var i1: int = i * 2 + 1
		var i2: int = (i + 1) * 2
		var i3: int = (i + 1) * 2 + 1

		st.add_index(i0); st.add_index(i2); st.add_index(i1)
		st.add_index(i1); st.add_index(i2); st.add_index(i3)

	var road_mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = road_mesh
	parent.add_child(mesh_inst)

	var road_body := StaticBody3D.new()
	road_body.collision_layer = col_layer
	road_body.collision_mask = 0
	if is_rough:
		road_body.set_meta("surface_type", "rough_gravel")
		road_body.add_to_group("surface_rough_gravel")
	var col_shape := CollisionShape3D.new()
	col_shape.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(col_shape)
	parent.add_child(road_body)

func _build_terrain_mesh_for_chunk(parent: Node3D, s_idx: int, e_idx: int, mat: Material, noise: FastNoiseLite) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if mat:
		st.set_material(mat)

	var num_pts: int = e_idx - s_idx + 1
	for i in range(num_pts):
		var idx: int = s_idx + i
		var pt: Vector3 = road_path.points[idx]
		var binorm: Vector3 = road_path.binormals[idx]
		var norm: Vector3 = road_path.normals[idx]
		var dist: float = road_path.cumulative_distances[idx]

		var road_left: Vector3 = pt - binorm * ROAD_HALF_WIDTH
		var road_right: Vector3 = pt + binorm * ROAD_HALF_WIDTH

		var outer_left_base: Vector3 = pt - binorm * (ROAD_HALF_WIDTH + TERRAIN_WIDTH)
		var outer_right_base: Vector3 = pt + binorm * (ROAD_HALF_WIDTH + TERRAIN_WIDTH)

		var h_left: float = noise.get_noise_2d(outer_left_base.x, outer_left_base.z) * 1.8 if noise else 0.0
		var h_right: float = noise.get_noise_2d(outer_right_base.x, outer_right_base.z) * 1.8 if noise else 0.0

		var outer_left: Vector3 = outer_left_base + norm * h_left
		var outer_right: Vector3 = outer_right_base + norm * h_right
		var v_coord: float = dist * 0.15

		st.set_normal(norm); st.set_uv(Vector2(0.0, v_coord)); st.add_vertex(outer_left)
		st.set_normal(norm); st.set_uv(Vector2(0.2, v_coord)); st.add_vertex(road_left)
		st.set_normal(norm); st.set_uv(Vector2(0.8, v_coord)); st.add_vertex(road_right)
		st.set_normal(norm); st.set_uv(Vector2(1.0, v_coord)); st.add_vertex(outer_right)

	for i in range(num_pts - 1):
		var base: int = i * 4
		var nxt: int = (i + 1) * 4
		st.add_index(base + 0); st.add_index(nxt + 0); st.add_index(base + 1)
		st.add_index(base + 1); st.add_index(nxt + 0); st.add_index(nxt + 1)
		st.add_index(base + 2); st.add_index(nxt + 2); st.add_index(base + 3)
		st.add_index(base + 3); st.add_index(nxt + 2); st.add_index(nxt + 3)

	var terrain_mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	parent.add_child(mesh_inst)

	var terrain_body := StaticBody3D.new()
	terrain_body.collision_layer = 4 # Layer 3: Grass
	terrain_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)
	parent.add_child(terrain_body)

func _build_signage() -> void:
	var signs_root := Node3D.new()
	signs_root.name = "LoopSignage"
	add_child(signs_root)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 2.2

	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(1.6, 0.8, 0.08)

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.22, 0.18, 0.14)
	wood_mat.roughness = 0.9

	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.12, 0.16, 0.14)
	board_mat.roughness = 0.85

	for sec in sections:
		var s: float = sec.s0
		var sample: Dictionary = road_path.get_sample_at_distance(s)
		var pos: Vector3 = sample.get("position", Vector3.ZERO)
		var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
		var norm: Vector3 = sample.get("normal", Vector3.UP)
		var binorm: Vector3 = norm.cross(tang).normalized()

		var sign_pos: Vector3 = pos + binorm * 2.8

		var sign_stele := Node3D.new()
		sign_stele.name = "Sign_%s" % sec.code
		sign_stele.position = sign_pos

		var post_inst := MeshInstance3D.new()
		post_inst.mesh = post_mesh
		post_inst.material_override = wood_mat
		post_inst.position = Vector3(0, 1.1, 0)
		sign_stele.add_child(post_inst)

		var board_inst := MeshInstance3D.new()
		board_inst.mesh = board_mesh
		board_inst.material_override = board_mat
		board_inst.position = Vector3(0, 1.8, 0)
		sign_stele.add_child(board_inst)

		var label := Label3D.new()
		label.text = "[%s] %s\n%s" % [sec.code, sec.name, sec.target]
		label.font_size = 36
		label.pixel_size = 0.003
		label.outline_size = 4
		label.modulate = Color(0.95, 0.95, 0.85)
		label.outline_modulate = Color(0.05, 0.05, 0.05)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0, 1.8, 0.05)
		sign_stele.add_child(label)

		var look_dir: Vector3 = -tang
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.0001:
			sign_stele.basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)

		signs_root.add_child(sign_stele)

func request_bike_recovery(current_pos: Vector3) -> Transform3D:
	if not road_path or road_path.size() < 2:
		return Transform3D(Basis(), Vector3(0, 2.0, 0))

	var closest_idx: int = road_path.find_closest_index(current_pos)
	var current_dist: float = road_path.cumulative_distances[closest_idx]
	var target_dist: float = fposmod(current_dist - 15.0, TOTAL_TRACK_LENGTH)

	var sample: Dictionary = road_path.get_sample_at_distance(target_dist)
	var pos: Vector3 = sample.get("position", Vector3.ZERO)
	var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
	var norm: Vector3 = sample.get("normal", Vector3.UP)

	var spawn_pos: Vector3 = pos + norm * 0.45
	var horiz_tang: Vector3 = Vector3(tang.x, 0.0, tang.z).normalized()
	if horiz_tang.is_zero_approx():
		horiz_tang = Vector3.FORWARD
	var spawn_basis: Basis = Basis.looking_at(horiz_tang, Vector3.UP)

	return Transform3D(spawn_basis, spawn_pos)

func _build_pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(0.16, 0.32, 0.20)
	needle_mat.roughness = 0.85
	st.set_material(needle_mat)

	var segs: int = 7
	var trunk_r: float = 0.18
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * trunk_r, 0.0, sin(a0) * trunk_r)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a0) * trunk_r * 0.8, 1.8, sin(a0) * trunk_r * 0.8)
		var p3 := Vector3(cos(a1) * trunk_r * 0.8, 1.8, sin(a1) * trunk_r * 0.8)
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)

	var cones := [
		{"y": 1.4, "r": 1.45, "h": 1.8},
		{"y": 2.5, "r": 1.15, "h": 1.6},
		{"y": 3.4, "r": 0.75, "h": 1.4}
	]
	for c in cones:
		var base_y: float = c["y"]
		var tip_y: float = base_y + c["h"]
		var r: float = c["r"]
		for i in range(segs):
			var a0: float = (float(i) / float(segs)) * TAU
			var a1: float = (float(i + 1) / float(segs)) * TAU
			var p0 := Vector3(cos(a0) * r, base_y, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, base_y, sin(a1) * r)
			var p_tip := Vector3(0, tip_y, 0)
			st.add_vertex(p0); st.add_vertex(p_tip); st.add_vertex(p1)

	st.generate_normals()
	return st.commit()

func _build_birch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.38, 0.54, 0.22)
	leaf_mat.roughness = 0.8
	st.set_material(leaf_mat)

	var segs: int = 7
	var trunk_r: float = 0.14
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * trunk_r, 0.0, sin(a0) * trunk_r)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a0) * trunk_r * 0.8, 2.5, sin(a0) * trunk_r * 0.8)
		var p3 := Vector3(cos(a1) * trunk_r * 0.8, 2.5, sin(a1) * trunk_r * 0.8)
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)

	var r: float = 1.35
	var y_center: float = 3.0
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * r, y_center, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, y_center, sin(a1) * r)
		var p_top := Vector3(0, y_center + r * 1.0, 0)
		var p_bot := Vector3(0, y_center - r * 0.7, 0)
		st.add_vertex(p0); st.add_vertex(p_top); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p_bot); st.add_vertex(p0)

	st.generate_normals()
	return st.commit()

func _build_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.26, 0.46, 0.20)
	grass_mat.roughness = 0.9
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(grass_mat)

	var h: float = 0.55
	var w: float = 0.35
	st.add_vertex(Vector3(-w, 0, 0)); st.add_vertex(Vector3(0, h, 0)); st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(0, 0, -w)); st.add_vertex(Vector3(0, h, 0)); st.add_vertex(Vector3(0, 0, w))

	st.generate_normals()
	return st.commit()
