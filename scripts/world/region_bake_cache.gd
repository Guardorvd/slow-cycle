class_name RegionBakeCache
extends RefCounted

## PR1 D7 I/O adapter of RegionBake products: `user://regions/<key>/`, never
## committed. key = SHA-256 of the bake schema, engine version, seed, region,
## settings and a source closure digest (every script / resource the bake can
## reach plus project.godot, path + bytes). Any mismatch or damaged file reads
## as ERR_BAKE_STALE and the caller rebakes. Files: manifest.json, network.bin,
## tile_<i>.bin (one per tile), extras.bin (bridges, water, spawn); binary
## files are zstd-compressed var_to_bytes, each SHA-256 recorded in the
## manifest. The domain bake never touches files.

const Bake = preload("res://scripts/world/region/region_bake.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const ROOT := "user://regions"
const FORMAT := "slow_cycle.region_cache/1"


static func key(seed_value: int, region: Vector2i, settings: Dictionary = {}) -> String:
	var text: String = FORMAT + "\n" + Bake.SCHEMA + "\n" + str(Engine.get_version_info()) + "\n%d\n%d,%d\n" % [seed_value, region.x, region.y] + JSON.stringify(settings, "", true) + "\n" + source_digest()
	return text.sha256_text()


## Sorted path|sha lines of the bake's source closure (conservative superset).
static func source_digest() -> String:
	var paths: Array[String] = ["res://project.godot"]
	for directory: String in ["res://scripts/world", "res://scripts/core", "res://resources"]:
		_collect(directory, paths)
	paths.sort()
	var lines: String = ""
	for path: String in paths:
		lines += path + "|" + FileAccess.get_sha256(path) + "\n"
	return lines.sha256_text()


static func _collect(directory: String, paths: Array[String]) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.get_extension() in ["gd", "gdshader", "tres", "res", "json", "cfg", "csv"]:
			paths.append(directory.path_join(file))
	for sub: String in dir.get_directories():
		_collect(directory.path_join(sub), paths)


static func directory_of(cache_key: String) -> String:
	return ROOT.path_join(cache_key)


static func save(cache_key: String, baked: Dictionary) -> Dictionary:
	var dir: String = directory_of(cache_key)
	DirAccess.make_dir_recursive_absolute(dir)
	var files: Dictionary = {}
	var network_bytes: PackedByteArray = baked.network.to_bytes()
	var written: Dictionary = _write(dir.path_join("network.bin"), network_bytes)
	if not written.ok:
		return {"is_valid": false, "reason_code": "ERR_BAKE_WRITE"}
	files["network.bin"] = written.sha256
	for k in range(baked.tiles.size()):
		var slot: Dictionary = baked.tiles[k]
		var payload := {"tx": slot.tx, "tz": slot.tz, "arrays": slot.arrays, "layers": slot.layers, "patches": slot.patches, "origin": slot.origin, "coarse": slot.coarse,
			"sha256": slot.sha256, "vertex_count": slot.vertex_count, "triangle_count": slot.triangle_count}
		written = _write(dir.path_join("tile_%d.bin" % k), var_to_bytes(payload))
		if not written.ok:
			return {"is_valid": false, "reason_code": "ERR_BAKE_WRITE"}
		files["tile_%d.bin" % k] = written.sha256
	written = _write(dir.path_join("extras.bin"), var_to_bytes({"bridges": baked.bridges, "water": baked.water, "spawn": baked.spawn}))
	if not written.ok:
		return {"is_valid": false, "reason_code": "ERR_BAKE_WRITE"}
	files["extras.bin"] = written.sha256
	var manifest: Dictionary = baked.manifest.duplicate(true)
	manifest["cache_key"] = cache_key
	manifest["files"] = files
	var file := FileAccess.open(dir.path_join("manifest.json"), FileAccess.WRITE)
	if file == null:
		return {"is_valid": false, "reason_code": "ERR_BAKE_WRITE"}
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	return {"is_valid": true, "reason_code": "", "directory": dir}


static func _write(path: String, bytes: PackedByteArray) -> Dictionary:
	var file := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {"ok": false}
	file.store_buffer(bytes)
	file.close()
	return {"ok": true, "sha256": _sha(bytes)}


static func _read(path: String, expected: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if _sha(bytes) != expected:
		return null
	return bytes_to_var(bytes)


static func _sha(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Returns the bake products ({manifest, network, tiles, bridges, water, spawn})
## or {is_valid: false, reason_code: ERR_BAKE_STALE}.
static func load_products(cache_key: String) -> Dictionary:
	var stale := {"is_valid": false, "reason_code": "ERR_BAKE_STALE"}
	var dir: String = directory_of(cache_key)
	if not FileAccess.file_exists(dir.path_join("manifest.json")):
		return stale
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("manifest.json")))
	if not manifest is Dictionary or manifest.get("cache_key", "") != cache_key or manifest.get("schema", "") != Bake.SCHEMA:
		return stale
	var files: Dictionary = manifest.get("files", {})
	var network_bytes: Variant = null
	if files.has("network.bin") and FileAccess.file_exists(dir.path_join("network.bin")):
		var file := FileAccess.open_compressed(dir.path_join("network.bin"), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if file != null:
			network_bytes = file.get_buffer(file.get_length())
			file.close()
	if not network_bytes is PackedByteArray or _sha(network_bytes) != files["network.bin"]:
		return stale
	var network: Dictionary = Network.from_bytes(network_bytes)
	if not network.is_valid or network.network.digest() != manifest.network_digest:
		return stale
	var tiles: Array = []
	for k in range(Bake.TILES * Bake.TILES):
		var tile: Variant = _read(dir.path_join("tile_%d.bin" % k), files.get("tile_%d.bin" % k, ""))
		if not tile is Dictionary:
			return stale
		tiles.append(tile)
	var extras: Variant = _read(dir.path_join("extras.bin"), files.get("extras.bin", ""))
	if not extras is Dictionary:
		return stale
	return {"is_valid": true, "reason_code": "", "manifest": manifest, "network": network.network, "tiles": tiles, "bridges": extras.bridges, "water": extras.water, "spawn": extras.spawn}
