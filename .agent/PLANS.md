# Slow Cycle ExecPlans

Use an ExecPlan for phase/sprint transitions, architectural/new-subsystem or multi-system changes, multi-file features, significant migration and long implementation. Start with native Codex Plan Mode where available, then save one reviewable plan in `implementation_plan.md` and STOP for explicit human approval. Mode switching alone is not approval.

A small local fix without ownership/contract/gate/phase change needs only goal, exact files, protected boundaries and targeted evidence, unless the user requests a plan. A one-file architectural change still requires this format. Keep fields concise (target ≤ 15 KB per phase plan, ≤ 3 KB per small fix); N/A needs a scope-specific reason, not a waiver of existing gates.

## Header

TASK; date; status (PLAN_ONLY / APPROVED / IMPLEMENTING / VERIFYING / REVIEWING / COMPLETE); branch/base/HEAD; staged/unstaged/untracked baseline; approval source/date and approved version or digest. Record result source/diff digests for dirty results: HEAD alone is insufficient.

## Required task fields

| Field | Content |
|---|---|
| Goal | One concrete user/engineering outcome |
| Observed current state | Read sources, measured facts, unknowns and previous evidence limitations |
| Target behaviour | Expected outcome and exclusions; future responsibilities are not implemented APIs |
| KEEP / ADAPT / REPLACE / RETIRE decisions | Disposition of affected legacy owners; EXTEND/DEFER when justified |
| System ownership | Single owner of each state/lifecycle and composition boundary |
| Public contracts | Inputs/outputs/queries, failure reasons and compatibility boundaries |
| Dependency direction | One-way flow and pure-domain → runtime adapter separation |
| Allowed files | Exact create/modify/delete whitelist with responsibility |
| Forbidden files | Stable neighbors, tests/gates/config and explicit exclusions |
| Migration path | Small milestones, adapter/parity/retirement gates and stop points |
| Risks | Coupling, determinism, scope, performance and legacy assumptions with mitigations |
| Verification plan | L0/L1 per milestone and one L2 campaign selected by impact ([Test Strategy §7](../docs/TEST_STRATEGY.md)): checks/E-levels, reuse with closure proof, holdout/visual/performance scope, commands/seeds/time limits/concurrency, expected/actual assertions, coverage, completion; L3 items named, not run |
| Negative verification | Meaningful invalid/boundary cases and exact expected reasons; justify omissions |
| Runtime/visual/physics requirements | Real scene integration, Vulkan/collision/Input/ride as applicable; N/A with reason |
| Performance evidence | Required workload/environment/before-after frame stalls, distributions, memory/lifecycle; no unsupported optimization claim |
| Rollback boundary | Reversible task edits, compatibility/data impacts, preservation of other people's work/history |
| Legacy impact | Protected behavior, pending conflicts/known failures and next dependency |
| Documentation changes | Exact owner documents and evidence updates within whitelist |
| Definition of Done | Scope compliance, required actual evidence, VERIFY PASS, independent REVIEW PASS, documentation and limitations |

## Approval and execution

- Approval is for this task/version/scope. Record new user conditions alongside the approval; preserve the original approved plan for traceability. Do not infer authorization for tests/player/gates from a broad feature approval.
- Execute agreed steps autonomously after approval. Material file/contract/gate scope expansion requires an amendment and approval before dependent changes. Keep progress/decisions/evidence and the time ledger (Test Strategy §7.6) for this task, not a mixed backlog/history.
- Use `slow-cycle-worldgen` when its domain trigger applies; `slow-cycle-verify` after implementation; `slow-cycle-review` in a fresh independent context after verification. Natural-language skill invocation is valid; a literal `$` token is not an acceptance requirement.
- Verifier/reviewer are read-only for feature/tests. Findings return to the implementation owner; fixes require fresh reports for the changed result. Missing independent reviewer means INCOMPLETE, never author self-certified PASS.

## Verification report

TASK; approved plan version; base/result revision plus dirty/source/diff digests; result PASS / FAIL / INCOMPLETE; reason; audited files; required/actual coverage and completion; commands/seeds/durations/environment; actual assertions and negative reasons; errors/warnings/leaks/timeouts; E-level evidence or justified N/A; reused evidence (`REUSED` run id + closure proof); artifacts; tests changed/reclassified with approval reference; known failures/limitations.

FAIL means a demonstrated requirement violation; INCOMPLETE means missing/uncompleted required evidence. When both occur, FAIL with missing coverage listed. PASS requires all declared checks, scope, coverage and completion satisfied with no unexpected errors/leaks. Existing runtime failures do not become repaired by documentation PASS.

## Independent review report

Reviewer/context identity; approved plan + resulting diff + verification report identities; risk-targeted, no rerun of the verification campaign; result PASS / REJECT; reason/evidence; actionable findings with source/file/line or plan item, impact and required correction. Missing inputs/independence/required evidence → REJECT. Verification FAIL/INCOMPLETE blocks final acceptance even if review has no other findings; green tests do not prevent REJECT.

## Completion lifecycle

- Only after VERIFY PASS + independent REVIEW PASS: archive the approved plan, approval/progress, final scope, evidence/reports/limitations in `docs/plans/completed/<TASK-ID>.md` (full reports may stay in a durable evidence root cited by SHA-256, Test Strategy §7.4); replace root `implementation_plan.md` with NO_ACTIVE_PLAN and a link to the completed record.
- Check final archival/navigation changes. Closeout edits that only transcribe already-verified results into the record, plan slot and state docs (Test Strategy §7.4), with the verified code manifest unchanged, need link/scope/hash checks only; any other late change needs fresh verification/review of its impact set. Bind reports to immutable content digests; the final commit SHA may be reported externally to avoid a self-referential digest.
- At FAIL/INCOMPLETE/REJECT keep the active plan and honest status; do not create a completed record. Local commit/handoff follows user authorization and an audited exact stage scope; never start the next phase automatically.
