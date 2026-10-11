extends RefCounted

## PR1 M5 runtime adapter: low-poly procedural meshes of the regional
## vegetation kinds (RegionVegetationPlanner.KINDS), one material each, origin
## at the ground contact point. Built once per scene on the main thread.

const KINDS: Array[String] = ["pine", "birch", "autumn", "shrub", "grass", "rock"]
## Visible distance per kind (m) and whether it casts shadows.
const RANGE_M := {"pine": 900.0, "birch": 800.0, "autumn": 800.0, "shrub": 320.0, "grass": 140.0, "rock": 450.0}
const SHADOWS := {"pine": true, "birch": true, "autumn": true, "shrub": false, "grass": false, "rock": false}
## Collider height (m) at scale 1 for trunk cylinders.
const TRUNK_HEIGHT := {"pine": 3.0, "birch": 3.0, "autumn": 3.0}


static func build_all() -> Dictionary:
	return {"pine": _pine(), "birch": _birch(Color(0.40, 0.58, 0.24)), "autumn": _birch(Color(0.86, 0.47, 0.16)), "shrub": _shrub(), "grass": _grass(), "rock": _rock()}


static func _material(color: Color, double_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _trunk(st: SurfaceTool, radius: float, height: float, segs: int) -> void:
	for i in range(segs):
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		var p0 := Vector3(cos(a0) * radius, -0.3, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, -0.3, sin(a1) * radius)
		var p2 := Vector3(cos(a0) * radius * 0.75, height, sin(a0) * radius * 0.75)
		var p3 := Vector3(cos(a1) * radius * 0.75, height, sin(a1) * radius * 0.75)
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)


static func _pine() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, 0.18, 2.2, 6)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(Color(0.33, 0.24, 0.17)))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	for c: Array in [[1.6, 2.0, 2.6], [3.0, 1.6, 2.4], [4.3, 1.1, 2.2], [5.4, 0.7, 1.8]]:
		var base_y: float = c[0]
		var r: float = c[1]
		var tip := Vector3(0.0, base_y + c[2], 0.0)
		for i in range(segs):
			var a0: float = TAU * i / segs
			var a1: float = TAU * (i + 1) / segs
			var p0 := Vector3(cos(a0) * r, base_y, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, base_y, sin(a1) * r)
			st.add_vertex(p0); st.add_vertex(tip); st.add_vertex(p1)
			st.add_vertex(p1); st.add_vertex(Vector3(0.0, base_y, 0.0)); st.add_vertex(p0)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(1, _material(Color(0.15, 0.30, 0.19)))
	return mesh


static func _blob(st: SurfaceTool, c: Vector3, r: float, segs: int) -> void:
	var top := c + Vector3(0.0, r, 0.0)
	var bottom := c - Vector3(0.0, r * 0.9, 0.0)
	var rings: Array = []
	for y: Array in [[0.55, 0.75], [0.0, 1.0], [-0.5, 0.7]]:
		var ring: Array[Vector3] = []
		for i in range(segs):
			var a: float = TAU * i / segs + y[0] * 0.4
			ring.append(c + Vector3(cos(a) * r * y[1], y[0] * r, sin(a) * r * y[1]))
		rings.append(ring)
	for i in range(segs):
		var n: int = (i + 1) % segs
		st.add_vertex(rings[0][i]); st.add_vertex(top); st.add_vertex(rings[0][n])
		for b in range(2):
			st.add_vertex(rings[b + 1][i]); st.add_vertex(rings[b][i]); st.add_vertex(rings[b + 1][n])
			st.add_vertex(rings[b + 1][n]); st.add_vertex(rings[b][i]); st.add_vertex(rings[b][n])
		st.add_vertex(rings[2][n]); st.add_vertex(bottom); st.add_vertex(rings[2][i])


static func _birch(leaf: Color) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_trunk(st, 0.12, 3.6, 6)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(Color(0.86, 0.85, 0.80)))
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st, Vector3(0.0, 4.0, 0.0), 1.4, 7)
	_blob(st, Vector3(0.4, 5.0, -0.3), 1.0, 6)
	_blob(st, Vector3(-0.35, 3.5, 0.35), 0.95, 6)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(1, _material(leaf))
	return mesh


static func _shrub() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_blob(st, Vector3(0.0, 0.6, 0.0), 0.9, 6)
	_blob(st, Vector3(0.6, 0.5, 0.3), 0.7, 5)
	_blob(st, Vector3(-0.5, 0.45, -0.4), 0.65, 5)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(Color(0.22, 0.42, 0.20)))
	return mesh


static func _grass() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(5):
		var a: float = TAU * k / 5.0
		var o := Vector3(cos(a) * 0.6, 0.0, sin(a) * 0.6)
		var side := Vector3(-sin(a), 0.0, cos(a)) * 0.3
		st.add_vertex(o - side); st.add_vertex(o + Vector3(0.0, 0.6, 0.0)); st.add_vertex(o + side)
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(Color(0.36, 0.52, 0.22), true))
	return mesh


static func _rock() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 6
	var radial: Array[float] = [1.0, 0.85, 1.15, 0.9, 1.1, 0.95]
	var lift: Array[float] = [0.0, 0.08, -0.05, 0.06, -0.04, 0.05]
	var base: Array[Vector3] = []
	var mid: Array[Vector3] = []
	for i in range(segs):
		var a: float = TAU * i / segs
		base.append(Vector3(cos(a) * 0.55 * radial[i], -0.2, sin(a) * 0.55 * radial[i]))
		mid.append(Vector3(cos(a) * 0.7 * radial[(i + 2) % segs], 0.4 + lift[i], sin(a) * 0.7 * radial[(i + 2) % segs]))
	var apex := Vector3(0.05, 0.75, -0.04)
	for i in range(segs):
		var n: int = (i + 1) % segs
		st.add_vertex(base[i]); st.add_vertex(mid[i]); st.add_vertex(base[n])
		st.add_vertex(base[n]); st.add_vertex(mid[i]); st.add_vertex(mid[n])
		st.add_vertex(mid[i]); st.add_vertex(apex); st.add_vertex(mid[n])
	st.generate_normals()
	st.commit(mesh)
	mesh.surface_set_material(0, _material(Color(0.45, 0.43, 0.40)))
	return mesh
