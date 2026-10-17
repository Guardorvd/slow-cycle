extends SceneTree
## GEN2-S S1 dev probe: builds a window of SurfaceBlocks (128 m, 0.5 m grid)
## on the cached ground stage of a region with one realized trail and one
## SHAPED turn platform, and checks/measures the block data. Never a
## production path; the bake, its caches and the runtime are not touched.
##
##   godot --headless --path . --script res://tools/dev/surface_block_probe.gd -- \
##     --seed=184729 --region=0,0 --config=res://resources/regions/bc1_trail_184729.json \
##     [--blocks=17,21,3,3] [--threads=4]
##
## Checks (each PASS / FAIL in the summary):
##   determinism  the window built on N threads and on 1 thread: equal digests;
##   seams        shared block edges equal bit for bit;
##   composition  at sample points off every operation the block equals the
##                design surface, on road planes the road height (by rule);
##   grid_error   |bilinear(block) - exact composition| at cell centres, per
##                material: REPORTED, no limit (Game Director 2026-10-17: the
##                0.5 m grid's softened creases are accepted; the ride judges
##                them; the preliminary 0.02 m trail limit is withdrawn);
##   incremental  the platform moved: only blocks of its old and new
##                rectangles are rebuilt and the result equals a full rebuild.
## Outputs in user://surface_block_probe/<name>/: summary JSON, map PNG.

const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Ops = preload("res://scripts/world/surface/surface_ops.gd")
const Block = preload("res://scripts/world/surface/surface_block.gd")
const Section = preload("res://scripts/world/surface/surface_section.gd")

const OUT_ROOT := "user://surface_block_probe"
const MOVE_M := Vector2(4.0, 0.0)

var _args: Dictionary = {}


func _initialize() -> void:
	_args = {"seed": 184729, "region": Vector2i.ZERO, "threads": 4, "config": "res://resources/regions/bc1_trail_184729.json",
		"blocks": [17, 21, 3, 3], "name": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_args.seed = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			_args.region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--threads="):
			_args.threads = maxi(1, arg.substr(10).to_int())
		elif arg.begins_with("--config="):
			_args.config = arg.substr(9)
		elif arg.begins_with("--blocks="):
			_args.blocks = Array(arg.substr(9).split(",")).map(func(v: String) -> int: return v.to_int())
		elif arg.begins_with("--name="):
			_args.name = arg.substr(7)
	if _args.name.is_empty():
		_args.name = "%d_%d_%d" % [_args.seed, _args.region.x, _args.region.y]
	var out_dir: String = ProjectSettings.globalize_path(OUT_ROOT.path_join(_args.name))
	DirAccess.make_dir_recursive_absolute(out_dir)
	var t0: int = Time.get_ticks_usec()
	var made: Dictionary = Synth.off_main_thread(func() -> Dictionary: return _work(out_dir))
	made["total_s"] = _lap(t0)
	made.erase("_flora")
	var path: String = out_dir.path_join("summary.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(made, "\t"))
	f.close()
	print("SURFACE_SUMMARY ", path, " total_s=%.2f" % made.total_s, " exit=", made.get("exit_code", 1))
	quit(int(made.get("exit_code", 1)))


func _work(out_dir: String) -> Dictionary:
	var prep: Dictionary = Section.prepare(_args.seed, _args.region, _args.config, _args.threads)
	if not prep.is_valid:
		return {"exit_code": 1, "reason_code": prep.reason_code, "detail": prep.get("detail", {}), "stage": prep.stage}
	var timings: Dictionary = prep.timings
	var t: int
	var ground: Dictionary = prep.ground
	var trails: Array = prep.trails
	var site: Dictionary = prep.site
	var platform: Dictionary = prep.platform
	var piece_class: Dictionary = prep.piece_class
	var ops: RefCounted = prep.ops
	print("SURFACE_SITE ", JSON.stringify({"platform": [snappedf(site.centre.x, 0.1), snappedf(site.centre.y, 0.1)], "turn_deg": snappedf(site.turn_deg, 0.1), "s_m": snappedf(site.s_m, 0.1)}))
	var ids: Array = Section.block_ids(_args.blocks)
	var out := {"seed": _args.seed, "region": [_args.region.x, _args.region.y], "threads": _args.threads, "block_m": Block.SIZE_M, "step_m": Block.STEP_M,
		"blocks": ids.map(func(v: Vector2i) -> Array: return [v.x, v.y]), "platform": {"centre": [site.centre.x, site.centre.y], "turn_deg": site.turn_deg, "s_m": site.s_m},
		"operations": ops.operations().map(func(op: Dictionary) -> Dictionary: return {"kind": op.kind, "id": op.id, "rect": [op.rect.position.x, op.rect.position.y, op.rect.size.x, op.rect.size.y]}),
		"timings_s": timings, "checks": {}}
	# Build on N threads, then on 1 thread.
	t = Time.get_ticks_usec()
	var blocks: Array = Section.build(ops, ids, _args.threads)
	timings["build_threads_s"] = _lap(t)
	for b: Dictionary in blocks:
		if not b.is_valid:
			out["exit_code"] = 1
			out["reason_code"] = b.reason_code
			out["detail"] = b.get("detail", {})
			return out
	t = Time.get_ticks_usec()
	var single: Array = Section.build(ops, ids, 1)
	timings["build_one_thread_s"] = _lap(t)
	timings["per_block_one_thread_s"] = timings.build_one_thread_s / ids.size()
	var checks: Dictionary = out.checks
	var same: bool = true
	for k in range(ids.size()):
		same = same and blocks[k].digest == single[k].digest
	checks["determinism"] = {"verdict": "PASS" if same else "FAIL", "threads": [_args.threads, 1]}
	checks["seams"] = _seams(blocks, ids)
	checks["composition"] = _composition(blocks, ids, ground.surface, ops)
	t = Time.get_ticks_usec()
	checks["grid_error"] = _grid_error(blocks, ops)
	timings["grid_error_s"] = _lap(t)
	checks["incremental"] = _incremental(ground.surface, trails, platform, piece_class, ids, blocks, timings)
	_vegetation_checks(prep, blocks, ids, checks, timings, out)
	var materials := {"GRASS": 0, "ROAD": 0, "ROUGH_ROAD": 0, "TRAIL": 0}
	for b: Dictionary in blocks:
		for m: int in b.material:
			materials[Ops.Cover.keys()[m]] += 1
	out["samples_by_material"] = materials
	out["digests"] = blocks.map(func(b: Dictionary) -> String: return b.digest.left(16))
	t = Time.get_ticks_usec()
	_map(blocks, ids, out_dir.path_join("map.png"), site.centre, out.get("_flora", []))
	out.erase("_flora")
	timings["map_s"] = _lap(t)
	var ok: bool = true
	for key: String in checks:
		ok = ok and checks[key].verdict in ["PASS", "REPORTED"]
		print("SURFACE_CHECK ", key, " ", JSON.stringify(checks[key]))
	print("SURFACE_TIMINGS ", JSON.stringify(timings))
	out["exit_code"] = 0 if ok else 2
	return out


func _seams(blocks: Array, ids: Array) -> Dictionary:
	var at: Dictionary = {}
	for k in range(ids.size()):
		at[ids[k]] = blocks[k]
	var pairs: int = 0
	var bad: int = 0
	var n: int = Block.N
	for id: Vector2i in at:
		var b: Dictionary = at[id]
		if at.has(id + Vector2i(1, 0)):
			var r: Dictionary = at[id + Vector2i(1, 0)]
			pairs += 1
			for j in range(n):
				if b.heights[j * n + n - 1] != r.heights[j * n] or b.material[j * n + n - 1] != r.material[j * n]:
					bad += 1
		if at.has(id + Vector2i(0, 1)):
			var d: Dictionary = at[id + Vector2i(0, 1)]
			pairs += 1
			for i in range(n):
				if b.heights[(n - 1) * n + i] != d.heights[i] or b.material[(n - 1) * n + i] != d.material[i]:
					bad += 1
	return {"verdict": "PASS" if bad == 0 and pairs > 0 else "FAIL", "edges": pairs, "mismatched_samples": bad}


## Every 7th sample of every block: off every operation's rectangle the block
## height equals the design surface (float32 of it); on road planes too.
func _composition(blocks: Array, ids: Array, surface: RefCounted, ops: RefCounted) -> Dictionary:
	var checked: int = 0
	var off_ops: int = 0
	var on_road: int = 0
	var worst: float = 0.0
	var all_ops: Array = ops.operations()
	var n: int = Block.N
	for b: Dictionary in blocks:
		for q in range(0, n * n, 7):
			var x: float = b.origin.x + (q % n) * Block.STEP_M
			var z: float = b.origin.y + (q / n) * Block.STEP_M
			var s: Dictionary = surface.sample_surface(x, z)
			var road: bool = s.kind == "ROAD"
			var inside: bool = false
			for op: Dictionary in all_ops:
				inside = inside or op.rect.has_point(Vector2(x, z))
			if inside and not road:
				continue
			checked += 1
			off_ops += 0 if road else 1
			on_road += 1 if road else 0
			var expected: float = PackedFloat32Array([s.height_m])[0]
			worst = maxf(worst, absf(b.heights[q] - expected))
	return {"verdict": "PASS" if worst <= 0.001 and checked > 0 else "FAIL", "samples": checked, "off_operations": off_ops, "on_road": on_road, "max_abs_m": worst}


## |bilinear(block) - exact| at cell centres: every cell whose corners are
## not all grass, every 4th otherwise. Per class: max, p99, count.
func _grid_error(blocks: Array, ops: RefCounted) -> Dictionary:
	var by: Dictionary = {}
	var worst: Dictionary = {}
	var n: int = Block.N
	for b: Dictionary in blocks:
		var touching: Array = ops.touching(Rect2(b.origin, Vector2(Block.SIZE_M, Block.SIZE_M)))
		for j in range(n - 1):
			for i in range(n - 1):
				var q: int = j * n + i
				var m: Array = [b.material[q], b.material[q + 1], b.material[q + n], b.material[q + n + 1]]
				var cls: String = "GRASS"
				if Ops.Cover.TRAIL in m:
					var kinds: Array = _ops_at(touching, b.origin + Vector2(i + 0.5, j + 0.5) * Block.STEP_M)
					cls = "TRAIL_PLATFORM" if "PLATFORM" in kinds else ("TRAIL_BENCH" if "BENCH" in kinds else "TRAIL")
					if m.count(Ops.Cover.TRAIL) < 4:
						cls += "_EDGE"
				elif Ops.Cover.ROAD in m or Ops.Cover.ROUGH_ROAD in m:
					cls = "ROAD" if m.count(Ops.Cover.ROAD) + m.count(Ops.Cover.ROUGH_ROAD) == 4 else "ROAD_EDGE"
				if cls == "GRASS" and (i % 4 != 0 or j % 4 != 0):
					continue
				var x: float = b.origin.x + (i + 0.5) * Block.STEP_M
				var z: float = b.origin.y + (j + 0.5) * Block.STEP_M
				var exact: Dictionary = ops.sample(x, z, touching)
				if not by.has(cls):
					by[cls] = PackedFloat32Array()
					worst[cls] = {"error_m": -1.0}
				var e: float = absf(Block.height_at(b, x, z) - exact.height_m)
				by[cls].append(e)
				if e > worst[cls].error_m:
					worst[cls] = {"error_m": snappedf(e, 0.0001), "at": [x, z], "ops": _ops_at(touching, Vector2(x, z))}
	var out := {}
	for cls: String in by:
		var v: PackedFloat32Array = by[cls]
		v.sort()
		out[cls] = {"count": v.size(), "max_m": snappedf(v[v.size() - 1], 0.0001), "p99_m": snappedf(v[int(0.99 * (v.size() - 1))], 0.0001),
			"mean_m": snappedf(_mean(v), 0.0001), "worst": worst[cls]}
	var trail_max: float = -1.0
	for cls: String in out:
		if cls.begins_with("TRAIL"):
			trail_max = maxf(trail_max, out[cls].max_m)
	trail_max = INF if trail_max < 0.0 else trail_max
	out["verdict"] = "REPORTED"
	out["trail_max_m"] = trail_max
	return out


func _incremental(surface: RefCounted, trails: Array, platform: Dictionary, piece_class: Dictionary, ids: Array, blocks: Array, timings: Dictionary) -> Dictionary:
	var moved: Dictionary = platform.duplicate()
	moved.centre = platform.centre + MOVE_M
	var t: int = Time.get_ticks_usec()
	var made: Dictionary = Ops.create(surface, trails, [moved], piece_class)
	if not made.is_valid:
		return {"verdict": "FAIL", "reason_code": made.reason_code}
	var ops2: RefCounted = made.ops
	var r: float = platform.radius_m + platform.taper_m
	var old_rect := Rect2(platform.centre - Vector2(r, r), Vector2(2 * r, 2 * r))
	var new_rect := Rect2(moved.centre - Vector2(r, r), Vector2(2 * r, 2 * r))
	var redo: Array = []
	for id: Vector2i in ids:
		var rect := Rect2(Vector2(id) * Block.SIZE_M, Vector2(Block.SIZE_M, Block.SIZE_M))
		if rect.intersects(old_rect) or rect.intersects(new_rect):
			redo.append(id)
	var partial: Array = Section.build(ops2, redo, _args.threads)
	timings["incremental_s"] = _lap(t)
	var full: Array = Section.build(ops2, ids, _args.threads)
	var by_id: Dictionary = {}
	for b: Dictionary in partial:
		by_id[Vector2i(b.bx, b.bz)] = b
	var mismatched: Array = []
	var changed: int = 0
	for k in range(ids.size()):
		var kept: Dictionary = by_id.get(ids[k], blocks[k])
		if kept.digest != full[k].digest:
			mismatched.append([ids[k].x, ids[k].y])
		if full[k].digest != blocks[k].digest:
			changed += 1
	return {"verdict": "PASS" if mismatched.is_empty() and changed > 0 and changed <= redo.size() else "FAIL", "moved_m": [MOVE_M.x, MOVE_M.y],
		"rebuilt_blocks": redo.size(), "changed_blocks": changed, "mismatched_vs_full": mismatched, "seconds": timings.incremental_s}


func _map(blocks: Array, ids: Array, path: String, mark: Vector2, flora: Array = []) -> void:
	var n: int = Block.N - 1
	var lo := Vector2i(ids[0])
	var hi := Vector2i(ids[ids.size() - 1])
	var w: int = (hi.x - lo.x + 1) * n
	var h: int = (hi.y - lo.y + 1) * n
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var colors: Array[Color] = [Color(0.36, 0.55, 0.28), Color(0.45, 0.45, 0.47), Color(0.62, 0.55, 0.42), Color(0.78, 0.6, 0.35)]
	var light := Vector3(-1, 2, -1).normalized()
	for b: Dictionary in blocks:
		var ox: int = (b.bx - lo.x) * n
		var oz: int = (b.bz - lo.y) * n
		for j in range(n):
			for i in range(n):
				var q: int = j * Block.N + i
				var nx: float = (b.heights[q] - b.heights[q + 1]) / Block.STEP_M
				var nz: float = (b.heights[q] - b.heights[q + Block.N]) / Block.STEP_M
				var shade: float = clampf(Vector3(nx, 1.0, nz).normalized().dot(light), 0.2, 1.0)
				img.set_pixel(ox + i, oz + j, colors[b.material[q]] * (0.35 + 0.75 * shade))
	var dot := {"pine": Color(0.05, 0.25, 0.1), "birch": Color(0.2, 0.45, 0.1), "autumn": Color(0.85, 0.45, 0.1), "shrub": Color(0.15, 0.35, 0.15), "grass": Color(0.55, 0.7, 0.3), "rock": Color(0.6, 0.6, 0.6)}
	for d: Dictionary in flora:
		for kind: String in dot:
			var v: PackedFloat32Array = d[kind]
			for q in range(v.size() / 5):
				var px: int = int((v[5 * q] - lo.x * Block.SIZE_M) / Block.STEP_M)
				var pz: int = int((v[5 * q + 2] - lo.y * Block.SIZE_M) / Block.STEP_M)
				var rad: int = 3 if kind in ["pine", "birch", "autumn"] else 2
				for dz in range(-rad, rad + 1):
					for dx in range(-rad, rad + 1):
						if dx * dx + dz * dz <= rad * rad and px + dx >= 0 and pz + dz >= 0 and px + dx < w and pz + dz < h:
							img.set_pixel(px + dx, pz + dz, dot[kind])
	var mx: int = int((mark.x - lo.x * Block.SIZE_M) / Block.STEP_M)
	var mz: int = int((mark.y - lo.y * Block.SIZE_M) / Block.STEP_M)
	for d in range(-12, 13):
		for p: Vector2i in [Vector2i(mx + d, mz), Vector2i(mx, mz + d)]:
			if p.x >= 0 and p.y >= 0 and p.x < w and p.y < h:
				img.set_pixelv(p, Color(0.9, 0.1, 0.1))
	img.save_png(path)


# --- S3: vegetation -----------------------------------------------------------

const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Flora = preload("res://scripts/world/surface/surface_block_vegetation.gd")


func _vegetation_checks(prep: Dictionary, blocks: Array, ids: Array, checks: Dictionary, timings: Dictionary, out: Dictionary) -> void:
	var planner: RefCounted = prep.vegetation_planner
	var veg: Dictionary = Section.vegetation(planner, blocks, ids, _args.threads)
	timings["vegetation_candidates_s"] = veg.candidates_s
	timings["vegetation_place_s"] = veg.place_s
	var one: Dictionary = Section.vegetation(planner, blocks, ids, 1)
	checks["vegetation_determinism"] = {"verdict": "PASS" if _flora_hash(veg.placed) == _flora_hash(one.placed) and _flora_hash(veg.candidates) == _flora_hash(one.candidates) else "FAIL", "threads": [_args.threads, 1]}
	var counts: Dictionary = {}
	for kind: String in Vegetation.KINDS:
		counts[kind] = 0
		for placed: Dictionary in veg.placed:
			counts[kind] += placed[kind].size() / 5
	out["vegetation_counts"] = counts
	checks["vegetation_clear"] = _flora_clear(prep, veg.placed)
	checks["vegetation_incremental"] = _flora_incremental(prep, blocks, ids, veg, timings)
	checks["vegetation_vs_planner"] = _flora_vs_planner(prep, veg.placed, ids, timings)
	out["_flora"] = veg.placed


## Every trunk / rock collider and shrub clear of the riding band, the
## platform and the road planes (independent of the cover raster: the
## realized trail lines and the design surface).
func _flora_clear(prep: Dictionary, placed: Array) -> Dictionary:
	var surface: RefCounted = prep.ground.surface.with_trails(prep.trails)
	var bad: Array = []
	var checked: int = 0
	for blockflora: Dictionary in placed:
		for kind: String in ["pine", "birch", "autumn", "rock", "shrub"]:
			var v: PackedFloat32Array = blockflora[kind]
			for q in range(v.size() / 5):
				var x: float = v[5 * q]
				var z: float = v[5 * q + 2]
				var r: float = Vegetation.TRUNK_RADIUS.get(kind, 0.3) * v[5 * q + 4]
				checked += 1
				var near: Dictionary = surface.trail_near(x, z, r)
				var on_band: bool = not near.is_empty() and near.distance <= near.half_width + r
				var on_platform: bool = Vector2(x, z).distance_to(prep.site.centre) <= prep.platform.radius_m + r
				var on_road: bool = not prep.ground.surface.road_owner(x, z).is_empty()
				if on_band or on_platform or on_road:
					bad.append({"kind": kind, "at": [snappedf(x, 0.1), snappedf(z, 0.1)], "band": on_band, "platform": on_platform, "road": on_road})
	return {"verdict": "PASS" if bad.is_empty() and checked > 0 else "FAIL", "checked": checked, "violations": bad.slice(0, 10), "violation_count": bad.size()}


## The platform moved: re-place only blocks within the largest clearance of
## its old / new rectangles (candidates reused) == a full re-placement.
func _flora_incremental(prep: Dictionary, blocks: Array, ids: Array, veg: Dictionary, timings: Dictionary) -> Dictionary:
	var moved: Dictionary = prep.platform.duplicate()
	moved.centre = prep.platform.centre + MOVE_M
	var made: Dictionary = Ops.create(prep.ground.surface, prep.trails, [moved], prep.piece_class)
	var blocks2: Array = Section.build(made.ops, ids, _args.threads)
	var r: float = prep.platform.radius_m + prep.platform.taper_m + Vegetation.CLEAR_M.tree
	var reach := Rect2(prep.platform.centre - Vector2(r, r), Vector2(2 * r, 2 * r)).merge(Rect2(moved.centre - Vector2(r, r), Vector2(2 * r, 2 * r)))
	var redo: Array = []
	var redo_k: Array = []
	for k in range(ids.size()):
		if Rect2(Vector2(ids[k]) * Block.SIZE_M, Vector2(Block.SIZE_M, Block.SIZE_M)).grow(Vegetation.CLEAR_M.tree).intersects(reach):
			redo.append(ids[k])
			redo_k.append(k)
	var t: int = Time.get_ticks_usec()
	var sub_blocks: Array = []
	var sub_cands: Array = []
	for k: int in redo_k:
		sub_cands.append(veg.candidates[k])
	var partial: Dictionary = Section.vegetation(prep.vegetation_planner, blocks2, redo, _args.threads, sub_cands)
	timings["vegetation_incremental_s"] = _lap(t)
	var full: Dictionary = Section.vegetation(prep.vegetation_planner, blocks2, ids, _args.threads, veg.candidates)
	var merged: Array = veg.placed.duplicate()
	for m in range(redo_k.size()):
		merged[redo_k[m]] = partial.placed[m]
	var same: bool = _flora_hash(merged) == _flora_hash(full.placed)
	return {"verdict": "PASS" if same else "FAIL", "replaced_blocks": redo.size(), "seconds": timings.vegetation_incremental_s,
		"changed_blocks": range(ids.size()).filter(func(k: int) -> bool: return _flora_hash([veg.placed[k]]) != _flora_hash([full.placed[k]])).size()}


## Information: the current planner's tile (trails surface) inside the window,
## kind by kind: same positions kept / only here / only in the planner.
func _flora_vs_planner(prep: Dictionary, placed: Array, ids: Array, timings: Dictionary) -> Dictionary:
	var lo: Vector2 = Vector2(ids[0]) * Block.SIZE_M
	var window := Rect2(lo, Vector2(Vector2(ids[ids.size() - 1]) * Block.SIZE_M + Vector2(Block.SIZE_M, Block.SIZE_M) - lo))
	var made: Dictionary = Vegetation.create(prep.up.plan, prep.up.terrain, prep.up.hydro.plan, prep.ground.surface.with_trails(prep.trails))
	var bounds: Dictionary = prep.up.bounds
	var tiles: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	for x in [window.position.x, window.end.x - 1.0]:
		for z in [window.position.y, window.end.y - 1.0]:
			tiles[Vector2i(floori(x / Vegetation.TILE_M), floori(z / Vegetation.TILE_M))] = true
	var theirs: Dictionary = {}
	for tile: Vector2i in tiles:
		var got: Dictionary = made.planner.tile(tile.x, tile.y)
		for kind: String in Vegetation.KINDS:
			var v: PackedFloat32Array = got[kind]
			for q in range(v.size() / 5):
				var p := Vector2(v[5 * q] + bounds.min_x, v[5 * q + 2] + bounds.min_z)
				if window.has_point(p):
					theirs["%s@%.2f,%.2f" % [kind, p.x, p.y]] = v[5 * q + 1]
	timings["planner_tiles_s"] = _lap(t)
	var ours: Dictionary = {}
	for blockflora: Dictionary in placed:
		for kind: String in Vegetation.KINDS:
			var v: PackedFloat32Array = blockflora[kind]
			for q in range(v.size() / 5):
				ours["%s@%.2f,%.2f" % [kind, v[5 * q], v[5 * q + 2]]] = v[5 * q + 1]
	var both: int = 0
	var dy_max: float = 0.0
	for key: String in ours:
		if theirs.has(key):
			both += 1
			dy_max = maxf(dy_max, absf(ours[key] - theirs[key]))
	return {"verdict": "REPORTED", "planner_tiles": tiles.size(), "here": ours.size(), "planner": theirs.size(), "same_positions": both,
		"only_here": ours.size() - both, "only_planner": theirs.size() - both, "max_height_difference_m": snappedf(dy_max, 0.001)}


static func _flora_hash(lists: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for d: Dictionary in lists:
		for kind: String in Vegetation.KINDS:
			var bytes: PackedByteArray = d[kind].to_byte_array()
			ctx.update(bytes if not bytes.is_empty() else kind.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func _ops_at(ops: Array, p: Vector2) -> Array:
	return ops.filter(func(op: Dictionary) -> bool: return op.rect.has_point(p)).map(func(op: Dictionary) -> String: return op.kind)


static func _mean(v: PackedFloat32Array) -> float:
	var s: float = 0.0
	for x: float in v:
		s += x
	return s / maxf(v.size(), 1)


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
