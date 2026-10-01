extends RefCounted
## Shared guards for the two capture tools. No production generation changes.

var tree: SceneTree
var scene: Node3D
var manager: Node3D
var bike: CharacterBody3D
var streamer: Node3D
var drone: Camera3D
var manifest: Dictionary = {}
var run_dir: String
var started_ms: int
var timeout_ms: int = 55000
var failure: String = ""
var finished: bool = false
var checkpoint: Dictionary = {}
var last_s: float = 0.0
var route_choices: Array = []

func option(key: String, fallback: String = "") -> String:
	var value := fallback
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with(key + "="):
			value = arg.substr(key.length() + 1)
	return value

func cli_seed() -> Variant:
	# Same valid-integer and user-argument priority as WorldManager.
	var value: Variant = null
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--seed=") and arg.substr(7).is_valid_int():
			value = arg.substr(7).to_int()
	return value

func begin(owner: SceneTree, tool: String, defaults: Array) -> bool:
	tree = owner
	started_ms = Time.get_ticks_msec()
	timeout_ms = int(clampf(option("--audit-timeout", "55").to_float(), 0.01, 55.0) * 1000.0)
	var run_id := "%s-%d-%s" % [Time.get_datetime_string_from_system(true).replace(":", "-"), OS.get_process_id(), Crypto.new().generate_random_bytes(8).hex_encode()]
	var output_root := option("--audit-output-root", "user://capture_audits")
	run_dir = ProjectSettings.globalize_path(output_root.path_join(run_id))
	if DirAccess.dir_exists_absolute(run_dir) or FileAccess.file_exists(run_dir):
		return reject("RUN_ID_COLLISION")
	if DirAccess.make_dir_recursive_absolute(run_dir) != OK:
		return reject("OUTPUT_DIRECTORY_UNAVAILABLE")
	var revision_output: Array = []
	var status_output: Array = []
	var git_revision := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], revision_output, true)
	var git_status := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], status_output, true)
	var sources: Array[String] = []
	_collect_sources("res://scripts", sources)
	_collect_sources("res://scenes", sources)
	_collect_sources("res://assets/materials", sources)
	_collect_sources("res://assets/shaders", sources)
	sources.append("res://project.godot")
	sources.sort()
	var digest_parts := PackedStringArray()
	var source_hashes: Dictionary = {}
	for source in sources:
		source_hashes[source] = FileAccess.get_sha256(source)
		digest_parts.append(source + ":" + source_hashes[source])
	manifest = {
		"schema": 1, "run_id": run_id, "tool": tool, "defaults": defaults,
		"cli_override": cli_seed(), "revision": str(revision_output[0]).strip_edges() if git_revision == 0 and not revision_output.is_empty() else null,
		"working_tree_dirty": not str(status_output[0]).strip_edges().is_empty() if git_status == 0 and not status_output.is_empty() else null,
		"source_digest": "\n".join(digest_parts).sha256_text(), "source_files": sources, "source_hashes": source_hashes,
		"godot": Engine.get_version_info(), "display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(),
		"scene": "res://scenes/main.tscn", "capture_kind": "teleport; no physical ride",
		"timeout_seconds": timeout_ms / 1000.0, "frames": [], "sessions": [], "status": "RUNNING"
	}
	if git_revision != 0 or git_status != 0:
		return reject("PROVENANCE_UNAVAILABLE")
	var manifest_error := write_json(run_dir.path_join("manifest.json"), manifest)
	return true if manifest_error.is_empty() else reject(manifest_error)

func _collect_sources(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	for filename in dir.get_files():
		if filename.ends_with(".gd") or filename.ends_with(".tscn") or filename.ends_with(".tres") or filename.ends_with(".gdshader"):
			result.append(path.path_join(filename))
	for subdir in dir.get_directories():
		_collect_sources(path.path_join(subdir), result)

func reject(reason: String) -> bool:
	if failure.is_empty():
		failure = reason
	return false

func alive() -> bool:
	if not failure.is_empty():
		return false
	if Time.get_ticks_msec() - started_ms >= timeout_ms:
		return reject("TIMEOUT")
	return true

func start_world(requested: int) -> bool:
	close_world()
	scene = load("res://scenes/main.tscn").instantiate()
	manager = scene.get_node("WorldManager")
	bike = scene.get_node("Bicycle")
	manager.world_seed = requested
	manager.randomize_world_seed_on_start = false
	# Configuration precedes add_child, including when called from _process.
	tree.root.add_child(scene)
	bike.set_physics_process(false)
	bike.velocity = Vector3.ZERO
	while alive() and (not manager.is_node_ready() or manager.road_logic == null or manager.chunk_streamer == null):
		await tree.process_frame
	if not alive():
		return false
	streamer = manager.chunk_streamer
	var expected: int = int(cli_seed()) if cli_seed() != null else requested
	var reason := seed_reason(expected, manager.world_seed, manager.road_logic.world_seed, streamer.world_seed)
	manifest.sessions.append({"configured_seed": requested, "expected_effective_seed": expected, "actual_generator_seed": manager.road_logic.world_seed, "manager_seed": manager.world_seed, "streamer_seed": streamer.world_seed,
		"generation_config": {"randomize_on_start": manager.randomize_world_seed_on_start, "ahead_m": streamer.AHEAD_DISTANCE, "behind_m": streamer.BEHIND_DISTANCE, "preload_m": streamer.preload_distance, "first_fork_m": streamer.first_fork_distance, "fork_interval_m": streamer.fork_interval_dist, "max_chunks_per_frame": streamer.MAX_CHUNKS_PER_FRAME, "safety_corridor_m": streamer.safety_corridor_margin, "fork_safety_radius_m": streamer.fork_safety_radius}})
	if not reason.is_empty():
		return reject(reason)
	drone = Camera3D.new()
	drone.name = "AuditDrone"
	drone.fov = 70.0
	scene.add_child(drone)
	drone.current = false
	last_s = 0.0
	route_choices = []
	# Signature before pruning, always the same explicit 0..100 m interval.
	while alive():
		var branch = streamer.get_active_branch()
		if branch and branch.road_path and path_reason(branch.road_path, 100.0).is_empty():
			checkpoint = {"range_m": [0, 100], "step_m": 2, "signature": geometry_signature(branch.road_path)}
			return true
		await tree.process_frame
	return false

static func seed_reason(expected: int, configured: int, generated: int, streaming: int) -> String:
	return "SEED_MISMATCH" if expected != configured or expected != generated or expected != streaming else ""

static func path_reason(path: RefCounted, target: float) -> String:
	if path == null or path.size() < 2 or path.cumulative_distances.size() != path.size():
		return "PATH_MISSING"
	if not is_finite(target):
		return "TARGET_NONFINITE"
	var first: float = path.cumulative_distances[0]
	var last: float = path.cumulative_distances[-1]
	if not is_finite(first) or not is_finite(last) or first >= last:
		return "PATH_INVALID"
	if target < first or target > last:
		return "TARGET_OUTSIDE_PATH"
	return ""

static func geometry_signature(path: RefCounted) -> String:
	var data := PackedStringArray()
	for s in range(0, 101, 2):
		var sample: Dictionary = path.get_sample_at_distance(float(s))
		data.append("%s|%s|%s" % [sample.position, sample.tangent, sample.normal])
	return "\n".join(data).sha256_text()

static func actual_distance(path: RefCounted, point: Vector3) -> float:
	var best_error := INF
	var best_s := NAN
	for i in range(path.size() - 1):
		var a: Vector3 = path.points[i]
		var segment: Vector3 = path.points[i + 1] - a
		if segment.length_squared() < 0.000001:
			continue
		var fraction := clampf((point - a).dot(segment) / segment.length_squared(), 0, 1)
		var error := point.distance_squared_to(a + segment * fraction)
		if error < best_error:
			best_error = error
			best_s = lerpf(path.cumulative_distances[i], path.cumulative_distances[i + 1], fraction)
	return best_s

static func fork_reason(stream: Node3D, parent: RefCounted) -> String:
	if parent == null or not parent.is_fork_spawned or parent.child_branch_ids.is_empty():
		return "FORK_MISSING"
	var alternate = stream.branches.get(parent.child_branch_ids[0])
	if alternate == null or alternate.parent_branch_id != parent.branch_id or alternate.fork_node_pos.distance_to(parent.fork_node_pos) > 0.001:
		return "FORK_ARM_MISSING"
	if committed_chunk(parent, parent.distance_at_last_fork + 4.0).is_empty() or committed_chunk(alternate, 4.0).is_empty():
		return "FORK_ARM_MISSING"
	return ""

static func mesh_reason(instance: MeshInstance3D) -> String:
	if not is_instance_valid(instance) or not instance.is_inside_tree() or not instance.is_visible_in_tree() or instance.mesh == null or instance.mesh.get_surface_count() == 0:
		return "MESH_MISSING"
	var count := 0
	for surface in range(instance.mesh.get_surface_count()):
		var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		count += vertices.size()
	return "MESH_EMPTY" if count < 3 else ""

static func _point_in_triangle_xz(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(point.x - a.x, point.z - a.z)
	var denom := v0.cross(v1)
	if absf(denom) < 0.000001:
		return false
	var u := v2.cross(v1) / denom
	var v := v0.cross(v2) / denom
	return u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001

static func committed_chunk(branch: RefCounted, target: float) -> Dictionary:
	if branch == null or not path_reason(branch.road_path, target).is_empty():
		return {}
	var point: Vector3 = branch.road_path.get_sample_at_distance(target).position
	for id in branch.active_chunks:
		var chunk = branch.active_chunks[id]
		if not is_instance_valid(chunk) or chunk.is_queued_for_deletion():
			continue
		if not mesh_reason(chunk.road_mesh_inst).is_empty() or not mesh_reason(chunk.terrain_mesh_inst).is_empty():
			continue
		# Test actual committed triangles, not stale sample indices after pruning.
		var faces: PackedVector3Array = chunk.road_mesh_inst.mesh.get_faces()
		var covers := false
		var first_s: float = INF
		var last_s: float = -INF
		for i in range(0, faces.size(), 3):
			var a: Vector3 = chunk.road_mesh_inst.to_global(faces[i])
			var b: Vector3 = chunk.road_mesh_inst.to_global(faces[i + 1])
			var c: Vector3 = chunk.road_mesh_inst.to_global(faces[i + 2])
			if _point_in_triangle_xz(point, a, b, c):
				var normal := (b - a).cross(c - a)
				if absf(normal.y) > 0.000001:
					var road_y := a.y - (normal.x * (point.x - a.x) + normal.z * (point.z - a.z)) / normal.y
					if absf(road_y - point.y) <= 0.5:
						covers = true
		if covers:
			for vertex in faces:
				var idx: int = branch.road_path.find_closest_index(chunk.road_mesh_inst.to_global(vertex))
				var s: float = branch.road_path.cumulative_distances[idx]
				first_s = minf(first_s, s)
				last_s = maxf(last_s, s)
			if target < first_s - 0.001 or target > last_s + 0.001:
				continue
			return {"chunk_id": id, "retained_interval_m": [first_s, last_s], "end_distance_m": branch.chunk_end_distances.get(id), "road_triangles": faces.size() / 3, "terrain_triangles": chunk.terrain_mesh_inst.mesh.get_faces().size() / 3}
	return {}

func position_at(target: float) -> Dictionary:
	var branch = streamer.get_active_branch()
	if branch == null:
		reject("BRANCH_MISSING")
		return {}
	var reason := path_reason(branch.road_path, target)
	if not reason.is_empty():
		reject(reason)
		return {}
	var sample: Dictionary = branch.road_path.get_sample_at_distance(target)
	if not sample.position.is_finite() or not sample.tangent.is_finite() or not sample.normal.is_finite() or sample.tangent.length_squared() < 0.5 or sample.normal.length_squared() < 0.5:
		reject("SAMPLE_INVALID")
		return {}
	bike.global_position = sample.position + sample.normal * 0.4
	var forward := Vector3(sample.tangent.x, 0, sample.tangent.z).normalized()
	if forward.is_zero_approx():
		reject("SAMPLE_TANGENT_INVALID")
		return {}
	bike.global_basis = Basis.looking_at(forward, Vector3.UP)
	bike.velocity = Vector3.ZERO
	var before: int = streamer.active_branch_id
	streamer.update_streaming(bike.global_position, sample.tangent * 12.0, 0.016)
	if before != streamer.active_branch_id:
		route_choices.append({"from": before, "to": streamer.active_branch_id, "local_s": target, "tick": Engine.get_physics_frames()})
		reject("UNEXPECTED_BRANCH_CHANGE")
		return {}
	last_s = target
	return sample

func advance_to(target: float) -> bool:
	while alive() and last_s < target:
		var next_s := minf(target, last_s + 15.0)
		var branch = streamer.get_active_branch()
		if branch and path_reason(branch.road_path, next_s).is_empty():
			if position_at(next_s).is_empty():
				return false
		await tree.process_frame
	return alive()

func select_camera(mode: String, sample: Dictionary, altitude: float) -> Camera3D:
	var rig = bike.get_node_or_null("CameraRig")
	if mode == "drone":
		drone.global_position = sample.position + Vector3(0, altitude, 25)
		drone.look_at(sample.position, Vector3.UP)
		drone.make_current()
		return drone
	if not rig:
		return null
	var camera: Camera3D = rig.first_person_cam if mode == "fp" else rig.third_person_cam
	if camera:
		rig.is_first_person = mode == "fp"
		camera.make_current()
	return camera

static func camera_reason(viewport: Viewport, camera: Camera3D) -> String:
	if not is_instance_valid(camera) or not camera.is_inside_tree() or viewport.get_camera_3d() != camera:
		return "CAMERA_MISSING"
	if not camera.global_position.is_finite() or not camera.global_basis.is_finite():
		return "CAMERA_INVALID"
	return ""

static func image_reason(img: Image, size: Vector2i) -> String:
	if img == null:
		return "IMAGE_MISSING"
	if img.is_empty() or img.get_width() <= 0 or img.get_height() <= 0:
		return "IMAGE_EMPTY"
	if img.get_size() != size:
		return "IMAGE_SIZE_MISMATCH"
	return ""

static func verify_png(path: String, expected_size: Vector2i) -> String:
	if not FileAccess.file_exists(path):
		return "PNG_MISSING"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() == 0:
		return "PNG_UNREADABLE"
	file.close()
	var reloaded := Image.new()
	if reloaded.load(path) != OK:
		return "PNG_UNREADABLE"
	return "PNG_SIZE_MISMATCH" if reloaded.get_size() != expected_size else ""

static func save_image(img: Image, size: Vector2i, path: String) -> String:
	var reason := image_reason(img, size)
	if not reason.is_empty():
		return reason
	if FileAccess.file_exists(path):
		return "PNG_ALREADY_EXISTS"
	var error := img.save_png(path)
	if error != OK:
		return "PNG_SAVE_FAILED:%d" % error
	return verify_png(path, size)

static func write_json(path: String, data: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "METADATA_OPEN_FAILED:%d" % FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "METADATA_WRITE_FAILED:%d" % error
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return "METADATA_UNREADABLE" if not parsed is Dictionary or JSON.stringify(parsed) != JSON.stringify(JSON.parse_string(JSON.stringify(data))) else ""

static func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func pose(t: Transform3D) -> Dictionary:
	return {"position": vec(t.origin), "basis": [vec(t.basis.x), vec(t.basis.y), vec(t.basis.z)]}

func capture(item: Dictionary, extra: Dictionary = {}) -> bool:
	var target: float = item.dist
	var branch = streamer.get_active_branch()
	var camera: Camera3D
	var sample: Dictionary
	var coverage: Dictionary
	# Settle only after both coverage and pose are present; frame count alone is insufficient.
	var settled := 0
	while alive() and settled < 12:
		sample = position_at(target)
		if sample.is_empty():
			return false
		camera = select_camera(item.mode, sample, item.get("altitude", 0.0))
		var reason := camera_reason(tree.root, camera)
		if not reason.is_empty():
			return reject(reason)
		coverage = committed_chunk(branch, target)
		if extra.has("fork"):
			var fork_error := fork_reason(streamer, branch)
			if not fork_error.is_empty():
				return reject(fork_error)
		settled = settled + 1 if not coverage.is_empty() else 0
		await tree.process_frame
	if not alive():
		return false
	if DisplayServer.get_name() == "headless":
		return reject("RENDERER_UNAVAILABLE")
	await RenderingServer.frame_post_draw
	if not alive():
		return false
	var seed_error := seed_reason(int(manifest.sessions[-1].expected_effective_seed), manager.world_seed, manager.road_logic.world_seed, streamer.world_seed)
	if not seed_error.is_empty():
		return reject(seed_error)
	if bike.global_position.distance_to(sample.position + sample.normal * 0.4) > 0.01:
		return reject("BIKE_POSE_MISMATCH")
	if not camera_reason(tree.root, camera).is_empty():
		return reject(camera_reason(tree.root, camera))
	coverage = committed_chunk(branch, target)
	if coverage.is_empty():
		return reject("COMMITTED_TARGET_MISSING")
	if extra.has("fork"):
		var fork_error := fork_reason(streamer, branch)
		if not fork_error.is_empty():
			return reject(fork_error)
	var actual_s := actual_distance(branch.road_path, sample.position)
	if not is_finite(actual_s) or absf(actual_s - target) > 0.01:
		return reject("ACTUAL_DISTANCE_MISMATCH")
	var size := Vector2i(tree.root.get_visible_rect().size)
	var texture := tree.root.get_texture()
	if texture == null:
		return reject("TEXTURE_MISSING")
	var image := texture.get_image()
	var png_path := run_dir.path_join(item.name)
	var save_error := save_image(image, size, png_path)
	if not save_error.is_empty():
		return reject(save_error)
	var metadata := {
		"run_id": manifest.run_id, "revision": manifest.revision, "source_digest": manifest.source_digest, "working_tree_dirty": manifest.working_tree_dirty,
		"godot": manifest.godot, "renderer": manifest.renderer, "driver": manifest.driver,
		"default_seeds": manifest.defaults, "cli_override": manifest.cli_override, "seeds": manifest.sessions[-1],
		"branch_id": branch.branch_id, "branch_seed": branch.road_logic.world_seed, "route_choices": route_choices.duplicate(true),
		"requested_local_s": target, "actual_local_s": actual_s, "sample": {"position": vec(sample.position), "tangent": vec(sample.tangent), "normal": vec(sample.normal)},
		"path_range": [branch.road_path.cumulative_distances[0], branch.road_path.cumulative_distances[-1]], "committed_coverage": coverage,
		"bike": pose(bike.global_transform), "camera": {"path": str(camera.get_path()), "mode": item.mode, "pose": pose(camera.global_transform), "fov": camera.fov},
		"geometry_checkpoint": checkpoint, "viewport_size": [size.x, size.y], "png_size": [image.get_width(), image.get_height()],
		"png": png_path, "save_png_error": OK, "png_reloaded": true, "status": "CAPTURED", "extra": extra
	}
	var meta_path := png_path.trim_suffix(".png") + ".json"
	var meta_error := write_json(meta_path, metadata)
	if not meta_error.is_empty():
		return reject(meta_error)
	manifest.frames.append({"png": png_path, "metadata": meta_path, "seed": manager.road_logic.world_seed, "local_s": target})
	var manifest_error := write_json(run_dir.path_join("manifest.json"), manifest)
	if not manifest_error.is_empty():
		return reject(manifest_error)
	print("[CAPTURED] seed=%d s=%.3f camera=%s png=%s" % [manager.road_logic.world_seed, target, item.mode, png_path])
	return true

func finish(expected_frames: int) -> void:
	if finished:
		return
	finished = true
	if failure.is_empty() and manifest.get("frames", []).size() != expected_frames:
		reject("FRAME_COUNT_MISMATCH")
	manifest["expected_frames"] = expected_frames
	manifest["status"] = "CAPTURE_COMPLETE" if failure.is_empty() else "INCOMPLETE"
	manifest["reason"] = failure
	manifest["elapsed_seconds"] = (Time.get_ticks_msec() - started_ms) / 1000.0
	if not run_dir.is_empty() and DirAccess.dir_exists_absolute(run_dir):
		var reason := write_json(run_dir.path_join("manifest.json"), manifest)
		if not reason.is_empty():
			reject(reason)
	close_world()
	print("AUDIT_COMPLETE status=%s reason=%s frames=%d/%d run=%s" % ["CAPTURE_COMPLETE" if failure.is_empty() else "INCOMPLETE", failure, manifest.get("frames", []).size(), expected_frames, run_dir])
	tree.quit(0 if failure.is_empty() else 1)

func close_world() -> void:
	if is_instance_valid(scene):
		scene.free()
	scene = null
	manager = null
	bike = null
	streamer = null
	drone = null
