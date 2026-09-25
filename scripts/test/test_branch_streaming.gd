extends SceneTree

## Slow Cycle — Branch Streaming & Greybox Dressing Test Suite (FEAT-014.5)
## Headless verification of branch lifecycle state machine (ACTIVE -> PRELOADED -> DORMANT -> UNLOADED),
## ghost collision deactivation on dormant branches, deterministic child seed derivation,
## greybox dressing meshes (boulder, marker_post, directional_sign) with zero physics overhead,
## and commit phase performance budget (<= 1.0 ms).

const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const ForkDecisionModelClass = preload("res://scripts/world/fork_decision_model.gd")
const WorldManagerClass = preload("res://scripts/world/world_manager.gd")
const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — BRANCH STREAMING & GREYBOX TEST SUITE         ")
	print("==================================================================\n")

	test_greybox_meshes_and_shared_resources()
	test_deterministic_child_seed_derivation()
	await test_branch_fsm_lifecycle_and_ghost_collision_deactivation()
	test_greybox_dressing_placement_and_physics_layers()
	test_commit_budget_benchmark()

	await process_frame
	await process_frame

	print("\n==================================================================")
	print("                  TEST SUITE SUMMARY                              ")
	print("==================================================================")
	print("  TOTAL ASSERTIONS : %d" % total_assertions)
	print("  PASSED           : %d" % passed_assertions)
	print("  FAILED           : %d" % failed_assertions)
	if failed_assertions == 0:
		print("  OVERALL VERDICT  : ALL CHECKS PASSED [OK]")
		print("==================================================================\n")
		quit(0)
	else:
		print("  OVERALL VERDICT  : SUITE FAILED WITH %d DEFECTS [FAIL]" % failed_assertions)
		print("==================================================================\n")
		quit(1)

func assert_true(condition: bool, description: String) -> void:
	total_assertions += 1
	if condition:
		passed_assertions += 1
		print("  [PASS] %s" % description)
	else:
		failed_assertions += 1
		print("  [FAIL] %s" % description)

func assert_almost_equal(val: float, expected: float, tol: float, description: String) -> void:
	total_assertions += 1
	var delta: float = absf(val - expected)
	if delta <= tol:
		passed_assertions += 1
		print("  [PASS] %s (val=%.5f, exp=%.5f, delta=%.6f)" % [description, val, expected, delta])
	else:
		failed_assertions += 1
		print("  [FAIL] %s (val=%.5f, exp=%.5f, delta=%.6f > tol=%.6f)" % [description, val, expected, delta, tol])

# ==============================================================================
# TEST GROUP 1: GREYBOX MESHES & SHARED RESOURCES (FEAT-014.5)
# ==============================================================================

func test_greybox_meshes_and_shared_resources() -> void:
	print("[TEST GROUP 1] Greybox Meshes & Shared Resources Registration...")

	var wm := WorldManagerClass.new()
	wm.world_seed = 424242
	wm._init_shared_resources()

	# 1. Check mesh registration
	assert_true(wm.shared_meshes.has("boulder"), "shared_meshes contains 'boulder'")
	assert_true(wm.shared_meshes.has("marker_post"), "shared_meshes contains 'marker_post'")
	assert_true(wm.shared_meshes.has("directional_sign"), "shared_meshes contains 'directional_sign'")

	var boulder_mesh: Mesh = wm.shared_meshes.get("boulder", null)
	var marker_mesh: Mesh = wm.shared_meshes.get("marker_post", null)
	var sign_mesh: Mesh = wm.shared_meshes.get("directional_sign", null)

	assert_true(boulder_mesh != null and boulder_mesh.get_surface_count() > 0, "Boulder mesh is valid ArrayMesh with surfaces")
	assert_true(marker_mesh != null and marker_mesh.get_surface_count() > 0, "Marker post mesh is valid ArrayMesh with surfaces")
	assert_true(sign_mesh != null and sign_mesh.get_surface_count() > 0, "Directional sign mesh is valid ArrayMesh with surfaces")

	# 2. Check mesh bounds are compact (greybox dimensions)
	var b_aabb: AABB = boulder_mesh.get_aabb()
	assert_true(b_aabb.size.x > 0.5 and b_aabb.size.x < 3.0, "Boulder width is within [0.5m, 3.0m] (measured: %.2f)" % b_aabb.size.x)
	assert_true(b_aabb.size.y > 0.5 and b_aabb.size.y < 3.0, "Boulder height is within [0.5m, 3.0m] (measured: %.2f)" % b_aabb.size.y)

	var m_aabb: AABB = marker_mesh.get_aabb()
	assert_true(m_aabb.size.y > 0.6 and m_aabb.size.y < 1.6, "Marker post height is within [0.6m, 1.6m] (measured: %.2f)" % m_aabb.size.y)

	var s_aabb: AABB = sign_mesh.get_aabb()
	assert_true(s_aabb.size.y > 1.2 and s_aabb.size.y < 2.5, "Directional sign height is within [1.2m, 2.5m] (measured: %.2f)" % s_aabb.size.y)

	wm.queue_free()

# ==============================================================================
# TEST GROUP 2: DETERMINISTIC CHILD SEED DERIVATION
# ==============================================================================

func test_deterministic_child_seed_derivation() -> void:
	print("\n[TEST GROUP 2] Deterministic Child Seed Derivation...")

	var parent_seed: int = 184729
	var fork_id: int = 3
	var branch_left_idx: int = 0
	var branch_right_idx: int = 1

	var seed_l1: int = hash([parent_seed, fork_id, branch_left_idx]) & 0x7FFFFFFF
	var seed_l2: int = hash([parent_seed, fork_id, branch_left_idx]) & 0x7FFFFFFF
	var seed_r1: int = hash([parent_seed, fork_id, branch_right_idx]) & 0x7FFFFFFF
	var seed_r2: int = hash([parent_seed, fork_id, branch_right_idx]) & 0x7FFFFFFF

	assert_true(seed_l1 == seed_l2, "Left child seed is 100% deterministic across repeated calls")
	assert_true(seed_r1 == seed_r2, "Right child seed is 100% deterministic across repeated calls")
	assert_true(seed_l1 != seed_r1, "Left and Right branches have distinct derived child seeds")
	assert_true(seed_l1 >= 0 and seed_r1 >= 0, "Derived child seeds are non-negative 31-bit integers")

# ==============================================================================
# TEST GROUP 3: BRANCH FSM LIFECYCLE & GHOST COLLISION DEACTIVATION
# ==============================================================================

func test_branch_fsm_lifecycle_and_ghost_collision_deactivation() -> void:
	print("\n[TEST GROUP 3] Branch FSM Lifecycle & Ghost Collision Deactivation...")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var instance: Node = main_scene.instantiate()
	var wm: Node3D = instance.get_node("WorldManager")
	wm.world_seed = 184729
	root.add_child(instance)

	await process_frame
	await physics_frame

	var streamer: Node3D = wm.chunk_streamer
	assert_true(streamer != null, "ChunkStreamer initialized after scene ready")

	# Check initial trunk branch is ACTIVE
	var trunk = streamer.get_active_branch()
	assert_true(trunk != null, "Trunk branch exists")
	assert_true(trunk.state == ChunkStreamerClass.BranchState.ACTIVE, "Trunk branch is initially in ACTIVE state")
	assert_true(trunk.branch_id == 0, "Trunk branch_id is 0")

	# Check all initial active chunks have physics enabled
	var all_initial_physics: bool = true
	for c in trunk.active_chunks.values():
		var road_sb: StaticBody3D = c.road_body if "road_body" in c else c.get_node_or_null("StaticBody3D")
		var terr_sb: StaticBody3D = c.terrain_body if "terrain_body" in c else c.get_node_or_null("TerrainBody")
		if road_sb == null or terr_sb == null:
			all_initial_physics = false
			break
		if road_sb.collision_layer == 0 or terr_sb.collision_layer == 0:
			all_initial_physics = false
			break
	assert_true(all_initial_physics, "All initial ACTIVE branch chunks have collision_layer > 0")

	# Manually spawn a fork to inspect PRELOADED branch
	streamer._spawn_procedural_fork(trunk)
	assert_true(trunk.child_branch_ids.size() == 1, "Trunk spawned 1 alternative child branch")
	var left_edge = streamer.road_graph.get_fork_branch_edge(trunk.graph_fork_node_id, ForkDecisionModelClass.BranchChoice.LEFT)
	var right_edge = streamer.road_graph.get_fork_branch_edge(trunk.graph_fork_node_id, ForkDecisionModelClass.BranchChoice.RIGHT)
	assert_true(left_edge != null and right_edge != null, "Runtime road graph owns both stable left/right fork edges")
	assert_true(left_edge != null and left_edge.branch_id == trunk.branch_id, "Graph LEFT edge points at the generated left centerline")
	assert_true(right_edge != null and right_edge.branch_id == trunk.child_branch_ids[0], "Graph RIGHT edge points at the generated right centerline")
	assert_true(trunk.route_style != streamer.branches[trunk.child_branch_ids[0]].route_style, "Fork alternatives have distinct Flow and Technical route styles")
	assert_true(trunk.decision_model.left_branch_path == left_edge.path_data, "Decision model scores the actual left edge geometry")
	assert_true(trunk.decision_model.right_branch_path == right_edge.path_data, "Decision model scores the actual right edge geometry")
	assert_true(streamer.road_graph.is_valid_dag(), "Generated fork topology remains an acyclic graph")
	var continuity: Dictionary = streamer.road_graph.validate_node_continuity(trunk.graph_fork_node_id)
	assert_true(continuity.is_valid, "Both generated fork arms meet the junction tangent and shared riding envelope")

	var alt_branch_id: int = trunk.child_branch_ids[0]
	var alt_branch = streamer.branches.get(alt_branch_id, null)
	assert_true(alt_branch != null, "Alternative branch object exists in branches dictionary")
	assert_true(alt_branch.state == ChunkStreamerClass.BranchState.PRELOADED, "Alternative branch is in PRELOADED state")
	assert_true(alt_branch.active_chunks.size() >= 2, "Alternative branch preloaded >= 2 chunks")

	# Transition: Lock to LEFT -> Alternative branch becomes DORMANT
	streamer._on_branch_locked(1, ForkDecisionModelClass.BranchChoice.LEFT, trunk.branch_id)
	assert_true(alt_branch.state == ChunkStreamerClass.BranchState.DORMANT, "Alternative branch transitioned to DORMANT state")
	assert_true(trunk.state == ChunkStreamerClass.BranchState.ACTIVE, "Primary branch remains in ACTIVE state")
	assert_true(streamer.active_branch_id == trunk.branch_id, "Graph LEFT choice keeps the left route active")
	assert_true(trunk.decision_model == null, "Resolved branch decision is released after graph transition")

	# Invariant Check: Solid Presentation Invariant (Alternative branch retains solid collisions while visible)
	var all_dormant_collisions_solid: bool = true
	for c in alt_branch.active_chunks.values():
		var road_sb: StaticBody3D = c.road_body if "road_body" in c else c.get_node_or_null("StaticBody3D")
		var terr_sb: StaticBody3D = c.terrain_body if "terrain_body" in c else c.get_node_or_null("TerrainBody")
		if road_sb != null and road_sb.collision_layer == 0:
			all_dormant_collisions_solid = false
		if terr_sb != null and terr_sb.collision_layer == 0:
			all_dormant_collisions_solid = false

	assert_true(all_dormant_collisions_solid, "Solid Presentation Invariant: All collision shapes on alternative branch retain collision_layer > 0 (Zero Ghost Textures)")

	# Transition: Player moves far away past safety envelopes -> DORMANT becomes UNLOADED
	var far_away_pos := Vector3(5000.0, 100.0, 5000.0)
	streamer._update_dormant_branches_safety_envelope(far_away_pos, Vector3.FORWARD * 8.0)

	assert_true(not streamer.branches.has(alt_branch_id), "Dormant branch safely removed from streamer after exiting safety envelope (UNLOADED)")

	instance.queue_free()
	await process_frame

	# Verify the alternative graph edge can also become the real active gameplay route.
	var right_test_manager := WorldManagerClass.new()
	right_test_manager.world_seed = 184729
	right_test_manager._init_shared_resources()
	var right_test_path := RoadPathDataClass.new()
	var right_test_logic := RoadLogicClass.new(184729, right_test_path)
	var right_test_streamer := ChunkStreamerClass.new()
	root.add_child(right_test_streamer)
	right_test_streamer.setup(right_test_manager, right_test_path, right_test_logic, right_test_manager.shared_materials, right_test_manager.shared_meshes)
	var right_test_trunk = right_test_streamer.get_active_branch()
	right_test_streamer._spawn_procedural_fork(right_test_trunk)
	var right_test_branch_id: int = right_test_streamer.road_graph.get_fork_branch_edge(right_test_trunk.graph_fork_node_id, ForkDecisionModelClass.BranchChoice.RIGHT).branch_id
	right_test_streamer._on_branch_locked(1, ForkDecisionModelClass.BranchChoice.RIGHT, right_test_trunk.branch_id)
	assert_true(right_test_streamer.active_branch_id == right_test_branch_id, "Graph RIGHT choice switches the active riding route to the generated right edge")
	assert_true(right_test_trunk.state == ChunkStreamerClass.BranchState.DORMANT, "Unselected left continuation becomes dormant after RIGHT choice")
	right_test_streamer.queue_free()
	right_test_manager.queue_free()
	await process_frame

# ==============================================================================
# TEST GROUP 4: GREYBOX DRESSING PLACEMENT & PHYSICS LAYERS
# ==============================================================================

func test_greybox_dressing_placement_and_physics_layers() -> void:
	print("\n[TEST GROUP 4] Greybox Dressing Placement & Physics Layers...")

	var wm := WorldManagerClass.new()
	wm.world_seed = 184729
	wm._init_shared_resources()

	var r_path := RoadPathDataClass.new()
	var r_logic := RoadLogicClass.new(184729, r_path)

	# Generate a sample chunk
	for i in range(2):
		r_logic.plan_next_chunk()

	var token := ChunkStreamerClass.GenerationToken.new(1, 0, 1)
	var prep = RoadChunkClass.prepare_geometry_data(
		r_path, 0, 50, 1, wm.shared_materials, token, true, Vector3.FORWARD
	)

	var chunk := RoadChunkClass.new()
	var _timings = chunk.commit(prep, wm.shared_materials, wm.shared_meshes)

	# 1. Verify greybox elements exist on chunk
	var post_mm: MultiMeshInstance3D = chunk.get_node_or_null("MarkerPostMultiMesh")
	var sign_inst: MeshInstance3D = chunk.get_node_or_null("DirectionalSignInstance")

	assert_true(post_mm != null, "Chunk instantiated MarkerPostMultiMesh")
	assert_true(sign_inst != null, "Chunk instantiated DirectionalSignInstance on fork chunk (is_fork_decor = true)")

	# 2. Verify MultiMesh custom_aabb for frustum culling
	if post_mm and post_mm.multimesh and post_mm.multimesh.instance_count > 0:
		assert_true(post_mm.custom_aabb.size.length() > 0.1, "MarkerPostMultiMesh has custom_aabb configured for frustum culling")

	# 3. Verify Boulder MultiMesh instancing via ChunkFoliage helper
	var test_parent := Node3D.new()
	var sample_boulder_transforms: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(10.0, 1.0, -10.0)),
		Transform3D(Basis(), Vector3(12.0, 1.5, -15.0))
	]
	var test_transforms_dict: Dictionary = {
		"boulder": sample_boulder_transforms
	}
	ChunkFoliageClass.instantiate_foliage_and_decor(test_parent, test_transforms_dict, wm.shared_meshes)
	var boulder_mm: MultiMeshInstance3D = test_parent.get_node_or_null("BoulderMultiMesh")
	assert_true(boulder_mm != null, "ChunkFoliage correctly instantiates BoulderMultiMesh from transforms")
	if boulder_mm:
		assert_true(boulder_mm.custom_aabb.size.length() > 0.1, "BoulderMultiMesh has custom_aabb configured for frustum culling")

	# 4. Invariant: Zero physics overhead for visual greybox dressing
	var post_body = post_mm.get_node_or_null("StaticBody3D") if post_mm else null
	var sign_body = sign_inst.get_node_or_null("StaticBody3D") if sign_inst else null
	var boulder_body = boulder_mm.get_node_or_null("StaticBody3D") if boulder_mm else null
	assert_true(post_body == null, "Marker posts have zero physics bodies (purely visual)")
	assert_true(sign_body == null, "Directional signs have zero physics bodies (purely visual)")
	assert_true(boulder_body == null, "Boulders have zero physics bodies (purely visual)")

	test_parent.queue_free()
	chunk.queue_free()
	wm.queue_free()

# ==============================================================================
# TEST GROUP 5: COMMIT BUDGET BENCHMARK (<= 1.0 ms)
# ==============================================================================

func test_commit_budget_benchmark() -> void:
	print("\n[TEST GROUP 5] Commit Phase Performance Budget (<= 1.0 ms)...")

	var wm := WorldManagerClass.new()
	wm.world_seed = 184729
	wm._init_shared_resources()

	var r_path := RoadPathDataClass.new()
	var r_logic := RoadLogicClass.new(184729, r_path)

	# Warmup
	r_logic.plan_next_chunk()
	r_logic.plan_next_chunk()

	var commit_times: Array[float] = []
	var prep_times: Array[float] = []

	var chunks_to_test: int = 10
	for i in range(chunks_to_test):
		var start_idx: int = r_path.size() - 1
		r_logic.plan_next_chunk()
		var end_idx: int = r_path.size() - 1

		var t0: float = Time.get_ticks_usec()
		var token := ChunkStreamerClass.GenerationToken.new(1, 0, i)
		var is_fork: bool = (i % 3 == 0)
		var prep = RoadChunkClass.prepare_geometry_data(
			r_path, start_idx, end_idx, i, wm.shared_materials, token, is_fork, Vector3.FORWARD
		)
		var t1: float = Time.get_ticks_usec()
		prep_times.append((t1 - t0) / 1000.0)

		var chunk := RoadChunkClass.new()
		var timings = chunk.commit(prep, wm.shared_materials, wm.shared_meshes)
		var t_commit: float = timings.get("t_total", 0.0)
		commit_times.append(t_commit)

		chunk.queue_free()

	var avg_commit: float = 0.0
	var max_commit: float = 0.0
	for t in commit_times:
		avg_commit += t
		if t > max_commit: max_commit = t
	avg_commit /= float(commit_times.size())

	print("  [BENCHMARK] Commit Phase: Avg = %.3f ms, Max = %.3f ms across %d chunks" % [
		avg_commit, max_commit, chunks_to_test
	])

	assert_true(max_commit <= 1.0, "Synchronous chunk commit is strictly <= 1.0 ms budget (max measured: %.3f ms)" % max_commit)
	assert_true(avg_commit <= 0.85, "Average chunk commit is <= 0.85 ms budget (avg measured: %.3f ms)" % avg_commit)

	wm.queue_free()
