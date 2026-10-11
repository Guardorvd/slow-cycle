extends SceneTree

## PR1 M1 — measured riding envelope of the EXISTING BicycleController.
## Real bicycle scene, registered trimesh collision (ConcavePolygonShape3D,
## same winding as FinalSurfaceTileRenderer) and Input actions only: the
## controller is never commanded internally, only observed through public
## properties. Ramps are built in code. Run headless with --fixed-fps 60.
##   --out=DIR      JSON report (required)
##   --group=G      all | climb | pitch | descent | turn | step | kink | contact
## Output: ENVELOPE_CASE lines, ENVELOPE_TABLE json, report file and
## ENVELOPE_SUMMARY checks=.. failures=.. completed=true.
const BikeScene = preload("res://scenes/player/bicycle.tscn")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")

const DT: float = 1.0 / 60.0
const LAYER_ROAD: int = 2
const LAYER_GRASS: int = 4
const LAYER_ROUGH: int = 2 | 16
const SURFACES: Dictionary = {"gravel": LAYER_ROAD, "rough": LAYER_ROUGH, "grass": LAYER_GRASS}
## Climb-speed thresholds reported by the table (m/s); the policy picks one.
const V_CLIMB_CANDIDATES: Array[float] = [1.5, 2.0, 2.5, 3.0]

var _checks: int = 0
var _failures: Array = []
var _cases: Array = []
var _group: String = "all"
var _out: String = ""
var _world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"check": label, "detail": str(detail)})
		print("ENVELOPE_FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--group="):
			_group = arg.substr(8)
		else:
			_group = "!invalid"
	if _out.is_empty() or not _group in ["all", "climb", "pitch", "descent", "turn", "step", "kink", "contact"]:
		print("ENVELOPE_FAIL ERR_ENVELOPE_CLI")
		quit(2)
		return
	_check(Engine.physics_ticks_per_second == 60, "physics at 60 Hz", Engine.physics_ticks_per_second)
	var t0: int = Time.get_ticks_usec()
	var table: Dictionary = {}
	if _group in ["all", "climb"]:
		table["climb"] = await _climb()
	if _group in ["all", "pitch"]:
		table["pitch"] = await _pitch()
	if _group in ["all", "descent"]:
		table["descent"] = await _descent()
	if _group in ["all", "turn"]:
		table["turn"] = await _turn()
	if _group in ["all", "step"]:
		table["step"] = await _steps()
	if _group in ["all", "kink"]:
		table["kink"] = await _kinks()
	if _group in ["all", "contact"]:
		table["contact"] = await _contact()
	if _group == "all":
		table["derived"] = derive_policy(table)
	var report := {"group": _group, "checks": _checks, "failures": _failures, "cases": _cases, "table": table, "duration_s": (Time.get_ticks_usec() - t0) / 1e6,
		"controller_sha256": FileAccess.get_sha256("res://scripts/player/bicycle_controller.gd"), "bicycle_scene_sha256": FileAccess.get_sha256("res://scenes/player/bicycle.tscn"),
		"test_sha256": FileAccess.get_sha256("res://scripts/test/test_ride_envelope.gd"), "engine": Engine.get_version_info()}
	print("ENVELOPE_TABLE ", JSON.stringify(table))
	DirAccess.make_dir_recursive_absolute(_out)
	var file := FileAccess.open(_out.path_join("ride_envelope_%s.json" % _group), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ENVELOPE_SUMMARY group=%s checks=%d failures=%d completed=true" % [_group, _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


## Fixed derivation rules of the measured envelope (policy v2 inputs):
##   v_climb: knee of the pedal-hold curve (speed collapses within 0.5 deg
##            below it), 2.0 m/s;
##   sustained grade per surface: steepest pedal-hold grade at >= v_climb;
##   pitch length per surface: distance on the grade above v_climb when
##            entering at cruise with relaxed sprint taps (one per 2 s);
##   descent: steepest grade where a modulated brake holds 8 m/s within 1 m/s;
##   lateral design load: median steady lateral acceleration of half-lock
##            turns that hold their target speed (no scrub collapse);
##   low-speed radius: mean half-lock radius at 2-3 m/s;
##   braking: smallest mean full-brake deceleration over the descents.
static func derive_policy(table: Dictionary) -> Dictionary:
	var v_climb: float = 2.0
	var out := {"v_climb_ms": v_climb, "sustained_grade_deg": {}, "pitch_length_m": {}}
	if table.has("climb"):
		for surface: String in SURFACES:
			out.sustained_grade_deg[surface] = table.climb.sustained_grade_deg_by_v_climb[surface][str(v_climb)]
	if table.has("pitch"):
		for row: Dictionary in table.pitch.rows:
			if row.tap_period_frames != 120:
				continue
			if not out.pitch_length_m.has(row.surface):
				out.pitch_length_m[row.surface] = {}
			out.pitch_length_m[row.surface][str(row.grade_deg)] = row.length_above_v_m[str(v_climb)]
	if table.has("descent"):
		var steepest: float = 0.0
		var decel: float = INF
		for row: Dictionary in table.descent.rows:
			if row.mode == "hold_8" and row.hold_8_max_speed_ms <= 9.0:
				steepest = maxf(steepest, row.grade_deg)
			if row.mode == "coast_brake" and is_finite(row.mean_brake_decel_ms2):
				decel = minf(decel, row.mean_brake_decel_ms2)
		out["controlled_descent_deg"] = steepest
		out["full_brake_decel_ms2"] = decel
	if table.has("turn"):
		var loads: Array = []
		var radii: Array = []
		for row: Dictionary in table.turn.rows:
			if row.steer == 0.5 and is_finite(row.mean_speed_ms) and row.mean_speed_ms >= row.target_ms - 0.3:
				loads.append(row.lateral_accel_ms2)
			if row.steer == 0.5 and row.target_ms <= 3.0 and is_finite(row.radius_m):
				radii.append(row.radius_m)
		loads.sort()
		out["lateral_design_ms2"] = loads[loads.size() / 2] if not loads.is_empty() else NAN
		var total: float = 0.0
		for r: float in radii:
			total += r
		out["low_speed_radius_m"] = total / radii.size() if not radii.is_empty() else NAN
	return out


# ---------------------------------------------------------------------------
# Course construction: centreline along -Z (bike forward), lateral +X.
# ---------------------------------------------------------------------------

## Height profile from grade segments [[length_m, grade_ratio], ...] with an
## optional vertical-curve rate (deg/m of grade change; 0 = abrupt kink).
static func profile(segments: Array, step: float, change_deg_per_m: float, start_y: float = 0.0) -> PackedFloat64Array:
	var grades := PackedFloat64Array()
	for segment: Array in segments:
		for i in range(int(round(segment[0] / step))):
			grades.append(segment[1])
	if change_deg_per_m > 0.0:
		# Limit the per-sample change of grade angle (symmetric two-pass ramp).
		var limit: float = deg_to_rad(change_deg_per_m) * step
		var angles := PackedFloat64Array()
		for g: float in grades:
			angles.append(atan(g))
		for _pass in range(2):
			for i in range(1, angles.size()):
				angles[i] = clampf(angles[i], angles[i - 1] - limit, angles[i - 1] + limit)
			for i in range(angles.size() - 2, -1, -1):
				angles[i] = clampf(angles[i], angles[i + 1] - limit, angles[i + 1] + limit)
		for i in range(angles.size()):
			grades[i] = tan(angles[i])
	var heights := PackedFloat64Array([start_y])
	for g: float in grades:
		heights.append(heights[heights.size() - 1] + g * step)
	return heights


func _strip(heights: PackedFloat64Array, step: float, half_width: float, layer: int) -> StaticBody3D:
	var faces := PackedVector3Array()
	var lateral: Array[float] = [-half_width, -half_width / 2.0, 0.0, half_width / 2.0, half_width]
	for i in range(heights.size() - 1):
		var z0: float = -i * step
		var z1: float = -(i + 1) * step
		var y0: float = heights[i]
		var y1: float = heights[i + 1]
		for j in range(lateral.size() - 1):
			var a := Vector3(lateral[j], y0, z0)
			var b := Vector3(lateral[j + 1], y0, z0)
			var c := Vector3(lateral[j], y1, z1)
			var d := Vector3(lateral[j + 1], y1, z1)
			_tri(faces, a, b, c)
			_tri(faces, b, d, c)
	return _body(faces, layer)


## Renderer convention: (c - a) x (b - a) points up for ground faces.
static func _tri(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal: Vector3 = (c - a).cross(b - a)
	if normal.y < 0.0:
		faces.append_array([a, c, b])
	else:
		faces.append_array([a, b, c])


func _body(faces: PackedVector3Array, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	return body


func _begin(body: StaticBody3D, spawn: Transform3D) -> BicycleController:
	_world = Node3D.new()
	root.add_child(_world)
	_world.add_child(body)
	var bike: BicycleController = BikeScene.instantiate()
	bike.transform = spawn
	_world.add_child(bike)
	return bike


func _end() -> void:
	for action: String in ["pedal", "brake", "steer_left", "steer_right", "sprint_pedal"]:
		Input.action_release(action)
	_world.queue_free()
	await process_frame
	await process_frame


## Spawn resting above the course at station s (heights indexed by step).
static func _spawn(heights: PackedFloat64Array, step: float, s: float) -> Transform3D:
	var i: int = int(s / step)
	return Transform3D(Basis.IDENTITY, Vector3(0.0, heights[i] + 0.05, -s))


static func _ground(heights: PackedFloat64Array, step: float, s: float) -> float:
	var q: float = clampf(s / step, 0.0, heights.size() - 1.001)
	var i: int = int(q)
	return lerpf(heights[i], heights[i + 1], q - i)


## Runs Input-driven frames. `driver(bike, frame, state) -> bool` presses
## actions and returns false to stop. Returns per-frame samples (decimated).
func _drive(bike: BicycleController, max_frames: int, driver: Callable, state: Dictionary) -> Array:
	var samples: Array = []
	for _settle in range(20):
		await physics_frame
	for frame in range(max_frames):
		await physics_frame
		if not driver.call(bike, frame, state):
			break
		if bike.global_position.y < -200.0 or not bike.global_position.is_finite():
			state["fell"] = true
			break
		samples.append([frame * DT, -bike.global_position.z, bike.global_position.y, bike.current_speed, bike.is_grounded, bike.front_contact_valid and bike.rear_contact_valid,
			bike.global_position.x, bike.global_transform.basis.z, bike.velocity.y])
	return samples


static func _tap(frame: int, period_frames: int) -> void:
	if period_frames <= 0:
		return
	if frame % period_frames == 0:
		Input.action_press("sprint_pedal")
	elif frame % period_frames == 1:
		Input.action_release("sprint_pedal")


func _record(name: String, data: Dictionary) -> void:
	data["case"] = name
	_cases.append(data)
	print("ENVELOPE_CASE ", JSON.stringify(data))


static func _mean_speed(samples: Array, s0: float, s1: float) -> float:
	var total: float = 0.0
	var count: int = 0
	for row: Array in samples:
		if row[1] >= s0 and row[1] <= s1:
			total += row[3]
			count += 1
	return total / count if count > 0 else NAN


# ---------------------------------------------------------------------------
# A. Sustained climb (pedal hold) and steady climb with sprint taps.
# ---------------------------------------------------------------------------

func _climb() -> Dictionary:
	var out: Dictionary = {}
	var grades: Array[float] = [0.0, 2.0, 4.0, 5.0, 5.5, 6.0, 6.5, 7.0, 8.0, 10.0, 12.0, 15.0]
	for surface: String in SURFACES:
		var rows: Array = []
		for deg: float in grades:
			for taps: int in [0, 90, 60]:
				if surface != "gravel" and taps != 0:
					continue
				if taps != 0 and deg < 6.0:
					continue
				var step: float = 0.5
				var heights: PackedFloat64Array = profile([[20.0, 0.0], [420.0, tan(deg_to_rad(deg))], [20.0, 0.0]], step, 1.2)
				var bike: BicycleController = _begin(_strip(heights, step, 4.0, SURFACES[surface]), _spawn(heights, step, 5.0))
				var state := {"fell": false}
				var samples: Array = await _drive(bike, 60 * 420, func(b: BicycleController, f: int, st: Dictionary) -> bool:
					Input.action_press("pedal", 1.0)
					_tap(f, taps)
					return -b.global_position.z < 400.0, state)
				var last: Array = samples[samples.size() - 1]
				var steady: float = _mean_speed(samples, 250.0, 400.0)
				var stall: bool = last[1] < 250.0
				var lost: int = samples.filter(func(r: Array) -> bool: return not r[4]).size()
				var row := {"surface": surface, "grade_deg": deg, "tap_period_frames": taps, "steady_speed_ms": 0.0 if stall else steady, "reached_m": last[1], "stalled": stall,
					"frames": samples.size(), "ungrounded_frames": lost, "fell": state.fell}
				rows.append(row)
				_record("climb", row)
				_check(not state.fell, "climb no fall %s %.1f %d" % [surface, deg, taps])
				await _end()
		out[surface] = rows
		# Steady speed must not increase with grade (pedal hold, same surface).
		var hold: Array = rows.filter(func(r: Dictionary) -> bool: return r.tap_period_frames == 0)
		var monotone := true
		for k in range(1, hold.size()):
			monotone = monotone and hold[k].steady_speed_ms <= hold[k - 1].steady_speed_ms + 0.02
		_check(monotone, "climb steady speed monotone in grade " + surface, hold.map(func(r: Dictionary) -> float: return r.steady_speed_ms))
	# Derived: steepest pedal-hold grade sustaining each candidate climb speed
	# (linear interpolation of the measured steady speeds; surfaces separate).
	var derived: Dictionary = {}
	for surface: String in SURFACES:
		var hold: Array = out[surface].filter(func(r: Dictionary) -> bool: return r.tap_period_frames == 0)
		var by_speed: Dictionary = {}
		for v: float in V_CLIMB_CANDIDATES:
			by_speed[str(v)] = _grade_for_speed(hold, v)
		derived[surface] = by_speed
	out["sustained_grade_deg_by_v_climb"] = derived
	return out


static func _grade_for_speed(rows: Array, v: float) -> float:
	for k in range(1, rows.size()):
		var a: Dictionary = rows[k - 1]
		var b: Dictionary = rows[k]
		if a.steady_speed_ms >= v and b.steady_speed_ms < v:
			var t: float = (a.steady_speed_ms - v) / maxf(a.steady_speed_ms - b.steady_speed_ms, 1e-9)
			return lerpf(a.grade_deg, b.grade_deg, t)
	return rows[rows.size() - 1].grade_deg if rows[rows.size() - 1].steady_speed_ms >= v else rows[0].grade_deg


# ---------------------------------------------------------------------------
# P. Pitch: enter at cruise (pedal-hold run-up), keep pedalling with relaxed
# sprint taps, distance on the grade until the speed falls below v_climb.
# ---------------------------------------------------------------------------

func _pitch() -> Dictionary:
	var rows: Array = []
	for surface: String in ["gravel", "rough"]:
		for deg: float in [6.0, 7.0, 8.0, 9.0, 10.0, 12.0, 15.0]:
			for taps: int in [0, 120, 90]:
				if surface == "rough" and taps == 90:
					continue
				rows.append(await _pitch_case(surface, deg, taps))
	return {"rows": rows}


func _pitch_case(surface: String, deg: float, taps: int) -> Dictionary:
	var step: float = 0.5
	var heights: PackedFloat64Array = profile([[160.0, 0.0], [320.0, tan(deg_to_rad(deg))], [20.0, 0.0]], step, 1.2)
	var bike: BicycleController = _begin(_strip(heights, step, 4.0, SURFACES[surface]), _spawn(heights, step, 5.0))
	var state := {"fell": false, "entry": 0.0}
	var samples: Array = await _drive(bike, 60 * 300, func(b: BicycleController, f: int, st: Dictionary) -> bool:
		Input.action_press("pedal", 1.0)
		var s: float = -b.global_position.z
		if s >= 160.0:
			if st.entry == 0.0:
				st.entry = b.current_speed
			_tap(f, taps)
		return s < 470.0 and not (s > 165.0 and b.current_speed < 1.0), state)
	var lengths: Dictionary = {}
	for v: float in V_CLIMB_CANDIDATES:
		var reached: float = 320.0
		for row: Array in samples:
			if row[1] > 162.0 and row[3] < v:
				reached = minf(reached, row[1] - 160.0)
				break
		lengths[str(v)] = reached
	var row := {"surface": surface, "grade_deg": deg, "tap_period_frames": taps, "entry_speed_ms": state.entry, "length_above_v_m": lengths, "fell": state.fell}
	_record("pitch", row)
	_check(not state.fell, "pitch no fall %s %.1f %d" % [surface, deg, taps])
	_check(state.entry >= 6.5, "pitch entry at cruise %s %.1f %d" % [surface, deg, taps], state.entry)
	await _end()
	return row


# ---------------------------------------------------------------------------
# C. Descent: coasting terminal speed, full-brake deceleration, and a speed
# hold with modulated brake (what a rider/bot needs on a long descent).
# ---------------------------------------------------------------------------

func _descent() -> Dictionary:
	var rows: Array = []
	for deg: float in [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 15.0]:
		for mode: String in ["coast_brake", "hold_8"]:
			var step: float = 0.5
			var heights: PackedFloat64Array = profile([[40.0, 0.0], [560.0, -tan(deg_to_rad(deg))], [100.0, 0.0]], step, 1.2, 200.0)
			var bike: BicycleController = _begin(_strip(heights, step, 4.0, LAYER_ROAD), _spawn(heights, step, 5.0))
			var state := {"fell": false, "brake_t0": -1.0, "brake_v0": 0.0, "brake_s0": 0.0, "stop_s": -1.0, "stop_t": -1.0, "max_hold": 0.0, "terminal": 0.0, "t": 0.0}
			var samples: Array = await _drive(bike, 60 * 240, func(b: BicycleController, f: int, st: Dictionary) -> bool:
				var s: float = -b.global_position.z
				st.t = f * DT
				if s < 40.0:
					Input.action_press("pedal", 1.0)
					return true
				Input.action_release("pedal")
				if mode == "coast_brake":
					if s < 420.0:
						st.terminal = maxf(st.terminal, b.current_speed)
						return true
					if st.brake_t0 < 0.0:
						st.brake_t0 = st.t
						st.brake_v0 = b.current_speed
						st.brake_s0 = s
					Input.action_press("brake", 1.0)
					if b.current_speed <= 0.05:
						st.stop_s = s - st.brake_s0
						st.stop_t = st.t - st.brake_t0
						return false
					return s < 690.0
				# Hold 8 m/s with a proportional brake (modulated input).
				var error: float = b.current_speed - 8.0
				if error > 0.0:
					Input.action_press("brake", clampf(0.25 + error * 0.6, 0.06, 1.0))
				else:
					Input.action_release("brake")
				if s > 120.0 and s < 560.0:
					st.max_hold = maxf(st.max_hold, b.current_speed)
				return s < 600.0, state)
			var row := {"grade_deg": deg, "mode": mode, "fell": state.fell}
			if mode == "coast_brake":
				row.merge({"coast_terminal_ms": state.terminal, "brake_from_ms": state.brake_v0, "stop_distance_m": state.stop_s, "stop_time_s": state.stop_t,
					"mean_brake_decel_ms2": state.brake_v0 / state.stop_t if state.stop_t > 0.0 else NAN})
				_check(state.stop_s > 0.0, "descent brake stops %.1f" % deg, state)
			else:
				row["hold_8_max_speed_ms"] = state.max_hold
				_check(state.max_hold < 9.0, "descent speed hold %.1f" % deg, state.max_hold)
			rows.append(row)
			_record("descent", row)
			_check(not state.fell, "descent no fall %.1f %s" % [deg, mode])
			await _end()
	return {"rows": rows}


# ---------------------------------------------------------------------------
# D. Turning: steady full-lock radius by speed on a flat pad.
# ---------------------------------------------------------------------------

func _turn() -> Dictionary:
	var rows: Array = []
	var faces := PackedVector3Array()
	for j in range(-50, 50):
		for i in range(-50, 50):
			var a := Vector3(i * 8.0, 0.0, j * 8.0)
			_tri(faces, a, a + Vector3(8, 0, 0), a + Vector3(0, 0, 8))
			_tri(faces, a + Vector3(8, 0, 0), a + Vector3(8, 0, 8), a + Vector3(0, 0, 8))
	for target: float in [2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]:
		for amount: float in [1.0, 0.5]:
			var bike: BicycleController = _begin(_body(faces, LAYER_ROAD), Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 340.0)))
			var state := {"fell": false, "turn_frame": -1, "headings": [], "speeds": [], "lat": []}
			await _drive(bike, 60 * 90, func(b: BicycleController, f: int, st: Dictionary) -> bool:
				var v: float = b.current_speed
				# Speed control: pedal below cruise, sprint taps above it, brake over target.
				if v < target - 0.15:
					Input.action_press("pedal", 1.0)
					Input.action_release("brake")
					if target > 6.8:
						_tap(f, 30)
				elif v > target + 0.3:
					Input.action_release("pedal")
					Input.action_press("brake", 0.3)
				else:
					Input.action_press("pedal", 1.0)
					Input.action_release("brake")
					if target > 6.8:
						_tap(f, 45)
				if st.turn_frame < 0 and absf(v - target) < 0.25 and -b.global_position.z < 300.0:
					st.turn_frame = f
				if st.turn_frame >= 0:
					Input.action_press("steer_left", amount)
					if f - st.turn_frame > 90:
						var forward: Vector3 = -b.global_transform.basis.z
						st.headings.append(atan2(forward.x, forward.z))
						st.speeds.append(v)
						st.lat.append(b.lateral_acceleration)
					return f - st.turn_frame < 90 + 240
				return f < 60 * 80 and b.global_position.z > -380.0, state)
			var radius: float = NAN
			var speed: float = NAN
			if state.headings.size() > 10:
				var total: float = 0.0
				for k in range(1, state.headings.size()):
					total += absf(wrapf(state.headings[k] - state.headings[k - 1], -PI, PI))
				var rate: float = total / ((state.headings.size() - 1) * DT)
				speed = 0.0
				for v: float in state.speeds:
					speed += v
				speed /= state.speeds.size()
				radius = speed / rate if rate > 1e-6 else INF
			var row := {"target_ms": target, "steer": amount, "mean_speed_ms": speed, "radius_m": radius, "lateral_accel_ms2": speed * speed / radius if is_finite(radius) else NAN,
				"turned": state.turn_frame >= 0, "fell": state.fell}
			rows.append(row)
			_record("turn", row)
			_check(state.turn_frame >= 0 and is_finite(radius), "turn measured %.1f %.1f" % [target, amount], row)
			await _end()
	return {"rows": rows}


# ---------------------------------------------------------------------------
# E. Height steps (mesh tolerance) at riding speed, up and down.
# ---------------------------------------------------------------------------

func _steps() -> Dictionary:
	var rows: Array = []
	for h: float in [0.005, 0.01, 0.02, 0.05, 0.10]:
		for sign: float in [1.0, -1.0]:
			var step: float = 0.5
			var heights: PackedFloat64Array = profile([[120.0, 0.0]], step, 0.0)
			var at: int = int(80.0 / step)
			var stepped := PackedFloat64Array(heights)
			for i in range(at, stepped.size()):
				stepped[i] += sign * h
			var body: StaticBody3D = _strip_steps(heights, stepped, at, step, 4.0, LAYER_ROAD)
			var bike: BicycleController = _begin(body, _spawn(heights, step, 5.0))
			var state := {"fell": false}
			var samples: Array = await _drive(bike, 60 * 40, func(b: BicycleController, f: int, st: Dictionary) -> bool:
				Input.action_press("pedal", 1.0)
				return -b.global_position.z < 110.0, state)
			var v_before: float = _mean_speed(samples, 70.0, 79.0)
			var v_after: float = _mean_speed(samples, 81.0, 90.0)
			var lost: int = samples.filter(func(r: Array) -> bool: return r[1] > 78.0 and r[1] < 84.0 and not r[5]).size()
			var peak_vy: float = 0.0
			for r: Array in samples:
				if r[1] > 78.0 and r[1] < 84.0:
					peak_vy = maxf(peak_vy, absf(r[8]))
			var passed: bool = samples[samples.size() - 1][1] >= 100.0
			var row := {"height_m": h * sign, "speed_before_ms": v_before, "speed_after_ms": v_after, "partial_contact_frames": lost, "peak_vertical_speed_ms": peak_vy, "passed": passed, "fell": state.fell}
			rows.append(row)
			_record("step", row)
			_check(not state.fell, "step no fall %.3f" % (h * sign))
			await _end()
	return {"rows": rows}


## Strip with an exact vertical discontinuity at index `at`: quads before the
## step use `heights`, quads after use `stepped`, joined by a vertical face.
func _strip_steps(heights: PackedFloat64Array, stepped: PackedFloat64Array, at: int, step: float, half_width: float, layer: int) -> StaticBody3D:
	var faces := PackedVector3Array()
	var lateral: Array[float] = [-half_width, 0.0, half_width]
	for i in range(heights.size() - 1):
		var src: PackedFloat64Array = heights if i < at else stepped
		var z0: float = -i * step
		var z1: float = -(i + 1) * step
		for j in range(lateral.size() - 1):
			var a := Vector3(lateral[j], src[i], z0)
			var b := Vector3(lateral[j + 1], src[i], z0)
			var c := Vector3(lateral[j], src[i + 1], z1)
			var d := Vector3(lateral[j + 1], src[i + 1], z1)
			_tri(faces, a, b, c)
			_tri(faces, b, d, c)
	var z: float = -at * step
	var lo: float = minf(heights[at], stepped[at])
	var hi: float = maxf(heights[at], stepped[at])
	for j in range(lateral.size() - 1):
		faces.append_array([Vector3(lateral[j], lo, z), Vector3(lateral[j + 1], lo, z), Vector3(lateral[j], hi, z)])
		faces.append_array([Vector3(lateral[j + 1], lo, z), Vector3(lateral[j + 1], hi, z), Vector3(lateral[j], hi, z)])
	var body: StaticBody3D = _body(faces, layer)
	(body.get_child(0).shape as ConcavePolygonShape3D).backface_collision = true
	return body


# ---------------------------------------------------------------------------
# F. Abrupt grade kinks (no vertical curve): sags and crests at speed.
# ---------------------------------------------------------------------------

func _kinks() -> Dictionary:
	var rows: Array = []
	for deg: float in [2.0, 4.0, 6.0, 8.0, 10.0]:
		for kind: String in ["sag", "crest", "sag_curve", "crest_curve"]:
			var step: float = 0.5
			var g: float = tan(deg_to_rad(deg))
			var segments: Array = [[120.0, 0.0], [80.0, g if kind.begins_with("sag") else -g], [60.0, 0.0]]
			var heights: PackedFloat64Array = profile(segments, step, 1.2 if kind.ends_with("curve") else 0.0, 100.0)
			var bike: BicycleController = _begin(_strip(heights, step, 4.0, LAYER_ROAD), _spawn(heights, step, 5.0))
			var state := {"fell": false}
			var samples: Array = await _drive(bike, 60 * 60, func(b: BicycleController, f: int, st: Dictionary) -> bool:
				Input.action_press("pedal", 1.0)
				if b.current_speed < 9.0:
					_tap(f, 40)
				return -b.global_position.z < 250.0, state)
			var airborne: int = 0
			var partial: int = 0
			var entry: float = _mean_speed(samples, 110.0, 119.0)
			var max_dev: float = 0.0
			for r: Array in samples:
				if r[1] > 115.0 and r[1] < 135.0:
					airborne += 0 if r[4] else 1
					partial += 0 if r[5] else 1
				if r[1] > 100.0 and r[1] < 210.0:
					max_dev = maxf(max_dev, absf(r[2] - (_ground(heights, step, r[1]) - 0.05)))
			var row := {"grade_change_deg": deg, "kind": kind, "entry_speed_ms": entry, "airborne_frames": airborne, "partial_contact_frames": partial, "max_height_deviation_m": max_dev, "fell": state.fell}
			rows.append(row)
			_record("kink", row)
			_check(not state.fell, "kink no fall %.1f %s" % [deg, kind])
			await _end()
	return {"rows": rows}


# ---------------------------------------------------------------------------
# G. Trimesh internal edges: fine 0.5 m triangles vs one coarse plane, on the
# flat and across a 5 deg cross slope; diagonal heading.
# ---------------------------------------------------------------------------

func _contact() -> Dictionary:
	var rows: Array = []
	for cell: float in [0.5, 8.0]:
		for cross_deg: float in [0.0, 5.0]:
			var faces := PackedVector3Array()
			var slope: float = tan(deg_to_rad(cross_deg))
			var n: int = int(240.0 / cell)
			for j in range(n):
				for i in range(int(60.0 / cell)):
					var x: float = -30.0 + i * cell
					var z: float = 20.0 - (j + 1) * cell
					var a := Vector3(x, x * slope, z + cell)
					var b := Vector3(x + cell, (x + cell) * slope, z + cell)
					var c := Vector3(x, x * slope, z)
					var d := Vector3(x + cell, (x + cell) * slope, z)
					_tri(faces, a, b, c)
					_tri(faces, b, d, c)
			var spawn := Transform3D(Basis(Vector3.UP, deg_to_rad(5.0)), Vector3(0.0, 0.05, 15.0))
			var bike: BicycleController = _begin(_body(faces, LAYER_ROAD), spawn)
			var state := {"fell": false}
			var samples: Array = await _drive(bike, 60 * 50, func(b: BicycleController, f: int, st: Dictionary) -> bool:
				Input.action_press("pedal", 1.0)
				return -b.global_position.z < 200.0 and absf(b.global_position.x) < 28.0, state)
			var vy_sq: float = 0.0
			var count: int = 0
			var gap_max: float = 0.0
			for r: Array in samples:
				if r[1] > 40.0:
					var ground: float = r[6] * slope
					gap_max = maxf(gap_max, absf(r[2] - (ground - 0.05)))
					vy_sq += r[8] * r[8]
					count += 1
			var row := {"cell_m": cell, "cross_slope_deg": cross_deg, "speed_at_end_ms": samples[samples.size() - 1][3], "distance_m": samples[samples.size() - 1][1],
				"vertical_speed_rms": sqrt(vy_sq / maxi(count, 1)), "max_height_deviation_m": gap_max, "fell": state.fell}
			rows.append(row)
			_record("contact", row)
			_check(not state.fell, "contact no fall %.1f %.1f" % [cell, cross_deg])
			await _end()
	return {"rows": rows}
