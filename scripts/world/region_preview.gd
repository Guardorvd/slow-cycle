extends Node3D

const Generator = preload("res://scripts/world/region/region_generator.gd")
const Field = preload("res://scripts/world/region/terrain_field.gd")
const Renderer = preload("res://scripts/world/region/terrain_tile_renderer.gd")
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
var _plan: RefCounted
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
	# Composition only: every tile is built independently from TerrainField
	# lattice queries, so shared edges match by construction (no shared grid).
	var built: Array = []
	for tz in range(TILE_SIDE):
		for tx in range(TILE_SIDE):
			var tile_result: Dictionary = Renderer.tile_mesh(field, bounds.min_x / Renderer.TILE_SIZE_M + tx, bounds.min_z / Renderer.TILE_SIZE_M + tz)
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


func get_plan_signature() -> String:
	return _plan.signature() if _plan != null else ""


func get_tile_count() -> int:
	return _tiles.size()


func get_tile_arrays(index: int) -> Array:
	return _tiles[index].mesh.surface_get_arrays(0).duplicate(true)


func get_metrics() -> Dictionary:
	return _metrics.duplicate(true)
