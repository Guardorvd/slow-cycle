extends SceneTree
## GEN2-1 single-trail tool (dev; never a production path). Works on the
## ground stage of a region (RegionStageCache: network, R7 surface,
## prototype-off tiles; built and stored once when missing) and a trail set
## in the BC1 configuration schema (TrailRealization).
##   --mode=planner  the V1 planner (TrailNetworkPlanner, default policy) on
##                   the ground; lists its proposals; --pick=ID|CLASS|selected
##                   writes their configurations as one BC1 file (--name).
##   --mode=preview  line, profile and planned operations of every trail of
##                   --config on the design surface (TrailRealization.realize
##                   screening); profile CSV, top-down PNG, JSON summary.
##                   A preview pass is not a ride check and publishes nothing.
##   --mode=exact    the trail set published by the existing mechanism
##                   (RegionBakeTrails.publish), checked on the published
##                   triangles; tiles outside the trail's dependency set
##                   (refined tiles) must keep their off arrays. Bridges,
##                   water, spawn and manifest as RegionBake.finish makes
##                   them; vegetation only for the changed tiles and their 8
##                   neighbours, the rest from the off vegetation of the same
##                   ground (computed once, stored under user://trail_probe/
##                   keyed by the ground key and the vegetation planner's
##                   source closure). Products saved to the dev cache under
##                   the runtime key of --config, so ride_trail.gd --dev-cache
##                   rides them. --verify-full also runs a cold full bake
##                   (RegionBake from upstream, every tile's vegetation) with
##                   the same configuration and compares the network, tile
##                   and vegetation digests.
##   --mode=check    success and refusal checks on this ground: suitable
##                   examples (BC1 trail of 184729, each trail the V1 planner
##                   selects) must pass preview and publish in exact;
##                   unsuitable variants derived from them (other seed, end
##                   off the road, a one-way descent reversed, a zigzag of
##                   tight turns, a detour through water) must be refused
##                   with the expected reason in both modes and leave the
##                   tiles unchanged. A correct refusal alone does not show
##                   the tool works; the suitable examples do.
##   --mode=slopes   data for choosing a hillside: candidate tops by height
##                   above their nearest road, with straight-line measures and
##                   length estimates (no feasibility claim).
## --cases=TEXT (check) runs only the cases whose name contains TEXT.
## Common: --seed=S --region=X,Z --threads=N (4) --out-dir=ABS (default
## user://trail_probe/<name>) --name=NAME.
## Output lines: PROBE_GROUND, PROBE_PLANNER, PROBE_PREVIEW, PROBE_EXACT,
## PROBE_VERIFY, PROBE_SLOPES, PROBE_LAUNCH, PROBE_FAIL; exit 0 = the mode's
## result is valid (every trail passed), 2 = a trail refused (reasons
## printed), 1 = tool failure.
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Trails = preload("res://scripts/world/region/region_bake_trails.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Stage = preload("res://scripts/world/region_stage_cache.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const TrailPolicy = preload("res://scripts/world/region/trail_policy.gd")
const Planner = preload("res://scripts/world/region/trail_network_planner.gd")
const Bridges = preload("res://scripts/world/region/bridge_deck_builder.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const VEGETATION_ENTRY := "res://scripts/world/region/region_vegetation_planner.gd"
const OUT_ROOT := "user://trail_probe"
const DEFAULT_POLICY := "res://resources/regions/trail_network.json"
## Map: metres around the trail's bounding box; pixels per metre.
const MAP_MARGIN_M: float = 120.0
const MAP_PX_PER_M: float = 1.0
## Slopes: raster cell, search reach from a road, suppression radius.
const SLOPE_CELL_M: float = 8.0
const SLOPE_REACH_M: float = 1500.0
const SLOPE_SPACING_M: float = 300.0
const SLOPE_BANDS_M: Array[float] = [40.0, 120.0, 250.0, 450.0, 10000.0]
const SLOPE_PER_BAND: int = 4

var _args: Dictionary = {}


func _initialize() -> void:
	_args = {"seed": 184729, "region": Vector2i.ZERO, "threads": 4, "mode": "preview", "config": "", "pick": "", "name": "", "out_dir": "", "verify_full": false, "cases": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_args.seed = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			_args.region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--threads="):
			_args.threads = maxi(1, arg.substr(10).to_int())
		elif arg.begins_with("--mode="):
			_args.mode = arg.substr(7)
		elif arg.begins_with("--config="):
			_args.config = arg.substr(9)
		elif arg.begins_with("--pick="):
			_args.pick = arg.substr(7)
		elif arg.begins_with("--name="):
			_args.name = arg.substr(7)
		elif arg.begins_with("--out-dir="):
			_args.out_dir = arg.substr(10)
		elif arg.begins_with("--cases="):
			_args.cases = arg.substr(8)
		elif arg == "--verify-full":
			_args.verify_full = true
	if not _args.mode in ["planner", "preview", "exact", "slopes", "check"]:
		print("PROBE_FAIL unknown mode ", _args.mode)
		quit(1)
		return
	if _args.mode in ["preview", "exact"] and _args.config.is_empty():
		print("PROBE_FAIL --config=PATH required for ", _args.mode)
		quit(1)
		return
	if _args.name.is_empty():
		_args.name = _args.config.get_file().get_basename() if not _args.config.is_empty() else "%d_%d_%d_%s" % [_args.seed, _args.region.x, _args.region.y, _args.mode]
	if _args.out_dir.is_empty():
		_args.out_dir = ProjectSettings.globalize_path(OUT_ROOT.path_join(_args.name))
	DirAccess.make_dir_recursive_absolute(_args.out_dir)
	var t0: int = Time.get_ticks_usec()
	var made: Dictionary = Synth.off_main_thread(func() -> Dictionary: return _work())
	made["total_s"] = _lap(t0)
	var summary_path: String = _args.out_dir.path_join("%s_summary.json" % _args.mode)
	var f := FileAccess.open(summary_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(made, "\t"))
	f.close()
	print("PROBE_SUMMARY ", summary_path, " total_s=%.2f" % made.total_s)
	quit(int(made.get("exit_code", 1)))


func _work() -> Dictionary:
	var timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var up: Dictionary = Ground.upstream(_args.seed, _args.region)
	timings["upstream_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var options := {"threads": _args.threads, "max_replans": Builder.MAX_REPLANS, "stop_rule": Builder.STOP_ROADS}
	var gkey: Dictionary = Stage.ground_key(_args.seed, _args.region, options)
	var ground: Dictionary = Stage.load_ground(gkey.key, _args.seed, _args.region, up)
	var ground_state: String = "reused"
	if ground.is_valid:
		timings["ground_load_s"] = _lap(t)
	else:
		# Missing ground stage: built once (a cold R5-R7 + tiles run) and stored.
		ground_state = "built (%s)" % ground.reason_code
		var bake_timings: Dictionary = {}
		ground = Bake.ground_stage(_args.seed, _args.region, up, options, Callable(), bake_timings)
		if not ground.is_valid:
			return {"exit_code": 1, "reason_code": ground.reason_code, "stage": "ground"}
		timings["ground_build_s"] = _lap(t)
		timings["ground_build_detail_s"] = bake_timings
		Stage.save_ground(gkey.key, _args.seed, _args.region, up, ground)
	print("PROBE_GROUND ", JSON.stringify({"state": ground_state, "key": gkey.key.left(16), "seconds": timings.get("ground_load_s", timings.get("ground_build_s"))}))
	var out := {"seed": _args.seed, "region": [_args.region.x, _args.region.y], "mode": _args.mode, "ground": ground_state, "ground_key": gkey.key, "timings_s": timings,
		"threads": _args.threads}
	match _args.mode:
		"planner":
			out.merge(_planner(up, ground, timings))
		"preview":
			out.merge(_preview(up, ground, timings))
		"exact":
			out.merge(_exact(up, ground, ground_state, timings))
		"slopes":
			out.merge(_slopes(up, ground, timings))
		"check":
			out.merge(_check(up, ground, ground_state, timings))
	return out


# --- planner -----------------------------------------------------------------

func _planner(up: Dictionary, ground: Dictionary, timings: Dictionary) -> Dictionary:
	var t: int = Time.get_ticks_usec()
	var parsed: Dictionary = TrailPolicy.parse(JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_POLICY)))
	if not parsed.is_valid:
		return {"exit_code": 1, "reason_code": parsed.reason_code}
	var context := {"seed": _args.seed, "region": _args.region, "network": ground.network.get_data(), "surface": ground.surface, "field": up.field, "slots": ground.slots,
		"ground": Surface.published_ground(ground.slots, up.bounds, TrailPolicy.GROUND_CELL_M, _args.threads)}
	timings["planner_ground_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var planned: Dictionary = Planner.plan(parsed.config, context)
	timings["planner_s"] = _lap(t)
	var listing: Array = []
	for trail: Dictionary in planned.trails + planned.alternates:
		listing.append({"id": trail.id, "class": trail.class_name, "selected": trail in planned.trails, "score": snappedf(trail.planner.score, 0.01),
			"length_m": snappedf(trail.length_m, 0.1), "purpose": trail.purpose})
	print("PROBE_PLANNER ", JSON.stringify({"selected": planned.trails.size(), "alternates": planned.alternates.size(), "rejected": planned.rejected.size(),
		"planner_s": snappedf(timings.planner_s, 0.01)}))
	for entry: Dictionary in listing:
		print("  ", "*" if entry.selected else " ", " ", entry.id, " ", entry["class"], " ", entry.length_m, " m score ", entry.score)
	var result := {"exit_code": 0, "proposals": listing, "rejected_count": planned.rejected.size()}
	if _args.pick.is_empty():
		return result
	var picked: Array = []
	for trail: Dictionary in planned.trails + planned.alternates:
		var wanted: bool = trail.id == _args.pick or (_args.pick == "selected" and trail in planned.trails) or (_args.pick == trail.class_name and picked.is_empty())
		if wanted:
			picked.append(trail.planner.config)
	if picked.is_empty():
		print("PROBE_FAIL nothing matches --pick=", _args.pick)
		result.exit_code = 1
		return result
	var config := {"schema": Trail.SCHEMA, "seed": _args.seed, "region": [_args.region.x, _args.region.y], "trails": picked}
	var path: String = OUT_ROOT.path_join(_args.name + ".json")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_ROOT))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(config, "\t"))
	f.close()
	print("PROBE_CONFIG ", path, " trails=", picked.map(func(c: Dictionary) -> String: return c.id))
	result["config_path"] = path
	return result


# --- preview -------------------------------------------------------------------

func _preview(up: Dictionary, ground: Dictionary, timings: Dictionary) -> Dictionary:
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(_args.config))
	var parsed: Dictionary = Trail.parse(config)
	if not parsed.is_valid:
		return {"exit_code": 1, "reason_code": parsed.reason_code, "detail": parsed.detail}
	var bounds: Dictionary = up.bounds
	var context := {"seed": _args.seed, "region": _args.region, "network": ground.network.get_data(), "surface": ground.surface, "field": up.field}
	var t: int = Time.get_ticks_usec()
	var trails: Array = []
	var all_ok: bool = true
	for cfg: Dictionary in parsed.config.trails:
		var made: Dictionary = Trail.realize(cfg, parsed.config, context)
		var line: Dictionary = made.trail.line if made.is_valid else _line_of(cfg, ground.surface, bounds)
		var entry := {"id": cfg.id, "verdict": "PREVIEW_OK" if made.is_valid else "PREVIEW_REFUSED", "reason_code": made.reason_code, "detail": made.detail,
			"class": str(cfg.get("class", "SINGLETRACK")), "half_width_m": float(cfg.get("half_width_m", 0.65))}
		if made.is_valid:
			entry["metrics"] = made.trail.metrics
			entry["length_m"] = made.trail.length_m
			entry["joins"] = made.trail.joins.map(func(j: Dictionary) -> Dictionary: return {"node": j.node, "piece": j.piece, "node_distance_m": snappedf(j.node_distance_m, 0.1)})
			entry["operations"] = made.trail.operations.map(func(op: Dictionary) -> Dictionary: return {"kind": op.kind, "s0_m": op.s0_m, "s1_m": op.s1_m, "metrics": op.metrics})
		else:
			all_ok = false
			entry["operations_configured"] = cfg.get("operations", [])
		if not line.is_empty():
			entry["profile"] = _profile(line, entry.half_width_m, ground.surface, up.field, bounds)
			_write_profile(cfg.id, entry.profile)
			entry.profile = _profile_summary(entry.profile)
		entry["line_obj"] = line
		trails.append(entry)
		print("PROBE_PREVIEW ", JSON.stringify({"id": entry.id, "verdict": entry.verdict, "reason_code": entry.reason_code, "detail": entry.detail,
			"length_m": entry.get("length_m", 0.0), "profile": entry.get("profile", {})}))
	timings["preview_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var map_path: String = _map(trails, ground, up, "preview")
	timings["map_s"] = _lap(t)
	for entry: Dictionary in trails:
		entry.erase("line_obj")
	return {"exit_code": 0 if all_ok else 2, "trails": trails, "map": map_path, "note": "preview: design-surface screening only; not a published surface, not a ride check"}


## Dense line of a configured trail (TrailRealization._line), {} when the
## configuration cannot make one.
func _line_of(cfg: Dictionary, surface: RefCounted, bounds: Dictionary) -> Dictionary:
	var points: Array[Vector2] = []
	for p: Variant in cfg.get("control_points", []):
		if p is Array and p.size() == 2:
			points.append(Vector2(float(p[0]), float(p[1])))
	if points.size() < 2:
		return {}
	var line: Dictionary = Trail._line(points, float(cfg.get("half_width_m", 0.65)), surface, bounds)
	return line if line.get("is_valid", false) else {}


## Per-sample profile: s, x, z, height, grade over +-2 m, side slope across
## the band (design surface), circumradius over +-3 m, road / water flags.
func _profile(line: Dictionary, half: float, surface: RefCounted, field: RefCounted, bounds: Dictionary) -> Dictionary:
	var n: int = line.s.size()
	var grade := PackedFloat32Array()
	var cross := PackedFloat32Array()
	var radius := PackedFloat32Array()
	var road := PackedByteArray()
	var water := PackedByteArray()
	for k in range(n):
		var a: int = maxi(0, k - 2)
		var b: int = mini(n - 1, k + 2)
		grade.append((line.y[b] - line.y[a]) / maxf(line.s[b] - line.s[a], 0.01))
		var p := Vector2(line.x[k], line.z[k])
		var normal := Vector2(-line.tz[k], line.tx[k])
		var hi: Dictionary = surface.sample_height(bounds.min_x + p.x + normal.x * half, bounds.min_z + p.y + normal.y * half)
		var lo: Dictionary = surface.sample_height(bounds.min_x + p.x - normal.x * half, bounds.min_z + p.y - normal.y * half)
		cross.append((hi.height_m - lo.height_m) / (2.0 * half) if hi.is_valid and lo.is_valid else NAN)
		var i0: int = maxi(0, k - 3)
		var i1: int = mini(n - 1, k + 3)
		radius.append(_circumradius(Vector2(line.x[i0], line.z[i0]), p, Vector2(line.x[i1], line.z[i1])))
		road.append(0 if surface.road_owner(bounds.min_x + p.x, bounds.min_z + p.y).is_empty() else 1)
		water.append(1 if field.sample_water(bounds.min_x + p.x, bounds.min_z + p.y).get("is_water", false) else 0)
	return {"s": line.s, "x": line.x, "z": line.z, "y": line.y, "grade": grade, "cross": cross, "radius": radius, "road": road, "water": water}


func _circumradius(a: Vector2, b: Vector2, c: Vector2) -> float:
	var area2: float = absf((b - a).cross(c - a))
	if area2 < 1e-6:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * area2)


func _profile_summary(p: Dictionary) -> Dictionary:
	var n: int = p.s.size()
	var climb: float = 0.0
	var descent: float = 0.0
	var max_up: float = 0.0
	var max_down: float = 0.0
	var max_cross: float = 0.0
	var min_r: float = INF
	var road_m: float = 0.0
	var water_m: float = 0.0
	for k in range(n):
		if k > 0:
			var dy: float = p.y[k] - p.y[k - 1]
			climb += maxf(dy, 0.0)
			descent += maxf(-dy, 0.0)
		max_up = maxf(max_up, p.grade[k])
		max_down = minf(max_down, p.grade[k])
		if not is_nan(p.cross[k]) and p.road[k] == 0:
			max_cross = maxf(max_cross, absf(p.cross[k]))
		if p.road[k] == 0:
			min_r = minf(min_r, p.radius[k])
		road_m += float(p.road[k])
		water_m += float(p.water[k])
	return {"length_m": snappedf(p.s[n - 1], 0.1), "climb_m": snappedf(climb, 0.1), "descent_m": snappedf(descent, 0.1), "height_start_m": snappedf(p.y[0], 0.1),
		"height_end_m": snappedf(p.y[n - 1], 0.1), "max_grade_up": snappedf(max_up, 0.001), "max_grade_down": snappedf(max_down, 0.001),
		"max_side_slope_off_road": snappedf(max_cross, 0.001), "min_radius_off_road_m": snappedf(min_r, 0.1) if is_finite(min_r) else -1.0, "road_samples": int(road_m),
		"water_samples": int(water_m)}


func _write_profile(id: String, p: Dictionary) -> void:
	var path: String = _args.out_dir.path_join("profile_%s.csv" % id.replace(":", "_"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_line("s_m,x_m,z_m,y_m,grade,side_slope,radius_m,road,water")
	for k in range(p.s.size()):
		f.store_line("%.1f,%.2f,%.2f,%.2f,%.4f,%.4f,%.1f,%d,%d" % [p.s[k], p.x[k], p.z[k], p.y[k], p.grade[k], p.cross[k], minf(p.radius[k], 9999.0), p.road[k], p.water[k]])
	f.close()


# --- exact ---------------------------------------------------------------------

func _exact(up: Dictionary, ground: Dictionary, ground_state: String, timings: Dictionary) -> Dictionary:
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(_args.config))
	if Trail.parse(config).get("is_valid", false) == false:
		return {"exit_code": 1, "reason_code": "ERR_TRAIL_INPUT"}
	var options := {"threads": _args.threads, "trail_config": config}
	var t: int = Time.get_ticks_usec()
	var off_vegetation: Dictionary = _off_vegetation(up, ground, timings)
	if not off_vegetation.is_valid:
		return {"exit_code": 1, "reason_code": off_vegetation.reason_code, "stage": "off vegetation"}
	timings["off_vegetation_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var trailed: Dictionary = Trails.publish(config, _args.seed, _args.region, ground.network, ground.surface, up.field, up.bounds, ground.slots, _args.threads)
	timings["publish_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var baked: Dictionary = _finish(up, ground, trailed, off_vegetation.vegetation, config, timings)
	timings["finish_s"] = _lap(t)
	if not baked.is_valid:
		return {"exit_code": 1, "reason_code": baked.reason_code, "stage": "finish"}
	# Tiles outside the dependency set (the refined tiles, seam growth
	# included) keep their prototype-off arrays.
	var changed: Array = []
	for k in range(baked.tiles.size()):
		if baked.tiles[k].sha256 != ground.slots[k].sha256:
			changed.append(k)
	var dependency: Array = trailed.refined.duplicate()
	dependency.sort()
	var outside: Array = changed.filter(func(k: int) -> bool: return not k in dependency)
	var tile_of := func(k: int) -> Array: return [ground.slots[k].tx, ground.slots[k].tz]
	var report: Dictionary = trailed.report
	var published: Array = report.published.map(func(e: Dictionary) -> Dictionary: return {"id": e.id, "length_m": snappedf(e.length_m, 0.1), "metrics": e.metrics,
		"tiles": e.tiles, "border_points": e.border_points, "operations": e.operations})
	var rejected: Array = report.rejected
	t = Time.get_ticks_usec()
	var settings: Dictionary = Cache.trail_settings(_args.config)
	var key: String = Cache.key(_args.seed, _args.region, settings)
	baked.manifest["dev_stage_reuse"] = {"stages": {"ground": ground_state, "trails": "trail_probe exact", "config": _args.config}}
	# Nothing published: nothing to ride, products are the off ones (not saved).
	var saved: Dictionary = Cache.save(key, baked, Stage.DEV_ROOT) if not published.is_empty() else {"is_valid": false}
	timings["save_s"] = _lap(t)
	var m: Dictionary = baked.manifest
	var result := {"published": published, "rejected": rejected, "publication": report.get("publication", {}), "dependency_tiles": dependency.map(tile_of),
		"changed_tiles": changed.map(tile_of), "changed_outside_dependency": outside.map(tile_of), "outside_unchanged": outside.is_empty(),
		"digests": {"network": m.network_digest, "tiles": m.tiles_digest, "vegetation": m.vegetation.digest}, "runtime_key": key, "saved": saved.is_valid,
		"dev_cache_dir": ProjectSettings.globalize_path(Cache.directory_of(key, Stage.DEV_ROOT))}
	print("PROBE_EXACT ", JSON.stringify({"published": published.map(func(e: Dictionary) -> Array: return [e.id, e.length_m]), "rejected": rejected.map(func(r: Dictionary) -> Array:
		return [r.id, r.reason_code, r.detail]), "dependency_tiles": dependency.size(), "changed_tiles": changed.size(), "outside_unchanged": result.outside_unchanged,
		"publish_s": snappedf(timings.publish_s, 0.01), "finish_s": snappedf(timings.finish_s, 0.01), "saved": saved.is_valid}))
	var ok: bool = rejected.is_empty() and result.outside_unchanged and saved.is_valid and not published.is_empty()
	if _args.verify_full:
		t = Time.get_ticks_usec()
		var full: Dictionary = Bake._bake(_args.seed, _args.region, options, Callable())
		timings["verify_full_s"] = _lap(t)
		if not full.is_valid:
			result["verify_full"] = {"verdict": "FULL_BAKE_FAILED", "reason_code": full.reason_code}
			ok = false
		else:
			var fm: Dictionary = full.manifest
			var same := {"network": fm.network_digest == m.network_digest, "tiles": fm.tiles_digest == m.tiles_digest, "vegetation": fm.vegetation.digest == m.vegetation.digest}
			var verdict: String = "MATCH" if same.values().all(func(v: bool) -> bool: return v) else "MISMATCH"
			result["verify_full"] = {"verdict": verdict, "same": same, "full_digests": {"network": fm.network_digest, "tiles": fm.tiles_digest, "vegetation": fm.vegetation.digest},
				"full_timings_s": fm.timings_s}
			ok = ok and verdict == "MATCH"
			print("PROBE_VERIFY ", verdict, " ", JSON.stringify(same), " full_bake_s=%.1f" % timings.verify_full_s)
	var trail_flag: String = "" if published.is_empty() else " --trail=%s" % published[0].id
	var launch: String = "godot --path . --script res://tools/dev/ride_trail.gd -- --seed=%d --region=%d,%d --trail-config=%s --dev-cache%s" % [_args.seed, _args.region.x,
		_args.region.y, _args.config, trail_flag]
	print("PROBE_LAUNCH ", launch)
	result["launch"] = launch
	result["exit_code"] = 0 if ok else 2
	var maps: Array = []
	for e: Dictionary in report.published:
		for trail: Dictionary in baked.network.get_trails():
			if trail.id == e.id:
				maps.append({"id": e.id, "verdict": "PUBLISHED", "line_obj": trail.line})
	if not maps.is_empty():
		t = Time.get_ticks_usec()
		result["map"] = _map(maps, {"slots": baked.tiles, "network": baked.network}, up, "exact")
		timings["map_s"] = _lap(t)
	return result


## Off vegetation of the ground (every tile on the prototype-off surface, as
## RegionBake.finish plans it), stored once per ground key and vegetation
## planner source closure; {is_valid, vegetation}.
func _off_vegetation(up: Dictionary, ground: Dictionary, timings: Dictionary) -> Dictionary:
	var gkey: String = Stage.ground_key(_args.seed, _args.region, {"max_replans": Builder.MAX_REPLANS, "stop_rule": Builder.STOP_ROADS}).key
	var key: String = (gkey + "\n" + Stage.closure_digest([VEGETATION_ENTRY]).digest).sha256_text()
	var path: String = OUT_ROOT.path_join("off_vegetation").path_join(key + ".bin")
	if FileAccess.file_exists(path) and FileAccess.file_exists(path + ".sha256"):
		var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		file.close()
		if bytes.size() > 0 and Stage._sha(bytes) == FileAccess.get_file_as_string(path + ".sha256").strip_edges():
			var stored: Variant = bytes_to_var(bytes)
			if stored is Array and stored.size() == ground.slots.size():
				timings["off_vegetation"] = "reused"
				return {"is_valid": true, "vegetation": stored}
	var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, ground.surface)
	if not flora.is_valid:
		return {"is_valid": false, "reason_code": flora.reason_code}
	var vegetation: Array = Bake._vegetation(flora.planner, ground.slots, _args.threads)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var bytes: PackedByteArray = var_to_bytes(vegetation)
	var out := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	out.store_buffer(bytes)
	out.close()
	var sidecar := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	sidecar.store_string(Stage._sha(bytes))
	sidecar.close()
	timings["off_vegetation"] = "built"
	return {"is_valid": true, "vegetation": vegetation}


## RegionBake.finish on the trail products with vegetation planned again only
## for the tiles whose arrays changed and their 8 neighbours (the others keep
## the off vegetation). Same records and manifest fields as finish.
func _finish(up: Dictionary, ground: Dictionary, trailed: Dictionary, off: Array, config: Variant, timings: Dictionary) -> Dictionary:
	var bounds: Dictionary = up.bounds
	var network: RefCounted = trailed.network
	var surface: RefCounted = trailed.surface
	var slots: Array = trailed.slots
	var data: Dictionary = network.get_data()
	var bake_timings: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var ground_height := func(x: float, z: float) -> float:
		var h: Dictionary = surface.sample_height(x + bounds.min_x, z + bounds.min_z)
		return h.height_m if h.is_valid else NAN
	var bridges: Dictionary = Bridges.build(data, ground_height)
	var water: Dictionary = Bake._water(up.hydro.plan)
	bake_timings["bridges_water_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var flora: Dictionary = Vegetation.create(up.plan, up.terrain, up.hydro.plan, surface)
	if not flora.is_valid:
		return {"is_valid": false, "reason_code": flora.reason_code}
	var vegetation: Array = off.duplicate()
	var near: Dictionary = {}
	for k in range(slots.size()):
		if slots[k].sha256 != ground.slots[k].sha256:
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					near[Vector2i(slots[k].tx + dx, slots[k].tz + dz)] = true
	var redo: Array = []
	for k in range(slots.size()):
		if near.has(Vector2i(slots[k].tx, slots[k].tz)):
			redo.append(k)
	var job := func(i: int) -> void:
		vegetation[redo[i]] = flora.planner.tile(slots[redo[i]].tx, slots[redo[i]].tz)
	if _args.threads > 1 and redo.size() > 1:
		var group: int = WorkerThreadPool.add_group_task(job, redo.size(), _args.threads, true, "trail_probe_vegetation")
		WorkerThreadPool.wait_for_group_task_completion(group)
	else:
		for i in range(redo.size()):
			job.call(i)
	bake_timings["vegetation_s"] = _lap(t)
	bake_timings["vegetation_tiles"] = redo.size()
	timings["finish_detail"] = bake_timings
	var meta: Dictionary = ground.meta
	var manifest: Dictionary = {"schema": Bake.SCHEMA, "seed": _args.seed, "region": [_args.region.x, _args.region.y], "origin": [bounds.min_x, bounds.min_z],
		"region_signature": up.plan.signature(), "hydrology_signature": up.hydro.plan.signature(), "network_digest": network.digest(), "graph_signature": meta.graph_signature,
		"plan_signature": meta.plan_signature, "chosen_round": meta.chosen_round, "network_best_round": meta.network_best_round, "rounds": meta.rounds, "metrics": data.metrics,
		"tiles": [], "timings_s": bake_timings, "r7_excluded": meta.r7_excluded, "r7_rounds": meta.r7_rounds, "bridges": bridges.decks.size(), "threads": _args.threads,
		"terrain_kernel": "csharp" if Bake.Eval.kernel_active() else "gdscript", "trails": trailed.report}
	var vertices: int = 0
	var triangles: int = 0
	for slot: Dictionary in slots:
		vertices += slot.vertex_count
		triangles += slot.triangle_count
		manifest.tiles.append({"tile": [slot.tx, slot.tz], "vertices": slot.vertex_count, "triangles": slot.triangle_count, "sha256": slot.sha256})
	manifest["vertices"] = vertices
	manifest["triangles"] = triangles
	manifest["tiles_digest"] = Bake._tiles_digest(slots)
	manifest["vegetation"] = Bake._vegetation_summary(vegetation)
	return {"is_valid": true, "reason_code": "", "manifest": manifest, "network": network, "tiles": slots, "bridges": bridges, "water": water, "spawn": Bake._spawn(data),
		"vegetation": vegetation, "surface": surface}


# --- check ---------------------------------------------------------------------

func _check(up: Dictionary, ground: Dictionary, ground_state: String, timings: Dictionary) -> Dictionary:
	var parsed: Dictionary = TrailPolicy.parse(JSON.parse_string(FileAccess.get_file_as_string(DEFAULT_POLICY)))
	var context := {"seed": _args.seed, "region": _args.region, "network": ground.network.get_data(), "surface": ground.surface, "field": up.field, "slots": ground.slots,
		"ground": Surface.published_ground(ground.slots, up.bounds, TrailPolicy.GROUND_CELL_M, _args.threads)}
	var planned: Dictionary = Planner.plan(parsed.config, context)
	var wrap := func(trail: Dictionary, seed_value: int) -> Dictionary:
		return {"schema": Trail.SCHEMA, "seed": seed_value, "region": [_args.region.x, _args.region.y], "trails": [trail]}
	var cases: Array = []
	if _args.seed == 184729 and _args.region == Vector2i.ZERO:
		cases.append({"name": "suitable_bc1_meadow", "expect": "PUBLISH", "config": JSON.parse_string(FileAccess.get_file_as_string("res://resources/regions/bc1_trail_184729.json"))})
	var first_st: Dictionary = {}
	var first_tech: Dictionary = {}
	for trail: Dictionary in planned.trails:
		cases.append({"name": "suitable_" + trail.id.trim_prefix("trail:"), "expect": "PUBLISH", "config": wrap.call(trail.planner.config, _args.seed)})
		if trail.class_name == "SINGLETRACK" and first_st.is_empty():
			first_st = trail
		if trail.class_name == "TECHNICAL" and first_tech.is_empty():
			first_tech = trail
	var base: Dictionary = first_st if not first_st.is_empty() else (planned.trails[0] if not planned.trails.is_empty() else {})
	if not base.is_empty():
		var cfg: Dictionary = base.planner.config.duplicate(true)
		cases.append({"name": "unsuitable_other_seed", "expect": "ERR_TRAIL_IDENTITY", "stage": "seed/region", "config": wrap.call(cfg, _args.seed + 1)})
		cfg = base.planner.config.duplicate(true)
		cfg.id = "trail:check_end_off_road"
		cfg.control_points = cfg.control_points.slice(0, maxi(2, int(cfg.control_points.size() * 0.6)))
		cases.append({"name": "unsuitable_end_off_road", "expect": "ERR_TRAIL_CONNECTION", "stage": "ends on road", "config": wrap.call(cfg, _args.seed)})
		cfg = base.planner.config.duplicate(true)
		cfg.id = "trail:check_zigzag"
		var pts: Array = cfg.control_points
		var a := Vector2(pts[0][0], pts[0][1])
		var mid: int = pts.size() / 2
		var m := Vector2(pts[mid][0], pts[mid][1])
		var b := Vector2(pts[mid + 1][0], pts[mid + 1][1]) if mid + 1 < pts.size() else a
		var along: Vector2 = (b - m).normalized() if b.distance_to(m) > 1.0 else (m - a).normalized()
		var zig: Array = []
		for q in range(6):
			var p: Vector2 = m + along * (4.0 * q) + along.orthogonal() * (3.0 if q % 2 == 0 else -3.0)
			zig.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		cfg.control_points = pts.slice(0, mid) + zig + pts.slice(mid + 1)
		cases.append({"name": "unsuitable_zigzag", "expect": "ERR_TRAIL_UNRIDEABLE", "stage": "radius", "config": wrap.call(cfg, _args.seed)})
		# Water: detours of every selected trail towards nearby water, nearest
		# first; the first whose design-surface screening meets water before
		# any other limit becomes the case (a fixture built to reach water,
		# so the check is about the water refusal itself).
		var screen := {"seed": _args.seed, "region": _args.region, "network": ground.network.get_data(), "surface": ground.surface, "field": up.field}
		var tried: int = 0
		for trail: Dictionary in planned.trails:
			if cases.any(func(c: Dictionary) -> bool: return c.name == "unsuitable_through_water"):
				break
			for detour: Array in _water_detours(trail, up, ground.surface):
				if tried >= 40:
					break
				tried += 1
				cfg = trail.planner.config.duplicate(true)
				cfg.id = "trail:check_through_water"
				cfg.control_points = detour
				var config_try: Dictionary = wrap.call(cfg, _args.seed)
				var made: Dictionary = Trail.realize(cfg, config_try, screen)
				if not made.is_valid and str(made.detail.get("stage", "")) == "water":
					cases.append({"name": "unsuitable_through_water", "expect": "ERR_TRAIL_UNRIDEABLE", "stage": "water", "config": config_try, "fixture_attempts": tried})
					break
		if not cases.any(func(c: Dictionary) -> bool: return c.name == "unsuitable_through_water"):
			print("PROBE_CHECK water case NOT BUILT: no detour of ", tried, " met water before another limit")
	if not first_tech.is_empty():
		var cfg: Dictionary = first_tech.planner.config.duplicate(true)
		cfg.id = "trail:check_descent_reversed"
		cfg.control_points.reverse()
		cfg.nodes.reverse()
		cases.append({"name": "unsuitable_descent_reversed", "expect": "ERR_TRAIL_UNRIDEABLE", "stage": "direction", "config": wrap.call(cfg, _args.seed)})
	var root_dir: String = _args.out_dir
	var results: Array = []
	var all_pass: bool = true
	if not _args.cases.is_empty():
		cases = cases.filter(func(case: Dictionary) -> bool: return _args.cases in case.name)
	for case: Dictionary in cases:
		var path: String = OUT_ROOT.path_join("check").path_join(case.name + ".json")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(case.config, "\t"))
		f.close()
		_args.config = path
		_args.out_dir = root_dir.path_join(case.name)
		DirAccess.make_dir_recursive_absolute(_args.out_dir)
		var case_timings: Dictionary = {}
		var t: int = Time.get_ticks_usec()
		var preview: Dictionary = _preview(up, ground, case_timings)
		var preview_s: float = _lap(t)
		t = Time.get_ticks_usec()
		var exact: Dictionary = _exact(up, ground, ground_state, case_timings)
		var exact_s: float = _lap(t)
		var p_reason: String = preview.trails[0].reason_code if preview.has("trails") and not preview.trails.is_empty() else str(preview.get("reason_code", ""))
		var e_reasons: Array = exact.get("rejected", []).map(func(r: Dictionary) -> String: return r.reason_code)
		var verdict: bool
		if case.expect == "PUBLISH":
			verdict = p_reason.is_empty() and exact.get("exit_code", 1) == 0
		else:
			var tiles_kept: bool = exact.get("changed_tiles", [null]).is_empty()
			var p_stage: String = str(preview.trails[0].detail.get("stage", "")) if preview.has("trails") and not preview.trails.is_empty() else ""
			verdict = p_reason == case.expect and p_stage == case.stage and e_reasons.size() > 0 and e_reasons.all(func(r: String) -> bool: return r == case.expect) and tiles_kept
		all_pass = all_pass and verdict
		var entry := {"fixture_attempts": case.get("fixture_attempts", 0), "case": case.name, "expect": case.expect + ("" if case.expect == "PUBLISH" else " / " + case.stage), "verdict": "PASS" if verdict else "FAIL", "preview_reason": p_reason, "exact_rejected": exact.get("rejected", []),
			"exact_published": exact.get("published", []).map(func(e: Dictionary) -> String: return e.id), "changed_tiles": exact.get("changed_tiles", []).size(),
			"outside_unchanged": exact.get("outside_unchanged", false), "preview_s": snappedf(preview_s, 0.01), "exact_s": snappedf(exact_s, 0.01), "config": path,
			"publication": exact.get("publication", {}), "timings_s": case_timings, "launch": exact.get("launch", "")}
		if preview.has("trails") and not preview.trails.is_empty():
			entry["preview_detail"] = preview.trails[0].detail
			entry["profile"] = preview.trails[0].get("profile", {})
		results.append(entry)
		print("PROBE_CHECK ", JSON.stringify({"case": entry.case, "expect": entry.expect, "verdict": entry.verdict, "preview_reason": p_reason, "exact_reasons": e_reasons,
			"published": entry.exact_published, "changed_tiles": entry.changed_tiles, "preview_s": entry.preview_s, "exact_s": entry.exact_s}))
	_args.out_dir = root_dir
	print("PROBE_CHECK_SUMMARY ", JSON.stringify({"cases": results.size(), "pass": results.filter(func(r: Dictionary) -> bool: return r.verdict == "PASS").size(),
		"suitable": results.filter(func(r: Dictionary) -> bool: return r.expect == "PUBLISH").size()}))
	return {"exit_code": 0 if all_pass and not results.is_empty() else 2, "cases": results}


## Detours of `trail` towards nearby water, nearest first (up to 12): for
## line samples p of the inner part of the line and 16 directions, the first
## water point q 16-80 m away whose design height is within 6 % of the
## distance from p's height; every control point within L = max(8 |q - p|,
## 80 m) of p along the control polyline moves by w (q - p),
## w = (1 + cos(pi t)) / 2, t = distance / L.
func _water_detours(trail: Dictionary, up: Dictionary, surface: RefCounted) -> Array:
	var line: Dictionary = trail.line
	var n: int = line.s.size()
	var bounds: Dictionary = up.bounds
	var found: Array = []
	for k in range(n / 5, n - n / 5, 5):
		var p := Vector2(line.x[k], line.z[k])
		for a in range(16):
			var dir := Vector2.from_angle(TAU * a / 16.0)
			for r in range(16, 81, 8):
				var q: Vector2 = p + dir * r
				if not up.field.sample_water(bounds.min_x + q.x, bounds.min_z + q.y).get("is_water", false):
					continue
				var h: Dictionary = surface.sample_height(bounds.min_x + q.x, bounds.min_z + q.y)
				if h.is_valid and absf(h.height_m - line.y[k]) <= 0.06 * r:
					found.append({"r": float(r), "p": p, "q": q, "k": k, "a": a})
				break
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.r < y.r or (x.r == y.r and (x.k < y.k or (x.k == y.k and x.a < y.a))))
	var points: Array = trail.planner.config.control_points
	var along := PackedFloat64Array([0.0])
	for i in range(1, points.size()):
		along.append(along[i - 1] + Vector2(points[i][0], points[i][1]).distance_to(Vector2(points[i - 1][0], points[i - 1][1])))
	var out: Array = []
	for best: Dictionary in found.slice(0, 12):
		var centre: int = 0
		for i in range(points.size()):
			if Vector2(points[i][0], points[i][1]).distance_to(best.p) < Vector2(points[centre][0], points[centre][1]).distance_to(best.p):
				centre = i
		var reach: float = minf(maxf(8.0 * best.r, 80.0), minf(along[centre], along[points.size() - 1] - along[centre]) - 20.0)
		if reach < 40.0:
			continue
		var shift: Vector2 = best.q - best.p
		var bent: Array = []
		for i in range(points.size()):
			var t: float = absf(along[i] - along[centre]) / reach
			var w: float = 0.5 * (1.0 + cos(PI * t)) if t < 1.0 else 0.0
			bent.append([snappedf(points[i][0] + w * shift.x, 0.01), snappedf(points[i][1] + w * shift.y, 0.01)])
		out.append(bent)
	return out


# --- slopes --------------------------------------------------------------------

## Candidate hillside tops: height above the nearest road point (8 m raster
## of the published off ground), within SLOPE_REACH_M of a road, in drop
## bands (SLOPE_BANDS_M); in each band the gentlest faces first (lowest
## end-to-end grade, at least 0.08), at least SLOPE_SPACING_M apart, up to
## SLOPE_PER_BAND. For each: the
## straight line from that road point to the top - drop, length, end-to-end
## grade (drop / length), mean and largest terrain slope |grad h| along it,
## water on it - and trail lengths a climb at 6 % / a descent at 10 % would
## need (estimates for choosing, not a layout or feasibility check).
func _slopes(up: Dictionary, ground: Dictionary, timings: Dictionary) -> Dictionary:
	var t: int = Time.get_ticks_usec()
	var bounds: Dictionary = up.bounds
	var raster: Dictionary = Surface.published_ground(ground.slots, bounds, SLOPE_CELL_M, _args.threads)
	timings["slopes_raster_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var nx: int = raster.nx
	var nz: int = raster.nz
	var h: PackedFloat32Array = raster.heights
	# Nearest road point per cell (two-pass chamfer propagation of sources).
	var src := PackedInt32Array()
	src.resize(nx * nz)
	src.fill(-1)
	var road_points: Array = []
	for piece: Dictionary in ground.network.get_data().pieces:
		var d: Dictionary = piece.design
		for k in range(0, d.s.size(), 2):
			var i: int = int(round(d.x[k] / SLOPE_CELL_M))
			var j: int = int(round(d.z[k] / SLOPE_CELL_M))
			if i >= 0 and j >= 0 and i < nx and j < nz and src[j * nx + i] < 0:
				src[j * nx + i] = road_points.size()
				road_points.append({"p": Vector2(d.x[k], d.z[k]), "y": d.y[k], "class": int(piece.info.get("route_class", -1)), "piece": piece.id})
	var dist := PackedFloat32Array()
	dist.resize(nx * nz)
	for c in range(nx * nz):
		dist[c] = 0.0 if src[c] >= 0 else INF
	var pass_cells := func(forward: bool) -> void:
		var offsets: Array = [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)] if forward else [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
		var j_range: Array = range(nz) if forward else range(nz - 1, -1, -1)
		var i_range: Array = range(nx) if forward else range(nx - 1, -1, -1)
		for j: int in j_range:
			for i: int in i_range:
				var c: int = j * nx + i
				var here := Vector2(i * SLOPE_CELL_M, j * SLOPE_CELL_M)
				for o: Vector2i in offsets:
					var ni: int = i + o.x
					var nj: int = j + o.y
					if ni < 0 or nj < 0 or ni >= nx or nj >= nz:
						continue
					var s: int = src[nj * nx + ni]
					if s < 0:
						continue
					var dd: float = here.distance_to(road_points[s].p)
					if dd < dist[c]:
						dist[c] = dd
						src[c] = s
	pass_cells.call(true)
	pass_cells.call(false)
	timings["slopes_distance_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var bands: Array = []
	for b in range(SLOPE_BANDS_M.size() - 1):
		bands.append([])
	var grade_of := func(c: int) -> float: return (h[c] - road_points[src[c]].y) / maxf(dist[c], SLOPE_CELL_M)
	for c in range(nx * nz):
		var ci: int = c % nx
		var cj: int = c / nx
		if src[c] < 0 or dist[c] > SLOPE_REACH_M or is_nan(h[c]) or mini(mini(ci, cj), mini(nx - 1 - ci, nz - 1 - cj)) * SLOPE_CELL_M < Trail.MARGIN_M * 4.0:
			continue
		var gain: float = h[c] - road_points[src[c]].y
		for b in range(SLOPE_BANDS_M.size() - 1):
			if gain >= SLOPE_BANDS_M[b] and gain < SLOPE_BANDS_M[b + 1] and grade_of.call(c) >= 0.08:
				bands[b].append(c)
	var chosen: Array = []
	for b in range(bands.size()):
		var cells: Array = bands[b]
		cells.sort_custom(func(x: int, y: int) -> bool: return grade_of.call(x) < grade_of.call(y) or (grade_of.call(x) == grade_of.call(y) and x < y))
		var picked: Array = []
		for c: int in cells:
			var p := Vector2((c % nx) * SLOPE_CELL_M, (c / nx) * SLOPE_CELL_M)
			if picked.any(func(q: Vector2) -> bool: return q.distance_to(p) < SLOPE_SPACING_M):
				continue
			picked.append(p)
			chosen.append([c, b])
			if picked.size() >= SLOPE_PER_BAND:
				break
	var tops: Array = []
	for pair: Array in chosen:
		var c: int = pair[0]
		var p := Vector2((c % nx) * SLOPE_CELL_M, (c / nx) * SLOPE_CELL_M)
		var r: Dictionary = road_points[src[c]]
		var drop: float = h[c] - r.y
		var length: float = p.distance_to(r.p)
		var steps: int = maxi(2, int(length / SLOPE_CELL_M))
		var mean_slope: float = 0.0
		var max_slope: float = 0.0
		var steep_share: float = 0.0
		var water: int = 0
		for m in range(1, steps):
			var q: Vector2 = r.p.lerp(p, float(m) / steps)
			var gx: float = (Surface.ground_height(raster, q.x + SLOPE_CELL_M, q.y) - Surface.ground_height(raster, q.x - SLOPE_CELL_M, q.y)) / (2.0 * SLOPE_CELL_M)
			var gz: float = (Surface.ground_height(raster, q.x, q.y + SLOPE_CELL_M) - Surface.ground_height(raster, q.x, q.y - SLOPE_CELL_M)) / (2.0 * SLOPE_CELL_M)
			var g: float = Vector2(gx, gz).length()
			if is_nan(g):
				continue
			mean_slope += g
			max_slope = maxf(max_slope, g)
			steep_share += 1.0 if g >= 0.23 else 0.0
			if up.field.sample_water(bounds.min_x + q.x, bounds.min_z + q.y).get("is_water", false):
				water += 1
		mean_slope /= steps - 1
		steep_share /= steps - 1
		tops.append({"p": p, "band_m": "%d-%d" % [int(SLOPE_BANDS_M[pair[1]]), int(SLOPE_BANDS_M[pair[1] + 1])], "top_x_m": p.x, "top_z_m": p.y, "top_y_m": snappedf(h[c], 0.1), "road_x_m": snappedf(r.p.x, 0.1), "road_z_m": snappedf(r.p.y, 0.1),
			"road_y_m": snappedf(r.y, 0.1), "road_class": r["class"], "road_piece": r.piece, "drop_m": snappedf(drop, 0.1), "straight_m": snappedf(length, 1.0),
			"end_to_end_grade": snappedf(drop / maxf(length, 1.0), 0.001), "mean_terrain_slope": snappedf(mean_slope, 0.001), "max_terrain_slope": snappedf(max_slope, 0.001),
			"share_slope_ge_23pct": snappedf(steep_share, 0.01), "water_samples": water, "climb_6pct_m": snappedf(drop / 0.06, 10.0),
			"descent_10pct_m": snappedf(drop / 0.10, 10.0)})
	timings["slopes_candidates_s"] = _lap(t)
	for top: Dictionary in tops:
		var shown: Dictionary = top.duplicate()
		shown.erase("p")
		print("PROBE_SLOPES ", JSON.stringify(shown))
	var csv: String = _args.out_dir.path_join("slope_candidates.csv")
	var f := FileAccess.open(csv, FileAccess.WRITE)
	var columns: Array = ["band_m", "top_x_m", "top_z_m", "top_y_m", "road_x_m", "road_z_m", "road_y_m", "road_class", "road_piece", "drop_m", "straight_m", "end_to_end_grade",
		"mean_terrain_slope", "max_terrain_slope", "share_slope_ge_23pct", "water_samples", "climb_6pct_m", "descent_10pct_m"]
	f.store_line(",".join(columns))
	for top: Dictionary in tops:
		f.store_line(",".join(columns.map(func(c: String) -> String: return str(top[c]))))
	f.close()
	t = Time.get_ticks_usec()
	var marks: Array = tops.map(func(top: Dictionary) -> Dictionary: return {"top": top.p, "road": Vector2(top.road_x_m, top.road_z_m)})
	var map_path: String = _map([], ground, up, "slopes", marks)
	timings["map_s"] = _lap(t)
	for top: Dictionary in tops:
		top.erase("p")
	return {"exit_code": 0, "candidates": tops, "csv": csv, "map": map_path, "definitions": {"end_to_end_grade": "drop / straight distance between the road point and the top",
		"mean_terrain_slope": "mean |grad h| of the published off ground (8 m raster) along that straight line", "climb_6pct_m / descent_10pct_m": "drop / 0.06, drop / 0.10: trail length estimates, not a layout"}}


# --- map -----------------------------------------------------------------------

## Top-down map (published ground of `products.slots`, slope classes,
## hillshade, 10 m contours): roads white, trails coloured by grade
## (green < 6 %, yellow < 10 %, orange < 15 %, red steeper), road samples of a
## trail grey, refused trails magenta; slope candidates: top cyan, road point
## blue, joined by a line.
func _map(trails: Array, products: Dictionary, up: Dictionary, label: String, marks: Array = []) -> String:
	var bounds: Dictionary = up.bounds
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for entry: Dictionary in trails:
		var line: Dictionary = entry.get("line_obj", {})
		for k in range(line.get("s", []).size()):
			lo = lo.min(Vector2(line.x[k], line.z[k]))
			hi = hi.max(Vector2(line.x[k], line.z[k]))
	for mark: Dictionary in marks:
		lo = lo.min(mark.top).min(mark.road)
		hi = hi.max(mark.top).max(mark.road)
	if not is_finite(lo.x):
		lo = Vector2.ZERO
		hi = Vector2(bounds.max_x - bounds.min_x, bounds.max_z - bounds.min_z)
	var px_per_m: float = MAP_PX_PER_M if marks.is_empty() else 0.25
	lo -= Vector2.ONE * MAP_MARGIN_M
	hi += Vector2.ONE * MAP_MARGIN_M
	var w: int = clampi(int((hi.x - lo.x) * px_per_m), 64, 2048)
	var hgt: int = clampi(int((hi.y - lo.y) * px_per_m), 64, 2048)
	var step: float = maxf((hi.x - lo.x) / w, (hi.y - lo.y) / hgt)
	# Only the tiles under the window are rasterized (the rest stay NAN).
	var window := Rect2(lo, hi - lo).grow(8.0)
	var under: Array = products.slots.filter(func(slot: Dictionary) -> bool:
		return window.intersects(Rect2(slot.origin[0], slot.origin[1], Ground.TILE_M, Ground.TILE_M)))
	var ground: Dictionary = Surface.published_ground(under, bounds, 2.0, _args.threads)
	var image := Image.create(w, hgt, false, Image.FORMAT_RGB8)
	for j in range(hgt):
		for i in range(w):
			var x: float = lo.x + (i + 0.5) * step
			var z: float = lo.y + (j + 0.5) * step
			var h0: float = Surface.ground_height(ground, x, z)
			var hx: float = Surface.ground_height(ground, x + 2.0, z) - Surface.ground_height(ground, x - 2.0, z)
			var hz: float = Surface.ground_height(ground, x, z + 2.0) - Surface.ground_height(ground, x, z - 2.0)
			if is_nan(h0) or is_nan(hx) or is_nan(hz):
				image.set_pixel(i, j, Color(0, 0, 0))
				continue
			var g: float = Vector2(hx, hz).length() / 4.0
			var c: Color = Color(0.35, 0.62, 0.3) if g < 0.10 else (Color(0.62, 0.7, 0.32) if g < 0.23 else (Color(0.78, 0.6, 0.3) if g < 0.35 else (Color(0.7, 0.4, 0.28) if g < 0.6 else Color(0.5, 0.3, 0.3))))
			c = c * clampf(0.8 + 0.6 * (-hx - hz) / 4.0, 0.45, 1.1)
			if int(floor(h0 / 10.0)) != int(floor(Surface.ground_height(ground, x + step, z) / 10.0)) or int(floor(h0 / 10.0)) != int(floor(Surface.ground_height(ground, x, z + step) / 10.0)):
				c = c.darkened(0.35)
			image.set_pixel(i, j, c)
	var dot := func(p: Vector2, r: int, c: Color) -> void:
		var ci: int = int((p.x - lo.x) / step)
		var cj: int = int((p.y - lo.y) / step)
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if ci + di >= 0 and cj + dj >= 0 and ci + di < w and cj + dj < hgt and di * di + dj * dj <= r * r:
					image.set_pixel(ci + di, cj + dj, c)
	var data: Dictionary = products.network.get_data()
	for piece: Dictionary in data.pieces:
		var d: Dictionary = piece.design
		for k in range(d.s.size()):
			dot.call(Vector2(d.x[k], d.z[k]), 1, Color(0.95, 0.95, 0.92))
	for entry: Dictionary in trails:
		var line: Dictionary = entry.get("line_obj", {})
		var refused: bool = entry.verdict.ends_with("REFUSED")
		for k in range(line.get("s", []).size()):
			var a: int = maxi(0, k - 2)
			var b: int = mini(line.s.size() - 1, k + 2)
			var g: float = absf((line.y[b] - line.y[a]) / maxf(line.s[b] - line.s[a], 0.01))
			var c: Color = Color(0.1, 0.85, 0.2) if g < 0.06 else (Color(1.0, 0.9, 0.1) if g < 0.10 else (Color(1.0, 0.55, 0.1) if g < 0.15 else Color(0.9, 0.1, 0.1)))
			dot.call(Vector2(line.x[k], line.z[k]), 1, Color(1.0, 0.2, 0.9) if refused else c)
	for node: Dictionary in data.nodes:
		dot.call(Vector2(node.x_m, node.z_m), 3, Color(1, 0, 0))
	for mark: Dictionary in marks:
		var steps: int = int(mark.top.distance_to(mark.road) / step)
		for m in range(steps):
			dot.call(mark.road.lerp(mark.top, float(m) / maxi(steps, 1)), 0, Color(0.2, 0.9, 1.0))
		dot.call(mark.top, 5, Color(0.2, 0.9, 1.0))
		dot.call(mark.road, 4, Color(0.15, 0.3, 1.0))
	var path: String = _args.out_dir.path_join("map_%s.png" % label)
	image.save_png(path)
	print("PROBE_MAP ", path, " window=[%.0f,%.0f]-[%.0f,%.0f] m" % [lo.x, lo.y, hi.x, hi.y])
	return path


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
