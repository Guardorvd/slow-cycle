# BC0 — Architecture & Documentation Migration to B+C route realization: completed record

TASK: BC0 — roadmap Phase 0 (documentation and governance only)
STATUS: COMPLETE (2026-10-12) — VERIFY PASS (#4 on the final candidate, after #1 FAIL, #2 PASS, #3 PASS) + independent REVIEW PASS (#2 on the final candidate, after #1 REJECT)
APPROVAL: Game Director in chat 2026-10-12 — «APPROVE BC0 ExecPlan v1.0», SHA-256 `abccce2168c2cd0bb50dc2b0bbb8f6ec40fb5a63e8d6d1b70ac696d8d0cf9a11` (approved file `53a69f2:docs/proposals/BC0_EXECPLAN.md`, embedded verbatim below); conditions: (1) the roadmap becomes ACCEPTED only after independent VERIFY/REVIEW PASS and BC0 closeout — applied at this closeout; (2) the presumed PR1 cache key is not presented as confirmed — recorded in the [PR1 record](../suspended/PR1.md) §6
BRANCH/BASE: `bc0-architecture-migration` / `beacc9c4258c4abfaec58443cf6e6a25b7b7140d` (= `origin/pr1-playable-region`, tag `pr1-suspended-baseline`)
VERIFIED CANDIDATE: `633895f8351433a5abed3070c86bbb27bf2ea5d7`; SHA-256 of `git diff beacc9c 633895f` = `2fb586cc935b1fa62e873bd7dfdd2b28003cc9e16389d2650fe37a7175619b4a`. The closeout commit adds only transcription (this record, slot → NO_ACTIVE_PLAN, ACCEPTED status, links re-based to this record, Current Project State status line, PR1 record owner label); its SHA is reported outside the record
EVIDENCE ROOT: `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/` (author checks `bc0_checks.py`, `l2*/`; reports `verify*/`, `review*/`)
PUSH/MERGE: none; local commits only

## 1. Result

- **PR1 → SUSPENDED** (not COMPLETE, not PASS) under the new [PLANS «Suspension lifecycle»](../../../.agent/PLANS.md) and the AGENTS clause (§A1–A4 verbatim): [record](../suspended/PR1.md) with milestone and DoD state, D1–D13 state, known failures, reproducible baseline, obligations and a byte-identical copy of the PR1 plan (SHA-256 `e63de9c1…38a4`).
- **Roadmap** [B+C route realization](../../ROADMAP_B_C_ROUTE_REALIZATION.md) — approved v2 text, links re-based; **ACCEPTED** at this closeout, with the errata in §4.
- **Authority documents aligned:** Master XII-B amendment + pointer lines (R9–R21 goals unchanged); Target Architecture additive B+C rows and §8; Migration Matrix B+C section; Test Strategy §8; Current Project State; ARCHITECTURE.md status and §6; navigation. Blueprint, TEST_MATRIX, tests, code, scenes, resources, tools, skills and scoped AGENTS unchanged.
- **No test, assertion, threshold, category or gate changed.** Godot not run (Markdown-only class).

## 2. Verification and review

| # | Kind | Candidate | Result | Report SHA-256 | Key findings |
|---|---|---|---|---|---|
| 1 | VERIFY | `83e2695` | FAIL | `f388720b13a40a31610b3ead73e664132365f34f1a8348a77e4d2cbd98319ed9` | B1 roadmap content changed beyond «links re-based» (→ F1, restored v2); N1–N10 (→ F1) |
| 2 | VERIFY | `1db5323` | PASS | `b44cdb7e969257f2b349fd2e2b0b1d199f0479247bce0fe318d6870eab4f5f50` | M1–M3 record wording (→ F2), M4 ledger, M5 errata, M6 closeout links |
| 3 | VERIFY | `ce7edff` | PASS | `d841a40828351b73e2669445ca75e7219cb2e24e992507f694668030075af301` | F2 impact set; P1–P3 (ledger, wording, reverted-edit marks) |
| 1 | REVIEW | `ce7edff` | REJECT | `61c48ed49076a7b3febd91bb55d2533e44ce135641f5ac3f0f5430efe1efc6c3` | R-B1 unapproved legacy retirement gate and category claim in Migration Matrix step 3 (→ F3); R-N1–R-N10 |
| 4 | VERIFY | `633895f` | PASS | `16651b3e8c3a77b897ff62b366f2b413112defce93dafee592c5cd8097a3ca29` | F3 impact set; V4-N1–V4-N4 non-blocking |
| 2 | REVIEW | `633895f` | PASS | `de4c1a8921954234c061d3c53b201678c9e69b4a23d74374f6838c82573c42a8` | no blocking; R2-N1–R2-N6; closeout items acceptable as docs-only transcription |

All verifiers and reviewers ran in separate fresh agent contexts, read-only for the repository; reports are stored only in the evidence root. Closeout checks (link, scope, hash) are recorded in `bc0/closeout/`.

## 3. Carried non-blocking items (not edited in BC0)

- **R2-N1 / V4-N1:** «mandatory at L2» for `test_final_surface --source=fixture` (Test Strategy §8.4, PR1 record, Current Project State) is quoted from PR1 and means **PR1's L2**; for BC phases its applicability follows Test Strategy §7.1 impact selection and roadmap §5.4 T5. Stricter, not weaker. Input for BC1.
- **R2-N2 / V4-N2:** Migration Matrix step 3 lists RoadLogic among the systems retired gradually while its row and Master say ADAPT, and cites Master R13 for RoadGraph/ForkDecisionModel loosely; this roadmap-§4 vs Master tension predates F3 and adds no condition. Decide in the first retirement task or by the Director.
- **R2-N5:** Test Strategy §8.3 calls N4 a «mandatory route class»; N4 is a PR1 acceptance criterion covering mandatory classes. No change required.
- **R2-N6:** REVIEW #1 R-N10 — the suspension rule does not require checking the suspension record itself; a possible later PLANS refinement for the Director. Not a loophole.
- **V4-N4:** author check `3b` used a prefix test; the closeout check uses exact equality.

## 4. Roadmap v2 errata (reported to the Director; roadmap text unchanged)

The accepted roadmap is the approved v2 text. The following statements in it are inaccurate; the authority documents carry the corrected facts. A Director-approved roadmap revision may fix the text.

| # | Roadmap place | Inaccurate statement | Fact / where corrected |
|---|---|---|---|
| E1 | §1.2 table, row «Принято (Alpha)» | Lists R7 FinalSurface among accepted Alpha phases | R7 is technical LIMITED ALPHA complete, Director acceptance pending ([R7 record](../completed/R7.md); ARCHITECTURE.md status; Current Project State) |
| E2 | §5.4 «Факт — область поиска» | PR1 network rules «используются только инструментом `region_ride_bot.gd`» | They are executed, not asserted, also by `test_region_ride.gd` and `capture_region_world.gd` (via `region_world.tscn` → `region_bake.gd`); no test asserts them ([Test Strategy §8.4](../../TEST_STRATEGY.md)) |
| E3 | §5.4 T3 «Затронутые проверки» | «Тестов в репозитории нет» | No test asserts the rules; the planned `test_region_network` was never created (PR1 record §4, §7) |
| E4 | §5.3 obligations table | Lacks the protection gap of the never-created PR1 suites and the open S3 conflict | Recorded in the PR1 record §5, §7, Test Strategy §8.4, Current Project State |
| E5 | §7.5 K1, §9 RM-8/RM-9, §10 | Pre-approval wording («утверждается с ExecPlan BC0», «хранится рядом…») | Historical as of v2; BC0 v1.0 was approved and executed (this record) |

## 5. Obligation owners proposed by BC0 (reported to the Director)

Roadmap v2 §5.3 (approved) names owners for M0–M5 formal acceptance, N4, M6, E7 and the known problems. The following owners in the [PR1 record](../suspended/PR1.md) §7 were **proposed by BC0** and are reported to the Director for confirmation; until changed they are the working assignment:

- regression guard of the realized network (PR1 D10 T1/T2.4 suites and the `handoff` transfer) → BC1, before its L2;
- S3 oracle conflict → Director decision; analysis in BC2 or DEBT with an owner;
- PR1 L2 items never run → BC1 L2; the **G gates for the PR1 main-scene closure change** run in BC1 L2 regardless of BC1's own scope, and are a precondition for merging PR1 code into master (the BC1 plan must state that this reference audit covers PR1's `mode_select` change, not only BC1's diff);
- P1–P4, full-bake determinism 1 vs N, «different seeds differ», GPU performance gates → BC1 L2 for the touched scope, then L3;
- Director execution condition 2 (descent-preferred direction with a proven rideable reverse path) → BC2;
- D10 T2.5 → re-checked by the first L2 that touches the deformer (BC1).

## 6. Known failures and limitations (unchanged)

`route_branch_integration` known failure; S3 (10 × curvature) undecided; C10/C12 OPEN; whole-game runtime acceptance INCOMPLETE; R6 LIMITED and R7 technical LIMITED scopes; PR1 evidence is L0/L1 only. This record certifies documentation scope only and approves no phase.

## 7. Time ledger (±0.25 h)

Agent/process hours of VERIFY/REVIEW are the measured wall durations of their agent runs (V1 13.9 min, V2 10.7, V3 8.7, V4 7.9; R1 9.1, R2 5.2); the reports' own estimates are higher for V1/V2. Other rows are author-session estimates; elapsed equals agent hours (no overlapping work).

| Row | Elapsed h | Agent/process h |
|---|---|---|
| Planning (roadmap v1/v2, ExecPlan) — shown separately | 1.5 | 1.5 |
| Implementation (M0–M2, F1, F2, F3) | 1.25 | 1.25 |
| L0 (author checks during milestones) | 0.25 | 0.25 |
| L1 | N/A (docs task, no milestone engine checks) | N/A |
| L2 (author campaign: checks 1–6, negatives, reruns) | 0.25 | 0.25 |
| VERIFY (#1–#4) | 0.75 | 0.75 |
| REVIEW (#1–#2) | 0.25 | 0.25 |
| Closeout — shown separately | 0.25 | 0.25 |

Verification overhead = (L0 + L1 + L2 + VERIFY + REVIEW) / (Implementation + those) = 1.5 / 2.75 ≈ 55 % (target ≤ 20 % rolling). Cause: two fix cycles (VERIFY #1 FAIL, REVIEW #1 REJECT) on self-introduced scope deviations in a docs task. Budgets per class (L2 ≤ 0.5 h, VERIFY ≤ 1 h, REVIEW ≤ 1 h) were met.

## 8. Next step

BC1 — the first rideable NATURAL trail on 184729 and playtest 1 — needs its own ExecPlan and approval. BC1 inputs from BC0: §3 R2-N1, §5 owners (protection gap, G gates for the PR1 menu change), roadmap §5.4 T1/T5, Test Strategy §8. BC1 is not started.

---

<!-- APPROVED BC0 EXECPLAN v1.0 BELOW: byte-identical to 53a69f2:docs/proposals/BC0_EXECPLAN.md -->
TASK: BC0 — Architecture & Documentation Migration to B+C route realization (roadmap Phase 0)
DATE: 2026-10-12
STATUS: PLAN_ONLY — ExecPlan v1.0, waiting for explicit Game Director approval of this version
BRANCH/BASE/HEAD: bc0-architecture-migration / pr1-playable-region `beacc9c` (= origin/pr1-playable-region) / first branch commit holds only `docs/proposals/` (SHA reported in chat)
BASELINE: clean at `beacc9c`; local tag `pr1-suspended-baseline` → `beacc9c` (unpublished); PR1 branch untouched
PRIOR DECISIONS: Game Director in chat 2026-10-12 — B+C direction approved with amendments A–E; RM-8 = variant B (suspend PR1); permission to prepare and execute Phase 0 under repository rules
LOCATION: stored next to the roadmap because the root slot still holds PR1 (IMPLEMENTING) and PLANS.md has no suspension lifecycle (roadmap K1). M0 installs this approved plan in `implementation_plan.md`.
INPUT: [ROADMAP_B_C_ROUTE_REALIZATION.md](ROADMAP_B_C_ROUTE_REALIZATION.md) v2

---

## Goal

Make the authority documents consistent with the approved B+C roadmap. Formally suspend PR1 with a reproducible baseline. Leave the repository ready for a BC1 ExecPlan. Documentation and governance only.

## Observed current state

- PR1 is the active plan (IMPLEMENTING, M0–M5 done, N4 unmet, M6/E7 not run). Its code is the playable baseline (roadmap §5.1). PLANS.md knows PLAN_ONLY…COMPLETE and keeps FAIL/INCOMPLETE/REJECT tasks active; there is no human-decided stop state.
- Master R5–R13 and Target Architecture §1 describe one road pipeline (`RouteCorridor → RoadSynthesizer → RoadPathData → FinalSurface`) for every class. Current Project State ends at R7; ARCHITECTURE.md status says the region work is isolated and legacy runtime unchanged. That is stale since PR1 put the region scene in the menu.
- Test Strategy has no PLAYABLE checkpoint or defect criticality. TEST_MATRIX (Q0, 204 rows) has no rows for R5–R7/PR1 suites. No repository test references the PR1 network rules (roadmap §5.4).
- Unknown until M0 reads it: exact PR1 N1–N7 text, milestone list and recorded failures. Reading the full PR1 plan is allowed only during this approved execution.

## Target behaviour

The authority documents state the same thing:

- one route network;
- ENGINEERED / NATURAL / SHAPED as ways to build segments, separate from route class;
- FinalSurface as single owner of the final physical surface (principles S1–S7, no storage choice);
- R5/R6 kept pragmatically for roads;
- meaningful dead ends, no traps;
- acceptance of complete connections;
- PLAYABLE vs FORMALLY ACCEPTED;
- PR1 SUSPENDED, not COMPLETE.

R9–R21 goals and the Blueprint are unchanged.

**Exclusions:** no production code, tests, scenes, resources, project settings, tools, skills, scoped AGENTS or TEST_MATRIX change. No test is mutated, skipped or reclassified. No push, merge or tag publication.

## KEEP / ADAPT / REPLACE / RETIRE

- Documentation only. Blueprint: KEEP.
- Master: ADAPT by an appended amendment plus pointer lines.
- Target Architecture and Migration Matrix: ADAPT (new sections; superseded statements marked, not deleted).
- PR1 plan: preserved verbatim in the suspension record.
- System dispositions are those of roadmap §4, recorded in the matrix.

## Ownership, contracts, dependencies

- Product authority: Blueprint. Strategy: Master plus its B+C amendment. Accepted architecture decision: the roadmap, moved to `docs/`.
- Lifecycle authority: PLANS.md.
- Contract statements added (documentation, no code): R6 class limits apply to ENGINEERED pieces realized by R6 (T1); NATURAL/SHAPED contracts are defined by BC1. Dependency direction pure domain → bake → runtime is unchanged.

## Allowed files

| Path | Action | Responsibility |
|---|---|---|
| `.agent/PLANS.md` | modify | Amendment §A (SUSPENDED lifecycle, playtest checkpoints field) |
| `AGENTS.md` | modify | One clause, §A3 |
| `implementation_plan.md` | modify | M0: PR1 → this plan; M4: NO_ACTIVE_PLAN + link |
| `docs/plans/suspended/README.md` | create | Index of suspended tasks (one row) |
| `docs/plans/suspended/PR1.md` | create | Suspension record + verbatim PR1 plan |
| `docs/plans/completed/BC0.md` | create | Closeout record |
| `docs/ROADMAP_B_C_ROUTE_REALIZATION.md` | create (git mv from `docs/proposals/`) | STATUS ACCEPTED; links re-based; content otherwise v2 |
| `docs/proposals/BC0_EXECPLAN.md` | delete (git mv into slot) | — |
| `docs/MASTER_IMPLEMENTATION_PLAN.md` | modify | Appended section «XII-B. Amendment B+C (2026-10-12)»; one pointer line under R6, R7, R8, R13 headings; R7 sentence on `FinalSurface.sample(x,z)` qualified by S1–S7 |
| `docs/TARGET_ARCHITECTURE.md` | modify | §1 diagram adds route realization; new section: realization modes, responsibilities, FinalSurface principles, route semantics, anti-R6 guard |
| `docs/LEGACY_MIGRATION_MATRIX.md` | modify | Rows for regional/PR1 systems (roadmap §4); baseline preservation; retirement order |
| `docs/CURRENT_PROJECT_STATE.md` | modify | PR1 section (SUSPENDED: works / unfinished / baseline), B+C direction, next phase BC1 |
| `docs/TEST_STRATEGY.md` | modify | New §8: PLAYABLE / FORMALLY ACCEPTED, playtest before acceptance, defect criticality, escalation rule, applicability of old contracts (T1–T9 by reference), L3 mapping |
| `ARCHITECTURE.md` | modify | Status line + short as-is PR1 region runtime paragraph |
| `docs/README.md` | modify | Navigation rows: roadmap, suspended plans |
| `docs/DECISIONS/README.md` | modify | Row for the accepted roadmap decision |
| `docs/PLAYTEST_MOUNTAIN_RIVER_VALLEY.md` | modify | Status line: baseline of suspended PR1, tag, reproduction pointer |

## Forbidden files

`scripts/**`, `scenes/**`, `resources/**`, `assets/**`, `project.godot`, `tools/**`, `.agents/skills/**`, `scripts/*/AGENTS.md`, `.antigravity/rules/test-integrity.md`, `docs/TARGET_GAME_BLUEPRINT.md`, `docs/TEST_MATRIX.md`, `TEST_PLAN.md` (already SUPERSEDED), existing `docs/plans/completed/*`, `docs/baselines/**`, `docs/investigations/**`, the evidence root (read-only), branch `pr1-playable-region`, published history.

## §A Exact governance amendment

**A1. PLANS.md, Header line.** Replace the status list with `(PLAN_ONLY / APPROVED / IMPLEMENTING / VERIFYING / REVIEWING / COMPLETE / SUSPENDED)`.

**A2. PLANS.md, Required task fields.** Add the row:

`| Playtest checkpoints | Where applicable: PLAYABLE / REVIEWABLE points inside the task (Test Strategy §8) — what a human rides, entry criteria, critical-defect list; never acceptance and never a substitute for L2/VERIFY/REVIEW/E7 |`

**A3. PLANS.md, new section after «Completion lifecycle»:**

```markdown
## Suspension lifecycle

- SUSPENDED stops an unfinished task by explicit human decision (for example, its method is superseded). It is never COMPLETE or PASS, closes no obligation, and needs no VERIFY/REVIEW of the unfinished scope.
- Before the root slot changes, create `docs/plans/suspended/<TASK-ID>.md`: decision source/date and reason; status of every milestone (done / not done / not run); the plan and execution record verbatim, with the SHA-256 of the root file it was copied from; retained evidence with its limitations; known failures; a reproducible baseline (revision or tag, engine, seed/configuration, launch command, cache/evidence location); every open obligation with its new owner task/phase or its explicit cancellation by the decision.
- Then replace the root `implementation_plan.md` with NO_ACTIVE_PLAN or the next approved plan, linking the record. Keep the task branch and published history; no force-push or rewrite.
- Resuming needs a new approved plan or amendment. Obligations move only as the decision names them.
```

**A4. AGENTS.md, Workflow bullet «Update owned current documentation…».** After «…then clear the root slot to NO_ACTIVE_PLAN.» insert: «An unfinished task stops only by explicit human decision as SUSPENDED under [.agent/PLANS.md](.agent/PLANS.md), never as COMPLETE.»

## Migration path

| Milestone | Content | Stop point |
|---|---|---|
| M0 Transition | Apply A1–A4. Read the PR1 plan fully. Create `suspended/PR1.md` (decision; milestone table; N1–N7 verbatim; recorded results with limitations; known failures; baseline kit roadmap §5.1; obligations table roadmap §5.3) + verbatim copy; check byte identity of the embedded copy against the recorded SHA-256. Install this plan in the slot with the approval line. Commit. | If PR1 content contradicts roadmap §5.3 (for example, an obligation not listed), add it to the record and report it; do not drop it |
| M1 Architecture docs | Move the roadmap to `docs/` (ACCEPTED). Master amendment; Target Architecture; Migration Matrix. Commit. | — |
| M2 State, strategy, navigation | Test Strategy §8; Current Project State; ARCHITECTURE.md status; README; DECISIONS; playtest note. Commit. | — |
| M3 Verification | L0/L2 checks below → slow-cycle-verify (fresh context) → slow-cycle-review (fresh independent context) | Any FAIL/REJECT returns to the implementation owner inside this scope |
| M4 Closeout | `completed/BC0.md` with reports summary and ledger; slot → NO_ACTIVE_PLAN; commit | Stop. BC1 is not started |

## Risks

- **Lost protection** through rewording. Every superseded statement is marked with its new owner, not deleted. The T1–T9 map is carried unchanged.
- **Authority drift** (roadmap overriding Blueprint/Master). The roadmap stays subordinate; the Master amendment carries the strategy change explicitly.
- **Scope creep** into a documentation reset. Whitelist only; pointer lines rather than rewrites.
- **PR1 obligations silently dropped.** M0 stop point; verify checks the obligations table against the verbatim plan.

## Verification plan

**Class.** Markdown-only plus governance edit (Test Strategy §7.1 row 1, §7.4 «Docs-only closeout» — governance edits need verification of their impact set). Budget: L2 ≤ 0.5 h, VERIFY ≤ 1 h, REVIEW ≤ 1 h. No engine.

**L0/L2 checks (author, recorded output):**

1. `git diff --name-status beacc9c..HEAD` equals the whitelist.
2. Byte identity (`git diff --quiet beacc9c..HEAD -- <path>`) of all forbidden paths, explicitly `scripts scenes resources project.godot tools .agents .antigravity docs/TARGET_GAME_BLUEPRINT.md docs/TEST_MATRIX.md docs/plans/completed`, except the new `BC0.md`.
3. SHA-256 of the root PR1 plan at `beacc9c` equals the hash recorded in `suspended/PR1.md`, and the embedded copy is byte-identical (extract and compare).
4. Relative-link check of every changed Markdown file (all targets exist; line anchors exist where given).
5. Traceability table in the closeout record: each roadmap §3–§7 decision → document/section where it now lives.
6. PR1 obligations: every milestone and N1–N7 item of the verbatim plan appears in the record with a state and an owner.

**Negative checks:**

- the link checker reports a deliberately broken link in a scratchpad copy;
- the whitelist check reports a deliberately added out-of-scope path in a scratchpad worktree.

**Not run, with reason:** E0–E7, G gates, suites. No `.gd/.tscn/.tres/.gdshader/project.godot/tools` change, so no runtime closure is reached. This waives nothing for BC1. L3 is not applicable.

**Independence.** VERIFY and REVIEW run as separate fresh agent contexts using the repo skills, with inputs: this approved plan (SHA-256), the diff `beacc9c..HEAD`, and the verification report. Reports are saved in a durable evidence root `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/`.

## Runtime / visual / physics / performance

N/A: documentation only. The roadmap's runtime requirements bind BC1+.

## Rollback boundary

Branch-local commits are revertible. `pr1-playable-region`, its remote, `master` and tag `pr1-suspended-baseline` stay untouched. The PR1 plan is recoverable from `beacc9c` and the verbatim copy.

## Legacy impact

Preserved and restated, not reclassified:

- `route_branch_integration` known failure;
- R6 regions 10 × S3;
- C10/C12 OPEN;
- whole-game runtime acceptance INCOMPLETE;
- the R6 LIMITED and R7 technical LIMITED scopes.

Next dependency: the BC1 ExecPlan.

## Documentation changes

As in Allowed files. Current Project State and README describe implemented / planned / not run / known failures separately.

## Definition of Done

- Whitelist respected; A1–A4 applied verbatim.
- PR1 SUSPENDED with record, verbatim copy, baseline and obligations.
- Documents consistent with roadmap v2; T1–T9 unchanged.
- Checks 1–6 and the negatives recorded.
- VERIFY PASS and independent REVIEW PASS.
- Completed record exists and the slot is NO_ACTIVE_PLAN.
- Local commits only.

## Approval requested

1. ExecPlan v1.0 (this file, SHA-256 reported in chat), including the exact text §A.
2. Local commits on `bc0-architecture-migration` per milestone (no push).
3. Durable evidence root as stated.

## Time ledger

To be kept in the execution record (Planning, Implementation, L0, L2, VERIFY, REVIEW, Closeout; elapsed and agent hours).

<!-- BC0 EXECUTION RECORD BELOW: verbatim from 633895f:implementation_plan.md -->
# BC0 execution record

Evidence root: `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/`.

## M0 — transition (DONE)

- §A1–A4 applied verbatim to `.agent/PLANS.md` and `AGENTS.md`.
- PR1 plan read in full (allowed by this approved execution). [Suspension record](docs/plans/suspended/PR1.md) created with milestone and DoD state, D1–D13 state, known failures, baseline and obligations; [index](docs/plans/suspended/README.md).
- Verbatim copy: embedded bytes SHA-256 `e63de9c1…38a4` = `git show beacc9c:implementation_plan.md` (checked by extraction; the CRLF working-tree checkout hashes `5978d182…048b`, same content).
- This approved plan installed in the slot; body byte-identical to `53a69f2:docs/proposals/BC0_EXECPLAN.md`, header updated (status, approval, location, input link).
- **Stop-point findings (added to the record; the roadmap §5.3/§5.4 edits made in M1 were reverted by F1, the findings stay in the PR1 record and Test Strategy §8.4):** PR1 D10 T1 suites `test_region_network` / `test_region_surface` / `test_region_runtime` were never created, and the T2.4 transfer of the `handoff` checks was not done — a protection gap for the realized network, now an open obligation owned by BC1. The S3 oracle conflict (10 × curvature) is still undecided. PR1 D10 T2.4 categories (fixture = REGRESSION_GUARD, live = LEGACY_CONTRACT) were approved with PR1 v1.1 and are recorded, not newly decided.
- **Approval condition 1 applied to M1:** the roadmap moves to `docs/` in M1 with status «APPROVED — becomes ACCEPTED at BC0 closeout»; ACCEPTED is set only in M4 after VERIFY/REVIEW PASS.
- **Approval condition 2:** the PR1 cache directory for `beacc9c` is recorded as unconfirmed (two candidate entries, key not computed).

## M1 — architecture documents (DONE)

- Roadmap moved to [docs/ROADMAP_B_C_ROUTE_REALIZATION.md](docs/ROADMAP_B_C_ROUTE_REALIZATION.md), links re-based, status «APPROVED — becomes ACCEPTED at BC0 closeout» (condition 1); v2.1 added the M0 findings to §5.3/§5.4 and updated K1 and the RM-8/RM-9 status — **reverted by F1** (VERIFY #1 B1).
- Master: appended «XII-B. Amendment B+C (2026-10-12)» before §XIV and one pointer line under R6, R7 (qualifies `FinalSurface.sample(x,z)` by S1–S7), R8, R13; no existing text removed; R9–R21 goals unchanged. L3 mapping: the R8 checkpoint was not run in PR1, the first L3 follows BC2 and covers R8 + R13.
- Target Architecture: §1 diagram with route realization by segment; owner table (RoutePlanner, RoadSynthesizer = ENGINEERED, trail realization, published network, FinalSurface, WorldStreamer); §5 composition; §7 BC row; new §8 (modes, R5/R6 scope incl. T1 contract scope, S1–S7, network semantics, anti-R6 guard).
- Migration Matrix: new section with B+C dispositions, baseline preservation and retirement order (trails at BC2 acceptance; PR1 network rules at BC2; legacy runtime — step 3 **restated by F3** after REVIEW R-B1: gradual retirement per Master's retire points, no new condition).

## M2 — state, strategy, navigation (DONE)

- Test Strategy: navigation line + new §8 (PLAYABLE / FORMALLY ACCEPTED, playtest checkpoints, defect criticality, repeated failures and escalation, contract applicability summary T1–T9 incl. the recorded PR1 D10 T2.4 categories, the open protection gap and S3, PR1 evidence limits, L3 mapping). No test, category or gate changed.
- Current Project State: dated pointer under STATUS and section «PR1 и переход на B+C» (works / unfinished / known problems / baseline with unconfirmed cache entry / direction / next phase BC1).
- ARCHITECTURE.md: status line and §6 as-is PR1 region runtime.
- Navigation: docs/README.md (roadmap, suspended tasks), DECISIONS index (roadmap APPROVED, ACCEPTED at closeout), playtest note status (PR1 baseline).
- TEST_PLAN.md and TEST_MATRIX unchanged (plan: SUPERSEDED / no new contract).

## M3 — author checks (L0/L2, Markdown-only class)

Script `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/bc0_checks.py` (reads committed git blobs only); output `bc0/l2/checks.json`, `bc0/l2/stdout.log`. Run on candidate `431ac13`: PASS. A rerun on the commit that adds this section is the VERIFY input.

| Check | Result |
|---|---|
| 1 whitelist (`git diff --name-status --no-renames beacc9c..HEAD` ⊆ Allowed files) | PASS |
| 2 forbidden paths byte-identical (scripts, scenes, resources, assets, project.godot, tools, .agents, .antigravity, Blueprint, TEST_MATRIX, TEST_PLAN, baselines, investigations, history, sprints; no other completed record); refs: `pr1-playable-region` = `origin/pr1-playable-region` = `pr1-suspended-baseline` = `beacc9c`, `master` = `origin/master` = `52a9c34` | PASS |
| 3 verbatim PR1 copy = `beacc9c:implementation_plan.md`, SHA-256 `e63de9c1…38a4` recorded | PASS |
| 3b slot body = approved body of `53a69f2:docs/proposals/BC0_EXECPLAN.md` (`abccce21…9a11`) | PASS |
| 4 relative links in 15 changed Markdown files (280 links; files, line numbers, heading anchors; verbatim PR1 copy resolved from its original root location) | PASS |
| 6 PR1 record lists M0–M6, N1–N7, P1–P4, D1–D13, E7, S3, T2.4, the missing suites, the baseline tag and the unconfirmed cache key | PASS |
| Negatives: broken link and broken anchor reported in a scratch copy; out-of-scope path reported by the whitelist check | PASS |

Not run (with reason): E0–E7, G gates, suites — Markdown-only diff, no runtime closure reached; waives nothing for BC1.

**Check 5 — traceability (roadmap decision → where it now lives):**

| Decision | Authority documents |
|---|---|
| RM-1 one network; ENGINEERED / NATURAL / SHAPED; class ≠ method | Target Architecture §1, §2, §8; Master XII-B item 1; Migration Matrix B+C section |
| RM-2 R5/R6 pragmatic for roads; T1 contract scope | Target Architecture §2 (RoadSynthesizer), §8; Master R6 pointer, XII-B item 2; Migration Matrix |
| RM-3 FinalSurface S1–S7, no storage choice | Target Architecture §2 (FinalSurface), §5, §8; Master R7 pointer, XII-B item 3 |
| RM-4 route semantics, meaningful dead ends, no traps | Target Architecture §8; Migration Matrix retirement step 2 |
| RM-5 acceptance of complete connections | Target Architecture §2 (published network), §8; Master XII-B item 4 |
| RM-6 PLAYABLE / FORMALLY ACCEPTED, criticality, escalation | Test Strategy §8.1–8.3; PLANS «Playtest checkpoints»; Master XII-B item 5 |
| RM-7 fast iteration after the first ride, by measurement | Roadmap §7.4 (executed by BC1; no authority-document change needed) |
| RM-8 PR1 SUSPENDED with baseline | PLANS «Suspension lifecycle», AGENTS, `docs/plans/suspended/`, Current Project State, ARCHITECTURE.md, playtest note, Test Strategy §8.5 |
| RM-9 test migration map T1–T9 | Roadmap §5.4; Test Strategy §8.4 |
| RM-10 phases BC0–BC6, L3 mapping | Master XII-B table and L3 line; Target Architecture §7; Test Strategy §8.6; Current Project State |
| RM-11 trail purpose from world data | Target Architecture §8; Master XII-B item 4 |

## VERIFY #1 — FAIL (independent fresh context, 2026-10-12)

Report `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/verify/VERIFY_REPORT.md`, SHA-256 `f388720b13a40a31610b3ead73e664132365f34f1a8348a77e4d2cbd98319ed9`; candidate `83e2695`, diff digest `ce0ba727…0abe2`. All mechanical checks passed (scope, forbidden identity, refs, §A verbatim, slot body, PR1 verbatim copy, numbers, links 280/280, traceability, conditions 1–2). **B1 (blocking):** the roadmap content was changed beyond «links re-based; content otherwise v2» (v2.1: §5.3 rows, T3/T5/T7, RM-8/RM-9 status) without recorded approval. Non-blocking N1–N10.

## F1 — fixes (author, within the whitelist)

- **B1 → option (b):** roadmap restored to the approved v2 text (`53a69f2`); only links are re-based (the «план PR1» link now points to its moved location `docs/plans/suspended/PR1.md`) and the STATUS line follows approval condition 1. The M0 findings stay in the PR1 record and Test Strategy §8.4. Roadmap v2 errata found by VERIFY (network-rule usage wording in §5.4, R7 listed as «Принято (Alpha)» in §1.2) are corrected in the authority documents (Test Strategy §8.4, ARCHITECTURE.md / Current Project State) and listed for a later Director-approved roadmap revision; the roadmap text itself is not changed without approval.
- N1 PR1 record: R5 2230/0 attributed to `37e584d`, closure change of `region_seed_derivation.gd` in `3842a3f` stated, R6 regions 2024/int64 not run on PR1 code.
- N2 T2.4 categories location corrected (Test Strategy §8.4).
- N3 obligations table completed (M0–M5 formal acceptance, PR1 L2 items incl. G gates for the `mode_select` change, mutants, Vulkan package, E6/ObjectDB, R6 regions 2024/int64, «different seeds differ», Director conditions 2–3, D10 T2.5); cancellation sentence made consistent with the decision.
- N4 cache: nine directories for seed 184729, two with the expected digests; key not computed.
- N5 D12 «no push» deviation recorded factually.
- N6 Test Strategy §8.4: rules executed (not asserted) by `test_region_ride.gd`, `capture_region_world.gd`, `region_ride_bot.gd`.
- N7 Target Architecture rebuilt additively from `beacc9c`: original statements kept verbatim, B+C refinements added as marked text/rows.
- N8 ARCHITECTURE.md status keeps «Director acceptance pending» for R7.
- N9 Current Project State: «одобрено направление B+C».
- N10 slot header updated; time ledger added below.

## Time ledger (±0.25 h; agent-session estimates)

| Row | Elapsed h | Agent/process h |
|---|---|---|
| Planning (roadmap v1/v2, ExecPlan) | 1.5 | 1.5 |
| Implementation M0–M2 + F1 | 1.0 | 1.0 |
| L0/L2 author checks | 0.25 | 0.25 |
| VERIFY #1 (per its report) | 0.75 | 0.75 |
| VERIFY #2 (per its report) | 0.25 | 0.25 |
| REVIEW, Closeout | pending | pending |

## VERIFY #2 — PASS (fresh context) and F2

Report `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/verify2/VERIFY_REPORT.md`, SHA-256 `b44cdb7e969257f2b349fd2e2b0b1d199f0479247bce0fe318d6870eab4f5f50`; candidate `1db5323`, diff digest `a500ed53…87b2c`. B1 resolved (roadmap = approved v2 except re-based links and the STATUS line). Non-blocking M1–M6.

F2 (author): M1 R5 closure wording (closure unchanged since `37e584d` except `region_seed_derivation.gd`, also preloaded by `test_route_network.gd`); M2 S3 owner cites roadmap T7; M3 424259/0 is the total of the fixture groups; M4 ledger rows from the reports. M5 (roadmap errata: R7 «Принято (Alpha)» in §1.2, «used only by `region_ride_bot.gd`» in §5.4) and M6 (links to the slot re-based to the completed record) are closeout items.

## VERIFY #3 — PASS (fresh context, F2 impact set)

Report `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/verify3/VERIFY_REPORT.md`, SHA-256 `d841a40828351b73e2669445ca75e7219cb2e24e992507f694668030075af301`; candidate `ce7edff`, diff digest `c13b33dd…23b`; VERIFY #2 reused by byte identity for all other files. Non-blocking P1–P3 (ledger, «analysis» wording, reverted-edit marks).

## REVIEW #1 — REJECT (independent fresh context)

Report `C:/Users/Luisa/Documents/Codex/2026-10-12/bc0/review/REVIEW_REPORT.md`, SHA-256 `61c48ed49076a7b3febd91bb55d2533e44ce135641f5ac3f0f5430efe1efc6c3`; inputs plan `abccce21…`, diff `c13b33dd…`, VERIFY #1–#3. **R-B1 (blocking):** Migration Matrix retirement step 3 introduced an unapproved migration gate (legacy retirement tied to BC5 and a feature freeze) and a category claim («REGRESSION_GUARD» for the G gates) that differs from TEST_MATRIX. Non-blocking R-N1–R-N10; R-N1, R-N2, R-N3, R-N9 are closeout items. Governance amendment, PR1 honesty, Master/Target fidelity, T1 scope and F1 found sound.

## F3 — fixes (author, within the whitelist)

- R-B1: step 3 restated — gradual retirement per the matrix rows and Master's retire points (R7, R10, R11, R13) after consumer migration, parity and a separate approved task; «no new conditions»; G gates mandatory under world AGENTS, categories per TEST_MATRIX unchanged.
- R-N4: PR1 record — BC1 L2 runs the G gates for the PR1 main-scene closure change regardless of BC1's own scope; also a precondition for merging PR1 code into master.
- R-N5: Target Architecture — published-network row names its owner (roadmap §3.1 «FinalSurface и публикация региона») and RealizedRoadNetwork as ADAPT; flow candidates → FinalSurface check → published network → bake/runtime.
- R-N6: T2.4 categories carry «mandatory at L2» (Test Strategy §8.4, PR1 record) and are also recorded in Current Project State (the place PR1 T5 named).
- R-N7: Test Strategy §8.3 — «optional» bound to roadmap §3.7 / PR1 D13; never a mandatory route class.
- R-N8: Migration Matrix step 1 — changes touching T1/T7 need specific approval.
- R-N9 partly: «analysis in BC2» wording; reverted/restated marks on the M0/M1 bullets. Ledger completion, R-N1, R-N2, R-N3 at closeout.
