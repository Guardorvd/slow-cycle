extends SceneTree
# Known project failure: explicit contract predicate fails, nonzero exit.
func _init() -> void:
	print("PROBE_CONTRACT_VIOLATION invariant=A-1 detail=declared invariant not met")
	quit(1)
