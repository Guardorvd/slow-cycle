extends SceneTree

## PR1 Input-driven rides of the existing bicycle in the region runtime scene
## (registered collision, real physics, no teleport during a ride).
##   --target=r7_fixture   M1: authenticated v1 route slice, both directions
##   --out=DIR             JSON report (required)
## Output: RIDE_RUN lines, report and RIDE_SUMMARY checks=.. failures=.. completed=true.
const Source = preload("res://scripts/test/final_surface_route_source.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Slice = preload("res://scripts/world/final_surface_slice.gd")
const Bot = preload("res://scripts/test/region_ride_bot.gd")
const WorldScene = preload("res://scenes/region/region_world.tscn")

var _checks: int = 0
var _failures: Array = []
var _runs: Array = []
var _out: String = ""
var _target: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"check": label, "detail": str(detail)})
		print("RIDE_FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--target="):
			_target = arg.substr(9)
		else:
			_target = "!invalid"
	if _out.is_empty() or not _target in ["r7_fixture"]:
		print("RIDE_FAIL ERR_RIDE_CLI")
		quit(2)
		return
	var t0: int = Time.get_ticks_usec()
	var report: Dictionary = {"target": _target}
	if _target == "r7_fixture":
		report.merge(await _r7_fixture())
	report.merge({"checks": _checks, "failures": _failures, "runs": _runs, "duration_s": (Time.get_ticks_usec() - t0) / 1e6,
		"controller_sha256": FileAccess.get_sha256("res://scripts/player/bicycle_controller.gd")})
	DirAccess.make_dir_recursive_absolute(_out)
	var file := FileAccess.open(_out.path_join("region_ride_%s.json" % _target), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RIDE_SUMMARY target=%s checks=%d failures=%d completed=true" % [_target, _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _r7_fixture() -> Dictionary:
	var source: Dictionary = Source.build("fixture")
	_check(source.is_valid, "fixture route source", source.get("reason_code"))
	if not source.is_valid:
		return {}
	var deformer: Dictionary = Deformer.create(source.route, source.field)
	_check(deformer.is_valid, "deformer", deformer.get("reason_code"))
	if not deformer.is_valid:
		return {}
	var surface: RefCounted = Surface.create(source.terrain, source.field, deformer.deformer).surface
	var scene: Node3D = WorldScene.instantiate()
	var slice := Slice.new()
	var built: Dictionary = slice.build(surface, source.hydrology, source.route)
	_check(built.is_valid, "slice build", built.get("reason_code"))
	if not built.is_valid:
		return {}
	scene.attach_content(slice)
	var path: PackedVector3Array = Bot.route_polyline(source.route.get_data())
	scene.set_recovery_paths([path])
	scene.spawn_bike(path[0], path[1] - path[0])
	root.add_child(scene)
	var result := {"mesh": slice.metrics.duplicate(), "route_m": Bot.polyline_length(path)}
	for direction: String in ["forward", "reverse"]:
		var line: PackedVector3Array = path
		if direction == "reverse":
			line = path.duplicate()
			line.reverse()
		var run: Dictionary = await _ride(scene, line, direction, 60 * 420)
		_check(run.finished, "ride finished " + direction, run)
		_check(run.stalls == 0, "no stalls " + direction, run.stall_at)
		_check(not run.off_path and run.max_lateral_m <= 1.8, "stays on the road " + direction, run.max_lateral_m)
		_check(run.road_frame_share >= 0.98, "road collider under wheels " + direction, run.road_frame_share)
	scene.queue_free()
	await process_frame
	return result


## One Input ride from the start of `line`; returns the bot summary plus
## surface-layer shares and physics frame-time statistics.
func _ride(scene: Node3D, line: PackedVector3Array, label: String, max_frames: int) -> Dictionary:
	var bike: BicycleController = scene.get_bike()
	scene.spawn_bike(line[0], line[1] - line[0])
	for _settle in range(30):
		await physics_frame
	var bot: RefCounted = Bot.new().setup(line, 7.5)
	var times := PackedFloat64Array()
	var road_frames: int = 0
	var surfaces := {"GRAVEL": 0, "GRASS": 0, "ROUGH_GRAVEL": 0}
	var last: int = Time.get_ticks_usec()
	for frame in range(max_frames):
		await physics_frame
		var now: int = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		bot.step(bike)
		var collider: Object = bike.front_ray.get_collider() if bike.front_ray.is_colliding() else null
		if collider is CollisionObject3D and (collider.collision_layer & 2) != 0:
			road_frames += 1
		surfaces[BicycleController.SurfaceType.keys()[bike.current_surface]] += 1
		if bot.stats.finished or bot.stats.off_path or bike.global_position.y < -100.0:
			break
	bot.release_inputs()
	var summary: Dictionary = bot.summary()
	times.sort()
	summary.merge({"direction": label, "road_frame_share": float(road_frames) / maxi(bot.stats.frames, 1), "surface_frames": surfaces,
		"frame_ms_p50": times[times.size() / 2], "frame_ms_p99": times[int(times.size() * 0.99)], "frame_ms_max": times[times.size() - 1],
		"seconds": bot.stats.frames / 60.0})
	_runs.append(summary)
	print("RIDE_RUN ", JSON.stringify(summary))
	return summary
