# Slow Cycle — Agent Directives & Operating Protocol

This document governs all actions of AI agents (AntiGravity and subagents) working in this repository.

---

## 1. Core Immutable Rules
1. **Do not refactor working systems without an explicit, approved reason.** If physics and camera work, do not touch them while working on world generation.
2. **Prefer minimal invasive changes.** Small, robust patches over massive rewrites.
3. **No unnecessary dependencies.** Do not pull in heavy external plugins or libraries when clean GDScript math suffices.
4. **`BicycleController` is a stable API.** Other systems observe bicycle position/speed via properties and signals; they do not dictate internal kinematics.
5. **World generation must be 100% deterministic by Seed.** Any given seed must produce the exact same road profile, elevations, and foliage distribution every single run.
6. **Mathematical continuity first.** The road generator must guarantee $C^1 / C^2$ continuity. Do not rely on wheel raycasts to hide geometric tears, normal flips, or height steps.
7. **Test after every feature.** Verify in Godot engine with headless/runtime checks. Zero parse errors, zero leak warnings.
8. **No gameplay creep.** Do not introduce gears, stamina, stunts, inventory, or score mechanics unless explicitly instructed.
9. **Preserve existing controls and camera settings.**
10. **Single MultiMesh per Chunk.** Never combine infinite world foliage into a single monolithic MultiMesh. Group instancing locally per chunk to maintain Godot frustum culling.

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
