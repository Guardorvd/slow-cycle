extends SceneTree

## R2 terrain tile contract suite (headless). Protects the TerrainField
## world-space query contract (height authority, gradient/normal definition,
## lattice parity, closed domain and exact reasons) and the
## TerrainTileRenderer tile contract (topology, winding, coverage, seams by
## construction, determinism). ArrayMesh commit and real rendering are
## covered by test_region_preview.gd and capture_region_preview.gd (Vulkan).

const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const Plan = preload("res://scripts/world/region/region_plan.gd")
const Generator = preload("res://scripts/world/region/region_generator.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const Renderer = preload("res://scripts/world/region/terrain_tile_renderer.gd")
const I64MIN: int = -9223372036854775807 - 1
const I64MAX: int = 9223372036854775807
const I32MIN: int = -2147483648
const I32MAX: int = 2147483647
## Spike/discontinuity detector (R1 G5 semantics), not a rideability limit.
const MAX_GRADE: float = 5.0
## Fixtures: three reference seeds at (0,0), two offset regions, two extremes.
const ROWS := [[184729, 0, 0], [42, 0, 0], [77777, 0, 0], [184729, -1, -1], [42, 3, -2], [I64MIN, I32MAX, I32MIN], [I64MAX, I32MIN, I32MAX]]
## Fixtures whose 64 tiles are built (reference seeds + one negative region).
const TILE_FIXTURES := [0, 1, 2, 3]
const OWN_CHECKS: int = 2178

var checks: int = 0
var failures: int = 0
var _plans: Array = []
var _fields: Array = []
var _tiles: Dictionary = {} # fixture -> Array of 64 tile_arrays results, row-major


func _init() -> void:
	for path: String in ["scripts/world/region/terrain_field.gd", "scripts/world/region/terrain_tile_renderer.gd", "scripts/world/region/macro_terrain_evaluator.gd", "scripts/world/region_preview.gd", "scenes/world/region_preview.tscn"]:
		_check(load("res://" + path) != null, "E0 explicit resource load " + path)
	for row: Array in ROWS:
		var plan: RefCounted = Generator.build(row[0], Vector2i(row[1], row[2]))
		var created: Dictionary = Field.create(plan)
		_check(plan != null and created.is_valid and created.field is Field and created.reason_code == "", "fixture field w=%d c=%d,%d" % row)
		if plan == null or not created.is_valid:
			print("TERRAIN_CONTRACT_SUMMARY construction_aborted=true checks=%d failures=%d" % [checks, failures])
			quit(1)
			return
		_plans.append(plan)
		_fields.append(created.field)
		print("TERRAIN_FIXTURE w=%d x=%d z=%d region_signature=%s bounds=%s" % [row[0], row[1], row[2], plan.signature(), JSON.stringify(created.field.get_bounds_m())])
	for group: Callable in [_f1, _f2, _f3, _f4, _f5, _f6, _f7, _f8, _f9, _f10, _f11, _f12]:
		var before: int = checks
		var failed_before: int = failures
		var start: int = Time.get_ticks_msec()
		group.call()
		print("TERRAIN_GROUP name=%s checks=%d failures=%d" % [group.get_method(), checks - before, failures - failed_before])
		printerr("TERRAIN_GROUP_TIME name=%s ms=%d" % [group.get_method(), Time.get_ticks_msec() - start])
	_check(checks + 1 == OWN_CHECKS, "fixed own check count %d" % (checks + 1))
	print("TERRAIN_CONTRACT_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("TERRAIN_CONTRACT_FAIL " + message)


func _query(field: RefCounted, kind: String, x: float, z: float) -> Dictionary:
	match kind:
		"height":
			return field.sample_height(x, z)
		"gradient":
			return field.sample_gradient(x, z)
	return field.sample_normal(x, z)


func _value_is_nan(result: Dictionary) -> bool:
	if result.has("height_m"):
		return is_nan(result.height_m)
	if result.has("gradient"):
		return is_nan(result.gradient.x) and is_nan(result.gradient.y)
	return is_nan(result.normal.x) and is_nan(result.normal.y) and is_nan(result.normal.z)


func _hash(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## Region-local probe points (dyadic, exact after a round trip through any
## world origin): corners, edges, a 512 m lattice and seeded random points.
func _local_points(random_count: int, salt: int) -> Array:
	var points: Array = [[0.0, 0.0], [4096.0, 4096.0], [0.0, 4096.0], [4096.0, 0.0], [0.0, 1234.5], [4096.0, 2000.125], [777.25, 0.0], [3000.0, 4096.0], [8.0, 4088.0], [4095.875, 15.5]]
	for j in range(9):
		for i in range(9):
			points.append([i * 512.0, j * 512.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006 + salt
	for k in range(random_count):
		points.append([rng.randi_range(0, 32768) / 8.0, rng.randi_range(0, 32768) / 8.0])
	return points


## The contract gradient, restated from the public height query.
func _expected_gradient(field: RefCounted, x: float, z: float) -> Vector2:
	var b: Dictionary = field.get_bounds_m()
	var x0: float = maxf(b.min_x, x - 16.0)
	var x1: float = minf(b.max_x, x + 16.0)
	var z0: float = maxf(b.min_z, z - 16.0)
	var z1: float = minf(b.max_z, z + 16.0)
	return Vector2((field.sample_height(x1, z).height_m - field.sample_height(x0, z).height_m) / (x1 - x0), (field.sample_height(x, z1).height_m - field.sample_height(x, z0).height_m) / (z1 - z0))


func _tile_origin(fixture: int, index: int) -> Vector2i:
	var b: Dictionary = _fields[fixture].get_bounds_m()
	return Vector2i(b.min_x / Renderer.TILE_SIZE_M + index % 8, b.min_z / Renderer.TILE_SIZE_M + index / 8)


# F1 — purity, dependency direction and API surface.
func _f1() -> void:
	_check(Field.SCHEMA_TAG == "slow_cycle.terrain_field/1" and Field.LATTICE_STEP_M == 16 and Field.GRADIENT_HALF_STEP_M == 16.0, "F1 field contract constants")
	_check(Renderer.TILE_CELLS == 32 and Renderer.TILE_VERTICES == 33 and Renderer.TILE_SIZE_M == 512, "F1 tile contract constants")
	for script: Script in [Field, Renderer]:
		_check(script.get_instance_base_type() == "RefCounted", "F1 RefCounted " + script.resource_path)
		for token: String in ["get_tree", "Node3D", "MeshInstance", "RenderingServer", "add_child", "randomize(", "randi()", "Time.", "MountainMassifField", "get_data"]:
			_check(not token in script.source_code, "F1 %s free of %s" % [script.resource_path, token])
	# Consumers depend on TerrainField only, never on the R1 kernel or descriptor.
	var preview: String = FileAccess.get_file_as_string("res://scripts/world/region_preview.gd")
	var renderer: String = FileAccess.get_file_as_string("res://scripts/world/region/terrain_tile_renderer.gd")
	for source: String in [renderer, preview]:
		for token: String in ["macro_terrain_evaluator", "MacroTerrainEvaluator", "sample_grid", "evaluate_elevation_m", "macro_geography_generator", "get_macro_terrain", "valley_points"]:
			_check(not token in source, "F1 consumer free of " + token)
	_check(not "region_plan" in renderer and "terrain_field.gd" in renderer, "F1 renderer depends on the field only")
	_check("terrain_field.gd" in preview and "terrain_tile_renderer.gd" in preview, "F1 preview composes field and renderer")
	var field: RefCounted = _fields[0]
	for method: String in ["sample_height", "sample_gradient", "sample_normal", "sample_lattice", "get_bounds_m", "get_region_signature"]:
		_check(field.has_method(method), "F1 field has " + method)
	for part: RefCounted in [_plans[0], _plans[0].get_macro_terrain()]:
		for method: String in ["sample_height", "sample_gradient", "sample_normal", "get_height"]:
			_check(not part.has_method(method), "F1 plan stays query-free " + method)


# F2 — creation, reasons and snapshot independence.
func _f2() -> void:
	for fixture in range(ROWS.size()):
		var bounds: RefCounted = _plans[fixture].get_bounds()
		_check(_fields[fixture].get_bounds_m() == {"min_x": bounds.get_min_x_m(), "min_z": bounds.get_min_z_m(), "max_x": bounds.get_max_x_m(), "max_z": bounds.get_max_z_m()}, "F2 bounds fixture=%d" % fixture)
		_check(_fields[fixture].get_region_signature() == _plans[fixture].signature(), "F2 region signature fixture=%d" % fixture)
	_check(Field.create(null) == {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_MISSING"}, "F2 null plan")
	_check(Field.create(_plans[0].get_macro_terrain()) == {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_MISSING"}, "F2 not a RegionPlan")
	_check(Field.create(Plan.new(_plans[0].get_identity(), _plans[0].get_bounds(), null)) == {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_MISSING"}, "F2 plan without macro")
	var swapped := Generator.build(184729, Vector2i.ZERO)
	swapped._macro_terrain = Generator.build(42, Vector2i.ZERO).get_macro_terrain()
	_check(Field.create(swapped) == {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_INVALID"}, "F2 swapped macro")
	var tampered := Generator.build(184729, Vector2i.ZERO)
	tampered.get_macro_terrain()._state = "BAD"
	_check(Field.create(tampered) == {"is_valid": false, "field": null, "reason_code": "ERR_TERRAIN_PLAN_INVALID"}, "F2 bad macro state")
	# The field snapshots the plan: later plan tampering does not reach it.
	var plan := Generator.build(184729, Vector2i.ZERO)
	var field: RefCounted = Field.create(plan).field
	var before: float = field.sample_height(1000.0, 1000.0).height_m
	plan.get_macro_terrain()._state = "BAD"
	plan.get_macro_terrain()._data.noise.amplitude_cm = 0
	_check(field.sample_height(1000.0, 1000.0).height_m == before, "F2 field independent of later plan changes")


# F3 — height authority: world query == R1 evaluator at the local point.
func _f3() -> void:
	for fixture in range(ROWS.size()):
		var field: RefCounted = _fields[fixture]
		var macro: RefCounted = _plans[fixture].get_macro_terrain()
		var b: Dictionary = field.get_bounds_m()
		var points: Array = _local_points(150, fixture)
		var same: bool = true
		for p: Array in points:
			var world: Dictionary = field.sample_height(b.min_x + p[0], b.min_z + p[1])
			var local: Dictionary = Eval.evaluate_elevation_m(macro, p[0], p[1])
			same = same and world.is_valid and local.is_valid and world.height_m == local.elevation_m
		_check(same, "F3 height bit-identical to R1 evaluator fixture=%d points=%d" % [fixture, points.size()])


# F4 — closed domain, non-finite input, lattice and tile reasons.
func _f4() -> void:
	for fixture: int in [0, 3, 5, 6]:
		var field: RefCounted = _fields[fixture]
		var b: Dictionary = field.get_bounds_m()
		var mid_x: float = b.min_x + 2048.0
		var mid_z: float = b.min_z + 2048.0
		for kind: String in ["height", "gradient", "normal"]:
			for corner: Array in [[b.min_x, b.min_z], [b.max_x, b.max_z], [b.min_x, b.max_z], [b.max_x, b.min_z]]:
				var result: Dictionary = _query(field, kind, corner[0], corner[1])
				_check(result.is_valid and result.reason_code == "" and not _value_is_nan(result), "F4 closed corner %s fixture=%d" % [kind, fixture])
			var outside: Array = [[b.max_x + 0.001, mid_z], [b.min_x - 0.001, mid_z], [mid_x, b.max_z + 0.001], [mid_x, b.min_z - 0.001], [b.min_x - 4096.0, b.min_z - 4096.0]]
			for point: Array in outside:
				var result: Dictionary = _query(field, kind, point[0], point[1])
				_check(not result.is_valid and result.reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN" and _value_is_nan(result), "F4 outside %s fixture=%d" % [kind, fixture])
			for value: float in [NAN, INF, -INF]:
				for point: Array in [[value, mid_z], [mid_x, value], [value, b.max_z + 10.0]]:
					var result: Dictionary = _query(field, kind, point[0], point[1])
					_check(not result.is_valid and result.reason_code == "ERR_TERRAIN_NONFINITE_INPUT" and _value_is_nan(result), "F4 non-finite %s fixture=%d" % [kind, fixture])
	# World-space ownership: a region-local coordinate is not inside region (3,-2).
	for kind: String in ["height", "gradient", "normal"]:
		_check(_query(_fields[4], kind, 100.0, 100.0).reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN", "F4 local coordinate rejected " + kind)
	var field: RefCounted = _fields[0]
	var lattice_cases: Array = [[0, 0, 0, 1, "ERR_TERRAIN_GRID_SHAPE"], [0, 0, 1, -1, "ERR_TERRAIN_GRID_SHAPE"], [0, 0, 258, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [0, 0, 1, 258, "ERR_TERRAIN_OUT_OF_DOMAIN"], [-1, 0, 1, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [257, 0, 1, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [0, 257, 1, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [I64MAX, 0, 1, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [I64MIN, 0, 1, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"], [0, 0, 1, I64MAX, "ERR_TERRAIN_OUT_OF_DOMAIN"], [256, 256, 2, 1, "ERR_TERRAIN_OUT_OF_DOMAIN"]]
	for row: Array in lattice_cases:
		var result: Dictionary = field.sample_lattice(row[0], row[1], row[2], row[3])
		_check(not result.is_valid and result.reason_code == row[4] and result.heights_m.is_empty() and result.gradients.is_empty() and result.normals.is_empty(), "F4 lattice %s -> %s" % [str(row.slice(0, 4)), row[4]])
	_check(field.sample_lattice(0, 0, 257, 1).is_valid and field.sample_lattice(256, 256, 1, 1).is_valid, "F4 lattice edges valid")
	var extreme: RefCounted = _fields[5]
	var eb: Dictionary = extreme.get_bounds_m()
	_check(extreme.sample_lattice(eb.min_x / 16, eb.min_z / 16, 2, 2).is_valid and extreme.sample_lattice(eb.max_x / 16, eb.max_z / 16, 2, 1).reason_code == "ERR_TERRAIN_OUT_OF_DOMAIN", "F4 extreme lattice bounds")
	var tile_cases: Array = [[null, 0, 0, "ERR_TILE_FIELD_MISSING"], [_plans[0], 0, 0, "ERR_TILE_FIELD_MISSING"], [field, -1, 0, "ERR_TERRAIN_OUT_OF_DOMAIN"], [field, 8, 0, "ERR_TERRAIN_OUT_OF_DOMAIN"], [field, 0, 8, "ERR_TERRAIN_OUT_OF_DOMAIN"], [field, I64MAX, 0, "ERR_TERRAIN_OUT_OF_DOMAIN"], [field, I64MIN, I64MIN, "ERR_TERRAIN_OUT_OF_DOMAIN"], [field, I64MAX / 32 + 1, 0, "ERR_TERRAIN_OUT_OF_DOMAIN"], [extreme, eb.min_x / 512 + 8, eb.min_z / 512, "ERR_TERRAIN_OUT_OF_DOMAIN"]]
	for row: Array in tile_cases:
		var arrays: Dictionary = Renderer.tile_arrays(row[0], row[1], row[2])
		var mesh: Dictionary = Renderer.tile_mesh(row[0], row[1], row[2])
		_check(not arrays.is_valid and arrays.reason_code == row[3] and arrays.arrays.is_empty() and not mesh.is_valid and mesh.reason_code == row[3] and mesh.mesh == null, "F4 tile %d,%d -> %s" % [row[1], row[2], row[3]])
	_check(Renderer.tile_arrays(extreme, eb.min_x / 512 + 7, eb.min_z / 512 + 7).is_valid, "F4 extreme last tile valid")


# F5 — gradient and normal follow the single contract definition.
func _f5() -> void:
	for fixture: int in [0, 1, 2, 3, 5]:
		var field: RefCounted = _fields[fixture]
		var b: Dictionary = field.get_bounds_m()
		var gradient_ok: bool = true
		var normal_ok: bool = true
		var unit_ok: bool = true
		var steepest: float = 0.0
		for p: Array in _local_points(80, 100 + fixture):
			var x: float = b.min_x + p[0]
			var z: float = b.min_z + p[1]
			var g: Vector2 = field.sample_gradient(x, z).gradient
			var n: Vector3 = field.sample_normal(x, z).normal
			gradient_ok = gradient_ok and g == _expected_gradient(field, x, z)
			normal_ok = normal_ok and n == Vector3(-g.x, 1.0, -g.y).normalized()
			unit_ok = unit_ok and g.is_finite() and n.is_finite() and n.y > 0.0 and absf(n.length() - 1.0) < 1e-5
			steepest = maxf(steepest, g.length())
		_check(gradient_ok, "F5 gradient == clamped central difference fixture=%d" % fixture)
		_check(normal_ok, "F5 normal derived from gradient fixture=%d" % fixture)
		_check(unit_ok, "F5 finite unit upward normals fixture=%d" % fixture)
		_check(steepest > 0.3 and steepest <= MAX_GRADE, "F5 non-degenerate bounded gradient fixture=%d steepest=%.3f" % [fixture, steepest])


func _lattice_matches_points(field: RefCounted, i0: int, j0: int, nx: int, nz: int) -> bool:
	var block: Dictionary = field.sample_lattice(i0, j0, nx, nz)
	if not block.is_valid or block.heights_m.size() != nx * nz:
		return false
	var same: bool = true
	for j in range(nz):
		for i in range(nx):
			var x: float = float((i0 + i) * 16)
			var z: float = float((j0 + j) * 16)
			var k: int = j * nx + i
			same = same and block.heights_m[k] == field.sample_height(x, z).height_m and block.gradients[k] == field.sample_gradient(x, z).gradient and block.normals[k] == field.sample_normal(x, z).normal
	return same


# F6 — lattice blocks are bit-identical to point queries and to each other.
func _f6() -> void:
	for fixture in range(ROWS.size()):
		var field: RefCounted = _fields[fixture]
		var b: Dictionary = field.get_bounds_m()
		var i0: int = b.min_x / 16
		var j0: int = b.min_z / 16
		var i1: int = b.max_x / 16
		var j1: int = b.max_z / 16
		for block: Array in [[i0, j0, 9, 9], [i1 - 8, j1 - 8, 9, 9], [i0 + 100, j0 + 37, 7, 5], [i1, j0, 1, 1], [i0, j1 - 3, 4, 4]]:
			_check(_lattice_matches_points(field, block[0], block[1], block[2], block[3]), "F6 lattice == point queries fixture=%d block=%s" % [fixture, str(block)])
		var a: Dictionary = field.sample_lattice(i0 + 40, j0 + 40, 20, 20)
		var c: Dictionary = field.sample_lattice(i0 + 50, j0 + 45, 20, 20)
		var overlap: bool = true
		for j in range(5, 20):
			for i in range(10, 20):
				var ka: int = j * 20 + i
				var kc: int = (j - 5) * 20 + (i - 10)
				overlap = overlap and a.heights_m[ka] == c.heights_m[kc] and a.gradients[ka] == c.gradients[kc] and a.normals[ka] == c.normals[kc]
		_check(overlap, "F6 overlapping blocks agree fixture=%d" % fixture)


func _build_tiles(field: RefCounted, fixture: int, reverse: bool) -> Array:
	var tiles: Array = []
	tiles.resize(64)
	for n in range(64):
		var index: int = 63 - n if reverse else n
		var origin: Vector2i = _tile_origin(fixture, index)
		tiles[index] = Renderer.tile_arrays(field, origin.x, origin.y)
	return tiles


# F7 — tile arrays: topology, finiteness, winding, field agreement.
func _f7() -> void:
	for fixture: int in TILE_FIXTURES:
		var field: RefCounted = _fields[fixture]
		var tiles: Array = _build_tiles(field, fixture, false)
		_tiles[fixture] = tiles
		var disagreeing: int = 0
		var total_triangles: int = 0
		for index in range(64):
			var tile: Dictionary = tiles[index]
			var origin: Vector2i = _tile_origin(fixture, index)
			var label: String = "fixture=%d tile=%d" % [fixture, index]
			_check(tile.is_valid and tile.reason_code == "" and tile.origin_x_m == origin.x * 512 and tile.origin_z_m == origin.y * 512, "F7 tile built " + label)
			var vertices: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = tile.arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
			var heights: PackedFloat64Array = tile.heights_m
			_check(tile.arrays.size() == Mesh.ARRAY_MAX and vertices.size() == 1089 and normals.size() == 1089 and indices.size() == 6144 and heights.size() == 1089, "F7 array sizes " + label)
			var vertex_ok: bool = true
			for k in range(1089):
				var v: Vector3 = vertices[k]
				var n: Vector3 = normals[k]
				vertex_ok = vertex_ok and v.is_finite() and n.is_finite() and n.y > 0.0 and absf(n.length() - 1.0) < 1e-5
				vertex_ok = vertex_ok and v.x == (k % 33) * 16 and v.z == (k / 33) * 16 and v.y == Vector3(0, heights[k], 0).y
			_check(vertex_ok, "F7 finite lattice vertices, unit upward normals " + label)
			# Spot-check the renderer against the field's point queries.
			var agrees: bool = true
			for k: int in [0, 32, 544, 1056, 1088, 33 * 7 + 19]:
				var x: float = float(tile.origin_x_m + (k % 33) * 16)
				var z: float = float(tile.origin_z_m + (k / 33) * 16)
				agrees = agrees and heights[k] == field.sample_height(x, z).height_m and normals[k] == field.sample_normal(x, z).normal
			_check(agrees, "F7 vertices equal field point queries " + label)
			var triangles_ok: bool = true
			for offset in range(0, 6144, 3):
				var ia: int = indices[offset]
				var ib: int = indices[offset + 1]
				var ic: int = indices[offset + 2]
				if ia < 0 or ib < 0 or ic < 0 or ia >= 1089 or ib >= 1089 or ic >= 1089:
					triangles_ok = false
					continue
				var face: Vector3 = (vertices[ic] - vertices[ia]).cross(vertices[ib] - vertices[ia])
				# Clockwise from +Y: positive face.y, exact 128 m^2 footprint.
				triangles_ok = triangles_ok and face.y > 0.0 and face.y / 2.0 == 128.0
				for vertex_index: int in [ia, ib, ic]:
					disagreeing += 1 if face.dot(normals[vertex_index]) <= 0.0 else 0
				total_triangles += 1
			_check(triangles_ok, "F7 index range, clockwise non-inverted exact triangles " + label)
		print("TERRAIN_NORMAL_FACE_DISAGREEMENT fixture=%d vertex_face_pairs=%d of %d" % [fixture, disagreeing, total_triangles * 3])
		_check(disagreeing == 0 and total_triangles == 64 * 2048, "F7 every vertex normal on the front side of its faces fixture=%d" % fixture)


func _world_vertex(fixture: int, tile: Dictionary, k: int) -> Vector3:
	var b: Dictionary = _fields[fixture].get_bounds_m()
	return tile.arrays[Mesh.ARRAY_VERTEX][k] + Vector3(tile.origin_x_m - b.min_x, 0, tile.origin_z_m - b.min_z)


# F8 — seams absent by construction: shared edges, corners, build order and
# field instance never change a shared vertex.
func _f8() -> void:
	for fixture: int in TILE_FIXTURES:
		var tiles: Array = _tiles[fixture]
		for tz in range(8):
			for tx in range(8):
				var index: int = tz * 8 + tx
				for neighbour: Array in [[1, 0], [0, 1]]:
					if tx + neighbour[0] > 7 or tz + neighbour[1] > 7:
						continue
					var other: int = index + neighbour[0] + 8 * neighbour[1]
					var same: bool = true
					for s in range(33):
						var ka: int = s * 33 + 32 if neighbour[0] == 1 else 32 * 33 + s
						var kb: int = s * 33 if neighbour[0] == 1 else s
						same = same and _world_vertex(fixture, tiles[index], ka) == _world_vertex(fixture, tiles[other], kb)
						same = same and tiles[index].arrays[Mesh.ARRAY_NORMAL][ka] == tiles[other].arrays[Mesh.ARRAY_NORMAL][kb]
						same = same and tiles[index].heights_m[ka] == tiles[other].heights_m[kb]
					_check(same, "F8 shared edge bit-identical fixture=%d tiles=%d,%d" % [fixture, index, other])
		var corners: bool = true
		for cz in range(1, 8):
			for cx in range(1, 8):
				var owners: Array = [[(cz - 1) * 8 + cx - 1, 1088], [(cz - 1) * 8 + cx, 32 * 33], [cz * 8 + cx - 1, 32], [cz * 8 + cx, 0]]
				for owner: Array in owners:
					corners = corners and _world_vertex(fixture, tiles[owner[0]], owner[1]) == _world_vertex(fixture, tiles[owners[0][0]], owners[0][1])
					corners = corners and tiles[owner[0]].arrays[Mesh.ARRAY_NORMAL][owner[1]] == tiles[owners[0][0]].arrays[Mesh.ARRAY_NORMAL][owners[0][1]]
		_check(corners, "F8 four-tile corners bit-identical fixture=%d" % fixture)
		# Independent plan, independent field instance, reverse build order.
		var row: Array = ROWS[fixture]
		var second: RefCounted = Field.create(Generator.build(row[0], Vector2i(row[1], row[2]))).field
		_check(second != _fields[fixture], "F8 second field is a distinct instance fixture=%d" % fixture)
		var rebuilt: Array = _build_tiles(second, fixture, true)
		var identical: bool = true
		for index in range(64):
			identical = identical and rebuilt[index].arrays == tiles[index].arrays and rebuilt[index].heights_m == tiles[index].heights_m
		_check(identical, "F8 reverse-order tiles from an independent field identical fixture=%d" % fixture)


# F9 — coverage: every lattice cell exactly once, no holes, no T-junctions.
func _f9() -> void:
	for fixture: int in TILE_FIXTURES:
		var tiles: Array = _tiles[fixture]
		var counts := PackedInt32Array()
		counts.resize(256 * 256)
		var area: float = 0.0
		var in_range: bool = true
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for index in range(64):
			var tile: Dictionary = tiles[index]
			var vertices: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
			for offset in range(0, indices.size(), 3):
				var a: Vector3 = _world_vertex(fixture, tile, indices[offset])
				var b: Vector3 = _world_vertex(fixture, tile, indices[offset + 1])
				var c: Vector3 = _world_vertex(fixture, tile, indices[offset + 2])
				var cell_x: int = floori(minf(a.x, minf(b.x, c.x)) / 16.0)
				var cell_z: int = floori(minf(a.z, minf(b.z, c.z)) / 16.0)
				if cell_x < 0 or cell_z < 0 or cell_x > 255 or cell_z > 255:
					in_range = false
					continue
				counts[cell_z * 256 + cell_x] += 1
				area += (c - a).cross(b - a).y / 2.0
				for v: Vector3 in [a, b, c]:
					low = Vector2(minf(low.x, v.x), minf(low.y, v.z))
					high = Vector2(maxf(high.x, v.x), maxf(high.y, v.z))
		var exact: bool = in_range
		for count: int in counts:
			exact = exact and count == 2
		_check(exact, "F9 each lattice cell covered by exactly two triangles fixture=%d" % fixture)
		_check(area == 4096.0 * 4096.0, "F9 total XZ area equals the region fixture=%d area=%.1f" % [fixture, area])
		_check(low == Vector2.ZERO and high == Vector2(4096, 4096), "F9 union equals the region square fixture=%d" % fixture)


func _tiles_hash(tiles: Array) -> String:
	var bytes := PackedByteArray()
	for tile: Dictionary in tiles:
		bytes.append_array(tile.arrays[Mesh.ARRAY_VERTEX].to_byte_array())
		bytes.append_array(tile.arrays[Mesh.ARRAY_NORMAL].to_byte_array())
		bytes.append_array(tile.heights_m.to_byte_array())
	return _hash(bytes)


# F10 — determinism: global RNG isolation and cross-process hashes.
func _f10() -> void:
	for fixture: int in TILE_FIXTURES:
		print("TERRAIN_TILE_HASH fixture=%d sha256=%s" % [fixture, _tiles_hash(_tiles[fixture])])
	seed(77)
	var expected: int = randi()
	seed(77)
	var field: RefCounted = Field.create(Generator.build(184729, Vector2i.ZERO)).field
	field.sample_height(100.0, 200.0)
	field.sample_normal(4096.0, 0.0)
	field.sample_lattice(0, 0, 3, 3)
	var tile: Dictionary = Renderer.tile_arrays(field, 3, 5)
	_check(randi() == expected, "F10 field and renderer consume no global RNG")
	seed(1)
	_check(Renderer.tile_arrays(field, 3, 5).arrays == _tiles[0][43].arrays and tile.arrays == _tiles[0][43].arrays, "F10 tile unaffected by global seed")
	randomize()
	_check(Renderer.tile_arrays(Field.create(Generator.build(184729, Vector2i.ZERO)).field, 3, 5).arrays == _tiles[0][43].arrays, "F10 tile unaffected by randomize")


# F11 — numerical safety: full-region lattices and fine transects.
func _f11() -> void:
	for fixture in range(ROWS.size()):
		var field: RefCounted = _fields[fixture]
		var b: Dictionary = field.get_bounds_m()
		var heights := PackedFloat64Array()
		var normals_ok: bool = true
		if fixture in TILE_FIXTURES:
			# Re-assemble the 257^2 lattice from the tiles (already full coverage).
			heights.resize(257 * 257)
			for index in range(64):
				var tile: Dictionary = _tiles[fixture][index]
				for k in range(1089):
					heights[((index / 8) * 32 + k / 33) * 257 + (index % 8) * 32 + k % 33] = tile.heights_m[k]
		else:
			var block: Dictionary = field.sample_lattice(b.min_x / 16, b.min_z / 16, 257, 257)
			_check(block.is_valid and block.heights_m.size() == 257 * 257, "F11 full-region lattice fixture=%d" % fixture)
			heights = block.heights_m
			for n: Vector3 in block.normals:
				normals_ok = normals_ok and n.is_finite() and n.y > 0.0 and absf(n.length() - 1.0) < 1e-5
			print("TERRAIN_LATTICE_HASH fixture=%d sha256=%s" % [fixture, _hash(heights.to_byte_array() + block.normals.to_byte_array())])
		var finite: bool = true
		var steepest: float = 0.0
		for j in range(257):
			for i in range(257):
				var h: float = heights[j * 257 + i]
				finite = finite and is_finite(h)
				if i > 0:
					steepest = maxf(steepest, absf(h - heights[j * 257 + i - 1]) / 16.0)
				if j > 0:
					steepest = maxf(steepest, absf(h - heights[(j - 1) * 257 + i]) / 16.0)
		_check(finite and normals_ok, "F11 finite lattice and normals fixture=%d" % fixture)
		_check(steepest <= MAX_GRADE, "F11 lattice neighbour grade fixture=%d steepest=%.3f" % [fixture, steepest])
		print("TERRAIN_LATTICE_GRADE fixture=%d steepest=%.3f" % [fixture, steepest])
	# 1 m transects across every tile edge and through the evaluator's 256 m
	# spatial buckets: no step beyond the spike bound.
	for fixture: int in [0, 1, 2, 5]:
		var field: RefCounted = _fields[fixture]
		var b: Dictionary = field.get_bounds_m()
		var steepest: float = 0.0
		var finite: bool = true
		for along_x: bool in [true, false]:
			var previous: float = NAN
			for s in range(4097):
				var x: float = b.min_x + (float(s) if along_x else 2345.0)
				var z: float = b.min_z + (1234.0 if along_x else float(s))
				var h: float = field.sample_height(x, z).height_m
				finite = finite and is_finite(h)
				if s > 0:
					steepest = maxf(steepest, absf(h - previous))
				previous = h
		_check(finite and steepest <= MAX_GRADE, "F11 1 m transects continuous fixture=%d steepest=%.3f" % [fixture, steepest])
		print("TERRAIN_TRANSECT_GRADE fixture=%d steepest=%.3f" % [fixture, steepest])


# F12 — observational timings (stderr only; no budget, no checks).
func _f12() -> void:
	var start: int = Time.get_ticks_usec()
	var field: RefCounted = Field.create(Generator.build(184729, Vector2i.ZERO)).field
	var create_us: int = Time.get_ticks_usec() - start
	var timings: Dictionary = {"field_create_ms": create_us / 1000.0}
	for kind: String in ["height", "gradient", "normal"]:
		start = Time.get_ticks_usec()
		for k in range(200):
			_query(field, kind, 13.0 + k * 19.5, 4000.0 - k * 17.25)
		timings[kind + "_us"] = (Time.get_ticks_usec() - start) / 200.0
	var macro: RefCounted = _plans[0].get_macro_terrain()
	start = Time.get_ticks_usec()
	for k in range(50):
		Eval.evaluate_elevation_m(macro, 13.0 + k * 19.5, 4000.0 - k * 17.25)
	timings["r1_point_api_us"] = (Time.get_ticks_usec() - start) / 50.0
	start = Time.get_ticks_usec()
	Renderer.tile_arrays(field, 3, 5)
	timings["tile_arrays_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	printerr("TERRAIN_TIMINGS " + JSON.stringify(timings))
