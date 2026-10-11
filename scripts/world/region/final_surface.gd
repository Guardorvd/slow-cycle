class_name FinalSurface
extends RefCounted
const Natural = preload("res://scripts/world/region/hydrology_surface.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
var _natural: RefCounted
var _deformer: RefCounted
var _bounds: Dictionary
var _fine_cells: Dictionary = {}
var _road_cells: Dictionary = {}
var _road_leaves: Dictionary = {}
var _cap_leaves: Dictionary = {}
var _boundary_points: Dictionary = {}

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

func get_bounds_m() -> Dictionary:
	return _bounds.duplicate()

func get_region_signature() -> String:
	return _natural.get_region_signature()

func sample_surface(x: float, z: float) -> Dictionary:
	var result: Dictionary = _mesh_sample(x,z)
	result.erase("_natural_height")
	result.erase("_wet")
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
