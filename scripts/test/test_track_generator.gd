class_name TestTrackGenerator
extends Node3D

## Deterministic closed-circuit polygon for empirical riding feel and physics verification.
## Features 18 calibrated test sections (12 isolated A-L, 6 composite stress S1-S6).
## Guarantees exact C1 continuity, analytical radius profiles, zero seam defects,
## Layer 2/Layer 3 collision layers, 3D roadside signage, and racing distance boards.

const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")

const TOTAL_TRACK_LENGTH: float = 2800.0
const SAMPLE_DS: float = 2.0
const SAMPLES_COUNT: int = 1401 ## samples 0 to 1400 (sample 1400 wraps exactly to 0)
const CHUNK_LENGTH: float = 50.0
const CHUNKS_COUNT: int = 56 ## 56 chunks * 50m = 2800m
const ROAD_HALF_WIDTH: float = 2.0 ## 4.0m road width
const TERRAIN_WIDTH: float = 20.0 ## 20m roadside meadow strip

@export var player: Node3D
@export var world_seed: int = 42

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
	_build_distance_boards()

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
		{"code": "A", "name": "Flat Start", "desc": "Calibration Baseline & Coasting", "s0": 0.0, "s1": 247.61, "target": "FLAT | ACCEL & COAST"},
		{"code": "B", "name": "Long Straight Climb", "desc": "Hill Resistance +4.5°", "s0": 247.61, "s1": 467.61, "target": "CLIMB +4.5° | SUSTAINED"},
		{"code": "C", "name": "Long Downhill", "desc": "Gravity Accel & Downhill Brake -5.0°", "s0": 467.61, "s1": 717.61, "target": "DOWNHILL -5.0° | BRAKE DIVE"},
		{"code": "D", "name": "Sharp Crest", "desc": "Pitch +6° to -6° Pitch Change", "s0": 717.61, "s1": 797.61, "target": "CREST +6° -> -6° | UNWEIGHTING"},
		{"code": "E", "name": "Sharp Dip", "desc": "Pitch -6° to +6° Compression", "s0": 797.61, "s1": 877.61, "target": "DIP -6° -> +6° | COMPRESSION"},
		{"code": "F", "name": "Constant Arc R=35m", "desc": "Steady-State Lean Angle", "s0": 877.61, "s1": 1356.93, "target": "CORNER R=35m | LEAN 22°"},
		{"code": "G", "name": "Sharp Turn R=25m", "desc": "Max Lean Angle & Steering Damping", "s0": 1356.93, "s1": 1456.93, "target": "SHARP TURN R=25m | LEAN 30°"},
		{"code": "H", "name": "S-Chicanes R=30m", "desc": "Rapid Roll/Bank Reversals", "s0": 1456.93, "s1": 1656.93, "target": "S-CHICANES R=30m | ROLL REVERSAL"},
		{"code": "I", "name": "Fast Sweeper R=65m", "desc": "High Speed Equilibrium", "s0": 1656.93, "s1": 1856.93, "target": "SWEEPER R=65m | HIGH SPEED"},
		{"code": "J", "name": "Rough Gravel", "desc": "Vertical Micro-Bumps (0.035m)", "s0": 1856.93, "s1": 1956.93, "target": "ROUGH GRAVEL | MICRO-BUMPS"},
		{"code": "K", "name": "Rough Downhill", "desc": "Downhill -4.0° with Bumps", "s0": 1956.93, "s1": 2106.93, "target": "ROUGH DOWNHILL -4° | CHATTER"},
		{"code": "L", "name": "Grass Verge Exit", "desc": "Layer 3 Grass Drag (0.45)", "s0": 2106.93, "s1": 2257.88, "target": "GRASS VERGE | HIGH DRAG (0.45)"},
		{"code": "S1", "name": "Downhill -> Sweeper", "desc": "High Speed Entry into R=65m Arc", "s0": 2257.88, "s1": 2457.88, "target": "STRESS 1 | HIGH SPEED ENTRY"},
		{"code": "S2", "name": "Downhill -> Apex Flow", "desc": "Braking Boards into R=25m Apex", "s0": 2457.88, "s1": 2557.88, "target": "STRESS 2 | APEX FLOW & BOARDS"},
		{"code": "S3", "name": "Crest -> Dip -> Turn", "desc": "Compression into Steering Input", "s0": 2557.88, "s1": 2627.88, "target": "STRESS 3 | CREST -> DIP -> TURN"},
		{"code": "S4", "name": "Rough Downhill -> S-Turns", "desc": "Combined Chatter & Roll Transition", "s0": 2627.88, "s1": 2687.88, "target": "STRESS 4 | BUMPS -> S-TURNS"},
		{"code": "S5", "name": "Sweeper -> Heavy Brake", "desc": "Threshold Emergency Braking", "s0": 2687.88, "s1": 2745.26, "target": "STRESS 5 | THRESHOLD BRAKE"},
		{"code": "S6", "name": "Grass in Corner Return", "desc": "Layer 3 Low Grip Turn to Start", "s0": 2745.26, "s1": 2800.00, "target": "STRESS 6 | GRASS CORNER -> START"}
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
	var cur_pos: Vector2 = Vector2.ZERO
	var cur_dir: Vector2 = Vector2(0, -1) # North (-Z)
	var cur_s: float = 0.0

	# Leg 1: North (0 to 877.61m)
	var r: Array = _add_line(cur_pos, cur_dir, cur_s, 247.613078) # A
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 220.0) # B
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 250.0) # C
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 80.0)  # D
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 80.0)  # E
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 1 (Turn F Arc R=35m, 90 deg right)
	r = _add_arc(cur_pos, cur_dir, cur_s, 35.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Leg 2: East
	r = _add_line(cur_pos, cur_dir, cur_s, 145.02213) # F exit
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 424.33629 - 145.02213) # G approach
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 2 (Turn G Arc R=25m, 90 deg right)
	r = _add_arc(cur_pos, cur_dir, cur_s, 25.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Leg 3: South
	r = _add_line(cur_pos, cur_dir, cur_s, 60.73009) # G exit
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section H: S-Chicanes R=30m
	var s_H_start: float = cur_s
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 30.0, 25.0, 2)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 200.0 - (cur_s - s_H_start))
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section I: Fast Sweeper R=65m
	var s_I_start: float = cur_s
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 65.0, 15.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 200.0 - (cur_s - s_I_start))
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section J: Rough Gravel
	r = _add_line(cur_pos, cur_dir, cur_s, 100.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section K: Rough Downhill
	r = _add_line(cur_pos, cur_dir, cur_s, 150.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section L: Grass Verge (remaining to reach Z = -30.0)
	var rem_Z: float = -30.0 - cur_pos.y
	r = _add_line(cur_pos, cur_dir, cur_s, rem_Z)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 3 (Turn S1 Sweeper Arc R=65m, 90 deg right)
	r = _add_arc(cur_pos, cur_dir, cur_s, 65.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Leg 4: West
	r = _add_line(cur_pos, cur_dir, cur_s, 97.89824) # S1 exit
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section S2: Apex Flow with R=25m chicane
	var s_S2_start: float = cur_s
	r = _add_line(cur_pos, cur_dir, cur_s, 20.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 25.0, 20.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 100.0 - (cur_s - s_S2_start))
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section S3: Crest -> Dip -> Turn combo (70.0m)
	var s_S3_start: float = cur_s
	r = _add_line(cur_pos, cur_dir, cur_s, 20.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 45.0, 8.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 70.0 - (cur_s - s_S3_start))
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section S4: Rough Downhill into S-turns (60.0m)
	var s_S4_start: float = cur_s
	r = _add_line(cur_pos, cur_dir, cur_s, 15.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 30.0, 10.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_line(cur_pos, cur_dir, cur_s, 60.0 - (cur_s - s_S4_start))
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Section S5: Sweeper into Heavy Brake
	var s_S5_start: float = cur_s
	r = _add_line(cur_pos, cur_dir, cur_s, 15.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	r = _add_symmetric_chicane(cur_pos, cur_dir, cur_s, 65.0, 6.0, 1)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]
	var rem_X: float = cur_pos.x - 35.0
	r = _add_line(cur_pos, cur_dir, cur_s, rem_X)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	# Corner 4 (Turn S6 Grass Corner Arc R=35m, 90 deg right)
	r = _add_arc(cur_pos, cur_dir, cur_s, 35.0, 90.0)
	cur_pos = r[0]; cur_dir = r[1]; cur_s = r[2]

	_setup_elevation()

	# Sample into road_path
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

		# For exact seam closure on the last point:
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

		# Segment type: MEADOW (5) for open areas, DESCENT (4) for downhills, STRAIGHT (0) for flats
		var seg_type: int = 0
		if slope_deg < -2.0:
			seg_type = 4 # DESCENT
		elif absf(slope_deg) < 0.5 and kappa < 0.001:
			seg_type = 5 # MEADOW

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
	# Leg 1: 0..877.6m
	elev_keys.append(ElevKey.new(0.0, 0.0, 0.0))          # A start
	elev_keys.append(ElevKey.new(247.61, 0.0, 0.0))        # A end / B start
	elev_keys.append(ElevKey.new(272.61, 0.98, 4.5))       # B climb blend
	elev_keys.append(ElevKey.new(442.61, 14.33, 4.5))      # B climb steady
	elev_keys.append(ElevKey.new(467.61, 15.31, 0.0))      # B end / C start
	elev_keys.append(ElevKey.new(492.61, 14.22, -5.0))     # C downhill blend
	elev_keys.append(ElevKey.new(692.61, -3.27, -5.0))     # C downhill steady
	elev_keys.append(ElevKey.new(717.61, -4.36, 0.0))      # C end / D start
	elev_keys.append(ElevKey.new(737.61, -2.79, 6.0))      # D crest ascent
	elev_keys.append(ElevKey.new(757.61, -2.00, 0.0))      # D crest apex
	elev_keys.append(ElevKey.new(777.61, -2.79, -6.0))     # D crest descent
	elev_keys.append(ElevKey.new(797.61, -4.36, 0.0))      # D end / E start
	elev_keys.append(ElevKey.new(817.61, -5.93, -6.0))     # E dip descent
	elev_keys.append(ElevKey.new(837.61, -6.72, 0.0))      # E dip bottom
	elev_keys.append(ElevKey.new(857.61, -5.93, 6.0))      # E dip ascent
	elev_keys.append(ElevKey.new(877.61, -4.36, 0.0))      # E end
	
	# Leg 2 & first part of Leg 3: Flat at Y = -4.36m up to Section K start (1956.93)
	elev_keys.append(ElevKey.new(1956.93, -4.36, 0.0))     # K start (Rough Downhill)
	elev_keys.append(ElevKey.new(1981.93, -5.23, -4.0))     # K downhill blend -4.0°
	elev_keys.append(ElevKey.new(2021.93, -8.02, -4.0))     # K steady
	elev_keys.append(ElevKey.new(2046.93, -8.90, 0.0))      # K level out
	elev_keys.append(ElevKey.new(2106.93, -8.90, 0.0))      # K end / L start
	
	# Flat through L, S1, and S2
	elev_keys.append(ElevKey.new(2257.88, -8.90, 0.0))      # S1 start
	elev_keys.append(ElevKey.new(2457.88, -8.90, 0.0))      # S2 start
	elev_keys.append(ElevKey.new(2557.88, -8.90, 0.0))      # S3 start

	# S3: Crest -> Dip -> Turn combo (2557.88 .. 2627.88)
	elev_keys.append(ElevKey.new(2575.00, -8.30, 4.0))      # Crest ascent +4°
	elev_keys.append(ElevKey.new(2590.00, -7.78, 0.0))      # Crest apex
	elev_keys.append(ElevKey.new(2610.00, -8.48, -4.0))     # Dip descent -4°
	elev_keys.append(ElevKey.new(2627.88, -8.90, 0.0))      # S3 end / S4 start

	# S4: Rough Downhill into S-turns (2627.88 .. 2687.88)
	elev_keys.append(ElevKey.new(2645.00, -9.42, -3.5))     # Downhill entry -3.5°
	elev_keys.append(ElevKey.new(2670.00, -10.95, -3.5))    # Downhill sustained -3.5°
	elev_keys.append(ElevKey.new(2687.88, -11.47, 0.0))     # S4 end / S5 start

	# S5: Sweeper into Heavy Brake (2687.88 .. 2745.26)
	elev_keys.append(ElevKey.new(2700.00, -9.75, 17.0))     # Recovery climb
	elev_keys.append(ElevKey.new(2723.00, -2.71, 17.0))     # Sustained climb
	elev_keys.append(ElevKey.new(2735.00, 0.00, 0.0))       # Level off at 0.00m into heavy braking zone
	elev_keys.append(ElevKey.new(2745.26, 0.00, 0.0))       # S5 end / S6 start
	elev_keys.append(ElevKey.new(2800.00, 0.00, 0.0))       # S6 end -> wrap to 0.0m exact!

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
	
	# Micro-bumps for J (1856.93..1956.93), K (1956.93..2106.93), S4 (2627.88..2687.88)
	var bump: float = 0.0
	if (s >= 1856.93 and s <= 1956.93) or (s >= 1956.93 and s <= 2106.93) or (s >= 2627.88 and s <= 2687.88):
		bump = 0.035 * sin(2.0 * PI * s / 2.5)
	
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

		var chunk_node := Node3D.new()
		chunk_node.name = "TestTrackChunk_%d" % c
		chunk_node.set("chunk_id", c)
		add_child(chunk_node)
		chunks.append(chunk_node)

		# Check if this chunk is located in grass-road sections (Section L or Section S6)
		var chunk_center_s: float = (road_path.cumulative_distances[s_idx] + road_path.cumulative_distances[e_idx]) * 0.5
		var is_grass_road: bool = (chunk_center_s >= 2106.93 and chunk_center_s <= 2257.88) or (chunk_center_s >= 2745.26 and chunk_center_s <= 2800.0)
		var is_rough_road: bool = (chunk_center_s >= 1856.93 and chunk_center_s <= 2106.93) or (chunk_center_s >= 2627.88 and chunk_center_s <= 2687.88)

		# 1. Build Road Mesh
		var road_mat: Material = shared_materials.get("grass") if is_grass_road else shared_materials.get("road")
		var road_col_layer: int = 4 if is_grass_road else 2 # Layer 3: Grass (4) or Layer 2: Road (2)
		if is_rough_road and not is_grass_road:
			road_col_layer = road_col_layer | 16 # Layer 5: Rough Gravel
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
	signs_root.name = "TrackSignage"
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

		# Position on right side of track (2.8m from centerline)
		var sign_pos: Vector3 = pos + binorm * 2.8

		var sign_stele := Node3D.new()
		sign_stele.name = "Sign_%s" % sec.code
		sign_stele.position = sign_pos

		# Post
		var post_inst := MeshInstance3D.new()
		post_inst.mesh = post_mesh
		post_inst.material_override = wood_mat
		post_inst.position = Vector3(0, 1.1, 0)
		sign_stele.add_child(post_inst)

		# Sign Board
		var board_inst := MeshInstance3D.new()
		board_inst.mesh = board_mesh
		board_inst.material_override = board_mat
		board_inst.position = Vector3(0, 1.8, 0)
		sign_stele.add_child(board_inst)

		# Label3D facing the approaching rider (-tangent)
		var label := Label3D.new()
		label.text = "[%s] %s\n%s" % [sec.code, sec.name, sec.target]
		label.font_size = 38
		label.pixel_size = 0.003
		label.outline_size = 4
		label.modulate = Color(0.95, 0.95, 0.85)
		label.outline_modulate = Color(0.05, 0.05, 0.05)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(0, 1.8, 0.05)
		sign_stele.add_child(label)

		# Orient stele to face approaching riders (-tang)
		var look_dir: Vector3 = -tang
		look_dir.y = 0.0
		if look_dir.length_squared() > 0.0001:
			sign_stele.basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)

		signs_root.add_child(sign_stele)

func _build_distance_boards() -> void:
	var boards_root := Node3D.new()
	boards_root.name = "ApexFlowBoards"
	add_child(boards_root)

	# Section S2: 2457.88m to 2557.88m
	# Apex is at s = 2457.88 + 20.0 + 34.91 / 2 = ~2495.33m
	var s_apex: float = 2495.33
	var board_defs: Array[Dictionary] = [
		{"dist": s_apex - 100.0, "text": "[ 100 m ]", "color": Color(0.9, 0.9, 0.9)},
		{"dist": s_apex - 50.0, "text": "[ 50 m ]", "color": Color(0.95, 0.85, 0.2)},
		{"dist": s_apex - 30.0, "text": "[ BRAKE ZONE ]", "color": Color(0.95, 0.3, 0.2)},
		{"dist": s_apex, "text": "[ APEX ]", "color": Color(0.3, 0.9, 0.3)},
		{"dist": s_apex + 40.0, "text": "[ SPRINT ]", "color": Color(0.2, 0.8, 0.95)}
	]

	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(2.0, 0.7, 0.06)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.08, 0.08, 0.10)
	bg_mat.roughness = 0.8

	for b in board_defs:
		var s: float = b.dist
		var sample: Dictionary = road_path.get_sample_at_distance(s)
		var pos: Vector3 = sample.get("position", Vector3.ZERO)
		var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
		var norm: Vector3 = sample.get("normal", Vector3.UP)
		var binorm: Vector3 = norm.cross(tang).normalized()

		var b_pos: Vector3 = pos + binorm * 2.75

		var b_node := Node3D.new()
		b_node.position = b_pos

		var b_mesh_inst := MeshInstance3D.new()
		b_mesh_inst.mesh = board_mesh
		b_mesh_inst.material_override = bg_mat
		b_mesh_inst.position = Vector3(0, 0.85, 0)
		b_node.add_child(b_mesh_inst)

		var label := Label3D.new()
		label.text = b.text
		label.font_size = 46
		label.pixel_size = 0.0035
		label.outline_size = 5
		label.modulate = b.color
		label.outline_modulate = Color(0.0, 0.0, 0.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector3(0, 0.85, 0.04)
		b_node.add_child(label)

		var look_b: Vector3 = -tang
		look_b.y = 0.0
		if look_b.length_squared() > 0.0001:
			b_node.basis = Basis.looking_at(look_b.normalized(), Vector3.UP)

		boards_root.add_child(b_node)


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
