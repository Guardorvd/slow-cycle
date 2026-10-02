# Slow Cycle — current project state after D0

STATUS: CURRENT

Дата: 02.10.2026. Scope: состояние после documentation reset; runtime/source baseline `ed7d1322da1a5700a8c64425708e1c813213c7f6`, никаких игровых изменений в D0. Runtime evidence ниже датировано 01.10 или ранее и в D0 заново не запускалось. Точную текущую docs revision/branch определять через `git log -1`/`git status`; это не новый runtime baseline Q2.

## 1. Authority и ближайшая работа

[Blueprint](TARGET_GAME_BLUEPRINT.md) — продукт; [Master](MASTER_IMPLEMENTATION_PLAN.md) — стратегия/pivot и порядок фаз. [Target architecture](TARGET_ARCHITECTURE.md), [migration matrix](LEGACY_MIGRATION_MATRIX.md), [test strategy](TEST_STRATEGY.md) — производные. [AGENTS](../AGENTS.md)/[plan slot](../implementation_plan.md) регулируют разрешённое действие; [as-is architecture](../ARCHITECTURE.md) и код — факты/миграционный контекст. [Index](README.md), [audit](DOCUMENTATION_AUDIT.md), [decision](DECISIONS/D0-001-documentation-authority.md).

D0 завершён как документационная фаза; [approved ExecPlan и отчёт](plans/completed/D0.md). Активного плана нет. Следующий безопасный task — подготовка D1: отдельный ExecPlan и согласование до исполнения. D1/Q0/Q1/Q2/R0 не начаты. WORLD-01/C05 и старые B/P/sprint next steps SUPERSEDED, не разрешение продолжить код.

## 2. Что фактически есть

| Часть | Implemented legacy scope | Ограничение |
|---|---|---|
| Player/camera/controls/audio/HUD/recovery | Существующие stable controllers и public telemetry | D0 не меняет параметры и не выполняет новый ride |
| Road | Seeded RoadGrammar/RoadLogic, RoadPathData, MountainProfile, локальные MTB events | Не region terrain-aware corridor planning |
| Fork/streaming | RoadGraph strict DAG + actual centerlines/choices; ChunkStreamer branch/chunk lifecycle | Нет loop/merge региональной сети; spatial streaming не создан |
| Terrain | MountainMassifField math + road-relative TerrainCarver/RoadChunk strip/wedge | W_FAR 38 м, нет world-covering independent terrain и FinalSurface |
| Vegetation/collision | Local MultiMesh/type/chunk; whole terrain faces collider | Нет regional ecology fields и near-only terrain patches |
| Capture/diagnostics | C01–C02 provenance guards, LOG session observer/checkpoints, C03–C04 CW/contact checks | Geometry replay не input/physics replay; ограниченный seed/arm/point coverage |

Исходники/ownership: [ARCHITECTURE](../ARCHITECTURE.md). Future owners не реализованы только потому, что их имена появились в D0 docs.

## 3. Датированные свидетельства

Последний основной runtime commit предыдущего дня: `ce3b175c95d85664a110031161ebbc10c5486720`; отчёты исходных запусков содержат `7c33004` плюс dirty changes. После него были documentation commits, включая authority bootstrap `ed7d132`. Эти revisions нельзя выдавать за новые D0 запусковые evidence.

| Этап | Сохранённый результат | Что не доказано |
|---|---|---|
| [C01–C02](sprints/world_00_c01_c02_verification_report.md) | 27 checks, 19 PNG с effective seed/местом/camera/Image/save/reload/metadata | Beauty/whole-world terrain/physical ride |
| [WORLD-00-LOG](sprints/world_00_logs_verification_report.md) | 37 checks, три seed × 3 checkpoints/1 choice, 13 expected negative результатов | Полный deterministic input/physics replay; crash recovery |
| [C03–C04](sprints/world_00_c03_c04_verification_report.md) | 168 checks, 6 arms, 333 contacts, 21 PNG в declared scope | Цельная земля за road strips/все routes/все seed |
| [WORLD-00B](sprints/world_00b_verification_report.md) | Карта 59 tools и четыре bounded baseline/lifecycle probe | Fresh full regression/visual/human acceptance |

Сводка дня: [TODAY_CHANGES_2026_10_01](TODAY_CHANGES_2026_10_01.md). Полная передача прежнего состояния: [snapshot](history/CURRENT_PROJECT_STATE_PRE_D0.md). Evidence files по абсолютным внешним локальным путям сохраняются; их доступность в D0 не перепроверялась.

## 4. Known failures и границы доказанного

**Последняя общая чистая runtime acceptance: INCOMPLETE; D0 её не закрывает.**

- ObjectDB warning о 6 unresolved instances наблюдался в replay; причина не устранена. Чистый повтор не является исправлением lifecycle.
- Route failures=9/routes=4 и fixed-seed junction/envelope failure ранее воспроизводились также на исходном HEAD; commit benchmark варьировал.
- Rider PASS покрывал 355.9/500 м по прежнему 70% порогу; это не полный route acceptance или E7.
- Valley boundary jump 4.5 м, code radius 18 м против 19 м AGENTS, широкий fatal fallback и landing +10° зарегистрированы как legacy findings. D0 их не ремонтирует и не меняет limits.
- Full streaming-order determinism, отсутствие всех holes/leaks, продолжительный FPS/memory, проезд всех alternatives и качество нового region не подтверждены D0 запуском.

Это сохранённые наблюдения/claims прошлых проверок, не freshly reproduced findings. Sources: dated reports и [audit](DOCUMENTATION_AUDIT.md); future Q2 должен зафиксировать настоящий frozen baseline и ObjectDB investigation.

## 5. Продуктовая цель и запреты

Mountain River Valley slice 20–30 минут: настоящее место, choices/change plan, спокойная/интересная езда, off-road, loop, biomes/reveal/human traces — по Blueprint и E7. Зрелый region/continuation позже. Legacy implementation не отменяет эту цель.

Worldgen не меняет bicycle/camera/controls без отдельного approved player scope. Старые tests сохраняются; suite authority/reclassification — Q0 с human approval, governance rewrite — D1. Никакое documentation acceptance не даёт зелёный runtime статус и не разрешает следующую фазу автоматически.
