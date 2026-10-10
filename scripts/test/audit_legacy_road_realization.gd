extends SceneTree

## Observational legacy study (ExecPlan §12 M1): the unmodified RoadLogic /
## RoadGrammar pipeline generating 150 chunks per seed x style x profile
## configuration, with its normal GEOM log lines captured per chunk through
## the existing SlowCycleLogger API. Measures requested phases, rejected
## candidates, soft repairs, fatal fallbacks, final invalid chunks and actual
## realisation (heading change, curvature, elevation, contact states) per phase,
## plus whole-path straightness in the same terms as the R6 character report.
## Forced switchback / crest / drop / winding phases are separate labelled
## probes, not prevalence data. Changes no legacy code, threshold or test.
## Not an R6-versus-legacy speed benchmark or a same-geography comparison.
const RoadLogicClass = preload("res://scripts/world/road_logic.gd")
const RoadPathDataClass = preload("res://scripts/world/road_path_data.gd")
const GrammarClass = preload("res://scripts/world/road_grammar.gd")
const GeomLog = preload("res://scripts/core/slow_cycle_logger.gd")
const Preview = preload("res://scripts/world/region_preview.gd")
const STYLES := {"BALANCED": 0, "FLOW": 1, "TECHNICAL": 2}
const PHASE_NAMES := ["CRUISE_DOWNHILL", "FAST_GRAVITY_DESCENT", "BRAKING_ZONE", "SWITCHBACK", "CREST_MICRO_DROP", "AIRBORNE_DROP", "VALID_LANDING_SURFACE", "RECOVERY_FLAT",
	"WINDING_SINGLETRACK", "FOREST_CRUISE"]


func _init() -> void:
	var seeds: Array = [184729, 42, 77777]
	var chunks: int = 150
	var out: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			var parsed: Dictionary = Preview.parse_integer(arg.substr(7), 64)
			if not parsed.is_valid:
				_fail()
				return
			seeds = [parsed.value]
		elif arg.begins_with("--chunks="):
			chunks = arg.substr(9).to_int()
		elif arg.begins_with("--out="):
			out = arg.substr(6).replace("\\", "/")
		else:
			_fail()
			return
	if out.is_empty() or chunks <= 0:
		_fail()
		return
	GeomLog.set_console_echo(false)
	# Capture self-test: a GEOM line written through the same API must be read
	# back, otherwise zero counts would not be evidence.
	GeomLog.clear()
	GeomLog.log_geom("GEOM_REJECT: audit capture self-test")
	var capture_ok: bool = GeomLog.get_recent_lines(5).any(func(line: String) -> bool: return line.contains("audit capture self-test"))
	GeomLog.clear()
	if not capture_ok:
		print("R6_LEGACY_AUDIT_FAIL capture")
		quit(1)
		return
	var runs: Array = []
	for seed_value: int in seeds:
		for style_name: String in STYLES:
			for config: String in ["mountain_profile", "no_profile"]:
				var first: Dictionary = _run(seed_value, STYLES[style_name], config, chunks)
				var replay: Dictionary = _run(seed_value, STYLES[style_name], config, chunks)
				first["seed"] = seed_value
				first["style"] = style_name
				first["config"] = config
				first["replay_identical"] = first.signature == replay.signature
				runs.append(first)
				print("LEGACY_AUDIT seed=%d style=%s config=%s rejects=%d repairs=%d fallbacks=%d invalid_final=%d straight=%.3f turn_deg_km=%.1f replay=%s" % [seed_value, style_name, config,
					first.totals.rejects, first.totals.repairs, first.totals.fatal_fallbacks, first.totals.invalid_final, first.path.straight_fraction, first.path.turn_deg_per_km, first.replay_identical])
	var probes: Array = []
	for phase: int in [GrammarClass.FlowPhase.SWITCHBACK, GrammarClass.FlowPhase.CREST_MICRO_DROP, GrammarClass.FlowPhase.AIRBORNE_DROP, GrammarClass.FlowPhase.WINDING_SINGLETRACK]:
		for seed_value: int in seeds:
			probes.append(_probe(seed_value, phase))
	var provenance: Dictionary = {}
	for path: String in ["res://scripts/world/road_logic.gd", "res://scripts/world/road_grammar.gd", "res://scripts/world/road_validity_validator.gd", "res://scripts/world/mountain_profile.gd",
			"res://scripts/world/road_generation_contract.gd", "res://scripts/test/audit_legacy_road_realization.gd"]:
		provenance[path] = FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("legacy_audit_%s.json" % "_".join(seeds.map(func(s: int) -> String: return str(s)))), FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs": runs, "probes": probes, "provenance": provenance, "chunks": chunks, "capture_self_test": capture_ok, "engine": Engine.get_version_info()}, "\t"))
	file.close()
	print("R6_LEGACY_AUDIT_SUMMARY runs=%d probes=%d completed=true" % [runs.size(), probes.size()])
	quit(0)


func _fail() -> void:
	print("R6_LEGACY_AUDIT_FAIL ERR_R6_CLI_ARGUMENT")
	quit(2)


func _run(seed_value: int, style: int, config: String, chunks: int) -> Dictionary:
	var path: RefCounted = RoadPathDataClass.new()
	var logic: RefCounted = RoadLogicClass.new(seed_value, path)
	logic.set_route_style(style, seed_value)
	if config == "no_profile":
		logic.mountain_profile = null
	var per_phase: Dictionary = {}
	var totals := {"rejects": 0, "repairs": 0, "fatal_fallbacks": 0, "invalid_final": 0}
	var chunk_records: Array = []
	for c in range(chunks):
		var start: int = path.size() - 1
		GeomLog.clear()
		logic.plan_next_chunk()
		var lines: Array[String] = GeomLog.get_recent_lines(50)
		var reject: bool = false
		var repair: bool = false
		var fallback: bool = false
		for line: String in lines:
			reject = reject or line.contains("GEOM_REJECT")
			repair = repair or line.contains("SOFT_REPAIR")
			fallback = fallback or line.contains("FATAL_FALLBACK")
		var phase: int = logic.grammar.get_current_phase()
		var name: String = PHASE_NAMES[phase] if phase >= 0 and phase < PHASE_NAMES.size() else str(phase)
		var m: Dictionary = _measure(path, start, path.size() - 1)
		if not per_phase.has(name):
			per_phase[name] = {"requested": 0, "rejected": 0, "repaired": 0, "fallback": 0, "invalid_final": 0, "abs_heading_change_deg": [], "max_curvature": [], "elevation_change_m": [],
				"contact_non_grounded_samples": 0, "segment_types": {}}
		var p: Dictionary = per_phase[name]
		p.requested += 1
		p.rejected += 1 if reject else 0
		p.repaired += 1 if repair else 0
		p.fallback += 1 if fallback else 0
		p.invalid_final += 0 if logic.is_last_chunk_valid() else 1
		p.abs_heading_change_deg.append(snappedf(absf(m.heading_change_deg), 0.1))
		p.max_curvature.append(snappedf(m.max_curvature, 0.0001))
		p.elevation_change_m.append(snappedf(m.elevation_change_m, 0.01))
		p.contact_non_grounded_samples += m.non_grounded
		for t: int in m.types:
			p.segment_types[str(t)] = p.segment_types.get(str(t), 0) + 1
		totals.rejects += 1 if reject else 0
		totals.repairs += 1 if repair else 0
		totals.fatal_fallbacks += 1 if fallback else 0
		totals.invalid_final += 0 if logic.is_last_chunk_valid() else 1
		chunk_records.append([c, name, reject, repair, fallback, logic.is_last_chunk_valid()])
	var whole: Dictionary = _straightness(path)
	var signature: String = str(path.points).sha256_text()
	return {"per_phase": per_phase, "totals": totals, "path": whole, "chunks": chunk_records, "signature": signature, "samples": path.size()}


static func _measure(path: RefCounted, a: int, b: int) -> Dictionary:
	var heading: float = 0.0
	var max_k: float = 0.0
	var non_grounded: int = 0
	var types: Dictionary = {}
	for i in range(maxi(a, 0) + 1, b + 1):
		var t0 := Vector2(path.tangents[i - 1].x, path.tangents[i - 1].z)
		var t1 := Vector2(path.tangents[i].x, path.tangents[i].z)
		heading += rad_to_deg(t0.angle_to(t1))
		max_k = maxf(max_k, path.curvatures[i])
		non_grounded += 1 if path.surface_contact_states[i] != 0 else 0
		types[path.segment_types[i]] = true
	return {"heading_change_deg": heading, "max_curvature": max_k, "elevation_change_m": path.points[b].y - path.points[maxi(a, 0)].y, "non_grounded": non_grounded, "types": types.keys()}


## Same measures as the R6 character report, from point geometry.
static func _straightness(path: RefCounted) -> Dictionary:
	var length: float = 0.0
	var straight: float = 0.0
	var total_turn: float = 0.0
	var longest: float = 0.0
	var run: float = 0.0
	for i in range(1, path.size() - 1):
		var a := Vector2(path.points[i - 1].x, path.points[i - 1].z)
		var c := Vector2(path.points[i].x, path.points[i].z)
		var e := Vector2(path.points[i + 1].x, path.points[i + 1].z)
		var ds: float = a.distance_to(c)
		var denominator: float = (c - a).length() * (e - c).length() * (e - a).length()
		var k: float = 0.0 if denominator <= 1e-9 else absf(2.0 * (c - a).cross(e - c) / denominator)
		length += ds
		total_turn += rad_to_deg(absf((c - a).angle_to(e - c)))
		if k < 1.0 / 1000.0:
			straight += ds
			run += ds
			longest = maxf(longest, run)
		else:
			run = 0.0
	return {"length_m": length, "straight_fraction": straight / maxf(length, 1e-9), "turn_deg_per_km": total_turn / maxf(length / 1000.0, 1e-9), "longest_straight_m": longest}


## Forced phase probe: 12 ordinary chunks, then the phase queued at the front.
func _probe(seed_value: int, phase: int) -> Dictionary:
	var path: RefCounted = RoadPathDataClass.new()
	var logic: RefCounted = RoadLogicClass.new(seed_value, path)
	for _c in range(12):
		logic.plan_next_chunk()
	logic.grammar.phase_queue.push_front(phase)
	var start: int = path.size() - 1
	GeomLog.clear()
	logic.plan_next_chunk()
	var lines: Array[String] = GeomLog.get_recent_lines(50)
	var m: Dictionary = _measure(path, start, path.size() - 1)
	var flags: Array = []
	for line: String in lines:
		for key: String in ["GEOM_REJECT", "SOFT_REPAIR", "FATAL_FALLBACK"]:
			if line.contains(key) and not key in flags:
				flags.append(key)
	return {"label": "FORCED_" + PHASE_NAMES[phase], "seed": seed_value, "realized_phase": PHASE_NAMES[logic.grammar.get_current_phase()], "heading_change_deg": m.heading_change_deg,
		"max_curvature": m.max_curvature, "elevation_change_m": m.elevation_change_m, "non_grounded_samples": m.non_grounded, "segment_types": m.types, "log_flags": flags,
		"valid": logic.is_last_chunk_valid()}
