class_name WorldManager
extends Node3D

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")

@export var world_seed: int = 184729
@export var player: Node3D

var road_path: RefCounted
var road_logic: RefCounted
var chunk_streamer: Node3D

var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--seed="):
			var val: String = arg.trim_prefix("--seed=")
			if val.is_valid_int():
				world_seed = val.to_int()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var val: String = arg.trim_prefix("--seed=")
			if val.is_valid_int():
				world_seed = val.to_int()

	_init_shared_resources()
	
	road_path = RoadPathDataClass.new()
	road_logic = RoadLogicClass.new(world_seed, road_path)

	# Setup streamer
	chunk_streamer = ChunkStreamerClass.new()
	chunk_streamer.setup(self, road_path, road_logic, shared_materials, shared_meshes)
	add_child(chunk_streamer)

func _process(_delta: float) -> void:
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO
	if chunk_streamer:
		chunk_streamer.update_streaming(player_pos)

func request_bike_recovery(current_pos: Vector3) -> Transform3D:
	if not road_path or road_path.size() < 2:
		return Transform3D(Basis(), Vector3(0, 4.0, 0))

	var closest_idx: int = road_path.find_closest_index(current_pos)
	var current_dist: float = road_path.cumulative_distances[closest_idx]
	var target_dist: float = maxf(0.0, current_dist - 20.0)

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
	leaf_mat.albedo_color = Color(0.38, 0.54, 0.22)
	leaf_mat.roughness = 0.8
	st.set_material(leaf_mat)

	# 1. Trunk (y=0 to y=2.5)
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

	# 2. Canopy
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
