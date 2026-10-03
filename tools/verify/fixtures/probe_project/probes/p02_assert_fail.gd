extends SceneTree
# Executed check fails: summary failures=1, exit 1.
func _init() -> void:
	print("PROBE_SUMMARY checks=3 failures=1")
	print("PROBE_COMPLETE name=p02")
	quit(1)
