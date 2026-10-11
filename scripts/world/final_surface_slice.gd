class_name FinalSurfaceSlice
extends Node3D
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
var metrics: Dictionary = {}
var tiles: Array[Dictionary] = []
var _route: RefCounted
const SHADER = """
shader_type spatial;
varying float road_distance;
void vertex() { road_distance = abs(UV.x)-UV.y; }
void fragment() {
 float road = 1.0-smoothstep(-0.05,0.05,road_distance);
 ALBEDO = mix(vec3(0.26,0.36,0.22),vec3(0.63,0.48,0.30),road);
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
"""

func build(surface: RefCounted, hydrology_plan: RefCounted, route: RefCounted) -> Dictionary:
	_route = route
	var t0 := Time.get_ticks_usec()
	var memory0: int = OS.get_static_memory_usage()
	var bounds: Dictionary = surface.get_bounds_m()
	var data: Dictionary = route.get_data()
	var route_tiles: Dictionary = {}
	for cell: Vector2i in surface._fine_cells:
		route_tiles[Vector2i(int(floor((bounds.min_x+cell.x*16)/512)),int(floor((bounds.min_z+cell.y*16)/512)))]=true
	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var vertex_count := 0
	var triangle_count := 0
	var array_bytes := 0
	var timings: Array=[]
	var keys: Array = route_tiles.keys()
	keys.sort()
	for key: Vector2i in keys:
		print("R7_TILE_BEGIN ",key)
		var tile0: int=Time.get_ticks_usec()
		var tile: Dictionary = Renderer.tile_mesh(surface,key.x,key.y)
		if not tile.is_valid:
			return tile
		print("R7_TILE_ARRAYS vertices=",tile.vertex_count," triangles=",tile.triangle_count)
		var arrays_ms: float=(Time.get_ticks_usec()-tile0)/1000.0
		tile0=Time.get_ticks_usec()
		var faces: Dictionary = Renderer.tile_collision_faces(surface,tile)
		if not faces.is_valid:
			return faces
		var faces_ms: float=(Time.get_ticks_usec()-tile0)/1000.0
		tile0=Time.get_ticks_usec()
		var instance := MeshInstance3D.new()
		instance.mesh = tile.mesh
		instance.material_override = material
		instance.position = Vector3(tile.origin_x_m,0,tile.origin_z_m)
		add_child(instance)
		var shapes: Dictionary={}
		for layer: int in [2,4]:
			var triangles: PackedVector3Array = faces.road if layer == 2 else faces.terrain
			if triangles.is_empty():
				continue
			var body := StaticBody3D.new()
			body.collision_layer = layer
			body.collision_mask = 0
			body.position = instance.position
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(triangles)
			shapes[layer]=shape
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			add_child(body)
		tile["faces"] = faces
		tile["shapes"]=shapes
		tiles.append(tile)
		timings.append({"tile":[key.x,key.y],"arrays_ms":arrays_ms,"partition_ms":faces_ms,"registration_ms":(Time.get_ticks_usec()-tile0)/1000.0})
		vertex_count += tile.vertex_count
		triangle_count += tile.triangle_count
		array_bytes += tile.array_bytes
	metrics = {"build_ms": (Time.get_ticks_usec()-t0)/1000.0, "vertices": vertex_count, "triangles": triangle_count, "array_bytes": array_bytes, "static_memory_delta": OS.get_static_memory_usage()-memory0, "tiles": tiles.size()}
	metrics["stages"]=timings
	_water(hydrology_plan,bounds)
	return {"is_valid": true, "reason_code": "", "metrics": metrics}

func get_route_poses() -> Dictionary:
	var data: Dictionary = _route.get_data()
	var first: Dictionary = data.pieces[0].design
	var last: Dictionary = data.pieces[-1].design
	var k: int = last.s.size()-1
	var origin := Vector3(data.header.origin_x_m,0,data.header.origin_z_m)
	return {"forward": {"position": origin+Vector3(first.x[0],first.y[0],first.z[0]),"direction": Vector3(first.tx[0],first.grade[0],first.tz[0]).normalized()}, "reverse": {"position": origin+Vector3(last.x[k],last.y[k],last.z[k]),"direction": -Vector3(last.tx[k],last.grade[k],last.tz[k]).normalized()}}

func _water(plan: RefCounted, bounds: Dictionary) -> void:
	for id in [7,20,21]:
		var channel: Dictionary = plan.get_channel(id)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		for k in range(channel.x_cm.size()):
			var a := Vector2(channel.x_cm[maxi(0,k-1)],channel.z_cm[maxi(0,k-1)])/100.0
			var b := Vector2(channel.x_cm[mini(channel.x_cm.size()-1,k+1)],channel.z_cm[mini(channel.x_cm.size()-1,k+1)])/100.0
			var n: Vector2 = (b-a).normalized().orthogonal()*channel.width_cm[k]/200.0
			var p := Vector2(channel.x_cm[k],channel.z_cm[k])/100.0
			vertices.append(Vector3(bounds.min_x+p.x+n.x,channel.surface_cm[k]/100.0,bounds.min_z+p.y+n.y))
			vertices.append(Vector3(bounds.min_x+p.x-n.x,channel.surface_cm[k]/100.0,bounds.min_z+p.y-n.y))
			if k>0:
				var q: int = 2*k
				indices.append_array([q-2,q-1,q,q-1,q+1,q])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.15,0.44,0.57,0.65)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = material
		add_child(node)
