extends SceneTree
# Warnings are recorded but are not fatal when the suite declares no warning gate.
func _init() -> void:
	push_warning("probe warning recorded, not fatal")
	print("PROBE_SUMMARY checks=1 failures=0")
	print("PROBE_COMPLETE name=p15")
	quit(0)
