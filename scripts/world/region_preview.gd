extends Node3D

const Generator = preload("res://scripts/world/region/region_generator.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const Renderer = preload("res://scripts/world/region/terrain_tile_renderer.gd")
const HydroGenerator = preload("res://scripts/world/region/hydrology_generator.gd")
const HydroField = preload("res://scripts/world/region/hydrology_field.gd")
const HydroSurface = preload("res://scripts/world/region/hydrology_surface.gd")
const EnvContext = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const TILE_SIDE: int = 8
const CONTOUR_SHADER := """
shader_type spatial;
varying float height_m;
void vertex() { height_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
uniform float low_m = 0.0;
uniform float high_m = 1000.0;
void fragment() {
    float t = clamp((height_m - low_m) / max(high_m - low_m, 1.0), 0.0, 1.0);
    vec3 tint = mix(vec3(0.42, 0.47, 0.40), vec3(0.62, 0.60, 0.55), smoothstep(0.0, 0.55, t));
    tint = mix(tint, vec3(0.86, 0.86, 0.85), smoothstep(0.55, 1.0, t));
    float minor_d = abs(fract(height_m / 25.0 + 0.5) - 0.5);
    float major_d = abs(fract(height_m / 100.0 + 0.5) - 0.5);
    float minor_line = 1.0 - smoothstep(0.0, fwidth(height_m / 25.0), minor_d);
    float major_line = 1.0 - smoothstep(0.0, fwidth(height_m / 100.0), major_d);
    ALBEDO = tint * (1.0 - 0.18 * minor_line - 0.38 * major_line);
    ROUGHNESS = 1.0;
}
"""

@export var world_seed: int = 184729
@export var region_coordinate := Vector2i.ZERO
## Opt-in R3 hydrology mode (also `--hydrology`): tiles from the transitional
## HydrologySurface and simple diagnostic water meshes appended after the 64
## tiles. Off by default: the default preview is unchanged.
@export var show_hydrology: bool = false
## R4 diagnostics only. Off preserves the original material and composition.
@export var environment_mode: String = ""
var _environment: RefCounted
var _biome: RefCounted
var _rideability: RefCounted
var _plan: RefCounted
var _hydrology: RefCounted
var _focus := Vector3(2048, 0, 2048)
var _tiles: Array[MeshInstance3D] = []
var _metrics: Dictionary = {}
var _mean_elevation: float = 0.0
var _min_elevation: float = 0.0
var _max_elevation: float = 0.0
var build_error: String = ""


## Check the signed integer domain before to_int, which otherwise saturates.
static func parse_integer(text: String, bits: int) -> Dictionary:
	var grammar := RegEx.new()
	grammar.compile("^[+-]?[0-9]+$")
	if grammar.search(text) == null:
		return {"is_valid": false, "value": 0}
	var negative: bool = text.begins_with("-")
	var digits: String = text.substr(1) if text.begins_with("-") or text.begins_with("+") else text
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
	var upper: String = ("9223372036854775808" if negative else "9223372036854775807") if bits == 64 else ("2147483648" if negative else "2147483647")
	if digits.length() > upper.length() or (digits.length() == upper.length() and digits > upper):
		return {"is_valid": false, "value": 0}
	return {"is_valid": true, "value": text.to_int()}


func _fail(reason: String) -> void:
	build_error = reason
	push_error("REGION_PREVIEW_FAIL " + reason)
	get_tree().quit(1)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			var parsed: Dictionary = parse_integer(argument.substr(7), 64)
			if not parsed.is_valid:
				_fail("ERR_PREVIEW_CLI_SEED")
				return
			world_seed = parsed.value
		elif argument.begins_with("--region="):
			var parts: PackedStringArray = argument.substr(9).split(",")
			if parts.size() != 2:
				_fail("ERR_PREVIEW_CLI_REGION")
				return
			var px: Dictionary = parse_integer(parts[0], 32)
			var pz: Dictionary = parse_integer(parts[1], 32)
			if not px.is_valid or not pz.is_valid:
				_fail("ERR_PREVIEW_CLI_REGION")
				return
			region_coordinate = Vector2i(px.value, pz.value)
		elif argument == "--hydrology":
			show_hydrology = true
		elif argument.begins_with("--environment="):
			environment_mode = argument.substr(14)
			if environment_mode not in ["biome", "rideability"]:
				_fail("ERR_PREVIEW_CLI_ENVIRONMENT")
				return
	if not environment_mode.is_empty():
		show_hydrology = true
	var generation_start: int = Time.get_ticks_usec()
	_plan = Generator.build(world_seed, region_coordinate)
	if _plan == null or not _plan.validate().is_valid:
		_fail("ERR_PREVIEW_PLAN")
		return
	var generation_ms: float = (Time.get_ticks_usec() - generation_start) / 1000.0
	var build_start: int = Time.get_ticks_usec()
	var created: Dictionary = Field.create(_plan)
	if not created.is_valid:
		_fail("ERR_PREVIEW_FIELD")
		return
	var field: RefCounted = created.field
	var bounds: Dictionary = field.get_bounds_m()
	var source: RefCounted = field
	var surface: RefCounted = null
	var hydrology_ms: float = 0.0
	if show_hydrology:
		var hydrology_start: int = Time.get_ticks_usec()
		var hydrology: Dictionary = HydroGenerator.build(_plan, field)
		if not hydrology.is_valid:
			_fail("ERR_PREVIEW_HYDROLOGY " + hydrology.reason_code + " " + hydrology.detail)
			return
		_hydrology = hydrology.plan
		var hydro_field: Dictionary = HydroField.create(_hydrology, field)
		var composed: Dictionary = HydroSurface.create(field, hydro_field.field) if hydro_field.is_valid else {"is_valid": false}
		if not composed.is_valid:
			_fail("ERR_PREVIEW_HYDROLOGY surface")
			return
		surface = composed.surface
		source = surface
		hydrology_ms = (Time.get_ticks_usec() - hydrology_start) / 1000.0
	# Composition only: every tile is built independently from TerrainField
	# lattice queries, so shared edges match by construction (no shared grid).
	var built: Array = []
	for tz in range(TILE_SIDE):
		for tx in range(TILE_SIDE):
			var tile_result: Dictionary = Renderer.tile_mesh(source, bounds.min_x / Renderer.TILE_SIZE_M + tx, bounds.min_z / Renderer.TILE_SIZE_M + tz)
			if not tile_result.is_valid:
				_fail("ERR_PREVIEW_SAMPLE")
				return
			for h: float in tile_result.heights_m:
				if not is_finite(h):
					_fail("ERR_PREVIEW_SAMPLE")
					return
			built.append(tile_result)
	var elevation_sum: float = 0.0
	_min_elevation = INF
	_max_elevation = -INF
	for tile_result: Dictionary in built:
		for h: float in tile_result.heights_m:
			_min_elevation = minf(_min_elevation, h)
			_max_elevation = maxf(_max_elevation, h)
			elevation_sum += h
	var shader := Shader.new()
	shader.code = CONTOUR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("low_m", _min_elevation)
	material.set_shader_parameter("high_m", _max_elevation)
	var environmental_ms: float = 0.0
	if not environment_mode.is_empty():
		var environment_start: int = Time.get_ticks_usec()
		var context_result: Dictionary = EnvContext.create(_plan, field, _hydrology)
		if not context_result.is_valid:
			_fail(context_result.reason_code)
			return
		_environment = context_result.context
		_biome = Biome.create(_environment).field
		_rideability = Ride.create(_environment, _biome).field
		var result: Dictionary = _rideability.sample_combined_lattice(bounds.min_x / 16, bounds.min_z / 16, 257, 257)
		if not result.is_valid:
			_fail(result.reason_code)
			return
		var image := Image.create(257, 257, false, Image.FORMAT_RGB8)
		for k in range(257 * 257):
			var colour: Color
			if environment_mode == "biome":
				colour = Biome.blend_color({"is_water": bool(result.biome.is_water[k]), "weights": result.biome.weights.slice(k * 4, k * 4 + 4)})
			else:
				colour = Color(0.20, 0.70, 0.35).lerp(Color(0.92, 0.40, 0.15), clampf((result.rideability.cost[k] - 1.0) / 8.0, 0.0, 1.0)) if not result.rideability.blocked[k] else Color(0.65, 0.08, 0.18)
			image.set_pixel(k % 257, k / 257, colour)
		var environmental_shader := Shader.new()
		environmental_shader.code = """
shader_type spatial;
uniform sampler2D environment_map : source_color, filter_linear, repeat_disable;
varying vec2 region_uv;
varying float height_m;
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    region_uv = (p.xz / 4096.0 * 256.0 + 0.5) / 257.0;
    height_m = p.y;
}
void fragment() {
    vec3 tint = texture(environment_map, region_uv).rgb;
    float d = abs(fract(height_m / 100.0 + 0.5) - 0.5);
    float line = 1.0 - smoothstep(0.0, fwidth(height_m / 100.0), d);
    ALBEDO = tint * (1.0 - 0.15 * line);
    ROUGHNESS = 1.0;
}
"""
		material.shader = environmental_shader
		material.set_shader_parameter("environment_map", ImageTexture.create_from_image(image))
		environmental_ms = (Time.get_ticks_usec() - environment_start) / 1000.0
	for index in range(built.size()):
		var mesh: ArrayMesh = built[index].mesh
		mesh.surface_set_material(0, material)
		var tile := MeshInstance3D.new()
		tile.name = "Tile_%d_%d" % [index % TILE_SIDE, index / TILE_SIDE]
		# Region-local placement (world origin minus the region minimum).
		tile.position = Vector3(built[index].origin_x_m - bounds.min_x, 0, built[index].origin_z_m - bounds.min_z)
		tile.mesh = mesh
		add_child(tile)
		_tiles.append(tile)
	_mean_elevation = elevation_sum / (TILE_SIDE * TILE_SIDE * Renderer.TILE_VERTICES * Renderer.TILE_VERTICES)
	_metrics = {"generation_ms": generation_ms, "mesh_build_ms": (Time.get_ticks_usec() - build_start) / 1000.0, "tiles": _tiles.size(), "vertices": 69696, "triangles": 131072, "approximate_committed_bytes": 69696 * 24 + 64 * 6144 * 4}
	if show_hydrology:
		_add_water(surface, bounds)
		_metrics.merge({"hydrology_ms": hydrology_ms, "hydrology_signature": _hydrology.signature(), "channels": _hydrology.get_channel_count(), "water_bodies": _hydrology.get_body_count()})
	if not environment_mode.is_empty():
		_metrics.merge({"environment_mode": environment_mode, "environment_ms": environmental_ms, "environment_signature": _environment.signature(), "biome_signature": _biome.signature(), "rideability_signature": _rideability.signature(), "basis": EnvContext.SURFACE_BASIS, "sample_spacing_m": 16, "biome_descriptor": _biome.get_descriptor()})
		var legend := Label.new()
		legend.text = "R4 %s | seed %d | region %s | 4096 m; samples 16 m\n%s\nNatural barriers allow future crossing/engineering reasoning. Water ribbons show narrow geometry." % [environment_mode, world_seed, str(region_coordinate), "Conifer green / Meadow yellow / Riparian teal / Autumn orange / Water blue" if environment_mode == "biome" else "Cost: green low / orange difficult / red natural barrier (deep water or steep slope)"]
		legend.position = Vector2(15, 15)
		legend.add_theme_color_override("font_shadow_color", Color.BLACK)
		legend.add_theme_constant_override("shadow_offset_x", 2)
		legend.add_theme_constant_override("shadow_offset_y", 2)
		add_child(legend)
	set_camera_framing("oblique")
	print("REGION_PREVIEW_METRICS " + JSON.stringify(_metrics))


## Fixed diagnostic framings: "oblique" (from the south-west), "oblique_b"
## (opposite azimuth) and orthographic "top_down".
func set_camera_framing(framing: String) -> Dictionary:
	var camera: Camera3D = $Camera3D
	var light: DirectionalLight3D = $DirectionalLight3D
	# Cast shadows aid oblique depth reading; top-down relies on shading only.
	light.shadow_enabled = framing != "top_down"
	light.directional_shadow_max_distance = 12000.0
	var target := Vector3(2048, _mean_elevation, 2048)
	camera.far = 20000.0
	var azimuth_deg: float = 45.0 if framing == "oblique_b" else 225.0
	var elevation_deg: float = 90.0 if framing == "top_down" else 32.0
	var distance: float = 5600.0 if framing == "top_down" else 5200.0
	if framing == "valley_a" or framing == "valley_b":
		# Closer diagnostic framings on the river midpoint (hydrology mode).
		target = _focus
		azimuth_deg = 225.0 if framing == "valley_a" else 45.0
		elevation_deg = 30.0
		distance = 1500.0
	if framing == "pocket" and _biome != null:
		var pocket: Dictionary = _biome.get_descriptor().pocket
		if pocket.is_present:
			var macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
			var local: Vector2 = macro.frame_to_local(_environment.get_frame_symmetry(), pocket.u_m, pocket.v_m)
			target = Vector3(local.x, _mean_elevation, local.y)
			elevation_deg = 70.0
			distance = 1600.0
	if framing == "top_down":
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4096.0
		camera.position = target + Vector3(0, distance, 0)
		camera.look_at(target, Vector3.FORWARD)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 50.0
		var azimuth: float = deg_to_rad(azimuth_deg)
		var elevation: float = deg_to_rad(elevation_deg)
		camera.position = target + distance * Vector3(cos(elevation) * sin(azimuth), sin(elevation), cos(elevation) * cos(azimuth))
		camera.look_at(target)
	return {"framing": framing, "target": [target.x, target.y, target.z], "position": [camera.position.x, camera.position.y, camera.position.z], "projection": camera.projection, "fov": camera.fov, "size": camera.size, "far": camera.far, "azimuth_deg": azimuth_deg, "elevation_deg": elevation_deg, "distance_m": distance}


## Diagnostic water: the major river as a ribbon at its true water surface and
## width; tributaries and creeks as draped overlay ribbons (visual width at
## least 6 m, 2 m above the composed surface; an overlay, not geometry);
## bodies as flat lattice-cell quads at their level, clipped by the terrain.
func _add_water(surface: RefCounted, bounds: Dictionary) -> void:
	var colours: Array[Color] = [Color(0.10, 0.28, 0.55), Color(0.20, 0.45, 0.85), Color(0.45, 0.70, 0.95)]
	for index in range(_hydrology.get_channel_count()):
		var channel: Dictionary = _hydrology.get_channel(index)
		var major: bool = index == 0
		var count: int = channel.x_cm.size()
		var vertices := PackedVector3Array()
		for k in range(count):
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var a := Vector2(channel.x_cm[maxi(k - 1, 0)], channel.z_cm[maxi(k - 1, 0)]) / 100.0
			var b := Vector2(channel.x_cm[mini(k + 1, count - 1)], channel.z_cm[mini(k + 1, count - 1)]) / 100.0
			var side: Vector2 = (b - a).normalized().orthogonal()
			var half: float = channel.width_cm[k] / 200.0 if major else maxf(channel.width_cm[k] / 200.0, 3.0)
			var y: float = channel.surface_cm[k] / 100.0
			if not major:
				y = surface.sample_height(bounds.min_x + p.x, bounds.min_z + p.y).height_m + 2.0
			vertices.append(Vector3(p.x + side.x * half, y, p.y + side.y * half))
			vertices.append(Vector3(p.x - side.x * half, y, p.y - side.y * half))
		var indices := PackedInt32Array()
		for k in range(count - 1):
			indices.append_array([2 * k, 2 * k + 1, 2 * k + 2, 2 * k + 1, 2 * k + 3, 2 * k + 2])
		_add_water_mesh("Water_channel_%d" % index, vertices, indices, colours[channel.class])
		if major:
			var middle: int = count / 2
			_focus = Vector3(channel.x_cm[middle] / 100.0, channel.surface_cm[middle] / 100.0, channel.z_cm[middle] / 100.0)
	for index in range(_hydrology.get_body_count()):
		var body: Dictionary = _hydrology.get_body(index)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var level: float = body.level_cm / 100.0
		for cell: int in body.cells:
			var cx: float = (cell % 129) * 32.0
			var cz: float = (cell / 129) * 32.0
			var base: int = vertices.size()
			vertices.append_array([Vector3(cx - 16, level, cz - 16), Vector3(cx + 16, level, cz - 16), Vector3(cx - 16, level, cz + 16), Vector3(cx + 16, level, cz + 16)])
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		_add_water_mesh("Water_body_%d" % index, vertices, indices, Color(0.25, 0.60, 0.75) if body.kind == 0 else Color(0.45, 0.35, 0.70))


func _add_water_mesh(node_name: String, vertices: PackedVector3Array, indices: PackedInt32Array, colour: Color) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = colour
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)


func get_hydrology_signature() -> String:
	return _hydrology.signature() if _hydrology != null else ""


func get_plan_signature() -> String:
	return _plan.signature() if _plan != null else ""


func get_tile_count() -> int:
	return _tiles.size()


func get_tile_arrays(index: int) -> Array:
	return _tiles[index].mesh.surface_get_arrays(0).duplicate(true)


func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)

