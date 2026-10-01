extends RefCounted

## Independent checks: Godot clockwise front faces; actual XZ triangle support.
static func mesh_report(arrays: Array, reference: Vector3 = Vector3.UP) -> Dictionary:
	var result := {"available": false, "triangles": 0, "inverted": 0, "degenerate": 0, "reason": "MESH_MISSING"}
	if arrays.size() != Mesh.ARRAY_MAX or not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		return result
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.size() < 3 or indices.size() < 3 or indices.size() % 3 != 0:
		return result
	for index in indices:
		if index < 0 or index >= verts.size() or not verts[index].is_finite():
			result.reason = "MESH_INVALID"
			return result
	result.available = true
	result.reason = ""
	for i in range(0, indices.size(), 3):
		var cross: Vector3 = (verts[indices[i + 1]] - verts[indices[i]]).cross(verts[indices[i + 2]] - verts[indices[i]])
		result.triangles += 1
		if cross.length() * 0.5 < 0.0005:
			result.degenerate += 1
		elif (-cross.normalized()).dot(reference) <= 0.0:
			result.inverted += 1
	return result

static func triangle_height(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> float:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(x - a.x, z - a.z)
	var den := v0.cross(v1)
	if absf(den) < 1e-6:
		return INF
	var v := v2.cross(v1) / den
	var w := v0.cross(v2) / den
	var u := 1.0 - v - w
	if u >= -0.0005 and v >= -0.0005 and w >= -0.0005:
		return u * a.y + v * b.y + w * c.y
	return INF

static func contact_report(faces: PackedVector3Array, props: Array, allow_barren: bool = false) -> Dictionary:
	var result := {"available": faces.size() >= 3 and faces.size() % 3 == 0, "expected_props": props.size(), "checked_contacts": 0, "missing_ground": 0, "floating": 0, "buried": 0, "valid": false}
	for prop in props:
		var position: Vector3 = prop.pos
		var surface_y := INF
		var min_delta := INF
		for i in range(0, faces.size() - 2, 3):
			var y := triangle_height(faces[i], faces[i + 1], faces[i + 2], position.x, position.z)
			if is_finite(y) and absf(y - position.y) < min_delta:
				min_delta = absf(y - position.y)
				surface_y = y
		if not is_finite(surface_y):
			result.missing_ground += 1
			continue
		result.checked_contacts += 1
		var delta := position.y - surface_y
		if delta > 0.05:
			result.floating += 1
		elif delta < -0.35:
			result.buried += 1
	result.valid = result.available and (allow_barren or result.expected_props > 0) and result.checked_contacts == result.expected_props and result.missing_ground == 0 and result.floating == 0 and result.buried == 0
	return result

static func props_from(transforms: Dictionary) -> Array:
	var props: Array = []
	for kind in ["pine", "birch", "boulder"]:
		for transform in transforms.get(kind, []):
			props.append({"type": kind, "pos": transform.origin})
	return props

static func wedge_valid(prep: RefCounted, expected: bool) -> bool:
	var first: int = prep.terrain_wedge_first_triangle
	var count: int = prep.terrain_wedge_triangle_count
	if count == 0:
		return not expected
	if first < 0 or count < 1 or (first + count) * 3 > prep.terrain_faces.size():
		return false
	for i in range(first * 3, (first + count) * 3, 3):
		var cross: Vector3 = (prep.terrain_faces[i + 1] - prep.terrain_faces[i]).cross(prep.terrain_faces[i + 2] - prep.terrain_faces[i])
		if cross.length() * 0.5 < 0.0005 or -cross.normalized().y < 0.20:
			return false
	return true
