extends SceneTree
const TeardownSettle = preload("res://scripts/test/teardown_settle_support.gd")

var arm: String = "NORMAL"
var cycles: int = 1
var walk: bool = false
var settle_ms: int = 0
var tracked: Dictionary = {}

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--q2b-arm="): arm = arg.get_slice("=", 1)
		if arg.begins_with("--q2b-cycles="): cycles = int(arg.get_slice("=", 1))
		if arg.begins_with("--q2b-walk="): walk = arg.get_slice("=", 1) == "1"
		if arg.begins_with("--q2b-settle-ms="): settle_ms = int(arg.get_slice("=", 1))
	call_deferred("_run")

func _counts(cycle: int, phase: String) -> void:
	print("Q2B_COUNTS cycle=%d phase=%s objects=%d resources=%d nodes=%d orphan_nodes=%d" % [cycle, phase, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])

func _own(cycle: int, group: String, role: String, obj: Object, playing: String = "na") -> void:
	if obj == null: return
	var id: int = obj.get_instance_id()
	if not tracked[group].has(id):
		tracked[group][id] = obj.get_class()
		print("Q2B_OWNED cycle=%d group=%s role=%s class=%s id=%s playing=%s" % [cycle, group, role, obj.get_class(), String.num_uint64(id), playing])

func _world(cycle: int, manager: Node) -> void:
	var streamer: Node = manager.chunk_streamer
	_own(cycle, "T-WORLD", "WorldManager", manager)
	_own(cycle, "T-WORLD", "ChunkStreamer", streamer)
	_own(cycle, "T-WORLD", "SlowCycleLogger", manager.diagnostics_logger)
	_own(cycle, "T-WORLD", "road_graph", streamer.road_graph)
	for child: Node in streamer.get_children():
		if child is RoadChunk: _own(cycle, "T-WORLD", "RoadChunk", child)
	for branch_id in streamer.branches:
		var branch: RefCounted = streamer.branches[branch_id]
		_own(cycle, "T-WORLD", "branch_%s" % branch_id, branch)
		for field: String in ["decision_model", "road_path", "road_logic"]:
			_own(cycle, "T-WORLD", "branch_%s.%s" % [branch_id, field], branch.get(field))

func _tree_lines(node: Node, main: Node, lines: Array[String], streamer: Node) -> void:
	var identity_path: String = str(main.get_path_to(node))
	if node == streamer:
		identity_path = str(main.get_path_to(node.get_parent())) + "/ChunkStreamer"
	lines.append("%s|%s" % [identity_path, node.get_class()])
	if node == streamer: return
	for child: Node in node.get_children(): _tree_lines(child, main, lines, streamer)

func _snapshot(cycle: int, scene: Node, manager: Node) -> void:
	var lines: Array[String] = []
	_tree_lines(scene, scene, lines, manager.chunk_streamer)
	lines.sort()
	var audio_children: Array[String] = []
	for player: Node in scene.get_node("Bicycle/AudioManager").get_children():
		audio_children.append(str(player.name))
		if player is AudioStreamPlayer3D:
			var playing: String = "true" if player.playing else "false"
			_own(cycle, "T-AUDIO", str(player.name), player, playing)
			_own(cycle, "T-AUDIO", str(player.name) + ".stream", player.stream, playing)
			if player.has_stream_playback(): _own(cycle, "T-AUDIO", str(player.name) + ".get_stream_playback()", player.get_stream_playback(), playing)
	print("Q2B_TREE cycle=%d digest=%s nodes=%d audio_children=%s entries=%s" % [cycle, "\n".join(lines).sha256_text(), lines.size(), JSON.stringify(audio_children), JSON.stringify(lines)])
	_own(cycle, "T-SCENE", "Main", scene)
	_world(cycle, manager)
	print("Q2B_STREAM cycle=%d branches=%d chunks=%d" % [cycle, manager.chunk_streamer.branches.size(), manager.chunk_streamer.get_children().size()])

func _teleport(scene: Node, manager: Node, distance: float) -> void:
	var branch: RefCounted = manager.chunk_streamer.get_active_branch()
	var sample: Dictionary = branch.road_path.get_sample_at_distance(distance)
	var bike: CharacterBody3D = scene.get_node("Bicycle")
	bike.global_position = sample.position + sample.normal * 0.4
	bike.velocity = Vector3.ZERO
	manager.chunk_streamer.update_streaming(bike.global_position, sample.tangent * 12.0, 0.016)

func _walk(cycle: int, scene: Node, manager: Node) -> void:
	var trunk: RefCounted = manager.chunk_streamer.get_active_branch()
	var distance: float = 0.0
	while not trunk.is_fork_spawned and distance < 650.0:
		distance = minf(distance + 15.0, 650.0)
		_teleport(scene, manager, distance)
		_world(cycle, manager)
		await process_frame
	if not trunk.is_fork_spawned:
		push_error("Q2B walk: fork not found within 650 m")
		return
	var fork_distance: float = trunk.distance_at_last_fork
	manager.chunk_streamer._on_branch_locked(trunk.decision_model.fork_node_id, 0, trunk.branch_id)
	distance = fork_distance
	while distance < fork_distance + 200.0:
		distance = minf(distance + 15.0, fork_distance + 200.0)
		_teleport(scene, manager, distance)
		_world(cycle, manager)
		await process_frame
	print("Q2B_WALK cycle=%d choice=0 fork_s=%s final_s=%s" % [cycle, fork_distance, distance])

func _settle(cycle: int, requested: int) -> void:
	var t0: int = Time.get_ticks_msec()
	var frames: int = 0
	while Time.get_ticks_msec() - t0 < requested:
		await process_frame
		frames += 1
	print("Q2B_SETTLE cycle=%d requested_ms=%d elapsed_ms=%d frames=%d" % [cycle, requested, Time.get_ticks_msec() - t0, frames])

func _survivors(cycle: int) -> void:
	for group: String in tracked:
		var alive: int = 0
		var classes: Dictionary = {}
		for id: int in tracked[group]:
			if is_instance_id_valid(id):
				alive += 1
				var klass: String = tracked[group][id]
				classes[klass] = classes.get(klass, 0) + 1
		print("Q2B_SURVIVORS cycle=%d group=%s tracked=%d alive=%d classes=%s" % [cycle, group, tracked[group].size(), alive, JSON.stringify(classes)])

func _run() -> void:
	print("Q2B_PROBE_START arm=%s seed=184729 cycles=%d walk=%d settle_ms=%d" % [arm, cycles, int(walk), settle_ms])
	for cycle: int in range(1, cycles + 1):
		tracked = {"T-AUDIO": {}, "T-WORLD": {}, "T-SCENE": {}}
		_counts(cycle, "baseline")
		var scene: Node3D = load("res://scenes/main.tscn").instantiate()
		var manager: Node3D = scene.get_node("WorldManager")
		manager.world_seed = 184729
		manager.randomize_world_seed_on_start = false
		if arm == "AUDIO_REMOVED": scene.get_node("Bicycle/AudioManager").set_script(null)
		var added_ms: int = Time.get_ticks_msec()
		root.add_child(scene)
		scene.get_node("Bicycle").set_physics_process(false)
		for frame: int in range(30): await process_frame
		while Time.get_ticks_msec() - added_ms < 300: await process_frame
		_counts(cycle, "ready")
		if walk: await _walk(cycle, scene, manager)
		_snapshot(cycle, scene, manager)
		_counts(cycle, "pre_teardown")
		if cycles == 1 and arm == "FIXED_SETTLED_QUIT":
			print("Q2B_PROBE_COMPLETE cycles=1")
			scene.free()
			await TeardownSettle.settle_then_quit(self, 0)
			return
		if cycles == 1 and arm != "WAIT":
			# These zero-delay markers precede free; quit is its immediate next statement.
			print("Q2B_SETTLE cycle=1 requested_ms=0 elapsed_ms=0 frames=0")
			print("Q2B_PROBE_COMPLETE cycles=1")
			scene.free()
			quit(0)
			return
		scene.free()
		_counts(cycle, "post_teardown")
		await _settle(cycle, 250 if arm == "WAIT" else settle_ms)
		_counts(cycle, "post_settle")
		if cycles > 1: _survivors(cycle)
	print("Q2B_PROBE_COMPLETE cycles=%d" % cycles)
	quit(0)
