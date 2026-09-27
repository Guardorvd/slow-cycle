# Slow Cycle — Architecture and Generation Boundaries

## 1. Purpose and source of truth

This document describes the current runtime contracts and the intended direction without presenting future systems as implemented. `DEVELOPMENT_ROADMAP.md` owns the full product path; `ROAD_GENERATION.md` owns geometry limits; `implementation_plan.md` owns the active task and its execution report; `TEST_PLAN.md` owns reproducible checks and measured outcomes. `AGENTS.md` and `.antigravity/rules/test-integrity.md` remain mandatory.

The product target is a meditative, continuous ride through a coherent mountain world. A quiet pace is supported by readable singletracks, meaningful FLOW/TECHNICAL choices, rideable MTB features, a convincing landscape, and reliable road/terrain collision. “Meditative” does not mean featureless straight road; route rhythm and mountain scenery are part of the same goal.

## 2. Current runtime ownership

```text
mode_select.tscn
└── main.tscn
    ├── WorldManager
    │   ├── owns world_seed and shared deterministic resources
    │   ├── MountainProfile (seed + route identity + arc distance)
    │   └── ChunkStreamer
    │       ├── branch lifecycle, chunk window and spawn schedule
    │       ├── ForkSitePlanner: pure preflight at a generated endpoint (P2.1a)
    │       ├── RoadGraph: fork nodes, LEFT/RIGHT edges and branch identity
    │       └── RoadChunk instances
    │           ├── RoadPathData → ArrayMesh and road collision
    │           ├── TerrainCarver → local roadside cross-section/terrain collision
    │           └── ChunkFoliage → chunk-local MultiMesh groups
    ├── Bicycle (stable public API)
    │   ├── CharacterBody3D movement and road/terrain ray queries
    │   ├── upright physical root; visual lean/pitch inside VisualsRoot
    │   └── telemetry_updated / bell_rung signals to observers
    └── HUD and audio observe player state/signals
```

### Runtime data flow

1. `WorldManager` selects the effective seed, initializes shared resources and creates the trunk `RoadPathData` plus `RoadLogic`.
2. `RoadGrammar` can export its current authored queue as a pure `RouteIntent`; `RoadLogic` still asks the seeded grammar for each phase, constructs a candidate centerline, applies the shared `MountainProfile`, and validates it before it is committed. `RoutePlan` records measured geometry/telemetry as data for planner tests. The streamer does not yet consume RoutePlan when generating production routes.
3. `ChunkStreamer` checks whether the generated horizon needs another chunk. Fork spacing remains a seeded minimum-distance schedule. Once that minimum is reached, `ForkSitePlanner` evaluates the available endpoint before any fork approach widening, graph mutation or fork mesh commit. Rejected sites take the ordinary chunk path; streaming retries on a later chunk boundary.
4. For an accepted site, existing `RoadLogic` queues a braking approach; the streamer widens the junction, constructs LEFT/RIGHT paths, registers graph edges, and commits `RoadChunk` meshes and colliders.
5. `ForkDecisionModel` compares the rider to those actual edge centerlines. `RoadGraph` is authoritative for the chosen edge and branch ID; `ChunkStreamer` still owns chunk lifetime, preloading and dormant branch state.
6. `RoadChunk` consumes committed road samples. `TerrainCarver` shapes local roadside strips from the same centerline plus seeded lateral relief. The current terrain is not a shared, open 2D mountain surface.
7. The bicycle observes world collision and its own telemetry signals. It does not participate in route generation and is not changed by P2.1.

## 3. Implemented contract versus target architecture

| Concern | Implemented now | Later target |
|---|---|---|
| Determinism | Stable world/profile/grammar/fork sub-seeds and deterministic geometry for the same seed/choice sequence | Keep deterministic independent streams as landscape, ecology and route planning expand |
| Large terrain shape | 1D `MountainProfile` contributes a bounded elevation overlay; `TerrainCarver` creates local roadside flanks | One shared seeded 2D mountain/valley/ridge field used by distant horizon, rideable terrain and trail planning |
| Route intent | FLOW and TECHNICAL have distinct authored openings; later grammar remains seeded | Plan leg composition, terrain corridor and both alternatives before committing fork topology/mesh |
| Planning data | `RouteIntent` exports the current queue and phase envelopes; `RoutePlan` stores measured intervals/profile/telemetry with stable signatures | Use measured intent/plan to preview paired branch corridors before mesh creation |
| Fork location | Seeded distance threshold, followed by endpoint preflight in P2.1 | Select among terrain/sightline/grade/clearance/composition-qualified candidate corridors |
| Geometry | `RoadPathData` and existing validator define continuous centerlines and local constraints | Route plan → C1 centerline and event geometry → validated road/terrain fit → chunk rendering/collision |
| Topology/streaming | `RoadGraph` owns fork choice; `ChunkStreamer` owns branch/chunk lifecycle | Migrate lifecycle incrementally only when graph-backed generation passes route and streaming gates |
| Graph history | Chunk/branch unload prunes graph nodes strictly behind the oldest live branch entry/fork reference and disconnects incident adjacency | Keep topology bounded to the live choice/streaming window; preserve every node reachable from pending decisions |
| World dressing | Per-chunk foliage MultiMesh groups use a positive 63-bit hash of stable route seed and quantized local arc-length bounds | Seeded ecology/secondary-trail network with exclusion corridors and measured budgets |

The target flow is deliberately ordered: a shared macro field gives a candidate route its context; route intent chooses a corridor and ride rhythm; the route graph fixes topology; centerlines and events are fitted and validated; terrain is fitted to those same coordinates; chunks materialize render and collision data; foliage is placed last with road/fork/sightline exclusions. Do not generate terrain and road independently and attempt to reconcile them with wheel raycasts.

## 4. P2.1 planner boundary

`ForkSitePlanner` is a pure evaluator, not a full network optimizer. It receives the currently available `RoadPathData`, candidate endpoint, prior-chunk validation result, existing `TerrainCarver`, and the `BRAKING_ZONE` sight distance supplied by `RoadGrammar`. It returns an eligibility flag, stable reason codes and measured metrics. It does not mutate path arrays, RNG state, graph topology, grammar state, meshes or colliders.

The initial gate checks the last 25 m for aligned/finite samples, sample spacing, standard road width, existing grade/curvature bounds and grounded contact. It checks both terrain-carver sides for the existing danger signal and verifies the actual braking phase has at least the contract sight distance. A rejection creates no fork side effects; the current 50 m chunk is generated normally, allowing a later endpoint to be reconsidered. It does not inspect yet-unbuilt downstream arms or promise a globally optimal route. Those remain later roadmap work and need separate evidence/acceptance criteria.

P2.1b adds two node-free data contracts. `RouteIntent` describes seed/branch/style identity, the global leg start, the current phase sequence and each phase's existing geometry envelope. `RoutePlan` stores actual interval bounds, observed geometry/contact/event metrics and explicitly sourced bike telemetry. Its builder rejects malformed paths; validators report stable reason codes for incomplete intent, intervals, metrics or telemetry. These records do not change generation behavior and are not yet a route optimizer.

P2.1c adds a deterministic paired preview before fork creation. `ForkArmGeometry` is the shared pure source for both the 50m fork arms and their production mesh input. `ForkCorridorPreviewPlanner` checks both seeded FLOW/TECHNICAL exits for finite/continuous geometry, legal grade/curvature/sample spacing, approach seam position/tangent, end separation, and terrain danger on both sides. `ChunkStreamer` runs this after site preflight and before graph/branch/mesh side effects; rejection follows the normal chunk path. Preview covers only the fork arms, not subsequent FSM chunks or distant route crossings.

P2.1d adds `ForkPacingPlanner` as a pure label/measurement step after the P2.1a/c safety decisions. The streamer logs each due chunk-end candidate to a bounded 64-entry in-memory trace with seed/branch/fork identity, target and candidate distance, generated-ahead distance, reject reasons and accept/defer result. The runtime retains the existing nearest-safe endpoint and seed-derived schedule. The 200m/four-rejection overrun is diagnostic; it never forces an unsafe fork. The route-wide planner and whole-network clearance gate remain incomplete.

## 5. Stable contracts and constraints

- `BicycleController` remains a stable API. Other systems may observe its documented properties/signals; world generation does not dictate internal kinematics.
- The physical bicycle root stays upright; presentation lean/pitch remains in `VisualsRoot`.
- Road geometry remains mathematically continuous under `RoadGenerationContract`; raycasts cannot hide geometric tears, normal flips or height steps.
- Every stochastic-looking world choice must derive from stable seed/key inputs. Candidate evaluation itself is deterministic and consumes no RNG.
- Foliage keys exclude global allocation IDs and materialization order. Keys are a 63-bit hash, so collisions are theoretically possible; the expanded key space makes accidental collisions negligible for current world windows.
- Keep one local MultiMesh per chunk/group for culling; never consolidate infinite-world foliage into one global MultiMesh.
- No gears, stamina, stunt scoring, inventory or unrelated gameplay loop is part of the world-generation scope.

## 6. Stage B event-to-surface boundary

Stage B checks that a generated MTB event survives each production handoff. In B1,
`RoadLogic.plan_next_chunk()` generates and validates AIRBORNE→LANDING geometry;
the subsequent queued recovery phase returns to grounded road. The test then feeds
the same `RoadPathData` to `RoadChunk.prepare_geometry_data()`, which is the
production source for road mesh arrays and road collision faces. Every airborne
and landing segment midpoint must be covered by those road triangles.

This is stronger than inspecting the grammar queue: it checks committed path data
and the mesh/collision preparation pipeline. It does not add runtime instrumentation
or change generation. It still does not instantiate a physics world, raycast against
the committed collider, simulate the bicycle, or establish how the feature feels;
those are later Stage B4/B6 checks. See `TEST_PLAN.md` for the measured seeds.

## 7. Stage B2 seeded ride rhythm

`RoadGrammar` now retains only the last 12 generated phase IDs (12 × 50 m ≈ 600 m).
Style profiles cap major events per rolling window: FLOW 2, BALANCED 3, TECHNICAL 4.
If ordinary choices leave eight feature-free chunks, the grammar schedules a gentle
crest instead of forcing a high-risk obstacle. After the authored opening, weights
also differ by route style; the seed still controls the concrete sequence. Recovery,
landing, and braking-before-major rules remain mandatory. The policy is a bounded
composition guide, not an exact percentage guarantee or a claim of subjective fun.

B2 changes the order and frequency of road features only. The current generator
still constructs the road and fits local terrain beside it; it does **not** first
create a random 2D mountain and then route the road across that landscape. Seeded
macro landforms and terrain-constrained route planning remain Stage C.

The main ride scene now requests a fresh positive world seed at session start;
`--seed=N` overrides it for exact replay. Test/tool `WorldManager` instances keep
their configured fixed seed unless they explicitly request session randomization.
The effective value remains visible in the existing F3 DebugHUD. Stage E still
owns user-facing seed selection and copy/replay controls.

## 8. Stage B3a event geometry baseline

`scripts/test/test_mtb_event_geometry_catalog.gd` measures the current production
builders through `RoadLogic.plan_next_chunk()` for crest/micro-drop, airborne plus
landing, switchback and recovery. It confirms validator acceptance and deterministic
replay while reporting actual point-to-point geometry; the airborne case additionally
requires accepted grounded recovery samples. It does not tune the builder, instantiate
the bike or establish perceived difficulty.

The baseline exposed one actionable documentation/geometry mismatch: the two marked
crest micro-drop samples span about 4 m and fall **0.552–0.608 m** across the four
catalogue seeds, while the builder comment states `h <= 0.35m`. Do not loosen the
validator to hide this. B3b owns the focused profile correction. The measured tangent
vs chord grade difference also remains evidence for B4's continuity audit.

## 9. Collision layers

The bicycle queries the existing road and surface layers through its configured collision mask. Road generation and physics contracts are coupled at the collision interface only; P2.1 does not edit that mask or tune wheel raycasts.

| Godot layer | Name | World purpose |
|---|---|---|
| 2 | Road | Packed road surface |
| 3 | Grass / terrain | Local roadside terrain and verge surface |
| 4 | Player | Bicycle character body |
| 5 | RoughRoad | Rough road surface |

## 9. Legacy feature traceability

The historic sprint ID alone does not imply that the full product goal is done.

| Backlog item | Status/scope | Roadmap placement |
|---|---|---|
| FEAT-014.4 Terrain Carving & Surface Physics | Completed local roadside cross-section, terrain collision metadata/surface integration. It is not open mountain terrain. | Foundation feeding Stage C; broader macro terrain work remains |
| FEAT-014.5 fork/branch streaming foundation | Completed graph choice and chunk lifecycle foundation; ownership is still split | Stage A/B foundation; lifecycle evolution remains incremental |
| P0/P1 and P2.0 | Current diagnostic/integration foundation, macro elevation overlay and distinct branch openings | Completed groundwork before Stage A/B |
| P2.1a | Terrain-aware eligible endpoint selection before fork generation | Stage A, current foundation slice; paired route planner remains open |
| FEAT-015.1 distant mountain horizon | Planned | Stage C: visual macro landscape |
| FEAT-015.2 open mountain downhill terrain | Planned | Stage C: continuous near/far mountain field |
| FEAT-015.3 mountain trails/singletracks | Planned; playable network must connect to route graph or be clearly decorative | Stage D after shared landscape and route corridors |
| FEAT-015.4 far terrain LOD/streaming | Planned | Stage C performance/completeness gate, then Stage G soak |

## 10. Entry points and references

- `project.godot` starts `res://scenes/mode_select.tscn`; `res://scenes/main.tscn` hosts the ride.
- Full product stages and intermediate build gates: `DEVELOPMENT_ROADMAP.md`.
- Geometry/event limits and P0–P2 behavior: `ROAD_GENERATION.md`.
- Current sprint plan and actual execution log: `implementation_plan.md`.
- Reproducible test commands, results and limits: `TEST_PLAN.md`.
- Current handoff summary: `MTB_WORLD_GENERATION_HANDOFF.md`.
