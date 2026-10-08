class_name BiomeField
extends RefCounted

## Immutable derived ecological affinities. WATER is a sentinel/mask, not
## a fifth normalized land weight. No vegetation instances or height owner.
const Context = preload("res://scripts/world/region/environment_context.gd")
const Macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SCHEMA_TAG := "slow_cycle.biome_field/1"
const MODEL := "biome/1;conifer=.38:.45;meadow=.20:1.60;riparian=10:60;autumn_transfer=.93;cover=.85,.08,.70,.80;warp=95;radial=.20;feather=60:120"
enum Biome { CONIFER, MEADOW, RIPARIAN, AUTUMN, WATER }
const NAMES := ["CONIFER", "MEADOW", "RIPARIAN", "AUTUMN", "WATER"]
const COLORS := [Color(0.13, 0.34, 0.22), Color(0.73, 0.78, 0.42), Color(0.21, 0.64, 0.51), Color(0.90, 0.38, 0.13), Color(0.12, 0.35, 0.80)]
var _context: Context
var _character: Dictionary
var _pocket: Dictionary
var _signature: String


static func create(context: RefCounted) -> Dictionary:
	if context == null or not context is Context or context.signature().is_empty():
		return {"is_valid": false, "field": null, "reason_code": "ERR_BIOME_CONTEXT"}
	var field := BiomeField.new()
	field._context = context
	var rng := RandomNumberGenerator.new()
	rng.seed = context.get_biome_seed()
	field._character = {"seed": context.get_biome_seed(), "forest_permille": rng.randi_range(850, 1250), "phase_millirad": rng.randi_range(0, 6283), "wavelength_m": rng.randi_range(450, 750)}
	field._pocket = {"is_present": false, "reason_code": "NO_SUITABLE_AUTUMN_SITE", "u_m": 0, "v_m": 0, "radius_u_m": rng.randi_range(220, 350), "radius_v_m": rng.randi_range(150, 270), "feather_m": rng.randi_range(60, 120)}
	field._choose_pocket()
	field._signature = (SCHEMA_TAG + "\n" + context.signature() + "\n" + MODEL + "\n" + JSON.stringify(field._character) + "\n" + JSON.stringify(field._pocket)).sha256_text()
	return {"is_valid": true, "field": field, "reason_code": ""}


func _choose_pocket() -> void:
	var best: float = -INF
	var bounds: Dictionary = get_bounds_m()
	for j in range(1, 16):
		for i in range(1, 16):
			var signals: Dictionary = _context.sample_signals(bounds.min_x + i * 256.0, bounds.min_z + j * 256.0)
			if signals.is_water or signals.slope_grade > 0.65 or signals.relative_elevation > 0.75 or signals.distance_to_water_m < 30.0:
				continue
			var score: float = woodland_suitability(signals) + 0.32 * variation(signals.local_x, signals.local_z)
			if score > best:
				best = score
				var frame: Vector2 = Macro.local_to_frame(_context.get_frame_symmetry(), signals.local_x, signals.local_z)
				_pocket.merge({"is_present": true, "reason_code": "", "u_m": roundi(frame.x), "v_m": roundi(frame.y)}, true)


func variation(lx: float, lz: float) -> float:
	var phase: float = _character.phase_millirad / 1000.0
	var k: float = TAU / float(_character.wavelength_m)
	return (sin(lx * k + phase) + sin(lz * k * 0.79 - phase) + 0.5 * sin((lx + lz) * k * 0.51 + phase)) / 2.5


static func woodland_suitability(signals: Dictionary) -> float:
	return (1.0 - Context.smooth(0.35, 0.85, signals.relative_elevation)) * (1.0 - 0.75 * Context.smooth(0.45, 1.0, signals.slope_grade)) * (0.75 + 0.25 * signals.moisture)


func _pocket_weight(signals: Dictionary) -> float:
	if not _pocket.is_present:
		return 0.0
	var frame: Vector2 = Macro.local_to_frame(_context.get_frame_symmetry(), signals.local_x, signals.local_z)
	var phase: float = _character.phase_millirad / 1000.0
	# Bounded broad displacement and asymmetric radial lobes deliberately break
	# the descriptor ellipse. Geography and suitability further shape the edge.
	var u: float = frame.x - _pocket.u_m + 95.0 * sin(frame.y * TAU / 620.0 + phase)
	var v: float = frame.y - _pocket.v_m + 95.0 * sin(frame.x * TAU / 480.0 - phase)
	var q: float = sqrt(pow(u / float(_pocket.radius_u_m), 2.0) + pow(v / float(_pocket.radius_v_m), 2.0))
	q += 0.20 * variation(signals.local_x, signals.local_z)
	var feather: float = _pocket.feather_m / float(mini(_pocket.radius_u_m, _pocket.radius_v_m))
	return (1.0 - Context.smooth(1.0 - feather, 1.0 + feather, q)) * woodland_suitability(signals) * (1.0 - Context.smooth(0.60, 0.90, signals.moisture))


## Actual production scoring kernel; controlled-signal tests also use it.
func evaluate_signals(signals: Dictionary) -> Dictionary:
	var moisture: float = signals.moisture
	if signals.is_water:
		return {"is_valid": true, "reason_code": "", "weights": PackedFloat64Array([0.0, 0.0, 0.0, 0.0]), "dominant": Biome.WATER, "is_water": true, "moisture": moisture, "woody_cover": 0.0}
	var elevation: float = Context.smooth(0.45, 0.80, signals.relative_elevation)
	var variation_value: float = variation(signals.local_x, signals.local_z)
	var conifer: float = (0.38 + 0.75 * (1.0 - elevation)) * (_character.forest_permille / 1000.0) * (1.0 + 0.24 * signals.shade + 0.18 * variation_value) * (0.70 + 0.45 * moisture)
	var meadow: float = (0.20 + 1.60 * elevation + 0.24 * (1.0 - Context.smooth(0.10, 0.50, signals.slope_grade))) * (1.0 - 0.28 * signals.shade - 0.16 * variation_value) * (1.0 - 0.30 * moisture)
	var riparian: float = 2.5 * (1.0 - Context.smooth(10.0, 60.0, signals.distance_to_water_m)) * (0.35 + 0.65 * (1.0 - Context.smooth(0.20, 0.80, signals.slope_grade))) * (0.40 + 0.60 * moisture)
	var autumn: float = conifer * 0.93 * _pocket_weight(signals)
	conifer -= autumn
	var total: float = conifer + meadow + riparian + autumn
	var weights := PackedFloat64Array([conifer / total, meadow / total, riparian / total, autumn / total])
	var dominant: int = dominant_weight(weights)
	var cover: float = (0.85 * weights[0] + 0.08 * weights[1] + 0.70 * weights[2] + 0.80 * weights[3]) * (0.80 + 0.20 * moisture) * (1.0 - 0.65 * Context.smooth(0.65, 1.2, signals.slope_grade))
	return {"is_valid": true, "reason_code": "", "weights": weights, "dominant": dominant, "is_water": false, "moisture": moisture, "woody_cover": clampf(cover, 0.0, 1.0)}


func sample(x: float, z: float) -> Dictionary:
	var signals: Dictionary = _context.sample_signals(x, z)
	return evaluate_signals(signals) if signals.is_valid else signals


static func dominant_weight(weights: PackedFloat64Array) -> int:
	var dominant: int = 0
	for i in range(1, 4):
		if weights[i] > weights[dominant]:
			dominant = i
	return dominant


func sample_lattice(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	var block: Dictionary = _context.sample_signal_lattice(i0, j0, nx, nz)
	if not block.is_valid:
		return block
	var result := {"is_valid": true, "reason_code": "", "weights": PackedFloat64Array(), "dominant": PackedByteArray(), "is_water": PackedByteArray(), "moisture": PackedFloat64Array(), "woody_cover": PackedFloat64Array()}
	for signals: Dictionary in block.signals:
		var point: Dictionary = evaluate_signals(signals)
		result.weights.append_array(point.weights)
		for key: String in ["dominant", "is_water", "moisture", "woody_cover"]:
			result[key].append(point[key])
	return result


func get_bounds_m() -> Dictionary:
	return _context.get_bounds_m()


func get_region_signature() -> String:
	return _context.get_region_signature()


func get_input_signature() -> String:
	return _context.get_input_signature()


func get_context_signature() -> String:
	return _context.signature() if _context != null else ""


func signature() -> String:
	return _signature


func get_descriptor() -> Dictionary:
	return {"character": _character.duplicate(true), "pocket": _pocket.duplicate(true), "model": MODEL}


static func blend_color(point: Dictionary) -> Color:
	if point.is_water:
		return COLORS[Biome.WATER]
	var color := Color(0, 0, 0, 1)
	for k in range(4):
		color.r += COLORS[k].r * point.weights[k]
		color.g += COLORS[k].g * point.weights[k]
		color.b += COLORS[k].b * point.weights[k]
	return color
