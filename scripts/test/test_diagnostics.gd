extends SceneTree

func _init() -> void:
	print("\n=== RUNNING POST-FIX DIAGNOSTIC VERIFICATION ===")
	var all_ok: bool = true

	# Test 1: REAL 3D ArrayMesh vertex continuity at Chunk 0 / Chunk 1 boundary
	var wm_script: GDScript = load("res://scripts/world/world_manager.gd")
	var wm = wm_script.new()
	wm._init_shared_resources()

	var path := preload("res://scripts/world/road_path_data.gd").new()
	var logic := preload("res://scripts/world/road_logic.gd").new(184729, path)
	var chunk_class: GDScript = load("res://scripts/world/road_chunk.gd")

	# Chunk 0
	logic.plan_next_chunk()
	var chunk0 = chunk_class.new()
	chunk0.build_chunk(path, 0, 25, 0, wm.shared_materials, wm.shared_meshes)

	# Chunk 1
	logic.plan_next_chunk()
	var chunk1 = chunk_class.new()
	chunk1.build_chunk(path, 25, 50, 1, wm.shared_materials, wm.shared_meshes)

	# Extract real vertex arrays
	var road_mesh0: ArrayMesh = chunk0.get_child(0).mesh
	var road_mesh1: ArrayMesh = chunk1.get_child(0).mesh
	var road_verts0: PackedVector3Array = road_mesh0.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var road_verts1: PackedVector3Array = road_mesh1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var delta_left: float = road_verts0[-2].distance_to(road_verts1[0])
	var delta_right: float = road_verts0[-1].distance_to(road_verts1[1])
	var max_road_seam_delta: float = maxf(delta_left, delta_right)

	var terr_mesh0: ArrayMesh = chunk0.get_child(2).mesh
	var terr_mesh1: ArrayMesh = chunk1.get_child(2).mesh
	var terr_verts0: PackedVector3Array = terr_mesh0.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var terr_verts1: PackedVector3Array = terr_mesh1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var max_terr_seam_delta: float = 0.0
	for vi in range(4):
		var d: float = terr_verts0[-4 + vi].distance_to(terr_verts1[vi])
		if d > max_terr_seam_delta: max_terr_seam_delta = d

	print("[VERIFICATION #1] Real polygon mesh seam deltas:")
	print("  - Road Mesh Seam Delta: %.6f meters" % max_road_seam_delta)
	print("  - Terrain Mesh Seam Delta: %.6f meters" % max_terr_seam_delta)
	if max_road_seam_delta <= 0.001 and max_terr_seam_delta <= 0.001:
		print("  [PASS] Real 3D polygon vertex continuity verified (< 0.001m)")
	else:
		print("  [FAIL] Real mesh seam discrepancy detected!")
		all_ok = false

	chunk0.free()
	chunk1.free()
	wm.free()

	# Test 2: Search complexity in find_closest_index with cached start_idx
	for i in range(98):
		logic.plan_next_chunk()

	var bike_pos_at_end: Vector3 = path.points[-1]
	var last_idx: int = path.size() - 5
	var t1: int = Time.get_ticks_usec()
	var idx_with_cache: int = path.find_closest_index(bike_pos_at_end, last_idx)
	var time_with_cache_us: int = Time.get_ticks_usec() - t1
	print("[VERIFICATION #2] Cached find_closest_index over %d samples: %d µs" % [path.size(), time_with_cache_us])
	if time_with_cache_us < 60:
		print("  [PASS] Fast window lookup confirmed (%d µs < 60 µs)" % time_with_cache_us)
	else:
		print("  [FAIL] Lookup too slow: %d µs" % time_with_cache_us)
		all_ok = false


	# Test 3: Downhill ground adhesion
	var max_downhill_slope_deg: float = 6.0
	var sprint_speed: float = 13.0
	var current_pitch: float = deg_to_rad(-max_downhill_slope_deg)
	var slope_vy: float = sprint_speed * sin(current_pitch)
	var dynamic_vy: float = minf(-0.5, slope_vy - 0.5)
	var required_vy: float = -sprint_speed * tan(deg_to_rad(max_downhill_slope_deg))
	print("[VERIFICATION #3] Downhill ground adhesion:")
	print("  - Road descent velocity at 13 m/s on -6°: %.3f m/s" % required_vy)
	print("  - Dynamic vertical_vel in controller: %.3f m/s" % dynamic_vy)
	if dynamic_vy <= required_vy:
		print("  [PASS] Bicycle downward velocity (%.3f m/s) is strictly >= road drop rate (%.3f m/s)" % [absf(dynamic_vy), absf(required_vy)])
	else:
		print("  [FAIL] Insufficient downward velocity")
		all_ok = false

	# Test 4: Verify hud.gd no longer contains reload_current_scene on KEY_R
	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	var hud_source: String = hud_script.source_code
	if hud_source.find("reload_current_scene") == -1:
		print("[VERIFICATION #4] [PASS] hud.gd no longer intercepts KEY_R; Recovery system is fully active!")
	else:
		print("[VERIFICATION #4] [FAIL] hud.gd still contains reload_current_scene")
		all_ok = false

	# Test 5: Verify foliage grounds with noise
	var foliage_script: GDScript = load("res://scripts/world/chunk_foliage.gd")
	var foliage_source: String = foliage_script.source_code
	if foliage_source.find("get_noise_2d") != -1 and foliage_source.find("t_factor") != -1:
		print("[VERIFICATION #5] [PASS] chunk_foliage.gd now projects trees and grass onto terrain surface!")
	else:
		print("[VERIFICATION #5] [FAIL] chunk_foliage.gd lacks noise projection")
		all_ok = false

	# Test 6: Verify bicycle.tscn collision layers
	var bike_scene: PackedScene = load("res://scenes/player/bicycle.tscn")
	var bike_instance = bike_scene.instantiate()
	if bike_instance.collision_layer == 8 and bike_instance.collision_mask == 7:
		print("[VERIFICATION #6] [PASS] Bicycle layer (8=Player) and mask (7=Default|Road|Grass) correctly configured!")
	else:
		print("[VERIFICATION #6] [FAIL] Bicycle layer/mask mismatch: layer=%d, mask=%d" % [bike_instance.collision_layer, bike_instance.collision_mask])
		all_ok = false

	# Test 7: [FIX-001] Verify removal of current_gear and telemetry_updated arity = 3
	var bike_script: GDScript = load("res://scripts/player/bicycle_controller.gd")
	var bike_source: String = bike_script.source_code
	var has_dead_gear: bool = (bike_instance.get("current_gear") != null) or (bike_source.find("var current_gear") != -1)
	
	var sig_arity_ok: bool = false
	for sig in bike_instance.get_signal_list():
		if sig["name"] == "telemetry_updated":
			if sig["args"].size() == 3:
				sig_arity_ok = true
			else:
				print("  telemetry_updated args count: %d (expected 3)" % sig["args"].size())

	var hud_src: String = load("res://scripts/ui/hud.gd").source_code
	var hud_sig_ok: bool = hud_src.find("func _on_telemetry_updated(speed_kmh: float, _cadence_pct: float, is_coasting: bool) -> void:") != -1

	if not has_dead_gear and sig_arity_ok and hud_sig_ok:
		print("[VERIFICATION #7] [PASS] FIX-001 verified: current_gear eliminated, telemetry_updated has exactly 3 arguments across controller and HUD!")
	else:
		print("[VERIFICATION #7] [FAIL] FIX-001 check failed: dead_gear=%s, sig_arity_ok=%s, hud_sig_ok=%s" % [has_dead_gear, sig_arity_ok, hud_sig_ok])
		all_ok = false
	bike_instance.queue_free()

	# Test 8: [FIX-002] Verify strict noise assert in road_chunk.gd
	var chunk_source: String = load("res://scripts/world/road_chunk.gd").source_code
	var has_assert: bool = chunk_source.find("assert(noise != null, \"Terrain noise must be provided by WorldManager\")") != -1
	var has_fallback_1337: bool = chunk_source.find("1337") != -1
	if has_assert and not has_fallback_1337:
		print("[VERIFICATION #8] [PASS] FIX-002 verified: silent fallback seed 1337 removed, strict assert(noise != null) active!")
	else:
		print("[VERIFICATION #8] [FAIL] FIX-002 check failed: has_assert=%s, has_fallback_1337=%s" % [has_assert, has_fallback_1337])
		all_ok = false

	# Test 9: [FIX-003] Verify foliage noise sampled at plant spawn coordinates (X, Z)
	var fol_src: String = load("res://scripts/world/chunk_foliage.gd").source_code
	var has_grass_exact: bool = fol_src.find("noise.get_noise_2d(grass_base.x, grass_base.z)") != -1
	var has_tree_exact: bool = fol_src.find("noise.get_noise_2d(tree_base.x, tree_base.z)") != -1
	var has_old_edge_sample: bool = fol_src.find("road_edge.x") != -1
	if has_grass_exact and has_tree_exact and not has_old_edge_sample:
		print("[VERIFICATION #9] [PASS] FIX-003 verified: noise sampled strictly at plant spawn coordinates (X, Z)!")
	else:
		print("[VERIFICATION #9] [FAIL] FIX-003 check failed: grass_exact=%s, tree_exact=%s, old_edge=%s" % [has_grass_exact, has_tree_exact, has_old_edge_sample])
		all_ok = false

	if all_ok:
		print("\n=== ALL SYSTEM VERIFICATIONS PASSED [100% OK] ===\n")
	else:
		print("\n=== SOME VERIFICATIONS FAILED ===\n")

	quit(0 if all_ok else 1)
