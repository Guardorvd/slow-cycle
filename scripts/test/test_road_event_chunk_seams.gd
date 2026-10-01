extends SceneTree

## Stage B4a: prove adjacent production road chunks meet on identical mesh/collision rows.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")
const ValidatorClass = preload("res://scripts/world/road_validity_validator.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")

const SEEDS: Array[int] = [184729, 42, 7319, 900001]
const SEQUENCES: Array[Dictionary] = [
	{"name": "crest_recovery", "phases": [GrammarClass.FlowPhase.CREST_MICRO_DROP, GrammarClass.FlowPhase.RECOVERY_FLAT]},
	{"name": "airborne_landing_recovery", "phases": [GrammarClass.FlowPhase.AIRBORNE_DROP, GrammarClass.FlowPhase.RECOVERY_FLAT]},
	{"name": "switchback_recovery", "phases": [GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.RECOVERY_FLAT]},
	{"name": "mixed_event_chain", "phases": [GrammarClass.FlowPhase.CRUISE_DOWNHILL, GrammarClass.FlowPhase.CREST_MICRO_DROP,
		GrammarClass.FlowPhase.RECOVERY_FLAT, GrammarClass.FlowPhase.AIRBORNE_DROP, GrammarClass.FlowPhase.RECOVERY_FLAT,
		GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.RECOVERY_FLAT]}
]

var checks: int = 0
var failures: int = 0

func _init() -> void:
	for scenario: Dictionary in SEQUENCES:
		for seed_value: int in SEEDS:
			var first: Dictionary = _audit_sequence(seed_value, scenario)
			var replay: Dictionary = _audit_sequence(seed_value, scenario)
			_check(bool(first.get("accepted", false)), "%s production sequence is accepted (seed %d): %s" % [scenario.name, seed_value, first.get("reason", "unknown")])
			_check(bool(first.get("events_present", false)), "%s produced each requested event/contact phase (seed %d): %s" % [scenario.name, seed_value, first.get("event_reason", "unknown")])
			_check(bool(first.get("seams_clean", false)), "%s path and seam contracts pass (seed %d): %s" % [scenario.name, seed_value, first.get("seam_reason", "unknown")])
			_check(bool(first.get("rows_match", false)), "%s road and roadside rows match at chunk boundaries (seed %d)" % [scenario.name, seed_value])
			_check(bool(first.get("faces_valid", false)), "%s production collision faces cover both sides of each boundary (seed %d)" % [scenario.name, seed_value])
			_check(first.get("signature", "") == replay.get("signature", ""), "%s chunk preparation replays deterministically (seed %d)" % [scenario.name, seed_value])
			print("ROAD_EVENT_CHUNK_SEAM seed=%d sequence=%s chunks=%d boundaries=%d max_pos_error_m=%.6f max_tangent_deg=%.4f max_slope_delta_deg=%.4f max_normal_deg=%.4f road_row_error_m=%.6f terrain_row_error_m=%.6f road_faces=%d terrain_faces=%d" % [
				seed_value, scenario.name, int(first.chunks), int(first.boundaries), float(first.max_pos_error_m),
				float(first.max_tangent_deg), float(first.max_slope_delta_deg), float(first.max_normal_deg),
				float(first.road_row_error_m), float(first.terrain_row_error_m), int(first.road_faces), int(first.terrain_faces)])
	print("ROAD_EVENT_CHUNK_SEAMS_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("ROAD_EVENT_CHUNK_SEAM_FAIL " + message)

func _audit_sequence(seed_value: int, scenario: Dictionary) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.grammar.phase_queue.assign(scenario.phases)
	var ranges: Array[Vector2i] = []
	var accepted: bool = true
	var accepted_reason: String = ""
	var events_present: bool = true
	var event_reason: String = ""
	for phase: int in scenario.phases:
		var start_idx: int = path.size() - 1
		logic.plan_next_chunk()
		var end_idx: int = path.size() - 1
		if not logic.last_chunk_passed or logic.last_validity_report == null or not logic.last_validity_report.is_valid:
			accepted = false
			accepted_reason = "phase %d rejected: %s" % [phase, str(logic.last_validity_report.violations if logic.last_validity_report != null else "missing report")]
		var phase_present: bool = false
		var airborne_present: bool = false
		var landing_present: bool = false
		for sample_idx: int in range(start_idx + 1, end_idx + 1):
			var segment_type: int = path.segment_types[sample_idx]
			var contact_state: int = path.surface_contact_states[sample_idx]
			match phase:
				GrammarClass.FlowPhase.CREST_MICRO_DROP:
					phase_present = phase_present or (segment_type == RoadPathDataClass.SegmentType.CREST_MICRO_DROP and contact_state == Airborne.SurfaceContactMode.MICRO_DROP)
				GrammarClass.FlowPhase.AIRBORNE_DROP:
					airborne_present = airborne_present or (segment_type == RoadPathDataClass.SegmentType.AIRBORNE_DROP and contact_state == Airborne.SurfaceContactMode.AIRBORNE)
					landing_present = landing_present or (segment_type == RoadPathDataClass.SegmentType.VALID_LANDING_SURFACE and contact_state == Airborne.SurfaceContactMode.LANDING)
					phase_present = airborne_present and landing_present
				GrammarClass.FlowPhase.SWITCHBACK:
					phase_present = phase_present or segment_type == RoadPathDataClass.SegmentType.SWITCHBACK
				GrammarClass.FlowPhase.RECOVERY_FLAT:
					phase_present = phase_present or (segment_type == RoadPathDataClass.SegmentType.RECOVERY_FLAT and contact_state == Airborne.SurfaceContactMode.GROUNDED)
				GrammarClass.FlowPhase.CRUISE_DOWNHILL:
					phase_present = phase_present or segment_type == RoadPathDataClass.SegmentType.CRUISE_DOWNHILL
		if not phase_present:
			events_present = false
			event_reason = "requested phase %d missing from samples [%d..%d]" % [phase, start_idx, end_idx]
		ranges.append(Vector2i(start_idx, end_idx))

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	var terrain_carver = TerrainCarverClass.new(seed_value)
	var materials: Dictionary = {"noise": noise, "terrain_carver": terrain_carver}
	var seams_clean: bool = true
	var rows_match: bool = true
	var faces_valid: bool = true
	var seam_reason: String = ""
	var max_pos_error: float = 0.0
	var max_tangent_deg: float = 0.0
	var max_slope_delta_deg: float = 0.0
	var max_normal_deg: float = 0.0
	var max_road_row_error: float = 0.0
	var max_terrain_row_error: float = 0.0
	var road_face_count: int = 0
	var terrain_face_count: int = 0
	var signature: PackedStringArray = PackedStringArray()
	for i: int in range(ranges.size() - 1):
		var left_range: Vector2i = ranges[i]
		var right_range: Vector2i = ranges[i + 1]
		if left_range.y != right_range.x:
			seams_clean = false
			seam_reason = "chunk ranges do not overlap at one shared sample (%d != %d)" % [left_range.y, right_range.x]
			continue
		var left_path: RefCounted = path.slice_segment(left_range.x, left_range.y)
		var right_path: RefCounted = path.slice_segment(right_range.x, right_range.y)
		var seam_report = ValidatorClass.validate_seam(left_path, left_path.size() - 1, right_path, 0)
		if not seam_report.is_valid:
			seams_clean = false
			seam_reason = str(seam_report.violations)
		var boundary_idx: int = left_range.y
		var position_error: float = left_path.points[-1].distance_to(right_path.points[0])
		var tangent_angle: float = rad_to_deg(left_path.tangents[-1].angle_to(right_path.tangents[0]))
		var slope_delta: float = absf(left_path.slopes[-1] - right_path.slopes[0])
		var normal_angle: float = rad_to_deg(left_path.normals[-1].angle_to(right_path.normals[0]))
		max_pos_error = maxf(max_pos_error, position_error)
		max_tangent_deg = maxf(max_tangent_deg, tangent_angle)
		max_slope_delta_deg = maxf(max_slope_delta_deg, slope_delta)
		max_normal_deg = maxf(max_normal_deg, normal_angle)

		var left_prep = RoadChunkClass.prepare_geometry_data(path, left_range.x, left_range.y, i, materials)
		var right_prep = RoadChunkClass.prepare_geometry_data(path, right_range.x, right_range.y, i + 1, materials)
		var left_road: PackedVector3Array = left_prep.road_arrays[Mesh.ARRAY_VERTEX]
		var right_road: PackedVector3Array = right_prep.road_arrays[Mesh.ARRAY_VERTEX]
		var left_terrain: PackedVector3Array = left_prep.terrain_arrays[Mesh.ARRAY_VERTEX]
		var right_terrain: PackedVector3Array = right_prep.terrain_arrays[Mesh.ARRAY_VERTEX]
		var left_road_boundary_faces: PackedVector3Array = left_prep.road_faces.slice(left_prep.road_faces.size() - 6, left_prep.road_faces.size())
		var right_road_boundary_faces: PackedVector3Array = right_prep.road_faces.slice(0, 6)
		var road_error: float = 0.0
		var road_boundary_targets: PackedVector3Array = PackedVector3Array()
		for edge: int in range(2):
			road_error = maxf(road_error, left_road[left_road.size() - 2 + edge].distance_to(right_road[edge]))
			road_boundary_targets.append(left_road[left_road.size() - 2 + edge])
		road_error = maxf(road_error, _max_nearest_error(left_road_boundary_faces, road_boundary_targets))
		road_error = maxf(road_error, _max_nearest_error(right_road_boundary_faces, road_boundary_targets))

		var half_width: float = path.road_widths[boundary_idx] * 0.5 if not path.road_widths.is_empty() else RoadChunkClass.ROAD_HALF_WIDTH
		var signed_curv: float = path.get_signed_curvature(boundary_idx)
		var cross_section: Dictionary = terrain_carver.compute_cross_section(path.points[boundary_idx], path.tangents[boundary_idx],
			path.normals[boundary_idx], path.binormals[boundary_idx], half_width, signed_curv,
			path.segment_types[boundary_idx], path.cumulative_distances[boundary_idx])
		var terrain_row: PackedVector3Array = cross_section.vertices
		var active_terrain_row: PackedVector3Array = PackedVector3Array()
		for vertex_idx: int in range(12):
			active_terrain_row.append(terrain_row[vertex_idx])
		var left_terrain_boundary_faces: PackedVector3Array = left_prep.terrain_faces.slice(left_prep.terrain_faces.size() - 60, left_prep.terrain_faces.size())
		var right_terrain_boundary_faces: PackedVector3Array = right_prep.terrain_faces.slice(0, 60)
		var terrain_error: float = maxf(
			_max_nearest_error(left_terrain, active_terrain_row),
			_max_nearest_error(right_terrain, active_terrain_row))
		terrain_error = maxf(terrain_error, _max_nearest_error(left_terrain_boundary_faces, active_terrain_row))
		terrain_error = maxf(terrain_error, _max_nearest_error(right_terrain_boundary_faces, active_terrain_row))
		max_road_row_error = maxf(max_road_row_error, road_error)
		max_terrain_row_error = maxf(max_terrain_row_error, terrain_error)
		if road_error > 0.000001 or terrain_error > 0.000001:
			rows_match = false
		var expected_road_faces: int = (left_range.y - left_range.x) * 6 + (right_range.y - right_range.x) * 6
		var expected_terrain_faces: int = (left_range.y - left_range.x + right_range.y - right_range.x) * 60
		road_face_count += left_prep.road_faces.size() + right_prep.road_faces.size()
		terrain_face_count += left_prep.terrain_faces.size() + right_prep.terrain_faces.size()
		if left_prep.road_faces.size() != (left_range.y - left_range.x) * 6 \
				or right_prep.road_faces.size() != (right_range.y - right_range.x) * 6 \
				or left_prep.terrain_faces.size() != (left_range.y - left_range.x) * 60 \
				or right_prep.terrain_faces.size() != (right_range.y - right_range.x) * 60 \
				or not _faces_are_finite_and_non_degenerate(left_prep.road_faces) \
				or not _faces_are_finite_and_non_degenerate(right_prep.road_faces) \
				or not _faces_are_finite_and_non_degenerate(left_prep.terrain_faces) \
				or not _faces_are_finite_and_non_degenerate(right_prep.terrain_faces):
			faces_valid = false
		signature.append("%d|%d|%d|%.6f|%.6f|%.6f|%.6f" % [boundary_idx, expected_road_faces, expected_terrain_faces,
			road_error, terrain_error, tangent_angle, slope_delta])
	return {
		"accepted": accepted, "reason": accepted_reason, "events_present": events_present,
		"event_reason": event_reason, "seams_clean": seams_clean,
		"seam_reason": seam_reason, "rows_match": rows_match, "faces_valid": faces_valid,
		"max_pos_error_m": max_pos_error, "max_tangent_deg": max_tangent_deg,
		"max_slope_delta_deg": max_slope_delta_deg, "max_normal_deg": max_normal_deg,
		"road_row_error_m": max_road_row_error, "terrain_row_error_m": max_terrain_row_error,
		"road_faces": road_face_count, "terrain_faces": terrain_face_count,
		"chunks": ranges.size(), "boundaries": maxi(0, ranges.size() - 1),
		"signature": ";".join(signature)
	}

func _max_nearest_error(vertices: PackedVector3Array, targets: PackedVector3Array) -> float:
	if vertices.is_empty() or targets.is_empty():
		return INF
	var max_error: float = 0.0
	for target: Vector3 in targets:
		var nearest: float = INF
		for vertex: Vector3 in vertices:
			nearest = minf(nearest, target.distance_to(vertex))
		max_error = maxf(max_error, nearest)
	return max_error

func _faces_are_finite_and_non_degenerate(faces: PackedVector3Array) -> bool:
	if faces.is_empty() or faces.size() % 3 != 0:
		return false
	for i: int in range(0, faces.size(), 3):
		var a: Vector3 = faces[i]
		var b: Vector3 = faces[i + 1]
		var c: Vector3 = faces[i + 2]
		if not a.is_finite() or not b.is_finite() or not c.is_finite():
			return false
		if (b - a).cross(c - a).length_squared() < 0.0000000001:
			return false
	return true
