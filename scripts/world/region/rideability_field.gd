class_name RideabilityField
extends RefCounted

## Natural traversal resistance, before any road/crossing engineering.
## blocked means a natural barrier without a dedicated crossing solution;
## it does NOT prohibit future R5 bridge/ford/engineered-corridor reasoning.
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biomes = preload("res://scripts/world/region/biome_field.gd")
const SCHEMA_TAG := "slow_cycle.rideability_field/1"
const MODEL := "rideability/1;cost=1+4S+3C+2M;slope=.05:1;classes=2,4;water=.35;barrier_grade=1;shallow_cost=8;flags_cover=.65,wet=.60"
enum TravelClass { OPEN, RIDEABLE, DIFFICULT, BLOCKED }
enum Reason { WATER_PRESENT = 1, DEEP_WATER = 2, EXCESSIVE_SLOPE = 4, DENSE_COVER = 8, WET_GROUND = 16 }
const NAMES := ["OPEN", "RIDEABLE", "DIFFICULT", "BLOCKED"]
var _context: Context
var _biome: Biomes
var _signature: String


static func create(context: RefCounted, biome_field: RefCounted) -> Dictionary:
	if context == null or not context is Context or context.signature().is_empty():
		return {"is_valid": false, "field": null, "reason_code": "ERR_RIDEABILITY_CONTEXT"}
	if biome_field == null or not biome_field is Biomes or biome_field.get_context_signature() != context.signature():
		return {"is_valid": false, "field": null, "reason_code": "ERR_RIDEABILITY_BIOME_MISMATCH"}
	var field := RideabilityField.new()
	field._context = context
	field._biome = biome_field
	field._signature = (SCHEMA_TAG + "\n" + context.signature() + "\n" + biome_field.signature() + "\n" + MODEL).sha256_text()
	return {"is_valid": true, "field": field, "reason_code": ""}


## Monotone production resistance kernel. Alpha coefficients are versioned
## starting values, not gameplay/physics laws. Cost alone is never a barrier.
static func resistance(signals: Dictionary, woody_cover: float) -> Dictionary:
	var grade: float = signals.slope_grade
	var cost: float = clampf(1.0 + 4.0 * Context.smooth(0.05, 1.0, grade) + 3.0 * woody_cover + 2.0 * signals.moisture, 1.0, 16.0)
	var flags: int = 0
	if woody_cover >= 0.65:
		flags |= Reason.DENSE_COVER
	if signals.moisture >= 0.60:
		flags |= Reason.WET_GROUND
	if signals.is_water and signals.water_depth_m > 0.0:
		flags |= Reason.WATER_PRESENT
		cost = maxf(8.0, cost)
		if signals.water_depth_m >= 0.35:
			flags |= Reason.DEEP_WATER
	if grade >= 1.0:
		flags |= Reason.EXCESSIVE_SLOPE
	var blocked: bool = (flags & (Reason.DEEP_WATER | Reason.EXCESSIVE_SLOPE)) != 0
	var travel_class: int = TravelClass.OPEN if cost < 2.0 else (TravelClass.RIDEABLE if cost < 4.0 else TravelClass.DIFFICULT)
	if blocked:
		cost = 16.0
		travel_class = TravelClass.BLOCKED
	return {"is_valid": true, "reason_code": "", "cost": cost, "class": travel_class, "blocked": blocked, "reason_flags": flags, "gradient": signals.gradient, "slope_grade": grade, "is_water": signals.is_water, "water_depth_m": signals.water_depth_m}


## Both fields from one set of signals: no duplicate natural surface query.
func evaluate_signals(signals: Dictionary) -> Dictionary:
	var biome: Dictionary = _biome.evaluate_signals(signals)
	return {"biome": biome, "rideability": resistance(signals, biome.woody_cover)}


func sample(x: float, z: float) -> Dictionary:
	var signals: Dictionary = _context.sample_signals(x, z)
	return evaluate_signals(signals).rideability if signals.is_valid else signals


func sample_combined(x: float, z: float) -> Dictionary:
	var signals: Dictionary = _context.sample_signals(x, z)
	if not signals.is_valid:
		return signals
	var result: Dictionary = evaluate_signals(signals)
	result.merge({"is_valid": true, "reason_code": "", "signals": signals})
	return result


func sample_lattice(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	var combined: Dictionary = sample_combined_lattice(i0, j0, nx, nz)
	return combined.rideability if combined.is_valid else combined


func sample_combined_lattice(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	var block: Dictionary = _context.sample_signal_lattice(i0, j0, nx, nz)
	if not block.is_valid:
		return block
	var biome := {"is_valid": true, "reason_code": "", "weights": PackedFloat64Array(), "dominant": PackedByteArray(), "is_water": PackedByteArray(), "moisture": PackedFloat64Array(), "woody_cover": PackedFloat64Array()}
	var ride := {"is_valid": true, "reason_code": "", "cost": PackedFloat64Array(), "class": PackedByteArray(), "blocked": PackedByteArray(), "reason_flags": PackedByteArray(), "gradient": PackedVector2Array(), "slope_grade": PackedFloat64Array(), "is_water": PackedByteArray(), "water_depth_m": PackedFloat64Array()}
	for signals: Dictionary in block.signals:
		var point: Dictionary = evaluate_signals(signals)
		biome.weights.append_array(point.biome.weights)
		for key: String in ["dominant", "is_water", "moisture", "woody_cover"]:
			biome[key].append(point.biome[key])
		for key: String in ["cost", "class", "blocked", "reason_flags", "gradient", "slope_grade", "is_water", "water_depth_m"]:
			ride[key].append(point.rideability[key])
	return {"is_valid": true, "reason_code": "", "biome": biome, "rideability": ride, "signals": block.signals}


func get_bounds_m() -> Dictionary:
	return _context.get_bounds_m()


func get_region_signature() -> String:
	return _context.get_region_signature()


func get_input_signature() -> String:
	return _context.get_input_signature()


func signature() -> String:
	return _signature
