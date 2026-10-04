class_name RegionPlan
extends RefCounted

const Identity = preload("res://scripts/world/region/region_identity.gd")
const Bounds = preload("res://scripts/world/region/region_bounds.gd")
const MacroTerrain = preload("res://scripts/world/region/macro_terrain_plan.gd")
const SeedDerivation = preload("res://scripts/world/region/region_seed_derivation.gd")
const SCHEMA_TAG := "slow_cycle.region_plan/1"

var _identity: Identity
var _bounds: Bounds
var _macro_terrain: MacroTerrain


func _init(world_seed: int, region_coordinate: Vector2i) -> void:
	_identity = Identity.new(world_seed, region_coordinate)
	_bounds = Bounds.new(region_coordinate)
	_macro_terrain = MacroTerrain.new()


func get_identity() -> Identity:
	return _identity


func get_bounds() -> Bounds:
	return _bounds


func get_macro_terrain() -> MacroTerrain:
	return _macro_terrain


func canonical_text() -> String:
	var coordinate: Vector2i = _identity.get_region_coordinate()
	return SCHEMA_TAG + "\n" \
		+ "layout.region_size_m=" + str(Bounds.REGION_SIZE_M) + "\n" \
		+ "identity.world_seed=" + str(_identity.get_world_seed()) + "\n" \
		+ "identity.region_coordinate=" + str(coordinate.x) + "," + str(coordinate.y) + "\n" \
		+ "identity.region_seed=" + str(_identity.get_region_seed()) + "\n" \
		+ "bounds.min_x_m=" + str(_bounds.get_min_x_m()) + "\n" \
		+ "bounds.min_z_m=" + str(_bounds.get_min_z_m()) + "\n" \
		+ "bounds.max_x_m=" + str(_bounds.get_max_x_m()) + "\n" \
		+ "bounds.max_z_m=" + str(_bounds.get_max_z_m()) + "\n" \
		+ "macro_terrain.state=" + _macro_terrain.get_state() + "\n"


func signature() -> String:
	return canonical_text().sha256_text()


func validate() -> Dictionary:
	var reasons: Array[String] = []
	if _identity == null or _bounds == null or _macro_terrain == null:
		reasons.append("ERR_REGION_PART_MISSING")
	if _identity != null:
		var coordinate: Vector2i = _identity.get_region_coordinate()
		if _identity.get_region_seed() != SeedDerivation.region_seed(_identity.get_world_seed(), coordinate):
			reasons.append("ERR_REGION_SEED_MISMATCH")
		if _bounds != null:
			var expected: Bounds = Bounds.new(coordinate)
			if _bounds.get_size_m() != Bounds.REGION_SIZE_M \
					or _bounds.get_min_x_m() != expected.get_min_x_m() \
					or _bounds.get_min_z_m() != expected.get_min_z_m() \
					or _bounds.get_max_x_m() != expected.get_max_x_m() \
					or _bounds.get_max_z_m() != expected.get_max_z_m():
				reasons.append("ERR_REGION_BOUNDS_MISMATCH")
	if _macro_terrain != null and _macro_terrain.get_state() != MacroTerrain.STATE_DEFERRED_R1:
		reasons.append("ERR_MACRO_TERRAIN_STATE")
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}
