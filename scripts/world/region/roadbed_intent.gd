class_name RoadbedIntent
extends RefCounted

## R6 -> R7 roadbed intent (`slow_cycle.roadbed_intent/1`, ExecPlan §9 + C3):
## the minimal bounded description of the surface and support a designed
## piece needs. Data only: not a final surface, mesh, collider or second
## height owner. R4/R5 keep sampling the natural pre-road world; R7 owns the
## deformation, blending, surface queries and support realisation and must
## re-check the signatures. Side "l" is the R5 band's left side, normal
## (-dz, +dx) of the canonical a -> b direction.
##
## Piece intent stations (<= 4 m, plus every support change): centreline x/z,
## road centre height y, riding width, shoulders, road-edge heights, natural
## heights at the shoulder edges, signed edge delta (+ fill / - cut), daylight
## tie-in reach beyond each shoulder and support kind. The footprint is the
## shoulder edge plus tie-in on each side; displacement tapers along the
## stylised side slope (cut 1:1, fill 1:2) to zero at its outer edge; outside
## it nothing moves. Bridge decks and fords are support obligations over
## preserved water / natural terrain, never fills of the watercourse.
## Junction patches: one record per node-owned shared plane.

const Policy = preload("res://scripts/world/region/road_synthesis_policy.gd")
const STATION_MAX_M: float = 4.0


static func from_piece(piece_id: String, owner: Dictionary, route_class: int, design: Dictionary, crossings: Array, signatures: Dictionary, connector: bool) -> Dictionary:
	var cls: Dictionary = Policy.CLASSES[route_class]
	var shoulder: float = 0.0 if connector else cls.shoulder_m
	var keys: Array[String] = ["s", "x", "z", "y", "width", "edge_y_l", "edge_y_r", "nat_l", "nat_r", "nat_c", "delta_l", "delta_r", "tie_l", "tie_r"]
	var st: Dictionary = {}
	for key: String in keys:
		st[key] = PackedFloat64Array()
	var support := PackedByteArray()
	var n: int = design.s.size()
	var last_s: float = -INF
	for i in range(n):
		var change: bool = i > 0 and design.support[i] != design.support[i - 1]
		var next_change: bool = i < n - 1 and design.support[i] != design.support[i + 1]
		if not (i == 0 or i == n - 1 or change or next_change or design.s[i] - last_s >= STATION_MAX_M - 1e-9 or (i < n - 1 and design.s[i + 1] - last_s > STATION_MAX_M)):
			continue
		last_s = design.s[i]
		var half: float = 0.5 * design.width[i] + shoulder
		var tb: float = tan(deg_to_rad(design.bank[i]))
		st.s.append(design.s[i])
		st.x.append(design.x[i])
		st.z.append(design.z[i])
		st.y.append(design.y[i])
		st.width.append(design.width[i])
		st.edge_y_l.append(design.y[i] - half * tb)
		st.edge_y_r.append(design.y[i] + half * tb)
		st.nat_l.append(design.nat_l[i])
		st.nat_r.append(design.nat_r[i])
		st.nat_c.append(design.nat_c[i])
		st.delta_l.append(design.fill_l[i])
		st.delta_r.append(design.fill_r[i])
		st.tie_l.append(design.tie_l[i])
		st.tie_r.append(design.tie_r[i])
		support.append(design.support[i])
	st["support"] = support
	var refs: Array = []
	for r: Dictionary in crossings:
		var deck: bool = r.support == Policy.Support.BRIDGE_DECK
		refs.append({"crossing_id": r.get("crossing_id", ""), "support": Policy.SUPPORT_NAMES[r.support], "s0": r.deck_s0, "s1": r.deck_s1, "wet_s0": r.wet_s0, "wet_s1": r.wet_s1,
			"water_surface_m": r.surface_m, "deck_min_m": r.surface_m + Policy.DECK_CLEARANCE_M + Policy.DECK_STRUCTURE_M if deck else NAN, "clear_span_m": r.clear_span_m,
			"bearing_m": Policy.BRIDGE_BEARING_M if deck else 0.0, "ford_depth_m": r.depth_m if not deck else 0.0,
			"requires_support": deck, "physical_support_built": false, "preserve": "watercourse and natural terrain below the deck / ford"})
	for ref: Dictionary in refs:
		if is_nan(ref.deck_min_m):
			ref.deck_min_m = 0.0
	return {"schema": Policy.INTENT_SCHEMA, "intent_id": "intent:" + piece_id, "piece_id": piece_id, "owner": owner, "kind": "PIECE", "route_class": route_class,
		"origin": signatures.origin, "natural_signature": signatures.natural, "policy_signature": signatures.policy, "side_convention": "l = R5 left (-dz, +dx) of canonical a->b",
		"limits": {"cut_max_m": cls.cut_max_m, "fill_max_m": cls.fill_max_m, "tie_max_m": cls.tie_max_m, "cut_side_slope": Policy.CUT_SIDE_SLOPE, "fill_side_slope": Policy.FILL_SIDE_SLOPE,
			"shoulder_m": shoulder}, "stations": st, "crossings": refs, "status": "BOUNDED"}


static func from_patch(junction: Dictionary, signatures: Dictionary) -> Dictionary:
	var patch: Dictionary = junction.patch
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var natural := PackedFloat64Array()
	var plane := PackedFloat64Array()
	for sample: Array in patch.get("samples", []):
		xs.append(sample[0])
		zs.append(sample[1])
		natural.append(sample[2])
		plane.append(sample[3])
	return {"schema": Policy.INTENT_SCHEMA, "intent_id": "intent:patch:%d" % junction.node_id, "piece_id": "", "owner": {"node_id": junction.node_id}, "kind": "JUNCTION_PATCH",
		"origin": signatures.origin, "natural_signature": signatures.natural, "policy_signature": signatures.policy,
		"patch": {"centre_x": junction.x, "centre_z": junction.z, "radius_m": patch.get("radius_m", 0.0), "y0": patch.get("y0", 0.0), "gx": patch.get("gx", 0.0), "gz": patch.get("gz", 0.0),
			"sample_x": xs, "sample_z": zs, "natural_m": natural, "plane_m": plane, "max_cut_m": patch.get("max_cut_m", 0.0), "max_fill_m": patch.get("max_fill_m", 0.0)},
		"limits": {"cut_max_m": patch.get("cut_limit_m", 0.0), "fill_max_m": patch.get("fill_limit_m", 0.0), "grade_max": Policy.PATCH_GRADE_MAX},
		"support": Policy.SUPPORT_NAMES[Policy.Support.JUNCTION_PATCH], "status": "BOUNDED" if junction.status != Policy.JUNCTION_BLOCKED or not "ERR_R6_JUNCTION_HEIGHT" in junction.reasons else "UNSUPPORTED"}


## Schema and bound check of one intent record.
static func validate(intent: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	if intent.get("schema", "") != Policy.INTENT_SCHEMA or not intent.has("intent_id") or not intent.has("limits"):
		return {"is_valid": false, "reason_codes": ["ERR_R6_SCHEMA"]}
	var limits: Dictionary = intent.limits
	if intent.kind == "JUNCTION_PATCH":
		var patch: Dictionary = intent.patch
		if patch.max_cut_m > limits.cut_max_m + 1e-6 or patch.max_fill_m > limits.fill_max_m + 1e-6 or Vector2(patch.gx, patch.gz).length() > limits.grade_max + 1e-9:
			reasons.append("ERR_R6_EARTHWORK")
		return {"is_valid": reasons.is_empty(), "reason_codes": reasons}
	var st: Dictionary = intent.stations
	var n: int = st.s.size()
	for key: String in st:
		if st[key].size() != n:
			return {"is_valid": false, "reason_codes": ["ERR_R6_PATH_STRUCTURE"]}
		if st[key] is PackedFloat64Array:
			for v: float in st[key]:
				if not is_finite(v):
					return {"is_valid": false, "reason_codes": ["ERR_R6_NONFINITE"]}
	for i in range(n):
		if i > 0 and st.s[i] <= st.s[i - 1]:
			reasons.append("ERR_R6_PATH_STRUCTURE")
			break
		if st.support[i] >= Policy.SUPPORT_NAMES.size():
			reasons.append("ERR_R6_SCHEMA")
			break
		if st.support[i] == Policy.Support.EARTHWORK:
			if maxf(-st.delta_l[i], -st.delta_r[i]) > limits.cut_max_m + 1e-6 or maxf(st.delta_l[i], st.delta_r[i]) > limits.fill_max_m + 1e-6 or maxf(st.tie_l[i], st.tie_r[i]) > limits.tie_max_m + 1e-6:
				reasons.append("ERR_R6_EARTHWORK")
				break
	for ref: Dictionary in intent.crossings:
		if ref.support == Policy.SUPPORT_NAMES[Policy.Support.BRIDGE_DECK]:
			for i in range(n):
				if st.s[i] >= ref.wet_s0 and st.s[i] <= ref.wet_s1 and st.y[i] < ref.deck_min_m - 1e-3:
					reasons.append("ERR_R6_CROSSING_SUPPORT")
					break
	return {"is_valid": reasons.is_empty(), "reason_codes": reasons}
