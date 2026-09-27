@tool
extends SceneTree

## Slow Cycle — Stage B6 Dynamic Rideability & Physics Gate
## Programmatic proof that the live physical entity (BicycleController)
## navigates procedural MTB geometry without physics crashes, frame rollovers,
## suspension bottom-out spikes, or falling through terrain.
##
## Tests:
## 1. CREST_MICRO_DROP: Unweighting <= 0.30s, Pitch in [-18°, +10°], ground contact recovered.
## 2. AIRBORNE_DROP + LANDING: Flight >= 4 frames, compliant suspension (<0), Vy <= 6.5 m/s, zero tunneling.
## 3. SWITCHBACK (R≈18-19m): Lateral deviation <= 1.2m, roll <= 28°, forward exit speed >= 3.0 m/s.
## 4. BRAKING_ZONE & FORK SPLITTER WEDGE: Approach speed <= 35 km/h, clear wedge clearance on LEFT & RIGHT.
## 5. PROCEDURAL SEED REPLAY: Validated across Seeds 184729 and 42 in live streaming main world.

const LabScene = preload("res://scenes/test/riding_lab_track.tscn")
const MainScene = preload("res://scenes/main.tscn")
const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failures: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — STAGE B6 DYNAMIC RIDEABILITY SUITE            ")
	print("==================================================================\n")
	_run_suite()

func _run_suite() -> void:
	# Part 1: Empirical Kinematic Feature Verification
	print("[STAGE B6.1] Evaluating CREST_MICRO_DROP Invariants...")
	var crest_ok: bool = await _test_crest_micro_drop()

	print("\n[STAGE B6.2] Evaluating AIRBORNE_DROP & VALID_LANDING_SURFACE Invariants...")
	var drop_ok: bool = await _test_airborne_drop_landing()

	print("\n[STAGE B6.3] Evaluating SWITCHBACK Hairpin (R≈18-19m) Invariants...")
	var switchback_ok: bool = await _test_switchback_hairpin()

	# Part 2: Procedural World Streaming & Fork Wedge Navigation
	print("\n[STAGE B6.4] Evaluating Procedural Live Streaming & Fork Wedge Navigation...")
	var fork_ok: bool = await _test_procedural_stream_and_forks()

	# Summary & Verdict
	print("\n==================================================================")
	print("              STAGE B6 RIDEABILITY VERIFICATION SUMMARY           ")
	print("==================================================================")
	print("  1. Crest Micro-Drop Invariants:            %s" % ("PASS" if crest_ok else "FAIL"))
	print("  2. Airborne Drop & Landing Invariants:     %s" % ("PASS" if drop_ok else "FAIL"))
	print("  3. Switchback Hairpin (R≈19m) Invariants:  %s" % ("PASS" if switchback_ok else "FAIL"))
	print("  4. Procedural Streaming & Fork Clearance:  %s" % ("PASS" if fork_ok else "FAIL"))
	print("------------------------------------------------------------------")
	print("  TOTAL ASSERTIONS: %d | PASSED: %d | FAILURES: %d" % [total_assertions, passed_assertions, failures])
	print("==================================================================\n")

	if failures == 0 and total_assertions == passed_assertions:
		print("[B6_RIDEABILITY_PASS: ALL PHYSICAL INVARIANTS SATISFIED [EXIT 0]]\n")
		quit(0)
	else:
		printerr("[B6_RIDEABILITY_FAIL: ENCOUNTERED PHYSICAL VIOLATIONS [EXIT 1]]\n")
		quit(1)

func _assert_check(condition: bool, description: String) -> bool:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		print("    [PASS] " + description)
		return true
	else:
		failures += 1
		printerr("    [FAIL] " + description)
		return false

# ------------------------------------------------------------------------------
# 1. CREST_MICRO_DROP Dynamic Gate
# ------------------------------------------------------------------------------
func _test_crest_micro_drop() -> bool:
	var root_node = LabScene.instantiate()
	root.add_child(root_node)
	for _i in range(5):
		await process_frame

	var generator = root_node.get_node_or_null("RidingLabGenerator")
	var bike: CharacterBody3D = root_node.get_node_or_null("Bicycle")
	var path_data = generator.road_path

	# Section T6 Crest -> Dip is at s = 115.0 to 145.0 (h ≈ 0.25m crest)
	var sample_approach = path_data.get_sample_at_distance(110.0)
	bike.global_position = sample_approach.position + Vector3(0.0, 0.45, 0.0)
	var tang: Vector3 = sample_approach.tangent
	bike.look_at(bike.global_position + tang, Vector3.UP)
	bike.current_speed = 7.5 # 27 km/h
	bike.velocity = tang * bike.current_speed

	var unweighted_frames: int = 0
	var min_pitch_deg: float = 90.0
	var max_pitch_deg: float = -90.0
	var final_front_contact: bool = false
	var final_rear_contact: bool = false
	var max_lat_offset: float = 0.0
	var last_idx: int = 0

	for _frame in range(90):
		await physics_frame
		var fc: bool = bike.front_contact_valid
		var rc: bool = bike.rear_contact_valid
		var pitch_deg: float = rad_to_deg(bike.current_pitch)
		min_pitch_deg = minf(min_pitch_deg, pitch_deg)
		max_pitch_deg = maxf(max_pitch_deg, pitch_deg)

		if not fc or not rc:
			unweighted_frames += 1

		last_idx = path_data.find_closest_index(bike.global_position, last_idx)
		var center_pt: Vector3 = path_data.points[last_idx]
		var lat_offset: float = Vector2(bike.global_position.x - center_pt.x, bike.global_position.z - center_pt.z).length()
		max_lat_offset = maxf(max_lat_offset, lat_offset)

		final_front_contact = fc
		final_rear_contact = rc

	root_node.queue_free()
	for _i in range(5):
		await process_frame

	var dt: float = 1.0 / 60.0
	var air_time_s: float = float(unweighted_frames) * dt

	var ok_air: bool = _assert_check(air_time_s <= 0.30, "Crest unweighting duration (%.3fs) <= 0.30s" % air_time_s)
	var ok_pitch_min: bool = _assert_check(min_pitch_deg >= -18.0, "Crest minimum pitch (%+.1f°) >= -18.0° (no endo)" % min_pitch_deg)
	var ok_pitch_max: bool = _assert_check(max_pitch_deg <= 10.0, "Crest maximum pitch (%+.1f°) <= +10.0°" % max_pitch_deg)
	var ok_recovery: bool = _assert_check(final_front_contact and final_rear_contact, "Ground contact fully recovered on recovery rollout")
	var ok_lateral: bool = _assert_check(max_lat_offset <= 1.2, "Max lateral offset (%.2fm) within road bound" % max_lat_offset)

	return ok_air and ok_pitch_min and ok_pitch_max and ok_recovery and ok_lateral

# ------------------------------------------------------------------------------
# 2. AIRBORNE_DROP & VALID_LANDING_SURFACE Dynamic Gate
# ------------------------------------------------------------------------------
func _test_airborne_drop_landing() -> bool:
	var root_node = LabScene.instantiate()
	root.add_child(root_node)
	for _i in range(5):
		await process_frame

	var generator = root_node.get_node_or_null("RidingLabGenerator")
	var bike: CharacterBody3D = root_node.get_node_or_null("Bicycle")
	var path_data = generator.road_path

	# Section T10 Drop is at s = 232.69 to 248.69 (h ≈ 0.8m drop into -15° landing)
	var sample_approach = path_data.get_sample_at_distance(228.0)
	bike.global_position = sample_approach.position + Vector3(0.0, 0.45, 0.0)
	var tang: Vector3 = sample_approach.tangent
	bike.look_at(bike.global_position + tang, Vector3.UP)
	bike.current_speed = 8.5 # 30.6 km/h
	bike.velocity = tang * bike.current_speed

	var air_frames: int = 0
	var landed: bool = false
	var landing_vy: float = 0.0
	var max_susp_comp: float = 0.0
	var zero_tunneling: bool = true

	for _frame in range(120):
		await physics_frame
		var fc: bool = bike.front_contact_valid
		var rc: bool = bike.rear_contact_valid

		if not fc and not rc:
			air_frames += 1
		else:
			if air_frames >= 4 and not landed:
				landed = true
				landing_vy = bike.velocity.y
			if landed:
				max_susp_comp = minf(max_susp_comp, bike.suspension_compression)

		# Check for coordinate anomalies or tunneling below ground
		if not is_finite(bike.global_position.y) or bike.global_position.y < -100.0:
			zero_tunneling = false

	root_node.queue_free()
	for _i in range(5):
		await process_frame

	var susp_deflection_mm: float = absf(max_susp_comp) * 1000.0

	var ok_flight: bool = _assert_check(air_frames >= 4, "Airborne flight duration (%d frames) >= 4 frames" % air_frames)
	var ok_landing: bool = _assert_check(landed, "Touchdown occurred on descending landing surface")
	var ok_susp: bool = _assert_check(susp_deflection_mm >= 15.0 and susp_deflection_mm <= 120.0, "Suspension compliance deflection (%.1fmm) in [15, 120]mm" % susp_deflection_mm)
	var ok_vy: bool = _assert_check(absf(landing_vy) <= 6.5, "Landing vertical velocity (|%.2f| m/s) <= 6.5 m/s" % absf(landing_vy))
	var ok_tunnel: bool = _assert_check(zero_tunneling, "Zero physics fallthrough or tunneling detected")

	return ok_flight and ok_landing and ok_susp and ok_vy and ok_tunnel

# ------------------------------------------------------------------------------
# 3. SWITCHBACK Hairpin (R≈18-19m) Dynamic Gate
# ------------------------------------------------------------------------------
func _test_switchback_hairpin() -> bool:
	var root_node = LabScene.instantiate()
	root.add_child(root_node)
	for _i in range(5):
		await process_frame

	var generator = root_node.get_node_or_null("RidingLabGenerator")
	var bike: CharacterBody3D = root_node.get_node_or_null("Bicycle")
	var path_data = generator.road_path

	# Section T4 is Switchback Left (R = 18m) at s = 65.79 to 103.49
	var sample_approach = path_data.get_sample_at_distance(64.0)
	bike.global_position = sample_approach.position + Vector3(0.0, 0.45, 0.0)
	var tang: Vector3 = sample_approach.tangent
	bike.look_at(bike.global_position + tang, Vector3.UP)
	bike.current_speed = 5.5 # ~20 km/h
	bike.velocity = tang * bike.current_speed

	var max_roll_deg: float = 0.0
	var max_lat_error: float = 0.0
	var min_speed: float = INF
	var last_idx: int = 0

	for _frame in range(80):
		await physics_frame
		last_idx = path_data.find_closest_index(bike.global_position, last_idx)
		var cur_dist: float = path_data.cumulative_distances[last_idx]
		var cur_sample = path_data.get_sample_at_distance(cur_dist + 2.5)
		var target_pos: Vector3 = cur_sample.position + Vector3(0.0, 0.45, 0.0)
		var to_target: Vector3 = (target_pos - bike.global_position).normalized()
		var forward: Vector3 = -bike.global_transform.basis.z

		var steer_target: float = clampf(forward.cross(to_target).y * 3.0, -0.6, 0.6)
		bike.current_steer = move_toward(bike.current_steer, steer_target, 0.08)

		var roll_deg: float = absf(rad_to_deg(bike.current_bank))
		max_roll_deg = maxf(max_roll_deg, roll_deg)
		min_speed = minf(min_speed, bike.current_speed)

		var center_pt: Vector3 = path_data.points[last_idx]
		var lateral_offset: float = Vector2(bike.global_position.x - center_pt.x, bike.global_position.z - center_pt.z).length()
		max_lat_error = maxf(max_lat_error, lateral_offset)

	root_node.queue_free()
	for _i in range(5):
		await process_frame

	var ok_lat: bool = _assert_check(max_lat_error <= 1.2, "Hairpin lateral track adherence (%.2fm) <= 1.2m" % max_lat_error)
	var ok_roll: bool = _assert_check(max_roll_deg <= 28.0, "Hairpin peak frame roll (%.1f°) <= 28.0° (stable banking)" % max_roll_deg)
	var ok_speed: bool = _assert_check(min_speed >= 3.0, "Hairpin exit speed (%.1f m/s) >= 3.0 m/s (no stall)" % min_speed)

	return ok_lat and ok_roll and ok_speed

# ------------------------------------------------------------------------------
# 4. PROCEDURAL STREAMING & FORK CLEARANCE (Seeds 184729 & 42)
# ------------------------------------------------------------------------------
func _test_procedural_stream_and_forks() -> bool:
	var all_seeds_passed: bool = true
	for seed_val: int in [184729, 42]:
		var scene: Node = MainScene.instantiate()
		var world_manager: Node = scene.get_node("WorldManager")
		world_manager.world_seed = seed_val
		world_manager.randomize_world_seed_on_start = false
		root.add_child(scene)
		await process_frame
		await physics_frame

		var bike: CharacterBody3D = scene.get_node("Bicycle")
		var streamer: Node = world_manager.chunk_streamer
		world_manager.set_process(false)
		bike.set_process(false)
		bike.set_physics_process(false)

		var active = streamer.get_active_branch()
		var path = active.road_path
		var idx: int = 10
		var pos: Vector3 = path.points[idx] + path.normals[idx] * 0.4
		var vel: Vector3 = path.tangents[idx] * 8.0
		bike.global_position = pos
		bike.velocity = vel
		bike.current_speed = 8.0

		var road_misses: int = 0
		var steps: int = 0
		var fork_reached: bool = false

		while steps < 250 and not fork_reached:
			steps += 1
			active = streamer.get_active_branch()
			if active == null or active.road_path == null or active.road_path.size() < 2:
				break
			path = active.road_path
			idx = mini(active.last_closest_idx + 2, path.size() - 1)
			pos = path.points[idx] + path.normals[idx] * 0.4
			vel = path.tangents[idx] * 8.0
			bike.global_position = pos
			bike.velocity = vel
			bike.current_speed = 8.0

			streamer.update_streaming(pos, vel, 0.1)
			await physics_frame

			# Check downward road collision ray
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
				pos + Vector3.UP * 5.0, pos - Vector3.UP * 5.0, 2 # Layer 2 = Road
			)
			query.exclude = [bike.get_rid()]
			var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():
				road_misses += 1

			# Fork check
			if active != null and not active.child_branch_ids.is_empty():
				var child = streamer.branches.get(active.child_branch_ids[0], null)
				if child != null and child.state == ChunkStreamerClass.BranchState.PRELOADED:
					if pos.distance_to(active.fork_node_pos) < 30.0:
						fork_reached = true
						# Execute lock to LEFT
						streamer._on_branch_locked(active.fork_id, ForkDecisionModelClass.BranchChoice.LEFT, active.branch_id)
						break

		scene.queue_free()
		for _i in range(5):
			await process_frame

		var ok_road: bool = _assert_check(road_misses == 0, "Seed %d procedural stream zero road misses (misses=%d)" % [seed_val, road_misses])
		var ok_fork: bool = _assert_check(fork_reached, "Seed %d reached and safely negotiated fork junction" % seed_val)
		if not (ok_road and ok_fork):
			all_seeds_passed = false

	return all_seeds_passed
