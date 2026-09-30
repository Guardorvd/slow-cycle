class_name RoadChunk
extends Node3D

## Slow Cycle — Road Chunk (FEAT-014.5)
## Pure geometry container and scene-commit node.
## Decouples asynchronous/off-physics geometry computation (prepare_geometry_data)
## from main-thread-safe scene and physics registration (commit).
## Guaranteed commit budget <= 0.5 ms via precomputed ConcavePolygonShape3D faces.

const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

const ROAD_HALF_WIDTH: float = 0.9 ## Standard 1.8m singletrack width baseline
const TERRAIN_WIDTH: float = 20.0 ## 20m roadside meadow strip

# ==============================================================================
# DATA TRANSFER OBJECT FOR ASYNC / DECOUPLED GENERATION
# ==============================================================================

class PreparedChunkData extends RefCounted:
	var token: RefCounted = null                ## GenerationToken (for stale-result invalidation)
	var chunk_id: int = 0
	var foliage_seed_key: int = -1
	var start_sample_idx: int = 0
	var end_sample_idx: int = 0
	var is_rough: bool = false
	var road_arrays: Array = []                 ## SurfaceTool mesh arrays for road
	var terrain_arrays: Array = []              ## SurfaceTool mesh arrays for terrain
	var road_faces: PackedVector3Array = PackedVector3Array()    ## Raw triangle faces for instant collision
	var terrain_faces: PackedVector3Array = PackedVector3Array() ## Raw triangle faces for instant collision
	var foliage_transforms: Dictionary = {}
	var timings: Dictionary = {}

var chunk_id: int = 0
var start_sample_idx: int = 0
var end_sample_idx: int = 0
var default_road_collision_layer: int = 2

var road_body: StaticBody3D
var terrain_body: StaticBody3D
var road_mesh_inst: MeshInstance3D
var terrain_mesh_inst: MeshInstance3D

# ==============================================================================
# PHASE 1: GEOMETRY & DATA PREPARATION (Isolated from Physics)
# ==============================================================================

static func prepare_geometry_data(
	path_data: RefCounted,
	s_idx: int,
	e_idx: int,
	id: int,
	shared_materials: Dictionary,
	token: RefCounted = null,
	is_fork_chunk: bool = false,
	fork_tangent: Vector3 = Vector3.FORWARD,
	fork_context: Dictionary = {},
	foliage_seed_key: int = -1
) -> PreparedChunkData:
	var t0: int = Time.get_ticks_usec()
	var prep := PreparedChunkData.new()
	prep.token = token
	prep.chunk_id = id
	prep.foliage_seed_key = foliage_seed_key
	prep.start_sample_idx = s_idx
	prep.end_sample_idx = e_idx

	var count: int = e_idx - s_idx + 1
	if count < 2:
		return prep

	var side_mask: int = fork_context.get("terrain_side_mask", 3)
	var wedge_opposite: Array = fork_context.get("wedge_opposite_inner_verts", [])

	# 1. Segment roughness check
	var is_rough: bool = false
	if "segment_types" in path_data and path_data.segment_types.size() > e_idx:
		for i in range(s_idx, e_idx + 1):
			if path_data.segment_types[i] == RoadPathDataClass.SegmentType.ROUGH_GRAVEL:
				is_rough = true
				break
	prep.is_rough = is_rough

	# 2. Prepare Road Mesh Arrays
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)

	var road_verts_left: Array[Vector3] = []
	var road_verts_right: Array[Vector3] = []

	for i in range(count):
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
			var t_chunk: float = float(i) / float(maxi(count - 1, 1))
			var envelope: float = smoothstep(0.0, 0.15, t_chunk) * smoothstep(1.0, 0.85, t_chunk)
			var bump: float = 0.025 * sin(dist * 2.5) * envelope
			v_left.y += bump
			v_right.y += bump

		road_verts_left.append(v_left)
		road_verts_right.append(v_right)

		var v_coord: float = dist * 0.25

		st_road.set_normal(norm)
		st_road.set_uv(Vector2(0.0, v_coord))
		st_road.add_vertex(v_left)

		st_road.set_normal(norm)
		st_road.set_uv(Vector2(1.0, v_coord))
		st_road.add_vertex(v_right)

	# Road Indices & Faces
	var road_faces := PackedVector3Array()
	road_faces.resize((count - 1) * 6)
	var face_idx: int = 0

	for i in range(count - 1):
		var i0: int = i * 2
		var i1: int = i * 2 + 1
		var i2: int = (i + 1) * 2
		var i3: int = (i + 1) * 2 + 1

		st_road.add_index(i0)
		st_road.add_index(i2)
		st_road.add_index(i1)

		st_road.add_index(i1)
		st_road.add_index(i2)
		st_road.add_index(i3)

		var vl0: Vector3 = road_verts_left[i]
		var vr0: Vector3 = road_verts_right[i]
		var vl1: Vector3 = road_verts_left[i + 1]
		var vr1: Vector3 = road_verts_right[i + 1]

		# Triangle 1 (i0, i2, i1)
		road_faces[face_idx] = vl0; face_idx += 1
		road_faces[face_idx] = vl1; face_idx += 1
		road_faces[face_idx] = vr0; face_idx += 1

		# Triangle 2 (i1, i2, i3)
		road_faces[face_idx] = vr0; face_idx += 1
		road_faces[face_idx] = vl1; face_idx += 1
		road_faces[face_idx] = vr1; face_idx += 1

	prep.road_arrays = st_road.commit_to_arrays()
	prep.road_faces = road_faces

	# 3. Prepare Mountain Terrain Mesh Arrays
	var carver: RefCounted = shared_materials.get("terrain_carver")
	var noise: FastNoiseLite = shared_materials.get("noise")
	assert(noise != null, "Terrain noise must be provided by WorldManager")
	if carver == null:
		var s_seed: int = noise.seed if noise else 184729
		carver = TerrainCarverClass.new(s_seed)

	var st_terr := SurfaceTool.new()
	st_terr.begin(Mesh.PRIMITIVE_TRIANGLES)

	var all_terrain_verts: Array[PackedVector3Array] = []
	all_terrain_verts.resize(count)

	for i in range(count):
		var idx: int = s_idx + i
		var pt: Vector3 = path_data.points[idx]
		var tang: Vector3 = path_data.tangents[idx]
		var norm: Vector3 = path_data.normals[idx]
		var binorm: Vector3 = path_data.binormals[idx]
		var dist: float = path_data.cumulative_distances[idx]
		var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
		var seg_type: int = path_data.segment_types[idx] if idx < path_data.segment_types.size() else 0

		# Compute smooth signed lateral curvature (+b = turning right, -b = turning left)
		var next_idx: int = mini(idx + 1, path_data.size() - 1)
		var prev_idx: int = maxi(0, idx - 1)
		var dt: Vector3 = path_data.tangents[next_idx] - path_data.tangents[prev_idx]
		var ds_span: float = maxf(0.001, path_data.cumulative_distances[next_idx] - path_data.cumulative_distances[prev_idx])
		var turn_proj: float = dt.dot(binorm)
		var k_lat: float = turn_proj / ds_span
		var signed_curv: float = clampf(k_lat, -curv, curv) if curv > 0.0 else 0.0

		var half_w: float = ROAD_HALF_WIDTH
		if not path_data.road_widths.is_empty() and idx < path_data.road_widths.size():
			half_w = path_data.road_widths[idx] * 0.5

		var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, binorm, half_w, signed_curv, seg_type, dist)
		var verts: PackedVector3Array = cs.vertices
		var uvs: PackedVector2Array = cs.uvs
		all_terrain_verts[i] = verts

		for v_idx in range(8):
			st_terr.set_normal(norm)
			st_terr.set_uv(uvs[v_idx])
			st_terr.add_vertex(verts[v_idx])

	# Quad strips across the corridor filtered by side_mask (0,1,2 = Left outer, 4,5,6 = Right outer)
	var active_strip_cols: Array[int] = []
	if (side_mask & 1) != 0:
		active_strip_cols.append_array([0, 1, 2])
	if (side_mask & 2) != 0:
		active_strip_cols.append_array([4, 5, 6])

	var terr_faces := PackedVector3Array()
	var t_face_idx: int = 0
	terr_faces.resize((count - 1) * active_strip_cols.size() * 6)

	for i in range(count - 1):
		var row_curr: int = i * 8
		var row_next: int = (i + 1) * 8
		var v_row_curr: PackedVector3Array = all_terrain_verts[i]
		var v_row_next: PackedVector3Array = all_terrain_verts[i + 1]

		var seg_norm: Vector3 = path_data.normals[s_idx + i]

		for col: int in active_strip_cols:
			var i0: int = row_curr + col
			var i1: int = row_curr + col + 1
			var i2: int = row_next + col
			var i3: int = row_next + col + 1

			var p0: Vector3 = v_row_curr[col]
			var p1: Vector3 = v_row_curr[col + 1]
			var p2: Vector3 = v_row_next[col]
			var p3: Vector3 = v_row_next[col + 1]

			# Shortest-diagonal candidates
			var i_a1: int; var i_b1: int; var i_c1: int
			var p_a1: Vector3; var p_b1: Vector3; var p_c1: Vector3
			var i_a2: int; var i_b2: int; var i_c2: int
			var p_a2: Vector3; var p_b2: Vector3; var p_c2: Vector3

			if p0.distance_squared_to(p3) < p1.distance_squared_to(p2):
				i_a1 = i0; i_b1 = i1; i_c1 = i3
				p_a1 = p0; p_b1 = p1; p_c1 = p3
				i_a2 = i0; i_b2 = i3; i_c2 = i2
				p_a2 = p0; p_b2 = p3; p_c2 = p2
			else:
				i_a1 = i0; i_b1 = i1; i_c1 = i2
				p_a1 = p0; p_b1 = p1; p_c1 = p2
				i_a2 = i1; i_b2 = i3; i_c2 = i2
				p_a2 = p1; p_b2 = p3; p_c2 = p2

			# Tri 1: strictly oriented UP along seg_norm
			if (p_b1 - p_a1).cross(p_c1 - p_a1).dot(seg_norm) >= 0.0:
				st_terr.add_index(i_a1); st_terr.add_index(i_b1); st_terr.add_index(i_c1)
				terr_faces[t_face_idx] = p_a1; t_face_idx += 1
				terr_faces[t_face_idx] = p_b1; t_face_idx += 1
				terr_faces[t_face_idx] = p_c1; t_face_idx += 1
			else:
				st_terr.add_index(i_a1); st_terr.add_index(i_c1); st_terr.add_index(i_b1)
				terr_faces[t_face_idx] = p_a1; t_face_idx += 1
				terr_faces[t_face_idx] = p_c1; t_face_idx += 1
				terr_faces[t_face_idx] = p_b1; t_face_idx += 1

			# Tri 2: strictly oriented UP along seg_norm
			if (p_b2 - p_a2).cross(p_c2 - p_a2).dot(seg_norm) >= 0.0:
				st_terr.add_index(i_a2); st_terr.add_index(i_b2); st_terr.add_index(i_c2)
				terr_faces[t_face_idx] = p_a2; t_face_idx += 1
				terr_faces[t_face_idx] = p_b2; t_face_idx += 1
				terr_faces[t_face_idx] = p_c2; t_face_idx += 1
			else:
				st_terr.add_index(i_a2); st_terr.add_index(i_c2); st_terr.add_index(i_b2)
				terr_faces[t_face_idx] = p_a2; t_face_idx += 1
				terr_faces[t_face_idx] = p_c2; t_face_idx += 1
				terr_faces[t_face_idx] = p_b2; t_face_idx += 1

	# Far Outer Skirt (Phase 7R.3: Closed Horizon sealing out to 180m into atmospheric fog)
	# Pure visual extension (collision_layer = 0) with zero physics cost.
	var skirt_v_offset: int = count * 8
	var has_left_skirt: bool = (side_mask & 1) != 0
	var has_right_skirt: bool = (side_mask & 2) != 0

	var base_l_mid: int = skirt_v_offset
	if has_left_skirt:
		skirt_v_offset += count
	var base_l_far: int = skirt_v_offset
	if has_left_skirt:
		skirt_v_offset += count

	var base_r_mid: int = skirt_v_offset
	if has_right_skirt:
		skirt_v_offset += count
	var base_r_far: int = skirt_v_offset
	if has_right_skirt:
		skirt_v_offset += count

	var all_skirt_l_mid := PackedVector3Array()
	var all_skirt_l_far := PackedVector3Array()
	var all_skirt_r_mid := PackedVector3Array()
	var all_skirt_r_far := PackedVector3Array()

	if has_left_skirt:
		all_skirt_l_mid.resize(count)
		all_skirt_l_far.resize(count)
		for i in range(count):
			var idx: int = s_idx + i
			var pt: Vector3 = path_data.points[idx]
			var norm: Vector3 = path_data.normals[idx]
			var binorm: Vector3 = path_data.binormals[idx]
			var dist: float = path_data.cumulative_distances[idx]
			var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
			var abs_k: float = absf(curv)
			var r_loc: float = (1.0 / abs_k) if abs_k > 0.001 else 9999.0

			var center_macro: float = carver.get_macro_elevation(pt.x, pt.z)
			var uv_y: float = dist * 0.08

			var d_mid_l: float = 75.0
			if curv < -0.001:
				d_mid_l = minf(75.0, maxf(25.0, r_loc * 0.45))

			var p_mid_l: Vector3 = pt - binorm * d_mid_l
			p_mid_l.y = pt.y + carver.get_macro_elevation(p_mid_l.x, p_mid_l.z) - center_macro
			st_terr.set_normal(norm)
			st_terr.set_uv(Vector2(-1.5, uv_y))
			st_terr.add_vertex(p_mid_l)
			all_skirt_l_mid[i] = p_mid_l

		for i in range(count):
			var idx: int = s_idx + i
			var pt: Vector3 = path_data.points[idx]
			var norm: Vector3 = path_data.normals[idx]
			var binorm: Vector3 = path_data.binormals[idx]
			var dist: float = path_data.cumulative_distances[idx]
			var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
			var abs_k: float = absf(curv)
			var r_loc: float = (1.0 / abs_k) if abs_k > 0.001 else 9999.0

			var center_macro: float = carver.get_macro_elevation(pt.x, pt.z)
			var uv_y: float = dist * 0.08

			var d_far_l: float = 180.0
			if curv < -0.001:
				d_far_l = minf(180.0, maxf(40.0, r_loc * 0.75))

			var p_far_l: Vector3 = pt - binorm * d_far_l
			p_far_l.y = pt.y + carver.get_macro_elevation(p_far_l.x, p_far_l.z) - center_macro - 6.0
			st_terr.set_normal(norm)
			st_terr.set_uv(Vector2(-4.0, uv_y))
			st_terr.add_vertex(p_far_l)
			all_skirt_l_far[i] = p_far_l

	if has_right_skirt:
		all_skirt_r_mid.resize(count)
		all_skirt_r_far.resize(count)
		for i in range(count):
			var idx: int = s_idx + i
			var pt: Vector3 = path_data.points[idx]
			var norm: Vector3 = path_data.normals[idx]
			var binorm: Vector3 = path_data.binormals[idx]
			var dist: float = path_data.cumulative_distances[idx]
			var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
			var abs_k: float = absf(curv)
			var r_loc: float = (1.0 / abs_k) if abs_k > 0.001 else 9999.0

			var center_macro: float = carver.get_macro_elevation(pt.x, pt.z)
			var uv_y: float = dist * 0.08

			var d_mid_r: float = 75.0
			if curv > 0.001:
				d_mid_r = minf(75.0, maxf(25.0, r_loc * 0.45))

			var p_mid_r: Vector3 = pt + binorm * d_mid_r
			p_mid_r.y = pt.y + carver.get_macro_elevation(p_mid_r.x, p_mid_r.z) - center_macro
			st_terr.set_normal(norm)
			st_terr.set_uv(Vector2(2.5, uv_y))
			st_terr.add_vertex(p_mid_r)
			all_skirt_r_mid[i] = p_mid_r

		for i in range(count):
			var idx: int = s_idx + i
			var pt: Vector3 = path_data.points[idx]
			var norm: Vector3 = path_data.normals[idx]
			var binorm: Vector3 = path_data.binormals[idx]
			var dist: float = path_data.cumulative_distances[idx]
			var curv: float = path_data.curvatures[idx] if idx < path_data.curvatures.size() else 0.0
			var abs_k: float = absf(curv)
			var r_loc: float = (1.0 / abs_k) if abs_k > 0.001 else 9999.0

			var center_macro: float = carver.get_macro_elevation(pt.x, pt.z)
			var uv_y: float = dist * 0.08

			var d_far_r: float = 180.0
			if curv > 0.001:
				d_far_r = minf(180.0, maxf(40.0, r_loc * 0.75))

			var p_far_r: Vector3 = pt + binorm * d_far_r
			p_far_r.y = pt.y + carver.get_macro_elevation(p_far_r.x, p_far_r.z) - center_macro - 6.0
			st_terr.set_normal(norm)
			st_terr.set_uv(Vector2(5.0, uv_y))
			st_terr.add_vertex(p_far_r)
			all_skirt_r_far[i] = p_far_r

	# Triangulate outer skirt rings (strictly oriented UP along seg_norm to eliminate backface culling tears)
	for i in range(count - 1):
		var seg_norm: Vector3 = path_data.normals[s_idx + i]

		if has_left_skirt:
			var i0: int = base_l_mid + i
			var i1: int = i * 8
			var i2: int = base_l_mid + i + 1
			var i3: int = (i + 1) * 8
			var p_i0: Vector3 = all_skirt_l_mid[i]
			var p_i1: Vector3 = all_terrain_verts[i][0]
			var p_i2: Vector3 = all_skirt_l_mid[i + 1]
			var p_i3: Vector3 = all_terrain_verts[i + 1][0]

			if (p_i3 - p_i0).cross(p_i1 - p_i0).dot(seg_norm) >= 0.0:
				st_terr.add_index(i0); st_terr.add_index(i3); st_terr.add_index(i1)
			else:
				st_terr.add_index(i0); st_terr.add_index(i1); st_terr.add_index(i3)

			if (p_i2 - p_i0).cross(p_i3 - p_i0).dot(seg_norm) >= 0.0:
				st_terr.add_index(i0); st_terr.add_index(i2); st_terr.add_index(i3)
			else:
				st_terr.add_index(i0); st_terr.add_index(i3); st_terr.add_index(i2)

			var f0: int = base_l_far + i
			var f1: int = base_l_mid + i
			var f2: int = base_l_far + i + 1
			var f3: int = base_l_mid + i + 1
			var p_f0: Vector3 = all_skirt_l_far[i]
			var p_f1: Vector3 = all_skirt_l_mid[i]
			var p_f2: Vector3 = all_skirt_l_far[i + 1]
			var p_f3: Vector3 = all_skirt_l_mid[i + 1]

			if (p_f3 - p_f0).cross(p_f1 - p_f0).dot(seg_norm) >= 0.0:
				st_terr.add_index(f0); st_terr.add_index(f3); st_terr.add_index(f1)
			else:
				st_terr.add_index(f0); st_terr.add_index(f1); st_terr.add_index(f3)

			if (p_f2 - p_f0).cross(p_f3 - p_f0).dot(seg_norm) >= 0.0:
				st_terr.add_index(f0); st_terr.add_index(f2); st_terr.add_index(f3)
			else:
				st_terr.add_index(f0); st_terr.add_index(f3); st_terr.add_index(f2)

		if has_right_skirt:
			var r0: int = i * 8 + 7
			var r1: int = base_r_mid + i
			var r2: int = (i + 1) * 8 + 7
			var r3: int = base_r_mid + i + 1
			var p_r0: Vector3 = all_terrain_verts[i][7]
			var p_r1: Vector3 = all_skirt_r_mid[i]
			var p_r2: Vector3 = all_terrain_verts[i + 1][7]
			var p_r3: Vector3 = all_skirt_r_mid[i + 1]

			if (p_r3 - p_r0).cross(p_r1 - p_r0).dot(seg_norm) >= 0.0:
				st_terr.add_index(r0); st_terr.add_index(r3); st_terr.add_index(r1)
			else:
				st_terr.add_index(r0); st_terr.add_index(r1); st_terr.add_index(r3)

			if (p_r2 - p_r0).cross(p_r3 - p_r0).dot(seg_norm) >= 0.0:
				st_terr.add_index(r0); st_terr.add_index(r2); st_terr.add_index(r3)
			else:
				st_terr.add_index(r0); st_terr.add_index(r3); st_terr.add_index(r2)

			var rf0: int = base_r_mid + i
			var rf1: int = base_r_far + i
			var rf2: int = base_r_mid + i + 1
			var rf3: int = base_r_far + i + 1
			var p_rf0: Vector3 = all_skirt_r_mid[i]
			var p_rf1: Vector3 = all_skirt_r_far[i]
			var p_rf2: Vector3 = all_skirt_r_mid[i + 1]
			var p_rf3: Vector3 = all_skirt_r_far[i + 1]

			if (p_rf3 - p_rf0).cross(p_rf1 - p_rf0).dot(seg_norm) >= 0.0:
				st_terr.add_index(rf0); st_terr.add_index(rf3); st_terr.add_index(rf1)
			else:
				st_terr.add_index(rf0); st_terr.add_index(rf1); st_terr.add_index(rf3)

			if (p_rf2 - p_rf0).cross(p_rf3 - p_rf0).dot(seg_norm) >= 0.0:
				st_terr.add_index(rf0); st_terr.add_index(rf2); st_terr.add_index(rf3)
			else:
				st_terr.add_index(rf0); st_terr.add_index(rf3); st_terr.add_index(rf2)

	# Splitter Wedge: connect road_verts_right (Left arm inner) to wedge_opposite (Right arm inner)
	if not wedge_opposite.is_empty() and wedge_opposite.size() >= count:
		var curr_w_base: int = skirt_v_offset
		for i in range(count - 1):
			var p_l0: Vector3 = road_verts_right[i]
			var p_r0: Vector3 = wedge_opposite[i]
			var p_l1: Vector3 = road_verts_right[i + 1]
			var p_r1: Vector3 = wedge_opposite[i + 1]

			var w0: float = p_l0.distance_to(p_r0)
			var w1: float = p_l1.distance_to(p_r1)
			if w0 < 0.15 and w1 < 0.15:
				continue

			var p_m0: Vector3 = (p_l0 + p_r0) * 0.5
			p_m0.y += minf(0.35, w0 * 0.04) - 0.04
			var p_m1: Vector3 = (p_l1 + p_r1) * 0.5
			p_m1.y += minf(0.35, w1 * 0.04) - 0.04

			var dist_i0: float = path_data.cumulative_distances[s_idx + i]
			var dist_i1: float = path_data.cumulative_distances[s_idx + i + 1]
			var uv_y0: float = dist_i0 * 0.15
			var uv_y1: float = dist_i1 * 0.15
			var norm_up: Vector3 = Vector3.UP

			# Triangle 1: (p_l0, p_l1, p_m0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.3, uv_y0)); st_terr.add_vertex(p_l0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.3, uv_y1)); st_terr.add_vertex(p_l1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y0)); st_terr.add_vertex(p_m0)
			st_terr.add_index(curr_w_base + 0); st_terr.add_index(curr_w_base + 1); st_terr.add_index(curr_w_base + 2)
			terr_faces.append(p_l0); terr_faces.append(p_l1); terr_faces.append(p_m0)

			# Triangle 2: (p_m0, p_l1, p_m1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y0)); st_terr.add_vertex(p_m0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.3, uv_y1)); st_terr.add_vertex(p_l1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y1)); st_terr.add_vertex(p_m1)
			st_terr.add_index(curr_w_base + 3); st_terr.add_index(curr_w_base + 4); st_terr.add_index(curr_w_base + 5)
			terr_faces.append(p_m0); terr_faces.append(p_l1); terr_faces.append(p_m1)

			# Triangle 3: (p_m0, p_m1, p_r0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y0)); st_terr.add_vertex(p_m0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y1)); st_terr.add_vertex(p_m1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.7, uv_y0)); st_terr.add_vertex(p_r0)
			st_terr.add_index(curr_w_base + 6); st_terr.add_index(curr_w_base + 7); st_terr.add_index(curr_w_base + 8)
			terr_faces.append(p_m0); terr_faces.append(p_m1); terr_faces.append(p_r0)

			# Triangle 4: (p_r0, p_m1, p_r1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.7, uv_y0)); st_terr.add_vertex(p_r0)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.5, uv_y1)); st_terr.add_vertex(p_m1)
			st_terr.set_normal(norm_up); st_terr.set_uv(Vector2(0.7, uv_y1)); st_terr.add_vertex(p_r1)
			st_terr.add_index(curr_w_base + 9); st_terr.add_index(curr_w_base + 10); st_terr.add_index(curr_w_base + 11)
			terr_faces.append(p_r0); terr_faces.append(p_m1); terr_faces.append(p_r1)

			curr_w_base += 12

	prep.terrain_arrays = st_terr.commit_to_arrays()
	prep.terrain_faces = terr_faces

	# 4. Foliage & Boulders Transforms (filtered by side_mask to protect road junction and wedge)
	prep.foliage_transforms = ChunkFoliageClass.compute_foliage_and_decor_transforms(
		path_data, s_idx, e_idx, id, noise, carver, side_mask, foliage_seed_key
	)

	var t1: int = Time.get_ticks_usec()
	prep.timings["t_prepare"] = float(t1 - t0) / 1000.0
	return prep

# ==============================================================================
# PHASE 2: SYNCHRONOUS SCENE & PHYSICS COMMIT (Budget <= 0.5 ms)
# ==============================================================================

func commit(
	prep: PreparedChunkData,
	shared_materials: Dictionary,
	shared_meshes: Dictionary
) -> Dictionary:
	var t_start: int = Time.get_ticks_usec()

	chunk_id = prep.chunk_id
	start_sample_idx = prep.start_sample_idx
	end_sample_idx = prep.end_sample_idx
	name = "Chunk_%d" % chunk_id
	default_road_collision_layer = (2 | 16) if prep.is_rough else 2

	# 1. Mesh Commit
	var t_m0: int = Time.get_ticks_usec()
	var road_mesh := ArrayMesh.new()
	if not prep.road_arrays.is_empty():
		road_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prep.road_arrays)
		var road_mat: Material = shared_materials.get("road")
		if road_mat:
			road_mesh.surface_set_material(0, road_mat)

	var terrain_mesh := ArrayMesh.new()
	if not prep.terrain_arrays.is_empty():
		terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, prep.terrain_arrays)
		var grass_mat: Material = shared_materials.get("grass")
		if grass_mat:
			terrain_mesh.surface_set_material(0, grass_mat)
	var t_m1: int = Time.get_ticks_usec()

	# 2. Collision Commit (Instant set_faces without PhysicsServer overhead)
	var t_c0: int = Time.get_ticks_usec()
	road_body = StaticBody3D.new()
	road_body.collision_layer = default_road_collision_layer
	road_body.collision_mask = 0
	if prep.is_rough:
		road_body.set_meta("surface_type", "rough_gravel")
		road_body.add_to_group("surface_rough_gravel")

	var road_col_shape := CollisionShape3D.new()
	if not prep.road_faces.is_empty():
		var r_shape := ConcavePolygonShape3D.new()
		r_shape.set_faces(prep.road_faces)
		road_col_shape.shape = r_shape
	elif road_mesh.get_surface_count() > 0:
		road_col_shape.shape = road_mesh.create_trimesh_shape()
	road_body.add_child(road_col_shape)

	terrain_body = StaticBody3D.new()
	terrain_body.collision_layer = 4 # Layer 3 Grass / Mountain Terrain
	terrain_body.collision_mask = 0
	terrain_body.set_meta("surface_type", "mountain_terrain")

	var terr_col_shape := CollisionShape3D.new()
	if not prep.terrain_faces.is_empty():
		var t_shape := ConcavePolygonShape3D.new()
		t_shape.set_faces(prep.terrain_faces)
		terr_col_shape.shape = t_shape
	elif terrain_mesh.get_surface_count() > 0:
		terr_col_shape.shape = terrain_mesh.create_trimesh_shape()
	terrain_body.add_child(terr_col_shape)
	var t_c1: int = Time.get_ticks_usec()

	# 3. Node Attachment
	var t_n0: int = Time.get_ticks_usec()
	road_mesh_inst = MeshInstance3D.new()
	road_mesh_inst.mesh = road_mesh
	add_child(road_mesh_inst)
	add_child(road_body)

	terrain_mesh_inst = MeshInstance3D.new()
	terrain_mesh_inst.mesh = terrain_mesh
	add_child(terrain_mesh_inst)
	add_child(terrain_body)
	var t_n1: int = Time.get_ticks_usec()

	# 4. Decoration Commit (Strictly collision_layer = 0, zero physics participation)
	var t_d0: int = Time.get_ticks_usec()
	ChunkFoliageClass.instantiate_foliage_and_decor(self, prep.foliage_transforms, shared_meshes)
	var t_d1: int = Time.get_ticks_usec()

	var t_end: int = Time.get_ticks_usec()

	var result_timings := {
		"t_prepare": prep.timings.get("t_prepare", 0.0),
		"t_mesh": float(t_m1 - t_m0) / 1000.0,
		"t_collision": float(t_c1 - t_c0) / 1000.0,
		"t_nodes": float(t_n1 - t_n0) / 1000.0,
		"t_decor": float(t_d1 - t_d0) / 1000.0,
		"t_total": float(t_end - t_start) / 1000.0
	}
	return result_timings

# ==============================================================================
# PHYSICAL DORMANT DEACTIVATION
# ==============================================================================

## Instantly enables or disables physics collisions without destroying scene hierarchy.
## Used for seamless transition of branches to DORMANT to prevent ghost collisions.
func set_physics_enabled(enabled: bool) -> void:
	if is_instance_valid(road_body):
		road_body.collision_layer = default_road_collision_layer if enabled else 0
	if is_instance_valid(terrain_body):
		terrain_body.collision_layer = 4 if enabled else 0

# ==============================================================================
# MULTIMESH CHILD HELPER WITH CUSTOM AABB
# ==============================================================================

func _build_multimesh_child(mesh: Mesh, transforms: Array[Transform3D], node_name: String) -> void:
	if mesh == null or transforms.is_empty():
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()

	var aabb := AABB(transforms[0].origin, Vector3(0.1, 0.1, 0.1))
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		aabb = aabb.expand(transforms[i].origin)
	aabb = aabb.grow(3.0)

	mmi.multimesh = mm
	mmi.custom_aabb = aabb
	add_child(mmi)

# ==============================================================================
# BACKWARD COMPATIBLE API (Retained for existing test runners)
# ==============================================================================

func build_chunk(
	path_data: RefCounted,
	s_idx: int,
	e_idx: int,
	id: int,
	shared_materials: Dictionary,
	shared_meshes: Dictionary
) -> void:
	var prep = prepare_geometry_data(path_data, s_idx, e_idx, id, shared_materials)
	commit(prep, shared_materials, shared_meshes)
