extends RefCounted
## GEN2-S: the prototype section's inputs, shared by the dev probe and the dev
## ride (pure; no scene). Loads (or builds once and stores) the cached ground
## stage of a region, realizes the configured trails on its design surface,
## places one SHAPED turn platform and makes the SurfaceOps; builds blocks.

const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Stage = preload("res://scripts/world/region_stage_cache.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const Ops = preload("res://scripts/world/surface/surface_ops.gd")
const Block = preload("res://scripts/world/surface/surface_block.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Flora = preload("res://scripts/world/surface/surface_block_vegetation.gd")

const PLATFORM_RADIUS_M: float = 3.5
const PLATFORM_TAPER_M: float = 3.0
## Platform site: sharpest heading change over +-TURN_SPAN_M, at least
## SITE_CLEAR_M (along the line) from a BENCH and from the trail ends.
const TURN_SPAN_M: float = 6.0
const SITE_CLEAR_M: float = 15.0


## {is_valid, up, ground, trails, site, platform, piece_class, ops, timings,
## reason_code}.
static func prepare(seed_value: int, region: Vector2i, config_path: String, threads: int) -> Dictionary:
	var timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var up: Dictionary = Ground.upstream(seed_value, region)
	var options := {"threads": threads, "max_replans": Builder.MAX_REPLANS, "stop_rule": Builder.STOP_ROADS}
	var gkey: Dictionary = Stage.ground_key(seed_value, region, options)
	var ground: Dictionary = Stage.load_ground(gkey.key, seed_value, region, up)
	timings["ground_state"] = "reused" if ground.is_valid else "built"
	if not ground.is_valid:
		ground = Bake.ground_stage(seed_value, region, up, options, Callable(), {})
		if not ground.is_valid:
			return {"is_valid": false, "reason_code": ground.reason_code, "stage": "ground"}
		Stage.save_ground(gkey.key, seed_value, region, up, ground)
	timings["ground_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var parsed: Dictionary = Trail.parse(JSON.parse_string(FileAccess.get_file_as_string(config_path)))
	if not parsed.is_valid:
		return {"is_valid": false, "reason_code": parsed.reason_code, "detail": parsed.detail, "stage": "config"}
	var context := {"seed": seed_value, "region": region, "network": ground.network.get_data(), "surface": ground.surface, "field": up.field}
	var trails: Array = []
	for cfg: Dictionary in parsed.config.trails:
		var made: Dictionary = Trail.realize(cfg, parsed.config, context)
		if not made.is_valid:
			return {"is_valid": false, "reason_code": made.reason_code, "detail": made.detail, "stage": "trail"}
		trails.append(made.trail)
	timings["trails_s"] = _lap(t)
	var site: Dictionary = platform_site(trails[0], up.bounds)
	var platform := {"id": "platform:turn", "centre": site.centre, "radius_m": PLATFORM_RADIUS_M, "taper_m": PLATFORM_TAPER_M}
	var piece_class: Dictionary = Ground.piece_classes(ground.network.get_data())
	var made_ops: Dictionary = Ops.create(ground.surface, trails, [platform], piece_class)
	if not made_ops.is_valid:
		return {"is_valid": false, "reason_code": made_ops.reason_code, "detail": made_ops.detail, "stage": "ops"}
	var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, ground.surface)
	if not flora.is_valid:
		return {"is_valid": false, "reason_code": flora.reason_code, "stage": "vegetation"}
	return {"is_valid": true, "up": up, "ground": ground, "trails": trails, "site": site, "platform": platform, "piece_class": piece_class,
		"ops": made_ops.ops, "vegetation_planner": flora.planner, "timings": timings, "reason_code": ""}


static func block_ids(rect: Array) -> Array:
	var ids: Array = []
	for dz in range(rect[3]):
		for dx in range(rect[2]):
			ids.append(Vector2i(rect[0] + dx, rect[1] + dz))
	return ids


static func build(ops: RefCounted, ids: Array, threads: int) -> Array:
	var blocks: Array = []
	blocks.resize(ids.size())
	var job := func(k: int) -> void:
		blocks[k] = Block.build(ops, ids[k].x, ids[k].y)
	if threads > 1:
		var group: int = WorkerThreadPool.add_group_task(job, ids.size(), threads, true, "surface_blocks")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(ids.size()):
			job.call(k)
	return blocks


## Vegetation of blocks `ids` in two steps: {candidates: [per id], placed: [per
## id], candidates_s, place_s}. `cands` (optional, per id) reuses candidates.
static func vegetation(planner: RefCounted, blocks: Array, ids: Array, threads: int, cands: Array = []) -> Dictionary:
	var by_id: Dictionary = {}
	for b: Dictionary in blocks:
		by_id[Vector2i(b.bx, b.bz)] = b
	var t: int = Time.get_ticks_usec()
	var candidates: Array = cands.duplicate()
	if candidates.is_empty():
		candidates.resize(ids.size())
		var job := func(k: int) -> void:
			candidates[k] = Flora.candidates(planner, ids[k].x, ids[k].y)
		_run(job, ids.size(), threads)
	var candidates_s: float = _lap(t)
	t = Time.get_ticks_usec()
	var placed: Array = []
	placed.resize(ids.size())
	var place := func(k: int) -> void:
		placed[k] = Flora.place(candidates[k], by_id[ids[k]], by_id)
	_run(place, ids.size(), threads)
	return {"candidates": candidates, "placed": placed, "candidates_s": candidates_s, "place_s": _lap(t)}


static func _run(job: Callable, count: int, threads: int) -> void:
	if threads > 1:
		var group: int = WorkerThreadPool.add_group_task(job, count, threads, true, "surface_section")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for k in range(count):
			job.call(k)


static func platform_site(trail: Dictionary, bounds: Dictionary) -> Dictionary:
	var line: Dictionary = trail.line
	var n: int = line.s.size()
	var length: float = line.s[n - 1]
	var benches: Array = trail.get("operations", []).filter(func(op: Dictionary) -> bool: return op.kind == "BENCH")
	var best := {"turn_deg": -1.0}
	for k in range(n):
		var s: float = line.s[k]
		if s < SITE_CLEAR_M + TURN_SPAN_M or s > length - SITE_CLEAR_M - TURN_SPAN_M:
			continue
		var clear: bool = true
		for op: Dictionary in benches:
			clear = clear and (s < op.s0_m - SITE_CLEAR_M or s > op.s1_m + SITE_CLEAR_M)
		if not clear:
			continue
		var a: int = clampi(line.s.bsearch(s - TURN_SPAN_M), 1, n - 1)
		var b: int = clampi(line.s.bsearch(s + TURN_SPAN_M), 1, n - 1)
		var d0 := Vector2(line.x[k] - line.x[a - 1], line.z[k] - line.z[a - 1])
		var d1 := Vector2(line.x[b] - line.x[k], line.z[b] - line.z[k])
		if d0.length() < 1e-6 or d1.length() < 1e-6:
			continue
		var turn: float = absf(rad_to_deg(d0.angle_to(d1)))
		if turn > best.turn_deg:
			best = {"turn_deg": turn, "s_m": s, "centre": Vector2(line.x[k] + bounds.min_x, line.z[k] + bounds.min_z)}
	return best


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
