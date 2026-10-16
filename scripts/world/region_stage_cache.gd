class_name RegionStageCache
extends RefCounted

## Dev stage reuse (never a production path): I/O adapter that keeps the
## products of the RegionBake ground stage (RegionBakeGround: network, R7,
## prototype-off tiles) and trail stage (RegionBakeTrails) under
## `user://regions_dev/stages/`, so a change that does not reach a stage
## reuses its products instead of re-running R5/R6/R7.
## Keys: SHA-256 of FORMAT, the bake schema, engine version, seed, region,
## stage options and the stage's source closure digest - every file the
## stage entry script can reach (preload / load / any res:// literal, a
## directory literal adds all its files, any global class_name used in the
## text), transitively, plus project.godot. The trail key also contains the
## ground key and the trail configuration digest. A missing, stale, damaged
## or inconsistent stage reads as invalid and the caller runs the stage.
## Loading verifies: file SHA-256, key, seed, region, region and hydrology
## signatures against the upstream built now, network digest, every tile
## content hash. Surfaces are rebuilt from the stored network (the same
## construction the bake makes). Final dev products go to DEV_ROOT through
## RegionBakeCache with a dev_stage_reuse manifest marker; the runtime reads
## them only with --dev-cache.

const Bake = preload("res://scripts/world/region/region_bake.gd")
const Ground = preload("res://scripts/world/region/region_bake_ground.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const FORMAT := "slow_cycle.region_stage/1"
const DEV_ROOT := "user://regions_dev"
const STAGE_ROOT := "user://regions_dev/stages"
const GROUND_ENTRY := "res://scripts/world/region/region_bake_ground.gd"
const TRAILS_ENTRY := "res://scripts/world/region/region_bake_trails.gd"
const SOURCE_EXTENSIONS: Array[String] = ["gd", "gdshader", "tres", "res", "json", "cfg", "csv", "tscn"]


## Sorted res:// paths of the source closure of `entries` (conservative).
static func closure(entries: Array) -> Array[String]:
	var classes: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		classes[str(entry["class"])] = str(entry.path)
	var literal := RegEx.create_from_string("res://[A-Za-z0-9_./\\-]+")
	var word := RegEx.create_from_string("\\b[A-Z][A-Za-z0-9_]*\\b")
	var seen: Dictionary = {"res://project.godot": true}
	var queue: Array = entries.duplicate()
	while not queue.is_empty():
		var path: String = queue.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		if not path.get_extension() in ["gd", "gdshader", "tres", "tscn", "cfg"]:
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if path.get_extension() == "gd":
			text = _code_of(text)
		for m: RegExMatch in literal.search_all(text):
			var found: String = m.get_string().trim_suffix(".")
			if FileAccess.file_exists(found):
				queue.append(found)
			elif DirAccess.dir_exists_absolute(found):
				var files: Array[String] = []
				_collect(found, files)
				queue.append_array(files)
		if path.get_extension() == "gd":
			var names: Dictionary = {}
			for m: RegExMatch in word.search_all(text):
				names[m.get_string()] = true
			for name: String in names:
				if classes.has(name):
					queue.append(classes[name])
	var out: Array[String] = []
	for path: String in seen:
		out.append(path)
	out.sort()
	return out


## Script text without comments (# outside string literals to line end), so
## names and paths in documentation do not join the closure.
static func _code_of(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var quote: String = ""
		var cut: int = line.length()
		var i: int = 0
		while i < line.length():
			var ch: String = line[i]
			if not quote.is_empty():
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut))
	return "\n".join(out)


static func _collect(directory: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.get_extension() in SOURCE_EXTENSIONS:
			paths.append(directory.path_join(file))
	for sub: String in dir.get_directories():
		_collect(directory.path_join(sub), paths)


## {digest, files} of a closure (path|sha lines).
static func closure_digest(entries: Array) -> Dictionary:
	var paths: Array[String] = closure(entries)
	var lines: String = ""
	for path: String in paths:
		lines += path + "|" + FileAccess.get_sha256(path) + "\n"
	return {"digest": lines.sha256_text(), "files": paths.size(), "paths": paths}


static func ground_key(seed_value: int, region: Vector2i, options: Dictionary) -> Dictionary:
	var source: Dictionary = closure_digest([GROUND_ENTRY])
	var settings := {"max_replans": int(options.get("max_replans", -1)), "stop_rule": str(options.get("stop_rule", "ROADS")),
		"natural_intents": bool(options.get("natural_intents", true))}
	var text: String = FORMAT + "\nground\n" + Bake.SCHEMA + "\n" + str(Engine.get_version_info()) + "\n%d\n%d,%d\n" % [seed_value, region.x, region.y] \
		+ JSON.stringify(settings, "", true) + "\n" + source.digest
	return {"key": text.sha256_text(), "files": source.files, "paths": source.paths}


static func trails_key(ground: String, trail_settings: Dictionary) -> Dictionary:
	var source: Dictionary = closure_digest([TRAILS_ENTRY])
	var text: String = FORMAT + "\ntrails\n" + ground + "\n" + JSON.stringify(trail_settings, "", true) + "\n" + source.digest
	return {"key": text.sha256_text(), "files": source.files, "paths": source.paths}


static func save_ground(key: String, seed_value: int, region: Vector2i, up: Dictionary, ground: Dictionary) -> Dictionary:
	var payload := {"format": FORMAT, "stage": "ground", "key": key, "seed": seed_value, "region": [region.x, region.y], "region_signature": up.plan.signature(),
		"hydrology_signature": up.hydro.plan.signature(), "network": ground.network.to_bytes(), "network_digest": ground.network.digest(), "slots": ground.slots, "meta": ground.meta}
	return _write(key, "ground", payload)


static func save_trails(key: String, ground_key_value: String, trailed: Dictionary) -> Dictionary:
	var refined_slots: Array = []
	for k: int in trailed.refined:
		refined_slots.append(trailed.slots[k])
	var payload := {"format": FORMAT, "stage": "trails", "key": key, "ground_key": ground_key_value, "network": trailed.network.to_bytes(), "network_digest": trailed.network.digest(),
		"refined": trailed.refined, "refined_slots": refined_slots, "surface_trails": trailed.surface_trails, "report": trailed.report}
	return _write(key, "trails", payload)


## Ground stage products as RegionBake.ground_stage returns them (without
## the graph / route plan objects), or {is_valid: false, reason_code}.
static func load_ground(key: String, seed_value: int, region: Vector2i, up: Dictionary) -> Dictionary:
	var payload: Variant = _read(key, "ground")
	if not payload is Dictionary:
		return {"is_valid": false, "reason_code": "ERR_STAGE_MISSING"}
	if payload.get("format") != FORMAT or payload.get("key") != key or int(payload.seed) != seed_value or Vector2i(int(payload.region[0]), int(payload.region[1])) != region:
		return {"is_valid": false, "reason_code": "ERR_STAGE_IDENTITY"}
	if payload.region_signature != up.plan.signature() or payload.hydrology_signature != up.hydro.plan.signature():
		return {"is_valid": false, "reason_code": "ERR_STAGE_UPSTREAM"}
	var network: Dictionary = Network.from_bytes(payload.network)
	if not network.is_valid or network.network.digest() != payload.network_digest:
		return {"is_valid": false, "reason_code": "ERR_STAGE_NETWORK"}
	if payload.slots.size() != Ground.TILES * Ground.TILES or not payload.slots.all(_slot_intact):
		return {"is_valid": false, "reason_code": "ERR_STAGE_TILES"}
	var surface: RefCounted = Ground.surface_of(up, network.network)
	if surface == null:
		return {"is_valid": false, "reason_code": "ERR_STAGE_SURFACE"}
	return {"is_valid": true, "reason_code": "", "network": network.network, "surface": surface, "slots": payload.slots, "meta": payload.meta}


## Trail stage products as RegionBake.trail_stage returns them, or
## {is_valid: false, reason_code}.
static func load_trails(key: String, ground_key_value: String, ground: Dictionary) -> Dictionary:
	var payload: Variant = _read(key, "trails")
	if not payload is Dictionary:
		return {"is_valid": false, "reason_code": "ERR_STAGE_MISSING"}
	if payload.get("format") != FORMAT or payload.get("key") != key or payload.get("ground_key") != ground_key_value:
		return {"is_valid": false, "reason_code": "ERR_STAGE_IDENTITY"}
	var network: Dictionary = Network.from_bytes(payload.network)
	if not network.is_valid or network.network.digest() != payload.network_digest:
		return {"is_valid": false, "reason_code": "ERR_STAGE_NETWORK"}
	if payload.refined.size() != payload.refined_slots.size() or not payload.refined_slots.all(_slot_intact):
		return {"is_valid": false, "reason_code": "ERR_STAGE_TILES"}
	var slots: Array = ground.slots.duplicate()
	for m in range(payload.refined.size()):
		slots[payload.refined[m]] = payload.refined_slots[m]
	var surface: RefCounted = ground.surface
	if not payload.surface_trails.is_empty():
		surface = surface.with_trails(payload.surface_trails).with_published(payload.refined_slots)
	return {"is_valid": true, "reason_code": "", "network": network.network, "surface": surface, "slots": slots, "report": payload.report, "surface_trails": payload.surface_trails,
		"refined": payload.refined}


## A slot whose content hash matches its arrays (RegionBakeGround.finish_slot).
static func _slot_intact(slot: Variant) -> bool:
	if not slot is Dictionary or not slot.get("is_valid", false) or not slot.has("arrays"):
		return false
	var bytes := PackedByteArray()
	bytes.append_array((slot.arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).to_byte_array())
	bytes.append_array((slot.arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).to_byte_array())
	bytes.append_array(slot.layers)
	return _sha(bytes) == slot.sha256


static func _path(key: String, stage: String) -> String:
	return STAGE_ROOT.path_join(stage).path_join(key + ".bin")


static func _write(key: String, stage: String, payload: Dictionary) -> Dictionary:
	var path: String = _path(key, stage)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var bytes: PackedByteArray = var_to_bytes(payload)
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {"is_valid": false, "reason_code": "ERR_STAGE_WRITE", "path": path}
	file.store_buffer(bytes)
	file.close()
	var sidecar := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	if sidecar == null:
		return {"is_valid": false, "reason_code": "ERR_STAGE_WRITE", "path": path}
	sidecar.store_string(_sha(bytes))
	sidecar.close()
	return {"is_valid": true, "reason_code": "", "path": path, "bytes": bytes.size()}


static func _read(key: String, stage: String) -> Variant:
	var path: String = _path(key, stage)
	if not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".sha256"):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if _sha(bytes) != FileAccess.get_file_as_string(path + ".sha256").strip_edges():
		return null
	return bytes_to_var(bytes)


static func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
