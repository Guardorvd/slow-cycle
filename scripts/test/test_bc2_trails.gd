extends SceneTree

## BC2 procedural trails, FAST group (headless, seconds; D3 Fast Cycle).
##   --group=domain   TrailNetworkPlanner + TrailRealization (production code)
##                    on a small analytic world: a road loop around a meadow
##                    whose two ends are close - the planner must find the
##                    shortcut, join both nodes, keep clear of the creek and be
##                    deterministic; a creek across the whole meadow must leave
##                    no trail (refusal with reasons, nothing published); the
##                    raster query, heap and line helpers keep their contracts.
##                    TECHNICAL: on a terrace scarp a descent is proposed - one-
##                    way, within its limits, with linked turns, both ends on
##                    the road and the road as the way back; a climbing or
##                    unknown-class line is refused; the 24.5 % fall line is
##                    TECHNICAL, not SINGLETRACK.
## The analytic surface and water are stand-ins for FinalSurface and
## HydrologyField (the external inputs of the planner, not the planning
## math); the region products are exercised by the cached bake and the
## Director's playtest, not here.
## Output: BC2_CHECK lines for failures, DIR/bc2_trails_<group>.json and
## BC2_SUMMARY group=.. checks=.. failures=.. completed=true.
const Planner = preload("res://scripts/world/region/trail_network_planner.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const SIZE_M: float = 1024.0
const ROAD_HALF_M: float = 3.0
## Scarp world: upper terrace road at z 350, lower at z 620, the scarp
## between (cosine profile, steepest 25 pi / 320 = 0.245).
const SCARP_Z := Vector2(420.0, 580.0)
const SCARP_DROP_M: float = 25.0

var _checks: int = 0
var _failures: Array = []


class AnalyticSurface:
	extends RefCounted
	var road: PackedVector2Array
	## false: gentle hills; true: a terrace scarp (SCARP_DROP_M over SCARP_Z).
	var scarp: bool = false

	func get_bounds_m() -> Dictionary:
		return {"min_x": 0.0, "min_z": 0.0, "max_x": SIZE_M, "max_z": SIZE_M}

	func height(x: float, z: float) -> float:
		if scarp:
			var u: float = clampf((z - SCARP_Z.x) / (SCARP_Z.y - SCARP_Z.x), 0.0, 1.0)
			return 100.0 - SCARP_DROP_M * 0.5 * (1.0 - cos(PI * u)) + 0.5 * sin(x / 40.0)
		return 100.0 + 6.0 * sin(x / 90.0) * cos(z / 110.0) + 0.01 * z

	func sample_height(x: float, z: float) -> Dictionary:
		if x < 0.0 or z < 0.0 or x > SIZE_M or z > SIZE_M:
			return {"is_valid": false, "height_m": NAN, "reason_code": "ERR_OUTSIDE"}
		return {"is_valid": true, "height_m": height(x, z), "reason_code": "", "kind": "TERRAIN"}

	func sample_gradient(x: float, z: float) -> Dictionary:
		var e: float = 0.25
		return {"is_valid": true, "gradient": Vector2(height(x + e, z) - height(x - e, z), height(x, z + e) - height(x, z - e)) / (2.0 * e), "reason_code": ""}

	func road_owner(x: float, z: float) -> String:
		var p := Vector2(x, z)
		for k in range(road.size() - 1):
			if Geometry2D.get_closest_point_to_segment(p, road[k], road[k + 1]).distance_to(p) <= ROAD_HALF_M:
				return "edge:0"
		return ""

	func with_trails(_trails: Array) -> RefCounted:
		return self

	func with_published(_tiles: Array) -> RefCounted:
		return self


class AnalyticWater:
	extends RefCounted
	## Creek: |x - x0| < half for z in [z0, z1].
	var creek: Rect2

	func sample_water(x: float, z: float) -> Dictionary:
		return {"is_valid": true, "is_water": creek.has_point(Vector2(x, z))}


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"label": label, "detail": str(detail)})
		print("BC2_CHECK FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	var out: String = ""
	var group: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--group="):
			group = arg.substr(8)
	if out.is_empty() or group != "domain":
		push_error("BC2_FAIL usage: --group=domain --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var t0: int = Time.get_ticks_usec()
	var report: Dictionary = _domain()
	report["seconds"] = (Time.get_ticks_usec() - t0) / 1e6
	report["checks"] = _checks
	report["failures"] = _failures
	var file := FileAccess.open(out.path_join("bc2_trails_%s.json" % group), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BC2_SUMMARY group=%s checks=%d failures=%d seconds=%.1f completed=true" % [group, _checks, _failures.size(), report.seconds])
	quit(0 if _failures.is_empty() else 1)


## A road from node 0 (300, 200) south round a loop to node 1 (700, 200):
## 300 m apart in a straight line, ~1.3 km by road. With scarp: a road from
## node 0 (200, 350) east along the upper terrace, down a ramp at x 800 and
## back west below the scarp to node 1 (200, 620).
func _world(creek: Rect2, scarp: bool = false) -> Dictionary:
	var surface := AnalyticSurface.new()
	surface.scarp = scarp
	var corners: Array[Vector2] = [Vector2(300, 200), Vector2(300, 700), Vector2(700, 700), Vector2(700, 200)]
	if scarp:
		corners = [Vector2(200, 350), Vector2(800, 350), Vector2(800, 620), Vector2(200, 620)]
	var d := {"s": PackedFloat64Array(), "x": PackedFloat64Array(), "y": PackedFloat64Array(), "z": PackedFloat64Array(), "tx": PackedFloat64Array(), "tz": PackedFloat64Array(),
		"width": PackedFloat64Array()}
	var road := PackedVector2Array()
	var s: float = 0.0
	for c in range(corners.size() - 1):
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[c + 1]
		var steps: int = int(a.distance_to(b) / 2.0)
		for k in range(steps if c < corners.size() - 2 else steps + 1):
			var p: Vector2 = a.lerp(b, float(k) / steps)
			if not road.is_empty():
				s += p.distance_to(road[road.size() - 1])
			road.append(p)
			d.s.append(s)
			d.x.append(p.x)
			d.z.append(p.y)
			d.y.append(surface.height(p.x, p.y))
			var t: Vector2 = (b - a).normalized()
			d.tx.append(t.x)
			d.tz.append(t.y)
			d.width.append(2.0 * ROAD_HALF_M)
	surface.road = road
	var water := AnalyticWater.new()
	water.creek = creek
	var network := {"nodes": [{"id": 0, "x_m": corners[0].x, "z_m": corners[0].y, "kind": "JUNCTION"}, {"id": 1, "x_m": corners[3].x, "z_m": corners[3].y, "kind": "JUNCTION"}],
		"edges": [{"edge_id": 0, "a": 0, "b": 1, "piece_id": "edge:0", "length_m": s}],
		"pieces": [{"id": "edge:0", "design": d, "info": {"route_class": 1}}], "movements": [], "crossings": []}
	var cell: float = TrailPolicy.GROUND_CELL_M
	var n: int = int(SIZE_M / cell) + 1
	var heights := PackedFloat32Array()
	for j in range(n):
		for i in range(n):
			heights.append(surface.height(i * cell, j * cell))
	return {"seed": 4242, "region": Vector2i(0, 0), "network": network, "surface": surface, "field": water, "slots": [],
		"ground": {"cell_m": cell, "nx": n, "nz": n, "heights": heights}}


func _domain() -> Dictionary:
	var config: Dictionary = TrailPolicy.parse({"schema": TrailPolicy.SCHEMA, "mode": "PROCEDURAL", "classes": ["SINGLETRACK"], "max_trails": 1}).config
	var report := {}
	# 1. Connection: a dry meadow with a short creek in its middle.
	var creek := Rect2(496.0, 260.0, 8.0, 120.0)
	var world: Dictionary = _world(creek)
	var planned: Dictionary = Planner.plan(config, world)
	report["connection"] = planned.report
	_check(not planned.trails.is_empty(), "a trail is proposed across the meadow", planned.rejected)
	if not planned.trails.is_empty():
		var trail: Dictionary = planned.trails[0]
		_check(trail.nodes == [0, 1] or trail.nodes == [1, 0], "the trail joins both road nodes", trail.nodes)
		_check(trail.class == Trail.TRAIL_CLASS and trail.class_name == "SINGLETRACK" and trail.origin == "PROCEDURAL", "class and origin recorded", [trail.class, trail.class_name])
		_check(trail.directions == ["FORWARD", "REVERSE"], "rideable both ways (realization record)", trail.directions)
		_check(trail.planner.road_m > 2.0 * trail.length_m, "a real shortcut: road distance > 2 x trail length", [trail.planner.road_m, trail.length_m])
		var line: Dictionary = trail.line
		var n: int = line.s.size()
		var first: int = trail.joins[0].leave_index
		var last: int = trail.joins[1].leave_index
		var dry: bool = true
		var off_road: bool = true
		for k in range(n):
			var p := Vector2(line.x[k], line.z[k])
			dry = dry and creek.grow(TrailPolicy.WATER_CLEAR_M - 0.5).has_point(p) == false
			if k > first and k < last:
				off_road = off_road and world.surface.road_owner(p.x, p.y).is_empty()
		_check(dry, "the line keeps clear of the creek")
		_check(off_road, "the line meets no road between its joins")
		_check(not world.surface.road_owner(line.x[0], line.z[0]).is_empty() and not world.surface.road_owner(line.x[n - 1], line.z[n - 1]).is_empty(), "both ends on the road plane")
		_check(String(trail.purpose).contains("instead of") and trail.purpose.get_slice(":", 0) in ["MEADOW_SHORTCUT", "CREEK_PASSAGE", "HILLSIDE_CUT", "SLOPE_TRAVERSE"],
			"purpose names the natural reason", trail.purpose)
		report["trail"] = {"id": trail.id, "length_m": trail.length_m, "metrics": trail.metrics, "purpose": trail.purpose}
	# 2. Determinism: the same inputs give byte-identical proposals.
	var again: Dictionary = Planner.plan(config, _world(creek))
	_check(var_to_bytes(again.trails) == var_to_bytes(planned.trails) and JSON.stringify(again.rejected) == JSON.stringify(planned.rejected), "deterministic proposals")
	# 3. Refusal: a creek across the whole meadow leaves no trail, with reasons.
	var blocked: Dictionary = Planner.plan(config, _world(Rect2(496.0, 0.0, 8.0, 690.0)))
	_check(blocked.trails.is_empty(), "no trail across a continuous creek", blocked.trails.map(func(t: Dictionary) -> String: return t.id))
	_check(not blocked.rejected.is_empty() and blocked.rejected.all(func(r: Dictionary) -> bool: return r.reason_code in ["ERR_TRAIL_SEARCH", "ERR_TRAIL_SCREEN"]),
		"refusals carry search / screen reasons", blocked.rejected.slice(0, 3))
	report["refusal"] = {"rejected": blocked.rejected.size(), "reasons": blocked.rejected.map(func(r: Dictionary) -> String: return "%s/%s" % [r.reason_code, r.detail.get("stage", "")])}
	# 4. Policy configuration contract.
	_check(not TrailPolicy.parse({"schema": TrailPolicy.SCHEMA, "mode": "PROCEDURAL", "classes": ["ROAD"]}).is_valid, "unknown class rejected")
	_check(not TrailPolicy.parse({"schema": "slow_cycle.trail_config/1"}).is_valid, "BC1 configuration is not a procedural one")
	_check(not TrailPolicy.parse({"schema": TrailPolicy.SCHEMA, "mode": "PROCEDURAL", "classes": ["SINGLETRACK"], "max_trails": 0}).is_valid, "max_trails >= 1")
	# 5. Published ground raster: barycentric heights of tile triangles.
	var tile := {"origin": [0.0, 0.0], "arrays": _two_triangles()}
	var ground: Dictionary = Surface.published_ground([tile], {"min_x": 0.0, "min_z": 0.0, "max_x": 512.0, "max_z": 512.0}, 2.0)
	_check(is_equal_approx(Surface.ground_height(ground, 0.0, 0.0), 10.0) and is_equal_approx(Surface.ground_height(ground, 512.0, 512.0), 30.0), "raster corners")
	_check(absf(Surface.ground_height(ground, 256.0, 100.0) - (10.0 + 20.0 * 256.0 / 512.0)) < 1e-3, "raster plane interpolation", Surface.ground_height(ground, 256.0, 100.0))
	_check(is_nan(Surface.ground_height(ground, 600.0, 10.0)), "outside the raster is NAN")
	# 6. TECHNICAL on a terrace scarp (class interplay: test_region_network).
	var both: Dictionary = TrailPolicy.parse({"schema": TrailPolicy.SCHEMA, "mode": "PROCEDURAL", "classes": ["TECHNICAL"], "max_trails": 1}).config
	var scarp_world: Dictionary = _world(Rect2(), true)
	var scarp_plan: Dictionary = Planner.plan(both, scarp_world)
	var techs: Array = scarp_plan.trails.filter(func(t: Dictionary) -> bool: return t.class_name == "TECHNICAL")
	report["technical"] = scarp_plan.report
	_check(techs.size() == 1, "one TECHNICAL descent proposed on the scarp", scarp_plan.rejected.slice(0, 4))
	if not techs.is_empty():
		var tech: Dictionary = techs[0]
		var line: Dictionary = tech.line
		var n: int = line.s.size()
		_check(tech.class == Trail.Graph.RouteClass.TECHNICAL and tech.directions == ["FORWARD"], "TECHNICAL is one-way (FORWARD)", [tech.class, tech.directions])
		_check(line.y[0] - line.y[n - 1] > 15.0, "it descends from its first end to its second", [line.y[0], line.y[n - 1]])
		_check(tech.metrics.max_forward_climb <= Trail.FORWARD_CLIMB_TECHNICAL and tech.metrics.min_radius_m >= Trail.RADIUS_MIN_TECHNICAL_M
			and tech.metrics.max_grade <= Trail.Policy.grade_hard(Trail.Graph.RouteClass.TECHNICAL), "within the TECHNICAL limits", tech.metrics)
		_check(tech.planner.turns >= 2 and tech.planner.steep_share > 0.2, "linked turns and steep descent", [tech.planner.turns, tech.planner.steep_share])
		_check(not scarp_world.surface.road_owner(line.x[0], line.z[0]).is_empty() and not scarp_world.surface.road_owner(line.x[n - 1], line.z[n - 1]).is_empty()
			and is_finite(tech.planner.return.road_m) and tech.planner.return.road_m > tech.length_m, "no trap: entry and exit on the road, a way back by road", tech.planner.get("return"))
		report["technical_trail"] = {"id": tech.id, "length_m": tech.length_m, "metrics": tech.metrics, "turns": tech.planner.turns, "purpose": tech.purpose}
	# 7. Realization contract of the classes on one fall line down the scarp.
	var fall := {"id": "trail:fall", "mode": "NATURAL", "class": "TECHNICAL", "half_width_m": 0.5, "control_points": [[300.0, 350.0], [300.0, 380.0], [300.0, 500.0], [300.0, 600.0], [300.0, 620.0]],
		"nodes": [{"id": 0, "x_m": 200.0, "z_m": 350.0}, {"id": 1, "x_m": 200.0, "z_m": 620.0}], "operations": []}
	var fall_config := {"schema": Trail.SCHEMA, "seed": 4242, "region": [0, 0], "trails": [fall]}
	var as_tech: Dictionary = Trail.realize(fall, fall_config, scarp_world)
	_check(as_tech.is_valid, "TECHNICAL accepts the 24.5 % fall line", as_tech.get("detail"))
	var as_st: Dictionary = fall.duplicate(true)
	as_st.erase("class")
	var st_made: Dictionary = Trail.realize(as_st, fall_config, scarp_world)
	_check(not st_made.is_valid and st_made.reason_code == "ERR_TRAIL_UNRIDEABLE" and st_made.detail.stage == "grade", "SINGLETRACK refuses it (grade)", st_made.get("detail"))
	var up: Dictionary = fall.duplicate(true)
	up.control_points.reverse()
	up.nodes.reverse()
	var up_made: Dictionary = Trail.realize(up, fall_config, scarp_world)
	_check(not up_made.is_valid and up_made.detail.get("stage", "") == "direction", "a TECHNICAL line that climbs is refused", up_made.get("detail"))
	var bad_class: Dictionary = fall.duplicate(true)
	bad_class["class"] = "DOWNHILL"
	_check(Trail.realize(bad_class, fall_config, scarp_world).reason_code == "ERR_TRAIL_INPUT", "unknown class refused")
	# 8. Heap order and line helpers.
	var heap := Planner._Heap.new()
	for v: int in [5, 1, 4, 2, 3, 0]:
		heap.push(float(v), v)
	var popped: Array = []
	while not heap.is_empty():
		popped.append(heap.pop())
	_check(popped == [0, 1, 2, 3, 4, 5], "heap pops in key order", popped)
	var corner: Array[Vector2] = [Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]
	var cut: Array[Vector2] = Planner._chaikin(corner)
	_check(cut[0] == corner[0] and cut[cut.size() - 1] == corner[2] and cut.size() == 4, "corner cutting keeps the ends", cut)
	var straight: Array[Vector2] = [Vector2(0, 0), Vector2(5, 0.2), Vector2(10, 0)]
	_check(Planner._simplify(straight, 0.5).size() == 2, "simplification drops a near-collinear point")
	return report


## A 512 m square tile split into two planar triangles, h = 10 + 20 x / 512.
func _two_triangles() -> Array:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var h := func(x: float, z: float) -> float: return 10.0 + 20.0 * x / 512.0 + 0.0 * z
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, h.call(0, 0), 0), Vector3(512, h.call(512, 0), 0), Vector3(512, h.call(512, 512), 512), Vector3(0, h.call(0, 512), 512)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	return arrays
