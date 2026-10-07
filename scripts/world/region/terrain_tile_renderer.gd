class_name TerrainTileRenderer
extends RefCounted

## Builds one terrain tile from TerrainField lattice queries (R2): mesh arrays
## and an ArrayMesh, nothing else (no nodes, materials or cached state).
##
## A tile (tile_x, tile_z) covers the world square [512 tile_x, 512 tile_x +
## 512] x [512 tile_z, 512 tile_z + 512] with 33 x 33 lattice points. Every
## vertex is a lattice point queried from the field, so neighbouring tiles
## share bit-identical edge positions and normals by construction, whichever
## tile is built first and from whichever field instance of the same region.
## Vertex positions are tile-local; the tile origin is returned in world metres.

const Field = preload("res://scripts/world/region/terrain_field.gd")
const TILE_CELLS: int = 32
const TILE_VERTICES: int = TILE_CELLS + 1
const TILE_SIZE_M: int = TILE_CELLS * Field.LATTICE_STEP_M


static func tile_arrays(field: RefCounted, tile_x: int, tile_z: int) -> Dictionary:
	var failed := {"is_valid": false, "arrays": [], "heights_m": PackedFloat64Array(), "origin_x_m": 0, "origin_z_m": 0, "reason_code": ""}
	if field == null or not field is Field:
		failed.reason_code = "ERR_TILE_FIELD_MISSING"
		return failed
	# Range check before multiplying, so no int64 overflow can alias a tile
	# back into the region.
	var bounds: Dictionary = field.get_bounds_m()
	if tile_x < bounds.min_x / TILE_SIZE_M or tile_x >= bounds.max_x / TILE_SIZE_M or tile_z < bounds.min_z / TILE_SIZE_M or tile_z >= bounds.max_z / TILE_SIZE_M:
		failed.reason_code = "ERR_TERRAIN_OUT_OF_DOMAIN"
		return failed
	var sampled: Dictionary = field.sample_lattice(tile_x * TILE_CELLS, tile_z * TILE_CELLS, TILE_VERTICES, TILE_VERTICES)
	if not sampled.is_valid:
		failed.reason_code = sampled.reason_code
		return failed
	var heights: PackedFloat64Array = sampled.heights_m
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.resize(TILE_VERTICES * TILE_VERTICES)
	for iz in range(TILE_VERTICES):
		for ix in range(TILE_VERTICES):
			var k: int = iz * TILE_VERTICES + ix
			vertices[k] = Vector3(ix * Field.LATTICE_STEP_M, heights[k], iz * Field.LATTICE_STEP_M)
	for iz in range(TILE_CELLS):
		for ix in range(TILE_CELLS):
			var a: int = iz * TILE_VERTICES + ix
			# Clockwise when viewed from +Y (Godot's front-face convention).
			indices.append_array([a, a + 1, a + TILE_VERTICES, a + 1, a + TILE_VERTICES + 1, a + TILE_VERTICES])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = sampled.normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return {"is_valid": true, "arrays": arrays, "heights_m": heights, "origin_x_m": tile_x * TILE_SIZE_M, "origin_z_m": tile_z * TILE_SIZE_M, "reason_code": ""}


static func tile_mesh(field: RefCounted, tile_x: int, tile_z: int) -> Dictionary:
	var built: Dictionary = tile_arrays(field, tile_x, tile_z)
	if not built.is_valid:
		return {"is_valid": false, "mesh": null, "heights_m": built.heights_m, "origin_x_m": 0, "origin_z_m": 0, "reason_code": built.reason_code}
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built.arrays)
	return {"is_valid": true, "mesh": mesh, "heights_m": built.heights_m, "origin_x_m": built.origin_x_m, "origin_z_m": built.origin_z_m, "reason_code": ""}
