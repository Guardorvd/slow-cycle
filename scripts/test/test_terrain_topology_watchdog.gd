extends SceneTree

## Slow Cycle — Sprint 7 Watchdog #2: Upgraded Terrain Topology & Horizon Boundary Watchdog
## Audits prepared terrain arrays; committed GPU/physics are checked separately.
## Verifies:
## 1. Zero degenerate triangles (area >= 0.0005).
## 2. Strictly upward face normal orientation (n . seg_norm > 0.0, zero CW culling inversions).
## 3. Strict lateral boundary envelope (|d_lat_horiz| <= 40.5m, zero 75m/180m sky-spikes).
## 4. Evolute clearance on sharp turns (inner horizontal span <= R * 0.70).
## 5. Topological ribbon forward-progression invariant: (V_{i+1} - V_i) . road_step_dir > 0 (zero ribbon folds).
## 6. Real Fork Chunk Splitter Wedge verification (nonempty Godot CW orientation).

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

const SurfaceAudit = preload("res://scripts/test/surface_audit_support.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777, 99999, 12345]
const CHUNKS_PER_SEED: int = 15

func _init() -> void:
	print("\n========================================================")
	print("🔍 UPGRADED SPRINT 7 WATCHDOG #2: TERRAIN TOPOLOGY AUDIT")
	print("Direct audit of prepared mesh arrays across %d seeds" % TEST_SEEDS.size())
	print("========================================================\n")

	var total_triangles_checked: int = 0
	var total_vertices_checked: int = 0
	var inverted_faces_count: int = 0
	var degenerate_triangles_count: int = 0
	var evolute_crossings_count: int = 0
	var lateral_spikes_count: int = 0
	var ribbon_fold_count: int = 0
	var wedge_triangles_checked: int = 0
	var wedge_inverted_count: int = 0
	var missing_mesh_count: int = 0

	for s in TEST_SEEDS:
		var path_data = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(s, path_data)
		var carver = TerrainCarverClass.new(s)
		var noise = FastNoiseLite.new()
		noise.seed = s

		var shared_mats = {
			"terrain_carver": carver,
			"noise": noise
		}

		for c in range(CHUNKS_PER_SEED):
			logic.plan_next_chunk()

		var pts_count: int = path_data.size()
		var chunk_step: int = 25
		var seed_defects: int = 0

		for c in range(CHUNKS_PER_SEED):
			var s_idx: int = c * chunk_step
			var e_idx: int = mini(s_idx + chunk_step, pts_count - 1)
			if s_idx >= e_idx:
				break

			var prep: RoadChunk.PreparedChunkData = RoadChunkClass.prepare_geometry_data(
				path_data, s_idx, e_idx, c, shared_mats
			)

			if not SurfaceAudit.mesh_report(prep.terrain_arrays).available:
				missing_mesh_count += 1
				seed_defects += 1
				printerr("[MESH MISSING] seed=%d chunk=%d" % [s, c])
				continue

			var v_mesh: PackedVector3Array = prep.terrain_arrays[Mesh.ARRAY_VERTEX]
			var idx_mesh: PackedInt32Array = prep.terrain_arrays[Mesh.ARRAY_INDEX]
			var num_vis_triangles: int = idx_mesh.size() / 3
			var count_pts: int = e_idx - s_idx + 1

			# --- CHECK 1: Direct Vertex Lateral Bounds ---
			for v_i in range(v_mesh.size()):
				total_vertices_checked += 1
				var vert: Vector3 = v_mesh[v_i]

				# Find closest centerline sample index within this chunk
				var min_d_sq: float = INF
				var best_idx: int = s_idx
				for scan_i in range(s_idx, e_idx + 1):
					var d_sq: float = path_data.points[scan_i].distance_squared_to(vert)
					if d_sq < min_d_sq:
						min_d_sq = d_sq
						best_idx = scan_i

				var pt: Vector3 = path_data.points[best_idx]
				var binorm: Vector3 = path_data.binormals[best_idx]
				var b_horiz: Vector3 = Vector3(binorm.x, 0.0, binorm.z).normalized()

				var lat_dist: float = (vert - pt).dot(b_horiz)
				var abs_lat: float = absf(lat_dist)

				# Hard bound: terrain must strictly stay within corridor boundary (38m from road edge, max 40.5m from centerline)
				if abs_lat > 40.5:
					lateral_spikes_count += 1
					seed_defects += 1
					printerr("  [LATERAL SPIKE] Seed %d Chunk %d V%d: lateral span=%.2fm > 40.5m!" % [
						s, c, v_i, abs_lat
					])

			# --- CHECK 2: Evolute Bound & Cross-Section Ribbon Progression ---
			for seg in range(count_pts - 1):
				var p_idx: int = s_idx + seg
				var next_idx: int = p_idx + 1

				var pt_curr: Vector3 = path_data.points[p_idx]
				var pt_next: Vector3 = path_data.points[next_idx]
				var road_step_dir: Vector3 = (pt_next - pt_curr).normalized()

				var signed_curv: float = path_data.get_signed_curvature(p_idx)
				var half_w: float = 2.0
				if not path_data.road_widths.is_empty() and p_idx < path_data.road_widths.size():
					half_w = path_data.road_widths[p_idx] * 0.5

				var cs_curr = carver.compute_cross_section(
					pt_curr, path_data.tangents[p_idx], path_data.normals[p_idx],
					path_data.binormals[p_idx], half_w, signed_curv,
					path_data.segment_types[p_idx], path_data.cumulative_distances[p_idx]
				)

				var signed_curv_next: float = path_data.get_signed_curvature(next_idx)
				var half_w_next: float = 2.0
				if not path_data.road_widths.is_empty() and next_idx < path_data.road_widths.size():
					half_w_next = path_data.road_widths[next_idx] * 0.5

				var cs_next = carver.compute_cross_section(
					pt_next, path_data.tangents[next_idx], path_data.normals[next_idx],
					path_data.binormals[next_idx], half_w_next, signed_curv_next,
					path_data.segment_types[next_idx], path_data.cumulative_distances[next_idx]
				)

				# Check evolute boundary on sharp curves (R < 50m)
				var curv: float = absf(signed_curv)
				if curv > 0.020:
					var r_turn: float = 1.0 / curv
					# Right turn: right flank (offsets[11]) is inner; Left turn: left flank (offsets[0]) is inner
					var inner_span: float = absf(cs_curr.offsets[11]) if signed_curv > 0.0 else absf(cs_curr.offsets[0])
					if inner_span > r_turn * 0.70:
						evolute_crossings_count += 1
						seed_defects += 1
						printerr("  [EVOLUTE VIOLATION] Seed %d Chunk %d Sample %d: inner span=%.2fm > R*0.70 (R=%.1fm)!" % [
							s, c, p_idx, inner_span, r_turn
						])

				# Check ribbon forward progression across all 12 columns in horizontal plan view
				var tang_curr: Vector3 = path_data.tangents[p_idx]
				var t_horiz: Vector3 = Vector3(tang_curr.x, 0.0, tang_curr.z).normalized()

				for col in range(12):
					var p0: Vector3 = cs_curr.vertices[col]
					var p1: Vector3 = cs_next.vertices[col]
					var step_horiz: Vector3 = Vector3(p1.x - p0.x, 0.0, p1.z - p0.z)
					var fwd_proj: float = step_horiz.dot(t_horiz)
					if fwd_proj <= 0.0:
						ribbon_fold_count += 1
						seed_defects += 1
						printerr("  [RIBBON FOLD] Seed %d Chunk %d Seg %d Col %d: fwd_proj = %.4f <= 0!" % [
							s, c, seg, col, fwd_proj
						])

			# --- CHECK 3: Triangle Geometry & Face Normal Orientation ---
			for t_i in range(num_vis_triangles):
				total_triangles_checked += 1
				var p0: Vector3 = v_mesh[idx_mesh[t_i * 3 + 0]]
				var p1: Vector3 = v_mesh[idx_mesh[t_i * 3 + 1]]
				var p2: Vector3 = v_mesh[idx_mesh[t_i * 3 + 2]]

				var e1: Vector3 = p1 - p0
				var e2: Vector3 = p2 - p0
				var cross: Vector3 = e1.cross(e2)
				var area: float = cross.length() * 0.5

				# Sliver degeneracy
				if area < 0.0005:
					degenerate_triangles_count += 1
					seed_defects += 1
					continue

				var face_norm: Vector3 = -cross.normalized() # Godot CW outward normal
				# Check orientation against road normal of this chunk
				var mid_idx: int = clampi(s_idx + count_pts / 2, 0, path_data.size() - 1)
				var ref_norm: Vector3 = path_data.normals[mid_idx]

				if face_norm.dot(ref_norm) <= 0.0:
					inverted_faces_count += 1
					seed_defects += 1
					printerr("  [INVERTED VISUAL FACE] Seed %d Chunk %d Tri %d: n.ref = %.3f <= 0.0! n=(%.2f, %.2f, %.2f)" % [
						s, c, t_i, face_norm.dot(ref_norm), face_norm.x, face_norm.y, face_norm.z
					])

		if seed_defects > 0:
			print("  -> Seed %d: %d topology defects detected" % [s, seed_defects])
		else:
			print("  -> Seed %d: CLEAR (0 defects across %d chunks)" % [s, CHUNKS_PER_SEED])

	# --- CHECK 4: Dedicated Fork Splitter Wedge Audit ---
	print("\n--- Auditing Splitter Wedge Geometry on Fork Arms ---")
	for s in [184729, 42, 77777]:
		var path_data = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(s, path_data)
		var carver = TerrainCarverClass.new(s)
		var noise = FastNoiseLite.new()
		noise.seed = s
		var shared_mats = {"terrain_carver": carver, "noise": noise}

		# Generate 2 chunks to build path
		logic.plan_next_chunk()
		logic.plan_next_chunk()

		var s_idx: int = 0
		var e_idx: int = 24
		var count_pts: int = e_idx - s_idx + 1

		# Simulate diverging right arm inner vertices
		var simulated_opposite := PackedVector3Array()
		simulated_opposite.resize(count_pts)
		for i in range(count_pts):
			var pt: Vector3 = path_data.points[i]
			var binorm: Vector3 = path_data.binormals[i]
			var dist_frac: float = float(i) / float(count_pts - 1)
			var spread: float = lerpf(0.2, 4.5, dist_frac)
			simulated_opposite[i] = pt + binorm * (1.8 + spread)

		var fork_ctx := {
			"terrain_side_mask": 1,
			"wedge_opposite_inner_verts": Array(simulated_opposite),
			"is_fork_arm": true
		}

		var prep_fork: RoadChunk.PreparedChunkData = RoadChunkClass.prepare_geometry_data(
			path_data, s_idx, e_idx, 0, shared_mats, null, true, Vector3.FORWARD, fork_ctx
		)

		var tf: PackedVector3Array = prep_fork.terrain_faces
		var num_faces: int = tf.size() / 3
		if not SurfaceAudit.wedge_valid(prep_fork, true):
			printerr("[WEDGE MISSING/INVALID] seed=%d range=%d+%d" % [s, prep_fork.terrain_wedge_first_triangle, prep_fork.terrain_wedge_triangle_count])
			wedge_inverted_count += 1
		var wedge_face_start: int = prep_fork.terrain_wedge_first_triangle
		var wedge_face_end: int = wedge_face_start + prep_fork.terrain_wedge_triangle_count
		for t_i in range(wedge_face_start, wedge_face_end):
			wedge_triangles_checked += 1
			var p0: Vector3 = tf[t_i * 3 + 0]
			var p1: Vector3 = tf[t_i * 3 + 1]
			var p2: Vector3 = tf[t_i * 3 + 2]
			var cross: Vector3 = (p1 - p0).cross(p2 - p0)
			var area: float = cross.length() * 0.5
			if area < 0.0005:
				degenerate_triangles_count += 1
				continue
			var n: Vector3 = -cross.normalized()
			if n.y < 0.20:
				wedge_inverted_count += 1
				printerr("  [WEDGE INVERSION] Seed %d Fork Wedge Tri %d: Ny=%.3f < 0.20!" % [s, t_i, n.y])

	print("  -> Checked %d splitter wedge triangles across 3 fork setups (Inverted: %d)" % [
		wedge_triangles_checked, wedge_inverted_count
	])

	print("\n--------------------------------------------------------")
	print("Summary of Mesh Audits:")
	print("  - Total vertices audited: %d" % total_vertices_checked)
	print("  - Total triangles audited: %d" % total_triangles_checked)
	print("  - Lateral spikes (|d_lat_horiz| > 40.5m): %d" % lateral_spikes_count)
	print("  - Skirt evolute crossings: %d" % evolute_crossings_count)
	print("  - Ribbon topological folds: %d" % ribbon_fold_count)
	print("  - Degenerate slivers: %d" % degenerate_triangles_count)
	print("  - Inverted faces: %d" % inverted_faces_count)
	print("  - Wedge inverted faces: %d" % wedge_inverted_count)

	var total_defects: int = missing_mesh_count + lateral_spikes_count + evolute_crossings_count + ribbon_fold_count + degenerate_triangles_count + inverted_faces_count + wedge_inverted_count
	if total_triangles_checked == 0 or wedge_triangles_checked == 0:
		total_defects += 1
	if total_defects > 0:
		print("❌ [WATCHDOG FAIL] Terrain topology defects detected (%d violations)" % total_defects)
		quit(1)
	else:
		print("✅ [WATCHDOG PASS] Prepared terrain checks passed; GPU/physics require separate coverage.")
		quit(0)
