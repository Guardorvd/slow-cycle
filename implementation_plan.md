TASK: BC3 — Free riding in a consistent natural world
DATE: 2026-10-15
STATUS: PLAN_ONLY — awaiting Game Director approval (AGENTS.md: new phase → compact ExecPlan, STOP)
BRANCH/BASE: bc2-stabilization-perf (post-BC2 A + B1) on master e7730ca
PREVIOUS: [BC2](docs/plans/completed/BC2.md) COMPLETE (playtest-accepted); post-BC2 stabilization A1–A6 + B1 counters; ENGINEERED-only experiment not adopted ([record](docs/investigations/POST_BC2_PERF.md)).
ALSO PLAN_ONLY (2026-10-15): PERF-P2 natural route intents, at the end of this file (PERFORMANCE FIRST part 2; answers D4 below). Branch `perf-first`.

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

---

TASK: PERF-P2 — Natural route intents: R5 keeps them, R6 does not design them, trails realize them
DATE: 2026-10-15
STATUS: PLAN_ONLY — awaiting Game Director approval (PERFORMANCE FIRST part 2: substantial R5 → R6 → BC2 interaction change)
BRANCH/BASE: `perf-first` (stage reuse, C# terrain kernel, ROADS stop rule; [record](docs/investigations/PERF_FIRST.md))

## Goal

Cold bakes of rugged regions stop paying for R6 designs of SINGLETRACK / TECHNICAL road edges that fail, while every natural route R5 finds can still become a published trail, and none appears as a road it is not.

## Current state (measured, Linux, 4 threads, `perf-first`)

- 3628391 (3,−2): network 347 s of a 553 s bake; R6 102 / 100 / 71 s per round, mostly natural edges that end REPLAN_REQUIRED (B1: SINGLETRACK 426 CPU-s, 94 % failed; TECHNICAL 90 CPU-s, 100 % failed). The ROADS stop rule does not help: only round 2 meets N1–N6.
- 184729: natural edges are cheap (≈ 3 s per round); the ROADS stop rule already removed the useless third round (network 109 → 62 s, same result).
- No chosen production network contains a READY SINGLETRACK / TECHNICAL road edge; all natural riding is BC2 trails (`TrailNetworkPlanner` pairs ports on the road network by detour / gain / descent filters, `TrailRealization` publishes).
- Coupling (R6_ENGINEERED experiment): skipping those designs changes round hints and junction outcomes, so later rounds differ; 184729 lost two trails. A speed-up that re-rolls accepted regions is not acceptable silently.

## Target behaviour and exclusions

- R5 plans every class as today. R6 records SINGLETRACK / TECHNICAL edges as `INTENT` (never READY, never pieces, never in the road network, collision or render) with the R5 polyline, class, end nodes and the reason `NATURAL_INTENT`.
- Round hints: intents produce none (their failures were the noise that re-rolled layouts); the replan loop judges roads only (ROADS rule).
- `TrailNetworkPlanner` takes the intents of the chosen round as first candidates of their class: ports near both intent ends, the R5 polyline as the search corridor bias; the detour / gain filters are waived for an intent pair (R5 already judged the route), every physical check stays (TrailRealization screening, publication, trap check). An intent the realization rejects is reported (`ERR_TRAIL_*` with the intent id), not published.
- Out: changing R6 limits, road classes, R7, the vegetation model; faking READY edges or passability.

## Ownership and contracts

R5 owns intents (unchanged graph schema); R6 owns the INTENT record status (ADAPT `RoadSynthesizer`: skip design of natural classes); `RegionNetworkBuilder` owns the stop rule (ROADS, already on the branch); `TrailNetworkPlanner` owns turning intents into trail candidates (ADAPT: one new pair source); `RealizedRoadNetwork` exposes `intents` read-only. One-way dependencies kept: R5 → R6 → network → trails.

## Files

`road_synthesizer.gd`, `region_network_builder.gd`, `realized_road_network.gd` (intents passthrough), `trail_network_planner.gd`, `region_bake_trails.gd` (report), new FAST test cases in `test_bc2_trails.gd` / `test_region_network.gd` (new cases only; existing assertions unchanged). Protected: BicycleController, camera, controls, R7, renderer contracts, existing tests.

## Sprints

1. **S1 intents (R6/builder):** INTENT records, no hints from them. FAST + 3-seed bake table (time, roads, loops). Playtest: none (roads only).
2. **S2 intent pairs (BC2):** intent candidates first; publish report lists intent → trail / rejection. Playtest: 184729 (0,0) and 3628391 (3,−2), 3–5 placement captures each of new / changed trails, launch command; Director ride decides.
3. **S3 decision:** keep S1+S2 as production only if 184729 keeps ≥ TECHNICAL 2 + SINGLETRACK 2 with alternatives and loops, 3628391 keeps its TECHNICAL descent, 2024 not worse; otherwise revert to `perf-first` without S1/S2.

## Risks

Layout re-roll on every seed (accepted regions change; their caches re-bake); intent pairs could publish dull trails (playtest judges); 2024 N-7 stays (backbone loss is R7 / R6 BACKBONE, not intents). Confirmed trap or missing road after S2 → DEEP ride check on that seed.

## Checks

FAST: parse, `test_perf_dev_cache`, `test_region_stabilization`, `test_region_network --group=domain`, `test_bc2_trails --group=domain` + new intent cases. Bakes: 184729, 3628391, 2024 cold, same machine, old vs new. DEEP: none unless a risk above is confirmed.

## Done

Director rides 184729 and 3628391 and accepts; backlog updated; record in `docs/investigations/PERF_FIRST.md`.

## Decision for the Director

- **P2-1** Approve PERF-P2 S1–S3 (layouts of existing seeds may change; acceptance by ride), or keep `perf-first` as is (ROADS stop rule only; 3628391-type regions keep their R6 cost).
