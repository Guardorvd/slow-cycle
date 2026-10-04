# Q2A — Frozen Baseline

TASK: Q2A — ExecPlan v1.1 + human A1/A2/A3/A4
DATE: 2026-10-04 (Asia/Qyzylorda)
STATUS: COMPLETE — frozen baseline captured and accepted; product aggregate FAIL, runtime acceptance INCOMPLETE
BRANCH: q2-frozen-baseline
RUNTIME BASE: `02b7b5816d488877181872ab3f04bf2f094bd0df`
CAMPAIGN FREEZE F: `a533f2e3248466fea867857184b3458ffdecac75` (tree `44d62e4607b69702af6bf7438a41fc7d70150d99`)
VERIFY: fresh A4 PASS, all V1–V15; final non-runtime closeout tests Q2 36/36, Q1 49/49 and manifest66/209 PASS
INDEPENDENT REVIEW: R1 REJECT accepted; R1-F1 resolved by A4; R2 PASS, blocking_findings none
COMPLETION COMMIT: `docs: complete Q2A frozen baseline`; SHA/tree/changed-file count recorded externally after the single local commit (a commit cannot contain its own SHA)

## 1. Accepted outcome and boundary

Q2A captured and accepted the frozen baseline:29 invocations,188 attempts including22 integrity probes,166 baseline attempts,127 PASS/39 FAIL/0 INCOMPLETE,retries0. Q1 results/reasons and raw evidence remain unchanged. Completion accepts evidence accountability/reporting; it does not accept the product/runtime. C10 OPEN, C12 OPEN, runtime_acceptance INCOMPLETE. ObjectDB remains intermittent and unroot-caused;39 product FAILs are preserved. [Durable baseline](../../baselines/Q2A/README.md).

Q2B NOT STARTED. R0 NOT STARTED and BLOCKED until Q2B completion. They require separate requests, approved plans and verification/review. Closeout authorizes no Godot/campaign/calibration, product/ObjectDB fixes, new seeds/retries/matrix/F, frozen evidence edits, push or merge.

## 2. Independent reviews, acceptance and preserved history

Independent R1 returned REJECT. Human accepted R1-F1: RI-SESSION incorrectly hashed whole route_choices, including physics_tick and incidental runtime fields, producing65 false EQUALITY_ELIGIBLE MISMATCH. Human A4 authorized only a derived semantic correction using emitted opening/selected_arm signatures and explicit fork_id/choice/selected_branch_id/selected_seed fields, with timing separately retained. No geometry or runtime evidence was regenerated. Historical A3 composite/reports remain SUPERSEDED_BY_A4 under aggregate/superseded/A3, receipt SHA256 `a9ad0c66fb0aca5e3647c11736be4716700681b659e8e5bc98c6bbfe989c5f26`. R1 is never represented as PASS.

Fresh A4 VERIFY independently recomputed66 MATCH/0 MISMATCH for producing eligible RI-SESSION pairs; physics_tick repeatability65 DIFFERENT/1 IDENTICAL;23 nonproducing NOT_OBSERVED candidates retained.36 per-seed components/timing records retain source attempt/run/path/SHA provenance. All other identity/comparison semantics unchanged.

Q2A INDEPENDENT REVIEW R2 = PASS; blocking_findings = none. Independent context R2 confirmed A4, frozen baseline integrity, no hidden reruns and no new blocking finding, as supplied directly by the human owner in the current chat on2026-10-04. Human accepted Q2A and explicitly authorized archive/navigation closeout and exactly one local completion commit. This is external independent-review acceptance, not author self-review. No separate R2 report locator/hash was supplied; none fabricated. The authorization record is retained in external closeout evidence, SHA256 `bc33d1930abcbddde69844ac80bb5a47884998b9a58a285e79f730ded1dd9de7`.

## 3. Deferred findings — no closeout fixes

| Finding | Disposition |
|---|---|
| R1-NB1 | ObjectDB warning in stderr but absent from engine.log; carry to separately approved Q2B investigation |
| R1-NB2 | Nonproducing/ineligible identity candidates inflate NOT_OBSERVED; deferred reporting/tooling hardening |
| R1-NB3 | Conservative default-path RI-OPEN exclusion accepted; retained limitation |
| R1-NB4 | Historical short-lived unlabelled Godot --version process pair; retained provenance limitation |
| R1-NB5 | Q2 tooling1076 nonblank/noncomment lines versus approximate900 target; deferred sizing/hardening consideration |
| R2-NB1 | aggregate.comparisons drops RI-SESSION rows without a hash instead of making a partly malformed producing attempt NOT_COMPARABLE; **no effect on frozen Q2A dataset; deferred tooling hardening** |

R2-NB1 remains unfixed and does not reopen Q2A. It is not a Q2B ObjectDB root-cause task. None of these findings authorizes implementation work in this closeout.

## 4. Frozen and final baseline identities

Baseline ID `Q2A-a533f2e32484-2026-10-03T175011263949Z`; artifact paths are relative to that external package, with absolute locators as environment metadata only. Campaign definition digest `ebf7dd032a8f1d553845f035ff38f398e1975ec65b0c19baa5968c56031e4f15`; ledger head `94b0618fd972b6de92f1c18c6ab02f16c739ab548cf5c92350ef843188a767da`; freeze receipt SHA256 `c70df2d07c04e517131304bad6f6c155c227fe90aaad9793f121ca0f951f47b2`.

Accepted full report `aggregate/baseline.json`:2418832 bytes, SHA256 `57bf601dab4b8b93607d3018eb10a6900a8c615177442168249ddfdd9af3574c`. Payload digest `26abdc1445236a58d4ae4f8d2d2fd5ec8ca4f053ea2678ec1ba17e95874e882c`; reporting source digest `dbe8e6a1bb813879e5ffa2e5cef1394c6d55fe063b09140dc389b5ddf916f760`. Compact data678394 bytes/index243555 bytes retain188 bindings; only lifecycle README changes during closeout. Final package budget/hash audit is external below. All15438 original raw files and the accepted full/extraction/index/SHA256SUMS/history remain immutable.

Reviewed source inventory SHA256 `10b106b7dff93f1beb2109627d64371916dd267bbc341ba01ca539254be165fb`; tracked base..working diff SHA256 `27724f45cb16755eea3b1b308ab4ed8209dc6f64337d0c1cc3b17bf7cd72e2f5`. Verbatim reviewed plan snapshot SHA256 `93c58498cba759ef174949a0fd2f7310ce6d73f000b1fe6cc5b44e607026673b`. Final archival/navigation diff identity and final commit/tree are reported externally; reviewed code/tests/schema/compact/index/full evidence remain identical.

## 5. Verification, closeout and limitations

Fresh A4 V1–V15 PASS report SHA256 `ffc1232d3e3903a18193b10e3d18ba51ac046b426fe9c1ffae5a2888e4653681`, independent audit SHA256 `856613b0caddd1c30c6ebb81f36e1e65efcab1942595185bf0bfd1182efa3abb`, supplemental identity SHA256 `8148512e087ede47bb00cdf6dbdeb6c7411bce58640ff3accc1c24b0a6757dce`. A4 verification/evidence root is sibling A4-reporting-2026-10-04T0600406179720Z of the external package; every earlier calibration/failure/proposal/A3/R1/A4 remains preserved in the verbatim progress record and original external locations.

Final no-runtime checks: Python3.13.7 -B Q2 selftest36 OK (2.780s), Q1 selftest49 OK (10.575s; full log retained externally); check-manifest66 suites/209 rows, TEST_MATRIX blob48477ee1aaae3f7a03fa9ff544272a0a5df84566. Required final diff/protected-path/source scope/package budget/durable index/Git status audits are retained at `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\closeout-2026-10-04T0621418191163Z`; completion_report.json records final commit/tree/count/clean status/tests/budget after successful commit. No implementation/test modification in closeout. Existing approved A3/A4 Q2 tests remain; no assertions/gates weakened, skips/suppression/hooks or fake product PASS.

Known evidence limits: P3 ObjectDB8/40 normally completed attempts (rider4/10/replay4/10/route0/10/session0/10), no cause claim; default route failures9/routes4; branch-local rider/geometry replay limits; thermal/background drift; frame/GPU timing approved D4 NOT_MEASURED; no E5 human acceptance/E7 ride/full-world or cross-platform identity claim. Actual per-attempt checks/coverage/completion/log messages are retained. Product FAIL/runtime INCOMPLETE and C10/C12 OPEN persist.

## 6. Appendix — complete reviewed ExecPlan and progress record (verbatim)

The following snapshot preserves the original plan, approvals, A1/A2/A3, failed attempts/reports, R1 REJECT, A4 and fresh VERIFY PASS exactly as reviewed. Its historical AWAITING_INDEPENDENT_REVIEW status is superseded by the R2 acceptance and COMPLETE lifecycle record above. Original relative links were rooted at the repository root; current navigation uses the completed record and durable baseline links above.

---

# Slow Cycle — active plan slot

TASK: Q2A — Frozen Baseline (ExecPlan v1.1)
STATUS: AWAITING_INDEPENDENT_REVIEW — fresh A4 VERIFY PASS (V1–V15); R1 REJECT accepted/F1 corrected; product FAIL/runtime INCOMPLETE; no completion
DATE: 2026-10-04 (Asia/Qyzylorda); original approval/campaign 2026-10-03
BRANCH / BASE / HEAD: `q2-frozen-baseline` / `master` = `origin/master` = `02b7b5816d488877181872ab3f04bf2f094bd0df`; HEAD = F = `a533f2e3248466fea867857184b3458ffdecac75` (tree `44d62e4607b69702af6bf7438a41fc7d70150d99`)
BASELINE: clean HEAD=F throughout campaign; A3 intake had only this plan modified. Current handoff: 11 modified approved reporting/plan/navigation files + 4 new durable files; staged=[]; no unrelated paths
APPROVAL: ExecPlan v1.1 APPROVED by human instruction in this chat on 2026-10-03; D1–D6 exactly as §A and amendments A–H APPROVED
PREVIOUS: Q1 COMPLETE — [record](docs/plans/completed/Q1.md)
SCOPE GUARD: measurement/reporting only; Q2 selftests extended by A3/A4; no new Godot/harness runtime; no production/Q1 test/threshold/gate/player/camera/scene/asset/project change; no Q2B/R0; C10/C12 OPEN
NEXT DEPENDENCY: Q2B — ObjectDB / Lifecycle Root-Cause Investigation (only after Q2A is accepted); R0 blocked until Q2A and Q2B are done

---

## A. Human review of v1.0 (2026-10-03) and how v1.1 applies it

v1.0 text SHA-256 (raw working-tree bytes, before this rewrite): `94e4b772292ceb18877c5fdc50fd5cdad47587c06460e294d10a9bc8fa556538` (556 lines). The architecture was accepted subject to the decisions and amendments below. Where they conflict with v1.0 wording, this version governs.

| ID | Human decision | Where applied |
|---|---|---|
| D1 | APPROVED: additive `q2a_*` entries in `tools/verify/suites.json`. Existing suite semantics are unchanged. Every Q2A entry references an existing accepted TEST_MATRIX row and category. No TEST_MATRIX reclassification and no Q1 classifier/process change | §5, §8.2, §14, §15 M3 |
| D2 | APPROVED: local campaign freeze commit before the first runtime run. The baseline distinguishes `runtime_base_revision = 02b7b5816d488877181872ab3f04bf2f094bd0df` from `campaign_freeze_revision = <F>`, and the freeze procedure proves the runtime/protected trees are identical | §0, §12.3, §15 M3 |
| D3 | APPROVED WITH CONSTRAINT: external Windows memory observer, kept out of the timing workloads. Sampled values are labelled `sampled_peak_*`. Exact counter/API semantics are specified | §9.6, §9.7, §8.1 |
| D4 | APPROVED: main-thread/frame-time statistics = `NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING`, an accepted Q2A gap. No product instrumentation, no Q1 change, no additional pre-R0 phase. Q2B remains the next mandatory phase | §3, §9.6, §20.2, §22 |
| D5 | APPROVED OPTIONAL: human inspection of canonical captures is useful, not required. Without it, no E5/E7 claim | §9.8, §19 |
| D6 | APPROVED: 10 predeclared ObjectDB rounds, external evidence folder, no raw logs/PNGs committed. The repository baseline carries run IDs, relative names, sizes, SHA-256, revision and environment identity; an absolute path is never the durable reference | §9.9, §13 |

| Amendment | Resolution in v1.1 |
|---|---|
| A — header | One Q2A identity (above). Note: the v1.0 file on disk contained one `TASK:` and one `LAST_COMPLETED:` line (checked with grep before this rewrite); the duplicate the reviewer saw was most likely the diff against the previous NO_ACTIVE_PLAN slot. The header is rebuilt regardless and contains no NO_ACTIVE_PLAN text |
| B — seed count | **All 7 seeds run on the rider via the CLI** (`q2a_rider_s<seed>`, including 184729), plus the unchanged default-config pilot rider. Captures were made consistent the same way (7 CLI variants). Exact enumeration: **188 ledgered attempts** = 22 probes + 166 baseline attempts in 29 harness invocations (§8.3). There is no approximate count |
| C — Round B semantics | Round B repeats configuration, not necessarily the world. Equality is evaluated only for eligible identities (§9.2) |
| D — performance statistics | n=5 measured: all five raw values + median, min, max (mean supplemental). No p95. Warm-up recorded separately (§9.6) |
| E — required INCOMPLETE | A required attempt that is INCOMPLETE blocks Q2A until the human explicitly accepts it. Product FAIL does not block (§20.2) |
| F — durable evidence | Machine-independent artifact manifest keyed by `baseline_id` + relative POSIX path + bytes + SHA-256 (§13) |
| G — canonicalisation | Canonical JSON (CJSON) + SHA-256 for the campaign digest, ledger records, chain and all digested JSON. No floats; no `str()` serialisation (§12.0) |
| H — completeness pass | Read-only pass over every TEST_MATRIX file context, the world-AGENTS gates and the Master Q2 list, each marked INCLUDED / EXCLUDED_WITH_REASON / NOT_APPLICABLE (§8.5). Result: one justified addition (`q2a_world_session_seed`, the contract behind the CLI seed mechanism Q2A relies on); no automatic enlargement |

## 0. Base identity and what was read

| Fact | Value | Source |
|---|---|---|
| Branch | `q2-frozen-baseline` | `git branch --show-current` |
| `runtime_base_revision` (HEAD = master = origin/master) | `02b7b5816d488877181872ab3f04bf2f094bd0df` ("feat: add bounded verification harness"), tree `3ae246650bf14006140ec0ac815c236676a14d8b` | `git rev-parse` |
| Runtime/protected trees at base | `scripts` `b102a98d38f5b58e2494da664be0bd1fb15f5d79` (`player` `8917fc74…48ba`, `camera` `c030b66a…32a3`, `world` `19f404ac…c579`, `core` `08d8dd94…a619`, `test` `0e028ea8…29d4`, `ui` `a99816ca…42d5`, `audio` `5a8f0af4…0da64`); `scenes` `b0cc030dba7fecdaa2cd76b428866cfa846aca11`; `assets` `e9f5c1a2b790129f6caf26ac92d9ab24f2f7b3fa`; `project.godot` `1d533851fe53a6d6e913ed721f7d862a62d8b262`; `default_bus_layout.tres` `0d9024a36b2612e6166ffbd837cf0dffee7f4a29`; `icon.svg` `df989b6c872b6534298b80002b09034d769bd199` | `git rev-parse HEAD:<path>` |
| Protected authority | `docs/TEST_MATRIX.md` `48477ee1aaae3f7a03fa9ff544272a0a5df84566`; `.antigravity/rules/test-integrity.md` `736be8ed914b16e468680d55bd5e3ce2a032680c`; `tools/verify` tree `2095808d744cbe38775ef77860dcdbd74f432222`; `tools/verify/suites.json` 42 suites, sets `probes` (22) and `pilot` (20) | same; JSON read |
| Working tree | clean at plan start; `core.autocrlf=true` (Git blobs canonical, Q1 A7) | `git status`, `git config` |

**Which commit is "the baseline":** the measured runtime is `runtime_base_revision` `02b7b58`. The campaign executes at `campaign_freeze_revision` F, a descendant whose diff from `02b7b58` is limited to Q2A tooling, the additive suites.json entries and this plan. §15 M3 proves runtime-tree identity before any run.

Read: root and scoped AGENTS; `.agent/PLANS.md`; both verify/review skills; CURRENT_PROJECT_STATE, TEST_STRATEGY, TARGET_ARCHITECTURE, LEGACY_MIGRATION_MATRIX, docs README; `tools/verify/README.md`, `sc_verify.py`; the Q1 record in full.
Completeness pass (H): TEST_MATRIX §§1–8 in full — every file context's role, trigger and row IDs/categories (66 contexts), the C01–C14 conflict ledger, seed bindings and E-level rules. Master §§VI, IX–XII (Q0–R0), XV–XVI, XVIII. Blueprint: no numeric performance budgets.
Traced sources: `world_manager.gd`, `slow_cycle_logger.gd`, `main.tscn`, capture helper/runners, and the rider, route, soak, branch-streaming, diversity, monotony, carver, grammar, road-contract, road-graph, macro-profile, surface-contract and session-seed runners.
Nothing was launched.

## 1. Goal

Produce one exact, reproducible, evidence-backed snapshot of what the current Slow Cycle runtime (`02b7b58`) actually does on one documented machine. It covers seeds, road/geometry identities, rider, branch/fork, streaming/lifecycle, timing, memory, Vulkan captures, ObjectDB occurrence and every current FAIL/INCOMPLETE. A later region-first migration must be able to tell whether it **introduced** a regression, **preserved** a defect or **removed** a defect. Q2A is measurement only. A product FAIL inside the baseline is legitimate data.

## 2. Observed current state (forensic)

### 2.1 Q1 harness facts that shape Q2A

| # | Fact | Source | Consequence |
|---|---|---|---|
| H1 | CLI `run --suite a,b \| --set X --godot --output-root`; new `<UTC>-<hex>` run dir per invocation; verdict owner `classify.py`; exit 0/1/2/3 | `sc_verify.py` | Q2A drives the harness only through the CLI, never importing it |
| H2 | Manifest path fixed to `tools/verify/suites.json` (L262/L338/L348); no `--seed` or `--manifest` option | `sc_verify.py` | Seeded variants are additive suites.json entries with `--seed=N` in `user_args` (D1) |
| H3 | Engine flags fixed (`LAUNCH_FLAGS` L24); `user_args` placed after `--` (L131) | `sc_verify.py` | No `--print-fps`/`--verbose`, consistent with D4 and the Q2A/Q2B boundary |
| H4 | A duplicate suite in one invocation is rejected (L238); `attempt` is always 1 (L162) | `sc_verify.py` | Each repetition is its own invocation/run_id; the Q2 ledger owns ordinals |
| H5 | `purpose` hard-coded `q1-harness-pilot`/`probes` (L273); `run.json` notice "not … Q2 baseline" (L317) | `sc_verify.py` | Limitation **L-Q1-PURPOSE**; Q2 provenance lives in the ledger binding the run_ids |
| H6 | `measurements` uses the first regex match (L154) | `sc_verify.py` | Q2 extracts numbers from raw logs itself; verdicts only from `result.json` |
| H7 | For repo suites the harness passes `--diagnostics-root=<check>/diag`, `--audit-output-root=<check>/audit` (L129); artifacts must be fresh and inside the check dir | `sc_verify.py` | Session manifests carry effective seeds and opening signatures |
| H8 | `worktree_raw` covers `scripts`, `scenes`, `project.godot` only (identity.py L13) | identity.py | Q2A identity uses Git trees on a clean committed revision (covers `assets/`) |
| H9 | Leak regex (evidence.py L14); leak policy `record` by default, zero-leak only on G-gates (rider, diversity, monotony, capture) | evidence.py, Q1 N4 | Leaks recorded for every attempt; FAIL only where Q1 already declares zero-leak |
| H10 | Only `id, kind, origin, entry, launch, matrix` are required keys; `check-manifest` verifies rows/categories against TEST_MATRIX; selftests assert probe invariants and rider 500/350 | manifest.py, selftest | Additive entries are possible without code change; categories are copied, never invented |
| H11 | Probe set has 22 headless probes (none launched in Vulkan); pilot 20 checks; Q1 durations: rider 43.8 s, master 23.7 s, route ~13 s, capture 9.0 s, others ≤10.3 s | suites.json, Q1 §20.2 | Pilot round ≈ 2.5 min |

### 2.2 Seed mechanics (traced)

`WorldManager._ready` records `requested_seed` and then calls `_resolve_session_seed`. A CLI `--seed=N` always wins, with user args beating command args (world_manager.gd L23–56). Otherwise, with `randomize_world_seed_on_start`, the seed is drawn from `[1, 2147483647]`. `scenes/main.tscn` L25–26: `world_seed=184729`, `randomize_world_seed_on_start=true` (C08). The logger writes `<diagnostics-root>/<session>/manifest.json` with `requested_seed`, `effective_seed`, godot/renderer/driver/display, `generation_config`. It autosaves every 2 s and on tree exit (logger L119–123, L129, L245). The CLI precedence itself is covered by the ACTIVE_CONTRACT `SESSION-SEED` (`test_world_session_seed.gd`, prints `WORLD_SESSION_SEED_SUMMARY checks= failures=` L43).

### 2.3 Identity sources that exist

| Source | Content | Serialization | Location |
|---|---|---|---|
| `WorldManager.diagnostic_checkpoint` (production, L109–131) | Active branch, s∈[0,100] step 2 m, 51 samples of `position\|tangent\|normal` | Godot `"%s"` Vector3 formatting (implicit engine precision), `"\n".join`, `sha256_text()` | Session manifest `replay_steps[]` CHECKPOINT `automatic_opening` (L75–80, once the branch reaches ≥100 m) |
| `test_session_diagnostics.gd` L58/L75 | `opening` (0–100 m) and `selected_arm` (40 m) + 1 route choice per canonical seed | Same production function | diag manifests; replay recomputes (C06) |
| `CaptureAuditSupport.geometry_signature` (L153–158) | 0–100 m step 2 m | Same formatting, test-helper code | Capture manifest |
| Fixed-precision printf lines | ROUTE (route L261), `FORK_PROFILE_CONTINUITY` (macro L45), rider results (L149–158), soak milestones (L85), diversity table, monotony per-seed | Test's own format strings | stdout |
| Domain `stable_signature`s (route plan/intent, events, pacing) | Internal replay equality | **Not printed** | Not observable (D) |

There is no complete road hash. The opening signature is a sampled 100 m identity and is never called a "world hash".

### 2.4 Timing / memory / frame sources

Microbenchmarks: road_graph L322–354; terrain_carver L285/L317/L326; road_grammar L173/L176; road_contract L372; branch_streaming L311–339 (asserted max ≤1.0 / mean ≤0.85 ms). All are REGRESSION_GUARD "E6 narrow" with C09 hardware-specific notes. Godot static memory: soak L48/L78/L115 (SOAK-MEM OBSERVATIONAL). Process wall duration: harness. Process memory/CPU: none in tests. Frame times: none in tests (only `debug_hud.gd`, runtime UI). GPU: none.

### 2.5 Known current facts (priors for comparison only, not acceptance criteria)

- `route_branch_integration` FAIL `failures=9 routes=4`.
- ObjectDB "6 instances leaked" occurred in Q1 pilot `…351ffd23` (rider, replay, route) and was absent in `…e0648cb7`.
- Rider 355.9 m against the 350/500 gate; distance is branch-local (C03).
- Historical branch junction/commit-budget failure (TEST_MATRIX §6).
- C10 and C12 OPEN; valley jump 4.5 m and landing +10° are legacy findings.
- Runtime acceptance INCOMPLETE.

### 2.6 Q1 non-blocking findings

| Finding | Handling in Q2A (no Q1 code change) |
|---|---|
| NB1 Job Object race | Recorded; survivors/orphans copied per attempt |
| NB2 engine.log not parsed | The Q2 leak census counts stderr and engine.log separately and flags mismatches (observation only) |
| NB3 continuation lines | Raw logs hashed and retained; the census is regex on raw text |
| NB5 probe exit semantics | P1 uses `run.json.probe_matrix.expectations_met`, not the exit code |
| NB6 replay prerequisite | Each replay attempt is annotated with its same-invocation `session_diagnostics` verdict |
| N8 git return codes | The Q2 runner performs its own Git checks with return codes |
| N5–N7, L-Q1-PURPOSE, H3/H4/H6 | Recorded limitations |

None prevents trustworthy Q2A evidence, so no Q1 code amendment is proposed.

## 3. Evidence-capability inventory (A direct · B derivable from raw · C new Q2-only external observer · D unavailable without product/test change)

| Metric | Class | Basis |
|---|---|---|
| Git revisions/trees/dirty, harness digest | A | Harness + Q2 checks |
| Godot build, exe sha256 | A | Harness `engine_identity` |
| OS/CPU/RAM/GPU/driver/display/power | C (trivial) | §10 env collector; missing → `UNKNOWN` |
| Vulkan version/renderer/device | B | Godot banner; capture manifest |
| Effective seed (Main runners) | A/B | Harness `seeds` certification (Q2A seeded entries) or Q2 manifest read (observed) |
| Effective seed (domain runners) | B | `source_constant` |
| Opening / session / capture signatures | B | Manifests (§2.3) |
| Fixed-precision metric digests | B | §9.1 canonicalisation |
| Complete road hash | D in Q2A | Claim narrowed (§9.1) |
| Domain signatures | D | Not printed |
| Fork decisions/state, route coverage | A/B | ROUTE lines, route messages, `route_choices`, branch FSM, surface metadata |
| Rider telemetry | A/B | Harness measurement + results block |
| Streaming state | B | Soak milestones; session snapshot |
| Microbenchmark timings | B | stdout (P4 measured) |
| Session-start→opening latency | B (proxy) | `events.jsonl ticks_ms`; includes setup/frames, not generation-only |
| Process wall duration | A | Harness |
| Process memory/CPU | C | P5 memory block observer (§9.7) |
| Godot static memory | B | Soak stdout |
| GPU memory/time | D | `NOT_MEASURED` |
| Main-thread frame-time statistics | **Accepted gap (D4)** | `NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING` |
| ObjectDB occurrence/count | A/B | Harness `leaks` + Q2 census |
| PNG provenance | A/B | Harness artifacts + capture manifest |
| Raw errors/warnings/unknown lines | A | Harness `engine_messages`, raw logs |
| Repeatability | B | §9.2 |

## 4. Target behaviour, exclusions, boundaries

- **In scope:** the frozen campaign manifest; execution through the Q1 harness; the hash-chained attempt ledger; the environment manifest; the memory-block observer; aggregation into the versioned baseline record; reconciliation; the durable lightweight record in Git and heavy evidence outside Git.
- **Q1/Q2 boundary:** Q1 classifies, Q2 aggregates. Q2 copies `result`/`reason_code`/`reasons` from `result.json` and never computes a suite verdict. Its own statuses are evidence-completeness and baseline statuses (§12.3).
- **Q2A/Q2B boundary:** Q2A only characterises ObjectDB occurrence. No `--verbose`, no instrumentation, no teardown/ownership/scene change, no bisection or configuration variation to locate a cause. All of that is Q2B.
- **Excluded:** any target-world code (RegionPlan, RegionIdentity, MacroTerrainPlan, FinalSurface, RegionRouteGraph…); road/terrain/streaming/biome/hydrology changes; player/camera/controls/scenes/resources/`project.godot`; tests, assertions, thresholds, coverage, gates, TEST_MATRIX; C10/C12 resolution; route/leak repair; optimisation; frame instrumentation (D4); E5/E7 claims; running all 204 rows.

## 5. KEEP / ADAPT / REPLACE / DEFER

| Object | Decision | Reason |
|---|---|---|
| `scripts/test/*.gd`, assertions, thresholds, seeds, gates | KEEP (bytes unchanged) | Test integrity |
| Production, scenes, assets, `project.godot`, player/camera | KEEP (bytes unchanged) | The measured runtime is the current runtime |
| Q1 code, schemas, selftests, probes, README | KEEP (bytes unchanged) | Reuse; `classify.py` stays the verdict owner |
| `tools/verify/suites.json` | EXTEND additively (D1): 24 `q2a_*` entries; existing 42 entries, `sets`, `matrix`, `environment_allowlist`, `schema`, `purpose` structurally identical | Documented data extension |
| Pilot set | KEEP, run as `--set pilot` | Q1 continuity |
| Existing identity emitters | KEEP, consumed as recorded | No second hash implementation |
| Full road hash, domain signatures, frame-time observer | DEFER (claim narrowed; D4 accepted gap) | Requires in-project code |
| Q1 external evidence | KEEP as reference | Not the Q2 baseline |

## 6. Ownership, contracts, dependency direction

```
tools/baseline/sc_baseline.py   (Q2 campaign owner)
  → subprocess: python tools/verify/sc_verify.py run --suite … | --set …   (Q1 envelope + verdict)
      → Godot --script res://scripts/test/<existing>.gd  → real Slow Cycle systems
  ← read-only: <evidence>/runs/<run_id>/{run.json, checks/*/{result.json, stdout.log, stderr.log, engine.log, diag/**, audit/**}}
  → writes: <evidence>/{ledger.jsonl, env/, observer/, aggregate/}; later docs/baselines/Q2A/*
```

| State | Single owner |
|---|---|
| Suite verdict | Q1 `classify.py` via `result.json` |
| Campaign definition + digest | `tools/baseline/q2a_campaign.json` at F |
| Attempt ordinals, order, re-attempts | `ledger.jsonl` |
| Environment identity | Q2 `envinfo.py` |
| Process memory/CPU | Q2 `observer.py` (P5 only) |
| Metric/identity extraction | Q2 `extract.py` (numbers/identities only) |
| Baseline record | Q2 `aggregate.py` |

Dependencies are one-way. Q2 imports nothing from `tools/verify/harness`, and no `.gd`, scene or Q1 file knows about Q2.

## 7. Seed policy

### 7.1 Seeds (exact)

- **Canonical (Master):** `184729`, `42`, `77777`.
- **Additional (4), fixed before execution:** for i = 1, 2, …: `v = int.from_bytes(SHA256(UTF-8("slow-cycle/q2a/additional-seed/<i>"))[0:4], "big") & 0x7FFFFFFF`. Accept v if `v ≥ 1` and v is not in the canonical set ∪ every TEST_MATRIX §3 bound seed (including `50000+37t`, t=0..14) ∪ already-accepted values. Take the first four. Result (computed during planning, pure hashing): i=1 **351697566**, i=2 **1027766269**, i=3 **874341432**, i=4 **9954360**; none rejected.
- Rationale: production sessions draw from `[1, 2^31−1]` (world_manager.gd L51–53), so 31-bit seeds represent normal sessions. Seven seeds in total keep the campaign bounded.
- **Declared seed set S7 = {184729, 42, 77777, 351697566, 1027766269, 874341432, 9954360}.**

### 7.2 Per-suite seed semantics (no test modified to force a seed)

| Suite | Traced mechanism | Q2A configuration | Effective-seed basis |
|---|---|---|---|
| `virtual_rider` (pilot) | `TEST_SEED=184729`, `randomize=false` before tree (L11, L30–31) | Default, no CLI | Manifest (observed; Q1 entry declares no `seeds`) |
| `q2a_rider_s<seed>` ×7 (all of S7) | CLI `--seed=` wins in WorldManager | `--seed=<seed>` | Harness-certified from `diag/*/manifest.json effective_seed`. The rider's header line still prints 184729 (L22) and is not evidence |
| `capture_visual_vulkan` (pilot) | Helper `start_world` + `cli_seed()` + `seed_reason` (helper L27–31, L56–57) | Default 184729 | Coverage `[CAPTURED] seed=184729` |
| `q2a_capture_s<seed>` ×7 (all of S7) | Same | `--seed=<seed>` | Certified via diag manifests + `[CAPTURED] seed=<seed>` ×8 |
| `q2a_capture_seed_audit` | Defaults 184729/42/77777 (CLI would reduce to one) | As-is | Capture manifest `sessions[]` (observed) |
| `route_branch_integration` | `[184729,42]` × 2 modes × 2 choices per Main; a CLI seed would collapse all routes | As-is, no CLI | ROUTE `seed=` + manifests if present |
| `session_diagnostics`/`replay_session` | Canonical 3 | As-is | Harness-certified |
| `q2a_world_session_seed` | Exercises the resolver without generating a world | As-is | N/A (synthetic) |
| diversity (10), monotony (3), master (5), grammar, road_contract, carver, macro, surface, road_graph/children | Source constants or fixtures | As-is | `source_constant` |
| `q2a_soak_asis` | Labels 184729/10101/99999; Main randomisation not disabled (L37, C08) | As-is → random effective seeds | Observed only; not reproducible |
| `q2a_soak_pin184729` | CLI overrides all three iterations | `--seed=184729` | Certified {184729} (documented C08 behaviour, not the intended 3-seed battery) |
| `q2a_branch_streaming` | 424242/184729 assigned without disabling randomisation (C08) | As-is | Observed only |

Seeded rider/capture entries copy the TEST_MATRIX category (RIDER REGRESSION_GUARD, CAP-VIS OBSERVATIONAL) because `check-manifest` requires it. Their campaign role is `SEED_EXTENSION_OBSERVATION` for seeds other than the bound 184729: a FAIL there is current behaviour for that seed, not a regression of the declared gate. `q2a_rider_s184729`/`q2a_capture_s184729` additionally show whether the CLI path equals the default path (§9.2).

## 8. Campaign design

### 8.1 Phases (fixed order) and observer mode

| Phase | Content | Observer |
|---|---|---|
| P0 Preflight / freeze check | Git identity at F (clean, F descends from `02b7b58`, runtime trees equal §0); campaign digest = recomputed = value recorded in §B; Python/Godot identity; ENV-PRE; user-data listing pre; `sc_verify.py selftest` + `check-manifest`; Q2 selftest | — |
| P1 Harness integrity | Probes ×1 | OFF |
| P2 Round A | A-I01…A-I05 | OFF |
| P3 ObjectDB | OBJ-01…OBJ-10 | OFF |
| P4 Performance | PERF-W (warm-up) + PERF-1…PERF-5 | **OFF (timing workload kept clean)** |
| P5 Memory | MEM-1, MEM-2 (dedicated memory runs) | **POLL-250ms** |
| P6 Round B | B-I01…B-I05 (configuration repeat of A) | OFF |
| P7 Close | ENV-POST, user-data listing post, aggregate, reconcile, full artifact index, SHA256SUMS, ledger head | — |

A FAIL or INCOMPLETE never skips a later independent invocation; only the hard stops in §11.2 do. The observer runs **only** in P5 (and M2 calibration), so no timing evidence in P1–P4/P6 is produced while memory is being polled.

### 8.2 Additive suites.json entries (24, prefix `q2a_`; adapters from source print formats, confirmed in M2)

| Entry id(s) | Entry / user_args | Mode | TEST_MATRIX rows (category copied) | Completion / coverage adapter | Leak policy | Timeout ceiling (s) |
|---|---|---|---|---|---|---|
| `q2a_rider_s184729`, `_s42`, `_s77777`, `_s351697566`, `_s1027766269`, `_s874341432`, `_s9954360` | `test_virtual_rider_bot.gd` `--seed=<seed>` | headless | RIDER (REGRESSION_GUARD) | As `virtual_rider` (`VIRTUAL PHYSICAL RIDER BOT COMPLETED SUCCESSFULLY`, `actual_progress`, same `contract_report` 500/350/semantics/limitation) + `seeds:{requested:[seed], observed: diag/*/manifest.json effective_seed}` | zero_unexpected (same G-gate) | 240 |
| `q2a_capture_s<seed>` ×7 (S7) | `capture_visual_audit.gd` `--seed=<seed>` | vulkan | CAP-VIS (OBSERVATIONAL) | `AUDIT_COMPLETE status=CAPTURE_COMPLETE reason= frames=8/8`; `[CAPTURED] seed=<seed>` ×8 distinct; 8 PNG 1280×720; manifest `driver=vulkan`; seeds certified | zero_unexpected (same as existing) | 180 |
| `q2a_capture_seed_audit` | `capture_seed_audit.gd` | vulkan | CAP-SEED (OBSERVATIONAL) | `AUDIT_COMPLETE status=CAPTURE_COMPLETE … frames=9/9`; 9 PNG | record | 180 |
| `q2a_surface_contract` | `test_surface_audit_contract.gd` | vulkan | SURFACE-NEG (ACTIVE_CONTRACT), SURFACE-LIVE (REGRESSION_GUARD) | `SURFACE_CONTRACT_SUMMARY status=… checks= failures=` (L169) | record | 180 |
| `q2a_world_session_seed` | `test_world_session_seed.gd` | headless | SESSION-SEED (ACTIVE_CONTRACT) | `WORLD_SESSION_SEED_SUMMARY checks= failures=` (L43); coverage `checks ≥ 7` (TEST_MATRIX: seven checks) | record | 120 |
| `q2a_branch_streaming` | `test_branch_streaming.gd` | headless | BRANCH-MESH/FSM/DRESS/PERF (RG), BRANCH-NOPOST/DAG/NOPOST2 (LEGACY), BRANCH-SEED (OBS) | `TOTAL ASSERTIONS/PASSED/FAILED` + `OVERALL VERDICT` (L38–46) | record | 300 |
| `q2a_terrain_carver` | `test_terrain_carver.gd` | headless | CARVER-LAYOUT/NOPOST (LEGACY), CARVER-ANCHOR (ACTIVE), CARVER-CLASS/LAYER/PERF (RG) | Counters + `OVERALL VERDICT` (L30–42) | record | 240 |
| `q2a_road_grammar` | `test_road_grammar.gd` | headless | GRAMMAR-DET (ACTIVE), SAFE/PERF (RG), BIOME (LEGACY) | `OVERALL VERDICT: ALL CHECKS PASSED [OK]` / `CHECKS FAILED [FAIL]` (L55) | record | 240 |
| `q2a_road_contract` | `test_road_contract.gd` | headless | ROAD-VALID (ACTIVE), ROAD-GEN/PERF (RG) | `TOTAL TESTS EVALUATED: n / m PASSED` (L88) | record | 240 |
| `q2a_macro_profile` | `test_macro_profile_road_integration.gd` | headless | MACRO-ROAD (ACTIVE), MACRO-TERR (RG, C12) | `MACRO_PROFILE_ROAD_INTEGRATION_SUMMARY checks= failures= seeds=` (L21) | record | 240 |
| `q2a_soak_asis` | `test_soak_run.gd` | headless | SOAK-STATE (RG), SOAK-MEM (OBS) | `ALL SOAK TESTS PASSED` / `[FAIL] SOAK TEST FAILED` (L24/L29); coverage = 3 `[SUCCESS] Seed` lines | record | 1500 |
| `q2a_soak_pin184729` | `test_soak_run.gd` `--seed=184729` | headless | same | same + seeds certified {184729} | record | 1500 |

Existing entries are never edited. Calibration may raise a ceiling, never lower it: `final = max(ceiling, ceil30(3 × calibration_duration))`.

### 8.3 Exact attempt enumeration (frozen manifest lists every attempt with its ordinal)

| Invocation | Phase | Ordinals | Suites in execution order |
|---|---|---|---|
| P1-I01 | P1 | 1–22 | `--set probes` (probe_p01 … probe_p16, in set order) |
| A-I01 | P2 | 23–42 | `--set pilot`: road_graph, seed_diversity, monotony, master_native_tiers, child_diagnostics, child_track_verification, child_track_ride, child_riding_lab, child_gravel_loop, virtual_rider, route_branch_integration, session_diagnostics, replay_session, capture_visual_vulkan, neg_contract_seed_mismatch, neg_contract_missing_target, neg_contract_save_failure, neg_capture_audit_timeout, neg_capture_unknown_frame, neg_replay_no_manifest |
| A-I02 | P2 | 43–48 | q2a_world_session_seed, q2a_branch_streaming, q2a_terrain_carver, q2a_road_grammar, q2a_road_contract, q2a_macro_profile |
| A-I03 | P2 | 49–55 | q2a_rider_s184729, _s42, _s77777, _s351697566, _s1027766269, _s874341432, _s9954360 |
| A-I04 | P2 | 56–64 | q2a_capture_s184729, _s42, _s77777, _s351697566, _s1027766269, _s874341432, _s9954360, q2a_capture_seed_audit, q2a_surface_contract |
| A-I05 | P2 | 65–66 | q2a_soak_asis, q2a_soak_pin184729 |
| OBJ-k (k=1…10) | P3 | 67+4(k−1) … 70+4(k−1) (67–106) | virtual_rider, route_branch_integration, session_diagnostics, replay_session |
| PERF-W | P4 | 107–111 | road_graph, q2a_terrain_carver, q2a_road_grammar, q2a_road_contract, q2a_branch_streaming (**warm-up; excluded from statistics**) |
| PERF-j (j=1…5) | P4 | 112+5(j−1) … 116+5(j−1) (112–136) | same five, same order |
| MEM-m (m=1,2) | P5 | 137–140, 141–144 | virtual_rider, route_branch_integration, q2a_soak_pin184729, capture_visual_vulkan |
| B-I01…B-I05 | P6 | 145–164, 165–170, 171–177, 178–186, 187–188 | Exactly A-I01…A-I05 |

**Totals:** 29 harness invocations; **188 ledgered declared attempts** = 22 probe attempts (harness integrity, judged by expectation match) + **166 baseline attempts** (ordinals 23–188). Of these, 5 are warm-up (107–111, recorded, excluded from statistics) and 25 are measured performance attempts. Per round: 44 attempts (20 pilot + 6 DOM + 7 RIDE + 9 VIS + 2 SOAK). Rider-on-seed coverage: each S7 seed ×2 (A/B) via CLI, plus the default rider ×14 (A, B, OBJ ×10, MEM ×2). Infrastructure re-attempts (§11.3) get new ordinals from 189 upward with `retry_of`; they never replace a declared ordinal.

Pre-calibration timeout-ceiling sum (worst case, a bound only): 568 (probes) + 2×11 700 (rounds) + 9 600 (OBJ) + 7 560 (PERF) + 4 320 (MEM) = **45 448 s**. The final sum is fixed in the frozen manifest. A nominal duration is not predicted, because soak duration is UNKNOWN.

### 8.4 Campaign row families

FAIL acceptable = a product FAIL is valid baseline data. Every baseline attempt is REQUIRED (§20.2).

| Family | Purpose | Collected | Known limitation |
|---|---|---|---|
| Probes | Verdict-engine integrity on this machine/session | Expected vs actual verdicts (mismatch = hard stop) | Harness tests, not the game |
| CORE pilot | Q1-continuous baseline incl. 6 negatives | All harness fields, rider, ROUTE, replay, capture, signatures, durations, leaks | Q1 limitations (C02/C03/C05/C06) |
| DOM | Seed resolver contract, branch lifecycle, generation microbenchmarks (round context), C12, fork C0/C1 | Counters, benchmark text, FORK_PROFILE_CONTINUITY, FSM/commit, macro failures | E6 narrow; C08 branch seeds |
| RIDE ×7 seeds | Physical rider over S7 | Distance, lateral, roll, density, integrity, verdict, leaks, RI-OPEN, RI-RIDE | Branch-local distance; ≤ E4 bounded; seed extension outside 184729 |
| VIS | Vulkan current-world frames; fork-arm surface | Banner, driver, per-frame seed/s/camera, PNG sha/bytes/dims, signatures, surface checks | Teleport capture (C05); PNG ≠ E5 |
| SOAK | Streaming/lifecycle/static memory | Milestones, peak/delta static RAM, recovery, seeds, duration, leaks | As-is non-reproducible seeds (C08) |
| OBJ | ObjectDB occurrence | §9.9 | Characterisation only |
| PERF | Microbenchmark distributions | §9.6 | Hardware-specific CPU only |
| MEM | Process memory/CPU | §9.7 | Sampling limits; console wrapper separate |

### 8.5 Completeness pass (amendment H) — every relevant gate and TEST_MATRIX file context

**Mandatory gates and Master Q2 requirements**

| Gate / requirement | Status | How |
|---|---|---|
| World AGENTS G: `test_seed_diversity_matrix` | INCLUDED | Pilot ×2 rounds |
| World AGENTS G: `test_monotony_profiler` | INCLUDED | Pilot ×2 |
| World AGENTS G: `test_virtual_rider_bot` real physics | INCLUDED | Pilot ×14 + `q2a_rider_s*` ×14 |
| World AGENTS G: Vulkan `capture_visual_audit.gd` | INCLUDED | Pilot ×2 + MEM ×2 + `q2a_capture_s*` ×14 |
| World AGENTS: zero parse errors / zero leak warnings | INCLUDED (observed) | Harness engine policy (zero-leak on G-gates) + Q2 census for all attempts |
| World AGENTS legacy road guard: C1, prohibited straight fallback, `[GEOM]` fatal-fallback logging | INCLUDED (observed only) | Census of `[GEOM]` lines in raw logs; fork C0/C1 from FORK_PROFILE_CONTINUITY; no oracle change |
| World AGENTS: local foliage MultiMesh culling | NOT_APPLICABLE | No foliage/runtime change in Q2A; CAP-CULL excluded below |
| Q1 PASS conditions (completion, coverage, no unexpected errors/leaks, assertions executed) | INCLUDED | Harness verdicts copied |
| Master Q2: seeds 184729/42/77777 + additional | INCLUDED | §7 |
| Master Q2: road hashes | INCLUDED (narrowed) | §9.1; complete road hash D |
| Master Q2: generation timings | INCLUDED | P4 microbenchmarks + latency proxy |
| Master Q2: memory | INCLUDED | P5 + soak static memory |
| Master Q2: main-thread frame statistics | EXCLUDED_WITH_REASON (accepted gap D4) | `NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING` |
| Master Q2: fork behaviour | INCLUDED | §9.4 |
| Master Q2: current known failures | INCLUDED | `known_failures` |
| Master Q2: Vulkan captures | INCLUDED | §9.8 |
| Master Q2: real rider results | INCLUDED | §9.3 |
| Master Q2: ObjectDB warnings | INCLUDED | §9.9 |
| Master Q2: separate ObjectDB root-cause task | EXCLUDED_WITH_REASON | It is Q2B by definition |
| Master XVI DoD (plan, scope, verify, independent review, diff audit, docs, limitations, next dependency, Vulkan for visual, real physics for ride) | INCLUDED | §§15–23 |
| TEST_MATRIX conflict items | C02/C03/C05/C06/C08/C09/C11 carried as limitations; C10/C12 OPEN observations; C01 legacy rows run as-is; C13 excluded with MASSIF; C14 N/A | §9.10, `limitations` |

**TEST_MATRIX file contexts (66)**

| File context (rows) | Status | Reason / where |
|---|---|---|
| `capture_visual_audit` (CAP-VIS) | INCLUDED | Pilot + 7 seeded |
| `capture_seed_audit` (CAP-SEED) | INCLUDED | `q2a_capture_seed_audit` |
| `replay_session_diagnostic` (REPLAY) | INCLUDED | Pilot + neg |
| `test_capture_audit_contract` (CAP-CONTRACT) | INCLUDED | Pilot negatives ×3 |
| `test_session_diagnostics` (LOG-*) | INCLUDED | Pilot |
| `test_world_session_seed` (SESSION-SEED) | INCLUDED (added in v1.1) | Contract for the CLI seed mechanism Q2A depends on |
| `test_route_branch_integration` (ROUTE-*) | INCLUDED | Pilot |
| `test_branch_streaming` (BRANCH-*) | INCLUDED | `q2a_branch_streaming` |
| `test_virtual_rider_bot` (RIDER) | INCLUDED | Pilot + 7 seeded |
| `test_seed_diversity_matrix`, `test_monotony_profiler` | INCLUDED | Pilot (G) |
| `test_sprint_4m_master` (MASTER-*) | INCLUDED | Pilot native tiers |
| `test_diagnostics`, `test_track_verification`, `test_track_ride`, `test_riding_lab`, `test_gravel_loop` | INCLUDED | Pilot direct children |
| `test_road_graph` (GRAPH-*) | INCLUDED | Pilot + PERF |
| `test_terrain_carver`, `test_road_grammar`, `test_road_contract` | INCLUDED | `q2a_*` + PERF |
| `test_macro_profile_road_integration` (MACRO-*, C12) | INCLUDED | `q2a_macro_profile` |
| `test_surface_audit_contract` (SURFACE-*) | INCLUDED | `q2a_surface_contract` |
| `test_soak_run` (SOAK-*) | INCLUDED | `q2a_soak_asis`, `q2a_soak_pin184729` |
| `capture_surface_culling_audit` (CAP-CULL) | EXCLUDED_WITH_REASON | Synthetic prepared fixture (`actual_fork=false`), not the generated world; triggered by winding/culling changes (none); live fork surface covered by `q2a_surface_contract` |
| `test_airborne_calibration_gate`, `test_airborne_empirical_gate` (AIR-*) | EXCLUDED_WITH_REASON | Player/airborne physics calibration; triggered by physics changes (forbidden here); narrow airborne baseline kept via MASTER-AIR |
| `test_dynamic_rideability` (DYNAMIC-*) | EXCLUDED_WITH_REASON | Scripted event/fork physics episodes overlapping rider/route; adds no seed identity; candidate for an amendment if the human wants an R8/R9 baseline |
| `test_foliage_contact_watchdog` (FOLIAGE-CONTACT) | EXCLUDED_WITH_REASON | Binary foliage-contact contract with no printed identity/metric; contacts are observed via surface contract; candidate amendment for an R11 baseline |
| `test_fork_biome_pacing`, `test_fork_corridor_preview`, `test_fork_decision`, `test_fork_geometry_verification`, `test_fork_pacing_planner`, `test_fork_site_planner` | EXCLUDED_WITH_REASON | Domain/integration fork contracts whose signatures are not printed; runtime fork behaviour comes from route/branch/surface/macro |
| `test_mountain_massif_field` (MASSIF, C13) | EXCLUDED_WITH_REASON | Assert-only runner (Q1 ceiling INCOMPLETE without marker); reference fixture per migration matrix, not a runtime dimension |
| `test_mountain_profile` (PROFILE-*) | EXCLUDED_WITH_REASON | Domain determinism; signatures not printed; MASTER-SEED/GRAMMAR-DET cover generation determinism |
| `test_mountain_validation` (MOUNTAIN-*) | EXCLUDED_WITH_REASON | Teleport stress/static memory overlapping soak |
| `test_mtb_event_geometry_catalog`, `test_mtb_event_pipeline`, `test_road_event_chunk_seams` | EXCLUDED_WITH_REASON | Internal replay signatures not printed; no Master Q2 dimension beyond covered ones |
| `test_procedural_run` (PROC-RIDE) | EXCLUDED_WITH_REASON | Effective seed uncontrolled (C08) + unchecked PNG; physical ride covered by rider S7 |
| `test_review_fix` (FIX-*) | EXCLUDED_WITH_REASON | Regression negatives for past fixes; no baseline dimension |
| `test_road_logic` (LOGIC-DET/LIMIT), `test_winding_road` (WIND-*), `test_road_verge_seam_watchdog` (VERGE), `test_terrain_topology_watchdog` (TOPO-*) | EXCLUDED_WITH_REASON | C10/C10-adjacent numeric-limit suites: a run cannot resolve the requirement conflict; determinism is covered by MASTER-SEED/GRAMMAR-DET; radius/grade observed from ROUTE lines. Candidate amendment for a numeric snapshot |
| `test_road_clearance_watchdog`, `test_route_clearance_audit`, `test_route_style_spacing_audit` | EXCLUDED_WITH_REASON | C08 (effective seed unknown) / C11 observational |
| `test_route_intent`, `test_route_plan_contract`, `test_route_rhythm` | EXCLUDED_WITH_REASON | Domain signatures not printed; PLAN-TELEM is an observational proxy |
| `test_mode_select_gamepad` (MENU-PAD) | EXCLUDED_WITH_REASON | UI/input; assert runner without marker; not a Q2 dimension |
| `capture_audit_support`, `surface_audit_support`, `gravel_loop_generator`, `riding_lab_generator`, `test_track_generator`, `capture_screenshot`, `capture_screenshot_ride`, `capture_sprint3a`, `capture_sprint3c`, `capture_third_person`, `test_ride`, `test_screenshot` | NOT_APPLICABLE | N/A NON_CHECK_ARTIFACT (helpers/generators/unchecked captures; TEST_MATRIX §3) |

Totals: 24 contexts INCLUDED, 30 EXCLUDED_WITH_REASON, 12 NOT_APPLICABLE = 66 (all `###` contexts in TEST_MATRIX §7). No campaign enlargement other than the justified `q2a_world_session_seed`.

## 9. Methodologies

### 9.1 Road identity / hash

| ID | Hashed content | Serialization | Precision | Proves | Does NOT prove |
|---|---|---|---|---|---|
| RI-OPEN | Active branch s=0,2,…,100 m (51) `position\|tangent\|normal` | Production `diagnostic_checkpoint`, **read from the manifest, never recomputed by Q2** | Implicit engine string formatting (quantising; recorded verbatim) | Same engine build + seed + `generation_config` → identical formatted first 100 m of the starting branch | Road beyond 100 m, other branches, terrain/foliage/collision, sub-format differences, cross-engine/platform identity, a "world hash" |
| RI-SESSION | `opening` + `selected_arm` + choice per canonical seed | Same production function | Same | As above plus the 40 m selected arm | Physical replay (C06) |
| RI-CAP | Capture helper 0–100 m | Same format (helper) | Same | Capture world = generated opening | Visual identity |
| RI-ROUTE | `^ROUTE mode=` lines in order | UTF-8 strict decode (failure → `NOT_COMPARABLE(decode_error)`), strip trailing `\r`/spaces, `\n`-join, SHA-256; values verbatim | Test printf precision | Same route metric text | Geometry between aggregates |
| RI-ROUTEFAIL | Sorted `[ROUTE FAIL] …` messages | As RI-ROUTE, byte-sorted | Verbatim | Same failure set | Cause |
| RI-FORKC | `FORK_PROFILE_CONTINUITY` lines | As RI-ROUTE | `%.3fdeg`/`%.4fm` | Same fork C0/C1 readings | Other forks |
| RI-SOAKSTRUCT | Soak milestone lines with the RAM field removed by a declared capture-group filter | As RI-ROUTE over kept groups | Printed | Same streaming structure | Memory/timing |
| RI-DIV / RI-MONO | Diversity table rows; monotony per-seed lines | As RI-ROUTE | Printed | Same statistics | Full trajectories |
| RI-RIDE | Rider results block | As RI-ROUTE | Printed | Same outcome at printed precision | Whole route; physics bit identity |

Cross-suite table (observation): RI-OPEN for each S7 seed from rider-CLI vs capture-CLI; for 184729 also default rider, default capture, session, pinned soak; for 42/77777 also session.

### 9.2 Determinism / repeatability (amendment C)

Round B repeats the **same declared configuration** (command, entry, user_args). It does not necessarily repeat the same world. A comparison is labelled per identity and pair:

| Eligibility | Identities / pairs | Condition | Report |
|---|---|---|---|
| `EQUALITY_ELIGIBLE` | RI-OPEN, RI-CAP, RI-SESSION, RI-FORKC, RI-DIV, RI-MONO, RI-SOAKSTRUCT (pinned only) | **Both** attempts have the same certified (or source-constant) effective seed, identical `generation_config`, identical engine sha256 and identical command. The existing determinism contracts (MASTER-SEED, GRAMMAR-DET, SESSION-SEED; world-AGENTS determinism rule) make equality the expected outcome | `MATCH` / `MISMATCH` — observed, never asserted in advance. A mismatch is recorded as a determinism finding (no verdict change) |
| `REPEATABILITY_OBSERVATION` | RI-ROUTE, RI-ROUTEFAIL (fixed seeds, but teleport stepping/streaming with collision queries), RI-RIDE (real physics + frame scheduling) | Same configuration; determinism at this level is not established by any accepted contract | Counts of identical/different; no determinism claim either way |
| `EXCLUDED_FROM_EQUALITY` | Everything from `q2a_soak_asis` (random effective seed), `q2a_branch_streaming` identities (seed not controlled, C08), PNG bytes, timings, memory, anything where a seed is uncertified or differs | — | Distribution/current-behaviour evidence only. Even a coincidental equal seed is reported as an observation, not a determinism result |

Pairs: every A/B twin, plus the 14 default-rider attempts and the session/replay/route attempts across A, OBJ ×10, MEM and B (same configuration). Claims are limited to same revision + same environment. There is no cross-machine/engine, streaming-order or full-world determinism claim.

### 9.3 Physical rider

Per attempt: `declared_target=500 m`, `existing_pass_threshold=350 m` (unchanged), `actual_progress` with `measurement_semantics = active-branch local s distance; may reset on branch change (C03)`, max lateral deviation (limit 2.2 m), peak roll, roll events/density, track integrity, verdict/reasons, leaks, exit, completion, effective seed, RI-OPEN, RI-RIDE, duration. The limitation is copied verbatim: a threshold PASS ≠ full 500 m route, not both routes, not all seeds, not E7. Per seed (A/B): both values. Default rider (14 attempts): all values, min/median/max. No physics change.

### 9.4 Branch / fork

Route summary `failures`/`routes`; every ROUTE row field; `[ROUTE FAIL]` / `[ROUTE DIAGNOSTIC]` texts; RI-ROUTE, RI-ROUTEFAIL; branch-streaming FSM/DAG/unload/BRANCH-PERF; session `route_choices`; FORK_PROFILE_CONTINUITY; surface fork-arm checks. Whether `failures=9 routes=4` reproduces (or deviates) is recorded for every route attempt (A, OBJ ×10, MEM ×2, B). Observed radius `1/|k|` from curvature extremes is labelled observation, not C10 resolution. No repair.

### 9.5 Streaming / lifecycle

Soak milestones (active chunks, graph nodes/edges, spline points, Pos Y, recovery offset, completion of each of the three seeds; an early `break` is recorded as missing coverage); branch unload at 5000 m; session `last_snapshot.active_chunks`; exit codes, survivors/orphans; ObjectDB census; durations. "No leak" is never inferred from `queue_free` or a printed "0 Leaks" (C02).

### 9.6 Performance (amendment D; D3 separation)

| Label | Source | Statistics |
|---|---|---|
| `microbenchmark_ms` per named benchmark (the test's own aggregation, e.g. "avg/max over 10 chunks", kept with its label) | P4 measured attempts 112–136 (observer OFF) | **All 5 raw values (verbatim text) + median + min + max** (mean supplemental). **No p95.** Warm-up 107–111 reported separately and never pooled |
| `microbenchmark_ms@roundA` / `@roundB` | Rounds A/B | Reported separately as single observations; not pooled with P4 |
| `generation_latency_proxy_ms` | `events.jsonl` `ticks_ms` (SESSION_START → automatic_opening) | Per attempt; labelled proxy including setup/frames |
| `process_wall_ms` | Harness `duration` (integer ms) | Per configuration: all values, median, min, max |
| `godot_static_memory_mb` | Soak stdout (verbatim) | Single-run factual series |
| `frame_time_*`, `gpu_*` | — | `NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING` (D4) |

Order is fixed and recorded (no shuffling). Every value is retained: no outlier removal, trimming or best-of. Thermal/background drift is a stated limitation. Thresholds remain test-owned; Q2 derives no budgets.

### 9.7 Memory — Q2-only external observer (D3; P5 and calibration only)

- **Discovery:** every 250 ms `CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS)` + `Process32FirstW/NextW` (`th32ProcessID`, `th32ParentProcessID`, `szExeFile`). Q2 tracks the descendants of the `sc_verify.py` subprocess: the Godot console wrapper and the main Godot process separately. PID reuse is guarded by parent chain + `GetProcessTimes` creation time ≥ invocation start.
- **Handle:** `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION 0x1000 | PROCESS_VM_READ 0x0010 | SYNCHRONIZE 0x00100000, FALSE, pid)`. If denied, retry without `PROCESS_VM_READ`; the granted mask is recorded.
- **Counters:** `K32GetProcessMemoryInfo` with `PROCESS_MEMORY_COUNTERS_EX`:
  - `WorkingSetSize` — current resident working set, bytes.
  - `PeakWorkingSetSize` — OS-maintained lifetime maximum of the working set.
  - `PagefileUsage` / `PrivateUsage` — current commit charge (private committed bytes).
  - `PeakPagefileUsage` — OS-maintained lifetime maximum commit charge.
- **CPU:** `GetProcessTimes` gives creation, exit, kernel and user times as integer 100-ns ticks.
- **Polling:** in P5 every 250 ms per tracked process.
- **Post-exit:** after `WaitForSingleObject` signals, one query on the retained handle; the outcome is recorded as `post_exit_query: OK | FAILED(<GetLastError>)`. Whether Windows still returns memory counters for a terminated process is **confirmed in M2**, not assumed.
- **Labels (never mixed):**
  - `os_peak_working_set_bytes`, `os_peak_commit_bytes` — OS-maintained lifetime peaks, only when the post-exit query succeeded.
  - `os_peak_*_until_last_query` (+ query timestamp) — OS-maintained but possibly not final, used when the post-exit query failed.
  - `sampled_peak_working_set_bytes`, `sampled_peak_private_bytes` — maximum of the 250 ms series, which can miss spikes.
  - `cpu_user_100ns`, `cpu_kernel_100ns`.
  - Plus the full series.
- **Scope:** stdlib `ctypes` only; no writes to the observed process; no installation. The observer is not active in P1–P4/P6, so it cannot contaminate timing or the OBJ characterisation.

### 9.8 Vulkan / visual (D5)

Rows: pilot capture (184729) A/B and MEM ×2; 7 seeded captures A/B; seed audit (3 canonical × start/100 m/first fork) A/B; surface contract A/B. Per attempt: banner (Vulkan version, Forward+, device), manifest driver/renderer/display_server, source digest in the manifest compared with the repo, 1280×720 windowed. Per frame: seed, s, camera mode, altitude, relative PNG name, bytes, SHA-256, header dimensions, freshness. **Artifact captured ≠ E5 review ≠ E7.** `e5_human_review = NOT_PERFORMED` unless the human performs the optional review, which is recorded separately (reviewer, date, frames viewed, verbatim notes). The AI makes no visual judgement and no E5/E7 claim.

### 9.9 ObjectDB characterisation (D6)

- **Declared block:** P3, N = 10 rounds × {virtual_rider, route_branch_integration, session_diagnostics, replay_session}, default configuration, observer OFF.
- **Per attempt:** leak line counts in stderr and engine.log (mismatch flagged); instance count from `WARNING: <N> ObjectDB instance(s)…`; the `at:` line; exit; completion; normal completion vs kill; verdict; seed; phase; run_id.
- **Statement:** "X of N normally completed attempts in the declared block emitted the ObjectDB warning (instances …)", per suite and in total. Infrastructure-failed attempts are listed but excluded from the denominator. If X = 0, record "0 of 10" (rule-of-three upper bound ≈ 30%).
- **Campaign-wide census:** all phases, per suite/seed/phase, kept separate from the P3 rate.
- **Forbidden:** `--verbose`, instrumentation, teardown/scene/ownership changes, reruns to provoke or avoid leaks, cause claims.

### 9.10 C10 / C12

C12: `q2a_macro_profile` output and verdict are recorded verbatim → `C12: OPEN — current behaviour recorded`. C10: observations only (ROUTE radius/grade, `[GEOM]` census) → `C10: OPEN`. No oracle or threshold changes.

## 10. Environment manifest (pre and post; missing → `UNKNOWN`)

| Field | Read-only method |
|---|---|
| Windows caption/version/build/arch | `powershell -NoProfile -NonInteractive -Command "Get-CimInstance Win32_OperatingSystem \| Select … \| ConvertTo-Json"` |
| CPU name, cores, logical processors, max clock | `Win32_Processor` |
| RAM total, system make/model | `Win32_ComputerSystem` |
| GPU name, driver version/date, current resolution/refresh | `Win32_VideoController` (AdapterRAM raw, noted unreliable >4 GB) |
| Vulkan API/device | Godot banner from Vulkan attempts |
| Power plan; AC/battery | `powercfg /getactivescheme`; `Win32_Battery` |
| Python | `sys.version`, `sys.executable` |
| Godot | Path, SHA-256, `--version` (harness + Q2 cross-check) |
| Git | `runtime_base_revision`, `campaign_freeze_revision`, trees (§15 M3) |
| Commands | Every harness argv (result.json) and Q2 argv (ledger) |
| User data `%APPDATA%\Godot\app_userdata\Slow Cycle` | Listing (name, bytes, mtime) pre/post; contents not read |
| Evidence root locator | Absolute path recorded **only here**, as metadata (§13) |
| Uncontrolled factors | Background load, thermal state, display sleep → limitation; the operator keeps the session unlocked |

## 11. Anti-cherry-picking, stop conditions, re-attempts

### 11.1 Controls

1. The matrix (seeds, entries, invocations, ordinals, order, metrics, stop rules) is fixed by this plan.
2. Calibration (M2) may change only adapter regex text and **raise** timeouts; every change is listed in §B.
3. The executable definition is committed at F before P0. Its digest (§12.0) is written into §B and the ledger genesis.
4. Hash-chained ledger; `INVOCATION_START` is written before the subprocess starts.
5. Every run dir is kept, never deleted or overwritten; `SHA256SUMS` covers the root.
6. Statistics use all declared measured attempts.
7. The aggregator refuses when manifest attempts ≠ ledger attempts ≠ run dirs ≠ baseline `run_refs`.
8. Calibration evidence goes to a separate `calibration-<UTC>/` root, disclosed and excluded from statistics.

### 11.2 Hard stops (campaign `INVALID`; escalate; evidence kept)

Git HEAD/tree/status change at any invocation boundary; dirty tree; campaign digest mismatch; Godot SHA-256 change; P1 probe expectations not met; ledger chain broken; evidence root unwritable or disk full; three consecutive infrastructure-failed invocations (pause → human decides whether to resume in the same ledger); user request.

### 11.3 Infrastructure re-attempts

At most one per affected attempt, immediately, with an identical command and a new ordinal ≥189 and `retry_of`. Both attempts stay in the record. Permitted only for:
- `ENGINE_UNAVAILABLE`, `LOG_INCOMPLETE`, `CONTAINMENT_UNVERIFIED`, `ORPHAN_PROCESS`;
- harness exit 3 (`HARNESS_*`);
- `VULKAN_EVIDENCE_MISSING` when the banner shows no Vulkan device;
- evidence-root I/O failure;
- in P5 only, an observer failure.

**Never re-attempted:** product FAIL, `TIMEOUT`, `RUNNER_TIMEOUT`, `COMPLETION_NOT_PROVEN`, `COVERAGE_MISSING`, `SEED_NOT_CERTIFIED`, `UNKNOWN_ENGINE_MESSAGE`, `NONZERO_EXIT_UNEXPLAINED`, `NEGATIVE_*`, leaks.

## 12. Data model

### 12.0 Canonicalisation (amendment G)

- **CJSON(x)** := `json.dumps(x, sort_keys=True, separators=(",", ":"), ensure_ascii=True, allow_nan=False).encode("ascii")`.
  - Allowed types: object (string keys), array, string, integer (|v| < 2^53), `true`/`false`/`null`.
  - **Floats are forbidden** in every digested object; validators reject them.
  - Decimal measurements are stored as the verbatim decimal **string** from the log (e.g. `"355.9"`); durations as integer ms; memory as integer bytes; CPU as integer 100-ns ticks.
  - Timestamps are strings `YYYY-MM-DDTHH:MM:SS.ffffffZ` (UTC).
  - No `str()`/`repr()` of non-string values enters any digested field.
- **`campaign_definition_digest`** = lowercase hex SHA-256(CJSON(parsed `q2a_campaign.json`)). On-disk bytes (CRLF/LF) are irrelevant; the Git blob of the file at F is also recorded. The digest is never stored inside the file it covers.
- **Ledger record:**
  - `record_sha256` = SHA-256(CJSON(record without the key `record_sha256`)).
  - The stored line is CJSON(record with `record_sha256`) + `0x0A`, appended in **binary** mode (no newline translation) and flushed + `os.fsync` after every record.
  - Chain: `prev_record_sha256` = the previous record's `record_sha256`. Genesis = SHA-256(ASCII `"slow-cycle/q2a/ledger-genesis/" + campaign_definition_digest`).
  - The chain head is recorded in `baseline.json` and the repo artifact index.
- **Attempt binding:** each attempt entry inside `INVOCATION_END` carries:
  - `campaign_definition_digest`, `campaign_freeze_revision`, `runtime_base_revision`;
  - `invocation_id`, `attempt_ordinal` (1…188, ≥189 for retries), `attempt_id`, `row_id`, `suite_id`, `round`;
  - `seed_config {policy, requested: int|null, cli_arg: string|null}`, `argv` (array of strings), `observer_mode`;
  - `q1_run_id`, `q1_check_relpath`, `q1_result_json_sha256` (raw bytes), `q1_result`, `q1_reason_code` (copied);
  - `retry_of`, and the record's `prev_record_sha256`.
- **Artifact digests:** SHA-256 over raw file bytes. Directory and index digests per §13.

### 12.1 Campaign manifest `slow-cycle.baseline.campaign/1` (`tools/baseline/q2a_campaign.json`)

`schema`, `task`, `plan_version` (v1.1 + approval ref), `runtime_base_revision`, `runtime_roots` (§15 M3 list), `seeds` {canonical, additional {rule, values}, S7}, `entries` (24 q2a ids → TEST_MATRIX rows/categories copied, role, seed_config, mode, timeout_s), `invocations` [29 × {invocation_id, phase, observer_mode, suites[] or set, round}], `attempts` [188 × {ordinal, invocation_id, attempt_id, row_id, suite_id, round, required: true, statistics_role ∈ {probe, baseline, warmup_excluded, measured}}], `metrics` {id → source, pattern, groups, unit, label_class, statistics_allowed}, `identities` {RI-* → source, filter, canonicalisation, eligibility}, `objectdb` {block, N=10, order}, `stop_rules`, `reattempt_policy`, `observer` {mode per phase, interval_ms: 250, api: §9.7}. Integers and strings only.

### 12.2 Ledger `slow-cycle.baseline.ledger/1` (JSONL, §12.0)

Records: `CAMPAIGN_START` (digests, revisions, engine SHA-256, evidence locator as metadata), `PREFLIGHT`, `INVOCATION_START`, `INVOCATION_END` (per-attempt bindings), `REATTEMPT_START`, `HARD_STOP`, `GAP_DECISION_REQUESTED`, `CAMPAIGN_END`.

### 12.3 Baseline record `slow-cycle.baseline/1` (`baseline.json`; refers to Q1 results, does not copy their schema)

| Field | Semantics |
|---|---|
| `schema_version`, `baseline_id` (`Q2A-<F short>-<UTC>`) | Identity |
| `runtime_base_revision` | `02b7b5816d488877181872ab3f04bf2f094bd0df` — the measured runtime |
| `campaign_freeze_revision` | F — tooling + manifest |
| `runtime_identity_proof` | Per runtime root: tree/blob at both revisions (must be equal); `git diff --name-only` base..F list (must be ⊆ Q2A tooling paths) |
| `environment` | ENV-PRE/POST key fields + digests, differences; evidence root locator (metadata only) |
| `campaign_definition_digest`, `ledger_head_sha256` | §12.0 |
| `campaign_rows`, `attempt_plan` | Copy of manifest entries/attempts |
| `run_refs` | Per attempt: ordinal, attempt_id, invocation, q1_run_id, relative check path, `result`/`reason_code`/`reasons` **copied**, exit, duration_ms, `evidence_status` ∈ {CAPTURED, PARTIAL(missing[]), INFRA_FAILED(reason), NOT_STARTED}, `required: true`, retry_of |
| `seed_matrix` | Per suite: policy, requested, effective (certified / observed / source_constant), discrepancies |
| `road_identity`, `determinism` | RI-* per attempt; comparisons with eligibility (§9.2) |
| `rider`, `branch`, `streaming`, `performance`, `memory`, `vulkan` | §§9.3–9.8, labels per §9.6/§9.7 |
| `leaks` | P3 statement + census |
| `known_failures`, `known_incomplete` | Every FAIL / INCOMPLETE with ordinals, reasons, messages, prior-comparison (reproduced / changed / not reproduced) |
| `accepted_gaps` | D4 frame/GPU gap (accepted at approval) + any human-accepted required INCOMPLETE (ordinal, reason, decision text, date) |
| `C10`, `C12` | `OPEN` + observations |
| `limitations` | Q1 + Q2 limitations |
| `artifact_manifest` | §13 |
| `product_aggregate` | Q1 aggregate rule over baseline attempts — **not** runtime acceptance |
| `runtime_acceptance` | `INCOMPLETE` (unchanged) |
| `overall_baseline_status` | `CAPTURED` / `AWAITING_HUMAN_GAP_DECISION` / `CAPTURED_WITH_ACCEPTED_GAPS` / `INVALID` (§20.2). "Frozen and accepted" is stated only in the completed record after VERIFY + REVIEW PASS |

## 13. Artifact retention and machine-independent manifest (D6, amendment F)

- **Durable identity of evidence** = (`baseline_id`, `relpath`). `relpath` is POSIX-style (forward slashes) and relative to the evidence root, composed only of harness/Q2-generated components (`runs/<q1_run_id>/checks/<suite_id>/…`, `ledger.jsonl`, `env/…`, `observer/<invocation_id>.jsonl`, `aggregate/…`). Each artifact is identified by `relpath` + `bytes` (int) + `sha256`. Absolute paths appear **only** as `environment.evidence_root_locator`.
- **Full index** `aggregate/artifact_index_full.txt`: one line per file, `<sha256> <bytes> <relpath>\n`, LF, sorted by UTF-8 bytes of `relpath`. Its SHA-256 = `artifact_root_digest`.
- **Per-attempt directory digest** = SHA-256(CJSON(sorted list of `[relpath, bytes, sha256]` for every file under that attempt's check dir)).
- **External root** (outside the repo): `<evidence_root>/<baseline_id>/` with `campaign/` (manifest copy + digest), `env/`, `ledger.jsonl`, `runs/<q1_run_id>/…` (unaltered Q1 output), `observer/`, `aggregate/{baseline.json, extraction_report.json, reconcile_report.json, artifact_index_full.txt}`, `SHA256SUMS`. Default locator: `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\` (sibling of the Q1 root). Calibration lives in `calibration-<UTC>/`. Archiving the root is recommended to the user, not required.
- **Repository (lightweight, durable):**
  - `docs/baselines/.gdignore`.
  - `docs/baselines/Q2A/README.md` — human summary.
  - `docs/baselines/Q2A/baseline.json` — §12.3, compact CJSON, ≤ 1 MB total for the directory.
  - `docs/baselines/Q2A/artifact_index.txt` — every attempt's ordinal, q1_run_id, check relpath and directory digest; key-artifact lines (`result.json`, `stdout.log`, `stderr.log`, `engine.log`, session/capture manifests, PNGs) as `sha256 bytes relpath`; `artifact_root_digest`; `ledger_head_sha256`; revisions; environment digest.
- **Not committed:** PNGs, raw logs, session dirs, logger source copies, observer series.

## 14. Exact future mutation whitelist

| Op | Path | Responsibility |
|---|---|---|
| MODIFY | `implementation_plan.md` | Approval, progress (§B), digests, reports; finally NO_ACTIVE_PLAN |
| CREATE | `tools/baseline/.gdignore`, `tools/baseline/.gitignore` (`__pycache__/`) | Isolation |
| CREATE | `tools/baseline/README.md` | Usage, statuses, boundaries |
| CREATE | `tools/baseline/sc_baseline.py` | CLI: `env`, `freeze-check`, `calibrate`, `run`, `aggregate`, `reconcile`, `selftest` |
| CREATE | `tools/baseline/q2a/__init__.py`, `cjson.py`, `campaign.py`, `ledger.py`, `observer.py`, `envinfo.py`, `extract.py`, `aggregate.py` | §6 owners; stdlib only; target ≤ 900 non-comment lines |
| CREATE | `tools/baseline/q2a_campaign.json` | Frozen definition (24 entries, 29 invocations, 188 attempts) |
| CREATE | `tools/baseline/schema/campaign.schema.json`, `ledger.schema.json`, `baseline.schema.json` | §12 |
| CREATE | `tools/baseline/selftest/test_cjson.py`, `test_campaign.py`, `test_ledger.py`, `test_extract.py`, `test_aggregate.py`, `selftest/samples/*` | Q2 self-tests (no Godot); samples from calibration raw output |
| MODIFY (additive only) | `tools/verify/suites.json` | Append exactly the 24 `q2a_*` entries of §8.2; nothing else changes |
| CREATE | `docs/baselines/.gdignore`, `docs/baselines/Q2A/README.md`, `docs/baselines/Q2A/baseline.json`, `docs/baselines/Q2A/artifact_index.txt` | Durable baseline |
| MODIFY | `docs/CURRENT_PROJECT_STATE.md`, `docs/README.md`, `docs/TEST_STRATEGY.md` | Status/navigation lines only; runtime INCOMPLETE retained |
| CREATE | `docs/plans/completed/Q2A.md` | Only after VERIFY PASS + independent REVIEW PASS |

DELETE: none. Runtime evidence: outside the repository only.

**Forbidden:**
- `scripts/**`, `scenes/**`, `assets/**`, `project.godot`, `default_bus_layout.tres`, `icon.svg*`.
- `tools/verify/**` except the additive suites.json append (Q1 code, schema, selftest, fixtures, README untouched).
- Root/scoped `AGENTS.md`, `.agent/PLANS.md`, `.agents/skills/**`, `.antigravity/rules/test-integrity.md`.
- `docs/TEST_MATRIX.md`, Blueprint, Master, Target Architecture, Legacy Migration Matrix, `TEST_COVERAGE_AND_REPLAY.md`, sprint/history/decision docs, `ARCHITECTURE.md`, root `.gitignore`.
- No test-only hooks, no `--verbose`, no edits to existing suites.json entries.

## 15. Migration path (milestones and stop points)

- **M0 Approval intake.** Record the v1.1 approval and conditions in §A/§B. Real Git preflight (branch, HEAD = `02b7b58` or a descendant containing only this plan file, clean except the plan). Divergence → STOP.
- **M1 Tooling.** `tools/baseline/**` + 24 additive entries. Q2 selftests; Q1 `selftest` (49 OK) and `check-manifest` OK. No Godot.
- **M2 Calibration (disclosed, non-baseline; observer POLL-250ms).** One run each of the 12 adapter classes: `q2a_world_session_seed`, `q2a_branch_streaming`, `q2a_terrain_carver`, `q2a_road_grammar`, `q2a_road_contract`, `q2a_macro_profile`, `q2a_rider_s42`, `q2a_capture_s42`, `q2a_capture_seed_audit`, `q2a_surface_contract`, `q2a_soak_asis`, `q2a_soak_pin184729`. Confirms adapters, PID attribution, the post-exit counter outcome (§9.7) and opening-checkpoint presence per class. Only regex text and raised timeouts may change; any matrix/seed/ordinal change → amendment + STOP.
- **M3 Freeze proof and commit F.**
  1. `git diff --name-only 02b7b58 <candidate>` ⊆ {`implementation_plan.md`, `tools/verify/suites.json`, `tools/baseline/**`}.
  2. For every runtime/protected root (`scripts` and each subtree `player`, `camera`, `world`, `core`, `test`, `ui`, `audio`; `scenes`; `assets`; `project.godot`; `default_bus_layout.tres`; `icon.svg`; `.antigravity/rules/test-integrity.md`; `docs/TEST_MATRIX.md`; `AGENTS.md`; `scripts/*/AGENTS.md`), `git rev-parse 02b7b58:<p>` = `git rev-parse <candidate>:<p>` (expected values in §0).
  3. `git diff --quiet 02b7b58 <candidate> -- tools/verify ':(exclude)tools/verify/suites.json'`.
  4. suites.json: base-blob JSON vs candidate JSON — `schema`, `purpose`, `matrix`, `environment_allowlist`, `sets` deep-equal; `suites[0:42]` deep-equal in order; `suites[42:66]` are exactly the 24 declared `q2a_*` ids.
  5. Compute `campaign_definition_digest` and write it with the proof into §B.
  6. Local commit F (no push); record F.
  Any failure → STOP.
- **M4 Campaign** P0–P7 per §8 and §11.
- **M5 Aggregate + reconcile + index**; write `docs/baselines/**`. If any required attempt is not CAPTURED or has Q1 result INCOMPLETE → status `AWAITING_HUMAN_GAP_DECISION`, list them, **STOP** for the human (§20.2).
- **M6 VERIFY** (`slow-cycle-verify`) → **M7 independent REVIEW** (`slow-cycle-review`, fresh context) → **M8** archive, navigation, NO_ACTIVE_PLAN, local completion commit by user decision → **STOP**. Q2B is not started.

## 16. Risks

| Risk | Mitigation |
|---|---|
| Retrospective selection | Plan-fixed matrix, hash seed rule, digest at F, hash-chained ledger, exact ordinals, independent recomputation |
| Second verdict engine | Q2 copies verdicts; reviewer inspects `extract.py`/`aggregate.py` |
| Mislabelled metrics | Label classes in manifest/schema; §9.1/§9.6/§9.7 tables copied into the record |
| Observer contaminates timing/leaks | Observer only in P5/M2 |
| Post-exit counters unavailable | Distinct `_until_last_query` / `sampled_peak_*` labels; outcome recorded |
| `str()`-formatted signatures hide drift | Precision stated as implicit; claim limited to the same engine build |
| Non-deterministic suites read as determinism failures | Eligibility rules (§9.2) |
| Vulkan unavailable | Infrastructure classification, one re-attempt, then human gap decision |
| Soak duration unknown | Raise-only ceilings; TIMEOUT is evidence (and a required INCOMPLETE → human decision) |
| Godot writes into the repo | Status check at every invocation boundary → hard stop; `.gdignore` on new dirs |
| user:// shared state | Pre/post listing; noted for Q2B |
| Baseline mistaken for acceptance | `runtime_acceptance: INCOMPLETE`, separate `product_aggregate`, wording checks |
| External evidence loss | Relative-path manifest with hashes in Git; archive recommendation |
| Scope creep into Q2B/R0 | Forbidden list; reviewer check |

## 17. VERIFY procedure (`slow-cycle-verify`; read-only)

| # | Check |
|---|---|
| V1 | Approved plan version/digest; `runtime_base_revision`, `campaign_freeze_revision`, completion diff, untracked list |
| V2 | Scope: diff base..result ⊆ §14; forbidden roots byte-identical; M3 proof re-run independently (runtime trees, Q1 code, suites.json additive) |
| V3 | Freeze order: F precedes ledger `CAMPAIGN_START`; recomputed CJSON digest of `q2a_campaign.json` at F = ledger genesis input = §B value; no definition change after F (or a recorded amendment with a new digest) |
| V4 | Seed rule recomputed → same 4 values; S7 used for all 7 rider and 7 capture CLI entries |
| V5 | Manifest lists exactly 29 invocations / 188 attempts with the §8.3 ordinals; ledger attempts = run dirs = `run_refs`; order matches; re-attempts only per §11.3 with both retained; ledger chain recomputed |
| V6 | Independent reconciliation script (imports neither Q1 nor Q2 code): copied verdicts = `result.json`; leak counts (stderr/engine.log) re-counted; metrics re-extracted; RI-* re-read from manifests; PNG SHA-256/dims recomputed; artifact index, directory digests, root digest and `SHA256SUMS` recomputed |
| V7 | Metric semantics: labels; P4 statistics = 5 raw values + median/min/max (no p95); warm-up separate; observer only in P5; `sampled_peak_*` vs `os_peak_*` correct; frame/GPU = `NOT_MEASURED / UNAVAILABLE_WITH_CURRENT_TRUSTED_TOOLING` |
| V8 | Every FAIL, INCOMPLETE, warning, unknown message and leak appears in the record; priors marked reproduced / changed / not reproduced |
| V9 | Determinism comparisons respect §9.2 eligibility; no "world hash" wording |
| V10 | Vulkan provenance per attempt; `e5_human_review` correct; no E5/E7 claim |
| V11 | Q1/Q2 boundary: no classification in Q2; Q1 code untouched; Q1 selftest 49 OK; `check-manifest` OK; P1 probes matched |
| V12 | Q2A/Q2B boundary; no R0 artifacts; C10/C12 OPEN |
| V13 | Required-INCOMPLETE rule: every required attempt is CAPTURED with a non-INCOMPLETE Q1 result, or listed in `accepted_gaps` with a matching human decision in §B |
| V14 | Durable record: no absolute path used as identity; repo index alone resolves every attempt to run_id + relpath + hash |
| V15 | Q2 selftests (including §17.1 negatives) pass; `git diff --check` clean |

Result PASS / FAIL / INCOMPLETE per `.agent/PLANS.md`.

### 17.1 Negative verification (Q2 tooling only)

| Case | Expected |
|---|---|
| Ledger line deleted/edited/reordered | `reconcile` reports chain break → INVALID |
| `q2a_campaign.json` edited after F | `freeze-check`/`run` refuse (digest mismatch) |
| Float in a digested object | CJSON validator rejects |
| Dirty tree / HEAD moved | `run` refuses before any invocation |
| Run dir missing or extra | `aggregate` refuses (count mismatch) |
| `result.json` altered after the run | `reconcile` flags a mismatch with the ledger-recorded SHA-256 |
| Metric regex has no match | `NOT_OBSERVED` (never 0) |
| Non-UTF-8 bytes in a canonicalised stream | `NOT_COMPARABLE(decode_error)`; raw retained |
| Seed list differs from rule | Campaign validation fails |
| Determinism comparison requested for an ineligible pair | `EXCLUDED_FROM_EQUALITY`, no MATCH/MISMATCH emitted |
| Required attempt INCOMPLETE without a recorded decision | `aggregate` → `AWAITING_HUMAN_GAP_DECISION` (never `CAPTURED`) |
| Observer cannot open the process (P5) | Memory evidence `INFRA_FAILED(reason)`; Q1 verdict untouched |

## 18. Independent review (`slow-cycle-review`, fresh context)

Inputs: approved v1.1 (+ §B), the diff and revision identities, the VERIFY report, and access to the external evidence. The reviewer must challenge:
- cherry-picking and hidden reruns (manifest vs ledger vs disk);
- seed selection; metric mislabelling;
- timing methodology (warm-up, n=5, pooling, observer separation);
- leak reporting (denominator, census, stderr vs engine.log);
- environment identity; unsupported world-hash or determinism claims (eligibility);
- false whole-game PASS or E5/E7 wording;
- required-INCOMPLETE handling;
- artifact durability without the external root;
- scope leakage (Q1 code, tests, production, Q2B, R0).

Output PASS / REJECT with actionable findings. VERIFY FAIL/INCOMPLETE independently blocks acceptance.

## 19. E-levels

- **E0:** recorded per attempt as a fact.
- **E1–E4:** properties of specific attempts only (rider = E4 bounded; route = E2/E3 teleport).
- **E5:** artifact-level only (Vulkan saved/read PNG + context); human review NOT_PERFORMED unless D5 is done; no E5 acceptance claim.
- **E6:** narrow (microbenchmarks, soak structure, static and process memory with their labels); frame/GPU not measured (D4).
- **E7:** N/A, not claimed.

Q2A changes no generation code, so the generation gates are not triggered by a change. They are nevertheless all exercised as baseline rows; this is not a waiver.

## 20. Definition of Done and acceptance

### 20.1 Q2A task status vs product result

**Q2A COMPLETE** requires all of the following:
- `runtime_base_revision` and `campaign_freeze_revision` recorded, with the runtime-identity proof;
- the campaign manifest committed with its digest before execution;
- canonical + additional seeds executed exactly as enumerated (rider and capture on all S7);
- all 188 declared attempts accounted for (manifest = ledger = disk = record), with re-attempts disclosed;
- the repeatability comparison done under the eligibility rules;
- rider, branch/fork, streaming, performance (5 raw + median/min/max), memory (P5, labelled), Vulkan (provenance) and ObjectDB ("X of N") evidence captured;
- raw and structured evidence reconciled;
- known FAILs retained;
- the lightweight record in Git with the machine-independent manifest;
- no test, threshold, gate or production byte changed;
- C10/C12 OPEN; Q2B dependency and R0 block recorded;
- every required INCOMPLETE either absent or explicitly human-accepted;
- VERIFY PASS and independent REVIEW PASS.

**Product/suite results are independent of that status.** `route_branch_integration = FAIL`, a C12 FAIL, a branch-budget FAIL or a leak may all sit inside a COMPLETE baseline. `runtime_acceptance` remains **INCOMPLETE**.

### 20.2 Required-INCOMPLETE rule (amendment E)

- Every baseline attempt (ordinals 23–188) is **REQUIRED**. Probes (1–22) are judged by expectation match; a mismatch is a hard stop.
- A product **FAIL** with captured evidence does not block.
- A required attempt **blocks** Q2A if, after the single permitted infrastructure re-attempt, either:
  - its Q1 result is `INCOMPLETE` (any reason, including product-side ones such as TIMEOUT or COVERAGE_MISSING), or
  - its Q2 `evidence_status` ≠ `CAPTURED`.
- Q2A then **cannot** proceed automatically to COMPLETE. The aggregator sets `AWAITING_HUMAN_GAP_DECISION`, the ledger gets `GAP_DECISION_REQUESTED`, and work STOPs.
- The human may explicitly accept specific attempts as unavoidable documented evidence gaps. Each acceptance (ordinal, reason, decision text, date) is recorded in §B and in `baseline.json.accepted_gaps`, and only then does the status become `CAPTURED_WITH_ACCEPTED_GAPS`.
- Nothing is silently downgraded, omitted or re-labelled.
- D4 (frame-time/GPU statistics) is the only gap accepted in advance.
- A hard stop makes the campaign `INVALID`: its evidence is kept and disclosed, and a new campaign needs a new digest.

## 21. Rollback

Q2A mutates no runtime system. Rollback means reverting Q2A-owned commits or hunks: `tools/baseline/**`, the 24 appended entries (restoring the base suites.json blob), `docs/baselines/**`, navigation hunks and the plan slot. No `reset --hard`, no history rewrite, no deletion of others' work. External evidence (including failed or INVALID campaigns and calibration) is **never deleted** and stays accounted for in its own ledger. A rolled-back baseline is marked superseded, not erased.

## 22. Legacy impact, Q2B dependency, R0 block

- Existing gates, known failures and runtime INCOMPLETE are preserved; C10/C12 stay OPEN; Q1 non-blocking findings stay open.
- **Next mandatory phase: Q2B — ObjectDB / Lifecycle Root-Cause Investigation.** It begins only after the Q2A baseline is frozen and accepted (VERIFY PASS + REVIEW PASS + archive). It starts from the Q2A census and the P3 rate. It may later require instrumentation (`--verbose`, lifecycle probes) or production/lifecycle changes, **none of which Q2A authorises**. It needs its own ExecPlan and approval, and any fix is compared against this baseline.
- The D4 frame-time gap does **not** create another pre-R0 phase.
- **R0 is BLOCKED** until the Q2 obligations of the Master are met: Q2A accepted and Q2B completed, each with VERIFY + independent REVIEW. Nothing starts automatically.

## 23. Documentation changes (at completion, within the whitelist)

- `docs/baselines/Q2A/*`.
- `docs/CURRENT_PROJECT_STATE.md`: Q2A status, baseline link, runtime INCOMPLETE, Q2B/R0 not started.
- `docs/README.md`: navigation row to the baseline.
- `docs/TEST_STRATEGY.md`: Q2A navigation line.
- `docs/plans/completed/Q2A.md`; root slot → NO_ACTIVE_PLAN.
- TEST_MATRIX, AGENTS, skills and the Q1 README stay unchanged.

## 24. Decisions

D1–D6 are decided (§A). No open decision remains for v1.1. Any later change to seeds, entries, invocations, ordinals, metrics, stop rules or the observer mode requires a written amendment and a new campaign digest.

## B. Progress, freeze record and gap decisions

Human approval recorded 2026-10-03 (Asia/Qyzylorda): “Q2A ExecPlan v1.1 = APPROVED; D1–D6 = APPROVED exactly as recorded in §A; amendments A–H = APPROVED.” The human subsequently authorized conditional deletion of exactly `.claude/settings.local.json` after read-only inspection. It contained only Claude-local `permissions.allow` for two Bash tool approvals, with no governance/source/credentials/user work. The file and then-empty directory were removed; no ignore/configuration files changed.

M0 real commands after cleanup: branch `q2-frozen-baseline`; HEAD = master = origin/master = `02b7b5816d488877181872ab3f04bf2f094bd0df`; staged=[]; untracked=[]; unstaged=[`implementation_plan.md`]. Git exit codes successful. Environment warning: denied read of `C:\Users\Luisa/.config/git/ignore`; required status/diff results succeeded, human decision permits continuation. Expected LF→CRLF warning retained; no normalization performed.

Existing Python: `C:\Users\Luisa\AppData\Local\Programs\Python\Python313\python.exe`, 3.13.7 (`MSC v.1944 64 bit (AMD64)`). Sandbox launch denied initially; approved escalation ran the read-only identity check successfully. Existing Godot: `C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`; version `4.7.2.stable.mono.official.ed1daf0bf`; SHA-256 `2445d009a5e0474fc7064b9767100e9d2c09521890ac5625476bfb81cf03f2d4`. No install/PATH change. M1/M2/M3/campaign/VERIFY/REVIEW NOT_RUN at approval intake.

To be filled in order:
M1 initial checks: Q2 selftests 18/18 OK (3.931 s), unchanged Q1 selftests 49/49 OK (11.146 s), Q1 check-manifest OK: 66 suites, accepted TEST_MATRIX blob `48477ee1aaae3f7a03fa9ff544272a0a5df84566`. Q2 additive freeze proof selftest independently deep-compared original 42 suite objects and protected manifest blocks; exact 24 additions; campaign 29 invocations / 188 ordinals. Current pre-calibration campaign digest `ec27c48ccaa9c6cfbb4d647fd9305d36e00443644bd4a83198cb9a96a27fdafc` (not yet frozen). Existing tests/production untouched. Calibration/negative tooling samples and final M1 reconciliation remain in progress; no campaign invocation.

Pending human clarification before M3: §13 full-file index has circular references through the index itself, SHA256SUMS and baseline.json's artifact_root_digest; requested explicit exclusion of these three derived files from the full index and separate repository-index hashes. M3 also cannot embed F's own SHA inside F or edit the plan after F while retaining clean HEAD=F; requested external freeze receipt immediately after F with later plan recording. Neither clarification is assumed approved; no freeze commit/campaign may occur while pending.

M2 first invocation (not baseline): external evidence root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\calibration-2026-10-03T165852968581Z`; Q1 run ID `20261003T165853Z-d839671a`. All 12 declared suites launched exactly once and Q1 finished: 9 PASS, 3 FAIL, 0 INCOMPLETE. FAIL suites: `q2a_branch_streaming`, `q2a_macro_profile`, `q2a_rider_s42`, each Q1 reason `ASSERTION_FAILED`; rider required completion marker was absent. Q1 verdicts/reasons were preserved, with no production/test/threshold changes or adapter/timeout adjustment. These are calibration observations, not campaign statistics or acceptance.

M2 status INCOMPLETE: observer failed before polling (`TypeError: int object is not callable`), because its instance timestamp shadowed the `start()` method. Q1 had already launched and continued to completion; no second run was started, no raw evidence deleted. Memory observer NOT_STARTED; PID attribution and post-exit counters NOT_MEASURED. Tooling fix renamed the timestamp field, checks observer startup callability before launching Q1, and retains/report-waits on startup failure after launch. Q2 selftests after this fix: 19/19 OK (4.638 s). Windows observer runtime behavior remains unverified.

Preserved external `calibration_report.json` records the failure and all 12 result/extraction rows plus raw artifact hashes. External `calibration_ledger.jsonl` is explicitly retrospective, calibration-only, and excluded from baseline; head `8cfe4c2a4a2c14af7f45f567e4cb80aa95aaa60742d6236bd14750ef5053a397`. Requested a narrow human amendment for one disclosed repeat of the identical 12-suite M2 selection with observer ON, retaining both runs outside baseline statistics. Repeat is NOT_AUTHORIZED_PENDING_HUMAN_AMENDMENT. Together with the two preceding freeze/index clarifications, three decisions remain pending. M3/F/campaign/VERIFY/REVIEW NOT_RUN; no commit/push/archive/next phase.

### HUMAN AMENDMENT A1 — approved 2026-10-03

Human source: attached `Вставленный текст.txt`, attachment ID `b00c4421-b58f-4685-9a0b-e9a4ab62b005`. This approval supersedes the three pending requests above and authorizes no other campaign/seed/suite/ordinal/metric/product/Q1/test/threshold/gate change.

**A1.1:** Exactly one additional M2 calibration, identical 12 suites, selection/order and seed/configuration semantics, corrected observer ON. Preserve both roots permanently outside baseline statistics; label calibration_1 = observer startup defect, calibration_2 = observer validation after correction. Second calibration validates only process discovery, PID/parent attribution, WinAPI access, 250 ms sampling, post-exit query and memory labels. Product verdict changes are observations; do not repair the first run's 3 FAILs. No third calibration authorized. If observer evidence remains untrustworthy after calibration_2, STOP for a new human decision; do not enter M3.

**A1.2:** Before freeze, payload `artifact_index_full.txt` excludes itself, SHA256SUMS, baseline.json, and any repository-side index containing the payload-index digest. `artifact_root_digest` is SHA-256 of raw payload-index bytes. Closure/repository index separately records bytes/SHA-256 of these metadata files plus approved revisions, ledger head, run IDs and attempt identities; no self-hash or recursively dependent digest. Distinguish payload evidence digest from closure/metadata digests. Individual Q1 artifacts retain their meaning. Update Q2A schema/selftests and final pre-freeze definition metadata/digest only; 29 invocations/188 attempts remain unchanged.

**A1.3:** Immediately after F and before baseline invocation, create deterministic canonical JSON external freeze receipt, with schema/version, UTC timestamp, runtime base, F, campaign digest, Git blob and SHA identities at F for implementation_plan.md, q2a_campaign.json and tools/verify/suites.json, and protected/runtime proof result. Bind receipt identity into CAMPAIGN_START, ledger, final baseline.json and durable repository index. Keep repository clean after F; record F/receipt back into plan only after campaign completion or approved gate/hard stop, at the first permitted documentation mutation. External receipt does not replace eventual durable recording.

Approved action order: record A1 → one second M2 → validate observer → if trustworthy, implement A1.2/A1.3 pre-freeze metadata/schema/tests → M3 proof → F → external receipt → verify clean tree → frozen campaign. Q2B/R0 prohibited; any other needed contract change requires approval and STOP.

### A1 execution — second M2; mandated STOP

Exactly one additional invocation executed, selection/order deep-equal to the original 12-suite CALIBRATION, same unchanged manifest/seed/configuration semantics and observer ON. Root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\calibration-2026-10-03T171534805187Z`; Q1 run ID `20261003T171535Z-206904b2`. Q1 finished 9 PASS / 3 FAIL / 0 INCOMPLETE; the same three FAIL suite IDs and ASSERTION_FAILED reason remain. No effort to make product FAILs green. Calibration_1 original report remains unchanged. External parent `calibration_labels_A1.json` labels both roots explicitly; both excluded from baseline statistics.

Observer raw evidence: 74 discovered processes; all 12 Q1 wrapper PIDs matched and each had exactly one observed Godot-main child. All 24 suite wrapper/main processes had samples, signalled exit and post-exit query OK; all 74 recorded post-exit queries returned OK. Granted mask 1052688 (0x101010). Raw-series creation ordering, sampled maxima and OS-peak labels matched for the 24 suite processes. Nominal polling wait 250 ms; observed same-process intervals 261303–295089 microseconds, per-process median range 267654.5–280711 microseconds (snapshot/query overhead included; no invented pass tolerance).

Observer validation remains INCOMPLETE: four OpenProcess errors, code 87, for git.exe PID 22932/parent 13140, PID 23280/parent 12056, and PID 28348/parent 21740 twice. The unchanged Q2 evidence_status rule treats any observer error as INFRA_FAILED/P5_observer_failure; all 12 calibration statuses reflect that rule. No error suppressed/reclassified or attribution criterion weakened. Additionally, the summary kept initial `exit_100ns="0"` for all 24 suite processes while each final raw sample has nonzero exit time. Raw evidence and summary discrepancy are both retained; no claim of trustworthy complete observer validation.

Launcher reporting failed after Q1/observer completion: `ValueError: non-CJSON value: tuple` because calibration rows stored evidence_status's tuple instead of CJSON-compatible fields. No extra Godot execution. Reconstructed a retrospective calibration_report.json from existing unaltered Q1 files and summary, with string status/list problems and disclosed reporting failure. It does not imply observer PASS. Report SHA-256 `698dd2d2aa96061cbb38924be190e609778a94a07a4b98d729a429843af50f98`; calibration_validation.json SHA-256 `37ada095fecaa5d41b1792f7011dd596543cce8030f48418a0e821b2fd505d96`; retrospective calibration-only ledger head `80c166c8b555dedc44fd3b9499bdd09fccdf6a27be154c068c174592891abcde`.

Per A1.1 STOP for a new human decision. No third calibration authorized or run. A1.2/A1.3 implementation NOT_RUN because the prerequisite observer validation did not succeed; M3, F, receipt and baseline campaign NOT_RUN. No code/test/suite changes during this amendment turn; only this approved plan record and external calibration evidence writes. Git branch/base/HEAD unchanged; nothing staged, committed or pushed; git diff --check passes with the preserved expected line-ending warning.

### HUMAN AMENDMENT A2 — approved 2026-10-03

Human source: attached `Вставленный текст.txt`, attachment ID `2a77da0c-81b2-4d3b-adba-310a76eb230a`. The M2 STOP is accepted. Only three demonstrated Q2 tooling defects are authorized for correction: explicit required-Godot versus incidental/helper classification by actual executable identity/path and parent relationship; propagate observed real exit timestamps from authoritative raw samples or explicit null/UNKNOWN; fix report producer's tuple to intended JSON list without weakening CJSON. Required-target identification/query failures remain incomplete. Incidental OpenProcess failures retain PID, executable, Win32 error and role, but do not independently invalidate unrelated Godot memory. No generic error-ignore rule.

Preserve both existing roots, their product verdicts, startup/runtime/report defects, four git.exe OpenProcess(87) records and recovered calibration-2 report. Do not overwrite either root. No third full 12-suite calibration, product/test/Q1/seed/matrix/ordinal/statistics/ObjectDB changes, Q2B or R0. Add regression selftests for role-specific failures, real exit/raw reconciliation and valid report production while tuples remain forbidden. Required pre-runtime checks: Q2 selftests, unchanged Q1 selftests, Q1 check-manifest, git diff --check, whitelist/protected audit.

After those corrections/checks, exactly one external observer-validation invocation set `[q2a_rider_s42, q2a_capture_s42]`, same existing suite configs, observer ON/POLL-250ms, separate root and excluded from all baseline statistics. PASS requires both: reliable Godot roles/parent attribution, no unresolved required OpenProcess failure, memory samples, correct OS/fallback/sampled labels, explicit post-exit outcome, real exit matching raw or explicit unknown (never fabricated 0), visible incidental diagnostics, normal canonical report writing, all Q2 selftests OK and no scope violation. Product verdicts observational only. If any condition fails: INCOMPLETE and STOP; no further calibration/validation authorized. If PASS: implement approved A1 artifact hashing/receipt, perform M3 proof and F; baseline only after F. Record exact files, checks and all evidence identities here.

A2 corrected files: `tools/baseline/q2a/observer.py` (QueryFullProcessImageNameW/exact console+main paths, parent roles, explicit required/helper diagnostics, exit event/raw timing propagation, null live exit time); `tools/baseline/sc_baseline.py` (require both wrapper/main targets, only explicitly incidental errors excluded from failure; canonical producer converts status tuple to list; exact A2 two-suite calibration option); `tools/baseline/selftest/test_aggregate.py` (role/path/parent, actual discovery failures, required missing main, real exit/raw equality, post-exit failure fallback labels, report producer and forbidden tuple regression cases). CJSON implementation and existing Q1/tests/thresholds untouched.

A2 before targeted runtime: Q2 25/25 OK (4.003 s); unchanged Q1 49/49 OK (11.009 s); Q1 check-manifest OK 66 suites, 209 rows, TEST_MATRIX blob unchanged. git diff --check PASS (expected LF→CRLF warning); whitelist/protected proof PASS: original 42 suite objects/root blocks unchanged, exact 24 additions, 19 runtime/protected roots unchanged, Q1 code unchanged, only plan/additive suites/tools-baseline paths. Definition still 29 invocations/188 attempts/S7 with digest `ec27c48ccaa9c6cfbb4d647fd9305d36e00443644bd4a83198cb9a96a27fdafc` (pre-freeze). Calibration_1 report SHA still `1fd4c12a7fb740a1996fcf14b3a5e1512836f437b111e15b77d1ca6ad03b51df`; calibration_2 still `698dd2d2aa96061cbb38924be190e609778a94a07a4b98d729a429843af50f98`; neither root overwritten. Next: exactly one A2 targeted validation; no further run authorized if INCOMPLETE.

A2 targeted invocation completed once, separate root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\observer-validation-2026-10-03T173318991328Z`, Q1 run `20261003T173319Z-b20609de`. Exact selection/order rider_s42 then capture_s42. OBSERVER_VALIDATION = PASS: four required suite processes identified by QueryFullProcessImageNameW paths and parent links; rider wrapper/main 166/166 samples, capture wrapper/main 37/37. All four exits nonzero decimal tick strings reconcile with raw exit events; post-exit queries OK; OS/sampled labels recomputed from series agree; required errors=[] and incidental diagnostics=[] for this invocation (earlier four diagnostics retained in calibration_2). Canonical report written normally, no recovery. Report SHA `8b747f8cfe25ab7eef54be529b63ce958ee7cec7d1ef2f8412cbefd26c5c94da`; series SHA `7833c6c5e26abb84d64cf45154a10cf66d592313bbec060e415b78db0bac499c`; summary SHA `ccbd4d24c927ec1aaeffcb5bbc061e995d5dce69f61082827cec8b42e56d9100`. observer_validation_result.json records per-process proofs and ten acceptance conditions. Post-run whitelist/protected audit and diff --check PASS. Q1 rider FAIL/ASSERTION_FAILED with reasons ASSERTION_FAILED, UNEXPECTED_LEAK, UNKNOWN_ENGINE_MESSAGE, COMPLETION_NOT_PROVEN; capture PASS/ALL_REQUIRED_EVIDENCE_SATISFIED. Product observations excluded from baseline; no repair or further validation/calibration run. A1.2/A1.3 and M3 now permitted.

A1 implementation: campaign.py and q2a_campaign.json now carry only approved artifact/receipt/A2 role metadata; aggregate.py generates payload index, separately closed SHA256SUMS/baseline and receipt binding; sc_baseline.run requires/validates/copies receipt before CAMPAIGN_START; campaign/baseline/ledger schemas and README updated. Tests cover nonrecursive closure, raw payload mutation, metadata-only mutation, receipt mismatch. Original planned M1 reporting now also includes cross-suite opening observation table, copied-verdict product aggregate and process-wall all-value statistics; no new metric/statistics policy. Added small source-hashed calibration excerpts, confirmed the declared benchmark regex formats without modification, and a missing-directory negative. Additive-proof selftest verifies frozen HEAD once F exists (before F, working candidate), so permitted later documentation does not masquerade as a freeze violation; final-scope audit remains separate and mandatory.

Final M3 candidate evidence root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\pre-freeze-2026-10-03T174644642988Z`; pre_freeze_proof.json SHA `d0c8e18fa8673e03620605876bd58bb7a7b8f4fdcb6365a878cf796e55e6bb58`. Q2 28/28 OK (4.033 s), unchanged Q1 49/49 OK and manifest 66 OK as recorded above. git diff --check PASS; Q1/protected worktree diff exits 0. All 19 protected root identities equal §0/base; original 42 suites and manifest root blocks deep-equal; exact 24 additions. Changed paths restricted to this plan, tools/baseline/** and additive tools/verify/suites.json. Final pre-freeze campaign_definition_digest `ebf7dd032a8f1d553845f035ff38f398e1975ec65b0c19baa5968c56031e4f15`; 29 invocations/188 attempts/S7/entries/metrics/identities/objectdb/stop/retry policies byte-semantically unchanged from pre-amendment definition. Metadata-only digest change is authorized by A1/A2. Measured implementation is 926 non-comment lines (target 900, exceeded by 26 after explicit role/exit and receipt/index integrity requirements); stdlib only, no added dependency/subsystem or campaign expansion. This target deviation is disclosed, not represented as a hard size gate PASS.

The preceding M3-ready status was historical. F/receipt and campaign are now recorded below at the permitted campaign-completion boundary under A1. No plan edit occurred between F and campaign completion.

### M3/F and frozen campaign — completed execution; M5 reporting STOP

Recorded 2026-10-04 Asia/Qyzylorda (campaign identifiers use UTC 2026-10-03). Local F `a533f2e3248466fea867857184b3458ffdecac75`, tree `44d62e4607b69702af6bf7438a41fc7d70150d99`, commit `Q2A: freeze baseline tooling and campaign with A1 A2`; no push. Exactly 24 approved paths committed. Protected/runtime identities and original Q1 suites remained unchanged. Immediately after F, external canonical receipt at `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\freeze-a533f2e32484-2026-10-03T174919314694Z\freeze_receipt.json`, 4221 bytes, SHA256 `c70df2d07c04e517131304bad6f6c155c227fe90aaad9793f121ca0f951f47b2`; validated clean HEAD=F before first campaign invocation. Receipt binds frozen plan/definition/suites identities and protected proof; copied into campaign root and CAMPAIGN_START. Frozen campaign digest `ebf7dd032a8f1d553845f035ff38f398e1975ec65b0c19baa5968c56031e4f15`.

Campaign root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\Q2A-a533f2e32484-2026-10-03T175011263949Z`. All 29 fixed invocations / 188 declared attempts captured; no infrastructure retry, required-INCOMPLETE gap or runtime stop. P1 expected probes matched. Baseline 166 constituents: 127 PASS / 39 FAIL / 0 INCOMPLETE; copied Q1 product aggregate FAIL, runtime acceptance INCOMPLETE. P3 occurrence census: 8/40 normally completed attempts emitted ObjectDB warning (virtual_rider 4/10, replay_session 4/10, route/session_diagnostics 0/10), no cause inference. P4 five measured rounds plus excluded warm-up retained; all 12 named microbenchmark metrics n=5. P5 three incidental helper errors retained under A2, no reported required-target error. Calibration/targeted validation excluded. No further runtime run is authorized.

Final ledger head `94b0618fd972b6de92f1c18c6ab02f16c739ab548cf5c92350ef843188a767da`. Original payload index SHA256 `acebebb799f93d1ba591e5b7ca8962e598cb021a2f49d6a35c6f28ba29156ea9`; 15440 files, index 3251235 bytes. Original full `aggregate/baseline.json`: 1935518 bytes, SHA256 `31a1e3e980865528b5b048729fbbd153727ff1d0b801583529b7ca41608ef7e2`. Original baseline/index/SHA256SUMS snapshots also preserved outside the campaign root. CAPTURED describes raw execution completeness, not Q2A acceptance.

M5 demonstrated reporting defects, with implementation still unchanged at F:

- Full baseline alone exceeds §13 total repository-directory <=1 MB budget. A compact bound-field-reference representation changes the public record contract and requires approval.
- `aggregate.py:148` groups process-wall statistics across observer OFF/POLL-250ms: rider/route n=14 (12 OFF + 2 ON), capture/pinned soak n=4 (2 OFF + 2 ON). D3 requires separation.
- `extract.py:91` / `aggregate.py:111,135` do not dereference capture frame metadata. Independent read found 162 actual producer geometry_checkpoint.signature rows; current RI-CAP record loses them. Frozen definition source shorthand must not be silently rewritten.
- `envinfo.py:26` labels microsecond values as mtime_ns (`st_mtime_ns // 1000`). Original env evidence remains immutable; unit correction belongs in derived reporting/future producer.

Read-only preliminary `slow-cycle-verify` result FAIL, with incomplete final coverage explicitly listed. Evidence/proposal root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\m5-reporting-proposal-2026-10-03T185407161292Z`. `verification_report.md` SHA256 `0e9b24953d1802f68dce72eaa6a004e447d905e6e5cac9030c8fc34046e802ca`; independent_audit.json SHA256 `1fe99df4a2e7b0e1dd017094e813f9c6cf399d041e0e1b83a1216b3b4a869577`. Script imports neither Q1 nor Q2 and asserts ledger chain / all 188 result hashes and copied verdict/reasons / mixed groups / referenced capture metadata. Fresh Q2 28/28 OK (3.793 s), unchanged Q1 49/49 OK (10.988 s), manifest 66 suites / 209 rows OK, diff --check clean; full test logs retained. Full independent V6 metrics/leaks/PNGs/directories/index/checksums, final V1–V15, durable V14 and independent review remain NOT_COMPLETED. No VERIFY PASS or global runtime acceptance is claimed.

### Proposed HUMAN AMENDMENT A3 — historical proposal; subsequently approved below

Concrete proposal `A3_proposal.md`, SHA256 `28875eefc913c3d628f7275c3303aa3c1f6c75a47aa57ba77c6af5df6c4ae786`, requests only compact explicitly bound durable-record representation; split wall statistics by suite/configuration/observer; dereference existing RI-CAP producer metadata and regenerate derived comparisons under existing eligibility; correct mtime unit annotation/future field name while retaining original env files. Draft compact record 669168 bytes + key-artifact lines 197675 bytes = 866843 bytes before README/closure headers. Draft is not final: RI-CAP comparisons and complete producer/schema/tests/verification remain pending. proposal_facts.json SHA256 `75b4c289a9713e1d795e68cdb80f96f8bb18c153c679a8c713f121387c2a786a`.

Requested paths are only Q2 aggregate/extract/envinfo, baseline schema, existing Q2 aggregate/extract selftests, tooling README, and already-approved durable/status/navigation/plan paths. Preserve F, frozen definition/digest, receipt, ledger, raw Q1/observer/env evidence and all original derived snapshots; explicitly bind corrected reporting source after F. No new F, campaign, calibration, retry, seeds/matrix/ordinals, test weakening, production/Q1/player changes, ObjectDB diagnosis, Q2B or R0. After approval only: reporting fixes and fresh complete verification from retained raw evidence; stop at VERIFY PASS / AWAITING_INDEPENDENT_REVIEW. A3 implementation is blocked pending human approval under A1 and root contract-expansion rules. No completion/archive/push.

### HUMAN AMENDMENT A3 — approved 2026-10-04

Human source: attachment `2097c1d4-056a-43b9-8a27-68911843994d/Вставленный текст.txt`, read in full. A3 supersedes the pending proposal only in the explicitly approved reporting scope. Authorizes compact explicit repository representation plus hash-bound full external record; wall statistics stratified by observer mode AND workload role; RI-CAP dereference with signature/source path/SHA/seed/config/attempt provenance and honest missing/malformed status; truthful mtime_us compatibility correction. Add Q2 tests for all eight A3.6 requirements; Q1 unchanged. Regenerate only derived M5 outputs from the same 188 frozen attempts; complete fresh V1–V15. All original raw/ledger/manifest/observer/log/PNG data and product counts 127 PASS / 39 FAIL / 0 INCOMPLETE, 29 invocations, 188 attempts, 166 baseline attempts, retries=0 remain immutable; mismatch requires STOP. Preserve preliminary FAIL/proposal. No Godot/harness runtime, new F/digest/seed/matrix/ordinal, Q2B/R0. Fresh VERIFY PASS must STOP at AWAITING_INDEPENDENT_REVIEW, with active plan retained, no archive/completion commit/push. Fresh new contract/scope issue requires STOP rather than A3 expansion.

A3 implementation/M5: exact reporting changes in aggregate/extract/envinfo, baseline schema, tooling README and existing Q2 aggregate/extract selftests. Four added tests cover A3.6's eight conditions plus malformed/ambiguous/seed-mismatched referenced metadata and oversize/accountability negatives. Q2 32/32 OK (3.728 s). Initial new test exposed missing derived-index parent directory; production artifact_closure now creates its own derived parent, with assertions unchanged. No Q1/player/test/gate mutation.

Fresh M5 evidence `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\A3-reporting-2026-10-03T1912101377573Z`. generate_m5.py reconciled all 188 attempts and checked 15438 immutable original raw files before and after derived regeneration. All run_refs equal the original failed report, product counts remain 127/39/0, retry count 0. All 162 RI-CAP referenced signatures are OBSERVED with source/hash/seed/config/attempt provenance. Wall statistics stratify configuration/observer/workload role (P5 explicitly memory_evidence). Historical raw env unchanged; derived mtime_us preserves numeric values. Explicit full-external/1 and compact-repository/1 schema variants. Reporting source digest `2f6bd732074f706bee511ba683899755beba5982e217d84739c586bd51db6c89`; frozen F/definition/ledger unchanged.

Durable Q2A directory generated: compact baseline 675256 bytes, key/closure/attempt index 242667 bytes, README 3805 bytes; total 921728 bytes <=1000000. Full external report 2150455 bytes, SHA256 `0b9e562e0a16042afa641f028b790a1ba8e2dee11f306f7d0626b0baf74ef608`; corrected payload digest `38f71c04e848415b53aeea728db0821fc536ed522cfb6767cc4bec13d0019c96`. These derived hashes differ as expected; original failed snapshots retained. Status/navigation updated only in the three approved documents. Complete fresh VERIFY and independent REVIEW not yet complete; no new runtime execution or commit/push.

### Fresh A3 VERIFY PASS — 2026-10-04; required review handoff STOP

Used slow-cycle-verify read-only after reporting implementation. Full independent V1–V15 script (imports neither Q1 nor Q2) PASS: all 188 copied results/reasons and directory digests, all metrics/RI identities, 1958 eligible comparisons, 162 referenced RI-CAP signatures and PNG hashes/dimensions, full payload/index/SHA256SUMS, all 15438 original raw files unchanged; 29 invocations/188 attempts/166 baseline attempts/0 retries; product 127 PASS / 39 FAIL / 0 INCOMPLETE remains unchanged. Protected 19 roots and all Q1 code/original 42 suite objects/manifest root blocks independently unchanged; exactly 24 approved suite additions. Receipt's 3 blob identities and 18 required Godot process executable/parent identities confirmed. Helper diagnostics retained: OpenProcess(87) x1, QueryFullProcessImageNameW(31) x2. Two calibrations and A2 targeted validation report hashes unchanged. Q2 32/32 OK (4.114 s), Q1 49/49 OK (10.888 s), manifest 66/209 OK, diff --check clean. P1 expected timeouts are ordinals 5/6/7/17; probe expectations match; no required baseline timeout concealed. Actual checks/coverage and full diagnostic inventory retained rather than expected budgets substituted.

Final `verification_report.md` at the A3 evidence root, SHA256 `ec0750a06a843801e6a9047b771926ee2be84720921f7729e7eb8520027731e0`. independent_V1_V15.json SHA256 `94b28e9807e52a5a08cf8e53cfea89e29e091a61058f66b803914ab3eae4279a`; supplemental_identity.json SHA256 `8148512e087ede47bb00cdf6dbdeb6c7411bce58640ff3accc1c24b0a6757dce`. Audited dirty source inventory SHA256 `6f89d8366f9148644729d15cac1c3156cb422c0b315c02de7b29342e436d412f`, tracked base..working diff SHA256 `0ebff6d88ea2164d7549981e2db2841ea9227c3adf9deb284fe6ce9028cf5c40`. Subsequent status/plan/navigation handoff edits only are bound by external final_status_audit.json; reporting implementation/tests/baseline/index/full report remain unchanged.

Verification-script intermediate failures were kept as audit1/audit2 history: doubled observer path and unintended canonical-JSON identity-key-order assumption corrected in the auditor, without dropping comparison records. Supplemental initial API-shape assumption corrected to preserve both WinAPI diagnostic formats; no observer/code/data correction. Initial Q2 derived-parent failure fixed before the fresh passing tests. Preliminary M5 FAIL/proposal remains preserved. Approval review briefly unavailable from usage limit; failed action was not executed, resumed after human confirmed reset. Not a safety rejection or evidence gap. Environment Git-ignore and LF→CRLF warnings remain recorded without configuration/file normalization.

Measured production tooling now 1036 nonblank/noncomment lines versus original 900-line target (136 over), disclosed for independent review; repository size budget unchanged and satisfied. No dependency/subsystem introduced. Fresh VERIFY certifies the reporting/evidence package, not clean game runtime. P3 8/40 ObjectDB occurrence remains, no cause claim. C10/C12 OPEN, runtime acceptance INCOMPLETE, no E5 human review or E7. Independent REVIEW NOT_RUN. STOP here: active plan retained; no archive/clear/completion commit/push/Q2B/R0. Final status audit is read-only plus external reporting, and does not authorize independent-review execution.

### HUMAN AMENDMENT A4 — approved 2026-10-04; R1 REJECT accepted

Human attachment `3a7fef55-ab8e-4355-a2cd-70497798f813/Вставленный текст.txt` read in full. R1-F1 is accepted: the old RI-SESSION hash consumed whole route_choices, including physics_tick and incidental runtime fields, causing 65 false EQUALITY_ELIGIBLE MISMATCH. A3 VERIFY PASS is historical and insufficient for acceptance after this finding. A4 authorizes only derived extraction/identity/reporting and four minimum Q2 selftests; no Godot/harness/calibration runtime, new F, seeds, matrix, attempts, retries, Q1/production/test/gate changes. Whitelist exactly fork_id/choice/selected_branch_id/selected_seed plus existing emitted opening/selected_arm signatures; no geometry recomputation. physics_tick retained separately as REPEATABILITY_OBSERVATION. Components and source attempt/run/relative path/SHA remain inspectable through the full/compact hash-bound record.

Preserved byte-exact A3 full/extraction/reconcile/index/SHA256SUMS and human A4 decision under external package `aggregate/superseded/A3`; receipt SHA256 `a9ad0c66fb0aca5e3647c11736be4716700681b659e8e5bc98c6bbfe989c5f26`, status SUPERSEDED_BY_A4; old counts MATCH=1/MISMATCH=65/NOT_OBSERVED=23 retained. A4 evidence root `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2a-evidence\A4-reporting-2026-10-04T0600406179720Z`. Original frozen raw/definition/receipt/ledger/observer/log/PNG/session manifest files immutable. Recompute producing eligible comparisons from evidence; expected 66/66 MATCH, discrepancy requires STOP. Product must remain 127/39/0, attempts188/baseline166/retries0. Fresh complete VERIFY V1–V15 required; PASS must STOP at AWAITING_INDEPENDENT_REVIEW, no independent review by author, archive/final commit/push/Q2B/R0.

R1 nonblocking findings retained without correction: NB1 stderr ObjectDB warnings absent from engine.log (carry to separately approved Q2B); NB2 ineligible/nonproducing identity candidates inflate NOT_OBSERVED; NB3 conservative default-path RI-OPEN exclusion accepted; NB4 short-lived unlabelled Godot --version process pair; NB5 approximate tooling size target exceeded. These authorize no expansion. Current A4 intake is the A3 dirty reporting/status package, 11 modified + 4 new paths, staged none; branch/HEAD/base unchanged. Global ignore permission and LF→CRLF remain environment warnings; no configuration or line-ending cleanup.

A4 derived generation independently checked raw hashes before/after, all188 run_refs identical to A3, all other identity values/comparison records unchanged. Actual RI-SESSION results: 66 EQUALITY_ELIGIBLE MATCH, 0 MISMATCH, 23 nonproducing NOT_OBSERVED retained. Physics ticks: 65 DIFFERENT / 1 IDENTICAL / 23 NOT_OBSERVED repeatability pairs; 36 emitted per-seed component/timing observations retained with provenance. These are computed outputs, not forced results. Full report 2418832 bytes SHA256 `57bf601dab4b8b93607d3018eb10a6900a8c615177442168249ddfdd9af3574c`; reporting source digest `dbe8e6a1bb813879e5ffa2e5cef1394c6d55fe063b09140dc389b5ddf916f760`; payload digest `26abdc1445236a58d4ae4f8d2d2fd5ec8ca4f053ea2678ec1ba17e95874e882c`. Durable package927825 bytes <=1000000 (compact678394, index243555, README5876); final status text will be checked again. Q2 36/36 OK (2.704s), unchanged Q1 49/49 OK (10.343s), manifest66/209 OK. Initial direct unittest discovery used the wrong import path and produced five import errors before tests ran; documented sc_baseline.py selftest then passed without code/assertion changes. Fresh full VERIFY pending; no runtime execution or phase transition.

### Fresh A4 VERIFY PASS — 2026-10-04; required STOP

Used slow-cycle-verify in a read-only implementation/test phase. Full fresh V1–V15 passed on first A4 audit execution; independent script imports neither Q1 nor Q2. All188 results/reasons/directory hashes and15438 accepted original raw files unchanged;29 invocations/166 baseline attempts/0 retries; product127/39/0. All1958 identity comparison records independently recomputed. RI-SESSION whitelist/component/source provenance confirmed from raw manifests:66/66 producing eligible MATCH; separate ticks65 DIFFERENT/1 IDENTICAL;23 nonproducing NOT_OBSERVED retained. All unrelated identities/comparisons equal preserved A3. Original65 false mismatches and whole-object composite independently reproduced and retained SUPERSEDED_BY_A4; historical files/receipt hashes verified. No Godot/harness runtime occurred; F/definition/receipt/ledger/run/artifact identity unchanged.

Full raw metrics/P4 statistics/wall and observer semantics/mtime values/162 PNGs and RI-CAP signatures/28 Vulkan manifest provenance checked;19 protected roots and Q1 blobs unchanged,42 original suite objects+root blocks unchanged, exactly24 approved additions. All152/188 completion markers and actual coverage/certified assertions retained;336 diagnostic rows; only expected P1 OS timeouts5/6/7/17. Supplemental3 receipt blobs/executable hash/18 required parent-executable identities and3 helper diagnostics checked; both calibrations/A2 validation hashes unchanged. Q2 36/36 OK (2.704s), Q1 49/49 OK (10.343s), manifest66/209 OK, diff --check clean. Tooling1076 nonblank/noncomment lines vs approximate900 target (176 over), disclosed NB5; no refactor authorized.

Fresh A4 evidence root as above: verification_report.md SHA256 `ffc1232d3e3903a18193b10e3d18ba51ac046b426fe9c1ffae5a2888e4653681`; independent_V1_V15.json SHA256 `856613b0caddd1c30c6ebb81f36e1e65efcab1942595185bf0bfd1182efa3abb`. Audited dirty source inventory SHA256 `0ccb57f4edc69101b23f58c2065ca94e80a5685852322cff16073d866db4cb35`; tracked base..working diff SHA256 `cdac8bb53f584d8df74e0c70e8f3580bd9fd9dbfcb7da5fd6447af0f3f4aa4f9`. Only subsequent plan/README/status/navigation handoff edits are allowed; final_status_audit.json binds those final bytes and proves reporting code/tests/schema/compact/index/full report unchanged. No new contract/scope issue found. R1 NB1–NB5 recorded without fixes. Prior A3 PASS remains historical after accepted R1 REJECT; fresh independent REVIEW pending. Product FAIL/runtime INCOMPLETE, C10/C12 OPEN, E5 human NOT_PERFORMED/E7 NOT_CLAIMED. STOP AWAITING_INDEPENDENT_REVIEW: active plan retained; no archive/clear/final commit/push/Q2B/R0.

1. v1.1 approval reference.
2. M1/M2 results and every calibration change.
3. M3 freeze proof, `campaign_definition_digest`, F.
4. Campaign summary and ledger head.
5. Any `GAP_DECISION_REQUESTED` list and the human decisions.
6. VERIFY / REVIEW report identities.

## 25. Handoff

- [x] Git identity recorded; amendments A–H and decisions D1–D6 applied; completeness pass over 66 TEST_MATRIX contexts, world-AGENTS gates and Master Q2 done (read-only).
- [x] Exact campaign: 24 additive entries, 29 invocations, 188 ledgered attempts (22 probes + 166 baseline: 5 warm-up, 25 measured performance, 8 memory, 128 other).
- [x] Approval intake initially changed only `implementation_plan.md`; subsequent approved implementation added tooling and 24 suites. One M2 invocation ran all 12 suites; observer failure is disclosed in §B. Existing tests, production and gates untouched; no ObjectDB diagnosis.
- [x] Final human approval of v1.1 → M0 passed (see §B).

Test Integrity Verification: production/Q1 tests changed — NO; Q2 selftests extended — YES under explicit A3.6/A4.6; existing assertions/thresholds/coverage/gates weakened — NO; skips/suppression/hooks — NO; game-green status claimed — NO (product FAIL/runtime acceptance INCOMPLETE).

**Q2A EXECPLAN v1.1 + APPROVED A1/A2/A3/A4 — STATUS: AWAITING_INDEPENDENT_REVIEW. Fresh A4 VERIFY PASS V1–V15; R1 REJECT accepted/F1 corrected, fresh REVIEW pending; F/campaign/verdicts immutable; product FAIL/runtime INCOMPLETE; no completion/archive/final commit/push/Q2B/R0.**
