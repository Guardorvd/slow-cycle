extends SceneTree

## Additive R4 durable contracts. All kernels and integration paths are real
## production paths; geographic appearance is inspected in diagnostic maps.
const Gen = preload("res://scripts/world/region/region_generator.gd")
const Terrain = preload("res://scripts/world/region/terrain_field.gd")
const HGen = preload("res://scripts/world/region/hydrology_generator.gd")
const Hydro = preload("res://scripts/world/region/hydrology_plan.gd")
const HField = preload("res://scripts/world/region/hydrology_field.gd")
const Surface = preload("res://scripts/world/region/hydrology_surface.gd")
const Context = preload("res://scripts/world/region/environment_context.gd")
const Biome = preload("res://scripts/world/region/biome_field.gd")
const Ride = preload("res://scripts/world/region/rideability_field.gd")
const Seeds = preload("res://scripts/world/region/region_seed_derivation.gd")
const Maps = preload("res://scripts/test/capture_environment_map.gd")
var checks: int = 0
var failures: int = 0
var digest_text: String = ""
var _body_kinds_seen: Dictionary = {}
var _width_transition_seen: bool = false


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ENV_CONTRACT_FAIL " + label)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	check(Context.create(null, null, null).reason_code == "ERR_ENV_INPUT_MISSING", "missing inputs")
	check(Context.create(RefCounted.new(), RefCounted.new(), RefCounted.new()).reason_code == "ERR_ENV_INPUT_INVALID", "wrong input types")
	check(Biome.create(null).reason_code == "ERR_BIOME_CONTEXT", "null biome context")
	check(Ride.create(null, null).reason_code == "ERR_RIDEABILITY_CONTEXT", "null ride context")
	check(Biome.create(Context.new()).reason_code == "ERR_BIOME_CONTEXT", "unconstructed context")
	check(Biome.dominant_weight(PackedFloat64Array([0.25, 0.25, 0.25, 0.25])) == 0 and Biome.dominant_weight(PackedFloat64Array([0.0, 0.5, 0.5, 0.0])) == 1, "enum order tie break")
	check(Context.aspect_shade(Vector2.ZERO) == 0.0 and Context.aspect_shade(Vector2(0.0, 0.01)) == 0.0, "flat aspect neutral")
	check(Context.aspect_shade(Vector2(0, 0.2)) == 1.0 and Context.aspect_shade(Vector2(0, -0.2)) == -1.0, "fixed world north")
	for fixture: Array in [["--seed=no", "ERR_ENV_CLI_SEED"], ["--seed=9223372036854775808", "ERR_ENV_CLI_SEED"], ["--region=1", "ERR_ENV_CLI_REGION"], ["--region=2147483648,0", "ERR_ENV_CLI_REGION"], ["--sweep=foo", "ERR_ENV_CLI_ARGUMENT"], ["--unknown", "ERR_ENV_CLI_ARGUMENT"]]:
		check(Maps.parse_options(PackedStringArray([fixture[0], "--out=C:/r4-evidence"])).reason_code == fixture[1], "CLI " + fixture[0])
	check(Maps.parse_options(PackedStringArray(["--seed=1", "--seed=2", "--out=C:/r4-evidence"])).reason_code == "ERR_ENV_CLI_DUPLICATE", "duplicate CLI")
	check(Maps.parse_options(PackedStringArray(["--seed=1", "--out=" + ProjectSettings.globalize_path("res://")])).reason_code == "ERR_ENV_CLI_OUTPUT", "project output rejected")
	check(Maps.parse_options(PackedStringArray(["--out=relative"])).reason_code == "ERR_ENV_CLI_OUTPUT", "relative output rejected")
	check(Maps.parse_options(PackedStringArray(["--seed=1", "--environment=wrong", "--out=C:/r4-evidence"]), true).reason_code == "ERR_ENV_CLI_MODE", "Vulkan mode grammar")
	check(Maps.parse_options(PackedStringArray(["--seed=1", "--seeds=2", "--out=C:/r4-evidence"])).reason_code == "ERR_ENV_CLI_MODE", "ambiguous seeds")
	check(Seeds.biome_seed_preimage(42) == "slow_cycle.seed/1\npurpose=biome\ncount=1\nv0=42\n", "seed preimage")
	check(Seeds.biome_seed(42) != Seeds.hydrology_seed(42), "seed purpose separation")
	for path: String in ["environment_context", "biome_field", "rideability_field"]:
		var text: String = FileAccess.get_file_as_string("res://scripts/world/region/" + path + ".gd")
		check(text.contains("extends RefCounted") and not text.contains("extends Node") and not text.contains("get_tree(") and not text.contains("RoadGraph") and not text.contains("BicycleController"), "pure direction " + path)
	var rows: Array = [[184729, 0, 0], [42, 0, 0], [77777, 0, 0], [3, 0, 0], [2024, 0, 0], [10007, 3, -2], [11, -1, -1], [-9223372036854775808, 2147483647, -2147483648]]
	var descriptors: Dictionary = {}
	var distributions: Dictionary = {}
	for row: Array in rows:
		var plan: RefCounted = Gen.build(row[0], Vector2i(row[1], row[2]))
		var terrain: RefCounted = Terrain.create(plan).field
		var hydro: RefCounted = HGen.build(plan, terrain).plan
		var made: Dictionary = Context.create(plan, terrain, hydro)
		check(made.is_valid, "real context construction " + str(row))
		if not made.is_valid:
			print("ENV_CONTRACT_SUMMARY checks=%d failures=%d completed=false" % [checks, failures])
			quit(1)
			return
		var ctx: RefCounted = made.context
		var biome: RefCounted = Biome.create(ctx).field
		var ride: RefCounted = Ride.create(ctx, biome).field
		var hf: RefCounted = HField.create(hydro, terrain).field
		var surface: RefCounted = Surface.create(terrain, hf).surface
		var ctx2: RefCounted = Context.create(plan, terrain, hydro).context
		seed(8791)
		for k in range(50):
			randf()
		var biome2: RefCounted = Biome.create(ctx2).field
		check(biome.signature() == biome2.signature() and ctx.signature() == ctx2.signature(), "independent fresh instances/global RNG " + str(row))
		var b: Dictionary = ctx.get_bounds_m()
		var original: int = b.min_x
		b.min_x = 0
		check(ctx.get_bounds_m().min_x == original, "bounds snapshot")
		b = ctx.get_bounds_m()
		var data: Dictionary = hydro.get_data()
		var first: Dictionary = biome.sample(b.min_x + 512.0, b.min_z + 512.0)
		data.lattice.area_cells.fill(0)
		var desc: Dictionary = biome.get_descriptor()
		desc.character.forest_permille = -10
		check(first == biome.sample(b.min_x + 512.0, b.min_z + 512.0), "snapshot cannot alias copies")
		check(Ride.create(ctx, null).reason_code == "ERR_RIDEABILITY_BIOME_MISMATCH", "missing biome")
		check(Ride.create(ctx, Biome.new()).reason_code == "ERR_RIDEABILITY_BIOME_MISMATCH", "unconstructed biome")
		var i0: int = b.min_x / 16
		var j0: int = b.min_z / 16
		var combined: Dictionary = ride.sample_combined_lattice(i0 + 121, j0 + 121, 9, 9)
		var biome_block: Dictionary = biome.sample_lattice(i0 + 121, j0 + 121, 9, 9)
		var ride_block: Dictionary = ride.sample_lattice(i0 + 121, j0 + 121, 9, 9)
		check(combined.biome == biome_block and combined.rideability == ride_block, "shared combined/standalone block parity")
		for j in range(9):
			for i in range(9):
				var k: int = j * 9 + i
				var x: float = float((i0 + 121 + i) * 16)
				var z: float = float((j0 + 121 + j) * 16)
				var point: Dictionary = ride.sample_combined(x, z)
				check(point.biome.weights == combined.biome.weights.slice(k * 4, k * 4 + 4) and point.rideability.cost == combined.rideability.cost[k] and point.rideability.gradient == combined.rideability.gradient[k] and int(point.rideability.blocked) == combined.rideability.blocked[k], "bit exact point/block " + str(k))
				check(point.biome == biome2.sample(x, z), "reordered fresh point " + str(k))
		var left: Dictionary = ride.sample_lattice(i0 + 125, j0 + 126, 4, 3)
		var right: Dictionary = ride.sample_lattice(i0 + 128, j0 + 126, 4, 3)
		for j in range(3):
			check(left.cost[j * 4 + 3] == right.cost[j * 4], "independent block seam")
		var means := PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
		for j in range(17):
			for i in range(17):
				var x: float = b.min_x + i * 256.0
				var z: float = b.min_z + j * 256.0
				var point: Dictionary = ride.sample_combined(x, z)
				var weights: PackedFloat64Array = point.biome.weights
				var sum: float = 0.0
				var finite: bool = true
				for k in range(4):
					sum += weights[k]
					finite = finite and is_finite(weights[k]) and weights[k] >= 0.0
					means[k] += weights[k]
				check(finite and absf(sum - (0.0 if point.biome.is_water else 1.0)) < 1e-12, "weight normalization/range")
				check(point.biome.dominant == Biome.Biome.WATER if point.biome.is_water else point.biome.dominant < 4, "water sentinel")
				check(is_finite(point.biome.moisture) and point.biome.moisture >= 0 and point.biome.moisture <= 1 and point.biome.woody_cover >= 0 and point.biome.woody_cover <= 1 and is_finite(point.rideability.cost) and point.rideability.cost >= 1 and point.rideability.cost <= 16, "finite bounded outputs")
				check(point.biome.is_water == hf.sample_water(x, z).is_water and point.rideability.water_depth_m == hf.sample_water(x, z).depth_m, "exact independent water wiring")
				check(point.rideability.gradient == surface.sample_gradient(x, z).gradient, "pre-road composed gradient")
				if point.rideability.water_depth_m >= 0.35 or point.rideability.slope_grade >= 1.0:
					check(point.rideability.blocked and point.rideability.cost == 16.0, "natural barriers")
				digest_text += JSON.stringify(point.biome) + JSON.stringify(point.rideability)
		for k in range(90):
			var lx: float = fmod(43.0 + k * 619.137, 4096.0)
			var lz: float = fmod(91.0 + k * 397.231, 4096.0)
			var x: float = b.min_x + lx
			var z: float = b.min_z + lz
			for radius: float in [1.0, 16.0, 160.0, 256.0]:
				var capped: Dictionary = hf.sample_proximity_bounded(x, z, radius)
				check(absf(capped.distance_to_water_m - minf(radius, hf.sample_proximity(x, z).distance_to_water_m)) < 1e-5, "bounded/full parity")
		# Independent all-geometry distance, no old proximity implementation.
		for channel: Dictionary in hydro.get_data().channels:
			var last: int = channel.x_cm.size() - 1
			for vertex: int in [0, last / 2, last]:
				var x: float = b.min_x + channel.x_cm[vertex] / 100.0
				var z: float = b.min_z + channel.z_cm[vertex] / 100.0
				check(hf.sample_proximity_bounded(x, z, 160.0).distance_to_water_m == 0.0, "channel vertex zero")
				check(ride.sample(x, z).is_water == hf.sample_water(x, z).is_water, "narrow channel point water")
		for p: Array in [[127.99, 128.01], [2080.0, 2055.0], [4095.0, 1000.0]]:
			var x: float = b.min_x + p[0]
			var z: float = b.min_z + p[1]
			check(absf(hf.sample_proximity_bounded(x, z, 256.0).distance_to_water_m - _independent_distance(hydro.get_data(), x - b.min_x, z - b.min_z, 256.0)) < 1e-4, "independent geometric oracle")
		_proximity_examples(hydro.get_data(), hf, ride, b)
		_negative_queries(ctx, biome, ride, hf, b)
		_continuity(ride, b, biome, ctx)
		_kernel(biome)
		descriptors[JSON.stringify(biome.get_descriptor())] = true
		distributions[str(means)] = true
		print("ENV_FIXTURE " + JSON.stringify({"seed": row[0], "region": [row[1], row[2]], "context": ctx.signature(), "biome": biome.signature(), "rideability": ride.signature(), "pocket": biome.get_descriptor().pocket, "weight_sums": means}))
		if row == rows[0]:
			_malformed(plan, terrain, hydro, ctx)
	check(descriptors.size() == rows.size() and distributions.size() == rows.size(), "nonconstant geographic layouts/distributions")
	check(_body_kinds_seen.has(Hydro.BODY_POND) and _body_kinds_seen.has(Hydro.BODY_CLOSED), "explicit pond and CLOSED examples completed")
	check(_width_transition_seen, "explicit channel width transition completed")
	print("ENV_OUTPUT_SHA256 " + digest_text.sha256_text())
	print("ENV_CONTRACT_SUMMARY checks=%d failures=%d completed=true fixtures=%d" % [checks, failures, rows.size()])
	quit(1 if failures else 0)


func _negative_queries(ctx: RefCounted, biome: RefCounted, ride: RefCounted, hf: RefCounted, b: Dictionary) -> void:
	for field: RefCounted in [biome, ride]:
		for p: Array in [[NAN, 1.0], [INF, 1.0], [b.min_x - 0.01, b.min_z], [b.max_x + 1.0, b.max_z]]:
			check(field.sample(p[0], p[1]).reason_code == ("ERR_ENV_NONFINITE_INPUT" if not is_finite(p[0]) else "ERR_ENV_OUT_OF_DOMAIN"), "query reason")
		check(field.sample_lattice(-9223372036854775808, 0, 0, 1).reason_code == "ERR_ENV_GRID_SHAPE", "shape checked first")
		check(field.sample_lattice(9223372036854775807, 0, 1, 1).reason_code == "ERR_ENV_OUT_OF_DOMAIN", "overflowing origin")
		check(field.sample_lattice(b.min_x / 16, b.min_z / 16, 9223372036854775807, 1).reason_code == "ERR_ENV_OUT_OF_DOMAIN", "overflowing count")
	for radius: float in [NAN, INF, -1.0, 0.0, 256.001]:
		check(hf.sample_proximity_bounded(b.min_x, b.min_z, radius).reason_code == "ERR_HYDRO_PROXIMITY_RADIUS", "radius reason")
	check(hf.sample_proximity_bounded(NAN, NAN, -1).reason_code == "ERR_HYDRO_NONFINITE_INPUT", "coordinate priority")
	check(ctx.query_reason(b.max_x, b.max_z).is_empty(), "closed edge")


func _malformed(plan: RefCounted, terrain: RefCounted, hydro: RefCounted, ctx: RefCounted) -> void:
	var other: RefCounted = Gen.build(99, Vector2i.ZERO)
	check(Context.create(other, terrain, hydro).reason_code == "ERR_ENV_INPUT_MISMATCH", "wrong region identity")
	var other_terrain: RefCounted = Terrain.create(other).field
	var other_hydro: RefCounted = HGen.build(other, other_terrain).plan
	var other_ctx: RefCounted = Context.create(other, other_terrain, other_hydro).context
	check(Ride.create(ctx, Biome.create(other_ctx).field).reason_code == "ERR_RIDEABILITY_BIOME_MISMATCH", "different environmental input")
	for kind: String in ["body_id", "body_kind", "cell", "duplicate", "negative_area", "frame", "symmetry", "origin", "schema"]:
		var data: Dictionary = hydro.get_data()
		# Consumer-invalid body is appended to a valid generated plan. Each
		# case changes exactly one invariant of this valid new body descriptor.
		if kind in ["body_id", "body_kind", "cell", "duplicate"]:
			var occupied: Dictionary = {}
			for body: Dictionary in data.bodies:
				for cell: int in body.cells:
					occupied[cell] = true
			var dry_cell: int = 0
			while occupied.has(dry_cell):
				dry_cell += 1
			var body: Dictionary = {"id": data.bodies.size(), "kind": Hydro.BODY_POND, "level_cm": 0, "outlet_kind": Hydro.OUTLET_EDGE, "outlet_id": -1, "cells": PackedInt32Array([dry_cell])}
			if kind == "body_id": body.id += 1
			if kind == "body_kind": body.kind = 2
			if kind == "cell": body.cells = PackedInt32Array([16641])
			if kind == "duplicate": body.cells.append(dry_cell)
			data.bodies.append(body)
		if kind == "negative_area": data.lattice.area_cells[15] = -1
		if kind == "frame": data.river_frame.near_v_cm[15] = data.river_frame.far_v_cm[15]
		if kind == "symmetry": data.frame_symmetry = 8
		if kind == "origin": data.origin_x_m += 4096
		if kind == "schema": data.terrain_schema = "wrong"
		var result: Dictionary = Context.create(plan, terrain, Hydro.new(data))
		check(result.reason_code == ("ERR_ENV_INPUT_MISMATCH" if kind in ["origin", "schema"] else "ERR_ENV_HYDRO_DATA") and result.context == null, "consumed guard " + kind)


func _kernel(biome: RefCounted) -> void:
	var signals: Dictionary = {"local_x": 1600.0, "local_z": 1200.0, "relative_elevation": 0.30, "gradient": Vector2.ZERO, "slope_grade": 0.0, "shade": 0.0, "moisture": 0.2, "distance_to_water_m": 160.0, "is_water": false, "water_depth_m": 0.0}
	for axis: String in ["slope_grade", "moisture", "cover"]:
		var previous: float = 0.0
		for i in range(101):
			var s: Dictionary = signals.duplicate()
			var cover: float = 0.4
			if axis == "cover": cover = i / 100.0
			else: s[axis] = i / 100.0
			var result: Dictionary = Ride.resistance(s, cover)
			check(result.cost >= previous, "monotone " + axis)
			previous = result.cost
	check(Ride.resistance(signals, 0.0).cost < Ride.resistance(signals, 0.9).cost, "flat open lower than forest")
	for depth: float in [0.1, 0.349999, 0.35, 2.0]:
		var s: Dictionary = signals.duplicate()
		s.is_water = true
		s.water_depth_m = depth
		var r: Dictionary = Ride.resistance(s, 0.0)
		check(r.blocked == (depth >= 0.35) and (r.reason_flags & Ride.Reason.WATER_PRESENT) != 0 and r.cost >= 8.0 and r["class"] >= Ride.TravelClass.DIFFICULT, "water thresholds")
		var bio: Dictionary = biome.evaluate_signals(s)
		check(bio.dominant == 4 and bio.woody_cover == 0.0 and bio.weights == PackedFloat64Array([0, 0, 0, 0]), "kernel exact water mask")
	var shaded: Dictionary = signals.duplicate()
	shaded.shade = 1.0
	var warm: Dictionary = signals.duplicate()
	warm.shade = -1.0
	check(biome.evaluate_signals(shaded).weights[0] > biome.evaluate_signals(warm).weights[0], "shaded conifer affinity")
	var previous_riparian: float = INF
	for distance in range(0, 161):
		var s: Dictionary = signals.duplicate()
		s.distance_to_water_m = float(distance)
		var riparian: float = biome.evaluate_signals(s).weights[2]
		check(riparian <= previous_riparian + 1e-15, "riparian distance decay")
		previous_riparian = riparian
	var previous: Dictionary = biome.evaluate_signals(signals)
	for i in range(1, 100):
		var s: Dictionary = signals.duplicate()
		s.relative_elevation += i * 0.001
		var now: Dictionary = biome.evaluate_signals(s)
		check(absf(now.weights[0] - previous.weights[0]) < 0.005, "controlled smooth kernel")
		previous = now


func _continuity(ride: RefCounted, b: Dictionary, biome: RefCounted, ctx: RefCounted) -> void:
	var sites: Array = [[512.0, 768.0], [1024.0, 1280.0], [2048.0, 2048.0]]
	var pocket: Dictionary = biome.get_descriptor().pocket
	if pocket.is_present:
		var macro = preload("res://scripts/world/region/macro_terrain_plan.gd")
		var edge: int = pocket.u_m + pocket.radius_u_m if pocket.u_m + pocket.radius_u_m < 4096 else pocket.u_m - pocket.radius_u_m
		var p: Vector2 = macro.frame_to_local(ctx.get_frame_symmetry(), edge, pocket.v_m)
		sites.append([p.x, p.y])
	for site: Array in sites:
		var a: Dictionary = ride.sample_combined(b.min_x + site[0] - 0.00001, b.min_z + site[1])
		var c: Dictionary = ride.sample_combined(b.min_x + site[0] + 0.00001, b.min_z + site[1])
		check(absf(a.biome.moisture - c.biome.moisture) < 0.00001, "scalar continuity at grid/pocket boundary")
		if a.biome.is_water == c.biome.is_water:
			var continuous: bool = true
			for k in range(4):
				continuous = continuous and absf(a.biome.weights[k] - c.biome.weights[k]) < 0.00001
			check(continuous and absf(a.biome.woody_cover - c.biome.woody_cover) < 0.00001, "actual-world all affinity/cover continuity")
		if a.rideability.blocked == c.rideability.blocked and a.rideability.is_water == c.rideability.is_water:
			check(absf(a.rideability.cost - c.rideability.cost) < 0.0001, "actual-world cost continuity")


func _proximity_examples(data: Dictionary, hf: RefCounted, ride: RefCounted, b: Dictionary) -> void:
	var examples: Array = []
	for channel: Dictionary in data.channels:
		var k: int = (channel.x_cm.size() - 2) / 2
		for step in range(channel.width_cm.size() - 1):
			if channel.width_cm[step] != channel.width_cm[step + 1]:
				k = step
				_width_transition_seen = true
				break
		var ax: float = channel.x_cm[k] / 100.0
		var az: float = channel.z_cm[k] / 100.0
		var dx: float = (channel.x_cm[k + 1] - channel.x_cm[k]) / 100.0
		var dz: float = (channel.z_cm[k + 1] - channel.z_cm[k]) / 100.0
		var length: float = sqrt(dx * dx + dz * dz)
		for t: float in [0.25, 0.5, 0.75]:
			var half: float = lerpf(channel.width_cm[k] / 200.0, channel.width_cm[k + 1] / 200.0, t)
			var lx: float = ax + t * dx
			var lz: float = az + t * dz
			examples.append([lx, lz, "segment interior"])
			examples.append([clampf(lx - dz / length * (half + 10.0), 0, 4096), clampf(lz + dx / length * (half + 10.0), 0, 4096), "width-interpolated edge offset"])
		# Both sides of a nearby 128 m bucket edge, independently selected.
		var middle_x: float = (ax + dx * 0.5)
		var middle_z: float = (az + dz * 0.5)
		var bucket_x: float = clampf(round(middle_x / 128.0) * 128.0, 128.0, 3968.0)
		examples.append([bucket_x - 0.01, middle_z, "bucket west"])
		examples.append([bucket_x + 0.01, middle_z, "bucket east"])
	for body: Dictionary in data.bodies:
		_body_kinds_seen[body.kind] = true
		var cell: int = body.cells[body.cells.size() / 2]
		var cx: float = (cell % 129) * 32.0
		var cz: float = (cell / 129) * 32.0
		for offset: float in [0.0, 15.99, 16.01, 31.0]:
			examples.append([clampf(cx + offset, 0, 4096), cz, "body kind %d cell edge" % body.kind])
		var actual: Dictionary = hf.sample_water(b.min_x + cx, b.min_z + cz)
		var traversal: Dictionary = ride.sample(b.min_x + cx, b.min_z + cz)
		check(actual.is_water == traversal.is_water and actual.depth_m == traversal.water_depth_m, "explicit body water authority")
		if actual.depth_m >= 0.35:
			check(traversal.blocked, "explicit deep body barrier")
	for example: Array in examples:
		var x: float = b.min_x + example[0]
		var z: float = b.min_z + example[1]
		for radius: float in [1.0, 16.0, 160.0, 256.0]:
			var expected: float = _independent_distance(data, x - b.min_x, z - b.min_z, radius)
			var actual: Dictionary = hf.sample_proximity_bounded(x, z, radius)
			check(absf(actual.distance_to_water_m - expected) < 1e-4 and actual.is_capped == (actual.distance_to_water_m == radius), "independent " + example[2])


func _independent_distance(data: Dictionary, lx: float, lz: float, radius: float) -> float:
	var best: float = radius
	for channel: Dictionary in data.channels:
		for k in range(channel.x_cm.size() - 1):
			var ax: float = channel.x_cm[k] / 100.0
			var az: float = channel.z_cm[k] / 100.0
			var dx: float = (channel.x_cm[k + 1] - channel.x_cm[k]) / 100.0
			var dz: float = (channel.z_cm[k + 1] - channel.z_cm[k]) / 100.0
			var t: float = clampf(((lx - ax) * dx + (lz - az) * dz) / (dx * dx + dz * dz), 0.0, 1.0)
			var distance: float = sqrt(pow(lx - ax - dx * t, 2.0) + pow(lz - az - dz * t, 2.0))
			best = minf(best, maxf(0.0, distance - lerpf(channel.width_cm[k] / 200.0, channel.width_cm[k + 1] / 200.0, t)))
	for body: Dictionary in data.bodies:
		for cell: int in body.cells:
			best = minf(best, maxf(0.0, Vector2(lx - (cell % 129) * 32.0, lz - (cell / 129) * 32.0).length() - 16.0))
	return best
