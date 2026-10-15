extends SceneTree
## Dev bake with stage reuse (never a production path; RegionStageCache).
## Runs RegionBake as ground -> trails -> finish, reusing the stored products
## of each stage whose source closure, inputs and upstream are unchanged, and
## running (then storing) every stage that is not. Writes the final products
## to the dev cache (user://regions_dev/<runtime key>/, manifest marker
## dev_stage_reuse); a normal launch never reads them, a launch with
## --dev-cache does. When the production cache holds the same runtime key,
## the dev products are compared with it (DEV_VERIFY).
##   --seed=S --region=X,Z [--threads=N (4)] [--trail-config=res://...]
##   [--rebuild=ground|trails] (run that stage and the later ones anyway)
##   [--stop-rule=ROADS|ALL_CLASSES] (network replan stop rule; products of
##   ALL_CLASSES are not saved as final products)
##   [--out=ABS.json]
## Prints DEV_BAKE {stages: {ground, trails: reused|built (reason)}, timings,
## digests, keys} and DEV_VERIFY.
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Stage = preload("res://scripts/world/region_stage_cache.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const DEFAULT_TRAIL_CONFIG := "res://resources/regions/trail_network.json"


func _initialize() -> void:
	var seed_value: int = 184729
	var region := Vector2i.ZERO
	var threads: int = 4
	var config_path: String = DEFAULT_TRAIL_CONFIG
	var rebuild: String = ""
	var out_path: String = ""
	var stop_rule: String = "ROADS"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.substr(7).to_int()
		elif arg.begins_with("--region="):
			var p: PackedStringArray = arg.substr(9).split(",")
			region = Vector2i(int(p[0]), int(p[1]))
		elif arg.begins_with("--threads="):
			threads = maxi(1, arg.substr(10).to_int())
		elif arg.begins_with("--trail-config="):
			config_path = arg.substr(15)
		elif arg.begins_with("--rebuild="):
			rebuild = arg.substr(10)
		elif arg.begins_with("--stop-rule="):
			stop_rule = arg.substr(12)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
	var t0: int = Time.get_ticks_usec()
	var settings: Dictionary = Cache.trail_settings(config_path)
	var options := {"threads": threads, "trail_config": JSON.parse_string(FileAccess.get_file_as_string(config_path)), "max_replans": Builder.MAX_REPLANS, "stop_rule": stop_rule}
	var made: Dictionary = Synth.off_main_thread(func() -> Dictionary: return _work(seed_value, region, options, settings, rebuild))
	if not made.is_valid:
		print("DEV_BAKE_FAIL ", JSON.stringify(made.get("report", {"reason_code": made.reason_code})))
		quit(1)
		return
	var baked: Dictionary = made.baked
	var t: int = Time.get_ticks_usec()
	var key: String = Cache.key(seed_value, region, settings)
	baked.manifest["dev_stage_reuse"] = made.report
	# Products of a non-default stop rule are not what the runtime bakes for
	# this key: never stored as final products (stages are keyed by the rule).
	var saved: Dictionary = Cache.save(key, baked, Stage.DEV_ROOT) if stop_rule == Builder.STOP_ROADS else {"is_valid": false}
	made.report.timings["save_s"] = (Time.get_ticks_usec() - t) / 1e6
	made.report.timings["total_s"] = (Time.get_ticks_usec() - t0) / 1e6
	var m: Dictionary = baked.manifest
	var summary := {"seed": seed_value, "stop_rule": stop_rule, "terrain_kernel": m.terrain_kernel, "region": [region.x, region.y], "stages": made.report.stages, "timings_s": made.report.timings, "bake_timings_s": m.timings_s,
		"network_digest": m.network_digest, "tiles_digest": m.tiles_digest, "vegetation_digest": m.vegetation.digest, "runtime_key": key, "saved": saved.is_valid,
		"trails": (m.get("trails", {}).get("published", []) as Array).map(func(e: Dictionary) -> Array: return [e.id, e.get("class", ""), e.length_m])}
	print("DEV_BAKE ", JSON.stringify(summary))
	var production: Dictionary = Cache.load_products(key)
	if production.is_valid:
		var p: Dictionary = production.manifest
		var same: bool = p.network_digest == m.network_digest and p.tiles_digest == m.tiles_digest and p.vegetation.digest == m.vegetation.digest
		print("DEV_VERIFY ", "MATCH" if same else "MISMATCH", " ", JSON.stringify({"production": [p.network_digest, p.tiles_digest, p.vegetation.digest]}))
	else:
		print("DEV_VERIFY NOT_RUN (no production cache for this source)")
	if not out_path.is_empty():
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"summary": summary, "manifest": m}, "\t"))
		f.close()
	quit(0)


func _work(seed_value: int, region: Vector2i, options: Dictionary, settings: Dictionary, rebuild: String) -> Dictionary:
	var timings: Dictionary = {}
	var bake_timings: Dictionary = {}
	var stages: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var up: Dictionary = Ground.upstream(seed_value, region)
	timings["upstream_s"] = _lap(t)
	bake_timings["upstream_s"] = timings.upstream_s
	t = Time.get_ticks_usec()
	var gkey: Dictionary = Stage.ground_key(seed_value, region, options)
	var tkey: Dictionary = Stage.trails_key(gkey.key, settings)
	timings["keys_s"] = _lap(t)
	t = Time.get_ticks_usec()
	var ground: Dictionary = {"is_valid": false, "reason_code": "ERR_STAGE_REBUILD"}
	if rebuild != "ground":
		ground = Stage.load_ground(gkey.key, seed_value, region, up)
	if ground.is_valid:
		stages["ground"] = "reused"
		timings["ground_load_s"] = _lap(t)
	else:
		stages["ground"] = "built (%s)" % ground.reason_code
		ground = Bake.ground_stage(seed_value, region, up, options, Callable(), bake_timings)
		if not ground.is_valid:
			return {"is_valid": false, "reason_code": ground.reason_code, "report": {"stages": stages, "reason_code": ground.reason_code}}
		timings["ground_build_s"] = _lap(t)
		var saved: Dictionary = Stage.save_ground(gkey.key, seed_value, region, up, ground)
		stages["ground_saved"] = saved.is_valid
	t = Time.get_ticks_usec()
	var trailed: Dictionary = {"is_valid": false, "reason_code": "ERR_STAGE_REBUILD"}
	if rebuild != "ground" and rebuild != "trails" and stages.ground == "reused":
		trailed = Stage.load_trails(tkey.key, gkey.key, ground)
	if trailed.get("is_valid", false):
		stages["trails"] = "reused"
		timings["trails_load_s"] = _lap(t)
	else:
		stages["trails"] = "built (%s)" % trailed.get("reason_code", "")
		trailed = Bake.trail_stage(seed_value, region, up, ground, options, Callable(), bake_timings)
		timings["trails_build_s"] = _lap(t)
		var saved: Dictionary = Stage.save_trails(tkey.key, gkey.key, trailed)
		stages["trails_saved"] = saved.is_valid
	t = Time.get_ticks_usec()
	var baked: Dictionary = Bake.finish(seed_value, region, up, ground, trailed, options, Callable(), bake_timings)
	timings["finish_s"] = _lap(t)
	if not baked.is_valid:
		return {"is_valid": false, "reason_code": baked.reason_code, "report": {"stages": stages, "reason_code": baked.reason_code}}
	var report := {"stages": stages, "timings": timings, "ground_key": gkey.key, "ground_closure_files": gkey.files, "trails_key": tkey.key, "trails_closure_files": tkey.files}
	return {"is_valid": true, "reason_code": "", "baked": baked, "report": report}


static func _lap(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1e6
