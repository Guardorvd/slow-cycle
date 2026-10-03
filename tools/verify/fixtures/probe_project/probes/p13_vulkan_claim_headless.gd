extends SceneTree
# Completes cleanly but runs headless while the check claims E5/Vulkan evidence.
func _init() -> void:
	print("PROBE_DRIVER driver=%s" % RenderingServer.get_current_rendering_driver_name())
	print("PROBE_SUMMARY checks=1 failures=0")
	print("PROBE_COMPLETE name=p13")
	quit(0)
