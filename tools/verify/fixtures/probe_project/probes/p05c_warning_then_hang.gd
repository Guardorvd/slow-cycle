extends SceneTree
# A warning followed by a hang: the warning is recorded, the verdict stays INCOMPLETE/TIMEOUT.
func _init() -> void:
	push_warning("probe warning before hang")
	print("PROBE_HANG_START")
