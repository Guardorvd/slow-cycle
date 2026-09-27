class_name ForkPacingPlanner
extends RefCounted

## Pure pacing label for one real fork-site candidate. Safety eligibility is supplied by P2.1a/c.
const CHUNK_LENGTH_M: float = 50.0
const MIN_LEG_BAND_M: float = 550.0
const MAX_LEG_BAND_M: float = 900.0
const PACING_DEFERRAL_WINDOW_M: float = 200.0

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
		if candidate_distance_m < MIN_LEG_BAND_M:
			band = "short"
		elif candidate_distance_m > MAX_LEG_BAND_M:
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
		"is_initial_fork": is_initial_fork
	})

func _result(decision: String, eligible: bool, reasons: Array[String], metrics: Dictionary) -> Dictionary:
	return {"decision": decision, "eligible": eligible, "reason_codes": reasons, "metrics": metrics}
