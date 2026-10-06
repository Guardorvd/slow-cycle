extends SceneTree

const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Identity = preload("res://scripts/world/region/region_identity.gd")
const Bounds = preload("res://scripts/world/region/region_bounds.gd")
const MacroTerrain = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Plan = preload("res://scripts/world/region/region_plan.gd")
const Generator = preload("res://scripts/world/region/region_generator.gd")
const I32MIN: int = -2147483648
const I32MAX: int = 2147483647
const I64MIN: int = -9223372036854775807 - 1
const I64MAX: int = 9223372036854775807

## Literal approved S1-S15 fixtures: w, x, y, digest[0], seed, exact preimage.
const SEED_GOLDENS := [
	[184729, 0, 0, 0x1a, 1944063217383134986, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=0\nv2=0\n"],
	[184729, 1, 0, 0x24, 2600215425804300825, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=1\nv2=0\n"],
	[184729, 0, 1, 0x41, 4753250579508208490, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=0\nv2=1\n"],
	[184729, -1, -1, 0xcb, 5466766008934095593, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=-1\nv2=-1\n"],
	[184729, 1, 2, 0x91, 1284942358543851228, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=1\nv2=2\n"],
	[184729, 2, 1, 0x21, 2399257113511956278, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=2\nv2=1\n"],
	[42, 0, 0, 0xf5, 8498422420403868873, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=42\nv1=0\nv2=0\n"],
	[0, 0, 0, 0x94, 1495971027060834261, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=0\nv1=0\nv2=0\n"],
	[-1, 0, 0, 0x77, 8584550069411511142, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=-1\nv1=0\nv2=0\n"],
	[I64MAX, 0, 0, 0x47, 5151963691858557513, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=9223372036854775807\nv1=0\nv2=0\n"],
	[I64MIN, 0, 0, 0xaf, 3398898943656697436, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=-9223372036854775808\nv1=0\nv2=0\n"],
	[184729, I32MIN, I32MIN, 0x8e, 1044583465472755561, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=-2147483648\nv2=-2147483648\n"],
	[184729, I32MAX, I32MAX, 0x99, 1825065265736844034, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=2147483647\nv2=2147483647\n"],
	[184729, I32MIN, I32MAX, 0x1f, 2267084752082801798, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=184729\nv1=-2147483648\nv2=2147483647\n"],
	[I64MIN, I32MAX, I32MIN, 0xde, 6780184215550171328, "slow_cycle.seed/1\npurpose=region_seed\ncount=3\nv0=-9223372036854775808\nv1=2147483647\nv2=-2147483648\n"],
]
const SIGNATURE_GOLDENS := [
	[184729, 0, 0, "1e28fe1846cd0fa96b0c8cc7d153abd83703a14b9eaa1718b21e24cad69f6278"],
	[184729, -1, -1, "3170d27b86cf95fc704dfc02c3f9706771222cea112ef3ba6dbfa3732570c176"],
	[42, 0, 0, "5518e1b59b6c0280e1026a9ac8a58b94144b0447b6d1f04e5b29efdb287be964"],
	[184729, I32MAX, I32MAX, "3f5ea72ccf7a3e995dd79ef8d5a19c6f8f4065edd891b1e656211d340ed21a6f"],
	[I64MIN, I32MIN, I32MIN, "f8fe99e64b0e82b798770703a335c28d24a48f80733b327a83405b3ca44bcde9"],
]
const P2_TEXT := "slow_cycle.region_plan/2\nlayout.region_size_m=4096\nidentity.world_seed=184729\nidentity.region_coordinate=-1,-1\nidentity.region_seed=5466766008934095593\nbounds.min_x_m=-4096\nbounds.min_z_m=-4096\nbounds.max_x_m=0\nbounds.max_z_m=0\nmacro_terrain.state=GENERATED_R1\nmacro_terrain.signature=4e06d0163258e1f46acbdf0115ec47e348298e8380fac25b3c1fba1014e30c07\n"

var checks: int = 0
var failures: int = 0


func _init() -> void:
	var groups: Array[Callable] = [_t1, _t2, _t3, _t4, _t5, _t6, _t7, _t8, _t9, _t10, _t11]
	for i in range(groups.size()):
		var before: int = checks
		groups[i].call()
		print("REGION_DOMAIN_GROUP T%d checks=%d" % [i + 1, checks - before])
	if checks != 145:
		failures += 1
		push_error("REGION_DOMAIN_FAIL incomplete coverage: expected 145 checks, got " + str(checks))
	print("REGION_DOMAIN_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REGION_DOMAIN_FAIL " + message)


func _t1() -> void:
	for i in range(SEED_GOLDENS.size()):
		var row: Array = SEED_GOLDENS[i]
		var coordinate := Vector2i(row[1], row[2])
		var preimage: String = Seeds.region_seed_preimage(row[0], coordinate)
		_check(preimage == row[5], "T1 S%d exact LF preimage" % (i + 1))
		var actual: int = Seeds.region_seed(row[0], coordinate)
		_check(actual == row[4] and preimage.sha256_buffer()[0] == row[3],
			"T1 S%d derived seed and first-byte extraction class" % (i + 1))
		print("REGION_DOMAIN_SEED S%d seed=%d first_byte=%d" % [i + 1, actual, preimage.sha256_buffer()[0]])


func _t2() -> void:
	var token := RegEx.new()
	var compiled: int = token.compile("^[a-z][a-z0-9_]{0,63}$")
	_check(compiled == OK and token.search(Seeds.PURPOSE_REGION_SEED) != null, "T2 purpose token grammar")


func _t3() -> void:
	for i in range(SIGNATURE_GOLDENS.size()):
		var row: Array = SIGNATURE_GOLDENS[i]
		var actual: String = Generator.build(row[0], Vector2i(row[1], row[2])).signature()
		_check(actual == row[3], "T3 P%d identity signature" % (i + 1))
		print("REGION_DOMAIN_SIGNATURE P%d signature=%s" % [i + 1, actual])
	_check(Generator.build(184729, Vector2i(-1, -1)).canonical_text() == P2_TEXT, "T3 exact P2 canonical text")


func _t4() -> void:
	for row: Array in [[184729, 0, 0], [42, -1, -1], [I64MIN, I32MAX, I32MIN]]:
		var coordinate := Vector2i(row[1], row[2])
		var a := Generator.build(row[0], coordinate)
		var b := Generator.build(row[0], coordinate)
		var c := Generator.build(row[0], coordinate)
		_check(a.signature() == b.signature() and b.signature() == c.signature(), "T4 repeat signatures")
		_check(a != b and b != c and a != c, "T4 separately owned instances")


func _check_pair(a: Plan, b: Plan) -> void:
	_check(not a.get_identity().equals(b.get_identity()), "T5 distinct canonical identities")
	_check(a.signature() != b.signature(), "T5 distinct signatures")
	_check(a.get_identity().get_region_seed() != b.get_identity().get_region_seed(), "T5 distinct tested seeds")


func _grid_inputs() -> Array[Array]:
	var inputs: Array[Array] = []
	for world_seed: int in [184729, 42, 0]:
		for x in range(-2, 3):
			for y in range(-2, 3):
				inputs.append([world_seed, Vector2i(x, y)])
	return inputs


func _signature_map(inputs: Array[Array]) -> Dictionary:
	var result: Dictionary = {}
	for row: Array in inputs:
		var coordinate: Vector2i = row[1]
		var key: String = "%d:%d:%d" % [row[0], coordinate.x, coordinate.y]
		result[key] = Generator.build(row[0], coordinate).signature()
	return result


func _t5() -> void:
	for pair: Array in [[184729, 42], [0, -1], [I64MAX, I64MIN]]:
		_check_pair(Generator.build(pair[0], Vector2i.ZERO), Generator.build(pair[1], Vector2i.ZERO))
	for pair: Array in [[Vector2i(0, 0), Vector2i(1, 0)], [Vector2i(1, 2), Vector2i(2, 1)],
			[Vector2i(1, 0), Vector2i(-1, 0)], [Vector2i(0, 1), Vector2i(0, -1)]]:
		_check_pair(Generator.build(184729, pair[0]), Generator.build(184729, pair[1]))
	var unique_seeds: Dictionary = {}
	var unique_signatures: Dictionary = {}
	for row: Array in _grid_inputs():
		var plan := Generator.build(row[0], row[1])
		unique_seeds[plan.get_identity().get_region_seed()] = true
		unique_signatures[plan.signature()] = true
		var coordinate: Vector2i = row[1]
		print("REGION_DOMAIN_GRID w=%d x=%d y=%d seed=%d signature=%s" % [row[0], coordinate.x,
			coordinate.y, plan.get_identity().get_region_seed(), plan.signature()])
	_check(unique_seeds.size() == 75, "T5 75 distinct grid seeds")
	_check(unique_signatures.size() == 75, "T5 75 distinct grid signatures")


func _t6() -> void:
	var forward: Array[Array] = _grid_inputs()
	var expected: Dictionary = _signature_map(forward)
	var reverse: Array[Array] = _grid_inputs()
	reverse.reverse()
	_check(_signature_map(reverse) == expected, "T6 reverse construction order")
	var interleaved: Array[Array] = []
	for x in range(-2, 3):
		for y in range(-2, 3):
			for world_seed: int in [184729, 42, 0]:
				interleaved.append([world_seed, Vector2i(x, y)])
	_check(_signature_map(interleaved) == expected, "T6 coordinate-major interleaving")
	seed(1)
	var before: String = Generator.build(184729, Vector2i(-1, 2)).signature()
	seed(999999)
	for i in range(10):
		randi()
	_check(Generator.build(184729, Vector2i(-1, 2)).signature() == before, "T6 seeded global RNG independence")
	randomize()
	_check(Generator.build(184729, Vector2i(-1, 2)).signature() == before, "T6 randomized global RNG independence")
	seed(77)
	var expected_random: int = randi()
	seed(77)
	for x in range(-1, 2):
		for y in range(-1, 2):
			Generator.build(42, Vector2i(x, y))
	_check(randi() == expected_random, "T6 build consumes no global RNG")


func _t7() -> void:
	var cases := [
		[Vector2i(0, 0), 0, 0, 4096, 4096],
		[Vector2i(1, 0), 4096, 0, 8192, 4096],
		[Vector2i(-1, -1), -4096, -4096, 0, 0],
		[Vector2i(I32MIN, I32MIN), -8796093022208, -8796093022208, -8796093018112, -8796093018112],
		[Vector2i(I32MAX, I32MAX), 8796093018112, 8796093018112, 8796093022208, 8796093022208],
		[Vector2i(I32MIN, I32MAX), -8796093022208, 8796093018112, -8796093018112, 8796093022208],
	]
	for row: Array in cases:
		var bounds := Generator.build(184729, row[0]).get_bounds()
		_check(bounds.get_min_x_m() == row[1], "T7 exact min X " + str(row[0]))
		_check(bounds.get_min_z_m() == row[2], "T7 exact min Z " + str(row[0]))
		_check(bounds.get_max_x_m() == row[3], "T7 exact max X " + str(row[0]))
		_check(bounds.get_max_z_m() == row[4], "T7 exact max Z " + str(row[0]))
	var origin := Generator.build(184729, Vector2i.ZERO).get_bounds()
	_check(origin.get_size_m() == 4096, "T7 schema-v1 size")
	for coordinate: Vector2i in [Vector2i.ZERO, Vector2i(-1, -1),
			Vector2i(I32MAX - 1, I32MAX - 1), Vector2i(I32MIN, I32MIN)]:
		var current := Generator.build(184729, coordinate).get_bounds()
		var east := Generator.build(184729, coordinate + Vector2i(1, 0)).get_bounds()
		var north := Generator.build(184729, coordinate + Vector2i(0, 1)).get_bounds()
		_check(current.get_max_x_m() == east.get_min_x_m(), "T7 exact X seam " + str(coordinate))
		_check(current.get_max_z_m() == north.get_min_z_m(), "T7 exact Z seam " + str(coordinate))
	_check(origin.contains_world_xz(0.0, 0.0), "T7 origin min edges included")
	_check(origin.contains_world_xz(4095.999, 4095.999), "T7 interior near max edges")
	_check(not origin.contains_world_xz(4096.0, 0.0), "T7 max X excluded")
	_check(not origin.contains_world_xz(0.0, 4096.0), "T7 max Z excluded")
	_check(Generator.build(0, Vector2i(1, 0)).get_bounds().contains_world_xz(4096.0, 0.0), "T7 east owns seam")
	_check(Generator.build(0, Vector2i(0, 1)).get_bounds().contains_world_xz(0.0, 4096.0), "T7 north owns seam")
	var negative := Generator.build(0, Vector2i(-1, -1)).get_bounds()
	_check(negative.contains_world_xz(-0.5, -0.5), "T7 negative interior")
	_check(not negative.contains_world_xz(0.0, 0.0), "T7 negative max edges excluded")
	_check(origin.contains_world_xz(-0.0, -0.0), "T7 signed zero")
	_check(not origin.contains_world_xz(NAN, 0.0), "T7 NaN X")
	_check(not origin.contains_world_xz(0.0, NAN), "T7 NaN Z")
	_check(not origin.contains_world_xz(INF, 0.0), "T7 positive infinite X")
	_check(not origin.contains_world_xz(0.0, -INF), "T7 negative infinite Z")
	var upper := Generator.build(0, Vector2i(I32MAX, I32MAX)).get_bounds()
	var lower := Generator.build(0, Vector2i(I32MIN, I32MIN)).get_bounds()
	_check(upper.contains_world_xz(8796093018112.0, 8796093018112.0), "T7 upper extreme min included")
	_check(not upper.contains_world_xz(8796093022208.0, 8796093018112.0), "T7 upper extreme max excluded")
	_check(lower.contains_world_xz(-8796093022208.0, -8796093022208.0), "T7 lower extreme min included")
	_check(not lower.contains_world_xz(-8796093018112.0, -8796093022208.0), "T7 lower extreme max excluded")


func _t8() -> void:
	for world_seed: int in [I64MIN, I64MAX, 0, -1]:
		var plan := Generator.build(world_seed, Vector2i.ZERO)
		_check(plan != null and plan.validate() == {"is_valid": true, "reason_codes": []}, "T8 total seed domain")
	for coordinate: Vector2i in [Vector2i(I32MIN, I32MIN), Vector2i(I32MIN, I32MAX),
			Vector2i(I32MAX, I32MIN), Vector2i(I32MAX, I32MAX)]:
		var plan := Generator.build(184729, coordinate)
		_check(plan != null and plan.validate() == {"is_valid": true, "reason_codes": []}, "T8 total coordinate domain")


func _t9() -> void:
	for script: Script in [Seeds, Identity, Bounds, MacroTerrain, Plan, Generator]:
		_check(script.get_instance_base_type() == "RefCounted", "T9 pure-domain base " + script.resource_path)
	var plan := Generator.build(184729, Vector2i(-1, 2))
	_check(plan.get_macro_terrain().get_state() == "GENERATED_R1", "T9 macro schema state")
	for part: RefCounted in [plan, plan.get_macro_terrain()]:
		var absent: bool = true
		for method: String in ["sample_height", "sample_gradient", "sample_normal", "get_height"]:
			absent = absent and not part.has_method(method)
		_check(absent, "T9 no geography query API")
	var identity := plan.get_identity()
	_check(identity.get_region_seed() == Seeds.region_seed(184729, Vector2i(-1, 2)), "T9 derived identity seed")
	_check(identity.equals(Generator.build(184729, Vector2i(-1, 2)).get_identity()), "T9 same canonical identity")
	_check(not identity.equals(null) and not identity.equals(Generator.build(42, Vector2i(-1, 2)).get_identity()),
		"T9 null and different canonical identity")


func _t10() -> void:
	# Deliberate privacy violations confined to negative diagnostic fixtures.
	var seed_plan := Generator.build(184729, Vector2i.ZERO)
	seed_plan.get_identity()._region_seed += 1
	_check(seed_plan.validate() == {"is_valid": false, "reason_codes": ["ERR_REGION_SEED_MISMATCH"]},
		"T10 exact seed mismatch diagnostic")
	var bounds_plan := Generator.build(184729, Vector2i.ZERO)
	bounds_plan._bounds = Bounds.new(Vector2i(1, 0))
	_check(bounds_plan.validate() == {"is_valid": false, "reason_codes": ["ERR_REGION_BOUNDS_MISMATCH"]},
		"T10 exact bounds mismatch diagnostic")
	var missing_plan := Generator.build(184729, Vector2i.ZERO)
	missing_plan._macro_terrain = null
	_check(missing_plan.validate() == {"is_valid": false, "reason_codes": ["ERR_REGION_PART_MISSING"]},
		"T10 exact missing-part diagnostic")


func _t11() -> void:
	var plan := Generator.build(184729, Vector2i(-1, 2))
	var before: String = plan.signature()
	var identity := plan.get_identity()
	identity.get_world_seed()
	identity.get_region_seed()
	identity.equals(identity)
	var coordinate: Vector2i = identity.get_region_coordinate()
	coordinate.x += 1
	coordinate.y -= 1
	var bounds := plan.get_bounds()
	bounds.get_size_m()
	bounds.get_min_x_m()
	bounds.get_min_z_m()
	bounds.get_max_x_m()
	bounds.get_max_z_m()
	bounds.contains_world_xz(0.0, 0.0)
	plan.get_macro_terrain().get_state()
	plan.canonical_text()
	plan.validate()
	_check(plan.signature() == before and identity.get_region_coordinate() == Vector2i(-1, 2),
		"T11 getters and caller coordinate mutation preserve aggregate")
