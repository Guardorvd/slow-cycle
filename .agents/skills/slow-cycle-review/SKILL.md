---
name: slow-cycle-review
description: Independently critique an approved Slow Cycle plan, resulting diff and verification report. Return PASS or REJECT even when tests are green; excludes implementation fixes and replacing verification.
---

# Independent critical review

Use an approved ExecPlan, resulting diff and verification report in a fresh independent reviewer context or with an independent human. “Use the slow-cycle-review skill” and a named skill mention both select this workflow. Reading this body in the author's implementation session does not establish independence.

1. Read applicable root/scoped instructions and `.agent/PLANS.md` report format. Check all three input identities/version/digests, specific scope approval and report freshness. Record reviewer/context identity; missing inputs/independence/required evidence → REJECT. Reports may be saved only in an authorized evidence location; implementation/tests/scope stay read-only.
2. Seek scope creep/unrelated cleanup, duplicated responsibilities, hidden coupling, God objects, public contract breaches, wrong dependency direction, renderer/road-relative world authority and scene-tree access in domain/worker logic.
3. Inspect hidden fallback/object deletion, stale legacy assumptions, unnecessary compatibility layers and claims of implemented target owners inferred from names/types.
4. Seek test gaming, skips/suppression/test-only hooks, fake coverage, omitted assertions/completion, lowered thresholds/gates, unapproved reclassification and missing meaningful negative tests. Tests cannot redefine product architecture, and target design cannot excuse current test mutation/failure.
5. Seek unbounded allocations/caches, mutable cross-system state, heavy main-thread work without profiling/justification, unsupported optimization claims and global RNG/time/unstable identity determinism risks.
6. Compare claims with runtime/physics/Vulkan/performance/human evidence actually required by the task. Preserve known failures/limitations/coverage; green legacy tests do not certify a region, and documentation PASS does not close runtime INCOMPLETE.
7. Return **PASS / REJECT** with reason/evidence and actionable findings (source/file/line or plan item, impact, required correction). PASS covers only the declared task, never approval of a new phase. Green tests can still receive REJECT; verification FAIL/INCOMPLETE blocks acceptance independently.
8. Return defects to the implementation owner. After fixes require fresh verify + independent review of the changed diff; do not quietly fix the feature, approve expanded scope or self-certify the author's work.
