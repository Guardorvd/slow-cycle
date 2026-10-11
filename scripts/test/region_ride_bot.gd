class_name RegionRideBot
extends RefCounted

## PR1 Input-only rider for the existing BicycleController. Drives through
## Input actions (pedal, brake, steer, sprint taps) and observes public
## telemetry; it never writes controller state. Pure pursuit on a world
## polyline; target speed from curvature (comfortable lateral load and the
## controller's own steering limit), class design speed and a braking pass.
## Statistics: progress, lateral error, contact, stalls, taps, brake share.

const WHEELBASE: float = 1.15
const LATERAL_COMFORT_MS2: float = 2.6
const BRAKE_COMFORT_MS2: float = 2.2
const STALL_SPEED_MS: float = 0.3
const STALL_SECONDS: float = 2.5

var points := PackedVector3Array()
var distances := PackedFloat64Array()
var v_plan := PackedFloat64Array()
var grade := PackedFloat64Array()
var total_m: float = 0.0
var index: int = 0
var s_now: float = 0.0
var assist_speed_ms: float = 2.0
var tap_period_frames: int = 36
var stats: Dictionary = {}
var _frame: int = 0
var _stall_frames: int = 0
var _tapping: bool = false
var _last_tap: int = -1000


## `speed_cap` (m/s per point, optional) caps the plan, e.g. class design speed.
func setup(path: PackedVector3Array, cruise_ms: float = 7.0, speed_cap: PackedFloat64Array = PackedFloat64Array()) -> RefCounted:
	var bot := self
	bot.points = path
	bot.distances.append(0.0)
	for i in range(1, path.size()):
		bot.distances.append(bot.distances[i - 1] + Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length())
	bot.total_m = bot.distances[bot.distances.size() - 1]
	var n: int = path.size()
	bot.v_plan.resize(n)
	bot.grade.resize(n)
	for i in range(n):
		var a: int = bot._at_distance(bot.distances[i] - 4.0)
		var b: int = bot._at_distance(bot.distances[i] + 4.0)
		var c: int = i
		var curvature: float = 0.0
		if a != c and b != c:
			curvature = _curvature(path[a], path[c], path[b])
		var radius: float = 1.0 / maxf(absf(curvature), 1e-6)
		var v: float = minf(cruise_ms, sqrt(LATERAL_COMFORT_MS2 * radius))
		v = minf(v, _max_speed_for_radius(radius * 0.8))
		if not speed_cap.is_empty():
			v = minf(v, speed_cap[i])
		bot.v_plan[i] = maxf(v, 1.5)
		var run: float = bot.distances[b] - bot.distances[a]
		bot.grade[i] = (path[b].y - path[a].y) / run if run > 0.1 else 0.0
	# Backward braking pass.
	for i in range(n - 2, -1, -1):
		var ds: float = bot.distances[i + 1] - bot.distances[i]
		bot.v_plan[i] = minf(bot.v_plan[i], sqrt(bot.v_plan[i + 1] * bot.v_plan[i + 1] + 2.0 * BRAKE_COMFORT_MS2 * ds))
	bot.stats = {"frames": 0, "ungrounded_frames": 0, "partial_contact_frames": 0, "max_lateral_m": 0.0, "lateral_sum": 0.0, "stalls": 0, "stall_at": [],
		"tap_frames": 0, "brake_frames": 0, "min_speed_climb_ms": INF, "max_speed_ms": 0.0, "distance_m": 0.0, "finished": false, "off_path": false,
		"max_height_jump_m": 0.0}
	return self


static func _curvature(a: Vector3, b: Vector3, c: Vector3) -> float:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z)
	var r := Vector2(c.x, c.z)
	var area: float = (q - p).cross(r - p)
	var denominator: float = (q - p).length() * (r - q).length() * (r - p).length()
	return 2.0 * area / denominator if denominator > 1e-9 else 0.0


## Inverse of the controller's speed-dependent steering limit (public
## constants mirrored from its exported defaults): highest speed whose full
## lock still turns on `radius`.
static func _max_speed_for_radius(radius: float) -> float:
	var v: float = 12.5
	while v > 1.0:
		var norm: float = clampf((v - 0.83) / 9.5, 0.0, 1.0)
		var steer: float = lerpf(0.50, 0.045, norm)
		var r_min: float = maxf(WHEELBASE / tan(steer), v / 1.8)
		if r_min <= radius:
			return v
		v -= 0.25
	return 1.0


func _at_distance(s: float) -> int:
	s = clampf(s, 0.0, total_m)
	var i: int = distances.bsearch(s)
	return clampi(i, 0, points.size() - 1)


## Nearest segment around the previous progress index (monotone window).
func _track(position: Vector3) -> Dictionary:
	var best: float = INF
	var best_i: int = index
	var best_t: float = 0.0
	for i in range(maxi(0, index - 20), mini(points.size() - 1, index + 60)):
		var a := Vector2(points[i].x, points[i].z)
		var b := Vector2(points[i + 1].x, points[i + 1].z)
		var p := Vector2(position.x, position.z)
		var ab: Vector2 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
		var d: float = (a + ab * t).distance_to(p)
		if d < best:
			best = d
			best_i = i
			best_t = t
	index = best_i
	var a2 := Vector2(points[best_i].x, points[best_i].z)
	var b2 := Vector2(points[best_i + 1].x, points[best_i + 1].z)
	var side: float = signf((b2 - a2).cross(Vector2(position.x, position.z) - a2))
	s_now = lerpf(distances[best_i], distances[best_i + 1], best_t)
	return {"lateral": best * side, "y": lerpf(points[best_i].y, points[best_i + 1].y, best_t)}


func step(bike: BicycleController) -> void:
	_frame += 1
	var position: Vector3 = bike.global_position
	var track: Dictionary = _track(position)
	var v: float = bike.current_speed
	stats.frames += 1
	stats.distance_m = s_now
	stats.max_lateral_m = maxf(stats.max_lateral_m, absf(track.lateral))
	stats.lateral_sum += absf(track.lateral)
	stats.max_speed_ms = maxf(stats.max_speed_ms, v)
	stats.max_height_jump_m = maxf(stats.max_height_jump_m, absf(position.y - (track.y - 0.05)))
	if not bike.is_grounded:
		stats.ungrounded_frames += 1
	if not (bike.front_contact_valid and bike.rear_contact_valid):
		stats.partial_contact_frames += 1
	if absf(track.lateral) > 12.0:
		stats.off_path = true
	if s_now >= total_m - 3.0:
		stats.finished = true
		release_inputs()
		return
	# Steering: pure pursuit, converted to the controller's normalised input.
	var lookahead: float = clampf(2.6 + 0.55 * v, 3.0, 10.0)
	var target: Vector3 = points[_at_distance(s_now + lookahead)]
	var forward := Vector3(-bike.global_transform.basis.z.x, 0.0, -bike.global_transform.basis.z.z).normalized()
	var to_target := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var alpha: float = atan2(forward.cross(to_target.normalized()).y, forward.dot(to_target.normalized()))
	var kappa: float = 2.0 * sin(alpha) / maxf(to_target.length(), 1.0)
	var delta: float = atan(WHEELBASE * kappa)
	var limit: float = lerpf(bike.max_steer_angle, bike.high_speed_steer_limit, clampf((v - 0.83) / 9.5, 0.0, 1.0))
	var u: float = clampf(delta / maxf(limit, 1e-3), -1.0, 1.0)
	var stick: float = pow(absf(u), 1.0 / 1.5)
	if u > 0.01:
		Input.action_press("steer_left", stick)
		Input.action_release("steer_right")
	elif u < -0.01:
		Input.action_press("steer_right", stick)
		Input.action_release("steer_left")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")
	# Speed: plan at a short preview distance.
	var plan: float = v_plan[_at_distance(s_now + 2.0)]
	var climbing: bool = grade[_at_distance(s_now + 3.0)] > 0.02
	if climbing:
		stats.min_speed_climb_ms = minf(stats.min_speed_climb_ms, v)
	var tap := false
	if v > plan + 0.35:
		Input.action_release("pedal")
		Input.action_press("brake", clampf(0.3 + (v - plan) * 0.45, 0.08, 1.0))
		stats.brake_frames += 1
	else:
		Input.action_release("brake")
		Input.action_press("pedal", 1.0)
		tap = (plan > 6.9 and v < plan - 0.3) or (climbing and v < assist_speed_ms)
	Input.action_release("sprint_pedal")
	if tap and _frame - _last_tap >= tap_period_frames:
		Input.action_press("sprint_pedal")
		_last_tap = _frame
		stats.tap_frames += 1
	# Stall detection (Input riding cannot progress).
	if v < STALL_SPEED_MS:
		_stall_frames += 1
		if _stall_frames == int(STALL_SECONDS * 60.0):
			stats.stalls += 1
			stats.stall_at.append([snappedf(s_now, 0.1), snappedf(position.x, 0.01), snappedf(position.z, 0.01)])
	else:
		_stall_frames = 0


## World polyline of consecutive route pieces (design stations + header
## origin), seam duplicates (<= 1 mm) removed.
static func route_polyline(data: Dictionary) -> PackedVector3Array:
	var out := PackedVector3Array()
	var ox: float = data.header.origin_x_m
	var oz: float = data.header.origin_z_m
	for piece: Dictionary in data.pieces:
		var d: Dictionary = piece.design
		for k in range(d.s.size()):
			var p := Vector3(ox + d.x[k], d.y[k], oz + d.z[k])
			if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.001:
				out.append(p)
	return out


static func polyline_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for i in range(1, path.size()):
		total += path[i].distance_to(path[i - 1])
	return total


func release_inputs() -> void:
	for action: String in ["pedal", "brake", "steer_left", "steer_right", "sprint_pedal"]:
		Input.action_release(action)


func summary() -> Dictionary:
	var out: Dictionary = stats.duplicate(true)
	out["mean_lateral_m"] = stats.lateral_sum / maxi(stats.frames, 1)
	out.erase("lateral_sum")
	out["path_m"] = total_m
	if out.min_speed_climb_ms == INF:
		out.min_speed_climb_ms = -1.0
	return out
