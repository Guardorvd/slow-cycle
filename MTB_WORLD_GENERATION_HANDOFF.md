# MTB World Generation — Handoff for the Next Chat

Updated: 2026-09-27. This file is the single starting specification for continuing the procedural MTB world work. Read it together with `AGENTS.md`; the analysis and implementation plan linked below retain supporting detail.

## 1. Product goal

Build an **arcade mountain-bike riding simulator** with rides that feel like descending a real, rideable singletrack: narrow packed trail, readable flow, turns and switchbacks, rollers, controlled jumps and landings, and forks where each option leads to a distinct ride. The current task is world generation and route design; art, textures and final scenery are explicitly later. Bike physics and camera are stable systems: preserve them unless a measured route defect requires a separately approved change.

## 2. What the earlier iterations got wrong

The original implementation mixed independent concerns without one integration contract:

1. `RoadLogic` generated a linear road in 50m chunks and `RoadGrammar` selected local phases. Neither planned the whole ride or assigned a route identity to alternatives.
2. `ChunkStreamer` inserted a repeated Y-fork based mainly on distance and owned both branch topology and branch lifetime.
3. `RoadGraph` described topology but was not the runtime source of truth.
4. `ForkDecisionModel` evaluated an analytic Y instead of the actual generated route centerlines.
5. Road widths and fork separation targets described a broad road, not the requested packed singletrack.
6. Tests proved local fork geometry, FSM and memory behavior independently. They did not prove that both generated routes matched LEFT/RIGHT semantics or had different riding rhythms. A master PASS was not evidence of a complete MTB ride.
7. `TerrainCarver` makes local roadside profiles; it is not a shared mountain surface/elevation model that all route alternatives fit into.

The detailed **pre-change snapshot** is `branch_generation_review.md`; it intentionally records old behavior and old measurements. Do not treat its old width/fork results as current.

## 3. Current implementation

The first reviewed vertical slice is implemented:

- Runtime forks create stable graph edges `0=LEFT`, `1=RIGHT`, each linked to its real `RoadPathData` centerline and branch ID.
- `ForkDecisionModel` uses those centerlines to score rider distance and heading. It retains its analytic model only for synthetic tests without generated route data.
- The graph edge chosen by the decision model drives the active branch transition.
- A deterministic seed assigns opposite `FLOW` and `TECHNICAL` styles to each fork's alternatives. These styles initialize distinct `RoadGrammar` phase sequences.
- A `BRAKING_ZONE` is queued before each fork, with mild approach grade, >=45m sightline, and smooth width expansion from 1.8m to 3.6m over the final 25m.
- Runtime singletrack profile is 1.8m nominal; branch lines narrow to 1.6m Flow / 1.35m Technical.
- RoadGraph continuity allows the two centerlines to begin within the shared junction radius while still enforcing tangent continuity.
- Fork intervals have seeded variation but are still distance scheduled. Fallback noise now derives its seed from `WorldManager.world_seed`.

Primary code: `scripts/world/chunk_streamer.gd`, `fork_decision_model.gd`, `road_graph.gd`, `road_logic.gd`, `road_grammar.gd`, `road_generation_contract.gd`, `road_math.gd`, `road_path_data.gd`, `road_chunk.gd`.

## 4. Current limits — do not overstate completion

- This is not yet a full procedural mountain route planner. No macro mountain, valley, ridge or drainage/elevation envelope exists.
- Fork placement is still a seeded distance schedule, not a location selected from terrain, sightline, trail bench and ride composition constraints.
- `ChunkStreamer` still owns branch lifecycle/preload dictionaries; graph topology now owns fork choice, but does not yet own complete route materialization.
- There are no merge nodes or route-level planner/scorer; branches continue as separate generated paths.
- Automated checks cover both graph choices and centerline traversal to next-fork materialization, but this is not a free-running bike ride or proof of arrival at the next decision node.
- Initial human greybox ride feedback has now been received, but it has not yet been reproduced systematically across known seeds/choice sequences. Passing geometry tests does not settle those questions.

## 5. Next work, in order

### P0 — Route-level acceptance before another generator rewrite — COMPLETED 2026-09-26

Implemented `scripts/test/test_route_branch_integration.gd`. For seeds `184729` and `42`, the harness runs both LEFT and RIGHT through the production choice model and registered graph centerlines, then advances along the selected generated centerline until the next fork is materialized. It records route length, elevation delta, grade/curvature ranges, contact-state sequence/counts, sample gaps, collision coverage, branch identity/style, and next-fork reachability. Two consecutive runs reproduced the same metrics; all four combinations passed.

Measured next-fork distance is about 451 m for LEFT/TECHNICAL and 150 m for RIGHT/FLOW for both tested seeds. Every sampled route point had solid collision coverage; maximum sample gap was 2.000–2.018 m. No AIRBORNE or LANDING state occurred in these segments. Detailed data and invocation are in `TEST_PLAN.md`.

Scope limit: this is a deterministic centerline follower that updates the real fork decision and streamer. It positions the rider at generated samples and is not a free-running bicycle-physics ride or human greybox playtest. The length split is repeatable but its relationship to the intended Flow/Technical experience is unresolved.

### P0.2 — Corrected fork-to-fork integration — COMPLETED 2026-09-26

The integration runner now owns a single streaming cadence, captures route style from the selected edge at choice time, compares a controlled 100 m post-choice schedule with the seed-assigned default, follows to within 20 m of the next fork, and drives along a real outgoing graph edge until the production model locks it. Eight routes passed; two complete runs reproduced the same metrics. Caveat: the controlled LEFT/primary fork was already materialized at measurement start because the road ahead had been buffered ~301 m, so its 300.9 m length is not a valid 100 m schedule measurement; the RIGHT/child route was not pre-materialized and measured 150.0 m. Seeded-default lengths: 851.0/650.1 m LEFT/RIGHT on seed 184729; 651.0/600.1 m on seed 42. Decision arrival distance was 16–18 m, selected edge/branch IDs matched, and centerline gap/collision checks passed. Full table is in `TEST_PLAN.md`.

Regressions passed: fork decision 212/212, geometry 15/15, branch streaming 49/49, mountain validation 12/12; the P0.1 diagnostic also passes 4/4 traces. No production files or existing assertions changed. Remaining caveat: the follower teleports along generated centerline samples, so bike dynamics/readability/fun still require a human greybox ride. Seeded-default distances vary widely and should be compared with a written route-pacing contract before altering schedule behavior.

### P0.3 — Spacing and composition proposal — COMPLETED 2026-09-26

Production schedule is 450 m ±12% to the first fork, then 700 m ±18% (574–826 m). The runtime checks spacing in 50 m chunks and also requires a safe validated chunk and less than 350 m of generated road ahead. Four seeded-default traces had assigned targets 591–821 m, actual distances 600–851 m and only 9–33 m overshoot, all below one chunk. Their local route origin matched `distance_at_last_fork`; none had pre-materialized the next fork. These results do not show a default-schedule bug.

The controlled 100 m LEFT/primary stress route is not a valid interval comparison: its next fork already existed at the route measurement start, 300.9 m ahead, due to the primary road buffer. The runner reports this explicitly. A draft pacing suggestion for the first 1–2 km greybox track is fork legs around 550–900 m, with similar length bands for both styles and the distinction expressed through turns, rollers, switchbacks and controlled drops. Existing safety limits remain: grade -14°…+5°, radius >=18 m, curvature <=0.0556 m⁻¹. Current two-seed samples do not establish reliable style-specific grade/curvature/airtime targets; they need a real ride and broader seed battery.

### P0.4 — Greybox ride and pacing decision

Player feedback received 2026-09-26 (reported observations; reproduction still pending):

- Runs appear to start on the same seed; the player suspects the seed pool is small. Determine whether the game fixes the seed, reuses a saved seed, or just repeats because of current selection behavior.
- First fork feels too far into the ride.
- The fork is visible from a distance, but the signs/markers around it feel cluttered.
- There is an empty gap between the left and right arms.
- The two routes feel alike; generation beyond gentle grades/straight roads is weak, especially harder ride features.
- Visual artifacts occur and the bike can fall through the surface.
- On one route, a line curls underneath a later fork and becomes impossible to ride through; likely a route crossing/clearance/collision issue, not yet localized.

P0.4 is now proposed as a **playability triage**, before general pacing polish: capture/reproduce the seed and choice sequence; prioritize the under-fork impassable route and fall-through; then review seed repetition, first-fork spacing, fork dressing/center gap and FLOW/TECHNICAL distinction. The player has already provided the initial qualitative review, so do not ask them to repeat it. Any production fixes need their own narrow implementation plan after the defect and files are identified. Preserve bike physics/camera unless a specific measured defect justifies a separate approval.

Diagnostic pass (2026-09-26): the main scene fixes seed `184729` (so repetition is a configured default, not a demonstrated small seed pool). The follow-up audit ran 12 forks per seed (`184729`, `42`) with LEFT-only and RIGHT-only decisions. At sampled centerline points, road-layer rays at center and ±0.5 m lateral offsets hit both before and after streaming updates; all four traversals had zero center misses with the original ±5 m ray height. The three earlier misses were not reproduced. No near non-connected centerline crossing candidates were found, but the exact reported under-fork route remains unreproduced because its seed/choice sequence/location is unknown. Thus no production collision defect is confirmed and no code-fix plan is opened. Source inspection counts two signs and eleven posts across a paired fork. Full measurements and limitations: `TEST_PLAN.md`.

### P0.1 — Branch length/style audit — COMPLETED 2026-09-26

Added `scripts/test/test_route_style_spacing_audit.gd`; it uses the real streamer, graph paths, and fork decision model, with one explicitly controlled streamer update cadence. It completed four traces (seeds `184729` and `42`, LEFT/RIGHT) with exit 0 and repeated consistently. Under this setup the primary/LEFT branch reached next-fork materialization at 300.9 m and the child/RIGHT branch at 150.0 m, regardless of assigned route style. This indicates that the observed disparity follows branch role/lifecycle in this diagnostic scenario rather than FLOW/TECHNICAL alone.

The earlier P0 integration harness called streamer updates both manually and via `WorldManager._process`; its 450.9/451.0 m LEFT measurements are cadence-sensitive and must not be used as an acceptance contract. Also, read style from the selected graph edge at choice time: generation of a later fork mutates runtime `branch.route_style`. Seed `42` was initially LEFT=FLOW / RIGHT=TECHNICAL; seed `184729` was LEFT=TECHNICAL / RIGHT=FLOW. The 100 m override in the audit is applied after choice, and a RIGHT fork may already have materialized by then. It does not establish production-default spacing. Chunks logged in the trace had `last_valid=true` and zero validator errors, but runtime does not expose rejected candidate history, so no fallback cause is asserted. The audit endpoint is fork materialization, not player arrival. Production source was untouched.

See `TEST_PLAN.md` and `implementation_plan.md`. P0.3 compared assigned and observed seeded-default distances and proposed an initial 550–900 m pacing band. The player has now given initial ride feedback; P0.4 focuses on reproducing the reported traversal/surface blockers and triaging the related usability findings.

### P1.0 — Seeded macro elevation envelope — COMPLETED 2026-09-26

Added `MountainProfile`, a pure O(1) analytic function of seed, route identity and arc distance. It returns elevation, grade, grade derivative and a macro region label. Seven seeds × three route identities passed 39,845 assertions; 12km descent measured 1070–1090m. P1.1 now wires it into runtime road and terrain generation. Full contract and limits are in `ROAD_GENERATION.md` §3.2–3.3 and `TEST_PLAN.md`.

The collision-hole isolation substep of P0.4 is complete but inconclusive: exact player route is still unknown. Continue capturing/reproducing the reported impassable route when available; do not let that block the broader landscape work or alter production code without a confirmed defect and its own plan.

### P1.1 — Integrate the macro profile with road and terrain — COMPLETED 2026-09-26

The profile now contributes a bounded height correction to trunk and fork-arm road samples before chunk validation/build. Fork arms share the seeded profile and global route distance, while the child arm accounts for its local centerline starting at the fork inner edge. Terrain far rows follow road centerline elevation and retain lateral shaping. The new integration runner passed 968 checks on seeds 184729 and 42; the existing road, fork, streaming, terrain, mountain-validation, and profile suites all passed without changing prior regression assertions. See `ROAD_GENERATION.md` §3.3 and `TEST_PLAN.md` for details and known environment messages.

The integration is a common macro envelope; branches still lack distinct elevation/route-intent budgets. Next prepare P2 for deterministic FLOW/TECHNICAL route planning and terrain-aware fork placement, then run an in-game ride review. Keep the unresolved exact under-fork traversal report in the diagnostic backlog; current clearance audits have not reproduced it and do not establish a production defect.

### P2 — Plan route intent and forks on that envelope

Plan alternatives before meshing: `FLOW` should trade length for sweeping turns/rollers and a steady descent; `TECHNICAL` should trade time/line choice for switchbacks, controlled drops and recovery. Place forks only where the planned approach supports sightline, width, grade and both outgoing corridors. Replace distance-only scheduling after these acceptance tests exist.

### P2.0 — Deterministic style opening — COMPLETED 2026-09-27

FLOW/TECHNICAL authored openings now differ in measured generated geometry on 4 world seeds and two style seeds per style. FLOW has two micro-drop events and no switchback; TECHNICAL has two opposite-turn switchbacks, recovery after each, and a micro-drop. The production route-intent runner passed 72 checks, with unchanged core suites also green. See `ROAD_GENERATION.md` §3.4 and `TEST_PLAN.md`.

**Next P2.1:** plan each pair of alternatives from route intent before mesh creation; select fork placement only when approach sightline/grade/width and both exit corridors pass measured thresholds. Keep seed determinism and current fork API; replace distance-only scheduling only after the planner has seed-battery evidence. Then arrange a manual bike ride on at least two seeds and both route choices.

**Separate defect plan needed:** the current `AIRBORNE_DROP` candidate is rejected by its existing validator (6.16–6.19m airborne length, 1.66–1.77m height in this opening) and falls back to recovery. Correct the generated lip/landing geometry while preserving airborne contracts; do not relax validator bounds. The user-reported under-fork traversal remains unreproduced and is a separate diagnostic item.

### P3 — Fit continuous centerlines and local terrain to the plan

Construct branch splines from shared junction constraints, then validate C0/C1 position/tangent, width transition, grade, curvature, jump/landing and collision seams. Extend terrain from a shared macro elevation field, not independent strips. Keep chunk creation as a downstream representation of immutable route data.

### P4 — Unify topology and streaming incrementally

Move branch materialization/lifecycle toward graph edge state without a risky all-at-once rewrite. Add graph merge nodes only when route pacing needs them. Remove duplicate topology state only after the new graph-driven path passes the P0 harness and stress tests.

### P5 — Human greybox review

Ride at least two seeds and both fork options in Godot. Evaluate: can the rider read a fork in time, is the difference between routes obvious from riding, are jump landings forgiving, and does the rhythm feel arcade-fun rather than random? Update parameter ranges from observed telemetry and rider feedback.

## 6. Acceptance gates

- Deterministic route data and foliage for the same seed and same choice sequence; no dependence on branch materialization order.
- Both fork options are physically continuous, recognizable from the approach, traversable to their next decision, and have a distinct measured ride profile.
- Validated grade, curvature, visibility, width and airborne/landing envelopes along the complete ride, not just one 50m chunk.
- No geometry/mesh/collision seams; streamer memory remains within an explicit soak limit.
- At least two-seed human greybox review confirms readable, enjoyable flow. Automated PASS alone is insufficient.

## 7. Test commands and latest known results

Project root: `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar`

Godot console: `C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe`

Run from the project root in PowerShell:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/test_fork_decision.gd
```

Replace the test script for `test_fork_geometry_verification.gd`, `test_branch_streaming.gd`, `test_road_graph.gd`, `test_road_grammar.gd`, `test_mountain_validation.gd` or `test_sprint_4m_master.gd`.

Latest completed results: fork decision 212/212; fork geometry 15/15; branch streaming 49/49; road graph 61/61; grammar battery 5 seeds × 1000 chunks; mountain stress 12/12 across 60 forks with RAM delta +19.7–20.9MB; master-runner all seven tiers PASS, expected budget 125/125. The master runner credits expected counts on successful process exit; 125 is a budget, not a collected assertion count. Godot emitted environment warnings for `user://logs/godot.log` and the Windows root-certificate store; test processes exited 0.

## 8. Repository operating rules

- `AGENTS.md` is authoritative: deterministic by seed, mathematical continuity first, preserve bike/camera APIs and controls, minimal changes, no unrelated gameplay, test with Godot.
- For multi-file/architectural work, maintain `implementation_plan.md` and obey its plan approval gate. The previous broad plan is in this repository, but in a new chat make sure the user explicitly authorizes the next implementation scope before editing if approval is not present in that chat context.
- `.antigravity/rules/test-integrity.md` protects test integrity. Tests were changed in the prior feature because singletrack dimensions and graph-driven branch choice changed the intended contract; assertions were updated to verify the new dimensions/real branch mapping, not weakened to hide defects.
- Do not change bicycle physics, camera, controls, or art assets while implementing the next world-generation stage unless measurements show a specific conflict and the user approves that scope.

## 9. Helpful project documents

- `branch_generation_review.md` — old architecture/root-cause review.
- `implementation_plan.md` — approved implementation plan and honest execution report/remaining scope.
- `ROAD_GENERATION.md` — current geometric and runtime fork contract.
- `ARCHITECTURE.md` — runtime module relationships and fork ownership.
- `TEST_PLAN.md` — test inventory and recorded run results.
- `AGENTS.md` and `.antigravity/rules/test-integrity.md` — mandatory contributor/test directives.

### Prompt to resume in a new chat

“Read `MTB_WORLD_GENERATION_HANDOFF.md`, `AGENTS.md`, `.antigravity/rules/test-integrity.md`, `implementation_plan.md` and `ROAD_GENERATION.md`. P0–P0.3 are complete. Review proposed P0.4 in `implementation_plan.md`; do not begin it until the user explicitly approves it. Preserve bicycle physics and camera, and follow the plan approval gate for later multi-file work.”
