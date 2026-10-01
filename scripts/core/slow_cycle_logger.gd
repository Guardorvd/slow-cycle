class_name SlowCycleLogger
extends Node

## Existing ring API plus one session owner. Rare events and replay inputs survive the ring.
enum Channel { WORLD, GRAMMAR, GEOM, FORK, TERRAIN, BIKE }
const CHANNEL_NAMES := {Channel.WORLD: "WORLD", Channel.GRAMMAR: "GRAMMAR", Channel.GEOM: "GEOM", Channel.FORK: "FORK", Channel.TERRAIN: "TERRAIN", Channel.BIKE: "BIKE"}
const MAX_BUFFER_LINES: int = 5000
const LOG_FILE_PATH: String = "user://slow_cycle_diagnostics.log"
const AUTO_FLUSH_INTERVAL: float = 2.0
const MAX_REPLAY_STEPS: int = 128

static var _buffer: Array[String] = []
static var _buffer_head: int = 0
static var _is_full: bool = false
static var _total_logged: int = 0
static var _enabled: bool = true
static var _print_to_console: bool = false
static var _owner_ref: WeakRef

var manifest: Dictionary = {}
var run_dir: String = ""
var _context_ref: WeakRef
var _pending_events: Array[Dictionary] = []
var _reported_io: Dictionary = {}
var _time_since_flush: float = 0.0
var _event_sequence: int = 0
var _closed: bool = false
var _dirty: bool = false
var _io_failed: bool = false

static func _owner() -> Node:
	return _owner_ref.get_ref() if _owner_ref else null

static func argument(name: String, fallback: String = "") -> String:
	var value := fallback
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			value = arg.substr(name.length() + 1)
	return value

func start_session(header: Dictionary, context: Node, output_root: String = "") -> bool:
	var prior = _owner()
	if is_instance_valid(prior) and prior != self:
		prior.finish_session("replaced_by_new_session")
	clear()
	_owner_ref = weakref(self)
	_context_ref = weakref(context) if context else null
	var run_id := "%s-%d-%s" % [Time.get_datetime_string_from_system(true).replace(":", "-"), OS.get_process_id(), Crypto.new().generate_random_bytes(8).hex_encode()]
	if output_root.is_empty():
		output_root = argument("--diagnostics-root", "user://slow_cycle_sessions")
	run_dir = ProjectSettings.globalize_path(output_root.path_join(run_id))
	manifest = json_safe(header)
	manifest.merge({"schema": 1, "run_id": run_id, "run_dir": run_dir, "status": "RUNNING", "replay_complete": true, "physics_replay_supported": false, "route_choices": [], "replay_steps": [], "problems": [], "io_errors": [], "events": 0, "godot": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_method(), "driver": RenderingServer.get_current_rendering_driver_name(), "display_server": DisplayServer.get_name()}, true)
	if DirAccess.dir_exists_absolute(run_dir) or FileAccess.file_exists(run_dir):
		return _io_error("RUN_ID_COLLISION", run_dir)
	if DirAccess.make_dir_recursive_absolute(run_dir) != OK:
		return _io_error("DIRECTORY_UNAVAILABLE", run_dir)
	var provenance := collect_provenance()
	manifest.merge(provenance, true)
	if not provenance.source_available:
		manifest.replay_complete = false
		manifest["replay_limit_reason"] = "SOURCE_UNAVAILABLE"
	for uri in provenance.source_hashes:
		var dest := run_dir.path_join("sources").path_join(str(uri).trim_prefix("res://"))
		if DirAccess.make_dir_recursive_absolute(dest.get_base_dir()) != OK:
			_io_error("SOURCE_DIRECTORY_FAILED", dest)
			break
		var source := FileAccess.open(uri, FileAccess.READ)
		var copy := FileAccess.open(dest, FileAccess.WRITE)
		if not source or not copy:
			_io_error("SOURCE_COPY_FAILED", dest)
			break
		copy.store_buffer(source.get_buffer(source.get_length()))
		copy.flush()
		var error := copy.get_error()
		copy.close()
		source.close()
		if error != OK or FileAccess.get_sha256(dest) != provenance.source_hashes[uri]:
			_io_error("SOURCE_COPY_MISMATCH", dest)
			break
	record_event("SESSION_START", {"effective_seed": manifest.get("effective_seed"), "requested_seed": manifest.get("requested_seed")})
	log_world("SESSION_START run=%s seed=%s" % [run_id, manifest.get("effective_seed")])
	return save_session()

static func collect_provenance() -> Dictionary:
	var revision: Array = []
	var state: Array = []
	var revision_code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], revision, true)
	var state_code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "status", "--porcelain"], state, true)
	var files: Array[String] = []
	for folder in ["world", "core", "player", "camera", "audio", "ui"]:
		_collect_sources("res://scripts/" + folder, files)
	_collect_sources("res://scenes", files)
	_collect_sources("res://assets/materials", files)
	_collect_sources("res://assets/shaders", files)
	files.append("res://project.godot")
	files.sort()
	var hashes: Dictionary = {}
	var parts := PackedStringArray()
	var available := true
	for uri in files:
		var digest := FileAccess.get_sha256(uri)
		if digest.is_empty():
			available = false
		hashes[uri] = digest
		parts.append(uri + ":" + digest)
	return {"revision": str(revision[0]).strip_edges() if revision_code == 0 and not revision.is_empty() else null, "working_tree_dirty": not str(state[0]).strip_edges().is_empty() if state_code == 0 and not state.is_empty() else null, "source_digest": "\n".join(parts).sha256_text() if available else null, "source_hashes": hashes, "source_available": available}

static func _collect_sources(path: String, result: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	for filename in dir.get_files():
		if filename.ends_with(".gd") or filename.ends_with(".tscn") or filename.ends_with(".tres") or filename.ends_with(".gdshader"):
			result.append(path.path_join(filename))
	for folder in dir.get_directories():
		_collect_sources(path.path_join(folder), result)

func _process(delta: float) -> void:
	_time_since_flush += delta
	if _time_since_flush >= AUTO_FLUSH_INTERVAL and _owner() == self and not _closed:
		_time_since_flush = 0.0
		save_session()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		finish_session("window_close_request")

func _exit_tree() -> void:
	finish_session("tree_exit")

func _snapshot() -> Dictionary:
	var context = _context_ref.get_ref() if _context_ref else null
	if is_instance_valid(context) and context.has_method("diagnostic_snapshot"):
		return json_safe(context.diagnostic_snapshot())
	return {"context_available": false}

func record_event(kind: String, details: Dictionary = {}) -> void:
	if _closed:
		return
	_event_sequence += 1
	_pending_events.append({"sequence": _event_sequence, "type": kind, "ticks_ms": Time.get_ticks_msec(), "physics_tick": Engine.get_physics_frames(), "details": json_safe(details)})
	manifest.events = _event_sequence
	_dirty = true

func record_route_choice(details: Dictionary) -> void:
	var clean: Dictionary = json_safe(details)
	if manifest.route_choices.size() < MAX_REPLAY_STEPS:
		manifest.route_choices.append(clean)
	else:
		manifest.replay_complete = false
		manifest["replay_limit_reason"] = "REPLAY_STEP_BUDGET"
	_add_replay_step({"type": "CHOICE", "details": clean})
	record_event("FORK_CHOICE", clean)
	save_session()

func _add_replay_step(step: Dictionary) -> void:
	if manifest.replay_steps.size() >= MAX_REPLAY_STEPS:
		manifest.replay_complete = false
		manifest["replay_limit_reason"] = "REPLAY_STEP_BUDGET"
		return
	manifest.replay_steps.append(json_safe(step))

func record_checkpoint(label: String, start_s: float, end_s: float) -> bool:
	var context = _context_ref.get_ref() if _context_ref else null
	if not is_instance_valid(context) or not context.has_method("diagnostic_checkpoint"):
		return record_problem("CHECKPOINT_CONTEXT_MISSING", {"label": label})
	var checkpoint: Dictionary = context.diagnostic_checkpoint(start_s, end_s)
	if not checkpoint.get("available", false):
		manifest.replay_complete = false
		manifest["replay_limit_reason"] = "CHECKPOINT_UNAVAILABLE"
		return record_problem("CHECKPOINT_UNAVAILABLE", {"label": label, "checkpoint": checkpoint})
	checkpoint["label"] = label
	_add_replay_step({"type": "CHECKPOINT", "details": checkpoint})
	record_event("CHECKPOINT", checkpoint)
	return save_session()

func record_problem(code: String, details: Dictionary = {}) -> bool:
	var problem := {"code": code, "details": json_safe(details), "snapshot": _snapshot(), "recent_lines": get_recent_lines(20)}
	manifest.problems.append(problem)
	record_event("PROBLEM", problem)
	manifest["diagnostic_problem_count"] = manifest.problems.size()
	save_session()
	return false

func _io_error(code: String, path: String) -> bool:
	_io_failed = true
	manifest["status"] = "INCOMPLETE"
	manifest["replay_complete"] = false
	var key := code + ":" + path
	if not _reported_io.has(key):
		_reported_io[key] = true
		manifest.get_or_add("io_errors", []).append({"code": code, "path": path})
		printerr("DIAGNOSTIC_IO_ERROR code=%s path=%s run=%s" % [code, path, manifest.get("run_id", "unavailable")])
	return false

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return _io_error("OPEN_FAILED:%d" % FileAccess.get_open_error(), path)
	file.store_string(JSON.stringify(json_safe(data), "\t") + "\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return _io_error("WRITE_FAILED:%d" % error, path)
	var reloaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not reloaded is Dictionary or reloaded.get("run_id") != data.get("run_id"):
		return _io_error("METADATA_RELOAD_FAILED", path)
	return true

func save_session() -> bool:
	if run_dir.is_empty() or _closed:
		return false
	if not DirAccess.dir_exists_absolute(run_dir):
		return false
	var snapshot := _snapshot()
	manifest["last_snapshot"] = snapshot
	if snapshot.get("player_available", false) and snapshot.get("path_available", false):
		manifest["last_live_snapshot"] = snapshot
	manifest["total_ring_lines"] = _total_logged
	manifest["retained_ring_lines"] = _buffer.size()
	var journal_path := run_dir.path_join("events.jsonl")
	if not _pending_events.is_empty():
		var mode := FileAccess.READ_WRITE if FileAccess.file_exists(journal_path) else FileAccess.WRITE
		var journal := FileAccess.open(journal_path, mode)
		if not journal:
			return _io_error("OPEN_FAILED:%d" % FileAccess.get_open_error(), journal_path)
		journal.seek_end()
		for event in _pending_events:
			journal.store_line(JSON.stringify(event))
		journal.flush()
		var error := journal.get_error()
		journal.close()
		if error != OK:
			return _io_error("WRITE_FAILED:%d" % error, journal_path)
		_pending_events.clear()
	var ring_ok := _write_ring(run_dir.path_join("diagnostics.log"))
	if not ring_ok:
		_io_error("RING_WRITE_FAILED", run_dir.path_join("diagnostics.log"))
	var manifest_ok := _write_json(run_dir.path_join("manifest.json"), manifest)
	_dirty = false
	return ring_ok and manifest_ok and not _io_failed

func finish_session(reason: String) -> bool:
	if _closed:
		return not _io_failed
	manifest["end_reason"] = reason
	manifest["status"] = "INCOMPLETE" if _io_failed else "SESSION_CLOSED"
	record_event("SESSION_END", {"reason": reason, "snapshot": _snapshot()})
	var saved := save_session()
	_closed = true
	_context_ref = null
	if _owner() == self:
		_owner_ref = null
	return saved

static func log_world(message: String) -> void:
	_log_raw("WORLD", message)

static func log_grammar(message: String) -> void:
	_log_raw("GRAMMAR", message)

static func log_geom(message: String, details: Dictionary = {}) -> void:
	_log_raw("GEOM", message)
	var current = _owner()
	if is_instance_valid(current):
		current.record_event("GEOM", {"message": message, "emitter": details, "active_snapshot": current._snapshot()})
		if message.begins_with("FATAL_FALLBACK"):
			current.record_problem("FATAL_FALLBACK", details)

static func log_fork(message: String) -> void:
	_log_raw("FORK", message)

static func log_terrain(message: String) -> void:
	_log_raw("TERRAIN", message)

static func log_bike(message: String) -> void:
	_log_raw("BIKE", message)

static func log_channel(channel: Channel, message: String) -> void:
	_log_raw(CHANNEL_NAMES.get(channel, "DIAG"), message)

static func _log_raw(channel: String, message: String) -> void:
	if not _enabled:
		return
	var line := "[%s] [%s] %s" % [Time.get_time_string_from_system(), channel, message]
	if _print_to_console:
		print(line)
	if _buffer.size() < MAX_BUFFER_LINES:
		_buffer.append(line)
	else:
		_buffer[_buffer_head] = line
		_is_full = true
	_buffer_head = (_buffer_head + 1) % MAX_BUFFER_LINES
	_total_logged += 1
	var current = _owner()
	if is_instance_valid(current):
		current._dirty = true

static func get_recent_lines(count: int = 100) -> Array[String]:
	var result: Array[String] = []
	var n := clampi(count, 0, _buffer.size())
	var start := (_buffer_head - n + MAX_BUFFER_LINES) % MAX_BUFFER_LINES if _is_full else _buffer.size() - n
	for i in range(n):
		result.append(_buffer[(start + i) % MAX_BUFFER_LINES])
	return result

static func _write_ring(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	for line in get_recent_lines(MAX_BUFFER_LINES):
		file.store_line(line)
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK

static func flush() -> bool:
	var current = _owner()
	if is_instance_valid(current):
		return current.save_session()
	if _buffer.is_empty():
		return true
	var ok := _write_ring(LOG_FILE_PATH)
	if not ok:
		printerr("DIAGNOSTIC_IO_ERROR code=LEGACY_WRITE_FAILED path=" + LOG_FILE_PATH)
	return ok

static func clear() -> void:
	_buffer.clear()
	_buffer_head = 0
	_is_full = false
	_total_logged = 0

static func set_console_echo(echo: bool) -> void:
	_print_to_console = echo

static func json_safe(value: Variant) -> Variant:
	if value is float and not is_finite(value):
		return "NaN" if is_nan(value) else ("+Inf" if value > 0 else "-Inf")
	if value is Vector3:
		return [json_safe(value.x), json_safe(value.y), json_safe(value.z)]
	if value is Transform3D:
		return {"position": json_safe(value.origin), "basis": [json_safe(value.basis.x), json_safe(value.basis.y), json_safe(value.basis.z)]}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[str(key)] = json_safe(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(json_safe(item))
		return result
	return value
