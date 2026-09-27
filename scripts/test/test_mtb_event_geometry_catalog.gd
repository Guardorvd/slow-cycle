extends SceneTree

## Stage B3: measure production event envelopes and enforce the reviewed micro-drop bound.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const SEEDS: Array[int] = [184729, 42, 7319, 900001, 10101, 20202, 30303, 40404, 50505, 60606, 70707, 80808]
const EVENTS: Array[Dictionary] = [
	{"name": "crest_micro_drop", "phase": GrammarClass.FlowPhase.CREST_MICRO_DROP,
		"segment": RoadPathDataClass.SegmentType.CREST_MICRO_DROP},
	{"name": "airborne_landing", "phase": GrammarClass.FlowPhase.AIRBORNE_DROP,
		"segment": RoadPathDataClass.SegmentType.AIRBORNE_DROP},
	{"name": "switchback", "phase": GrammarClass.FlowPhase.SWITCHBACK,
		"segment": RoadPathDataClass.SegmentType.SWITCHBACK},
	{"name": "recovery", "phase": GrammarClass.FlowPhase.RECOVERY_FLAT,
		"segment": RoadPathDataClass.SegmentType.RECOVERY_FLAT}
]

var checks: int = 0
var failures: int = 0

func _init() -> void:
	for event: Dictionary in EVENTS:
		for seed_value: int in SEEDS:
			var first: Dictionary = _measure_event(seed_value, event)
			var replay: Dictionary = _measure_event(seed_value, event)
			_check(bool(first.get("accepted", false)), "%s accepted without fallback (seed %d): %s" % [event.name, seed_value, first.get("reason", "unknown")])
			_check(int(first.get("event_samples", 0)) > 0, "%s has requested production samples (seed %d)" % [event.name, seed_value])
			_check(bool(first.get("finite", false)), "%s metrics are finite (seed %d)" % [event.name, seed_value])
			_check(first.get("signature", "") == replay.get("signature", ""), "%s replay metrics match (seed %d)" % [event.name, seed_value])
			if event.name == "crest_micro_drop":
				var measured_drop: float = float(first.get("feature_height_delta_m", 0.0))
				_check(measured_drop > 0.0 and measured_drop <= 0.35 + 0.001,
					"crest micro-drop actual height %.3fm is within (0, 0.35m] (seed %d)" % [measured_drop, seed_value])
				_check(int(first.get("micro_drop_samples", 0)) == 2,
					"crest retains the two marked MICRO_DROP contacts (seed %d)" % seed_value)
			if int(event.phase) == GrammarClass.FlowPhase.AIRBORNE_DROP:
				_check(int(first.get("recovery_samples", 0)) > 0, "airborne event reaches grounded recovery (seed %d)" % seed_value)
			print("MTB_EVENT_GEOMETRY seed=%d event=%s accepted=%s samples=%d event_samples=%d length_m=%.3f height_delta_m=%.3f feature_drop_m=%.3f grade_deg=%.2f..%.2f max_grade_geometry_error_deg=%.2f peak_curvature=%.5f turn_deg=%.2f airborne=%d landing=%d micro_drop=%d" % [
				seed_value, event.name, str(first.accepted), int(first.samples), int(first.event_samples),
				float(first.length_m), float(first.height_delta_m), float(first.feature_height_delta_m),
				float(first.grade_min_deg), float(first.grade_max_deg), float(first.max_grade_geometry_error_deg),
				float(first.peak_curvature), float(first.turn_deg), int(first.airborne_samples),
				int(first.landing_samples), int(first.micro_drop_samples)])
	print("MTB_EVENT_GEOMETRY_CATALOG_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MTB_EVENT_GEOMETRY_CATALOG_FAIL " + message)

func _measure_event(seed_value: int, event: Dictionary) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.grammar.phase_queue.assign([int(event.phase)])
	logic.plan_next_chunk()
	var accepted: bool = logic.last_chunk_passed and logic.last_validity_report != null and logic.last_validity_report.is_valid
	var event_end: int = path.size() - 1
	var recovery_accepted: bool = true
	var recovery_sample_count: int = 0
	if int(event.phase) == GrammarClass.FlowPhase.AIRBORNE_DROP:
		logic.plan_next_chunk()
		recovery_accepted = logic.last_chunk_passed and logic.last_validity_report != null and logic.last_validity_report.is_valid
		for i: int in range(event_end + 1, path.size()):
			if path.segment_types[i] == RoadPathDataClass.SegmentType.RECOVERY_FLAT \
					and path.surface_contact_states[i] == Airborne.SurfaceContactMode.GROUNDED:
				recovery_sample_count += 1

	var start_index: int = 1
	var end_index: int = event_end
	if int(event.phase) == GrammarClass.FlowPhase.RECOVERY_FLAT:
		end_index = path.size() - 1
	var sample_count: int = maxi(0, end_index - start_index + 1)
	var event_sample_count: int = 0
	var first_event_index: int = -1
	var last_event_index: int = -1
	var airborne_count: int = 0
	var landing_count: int = 0
	var micro_drop_count: int = 0
	var grade_min: float = INF
	var grade_max: float = -INF
	var height_min: float = INF
	var height_max: float = -INF
	var peak_curvature: float = 0.0
	var turn_deg: float = 0.0
	var length_m: float = 0.0
	var max_grade_geometry_error: float = 0.0
	var finite: bool = true
	var signature_parts: PackedStringArray = PackedStringArray()
	for i: int in range(start_index, end_index + 1):
		var point: Vector3 = path.points[i]
		var grade: float = path.slopes[i]
		var curvature: float = path.curvatures[i]
		if not point.is_finite() or not is_finite(grade) or not is_finite(curvature):
			finite = false
		grade_min = minf(grade_min, grade)
		grade_max = maxf(grade_max, grade)
		height_min = minf(height_min, point.y)
		height_max = maxf(height_max, point.y)
		peak_curvature = maxf(peak_curvature, absf(curvature))
		if path.segment_types[i] == int(event.segment):
			event_sample_count += 1
			if first_event_index < 0:
				first_event_index = i
			last_event_index = i
		if path.surface_contact_states[i] == Airborne.SurfaceContactMode.AIRBORNE:
			airborne_count += 1
		if path.surface_contact_states[i] == Airborne.SurfaceContactMode.LANDING:
			landing_count += 1
		if path.surface_contact_states[i] == Airborne.SurfaceContactMode.MICRO_DROP:
			micro_drop_count += 1
		var delta: Vector3 = path.points[i] - path.points[i - 1]
		length_m += delta.length()
		var geometric_grade: float = rad_to_deg(atan2(delta.y, Vector2(delta.x, delta.z).length()))
		max_grade_geometry_error = maxf(max_grade_geometry_error, absf(geometric_grade - grade))
		if i > start_index:
			turn_deg += rad_to_deg(path.tangents[i - 1].angle_to(path.tangents[i]))
		signature_parts.append("%.5f,%.5f,%.5f,%.5f,%d,%d" % [
			point.x, point.y, point.z, grade, path.segment_types[i], path.surface_contact_states[i]])
	var event_accepted: bool = accepted and recovery_accepted
	var feature_height_delta: float = 0.0
	if first_event_index >= 0:
		feature_height_delta = path.points[first_event_index - 1].y - path.points[last_event_index].y
	var metrics_signature: String = "%s|%d|%d|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f" % [
		";".join(signature_parts), event_sample_count, sample_count, length_m,
		height_max - height_min, grade_min, grade_max, peak_curvature, turn_deg]
	metrics_signature += "|%.5f|%.5f" % [feature_height_delta, max_grade_geometry_error]
	var reason: String = "accepted=%s recovery=%s status=%s" % [
		str(accepted), str(recovery_accepted), str(logic.last_validity_report.segment_status if logic.last_validity_report != null else -1)]
	return {
		"accepted": event_accepted, "reason": reason, "finite": finite, "samples": sample_count,
		"event_samples": event_sample_count, "length_m": length_m, "height_delta_m": height_max - height_min,
		"grade_min_deg": grade_min, "grade_max_deg": grade_max, "peak_curvature": peak_curvature,
		"turn_deg": turn_deg, "airborne_samples": airborne_count, "landing_samples": landing_count,
		"feature_height_delta_m": feature_height_delta, "max_grade_geometry_error_deg": max_grade_geometry_error,
		"micro_drop_samples": micro_drop_count, "recovery_samples": recovery_sample_count,
		"signature": metrics_signature
	}
