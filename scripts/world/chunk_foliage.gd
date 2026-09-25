class_name ChunkFoliage
extends RefCounted

## Slow Cycle — Chunk Foliage & Minimal Greybox Dressing (FEAT-014.5)
## Manages chunk-local MultiMesh instancing using shared geometry and materials.
## Decouples pure mathematical transform computation (worker/off-physics safe) from
## scene-tree node instantiation (main-thread commit).
## Guarantees custom_aabb for flawless frustum culling and zero monolithic memory leaks.

## Pure mathematical evaluation of foliage and greybox transforms.
## Fully thread-safe: zero scene-tree node references.
static func compute_foliage_and_decor_transforms(
	path_data: RefCounted,
	s_idx: int,
	e_idx: int,
	chunk_id_val: int,
	noise: FastNoiseLite = null,
	carver: RefCounted = null,
	side_mask: int = 3
) -> Dictionary:
	var result: Dictionary = {
		"pine": [] as Array[Transform3D],
		"birch": [] as Array[Transform3D],
		"grass": [] as Array[Transform3D],
		"boulder": [] as Array[Transform3D]
	}

	var rng := RandomNumberGenerator.new()
	var seed_offset: int = noise.seed if noise else 184729
	rng.seed = seed_offset + 98765 + chunk_id_val

	var seg_type: int = path_data.segment_types[s_idx] if s_idx < path_data.segment_types.size() else 0
	var is_open_meadow: bool = (seg_type == 14 or seg_type == 5) # 14 = RECOVERY_FLAT, 5 = MEADOW
	var tree_chance: float = 0.25 if is_open_meadow else 0.75

	# Half-open interval [s_idx, e_idx) prevents duplicate foliage at chunk boundaries
	var count_pts: int = (e_idx - s_idx) if e_idx < path_data.size() - 1 else (e_idx - s_idx + 1)
	var start_offset: int = (3 - (s_idx % 3)) % 3

	for i in range(start_offset, count_pts, 3):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var tang: Vector3 = path_data.tangents[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var norm: Vector3 = path_data.normals[idx]
		var dist: float = path_data.cumulative_distances[idx]
		var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
		var s_type: int = path_data.segment_types[idx] if idx < path_data.segment_types.size() else 0
		var half_w: float = 2.0
		if not path_data.road_widths.is_empty() and idx < path_data.road_widths.size():
			half_w = path_data.road_widths[idx] * 0.5

		# 1. Plants along left and right roadside (filtered by side_mask)
		if (side_mask & 1) != 0:
			_try_spawn_plant(pt, -binorm, norm, rng, tree_chance, result["pine"], result["birch"], result["grass"], noise)
		if (side_mask & 2) != 0:
			_try_spawn_plant(pt, binorm, norm, rng, tree_chance, result["pine"], result["birch"], result["grass"], noise)

		# 2. Low-poly boulders along CUT base (rock wall shoulder foot, filtered by side_mask)
		if carver != null:
			var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, binorm, half_w, curv, s_type, dist)
			var eval: Dictionary = cs.get("eval", {})
			# ProfileType: 0=MEADOW, 1=CUT, 2=SHELF, 3=CLIFF, 4=FILL
			if (side_mask & 1) != 0 and eval.get("left_profile", -1) == 1 and rng.randf() < 0.60:
				var b_dist_l: float = rng.randf_range(half_w + 1.0, half_w + 3.2)
				var b_pos_l: Vector3 = pt - binorm * b_dist_l
				b_pos_l.y = cs.shoulder_left_pos.y + 0.10
				var b_scale_l: float = rng.randf_range(0.70, 1.35)
				var b_rot_l: float = rng.randf_range(0.0, TAU)
				var b_basis_l := Basis(Vector3.UP, b_rot_l).scaled(Vector3.ONE * b_scale_l)
				result["boulder"].append(Transform3D(b_basis_l, b_pos_l))

			if (side_mask & 2) != 0 and eval.get("right_profile", -1) == 1 and rng.randf() < 0.60:
				var b_dist_r: float = rng.randf_range(half_w + 1.0, half_w + 3.2)
				var b_pos_r: Vector3 = pt + binorm * b_dist_r
				b_pos_r.y = cs.shoulder_right_pos.y + 0.10
				var b_scale_r: float = rng.randf_range(0.70, 1.35)
				var b_rot_r: float = rng.randf_range(0.0, TAU)
				var b_basis_r := Basis(Vector3.UP, b_rot_r).scaled(Vector3.ONE * b_scale_r)
				result["boulder"].append(Transform3D(b_basis_r, b_pos_r))

	return result

## Main-thread node instantiation helper with custom_aabb for robust frustum culling.
static func instantiate_foliage_and_decor(
	parent: Node3D,
	transforms_dict: Dictionary,
	shared_meshes: Dictionary
) -> void:
	var mesh_map := {
		"pine": {"mesh_key": "pine", "node_name": "PineMultiMesh"},
		"birch": {"mesh_key": "birch", "node_name": "BirchMultiMesh"},
		"grass": {"mesh_key": "grass", "node_name": "GrassMultiMesh"},
		"boulder": {"mesh_key": "boulder", "node_name": "BoulderMultiMesh"}
	}

	for key: String in mesh_map:
		var cfg = mesh_map[key]
		var mesh: Mesh = shared_meshes.get(cfg["mesh_key"])
		var transforms: Array = transforms_dict.get(key, [])
		if mesh != null and not transforms.is_empty():
			var mmi := MultiMeshInstance3D.new()
			mmi.name = cfg["node_name"]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = transforms.size()

			var aabb := AABB(transforms[0].origin, Vector3(0.2, 0.2, 0.2))
			for i in range(transforms.size()):
				mm.set_instance_transform(i, transforms[i])
				aabb = aabb.expand(transforms[i].origin)
			aabb = aabb.grow(4.0)

			mmi.multimesh = mm
			mmi.custom_aabb = aabb
			# Strictly visual dressing: zero participation in bicycle physics
			parent.add_child(mmi)

## Legacy convenience wrapper (for backwards compatibility with existing tests).
func populate_chunk(
	parent_chunk: Node3D,
	path_data: RefCounted,
	s_idx: int,
	e_idx: int,
	shared_meshes: Dictionary,
	noise: FastNoiseLite = null
) -> void:
	var chunk_id_val: int = parent_chunk.get("chunk_id") if "chunk_id" in parent_chunk else 0
	var transforms := compute_foliage_and_decor_transforms(path_data, s_idx, e_idx, chunk_id_val, noise, null)
	instantiate_foliage_and_decor(parent_chunk, transforms, shared_meshes)

static func _try_spawn_plant(
	center_pt: Vector3,
	lateral_dir: Vector3,
	norm: Vector3,
	rng: RandomNumberGenerator,
	tree_chance: float,
	pines: Array[Transform3D],
	birches: Array[Transform3D],
	grasses: Array[Transform3D],
	noise: FastNoiseLite = null
) -> void:
	if rng.randf() < 0.8:
		var grass_dist: float = rng.randf_range(2.6, 5.2)
		var grass_base: Vector3 = center_pt + lateral_dir * grass_dist
		var t_factor: float = clampf((grass_dist - 2.0) / 20.0, 0.0, 1.0)
		var h_grass: float = (noise.get_noise_2d(grass_base.x, grass_base.z) * 1.8) if noise else 0.0
		var grass_pos: Vector3 = grass_base + norm * (h_grass * t_factor)
		grass_pos.y -= 0.02 # Slight embed so blades sit cleanly in ground
		var t_trans := Transform3D(Basis().scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), grass_pos)
		grasses.append(t_trans)

	if rng.randf() < tree_chance:
		var tree_dist: float = rng.randf_range(5.5, 17.5)
		var tree_base: Vector3 = center_pt + lateral_dir * tree_dist
		var t_factor: float = clampf((tree_dist - 2.0) / 20.0, 0.0, 1.0)
		var h_tree: float = (noise.get_noise_2d(tree_base.x, tree_base.z) * 1.8) if noise else 0.0
		var tree_pos: Vector3 = tree_base + norm * (h_tree * t_factor)
		var scale_val: float = rng.randf_range(0.85, 1.4)
		var rot_y: float = rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * scale_val)
		var t_trans := Transform3D(basis, tree_pos)

		if rng.randf() < 0.65:
			pines.append(t_trans)
		else:
			birches.append(t_trans)
