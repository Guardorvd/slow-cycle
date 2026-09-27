# Slow Cycle — Verification & Testing Protocol

## Stage B1 — MTB event to road surface (2026-09-27)

Command: `& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_mtb_event_pipeline.gd`

Result: **8/8 PASS**, zero failures. Four fixed seeds (`184729`, `42`, `7319`,
`900001`) were each replayed twice. Every replay generated 3 AIRBORNE, 8 LANDING
and 25 RECOVERY samples; the road mesh contained 102 vertices and collision data
contained 300 face vertices. All 11 event centerline segments had midpoint
coverage by the road collision triangles. Event acceptance, recovery validation,
non-empty finite surface data and repeated signatures passed.

This exercises production RoadLogic and RoadChunk geometry preparation; it does
not instantiate the collider in a physics space or ride the bicycle across it.
Godot exited 0. The environment printed its known `user://logs/godot.log` and
Windows root certificate messages; there were no parse/runtime/test failures.

## Stage B2 — seeded long-range route rhythm (2026-09-27)

Session-seed command: `& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_world_session_seed.gd`

Result: **7/7 PASS**. Confirms fixed-seed test/tool default, positive fresh session
seed, distinct consecutive fresh seeds, explicit `--seed=N` replay, user-argument
precedence, seed 0 support and that the normal main scene opts into fresh sessions.
The existing F3 DebugHUD shows the effective seed. Stage E still adds user-facing
seed choose/copy controls.

Command: `& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_route_rhythm.gd`

Result: **105/105 PASS**, zero assertion failures. Eight fixed world seeds replayed
1200 phases per FLOW, BALANCED and TECHNICAL profile twice. Every window obeyed its
cap (FLOW ≤2, BALANCED ≤3, TECHNICAL ≤4 major events per 12 phases); observed maxima
were 2, 3 and 3. Longest interval without crest/switchback/jump was 6–8 chunks,
within the 8-chunk limit. Aggregate major events were FLOW 942/9600, BALANCED
1564/9600 and TECHNICAL 1924/9600 phases. These are observations from the tested
seeds, not exact player-percent targets. Across 4 seeds × 3 styles × 150 production
`RoadLogic` chunks (with replay), all chunks passed validation without fallback,
same-seed centerlines replayed exactly and different seeds produced different
centerlines. Major-event counts were FLOW 15–16, BALANCED 24–27, TECHNICAL 30–34.

Before implementation, the same battery measured FLOW 191–211 and TECHNICAL
193–213 major phases per 1200: long-run style profiles were nearly identical.
Feature-free gaps reached 9–12 chunks and rolling windows reached 3 major events.
This baseline motivated style-specific pacing and bounded spacing.

Regression checks after B2: `test_road_grammar.gd` 5 × 1000 chunks without
validator/seam/transition errors; RouteIntent 72/72; RoutePlan contract 166/166;
Road contract 18/18; REVIEW-FIX 25/25; B1 event-to-surface 8/8; route integration
8/8. The RoutePlan contract runner exited 0 but emitted one `6 ObjectDB instances
were leaked` warning in this run. That test and its authored 9-phase opening are
unchanged by B2; the warning is recorded and not treated as resolved. Manual ride
was not part of this task. Godot also prints the known log-file and Windows
certificate-store messages.

## P2.1b — RouteIntent / RoutePlan data contract (2026-09-27)

Command: `godot --headless --path . --script res://scripts/test/test_route_plan_contract.gd` (Godot 4.7.2 mono). Result: `ROUTE_PLAN_CONTRACT_SUMMARY checks=166 failures=0 geometry_profiles=16 physics_traces=2`.

The 16 geometry profiles used 4 world seeds × 2 style salts × FLOW/TECHNICAL. Each route generated nine production chunks (about 450m), then repeated in reverse battery order. Route/style signatures and centerline outputs matched; all measured sample gaps were 2.015–2.022m. FLOW measured grade −8.24°…+0.98° and max curvature 0.00101–0.00166m⁻¹; TECHNICAL measured grade −7.48°…+0.95° and max curvature 0.05118–0.05263m⁻¹. Segment event counts retained the existing two FLOW crests and two opposite TECHNICAL switchbacks/recovery pattern.

The focused runner also checks incomplete/mismatched intent, missing intervals/metrics, malformed path arrays, stable plan serialization, data-only (no Node references), and two controller telemetry traces. Those traces use an automated follower that maintains path progress at a 7m/s minimum; controller signals averaged about 9.5km/h / 0 cadence / 33% coasting for both styles in the final run. This proxy is inconsistent with its imposed path pace and is explicitly **not** a rider-quality target or a manual ride result. No subjective style thresholds were set from it.

Existing suites after adding the read-only grammar adapter passed: RouteIntent `72/72`, RoadGraph `61/61`, branch streaming `49/49`, fork geometry `15/15`, road contract `18/18`. Godot prints the known log-file and Windows certificate-store environment messages. Manual bike review remains open.

## REVIEW-FIX-01 — Runtime and generation regressions (2026-09-27)

`test_review_fix.gd`: **25/25 PASS**. It covers graph pruning/adjacency, order-independent foliage seeds derived from route identity and quantized path interval, malformed/empty path rejection and occluded braking visibility, generated AIRBORNE distance/height plus landing acceptance on four seeds, and normalized surface weights after frame hitches.

Regression suites passed: RoadGraph `61/61`; branch streaming `49/49`; road contract `18/18`; RouteIntent `72/72`; mountain validation `12/12` over 60 forks; master runner `125/125` expected budget across all seven tiers. The master runner also passed five-seed determinism and scene-switch cleanup. The streaming soak ran 500 chunks (25 km) each on seeds `184729`, `10101` and `99999`; all completed with 9–10 active chunks, graph history at 2–5 nodes / 0–3 edges and RAM deltas +1.4, +0.9 and +0.8 MB.

Godot 4.7.2 headless processes exited successfully. The environment still reports inability to write `user://logs/godot.log` and read the Windows root certificate store; no parse errors, assertion failures or repeatable ObjectDB leak warning appeared. No manual bike ride was part of this regression task. Foliage uses a positive 63-bit hash key; theoretical hash collisions remain possible, with negligible probability for the exercised chunk set.

## P2.1a — Fork-site endpoint preflight (2026-09-27)

Command:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_fork_site_planner.gd
```

Result: exit code 0, `FORK_SITE_PLANNER_SUMMARY checks=32 failures=0`. The isolated contract cases cover a valid grounded endpoint, no path mutation and deterministic repeated output, invalid prior chunk, short/non-finite planned braking visibility, danger on each terrain side, incomplete terrain result, narrow/steep/over-curved/not-grounded samples, non-finite distance, misaligned sample arrays and invalid candidate index. A forced rejected candidate was also sent through the real streamer update: an ordinary chunk was committed, the endpoint was not widened, and no fork/child branch was created.

The integrated endpoint search on each production road seed accepted the initial 350m endpoint with zero deferrals: seed `184729` ended at 349.9m, seed `42` at 350.0m, and seed `99999` at 349.9m. The two independently generated traces for each seed compared equal. This means the new planner is wired and deterministic; it does **not** demonstrate terrain-driven deferral on these seeds. The negative terrain/safety cases are verified at the evaluator, while runtime retry behavior is verified using a forced rejection seam. Keep this limitation visible when evaluating whether P2.1 is complete.

Godot printed the known environment messages for unavailable `user://logs/godot.log` and the Windows root certificate store. The completed process reported no parse errors, assertion failures or leak warning. This is headless structural validation; it is not a human bike ride and does not inspect the unbuilt future fork arms.

P2.1a regression run (same Godot 4.7.2 mono executable, no test source/assertions changed): route branch integration `failures=0 routes=8`; fork geometry `15/15`; branch streaming `49/49`; route intent `72/72`; terrain carver `99/99`; road contract `18/18`; mountain stress `12/12` across 60 forks and three seeds; route clearance audit `failures=0 candidates=0 seeds=2 choice_modes=2`. Center-road collider misses before/after chunk update: zero for both seeds and both fixed-choice modes. A leak warning appeared once during a parallel mountain run, then did not repeat when mountain stress was rerun alone; see `implementation_plan.md`. Environment log/certificate messages persist.

## 0. Route-Level Fork Integration (2026-09-26)

Run from the project root with Godot 4.7.2 mono:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_route_branch_integration.gd
```

The harness creates a fresh runtime scene for each combination of seeds `184729` and `42` and LEFT/RIGHT. It asks the production `ForkDecisionModel` to choose using the registered runtime `RoadGraph` centerlines, then advances the selected rider position along generated centerline samples through `ChunkStreamer` until that branch materializes its next fork. While advancing, it records distance, elevation change, grade and curvature ranges, contact-state sequence/counts, sample gaps, solid collision coverage, selected branch identity/style, and whether the next fork appeared. The route follower places the rider at actual generated samples; this is not a free-running bicycle-physics playtest.

| Seed | Choice | Branch / style | Length to next fork | Elevation delta | Grade range | Curvature range | Contact states | Max sample gap |
|---:|---|---|---:|---:|---:|---:|---|---:|
| 184729 | LEFT | 0 / TECHNICAL | 450.9 m | -28.32 m | -7.67° to -1.46° | 0.0000 to 0.0505 m⁻¹ | GROUNDED (227 samples) | 2.001 m |
| 184729 | RIGHT | 1 / FLOW | 150.0 m | -10.71 m | -5.35° to -3.32° | 0.0003 to 0.0017 m⁻¹ | GROUNDED (76 samples) | 2.001 m |
| 42 | LEFT | 0 / TECHNICAL | 451.0 m | -35.75 m | -7.00° to -0.33° | 0.0000 to 0.0493 m⁻¹ | GROUNDED (225), MICRO_DROP (2) | 2.018 m |
| 42 | RIGHT | 1 / FLOW | 150.0 m | -7.88 m | -3.82° to -1.80° | 0.0001 to 0.0035 m⁻¹ | GROUNDED (76) | 2.000 m |

### P0.1 cadence/style audit correction

The table above records the original P0 run. Its route follower manually called `ChunkStreamer.update_streaming()` while `WorldManager._process` also called it, so the LEFT distance (450.9/451.0 m) depended on duplicate update cadence. Treat those values as historical observations, not a deterministic acceptance metric. The style labels for seed `42` were also read after the following fork mutated runtime `route_style`; the selected edge at the original choice was LEFT=FLOW and RIGHT=TECHNICAL. For seed `184729`, it was LEFT=TECHNICAL and RIGHT=FLOW.

Run the isolated diagnostic with:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_route_style_spacing_audit.gd
```

The runner disables background `WorldManager` and bicycle updates, then explicitly advances the real streamer. With the same two seeds and choices, it reported LEFT/primary next-fork materialization at 300.9 m and RIGHT/child at 150.0 m, regardless of which style each seed assigned to that side. This points to branch role/lifecycle and update setup in this diagnostic scenario, not style alone. The controlled 100 m interval was applied only after branch choice; for RIGHT, the seeded next fork could already have spawned before the override, so this is not a clean comparison to production-default interval behavior. The measured endpoint is next-fork materialization, not rider arrival at that fork.

Audit result: two consecutive isolated runs reproduced all four traces; `STYLE_SPACING_AUDIT_SUMMARY failures=0 traces=4`. Logged chunks were valid (`last_valid=true`, validator error count 0). Rejected candidate/fallback history is not exposed by runtime and therefore remains unproven. Godot printed existing environment messages for the user log path and Windows root certificate store; no parse or leak warnings were seen. The corrected P0.2 integration results follow.

### P0.2 corrected fork-to-fork integration

The updated route harness disables `WorldManager._process` and bike processing and calls `ChunkStreamer.update_streaming()` at one controlled cadence. It records the selected style from the graph branch at initial choice time, then follows the active generated parent centerline to within 20 m of the next fork and drives along a real outgoing edge until the next production decision locks to that edge. The initial fork is a fixed fixture at 100 m in both modes. In the controlled mode, both outgoing branch targets are set to 100 m before the choice; the report also marks when a fork was already materialized before measuring it. In default mode the following intervals retain production seed scheduling.

Run:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_route_branch_integration.gd
```

| Interval mode | Seed | Choice / style at choice | Distance fork-to-arrival | Elevation delta | Grade range | Curvature range | Arrival to node | Next choice lock |
|---|---:|---|---:|---:|---:|---:|---:|---|
| Controlled 100 m | 184729 | LEFT / TECHNICAL | 300.9 m | -15.63 m | -4.52°…-1.88° | 0…0.0505 m⁻¹ | 16.01 m | branch 2, locked |
| Controlled 100 m | 184729 | RIGHT / FLOW | 150.0 m | -10.71 m | -5.35°…-3.32° | 0.0003…0.0017 m⁻¹ | 18.01 m | branch 1, locked |
| Controlled 100 m | 42 | LEFT / FLOW | 300.9 m | -22.30 m | -7.00°…-0.33° | 0…0.0017 m⁻¹ | 16.01 m | branch 2, locked |
| Controlled 100 m | 42 | RIGHT / TECHNICAL | 150.0 m | -7.88 m | -3.82°…-1.80° | 0.0001…0.0035 m⁻¹ | 18.01 m | branch 1, locked |
| Seeded default | 184729 | LEFT / TECHNICAL | 851.0 m | -54.35 m | -7.67°…-1.46° | 0…0.0519 m⁻¹ | 18.01 m | branch 2, locked |
| Seeded default | 184729 | RIGHT / FLOW | 650.1 m | -54.07 m | -7.54°…-0.29° | 0…0.0520 m⁻¹ | 18.01 m | branch 1, locked |
| Seeded default | 42 | LEFT / FLOW | 651.0 m | -48.67 m | -7.00°…0.35° | 0…0.0493 m⁻¹ | 18.01 m | branch 2, locked |
| Seeded default | 42 | RIGHT / TECHNICAL | 600.1 m | -43.77 m | -7.52°…-0.77° | 0…0.0486 m⁻¹ | 16.01 m | branch 1, locked |

Both full runs reproduced the same eight route rows; `ROUTE_INTEGRATION_SUMMARY failures=0 routes=8`. Each route passed graph identity, positive length, <=2.5 m sample gap, solid collision coverage and next-edge lock checks. The controlled LEFT/primary fork was already materialized at route start: the parent road had been generated about 301 m beyond the first fork, so its 300.9 m result is not a valid 100 m interval measurement. The RIGHT/child controlled result (150 m) had not been materialized and is a valid illustration of the 100 m target plus preload/chunk effects. Treat controlled mode as a lifecycle stress trace, not a balanced side-by-side interval experiment. In seeded-default mode, all four following forks were unmaterialized at measurement start, and the prior fork origin matched the route origin; those rows are suitable for comparing assigned and observed spacing.

The route follower places the rider at generated centerline samples, so this does not establish a free-running bicycle experience. Seeded-default lengths range from 600.1 to 851.0 m; P0.3 below compares them directly with their assigned intervals. Godot still prints environment messages about log writing and Windows certificates; no parse or leak warnings were emitted.

### P0.3 spacing and route-role interpretation

The runtime currently sets the nominal subsequent fork distance to 700 m, then deterministically varies it by ±18% per seed/branch. Thus the scheduled range is 574–826 m. For the four seeded-default routes, the report captured the assigned target, local origin offset, and observed distance:

| Seed | Choice / style | Assigned target | Route origin offset | Observed to fork | Difference |
|---:|---|---:|---:|---:|---:|
| 184729 | LEFT / TECHNICAL | 820.7 m | 0.0 m | 851.0 m | +30.2 m |
| 184729 | RIGHT / FLOW | 624.6 m | 0.0 m | 650.1 m | +25.5 m |
| 42 | LEFT / FLOW | 618.1 m | 0.0 m | 651.0 m | +32.9 m |
| 42 | RIGHT / TECHNICAL | 591.0 m | 0.0 m | 600.1 m | +9.1 m |

The observed distance is only 9–33 m above target, below the 50 m chunk length. This is consistent with the streamer checking distance at chunk boundaries and only spawning when the site is safe and enough generated road lies ahead. The target, origin, and observed distance show no evidence of a default-schedule defect in these four traces.

**Draft pacing proposal, not yet an enforced requirement:** for the first 1–2 km greybox route, aim for fork-to-fork legs around **550–900 m**. This brackets the observed default routes and leaves room for roughly two or three meaningful route segments in the target demonstration length. Keep both styles in a similar length band initially; distinguish FLOW through sweeping turns/rollers and a smoother rhythm, and TECHNICAL through tighter line choices, switchbacks and controlled drops. Existing shared geometry safety limits remain authoritative: grade -14°…+5°, radius >=18 m, curvature <=0.0556 m⁻¹. Current two-seed data does not show reliable numeric grade/curvature separation by style, and the sampled legs had no full AIRBORNE/LANDING sequence, so those experience targets need additional seeds and an actual bike ride before becoming assertions.

Related regressions: fork decision 212/212, fork geometry 15/15, branch streaming 49/49, mountain validation 12/12. Existing tests/assertions were not changed.

## Human Greybox Ride Feedback (2026-09-26)

Initial qualitative report from the player; observations are recorded but have not yet been reproduced across a controlled seed/choice sequence:

- The game appears to start on the same seed each time, and the first fork takes too long to reach.
- The fork can be seen from far away, but its signs/markers feel cluttered; the space between left and right arms looks empty.
- The alternatives feel alike, and generation of challenging features is weak beyond gentle slopes and straight sections.
- Visual artifacts occur; the bike can fall through the surface.
- One selected route curls beneath a later fork and becomes impassable, possibly because the lines overlap or lack vertical clearance.

These findings make route passage and surface collision the next diagnostic priorities. Do not infer yet that the seed pool is small or that the fork arms need additional geometry; first reproduce the cases and identify their seed, choice sequence and exact location. The route crossing/fall-through reports are potential blockers; signs, empty space, spacing and route-role variety follow once passage is reliable.

### P0.4 diagnostic pass — partial, 2026-09-26

Added `scripts/test/test_route_clearance_audit.gd`. It follows 12 forks on seeds `184729` and `42` with deterministic alternating LEFT/RIGHT choices. Both traversals completed (`failures=0`); the graph scan found zero non-connected centerline pairs within 3 m horizontal / 2 m vertical clearance. This does not rule out the player's under-fork case because their exact branch-choice sequence and location are unknown.

The same run found three centerline samples where a ray on road collision layer 2 missed the road and an all-layer ray hit terrain layer 4: two on seed `184729` (branches 8/10, local route distances 803.00/602.95 m) and one on seed `42` (branch 8, 602.99 m). Each point was nominally covered by an active road chunk. These are collision-coverage candidates, not yet confirmed player fall-through: the audit currently raycasts after streaming update and does not compare before/after or lateral samples. Next, isolate those samples across streaming, verify ray hit heights/shape coverage, and only then scope a production repair.

The scene's `world_seed` is explicitly set to `184729`; `WorldManager` also accepts `--seed=<int>`. The repeated start therefore comes from the configured default, not evidence of a limited seed pool. Source inspection of fork dressing also shows two directional signs and eleven marker posts across the paired fork chunks, a plausible cause of the reported clutter. The wedge is generated in code, but the empty center appearance still needs visual/runtime confirmation.

Godot audit summary: `ROUTE_CLEARANCE_AUDIT_SUMMARY failures=0 candidates=0 seeds=2`. Existing environment messages appeared for log-file writing and Windows root certificates; no script parse errors, engine assertion failures, or leak warnings appeared. `git diff --check` passed.

### P0.4 follow-up — collision-hole isolation, 2026-09-26

Expanded `scripts/test/test_route_clearance_audit.gd` as a diagnostic-only runner. For each seed (`184729`, `42`), it now traverses 12 forks with LEFT-only and RIGHT-only decisions (4 runs, 48 fork choices total). At each sampled centerline point it casts road-layer vertical rays at lateral offsets `-0.5m`, `0m`, `+0.5m`, from `+5m` to `-5m`, both immediately before and after `update_streaming()` plus one physics frame. It records centerline road misses and hit height relative to the centerline point.

| Seed | Choices | Forks | Center misses before / after | Road hits before / after | Hit Y delta to centerline point |
|---:|---|---:|---:|---:|---:|
| 184729 | LEFT only | 12 | 0 / 0 | 7413/7413 / 7413/7413 | -0.027…+0.672 m |
| 184729 | RIGHT only | 12 | 0 / 0 | 6030/6030 / 6030/6030 | -0.060…+1.038 m |
| 42 | LEFT only | 12 | 0 / 0 | 5688/5688 / 5688/5688 | -0.026…+0.653 m |
| 42 | RIGHT only | 12 | 0 / 0 | 5694/5694 / 5694/5694 | -0.059…+0.611 m |

All-layer/terrain substitution was therefore not observed in these runs, and the three earlier road-layer misses were not reproduced even with the original ±5m ray height. No close non-connected centerline candidates were found (`candidates=0`); this does not disprove the reported under-fork route because the exact seed/choice sequence is unknown and the scan only tests generated centerline proximity, not full bike clearance or swept collision volume. The Y deltas include the lateral probes and are measured against the centerline sample elevation; they are not a road-height error bound or a mesh-seam measurement. This evidence does not confirm a production collision defect, so no production fix plan is opened yet.

Run summary: `ROUTE_CLEARANCE_AUDIT_SUMMARY failures=0 candidates=0 seeds=2 choice_modes=2`, exit 0. No parse/assertion errors or ObjectDB leak warning in the final run. Godot still emitted environment messages about writing `user://logs/godot.log` and reading the Windows root certificate store. Existing production code and regression suites were untouched; `git diff --check` passed.

### P1.0 — Seeded macro elevation profile, 2026-09-26

Added a standalone mathematical envelope in `scripts/world/mountain_profile.gd` and the separate runner `scripts/test/test_mountain_profile.gd`. It uses stable seed/route-keyed phases for three smooth harmonics; elevation and grade are analytic, query cost is O(1), and no per-distance cache grows with travel. The profile is not yet consumed by runtime road or terrain generation.

The headless battery covered 7 seeds × 3 route identities, repeated creation, reverse-order random-access queries, 40 nominal 300m interval boundaries per seed, grade contract limits, monotonic descent, profile diversity and 12km elevation budget. Result: `MOUNTAIN_PROFILE_SUMMARY checks=39845 failures=0 seeds=7 routes=3`, exit 0. Measured 12km drop was 1070.26–1089.66m; measured grade across the route identity/seed battery was approximately -7.42°…-2.91°. No parse errors or ObjectDB leak warning appeared.

Existing regressions were run without changing assertions: `test_road_contract.gd` 18/18 PASS (5 seeded paths 100% compliant; validator benchmark 5.110ms/100 chunks); `test_mountain_validation.gd` 12/12 PASS across 60 forks, RAM delta +19.7–20.9MB. Godot emitted the known environment messages for writing `user://logs/godot.log` and reading the Windows root certificate store. `git diff --check` passed.

P1.0 established the analytic profile foundation. Runtime integration and its verification are recorded below under P1.1.

### P1.1 — Macro profile road/terrain integration, 2026-09-26

Applied a bounded profile elevation correction to generated road samples before validation and mesh/collision construction. Fork arms share the seeded profile and use a common route-distance origin; child-arm local distance is offset by the half-width needed to preserve the shared fork apex. `RoadPathData` carries macro offsets through range operations, and arc distances plus frame vectors are recalculated after height correction. `TerrainCarver` now anchors its far surface to road centerline elevation while retaining the existing lateral noise.

The new `test_macro_profile_road_integration.gd` passed 968 checks for seeds 184729 and 42, including repeated generation, both fork arms, grade/frame contracts, edge alignment and terrain elevation. Existing suites remained unchanged and passed: `test_road_contract.gd` 18/18; `test_fork_geometry_verification.gd` 15/15; `test_branch_streaming.gd` 49/49; `test_terrain_carver.gd` 99/99; `test_mountain_validation.gd` 12/12. `test_mountain_profile.gd` also passed 39,845 checks. No final-run parse errors or ObjectDB leak warnings. Godot emitted known environment messages for log-file permissions and Windows certificate-store access; process exit codes were 0.

The profile blend remains conservative (0.35). This step does not yet make FLOW and TECHNICAL branches follow distinct macro elevation plans, nor does it close the unconfirmed player-reported under-fork traversal issue. See `ROAD_GENERATION.md` §3.3 and the P1.1 task report in `implementation_plan.md`.

### P2.0 — Deterministic branch route intent, 2026-09-27

Updated only the authored opening queue in `RoadGrammar`. FLOW now produces two micro-drop/crest events across the first 9 chunks, with no switchback or airborne contact; 8/9 chunk endpoints were cruise/crest/recovery rhythm categories. TECHNICAL produces two switchbacks with alternating signed turn direction, braking and recovery after each, followed by one micro-drop and recovery. Both styles continue into the prior seeded weighted FSM after the authored opening. No validator limits, physics, camera, controls, fork scheduling, terrain, or existing assertions changed.

The new production `RoadLogic` runner exercised 4 world seeds × 2 style-seed salts × 2 styles, repeated each case and compared full generated centerline signatures. Result: `ROUTE_INTENT_SUMMARY checks=72 failures=0 seeds=4 style_seed_salts=2`. All candidate chunks passed production validation. FLOW max curvature was 0.00101–0.00166m⁻¹; TECHNICAL was 0.05118–0.05263m⁻¹ (contract limit 0.05556m⁻¹). Grade range was -8.24°…+0.98°; maximum adjacent sample gap was 2.022m (limit 2.5m). FLOW had 2 micro-drop chunks per opening; TECHNICAL had 2 opposite-turn switchbacks and 1 micro-drop chunk.

The first attempted P2 sequence included AIRBORNE_DROP. The runner exposed that the production candidate is rejected by `RoadValidityValidator` on every tested world seed: measured airborne length 6.16–6.19m exceeds 6m and drop height 1.66–1.77m exceeds 1.2m, after which the existing safe fallback replaces the intended event. This P2 scope was narrowed to supported micro-drop events; no validator/test was weakened. Track airborne geometry as a separate plan.

Regressions passed unchanged: `test_road_grammar.gd` (all checks passed; 5 × 1000 chunk deterministic battery), `test_road_contract.gd` 18/18, `test_branch_streaming.gd` 49/49, `test_fork_geometry_verification.gd` 15/15, `test_macro_profile_road_integration.gd` 968/0, `test_mountain_profile.gd` 39,845/0, and `test_mountain_validation.gd` 12/12 across 60 forks. Godot exited 0 for each. Only the known environment messages for user log writing and Windows root certificate access appeared; no final parse or leak warnings.

All four runs reached the next fork, selected the expected graph edge/branch ID, and had solid collision chunk coverage across every sampled route point. Each seed's alternatives differed in measured length, elevation profile, and curvature range. Two consecutive complete harness runs reproduced the same metrics. No AIRBORNE or LANDING states occurred in these fork-to-fork segments.

This result exposes a route-composition question for follow-up: the sampled technical alternative is about 451 m while Flow is 150 m, the opposite of the earlier route-intent sketch that described Flow as the longer, sweeping option. The harness confirms route-level difference; it does not establish that the player experiences the intended difficulty or that the current length split is deliberate.

## 1. The 10-Minute "Ride Test" (Core Milestone Verification)
The ultimate quality gate for Slow Cycle is the uninterrupted continuous **Ride Test**.

```text
Run fixed Seed -> Ride for 10 minutes continuously -> Measure telemetry and performance
```

### Acceptance Checklist:
- [ ] **Endless Road**: Road continuously generates ahead; never runs out or dead-ends.
- [ ] **No Seam Snagging**: Zero collision hitches, vertical steps, or wheel catching at chunk boundaries.
- [ ] **Zero Stutter / Hitching**: Chunk spawning in front and deletion behind occurs without frame drops (stable frame time $\le 16.6\text{ ms}$).
- [ ] **No Memory Leak**: RAM and VRAM footprint remains completely flat after 500+ spawned chunks.
- [ ] **Physical Stability**: Bicycle never launches into the air, falls through ground, or reports `NaN` / `Inf` coordinates.
- [ ] **Comfortable Dynamics**: Speed remains naturally bounded between $0\text{ km/h}$ and $48\text{ km/h}$ via air drag.

---

## 2. Fixed Test Seed Battery
All procedural updates must be tested against 5 deterministic seeds:

| Seed ID | Seed Value | Profile Character | Primary Test Focus |
| :--- | :--- | :--- | :--- |
| **SEED_001** | `10101` | **Normal / Balanced** | Baseline balance of forest paths, sunny clearings, and gentle hills. |
| **SEED_002** | `20202` | **Curvy / Winding** | High density of sweeping S-curves to test dynamic banking and steering smoothness. |
| **SEED_003** | `30303` | **Hilly / Rolling** | Frequent elevation changes to verify uphill deceleration and downhill coasting. |
| **SEED_004** | `40404` | **Scenic Straights** | Long straightaways through dense pine forests to verify sense of cruising speed. |
| **SEED_005** | `50505` | **Boundary Stress** | Maximum permitted slope ($-6.5^\circ$) and tightest radius ($35\text{m}$) to verify constraint clamps. |

---

## 3. The 3-Track Testing Tier (Sprint 4G–4M Hierarchy)
Testing is structured across three distinct track levels with strictly defined roles:

| Track / Scene | Scale | Role & Focus | Mode Access |
| :--- | :---: | :--- | :--- |
| **4K — Riding Lab 2.0** (`riding_lab_track.tscn`) | ~300–600 m | **Technical Geometry**: Tight corners, switchbacks, berms/slopes (if spike succeeds), steep climbs/descents, rollers, crests, compressions. | Mode Select (`[3]`) |
| **4L — Gravel Training Loop** (`gravel_training_loop.tscn`) | ~800–1500 m | **Riding Rhythm & Zen Flow**: Natural cycle of pedaling, coasting, sweeping turns, gentle slopes, surface changes. | Mode Select (`[4]`) |
| **4G — Regression / Endurance Track** (`riding_feel_test_track.tscn`) | ~2.8 km | **Long-Form Stability**: 18 calibrated sections, C1 seam continuity, 56 chunks, memory stability, automated telemetry soak tests. | Mode Select (`[2]`) |

*Note: 4G is no longer the primary manual feel evaluation track; that role is now served by 4L (flow) and 4K (technical).*

---

## 4. 12-Point Behavioral KPI Gate (Sprint 4H / 4M Protocol)
Every physics change in 4H–4M must be measured against the 12 KPI baseline:

1. **0 → 20 km/h acceleration**: Muscle ramp duration ($4.8–6.5\text{ s}$).
2. **20 → 25 km/h acceleration**: Transition into cruise regime ($sustain\_thrust$).
3. **25 → 40 km/h sprint**: Diminishing returns ramp and 44 km/h hard cadence ceiling.
4. **25 → 0 km/h coasting**: Free roll duration on flat ($25–35\text{ s}$).
5. **Braking distance**: Rapid bite, quadratic ramp ($0.15\text{ s}$), dive pitch $-1.44^\circ$.
6. **Bank entry time**: Responsive roll onset without lag.
7. **Maximum bank**: Physical clamp ($\le 24.1^\circ$).
8. **Bank recovery**: Self-righting speed returning to vertical.
9. **Steering return (Caster Trail)**: Return to neutral after input release ($0.52\text{ s} \le 0.75\text{ s}$).
10. **Cornering Scrub onset**: Strictly $0.0\text{ m/s}^2$ for $a_{\text{lat}} \le 1.8\text{ m/s}^2$.
11. **Cornering Scrub magnitude**: Proportional deceleration under excess lateral load ($0.22 \times \Delta a_{\text{lat}}$).
12. **Crest / Dip pitch response**: Single/dual-ray adherence, zero pitch collapse on crests.

---

## 5. Automated Verification Suite & Engine Contracts
Automated headless checks run using the Godot console (no CI workflow is configured in the repository):

```powershell
# Unified master validation suite (Godot 4.7+, 7 tiers)
godot --headless --path . --script scripts/test/test_sprint_4m_master.gd
```

- **Most recent run: 25.09.2026, Godot 4.7.2 mono (headless); 125 expected checks across 7 tiers all PASS**:
  - `Tier 1`: 68 numbered core verifications in `scripts/test/test_diagnostics.gd` (#1–#68).
  - `Tier 2A/2B`: 4G Test Track Baseline (6 geometry verification + 8 live ride simulation assertions).
  - `Tier 3`: 4K Technical Riding Lab (15 geometry & structure contracts).
  - `Tier 4`: 4L Gravel Training Loop (16 rhythm & Zen Flow contracts).
  - `Tier 5`: 4K T10 Ballistic Airborne & Landing Invariant Fixture (6 invariants: detachment, flight duration, ballistic curve, recontact, continuous path, suspension compression).
  - `Tier 6`: 5-Seed Procedural Determinism Battery (5 seeds match within $\Delta p \le 10^{-6}$ m; tangents and curvature use the same tolerance).
  - `Tier 7`: Multi-Scene Switching Memory Soak (7 transitions, 0 dangling nodes).
  - The runner attributes a tier's expected count when its subprocess exits with code 0; it does not collect individual assertion events from subprocess output. Treat 125 as an expected assertion budget, not a dynamically measured count.
- **Leak Gate**: The documented acceptance criterion is 0 ObjectDB leaks on exit across all runners.
- **Human Perception Gate**: 15 observed gameplay points conducted without F3 HUD, 3x repetition for critical mechanics, and Blind Human Perception Pass. Full report in `docs/sprints/sprint_4m_validation_report.md`.

---

## 5.1. Sprint 5 Mountain World & Road Contract Suites

**Latest world-generation run:** `test_fork_decision.gd` 212/212; `test_fork_geometry_verification.gd` 15/15; `test_branch_streaming.gd` 49/49; `test_road_graph.gd` 61/61; `test_road_grammar.gd` passed 5 seeds × 1000 chunks; `test_mountain_validation.gd` 12/12 across 60 traversed forks. RAM delta was +19.7–20.9MB across those 3 seeds (below the 25MB gate). Branch integration additionally verifies edge/centerline mapping, both route transitions and DAG continuity.

### C. Test Directory Map and Determinism Scope

- `test_sprint_4m_master.gd`: aggregate regression entry point; launches the core, 4G, 4K, and 4L suites and runs airborne, determinism, and scene-switch fixtures.
- `test_diagnostics.gd`: numbered system contracts #1–#68. It is a legacy, broad contract script, not a small unit-test file.
- `test_track_verification.gd`, `test_track_ride.gd`, `test_riding_lab.gd`, `test_gravel_loop.gd`: geometry and gameplay checks for fixed tracks.
- `test_road_contract.gd`, `test_road_grammar.gd`, `test_road_graph.gd`, `test_fork_decision.gd`, `test_fork_geometry_verification.gd`, `test_branch_streaming.gd`, `test_terrain_carver.gd`, `test_mountain_validation.gd`: targeted world-generation/branching suites; run individually when changing those systems.
- `test_airborne_empirical_gate.gd`, `test_airborne_calibration_gate.gd`: empirical physics calibration gates. `test_soak_run.gd` and `test_procedural_run.gd` are longer soak/procedural runs. `capture_*.gd` scripts capture screenshots; `test_*_generator.gd` and the `*_generator.gd` files provide test fixtures/generators.

**Determinism guarantee currently exercised:** in the same Godot runtime and with the same seed and same ordered sequence of chunk-generation calls, two independent `RoadLogic` instances are compared over 15 chunks for equal sample counts and position/tangent/curvature deltas no greater than `1e-6`. This does not establish cross-version bit identity or order-independent generation across branches. Foliage derives its RNG seed from world noise seed and chunk id; fork child seeds derive from parent seed, fork id, and branch index.

### A. Airborne Empirical Physics Gate (`scripts/test/test_airborne_empirical_gate.gd`)
Measures existing `BicycleController` dynamics over varied drop geometries without modifying bicycle kinematics:
* Measures air time, flight distance, touchdown vertical velocity $v_y$, and suspension deflection across heights $0.2 \dots 1.2$ m.
* Calibrates safety envelopes for `RoadAirborneContract`: `MICRO_DROP_MAX_HEIGHT = 0.35m`, `AIRBORNE_MAX_HEIGHT = 1.20m`.

### B. Road Contract & Validator Suite (`scripts/test/test_road_contract.gd`)
Runs full geometric validation against `RoadGenerationContract` (v5.1.0) and `RoadAirborneContract`:
```powershell
godot --headless --path . --script scripts/test/test_road_contract.gd
```
* **Synthetic Battery T01–T16**:
  * T01–T08 (Valid cases): straight, constant downhill $-6^\circ$, switchback $R=19$m, micro-drop, short airborne with landing, full airborne chain, downhill with crest drop, downhill with recovery straight.
  * T09–T16 (Invalid / Injected defects): uncontrolled gap (airborne without landing), excessive airborne length $>6$m, excessive drop height $>1.2$m, uphill landing, sharp landing curvature $R=18$m, missing landing FSM violation, sightline occlusion, and seam coordinate tear 5mm.
* **Procedural Multi-Seed Validation**: 15 chunks across 5 deterministic seeds (10101–50505) verified 100% compliant.
* **Micro-Benchmark**: 100 chunks (2500 samples, 5.0 km) validated in $\approx 7.6$ ms ($< 0.08$ ms per chunk).


---

## 6. Developer Debug HUD (F3 Key)
A developer overlay displaying live generation and bicycle telemetry:

```text
=== SLOW CYCLE DEBUG ===
Seed: 10101 | Chunk: #14 (Total generated: 42)
Active Chunks in Tree: 7
Speed: 23.4 km/h | Slope: -3.2° (Downhill) | Curve Radius: 58.2m
FPS: 84 | Frame Time: 11.9ms | Chunk Gen Time: 0.8ms
Memory: Static 48MB | VRAM 182MB
Surface: GRAVEL | Rough: 16% | Susp: -2mm | Mode: [CRUISE]
Lat Accel: 1.2 m/s² | Scrub: 0.0 m/s² [FLOW]
Road: CONTINUOUS [OK] | Raycasts: GROUNDED [OK]
========================
```
## P2.1c — Парный preview fork arms (2026-09-27)

`test_fork_corridor_preview.gd`: **15/15 PASS**. Проверены обе стороны, 26 production samples на рукав, приблизительно 50 м длины, сохранение стилей, повторяемая подпись, отказ на опасной terrain стороне для каждой ветки, отказ для одинаковой пары стилей и недопустимого grade, отказ при отсутствии terrain evaluator и повторяемость production `TerrainCarver` с seed `184729`.

Неизменённые регрессии после интеграции в `ChunkStreamer`: fork site planner **36/36** (включая forced preview reject/fallback); fork geometry **15/15**; route branch integration **8 маршрутов**; branch streaming **49/49**; road contract **18/18**; mountain validation **12/12** на 60 fork choices по seed `184729`, `42`, `99999`. В stress run peak RAM delta составил +20.1…+21.4 MB, ниже существующего 25 MB gate; streaming suite измерил commit chunk max 0.669ms, mean 0.471ms. `git diff --check` чистый.

Новая проверка меряет только fork-arm (~50 м), а не следующие grammar chunks или дальние crossing roads. Регрессии подтверждают, что настоящие fork meshes, route choices и streaming сохранились на указанной батарее. Godot продолжает выводить средовые ошибки записи `user://logs/godot.log` и чтения Windows certificate store; финальные завершённые runs не показали parser/assertion/leak warning. Реальный заезд на велосипеде автоматикой не заменён.
## P2.1d — Fork pacing trace (2026-09-27)

`test_fork_pacing_planner.gd`: **21/21 PASS** for pre-target wait, unsafe defer, first eligible endpoint, ordinal, 200m deferral window, fifth-candidate/over-200m overrun, no safety bypass, initial-vs-later pacing bands, malformed values, determinism and 64-record ring buffer.

Fresh integration results: `test_fork_site_planner.gd` **36/36** including paired-preview forced reject/fallback; paired preview **15/15**; fork geometry **15/15**; route branch integration **8 routes**; branch streaming **49/49**; road contract **18/18**; mountain validation **18 assertions / 60 fork choices / 3 seeds**, with active chunks ≤15, branches ≤3 and RAM increase +20.1…+21.4 MB.

Four seeded-default pacing records from integration (seeds `184729`, `42`, both branch choices) matched the generated fork distance. Targets were 591.0–820.7m, generated distances 600.3–851.1m and overshoot 9.3–33.3m; all fell in the diagnostic 550–900m band without overrun. This is four controlled route traces only. The mountain stress runner deliberately sets 100m intervals; its 314.6–317.6m first-candidate overrun reflects the 350m generation-ahead window under that artificial schedule, not normal production spacing. Safety behavior was preserved.

One batched route-integration execution printed `6 ObjectDB instances leaked`; isolated repeat exited 0 without reproducing it. It remains an unreproduced warning. Godot also continues to report the environment's log-file and Windows root-certificate errors. Do not describe either as fixed. The path follower does not establish human ride quality.
