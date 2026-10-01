extends SceneTree

const Audit = preload("res://scripts/test/capture_audit_support.gd")
var audit: Audit = Audit.new()
var expected_frames := 0
var capture_queue: Array[Dictionary] = [
	{"name": "01_start_handlebar_000m.png", "dist": 0.0, "mode": "fp", "altitude": 0.0},
	{"name": "02_straight_handlebar_100m.png", "dist": 100.0, "mode": "fp", "altitude": 0.0},
	{"name": "03_switchback_handlebar_220m.png", "dist": 220.0, "mode": "fp", "altitude": 0.0},
	{"name": "04_switchback_chase_220m.png", "dist": 220.0, "mode": "tp", "altitude": 0.0},
	{"name": "05_straight_after_turn_300m.png", "dist": 300.0, "mode": "fp", "altitude": 0.0},
	{"name": "06_winding_singletrack_520m.png", "dist": 520.0, "mode": "fp", "altitude": 0.0},
	{"name": "07_aerial_drone_overview_start.png", "dist": 100.0, "mode": "drone", "altitude": 45.0},
	{"name": "08_aerial_drone_overview_switchback.png", "dist": 250.0, "mode": "drone", "altitude": 55.0}
]

func _init() -> void:
	call_deferred("_run")

func _process(_delta: float) -> bool:
	if audit.tree and not audit.finished and not audit.alive():
		audit.finish(expected_frames)
	return false

func _run() -> void:
	if not audit.begin(self, "capture_visual_audit", [184729]):
		audit.finish(0)
		return
	var filter: String = audit.option("--audit-frame", "all")
	var items: Array[Dictionary] = []
	for item in capture_queue:
		if filter == "all" or item.name.begins_with(filter + "_"):
			items.append(item)
	expected_frames = items.size()
	if items.is_empty():
		audit.reject("UNKNOWN_FRAME_FILTER")
		audit.finish(0)
		return
	for item in items:
		# Backward views need a fresh, identically seeded scene after chunk pruning.
		if audit.scene == null or item.dist < audit.last_s:
			if not await audit.start_world(184729):
				break
		if not await audit.advance_to(item.dist) or not await audit.capture(item):
			break
	audit.finish(expected_frames)
