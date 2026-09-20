class_name RoadChunk
extends Node3D

const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")

const ROAD_HALF_WIDTH: float = 2.0 ## 4.0m road width
const TERRAIN_WIDTH: float = 20.0 ## 20m roadside meadow strip

var chunk_id: int = 0
var start_sample_idx: int = 0
var end_sample_idx: int = 0

var road_body: StaticBody3D
var terrain_body: StaticBody3D

func build_chunk(path_data: RefCounted, s_idx: int, e_idx: int, id: int, shared_materials: Dictionary, shared_meshes: Dictionary) -> void:
	chunk_id = id
	start_sample_idx = s_idx
	end_sample_idx = e_idx
	name = "Chunk_%d" % chunk_id

	var count: int = e_idx - s_idx + 1
	if count < 2:
		return

	# 1. Build Road Mesh (Layer 2: Road)
	_build_road_mesh(path_data, s_idx, e_idx, shared_materials.get("road"))

	# 2. Build Roadside Terrain Strip (Layer 3: Grass)
	var noise: FastNoiseLite = shared_materials.get("noise")
	_build_terrain_mesh(path_data, s_idx, e_idx, shared_materials.get("grass"), noise)

	# 3. Populate Chunk-Local MultiMesh Foliage
	var foliage_spawner = ChunkFoliageClass.new()
	foliage_spawner.populate_chunk(self, path_data, s_idx, e_idx, shared_meshes, noise)

func _build_road_mesh(path_data: RefCounted, s_idx: int, e_idx: int, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if mat:
		st.set_material(mat)

	var num_pts: int = e_idx - s_idx + 1
	for i in range(num_pts):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var norm: Vector3 = path_data.normals[idx]
		var dist: float = path_data.cumulative_distances[idx]

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

		st.add_index(i0)
		st.add_index(i2)
		st.add_index(i1)

		st.add_index(i1)
		st.add_index(i2)
		st.add_index(i3)

	var road_mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = road_mesh
	add_child(mesh_inst)

	# Build StaticBody3D on Layer 2 (Road = mask 2)
	road_body = StaticBody3D.new()
	road_body.collision_layer = 2
	road_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	col_shape.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(col_shape)
	add_child(road_body)

func _build_terrain_mesh(path_data: RefCounted, s_idx: int, e_idx: int, mat: Material, noise: FastNoiseLite = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if mat:
		st.set_material(mat)

	var num_pts: int = e_idx - s_idx + 1
	assert(noise != null, "Terrain noise must be provided by WorldManager")

	for i in range(num_pts):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var norm: Vector3 = path_data.normals[idx]
		var dist: float = path_data.cumulative_distances[idx]

		var road_left: Vector3 = pt - binorm * ROAD_HALF_WIDTH
		var road_right: Vector3 = pt + binorm * ROAD_HALF_WIDTH

		var outer_left_base: Vector3 = pt - binorm * (ROAD_HALF_WIDTH + TERRAIN_WIDTH)
		var outer_right_base: Vector3 = pt + binorm * (ROAD_HALF_WIDTH + TERRAIN_WIDTH)

		var h_left: float = noise.get_noise_2d(outer_left_base.x, outer_left_base.z) * 1.8
		var h_right: float = noise.get_noise_2d(outer_right_base.x, outer_right_base.z) * 1.8

		var outer_left: Vector3 = outer_left_base + norm * h_left
		var outer_right: Vector3 = outer_right_base + norm * h_right

		var v_coord: float = dist * 0.15

		st.set_normal(norm)
		st.set_uv(Vector2(0.0, v_coord))
		st.add_vertex(outer_left)

		st.set_normal(norm)
		st.set_uv(Vector2(0.2, v_coord))
		st.add_vertex(road_left)

		st.set_normal(norm)
		st.set_uv(Vector2(0.8, v_coord))
		st.add_vertex(road_right)

		st.set_normal(norm)
		st.set_uv(Vector2(1.0, v_coord))
		st.add_vertex(outer_right)

	for i in range(num_pts - 1):
		var base: int = i * 4
		var nxt: int = (i + 1) * 4

		st.add_index(base + 0)
		st.add_index(nxt + 0)
		st.add_index(base + 1)

		st.add_index(base + 1)
		st.add_index(nxt + 0)
		st.add_index(nxt + 1)

		st.add_index(base + 2)
		st.add_index(nxt + 2)
		st.add_index(base + 3)

		st.add_index(base + 3)
		st.add_index(nxt + 2)
		st.add_index(nxt + 3)

	var terrain_mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	add_child(mesh_inst)

	# Build StaticBody3D on Layer 3 (Grass = mask 4)
	terrain_body = StaticBody3D.new()
	terrain_body.collision_layer = 4
	terrain_body.collision_mask = 0
	var col_shape := CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)
	add_child(terrain_body)
