extends SceneTree

## Airborne Empirical Physics Calibration Gate (v5.3)
## Measures real BicycleController dynamics over the 6-tier synthetic ladder
## to empirically calibrate and verify generation bounds.
## DOES NOT MODIFY BicycleController!

const BicycleScene = preload("res://scenes/player/bicycle.tscn")

const CALIBRATION_LADDER: Array[Dictionary] = [
	{"name": "Ladder 1: Micro-Drop (h=0.20m, L=1.0m)", "drop_h": 0.20, "landing_grade": -6.0, "speed": 7.0, "target_gap": 1.0},
	{"name": "Ladder 2: Micro-Drop (h=0.35m, L=2.0m)", "drop_h": 0.35, "landing_grade": -8.0, "speed": 7.5, "target_gap": 2.0},
	{"name": "Ladder 3: Step Drop  (h=0.50m, L=2.0m)", "drop_h": 0.50, "landing_grade": -10.0, "speed": 8.0, "target_gap": 2.0},
	{"name": "Ladder 4: MTB Drop   (h=0.80m, L=4.0m)", "drop_h": 0.80, "landing_grade": -12.0, "speed": 8.5, "target_gap": 4.0},
	{"name": "Ladder 5: High Drop  (h=1.00m, L=5.0m)", "drop_h": 1.00, "landing_grade": -13.0, "speed": 9.0, "target_gap": 5.0},
	{"name": "Ladder 6: Limit Drop (h=1.20m, L=6.0m)", "drop_h": 1.20, "landing_grade": -14.0, "speed": 9.5, "target_gap": 6.0}
]

func _init() -> void:
	print("\n==================================================================")
	print("    SLOW CYCLE — AIRBORNE EMPIRICAL CALIBRATION GATE (v5.3)       ")
	print("==================================================================\n")
	_run_calibration()

func _run_calibration() -> void:
	var results: Array[Dictionary] = []
	var all_passed: bool = true

	for tier in CALIBRATION_LADDER:
		print("Simulating %s..." % tier["name"])
		var res = await _simulate_synthetic_tier(tier)
		results.append(res)
		if not res["is_stable"]:
			all_passed = false

	print("\n---------------------------------------------------------------------------------------------------------")
	print("                          EMPIRICAL PHYSICS CALIBRATION RESULTS                                          ")
	print("---------------------------------------------------------------------------------------------------------")
	print("%-38s | %-8s | %-9s | %-10s | %-11s | %s" % [
		"Drop Scenario", "Air Time", "Air Dist", "Landing Vy", "Suspension", "Stability"
	])
	print("---------------------------------------------------------------------------------------------------------")

	for r in results:
		var name_str: String = str(r["name"])
		var time_str: String = "%.3f s" % float(r["air_time_s"])
		var dist_str: String = "%.2f m" % float(r["air_dist_m"])
		var vy_str: String = "%.2f m/s" % float(r["landing_vy"])
		var susp_str: String = "%d mm" % int(r["susp_compression_mm"])
		var stab_str: String = "PASS [STABLE]" if bool(r["is_stable"]) else "WARN [INSTABILITY]"

		print("%-38s | %-8s | %-9s | %-10s | %-11s | %s" % [
			name_str, time_str, dist_str, vy_str, susp_str, stab_str
		])

	print("---------------------------------------------------------------------------------------------------------")
	if all_passed:
		print(">>> ALL 6 LADDER TIERS SUCCESSFULLY CALIBRATED AND VERIFIED WITH REAL PHYSICS [OK]\n")
	else:
		print(">>> SOME TIERS FAILED PHYSICAL STABILITY ENVELOPE [FAIL]\n")

	quit(0 if all_passed else 1)

func _simulate_synthetic_tier(cfg: Dictionary) -> Dictionary:
	var drop_h: float = float(cfg["drop_h"])
	var landing_grade: float = float(cfg["landing_grade"])
	var app_speed: float = float(cfg["speed"])
	var name_str: String = str(cfg["name"])

	var world := Node3D.new()
	root.add_child(world)

	var col_body := StaticBody3D.new()
	col_body.collision_layer = 2 # Layer 2: Road
	world.add_child(col_body)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w: float = 3.5

	# Approach table (y = drop_h, z from -20 to 10)
	st.add_vertex(Vector3(-w, drop_h, -20)); st.add_vertex(Vector3(w, drop_h, 10)); st.add_vertex(Vector3(-w, drop_h, 10))
	st.add_vertex(Vector3(-w, drop_h, -20)); st.add_vertex(Vector3(w, drop_h, -20)); st.add_vertex(Vector3(w, drop_h, 10))

	# Landing ramp (y starts at 0 at z = 10, slopes down by landing_grade)
	var slope_rad: float = deg_to_rad(landing_grade)
	var land_len: float = 50.0
	var dy: float = land_len * sin(slope_rad)
	var dz: float = land_len * cos(slope_rad)
	var z_end: float = 10.0 + dz

	st.add_vertex(Vector3(-w, 0, 10)); st.add_vertex(Vector3(w, dy, z_end)); st.add_vertex(Vector3(-w, dy, z_end))
	st.add_vertex(Vector3(-w, 0, 10)); st.add_vertex(Vector3(w, 0, 10)); st.add_vertex(Vector3(w, dy, z_end))

	var mesh: ArrayMesh = st.commit()
	var col_shape := CollisionShape3D.new()
	col_shape.shape = mesh.create_trimesh_shape()
	col_body.add_child(col_shape)

	var bike: CharacterBody3D = BicycleScene.instantiate()
	world.add_child(bike)
	for _i in range(2):
		await process_frame
	bike.global_position = Vector3(0.0, drop_h + 0.45, 0.0)
	bike.look_at(Vector3(0.0, drop_h + 0.45, 10.0), Vector3.UP)
	bike.current_speed = app_speed
	bike.velocity = Vector3(0, 0, app_speed)

	var air_frames: int = 0
	var landed: bool = false
	var landing_vy: float = 0.0
	var max_susp_comp: float = 0.0
	var start_air_pos: Vector3 = Vector3.ZERO
	var end_air_pos: Vector3 = Vector3.ZERO

	for _step in range(120):
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
		"is_stable": landed and (absf(landing_vy) < 6.5) and (absf(max_susp_comp) < 0.041)
	}
