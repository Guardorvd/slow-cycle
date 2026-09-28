extends SceneTree

## Captures existing FLOW/TECHNICAL route baselines and controlled bike telemetry.

const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")
const BicycleScene = preload("res://scenes/player/bicycle.tscn")
const Grammar = preload("res://scripts/world/road_grammar.gd")
const RoutePlanClass = preload("res://scripts/world/route_plan.gd")
const RouteIntentClass = preload("res://scripts/world/route_intent.gd")
const SEEDS: Array[int] = [184729, 42, 7319, 900001]
const STYLE_SALTS: Array[int] = [101, 909]
const OPENING_CHUNKS: int = 9

var checks: int = 0
var failures: int = 0
var raw_telemetry_samples: Array[Dictionary] = []
var telemetry_profiles: Array[Dictionary] = []

func _init() -> void:
	_run()

func _run() -> void:
	_test_invalid_contract_inputs()
	var route_traces: Dictionary = {}
	var signatures: Dictionary = {}
	for seed_value: int in SEEDS:
		for style: int in [Grammar.RouteStyle.FLOW, Grammar.RouteStyle.TECHNICAL]:
			for salt: int in STYLE_SALTS:
				var style_seed: int = int(hash([seed_value, style, salt]) & 0x7FFFFFFF)
				var trace: Dictionary = _generate_route(seed_value, style, style_seed)
				var replay: Dictionary = _generate_route(seed_value, style, style_seed)
				_check(not trace.is_empty() and not replay.is_empty(), "production opening generated")
				if trace.is_empty() or replay.is_empty():
					continue
				var intent: RefCounted = trace.intent
				var intent_replay: RefCounted = replay.intent
				_check(intent.validate().is_valid, "grammar adapter emits valid intent")
				_check(intent.stable_signature() == intent_replay.stable_signature(), "intent signature independent of evaluation order")
				_check(trace.signature == replay.signature, "production road geometry baseline repeats exactly")
				signatures["%d:%d:%d" % [seed_value, style, salt]] = intent.stable_signature()
				_check(trace.actual_length_m > 0.0 and trace.max_sample_gap_m <= 2.5, "measured opening length and sample spacing are within contract")
				if seed_value == SEEDS[0] and salt == STYLE_SALTS[0]:
					route_traces[style] = trace
				_print_geometry_summary(seed_value, style, salt, trace)
	for seed_index in range(SEEDS.size() - 1, -1, -1):
		var seed_value: int = SEEDS[seed_index]
		for style: int in [Grammar.RouteStyle.TECHNICAL, Grammar.RouteStyle.FLOW]:
			for salt_index in range(STYLE_SALTS.size() - 1, -1, -1):
				var salt: int = STYLE_SALTS[salt_index]
				var style_seed: int = int(hash([seed_value, style, salt]) & 0x7FFFFFFF)
				var reordered: Dictionary = _generate_route(seed_value, style, style_seed)
				var key: String = "%d:%d:%d" % [seed_value, style, salt]
				_check(not reordered.is_empty() and reordered.intent.stable_signature() == signatures.get(key),
					"seed battery signature survives reversed materialization order")
	for seed_value: int in SEEDS:
		for salt: int in STYLE_SALTS:
			var flow_key: String = "%d:%d:%d" % [seed_value, Grammar.RouteStyle.FLOW, salt]
			var tech_key: String = "%d:%d:%d" % [seed_value, Grammar.RouteStyle.TECHNICAL, salt]
			_check(signatures.get(flow_key, "") != signatures.get(tech_key, ""), "FLOW and TECHNICAL intents differ")
	for style: int in [Grammar.RouteStyle.FLOW, Grammar.RouteStyle.TECHNICAL]:
		if route_traces.has(style):
			await _run_controlled_telemetry(route_traces[style], style)
	print("ROUTE_PLAN_CONTRACT_SUMMARY checks=%d failures=%d geometry_profiles=%d physics_traces=%d" % [checks, failures, SEEDS.size() * STYLE_SALTS.size() * 2, telemetry_profiles.size()])
	await process_frame
	await physics_frame
	quit(1 if failures > 0 else 0)

func _test_invalid_contract_inputs() -> void:
	var empty_intent = RouteIntentClass.new()
	_check(not empty_intent.validate().is_valid, "empty intent is rejected with reason codes")
	var mismatch = RouteIntentClass.new()
	var envelope: Array[Dictionary] = [{
		"phase_id": Grammar.FlowPhase.CRUISE_DOWNHILL,
		"min_slope_deg": -8.0,
		"max_slope_deg": -5.0,
		"target_speed_kmh": 28.0,
		"min_length_m": 50.0,
		"max_length_m": 50.0,
		"min_radius_m": 45.0,
		"sight_distance_m": 50.0
	}]
	mismatch.configure(1, "route/invalid", 1, Grammar.RouteStyle.FLOW, 11, -1.0, [Grammar.FlowPhase.SWITCHBACK], envelope)
	var mismatch_result: Dictionary = mismatch.validate()
	_check(mismatch_result.reason_codes.has("ERR_PHASE_ID_0") and mismatch_result.reason_codes.has("ERR_START_DISTANCE"),
		"mismatched phase constraints and negative start distance are rejected")
	var unknown_phase = RouteIntentClass.new()
	unknown_phase.configure(1, "route/unknown-phase", 1, Grammar.RouteStyle.FLOW, 11, 0.0,
		[99], [{"phase_id": 99}])
	_check(unknown_phase.validate().reason_codes.has("ERR_PHASE_RANGE_0"), "unknown event type is rejected")
	var empty_plan = RoutePlanClass.new()
	_check(empty_plan.validate().reason_codes.has("ERR_INTENT_MISSING"), "plan without an intent is rejected with a reason code")
	var incomplete_plan = RoutePlanClass.new()
	incomplete_plan.intent = mismatch
	_check(incomplete_plan.validate().reason_codes.has("ERR_INTERVAL_COUNT"), "plan with missing event intervals is rejected")
	var malformed_path = RoadPathDataClass.new()
	for sample_idx in range(3):
		malformed_path.append_sample(Vector3(0.0, 0.0, -float(sample_idx) * 2.0), Vector3.FORWARD, Vector3.UP,
			0.0, 0.0, RoadPathDataClass.SegmentType.STRAIGHT)
	malformed_path.slopes.resize(2)
	var malformed_plan = RoutePlanClass.from_road_path(mismatch, malformed_path,
		[{"start_idx": 0, "end_idx": 2}], {})
	_check(malformed_plan.validate().reason_codes.has("ERR_METRIC_MISSING_ACTUAL_LENGTH_M"),
		"plan builder rejects malformed path arrays without indexing beyond bounds")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ROUTE_PLAN_CONTRACT_FAIL " + message)

func _generate_route(seed_value: int, style: int, style_seed: int) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.set_route_style(style, style_seed)
	var route_id: String = "world-%d/branch-7" % seed_value
	var intent: RefCounted = logic.grammar.build_route_intent(seed_value, route_id, 7, 1200.0)
	var chunk_ranges: Array[Dictionary] = []
	var signature := PackedStringArray()
	for _chunk_idx in range(OPENING_CHUNKS):
		var start_idx: int = maxi(0, path.size() - 1)
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1
		if not logic.last_chunk_passed:
			return {}
		chunk_ranges.append({"start_idx": start_idx, "end_idx": end_idx})
		signature.append("%d:%d:%d" % [logic.grammar.current_phase, start_idx, end_idx])
	for i in range(path.size()):
		signature.append("%.4f,%.4f,%.4f,%.3f,%.5f,%d" % [
			path.points[i].x, path.points[i].y, path.points[i].z, path.slopes[i], path.curvatures[i], path.segment_types[i]
		])
	var plan = RoutePlanClass.from_road_path(intent, path, chunk_ranges, {})
	var geometry_check: Dictionary = plan.validate()
	# RoutePlan validation requires observed telemetry; geometry baseline is reported separately.
	_check(geometry_check.reason_codes.has("ERR_TELEMETRY_EMPTY"), "plan refuses to present an unmeasured telemetry trace as complete")
	return {
		"path": path,
		"intent": intent,
		"chunk_ranges": chunk_ranges,
		"signature": "|".join(signature),
		"actual_length_m": plan.metrics.get("actual_length_m", 0.0),
		"min_grade_deg": plan.metrics.get("min_grade_deg", 0.0),
		"max_grade_deg": plan.metrics.get("max_grade_deg", 0.0),
		"max_curvature_inv_m": plan.metrics.get("max_abs_curvature_inv_m", 0.0),
		"max_sample_gap_m": plan.metrics.get("max_sample_gap_m", 0.0),
		"phase_counts": _phase_counts(path)
	}

func _phase_counts(path_data: RefCounted) -> Dictionary:
	var counts: Dictionary = {}
	for i in range(path_data.size()):
		counts[path_data.segment_types[i]] = int(counts.get(path_data.segment_types[i], 0)) + 1
	return counts

func _print_geometry_summary(seed_value: int, style: int, salt: int, trace: Dictionary) -> void:
	print("ROUTE_PLAN_GEOMETRY seed=%d style=%s salt=%d length=%.1fm grade=%.2f..%.2f curvature=%.5f gap=%.3fm phases=%s" % [
		seed_value, _style_name(style), salt, trace.actual_length_m, trace.min_grade_deg,
		trace.max_grade_deg, trace.max_curvature_inv_m, trace.max_sample_gap_m, str(trace.phase_counts)
	])

func _run_controlled_telemetry(trace: Dictionary, style: int) -> void:
	var path: RefCounted = trace.path
	var intent: RefCounted = trace.intent
	var root_node := Node3D.new()
	root.add_child(root_node)
	var noise := FastNoiseLite.new()
	noise.seed = intent.world_seed
	var materials: Dictionary = {
		"road": StandardMaterial3D.new(),
		"grass": StandardMaterial3D.new(),
		"noise": noise,
		"terrain_carver": TerrainCarverClass.new(intent.world_seed)
	}
	for chunk_idx in range(trace.chunk_ranges.size()):
		var bounds: Dictionary = trace.chunk_ranges[chunk_idx]
		var chunk: Node3D = RoadChunkClass.new()
		root_node.add_child(chunk)
		var prep = RoadChunkClass.prepare_geometry_data(path, bounds.start_idx, bounds.end_idx, chunk_idx + 1, materials)
		chunk.commit(prep, materials, {})
	var bike: CharacterBody3D = BicycleScene.instantiate()
	root_node.add_child(bike)
	bike.telemetry_updated.connect(_on_bike_telemetry)
	await physics_frame
	var local_distance: float = 0.0
	var path_length: float = path.cumulative_distances[-1]
	var phase_index: int = 0
	var fixed_delta: float = 1.0 / 60.0
	var first_sample: Dictionary = path.get_sample_at_distance(0.0)
	bike.current_speed = 6.0
	bike.global_position = first_sample.position + first_sample.normal * 0.48
	bike.velocity = first_sample.tangent * bike.current_speed
	while local_distance < path_length:
		while phase_index < trace.chunk_ranges.size() - 1 and local_distance > path.cumulative_distances[trace.chunk_ranges[phase_index].end_idx]:
			phase_index += 1
		var sample: Dictionary = path.get_sample_at_distance(local_distance)
		var tangent: Vector3 = sample.tangent
		var horizontal_tangent := Vector3(tangent.x, 0.0, tangent.z).normalized()
		bike.global_position = sample.position + sample.normal * 0.48
		if not horizontal_tangent.is_zero_approx():
			bike.global_transform.basis = Basis.looking_at(horizontal_tangent, Vector3.UP)
		var phase: int = intent.phase_ids[phase_index]
		var should_pedal: bool = phase in [Grammar.FlowPhase.CRUISE_DOWNHILL, Grammar.FlowPhase.RECOVERY_FLAT]
		var should_brake: bool = style == Grammar.RouteStyle.TECHNICAL and phase == Grammar.FlowPhase.BRAKING_ZONE
		if should_pedal:
			Input.action_press("pedal")
		else:
			Input.action_release("pedal")
		if should_brake:
			Input.action_press("brake")
		else:
			Input.action_release("brake")
		await physics_frame
		await process_frame
		# The path follower keeps the test rider on the exact centerline at a minimum
		# crawl even when the physics model stops; reported speed remains the bike's
		# measured controller output and is not replaced by this progress rate.
		local_distance += maxf(bike.current_speed, 7.0) * fixed_delta
	Input.action_release("pedal")
	Input.action_release("brake")
	var telemetry: Dictionary = _summarize_telemetry()
	telemetry["source"] = "controlled_path_follower_proxy"
	telemetry["path_progress_min_mps"] = 7.0
	var plan = RoutePlanClass.from_road_path(intent, path, trace.chunk_ranges, telemetry)
	var result: Dictionary = plan.validate()
	_check(result.is_valid, "%s complete measured route plan validates: %s" % [_style_name(style), str(result.reason_codes)])
	var replay_plan = RoutePlanClass.from_road_path(intent, path, trace.chunk_ranges, telemetry)
	_check(plan.stable_signature() == replay_plan.stable_signature(), "%s complete plan signature is repeatable" % _style_name(style))
	_check(not _contains_node(plan.to_dictionary()), "%s serialized plan contains data only, no scene nodes" % _style_name(style))
	_check(telemetry.sample_count > 100, "%s physics runner collected adequate telemetry" % _style_name(style))
	telemetry_profiles.append({"style": style, "telemetry": telemetry, "plan": plan})
	print("ROUTE_PLAN_TELEMETRY style=%s source=%s samples=%d path_progress_floor=%.1fm/s mean_speed=%.2fkmh mean_cadence=%.1f%% coasting=%.1f%%" % [
		_style_name(style), telemetry.source, telemetry.sample_count, telemetry.path_progress_min_mps,
		telemetry.mean_speed_kmh, telemetry.mean_cadence_pct, telemetry.coasting_ratio * 100.0
	])
	root_node.queue_free()
	await process_frame
	await physics_frame

func _on_bike_telemetry(speed_kmh: float, cadence_pct: float, is_coasting: bool) -> void:
	raw_telemetry_samples.append({"speed_kmh": speed_kmh, "cadence_pct": cadence_pct, "is_coasting": is_coasting})

func _summarize_telemetry() -> Dictionary:
	var count: int = raw_telemetry_samples.size()
	var speed_sum: float = 0.0
	var cadence_sum: float = 0.0
	var coast_count: int = 0
	for sample: Dictionary in raw_telemetry_samples:
		speed_sum += float(sample.speed_kmh)
		cadence_sum += float(sample.cadence_pct)
		if sample.is_coasting:
			coast_count += 1
	raw_telemetry_samples.clear()
	return {
		"sample_count": count,
		"mean_speed_kmh": speed_sum / float(maxi(1, count)),
		"mean_cadence_pct": cadence_sum / float(maxi(1, count)),
		"coasting_ratio": float(coast_count) / float(maxi(1, count))
	}

func _phase_index_for_sample(chunk_ranges: Array[Dictionary], sample_idx: int) -> int:
	for i in range(chunk_ranges.size()):
		var bounds: Dictionary = chunk_ranges[i]
		if sample_idx >= int(bounds.start_idx) and sample_idx <= int(bounds.end_idx):
			return i
	return maxi(0, chunk_ranges.size() - 1)

func _contains_node(value: Variant) -> bool:
	if value is Node:
		return true
	if value is Dictionary:
		for nested: Variant in value.values():
			if _contains_node(nested):
				return true
	elif value is Array:
		for nested: Variant in value:
			if _contains_node(nested):
				return true
	return false

func _style_name(style: int) -> String:
	return "FLOW" if style == Grammar.RouteStyle.FLOW else "TECHNICAL"
