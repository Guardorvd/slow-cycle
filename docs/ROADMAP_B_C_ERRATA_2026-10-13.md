# Roadmap v2 → v2.1: factual errata E1–E5

DATE: 2026-10-13. AUTHORIZATION: Game Director, «Slow Cycle — BC0 Accepted → BC1 Planning», items 1–4. Scope: factual corrections only; no architecture, phase, product, test or gate change. BC0 remains COMPLETE; roadmap remains ACCEPTED; PR1 remains SUSPENDED.

Original accepted text: `2a43bc092b503987a9a2845232a3791b0ad69e21:docs/ROADMAP_B_C_ROUTE_REALIZATION.md`. Original findings and prior correction/reversion history remain unchanged in [BC0 §4](plans/completed/BC0.md). This is a separate correction after BC0, not a new BC0 iteration.

| Erratum | Change | Evidence / authority |
|---|---|---|
| E1 | Move R7 out of the accepted-Alpha row; explicitly retain Director acceptance pending | [R7 record](plans/completed/R7.md), opening status; technical LIMITED ALPHA is not Director acceptance |
| E2 | Replace «only region_ride_bot» with execution through test_region_ride, capture_region_world and region_ride_bot; distinguish execution from assertions | Test script scene preloads; region_world → RegionBake → RegionNetworkBuilder/RealizedRoadNetwork; [Test Strategy §8.4](TEST_STRATEGY.md) |
| E3 | Replace «no tests» with the precise absence of assertions of PR1 network rules and never-created test_region_network | Existing scripts are present; [PR1 §4](plans/suspended/PR1.md) records D10 T1/T2.4 incomplete |
| E4 | Add the missing coverage/handoff obligation and record S3 OPEN / KNOWN FAILURE, BC2 assessment; no compulsory three-suite prerequisite for first playtest | [PR1 §4–7](plans/suspended/PR1.md); Director items 2 and 4, 2026-10-13. BC1 ExecPlan allocates coverage by responsibility; no test is waived |
| E5 | Replace stale pre-BC0 status wording in authority paragraph, PR1 lifecycle, K1/K2, RM-8/RM-9 and next step | [BC0 completed record](plans/completed/BC0.md), final commit 2a43bc0; K2 was resolved in the same BC0 change as K1 |

No E1–E5 correction requires changing an approved architectural decision. The older RoadLogic ADAPT/RETIRE tension (BC0 §3 R2-N2) is outside these errata and outside BC1: unchanged, for the first retirement task. No new retirement gate is introduced.

Director clarification on G: applicable gates remain mandatory for BC1 formal verification and before a future master merge; PLAYABLE / REVIEWABLE uses Test Strategy §8. Nothing here certifies the unverified PR1 runtime. S3 is distinct from FinalSurface principle S3 (NATURAL preserves shape).

Validation: targeted source/reference checks; history preserved; docs-only diff; code/tests/governance unchanged. Godot, runtime L2, VERIFY and independent REVIEW have not run for BC1. This record claims only the authorized factual correction, not phase acceptance.
