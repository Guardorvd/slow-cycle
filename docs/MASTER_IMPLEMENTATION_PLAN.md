# Slow Cycle — Controlled Pivot & Implementation Master Plan v1

**Статус:** стратегический source of truth для перехода от road-first генератора к region-first Slow Cycle.

**Главная цель:** сохранить зрелые и работающие части проекта, но построить новый независимый world-generation layer, позволяющий реализовать процедурные регионы, свободу исследования, сеть маршрутов, off-road движение, биомы, landmarks и режиссуру путешествия.

---

# I. Неподвижные архитектурные принципы

## 1. Независимость систем сохраняется и усиливается

Это один из лучших принципов, которые уже были заложены в Slow Cycle.

Новая архитектура должна быть ещё строже.

Целевая зависимость:

```text
Region generation
        ↓
RegionPlan
        ↓
Terrain / Hydrology / Biome data
        ↓
Route planning
        ↓
RouteNetworkPlan
        ↓
Road synthesis
        ↓
RoadPathData
        ↓
FinalSurface
        ↓
Runtime presentation
        ↓
Render / Physics / Vegetation / Water

Player
  ↓
World query contracts
```

Запрещается обратное управление.

Например:

- велосипед не сообщает генератору, какую гору строить;
- vegetation не меняет terrain;
- renderer не является источником данных для route planner;
- RoadLogic не знает про `BicycleController`;
- route planner не создаёт `MeshInstance3D`;
- RegionGenerator не создаёт collision;
- JourneyDirector не изменяет физику велосипеда;
- тестовые инструменты не получают специальных production hooks, меняющих поведение игры.

## 2. Pure domain → Godot adapter

Где возможно, логика генерации существует как:

```text
RefCounted / pure data
```

без scene tree.

Godot Nodes появляются только на runtime/presentation boundary.

Это даст:

- простые тесты;
- детерминизм;
- возможность генерации в worker thread;
- replay;
- сохранение планов мира;
- замену renderer без переписывания генератора;
- замену генератора без изменения велосипеда.

## 3. Системы общаются контрактами, а не внутренним состоянием

Основные будущие контракты:

```text
RegionPlan
TerrainField
HydrologyPlan
BiomeField
RideabilityField
RegionRouteGraph
RouteCorridor
RoadPathData
FinalSurface
WorldCellData
```

Каждый объект является либо входом, либо результатом системы.

Никакая система не должна лезть во внутренние массивы соседней системы, если для этого можно определить публичный query.

## 4. Один владелец каждого состояния

Например:

```text
RegionGenerator → владелец RegionPlan
RoutePlanner    → владелец RouteNetworkPlan
RoadSynthesizer → владелец RoadPathData
FinalSurface    → владелец итоговой высоты мира
WorldStreamer   → владелец lifecycle runtime cells
Bicycle         → владелец движения велосипеда
```

`WorldManager` — composition root/orchestrator, но **не God Object с генерационной логикой**.

## 5. Никаких скрытых fallback

Если генератор не смог построить допустимый маршрут:

не превращаем его молча в прямую дорогу;

не скрываем ошибку;

не удаляем проблемный объект;

не ослабляем проверку.

Получаем диагностируемый:

```text
REJECT
REPLAN
DEGRADE_EXPLICITLY
FAIL
```

с причиной.

---

# II. Правило KEEP / ADAPT / REPLACE

Перед любой серьёзной задачей Codex обязан классифицировать затронутую старую систему:

```text
KEEP
EXTEND
ADAPT
REPLACE
RETIRE
DEFER
```

## Когда предпочитаем REPLACE

Если фундаментальный invariant старой системы противоречит новой архитектуре.

Пример:

```text
RoadGraph:
strict DAG
```

Наша цель:

```text
loops + merges + alternative connections
```

Не ломаем DAG десятками исключений.

Создаём `RegionRouteGraph`.

Другой пример:

```text
TerrainCarver:
road → roadside terrain
```

Наша цель:

```text
terrain → road deformation
```

Роль системы инвертирована.

Создаём новую систему и забираем полезную математику.

## Когда предпочитаем ADAPT

Когда роль системы остаётся правильной, но меняется источник входных данных.

Лучший пример:

```text
RoadLogic
```

Сегодня он сам решает много вопросов направления дороги.

В будущем:

```text
RouteCorridor
      ↓
RoadLogic/RoadSynthesizer
      ↓
RoadPathData
```

Большая часть геометрической математики остаётся полезной.

---

# III. Настройка Codex перед разработкой

Это будет первая реальная работа.

## Структура инструкций

```text
/
├── AGENTS.md
├── .agent/
│   └── PLANS.md
│
├── .codex/
│   └── skills/
│       ├── slow-cycle-plan/
│       │   └── SKILL.md
│       ├── slow-cycle-worldgen/
│       │   └── SKILL.md
│       ├── slow-cycle-verify/
│       │   └── SKILL.md
│       └── slow-cycle-review/
│           └── SKILL.md
│
├── scripts/
│   ├── world/
│   │   └── AGENTS.md
│   ├── player/
│   │   └── AGENTS.md
│   └── test/
│       └── AGENTS.md
```

Не нужно создавать двадцать skills.

Четырёх достаточно.

---

## Skill 1 — `slow-cycle-plan`

Используется для любой:

- новой системы;
- migration;
- multi-file задачи;
- архитектурного изменения.

Обязан подготовить ExecPlan.

ExecPlan содержит:

```text
Goal
Observed current state
Target architecture
KEEP / ADAPT / REPLACE decisions
Public contracts
Dependency direction
Allowed files
Forbidden files
Migration path
Risks
Tests
Visual verification
Runtime verification
Performance verification
Rollback boundary
Legacy impact
Documentation changes
Definition of Done
```

После создания плана Codex **останавливается**.

Код не пишет до согласования пользователя.

---

## Skill 2 — `slow-cycle-worldgen`

Узкий skill архитектуры worldgen.

В нём закрепить:

```text
WORLD FIRST → ROUTE SECOND → ROAD THIRD
```

Правила:

- deterministic seed;
- explicit seed derivation;
- world-space coordinates;
- no global RNG;
- pure-data generation;
- no scene tree inside planners;
- no Node3D inside RegionPlan;
- no road-relative world generation;
- no circular dependencies;
- no cross-system mutable shared state;
- no terrain generated exclusively from road samples;
- no foliage placement exclusively relative to road;
- route generation consumes terrain information;
- road synthesis consumes RouteCorridor;
- render/collision consume FinalSurface;
- all spatial outputs have stable coordinates and hashes.

---

## Skill 3 — `slow-cycle-verify`

Используется после implementation.

Он не реализует feature.

Только проверяет.

Обязательные действия:

```text
git diff audit
parse/runtime check
targeted tests
integration test
negative fixtures
determinism check
seed repetition
leak/error inspection
coverage confirmation
visual capture if applicable
performance data if applicable
```

Результат:

```text
PASS
FAIL
INCOMPLETE
```

Никаких:

```text
"looks good"
"probably works"
```

---

## Skill 4 — `slow-cycle-review`

Независимый критик.

Читает:

- утверждённый ExecPlan;
- diff;
- новые API;
- результаты тестов.

Ищет:

```text
scope creep
architecture coupling
duplicated responsibilities
God objects
hidden fallback
test gaming
fake coverage
legacy assumptions
unnecessary compatibility layers
unbounded allocations
main-thread heavy work
scene-tree access from worker logic
seed nondeterminism
missing negative tests
unverified claims
```

Reviewer имеет право вернуть:

```text
REJECT
```

Даже если все тесты зелёные.

Это будет наша формальная версия твоего «саб-агента критика».

---

# IV. Новый AGENTS.md

Текущий `AGENTS.md` не уничтожаем, но существенно упрощаем.

Root должен содержать только постоянные правила.

Примерная структура:

```text
1. Product source of truth
2. Planning gate
3. Architecture boundaries
4. Stable subsystem protection
5. Determinism
6. Test integrity
7. Evidence requirements
8. Git/scope discipline
9. Documentation responsibility
10. Human validation boundary
```

Из него убираем детали вроде конкретных исторических fork spacing или текущей реализации terrain.

Они не являются вечными agent directives.

## `scripts/player/AGENTS.md`

Очень строгий:

```text
BicycleController and camera are stable systems.

World-generation tasks may not modify them unless:
1. measured defect exists;
2. task explicitly scopes player physics;
3. separate plan is approved.

World systems consume public telemetry/query API only.
```

## `scripts/world/AGENTS.md`

```text
Domain planning remains independent from scene tree.

Dependency direction is one-way.

Do not modify player/controller to accommodate worldgen.

Prefer new isolated replacement over invasive modification when old ownership is fundamentally wrong.

No renderer-specific state in RegionPlan/RoutePlan.

No global mutable generator state.
```

## `scripts/test/AGENTS.md`

Здесь исправляем опасную часть нынешнего test-integrity.

Старый тест **не всегда автоматически является вечным продуктовым требованием**.

Вводим классификацию.

---

# V. Новая система честности тестов

Каждый существующий test получает одну категорию.

## ACTIVE_CONTRACT

Текущая спецификация.

Падение блокирует задачу.

Изменение assertions — только после человеческого согласования.

## REGRESSION_GUARD

Защищает работающую систему от случайной поломки.

Падение блокирует задачу, если система входит в scope или могла быть затронута.

## LEGACY_CONTRACT

Проверяет поведение архитектуры, которую мы сознательно заменяем.

Не переписывается молча.

Но также **не может заставить новый RegionRouteGraph оставаться DAG только потому, что старый RoadGraph был DAG**.

Если появляется конфликт:

```text
OLD CONTRACT
vs
APPROVED TARGET DESIGN
```

Codex фиксирует конфликт и просит reclassification approval.

## OBSERVATIONAL

Измеряет состояние.

Например:

```text
performance
monotony
coverage
route statistics
```

Само значение не обязательно означает PASS/FAIL, пока не утверждён budget.

## HISTORICAL

Сохранено для истории спринта.

Не входит автоматически в текущий acceptance.

---

# VI. Evidence Ladder

Одной надписи `PASS` недостаточно.

Создаём уровни доказательства.

## E0 — Parse

Проект запускается без parse errors.

## E1 — Pure Domain

Математика/data contracts проверены без сцены.

## E2 — Integration

Реальные соседние системы работают вместе.

## E3 — Runtime

Система реально существует в `main` или production-equivalent scene.

## E4 — Physics

Реальный велосипед/коллизии взаимодействуют с системой.

## E5 — Vulkan Visual

Настоящий renderer.

Не headless substitute.

## E6 — Soak / Performance

Продолжительный runtime, memory, frame timings, lifecycle.

## E7 — Human Ride

Человек реально проехал участок без debug UI.

AI не имеет права объявлять E7 PASS самостоятельно.

---

# VII. Документационный reset

## PHASE D0 — Documentation Authority Reset

### Цель

Перед новым кодом сделать невозможным ситуацию, когда Codex читает три старых roadmap и выбирает удобную версию истины.

### Создать

```text
docs/TARGET_GAME_BLUEPRINT.md
docs/TARGET_ARCHITECTURE.md
docs/MASTER_IMPLEMENTATION_PLAN.md
docs/LEGACY_MIGRATION_MATRIX.md
docs/TEST_STRATEGY.md
docs/DECISIONS/
```

### Обновить

```text
VISION.md
ARCHITECTURE.md
docs/CURRENT_PROJECT_STATE.md
README.md
AGENTS.md
```

### Изменить роль `implementation_plan.md`

Сейчас этот файл превратился в огромный исторический журнал.

Так больше не делаем.

Он содержит **только один активный ExecPlan**.

После завершения:

```text
docs/plans/completed/<TASK-ID>.md
```

а `implementation_plan.md` очищается под следующую задачу.

### Старые документы

Не удалять без необходимости.

В начало устаревших документов добавить:

```text
STATUS: HISTORICAL / SUPERSEDED
Current source of truth:
...
```

### Acceptance D0

- один однозначный source of truth;
- отсутствуют конфликтующие «следующие этапы»;
- старые документы явно исторические;
- Target Blueprint отражает наш текущий дизайн;
- ни один production `.gd` не изменён.

---

# VIII. Agent Governance

## PHASE D1 — Codex Operating System

### Реализовать

Root/scoped AGENTS.

`.agent/PLANS.md`.

Четыре Codex Skills.

Task specification template.

Review protocol.

### Каждый task должен проходить цикл

```text
OBSERVE
   ↓
PLAN
   ↓
USER APPROVAL
   ↓
IMPLEMENT
   ↓
VERIFY
   ↓
INDEPENDENT REVIEW
   ↓
DOCUMENT
   ↓
COMMIT
```

Не:

```text
prompt
 ↓
1500 lines changed
 ↓
tests green
```

### Git discipline

В начале задачи Codex фиксирует:

```text
HEAD
branch
git status
existing dirty files
```

Никогда не откатывает чужие изменения.

Одна архитектурная задача — одна логическая ветка/commit series.

Никаких unrelated cleanup.

---

# IX. Verification Foundation

## PHASE Q0 — Test Authority Map

Codex проходит текущие tests и создаёт:

```text
docs/TEST_MATRIX.md
```

Для каждого suite:

```text
name
owner system
category
runtime level E0-E7
required for which changes
known limitation
current status
historical or active
```

Не запускать бессмысленно всё подряд.

---

# X. Реальный test launcher

## PHASE Q1 — Bounded Verification Harness

Сейчас часть старых runner может завершиться `exit 0`, хотя проверка фактически неполна.

Нужен небольшой строгий launcher.

Не огромный testing framework.

Каждый run возвращает machine-readable summary:

```text
run_id
revision
seed
suite
expected coverage
actual coverage
assertions
errors
warnings
leaks
timeout
completion marker
result
```

`PASS` допускается только если:

```text
completion == true
expected coverage satisfied
zero unexpected engine errors
zero unexpected leak warnings
all required assertions executed
```

Иначе:

```text
FAIL
```

или:

```text
INCOMPLETE
```

---

# XI. Baseline before migration

## PHASE Q2 — Frozen Baseline

До нового worldgen фиксируем нынешний runtime.

Seeds:

```text
184729
42
77777
```

И несколько дополнительных random seeds.

Сохраняем:

```text
road hashes
generation timings
memory
main-thread frame statistics
fork behaviour
current known failures
Vulkan captures
real rider results
ObjectDB warnings
```

Не ремонтируем всё.

Baseline нужен для сравнения.

### Отдельная обязательная задача

Найти причину текущего:

```text
6 unresolved ObjectDB instances
```

Потому что lifecycle leak опасен для будущего streaming.

---

# XII. Новый world layer начинается

# PHASE R0 — Region Domain Skeleton

Это первая worldgen-фаза.

Никакого render.

Никакого велосипеда.

Никакой дороги.

Создаётся новый независимый namespace, например:

```text
scripts/world/region/
```

Минимальные domain-типы:

```text
RegionPlan
RegionIdentity
RegionBounds
MacroTerrainPlan
```

И query contract.

Seed:

```text
world_seed
region_coordinate
region_seed
```

должны иметь стабильную derivation.

### Проверяем

Same seed/config:

```text
RegionPlan hash A
RegionPlan hash A
RegionPlan hash A
```

Другой seed:

```text
hash B
```

### Запрещено

Подключать старый `MountainMassifField` как скрытый source of truth.

Он может использоваться только как reference fixture.

---

# PHASE R1 — Macro Geography

Теперь создаётся настоящее место.

Первый archetype:

```text
MOUNTAIN_RIVER_VALLEY
```

Domain generator создаёт:

```text
mountain masses
major valley
ridges
saddles
benches
basins
slopes
```

Не просто summed noise.

Правило:

```text
STRUCTURE
   +
NOISE
```

а не:

```text
NOISE
   =
WORLD
```

### Новый terrain preview

Отдельная сцена:

```text
region_preview.tscn
```

Не main game.

Она визуализирует регион tiled `ArrayMesh`.

Сначала uniform resolution.

Без LOD.

Без infinite streaming.

Без vegetation.

### Acceptance

На трёх seed визуально различаются:

```text
гора
долина
склоны
хребты
пространства
```

И нет:

```text
holes
tile seams
NaN
inverted faces
height discontinuities
```

---

# PHASE R2 — Terrain Tile Contract

Отделяем:

```text
TerrainField
```

от:

```text
TerrainRenderer
```

`TerrainField` умеет:

```text
sample_height(x,z)
sample_gradient(x,z)
sample_normal(x,z)
```

`TerrainTileRenderer` только строит mesh.

### Инвариант

Два соседних tile получают границу из одних world-space samples.

Не исправляем seam постфактум.

Seam отсутствует по архитектуре.

---

# PHASE R3 — Hydrology

Добавляем data layer:

```text
HydrologyPlan
```

Сначала:

- одна major river;
- несколько tributaries/creeks;
- drainage relationship;
- valley association.

Река не является просто синей spline поверх terrain.

Она должна влиять на:

```text
terrain
moisture
biomes
future routes
future crossings
```

Render воды можно оставить примитивным.

Сейчас важнее география.

---

# PHASE R4 — Biome + Rideability Fields

Добавляем независимые query:

```text
BiomeField.sample(x,z)
RideabilityField.sample(x,z)
```

Biome учитывает:

```text
altitude
slope
aspect
water distance
moisture
region identity
```

Первый регион:

```text
conifer forest
meadow
river vegetation
autumn woodland pocket
```

Rideability:

```text
OPEN
RIDEABLE
DIFFICULT
BLOCKED
```

или непрерывный cost.

Пока без реальных деревьев.

Debug visualization обязательно.

---

# PHASE R5 — Region Route Planning

Вот здесь появляется принципиально новая система:

```text
RegionRouteGraph
```

Не расширение старого `RoadGraph`.

Он должен поддерживать:

```text
fork
merge
loop
cross-connection
rare dead-end
landmark connector
```

Route hierarchy:

```text
BACKBONE
SECONDARY
SINGLETRACK
TECHNICAL
```

Edge пока означает:

```text
corridor
```

а не финальный spline.

### RoutePlanner видит

```text
terrain slope
gradient
rideability
water
biome
route separation
landmarks
cut/fill estimate
route class
```

### На этом этапе дороги не рендерятся

Debug:

```text
top-down route graph
corridor overlay
cost heatmap
```

### Acceptance

На трёх seeds:

- сеть связна;
- существуют альтернативы;
- нет обязательного backtracking;
- loops действительно существуют;
- редкие dead-end имеют explicit reason;
- backbone пересекает регион логично;
- маршруты не проходят бессмысленно через cliffs/water.

---

# PHASE R6 — Road Synthesis Adapter

Теперь подключаем лучшее из старого проекта.

Создаём boundary:

```text
RouteCorridor
      ↓
RoadSynthesizer
      ↓
RoadPathData
```

Внутри можно переиспользовать:

```text
RoadLogic
RoadMath
RoadGenerationContract
Airborne contracts
части RoadGrammar
```

Но RoadLogic больше не определяет macro direction путешествия.

### Старое RoadGrammar

Не удаляется.

Его роль меняется:

было:

```text
top-level ride generator
```

станет:

```text
local ride geometry vocabulary
```

---

# PHASE R7 — FinalSurface

Самая важная техническая фаза.

Новая единая истина:

```text
FinalSurface.sample(x,z)
```

Состав:

```text
BaseTerrain
+
Hydrology deformation
+
Road deformation
+
Landmark deformation
=
FinalSurface
```

`TerrainCarver` как production owner retire.

Полезная CUT/FILL/SHELF математика извлекается в:

```text
RoadTerrainDeformer
```

### Все используют FinalSurface

```text
render terrain
collision terrain
vegetation placement
prop placement
water banks
off-road queries
```

Больше никаких разных версий высоты мира.

---

# PHASE R8 — First Physical Ride

До этого момента новая система могла жить отдельно от main.

Теперь впервые:

```text
Mountain River Valley
+
one real route
+
existing BicycleController
```

Цель:

примерно 1–2 км настоящей дороги по terrain.

Не forks.

Не landmarks.

Не лес.

### Human Gate

Игрок реально едет.

Проверяем:

- road выглядит встроенной в ландшафт;
- нет floating;
- нет clipping;
- slope чувствуется естественно;
- велосипед не требует изменения physics для маскировки terrain problems.

---

# PHASE R9 — Off-road Surface

Теперь велосипед может физически съехать с дороги.

Делаем near-player collision patches.

Не collider всей горы.

Render terrain и physical terrain существуют независимо по уровню детализации.

Проверяем:

```text
road → meadow
meadow → road
cross slope
small bumps
edge of forest
river boundary
```

### Главный acceptance

Игрок может увидеть луг, свернуть и физически пересечь его.

Вот здесь впервые начинает появляться **настоящая свобода Slow Cycle**.

---

# PHASE R10 — Spatial World Streaming

Только теперь перестраиваем streaming.

Не раньше.

Новый:

```text
WorldStreamer
```

оперирует пространственными cells.

Логические responsibilities:

```text
TerrainTile lifecycle
CollisionPatch lifecycle
RoadSegment lifecycle
VegetationCell lifecycle
Prop lifecycle
Water lifecycle
```

Старый `ChunkStreamer` продолжает существовать через adapter, пока migration не завершена.

После parity — retire.

### Очень важное правило Godot

Worker thread готовит:

```text
plain data
height arrays
mesh arrays
transforms
plans
```

Main thread делает:

```text
scene tree
physics objects
resource commit where required
```

Параллелизм добавляется **после profiling**, а не заранее.

---

# PHASE R11 — Regional Vegetation

Полностью новая placement semantics.

Было:

```text
road sample
 → left/right
 → tree
```

Станет:

```text
BiomeField
TerrainField
Moisture
Slope
ForestDensity
ClearingMask
RoadExclusion
      ↓
VegetationCell
```

Rendering:

```text
MultiMesh per spatial cell + type
```

Не один MultiMesh на регион.

`ChunkFoliage` можно retire после переноса полезного MultiMesh instantiation.

---

# PHASE R12 — Water + Environmental Traces

Теперь оживляем region.

Water:

```text
river
creeks
small crossings
```

Human traces:

```text
forest road
wood bridge
old signs
small hut
fence
bench
minor utility traces
```

Без NPC.

Без quests.

Каждый объект должен иметь географическую причину существования.

---

# PHASE R13 — Full Route Network Gameplay

Теперь включаем:

```text
secondary roads
singletracks
technical lines
loops
merges
bridges
route reconnections
```

Старый fork pipeline больше не является хозяином topology.

`ForkDecisionModel` оцениваем заново.

Если он полезен для мягкого определения текущего route context — ADAPT.

Если свободный movement делает его ненужным — RETIRE.

Не сохраняем его только потому, что в него вложено время.

---

# PHASE R14 — Exploration Layer

Добавляем:

```text
Macro landmarks
Meso landmarks
Micro landmarks
```

Первый набор:

```text
mountain
river
high meadow
bridge
creek
hut
rock outcrop
viewpoint
```

Landmark planner работает с RegionPlan.

Не renderer случайно расставляет POI.

---

# PHASE R15 — Vista Planner

Это отдельная система.

Она знает:

```text
viewpoint
view direction
foreground
midground
landmark
occlusion budget
```

Она может влиять на:

```text
vegetation clearing
route placement
landmark placement
```

Но не меняет физику велосипеда.

Проверяем реальные Vulkan captures.

---

# PHASE R16 — Journey Director

Только теперь.

Потому что режиссировать бессмысленно, пока нет мира и маршрутов.

Он управляет macro pacing:

```text
CALM
DISCOVERY
FLOW
INTENSITY
RELEASE
WONDER
```

Но не диктует игроку выбор.

И не генерирует spline напрямую.

Он создаёт intents.

Например:

```text
"нужен длинный calm stretch"

"после этого желательно discovery opportunity"

"после technical section не ставить ещё один technical section"

"следующая vista может быть payoff"
```

RoadGrammar остаётся локальным исполнителем ride geometry.

---

# PHASE R17 — Ride Situation Library

Формализуем уже обсуждавшийся словарь:

```text
Cruise
Flow Descent
Forest Weave
Climb
Fast Sweeper
Rollers
Creek Crossing
Ridge Traverse
Technical Pocket
Meadow Freedom
Reveal Descent
```

Каждая ситуация:

- имеет terrain prerequisites;
- имеет safety envelope;
- имеет характер езды;
- имеет visual telegraphing;
- имеет entry/exit contract.

Она не является prefab куском дороги.

Она адаптируется к миру.

---

# PHASE R18 — Mountain River Valley Vertical Slice

Теперь собираем всё.

Цель:

**20–30 минут полноценной поездки.**

Не debug demo.

И не engineering track.

Регион содержит:

```text
mountain
river valley
creeks
conifer forest
meadows
autumn pocket
backbone
secondary roads
singletracks
technical option
loops
rideable open terrain
landmarks
vistas
human traces
```

### Human Acceptance

Без F3/debug UI.

Игрок должен:

1. несколько раз самостоятельно выбрать направление;
2. хотя бы один раз изменить план из-за увиденного;
3. получить спокойную езду;
4. получить интересную езду;
5. реально съехать с основной дороги;
6. встретить минимум одну значимую альтернативную петлю;
7. получить минимум один сильный reveal;
8. ощущать разные части региона как разные места;
9. не испытывать обязательного раздражающего backtracking;
10. хотеть продолжить поездку.

Если automated tests PASS, но эти условия не работают — vertical slice FAIL.

---

# PHASE R19 — Performance & Streaming Hardening

До этого момента optimization была локальной и измеряемой.

Теперь полноценный hardening:

```text
terrain LOD
far terrain
collision distance
vegetation distance
generation jobs
worker queues
resource lifecycle
memory budgets
object pooling where justified
shader cost
draw calls
MultiMesh cell size
streaming hitch profiling
```

Сначала measurement.

Потом optimization.

Никаких «оптимизировал» без before/after.

---

# PHASE R20 — Region Diversity

После одного хорошего региона.

Не раньше.

Создаём дополнительные archetypes:

```text
Taiga River Region
Autumn Highlands
Forest Hills
Open Mountain Meadows
```

Они используют одни системные слои.

Не четыре отдельных генератора.

---

# PHASE R21 — Region Continuation

Теперь решаем долгую поездку.

Регион становится крупной процедурной единицей.

Следующий region создаётся с совместимыми boundary conditions.

Получаем:

```text
Region A
   ↓
transition
   ↓
Region B
   ↓
transition
   ↓
Region C
```

Игрок воспринимает это как долгую непрерывную поездку.

Только здесь возвращаемся к настоящей «бесконечности».

---

# XIV. Что НЕ делаем до Vertical Slice

Запрещено преждевременно добавлять:

```text
complex terrain clipmaps
voxel terrain
third-party terrain framework
NPC
quests
inventory
progression
bike upgrades
map full of icons
weather simulation
season simulation
huge POI library
advanced save world persistence
multiplayer
complex traffic
walking mode
```

Если идея не помогает `Mountain River Valley Vertical Slice`, она откладывается.

---

# XV. Godot-specific engineering rules

Проект остаётся на Godot 4.7 / Forward+.

## Terrain

CPU-generated `ArrayMesh`.

Initial terrain:

```text
fixed world-space tiles
uniform initial resolution
```

LOD добавляется только после рабочего slice.

## Foliage

`MultiMesh`.

Но spatially divided.

Никаких десятков тысяч отдельных tree Nodes.

## Collision

Detailed collision существует возле игрока.

Далёкая гора не обязана иметь detailed collider.

## Threads

Worker:

```text
math
sampling
planning
array preparation
```

Main:

```text
scene tree
physics
runtime commit
```

Никаких shared mutable world structures между threads без явного synchronization.

## Profiling

Codex не имеет права вводить complex multithreading только потому, что «procedural generation может быть тяжёлой».

Сначала фиксируется stall.

Потом устраняется.

---

# XVI. Definition of Done для КАЖДОЙ задачи

Task не завершён, пока нет:

```text
approved ExecPlan
scope compliance
implementation
targeted tests
negative tests where meaningful
integration check
verification report
independent review
git diff audit
documentation update
known limitations
next dependency
```

Для visual/world задач также:

```text
real Vulkan capture
```

Для ride/collision:

```text
real physics
```

Для product milestone:

```text
human evaluation
```

---

# XVII. Формат отчёта Codex

Каждая задача заканчивается одинаковым отчётом:

```text
TASK:
REVISION:

Implemented:
-

Not implemented:
-

Files changed:
-

Architecture:
KEEP:
ADAPT:
REPLACE:
RETIRE:

Verification:
E0:
E1:
E2:
E3:
E4:
E5:
E6:
E7:

Tests changed:
-

Existing tests reclassified:
-

Known failures:
-

Performance:
-

Artifacts:
-

Reviewer result:
PASS / REJECT

Technical debt introduced:
-

Next safe task:
-
```

Это резко уменьшит красивые, но бесполезные AI-отчёты.

---

# XVIII. Первый конкретный пакет работ

Не начинаем `RegionPlan` завтра же.

Первая цепочка должна быть:

```text
D0 Documentation Authority Reset
      ↓
D1 Codex Governance + Skills
      ↓
Q0 Test Authority Map
      ↓
Q1 Verification Harness
      ↓
Q2 Frozen Baseline + ObjectDB investigation
      ↓
R0 Region Domain Skeleton
```

Это осознанно медленное начало.

Но после него огромная последующая работа становится значительно безопаснее.

---

# XIX. Первое задание Codex

После того как этот Master Plan сохранён в репозитории, новый чат Codex получает только это:

> Прочитай корневой `AGENTS.md` и текущие source-of-truth документы.  
> Мы начинаем только `D0 — Documentation Authority Reset`.  
> Production-код `.gd`, сцены и ресурсы игры не изменять.  
> Проведи аудит актуальной документации репозитория относительно `TARGET_GAME_BLUEPRINT` и `MASTER_IMPLEMENTATION_PLAN`.  
> Определи какие документы являются current, historical, contradictory или redundant.  
> Подготовь новый `implementation_plan.md` для D0 с точным списком создаваемых/изменяемых документов, ссылочной структурой, source-of-truth hierarchy, migration старых документов и проверками ссылок/противоречий.  
> Ничего не реализуй. После подготовки плана остановись и представь его на согласование.

Только после проверки этого плана даём:

```text
PROCEED D0
```

Именно так я бы начал новый этап Slow Cycle.