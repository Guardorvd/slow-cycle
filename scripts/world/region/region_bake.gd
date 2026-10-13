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
##   vegetation RegionVegetationPlanner per tile (M5, D9; on FinalSurface);
##   spawn      a backbone point near the region centre, facing along it;
##   trails     BC1 (options.trail_config, the parsed TrailRealization
##              configuration; absent = prototype-off, products unchanged):
##              realized on the chosen products and published atomically
##              (_trails) before bridges, water and vegetation.
## Output is region-local (x - min_x, z - min_z) so runtime float32 stays
## precise anywhere in the int64 world. Tiles may be built on WorkerThreadPool
## threads: each tile is independent and its arrays do not depend on order or
## thread count (manifest hashes prove it). The whole bake runs off the main
## thread (RoadSynthesizer.off_main_thread: main-thread `exp`/`pow` differ in
## the last bits), so a probe, a test and the runtime loader bake identically.
## `progress` (optional Callable(stage: String, fraction: float)) is called
## from the baking thread; options.cancelled (optional Callable() -> bool) is
## polled between stages and ends the bake with ERR_BAKE_CANCELLED.

const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
const Bridges = preload("res://scripts/world/region/bridge_deck_builder.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const SCHEMA := "slow_cycle.region_bake/1"
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
## Bound on BC1 trail border-agreement passes (each adds border points).
const MAX_SEAM_PASSES: int = 12


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
	var cancelled: Callable = options.get("cancelled", Callable())
	var stopped := {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
	if cancelled.is_valid() and cancelled.call():
		return stopped
	t = Time.get_ticks_usec()
	_report(progress, "network", 0.03)
	var network_progress := func(stage: String, fraction: float) -> void: _report(progress, stage, 0.03 + 0.42 * fraction)
	var built: Dictionary = Builder.build(plan, terrain, hydro.plan, {"seed": seed_value, "region": region, "max_replans": options.get("max_replans", Builder.MAX_REPLANS),
		"threads": int(options.get("threads", 1)), "progress": network_progress, "cancelled": cancelled})
	timings["network_s"] = _lap(t)
	if not built.is_valid:
		return {"is_valid": false, "reason_code": built.reason_code, "rounds": built.get("rounds", [])}
	var bounds: Dictionary = terrain.get_bounds_m()
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
	var network: RefCounted = chosen.network
	var surface: RefCounted = chosen.surface
	var slots: Array = chosen.slots
	var excluded: Dictionary = chosen.excluded
	var trail_report: Dictionary = {}
	if options.has("trail_config"):
		t = Time.get_ticks_usec()
		_report(progress, "trails", 0.91)
		var made: Dictionary = _trails(options.trail_config, seed_value, region, network, surface, field, bounds, slots, threads)
		network = made.network
		surface = made.surface
		slots = made.slots
		trail_report = made.report
		timings["trails_s"] = _lap(t)
	var data: Dictionary = network.get_data()
	t = Time.get_ticks_usec()
	_report(progress, "bridges_water", 0.92)
	var ground := func(x: float, z: float) -> float:
		var h: Dictionary = surface.sample_height(x + bounds.min_x, z + bounds.min_z)
		return h.height_m if h.is_valid else NAN
	var bridges: Dictionary = Bridges.build(data, ground)
	var water: Dictionary = _water(hydro.plan)
	timings["bridges_water_s"] = _lap(t)
	if cancelled.is_valid() and cancelled.call():
		return stopped
	t = Time.get_ticks_usec()
	_report(progress, "vegetation", 0.94)
	var flora: Dictionary = Vegetation.create(plan, terrain, hydro.plan, surface)
	if not flora.is_valid:
		return {"is_valid": false, "reason_code": flora.reason_code, "rounds": built.rounds}
	var vegetation: Array = _vegetation(flora.planner, slots, threads)
	timings["vegetation_s"] = _lap(t)
	var spawn: Dictionary = _spawn(data)
	var manifest: Dictionary = {"schema": SCHEMA, "seed": seed_value, "region": [region.x, region.y], "origin": [bounds.min_x, bounds.min_z],
		"region_signature": plan.signature(), "hydrology_signature": hydro.plan.signature(), "network_digest": network.digest(), "graph_signature": chosen.graph.signature(),
		"plan_signature": chosen.plan.signature(), "chosen_round": chosen.round, "network_best_round": built.round, "rounds": _round_summaries(built.rounds), "metrics": data.metrics,
		"tiles": [], "timings_s": timings, "r7_excluded": excluded, "r7_rounds": _r7_summaries(tried),
		"bridges": bridges.decks.size(), "threads": threads}
	if options.has("trail_config"):
		manifest["trails"] = trail_report
	var vertices: int = 0
	var triangles: int = 0
	for slot: Dictionary in slots:
		vertices += slot.vertex_count
		triangles += slot.triangle_count
		manifest.tiles.append({"tile": [slot.tx, slot.tz], "vertices": slot.vertex_count, "triangles": slot.triangle_count, "sha256": slot.sha256})
	manifest["vertices"] = vertices
	manifest["triangles"] = triangles
	manifest["tiles_digest"] = _tiles_digest(slots)
	manifest["vegetation"] = _vegetation_summary(vegetation)
	_report(progress, "done", 1.0)
	return {"is_valid": true, "reason_code": "", "manifest": manifest, "network": network, "tiles": slots, "bridges": bridges, "water": water, "spawn": spawn, "vegetation": vegetation,
		"surface": surface, "terrain": terrain, "hydrology": hydro.plan, "field": field, "plan": plan, "graph": chosen.graph}


## BC1: realize the configured trails on the chosen products and publish them
## atomically. The tiles their bands reach are refined from their prototype-
## off arrays on the trail surface (FinalSurfaceTileRenderer.refine_arrays),
## in passes until the tiles agree on every shared border: each pass forces
## the border midpoints any tile made, and a tile whose border receives one
## joins; the other tiles keep their arrays. Final heights come from the
## published triangles (FinalSurface.with_published), and every trail is
## checked again on them (TrailRealization.finalize). A trail rejected at any
## step leaves no trace: the rest are published again without it, and with
## none left the products stay exactly the prototype-off ones. Returns
## {network, surface, slots, report: {config_sha256, published, rejected}}.
static func _trails(config: Variant, seed_value: int, region: Vector2i, network: RefCounted, surface: RefCounted, field: RefCounted, bounds: Dictionary, slots: Array,
		threads: int) -> Dictionary:
	var context := {"seed": seed_value, "region": region, "network": network.get_data(), "surface": surface, "field": field}
	var realized: Dictionary = Trail.realize_all(config, context)
	var rejected: Array = realized.rejected.duplicate(true)
	var trails: Array = realized.trails
	var report := {"config_sha256": JSON.stringify(config, "", true).sha256_text(), "published": [], "rejected": rejected}
	var unchanged := {"network": network, "surface": surface, "slots": slots, "report": report}
	var piece_class: Dictionary = {}
	for piece: Dictionary in network.get_data().pieces:
		piece_class[piece.id] = piece.info.route_class
	while not trails.is_empty():
		var indices: Array = _trail_tiles(trails, slots, bounds)
		# Benches are measured on the published pre-bench surface of their zone.
		var pre: RefCounted = surface.with_trails(trails).with_published(indices.map(func(k: int) -> Dictionary: return slots[k]))
		var shaped: Array = []
		for trail: Dictionary in trails:
			var made: Dictionary = Trail.shape(trail, pre)
			if made.is_valid:
				shaped.append(made.trail)
			else:
				rejected.append({"id": made.id, "reason_code": made.reason_code, "detail": made.detail})
		if shaped.size() < trails.size():
			trails = shaped
			continue
		trails = shaped
		var trail_surface: RefCounted = surface.with_trails(trails)
		var forced: Dictionary = {}
		var refined: Array = []
		var failure: Dictionary = {}
		var agreed: bool = false
		for attempt in range(MAX_SEAM_PASSES):
			refined = _refine_tiles(trail_surface, bounds, piece_class, threads, slots, indices, forced)
			for slot: Dictionary in refined:
				if not slot.is_valid:
					failure = slot
			if not failure.is_empty():
				break
			var grew: bool = false
			for slot: Dictionary in refined:
				for point: Vector2 in slot.border_points:
					if not forced.has(point):
						forced[point] = true
						grew = true
			for point: Vector2 in forced:
				for k in range(slots.size()):
					var rect := Rect2(slots[k].tx * TILE_M, slots[k].tz * TILE_M, TILE_M, TILE_M)
					if not k in indices and rect.grow(0.001).has_point(point) and not rect.grow(-0.001).has_point(point):
						indices.append(k)
						grew = true
			if not grew:
				agreed = true
				break
		if failure.is_empty() and not agreed:
			failure = {"reason_code": "ERR_TRAIL_TILE", "tx": -1, "tz": -1, "detail": "no border agreement in %d passes" % MAX_SEAM_PASSES}
		if not failure.is_empty():
			for trail: Dictionary in trails:
				rejected.append({"id": trail.id, "reason_code": "ERR_TRAIL_UNRIDEABLE", "detail": {"stage": "published geometry", "reason": failure.get("reason_code", ""),
					"tile": [failure.tx, failure.tz], "note": str(failure.get("detail", ""))}})
			return unchanged
		var published: RefCounted = trail_surface.with_published(refined)
		var finished: Array = []
		var kept: Array = []
		for trail: Dictionary in trails:
			var made: Dictionary = Trail.finalize(trail, published, context)
			if made.is_valid:
				finished.append(made.trail)
				kept.append(trail)
			else:
				rejected.append({"id": made.id, "reason_code": made.reason_code, "detail": made.detail})
		if kept.size() < trails.size():
			trails = kept
			continue
		var joined: Dictionary = network.with_trails(finished)
		if not joined.is_valid:
			for trail: Dictionary in trails:
				rejected.append({"id": trail.id, "reason_code": joined.reason_code, "detail": {"stage": "network publication"}})
			return unchanged
		var out_slots: Array = slots.duplicate()
		for m in range(indices.size()):
			refined[m].erase("border_points")
			out_slots[indices[m]] = refined[m]
		for trail: Dictionary in finished:
			report.published.append({"id": trail.id, "mode": trail.mode, "length_m": trail.length_m, "nodes": trail.nodes, "joins": trail.joins, "metrics": trail.metrics,
				"directions": trail.directions, "tiles": indices.map(func(k: int) -> Array: return [slots[k].tx, slots[k].tz]), "border_points": forced.size(),
				"operations": trail.operations.map(func(op: Dictionary) -> Dictionary: return {"kind": op.kind, "mode": op.mode, "s0_m": op.s0_m, "s1_m": op.s1_m,
					"daylight_m": op.daylight_m, "taper_m": op.taper_m, "metrics": op.metrics})})
		return {"network": joined.network, "surface": published, "slots": out_slots, "report": report}
	return unchanged


## Indices of the tile slots a trail band may refine (band within the
## renderer's refinement reach of the tile).
static func _trail_tiles(trails: Array, slots: Array, bounds: Dictionary) -> Array:
	var out: Array = []
	for k in range(slots.size()):
		var rect := Rect2(slots[k].tx * TILE_M - bounds.min_x, slots[k].tz * TILE_M - bounds.min_z, TILE_M, TILE_M).grow(Renderer.TRAIL_REFINE_M + 1.5)
		var near: bool = false
		for trail: Dictionary in trails:
			var line: Dictionary = trail.line
			for i in range(line.s.size()):
				near = near or rect.grow(trail.half_width_m).has_point(Vector2(line.x[i], line.z[i]))
		if near:
			out.append(k)
	return out


## Trail refinement of the listed tiles from their slot arrays (threaded like
## _tiles; each job writes its own slot).
static func _refine_tiles(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, threads: int, slots: Array, indices: Array, forced: Dictionary) -> Array:
	var out: Array = []
	for k: int in indices:
		out.append({"tx": slots[k].tx, "tz": slots[k].tz})
	var job := func(m: int) -> void:
		var base: Dictionary = slots[indices[m]]
		var tile: Dictionary = Renderer.refine_arrays(surface, base.arrays, base.tx, base.tz, forced)
		_finish_slot(surface, bounds, piece_class, out[m], tile, base.coarse)
		out[m]["border_points"] = tile.get("border_points", [])
	if threads > 1 and out.size() > 1:
		var group: int = WorkerThreadPool.add_group_task(job, out.size(), threads, true, "region_bake_trail_tiles")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for m in range(out.size()):
			job.call(m)
	return out


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
			var slots: Array = _tiles(surface, bounds, network.get_data(), threads, progress, cancelled)
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


static func _r7_summaries(tried: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in tried:
		var ids: Array = entry.r7_excluded.keys()
		ids.sort()
		out.append({"round": entry.round, "is_valid": entry.is_valid, "reason_code": entry.reason_code, "score_before": entry.score_before,
			"score_after": entry.get("score_after", []), "r7_excluded": ids})
	return out


## Every tile of the region (optionally threaded; each result lands in its own
## slot dictionary, so order and thread count do not matter).
static func _tiles(surface: RefCounted, bounds: Dictionary, data: Dictionary, threads: int, progress: Callable, cancelled: Callable = Callable()) -> Array:
	var piece_class: Dictionary = {}
	for piece: Dictionary in data.pieces:
		piece_class[piece.id] = piece.info.route_class
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


## Vegetation of every tile, in tile order (each job writes its own slot).
static func _vegetation(planner: RefCounted, slots: Array, threads: int) -> Array:
	var out: Array = []
	out.resize(slots.size())
	var job := func(k: int) -> void:
		out[k] = planner.tile(slots[k].tx, slots[k].tz)
	if threads > 1:
		var group: int = WorkerThreadPool.add_group_task(job, slots.size(), threads, true, "region_bake_vegetation")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(slots.size()):
			job.call(k)
	return out


## Instance counts per kind and a content digest (order: tiles, kinds).
static func _vegetation_summary(vegetation: Array) -> Dictionary:
	var counts: Dictionary = {}
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for tile: Dictionary in vegetation:
		for kind: String in Vegetation.KINDS:
			var values: PackedFloat32Array = tile[kind]
			counts[kind] = counts.get(kind, 0) + values.size() / 5
			ctx.update(("%s:%d;" % [kind, values.size()]).to_utf8_buffer())
			if not values.is_empty():
				ctx.update(values.to_byte_array())
	return {"model": Vegetation.MODEL, "counts": counts, "digest": ctx.finish().hex_encode()}


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6


static func _report(progress: Callable, stage: String, fraction: float) -> void:
	if progress.is_valid():
		progress.call(stage, fraction)


## One tile: fine arrays (region-local origin), per-triangle layer and patch,
## coarse 16 m LOD arrays, content hash. Writes into `slot` only.
static func _tile(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, slot: Dictionary) -> void:
	var tile: Dictionary = Renderer.tile_arrays(surface, slot.tx, slot.tz)
	_finish_slot(surface, bounds, piece_class, slot, tile, [])


## Slot of built tile arrays: per-triangle layer and patch, origin, coarse
## LOD (given, or computed when empty), content hash. Writes into `slot` only.
static func _finish_slot(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, slot: Dictionary, tile: Dictionary, coarse: Array) -> void:
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
	_patch_order(slot)
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
static func _patch_order(slot: Dictionary) -> void:
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
