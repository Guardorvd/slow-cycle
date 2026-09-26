class_name MountainProfile
extends RefCounted

## Seeded, route-local macro elevation envelope. This is mathematical data only:
## it does not generate road centerlines, terrain meshes, or streamed chunks.
## A finite sum of analytic harmonics makes every query O(1), stateless, and C-infinity.
## Distance is arc length; vertical_rate is dh/ds = sin(grade).

enum MacroRegion {
	RIDGE = 0,
	BENCH = 1,
	VALLEY = 2
}

const PROFILE_VERSION: String = "mountain-profile-v1"
const BASE_VERTICAL_RATE: float = -0.09
const AMPLITUDES: Array[float] = [0.020, 0.013, 0.007]
const WAVELENGTHS_M: Array[float] = [1800.0, 600.0, 300.0]

var world_seed: int
var route_identity: String
var start_elevation_m: float
var _phases: Array[float] = []

func _init(seed_value: int = 184729, route_id: String = "main", start_elevation: float = 0.0) -> void:
	world_seed = seed_value
	route_identity = route_id
	start_elevation_m = start_elevation
	for harmonic_index in range(AMPLITUDES.size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = _stable_seed(harmonic_index)
		_phases.append(rng.randf_range(0.0, TAU))

## Returns elevation, grade, grade rate, macro region, and a 300m reporting index.
## Negative or non-finite distances return an empty Dictionary.
func sample_at(distance_m: float) -> Dictionary:
	if not is_finite(distance_m) or distance_m < 0.0:
		return {}
	var vertical_rate: float = BASE_VERTICAL_RATE
	var vertical_rate_derivative: float = 0.0
	var elevation_delta: float = BASE_VERTICAL_RATE * distance_m
	for i in range(AMPLITUDES.size()):
		var amplitude: float = AMPLITUDES[i]
		var angular_frequency: float = TAU / WAVELENGTHS_M[i]
		var phase: float = angular_frequency * distance_m + _phases[i]
		vertical_rate += amplitude * sin(phase)
		vertical_rate_derivative += amplitude * angular_frequency * cos(phase)
		elevation_delta += (amplitude / angular_frequency) * (cos(_phases[i]) - cos(phase))
	var grade_deg: float = rad_to_deg(asin(clampf(vertical_rate, -0.999, 0.999)))
	var grade_rate_deg_per_m: float = rad_to_deg(vertical_rate_derivative / sqrt(1.0 - vertical_rate * vertical_rate))
	return {
		"distance_m": distance_m,
		"elevation_m": start_elevation_m + elevation_delta,
		"grade_deg": grade_deg,
		"grade_rate_deg_per_m": grade_rate_deg_per_m,
		"vertical_rate": vertical_rate,
		"segment_index": int(floor(distance_m / get_segment_length_m())),
		"macro_region": _macro_region_for_grade(grade_deg)
}

## Macro displacement relative to the constant mean-descent backbone.
func centerline_offset_at(distance_m: float) -> float:
	var sample: Dictionary = sample_at(distance_m)
	if sample.is_empty():
		return 0.0
	return float(sample.elevation_m) - (start_elevation_m + BASE_VERTICAL_RATE * distance_m)

static func get_base_vertical_rate() -> float:
	return BASE_VERTICAL_RATE

func _macro_region_for_grade(grade_deg: float) -> int:
	if grade_deg > -3.8:
		return MacroRegion.RIDGE
	if grade_deg < -5.7:
		return MacroRegion.VALLEY
	return MacroRegion.BENCH

func _stable_seed(harmonic_index: int) -> int:
	var key: String = "%s|%d|%s|%d" % [PROFILE_VERSION, world_seed, route_identity, harmonic_index]
	return int(hash(key) & 0x7FFFFFFF)

static func get_profile_version() -> String:
	return PROFILE_VERSION

static func get_segment_length_m() -> float:
	return 300.0
