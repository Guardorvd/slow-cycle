class_name WorldManager
extends Node3D

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

@export var world_seed: int = 184729
@export var randomize_world_seed_on_start: bool = false
@export var player: Node3D

var road_path: RefCounted
var road_logic: RefCounted
var chunk_streamer: Node3D

var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}

func _ready() -> void:
	_resolve_session_seed(OS.get_cmdline_args(), OS.get_cmdline_user_args())

	_init_shared_resources()
	
	road_path = RoadPathDataClass.new()
	road_logic = RoadLogicClass.new(world_seed, road_path)

	# Setup streamer
	chunk_streamer = ChunkStreamerClass.new()
	chunk_streamer.setup(self, road_path, road_logic, shared_materials, shared_meshes)
	add_child(chunk_streamer)

## Keep the generator deterministic after choosing its session seed. Normal gameplay
## can request a fresh value, while explicit CLI seeds always win for replay/tests.
func _resolve_session_seed(command_args: PackedStringArray, user_args: PackedStringArray) -> void:
	var seed_override: Variant = _find_seed_override(command_args)
	var user_seed_override: Variant = _find_seed_override(user_args)
	if user_seed_override != null:
		seed_override = user_seed_override
	if seed_override != null:
		world_seed = int(seed_override)
		return
	if randomize_world_seed_on_start:
		var session_rng := RandomNumberGenerator.new()
		session_rng.randomize()
		world_seed = session_rng.randi_range(1, 2147483647)

func _find_seed_override(arguments: PackedStringArray) -> Variant:
	for arg: String in arguments:
		if arg.begins_with("--seed="):
			var value: String = arg.trim_prefix("--seed=")
			if value.is_valid_int():
				return value.to_int()
	return null

func _process(delta: float) -> void:
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var player_vel: Vector3 = Vector3.ZERO
	if player:
		if "velocity" in player:
			player_vel = player.velocity
		elif "linear_velocity" in player:
			player_vel = player.linear_velocity
	if chunk_streamer:
		chunk_streamer.update_streaming(player_pos, player_vel, delta)

func request_bike_recovery(current_pos: Vector3) -> Transform3D:
	var active_path: RefCounted = road_path
	if chunk_streamer and chunk_streamer.has_method("get_active_road_path"):
		var p = chunk_streamer.get_active_road_path()
		if p != null and p.size() >= 2:
			active_path = p

	if not active_path or active_path.size() < 2:
		return Transform3D(Basis(), Vector3(0, 4.0, 0))

	var hint_idx: int = 0
	if chunk_streamer and "last_closest_idx" in chunk_streamer:
		hint_idx = chunk_streamer.last_closest_idx
	var closest_idx: int = active_path.find_closest_index(current_pos, hint_idx)
	var current_dist: float = active_path.cumulative_distances[closest_idx]
	var target_dist: float = maxf(0.0, current_dist - 20.0)

	var sample: Dictionary = active_path.get_sample_at_distance(target_dist)
	var pos: Vector3 = sample.get("position", Vector3.ZERO)
	var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
	var norm: Vector3 = sample.get("normal", Vector3.UP)

	var spawn_pos: Vector3 = pos + norm * 0.45
	var horiz_tang: Vector3 = Vector3(tang.x, 0.0, tang.z).normalized()
	if horiz_tang.is_zero_approx():
		horiz_tang = Vector3.FORWARD
	var spawn_basis: Basis = Basis.looking_at(horiz_tang, Vector3.UP)

	return Transform3D(spawn_basis, spawn_pos)

func _init_shared_resources() -> void:
	var road_mat: Material = load("res://assets/materials/gravel_road.tres")
	var grass_mat: Material = load("res://assets/materials/roadside_grass.tres")
	shared_materials["road"] = road_mat
	shared_materials["grass"] = grass_mat

	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = world_seed
	terrain_noise.frequency = 0.04
	shared_materials["noise"] = terrain_noise
	shared_materials["terrain_carver"] = TerrainCarverClass.new(world_seed)

	shared_meshes["pine"] = _build_pine_mesh()
	shared_meshes["birch"] = _build_birch_mesh()
	shared_meshes["grass"] = _build_grass_mesh()
	shared_meshes["boulder"] = _build_boulder_mesh()

func _build_pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(0.16, 0.32, 0.20)
	needle_mat.roughness = 0.85
	st.set_material(needle_mat)

	# 1. Trunk (y=0 to y=1.8)
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

	# 2. Cones
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
			
			st.add_vertex(p0)
			st.add_vertex(p_tip)
			st.add_vertex(p1)

	st.generate_normals()
	return st.commit()

func _build_birch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.40, 0.58, 0.24) # Fresh vibrant mountain birch
	leaf_mat.roughness = 0.82
	st.set_material(leaf_mat)

	# 1. Trunk (y=0 to y=2.8)
	var segs: int = 6
	var trunk_r: float = 0.12
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * trunk_r, 0.0, sin(a0) * trunk_r)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a0) * trunk_r * 0.75, 2.8, sin(a0) * trunk_r * 0.75)
		var p3 := Vector3(cos(a1) * trunk_r * 0.75, 2.8, sin(a1) * trunk_r * 0.75)

		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)

	# 2. Natural 3-Cluster Low-Poly Organic Canopy
	var clusters := [
		{"center": Vector3(0.0, 3.2, 0.0), "r": 1.15, "segs": 7},
		{"center": Vector3(0.30, 4.0, -0.20), "r": 0.85, "segs": 6},
		{"center": Vector3(-0.25, 2.8, 0.25), "r": 0.80, "segs": 6}
	]

	for cl in clusters:
		var c_pos: Vector3 = cl["center"]
		var cr: float = cl["r"]
		var c_segs: int = cl["segs"]

		var pole_top := c_pos + Vector3(0.0, cr * 1.05, 0.0)
		var pole_bot := c_pos + Vector3(0.0, -cr * 0.95, 0.0)

		var r_mid: float = cr
		var r_top: float = cr * 0.72
		var r_bot: float = cr * 0.68

		var y_top: float = c_pos.y + cr * 0.50
		var y_mid: float = c_pos.y
		var y_bot: float = c_pos.y - cr * 0.45

		var ring_top: Array[Vector3] = []
		var ring_mid: Array[Vector3] = []
		var ring_bot: Array[Vector3] = []

		for i in range(c_segs):
			var a: float = (float(i) / float(c_segs)) * TAU
			ring_top.append(Vector3(c_pos.x + cos(a) * r_top, y_top, c_pos.z + sin(a) * r_top))
			ring_mid.append(Vector3(c_pos.x + cos(a + 0.2) * r_mid, y_mid, c_pos.z + sin(a + 0.2) * r_mid))
			ring_bot.append(Vector3(c_pos.x + cos(a) * r_bot, y_bot, c_pos.z + sin(a) * r_bot))

		for i in range(c_segs):
			var i_next: int = (i + 1) % c_segs

			# Top cone
			st.add_vertex(ring_top[i]); st.add_vertex(pole_top); st.add_vertex(ring_top[i_next])

			# Upper band
			st.add_vertex(ring_mid[i]); st.add_vertex(ring_top[i]); st.add_vertex(ring_mid[i_next])
			st.add_vertex(ring_mid[i_next]); st.add_vertex(ring_top[i]); st.add_vertex(ring_top[i_next])

			# Lower band
			st.add_vertex(ring_bot[i]); st.add_vertex(ring_mid[i]); st.add_vertex(ring_bot[i_next])
			st.add_vertex(ring_bot[i_next]); st.add_vertex(ring_mid[i]); st.add_vertex(ring_mid[i_next])

			# Bottom cone
			st.add_vertex(ring_bot[i_next]); st.add_vertex(pole_bot); st.add_vertex(ring_bot[i])

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

func _build_boulder_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.40, 0.38) # Weathered granite / slate
	rock_mat.roughness = 0.92
	st.set_material(rock_mat)

	# Low-poly faceted boulder (6-segment base ring, 6-segment mid ring, apex)
	var base_r: float = 0.55
	var mid_r: float = 0.70
	var mid_y: float = 0.40
	var top_y: float = 0.75
	var segs: int = 6

	var rad_perturb: Array[float] = [1.0, 0.85, 1.15, 0.90, 1.10, 0.95]
	var y_perturb: Array[float] = [0.0, 0.08, -0.05, 0.06, -0.04, 0.05]

	var base_pts: Array[Vector3] = []
	var mid_pts: Array[Vector3] = []

	for i in range(segs):
		var a: float = (float(i) / float(segs)) * TAU
		var p_base := Vector3(cos(a) * base_r * rad_perturb[i], 0.0, sin(a) * base_r * rad_perturb[i])
		var p_mid := Vector3(cos(a) * mid_r * rad_perturb[(i + 2) % segs], mid_y + y_perturb[i], sin(a) * mid_r * rad_perturb[(i + 2) % segs])
		base_pts.append(p_base)
		mid_pts.append(p_mid)

	var apex := Vector3(0.05, top_y, -0.04)

	# Quads between base and mid
	for i in range(segs):
		var i_next: int = (i + 1) % segs
		st.add_vertex(base_pts[i]); st.add_vertex(mid_pts[i]); st.add_vertex(base_pts[i_next])
		st.add_vertex(base_pts[i_next]); st.add_vertex(mid_pts[i]); st.add_vertex(mid_pts[i_next])

	# Triangles from mid to apex
	for i in range(segs):
		var i_next: int = (i + 1) % segs
		st.add_vertex(mid_pts[i]); st.add_vertex(apex); st.add_vertex(mid_pts[i_next])

	st.generate_normals()
	return st.commit()


