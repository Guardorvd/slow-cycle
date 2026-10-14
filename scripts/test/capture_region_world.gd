extends SceneTree

## PR1 Vulkan captures of real Input rides in the region runtime scene.
## Run windowed (Forward+ / Vulkan). Saves and reloads every PNG, printing a
## CAPTURE receipt (view, camera, seed, distance, png sha256).
##   --target=r7_fixture   M1: authenticated v1 route slice
##   --target=region       PR1 runtime scene (cache or bake; --seed=N read by
##                         the scene): network overview + ride captures
##   --out=DIR             capture directory (required)
const Source = preload("res://scripts/test/final_surface_route_source.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Slice = preload("res://scripts/world/final_surface_slice.gd")
const Bot = preload("res://scripts/test/region_ride_bot.gd")
const WorldScene = preload("res://scenes/region/region_world.tscn")

var _out: String = ""
var _target: String = ""
var _count: int = 0
var _seed: int = 184729
var _region_xz := [0, 0]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--target="):
			_target = arg.substr(9)
	if _out.is_empty() or not _target in ["r7_fixture", "region"]:
		push_error("CAPTURE_FAIL ERR_CAPTURE_CLI")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	if _target == "region":
		await _region()
		return
	var source: Dictionary = Source.build("fixture")
	var deformer: Dictionary = Deformer.create(source.route, source.field)
	var surface: RefCounted = Surface.create(source.terrain, source.field, deformer.deformer).surface
	var scene: Node3D = WorldScene.instantiate()
	var slice := Slice.new()
	var built: Dictionary = slice.build(surface, source.hydrology, source.route)
	if not built.is_valid:
		push_error("CAPTURE_FAIL " + built.reason_code)
		quit(1)
		return
	scene.attach_content(slice)
	var path: PackedVector3Array = Bot.route_polyline(source.route.get_data())
	scene.set_recovery_paths([path])
	scene.spawn_bike(path[0], path[1] - path[0])
	scene.auto_bake = false
	root.add_child(scene)
	var bike: BicycleController = scene.get_bike()
	var bot: RefCounted = Bot.new().setup(path, 7.5)
	var shots: Array = [[60.0, "first_person"], [330.0, "third_person"], [600.0, "third_person"], [900.0, "first_person"]]
	for _settle in range(30):
		await physics_frame
	var next: int = 0
	var frames: int = 0
	while next < shots.size() and frames < 60 * 400:
		await physics_frame
		frames += 1
		bot.step(bike)
		if bot.stats.finished:
			break
		if bot.s_now >= shots[next][0]:
			await _capture(scene, bike, shots[next][1], bot.s_now)
			next += 1
	bot.release_inputs()
	print("CAPTURE_SUMMARY target=%s captures=%d expected=%d" % [_target, _count, shots.size()])
	quit(0 if _count == shots.size() else 1)


## PR1 region: the real scene loads its bake, one overview from above the
## spawn, then ride captures along a network tour from the spawn edge.
func _region() -> void:
	var scene: Node3D = WorldScene.instantiate()
	root.add_child(scene)
	var t0: int = Time.get_ticks_usec()
	while not scene.is_ready_to_ride() and (Time.get_ticks_usec() - t0) / 1e6 < 3000.0:
		await process_frame
	if not scene.is_ready_to_ride():
		push_error("CAPTURE_FAIL region not ready")
		quit(1)
		return
	_seed = scene.session_seed
	_region_xz = [scene.region.x, scene.region.y]
	var data: Dictionary = scene.products.network.get_data()
	var spawn: Dictionary = scene.products.spawn
	var start_edge: int = int(String(spawn.piece).get_slice(":", 1))
	var path: PackedVector3Array = Bot.longest_tour(data, start_edge, 3200.0).path
	var bike: BicycleController = scene.get_bike()
	# Overview: a temporary camera high above the spawn, looking down the valley.
	var previous: Camera3D = root.get_viewport().get_camera_3d()
	var overview := Camera3D.new()
	overview.far = 6000.0
	# The overview looks across kilometres: its own copy of the scene
	# environment without fog (this camera only; the ride captures keep it).
	var world_env: WorldEnvironment = scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null and world_env.environment != null:
		var clear: Environment = world_env.environment.duplicate()
		clear.fog_enabled = false
		clear.volumetric_fog_enabled = false
		overview.environment = clear
	scene.add_child(overview)
	overview.global_position = spawn.position + Vector3(-260.0, 320.0, -260.0)
	overview.look_at(spawn.position + Vector3(250.0, 0.0, 250.0), Vector3.UP)
	overview.make_current()
	await _capture_current(bike, "overview", 0.0)
	if previous != null:
		previous.make_current()
	overview.queue_free()
	scene.streamer.ensure_around(path[0])
	scene.spawn_bike(path[0], path[1] - path[0])
	var bot: RefCounted = Bot.new().setup(path, 7.5)
	var shots: Array = [[80.0, "third_person"], [700.0, "first_person"], [1500.0, "third_person"], [2300.0, "third_person"], [3000.0, "first_person"]]
	for _settle in range(30):
		await physics_frame
	var next: int = 0
	var frames: int = 0
	while next < shots.size() and frames < 60 * 1500:
		await physics_frame
		frames += 1
		bot.step(bike)
		if bot.stats.finished:
			break
		if bot.s_now >= shots[next][0]:
			await _capture(scene, bike, shots[next][1], bot.s_now)
			next += 1
	bot.release_inputs()
	print("CAPTURE_SUMMARY target=%s captures=%d expected=%d" % [_target, _count, shots.size() + 1])
	quit(0 if _count == shots.size() + 1 else 1)


func _capture(scene: Node3D, bike: BicycleController, view: String, distance: float) -> void:
	var rig: Node = bike.get_node("CameraRig")
	var third: bool = not bool(rig.get("is_first_person"))
	if (view == "third_person") != third:
		Input.action_press("toggle_camera")
		await process_frame
		Input.action_release("toggle_camera")
	await _capture_current(bike, view, distance)


func _capture_current(bike: BicycleController, view: String, distance: float) -> void:
	for _wait in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var file: String = _out.path_join("%s_%02d_%s_%04dm.png" % [_target, _count, view, int(distance)])
	if image.save_png(file) != OK:
		push_error("CAPTURE_FAIL save " + file)
		return
	var saved: Image = Image.load_from_file(file)
	if saved.is_empty() or saved.get_size() != image.get_size():
		push_error("CAPTURE_FAIL reload " + file)
		return
	_count += 1
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	print("CAPTURE ", JSON.stringify({"target": _target, "view": view, "path": file, "distance_m": distance, "width": saved.get_width(), "height": saved.get_height(),
		"camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "bike": [bike.global_position.x, bike.global_position.y, bike.global_position.z],
		"speed_ms": bike.current_speed, "png_sha256": FileAccess.get_sha256(file), "seed": _seed, "region": _region_xz}))
