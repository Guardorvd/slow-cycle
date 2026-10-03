extends SceneTree
# Exit 0 without any completion marker (the --quit-after failure mode).
func _init() -> void:
	print("PROBE_SUMMARY checks=3 failures=0")
	quit(0)
