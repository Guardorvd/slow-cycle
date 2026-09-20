extends Control

@export var bike_controller: Node

@onready var speed_label: Label = $TopMargin/StatusCard/VBox/SpeedLabel
@onready var state_badge: Label = $TopMargin/StatusCard/VBox/StateBadge
@onready var controls_panel: PanelContainer = $BottomMargin/ControlsCard
@onready var bell_notice: Label = $CenterNotice/BellNotice

var bell_timer: float = 0.0

func _ready() -> void:
	if bike_controller:
		if bike_controller.has_signal("telemetry_updated"):
			bike_controller.connect("telemetry_updated", _on_telemetry_updated)
		if bike_controller.has_signal("bell_rung"):
			bike_controller.connect("bell_rung", _on_bell_rung)
	bell_notice.modulate.a = 0.0

func _process(delta: float) -> void:
	# Toggle controls panel visibility
	if Input.is_action_just_pressed("ui_cancel") or Input.is_key_pressed(KEY_H):
		controls_panel.visible = not controls_panel.visible

	# Fade out bell notice
	if bell_timer > 0.0:
		bell_timer -= delta
		bell_notice.modulate.a = clampf(bell_timer / 0.4, 0.0, 1.0)

func _on_telemetry_updated(speed_kmh: float, _cadence_pct: float, is_coasting: bool) -> void:
	speed_label.text = "%3.1f" % speed_kmh
	
	var is_braking: bool = bike_controller.get("is_braking") if bike_controller else false
	var is_pedaling: bool = bike_controller.get("is_pedaling") if bike_controller else false

	if is_braking:
		state_badge.text = "● ТОРМОЖЕНИЕ"
		state_badge.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	elif is_coasting:
		state_badge.text = "● СВОБОДНЫЙ НАКАТ"
		state_badge.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif is_pedaling:
		state_badge.text = "● ПЕДАЛИРОВАНИЕ"
		state_badge.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	else:
		state_badge.text = "● ПОКОЙ"
		state_badge.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))

func _on_bell_rung() -> void:
	bell_timer = 1.0
	bell_notice.modulate.a = 1.0
