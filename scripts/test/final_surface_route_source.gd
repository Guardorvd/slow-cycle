extends RefCounted
## Development fixture I/O lives outside the pure surface domain.
const Route = preload("res://scripts/world/region/certified_road_route.gd")
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Natural = preload("res://scripts/world/region/hydrology_surface.gd")
const Planner = preload("res://scripts/world/region/route_planner.gd")
const Synth = preload("res://scripts/world/region/road_synthesizer.gd")

static func build(source: String = "cache", path: String = "user://r7/route_184729_0_0.bin") -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var region: RefCounted = Gen.build(184729, Vector2i.ZERO)
	var terrain: RefCounted = Terrain.create(region).field
	var hydro: Dictionary = HGen.build(region, terrain)
	var field: RefCounted = HField.create(hydro.plan, terrain).field
	var natural: RefCounted = Natural.create(terrain, field).surface
	var stages: Dictionary={"base_hydrology_ms":(Time.get_ticks_usec()-t0)/1000.0,"planner_ms":0.0,"synth_ms":0.0}
	var key := Route.dependency_digest()
	var spec := {"seed": 184729, "region": Vector2i.ZERO, "settings": "default", "region_signature": region.signature(), "hydrology_signature": hydro.plan.signature()}
	var cached: Dictionary = read_cache(path, key, spec)
	var route: RefCounted
	var live_bytes_equal := false
	var graph: RefCounted
	var plan: RefCounted
	if source == "cache" and cached.is_valid:
		route = cached.route
	else:
		if FileAccess.file_exists(path) and not cached.is_valid:
			print("ERR_R7_CACHE_STALE: invalid development fixture; rebuilding live")
		var stage0: int=Time.get_ticks_usec()
		var routes: Dictionary = Planner.plan(region, terrain, hydro.plan)
		stages.planner_ms=(Time.get_ticks_usec()-stage0)/1000.0
		if not routes.is_valid:
			return {"is_valid": false, "reason_code": routes.reason_code}
		graph = routes.graph
		stage0=Time.get_ticks_usec()
		var result: Dictionary = Synth.synthesize(region, terrain, hydro.plan, graph)
		stages.synth_ms=(Time.get_ticks_usec()-stage0)/1000.0
		plan = result.plan
		var extract: Dictionary = Route.from_plan(plan, spec)
		if not extract.is_valid:
			return extract
		route = extract.route
		live_bytes_equal = cached.is_valid and route.to_bytes() == cached.route.to_bytes()
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return {"is_valid": false, "reason_code": "ERR_R7_CACHE_WRITE"}
		var payload: PackedByteArray = route.to_bytes()
		file.store_buffer(var_to_bytes({"key": key, "spec": spec, "sha": Route.sha(payload), "payload": payload}))
		file.close()
	return {"is_valid": true, "reason_code": "", "region":region,"route": route, "terrain": terrain, "hydrology": hydro.plan, "field": field, "natural": natural, "graph": graph, "plan": plan, "fixture_equal": live_bytes_equal, "upstream_ms": (Time.get_ticks_usec() - t0) / 1000.0,"upstream_stages_ms":stages,"key": key}

static func read_cache(path: String, key: String, spec: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return Route.failure("ERR_R7_CACHE_STALE")
	var value: Variant = bytes_to_var(FileAccess.get_file_as_bytes(path))
	if not value is Dictionary or value.get("key", "") != key or value.get("spec", {}) != spec:
		return Route.failure("ERR_R7_CACHE_STALE")
	if not value.get("payload") is PackedByteArray or Route.sha(value.payload) != value.get("sha", ""):
		return Route.failure("ERR_R7_CACHE_STALE")
	return Route.from_bytes(value.payload)
