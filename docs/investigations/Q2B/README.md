# Q2B — accepted Stage D diagnosis and accepted Stage F F1

STATUS: Q2B COMPLETE — Stage D VERIFY PASS (original FAIL retained, A1) + independent R1 PASS; Stage F VERIFY PASS (FV1–FV15) + independent R2 PASS (`blocking_findings = none`); human G3 accepted. Completed record: [Q2B.md](../../plans/completed/Q2B.md). C10 OPEN; C12 OPEN; runtime acceptance INCOMPLETE; R0 NOT STARTED and must not begin until Q2B is merged and verified on master.

Stage D is accepted by A1 VERIFY PASS and independent REVIEW R1 PASS. The final diagnosis uses the distinct confidence levels below; bare ROOT_CAUSE_PROVEN is never the final diagnosis.

| Claim | Final confidence | Scoped conclusion |
|---|---|---|
| A | PROVEN | BikeAudioManager is causally responsible for the measured six-object signature. |
| B | PROVEN | Verbose same-process provenance identifies 3 AudioStreamWAV and 3 AudioStreamPlaybackWAV from Wind/Gravel/Skid. Non-verbose membership is inferred from count compatibility, not direct per-run class attribution. |
| C | STRONGLY_SUPPORTED | Process-exit delayed audio-resource teardown, with no accumulating tracked-owner retention on the exercised path. |
| D | NOT_PROVEN | The exact low-level mechanism or race inside Godot AudioServer. |

## Immutable Stage D / A1 / R1 history

Branch `q2b-objectdb-lifecycle`; base/HEAD `d0a71eb29b167b964d43da5bfcfe2012067d8f69`. No commit or push. Q2A has 15,449 immutable checksum entries; historical 39 FAILs (35 out of remediation scope) and four rider FAIL/UNEXPECTED_LEAK observations remain unchanged and unreclassified.

Stage D ran 150/150 attempts, retries=0. NORMAL 14/30; AUDIO_REMOVED 0/30; WAIT 0/30. Each one-sided Fisher comparison is exactly 69/8230264 = 8.38369218776e-06. NORMAL CP95 [0.28342, 0.65674]; zero arms CP95 [0, 0.11570], one-sided 99% upper 0.142304. Verbose classification and non-verbose incidence remain separate. The frozen signature uses Wind/Gravel/Skid same-process ID matches, k=1, C_target={6}; IDs are never compared across processes.

D3 used three processes with three cycles each: all 27 tracked group/cycle survivor records were zero after bounded 503–504 ms settle; nine cycles. Global counters were observational. This does not prove a globally leak-free game. Historical four Q2A rider leaks have compatible / strongly supported indirect attribution; no retrospective per-run class proof is claimed.

The original failed VERIFY remains historical: `verification/report.json` SHA256 `88a4b9eaac892453cb9112fb172836ae1ea3a439f46f18c7f7f8964d2fcd614d`. Its quoted historical `ROOT_CAUSE_PROVEN` field is not the final diagnosis. Original signature freeze SHA256 `f7b395372133463ca84b2fdbc01aedc5e9f82eb46c1f1525e99c34226d8dfe80`; campaign SHA256SUMS `8d618e255ada849f25244fa9c846c6ac7ddb018af5a0b64b923078583f9eea34`; ledger head `e9596cc386bdc57c44fc28bdf346358c4c88b4dfa4f9ed56b78f87775c9e782d`.

A1 corrected only diagnostic representation from frozen evidence: engine object paths remain empty/NOT_OBSERVED when only reference-count tails are emitted; no path is inferred from class, ObjectID, owner or source. Tree exclusion identifies the unique owned streamer by same-cycle class/topology, excludes only its descendants, and preserves unrelated nodes. Ambiguous roles/topology stop rather than invent identity. Both initial offline bookkeeping failures and the first A1 audit FAIL remain retained. The fresh A1 VERIFY passed V1–V15; SHA256 `a539cb5fce4f09c7b4e040974051d76c7a6a59e51d707b201e44466b48fd0a92`. A1 added no Godot invocation. A1 SHA256SUMS `b38ad6fc50c37bb312e384aefff5c7ce2b3a32f28d66616281cff9656f86523f`; verification manifest `a42a0a74227f7deb07a1a2eb8a9b7b830beb951bc3d07f2291813eb9b19cb385`.

R1, fresh independent reviewer Claude Opus 5.5, returned PASS with no blocking findings. Review SHA256 `f5443a955594fe0b2e90d993e0b94387a13f409d2da065fe200e54d7b69869b6`; human G2 decision `c825716f3c9b17ad8fc7bac75dce5ea098f38bf0bad3856add9dbb215da32e5e`; R1 manifest `e367729154904b581bbe7d33a99aaed1d373712da1e8209f69edd07b3edea7d6`. G2 chose PROCEED WITH BOUNDED REMEDIATION, followed by explicit F1 approval with binding A/B/C clarifications on 2026-10-04 (Asia/Qyzylorda).

## R1 non-blocking findings relevant to G2

NB1: D2-R historical raw target-warning incidence:

| D2-R suite | Target warnings / attempts | Existing Q1 outcomes |
|---|---|---|
| session | 0/10 | 10/10 PASS, preserved |
| replay | 0/10 | 10/10 PASS, preserved |

Non-verbose replay is a weak positive control because it was already 0/10 before remediation. Versus Q2A P3 replay 4/10, one-sided Fisher = 0.04334365, above alpha 0.01. Versus verbose D1-R replay 6/10, Fisher = 0.00541796. Timing, verbose mode, and launch conditions affect incidence; the conditions are never pooled. Stage F therefore uses a contemporaneous 30/30 probe control and a separate verbose real-entry comparison.

NB2: the A1 probe had never run in corrected form; Stage F retained parse and LEGACY/FIXED runtime sanity before counted execution. NB3: A/B/C/D wording above replaces the final bare label. NB4: the reviewer byte-confirmed protected paths despite a textual original V13 assertion; Stage F compares raw bytes. NB5: verbose `Orphan StringName: Ambient/SFX` observations correlate historically with leaking runs; they are retained observationally, never allowlisted or treated as the target class signature. NB6: internal ledger chronology has no external timestamp; this limitation persists.

## Stage F implementation and predeclared matrix

The production audio/gameplay was not changed. Production scenes/assets, WorldManager, ChunkStreamer, player/camera, project.godot, Q1 harness/classifier/thresholds/detection/policies and Q2A tooling/evidence are protected. Route, macro-profile, soak and unrelated suites remain outside remediation scope; their historical route/soak/macros warnings remain known residuals, with no new attribution claimed.

The shared helper requests a constant 250 ms using normal SceneTree process frames, prints exactly one `SC_TEARDOWN_SETTLE requested_ms=250 elapsed_ms=... frames=... exit_code=...` line to stdout, and preserves the caller exit code. It reads neither ObjectDB nor stderr and never dynamically extends the wait. Acceptance requires elapsed 250–500 ms. Rider changes only its two normal-teardown exits; early errors are unchanged. Replay preserves both existing awaited frames and adds the helper before its final quit. Probe LEGACY retains actual immediate quit after free; FIXED calls the real shared helper.

LEGACY and FIXED are separate Godot processes. Same setup means equivalent pinned engine SHA/version, source identity, seed/config, production scene, probe path except the approved arm, topology and ordering. Pairs alternate LEGACY→FIXED / FIXED→LEGACY. Normalization uses the A1 semantic streamer role; no count-only topology inference is added.

| Ordinals | Declared group | Count |
|---|---|---|
| 1–4 | Four script check-only parses | 4 |
| 5–6 | Retained LEGACY/FIXED sanity, excluded from statistics | 2 |
| 7–66 | Interleaved counted LEGACY/FIXED | 30 + 30 |
| 67 | Untouched session manifest producer | 1 |
| 68–77 | Verbose replay real entry | 10 |
| 78–117 | Unmodified Q1: session/replay/rider plus second rider per round | 10 + 10 + 20 |
| 118–120 | Unmodified Q1 no-manifest negatives | 3 |

Engine `4.7.2.stable.mono.official.ed1daf0bf`, SHA256 `2445d009a5e0474fc7064b9767100e9d2c09521890ac5625476bfb81cf03f2d4`; observer off, one runtime process at a time, probe seed 184729, original Q1 timeouts. Read-only `--version` identity queries by the diagnostic runner/Q1 are metadata queries outside the 120 declared executions/checks. Matrix SHA256 `e33a184b704b39385af6de96bf825361138a7d4b4bb3c797b7684ec82c4d2c3a` (retained canonical copy); source matrix SHA256 `fcbbc1704696d21f6e314cd5a14e0b2690acdbfb735af818aa8d0f9fc9c50a06`.

Infrastructure tolerance is zero. Every declared completed count is required. Any infrastructure or parse/sanity failure stops; no reduced n, replacement, retry or automatic restart. Intentionally negative MANIFEST_MISSING is not infrastructure failure. LEGACY <7/30 is INCONCLUSIVE and stops; any FIXED leak is FAIL and stops. The wait is never tuned.

Preflight: Python AST checks, 31 Q2B tests (16 retained A1 + 15 F1), 49 Q1 tests, manifest validation (66 suites / 209 rows), exact teardown diffs, protected raw-byte baseline and all immutable manifests passed. One read-only locator was corrected because the unchanged Stage D matrix is absent from A1 source_after: immutable Stage D env.json pins its raw SHA256 `69a43c2e1825d1164ab0b592b137bfd8247476ee435a6af61065495020b6767c`, also unchanged against the Stage F baseline. No execution was discarded/replaced for that bookkeeping correction.

## Stage F measured results

Evidence root: `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2b-evidence\Q2B-F-d0a71eb29b16-20261004T091958695127Z`. Executed-source snapshots, raw stdout/stderr/engine logs, Q1 results, approval, matrix, preflight, ledger and SHA256SUMS are retained. Accounting: 120/120; retries=0; replacements=0; stop=`None`.

| Group | Target warnings | Any ObjectDB/leak warning attempts | Confidence bounds on target rate |
|---|---|---|---|
| LEGACY | 11/30 | 11/30 | CP95 [0.199298625012, 0.561440150988]; one-sided exact 99% upper 0.593946519591 |
| FIXED | 0/30 | 0/30 | CP95 [0, 0.115703308222]; one-sided exact 99% upper 0.142304101409 |

Primary one-sided Fisher P(FIXED)<P(LEGACY), alpha 0.01: exact fraction `161/1010021`; p=0.0001594026262820278. CP95 uses the exact binomial Clopper–Pearson method (numeric quantiles); upper99 is the one-sided exact binomial bound. Zero observed warnings does not mean zero probability. Only the counted 30/30 enters the primary statistic; sanity, verbose and Q1 runs are separate.

- verbose_replay: 10 completed; raw leak-warning attempts 0/10; CP95 [0, 0.308497107819]; one-sided exact 99% upper 0.36904265552.
- virtual_rider: 20 completed; raw leak-warning attempts 0/20; CP95 [0, 0.168433470983]; one-sided exact 99% upper 0.205671765276.
- Q1_replay: 10 completed; raw leak-warning attempts 0/10; CP95 [0, 0.308497107819]; one-sided exact 99% upper 0.36904265552.
- session: 10 completed; raw leak-warning attempts 0/10; CP95 [0, 0.308497107819]; one-sided exact 99% upper 0.36904265552.
- negative_tests: 3 completed; raw leak-warning attempts 0/3; CP95 [0, 0.707598226179]; one-sided exact 99% upper 0.784556530997.

Q1 result.json outcomes are copied verbatim; Q2B never re-derives or overrides verdicts. Rider distance contract remains 355.9 m at the existing seed/launch contract and 350/500 m threshold. This is not full 500 m route acceptance. Replay coverage remains the existing 3 checkpoints / 1 choice and geometry replay semantics, not physical Input replay. Session warnings: observed 0/10; nothing was escalated and there was no scope expansion.

Expected negative outcomes (existing Q1 contract, exact verdict/reason semantics rather than an invented generic label):

- Ordinal 118: `PASS / ALL_REQUIRED_EVIDENCE_SATISFIED`, exit 1, negative record `{"expected": "^MANIFEST_MISSING$", "not_exercised_reason": null, "reason_found": true, "reported_reason": "MANIFEST_MISSING"}`.
- Ordinal 119: `PASS / ALL_REQUIRED_EVIDENCE_SATISFIED`, exit 1, negative record `{"expected": "^MANIFEST_MISSING$", "not_exercised_reason": null, "reason_found": true, "reported_reason": "MANIFEST_MISSING"}`.
- Ordinal 120: `PASS / ALL_REQUIRED_EVIDENCE_SATISFIED`, exit 1, negative record `{"expected": "^MANIFEST_MISSING$", "not_exercised_reason": null, "reason_found": true, "reported_reason": "MANIFEST_MISSING"}`.

Settle evidence: 74 stdout records across 74 modified normal teardowns under `attempts/` (`engine.log` mirrors each, so 148 raw cross-channel occurrences there; the `q1/` run directories hold 33 + 33 further original copies; `stderr.log` has none); observed elapsed range 255–256 ms; exit codes match the actual intended caller/process exit; negative checks retain exit 1. No suppression/filter/allowlist change.

Verbose 0/10 versus frozen D1-R 6/10: exact one-sided Fisher 7/1292 = 0.00541795665635. Historical Q2A rider P3 4/10 versus new rider 0/20: supporting comparison 2/261 = 0.00766283524904. Non-verbose Q1 replay 0/N is regression evidence only, not primary causal proof.

## Verification, limits and test integrity

Fresh full FV1–FV15 VERIFY PASS against the resulting source/diff and retained evidence: immutable Stage D/A1/R1/Q2A; exact scope and protected bytes; original Q1 detector/authority; exact teardown hunks; valid LEGACY control and FIXED acceptance; all regression/negative counts; fixed bounded settle; no suppression; honest diagnosis and gates. Full read-only independently recomputed report: `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar-q2b-evidence\Q2B-F-d0a71eb29b16-20261004T091958695127Z\verification\report.json`. Independent Stage F REVIEW R2 returned PASS (`blocking_findings = none`), as supplied by the human owner; the reviewer did not store the report, so no repository report path or hash exists and none is invented. Human G3 acceptance was granted. Historical runtime acceptance remains INCOMPLETE, C10 OPEN, C12 OPEN, R0 NOT STARTED. Warning-detection integrity limit: the Stage F Q1 runs did not themselves produce a leak; detection integrity rests on the LEGACY positive control 11/30, byte-identical `tools/verify/**` and the unchanged Q1 detector/classifier. The Stage D and Stage F matrices were untracked during execution and are hash/evidence pinned (see the completed record). Route, macro and soak remain documented residual suites; R1 NB6 (no external ledger timestamp) remains non-blocking.

- [x] Real production paths and retained raw evidence; no mock/hardcoded production hooks.
- [x] Existing tests changed only by human-approved teardown hunks; assertions, thresholds and early-error exits preserved.
- [x] No skips, assertion weakening, warning filtering/suppression or reclassification.
- [x] Scoped checks do not assert global business/game readiness or exact Godot internals.

The first Stage F full audit produced a false FV3 scope FAIL because its Git helper stripped leading porcelain whitespace from the first row, truncating the path. Its report and exact audit source are retained in verification/first_scope_audit_report.json and first_scope_audit_f.py. The checker now preserves the status columns; a fresh complete FV1–FV15 audit passed. No source change, runtime retry/replacement, discarded observation or relaxed criterion resulted.

Q2B closeout: single local completion commit; no push, no merge, no R0 branch or work.
