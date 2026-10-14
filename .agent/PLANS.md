# Slow Cycle — plans, sprint cards and records

Fast Cycle (D3, Game Director 2026-10-14): verification order FAST → PLAYTEST → DEEP, [Test Strategy §0](../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3).

## Which document

| Work | Document | Approval |
|---|---|---|
| Small game feature, tuning, sprint inside an approved phase | **Sprint card** (below), in the phase plan's progress section or in chat | Director request naming the feature/scope, or the approved phase plan |
| Small local fix (no ownership/contract/phase change) | Goal, files, FAST check — a few lines | Request itself |
| New phase, new subsystem, architectural/multi-system change, significant migration | **Compact ExecPlan** in `implementation_plan.md` (target ≤ 8 KB) | Save it and STOP for explicit approval of that task/version/scope |
| DEEP campaign (Director decision, confirmed risk, release milestone) | DEEP section of the plan: named risk, checks, seeds, time limit | Director |

## Sprint card (≈ 10 lines)

Goal (what the rider will notice) · files to touch · FAST checks (parse + 1–3 related fast tests, ≈ 10–15 s) · playtest: seed/region, launch command, 3–5 capture points · known issues/risks · protected systems touched (normally none; if any, stop for approval).

Sprint note at the end (≈ 5 lines): revision, FAST result, captures, critical defects fixed, backlog items added, Director verdict.

## Compact ExecPlan

Header: TASK; date; status (PLAN_ONLY / APPROVED / IMPLEMENTING / COMPLETE / SUSPENDED); branch/base/HEAD; approval source/date.

Fields (one short paragraph or table row each; omit a field that does not apply):

| Field | Content |
|---|---|
| Goal | One concrete player/engineering outcome |
| Current state | Read sources, measured facts, unknowns |
| Target behaviour | Expected outcome and exclusions |
| Ownership and contracts | Owner of each new state; public inputs/outputs; dependency direction; KEEP / ADAPT / REPLACE / RETIRE of affected legacy owners |
| Files | Allowed files; protected neighbours not to touch |
| Sprints | Ordered sprint cards with their playtest points |
| Risks | Determinism, data integrity, performance, coupling — and which, if confirmed, triggers DEEP |
| Checks | FAST set per sprint; DEEP only if a named risk or the Director requires it |
| Done | Director playtest acceptance + backlog updated; FORMALLY ACCEPTED only if a DEEP campaign is scheduled |

## Approval and execution

- Approval is for this task/version/scope. Record new Director conditions with the approval. Do not infer authorization for semantic test changes or player/physics/camera changes from a feature approval.
- After approval, execute sprints autonomously. Material file/contract/protected-system expansion needs an amendment and approval first.
- Use `slow-cycle-worldgen` when its domain trigger applies. `slow-cycle-verify` and `slow-cycle-review` run only in a scheduled DEEP campaign.

## DEEP reports (only when DEEP runs)

- Verification: TASK; plan version; base/result revision and diff identity; PASS / FAIL / INCOMPLETE with reason; commands/seeds/durations/environment; actual assertions and completion; errors/leaks/timeouts; reused evidence with closure proof (Test Strategy §7.2); artifacts; known failures. FAIL = demonstrated violation; INCOMPLETE = missing required evidence.
- Independent review: reviewer/context identity; plan + diff + verification report identities; PASS / REJECT with actionable findings. Verification FAIL/INCOMPLETE blocks FORMALLY ACCEPTED.

## Completion lifecycle

- **Sprint:** closes on the Director's playtest acceptance (Test Strategy §0); sprint note + backlog update.
- **Phase:** when its sprints are accepted, write a short `docs/plans/completed/<TASK-ID>.md` (goal, result, revisions, playtest verdicts, checks run, NOT RUN list, open backlog items, limitations; the plan verbatim or by SHA-256) and set root `implementation_plan.md` to NO_ACTIVE_PLAN. Status COMPLETE (playtest-accepted); FORMALLY ACCEPTED only after a DEEP campaign with VERIFY PASS + independent REVIEW PASS.
- Never write NOT RUN as PASS. Local commit follows user authorization and an audited stage scope; never start the next phase automatically.

## Suspension lifecycle

- SUSPENDED stops an unfinished task by explicit human decision. It is never COMPLETE or PASS and closes no obligation.
- Before the root slot changes, create `docs/plans/suspended/<TASK-ID>.md`: decision source/date and reason; status of every milestone (done / not done / not run); the plan and execution record verbatim with the SHA-256 of the root file; retained evidence and limitations; known failures; a reproducible baseline (revision, engine, seed/configuration, launch command, cache location); open obligations with their new owner or explicit cancellation.
- Then replace root `implementation_plan.md` with NO_ACTIVE_PLAN or the next approved plan, linking the record. Keep branches and published history; no force-push. Resuming needs a new approved plan or amendment.
