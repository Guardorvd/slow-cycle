class_name BridgeDeckBuilder
extends RefCounted

## PR1 D6: bridge decks as separate geometry and collision. Pure arrays from
## the consumable network data; natural ground stays under every deck (the
## deformer does not deform declared deck spans). One deck per resolved
## BRIDGE_DECK crossing, over exactly the design stations the deformer leaves
## to the deck (both stations inside the declared span), so the riding surface
## at both abutments is the road plane's own station height and crossfall.
## Riding top (road + shoulders) -> collision layer Road (2); low curbs and the
## deck body -> layer Default (1, the bicycle body collides with it, wheel
## rays do not); piers are render-only. Region-local coordinates; heights in
## metres.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const DECK_DEPTH_M: float = 0.6
const CURB_HEIGHT_M: float = 0.35
const CURB_WIDTH_M: float = 0.2
const PIER_SPACING_M: float = 18.0
const PIER_HALF_M: float = 0.45


## data: RealizedRoadNetwork.get_data(); ground: Callable(x_local, z_local) ->
## natural height (FinalSurface on the deck span). Returns {decks: [{edge_id,
## crossing_id, s0, s1, top: {vertices, indices}, body: {...}, piers: {...},
## top_faces, body_faces}]}.
static func build(data: Dictionary, ground: Callable) -> Dictionary:
	var decks: Array = []
	var designs: Dictionary = {}
	for piece: Dictionary in data.pieces:
		designs[piece.id] = piece
	for c: Dictionary in data.crossings:
		if c.get("status", "") != "RESOLVED" or c.get("support", "") != "BRIDGE_DECK":
			continue
		var piece: Dictionary = designs.get("edge:%d" % c.edge_id, {})
		if piece.is_empty():
			continue
		var deck: Dictionary = _deck(piece, c, ground)
		if not deck.is_empty():
			decks.append(deck)
	return {"decks": decks}


static func _deck(piece: Dictionary, crossing: Dictionary, ground: Callable) -> Dictionary:
	var d: Dictionary = piece.design
	var span: Array = crossing.deck_span_m
	var stations: Array[int] = []
	for k in range(d.s.size()):
		if d.support[k] == Policy.Support.BRIDGE_DECK and d.s[k] >= span[0] - 0.001 and d.s[k] <= span[1] + 0.001:
			stations.append(k)
	if stations.size() < 2:
		return {}
	var shoulder: float = piece.intent.limits.shoulder_m
	var top_v := PackedVector3Array()
	var body_v := PackedVector3Array()
	var top_i := PackedInt32Array()
	var body_i := PackedInt32Array()
	var rows: Array = []
	for k: int in stations:
		var half: float = d.width[k] / 2.0 + shoulder
		var nx: float = -d.tz[k]
		var nz: float = d.tx[k]
		var bank: float = tan(deg_to_rad(d.bank[k]))
		# Lateral t positive on the design's left normal (-tz, tx); the road
		# plane is y - t * tan(bank) (RoadTerrainDeformer convention).
		var left := Vector3(d.x[k] + nx * half, d.y[k] - half * bank, d.z[k] + nz * half)
		var right := Vector3(d.x[k] - nx * half, d.y[k] + half * bank, d.z[k] - nz * half)
		rows.append([left, right, Vector3(nx, 0.0, nz)])
	for r in range(rows.size()):
		var row: Array = rows[r]
		top_v.append_array([row[0], row[1]])
	for r in range(rows.size() - 1):
		var a: int = 2 * r
		_quad(top_i, top_v, a, a + 1, a + 2, a + 3)
	# Deck body: two side faces, the underside, and low curbs on both edges.
	for r in range(rows.size()):
		var row: Array = rows[r]
		var down := Vector3(0.0, -DECK_DEPTH_M, 0.0)
		var up := Vector3(0.0, CURB_HEIGHT_M, 0.0)
		var inward: Vector3 = row[2] * CURB_WIDTH_M
		# per row: 0 left top, 1 left bottom, 2 right top, 3 right bottom,
		# 4 left curb outer top, 5 left curb inner top, 6 right curb outer top, 7 right curb inner top
		body_v.append_array([row[0], row[0] + down, row[1], row[1] + down, row[0] + up, row[0] - inward + up, row[1] + up, row[1] + inward + up])
	for r in range(rows.size() - 1):
		var a: int = 8 * r
		var b: int = a + 8
		_quad(body_i, body_v, a + 1, a, b + 1, b)          # left side
		_quad(body_i, body_v, a + 2, a + 3, b + 2, b + 3)  # right side
		_quad(body_i, body_v, a + 3, a + 1, b + 3, b + 1)  # underside
		_quad(body_i, body_v, a, a + 4, b, b + 4)          # left curb outer face
		_quad(body_i, body_v, a + 4, a + 5, b + 4, b + 5)  # left curb top
		_quad(body_i, body_v, a + 2, a + 6, b + 2, b + 6)  # right curb outer face
		_quad(body_i, body_v, a + 6, a + 7, b + 6, b + 7)  # right curb top
	# Piers: render-only boxes from the underside to natural ground.
	var pier_v := PackedVector3Array()
	var pier_i := PackedInt32Array()
	var length: float = d.s[stations[stations.size() - 1]] - d.s[stations[0]]
	var count: int = int(floor(length / PIER_SPACING_M))
	for q in range(1, count + 1):
		var s: float = d.s[stations[0]] + length * q / (count + 1)
		var k: int = clampi(d.s.bsearch(s), 1, d.s.size() - 1)
		var cx: float = d.x[k]
		var cz: float = d.z[k]
		var top_y: float = d.y[k] - DECK_DEPTH_M
		var bottom: float = float(ground.call(cx, cz))
		if not is_finite(bottom) or bottom >= top_y - 0.2:
			continue
		_box(pier_v, pier_i, Vector3(cx, bottom - 0.5, cz), Vector3(cx, top_y, cz), PIER_HALF_M)
	return {"edge_id": crossing.edge_id, "crossing_id": crossing.get("crossing_id", ""), "s0": d.s[stations[0]], "s1": d.s[stations[stations.size() - 1]],
		"top": {"vertices": top_v, "indices": top_i}, "body": {"vertices": body_v, "indices": body_i}, "piers": {"vertices": pier_v, "indices": pier_i},
		"top_faces": _faces(top_v, top_i), "body_faces": _faces(body_v, body_i), "anchor": [d.x[stations[0]], d.y[stations[0]], d.z[stations[0]]]}


## Two triangles a-b-c, b-d-c with the renderer's up-facing convention for a
## horizontal-ish quad (flipped when the normal points down).
static func _quad(indices: PackedInt32Array, v: PackedVector3Array, a: int, b: int, c: int, d: int) -> void:
	for tri: Array in [[a, b, c], [b, d, c]]:
		indices.append_array(tri)


static func _box(v: PackedVector3Array, idx: PackedInt32Array, bottom: Vector3, top: Vector3, half: float) -> void:
	var base: int = v.size()
	for y: float in [bottom.y, top.y]:
		for corner: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]:
			v.append(Vector3(bottom.x + corner.x, y, bottom.z + corner.y))
	for side in range(4):
		var a: int = base + side
		var b: int = base + (side + 1) % 4
		idx.append_array([a, b, a + 4, b, b + 4, a + 4])


static func _faces(v: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for k in range(0, idx.size(), 3):
		faces.append_array([v[idx[k]], v[idx[k + 1]], v[idx[k + 2]]])
	return faces
