extends SceneTree
# Summary line present but malformed (non-numeric counters).
func _init() -> void:
	print("PROBE_SUMMARY checks=abc failures=xyz")
	print("PROBE_COMPLETE name=p14")
	quit(0)
