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
	_test_biome_determinism_and_continuity()
	_test_biome_zone_alternation_and_diversity()
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

func _test_biome_determinism_and_continuity() -> void:
	var distances: Array[float] = [0.0, 50.0, 100.0, 200.0, 500.0, 1250.0, 3000.0, 5000.0]
	for seed_value in SEEDS:
		for route_id in ROUTES:
			var profile = Profile.new(seed_value, route_id, 1200.0)
			_check(profile.get_mountain_weight_at(-10.0) == 0.5, "negative distance weight seed=%d" % seed_value)
			_check(profile.get_biome_zone_at(-10.0) == Profile.BiomeZone.TRANSITION, "negative distance zone seed=%d" % seed_value)

			var clone = Profile.new(seed_value, route_id, 1200.0)
			for d in distances:
				var w1: float = profile.get_mountain_weight_at(d)
				var w2: float = clone.get_mountain_weight_at(d)
				var z1: int = profile.get_biome_zone_at(d)
				var z2: int = clone.get_biome_zone_at(d)
				_check(is_equal_approx(w1, w2), "deterministic weight seed=%d route=%s s=%.1f" % [seed_value, route_id, d])
				_check(z1 == z2, "deterministic zone seed=%d route=%s s=%.1f" % [seed_value, route_id, d])
				_check(w1 >= 0.0 and w1 <= 1.0, "weight bounded [0,1] seed=%d s=%.1f" % [seed_value, d])

		var p = Profile.new(seed_value, "main", 0.0)
		var prev_w: float = p.get_mountain_weight_at(0.0)
		for step in range(1, 1001):
			var s: float = float(step) * 2.0
			var curr_w: float = p.get_mountain_weight_at(s)
			_check(absf(curr_w - prev_w) < 0.02, "weight C0 continuous step=%d s=%.1f dw=%.4f" % [step, s, absf(curr_w - prev_w)])
			prev_w = curr_w

func _test_biome_zone_alternation_and_diversity() -> void:
	for seed_value in [10101, 20202, 30303, 184729, 42]:
		var profile = Profile.new(seed_value, "main", 0.0)
		var m_count: int = 0
		var f_count: int = 0
		var t_count: int = 0
		var switches: int = 0
		var last_main_zone: int = -1
		var current_zone: int = -1
		var zone_start_s: float = 0.0
		var zone_lengths: Array[Dictionary] = []

		var sample_step_m: float = 10.0
		var max_distance_m: float = 5000.0
		var steps: int = int(max_distance_m / sample_step_m)

		for step in range(steps + 1):
			var s: float = float(step) * sample_step_m
			var zone: int = profile.get_biome_zone_at(s)
			match zone:
				Profile.BiomeZone.MOUNTAIN:
					m_count += 1
					if last_main_zone == Profile.BiomeZone.FOREST:
						switches += 1
					last_main_zone = Profile.BiomeZone.MOUNTAIN
				Profile.BiomeZone.FOREST:
					f_count += 1
					if last_main_zone == Profile.BiomeZone.MOUNTAIN:
						switches += 1
					last_main_zone = Profile.BiomeZone.FOREST
				Profile.BiomeZone.TRANSITION:
					t_count += 1

			if current_zone == -1:
				current_zone = zone
				zone_start_s = s
			elif zone != current_zone:
				zone_lengths.append({"zone": current_zone, "len": s - zone_start_s, "start": zone_start_s, "end": s})
				current_zone = zone
				zone_start_s = s
		zone_lengths.append({"zone": current_zone, "len": max_distance_m - zone_start_s, "start": zone_start_s, "end": max_distance_m})

		_check(switches >= 4, "alternation switches >= 4 (actual=%d) seed=%d" % [switches, seed_value])

		var total_samples: float = float(steps + 1)
		var m_ratio: float = float(m_count) / total_samples
		var f_ratio: float = float(f_count) / total_samples
		var t_ratio: float = float(t_count) / total_samples
		_check(m_ratio >= 0.30 and m_ratio <= 0.85, "mountain ratio in [0.30, 0.85] (actual=%.2f) seed=%d" % [m_ratio, seed_value])
		_check(f_ratio >= 0.08 and f_ratio <= 0.60, "forest ratio in [0.08, 0.60] (actual=%.2f) seed=%d" % [f_ratio, seed_value])
		_check(t_ratio >= 0.05, "transition ratio >= 0.05 (actual=%.2f) seed=%d" % [t_ratio, seed_value])

		for i in range(1, zone_lengths.size() - 1):
			var seg: Dictionary = zone_lengths[i]
			if seg.zone != Profile.BiomeZone.TRANSITION:
				_check(float(seg.len) >= 50.0, "stable non-transition zone length >= 50m (actual=%.1fm) seed=%d start=%.1f" % [seg.len, seed_value, seg.start])
