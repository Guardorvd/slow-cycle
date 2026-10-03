extends SceneTree
# Completes normally but leaks a Node: ObjectDB warning at exit under a zero-leak gate.
func _init() -> void:
	var leaked := Node.new()
	leaked.name = "ProbeLeakedNode"
	print("PROBE_SUMMARY checks=1 failures=0")
	print("PROBE_COMPLETE name=p12")
	quit(0)
