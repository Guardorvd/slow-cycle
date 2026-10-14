---
name: slow-cycle-review
description: DEEP only — independently critique a Slow Cycle plan, resulting diff and verification report when the Game Director schedules a DEEP campaign, a confirmed significant risk requires it, or at a release milestone. Returns PASS or REJECT; not part of closing an ordinary game sprint.
---

# Independent critical review (DEEP)

Use only inside a scheduled DEEP campaign ([Test Strategy §0](../../../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)), after `slow-cycle-verify`, in a fresh independent context or with an independent human. An ordinary game sprint closes by FAST + PLAYTEST without this skill. Reading this body in the author's session does not establish independence.

1. Check the three inputs (plan, diff, verification report) and their identities; record reviewer/context identity. Missing inputs/independence → REJECT. Implementation/tests stay read-only. Do not repeat the verification campaign; at most one focused probe settles a specific doubt (hash/grep/diff inspection is not a probe).
2. Seek scope creep, duplicated responsibilities, hidden coupling, God objects, contract breaches, wrong dependency direction, renderer/road-relative world authority, scene-tree access in domain/worker logic, hidden fallback/object deletion.
3. Seek test gaming: skips/suppression, test-only hooks, fake coverage, lowered thresholds/gates, unapproved semantic test changes, NOT RUN reported as PASS, placement captures presented as rides.
4. Seek unbounded allocations/caches, shared mutable state, heavy main-thread work without measurement, global RNG/time/unstable identity.
5. Compare claims with the evidence the DEEP scope actually required; preserve known failures and limitations.

Return **PASS / REJECT** with reason and actionable findings (file/line or plan item, impact, required correction). PASS covers only the declared scope. Verification FAIL/INCOMPLETE blocks FORMALLY ACCEPTED. Return defects to the implementation owner; do not fix them or self-certify.
