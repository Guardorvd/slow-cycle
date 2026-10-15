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
## Stages (each its own script, so each has its own source closure for dev
## stage reuse, RegionStageCache): RegionBakeGround (upstream, network, R7,
## tiles) -> RegionBakeTrails (trail publication) -> finish() here (bridges,
## water, vegetation, spawn, manifest). A full bake runs them in sequence.

const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Trails = preload("res://scripts/world/region/region_bake_trails.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Bridges = preload("res://scripts/world/region/bridge_deck_builder.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Graph = preload("res://scripts/world/region/region_route_graph.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const SCHEMA := "slow_cycle.region_bake/1"
const TILE_M: int = Ground.TILE_M
const TILES: int = Ground.TILES
const PATCH_M: float = Ground.PATCH_M
const LAYER_ROAD: int = Ground.LAYER_ROAD
const LAYER_ROUGH: int = Ground.LAYER_ROUGH
const LAYER_TERRAIN: int = Ground.LAYER_TERRAIN
## Bucket order of triangles inside a collision patch (runtime patch bodies).
const PATCH_LAYERS: Array[int] = [LAYER_TERRAIN, LAYER_ROAD, LAYER_ROUGH]


static func bake(seed_value: int, region: Vector2i, options: Dictionary = {}, progress: Callable = Callable()) -> Dictionary:
	return Synth.off_main_thread(func() -> Dictionary: return _bake(seed_value, region, options, progress))


static func _bake(seed_value: int, region: Vector2i, options: Dictionary, progress: Callable) -> Dictionary:
	var timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	_report(progress, "upstream", 0.0)
	var up: Dictionary = Ground.upstream(seed_value, region)
	timings["upstream_s"] = _lap(t)
	var cancelled: Callable = options.get("cancelled", Callable())
	var stopped := {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
	if cancelled.is_valid() and cancelled.call():
		return stopped
	var ground: Dictionary = ground_stage(seed_value, region, up, options, progress, timings)
	if not ground.is_valid:
		return ground
	if cancelled.is_valid() and cancelled.call():
		return stopped
	var trailed: Dictionary = trail_stage(seed_value, region, up, ground, options, progress, timings)
	return finish(seed_value, region, up, ground, trailed, options, progress, timings)


## Ground stage products: {is_valid, network, surface, slots (prototype-off),
## meta (plain record for the manifest), graph, route_plan (objects; absent
## after a stage reload)} or the failure record of RegionBakeGround.build.
static func ground_stage(seed_value: int, region: Vector2i, up: Dictionary, options: Dictionary, progress: Callable, timings: Dictionary) -> Dictionary:
	var made: Dictionary = Ground.build(seed_value, region, up, options, progress, timings)
	if not made.is_valid:
		return made
	var chosen: Dictionary = made.chosen
	var meta := {"graph_signature": chosen.graph.signature(), "plan_signature": chosen.plan.signature(), "chosen_round": chosen.round, "network_best_round": made.built.round,
		"rounds": _round_summaries(made.built.rounds), "r7_excluded": chosen.excluded, "r7_rounds": _r7_summaries(made.tried)}
	return {"is_valid": true, "reason_code": "", "network": chosen.network, "surface": chosen.surface, "slots": chosen.slots, "meta": meta, "graph": chosen.graph,
		"route_plan": chosen.plan, "rounds_raw": made.built.rounds}


## Trail stage products on the ground stage: {network, surface, slots, report
## (the manifest "trails" record; {} without options.trail_config),
## surface_trails, refined}.
static func trail_stage(seed_value: int, region: Vector2i, up: Dictionary, ground: Dictionary, options: Dictionary, progress: Callable, timings: Dictionary) -> Dictionary:
	var network: RefCounted = ground.network
	var unchanged := {"network": network, "surface": ground.surface, "slots": ground.slots, "report": {}, "surface_trails": [], "refined": []}
	if options.has("trail_config") and network.get_data().pieces.is_empty():
		# No road to join: trails are not planned; the empty network stays the
		# recorded result (the runtime reports ERR_REGION_NO_NETWORK).
		unchanged.report = {"config_sha256": JSON.stringify(options.trail_config, "", true).sha256_text(), "procedural": TrailPolicy.is_procedural(options.trail_config),
			"published": [], "rejected": [{"id": "", "reason_code": "ERR_REGION_NO_NETWORK", "detail": {"stage": "network"}}]}
		return unchanged
	if not options.has("trail_config"):
		return unchanged
	var t: int = Time.get_ticks_usec()
	_report(progress, "trails", 0.91)
	var made: Dictionary = Trails.publish(options.trail_config, seed_value, region, network, ground.surface, up.field, up.bounds, ground.slots, int(options.get("threads", 1)))
	timings["trails_s"] = _lap(t)
	return made


## Bridges, water, vegetation, spawn and the manifest on the trail stage.
static func finish(seed_value: int, region: Vector2i, up: Dictionary, ground: Dictionary, trailed: Dictionary, options: Dictionary, progress: Callable,
		timings: Dictionary) -> Dictionary:
	var cancelled: Callable = options.get("cancelled", Callable())
	var stopped := {"is_valid": false, "reason_code": "ERR_BAKE_CANCELLED"}
	var threads: int = int(options.get("threads", 1))
	var bounds: Dictionary = up.bounds
	var network: RefCounted = trailed.network
	var surface: RefCounted = trailed.surface
	var slots: Array = trailed.slots
	var data: Dictionary = network.get_data()
	var t: int = Time.get_ticks_usec()
	_report(progress, "bridges_water", 0.92)
	var ground_height := func(x: float, z: float) -> float:
		var h: Dictionary = surface.sample_height(x + bounds.min_x, z + bounds.min_z)
		return h.height_m if h.is_valid else NAN
	var bridges: Dictionary = Bridges.build(data, ground_height)
	var water: Dictionary = _water(up.hydro.plan)
	timings["bridges_water_s"] = _lap(t)
	if cancelled.is_valid() and cancelled.call():
		return stopped
	t = Time.get_ticks_usec()
	_report(progress, "vegetation", 0.94)
	var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, surface)
	if not flora.is_valid:
		return {"is_valid": false, "reason_code": flora.reason_code, "rounds": ground.get("rounds_raw", ground.meta.rounds)}
	var vegetation: Array = _vegetation(flora.planner, slots, threads)
	timings["vegetation_s"] = _lap(t)
	var spawn: Dictionary = _spawn(data)
	var meta: Dictionary = ground.meta
	var manifest: Dictionary = {"schema": SCHEMA, "seed": seed_value, "region": [region.x, region.y], "origin": [bounds.min_x, bounds.min_z],
		"region_signature": up.plan.signature(), "hydrology_signature": up.hydro.plan.signature(), "network_digest": network.digest(), "graph_signature": meta.graph_signature,
		"plan_signature": meta.plan_signature, "chosen_round": meta.chosen_round, "network_best_round": meta.network_best_round, "rounds": meta.rounds, "metrics": data.metrics,
		"tiles": [], "timings_s": timings, "r7_excluded": meta.r7_excluded, "r7_rounds": meta.r7_rounds,
		"bridges": bridges.decks.size(), "threads": threads, "terrain_kernel": "csharp" if Eval.kernel_active() else "gdscript"}
	if options.has("trail_config"):
		manifest["trails"] = trailed.report
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
		"surface": surface, "terrain": up.terrain, "hydrology": up.hydro.plan, "field": up.field, "plan": up.plan, "graph": ground.get("graph")}


## BC1 / BC2 trail publication (RegionBakeTrails.publish; kept for callers).
static func _trails(config: Variant, seed_value: int, region: Vector2i, network: RefCounted, surface: RefCounted, field: RefCounted, bounds: Dictionary, slots: Array,
		threads: int) -> Dictionary:
	return Trails.publish(config, seed_value, region, network, surface, field, bounds, slots, threads)


## Patch order of a tile slot (RegionBakeGround.patch_order; kept for callers).
static func _patch_order(slot: Dictionary) -> void:
	Ground.patch_order(slot)


static func _r7_summaries(tried: Array) -> Array:
	var out: Array = []
	for entry: Dictionary in tried:
		var ids: Array = entry.r7_excluded.keys()
		ids.sort()
		out.append({"round": entry.round, "is_valid": entry.is_valid, "reason_code": entry.reason_code, "score_before": entry.score_before,
			"score_after": entry.get("score_after", []), "r7_excluded": ids})
	return out


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
			"seconds": r.get("seconds", {}), "r6_timings": r.get("r6_timings", {}), "r6_edge_work": r.get("r6_edge_work", {}), "r5_work": r.get("r5_work", {}),
			"r6_reasons": r.get("r6_reasons", []), "component_length_m": m.get("component_length_m", 0.0), "cycles": m.get("cycles", 0), "classes": m.get("classes", {})})
	return out
