# Slow Cycle — Agent Directives & Operating Protocol

STATUS: CURRENT

## Documentation authority after D0

Product source of truth: [TARGET_GAME_BLUEPRINT](docs/TARGET_GAME_BLUEPRINT.md). Migration strategy and phase order: [MASTER_IMPLEMENTATION_PLAN](docs/MASTER_IMPLEMENTATION_PLAN.md). [Documentation index](docs/README.md), [target architecture](docs/TARGET_ARCHITECTURE.md), [migration matrix](docs/LEGACY_MIGRATION_MATRIX.md), [test strategy](docs/TEST_STRATEGY.md), [current state](docs/CURRENT_PROJECT_STATE.md).

Explicit current user instructions and approval define task scope. Implemented code and historical roadmaps/tests inform safe migration; they do not override the approved region-first target. A legacy DAG requirement does not forbid a future loop/merge-capable RegionRouteGraph. Existing assertions are nevertheless unchanged: any test mutation/reclassification needs its own explicit human approval; D0 assigns no new suite categories and removes no mandatory gates.

Rules 1–12 and the task template below are retained unchanged. Rule 6's numerical geometry/fallback requirements protect the current legacy road subsystem; known 18/19m/fallback mismatches remain open. Rule 10's per-chunk grouping describes current foliage locality/culling, not a mandatory target partition: the approved target uses spatial cells and type-local MultiMeshes. Neither rule grants permission to alter runtime, limits or tests during D0.

D0 scope is documentation only: no production/test GDScript, scenes/resources, physics/camera, generation algorithms or runtime changes. Feature/generation engine gates remain mandatory in their scope; a docs-only diff is checked for links/authority/preservation/scope, not represented as E0–E7 runtime PASS. D0 is complete; [completed plan](docs/plans/completed/D0.md). [Root plan slot](implementation_plan.md) has no active plan. D1/scoped AGENTS/skills and Q/R phases require the next separately approved plan.

The frozen [.antigravity test-integrity rule](.antigravity/rules/test-integrity.md) continues to protect tests; its universal test-as-product-authority wording is recorded as [D0-C10](docs/DOCUMENTATION_AUDIT.md) for D1/Q0. It cannot restore the superseded product architecture. This precedence clarifies documentation authority without changing test semantics.

---

This document governs all actions of AI agents (AntiGravity and subagents) working in this repository.

---

## 1. Core Immutable Rules
1. **Do not refactor working systems without an explicit, approved reason.** If physics and camera work, do not touch them while working on world generation.
2. **Prefer minimal invasive changes.** Small, robust patches over massive rewrites.
3. **No unnecessary dependencies.** Do not pull in heavy external plugins or libraries when clean GDScript math suffices.
4. **`BicycleController` is a stable API & Presentation Decoupling.** Other systems observe bicycle position/speed via properties and signals (`telemetry_updated(speed_kmh, cadence_pct, is_coasting)`, `bell_rung`); they do not dictate internal kinematics. The physical root (`CharacterBody3D`) strictly preserves world upright orientation (`Basis.Y = (0, 1, 0)`), while visual lean, dive, and pitch are decoupled inside `VisualsRoot`. Internal banking, steering damping, and resistance curves may be refined within approved tasks while strictly preserving public signals, properties, and pitch raycasting.
5. **World generation must be 100% deterministic by Seed.** Any given seed must produce the exact same road profile, elevations, and foliage distribution every single run.
6. **Mathematical continuity first & Soft-Repair.** The road generator must guarantee $C^1$ continuity as an invariant ($C^2$ is desirable where applicable). Do not rely on wheel raycasts to hide geometric tears, normal flips, or height steps. **Strict ban on Straight Fallback**: replacing challenging curves with straight lines (`_generate_conservative_safe_chunk`) is prohibited. If a candidate curve exceeds kinematic or curvature limits, it must be smoothly clamped via Soft-Repair clothoid adjustment to physical boundaries ($R \ge 19.0$m) preserving curve intent. Fatal fallback is permitted solely on seam tears ($\Delta p > 1$mm) or NaN/Inf, with mandatory logging to `[GEOM]`.
7. **Test after every feature & Watchdog Gate.** Verify in Godot engine with headless and runtime checks. Zero parse errors, zero leak warnings. Tasks cannot be accepted solely on abstract math unit tests: all generation changes must pass the Watchdog Suite (`test_seed_diversity_matrix`, `test_monotony_profiler`, `test_virtual_rider_bot` on real physics) and GPU Vulkan visual audit (`capture_visual_audit.gd`).
8. **No gameplay creep.** Do not introduce gears, stamina, stunts, inventory, or score mechanics unless explicitly instructed.
9. **Preserve existing controls and camera settings.**
10. **Single MultiMesh per Chunk.** Never combine infinite world foliage into a single monolithic MultiMesh. Group instancing locally per chunk to maintain Godot frustum culling.
11. **Strict Plan Approval Gate.** For any sprint transition, multi-file feature, or architectural refactoring, the agent must create an `implementation_plan.md` artifact and STOP immediately to wait for explicit user approval ('Proceed' or chat confirmation). The agent must NEVER start executing code changes or modifying files until this approval is received.
12. **Autonomous Execution Once Approved.** Once the implementation plan is approved by the user, the agent executes all internal steps, tool calls, tests, and documentation updates autonomously without pausing for trivial confirmations on each individual tool action.

---

## 2. Standard Task Specification Template
All future backlog tasks must follow this format:

```markdown
### TASK: [TASK-ID] Title

**Goal**: What value or capability this task adds to the game.
**Do**: What systems and files are permitted to be created or modified.
**Do not**: What systems must remain untouched.
**Acceptance Criteria**: Concrete checklist proving the feature is functional.
**Tests**: Specific empirical tests required (seeds, run duration, command checks).
**Files**: Targeted paths.
```
