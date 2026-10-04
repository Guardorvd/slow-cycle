@tool
extends SceneTree

## Slow Cycle — Quality Watchdog 3: Virtual Physical Rider Bot (Sprint 6 v4)
## Simulates an autonomous physical rider navigating procedural terrain on REAL PHYSICS.
## No coordinate teleportation. Drives BicycleController via steer and pedal inputs.

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const SlowCycleLogger = preload("res://scripts/core/slow_cycle_logger.gd")
const TeardownSettle = preload("res://scripts/test/teardown_settle_support.gd")

const TEST_SEED: int = 184729
const TARGET_RIDE_DISTANCE_M: float = 500.0 # Fast and thorough physical run
const MIN_SPEED_MS: float = 4.0 # ~15 km/h min
const TARGET_SPEED_MS: float = 9.0 # ~32 km/h
const MAX_LATERAL_DEVIATION_M: float = 2.2 # Keep within road boundary
const MIN_ROLL_EVENTS_PER_KM: float = 4.0 # Active dynamic cornering events
const ROLL_THRESHOLD_DEG: float = 3.0 # Minimum roll angle to count as active turn

func _init() -> void:
	print("\n========================================================")
	print("🔍 WATCHDOG #3: VIRTUAL PHYSICAL RIDER BOT")
	print("Physical ride test on Seed %d (Target: %.0fm, No Teleport)" % [TEST_SEED, TARGET_RIDE_DISTANCE_M])
	print("========================================================\n")
	SlowCycleLogger.log_world("Starting Virtual Rider Bot Watchdog...")
	_run_ride()

func _run_ride() -> void:
	var scene: Node = MainScene.instantiate()
	var world_mgr: Node = scene.get_node("WorldManager")
	world_mgr.world_seed = TEST_SEED
	world_mgr.randomize_world_seed_on_start = false
	root.add_child(scene)

	# Wait for initialization
	for i in range(10):
		await process_frame

	var bike: BicycleController = scene.get_node("Bicycle") as BicycleController
	var streamer: ChunkStreamer = world_mgr.chunk_streamer as ChunkStreamer

	if not bike or not streamer:
		printerr("[ERROR] Failed to obtain Bicycle or ChunkStreamer!")
		quit(1)
		return

	var active_branch = streamer.get_active_branch()
	if not active_branch or not active_branch.road_path:
		printerr("[ERROR] Active road branch not ready!")
		quit(1)
		return

	var path = active_branch.road_path

	# Telemetry counters
	var total_distance_covered: float = 0.0
	var max_lateral_error: float = 0.0
	var roll_events_count: int = 0
	var in_roll_event: bool = false
	var peak_roll_deg: float = 0.0
	var last_closest_idx: int = 0
	var start_pos: Vector3 = bike.global_position
	var fell_off_track: bool = false

	print("Initial rider position: %s | Starting physical pedal drive..." % start_pos)

	# Run simulation frames
	var max_sim_frames: int = 2500 # ~40 seconds of physics
	var current_frame: int = 0

	while current_frame < max_sim_frames and total_distance_covered < TARGET_RIDE_DISTANCE_M:
		await physics_frame
		current_frame += 1

		# Maintain active branch path
		active_branch = streamer.get_active_branch()
		if active_branch and active_branch.road_path:
			path = active_branch.road_path

		# Find position along road
		last_closest_idx = path.find_closest_index(bike.global_position, last_closest_idx)
		var cur_s: float = path.cumulative_distances[last_closest_idx]
		total_distance_covered = cur_s

		# Measure lateral offset from centerline
		var road_pt: Vector3 = path.points[last_closest_idx]
		var delta_pos: Vector2 = Vector2(bike.global_position.x - road_pt.x, bike.global_position.z - road_pt.z)
		var lateral_offset: float = delta_pos.length()
		max_lateral_error = maxf(max_lateral_error, lateral_offset)

		if lateral_offset > MAX_LATERAL_DEVIATION_M:
			printerr("  ❌ OFF-TRACK: Bike deviated %.2fm from centerline at s=%.1fm!" % [lateral_offset, cur_s])
			fell_off_track = true
			break

		if bike.global_position.y < -30.0:
			printerr("  ❌ PITFALL: Bike fell through world at s=%.1fm!" % cur_s)
			fell_off_track = true
			break

		# AI Steering & Throttle Control via Input Actions
		var target_s: float = cur_s + 4.2
		var target_sample = path.get_sample_at_distance(target_s)
		var target_pos: Vector3 = target_sample.position
		var to_target: Vector3 = (target_pos - bike.global_position).normalized()
		var bike_forward: Vector3 = -bike.global_transform.basis.z

		# Steer error (+ is left, - is right in Godot convention)
		var steer_error: float = bike_forward.cross(to_target).y
		var steer_target: float = clampf(steer_error * 3.5, -1.0, 1.0)

		if steer_target > 0.05:
			Input.action_press("steer_left", steer_target)
			Input.action_release("steer_right")
		elif steer_target < -0.05:
			Input.action_press("steer_right", -steer_target)
			Input.action_release("steer_left")
		else:
			Input.action_release("steer_left")
			Input.action_release("steer_right")

		# Throttle / Cruise pedal control via Input action
		if bike.current_speed < TARGET_SPEED_MS:
			Input.action_press("pedal", 1.0)
			Input.action_release("brake")
		else:
			Input.action_release("pedal")

		# Track roll banking
		var roll_deg: float = absf(rad_to_deg(bike.current_bank))
		peak_roll_deg = maxf(peak_roll_deg, roll_deg)

		if roll_deg >= ROLL_THRESHOLD_DEG:
			if not in_roll_event:
				roll_events_count += 1
				in_roll_event = true
		else:
			if roll_deg < ROLL_THRESHOLD_DEG * 0.6:
				in_roll_event = false

	# Release inputs
	Input.action_release("pedal")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")

	# Summary
	print("\n--------------------------------------------------------")
	print("Virtual Rider Bot Run Results:")
	print("  - Distance Covered: %.1fm / %.1fm" % [total_distance_covered, TARGET_RIDE_DISTANCE_M])
	print("  - Max Lateral Deviation: %.2fm (Limit: <= %.1fm)" % [max_lateral_error, MAX_LATERAL_DEVIATION_M])
	print("  - Peak Bike Roll Bank: %.1f°" % peak_roll_deg)
	print("  - Active Cornering Roll Events: %d" % roll_events_count)
	print("  - Track Integrity Kept: %s" % ("YES" if not fell_off_track else "NO"))
	print("--------------------------------------------------------\n")

	# Evaluate Criteria
	var roll_density: float = (float(roll_events_count) / maxf(1.0, total_distance_covered)) * 1000.0
	print("Roll Events Density: %.1f events/km (Required: >= %.1f events/km)" % [roll_density, MIN_ROLL_EVENTS_PER_KM])

	var pass_run: bool = true
	if fell_off_track:
		printerr("❌ [FAIL] Rider lost control or crashed!")
		pass_run = false
	elif total_distance_covered < TARGET_RIDE_DISTANCE_M * 0.7:
		printerr("❌ [FAIL] Rider failed to complete target distance (covered only %.1fm)!" % total_distance_covered)
		pass_run = false
	elif roll_density < MIN_ROLL_EVENTS_PER_KM:
		printerr("❌ [FAIL] Track is boring / straight! Only %d active bank events in %.0fm (%.1f/km < %.1f/km required)." % [
			roll_events_count, total_distance_covered, roll_density, MIN_ROLL_EVENTS_PER_KM
		])
		pass_run = false

	scene.free()

	if not pass_run:
		SlowCycleLogger.log_world("[FAIL] Virtual Rider Bot: run failed")
		SlowCycleLogger.flush()
		await TeardownSettle.settle_then_quit(self, 1)
	else:
		print("✅ [PASS] VIRTUAL PHYSICAL RIDER BOT COMPLETED SUCCESSFULLY!")
		SlowCycleLogger.log_world("[PASS] Virtual Rider Bot: covered %.1fm, %d roll events" % [total_distance_covered, roll_events_count])
		SlowCycleLogger.flush()
		await TeardownSettle.settle_then_quit(self, 0)
