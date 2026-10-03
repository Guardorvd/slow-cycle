"""The single owner of PASS / FAIL / INCOMPLETE.

Rules (plan section A + 6.5):
  FAIL        only reliable evidence that a product/test/gate contract was violated.
  INCOMPLETE  required evidence could not be established (timeout, missing marker/coverage/artifact,
              environment or launcher failure, unexplained termination, unavailable Vulkan ...).
  PASS        every required item satisfied, nothing unexpected under the applicable gate policy.
A nonzero exit code alone never produces FAIL; kill-induced noise never converts a timeout into FAIL.
Unknown / untrusted state defaults to INCOMPLETE, never PASS.
"""

PASS, FAIL, INCOMPLETE = "PASS", "FAIL", "INCOMPLETE"


def classify(spec, facts):
    fails, incs = [], []

    def fail(code, detail=None):
        fails.append({"code": code, "detail": detail})

    def inc(code, detail=None):
        incs.append({"code": code, "detail": detail})

    proc = facts["proc"]
    policy = spec.get("engine_policy", {})
    split = facts["split"]
    kind = spec.get("kind", "check")

    if facts.get("prerequisite_error"):
        inc("PREREQUISITE_EVIDENCE_MISSING", facts["prerequisite_error"])
        return _verdict(fails, incs, kind)
    if not proc["spawned"]:
        inc("ENGINE_UNAVAILABLE", proc.get("spawn_error"))
        return _verdict(fails, incs, kind)

    killed = proc["timed_out"]
    if killed:
        inc("TIMEOUT", "no exit within %ss; process tree killed (%s)" % (proc["timeout_s"], proc["kill"]["method"]))
        if proc["kill"]["survivors"]:
            inc("ORPHAN_PROCESS", proc["kill"]["survivors"])
    if proc["post_exit_orphans"]:
        inc("ORPHAN_PROCESS", proc["post_exit_orphans"])
    if facts.get("log_complete") is False:
        inc("LOG_INCOMPLETE")
    if proc["kill"].get("containment_established") is False:
        inc("CONTAINMENT_UNVERIFIED", "process was not placed under tree containment; cleanup and orphans cannot be certified")
    # An unrecognised stderr line is unclassified evidence: never PASS, and not FAIL merely for being unknown.
    # Lines handled by a declared expected pattern or an exact environment allowlist entry are already out of this bucket.
    if split["unknown_engine_messages"]:
        inc("UNKNOWN_ENGINE_MESSAGE", [m["text"] for m in split["unknown_engine_messages"]])

    # ---- explicit contract violations (valid even when the run was later killed: they were emitted before) ----
    if facts["summary_failures"]:
        fail("ASSERTION_FAILED", "runner summary reports failures=%d" % facts["summary_failures"])
    for hit in facts["fail_marker_hits"]:
        fail("ASSERTION_FAILED", hit)
    for m in split["assertion_failures"]:
        fail("ASSERTION_FAILED", m["text"])
    for m in split["parse_errors"]:
        fail("ENGINE_PARSE_ERROR", m["text"])
    if policy.get("errors", "zero_unexpected") == "zero_unexpected":
        for m in split["project_errors"]:
            if m not in split["parse_errors"] and m not in split["assertion_failures"]:
                fail("UNEXPECTED_ENGINE_ERROR", m["text"])
    completed_normally = (not killed) and proc["exit_code"] is not None
    if policy.get("leaks", "record") == "zero_unexpected" and completed_normally:
        for m in split["objectdb_or_leak_warnings"]:
            fail("UNEXPECTED_LEAK", m["text"])

    # ---- expected-negative: sensitivity, not product acceptance ----
    if kind == "expected_negative":
        neg = facts["negative"]
        if completed_normally and proc["exit_code"] == 0:
            fail("NEGATIVE_ACCEPTED", "invalid input was accepted (exit 0)")
        elif neg["reason_found"]:
            pass
        elif neg["not_exercised_reason"]:
            inc("NEGATIVE_NOT_EXERCISED", "runner reported %s" % neg["not_exercised_reason"])
        elif neg["reported_reason"]:
            fail("NEGATIVE_WRONG_REASON", "expected /%s/ got %s" % (neg["expected"], neg["reported_reason"]))
        elif not killed:
            inc("NEGATIVE_NOT_EXERCISED", "no reason reported (crash or unknown termination)")
    else:
        expect_exit = spec.get("launch", {}).get("expect_exit", 0)
        if completed_normally and proc["exit_code"] != expect_exit and not fails:
            inc("NONZERO_EXIT_UNEXPLAINED", "exit_code=%s without contract-violation evidence" % proc["exit_code"])
        if not spec.get("completion"):
            inc("NO_ADAPTER_COMPLETION_UNPROVEN")
        elif not all(c["satisfied"] for c in facts["completion"]):
            inc("COMPLETION_NOT_PROVEN", [c["id"] for c in facts["completion"] if not c["satisfied"]])

    if facts["malformed"]:
        inc("MALFORMED_RESULT", facts["malformed"])
    if facts["runner_timeout"]:
        inc("RUNNER_TIMEOUT", facts["runner_timeout"])
    missing_cov = [c["id"] for c in facts["coverage"] if not c["satisfied"]]
    if missing_cov:
        inc("COVERAGE_MISSING", missing_cov)
    art = facts["artifacts"]
    if art["missing"]:
        inc("ARTIFACT_MISSING", art["missing"])
    if art["stale"]:
        inc("ARTIFACT_STALE", art["stale"])
    if art["invalid"]:
        inc("ARTIFACT_INVALID", art["invalid"])
    if facts["seeds"].get("certified") is False:
        inc("SEED_NOT_CERTIFIED", facts["seeds"])
    for level, gate in facts["gates"].items():
        if not gate["satisfied"]:
            inc("VULKAN_EVIDENCE_MISSING" if level == "E5" else "EVIDENCE_GATE_UNSATISFIED", gate["missing"])
    return _verdict(fails, incs, kind)


def _verdict(fails, incs, kind):
    if fails:
        primary, result = fails[0]["code"], FAIL
    elif incs:
        primary, result = incs[0]["code"], INCOMPLETE
    else:
        primary, result = "ALL_REQUIRED_EVIDENCE_SATISFIED", PASS
    return {"result": result, "reason_code": primary,
            "reasons": [f["code"] for f in fails] + [i["code"] for i in incs],
            "fail_evidence": fails, "incomplete_evidence": incs,
            "meaning": "negative path exercised with expected reason" if kind == "expected_negative" and result == PASS else None}


def aggregate(results):
    """Aggregate PASS is impossible when any constituent is FAIL or INCOMPLETE (or when nothing ran)."""
    if not results:
        return INCOMPLETE
    if any(r == FAIL for r in results):
        return FAIL
    if any(r != PASS for r in results):
        return INCOMPLETE
    return PASS
