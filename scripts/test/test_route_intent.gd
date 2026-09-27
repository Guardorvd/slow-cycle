extends SceneTree

## Exercises the authored route-style opening through production RoadLogic.
## This checks generated samples, not just the phase queue declarations.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const Grammar = preload("res://scripts/world/road_grammar.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const SEEDS: Array[int] = [184729, 42, 7319, 900001]
const STYLE_SEED_SALTS: Array[int] = [101, 909]
const OPENING_CHUNKS: int = 9

var failures: int = 0
var checks: int = 0
var signatures: Dictionary = {}

func _init() -> void:
	for seed_value: int in SEEDS:
		for style: int in [Grammar.RouteStyle.FLOW, Grammar.RouteStyle.TECHNICAL]:
			for salt: int in STYLE_SEED_SALTS:
				var style_seed: int = int(hash([seed_value, style, salt]) & 0x7FFFFFFF)
				var first: Dictionary = _generate_opening(seed_value, style, style_seed)
				var repeat: Dictionary = _generate_opening(seed_value, style, style_seed)
				_check(not first.is_empty() and first == repeat,
					"same world/style seed reproduces generated intent metrics")
				if first.is_empty():
					continue
				print("ROUTE_INTENT_METRIC seed=%d style=%s salt=%d types=%s switchbacks=%d micro_drop_chunks=%d max_curvature=%.5f grade=%.2f..%.2f max_gap=%.3fm" % [seed_value, "FLOW" if style == Grammar.RouteStyle.FLOW else "TECHNICAL", salt, str(first.types), first.switchbacks, first.micro_drop_chunks, first.max_curvature, first.grade_range.x, first.grade_range.y, first.max_gap])
				_check(bool(first.valid), "all authored chunks pass production validation")
				_check(bool(first.events_valid), "style event signature and recovery rhythm are present")
				_check(bool(first.contract_valid), "grade, curvature, spacing and contacts stay in contract")
				var key: String = "%d:%d:%d" % [seed_value, style, salt]
				signatures[key] = first.signature
		_check_style_separation(seed_value, STYLE_SEED_SALTS[0])
	print("ROUTE_INTENT_SUMMARY checks=%d failures=%d seeds=%d style_seed_salts=%d" % [checks, failures, SEEDS.size(), STYLE_SEED_SALTS.size()])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[ROUTE INTENT FAIL] " + message)

func _generate_opening(seed_value: int, style: int, style_seed: int) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.set_route_style(style, style_seed)
	var chunk_types: Array[int] = []
	var signature: Array[String] = []
	var valid: bool = true
	var contract_valid: bool = true
	var max_curvature: float = 0.0
	var min_grade: float = 90.0
	var max_grade: float = -90.0
	var max_gap: float = 0.0
	var airborne_samples: int = 0
	var landing_samples: int = 0
	var micro_drop_samples: int = 0
	var micro_drop_chunks: int = 0
	var switchback_count: int = 0
	var cruise_recovery_chunks: int = 0
	var switchback_turn_signs: Array[int] = []
	for chunk_idx in range(OPENING_CHUNKS):
		var start_idx: int = path.size() - 1
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1
		valid = valid and logic.last_chunk_passed
		var dominant_type: int = int(path.segment_types[end_idx])
		chunk_types.append(dominant_type)
		signature.append(str(dominant_type))
		var chunk_airborne: int = 0
		var chunk_landing: int = 0
		var chunk_micro_drop: int = 0
		var chunk_turn_sum: float = 0.0
		for idx in range(start_idx + 1, end_idx + 1):
			var segment_type: int = int(path.segment_types[idx])
			var contact_mode: int = int(path.surface_contact_states[idx])
			max_curvature = maxf(max_curvature, absf(path.curvatures[idx]))
			min_grade = minf(min_grade, path.slopes[idx])
			max_grade = maxf(max_grade, path.slopes[idx])
			if contact_mode == Airborne.SurfaceContactMode.AIRBORNE:
				airborne_samples += 1
				chunk_airborne += 1
			if contact_mode == Airborne.SurfaceContactMode.LANDING:
				landing_samples += 1
				chunk_landing += 1
			if contact_mode == Airborne.SurfaceContactMode.MICRO_DROP:
				micro_drop_samples += 1
				chunk_micro_drop += 1
			if segment_type == RoadPathDataClass.SegmentType.SWITCHBACK and idx == end_idx:
				switchback_count += 1
			if segment_type == RoadPathDataClass.SegmentType.SWITCHBACK and idx > start_idx + 1:
				chunk_turn_sum += path.tangents[idx - 1].cross(path.tangents[idx]).dot(Vector3.UP)
			if idx > 0:
				var gap: float = path.points[idx].distance_to(path.points[idx - 1])
				max_gap = maxf(max_gap, gap)
				contract_valid = contract_valid and gap <= 2.5
			contract_valid = contract_valid and path.slopes[idx] >= -14.01 and path.slopes[idx] <= 5.01
			contract_valid = contract_valid and absf(path.curvatures[idx]) <= 1.0 / 18.0 + 0.0001
		if chunk_airborne > 0:
			_check(chunk_landing > 0, "airborne chunk carries its paired landing samples")
		if chunk_micro_drop > 0:
			micro_drop_chunks += 1
		if absf(chunk_turn_sum) > 0.001:
			switchback_turn_signs.append(1 if chunk_turn_sum > 0.0 else -1)
		if dominant_type in [RoadPathDataClass.SegmentType.CRUISE_DOWNHILL, RoadPathDataClass.SegmentType.CREST_MICRO_DROP, RoadPathDataClass.SegmentType.RECOVERY_FLAT]:
			cruise_recovery_chunks += 1
	if path.size() > 1:
		var path_values := PackedStringArray()
		for idx in range(path.size()):
			path_values.append("%.3f,%.3f,%.3f,%.3f" % [path.points[idx].x, path.points[idx].y, path.points[idx].z, path.slopes[idx]])
		signature.append_array(path_values)
	var events_valid: bool = false
	if style == Grammar.RouteStyle.FLOW:
		events_valid = micro_drop_chunks >= 2 and switchback_count == 0 and airborne_samples == 0 and cruise_recovery_chunks >= 5
	else:
		events_valid = switchback_count >= 2 and switchback_turn_signs.size() >= 2 and switchback_turn_signs[0] != switchback_turn_signs[1] and micro_drop_chunks >= 1 and airborne_samples == 0 and chunk_types[2] == RoadPathDataClass.SegmentType.RECOVERY_FLAT and chunk_types[5] == RoadPathDataClass.SegmentType.RECOVERY_FLAT and chunk_types[7] == RoadPathDataClass.SegmentType.RECOVERY_FLAT
	return {
		"valid": valid,
		"events_valid": events_valid,
		"contract_valid": contract_valid,
		"signature": "|".join(signature),
		"types": chunk_types,
		"switchbacks": switchback_count,
		"max_curvature": max_curvature,
		"grade_range": Vector2(min_grade, max_grade),
		"max_gap": max_gap,
		"airborne": airborne_samples,
		"landing": landing_samples,
		"micro_drop": micro_drop_samples,
		"micro_drop_chunks": micro_drop_chunks
	}

func _check_style_separation(seed_value: int, salt: int) -> void:
	var flow_key: String = "%d:%d:%d" % [seed_value, Grammar.RouteStyle.FLOW, salt]
	var technical_key: String = "%d:%d:%d" % [seed_value, Grammar.RouteStyle.TECHNICAL, salt]
	_check(signatures.has(flow_key) and signatures.has(technical_key), "both style runs recorded for separation comparison")
	if signatures.has(flow_key) and signatures.has(technical_key):
		_check(signatures[flow_key] != signatures[technical_key], "FLOW and TECHNICAL produce different centerline signatures")
