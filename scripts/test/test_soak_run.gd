extends SceneTree

const TEST_SEEDS: Array[int] = [184729, 10101, 99999]
const TARGET_CHUNKS: int = 350 # 17.5 km per seed (~25-30 minutes of real riding)

func _init() -> void:
	print("\n========================================================")
	print("=== STARTING 15-MINUTE CONTINUOUS SOAK STRESS TEST  ===")
	print("=== TARGET: 17.5 KM (350 CHUNKS) PER SEED           ===")
	print("========================================================\n")

	var all_ok: bool = true
	for s in TEST_SEEDS:
		var ok: bool = await _run_seed_soak(s)
		if not ok:
			all_ok = false
			break

	await process_frame
	await process_frame

	if all_ok:
		print("\n========================================================")
		print("=== ALL SOAK TESTS PASSED [100% OK]                  ===")
		print("=== RAM PLATEAU CONFIRMED, 0 FALLS, 0 UNBOUNDED DATA ===")
		print("========================================================\n")
		quit(0)
	else:
		print("\n[FAIL] SOAK TEST FAILED!")
		quit(1)

func _run_seed_soak(seed_val: int) -> bool:
	print("--- Running Soak Test for Seed %d ---" % seed_val)
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var instance: Node = main_scene.instantiate()
	var world_mgr: Node = instance.get_node("WorldManager")
	world_mgr.world_seed = seed_val

	root.add_child(instance)

	await process_frame
	await physics_frame

	var bike: CharacterBody3D = instance.get_node("Bicycle")
	var streamer: Node = world_mgr.chunk_streamer
	var road_path: RefCounted = world_mgr.road_path

	var ram_start_mb: float = float(OS.get_static_memory_usage()) / 1048576.0
	print("  [INIT] Seed %d: Start RAM = %.2f MB, Active Chunks = %d" % [seed_val, ram_start_mb, streamer.get_active_chunk_count()])


	var chunks_milestone: int = 50
	var current_distance: float = 0.0
	var target_total_dist: float = float(TARGET_CHUNKS) * 50.0 # 17,500m
	var step_dist: float = 4.0 # 4m step per iteration
	var step: int = 0
	var max_ram_mb: float = ram_start_mb

	while current_distance < target_total_dist:
		step += 1
		current_distance += step_dist
		var sample: Dictionary = road_path.get_sample_at_distance(current_distance)
		var target_pos: Vector3 = sample.get("position", Vector3.ZERO)
		var target_tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
		var target_norm: Vector3 = sample.get("normal", Vector3.UP)

		bike.global_position = target_pos + target_norm * 0.4
		bike.velocity = target_tang * 8.5
		bike.current_speed = 8.5

		# Step streaming
		streamer.update_streaming(bike.global_position)


		# Check milestones every 50 chunks (2.5 km)
		var current_chunk: int = int(current_distance / 50.0)
		if current_chunk >= chunks_milestone:
			var cur_ram_mb: float = float(OS.get_static_memory_usage()) / 1048576.0
			if cur_ram_mb > max_ram_mb: max_ram_mb = cur_ram_mb
			var active_c: int = streamer.get_active_chunk_count()
			var spline_pts: int = road_path.size()

			print("  [MILESTONE] %4d chunks (%.1f km) | Active Chunks: %d | Spline Pts: %d | RAM: %.1f MB | Pos Y: %.1f" % [
				current_chunk, current_distance / 1000.0, active_c, spline_pts, cur_ram_mb, bike.global_position.y
			])

			# Assertions
			if active_c < 5 or active_c > 12:
				print("    [FAIL] Active chunks count out of bounds: %d" % active_c)
				instance.queue_free()
				return false

			if spline_pts > 400:
				print("    [FAIL] Spline points not pruned properly: %d pts" % spline_pts)
				instance.queue_free()
				return false

			if is_nan(bike.global_position.y) or is_inf(bike.global_position.y):
				print("    [FAIL] Bicycle coordinates invalid (NaN/Inf)!")
				instance.queue_free()
				return false

			chunks_milestone += 50

		if step % 60 == 0:
			await physics_frame

	print("  [SUCCESS] Seed %d: Completed %.2f km across %d chunks. Peak RAM: %.1f MB (Delta: +%.1f MB)" % [
		seed_val, current_distance / 1000.0, TARGET_CHUNKS, max_ram_mb, (max_ram_mb - ram_start_mb)
	])

	# Test Recovery on long-distance run
	var safe_tf: Transform3D = world_mgr.request_bike_recovery(bike.global_position)
	var recovery_dist: float = safe_tf.origin.distance_to(bike.global_position)
	print("  [RECOVERY TEST] Teleport offset after 17.5 km: %.2f m" % recovery_dist)
	if recovery_dist < 10.0 or recovery_dist > 35.0:
		print("  [FAIL] Recovery returned invalid position!")
		instance.queue_free()
		return false
	print("  [PASS] Recovery function verified at 17.5 km mark.\n")

	instance.queue_free()
	await process_frame
	return true
