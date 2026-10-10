# Slow Cycle — repository operating protocol

STATUS: CURRENT

## Authority and focused reading

- [Blueprint](docs/TARGET_GAME_BLUEPRINT.md) owns product requirements; [Master](docs/MASTER_IMPLEMENTATION_PLAN.md) owns migration and phase order. Consult relevant [target architecture](docs/TARGET_ARCHITECTURE.md), [migration matrix](docs/LEGACY_MIGRATION_MATRIX.md), [test strategy](docs/TEST_STRATEGY.md) and [current state](docs/CURRENT_PROJECT_STATE.md). Code/history describe facts.
- Record branch/HEAD/status and staged/unstaged/untracked paths. Preserve others' edits and published history; one logical branch/commit series per task; no unrelated cleanup.
- Read each participating scope before work: [world](scripts/world/AGENTS.md), [player](scripts/player/AGENTS.md), [test](scripts/test/AGENTS.md). Root-start may not load sibling scopes. Read relevant scopes/sources. For another task, read only the active-plan header before the first `---` (max 12 lines); no whole-file reads/searches. Read its full plan only for that approved task's execution/verify/review.

## Planning and scope

- Phase/sprint transitions, new subsystems, architectural changes, multi-file features, multi-system changes, significant migrations and long implementations require one ExecPlan in [implementation_plan.md](implementation_plan.md), using [.agent/PLANS.md](.agent/PLANS.md).
- Use native Codex Plan Mode for preliminary investigation where available; it does not itself authorize implementation. Save the concrete plan and STOP for explicit human approval of that task/version/scope. A missing Plan Mode is not a reason to create a planning skill.
- A small local fix with no ownership, contract, gate or phase change needs only concise scope and targeted verification, unless the user requires a plan. A one-file architectural change still needs an ExecPlan.
- Once approved, execute the agreed scope autonomously. File/contract/protected-system/gate expansion needs a concrete approved amendment; prior approval does not authorize another task/phase.
- Prefer minimal changes and justified dependencies. Do not introduce gears, stamina, stunts, inventory, score or other gameplay mechanics without explicit instruction.

## System boundaries

- Keep one owner per state/lifecycle, public contracts and one-way dependencies: pure domain planning → Godot runtime adapter. Composition roots compose; they do not absorb subsystem logic. Renderers and player internals do not own world planning.
- Generation must reproduce the same result for the same effective seed/configuration/stable identity. Derive local RNG seeds explicitly; generation must not depend on global RNG, time, allocation IDs or materialization order. Runtime may choose and record a session seed before generation.
- BicycleController, camera and controls are stable, including configuration in scenes, resources and project settings outside `scripts/player`. Changes require a measured defect, an explicitly scoped player task and its separately approved plan. Never adjust player physics/camera to accommodate worldgen defects; preserve public APIs and physics/presentation separation.

## Integrity and evidence

- Existing tests, assertions, thresholds, coverage and mandatory gates remain protected. Test mutation/reclassification needs explicit human approval of the specific change; general feature approval is insufficient.
- Tests cannot silently redefine the approved product architecture. Preserve current regression protection while escalating a precise legacy-test/target conflict with owner, requirement and evidence; do not change tests, ignore failures or revert the target by inference.
- Read the frozen [test-integrity rule](.antigravity/rules/test-integrity.md) for test-related work/conflicts. Its anti-gaming and escalation protections remain; universal test-as-product-authority wording is limited by the accepted D0 authority distinction. No silent skips, suppression, fake PASS, test-specific production behavior or weakened assertions.
- [World instructions](scripts/world/AGENTS.md) retain the existing legacy geometry limits, Watchdog/Vulkan generation gates and local foliage culling. Simplifying root instructions does not relax them.
- Select checks by L0–L3 and impact ([Test Strategy §7](docs/TEST_STRATEGY.md)); reuse needs closure proof. Report actual coverage, assertions, completion, seeds, source/diff identity, errors/leaks and artifacts. Exit 0, budgets or stale reports never suffice; missing evidence blocks completion. E7 requires a human ride.

## Workflow and documentation

- Worldgen design/implementation uses `slow-cycle-worldgen`; result verification uses `slow-cycle-verify`; independent criticism uses `slow-cycle-review`. Load the relevant body when that workflow starts, only as needed.
- Invoke required verify/review explicitly by name or natural language (for example, “Use the slow-cycle-verify skill”). `$skill-name` is a convenience, not the sole activation or acceptance mechanism. Implicit matching alone does not prove a gate ran.
- Verification is read-only for implementation/tests and returns PASS / FAIL / INCOMPLETE with reason/evidence. Review reads approved plan + diff + verification report in a fresh independent context, reruns no campaign and returns PASS / REJECT. Green tests do not guarantee review PASS; author self-review is not independent.
- Fixes return to the implementation owner inside approved scope, followed by fresh verification/review of the changed impact set. Completion requires both VERIFY PASS and independent REVIEW PASS.
- Update owned current documentation and the task record within the whitelist; distinguish implemented, planned, not-run and known failures. Keep one active plan; archive successful tasks in `docs/plans/completed/<TASK-ID>.md`, then clear the root slot to NO_ACTIVE_PLAN. Never start the next phase automatically.
- Scoped instructions, skills and an ExecPlan specialize these rules; they may not silently weaken approval, stable-system or integrity boundaries. Record unresolved conflicts and stop the affected work for a human decision.
