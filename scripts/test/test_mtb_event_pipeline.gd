extends SceneTree

## Stage B1: verify a production MTB event survives validation and reaches
## RoadChunk's mesh/collision preparation path without silent fallback.

const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const Airborne = preload("res://scripts/world/road_airborne_contract.gd")
const RoadChunkClass = preload("res://scripts/world/road_chunk.gd")
const TerrainCarverClass = preload("res://scripts/world/terrain_carver.gd")
const ValidatorClass = preload("res://scripts/world/road_validity_validator.gd")

var checks: int = 0
var failures: int = 0

func _init() -> void:
	for seed_value: int in [184729, 42, 7319, 900001]:
		var first: Dictionary = _generate_event_pipeline(seed_value)
		var replay: Dictionary = _generate_event_pipeline(seed_value)
		_check(bool(first.get("ok", false)), "production event reaches prepared surface (seed %d): %s" % [seed_value, first.get("reason", "unknown")])
		_check(first.get("signature", "") == replay.get("signature", ""), "event and prepared surfaces replay deterministically (seed %d)" % seed_value)
		print("MTB_EVENT_PIPELINE seed=%d accepted=%s airborne=%d landing=%d recovery=%d mesh_vertices=%d road_faces=%d covered_segments=%d" % [
			seed_value, str(first.get("ok", false)), int(first.get("airborne", 0)), int(first.get("landing", 0)),
			int(first.get("recovery", 0)), int(first.get("mesh_vertices", 0)), int(first.get("road_faces", 0)), int(first.get("covered", 0))])
	print("MTB_EVENT_PIPELINE_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("MTB_EVENT_PIPELINE_FAIL " + message)

func _generate_event_pipeline(seed_value: int) -> Dictionary:
	var path = RoadPathDataClass.new()
	var logic = RoadLogicClass.new(seed_value, path)
	logic.grammar.phase_queue.assign([GrammarClass.FlowPhase.AIRBORNE_DROP])
	logic.plan_next_chunk()
	var event_report = logic.last_validity_report
	var event_accepted: bool = logic.last_chunk_passed and event_report != null and event_report.is_valid \
		and event_report.segment_status == ValidatorClass.SegmentStatus.VALID_AIRBORNE
	var event_end: int = path.size() - 1
	var airborne_count: int = 0
	var landing_count: int = 0
	var flight_distance: float = 0.0
	var flight_start_height: float = 0.0
	var flight_end_height: float = 0.0
	for i in range(1, path.size()):
		if path.surface_contact_states[i] == Airborne.SurfaceContactMode.AIRBORNE:
			if airborne_count == 0:
				flight_start_height = path.points[i - 1].y
			flight_distance += path.points[i].distance_to(path.points[i - 1])
			flight_end_height = path.points[i].y
			airborne_count += 1
		if path.surface_contact_states[i] == Airborne.SurfaceContactMode.LANDING:
			landing_count += 1
	var airborne_in_event_range: bool = false
	var landing_in_event_range: bool = false
	var airborne_type_in_event_range: bool = false
	for i in range(1, event_end + 1):
		airborne_in_event_range = airborne_in_event_range or path.surface_contact_states[i] == Airborne.SurfaceContactMode.AIRBORNE
		landing_in_event_range = landing_in_event_range or path.surface_contact_states[i] == Airborne.SurfaceContactMode.LANDING
		airborne_type_in_event_range = airborne_type_in_event_range or path.segment_types[i] == RoadPathDataClass.SegmentType.AIRBORNE_DROP

	# The grammar queues the recovery phase directly after the airborne/landing event.
	logic.plan_next_chunk()
	var recovery_accepted: bool = logic.last_chunk_passed and logic.last_validity_report != null and logic.last_validity_report.is_valid
	var recovery_count: int = 0
	for i in range(event_end + 1, path.size()):
		if path.segment_types[i] == RoadPathDataClass.SegmentType.RECOVERY_FLAT and path.surface_contact_states[i] == Airborne.SurfaceContactMode.GROUNDED:
			recovery_count += 1

	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	var materials: Dictionary = {"noise": noise, "terrain_carver": TerrainCarverClass.new(seed_value)}
	var prep = RoadChunkClass.prepare_geometry_data(path, 0, path.size() - 1, 1, materials)
	var mesh_vertices: PackedVector3Array = prep.road_arrays[Mesh.ARRAY_VERTEX] if prep.road_arrays.size() > Mesh.ARRAY_VERTEX else PackedVector3Array()
	var covered: int = 0
	var event_segment_count: int = 0
	for i in range(1, event_end + 1):
		if path.surface_contact_states[i] not in [Airborne.SurfaceContactMode.AIRBORNE, Airborne.SurfaceContactMode.LANDING]:
			continue
		event_segment_count += 1
		var midpoint: Vector3 = (path.points[i - 1] + path.points[i]) * 0.5
		if _point_is_covered_by_faces(midpoint, prep.road_faces):
			covered += 1

	var finite_mesh: bool = not mesh_vertices.is_empty()
	for vertex: Vector3 in mesh_vertices:
		if not vertex.is_finite():
			finite_mesh = false
			break
	var finite_faces: bool = not prep.road_faces.is_empty()
	for vertex: Vector3 in prep.road_faces:
		if not vertex.is_finite():
			finite_faces = false
			break

	var success: bool = event_accepted and airborne_count > 0 and landing_count > 0 \
		and airborne_in_event_range and landing_in_event_range and airborne_type_in_event_range \
		and flight_distance <= Airborne.AIRBORNE_MAX_DIST + 0.01 \
		and flight_start_height - flight_end_height <= Airborne.AIRBORNE_MAX_HEIGHT + 0.1 \
		and recovery_accepted and recovery_count > 0 and finite_mesh and finite_faces \
		and event_segment_count > 0 and covered == event_segment_count
	var signature: String = "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		airborne_count, landing_count, recovery_count, mesh_vertices.size(), prep.road_faces.size(), covered,
		path.size(), hash(path.points), hash(path.surface_contact_states), hash(path.segment_types), hash(prep.road_faces)]
	var reason: String = "accepted=%s recovery_valid=%s airborne=%d landing=%d recovery=%d flight=%.3fm drop=%.3fm covered=%d/%d" % [
		str(event_accepted), str(recovery_accepted), airborne_count, landing_count, recovery_count,
		flight_distance, flight_start_height - flight_end_height, covered, event_segment_count]
	return {"ok": success, "reason": reason, "signature": signature, "airborne": airborne_count,
		"landing": landing_count, "recovery": recovery_count, "mesh_vertices": mesh_vertices.size(),
		"road_faces": prep.road_faces.size(), "covered": covered}

func _point_is_covered_by_faces(point: Vector3, faces: PackedVector3Array) -> bool:
	for i in range(0, faces.size() - 2, 3):
		if _point_is_inside_triangle(point, faces[i], faces[i + 1], faces[i + 2]):
			return true
	return false

func _point_is_inside_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var normal: Vector3 = ab.cross(ac)
	var normal_length: float = normal.length()
	if normal_length < 0.000001 or absf((point - a).dot(normal / normal_length)) > 0.001:
		return false
	var ap: Vector3 = point - a
	var d00: float = ab.dot(ab)
	var d01: float = ab.dot(ac)
	var d11: float = ac.dot(ac)
	var d20: float = ap.dot(ab)
	var d21: float = ap.dot(ac)
	var denominator: float = d00 * d11 - d01 * d01
	if absf(denominator) < 0.000001:
		return false
	var v: float = (d11 * d20 - d01 * d21) / denominator
	var w: float = (d00 * d21 - d01 * d20) / denominator
	var u: float = 1.0 - v - w
	return u >= -0.0001 and v >= -0.0001 and w >= -0.0001
