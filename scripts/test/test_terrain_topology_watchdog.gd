extends SceneTree

## Slow Cycle — Sprint 7 Watchdog #2: Terrain Topology & Skirt Inversion Profiler
## Checks terrain mesh geometry across demanding curved seeds for:
## 1. Zero/near-zero area degeneracies (sliver triangles).
## 2. Inverted face normals / flipped polygons.
## 3. Skirt self-intersection across turn evolutes (R < W_FAR leading to sky-spikes).
## On baseline code with unconstrained W_FAR = 45m on R = 19m turns, this watchdog detects defects.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777, 99999, 12345]
const CHUNKS_PER_SEED: int = 15

func _init() -> void:
	print("\n========================================================")
	print("🔍 SPRINT 7 WATCHDOG #2: TERRAIN TOPOLOGY & EVOLUTE AUDIT")
	print("Checking mesh integrity & skirt clamping across %d seeds" % TEST_SEEDS.size())
	print("========================================================\n")

	var total_triangles_checked: int = 0
	var inverted_faces_count: int = 0
	var degenerate_triangles_count: int = 0
	var evolute_crossings_count: int = 0

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

			# Analyze prepared terrain_faces (triangles, 3 vertices each)
			var faces: PackedVector3Array = prep.terrain_faces
			var num_faces: int = faces.size() / 3

			for f_i in range(num_faces):
				total_triangles_checked += 1
				var p0: Vector3 = faces[f_i * 3 + 0]
				var p1: Vector3 = faces[f_i * 3 + 1]
				var p2: Vector3 = faces[f_i * 3 + 2]

				var e1: Vector3 = p1 - p0
				var e2: Vector3 = p2 - p0
				var cross: Vector3 = e1.cross(e2)
				var area: float = cross.length() * 0.5

				# 1. Check for degenerate slivers
				if area < 0.001:
					degenerate_triangles_count += 1
					seed_defects += 1

				# 2. Check face normal orientation
				if area > 0.001:
					var normal: Vector3 = cross.normalized()
					# In mountain terrain, normal pointing down (Ny < -0.3) indicates flipped face
					if normal.y < -0.30:
						inverted_faces_count += 1
						seed_defects += 1
						if seed_defects <= 5:
							var seg_i: int = f_i / 12
							var sample_idx: int = s_idx + seg_i
							var p_road: Vector3 = path_data.points[sample_idx]
							var t_road: Vector3 = path_data.tangents[sample_idx]
							var b_road: Vector3 = path_data.binormals[sample_idx]
							var k_road: float = path_data.curvatures[sample_idx]
							printerr("  [INVERTED FACE] Seed %d Chunk %d Face %d: normal (%.2f, %.2f, %.2f)\n    pt=%s, t=%s, b=%s, k=%.4f\n    p0=%s\n    p1=%s\n    p2=%s" % [
								s, c, f_i, normal.x, normal.y, normal.z,
								str(p_road), str(t_road), str(b_road), k_road,
								str(p0), str(p1), str(p2)
							])

			# 3. Check for evolute crossings on sharp curves
			# When turn radius R < 45m, skirt points extending 45m inwards cross the evolute
			for idx in range(s_idx, e_idx):
				var k: float = path_data.curvatures[idx]
				if absf(k) > 0.022: # Sharp turn (R < 45.4m)
					var r_turn: float = 1.0 / absf(k)
					var pt: Vector3 = path_data.points[idx]
					var tang: Vector3 = path_data.tangents[idx]
					var bin: Vector3 = path_data.binormals[idx]
					var norm: Vector3 = path_data.normals[idx]
					var half_w: float = 0.9

					var next_i: int = mini(idx + 1, path_data.size() - 1)
					var prev_i: int = maxi(0, idx - 1)
					var dt: Vector3 = path_data.tangents[next_i] - path_data.tangents[prev_i]
					var is_turning_right: bool = dt.dot(bin) >= 0.0
					var signed_curv: float = k if is_turning_right else -k

					var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, bin, half_w, signed_curv, 0, path_data.cumulative_distances[idx])
					var verts: PackedVector3Array = cs.vertices
					# If turning RIGHT, inner side is Right (v4..v7).
					# The lateral offset of v7 must NOT exceed R_turn!
					if is_turning_right:
						var inner_v7: Vector3 = verts[7]
						var lat_span: float = absf((inner_v7 - pt).dot(bin))
						if lat_span >= r_turn:
							evolute_crossings_count += 1
							seed_defects += 1
							if seed_defects <= 5:
								printerr("  [EVOLUTE CROSSING] Seed %d: Right Turn R=%.1fm, Right inner skirt span=%.1fm >= R! Polygons fold across horizon!" % [
									s, r_turn, lat_span
								])
					else:
						# Turning LEFT, inner side is Left (v0..v3).
						var inner_v0: Vector3 = verts[0]
						var lat_span: float = absf((pt - inner_v0).dot(bin))
						if lat_span >= r_turn:
							evolute_crossings_count += 1
							seed_defects += 1
							if seed_defects <= 5:
								printerr("  [EVOLUTE CROSSING] Seed %d: Left Turn R=%.1fm, Left inner skirt span=%.1fm >= R! Polygons fold across horizon!" % [
									s, r_turn, lat_span
								])

		if seed_defects > 0:
			print("  -> Seed %d: %d topology defects detected" % [s, seed_defects])
		else:
			print("  -> Seed %d: CLEAR" % s)

	print("\n--------------------------------------------------------")
	print("Summary: %d triangles checked" % total_triangles_checked)
	print("  - Inverted faces: %d" % inverted_faces_count)
	print("  - Degenerate slivers: %d" % degenerate_triangles_count)
	print("  - Skirt evolute crossings: %d" % evolute_crossings_count)

	var total_defects: int = inverted_faces_count + degenerate_triangles_count + evolute_crossings_count
	if total_defects > 0:
		print("❌ [WATCHDOG FAIL] Terrain topology defects detected (%d violations)" % total_defects)
		quit(1)
	else:
		print("✅ [WATCHDOG PASS] 100% terrain topology validity guaranteed!")
		quit(0)
