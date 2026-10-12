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
