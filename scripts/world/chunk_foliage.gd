class_name ChunkFoliage
extends RefCounted

## Manages chunk-local MultiMesh instancing using shared geometry and materials.
## Guarantees instant frustum culling and zero monolithic memory leaks.

func populate_chunk(parent_chunk: Node3D, path_data: RefCounted, s_idx: int, e_idx: int, shared_meshes: Dictionary, noise: FastNoiseLite = null) -> void:
	var pine_mesh: Mesh = shared_meshes.get("pine")
	var birch_mesh: Mesh = shared_meshes.get("birch")
	var grass_mesh: Mesh = shared_meshes.get("grass")

	var num_pts: int = e_idx - s_idx + 1
	var rng := RandomNumberGenerator.new()
	var chunk_id_val: int = parent_chunk.get("chunk_id") if "chunk_id" in parent_chunk else 0
	var seed_offset: int = noise.seed if noise else 0
	rng.seed = seed_offset + 98765 + chunk_id_val

	var pine_transforms: Array[Transform3D] = []
	var birch_transforms: Array[Transform3D] = []
	var grass_transforms: Array[Transform3D] = []

	var seg_type: int = path_data.segment_types[s_idx]
	var is_open_meadow: bool = (seg_type == 5) # 5 = MEADOW
	var tree_chance: float = 0.25 if is_open_meadow else 0.75

	for i in range(0, num_pts, 3):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var norm: Vector3 = path_data.normals[idx]

		_try_spawn_plant(pt, -binorm, norm, rng, tree_chance, pine_transforms, birch_transforms, grass_transforms, noise)
		_try_spawn_plant(pt, binorm, norm, rng, tree_chance, pine_transforms, birch_transforms, grass_transforms, noise)

	if pine_mesh and not pine_transforms.is_empty():
		_create_multimesh(parent_chunk, pine_mesh, pine_transforms, "PineMultiMesh")

	if birch_mesh and not birch_transforms.is_empty():
		_create_multimesh(parent_chunk, birch_mesh, birch_transforms, "BirchMultiMesh")

	if grass_mesh and not grass_transforms.is_empty():
		_create_multimesh(parent_chunk, grass_mesh, grass_transforms, "GrassMultiMesh")

func _try_spawn_plant(center_pt: Vector3, lateral_dir: Vector3, norm: Vector3, rng: RandomNumberGenerator, tree_chance: float, pines: Array[Transform3D], birches: Array[Transform3D], grasses: Array[Transform3D], noise: FastNoiseLite = null) -> void:
	if rng.randf() < 0.8:
		var grass_dist: float = rng.randf_range(2.6, 5.2)
		var grass_pos: Vector3 = center_pt + lateral_dir * grass_dist
		if noise:
			var t_factor: float = clampf((grass_dist - 2.0) / 20.0, 0.0, 1.0)
			var h: float = noise.get_noise_2d(grass_pos.x, grass_pos.z) * 1.8 * t_factor
			grass_pos += norm * h
		grass_pos.y -= 0.05
		var t_trans := Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), grass_pos)
		grasses.append(t_trans)

	if rng.randf() < tree_chance:
		var tree_dist: float = rng.randf_range(5.5, 17.5)
		var tree_pos: Vector3 = center_pt + lateral_dir * tree_dist
		if noise:
			var t_factor: float = clampf((tree_dist - 2.0) / 20.0, 0.0, 1.0)
			var h: float = noise.get_noise_2d(tree_pos.x, tree_pos.z) * 1.8 * t_factor
			tree_pos += norm * h
		var scale_val: float = rng.randf_range(0.85, 1.4)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * scale_val)
		var t_trans := Transform3D(basis, tree_pos)

		if rng.randf() < 0.65:
			pines.append(t_trans)
		else:
			birches.append(t_trans)

func _create_multimesh(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], node_name: String) -> void:
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	mmi.multimesh = mm
	parent.add_child(mmi)
