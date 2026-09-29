extends SceneTree

## Verifies the shared macro elevation profile reaches real road and roadside geometry.

const ProfileBlend: float = 0.35
const RoadContract = preload("res://scripts/world/road_generation_contract.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const CarverClass = preload("res://scripts/world/terrain_carver.gd")
const SEEDS: Array[int] = [184729, 42]

var checks: int = 0
var failures: int = 0

func _init() -> void:
	for seed_value in SEEDS:
		var first: Dictionary = await _capture_seed(seed_value)
		var second: Dictionary = await _capture_seed(seed_value)
		_check(not first.is_empty() and not second.is_empty(), "seed %d generated both fork arms" % seed_value)
		if not first.is_empty() and not second.is_empty():
			_check(first.signature == second.signature, "seed %d repeated road/profile geometry" % seed_value)
	print("MACRO_PROFILE_ROAD_INTEGRATION_SUMMARY checks=%d failures=%d seeds=%d" % [checks, failures, SEEDS.size()])
	quit(1 if failures > 0 else 0)

func _capture_seed(seed_value: int) -> Dictionary:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	var world_manager: Node = scene.get_node("WorldManager")
	world_manager.randomize_world_seed_on_start = false
	world_manager.world_seed = seed_value
	root.add_child(scene)
	await process_frame
	await physics_frame
	world_manager.set_process(false)
	var streamer: Node = world_manager.chunk_streamer
	var parent = streamer.get_active_branch()
	if parent == null or parent.road_path.size() < 2 or parent.road_logic.mountain_profile == null:
		_check(false, "seed %d trunk/profile initializes" % seed_value)
		scene.queue_free()
		await process_frame
		return {}
	var junction_idx: int = parent.road_path.size() - 1
	var junction_pos: Vector3 = parent.road_path.points[junction_idx]
	var junction_s: float = parent.road_logic.profile_distance_origin_m + parent.road_path.cumulative_distances[junction_idx]
	streamer._spawn_procedural_fork(parent)
	var node_continuity: Dictionary = streamer.road_graph.validate_node_continuity(parent.graph_fork_node_id)
	print("FORK_PROFILE_CONTINUITY seed=%d valid=%s tangent=%.3fdeg pos=%.4fm" % [seed_value, node_continuity.get("is_valid", false), node_continuity.get("max_tangent_angle_deg", -1.0), node_continuity.get("max_pos_error_m", -1.0)])
	_check(node_continuity.get("is_valid", false), "fork tangent continuity remains within RoadGraph contract")
	if parent.child_branch_ids.is_empty():
		_check(false, "seed %d created right alternative" % seed_value)
		scene.queue_free()
		await process_frame
		return {}
	var right_branch = streamer.branches.get(parent.child_branch_ids[0], null)
	if right_branch == null:
		_check(false, "seed %d right branch exists" % seed_value)
		scene.queue_free()
		await process_frame
		return {}
	_check(parent.road_logic.mountain_profile == right_branch.road_logic.mountain_profile, "both arms share immutable seeded profile")
	var left_start: int = parent.road_path.size() - 26
	_check(absf(right_branch.road_logic.profile_distance_origin_m - (junction_s + 0.9)) < 0.001, "right branch profile starts at arm centerline route distance")
	var left_inner: Vector3 = parent.road_path.points[left_start] + parent.road_path.binormals[left_start] * (parent.road_path.road_widths[left_start] * 0.5)
	var right_inner: Vector3 = right_branch.road_path.points[0] - right_branch.road_path.binormals[0] * (right_branch.road_path.road_widths[0] * 0.5)
	_check(left_inner.distance_to(right_inner) <= 0.001, "left and right arm inner edges remain watertight at fork")
	_check(absf(right_branch.road_path.points[0].y - junction_pos.y) < 0.05, "arm elevation transitions smoothly from junction profile")
	_check(_check_path_profile(parent.road_path, left_start, parent.road_path.size() - 1, parent.road_logic), "left arm samples match shared profile")
	_check(_check_path_profile(right_branch.road_path, 0, right_branch.road_path.size() - 1, right_branch.road_logic), "right arm samples match shared profile")
	_check(_check_terrain_follows_road(world_manager, parent.road_path, left_start), "terrain cross-section follows macro road height")
	var signature_parts: PackedStringArray = PackedStringArray()
	for branch_path in [parent.road_path, right_branch.road_path]:
		for i in range(branch_path.size()):
			signature_parts.append("%.5f,%.5f,%.5f,%.5f" % [branch_path.points[i].x, branch_path.points[i].y, branch_path.points[i].z, branch_path.macro_elevation_offsets[i]])
	var signature: int = hash("|".join(signature_parts))
	scene.queue_free()
	await process_frame
	await process_frame
	return {"signature": signature}

func _check_path_profile(path: RefCounted, start_idx: int, end_idx: int, logic: RefCounted) -> bool:
	if path == null or path.size() < 2 or path.macro_elevation_offsets.size() != path.size():
		_check(false, "path carries one macro offset per sample")
		return false
	var all_ok: bool = true
	for i in range(start_idx, end_idx + 1):
		var global_s: float = logic.profile_distance_origin_m + path.cumulative_distances[i]
		var expected_offset: float = ProfileBlend * logic.mountain_profile.centerline_offset_at(global_s)
		var offset_ok: bool = absf(path.macro_elevation_offsets[i] - expected_offset) <= 0.003
		var grade_ok: bool = RoadContract.is_slope_within_bounds(path.slopes[i])
		var tangent_ok: bool = absf(path.slopes[i] - rad_to_deg(asin(clampf(path.tangents[i].y, -1.0, 1.0)))) <= 0.001
		_check(offset_ok, "profile offset matches global route distance at sample %d" % i)
		_check(grade_ok, "integrated road grade within contract at sample %d" % i)
		_check(tangent_ok, "slope matches updated tangent at sample %d" % i)
		all_ok = all_ok and offset_ok and grade_ok and tangent_ok
	return all_ok

func _check_terrain_follows_road(world_manager: Node, path: RefCounted, idx: int) -> bool:
	var carver: RefCounted = world_manager.shared_materials["terrain_carver"]
	var pt: Vector3 = path.points[idx]
	var norm: Vector3 = path.normals[idx]
	var binorm: Vector3 = path.binormals[idx]
	var half_width: float = path.road_widths[idx] * 0.5
	var cross_section: Dictionary = carver.compute_cross_section(
		pt, path.tangents[idx], norm, binorm, half_width, path.curvatures[idx], path.segment_types[idx], path.cumulative_distances[idx]
	)
	var vertices: PackedVector3Array = cross_section.vertices
	var pos_l_far: Vector3 = pt - binorm * (half_width + CarverClass.W_SHOULDER + CarverClass.W_FEATURE + CarverClass.W_FAR)
	var center_macro: float = carver.get_macro_elevation(pt.x, pt.z)
	var center_detail: float = carver.get_detail_elevation(pt.x, pt.z)
	var far_height: float = carver.get_macro_elevation(pos_l_far.x, pos_l_far.z) - center_macro + carver.get_detail_elevation(pos_l_far.x, pos_l_far.z) - center_detail
	var expected_far: Vector3 = pos_l_far + norm * far_height
	var far_ok: bool = vertices.size() == 8 and vertices[0].distance_to(expected_far) <= 0.0001
	var edge_ok: bool = vertices.size() == 8 and vertices[3].distance_to(pt - binorm * half_width) <= 0.0001 and vertices[4].distance_to(pt + binorm * half_width) <= 0.0001
	_check(far_ok, "outer terrain height is offset from road center elevation")
	_check(edge_ok, "terrain cross-section edges exactly meet road shoulders")
	return far_ok and edge_ok

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[MACRO_PROFILE_INTEGRATION FAIL] %s" % label)
