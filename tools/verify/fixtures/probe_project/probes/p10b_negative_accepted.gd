extends SceneTree
# Expected-negative path that wrongly accepts the invalid input (exit 0).
func _init() -> void:
	print("PROBE_NEGATIVE status=OK reason=")
	quit(0)
