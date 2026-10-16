# Generator V2 — documents

STATUS: CURRENT (2026-10-16). Direction accepted by the Game Director (decisions G1–G3); GEN2-1 COMPLETE (accepted 2026-10-16); GEN2-2…GEN2-5 PROPOSED, each needs its own approval. The BC3 ExecPlan in the [root plan slot](../../implementation_plan.md) is not changed by these documents.

Goal: structurally different mountains and valleys, routes from calm to technical, real riding with the existing bike (physics, camera and controls unchanged), and a short "change → generate → ride" cycle.

| Document | What it is |
|---|---|
| [GENERATOR_V2_REPORT.md](GENERATOR_V2_REPORT.md) | Review of V1 constraints, architecture and speed — revision 2 with r2.1 notes (§2.2 search definitions, §14 GEN2-1 measurements). Russian. |
| [GENERATOR_V2_REPORT_r1.md](GENERATOR_V2_REPORT_r1.md) | Revision 1, kept unchanged so original findings stay distinguishable from corrections (its file links point to the project folder of that time; the probes are in [probes/](probes/)). |
| [GENERATOR_V2_PLAN.md](GENERATOR_V2_PLAN.md) | Compact stage plan GEN2-1…GEN2-5 with the Director's clarifications, measurement plan, checks and open question. |
| [V1_SNAPSHOT.md](V1_SNAPSHOT.md) | V1 control snapshot: code `d2ad73f`, configurations, environment, product digests, how to open. The archives (111 MB) stay in the project folder `generator-v1-snapshot/`, outside Git, not published. |
| [../investigations/GEN2_1.md](../investigations/GEN2_1.md) | GEN2-1 record: `tools/dev/trail_probe.gd`, commands, measurements, checks run, NOT RUN. |
| [gen2-1/](gen2-1/) | GEN2-1 evidence: timed cold bake, check-mode summary, exact vs full summary, slope candidates (CSV + map), BC1 maps, wall/RSS lines. |
| [probes/](probes/) | The two diagnostic scripts of the review (`slope_probe`, `access_probe`), stored as text; not part of the game. |

Related backlog: N-7 (2024 without a continuous backbone, reproduced on `d2ad73f`), D-10 (GEN2-1 checks not run) in [BACKLOG_ACTIVE.md](../BACKLOG_ACTIVE.md).
