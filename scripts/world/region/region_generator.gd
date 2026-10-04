class_name RegionGenerator
extends RefCounted

const Plan = preload("res://scripts/world/region/region_plan.gd")


## Total public producer; the caller owns each independently constructed plan.
static func build(world_seed: int, region_coordinate: Vector2i) -> Plan:
	return Plan.new(world_seed, region_coordinate)
