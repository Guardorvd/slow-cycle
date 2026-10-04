class_name RegionBounds
extends RefCounted

## Schema-v1 layout: coordinate x/y maps to world +X/+Z, in metres.
const REGION_SIZE_M: int = 4096

var _min_x_m: int
var _min_z_m: int
var _max_x_m: int
var _max_z_m: int


func _init(region_coordinate: Vector2i) -> void:
	_min_x_m = int(region_coordinate.x) * REGION_SIZE_M
	_min_z_m = int(region_coordinate.y) * REGION_SIZE_M
	_max_x_m = _min_x_m + REGION_SIZE_M
	_max_z_m = _min_z_m + REGION_SIZE_M


func get_size_m() -> int:
	return REGION_SIZE_M


func get_min_x_m() -> int:
	return _min_x_m


func get_min_z_m() -> int:
	return _min_z_m


func get_max_x_m() -> int:
	return _max_x_m


func get_max_z_m() -> int:
	return _max_z_m


func contains_world_xz(x: float, z: float) -> bool:
	return is_finite(x) and is_finite(z) \
		and x >= float(_min_x_m) and x < float(_max_x_m) \
		and z >= float(_min_z_m) and z < float(_max_z_m)
