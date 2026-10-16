class_name RegionBakeGround
extends RefCounted

## Ground stage of RegionBake (pure; no scene, no I/O): the region products
## before any trail -
##   upstream   R0-R3 (region plan, terrain, hydrology, natural surface);
##   network    RegionNetworkBuilder -> candidate RealizedRoadNetworks;
##   R7         each candidate isolated against FinalSurface construction and
##              the 8 x 8 tile build, the best constructible one chosen;
##   tiles      FinalSurfaceTileRenderer arrays per 512 m tile with
##              per-triangle collision layer, 64 m patch order and coarse LOD.
## Split out of RegionBake so the stage has its own source closure (dev stage
## reuse, RegionStageCache): code that only reaches trails, bridges or
## vegetation does not reach this file. The products are exactly those of
## the former RegionBake steps (same calls, same order).

const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const TILE_M: int = 512
const TILES: int = 8
const PATCH_M: float = 64.0
const LAYER_ROAD: int = 2
const LAYER_ROUGH: int = 2 | 16
const LAYER_TERRAIN: int = 4
## Bucket order of triangles inside a collision patch (runtime patch bodies).
const PATCH_LAYERS: Array[int] = [LAYER_TERRAIN, LAYER_ROAD, LAYER_ROUGH]
## Bound on surface isolation passes (each excludes at least one piece).
const MAX_ISOLATION_PASSES: int = 24


## R0-R3 of a region: {plan, terrain, hydro (HydrologyGenerator result),
## field, bounds}. Deterministic; rebuilt by every stage that needs it.
static func upstream(seed_value: int, region: Vector2i) -> Dictionary:
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	var field: RefCounted = HField.create(hydro.plan, terrain).field
	return {"plan": plan, "terrain": terrain, "hydro": hydro, "field": field, "bounds": terrain.get_bounds_m()}


## FinalSurface of a realized network over the upstream products (the same
## construction the R7 isolation pass makes for a network it accepts), or
## null when R7 rejects the network over these products.
static func surface_of(up: Dictionary, network: RefCounted) -> RefCounted:
	var deformer: Dictionary = Deformer.create(network, up.field)
	if not deformer.is_valid:
		return null
	var surface: Dictionary = Surface.create(up.terrain, up.field, deformer.deformer)
	return surface.surface if surface.get("is_valid", true) else null


## The ground stage after upstream: network rounds, R7 choice, tiles.
## Returns {is_valid, reason_code, built, chosen {network, surface, slots,
## excluded, score, round, plan, graph}, tried} or a failure record
## {is_valid: false, reason_code, rounds, r7_rounds?, detail?, tile?}.
## `timings` receives network_s, deformer_s and tiles_s.
static func build(seed_value: int, region: Vector2i, up: Dictionary, options: Dictionary, progress: Callable, timings: Dictionary) -> Dictionary:
	var cancelled: Callable = options.get("cancelled", Callable())
	var stopped := {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
	var plan: RefCounted = up.plan
	var terrain: RefCounted = up.terrain
	var hydro: Dictionary = up.hydro
	var field: RefCounted = up.field
	var t: int = Time.get_ticks_usec()
	_report(progress, "network", 0.03)
	var network_progress := func(stage: String, fraction: float) -> void: _report(progress, stage, 0.03 + 0.42 * fraction)
	var built: Dictionary = Builder.build(plan, terrain, hydro.plan, {"seed": seed_value, "region": region, "max_replans": options.get("max_replans", Builder.MAX_REPLANS),
		"stop_rule": options.get("stop_rule", Builder.STOP_ROADS), "natural_intents": bool(options.get("natural_intents", true)),
		"threads": int(options.get("threads", 1)), "progress": network_progress, "cancelled": cancelled})
	timings["network_s"] = _lap(t)
	if not built.is_valid:
		return {"is_valid": false, "reason_code": built.reason_code, "rounds": built.get("rounds", [])}
	var bounds: Dictionary = up.bounds
	var threads: int = int(options.get("threads", 1))
	timings["deformer_s"] = 0.0
	timings["tiles_s"] = 0.0
	# The round is chosen with R7 constructibility: candidates in network score
	# order; each is isolated (below) and scored again. A further candidate is
	# tried only while its score before isolation exceeds the best score after
	# isolation (isolation only removes pieces), so a round R7 would collapse
	# does not hide a round that constructs.
	var candidates: Array = built.get("candidates", [])
	var chosen: Dictionary = {}
	var first_failure: Dictionary = {}
	var tried: Array = []
	for candidate: Dictionary in candidates:
		if not chosen.is_empty() and not candidate.score > chosen.score:
			break
		var made: Dictionary = _isolated(candidate, terrain, field, bounds, threads, progress, cancelled, timings)
		if made.get("reason_code", "") == "ERR_BAKE_CANCELLED":
			return stopped
		var entry := {"round": candidate.round, "score_before": candidate.score, "is_valid": made.is_valid, "reason_code": made.reason_code, "r7_excluded": made.get("excluded", {})}
		if made.is_valid:
			made["score"] = Builder.score_of(made.network.get_metrics())
			made["round"] = candidate.round
			made["plan"] = candidate.plan
			made["graph"] = candidate.graph
			entry["score_after"] = made.score
			if chosen.is_empty() or made.score > chosen.score:
				chosen = made
		elif first_failure.is_empty():
			first_failure = made
		tried.append(entry)
	if chosen.is_empty():
		var failure: Dictionary = {"is_valid": false, "reason_code": first_failure.get("reason_code", "ERR_BAKE_ISOLATION"), "rounds": built.rounds, "r7_rounds": tried}
		for key: String in ["detail", "tile"]:
			if first_failure.has(key):
				failure[key] = first_failure[key]
		return failure
	return {"is_valid": true, "reason_code": "", "built": built, "chosen": chosen, "tried": tried}


## Pieces FinalSurface cannot construct are isolated (M3): construction checks
## of the deformer, then failed tile samples naming their owning pieces. The
## candidate's network is realized again without them (DEGRADE "R7_<reason>"),
## in a fixed order, until the surface and every tile build. Returns {is_valid,
## reason_code, network, surface, slots, excluded} (detail / tile on failure).
static func _isolated(candidate: Dictionary, terrain: RefCounted, field: RefCounted, bounds: Dictionary, threads: int, progress: Callable, cancelled: Callable, timings: Dictionary) -> Dictionary:
	var network: RefCounted = candidate.network
	var checks: Dictionary = {}
	var excluded: Dictionary = {}
	for attempt in range(MAX_ISOLATION_PASSES):
		if cancelled.is_valid() and cancelled.call():
			return {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
		var t: int = Time.get_ticks_usec()
		_report(progress, "surface (round %d)" % candidate.round, 0.45)
		var blamed: Dictionary = {}
		var deformer: Dictionary = Deformer.create(network, field, {"collect_failures": true, "check_cache": checks})
		timings.deformer_s += _lap(t)
		if not deformer.is_valid:
			if deformer.reason_code != "ERR_R7_PIECE_FAILURES":
				return {"is_valid": false, "reason_code": deformer.reason_code, "detail": deformer.get("detail", {}), "excluded": excluded}
			for failure: Dictionary in deformer.failures:
				blamed[failure.piece_id] = failure.reason_code
		else:
			var surface: RefCounted = Surface.create(terrain, field, deformer.deformer).surface
			t = Time.get_ticks_usec()
			var slots: Array = tiles(surface, bounds, network.get_data(), threads, progress, cancelled)
			timings.tiles_s += _lap(t)
			if cancelled.is_valid() and cancelled.call():
				return {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
			var failed: Dictionary = {}
			for slot: Dictionary in slots:
				if not slot.get("is_valid", false):
					failed = slot
					for id: String in slot.get("owners", []):
						blamed[id] = slot.get("reason_code", "ERR_BAKE_TILE")
			if failed.is_empty():
				return {"is_valid": true, "reason_code": "", "network": network, "surface": surface, "slots": slots, "excluded": excluded}
			if blamed.is_empty():
				return {"is_valid": false, "reason_code": failed.get("reason_code", "ERR_BAKE_TILE"), "tile": [failed.tx, failed.tz], "excluded": excluded}
		var ids: Array = blamed.keys()
		ids.sort()
		for id: String in ids:
			excluded[id] = blamed[id]
		var again: Dictionary = Network.from_plan(candidate.plan, candidate.graph, candidate.network.get_data().spec, excluded)
		if not again.is_valid:
			return {"is_valid": false, "reason_code": again.reason_code, "excluded": excluded}
		network = again.network
	return {"is_valid": false, "reason_code": "ERR_BAKE_ISOLATION", "detail": excluded, "excluded": excluded}


## Every tile of the region (optionally threaded; each result lands in its own
## slot dictionary, so order and thread count do not matter).
static func tiles(surface: RefCounted, bounds: Dictionary, data: Dictionary, threads: int, progress: Callable, cancelled: Callable = Callable()) -> Array:
	var piece_class: Dictionary = piece_classes(data)
	var tile_x0: int = int(bounds.min_x) / TILE_M
	var tile_z0: int = int(bounds.min_z) / TILE_M
	var slots: Array = []
	for k in range(TILES * TILES):
		slots.append({"tx": tile_x0 + k % TILES, "tz": tile_z0 + k / TILES})
	var job := func(k: int) -> void:
		if cancelled.is_valid() and cancelled.call():
			slots[k]["is_valid"] = false
			slots[k]["reason_code"] = "ERR_BAKE_CANCELLED"
			return
		_tile(surface, bounds, piece_class, slots[k])
	if threads > 1:
		_report(progress, "tiles", 0.5)
		var group: int = WorkerThreadPool.add_group_task(job, slots.size(), threads, true, "region_bake_tiles")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(slots.size()):
			job.call(k)
			_report(progress, "tiles", 0.5 + 0.4 * float(k + 1) / slots.size())
	return slots


## Route class per piece id of a network's data.
static func piece_classes(data: Dictionary) -> Dictionary:
	var piece_class: Dictionary = {}
	for piece: Dictionary in data.pieces:
		piece_class[piece.id] = piece.info.route_class
	return piece_class


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6


static func _report(progress: Callable, stage: String, fraction: float) -> void:
	if progress.is_valid():
		progress.call(stage, fraction)


## One tile: fine arrays (region-local origin), per-triangle layer and patch,
## coarse 16 m LOD arrays, content hash. Writes into `slot` only.
static func _tile(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, slot: Dictionary) -> void:
	var tile: Dictionary = Renderer.tile_arrays(surface, slot.tx, slot.tz)
	finish_slot(surface, bounds, piece_class, slot, tile, [])


## Slot of built tile arrays: per-triangle layer and patch, origin, coarse
## LOD (given, or computed when empty), content hash. Writes into `slot` only.
static func finish_slot(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, slot: Dictionary, tile: Dictionary, coarse: Array) -> void:
	if not tile.is_valid:
		slot["is_valid"] = false
		slot["reason_code"] = tile.reason_code
		slot["owners"] = tile.get("owners", [])
		return
	var arrays: Array = tile.arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var layers := PackedByteArray()
	var patches := PackedByteArray()
	var count: int = indices.size() / 3
	layers.resize(count)
	patches.resize(count)
	for q in range(count):
		var a: int = indices[3 * q]
		var b: int = indices[3 * q + 1]
		var c: int = indices[3 * q + 2]
		var centre: Vector3 = (vertices[a] + vertices[b] + vertices[c]) / 3.0
		patches[q] = clampi(int(centre.x / PATCH_M), 0, 7) + 8 * clampi(int(centre.z / PATCH_M), 0, 7)
		if uv[a].x == 100.0 and uv[b].x == 100.0 and uv[c].x == 100.0:
			layers[q] = LAYER_TERRAIN
			continue
		var owner: String = surface.road_owner(tile.origin_x_m + centre.x, tile.origin_z_m + centre.z)
		if owner.is_empty():
			# BC1: a trail band off the road planes is rough ground (SINGLETRACK).
			layers[q] = LAYER_ROUGH if not surface.trail_owner(tile.origin_x_m + centre.x, tile.origin_z_m + centre.z).is_empty() else LAYER_TERRAIN
		else:
			layers[q] = LAYER_ROUGH if piece_class.get(owner, 0) >= Graph.RouteClass.SINGLETRACK else LAYER_ROAD
	slot["arrays"] = arrays
	slot["layers"] = layers
	slot["patches"] = patches
	patch_order(slot)
	slot["origin"] = [tile.origin_x_m - bounds.min_x, tile.origin_z_m - bounds.min_z]
	slot["vertex_count"] = tile.vertex_count
	slot["triangle_count"] = tile.triangle_count
	slot["coarse"] = coarse if not coarse.is_empty() else _coarse(surface, tile.origin_x_m, tile.origin_z_m)
	var bytes := PackedByteArray()
	bytes.append_array(vertices.to_byte_array())
	bytes.append_array(indices.to_byte_array())
	bytes.append_array(layers)
	slot["sha256"] = _sha(bytes)
	slot["is_valid"] = true


## Triangles counting-sorted by (patch, PATCH_LAYERS index): patch_order lists
## triangle indices, patch_offsets[b] .. patch_offsets[b + 1] is bucket b
## (b = patch * PATCH_LAYERS.size() + layer index). Writes into `slot` only.
static func patch_order(slot: Dictionary) -> void:
	var layers: PackedByteArray = slot.layers
	var patches: PackedByteArray = slot.patches
	var count: int = layers.size()
	var lanes: int = PATCH_LAYERS.size()
	var offsets := PackedInt32Array()
	offsets.resize(64 * lanes + 1)
	var bucket_of := PackedInt32Array()
	bucket_of.resize(count)
	for q in range(count):
		var b: int = patches[q] * lanes + PATCH_LAYERS.find(layers[q])
		bucket_of[q] = b
		offsets[b + 1] += 1
	for b in range(1, offsets.size()):
		offsets[b] += offsets[b - 1]
	var cursor: PackedInt32Array = offsets.duplicate()
	var order := PackedInt32Array()
	order.resize(count)
	for q in range(count):
		order[cursor[bucket_of[q]]] = q
		cursor[bucket_of[q]] += 1
	slot["patch_order"] = order
	slot["patch_offsets"] = offsets


static func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## 33 x 33 lattice of FinalSurface heights (16 m) for distant rendering.
static func _coarse(surface: RefCounted, ox: float, oz: float) -> Array:
	var vertices := PackedVector3Array()
	for j in range(33):
		for i in range(33):
			var h: Dictionary = surface.sample_height(ox + 16.0 * i, oz + 16.0 * j)
			vertices.append(Vector3(16.0 * i, h.height_m if h.is_valid else 0.0, 16.0 * j))
	var indices := PackedInt32Array()
	for j in range(32):
		for i in range(32):
			var a: int = j * 33 + i
			indices.append_array([a, a + 1, a + 33, a + 1, a + 34, a + 33])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	for k in range(0, indices.size(), 3):
		var n: Vector3 = (vertices[indices[k + 2]] - vertices[indices[k]]).cross(vertices[indices[k + 1]] - vertices[indices[k]])
		for m in range(3):
			normals[indices[k + m]] += n
	for k in range(normals.size()):
		normals[k] = normals[k].normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
