extends RefCounted
## Q2B Stage F: bounded post-teardown settle for SceneTree test entry points.
## Gives asynchronous engine resource release a fixed interval after the tested scene
## was freed, then quits with the caller's unchanged exit code.

const SETTLE_MS: int = 250

static func settle_then_quit(tree: SceneTree, exit_code: int) -> void:
	var t0: int = Time.get_ticks_msec()
	var frames: int = 0
	while Time.get_ticks_msec() - t0 < SETTLE_MS:
		await tree.process_frame
		frames += 1
	print("SC_TEARDOWN_SETTLE requested_ms=%d elapsed_ms=%d frames=%d exit_code=%d" % [SETTLE_MS, Time.get_ticks_msec() - t0, frames, exit_code])
	tree.quit(exit_code)
