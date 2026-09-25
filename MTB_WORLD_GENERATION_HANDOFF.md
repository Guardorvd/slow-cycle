# MTB World Generation — Handoff for the Next Chat

Updated: 2026-09-25. This file is the single starting specification for continuing the procedural MTB world work. Read it together with `AGENTS.md`; the analysis and implementation plan linked below retain supporting detail.

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
- Automated checks cover both graph choices and stress traversal, but do not yet automatically ride each distinct branch centerline from fork to the next fork and score the whole route.
- No human greybox ride/playtest has been performed for flow, readability, fun, or difficulty. Passing geometry tests does not settle those questions.

## 5. Next work, in order

### P0 — Route-level acceptance before another generator rewrite

Create a deterministic integration harness for at least two seeds. Generate one fork, drive the actual choice model down each generated centerline, traverse the chosen branch to its next fork, and record length, elevation delta, grade/curvature ranges, airborne/landing sequence, collision continuity, and branch identity. Confirm that the two alternatives produce measurably different ride profiles. Keep the physics unchanged; if the rider cannot traverse a valid route, capture telemetry and identify the exact geometry conflict first.

### P1 — Define the mountain/elevation envelope

Add a deterministic, seed-keyed macro profile for a descent (ridge/bench/valley segments, elevation budget, safe grade and visibility windows). Keep it pure data/math, independent of meshes and streaming. Test exact repeatability for the same seed and continuity at all macro segment boundaries.

### P2 — Plan route intent and forks on that envelope

Plan alternatives before meshing: `FLOW` should trade length for sweeping turns/rollers and a steady descent; `TECHNICAL` should trade time/line choice for switchbacks, controlled drops and recovery. Place forks only where the planned approach supports sightline, width, grade and both outgoing corridors. Replace distance-only scheduling after these acceptance tests exist.

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

“Read `MTB_WORLD_GENERATION_HANDOFF.md`, `AGENTS.md`, `.antigravity/rules/test-integrity.md`, `implementation_plan.md` and `ROAD_GENERATION.md`. Continue with P0 only: build a real integration harness that traverses both generated branch centerlines to the next fork and reports route metrics. First inspect the current branch and working tree. Preserve bicycle physics and camera. Follow the plan approval gate if the new chat does not inherit the prior approval.”
