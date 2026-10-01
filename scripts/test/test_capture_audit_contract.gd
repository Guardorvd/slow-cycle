extends SceneTree

const Audit = preload("res://scripts/test/capture_audit_support.gd")
const PathData = preload("res://scripts/world/road_path_data.gd")
var audit: Audit = Audit.new()
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("CONTRACT_FAIL " + label)

func _process(_delta: float) -> bool:
	if audit.tree and not audit.finished and not audit.alive():
		audit.finish(1)
	return false

func _run() -> void:
	if not audit.begin(self, "test_capture_audit_contract", [184729]):
		audit.finish(1)
		return
	var fixture: String = audit.option("--audit-case")
	if not fixture.is_empty():
		await _end_to_end(fixture)
		return
	_check(Audit.seed_reason(42, 42, 42, 42).is_empty(), "matching effective seed accepted")
	_check(Audit.seed_reason(42, 42, 77777, 42) == "SEED_MISMATCH", "generator mismatch rejected")
	_check(Audit.seed_reason(42, 42, 42, 77777) == "SEED_MISMATCH", "streamer mismatch rejected")
	var empty = PathData.new()
	_check(Audit.path_reason(empty, 0) == "PATH_MISSING", "empty real PathData rejected")
	var retained = PathData.new()
	retained.append_sample(Vector3.ZERO, Vector3.FORWARD, Vector3.UP, 0, 0, 0)
	retained.append_sample(Vector3(0, 0, -10), Vector3.FORWARD, Vector3.UP, 0, 0, 0)
	retained.cumulative_distances[0] = 100.0
	retained.cumulative_distances[1] = 110.0
	_check(Audit.path_reason(retained, 99) == "TARGET_OUTSIDE_PATH", "before retained beginning rejected")
	_check(Audit.path_reason(retained, 111) == "TARGET_OUTSIDE_PATH", "beyond last sample rejected")
	_check(Audit.path_reason(retained, NAN) == "TARGET_NONFINITE", "nonfinite target rejected")
	_check(Audit.path_reason(retained, 105).is_empty(), "retained interval accepted")
	_check(Audit.camera_reason(root, null) == "CAMERA_MISSING", "missing actual camera rejected")
	_check(Audit.mesh_reason(null) == "MESH_MISSING", "missing mesh rejected")
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = ArrayMesh.new()
	root.add_child(mesh_instance)
	_check(Audit.mesh_reason(mesh_instance) == "MESH_MISSING", "empty committed mesh rejected")
	mesh_instance.free()
	_check(Audit.image_reason(null, Vector2i(16, 16)) == "IMAGE_MISSING", "null Image rejected")
	_check(Audit.image_reason(Image.new(), Vector2i(16, 16)) == "IMAGE_EMPTY", "empty Image rejected")
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6, 1.0))
	_check(Audit.image_reason(image, Vector2i(32, 16)) == "IMAGE_SIZE_MISMATCH", "wrong viewport size rejected")
	var png := audit.run_dir.path_join("fixture-valid.png")
	_check(Audit.save_image(image, Vector2i(16, 16), png).is_empty(), "real Image PNG write and reload accepted")
	_check(Audit.save_image(image, Vector2i(16, 16), png) == "PNG_ALREADY_EXISTS", "old PNG is not overwritten")
	_check(Audit.verify_png(png, Vector2i(32, 16)) == "PNG_SIZE_MISMATCH", "reload dimensions checked")
	_check(Audit.verify_png(audit.run_dir.path_join("missing.png"), Vector2i(16, 16)) == "PNG_MISSING", "missing file rejected")
	var blocked := audit.run_dir.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("file, not a directory")
	file.close()
	_check(Audit.save_image(image, Vector2i(16, 16), blocked.path_join("bad.png")).begins_with("PNG_SAVE_FAILED:"), "real write failure rejected")
	var bad_png := audit.run_dir.path_join("broken.png")
	file = FileAccess.open(bad_png, FileAccess.WRITE)
	file.store_string("not a PNG")
	file.close()
	_check(Audit.verify_png(bad_png, Vector2i(16, 16)) == "PNG_UNREADABLE", "corrupt PNG rejected")
	_check(Audit.write_json(blocked.path_join("bad.json"), {"fixture": true}).begins_with("METADATA_OPEN_FAILED:"), "metadata write failure rejected")
	if await audit.start_world(184729):
		var branch = audit.streamer.get_active_branch()
		_check(Audit.committed_chunk(branch, 2.5).is_empty() == false, "real production road and terrain meshes cover start")
		_check(Audit.fork_reason(audit.streamer, null) == "FORK_MISSING", "missing fork rejected")
		var fork_parent = branch
		while audit.alive() and not fork_parent.is_fork_spawned:
			var next_s: float = minf(650.0, audit.last_s + 15.0)
			if Audit.path_reason(fork_parent.road_path, next_s).is_empty():
				audit.position_at(next_s)
			await process_frame
		if audit.alive():
			_check(Audit.fork_reason(audit.streamer, fork_parent).is_empty(), "both real fork arm meshes accepted")
			# Missing geometry fixture hides one real MeshInstance, then restores it.
			var alt = audit.streamer.branches[fork_parent.child_branch_ids[0]]
			var visibility: Array = []
			for chunk in alt.active_chunks.values():
				visibility.append([chunk.road_mesh_inst, chunk.road_mesh_inst.visible])
				chunk.road_mesh_inst.visible = false
			_check(Audit.fork_reason(audit.streamer, fork_parent) == "FORK_ARM_MISSING", "absent visible fork arm rejected")
			for entry in visibility:
				entry[0].visible = entry[1]
		_check(Audit.seed_reason(int(audit.manifest.sessions[-1].expected_effective_seed), audit.manager.world_seed, audit.manager.road_logic.world_seed, audit.streamer.world_seed).is_empty(), "real initialized generator seed matches")
	else:
		_check(false, "real world initialized within deadline")
	audit.close_world()
	# Test the real deadline guard, without sleeping or weakening the time budget.
	var deadline_fixture: Audit = Audit.new()
	deadline_fixture.started_ms = Time.get_ticks_msec() - deadline_fixture.timeout_ms
	_check(not deadline_fixture.alive() and deadline_fixture.failure == "TIMEOUT", "deadline returns incomplete")
	print("CAPTURE_CONTRACT_COMPLETE checks=%d failures=%d expected_io_operations=2" % [checks, failures])
	if failures > 0:
		audit.reject("CONTRACT_FAILURE")
	audit.finish(0)

func _end_to_end(fixture: String) -> void:
	if not await audit.start_world(184729):
		audit.finish(1)
		return
	var item := {"name": "e2e.png", "dist": 2.5, "mode": "fp"}
	match fixture:
		"seed_mismatch":
			# Change requested expectation, never the real generator.
			audit.manifest.sessions[-1].expected_effective_seed = audit.manager.road_logic.world_seed + 1
		"missing_target":
			item.dist = audit.streamer.get_active_branch().road_path.get_total_distance() + 10000.0
		"save_failure":
			var file := FileAccess.open(audit.run_dir.path_join("blocked"), FileAccess.WRITE)
			file.store_string("fixture external I/O boundary")
			file.close()
			item.name = "blocked/e2e.png"
		_:
			audit.reject("UNKNOWN_FIXTURE")
			audit.finish(1)
			return
	await audit.capture(item)
	audit.finish(1)
