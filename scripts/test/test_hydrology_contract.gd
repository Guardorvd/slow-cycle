extends SceneTree

## R3 hydrology contract suite (headless, E1/E2): DrainageRouting,
## HydrologyGenerator / HydrologyPlan, HydrologyField, HydrologySurface and
## the renderer's acceptance of the surface. Durable topology, monotonicity,
## terrain association, determinism and numerical contracts only - geographic
## credibility is judged from maps and captures, not asserted here.
## Checks are aggregated per fixture so the fixed count does not depend on
## how many channels a seed produces; labels name the first offending item.

const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Generator = preload("res://scripts/world/region/region_generator.gd")
const RegionPlanScript = preload("res://scripts/world/region/region_plan.gd")
const Bounds = preload("res://scripts/world/region/region_bounds.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const Renderer = preload("res://scripts/world/region/terrain_tile_renderer.gd")
const Routing = preload("res://scripts/world/region/drainage_routing.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const HSurface = preload("res://scripts/world/region/hydrology_surface.gd")
const I64MIN: int = -9223372036854775808
const I32MAX: int = 2147483647
const I32MIN: int = -2147483648
const ROWS: Array = [[184729, 0, 0], [42, 0, 0], [77777, 0, 0], [3, 0, 0], [2024, 0, 0], [184729, -1, -1], [I64MIN, I32MAX, I32MIN]]
const DIVERSITY_EXTRA: Array[int] = [1, 2, 99, 7, 11, 555]
const OWN_CHECKS: int = 299
const SPIKE_PER_M: float = 5.0
const FLOAT_ABOVE_GROUND_M: float = 3.0

var checks: int = 0
var failures: int = 0
var _plans: Array = []
var _fields: Array = []
var _hydro: Array = []
var _hfields: Array = []
var _surfaces: Array = []
var _data: Array = []


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("HYDRO_CONTRACT_FAIL " + label)


func _init() -> void:
	for path: String in ["scripts/world/region/drainage_routing.gd", "scripts/world/region/hydrology_generator.gd", "scripts/world/region/hydrology_plan.gd", "scripts/world/region/hydrology_field.gd", "scripts/world/region/hydrology_surface.gd", "scripts/world/region/terrain_tile_renderer.gd", "scripts/world/region_preview.gd", "scenes/world/region_preview.tscn"]:
		_check(load("res://" + path) != null, "E0 explicit resource load " + path)
	for row: Array in ROWS:
		var start: int = Time.get_ticks_msec()
		var plan: RefCounted = Generator.build(row[0], Vector2i(row[1], row[2]))
		var field: RefCounted = Field.create(plan).field if plan != null else null
		var built: Dictionary = HGen.build(plan, field)
		var generation_ms: int = Time.get_ticks_msec() - start
		_check(built.is_valid and built.plan is Hydro and built.reason_code == "", "fixture hydrology w=%d c=%d,%d %s %s" % [row[0], row[1], row[2], built.reason_code, built.get("detail", "")])
		if not built.is_valid:
			print("HYDRO_CONTRACT_SUMMARY construction_aborted=true checks=%d failures=%d" % [checks, failures])
			quit(1)
			return
		var hfield: RefCounted = HField.create(built.plan, field).field
		var surface: RefCounted = HSurface.create(field, hfield).surface
		_plans.append(plan)
		_fields.append(field)
		_hydro.append(built.plan)
		_hfields.append(hfield)
		_surfaces.append(surface)
		_data.append(built.plan.get_data())
		print("HYDRO_FIXTURE w=%d x=%d z=%d region_signature=%s hydrology_signature=%s channels=%d bodies=%d" % [row[0], row[1], row[2], plan.signature(), built.plan.signature(), built.plan.get_channel_count(), built.plan.get_body_count()])
		printerr("HYDRO_FIXTURE_TIME w=%d generation_ms=%d" % [row[0], generation_ms])
	for group: Callable in [_h1, _h2, _h3, _h4, _h5, _h6, _h7, _h8, _h9, _h10, _h11, _h12]:
		var before: int = checks
		var failed_before: int = failures
		var start: int = Time.get_ticks_msec()
		group.call()
		print("HYDRO_GROUP name=%s checks=%d failures=%d" % [group.get_method(), checks - before, failures - failed_before])
		printerr("HYDRO_GROUP_TIME name=%s ms=%d" % [group.get_method(), Time.get_ticks_msec() - start])
	_check(checks + 1 == OWN_CHECKS, "fixed own check count %d" % (checks + 1))
	print("HYDRO_CONTRACT_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _local(data: Dictionary, x: float, z: float) -> Vector2:
	return Vector2(x - data.origin_x_m, z - data.origin_z_m)


## World coordinates as float64 scalars [x, z] (Vector2 is float32 and loses
## metres at the extreme-region fixture).
func _world(data: Dictionary, x_cm: int, z_cm: int) -> Array:
	return [data.origin_x_m + x_cm / 100.0, data.origin_z_m + z_cm / 100.0]


func _cell_world(data: Dictionary, cell: int) -> Array:
	return [data.origin_x_m + (cell % Hydro.LATTICE_SIZE) * 32.0, data.origin_z_m + (cell / Hydro.LATTICE_SIZE) * 32.0]


func _children(data: Dictionary) -> Array:
	var children: Array = []
	for channel: Dictionary in data.channels:
		children.append([])
	for channel: Dictionary in data.channels:
		if channel.parent >= 0:
			children[channel.parent].append(channel.id)
	return children


# H1 — purity, dependency direction and API surface.
func _h1() -> void:
	_check(Hydro.SCHEMA_TAG == "slow_cycle.hydrology/1" and HSurface.SCHEMA_TAG == "slow_cycle.hydrology_surface/1" and HField.SCHEMA_TAG == "slow_cycle.hydrology_field/1", "H1 schema tags")
	_check(Hydro.LATTICE_STEP_M == 32 and Hydro.LATTICE_SIZE == 129 and Hydro.MAX_DEFORMATION_M == 15.0 and Hydro.LATTICE_STEP_M == 2 * Field.LATTICE_STEP_M, "H1 lattice and deformation constants")
	_check(Hydro.MAJOR_WIDTH_CM == Vector2i(1200, 6000) and Hydro.CHANNEL_WIDTH_CM == Vector2i(100, 800), "H1 width ranges")
	for script: Script in [Routing, HGen, Hydro, HField, HSurface]:
		_check(script.get_instance_base_type() == "RefCounted", "H1 RefCounted " + script.resource_path)
		var bad: String = ""
		for token: String in ["get_tree", "Node3D", "MeshInstance", "RenderingServer", "add_child", "randomize(", "randi()", "randf()", "Time.", "MountainMassifField", "macro_terrain_evaluator", "MacroTerrainEvaluator", "OS."]:
			if token in script.source_code:
				bad = token
		_check(bad.is_empty(), "H1 %s free of scene/RNG/time/kernel tokens %s" % [script.resource_path, bad])
	var renderer: String = FileAccess.get_file_as_string("res://scripts/world/region/terrain_tile_renderer.gd")
	var preview: String = FileAccess.get_file_as_string("res://scripts/world/region_preview.gd")
	_check(not "hydrology_generator" in renderer and not "drainage_routing" in renderer and not "hydrology_field" in renderer and "hydrology_surface.gd" in renderer, "H1 renderer reads the surface only")
	for token: String in ["drainage_routing", "floodplain_delta", "deformation_local", "get_data", "frame_values"]:
		_check(not token in preview, "H1 preview computes no hydrology: " + token)
	var surface_source: String = FileAccess.get_file_as_string("res://scripts/world/region/hydrology_surface.gd")
	_check(not "hydrology_generator" in surface_source and not "get_data" in surface_source and "gradient_from_samples" in surface_source and "normal_from_gradient" in surface_source, "H1 surface composes field + hydrology field with the shared stencil")
	var field_source: String = FileAccess.get_file_as_string("res://scripts/world/region/hydrology_field.gd")
	_check(not "hydrology_generator" in field_source and not "drainage_routing" in field_source, "H1 field is a view: no generator/routing")
	_check(Seeds.PURPOSE_HYDROLOGY == "hydrology" and not Seeds.PURPOSE_HYDROLOGY in [Seeds.PURPOSE_REGION_SEED, Seeds.PURPOSE_MACRO_STRUCTURE, Seeds.PURPOSE_MACRO_NOISE], "H1 registered hydrology purpose")
	_check(Seeds.hydrology_seed_preimage(12345) == "slow_cycle.seed/1\npurpose=hydrology\ncount=1\nv0=12345\n", "H1 literal hydrology preimage")
	var region_seed: int = _plans[0].get_identity().get_region_seed()
	var hydrology_seed: int = Seeds.hydrology_seed(region_seed)
	_check(hydrology_seed == _data[0].hydrology_seed and hydrology_seed >= 0 and hydrology_seed != Seeds.macro_structure_seed(region_seed) and hydrology_seed != Seeds.macro_noise_seed(region_seed), "H1 hydrology seed derived and distinct")
	for method: String in ["sample_water", "sample_proximity", "sample_drainage", "sample_deformation", "deformation_local", "get_bounds_m", "get_region_signature", "get_plan_signature"]:
		_check(_hfields[0].has_method(method), "H1 field has " + method)
	for method: String in ["sample_height", "sample_gradient", "sample_normal", "sample_lattice", "get_bounds_m", "get_region_signature"]:
		_check(_surfaces[0].has_method(method), "H1 surface has " + method)
	_check(not _plans[0].has_method("get_hydrology") and not _fields[0].has_method("sample_water"), "H1 hydrology is a separate product (RegionPlan / TerrainField unchanged)")


# H2 — creation and input negatives with exact reasons.
func _h2() -> void:
	var plan: RefCounted = _plans[0]
	var field: RefCounted = _fields[0]
	var foreign: RefCounted = _fields[1]
	_check(HGen.build(null, field).reason_code == "ERR_HYDRO_INPUT_MISSING", "H2 build null plan")
	_check(HGen.build(plan, null).reason_code == "ERR_HYDRO_INPUT_MISSING", "H2 build null field")
	_check(HGen.build(field, plan).reason_code == "ERR_HYDRO_INPUT_MISSING", "H2 build swapped inputs")
	_check(HGen.build(plan, foreign).reason_code == "ERR_HYDRO_INPUT_INVALID", "H2 build foreign-region field")
	var tampered: RefCounted = RegionPlanScript.new(plan.get_identity(), Bounds.new(Vector2i(1, 0)), plan.get_macro_terrain())
	_check(HGen.build(tampered, field).reason_code == "ERR_HYDRO_INPUT_INVALID" and HGen.build(tampered, field).plan == null, "H2 build tampered region plan")
	_check(HField.create(null, field).reason_code == "ERR_HYDRO_PLAN_MISSING" and HField.create(_hydro[0], null).reason_code == "ERR_HYDRO_PLAN_MISSING", "H2 field missing inputs")
	_check(HField.create(_hydro[0], foreign).reason_code == "ERR_HYDRO_TERRAIN_MISMATCH", "H2 field foreign terrain")
	var broken: Dictionary = _data[0].duplicate(true)
	broken.erase("channels")
	_check(HField.create(Hydro.new(broken), field).reason_code == "ERR_HYDRO_PLAN_INVALID", "H2 field invalid plan")
	_check(HSurface.create(null, _hfields[0]).reason_code == "ERR_HYDRO_SURFACE_INPUT_MISSING" and HSurface.create(field, null).reason_code == "ERR_HYDRO_SURFACE_INPUT_MISSING" and HSurface.create(field, field).reason_code == "ERR_HYDRO_SURFACE_INPUT_MISSING", "H2 surface missing inputs")
	_check(HSurface.create(foreign, _hfields[0]).reason_code == "ERR_HYDRO_TERRAIN_MISMATCH", "H2 surface foreign terrain")
	var b: Dictionary = field.get_bounds_m()
	var hf: RefCounted = _hfields[0]
	var calls: Array = ["sample_water", "sample_proximity", "sample_drainage", "sample_deformation"]
	for call: String in calls:
		var ok: bool = true
		for p: Vector2 in [Vector2(NAN, 0), Vector2(0, INF), Vector2(-INF, 0)]:
			var r: Dictionary = hf.call(call, b.min_x + p.x, b.min_z + p.y)
			ok = ok and not r.is_valid and r.reason_code == "ERR_HYDRO_NONFINITE_INPUT"
		for p: Vector2 in [Vector2(b.max_x + 0.001, b.min_z), Vector2(b.min_x - 0.001, b.min_z), Vector2(b.min_x, b.max_z + 0.001)]:
			var r: Dictionary = hf.call(call, p.x, p.y)
			ok = ok and not r.is_valid and r.reason_code == "ERR_HYDRO_OUT_OF_DOMAIN"
		for p: Vector2 in [Vector2(b.min_x, b.min_z), Vector2(b.max_x, b.max_z), Vector2(b.min_x, b.max_z)]:
			ok = ok and hf.call(call, p.x, p.y).is_valid
		_check(ok, "H2 %s domain reasons and closed edges" % call)
	var surface: RefCounted = _surfaces[0]
	for call: String in ["sample_height", "sample_gradient", "sample_normal"]:
		var r1: Dictionary = surface.call(call, NAN, 0.0)
		var r2: Dictionary = surface.call(call, b.max_x + 0.001, b.min_z)
		_check(not r1.is_valid and r1.reason_code == "ERR_TERRAIN_NONFINITE_INPUT" and not r2.is_valid and r2.reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN" and surface.call(call, b.max_x, b.max_z).is_valid, "H2 surface %s reasons" % call)
	_check(surface.sample_lattice(b.min_x / 16, b.min_z / 16, 0, 3).reason_code == "ERR_TERRAIN_GRID_SHAPE" and surface.sample_lattice(b.min_x / 16 + 250, b.min_z / 16, 8, 1).reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN" and surface.sample_lattice(b.min_x / 16 - 1, b.min_z / 16, 1, 1).reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN", "H2 surface lattice reasons")
	_check(Renderer.tile_arrays(surface, b.min_x / 512 + 8, b.min_z / 512).reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN" and Renderer.tile_arrays(hf, b.min_x / 512, b.min_z / 512).reason_code == "ERR_TILE_FIELD_MISSING", "H2 renderer reasons with surface / non-surface")


# H3 — determinism and independence from global RNG and build order.
func _h3() -> void:
	var rebuilt: Array = []
	for index: int in [1, 0]:
		var plan: RefCounted = Generator.build(ROWS[index][0], Vector2i(ROWS[index][1], ROWS[index][2]))
		rebuilt.append(HGen.build(plan, Field.create(plan).field).plan.signature())
	_check(rebuilt[0] == _hydro[1].signature() and rebuilt[1] == _hydro[0].signature(), "H3 independent rebuild in reverse order")
	seed(777)
	var expected: int = randi()
	seed(777)
	var plan_a: RefCounted = Generator.build(ROWS[0][0], Vector2i.ZERO)
	var again: RefCounted = HGen.build(plan_a, _fields[0]).plan
	_check(randi() == expected, "H3 global RNG not consumed")
	randomize()
	_check(again.signature() == _hydro[0].signature() and HGen.build(plan_a, Field.create(plan_a).field).plan.signature() == _hydro[0].signature(), "H3 unaffected by global seed / randomize and by field instance")
	var distinct: bool = true
	for i in range(_hydro.size()):
		for j in range(i + 1, _hydro.size()):
			distinct = distinct and _hydro[i].signature() != _hydro[j].signature()
	_check(distinct, "H3 distinct regions differ")
	_check(Hydro.new(_data[0]).signature() == _hydro[0].signature() and _hydro[0].canonical_text().begins_with("slow_cycle.hydrology/1\nstate=GENERATED_R3\n"), "H3 canonical text round trip")
	var copy: Dictionary = _hydro[0].get_data()
	copy.channels[0].surface_cm[0] = 0
	_check(_hydro[0].get_data().channels[0].surface_cm[0] != 0 or _data[0].channels[0].surface_cm[0] == 0, "H3 plan immutable through get_data")
	var second: RefCounted = HField.create(_hydro[0], Field.create(_plans[0]).field).field
	var b: Dictionary = _fields[0].get_bounds_m()
	var same: bool = true
	for k in range(40):
		var x: float = b.min_x + fposmod(k * 977.31, 4096.0)
		var z: float = b.min_z + fposmod(k * 613.7 + 50.0, 4096.0)
		same = same and second.sample_deformation(x, z).delta_m == _hfields[0].sample_deformation(x, z).delta_m and str(second.sample_water(x, z)) == str(_hfields[0].sample_water(x, z))
	_check(same, "H3 independent field instances agree")


# H4 — topology and hierarchy.
func _h4() -> void:
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		var validation: Dictionary = _hydro[f].validate()
		_check(validation.is_valid and validation.reason_codes.is_empty(), "H4 validate w=%d %s" % [ROWS[f][0], str(validation.reason_codes)])
		var majors: int = 0
		for channel: Dictionary in data.channels:
			majors += 1 if channel.class == Hydro.CLASS_MAJOR_RIVER else 0
		var river: Dictionary = data.channels[0]
		var last: int = river.x_cm.size() - 1
		var start_u: float = Macro.local_to_frame(data.frame_symmetry, river.x_cm[0] / 100.0, river.z_cm[0] / 100.0).x
		var end_u: float = Macro.local_to_frame(data.frame_symmetry, river.x_cm[last] / 100.0, river.z_cm[last] / 100.0).x
		_check(majors == 1 and river.class == Hydro.CLASS_MAJOR_RIVER and river.parent == -1 and river.outlet_kind == Hydro.OUTLET_EDGE, "H4 one major river w=%d" % ROWS[f][0])
		_check(absf(start_u) <= 0.02 and absf(end_u - 4096.0) <= 0.02 and river.surface_cm[0] > river.surface_cm[last], "H4 river edge to edge along the valley's downstream +u w=%d" % ROWS[f][0])
		var children: Array = _children(data)
		var forest: String = ""
		var hierarchy: String = ""
		var mouths: String = ""
		for channel: Dictionary in data.channels:
			var c: int = channel.id
			if channel.parent >= 0:
				if channel.parent >= c or channel.outlet_kind != Hydro.OUTLET_CHANNEL or channel.outlet_id != channel.parent:
					forest = "channel %d" % c
				var parent: Dictionary = data.channels[channel.parent]
				var at: Dictionary = Hydro.point_at_station(parent, channel.mouth_station_cm)
				var n: int = channel.x_cm.size() - 1
				if Vector2(at.x - channel.x_cm[n], at.z - channel.z_cm[n]).length() > 2.0:
					mouths = "channel %d" % c
				if channel.area_m2[n] > at.area + 1.0 or (parent.class != Hydro.CLASS_MAJOR_RIVER and channel.order > parent.order):
					hierarchy = "channel %d vs parent" % c
			elif c != 0 and not (channel.outlet_kind == Hydro.OUTLET_EDGE or (channel.outlet_kind == Hydro.OUTLET_BODY and data.bodies[channel.outlet_id].kind == Hydro.BODY_CLOSED)):
				forest = "root %d" % c
			for k in range(1, channel.area_m2.size()):
				if channel.area_m2[k] < channel.area_m2[k - 1]:
					hierarchy = "area decreases on %d" % c
			if c != 0 and channel.area_m2[channel.area_m2.size() - 1] >= river.area_m2[0]:
				hierarchy = "channel %d exceeds the major river" % c
			if c != 0 and children[c].is_empty() and channel.order != 1:
				hierarchy = "leaf %d order %d" % [c, channel.order]
			if c != 0 and channel.class == Hydro.CLASS_MAJOR_RIVER:
				hierarchy = "second major %d" % c
		var river_child_order: int = 0
		for child: int in children[0]:
			river_child_order = maxi(river_child_order, data.channels[child].order)
		_check(forest.is_empty(), "H4 forest: parents precede children, roots end at an edge or closed body w=%d %s" % [ROWS[f][0], forest])
		_check(mouths.is_empty(), "H4 every mouth lies on its parent w=%d %s" % [ROWS[f][0], mouths])
		_check(hierarchy.is_empty() and river.order > river_child_order, "H4 hierarchy: area grows downstream, tributary <= parent, leaves order 1, river dominant w=%d %s" % [ROWS[f][0], hierarchy])
		_check(children[0].size() >= 1, "H4 the major river has tributaries w=%d" % ROWS[f][0])


# H5 — hydraulic monotonicity and channel dimensions.
func _h5() -> void:
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		var surfaces: String = ""
		var beds: String = ""
		var confluence: String = ""
		var widths: String = ""
		for channel: Dictionary in data.channels:
			var range_cm: Vector2i = Hydro.MAJOR_WIDTH_CM if channel.class == Hydro.CLASS_MAJOR_RIVER else Hydro.CHANNEL_WIDTH_CM
			for k in range(channel.surface_cm.size()):
				if channel.bed_cm[k] >= channel.surface_cm[k]:
					beds = "channel %d vertex %d" % [channel.id, k]
				if k > 0 and channel.surface_cm[k] >= channel.surface_cm[k - 1]:
					surfaces = "channel %d vertex %d" % [channel.id, k]
				if channel.width_cm[k] < range_cm.x or channel.width_cm[k] > range_cm.y or (k > 0 and channel.width_cm[k] < channel.width_cm[k - 1]):
					widths = "channel %d vertex %d" % [channel.id, k]
			if channel.parent >= 0:
				var at: Dictionary = Hydro.point_at_station(data.channels[channel.parent], channel.mouth_station_cm)
				if channel.surface_cm[channel.surface_cm.size() - 1] < at.surface - 1.0:
					confluence = "channel %d" % channel.id
		_check(surfaces.is_empty(), "H5 water surface strictly decreasing downstream w=%d %s" % [ROWS[f][0], surfaces])
		_check(beds.is_empty(), "H5 bed below water surface w=%d %s" % [ROWS[f][0], beds])
		_check(confluence.is_empty(), "H5 mouth not below the receiving water w=%d %s" % [ROWS[f][0], confluence])
		_check(widths.is_empty(), "H5 widths in class range and non-decreasing w=%d %s" % [ROWS[f][0], widths])


# H6 — association with the R1 valley and the base terrain.
func _h6() -> void:
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		var macro: Dictionary = _plans[f].get_macro_terrain().get_data()
		var field: RefCounted = _fields[f]
		var river: Dictionary = data.channels[0]
		var inside: String = ""
		var near_ground: float = 0.0
		for k in range(river.x_cm.size()):
			var frame: Vector2 = Macro.local_to_frame(data.frame_symmetry, river.x_cm[k] / 100.0, river.z_cm[k] / 100.0)
			var axis: float = Macro.valley_axis(macro, frame.x).x
			var half: Vector2 = Macro.floor_half_widths(macro, frame.x)
			if frame.y < axis - half.y + 39.0 or frame.y > axis + half.x - 39.0:
				inside = "vertex %d" % k
			var w: Array = _world(data, river.x_cm[k], river.z_cm[k])
			near_ground = maxf(near_ground, absf(field.sample_height(w[0], w[1]).height_m - river.surface_cm[k] / 100.0))
		_check(inside.is_empty(), "H6 major river inside the R1 floor with a 40 m bank margin w=%d %s" % [ROWS[f][0], inside])
		_check(near_ground <= Hydro.MAX_DEFORMATION_M, "H6 river surface within the deformation bound of base terrain w=%d max=%.2f" % [ROWS[f][0], near_ground])
		var body_cells: Dictionary = {}
		for body: Dictionary in data.bodies:
			for cell: int in body.cells:
				body_cells[cell] = true
		var buried: float = 0.0
		var floating: float = 0.0
		for channel: Dictionary in data.channels:
			if channel.class == Hydro.CLASS_MAJOR_RIVER:
				continue
			for k in range(channel.x_cm.size()):
				var cell: int = roundi(channel.z_cm[k] / 3200.0) * Hydro.LATTICE_SIZE + roundi(channel.x_cm[k] / 3200.0)
				var w: Array = _world(data, channel.x_cm[k], channel.z_cm[k])
				var base: float = field.sample_height(w[0], w[1]).height_m
				buried = maxf(buried, base - channel.surface_cm[k] / 100.0)
				# Perching is judged against the ground the water flows on: base
				# terrain plus the hydrology deformation (floodplain shaping).
				if not body_cells.has(cell) and k < channel.x_cm.size() - 1:
					floating = maxf(floating, channel.surface_cm[k] / 100.0 - _surfaces[f].sample_height(w[0], w[1]).height_m)
		_check(buried <= Hydro.MAX_DEFORMATION_M, "H6 channels follow the terrain: base - surface <= bound w=%d max=%.2f" % [ROWS[f][0], buried])
		_check(floating <= FLOAT_ABOVE_GROUND_M, "H6 channel water not perched above the hydrology-shaped ground outside bodies w=%d max=%.2f" % [ROWS[f][0], floating])
		# Every lattice point ends at the major river, a region-edge point or a CLOSED body.
		var receiver: PackedInt32Array = data.lattice.receiver
		var terminal: PackedByteArray = data.lattice.terminal
		var closed_cells: Dictionary = {}
		for body: Dictionary in data.bodies:
			if body.kind == Hydro.BODY_CLOSED:
				for cell: int in body.cells:
					closed_cells[cell] = true
		var orphan: String = ""
		var counts: Array = [0, 0, 0, 0]
		for start in range(receiver.size()):
			var c: int = start
			var steps: int = 0
			while receiver[c] >= 0 and steps <= receiver.size():
				c = receiver[c]
				steps += 1
			var kind: int = terminal[c]
			counts[kind] += 1
			var i: int = c % Hydro.LATTICE_SIZE
			var j: int = c / Hydro.LATTICE_SIZE
			var edge: bool = i == 0 or j == 0 or i == Hydro.LATTICE_SIZE - 1 or j == Hydro.LATTICE_SIZE - 1
			if kind == Hydro.TERMINAL_NONE or (kind == Hydro.TERMINAL_EDGE and not edge) or (kind == Hydro.TERMINAL_CLOSED and not closed_cells.has(c)):
				orphan = "lattice %d" % start
		_check(orphan.is_empty() and counts[Hydro.TERMINAL_RIVER] > 0, "H6 every point drains to river / edge / recorded CLOSED body w=%d %s shares=%s" % [ROWS[f][0], orphan, str(counts)])
		var outlets: String = ""
		for body: Dictionary in data.bodies:
			var ok: bool
			if body.kind == Hydro.BODY_CLOSED:
				ok = body.outlet_kind == Hydro.OUTLET_BODY and body.outlet_id == -1
			else:
				ok = (body.outlet_kind == Hydro.OUTLET_CHANNEL and body.outlet_id >= 0 and body.outlet_id < data.channels.size()) or (body.outlet_kind == Hydro.OUTLET_EDGE) or (body.outlet_kind == Hydro.OUTLET_BODY and body.outlet_id >= 0 and data.bodies[body.outlet_id].kind == Hydro.BODY_CLOSED)
			if not ok:
				outlets = "body %d" % body.id
		_check(outlets.is_empty(), "H6 ponds have a recorded outlet, closed bodies are terminal w=%d %s" % [ROWS[f][0], outlets])


# H7 — domain and numerical safety of geometry and deformation.
func _h7() -> void:
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		var hf: RefCounted = _hfields[f]
		var b: Dictionary = _fields[f].get_bounds_m()
		var frame_m: Array = Hydro.frame_arrays_m(data.river_frame)
		var bounded: bool = true
		var zero_outside: String = ""
		var nonzero: int = 0
		for j in range(0, 4097, 64):
			for i in range(0, 4097, 64):
				var delta: float = hf.sample_deformation(b.min_x + i, b.min_z + j).delta_m
				bounded = bounded and is_finite(delta) and absf(delta) <= Hydro.MAX_DEFORMATION_M
				nonzero += 1 if delta != 0.0 else 0
				var values: Array = Hydro.frame_values(data.frame_symmetry, frame_m, float(i), float(j))
				var outside: float = maxf(values[0] - values[2], values[3] - values[0])
				if outside > Hydro.FLOODPLAIN_FADE_M and hf.sample_proximity(b.min_x + i, b.min_z + j).distance_to_water_m > HField.RIVER_REACH_M + 1.0 and delta != 0.0:
					zero_outside = "(%d,%d)=%.3f" % [i, j, delta]
		_check(bounded, "H7 deformation finite and |delta| <= bound w=%d" % ROWS[f][0])
		_check(zero_outside.is_empty() and nonzero > 0, "H7 deformation exactly 0 outside floor margin and channel corridors w=%d %s nonzero=%d" % [ROWS[f][0], zero_outside, nonzero])
		# 1 m transects across the river and across creeks: no step spike.
		var worst: float = 0.0
		var transects: Array = []
		var river: Dictionary = data.channels[0]
		for k in [16, 80, 128, 176, 240]:
			transects.append([river, k])
		for channel: Dictionary in data.channels.slice(1, mini(7, data.channels.size())):
			transects.append([channel, channel.x_cm.size() / 2])
		for t: Array in transects:
			var channel: Dictionary = t[0]
			var k: int = t[1]
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var q := Vector2(channel.x_cm[mini(k + 1, channel.x_cm.size() - 1)], channel.z_cm[mini(k + 1, channel.x_cm.size() - 1)]) / 100.0
			if q == p:
				q = Vector2(channel.x_cm[k - 1], channel.z_cm[k - 1]) / 100.0
			var side: Vector2 = (q - p).normalized().orthogonal()
			var previous: float = NAN
			for s in range(-150, 151):
				var point: Vector2 = p + side * s
				if point.x < 0.0 or point.y < 0.0 or point.x > 4096.0 or point.y > 4096.0:
					previous = NAN
					continue
				var delta: float = hf.sample_deformation(b.min_x + point.x, b.min_z + point.y).delta_m
				if not is_nan(previous):
					worst = maxf(worst, absf(delta - previous))
				previous = delta
		_check(worst <= SPIKE_PER_M, "H7 deformation continuous on 1 m transects w=%d max step=%.3f" % [ROWS[f][0], worst])
		var inside: bool = true
		for channel: Dictionary in data.channels:
			for k in range(channel.x_cm.size()):
				inside = inside and channel.x_cm[k] >= 0 and channel.x_cm[k] <= Hydro.DOMAIN_CM and channel.z_cm[k] >= 0 and channel.z_cm[k] <= Hydro.DOMAIN_CM
		_check(inside, "H7 all channel geometry inside the closed region w=%d" % ROWS[f][0])


# H8 — field queries agree with the plan.
func _h8() -> void:
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		var hf: RefCounted = _hfields[f]
		var river: Dictionary = data.channels[0]
		var on_river: String = ""
		for k in range(8, river.x_cm.size() - 8, 16):
			var w: Array = _world(data, river.x_cm[k], river.z_cm[k])
			var water: Dictionary = hf.sample_water(w[0], w[1])
			var near: Dictionary = hf.sample_proximity(w[0], w[1])
			if not water.is_water or water.kind != "MAJOR_RIVER" or water.id != 0 or absf(water.water_surface_m - river.surface_cm[k] / 100.0) > 0.011 or water.depth_m <= 0.0 or near.distance_to_major_m != 0.0 or not near.in_floodplain:
				on_river = "vertex %d %s" % [k, str(water)]
		_check(on_river.is_empty(), "H8 river centre line is water at the plan surface, in the floodplain, distance 0 w=%d %s" % [ROWS[f][0], on_river])
		var on_channels: bool = true
		for channel: Dictionary in data.channels:
			var k: int = channel.x_cm.size() / 2
			var w: Array = _world(data, channel.x_cm[k], channel.z_cm[k])
			on_channels = on_channels and hf.sample_proximity(w[0], w[1]).distance_to_water_m == 0.0
		_check(on_channels, "H8 every channel's mid vertex is at distance 0 w=%d" % ROWS[f][0])
		var drainage: String = ""
		for cell in range(0, Hydro.LATTICE_SIZE * Hydro.LATTICE_SIZE, 97):
			var w: Array = _cell_world(data, cell)
			var d: Dictionary = hf.sample_drainage(w[0], w[1])
			if d.area_m2 != data.lattice.area_cells[cell] * 1024.0 or d.catchment_id != data.lattice.catchment[cell] or not d.terminal_kind in ["MAJOR_RIVER", "EDGE", "CLOSED"]:
				drainage = "cell %d" % cell
		_check(drainage.is_empty(), "H8 drainage query matches the lattice w=%d %s" % [ROWS[f][0], drainage])
		var dry: bool = true
		var b: Dictionary = _fields[f].get_bounds_m()
		for k in range(60):
			var x: float = b.min_x + fposmod(k * 1543.7, 4096.0)
			var z: float = b.min_z + fposmod(k * 911.3 + 7.0, 4096.0)
			var near: Dictionary = hf.sample_proximity(x, z)
			if near.distance_to_water_m > 200.0:
				dry = dry and not hf.sample_water(x, z).is_water and near.distance_to_major_m >= near.distance_to_water_m
		_check(dry, "H8 points far from water are dry w=%d" % ROWS[f][0])
	# A closed body is water at its lowest cell; a pond at its deepest cell.
	var found: Array = [false, false]
	var correct: Array = [true, true]
	for f in range(_hydro.size()):
		var data: Dictionary = _data[f]
		for body: Dictionary in data.bodies:
			var lowest: int = body.cells[0]
			var lowest_h: float = INF
			for cell: int in body.cells:
				var w: Array = _cell_world(data, cell)
				var h: float = _surfaces[f].sample_height(w[0], w[1]).height_m
				if h < lowest_h:
					lowest_h = h
					lowest = cell
			if lowest_h >= body.level_cm / 100.0:
				continue
			var w: Array = _cell_world(data, lowest)
			var water: Dictionary = _hfields[f].sample_water(w[0], w[1])
			found[body.kind] = true
			correct[body.kind] = correct[body.kind] and water.is_water and water.kind == HField.BODY_NAMES[body.kind] and water.id == body.id and absf(water.water_surface_m - body.level_cm / 100.0) < 0.001
	_check(found[0] and correct[0], "H8 pond water at its lowest cell")
	_check(found[1] and correct[1], "H8 closed-body water at its lowest cell")


# H9 — the transitional surface: composition, stencil, lattice parity, seams.
func _h9() -> void:
	for f in [0, 3, 6]:
		var field: RefCounted = _fields[f]
		var surface: RefCounted = _surfaces[f]
		var hf: RefCounted = _hfields[f]
		var b: Dictionary = field.get_bounds_m()
		var composed: bool = true
		var stencil: bool = true
		var points: Array = [Vector2(0, 0), Vector2(4096, 4096), Vector2(0, 4088.5), Vector2(4092.75, 2049.0)]
		var river: Dictionary = _data[f].channels[0]
		for k in range(0, river.x_cm.size(), 32):
			points.append(Vector2(river.x_cm[k] / 100.0 + 5.5, river.z_cm[k] / 100.0 - 3.0))
		for k in range(20):
			points.append(Vector2(fposmod(k * 733.1, 4096.0), fposmod(k * 291.7, 4096.0)))
		for p: Vector2 in points:
			var x: float = b.min_x + clampf(p.x, 0.0, 4096.0)
			var z: float = b.min_z + clampf(p.y, 0.0, 4096.0)
			composed = composed and surface.sample_height(x, z).height_m == field.sample_height(x, z).height_m + hf.sample_deformation(x, z).delta_m
			var x0: float = maxf(b.min_x, x - 16.0)
			var x1: float = minf(b.max_x, x + 16.0)
			var z0: float = maxf(b.min_z, z - 16.0)
			var z1: float = minf(b.max_z, z + 16.0)
			var expected := Vector2((surface.sample_height(x1, z).height_m - surface.sample_height(x0, z).height_m) / (x1 - x0), (surface.sample_height(x, z1).height_m - surface.sample_height(x, z0).height_m) / (z1 - z0))
			var g: Vector2 = surface.sample_gradient(x, z).gradient
			var n: Vector3 = surface.sample_normal(x, z).normal
			stencil = stencil and g == expected and n == Vector3(-g.x, 1.0, -g.y).normalized() and n.is_normalized() and n.y > 0.0
		_check(composed, "H9 surface height == base + deformation w=%d" % ROWS[f][0])
		_check(stencil, "H9 surface gradient/normal by the shared stencil w=%d" % ROWS[f][0])
		var parity: bool = true
		# int64 lattice / tile indices (Vector2i is int32).
		var river_cell: Array = [river.x_cm[128] / 1600, river.z_cm[128] / 1600]
		var lattice_origin: Array = [[b.min_x / 16, b.min_z / 16], [b.max_x / 16 - 8, b.max_z / 16 - 8], [b.min_x / 16 + clampi(river_cell[0] - 4, 0, 248), b.min_z / 16 + clampi(river_cell[1] - 4, 0, 248)]]
		for o: Array in lattice_origin:
			var block: Dictionary = surface.sample_lattice(o[0], o[1], 9, 9)
			for k in range(81):
				var x: float = float((o[0] + k % 9) * 16)
				var z: float = float((o[1] + k / 9) * 16)
				parity = parity and block.heights_m[k] == surface.sample_height(x, z).height_m and block.gradients[k] == surface.sample_gradient(x, z).gradient and block.normals[k] == surface.sample_normal(x, z).normal
		_check(parity, "H9 surface lattice bit-identical to point queries w=%d" % ROWS[f][0])
		# Seams by construction for tiles over the river.
		var tile_x: int = b.min_x / 512 + clampi(river.x_cm[128] / 51200, 0, 6)
		var tile_z: int = b.min_z / 512 + clampi(river.z_cm[128] / 51200, 0, 6)
		var tiles: Dictionary = {}
		for offset: Vector2i in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 0)]:
			tiles[offset] = Renderer.tile_arrays(surface, tile_x + offset.x, tile_z + offset.y)
		var seams: bool = tiles[Vector2i(0, 0)].is_valid
		for k in range(33):
			var left: Dictionary = tiles[Vector2i(0, 0)]
			var right: Dictionary = tiles[Vector2i(1, 0)]
			var below: Dictionary = tiles[Vector2i(0, 1)]
			seams = seams and left.heights_m[k * 33 + 32] == right.heights_m[k * 33] and left.arrays[Mesh.ARRAY_NORMAL][k * 33 + 32] == right.arrays[Mesh.ARRAY_NORMAL][k * 33]
			seams = seams and left.heights_m[32 * 33 + k] == below.heights_m[k] and left.arrays[Mesh.ARRAY_NORMAL][32 * 33 + k] == below.arrays[Mesh.ARRAY_NORMAL][k]
		var other: RefCounted = HSurface.create(Field.create(_plans[f]).field, HField.create(_hydro[f], Field.create(_plans[f]).field).field).surface
		seams = seams and Renderer.tile_arrays(other, tile_x, tile_z).arrays == tiles[Vector2i(0, 0)].arrays
		_check(seams, "H9 surface tiles seamless by construction and identical from a second instance w=%d" % ROWS[f][0])
		var base_tile: Dictionary = Renderer.tile_arrays(field, tile_x, tile_z)
		var carved: bool = false
		for k in range(base_tile.heights_m.size() if base_tile.is_valid else 0):
			carved = carved or tiles[Vector2i(0, 0)].heights_m[k] != base_tile.heights_m[k]
		_check(carved, "H9 the surface differs from base terrain over the river tile w=%d" % ROWS[f][0])


# H10 — seed diversity (anti-template guard, not aesthetics).
func _h10() -> void:
	var plans: Array = []
	for f in range(5):
		plans.append(_data[f])
	for seed_value: int in DIVERSITY_EXTRA:
		var plan: RefCounted = Generator.build(seed_value, Vector2i.ZERO)
		plans.append(HGen.build(plan, Field.create(plan).field).plan.get_data())
	var signatures: Dictionary = {}
	var tributaries: Dictionary = {}
	var sinuosity: Dictionary = {}
	var channel_counts: Dictionary = {}
	var characters: Dictionary = {}
	var directions: Dictionary = {}
	for data: Dictionary in plans:
		signatures[Hydro.new(data).signature()] = true
		var river: Dictionary = data.channels[0]
		var count: int = 0
		for channel: Dictionary in data.channels:
			count += 1 if channel.parent == 0 else 0
		tributaries[count] = true
		sinuosity[roundi(100.0 * river.station_cm[river.station_cm.size() - 1] / Hydro.DOMAIN_CM)] = true
		channel_counts[data.channels.size()] = true
		characters[JSON.stringify(data.character)] = true
		var last: int = river.x_cm.size() - 1
		directions[Vector2i(signi(river.x_cm[last] - river.x_cm[0]), signi(river.z_cm[last] - river.z_cm[0]))] = true
	print("HYDRO_DIVERSITY tributary_counts=%s sinuosity_percent=%s channel_counts=%s directions=%d" % [str(tributaries.keys()), str(sinuosity.keys()), str(channel_counts.keys()), directions.size()])
	_check(signatures.size() == plans.size() and characters.size() == plans.size(), "H10 distinct hydrology per seed")
	_check(tributaries.size() >= 3, "H10 tributary count varies across seeds")
	_check(sinuosity.size() >= 3 and channel_counts.size() >= 3, "H10 river sinuosity and network size vary across seeds")
	_check(directions.size() >= 2, "H10 downstream direction varies with the region frame")


# H11 — validator and routing sensitivity: each fixture violates exactly one rule.
func _h11() -> void:
	var data: Dictionary = _data[0]
	var children: Array = _children(data)
	var leaf: int = -1
	var with_parent: int = -1
	for channel: Dictionary in data.channels:
		if channel.id > 0 and children[channel.id].is_empty() and channel.x_cm.size() >= 4 and leaf < 0:
			leaf = channel.id
		if channel.parent > 0 and with_parent < 0:
			with_parent = channel.id
	with_parent = with_parent if with_parent >= 0 else leaf
	_check(leaf > 0, "H11 fixture has a leaf channel")
	var cases: Array = []
	var schema: Dictionary = data.duplicate(true)
	schema.erase("channels")
	cases.append([schema, "ERR_HYDRO_SCHEMA"])
	var major: Dictionary = data.duplicate(true)
	var river: Dictionary = major.channels[0]
	if river.x_cm[0] == 0 or river.x_cm[0] == Hydro.DOMAIN_CM:
		river.x_cm[0] += 100 if river.x_cm[0] == 0 else -100
	else:
		river.z_cm[0] += 100 if river.z_cm[0] == 0 else -100
	cases.append([major, "ERR_HYDRO_MAJOR_RIVER"])
	var topology: Dictionary = data.duplicate(true)
	topology.channels[with_parent].parent = with_parent
	cases.append([topology, "ERR_HYDRO_TOPOLOGY"])
	var monotonic: Dictionary = data.duplicate(true)
	monotonic.channels[leaf].surface_cm[1] = monotonic.channels[leaf].surface_cm[0] + 100
	cases.append([monotonic, "ERR_HYDRO_MONOTONIC"])
	var flat_step: Dictionary = data.duplicate(true)
	flat_step.channels[leaf].surface_cm[1] = flat_step.channels[leaf].surface_cm[0]
	cases.append([flat_step, "ERR_HYDRO_MONOTONIC"])
	var hierarchy: Dictionary = data.duplicate(true)
	for k in range(hierarchy.channels[leaf].area_m2.size()):
		hierarchy.channels[leaf].area_m2[k] = data.channels[0].area_m2[0] + 1
	cases.append([hierarchy, "ERR_HYDRO_HIERARCHY"])
	var bounds: Dictionary = data.duplicate(true)
	for k in range(bounds.channels[leaf].width_cm.size()):
		bounds.channels[leaf].width_cm[k] = Hydro.CHANNEL_WIDTH_CM.y + 100
	cases.append([bounds, "ERR_HYDRO_BOUNDS"])
	# Zero-length segment: vertex k repeated at k + 1 with a surface 1 cm lower,
	# so only the geometry rule (strictly increasing stations) is violated.
	var geometry: Dictionary = data.duplicate(true)
	var g: Dictionary = geometry.channels[leaf]
	var gk: int = 0
	while gk < g.surface_cm.size() - 2 and g.surface_cm[gk] - g.surface_cm[gk + 1] < 2:
		gk += 1
	for key: String in Hydro.CHANNEL_ARRAYS:
		g[key].insert(gk + 1, g[key][gk])
	g.surface_cm[gk + 1] -= 1
	g.bed_cm[gk + 1] -= 1
	cases.append([geometry, "ERR_HYDRO_GEOMETRY"])
	# A leaf segment crossing the major river away from any mouth.
	var crossed: Dictionary = data.duplicate(true)
	var r0 := Vector2(data.channels[0].x_cm[128], data.channels[0].z_cm[128])
	var r1 := Vector2(data.channels[0].x_cm[129], data.channels[0].z_cm[129])
	var across: Vector2 = (r1 - r0).normalized().orthogonal() * 5000.0
	var middle: Vector2 = (r0 + r1) * 0.5
	crossed.channels[leaf].x_cm[1] = roundi(middle.x + across.x)
	crossed.channels[leaf].z_cm[1] = roundi(middle.y + across.y)
	crossed.channels[leaf].x_cm[2] = roundi(middle.x - across.x)
	crossed.channels[leaf].z_cm[2] = roundi(middle.y - across.y)
	cases.append([crossed, "ERR_HYDRO_GEOMETRY"])
	var drainage: Dictionary = data.duplicate(true)
	var cell: int = -1
	for c in range(drainage.lattice.receiver.size()):
		if drainage.lattice.receiver[c] >= 0:
			cell = c
			break
	drainage.lattice.receiver[cell] = cell
	cases.append([drainage, "ERR_HYDRO_DRAINAGE"])
	var interior_edge: Dictionary = data.duplicate(true)
	var interior: int = 64 * Hydro.LATTICE_SIZE + 64
	if interior_edge.lattice.terminal[interior] == Hydro.TERMINAL_NONE:
		interior_edge.lattice.terminal[interior] = Hydro.TERMINAL_EDGE
		interior_edge.lattice.receiver[interior] = -1
	else:
		interior_edge.lattice.terminal[interior] = Hydro.TERMINAL_CLOSED
	cases.append([interior_edge, "ERR_HYDRO_DRAINAGE"])
	# A river terminal far from the river corridor.
	var fake_river: Dictionary = data.duplicate(true)
	var far_cell: int = -1
	for c in range(fake_river.lattice.receiver.size()):
		var p := Vector2((c % Hydro.LATTICE_SIZE) * 3200.0, (c / Hydro.LATTICE_SIZE) * 3200.0)
		var near: bool = false
		for k in range(data.channels[0].x_cm.size()):
			near = near or p.distance_to(Vector2(data.channels[0].x_cm[k], data.channels[0].z_cm[k])) < 30000.0
		if fake_river.lattice.terminal[c] == Hydro.TERMINAL_NONE and not near:
			far_cell = c
			break
	fake_river.lattice.terminal[far_cell] = Hydro.TERMINAL_RIVER
	fake_river.lattice.receiver[far_cell] = -1
	cases.append([fake_river, "ERR_HYDRO_DRAINAGE"])
	for case: Array in cases:
		var result: Dictionary = Hydro.new(case[0]).validate()
		_check(not result.is_valid and result.reason_codes == [case[1]], "H11 exactly %s, got %s" % [case[1], str(result.reason_codes)])
	_check(Hydro.new({}).validate().reason_codes == ["ERR_HYDRO_SCHEMA"], "H11 empty plan")
	# Routing on synthetic grids.
	var outlets := PackedByteArray()
	outlets.resize(81)
	var nan_grid := PackedFloat64Array()
	nan_grid.resize(81)
	nan_grid[40] = NAN
	_check(Routing.route(nan_grid, 9, 9, 32.0, outlets).reason_code == "ERR_ROUTING_INPUT" and Routing.route(PackedFloat64Array([1.0]), 1, 1, 32.0, PackedByteArray([0])).reason_code == "ERR_ROUTING_INPUT" and Routing.route(PackedFloat64Array(), 9, 9, 32.0, outlets).reason_code == "ERR_ROUTING_INPUT", "H11 routing input reasons")
	var plane := PackedFloat64Array()
	var bowl := PackedFloat64Array()
	var flat := PackedFloat64Array()
	var noisy := PackedFloat64Array()
	for j in range(9):
		for i in range(9):
			plane.append(10.0 * i + 0.1 * j)
			bowl.append(10.0 + float((i - 4) * (i - 4) + (j - 4) * (j - 4)) if i > 0 and j > 0 and i < 8 and j < 8 else (50.0 if i == 0 and j == 4 else 200.0))
			flat.append(0.0)
	for k in range(33 * 33):
		noisy.append(fposmod(sin(k * 12.9898) * 43758.5453, 10.0))
	for grid: Array in [[plane, 9, "plane"], [bowl, 9, "bowl"], [flat, 9, "flat"], [noisy, 33, "noisy"]]:
		var size: int = grid[1]
		var marks := PackedByteArray()
		marks.resize(size * size)
		var first: Dictionary = Routing.route(grid[0], size, size, 32.0, marks)
		var second: Dictionary = Routing.route(grid[0], size, size, 32.0, marks)
		var drained: bool = first.is_valid and first.receiver == second.receiver
		var total: int = 0
		for c in range(size * size):
			if first.receiver[c] < 0:
				total += first.area_cells[c]
				drained = drained and first.terminal[c] == Routing.TERMINAL_EDGE
			else:
				drained = drained and first.filled_m[first.receiver[c]] <= first.filled_m[c]
		var crossing: bool = false
		for j in range(size - 1):
			for i in range(size - 1):
				var a: int = j * size + i
				crossing = crossing or ((first.receiver[a] == a + size + 1 or first.receiver[a + size + 1] == a) and (first.receiver[a + 1] == a + size or first.receiver[a + size] == a + 1))
		_check(drained and total == size * size and not crossing, "H11 routing %s: deterministic, drains to edges, area conserved, no crossing" % grid[2])
	var bowl_route: Dictionary = Routing.route(bowl, 9, 9, 32.0, outlets)
	_check(bowl_route.filled_m[40] > bowl[40] and bowl_route.filled_m[40] >= 50.0 and bowl_route.filled_m[40] < 50.1, "H11 routing fills a closed bowl to its spill level")
	var marked := PackedByteArray()
	marked.resize(81)
	marked[40] = 1
	var sink: Dictionary = Routing.route(plane, 9, 9, 32.0, marked)
	_check(sink.terminal[40] == Routing.TERMINAL_OUTLET and sink.receiver[40] == -1 and sink.area_cells[40] >= 1, "H11 routing marked outlet is terminal")


# H12 — observational timings (no budget).
func _h12() -> void:
	var start: int = Time.get_ticks_usec()
	var plan: RefCounted = Generator.build(ROWS[0][0], Vector2i.ZERO)
	var field: RefCounted = Field.create(plan).field
	var built: Dictionary = HGen.build(plan, field)
	var generator_us: int = Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var hf: RefCounted = HField.create(built.plan, field).field
	var create_us: int = Time.get_ticks_usec() - start
	var b: Dictionary = field.get_bounds_m()
	start = Time.get_ticks_usec()
	for k in range(200):
		hf.sample_deformation(b.min_x + 20.0 * k, b.min_z + 2000.0)
	var deformation_us: int = (Time.get_ticks_usec() - start) / 200
	start = Time.get_ticks_usec()
	for k in range(50):
		hf.sample_proximity(b.min_x + 80.0 * k, b.min_z + 3500.0)
	var proximity_us: int = (Time.get_ticks_usec() - start) / 50
	var surface: RefCounted = HSurface.create(field, hf).surface
	start = Time.get_ticks_usec()
	Renderer.tile_arrays(surface, 3, 4)
	var tile_us: int = Time.get_ticks_usec() - start
	printerr("HYDRO_TIMING generator_ms=%d field_create_ms=%d deformation_us=%d proximity_us=%d surface_tile_ms=%d" % [generator_us / 1000, create_us / 1000, deformation_us, proximity_us, tile_us / 1000])
	_check(built.is_valid, "H12 timing run built")
