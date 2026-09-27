class_name RouteIntent
extends RefCounted

## Seed-stable description of the intended rhythm/envelope for one route leg.
## Pure data only: no scene nodes, RNGs, meshes, or chunk allocation identities.

var world_seed: int = 0
var route_identity: String = ""
var branch_id: int = -1
var route_style: int = -1
var style_seed: int = 0
var global_start_distance_m: float = 0.0
var planned_length_m: float = 0.0
var phase_ids: Array[int] = []
var phase_envelopes: Array[Dictionary] = []

const PHASE_COUNT: int = 8
const SURFACE_MODE_COUNT: int = 4

func configure(
	p_world_seed: int,
	p_route_identity: String,
	p_branch_id: int,
	p_route_style: int,
	p_style_seed: int,
	p_global_start_distance_m: float,
	p_phase_ids: Array[int],
	p_phase_envelopes: Array[Dictionary]
) -> void:
	world_seed = p_world_seed
	route_identity = p_route_identity
	branch_id = p_branch_id
	route_style = p_route_style
	style_seed = p_style_seed
	global_start_distance_m = p_global_start_distance_m
	phase_ids = p_phase_ids.duplicate()
	phase_envelopes.clear()
	for envelope: Dictionary in p_phase_envelopes:
		phase_envelopes.append(envelope.duplicate(true))
	planned_length_m = 0.0
	for envelope: Dictionary in phase_envelopes:
		var min_length: float = float(envelope.get("min_length_m", 0.0))
		var max_length: float = float(envelope.get("max_length_m", 0.0))
		planned_length_m += (min_length + max_length) * 0.5

func validate() -> Dictionary:
	var reasons: Array[String] = []
	if route_identity.is_empty():
		reasons.append("ERR_ROUTE_IDENTITY")
	if branch_id < 0:
		reasons.append("ERR_BRANCH_ID")
	if route_style < 0:
		reasons.append("ERR_ROUTE_STYLE")
	elif route_style > 2:
		reasons.append("ERR_ROUTE_STYLE")
	if not is_finite(global_start_distance_m) or global_start_distance_m < 0.0:
		reasons.append("ERR_START_DISTANCE")
	if phase_ids.is_empty() or phase_envelopes.size() != phase_ids.size():
		reasons.append("ERR_PHASE_COUNT")
	if not is_finite(planned_length_m) or planned_length_m <= 0.0:
		reasons.append("ERR_PLANNED_LENGTH")
	for i in range(phase_envelopes.size()):
		var envelope: Dictionary = phase_envelopes[i]
		if phase_ids[i] < 0 or phase_ids[i] >= PHASE_COUNT:
			reasons.append("ERR_PHASE_RANGE_%d" % i)
		if int(envelope.get("phase_id", -1)) != phase_ids[i]:
			reasons.append("ERR_PHASE_ID_%d" % i)
		for field: String in ["min_slope_deg", "max_slope_deg", "target_speed_kmh", "min_length_m", "max_length_m", "min_radius_m", "sight_distance_m", "banking_angle_deg"]:
			if not envelope.has(field) or not is_finite(float(envelope.get(field, NAN))):
				reasons.append("ERR_PHASE_ENVELOPE_%d_%s" % [i, field.to_upper()])
		if envelope.has("min_slope_deg") and envelope.has("max_slope_deg") and float(envelope.min_slope_deg) > float(envelope.max_slope_deg):
			reasons.append("ERR_SLOPE_ENVELOPE_%d" % i)
		if envelope.has("min_length_m") and envelope.has("max_length_m") and (float(envelope.min_length_m) <= 0.0 or float(envelope.min_length_m) > float(envelope.max_length_m)):
			reasons.append("ERR_LENGTH_ENVELOPE_%d" % i)
		if envelope.has("target_speed_kmh") and float(envelope.target_speed_kmh) < 0.0:
			reasons.append("ERR_TARGET_SPEED_%d" % i)
		if envelope.has("min_radius_m") and float(envelope.min_radius_m) <= 0.0:
			reasons.append("ERR_MIN_RADIUS_%d" % i)
		if envelope.has("sight_distance_m") and float(envelope.sight_distance_m) < 0.0:
			reasons.append("ERR_SIGHT_DISTANCE_%d" % i)
		if envelope.has("surface_mode") and (int(envelope.surface_mode) < 0 or int(envelope.surface_mode) >= SURFACE_MODE_COUNT):
			reasons.append("ERR_SURFACE_MODE_%d" % i)
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}

func to_dictionary() -> Dictionary:
	return {
		"world_seed": world_seed,
		"route_identity": route_identity,
		"branch_id": branch_id,
		"route_style": route_style,
		"style_seed": style_seed,
		"global_start_distance_m": global_start_distance_m,
		"planned_length_m": planned_length_m,
		"phase_ids": phase_ids.duplicate(),
		"phase_envelopes": phase_envelopes.duplicate(true)
	}

func stable_signature() -> String:
	return JSON.stringify(to_dictionary(), "", false).sha256_text()
