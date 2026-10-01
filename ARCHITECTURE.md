# Slow Cycle — Architecture and Generation Boundaries

> Сверка 01.10.2026, `b6a5ff4`, WORLD-00A: [актуальное состояние и карта источников](docs/CURRENT_PROJECT_STATE.md). Текущие границы ниже уточнены по исходникам. Исторические метрики последующих разделов не перепроверялись; ощущения поездки, безопасность и визуальное качество требуют engine/ride-подтверждения.

## 1. Purpose and source of truth

Use `docs/CURRENT_PROJECT_STATE.md` as the current entry point and `docs/WORLD_GENERATION_GLOBAL_PLAN.md` for the sequential product direction. `DEVELOPMENT_ROADMAP.md` preserves the previous product path; `ROAD_GENERATION.md` records geometry requirements, including unresolved mismatches with code; the opening block of `implementation_plan.md` owns the active task; `TEST_PLAN.md` preserves check instructions and historical outcomes. `AGENTS.md` and `.antigravity/rules/test-integrity.md` remain mandatory.

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
6. `RoadChunk` consumes committed road samples. `TerrainCarver` shapes local roadside strips from the same centerline plus seeded lateral relief. `MountainMassifField` contributes height differences between the road center and flank; the mesh remains road-relative. There is no independent world-covering XZ terrain mesh or route fitting to this field yet.
7. The bicycle observes world collision and its own telemetry signals. It does not participate in route generation and is not changed by world generation refactoring.

### 2.1. Целевые слои мира и текущая граница реализации

Следующая схема задаёт направление разработки, а не полностью работающий production-конвейер. В текущем коде поле гор используется придорожным карвером; генератор пути не выбирает маршрут по нему.

```mermaid
flowchart TD
    L0["Слой 0: Геологическое тело горы (Macro Mountain Field)"] -->|2D поле высот H(x,z), уклоны, биом| L1["Слой 1: Кинематический путь и ритмика (Route & Grammar)"]
    L1 -->|Траектория P(s), радиусы, ширина полотна| L2["Слой 2: Инженерная врезка полотна (Roadbed Carver)"]
    L0 -->|Высота рельефа на флангах| L2
    L2 -->|Геометрия полотна и скальных откосов| L3["Слой 3: Окружение и декорации (Environment & Props)"]
    L2 -->|Collision bit masks 2 road / 4 terrain| L4["Слой 4: Физика и игрок (BicycleController)"]
```

#### Целевые контракты изоляции слоев:
1. **Слой 0 (Macro Mountain Field):** Чистая математика $H(x, z)$ и градиент $\nabla H(x, z)$ по сиду. Не имеет зависимостей ни от нод сцены, ни от полотна дороги, ни от физики.
2. **Слой 1 (Route & Grammar):** Генерирует $C^1$-непрерывную осевую линию дороги $P(s)$, ширину $w(s)$, крен полотна и развилки. Опрашивает Слой 0 для выбора естественного спуска по полкам долины, сохраняя автономность математики сплайна.
3. **Слой 2 (Roadbed Carver):** Принимает геометрию пути $P(s)$ и тело горы Слой 0. Выполняет инженерную выемку (Cut) и насыпь (Fill), строит меш дороги и скальных откосов с разнесением высот (Beveled Verge, ступенька 3–4 см).
4. **Слой 3 (Environment & Props):** Расставляет деревья, валуны. Маркерные вешки, защитные столбики и указатели полностью исключены из игры (Zero-Post Mandate). Высота посадки берется строго из полигональной поверхности Слоя 2. Расстановка жестко заблокирована в коридоре безопасности $w(s)/2 + 1.2$м.
5. **Слой 4 (BicycleController):** Потребитель коллизий. Для поверхности используются битовые маски 2 (дорога, Godot layer 2) и 4 (земля, Godot layer 3); маска 16 дополнительно обозначает rough road. Никакой код террейна не проникает внутрь контроллера.

#### Состояние решений прежнего Sprint 7 на 01.10.2026:
- **Ликвидация «стрел в небе» (Adaptive Curvature Clamping):** Внутренняя кромка юбки адаптивно сжимается на виражах:
  $$d_{\text{inner}}(s) = \min\left(W_{\text{FAR}}, \max\left(8.0, R(s) \cdot 0.70\right)\right)$$
  Это историческое описание намерения. Текущий `TerrainCarver` использует `W_FAR = 38м` и другую формулу сжатия (`pow(t_k, 0.35)`); приведённая формула не описывает текущую реализацию и не доказывает отсутствие складок. Требуется визуальная проверка.
- **Инженерная фаска обочины (Beveled Verge):** Профиль дороги приподнимается над основанием обочины на микро-ступеньку (фаску) высотой 3–4 см:
  - Вершина кромки полотна: $P_{\text{road}} = P_{\text{center}} \pm \mathbf{b} \cdot \frac{w}{2}$
  - Дно водоотводной канавки обочины: $P_{\text{ditch}} = P_{\text{center}} \pm \mathbf{b} \cdot \left(\frac{w}{2} + 0.35\right) - \mathbf{n} \cdot 0.04$
  - Текущая фаска задаётся `VERGE_STEP_HEIGHT = 0.035м` в `TerrainCarver`. Отсутствие Z-fighting и заступов на всех маршрутах этим обзором не подтверждено.
- **Разделение бюджетов Near vs Far — не реализовано:**
  - `RoadChunk.commit()` передаёт весь `prep.terrain_faces` в `ConcavePolygonShape3D`; битовая маска земли — 4 (Godot layer 3).
  - Отдельного near-only terrain collider нет. Прежнее утверждение о снижении нагрузки на 65% не подтверждено текущей реализацией/замером.
- **Прецизионная посадка объектов (Props Alignment) & Zero-Post Mandate:**
  - Полный демонтаж столбиков и вешек: никаких столбиков и дорожных знаков на полотне и обочине.
  - Стволы деревьев утапливаются на 10 см по реальному сечению $Y_{\text{terrain}}(s, d_{\text{lat}})$.
- **Граница местности и туман:**
  - Текущий внешний фланг: `W_FAR = 38м`; это ограниченная дорожная лента, не поверхность всего мира.
  - `forest_env.tres` задаёт `fog_depth_begin = 32м`, `fog_depth_end = 115м`. Туман не служит подтверждением отсутствия пустот за границей меша.

## 3. Implemented contract versus target architecture

| Concern | Implemented now | Later target |
|---|---|---|
| Determinism | Seeded world/profile/grammar/fork streams exist; full replay across streaming/branch schedules is not freshly verified | Preserve deterministic geometry and foliage independent of generation scheduling |
| Large terrain shape | 1D `MountainProfile` contributes a bounded elevation overlay; `TerrainCarver` uses 2D `MountainMassifField` height differences for road-relative flanks | One shared seeded 2D field and final surface used by surrounding terrain and trail planning |
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

The initial baseline exposed one actionable documentation/geometry mismatch: the two
marked crest micro-drop samples spanned about 4 m and fell **0.552–0.608 m** across the
four catalogue seeds, while the builder comment stated `h <= 0.35m`. B3b corrected this
locally without loosening the validator. The measured tangent vs chord grade difference
is a separate profile metric. The B4 boundary audit found no chunk-seam mismatch; it neither classifies that sample-to-chord difference as a defect nor certifies the longitudinal profile.

B3b removed the extra per-point vertical offset and reduced only the marked crest
profile slope from −7° to −4.5°. The measured fall is now **0.181–0.238 m** across
12 fixed seeds, with the two `MICRO_DROP` samples and contact states preserved. The
test enforces `0 < fall <= 0.35 m`; airborne, switchback, and recovery production
builders were left unchanged. This is a bounded longitudinal road-profile feature,
not a cross-slope or an open mountain landform.

## 9. Stage B4 road/terrain chunk seam audit

`test_road_event_chunk_seams.gd` builds real `RoadLogic` event sequences, then prepares
neighboring inclusive `RoadChunk` ranges from the same path and shared endpoint. For
36 boundaries across four seeds and four event sequences it checks seam C0/C1/slope/normal, road edge vertices,
the actual roadside terrain boundary cross-section in both prepared mesh buffers and
collision face blocks, plus face finiteness and non-degeneracy. All 96 assertions passed
with zero boundary position/frame or mesh/collision row error.

This is CPU geometry preparation evidence. It does not register live PhysicsServer
colliders, query the bicycle wheels or prove whole-route clearance; those remain B5/B6
checks. No production geometry changed in B4.

## 10. Collision layers

The bicycle queries the existing road and surface layers through its configured collision mask. Road generation and physics contracts are coupled at the collision interface only; P2.1 does not edit that mask or tune wheel raycasts.

| Godot layer | Name | World purpose |
|---|---|---|
| 2 | Road | Packed road surface |
| 3 | Grass / terrain | Local roadside terrain and verge surface |
| 4 | Player | Bicycle character body |
| 5 | RoughRoad | Rough road surface |

## 11. Legacy feature traceability

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

## 12. Biome Data Flow & Cross-System Coupling (Sprint 6 v4)

To prevent visual and physical isolation between road geometry, roadside carving, and vegetation, Sprint 6 v4 formalizes the unified continuous biome pipeline:

```text
MountainProfile (get_mountain_weight_at(s) ∈ [0.0, 1.0])
       │
       ▼
   RoadLogic (speed envelopes, curvature limits, clothoid transitions)
       │
       ▼
  ChunkStreamer (fork interval pacing: 200–350m mountain vs 450–650m forest)
       │
       ├──► TerrainCarver (mountain_weight drives CUT/SHELF/CLIFF, |dh| ≥ 1.5–3.5m,
       │                   plus 45m outer terrain skirt descending toward horizon)
       │
       └──► ChunkFoliage (mountain_weight selects alpine bonsai/scree vs dense forest,
                          strictly enforcing ≥ 2.5m clearance corridor from road centerline)
```

- **Data Flow Contract**: `MountainProfile` is the single source of biome weight. `mountain_weight` is computed from the 200m rolling grade window and passed downstream to all chunk generation passes.
- **Terrain Carver Coupling**: In mountain zones (`mountain_weight > 0.65`), even straight sections generate rock cuts and dramatic shelves. In forest zones (`mountain_weight < 0.35`), gentle ditches and rolling meadows prevail.
- **Foliage Density & Safety Zone**: Trees, shrubs, and boulders are placed via chunk-local `MultiMeshInstance3D` nodes. All trunks and solid obstacles are strictly banned within $2.5$m of the road centerline.

---

## 13. Curvature Synthesis, Adaptive Macro-Heading & Soft-Repair Architecture

> Предел 19м и ограничение fatal fallback ниже — требования AGENTS, а не доказательство их выполнения. В коде `RoadGenerationContract.MIN_RADIUS = 18м`; `RoadLogic` вызывает conservative fallback после любой неуспешной повторной валидации без проверки класса ошибки. Расхождения открыты, код в WORLD-00A не менялся.

Sprint 6 v4 removes historical straightfall traps (the 400m opening curtain and 450m post-fork queues) and adopts perceptual curvature dynamics:

1. **Perceptual Curvature Noise**:
   - `FastNoiseLite` frequency is tuned to $f \in [0.020, 0.024]$ (nominal $0.022$).
   - Semi-wavelength is $\sim 25$m, yielding lateral S-sweeps of $12\text{–}18$m (instead of imperceptible $1.5$m oscillations of high-frequency $0.12$ noise).
   - Target radius cascade: speed sweepers $R \in [45, 70]$m, medium carvers $R \in [25, 35]$m, tight switchbacks $R \in [19, 22]$m. Minimum design radius is strictly $R \ge 19.0$m.

2. **Adaptive Macro-Heading $\theta_{\text{macro}}$**:
   - Replaces the legacy rigid south constant ($180.0^\circ$).
   - Dynamic course tracking:
     $$\theta_{\text{macro}}(s) = \text{lerp\_angle}(\theta_{\text{macro}}, \theta_{\text{actual}}, 0.015 \cdot ds)$$
   - Allows the road to contour naturally around mountain massifs without artificial spring-back straightening.

3. **Soft-Repair Geometry Validator**:
   - **Ban on Silent Fallback**: The destructive `_generate_conservative_safe_chunk()` (silent replacement with a straight line) is prohibited.
   - **In-Place Clothoid Clamping**: If a candidate turn exceeds physical curvature or lateral jerk bounds, it is smoothly clamped to $R = 19.0$m while preserving the turn direction and continuity.
   - **Fatal Fallback Scope**: Straight fallback is restricted exclusively to seam tears ($\Delta p > 1$mm) or floating-point non-finiteness (NaN/Inf), and must trigger an explicit alert in `[GEOM]`.

4. **Free Launch & FSM Pacing**:
   - The opening uses a 15m horizontal launchpad (for wheel physics stabilization) followed by a 25m acceleration chute (grade $-4^\circ \dots -6^\circ$).
   - Beyond 40m, the procedural FSM takes over immediately. Initial curve direction is seeded 50/50: `rng.randf() < 0.5 ? 1.0 : -1.0`.
   - Post-fork routes never populate static chunk queues; `set_route_style()` modifies FSM transition weights (`FLOW` vs `TECHNICAL`), keeping generation 100% procedural.

---

## 14. Perception Calibration — Camera Ride Feel & Kinematic Steer Limits

Visual perception and physics are calibrated to reflect mountain steepness and cornering dynamics:

1. **Camera Horizon Tilt (65% Coupling)**:
   - Third-person and cockpit camera horizon stabilization is adjusted from $0.35$ to $0.65$. At a $24^\circ$ bicycle lean, the camera tilts $15.6^\circ$, conveying high-speed cornering energy without motion sickness.
   - Asymmetric critical damping eliminates jitter and nauseating roll whip.

2. **Visual Pitch Transmission**:
   - The camera X-rotation now couples directly with `visual_pitch` (ground-plane pitch). Steep downhill sections ($-10^\circ \dots -14^\circ$) are visibly perceived as steep descents with the valley floor opening below.

3. **Field of View (FOV)**:
   - Текущие defaults `BikeCamera`: кокпит $78^\circ \dots 83^\circ$, третье лицо $68^\circ \dots 72^\circ$. Прежнее описание $70^\circ \dots 75^\circ$ не соответствует коду. В WORLD-00A камера не перенастраивалась.

4. **Текущий предел руления**:
   - `BicycleController.high_speed_steer_limit = 0.045` rad. В `bicycle.tscn` override до 0.062 не найден.
   - Проходимость конкретного радиуса на скорости требует настоящего физического заезда; она не выводится из прежнего описания настройки.

---

## 15. Observability, Diagnostics & Structured Telemetry

Статус по коду на 01.10.2026 после WORLD-00-LOG: обычная main создаёт диагностическую сессию. Это ограниченный geometry replay, не input/physics recorder.

1. **`SlowCycleLogger` (`scripts/core/slow_cycle_logger.gd`)**:
   - Один Node owner под WorldManager, создан после разрешения requested/effective seed, до RoadLogic/streamer. `run_id` содержит UTC время, PID и случайный suffix; RNG геометрии не затрагивается.
   - Ring 5000 строк сохраняется в diagnostics.log; manifest/events.jsonl держат header, choices/checkpoints и редкие события отдельно. Каждый запуск в user://slow_cycle_sessions или --diagnostics-root. Старые static log/flush API сохранены; legacy flush без owner всё ещё пишет прежний diagnostics log.
   - Авто-flush раз в 2 с и явный flush при checkpoint/problem/scene exit/window-close request. Последний доступный live snapshot сохраняется при teardown. Hard kill/полный crash recovery не реализованы. I/O error даёт код/путь и INCOMPLETE; SESSION_CLOSED описывает только запись.
   - Manifest: фактический seed/config, Godot/renderer, git revision/dirty, SHA256 и копии конкретных 48 runtime files. Данные player/path отсутствуют явно; surface_checked=false. Ближайший sample не выдаётся за точную физическую дистанцию.
   - Подключены SESSION_START/END, FORK_COMMIT/CHOICE, GEOM с реальными emitter violations/stats до перезаписи report, явный PROBLEM API. Все terrain hits и push_error движка автоматически не перехватываются; внешний engine log нужен отдельно. Покадровая BIKE/TERRAIN телеметрия не записывается.
   - Replay inputs ограничены 128 шагами; overflow отмечает replay_complete=false. Runner сверяет source/config/seed/fork и signatures непустых checkpoints, телепортирует тестовый велосипед; физика не воспроизводится. Синхронизации потоков нет. Подробнее [отчёт LOG](docs/sprints/world_00_logs_verification_report.md).

2. **F3 Debug HUD (`scripts/ui/debug_hud.gd`)**:
   - Live runtime overlay showing: Seed, active biome & `mountain_weight`, instantaneous curve radius $R$, adaptive $\theta_{\text{macro}}$, slope grade, lateral $a_{\text{lat}}$, bicycle banking $\phi_{\text{bike}}$, and camera roll/pitch.

---

## 16. Entry points and references

- `project.godot` starts `res://scenes/mode_select.tscn`; `res://scenes/main.tscn` hosts the ride.
- Current status and source map: [CURRENT_PROJECT_STATE](docs/CURRENT_PROJECT_STATE.md).
- Sequential direction: [WORLD_GENERATION_GLOBAL_PLAN](docs/WORLD_GENERATION_GLOBAL_PLAN.md); previous product stages: `DEVELOPMENT_ROADMAP.md`.
- Geometry/event limits and P0–P2 behavior: `ROAD_GENERATION.md`.
- Current sprint plan and actual execution log: `implementation_plan.md`.
- Reproducible test commands, results and limits: `TEST_PLAN.md`.
- Current handoff summary: `MTB_WORLD_GENERATION_HANDOFF.md`.

## Изменение поверхности C03–C04 — 01.10.2026

RoadChunk сохраняет прежние вершины/дорогу/RNG и выдаёт terrain strip/wedge indices по Godot CW; collision faces повторяют эти треугольники. PreparedChunkData хранит фактический first/count splitter wedge. Culling материалов сохранён. Contact watchdog считает missing_ground и checked_contacts; прежние +0.05/−0.35 м сохранены. Реальные committed MultiMesh/collision проверены обеими arm на трёх seed; это не terrain-only поверхность мира. [Отчёт](docs/sprints/world_00_c03_c04_verification_report.md).
