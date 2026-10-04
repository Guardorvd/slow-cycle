extends SceneTree

const SessionLogger = preload("res://scripts/core/slow_cycle_logger.gd")
const TeardownSettle = preload("res://scripts/test/teardown_settle_support.gd")
var scene: Node3D
var manager: Node3D
var bike: CharacterBody3D
var start_ms: int
var timeout_ms: int = 55000
var done := false
var checked := 0
var choices := 0
var walked_s := 0.0

func _init() -> void:
	start_ms = Time.get_ticks_msec()
	timeout_ms = int(clampf(SessionLogger.argument("--replay-timeout", "55").to_float(), 0.01, 55) * 1000)
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if not done and Time.get_ticks_msec() - start_ms >= timeout_ms:
		_finish("TIMEOUT")
	return false

func _finish(reason: String = "") -> void:
	if done:
		return
	done = true
	if is_instance_valid(scene):
		scene.free()
		scene = null
	print("REPLAY_DIAGNOSTIC_SUMMARY status=%s reason=%s checkpoints=%d choices=%d" % ["PASS" if reason.is_empty() else "INCOMPLETE", reason, checked, choices])
	await process_frame
	await process_frame
	await TeardownSettle.settle_then_quit(self, 0 if reason.is_empty() else 1)

func _walk_to(s: float) -> void:
	while not done and walked_s < s:
		var branch = manager.chunk_streamer.get_active_branch()
		var next_s := minf(s, walked_s + 15.0)
		if next_s > branch.road_path.get_total_distance():
			await process_frame
			continue
		if next_s < branch.road_path.cumulative_distances[0]:
			_finish("TARGET_PRUNED")
			return
		var sample: Dictionary = branch.road_path.get_sample_at_distance(next_s)
		bike.global_position = sample.position + sample.normal * 0.4
		bike.velocity = Vector3.ZERO
		manager.chunk_streamer.update_streaming(bike.global_position, sample.tangent * 12.0, 0.016)
		walked_s = next_s
		await process_frame

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value)

static func _step_error(step: Variant) -> String:
	if not step is Dictionary or not step.get("details") is Dictionary:
		return "STEP_INVALID"
	var data: Dictionary = step.details
	if step.get("type") == "CHECKPOINT":
		var range_value: Variant = data.get("range_m")
		if not range_value is Array or range_value.size() != 2:
			return "CHECKPOINT_INVALID"
		if not _number(range_value[0]) or not _number(range_value[1]) or range_value[0] < 0 or range_value[0] >= range_value[1]:
			return "CHECKPOINT_INVALID"
		if not data.get("signature") is String or data.signature.length() != 64 or not _number(data.get("samples")) or data.samples < 1 or not _number(data.get("branch_seed")):
			return "CHECKPOINT_INVALID"
	elif step.get("type") == "CHOICE":
		if not _number(data.get("choice")) or (data.choice != 0 and data.choice != 1) or not _number(data.get("parent_player_sample_s")) or data.parent_player_sample_s < 0:
			return "CHOICE_INVALID"
		var origin: Variant = data.get("fork_origin")
		if not origin is Array or origin.size() != 3 or not origin.all(_number):
			return "CHOICE_INVALID"
		if not _number(data.get("parent_seed")) or not _number(data.get("selected_seed")):
			return "CHOICE_INVALID"
	else:
		return "STEP_TYPE_UNKNOWN"
	return ""

func _run() -> void:
	var path := SessionLogger.argument("--replay-manifest")
	if path.is_empty() or not FileAccess.file_exists(path):
		_finish("MANIFEST_MISSING")
		return
	var recorded: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not recorded is Dictionary or recorded.get("schema") != 1 or not recorded.has("effective_seed"):
		_finish("MANIFEST_INVALID")
		return
	if not _number(recorded.effective_seed) or recorded.effective_seed != int(recorded.effective_seed):
		_finish("SEED_INPUT_INVALID")
		return
	if not recorded.get("generation_config") is Dictionary:
		_finish("CONFIG_INVALID")
		return
	if not recorded.get("replay_complete", false):
		_finish("REPLAY_INPUTS_INCOMPLETE")
		return
	if not recorded.get("replay_steps") is Array or recorded.replay_steps.is_empty():
		_finish("CHECKPOINTS_MISSING")
		return
	if recorded.replay_steps.size() > SessionLogger.MAX_REPLAY_STEPS:
		_finish("REPLAY_STEP_BUDGET")
		return
	for entry in recorded.replay_steps:
		var invalid := _step_error(entry)
		if not invalid.is_empty():
			_finish(invalid)
			return
	var provenance := SessionLogger.collect_provenance()
	if not provenance.source_available or provenance.source_digest != recorded.get("source_digest"):
		_finish("SOURCE_MISMATCH")
		return
	scene = load("res://scenes/main.tscn").instantiate()
	manager = scene.get_node("WorldManager")
	manager.world_seed = int(recorded.effective_seed)
	manager.randomize_world_seed_on_start = false
	root.add_child(scene)
	bike = scene.get_node("Bicycle")
	bike.set_physics_process(false)
	if manager.road_logic.world_seed != int(recorded.effective_seed):
		_finish("SEED_MISMATCH")
		return
	var actual_config: Variant = JSON.parse_string(JSON.stringify(manager.diagnostic_generation_config()))
	if JSON.stringify(actual_config) != JSON.stringify(recorded.get("generation_config")):
		_finish("CONFIG_MISMATCH")
		return
	for step in recorded.replay_steps:
		if done:
			return
		if not step is Dictionary or not step.get("details") is Dictionary:
			_finish("STEP_INVALID")
			return
		var data: Dictionary = step.details
		if step.get("type") == "CHECKPOINT":
			if not data.has("range_m") or data.range_m.size() != 2 or not data.has("signature") or data.get("samples", 0) <= 0:
				_finish("CHECKPOINT_INVALID")
				return
			var last_s: float = data.range_m[1]
			while not done and manager.chunk_streamer.get_active_branch().road_path.get_total_distance() < last_s:
				await _walk_to(minf(data.range_m[0], walked_s + 15.0))
				await process_frame
			if done:
				return
			var actual: Dictionary = manager.diagnostic_checkpoint(data.range_m[0], data.range_m[1])
			if not actual.get("available", false) or actual.branch_seed != data.branch_seed or actual.signature != data.signature or actual.samples != data.samples:
				_finish("CHECKPOINT_MISMATCH")
				return
			checked += 1
		elif step.get("type") == "CHOICE":
			if not data.has("parent_player_sample_s") or not data.has("fork_origin") or (not (data.get("choice") is float or data.get("choice") is int) or (data.choice != 0 and data.choice != 1)):
				_finish("CHOICE_INVALID")
				return
			await _walk_to(data.parent_player_sample_s)
			if done:
				return
			var parent = manager.chunk_streamer.get_active_branch()
			while not done and not parent.is_fork_spawned:
				await process_frame
			if done:
				return
			var expected_origin := Vector3(data.fork_origin[0], data.fork_origin[1], data.fork_origin[2])
			if parent.road_logic.world_seed != int(data.parent_seed) or parent.fork_node_pos.distance_to(expected_origin) > 0.001:
				_finish("FORK_MISMATCH")
				return
			manager.chunk_streamer._on_branch_locked(parent.decision_model.fork_node_id, int(data.choice), parent.branch_id)
			var selected = manager.chunk_streamer.get_active_branch()
			if selected.road_logic.world_seed != int(data.selected_seed):
				_finish("SELECTED_BRANCH_MISMATCH")
				return
			if selected != parent:
				walked_s = 0.0
			choices += 1
		else:
			_finish("STEP_TYPE_UNKNOWN")
			return
	_finish("CHECKPOINTS_MISSING" if checked == 0 else "")
