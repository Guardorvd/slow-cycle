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

	var steer_deg: float = rad_to_deg(bike_controller.get("current_steer")) if bike_controller else 0.0
	var bank_deg: float = rad_to_deg(bike_controller.get("current_bank")) if bike_controller else 0.0
	var yaw_rate: float = bike_controller.get("yaw_turn_rate") if bike_controller else 0.0
	var radius_val: float = bike_controller.get("turn_radius") if bike_controller else INF
	var radius_str: String = "INF" if is_inf(radius_val) else "%.1fm" % radius_val
	var lat_accel: float = bike_controller.get("lateral_acceleration") if bike_controller else 0.0
	var scrub_accel: float = bike_controller.get("cornering_scrub_accel") if bike_controller else 0.0
	var apex_status: String = "SCRUB" if scrub_accel > 0.05 else "FLOW"
	var pedal_pct: float = (bike_controller.get("pedal_power") if bike_controller else 0.0) * 100.0
	var brake_pct: float = (bike_controller.get("brake_input") if bike_controller else 0.0) * 100.0
	var dive_deg: float = rad_to_deg(bike_controller.get("brake_dive_pitch")) if bike_controller else 0.0
	
	var active_chunks: int = 0
	var chunk_gen_ms: float = 0.0
	var dist_km: float = 0.0
	var chunk_id: int = 0
	var spline_pts: int = 0

	var road_path: RefCounted = world_manager.get("road_path") if world_manager else null
	if road_path:
		spline_pts = road_path.size()
		var streamer: Node = world_manager.get("chunk_streamer") if world_manager else null
		if streamer and "last_closest_idx" in streamer:
			last_closest_idx = streamer.last_closest_idx
		if last_closest_idx >= spline_pts:
			last_closest_idx = maxi(0, spline_pts - 1)

		var bike_pos: Vector3 = bike_controller.global_position if bike_controller else Vector3.ZERO
		var closest_idx: int = road_path.find_closest_index(bike_pos, last_closest_idx)
		last_closest_idx = closest_idx
		if closest_idx >= 0 and closest_idx < road_path.cumulative_distances.size():
			var cur_s: float = road_path.cumulative_distances[closest_idx]
			dist_km = cur_s / 1000.0
			chunk_id = int(cur_s / 50.0)
		
		if streamer:
			active_chunks = streamer.get_active_chunk_count()
			chunk_gen_ms = streamer.get("last_chunk_gen_ms") if "last_chunk_gen_ms" in streamer else 0.0

	var ram_mb: float = float(OS.get_static_memory_usage()) / 1048576.0
	var mins: int = int(session_elapsed_sec) / 60
	var secs: int = int(session_elapsed_sec) % 60

	var long_accel: float = bike_controller.get("longitudinal_acceleration") if bike_controller else 0.0
	var sprint_boost_val: float = bike_controller.get("sprint_boost") if bike_controller else 0.0
	var is_sprint: bool = bike_controller.get("is_sprinting") if bike_controller else false
	var is_pedal: bool = bike_controller.get("is_pedaling") if bike_controller else false
	var is_brake: bool = bike_controller.get("is_braking") if bike_controller else false
	var is_coast: bool = bike_controller.get("is_coasting") if bike_controller else false
	var mode_str := "IDLE"
	if is_brake: mode_str = "BRAKE"
	elif is_sprint: mode_str = "SPRINT"
	elif is_coast: mode_str = "COAST"
	elif is_pedal: mode_str = "CRUISE"

	var text := "=== SLOW CYCLE TELEMETRY (F3) ===\n"
	text += "Time: %02d:%02d | Seed: %d | Distance: %.2f km\n" % [mins, secs, seed_val, dist_km]
	if world_manager and world_manager.has_method("get_section_at_distance"):
		var sec_info: Dictionary = world_manager.get_section_at_distance(dist_km * 1000.0)
		text += "Track Section: [%s] %s (%s)\n" % [sec_info.get("code", "?"), sec_info.get("name", ""), sec_info.get("target", "")]
	text += "Global Chunk: #%d | Active Chunks: %d\n" % [chunk_id, active_chunks]
	text += "Spline Buffer: %d pts (Pruned) | Chunk Gen: %.2f ms\n" % [spline_pts, chunk_gen_ms]

	var vis_steer_deg: float = rad_to_deg(bike_controller.get("visual_steer")) if bike_controller else 0.0
	var cadence_rpm: float = bike_controller.get("current_cadence_rpm") if bike_controller else 0.0
	var skid_pct: float = (bike_controller.get("visual_skid_factor") if bike_controller else 0.0) * 100.0

	text += "Speed: %.1f km/h | Long Accel: %+.2f m/s² | Mode: %s\n" % [speed_kmh, long_accel, mode_str]
	text += "Slope: %.1f° | Steer: %.1f° (Vis: %.1f°) | Bank: %.1f°\n" % [slope_deg, steer_deg, vis_steer_deg, bank_deg]
	text += "Cadence: %.0f RPM | Skid: %.0f%% | Dive: %.1f° | Radius: %s\n" % [cadence_rpm, skid_pct, dive_deg, radius_str]
	text += "Lat Accel: %.2f m/s² | Scrub: %.2f m/s² [%s] | Pedals: %.0f%% | Brake: %.0f%%\n" % [lat_accel, scrub_accel, apex_status, pedal_pct, brake_pct]
	text += "FPS: %d | Frame: %.1f ms | Max Spike: %.1f ms\n" % [Engine.get_frames_per_second(), frame_ms, max_frame_time_ms]
	var surface_enum: int = bike_controller.get("current_surface") if bike_controller else 0
	var surface_name: String = "ROAD (Gravel)"
	if surface_enum == 1: surface_name = "GRASS (High Drag)"
	elif surface_enum == 2: surface_name = "ROUGH_GRAVEL (Washboard)"
	var rough_pct: float = (bike_controller.get("terrain_roughness") if bike_controller else 0.16) * 100.0
	var susp_mm: float = (bike_controller.get("suspension_compression") if bike_controller else 0.0) * 1000.0
	text += "Surface: %s | Rough: %.0f%% | Susp: %+dmm\n" % [surface_name, rough_pct, int(round(susp_mm))]
	text += "================================="

	telemetry_label.text = text

