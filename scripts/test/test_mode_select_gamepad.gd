extends SceneTree

# Headless verification of ModeSelect gamepad navigation and seed generation

func _init() -> void:
	print("--- Running TestModeSelectGamepad ---")
	var scene: PackedScene = load("res://scenes/mode_select.tscn")
	if not scene:
		printerr("FAIL: Could not load mode_select.tscn")
		quit(1)
		return
	
	var mode_select: ModeSelect = scene.instantiate() as ModeSelect
	root.add_child(mode_select)
	
	# Wait one frame for deferred calls
	await process_frame
	
	var btn_infinite: Button = mode_select.get_node("CenterContainer/VBoxContainer/BtnInfinite") as Button
	var btn_sandbox: Button = mode_select.get_node("CenterContainer/VBoxContainer/BtnSandbox") as Button
	var btn_lab: Button = mode_select.get_node("CenterContainer/VBoxContainer/BtnLab") as Button
	var btn_training: Button = mode_select.get_node("CenterContainer/VBoxContainer/BtnTraining") as Button
	
	assert(btn_infinite != null, "BtnInfinite must exist")
	assert(btn_sandbox != null, "BtnSandbox must exist")
	assert(btn_lab != null, "BtnLab must exist")
	assert(btn_training != null, "BtnTraining must exist")
	print("PASS: ModeSelect buttons found")
	
	# Verify initial focus
	assert(btn_infinite.has_focus(), "BtnInfinite should have initial focus")
	print("PASS: Initial focus is on BtnInfinite")
	
	# Test D-pad Down navigation
	var joy_down := InputEventJoypadButton.new()
	joy_down.button_index = JOY_BUTTON_DPAD_DOWN
	joy_down.pressed = true
	mode_select._unhandled_input(joy_down)
	assert(btn_sandbox.has_focus(), "Focus should move to BtnSandbox on D-pad down")
	print("PASS: D-pad Down moved focus to BtnSandbox")
	
	mode_select._unhandled_input(joy_down)
	assert(btn_lab.has_focus(), "Focus should move to BtnLab on D-pad down")
	print("PASS: D-pad Down moved focus to BtnLab")
	
	# Test D-pad Up navigation
	var joy_up := InputEventJoypadButton.new()
	joy_up.button_index = JOY_BUTTON_DPAD_UP
	joy_up.pressed = true
	mode_select._unhandled_input(joy_up)
	assert(btn_sandbox.has_focus(), "Focus should move back to BtnSandbox on D-pad up")
	print("PASS: D-pad Up moved focus to BtnSandbox")
	
	# Test Left Stick navigation (Y axis down)
	var joy_stick := InputEventJoypadMotion.new()
	joy_stick.axis = JOY_AXIS_LEFT_Y
	joy_stick.axis_value = 0.8
	mode_select._unhandled_input(joy_stick)
	assert(btn_lab.has_focus(), "Focus should move to BtnLab on Stick down")
	print("PASS: Stick Down moved focus to BtnLab")
	
	# Test Button A activation
	var joy_a := InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	mode_select._unhandled_input(joy_a)
	assert(mode_select.is_changing_scene == true, "Button A should trigger scene change")
	print("PASS: Button A triggered scene change on focused item")
	
	print("PASS: All mode select gamepad interactions verified")
	
	mode_select.queue_free()
	quit(0)
