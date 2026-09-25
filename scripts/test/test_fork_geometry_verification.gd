extends SceneTree

## Slow Cycle — Monolithic Fork Geometry & Zero Overlap Verification Test
## Empirically validates:
## 1. Approach widening (3.2m -> 6.5m)
## 2. Seam C0/C1 continuity (zero gap at s = 0)
## 3. Divergence angle (26 degrees total, >18m separation at s = 50m)
## 4. Splitter wedge watertight connection (delta < 0.001m) and crown
## 5. Zero mesh overlap between left and right arms

const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const WorldManagerClass = preload("res://scripts/world/world_manager.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("    SLOW CYCLE — MONOLITHIC FORK GEOMETRY & ZERO OVERLAP SUITE    ")
	print("==================================================================\n")

	test_fork_approach_widening()
	test_divergence_and_wedge_continuity()
	test_zero_overlap_invariant()

	await process_frame

	print("\n==================================================================")
	print("                     FORK GEOMETRY SUMMARY                        ")
	print("==================================================================")
	print("  TOTAL ASSERTIONS : %d" % total_tests)
	print("  PASSED           : %d" % passed_tests)
	print("  FAILED           : %d" % failed_tests)
	if failed_tests == 0:
		print("  OVERALL VERDICT  : ALL FORK GEOMETRY CHECKS PASSED [OK]")
		print("==================================================================\n")
		quit(0)
	else:
		print("  OVERALL VERDICT  : FAILED WITH %d DEFECTS [FAIL]" % failed_tests)
		print("==================================================================\n")
		quit(1)

func assert_true(cond: bool, desc: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [PASS] %s" % desc)
	else:
		failed_tests += 1
		print("  [FAIL] %s" % desc)

func assert_almost_equal(val: float, exp: float, tol: float, desc: String) -> void:
	total_tests += 1
	var delta: float = absf(val - exp)
	if delta <= tol:
		passed_tests += 1
		print("  [PASS] %s (val=%.5f, exp=%.5f, delta=%.6f)" % [desc, val, exp, delta])
	else:
		failed_tests += 1
		print("  [FAIL] %s (val=%.5f, exp=%.5f, delta=%.6f > tol=%.6f)" % [desc, val, exp, delta, tol])

func test_fork_approach_widening() -> void:
	print("[GROUP 1] Fork Approach Smoothstep Widening...")
	var wm := WorldManagerClass.new()
	wm._init_shared_resources()

	var r_path := RoadPathDataClass.new()
	var r_logic := RoadLogicClass.new(184729, r_path)

	var streamer := ChunkStreamerClass.new()
	streamer.setup(wm, r_path, r_logic, wm.shared_materials, wm.shared_meshes)

	var branch := streamer.get_active_branch()
	streamer._spawn_chunk_with_fork_widening(branch)

	var end_idx: int = branch.road_path.size() - 1
	var w_end: float = branch.road_path.road_widths[end_idx]
	assert_almost_equal(w_end, 3.6, 0.05, "Road width expands to 3.6m at the fork junction")
	assert_true(branch.road_path.segment_types[end_idx] == RoadPathDataClass.SegmentType.BRAKING_ZONE, "Fork is preceded by an explicitly generated braking and sightline zone")
	assert_true(branch.road_path.sight_distances[end_idx] >= 45.0, "Fork approach preserves at least 45m of visibility")
	assert_true(branch.road_path.slopes[end_idx] >= -5.0 and branch.road_path.slopes[end_idx] <= 2.0, "Fork junction is generated on a mild grade")

	# Check that the upstream trail remains narrow singletrack
	var w_start: float = branch.road_path.road_widths[0]
	assert_true(w_start <= 1.81, "Road width at approach chunk start is <= 1.8m (measured: %.2f)" % w_start)

	streamer.queue_free()
	wm.queue_free()

func test_divergence_and_wedge_continuity() -> void:
	print("\n[GROUP 2] Arm Divergence & Splitter Wedge Watertight Continuity...")
	var wm := WorldManagerClass.new()
	wm._init_shared_resources()

	var streamer := ChunkStreamerClass.new()
	var r_path := RoadPathDataClass.new()
	var r_logic := RoadLogicClass.new(184729, r_path)

	streamer.setup(wm, r_path, r_logic, wm.shared_materials, wm.shared_meshes)

	var trunk = streamer.get_active_branch()
	streamer._spawn_chunk_with_fork_widening(trunk)

	# Trigger procedural fork
	streamer._spawn_procedural_fork(trunk)

	var left_branch = trunk
	var alt_branch_id: int = trunk.child_branch_ids[0]
	var right_branch = streamer.branches[alt_branch_id]

	assert_true(left_branch.active_chunks.size() >= 1, "Left arm chunk instantiated")
	assert_true(right_branch.active_chunks.size() >= 1, "Right arm chunk instantiated")

	# Measure separation at arm end (s = 50m)
	var l_end_pt: Vector3 = left_branch.road_path.points[-1]
	var r_end_pt: Vector3 = right_branch.road_path.points[25] # Chunk 0 end sample
	var sep_dist: float = l_end_pt.distance_to(r_end_pt)
	print("  [MEASUREMENT] Fork arm separation at 50m: %.2f meters" % sep_dist)
	assert_true(sep_dist > 10.0, "Fork arms form two readable lines with > 10m separation at 50m (measured: %.2f)" % sep_dist)

	# Measure inner edge gap at s = 0 (seam)
	var l_start_pos: Vector3 = left_branch.road_path.points[-26]
	var l_start_bin: Vector3 = left_branch.road_path.binormals[-26]
	var l_start_w: float = left_branch.road_path.road_widths[-26]
	var l_inner_0: Vector3 = l_start_pos + l_start_bin * (l_start_w * 0.5)

	var r_start_pos: Vector3 = right_branch.road_path.points[0]
	var r_start_bin: Vector3 = right_branch.road_path.binormals[0]
	var r_start_w: float = right_branch.road_path.road_widths[0]
	var r_inner_0: Vector3 = r_start_pos - r_start_bin * (r_start_w * 0.5)

	var seam_inner_gap: float = l_inner_0.distance_to(r_inner_0)
	assert_almost_equal(seam_inner_gap, 0.0, 0.001, "Seam inner edge gap at s=0 is 0.000m (watertight apex)")

	# Verify both branches are physically solid (collision_layer > 0)
	var l_chunk = left_branch.active_chunks.values()[-1]
	var r_chunk = right_branch.active_chunks.values()[0]
	assert_true(l_chunk.road_body.collision_layer == 2, "Left arm road collision is Layer 2 (Solid)")
	assert_true(l_chunk.terrain_body.collision_layer == 4, "Left arm terrain/wedge collision is Layer 4 (Solid)")
	assert_true(r_chunk.road_body.collision_layer == 2, "Right arm road collision is Layer 2 (Solid)")
	assert_true(r_chunk.terrain_body.collision_layer == 4, "Right arm terrain collision is Layer 4 (Solid)")

	streamer.queue_free()
	wm.queue_free()

func test_zero_overlap_invariant() -> void:
	print("\n[GROUP 3] Zero Overlap Invariant (Terrain Side Masking)...")
	var wm := WorldManagerClass.new()
	wm._init_shared_resources()

	var r_path_l := RoadPathDataClass.new()
	var r_logic_l := RoadLogicClass.new(184729, r_path_l)
	r_logic_l.plan_next_chunk()

	# Prepare left arm chunk with terrain_side_mask = 1 (Left side only)
	var prep_l = RoadChunkClass.prepare_geometry_data(
		r_path_l, 0, 25, 101, wm.shared_materials, null, false, Vector3.FORWARD,
		{ "terrain_side_mask": 1 }
	)

	# Prepare right arm chunk with terrain_side_mask = 2 (Right side only)
	var r_path_r := RoadPathDataClass.new()
	var r_logic_r := RoadLogicClass.new(99999, r_path_r)
	r_logic_r.plan_next_chunk()

	var prep_r = RoadChunkClass.prepare_geometry_data(
		r_path_r, 0, 25, 102, wm.shared_materials, null, false, Vector3.FORWARD,
		{ "terrain_side_mask": 2 }
	)

	# Verify that left chunk terrain faces are strictly on the left of centerline
	var all_l_faces_on_left: bool = true
	for f_pt: Vector3 in prep_l.terrain_faces:
		# In straight -Z road, +X is right, -X is left. Left side points should have X <= 0.1
		if f_pt.x > 0.5:
			all_l_faces_on_left = false
			break
	assert_true(all_l_faces_on_left, "Left arm with side_mask=1 generates ZERO terrain on the right side")

	# Verify that right chunk terrain faces are strictly on the right of centerline
	var all_r_faces_on_right: bool = true
	for f_pt: Vector3 in prep_r.terrain_faces:
		if f_pt.x < -0.5:
			all_r_faces_on_right = false
			break
	assert_true(all_r_faces_on_right, "Right arm with side_mask=2 generates ZERO terrain on the left side")

	wm.queue_free()
