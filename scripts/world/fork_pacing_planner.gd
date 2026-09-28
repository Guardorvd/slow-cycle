class_name ForkPacingPlanner
extends RefCounted

## Pure pacing label for one real fork-site candidate. Safety eligibility is supplied by P2.1a/c.
const CHUNK_LENGTH_M: float = 50.0
const MIN_LEG_BAND_M: float = 550.0
const MAX_LEG_BAND_M: float = 900.0
const PACING_DEFERRAL_WINDOW_M: float = 200.0
const PACING_BAND_SLACK_M: float = 5.0

const MOUNTAIN_MIN_LEG_M: float = 200.0
const MOUNTAIN_MAX_LEG_M: float = 350.0
const FOREST_MIN_LEG_M: float = 450.0
const FOREST_MAX_LEG_M: float = 650.0

var min_leg_m: float = MIN_LEG_BAND_M
var max_leg_m: float = MAX_LEG_BAND_M
var mountain_weight: float = 0.5

func update_pacing_for_biome(p_mountain_weight: float) -> void:
	mountain_weight = clampf(p_mountain_weight, 0.0, 1.0)
	min_leg_m = lerpf(FOREST_MIN_LEG_M, MOUNTAIN_MIN_LEG_M, mountain_weight)
	max_leg_m = lerpf(FOREST_MAX_LEG_M, MOUNTAIN_MAX_LEG_M, mountain_weight)

func derive_fork_spacing(seed_value: int, branch_id: int, _is_initial: bool = false) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash([seed_value, branch_id, 71]) & 0x7FFFFFFF)
	return rng.randf_range(min_leg_m, max_leg_m)

func evaluate_candidate(
	scheduled_distance_m: float,
	candidate_distance_m: float,
	rejected_before: int,
	site_eligible: bool,
	is_initial_fork: bool = false
) -> Dictionary:
	if not is_finite(scheduled_distance_m) or scheduled_distance_m < 0.0:
		return _result("invalid", false, ["scheduled_distance_invalid"], {})
	if not is_finite(candidate_distance_m) or candidate_distance_m < 0.0:
		return _result("invalid", false, ["candidate_distance_invalid"], {})
	if rejected_before < 0:
		return _result("invalid", false, ["rejected_count_invalid"], {})
	var delay_m: float = maxf(0.0, candidate_distance_m - scheduled_distance_m)
	var band: String = "initial" if is_initial_fork else "within"
	if not is_initial_fork:
		var low_bound: float = minf(min_leg_m, scheduled_distance_m * 0.85) - PACING_BAND_SLACK_M
		var high_bound: float = maxf(max_leg_m, scheduled_distance_m * 1.25) + PACING_BAND_SLACK_M
		if candidate_distance_m < low_bound:
			band = "short"
		elif candidate_distance_m > high_bound:
			band = "long"
	var overrun: bool = rejected_before >= 4 or delay_m > PACING_DEFERRAL_WINDOW_M
	var reasons: Array[String] = []
	var before_target: bool = candidate_distance_m + 0.001 < scheduled_distance_m
	var decision: String = "wait" if before_target else ("accept" if site_eligible else "defer")
	var accepted: bool = site_eligible and not before_target
	if before_target:
		reasons.append("before_scheduled_distance")
	if overrun:
		reasons.append("pacing_overrun")
	if not site_eligible and not before_target:
		reasons.append("site_or_pair_rejected")
	return _result(decision, accepted, reasons, {
		"scheduled_distance_m": scheduled_distance_m,
		"candidate_distance_m": candidate_distance_m,
		"delay_m": delay_m,
		"rejected_before": rejected_before,
		"candidate_ordinal": rejected_before + 1,
		"pacing_band": band,
		"pacing_overrun": overrun,
		"is_initial_fork": is_initial_fork,
		"min_leg_m": min_leg_m,
		"max_leg_m": max_leg_m,
		"mountain_weight": mountain_weight
	})

func _result(decision: String, eligible: bool, reasons: Array[String], metrics: Dictionary) -> Dictionary:
	return {"decision": decision, "eligible": eligible, "reason_codes": reasons, "metrics": metrics}
