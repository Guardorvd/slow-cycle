extends SceneTree

## PERFORMANCE FIRST, FAST group (headless, seconds): dev stage reuse and the
## C# terrain kernel, on production code.
##   P1  stage source closures: the ground closure reaches R5/R6/R7 and the
##       terrain kernel (GDScript and C#), the trail closure reaches the BC2
##       planner; neither reaches the vegetation planner;
##   P2  stage keys are deterministic and change with seed, region, options,
##       the ground key and the trail settings;
##   P3  RegionStageCache refuses unsafe reuse: missing, damaged (file hash),
##       foreign identity, other upstream, bad network, a network R7
##       rejects over the current upstream, damaged tile;
##   P4  dev products (dev_stage_reuse marker) answer only a dev read, never a
##       production read, and production products never answer a dev read;
##   P5  the C# terrain kernel equals the GDScript kernel on 6000 points
##       (NOT_RUN without the .NET build, printed, never PASS);
##   P6  network replan stop rules: ROADS ends on N1-N6 without natural road
##       classes, ALL_CLASSES still demands them; no rule accepts a network
##       missing a continuous backbone, length, loops, SECONDARY, or with a
##       blocked node / stray dead end; an unknown rule is refused.
## Output: PERF_CHECK lines for failures / NOT_RUN and
## PERF_SUMMARY checks=.. failures=.. not_run=.. completed=true.
const Stage = preload("res://scripts/world/region_stage_cache.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Eval = preload("res://scripts/world/region/macro_terrain_evaluator.gd")
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Builder = preload("res://scripts/world/region/region_network_builder.gd")

var _checks: int = 0
var _failures: Array = []
var _not_run: Array = []


func _initialize() -> void:
	var t0: int = Time.get_ticks_usec()
	_closures()
	_keys()
	_refusals()
	_dev_separation()
	_kernel_parity()
	_stop_rules()
	print("PERF_SUMMARY checks=%d failures=%d not_run=%d seconds=%.2f completed=true" % [_checks, _failures.size(), _not_run.size(), (Time.get_ticks_usec() - t0) / 1e6])
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"label": label, "detail": str(detail)})
		print("PERF_CHECK FAIL ", label, " ", str(detail).substr(0, 400))


func _closures() -> void:
	var ground: Array[String] = Stage.closure([Stage.GROUND_ENTRY])
	var trails: Array[String] = Stage.closure([Stage.TRAILS_ENTRY])
	for path: String in ["res://project.godot", Stage.GROUND_ENTRY, "res://scripts/world/region/route_planner.gd", "res://scripts/world/region/road_synthesizer.gd",
			"res://scripts/world/region/region_network_builder.gd", "res://scripts/world/region/macro_terrain_evaluator.gd", Eval.KERNEL_PATH,
			"res://scripts/world/region/final_surface_tile_renderer.gd"]:
		_check(path in ground, "ground closure reaches " + path)
	for path: String in [Stage.TRAILS_ENTRY, "res://scripts/world/region/trail_network_planner.gd"]:
		_check(path in trails, "trail closure reaches " + path)
	var vegetation := "res://scripts/world/region/region_vegetation_planner.gd"
	_check(not vegetation in ground and not vegetation in trails, "no stage closure reaches the vegetation planner", [ground.size(), trails.size()])


func _keys() -> void:
	var options := {"max_replans": 2}
	var a: String = Stage.ground_key(184729, Vector2i.ZERO, options).key
	_check(a == Stage.ground_key(184729, Vector2i.ZERO, options).key, "ground key is deterministic")
	_check(a != Stage.ground_key(184730, Vector2i.ZERO, options).key, "ground key changes with the seed")
	_check(a != Stage.ground_key(184729, Vector2i(1, 0), options).key, "ground key changes with the region")
	_check(a != Stage.ground_key(184729, Vector2i.ZERO, {"max_replans": 1}).key, "ground key changes with the options")
	_check(a != Stage.ground_key(184729, Vector2i.ZERO, {"max_replans": 2, "stop_rule": Builder.STOP_ALL_CLASSES}).key, "ground key changes with the stop rule")
	var settings: Dictionary = Cache.trail_settings("res://resources/regions/trail_network.json")
	var t: String = Stage.trails_key(a, settings).key
	_check(t == Stage.trails_key(a, settings).key, "trail key is deterministic")
	_check(t != Stage.trails_key(Stage.ground_key(2024, Vector2i.ZERO, options).key, settings).key, "trail key changes with the ground key")
	var other: Dictionary = settings.duplicate()
	other["trail_sha256"] = "0".repeat(64)
	_check(t != Stage.trails_key(a, other).key, "trail key changes with the trail settings")


## Synthetic ground payloads written through the stage writer, each with one
## defect; load_ground must refuse each with its reason.
func _refusals() -> void:
	var seed_value: int = 184729
	var region := Vector2i.ZERO
	var up: Dictionary = Ground.upstream(seed_value, region)
	var network: RefCounted = _empty_network(up)
	var foreign: RefCounted = _empty_network(up, "foreign")
	var slot: Dictionary = _slot()
	var good := {"format": Stage.FORMAT, "stage": "ground", "key": "", "seed": seed_value, "region": [region.x, region.y], "region_signature": up.plan.signature(),
		"hydrology_signature": up.hydro.plan.signature(), "network": network.to_bytes(), "network_digest": network.digest(), "slots": [], "meta": {}}
	for k in range(Ground.TILES * Ground.TILES):
		good.slots.append(slot.duplicate(true))
	var cases: Array = [["ok", {}, ""], ["seed", {"seed": seed_value + 1}, "ERR_STAGE_IDENTITY"], ["upstream", {"region_signature": "x"}, "ERR_STAGE_UPSTREAM"],
		["network", {"network_digest": "0".repeat(64)}, "ERR_STAGE_NETWORK"],
		["r7", {"network": foreign.to_bytes(), "network_digest": foreign.digest()}, "ERR_STAGE_SURFACE"], ["tile", {"slots": _damaged(good.slots)}, "ERR_STAGE_TILES"]]
	var keys: Array = []
	for case: Array in cases:
		var key: String = ("perf_test_" + case[0]).sha256_text()
		keys.append(key)
		var payload: Dictionary = good.duplicate(true)
		payload.key = key
		payload.merge(case[1], true)
		Stage._write(key, "ground", payload)
		var loaded: Dictionary = Stage.load_ground(key, seed_value, region, up)
		if case[2].is_empty():
			_check(loaded.is_valid and loaded.surface != null, "intact synthetic ground stage loads", loaded.get("reason_code"))
		else:
			_check(not loaded.is_valid and loaded.reason_code == case[2], "ground stage refused: " + case[0], loaded.get("reason_code"))
	# Missing, then damaged on disk (file hash): read as missing.
	_check(Stage.load_ground("perf_test_absent".sha256_text(), seed_value, region, up).reason_code == "ERR_STAGE_MISSING", "missing ground stage refused")
	var path: String = Stage._path(keys[0], "ground")
	var sidecar := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	sidecar.store_string("0".repeat(64))
	sidecar.close()
	_check(Stage.load_ground(keys[0], seed_value, region, up).reason_code == "ERR_STAGE_MISSING", "damaged ground stage file refused")
	# A trail stage whose ground key is not the current one.
	var tkey: String = "perf_test_trails".sha256_text()
	Stage._write(tkey, "trails", {"format": Stage.FORMAT, "stage": "trails", "key": tkey, "ground_key": "other", "network": network.to_bytes(), "network_digest": network.digest(),
		"refined": [], "refined_slots": [], "surface_trails": [], "report": {}})
	_check(Stage.load_trails(tkey, keys[0], {"slots": [], "surface": null}).reason_code == "ERR_STAGE_IDENTITY", "trail stage of another ground refused")
	keys.append(tkey)
	for key: String in keys:
		for stage: String in ["ground", "trails"]:
			for suffix: String in ["", ".sha256"]:
				if FileAccess.file_exists(Stage._path(key, stage) + suffix):
					DirAccess.remove_absolute(Stage._path(key, stage) + suffix)


func _dev_separation() -> void:
	var network: RefCounted = _empty_network()
	var tiles: Array = []
	for k in range(Ground.TILES * Ground.TILES):
		var slot: Dictionary = _slot()
		slot.merge({"tx": k % Ground.TILES, "tz": k / Ground.TILES, "patches": [], "origin": Vector3.ZERO, "coarse": {}, "patch_order": [], "patch_offsets": [],
			"vertex_count": 3, "triangle_count": 1})
		tiles.append(slot)
	var cases: Array = [[Cache.ROOT, false, true], [Cache.ROOT, true, false], [Stage.DEV_ROOT, true, true], [Stage.DEV_ROOT, false, false]]
	for case: Array in cases:
		var key: String = ("perf_test_products_%s_%s" % [case[0], case[1]]).sha256_text()
		var manifest := {"schema": Bake.SCHEMA, "network_digest": network.digest()}
		if case[1]:
			manifest["dev_stage_reuse"] = {"stages": {}}
		var saved: Dictionary = Cache.save(key, {"network": network, "tiles": tiles, "bridges": [], "water": [], "spawn": {}, "vegetation": [], "manifest": manifest}, case[0])
		var loaded: Dictionary = Cache.load_products(key, case[0])
		_check(saved.is_valid and loaded.is_valid == case[2], "%s read of %s products: %s" % ["dev" if case[0] == Stage.DEV_ROOT else "production",
			"dev" if case[1] else "production", "accepted" if case[2] else "refused"], loaded.reason_code)
		var dir: String = Cache.directory_of(key, case[0])
		for file: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(file))
		DirAccess.remove_absolute(dir)


func _kernel_parity() -> void:
	if not Eval.kernel_active():
		_not_run.append("P5")
		print("PERF_CHECK NOT_RUN C# kernel parity (C# kernel not active: run with the .NET build after dotnet build)")
		return
	var plan: RefCounted = Gen.build(184729, Vector2i.ZERO)
	var context: Eval.Context = Eval.prepare(plan.get_macro_terrain())
	var mismatches: int = 0
	var state: int = 184729
	for k in range(3000):
		state = state * 6364136223846793005 + 1442695040888963407
		var x: float = float((state >> 11) & 0xFFFFF) / 1048576.0 * 4096.0
		state = state * 6364136223846793005 + 1442695040888963407
		var z: float = float((state >> 11) & 0xFFFFF) / 1048576.0 * 4096.0
		for noise: bool in [true, false]:
			if Eval._sample(context, x, z, noise) != Eval.sample_prepared(context, x, z, noise):
				mismatches += 1
	_check(context.kernel != null and mismatches == 0, "C# terrain kernel equals the GDScript kernel on 6000 points", mismatches)


## A network without roads; with `up`, its header names those upstream
## products (R7 accepts it over them).
func _stop_rules() -> void:
	var roads := {"backbone_continuous": true, "component_length_m": 9388.0, "cycles": 3, "classes": {"BACKBONE": 7, "SECONDARY": 5}, "blocked_nodes": 0,
		"dead_ends_not_terminus": 0}
	_check(Builder.complete(roads), "ROADS: a road network meeting N1-N6 without natural road classes is complete")
	_check(not Builder.complete_all_classes(roads), "ALL_CLASSES: the same network is not complete")
	var natural: Dictionary = roads.duplicate(true)
	natural.classes.merge({"SINGLETRACK": 1, "TECHNICAL": 1})
	_check(Builder.complete_all_classes(natural), "ALL_CLASSES: complete with READY SINGLETRACK and TECHNICAL")
	for defect: Array in [["backbone_continuous", false], ["component_length_m", 7999.0], ["cycles", 1], ["classes", {"BACKBONE": 7, "SINGLETRACK": 1, "TECHNICAL": 1}],
			["blocked_nodes", 1], ["dead_ends_not_terminus", 1]]:
		var m: Dictionary = natural.duplicate(true)
		m[defect[0]] = defect[1]
		_check(not Builder.complete(m) and not Builder.complete_all_classes(m), "no stop rule accepts %s = %s" % defect)
	var refused: Dictionary = Builder.build(null, null, null, {"stop_rule": "NONE"})
	_check(not refused.is_valid and refused.reason_code == "ERR_NETWORK_STOP_RULE", "unknown stop rule refused", refused.get("reason_code"))


func _empty_network(up: Dictionary = {}, signature: String = "") -> RefCounted:
	var data := {"schema": Network.SCHEMA, "nodes": [], "edges": [], "pieces": [], "trails": [], "crossings": [], "metrics": {}}
	if not up.is_empty():
		data["header"] = {"origin_x_m": up.bounds.min_x, "origin_z_m": up.bounds.min_z, "region_signature": up.field.get_region_signature(),
			"hydrology_signature": signature if not signature.is_empty() else up.field.get_plan_signature()}
	return Network.from_bytes(var_to_bytes(data)).network


## A one-triangle slot whose content hash matches its arrays.
func _slot() -> Dictionary:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	var layers := PackedByteArray([0])
	var bytes := PackedByteArray()
	bytes.append_array(arrays[Mesh.ARRAY_VERTEX].to_byte_array())
	bytes.append_array(arrays[Mesh.ARRAY_INDEX].to_byte_array())
	bytes.append_array(layers)
	return {"is_valid": true, "arrays": arrays, "layers": layers, "sha256": Stage._sha(bytes)}


func _damaged(slots: Array) -> Array:
	var out: Array = slots.duplicate(true)
	out[7].layers = PackedByteArray([1])
	return out
