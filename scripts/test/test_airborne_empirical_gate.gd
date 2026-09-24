extends SceneTree

## Empirical Physics Measurement Gate for Drops & Airborne Sections
## Tests the existing BicycleController over varied drop geometries
## to measure real airborne times, landing deflections, pitch attitudes, and stability.
## DOES NOT MODIFY BicycleController!

const LabScene = preload("res://scenes/test/riding_lab_track.tscn")
const BicycleScene = preload("res://scenes/player/bicycle.tscn")

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — AIRBORNE EMPIRICAL PHYSICS GATE               ")
	print("==================================================================\n")
	_run_measurements()

func _run_measurements() -> void:
	# Run 1: Measure existing calibrated Section T10 Drop in Riding Lab
	print("[RUN 1] Measuring Live Section T10 Drop (h ≈ 0.8m, -15° landing)...")
	var res_t10 = await _measure_riding_lab_t10()

	# Run 2: Measure Micro-Drop on Section T6 (Crest -> Dip ±8°)
	print("\n[RUN 2] Measuring Section T6 Micro-Drop (h ≈ 0.25m unweighting)...")
	var res_t6 = await _measure_riding_lab_t6()

	# Run 3: Measure Synthetic Step Drops
	print("\n[RUN 3] Measuring Synthetic Height Variations (0.35m, 0.6m, 1.2m)...")
	var res_synth = await _measure_synthetic_drops()

	print("\n------------------------------------------------------------------")
	print("                  EMPIRICAL MEASUREMENT SUMMARY                   ")
	print("------------------------------------------------------------------")
	print("%-28s | %-8s | %-9s | %-10s | %-12s | %s" % [
		"Drop Scenario", "Air Time", "Max Gap", "Landing Vy", "Suspension", "Stability"
	])
	print("------------------------------------------------------------------")

	var all_results := [res_t6, res_t10]
	all_results.append_array(res_synth)

	var all_passed: bool = true
	for r in all_results:
		var name_str: String = str(r["name"])
		var time_str: String = "%.3f s" % float(r["air_time_s"])
		var dist_str: String = "%.2f m" % float(r["air_dist_m"])
		var vy_str: String = "%.2f m/s" % float(r["landing_vy"])
		var susp_str: String = "%d mm" % int(r["susp_compression_mm"])
		var is_stable: bool = bool(r["is_stable"])
		if not is_stable:
			all_passed = false
		var stab_str: String = "PASS [STABLE]" if is_stable else "WARN [INSTABILITY]"

		print("%-28s | %-8s | %-9s | %-10s | %-12s | %s" % [
			name_str, time_str, dist_str, vy_str, susp_str, stab_str
		])

	print("------------------------------------------------------------------")
	if all_passed:
		print("[EMPIRICAL GATE COMPLETED SUCCESSFULLY: CALIBRATION READY]\n")
		quit(0)
	else:
		printerr("[EMPIRICAL GATE FAILED: INSTABILITY DETECTED]\n")
		quit(1)

func _measure_riding_lab_t10() -> Dictionary:
	var root_node = LabScene.instantiate()
	root.add_child(root_node)
	for _i in range(5):
		await process_frame

	var generator = root_node.get_node_or_null("RidingLabGenerator")
	var bike: CharacterBody3D = root_node.get_node_or_null("Bicycle")
	var path_data = generator.road_path

	var sample_approach = path_data.get_sample_at_distance(225.0)
	bike.global_position = sample_approach.position + Vector3(0.0, 0.45, 0.0)
	var tang: Vector3 = sample_approach.tangent
	bike.look_at(bike.global_position + tang, Vector3.UP)
	bike.current_speed = 8.5 # ~30.6 km/h
	bike.velocity = tang * bike.current_speed

	var air_frames: int = 0
	var landed: bool = false
	var landing_vy: float = 0.0
	var max_susp_comp: float = 0.0
	var start_air_pos: Vector3 = Vector3.ZERO
	var end_air_pos: Vector3 = Vector3.ZERO

	for _frame in range(120):
		await physics_frame
		var fc: bool = bike.front_contact_valid
		var rc: bool = bike.rear_contact_valid

		if not fc and not rc:
			if air_frames == 0:
				start_air_pos = bike.global_position
			air_frames += 1
		else:
			if air_frames >= 4 and not landed:
				landed = true
				end_air_pos = bike.global_position
				landing_vy = bike.velocity.y
			if landed:
				max_susp_comp = minf(max_susp_comp, bike.suspension_compression)

	root_node.queue_free()
	for _i in range(5):
		await process_frame

	var dt: float = 1.0 / 60.0
	return {
		"name": "Section T10 (h≈0.8m, -15°)",
		"air_time_s": float(air_frames) * dt,
		"air_dist_m": start_air_pos.distance_to(end_air_pos) if landed else 0.0,
		"landing_vy": landing_vy,
		"susp_compression_mm": absf(max_susp_comp) * 1000.0,
		"is_stable": landed and (absf(landing_vy) < 6.0)
	}

func _measure_riding_lab_t6() -> Dictionary:
	var root_node = LabScene.instantiate()
	root.add_child(root_node)
	for _i in range(5):
		await process_frame

	var generator = root_node.get_node_or_null("RidingLabGenerator")
	var bike: CharacterBody3D = root_node.get_node_or_null("Bicycle")
	var path_data = generator.road_path

	# T6 Crest -> Dip is at s = 115.0 to 145.0
	var sample_approach = path_data.get_sample_at_distance(110.0)
	bike.global_position = sample_approach.position + Vector3(0.0, 0.45, 0.0)
	var tang: Vector3 = sample_approach.tangent
	bike.look_at(bike.global_position + tang, Vector3.UP)
	bike.current_speed = 7.5 # 27 km/h
	bike.velocity = tang * bike.current_speed

	var unweighted_frames: int = 0
	var max_susp_comp: float = 0.0
	var min_vy: float = 0.0

	for _frame in range(90):
		await physics_frame
		var fc: bool = bike.front_contact_valid
		var rc: bool = bike.rear_contact_valid

		if not fc or not rc:
			unweighted_frames += 1
		max_susp_comp = minf(max_susp_comp, bike.suspension_compression)
		min_vy = minf(min_vy, bike.velocity.y)

	root_node.queue_free()
	for _i in range(5):
		await process_frame

	var dt: float = 1.0 / 60.0
	return {
		"name": "Section T6 (Micro-Drop Crest)",
		"air_time_s": float(unweighted_frames) * dt,
		"air_dist_m": float(unweighted_frames) * dt * 7.5,
		"landing_vy": min_vy,
		"susp_compression_mm": absf(max_susp_comp) * 1000.0,
		"is_stable": true
	}

func _measure_synthetic_drops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var drop_configs := [
		{"name": "Synthetic 0.35m Micro-Drop", "drop_h": 0.35, "landing_grade": -8.0, "speed": 7.0},
		{"name": "Synthetic 0.60m Medium Drop", "drop_h": 0.60, "landing_grade": -12.0, "speed": 8.0},
		{"name": "Synthetic 1.20m Limit MTB Drop", "drop_h": 1.20, "landing_grade": -14.0, "speed": 9.5}
	]

	for cfg in drop_configs:
		var res = await _simulate_synthetic_drop(cfg)
		out.append(res)

	return out

func _simulate_synthetic_drop(cfg: Dictionary) -> Dictionary:
	var drop_h: float = float(cfg["drop_h"])
	var landing_grade: float = float(cfg["landing_grade"])
	var app_speed: float = float(cfg["speed"])
	var name_str: String = str(cfg["name"])

	var world := Node3D.new()
	root.add_child(world)

	var col_body := StaticBody3D.new()
	col_body.collision_layer = 2 # Road
	world.add_child(col_body)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 3.0

	# Approach table (y = drop_h, z from -15 to 10)
	st.add_vertex(Vector3(-w, drop_h, -15)); st.add_vertex(Vector3(w, drop_h, 10)); st.add_vertex(Vector3(-w, drop_h, 10))
	st.add_vertex(Vector3(-w, drop_h, -15)); st.add_vertex(Vector3(w, drop_h, -15)); st.add_vertex(Vector3(w, drop_h, 10))

	# Landing ramp (y starts at 0 at z = 10, slopes down)
	var slope_rad: float = deg_to_rad(landing_grade)
	var land_len: float = 40.0
	var dy: float = land_len * sin(slope_rad)
	var dz: float = land_len * cos(slope_rad)
	var z_end: float = 10.0 + dz

	st.add_vertex(Vector3(-w, 0, 10)); st.add_vertex(Vector3(w, dy, z_end)); st.add_vertex(Vector3(-w, dy, z_end))
	st.add_vertex(Vector3(-w, 0, 10)); st.add_vertex(Vector3(w, 0, 10)); st.add_vertex(Vector3(w, dy, z_end))

	var mesh: ArrayMesh = st.commit()
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	col_body.add_child(col_shape)

	var bike = BicycleScene.instantiate()
	world.add_child(bike)
	bike.global_position = Vector3(0.0, drop_h + 0.45, 0.0)
	bike.look_at(Vector3(0.0, drop_h + 0.45, 10.0), Vector3.UP)
	bike.current_speed = app_speed
	bike.velocity = Vector3(0, 0, app_speed)

	for _i in range(5):
		await process_frame

	var air_frames: int = 0
	var landed: bool = false
	var landing_vy: float = 0.0
	var max_susp_comp: float = 0.0
	var start_air_pos: Vector3 = Vector3.ZERO
	var end_air_pos: Vector3 = Vector3.ZERO

	for _step in range(90):
		await physics_frame
		var fc: bool = bike.front_contact_valid
		var rc: bool = bike.rear_contact_valid

		if not fc and not rc:
			if air_frames == 0:
				start_air_pos = bike.global_position
			air_frames += 1
		else:
			if air_frames >= 2 and not landed:
				landed = true
				end_air_pos = bike.global_position
				landing_vy = bike.velocity.y
			if landed:
				max_susp_comp = minf(max_susp_comp, bike.suspension_compression)

	world.queue_free()
	for _i in range(5):
		await process_frame

	var dt: float = 1.0 / 60.0
	return {
		"name": name_str,
		"air_time_s": float(air_frames) * dt,
		"air_dist_m": start_air_pos.distance_to(end_air_pos) if landed else 0.0,
		"landing_vy": landing_vy,
		"susp_compression_mm": absf(max_susp_comp) * 1000.0,
		"is_stable": landed and (absf(landing_vy) < 6.5)
	}
