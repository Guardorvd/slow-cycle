class_name RegionStreamer
extends Node3D

## PR1 runtime adapter of RegionBake products (main thread only). Owns the
## nodes and physics bodies of one region, region-local frame:
##   * render: every tile's FinalSurface mesh (fine, visible to RENDER_FAR_M)
##     and its coarse 16 m mesh beyond, water ribbons / lakes, bridge decks;
##   * collision: 64 m patches of the very same tile triangles (each triangle
##     in exactly one patch, partitioned by its bake layer: Road 2, RoughRoad
##     2|16, Terrain 4) within COLLISION_RADIUS_M of the bicycle, at most
##     COMMITS_PER_FRAME new patches per frame; bridge decks (top Road, body
##     Default) are always present;
##   * region boundary: walls on the four edges (Default layer) and a skirt.
## The domain products are read-only here; nothing is regenerated.

const RENDER_FAR_M: float = 1100.0
const COLLISION_RADIUS_M: float = 170.0
const COMMITS_PER_FRAME: int = 1
const PATCH_M: float = 64.0
const TILE_M: float = 512.0
const REGION_M: float = 4096.0
const WALL_HEIGHT_M: float = 40.0

var products: Dictionary = {}
var tracked: Node3D
var terrain_material: Material
var water_material: Material
var bridge_material: Material
var _tiles: Array = []
var _patch_faces: Dictionary = {}
var _active: Dictionary = {}
var _pending: Array = []
var stats: Dictionary = {"patches_built": 0, "patches_freed": 0, "max_commit_ms": 0.0}


func setup(baked: Dictionary, materials: Dictionary = {}) -> void:
	products = baked
	terrain_material = materials.get("terrain")
	water_material = materials.get("water")
	bridge_material = materials.get("bridge")
	_tiles = baked.tiles
	for k in range(_tiles.size()):
		var tile: Dictionary = _tiles[k]
		var origin := Vector3(tile.origin[0], 0.0, tile.origin[1])
		var fine := ArrayMesh.new()
		fine.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile.arrays)
		var fine_node := MeshInstance3D.new()
		fine_node.name = "Tile_%d" % k
		fine_node.mesh = fine
		fine_node.position = origin
		fine_node.material_override = terrain_material
		fine_node.visibility_range_end = RENDER_FAR_M
		fine_node.visibility_range_end_margin = 40.0
		add_child(fine_node)
		var coarse := ArrayMesh.new()
		coarse.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tile.coarse)
		var coarse_node := MeshInstance3D.new()
		coarse_node.name = "TileFar_%d" % k
		coarse_node.mesh = coarse
		coarse_node.position = origin
		coarse_node.material_override = terrain_material
		coarse_node.visibility_range_begin = RENDER_FAR_M
		coarse_node.visibility_range_begin_margin = 40.0
		coarse_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(coarse_node)
	_build_water(baked.water)
	_build_bridges(baked.bridges)
	_build_boundary()


func _build_water(water: Dictionary) -> void:
	for entry: Dictionary in water.ribbons + water.lakes:
		if entry.indices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = entry.vertices
		arrays[Mesh.ARRAY_INDEX] = entry.indices
		var normals := PackedVector3Array()
		normals.resize(entry.vertices.size())
		normals.fill(Vector3.UP)
		arrays[Mesh.ARRAY_NORMAL] = normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = water_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _build_bridges(bridges: Dictionary) -> void:
	for deck: Dictionary in bridges.decks:
		for part: String in ["top", "body", "piers"]:
			var geometry: Dictionary = deck[part]
			if geometry.indices.is_empty():
				continue
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = geometry.vertices
			arrays[Mesh.ARRAY_INDEX] = geometry.indices
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.regen_normal_maps()
			var node := MeshInstance3D.new()
			node.mesh = mesh
			node.material_override = bridge_material
			add_child(node)
		for pair: Array in [["top_faces", 2], ["body_faces", 1]]:
			var faces: PackedVector3Array = deck[pair[0]]
			if faces.is_empty():
				continue
			var body := StaticBody3D.new()
			body.collision_layer = pair[1]
			body.collision_mask = 0
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			shape.backface_collision = pair[1] == 1
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			add_child(body)


## Walls on the region edges (Default layer: the bicycle body collides) and a
## render skirt hiding the void beyond: explicit exception until R21.
func _build_boundary() -> void:
	for side in range(4):
		var body := StaticBody3D.new()
		body.name = "Boundary_%d" % side
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		var along: bool = side % 2 == 0
		shape.size = Vector3(REGION_M + 4.0 if along else 2.0, 4000.0, 2.0 if along else REGION_M + 4.0)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		var centre: Vector3
		match side:
			0: centre = Vector3(REGION_M / 2.0, 0.0, -1.0)
			1: centre = Vector3(REGION_M + 1.0, 0.0, REGION_M / 2.0)
			2: centre = Vector3(REGION_M / 2.0, 0.0, REGION_M + 1.0)
			_: centre = Vector3(-1.0, 0.0, REGION_M / 2.0)
		body.position = centre
		add_child(body)


func _physics_process(_delta: float) -> void:
	if tracked == null or _tiles.is_empty():
		return
	var p: Vector3 = tracked.global_position
	# Wanted patches: centres within the radius (patch keys: tile * 64 + patch).
	var wanted: Dictionary = {}
	var r: float = COLLISION_RADIUS_M + PATCH_M
	for k in range(_tiles.size()):
		var tile: Dictionary = _tiles[k]
		var ox: float = tile.origin[0]
		var oz: float = tile.origin[1]
		if p.x < ox - r or p.x > ox + TILE_M + r or p.z < oz - r or p.z > oz + TILE_M + r:
			continue
		for patch in range(64):
			var cx: float = ox + (patch % 8 + 0.5) * PATCH_M
			var cz: float = oz + (patch / 8 + 0.5) * PATCH_M
			if Vector2(cx - p.x, cz - p.z).length() <= COLLISION_RADIUS_M + PATCH_M * 0.71:
				wanted[k * 64 + patch] = true
	for key: int in _active.keys():
		if not wanted.has(key):
			for body: Node in _active[key]:
				body.queue_free()
			_active.erase(key)
			stats.patches_freed += 1
	var nearest: Array = wanted.keys().filter(func(key: int) -> bool: return not _active.has(key))
	nearest.sort_custom(func(a: int, b: int) -> bool: return _patch_distance(a, p) < _patch_distance(b, p))
	for q in range(mini(COMMITS_PER_FRAME, nearest.size())):
		var t0: int = Time.get_ticks_usec()
		_active[nearest[q]] = _build_patch(nearest[q])
		stats.patches_built += 1
		stats.max_commit_ms = maxf(stats.max_commit_ms, (Time.get_ticks_usec() - t0) / 1000.0)


func _patch_distance(key: int, p: Vector3) -> float:
	var tile: Dictionary = _tiles[key / 64]
	var patch: int = key % 64
	return Vector2(tile.origin[0] + (patch % 8 + 0.5) * PATCH_M - p.x, tile.origin[1] + (patch / 8 + 0.5) * PATCH_M - p.z).length()


## Synchronous build of every patch around a point (spawn / recovery), so the
## bicycle never lands before its ground exists.
func ensure_around(p: Vector3) -> void:
	var saved: Node3D = tracked
	var probe := Node3D.new()
	add_child(probe)
	probe.global_position = p
	tracked = probe
	for _pass in range(400):
		var before: int = _active.size()
		_physics_process(0.0)
		if _active.size() == before:
			break
	tracked = saved
	probe.queue_free()


func _build_patch(key: int) -> Array:
	var faces: Dictionary = _faces_for(key)
	var bodies: Array = []
	var tile: Dictionary = _tiles[key / 64]
	for layer: int in faces:
		var triangles: PackedVector3Array = faces[layer]
		if triangles.is_empty():
			continue
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		body.position = Vector3(tile.origin[0], 0.0, tile.origin[1])
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(triangles)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
		bodies.append(body)
	return bodies


const LAYERS: Array[int] = [4, 2, 2 | 16]


## Faces of one patch by layer. Triangles of a tile are counting-sorted once by
## (patch, layer); a patch then copies exactly its own triangles.
func _faces_for(key: int) -> Dictionary:
	var k: int = key / 64
	var tile: Dictionary = _tiles[k]
	if not _patch_faces.has(k):
		var layers: PackedByteArray = tile.layers
		var patches: PackedByteArray = tile.patches
		var counts := PackedInt32Array()
		counts.resize(64 * LAYERS.size() + 1)
		var bucket_of := PackedInt32Array()
		bucket_of.resize(layers.size())
		for q in range(layers.size()):
			var b: int = patches[q] * LAYERS.size() + LAYERS.find(layers[q])
			bucket_of[q] = b
			counts[b + 1] += 1
		for b in range(1, counts.size()):
			counts[b] += counts[b - 1]
		var cursor: PackedInt32Array = counts.duplicate()
		var order := PackedInt32Array()
		order.resize(layers.size())
		for q in range(layers.size()):
			order[cursor[bucket_of[q]]] = q
			cursor[bucket_of[q]] += 1
		_patch_faces[k] = {"order": order, "offsets": counts}
	var sorted: Dictionary = _patch_faces[k]
	var order: PackedInt32Array = sorted.order
	var offsets: PackedInt32Array = sorted.offsets
	var vertices: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
	var out: Dictionary = {}
	for l in range(LAYERS.size()):
		var b: int = (key % 64) * LAYERS.size() + l
		var n: int = offsets[b + 1] - offsets[b]
		if n == 0:
			continue
		var faces := PackedVector3Array()
		faces.resize(3 * n)
		for i in range(n):
			var q: int = order[offsets[b] + i]
			faces[3 * i] = vertices[indices[3 * q]]
			faces[3 * i + 1] = vertices[indices[3 * q + 1]]
			faces[3 * i + 2] = vertices[indices[3 * q + 2]]
		out[LAYERS[l]] = faces
	return out


func active_patch_count() -> int:
	return _active.size()
