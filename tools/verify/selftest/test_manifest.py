"""Manifest, TEST_MATRIX cross-check, schema and harness-level failure self-tests."""
import copy
import json
import os
import tempfile
import unittest

from harness import manifest, report
import sc_verify

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(HERE))
SUITES = os.path.join(HERE, "suites.json")


def write_tmp(obj):
    fd, path = tempfile.mkstemp(suffix=".json")
    with os.fdopen(fd, "w") as fh:
        json.dump(obj, fh)
    return path


class Manifest(unittest.TestCase):
    def setUp(self):
        self.data = json.load(open(SUITES, encoding="utf-8"))

    def test_shipped_manifest_loads_and_matches_matrix(self):
        data = manifest.load(SUITES)
        info = manifest.check_matrix(REPO, data)
        self.assertEqual(info["matrix_identity"]["git_blob_head"], data["matrix"]["git_blob"])

    def test_broken_json_is_manifest_invalid(self):
        path = write_tmp({})
        open(path, "w").write("{not json")
        with self.assertRaises(manifest.ManifestError) as cm:
            manifest.load(path)
        self.assertEqual(cm.exception.code, "HARNESS_MANIFEST_INVALID")

    def test_bad_regex_and_duplicate_ids_rejected(self):
        bad = copy.deepcopy(self.data)
        bad["suites"][0]["fail_markers"] = ["("]
        with self.assertRaises(manifest.ManifestError):
            manifest.load(write_tmp(bad))
        dup = copy.deepcopy(self.data)
        dup["suites"].append(dup["suites"][0])
        with self.assertRaises(manifest.ManifestError):
            manifest.load(write_tmp(dup))

    def test_unknown_suite_in_set_is_rejected(self):
        bad = copy.deepcopy(self.data)
        bad["sets"]["pilot"].append("no_such_suite")
        with self.assertRaises(manifest.ManifestError) as cm:
            manifest.load(write_tmp(bad))
        self.assertEqual(cm.exception.code, "HARNESS_UNKNOWN_SUITE")

    def test_unknown_suite_id_on_command_line(self):
        data = manifest.load(SUITES)

        class A:
            set = None
            suite = "does_not_exist"
        with self.assertRaises(manifest.ManifestError) as cm:
            sc_verify.select(data, A)
        self.assertEqual(cm.exception.code, "HARNESS_UNKNOWN_SUITE")

    def test_duplicate_suite_selection_is_rejected_before_execution(self):
        data = manifest.load(SUITES)

        class Dup:
            set = None
            suite = "road_graph,monotony,road_graph"

        with self.assertRaises(manifest.ManifestError) as cm:
            sc_verify.select(data, Dup)
        self.assertEqual(cm.exception.code, "HARNESS_DUPLICATE_SUITE")

        class SetPlusSuite:
            set = "probes"
            suite = "probe_p01_pass"

        with self.assertRaises(manifest.ManifestError) as cm:
            sc_verify.select(data, SetPlusSuite)
        self.assertEqual(cm.exception.code, "HARNESS_DUPLICATE_SUITE")

    def test_duplicate_selection_via_cli_writes_incomplete_run_and_runs_nothing(self):
        import io
        from contextlib import redirect_stdout
        with tempfile.TemporaryDirectory() as d:
            args = sc_verify.argparse.Namespace(suite="road_graph,road_graph", set=None, godot="no-such-godot.exe", output_root=d)
            with redirect_stdout(io.StringIO()):
                code = sc_verify.cmd_run(args)
            self.assertEqual(code, 3)
            run_dirs = os.listdir(d)
            self.assertEqual(len(run_dirs), 1)
            self.assertFalse(os.path.exists(os.path.join(d, run_dirs[0], "checks")))
            rj = json.load(open(os.path.join(d, run_dirs[0], "run.json")))
            self.assertEqual((rj["overall"], rj["harness_error"]["code"]), ("INCOMPLETE", "HARNESS_DUPLICATE_SUITE"))

    def test_path_inside_is_case_insensitive_on_windows_and_never_prefix_matching(self):
        repo = REPO
        self.assertTrue(sc_verify.path_inside(os.path.join(repo, "out"), repo))
        self.assertTrue(sc_verify.path_inside(repo, repo))
        self.assertFalse(sc_verify.path_inside(repo + "-evidence", repo))
        self.assertFalse(sc_verify.path_inside(os.path.dirname(repo), repo))
        if os.name == "nt":
            swapped = repo[0].swapcase() + repo[1:]
            self.assertNotEqual(swapped, repo)
            self.assertTrue(sc_verify.path_inside(os.path.join(swapped, "out"), repo))
            self.assertTrue(sc_verify.path_inside(os.path.join(repo.upper(), "OUT"), repo.lower()))

    def test_output_root_inside_repo_is_refused_regardless_of_drive_letter_case(self):
        import io
        from contextlib import redirect_stdout
        bad = (REPO[0].swapcase() + REPO[1:]) if os.name == "nt" else REPO
        args = sc_verify.argparse.Namespace(suite="road_graph", set=None, godot="x", output_root=os.path.join(bad, "runs_should_not_exist"))
        buf = io.StringIO()
        with redirect_stdout(buf):
            code = sc_verify.cmd_run(args)
        self.assertEqual(code, 3)
        self.assertIn("HARNESS_OUTPUT_ROOT_INSIDE_REPO", buf.getvalue())
        self.assertFalse(os.path.exists(os.path.join(REPO, "runs_should_not_exist")))

    def test_matrix_digest_or_category_mismatch_refuses_to_run(self):
        wrong = copy.deepcopy(self.data)
        wrong["matrix"]["git_blob"] = "0" * 40
        with self.assertRaises(manifest.ManifestError) as cm:
            manifest.check_matrix(REPO, wrong)
        self.assertEqual(cm.exception.code, "MANIFEST_MATRIX_MISMATCH")
        recat = copy.deepcopy(self.data)
        for s in recat["suites"]:
            if s["id"] == "road_graph":
                s["matrix"]["categories"]["GRAPH-KIN"] = "OBSERVATIONAL"
        with self.assertRaises(manifest.ManifestError):
            manifest.check_matrix(REPO, recat)

    def test_allowlist_must_be_exact_text_with_rationale(self):
        for entry in ({"text": "x", "scope": "any"}, {"text": ".*permission.*", "rationale": "r", "scope": "any", "regex": True}):
            bad = copy.deepcopy(self.data)
            bad["environment_allowlist"] = [entry]
            with self.assertRaises(manifest.ManifestError):
                manifest.load(write_tmp(bad))

    def test_every_probe_declares_an_expected_verdict_and_no_matrix_category(self):
        for s in self.data["suites"]:
            if s["origin"] == "probe":
                self.assertIn("expected_verdict", s)
                self.assertEqual(s["matrix"]["categories"], {})

    def test_virtual_rider_keeps_350_of_500_and_limitation(self):
        rider = next(s for s in self.data["suites"] if s["id"] == "virtual_rider")["contract_report"]
        self.assertEqual(rider["declared_target"]["value"], 500)
        self.assertEqual(rider["existing_pass_threshold"]["value"], 350)
        self.assertIn("NOT full 500 m", rider["limitation"])
        self.assertIn("branch", rider["measurement_semantics"])


class Schema(unittest.TestCase):
    def test_validator_flags_missing_and_wrong_values(self):
        schema = report.load_schema(os.path.join(HERE, "schema"), "result.schema.json")
        self.assertTrue(report.validate({}, schema))
        run_schema = report.load_schema(os.path.join(HERE, "schema"), "run.schema.json")
        self.assertTrue(report.validate({"schema": "slow-cycle.verify.run/1", "overall": "GREEN"}, run_schema))


class HarnessFailure(unittest.TestCase):
    def test_harness_failure_run_is_never_pass(self):
        with tempfile.TemporaryDirectory() as d:
            rec = sc_verify.harness_failure(d, "rid", "HARNESS_MANIFEST_INVALID", "x")
            self.assertEqual(rec["overall"], "INCOMPLETE")
            self.assertTrue(os.path.isfile(os.path.join(d, "rid", "run.json")))
            with self.assertRaises(FileExistsError):
                sc_verify.harness_failure(d, "rid", "HARNESS_MANIFEST_INVALID", "x")


if __name__ == "__main__":
    unittest.main()
