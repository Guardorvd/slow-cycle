class_name RegionBakeTrails
extends RefCounted

## Trail stage of RegionBake (pure; no scene, no I/O): BC1 configured trails
## or the BC2 procedural trail network realized on the ground-stage products
## (RegionBakeGround) and published atomically. Split out of RegionBake so the
## stage has its own source closure (dev stage reuse, RegionStageCache):
## bridges and vegetation do not reach this file. Same calls, same order as
## the former RegionBake steps. Results also carry what the published surface
## was built from (surface_trails: the trail records of with_trails;
## refined: tile indices of with_published), so a stage reload rebuilds the
## same surface. report.publication (GEN2-1) records the work of every
## publication attempt (counters and wall-clock seconds of its steps); it is
## a measurement only and never changes the products.

const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Renderer = preload("res://scripts/world/region/final_surface_tile_renderer.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Planner = preload("res://scripts/world/region/trail_network_planner.gd")
const TILE_M: int = Ground.TILE_M
## Bound on BC1 trail border-agreement passes (each adds border points).
const MAX_SEAM_PASSES: int = 12
## BC2: procedural proposals tried at publication before giving up a slot.
const MAX_PUBLISH_ATTEMPTS: int = 3


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
## {network, surface, slots, report: {config_sha256, published, rejected},
## surface_trails, refined}.
static func publish(config: Variant, seed_value: int, region: Vector2i, network: RefCounted, surface: RefCounted, field: RefCounted, bounds: Dictionary, slots: Array,
		threads: int) -> Dictionary:
	var context := {"seed": seed_value, "region": region, "network": network.get_data(), "surface": surface, "field": field}
	if TrailPolicy.is_procedural(config):
		return _procedural_trails(config, context, network, surface, bounds, slots, threads)
	var realized: Dictionary = Trail.realize_all(config, context)
	var report := {"config_sha256": JSON.stringify(config, "", true).sha256_text(), "published": [], "rejected": realized.rejected.duplicate(true)}
	var stats: Dictionary = _new_stats()
	var made: Dictionary = _publish_trails(realized.trails, report, context, network, surface, bounds, slots, threads, stats)
	made.report["publication"] = stats
	return made


## BC2: trails proposed by TrailNetworkPlanner (configuration TrailPolicy) on
## the published ground of the off tiles, each already realized on the
## published triangles of its zone. The planner's selection is published at
## once; a trail rejected there gives way to an alternate of its class clear
## of the published ones (at most MAX_PUBLISH_ATTEMPTS each). The published
## network must leave no trap (RealizedRoadNetwork.trail_graph strongly
## connected; ERR_TRAIL_TRAP otherwise); report.network is that graph.
static func _procedural_trails(config: Variant, context: Dictionary, network: RefCounted, surface: RefCounted, bounds: Dictionary, slots: Array, threads: int) -> Dictionary:
	var report := {"config_sha256": JSON.stringify(config, "", true).sha256_text(), "procedural": true, "published": [], "rejected": []}
	var unchanged := {"network": network, "surface": surface, "slots": slots, "report": report, "surface_trails": [], "refined": []}
	var parsed: Dictionary = TrailPolicy.parse(config)
	if not parsed.is_valid:
		report.rejected.append({"id": "", "reason_code": parsed.reason_code, "detail": parsed.detail})
		return unchanged
	var t: int = Time.get_ticks_usec()
	var planning := context.duplicate()
	planning["ground"] = Surface.published_ground(slots, bounds, TrailPolicy.GROUND_CELL_M, threads)
	planning["slots"] = slots
	var ground_s: float = _lap(t)
	var planned: Dictionary = Planner.plan(parsed.config, planning)
	report["planner"] = planned.report
	report.planner["ground_s"] = ground_s
	report.rejected.append_array(planned.rejected)
	var products: Dictionary = unchanged
	var stats: Dictionary = _new_stats()
	report["publication"] = stats
	# The whole selection at once (_publish_trails drops a trail that fails and
	# publishes the rest again without it).
	var made: Dictionary = _publish_trails(planned.trails, {"published": [], "rejected": []}, context, network, surface, bounds, slots, threads, stats)
	report.rejected.append_array(made.report.rejected)
	var done: Array = made.report.published.map(func(entry: Dictionary) -> String: return entry.id)
	var chosen: Array = planned.trails.filter(func(trail: Dictionary) -> bool: return trail.id in done)
	if not chosen.is_empty():
		products = made
	# A selected trail that failed gives way to an alternate of its class clear
	# of the published ones.
	for trail: Dictionary in planned.trails:
		if trail.id in done:
			continue
		var attempts: int = 0
		for option: Dictionary in planned.alternates:
			if attempts >= MAX_PUBLISH_ATTEMPTS:
				break
			if option.class_name != trail.class_name or chosen.any(func(other: Dictionary) -> bool: return other.id == option.id or not _clear_of(option, other)):
				continue
			attempts += 1
			var again: Dictionary = _publish_trails(chosen + [option], {"published": [], "rejected": []}, context, network, surface, bounds, slots, threads, stats)
			report.rejected.append_array(again.report.rejected)
			if again.report.published.size() == chosen.size() + 1:
				chosen.append(option)
				products = again
				break
	# No traps: every place of the riding graph reaches every other; trails
	# are given up from the last one until it holds (atomic: the rest are
	# published again without them).
	t = Time.get_ticks_usec()
	var graph: Dictionary = Network.trail_graph(products.network.get_data())
	stats.trap_check_s += _lap(t)
	while not graph.strongly_connected and not chosen.is_empty():
		var dropped: Dictionary = chosen.pop_back()
		report.rejected.append({"id": dropped.id, "reason_code": "ERR_TRAIL_TRAP", "detail": {"stage": "network", "traps": graph.traps}})
		products = unchanged if chosen.is_empty() else _publish_trails(chosen, {"published": [], "rejected": []}, context, network, surface, bounds, slots, threads, stats)
		t = Time.get_ticks_usec()
		graph = Network.trail_graph(products.network.get_data())
		stats.trap_check_s += _lap(t)
	report["network"] = graph
	var ids: Array = chosen.map(func(trail: Dictionary) -> String: return trail.id)
	report.published = products.report.published if not chosen.is_empty() else []
	for entry: Dictionary in report.published:
		var trail: Dictionary = chosen[ids.find(entry.id)]
		entry["origin"] = trail.origin
		entry["class"] = trail.class_name
		entry["purpose"] = trail.purpose
		entry["planner"] = {"score": trail.planner.score, "road_m": trail.planner.road_m, "gain_m": trail.planner.gain_m, "ports": trail.planner.ports}
		for key: String in ["drop_m", "turns", "steep_share", "return", "shape"]:
			if trail.planner.has(key):
				entry.planner[key] = trail.planner[key]
	report["alternates"] = (planned.trails + planned.alternates).map(func(trail: Dictionary) -> String: return trail.id).filter(func(id: String) -> bool: return not id in ids)
	return {"network": products.network, "surface": products.surface, "slots": products.slots, "report": report, "surface_trails": products.surface_trails,
		"refined": products.refined}


## Two trail lines keep TrailPolicy.TRAIL_CLEAR_M apart (sampled).
static func _clear_of(a: Dictionary, b: Dictionary) -> bool:
	for i in range(0, a.line.s.size(), 3):
		var p := Vector2(a.line.x[i], a.line.z[i])
		for j in range(0, b.line.s.size(), 3):
			if p.distance_to(Vector2(b.line.x[j], b.line.z[j])) < TrailPolicy.TRAIL_CLEAR_M:
				return false
	return true


## Publication of realized trails (BC1): shaped, tiles refined, finalized on
## the published triangles, joined to the network; see _trails. `stats`
## (_new_stats) accumulates the work of every call (measurement only).
static func _publish_trails(trails: Array, report: Dictionary, context: Dictionary, network: RefCounted, surface: RefCounted, bounds: Dictionary, slots: Array,
		threads: int, stats: Dictionary = {}) -> Dictionary:
	if stats.is_empty():
		stats.merge(_new_stats())
	stats.calls += 1
	var rejected: Array = report.rejected
	var unchanged := {"network": network, "surface": surface, "slots": slots, "report": report, "surface_trails": [], "refined": []}
	var piece_class: Dictionary = {}
	for piece: Dictionary in network.get_data().pieces:
		piece_class[piece.id] = piece.info.route_class
	while not trails.is_empty():
		stats.attempts += 1
		stats.trails_attempted += trails.size()
		var t: int = Time.get_ticks_usec()
		var indices: Array = _trail_tiles(trails, slots, bounds)
		stats.trail_tiles_s += _lap(t)
		t = Time.get_ticks_usec()
		# Benches are measured on the published pre-bench surface of their zone.
		var pre: RefCounted = surface.with_trails(trails).with_published(indices.map(func(k: int) -> Dictionary: return slots[k]))
		var shaped: Array = []
		for trail: Dictionary in trails:
			var made: Dictionary = Trail.shape(trail, pre)
			if made.is_valid:
				shaped.append(made.trail)
			else:
				rejected.append({"id": made.id, "reason_code": made.reason_code, "detail": made.detail})
		stats.shape_s += _lap(t)
		if shaped.size() < trails.size():
			trails = shaped
			continue
		trails = shaped
		var trail_surface: RefCounted = surface.with_trails(trails)
		var forced: Dictionary = {}
		var refined: Array = []
		var failure: Dictionary = {}
		var agreed: bool = false
		var memo: Dictionary = {}
		t = Time.get_ticks_usec()
		for attempt in range(MAX_SEAM_PASSES):
			stats.seam_passes += 1
			refined = _refine_tiles(trail_surface, bounds, piece_class, threads, slots, indices, forced, memo, stats)
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
		stats.refine_s += _lap(t)
		stats.max_tiles = maxi(stats.max_tiles, indices.size())
		stats.border_points = maxi(stats.border_points, forced.size())
		if failure.is_empty() and not agreed:
			failure = {"reason_code": "ERR_TRAIL_TILE", "tx": -1, "tz": -1, "detail": "no border agreement in %d passes" % MAX_SEAM_PASSES}
		if not failure.is_empty():
			for trail: Dictionary in trails:
				rejected.append({"id": trail.id, "reason_code": "ERR_TRAIL_UNRIDEABLE", "detail": {"stage": "published geometry", "reason": failure.get("reason_code", ""),
					"tile": [failure.tx, failure.tz], "note": str(failure.get("detail", ""))}})
			return unchanged
		t = Time.get_ticks_usec()
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
		stats.finalize_s += _lap(t)
		if kept.size() < trails.size():
			trails = kept
			continue
		t = Time.get_ticks_usec()
		var joined: Dictionary = network.with_trails(finished)
		stats.join_s += _lap(t)
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
		return {"network": joined.network, "surface": published, "slots": out_slots, "report": report, "surface_trails": trails, "refined": indices}
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
## _tiles; each job writes its own slot). A tile's refinement depends on
## `forced` only through the points on its border
## (FinalSurfaceTileRenderer.forced_on_border): `memo` (slot index -> {key,
## slot}, kept across the seam passes of one surface) returns the earlier
## result of a tile whose border points did not change instead of refining
## it again.
static func _refine_tiles(surface: RefCounted, bounds: Dictionary, piece_class: Dictionary, threads: int, slots: Array, indices: Array, forced: Dictionary,
		memo: Dictionary = {}, stats: Dictionary = {}) -> Array:
	var out: Array = []
	var keys: Array = []
	var todo: Array = []
	for m in range(indices.size()):
		var k: int = indices[m]
		var mine: Array = Renderer.forced_on_border(Vector2(slots[k].tx * TILE_M, slots[k].tz * TILE_M), forced)
		mine.sort()
		var key: String = var_to_str(mine)
		keys.append(key)
		if memo.has(k) and memo[k].key == key:
			out.append(memo[k].slot)
		else:
			out.append({"tx": slots[k].tx, "tz": slots[k].tz})
			todo.append(m)
	# Largest tiles first (each job writes its own slot, so order does not
	# change the result; it shortens the wait for the last, heaviest tile).
	var size_of := func(m: int) -> int: return (slots[indices[m]].arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	todo.sort_custom(func(a: int, b: int) -> bool: return size_of.call(a) > size_of.call(b) or (size_of.call(a) == size_of.call(b) and a < b))
	var job := func(n: int) -> void:
		var m: int = todo[n]
		var base: Dictionary = slots[indices[m]]
		var tile: Dictionary = Renderer.refine_arrays(surface, base.arrays, base.tx, base.tz, forced)
		Ground.finish_slot(surface, bounds, piece_class, out[m], tile, base.coarse)
		out[m]["border_points"] = tile.get("border_points", [])
	if threads > 1 and todo.size() > 1:
		var group: int = WorkerThreadPool.add_group_task(job, todo.size(), threads, true, "region_bake_trail_tiles")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for n in range(todo.size()):
			job.call(n)
	for m: int in todo:
		memo[indices[m]] = {"key": keys[m], "slot": out[m]}
	if not stats.is_empty():
		stats.tiles_refined += todo.size()
		stats.tiles_memo += indices.size() - todo.size()
	return out


## Publication work record (report.publication): calls of _publish_trails,
## attempts (one per realized set tried), trails in them, seam passes, tiles
## refined / taken from the seam memo, the largest tile set and border-point
## set of an attempt, and seconds of each step summed over all attempts.
static func _new_stats() -> Dictionary:
	return {"calls": 0, "attempts": 0, "trails_attempted": 0, "seam_passes": 0, "tiles_refined": 0, "tiles_memo": 0, "max_tiles": 0, "border_points": 0,
		"trail_tiles_s": 0.0, "shape_s": 0.0, "refine_s": 0.0, "finalize_s": 0.0, "join_s": 0.0, "trap_check_s": 0.0}


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
