extends SceneTree

var current_seed_idx: int = 0
var test_seeds: Array[int] = [184729, 42, 77777]

var state: String = "INIT_SEED"
var frames_in_state: int = 0

var main_node: Node3D
var player_bike: CharacterBody3D
var world_mgr: Node3D
var streamer: Node3D
var active_path: RefCounted

var cur_dist: float = 0.0
var fork_pos: Vector3 = Vector3.ZERO
var fork_found: bool = false

func _init() -> void:
	print("\n=== STARTING MULTI-SEED VISUAL AUDIT ===")

func _process(delta: float) -> bool:
	frames_in_state += 1

	match state:
		"INIT_SEED":
			if current_seed_idx >= test_seeds.size():
				print("=== MULTI-SEED VISUAL AUDIT COMPLETE ===")
				quit()
				return true

			var s: int = test_seeds[current_seed_idx]
			print("\n--- Initializing Seed %d (%d/%d) ---" % [s, current_seed_idx + 1, test_seeds.size()])

			var main_scene = load("res://scenes/main.tscn").instantiate()
			root.add_child(main_scene)
			main_node = main_scene
			world_mgr = main_node.get_node("WorldManager")
			player_bike = main_node.get_node("Bicycle")

			world_mgr.world_seed = s
			world_mgr.randomize_world_seed_on_start = false

			cur_dist = 0.0
			fork_found = false
			fork_pos = Vector3.ZERO
			frames_in_state = 0
			state = "WAIT_READY"

		"WAIT_READY":
			if frames_in_state < 15:
				return false
			streamer = world_mgr.chunk_streamer if world_mgr else null
			if not streamer or not player_bike:
				return false

			var active_b = streamer.get_active_branch()
			if not active_b or not active_b.road_path or active_b.road_path.size() < 10:
				return false

			active_path = active_b.road_path
			frames_in_state = 0
			state = "CAPTURE_START"

		"CAPTURE_START":
			# Position at 2.5m (enclosed by Chunk 0, safe margin behind near-plane)
			_position_bike_at_dist(2.5)
			if frames_in_state >= 15:
				_save_screenshot("seed_%d_01_start_000m.png" % test_seeds[current_seed_idx])
				cur_dist = 10.0
				frames_in_state = 0
				state = "STEP_TO_100M"

		"STEP_TO_100M":
			# Advance progressively so streamer builds chunks
			if cur_dist < 100.0:
				cur_dist = minf(100.0, cur_dist + 15.0)
				_position_bike_at_dist(cur_dist)
			else:
				_position_bike_at_dist(100.0)
				if frames_in_state >= 15:
					_save_screenshot("seed_%d_02_straight_100m.png" % test_seeds[current_seed_idx])
					frames_in_state = 0
					state = "SEARCH_FORK"

		"SEARCH_FORK":
			# Advance ahead until fork spawns or up to 650m
			if not fork_found and cur_dist < 650.0:
				cur_dist += 15.0
				_position_bike_at_dist(cur_dist)

				# Check if alternative branch spawned
				if streamer.branches.size() > 1:
					for b in streamer.branches.values():
						if b.branch_id != 0 and b.fork_node_pos != Vector3.ZERO:
							fork_found = true
							fork_pos = b.fork_node_pos
							print("  [FORK DETECTED] Seed %d: Fork spawned at pos=%s (bike dist=%.1fm)" % [
								test_seeds[current_seed_idx], str(fork_pos), cur_dist
							])
							var active_b = streamer.get_active_branch()
							var p = active_b.road_path
							var fork_idx = p.find_closest_index(fork_pos)
							var fork_dist_on_path = p.cumulative_distances[fork_idx]
							var view_dist = maxf(0.0, fork_dist_on_path - 22.0)
							_position_bike_at_dist(view_dist)
							frames_in_state = 0
							state = "WAIT_FORK_STABILIZE"
							break
			elif cur_dist >= 650.0:
				# Reached 650m without fork; capture wherever we are
				print("  [NOTE] Seed %d: No fork before 650m, capturing singletrack" % test_seeds[current_seed_idx])
				_save_screenshot("seed_%d_03_corridor_600m.png" % test_seeds[current_seed_idx])
				frames_in_state = 0
				state = "NEXT_SEED"

		"WAIT_FORK_STABILIZE":
			var active_b = streamer.get_active_branch()
			var p = active_b.road_path
			var fork_idx = p.find_closest_index(fork_pos)
			var fork_dist_on_path = p.cumulative_distances[fork_idx]
			var view_dist = maxf(0.0, fork_dist_on_path - 22.0)
			_position_bike_at_dist(view_dist)

			# Allow 25 full frames for all chunk meshes to commit, old chunks to clear, and camera to settle
			if frames_in_state >= 25:
				_save_screenshot("seed_%d_03_first_fork.png" % test_seeds[current_seed_idx])
				frames_in_state = 0
				state = "NEXT_SEED"

		"NEXT_SEED":
			if main_node:
				main_node.free()
				main_node = null
			current_seed_idx += 1
			frames_in_state = 0
			state = "INIT_SEED"

	return false

func _position_bike_at_dist(target_dist: float) -> void:
	if not streamer or not player_bike:
		return
	var active_b = streamer.get_active_branch()
	if not active_b or not active_b.road_path:
		return
	var p = active_b.road_path
	var sample = p.get_sample_at_distance(target_dist)
	var pt: Vector3 = sample.get("position", Vector3.ZERO)
	var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
	var norm: Vector3 = sample.get("normal", Vector3.UP)

	player_bike.global_position = pt + norm * 0.4
	var horiz = Vector3(tang.x, 0.0, tang.z).normalized()
	if not horiz.is_zero_approx():
		player_bike.global_basis = Basis.looking_at(horiz, Vector3.UP)

	streamer.update_streaming(player_bike.global_position, tang * 12.0, 0.016)

func _save_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img != null:
		var save_path = "res://screenshots/" + filename
		img.save_png(save_path)
		print("[CAPTURED] Saved %s" % filename)
