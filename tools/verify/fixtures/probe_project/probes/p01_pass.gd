extends SceneTree
# Genuine PASS: marker + counter + three coverage items, exit 0.
func _init() -> void:
	for item in ["a", "b", "c"]:
		print("PROBE_COVERAGE item=%s" % item)
	print("PROBE_SUMMARY checks=3 failures=0")
	print("PROBE_COMPLETE name=p01")
	quit(0)
