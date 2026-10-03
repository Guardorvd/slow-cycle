# Slow Cycle bounded verification harness (Q1)

Evidence/orchestration layer. It launches **existing** Godot test entry points as bounded child processes and
reports what was actually proven. It contains no game logic and no second copy of any test oracle.

```
harness -> existing --script entry point -> real Slow Cycle systems -> raw evidence -> PASS / FAIL / INCOMPLETE
```

Python 3 standard library only. The harness is never imported by the game; `.gdignore` hides this directory from
Godot's project scan. Its own probe project (`fixtures/probe_project`) exists only to test classification.

STATUS: Q1 pilot evidence only. A harness run is **not** a Slow Cycle acceptance, **not** a Q2 frozen baseline and
not an E7 ride. See `implementation_plan.md` (section A amendments) and `docs/TEST_STRATEGY.md`.

## Commands

```
python tools/verify/sc_verify.py list
python tools/verify/sc_verify.py check-manifest
python tools/verify/sc_verify.py selftest                      # no Godot needed
python tools/verify/sc_verify.py run --set probes --godot <godot console exe> --output-root <dir outside repo>
python tools/verify/sc_verify.py run --set pilot  --godot <godot console exe> --output-root <dir outside repo>
python tools/verify/sc_verify.py run --suite road_graph,monotony --godot <exe> --output-root <dir>
```

`--output-root` must be outside the repository. Every invocation creates a new `<output-root>/<UTC>-<8 hex>/`
(`run_id`); nothing is reused, retried or deleted. Inside: `run.json`, `artifact_manifest.json` and per check
`checks/<id>/{stdout.log, stderr.log, engine.log, result.json, diag/, audit/, out/}`. Raw `stdout.log` / `stderr.log`
are the child's bytes, kept separately from every parsed summary. Artifacts are only accepted from the current
check's own directory and only if newer than the process start (previous runs can never satisfy a gate).

Harness exit code: `0` all PASS (probe sets: every probe verdict equals its declared expectation); `1` a FAIL (probe
sets: expectation mismatch); `2` no FAIL but INCOMPLETE; `3` harness-level error (bad manifest, unknown suite,
matrix mismatch, output root inside repo). Exit 3 still writes an INCOMPLETE `run.json` when it can.

## Verdicts

| Result | Meaning |
|---|---|
| `PASS` | every required item proven: completion marker, declared coverage, required fresh artifacts, expected exit code, nothing unexpected under the suite's declared gate policy |
| `FAIL` | reliable evidence that a product/test/gate contract was violated (failed assertion/summary, explicit fail marker, parse/script/engine error attributable to the tested source, wrong or accepted expected-negative, leak after a normally completed run where the suite declares a zero-leak gate) |
| `INCOMPLETE` | required evidence could not be established (timeout, no completion marker, missing coverage/artifact/log, launcher or engine failure, unexplained termination, unavailable Vulkan, orphan process) |

Rules: a nonzero exit code alone is never FAIL; exit 0 alone is never PASS; forced-kill shutdown noise never turns a
timeout into FAIL (a leak counts only after a normal completion); warnings are recorded but are never globally fatal;
FAIL outranks INCOMPLETE (both reason lists are kept). Aggregate PASS is impossible if any constituent is FAIL or
INCOMPLETE, or if nothing ran.

Reason codes: `ASSERTION_FAILED`, `ENGINE_PARSE_ERROR`, `UNEXPECTED_ENGINE_ERROR`, `UNEXPECTED_LEAK`,
`NEGATIVE_WRONG_REASON`, `NEGATIVE_ACCEPTED` (FAIL); `TIMEOUT`, `RUNNER_TIMEOUT`, `COMPLETION_NOT_PROVEN`,
`NO_ADAPTER_COMPLETION_UNPROVEN`, `NONZERO_EXIT_UNEXPLAINED`, `COVERAGE_MISSING`, `ARTIFACT_MISSING`,
`ARTIFACT_STALE`, `ARTIFACT_INVALID`, `SEED_NOT_CERTIFIED`, `VULKAN_EVIDENCE_MISSING`, `NEGATIVE_NOT_EXERCISED`,
`ENGINE_UNAVAILABLE`, `PREREQUISITE_EVIDENCE_MISSING`, `UNKNOWN_ENGINE_MESSAGE`, `CONTAINMENT_UNVERIFIED`, `LOG_INCOMPLETE`, `ORPHAN_PROCESS`, `MALFORMED_RESULT`, `HARNESS_MANIFEST_INVALID`,
`HARNESS_UNKNOWN_SUITE`, `HARNESS_DUPLICATE_SUITE`, `MANIFEST_MATRIX_MISMATCH` (INCOMPLETE / harness).

## Result record (`slow-cycle.verify.result/1`)

Fields: schema, run_id, revision, git_identity (HEAD, tree, branch, staged/unstaged/untracked, tracked diff sha256,
raw working-tree sha256 as a supplemental value), suite_id, test_matrix rows/categories, authority_category,
evidence_capability, seed (requested / observed / basis / certified), config, command, environment (engine path,
sha256, version; variable *names* only), expected_coverage / actual_coverage, expected and certified-actual checks,
completion_marker, artifacts, exit_code, timeout (+ kill record and survivors), errors, warnings, leaks,
engine_messages (`project_errors`, `warnings`, `objectdb_or_leak_warnings`, `expected_environment_messages`,
`expected_messages`, `unknown_engine_messages`), start/end/duration, result, reason_code, reasons, limitations,
contract_report. Unknown data is `null` / `NOT_MEASURED` / basis `not_measurable`; counts are never invented. In
particular the Sprint 4M master budget `125` (68/6/8/15/16) is recorded only as *expected*; its children are
certified by running them directly. Identity is Git-first (`HEAD`, tree, dirty state); LF-normalised hashes appear only
as labelled compatibility values (`compat_lf_sha256`) and never hide a dirty file.

## Engine message policy

Messages are parsed from the raw streams, never removed. Buckets: project errors (`ERROR:` / `SCRIPT ERROR:`, parse
errors, assertion failures), warnings, ObjectDB/leak warnings, expected messages (declared per suite as regexes, e.g.
intentional I/O negatives), environment messages (`environment_allowlist` in `suites.json`: exact text, rationale and
scope required, never a regex; currently **empty**) and unknown stderr lines. A suite's `engine_policy` states whether
errors / leaks must be zero. Leaks gate only the suites that declare `zero_unexpected` (the world AGENTS G gates). The default leak policy is `record`; zero-leak is only ever an explicit per-suite/gate declaration. An unrecognised stderr line (not an `ERROR:`/`WARNING:`/`SCRIPT ERROR:` message, not matched by a declared expected pattern or an exact allowlist entry) makes PASS impossible: `INCOMPLETE / UNKNOWN_ENGINE_MESSAGE` (unclassified evidence, not a proven violation); the line stays in raw stderr and in `engine_messages.unknown_engine_messages`.
No global zero-warning policy exists.

## Adding a suite

Add one entry to `suites.json` (data, not code): `entry`, `launch` (headless | vulkan, timeout, user args), `matrix`
rows and categories copied from `docs/TEST_MATRIX.md` (`check-manifest` verifies them and the matrix blob/digest),
`completion`, `coverage`, `summaries`, `fail_markers`, `assertions`, `artifacts`, `engine_policy`, `limitations`.
Without a completion adapter a suite can reach at most `INCOMPLETE`. Do not edit tests to fit the harness.

## Probes

`fixtures/probe_project/probes/*.gd` are deliberately good/bad scripts (22 cases). Each has a declared expected
verdict in `suites.json`; `run --set probes` fails if any classification differs. Probe results are harness tests,
never Slow Cycle gameplay or test results.
