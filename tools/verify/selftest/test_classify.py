"""Classification self-tests: recorded Godot 4.7.2 output samples + synthetic envelopes. No Godot needed."""
import os
import tempfile
import unittest

from harness import classify, evidence
import sc_verify

SAMPLES = os.path.join(os.path.dirname(__file__), "samples")


def sample(name):
    return evidence.read_text(os.path.join(SAMPLES, name))


def proc(exit_code=0, timed_out=False, survivors=None):
    return {"argv": ["x"], "cwd": ".", "spawned": True, "pid": 1, "start_utc": "t", "end_utc": "t", "duration_s": 1.0,
            "timeout_s": 5, "timed_out": timed_out, "exit_code": None if timed_out else exit_code, "spawn_error": None,
            "post_exit_orphans": [], "kill": {"method": "job_object_terminate" if timed_out else None, "job_assigned": True,
                                              "tree_terminated": not survivors if timed_out else None, "survivors": survivors or []}}


SPEC = {"id": "t", "kind": "check", "origin": "probe", "entry": "res://x.gd", "launch": {"mode": "headless", "timeout_s": 5},
        "matrix": {}, "completion": [{"id": "m", "kind": "stdout_regex", "pattern": r"^DONE$"}]}


def run(spec, stdout="", stderr="", p=None, allow=()):
    with tempfile.TemporaryDirectory() as d:
        for n, t in (("stdout.log", stdout), ("stderr.log", stderr), ("engine.log", "Godot Engine v4.7.2\n" + stdout)):
            open(os.path.join(d, n), "w", encoding="utf-8", newline="\n").write(t)
        facts = sc_verify.build_facts(spec, p or proc(), d, 0, list(allow))
        return classify.classify(spec, facts), facts


class RecordedFormats(unittest.TestCase):
    def cats(self, name):
        return [m["category"] for m in evidence.parse_messages("", sample(name))]

    def test_leak(self):
        self.assertEqual(self.cats("godot472_leak.stderr.log"), ["leak"])

    def test_parse_error(self):
        self.assertEqual(self.cats("godot472_parse_error.stderr.log"), ["parse_error", "parse_error"])

    def test_runtime_error_and_assert(self):
        self.assertEqual(self.cats("godot472_runtime_error.stderr.log"), ["script_error"])
        self.assertEqual(self.cats("godot472_assert_failed.stderr.log"), ["assertion_failed"])

    def test_push_error(self):
        self.assertTrue(all(c == "error" for c in self.cats("godot472_push_error_route_fail.stderr.log")))

    def test_continuation_lines_are_not_unknown(self):
        msgs = evidence.parse_messages("", sample("godot472_runtime_error.stderr.log"))
        self.assertEqual(len(msgs), 1)
        self.assertTrue(msgs[0]["detail"])


class Verdicts(unittest.TestCase):
    def test_clean_pass(self):
        res, _ = run(SPEC, "DONE\n")
        self.assertEqual((res["result"], res["reason_code"]), ("PASS", "ALL_REQUIRED_EVIDENCE_SATISFIED"))

    def test_exit_zero_without_marker_is_incomplete(self):
        self.assertEqual(run(SPEC, "nothing\n")[0]["reason_code"], "COMPLETION_NOT_PROVEN")

    def test_nonzero_exit_alone_is_not_fail(self):
        res, _ = run(SPEC, "DONE\n", p=proc(3))
        self.assertEqual((res["result"], res["reason_code"]), ("INCOMPLETE", "NONZERO_EXIT_UNEXPLAINED"))

    def test_nonzero_exit_with_assertion_evidence_is_fail(self):
        res, _ = run(SPEC, "", sample("godot472_assert_failed.stderr.log"), proc(1))
        self.assertEqual((res["result"], res["reason_code"]), ("FAIL", "ASSERTION_FAILED"))

    def test_timeout_is_incomplete_and_orphans_stay_incomplete(self):
        res, _ = run(SPEC, "DONE\n", p=proc(timed_out=True))
        self.assertEqual((res["result"], res["reason_code"]), ("INCOMPLETE", "TIMEOUT"))
        res, _ = run(SPEC, "", p=proc(timed_out=True, survivors=[42]))
        self.assertIn("ORPHAN_PROCESS", res["reasons"])

    def test_leak_in_killed_run_is_never_fail(self):
        spec = dict(SPEC, engine_policy={"leaks": "zero_unexpected"})
        res, _ = run(spec, "", sample("godot472_leak.stderr.log"), proc(timed_out=True))
        self.assertEqual(res["result"], "INCOMPLETE")

    def test_leak_after_normal_completion_follows_declared_gate(self):
        err = sample("godot472_leak.stderr.log")
        gate = dict(SPEC, engine_policy={"leaks": "zero_unexpected"})
        self.assertEqual(run(gate, "DONE\n", err)[0]["reason_code"], "UNEXPECTED_LEAK")
        record = dict(SPEC, engine_policy={"leaks": "record"})
        res, facts = run(record, "DONE\n", err)
        self.assertEqual(res["result"], "PASS")
        self.assertEqual(len(facts["split"]["objectdb_or_leak_warnings"]), 1)

    def test_warning_is_recorded_not_fatal(self):
        res, facts = run(SPEC, "DONE\n", "WARNING: something\n")
        self.assertEqual(res["result"], "PASS")
        self.assertEqual(len(facts["split"]["warnings"]), 1)

    def test_unexpected_engine_error_fails_under_zero_gate(self):
        err = "ERROR: boom\n   at: f (x.cpp:1)\n"
        self.assertEqual(run(SPEC, "DONE\n", err)[0]["reason_code"], "UNEXPECTED_ENGINE_ERROR")

    def test_declared_expected_message_is_matched_exactly_and_kept_visible(self):
        spec = dict(SPEC, engine_policy={"expected": [r"^ERROR: boom$"]})
        res, facts = run(spec, "DONE\n", "ERROR: boom\n")
        self.assertEqual(res["result"], "PASS")
        self.assertEqual(len(facts["split"]["expected_messages"]), 1)

    def test_environment_allowlist_is_exact_and_never_hides_missing_evidence(self):
        allow = [{"text": "ERROR: env thing", "rationale": "r", "scope": "any"}]
        res, facts = run(SPEC, "DONE\n", "ERROR: env thing\n", allow=allow)
        self.assertEqual(res["result"], "PASS")
        self.assertEqual(facts["split"]["expected_environment_messages"][0]["text"], "ERROR: env thing")
        res, _ = run(SPEC, "no marker\n", "ERROR: env thing\n", allow=allow)
        self.assertEqual(res["result"], "INCOMPLETE")
        res, _ = run(SPEC, "DONE\n", "ERROR: env thing 2\n", allow=allow)
        self.assertEqual(res["result"], "FAIL")

    def test_unknown_stderr_line_can_never_pass(self):
        line = "some unprefixed printerr diagnostic\n"
        res, facts = run(SPEC, "DONE\n", line)
        self.assertEqual((res["result"], res["reason_code"]), ("INCOMPLETE", "UNKNOWN_ENGINE_MESSAGE"))
        self.assertEqual([m["text"] for m in facts["split"]["unknown_engine_messages"]], [line.strip()])
        # not FAIL merely for being unknown, and still visible in the verdict detail
        self.assertEqual(res["incomplete_evidence"][0]["detail"], [line.strip()])

    def test_unknown_line_is_resolved_only_by_exact_expected_or_exact_allowlist(self):
        line = "some unprefixed printerr diagnostic\n"
        spec = dict(SPEC, engine_policy={"expected": [r"^some unprefixed printerr diagnostic$"]})
        self.assertEqual(run(spec, "DONE\n", line)[0]["result"], "PASS")
        allow = [{"text": line.strip(), "rationale": "r", "scope": "any"}]
        self.assertEqual(run(SPEC, "DONE\n", line, allow=allow)[0]["result"], "PASS")
        self.assertEqual(run(SPEC, "DONE\n", line + "another one\n", allow=allow)[0]["reason_code"], "UNKNOWN_ENGINE_MESSAGE")

    def test_unknown_line_blocks_pass_even_with_other_failures_listed_first(self):
        res, _ = run(SPEC, "DONE\n", "raw line\n" + sample("godot472_assert_failed.stderr.log"))
        self.assertEqual(res["result"], "FAIL")
        self.assertIn("UNKNOWN_ENGINE_MESSAGE", res["reasons"])

    def test_uncontained_process_cannot_certify_cleanup(self):
        p = proc(timed_out=True)
        p["kill"].update({"containment_established": False, "job_assigned": False, "survivors": ["UNKNOWN"], "tree_terminated": False})
        res, _ = run(SPEC, "", p=p)
        self.assertEqual(res["result"], "INCOMPLETE")
        self.assertIn("CONTAINMENT_UNVERIFIED", res["reasons"])
        p2 = proc(0)
        p2["kill"]["containment_established"] = False
        self.assertEqual(run(SPEC, "DONE\n", p=p2)[0]["result"], "INCOMPLETE")

    def test_missing_executable_is_incomplete(self):
        p = dict(proc(), spawned=False, spawn_error="FileNotFoundError", exit_code=None)
        self.assertEqual(run(SPEC, "", p=p)[0]["reason_code"], "ENGINE_UNAVAILABLE")

    def test_missing_prerequisite_evidence_is_incomplete(self):
        p = dict(proc(), spawned=False, exit_code=None)
        spec = dict(SPEC)
        with tempfile.TemporaryDirectory() as d:
            for n in ("stdout.log", "stderr.log", "engine.log"):
                open(os.path.join(d, n), "w").close()
            facts = sc_verify.build_facts(spec, p, d, 0, [])
            facts["prerequisite_error"] = "no manifest from earlier check"
            self.assertEqual(classify.classify(spec, facts)["reason_code"], "PREREQUISITE_EVIDENCE_MISSING")

    def test_default_without_adapter_is_incomplete(self):
        res, _ = run(dict(SPEC, completion=[]), "DONE\n")
        self.assertEqual(res["reason_code"], "NO_ADAPTER_COMPLETION_UNPROVEN")

    def test_fail_wins_over_incomplete(self):
        res, _ = run(SPEC, "", sample("godot472_assert_failed.stderr.log"), proc(timed_out=True))
        self.assertEqual(res["result"], "FAIL")
        self.assertIn("TIMEOUT", res["reasons"])

    def test_aggregate_never_passes_with_fail_or_incomplete(self):
        self.assertEqual(classify.aggregate(["PASS", "PASS"]), "PASS")
        self.assertEqual(classify.aggregate(["PASS", "INCOMPLETE"]), "INCOMPLETE")
        self.assertEqual(classify.aggregate(["PASS", "INCOMPLETE", "FAIL"]), "FAIL")
        self.assertEqual(classify.aggregate([]), "INCOMPLETE")


class Negatives(unittest.TestCase):
    NEG = dict(SPEC, kind="expected_negative", completion=[],
               expected_negative={"reason": r"^SEED_MISMATCH$", "reason_extract": r"^AUDIT_COMPLETE status=\S+ reason=(\S*) frames=",
                                  "not_exercised": ["RENDERER_UNAVAILABLE"]})

    def out(self, reason):
        return "AUDIT_COMPLETE status=INCOMPLETE reason=%s frames=0/1 run=x\n" % reason

    def test_negative_outcomes(self):
        self.assertEqual(run(self.NEG, self.out("SEED_MISMATCH"), p=proc(1))[0]["result"], "PASS")
        self.assertEqual(run(self.NEG, self.out("OTHER"), p=proc(1))[0]["reason_code"], "NEGATIVE_WRONG_REASON")
        self.assertEqual(run(self.NEG, self.out("RENDERER_UNAVAILABLE"), p=proc(1))[0]["reason_code"], "NEGATIVE_NOT_EXERCISED")
        self.assertEqual(run(self.NEG, "", p=proc(7))[0]["reason_code"], "NEGATIVE_NOT_EXERCISED")
        self.assertEqual(run(self.NEG, self.out("SEED_MISMATCH"), p=proc(0))[0]["reason_code"], "NEGATIVE_ACCEPTED")


if __name__ == "__main__":
    unittest.main()
