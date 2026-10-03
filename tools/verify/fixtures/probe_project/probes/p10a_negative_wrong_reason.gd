extends SceneTree
# Expected-negative path that reports a different reason than declared.
func _init() -> void:
	print("PROBE_NEGATIVE status=INCOMPLETE reason=SOMETHING_ELSE")
	quit(1)
