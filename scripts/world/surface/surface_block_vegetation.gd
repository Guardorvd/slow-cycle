extends RefCounted
## GEN2-S S3: vegetation of a SurfaceBlock in two steps (pure; no scene).
##   candidates  from the natural fields only, per block: the rules of
##               RegionVegetationPlanner (same seeded hash per kind and cell,
##               jitter, woody cover, biome species, thickets, meadow grass,
##               rocks by slope; the planner instance supplies them) without
##               roads, trails or heights. They never change when a road or a
##               trail changes, so they are made once per block.
##   placement   on the final blocks: a candidate is dropped when the block
##               cover (road / trail / platform) lies within its clearance
##               (the planner's CLEAR_M / TRAIL_CLEAR_M, checked at the centre
##               and 8 points around); its height is the block's height there.
##               A changed operation re-places only the blocks it touches.
## Output per block: {kind: PackedFloat32Array [x, y, z, yaw, scale] * n},
## world x/z, as the planner's tiles (minus their region-local offset).

const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Block = preload("res://scripts/world/surface/surface_block.gd")
const Ops = preload("res://scripts/world/surface/surface_ops.gd")

const TREES: Array[String] = ["pine", "birch", "autumn"]


## Candidates of block (bx, bz): {kind: PackedFloat32Array [x, z, yaw, scale] * n}.
static func candidates(planner: RefCounted, bx: int, bz: int) -> Dictionary:
	var lists: Dictionary = {}
	for kind: String in Vegetation.KINDS:
		lists[kind] = PackedFloat32Array()
	var bounds: Dictionary = planner._bounds
	var cells: int = int(Block.SIZE_M / Vegetation.TREE_CELL_M)
	var i0: int = int(bx * Block.SIZE_M / Vegetation.TREE_CELL_M)
	var j0: int = int(bz * Block.SIZE_M / Vegetation.TREE_CELL_M)
	for cj in range(cells):
		for ci in range(cells):
			var i: int = i0 + ci
			var j: int = j0 + cj
			var x: float = (i + 0.15 + 0.7 * planner._unit(1, i, j)) * Vegetation.TREE_CELL_M
			var z: float = (j + 0.15 + 0.7 * planner._unit(2, i, j)) * Vegetation.TREE_CELL_M
			if _outside(x, z, bounds):
				continue
			var signals: Dictionary = planner._context.sample_signals(x, z)
			if not signals.is_valid or signals.is_water:
				continue
			var point: Dictionary = planner._biome.evaluate_signals(signals)
			var weights: PackedFloat64Array = point.weights
			var kind: String = ""
			if planner._unit(3, i, j) < point.woody_cover:
				var meadow_birch: float = weights[1] * 0.5
				var t: float = planner._unit(4, i, j) * (weights[0] + weights[2] + weights[3] + meadow_birch)
				if t < weights[0]:
					kind = "pine"
				elif t < weights[0] + weights[3]:
					kind = "autumn"
				else:
					kind = "birch"
			elif signals.distance_to_water_m <= Vegetation.THICKET_M and planner._unit(5, i, j) < 0.85:
				kind = "shrub"
			elif point.dominant == Biome.Biome.MEADOW and planner._unit(6, i, j) < weights[1]:
				kind = "grass"
			if kind.is_empty():
				continue
			lists[kind].append_array(PackedFloat32Array([x, z, TAU * planner._unit(8, i, j), 0.8 + 0.5 * planner._unit(7, i, j)]))
	var rock_cells: int = int(Block.SIZE_M / Vegetation.ROCK_CELL_M)
	var ri0: int = int(bx * Block.SIZE_M / Vegetation.ROCK_CELL_M)
	var rj0: int = int(bz * Block.SIZE_M / Vegetation.ROCK_CELL_M)
	for cj in range(rock_cells):
		for ci in range(rock_cells):
			var i: int = ri0 + ci
			var j: int = rj0 + cj
			var x: float = (i + 0.15 + 0.7 * planner._unit(11, i, j)) * Vegetation.ROCK_CELL_M
			var z: float = (j + 0.15 + 0.7 * planner._unit(12, i, j)) * Vegetation.ROCK_CELL_M
			if _outside(x, z, bounds):
				continue
			var keep_roll: float = planner._unit(13, i, j)
			if keep_roll >= Vegetation.ROCK_KEEP_MAX:
				continue
			var signals: Dictionary = planner._context.sample_signals(x, z)
			if not signals.is_valid or signals.is_water:
				continue
			if keep_roll >= 0.04 + 0.5 * Context.smooth(0.2, 0.9, signals.slope_grade):
				continue
			lists["rock"].append_array(PackedFloat32Array([x, z, TAU * planner._unit(14, i, j), 0.6 + 1.2 * planner._unit(15, i, j)]))
	return lists


static func _outside(x: float, z: float, bounds: Dictionary) -> bool:
	var m: float = Vegetation.MARGIN_M
	return x < bounds.min_x + m or z < bounds.min_z + m or x > bounds.max_x - m or z > bounds.max_z - m


## Placement of one block's candidates on the final blocks (`by_id`:
## Vector2i -> block, the block and its neighbours for clearance checks).
static func place(cands: Dictionary, block: Dictionary, by_id: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for kind: String in Vegetation.KINDS:
		var src: PackedFloat32Array = cands.get(kind, PackedFloat32Array())
		var dst := PackedFloat32Array()
		var road_clear: float = Vegetation.CLEAR_M.tree if kind in TREES else Vegetation.CLEAR_M[kind]
		var trail_clear: float = Vegetation.TRAIL_CLEAR_M.tree if kind in TREES else Vegetation.TRAIL_CLEAR_M[kind]
		for q in range(src.size() / 4):
			var x: float = src[4 * q]
			var z: float = src[4 * q + 1]
			if not _clear(by_id, x, z, road_clear, [Ops.Cover.ROAD, Ops.Cover.ROUGH_ROAD]):
				continue
			if not _clear(by_id, x, z, trail_clear, [Ops.Cover.TRAIL]):
				continue
			var y: float = Block.height_at(block, x, z) - (0.1 if kind == "rock" else 0.0)
			dst.append_array(PackedFloat32Array([x, y, z, src[4 * q + 2], src[4 * q + 3]]))
		out[kind] = dst
	return out


## No sample of the given covers at (x, z) or at 8 points `clear` m around.
static func _clear(by_id: Dictionary, x: float, z: float, clear: float, covers: Array) -> bool:
	for k in range(9):
		var a: float = TAU * k / 8.0
		var r: float = 0.0 if k == 8 else clear
		var c: int = _cover_at(by_id, x + r * cos(a), z + r * sin(a))
		if c in covers:
			return false
	return true


## Cover of the nearest sample at a world point; GRASS outside every block.
static func _cover_at(by_id: Dictionary, x: float, z: float) -> int:
	var id := Vector2i(floori(x / Block.SIZE_M), floori(z / Block.SIZE_M))
	var b: Variant = by_id.get(id)
	if b == null:
		return Ops.Cover.GRASS
	var i: int = clampi(roundi((x - b.origin.x) / Block.STEP_M), 0, Block.N - 1)
	var j: int = clampi(roundi((z - b.origin.y) / Block.STEP_M), 0, Block.N - 1)
	return b.material[j * Block.N + i]
