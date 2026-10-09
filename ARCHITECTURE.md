# Slow Cycle — current runtime architecture

STATUS: CURRENT

Scope: **as-is legacy runtime**, read-only observations до D0 на `ed7d132`; D0 не меняет код. Целевая архитектура отдельно в [TARGET_ARCHITECTURE](docs/TARGET_ARCHITECTURE.md), первоисточники — [Blueprint](docs/TARGET_GAME_BLUEPRINT.md) и [Master](docs/MASTER_IMPLEMENTATION_PLAN.md). [Index](docs/README.md), [migration](docs/LEGACY_MIGRATION_MATRIX.md), [current state](docs/CURRENT_PROJECT_STATE.md).

## 1. Runtime ownership

```text
mode_select.tscn → main.tscn
  WorldManager: effective seed, shared deterministic resources, composition
    MountainProfile: seed / route identity / arc distance
    ChunkStreamer: branch/chunk window, fork scheduling, prepare/commit
      ForkSitePlanner / ForkCorridorPreviewPlanner / ForkPacingPlanner
      RoadGraph: actual LEFT/RIGHT centerlines, branch choice, strict DAG
      RoadChunk: road mesh/collision; TerrainCarver roadside mesh/collision
        ChunkFoliage: chunk-local MultiMesh groups
  BicycleController: public movement/telemetry, upright root + VisualsRoot
  BikeCamera / audio / HUD: player state/signals
  SlowCycleLogger: session observer, bounded geometry checkpoints
```

Источники: [manager](scripts/world/world_manager.gd), [streamer](scripts/world/chunk_streamer.gd), [graph](scripts/world/road_graph.gd), [chunk](scripts/world/road_chunk.gd), [foliage](scripts/world/chunk_foliage.gd). Ownership описывает реализованное, не доказывает full determinism/performance/ride quality.

## 2. As-is data flow и границы

1. Main разрешает effective session/CLI seed до создания генератора. [RoadLogic](scripts/world/road_logic.gd) потребляет seeded [RoadGrammar](scripts/world/road_grammar.gd), строит centerline/events, применяет MountainProfile и валидирует chunk.
2. [RoadPathData](scripts/world/road_path_data.gd) содержит текущую centerline/frame/contact geometry. Существующие [RouteIntent](scripts/world/route_intent.gd) и [RoutePlan](scripts/world/route_plan.gd) — данные intent/измерений из прежнего P2; это не RegionPlan/RouteNetworkPlan и не production region planner.
3. Streamer использует seeded distance schedule и pure fork preflight/paired arm preview до graph/mesh side effects. RoadGraph владеет actual choice/branch identity; streamer — lifetime/window. DAG остаётся старым контрактом.
4. [TerrainCarver](scripts/world/terrain_carver.gd) строит поперечные road-relative полосы. [MountainMassifField](scripts/world/mountain_massif_field.gd) добавляет разницу поля между центром и флангом; независимой world-covering XZ mesh и terrain-constrained route пока нет. W_FAR=38 м не размер региона.
5. RoadChunk prepare/commit создаёт mesh/collision из дорожных и terrain faces. В прежнем коде whole terrain_faces идут в collider; separate near-only collider не реализован. D0-C03–C04 в отчёте относится к CW surface faces и честным contacts, не новой open-world земле.
6. Foliage размещается локально по chunk/type с legacy seed/key и carver context. Это не ecology fields/spatial cells. Player потребляет реальные world collisions; generator не управляет bicycle kinematics.
7. [Logger](scripts/core/slow_cycle_logger.gd) наблюдает session/choices/geometry checkpoints, flush и source/config context. Geometry replay bounded, физический input и полный мир не записываются.

## 3. Stable subsystem boundary

[BicycleController](scripts/player/bicycle_controller.gd) и [BikeCamera](scripts/camera/bike_camera.gd) сохраняются. Public `telemetry_updated(speed_kmh, cadence_pct, is_coasting)` и `bell_rung`, upright physical root и отдельный VisualsRoot — существующие integration boundaries. Worldgen задача не меняет physics/camera/controls для маскировки поверхности.

| Godot layer | Runtime purpose |
|---|---|
| 2 | Road |
| 3 | Grass / terrain |
| 4 | Player |
| 5 | RoughRoad |

Bit masks 2/4/16 в прежних описаниях не равны порядковому номеру layer. D0 настройки и collision masks не меняет.

## 4. Ограничения и traceability

Нет подтверждённой целиком chain region → routes → FinalSurface → off-road → journey. Старые expected assertions/master PASS не доказательство сегодняшних E3–E7. Radius 18/19 м, широкий fatal fallback, landing +10°, valley jump, ObjectDB/route/performance findings сохранены в [state](docs/CURRENT_PROJECT_STATE.md) и [audit](docs/DOCUMENTATION_AUDIT.md), а не исправлены prose.

Полное прежнее architecture описание, formulas и Sprint/P/B/LOG/C03–C04 детали сохранены в [ARCHITECTURE_PRE_D0](docs/history/ARCHITECTURE_PRE_D0.md). Оно HISTORICAL: MountainProfile-as-biome-owner, Zero-Post, future paired planning и target road-first схемы не являются текущей product authority. [Road geometry reference](ROAD_GENERATION.md), [legacy commands](TEST_PLAN.md), [reports catalogue](docs/history/README.md) сохраняют полезную технику/coverage.

## 5. Region domain foundation R0–R4 (as-is)

Isolated pure-domain chain, no runtime/WorldManager integration (production references = 0), MountainMassifField is not a dependency:

```text
world_seed + Vector2i region_coordinate
  -> RegionIdentity -> RegionBounds -> MacroTerrainPlan -> RegionPlan          (R0 identity/bounds; R1 macro geography; RegionGenerator is the producer)
  -> TerrainField.create(region_plan)                                          (R2: sole public base-terrain query surface — height / gradient / normal / lattice, world metres)
       internal kernel: MacroTerrainEvaluator (prepared context; stateless math)
  -> HydrologyGenerator.build(region_plan, field) -> HydrologyPlan             (R3: single owner of hydrological truth — river, drainage lattice, channels, water bodies)
  -> HydrologyField.create(plan, field)                                        (R3: derived queries — water / proximity / drainage / deformation)
  -> HydrologySurface.create(field, hydrology_field)                           (R3, transitional until R7 FinalSurface: base + hydrology deformation, TerrainField API)
  -> TerrainTileRenderer.tile_arrays / tile_mesh(field or surface, tile_x, tile_z) (R2: per-tile arrays/ArrayMesh built only through the field / surface)
  -> RoutePlanner.plan(region_plan, field, hydrology_plan) -> RegionRouteGraph   (R5 COMPLETE, Alpha accepted: regional route network = RouteNetworkPlan; RouteCorridor per edge; no runtime consumer until R6)
  -> region_preview.gd                                                         (presentation only: nodes, material, camera; opt-in diagnostic hydrology / environment / routes modes; isolated scene)
```

Dependency direction `RegionPlan ← TerrainField → MacroTerrainEvaluator → MacroTerrainPlan`; `HydrologyGenerator → {RegionPlan, TerrainField, DrainageRouting} → HydrologyPlan ← HydrologyField ← HydrologySurface`; hydrology reads base terrain only (no feedback into TerrainField); the renderer and preview never touch the evaluator, descriptor data or hydrology math. Neighbouring tiles are seamless by construction (each tile is built independently from the field). Scope: single region, closed domain, same-platform determinism; no routes, FinalSurface, LOD/streaming or cross-region continuity yet (region-edge drainage is assumed); thread safety not claimed. Sources: [scripts/world/region](scripts/world/region/terrain_field.gd). Records: [R0](docs/plans/completed/R0.md), [R1](docs/plans/completed/R1.md), [R2](docs/plans/completed/R2.md), [R3](docs/plans/completed/R3.md).

R4 adds independent derived `BiomeField` and `RideabilityField`, composed through `EnvironmentContext.create(region_plan, terrain_field, hydrology_plan)`. The context is a sampling helper, not a world-truth or height owner. It guards consumed hydrology representations, holds matching derived HydrologyField/HydrologySurface adapters and a fixed smoothed 129² drainage scalar array. Its semantic basis is `BASE_PLUS_HYDROLOGY_PRE_ROAD`; R7 must retain this natural planning basis, without road feedback.

Biome weights have fixed CONIFER/MEADOW/RIPARIAN/AUTUMN order. Dry weights normalize to one; exact water has a WATER sentinel with zero land weights/cover. Moisture, aspect, relative elevation, slope and bounded geometric water proximity drive continuous affinities. A quantized child `biome` seed chooses character and one geography-ranked, warped/feathered autumn pocket. Woody cover is potential environmental resistance, not placed trees. Rideability consumes this continuous cover and moisture, samples signed natural gradient, returns cost [1,16], OPEN/RIDEABLE/DIFFICULT/BLOCKED and reason flags. `blocked` means a natural barrier without a dedicated crossing/engineering solution; it does not forbid future R5 crossing reasoning. Grade 1.0 and depth 0.35 m are versioned Alpha starting values, not physics laws.

Both fields use world metres, closed-domain checks, TerrainField's int64 16 m lattice and packed row-major block outputs. Field signatures bind input signatures, schemas, natural basis, versioned parameters and biome descriptor. Rideability's combined point/block helpers evaluate both fields from one signal set; the scoring/resistance helpers are real production logic. No full nearest-water query occurs on an R4 field path. `HydrologyField.sample_proximity_bounded` adds capped (0,256] m proximity and a local body-cell index, retaining all older methods/schema/numerics. `--environment=biome|rideability` enables preview textures and legends; default and hydrology-only modes retain their materials and geometry. R4 Alpha is COMPLETE and accepted by the Game Director at implementation commit `851baf8db84d95cb426988f55f6de316842e128f`; approved plan, execution, VERIFY PASS, independent REVIEW PASS and accepted debt are in the [completed R4 record](docs/plans/completed/R4.md).

R5 (COMPLETE, Alpha accepted 2026-10-09 after independent VERIFY PASS and fresh independent REVIEW PASS; [completed R5 record](docs/plans/completed/R5.md); R6 not started and the planner has no runtime consumer yet) adds `RoutePlanner.plan(region_plan, terrain_field, hydrology_plan)`, the single producer of the immutable `RegionRouteGraph` (`slow_cycle.region_route_graph/1`, the R5 RouteNetworkPlan). The planner composes its own R4 fields and R3 HydrologyField/HydrologySurface from those inputs (identity guaranteed), builds a plan-local 32 m `RoutePlanningRaster` (exact R4 point queries at hydrology-lattice nodes, released after planning), finds verified geographic anchors (`RouteAnchorFinder`; passes located topographically), selects a backbone between valley-end gateways and adds purpose-driven secondary / singletrack / technical routes and connectors. Path geometry comes only from the traversal-cost kernel (`RouteSearch`: R4 ground cost, along-grade with development, cut/fill cross-slope, separation, recorded water crossings; no interest bonuses); journey purpose (`RouteJourneyScoring`, saturating novelty, anchors, relief, biome transitions, character contrast, effort/length penalties) only decides which candidates exist and are kept. `RouteCorridorBuilder` turns node paths into corridors (reference line, ≤32 m stations, per-station band half-widths, exact ≤8 m certification, crossing records from the additive `HydrologyField.sample_segment_crossings`). Acceptance performs a trial split: every edge piece is built, certified and duplicate-checked with the validator's own rule before it exists.

The graph is integer, region-local storage: GATEWAY / JUNCTION / TERMINUS nodes, corridor edges, routes (BACKBONE, LOOP_ALTERNATIVE, SHORTCUT, CROSS_CONNECTION, JUSTIFIED_SPUR), loop records (fork/merge relative to the reference route), anchors with status and reasons. `validate()` protects topology (degrees, connectivity, single backbone path between valley-end gateways, semantic hierarchy — a class never relies on a harder class — technical lines optional, no mandatory backtracking, justified termini, loop records, junction angle/spacing, corridor bounds, duplicate geometry, crossing records). Corridor bands are R6 search freedom and may overlap; FORD / SMALL_BRIDGE / BRIDGE are R5 planning hints for R6/R12/R13. `get_corridor(i)` is the R6 input boundary; no road geometry, FinalSurface, gameplay or runtime integration exists. Region origins stay int64 / float64 scalars (never packed into float32 vectors). Registered `route` seed purpose only breaks near-equal ties. Production references to the region namespace remain 0.
