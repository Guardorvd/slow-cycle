class_name DebugHUD
extends CanvasLayer

## Slow Cycle — Diagnostic & Playtest Debug Telemetry Overlay (F3 / F4)
## Provides high-frequency telemetry visualization with zero-GC string throttling,
## semantic route/fork tracking, and instant diagnostic snapshot logging.

@export var world_manager: Node
@export var bike_controller: Node
@export var show_on_start: bool = false

@onready var telemetry_label: Label = $Root/Margin/Panel/Label

# Telemetry throttling & frame profiling
const TELEMETRY_REFRESH_INTERVAL: float = 0.05 # 20 Hz update rate prevents GC thrashing
var telemetry_refresh_timer: float = 0.0
var max_frame_time_ms: float = 0.0
var last_closest_idx: int = 0
var session_elapsed_sec: float = 0.0

# Route style & Fork state semantic labels
const ROUTE_STYLES: Array[String] = ["BALANCED", "FLOW", "TECHNICAL"]
const FORK_STATES: Array[String] = ["APPROACH", "PREVIEW", "COMMIT", "LOCKED"]
const FLOW_PHASE_NAMES: Array[String] = [
	"CRUISE_DOWNHILL", "FAST_GRAVITY", "BRAKING_ZONE", "SWITCHBACK",
	"CREST_DROP", "AIRBORNE_DROP", "LANDING", "RECOVERY_FLAT",
	"WINDING_TRACK", "FOREST_CRUISE"
]

func _ready() -> void:
	visible = show_on_start

func _process(delta: float) -> void:
	session_elapsed_sec += delta
	telemetry_refresh_timer -= delta

	if Input.is_action_just_pressed("toggle_debug"):
		visible = not visible
		if visible:
			max_frame_time_ms = 0.0
			telemetry_refresh_timer = 0.0

	if not visible:
		return

	# High-frequency frame profiling (evaluated every single render frame)
	var frame_ms: float = delta * 1000.0
	if frame_ms > max_frame_time_ms and Engine.get_process_frames() > 60:
		max_frame_time_ms = frame_ms

	# Throttle string allocations for UI label
	if telemetry_refresh_timer > 0.0:
		return
	telemetry_refresh_timer = TELEMETRY_REFRESH_INTERVAL

	_update_telemetry_display(delta, frame_ms)

func _update_telemetry_display(_delta: float, frame_ms: float) -> void:
	var seed_val: int = world_manager.get("world_seed") if world_manager else 0
	var ctrl: BicycleController = bike_controller as BicycleController
	var speed_val: float = ctrl.current_speed if ctrl else (bike_controller.get("current_speed") if bike_controller else 0.0)
	var speed_kmh: float = speed_val * 3.6
	var pitch_val: float = ctrl.current_pitch if ctrl else (bike_controller.get("current_pitch") if bike_controller else 0.0)
	var slope_deg: float = rad_to_deg(pitch_val)

	var steer_deg: float = rad_to_deg(ctrl.current_steer if ctrl else (bike_controller.get("current_steer") if bike_controller else 0.0))
	var bank_deg: float = rad_to_deg(ctrl.current_bank if ctrl else (bike_controller.get("current_bank") if bike_controller else 0.0))
	var radius_val: float = ctrl.turn_radius if ctrl else (bike_controller.get("turn_radius") if bike_controller else INF)
	var radius_str: String = "INF" if is_inf(radius_val) else "%.1fm" % radius_val
	var lat_accel: float = ctrl.lateral_acceleration if ctrl else (bike_controller.get("lateral_acceleration") if bike_controller else 0.0)
	var scrub_accel: float = ctrl.cornering_scrub_accel if ctrl else (bike_controller.get("cornering_scrub_accel") if bike_controller else 0.0)
	var apex_status: String = "SCRUB" if scrub_accel > 0.05 else "FLOW"
	var pedal_pct: float = (ctrl.pedal_power if ctrl else (bike_controller.get("pedal_power") if bike_controller else 0.0)) * 100.0
	var brake_pct: float = (ctrl.brake_input if ctrl else (bike_controller.get("brake_input") if bike_controller else 0.0)) * 100.0
	var dive_deg: float = rad_to_deg(ctrl.brake_dive_pitch if ctrl else (bike_controller.get("brake_dive_pitch") if bike_controller else 0.0))
	
	var active_chunks: int = 0
	var chunk_gen_ms: float = 0.0
	var dist_km: float = 0.0
	var chunk_id: int = 0
	var spline_pts: int = 0
	var bike_pos: Vector3 = bike_controller.global_position if bike_controller else Vector3.ZERO

	# Spline & Road Path Context
	var road_path: RefCounted = world_manager.get("road_path") if world_manager else null
	if road_path:
		spline_pts = road_path.size()
		var streamer: Node = world_manager.get("chunk_streamer") if world_manager else null
		if streamer and "last_closest_idx" in streamer:
			last_closest_idx = streamer.last_closest_idx
		if last_closest_idx >= spline_pts:
			last_closest_idx = maxi(0, spline_pts - 1)

		var closest_idx: int = road_path.find_closest_index(bike_pos, last_closest_idx)
		last_closest_idx = closest_idx
		if closest_idx >= 0 and closest_idx < road_path.cumulative_distances.size():
			var cur_s: float = road_path.cumulative_distances[closest_idx]
			dist_km = cur_s / 1000.0
			chunk_id = int(cur_s / 50.0)
		
		if streamer:
			active_chunks = streamer.get_active_chunk_count()
			chunk_gen_ms = streamer.get("last_chunk_gen_ms") if "last_chunk_gen_ms" in streamer else 0.0

	var mins: int = int(session_elapsed_sec) / 60
	var secs: int = int(session_elapsed_sec) % 60

	# Kinematic Mode String
	var is_sprint: bool = ctrl.is_sprinting if ctrl else (bike_controller.get("is_sprinting") if bike_controller else false)
	var is_pedal: bool = ctrl.is_pedaling if ctrl else (bike_controller.get("is_pedaling") if bike_controller else false)
	var is_brake: bool = ctrl.is_braking if ctrl else (bike_controller.get("is_braking") if bike_controller else false)
	var is_coast: bool = ctrl.is_coasting if ctrl else (bike_controller.get("is_coasting") if bike_controller else false)
	var mode_str := "IDLE"
	if is_brake: mode_str = "BRAKE"
	elif is_sprint: mode_str = "SPRINT"
	elif is_coast: mode_str = "COAST"
	elif is_pedal: mode_str = "CRUISE"

	# Build Visual Hierarchy
	var text := "=== SLOW CYCLE TELEMETRY (F3) ===\n"
	text += "Time: %02d:%02d | Seed: %d | Dist: %.2f km\n" % [mins, secs, seed_val, dist_km]

	# --- Route & Fork Pacing Section (Stage B6 Extension) ---
	var streamer_node: Node = world_manager.get("chunk_streamer") if world_manager else null
	if streamer_node and streamer_node.has_method("get_active_branch"):
		var act_b = streamer_node.get_active_branch()
		if act_b:
			var style_idx: int = act_b.route_style
			var style_str: String = ROUTE_STYLES[style_idx] if style_idx >= 0 and style_idx < ROUTE_STYLES.size() else "UNKNOWN"
			
			var fork_dist_str: String = ""
			if act_b.is_fork_spawned:
				var dist_to_apex: float = bike_pos.distance_to(act_b.fork_node_pos)
				fork_dist_str = "%.0fm (APEX)" % dist_to_apex
			else:
				var current_s: float = dist_km * 1000.0
				var delta_s: float = act_b.next_fork_distance - current_s
				if delta_s < 0.0:
					fork_dist_str = "OVERRUN (+%.0fm)" % absf(delta_s)
				else:
					fork_dist_str = "%.0fm" % delta_s

			var fsm_str := "IDLE"
			var fdm = act_b.get("decision_model") if "decision_model" in act_b else null
			if fdm:
				var state_val: int = fdm.get_state() if fdm.has_method("get_state") else (fdm.get("current_state") if "current_state" in fdm else 0)
				fsm_str = FORK_STATES[state_val] if state_val >= 0 and state_val < FORK_STATES.size() else "?"
				if state_val == 1 or state_val == 2: # PREVIEW or COMMIT
					var conf: float = fdm.get_confidence() if fdm.has_method("get_confidence") else (fdm.get("confidence_score") if "confidence_score" in fdm else 0.0)
					var side_char := "L" if conf < 0 else "R"
					fsm_str += " (%s:%.0f%%)" % [side_char, absf(conf) * 100.0]

			text += "Route: Branch #%d [%s] | Next Fork: %s\n" % [act_b.branch_id, style_str, fork_dist_str]
			text += "Fork State: [%s]\n" % fsm_str

	# Biome & Generation Context (Sprint 6 v4 Observability)
	var road_logic = world_manager.get("road_logic") if world_manager else null
	var biome_str := "N/A"
	var macro_heading_str := "180.0°"
	var fsm_phase_str := "N/A"
	if road_logic:
		if "mountain_profile" in road_logic and road_logic.mountain_profile:
			var m_wt: float = road_logic.mountain_profile.get_mountain_weight_at(dist_km * 1000.0)
			var b_name: String = "MOUNTAIN" if m_wt > 0.65 else ("FOREST" if m_wt < 0.35 else "TRANS")
			biome_str = "%s (wt: %.2f)" % [b_name, m_wt]
		if "_macro_heading_deg" in road_logic:
			macro_heading_str = "%.1f°" % road_logic._macro_heading_deg
		if "grammar" in road_logic and road_logic.grammar:
			var ph: int = road_logic.grammar.current_phase
			fsm_phase_str = FLOW_PHASE_NAMES[ph] if ph >= 0 and ph < FLOW_PHASE_NAMES.size() else "PHASE_%d" % ph
	text += "Biome: %s | FSM: [%s] | Macro: %s\n" % [biome_str, fsm_phase_str, macro_heading_str]

	# Track Section Label
	if world_manager and world_manager.has_method("get_section_at_distance"):
		var sec_info: Dictionary = world_manager.get_section_at_distance(dist_km * 1000.0)
		text += "Track Section: [%s] %s (%s)\n" % [sec_info.get("code", "?"), sec_info.get("name", ""), sec_info.get("target", "")]

	text += "Chunks: Global #%d | Active: %d | Gen: %.1f ms\n" % [chunk_id, active_chunks, chunk_gen_ms]

	# Dynamics & Steering
	var vis_steer_deg: float = rad_to_deg(ctrl.visual_steer if ctrl else (bike_controller.get("visual_steer") if bike_controller else 0.0))
	var cadence_rpm: float = ctrl.current_cadence_rpm if ctrl else (bike_controller.get("current_cadence_rpm") if bike_controller else 0.0)
	var skid_pct: float = (ctrl.visual_skid_factor if ctrl else (bike_controller.get("visual_skid_factor") if bike_controller else 0.0)) * 100.0

	text += "Speed: %.1f km/h | Mode: %s | Slope: %.1f°\n" % [speed_kmh, mode_str, slope_deg]
	text += "Steer: %.1f° (Vis: %.1f°) | Bank: %.1f° | R: %s\n" % [steer_deg, vis_steer_deg, bank_deg, radius_str]
	text += "Cadence: %.0f RPM | Skid: %.0f%% | Dive: %.1f°\n" % [cadence_rpm, skid_pct, dive_deg]
	text += "Lat Accel: %.2f m/s² | Cornering: [%s]\n" % [lat_accel, apex_status]
	text += "Pedal: %.0f%% | Brake: %.0f%%\n" % [pedal_pct, brake_pct]

	# Surface & Chassis
	var surface_enum: int = ctrl.current_surface if ctrl else (bike_controller.get("current_surface") if bike_controller else 0)
	var surface_name: String = "ROAD (Gravel)"
	if surface_enum == 1: surface_name = "GRASS (High Drag)"
	elif surface_enum == 2: surface_name = "ROUGH_GRAVEL (Washboard)"
	var susp_mm: float = (ctrl.suspension_compression if ctrl else (bike_controller.get("suspension_compression") if bike_controller else 0.0)) * 1000.0
	text += "Surface: %s | Susp: %+dmm\n" % [surface_name, int(round(susp_mm))]

	# Render & Performance Profiler
	var ram_mb: float = float(OS.get_static_memory_usage()) / 1048576.0
	text += "Perf: %d FPS (%.1f ms) | Spike: %.1f ms | RAM: %.1f MB\n" % [Engine.get_frames_per_second(), frame_ms, max_frame_time_ms, ram_mb]

	# Camera Rig Context
	var cam_rig = ctrl.camera_rig if ctrl and ctrl.camera_rig else (bike_controller.get("camera_rig") if (bike_controller and "camera_rig" in bike_controller) else null)
	if not cam_rig and bike_controller:
		cam_rig = bike_controller.get_node_or_null("CameraRig")
	if cam_rig:
		var cam_mode: String = "FP" if (cam_rig.get("is_first_person") if "is_first_person" in cam_rig else true) else "TP"
		var fp_cam = cam_rig.get("first_person_cam") if "first_person_cam" in cam_rig else null
		var cur_fov: float = fp_cam.fov if fp_cam else 78.0
		var c_roll: float = rad_to_deg(cam_rig.current_roll if "current_roll" in cam_rig else 0.0)
		var c_pitch: float = rad_to_deg(cam_rig.current_dive_pitch if "current_dive_pitch" in cam_rig else 0.0)
		text += "Camera: %s | FOV: %.1f° | Roll: %.1f° | Dive: %.1f°\n" % [cam_mode, cur_fov, c_roll, c_pitch]

	text += "================================="
	telemetry_label.text = text

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F4:
			_capture_telemetry_snapshot()

func _capture_telemetry_snapshot() -> void:
	var ctrl: BicycleController = bike_controller as BicycleController
	var speed_val: float = ctrl.current_speed if ctrl else (bike_controller.get("current_speed") if bike_controller else 0.0)
	var speed_kmh: float = speed_val * 3.6
	var slope_deg: float = rad_to_deg(ctrl.current_pitch if ctrl else (bike_controller.get("current_pitch") if bike_controller else 0.0))
	var bank_deg: float = rad_to_deg(ctrl.current_bank if ctrl else (bike_controller.get("current_bank") if bike_controller else 0.0))
	var steer_deg: float = rad_to_deg(ctrl.current_steer if ctrl else (bike_controller.get("current_steer") if bike_controller else 0.0))
	var lat_accel: float = ctrl.lateral_acceleration if ctrl else (bike_controller.get("lateral_acceleration") if bike_controller else 0.0)
	var scrub_accel: float = ctrl.cornering_scrub_accel if ctrl else (bike_controller.get("cornering_scrub_accel") if bike_controller else 0.0)
	var cadence_rpm: float = ctrl.current_cadence_rpm if ctrl else (bike_controller.get("current_cadence_rpm") if bike_controller else 0.0)
	var fps: int = Engine.get_frames_per_second()
	var ram_mb: float = float(OS.get_static_memory_usage()) / 1048576.0

	var sec_code: String = "N/A"
	var sec_name: String = "N/A"
	if world_manager and world_manager.has_method("get_section_at_distance"):
		var road_path: RefCounted = world_manager.get("road_path") if world_manager else null
		if road_path and last_closest_idx >= 0 and last_closest_idx < road_path.cumulative_distances.size():
			var cur_s: float = road_path.cumulative_distances[last_closest_idx]
			var sec_info: Dictionary = world_manager.get_section_at_distance(cur_s)
			sec_code = sec_info.get("code", "?")
			sec_name = sec_info.get("name", "")

	# Topology Context for Snapshot
	var branch_id: int = -1
	var route_style_str: String = "UNKNOWN"
	var fork_state_str: String = "UNKNOWN"
	var dist_to_fork: float = -1.0
	var streamer: Node = world_manager.get("chunk_streamer") if world_manager else null
	if streamer and streamer.has_method("get_active_branch"):
		var act_b = streamer.get_active_branch()
		if act_b:
			branch_id = act_b.branch_id
			if act_b.route_style >= 0 and act_b.route_style < ROUTE_STYLES.size():
				route_style_str = ROUTE_STYLES[act_b.route_style]
			dist_to_fork = act_b.next_fork_distance
			var fdm = act_b.get("decision_model") if "decision_model" in act_b else null
			if fdm:
				var st: int = fdm.get_state() if fdm.has_method("get_state") else (fdm.get("current_state") if "current_state" in fdm else 0)
				fork_state_str = FORK_STATES[st] if st >= 0 and st < FORK_STATES.size() else "?"

	var snapshot: Dictionary = {
		"timestamp_ms": Time.get_ticks_msec(),
		"branch_id": branch_id,
		"route_style": route_style_str,
		"fork_state": fork_state_str,
		"dist_to_fork_m": roundf(dist_to_fork * 10.0) / 10.0,
		"section_code": sec_code,
		"section_name": sec_name,
		"speed_kmh": roundf(speed_kmh * 10.0) / 10.0,
		"slope_deg": roundf(slope_deg * 10.0) / 10.0,
		"bank_deg": roundf(bank_deg * 10.0) / 10.0,
		"steer_deg": roundf(steer_deg * 10.0) / 10.0,
		"lat_accel": roundf(lat_accel * 100.0) / 100.0,
		"scrub_accel": roundf(scrub_accel * 100.0) / 100.0,
		"cadence_rpm": roundf(cadence_rpm),
		"fps": fps,
		"static_ram_mb": roundf(ram_mb * 10.0) / 10.0
	}

	var json_line: String = JSON.stringify(snapshot)
	var snap_path: String = "user://playtest_snapshots.json"
	var file: FileAccess
	if FileAccess.file_exists(snap_path):
		file = FileAccess.open(snap_path, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(snap_path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(json_line)
		file.close()
		print("[PLAYTEST_SNAPSHOT F4] Saved: Branch #%d [%s] | State: %s | %.1f km/h | Bank: %.1f° | FPS: %d" % [branch_id, route_style_str, fork_state_str, speed_kmh, bank_deg, fps])
