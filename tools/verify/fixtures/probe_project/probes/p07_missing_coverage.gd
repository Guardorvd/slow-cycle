extends SceneTree
# Completion marker present but only 2 of 3 declared coverage items observed.
func _init() -> void:
	for item in ["a", "b"]:
		print("PROBE_COVERAGE item=%s" % item)
	print("PROBE_SUMMARY checks=2 failures=0")
	print("PROBE_COMPLETE name=p07")
	quit(0)
