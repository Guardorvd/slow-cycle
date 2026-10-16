# Independent System Architecture & Health Audit Report (Agent B)

**Document Reference:** `outputs/independent-audit/2026-10-14/B_SYSTEM_HEALTH.md`  
**Date:** 2026-10-14  
**Operating Revision:** `master @ e7730caf60807300bff8323af45ca2d00d94a443`  
**Auditor:** Agent B — System Architecture & Health Auditor  
**Audit Scope:** Subsystems S1 through S14 against `docs/TARGET_ARCHITECTURE.md` and related roadmaps  
**Operating Mode:** READ-ONLY AUDIT (no modifications to production code, no commits, no pushes)

---

## 1. Executive Summary & Architectural Context

This audit provides an independent architectural evaluation of **Slow Cycle** at revision `e7730ca` (following the completion and Director acceptance of BC2 — Procedural Natural Trail Network).

### Key Architectural Findings
1. **Target Architecture Realization (World First → Route Second → Road Third):**
   The architecture has completed its fundamental shift away from the legacy road-dominated paradigm (`TerrainCarver` carving a 38-meter strip around a 1D DAG `RoadGrammar`) to a world-first, region-centric architecture. S1 (Identity), S2 (Macro Geography), S3 (Hydrology & Biomes), and S6 (FinalSurface) now form an authoritative, immutable stack.

2. **The B+C Route Realization Pivot (BC1/BC2 Success):**
   The transition defined in `docs/TARGET_ARCHITECTURE.md §8` and `docs/ROADMAP_B_C_ROUTE_REALIZATION.md` has successfully decoupled natural paths from the heavy, brittle `RoadSynthesizer` (R6). `TrailNetworkPlanner` and `TrailRealization` (S7) construct SINGLETRACK and TECHNICAL routes directly upon the **published ground** (`FinalSurface.published_ground`), honoring principles S1–S7. This provides functional route variety, linked turns, and steep descents without requiring road deformation or complex spline solvers.

3. **System Health Status Breakdown:**
   - **8 Subsystems are Fully Working & Healthy:** S1 (Identity), S2 (Geography), S3 (Hydrology/Biomes), S6 (FinalSurface), S7 (Natural Trails), S8 (Unified Network), S12 (Bicycle Gameplay), S13 (UI/Audio).
   - **1 Subsystem has a Genuine Defect / Known Failure:** S5 (`RoadSynthesizer` — S3 curvature oracle failures on junction movements).
   - **3 Subsystems carry Technical Debt:** S4 (`RoutePlanner` — R5 singletrack/technical planning redundancy), S9 (`RegionBake` / `RegionBakeCache` — cold bake duration), S10 (`RegionWorld` / `RegionStreamer` — planar water rendering, rudimentary border walls, owed soak tests).
   - **2 Subsystems are Frozen Legacy / Test Infrastructure:** S11 (Vegetation/Bridges — procedural primitive placeholders awaiting BC3/BC4 art), S14 (Legacy World & Test Harnesses — preserved for backward compatibility and verification).

---

## 2. Consolidated System Health Matrix

The matrix categorizes all 14 active subsystems by health status, concrete evidence, operational risk, minimal improvement path, effort, and phase ownership.

| System | Status | Evidence | Risk | Small Improvement | Effort | Owner / Phase |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **S1. World Identity & Seed Management** | **HEALTHY / WORKING** | `test_region_domain_skeleton` 145/145 PASS; SHA-256 seed derivation deterministic. | Low. Pure domain data, zero external dependencies. | None. Do not touch. | None | Core Architecture / Frozen |
| **S2. Macro Geography & Terrain** | **HEALTHY / WORKING** | `test_macro_geography` 4,269/4,269 PASS; `test_terrain_tile_contract` 2,178/2,178 PASS; 252k region sweep clean. | Low. Minor edge hollows (~1-2% seeds). | None immediate. Add bench/platform shaping in BC3 for switchbacks. | Medium | World Gen / BC3 |
| **S3. Hydrology & Environment Fields** | **HEALTHY / WORKING** | `test_hydrology_contract` 299/299 PASS; R4 suite 29,791/29,791 PASS; monotone river profiles. | Low. Upland flat creeks occasionally rectilinear. | None. Keep query contracts stable. | None | World Gen / Frozen |
| **S4. Regional Route Planning (R5)** | **TECH DEBT** | `test_route_network` 2,235/2,235 PASS; holdout 32/32 valid. Seed 2024 produces 0 loops (backlog N-6). | Medium. Singletrack/Technical logic in R5 is redundant with BC2 planner. | Defer singletrack/technical corridor generation in R5 to save bake time; keep R5 for engineered roads. | Small | Route Planning / BC3 |
| **S5. Road Synthesis (R6)** | **KNOWN DEFECT / DEBT** | Contracts 72/72 PASS; `test_road_synthesis --group=regions` 184729 has 10 × `oracle_path_move:*` curvature failures (S3 OPEN). | Medium. High solver complexity; junction movements exceed mainline curvature limits. | Scope curvature oracle tolerance specifically for junction movements (`kind == "MOVEMENT"`). | Small | Road Synthesis / Director Decision |
| **S6. FinalSurface (R7)** | **HEALTHY / WORKING** | `test_final_surface --source=fixture` 1,424/1,424 assertions PASS, 0 failures; raycast checks 43,644/43,644 clean. | Low. Solid implementation of Target Architecture S1–S7 principles. | None. Maintain bit-exact published ground queries. | None | Surface / Frozen |
| **S7. Natural Trails (BC1/BC2)** | **HEALTHY / WORKING** | `test_bc2_trails` 31/31 PASS (4.4s); Director accepted c1, c2, c3 playtests on 184729 & 3628391; zero traps. | Low. Valley floor singletrack has mild relief (N-3); technical turns are S-bends (N-5). | None for BC2. Switchback platforms and nature loops belong to BC3. | Medium | Route Realization / BC3 |
| **S8. Unified Route Network** | **HEALTHY / WORKING** | `test_region_network` 14/14 PASS (0.01s); `RealizedRoadNetwork.trail_graph` trap detection verified; atomic publication. | Low. Clean fixed-point component filtering. | None. Schema /2 is stable. | None | Network / Frozen |
| **S9. Region Bake & Cache** | **TECH DEBT (PERF)** | Disk cache hit loads in 1.3–2.0s; fresh cold bake takes 600–1000s; fast path (`fast_trail.gd`) runs in ~90–140s. | Medium. Long cold-bake duration slows full validation; D-5 (1 vs N thread determinism) owed. | Keep cache key schema strict; run owed D-5 determinism sweep under DEEP governance. | Small | Pipeline / DEEP Backlog |
| **S10. Runtime & Streaming** | **TECH DEBT / WORKING** | Dynamic 64m collision patches (1 commit/frame); water recovery operational; clean cache spawn. | Medium. DEEP soak runs owed (D-2); lake/pond visual presentation is planar; border wall is basic. | Add animated water surface shader and softer terrain border blend in BC3/BC4. | Medium | Runtime / BC3-BC4 |
| **S11. Vegetation & Bridges** | **TECH DEBT / WORKING** | Per-tile stateless hashing; road/trail clearance masks verified; bridge deck collisions active. | Low. Flora meshes are simple procedural primitives (cones/cylinders). | Replace procedural primitive meshes with artistic MultiMesh assets in BC3/BC4. | Medium | Art & Environment / BC3-BC4 |
| **S12. Bicycle Gameplay** | **HEALTHY / KEEP** | `test_ride_envelope` 204/204 PASS; surface weight blending responsive; stable downhill physics. | Low. Steep descent dark slab in FPV (N-4). | Adjust FPV camera pitch offset or bike mesh clip plane on steep descents (N-4). | Small | Player / Ergonomics Backlog |
| **S13. UI, Audio & Session** | **HEALTHY / WORKING** | ModeSelect (1-5) fully operational; HUD telemetry throttled (20 Hz); Q2B AudioServer teardown diagnosed. | Low. Audio instances delayed teardown handled by test settle (250ms). | None in production. Keep 250ms test settle. | None | UI & Audio / Frozen |
| **S14. Legacy & Test Harness** | **TECH DEBT / FROZEN** | Manifest OK (66 suites, 209 rows); `sc_verify.py` functional; legacy world isolated in option 1. | Medium. Legacy chunk streamer / terrain carver code remains in tree. | Do not refactor legacy code. Maintain read-only boundary until formal deprecation gate. | None | Test & Legacy / Migration Gate |

---

## 3. Detailed Subsystem Audits (S1 through S14)

### Subsystem S1: World Identity & Seed Management
* **What it actually does:** Defines the identity of any point in the world. Generates distinct, deterministic 64-bit seed values for each procedural domain (`macro_structure`, `macro_noise`, `hydrology`, `biome`, `route`, `road_synthesis`, `vegetation`) from `(world_seed, region_coordinate)` using SHA-256 preimages (`ALGORITHM_TAG = slow_cycle.seed/1`). Defines integer world bounding boxes (4096m squares).
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_identity.gd`, `region_bounds.gd`, `region_seed_derivation.gd`, `region_plan.gd`.
  - Owner: `RegionIdentity` owns coordinate identity; `RegionBounds` owns world extents; `RegionSeedDerivation` is a pure static domain service.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `world_seed: int`, `region_coordinate: Vector2i`.
  - Outputs: `RegionIdentity`, `RegionBounds`, seeded sub-purposes, `RegionPlan`.
  - Dependencies: Zero external dependencies; pure RefCounted objects.
* **Conformance with Target Architecture:** 100% compliant with §§1–3. Zero scene tree or Node dependencies; explicit seed derivation prevents hidden state sharing.
* **Defects & Failure Modes:** None discovered. Handles negative coordinates, non-finite bounds checks, and integer overflows cleanly.
* **Hidden Coupling / Duplication:** None.
* **Adequacy of Tests:** High. `test_region_domain_skeleton.gd` exercises 145 checks with 0 failures across diverse coordinate spaces and world seeds.
* **Necessity & Path of Improvement:** None. Strictly keep as-is.

---

### Subsystem S2: Macro Geography & Terrain
* **What it actually does:** Implements the `MOUNTAIN_RIVER_VALLEY` archetype. Creates the major valley floor axis, floodplain basin opening, mountain crest polylines (summits, saddles, shoulders), descending spurs, and far-side hill ridges. `TerrainField` provides the single world-space base query interface (height, gradient, normal, lattice blocks). `TerrainTileRenderer` generates seamless 512m ArrayMesh tiles with shared boundary vertices.
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_generator.gd`, `macro_geography_generator.gd`, `macro_terrain_evaluator.gd`, `macro_terrain_plan.gd`, `terrain_field.gd`, `terrain_tile_renderer.gd`.
  - Owner: `MacroTerrainPlan` owns the macro geographic parameters; `TerrainField` owns the public base query surface.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RegionIdentity`, `RegionBounds`, derived seeds.
  - Outputs: `MacroTerrainPlan`, `TerrainField`, ArrayMesh arrays.
  - Dependencies: Godot `FastNoiseLite` for bounded high-frequency noise.
* **Conformance with Target Architecture:** Fully compliant with §§1–2 (world-first geography prior to route selection; renderer does not own elevation).
* **Defects & Failure Modes:**
  - Known accepted debts from R1: ~2% buried passes in extreme crest seeds, ~1% closed hollows from steep slope intersections.
  - Architecture note: Floating-point precision differences between Godot's main thread and worker threads (`exp`/`pow` in MSVC C-runtime) can alter heights by ~1e-13m if evaluated across thread contexts. Mitigated by `RoadSynthesizer.off_main_thread`.
* **Hidden Coupling / Duplication:** `MacroTerrainEvaluator` contains private evaluation logic; `TerrainField` cleanly wraps it. Legacy `MountainMassifField` exists in `scripts/world/`, but is completely unreferenced by the region stack.
* **Adequacy of Tests:** Very thorough. 4,269 assertions in `test_macro_geography.gd`, 2,178 in `test_terrain_tile_contract.gd`, 252,000-region automated sweep in R1 review.
* **Necessity & Path of Improvement:** Working system. Improvement opportunities (switchback platforms, faceted rock walls) belong strictly to BC3.

---

### Subsystem S3: Hydrology & Environment Fields
* **What it actually does:**
  - Hydrology: Models a major river along the valley axis with seeded meanders, water surface monotonically decreasing downstream, 32m drainage routing lattice, perennial and ephemeral channel networks with Strahler orders, and water bodies (ponds, lakes, outlets).
  - Ecology: `EnvironmentContext` integrates base terrain and hydrology signals. `BiomeField` computes continuous weights (CONIFER, MEADOW, RIPARIAN, AUTUMN) and woody cover. `RideabilityField` evaluates traversal resistance and marks natural barriers (deep water >= 0.35m, cliffs >= 100% slope).
* **Main Files & State Owner:**
  - Files: `scripts/world/region/hydrology_generator.gd`, `hydrology_plan.gd`, `hydrology_field.gd`, `hydrology_surface.gd`, `drainage_routing.gd`, `environment_context.gd`, `biome_field.gd`, `rideability_field.gd`.
  - Owner: `HydrologyPlan` owns water truth; `BiomeField` owns ecological weights; `RideabilityField` owns traversal costs.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RegionPlan`, `TerrainField`.
  - Outputs: `HydrologyPlan`, `HydrologyField`, `EnvironmentContext`, `BiomeField`, `RideabilityField`.
  - Dependencies: S1, S2.
* **Conformance with Target Architecture:** Fully compliant with §§1–2. Water and biomes emerge naturally from macro geography, not from distance to road.
* **Defects & Failure Modes:** In very flat upland plateaus, tributary drainage channels can exhibit mild rectilinear stepping due to the 32m drainage lattice.
* **Hidden Coupling / Duplication:** `HydrologySurface` was created in R3 as a transitional base+water query layer for R5/R6 before R7 `FinalSurface` was built. It remains utilized by `RoutePlanner` during planning raster creation.
* **Adequacy of Tests:** Strong. `test_hydrology_contract.gd` (299 checks), R4 environmental suite (29,791 checks), 64-region holdout tests.
* **Necessity & Path of Improvement:** Working system. Do not touch.

---

### Subsystem S4: Regional Route Planning (R5)
* **What it actually does:** Plans regional route corridors. Generates a 32m raster of traversal costs, finds topographic anchors (passes, benches, side-valley heads, lake shores), traces a valley backbone connecting valley-end gateways, and identifies candidate loops, shortcuts, and spurs. Assembles `RegionRouteGraph` with certified `RouteCorridor` boundaries and junction zones.
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_route_graph.gd`, `route_planner.gd`, `route_planning_raster.gd`, `route_search.gd`, `route_anchor_finder.gd`, `route_journey_scoring.gd`, `route_corridor_builder.gd`.
  - Owner: `RegionRouteGraph` owns corridor topology and journey classifications.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RegionPlan`, `TerrainField`, `HydrologyPlan`, environmental fields.
  - Outputs: `RegionRouteGraph` (nodes, edges, corridors, loops, anchors).
  - Dependencies: S1–S3.
* **Conformance with Target Architecture:** Conforms to network topology goals (§4). However, R5 was originally designed to plan all 4 classes (Backbone, Secondary, Singletrack, Technical). In practice, R6 could only synthesize engineered roads, which led to the B+C amendment where Singletrack and Technical routes are planned by S7 (`TrailNetworkPlanner`).
* **Defects & Failure Modes:**
  - On regions with simple topography (such as seed 2024 with a single straight valley), R5 cannot find secondary loops or alternative paths, resulting in 0 road loops (backlog N-6).
  - R5 route search takes 15–20s to rasterize and search, which multiplies during feedback replans in `RegionNetworkBuilder`.
* **Hidden Coupling / Duplication:** R5 includes candidate generation and corridor building for `SINGLETRACK` and `TECHNICAL` classes which are largely bypassed or excluded by `RegionNetworkBuilder` and replaced by S7 in `RegionBake`.
* **Adequacy of Tests:** Robust for corridor validation (`test_route_network.gd` with 2,235 assertions; 32-seed holdout validation).
* **Necessity & Path of Improvement:** Technical debt. Safest improvement: restrict R5 candidate searches to BACKBONE and SECONDARY classes, formally delegating natural singletrack and technical paths to S7.

---

### Subsystem S5: Road Synthesis (R6)
* **What it actually does:** Synthesizes continuous, 3D engineered road alignments within R5 corridors for BACKBONE and SECONDARY roads. Implements dynamic programming lattice search, G2 quintic Hermite splines, horizontal fairing, vertical grade profile fitting, shared junction patches (D3), and bounded roadbed intents (CUT, FILL, SHELF).
* **Main Files & State Owner:**
  - Files: `scripts/world/region/road_synthesizer.gd`, `road_alignment_designer.gd`, `road_junction_planner.gd`, `road_feasibility_validator.gd`, `road_corridor_geometry.gd`, `road_synthesis_plan.gd`, `road_synthesis_policy.gd`, `roadbed_intent.gd`.
  - Owner: `RoadSynthesisPlan` owns the synthesized piece geometries and roadbed intents.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RegionRouteGraph`, `RegionPlan`, `TerrainField`, `HydrologyPlan`.
  - Outputs: `RoadSynthesisPlan` (READY, PARTIAL, or REJECT).
  - Dependencies: S1–S4.
* **Conformance with Target Architecture:** Target Architecture §2 explicitly states: *"R6 LIMITED ALPHA ACCEPTED 2026-10-10 (certified R7/R8 handoff route only; full regional network NOT READY)"*. R6 was acknowledged as too heavy and brittle for natural trails, directly motivating the B+C pivot.
* **Defects & Failure Modes:**
  - **Known Failure S3 (OPEN):** `test_road_synthesis --group=regions` on seed 184729 triggers 10 `oracle_path_move:*` curvature failures on junction movements (`move:3:2-3`, etc.). The test oracle applies the mainline road minimum radius check to junction turning arcs, which naturally require tighter radii.
  - High algorithmic complexity: Frequent PARTIAL synthesis outcomes requiring R5 replanning loops.
* **Hidden Coupling / Duplication:** Overlaps in kinematic validation between `RoadFeasibilityValidator` and `road_synthesis_oracle.gd`.
* **Adequacy of Tests:** Contracts group passes 72/72 (`test_road_synthesis.gd --group=contracts`). Region testing blocked by known failure S3.
* **Necessity & Path of Improvement:** Genuine defect / test oracle mismatch.
* **Smallest Safest Improvement:** Update `road_synthesis_oracle.gd` to relax the curvature check for junction movements (`kind == "MOVEMENT"`), or formally document an approved waiver from the Game Director as recorded in `docs/BACKLOG_ACTIVE.md`.

---

### Subsystem S6: FinalSurface (R7)
* **What it actually does:**
  - The authoritative, unified owner of all physical world elevation.
  - Mathematically composes: `BaseTerrain + Hydrology + Road Deformation (ENGINEERED) + SHAPED Trail Modifications (BENCH)`.
  - `RoadTerrainDeformer` cuts, fills, and shelves terrain along engineered road pieces.
  - `FinalSurfaceTileRenderer` tessellates 8x8 tiles (512m each, 16m lattice with adaptive subdivision around roads and trails).
  - Implements `with_trails()` and `with_published()`: redirects elevation queries in trail corridors to the actual published mesh triangles.
  - Implements `published_ground()`: generates a 4m raster of actual published mesh triangles for downstream trail planning.
* **Main Files & State Owner:**
  - Files: `scripts/world/region/road_terrain_deformer.gd`, `final_surface.gd`, `final_surface_tile_renderer.gd`, `regional_road_math.gd`, `certified_road_route.gd`.
  - Owner: `FinalSurface` is the single state owner of final ground elevation for render, collision, vegetation, and recovery.
* **Inputs, Outputs, Dependencies:**
  - Inputs: Base terrain (`TerrainField`), hydrology (`HydrologyField`), realized road network (`RealizedRoadNetwork`), trail records (`TrailRealization`).
  - Outputs: `FinalSurface` query instance, tile ArrayMeshes, collision triangle arrays, per-triangle collision layers (Road 2, RoughRoad 2|16, Terrain 4).
  - Dependencies: S2, S3, S5, S7.
* **Conformance with Target Architecture:** Exemplary conformance to Target Architecture §5 and §8 (Principles S1–S7). Resolves the historic issue where collision and rendering diverged from design splines.
* **Defects & Failure Modes:** Off-road coarse 16m cells linearly interpolate across gullies, diverging from analytic `sample_height()` by up to 3.6m. This was resolved for trails via `with_published()`, but general off-road free-riding parity remains a BC3 goal.
* **Hidden Coupling / Duplication:** None.
* **Adequacy of Tests:** Outstanding. `test_final_surface.gd --source=fixture --group=contracts` executed cleanly with 1,424 assertions and 0 failures. 43,644 registered rays, 0 misses.
* **Necessity & Path of Improvement:** Working system. Maintain read-only stability.

---

### Subsystem S7: Natural Trail Generation (BC1 / BC2)
* **What it actually does:** Procedurally discovers, plans, and realizes natural trails on the published ground.
  - SINGLETRACK: Finds road-to-road pairs where a natural path provides an advantageous detour across meadows or hillsides. Searches a 16-connected A* lattice on the 4m published ground, smooths with corner cutting, and verifies grade (<=10°), cross-slope (<=0.35), and radius (>=8m). Ridden both directions.
  - TECHNICAL: Identifies high-to-low pairs with steep relief drops (>=12m, >=9% drop). Traces directed descents, injects linked turn shapes (sine perturbations with R ~ 7–15m), and validates as one-way descents (FORWARD only, slope up to 15°, forward climb <=0.095, radius >=6m).
  - SHAPED (BENCH): Implements single traverse benches on side-slopes (length <=60m, |displacement| <=0.30m, volume <=30m³).
* **Main Files & State Owner:**
  - Files: `scripts/world/region/trail_network_planner.gd`, `trail_policy.gd`, `trail_realization.gd`.
  - Owner: `TrailNetworkPlanner` proposes; `TrailRealization` validates and owns line/operations; `FinalSurface` owns geometry; `RealizedRoadNetwork` owns connectivity.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RealizedRoadNetwork`, `FinalSurface.published_ground`, `HydrologyField`, trail configuration JSON.
  - Outputs: `TrailRealization` records, published trail lines, HUD network summaries.
  - Dependencies: S6, S8.
* **Conformance with Target Architecture:** Fully realizes the B+C amendment (`docs/TARGET_ARCHITECTURE.md §8`). Proves that natural trails can be generated robustly without roadbed deformation or heavy spline solvers.
* **Defects & Failure Modes:**
  - Backlog N-3: Singletrack lines on seed 184729 follow valley floors and lack dramatic relief.
  - Backlog N-5: Technical descent turns are S-bends rather than true hairpin switchbacks (which require shaped turn platforms).
  - Backlog N-6: On seeds with 0 or 1 road loops (2024, 3628391), Singletrack cannot find valid alternative pairs. Accepted as-is by Director (decision D-C3 = A).
* **Hidden Coupling / Duplication:** Clean. Separates policy parameters (`trail_policy.gd`) from realization verification (`trail_realization.gd`).
* **Adequacy of Tests:** Excellent. `test_bc2_trails.gd --group=domain` runs in 4.4s with 31 checks, 0 failures. Playtests accepted by Game Director across checkpoints c1, c2, and c3.
* **Necessity & Path of Improvement:** Working system. Enhancements (nature loops, switchback platforms) belong strictly to BC3.

---

### Subsystem S8: Unified Route Network
* **What it actually does:** Merges engineered road pieces and realized natural trails into a single published network model.
  - `RegionNetworkBuilder`: Orchestrates R5 <-> R6 feedback replanning loops (up to 2 replans) to resolve roadbed conflicts and maximize network score.
  - `RealizedRoadNetwork`: Enforces fixed-point connected component filtering, validates descent return paths, and publishes schema `/2`.
  - `RealizedRoadNetwork.trail_graph`: Analyzes directed graph reachability, loop counts, fork vertices, trail crossings, and guarantees no traps (`ERR_TRAIL_TRAP`).
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_network_builder.gd`, `realized_road_network.gd`.
  - Owner: `RealizedRoadNetwork` is the single authority on published route network data.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RoadSynthesisPlan`, `RegionRouteGraph`, `TrailRealization` records.
  - Outputs: `RealizedRoadNetwork` serialized data, connectivity metrics.
  - Dependencies: S4, S5, S7.
* **Conformance with Target Architecture:** Conforms to §2 and §8. Ensures only fully connected, rideable routes reach runtime and bake caches.
* **Defects & Failure Modes:** If R6 completely fails all synthesis attempts, network builder returns `NETWORK_FAILED`. Handled gracefully in `RegionBake`.
* **Hidden Coupling / Duplication:** None.
* **Adequacy of Tests:** Strong. `test_region_network.gd --group=domain` passes 14/14 checks in 0.01s.
* **Necessity & Path of Improvement:** Working system. Maintain as-is.

---

### Subsystem S9: Region Bake & Cache
* **What it actually does:**
  - `RegionBake`: The monolithic pure-data orchestrator for offline/worker generation. Sequentially coordinates upstream generation, network builder, deformer, tile renderer, published ground extraction, trail planning/publication, bridge generation, water bodies, and vegetation planning. Offloads work to worker threads (`WorkerThreadPool`) while enforcing off-main-thread execution to preserve math bit-identity.
  - `RegionBakeCache`: Manages disk persistence (`user://regions/<key>/`). Serializes data with ZSTD compression. Computes a tamper-evident cache key based on engine version, seed, coordinates, settings, and a source closure digest of all scripts and assets.
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_bake.gd`, `scripts/world/region_bake_cache.gd`.
  - Owner: `RegionBakeCache` owns persistent disk storage.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `seed_value: int`, `region: Vector2i`, options dictionary.
  - Outputs: Region products dictionary, compressed `.bin` files and `manifest.json`.
  - Dependencies: Subsystems S1–S8, S11.
* **Conformance with Target Architecture:** Conforms to §3 (Worker threads construct data; main thread commits) and §8 (Principle S5: fresh bake = cache hit).
* **Defects & Failure Modes:**
  - Performance: Fresh cold bake takes 10–17 minutes (593s on 184729, 1035s on 3628391) due to sequential R5/R6 replans and 64-tile mesh generation.
  - Owed check D-5: Multi-threaded determinism (1 vs N threads) across multiple seeds is owed in the DEEP backlog.
* **Hidden Coupling / Duplication:** None. Clean separation between in-memory bake and disk persistence.
* **Adequacy of Tests:** Fast path vs fresh bake parity verified in BC1 and BC2 records.
* **Necessity & Path of Improvement:** Performance debt. Maintain current implementation; optimize tile generation parallelism in a future hardening sprint.

---

### Subsystem S10: Runtime & Streaming
* **What it actually does:**
  - `RegionWorld`: Composition root for runtime regional gameplay (`scenes/region/region_world.tscn`). Handles loading overlay, background worker baking, cache retrieval (~1.5s load time), bike spawn placement, recovery contracts (`request_bike_recovery`), and deep water detection.
  - `RegionStreamer`: Main-thread spatial scene manager. Renders fine tile meshes up to 1100m and coarse meshes beyond. Streams dynamic 64m collision patches within 170m of the bicycle (rate-limited to 1 commit/frame). Mounts flora cylinder colliders to corresponding collision patches.
* **Main Files & State Owner:**
  - Files: `scripts/world/region_world.gd`, `scripts/world/region_streamer.gd`, `scenes/region/region_world.tscn`.
  - Owner: `RegionWorld` owns the session lifecycle; `RegionStreamer` owns active scene tree nodes and physics colliders.
* **Inputs, Outputs, Dependencies:**
  - Inputs: Baked region products.
  - Outputs: Active scene nodes, static collision bodies.
  - Dependencies: S9 products, `BicycleController`.
* **Conformance with Target Architecture:** Conforms to §2, §5 (near-only collision patches, distant visual-only meshes), and §8.
* **Defects & Failure Modes:**
  - Water visuals: Water surfaces are flat non-reflective planes without flow vectors or foam.
  - Boundary: 40m invisible perimeter collision walls represent a rudimentary boundary.
  - Owed check D-2: 20-minute soak test on memory retention and frame time jitter has not been rerun under BC2.
* **Hidden Coupling / Duplication:** `RegionWorld` provides `request_bike_recovery(pos: Vector3)` to satisfy the duck-typed interface of `BicycleController`. This interface is clean and decoupling is effective.
* **Adequacy of Tests:** Integration tests exist (`test_region_ride.gd`), though runtime test suites need explicit `--trails=off` flags if testing baseline road-only behaviors (backlog D-7).
* **Necessity & Path of Improvement:** Technical debt. Water rendering improvements and boundary visual improvements are scheduled for BC3/BC4.

---

### Subsystem S11: Vegetation, Bridges & Water Presentation
* **What it actually does:**
  - `RegionVegetationPlanner`: Deterministically calculates vegetation instance locations per 512m tile using stateless spatial hashing. Distributes pine, birch, autumn birch, shrubs, grass, and rocks using `BiomeField` coverage. Enforces clearances from roads (0.6–3.5m) and trails (0.3–2.2m).
  - `RegionFloraMeshes`: Generates procedural low-poly primitive meshes (cones/cylinders) and materials for MultiMesh rendering, and defines cylinder colliders for tree trunks and rocks.
  - `BridgeDeckBuilder`: Constructs bridge deck geometry (piers, abutments, curbs) where roads cross channels requiring structural clearance.
* **Main Files & State Owner:**
  - Files: `scripts/world/region/region_vegetation_planner.gd`, `bridge_deck_builder.gd`, `region_flora_meshes.gd`.
  - Owner: `RegionVegetationPlanner` owns transforms; `RegionStreamer` owns runtime MultiMesh instances.
* **Inputs, Outputs, Dependencies:**
  - Inputs: `RegionPlan`, `TerrainField`, `HydrologyPlan`, `FinalSurface`.
  - Outputs: MultiMesh instance arrays, bridge deck meshes.
  - Dependencies: S2, S3, S6.
* **Conformance with Target Architecture:** Conforms to §2 (Vegetation placement driven by ecology fields, respects road/trail clearances, never alters terrain shape).
* **Defects & Failure Modes:** Procedural flora meshes are primitive geometric placeholders. No wind sway shaders or seasonal leaf variations.
* **Hidden Coupling / Duplication:** None.
* **Adequacy of Tests:** Clearance masks and hash determinism verified in PR1 and BC1 verification suites.
* **Necessity & Path of Improvement:** Aesthetic technical debt. Asset replacement scheduled for BC3/BC4.

---

### Subsystem S12: Bicycle Gameplay
* **What it actually does:** Implements the core player vehicle physics. CharacterBody3D with two raycasts (front and rear, wheelbase 1.15m, wheel radius 0.34m). Blends surface properties from collision layers (Road 2, Grass 3, RoughRoad 5). Simulates muscular pedaling, progressive sprint impulses, quadratic braking with nose-dive pitch, aerodynamic drag, slope gravity acceleration/coasting, speed-dependent steering limits, dynamic banking (up to 24°), lateral cornering scrub deceleration, frame micro-suspension deflection, crank cadence animation, and rear wheel skid slip.
* **Main Files & State Owner:**
  - Files: `scripts/player/bicycle_controller.gd`, `scenes/player/bicycle.tscn`.
  - Owner: `BicycleController` owns player motion and telemetry.
* **Inputs, Outputs, Dependencies:**
  - Inputs: Player input actions (pedal, brake, sprint, steer, bell, recover), collision raycast results.
  - Outputs: `telemetry_updated` signal, `bell_rung` signal, 3D transform, physics velocity.
  - Dependencies: Standalone character controller. Communicates with world root via `request_bike_recovery()`.
* **Conformance with Target Architecture:** Target Architecture §2 explicitly designates the Bicycle as: *"Стабильная KEEP-система. Public movement/telemetry/query interface. Владелец движения; не generator input с командами создать гору."* Target Architecture §5 explicitly prohibits world generation from modifying bicycle physics to mask terrain defects.
* **Defects & Failure Modes:**
  - Backlog N-4: On steep 23% descents, the camera pitch causes the bicycle frame mesh to occlude the lower viewport in first-person view.
* **Hidden Coupling / Duplication:** None. Controller does not import terrain or generator files.
* **Adequacy of Tests:** High. `test_ride_envelope.gd` (204 assertions), `test_riding_lab.gd`, `test_virtual_rider_bot.gd`.
* **Necessity & Path of Improvement:** Working system (KEEP). Minor camera angle refinement (N-4) can be addressed in player ergonomics backlog.

---

### Subsystem S13: UI, Audio & Session
* **What it actually does:**
  - `ModeSelect`: Main menu supporting 5 modes (Infinite, Sandbox, Lab, Training, Region) with full keyboard, gamepad, and mouse navigation.
  - `BikeAudioManager`: Generates real-time procedural audio loops for wind rush, gravel roll, and tire skid; manages dual-voice ping-pong freewheel ratchet clicks and physical modal bell chime.
  - `HUD` & `DebugHUD`: HUD renders speed, pedaling state, bell notification, and trail information. DebugHUD provides high-frequency telemetry (F3/F4) for speed, pitch, roll, lateral load, scrub, frame time, and generator diagnostics.
  - `ScreenFader`: Smooth fade-to-black transitions for scene loading and recovery teleports.
* **Main Files & State Owner:**
  - Files: `scenes/mode_select.tscn`, `scripts/ui/mode_select.gd`, `scripts/audio/bike_audio_manager.gd`, `scripts/ui/debug_hud.gd`, `scripts/ui/hud.gd`, `scripts/ui/screen_fader.gd`.
  - Owner: Each UI and audio script owns its presentation state.
* **Inputs, Outputs, Dependencies:**
  - Inputs: Bicycle signals and properties.
  - Outputs: Audio stream playback, CanvasLayer overlays.
  - Dependencies: S12 (`BicycleController`).
* **Conformance with Target Architecture:** Conforms to clean domain boundaries.
* **Defects & Failure Modes:**
  - ObjectDB warning: Investigated in Q2B. Godot AudioServer playback instances take ~100–200ms to unregister upon abrupt exit. Mitigated in test harnesses via a bounded 250ms settle. Production behavior is unaffected.
* **Hidden Coupling / Duplication:** None.
* **Adequacy of Tests:** `test_mode_select_gamepad.gd`, Q2B lifecycle probes, `test_session_diagnostics.gd`.
* **Necessity & Path of Improvement:** Working system. Maintain as-is.

---

### Subsystem S14: Legacy Systems & Test Infrastructure
* **What it actually does:**
  - Legacy Systems: Houses the pre-region procedural generation stack (`WorldManager`, `RoadGrammar`, `ChunkStreamer`, `TerrainCarver`, `RoadPathData`, `MountainMassifField`, `fork_*`). Accessible via Option 1 in ModeSelect.
  - Test & Verification Harness: Governed by D3 Fast Cycle (`FAST` -> `PLAYTEST` -> `DEEP`). Includes `tools/verify/sc_verify.py` (Q1 harness, 66 suites, 209 matrix rows), Q2A baseline suites, dev tools (`fast_trail.gd`, `capture_bc2.gd`, `ride_trail.gd`).
* **Main Files & State Owner:**
  - Files: `scripts/world/world_manager.gd`, `chunk_streamer.gd`, `terrain_carver.gd`, `tools/verify/`, `scripts/test/`.
  - Owner: `WorldManager` owns legacy world generation; `sc_verify.py` orchestrates verification.
* **Inputs, Outputs, Dependencies:**
  - Inputs: CLI arguments, test suites.
  - Outputs: Test result JSONs, run reports.
  - Dependencies: Full repository.
* **Conformance with Target Architecture:** Fully compliant with `docs/LEGACY_MIGRATION_MATRIX.md`. Legacy code is intentionally quarantined and preserved to maintain regression baselines until region architecture reaches feature parity.
* **Defects & Failure Modes:**
  - Known legacy failure: `route_branch_integration` (9 failures in legacy branch generator).
  - Open compliance items: C10 (numeric requirements) and C12 (stale test oracles) remain documented open items.
* **Hidden Coupling / Duplication:** Legacy systems duplicate concepts implemented cleanly in the region stack (`MountainMassifField` vs `MacroTerrainPlan`; `TerrainCarver` vs `RoadTerrainDeformer`; `ChunkStreamer` vs `RegionStreamer`). This duplication is intentional and governed by the migration plan.
* **Adequacy of Tests:** Comprehensive test harness with automated failure classification and process isolation.
* **Necessity & Path of Improvement:** Frozen legacy code. Strictly maintain read-only isolation until formal deprecation.

---

## 4. Cross-Cutting Architectural Risks & Hidden Coupling Analysis

1. **Floating-Point Determinism Across Threads (CRT Exp/Pow Quirk):**
   - *Risk:* In Godot 4.7.2 on Windows (MSVC runtime), `exp()` and `pow()` return slightly different least-significant bits on the main thread compared to background threads. This creates a ~1e-13m discrepancy that cascades into differing terrain heights and cache key mismatches.
   - *Architecture Mitigation:* Subsystems S5 (`RoadSynthesizer`), S8 (`RegionNetworkBuilder`), and S9 (`RegionBake`) use `RoadSynthesizer.off_main_thread()` to ensure generation always executes inside a worker thread (`WorkerThreadPool`), preserving bit-identical outputs.

2. **Resolution Divergence Between Design Surface and Tessellated Mesh:**
   - *Risk:* Off-road terrain tiles use 16m lattice spacing. In steep gullies, linear interpolation between 16m vertices differs from the continuous analytic `sample_height()` by up to 3.6m.
   - *Architecture Mitigation:* Subsystem S7 queries the **published ground** (`FinalSurface.published_ground`) rather than analytic formulas. Subsystem S6 (`FinalSurface.with_published()`) intercepts elevation and raycast queries in trail zones and evaluates them against the exact published mesh triangles.

3. **AudioServer Process Teardown Lifecycle:**
   - *Risk:* Procedural audio streams in `BikeAudioManager` unregister asynchronously in Godot's audio thread. If a test harness terminates the process immediately after tearing down the scene, Godot emits 6 ObjectDB leak warnings.
   - *Architecture Mitigation:* Proven in Q2B investigation to be harmless process-exit latency rather than an accumulating memory leak. Test harnesses employ a 250ms teardown settle.

---

## 5. Test Coverage & Verification Adequacy Review

Under **D3 Fast Cycle governance** (`FAST` -> `PLAYTEST` -> `DEEP`):
- **FAST Verification:** Touched scripts pass parse checks; domain logic suites run in seconds (`test_bc2_trails` in 4.4s, `test_region_network` in 0.01s).
- **PLAYTEST Verification:** Game Director conducted real playtests for BC2 Checkpoints 1 (Singletrack), 2 (Technical Descent), and 3 (Procedural Network), formally accepting them (`ddfa9ce`, `699a6f2`, `e7730ca`).
- **DEEP Backlog (Owed Checks):**
  - **D-1:** G gates (`seed_diversity`, `monotony`, `virtual_rider`, `capture_visual_vulkan`).
  - **D-2:** 20-minute soak run on region runtime measuring frame time distribution and memory growth.
  - **D-3:** Re-run `capture_region_world --target=r7_fixture`.
  - **D-4:** Formal VERIFY + independent REVIEW of region runtime.
  - **D-5:** Procedural trail bake determinism (1 vs N threads) across multiple seeds.
  - **D-6:** Programmatic virtual rider bot input rides across procedural trails.
  - **D-7:** Execution of runtime suites (`test_region_ride`) with `--trails=off`.

---

## 6. Roadmapped Work & Phase Boundaries (BC3–BC6 Scope)

To maintain stability and avoid scope creep, the following boundaries must be strictly observed:

### What Must NOT Be Touched Now:
- Do NOT alter `BicycleController` physics, steering curves, or braking values.
- Do NOT refactor or touch legacy generation scripts (`WorldManager`, `ChunkStreamer`, `TerrainCarver`).
- Do NOT modify S1 (Identity), S2 (Geography), S3 (Hydrology/Biomes), or S6 (FinalSurface).

### Tasks Belonging to BC3 (World Quality & Environment):
- **Switchback Platforms (N-5):** Introduce localized terrain shaping for hairpin turns on steep descents.
- **Relief & Variety on Singletrack (N-3):** Enhance path selection when crossing undulating terrain.
- **Nature Loops on Loopless Regions (N-6):** Allow Singletrack to venture into scenic terrain and return to the same road when no road loop exists.
- **Water Visual Presentation:** Replace flat water quads with water shaders, flow direction, and riverbed details.
- **Environment & Vegetation Assets:** Replace procedural cones/cylinders with artistic foliage assets.

### Tasks Belonging to BC4–BC6:
- Cross-region continuous streaming and road continuation.
- Dynamic landmark framing and vista corridors (R14–R15).
- Journey Director experience pacing (R16).

---

## 7. Audit Sign-off

* **Auditor Role:** Agent B — System Architecture & Health Auditor
* **Model & Version:** Google Gemini 2.5 Pro (Thinking / Antigravity Architecture Auditor)
* **Audit Date:** 2026-10-14
* **Session / Conversation ID:** `96d03208-b0de-43ae-8514-4c19bc0bb3a8`
* **Analyzed Commit SHA:** `e7730caf60807300bff8323af45ca2d00d94a443` (`master`)
* **Checks Performed:**
  - Read-only static inspection of all 14 subsystem codebases and documentation authority files.
  - Direct execution of S1 domain skeleton suite (`test_region_domain_skeleton.gd`: 145 checks, 0 failures).
  - Direct execution of S7 BC2 trails domain suite (`test_bc2_trails.gd`: 31 checks, 0 failures).
  - Direct execution of S8 region network domain suite (`test_region_network.gd`: 14 checks, 0 failures).
  - Direct execution of S6 FinalSurface contracts suite (`test_final_surface.gd --source=fixture`: 1,424 assertions, 0 failures).
  - Direct execution of S5 road synthesis contracts suite (`test_road_synthesis.gd --group=contracts`: 72 checks, 0 failures).
  - Verification harness manifest integrity check (`tools/verify/sc_verify.py check-manifest`: 66 suites, 209 rows PASS).
* **Limitations:**
  - In accordance with the READ-ONLY operating rules, no source files were modified, committed, or pushed.
  - Full Vulkan Forward+ interactive riding sessions were evaluated via Director playtest records and automated contract tests rather than a live display head.
