TASK: BC3 — Free riding in a consistent natural world
DATE: 2026-10-15
STATUS: PLAN_ONLY — awaiting Game Director approval (AGENTS.md: new phase → compact ExecPlan, STOP)
BRANCH/BASE: bc2-stabilization-perf (post-BC2 A + B1) on master e7730ca
PREVIOUS: [BC2](docs/plans/completed/BC2.md) COMPLETE (playtest-accepted); post-BC2 stabilization A1–A6 + B1 counters; ENGINEERED-only experiment not adopted ([record](docs/investigations/POST_BC2_PERF.md)).

---

## Goal

The rider leaves the road anywhere sensible and rides a world that is physically what it looks like: trees and rocks stand on the ground, the ground off the roads has gentle relief worth riding, forest, meadow, shore and road read as one place. Master R9–R12 / B+C phase 3. Playable checkpoints, not an audit.

## Current state (measured 2026-10-15, Linux, cached 184729)

- Vegetation is placed on the design surface (`FinalSurface.sample_height`), the world renders/collides 16 m terrain cells off the roads. Exact barycentric lookup on the published triangles: 160 171 instances, **1 891 > 1 m off** (pine 668, birch 508, rock 295, shrub 229, grass 191), 8 365 > 0.5 m, max 5.8 m (above and below). Exact lookup cost: 2.0 s index + 0.3 s query for the whole region, single thread (vegetation stage today ≈ 90 s).
- Off-road render = collision (same triangles); design-time queries differ by up to ~3.6 m (BC1 record). Off-road mesh is a 16 m lattice (2 048 triangles per pure-terrain tile; region 2.9 M triangles, mostly road cells) — no relief below ~32 m wavelength can exist physically.
- Topology: trail opportunities depend on road layout (2024: 0 trails, 3628391: TECHNICAL only; backlog N-6). R5/R6 layout is chaotic under small changes (experiment record).

## Target behaviour and exclusions

In: published-world consistency, free off-road riding, meso/micro relief, natural environment, a geography-level look at trail opportunities. Out (BC4–BC6): landmarks, vistas, ride situations, vertical play, new archetypes, long-term hardening; no change to BicycleController, camera, controls, protected tests or safety limits.

## Ownership and contracts

- FinalSurface/bake own "height after publication": one published-ground query (exact triangle lookup, per tile index) used by vegetation, rocks, their colliders and any other post-publication consumer (KEEP renderer; ADAPT vegetation planner to take it).
- Relief: **meso** (≈ 64–400 m rises, hollows, gullies) belongs to the natural terrain layer before hydrology and routes (WORLD FIRST); **micro** (≈ 4–32 m bumps, swales) is a bounded FinalSurface ground-detail layer off the road planes, structures and water, published only where the mesh can carry it. Decision D2 below.
- Vegetation model v2 stays a pure planner per tile; runtime only renders/collides.

## Sprints (each ends in a Director playtest)

1. **S1 Ground truth for objects (first checkpoint).** Vegetation and rocks placed on the published triangles; trunk/rock colliders from the same height; rocks bedded by their slope. Exact per-tile lookup, threaded with the existing per-tile vegetation jobs. Measure on 184729 / 2024 / 3628391: residual error (target: none > 0.05 m), cost (bake ± s). Vegetation digest changes (expected). Playtest: 184729 forest edge, rocky slope, creek bank; 3–5 Vulkan captures + launch command.
2. **S2 Free off-road riding.** A small off-road ride tool (road → meadow → forest edge → creek → road) on real collision, plus a probe comparing design vs published heights where other consumers still use design queries (recovery, water depth, markers); fix what it finds (patch coverage, colliders, water boundary). Playtest: "I'll just ride straight there" on 184729.
3. **S3 Relief (after D2).** First measure: triangle/bake/streaming budget of an 8 m and a 4 m off-road lattice inside a riding zone (≈ 250 m of roads/trails, gentle ground), versus today. Then add meso relief upstream and micro detail on the refined zone only. Playtest: meadow and valley floor of 184729 and 2024 no longer read flat; bake time and frame time reported.
4. **S4 Natural environment.** Forest massifs with edges and clearings, meadows, shore vegetation and bank transitions, road verges (no trees on cuts/fills, grass shoulders), all from BiomeField/RideabilityField/HydrologyPlan. Playtest: one valley ride, road ↔ forest ↔ meadow ↔ river.
5. **S5 Geographic variety (study + one general change).** Measure trail opportunities over a fixed seed set (road loops, level differences, gentle ground beside roads, rejected pair reasons); propose one general remedy (e.g. a road-generator cross-connection rule or the BC2 D-C3 B "nature loop"), never a per-seed trail. Director picks before implementation.

## Risks

- Vegetation/relief change digests of every region (expected; old caches rebake — cold bake ≈ 6–11 min per region).
- Upstream meso relief moves rivers, routes and trails of accepted seeds (184729): treat as a deliberate re-roll, playtested.
- Mesh refinement cost: triangles, bake time, streaming commits (today max 150 ms per patch commit on 184729) — measured in S3 before adoption.
- N-7 (region without continuous backbone published) is a data-integrity risk; if it reproduces on the Director's machine it is fixed first (small: refuse or prefer a round with a backbone).

## Checks

FAST per sprint: parse + `test_region_stabilization`, `test_region_network --group=domain`, `test_bc2_trails --group=domain` + a new small test per sprint (vegetation on triangles; ground-detail mask off roads/water). PLAYTEST per sprint as above. DEEP only on a named risk or Director decision (D-1…D-7 stay in the backlog).

## Done

Director playtest acceptance of S1–S4 (S5 decision recorded); backlog updated; COMPLETE (playtest-accepted).

## Decisions for the Director

- **D1** Approve BC3 scope and order S1 → S5 (S1 is the first checkpoint).
- **D2** Relief placement: meso upstream (re-rolls existing seeds incl. 184729) + micro in FinalSurface on a refined riding zone (recommended), or micro only (keeps routes, less relief).
- **D3** Accept vegetation/tile digest changes and a bake-time budget for relief (proposal: ≤ +20 % bake, no frame-time regression).
- **D4** ENGINEERED-only R5/R6: not adopted (record); confirm, or fund a road-model change as its own task.
