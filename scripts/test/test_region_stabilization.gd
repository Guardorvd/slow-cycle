extends SceneTree

## Post-BC2 runtime stabilization, FAST group (headless, seconds; D3).
## Production code only, on small synthetic inputs:
##   A1  recovery on published trails follows their `directions` (FORWARD
##       only +1, REVERSE only -1, both / missing 0), for a bicycle facing
##       either way along the trail;
##   A2  RegionStreamer.ensure_around builds every wanted collision patch
##       after a short move whose first streaming pass frees one patch and
##       builds one (the active count is unchanged after that pass);
##   A3  RegionBakeCache.save reports a failed write (reason and file);
##   A4  a bake whose result lands between the snapshot and is_alive() is
##       not a crash; a thread that ends without a result still is;
##   A5  RealizedRoadNetwork.trail_graph of an empty network does not fail
##       and is not a connected riding network.
## Output: STAB_CHECK lines for failures and
## STAB_SUMMARY checks=.. failures=.. completed=true.
const WorldScene = preload("res://scenes/region/region_world.tscn")
const Streamer = preload("res://scripts/world/region_streamer.gd")
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")

var _checks: int = 0
var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"label": label, "detail": str(detail)})
		print("STAB_CHECK FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	var t0: int = Time.get_ticks_usec()
	await _recovery_directions()
	await _streamer_progress()
	_cache_write_failure()
	await _bake_race()
	_empty_network()
	print("STAB_SUMMARY checks=%d failures=%d seconds=%.2f completed=true" % [_checks, _failures.size(), (Time.get_ticks_usec() - t0) / 1e6])
	quit(0 if _failures.is_empty() else 1)


## A straight 200 m trail along +x at z = 50, 5 m samples.
func _trail(directions: Variant) -> Dictionary:
	var line := {"s": PackedFloat64Array(), "x": PackedFloat64Array(), "y": PackedFloat64Array(), "z": PackedFloat64Array()}
	for k in range(41):
		line.s.append(5.0 * k)
		line.x.append(5.0 * k)
		line.y.append(0.0)
		line.z.append(50.0)
	var trail := {"id": "trail:t", "line": line}
	if directions != null:
		trail["directions"] = directions
	return trail


func _recovery_directions() -> void:
	_check(RegionWorld.trail_recommended(_trail(["FORWARD"])) == 1, "FORWARD-only trail recommends +1")
	_check(RegionWorld.trail_recommended(_trail(["REVERSE"])) == -1, "REVERSE-only trail recommends -1")
	_check(RegionWorld.trail_recommended(_trail(["FORWARD", "REVERSE"])) == 0, "two-way trail recommends 0")
	_check(RegionWorld.trail_recommended(_trail(null)) == 0, "trail without directions (older record) recommends 0")
	var scene: Node3D = WorldScene.instantiate()
	scene.auto_bake = false
	root.add_child(scene)
	await process_frame
	var bike: Node3D = scene.get_bike()
	bike.process_mode = Node.PROCESS_MODE_DISABLED
	var query := Vector3(100.0, 0.0, 51.0)
	# expected travel along +x (sign) per directions and bicycle heading.
	var cases: Array = [[["FORWARD"], 1, 1], [["FORWARD"], -1, 1], [["REVERSE"], 1, -1], [["REVERSE"], -1, -1], [["FORWARD", "REVERSE"], 1, 1],
		[["FORWARD", "REVERSE"], -1, -1], [null, 1, 1], [null, -1, -1]]
	for case: Array in cases:
		scene._set_recovery_from_network({"pieces": [], "trails": [_trail(case[0])]})
		# The bicycle faces +x or -x (its forward is -basis.z).
		bike.global_transform = Transform3D(Basis.looking_at(Vector3(case[1], 0.0, 0.0), Vector3.UP), Vector3(100.0, 0.5, 51.0))
		var pose: Transform3D = scene.request_bike_recovery(query)
		var facing: Vector3 = -pose.basis.z
		var label: String = "recovery %s, bike heading %+d" % [str(case[0]), case[1]]
		_check(signf(facing.x) == case[2] and absf(facing.z) < 1e-3, label + ": faces travel", facing)
		# Stepped back against travel by RECOVERY_BACKOFF_M (20 m).
		_check(is_equal_approx(pose.origin.x, 100.0 - 20.0 * case[2]), label + ": stepped back against travel", pose.origin)
	scene.queue_free()
	await process_frame


## A region of 8 x 8 synthetic tiles, one flat triangle per 64 m patch.
func _tiles() -> Array:
	var tiles: Array = []
	for k in range(64):
		var vertices := PackedVector3Array()
		var indices := PackedInt32Array()
		var slot := {"layers": PackedByteArray(), "patches": PackedByteArray()}
		for patch in range(64):
			var x: float = (patch % 8) * 64.0 + 8.0
			var z: float = (patch / 8) * 64.0 + 8.0
			var base: int = vertices.size()
			vertices.append_array([Vector3(x, 0.0, z), Vector3(x + 40.0, 0.0, z), Vector3(x, 0.0, z + 40.0)])
			indices.append_array([base, base + 1, base + 2])
			slot.layers.append(Bake.LAYER_TERRAIN)
			slot.patches.append(patch)
		Bake._patch_order(slot)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_INDEX] = indices
		tiles.append({"origin": [(k % 8) * 512.0, (k / 8) * 512.0], "arrays": arrays, "layers": slot.layers, "patches": slot.patches, "patch_order": slot.patch_order,
			"patch_offsets": slot.patch_offsets})
	return tiles


## Patch keys whose centre lies within the streamer's reach of p (the
## streamer's own rule, restated).
func _wanted(p: Vector3) -> Dictionary:
	var out: Dictionary = {}
	for k in range(64):
		for patch in range(64):
			var c := Vector2((k % 8) * 512.0 + (patch % 8 + 0.5) * 64.0, (k / 8) * 512.0 + (patch / 8 + 0.5) * 64.0)
			if c.distance_to(Vector2(p.x, p.z)) <= Streamer.COLLISION_RADIUS_M + Streamer.PATCH_M * 0.71:
				out[k * 64 + patch] = true
	return out


func _streamer_progress() -> void:
	var streamer: Node3D = Streamer.new()
	streamer._tiles = _tiles()
	root.add_child(streamer)
	var a := Vector3(1000.0, 0.0, 1000.0)
	# The audit's counterexample: a short move whose first pass frees exactly
	# one patch and builds one (COMMITS_PER_FRAME), so the active count stays.
	var b := Vector3.INF
	var before: Dictionary = _wanted(a)
	for step in range(1, 200):
		var p: Vector3 = a + Vector3(float(step), 0.0, 0.0)
		var after: Dictionary = _wanted(p)
		var leaving: int = before.keys().filter(func(key: int) -> bool: return not after.has(key)).size()
		var entering: int = after.keys().filter(func(key: int) -> bool: return not before.has(key)).size()
		if leaving == 1 and entering >= 2:
			b = p
			break
	_check(b != Vector3.INF, "a short move frees one patch and needs several", b)
	streamer.ensure_around(a)
	_check(streamer._active.size() == before.size() and before.keys().all(func(key: int) -> bool: return streamer._active.has(key)), "every wanted patch at A",
		[streamer._active.size(), before.size()])
	if b != Vector3.INF:
		var wanted: Dictionary = _wanted(b)
		streamer.ensure_around(b)
		var missing: Array = wanted.keys().filter(func(key: int) -> bool: return not streamer._active.has(key))
		_check(missing.is_empty(), "every wanted patch after the short move", missing)
		_check(streamer._active.size() == wanted.size(), "no patch out of reach after the short move", [streamer._active.size(), wanted.size()])
	streamer.queue_free()
	await process_frame


func _cache_write_failure() -> void:
	# A file where the cache directory belongs: nothing can be written there.
	var cache_key: String = "stabilization_test_unwritable"
	DirAccess.make_dir_recursive_absolute(Cache.ROOT)
	var blocker := FileAccess.open(Cache.directory_of(cache_key), FileAccess.WRITE)
	blocker.store_string("not a directory")
	blocker.close()
	var network: Dictionary = Network.from_bytes(var_to_bytes({"schema": Network.SCHEMA}))
	var saved: Dictionary = Cache.save(cache_key, {"network": network.network, "tiles": [], "bridges": {}, "water": {}, "spawn": {}, "manifest": {}})
	_check(not saved.is_valid and saved.reason_code == "ERR_BAKE_WRITE" and saved.get("file", "") == "network.bin", "failed cache write is reported with its file", saved)
	DirAccess.remove_absolute(Cache.directory_of(cache_key))


## A job whose result is published after the first snapshot (the race).
class LateJob extends RegionWorld.BakeJob:
	var late: Variant = null
	var _calls: int = 0

	func snapshot() -> Array:
		_calls += 1
		return ["network", 0.4, null if _calls == 1 else late]


func _bake_race() -> void:
	for late: Variant in [{"is_valid": false, "reason_code": "ERR_TEST_BAKE_RESULT"}, null]:
		var scene: Node3D = WorldScene.instantiate()
		scene.auto_bake = false
		root.add_child(scene)
		await process_frame
		scene.session_seed = -77
		var job := LateJob.new()
		job.late = late
		var thread := Thread.new()
		thread.start(func() -> void: pass)
		while thread.is_alive():
			await process_frame
		scene._job = job
		scene._thread = thread
		scene._process(0.0)
		var expected: String = "ERR_TEST_BAKE_RESULT" if late != null else "ERR_BAKE_CRASHED"
		_check(scene.failed and scene.failure.get("reason_code", "") == expected, "finished thread, result %s -> %s" % ["late" if late != null else "none", expected],
			scene.failure.get("reason_code", ""))
		thread.wait_to_finish()
		if scene.failure.has("diagnostics_path"):
			DirAccess.remove_absolute(scene.failure.diagnostics_path)
		scene.queue_free()
		await process_frame


func _empty_network() -> void:
	var graph: Dictionary = Network.trail_graph({"nodes": [], "edges": [], "pieces": [], "trails": []})
	_check(graph.get("vertices", -1) == 0 and not graph.strongly_connected and graph.get("empty", false), "empty network: no vertices, not a riding network", graph)
