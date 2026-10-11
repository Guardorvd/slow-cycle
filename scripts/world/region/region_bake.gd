class_name RegionBake
extends RefCounted

## PR1 D7: deterministic bake of one region (pure; no scene, no I/O).
##   upstream   R0-R3 (region plan, terrain, hydrology, natural surface);
##   network    RegionNetworkBuilder -> RealizedRoadNetwork;
##   surface    RoadTerrainDeformer over the network -> FinalSurface;
##   tiles      8 x 8 tiles of 512 m: FinalSurfaceTileRenderer arrays (the
##              same triangles render and collide), per-triangle collision
##              layer (Road 2, RoughRoad 2|16 for SINGLETRACK / TECHNICAL,
##              Terrain 4) and 64 m collision-patch id, plus a coarse 16 m LOD;
##   bridges    BridgeDeckBuilder decks; water ribbons / lake cells;
##   spawn      a backbone point near the region centre, facing along it.
## Output is region-local (x - min_x, z - min_z) so runtime float32 stays
## precise anywhere in the int64 world. Tiles may be built on WorkerThreadPool
## threads: each tile is independent and its arrays do not depend on order or
## thread count (manifest hashes prove it). The whole bake runs off the main
## thread (RoadSynthesizer.off_main_thread: main-thread `exp`/`pow` differ in
## the last bits), so a probe, a test and the runtime loader bake identically.
## `progress` (optional Callable(stage: String, fraction: float)) is called
## from the baking thread.

const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
const Bridges = preload("res://scripts/world/region/bridge_deck_builder.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const SCHEMA := "slow_cycle.region_bake/1"
const TILE_M: int = 512
const TILES: int = 8
const PATCH_M: float = 64.0
const LAYER_ROAD: int = 2
const LAYER_ROUGH: int = 2 | 16
const LAYER_TERRAIN: int = 4


static func bake(seed_value: int, region: Vector2i, options: Dictionary = {}, progress: Callable = Callable()) -> Dictionary:
	return Synth.off_main_thread(func() -> Dictionary: return _bake(seed_value, region, options, progress))


static func _bake(seed_value: int, region: Vector2i, options: Dictionary, progress: Callable) -> Dictionary:
	var timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	_report(progress, "upstream", 0.0)
	var plan: RefCounted = Gen.build(seed_value, region)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	var field: RefCounted = HField.create(hydro.plan, terrain).field
	timings["upstream_s"] = _lap(t)
	t = Time.get_ticks_usec()
	_report(progress, "network", 0.03)
	var built: Dictionary = Builder.build(plan, terrain, hydro.plan, {"seed": seed_value, "region": region, "max_replans": options.get("max_replans", Builder.MAX_REPLANS),
		"threads": int(options.get("threads", 1))})
	timings["network_s"] = _lap(t)
	if not built.is_valid:
		return {"is_valid": false, "reason_code": built.reason_code, "rounds": built.get("rounds", [])}
	var network: RefCounted = built.network
	t = Time.get_ticks_usec()
	_report(progress, "surface", 0.45)
	var deformer: Dictionary = Deformer.create(network, field)
	if not deformer.is_valid:
		return {"is_valid": false, "reason_code": deformer.reason_code, "detail": deformer.get("detail", {}), "rounds": built.rounds}
	var surface: RefCounted = Surface.create(terrain, field, deformer.deformer).surface
	timings["deformer_s"] = _lap(t)
	var bounds: Dictionary = terrain.get_bounds_m()
	var data: Dictionary = network.get_data()
	var piece_class: Dictionary = {}
	for piece: Dictionary in data.pieces:
		piece_class[piece.id] = piece.info.route_class
	# Tiles (optionally threaded; results land in per-tile dictionaries).
	t = Time.get_ticks_usec()
	var tile_x0: int = int(bounds.min_x) / TILE_M
	var tile_z0: int = int(bounds.min_z) / TILE_M
	var slots: Array = []
	for k in range(TILES * TILES):
		slots.append({"tx": tile_x0 + k % TILES, "tz": tile_z0 + k / TILES})
	var job := func(k: int) -> void:
		_tile(surface, bounds, piece_class, slots[k])
	var threads: int = int(options.get("threads", 1))
	if threads > 1:
		var group: int = WorkerThreadPool.add_group_task(job, slots.size(), threads, true, "region_bake_tiles")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(slots.size()):
			job.call(k)
			_report(progress, "tiles", 0.5 + 0.4 * float(k + 1) / slots.size())
	timings["tiles_s"] = _lap(t)
	for slot: Dictionary in slots:
		if not slot.get("is_valid", false):
			return {"is_valid": false, "reason_code": slot.get("reason_code", "ERR_BAKE_TILE"), "tile": [slot.tx, slot.tz], "rounds": built.rounds}
	t = Time.get_ticks_usec()
	_report(progress, "bridges_water", 0.92)
	var ground := func(x: float, z: float) -> float:
		var h: Dictionary = surface.sample_height(x + bounds.min_x, z + bounds.min_z)
		return h.height_m if h.is_valid else NAN
	var bridges: Dictionary = Bridges.build(data, ground)
	var water: Dictionary = _water(hydro.plan)
	timings["bridges_water_s"] = _lap(t)
	var spawn: Dictionary = _spawn(data)
	var manifest: Dictionary = {"schema": SCHEMA, "seed": seed_value, "region": [region.x, region.y], "origin": [bounds.min_x, bounds.min_z],
		"region_signature": plan.signature(), "hydrology_signature": hydro.plan.signature(), "network_digest": network.digest(), "graph_signature": built.graph.signature(),
		"plan_signature": built.plan.signature(), "chosen_round": built.round, "rounds": _round_summaries(built.rounds), "metrics": data.metrics, "tiles": [], "timings_s": timings,
		"bridges": bridges.decks.size(), "threads": threads}
	var vertices: int = 0
	var triangles: int = 0
	for slot: Dictionary in slots:
		vertices += slot.vertex_count
		triangles += slot.triangle_count
		manifest.tiles.append({"tile": [slot.tx, slot.tz], "vertices": slot.vertex_count, "triangles": slot.triangle_count, "sha256": slot.sha256})
	manifest["vertices"] = vertices
	manifest["triangles"] = triangles
	manifest["tiles_digest"] = _tiles_digest(slots)
	_report(progress, "done", 1.0)
	return {"is_valid": true, "reason_code": "", "manifest": manifest, "network": network, "tiles": slots, "bridges": bridges, "water": water, "spawn": spawn,
		"surface": surface, "terrain": terrain, "hydrology": hydro.plan, "field": field, "plan": plan}


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6


static func _report(progress: Callable, stage: String, fraction: float) -> void:
	if progress.is_valid():
		progress.call(stage, fraction)


## One tile: fine arrays (region-local origin), per-triangle layer and patch,
## coarse 16 m LOD arrays, content hash. Writes into `slot` only.
static func _tile(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, slot: Dictionary) -> void:
	var tile: Dictionary = Renderer.tile_arrays(surface, slot.tx, slot.tz)
	if not tile.is_valid:
		slot["is_valid"] = false
		slot["reason_code"] = tile.reason_code
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
			layers[q] = LAYER_TERRAIN
		else:
			layers[q] = LAYER_ROUGH if piece_class.get(owner, 0) >= Graph.RouteClass.SINGLETRACK else LAYER_ROAD
	slot["arrays"] = arrays
	slot["layers"] = layers
	slot["patches"] = patches
	slot["origin"] = [tile.origin_x_m - bounds.min_x, tile.origin_z_m - bounds.min_z]
	slot["vertex_count"] = tile.vertex_count
	slot["triangle_count"] = tile.triangle_count
	slot["coarse"] = _coarse(surface, tile.origin_x_m, tile.origin_z_m)
	var bytes := PackedByteArray()
	bytes.append_array(vertices.to_byte_array())
	bytes.append_array(indices.to_byte_array())
	bytes.append_array(layers)
	slot["sha256"] = _sha(bytes)
	slot["is_valid"] = true


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


static func _tiles_digest(slots: Array) -> String:
	var lines: String = ""
	for slot: Dictionary in slots:
		lines += "%d,%d,%s\n" % [slot.tx, slot.tz, slot.sha256]
	return lines.sha256_text()


## Ribbons along every channel (surface heights) and flat cells for bodies,
## region-local.
static func _water(hydrology: RefCounted) -> Dictionary:
	var ribbons: Array = []
	for c in range(hydrology.get_channel_count()):
		var channel: Dictionary = hydrology.get_channel(c)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var n: int = channel.x_cm.size()
		for k in range(n):
			var a := Vector2(channel.x_cm[maxi(0, k - 1)], channel.z_cm[maxi(0, k - 1)]) / 100.0
			var b := Vector2(channel.x_cm[mini(n - 1, k + 1)], channel.z_cm[mini(n - 1, k + 1)]) / 100.0
			var normal: Vector2 = (b - a).normalized().orthogonal() * channel.width_cm[k] / 200.0
			var p := Vector2(channel.x_cm[k], channel.z_cm[k]) / 100.0
			var y: float = channel.surface_cm[k] / 100.0
			vertices.append(Vector3(p.x + normal.x, y, p.y + normal.y))
			vertices.append(Vector3(p.x - normal.x, y, p.y - normal.y))
			if k > 0:
				var q: int = 2 * k
				indices.append_array([q - 2, q - 1, q, q - 1, q + 1, q])
		ribbons.append({"id": channel.id, "class": channel["class"], "vertices": vertices, "indices": indices})
	var lakes: Array = []
	for b in range(hydrology.get_body_count()):
		var body: Dictionary = hydrology.get_body(b)
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var level: float = body.level_cm / 100.0
		for cell: int in body.cells:
			var cx: float = (cell % 129) * 32.0
			var cz: float = (cell / 129) * 32.0
			var base: int = vertices.size()
			vertices.append_array([Vector3(cx - 16.0, level, cz - 16.0), Vector3(cx + 16.0, level, cz - 16.0), Vector3(cx - 16.0, level, cz + 16.0), Vector3(cx + 16.0, level, cz + 16.0)])
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		lakes.append({"id": body.id, "vertices": vertices, "indices": indices, "level": level})
	return {"ribbons": ribbons, "lakes": lakes}


## Spawn: the backbone station nearest the region centre (ground point and
## forward direction), else the first edge piece.
static func _spawn(data: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for piece: Dictionary in data.pieces:
		if piece.info.kind != "EDGE":
			continue
		var d: Dictionary = piece.design
		var cls: int = piece.info.route_class
		for k in range(0, d.s.size(), 4):
			var dist: float = Vector2(d.x[k] - 2048.0, d.z[k] - 2048.0).length() + (0.0 if cls == Graph.RouteClass.BACKBONE else 4000.0)
			if dist < best_d:
				best_d = dist
				var recommended: int = int(piece.info.get("recommended", 0))
				var sign: float = -1.0 if recommended < 0 else 1.0
				best = {"position": Vector3(d.x[k], d.y[k], d.z[k]), "direction": Vector3(d.tx[k] * sign, 0.0, d.tz[k] * sign), "piece": piece.id, "station": k}
	return best


static func _round_summaries(rounds: Array) -> Array:
	var out: Array = []
	for r: Dictionary in rounds:
		var m: Dictionary = r.get("metrics", {})
		out.append({"round": r.round, "status": r.status, "hints": r.get("hints", 0), "score": r.get("score", []), "edges": r.get("edges", 0), "edges_ready": r.get("edges_ready", 0),
			"seconds": r.get("seconds", {}), "component_length_m": m.get("component_length_m", 0.0), "cycles": m.get("cycles", 0), "classes": m.get("classes", {})})
	return out
