# Slow Cycle — Claude Code

The repository protocol is [AGENTS.md](AGENTS.md); it applies in full:

@AGENTS.md

Work order (Fast Cycle, Game Director 2026-10-14; details in [Test Strategy §0](docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)):

1. Read the scoped `AGENTS.md` of every directory you touch (`scripts/world`, `scripts/player`, `scripts/test`) and the header of `implementation_plan.md`.
2. Small game feature → sprint card ([.agent/PLANS.md](.agent/PLANS.md)); new phase/subsystem/architecture → compact ExecPlan, then stop for approval.
3. After each change: **FAST** — parse changed scripts + a few directly related fast tests (≈ 10–15 s). No batteries, G gates, mutants, soak or long rides unless DEEP is scheduled.
4. **PLAYTEST** — cached region, 3–5 placement screenshots from different points, clean log, launch command for the Director. A placement screenshot is not a ride check.
5. Fix critical defects; log the rest and every DEEP check not run in [docs/BACKLOG_ACTIVE.md](docs/BACKLOG_ACTIVE.md). NOT RUN is never PASS.
6. **DEEP** (L2/L3, G gates, VERIFY, REVIEW, long rides) only on a Director decision, a named confirmed risk or a release milestone.

Godot: windowed runs are needed for Vulkan captures; headless for parse/domain tests. Shell: PowerShell or Git Bash on Windows.
