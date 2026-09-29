extends SceneTree

var frames: int = 0

func _init() -> void:
	print("Test screenshot script starting...")
	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	
	# Create directory for screenshots if not exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")

func _process(delta: float) -> bool:
	frames += 1
	if frames == 10:
		var img = root.get_viewport().get_texture().get_image()
		if img != null:
			var path = "res://screenshots/test_frame_10.png"
			img.save_png(path)
			print("Saved screenshot to: ", path, " (size: ", img.get_size(), ")")
		else:
			print("Viewport image is null!")
		quit()
		return true
	return false
