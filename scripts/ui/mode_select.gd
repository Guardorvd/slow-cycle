class_name ModeSelect
extends Control

@onready var btn_infinite: Button = $CenterContainer/VBoxContainer/BtnInfinite
@onready var btn_sandbox: Button = $CenterContainer/VBoxContainer/BtnSandbox

func _ready() -> void:
	btn_infinite.grab_focus()
	btn_infinite.pressed.connect(_on_infinite_selected)
	btn_sandbox.pressed.connect(_on_sandbox_selected)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 or event.keycode == KEY_KP_1:
			_on_infinite_selected()
		elif event.keycode == KEY_2 or event.keycode == KEY_KP_2:
			_on_sandbox_selected()

func _on_infinite_selected() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_sandbox_selected() -> void:
	get_tree().change_scene_to_file("res://scenes/test/riding_feel_test_track.tscn")

