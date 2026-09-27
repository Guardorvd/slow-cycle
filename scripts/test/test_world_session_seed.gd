extends SceneTree

## Verify normal-session seed selection and exact command-line replay behavior.

const WorldManagerClass = preload("res://scripts/world/world_manager.gd")
const MainScene = preload("res://scenes/main.tscn")

var checks: int = 0
var failures: int = 0

func _init() -> void:
	var manager = WorldManagerClass.new()
	manager.world_seed = 184729
	manager.randomize_world_seed_on_start = false
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray())
	_check(manager.world_seed == 184729, "fixed-seed test/tool sessions retain their configured seed")

	manager.randomize_world_seed_on_start = true
	manager.world_seed = 184729
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray())
	var first_session_seed: int = manager.world_seed
	_check(first_session_seed > 0 and first_session_seed <= 2147483647,
		"fresh session seed is a valid positive signed 32-bit world seed")
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray())
	_check(manager.world_seed != first_session_seed, "separate fresh sessions receive different world seeds")

	manager._resolve_session_seed(PackedStringArray(["--seed=42"]), PackedStringArray(["--seed=9090"]))
	_check(manager.world_seed == 9090, "explicit user seed overrides default and command-line seed")
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray(["--seed=9090"]))
	var replay_seed: int = manager.world_seed
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray(["--seed=9090"]))
	_check(manager.world_seed == replay_seed, "the same explicit seed is replayable exactly")
	manager._resolve_session_seed(PackedStringArray(), PackedStringArray(["--seed=0"]))
	_check(manager.world_seed == 0, "seed zero is a valid explicit replay value, not the randomization sentinel")
	manager.free()

	var main_root: Node = MainScene.instantiate()
	var main_world: Node = main_root.get_node("WorldManager")
	_check(bool(main_world.randomize_world_seed_on_start),
		"the normal gameplay scene requests a fresh seed for each ride")
	main_root.free()

	print("WORLD_SESSION_SEED_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("WORLD_SESSION_SEED_FAIL " + message)
