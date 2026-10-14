class_name FinalSurface
extends RefCounted
## BC1 (additive; a surface without trails answers exactly as before):
## with_trails() adds realized trails (TrailRealization records): their band
## (centre line +- half width, flat at the line ends) is the trail material
## off the road planes (trail_near / trail_owner; sample_surface kind TRAIL).
## The trail never changes the design heights (_mesh_sample, from which the
## tiles are built). with_published() then answers the FINAL height, normal
## and gradient queries inside every trail zone (band + PUBLISHED_REACH_M,
## off the road planes) from the published tile triangles themselves, so
## queries there agree with what renders and collides; elsewhere they stay
## the design evaluation (general off-road parity is BC2's).
## A trail's BENCH operation (TrailRealization, amendment A1) is evaluated by
## trail_displacement(); the tile renderer moves the published vertices of its
## footprint by it, so final queries follow it through with_published().
const Natural = preload("res://scripts/world/region/hydrology_surface.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const TRAIL_CELL_M: float = 4.0
## trail_near() answers within this distance beyond a band edge.
const TRAIL_REACH_M: float = 4.0
const PUBLISHED_REACH_M: float = 3.0
const PUBLISHED_CELL_M: float = 2.0
## Bake tile size (m) for published_ground().
const TILE_SIZE_M: float = 512.0
var _natural: RefCounted
var _deformer: RefCounted
var _bounds: Dictionary
var _fine_cells: Dictionary = {}
var _road_cells: Dictionary = {}
var _road_leaves: Dictionary = {}
var _cap_leaves: Dictionary = {}
var _boundary_points: Dictionary = {}
var _trails: Array = []
var _trail_index: Dictionary = {}
var _published: Dictionary = {}
var _published_vertices := PackedVector3Array()

static func create(terrain: RefCounted, hydrology: RefCounted, deformer: RefCounted = null) -> Dictionary:
	var built: Dictionary = Natural.create(terrain, hydrology)
	if not built.is_valid:
		return built
	var surface := FinalSurface.new()
	surface._natural = built.surface
	surface._deformer = deformer
	surface._bounds = terrain.get_bounds_m()
	if deformer != null:
		surface._fine_cells = deformer.fine_cells()
		surface._road_cells = deformer._road_cells.duplicate()
		surface._road_leaves = deformer._road_leaves.duplicate()
		surface._cap_leaves = deformer._cap_leaves.duplicate()
		surface._boundary_points = deformer._boundary_points.duplicate(true)
	return {"is_valid": true, "surface": surface, "reason_code": ""}

## This surface plus realized trails (region-local TrailRealization records).
func with_trails(trails: Array) -> RefCounted:
	var out: FinalSurface = _copy()
	out._trails = trails.duplicate(true)
	out._trail_index = {}
	out._published = {}
	out._published_vertices = PackedVector3Array()
	for t in range(out._trails.size()):
		var line: Dictionary = out._trails[t].line
		var reach: float = out._trails[t].half_width_m + TRAIL_REACH_M
		for k in range(line.s.size() - 1):
			var lo := Vector2(minf(line.x[k], line.x[k + 1]), minf(line.z[k], line.z[k + 1])) - Vector2(reach, reach)
			var hi := Vector2(maxf(line.x[k], line.x[k + 1]), maxf(line.z[k], line.z[k + 1])) + Vector2(reach, reach)
			for j in range(int(floor(lo.y / TRAIL_CELL_M)), int(floor(hi.y / TRAIL_CELL_M)) + 1):
				for i in range(int(floor(lo.x / TRAIL_CELL_M)), int(floor(hi.x / TRAIL_CELL_M)) + 1):
					var key := Vector2i(i, j)
					if not out._trail_index.has(key):
						out._trail_index[key] = PackedInt32Array()
					out._trail_index[key].append_array([t, k])
	return out

## This surface with the published triangles of its trail zones answering the
## final queries there. `tiles`: bake tile slots {arrays, origin} (tile-local
## vertices, region-local origin) covering the zones; a triangle is kept when
## its bounds overlap a trail index cell (cells cover every zone point).
func with_published(tiles: Array) -> RefCounted:
	var out: FinalSurface = _copy()
	out._trails = _trails
	out._trail_index = _trail_index
	for slot: Dictionary in tiles:
		var origin := Vector3(slot.origin[0], 0.0, slot.origin[1])
		var vertices: PackedVector3Array = slot.arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = slot.arrays[Mesh.ARRAY_INDEX]
		for q in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[q]] + origin
			var b: Vector3 = vertices[indices[q + 1]] + origin
			var c: Vector3 = vertices[indices[q + 2]] + origin
			var overlaps: bool = false
			for j in range(int(floor(minf(a.z, minf(b.z, c.z)) / TRAIL_CELL_M)), int(floor(maxf(a.z, maxf(b.z, c.z)) / TRAIL_CELL_M)) + 1):
				for i in range(int(floor(minf(a.x, minf(b.x, c.x)) / TRAIL_CELL_M)), int(floor(maxf(a.x, maxf(b.x, c.x)) / TRAIL_CELL_M)) + 1):
					overlaps = overlaps or _trail_index.has(Vector2i(i, j))
			if not overlaps:
				continue
			var start: int = out._published_vertices.size()
			out._published_vertices.append_array([a, b, c])
			for j in range(int(floor(minf(a.z, minf(b.z, c.z)) / PUBLISHED_CELL_M)), int(floor(maxf(a.z, maxf(b.z, c.z)) / PUBLISHED_CELL_M)) + 1):
				for i in range(int(floor(minf(a.x, minf(b.x, c.x)) / PUBLISHED_CELL_M)), int(floor(maxf(a.x, maxf(b.x, c.x)) / PUBLISHED_CELL_M)) + 1):
					var key := Vector2i(i, j)
					if not out._published.has(key):
						out._published[key] = PackedInt32Array()
					out._published[key].append(start)
	return out

## BC2: the published ground of a region before any trail - heights of the
## tile triangles themselves (`tiles`: bake slots {arrays, origin}, region-
## local) on a lattice of `cell_m` (node (i, j) at region-local (i, j) *
## cell_m), NAN where no triangle covers a node. This is the query of the
## published tiles, kept apart from the design evaluation (sample_height):
## off the fine road cells the tiles interpolate the design over 16 m cells,
## which differs from it by metres in gullies. Each tile fills its own nodes
## (threads: WorkerThreadPool group); shared border nodes agree.
## Returns {cell_m, nx, nz, heights: PackedFloat32Array (row-major, nx * nz)}.
static func published_ground(tiles: Array, bounds: Dictionary, cell_m: float, threads: int = 1) -> Dictionary:
	var nx: int = int(round((bounds.max_x - bounds.min_x) / cell_m)) + 1
	var nz: int = int(round((bounds.max_z - bounds.min_z) / cell_m)) + 1
	var parts: Array = []
	parts.resize(tiles.size())
	var job := func(k: int) -> void:
		parts[k] = _ground_part(tiles[k], cell_m, nx, nz)
	if threads > 1 and tiles.size() > 1:
		var group: int = WorkerThreadPool.add_group_task(job, tiles.size(), threads, true, "final_surface_ground")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(tiles.size()):
			job.call(k)
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	heights.fill(NAN)
	for part: Dictionary in parts:
		for j in range(part.nz):
			for i in range(part.nx):
				var h: float = part.heights[j * part.nx + i]
				if not is_nan(h):
					heights[(part.j0 + j) * nx + part.i0 + i] = h
	return {"cell_m": cell_m, "nx": nx, "nz": nz, "heights": heights}

static func _ground_part(slot: Dictionary, cell_m: float, nx: int, nz: int) -> Dictionary:
	var ox: float = slot.origin[0]
	var oz: float = slot.origin[1]
	var vertices: PackedVector3Array = slot.arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = slot.arrays[Mesh.ARRAY_INDEX]
	var i0: int = int(ceil(ox / cell_m - 1e-6))
	var j0: int = int(ceil(oz / cell_m - 1e-6))
	var i1: int = mini(nx - 1, int(floor((ox + TILE_SIZE_M) / cell_m + 1e-6)))
	var j1: int = mini(nz - 1, int(floor((oz + TILE_SIZE_M) / cell_m + 1e-6)))
	var pnx: int = i1 - i0 + 1
	var pnz: int = j1 - j0 + 1
	var heights := PackedFloat32Array()
	heights.resize(pnx * pnz)
	heights.fill(NAN)
	for q in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[q]]
		var b: Vector3 = vertices[indices[q + 1]]
		var c: Vector3 = vertices[indices[q + 2]]
		var lo_i: int = maxi(i0, int(ceil((ox + minf(a.x, minf(b.x, c.x))) / cell_m - 1e-6)))
		var hi_i: int = mini(i1, int(floor((ox + maxf(a.x, maxf(b.x, c.x))) / cell_m + 1e-6)))
		if lo_i > hi_i:
			continue
		var lo_j: int = maxi(j0, int(ceil((oz + minf(a.z, minf(b.z, c.z))) / cell_m - 1e-6)))
		var hi_j: int = mini(j1, int(floor((oz + maxf(a.z, maxf(b.z, c.z))) / cell_m + 1e-6)))
		if lo_j > hi_j:
			continue
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var den: float = v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-12:
			continue
		for j in range(lo_j, hi_j + 1):
			for i in range(lo_i, hi_i + 1):
				var px: float = i * cell_m - ox - a.x
				var pz: float = j * cell_m - oz - a.z
				var v: float = (px * v1.y - v1.x * pz) / den
				var w: float = (v0.x * pz - px * v0.y) / den
				if v >= -1e-6 and w >= -1e-6 and v + w <= 1.0 + 1e-6:
					heights[(j - j0) * pnx + i - i0] = a.y + v * (b.y - a.y) + w * (c.y - a.y)
	return {"i0": i0, "j0": j0, "nx": pnx, "nz": pnz, "heights": heights}

## Bilinear height of a published_ground() raster at a region-local point
## (NAN outside it or next to an uncovered node).
static func ground_height(ground: Dictionary, lx: float, lz: float) -> float:
	var u: float = lx / ground.cell_m
	var v: float = lz / ground.cell_m
	# The last lattice line belongs to the cell before it.
	var i: int = mini(int(floor(u)), ground.nx - 2) if u <= ground.nx - 1 else ground.nx
	var j: int = mini(int(floor(v)), ground.nz - 2) if v <= ground.nz - 1 else ground.nz
	if u < 0.0 or v < 0.0 or i >= ground.nx - 1 or j >= ground.nz - 1:
		return NAN
	var fu: float = u - i
	var fv: float = v - j
	var row: int = j * ground.nx + i
	var h: PackedFloat32Array = ground.heights
	return lerpf(lerpf(h[row], h[row + 1], fu), lerpf(h[row + ground.nx], h[row + ground.nx + 1], fu), fv)

func _copy() -> FinalSurface:
	var out := FinalSurface.new()
	out._natural = _natural
	out._deformer = _deformer
	out._bounds = _bounds
	out._fine_cells = _fine_cells
	out._road_cells = _road_cells
	out._road_leaves = _road_leaves
	out._cap_leaves = _cap_leaves
	out._boundary_points = _boundary_points
	return out

func get_trails() -> Array:
	return _trails.duplicate(true)

func has_trails() -> bool:
	return not _trails.is_empty()

## Nearest trail centre line within `reach` of its band edge at a world point:
## {id, index, lateral (signed, + left of travel), half_width, s, distance};
## {} when none. Flat ends: nothing beyond a line's first or last station.
func trail_near(x: float, z: float, reach: float = 0.0) -> Dictionary:
	if _trails.is_empty():
		return {}
	return _trail_near_local(x - _bounds.min_x, z - _bounds.min_z, reach)

func _trail_near_local(lx: float, lz: float, reach: float) -> Dictionary:
	var pairs: Variant = _trail_index.get(Vector2i(int(floor(lx / TRAIL_CELL_M)), int(floor(lz / TRAIL_CELL_M))))
	if pairs == null:
		return {}
	var best: Dictionary = {}
	var p := Vector2(lx, lz)
	for m in range(0, pairs.size(), 2):
		var trail: Dictionary = _trails[pairs[m]]
		var line: Dictionary = trail.line
		var k: int = pairs[m + 1]
		var a := Vector2(line.x[k], line.z[k])
		var b := Vector2(line.x[k + 1], line.z[k + 1])
		var ab: Vector2 = b - a
		var u: float = (p - a).dot(ab) / maxf(ab.length_squared(), 1e-12)
		if (u < 0.0 and k == 0) or (u > 1.0 and k == line.s.size() - 2):
			continue
		u = clampf(u, 0.0, 1.0)
		var closest: Vector2 = a + ab * u
		var distance: float = closest.distance_to(p)
		if distance > trail.half_width_m + reach or (not best.is_empty() and distance >= best.distance):
			continue
		var side: float = -1.0 if ab.cross(p - a) < 0.0 else 1.0
		best = {"id": trail.id, "index": pairs[m], "lateral": side * distance, "half_width": trail.half_width_m, "s": lerpf(line.s[k], line.s[k + 1], u), "distance": distance}
	return best

## BENCH displacement (m) of the published surface at a world point (0 off
## every bench footprint; amendment A1 formula in TrailRealization).
func trail_displacement(x: float, z: float) -> float:
	if _trails.is_empty():
		return 0.0
	var near: Dictionary = _trail_near_local(x - _bounds.min_x, z - _bounds.min_z, TRAIL_REACH_M)
	if near.is_empty():
		return 0.0
	var trail: Dictionary = _trails[near.index]
	for op: Dictionary in trail.get("operations", []):
		if op.kind != "BENCH" or near.s < op.s0_m or near.s > op.s1_m:
			continue
		var half: float = trail.half_width_m
		var t: float = near.lateral
		if absf(t) >= half + op.daylight_m:
			return 0.0
		var line: Dictionary = trail.line
		var k: int = clampi(line.s.bsearch(near.s) - 1, op.k0, op.k1 - 1)
		var u: float = clampf((near.s - line.s[k]) / maxf(line.s[k + 1] - line.s[k], 1e-12), 0.0, 1.0)
		var a: float = lerpf(op.amplitude[k - op.k0], op.amplitude[k + 1 - op.k0], u)
		if absf(t) <= half:
			return -a * t
		return -a * signf(t) * half * (half + op.daylight_m - absf(t)) / op.daylight_m
	return 0.0

## Distance (m) from a world triangle to the nearest BENCH footprint (band +
## daylight over the bench interval), 0 when they overlap; INF without one.
func trail_bench_gap(a: Vector2, b: Vector2, c: Vector2) -> float:
	return trail_triangle_gap(a, b, c, true)

## Distance (m) from a world triangle to the nearest trail band, 0 when they
## overlap; INF when no centre line is within TRAIL_REACH_M of its band edge.
## `bench_only`: only bench intervals, measured from their daylight edge.
func trail_triangle_gap(a: Vector2, b: Vector2, c: Vector2, bench_only: bool = false) -> float:
	if _trails.is_empty():
		return INF
	var o := Vector2(_bounds.min_x, _bounds.min_z)
	var la: Vector2 = a - o
	var lb: Vector2 = b - o
	var lc: Vector2 = c - o
	var best: float = INF
	var seen: Dictionary = {}
	for j in range(int(floor(minf(la.y, minf(lb.y, lc.y)) / TRAIL_CELL_M)), int(floor(maxf(la.y, maxf(lb.y, lc.y)) / TRAIL_CELL_M)) + 1):
		for i in range(int(floor(minf(la.x, minf(lb.x, lc.x)) / TRAIL_CELL_M)), int(floor(maxf(la.x, maxf(lb.x, lc.x)) / TRAIL_CELL_M)) + 1):
			var pairs: Variant = _trail_index.get(Vector2i(i, j))
			if pairs == null:
				continue
			for m in range(0, pairs.size(), 2):
				var key := Vector2i(pairs[m], pairs[m + 1])
				if seen.has(key):
					continue
				seen[key] = true
				var trail: Dictionary = _trails[key.x]
				var extra: float = 0.0
				if bench_only:
					extra = -1.0
					for op: Dictionary in trail.get("operations", []):
						if op.kind == "BENCH" and key.y + 1 >= op.k0 and key.y <= op.k1:
							extra = op.daylight_m
					if extra < 0.0:
						continue
				var p := Vector2(trail.line.x[key.y], trail.line.z[key.y])
				var q := Vector2(trail.line.x[key.y + 1], trail.line.z[key.y + 1])
				best = minf(best, maxf(0.0, _triangle_segment_distance(la, lb, lc, p, q) - trail.half_width_m - extra))
	return best

## Distance (m) from a world segment to the nearest trail band (all trail
## segments; for coarse decisions far from the bands), 0 when they overlap.
func trail_segment_gap(a: Vector2, b: Vector2) -> float:
	var o := Vector2(_bounds.min_x, _bounds.min_z)
	var la: Vector2 = a - o
	var lb: Vector2 = b - o
	var middle: Vector2 = (la + lb) * 0.5
	var half: float = la.distance_to(lb) * 0.5
	var best: float = INF
	for trail: Dictionary in _trails:
		var line: Dictionary = trail.line
		for k in range(line.s.size() - 1):
			var p := Vector2(line.x[k], line.z[k])
			var q := Vector2(line.x[k + 1], line.z[k + 1])
			# Lower bound first: centre distance minus both half lengths.
			if middle.distance_to((p + q) * 0.5) - half - p.distance_to(q) * 0.5 - trail.half_width_m >= best:
				continue
			best = minf(best, maxf(0.0, _segment_distance(la, lb, p, q) - trail.half_width_m))
	return best

static func _segment_distance(a: Vector2, b: Vector2, p: Vector2, q: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, p, q) != null:
		return 0.0
	return minf(minf(Geometry2D.get_closest_point_to_segment(a, p, q).distance_to(a), Geometry2D.get_closest_point_to_segment(b, p, q).distance_to(b)),
		minf(Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p), Geometry2D.get_closest_point_to_segment(q, a, b).distance_to(q)))

static func _triangle_segment_distance(a: Vector2, b: Vector2, c: Vector2, p: Vector2, q: Vector2) -> float:
	if Geometry2D.point_is_inside_triangle(p, a, b, c) or Geometry2D.point_is_inside_triangle(q, a, b, c):
		return 0.0
	return minf(_segment_distance(a, b, p, q), minf(_segment_distance(b, c, p, q), _segment_distance(c, a, p, q)))

## Owning trail id of a world point inside a band and off every road plane.
func trail_owner(x: float, z: float) -> String:
	var near: Dictionary = trail_near(x, z)
	if near.is_empty() or near.distance > near.half_width or not road_owner(x, z).is_empty():
		return ""
	return near.id

## Published triangle under a world point of a trail zone: {height_m,
## normal}; {} outside the zones or without published triangles.
func _published_sample(x: float, z: float) -> Dictionary:
	if _published.is_empty():
		return {}
	var lx: float = x - _bounds.min_x
	var lz: float = z - _bounds.min_z
	if _trail_near_local(lx, lz, PUBLISHED_REACH_M).is_empty():
		return {}
	var starts: Variant = _published.get(Vector2i(int(floor(lx / PUBLISHED_CELL_M)), int(floor(lz / PUBLISHED_CELL_M))))
	if starts == null:
		return {}
	var p := Vector2(lx, lz)
	for start: int in starts:
		var a: Vector3 = _published_vertices[start]
		var b: Vector3 = _published_vertices[start + 1]
		var c: Vector3 = _published_vertices[start + 2]
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var v2 := Vector2(p.x - a.x, p.y - a.z)
		var den: float = v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-12:
			continue
		var v: float = (v2.x * v1.y - v1.x * v2.y) / den
		var w: float = (v0.x * v2.y - v2.x * v0.y) / den
		if v >= -1e-7 and w >= -1e-7 and v + w <= 1.0 + 1e-7:
			var normal: Vector3 = (c - a).cross(b - a).normalized()
			return {"height_m": a.y + v * (b.y - a.y) + w * (c.y - a.y), "normal": normal}
	return {}

func get_bounds_m() -> Dictionary:
	return _bounds.duplicate()

func get_region_signature() -> String:
	return _natural.get_region_signature()

func sample_surface(x: float, z: float) -> Dictionary:
	var result: Dictionary = _mesh_sample(x,z)
	result.erase("_natural_height")
	result.erase("_wet")
	if _trails.is_empty() or not result.is_valid or result.kind == "ROAD":
		return result
	var published: Dictionary = _published_sample(x, z)
	if not published.is_empty():
		result.height_m = published.height_m
	var near: Dictionary = trail_near(x, z)
	if not near.is_empty() and near.distance <= near.half_width:
		result.merge({"kind": "TRAIL", "owner": near.id, "lateral": near.lateral, "half_width": near.half_width}, true)
	return result

func _mesh_sample(x: float,z: float) -> Dictionary:
	var h: Dictionary = _natural.sample_height(x, z)
	if not h.is_valid:
		return h
	if _deformer == null:
		return {"is_valid": true, "height_m": h.height_m, "kind": "TERRAIN", "owner": "", "lateral": INF, "half_width": 0.0, "reason_code": ""}
	var result: Dictionary = _deformer.evaluate(x - _bounds.min_x, z - _bounds.min_z, h.height_m)
	result["_natural_height"] = h.height_m
	return result

func sample_height(x: float, z: float) -> Dictionary:
	return sample_surface(x, z)

func is_fine_cell(i: int, j: int) -> bool:
	return _fine_cells.has(Vector2i(i - int(_bounds.min_x/16), j - int(_bounds.min_z/16)))

func _road_cell(i: int,j: int) -> bool:
	return _road_cells.has(Vector2i(i-int(_bounds.min_x/16),j-int(_bounds.min_z/16)))

func _road_leaf(x2: int,z2: int) -> bool:
	return _road_leaves.has(Vector2i(int(floor(x2/2.0))-_bounds.min_x,int(floor(z2/2.0))-_bounds.min_z))

## Owning road piece id at a world point ("" off road): the layer test of
## _collision_layer, naming the owner (PR1: road / rough-road layers by class).
func road_owner(x: float, z: float) -> String:
	return _deformer.owner_at(x-_bounds.min_x,z-_bounds.min_z) if _deformer!=null else ""

func _collision_layer(x: float,z: float) -> int:
	return 2 if _deformer!=null and _deformer._owns_road_point(x-_bounds.min_x,z-_bounds.min_z) else 4

func _cap_leaf(x2: int,z2: int) -> bool:
	return _cap_leaves.has(Vector2i(int(floor(x2/2.0))-_bounds.min_x,int(floor(z2/2.0))-_bounds.min_z))

func sample_gradient(x: float, z: float) -> Dictionary:
	var query: Dictionary = _natural.sample_height(x,z)
	if not query.is_valid:
		return {"is_valid":false,"gradient":Vector2(NAN,NAN),"reason_code":query.reason_code}
	var published: Dictionary = _published_sample(x, z) if not _published.is_empty() and road_owner(x, z).is_empty() else {}
	if not published.is_empty():
		return {"is_valid": true, "gradient": Vector2(-published.normal.x / published.normal.y, -published.normal.z / published.normal.y), "reason_code": ""}
	var step: float = 0.25 if is_fine_cell(int(floor(x/16)), int(floor(z/16))) else 16.0
	var x0: float = maxf(_bounds.min_x, x-step)
	var x1: float = minf(_bounds.max_x, x+step)
	var z0: float = maxf(_bounds.min_z, z-step)
	var z1: float = minf(_bounds.max_z, z+step)
	var values: Array = [sample_height(x0,z), sample_height(x1,z), sample_height(x,z0), sample_height(x,z1)]
	for v: Dictionary in values:
		if not v.is_valid:
			return {"is_valid": false, "gradient": Vector2(NAN,NAN), "reason_code": v.reason_code}
	return {"is_valid": true, "gradient": Vector2((values[1].height_m-values[0].height_m)/(x1-x0),(values[3].height_m-values[2].height_m)/(z1-z0)), "reason_code": ""}

func sample_normal(x: float, z: float) -> Dictionary:
	var published: Dictionary = _published_sample(x, z) if not _published.is_empty() and road_owner(x, z).is_empty() else {}
	if not published.is_empty():
		return {"is_valid": true, "normal": published.normal, "reason_code": ""}
	var g: Dictionary = sample_gradient(x,z)
	return {"is_valid": g.is_valid, "normal": Vector3(-g.gradient.x,1,-g.gradient.y).normalized(), "reason_code": g.reason_code}

func sample_lattice(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	return _grid(i0*16.0,j0*16.0,nx,nz,16.0)

func sample_fine_grid(i0: int, j0: int, nx: int, nz: int) -> Dictionary:
	return _grid(i0*0.5,j0*0.5,nx,nz,0.5)

func _grid(x: float, z: float, nx: int, nz: int, step: float) -> Dictionary:
	var heights := PackedFloat64Array()
	var normals := PackedVector3Array()
	if nx<=0 or nz<=0:
		return {"is_valid": false, "reason_code": "ERR_TERRAIN_GRID_SHAPE"}
	for j in range(nz):
		for i in range(nx):
			var h: Dictionary = sample_height(x+i*step,z+j*step)
			if not h.is_valid:
				return h
			heights.append(h.height_m)
			var normal: Dictionary=sample_normal(x+i*step,z+j*step)
			if not normal.is_valid: return normal
			normals.append(normal.normal)
	return {"is_valid": true, "heights_m": heights, "normals": normals, "reason_code": ""}

func signature_for_cells(cells: Array) -> String:
	var bytes := PackedByteArray()
	for cell: Vector2i in cells:
		bytes.append_array(var_to_bytes(sample_fine_grid(cell.x*32,cell.y*32,33,33).get("heights_m",PackedFloat64Array())))
	return bytes.hex_encode().sha256_text()
