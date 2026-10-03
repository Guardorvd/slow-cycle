extends SceneTree
# Script error before quit() leaves the engine alive; timeout + explicit script error.
func _init() -> void:
	var a = null
	print("PROBE_BEFORE_ERROR")
	a.nonexistent_call()
	print("PROBE_COMPLETE name=p11b")
	quit(0)
