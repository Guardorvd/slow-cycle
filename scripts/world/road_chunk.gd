class_name RoadChunk
extends Node3D

const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

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

	# Check if chunk contains ROUGH_GRAVEL segments
	var is_rough: bool = false
	if "segment_types" in path_data and path_data.segment_types.size() > e_idx:
		for i in range(s_idx, e_idx + 1):
			if path_data.segment_types[i] == RoadPathDataClass.SegmentType.ROUGH_GRAVEL:
				is_rough = true
				break

	# 1. Build Road Mesh (Layer 2: Road, or Layer 2 | 16: Rough Gravel)
	_build_road_mesh(path_data, s_idx, e_idx, shared_materials.get("road"), is_rough)

	# 2. Build Roadside Mountain Terrain (Layer 3: Grass)
	var carver: RefCounted = shared_materials.get("terrain_carver")
	var noise: FastNoiseLite = shared_materials.get("noise")
	assert(noise != null, "Terrain noise must be provided by WorldManager")
	var guard_post_mesh: Mesh = shared_meshes.get("guard_post")
	_build_terrain_mesh(path_data, s_idx, e_idx, shared_materials.get("grass"), carver, noise, guard_post_mesh, is_rough)

	# 3. Populate Chunk-Local MultiMesh Foliage
	var foliage_spawner = ChunkFoliageClass.new()
	foliage_spawner.populate_chunk(self, path_data, s_idx, e_idx, shared_meshes, noise)

func _build_road_mesh(path_data: RefCounted, s_idx: int, e_idx: int, mat: Material, is_rough: bool = false) -> void:
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

		var half_w: float = ROAD_HALF_WIDTH
		if not path_data.road_widths.is_empty() and idx < path_data.road_widths.size():
			half_w = path_data.road_widths[idx] * 0.5

		var v_left: Vector3 = pt - binorm * half_w
		var v_right: Vector3 = pt + binorm * half_w

		if is_rough:
			var t_chunk: float = float(i) / float(maxi(num_pts - 1, 1))
			var envelope: float = smoothstep(0.0, 0.15, t_chunk) * smoothstep(1.0, 0.85, t_chunk)
			var bump: float = 0.025 * sin(dist * 2.5) * envelope
			v_left.y += bump
			v_right.y += bump

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

	# Build StaticBody3D on Layer 2 (Road = mask 2) or Layer 2 | 16 (Rough Gravel)
	road_body = StaticBody3D.new()
	road_body.collision_layer = (2 | 16) if is_rough else 2
	road_body.collision_mask = 0
	if is_rough:
		road_body.set_meta("surface_type", "rough_gravel")
		road_body.add_to_group("surface_rough_gravel")
	var col_shape := CollisionShape3D.new()
	col_shape.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(col_shape)
	add_child(road_body)

func _build_terrain_mesh(
	path_data: RefCounted,
	s_idx: int,
	e_idx: int,
	mat: Material,
	p_carver: RefCounted = null,
	noise: FastNoiseLite = null,
	guard_post_mesh: Mesh = null,
	_is_rough: bool = false
) -> void:
	var carver: RefCounted = p_carver
	if carver == null:
		var s_seed: int = noise.seed if noise else 184729
		carver = TerrainCarverClass.new(s_seed)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if mat:
		st.set_material(mat)

	var num_pts: int = e_idx - s_idx + 1
	var guard_post_transforms: Array[Transform3D] = []

	for i in range(num_pts):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var tang: Vector3 = path_data.tangents[idx]
		var norm: Vector3 = path_data.normals[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var dist: float = path_data.cumulative_distances[idx]
		var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
		var seg_type: int = path_data.segment_types[idx] if idx < path_data.segment_types.size() else 0

		var half_w: float = ROAD_HALF_WIDTH
		if not path_data.road_widths.is_empty() and idx < path_data.road_widths.size():
			half_w = path_data.road_widths[idx] * 0.5

		var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, binorm, half_w, curv, seg_type, dist)
		var verts: PackedVector3Array = cs.vertices
		var uvs: PackedVector2Array = cs.uvs

		for v_idx in range(8):
			st.set_normal(norm)
			st.set_uv(uvs[v_idx])
			st.add_vertex(verts[v_idx])

		# Visual delineator guard posts along cliff danger shoulders every ~4m (i % 2 == 0)
		if guard_post_mesh != null and (i % 2 == 0):
			var danger_mask: int = cs.danger_mask
			if (danger_mask & 1) != 0:
				var t_left := Transform3D(Basis(), cs.shoulder_left_pos)
				guard_post_transforms.append(t_left)
			if (danger_mask & 2) != 0:
				var t_right := Transform3D(Basis(), cs.shoulder_right_pos)
				guard_post_transforms.append(t_right)

	# 6 quad strips across the corridor (skipping col 3 which is the road)
	const STRIP_COLS: Array[int] = [0, 1, 2, 4, 5, 6]
	for i in range(num_pts - 1):
		var row_curr: int = i * 8
		var row_next: int = (i + 1) * 8

		for col: int in STRIP_COLS:
			var i0: int = row_curr + col
			var i1: int = row_curr + col + 1
			var i2: int = row_next + col
			var i3: int = row_next + col + 1

			st.add_index(i0)
			st.add_index(i2)
			st.add_index(i1)

			st.add_index(i1)
			st.add_index(i2)
			st.add_index(i3)

	st.generate_normals()

	var terrain_mesh: ArrayMesh = st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = terrain_mesh
	add_child(mesh_inst)

	# Build StaticBody3D on Layer 3 (Grass / Mountain Terrain = mask 4)
	terrain_body = StaticBody3D.new()
	terrain_body.collision_layer = 4
	terrain_body.collision_mask = 0
	terrain_body.set_meta("surface_type", "mountain_terrain")
	var col_shape := CollisionShape3D.new()
	col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(col_shape)
	add_child(terrain_body)

	# Build visual-only MultiMesh guard posts if any were flagged
	if not guard_post_transforms.is_empty() and guard_post_mesh != null:
		_build_guard_posts(guard_post_mesh, guard_post_transforms)

func _build_guard_posts(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if mesh == null or transforms.is_empty():
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GuardPostMultiMesh"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	add_child(mmi)
