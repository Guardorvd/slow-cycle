---
name: slow-cycle-verify
description: DEEP only — independently verify a Slow Cycle result against its plan when the Game Director schedules a DEEP campaign, a confirmed significant risk requires it, or at a release milestone. Not part of closing an ordinary game sprint. Read-only for implementation/tests.
---

# Verify the result (DEEP)

Use only inside a scheduled DEEP campaign ([Test Strategy §0](../../../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)): Director decision, a named confirmed risk, or a release milestone. An ordinary game sprint closes by FAST + PLAYTEST without this skill. “Use the slow-cycle-verify skill” or a named mention selects it. Do not develop/fix the feature, reclassify suites or write a new harness. Reports go only to an authorized evidence location.

1. Read root/scoped instructions and the DEEP section of the plan (named risk, checks, seeds, limits). Obtain base/result revision, diff and raw artifacts. Missing identity → INCOMPLETE. Fix the required checks from the plan and [Test Strategy §7](../../../docs/TEST_STRATEGY.md) impact selection before running them.
2. Audit scope: protected player/camera/tests/config, owners/contracts/dependencies, other people's edits. Unapproved path/behavior/gate change → FAIL.
3. Audit stored evidence (identity, full logs, counts, completion) and re-execute E0 plus the suites owning the main changed contracts and any doubtful result, on real production paths. Accept reuse only with a closure proof (§7.2); a reused FAIL stays FAIL. Record commands, seeds, environment, expected/actual assertions and completion. Exit 0 alone is insufficient.
4. Negative fixtures must run through real logic with the exact expected reason; a crash/timeout is not negative PASS. Do not patch fixtures, hooks or expected values.
5. Check determinism (repeated seeds, stable hashes) when the plan requires it. Distinguish pure math, integration, runtime, Input-driven physics and placement/teleport proxies; a placement capture is never ride coverage.
6. Inspect logs for unexpected errors/warnings/leaks/timeouts; known failures stay recorded and do not waive a required zero-error gate. E7 only from a human.

Result **PASS / FAIL / INCOMPLETE** with reason and evidence (format: [.agent/PLANS.md](../../../.agent/PLANS.md) DEEP reports). FAIL = demonstrated violation; INCOMPLETE = missing required evidence. Return defects to the implementation owner; a stale PASS does not cover a different diff. Never infer whole-game readiness from a limited PASS.
