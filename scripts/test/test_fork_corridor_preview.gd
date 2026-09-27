extends SceneTree

const Planner = preload("res://scripts/world/fork_corridor_preview_planner.gd")
const ArmGeometry = preload("res://scripts/world/fork_arm_geometry.gd")
const TerrainCarver = preload("res://scripts/world/terrain_carver.gd")

var checks: int = 0
var failures: int = 0

class SafeTerrain extends RefCounted:
	func evaluate_profile(_pos: Vector3, _binorm: Vector3, _curv: float) -> Dictionary:
		return {"danger_left": false, "danger_right": false}

class DangerousTerrain extends RefCounted:
	func evaluate_profile(_pos: Vector3, _binorm: Vector3, _curv: float) -> Dictionary:
		return {"danger_left": true, "danger_right": false}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var planner = Planner.new()
	var pos := Vector3(12.0, 80.0, -450.0)
	var slope: float = -6.0
	var tang := Vector3(sin(deg_to_rad(174.0)) * cos(deg_to_rad(slope)), sin(deg_to_rad(slope)), cos(deg_to_rad(174.0)) * cos(deg_to_rad(slope))).normalized()
	var norm := Vector3.UP
	var binorm := tang.cross(norm).normalized()
	var safe = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, SafeTerrain.new())
	_check(bool(safe.eligible), "safe paired arms accepted")
	_check(safe.arms.size() == 2, "both arm previews returned")
	_check(safe.arms[0].sample_count == 26 and safe.arms[1].sample_count == 26, "both production arms have 26 samples")
	_check(absf(float(safe.arms[0].length_m) - 50.0) < 0.2, "left preview spans production arm length")
	_check(absf(float(safe.arms[1].length_m) - 50.0) < 0.2, "right preview spans production arm length")
	_check(safe.arms[0].route_style == 1 and safe.arms[1].route_style == 2, "style identities preserved")
	var repeat = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, SafeTerrain.new())
	_check(safe.signature == repeat.signature and safe.arms == repeat.arms, "preview signature deterministic")
	var danger = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, DangerousTerrain.new())
	_check(not danger.eligible, "dangerous terrain rejects pair")
	_check(danger.reason_codes.has("left_arm_corridor_terrain_danger"), "stable left reason reported")
	_check(danger.reason_codes.has("right_arm_corridor_terrain_danger"), "stable right reason reported")
	var unpaired = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 1, SafeTerrain.new())
	_check(not unpaired.eligible and unpaired.reason_codes.has("route_style_pair_invalid"), "non-distinct style pair rejected")
	var steep = planner.evaluate_pair(pos, tang, binorm, 174.0, -30.0, 1, 2, SafeTerrain.new())
	_check(not steep.eligible and steep.reason_codes.has("left_grade_out_of_bounds"), "out-of-contract paired grade rejected")
	var malformed = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, null)
	_check(not malformed.eligible and malformed.reason_codes.has("terrain_evaluator_unavailable"), "missing terrain evaluator rejects")
	var left = ArmGeometry.build(pos, tang, binorm, 174.0, -6.0, 0, 1)
	var right = ArmGeometry.build(pos, tang, binorm, 174.0, -6.0, 1, 2)
	_check(left.points.size() == 26 and right.points.size() == 26, "shared production builder used for both arms")
	var actual_terrain = TerrainCarver.new(184729)
	var seed_a = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, actual_terrain)
	var seed_b = planner.evaluate_pair(pos, tang, binorm, 174.0, -6.0, 1, 2, TerrainCarver.new(184729))
	_check(seed_a.signature == seed_b.signature and seed_a.reason_codes == seed_b.reason_codes, "production terrain preview deterministic by seed")
	print("FORK_CORRIDOR_PREVIEW_SUMMARY checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[FAIL] " + label)
	else:
		print("[PASS] " + label)
