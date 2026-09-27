extends SceneTree

## Focused regression checks for REVIEW-FIX-01 production defects.

const RoadGraphClass = preload("res://scripts/world/road_graph.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const ChunkStreamerClass = preload("res://scripts/world/chunk_streamer.gd")
const ChunkFoliageClass = preload("res://scripts/world/chunk_foliage.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const ValidatorClass = preload("res://scripts/world/road_validity_validator.gd")
const BicycleControllerClass = preload("res://scripts/player/bicycle_controller.gd")

var checks: int = 0
var failures: int = 0

func _init() -> void:
	test_graph_history_pruning()
	test_foliage_order_independence()
	test_validator_input_and_sightline_contract()
	test_generated_airborne_survives_validation()
	test_surface_weights_after_hitch()
	print("REVIEW_FIX_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("REVIEW_FIX_FAIL " + message)

func test_graph_history_pruning() -> void:
	var graph = RoadGraphClass.new()
	var previous = graph.add_node(Vector3.ZERO, Vector3.FORWARD)
	for i in range(1, 20):
		var node = graph.add_node(Vector3(0.0, 0.0, -float(i) * 2.0), Vector3.FORWARD)
		graph.add_edge(previous.node_id, node.node_id)
		previous = node
	var streamer = ChunkStreamerClass.new()
	streamer.road_graph = graph
	var active = ChunkStreamerClass.RoadBranch.new()
	active.branch_id = 1
	active.state = ChunkStreamerClass.BranchState.ACTIVE
	active.graph_entry_node_id = 15
	streamer.branches[1] = active
	var discarded = ChunkStreamerClass.RoadBranch.new()
	discarded.branch_id = 2
	discarded.state = ChunkStreamerClass.BranchState.DORMANT
	streamer.branches[2] = discarded
	streamer._unload_branch(2)
	_check(not streamer.branches.has(2), "unloaded route leaves branch registry")
	_check(graph.nodes.size() == 6 and graph.edges.size() == 5, "graph history is pruned to live route window")
	_check(graph.root_node_id == 15 and graph.nodes.has(15), "graph root advances to oldest retained node")
	_check(graph.is_valid_dag() and graph.validate_full_graph().is_valid, "pruned graph has no stale adjacency references")
	streamer.free()

func test_foliage_order_independence() -> void:
	var path = RoadPathDataClass.new()
	for i in range(30):
		path.append_sample(Vector3(0.0, 0.0, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP,
			0.0, 0.0, RoadPathDataClass.SegmentType.STRAIGHT)
	var noise := FastNoiseLite.new()
	noise.seed = 184729
	var streamer = ChunkStreamerClass.new()
	var route = ChunkStreamerClass.RoadBranch.new()
	route.road_path = path
	route.foliage_route_seed = 83472
	var first_key: int = streamer._foliage_seed_key(route, 0, 25)
	var interleaved_key: int = streamer._foliage_seed_key(route, 5, 20)
	var replay_key: int = streamer._foliage_seed_key(route, 0, 25)
	var first: Dictionary = ChunkFoliageClass.compute_foliage_and_decor_transforms(path, 0, 25, 4, noise, null, 3, first_key)
	var replay: Dictionary = ChunkFoliageClass.compute_foliage_and_decor_transforms(path, 0, 25, 991, noise, null, 3, replay_key)
	var other_route: Dictionary = ChunkFoliageClass.compute_foliage_and_decor_transforms(path, 0, 25, 4, noise, null, 3, first_key + 1)
	_check(first == replay, "same logical foliage chunk is independent of global chunk allocation id")
	_check(first != other_route, "distinct logical chunk keys produce distinct deterministic dressing")
	_check(first_key != interleaved_key, "different route intervals remain decorrelated when materialized between retries")
	streamer.free()

func test_validator_input_and_sightline_contract() -> void:
	var empty_path = RoadPathDataClass.new()
	_check(not ValidatorClass.validate_segment(empty_path).is_valid, "empty road path is rejected instead of passing validation")
	var malformed = RoadPathDataClass.new()
	for i in range(3):
		malformed.append_sample(Vector3(0.0, 0.0, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP, 0.0, 0.0, 0)
	malformed.slopes.resize(2)
	_check(not ValidatorClass.validate_segment(malformed).is_valid, "mismatched RoadPathData arrays are rejected without indexing past bounds")
	var path = RoadPathDataClass.new()
	for i in range(70):
		var y: float = 3.0 if i >= 10 and i <= 12 else 0.0
		path.append_sample(Vector3(0.0, y, -float(i) * 2.0), Vector3.FORWARD, Vector3.UP, 0.0, 0.0,
			RoadPathDataClass.SegmentType.BRAKING_ZONE, Airborne.SurfaceContactMode.GROUNDED, 0.0, 50.0)
	var blocked_report = ValidatorClass.validate_segment(path)
	var found_sight_violation: bool = false
	for violation: Dictionary in blocked_report.violations:
		if violation.code == "ERR_SIGHTLINE":
			found_sight_violation = true
	_check(found_sight_violation, "occluded production braking-zone geometry is rejected by segment validation")

func test_generated_airborne_survives_validation() -> void:
	for seed_value: int in [184729, 42, 7319, 900001]:
		var path = RoadPathDataClass.new()
		var logic = RoadLogicClass.new(seed_value, path)
		logic.grammar.phase_queue.assign([GrammarClass.FlowPhase.AIRBORNE_DROP])
		logic.plan_next_chunk()
		var airborne_count: int = 0
		var landing_count: int = 0
		var flight_distance: float = 0.0
		var flight_start_height: float = 0.0
		var flight_end_height: float = 0.0
		for i in range(1, path.size()):
			if path.surface_contact_states[i] == Airborne.SurfaceContactMode.AIRBORNE:
				if airborne_count == 0:
					flight_start_height = path.points[i - 1].y
				airborne_count += 1
				flight_distance += path.points[i].distance_to(path.points[i - 1])
				flight_end_height = path.points[i].y
			elif path.surface_contact_states[i] == Airborne.SurfaceContactMode.LANDING:
				landing_count += 1
		_check(logic.last_chunk_passed and airborne_count > 0 and landing_count > 0,
			"generated airborne candidate is accepted with a landing (seed %d)" % seed_value)
		_check(flight_distance <= Airborne.AIRBORNE_MAX_DIST + 0.01,
			"generated free-flight path stays within distance envelope (seed %d, %.3fm)" % [seed_value, flight_distance])
		_check(flight_start_height - flight_end_height <= Airborne.AIRBORNE_MAX_HEIGHT + 0.1,
			"generated free-flight drop stays within height envelope (seed %d, %.3fm)" % [seed_value, flight_start_height - flight_end_height])

func test_surface_weights_after_hitch() -> void:
	var controller = BicycleControllerClass.new()
	controller._blend_surface_weights(1.0, 0.0, 0.25)
	_check(_weights_valid(controller), "surface mixture stays normalized after a 250ms grass transition")
	controller._blend_surface_weights(0.0, 1.0, 0.25)
	_check(_weights_valid(controller), "surface mixture stays normalized after a 250ms gravel transition")
	controller._blend_surface_weights(0.5, 0.5, 0.05)
	_check(_weights_valid(controller), "mixed wheel contacts retain convex weights")
	controller.free()

func _weights_valid(controller: BicycleController) -> bool:
	var weights: Array[float] = [controller.surface_gravel_weight, controller.surface_grass_weight, controller.surface_rough_weight]
	var total: float = 0.0
	for weight: float in weights:
		if not is_finite(weight) or weight < 0.0 or weight > 1.0:
			return false
		total += weight
	return absf(total - 1.0) <= 0.00001
