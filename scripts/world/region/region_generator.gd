class_name RegionGenerator
extends RefCounted

const Plan = preload("res://scripts/world/region/region_plan.gd")
const Identity = preload("res://scripts/world/region/region_identity.gd")
const Bounds = preload("res://scripts/world/region/region_bounds.gd")
const Geography = preload("res://scripts/world/region/macro_geography_generator.gd")


## Total public producer; the caller owns each independently constructed plan.
static func build(world_seed: int, region_coordinate: Vector2i) -> Plan:
	var identity := Identity.new(world_seed, region_coordinate)
	var bounds := Bounds.new(region_coordinate)
	var macro := Geography.generate(identity, bounds)
	if macro == null:
		push_error("REGION_GENERATION_FAIL macro construction failed")
		return null
	var plan := Plan.new(identity, bounds, macro)
	var validation: Dictionary = plan.validate()
	if not validation.is_valid:
		push_error("REGION_GENERATION_FAIL " + str(validation.reason_codes))
		return null
	return plan
