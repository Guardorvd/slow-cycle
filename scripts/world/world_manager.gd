class_name WorldManager
extends Node3D

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")
const LoggerClass = preload("res://scripts/core/slow_cycle_logger.gd")

@export var world_seed: int = 184729
@export var randomize_world_seed_on_start: bool = false
@export var player: Node3D

var road_path: RefCounted
var road_logic: RefCounted
var chunk_streamer: Node3D
var diagnostics_logger: Node
var _opening_diagnostic_recorded: bool = false

var shared_materials: Dictionary = {}
var shared_meshes: Dictionary = {}

func _ready() -> void:
	var requested_seed: int = world_seed
	_resolve_session_seed(OS.get_cmdline_args(), OS.get_cmdline_user_args())
	diagnostics_logger = LoggerClass.new()
	diagnostics_logger.name = "SessionDiagnostics"
	diagnostics_logger.start_session({"scene": get_parent().scene_file_path, "requested_seed": requested_seed, "effective_seed": world_seed, "randomize_on_start": randomize_world_seed_on_start}, self)
	add_child(diagnostics_logger)

	_init_shared_resources()
	
	road_path = RoadPathDataClass.new()
	road_logic = RoadLogicClass.new(world_seed, road_path)

	# Setup streamer
	chunk_streamer = ChunkStreamerClass.new()
	chunk_streamer.setup(self, road_path, road_logic, shared_materials, shared_meshes)
	add_child(chunk_streamer)
	diagnostics_logger.manifest["generation_config"] = diagnostic_generation_config()
	diagnostics_logger.save_session()

## Keep the generator deterministic after choosing its session seed. Normal gameplay
## can request a fresh value, while explicit CLI seeds always win for replay/tests.
func _resolve_session_seed(command_args: PackedStringArray, user_args: PackedStringArray) -> void:
	var seed_override: Variant = _find_seed_override(command_args)
	var user_seed_override: Variant = _find_seed_override(user_args)
	if user_seed_override != null:
		seed_override = user_seed_override
	if seed_override != null:
		world_seed = int(seed_override)
		return
	if randomize_world_seed_on_start:
		var session_rng := RandomNumberGenerator.new()
		session_rng.randomize()
		world_seed = session_rng.randi_range(1, 2147483647)

func _find_seed_override(arguments: PackedStringArray) -> Variant:
	for arg: String in arguments:
		if arg.begins_with("--seed="):
			var value: String = arg.trim_prefix("--seed=")
			if value.is_valid_int():
				return value.to_int()
	return null

func _process(delta: float) -> void:
	var player_pos: Vector3 = player.global_position if player else Vector3.ZERO
	var player_vel: Vector3 = Vector3.ZERO
	if player:
		if "velocity" in player:
			player_vel = player.velocity
		elif "linear_velocity" in player:
			player_vel = player.linear_velocity
	if chunk_streamer:
		chunk_streamer.update_streaming(player_pos, player_vel, delta)
		if not _opening_diagnostic_recorded and is_instance_valid(diagnostics_logger):
			var branch = chunk_streamer.get_active_branch()
			if branch and branch.road_path and branch.road_path.size() >= 2 and branch.road_path.get_total_distance() >= 100.0:
				_opening_diagnostic_recorded = true
				diagnostics_logger.record_checkpoint("automatic_opening", 0.0, 100.0)

## Diagnostic observation only. No commands to the bicycle or generator.
func diagnostic_generation_config() -> Dictionary:
	if not is_instance_valid(chunk_streamer):
		return {"available": false}
	return {"available": true, "ahead_m": chunk_streamer.AHEAD_DISTANCE, "behind_m": chunk_streamer.BEHIND_DISTANCE, "first_fork_m": chunk_streamer.first_fork_distance, "fork_interval_m": chunk_streamer.fork_interval_dist, "preload_m": chunk_streamer.preload_distance, "max_chunks_per_frame": chunk_streamer.MAX_CHUNKS_PER_FRAME, "safety_corridor_m": chunk_streamer.safety_corridor_margin, "fork_safety_radius_m": chunk_streamer.fork_safety_radius}

func diagnostic_snapshot() -> Dictionary:
	var result := {"context_available": true, "effective_seed": world_seed, "player_available": (is_instance_valid(player) and player.is_inside_tree()), "path_available": false, "surface_checked": false}
	if (is_instance_valid(player) and player.is_inside_tree()):
		result["player_pose"] = player.global_transform
		result["speed_m_s"] = player.velocity.length() if "velocity" in player else null
	if not is_instance_valid(chunk_streamer):
		return result
	var branch = chunk_streamer.get_active_branch()
	if branch == null or branch.road_path == null or branch.road_path.size() < 2:
		return result
	var path: RefCounted = branch.road_path
	result["path_available"] = true
	result["branch_id"] = branch.branch_id
	result["branch_seed"] = branch.road_logic.world_seed
	result["route_origin_m"] = branch.road_logic.profile_distance_origin_m
	result["path_range_m"] = [path.cumulative_distances[0], path.cumulative_distances[-1]]
	result["active_chunks"] = branch.active_chunks.keys()
	if (is_instance_valid(player) and player.is_inside_tree()):
		var index: int = path.find_closest_index(player.global_position)
		result["nearest_sample_s"] = path.cumulative_distances[index]
		result["nearest_sample_position"] = path.points[index]
		result["sampled_route_s"] = branch.road_logic.profile_distance_origin_m + path.cumulative_distances[index]
	return result

func diagnostic_checkpoint(start_s: float, end_s: float) -> Dictionary:
	if not is_instance_valid(chunk_streamer):
		return {"available": false, "reason": "STREAMER_MISSING"}
	var branch = chunk_streamer.get_active_branch()
	if branch == null or branch.road_path == null or branch.road_path.size() < 2:
		return {"available": false, "reason": "PATH_MISSING"}
	var path: RefCounted = branch.road_path
	if not is_finite(start_s) or not is_finite(end_s) or start_s >= end_s or start_s < path.cumulative_distances[0] or end_s > path.cumulative_distances[-1]:
		return {"available": false, "reason": "CHECKPOINT_OUTSIDE_PATH"}
	var signature_parts := PackedStringArray()
	var s := start_s
	var count := 0
	while s <= end_s:
		var sample: Dictionary = path.get_sample_at_distance(s)
		if not sample.position.is_finite() or not sample.tangent.is_finite() or not sample.normal.is_finite():
			return {"available": false, "reason": "CHECKPOINT_NONFINITE"}
		signature_parts.append("%s|%s|%s" % [sample.position, sample.tangent, sample.normal])
		count += 1
		s += 2.0
	return {"available": true, "branch_id": branch.branch_id, "branch_seed": branch.road_logic.world_seed, "route_origin_m": branch.road_logic.profile_distance_origin_m, "range_m": [start_s, end_s], "step_m": 2.0, "samples": count, "signature": "\n".join(signature_parts).sha256_text(), "start_position": path.get_sample_at_distance(start_s).position, "snapshot": diagnostic_snapshot()}

func report_diagnostic_problem(code: String, details: Dictionary = {}) -> void:
	if is_instance_valid(diagnostics_logger):
		diagnostics_logger.record_problem(code, details)

func request_bike_recovery(current_pos: Vector3) -> Transform3D:
	var active_path: RefCounted = road_path
	if chunk_streamer and chunk_streamer.has_method("get_active_road_path"):
		var p = chunk_streamer.get_active_road_path()
		if p != null and p.size() >= 2:
			active_path = p

	if not active_path or active_path.size() < 2:
		return Transform3D(Basis(), Vector3(0, 4.0, 0))

	var hint_idx: int = 0
	if chunk_streamer and "last_closest_idx" in chunk_streamer:
		hint_idx = chunk_streamer.last_closest_idx
	var closest_idx: int = active_path.find_closest_index(current_pos, hint_idx)
	var current_dist: float = active_path.cumulative_distances[closest_idx]
	var target_dist: float = maxf(0.0, current_dist - 20.0)

	var sample: Dictionary = active_path.get_sample_at_distance(target_dist)
	var pos: Vector3 = sample.get("position", Vector3.ZERO)
	var tang: Vector3 = sample.get("tangent", Vector3.FORWARD)
	var norm: Vector3 = sample.get("normal", Vector3.UP)

	var spawn_pos: Vector3 = pos + norm * 0.45
	var horiz_tang: Vector3 = Vector3(tang.x, 0.0, tang.z).normalized()
	if horiz_tang.is_zero_approx():
		horiz_tang = Vector3.FORWARD
	var spawn_basis: Basis = Basis.looking_at(horiz_tang, Vector3.UP)

	return Transform3D(spawn_basis, spawn_pos)

func _init_shared_resources() -> void:
	var road_mat: Material = load("res://assets/materials/gravel_road.tres")
	var grass_mat: Material = load("res://assets/materials/roadside_grass.tres")
	shared_materials["road"] = road_mat
	shared_materials["grass"] = grass_mat

	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = world_seed
	terrain_noise.frequency = 0.04
	shared_materials["noise"] = terrain_noise
	shared_materials["terrain_carver"] = TerrainCarverClass.new(world_seed)

	shared_meshes["pine"] = _build_pine_mesh()
	shared_meshes["birch"] = _build_birch_mesh()
	shared_meshes["grass"] = _build_grass_mesh()
	shared_meshes["boulder"] = _build_boulder_mesh()

func _build_pine_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var needle_mat := StandardMaterial3D.new()
	needle_mat.albedo_color = Color(0.16, 0.32, 0.20)
	needle_mat.roughness = 0.85
	st.set_material(needle_mat)

	# 1. Trunk (y=0 to y=1.8)
	var segs: int = 7
	var trunk_r: float = 0.18
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * trunk_r, 0.0, sin(a0) * trunk_r)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a0) * trunk_r * 0.8, 1.8, sin(a0) * trunk_r * 0.8)
		var p3 := Vector3(cos(a1) * trunk_r * 0.8, 1.8, sin(a1) * trunk_r * 0.8)

		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)

	# 2. Cones
	var cones := [
		{"y": 1.4, "r": 1.45, "h": 1.8},
		{"y": 2.5, "r": 1.15, "h": 1.6},
		{"y": 3.4, "r": 0.75, "h": 1.4}
	]
	for c in cones:
		var base_y: float = c["y"]
		var tip_y: float = base_y + c["h"]
		var r: float = c["r"]
		for i in range(segs):
			var a0: float = (float(i) / float(segs)) * TAU
			var a1: float = (float(i + 1) / float(segs)) * TAU
			var p0 := Vector3(cos(a0) * r, base_y, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, base_y, sin(a1) * r)
			var p_tip := Vector3(0, tip_y, 0)
			
			st.add_vertex(p0)
			st.add_vertex(p_tip)
			st.add_vertex(p1)

	st.generate_normals()
	return st.commit()

func _build_birch_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.40, 0.58, 0.24) # Fresh vibrant mountain birch
	leaf_mat.roughness = 0.82
	st.set_material(leaf_mat)

	# 1. Trunk (y=0 to y=2.8)
	var segs: int = 6
	var trunk_r: float = 0.12
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p0 := Vector3(cos(a0) * trunk_r, 0.0, sin(a0) * trunk_r)
		var p1 := Vector3(cos(a1) * trunk_r, 0.0, sin(a1) * trunk_r)
		var p2 := Vector3(cos(a0) * trunk_r * 0.75, 2.8, sin(a0) * trunk_r * 0.75)
		var p3 := Vector3(cos(a1) * trunk_r * 0.75, 2.8, sin(a1) * trunk_r * 0.75)

		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
		st.add_vertex(p1); st.add_vertex(p2); st.add_vertex(p3)

	# 2. Natural 3-Cluster Low-Poly Organic Canopy
	var clusters := [
		{"center": Vector3(0.0, 3.2, 0.0), "r": 1.15, "segs": 7},
		{"center": Vector3(0.30, 4.0, -0.20), "r": 0.85, "segs": 6},
		{"center": Vector3(-0.25, 2.8, 0.25), "r": 0.80, "segs": 6}
	]

	for cl in clusters:
		var c_pos: Vector3 = cl["center"]
		var cr: float = cl["r"]
		var c_segs: int = cl["segs"]

		var pole_top := c_pos + Vector3(0.0, cr * 1.05, 0.0)
		var pole_bot := c_pos + Vector3(0.0, -cr * 0.95, 0.0)

		var r_mid: float = cr
		var r_top: float = cr * 0.72
		var r_bot: float = cr * 0.68

		var y_top: float = c_pos.y + cr * 0.50
		var y_mid: float = c_pos.y
		var y_bot: float = c_pos.y - cr * 0.45

		var ring_top: Array[Vector3] = []
		var ring_mid: Array[Vector3] = []
		var ring_bot: Array[Vector3] = []

		for i in range(c_segs):
			var a: float = (float(i) / float(c_segs)) * TAU
			ring_top.append(Vector3(c_pos.x + cos(a) * r_top, y_top, c_pos.z + sin(a) * r_top))
			ring_mid.append(Vector3(c_pos.x + cos(a + 0.2) * r_mid, y_mid, c_pos.z + sin(a + 0.2) * r_mid))
			ring_bot.append(Vector3(c_pos.x + cos(a) * r_bot, y_bot, c_pos.z + sin(a) * r_bot))

		for i in range(c_segs):
			var i_next: int = (i + 1) % c_segs

			# Top cone
			st.add_vertex(ring_top[i]); st.add_vertex(pole_top); st.add_vertex(ring_top[i_next])

			# Upper band
			st.add_vertex(ring_mid[i]); st.add_vertex(ring_top[i]); st.add_vertex(ring_mid[i_next])
			st.add_vertex(ring_mid[i_next]); st.add_vertex(ring_top[i]); st.add_vertex(ring_top[i_next])

			# Lower band
			st.add_vertex(ring_bot[i]); st.add_vertex(ring_mid[i]); st.add_vertex(ring_bot[i_next])
			st.add_vertex(ring_bot[i_next]); st.add_vertex(ring_mid[i]); st.add_vertex(ring_mid[i_next])

			# Bottom cone
			st.add_vertex(ring_bot[i_next]); st.add_vertex(pole_bot); st.add_vertex(ring_bot[i])

	st.generate_normals()
	return st.commit()

func _build_grass_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.26, 0.46, 0.20)
	grass_mat.roughness = 0.9
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(grass_mat)

	var h: float = 0.55
	var w: float = 0.35
	st.add_vertex(Vector3(-w, 0, 0)); st.add_vertex(Vector3(0, h, 0)); st.add_vertex(Vector3(w, 0, 0))
	st.add_vertex(Vector3(0, 0, -w)); st.add_vertex(Vector3(0, h, 0)); st.add_vertex(Vector3(0, 0, w))

	st.generate_normals()
	return st.commit()

func _build_boulder_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.42, 0.40, 0.38) # Weathered granite / slate
	rock_mat.roughness = 0.92
	st.set_material(rock_mat)

	# Low-poly faceted boulder (6-segment base ring, 6-segment mid ring, apex)
	var base_r: float = 0.55
	var mid_r: float = 0.70
	var mid_y: float = 0.40
	var top_y: float = 0.75
	var segs: int = 6

	var rad_perturb: Array[float] = [1.0, 0.85, 1.15, 0.90, 1.10, 0.95]
	var y_perturb: Array[float] = [0.0, 0.08, -0.05, 0.06, -0.04, 0.05]

	var base_pts: Array[Vector3] = []
	var mid_pts: Array[Vector3] = []

	for i in range(segs):
		var a: float = (float(i) / float(segs)) * TAU
		var p_base := Vector3(cos(a) * base_r * rad_perturb[i], 0.0, sin(a) * base_r * rad_perturb[i])
		var p_mid := Vector3(cos(a) * mid_r * rad_perturb[(i + 2) % segs], mid_y + y_perturb[i], sin(a) * mid_r * rad_perturb[(i + 2) % segs])
		base_pts.append(p_base)
		mid_pts.append(p_mid)

	var apex := Vector3(0.05, top_y, -0.04)

	# Quads between base and mid
	for i in range(segs):
		var i_next: int = (i + 1) % segs
		st.add_vertex(base_pts[i]); st.add_vertex(mid_pts[i]); st.add_vertex(base_pts[i_next])
		st.add_vertex(base_pts[i_next]); st.add_vertex(mid_pts[i]); st.add_vertex(mid_pts[i_next])

	# Triangles from mid to apex
	for i in range(segs):
		var i_next: int = (i + 1) % segs
		st.add_vertex(mid_pts[i]); st.add_vertex(apex); st.add_vertex(mid_pts[i_next])

	st.generate_normals()
	return st.commit()


