extends SceneTree

## BC1 trail entry (additive; real production code, existing bot helper).
##   --group=integration  fresh prototype-off bake (baseline identity, cache
##                        saved), fresh bake with the trail configuration
##                        (publication, shape equality against the off tiles,
##                        seams, layers, final queries, vegetation clearance,
##                        cache reload equality), stale cache, cache identity,
##                        atomic rejection
##   --group=domain       realization contract and negatives on the cached
##                        prototype-off products (run integration first)
##   --group=runtime      region scene with the trail (cached): Input rides
##                        road -> trail -> road both ways, P2 rays, recovery,
##                        bicycle-camera views (needs Vulkan, not --headless)
##   --seed=N (184729)  --config=res://... (bc1_trail_184729.json)  --out=DIR
## Output: BC1_CHECK lines for failures, DIR/bc1_trail_<group>.json, and
## BC1_SUMMARY group=.. checks=.. failures=.. completed=true.
const Bake = preload("res://scripts/world/region/region_bake.gd")
const Cache = preload("res://scripts/world/region_bake_cache.gd")
const Trail = preload("res://scripts/world/region/trail_realization.gd")
const Network = preload("res://scripts/world/region/realized_road_network.gd")
const Vegetation = preload("res://scripts/world/region/region_vegetation_planner.gd")
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Deformer = preload("res://scripts/world/region/road_terrain_deformer.gd")
const Surface = preload("res://scripts/world/region/final_surface.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")
const Bot = preload("res://scripts/test/region_ride_bot.gd")
const WorldScene = preload("res://scenes/region/region_world.tscn")
## Prototype-off baseline of 184729 (0,0) (PR1 record, m9_bake_184729; BC1 M0).
const BASE_TILES := "c94451cf56f26326743d1ce5acd01bd465c50c7f23dbc42843959caca569d84e"
const BASE_NETWORK := "183eef0c8d205747287eec3f18dc24d2bde5e8fb52cca6c349c3f4cfa7466fbc"
const BASE_VEGETATION := "35212949edb612ba1118d9e1765144b959550e8b35b45248bea5fe3c56d2aa4e"
## Tolerances: new vertices on the off triangles (float32 at region scale);
## band-edge layer probes closer than EDGE_TOLERANCE_M to a band edge are
## decided by float32 rounding of the clip vertices and are only counted.
const SHAPE_TOLERANCE_M: float = 0.001
const EDGE_TOLERANCE_M: float = 0.001
const P2_GROUND_M: float = 0.05
## Trail mouth: band edges may still lie on the joined road plane this far
## past a join's leave station (oblique exit of a 1.3 m band).
const MOUTH_M: float = 2.0

var _checks: int = 0
var _failures: Array = []
var _out: String = ""
var _group: String = ""
var _seed: int = 184729
var _config_path: String = "res://resources/regions/bc1_trail_184729.json"


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String, detail: Variant = "") -> void:
	_checks += 1
	if not ok:
		_failures.append({"check": label, "detail": str(detail).substr(0, 2000)})
		print("BC1_CHECK FAIL ", label, " ", str(detail).substr(0, 400))


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6).replace("\\", "/")
		elif arg.begins_with("--group="):
			_group = arg.substr(8)
		elif arg.begins_with("--seed="):
			_seed = arg.substr(7).to_int()
		elif arg.begins_with("--config="):
			_config_path = arg.substr(9)
		elif arg.begins_with("--trail-config=") or arg.begins_with("--region="):
			pass
		else:
			_group = "!invalid"
	if _out.is_empty() or not _group in ["integration", "domain", "runtime"]:
		print("BC1_CHECK FAIL ERR_BC1_CLI")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var t0: int = Time.get_ticks_usec()
	var report: Dictionary = {"group": _group, "seed": _seed, "config": _config_path, "config_sha256": FileAccess.get_sha256(_config_path)}
	if _group == "integration":
		report.merge(Synth.off_main_thread(_integration))
	elif _group == "domain":
		report.merge(Synth.off_main_thread(_domain))
	else:
		report.merge(await _runtime())
	report.merge({"checks": _checks, "failures": _failures, "duration_s": (Time.get_ticks_usec() - t0) / 1e6,
		"controller_sha256": FileAccess.get_sha256("res://scripts/player/bicycle_controller.gd"), "engine": Engine.get_version_info()})
	DirAccess.make_dir_recursive_absolute(_out)
	var file := FileAccess.open(_out.path_join("bc1_trail_%s.json" % _group), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BC1_SUMMARY group=%s checks=%d failures=%d completed=true" % [_group, _checks, _failures.size()])
	quit(0 if _failures.is_empty() else 1)


func _config() -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(_config_path))


# --- integration ---

func _integration() -> Dictionary:
	var out: Dictionary = {}
	var t: int = Time.get_ticks_usec()
	var off: Dictionary = Bake.bake(_seed, Vector2i.ZERO, {"threads": 8})
	out["off_bake_s"] = (Time.get_ticks_usec() - t) / 1e6
	_check(off.is_valid, "off bake valid", off.get("reason_code"))
	if not off.is_valid:
		return out
	_check(off.manifest.tiles_digest == BASE_TILES, "off tiles equal the baseline", off.manifest.tiles_digest)
	_check(off.manifest.network_digest == BASE_NETWORK, "off network equals the baseline", off.manifest.network_digest)
	_check(off.manifest.vegetation.digest == BASE_VEGETATION, "off vegetation equals the baseline", off.manifest.vegetation.digest)
	_check(not off.manifest.has("trails") and off.network.get_trails().is_empty(), "off has no trails", off.manifest.keys())
	var off_key: String = Cache.key(_seed, Vector2i.ZERO, {})
	_check(Cache.save(off_key, off).is_valid, "off cache saved")
	t = Time.get_ticks_usec()
	var on: Dictionary = Bake.bake(_seed, Vector2i.ZERO, {"threads": 8, "trail_config": _config()})
	out["on_bake_s"] = (Time.get_ticks_usec() - t) / 1e6
	_check(on.is_valid, "on bake valid", on.get("reason_code"))
	if not on.is_valid:
		return out
	var trails: Dictionary = on.manifest.get("trails", {})
	out["trails"] = trails
	out["timings_s"] = on.manifest.timings_s
	_check(trails.get("published", []).size() == 1 and trails.get("rejected", []).is_empty(), "trail published, none rejected", trails)
	var published: Array = on.network.get_trails()
	_check(published.size() == 1 and published[0].mode == "NATURAL", "network carries one NATURAL trail", published.size())
	if published.size() != 1:
		return out
	var trail: Dictionary = published[0]
	_network_checks(off, on, trail)
	out["tiles"] = _tile_checks(off, on, trail)
	out["vegetation"] = _vegetation_checks(off, on, trail)
	out["final_queries"] = _query_checks(on, trail)
	out["cost"] = {"vertices": [off.manifest.vertices, on.manifest.vertices], "triangles": [off.manifest.triangles, on.manifest.triangles]}
	# Cache: save and reload equal products; stale and identity.
	var on_key: String = Cache.key(_seed, Vector2i.ZERO, Cache.trail_settings(_config_path))
	_check(on_key != off_key, "on and off cache keys differ")
	_check(Cache.save(on_key, on).is_valid, "on cache saved")
	for pair: Array in [[off_key, off, "off"], [on_key, on, "on"]]:
		var loaded: Dictionary = Cache.load_products(pair[0])
		_check(loaded.is_valid, "cache reload " + pair[2], loaded.get("reason_code"))
		if loaded.is_valid:
			_check(loaded.network.digest() == pair[1].network.digest() and loaded.manifest.tiles_digest == pair[1].manifest.tiles_digest, "cache reload equals fresh network/tiles " + pair[2])
			var equal: bool = true
			for k in range(loaded.tiles.size()):
				equal = equal and loaded.tiles[k].sha256 == pair[1].tiles[k].sha256 and loaded.tiles[k].layers == pair[1].tiles[k].layers
			_check(equal, "cache reload equals fresh layers " + pair[2])
			_check(Bake._vegetation_summary(loaded.vegetation).digest == pair[1].manifest.vegetation.digest, "cache reload equals fresh vegetation " + pair[2])
			_check(loaded.network.get_trails().size() == (1 if pair[2] == "on" else 0), "cache reload trails " + pair[2])
	_stale_checks(on)
	_identity_checks(off_key, on_key)
	# Atomic rejection inside the bake step: an invalid trail leaves the
	# prototype-off products.
	var bad: Dictionary = _config().duplicate(true)
	bad.trails[0].control_points[3] = [2208.0, 2960.0]
	var made: Dictionary = Bake._trails(bad, _seed, Vector2i.ZERO, off.network, off.surface, off.field, off.terrain.get_bounds_m(), off.tiles, 8)
	_check(made.report.published.is_empty() and made.report.rejected.size() == 1, "rejected trail is not published", made.report)
	_check(made.network.digest() == BASE_NETWORK and made.slots == off.tiles and made.surface == off.surface, "rejection keeps the prototype-off products")
	return out


## The on network is the off network plus the trail and nothing else.
func _network_checks(off: Dictionary, on: Dictionary, trail: Dictionary) -> void:
	var data: Dictionary = on.network.get_data()
	_check(data.schema == Network.SCHEMA_TRAILS, "trail network schema", data.schema)
	var stripped: Dictionary = data.duplicate(true)
	stripped.erase("trails")
	stripped.schema = Network.SCHEMA
	stripped.header.schema = Network.SCHEMA
	stripped.metrics.erase("trails")
	for node: Dictionary in stripped.nodes:
		node.erase("trails")
	_check(stripped == off.network.get_data(), "roads unchanged by the trail (pieces, edges, movements, nodes, metrics)")
	var nodes: Dictionary = {}
	for node: Dictionary in data.nodes:
		nodes[node.id] = node
	var joined: bool = true
	for k in range(2):
		var join: Dictionary = trail.joins[k]
		joined = joined and join.node == trail.nodes[k] and nodes[join.node].get("trails", []).has(trail.id)
		var piece_ok: bool = false
		for e: Dictionary in data.edges:
			piece_ok = piece_ok or (e.piece_id == join.piece and (e.a == join.node or e.b == join.node))
		joined = joined and piece_ok
	_check(joined, "both ends joined on pieces of their nodes", trail.joins)
	_check(trail.directions == ["FORWARD", "REVERSE"], "trail rideable both ways (declared limits)", trail.directions)
	_check(trail.metrics.design_parity_max_m >= 0.0 and trail.metrics.max_grade <= Trail.Policy.grade_hard(Trail.TRAIL_CLASS), "metrics recorded", trail.metrics)


## Changed tiles only near the band; their new vertices on the off triangles;
## off vertices kept; seams with every neighbour; band layer and queries.
func _tile_checks(off: Dictionary, on: Dictionary, trail: Dictionary) -> Dictionary:
	var out: Dictionary = {"changed": [], "per_tile": []}
	var surface: RefCounted = on.surface
	var bounds: Dictionary = on.terrain.get_bounds_m()
	var changed: Array = []
	for k in range(on.tiles.size()):
		if on.tiles[k].sha256 != off.tiles[k].sha256:
			changed.append(k)
			out.changed.append([on.tiles[k].tx, on.tiles[k].tz])
	_check(not changed.is_empty() and changed.size() <= 4, "only the trail tiles change", out.changed)
	var listed: Array = on.manifest.trails.published[0].tiles
	for k: int in changed:
		_check([on.tiles[k].tx, on.tiles[k].tz] in listed, "changed tile listed by the trail report", [on.tiles[k].tx, on.tiles[k].tz])
	for k: int in changed:
		var base: Dictionary = off.tiles[k]
		var tile: Dictionary = on.tiles[k]
		var bv: PackedVector3Array = base.arrays[Mesh.ARRAY_VERTEX]
		var tv: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
		var ti: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
		var kept: Dictionary = {}
		for v: Vector3 in tv:
			kept[v] = true
		var missing: int = 0
		var base_set: Dictionary = {}
		for v: Vector3 in bv:
			base_set[v] = true
			missing += 0 if kept.has(v) else 1
		var grid: Dictionary = _grid(base)
		var max_dy: float = 0.0
		var misses: int = 0
		for v: Vector3 in tv:
			if base_set.has(v):
				continue
			var h: float = _mesh_height(base, grid, Vector2(v.x, v.z))
			if is_nan(h):
				misses += 1
			else:
				max_dy = maxf(max_dy, absf(h - v.y))
		var layers: PackedByteArray = tile.layers
		var origin := Vector2(tile.origin[0] + bounds.min_x, tile.origin[1] + bounds.min_z)
		var rough: int = 0
		var probes: int = 0
		var at_edge: int = 0
		var disagree: Array = []
		for q in range(ti.size() / 3):
			var a: Vector3 = tv[ti[3 * q]]
			var b: Vector3 = tv[ti[3 * q + 1]]
			var c: Vector3 = tv[ti[3 * q + 2]]
			var centre: Vector3 = (a + b + c) / 3.0
			if surface.trail_near(origin.x + centre.x, origin.y + centre.z, 2.0).is_empty():
				continue
			rough += 1 if layers[q] == Bake.LAYER_ROUGH else 0
			for w: Vector3 in [Vector3(0.6, 0.2, 0.2), Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6)]:
				var p: Vector3 = a * w.x + b * w.y + c * w.z
				var x: float = origin.x + p.x
				var z: float = origin.y + p.z
				if not surface.road_owner(x, z).is_empty():
					continue
				probes += 1
				var near: Dictionary = surface.trail_near(x, z, 2.0)
				var expect: int = Bake.LAYER_ROUGH if not surface.trail_owner(x, z).is_empty() else Bake.LAYER_TERRAIN
				if layers[q] != expect:
					if not near.is_empty() and absf(near.distance - near.half_width) <= EDGE_TOLERANCE_M:
						at_edge += 1
					elif disagree.size() < 8:
						disagree.append([x, z, layers[q], expect])
		var row := {"tile": [tile.tx, tile.tz], "vertices": [bv.size(), tv.size()], "triangles": [base.arrays[Mesh.ARRAY_INDEX].size() / 3, ti.size() / 3],
			"off_vertices_missing": missing, "new_vertex_max_dy_m": max_dy, "location_misses": misses, "rough_triangles": rough, "layer_probes": probes,
			"edge_rounding": at_edge, "layer_disagreements": disagree}
		out.per_tile.append(row)
		_check(missing == 0, "off vertices kept " + str(row.tile), missing)
		_check(misses == 0 and max_dy <= SHAPE_TOLERANCE_M, "new vertices on the off triangles " + str(row.tile), row)
		_check(disagree.is_empty(), "band layer agrees with the material query " + str(row.tile), disagree)
	_check(out.per_tile.reduce(func(sum: int, row: Dictionary) -> int: return sum + row.rough_triangles, 0) > 0, "band triangles on the rough layer")
	# Seams: border vertex sets of every changed tile and each neighbour.
	var seams: Array = []
	var by_tile: Dictionary = {}
	for k in range(on.tiles.size()):
		by_tile[Vector2i(on.tiles[k].tx, on.tiles[k].tz)] = on.tiles[k]
	for k: int in changed:
		var tile: Dictionary = on.tiles[k]
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other: Variant = by_tile.get(Vector2i(tile.tx, tile.tz) + d)
			if other == null:
				continue
			var mine: Dictionary = _border_set(tile, d)
			var theirs: Dictionary = _border_set(other, -d)
			var equal: bool = mine.size() == theirs.size()
			for key: Vector3 in mine:
				equal = equal and theirs.has(key)
			seams.append([[tile.tx, tile.tz], [other.tx, other.tz], mine.size(), equal])
			_check(equal, "seam %s|%s" % [str([tile.tx, tile.tz]), str([other.tx, other.tz])], [mine.size(), theirs.size()])
	out["seams"] = seams
	return out


## Vegetation unchanged outside the trail tiles; no collider in the band.
func _vegetation_checks(off: Dictionary, on: Dictionary, trail: Dictionary) -> Dictionary:
	var changed: Array = []
	for k in range(on.vegetation.size()):
		if on.vegetation[k] != off.vegetation[k]:
			changed.append([on.tiles[k].tx, on.tiles[k].tz])
	var listed: Array = on.manifest.trails.published[0].tiles
	var outside: bool = true
	for tile: Array in changed:
		outside = outside and tile in listed
	_check(outside, "vegetation changes only in the trail tiles", changed)
	var closest: float = INF
	var inside: int = 0
	var line: Dictionary = trail.line
	for tile: Dictionary in on.vegetation:
		for kind: String in Vegetation.KINDS:
			var values: PackedFloat32Array = tile[kind]
			var radius_1: float = Vegetation.TRUNK_RADIUS.get(kind, 0.0)
			for q in range(values.size() / 5):
				var p := Vector2(values[5 * q], values[5 * q + 2])
				if p.x < line.x[0] - 60.0 and p.x < line.x[line.s.size() - 1] - 60.0:
					continue
				var d: float = _line_distance(line, p) - trail.half_width_m - radius_1 * values[5 * q + 4]
				closest = minf(closest, d)
				inside += 1 if d < 0.0 else 0
	_check(inside == 0, "no vegetation collider or instance inside the band", inside)
	return {"changed_tiles": changed, "closest_clearance_m": closest}


## Final queries along the band agree with the published triangles.
func _query_checks(on: Dictionary, trail: Dictionary) -> Dictionary:
	var bounds: Dictionary = on.terrain.get_bounds_m()
	var grids: Dictionary = {}
	var worst: float = 0.0
	var misses: int = 0
	var kinds: Dictionary = {}
	var line: Dictionary = trail.line
	for k in range(line.s.size()):
		var normal := Vector2(-line.tz[k], line.tx[k])
		for side: float in [-0.9, 0.0, 0.9]:
			var p: Vector2 = Vector2(line.x[k], line.z[k]) + normal * side * trail.half_width_m
			var mesh: float = _region_height(on.tiles, grids, p)
			var q: Dictionary = on.surface.sample_surface(bounds.min_x + p.x, bounds.min_z + p.y)
			if is_nan(mesh) or not q.is_valid:
				misses += 1
				continue
			worst = maxf(worst, absf(mesh - q.height_m))
			kinds[q.kind] = kinds.get(q.kind, 0) + 1
	_check(misses == 0 and worst <= 0.001, "final queries equal the published triangles on the band", [misses, worst])
	_check(kinds.get("TRAIL", 0) > 0 and not kinds.has("TERRAIN"), "band points query as TRAIL (or ROAD at the joins)", kinds)
	return {"max_abs_m": worst, "kinds": kinds}


func _stale_checks(on: Dictionary) -> void:
	var key: String = "bc1_test_stale_%d" % Time.get_ticks_usec()
	_check(Cache.save(key, on).is_valid, "stale fixture saved")
	var dir: String = Cache.directory_of(key)
	var file := FileAccess.open_compressed(dir.path_join("tile_0.bin"), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file.close()
	_check(Cache.load_products(key).reason_code == "ERR_BAKE_STALE", "corrupt tile reads as ERR_BAKE_STALE")
	_check(Cache.load_products(key + "_absent").reason_code == "ERR_BAKE_STALE", "absent cache reads as ERR_BAKE_STALE")
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _identity_checks(off_key: String, on_key: String) -> void:
	var copy: String = "user://bc1_identity_config.json"
	var text: String = FileAccess.get_file_as_string(_config_path)
	var file := FileAccess.open(copy, FileAccess.WRITE)
	file.store_string(text.replace("2455.0", "2455.5"))
	file.close()
	var settings: Dictionary = Cache.trail_settings(copy)
	settings.trail_config = _config_path
	_check(Cache.key(_seed, Vector2i.ZERO, settings) != on_key, "changed trail content changes the cache key")
	_check(Cache.key(_seed + 1, Vector2i.ZERO, Cache.trail_settings(_config_path)) != on_key, "seed is part of the trail cache key")
	DirAccess.remove_absolute(copy)


# --- domain ---

func _domain() -> Dictionary:
	var loaded: Dictionary = Cache.load_products(Cache.key(_seed, Vector2i.ZERO, {}))
	_check(loaded.is_valid, "prototype-off cache present (run --group=integration first)", loaded.get("reason_code"))
	if not loaded.is_valid:
		return {}
	var plan: RefCounted = Gen.build(_seed, Vector2i.ZERO)
	var terrain: RefCounted = Terrain.create(plan).field
	var hydro: Dictionary = HGen.build(plan, terrain)
	var field: RefCounted = HField.create(hydro.plan, terrain).field
	var surface: RefCounted = Surface.create(terrain, field, Deformer.create(loaded.network, field).deformer).surface
	var context := {"seed": _seed, "region": Vector2i.ZERO, "network": loaded.network.get_data(), "surface": surface, "field": field}
	var good: Dictionary = Trail.realize_all(_config(), context)
	_check(good.trails.size() == 1 and good.rejected.is_empty(), "configured trail realizes", good.rejected)
	var again: Dictionary = Trail.realize_all(_config(), context)
	_check(not good.trails.is_empty() and not again.trails.is_empty() and good.trails[0] == again.trails[0], "realization is deterministic")
	var out: Dictionary = {"metrics": good.trails[0].metrics if not good.trails.is_empty() else {}, "negatives": []}
	var cases: Array = [
		["schema", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.schema = "other"],
		["id", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.trails[0].id = "meadow"],
		["mode", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.trails[0].mode = "PAVED"],
		["nonfinite point", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.trails[0].control_points[4] = [NAN, 2990.0]],
		["out of bounds", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.trails[0].control_points[4] = [2348.0, 4090.0]],
		["half width", "ERR_TRAIL_INPUT", func(c: Dictionary) -> void: c.trails[0].half_width_m = 3.0],
		["seed", "ERR_TRAIL_IDENTITY", func(c: Dictionary) -> void: c.seed = 2024],
		["region", "ERR_TRAIL_IDENTITY", func(c: Dictionary) -> void: c.region = [1, 0]],
		["node moved", "ERR_TRAIL_IDENTITY", func(c: Dictionary) -> void: c.trails[0].nodes[1].x_m = 2534.0],
		["start off road", "ERR_TRAIL_CONNECTION", func(c: Dictionary) -> void: c.trails[0].control_points.pop_front()],
		["end on a foreign piece", "ERR_TRAIL_CONNECTION", func(c: Dictionary) -> void: c.trails[0].nodes[1] = {"id": 8, "x_m": 2976.0, "z_m": 3296.0}],
		# Floodplain north of the valley road to the river's south bank (gentle
		# dry approach, M0 mask), back to the same road near junction 4.
		["water", "ERR_TRAIL_UNRIDEABLE", func(c: Dictionary) -> void: c.trails[0].control_points = [[2300.4, 2840.6], [2330.0, 2832.0], [2380.0, 2838.0], [2440.0, 2852.0],
			[2490.0, 2862.0], [2515.0, 2866.0], [2522.0, 2895.0], [2500.0, 2930.0]]],
		["radius", "ERR_TRAIL_UNRIDEABLE", func(c: Dictionary) -> void: c.trails[0].control_points.insert(5, [2330.0, 3005.0])],
	]
	for case: Array in cases:
		var config: Dictionary = _config().duplicate(true)
		case[2].call(config)
		var made: Dictionary = Trail.realize_all(config, context)
		var reason: String = made.rejected[0].reason_code if made.rejected.size() == 1 else "NONE"
		out.negatives.append({"case": case[0], "expected": case[1], "reason": reason, "detail": made.rejected[0].detail if made.rejected.size() == 1 else {}})
		_check(made.trails.is_empty() and reason == case[1], "negative %s -> %s" % [case[0], case[1]], [reason, made.rejected])
	var water: Dictionary = out.negatives[11].detail
	_check(water.get("stage", "") == "water", "water negative stops at water", water)
	_check(Trail.realize_all("not json", context).rejected[0].reason_code == "ERR_TRAIL_INPUT", "unparsable configuration -> ERR_TRAIL_INPUT")
	return out


# --- runtime ---

func _runtime() -> Dictionary:
	var out: Dictionary = {}
	var scene: Node3D = WorldScene.instantiate()
	root.add_child(scene)
	var t0: int = Time.get_ticks_usec()
	while not scene.is_ready_to_ride() and not scene.failed and (Time.get_ticks_usec() - t0) / 1e6 < 1500.0:
		await process_frame
	_check(scene.is_ready_to_ride(), "region scene ready with the trail", [scene.source, scene.failure.get("reason_code", "")])
	if not scene.is_ready_to_ride():
		return out
	out["source"] = scene.source
	out["load_seconds"] = scene.load_seconds
	var data: Dictionary = scene.products.network.get_data()
	var trails: Array = data.get("trails", [])
	_check(trails.size() == 1, "scene products carry the trail", trails.size())
	if trails.size() != 1:
		return out
	var trail: Dictionary = trails[0]
	var designs: Dictionary = {}
	for piece: Dictionary in data.pieces:
		designs[piece.id] = piece.design
	var path: Dictionary = _ride_path(trail, designs)
	out["path_m"] = Bot.polyline_length(path.points)
	var captures: bool = DisplayServer.get_name() != "headless"
	for direction: String in ["forward", "reverse"]:
		var points: PackedVector3Array = path.points.duplicate()
		var window: Vector2 = path.trail_window
		if direction == "reverse":
			points.reverse()
			var total: float = Bot.polyline_length(points)
			window = Vector2(total - path.trail_window.y, total - path.trail_window.x)
		var run: Dictionary = await _ride(scene, points, window, direction, captures and direction == "forward", trail)
		out[direction] = run
		_check(run.finished, "ride finished " + direction, run)
		_check(run.stalls == 0, "no stalls " + direction, run.stall_at)
		_check(not run.off_path and run.trail_max_lateral_m <= trail.half_width_m + 0.35, "stays on the trail " + direction, run.trail_max_lateral_m)
		_check(run.trail_rough_share >= 0.9, "trail collider under wheels " + direction, run.trail_rough_share)
		_check(run.trail_ungrounded_share <= 0.05, "wheels grounded on the trail " + direction, run.trail_ungrounded_share)
	_check(scene.water_recoveries == 0, "no deep-water recovery", scene.water_recoveries)
	# Rays and recovery query the loaded collision around a probe the streamer
	# tracks instead of the parked bicycle (its own load/free lifecycle).
	var probe := Node3D.new()
	scene.add_child(probe)
	var bike_node: Node3D = scene.streamer.tracked
	scene.streamer.tracked = probe
	out["p2"] = await _rays(scene, trail, probe)
	out["recovery"] = await _recovery(scene, trail, probe)
	scene.streamer.tracked = bike_node
	out["streamer"] = scene.streamer.stats.duplicate()
	scene.queue_free()
	await process_frame
	return out


## Road -> trail -> road: 60 m of the first join's edge towards the join, the
## trail, 50 m of the second join's edge away from the second node.
func _ride_path(trail: Dictionary, designs: Dictionary) -> Dictionary:
	var points := PackedVector3Array()
	var a: Dictionary = designs[trail.joins[0].piece]
	var sa: float = _station(a, Vector2(trail.joins[0].x_m, trail.joins[0].z_m))
	var node_at_end: bool = Vector2(a.x[a.s.size() - 1], a.z[a.s.size() - 1]).distance_to(Vector2(trail.joins[0].x_m, trail.joins[0].z_m)) < Vector2(a.x[0], a.z[0]).distance_to(Vector2(trail.joins[0].x_m, trail.joins[0].z_m))
	# Approach from the first node's side.
	_append_span(points, a, sa + 60.0 if node_at_end else sa - 60.0, sa)
	var start: float = Bot.polyline_length(points)
	var line: Dictionary = trail.line
	for k in range(line.s.size()):
		var p := Vector3(line.x[k], line.y[k], line.z[k])
		if points.is_empty() or points[points.size() - 1].distance_to(p) > 0.05:
			points.append(p)
	var end: float = Bot.polyline_length(points)
	var b: Dictionary = designs[trail.joins[1].piece]
	var sb: float = _station(b, Vector2(trail.joins[1].x_m, trail.joins[1].z_m))
	var node_b_at_start: bool = Vector2(b.x[0], b.z[0]).distance_to(Vector2(trail.joins[1].x_m, trail.joins[1].z_m)) < Vector2(b.x[b.s.size() - 1], b.z[b.s.size() - 1]).distance_to(Vector2(trail.joins[1].x_m, trail.joins[1].z_m))
	_append_span(points, b, sb, sb + 50.0 if node_b_at_start else sb - 50.0)
	return {"points": points, "trail_window": Vector2(start + trail.joins[0].leave_s_m, start + trail.joins[1].leave_s_m)}


func _station(d: Dictionary, p: Vector2) -> float:
	var best: float = INF
	var s: float = 0.0
	for k in range(d.s.size()):
		var dist: float = Vector2(d.x[k], d.z[k]).distance_to(p)
		if dist < best:
			best = dist
			s = d.s[k]
	return s


func _append_span(points: PackedVector3Array, d: Dictionary, from_s: float, to_s: float) -> void:
	var lo: float = clampf(minf(from_s, to_s), 0.0, d.s[d.s.size() - 1])
	var hi: float = clampf(maxf(from_s, to_s), 0.0, d.s[d.s.size() - 1])
	var picked: Array = []
	for k in range(d.s.size()):
		if d.s[k] >= lo and d.s[k] <= hi:
			picked.append(Vector3(d.x[k], d.y[k], d.z[k]))
	if from_s > to_s:
		picked.reverse()
	for p: Vector3 in picked:
		if points.is_empty() or points[points.size() - 1].distance_to(p) > 0.05:
			points.append(p)


func _ride(scene: Node3D, points: PackedVector3Array, window: Vector2, label: String, capture: bool, trail: Dictionary) -> Dictionary:
	var bike: BicycleController = scene.get_bike()
	scene.streamer.ensure_around(points[0])
	scene.spawn_bike(points[0], points[1] - points[0])
	for i in range(30):
		await physics_frame
	var bot: RefCounted = Bot.new().setup(points, 6.0)
	var frames: int = 0
	var trail_frames: int = 0
	var rough_frames: int = 0
	var ungrounded: int = 0
	var max_lateral: float = 0.0
	var shots: Array = []
	var targets: Array = [["join_a", window.x + 6.0], ["middle", (window.x + window.y) * 0.5], ["tile_border", -1.0], ["join_b", window.y - 6.0]]
	var border_s: float = -1.0
	for k in range(trail.line.s.size() - 1):
		if floorf(trail.line.z[k] / 512.0) != floorf(trail.line.z[k + 1] / 512.0) or floorf(trail.line.x[k] / 512.0) != floorf(trail.line.x[k + 1] / 512.0):
			border_s = window.x - trail.joins[0].leave_s_m + trail.line.s[k]
	targets[2][1] = border_s
	var max_frames: int = int(60.0 * (60.0 + bot.total_m / 2.0))
	while frames < max_frames and not bot.stats.finished:
		bot.step(bike)
		await physics_frame
		frames += 1
		if bot.s_now > window.x + 3.0 and bot.s_now < window.y - 3.0:
			trail_frames += 1
			max_lateral = maxf(max_lateral, _line_distance(trail.line, Vector2(bike.global_position.x, bike.global_position.z)))
			var rough: bool = true
			for ray: RayCast3D in [bike.front_ray, bike.rear_ray]:
				var collider: Object = ray.get_collider() if ray.is_colliding() else null
				rough = rough and collider is CollisionObject3D and (collider.collision_layer & 16) != 0
			rough_frames += 1 if rough else 0
			ungrounded += 0 if bike.is_grounded else 1
		if capture:
			for target: Array in targets:
				if target[1] > 0.0 and bot.s_now >= target[1] and not shots.has(target[0]):
					shots.append(target[0])
					await process_frame
					var image: Image = root.get_viewport().get_texture().get_image()
					var file: String = _out.path_join("bc1_view_%s.png" % target[0])
					image.save_png(file)
					var back := Image.load_from_file(file)
					var spread: float = 0.0
					if back != null and not back.is_empty():
						var c0: Color = back.get_pixel(back.get_width() / 2, back.get_height() / 3)
						var c1: Color = back.get_pixel(back.get_width() / 2, back.get_height() * 4 / 5)
						spread = absf(c0.get_luminance() - c1.get_luminance())
					_check(back != null and not back.is_empty() and back.get_width() > 100, "view saved and read " + target[0], file)
					print("BC1_VIEW ", target[0], " s=", snappedf(bot.s_now, 0.1), " pos=", bike.global_position, " file=", file, " spread=", spread)
	bot.release_inputs()
	var summary: Dictionary = bot.summary()
	summary["label"] = label
	summary["frames"] = frames
	summary["trail_frames"] = trail_frames
	summary["trail_max_lateral_m"] = max_lateral
	summary["trail_rough_share"] = float(rough_frames) / maxi(trail_frames, 1)
	summary["trail_ungrounded_share"] = float(ungrounded) / maxi(trail_frames, 1)
	summary["views"] = shots
	if capture:
		_check(shots.size() == 4, "four views (joins, middle, tile border)", shots)
	for i in range(60):
		await physics_frame
	return summary


## P2 rays on the loaded collision: centre and both band edges every metre.
func _rays(scene: Node3D, trail: Dictionary, probe: Node3D) -> Dictionary:
	var line: Dictionary = trail.line
	var grids: Dictionary = {}
	var misses: int = 0
	var worst: float = 0.0
	var not_rough: int = 0
	var not_rough_at: Array = []
	var count: int = 0
	for k in range(line.s.size()):
		if k % 50 == 0:
			probe.global_position = Vector3(line.x[k], line.y[k], line.z[k])
			scene.streamer.ensure_around(probe.global_position)
			await physics_frame
			await physics_frame
		var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
		var normal := Vector2(-line.tz[k], line.tx[k])
		for side: float in [-0.9, 0.0, 0.9]:
			var p: Vector2 = Vector2(line.x[k], line.z[k]) + normal * side * trail.half_width_m
			var expected: float = line.y[k] if side == 0.0 else _region_height(scene.products.tiles, grids, p)
			var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, expected + 5.0, p.y), Vector3(p.x, expected - 5.0, p.y), 2 | 4 | 16)
			var hit: Dictionary = space.intersect_ray(query)
			count += 1
			if hit.is_empty():
				misses += 1
				continue
			worst = maxf(worst, absf(hit.position.y - expected))
			# The trail mouth (within MOUTH_M of a join's leave station) is shared
			# with the road plane its band edge leaves obliquely: road or trail
			# there, never grass; the rough trail layer everywhere else.
			var mouth: bool = line.s[k] < trail.joins[0].leave_s_m + MOUTH_M or line.s[k] > trail.joins[1].leave_s_m - MOUTH_M
			if mouth and (hit.collider.collision_layer & 2) == 0:
				not_rough += 1
				not_rough_at.append([snappedf(line.s[k], 0.1), side, snappedf(p.x, 0.01), snappedf(p.y, 0.01), hit.collider.collision_layer])
			elif not mouth and (hit.collider.collision_layer & 16) == 0:
				not_rough += 1
				not_rough_at.append([snappedf(line.s[k], 0.1), side, snappedf(p.x, 0.01), snappedf(p.y, 0.01), hit.collider.collision_layer])
	_check(misses == 0, "P2 rays: no misses", [misses, count])
	_check(worst <= P2_GROUND_M, "P2 rays within 5 cm of the published trail surface", worst)
	_check(not_rough == 0, "P2 rays hit the trail layer (road or trail at the mouths)", not_rough_at)
	return {"rays": count, "misses": misses, "max_abs_m": worst, "not_rough": not_rough, "not_rough_at": not_rough_at}


## Recovery next to the trail lands on the trail line, on loaded ground.
func _recovery(scene: Node3D, trail: Dictionary, probe: Node3D) -> Dictionary:
	var line: Dictionary = trail.line
	var k: int = line.s.size() / 2
	var query := Vector3(line.x[k] - line.tz[k] * 3.0, line.y[k], line.z[k] + line.tx[k] * 3.0)
	var pose: Transform3D = scene.request_bike_recovery(query)
	probe.global_position = pose.origin
	await physics_frame
	await physics_frame
	var on_line: float = _line_distance(line, Vector2(pose.origin.x, pose.origin.z))
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin, pose.origin - Vector3(0.0, 3.0, 0.0), 2 | 4 | 16))
	var clearance: float = pose.origin.y - hit.position.y if not hit.is_empty() else INF
	_check(on_line <= 0.05, "recovery lands on the trail line", on_line)
	_check(not hit.is_empty() and clearance >= 0.3 and clearance <= 0.6, "recovery above loaded ground", clearance)
	return {"line_distance_m": on_line, "clearance_m": clearance}


# --- helpers ---

func _line_distance(line: Dictionary, p: Vector2) -> float:
	var best: float = INF
	for k in range(line.s.size() - 1):
		var a := Vector2(line.x[k], line.z[k])
		var b := Vector2(line.x[k + 1], line.z[k + 1])
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best


func _grid(tile: Dictionary) -> Dictionary:
	var grid: Dictionary = {}
	var v: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var a: Vector3 = v[idx[t]]
		var b: Vector3 = v[idx[t + 1]]
		var c: Vector3 = v[idx[t + 2]]
		for j in range(int(floor(minf(a.z, minf(b.z, c.z)) / 4.0)), int(floor(maxf(a.z, maxf(b.z, c.z)) / 4.0)) + 1):
			for i in range(int(floor(minf(a.x, minf(b.x, c.x)) / 4.0)), int(floor(maxf(a.x, maxf(b.x, c.x)) / 4.0)) + 1):
				var key := Vector2i(i, j)
				if not grid.has(key):
					grid[key] = PackedInt32Array()
				grid[key].append(t)
	return grid


## Height of a tile's triangle under tile-local `l` (NAN off the tile).
func _mesh_height(tile: Dictionary, grid: Dictionary, l: Vector2) -> float:
	var v: PackedVector3Array = tile.arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = tile.arrays[Mesh.ARRAY_INDEX]
	var best: float = NAN
	var best_slack: float = -INF
	for t: int in grid.get(Vector2i(int(floor(l.x / 4.0)), int(floor(l.y / 4.0))), PackedInt32Array()):
		var a: Vector3 = v[idx[t]]
		var b: Vector3 = v[idx[t + 1]]
		var c: Vector3 = v[idx[t + 2]]
		var v0 := Vector2(b.x - a.x, b.z - a.z)
		var v1 := Vector2(c.x - a.x, c.z - a.z)
		var v2 := Vector2(l.x - a.x, l.y - a.z)
		var den: float = v0.x * v1.y - v1.x * v0.y
		if absf(den) < 1e-12:
			continue
		var bv: float = (v2.x * v1.y - v1.x * v2.y) / den
		var bw: float = (v0.x * v2.y - v2.x * v0.y) / den
		var slack: float = minf(minf(bv, bw), 1.0 - bv - bw)
		if slack > best_slack:
			best_slack = slack
			best = a.y + bv * (b.y - a.y) + bw * (c.y - a.y)
	return best if best_slack >= -1e-5 else NAN


## Height of the published triangles at a region-local point.
func _region_height(tiles: Array, grids: Dictionary, p: Vector2) -> float:
	for k in range(tiles.size()):
		var o := Vector2(tiles[k].origin[0], tiles[k].origin[1])
		var l: Vector2 = p - o
		if l.x < 0.0 or l.y < 0.0 or l.x > 512.0 or l.y > 512.0:
			continue
		if not grids.has(k):
			grids[k] = _grid(tiles[k])
		return _mesh_height(tiles[k], grids[k], l)
	return NAN


## World positions of a tile's vertices on its border facing `d`.
func _border_set(tile: Dictionary, d: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var o := Vector3(tile.origin[0], 0.0, tile.origin[1])
	for v: Vector3 in tile.arrays[Mesh.ARRAY_VERTEX]:
		if (d.x == 1 and v.x == 512.0) or (d.x == -1 and v.x == 0.0) or (d.y == 1 and v.z == 512.0) or (d.y == -1 and v.z == 0.0):
			out[v + o] = true
	return out
