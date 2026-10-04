class_name RegionIdentity
extends RefCounted

const SeedDerivation = preload("res://scripts/world/region/region_seed_derivation.gd")

var _world_seed: int
var _region_coordinate: Vector2i
var _region_seed: int


func _init(world_seed: int, region_coordinate: Vector2i) -> void:
	_world_seed = world_seed
	_region_coordinate = region_coordinate
	_region_seed = SeedDerivation.region_seed(world_seed, region_coordinate)


func get_world_seed() -> int:
	return _world_seed


func get_region_coordinate() -> Vector2i:
	return _region_coordinate


func get_region_seed() -> int:
	return _region_seed


func equals(other: RegionIdentity) -> bool:
	return other != null and _world_seed == other.get_world_seed() \
		and _region_coordinate == other.get_region_coordinate()
