# Slow Cycle — Target Architecture

STATUS: CURRENT

Scope: производное описание region-first цели, NOT_IMPLEMENTED как полный pipeline. Authority: [Blueprint §§5–18,24–36](TARGET_GAME_BLUEPRINT.md), [Master §§I–II, R0–R21](MASTER_IMPLEMENTATION_PLAN.md). As-is: [ARCHITECTURE](../ARCHITECTURE.md); migration: [matrix](LEGACY_MIGRATION_MATRIX.md); navigation: [index](README.md). **Поправка B+C (2026-10-12):** [Master XII-B](MASTER_IMPLEMENTATION_PLAN.md#xii-b-amendment-bc-2026-10-12), [roadmap](ROADMAP_B_C_ROUTE_REALIZATION.md), §8 ниже; формулировки ниже, которые она уточняет, сохранены и помечены.

## 1. World first → Route second → Road third

Seed задаёт идентичность места и world-space географию до выбора маршрутов. Дорога не определяет всю землю, биомы и vegetation через ближайший road sample. Noise добавляет несовершенство осмысленным macro forms, а не заменяет композицию региона.

Полная продуктовая композиция Blueprint включает geography → hydrology → terrain features → biomes → landmarks/vistas → route network → geometry/ride situations → final surface → environment/player. Стратегия Master внедряет эти возможности по фазам: первые R5 corridors не требуют уже реализованных R14/R15 landmarks/vistas; поздние intents расширят planning inputs. Это разные виды порядка: целевые зависимости и безопасная поэтапная миграция. D0 не меняет ни один из первоисточников.

```text
Region generation → RegionPlan
                         ↓
TerrainField / HydrologyPlan / BiomeField / RideabilityField
                         ↓
Route planning → RouteNetworkPlan / RegionRouteGraph / RouteCorridor
                         ↓
Road synthesis → RoadPathData
                         ↓
FinalSurface → runtime presentation → render / collision / vegetation / water

Player → world query contracts / collision
```

**Поправка B+C (2026-10-12).** Шаг `Road synthesis → RoadPathData` выше относится только к участкам ENGINEERED; маршрут реализуется по участкам (§8):

```text
Route planning → RouteNetworkPlan / RegionRouteGraph (роли, причины, направленная доступность, возврат)
                         ↓
Route realization по участкам (§8):
  ENGINEERED — RouteCorridor → RoadSynthesizer → RoadPathData + roadbed intent
  NATURAL    — тропа на существующей поверхности (след, материал, растительность)
  SHAPED     — явное ограниченное локальное изменение поверхности
                         ↓
FinalSurface + публикация региона (опубликованная сеть, продукты bake/cache)
                         ↓
runtime presentation → render / collision / vegetation / water
```

Названия здесь — будущие domain responsibilities из Master, не утверждённые D0 schemas. Существующий RoutePlan из P2.1b не становится автоматически RouteNetworkPlan; точные API/serialization/версионирование требуют отдельного фазового ExecPlan.

## 2. Единственный owner каждого состояния

| Владелец | Результат/вход | Responsibility и запрет обратного управления | Фаза |
|---|---|---|---|
| RegionGenerator | RegionPlan, RegionIdentity, RegionBounds, MacroTerrainPlan | Pure география региона; не collision/Node tree | R0–R1 |
| Terrain field layer | height/gradient/normal world queries | Независимая от дороги основа; renderer не владеет высотой | R1–R2 |
| Hydrology layer | HydrologyPlan | River/tributary/drainage влияет на terrain/moisture/routes, не просто decoration spline | R3 |
| Biome/Rideability layers | BiomeField/RideabilityField | Geography-driven placement/cost; не biome из одного road arc-distance | R4 |
| RoutePlanner | RouteNetworkPlan, RegionRouteGraph, RouteCorridor | Network/corridors по terrain/water/cost/классу пути; не mesh builder | R5 |
| RoadSynthesizer | RegionRouteGraph + TerrainField/HydrologyPlan/R4 → RoadSynthesisPlan (RoadPathData-совместимые виды, roadbed intent) | R6 LIMITED ALPHA ACCEPTED 2026-10-10 (certified R7/R8 handoff route only; full regional network NOT READY; [record](plans/completed/R6.md)); isolated, `scripts/world/region/road_*.gd`, no runtime consumer: REWRITE регионального композитора, не RoadGrammar FSM; terrain-aware alignment designer (lattice DP + fairing + G2 quintic + exact vertical profile), shared junction patches, exact crossing pins (C2 envelope), bounded roadbed intent for R7; грунтовая геометрия без airborne; PARTIAL/REPLAN_REQUIRED выходы честны. R7 владеет deformation/surface/collision | R6 |
| FinalSurface | BaseTerrain + hydrology/road/landmark deformation | Единственная итоговая высота для всех consumers | R7 - technical LIMITED ALPHA complete on certified route; Director acceptance pending ([record](plans/completed/R7.md)) |
| WorldStreamer | WorldCellData/runtime lifecycle | Пространственные terrain/collision/road/vegetation/prop/water cells | R10 |
| Vegetation planning/adapter | Ecology fields → VegetationCell/transforms | World-space placement, road/view exclusions; не меняет terrain | R11 |
| Landmark/Vista planning | RegionPlan + spatial opportunities/intents | Композиция/approach/view corridors; не случайные renderer props | R14–R15 |
| JourneyDirector | Недавний опыт → intents CALM/DISCOVERY/FLOW/INTENSITY/RELEASE/WONDER | Предложения, не решения игрока, не spline/physics | R16 |
| Bicycle | Public movement/telemetry/query interface | Владелец движения; не generator input с командами создать гору | Стабильная KEEP-система |
| WorldManager | Composition root | Собирает contracts/owners; не God Object с генерационной математикой | Поэтапная integration |
| *Поправка B+C:* RoutePlanner | + роль, причина и способ реализации участка | Направленная доступность и возврат; не mesh builder | BC2 |
| *Поправка B+C:* RoadSynthesizer | Без изменения входов/выходов | Только участки ENGINEERED (основные дороги), пока оправдано (§8) | — |
| *Поправка B+C:* Trail realization (NATURAL / SHAPED) | RegionRouteGraph + природные слои → линия тропы, маска, ограниченные операции | Реализует тропы на существующей поверхности; не владеет поверхностью и опубликованной сетью; NOT_IMPLEMENTED | BC1–BC2 |
| *Поправка B+C:* опубликованная сеть (RealizedRoadNetwork в PR1) | Реализованные участки → сеть, которую потребляют FinalSurface, bake и runtime | Приёмка законченных связей; метрики только по опубликованной сети (§8). PR1: реализовано, не принято | PR1; BC1–BC2 |
| *Поправка B+C:* FinalSurface | + ограниченные изменения SHAPED; NATURAL-маска без изменения формы | Единственный владелец итоговой физической поверхности; принципы S1–S7 (§8) | BC1–BC2 |
| *Поправка B+C:* WorldStreamer | — | PR1 RegionStreamer: реализован, не принят | PR1 |

## 3. Domain и Godot boundary

Planning/math — pure data/RefCounted где возможно, без scene tree, Nodes, mesh instances, collision objects и renderer state в планах. Consumers используют публичные immutable или явно owned results/query, без shared mutable arrays и circular dependencies.

Seed derivation явная, через stable identity/world coordinates; geometry hashes не зависят от allocation IDs, materialization order и global RNG. Точные salts/hash schemas и budgets утверждаются в соответствующих R/Q задачах, а не выбираются в D0.

Worker может готовить plain plans, height/mesh arrays и transforms. Main thread владеет scene tree, physics objects и required resource commit. Threads/queues добавляются только после profiling; D0 не создаёт threading framework.

## 4. Регион, topology и свобода

Первый archetype — Mountain River Valley: macro valley/mountain/ridges/creeks, 2–4 совместимых биома, natural limits и читаемые виды. RegionRouteGraph поддерживает fork, merge, loop, cross-connection, alternate route и редкий justified dead-end. Backbone/secondary/singletrack/technical — разные роли внутри места, не две бесконечные ветви процедурного дерева.

Legacy RoadGraph strict DAG сохраняется для старого runtime до migration gate; DAG не ограничивает новую topology. Off-road meadow/open terrain должен стать реальной проезжаемой поверхностью. Глубокая вода, cliffs, dense forest и rough terrain дают природные границы. Walking, inventory/XP/quests/races не добавляются.

## 5. FinalSurface и runtime consumers

`BaseTerrain + Hydrology deformation + Road deformation + Landmark deformation = FinalSurface`.

**Поправка B+C (2026-10-12):** `BaseTerrain + Hydrology deformation + Road deformation (ENGINEERED) + SHAPED trail modifications + Landmark deformation = FinalSurface`; NATURAL-маска меняет только след, материал и растительность (§8).

Сумма обозначает ответственность, не фиксирует ещё не спроектированный численный алгоритм. Terrain render/collision, vegetation/props, water banks и off-road queries используют согласованную итоговую поверхность. RoadTerrainDeformer может переиспользовать CUT/FILL/SHELF math; TerrainCarver перестаёт быть owner всей земли только после R7 parity.

Engine/render target по Master — Godot 4.7 / Forward+. Initial terrain renderer — CPU-generated ArrayMesh, fixed world-space tiles с uniform resolution/shared boundary samples. Detailed collision нужна возле игрока, distant terrain может быть render-only. Это будущие R2/R9 contracts: текущий полный collider придорожной полосы не считается уже near-only.

Vegetation — MultiMesh per spatial cell + type, локальный culling. Per-chunk instantiation полезна как legacy implementation detail, но не диктует target cell ownership. Zero-Post не является новым продуктовым запретом: Blueprint разрешает осмысленные human traces в R12 при безопасности пути.

## 6. Диагностируемые отказы

REJECT / REPLAN / DEGRADE_EXPLICITLY / FAIL имеют причину и coverage. Нельзя молча заменить сложную дорогу прямой, скрыть объект, ослабить проверку или править bicycle physics для маскировки terrain дефекта. Несогласованные legacy limits/fallback остаются [открытыми](DOCUMENTATION_AUDIT.md); D0 не выбирает новый радиус или landing envelope.

## 7. Фазовые и продуктовые границы

| Milestone | Что разрешает Master | Что это не доказывает |
|---|---|---|
| D0 | Documentation authority reset | Готовность нового region/runtime |
| D1 → Q0 → Q1 → Q2 | Governance → test authority map → bounded harness → frozen baseline/leak investigation | Автоматическое разрешение R0 |
| R0–R4 | Domain/geography/terrain/hydrology/biome/rideability | Physical ride/full network gameplay |
| R5–R7 | Network planning → road adapter → FinalSurface | Человеческий новый slice |
| R8–R11 | Первая поездка → off-road → spatial streaming → regional vegetation | Долгосрочная бесконечность |
| R12–R17 | Water/traces/network gameplay/exploration/vistas/journey/situations | Human acceptance без человека |
| R18 | 20–30 минут Mountain River Valley slice и E7 | Зрелый регион 40–70 минут или continuation |
| R19 → R20 → R21 | Performance hardening → archetype diversity → region continuation | Повод строить LOD/clipmaps заранее |
| BC0–BC6 ([Master XII-B](MASTER_IMPLEMENTATION_PLAN.md#xii-b-amendment-bc-2026-10-12)) | Технический путь B+C к целям R8–R21; PLAYABLE-контрольные точки внутри фаз | Формальную приёмку без L2/VERIFY/REVIEW/E7 |

Старые code/assets/API определяют reuse и safe migration, не право изменить target. Каждый следующий шаг имеет отдельный approved plan, tests/evidence и rollback boundary. D0 завершён только как документационная фаза.

## 8. Route realization B+C (поправка 2026-10-12)

Источник: [roadmap](ROADMAP_B_C_ROUTE_REALIZATION.md) §§3–4. Ниже — роли и контракты, а не утверждённые API; конкретные структуры, алгоритмы поиска, сетки высот и размеры операций определяются фазовыми планами BC1+ по измерениям.

**Одна сеть, три способа строительства.** BACKBONE / SECONDARY / SINGLETRACK / TECHNICAL — роль и характер маршрута. Способ выбирается по участкам и может меняться вдоль одного маршрута: ENGINEERED (R5/R6 + RoadTerrainDeformer), NATURAL (линия на существующей поверхности), SHAPED (явное ограниченное изменение с границей и бюджетом). Отдельного «мира троп» нет.

**R5/R6.** Остаются реализацией основных дорог, пока это оправдано; подключены к той же границе «реализация → FinalSurface», что и тропы, поэтому заменимы локально. Пересмотр — только по измеренной проблеме (время bake, расширяемость, качество игры, стоимость сопровождения) и отдельным планом. Контракт классов `regional_road/1 §6` (уклоны, радиусы) действует для участков ENGINEERED, реализованных R6; участки NATURAL / SHAPED получают собственный контракт тропы (BC1).

**FinalSurface — принципы S1–S7.** S1 одна итоговая физическая геометрия для collision, проверки троп, recovery, растительности и берегов. S2 запросы итогового мира совпадают с опубликованной геометрией в объявленном допуске; запросы этапа проектирования явно помечены. S3 NATURAL не меняет форму (новые вершины лежат на исходной поверхности). S4 SHAPED — явное, ограниченное, записанное изменение. S5 fresh bake = cache hit для всех потребителей. S6 дальний LOD — визуальное приближение; мосты — отдельные конструкции. S7 WORLD FIRST; renderer — потребитель, не владелец формы. Способ хранения не фиксируется.

**Семантика сети.** Геометрическая связность, направленная проходимость, доступный возврат и осмысленность — разные свойства. Осмысленный тупик допустим (цель соразмерна, обратный путь проходим); ловушка — нет. У тропы есть записанная причина из существующих данных мира (терраса, вода, лес, седловина, спуск, полезная связь); полноценные Landmark/Vista/Journey остаются R14–R16. Принимается законченная связь (линия, оба примыкания, crossings, при необходимости возврат); недостроенная петля не публикуется как доступная.

**Защита от второго универсального solver.** Малый словарь операций SHAPED, каждая новая — по конкретным отказам или плейтесту; локальная граница воздействия (вне неё поверхность бит-в-бит неизменна); конечный бюджет попыток и право отказа; различия регионов и биомов — данными, без веток кода под биом; наблюдаемые метрики (доля SHAPED, объём изменений, попытки, причины отказов).
