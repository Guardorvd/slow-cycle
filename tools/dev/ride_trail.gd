extends SceneTree

## BC2 dev launch for playtests: the real region scene (its own arguments
## --seed=, --trail-config=; cache or bake as usual), then the bike is placed
## ON a published trail, a few metres past where it leaves the road, facing
## along it. Everything else is the normal game (Input, recovery, menu).
##   godot --path . --script res://tools/dev/ride_trail.gd -- --seed=S
##       --trail-config=res://... [--trail=ID | --class=TECHNICAL] [--from=2] [--shot=ABS.png]
## --from=2 starts at the trail's second end, riding it the other way (not
## offered for a one-way trail: a TECHNICAL descent starts at its top).
## --shot: save one frame after spawning and quit (launch check only).
const WorldScene = preload("res://scenes/region/region_world.tscn")
## Metres past the road edge where the bike is placed.
const INTO_TRAIL_M: float = 6.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var only: String = ""
	var wanted_class: String = ""
	var from_end: int = 1
	var shot: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--trail="):
			only = arg.substr(8)
		elif arg.begins_with("--class="):
			wanted_class = arg.substr(8)
		elif arg.begins_with("--from="):
			from_end = int(arg.substr(7))
		elif arg.begins_with("--shot="):
			shot = arg.substr(7).replace("\\", "/")
	var scene: Node3D = WorldScene.instantiate()
	root.add_child(scene)
	while not scene.is_ready_to_ride() and not scene.failed:
		await process_frame
	if scene.failed:
		return
	var trails: Array = scene.products.network.get_trails()
	var chosen: Dictionary = {}
	for trail: Dictionary in trails:
		if (only.is_empty() or trail.id == only) and (wanted_class.is_empty() or trail.get("class_name", "SINGLETRACK") == wanted_class):
			chosen = trail
			break
	if chosen.is_empty():
		print("RIDE_TRAIL none published (", trails.size(), " trails) - normal spawn kept")
		if not shot.is_empty():
			await _save(shot)
			quit(0)
		return
	var line: Dictionary = chosen.line
	var n: int = line.s.size()
	var k: int
	var sign_dir: float
	if from_end == 2 and not "REVERSE" in chosen.directions:
		print("RIDE_TRAIL ", chosen.id, " is one-way (", chosen.directions, "): starting at its top")
		from_end = 1
	if from_end == 2:
		k = clampi(chosen.joins[1].leave_index - int(INTO_TRAIL_M), 0, n - 2)
		sign_dir = -1.0
	else:
		k = clampi(chosen.joins[0].leave_index + int(INTO_TRAIL_M), 1, n - 1)
		sign_dir = 1.0
	var p := Vector3(line.x[k], line.y[k], line.z[k])
	scene.streamer.ensure_around(p)
	for _settle in range(2):
		await physics_frame
	scene.spawn_bike(p, Vector3(line.tx[k], 0.0, line.tz[k]) * sign_dir)
	print("RIDE_TRAIL spawn trail=%s from=%d s=%.1f point=%s" % [chosen.id, from_end, line.s[k], str(p)])
	if shot.is_empty():
		return
	await _save(shot)
	var bike: Node3D = scene.get_bike()
	print("RIDE_TRAIL shot=%s bike=%s ground_drift_m=%.2f" % [shot, str(bike.global_position), bike.global_position.distance_to(p)])
	quit(0)


func _save(shot: String) -> void:
	for _wait in range(120):
		await physics_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(shot)
	print("RIDE_TRAIL shot=", shot)
