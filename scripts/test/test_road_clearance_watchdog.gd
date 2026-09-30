extends SceneTree

## Slow Cycle — Sprint 7 Watchdog #1: Road Clearance & Props Envelope
## Scans road chunks across multiple seeds to verify that NO props, posts, or foliage
## encroach upon the road corridor (clearance envelope w(s)/2 + margin).
## On baseline code with static w_start for posts and unconstrained foliage, this watchdog detects defects.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")
const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const SlowCycleLogger = preload("res://scripts/core/slow_cycle_logger.gd")

const TEST_SEEDS: Array[int] = [184729, 42, 77777, 99999, 12345]
const CHUNKS_PER_SEED: int = 15 ## ~750m per seed

func _init() -> void:
	print("\n========================================================")
	print("🔍 SPRINT 7 WATCHDOG #1: ROAD CLEARANCE & PROPS ENVELOPE")
	print("Checking safety clearance (w/2 + margin) across %d seeds" % TEST_SEEDS.size())
	print("========================================================\n")

	var total_encroachments: int = 0
	var total_props_checked: int = 0

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

		var seed_encroachments: int = 0

		# Generate chunks
		for c in range(CHUNKS_PER_SEED):
			logic.plan_next_chunk()

		# Simulate fork approach widening on chunk 4 and 9 (as done in production ChunkStreamer)
		for c_fork in [4, 9]:
			var fork_s: int = c_fork * 25
			var fork_e: int = mini(fork_s + 25, path_data.size() - 1)
			if path_data.road_widths.size() <= fork_e:
				path_data.road_widths.resize(path_data.size())
				for i in range(path_data.size()):
					path_data.road_widths[i] = 2.0
			for i in range(fork_s, fork_e + 1):
				var t_wide: float = float(i - fork_s) / float(maxi(1, fork_e - fork_s))
				path_data.road_widths[i] = lerpf(3.2, 6.5, t_wide)

		var pts_count: int = path_data.size()
		var chunk_step: int = 25 # 25 samples per chunk approx

		for c in range(CHUNKS_PER_SEED):
			var s_idx: int = c * chunk_step
			var e_idx: int = mini(s_idx + chunk_step, pts_count - 1)
			if s_idx >= e_idx:
				break

			# Test standard chunk and simulated approach/fork chunk
			var is_fork: bool = (c % 5 == 4)
			var prep: RoadChunk.PreparedChunkData = RoadChunkClass.prepare_geometry_data(
				path_data, s_idx, e_idx, c, shared_mats, null, is_fork
			)

			# Collect all prop positions
			var props_to_check: Array[Dictionary] = [] # { type: String, pos: Vector3 }

			for t in prep.guard_post_transforms:
				props_to_check.append({"type": "guard_post", "pos": t.origin})
			for t in prep.marker_post_transforms:
				props_to_check.append({"type": "marker_post", "pos": t.origin})
			if prep.has_directional_sign:
				props_to_check.append({"type": "directional_sign", "pos": prep.directional_sign_transform.origin})

			for key in ["pine", "birch", "boulder"]:
				var t_arr: Array = prep.foliage_transforms.get(key, [])
				for t in t_arr:
					props_to_check.append({"type": key, "pos": t.origin})

			# Check each prop against nearest road centerline sample
			for item in props_to_check:
				total_props_checked += 1
				var p_obj: Vector3 = item.pos
				var min_dist: float = 1e9
				var nearest_idx: int = -1

				for idx in range(s_idx, e_idx + 1):
					var d: float = path_data.points[idx].distance_to(p_obj)
					if d < min_dist:
						min_dist = d
						nearest_idx = idx

				if nearest_idx >= 0:
					var pt: Vector3 = path_data.points[nearest_idx]
					var bin: Vector3 = path_data.binormals[nearest_idx]
					var half_w: float = 0.9 # default half width
					if not path_data.road_widths.is_empty() and nearest_idx < path_data.road_widths.size():
						half_w = path_data.road_widths[nearest_idx] * 0.5

					# Project vector onto lateral binormal
					var delta: Vector3 = p_obj - pt
					var lat_offset: float = absf(delta.dot(bin))

					# Encroachment rule:
					# Solid objects (trees, boulders, posts) must not be within the roadbed (half_w)
					# Posts must have clearance: strictly outside roadbed (lat_offset >= half_w + 0.15m)
					# Foliage/rocks must have safe margin: strictly outside roadbed (lat_offset >= half_w + 0.50m)
					var required_margin: float = 0.15 if (item.type.ends_with("_post") or item.type == "directional_sign") else 0.50
					var min_required_lat: float = half_w + required_margin

					if lat_offset < min_required_lat:
						seed_encroachments += 1
						total_encroachments += 1
						if seed_encroachments <= 5:
							printerr("  [CLEARANCE VIOLATION] Seed %d Chunk %d: %s at lateral %.2fm < required %.2fm (road half_w=%.2fm, s_idx=%d)" % [
								s, c, item.type, lat_offset, min_required_lat, half_w, nearest_idx
							])

		if seed_encroachments > 0:
			print("  -> Seed %d: %d clearance violations detected" % [s, seed_encroachments])
		else:
			print("  -> Seed %d: CLEAR (0 violations)" % s)

	print("\n--------------------------------------------------------")
	print("Summary: %d total props checked, %d clearance encroachments" % [total_props_checked, total_encroachments])

	if total_encroachments > 0:
		print("❌ [WATCHDOG FAIL] Road clearance violated (%d encroachments on road corridor)" % total_encroachments)
		quit(1)
	else:
		print("✅ [WATCHDOG PASS] 100% road clearance guaranteed across all seeds!")
		quit(0)
