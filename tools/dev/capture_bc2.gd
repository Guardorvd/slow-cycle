extends SceneTree

## BC2 dev PLAYTEST captures (Vulkan, windowed): PLACEMENT shots of every
## published trail - the camera or the bike is placed by this tool, nothing is
## ridden, so a capture is not a ride check. The real region scene loads its
## products (cache or bake) from its own arguments (--seed=, --trail-config=).
## Per trail: an overview from above, the first join seen from the road, the
## steepest point, the middle and the way to the second join; each PNG
## is saved, reloaded and printed as a CAPTURE receipt.
##   godot --path . --script res://tools/dev/capture_bc2.gd -- --seed=S
##       --trail-config=res://... --out=ABS_DIR [--trail=ID]
##       [--views=overview,join1_from_road,steepest,middle,toward_join2]
const WorldScene = preload("res://scenes/region/region_world.tscn")

var _out: String = ""
var _only: String = ""
var _views: Array = ["overview", "join1_from_road", "steepest", "middle", "toward_join2"]
var _count: int = 0
var _scene: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--trail="):
			_only = arg.substr(8)
		elif arg.begins_with("--views="):
			_views = Array(arg.substr(8).split(","))
	if _out.is_empty():
		push_error("CAPTURE_FAIL ERR_CAPTURE_CLI")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_scene = WorldScene.instantiate()
	root.add_child(_scene)
	var t0: int = Time.get_ticks_usec()
	while not _scene.is_ready_to_ride() and not _scene.failed and (Time.get_ticks_usec() - t0) / 1e6 < 3000.0:
		await process_frame
	if not _scene.is_ready_to_ride():
		push_error("CAPTURE_FAIL region not ready")
		quit(1)
		return
	var trails: Array = _scene.products.network.get_trails()
	print("CAPTURE_TRAILS ", trails.size(), " source=", _scene.source)
	var expected: int = 0
	for trail: Dictionary in trails:
		if not _only.is_empty() and trail.id != _only:
			continue
		expected += _views.size()
		await _trail_shots(trail)
	print("CAPTURE_SUMMARY captures=%d expected=%d" % [_count, expected])
	quit(0 if _count == expected and expected > 0 else 1)


func _trail_shots(trail: Dictionary) -> void:
	var line: Dictionary = trail.line
	var n: int = line.s.size()
	var at := func(k: int) -> Vector3: return Vector3(line.x[k], line.y[k], line.z[k])
	var along := func(k: int) -> Vector3: return Vector3(line.tx[k], 0.0, line.tz[k])
	var first: int = trail.joins[0].leave_index
	var last: int = trail.joins[1].leave_index
	# Steepest interior point (4 m window).
	var steep: int = (first + last) / 2
	var steep_grade: float = -1.0
	for k in range(first + 4, last - 4):
		var grade: float = absf(line.y[k + 2] - line.y[k - 2]) / (line.s[k + 2] - line.s[k - 2])
		if grade > steep_grade:
			steep_grade = grade
			steep = k
	# Overview from above the middle of the trail.
	var middle: Vector3 = at.call(n / 2)
	var span: float = at.call(0).distance_to(at.call(n - 1))
	var camera := Camera3D.new()
	camera.far = 6000.0
	var env: WorldEnvironment = _scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env != null and env.environment != null:
		var clear: Environment = env.environment.duplicate()
		clear.fog_enabled = false
		clear.volumetric_fog_enabled = false
		camera.environment = clear
	_scene.add_child(camera)
	var normal_mid := Vector3(-line.tz[n / 2], 0.0, line.tx[n / 2])
	_scene.streamer.ensure_around(middle)
	camera.global_position = middle + normal_mid * span * 0.55 + Vector3(0.0, span * 0.45, 0.0)
	camera.look_at(middle, Vector3.UP)
	var previous: Camera3D = root.get_viewport().get_camera_3d()
	camera.make_current()
	if "overview" in _views:
		await _shot(trail, "overview", n / 2, camera)
	# Join 1 seen from the road, 18 m before the trail leaves it, looking at it.
	var join1: Vector3 = at.call(first)
	var road_dir: Vector3 = _road_tangent(trail.joins[0])
	var stand: Vector3 = at.call(0) - road_dir * 16.0 * signf(road_dir.dot(join1 - at.call(0)) + 1e-6)
	_scene.streamer.ensure_around(stand)
	for _settle in range(3):
		await physics_frame
	var stand_y: float = _ground(stand)
	camera.global_position = Vector3(stand.x, (line.y[0] if is_nan(stand_y) else stand_y) + 1.7, stand.z)
	camera.look_at(at.call(mini(first + 12, n - 1)) + Vector3(0.0, 0.8, 0.0), Vector3.UP)
	if "join1_from_road" in _views:
		await _shot(trail, "join1_from_road", first, camera)
	if previous != null:
		previous.make_current()
	camera.queue_free()
	# Bike placed on the trail, third-person camera of the bike itself.
	if "steepest" in _views:
		await _bike_shot(trail, "steepest_%.0fpct" % (steep_grade * 100.0), steep, at, along, 1.0)
	if "middle" in _views:
		await _bike_shot(trail, "middle", (first + last) / 2, at, along, 1.0)
	if "toward_join2" in _views:
		await _bike_shot(trail, "toward_join2", maxi(first, last - 25), at, along, 1.0)


func _road_tangent(join: Dictionary) -> Vector3:
	var data: Dictionary = _scene.products.network.get_data()
	for piece: Dictionary in data.pieces:
		if piece.id != join.piece:
			continue
		var d: Dictionary = piece.design
		var best: int = 0
		var best_d: float = INF
		for k in range(d.s.size()):
			var distance: float = Vector2(d.x[k] - join.x_m, d.z[k] - join.z_m).length()
			if distance < best_d:
				best_d = distance
				best = k
		return Vector3(d.tx[best], 0.0, d.tz[best]).normalized()
	return Vector3.FORWARD


## Height of the collision ground under a point (NAN without a hit).
func _ground(p: Vector3) -> float:
	var space := root.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 200, 0), p - Vector3(0, 200, 0)))
	return hit.position.y if not hit.is_empty() else NAN


func _bike_shot(trail: Dictionary, view: String, k: int, at: Callable, along: Callable, direction: float) -> void:
	var p: Vector3 = at.call(k)
	_scene.streamer.ensure_around(p)
	_scene.spawn_bike(p, along.call(k) * direction)
	var bike: Node3D = _scene.get_bike()
	var rig: Node = bike.get_node_or_null("CameraRig")
	if rig != null and bool(rig.get("is_first_person")):
		# The view the player's V key selects (state of the rig, not its code).
		rig.set("is_first_person", false)
		rig.call("_apply_camera_mode")
	# Brake held while the bike settles: on a steep descent it rolls away.
	Input.action_press("brake")
	for _settle in range(45):
		await physics_frame
	await _shot(trail, view, k, root.get_viewport().get_camera_3d())
	Input.action_release("brake")


func _shot(trail: Dictionary, view: String, k: int, camera: Camera3D) -> void:
	for _wait in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	var name: String = String(trail.id).replace("trail:", "").replace(":", "_")
	var file: String = _out.path_join("%02d_%s_%s.png" % [_count, name, view])
	if image.save_png(file) != OK:
		push_error("CAPTURE_FAIL save " + file)
		return
	var saved: Image = Image.load_from_file(file)
	if saved.is_empty() or saved.get_size() != image.get_size():
		push_error("CAPTURE_FAIL reload " + file)
		return
	_count += 1
	var line: Dictionary = trail.line
	print("CAPTURE ", JSON.stringify({"kind": "PLACEMENT", "trail": trail.id, "view": view, "path": file, "s_m": line.s[k], "point": [line.x[k], line.y[k], line.z[k]],
		"camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "width": saved.get_width(), "height": saved.get_height(),
		"png_sha256": FileAccess.get_sha256(file), "seed": _scene.session_seed, "region": [_scene.region.x, _scene.region.y]}))
