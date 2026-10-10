extends SceneTree

## R6 road synthesis tests (ExecPlan §13, A4). Real production code, real
## R1-R5 inputs; independent measurements through road_synthesis_oracle.gd.
##   --group=contracts   policy / settings, input rejection, math, band, and
##                       isolated negative fixtures: each exercises the real
##                       production rule with the exact expected reason;
##   --group=regions --case=seed,x,z   real integration of one region:
##                       structure, determinism (repeat + rebuilt graph),
##                       arbitrary lookup order, immutable copies, reversal,
##                       oracle path checks on every exported piece, band
##                       containment, water re-derivation, natural barriers,
##                       seams, feature re-measurement, C1 / C2 / C3 records,
##                       R5 DEBT-3 recertification, search-budget negative.
## Output: per-check lines, JSON report under --out and the completion marker
## R6_TEST_SUMMARY group=.. checks=.. failures=.. completed=true.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const Plan = preload("res://scripts/world/region/road_synthesis_plan.gd")
const RMath = preload("res://scripts/world/region/regional_road_math.gd")
const Geo = preload("res://scripts/world/region/road_corridor_geometry.gd")
const Designer = preload("res://scripts/world/region/road_alignment_designer.gd")
const Junctions = preload("res://scripts/world/region/road_junction_planner.gd")
const Validator = preload("res://scripts/world/region/road_feasibility_validator.gd")
const Intent = preload("res://scripts/world/region/roadbed_intent.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Oracle = preload("res://scripts/test/road_synthesis_oracle.gd")
const Preview = preload("res://scripts/world/region_preview.gd")

var _checks: int = 0
var _failures: Array = []
var _report: Dictionary = {}


func _check(name: String, ok: bool, detail: Variant = "") -> bool:
	_checks += 1
	if not ok:
		_failures.append({"check": name, "detail": detail})
		print("R6_TEST FAIL %s %s" % [name, JSON.stringify(detail).substr(0, 600)])
	return ok


func _init() -> void:
	var group: String = ""
	var case_row: Array = []
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--group="):
			group = arg.substr(8)
		elif arg.begins_with("--case="):
			var parts: PackedStringArray = arg.substr(7).split(",")
			if parts.size() == 3:
				var s: Dictionary = Preview.parse_integer(parts[0], 64)
				var x: Dictionary = Preview.parse_integer(parts[1], 32)
				var z: Dictionary = Preview.parse_integer(parts[2], 32)
				if s.is_valid and x.is_valid and z.is_valid:
					case_row = [s.value, Vector2i(x.value, z.value)]
		elif arg.begins_with("--out="):
			out = arg.substr(6).replace("\\", "/")
		else:
			group = "!invalid"
	if not group in ["contracts", "regions"] or (group == "regions" and case_row.is_empty()) or out.is_empty():
		print("R6_TEST_FAIL ERR_R6_CLI_ARGUMENT")
		quit(2)
		return
	var t0: int = Time.get_ticks_usec()
	if group == "contracts":
		_contracts()
	else:
		_regions(case_row[0], case_row[1])
	_report["checks"] = _checks
	_report["failures"] = _failures
	_report["duration_s"] = (Time.get_ticks_usec() - t0) / 1e6
	_report["provenance"] = {}
	for name: String in ["road_synthesis_policy", "road_synthesis_plan", "road_synthesizer", "road_corridor_geometry", "road_alignment_designer", "regional_road_math",
			"road_junction_planner", "road_feasibility_validator", "roadbed_intent", "region_seed_derivation"]:
		_report.provenance[name] = FileAccess.get_sha256("res://scripts/world/region/" + name + ".gd")
	for name: String in ["test_road_synthesis", "road_synthesis_oracle"]:
		_report.provenance[name] = FileAccess.get_sha256("res://scripts/test/" + name + ".gd")
	DirAccess.make_dir_recursive_absolute(out)
	var file_name: String = "r6_test_%s%s.json" % [group, "" if case_row.is_empty() else "_%d_%d_%d" % [case_row[0], case_row[1].x, case_row[1].y]]
	var file := FileAccess.open(out.path_join(file_name), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	print("R6_TEST_SUMMARY group=%s case=%s checks=%d failures=%d completed=true" % [group, str(case_row), _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _upstream(seed_value: int, region: Vector2i) -> Dictionary:
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: RefCounted = HGen.build(plan, terrain).plan
	var routes: Dictionary = Planner.plan(plan, terrain, hydro)
	var context: RefCounted = Context.create(plan, terrain, hydro).context
	var biome: RefCounted = Biome.create(context).field
	var ride: RefCounted = Ride.create(context, biome).field
	var hfield: RefCounted = HField.create(hydro, terrain).field
	var surface: RefCounted = Surface.create(terrain, hfield).surface
	return {"plan": plan, "terrain": terrain, "hydrology": hydro, "graph": routes.graph, "ride": ride, "hfield": hfield, "surface": surface,
		"natural": Geo.Natural.create(surface, ride, hfield, hydro, routes.graph.get_origin_x_m(), routes.graph.get_origin_z_m(), Policy.MAX_NATURAL_QUERIES)}


# =====================================================================
# contracts
# =====================================================================

func _contracts() -> void:
	# Policy / settings.
	_check("settings_default", Policy.resolve_settings({}).is_valid)
	_check("settings_unknown_key", Policy.resolve_settings({"speed": 1}).reason_code == "ERR_R6_SCHEMA")
	_check("settings_schema_tag", Policy.resolve_settings({"schema": "other/1"}).reason_code == "ERR_R6_SCHEMA")
	_check("settings_nonfinite", Policy.resolve_settings({"max_fit_evaluations": INF}).reason_code == "ERR_R6_CONFIG")
	_check("settings_range", Policy.resolve_settings({"max_natural_queries": 5}).reason_code == "ERR_R6_CONFIG")
	_check("settings_fraction", Policy.resolve_settings({"max_final_samples": 2000.5}).reason_code == "ERR_R6_CONFIG")
	_check("settings_type", Policy.resolve_settings("x").reason_code == "ERR_R6_SCHEMA")
	_check("policy_digest_stable", Policy.digest() == Policy.digest() and Policy.digest().length() == 64)
	# Seed purpose: additive, old preimages unchanged.
	_check("seed_route_unchanged", Seeds.route_seed_preimage(7) == "slow_cycle.seed/1\npurpose=route\ncount=1\nv0=7\n")
	_check("seed_road_purpose", Seeds.road_synthesis_seed_preimage(7) == "slow_cycle.seed/1\npurpose=road_synthesis\ncount=1\nv0=7\n" and Seeds.road_synthesis_seed(7) != Seeds.route_seed(7))
	_math()
	_band()
	var up: Dictionary = _upstream(184729, Vector2i.ZERO)
	var other: Dictionary = _upstream(42, Vector2i.ZERO)
	# Input rejection (null plan in every case).
	var cases: Array = [
		["input_missing", Synth.synthesize(null, up.terrain, up.hydrology, up.graph), "ERR_R6_INPUT_MISSING"],
		["input_invalid_type", Synth.synthesize(up.plan, up.hydrology, up.hydrology, up.graph), "ERR_R6_INPUT_INVALID"],
		["input_foreign_graph", Synth.synthesize(up.plan, up.terrain, up.hydrology, other.graph), "ERR_R6_INPUT_MISMATCH"],
		["input_foreign_hydrology", Synth.synthesize(up.plan, up.terrain, other.hydrology, up.graph), "ERR_R6_INPUT_MISMATCH"],
		["input_foreign_terrain", Synth.synthesize(up.plan, other.terrain, up.hydrology, up.graph), "ERR_R6_INPUT_MISMATCH"],
		["input_bad_settings", Synth.synthesize(up.plan, up.terrain, up.hydrology, up.graph, {"bogus": 1}), "ERR_R6_SCHEMA"],
		["input_bad_config", Synth.synthesize(up.plan, up.terrain, up.hydrology, up.graph, {"max_fit_evaluations": -3}), "ERR_R6_CONFIG"]]
	var broken: Dictionary = up.graph.get_data()
	var half: PackedInt32Array = broken.edges[0].corridor.half_left_cm
	half[0] = 1
	broken.edges[0].corridor.half_left_cm = half
	cases.append(["input_invalid_graph", Synth.synthesize(up.plan, up.terrain, up.hydrology, Graph.new(broken)), "ERR_R6_INPUT_INVALID"])
	for c: Array in cases:
		_check(c[0], c[1].status == "REJECT" and c[1].plan == null and c[1].reason_code == c[2], {"got": c[1].reason_code, "status": c[1].status})
	_negatives(up)


func _math() -> void:
	var c: PackedFloat64Array = RMath.quintic(1.0, 2.0, 3.0, 4.0, 5.0, 6.0)
	_check("quintic_ends", absf(RMath.poly(c, 0, 0.0) - 1.0) < 1e-12 and absf(RMath.poly(c, 0, 1.0) - 4.0) < 1e-12 and absf(RMath.poly_d1(c, 0, 1.0) - 5.0) < 1e-12
		and absf(RMath.poly_d2(c, 0, 0.0) - 3.0) < 1e-12 and absf(RMath.poly_d2(c, 0, 1.0) - 6.0) < 1e-12)
	# G2 continuity at an interior knot of a plan spline; arc length of a
	# straight span equals its chord.
	var spline := RMath.PlanSpline.new()
	spline.kx = PackedFloat64Array([0.0, 50.0, 90.0])
	spline.kz = PackedFloat64Array([0.0, 10.0, 40.0])
	spline.ktx = PackedFloat64Array([1.0, 0.94, 0.6])
	spline.ktz = PackedFloat64Array([0.0, 0.3411744, 0.8])
	spline.kk = PackedFloat64Array([0.0, 0.01, 0.0])
	spline.span_param = PackedFloat64Array([52.0, 50.0])
	spline.build()
	var left: PackedFloat64Array = spline.eval(0, 1.0)
	var right: PackedFloat64Array = spline.eval(1, 0.0)
	_check("g2_knot_continuity", absf(left[0] - right[0]) < 1e-9 and absf(left[1] - right[1]) < 1e-9 and absf(left[2] - right[2]) < 1e-6 and absf(left[4] - right[4]) < 1e-6
		and absf(right[4] - 0.01) < 1e-6, [left, right])
	var line := RMath.PlanSpline.new()
	line.kx = PackedFloat64Array([0.0, 30.0])
	line.kz = PackedFloat64Array([0.0, 40.0])
	line.ktx = PackedFloat64Array([0.6, 0.6])
	line.ktz = PackedFloat64Array([0.8, 0.8])
	line.kk = PackedFloat64Array([0.0, 0.0])
	line.span_param = PackedFloat64Array([50.0])
	line.build()
	_check("arc_length_straight", absf(line.total_length - 50.0) < 1e-6, line.total_length)
	var mid: PackedFloat64Array = line.eval_s(25.0)
	_check("arc_inverse", absf(mid[0] - 15.0) < 1e-4 and absf(mid[1] - 20.0) < 1e-4, mid)
	# Lipschitz envelopes and fairing.
	var v := PackedFloat64Array([0.0, 10.0, 0.0, 0.0])
	var up_env: PackedFloat64Array = RMath.lipschitz_upper(v, 1.0, 2.0)
	var lo_env: PackedFloat64Array = RMath.lipschitz_lower(v, 1.0, 2.0)
	_check("lipschitz", up_env == PackedFloat64Array([0.0, 2.0, 0.0, 0.0]) and lo_env == PackedFloat64Array([8.0, 10.0, 8.0, 6.0]), [up_env, lo_env])
	var w := PackedFloat64Array([1e9, 1.0, 1.0, 1.0, 1e9])
	var lam := PackedFloat64Array([0.0, 50.0, 50.0, 50.0, 0.0])
	var faired: PackedFloat64Array = RMath.fair(PackedFloat64Array([0.0, 1.0, -1.0, 1.0, 0.0]), w, lam)
	_check("fairing_smooths", absf(faired[0]) < 1e-6 and absf(faired[4]) < 1e-6 and absf(faired[2]) < 0.5, faired)
	var lobes: Array = RMath.turn_lobes(PackedFloat64Array([0, 10, 20, 30, 40, 50]), PackedFloat64Array([0.0, 0.02, 0.02, 0.0, -0.02, 0.0]), 0.01, 1.0)
	_check("turn_lobes", lobes.size() == 2 and lobes[0].turn > 0.0 and lobes[1].turn < 0.0, lobes)
	_check("three_point_sign", RMath.three_point_curvature(0, 0, 1, 0, 2, 1) > 0.0)


func _band() -> void:
	var corridor := {"edge_id": 0, "station_count": 3, "x_m": PackedFloat64Array([100.0, 200.0, 200.0]), "z_m": PackedFloat64Array([100.0, 100.0, 200.0]),
		"half_left_m": PackedFloat64Array([10.0, 10.0, 10.0]), "half_right_m": PackedFloat64Array([20.0, 20.0, 20.0])}
	var band: Geo.Band = Geo.Band.from_corridor(corridor, 0.0, 0.0)
	# Left normal of the first segment (+x travel) is +z.
	_check("band_left_inside", band.clearance(150.0, 105.0)[0] > 0.0 and absf(band.clearance(150.0, 105.0)[0] - 5.0) < 1e-9)
	_check("band_left_outside", band.clearance(150.0, 112.0)[0] < 0.0)
	_check("band_right_inside", band.clearance(150.0, 85.0)[0] > 0.0)
	_check("band_corner_cap", band.clearance(205.0, 95.0)[0] > 0.0 and band.clearance(225.0, 75.0)[0] < 0.0)
	_check("band_oracle_agrees", absf(band.clearance(150.0, 90.0)[0] - Oracle.band_clearance(corridor, 0.0, 0.0, 150.0, 90.0)) < 1e-9)
	_check("band_hint_window", band.clearance(200.0, 190.0, 0, 0)[0] < band.clearance(200.0, 190.0, 1, 0)[0])


## Isolated negatives (§13): real production rules, adversarial inputs.
func _negatives(up: Dictionary) -> void:
	var natural: Geo.Natural = up.natural
	var validator: Validator = Validator.create(natural)
	var designer: Designer = Designer.create(natural, Policy.MAX_FIT_EVALUATIONS)
	var straight: Dictionary = _straight_design(500.0, 1000.0, 400.0, 1.0, 0.0, 200.0, 0.02, 2.8)
	_check("neg_baseline_geometry", validator._geometry(straight, 1, false).reasons.is_empty() and validator._structure(straight).reasons.is_empty(),
		[validator._geometry(straight, 1, false), validator._structure(straight)])
	var nan_design: Dictionary = straight.duplicate(true)
	nan_design.y[5] = NAN
	_check("neg_nonfinite", validator._structure(nan_design).reasons == ["ERR_R6_NONFINITE"], validator._structure(nan_design).reasons)
	var short_design: Dictionary = straight.duplicate(true)
	short_design.width.resize(3)
	_check("neg_path_structure", validator._structure(short_design).reasons == ["ERR_R6_PATH_STRUCTURE"], validator._structure(short_design).reasons)
	var steep: Dictionary = _straight_design(500.0, 1000.0, 400.0, 1.0, 0.0, 200.0, 0.16, 2.8)
	_check("neg_grade", validator._geometry(steep, 1, false).reasons == ["ERR_R6_GRADE"], validator._geometry(steep, 1, false))
	var tight: Dictionary = _arc_design(500.0, 1000.0, 400.0, 15.0, 1.2)
	_check("neg_curvature", validator._geometry(tight, 2, false).reasons == ["ERR_R6_CURVATURE"], validator._geometry(tight, 2, false))
	# Grade steps 0.02 -> 0.08 within one 2 m sample (points consistent).
	var kink: Dictionary = straight.duplicate(true)
	var ky: PackedFloat64Array = kink.y
	var kg: PackedFloat64Array = kink.grade
	ky[50] = ky[49] + 0.05 * (kink.s[50] - kink.s[49])
	for i in range(50, kink.s.size()):
		kg[i] = 0.08
		if i > 50:
			ky[i] = ky[50] + 0.08 * (kink.s[i] - kink.s[50])
	kink.y = ky
	kink.grade = kg
	_check("neg_grade_transition", validator._geometry(kink, 1, false).reasons == ["ERR_R6_GRADE_TRANSITION"], validator._geometry(kink, 1, false))
	var flipped: Dictionary = straight.duplicate(true)
	for i in range(20, 22):
		flipped.tx[i] = -flipped.tx[i]
	_check("neg_frame", "ERR_R6_FRAME" in validator._geometry(flipped, 1, false).reasons, validator._geometry(flipped, 1, false))
	var banked: Dictionary = straight.duplicate(true)
	for i in range(banked.s.size()):
		banked.bank[i] = 9.0
	_check("neg_bank", validator._geometry(banked, 1, false).reasons == ["ERR_R6_BANK"], validator._geometry(banked, 1, false))
	var sparse: Dictionary = _straight_design(500.0, 1000.0, 400.0, 1.0, 0.0, 200.0, 0.02, 2.8, 3.0)
	_check("neg_sampling", validator._structure(sparse).reasons == ["ERR_R6_SAMPLING"], validator._structure(sparse).reasons)
	var coarse_arc: Dictionary = _arc_design(500.0, 1000.0, 400.0, 30.0, 2.2)
	_check("neg_certification_unresolved", validator._structure(coarse_arc).reasons == ["ERR_R6_CERTIFICATION_UNRESOLVED"], validator._structure(coarse_arc))
	var far: Dictionary = _straight_design(2.0e6 + 0.3337, 1000.1234, 400.0, 1.0, 0.0, 50.0, 0.0, 2.8)
	_check("neg_precision", "ERR_R6_PRECISION" in validator._frame(far).reasons, validator._frame(far))
	# Seams.
	var row := {"x": 10.0, "y": 5.0, "z": 3.0, "tx": 1.0, "tz": 0.0, "grade": 0.02, "bank": 1.0}
	var torn: Dictionary = row.duplicate()
	torn.x += 0.002
	_check("neg_seam_tear", Validator.seam(row, torn).reasons == ["ERR_R6_SEAM"] and Validator.seam(row, row).reasons.is_empty())
	var turned: Dictionary = row.duplicate()
	turned.tz = 0.01
	_check("neg_seam_tangent", Validator.seam(row, turned).reasons == ["ERR_R6_SEAM"])
	# Overlap of two pieces crossing without a node.
	var a_piece: Dictionary = _straight_design(1000.0, 1000.0, 300.0, 1.0, 0.0, 200.0, 0.0, 2.8)
	var b_piece: Dictionary = _straight_design(1100.0, 900.0, 300.0, 0.0, 1.0, 200.0, 0.0, 2.8)
	var overlap: Array = Validator.overlaps([{"piece_id": "a", "design": a_piece, "zones": []}, {"piece_id": "b", "design": b_piece, "zones": []}])
	_check("neg_unplanned_intersection", overlap.size() == 1 and overlap[0].kind == "ERR_R6_UNPLANNED_INTERSECTION", overlap)
	# Feature realisation against final geometry.
	var unrealised: Array = Validator.measure_features([{"kind": "SWEEP", "s0": 20.0, "s1": 120.0, "envelope": {"turn_deg": 45.0, "min_turn_deg": 30.0, "sign": 1.0}, "status": "", "measured": {}, "reasons": []},
		{"kind": "CREST", "s0": 20.0, "s1": 180.0, "envelope": {"apex_s": 100.0, "prominence_m": 4.0, "min_prominence_m": 2.0}, "status": "", "measured": {}, "reasons": []}], straight)
	_check("neg_feature_unrealized", unrealised[0].status == Policy.REJECTED and unrealised[0].reasons == ["ERR_R6_FEATURE_UNREALIZED"] and unrealised[1].status == Policy.REJECTED, unrealised)
	var arc_ok: Array = Validator.measure_features([{"kind": "SWEEP", "s0": 0.0, "s1": 60.0, "envelope": {"turn_deg": 60.0, "min_turn_deg": 40.0, "sign": 1.0}, "status": "", "measured": {}, "reasons": []}],
		_arc_design(500.0, 1000.0, 400.0, 60.0, 1.0))
	_check("feature_realized_positive", arc_ok[0].status == Policy.REALIZED, arc_ok)
	# Earthwork and deck support on a real READY-style record.
	var fill: Dictionary = straight.duplicate(true)
	fill.fill_l[10] = 2.5
	var context := {"route_class": 1, "band_request": {"band": _wide_band(straight), "zones": [], "gateway_ends": true}}
	_check("neg_earthwork", "ERR_R6_EARTHWORK" in validator._footprint(fill, context).reasons and not "ERR_R6_EARTHWORK" in validator._footprint(straight, context).reasons,
		validator._footprint(fill, context))
	var outside: Dictionary = straight.duplicate(true)
	for i in range(outside.s.size()):
		outside.z[i] += 400.0
	_check("neg_corridor_clearance", validator._footprint(outside, context).reasons == ["ERR_R6_CORRIDOR_CLEARANCE"], validator._footprint(outside, context))
	# Water: real channel crossings from the hydrology plan.
	_water_negatives(up, validator, designer)
	# Profile negatives through the real designer stage.
	_profile_negatives(designer)
	# Grade reach certificate and sight distance.
	var reach: Dictionary = designer._grade_reach({"x": PackedFloat64Array([1000, 1010, 1020, 1030]), "z": PackedFloat64Array([2000, 2000, 2000, 2000])}, 0)
	_check("grade_reach_runs", reach.has("is_valid"))
	_sight_negative(designer)
	# Junction: plane far from the natural surface -> movements unavailable.
	_junction_negatives(up)
	# Duplicate ownership in a plan envelope.
	_plan_negatives()
	# Natural barrier: a real EXCESSIVE_SLOPE location from the R4 field.
	_barrier_negative(up, validator)


func _straight_design(x0: float, z0: float, length: float, dx: float, dz: float, y0: float, grade: float, width: float, step: float = 2.0) -> Dictionary:
	var d: Dictionary = {}
	for key: String in Plan.DESIGN_KEYS:
		d[key] = PackedFloat64Array()
	var n: int = int(length / step)
	for i in range(n + 1):
		var s: float = i * step
		d.s.append(s)
		d.x.append(x0 + dx * s)
		d.z.append(z0 + dz * s)
		d.y.append(y0 + grade * s)
		d.tx.append(dx)
		d.tz.append(dz)
		d.grade.append(grade)
		for key: String in ["k", "dk", "vk", "bank", "fill_l", "fill_r", "tie_l", "tie_r"]:
			d[key].append(0.0)
		d.width.append(width)
		d.nat_c.append(y0 + grade * s)
		d.nat_l.append(y0 + grade * s)
		d.nat_r.append(y0 + grade * s)
		d.sight_forward.append(120.0)
		d.sight_backward.append(120.0)
	var support := PackedByteArray()
	support.resize(n + 1)
	d["support"] = support
	return d


func _arc_design(x0: float, z0: float, y0: float, radius: float, step: float) -> Dictionary:
	var d: Dictionary = _straight_design(x0, z0, 60.0, 1.0, 0.0, y0, 0.0, 1.8, step)
	for i in range(d.s.size()):
		var a: float = d.s[i] / radius
		d.x[i] = x0 + radius * sin(a)
		d.z[i] = z0 + radius * (1.0 - cos(a))
		d.tx[i] = cos(a)
		d.tz[i] = sin(a)
		d.k[i] = 1.0 / radius
	return d


func _wide_band(design: Dictionary) -> Geo.Band:
	var n: int = design.s.size()
	var corridor := {"edge_id": 99, "station_count": 2, "x_m": PackedFloat64Array([design.x[0], design.x[n - 1]]), "z_m": PackedFloat64Array([design.z[0], design.z[n - 1]]),
		"half_left_m": PackedFloat64Array([60.0, 60.0]), "half_right_m": PackedFloat64Array([60.0, 60.0])}
	return Geo.Band.from_corridor(corridor, 0.0, 0.0)


func _water_negatives(up: Dictionary, validator: Validator, designer: Designer) -> void:
	# A straight design across the major river (channel 0) at mid-river.
	var channel: Dictionary = up.hydrology.get_channel(0)
	var mid: int = channel.x_cm.size() / 2
	var p := Vector2(channel.x_cm[mid], channel.z_cm[mid]) / 100.0
	var q := Vector2(channel.x_cm[mid + 1], channel.z_cm[mid + 1]) / 100.0
	var dir: Vector2 = (q - p).normalized()
	var across := Vector2(-dir.y, dir.x)
	var start: Vector2 = p - across * 80.0
	var design: Dictionary = _straight_design(start.x, start.y, 160.0, across.x, across.y, channel.surface_cm[mid] / 100.0 + 3.0, 0.0, 3.6, 1.0)
	var pin := {"index": 0, "x": p.x, "z": p.y, "channel_id": channel.id}
	var ok: Dictionary = validator._water(design, {"pins": [pin], "crossings": []})
	_check("water_baseline_match", not "ERR_R6_CROSSING_MISSING" in ok.reasons and not "ERR_R6_CROSSING_EXTRA" in ok.reasons and ok.measured.matched.size() == 1, ok.measured)
	_check("neg_crossing_extra", "ERR_R6_CROSSING_EXTRA" in validator._water(design, {"pins": [], "crossings": []}).reasons)
	var shifted: Dictionary = pin.duplicate()
	shifted.x += dir.x * 20.0
	shifted.z += dir.y * 20.0
	_check("neg_crossing_displaced", "ERR_R6_CROSSING_DISPLACED" in validator._water(design, {"pins": [shifted], "crossings": []}).reasons)
	var phantom := {"index": 1, "x": start.x - across.x * 500.0, "z": start.y - across.y * 500.0, "channel_id": 9999}
	var phantom_result: Dictionary = validator._water(design, {"pins": [pin, phantom], "crossings": []})
	_check("neg_crossing_phantom", "ERR_R6_CROSSING_PHANTOM" in phantom_result.reasons, phantom_result.reasons)
	# Missing: a dry design with the real river pin.
	var dry: Dictionary = _straight_design(start.x - across.x * 300.0, start.y - across.y * 300.0, 50.0, dir.x, dir.y, 300.0, 0.0, 3.6, 1.0)
	_check("neg_crossing_missing", "ERR_R6_CROSSING_MISSING" in validator._water(dry, {"pins": [pin], "crossings": []}).reasons)
	# Water occupancy: no deck record although the design crosses the river.
	var occupied: Dictionary = validator._water(design, {"pins": [pin], "crossings": []})
	_check("neg_water_occupancy", "ERR_R6_WATER_OCCUPANCY" in occupied.reasons, occupied.reasons)
	# Deep ford record and deck clearance.
	var record := {"support": Policy.Support.FORD, "depth_m": 0.6, "wet_s0": 70.0, "wet_s1": 90.0, "clear_span_m": 20.0, "surface_m": channel.surface_cm[mid] / 100.0}
	_check("neg_deep_ford", "ERR_R6_WATER_OCCUPANCY" in validator._water(design, {"pins": [pin], "crossings": [record]}).reasons)
	var deck := {"support": Policy.Support.BRIDGE_DECK, "depth_m": 2.0, "wet_s0": 60.0, "wet_s1": 100.0, "clear_span_m": 44.0, "surface_m": channel.surface_cm[mid] / 100.0 + 5.0}
	_check("neg_crossing_support", "ERR_R6_CROSSING_SUPPORT" in validator._water(design, {"pins": [pin], "crossings": [deck]}).reasons)
	# Water body: a design through a body's lattice cells.
	if up.hydrology.get_body_count() > 0:
		var body: Dictionary = up.hydrology.get_body(0)
		var cell: int = body.cells[0]
		var centre := Vector2((cell % 129) * 32.0, (cell / 129) * 32.0)
		var through: Dictionary = _straight_design(centre.x - 30.0, centre.y, 60.0, 1.0, 0.0, body.level_cm / 100.0 + 1.0, 0.0, 2.8, 1.0)
		_check("neg_water_body", "ERR_R6_WATER_BODY" in validator._water(through, {"pins": [], "crossings": []}).reasons)
	else:
		_check("neg_water_body_fixture", false, "region has no water body")


func _profile_negatives(designer: Designer) -> void:
	# Synthetic sections on flat ground; the real profile stage decides.
	var n: int = 100
	var section := {"n": n, "ds": 2.0, "s": PackedFloat64Array(), "x": PackedFloat64Array(), "z": PackedFloat64Array(), "k": PackedFloat64Array(), "hc": PackedFloat64Array(),
		"hl": PackedFloat64Array(), "hr": PackedFloat64Array(), "slope_l": PackedFloat64Array(), "slope_r": PackedFloat64Array()}
	for i in range(n + 1):
		section.s.append(2.0 * i)
		section.x.append(2.0 * i)
		section.z.append(0.0)
		section.k.append(0.0)
		section.hc.append(100.0)
		section.hl.append(100.0)
		section.hr.append(100.0)
		section.slope_l.append(0.0)
		section.slope_r.append(0.0)
	var request := {"route_class": 1, "start": {"y": 100.0, "grade": 0.0, "grade_pinned": false, "bank_deg": 0.0}, "end": {"y": 100.0, "grade": 0.0, "grade_pinned": false, "bank_deg": 0.0}}
	var flat: Dictionary = designer._profile(request, null, section, {"records": []})
	_check("profile_baseline", flat.is_valid, flat)
	var lifted: Dictionary = request.duplicate(true)
	lifted.end.y = 160.0
	var grade_fail: Dictionary = designer._profile(lifted, null, section, {"records": []})
	_check("neg_profile_grade", not grade_fail.is_valid and grade_fail.reason_code == "ERR_R6_GRADE", grade_fail)
	var deck := {"support": Policy.Support.BRIDGE_DECK, "deck_s0": 96.0, "deck_s1": 104.0, "wet_s0": 98.0, "wet_s1": 102.0, "bed_s0": 99.0, "bed_s1": 101.0, "surface_m": 120.0}
	var approach: Dictionary = designer._profile(request, null, section, {"records": [deck]})
	_check("neg_crossing_approach", not approach.is_valid and approach.reason_code == "ERR_R6_CROSSING_APPROACH", approach)
	# A cross-section whose edges differ by more than cut + fill can absorb.
	var bumpy: Dictionary = section.duplicate(true)
	var hl: PackedFloat64Array = bumpy.hl
	var hr: PackedFloat64Array = bumpy.hr
	hl[50] = 104.0
	hr[50] = 96.0
	bumpy.hl = hl
	bumpy.hr = hr
	var earthwork: Dictionary = designer._profile(request, null, bumpy, {"records": []})
	_check("neg_profile_earthwork", not earthwork.is_valid and earthwork.reason_code == "ERR_R6_EARTHWORK", earthwork)


func _sight_negative(designer: Designer) -> void:
	# A sharp vertical crest (road surface itself blocks the line of sight).
	# High above all terrain: only the road's own crest can block the view.
	var flat: Dictionary = _straight_design(1000.0, 1000.0, 300.0, 1.0, 0.0, 3000.0, 0.0, 2.8, 1.0)
	var baseline: Dictionary = designer._sight({"route_class": 0}, flat)
	_check("sight_baseline", baseline.is_valid, baseline.detail)
	var d: Dictionary = flat.duplicate(true)
	var y: PackedFloat64Array = d.y
	var g: PackedFloat64Array = d.grade
	for i in range(d.s.size()):
		var s: float = d.s[i]
		y[i] = 3000.0 + 6.0 * exp(-pow((s - 150.0) / 12.0, 2.0))
		g[i] = -6.0 * 2.0 * (s - 150.0) / 144.0 * exp(-pow((s - 150.0) / 12.0, 2.0))
	d.y = y
	d.grade = g
	var sight: Dictionary = designer._sight({"route_class": 0}, d)
	_check("neg_approach_sight", not sight.is_valid and sight.min_ratio < 1.0, sight.detail)


func _junction_negatives(up: Dictionary) -> void:
	var planner: Junctions = Junctions.create(up.natural)
	var graph: RefCounted = up.graph
	var node: Dictionary = {}
	for n in range(graph.get_route_node_count()):
		if graph.get_route_node(n).kind == Graph.NodeKind.JUNCTION:
			node = graph.get_route_node(n)
			break
	var incident: Array = []
	for e: int in graph.edges_at(node.id):
		var edge: Dictionary = graph.get_edge(e)
		incident.append({"edge_id": e, "class": edge.class, "band": Geo.Band.from_corridor(graph.get_corridor(e), graph.get_origin_x_m(), graph.get_origin_z_m()),
			"at_start": edge.a == node.id, "route_id": edge.route_id})
	var cx: float = node.x_cm / 100.0
	var cz: float = node.z_cm / 100.0
	var fit: Dictionary = planner._plane(cx, cz, Policy.PATCH_GRADE_MAX)
	fit.y0 += 12.0
	var radii: Dictionary = {}
	for inc: Dictionary in incident:
		radii[inc.edge_id] = 38.0
	var attempt: Dictionary = planner._attempt({"node_id": node.id, "x": cx, "z": cz}, fit, incident, Junctions._essential_pairs(incident, []), radii)
	var heights: int = 0
	for m: Dictionary in attempt.movements:
		heights += 1 if "ERR_R6_JUNCTION_HEIGHT" in m.reasons else 0
	_check("neg_junction_height", heights > 0, attempt.movements.map(func(m: Dictionary) -> Array: return m.reasons))


func _plan_negatives() -> void:
	var design: Dictionary = _straight_design(100.0, 100.0, 20.0, 1.0, 0.0, 10.0, 0.0, 2.8)
	var base := {"schema": Policy.PLAN_SCHEMA, "policy_id": Policy.POLICY_ID, "policy_digest": "x", "algorithm": "x", "effective_seed": 1, "origin_x_m": 0, "origin_z_m": 0, "origin_y_m": 0,
		"region_signature": "r", "graph_signature": "g", "hydrology_signature": "h", "rideability_signature": "q", "status": "PARTIAL", "edges": [], "junctions": [], "crossings": [],
		"intents": [], "pieces": {"edge:1": {"piece_id": "edge:1", "kind": "EDGE", "owner": {"edge_id": 1}, "route_class": 1, "design": design}}}
	_check("plan_envelope_valid", Plan.new(base).validate().is_valid, Plan.new(base).validate())
	var dup: Dictionary = base.duplicate(true)
	dup.pieces["edge:2"] = {"piece_id": "edge:2", "kind": "EDGE", "owner": {"edge_id": 1}, "route_class": 1, "design": design}
	_check("neg_duplicate_piece", Plan.new(dup).validate().reason_codes == ["ERR_R6_DUPLICATE_PIECE"], Plan.new(dup).validate())
	var bad: Dictionary = base.duplicate(true)
	bad.pieces["edge:1"].design.y[3] = INF
	_check("neg_plan_nonfinite", "ERR_R6_NONFINITE" in Plan.new(bad).validate().reason_codes)
	# Copies: mutation of a returned record never reaches the plan.
	var plan := Plan.new(base)
	var signature: String = plan.signature()
	var copy: Dictionary = plan.get_design("edge:1")
	copy.y[0] = -1000.0
	var env: Dictionary = plan.get_path("edge:1")
	env.path.points[0] = Vector3(9, 9, 9)
	_check("plan_immutable", plan.get_design("edge:1").y[0] == 10.0 and plan.get_path("edge:1").path.points[0] != Vector3(9, 9, 9) and plan.signature() == signature)


func _barrier_negative(up: Dictionary, validator: Validator) -> void:
	var found := Vector2(-1, -1)
	for j in range(8, 248, 4):
		for i in range(8, 248, 4):
			var r: Dictionary = up.ride.sample(up.graph.get_origin_x_m() + i * 16.0, up.graph.get_origin_z_m() + j * 16.0)
			if r.is_valid and (r.reason_flags & Ride.Reason.EXCESSIVE_SLOPE):
				found = Vector2(i * 16.0, j * 16.0)
				break
		if found.x >= 0.0:
			break
	if found.x < 0.0:
		_check("neg_natural_barrier_fixture", false, "no EXCESSIVE_SLOPE sample found in the scanned lattice")
		return
	var design: Dictionary = _straight_design(found.x - 6.0, found.y, 12.0, 1.0, 0.0, 300.0, 0.0, 1.8, 1.0)
	var result: Dictionary = validator._natural(design, {})
	_check("neg_natural_barrier", "ERR_R6_NATURAL_BARRIER" in result.reasons, result)


# =====================================================================
# regions
# =====================================================================

func _regions(seed_value: int, region: Vector2i) -> void:
	var up: Dictionary = _upstream(seed_value, region)
	var graph: RefCounted = up.graph
	var t0: int = Time.get_ticks_usec()
	var result: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, graph)
	_report["r6_s"] = (Time.get_ticks_usec() - t0) / 1e6
	_report["status"] = result.status
	if not _check("region_plan_present", result.plan != null and result.status in ["READY", "PARTIAL"], [result.status, result.reason_code]):
		return
	var plan: RefCounted = result.plan
	var data: Dictionary = plan.get_data()
	_report["signature"] = plan.signature()
	_check("plan_self_validates", plan.validate().is_valid, plan.validate())
	_check("status_flags", result.is_valid == (result.status == "READY"))
	# Determinism: repeat and rebuilt graph object.
	var again: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, Graph.new(graph.get_data(), graph.get_diagnostics()))
	_check("determinism_repeat", again.plan != null and again.plan.signature() == plan.signature(), [again.status, again.plan.signature() if again.plan != null else ""])
	# Completeness of records.
	_check("edge_records_complete", data.edges.size() == graph.get_edge_count())
	var junction_nodes: int = 0
	for n in range(graph.get_route_node_count()):
		junction_nodes += 1 if graph.get_route_node(n).kind == Graph.NodeKind.JUNCTION else 0
	_check("junction_records_complete", data.junctions.size() == junction_nodes)
	var r5_crossings: int = 0
	for e in range(graph.get_edge_count()):
		r5_crossings += graph.get_edge(e).crossings.size()
	_check("crossing_records_complete", data.crossings.size() == r5_crossings, [data.crossings.size(), r5_crossings])
	for record: Dictionary in data.edges:
		_check("edge_outcome_%d" % record.edge_id, (record.status == "READY" and not record.piece_id.is_empty()) or (record.status != "READY" and record.piece_id.is_empty() and not record.reasons.is_empty()), record.status)
	# C1: movements explicit; READY plan only if all are.
	var all_available: bool = true
	for j: Dictionary in data.junctions:
		var essential_ok: bool = true
		for m: Dictionary in j.movements:
			_check("movement_explicit_%s" % m.piece_id, m.status == Policy.MOVEMENT_READY or not m.reasons.is_empty(), m)
			all_available = all_available and m.status == Policy.MOVEMENT_READY
			essential_ok = essential_ok and (m.status == Policy.MOVEMENT_READY or not m.essential)
		_check("junction_status_%d" % j.node_id, (j.status == Policy.JUNCTION_READY) == (j.movements.all(func(m: Dictionary) -> bool: return m.status == Policy.MOVEMENT_READY) and not "ERR_R6_JUNCTION_HEIGHT" in j.reasons and not "ERR_R6_CROSSING_APPROACH" in j.reasons), j.status)
	if not all_available:
		_check("c1_not_ready_with_unavailable_movement", result.status != "READY")
	# C2: crossing records.
	for c: Dictionary in data.crossings:
		if c.status == "RESOLVED":
			_check("c2_record_%s" % c.crossing_id, c.has("r6_x") and c.has("displacement_m") and c.displacement_m <= Policy.CROSSING_MAX_DISPLACEMENT_M and c.has("hydrology_validation")
				and c.hydrology_validation.channel_id == c.channel_id and (c.displacement_m <= Policy.CROSSING_RECORD_TOLERANCE_M or not c.justification.is_empty()), c)
	# C3: intents.
	for intent_id: String in plan.get_intent_ids():
		var intent: Dictionary = plan.get_intent(intent_id)
		_check("intent_valid_%s" % intent_id, intent.status == "UNSUPPORTED" or Intent.validate(intent).is_valid, Intent.validate(intent))
		for ref: Dictionary in intent.get("crossings", []):
			if ref.support == "BRIDGE_DECK":
				_check("c3_deck_obligation_%s" % intent_id, ref.requires_support and not ref.physical_support_built and ref.deck_min_m > ref.water_surface_m)
	# Pieces: oracle checks, reversal, lookup order, immutability.
	var ids: PackedStringArray = plan.get_piece_ids()
	var digests_forward: Dictionary = {}
	for piece_id: String in ids:
		var info: Dictionary = plan.get_piece_info(piece_id)
		var env: Dictionary = plan.get_path(piece_id)
		_check("envelope_%s" % piece_id, env.origin_x_m == graph.get_origin_x_m() and env.origin_z_m == graph.get_origin_z_m() and env.origin_y_m == 0 and env.path.branch_id == -1)
		var path: RefCounted = env.path
		var measured: Dictionary = Oracle.path_checks(path, info.route_class, info.kind == "MOVEMENT")
		_check("oracle_path_%s" % piece_id, measured.failures.is_empty(), measured)
		var backward: RefCounted = plan.get_path(piece_id, true).path
		var twice: RefCounted = Plan.export_path(Plan.oriented(Plan.oriented(plan.get_design(piece_id), true), true), false)
		_check("reversal_%s" % piece_id, Oracle.reversal_checks(path, backward, twice).is_empty(), Oracle.reversal_checks(path, backward, twice))
		digests_forward[piece_id] = Plan._sha256(Plan.export_bytes(path))
		_check("export_digest_%s" % piece_id, digests_forward[piece_id] == info.export_sha256)
		path.points[0] = Vector3(1, 2, 3)
		_check("path_copy_%s" % piece_id, plan.get_path(piece_id).path.points[0] != Vector3(1, 2, 3))
	var reversed_ids: Array = Array(ids)
	reversed_ids.reverse()
	var order_ok: bool = true
	for piece_id: String in reversed_ids:
		order_ok = order_ok and Plan._sha256(Plan.export_bytes(plan.get_path(piece_id).path)) == digests_forward[piece_id]
	_check("lookup_order_independent", order_ok)
	_check("signature_after_mutation", plan.signature() == _report.signature)
	# Edge interiors: band containment, water, barriers, features (oracle).
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var resolved: Dictionary = {}
	for c: Dictionary in data.crossings:
		if c.status == "RESOLVED":
			if not resolved.has(c.edge_id):
				resolved[c.edge_id] = []
			resolved[c.edge_id].append(c)
	for record: Dictionary in data.edges:
		if record.status != "READY":
			continue
		var corridor: Dictionary = graph.get_corridor(record.edge_id)
		var path: RefCounted = plan.get_path(record.piece_id).path
		var worst: float = INF
		for i in range(path.points.size()):
			var p: Vector3 = path.points[i]
			var c_own: float = Oracle.band_clearance(corridor, ox, oz, p.x, p.z)
			if c_own < 0.0:
				# Inside a junction zone the union of incident bands applies.
				for node_id: int in [record.a, record.b]:
					var node: Dictionary = graph.get_route_node(node_id)
					if Vector2(p.x - node.x_cm / 100.0, p.z - node.z_cm / 100.0).length() <= Policy.JUNCTION_ZONE_M:
						for e: int in graph.edges_at(node_id):
							c_own = maxf(c_own, Oracle.band_clearance(graph.get_corridor(e), ox, oz, p.x, p.z))
			worst = minf(worst, c_own)
		_check("oracle_band_%d" % record.edge_id, worst >= 0.0, worst)
		var hits: Dictionary = Oracle.channel_hits(path, up.hydrology)
		var expected: Array = resolved.get(record.edge_id, [])
		_check("oracle_crossings_%d" % record.edge_id, hits.hits.size() == expected.size() and hits.bodies.is_empty(), {"hits": hits.hits, "expected": expected.size()})
		for k in range(mini(hits.hits.size(), expected.size())):
			var h: Dictionary = hits.hits[k]
			var c: Dictionary = expected[k]
			_check("oracle_crossing_match_%s" % c.crossing_id, h.channel_id == c.channel_id and Vector2(h.x - c.r5_x_cm / 100.0, h.z - c.r5_z_cm / 100.0).length() <= Policy.CROSSING_MAX_DISPLACEMENT_M + 0.05,
				[h, c.r5_x_cm, c.r5_z_cm])
		var decks: Array = []
		for c: Dictionary in expected:
			if c.support == "BRIDGE_DECK":
				decks.append([c.deck_span_m[0] - 1.0, c.deck_span_m[1] + 1.0])
		var barrier: Dictionary = Oracle.barrier_samples(path, up.ride, ox, oz, 8.0, decks)
		_check("oracle_barrier_%d" % record.edge_id, barrier.blocked == 0, barrier)
		for f: Dictionary in record.features:
			if f.status == Policy.REALIZED and f.kind in ["SWEEP", "SWITCHBACK"]:
				var turn: float = Oracle.heading_change(path, f.measured.s0, f.measured.s1)
				_check("oracle_feature_%d_%s_%.0f" % [record.edge_id, f.kind, f.s0], signf(turn) == f.envelope.sign and absf(turn) >= f.envelope.min_turn_deg - 1.0, [turn, f.envelope])
	# Seams at every READY movement with READY edges (oracle on exports).
	for j: Dictionary in data.junctions:
		for m: Dictionary in j.movements:
			if m.status != Policy.MOVEMENT_READY:
				continue
			var connector: RefCounted = plan.get_path(m.piece_id).path
			for q in range(2):
				var edge_id: int = m.edges[q]
				var record: Dictionary = data.edges[edge_id]
				if record.status != "READY":
					continue
				var at_start: bool = record.a == j.node_id
				if q == 0:
					# Edge arrives at the node, then the connector.
					var arrive: RefCounted = plan.get_path(record.piece_id, at_start).path
					var seam: Dictionary = Oracle.seam(arrive, connector)
					_check("oracle_seam_%s_in" % m.piece_id, Oracle.seam_ok(seam), seam)
				else:
					var leave: RefCounted = plan.get_path(record.piece_id, not at_start).path
					var seam: Dictionary = Oracle.seam(connector, leave)
					_check("oracle_seam_%s_out" % m.piece_id, Oracle.seam_ok(seam), seam)
	# R5 DEBT-3 recertification (observational record + R6 final geometry
	# never sits on a natural barrier, asserted above).
	var recert: Dictionary = Oracle.r5_recertify(graph, up.ride, up.hydrology)
	_report["r5_recertification"] = recert.totals
	# R5 contract (builder certification): excessive slope on the reference is
	# flagged STEEP_PINCH; deep water on it is a recorded crossing. Discrepancy
	# = lost R5 certification (independent of the builder's own audit).
	_check("r5_recert_steep_flagged", recert.totals.steep_unflagged == 0, recert.totals)
	_check("r5_recert_deep_water_recorded", recert.totals.deep_water_unrecorded == 0, recert.totals)
	# Search-budget negative on the same region.
	var budget: Dictionary = Synth.synthesize(up.plan, up.terrain, up.hydrology, graph, {"max_natural_queries": 10000})
	var budget_seen: bool = false
	if budget.plan != null:
		for record: Dictionary in budget.plan.get_data().edges:
			budget_seen = budget_seen or "ERR_R6_SEARCH_BUDGET" in record.reasons
	_check("neg_search_budget", budget.status == "PARTIAL" and budget_seen, [budget.status, budget.reason_code])
	_report["outcome_counts"] = {"edges_ready": data.edges.filter(func(r: Dictionary) -> bool: return r.status == "READY").size(), "edges": data.edges.size(), "pieces": ids.size()}
