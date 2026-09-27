class_name RoutePlan
extends RefCounted

## Measured, node-free result for one RouteIntent leg.

const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")

var intent: RefCounted
var phase_intervals: Array[Dictionary] = []
var metrics: Dictionary = {}
var telemetry: Dictionary = {}

static func from_road_path(
	route_intent: RefCounted,
	path_data: RefCounted,
	chunk_ranges: Array[Dictionary],
	p_telemetry: Dictionary
) -> RefCounted:
	var plan = load("res://scripts/world/route_plan.gd").new()
	plan.intent = route_intent
	plan.telemetry = p_telemetry.duplicate(true)
	if route_intent == null or not route_intent.has_method("validate"):
		return plan
	if path_data == null or path_data.get_script() != RoadPathDataClass or path_data.size() < 2:
		return plan
	for field: String in ["cumulative_distances", "slopes", "curvatures", "segment_types", "surface_contact_states"]:
		if path_data.get(field).size() != path_data.size():
			return plan
	if chunk_ranges.size() != route_intent.phase_ids.size():
		return plan
	var start_idx: int = int(chunk_ranges[0].start_idx)
	var end_idx: int = int(chunk_ranges[-1].end_idx)
	if start_idx < 0 or end_idx >= path_data.size() or end_idx <= start_idx:
		return plan
	for i in range(chunk_ranges.size()):
		var bounds: Dictionary = chunk_ranges[i]
		var phase_start: int = int(bounds.start_idx)
		var phase_end: int = int(bounds.end_idx)
		if phase_start < start_idx or phase_end > end_idx or phase_end <= phase_start:
			return plan
		plan.phase_intervals.append({
			"phase_id": route_intent.phase_ids[i],
			"start_distance_m": route_intent.global_start_distance_m + path_data.cumulative_distances[phase_start],
			"end_distance_m": route_intent.global_start_distance_m + path_data.cumulative_distances[phase_end],
			"start_sample": phase_start,
			"end_sample": phase_end
		})
	var min_grade: float = INF
	var max_grade: float = -INF
	var max_curvature: float = 0.0
	var max_sample_gap: float = 0.0
	var contact_counts: Dictionary = {"grounded": 0, "micro_drop": 0, "airborne": 0, "landing": 0}
	var event_counts: Dictionary = {}
	for i in range(start_idx + 1, end_idx + 1):
		min_grade = minf(min_grade, path_data.slopes[i])
		max_grade = maxf(max_grade, path_data.slopes[i])
		max_curvature = maxf(max_curvature, absf(path_data.curvatures[i]))
		max_sample_gap = maxf(max_sample_gap, path_data.points[i].distance_to(path_data.points[i - 1]))
		var segment_type: int = path_data.segment_types[i]
		event_counts[segment_type] = int(event_counts.get(segment_type, 0)) + 1
		match path_data.surface_contact_states[i]:
			Airborne.SurfaceContactMode.GROUNDED:
				contact_counts.grounded += 1
			Airborne.SurfaceContactMode.MICRO_DROP:
				contact_counts.micro_drop += 1
			Airborne.SurfaceContactMode.AIRBORNE:
				contact_counts.airborne += 1
			Airborne.SurfaceContactMode.LANDING:
				contact_counts.landing += 1
	plan.metrics = {
		"actual_length_m": path_data.cumulative_distances[end_idx] - path_data.cumulative_distances[start_idx],
		"min_grade_deg": min_grade,
		"max_grade_deg": max_grade,
		"max_abs_curvature_inv_m": max_curvature,
		"max_sample_gap_m": max_sample_gap,
		"contact_counts": contact_counts,
		"event_counts": event_counts
	}
	return plan

func validate() -> Dictionary:
	var reasons: Array[String] = []
	if intent == null or not intent.has_method("validate"):
		return {"is_valid": false, "reason_codes": ["ERR_INTENT_MISSING"]}
	var intent_check: Dictionary = intent.validate()
	if not intent_check.is_valid:
		reasons.append_array(intent_check.reason_codes)
	if phase_intervals.size() != intent.phase_ids.size() or phase_intervals.is_empty():
		reasons.append("ERR_INTERVAL_COUNT")
	var previous_end: float = -INF
	for i in range(phase_intervals.size()):
		var interval: Dictionary = phase_intervals[i]
		if int(interval.get("phase_id", -1)) != intent.phase_ids[i]:
			reasons.append("ERR_INTERVAL_PHASE_%d" % i)
		if i >= intent.phase_envelopes.size() or int(intent.phase_envelopes[i].get("phase_id", -1)) != int(interval.get("phase_id", -1)):
			reasons.append("ERR_INTERVAL_ENVELOPE_%d" % i)
		var start_m: float = float(interval.get("start_distance_m", NAN))
		var end_m: float = float(interval.get("end_distance_m", NAN))
		if not is_finite(start_m) or not is_finite(end_m) or end_m <= start_m or start_m < previous_end - 0.001:
			reasons.append("ERR_INTERVAL_BOUNDS_%d" % i)
		if i == 0 and is_finite(start_m) and absf(start_m - intent.global_start_distance_m) > 0.001:
			reasons.append("ERR_INTERVAL_ORIGIN")
		if i > 0 and is_finite(start_m) and is_finite(previous_end) and absf(start_m - previous_end) > 0.01:
			reasons.append("ERR_INTERVAL_GAP_%d" % i)
		if int(interval.get("start_sample", -1)) < 0 or int(interval.get("end_sample", -1)) <= int(interval.get("start_sample", -1)):
			reasons.append("ERR_INTERVAL_SAMPLES_%d" % i)
		previous_end = end_m
	for key: String in ["actual_length_m", "min_grade_deg", "max_grade_deg", "max_abs_curvature_inv_m", "max_sample_gap_m", "contact_counts", "event_counts"]:
		if not metrics.has(key):
			reasons.append("ERR_METRIC_MISSING_%s" % key.to_upper())
	for key: String in ["actual_length_m", "min_grade_deg", "max_grade_deg", "max_abs_curvature_inv_m", "max_sample_gap_m"]:
		if metrics.has(key) and not is_finite(float(metrics[key])):
			reasons.append("ERR_METRIC_NONFINITE_%s" % key.to_upper())
	if metrics.has("actual_length_m") and float(metrics.actual_length_m) <= 0.0:
		reasons.append("ERR_METRIC_LENGTH")
	if metrics.has("min_grade_deg") and metrics.has("max_grade_deg") and float(metrics.min_grade_deg) > float(metrics.max_grade_deg):
		reasons.append("ERR_METRIC_GRADE_RANGE")
	if metrics.has("max_sample_gap_m") and float(metrics.max_sample_gap_m) <= 0.0:
		reasons.append("ERR_METRIC_SAMPLE_GAP")
	for key: String in ["contact_counts", "event_counts"]:
		if metrics.has(key) and not metrics[key] is Dictionary:
			reasons.append("ERR_METRIC_TYPE_%s" % key.to_upper())
	if metrics.has("max_abs_curvature_inv_m") and float(metrics.max_abs_curvature_inv_m) < 0.0:
		reasons.append("ERR_METRIC_CURVATURE")
	if not telemetry.has("sample_count") or int(telemetry.get("sample_count", 0)) <= 0:
		reasons.append("ERR_TELEMETRY_EMPTY")
	if str(telemetry.get("source", "")).is_empty():
		reasons.append("ERR_TELEMETRY_SOURCE")
	for key: String in ["mean_speed_kmh", "mean_cadence_pct", "coasting_ratio"]:
		if not telemetry.has(key) or not is_finite(float(telemetry.get(key, NAN))):
			reasons.append("ERR_TELEMETRY_%s" % key.to_upper())
	if telemetry.has("coasting_ratio") and (float(telemetry.coasting_ratio) < 0.0 or float(telemetry.coasting_ratio) > 1.0):
		reasons.append("ERR_TELEMETRY_COASTING_RANGE")
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}

func to_dictionary() -> Dictionary:
	return {
		"intent": intent.to_dictionary() if intent != null and intent.has_method("to_dictionary") else {},
		"phase_intervals": phase_intervals.duplicate(true),
		"metrics": metrics.duplicate(true),
		"telemetry": telemetry.duplicate(true)
	}

func stable_signature() -> String:
	return JSON.stringify(to_dictionary(), "", false).sha256_text()
