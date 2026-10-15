extends SceneTree
## Cold bake of one region, exactly as the runtime loader does it (RegionBake
## with the default procedural trail configuration, saved under the runtime
## cache key), with stage timings and product digests printed as BAKE_RESULT.
##   --seed=S --region=X,Z [--threads=N (4)] [--trail-config=res://...]
##   [--no-save] [--out=ABS.json] [--stop-rule=ROADS|ALL_CLASSES] (not saved
##   unless ROADS; on code without the option it is ignored)
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const DEFAULT_TRAIL_CONFIG := "res://resources/regions/trail_network.json"


func _initialize() -> void:
	var seed_value: int = 184729
	var region := Vector2i.ZERO
	var threads: int = 4
	var config_path: String = DEFAULT_TRAIL_CONFIG
	var save: bool = true
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
		elif arg == "--no-save":
			save = false
		elif arg.begins_with("--stop-rule="):
			stop_rule = arg.substr(12)
		elif arg.begins_with("--out="):
			out_path = arg.substr(6)
	var settings: Dictionary = Cache.trail_settings(config_path)
	var options := {"threads": threads, "trail_config": JSON.parse_string(FileAccess.get_file_as_string(config_path))}
	if stop_rule != "ROADS":
		options["stop_rule"] = stop_rule
		save = false
	var t0: int = Time.get_ticks_usec()
	var baked: Dictionary = Bake.bake(seed_value, region, options)
	var wall: float = (Time.get_ticks_usec() - t0) / 1e6
	if not baked.is_valid:
		print("BAKE_FAIL ", baked.reason_code)
		quit(1)
		return
	var key: String = Cache.key(seed_value, region, settings)
	var m: Dictionary = baked.manifest
	var summary := {"seed": seed_value, "stop_rule": stop_rule, "region": [region.x, region.y], "threads": threads, "wall_s": wall, "timings_s": m.timings_s, "network_digest": m.network_digest,
		"tiles_digest": m.tiles_digest, "vegetation_digest": m.vegetation.digest, "chosen_round": m.chosen_round, "metrics": m.metrics,
		"trails": (m.get("trails", {}).get("published", []) as Array).map(func(e: Dictionary) -> Array: return [e.id, e.get("class", ""), e.length_m]), "key": key}
	if save:
		var saved: Dictionary = Cache.save(key, baked)
		summary["saved"] = saved.is_valid
	print("BAKE_RESULT ", JSON.stringify(summary))
	if not out_path.is_empty():
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"summary": summary, "manifest": m}, "\t"))
		f.close()
	quit(0)
