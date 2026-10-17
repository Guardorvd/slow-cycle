extends RefCounted
class_name SurfaceBlock
## GEN2-S S1: one square block of the final ground as data (pure; no scene):
## heights and a material per sample on a regular grid. Block (bx, bz) covers
## world [bx * SIZE_M, (bx + 1) * SIZE_M] x [bz * SIZE_M, (bz + 1) * SIZE_M]
## inclusive; sample (i, j) sits at world (bx * SIZE_M + i * STEP_M, ...) and
## is computed from that world point alone, so the shared edge of two blocks
## is the same numbers in both (seams match bit for bit) and the result does
## not depend on build order or thread count.

const Ops = preload("res://scripts/world/surface/surface_ops.gd")

const SIZE_M: float = 128.0
const STEP_M: float = 0.5
const N: int = int(SIZE_M / STEP_M) + 1


## {is_valid, bx, bz, origin: Vector2, heights: PackedFloat32Array (N * N,
## row j = z), material: PackedByteArray (N * N, SurfaceOps.Cover), uv:
## PackedVector2Array (N * N, terrain shader coordinates), ops: [op ids], digest,
## reason_code}.
static func build(ops: RefCounted, bx: int, bz: int) -> Dictionary:
	var origin := Vector2(bx * SIZE_M, bz * SIZE_M)
	var touching: Array = ops.touching(Rect2(origin, Vector2(SIZE_M, SIZE_M)))
	var heights := PackedFloat32Array()
	var material := PackedByteArray()
	var uv := PackedVector2Array()
	heights.resize(N * N)
	material.resize(N * N)
	uv.resize(N * N)
	for j in range(N):
		var z: float = origin.y + j * STEP_M
		for i in range(N):
			var x: float = origin.x + i * STEP_M
			var s: Dictionary = ops.sample(x, z, touching)
			if not s.is_valid:
				return {"is_valid": false, "bx": bx, "bz": bz, "reason_code": s.reason_code, "detail": {"x": x, "z": z}}
			heights[j * N + i] = s.height_m
			material[j * N + i] = s.material
			uv[j * N + i] = s.uv
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(heights.to_byte_array())
	ctx.update(material)
	ctx.update(uv.to_byte_array())
	return {"is_valid": true, "bx": bx, "bz": bz, "origin": origin, "heights": heights, "material": material, "uv": uv,
		"ops": touching.map(func(op: Dictionary) -> String: return op.id), "digest": ctx.finish().hex_encode(), "reason_code": ""}


## Bilinear height of a block at a world point inside it.
static func height_at(block: Dictionary, x: float, z: float) -> float:
	var u: float = clampf((x - block.origin.x) / STEP_M, 0.0, N - 1.000001)
	var v: float = clampf((z - block.origin.y) / STEP_M, 0.0, N - 1.000001)
	var i: int = int(u)
	var j: int = int(v)
	var fu: float = u - i
	var fv: float = v - j
	var h: PackedFloat32Array = block.heights
	var a: float = lerpf(h[j * N + i], h[j * N + i + 1], fu)
	var b: float = lerpf(h[(j + 1) * N + i], h[(j + 1) * N + i + 1], fu)
	return lerpf(a, b, fv)
