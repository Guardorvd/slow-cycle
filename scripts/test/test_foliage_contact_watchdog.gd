extends SceneTree

## Slow Cycle — Sprint 7 Watchdog #3: Foliage & Props Ground Contact Profiler
## Verifies that trees, boulders, and props are anchored to the actual terrain mesh.
## Disallows floating objects (dh > 0.05m) and excessively submerged objects (dh < -0.35m).
## On baseline code where foliage uses independent noise instead of TerrainCarver cross-section,
## this watchdog detects severe ground anchoring defects.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

const SurfaceAudit = preload("res://scripts/test/surface_audit_support.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777]
const CHUNKS_PER_SEED: int = 12

func _init() -> void:
	print("\n========================================================")
	print("🔍 SPRINT 7 WATCHDOG #3: FOLIAGE & PROPS GROUND CONTACT")
	print("Checking vertical contact deltas against terrain mesh")
	print("========================================================\n")

	var total_props_checked: int = 0
	var floating_props_count: int = 0
	var buried_props_count: int = 0
	var missing_ground_count: int = 0
	var checked_contacts: int = 0
	var missing_terrain_count: int = 0

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

			var terrain_faces: PackedVector3Array = prep.terrain_faces
			var num_faces: int = terrain_faces.size() / 3
			if num_faces == 0:
				missing_terrain_count += 1
				seed_defects += 1

			# Collect trees and boulders
			var props: Array[Dictionary] = []
			for key in ["pine", "birch", "boulder"]:
				var t_arr: Array = prep.foliage_transforms.get(key, [])
				for t in t_arr:
					props.append({"type": key, "pos": t.origin})

			for item in props:
				total_props_checked += 1
				var p_obj: Vector3 = item.pos
				# Find triangle under (p_obj.x, p_obj.z)
				var surface_y: float = -9999.0
				var found_triangle: bool = false
				var min_dy: float = 1e9

				for f_i in range(num_faces):
					var p0: Vector3 = terrain_faces[f_i * 3 + 0]
					var p1: Vector3 = terrain_faces[f_i * 3 + 1]
					var p2: Vector3 = terrain_faces[f_i * 3 + 2]

					# 2D Point-in-triangle test in XZ plane
					var y_hit: float = _get_triangle_height_at(p0, p1, p2, p_obj.x, p_obj.z)
					if y_hit > -9000.0:
						var dy: float = absf(p_obj.y - y_hit)
						if dy < min_dy:
							min_dy = dy
							surface_y = y_hit
							found_triangle = true

				if not found_triangle:
					missing_ground_count += 1
					seed_defects += 1
					printerr("[MISSING GROUND] seed=%d chunk=%d prop=%s position=%s" % [s, c, item.type, p_obj])
				else:
					checked_contacts += 1
					var delta_y: float = p_obj.y - surface_y
					# Target: slightly embedded in ground (-0.10m), acceptable delta [-0.25m, 0.05m]
					if delta_y > 0.05:
						floating_props_count += 1
						seed_defects += 1
						if seed_defects <= 3:
							printerr("  [FLOATING %s] Seed %d Chunk %d: Prop at (%.2f, %.2f, %.2f) is FLOATING %.2fm above terrain (surface=%.2f)!" % [
								item.type.to_upper(), s, c, p_obj.x, p_obj.y, p_obj.z, delta_y, surface_y
							])
					elif delta_y < -0.35:
						buried_props_count += 1
						seed_defects += 1
						if seed_defects <= 3:
							printerr("  [BURIED %s] Seed %d Chunk %d: Prop at (%.2f, %.2f, %.2f) is BURIED %.2fm into terrain (surface=%.2f)!" % [
								item.type.to_upper(), s, c, p_obj.x, p_obj.y, p_obj.z, -delta_y, surface_y
							])

		if seed_defects > 0:
			print("  -> Seed %d: %d contact defects detected" % [s, seed_defects])
		else:
			print("  -> Seed %d: CLEAR" % s)

	print("\n--------------------------------------------------------")
	print("Summary: %d props analyzed" % total_props_checked)
	print("  - Floating props (dh > 0.05m): %d" % floating_props_count)
	print("  - Buried props (dh < -0.35m): %d" % buried_props_count)

	print("  - Checked contacts: %d; missing ground: %d; missing terrain: %d" % [checked_contacts, missing_ground_count, missing_terrain_count])
	var total_defects: int = floating_props_count + buried_props_count + missing_ground_count + missing_terrain_count
	if total_props_checked == 0 or checked_contacts != total_props_checked:
		total_defects += 1
	if total_defects > 0:
		print("❌ [WATCHDOG FAIL] Foliage contact defects detected (%d violations)" % total_defects)
		quit(1)
	else:
		print("✅ [WATCHDOG PASS] Prepared pine/birch/boulder contacts passed for this battery; fork/runtime checked separately.")
		quit(0)

func _get_triangle_height_at(p0: Vector3, p1: Vector3, p2: Vector3, px: float, pz: float) -> float:
	var height := SurfaceAudit.triangle_height(p0, p1, p2, px, pz)
	return height if is_finite(height) else -9999.0
