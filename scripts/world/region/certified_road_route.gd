class_name CertifiedRoadRoute
extends RefCounted
## Immutable authenticated extract; never accepts other PARTIAL-plan pieces.
const Plan = preload("res://scripts/world/region/road_synthesis_plan.gd")
const Intent = preload("res://scripts/world/region/roadbed_intent.gd")
const IDS = ["edge:2", "move:3:2-3", "edge:3", "move:4:3-4", "edge:4"]
const PLAN_SIGNATURE = "e9c11c398edced6d0a35a8632f2a71e68d771469b4eb2b48afc393fc97f8a8b4"
const ROUTE_DIGEST = "835422e71237d20b3e8e8975d1f52000cabb5e9df98a9c33979a4a715cfd875f"
const SCHEMA = "slow_cycle.certified_road_route/1"
var _data: Dictionary = {}

static func sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()

static func from_plan(plan: RefCounted, spec: Dictionary = {}) -> Dictionary:
	if plan == null or plan.signature() != PLAN_SIGNATURE:
		return failure("ERR_R7_ROUTE_DIGEST")
	var data := {"schema": SCHEMA, "header": plan.get_header(), "plan_signature": plan.signature(), "spec": spec.duplicate(true), "pieces": [], "patches": [], "crossings": [], "edges": [], "movements":[]}
	for id: String in IDS:
		var d: Dictionary = plan.get_design(id)
		var intent: Dictionary = plan.get_intent("intent:" + id)
		if d.is_empty() or intent.is_empty():
			return failure("ERR_R7_ROUTE_PIECE_MISSING")
		data.pieces.append({"id": id, "design": d, "intent": intent, "info": plan.get_piece_info(id)})
	for node in [3, 4]:
		data.patches.append(plan.get_intent("intent:patch:%d" % node))
		for movement: Dictionary in plan.get_junction(node).movements:
			if movement.piece_id in IDS:
				data.movements.append(movement)
	for edge in [2, 3, 4]:
		data.edges.append(plan.get_edge(edge))
	for id: String in plan.get_crossing_ids():
		var c: Dictionary = plan.get_crossing(id)
		if c.edge_id in [2, 3, 4]:
			data.crossings.append(c)
	return _validated(data)

static func failure(reason: String) -> Dictionary:
	return {"is_valid": false, "route": null, "reason_code": reason}

static func _validated(data: Dictionary) -> Dictionary:
	if data.get("schema", "") != SCHEMA or data.get("plan_signature", "") != PLAN_SIGNATURE:
		return failure("ERR_R7_ROUTE_DIGEST")
	if data.get("pieces", []).size() != IDS.size():
		return failure("ERR_R7_ROUTE_PIECE_MISSING")
	var route := CertifiedRoadRoute.new()
	route._data = data.duplicate(true)
	for k in range(IDS.size()):
		var p: Dictionary = data.pieces[k]
		if p.id != IDS[k] or p.get("intent", {}).is_empty():
			return failure("ERR_R7_ROUTE_PIECE_MISSING")
		if p.intent.status != "BOUNDED" or not Intent.validate(p.intent).is_valid:
			return failure("ERR_R7_INTENT_INVALID")
	if route.route_digest() != ROUTE_DIGEST:
		return failure("ERR_R7_ROUTE_DIGEST")
	return {"is_valid": true, "route": route, "reason_code": ""}

func route_digest() -> String:
	var lines := ""
	for p: Dictionary in _data.pieces:
		lines += p.id + "|fwd|" + sha(Plan.export_bytes(Plan.export_path(p.design, false))) + "\n"
	return sha(lines.to_utf8_buffer())

func get_data() -> Dictionary:
	return _data.duplicate(true)

func to_bytes() -> PackedByteArray:
	return var_to_bytes(_data)

static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		return failure("ERR_R7_CACHE_STALE")
	return _validated(data)

## Conservative superset of the R0–R6 closure, including configuration/resources
## and legacy export dependencies. Sorted path+byte hashes also detect additions.
static func dependency_digest() -> String:
	var paths: Array[String] = ["res://project.godot"]
	_collect("res://scripts/world", paths)
	_collect("res://scripts/core", paths)
	_collect("res://resources", paths)
	paths.sort()
	var lines := SCHEMA + PLAN_SIGNATURE + ROUTE_DIGEST + str(Engine.get_version_info())
	lines += sha(FileAccess.get_file_as_bytes("res://scripts/world/region/certified_road_route.gd"))
	for path: String in paths:
		if path.contains("final_surface") or path.ends_with("road_terrain_deformer.gd") or path.ends_with("certified_road_route.gd"):
			continue
		lines += path + "|" + sha(FileAccess.get_file_as_bytes(path)) + "\n"
	return lines.sha256_text()

static func _collect(directory: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.get_extension() in ["gd", "tres", "res", "json", "cfg", "csv"]:
			paths.append(directory.path_join(file))
	for sub: String in dir.get_directories():
		_collect(directory.path_join(sub), paths)
