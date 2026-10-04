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

## 5. R0 pure-domain region foundation (as-is)

R0 now provides the isolated pure-domain foundation `world_seed + Vector2i region_coordinate -> RegionIdentity -> RegionBounds -> MacroTerrainPlan(DEFERRED_R1) -> RegionPlan` in [scripts/world/region](scripts/world/region/region_generator.gd). RegionGenerator is the intended producer; RegionPlan directly uses RegionSeedDerivation for canonical identity/signature validation, a benign one-way dependency. There is no runtime/WorldManager integration and no geography yet; MountainMassifField is not a dependency. [R0 completion record](docs/plans/completed/R0.md).
