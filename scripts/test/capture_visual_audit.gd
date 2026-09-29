extends SceneTree

var frames: int = 0
var main_node: Node3D
var player_bike: CharacterBody3D
var world_mgr: Node3D
var drone_cam: Camera3D

var capture_queue: Array[Dictionary] = [
	{"name": "01_start_handlebar_000m.png", "dist": 0.0, "mode": "fp", "altitude": 0.0},
	{"name": "02_straight_handlebar_100m.png", "dist": 100.0, "mode": "fp", "altitude": 0.0},
	{"name": "03_switchback_handlebar_220m.png", "dist": 220.0, "mode": "fp", "altitude": 0.0},
	{"name": "04_switchback_chase_220m.png", "dist": 220.0, "mode": "tp", "altitude": 0.0},
	{"name": "05_straight_after_turn_300m.png", "dist": 300.0, "mode": "fp", "altitude": 0.0},
	{"name": "06_winding_singletrack_520m.png", "dist": 520.0, "mode": "fp", "altitude": 0.0},
	{"name": "07_aerial_drone_overview_start.png", "dist": 100.0, "mode": "drone", "altitude": 45.0, "pitch": -55.0},
	{"name": "08_aerial_drone_overview_switchback.png", "dist": 250.0, "mode": "drone", "altitude": 55.0, "pitch": -60.0}
]

var queue_idx: int = 0
var wait_ticks: int = 0

func _init() -> void:
	print("--- VISUAL AUDIT: Starting High-Fidelity Capture ---")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	main_node = main_scene
	world_mgr = main_node.get_node("WorldManager")
	player_bike = main_node.get_node("Bicycle")
	
	# Guarantee deterministic seed
	world_mgr.world_seed = 184729
	world_mgr.randomize_world_seed_on_start = false
	
	# Create drone camera
	drone_cam = Camera3D.new()
	drone_cam.name = "DroneCamera"
	drone_cam.current = false
	drone_cam.fov = 70.0
	main_node.add_child(drone_cam)

func _process(delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
		
	var streamer = world_mgr.chunk_streamer if world_mgr else null
	if not streamer or not player_bike:
		return false
		
	var active_b = streamer.get_active_branch()
	if not active_b or not active_b.road_path or active_b.road_path.size() < 10:
		return false
		
	var path = active_b.road_path
	
	if queue_idx >= capture_queue.size():
		print("--- VISUAL AUDIT: All frames successfully captured! ---")
		quit()
		return true

	var item = capture_queue[queue_idx]
	var target_dist: float = item.dist
	
	# Sample path
	var sample = path.get_sample_at_distance(target_dist)
	var pt: Vector3 = sample.get("position", Vector3.ZERO)
	var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
	var norm: Vector3 = sample.get("normal", Vector3.UP)
	
	# Position bike
	player_bike.global_position = pt + norm * 0.4
	var horiz = Vector3(tang.x, 0.0, tang.z).normalized()
	if not horiz.is_zero_approx():
		player_bike.global_basis = Basis.looking_at(horiz, Vector3.UP)
		
	# Update streaming ahead from this point
	streamer.update_streaming(player_bike.global_position, tang * 10.0, 0.016)
	
	# Setup camera mode
	var rig = player_bike.get_node_or_null("CameraRig")
	if item.mode == "drone":
		if rig:
			if rig.first_person_cam: rig.first_person_cam.current = false
			if rig.third_person_cam: rig.third_person_cam.current = false
		drone_cam.current = true
		var cam_pos = pt + Vector3(0, item.altitude, 25.0)
		drone_cam.global_position = cam_pos
		drone_cam.look_at(pt, Vector3.UP)
	elif item.mode == "tp":
		drone_cam.current = false
		if rig:
			if rig.first_person_cam: rig.first_person_cam.current = false
			if rig.third_person_cam:
				rig.third_person_cam.current = true
				if rig.has_method("switch_to_third_person"):
					rig.switch_to_third_person()
	else: # fp
		drone_cam.current = false
		if rig:
			if rig.third_person_cam: rig.third_person_cam.current = false
			if rig.first_person_cam:
				rig.first_person_cam.current = true
				if rig.has_method("switch_to_first_person"):
					rig.switch_to_first_person()
					
	wait_ticks += 1
	if wait_ticks >= 6: # Wait 6 frames for rendering & streaming to stabilize
		wait_ticks = 0
		var img = root.get_viewport().get_texture().get_image()
		if img != null:
			var save_path = "res://screenshots/" + item.name
			img.save_png(save_path)
			print("[SAVED] " + item.name + " at dist " + str(target_dist) + "m (" + item.mode + ")")
		queue_idx += 1
		
	return false
