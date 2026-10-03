#!/usr/bin/env python3
"""Slow Cycle bounded verification harness (Q1). Evidence/orchestration layer only:

    harness -> existing Godot --script entry point -> real Slow Cycle systems -> evidence -> PASS/FAIL/INCOMPLETE

Python standard library only. Usage: see tools/verify/README.md.
"""
import argparse
import json
import os
import platform
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

from harness import classify, evidence, identity, manifest, process, report  # noqa: E402

SCHEMA_DIR = os.path.join(HERE, "schema")
RESULT_SCHEMA, RUN_SCHEMA = "slow-cycle.verify.result/1", "slow-cycle.verify.run/1"
LAUNCH_FLAGS = {"headless": ["--headless"],
                "vulkan": ["--rendering-driver", "vulkan", "--windowed", "--resolution", "1280x720"]}
PROBE_PROJECT = os.path.join(HERE, "fixtures", "probe_project")
UNKNOWN = "UNKNOWN"


def sub(value, vars_):
    return re.sub(r"\{(\w+)\}", lambda m: vars_.get(m.group(1), m.group(0)), value)


def build_facts(spec, proc, check_dir, start_epoch, allow):
    stdout_text = evidence.read_text(os.path.join(check_dir, "stdout.log"))
    stderr_text = evidence.read_text(os.path.join(check_dir, "stderr.log"))
    engine_log = evidence.read_text(os.path.join(check_dir, "engine.log"))
    text = stdout_text + "\n" + stderr_text
    policy = spec.get("engine_policy", {})
    msgs = evidence.parse_messages(stdout_text, stderr_text)
    split = evidence.split_messages(msgs, policy.get("expected", []), allow)
    failures, malformed, summaries = evidence.eval_summaries(spec.get("summaries", []), text)
    facts = {
        "proc": proc, "split": split, "text": text,
        "log_complete": ("Godot Engine v" in engine_log) if proc["spawned"] else None,
        "summary_failures": failures, "malformed": malformed, "summaries": summaries,
        "fail_marker_hits": [m.group(0)[:200] for p in spec.get("fail_markers", []) for m in re.finditer(p, text, re.M)],
        "completion": evidence.eval_completion(spec.get("completion", []), text, check_dir),
        "coverage": evidence.eval_coverage(spec.get("coverage", []), text, check_dir),
        "runner_timeout": None, "negative": None,
    }
    if spec["kind"] == "check" and re.search(r"status=INCOMPLETE reason=TIMEOUT", text):
        facts["runner_timeout"] = "runner watchdog reported status=INCOMPLETE reason=TIMEOUT"
    if spec["kind"] == "expected_negative":
        neg = spec["expected_negative"]
        hits = [h for h in re.findall(neg["reason_extract"], text, re.M) if h] if neg.get("reason_extract") else []
        reported = hits[-1] if hits else None
        found = bool(reported and re.search(neg["reason"], reported)) if neg.get("reason_extract") else bool(re.search(neg["reason"], text))
        facts["negative"] = {"expected": neg["reason"], "reported_reason": reported, "reason_found": found,
                             "not_exercised_reason": reported if reported and reported in neg.get("not_exercised", []) else None}
    recs, missing, stale, invalid = evidence.eval_artifacts(spec.get("artifacts", []), check_dir, start_epoch)
    facts["artifacts"] = {"records": recs, "missing": missing, "stale": stale, "invalid": invalid}
    facts["seeds"] = _seeds(spec.get("seeds"), check_dir)
    facts["gates"] = _gates(spec.get("evidence_gate", {}), text, check_dir, facts["artifacts"])
    return facts


def _seeds(spec, check_dir):
    if not spec:
        return {"requested": None, "observed": None, "basis": "not_observable", "certified": None}
    obs = set()
    if spec.get("observed"):
        import glob
        for path in glob.glob(os.path.join(check_dir, spec["observed"]["glob"]), recursive=True):
            val, _ = evidence._json_value(os.path.dirname(path), os.path.basename(path), spec["observed"]["field"])
            if val is not None:
                obs.add(val)
    req = set(spec["requested"])
    return {"requested": sorted(req), "observed": sorted(obs), "basis": "session_manifest" if obs else "not_observable",
            "certified": (obs == req) if spec.get("require_observed", True) else None}


def _gates(gates, text, check_dir, art):
    out = {}
    for level, gate in gates.items():
        missing = []
        for req in gate["requires"]:
            if req == "driver_vulkan":
                ok = bool(re.search(r"^Vulkan \d+\.\d+", text, re.M))
                if ok and gate.get("manifest"):
                    val, found = evidence._json_value(check_dir, gate["manifest"]["glob"], "driver")
                    ok = found and val == "vulkan"
                if not ok:
                    missing.append("driver_vulkan")
            elif req == "frames_saved":
                if art["missing"] or art["stale"] or art["invalid"] or not art["records"]:
                    missing.append("frames_saved")
        out[level] = {"satisfied": not missing, "missing": missing, "human_review": gate.get("human_review")}
    return out


def execute_check(spec, ctx):
    cid = spec["id"]
    check_dir = os.path.join(ctx["run_dir"], "checks", cid)
    for sub_dir in ("diag", "audit", "out"):
        os.makedirs(os.path.join(check_dir, sub_dir), exist_ok=True)
    for pp in spec.get("preplant", []):
        path = os.path.join(check_dir, pp["path"])
        os.makedirs(os.path.dirname(path), exist_ok=True)
        open(path, "wb").write(b"stale artifact planted by harness probe\n")
        old = time.time() - pp["age_s"]
        os.utime(path, (old, old))
    vars_ = {"check_dir": check_dir.replace(os.sep, "/"), "diag": check_dir.replace(os.sep, "/") + "/diag",
             "audit": check_dir.replace(os.sep, "/") + "/audit", "out": check_dir.replace(os.sep, "/") + "/out"}
    launch = spec["launch"]
    project = PROBE_PROJECT if spec["origin"] == "probe" else REPO
    extra = [sub(a, vars_) for a in launch.get("user_args", [])]
    rf = spec.get("replay_from")
    replay_error = None
    if rf:
        prior = ctx["checks_dirs"].get(rf["check"])
        import glob
        found = sorted(glob.glob(os.path.join(prior, rf["glob"]))) if prior else []
        if found:
            extra.append("--replay-manifest=" + found[0].replace(os.sep, "/"))
        else:
            replay_error = "no manifest produced by earlier check %s in this run" % rf["check"]
    if spec["origin"] == "repo":
        extra += ["--diagnostics-root=" + vars_["diag"], "--audit-output-root=" + vars_["audit"]]
    argv = [ctx["godot"]] + LAUNCH_FLAGS[launch["mode"]] + ["--path", project.replace(os.sep, "/"), "--log-file",
            vars_["check_dir"] + "/engine.log", "--script", spec["entry"]] + (["--"] + extra if extra else [])
    start_epoch = time.time() - 0.05
    if replay_error:
        proc = {"argv": argv, "cwd": project, "spawned": False, "pid": None, "start_utc": process.utc_now(),
                "end_utc": process.utc_now(), "duration_s": 0.0, "timeout_s": launch["timeout_s"], "timed_out": False,
                "exit_code": None, "spawn_error": None, "post_exit_orphans": [],
                "kill": {"method": None, "tree_terminated": None, "survivors": [], "job_assigned": None}}
        for name in ("stdout.log", "stderr.log"):
            open(os.path.join(check_dir, name), "wb").close()
    else:
        proc = process.run_bounded(argv, project, os.path.join(check_dir, "stdout.log"),
                                   os.path.join(check_dir, "stderr.log"), launch["timeout_s"])
    allow = [e for e in ctx["manifest"].get("environment_allowlist", []) if e["scope"] in ("any", "platform:" + sys.platform)]
    facts = build_facts(spec, proc, check_dir, start_epoch, allow)
    facts["prerequisite_error"] = replay_error
    verdict = classify.classify(spec, facts)
    return assemble(spec, ctx, proc, facts, verdict, check_dir, argv)


def assemble(spec, ctx, proc, facts, verdict, check_dir, argv):
    split, mx = facts["split"], spec["matrix"]
    meas = {}
    for name, m in spec.get("measurements", {}).items():
        hit = re.search(m["pattern"], facts["text"], re.M)
        meas[name] = float(hit.group(m["group"])) if hit else None
    contract = None
    if spec.get("contract_report"):
        contract = dict(spec["contract_report"])
        contract.update({"actual_progress": meas.get("actual_progress"), "unit": spec["measurements"]["actual_progress"].get("unit")})
    env_names = sorted(os.environ.keys())
    return {
        "schema": RESULT_SCHEMA, "run_id": ctx["run_id"], "purpose": ctx["purpose"], "attempt": 1,
        "revision": ctx["source"]["head"], "git_identity": ctx["source"],
        "suite_id": spec["id"], "kind": spec["kind"], "origin": spec["origin"],
        "test_matrix": {"rows": mx.get("rows", []), "categories": mx.get("categories", {})},
        "authority_category": mx.get("authority_category"), "evidence_capability": mx.get("e_capability"),
        "role": mx.get("role"),
        "seed": {"policy": spec.get("seed_policy", "suite default; harness never passes --seed"), **facts["seeds"]},
        "config": {"launch": spec["launch"], "engine_policy": spec.get("engine_policy", {}), "entry": spec["entry"]},
        "command": {"argv": argv, "cwd": proc["cwd"]},
        "environment": {"engine": ctx["engine"], "platform": platform.platform(), "python": sys.version.split()[0],
                        "env_overrides": {}, "inherited_variable_names": env_names,
                        "note": "values of inherited variables are intentionally not recorded"},
        "expected_coverage": spec.get("coverage", []), "actual_coverage": facts["coverage"],
        "expected_checks_if_truly_known": facts_assert(spec, facts)["expected"],
        "certified_actual_checks_if_measurable": facts_assert(spec, facts)["actual"],
        "completion_marker": {"required": spec.get("completion", []), "observed": facts["completion"],
                              "satisfied": bool(spec.get("completion")) and all(c["satisfied"] for c in facts["completion"])},
        "runner_summaries": facts["summaries"],
        "artifacts": facts["artifacts"]["records"],
        "artifact_problems": {k: facts["artifacts"][k] for k in ("missing", "stale", "invalid")},
        "exit_code": proc["exit_code"], "process": {k: proc[k] for k in ("spawned", "pid", "spawn_error", "post_exit_orphans")},
        "timeout": {"timeout_s": proc["timeout_s"], "timed_out": proc["timed_out"], "kill": proc["kill"]},
        "errors": {"project_errors": split["project_errors"], "parse_errors": split["parse_errors"],
                   "script_errors": split["script_errors"], "assertion_failures": split["assertion_failures"]},
        "warnings": split["warnings"], "leaks": split["objectdb_or_leak_warnings"],
        "environment_messages": split["expected_environment_messages"],
        "engine_messages": {"project_errors": split["project_errors"], "warnings": split["warnings"],
                            "objectdb_or_leak_warnings": split["objectdb_or_leak_warnings"],
                            "expected_environment_messages": split["expected_environment_messages"],
                            "expected_messages": split["expected_messages"],
                            "unknown_engine_messages": split["unknown_engine_messages"],
                            "log_complete": facts["log_complete"]},
        "evidence_gates": facts["gates"], "negative": facts["negative"], "measurements": meas, "contract_report": contract,
        "start_time": proc["start_utc"], "end_time": proc["end_utc"], "duration": proc["duration_s"],
        "result": verdict["result"], "reason_code": verdict["reason_code"], "reasons": verdict["reasons"],
        "verdict_detail": {"fail_evidence": verdict["fail_evidence"], "incomplete_evidence": verdict["incomplete_evidence"],
                           "meaning": verdict["meaning"]},
        "limitations": spec.get("limitations", []) + ([] if not facts["split"]["objectdb_or_leak_warnings"] or
                    spec.get("engine_policy", {}).get("leaks") == "zero_unexpected" else
                    ["leak warning recorded; this suite declares no zero-leak gate (not a verdict input)"]),
        "evidence_claims": {"supported": spec.get("matrix", {}).get("e_capability"), "not_claimed": spec.get("not_claimed", [])},
        "raw": {"stdout": "stdout.log", "stderr": "stderr.log", "engine_log": "engine.log"},
        "probe_expectation": spec.get("expected_verdict"),
    }


def facts_assert(spec, facts):
    return evidence.eval_assertions(spec.get("assertions"), facts["text"])


def path_inside(path, root):
    """Windows-aware containment: resolved + case-normalised paths, compared by commonpath (never a string prefix)."""
    p = os.path.normcase(os.path.realpath(path))
    r = os.path.normcase(os.path.realpath(root))
    try:
        return os.path.commonpath([p, r]) == r
    except ValueError:  # different drives
        return False


def select(data, args):
    by_id = {s["id"]: s for s in data["suites"]}
    ids = []
    if args.set:
        if args.set not in data["sets"]:
            raise manifest.ManifestError("HARNESS_UNKNOWN_SUITE", "unknown set %s" % args.set)
        ids += data["sets"][args.set]
    for i in (args.suite.split(",") if args.suite else []):
        ids.append(i)
    if not ids:
        raise manifest.ManifestError("HARNESS_UNKNOWN_SUITE", "no suite selected")
    for i in ids:
        if i not in by_id:
            raise manifest.ManifestError("HARNESS_UNKNOWN_SUITE", "unknown suite id %s" % i)
    dups = sorted({i for i in ids if ids.count(i) > 1})
    if dups:
        raise manifest.ManifestError("HARNESS_DUPLICATE_SUITE",
                                     "suite selected more than once (a check directory and its evidence are never reused): %s" % ", ".join(dups))
    return [by_id[i] for i in ids]


def harness_failure(out_root, run_id, code, detail):
    run_dir = os.path.join(out_root, run_id)
    os.makedirs(run_dir, exist_ok=False)
    rec = {"schema": RUN_SCHEMA, "run_id": run_id, "purpose": "q1-harness-pilot", "overall": "INCOMPLETE",
           "harness_error": {"code": code, "detail": detail}, "checks": [], "counts": {"PASS": 0, "FAIL": 0, "INCOMPLETE": 0},
           "selected": [], "not_run": [], "start_time": process.utc_now(), "end_time": process.utc_now(),
           "probe_matrix": None, "revision": None}
    report.write_json(os.path.join(run_dir, "run.json"), rec)
    return rec


def cmd_run(args):
    out_root = os.path.abspath(args.output_root)
    if path_inside(out_root, REPO):
        print("HARNESS_OUTPUT_ROOT_INSIDE_REPO: refusing to write run data into the repository")
        return 3
    os.makedirs(out_root, exist_ok=True)
    run_id = identity.new_run_id()
    try:
        data = manifest.load(os.path.join(HERE, "suites.json"))
        suites = select(data, args)
        matrix_check = manifest.check_matrix(REPO, data, suites)
    except manifest.ManifestError as exc:
        harness_failure(out_root, run_id, exc.code, exc.detail)
        print("%s: %s\nrun_id=%s overall=INCOMPLETE" % (exc.code, exc.detail, run_id))
        return 3
    engine = identity.engine_identity(args.godot)
    source = identity.source_identity(REPO)
    run_dir = os.path.join(out_root, run_id)
    os.makedirs(os.path.join(run_dir, "checks"), exist_ok=False)
    purpose = "q1-harness-probes" if all(s["origin"] == "probe" for s in suites) else "q1-harness-pilot"
    ctx = {"run_id": run_id, "run_dir": run_dir, "godot": args.godot, "engine": engine, "source": source,
           "manifest": data, "purpose": purpose, "checks_dirs": {}}
    start = process.utc_now()
    results = []
    schema = report.load_schema(SCHEMA_DIR, "result.schema.json")
    for spec in suites:
        res = execute_check(spec, ctx)
        res["manifest_identity"] = {"matrix": matrix_check["matrix_identity"],
                                    "suites_json_sha256": identity.sha256_file(os.path.join(HERE, "suites.json"))}
        problems = report.validate(res, schema)
        if problems:
            res["result"], res["reason_code"] = "INCOMPLETE", "MALFORMED_RESULT"
            res["reasons"] = ["MALFORMED_RESULT"] + res["reasons"]
            res["schema_problems"] = problems
        ctx["checks_dirs"][spec["id"]] = os.path.join(run_dir, "checks", spec["id"])
        report.write_json(os.path.join(run_dir, "checks", spec["id"], "result.json"), res)
        results.append(res)
        print("%-34s %-10s %-28s exit=%s %.1fs" % (spec["id"], res["result"], res["reason_code"], res["exit_code"], res["duration"] or 0))
    write_run(run_dir, ctx, suites, results, start, args)
    return exit_code(results, suites)


def write_run(run_dir, ctx, suites, results, start, args):
    probe_rows = None
    if any(s["origin"] == "probe" for s in suites):
        probe_rows = [{"suite_id": r["suite_id"], "expected": r["probe_expectation"],
                       "actual": {"result": r["result"], "reason_code": r["reason_code"]},
                       "match": bool(r["probe_expectation"]) and r["probe_expectation"]["result"] == r["result"] and
                       r["probe_expectation"]["reason"] == r["reason_code"]} for r in results]
    counts = {k: sum(1 for r in results if r["result"] == k) for k in ("PASS", "FAIL", "INCOMPLETE")}
    manifest_rows = []
    for r in results:
        for a in r["artifacts"]:
            p = os.path.join(run_dir, "checks", r["suite_id"], a["path"])
            manifest_rows.append({"suite_id": r["suite_id"], "path": "checks/%s/%s" % (r["suite_id"], a["path"]),
                                  "role": a["role"], "bytes": a["bytes"], "fresh": a["fresh"], "sha256": identity.sha256_file(p)})
    report.write_json(os.path.join(run_dir, "artifact_manifest.json"), {"run_id": ctx["run_id"], "artifacts": manifest_rows})
    run = {"schema": RUN_SCHEMA, "run_id": ctx["run_id"], "purpose": ctx["purpose"], "revision": ctx["source"]["head"],
           "git_identity": ctx["source"], "engine": ctx["engine"], "selected": [s["id"] for s in suites],
           "not_run": [], "checks": [{"suite_id": r["suite_id"], "result": r["result"], "reason_code": r["reason_code"],
                                      "exit_code": r["exit_code"], "duration": r["duration"]} for r in results],
           "counts": counts, "overall": classify.aggregate([r["result"] for r in results]),
           "probe_matrix": None if probe_rows is None else {"rows": probe_rows, "expectations_met": all(p["match"] for p in probe_rows)},
           "notice": "q1-harness evidence for the verification mechanism; not a Slow Cycle acceptance or Q2 baseline.",
           "start_time": start, "end_time": process.utc_now()}
    problems = report.validate(run, report.load_schema(SCHEMA_DIR, "run.schema.json"))
    if problems:
        run["overall"], run["schema_problems"] = "INCOMPLETE", problems
    report.write_json(os.path.join(run_dir, "run.json"), run)
    print("run_id=%s overall=%s %s%s" % (ctx["run_id"], run["overall"], counts,
          "" if probe_rows is None else " probe_expectations_met=%s" % run["probe_matrix"]["expectations_met"]))
    print("run_dir=" + run_dir)


def exit_code(results, suites):
    if all(s["origin"] == "probe" for s in suites):
        ok = all(r["probe_expectation"] and r["probe_expectation"]["result"] == r["result"] and
                 r["probe_expectation"]["reason"] == r["reason_code"] for r in results)
        return 0 if ok else 1
    agg = classify.aggregate([r["result"] for r in results])
    return {"PASS": 0, "FAIL": 1, "INCOMPLETE": 2}[agg]


def cmd_list(_args):
    data = manifest.load(os.path.join(HERE, "suites.json"))
    for name, ids in data["sets"].items():
        print("set %s: %s" % (name, ", ".join(ids)))
    for s in data["suites"]:
        print("%-34s %-17s %-5s %s" % (s["id"], s["kind"], s["origin"], s["entry"]))
    return 0


def cmd_check_manifest(_args):
    try:
        data = manifest.load(os.path.join(HERE, "suites.json"))
        info = manifest.check_matrix(REPO, data)
    except manifest.ManifestError as exc:
        print(exc)
        return 3
    print("manifest OK: %d suites; TEST_MATRIX blob %s, %d rows" % (len(data["suites"]),
          info["matrix_identity"]["git_blob_head"], info["rows_in_matrix"]))
    return 0


def cmd_selftest(_args):
    import unittest
    suite = unittest.defaultTestLoader.discover(os.path.join(HERE, "selftest"))
    return 0 if unittest.TextTestRunner(verbosity=1).run(suite).wasSuccessful() else 1


def main(argv=None):
    ap = argparse.ArgumentParser(prog="sc_verify.py")
    sp = ap.add_subparsers(dest="cmd", required=True)
    r = sp.add_parser("run")
    r.add_argument("--suite")
    r.add_argument("--set")
    r.add_argument("--godot", required=True)
    r.add_argument("--output-root", required=True)
    r.set_defaults(fn=cmd_run)
    sp.add_parser("list").set_defaults(fn=cmd_list)
    sp.add_parser("check-manifest").set_defaults(fn=cmd_check_manifest)
    sp.add_parser("selftest").set_defaults(fn=cmd_selftest)
    args = ap.parse_args(argv)
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main())
