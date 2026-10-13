class_name FinalSurfaceTileRenderer
extends RefCounted
## One indexed triangle list. Transition fans explicitly consume all 33
## vertices on fine boundaries; tile boundaries use the same world keys.
## BC1 trails (surface with trails; otherwise nothing below runs): the tile is
## first built exactly as without trails, then refined along every trail band
## without changing its shape (_refine_trails; refine_arrays starts from such
## a built tile and takes the tile-border splits its neighbours made).
const TILE_SIZE_M = 512
## Longest triangle edge (m) within TRAIL_REFINE_M of a band edge.
const TRAIL_EDGE_M: float = 0.5
const TRAIL_REFINE_M: float = 1.0
## Terrain vertices this close to a band carry trail shading coordinates.
const TRAIL_SHADE_M: float = 2.5
## Bound on nested bisection propagation (longest-edge path length).
const TRAIL_LEPP_DEPTH: int = 256
var _surface: RefCounted
var _origin := Vector2.ZERO
var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uv := PackedVector2Array()
var _indices := PackedInt32Array()
var _lookup: Dictionary = {}
var _samples: Dictionary = {}
var _refinement: Dictionary = {}
var _road_mask := PackedByteArray()
var _intersections: Dictionary = {}
var _local_boundary_points: Array[Vector2] = []
var _reason := ""
## Owning pieces of the failed sample (PR1: the bake isolates them).
var _owners: Array = []
## Trail refinement state: triangles (3 vertex ids each, -1 removed), edge ->
## Vector2i(triangle, triangle or -1), edge midpoints, band edge points, and
## the world points of the midpoints made on the tile border.
var _tri := PackedInt32Array()
var _edge_tris: Dictionary = {}
var _mids: Dictionary = {}
var _band_points: Dictionary = {}
var _inside: Dictionary = {}
var _border_made: Dictionary = {}

static func tile_arrays(surface: RefCounted, tx: int, tz: int) -> Dictionary:
	var builder := FinalSurfaceTileRenderer.new()
	builder._surface = surface
	builder._origin = Vector2(tx*512, tz*512)
	for j in range(tz*32,(tz+1)*32):
		for i in range(tx*32,(tx+1)*32):
			builder._cell(i,j)
			if not builder._reason.is_empty():
				return {"is_valid": false, "reason_code": builder._reason, "owners": builder._owners}
	builder._weld()
	return builder._finish(tx, tz, {})

## BC1: the trail refinement of a tile already built by tile_arrays on the same
## surface without trails (`arrays`), splitting its border edges at least at
## the `forced` world points (Vector2 keys: midpoints made by the tiles across
## its borders). The result also lists `border_points`, the world points of
## every midpoint this tile made on its border; tiles agree on a border once
## no tile adds a point the others were not forced to make.
static func refine_arrays(surface: RefCounted, arrays: Array, tx: int, tz: int, forced: Dictionary) -> Dictionary:
	var builder := FinalSurfaceTileRenderer.new()
	builder._surface = surface
	builder._origin = Vector2(tx*512, tz*512)
	builder._vertices = arrays[Mesh.ARRAY_VERTEX].duplicate()
	builder._uv = arrays[Mesh.ARRAY_TEX_UV].duplicate()
	builder._indices = arrays[Mesh.ARRAY_INDEX].duplicate()
	builder._normals.resize(builder._vertices.size())
	return builder._finish(tx, tz, forced)

## Trail refinement (surfaces with trails), then normals and arrays.
func _finish(tx: int, tz: int, forced: Dictionary) -> Dictionary:
	if _surface.has_trails():
		_refine_trails(forced)
		if not _reason.is_empty():
			return {"is_valid": false, "reason_code": _reason, "owners": _owners}
	# Derive interior shading normals from these very triangles. Only shared
	# tile-boundary normals need the deterministic field stencil. This avoids
	# four extra deformer evaluations at every fine interior vertex.
	var vertices: PackedVector3Array = _vertices
	var indices: PackedInt32Array = _indices
	var normals: PackedVector3Array = _normals
	_normals = PackedVector3Array()
	for k in range(0,indices.size(),3):
		var a: int = indices[k]
		var b: int = indices[k+1]
		var c: int = indices[k+2]
		var normal: Vector3 = (vertices[c]-vertices[a]).cross(vertices[b]-vertices[a])
		normals[a] += normal
		normals[b] += normal
		normals[c] += normal
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		if v.x==0 or v.z==0 or v.x==512 or v.z==512:
			var normal: Dictionary=_surface.sample_normal(v.x+_origin.x,v.z+_origin.y)
			if not normal.is_valid: return {"is_valid":false,"reason_code":normal.reason_code}
			normals[i] = normal.normal
		else:
			normals[i] = normals[i].normalized()
	_normals = normals
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _indices
	return {"is_valid": true, "reason_code": "", "arrays": arrays, "origin_x_m": tx*512, "origin_z_m": tz*512, "vertex_count": _vertices.size(), "triangle_count": _indices.size()/3, "array_bytes": _vertices.size()*32 + _indices.size()*4,
		"border_points": _border_made.keys()}

func _vertex(x2: float, z2: float) -> int:
	var key := Vector2(x2,z2)
	var existing: int=_lookup.get(key,-1)
	if existing>=0: return existing
	var x: float = x2*0.5
	var z: float = z2*0.5
	var h: Dictionary = _sample(x2,z2)
	if not h.is_valid:
		_reason = h.reason_code
		_owners = h.get("owners", [])
		return 0
	var id: int = _vertices.size()
	_lookup[key] = id
	_vertices.append(Vector3(x-_origin.x,h.height_m,z-_origin.y))
	_normals.append(Vector3.ZERO)
	_uv.append(Vector2(h.lateral, h.half_width) if h.kind == "ROAD" else Vector2(100,0))
	_road_mask.append(1 if h.kind=="ROAD" else 0)
	return id

func _triangle(a: int,b: int,c: int) -> void:
	if not _reason.is_empty(): return
	if _local_boundary_points.is_empty() and _road_mask[a]==_road_mask[b] and _road_mask[b]==_road_mask[c]:
		_emit(a,b,c)
		return
	if _road_mask[a]==0 and _road_mask[b]==0 and _road_mask[c]==0:
		var midpoint: Vector3=(_vertices[a]+_vertices[b]+_vertices[c])/3.0
		if not _surface.is_fine_cell(int(floor((midpoint.x+_origin.x)/16)),int(floor((midpoint.z+_origin.y)/16))):
			_emit(a,b,c)
			return
	# Preserve each designed shoulder station corner in the triangulation.
	# Otherwise clipping may shortcut a convex turn by a millimetre and give
	# an exact edge ray the terrain layer despite continuous height geometry.
	var va := Vector2(_vertices[a].x+_origin.x,_vertices[a].z+_origin.y)
	var vb := Vector2(_vertices[b].x+_origin.x,_vertices[b].z+_origin.y)
	var vc := Vector2(_vertices[c].x+_origin.x,_vertices[c].z+_origin.y)
	for world: Vector2 in _local_boundary_points:
		if world==va or world==vb or world==vc: continue
		var ab: float=(vb-va).cross(world-va)
		var bc: float=(vc-vb).cross(world-vb)
		var ca: float=(va-vc).cross(world-vc)
		if ab>=-0.000001 and bc>=-0.000001 and ca>=-0.000001:
			var id: int=_vertex(world.x*2,world.y*2)
			if id in [a,b,c]: continue
			if absf(ab)<0.000001:
				_triangle(a,id,c)
				_triangle(id,b,c)
			elif absf(bc)<0.000001:
				_triangle(b,id,a)
				_triangle(id,c,a)
			elif absf(ca)<0.000001:
				_triangle(c,id,b)
				_triangle(id,a,b)
			else:
				_triangle(a,b,id)
				_triangle(b,c,id)
				_triangle(c,a,id)
			return
	if _road_mask[a]==_road_mask[b] and _road_mask[b]==_road_mask[c]:
		_emit(a,b,c)
		return
	# Clip at actual domain ownership, rather than assign a whole crossing
	# triangle by centroid. Shared-edge intersections are cached, and both
	# polygons use the same authoritative intersection vertex and height.
	var road: Array[int] = []
	var terrain: Array[int] = []
	var corners: Array[int] = [a,b,c]
	for k in range(3):
		var current: int = corners[k]
		var next: int = corners[(k+1)%3]
		if _road_mask[current]==1:
			road.append(current)
		else:
			terrain.append(current)
		if _road_mask[current]!=_road_mask[next]:
			var split: int = _split_edge(current,next)
			road.append(split)
			terrain.append(split)
	for polygon: Array[int] in [road,terrain]:
		for k in range(1,polygon.size()-1):
			_emit(polygon[0],polygon[k],polygon[k+1])

func _weld() -> void:
	# Float32 geometry can make intersections on two distinct edges coincide.
	# Weld exact positions before normal accumulation so topology stays shared.
	var positions: Dictionary={}
	var remap:=PackedInt32Array()
	var vertices:=PackedVector3Array()
	var uv:=PackedVector2Array()
	for k in range(_vertices.size()):
		var point: Vector3=_vertices[k]
		if not positions.has(point):
			positions[point]=vertices.size()
			vertices.append(point)
			uv.append(_uv[k])
		remap.append(positions[point])
	var indices:=PackedInt32Array()
	for k in range(0,_indices.size(),3):
		var a: int=remap[_indices[k]]
		var b: int=remap[_indices[k+1]]
		var c: int=remap[_indices[k+2]]
		if a!=b and b!=c and c!=a:
			indices.append(a)
			indices.append(b)
			indices.append(c)
	_vertices=vertices
	_indices=indices
	_uv=uv
	_normals=PackedVector3Array()
	_normals.resize(vertices.size())

## BC1: exact refinement of this tile along the trail bands (after _weld,
## before normals; a tile with no band within reach and no forced border
## point returns unchanged).
##  1. Border edges holding a forced point are split at their midpoints,
##     recursively, until every forced point is a vertex (forced points are
##     the neighbours' border midpoints of the same edges: same world points).
##  2. Every triangle within TRAIL_REFINE_M of a band is bisected at its
##     longest edge until its edges are <= TRAIL_EDGE_M. A bisection splits
##     both triangles of that edge, after refining the neighbour first when
##     the edge is not its longest (longest-edge propagation, Rivara), so the
##     tile stays conforming; border midpoints made here are reported.
##  3. Triangles crossing a band edge are clipped at it: one point per edge
##     by world-coordinate bisection, height linear along the edge.
##  4. Terrain vertices within TRAIL_SHADE_M of a band carry UV (lateral,
##     -half width) for the trail material.
## Every new vertex lies on an edge of the published triangulation with its
## linear height: the refined tile is the same surface. Failure (a non-
## manifold edge, propagation deeper than TRAIL_LEPP_DEPTH, a forced point on
## no edge) is ERR_TRAIL_TILE, owned by the trails.
func _refine_trails(forced: Dictionary) -> void:
	var o := Vector2(_surface._bounds.min_x, _surface._bounds.min_z)
	var reach: Rect2 = Rect2(_origin - o, Vector2(TILE_SIZE_M, TILE_SIZE_M)).grow(TRAIL_REFINE_M + 1.5)
	var near := false
	for trail: Dictionary in _surface._trails:
		var line: Dictionary = trail.line
		for k in range(line.s.size()):
			near = near or reach.grow(trail.half_width_m).has_point(Vector2(line.x[k], line.z[k]))
	var tile := Rect2(_origin, Vector2(TILE_SIZE_M, TILE_SIZE_M))
	var mine: Array = []
	for point: Vector2 in forced:
		if tile.grow(0.001).has_point(point) and not tile.grow(-0.001).has_point(point):
			mine.append(point)
	if not near and mine.is_empty():
		return
	_tri = _indices.duplicate()
	_edge_tris.clear()
	_mids.clear()
	_band_points.clear()
	_inside.clear()
	_border_made.clear()
	var bad: Dictionary = {}
	for t in range(_tri.size() / 3):
		_link(t, bad)
	# 1. Forced border points.
	if not mine.is_empty():
		var wanted: Dictionary = {}
		for point: Vector2 in mine:
			wanted[point] = true
		var roots: Array = []
		for key: Vector2i in _edge_tris.keys():
			if _border(key):
				roots.append(key)
		roots.sort()
		for key: Vector2i in roots:
			_force_border(key, wanted, bad, 0)
			if not _reason.is_empty():
				return
		for point: Vector2 in mine:
			if not _border_made.has(point) and not _is_vertex_on_border(point):
				_fail_trail("forced point %s on no border edge" % str(point))
				return
	# 2. Longest-edge refinement near the bands.
	var t: int = 0
	while t < _tri.size() / 3:
		if _tri[3 * t] >= 0 and _edge_length(_longest(t)) > TRAIL_EDGE_M:
			var gap: float = _surface.trail_triangle_gap(_world(_tri[3 * t]), _world(_tri[3 * t + 1]), _world(_tri[3 * t + 2]))
			if gap <= TRAIL_REFINE_M:
				_lepp(t, bad, 0)
				if not _reason.is_empty():
					return
		t += 1
	# 3. Clip at the band edges.
	var count: int = _tri.size() / 3
	for q in range(count):
		if _tri[3 * q] < 0:
			continue
		var corners: Array[int] = [_tri[3 * q], _tri[3 * q + 1], _tri[3 * q + 2]]
		var inside: Array[bool] = [_in_band(corners[0]), _in_band(corners[1]), _in_band(corners[2])]
		if inside[0] == inside[1] and inside[1] == inside[2]:
			continue
		var band: Array[int] = []
		var rest: Array[int] = []
		for k in range(3):
			if inside[k]:
				band.append(corners[k])
			else:
				rest.append(corners[k])
			if inside[k] != inside[(k + 1) % 3]:
				var point: int = _band_point(corners[k], corners[(k + 1) % 3])
				band.append(point)
				rest.append(point)
		for i in range(3):
			_tri[3 * q + i] = -1
		for polygon: Array[int] in [band, rest]:
			for k in range(1, polygon.size() - 1):
				_tri.append_array([polygon[0], polygon[k], polygon[k + 1]])
	# 4. Trail shading coordinates.
	for v in range(_vertices.size()):
		if _uv[v] != Vector2(100, 0):
			continue
		var world: Vector2 = _world(v)
		var nearest: Dictionary = _surface.trail_near(world.x, world.y, TRAIL_SHADE_M)
		if not nearest.is_empty():
			_uv[v] = Vector2(nearest.lateral, -nearest.half_width)
	_indices = PackedInt32Array()
	for q in range(_tri.size() / 3):
		if _tri[3 * q] >= 0:
			_emit(_tri[3 * q], _tri[3 * q + 1], _tri[3 * q + 2])
	_normals = PackedVector3Array()
	_normals.resize(_vertices.size())

func _is_vertex_on_border(point: Vector2) -> bool:
	var local: Vector2 = point - _origin
	for v: Vector3 in _vertices:
		if v.x == local.x and v.z == local.y:
			return true
	return false

func _fail_trail(detail: String) -> void:
	if _reason.is_empty():
		_reason = "ERR_TRAIL_TILE"
		_owners = []
		for trail: Dictionary in _surface._trails:
			_owners.append(trail.id)
		push_warning("BC1 trail refinement failed at tile %s: %s" % [str(_origin / TILE_SIZE_M), detail])

func _world(v: int) -> Vector2:
	return Vector2(_vertices[v].x + _origin.x, _vertices[v].z + _origin.y)

static func _ekey(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))

func _link(t: int, bad: Dictionary) -> void:
	for i in range(3):
		var key: Vector2i = _ekey(_tri[3 * t + i], _tri[3 * t + (i + 1) % 3])
		var pair: Vector2i = _edge_tris.get(key, Vector2i(-1, -1))
		if pair.x < 0:
			pair.x = t
		elif pair.y < 0:
			pair.y = t
		else:
			bad[key] = pair
			continue
		_edge_tris[key] = pair

func _unlink(t: int) -> void:
	for i in range(3):
		var key: Vector2i = _ekey(_tri[3 * t + i], _tri[3 * t + (i + 1) % 3])
		var pair: Vector2i = _edge_tris.get(key, Vector2i(-1, -1))
		if pair.x == t:
			pair = Vector2i(pair.y, -1)
		elif pair.y == t:
			pair.y = -1
		if pair.x < 0:
			_edge_tris.erase(key)
		else:
			_edge_tris[key] = pair

func _border(key: Vector2i) -> bool:
	var a: Vector3 = _vertices[key.x]
	var b: Vector3 = _vertices[key.y]
	return (a.x == b.x and (a.x == 0.0 or a.x == TILE_SIZE_M)) or (a.z == b.z and (a.z == 0.0 or a.z == TILE_SIZE_M))

func _edge_length(key: Vector2i) -> float:
	var a: Vector3 = _vertices[key.x]
	var b: Vector3 = _vertices[key.y]
	return Vector2(b.x - a.x, b.z - a.z).length()

## Longest edge of a triangle; ties by vertex ids (a strict total order, so
## propagation paths cannot cycle).
func _longest(t: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_length: float = -1.0
	for i in range(3):
		var key: Vector2i = _ekey(_tri[3 * t + i], _tri[3 * t + (i + 1) % 3])
		var length: float = _edge_length(key)
		if length > best_length or (length == best_length and (key.x > best.x or (key.x == best.x and key.y > best.y))):
			best = key
			best_length = length
	return best

func _midpoint(key: Vector2i) -> int:
	if _mids.has(key):
		return _mids[key]
	var id: int = _vertices.size()
	_vertices.append((_vertices[key.x] + _vertices[key.y]) * 0.5)
	_uv.append(Vector2(100, 0) if _uv[key.x] == Vector2(100, 0) and _uv[key.y] == Vector2(100, 0) else (_uv[key.x] + _uv[key.y]) * 0.5)
	_mids[key] = id
	if _border(key):
		_border_made[_world(id)] = true
	return id

## Split triangle t at the midpoint of its edge `key` into two triangles of
## the same winding.
func _bisect(t: int, key: Vector2i, bad: Dictionary) -> void:
	if bad.has(key):
		_fail_trail("non-manifold edge %s" % str(key))
		return
	var i: int = 0
	while i < 3 and _ekey(_tri[3 * t + i], _tri[3 * t + (i + 1) % 3]) != key:
		i += 1
	var a: int = _tri[3 * t + i]
	var b: int = _tri[3 * t + (i + 1) % 3]
	var c: int = _tri[3 * t + (i + 2) % 3]
	var m: int = _midpoint(key)
	_unlink(t)
	for k in range(3):
		_tri[3 * t + k] = -1
	var first: int = _tri.size() / 3
	_tri.append_array([a, m, c, m, b, c])
	_link(first, bad)
	_link(first + 1, bad)

## Bisect t at its longest edge, keeping the tile conforming (a border edge
## has no neighbour here; its midpoint is reported to the bake).
func _lepp(t: int, bad: Dictionary, depth: int) -> void:
	while _reason.is_empty() and _tri[3 * t] >= 0:
		if depth > TRAIL_LEPP_DEPTH:
			_fail_trail("propagation depth")
			return
		var key: Vector2i = _longest(t)
		var pair: Vector2i = _edge_tris[key]
		var n: int = pair.y if pair.x == t else pair.x
		if n < 0:
			_bisect(t, key, bad)
			return
		if _longest(n) == key:
			_bisect(t, key, bad)
			_bisect(n, key, bad)
			return
		_lepp(n, bad, depth + 1)

## Split border edge `key` at its midpoint while a wanted point lies strictly
## inside it (first refining its triangle until the edge is its longest), then
## recurse into both halves.
func _force_border(key: Vector2i, wanted: Dictionary, bad: Dictionary, depth: int) -> void:
	if not _reason.is_empty():
		return
	var a: Vector2 = _world(key.x)
	var b: Vector2 = _world(key.y)
	var inside := false
	for point: Vector2 in wanted:
		if (a.x == b.x and point.x == a.x and point.y > minf(a.y, b.y) and point.y < maxf(a.y, b.y)) or (a.y == b.y and point.y == a.y and point.x > minf(a.x, b.x) and point.x < maxf(a.x, b.x)):
			inside = true
			break
	if not inside:
		return
	if depth > 64:
		_fail_trail("forced border depth")
		return
	var guard: int = 0
	while not _mids.has(key):
		var t: int = _edge_tris[key].x
		if _longest(t) == key:
			_bisect(t, key, bad)
			break
		_lepp(t, bad, 0)
		guard += 1
		if not _reason.is_empty() or guard > 64:
			_fail_trail("forced border split")
			return
	var m: int = _mids[key]
	_force_border(_ekey(key.x, m), wanted, bad, depth + 1)
	_force_border(_ekey(m, key.y), wanted, bad, depth + 1)

func _in_band(v: int) -> bool:
	if _inside.has(v):
		return _inside[v]
	var world: Vector2 = _world(v)
	var nearest: Dictionary = _surface.trail_near(world.x, world.y)
	var inside: bool = not nearest.is_empty() and nearest.distance <= nearest.half_width
	_inside[v] = inside
	return inside

## The band edge point on edge a-b (endpoints on opposite sides): parameter
## by bisection of the band test in world coordinates from the lower world
## endpoint (both tiles of a border edge find the same one); position, height
## and UV linear along the tile-local edge.
func _band_point(a: int, b: int) -> int:
	var key: Vector2i = _ekey(a, b)
	if _band_points.has(key):
		return _band_points[key]
	var pa: Vector2 = _world(a)
	var pb: Vector2 = _world(b)
	if pa.x > pb.x or (pa.x == pb.x and pa.y > pb.y):
		var swap: int = a
		a = b
		b = swap
		pa = _world(a)
		pb = _world(b)
	var start_inside: bool = _in_band(a)
	var lo: float = 0.0
	var hi: float = 1.0
	for iteration in range(30):
		var mid: float = 0.5 * (lo + hi)
		var x: float = pa.x + (pb.x - pa.x) * mid
		var z: float = pa.y + (pb.y - pa.y) * mid
		var nearest: Dictionary = _surface.trail_near(x, z)
		var inside: bool = not nearest.is_empty() and nearest.distance <= nearest.half_width
		if inside == start_inside:
			lo = mid
		else:
			hi = mid
	var u: float = 0.5 * (lo + hi)
	var id: int = _vertices.size()
	var va: Vector3 = _vertices[a]
	var vb: Vector3 = _vertices[b]
	_vertices.append(va + (vb - va) * u)
	_uv.append(Vector2(100, 0) if _uv[a] == Vector2(100, 0) and _uv[b] == Vector2(100, 0) else _uv[a].lerp(_uv[b], u))
	_inside[id] = true
	_band_points[key] = id
	return id

func _emit(a: int,b: int,c: int) -> void:
	if a!=b and b!=c and c!=a and (_vertices[b]-_vertices[a]).cross(_vertices[c]-_vertices[a]).length_squared()>1e-16:
		_indices.append(a)
		_indices.append(b)
		_indices.append(c)

func _split_edge(a: int,b: int) -> int:
	var key := Vector2i(mini(a,b),maxi(a,b))
	if _intersections.has(key):
		return _intersections[key]
	var va := Vector2(_vertices[a].x+_origin.x,_vertices[a].z+_origin.y)
	var vb := Vector2(_vertices[b].x+_origin.x,_vertices[b].z+_origin.y)
	# World-coordinate ordering makes tile/build order irrelevant.
	if va.x>vb.x or (va.x==vb.x and va.y>vb.y):
		var tmp: Vector2=va
		va=vb
		vb=tmp
	var inside: Vector2 = va if _surface._collision_layer(va.x,va.y)==2 else vb
	var outside: Vector2 = vb if inside==va else va
	for iteration in range(14):
		var midpoint: Vector2=(inside+outside)/2.0
		if midpoint==inside or midpoint==outside:
			break
		if _surface._collision_layer(midpoint.x,midpoint.y)==2:
			inside=midpoint
		else:
			outside=midpoint
	for old: int in [a,b]:
		if Vector2(_vertices[old].x+_origin.x,_vertices[old].z+_origin.y)==inside:
			_intersections[key]=old
			return old
	var h: Dictionary=_surface._mesh_sample(inside.x,inside.y)
	if not h.is_valid:
		_reason=h.reason_code
		_owners = h.get("owners", [])
		return a
	var id: int=_vertices.size()
	_vertices.append(Vector3(inside.x-_origin.x,h.height_m,inside.y-_origin.y))
	_normals.append(Vector3.ZERO)
	_uv.append(Vector2(h.lateral,h.half_width) if h.kind=="ROAD" else Vector2(100,0))
	_road_mask.append(1)
	_intersections[key]=id
	return id

func _sample(x2: float,z2: float) -> Dictionary:
	var key := Vector2(x2,z2)
	var cached: Variant=_samples.get(key)
	if cached!=null: return cached
	var sample: Dictionary=_surface._mesh_sample(x2*0.5,z2*0.5)
	_samples[key]=sample
	return sample

func _want_fine(x2: int,z2: int) -> bool:
	return _leaf_resolution(x2,z2)<2.0

func _leaf_resolution(x2: int,z2: int) -> float:
	var key := Vector2i(x2,z2)
	var cached: float=_refinement.get(key,-1.0)
	if cached>0.0: return cached
	if not _surface.is_fine_cell(int(floor(x2/32.0)),int(floor(z2/32.0))):
		return 32.0
	var refine: bool=_surface._road_leaf(x2,z2)
	var wet := false
	var all_road := true
	var changed := false
	var unchanged := false
	for offset: Vector2i in [Vector2i.ZERO,Vector2i(2,0),Vector2i(0,2),Vector2i(2,2)]:
			var h: Dictionary = _sample(x2+offset.x,z2+offset.y)
			if not h.is_valid:
				_reason = h.reason_code
				_owners = h.get("owners", [])
				return 2.0
			wet = wet or h.get("_wet",false)
			all_road = all_road and h.kind=="ROAD"
			var delta: float = h.height_m-h.get("_natural_height",h.height_m)
			changed = changed or absf(delta)>0.000001
			unchanged = unchanged or absf(delta)<=0.000001
	if all_road:
		_refinement[key]=2.0
		return 2.0
	if _surface._cap_leaf(x2,z2):
		_refinement[key]=0.25
		return 0.25
	if changed and not unchanged:
		var centre: Dictionary=_sample(x2+1,z2+1)
		if centre.is_valid:
			unchanged=absf(centre.height_m-centre.get("_natural_height",centre.height_m))<=0.000001
	# Quarter-metre wet/channel and daylight cells capture the curved natural
	# bed without paying for eighth-metre refinement along every dry tie.
	var resolution: float=0.5 if wet or (changed and unchanged) else (1.0 if refine else 2.0)
	_refinement[key] = resolution
	return resolution

func _cell(i: int,j: int) -> void:
	var x: int = i*32
	var z: int = j*32
	if _surface.is_fine_cell(i,j):
		for v in range(16):
			for u in range(16):
				var lx: int = x+2*u
				var lz: int = z+2*v
				_local_boundary_points.clear()
				for dz: int in [0,1]:
					for dx: int in [0,1]:
						var key:=Vector2i(lx/2+dx-int(_surface._bounds.min_x),lz/2+dz-int(_surface._bounds.min_z))
						for point: Vector2 in _surface._boundary_points.get(key,[]):
							_local_boundary_points.append(point+Vector2(_surface._bounds.min_x,_surface._bounds.min_z))
				var resolution: float=_leaf_resolution(lx,lz)
				var divisions: int=int(2.0/resolution)
				for a in range(divisions):
					for b in range(divisions):
						var edges: Array[float]=[]
						edges.append(_leaf_resolution(lx,lz-2) if a==0 else resolution)
						edges.append(_leaf_resolution(lx+2,lz) if b==divisions-1 else resolution)
						edges.append(_leaf_resolution(lx,lz+2) if a==divisions-1 else resolution)
						edges.append(_leaf_resolution(lx-2,lz) if b==0 else resolution)
						_leaf(lx+b*resolution,lz+a*resolution,resolution,edges)
		return
	_local_boundary_points.clear()
	var neighbours: Array[int] = [_resolution(i,j-1),_resolution(i+1,j),_resolution(i,j+1),_resolution(i-1,j)]
	if neighbours==[32,32,32,32]:
		var a: int = _vertex(x,z)
		var b: int = _vertex(x+32,z)
		var c: int = _vertex(x,z+32)
		var d: int = _vertex(x+32,z+32)
		_triangle(a,b,c)
		_triangle(b,d,c)
		return
	var ring: Array[int] = []
	var corners: Array[Vector2i] = [Vector2i(x,z),Vector2i(x+32,z),Vector2i(x+32,z+32),Vector2i(x,z+32)]
	for edge in range(4):
		var count: int = 32/neighbours[edge]
		for k in range(count):
			var p: Vector2i = corners[edge] + (corners[(edge+1)%4]-corners[edge]) * k / count
			ring.append(_vertex(p.x,p.y))
			if count==16:
				var adjacent: Array[Vector2i] = [Vector2i(x+2*k,z-2),Vector2i(x+32,z+2*k),Vector2i(x+32-2*(k+1),z+32),Vector2i(x-2,z+32-2*(k+1))]
				var leaf: float=_leaf_resolution(adjacent[edge].x,adjacent[edge].y)
				if leaf<2.0:
					for part in range(1,int(2.0/leaf)):
						var mid: Vector2=Vector2(p)+Vector2(corners[(edge+1)%4]-corners[edge])*part*leaf/32.0
						ring.append(_vertex(mid.x,mid.y))
	var centre: int = _vertex(x+16,z+16)
	for k in range(ring.size()):
		_triangle(centre,ring[k],ring[(k+1)%ring.size()])

func _resolution(i: int,j: int) -> int:
	return 2 if _surface.is_fine_cell(i,j) else 32

func _leaf(x: float,z: float,step: float,finer: Array[float]) -> void:
	if finer[0]>=step and finer[1]>=step and finer[2]>=step and finer[3]>=step:
		var a: int = _vertex(x,z)
		var b: int = _vertex(x+step,z)
		var c: int = _vertex(x,z+step)
		var d: int = _vertex(x+step,z+step)
		_triangle(a,b,c)
		_triangle(b,d,c)
		return
	var corners: Array[Vector2] = [Vector2(x,z),Vector2(x+step,z),Vector2(x+step,z+step),Vector2(x,z+step)]
	var ring: Array[int] = []
	for side in range(4):
		var divisions: int=int(step/minf(step,finer[side]))
		for part in range(divisions):
			var point: Vector2=corners[side].lerp(corners[(side+1)%4],float(part)/divisions)
			ring.append(_vertex(point.x,point.y))
	var centre: int = _vertex(x+step/2,z+step/2)
	for k in range(ring.size()):
		_triangle(centre,ring[k],ring[(k+1)%ring.size()])

static func tile_mesh(surface: RefCounted, tx: int,tz: int) -> Dictionary:
	var result: Dictionary = tile_arrays(surface,tx,tz)
	if result.is_valid:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result.arrays)
		result["mesh"] = mesh
	return result

static func tile_collision_faces(surface: RefCounted, tile: Dictionary) -> Dictionary:
	var road := PackedVector3Array()
	var terrain := PackedVector3Array()
	var vertices: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
	for k in range(0,indices.size(),3):
		var a: Vector3 = vertices[indices[k]]
		var b: Vector3 = vertices[indices[k+1]]
		var c: Vector3 = vertices[indices[k+2]]
		var centre: Vector3 = (a+b+c)/3.0
		var layer: int = surface._collision_layer(tile.origin_x_m+centre.x,tile.origin_z_m+centre.z)
		if layer == 2:
			road.append_array([a,b,c])
		else:
			terrain.append_array([a,b,c])
	return {"is_valid": true, "reason_code": "", "road": road, "terrain": terrain}
