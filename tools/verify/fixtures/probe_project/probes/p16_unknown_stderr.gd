extends SceneTree
# Completes normally and satisfies every PASS requirement, but emits an unprefixed stderr line the harness cannot classify.
func _init() -> void:
	printerr("probe unprefixed diagnostic line that no pattern recognises")
	print("PROBE_SUMMARY checks=1 failures=0")
	print("PROBE_COMPLETE name=p16")
	quit(0)
