class_name ScreenFader
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var is_fading: bool = false

func _ready() -> void:
	if color_rect:
		color_rect.color = Color(0, 0, 0, 0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_reposition(on_midpoint: Callable) -> void:
	if is_fading:
		return

	if not color_rect:
		color_rect = get_node_or_null("ColorRect")

	if not color_rect:
		on_midpoint.call()
		return

	is_fading = true
	var tween: Tween = create_tween()
	# 1. Fade out to black in 0.22s
	tween.tween_property(color_rect, "color:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	# 2. Trigger callback at midpoint
	tween.tween_callback(on_midpoint)
	# 3. Small hold
	tween.tween_interval(0.08)
	# 4. Fade back in in 0.28s
	tween.tween_property(color_rect, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	# 5. Reset busy flag on completion
	tween.tween_callback(func(): is_fading = false)
