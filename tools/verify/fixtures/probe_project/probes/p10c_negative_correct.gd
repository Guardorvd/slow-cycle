extends SceneTree
# Expected-negative path with the declared reason: sensitivity proven.
func _init() -> void:
	print("PROBE_NEGATIVE status=INCOMPLETE reason=EXPECTED_REASON")
	quit(1)
