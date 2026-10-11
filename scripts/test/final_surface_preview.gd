extends Node3D
const Source = preload("res://scripts/test/final_surface_route_source.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Slice = preload("res://scripts/world/final_surface_slice.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
var slice: Node3D
var source: Dictionary
var camera: Camera3D
var _capture := ""
var _diagnostic_fords := false
var _dry_prototype := false
var _views: Array[String] = ["overview","forward","reverse","ford1","ford2","ford3","junction3","junction4","cut","fill","join_wireframe"]

func _ready() -> void:
	RenderingServer.set_debug_generate_wireframes(true)
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--diagnostic-fords":
			_diagnostic_fords = true
		if arg == "--dry-prototype":
			_dry_prototype = true
		if arg.begins_with("--capture="):
			_capture = arg.substr(10)
	call_deferred("_build")

func _build() -> void:
	source = Source.build()
	if not source.is_valid:
		_fail(source.reason_code)
		return
	if _diagnostic_fords:
		_ford_diagnostics()
		_views = ["ford1","ford2","ford3"]
		print("R7_DIAGNOSTIC_SCENE rejected ford requirements; no collision / no surface acceptance")
	else:
		var deformer: Dictionary = Deformer.create(source.route,source.field)
		if not deformer.is_valid:
			_fail(deformer.reason_code)
			return
		var surface: RefCounted = Surface.create(source.terrain,source.field,deformer.deformer).surface
		if _dry_prototype:
			var result: Dictionary = _build_dry_prototype(surface)
			if not result.is_valid:
				_fail(result.reason_code)
				return
			_views = ["reverse"]
			print("R7_DRY_PROTOTYPE ",JSON.stringify(result)," limited 64 m diagnostic coverage")
		else:
			slice = Slice.new()
			add_child(slice)
			var result: Dictionary = slice.build(surface,source.hydrology,source.route)
			if not result.is_valid:
				_fail(result.reason_code)
				return
			print("R7_VISIBLE_SCENE ",JSON.stringify(slice.metrics)," upstream_ms=",source.upstream_ms)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-35,0)
	light.light_energy = 1.4
	add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.52,0.69,0.80)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7,0.8,0.9)
	environment.environment.ambient_light_energy = 0.5
	add_child(environment)
	camera = Camera3D.new()
	camera.far = 4000
	add_child(camera)
	set_view("ford2" if _diagnostic_fords else ("reverse" if _dry_prototype else "overview"))
	var label := Label.new()
	label.text = "R7 FinalSurface — 1118.5 m / 3 fords / layers 2 + 4\n1 overview · 2 forward · 3 reverse · 4–6 fords · 7–8 connectors"
	if _diagnostic_fords:
		label.text = "R7 REJECTED FORD REQUIREMENTS — diagnostic, no collision\nGreen: real natural channel · blue: actual water · red: unchanged R6 plane (x-ray)\nKeys 1–3: channels 7 / 20 / 21"
	elif _dry_prototype:
		label.text = "R7 DRY ROAD PROTOTYPE — real FinalSurface / matching collision\nLimited 64 m diagnostic view."
	label.position = Vector2(16,16)
	add_child(label)
	if not _capture.is_empty():
		DirAccess.make_dir_recursive_absolute(_capture)
		for view: String in _views:
			set_view(view)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			await get_tree().create_timer(0.3).timeout
			var image: Image = get_viewport().get_texture().get_image()
			var path: String=_capture.path_join(view+".png")
			if image.save_png(path)!=OK:
				_fail("Capture save failed: "+path)
				return
			var saved: Image=Image.load_from_file(path)
			if saved.is_empty() or saved.get_size()!=image.get_size():
				_fail("Capture reload failed: "+path)
				return
			print("R7_CAPTURE ",JSON.stringify({"view":view,"path":path,"width":saved.get_width(),"height":saved.get_height(),"camera_position":[camera.position.x,camera.position.y,camera.position.z],"route_digest":source.route.route_digest(),"dependency_key":source.key,"png_sha256":Source.Route.sha(FileAccess.get_file_as_bytes(path)),"seed":184729,"region":[0,0],"diagnostic":_diagnostic_fords or _dry_prototype}))
		get_tree().quit()

func _fail(reason: String) -> void:
	push_error("R7_PREVIEW_FAIL "+reason)
	get_tree().quit(1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode>=KEY_1 and event.keycode<KEY_1+_views.size() and camera!=null:
		set_view(_views[event.keycode-KEY_1])

func set_view(view: String) -> void:
	get_viewport().debug_draw=Viewport.DEBUG_DRAW_WIREFRAME if view=="join_wireframe" else Viewport.DEBUG_DRAW_DISABLED
	var data: Dictionary = source.route.get_data()
	var d: Dictionary = data.pieces[0].design
	var k: int = d.s.size()/2
	if view == "reverse":
		d = data.pieces[-1].design
		k = d.s.size()/2
	elif view.begins_with("junction"):
		d = data.pieces[1 if view == "junction3" else 3].design
		k = d.s.size()/2
	elif view.begins_with("ford"):
		var c: Dictionary = data.crossings[int(view.trim_prefix("ford"))-1]
		k = 0
		for i in range(d.s.size()):
			if absf(d.s[i]-c.s_m)<absf(d.s[k]-c.s_m):
				k=i
	elif view in ["cut","fill"]:
		var extreme: float=-INF
		for piece: Dictionary in data.pieces:
			var candidate: Dictionary=piece.design
			for i in range(candidate.s.size()):
				var natural: float=source.natural.sample_height(candidate.x[i],candidate.z[i]).height_m
				var delta: float=candidate.y[i]-natural
				var score: float=-delta if view=="cut" else delta
				if score>extreme:
					extreme=score
					d=candidate
					k=i
	elif view=="join_wireframe":
		for i in range(d.s.size()):
			if absf(d.x[i]-3072)<absf(d.x[k]-3072): k=i
	var target := Vector3(data.header.origin_x_m+d.x[k],d.y[k],data.header.origin_z_m+d.z[k])
	var tangent := Vector3(d.tx[k],0,d.tz[k])
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	if view == "overview":
		var first: Dictionary = data.pieces[0].design
		var last: Dictionary = data.pieces[-1].design
		target = Vector3((first.x[0]+last.x[-1])/2,(first.y[0]+last.y[-1])/2,(first.z[0]+last.z[-1])/2)
		camera.position = target+Vector3(320,800,470)
	elif view == "forward" or view == "reverse":
		var direction: float = -1.0 if view == "reverse" else 1.0
		camera.position = target - tangent*direction*18.0 + Vector3(0,7,0)
		target += tangent*direction*30.0
	else:
		camera.position = target-tangent*20.0+Vector3(12,20,12)
	camera.look_at(target,Vector3.UP)

## Explicitly requested diagnostic view, never a fallback FinalSurface.
## Fine actual channel geometry plus unchanged R6 plane makes the rejected
## requirement inspectable without constructing invalid terrain/collision.
func _ford_diagnostics() -> void:
	var data: Dictionary = source.route.get_data()
	var d: Dictionary = data.pieces[0].design
	for crossing: Dictionary in data.crossings:
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var indices := PackedInt32Array()
		var x0: float = floor(crossing.r6_x)-16
		var z0: float = floor(crossing.r6_z)-16
		for j in range(129):
			for i in range(129):
				var x: float = x0+i*0.25
				var z: float = z0+j*0.25
				vertices.append(Vector3(x,source.natural.sample_height(x,z).height_m,z))
				normals.append(source.natural.sample_normal(x,z).normal)
		for j in range(128):
			for i in range(128):
				var a: int = j*129+i
				indices.append_array([a,a+1,a+129,a+1,a+130,a+129])
		_diagnostic_mesh(vertices,normals,indices,Color(0.27,0.38,0.23,1))
		var road := PackedVector3Array()
		var road_indices := PackedInt32Array()
		for k in range(d.s.size()):
			if absf(d.s[k]-crossing.s_m)>20:
				continue
			var q: int = road.size()
			for side: float in [-1.0,1.0]:
				var lateral: float = side*(d.width[k]/2.0+0.75)
				road.append(Vector3(d.x[k]-d.tz[k]*lateral,d.y[k]-lateral*tan(deg_to_rad(d.bank[k])),d.z[k]+d.tx[k]*lateral))
			if q>0:
				road_indices.append_array([q-2,q-1,q,q-1,q+1,q])
		_diagnostic_mesh(road,PackedVector3Array(),road_indices,Color(0.85,0.18,0.10,0.65))
		# Render only the local channel portion, preserving its true width/level.
		var channel: Dictionary = source.hydrology.get_channel(crossing.channel_id)
		var water_vertices := PackedVector3Array()
		var water_indices := PackedInt32Array()
		for k in range(channel.x_cm.size()):
			if absf(channel.x_cm[k]/100.0-crossing.r6_x)>60 or absf(channel.z_cm[k]/100.0-crossing.r6_z)>60:
				continue
			var a := Vector2(channel.x_cm[maxi(k-1,0)],channel.z_cm[maxi(k-1,0)])/100.0
			var b := Vector2(channel.x_cm[mini(k+1,channel.x_cm.size()-1)],channel.z_cm[mini(k+1,channel.x_cm.size()-1)])/100.0
			var n: Vector2 = (b-a).normalized().orthogonal()*channel.width_cm[k]/200.0
			var p := Vector2(channel.x_cm[k],channel.z_cm[k])/100.0
			var q: int = water_vertices.size()
			for side: float in [-1.0,1.0]:
				water_vertices.append(Vector3(p.x+side*n.x,channel.surface_cm[k]/100.0,p.y+side*n.y))
			if q>0:
				water_indices.append_array([q-2,q-1,q,q-1,q+1,q])
		_diagnostic_mesh(water_vertices,PackedVector3Array(),water_indices,Color(0.05,0.4,0.85,0.8))

func _diagnostic_mesh(vertices: PackedVector3Array,normals: PackedVector3Array,indices: PackedInt32Array,colour: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	if not normals.is_empty():
		arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if colour.a<1:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if colour.r>0.8:
			material.no_depth_test = true
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)

func _build_dry_prototype(surface: RefCounted) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var memory0: int = OS.get_static_memory_usage()
	var data: Dictionary = source.route.get_data()
	var d: Dictionary = data.pieces[-1].design
	var k: int = d.s.size()/2
	var x0: float = floor(d.x[k])-32
	var z0: float = floor(d.z[k])-32
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in range(129):
		for i in range(129):
			var x: float = x0+i*0.5
			var z: float = z0+j*0.5
			var h: Dictionary = surface.sample_surface(x,z)
			if not h.is_valid:
				return h
			vertices.append(Vector3(i*0.5,h.height_m,j*0.5))
			normals.append(surface.sample_normal(x,z).normal)
			uv.append(Vector2(h.lateral,h.half_width) if h.kind=="ROAD" else Vector2(100,0))
	for j in range(128):
		for i in range(128):
			var a: int = j*129+i
			indices.append_array([a,a+1,a+129,a+1,a+130,a+129])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var tile: Dictionary = {"is_valid":true,"arrays":arrays,"origin_x_m":x0,"origin_z_m":z0,"vertex_count":vertices.size(),"triangle_count":indices.size()/3,"array_bytes":vertices.size()*32+indices.size()*4}
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	tile["mesh"] = array_mesh
	var faces: Dictionary = Renderer.tile_collision_faces(surface,tile)
	if not faces.is_valid:
		return faces
	var shader := Shader.new()
	shader.code = Slice.SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	var mesh := MeshInstance3D.new()
	mesh.mesh = tile.mesh
	mesh.material_override = material
	mesh.position = Vector3(tile.origin_x_m,0,tile.origin_z_m)
	add_child(mesh)
	for layer: int in [2,4]:
		var triangles: PackedVector3Array = faces.road if layer == 2 else faces.terrain
		if triangles.is_empty():
			continue
		var body := StaticBody3D.new()
		body.position = mesh.position
		body.collision_layer = layer
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(triangles)
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	return {"is_valid":true,"reason_code":"","extent_m":64,"vertices":tile.vertex_count,"triangles":tile.triangle_count,"array_bytes":tile.array_bytes,"static_memory_delta":OS.get_static_memory_usage()-memory0,"build_ms":(Time.get_ticks_usec()-t0)/1000.0}
