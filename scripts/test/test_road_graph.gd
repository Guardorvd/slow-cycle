extends SceneTree

## Slow Cycle — Road Graph Foundation & Kinematics Test Suite (FEAT-014.1)
## Headless verification of pure memory DAG topology, RoadForkNode kinematic context,
## slope-compensated braking model, independent RoadPathData segment operations,
## and zero-mutation isolation across all arrays.

const RoadKinematicModelClass = preload("res://scripts/world/road_kinematic_model.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadGraphClass = preload("res://scripts/world/road_graph.gd")

var total_assertions: int = 0
var passed_assertions: int = 0
var failed_assertions: int = 0

func _init() -> void:
	print("\n==================================================================")
	print("       SLOW CYCLE — ROAD GRAPH & KINEMATICS TEST SUITE            ")
	print("==================================================================\n")

	test_kinematic_model()
	test_road_path_data_extensions()
	test_road_graph_topology()
	test_road_fork_continuity_and_divergence()
	test_benchmarks()

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
# 1. KINEMATIC MODEL & BRAKING MATHEMATICS
# ==============================================================================

func test_kinematic_model() -> void:
	print("[TEST GROUP 1] RoadKinematicModel & Slope-Compensated Braking...")

	# 1. Effective deceleration across regimes on flat ground (slope = 0)
	var a_comfort_flat: float = RoadKinematicModelClass.calculate_effective_deceleration(RoadKinematicModelClass.BrakingRegime.COMFORT, 0.0)
	var a_normal_flat: float = RoadKinematicModelClass.calculate_effective_deceleration(RoadKinematicModelClass.BrakingRegime.NORMAL, 0.0)
	var a_emerg_flat: float = RoadKinematicModelClass.calculate_effective_deceleration(RoadKinematicModelClass.BrakingRegime.EMERGENCY, 0.0)
	assert_almost_equal(a_comfort_flat, 2.2, 0.001, "Comfort deceleration on flat is 2.2 m/s²")
	assert_almost_equal(a_normal_flat, 3.5, 0.001, "Normal deceleration on flat is 3.5 m/s²")
	assert_almost_equal(a_emerg_flat, 5.5, 0.001, "Emergency deceleration on flat is 5.5 m/s²")

	# 2. Downhill slope reduces effective deceleration: theta = -6.0 deg
	var a_normal_downhill: float = RoadKinematicModelClass.calculate_effective_deceleration(RoadKinematicModelClass.BrakingRegime.NORMAL, -6.0)
	var g_sin: float = 9.80665 * sin(deg_to_rad(-6.0)) # ~ -1.025 m/s²
	var exp_downhill_a: float = 3.5 + g_sin # ~ 2.475 m/s²
	assert_almost_equal(a_normal_downhill, exp_downhill_a, 0.01, "Downhill (-6 deg) reduces effective deceleration by ~1.025 m/s²")

	# 3. Invariant: v_entry <= v_target requires ZERO braking distance
	var zero_eval = RoadKinematicModelClass.calculate_braking_distance(7.0, 8.0, -6.0, RoadKinematicModelClass.BrakingRegime.NORMAL)
	assert_true(zero_eval.is_valid, "Evaluation is valid when v_entry <= v_target")
	assert_almost_equal(zero_eval.distance_m, 0.0, 0.0001, "Braking distance is exactly 0.0 when entry speed <= target speed")
	assert_true(zero_eval.status == "ZERO_BRAKING_NEEDED", "Status reports ZERO_BRAKING_NEEDED")

	# 4. Invariant: Steep runaway slope detection without arbitrary clamp masking
	# At theta = -25 deg, g * sin(-25°) ≈ -4.14 m/s². Normal a = 3.5 => a_eff = -0.64 m/s² <= 0.5
	var runaway_eval = RoadKinematicModelClass.calculate_braking_distance(10.0, 5.0, -25.0, RoadKinematicModelClass.BrakingRegime.NORMAL)
	assert_true(not runaway_eval.is_valid, "Runaway steep downhill correctly flagged as invalid")
	assert_true(is_inf(runaway_eval.distance_m), "Braking distance is INF on runaway slope")
	assert_true(runaway_eval.status == "BRAKING_PHYSICALLY_INSUFFICIENT", "Status explicitly reports BRAKING_PHYSICALLY_INSUFFICIENT")

	# 5. Normal braking calculation: from 30 km/h (8.333 m/s) to 15 km/h (4.167 m/s) on flat
	var normal_eval = RoadKinematicModelClass.calculate_braking_distance(8.3333, 4.1667, 0.0, RoadKinematicModelClass.BrakingRegime.NORMAL)
	var exp_react_dist: float = 8.3333 * 0.5 # 4.1667 m
	var exp_ramp_dist: float = (8.3333 * 8.3333 - 4.1667 * 4.1667) / (2.0 * 3.5) # ~ 7.44 m
	var exp_total_dist: float = exp_react_dist + exp_ramp_dist # ~ 11.607 m
	assert_true(normal_eval.is_valid, "Normal braking evaluation is valid")
	assert_almost_equal(normal_eval.distance_m, exp_total_dist, 0.05, "Total braking distance matches analytical formula")

	# 6. Safe curve speed: R = 19m, max_lat_accel = 1.8 m/s² => v_safe = sqrt(1.8 * 19) ≈ 5.848 m/s (~21.05 km/h)
	var v_safe_19m: float = RoadKinematicModelClass.calculate_safe_curve_speed(19.0, 1.8)
	assert_almost_equal(v_safe_19m, 5.848, 0.01, "Safe curve speed for R=19m switchback is ~5.85 m/s")

# ==============================================================================
# 2. ROAD PATH DATA EXTENSIONS (SLICING, APPENDING, CLONING)
# ==============================================================================

func test_road_path_data_extensions() -> void:
	print("\n[TEST GROUP 2] RoadPathData Extensions (Slicing, Appending, Deep Cloning)...")

	var path := RoadPathDataClass.new()
	path.branch_id = 1
	path.fork_node_id = 42

	# Build a synthetic 10-sample path
	for i in range(10):
		var p := Vector3(0, 0, -float(i) * 2.0)
		var t := Vector3.FORWARD
		var n := Vector3.UP
		path.append_sample(p, t, n, -2.0, 0.01, RoadPathDataClass.SegmentType.CRUISE_DOWNHILL, 0, 1.5, 45.0)

	assert_true(path.size() == 10, "Baseline path has 10 samples")

	# 1. Slicing test: slice [3..7]
	var sliced = path.slice_segment(3, 7)
	assert_true(sliced.size() == 5, "Sliced segment has 5 samples")
	assert_almost_equal(sliced.cumulative_distances[0], 0.0, 0.0001, "Sliced segment cumulative distance strictly starts at 0.0")
	assert_almost_equal(sliced.get_total_distance(), 8.0, 0.0001, "Sliced segment total distance is 8.0m (4 steps x 2.0m)")
	assert_true(sliced.branch_id == 1, "Sliced segment preserves branch_id")
	assert_true(sliced.fork_node_id == 42, "Sliced segment preserves fork_node_id")

	# 2. Deep Clone & Mutation Isolation Test across ALL 10 arrays and metadata
	var clone_path = path.clone()
	assert_true(clone_path.size() == path.size(), "Clone has identical size")

	# Mutate EVERY single array and field in clone
	clone_path.points[0] = Vector3(999, 999, 999)
	clone_path.tangents[0] = Vector3.LEFT
	clone_path.normals[0] = Vector3.DOWN
	clone_path.binormals[0] = Vector3.RIGHT
	clone_path.cumulative_distances[0] = 555.5
	clone_path.slopes[0] = 45.0
	clone_path.curvatures[0] = 1.0
	clone_path.segment_types[0] = RoadPathDataClass.SegmentType.AIRBORNE_DROP
	clone_path.surface_contact_states[0] = 2
	clone_path.banking_angles[0] = 20.0
	clone_path.sight_distances[0] = 100.0
	clone_path.branch_id = 99
	clone_path.fork_node_id = 888

	# Verify original remains completely untouched!
	assert_true(path.points[0] == Vector3(0, 0, 0), "Original points[0] unchanged after clone mutation")
	assert_true(path.tangents[0] == Vector3.FORWARD, "Original tangents[0] unchanged after clone mutation")
	assert_true(path.normals[0] == Vector3.UP, "Original normals[0] unchanged after clone mutation")
	assert_almost_equal(path.cumulative_distances[0], 0.0, 0.0001, "Original cumulative_distances[0] unchanged")
	assert_almost_equal(path.slopes[0], -2.0, 0.0001, "Original slopes[0] unchanged")
	assert_almost_equal(path.curvatures[0], 0.01, 0.0001, "Original curvatures[0] unchanged")
	assert_true(path.segment_types[0] == RoadPathDataClass.SegmentType.CRUISE_DOWNHILL, "Original segment_types[0] unchanged")
	assert_true(path.surface_contact_states[0] == 0, "Original surface_contact_states[0] unchanged")
	assert_almost_equal(path.banking_angles[0], 1.5, 0.0001, "Original banking_angles[0] unchanged")
	assert_almost_equal(path.sight_distances[0], 45.0, 0.0001, "Original sight_distances[0] unchanged")
	assert_true(path.branch_id == 1, "Original branch_id unchanged")
	assert_true(path.fork_node_id == 42, "Original fork_node_id unchanged")

	# 3. Append with DROP_DUPLICATE_ENDPOINT policy
	var path_a := RoadPathDataClass.new()
	path_a.append_sample(Vector3(0, 0, 0), Vector3.FORWARD, Vector3.UP, 0, 0, 0)
	path_a.append_sample(Vector3(0, 0, -2), Vector3.FORWARD, Vector3.UP, 0, 0, 0)

	var path_b := RoadPathDataClass.new()
	path_b.append_sample(Vector3(0, 0, -2), Vector3.FORWARD, Vector3.UP, 0, 0, 0) # Duplicate seam point!
	path_b.append_sample(Vector3(0, 0, -4), Vector3.FORWARD, Vector3.UP, 0, 0, 0)

	path_a.append_path_data(path_b, RoadPathDataClass.AppendPolicy.DROP_DUPLICATE_ENDPOINT)
	assert_true(path_a.size() == 3, "Append correctly dropped duplicate seam vertex (size 3, not 4)")
	assert_almost_equal(path_a.points[1].distance_to(path_a.points[2]), 2.0, 0.0001, "Spacing between samples strictly 2.0m, zero 0-distance step")
	assert_almost_equal(path_a.get_total_distance(), 4.0, 0.0001, "Total cumulative distance correctly spans 4.0m")

# ==============================================================================
# 3. ROAD GRAPH TOPOLOGY & DAG VALIDATION
# ==============================================================================

func test_road_graph_topology() -> void:
	print("\n[TEST GROUP 3] RoadGraph Topology, Registries & DAG Invariant...")

	var graph := RoadGraphClass.new()

	# Create a branching Y-graph: Root -> Fork -> Left (Node L) / Right (Node R)
	var n_root = graph.add_node(Vector3(0, 0, 0), Vector3.FORWARD)
	var n_fork = graph.add_fork_node(Vector3(0, 0, -50), Vector3.FORWARD, Vector3.UP, 8.33, -6.0, 19.0, 50.0)
	var n_left = graph.add_node(Vector3(-10, 0, -100), Vector3(-0.3, 0, -0.9).normalized())
	var n_right = graph.add_node(Vector3(10, 0, -100), Vector3(0.3, 0, -0.9).normalized())

	var e_approach = graph.add_edge(n_root.node_id, n_fork.node_id, null, 0)
	var e_left = graph.add_edge(n_fork.node_id, n_left.node_id, null, 1)
	var e_right = graph.add_edge(n_fork.node_id, n_right.node_id, null, 2)

	assert_true(graph.get_all_nodes().size() == 4, "Graph has 4 nodes")
	assert_true(graph.get_all_edges().size() == 3, "Graph has 3 edges")
	assert_true(graph.get_fork_nodes().size() == 1, "Graph has exactly 1 fork node")

	# Traversal assertions
	var fork_out = graph.get_outgoing_edges(n_fork.node_id)
	assert_true(fork_out.size() == 2, "Fork has 2 outgoing edges")
	assert_true(fork_out[0].edge_id == e_left.edge_id and fork_out[1].edge_id == e_right.edge_id, "Fork outgoing edges match Left and Right edges")

	var fork_in = graph.get_incoming_edges(n_fork.node_id)
	assert_true(fork_in.size() == 1, "Fork has 1 incoming edge")
	assert_true(fork_in[0].edge_id == e_approach.edge_id, "Fork incoming edge matches approach edge")

	# DAG verification: valid tree is acyclic
	assert_true(graph.is_valid_dag(), "Valid branching tree passes DAG verification")

	# Cycle detection test: add back-edge n_left -> n_root
	var e_cycle = graph.add_edge(n_left.node_id, n_root.node_id, null, -1)
	assert_true(not graph.is_valid_dag(), "Cycle correctly detected when back-edge is added")

	# Remove cycle edge
	graph.edges.erase(e_cycle.edge_id)
	n_left.outgoing_edge_ids.erase(e_cycle.edge_id)
	n_root.incoming_edge_ids.erase(e_cycle.edge_id)
	assert_true(graph.is_valid_dag(), "Graph returns to valid DAG after removing cycle edge")

# ==============================================================================
# 4. FORK CONTINUITY, DIVERGENCE ZONE & ROADPATHDATA EXPORT
# ==============================================================================

func test_road_fork_continuity_and_divergence() -> void:
	print("\n[TEST GROUP 4] Fork C0/C1 Continuity, Divergence Zone & Branch Conversion...")

	var graph := RoadGraphClass.new()
	var fork_pos := Vector3(0, 10, -100)
	var fork_tang := Vector3.FORWARD
	var fork_norm := Vector3.UP

	var fork = graph.add_fork_node(fork_pos, fork_tang, fork_norm, 9.5, -6.0, 19.0, 50.0)

	# Build outgoing Branch A (Left) and Branch B (Right) paths
	# Invariant: at s=0, both branches MUST start at fork_pos with fork_tang and fork_norm!
	var path_left := RoadPathDataClass.new()
	var path_right := RoadPathDataClass.new()

	var steps: int = 15 # 30 meters at 2.0m step
	for i in range(steps):
		var s: float = float(i) * 2.0
		# Divergence develops along clothoid/cubic transition
		var t_trans: float = clampf(s / RoadGraphClass.DIVERGENCE_MEASUREMENT_DISTANCE, 0.0, 1.0)
		var angle_left_rad: float = deg_to_rad(-12.0 * t_trans)
		var angle_right_rad: float = deg_to_rad(15.0 * t_trans)

		var t_left: Vector3 = fork_tang.rotated(Vector3.UP, angle_left_rad).normalized()
		var t_right: Vector3 = fork_tang.rotated(Vector3.UP, angle_right_rad).normalized()

		var p_l: Vector3 = fork_pos + t_left * s
		var p_r: Vector3 = fork_pos + t_right * s

		path_left.append_sample(p_l, t_left, fork_norm, -6.0, 0.0, RoadPathDataClass.SegmentType.CRUISE_DOWNHILL)
		path_right.append_sample(p_r, t_right, fork_norm, -6.0, 0.0, RoadPathDataClass.SegmentType.CRUISE_DOWNHILL)

	# 1. Verify C0 and C1 at s=0
	assert_almost_equal(path_left.points[0].distance_to(fork_pos), 0.0, 0.000001, "Branch Left point[0] exactly equals fork position (C0)")
	assert_almost_equal(path_right.points[0].distance_to(fork_pos), 0.0, 0.000001, "Branch Right point[0] exactly equals fork position (C0)")
	assert_almost_equal(path_left.points[0].distance_to(path_right.points[0]), 0.0, 0.000001, "Branch Left and Right share exact same vertex at s=0")
	assert_almost_equal(rad_to_deg(acos(clampf(path_left.tangents[0].dot(fork_tang), -1.0, 1.0))), 0.0, 0.0001, "Branch Left point[0] tangent matches fork tangent (C1)")
	assert_almost_equal(rad_to_deg(acos(clampf(path_right.tangents[0].dot(fork_tang), -1.0, 1.0))), 0.0, 0.0001, "Branch Right point[0] tangent matches fork tangent (C1)")

	# 2. Verify Divergence at DIVERGENCE_MEASUREMENT_DISTANCE (15.0m)
	# At sample index 8 (distance 16.0m ~ 15m), measure angular divergence
	var idx_div: int = 8
	var dot_div: float = clampf(path_left.tangents[idx_div].dot(path_right.tangents[idx_div]), -1.0, 1.0)
	var div_angle_deg: float = rad_to_deg(acos(dot_div))
	assert_true(div_angle_deg >= 10.0 and div_angle_deg <= 40.0, "Divergence at 15m downstream is within [10°, 40°] envelope (measured: %.2f°)" % div_angle_deg)

	# 3. Register edges and BranchPreviewContext
	var n_end_l = graph.add_node(path_left.points[-1], path_left.tangents[-1])
	var n_end_r = graph.add_node(path_right.points[-1], path_right.tangents[-1])

	var e_left = graph.add_edge(fork.node_id, n_end_l.node_id, path_left, 1)
	var e_right = graph.add_edge(fork.node_id, n_end_r.node_id, path_right, 2)

	var bp_left = RoadGraphClass.BranchPreviewContext.new(e_left.edge_id, 0, -12.0, 8.33, -6.0, 45.0, {"name": "Scenic Flow"})
	var bp_right = RoadGraphClass.BranchPreviewContext.new(e_right.edge_id, 1, 15.0, 5.85, -6.0, 19.0, {"name": "Switchback Gully"})
	fork.add_branch_preview(bp_left)
	fork.add_branch_preview(bp_right)

	# 4. RoadForkNode querying RoadKinematicModel for required braking distance
	# Branch 0 target speed = 8.33 m/s (approaching at 9.5 m/s)
	var d_brake_0: float = fork.get_required_braking_distance(0, RoadKinematicModelClass.BrakingRegime.NORMAL)
	assert_true(d_brake_0 > 0.0 and d_brake_0 < 30.0, "Braking distance for Branch 0 is positive and reasonable (%.2fm)" % d_brake_0)

	# Branch 1 target speed = 5.85 m/s (approaching at 9.5 m/s => more braking needed)
	var d_brake_1: float = fork.get_required_braking_distance(1, RoadKinematicModelClass.BrakingRegime.NORMAL)
	assert_true(d_brake_1 > d_brake_0, "Braking distance for sharp technical branch is greater than scenic flow branch (%.2fm > %.2fm)" % [d_brake_1, d_brake_0])

	# 5. Node continuity validation on fork
	var cont_report = graph.validate_node_continuity(fork.node_id)
	assert_true(cont_report["is_valid"], "Fork node continuity strictly PASSES with 0 errors")

	# 6. Branch conversion to independent RoadPathData
	var branch_paths = graph.convert_fork_branches_to_path_data(fork.node_id)
	assert_true(branch_paths.size() == 2, "convert_fork_branches_to_path_data returned 2 independent branches")
	var exported_left: RefCounted = branch_paths[0]
	var exported_right: RefCounted = branch_paths[1]
	assert_true(exported_left != path_left, "Exported branch left is an independent deep-copy, not shallow reference")

	# Mutate exported left and verify original in graph is unaffected
	exported_left.points[0] = Vector3(1234, 5678, 9012)
	assert_true(path_left.points[0] == fork_pos, "Modifying exported branch does not mutate RoadGraph internal edge data")

# ==============================================================================
# 5. HIGH-SCALE TOPOLOGY & GEOMETRY BENCHMARKS
# ==============================================================================

func test_benchmarks() -> void:
	print("\n[TEST GROUP 5] High-Performance Micro-Benchmarks...")

	# 1. Topology Benchmark: 10,000 nodes and 10,000 edges DAG creation & traversal
	var graph_bench := RoadGraphClass.new()
	var t_topo_start: int = Time.get_ticks_usec()

	var prev_id: int = -1
	for i in range(10000):
		var n = graph_bench.add_node(Vector3(0, 0, -float(i) * 2.0), Vector3.FORWARD)
		if prev_id != -1:
			graph_bench.add_edge(prev_id, n.node_id, null, 0)
		prev_id = n.node_id

	var is_dag: bool = graph_bench.is_valid_dag()
	var t_topo_end: int = Time.get_ticks_usec()
	var elapsed_topo_ms: float = float(t_topo_end - t_topo_start) / 1000.0

	assert_true(is_dag, "10,000-node linear DAG verified acyclic")
	assert_true(elapsed_topo_ms <= 200.0, "Topology benchmark (10k nodes/edges + DAG check) finished in %.2f ms (limit <= 200ms)" % elapsed_topo_ms)

	# 2. Geometry Conversion Benchmark: deep-copying 32 branches of 100 samples
	var template_path := RoadPathDataClass.new()
	for i in range(100):
		template_path.append_sample(Vector3(0, 0, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP, -5.0, 0.01, RoadPathDataClass.SegmentType.CRUISE_DOWNHILL)

	var t_geom_start: int = Time.get_ticks_usec()
	var cloned_branches: Array = []
	for b in range(32):
		var branch_copy = template_path.clone()
		var sliced = branch_copy.slice_segment(0, 99)
		cloned_branches.append(sliced)

	var t_geom_end: int = Time.get_ticks_usec()
	var elapsed_geom_ms: float = float(t_geom_end - t_geom_start) / 1000.0

	assert_true(cloned_branches.size() == 32, "32 branches cloned and sliced successfully")
	assert_true(elapsed_geom_ms <= 10.0, "Geometry conversion benchmark (32 branches x 100 samples) finished in %.2f ms (limit <= 10ms)" % elapsed_geom_ms)
