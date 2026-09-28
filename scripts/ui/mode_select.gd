class_name ModeSelect
extends Control

## Slow Cycle — Main Mode Selection Screen
## Supports Keyboard (1-4, Enter, Space, Up/Down), Gamepad (A, D-pad, Left Stick), and Mouse.

@onready var btn_infinite: Button = $CenterContainer/VBoxContainer/BtnInfinite
@onready var btn_sandbox: Button = $CenterContainer/VBoxContainer/BtnSandbox
@onready var btn_lab: Button = $CenterContainer/VBoxContainer/BtnLab
@onready var btn_training: Button = $CenterContainer/VBoxContainer/BtnTraining

var is_changing_scene: bool = false
var _buttons: Array[Button] = []
var _last_stick_dir: int = 0

func _ready() -> void:
	_buttons = [btn_infinite, btn_sandbox, btn_lab, btn_training]

	if btn_infinite:
		btn_infinite.pressed.connect(_on_infinite_selected)
		btn_infinite.call_deferred("grab_focus")
	if btn_sandbox:
		btn_sandbox.pressed.connect(_on_sandbox_selected)
	if btn_lab:
		btn_lab.pressed.connect(_on_lab_selected)
	if btn_training:
		btn_training.pressed.connect(_on_training_selected)

func _unhandled_input(event: InputEvent) -> void:
	# 1. Keyboard digits 1-4
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			_on_infinite_selected()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			_on_sandbox_selected()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_3 or event.keycode == KEY_KP_3:
			_on_lab_selected()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_4 or event.keycode == KEY_KP_4:
			_on_training_selected()
			get_viewport().set_input_as_handled()
			return

	# 2. Gamepad Button A or ui_accept action
	if event.is_action_pressed("ui_accept"):
		_activate_focused_or_default()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_activate_focused_or_default()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			_navigate_vertical(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			_navigate_vertical(1)
			get_viewport().set_input_as_handled()
			return

	# 3. Gamepad Left Stick Y navigation
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		var dir: int = 0
		if event.axis_value > 0.5:
			dir = 1
		elif event.axis_value < -0.5:
			dir = -1

		if dir != 0 and _last_stick_dir == 0:
			_navigate_vertical(dir)
			get_viewport().set_input_as_handled()
		_last_stick_dir = dir

func _navigate_vertical(dir: int) -> void:
	if _buttons.is_empty():
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var current_idx: int = _buttons.find(focus_owner as Button)
	if current_idx == -1:
		_buttons[0].grab_focus()
	else:
		var next_idx: int = (current_idx + dir + _buttons.size()) % _buttons.size()
		_buttons[next_idx].grab_focus()

func _activate_focused_or_default() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == btn_sandbox:
		_on_sandbox_selected()
	elif focus_owner == btn_lab:
		_on_lab_selected()
	elif focus_owner == btn_training:
		_on_training_selected()
	else:
		_on_infinite_selected()

func _change_mode_scene(path: String) -> void:
	if is_changing_scene:
		return
	is_changing_scene = true
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load scene %s (error code %d)" % [path, err])
		is_changing_scene = false

func _on_infinite_selected() -> void:
	_change_mode_scene("res://scenes/main.tscn")

func _on_sandbox_selected() -> void:
	_change_mode_scene("res://scenes/test/riding_feel_test_track.tscn")

func _on_lab_selected() -> void:
	_change_mode_scene("res://scenes/test/riding_lab_track.tscn")

func _on_training_selected() -> void:
	_change_mode_scene("res://scenes/test/gravel_training_loop.tscn")
