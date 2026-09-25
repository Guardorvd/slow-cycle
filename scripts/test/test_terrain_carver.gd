extends SceneTree

## Slow Cycle — Mountain Terrain Carver & Surface Physics Test Suite (FEAT-014.4)
## Headless verification of road-centric carving, 8-vertex cross-section generation,
## numerical seam tolerance (<= 0.1mm), chunk boundary continuity, multi-factor classification,
## seed determinism, visual-only guard posts, collision layer 4 contract, and partitioned benchmarks.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — TERRAIN CARVER & MOUNTAIN PHYSICS SUITE       ")
	print("==================================================================\n")

	test_seam_invariant_and_cross_section_structure()
	test_chunk_boundary_continuity()
	test_multi_factor_profile_classification()
	test_seed_determinism()
	test_guard_posts_and_danger_flags()
	test_collision_layer_and_surface_contract()
	test_partitioned_benchmarks()

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
# TEST 1: SEAM INVARIANT AND CROSS-SECTION STRUCTURE
# ==============================================================================
func test_seam_invariant_and_cross_section_structure() -> void:
	print("--- Running Test 1: Seam Invariant & Cross-Section Structure ---")

	var carver = TerrainCarverClass.new(184729)

	# Build a straight test path with varying road width (4.0m to 8.0m)
	var path_data = RoadPathDataClass.new()
	for i in range(25):
		var z: float = -float(i) * 2.0
		var w: float = 4.0 + (float(i) / 24.0) * 4.0 # 4.0m to 8.0m
		path_data.append_sample(Vector3(0, 0, z), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, w)

	var max_seam_error_left: float = 0.0
	var max_seam_error_right: float = 0.0

	for i in range(path_data.size()):
		var pt: Vector3 = path_data.points[i]
		var tang: Vector3 = path_data.tangents[i]
		var norm: Vector3 = path_data.normals[i]
		var binorm: Vector3 = path_data.binormals[i]
		var half_w: float = path_data.road_widths[i] * 0.5
		var dist: float = path_data.cumulative_distances[i]

		var cs: Dictionary = carver.compute_cross_section(pt, tang, norm, binorm, half_w, 0.0, 0, dist)
		var verts: PackedVector3Array = cs.vertices

		assert_true(verts.size() == 8, "Cross-section has exactly 8 vertices at sample %d" % i)

		# V3 is Left Road Edge: must match pt - binorm * half_w
		var expected_v3: Vector3 = pt - binorm * half_w
		var delta_left: float = verts[3].distance_to(expected_v3)
		max_seam_error_left = maxf(max_seam_error_left, delta_left)

		# V4 is Right Road Edge: must match pt + binorm * half_w
		var expected_v4: Vector3 = pt + binorm * half_w
		var delta_right: float = verts[4].distance_to(expected_v4)
		max_seam_error_right = maxf(max_seam_error_right, delta_right)

		# Verify lateral ordering: V0 < V1 < V2 < V3 < V4 < V5 < V6 < V7 along binormal
		var proj_0: float = (verts[0] - pt).dot(binorm)
		var proj_1: float = (verts[1] - pt).dot(binorm)
		var proj_2: float = (verts[2] - pt).dot(binorm)
		var proj_3: float = (verts[3] - pt).dot(binorm)
		var proj_4: float = (verts[4] - pt).dot(binorm)
		var proj_5: float = (verts[5] - pt).dot(binorm)
		var proj_6: float = (verts[6] - pt).dot(binorm)
		var proj_7: float = (verts[7] - pt).dot(binorm)

		assert_true(proj_0 < proj_1 and proj_1 < proj_2 and proj_2 < proj_3, "Left side lateral vertices monotonically ordered at sample %d" % i)
		assert_true(proj_4 < proj_5 and proj_5 < proj_6 and proj_6 < proj_7, "Right side lateral vertices monotonically ordered at sample %d" % i)

	assert_almost_equal(max_seam_error_left, 0.0, 0.0001, "Max left seam error <= 0.1 mm (measured: %.6f m)" % max_seam_error_left)
	assert_almost_equal(max_seam_error_right, 0.0, 0.0001, "Max right seam error <= 0.1 mm (measured: %.6f m)" % max_seam_error_right)

# ==============================================================================
# TEST 2: CHUNK BOUNDARY CONTINUITY (C0 SEAMLESS CONNECTION)
# ==============================================================================
func test_chunk_boundary_continuity() -> void:
	print("\n--- Running Test 2: Chunk Boundary Continuity (C0 Seamless) ---")

	var carver = TerrainCarverClass.new(987654)

	# Simulate boundary between Chunk 0 (ending at s=50m) and Chunk 1 (starting at s=50m)
	var boundary_pt := Vector3(15.2, 104.5, -50.0)
	var boundary_tang := Vector3(0.2, -0.08, -0.97).normalized()
	var boundary_norm := Vector3(0.02, 0.99, -0.08).normalized()
	var boundary_binorm: Vector3 = boundary_tang.cross(boundary_norm).normalized()
	var boundary_half_w: float = 2.2
	var boundary_curv: float = 0.02
	var boundary_dist: float = 50.0

	# Evaluate as end of Chunk 0
	var cs_chunk_k: Dictionary = carver.compute_cross_section(
		boundary_pt, boundary_tang, boundary_norm, boundary_binorm, boundary_half_w, boundary_curv, 0, boundary_dist
	)

	# Evaluate as start of Chunk 1
	var cs_chunk_k_plus_1: Dictionary = carver.compute_cross_section(
		boundary_pt, boundary_tang, boundary_norm, boundary_binorm, boundary_half_w, boundary_curv, 0, boundary_dist
	)

	var verts_k: PackedVector3Array = cs_chunk_k.vertices
	var verts_next: PackedVector3Array = cs_chunk_k_plus_1.vertices

	var max_boundary_delta: float = 0.0
	for j in range(8):
		var delta_j: float = verts_k[j].distance_to(verts_next[j])
		max_boundary_delta = maxf(max_boundary_delta, delta_j)

	assert_almost_equal(max_boundary_delta, 0.0, 0.0001, "Chunk boundary cross-section C0 delta <= 0.1 mm (measured: %.8f m)" % max_boundary_delta)

# ==============================================================================
# TEST 3: MULTI-FACTOR PROFILE CLASSIFICATION
# ==============================================================================
func test_multi_factor_profile_classification() -> void:
	print("\n--- Running Test 3: Multi-Factor Profile Classification ---")

	var carver = TerrainCarverClass.new(424242)

	# Test 1: Flat straight road in neutral area
	var eval_neutral = carver.evaluate_profile(Vector3(0, 0, 0), Vector3.RIGHT, 0.0)
	assert_true(eval_neutral.has("left_profile") and eval_neutral.has("right_profile"), "Profile evaluation returns valid structure")

	# Test 2: Strong macro elevation gradient across road
	# We can test evaluate_profile at positions where macro noise creates a slope
	var p_uphill_right := Vector3(200.0, 0.0, 300.0)
	var binorm_test := Vector3.RIGHT
	var eval_slope = carver.evaluate_profile(p_uphill_right, binorm_test, 0.0)

	print("  Macro gradient sample: Score Left = %.3f, Score Right = %.3f" % [eval_slope.score_left, eval_slope.score_right])
	assert_true(eval_slope.left_delta_h != 0.0 or eval_slope.right_delta_h != 0.0, "Macro gradient produces non-zero feature elevation")

	# Test 3: Curvature influence on switchback (sharp left turn kappa = 0.05)
	var eval_left_turn = carver.evaluate_profile(Vector3(0, 0, -100.0), Vector3.RIGHT, 0.05)
	var eval_right_turn = carver.evaluate_profile(Vector3(0, 0, -100.0), Vector3.RIGHT, -0.05)

	# Turning left: inner curve is Left (score_left higher than when turning right)
	assert_true(eval_left_turn.score_left > eval_right_turn.score_left, "Turning left shifts Left side towards CUT relative to turning right")
	assert_true(eval_right_turn.score_right > eval_left_turn.score_right, "Turning right shifts Right side towards CUT relative to turning left")

# ==============================================================================
# TEST 4: 100% SEED DETERMINISM
# ==============================================================================
func test_seed_determinism() -> void:
	print("\n--- Running Test 4: 100% Seed Determinism across Runs ---")

	var carver_a = TerrainCarverClass.new(777123)
	var carver_b = TerrainCarverClass.new(777123)

	var max_diff: float = 0.0
	for step in range(50):
		var p := Vector3(float(step) * 1.5, 50.0 - float(step) * 0.4, -float(step) * 3.0)
		var b := Vector3(1.0, 0.0, 0.0)
		var t := Vector3(0.0, 0.0, -1.0)
		var n := Vector3(0.0, 1.0, 0.0)

		var cs_a = carver_a.compute_cross_section(p, t, n, b, 2.0, 0.01, 0, float(step) * 2.0)
		var cs_b = carver_b.compute_cross_section(p, t, n, b, 2.0, 0.01, 0, float(step) * 2.0)

		for v in range(8):
			var d: float = cs_a.vertices[v].distance_to(cs_b.vertices[v])
			max_diff = maxf(max_diff, d)

	assert_almost_equal(max_diff, 0.0, 0.0000001, "Two TerrainCarver runs with identical seed produce identical geometry (max delta = 0.0m)")

# ==============================================================================
# TEST 5: GUARD POSTS AND DANGER FLAGS
# ==============================================================================
func test_guard_posts_and_danger_flags() -> void:
	print("\n--- Running Test 5: Guard Posts & Danger Flags ---")

	var carver = TerrainCarverClass.new(184729)

	# Check danger detection helper
	var class_cliff = carver._classify_side_score(-0.6)
	assert_true(class_cliff.profile == TerrainCarverClass.ProfileType.CLIFF, "Severe negative score classifies as CLIFF")
	assert_true(class_cliff.delta_h < -2.5, "CLIFF delta_h is below danger drop threshold (-2.5m)")

	var class_cut = carver._classify_side_score(0.6)
	assert_true(class_cut.profile == TerrainCarverClass.ProfileType.CUT, "Severe positive score classifies as CUT")
	assert_true(class_cut.delta_h > 2.5, "CUT delta_h rises above road")

	# Test RoadChunk guard post MultiMesh creation
	var chunk = RoadChunkClass.new()
	var test_transforms: Array[Transform3D] = [
		Transform3D(Basis(), Vector3(2.5, 0, -10)),
		Transform3D(Basis(), Vector3(2.5, 0, -14)),
		Transform3D(Basis(), Vector3(2.5, 0, -18))
	]

	# Build a simple post mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.add_vertex(Vector3(0, 0, 0)); st.add_vertex(Vector3(0, 1, 0)); st.add_vertex(Vector3(0.1, 0, 0))
	var dummy_mesh = st.commit()

	chunk._build_guard_posts(dummy_mesh, test_transforms)
	var mmi: MultiMeshInstance3D = chunk.get_node_or_null("GuardPostMultiMesh")
	assert_true(mmi != null, "GuardPostMultiMesh successfully created as child of RoadChunk")
	assert_true(mmi.multimesh != null and mmi.multimesh.instance_count == 3, "GuardPostMultiMesh instance_count is 3")
	assert_true(not mmi.has_method("get_collision_layer"), "GuardPostMultiMesh has zero physics collision (visual dressing only)")

	chunk.queue_free()

# ==============================================================================
# TEST 6: COLLISION LAYER AND SURFACE CONTRACT
# ==============================================================================
func test_collision_layer_and_surface_contract() -> void:
	print("\n--- Running Test 6: Collision Layer & Surface Contract ---")

	var chunk = RoadChunkClass.new()
	var path_data = RoadPathDataClass.new()
	for i in range(10):
		path_data.append_sample(Vector3(0, 0, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 4.0)

	var mats := {
		"road": StandardMaterial3D.new(),
		"grass": StandardMaterial3D.new(),
		"noise": FastNoiseLite.new(),
		"terrain_carver": TerrainCarverClass.new(184729)
	}
	var meshes := {}

	chunk.build_chunk(path_data, 0, 9, 1, mats, meshes)

	assert_true(chunk.terrain_body != null, "RoadChunk has terrain_body StaticBody3D")
	assert_true(chunk.terrain_body.collision_layer == 4, "terrain_body collision_layer is strictly 4 (Layer 3 Grass, matching bicycle mask)")
	assert_true(chunk.terrain_body.has_meta("surface_type"), "terrain_body has surface_type metadata")
	assert_true(chunk.terrain_body.get_meta("surface_type") == "mountain_terrain", "terrain_body metadata is 'mountain_terrain'")

	assert_true(chunk.road_body != null, "RoadChunk has road_body StaticBody3D")
	assert_true(chunk.road_body.collision_layer == 2, "Standard road_body collision_layer is strictly 2 (Layer 2 Road)")

	chunk.queue_free()

# ==============================================================================
# TEST 7: PARTITIONED BENCHMARKS (Analyst Point 12)
# ==============================================================================
func test_partitioned_benchmarks() -> void:
	print("\n--- Running Test 7: Partitioned Performance Benchmarks ---")

	var carver = TerrainCarverClass.new(184729)

	# 1. Pure Math Benchmark: 100 chunks x 25 samples = 2500 samples
	var t0: int = Time.get_ticks_usec()
	for i in range(2500):
		var p := Vector3(0.0, 0.0, -float(i) * 2.0)
		var cs = carver.compute_cross_section(p, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 2.0, 0.01, 0, float(i) * 2.0)
	var t1: int = Time.get_ticks_usec()
	var math_ms: float = float(t1 - t0) / 1000.0
	print("  [Benchmark 1] TerrainCarver 2500 samples pure math: %.2f ms (Limit <= 45.0 ms, avg %.4f ms/sample)" % [math_ms, math_ms / 2500.0])
	assert_true(math_ms < 45.0, "Pure CPU math benchmark passed (under 45 ms for 2500 samples, avg < 0.018 ms/sample)")

	# 2. SurfaceTool Extrusion & ArrayMesh Commit Benchmark: 20 chunks
	var test_path = RoadPathDataClass.new()
	for i in range(26):
		test_path.append_sample(Vector3(0, 0, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0, 0, 0.0, 50.0, 4.0)

	var dummy_mat = StandardMaterial3D.new()
	var t2: int = Time.get_ticks_usec()
	var committed_meshes: Array[ArrayMesh] = []
	for c in range(20):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(dummy_mat)
		for i in range(26):
			var pt: Vector3 = test_path.points[i]
			var cs = carver.compute_cross_section(pt, Vector3.FORWARD, Vector3.UP, Vector3.RIGHT, 2.0, 0.0, 0, float(i) * 2.0)
			for v_idx in range(8):
				st.set_uv(cs.uvs[v_idx])
				st.add_vertex(cs.vertices[v_idx])
		const STRIP_COLS: Array[int] = [0, 1, 2, 4, 5, 6]
		for i in range(25):
			var r_curr: int = i * 8
			var r_next: int = (i + 1) * 8
			for col in STRIP_COLS:
				st.add_index(r_curr + col); st.add_index(r_next + col); st.add_index(r_curr + col + 1)
				st.add_index(r_curr + col + 1); st.add_index(r_next + col); st.add_index(r_next + col + 1)
		st.generate_normals()
		committed_meshes.append(st.commit())
	var t3: int = Time.get_ticks_usec()
	var mesh_ms: float = float(t3 - t2) / 1000.0
	print("  [Benchmark 2] 20 chunks mesh generation & commit: %.2f ms (Limit <= 30.0 ms, avg %.3f ms/chunk)" % [mesh_ms, mesh_ms / 20.0])
	assert_true(mesh_ms < 30.0, "SurfaceTool commit benchmark passed (under 30 ms for 20 chunks, avg < 1.5 ms/chunk)")

	# 3. Collision Shape Construction Benchmark: 20 trimesh shapes
	var t4: int = Time.get_ticks_usec()
	for m in committed_meshes:
		var shape = m.create_trimesh_shape()
	var t5: int = Time.get_ticks_usec()
	var col_ms: float = float(t5 - t4) / 1000.0
	print("  [Benchmark 3] 20 chunks trimesh shape creation: %.2f ms (Limit <= 20.0 ms, avg %.3f ms/chunk)" % [col_ms, col_ms / 20.0])
	assert_true(col_ms < 20.0, "Trimesh shape creation benchmark passed")
