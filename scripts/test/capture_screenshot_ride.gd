extends SceneTree

var frames: int = 0
var main_node: Node3D
var player_bike: CharacterBody3D
var world_mgr: Node3D
var captured_distances: Array[float] = [0.0, 100.0, 200.0, 300.0, 450.0, 600.0]
var current_target_idx: int = 0

func _init() -> void:
	print("Starting ride capture test...")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	main_node = main_scene
	world_mgr = main_node.get_node("WorldManager")
	player_bike = main_node.get_node("Bicycle")
	
	# Fix the seed so it is 100% deterministic
	world_mgr.world_seed = 184729
	world_mgr.randomize_world_seed_on_start = false

func _process(delta: float) -> bool:
	frames += 1
	if frames < 5:
		return false
		
	if player_bike and world_mgr:
		# Teleport or move the bike forward along the active road path to target distances
		var streamer = world_mgr.chunk_streamer
		if streamer:
			var active_b = streamer.get_active_branch()
			if active_b and active_b.road_path and active_b.road_path.size() > 5:
				var path = active_b.road_path
				var target_dist = captured_distances[current_target_idx]
				
				# Find sample closest to target_dist
				var sample = path.get_sample_at_distance(target_dist)
				var pt = sample.get("position", Vector3.ZERO)
				var tang = sample.get("tangent", Vector3.FORWARD)
				var norm = sample.get("normal", Vector3.UP)
				
				player_bike.global_position = pt + norm * 0.4
				var horiz = Vector3(tang.x, 0.0, tang.z).normalized()
				if not horiz.is_zero_approx():
					player_bike.global_basis = Basis.looking_at(horiz, Vector3.UP)
				
				# Trigger streamer update
				streamer.update_streaming(player_bike.global_position, tang * 8.0, 0.016)
				
				# Wait a couple frames at this position to render
				if frames % 5 == 0:
					var img = root.get_viewport().get_texture().get_image()
					if img != null:
						var filename = "res://screenshots/shot_dist_%03dm.png" % int(target_dist)
						img.save_png(filename)
						print("Saved screenshot: ", filename, " at route pos: ", pt)
					current_target_idx += 1
					if current_target_idx >= captured_distances.size():
						print("All target distances captured!")
						quit()
						return true
	return false
