extends SceneTree

const SessionLogger = preload("res://scripts/core/slow_cycle_logger.gd")
var scene: Node3D
var manager: Node3D
var bike: CharacterBody3D
var checks: int = 0
var failures: int = 0
var started_ms: int
var completed: bool = false
var source_manifests: Array[String] = []

func _init() -> void:
	started_ms = Time.get_ticks_msec()
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if not completed and Time.get_ticks_msec() - started_ms > 55000:
		completed = true
		printerr("SESSION_LOG_TEST_SUMMARY status=INCOMPLETE reason=TIMEOUT checks=%d failures=%d" % [checks, failures])
		quit(1)
	return false

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("SESSION_LOG_CHECK_FAIL " + label)

func _new_world(seed_value: int) -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	manager = scene.get_node("WorldManager")
	manager.world_seed = seed_value
	manager.randomize_world_seed_on_start = false
	root.add_child(scene)
	bike = scene.get_node("Bicycle")
	bike.set_physics_process(false)
	while manager.chunk_streamer.get_active_branch().road_path.get_total_distance() < 100.0 or not manager._opening_diagnostic_recorded:
		await process_frame

func _teleport(s: float) -> void:
	var branch = manager.chunk_streamer.get_active_branch()
	var sample: Dictionary = branch.road_path.get_sample_at_distance(s)
	bike.global_position = sample.position + sample.normal * 0.4
	bike.velocity = Vector3.ZERO
	manager.chunk_streamer.update_streaming(bike.global_position, sample.tangent * 12.0, 0.016)

func _run() -> void:
	for scenario in [{"seed": 184729, "choice": 0}, {"seed": 42, "choice": 1}, {"seed": 77777, "choice": 0}]:
		await _new_world(scenario.seed)
		var logger = manager.diagnostics_logger
		var manifest_path: String = logger.run_dir.path_join("manifest.json")
		source_manifests.append(manifest_path)
		var initial: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_check(initial is Dictionary and initial.effective_seed == scenario.seed and initial.events >= 1, "real session header exists before checkpoint")
		_check(manager.road_logic.world_seed == scenario.seed, "actual generator seed")
		_check(logger.manifest.replay_steps.size() == 1 and logger.manifest.replay_steps[0].details.label == "automatic_opening", "normal session gets replay checkpoint automatically")
		_check(logger.record_checkpoint("opening", 0.0, 100.0), "real 51-sample opening checkpoint saved")
		var trunk = manager.chunk_streamer.get_active_branch()
		var s := 0.0
		while not trunk.is_fork_spawned:
			s += 15.0
			if s > 650.0:
				_check(false, "fork created within bounded search")
				break
			_teleport(s)
			await process_frame
		if trunk.is_fork_spawned:
			var fork_s: float = trunk.distance_at_last_fork
			manager.chunk_streamer._on_branch_locked(trunk.decision_model.fork_node_id, scenario.choice, trunk.branch_id)
			var selected = manager.chunk_streamer.get_active_branch()
			var start_s: float = fork_s if scenario.choice == 0 else 0.0
			_check(logger.manifest.route_choices.size() == 1 and logger.manifest.route_choices[0].choice == scenario.choice, "confirmed production choice persisted")
			_check(selected.road_logic.world_seed == logger.manifest.route_choices[0].selected_seed, "selected real branch seed persisted")
			_check(logger.record_checkpoint("selected_arm", start_s, start_s + 40.0), "selected arm geometry saved")
		if scenario.seed == 184729:
			for i in range(5101):
				SessionLogger.log_grammar("overflow_fixture_%d" % i)
			_check(SessionLogger.get_recent_lines(6000).size() == 5000, "ring remains bounded")
			_check(SessionLogger.get_recent_lines(1)[0].ends_with("overflow_fixture_5100"), "last ring line preserved")
			manager.report_diagnostic_problem("FIXTURE_NONFINITE", {"measured": INF, "position": bike.global_position})
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			_check(saved.route_choices.size() == 1 and saved.replay_steps.size() == 4 and saved.effective_seed == 184729, "ring overflow did not lose header/choice/checkpoints")
			_check(saved.problems[0].details.measured == "+Inf" and saved.problems[0].snapshot.player_available, "problem retains actual pose and explicit nonfinite value")
			SessionLogger.log_world("AUTO_FLUSH_FIXTURE")
			var auto_start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - auto_start < 2200:
				await process_frame
			_check(FileAccess.get_file_as_string(logger.run_dir.path_join("diagnostics.log")).contains("AUTO_FLUSH_FIXTURE"), "real Node timer flushed without explicit call")
		else:
			_check(not SessionLogger.get_recent_lines(5000).any(func(line: String) -> bool: return line.contains("overflow_fixture_")), "new session has fresh ring")
		var previous_run: String = logger.run_dir
		scene.free()
		scene = null
		manager = null
		bike = null
		await process_frame
		await process_frame
		var closed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		_check(closed.status == "SESSION_CLOSED" and closed.end_reason == "tree_exit", "scene exit persisted SESSION_END")
		var journal := FileAccess.get_file_as_string(previous_run.path_join("events.jsonl"))
		_check(journal.contains('"SESSION_START"') and journal.contains('"FORK_COMMIT"') and journal.contains('"FORK_CHOICE"') and journal.contains('"SESSION_END"'), "real lifecycle/fork journal complete")
	# Real external I/O failure, with no permissions changed.
	var root_path := ProjectSettings.globalize_path(SessionLogger.argument("--diagnostics-root", "user://slow_cycle_sessions"))
	var blocked := root_path.path_join("blocked-%d" % OS.get_process_id())
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("file instead of directory")
	file.close()
	var failed_logger: SessionLogger = SessionLogger.new()
	_check(not failed_logger.start_session({"requested_seed": 42, "effective_seed": 42}, null, blocked), "output failure reported")
	_check(failed_logger.manifest.status == "INCOMPLETE" and not failed_logger.manifest.replay_complete, "failed I/O never reports complete")
	_check(not failed_logger.save_session(), "repeated failure remains failure")
	failed_logger.finish_session("fixture_exit")
	failed_logger.free()
	completed = true
	var summary := {"status": "PASS" if failures == 0 else "FAIL", "checks": checks, "failures": failures, "manifests": source_manifests}
	var summary_path := root_path.path_join("session-test-%d.json" % OS.get_process_id())
	file = FileAccess.open(summary_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t") + "\n")
	file.close()
	print("SESSION_LOG_TEST_SUMMARY checks=%d failures=%d summary=%s" % [checks, failures, summary_path])
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
