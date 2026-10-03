extends SceneTree
# Expected-negative path that merely crashes with no reason: not an exercised negative.
func _init() -> void:
	quit(7)
