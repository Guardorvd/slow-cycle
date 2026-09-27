extends SceneTree

## Stage B2: measure seeded long-range phase rhythm and validate production output.

const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const SEEDS: Array[int] = [184729, 42, 7319, 900001, 10101, 20202, 30303, 40404]
const PHASE_COUNT: int = 1200
const WINDOW_PHASES: int = 12
const FEATURE_GAP_LIMIT: int = 8

var checks: int = 0
var failures: int = 0

func _init() -> void:
	var aggregate_major: Dictionary = {
		GrammarClass.RouteStyle.FLOW: 0,
		GrammarClass.RouteStyle.BALANCED: 0,
		GrammarClass.RouteStyle.TECHNICAL: 0
	}
	var style_signatures: Dictionary = {}
	for style: int in [GrammarClass.RouteStyle.FLOW, GrammarClass.RouteStyle.BALANCED, GrammarClass.RouteStyle.TECHNICAL]:
		for seed_value: int in SEEDS:
			var trace: Array[int] = _phase_trace(seed_value, style, PHASE_COUNT)
			var replay: Array[int] = _phase_trace(seed_value, style, PHASE_COUNT)
			_check(trace == replay, "same seed/style reproduces the full phase sequence (seed=%d style=%d)" % [seed_value, style])
			var metrics: Dictionary = _measure_trace(trace)
			_check(int(metrics.max_feature_gap) <= FEATURE_GAP_LIMIT,
				"a light or major feature occurs within %d chunks (seed=%d style=%d gap=%d)" % [FEATURE_GAP_LIMIT, seed_value, style, metrics.max_feature_gap])
			_check(int(metrics.max_major_window) <= _major_event_limit(style),
				"major events stay within the style's rolling %d-phase cap (seed=%d style=%d max=%d)" % [WINDOW_PHASES, seed_value, style, metrics.max_major_window])
			aggregate_major[style] = int(aggregate_major[style]) + int(metrics.total_major)
			print("ROUTE_RHYTHM seed=%d style=%s phases=%d features=%d major=%d max_feature_gap=%d max_major_in_600m=%d" % [
				seed_value, _style_name(style), trace.size(), metrics.feature_count, metrics.total_major,
				metrics.max_feature_gap, metrics.max_major_window])
			if seed_value == SEEDS[0]:
				style_signatures[style] = trace
	_check(style_signatures[GrammarClass.RouteStyle.FLOW] != style_signatures[GrammarClass.RouteStyle.BALANCED]
		and style_signatures[GrammarClass.RouteStyle.BALANCED] != style_signatures[GrammarClass.RouteStyle.TECHNICAL],
		"FLOW, BALANCED and TECHNICAL produce distinct long-range phase patterns from the same seed")
	_check(int(aggregate_major[GrammarClass.RouteStyle.TECHNICAL]) > int(aggregate_major[GrammarClass.RouteStyle.BALANCED])
		and int(aggregate_major[GrammarClass.RouteStyle.BALANCED]) > int(aggregate_major[GrammarClass.RouteStyle.FLOW]),
		"major event density orders TECHNICAL > BALANCED > FLOW over the fixed seed battery")
	for style: int in [GrammarClass.RouteStyle.FLOW, GrammarClass.RouteStyle.BALANCED, GrammarClass.RouteStyle.TECHNICAL]:
		var different_seed_trace: Array[int] = _phase_trace(SEEDS[1], style, PHASE_COUNT)
		_check(style_signatures[style] != different_seed_trace,
			"different seeds produce different phase patterns for %s" % _style_name(style))
	test_production_routes()
	print("ROUTE_RHYTHM_SUMMARY checks=%d failures=%d FLOW_major=%d BALANCED_major=%d TECHNICAL_major=%d" % [
		checks, failures, aggregate_major[GrammarClass.RouteStyle.FLOW], aggregate_major[GrammarClass.RouteStyle.BALANCED], aggregate_major[GrammarClass.RouteStyle.TECHNICAL]])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ROUTE_RHYTHM_FAIL " + message)

func _phase_trace(seed_value: int, style: int, count: int) -> Array[int]:
	var grammar = GrammarClass.new(seed_value)
	grammar.set_route_style(style, seed_value)
	var phases: Array[int] = []
	for _i in range(count):
		phases.append(grammar.advance_phase().phase)
	return phases

func _measure_trace(phases: Array[int]) -> Dictionary:
	var feature_count: int = 0
	var major_count: int = 0
	var max_feature_gap: int = 0
	var since_feature: int = 0
	var max_major_window: int = 0
	for i in range(phases.size()):
		var phase: int = phases[i]
		if _is_feature(phase):
			feature_count += 1
			max_feature_gap = maxi(max_feature_gap, since_feature)
			since_feature = 0
		else:
			since_feature += 1
		if _is_major(phase):
			major_count += 1
		var window_major: int = 0
		for j in range(maxi(0, i - WINDOW_PHASES + 1), i + 1):
			if _is_major(phases[j]):
				window_major += 1
		max_major_window = maxi(max_major_window, window_major)
	max_feature_gap = maxi(max_feature_gap, since_feature)
	return {"feature_count": feature_count, "total_major": major_count,
		"max_feature_gap": max_feature_gap, "max_major_window": max_major_window}

func _is_feature(phase: int) -> bool:
	return phase in [GrammarClass.FlowPhase.CREST_MICRO_DROP, GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.AIRBORNE_DROP]

func _is_major(phase: int) -> bool:
	return phase in [GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.AIRBORNE_DROP]

func _major_event_limit(style: int) -> int:
	if style == GrammarClass.RouteStyle.FLOW:
		return 2
	if style == GrammarClass.RouteStyle.BALANCED:
		return 3
	return 4

func _style_name(style: int) -> String:
	match style:
		GrammarClass.RouteStyle.FLOW: return "FLOW"
		GrammarClass.RouteStyle.BALANCED: return "BALANCED"
		_: return "TECHNICAL"

func test_production_routes() -> void:
	var aggregate_major: Dictionary = {
		GrammarClass.RouteStyle.FLOW: 0,
		GrammarClass.RouteStyle.BALANCED: 0,
		GrammarClass.RouteStyle.TECHNICAL: 0
	}
	for seed_value: int in [184729, 42, 7319, 900001]:
		for style: int in [GrammarClass.RouteStyle.FLOW, GrammarClass.RouteStyle.BALANCED, GrammarClass.RouteStyle.TECHNICAL]:
			var first: Dictionary = _production_route(seed_value, style, 150)
			var replay: Dictionary = _production_route(seed_value, style, 150)
			_check(bool(first.ok), "all production chunks pass RoadLogic validation (seed=%d style=%s)" % [seed_value, _style_name(style)])
			_check(first.signature == replay.signature, "production centerline repeats for seed/style (seed=%d style=%s)" % [seed_value, _style_name(style)])
			aggregate_major[style] = int(aggregate_major[style]) + int(first.major)
			print("ROUTE_RHYTHM_PRODUCTION seed=%d style=%s phases=150 major=%d features=%d accepted=%s" % [
				seed_value, _style_name(style), first.major, first.features, str(first.ok)])
	_check(int(aggregate_major[GrammarClass.RouteStyle.TECHNICAL]) > int(aggregate_major[GrammarClass.RouteStyle.BALANCED])
		and int(aggregate_major[GrammarClass.RouteStyle.BALANCED]) > int(aggregate_major[GrammarClass.RouteStyle.FLOW]),
		"production major event density orders TECHNICAL > BALANCED > FLOW")
	for style: int in [GrammarClass.RouteStyle.FLOW, GrammarClass.RouteStyle.BALANCED, GrammarClass.RouteStyle.TECHNICAL]:
		var seed_a: Dictionary = _production_route(184729, style, 150)
		var seed_b: Dictionary = _production_route(42, style, 150)
		_check(seed_a.signature != seed_b.signature,
			"different world seeds produce different production centerlines for %s" % _style_name(style))

func _production_route(seed_value: int, style: int, count: int) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.set_route_style(style, seed_value)
	var signature_parts: PackedInt32Array = PackedInt32Array()
	var major_count: int = 0
	var feature_count: int = 0
	var all_accepted: bool = true
	for _i in range(count):
		var start_idx: int = path.size() - 1
		logic.plan_next_chunk()
		all_accepted = all_accepted and logic.last_chunk_passed
		var phase: int = logic.grammar.current_phase
		signature_parts.append(phase)
		if phase in [GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.AIRBORNE_DROP]:
			major_count += 1
		if phase in [GrammarClass.FlowPhase.CREST_MICRO_DROP, GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.AIRBORNE_DROP]:
			feature_count += 1
		if phase == GrammarClass.FlowPhase.SWITCHBACK:
			all_accepted = all_accepted and _chunk_contains_type(path, start_idx, RoadPathDataClass.SegmentType.SWITCHBACK)
		elif phase == GrammarClass.FlowPhase.CREST_MICRO_DROP:
			all_accepted = all_accepted and _chunk_contains_contact(path, start_idx, Airborne.SurfaceContactMode.MICRO_DROP)
		elif phase == GrammarClass.FlowPhase.AIRBORNE_DROP:
			all_accepted = all_accepted and _chunk_contains_contact(path, start_idx, Airborne.SurfaceContactMode.AIRBORNE) \
				and _chunk_contains_contact(path, start_idx, Airborne.SurfaceContactMode.LANDING)
	return {"ok": all_accepted, "signature": hash(path.points) * 31 + hash(signature_parts),
		"major": major_count, "features": feature_count}

func _chunk_contains_type(path: RoadPathData, start_idx: int, segment_type: int) -> bool:
	for i in range(start_idx + 1, path.size()):
		if path.segment_types[i] == segment_type:
			return true
	return false

func _chunk_contains_contact(path: RoadPathData, start_idx: int, contact_mode: int) -> bool:
	for i in range(start_idx + 1, path.size()):
		if path.surface_contact_states[i] == contact_mode:
			return true
	return false
