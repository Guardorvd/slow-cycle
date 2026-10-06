extends SceneTree

const Generator = preload("res://scripts/world/region/region_generator.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const PREVIEW = preload("res://scenes/world/region_preview.tscn")
const OWN_CHECKS: int = 867597
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REGION_PREVIEW_TEST_FAIL " + label)


func _scan(path: String) -> void:
	var directory := DirAccess.open(path)
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var item: String = path.path_join(name)
		if directory.current_is_dir():
			if name != "region" and name != "test":
				_scan(item)
		elif (name.ends_with(".gd") or name.ends_with(".tscn")) and item != "res://scripts/world/region_preview.gd" and item != "res://scenes/world/region_preview.tscn":
			var source: String = FileAccess.get_file_as_string(item)
			_check(not "region_preview" in source and not "scripts/world/region/" in source, "production isolation " + item)
		name = directory.get_next()


func _border(preview: Node3D, a: int, b: int, vertical: bool, macro: RefCounted) -> void:
	var av: PackedVector3Array = preview.get_tile_arrays(a)[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = preview.get_tile_arrays(b)[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = preview.get_tile_arrays(a)[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = preview.get_tile_arrays(b)[Mesh.ARRAY_NORMAL]
	var ao: Vector3 = preview.get_child(a + 3).position
	var bo: Vector3 = preview.get_child(b + 3).position
	for i in range(33):
		var ia: int = 32 * 33 + i if vertical else i * 33 + 32
		var ib: int = i if vertical else i * 33
		var pa: Vector3 = av[ia] + ao
		var pb: Vector3 = bv[ib] + bo
		_check(pa == pb, "shared edge exact position")
		_check(an[ia] == bn[ib], "shared edge exact normal")
		var fresh: Dictionary = Eval.evaluate_elevation_m(macro, pa.x, pa.z)
		_check(fresh.is_valid and pa == Vector3(pa.x, fresh.elevation_m, pa.z), "shared edge fresh evaluator")


func _run() -> void:
	_check(RenderingServer.get_current_rendering_method() == "forward_plus" and DisplayServer.get_name() != "headless", "real Forward+ Vulkan runtime")
	print("REGION_PREVIEW_RENDERER method=%s display=%s adapter=%s" % [RenderingServer.get_current_rendering_method(), DisplayServer.get_name(), RenderingServer.get_video_adapter_name()])
	var independent := Generator.build(184729, Vector2i.ZERO)
	var before: String = independent.signature()
	var macro_before: String = independent.get_macro_terrain().signature()
	var preview: Node3D = PREVIEW.instantiate()
	root.add_child(preview)
	_check(preview.build_error.is_empty() and preview.get_tile_count() == 64, "64 complete tiles")
	_check(preview.get_plan_signature() == before, "independent plan identity")
	var owned: RefCounted = preview._plan
	_check(owned.get_macro_terrain().signature() == macro_before, "independent macro identity")
	var min_x: float = INF
	var min_z: float = INF
	var max_x: float = -INF
	var max_z: float = -INF
	var total_vertices: int = 0
	var total_triangles: int = 0
	for tile_index in range(64):
		var tile: MeshInstance3D = preview.get_child(tile_index + 3)
		_check(tile.position == Vector3((tile_index % 8) * 512, 0, (tile_index / 8) * 512), "tile origin")
		var arrays: Array = preview.get_tile_arrays(tile_index)
		_check(arrays == tile.mesh.surface_get_arrays(0), "ArrayMesh round trip")
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		_check(vertices.size() == 1089 and normals.size() == 1089 and indices.size() == 6144, "tile array sizes")
		total_vertices += vertices.size()
		total_triangles += indices.size() / 3
		for i in range(vertices.size()):
			var vertex: Vector3 = vertices[i]
			var region: Vector3 = vertex + tile.position
			_check(vertex.is_finite() and normals[i].is_finite() and region.x >= 0 and region.x <= 4096 and region.z >= 0 and region.z <= 4096, "finite covered vertex/normal")
			min_x = minf(min_x, region.x)
			min_z = minf(min_z, region.z)
			max_x = maxf(max_x, region.x)
			max_z = maxf(max_z, region.z)
		for index: int in indices:
			_check(index >= 0 and index < vertices.size(), "index range")
		for offset in range(0, indices.size(), 3):
			var ia: int = indices[offset]
			var ib: int = indices[offset + 1]
			var ic: int = indices[offset + 2]
			var a: Vector3 = vertices[ia]
			var b: Vector3 = vertices[ib]
			var c: Vector3 = vertices[ic]
			# Godot's clockwise front normal is the reverse of the cross product.
			var face: Vector3 = (c - a).cross(b - a)
			_check(absf(face.y) / 2.0 == 128.0, "non-degenerate exact XZ area")
			_check(face.y > 0.0, "clockwise front from +Y")
			_check(face.dot(normals[ia]) > 0 and face.dot(normals[ib]) > 0 and face.dot(normals[ic]) > 0, "normal agrees with face")
		arrays[Mesh.ARRAY_VERTEX][0] = Vector3.INF
		_check(preview.get_tile_arrays(tile_index)[Mesh.ARRAY_VERTEX][0].is_finite(), "getter array copy")
	_check(total_vertices == 69696 and total_triangles == 131072, "total topology")
	_check(min_x == 0 and min_z == 0 and max_x == 4096 and max_z == 4096, "exact region coverage")
	for z in range(8):
		for x in range(8):
			var index: int = z * 8 + x
			if x < 7:
				_border(preview, index, index + 1, false, independent.get_macro_terrain())
			if z < 7:
				_border(preview, index, index + 8, true, independent.get_macro_terrain())
	# Interior vertices come from the shared grid; each equals a fresh
	# evaluator sample (the evaluator stays the only terrain model).
	for k in range(64):
		var tile_index: int = (k * 37) % 64
		var vertex_index: int = (k * 113) % 1089
		var region: Vector3 = preview.get_tile_arrays(tile_index)[Mesh.ARRAY_VERTEX][vertex_index] + preview.get_child(tile_index + 3).position
		var fresh: Dictionary = Eval.evaluate_elevation_m(independent.get_macro_terrain(), region.x, region.z)
		_check(fresh.is_valid and region == Vector3(region.x, fresh.elevation_m, region.z), "interior vertex equals fresh evaluator sample")
	for framing: String in ["oblique", "oblique_b", "top_down"]:
		var camera: Dictionary = preview.set_camera_framing(framing)
		_check(camera.framing == framing and camera.projection == (Camera3D.PROJECTION_ORTHOGONAL if framing == "top_down" else Camera3D.PROJECTION_PERSPECTIVE), "camera framing " + framing)
		_check(preview.get_node("DirectionalLight3D").shadow_enabled == (framing != "top_down"), "framing shadows " + framing)
	var preview_source: String = FileAccess.get_file_as_string("res://scripts/world/region_preview.gd")
	for token: String in ["get_data", "macro_geography_generator", "MacroGeographyGenerator", "valley_points", "main_nodes"]:
		_check(not token in preview_source, "preview is presentation only: no " + token)
	_check(owned.signature() == before and owned.get_macro_terrain().signature() == macro_before, "preview preserves owned identity")
	_check(independent.signature() == before and independent.get_macro_terrain().signature() == macro_before, "preview preserves independent identity")
	var metrics: Dictionary = preview.get_metrics()
	metrics.tiles = -1
	_check(preview.get_metrics().tiles == 64, "metrics copy")
	_scan("res://scripts")
	_scan("res://scenes")
	var project: String = FileAccess.get_file_as_string("res://project.godot")
	_check(not "region_preview" in project and not "scripts/world/region/" in project, "project isolation")
	_check(checks + 1 == OWN_CHECKS, "fixed own check count %d" % (checks + 1))
	print("REGION_PREVIEW_TEST_SUMMARY checks=%d failures=%d" % [checks, failures])
	preview.queue_free()
	await process_frame
	quit(1 if failures else 0)
