class_name DebugHUD
extends CanvasLayer

@export var world_manager: Node
@export var bike_controller: Node

@export var show_on_start: bool = false

@onready var telemetry_label: Label = $Root/Margin/Panel/Label

var max_frame_time_ms: float = 0.0
var last_closest_idx: int = 0
var session_elapsed_sec: float = 0.0

func _ready() -> void:
	visible = show_on_start

func _process(delta: float) -> void:
	session_elapsed_sec += delta

	if Input.is_action_just_pressed("toggle_debug"):
		visible = not visible

	if not visible:
		return

	var frame_ms: float = delta * 1000.0
	if frame_ms > max_frame_time_ms and Engine.get_process_frames() > 60:
		max_frame_time_ms = frame_ms

	var seed_val: int = world_manager.get("world_seed") if world_manager else 0
	var speed_val: float = bike_controller.get("current_speed") if bike_controller else 0.0
	var speed_kmh: float = speed_val * 3.6
	var pitch_val: float = bike_controller.get("current_pitch") if bike_controller else 0.0
	var slope_deg: float = rad_to_deg(pitch_val)
	var on_grass: bool = bike_controller.get("is_on_grass") if bike_controller else false
	
	var active_chunks: int = 0
	var chunk_gen_ms: float = 0.0
	var dist_km: float = 0.0
	var chunk_id: int = 0
	var spline_pts: int = 0

	var road_path: RefCounted = world_manager.get("road_path") if world_manager else null
	if road_path:
		spline_pts = road_path.size()
		var bike_pos: Vector3 = bike_controller.global_position if bike_controller else Vector3.ZERO
		var closest_idx: int = road_path.find_closest_index(bike_pos, last_closest_idx)
		last_closest_idx = closest_idx
		if closest_idx >= 0 and closest_idx < road_path.cumulative_distances.size():
			var cur_s: float = road_path.cumulative_distances[closest_idx]
			dist_km = cur_s / 1000.0
			chunk_id = int(cur_s / 50.0)
		
		var streamer: Node = world_manager.get("chunk_streamer") if world_manager else null
		if streamer:
			active_chunks = streamer.get_active_chunk_count()
			chunk_gen_ms = streamer.get("last_chunk_gen_ms") if "last_chunk_gen_ms" in streamer else 0.0

	var ram_mb: float = float(OS.get_static_memory_usage()) / 1048576.0
	var mins: int = int(session_elapsed_sec) / 60
	var secs: int = int(session_elapsed_sec) % 60

	var text := "=== SLOW CYCLE TELEMETRY (F3) ===\n"
	text += "Time: %02d:%02d | Seed: %d | Distance: %.2f km\n" % [mins, secs, seed_val, dist_km]
	text += "Global Chunk: #%d | Active Chunks: %d\n" % [chunk_id, active_chunks]
	text += "Spline Buffer: %d pts (Pruned) | Chunk Gen: %.2f ms\n" % [spline_pts, chunk_gen_ms]
	text += "Speed: %.1f km/h | Slope: %.1f°\n" % [speed_kmh, slope_deg]
	text += "FPS: %d | Frame: %.1f ms | Max Spike: %.1f ms\n" % [Engine.get_frames_per_second(), frame_ms, max_frame_time_ms]
	text += "RAM Static: %.1f MB\n" % [ram_mb]
	text += "Surface: %s\n" % ("GRASS (High Drag)" if on_grass else "ROAD (Gravel)")
	text += "================================="

	telemetry_label.text = text

