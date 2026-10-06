extends SceneTree

## R1 macro-geography domain suite (headless). Protects determinism,
## totality, numerical safety, structural invariants of the ridge-network
## construction, compositional seed variation and exact validation reasons.
## Subjective geographic quality is judged on Vulkan captures, not here.

const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Identity = preload("res://scripts/world/region/region_identity.gd")
const Bounds = preload("res://scripts/world/region/region_bounds.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const Geography = preload("res://scripts/world/region/macro_geography_generator.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const Plan = preload("res://scripts/world/region/region_plan.gd")
const Generator = preload("res://scripts/world/region/region_generator.gd")
const I64MIN: int = -9223372036854775807 - 1
const I64MAX: int = 9223372036854775807
const I32MIN: int = -2147483648
const I32MAX: int = 2147483647
const SEED_ROWS := [
	[1944063217383134986, 8254910480733202536, 0xf2, 6288223437005019402, 0x57],
	[8498422420403868873, 7155498265729271401, 0xe3, 7290266214267829223, 0xe5],
	[749671650299037083, 2877886576196208939, 0x27, 3566983675252739633, 0x31],
	[5466766008934095593, 1891129689569849483, 0x9a, 7842700507623563724, 0xec],
	[1495971027060834261, 2946979697831959287, 0x28, 6944007839919045961, 0x60],
	[6780184215550171328, 4247225128377747827, 0xba, 5428703941766576889, 0xcb],
	[3908217619317152525, 8726502944955122418, 0xf9, 6416079127949548725, 0x59],
]
const SWEEP_COUNT: int = 1000
## Spike/discontinuity detector on 4 m transects, not a rideability limit
## (rideability belongs to later phases). Observed maxima are ~1.2-2.3.
const MAX_GRADE: float = 5.0
const MACRO_TEXT := "slow_cycle.macro_terrain/2\nstate=GENERATED_R1\narchetype=MOUNTAIN_RIVER_VALLEY\nstructure_seed=8254910480733202536\nnoise_seed=6288223437005019402\ndomain_size_m=4096\nframe_symmetry=2\nrelief_cm=97097\ncomposition.valley_form=1\ncomposition.range_form=0\ncomposition.crest_shape=2\ncomposition.far_form=0\nbase.floor_elevation_cm=29073\nbase.floor_drop_cm=5673\nvalley.basin_u_m=2955\nvalley.basin_extra_m=379\nvalley.basin_half_length_m=701\nvalley.near_wall_width_m=363\nvalley.near_wall_height_cm=10981\nvalley.near_upland_permille=48\nvalley.far_wall_width_m=452\nvalley.far_wall_height_cm=3620\nvalley.far_upland_permille=51\nridge.profile_permille=1510\nridge.spur_profile_permille=1360\nridge.crest_rounding_m=45\nridge.rib_permille=91\nridge.rib_wavelength_m=417\nridge.warp_amplitude_m=129\nridge.warp_wavelength_m=1107\nnoise.algorithm=slow_cycle.lattice_value_noise/2\nnoise.amplitude_cm=4389\nnoise.wavelengths_m=640,320,160\nnoise.weights_permille=550,300,150\nnoise.ridged_permille=476\nnoise.valley_floor_permille=300\nnoise.bench_permille=300\nnoise.basin_permille=300\nvalley_points.count=9\nvalley_points.0=1205,102,1267,1180\nvalley_points.1=1347,74,1076,1167\nvalley_points.2=1262,116,900,965\nvalley_points.3=1274,128,766,796\nvalley_points.4=1427,120,824,929\nvalley_points.5=1313,99,1047,988\nvalley_points.6=1444,130,1092,1165\nvalley_points.7=1321,129,838,964\nvalley_points.8=1402,127,724,867\nmain_nodes.count=7\nmain_nodes.0=33,2725,0,36735,929,1283\nmain_nodes.1=636,2518,1,75903,772,1014\nmain_nodes.2=1415,2420,2,47733,743,1194\nmain_nodes.3=2033,2456,1,60670,655,1283\nmain_nodes.4=2766,2490,2,43418,767,1001\nmain_nodes.5=3388,2631,1,80443,891,1160\nmain_nodes.6=4044,2826,0,50748,815,1515\nfar_nodes.count=5\nfar_nodes.0=867,197,0,6523,425,672\nfar_nodes.1=1419,144,1,25934,649,434\nfar_nodes.2=1882,284,2,17440,567,620\nfar_nodes.3=2311,342,1,34766,710,636\nfar_nodes.4=2901,419,0,9680,622,687\nspurs.count=11\nspurs.0=0,1,3642,2270,3768,2172,3895,2074,52449,39337,22973,459\nspurs.1=0,0,3393,2633,3642,2270,3639,1843,75763,54549,14325,592\nspurs.2=0,0,604,2529,656,2166,416,1799,71986,56221,15341,696\nspurs.3=0,1,1925,2197,1757,2026,1589,1855,49536,37152,21548,381\nspurs.4=0,0,2024,2455,1925,2197,2010,1912,58649,51142,16964,857\nspurs.5=0,1,3140,2221,3013,2139,2887,2058,53880,40410,23546,402\nspurs.6=0,1,3140,2221,3235,1940,3330,1659,52761,39571,20893,419\nspurs.7=0,0,3185,2585,3140,2221,2990,1959,66869,54498,16804,456\nspurs.8=0,0,444,2584,291,2168,91,1707,64028,50134,14419,555\nspurs.9=0,0,2257,2466,2457,2180,2644,1705,52244,42579,15910,502\nspurs.10=1,0,1877,283,1952,459,2028,636,15492,10458,5424,397\nbenches.count=2\nbenches.0=1,369,1760,484,225\nbenches.1=-1,2362,3461,612,175\nbasins.count=0\n"
const SIGNATURE_ANCHORS := [
	[184729, 0, 0, "5af30b504921f425e8f945e1c6ff3e69776c228a6bbaeb4e908f5564e3e0ac97", "1e28fe1846cd0fa96b0c8cc7d153abd83703a14b9eaa1718b21e24cad69f6278"],
	[42, 0, 0, "a16cc2a054e9443daa48d123f8e6ca7665798fb758b6c579a6acd1983fe56cfa", "5518e1b59b6c0280e1026a9ac8a58b94144b0447b6d1f04e5b29efdb287be964"],
	[77777, 0, 0, "23c37c1439577e71f46776f13ba7ca54b515c378d008d804fd206032b78a8c1f", "60ac5d0fe9f509f9ca30a21d85c753abb70359f96a2d4cb32575abbf3c089957"],
	[184729, -1, -1, "4e06d0163258e1f46acbdf0115ec47e348298e8380fac25b3c1fba1014e30c07", "3170d27b86cf95fc704dfc02c3f9706771222cea112ef3ba6dbfa3732570c176"],
]
const OWN_CHECKS: int = 4269

var checks: int = 0
var failures: int = 0
var _cases: Array = []
var _macros: Array = []


func _init() -> void:
	for path: String in ["scripts/world/region/region_seed_derivation.gd", "scripts/world/region/macro_terrain_plan.gd", "scripts/world/region/region_plan.gd", "scripts/world/region/region_generator.gd", "scripts/world/region/macro_geography_generator.gd", "scripts/world/region/macro_terrain_evaluator.gd", "scripts/world/region_preview.gd", "scripts/test/test_region_domain_skeleton.gd", "scripts/test/test_region_preview.gd", "scripts/test/capture_region_preview.gd", "scenes/world/region_preview.tscn"]:
		_check(load("res://" + path) != null, "E0 explicit resource load " + path)
	for w: int in [184729, 42, 77777]:
		for c: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, -1), Vector2i(3, -2)]:
			_cases.append([w, c])
	_cases.append_array([[0, Vector2i.ZERO], [-1, Vector2i.ZERO], [I64MIN, Vector2i(I32MAX, I32MIN)], [I64MAX, Vector2i(I32MIN, I32MAX)]])
	for row: Array in _cases:
		var macro: Macro = _build(row[0], row[1])
		if macro == null:
			print("MACRO_GEOGRAPHY_SUMMARY construction_aborted=true checks=%d failures=%d" % [checks, failures])
			quit(1)
			return
		_macros.append(macro)
		print("MACRO_FIXTURE w=%d x=%d z=%d signature=%s composition=%s symmetry=%d" % [row[0], row[1].x, row[1].y, macro.signature(), JSON.stringify(macro.get_data().composition), macro.get_data().frame_symmetry])
	for group: Callable in [_g1, _g2, _g3, _g4, _g5, _g6, _g7, _g8, _g9, _g10]:
		var before: int = checks
		var failed_before: int = failures
		var start: int = Time.get_ticks_msec()
		group.call()
		print("MACRO_GROUP name=%s checks=%d failures=%d" % [group.get_method(), checks - before, failures - failed_before])
		printerr("MACRO_GROUP_TIME name=%s ms=%d" % [group.get_method(), Time.get_ticks_msec() - start])
	_check(checks + 1 == OWN_CHECKS, "fixed own check count %d" % (checks + 1))
	print("MACRO_GEOGRAPHY_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MACRO_GEOGRAPHY_FAIL " + message)


func _build(w: int, c: Vector2i) -> Macro:
	var plan := Generator.build(w, c)
	_check(plan != null and plan.validate() == {"is_valid": true, "reason_codes": []}, "producer boundary w=%d c=%s" % [w, c])
	return plan.get_macro_terrain() if plan != null else null


func _structure(macro: Macro, frame: Vector2) -> float:
	var local: Vector2 = Macro.frame_to_local(macro.get_data().frame_symmetry, frame.x, frame.y)
	var result: Dictionary = Eval.evaluate_structure_elevation_m(macro, clampf(local.x, 0, 4096), clampf(local.y, 0, 4096))
	_check(result.is_valid and is_finite(result.elevation_m), "probe valid " + str(frame))
	return result.elevation_m


## Crest elevation at a crest node: highest structure sample on a line across
## the crest through the node (tolerates the bounded domain warp without
## climbing along the crest towards neighbouring nodes).
func _crest_height(macro: Macro, nodes: Array, i: int) -> float:
	var along: Vector2 = (Vector2(nodes[mini(i + 1, nodes.size() - 1)].u_m, nodes[mini(i + 1, nodes.size() - 1)].v_m) - Vector2(nodes[maxi(i - 1, 0)].u_m, nodes[maxi(i - 1, 0)].v_m)).normalized()
	var across := Vector2(-along.y, along.x)
	var best: float = -INF
	for o in range(-12, 13):
		best = maxf(best, _structure(macro, Vector2(nodes[i].u_m, nodes[i].v_m) + across * o * 15.0))
	return best


# G1 — registered child seed contracts (literal goldens, unchanged).
func _g1() -> void:
	var token := RegEx.new()
	_check(token.compile("^[a-z][a-z0-9_]{0,63}$") == OK, "G1 token grammar compiles")
	for purpose: String in [Seeds.PURPOSE_MACRO_STRUCTURE, Seeds.PURPOSE_MACRO_NOISE]:
		_check(token.search(purpose) != null, "G1 token " + purpose)
	_check(Seeds.PURPOSE_MACRO_STRUCTURE != Seeds.PURPOSE_MACRO_NOISE, "G1 distinct purposes")
	for row: Array in SEED_ROWS:
		var parent: int = row[0]
		for lane: int in [0, 1]:
			var purpose: String = "macro_structure" if lane == 0 else "macro_noise"
			var expected: String = "slow_cycle.seed/1\npurpose=" + purpose + "\ncount=1\nv0=" + str(parent) + "\n"
			var actual: String = Seeds.macro_structure_seed_preimage(parent) if lane == 0 else Seeds.macro_noise_seed_preimage(parent)
			var value: int = Seeds.macro_structure_seed(parent) if lane == 0 else Seeds.macro_noise_seed(parent)
			_check(actual == expected, "G1 literal preimage " + purpose)
			_check(value == row[1 + lane * 2], "G1 literal child seed " + purpose)
			_check(actual.sha256_buffer()[0] == row[2 + lane * 2], "G1 literal first byte " + purpose)
			_check(value != parent, "G1 child differs from parent " + purpose)


func _order_map(order: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Array in order:
		result[str(row)] = Generator.build(row[0], row[1]).signature()
	return result


# G2 — determinism, order independence, global RNG isolation, grid parity.
func _g2() -> void:
	for index: int in [0, 4, 8, 12, 14, 15]:
		var row: Array = _cases[index]
		var a: Macro = _macros[index]
		var b: Macro = _build(row[0], row[1])
		var c: Macro = _build(row[0], row[1])
		_check(a.canonical_text() == b.canonical_text() and b.canonical_text() == c.canonical_text(), "G2 repeated canonical text")
		_check(a.signature() == b.signature() and b.signature() == c.signature(), "G2 repeated signature")
		_check(a != b and b != c, "G2 independent instances")
	var order: Array = []
	for w: int in [184729, 42, 77777]:
		for c: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, -1), Vector2i(0, 1)]:
			order.append([w, c])
	var forward: Dictionary = _order_map(order)
	order.reverse()
	_check(_order_map(order) == forward, "G2 reverse build order")
	seed(1)
	var signature: String = Generator.build(184729, Vector2i.ZERO).signature()
	seed(999999)
	for i in range(10):
		randi()
	_check(Generator.build(184729, Vector2i.ZERO).signature() == signature, "G2 prior global draws")
	randomize()
	_check(Generator.build(184729, Vector2i.ZERO).signature() == signature, "G2 global randomize")
	seed(77)
	var expected: int = randi()
	seed(77)
	for row: Array in _cases:
		Generator.build(row[0], row[1])
	var sampled: Dictionary = Eval.sample_grid(_macros[0], 0, 0, 512, 9, 9, true)
	Eval.evaluate_elevation_m(_macros[0], 100, 100)
	_check(randi() == expected, "G2 generation and evaluation consume no global RNG")
	for index: int in [0, 4, 8, 15]:
		var macro: Macro = _macros[index]
		for include_noise: bool in [false, true]:
			var grid: Dictionary = Eval.sample_grid(macro, 0, 0, 512, 9, 9, include_noise)
			_check(grid.is_valid and grid.elevations_m.size() == 81, "G2 grid shape")
			var same: bool = true
			for j in range(9):
				for i in range(9):
					var point: Dictionary = Eval.evaluate_elevation_m(macro, i * 512, j * 512) if include_noise else Eval.evaluate_structure_elevation_m(macro, i * 512, j * 512)
					same = same and point.elevation_m == grid.elevations_m[j * 9 + i]
			_check(same, "G2 sample_grid bit-identical to point API fixture=%d noise=%s" % [index, include_noise])
		var text: String = ""
		for h: float in Eval.sample_grid(macro, 0, 0, 64, 65, 65, true).elevations_m:
			text += "%d\n" % roundi(h * 100)
		print("MACRO_DETERMINISM_GRID fixture=%d sha256=%s" % [index, text.sha256_text()])


# G3 — regression anchors (frozen after visual acceptance; not correctness).
func _g3() -> void:
	_check(SIGNATURE_ANCHORS.size() == 4, "G3 anchor set")
	_check(_macros[0].canonical_text() == MACRO_TEXT, "G3 exact macro canonical text 184729")
	for row: Array in SIGNATURE_ANCHORS:
		var plan := Generator.build(row[0], Vector2i(row[1], row[2]))
		_check(plan.get_macro_terrain().signature() == row[3], "G3 macro signature " + str(row[0]))
		_check(plan.signature() == row[4], "G3 RegionPlan signature " + str(row[0]))


var _sweep: Array = []


# G4 — totality and validity over a seed sweep plus R0 extremes.
func _g4() -> void:
	var invalid: int = 0
	for i in range(SWEEP_COUNT):
		var w: int = i * 2654435761 - 977
		var plan := Generator.build(w, Vector2i(i % 7 - 3, i % 5 - 2))
		if plan == null or not plan.validate().is_valid:
			invalid += 1
			continue
		_sweep.append(plan.get_macro_terrain().get_data())
	_check(invalid == 0, "G4 sweep of %d regions: %d invalid" % [SWEEP_COUNT, invalid])
	for w: int in [I64MIN, I64MAX, 0, -1]:
		for c: Vector2i in [Vector2i(I32MIN, I32MIN), Vector2i(I32MIN, I32MAX), Vector2i(I32MAX, I32MIN), Vector2i(I32MAX, I32MAX), Vector2i.ZERO]:
			_check(_build(w, c) != null, "G4 extreme w=%d c=%s" % [w, c])


# G5 — numerical safety: finite closed domain, noise bound, continuity.
func _g5() -> void:
	for index: int in [0, 4, 8, 12, 14, 15]:
		var macro: Macro = _macros[index]
		var data: Dictionary = macro.get_data()
		var amplitude: float = data.noise.amplitude_cm / 100.0
		_check(100 * data.noise.amplitude_cm <= 6 * data.relief_cm and data.noise.amplitude_cm > 0, "G5 noise budget")
		var structure: Dictionary = Eval.sample_grid(macro, 0, 0, 32, 129, 129, false)
		var final: Dictionary = Eval.sample_grid(macro, 0, 0, 32, 129, 129, true)
		var finite: bool = structure.is_valid and final.is_valid
		var bounded: bool = true
		for k in range(129 * 129):
			finite = finite and is_finite(structure.elevations_m[k]) and is_finite(final.elevations_m[k])
			bounded = bounded and absf(final.elevations_m[k] - structure.elevations_m[k]) <= amplitude
		_check(finite, "G5 finite closed domain fixture=%d" % index)
		_check(bounded, "G5 |final-structure| <= amplitude fixture=%d" % index)
		var steepest: float = 0.0
		for fixed: float in [512.0, 1536.0, 2560.0, 3584.0]:
			for along_x: bool in [true, false]:
				var line: Dictionary = Eval.sample_grid(macro, 0.0 if along_x else fixed, fixed if along_x else 0.0, 4.0, 1025 if along_x else 1, 1 if along_x else 1025, true)
				for k in range(1, 1025):
					steepest = maxf(steepest, absf(line.elevations_m[k] - line.elevations_m[k - 1]) / 4.0)
		_check(steepest <= MAX_GRADE, "G5 continuity fixture=%d steepest=%.3f" % [index, steepest])
		print("MACRO_CONTINUITY fixture=%d steepest_grade=%.3f" % [index, steepest])


# G6 — structural invariants of the construction (structure field).
func _g6() -> void:
	for fixture in range(12):
		var macro: Macro = _macros[fixture]
		var data: Dictionary = macro.get_data()
		var label: String = " fixture=%d" % fixture
		# Valley: floor lower than both walls along the whole valley.
		var floor_min: float = INF
		for k in range(9):
			var u: float = 256.0 + 448.0 * k
			var axis: Vector2 = Macro.valley_axis(data, u)
			var halves: Vector2 = Macro.floor_half_widths(data, u)
			var centre: float = _structure(macro, Vector2(u, axis.x))
			floor_min = minf(floor_min, centre)
			var near: float = _structure(macro, Vector2(u, axis.x + halves.x + Macro.valley_wall(data, u, true).x + 250))
			var far: float = _structure(macro, Vector2(u, axis.x - halves.y - Macro.valley_wall(data, u, false).x - 250))
			_check(near >= centre + 20.0 and far >= centre + 20.0, "G6 valley cross-section u=%d%s" % [u, label])
		# Crest: summits above neighbouring passes; passes above the valley.
		var main: Array = data.main_nodes
		var peak: float = -INF
		for i in range(2, main.size() - 2, 2):
			var saddle: float = _crest_height(macro, main, i)
			var valley_floor: float = _structure(macro, Vector2(main[i].u_m, Macro.valley_axis(data, main[i].u_m).x))
			_check(saddle >= valley_floor + 100.0, "G6 pass above valley%s" % label)
			for j: int in [i - 1, i + 1]:
				var summit: float = _crest_height(macro, main, j)
				peak = maxf(peak, summit)
				_check(summit >= saddle + 30.0, "G6 summit above pass%s summit=%.1f pass=%.1f" % [label, summit, saddle])
		_check(peak >= floor_min + 300.0, "G6 relief%s" % label)
		# Spurs: most valley spurs stand above their lateral flanks.
		var standing: int = 0
		var total: int = 0
		for spur: Dictionary in data.spurs:
			if spur.group != Macro.GROUP_MAIN or spur.kind != Macro.SPUR_VALLEY:
				continue
			total += 1
			# Probe the upper half of the spur, away from where branches attach.
			var middle: Vector2 = (Vector2(spur.au_m, spur.av_m) + Vector2(spur.mu_m, spur.mv_m)) / 2.0
			var along: Vector2 = (Vector2(spur.mu_m, spur.mv_m) - Vector2(spur.au_m, spur.av_m)).normalized()
			var across := Vector2(-along.y, along.x)
			# The bounded warp may shift the spur crest sideways: look for a
			# local crest within 0.6 W of the descriptor line that stands 10 m
			# above the terrain half a width to either side of it.
			var profile: Array[float] = []
			for o in range(-11, 12):
				profile.append(_structure(macro, middle + across * o * 0.1 * spur.width_m))
			var ridge: bool = false
			for o in range(5, 18):
				ridge = ridge or profile[o] >= maxf(profile[o - 5], profile[o + 5]) + 10.0
			standing += 1 if ridge else 0
		_check(2 * standing > total, "G6 spurs readable%s %d/%d" % [label, standing, total])
		# Benches: core flatter than the wall below it.
		for bench: Dictionary in data.benches:
			var u: float = (bench.u_a_m + bench.u_b_m) / 2.0
			var near: bool = bench.side > 0
			var axis: float = Macro.valley_axis(data, u).x
			var edge: float = Macro.floor_half_widths(data, u).x if near else Macro.floor_half_widths(data, u).y
			var e1: float = 0.4 * Macro.valley_wall(data, u, near).x
			var at := func(excess: float) -> float: return _structure(macro, Vector2(u, axis + bench.side * (edge + excess)))
			var lower: float = absf(at.call(e1) - at.call(0.0)) / e1
			var core: float = absf(at.call(e1 + 0.75 * bench.width_m) - at.call(e1 + 0.25 * bench.width_m)) / (0.5 * bench.width_m)
			_check(core <= 0.6 * lower, "G6 bench flatter than wall%s core=%.3f lower=%.3f" % [label, core, lower])
		# Upland basin: floor below its surroundings.
		for basin: Dictionary in data.basins:
			var centre := Vector2(basin.u_m, basin.v_m)
			var reach: Vector2i = Macro.basin_reach(basin.radius_m, basin.elongation_permille, basin.orientation_deg)
			var rim: Array[float] = []
			for k in range(16):
				var direction := Vector2(cos(k * TAU / 16), sin(k * TAU / 16))
				rim.append(_structure(macro, centre + Vector2(direction.x * reach.x, direction.y * reach.y) * 1.3))
			rim.sort()
			_check(_structure(macro, centre) <= rim[8] - 5.0, "G6 basin below rim%s" % label)


func _normalized_grid(macro: Macro) -> PackedFloat64Array:
	var grid: PackedFloat64Array = Eval.sample_grid(macro, 0, 0, 128, 33, 33, false).elevations_m
	var mean: float = 0.0
	for h: float in grid:
		mean += h / grid.size()
	var variance: float = 0.0
	for h: float in grid:
		variance += (h - mean) * (h - mean) / grid.size()
	var result := PackedFloat64Array()
	for h: float in grid:
		result.append((h - mean) / sqrt(variance))
	return result


# G7 — compositional seed variation.
func _g7() -> void:
	var references: Array = [_macros[0], _macros[4], _macros[8]]
	var layouts: Array = []
	for macro: Macro in references:
		var data: Dictionary = macro.get_data()
		layouts.append([data.composition.valley_form, data.composition.range_form, data.composition.crest_shape, data.composition.far_form])
	for pair: Array in [[0, 1], [0, 2], [1, 2]]:
		_check(layouts[pair[0]] != layouts[pair[1]], "G7 reference compositions differ %s %s" % [layouts[pair[0]], layouts[pair[1]]])
	var grids: Array = []
	for macro: Macro in references:
		grids.append(_normalized_grid(macro))
	for pair: Array in [[0, 1], [0, 2], [1, 2]]:
		_check(references[pair[0]].signature() != references[pair[1]].signature(), "G7 reference signatures differ")
		var rms: float = 0.0
		for k in range(grids[0].size()):
			rms += pow(grids[pair[0]][k] - grids[pair[1]][k], 2) / grids[0].size()
		# Normalized fields: identical = 0, uncorrelated ~ 1.41.
		_check(sqrt(rms) >= 0.3, "G7 reference height fields differ rms=%.3f" % sqrt(rms))
		print("MACRO_REFERENCE_FIELD_RMS pair=%s rms=%.3f" % [pair, sqrt(rms)])
	var counts: Dictionary = {}
	for data: Dictionary in _sweep:
		var summits: int = (data.main_nodes.size() - 1) / 2
		for key: String in ["valley_form=%d" % data.composition.valley_form, "range_form=%d" % data.composition.range_form, "crest_shape=%d" % data.composition.crest_shape, "far_form=%d" % data.composition.far_form, "symmetry=%d" % data.frame_symmetry, "summits=%d" % summits, "basins=%d" % data.basins.size()]:
			counts[key] = counts.get(key, 0) + 1
	print("MACRO_VARIATION " + JSON.stringify(counts))
	var expected: Array = ["valley_form=0", "valley_form=1", "range_form=0", "range_form=1", "range_form=2", "crest_shape=0", "crest_shape=1", "crest_shape=2", "far_form=0", "far_form=1", "far_form=2", "summits=2", "summits=3", "summits=4", "basins=0", "basins=1"]
	for symmetry in range(8):
		expected.append("symmetry=%d" % symmetry)
	for key: String in expected:
		_check(counts.get(key, 0) >= _sweep.size() / 20, "G7 %s occurs in >= 5%% of the sweep (%d)" % [key, counts.get(key, 0)])


# G8 — purity and API surface.
func _g8() -> void:
	for script: Script in [Seeds, Identity, Bounds, Macro, Geography, Eval, Plan, Generator]:
		_check(script.get_instance_base_type() == "RefCounted", "G8 domain base " + script.resource_path)
		var source: String = script.source_code
		for token: String in ["get_tree", "Node3D", "MeshInstance", "RenderingServer", "randomize(", "randi()", "Time.", "MountainMassifField"]:
			_check(not token in source, "G8 %s free of %s" % [script.resource_path, token])
	for macro: Macro in _macros:
		var signature: String = macro.signature()
		var data: Dictionary = macro.get_data()
		data.base.floor_elevation_cm += 1
		data.main_nodes.clear()
		_check(macro.signature() == signature, "G8 getters return copies")
		for method: String in ["sample_height", "sample_gradient", "sample_normal", "get_height"]:
			_check(not macro.has_method(method), "G8 absent " + method)
	var plan := Generator.build(184729, Vector2i.ZERO)
	for method: String in ["sample_height", "sample_gradient", "sample_normal", "get_height"]:
		_check(not plan.has_method(method), "G8 plan absent " + method)


func _negative(data: Dictionary, expected: Array, label: String) -> void:
	var result: Dictionary = Macro.new(data).validate()
	_check(result == {"is_valid": false, "reason_codes": expected}, "G9 " + label + " " + str(result))


func _eval_negative(result: Dictionary, reason: String, label: String) -> void:
	_check(not result.is_valid and result.reason_code == reason and (is_nan(result.elevation_m) if result.has("elevation_m") else result.elevations_m.is_empty()), "G9 " + label + " " + str(result.reason_code))


# G9 — exact validation and evaluator reasons.
func _g9() -> void:
	var source: Dictionary = _macros[0].get_data()
	var data: Dictionary = source.duplicate(true)
	data.archetype = "OTHER"
	_negative(data, ["ERR_MACRO_ARCHETYPE"], "archetype")
	data = source.duplicate(true)
	data.erase("valley")
	_negative(data, ["ERR_MACRO_SCHEMA"], "missing section")
	data = source.duplicate(true)
	data.base.floor_drop_cm = 2500.5
	_negative(data, ["ERR_MACRO_SCHEMA"], "non-integer value")
	data = source.duplicate(true)
	data.frame_symmetry = 8
	_negative(data, ["ERR_MACRO_SCHEMA"], "symmetry out of range")
	data = source.duplicate(true)
	data.valley_points[4].v_m = 3000
	_negative(data, ["ERR_MACRO_VALLEY"], "valley point jump")
	data = source.duplicate(true)
	data.main_nodes = []
	_negative(data, ["ERR_MACRO_MOUNTAIN_COUNT", "ERR_MACRO_RIDGE_COUNT", "ERR_MACRO_SADDLE_COUNT"], "no crest")
	data = source.duplicate(true)
	var crest: Array = []
	for j in range(11):
		var u: int = 100 + j * 390
		var kind: int = Macro.NODE_END if j == 0 or j == 10 else (Macro.NODE_SUMMIT if j % 2 == 1 else Macro.NODE_SADDLE)
		crest.append({"u_m": u, "v_m": roundi(Macro.valley_axis(data, u).x) + 1500, "kind": kind, "height_cm": 60000 if kind == Macro.NODE_SUMMIT else 30000, "near_width_m": 900, "far_width_m": 1200})
	data.main_nodes = crest
	_negative(data, ["ERR_MACRO_MOUNTAIN_COUNT"], "five summits in a well-formed crest")
	# Only the END, SUMMIT, (SADDLE, SUMMIT)*, END order is broken: counts,
	# heights and saddle depths are all individually valid.
	data = source.duplicate(true)
	crest = []
	var order: Array = [[Macro.NODE_END, 30000], [Macro.NODE_SADDLE, 20000], [Macro.NODE_SUMMIT, 60000], [Macro.NODE_SUMMIT, 60000], [Macro.NODE_SADDLE, 30000], [Macro.NODE_SUMMIT, 60000], [Macro.NODE_END, 30000]]
	for j in range(order.size()):
		var u: int = 200 + j * 600
		crest.append({"u_m": u, "v_m": roundi(Macro.valley_axis(data, u).x) + 1500, "kind": order[j][0], "height_cm": order[j][1], "near_width_m": 900, "far_width_m": 1200})
	data.main_nodes = crest
	_negative(data, ["ERR_MACRO_FEATURE_SHAPE"], "crest kind order broken")
	data = source.duplicate(true)
	data.spurs = []
	_negative(data, ["ERR_MACRO_RIDGE_COUNT"], "no spurs")
	data = source.duplicate(true)
	var valley_spur: Dictionary = {}
	for spur: Dictionary in data.spurs:
		if spur.group == Macro.GROUP_MAIN and spur.kind == Macro.SPUR_VALLEY:
			valley_spur = spur
	while data.spurs.filter(func(spur: Dictionary) -> bool: return spur.group == Macro.GROUP_MAIN and spur.kind == Macro.SPUR_VALLEY).size() < 7:
		data.spurs.append(valley_spur.duplicate())
	_negative(data, ["ERR_MACRO_RIDGE_COUNT"], "seven valley spurs")
	data = source.duplicate(true)
	data.main_nodes[2].height_cm = data.main_nodes[1].height_cm
	_negative(data, ["ERR_MACRO_FEATURE_SHAPE"], "pass not below summit")
	data = source.duplicate(true)
	data.benches = []
	_negative(data, ["ERR_MACRO_BENCH_COUNT"], "no bench")
	data = source.duplicate(true)
	data.benches = [data.benches[0], data.benches[0], data.benches[0]]
	_negative(data, ["ERR_MACRO_BENCH_COUNT"], "three benches")
	data = source.duplicate(true)
	var basin: Dictionary = {"u_m": 2048, "v_m": 600, "radius_m": 300, "depth_cm": 2000, "orientation_deg": 0, "elongation_permille": 1200}
	data.basins = [basin, basin]
	_negative(data, ["ERR_MACRO_BASIN_COUNT"], "two upland basins")
	data = source.duplicate(true)
	data.spurs[0].bu_m = -1
	_negative(data, ["ERR_MACRO_FEATURE_BOUNDS"], "anchor outside region")
	data = source.duplicate(true)
	data.composition.far_form = Macro.FAR_OPEN if not data.far_nodes.is_empty() else Macro.FAR_RIDGE
	_negative(data, ["ERR_MACRO_FEATURE_SHAPE"], "composition contradicts far side")
	data = source.duplicate(true)
	data.noise.amplitude_cm = data.relief_cm
	_negative(data, ["ERR_MACRO_NOISE_BUDGET"], "noise above 6 percent")
	data = source.duplicate(true)
	data.base.floor_elevation_cm += 1
	_check(Macro.new(data).signature() != _macros[0].signature(), "G9 in-range tamper changes signature")
	var bad_state := Macro.new(source)
	bad_state._state = "BAD"
	_check(bad_state.validate() == {"is_valid": false, "reason_codes": ["ERR_MACRO_SCHEMA"]}, "G9 bad state")
	var swapped := Generator.build(184729, Vector2i.ZERO)
	swapped._macro_terrain = Generator.build(42, Vector2i.ZERO).get_macro_terrain()
	_check(swapped.validate() == {"is_valid": false, "reason_codes": ["ERR_MACRO_SEED_MISMATCH"]}, "G9 swapped macro seeds")
	var state_plan := Generator.build(184729, Vector2i.ZERO)
	state_plan.get_macro_terrain()._state = "BAD"
	_check(state_plan.validate() == {"is_valid": false, "reason_codes": ["ERR_MACRO_TERRAIN_STATE", "ERR_MACRO_SCHEMA"]}, "G9 composite state")
	for value: float in [NAN, INF, -INF]:
		for along_x: bool in [true, false]:
			for evaluation: Callable in [Eval.evaluate_structure_elevation_m, Eval.evaluate_elevation_m]:
				_eval_negative(evaluation.call(_macros[0], value if along_x else 0.0, 0.0 if along_x else value), "ERR_EVAL_NONFINITE_INPUT", "nonfinite")
	for value: float in [-0.001, 4096.001]:
		for along_x: bool in [true, false]:
			for evaluation: Callable in [Eval.evaluate_structure_elevation_m, Eval.evaluate_elevation_m]:
				_eval_negative(evaluation.call(_macros[0], value if along_x else 0.0, 0.0 if along_x else value), "ERR_EVAL_OUT_OF_DOMAIN", "out of domain")
	for evaluation: Callable in [Eval.evaluate_structure_elevation_m, Eval.evaluate_elevation_m]:
		_eval_negative(evaluation.call(null, 0.0, 0.0), "ERR_EVAL_PLAN_MISSING", "null plan")
		_eval_negative(evaluation.call(bad_state, 0.0, 0.0), "ERR_EVAL_PLAN_MISSING", "bad plan state")
	_eval_negative(Eval.sample_grid(_macros[0], 0, 0, 16, 0, 4, true), "ERR_EVAL_GRID_SHAPE", "empty grid")
	_eval_negative(Eval.sample_grid(_macros[0], 0, 0, NAN, 4, 4, true), "ERR_EVAL_GRID_SHAPE", "nan step")
	_eval_negative(Eval.sample_grid(_macros[0], 0, 0, 2048, 4, 1, true), "ERR_EVAL_OUT_OF_DOMAIN", "grid past region")
	_eval_negative(Eval.sample_grid(null, 0, 0, 16, 4, 4, true), "ERR_EVAL_PLAN_MISSING", "grid null plan")
	_eval_negative(Eval.sample_grid(_macros[0], NAN, 0, 16, 4, 4, true), "ERR_EVAL_NONFINITE_INPUT", "grid nonfinite origin")


# G10 — composite RegionPlan ownership at the producer boundary.
func _g10() -> void:
	for index in range(_cases.size()):
		var row: Array = _cases[index]
		var plan := Generator.build(row[0], row[1])
		var identity: RefCounted = plan.get_identity()
		var expected_seed: int = Seeds.region_seed(row[0], row[1])
		_check(identity.get_region_seed() == expected_seed, "G10 region seed")
		_check(plan.get_macro_terrain().get_structure_seed() == Seeds.macro_structure_seed(expected_seed) and plan.get_macro_terrain().get_noise_seed() == Seeds.macro_noise_seed(expected_seed), "G10 macro seeds derive from region seed")
		_check(plan.canonical_text().contains("macro_terrain.signature=" + plan.get_macro_terrain().signature() + "\n"), "G10 region text binds macro signature")
