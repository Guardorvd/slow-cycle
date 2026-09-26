extends SceneTree

## Standalone deterministic and continuity checks for MountainProfile.

const Profile = preload("res://scripts/world/mountain_profile.gd")
const Contract = preload("res://scripts/world/road_generation_contract.gd")
const SEEDS: Array[int] = [10101, 20202, 30303, 40404, 50505, 184729, 42]
const ROUTES: Array[String] = ["main", "route-left", "route-right"]
const CHECK_DISTANCE_M: float = 12000.0
var checks: int = 0
var failures: int = 0

func _init() -> void:
	_test_repeatability_and_order_independence()
	_test_boundary_continuity()
	_test_contract_envelope_and_descent()
	_test_profile_diversity()
	print("MOUNTAIN_PROFILE_SUMMARY checks=%d failures=%d seeds=%d routes=%d" % [checks, failures, SEEDS.size(), ROUTES.size()])
	quit(1 if failures > 0 else 0)

func _test_repeatability_and_order_independence() -> void:
	var distances: Array[float] = [0.0, 17.25, 299.999, 300.0, 901.5, 2999.0, 6000.0, CHECK_DISTANCE_M]
	for seed_value in SEEDS:
		for route_id in ROUTES:
			var first = Profile.new(seed_value, route_id, 1200.0)
			var expected: Dictionary = {}
			for distance in distances:
				expected[distance] = first.sample_at(distance)
			var shuffled = Profile.new(seed_value, route_id, 1200.0)
			for i in range(distances.size() - 1, -1, -1):
				var distance: float = distances[i]
				_check(_samples_equal(expected[distance], shuffled.sample_at(distance)), "order-independent sample seed=%d route=%s s=%.2f" % [seed_value, route_id, distance])
			var recreated = Profile.new(seed_value, route_id, 1200.0)
			for distance in distances:
				_check(_samples_equal(expected[distance], recreated.sample_at(distance)), "repeat sample seed=%d route=%s s=%.2f" % [seed_value, route_id, distance])

func _test_boundary_continuity() -> void:
	for seed_value in SEEDS:
		var profile = Profile.new(seed_value, "continuity-route", 0.0)
		for boundary_index in range(1, 41):
			var boundary_m: float = float(boundary_index) * Profile.get_segment_length_m()
			var left: Dictionary = profile.sample_at(boundary_m - 0.001)
			var exact: Dictionary = profile.sample_at(boundary_m)
			var right: Dictionary = profile.sample_at(boundary_m + 0.001)
			_check(absf(float(left.elevation_m) - float(exact.elevation_m)) < 0.00016, "C0 elevation left boundary seed=%d s=%.1f" % [seed_value, boundary_m])
			_check(absf(float(right.elevation_m) - float(exact.elevation_m)) < 0.00016, "C0 elevation right boundary seed=%d s=%.1f" % [seed_value, boundary_m])
			_check(absf(float(left.grade_deg) - float(exact.grade_deg)) < 0.0001, "C1 grade left boundary seed=%d s=%.1f" % [seed_value, boundary_m])
			_check(absf(float(right.grade_deg) - float(exact.grade_deg)) < 0.0001, "C1 grade right boundary seed=%d s=%.1f" % [seed_value, boundary_m])
			_check(absf(float(left.grade_rate_deg_per_m) - float(exact.grade_rate_deg_per_m)) < 0.0001, "grade derivative continuity left boundary seed=%d s=%.1f" % [seed_value, boundary_m])
			_check(absf(float(right.grade_rate_deg_per_m) - float(exact.grade_rate_deg_per_m)) < 0.0001, "grade derivative continuity right boundary seed=%d s=%.1f" % [seed_value, boundary_m])

func _test_contract_envelope_and_descent() -> void:
	for seed_value in SEEDS:
		for route_id in ROUTES:
			var profile = Profile.new(seed_value, route_id, 1800.0)
			var previous_height: float = float(profile.sample_at(0.0).elevation_m)
			var minimum_grade: float = INF
			var maximum_grade: float = -INF
			for step in range(1, 601):
				var sample: Dictionary = profile.sample_at(float(step) * 20.0)
				var grade: float = float(sample.grade_deg)
				_check(Contract.is_slope_within_bounds(grade), "road contract grade seed=%d route=%s s=%d" % [seed_value, route_id, step * 20])
				_check(grade <= -2.49 and grade >= -8.01, "profile grade envelope seed=%d route=%s s=%d grade=%.4f" % [seed_value, route_id, step * 20, grade])
				_check(float(sample.elevation_m) < previous_height, "strict net descent seed=%d route=%s s=%d" % [seed_value, route_id, step * 20])
				previous_height = float(sample.elevation_m)
				minimum_grade = minf(minimum_grade, grade)
				maximum_grade = maxf(maximum_grade, grade)
			var total_drop: float = 1800.0 - previous_height
			_check(total_drop >= 1000.0 and total_drop <= 1160.0, "12 km elevation budget seed=%d route=%s drop=%.3f" % [seed_value, route_id, total_drop])
			print("PROFILE_ENVELOPE seed=%d route=%s drop_12km=%.2fm grade_range=%.3f..%.3fdeg" % [seed_value, route_id, total_drop, minimum_grade, maximum_grade])

func _test_profile_diversity() -> void:
	var baseline = Profile.new(SEEDS[0], ROUTES[0])
	for seed_index in range(1, SEEDS.size()):
		var alternate_seed = Profile.new(SEEDS[seed_index], ROUTES[0])
		_check(_profiles_differ(baseline, alternate_seed), "distinct seed profile %d vs %d" % [SEEDS[0], SEEDS[seed_index]])
	for route_index in range(1, ROUTES.size()):
		var alternate_route = Profile.new(SEEDS[0], ROUTES[route_index])
		_check(_profiles_differ(baseline, alternate_route), "distinct route identity %s vs %s" % [ROUTES[0], ROUTES[route_index]])

func _profiles_differ(a: RefCounted, b: RefCounted) -> bool:
	for distance in [150.0, 600.0, 1500.0, 4200.0, 9000.0]:
		var sample_a: Dictionary = a.sample_at(distance)
		var sample_b: Dictionary = b.sample_at(distance)
		if absf(float(sample_a.elevation_m) - float(sample_b.elevation_m)) > 0.05:
			return true
		if absf(float(sample_a.grade_deg) - float(sample_b.grade_deg)) > 0.05:
			return true
	return false

func _samples_equal(a: Dictionary, b: Dictionary) -> bool:
	return a.segment_index == b.segment_index \
		and a.macro_region == b.macro_region \
		and is_equal_approx(float(a.elevation_m), float(b.elevation_m)) \
		and is_equal_approx(float(a.grade_deg), float(b.grade_deg)) \
		and is_equal_approx(float(a.grade_rate_deg_per_m), float(b.grade_rate_deg_per_m))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("[MOUNTAIN_PROFILE FAIL] %s" % label)
