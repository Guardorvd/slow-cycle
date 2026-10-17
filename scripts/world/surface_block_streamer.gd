extends Node3D
## GEN2-S S2: runtime adapter of SurfaceBlocks (dev prototype; the region
## runtime keeps RegionStreamer). Reads block data only and registers render
## and collision nodes on the main thread.
##
## Render: one mesh per block from its height grid (the bake's terrain shader,
## uv convention of FinalSurfaceTileRenderer), cells split along the
## (i + 1, j) - (i, j + 1) diagonal, the same split HeightMapShape3D uses.
## Collision without changing how the bicycle reads its ground (collision
## layer of the collider under a wheel):
##   ground   one HeightMapShape3D per block on the terrain layer;
##   strips   cells whose corners are mostly road / trail become a
##            ConcavePolygonShape3D on that cover's layer (road 2, rough
##            2 | 16), built from the same four heights and split, so the
##            strip is the ground there; heightfield vertices with only strip
##            cells around them are sunk SINK_M below so the strip is the only
##            surface a wheel meets inside it. Strip edges are cell edges,
##            shared exactly with the heightfield's.

const Ops = preload("res://scripts/world/surface/surface_ops.gd")
const Block = preload("res://scripts/world/surface/surface_block.gd")

const SINK_M: float = 0.3

var terrain_material: Material
var stats: Dictionary = {}


## `blocks`: SurfaceBlock.build results; `offset`: world -> scene (region
## min corner, subtracted).
func setup(blocks: Array, offset: Vector2, material: Material) -> void:
	terrain_material = material
	var t0: int = Time.get_ticks_usec()
	var by_id: Dictionary = {}
	for b: Dictionary in blocks:
		by_id[Vector2i(b.bx, b.bz)] = b
	var strip_cells: int = 0
	for b: Dictionary in blocks:
		var origin: Vector2 = b.origin - offset
		var cells: PackedByteArray = _cell_cover(b)
		_add_mesh(b, by_id, origin)
		strip_cells += _add_collision(b, cells, origin)
	stats = {"blocks": blocks.size(), "strip_cells": strip_cells, "setup_s": (Time.get_ticks_usec() - t0) / 1e6}


## Cover of each cell (N - 1)^2: GRASS unless at least two corners are not
## grass, then the most frequent non-grass cover (ties: higher code).
static func _cell_cover(b: Dictionary) -> PackedByteArray:
	var n: int = Block.N
	var m: PackedByteArray = b.material
	var cells := PackedByteArray()
	cells.resize((n - 1) * (n - 1))
	for j in range(n - 1):
		for i in range(n - 1):
			var q: int = j * n + i
			var counts := [0, 0, 0, 0]
			for c: int in [m[q], m[q + 1], m[q + n], m[q + n + 1]]:
				counts[c] += 1
			var cover: int = Ops.Cover.GRASS
			if counts[0] <= 2:
				var best: int = 0
				for c in range(1, 4):
					if counts[c] >= best and counts[c] > 0:
						best = counts[c]
						cover = c
			cells[j * (n - 1) + i] = cover
	return cells


func _add_mesh(b: Dictionary, by_id: Dictionary, origin: Vector2) -> void:
	var n: int = Block.N
	var h: PackedFloat32Array = b.heights
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	vertices.resize(n * n)
	normals.resize(n * n)
	for j in range(n):
		for i in range(n):
			var q: int = j * n + i
			vertices[q] = Vector3(i * Block.STEP_M, h[q], j * Block.STEP_M)
			var hl: float = _height(b, by_id, i - 1, j)
			var hr: float = _height(b, by_id, i + 1, j)
			var hd: float = _height(b, by_id, i, j - 1)
			var hu: float = _height(b, by_id, i, j + 1)
			var dx: float = (2.0 if not is_nan(hl) and not is_nan(hr) else 1.0) * Block.STEP_M
			var dz: float = (2.0 if not is_nan(hd) and not is_nan(hu) else 1.0) * Block.STEP_M
			hl = h[q] if is_nan(hl) else hl
			hr = h[q] if is_nan(hr) else hr
			hd = h[q] if is_nan(hd) else hd
			hu = h[q] if is_nan(hu) else hu
			normals[q] = Vector3(-(hr - hl) / dx, 1.0, -(hu - hd) / dz).normalized()
	var indices := PackedInt32Array()
	indices.resize((n - 1) * (n - 1) * 6)
	var k: int = 0
	for j in range(n - 1):
		for i in range(n - 1):
			var a: int = j * n + i
			var c: int = a + n
			indices[k] = a
			indices[k + 1] = a + 1
			indices[k + 2] = c
			indices[k + 3] = a + 1
			indices[k + 4] = c + 1
			indices[k + 5] = c
			k += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = b.uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = "Block_%d_%d" % [b.bx, b.bz]
	node.mesh = mesh
	node.material_override = terrain_material
	node.position = Vector3(origin.x, 0.0, origin.y)
	add_child(node)


## Height of sample (i, j) of block b, reaching into a neighbour block when
## (i, j) is outside; NAN when no block holds it.
static func _height(b: Dictionary, by_id: Dictionary, i: int, j: int) -> float:
	var n: int = Block.N
	var id := Vector2i(b.bx, b.bz)
	if i < 0:
		id.x -= 1
		i += n - 1
	elif i >= n:
		id.x += 1
		i -= n - 1
	if j < 0:
		id.y -= 1
		j += n - 1
	elif j >= n:
		id.y += 1
		j -= n - 1
	var holder: Variant = by_id.get(id)
	return NAN if holder == null else holder.heights[j * n + i]


func _add_collision(b: Dictionary, cells: PackedByteArray, origin: Vector2) -> int:
	var n: int = Block.N
	var h: PackedFloat32Array = b.heights
	var faces: Dictionary = {}
	var strip: int = 0
	for j in range(n - 1):
		for i in range(n - 1):
			var cover: int = cells[j * (n - 1) + i]
			if cover == Ops.Cover.GRASS:
				continue
			strip += 1
			var layer: int = Ops.LAYERS[cover]
			if not faces.has(layer):
				faces[layer] = PackedVector3Array()
			var q: int = j * n + i
			var a := Vector3(i * Block.STEP_M, h[q], j * Block.STEP_M)
			var bb := Vector3((i + 1) * Block.STEP_M, h[q + 1], j * Block.STEP_M)
			var c := Vector3(i * Block.STEP_M, h[q + n], (j + 1) * Block.STEP_M)
			var d := Vector3((i + 1) * Block.STEP_M, h[q + n + 1], (j + 1) * Block.STEP_M)
			faces[layer].append_array([a, bb, c, bb, d, c])
	# Heightfield (scale 0.5 on the shape: map units are STEP_M).
	var data := PackedFloat32Array()
	data.resize(n * n)
	for j in range(n):
		for i in range(n):
			var sunk: bool = true
			for cj in [j - 1, j]:
				for ci in [i - 1, i]:
					if ci < 0 or cj < 0 or ci >= n - 1 or cj >= n - 1:
						continue
					sunk = sunk and cells[cj * (n - 1) + ci] != Ops.Cover.GRASS
			var y: float = h[j * n + i] - (SINK_M if sunk else 0.0)
			data[j * n + i] = y / Block.STEP_M
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "Ground_%d_%d" % [b.bx, b.bz]
	body.collision_layer = Ops.LAYERS[Ops.Cover.GRASS]
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.scale = Vector3(Block.STEP_M, Block.STEP_M, Block.STEP_M)
	collider.position = Vector3(origin.x + Block.SIZE_M * 0.5, 0.0, origin.y + Block.SIZE_M * 0.5)
	body.add_child(collider)
	add_child(body)
	for layer: int in faces:
		var strip_body := StaticBody3D.new()
		strip_body.name = "Strip_%d_%d_L%d" % [b.bx, b.bz, layer]
		strip_body.collision_layer = layer
		strip_body.collision_mask = 0
		strip_body.position = Vector3(origin.x, 0.0, origin.y)
		var s := ConcavePolygonShape3D.new()
		s.set_faces(faces[layer])
		var sc := CollisionShape3D.new()
		sc.shape = s
		strip_body.add_child(sc)
		add_child(strip_body)
	return strip
