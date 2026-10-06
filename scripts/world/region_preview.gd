extends Node3D

const Generator = preload("res://scripts/world/region/region_generator.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const TILE_SIZE: int = 512
const SPACING: int = 16
const TILE_SIDE: int = 8
const VERTEX_SIDE: int = 33
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
	var shader := Shader.new()
	shader.code = CONTOUR_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	# One shared region grid: shared tile edges read identical samples, and
	# normals are central differences of that same grid (one-sided at the
	# region boundary), so neighbouring tiles get identical edge normals.
	var side: int = TILE_SIDE * (VERTEX_SIDE - 1) + 1
	var sampled: Dictionary = Eval.sample_grid(_plan.get_macro_terrain(), 0.0, 0.0, SPACING, side, side, true)
	if not sampled.is_valid:
		_fail("ERR_PREVIEW_SAMPLE")
		return
	var grid: PackedFloat64Array = sampled.elevations_m
	var elevation_sum: float = 0.0
	for h: float in grid:
		if not is_finite(h):
			_fail("ERR_PREVIEW_SAMPLE")
			return
	_min_elevation = INF
	_max_elevation = -INF
	for h: float in grid:
		_min_elevation = minf(_min_elevation, h)
		_max_elevation = maxf(_max_elevation, h)
	material.set_shader_parameter("low_m", _min_elevation)
	material.set_shader_parameter("high_m", _max_elevation)
	for tz in range(TILE_SIDE):
		for tx in range(TILE_SIDE):
			var vertices := PackedVector3Array()
			var normals := PackedVector3Array()
			var indices := PackedInt32Array()
			for iz in range(VERTEX_SIDE):
				for ix in range(VERTEX_SIDE):
					var gx: int = tx * (VERTEX_SIDE - 1) + ix
					var gz: int = tz * (VERTEX_SIDE - 1) + iz
					var h: float = grid[gz * side + gx]
					vertices.append(Vector3(ix * SPACING, h, iz * SPACING))
					elevation_sum += h
					var x0: int = maxi(0, gx - 1)
					var x1: int = mini(side - 1, gx + 1)
					var z0: int = maxi(0, gz - 1)
					var z1: int = mini(side - 1, gz + 1)
					var dx: float = (grid[gz * side + x1] - grid[gz * side + x0]) / ((x1 - x0) * SPACING)
					var dz: float = (grid[z1 * side + gx] - grid[z0 * side + gx]) / ((z1 - z0) * SPACING)
					normals.append(Vector3(-dx, 1.0, -dz).normalized())
			for iz in range(VERTEX_SIDE - 1):
				for ix in range(VERTEX_SIDE - 1):
					var a: int = iz * VERTEX_SIDE + ix
					# Clockwise when viewed from +Y (Godot's front-face convention).
					indices.append_array([a, a + 1, a + VERTEX_SIDE, a + 1, a + VERTEX_SIDE + 1, a + VERTEX_SIDE])
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_INDEX] = indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
			var tile := MeshInstance3D.new()
			tile.name = "Tile_%d_%d" % [tx, tz]
			tile.position = Vector3(tx * TILE_SIZE, 0, tz * TILE_SIZE)
			tile.mesh = mesh
			add_child(tile)
			_tiles.append(tile)
	_mean_elevation = elevation_sum / (TILE_SIDE * TILE_SIDE * VERTEX_SIDE * VERTEX_SIDE)
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
