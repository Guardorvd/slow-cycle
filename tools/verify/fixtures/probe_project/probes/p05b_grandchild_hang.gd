extends SceneTree
# Spawns a hanging grandchild engine, then hangs: process-tree kill must remove both.
func _init() -> void:
	var pid := OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://probes/p05_hang.gd"])
	print("PROBE_GRANDCHILD_PID=%d" % pid)
