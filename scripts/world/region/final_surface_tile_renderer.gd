class_name FinalSurfaceTileRenderer
extends RefCounted
## One indexed triangle list. Transition fans explicitly consume all 33
## vertices on fine boundaries; tile boundaries use the same world keys.
const TILE_SIZE_M = 512
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

static func tile_arrays(surface: RefCounted, tx: int, tz: int) -> Dictionary:
	var builder := FinalSurfaceTileRenderer.new()
	builder._surface = surface
	builder._origin = Vector2(tx*512, tz*512)
	for j in range(tz*32,(tz+1)*32):
		for i in range(tx*32,(tx+1)*32):
			builder._cell(i,j)
			if not builder._reason.is_empty():
				return {"is_valid": false, "reason_code": builder._reason}
	builder._weld()
	# Derive interior shading normals from these very triangles. Only shared
	# tile-boundary normals need the deterministic field stencil. This avoids
	# four extra deformer evaluations at every fine interior vertex.
	var vertices: PackedVector3Array = builder._vertices
	var indices: PackedInt32Array = builder._indices
	var normals: PackedVector3Array = builder._normals
	builder._normals = PackedVector3Array()
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
			var normal: Dictionary=surface.sample_normal(v.x+builder._origin.x,v.z+builder._origin.y)
			if not normal.is_valid: return {"is_valid":false,"reason_code":normal.reason_code}
			normals[i] = normal.normal
		else:
			normals[i] = normals[i].normalized()
	builder._normals = normals
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = builder._vertices
	arrays[Mesh.ARRAY_NORMAL] = builder._normals
	arrays[Mesh.ARRAY_TEX_UV] = builder._uv
	arrays[Mesh.ARRAY_INDEX] = builder._indices
	return {"is_valid": true, "reason_code": "", "arrays": arrays, "origin_x_m": tx*512, "origin_z_m": tz*512, "vertex_count": builder._vertices.size(), "triangle_count": builder._indices.size()/3, "array_bytes": builder._vertices.size()*32 + builder._indices.size()*4}

func _vertex(x2: float, z2: float) -> int:
	var key := Vector2(x2,z2)
	var existing: int=_lookup.get(key,-1)
	if existing>=0: return existing
	var x: float = x2*0.5
	var z: float = z2*0.5
	var h: Dictionary = _sample(x2,z2)
	if not h.is_valid:
		_reason = h.reason_code
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
