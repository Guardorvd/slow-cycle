extends SceneTree

const SurfaceAudit = preload("res://scripts/test/surface_audit_support.gd")
const Audit = preload("res://scripts/test/capture_audit_support.gd")
const Chunk = preload("res://scripts/world/road_chunk.gd")
const PathData = preload("res://scripts/world/road_path_data.gd")
const Carver = preload("res://scripts/world/terrain_carver.gd")
const SessionLogger = preload("res://scripts/core/slow_cycle_logger.gd")
var checks := 0
var failures := 0
var started := 0
var done := false
var runtime_rows: Array = []

func _init() -> void:
	started = Time.get_ticks_msec()
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - started > 55000:
		done = true
		printerr("SURFACE_CONTRACT_SUMMARY status=INCOMPLETE reason=TIMEOUT")
		quit(1)
	return false

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SURFACE_CHECK_FAIL " + label)

static func flat_fixture(wedge: bool = false) -> RefCounted:
	var path := PathData.new()
	for i in range(26):
		path.append_sample(Vector3(0, 0, -2.0 * i), Vector3.FORWARD, Vector3.UP, 0, 0, 0)
	var noise := FastNoiseLite.new()
	noise.seed = 184729
	var context: Dictionary = {}
	if wedge:
		var opposite: Array = []
		for i in range(26):
			opposite.append(Vector3(0.9 + 0.2 + i * 0.18, 0, -2.0 * i))
		context = {"terrain_side_mask": 1, "wedge_opposite_inner_verts": opposite, "is_fork_arm": true}
	return Chunk.prepare_geometry_data(path, 0, 25, 0, {"terrain_carver": Carver.new(184729), "noise": noise}, null, wedge, Vector3.FORWARD, context)

func _fixtures() -> void:
	var prep = flat_fixture()
	var report: Dictionary = SurfaceAudit.mesh_report(prep.terrain_arrays)
	_check(report.available and report.triangles > 0 and report.inverted == 0 and report.degenerate == 0, "actual prepared CW strips")
	_check(not SurfaceAudit.mesh_report([]).available, "empty mesh rejected")
	var reversed: Array = prep.terrain_arrays.duplicate(true)
	var indices: PackedInt32Array = reversed[Mesh.ARRAY_INDEX].duplicate()
	for i in range(0, indices.size(), 3):
		var temp := indices[i + 1]
		indices[i + 1] = indices[i + 2]
		indices[i + 2] = temp
	reversed[Mesh.ARRAY_INDEX] = indices
	_check(SurfaceAudit.mesh_report(reversed).inverted == report.triangles, "all reversed production indices rejected")
	var positions: PackedVector3Array = prep.terrain_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = prep.terrain_arrays[Mesh.ARRAY_NORMAL]
	_check(normals.size() == positions.size() and Array(normals).all(func(n: Vector3) -> bool: return n.is_finite() and n.y > 0), "actual generated outward normals")
	var matched: bool = prep.terrain_faces.size() == indices.size()
	var original_indices: PackedInt32Array = prep.terrain_arrays[Mesh.ARRAY_INDEX]
	for i in range(original_indices.size()):
		matched = matched and positions[original_indices[i]].is_equal_approx(prep.terrain_faces[i])
	_check(matched, "render indices and collision faces match")
	var wedge = flat_fixture(true)
	_check(SurfaceAudit.wedge_valid(wedge, true), "actual generated wedge range and CW")
	_check(not SurfaceAudit.wedge_valid(prep, true), "missing required wedge rejected")
	var faces := PackedVector3Array([prep.terrain_faces[0], prep.terrain_faces[1], prep.terrain_faces[2]])
	var center := (faces[0] + faces[1] + faces[2]) / 3.0
	var props: Array = [{"pos": center - Vector3.UP * 0.1}]
	_check(SurfaceAudit.contact_report(faces, props).valid, "normal contact on real production triangle")
	var missing: Dictionary = SurfaceAudit.contact_report(PackedVector3Array(), props)
	_check(not missing.valid and missing.missing_ground == 1 and missing.checked_contacts == 0, "removed actual faces counted as missing ground")
	_check(not SurfaceAudit.contact_report(faces, []).valid, "unexpected empty props rejected")
	_check(SurfaceAudit.contact_report(faces, [], true).valid, "declared barren fixture only")
	_check(SurfaceAudit.contact_report(faces, [{"pos": center + Vector3.UP * 0.06}]).floating == 1, "real surface plus 0.06m rejected")
	_check(SurfaceAudit.contact_report(faces, [{"pos": center - Vector3.UP * 0.36}]).buried == 1, "real surface minus 0.36m rejected")
	var chunk := Chunk.new()
	chunk.commit(prep, {}, {})
	root.add_child(chunk)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 10, center - Vector3.UP * 10, 4)
	query.hit_back_faces = false
	var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
	_check(not hit.is_empty() and hit.collider == chunk.terrain_body and hit.normal.y > 0, "real committed terrain ray hit from above")
	query.from = center - Vector3.UP * 10
	query.to = center + Vector3.UP * 10
	_check(root.world_3d.direct_space_state.intersect_ray(query).is_empty(), "collision back face rejected from below")
	chunk.free()
	await process_frame

func _runtime_seed(seed_value: int) -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	var manager = scene.get_node("WorldManager")
	manager.world_seed = seed_value
	manager.randomize_world_seed_on_start = false
	root.add_child(scene)
	var bike = scene.get_node("Bicycle")
	bike.set_physics_process(false)
	var trunk = manager.chunk_streamer.get_active_branch()
	var walked := 0.0
	while not trunk.is_fork_spawned:
		await process_frame
		if walked + 15 < trunk.road_path.get_total_distance():
			walked += 15
			var sample: Dictionary = trunk.road_path.get_sample_at_distance(walked)
			bike.global_position = sample.position + sample.normal * 0.4
			manager.chunk_streamer.update_streaming(bike.global_position, Vector3.ZERO, 0.016)
		if walked > 650:
			break
	_check(trunk.is_fork_spawned and trunk.child_branch_ids.size() == 1, "actual fork exists seed=%d" % seed_value)
	var rows: Array = []
	if trunk.is_fork_spawned:
		for branch_id in [trunk.branch_id, trunk.child_branch_ids[0]]:
			var branch = manager.chunk_streamer.branches[branch_id]
			var row := {"seed": seed_value, "branch_id": branch_id, "branch_seed": branch.road_logic.world_seed, "chunks": 0, "triangles": 0, "props": 0, "contacts": 0, "missing_ground": 0, "inverted": 0, "floating": 0, "buried": 0}
			for chunk in branch.active_chunks.values():
				var mesh = chunk.terrain_mesh_inst.mesh
				_check(mesh != null and mesh.get_surface_count() == 1, "real committed mesh seed=%d branch=%d" % [seed_value, branch_id])
				if mesh == null or mesh.get_surface_count() != 1:
					continue
				var arrays: Array = mesh.surface_get_arrays(0)
				var surface: Dictionary = SurfaceAudit.mesh_report(arrays)
				_check(surface.available and surface.inverted == 0 and surface.degenerate == 0, "real fork arm CW seed=%d branch=%d" % [seed_value, branch_id])
				var props: Array = []
				for name in ["PineMultiMesh", "BirchMultiMesh", "BoulderMultiMesh"]:
					var multimesh_node = chunk.get_node_or_null(name)
					if multimesh_node:
						for i in range(multimesh_node.multimesh.instance_count):
							props.append({"type": name, "pos": multimesh_node.multimesh.get_instance_transform(i).origin})
				var collision = chunk.terrain_body.get_child(0).shape
				_check(collision is ConcavePolygonShape3D, "real terrain collision shape")
				var faces: PackedVector3Array = collision.get_faces()
				var contact: Dictionary = SurfaceAudit.contact_report(faces, props, true)
				# An individual chunk may naturally have no trees; each real arm must have positive coverage.
				_check(contact.valid, "real fork props have ground seed=%d branch=%d result=%s" % [seed_value, branch_id, contact])
				row.chunks += 1
				row.triangles += surface.triangles
				row.inverted += surface.inverted
				row.props += contact.expected_props
				row.contacts += contact.checked_contacts
				row.missing_ground += contact.missing_ground
				row.floating += contact.floating
				row.buried += contact.buried
			_check(row.chunks > 0 and row.props > 0 and row.props == row.contacts, "nonempty actual arm coverage seed=%d branch=%d" % [seed_value, branch_id])
			rows.append(row)
	runtime_rows.append({"seed": seed_value, "actual_seed": manager.road_logic.world_seed, "arms": rows})
	scene.free()
	await process_frame
	await process_frame

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		done = true
		printerr("SURFACE_CONTRACT_SUMMARY status=INCOMPLETE reason=REAL_MULTIMESH_RENDERER_REQUIRED")
		quit(1)
		return
	await _fixtures()
	for seed_value in [184729, 42, 77777]:
		await _runtime_seed(seed_value)
	done = true
	var summary := {"status": "PASS" if failures == 0 else "FAIL", "checks": checks, "failures": failures, "runtime_forks": runtime_rows, "physics_replay": false}
	var directory := SessionLogger.argument("--audit-output-root", "user://capture_audits")
	var path := directory.path_join("surface-contract-%d.json" % OS.get_process_id())
	var error := Audit.write_json(path, summary)
	print("SURFACE_CONTRACT_SUMMARY status=%s checks=%d failures=%d metadata=%s io=%s" % [summary.status, checks, failures, path, error])
	await process_frame
	await process_frame
	quit(0 if failures == 0 and error.is_empty() else 1)
