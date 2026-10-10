extends Node3D

## Isolated R6 diagnostic preview (ExecPlan §10, E3/E5 evidence only; not the
## main game, no BicycleController, no collision). Real R1-R5 upstream and a
## real RoadSynthesizer run; renders over the UNCHANGED natural surface:
##   * terrain tiles from the R3 HydrologySurface (contour shader) and water;
##   * every exported R6 piece as a ribbon at its designed height (class
##     colour; bridge decks blue, fords cyan, junction connectors white), plus
##     a translucent copy drawn without depth test so cut sections hidden by
##     the natural ground stay visible (intent over unchanged terrain);
##   * earthwork intent faces from each shoulder edge to its daylight point on
##     the natural surface (cut orange, fill green), translucent;
##   * failed edges: their R5 reference line as a red ribbon; crossing and
##     junction posts.
## Presentation only: the synthesizer owns every decision; nothing here is a
## height authority or a terrain deformation.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Renderer = preload("res://scripts/world/region/terrain_tile_renderer.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const CLASS_COLOURS: Array[Color] = [Color(1.0, 0.85, 0.15), Color(1.0, 0.5, 0.05), Color(0.9, 0.2, 0.85), Color(0.9, 0.1, 0.1)]
const CONTOUR_SHADER := """
shader_type spatial;
varying float height_m;
void vertex() { height_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
uniform float low_m = 0.0;
uniform float high_m = 1000.0;
void fragment() {
    float t = clamp((height_m - low_m) / max(high_m - low_m, 1.0), 0.0, 1.0);
    vec3 tint = mix(vec3(0.40, 0.48, 0.36), vec3(0.62, 0.60, 0.52), smoothstep(0.0, 0.6, t));
    tint = mix(tint, vec3(0.86, 0.86, 0.84), smoothstep(0.6, 1.0, t));
    float minor_d = abs(fract(height_m / 5.0 + 0.5) - 0.5);
    float major_d = abs(fract(height_m / 25.0 + 0.5) - 0.5);
    float minor_line = 1.0 - smoothstep(0.0, fwidth(height_m / 5.0), minor_d);
    float major_line = 1.0 - smoothstep(0.0, fwidth(height_m / 25.0), major_d);
    ALBEDO = tint * (1.0 - 0.10 * minor_line - 0.30 * major_line);
    ROUGHNESS = 1.0;
}
"""

@export var world_seed: int = 184729
@export var region_coordinate := Vector2i.ZERO
var build_error: String = ""
var plan: RefCounted
var graph: RefCounted
var surface: RefCounted
var _metrics: Dictionary = {}
var _mean_elevation: float = 0.0


func _ready() -> void:
	var t0: int = Time.get_ticks_usec()
	var region_plan: RefCounted = Gen.build(world_seed, region_coordinate)
	if region_plan == null:
		_fail("ERR_R6_PREVIEW_PLAN")
		return
	var terrain: RefCounted = Terrain.create(region_plan).field
	var hydrology: Dictionary = HGen.build(region_plan, terrain)
	var routes: Dictionary = Planner.plan(region_plan, terrain, hydrology.plan)
	if not routes.is_valid:
		_fail("ERR_R6_PREVIEW_ROUTES " + routes.reason_code)
		return
	graph = routes.graph
	var t1: int = Time.get_ticks_usec()
	var result: Dictionary = Synth.synthesize(region_plan, terrain, hydrology.plan, graph)
	var t2: int = Time.get_ticks_usec()
	if result.plan == null:
		_fail("ERR_R6_PREVIEW_SYNTHESIS " + result.reason_code)
		return
	plan = result.plan
	surface = Surface.create(terrain, HField.create(hydrology.plan, terrain).field).surface
	var bounds: Dictionary = surface.get_bounds_m()
	_build_terrain(bounds)
	_build_water(hydrology.plan, bounds)
	var pieces: int = _build_roads()
	_build_failed_and_posts()
	_legend(result.status)
	_metrics = {"upstream_and_r5_ms": (t1 - t0) / 1000.0, "r6_ms": (t2 - t1) / 1000.0, "scene_build_ms": (Time.get_ticks_usec() - t2) / 1000.0, "pieces": pieces,
		"plan_signature": plan.signature(), "graph_signature": graph.signature(), "status": result.status}
	set_camera_framing("overview")


func _fail(reason: String) -> void:
	build_error = reason
	push_error("R6_PREVIEW_FAIL " + reason)


func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)


func _build_terrain(bounds: Dictionary) -> void:
	var low: float = INF
	var high: float = -INF
	var sum: float = 0.0
	var count: int = 0
	var built: Array = []
	for tz in range(8):
		for tx in range(8):
			var tile: Dictionary = Renderer.tile_mesh(surface, bounds.min_x / Renderer.TILE_SIZE_M + tx, bounds.min_z / Renderer.TILE_SIZE_M + tz)
			built.append(tile)
			for h: float in tile.heights_m:
				low = minf(low, h)
				high = maxf(high, h)
				sum += h
				count += 1
	_mean_elevation = sum / maxf(count, 1)
	var shader := Shader.new()
	shader.code = CONTOUR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("low_m", low)
	material.set_shader_parameter("high_m", high)
	for tile: Dictionary in built:
		var mesh: ArrayMesh = tile.mesh
		mesh.surface_set_material(0, material)
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(tile.origin_x_m - bounds.min_x, 0, tile.origin_z_m - bounds.min_z)
		add_child(instance)


func _build_water(hydrology: RefCounted, bounds: Dictionary) -> void:
	for c in range(hydrology.get_channel_count()):
		var channel: Dictionary = hydrology.get_channel(c)
		var vertices := PackedVector3Array()
		var n: int = channel.x_cm.size()
		for k in range(n):
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var a := Vector2(channel.x_cm[maxi(k - 1, 0)], channel.z_cm[maxi(k - 1, 0)]) / 100.0
			var b := Vector2(channel.x_cm[mini(k + 1, n - 1)], channel.z_cm[mini(k + 1, n - 1)]) / 100.0
			var side: Vector2 = (b - a).normalized().orthogonal()
			var half: float = channel.width_cm[k] / 200.0
			var y: float = channel.surface_cm[k] / 100.0
			vertices.append(Vector3(p.x + side.x * half, y, p.y + side.y * half))
			vertices.append(Vector3(p.x - side.x * half, y, p.y - side.y * half))
		_strip("Water_%d" % c, vertices, Color(0.2, 0.42, 0.85), true, false)
	for b in range(hydrology.get_body_count()):
		var body: Dictionary = hydrology.get_body(b)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var level: float = body.level_cm / 100.0
		for cell: int in body.cells:
			var cx: float = (cell % 129) * 32.0
			var cz: float = (cell / 129) * 32.0
			var base: int = vertices.size()
			vertices.append_array([Vector3(cx - 16, level, cz - 16), Vector3(cx + 16, level, cz - 16), Vector3(cx - 16, level, cz + 16), Vector3(cx + 16, level, cz + 16)])
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		_mesh("Body_%d" % b, vertices, indices, Color(0.25, 0.55, 0.75), true, false)


func _build_roads() -> int:
	var count: int = 0
	for piece_id: String in plan.get_piece_ids():
		var info: Dictionary = plan.get_piece_info(piece_id)
		var envelope: Dictionary = plan.get_path(piece_id)
		var path: RefCounted = envelope.path
		var design: Dictionary = plan.get_design(piece_id)
		var connector: bool = info.kind == "MOVEMENT"
		var base: Color = Color(0.95, 0.95, 0.95) if connector else CLASS_COLOURS[info.route_class]
		var shoulder: float = 0.0 if connector else Policy.CLASSES[info.route_class].shoulder_m
		var ribbon := PackedVector3Array()
		var colours := PackedColorArray()
		var faces_cut := PackedVector3Array()
		var faces_fill := PackedVector3Array()
		var bounds: Dictionary = surface.get_bounds_m()
		for i in range(path.points.size()):
			var p: Vector3 = path.points[i] + Vector3(0, 0.06, 0)
			var side: Vector3 = path.binormals[i] * (0.5 * path.road_widths[i])
			ribbon.append(p - side)
			ribbon.append(p + side)
			var c: Color = base
			if design.support[i] == Policy.Support.BRIDGE_DECK:
				c = Color(0.35, 0.6, 1.0)
			elif design.support[i] == Policy.Support.FORD:
				c = Color(0.5, 0.95, 1.0)
			colours.append(c)
			colours.append(c)
			if i % 2 == 0 and design.support[i] == Policy.Support.EARTHWORK and not connector:
				# Earthwork faces: shoulder edge (road height) to daylight point.
				var horizontal := Vector3(-design.tz[i], 0.0, design.tx[i])
				for sgn: float in [1.0, -1.0]:
					var tie: float = design.tie_l[i] if sgn > 0.0 else design.tie_r[i]
					var delta: float = design.fill_l[i] if sgn > 0.0 else design.fill_r[i]
					if tie < 0.05:
						continue
					var half: float = 0.5 * design.width[i] + shoulder
					var edge: Vector3 = Vector3(design.x[i], design.y[i], design.z[i]) + horizontal * sgn * half
					var outer: Vector3 = Vector3(design.x[i], 0.0, design.z[i]) + horizontal * sgn * (half + tie)
					outer.y = surface.sample_height(bounds.min_x + clampf(outer.x, 0.0, 4096.0), bounds.min_z + clampf(outer.z, 0.0, 4096.0)).height_m
					var target: PackedVector3Array = faces_cut if delta < 0.0 else faces_fill
					target.append(edge)
					target.append(outer)
		_strip_coloured(piece_id, ribbon, colours, false)
		var overlay := PackedColorArray()
		for c: Color in colours:
			overlay.append(Color(c.r, c.g, c.b, 0.35))
		_strip_coloured(piece_id + "_xray", ribbon, overlay, true)
		_lines(piece_id + "_cut", faces_cut, Color(0.95, 0.55, 0.15, 0.6))
		_lines(piece_id + "_fill", faces_fill, Color(0.35, 0.85, 0.35, 0.6))
		count += 1
	return count


func _build_failed_and_posts() -> void:
	var ox: float = graph.get_origin_x_m()
	var oz: float = graph.get_origin_z_m()
	var data: Dictionary = plan.get_data()
	for record: Dictionary in data.edges:
		if record.status == "READY":
			continue
		var corridor: Dictionary = graph.get_corridor(record.edge_id)
		var vertices := PackedVector3Array()
		var n: int = corridor.station_count
		for k in range(n):
			var p := Vector2(corridor.x_m[k] - ox, corridor.z_m[k] - oz)
			var a := Vector2(corridor.x_m[maxi(k - 1, 0)] - ox, corridor.z_m[maxi(k - 1, 0)] - oz)
			var b := Vector2(corridor.x_m[mini(k + 1, n - 1)] - ox, corridor.z_m[mini(k + 1, n - 1)] - oz)
			var side: Vector2 = (b - a).normalized().orthogonal() * 2.0
			var y: float = corridor.elevation_m[k] + 1.5
			vertices.append(Vector3(p.x + side.x, y, p.y + side.y))
			vertices.append(Vector3(p.x - side.x, y, p.y - side.y))
		_strip("Failed_%d" % record.edge_id, vertices, Color(0.95, 0.05, 0.05, 0.85), false, true)
	for c: Dictionary in data.crossings:
		var p := Vector3(c.r5_x_cm / 100.0, 0, c.r5_z_cm / 100.0)
		p.y = surface.sample_height(graph.get_origin_x_m() + p.x, graph.get_origin_z_m() + p.z).height_m
		_post(p, 18.0, Color(0.1, 0.3, 1.0) if c.status == "RESOLVED" else Color(1, 0, 0))
	for j: Dictionary in data.junctions:
		var p := Vector3(j.x, j.patch.get("y0", 0.0), j.z)
		_post(p, 25.0, Color(0.1, 0.9, 0.2) if j.status == Policy.JUNCTION_READY else (Color(1.0, 0.8, 0.1) if j.status == Policy.JUNCTION_USABLE else Color(1, 0.1, 0.1)))


func _legend(status: String) -> void:
	var label := Label.new()
	label.text = "R6 road synthesis | seed %d region %s | %s | ribbons at designed height over UNCHANGED natural terrain (intent, not built surface)\nBackbone yellow / Secondary orange / Singletrack magenta / Technical red / connectors white / deck blue / ford cyan | earthwork faces: cut orange, fill green | failed edge: R5 line red" % [world_seed, str(region_coordinate), status]
	label.position = Vector2(12, 12)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)


## Framings: "overview", "top_down"; or piece views via frame_piece().
func set_camera_framing(framing: String) -> Dictionary:
	var camera: Camera3D = $Camera3D
	var light: DirectionalLight3D = $DirectionalLight3D
	light.shadow_enabled = framing != "top_down"
	light.directional_shadow_max_distance = 6000.0
	camera.far = 20000.0
	var target := Vector3(2048, _mean_elevation, 2048)
	if framing == "top_down":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4096.0
		camera.position = target + Vector3(0, 5000, 0)
		camera.look_at(target, Vector3.FORWARD)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 50.0
		camera.position = target + 4800.0 * Vector3(cos(deg_to_rad(35.0)) * sin(deg_to_rad(205.0)), sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0)) * cos(deg_to_rad(205.0)))
		camera.look_at(target)
	return {"framing": framing, "position": [camera.position.x, camera.position.y, camera.position.z], "target": [target.x, target.y, target.z], "projection": camera.projection}


## Piece views: "oblique" (terrain-aware: 300 m away, 32 deg above, from the
## lower side of the piece) or "near" (1.6 m above the road at fraction f of
## the piece, looking 35 m ahead along it).
func frame_piece(piece_id: String, mode: String, fraction: float = 0.5) -> Dictionary:
	var camera: Camera3D = $Camera3D
	var light: DirectionalLight3D = $DirectionalLight3D
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 1500.0
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var path: RefCounted = plan.get_path(piece_id).path
	var n: int = path.points.size()
	var total: float = path.cumulative_distances[n - 1]
	var i: int = clampi(path.cumulative_distances.bsearch(total * fraction), 0, n - 1)
	if mode == "near":
		camera.fov = 70.0
		camera.far = 5000.0
		var eye: Vector3 = path.points[i] + path.normals[i] * 1.6
		var j: int = clampi(path.cumulative_distances.bsearch(path.cumulative_distances[i] + 35.0), 0, n - 1)
		var look: Vector3 = path.points[j] + Vector3(0, 1.0, 0)
		if look.distance_to(eye) < 1.0:
			look = eye + path.tangents[i] * 30.0
		camera.position = eye
		camera.look_at(look)
	else:
		camera.fov = 45.0
		camera.far = 12000.0
		var lo := Vector3(INF, INF, INF)
		var hi := Vector3(-INF, -INF, -INF)
		for k in range(n):
			lo = lo.min(path.points[k])
			hi = hi.max(path.points[k])
		var centre: Vector3 = 0.5 * (lo + hi)
		var extent: float = clampf((hi - lo).length(), 90.0, 700.0)
		var tangent: Vector3 = (path.points[n - 1] - path.points[0]).normalized()
		var side := Vector3(-tangent.z, 0, tangent.x)
		var gradient: Dictionary = surface.sample_gradient(graph.get_origin_x_m() + clampf(centre.x, 0, 4096), graph.get_origin_z_m() + clampf(centre.z, 0, 4096))
		# Look from the downhill side so the hillside behind stays in view.
		if side.dot(Vector3(gradient.gradient.x, 0, gradient.gradient.y)) > 0.0:
			side = -side
		var distance: float = extent * 0.75
		camera.position = centre + side * distance * cos(deg_to_rad(32.0)) + Vector3(0, distance * sin(deg_to_rad(32.0)), 0)
		camera.look_at(centre)
	return {"piece": piece_id, "mode": mode, "fraction": fraction, "position": [camera.position.x, camera.position.y, camera.position.z], "fov": camera.fov}


func _strip(node_name: String, vertices: PackedVector3Array, colour: Color, unshaded: bool, xray: bool) -> void:
	var colours := PackedColorArray()
	for v in vertices:
		colours.append(colour)
	_strip_coloured(node_name, vertices, colours, xray, unshaded)


func _strip_coloured(node_name: String, vertices: PackedVector3Array, colours: PackedColorArray, xray: bool, unshaded: bool = true) -> void:
	var indices := PackedInt32Array()
	for k in range(vertices.size() / 2 - 1):
		indices.append_array([2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 1, 2 * k + 3, 2 * k + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	_add(node_name, arrays, Mesh.PRIMITIVE_TRIANGLES, colours.size() > 0 and colours[0].a < 1.0, xray, unshaded)


func _mesh(node_name: String, vertices: PackedVector3Array, indices: PackedInt32Array, colour: Color, unshaded: bool, xray: bool) -> void:
	var colours := PackedColorArray()
	for v in vertices:
		colours.append(colour)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	_add(node_name, arrays, Mesh.PRIMITIVE_TRIANGLES, colour.a < 1.0, xray, unshaded)


func _lines(node_name: String, vertices: PackedVector3Array, colour: Color) -> void:
	if vertices.is_empty():
		return
	var colours := PackedColorArray()
	for v in vertices:
		colours.append(colour)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colours
	_add(node_name, arrays, Mesh.PRIMITIVE_LINES, true, false, true)


func _post(base: Vector3, height: float, colour: Color) -> void:
	var vertices := PackedVector3Array([base + Vector3(-1.5, 0, 0), base + Vector3(1.5, 0, 0), base + Vector3(-1.5, height, 0), base + Vector3(1.5, height, 0),
		base + Vector3(0, 0, -1.5), base + Vector3(0, 0, 1.5), base + Vector3(0, height, -1.5), base + Vector3(0, height, 1.5)])
	_mesh("Post", vertices, PackedInt32Array([0, 1, 2, 1, 3, 2, 4, 5, 6, 5, 7, 6]), colour, true, false)


func _add(node_name: String, arrays: Array, primitive: int, transparent: bool, xray: bool, unshaded: bool) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent or xray:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if xray:
		material.no_depth_test = true
		material.render_priority = 1
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name.replace(":", "_")
	instance.mesh = mesh
	add_child(instance)
