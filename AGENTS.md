# Slow Cycle — repository operating protocol

STATUS: CURRENT (Fast Cycle, D3 — Game Director 2026-10-14)

## Authority and focused reading

- [Blueprint](docs/TARGET_GAME_BLUEPRINT.md) owns product requirements; [Master](docs/MASTER_IMPLEMENTATION_PLAN.md) owns migration and phase order. Consult relevant [target architecture](docs/TARGET_ARCHITECTURE.md), [migration matrix](docs/LEGACY_MIGRATION_MATRIX.md), [test strategy](docs/TEST_STRATEGY.md) and [current state](docs/CURRENT_PROJECT_STATE.md). Code/history describe facts.
- Record branch/HEAD/status and staged/unstaged/untracked paths. Preserve others' edits and published history; one logical branch/commit series per task; no unrelated cleanup.
- Read each participating scope before work: [world](scripts/world/AGENTS.md), [player](scripts/player/AGENTS.md), [test](scripts/test/AGENTS.md). Root-start may not load sibling scopes. Read relevant scopes/sources. For another task, read only the active-plan header before the first `---` (max 12 lines); no whole-file reads/searches. Read its full plan only for that approved task's execution.

## Verification order: FAST → PLAYTEST → DEEP

Full rules: [Test Strategy §0](docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3).

- **FAST (default).** After developing or changing a game feature: parse the changed scripts plus a few directly related fast tests, target ≈ 10–15 s of automated checks. Do not launch large batteries, G gates, mutants, holdout, soak or long Input rides automatically.
- **PLAYTEST (main evaluation of a game feature).** Ready region (cache), 3–5 informative Vulkan screenshots from different points with the camera placed there, a log free of critical errors, then a launch command so the Director can ride. Never drive a bot for kilometres just to get screenshots; never present a placement capture as a physical ride check.
- **DEEP (only when needed).** Long rides, wide seed checks, G gates, mutants, L2/L3, VERIFY and independent REVIEW run only by a separate Director decision, on a confirmed significant risk named before the run, or at a release milestone. They are not an automatic condition for closing a game sprint or starting the next one.
- **A game sprint ends** when FAST passed (failures named), critical defects (crash/hang, falling through the world, trap without recovery, corrupt/inconsistent data, launch failure, baseline regression) are fixed, the playtest package was delivered and the Director rode and accepted it. Non-critical defects and DEEP checks not run go to the [short backlog](docs/BACKLOG_ACTIVE.md). Status: COMPLETE (playtest-accepted), not FORMALLY ACCEPTED.

## Planning and scope

- **Small game feature or sprint:** a sprint card (goal, files, FAST checks, playtest points, known issues; [.agent/PLANS.md](.agent/PLANS.md)). A Director request naming the feature and scope approves it; inside an approved phase plan, sprints run without new approval. No long ExecPlan per sprint.
- **ExecPlan** in [implementation_plan.md](implementation_plan.md) (compact, [.agent/PLANS.md](.agent/PLANS.md)) for a new phase, a new subsystem, an architectural or multi-system change or a significant migration. Save it and STOP for explicit human approval of that task/version/scope. Plan Mode alone does not authorize implementation.
- Once approved, execute autonomously. File/contract/protected-system expansion needs an approved amendment; prior approval does not authorize another task/phase.
- Prefer minimal changes and justified dependencies. Do not introduce gears, stamina, stunts, inventory, score or other gameplay mechanics without explicit instruction.

## System boundaries

- Keep one owner per state/lifecycle, public contracts and one-way dependencies: pure domain planning → Godot runtime adapter. Composition roots compose; they do not absorb subsystem logic. Renderers and player internals do not own world planning.
- Generation must reproduce the same result for the same effective seed/configuration/stable identity. Derive local RNG seeds explicitly; generation must not depend on global RNG, time, allocation IDs or materialization order. Runtime may choose and record a session seed before generation.
- BicycleController, camera and controls are stable, including configuration in scenes, resources and project settings outside `scripts/player`. Changes require a measured defect, an explicitly scoped player task and its separately approved plan. Never adjust player physics/camera to accommodate worldgen defects; preserve public APIs and physics/presentation separation.

## Integrity and evidence

- Never fake, weaken or hide: no lowered assertions/thresholds/coverage, silent skips, suppression, test-specific production behavior, fake PASS, or NOT RUN reported as PASS. Known failures stay visible. Read [test-integrity](.antigravity/rules/test-integrity.md) for test-related work.
- Agents may fix an obvious test-setup error with a proven cause (wrong path/argument, scene init order, fixture flag, launch timeout) when assertions, thresholds, coverage and checked behavior stay unchanged; record cause and diff. Changing a semantic test contract or reclassifying a test needs explicit human approval of that change.
- Tests cannot silently redefine the approved product architecture. Escalate a precise legacy-test/target conflict with owner, requirement and evidence; do not change tests, ignore failures or revert the target by inference.
- [World instructions](scripts/world/AGENTS.md) retain the legacy geometry limits and local foliage culling; their G gates are DEEP checks.
- Report what actually ran: commands, seeds, results, errors, artifacts; what did not run is NOT RUN. Exit 0 alone is not a PASS. E7 requires a human ride.

## Workflow and documentation

- Worldgen design/implementation uses `slow-cycle-worldgen`. `slow-cycle-verify` and `slow-cycle-review` belong to DEEP only: invoke them when a DEEP campaign is scheduled, explicitly by name or natural language.
- In DEEP, verification is read-only and returns PASS / FAIL / INCOMPLETE; review runs in a fresh independent context and returns PASS / REJECT; FORMALLY ACCEPTED needs both. Author self-review is not independent.
- Keep docs short: update the owned current docs, the sprint note and the backlog; distinguish implemented, planned, not run and known failures. Keep one active plan; archive a finished phase in `docs/plans/completed/<TASK-ID>.md` (short record), then set the root slot to NO_ACTIVE_PLAN. An unfinished task stops only by explicit human decision as SUSPENDED under [.agent/PLANS.md](.agent/PLANS.md). Never start the next phase automatically.
- Do not rewrite historical reports or results. Scoped instructions, skills and plans specialize these rules; they may not silently weaken approval, stable-system or integrity boundaries. Record unresolved conflicts and stop the affected work for a human decision.
