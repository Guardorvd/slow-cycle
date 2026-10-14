# Tests — integrity and authority

- Default verification is FAST: parse + a few directly related fast tests (≈ 10–15 s). Long groups (cold bake, Input rides, soak), batteries, G gates and mutants are DEEP ([Test Strategy §0](../../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)); do not launch them automatically.
- Exercise real production logic; mocks may isolate justified external boundaries, not replace the math/domain under test. No test-specific production hooks, hardcoded fixture responses, assertion dilution, silent skips/todo/suppression, type bypass or fabricated results.
- Existing assertions, thresholds, coverage and gates are protected; changing a semantic test contract or reclassifying a suite needs explicit human approval of that change. An obvious test-setup error with a proven cause (wrong path/argument, scene init order, fixture flag, launch timeout) may be fixed by the agent when assertions, thresholds, coverage and checked behavior stay unchanged; record cause and diff in the sprint note. New tests inside the task scope are allowed.
- A test is not automatic authority over the target product. Record legacy-expectation vs approved-target conflicts with owner, requirement, source and evidence; preserve current regression protection until human resolution.
- Read [test-integrity](../../.antigravity/rules/test-integrity.md). Report actual results: what ran, what failed, what did not run (NOT RUN). Exit 0 alone is not PASS; check logs for parse/runtime errors.
- A negative fixture must exercise the real path and produce the expected reason; an arbitrary crash/timeout is not negative PASS.
- Real physics means registered collision and Input-driven bicycle; teleport, camera placement and geometry replay do not establish ride coverage. Vulkan evidence needs actual saved/read captures. E7 belongs to a human.
- In DEEP, verify/review do not fix implementation or tests; findings return to the implementation owner.
