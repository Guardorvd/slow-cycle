extends SceneTree

## Slow Cycle — Sprint 7 Watchdog #4: Road Verge Seam & Z-Fighting Profiler
## Checks the interface between road edge vertices and adjacent terrain shoulder/ditch vertices.
## In studio-grade road construction (Beveled Verge Architecture), the gravel roadbed must
## rise above the drainage ditch swale by 0.02m .. 0.05m (3-4 cm step).
## Identical coplanar vertices (dh < 0.01m) lead to depth fighting (Z-fighting) and grass encroachment.
## On baseline code where v3/v4 of terrain exactly match road edge, this watchdog detects defects.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777]
const CHUNKS_PER_SEED: int = 10

func _init() -> void:
	print("\n========================================================")
	print("🔍 SPRINT 7 WATCHDOG #4: ROAD VERGE SEAM & Z-FIGHTING PROFILER")
	print("Checking verge elevation step (2cm .. 5cm) across %d seeds" % TEST_SEEDS.size())
	print("========================================================\n")

	var total_seam_samples: int = 0
	var coplanar_samples_count: int = 0
	var inverted_step_samples_count: int = 0

	for s in TEST_SEEDS:
		var path_data = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(s, path_data)
		var carver = TerrainCarverClass.new(s)
		var noise = FastNoiseLite.new()
		noise.seed = s

		for c in range(CHUNKS_PER_SEED):
			logic.plan_next_chunk()

		var pts_count: int = path_data.size()
		var chunk_step: int = 25
		var seed_coplanar: int = 0

		for c in range(CHUNKS_PER_SEED):
			var s_idx: int = c * chunk_step
			var e_idx: int = mini(s_idx + chunk_step, pts_count - 1)
			if s_idx >= e_idx:
				break

			for idx in range(s_idx, e_idx):
				total_seam_samples += 2 # Left and Right edges
				var pt: Vector3 = path_data.points[idx]
				var tang: Vector3 = path_data.tangents[idx]
				var norm: Vector3 = path_data.normals[idx]
				var bin: Vector3 = path_data.binormals[idx]
				var k: float = path_data.curvatures[idx]
				var dist: float = path_data.cumulative_distances[idx]

				var half_w: float = 0.9
				if not path_data.road_widths.is_empty() and idx < path_data.road_widths.size():
					half_w = path_data.road_widths[idx] * 0.5

				# Road edge vertices
				var p_road_l: Vector3 = pt - bin * half_w
				var p_road_r: Vector3 = pt + bin * half_w

				# Terrain cross-section vertices
				var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, bin, half_w, k, 0, dist)
				var verts: PackedVector3Array = cs.vertices
				# Left seam: road edge vs terrain shoulder/swale vertex
				# In current code: v3 is pos_l_road, v2 is pos_l_sh
				# In beveled architecture: road edge must sit higher than ditch by 0.02m .. 0.05m
				var v_terr_inner_l: Vector3 = verts[5] # Terrain seam vertex (Left)
				var v_terr_ditch_l: Vector3 = verts[4] # Terrain ditch swale vertex (Left)

				var v_terr_inner_r: Vector3 = verts[6] # Terrain seam vertex (Right)
				var v_terr_ditch_r: Vector3 = verts[7] # Terrain ditch swale vertex (Right)

				# Check step height: Road edge Y minus Terrain seam Y
				var dh_l: float = p_road_l.y - v_terr_inner_l.y
				var dh_r: float = p_road_r.y - v_terr_inner_r.y

				# Check for coplanar seam (dh < 0.015m) -> Z-fighting defect
				if dh_l < 0.015:
					coplanar_samples_count += 1
					seed_coplanar += 1
				if dh_r < 0.015:
					coplanar_samples_count += 1
					seed_coplanar += 1

				# Check for inverted step (terrain higher than road edge)
				if dh_l < -0.005:
					inverted_step_samples_count += 1
				if dh_r < -0.005:
					inverted_step_samples_count += 1

		if seed_coplanar > 0:
			print("  -> Seed %d: %d coplanar / zero-step verge samples (Z-fighting risk)" % [s, seed_coplanar])
		else:
			print("  -> Seed %d: CLEAR (Beveled verge confirmed)" % s)

	print("\n--------------------------------------------------------")
	print("Summary: %d seam samples audited" % total_seam_samples)
	print("  - Coplanar seams (dh < 0.015m): %d" % coplanar_samples_count)
	print("  - Inverted steps (terrain encroaching road): %d" % inverted_step_samples_count)

	if coplanar_samples_count > 0:
		print("❌ [WATCHDOG FAIL] Coplanar verge seam detected (%d samples suffer from Z-fighting)" % coplanar_samples_count)
		quit(1)
	else:
		print("✅ [WATCHDOG PASS] 100% Beveled Verge clearance confirmed!")
		quit(0)
