# Slow Cycle — Legacy Migration Matrix

STATUS: CURRENT

Scope: future migration decisions; **никакая runtime migration не выполнена в D0**. Authority: [Blueprint](TARGET_GAME_BLUEPRINT.md), [Master §§I–II и R0–R21](MASTER_IMPLEMENTATION_PLAN.md). [As-is owners](../ARCHITECTURE.md), [target](TARGET_ARCHITECTURE.md), [audit](DOCUMENTATION_AUDIT.md), [index](README.md).

## Decisions

KEEP сохраняет правильную responsibility; EXTEND добавляет capability без смены owner; ADAPT меняет inputs/роль через boundary; REPLACE создаёт независимого владельца при фундаментальном конфликте; RETIRE удаляет старую responsibility после parity; DEFER откладывает решение до evidence. EXTEND — допустимая категория Master, но D0 не назначает её системе без основания.


| Система | Решение, документируемое D0 | Граница будущей реализации |
|---|---|---|
| BicycleController, VisualsRoot, камера, controls, аудио, HUD/recovery | KEEP; world layer потребляет public API/коллизии | Любая player-правка — отдельный measured defect и approval |
| RoadPathData, RoadMath, геометрические/airborne contracts | KEEP/ADAPT как формат и локальная математика; расхождения явно открыты | R6, без молчаливой смены limits |
| RoadLogic | ADAPT к RouteCorridor/RoadSynthesizer; macro direction больше не его власть | R6 Alpha: legacy RoadLogic/RoadGrammar НЕ обёрнуты (A1: REWRITE регионального композитора); legacy-код и тесты не тронуты, используется только математика/формат (RoadPathData, RoadKinematicModel). Наблюдательный legacy audit (150 chunks × 3 seeds × 3 styles): 0 rejections/repairs/fallbacks, 57–65 % длины |k|<1/1000 |
| RoadGrammar | ADAPT в local ride vocabulary | R6 не использует FSM; feature intents R6 (SWEEP, LINKED_TURNS, SWITCHBACK, CLIMB, DESCENT, CREST, COMPRESSION, CALM) — геометрические, R16/R17 vocabulary остаётся |
| RoadGraph | REPLACE для региональной topology; старый runtime сохраняется до безопасного перехода | RegionRouteGraph R5; gameplay integration R13 |
| TerrainCarver | REPLACE как owner поверхности; извлечь CUT/FILL/SHELF в будущий RoadTerrainDeformer | R7; retire production role только после parity |
| MountainProfile | ADAPT/DEFER для локального intent/reference, не абсолютный terrain/biome owner | Точная полезность оценивается R6; не обязателен только из-за реализации |
| MountainMassifField | DEFER как reference fixture/источник полезной математики, не обязательная база нового региона | R0/R1: отдельный независимый region layer |
| ChunkStreamer | ADAPT временным boundary, затем REPLACE/RETIRE после parity | WorldStreamer R10; сейчас не переписывать lifecycle |
| ChunkFoliage | ADAPT rendering/MultiMesh assets; REPLACE placement semantics; RETIRE old owner после переноса | R11; ecology/world-space cells |
| ForkDecisionModel | DEFER; ADAPT или RETIRE по реальной пользе для свободного движения | R13; не сохранять автоматически |
| SlowCycleLogger | KEEP как ограниченную диагностику; расширение DEFER | Q1/Q2 по отдельному scope; geometry replay не physics replay |


## Observed source, reuse и retirement gates

| Система / read-only source | Полезное reuse и риск | Gate до adaptation/retirement |
|---|---|---|
| [BicycleController](../scripts/player/bicycle_controller.gd), [camera](../scripts/camera/bike_camera.gd), audio/ui/scenes | Public telemetry/signals, upright physical root, VisualsRoot, controls/recovery. Нельзя worldgen менять внутренние kinematics. | R8/R9 используют совместимые реальные colliders/query; отдельное approval для measured player defect |
| [RoadPathData](../scripts/world/road_path_data.gd), [RoadMath](../scripts/world/road_math.gd), [geometry contract](../scripts/world/road_generation_contract.gd), [airborne](../scripts/world/road_airborne_contract.gd) | Continuous centerline/frame/event data, math/validators. 18/19 м и +10° остаются открытыми, не считаются согласованным target. | R6 public corridor adapter + determinism/negative/integration evidence; изменение limits отдельно согласуется |
| [RoadLogic](../scripts/world/road_logic.gd) | Curve/event synthesis; риск скрытого fallback и независимого macro heading | RouteCorridor управляет macro direction; сохраняется полезная геометрия, ошибки диагностируются |
| [RoadGrammar](../scripts/world/road_grammar.gd) | Event vocabulary/preparation/recovery; риск top-level pacing вместо journey | Local geometry intents отделены от R16 director; outputs/limits проверены в scope |
| [RoadGraph](../scripts/world/road_graph.gd) | Legacy branch identity/choice useful; strict DAG несовместим с loop/merge | R5 отдельный RegionRouteGraph, R13 actual network gameplay, Q0 approved test-authority scope; не ломать текущий DAG исключениями |
| [TerrainCarver](../scripts/world/terrain_carver.gd) | CUT/FILL/SHELF/cross-section math; road-relative W_FAR=38 не world surface | R7 единая FinalSurface и consumers/roadbed parity; retire old ownership, не стирать math |
| [MountainProfile](../scripts/world/mountain_profile.gd) | Local rhythm/reference возможно полезны; arc-distance biome/height не world owner | R6 evidence необходимости; отсутствует вторая абсолютная высота |
| [MountainMassifField](../scripts/world/mountain_massif_field.gd) | Reference math/fixtures; previous valley jump и качество формы не доказаны | R0/R1 новый независимый namespace; class reuse только при обосновании в отдельном plan |
| [ChunkStreamer](../scripts/world/chunk_streamer.gd) | Chunk/branch lifecycle/window; риск ownership/coupling и stalls | R10 spatial cells с parity/lifecycle/performance evidence; legacy adapter до parity |
| [ChunkFoliage](../scripts/world/chunk_foliage.gd) | MultiMesh transforms/assets/culling; road-relative placements и carver context не target ecology | R11 fields/world keys/final-surface contacts; regional placement, then retire old owner |
| [ForkDecisionModel](../scripts/world/fork_decision_model.gd) | Может помогать мягкому route context, но не навязывать fork game | R13 freedom/network review определяет ADAPT либо RETIRE |
| [SlowCycleLogger](../scripts/core/slow_cycle_logger.gd) | Sessions/checkpoints/source copies; limited geometry replay, не physical replay | Q1/Q2 bounded evidence по scope; lifecycle warnings не объявлять устранёнными |

До любого удаления старой системы нужен separate approved task: consumers migrated, coverage определено, stable APIs защищены, negative/determinism/integration evidence сохранено и rollback возможен. Baseline старого runtime ещё не frozen Q2; старые отчёты — reference, не свежая parity certification.

## Out of scope D0

Нет удаления классов, adapters, schemas, ресурсных migrations, новых tests или изменений assertions/categories. Новые domain contracts, ownership и код создаются в R-фазах. Код определяет безопасный путь перехода; наличие работающей legacy системы не делает её target обязательной.
