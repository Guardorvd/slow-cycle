extends SceneTree

const Audit = preload("res://scripts/test/capture_audit_support.gd")
var audit: Audit = Audit.new()
var expected_frames := 0

func _init() -> void:
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if audit.tree and not audit.finished and not audit.alive():
		audit.finish(expected_frames)
	return false

func _run() -> void:
	var defaults := [184729, 42, 77777]
	if not audit.begin(self, "capture_seed_audit", defaults):
		audit.finish(0)
		return
	var seeds := defaults.duplicate()
	if audit.cli_seed() != null:
		seeds = [int(audit.cli_seed())]
	var filter: String = audit.option("--audit-frame", "all")
	if filter not in ["all", "start", "100m", "fork"]:
		audit.reject("UNKNOWN_FRAME_FILTER")
		audit.finish(0)
		return
	expected_frames = seeds.size() * (3 if filter == "all" else 1)
	for seed_value in seeds:
		if not await audit.start_world(seed_value):
			break
		if filter in ["all", "start"]:
			if not await audit.capture({"name": "seed_%d_01_start_002.5m.png" % seed_value, "dist": 2.5, "mode": "fp"}):
				break
		if filter in ["all", "100m"]:
			if not await audit.advance_to(100.0) or not await audit.capture({"name": "seed_%d_02_straight_100m.png" % seed_value, "dist": 100.0, "mode": "fp"}):
				break
		if filter in ["all", "fork"]:
			var fork_info: Dictionary = await _find_fork()
			if fork_info.is_empty():
				break
			if not await audit.advance_to(fork_info.view_s):
				break
			if not await audit.capture({"name": "seed_%d_03_first_fork.png" % seed_value, "dist": fork_info.view_s, "mode": "fp"}, {"fork": fork_info}):
				break
		audit.close_world()
	audit.finish(expected_frames)

func _find_fork() -> Dictionary:
	while audit.alive():
		var parent = audit.streamer.get_active_branch()
		if parent and parent.is_fork_spawned:
			var fork_s: float = parent.distance_at_last_fork
			if fork_s > 650.0:
				audit.reject("FORK_OUTSIDE_SEARCH_RANGE")
				return {}
			var reason: String = Audit.fork_reason(audit.streamer, parent)
			if reason.is_empty():
				var alternate = audit.streamer.branches[parent.child_branch_ids[0]]
				return {"parent_branch_id": parent.branch_id, "alternate_branch_id": alternate.branch_id, "fork_id": alternate.fork_id, "origin": Audit.vec(parent.fork_node_pos), "origin_s": fork_s, "view_s": fork_s - 22.0, "search_range_m": [0, 650], "both_arm_meshes_committed": true}
		elif audit.last_s >= 650.0:
			audit.reject("FORK_MISSING_BEFORE_650M")
			return {}
		var next_s: float = minf(650.0, audit.last_s + 15.0)
		if parent and Audit.path_reason(parent.road_path, next_s).is_empty():
			if audit.position_at(next_s).is_empty():
				return {}
		await process_frame
	return {}
