extends RefCounted

## PR1 M5 (D9): minimal regional vegetation, pure planning (no scene, no I/O).
## Placement per 512 m tile (independent tiles, any thread, any order):
##   trees   one jittered candidate per 8 m cell; kept with probability of the
##           R4 woody cover; species by the R4 biome weights at the point
##           (CONIFER -> pine, AUTUMN -> autumn birch, RIPARIAN -> birch,
##           MEADOW -> scattered birch);
##   shrubs  riparian thickets: one candidate per 8 m cell within
##           THICKET_M of water (a natural edge along streams and rivers);
##   grass   clumps on open meadow (one candidate per 8 m cell);
##   rocks   one candidate per 16 m cell, more on steep ground.
## Exclusions: water (R3 surface), every road footprint with a clearance per
## kind (FinalSurface road owner; bridge decks and fords are road pieces), the
## region margin; BC1 trails (FinalSurface.with_trails): a clearance per kind
## from the band edge (TRAIL_CLEAR_M), none without trails. Heights are
## FinalSurface heights (what renders and collides).
## Randomness: a stateless 64-bit mix of (vegetation seed, kind, cell), so the
## result depends only on the seed, the region and the products, never on
## thread count, order or time. Output is region-local:
## {kind: PackedFloat32Array [x, y, z, yaw, scale] * n} per tile.

const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const MODEL := "vegetation/1;tree=8;rock=16;thicket=12;clear=3.5,1.5,0.6,2.5;margin=8;trail_clear=1.2,0.8,0.3,2.2"
const KINDS: Array[String] = ["pine", "birch", "autumn", "shrub", "grass", "rock"]
const TREE_CELL_M: float = 8.0
const ROCK_CELL_M: float = 16.0
const THICKET_M: float = 12.0
## Clearance from a road footprint (m): trees, shrubs, grass, rocks.
const CLEAR_M := {"tree": 3.5, "shrub": 1.5, "grass": 0.6, "rock": 2.5}
const MARGIN_M: float = 8.0
## BC1: clearance from a trail band edge (m): trees (handlebar and shoulder
## room), shrubs, grass (the band is worn ground), rocks (centre: beyond the
## largest rock collider, 0.6 m x scale 1.8).
const TRAIL_CLEAR_M := {"tree": 1.2, "shrub": 0.8, "grass": 0.3, "rock": 2.2}
const TILE_M: int = 512
## Trunk / rock collider radii (m) at scale 1 (runtime uses them).
const TRUNK_RADIUS := {"pine": 0.18, "birch": 0.12, "autumn": 0.12, "rock": 0.6}

var _context: RefCounted
var _biome: RefCounted
var _surface: RefCounted
var _seed: int
var _bounds: Dictionary


## region_plan / terrain / hydrology_plan: R0-R3 products; surface: FinalSurface.
static func create(region_plan: RefCounted, terrain: RefCounted, hydrology_plan: RefCounted, surface: RefCounted) -> Dictionary:
	var context: Dictionary = Context.create(region_plan, terrain, hydrology_plan)
	if not context.is_valid:
		return {"is_valid": false, "reason_code": "ERR_VEGETATION_DEPENDENCY", "detail": context.reason_code}
	var biome: Dictionary = Biome.create(context.context)
	if not biome.is_valid:
		return {"is_valid": false, "reason_code": "ERR_VEGETATION_DEPENDENCY", "detail": biome.reason_code}
	var planner = load("res://scripts/world/region/region_vegetation_planner.gd").new()
	planner._context = context.context
	planner._biome = biome.field
	planner._surface = surface
	planner._seed = Seeds.vegetation_seed(region_plan.get_identity().get_region_seed())
	planner._bounds = terrain.get_bounds_m()
	return {"is_valid": true, "reason_code": "", "planner": planner}


## Stateless hash of (seed, salt, i, j) -> [0, 1).
func _unit(salt: int, i: int, j: int) -> float:
	var x: int = _seed ^ (salt * -7046029254386353131) ^ (i * -4658895280553007687) ^ (j * 7640891576956012809)
	x = (x ^ ((x >> 30) & 0x3FFFFFFFF)) * -4658895280553007687
	x = (x ^ ((x >> 27) & 0x1FFFFFFFFF)) * -7723592293110705685
	x = x ^ ((x >> 31) & 0x1FFFFFFFF)
	return float(x & 0xFFFFFF) / 16777216.0


## Clear of every road footprint by `clear` m (centre and 8 points around).
func _road_clear(x: float, z: float, clear: float) -> bool:
	if not _surface.road_owner(x, z).is_empty():
		return false
	for k in range(8):
		var a: float = TAU * k / 8.0
		if not _surface.road_owner(x + clear * cos(a), z + clear * sin(a)).is_empty():
			return false
	return true


## Clear of every trail band by `clear` m (BC1).
func _trail_clear(x: float, z: float, clear: float) -> bool:
	var near: Dictionary = _surface.trail_near(x, z, clear)
	return near.is_empty() or near.distance > near.half_width + clear


## Vegetation of one tile (tile indices in world 512 m units).
func tile(tx: int, tz: int) -> Dictionary:
	var out: Dictionary = {}
	var lists: Dictionary = {}
	for kind: String in KINDS:
		lists[kind] = PackedFloat32Array()
	var x0: float = tx * TILE_M
	var z0: float = tz * TILE_M
	var cells: int = int(TILE_M / TREE_CELL_M)
	for cj in range(cells):
		for ci in range(cells):
			var i: int = int(x0 / TREE_CELL_M) + ci
			var j: int = int(z0 / TREE_CELL_M) + cj
			var x: float = (i + 0.15 + 0.7 * _unit(1, i, j)) * TREE_CELL_M
			var z: float = (j + 0.15 + 0.7 * _unit(2, i, j)) * TREE_CELL_M
			if x < _bounds.min_x + MARGIN_M or z < _bounds.min_z + MARGIN_M or x > _bounds.max_x - MARGIN_M or z > _bounds.max_z - MARGIN_M:
				continue
			var signals: Dictionary = _context.sample_signals(x, z)
			if not signals.is_valid or signals.is_water:
				continue
			var point: Dictionary = _biome.evaluate_signals(signals)
			var weights: PackedFloat64Array = point.weights
			var kind: String = ""
			var roll: float = _unit(3, i, j)
			if roll < point.woody_cover:
				# Species by the biome weights at the point.
				var pick: float = _unit(4, i, j)
				var meadow_birch: float = weights[1] * 0.5
				var total: float = weights[0] + weights[2] + weights[3] + meadow_birch
				var t: float = pick * total
				if t < weights[0]:
					kind = "pine"
				elif t < weights[0] + weights[3]:
					kind = "autumn"
				else:
					kind = "birch"
			elif signals.distance_to_water_m <= THICKET_M and _unit(5, i, j) < 0.85:
				kind = "shrub"
			elif point.dominant == Biome.Biome.MEADOW and _unit(6, i, j) < weights[1]:
				kind = "grass"
			if kind.is_empty():
				continue
			var clear: float = CLEAR_M.tree if kind in ["pine", "birch", "autumn"] else CLEAR_M[kind]
			if not _road_clear(x, z, clear):
				continue
			if not _trail_clear(x, z, TRAIL_CLEAR_M.tree if kind in ["pine", "birch", "autumn"] else TRAIL_CLEAR_M[kind]):
				continue
			var h: Dictionary = _surface.sample_height(x, z)
			if not h.is_valid:
				continue
			var scale: float = 0.8 + 0.5 * _unit(7, i, j)
			lists[kind].append_array(PackedFloat32Array([x - _bounds.min_x, h.height_m, z - _bounds.min_z, TAU * _unit(8, i, j), scale]))
	var rock_cells: int = int(TILE_M / ROCK_CELL_M)
	for cj in range(rock_cells):
		for ci in range(rock_cells):
			var i: int = int(x0 / ROCK_CELL_M) + ci
			var j: int = int(z0 / ROCK_CELL_M) + cj
			var x: float = (i + 0.15 + 0.7 * _unit(11, i, j)) * ROCK_CELL_M
			var z: float = (j + 0.15 + 0.7 * _unit(12, i, j)) * ROCK_CELL_M
			if x < _bounds.min_x + MARGIN_M or z < _bounds.min_z + MARGIN_M or x > _bounds.max_x - MARGIN_M or z > _bounds.max_z - MARGIN_M:
				continue
			var signals: Dictionary = _context.sample_signals(x, z)
			if not signals.is_valid or signals.is_water:
				continue
			if _unit(13, i, j) >= 0.04 + 0.5 * Context.smooth(0.2, 0.9, signals.slope_grade):
				continue
			if not _road_clear(x, z, CLEAR_M.rock):
				continue
			if not _trail_clear(x, z, TRAIL_CLEAR_M.rock):
				continue
			var h: Dictionary = _surface.sample_height(x, z)
			if not h.is_valid:
				continue
			lists["rock"].append_array(PackedFloat32Array([x - _bounds.min_x, h.height_m - 0.1, z - _bounds.min_z, TAU * _unit(14, i, j), 0.6 + 1.2 * _unit(15, i, j)]))
	for kind: String in KINDS:
		out[kind] = lists[kind]
	return out
