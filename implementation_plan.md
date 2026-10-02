# D1 — Codex Governance & Operating Protocol

Дата: 02.10.2026 (Asia/Qyzylorda). **Статус: PLAN_ONLY / AWAITING_HUMAN_REVIEW_AND_APPROVAL.**

Это единственный предлагаемый active ExecPlan D1. Разрешена только подготовка этого файла. Создание инструкций, skills и изменения других документов ниже — будущая реализация после отдельного approval. Наличие плана, завершённый D0 и зелёные проверки не являются таким approval.

## 1. Goal и STOP

Создать компактный governance для следующего Codex session: нужные правила обнаруживаются, worldgen остаётся независимым от player/runtime, значимая работа сначала планируется, verification подтверждает фактическое покрытие, независимый review может отклонить реализацию при зелёных тестах.

**Сейчас: исследование → новый implementation_plan.md → представление человеку → STOP.** Не создаём AGENTS, PLANS или skills; не реализуем D1, Q0/Q1/Q2/R0. Этот план не проектирует поля RegionPlan, serialization, seed hash algorithm, новые gameplay/world schemas или runtime API.

Уточнение пользователя заменяет рекомендации Master §§III/IV/V/VIII в области D1: ровно три skills; отдельного `slow-cycle-plan` нет; планирование использует native Codex Plan Mode, root AGENTS gate и `.agent/PLANS.md`; классификация существующих suites остаётся Q0.

## 2. Зафиксированное Git-состояние и база

Репозиторий: `C:/Users/Luisa/Documents/antigravity/goofy-chandrasekhar`.

Первоначальная подготовка D1: branch `docs/d0-authority-reset`, HEAD `83bcbfeafdf05dd3174e9f482319147d2614bcb5`, чистое working tree без dirty/untracked; D1 branch создана от этого завершённого D0. До Git-консолидации local `main` указывал на `ed7d1322da1a5700a8c64425708e1c813213c7f6` и отслеживал `origin/master`; локального `master` не было. Remote master указывал на `b63815c26e344970abf8054a48ae963c64428d95`.

### Git-консолидация 02.10.2026 — частично выполнена; remote write заблокирован

Пользователь отдельно разрешил безопасный fast-forward принятого D0 в master, обычный push и удаление только полностью сохранённых старых веток. Это разрешение относится к Git-консолидации, **не к реализации D1**.

| Проверка / состояние после локальных действий | Фактический результат |
|---|---|
| Current branch | `docs/d1-codex-governance` |
| D1 base — local `master` | `83bcbfeafdf05dd3174e9f482319147d2614bcb5` |
| D1 HEAD | `83bcbfeafdf05dd3174e9f482319147d2614bcb5` |
| Local `master` | Создан от `origin/master`, затем fast-forward до принятого D0; без нового merge commit |
| Remote `origin/master`, проверен fetch | `b63815c26e344970abf8054a48ae963c64428d95`; D0 пока не опубликован в master |
| `master` относительно `origin/master` | 2 ahead / 0 behind: bootstrap `ed7d132…` и D0 reset `83bcbfe…` |
| D1 committed diff относительно local master | Пусто; обе ветки на одном принятом D0 tip |
| D1 working-tree diff относительно local master | Только `implementation_plan.md`, PLAN_ONLY |
| `git status --short --branch` | `## docs/d1-codex-governance` и ` M implementation_plan.md` |
| Staged / untracked / stash | Отсутствуют; единственный worktree — основной repository |
| Local branches | `master`, `main`, `docs/d0-authority-reset`, `docs/d1-codex-governance` |
| Remote branches | `master`, `docs/d0-authority-reset`, `codex/review`; `origin/HEAD` → `origin/master` |
| Remote push | Обычный `git push origin master:master` отклонён HTTP 403: запись запрещена для `guardokaz39-del` |
| Connected GitHub API | Та же учётная запись; repository permission `push: false`; default branch `master` |
| Branch cleanup | Не выполнен: старые ветки сохраняются до успешного push и повторной проверки origin/master |

D0 — проверенное чистое продолжение прежнего origin/master: ровно 2 commits ahead / 0 behind; production/test `.gd`, `.gd.uid`, scenes/resources/project и frozen rule в этих двух commits не менялись. Local main bootstrap commit уже достижим из D0; уникальных commits относительно D0 нет. Remote codex/review `398b8238ce38b5c45677f6e9226b86e1432a1d95` — предок прежнего origin/master (0 ahead / 24 behind), уникальных commits нет. Local/remote D0 tips совпадают с новым local master. Эти доказательства позволяют последующую очистку после успешного remote обновления, но сейчас ветки не удалены.

Точная копия исходного D1 plan и full-index binary diff сохранены вне repository/worktree в workspace чата `work/git-consolidation/`. Исходный D1 plan SHA256: `4DB658CA5E2A1176B7F365CD200FA1D29DAFE25B90323D8F28D6CE5FD760E936`. После переключений план восстановлен с тем же SHA256; затем изменён **только этот Git/base-state раздел**. Остальной текст сохранён побайтово. D1 commits/push/PR не создавались; published history не переписывалась.

После предоставления GitHub-доступа с правом push: повторить fetch/ahead/behind audit, выполнить обычный fast-forward push local master, проверить принятую D0 на origin/master, затем удалить только достижимые из нового master main/D0/review refs. Не выполнять force push/rebase/reset --hard/git clean. До этого remote целевое состояние не достигнуто и консолидация не объявляется завершённой.

Исходные SHA256 защищённых файлов и D0 plan slot:

- `AGENTS.md`: `BA4F833C3953F936781B6BD4197B68A515ED582498F8B63264EB144FB69B2DBD`.
- `.antigravity/rules/test-integrity.md`: `4853ACF1B4DCD2666BC175CBB8EB932AD89931107B1CCA2E06A529A298338733`.
- D0 `implementation_plan.md` (NO_ACTIVE_PLAN): `3B2A3BDEBEC4E51D9A8C30234E9EF08A2397CC3B176AEF321061C62A4F1A67AC`.

Служебный tracked paths/hashes snapshot находится вне репозитория в workspace чата. Он не является Q2 runtime baseline. На старте консолидации единственной незакоммиченной работой был сохранённый D1 plan; чужие dirty/untracked changes отсутствовали.

## 3. Observed current state: документы и реальные boundaries

Изучены обязательные sources: Blueprint, Master, Target Architecture, Test Strategy, Legacy Migration Matrix, Current Project State, root AGENTS, прежний implementation_plan и frozen test-integrity. Проверены inventory трёх указанных каталогов, объявления классов, зависимости и характерные участки runtime/domain/tests. Исторический журнал и весь архив спринтов повторно не исследовались.

| Область / конкретный source | Наблюдение, значимое для D1 |
|---|---|
| `scripts/world/`: 23 `.gd` | Domain-логика преимущественно RefCounted: RoadLogic/Grammar/Graph/PathData, RouteIntent/RoutePlan, fork planners, TerrainCarver, MountainProfile/MassifField, ChunkFoliage. WorldManager, ChunkStreamer и RoadChunk — Node3D runtime boundary. Это факты типов/зависимостей, не сертификат чистоты или thread safety всего каталога. |
| `world_manager.gd:23`, `:45`, `:74` | Composition/runtime root создаёт RoadLogic, streamer, shared resources и diagnostics, выбирает effective seed, передаёт player position/velocity. Выбор нового session seed допускается до генерации; effective seed записывается. D1 не запрещает эту существующую игровую опцию и не меняет её. |
| `road_chunk.gd:19`; `chunk_streamer.gd:328` | PreparedChunkData и prepare/commit уже разделяют arrays и scene registration. Streamer владеет branch/chunk lifecycle; это не будущий spatial WorldStreamer и не доказательство реально используемых workers. |
| `route_plan.gd:13` | `RoutePlan.from_road_path` строит измеренный результат legacy RouteIntent leg из RoadPathData/телеметрии. Это не RegionRouteGraph, RouteNetworkPlan или terrain-first route planning. Название не делает его будущим владельцем региона. |
| `road_graph.gd:263` | Реальный strict DAG validator; loops/merges новой архитектуры не внедряются исключениями в legacy DAG в D1. |
| `terrain_carver.gd:25`; `chunk_foliage.gd:34` | W_FAR=38 и road-relative cross-section/placement; локальный RNG seeded через logical key. Полезная pure math сама по себе не означает правильный target ownership. |
| `road_generation_contract.gd:25`; `road_logic.gd:176` | Code MIN_RADIUS=18, conservative fallback существует; root Rule 6 требует 19 м и более узкую область fatal fallback. Конфликты уже записаны D0, D1 их не чинит и не нормализует числа под код. |
| `scripts/player/`: 1 `.gd` | BicycleController — CharacterBody3D; публичные `telemetry_updated(speed_kmh, cadence_pct, is_coasting)`, `bell_rung`, существующие properties, collision/query/recovery boundary. Player владеет kinematics и visual transforms. |
| `scripts/camera/bike_camera.gd`; `scenes/player/bicycle.tscn` | Camera и часть player configuration находятся вне `scripts/player/`. Scoped player AGENTS недостаточно: root protection обязателен для camera, controls, scene/resource/input settings тоже. |
| `scripts/test/`: 66 `.gd` | Здесь смешаны SceneTree runners, physical rider, generators/labs, captures, RefCounted audit helpers, contract/negative fixtures и diagnostics. Счётчик файлов — inventory текущего дерева, не suite classification, coverage или результат тестов. |
| `test_sprint_4m_master.gd:86` | Subprocess exit 0 прибавляет expected assertion budget. Это не measured assertion count/completion всех внутренних checks. D1 требует честного report; исправление runner относится к Q1, не D1. |
| `test_virtual_rider_bot.gd:27`; `test_route_plan_contract.gd:30`; `test_capture_audit_contract.gd:30` | Уже есть real main/Input/physics, repeated/reordered seed checks и negative reason fixtures. D1 сохраняет эти инструменты; никакая категория им здесь не назначается. |

Scoped AGENTS/PLANS/repo skills сейчас отсутствуют: найден только root AGENTS. `AGENTS.override.md` и дополнительные AGENTS по проверенным родительским путям не найдены; global `C:/Users/Luisa/.codex/AGENTS.md`/override также не обнаружены. User settings/config полностью не аудировались: нельзя заявлять, что нет глобально отключённых skills или нестандартных лимитов discovery.

Codex CLI executable обнаружен. Новые session discovery probes сейчас не запускались, поскольку целевые инструкции ещё не созданы и D1 не одобрен.

Current state сохраняет общую runtime acceptance **INCOMPLETE** и датированные ObjectDB/route/junction/valley/fallback/landing findings. D1 не воспроизводил их; документационный PASS не закрывает эти failures.

## 4. Target behaviour, ownership и dependency direction

Цикл значимой задачи: OBSERVE → PLAN → HUMAN APPROVAL → IMPLEMENT → VERIFY → INDEPENDENT REVIEW → DOCUMENT → разрешённый Git handoff. После approval агент исполняет согласованный scope автономно; изменение scope/contracts/gates требует обновлённого плана и approval только затронутого расширения.

| Владелец информации | Responsibility |
|---|---|
| Blueprint | Продукт, world-first, freedom, anti-scope, human acceptance |
| Master | Порядок фаз и migration strategy; D1 уточнения пользователя вносятся точечно после approval |
| Target Architecture / Migration Matrix / Test Strategy | Производные target owners, migration decisions, evidence roles; конкретные schemas и suite authority не создаются D1 |
| Root AGENTS | Короткие постоянные process/safety boundaries и навигация |
| Scoped AGENTS | Только дополнительные правила своей области, включая сохранённые legacy ограничения в world |
| `.agent/PLANS.md` | Формат/жизненный цикл сложного task plan, не отдельный planning skill |
| Три skills | Узкие workflow worldgen / independent verification / critical review |
| `implementation_plan.md` | Один конкретный task scope, approval status, acceptance и актуальный progress |
| `docs/plans/completed/D1.md` | После успешного D1: согласованный план, instruction-discovery evidence, verification и independent review; без нового runtime PASS |

Направление инструкций: root выбирает релевантный scoped guidance/workflow/plan format; scoped/skills ссылаются на authorities и конкретный task. Skills не меняют продукт и не создают разрешений, ExecPlan не переписывает invariants. Runtime dependencies остаются неизменными.

Domain direction: world information → route planning → RouteCorridor → road synthesis → FinalSurface → runtime consumers. Player потребляет public queries/collision и публикует telemetry. D1 закрепляет направление, но не создаёт эти future contracts или adapters.

## 5. Exact file whitelist

### 5.1. Разрешено сейчас

В репозитории изменяется **только `implementation_plan.md`**. В outputs чата сохраняется идентичная review-копия этого файла. Служебные audit snapshots остаются в `work/` вне repo и не входят в Git diff.

Создание D1 branch не меняет tracked content. Сейчас запрет на все прочие repo paths, включая предлагаемые ниже инструкции.

### 5.2. Предлагается после отдельного approval D1 — ровно 12 путей

| Путь | Действие | Содержание / допустимая область |
|---|---|---|
| `AGENTS.md` | MODIFY | Короткий root protocol по §7; прежние релевантные guarantees сохраняются/переносятся по §12, D0-specific wording заменяется current governance. |
| `scripts/world/AGENTS.md` | CREATE | Domain/runtime direction, ownership, seed discipline, player isolation; legacy geometry и существующие generation gates по §8. |
| `scripts/player/AGENTS.md` | CREATE | Stable player invariants/public boundary и measured defect + explicit player approval по §8. |
| `scripts/test/AGENTS.md` | CREATE | Anti-gaming, mutation/reclassification gate, current regression protection vs future Q0 по §8. |
| `.agent/PLANS.md` | CREATE | Компактный ExecPlan/task/report format и lifecycle по §9. |
| `.agents/skills/slow-cycle-worldgen/SKILL.md` | CREATE | Только metadata + workflow/invariants по §10.1. |
| `.agents/skills/slow-cycle-verify/SKILL.md` | CREATE | Только metadata + read-only verification protocol по §10.2. |
| `.agents/skills/slow-cycle-review/SKILL.md` | CREATE | Только metadata + read-only critic protocol по §10.3. |
| `docs/MASTER_IMPLEMENTATION_PLAN.md` | MODIFY | Только governance части §§III/IV/V/VIII: убрать plan skill, три skills в `.agents/skills`, native Plan Mode/PLANS, scope test instructions без классификации suites в D1. Product, Q/R requirements, budgets и phase order не менять. |
| `docs/CURRENT_PROJECT_STATE.md` | MODIFY | Только D1 status/navigation/следующий безопасный шаг и limitations; статус завершённости лишь после acceptance. Датированные runtime failures сохраняются. |
| `implementation_plan.md` | MODIFY | Этот D1 plan: approval trace/progress/reports; после успешного completion короткий NO_ACTIVE_PLAN со ссылкой на completed D1 и будущую подготовку Q0. Не копить journal. |
| `docs/plans/completed/D1.md` | CREATE, только при completion | Approved plan + final scope + verification/discovery/independent-review evidence и ограничения. При FAIL/INCOMPLETE/REJECT completed-файл не создавать. |

Нет дополнительных README, YAML, config, scripts, reference bundles, plugins, agents definitions, hooks, launchers, TEST_MATRIX или новых skill directories. Ссылки в существующих документах на root/plan продолжают работать; дополнительное редактирование docs index не требуется.

Запрещены все прочие пути, особо: production/test `.gd`, `.gd.uid`, `.tscn`, `.tres`, `project.godot`, `scripts/camera/**`, controller, input actions, physics/visual settings, RoadLogic/Graph/ChunkStreamer/TerrainCarver и их алгоритмы; test assertions/thresholds/helpers/fixtures/mandatory gates; Blueprint/Target Architecture/Migration Matrix/Test Strategy; frozen `.antigravity/rules/test-integrity.md`; исторические docs/D0 reports. Создаваемый `scripts/test/AGENTS.md` — единственное исключение внутри test tree; это инструкция, не изменение теста.

Whitelist не расширяется из-за удобства authoring, validators или отсутствующего evidence. Сначала конкретный scope amendment и approval.

## 6. Precedence и instruction discovery

Разделяем product authority и фактический порядок загрузки Codex.

1. System/developer/tool security действуют по harness. В пределах repo текущие явные решения пользователя задают разрешённый scope, в том числе настоящие D1 уточнения.
2. Blueprint задаёт продукт; Master — migration/phase order; current производные документы не меняют эти authorities. Код/tests/history описывают факты и защиту согласованного поведения, а не вечные ограничения нового продукта.
3. Root AGENTS задаёт общие repo rules. Более близкий scoped AGENTS уточняет локальную работу. Предлагаемые scoped файлы не отменяют root approval, stable-system protection или integrity gates.
4. Skills исполняют соответствующий workflow внутри этих boundaries. Они не выше AGENTS/user и не могут менять whitelist, budgets, обязательные проверки или approval status.
5. Approved ExecPlan конкретизирует task: allowed/forbidden files, владельцев, checks, миграцию. Конфликт с постоянными правилами требует явно согласованного изменения; фраза «план approved» не разрешает неописанное test mutation/player change.

При конфликте назвать источники, точные assertions/пункты, влияние и минимальный amendment. Не выбирать удобное правило молча, не переписывать code/tests ради новой трактовки.

По [официальным AGENTS instructions](https://learn.chatgpt.com/docs/agent-configuration/agents-md) Codex собирает chain от project root до стартового CWD; ближние инструкции имеют приоритет, override может заменить обычный файл. Это механизм harness, а локальный запрет scoped-файлам ослаблять root — правило проектирования нашего набора. Проверять оба слоя.

**Root-start не гарантирует автоматическую загрузку sibling `scripts/world/player/test/AGENTS.md`.** Поэтому root содержит короткое routing rule: перед чтением/изменением выбранной области явно открыть её AGENTS; при cross-system work загрузить только участвующие scoped files. Камера/controls защищены root даже без отдельного camera AGENTS. При старте внутри `scripts/world` проверить native chain root→world; при root-start проверить явное чтение scoped guidance до planning.

По [официальной документации skills](https://learn.chatgpt.com/docs/build-skills) repo discovery использует `.agents/skills` по цепочке CWD→repo root; metadata участвует в explicit/implicit matching, body читается при выборе. Поэтому **`.agent/PLANS.md` (singular) и `.agents/skills` (plural) — разные намеренные пути**. Не использовать предложенный старым Master `.codex/skills` как основной repo path и не создавать копии в обоих местах.

Root не включает skill bodies. Он указывает три имени/триггера одной короткой строкой и требует explicit invocation для обязательных verify/review stages: implicit matching удобно, но не служит доказательством выполнения gate.

Native Plan Mode — предварительное read-only исследование/выбор решений. [Официальное описание](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex) подтверждает этот workflow. Это не permission gate само по себе и не сохранённый ExecPlan. После планирования материализовать согласуемый файл; mode switch/user continuation трактуется как approval только при ясном согласовании конкретной версии/scope. Если native mode недоступен, подготовить PLAN_ONLY artifact и остановиться; не заменять это новым planning skill. Эта сессия фактически в Default mode и соблюдает PLAN_ONLY по явному запросу пользователя.

## 7. Root AGENTS: короткий постоянный контракт

Целевой размер: примерно 45–65 строк, до 6 KiB UTF-8. Это бюджет текста, не повод удалить существенное ограничение. Proposed contents:

1. **Authority/navigation.** Blueprint — product; Master — phases; task-specific target/migration/test/state sections по необходимости. History не задаёт next task. Перед работой фиксировать branch/HEAD/status/dirty/untracked; читать scoped AGENTS участвующих областей.
2. **Planning gate.** Sprint/phase transition, architectural/new subsystem, multi-file feature, multi-system work, значимая миграция или длительная реализация требуют одного ExecPlan по `.agent/PLANS.md`, обычно после native Plan Mode. Подготовить и STOP до explicit human approval. D1 принадлежит этому классу. Локальная малая правка без изменения ownership/contracts/gates не требует полного шаблона; её scope и targeted evidence всё равно явные.
3. **Scope/Git.** Работать внутри approved file whitelist, без unrelated cleanup, новых mechanics/dependencies без необходимости. Сохранять чужие changes/history; один task — одна logical branch/series. Не начинать следующую фазу автоматически. После approval выполнять согласованные шаги автономно.
4. **Subsystem independence.** Один owner каждого состояния, public contracts и односторонние dependencies; domain→Godot adapter, никакого renderer/player-owned world planning или God Object в composition root. Детали world-specific contracts — world scoped/skill/Target Architecture.
5. **Determinism.** Same effective seed/config/identity даёт воспроизводимый результат независимо от runtime allocation/materialization order; domain RNG локальный с явной derivation. Runtime выбор session seed логируется и предшествует генерации.
6. **Stable systems.** BicycleController, camera, controls, physics/presentation separation и public APIs защищены во всех путях, включая scenes/resources/project settings. Изменения только при measured defect, explicitly scoped player task и separate approved plan; worldgen не подстраивает player physics под дефект мира. Локальные детали — player AGENTS.
7. **Evidence.** Required coverage/completion и reason/evidence обязательны; exit 0/expected counts/старый report не доказывают PASS. Verify возвращает PASS/FAIL/INCOMPLETE, review PASS/REJECT; missing required evidence блокирует completion. E-level meanings — Test Strategy, E7 только человек. Generation gates — обязательная ссылка на world AGENTS.
8. **Integrity/governance.** Frozen rule читать при test-related work и конфликте; никаких skips/suppression/fake PASS. Existing tests/assertions/thresholds/gates неизменны без отдельного explicit human approval. Reclassification — будущий Q0, D1 не назначает suite categories. Tests не переопределяют target; конфликт сначала эскалируется, а gate сохраняется.
9. **Documentation.** Изменившие scope/ownership/contracts decisions и fresh evidence обновлять в current task/соответствующем владельце документа по whitelist; не дублировать Blueprint. Не выдавать planned/not-run за implemented/PASS. Завершённый task архивируется; root slot — один active plan.
10. **Workflow routing.** Worldgen design/implementation — `slow-cycle-worldgen`; проверка результата — `slow-cycle-verify`; независимый critic — `slow-cycle-review`. Body загружать при релевантном workflow. Approval не заменяет verification/review и не даёт права игнорировать rejection.

Не включать в root длинные geometry specs, product pillars, Phase R0–R21 descriptions, suite inventory, command catalog, reports, task template второй раз или D0 history. Не ослаблять Rule 6/7 через удаление: перенос описан ниже и проверяется отдельной preservation matrix.

## 8. Scoped AGENTS: конкретное содержание

### 8.1. `scripts/world/AGENTS.md`

Ориентир: 30–50 строк / до 5 KiB. Только world rules:

- Планирование/математика — pure data/RefCounted где возможно; planners не обращаются к scene tree. Runtime adapter владеет Nodes, mesh/collision registration и lifecycle. RefCounted label сам по себе не доказывает чистоту или thread safety.
- Pure domain results → adapter; public inputs/outputs/query, explicit state ownership/lifetime, без cross-system mutable shared arrays и circular dependencies. WorldManager собирает системы, не содержит их генерационную логику.
- Worker готовит data/arrays, main thread выполняет scene/physics commit; threading вводится после измеренного stall, не по предположению. D1 ничего из этого не реализует.
- Worldgen не меняет controller, camera, controls или physics, чтобы скрыть geometry/collision issue; public telemetry/query/collision — boundary с player.
- Effective seed → explicit stable domain derivation по identity/world coordinates; no global RNG/time/allocation-order keys внутри generation. Смена session seed — только boundary до generation с recording.
- Новый target ownership — world-space; road/frame coordinates допустимы локально для геометрии/деформации, но не владельцы всей географии/биомов. Legacy RoadGraph/Carver не объявляются готовыми target systems; replacement только в отдельно approved phase.
- Для target worldgen загрузить `slow-cycle-worldgen`; schema/API не выдумывать до соответствующего task plan.

**Сохранённый legacy guard (нынешний root Rule 6)**: C1 continuity обязательно, C2 желательна где применимо; wheel raycasts не маскируют tears/normal flips/steps. Straight fallback `_generate_conservative_safe_chunk` запрещён по действующему требованию; smooth Soft-Repair/clothoid сохраняет curve intent с R≥19 м. Fatal fallback только seam Δp>1 мм или NaN/Inf с `[GEOM]` logging. Это сохраняемая нормативная область текущего legacy road subsystem; observed code MIN_RADIUS=18 и более широкий fallback остаются открытым конфликтом. Не переписывать limits/thresholds/code/tests в D1 и не переносить legacy числа автоматически в новую regional schema.

**Сохранённый generation gate (root Rule 7)**: feature verification в engine/headless/runtime, zero parse errors/zero leak warnings; все generation changes сохраняют обязательные `test_seed_diversity_matrix`, `test_monotony_profiler`, `test_virtual_rider_bot` на real physics и Vulkan `capture_visual_audit.gd`. Одних math tests недостаточно. Task plan добавляет проверки нового domain, а не отменяет старые. Если будущий pure-domain task сталкивается с неприменимостью/неполнотой gate, это explicit conflict/approval proposal, не молчаливый exemption. D1 markdown-only validation не объявляется runtime/generation PASS.

**Сохранённая locality (Rule 10/D0)**: не собирать infinite foliage в один monolithic MultiMesh; сохранить current chunk/type-local culling до approved migration. Target — spatial cell + type по architecture; D1 не меняет partition/runtime.

### 8.2. `scripts/player/AGENTS.md`

Ориентир: 15–25 строк / до 2.5 KiB:

- BicycleController/camera/controls stable. Для любой player-правки нужны measured defect с воспроизводимым evidence, explicitly approved player task, отдельный план с regression/physics/camera checks.
- Public signals `telemetry_updated(speed_kmh, cadence_pct, is_coasting)` и `bell_rung`, существующие public properties/query/recovery contracts сохраняются; world consumers не командуют внутренней kinematics и не мутируют controller state.
- Физический CharacterBody3D root сохраняет world-up orientation, visual lean/dive/pitch — внутри VisualsRoot; не смешивать presentation и physics и не маскировать world defects raycasts/camera.
- Scene exports/input maps/resources вне каталога защищены root. Одно изменение `.tscn` или `project.godot` не обходит player gate. Изменение camera не становится worldgen scope только потому, что world плохо выглядит.

### 8.3. `scripts/test/AGENTS.md`

Ориентир: 20–35 строк / до 3.5 KiB:

- Проверять реальную production логику; mocks только на оправданных внешних boundaries, не вместо проверяемого ядра. Никаких test-specific production hooks/hardcode, dilution assertions, скрытых skips/todo/suppression/type bypass или fabricated results.
- Existing test code/assertions/thresholds/coverage/mandatory gates остаются protected. Любая mutation/reclassification, включая syntax-helper fix, требует explicit human approval конкретного diff/требования; общее feature approval не даёт такого разрешения. Новый test/negative fixture предусматривается явно в approved task whitelist и проверяет requirement независимо от implementation.
- Tests не становятся владельцами product architecture. Conflict legacy expectation vs approved target записывать с owner/requirement/source и evidence; не менять ни тест, ни архитектуру молча. До решения current regression protection/gates остаются действующими.
- **D1 не классифицирует ни один текущий suite**. Future categories определены Test Strategy; authority map/назначение suite → category — только отдельный Q0 plan + approval. Не маркировать существующие tests historical для исключения из acceptance.
- Expected/actual checks и coverage различать. Reason-coded negative должен упасть/отказать именно ожидаемым способом в реальном коде; произвольный crash/timeout не negative PASS. Declared full completion и отсутствие unexpected errors/leaks обязательны; fixture failure logging не подавлять, а сопоставлять expected reason.
- Physics evidence — реальный player/collision/Input; teleport/provided mesh не заменяют ride. Vulkan evidence — реальные сохранённые/проверенные captures; measured counters не подменять expected budgets. E7 утверждает человек.
- Verify и review read-only по feature/test code; обнаруженный defect возвращается implementation owner, после исправления новые проверки/report/review для нового diff.

Frozen-файл остаётся внешним retained integrity source; scoped AGENTS не обещает переопределить его в другом агенте, который independently загружает `.antigravity` rules.

## 9. `.agent/PLANS.md`: компактный формат сложного ExecPlan

Ориентир: 60–100 строк / до 8 KiB. Native Plan Mode используется для предварительного анализа по [описанию OpenAI](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex); формат file plan адаптируем под repo, не копируем большой универсальный cookbook.

Header: TASK, status PLAN_ONLY/APPROVED/IMPLEMENTING/VERIFYING/REVIEWING/COMPLETE, date, base branch/HEAD/status/dirty, approval source/date и approved version/digest или однозначная Git revision. Для uncommitted реализации записывать source digest + diff digest, не только HEAD.

Обязательные поля, допускающие объединённые краткие таблицы:

| Поле | Что нужно зафиксировать |
|---|---|
| Goal | Пользовательский/технический результат одной задачи |
| Observed current state | Проверенные файлы/поведение/evidence, отдельно unknown/непроверенное |
| Target behaviour | Что изменится и что останется за scope, без обещаний будущих фаз |
| KEEP / ADAPT / REPLACE / RETIRE decisions | По затронутым legacy systems; EXTEND/DEFER при обосновании; N/A допустимо с причиной |
| System ownership | Один owner каждого состояния/lifecycle, граница composition root |
| Public contracts | Inputs/outputs/query/errors; future names не объявлять уже implemented API |
| Dependency direction | Односторонний data flow, domain/runtime boundary |
| Allowed files | Exact whitelist, create/modify/delete и минимальная ответственность каждого |
| Forbidden files | Stable neighbors/tests/gates/config и другие явные exclusions |
| Migration path | Малые milestones, adapter/parity/retirement gates, остановка при конфликте |
| Risks | Coupling, determinism, scope, performance/legacy assumptions и mitigation |
| Verification plan | Targeted tests/integration, команды/seeds/limits где применимо, expected vs actual coverage/completion, required E-levels |
| Negative verification | Какие invalid/boundary inputs должны дать какой reason; meaningful omissions обосновать |
| Runtime/visual/physics requirements | Real main/production-equivalent boundary, Vulkan/collision/Input/ride; N/A только с объяснением scope и без отмены gate |
| Performance evidence | Если применимо: workload, before/after, hardware/engine/mode, distribution/frame stalls/memory; отсутствие данных не «optimized» |
| Rollback boundary | Какие изменения можно отменить, сохранение чужих edits, preconditions/data/API compatibility |
| Legacy impact | Protected behavior, pending conflicts, known failures и next dependency |
| Documentation changes | Exact files и владельцы новых решений/evidence, без второго roadmap |
| Definition of Done | Scope + required evidence + verification PASS + independent review PASS + docs/limitations |

Ниже — короткий progress/decision/evidence log **только этой задачи** и формат reports по §10: status/reason/revision-digests/coverage/artifacts/limitations/findings. Не добавлять к каждому ExecPlan product handbook или прошлые sprint reports.

Небольшая локальная правка: Goal + exact files + не меняющиеся boundaries + targeted verification/result достаточно; полный ExecPlan не требуется, пока нет phase transition, multi-file feature, архитектурной/межсистемной/миграционной/длительной работы или explicit user gate. Число строк diff не единственный критерий: one-file ownership change всё равно architectural.

После drafting — STOP до human approval. Существенное изменение approval scope/contracts/mandatory evidence → amendment и новый gate. Verification/reviewer не исправляют feature «заодно». После completion approved plan/report архивируются в `docs/plans/completed/<TASK-ID>.md`; root slot очищается, следующая фаза не запускается. Архивирование старого D0/D1 никогда не означает approval Q0.

## 10. Три узких repo-scoped skills

Каждый — один instruction-only SKILL.md с YAML `name`/`description`. Не создавать scripts/assets/references/openai.yaml, skill-plan или дополнительные skills. Description краткая, trigger front-loaded; подробности только body. Scope boundaries указаны и в description, и в workflow.

### 10.1. `slow-cycle-worldgen`

**Trigger:** проектирование/реализация/миграция generation, terrain/hydrology/biomes, route planning/road synthesis, surface/placement ownership, seed/spatial identity contracts. Допустим на planning stage соответствующей задачи; не даёт права писать code до approval.

**Non-trigger:** player/camera/UI/audio-only, обычное редактирование prose без worldgen decisions, чистая verification/review без проектирования, governance-only D1. Review может читать invariants/reference, не запускать implementation workflow. Не вызывать только из-за слова «world» в пути/report.

Минимальный проект SKILL.md (только текст внутри настоящего плана):

```yaml
---
name: slow-cycle-worldgen
description: Design or implement Slow Cycle world generation, route/road/surface ownership and seed contracts. Excludes player, UI, governance-only tasks and verification-only work.
---
```

Body ориентировочно 20–35 строк:

1. Прочитать root/world AGENTS, approved plan либо drafting scope; выбрать релевантные sections Target Architecture/Migration Matrix/Blueprint. Для значимого scope подготовить ExecPlan по PLANS и STOP до approval.
2. Закрепить **WORLD FIRST → ROUTE SECOND → ROAD THIRD**. World-space geography независима от road-relative sampling/renderer state.
3. Effective deterministic seed/config/identity и explicit derivation; no global RNG/time/allocation-ID dependence. Domain results — pure planning data без Nodes/scene access; owner каждого состояния явный.
4. Route planner потребляет world information; road synthesis потребляет RouteCorridor; runtime render/collision/vegetation/water/world queries в целевой миграции потребляют FinalSurface. Все эти имена — target responsibilities, schemas/API утверждаются в соответствующем task, не в D1.
5. No road-relative world ownership, renderer-owned world state, circular dependencies, neighbor mutable arrays или player-physics adjustment. Local road coordinates допустимы для road geometry/deformation при явном переводе world-space boundary.
6. Отличить legacy as-is от target/phase migration: RoadGraph DAG, legacy RoutePlan/Carver не становятся новым региональным owner по названию или типу RefCounted. Не требовать уже реализованные поздние landmarks/vistas для раннего R5, не перескакивать Q/R phases.
7. Диагностировать REJECT/REPLAN/DEGRADE_EXPLICITLY/FAIL с reason; никаких hidden fallback. Для implementation handoff: dependency/owner/determinism/negative evidence, далее verify/review; skill не объявляет acceptance самостоятельно.

No конкретные RegionPlan fields, hash/salt algorithms, tile sizes, seed schema, new adapters или world scaffolding.

### 10.2. `slow-cycle-verify`

**Trigger:** независимая проверка resulting implementation/docs-governance diff относительно approved plan, после implementation milestone или явного verification request. Для D1 проверяется instruction protocol, а не новый runtime.

**Non-trigger:** разработка/fix feature, предварительное planning без результата, дизайн новой harness/Q0 map, критический architecture review как замена verify. Если входов недостаточно, вернуть INCOMPLETE, не писать feature/testing launcher.

Metadata:

```yaml
---
name: slow-cycle-verify
description: Independently verify a Slow Cycle resulting diff against its approved plan with actual scope, completion and evidence. Read-only for implementation/tests; excludes feature fixes and harness development.
---
```

Body ориентировочно 35–55 строк, workflow:

1. Получить approved plan/version, base/result revision, actual diff включая staged/unstaged/new files, baseline dirty list и reports/artifacts. При отсутствии approval/result identity — INCOMPLETE. Задать required checks/coverage из плана и существующих gates до запусков.
2. **Diff audit/scope:** whitelist, protected player/camera/tests/config/frozen rule, contracts/dependency/owner changes; отдельно чужие edits. Непредусмотренный путь/behavior/gate change — FAIL. Read-only access допускается вне whitelist, mutations нет.
3. **Targeted tests/integration:** real production path; expected assertions/coverage/timeouts/completion записывать до run, actual counters/markers и полный stdout/stderr сохранять. Не придумывать machine-readable runner, которого нет: Q1 later. Если существующий runner не даёт нужного evidence — INCOMPLETE, а не exit-0 PASS.
4. **Negative fixtures:** выполнить доступные approved invalid/boundary cases; сверить expected reason и sensitivity реального кода. Crash/неизвестная ошибка не засчитывается. Missing required fixture → INCOMPLETE; неверный reason/принятое invalid → FAIL. Не менять fixture/production hook ради результата.
5. **Determinism:** repeated effective seeds/config, stable identities/hashes и reorder/materialization tests где контракт их требует; записать фактические seeds/results. `184729`, `42`, `77777` — существующие reference seeds, не выполненный Q2 baseline. Cross-engine/platform byte determinism не заявлять без отдельно определённого contract/evidence.
6. **Runtime coverage/completion:** различить math, real integration, actual main/production-equivalent scene и meaningful branch/point/duration/distance coverage; завершившийся subprocess без выполненных обязательных assertions не PASS. Teleport/geometry replay не physics/input replay.
7. **Errors/leaks:** проверить full logs, timeouts/abort, unexpected engine warnings/parse/runtime errors/ObjectDB leaks. Нельзя подавлять/фильтровать failure ради PASS. Known baseline failure фиксируется отдельно и остаётся blocker соответствующего zero-error gate; «было раньше» не waiver.
8. **Required E4/E5/E6/E7:** real registered collision + Input-driven bike, настоящий Vulkan renderer + saved/read captures с context, bounded soak/frame/memory before-after при performance change, human ride только со свидетельством человека. Missing обязательного уровня → INCOMPLETE. Documentation-only D1: N/A с объяснением scope, не игровой PASS и не ослабление future generation gates.
9. Отчёт привязан к result source/diff digests; mutation feature/test запрещена. Вернуть findings implementation owner; после fix новый report, старый PASS недействителен для изменённого diff.

**Единственное поле result: PASS / FAIL / INCOMPLETE.** Reason/evidence обязательны. FAIL — обнаружено нарушение/непройденное требование; INCOMPLETE — проверка не закончена/нужного evidence нет. При одновременно доказанном defect и missing evidence result FAIL, недостающее явно указать. PASS — все required checks реально выполнены, scope/completion/coverage удовлетворены, никаких неожиданных errors/leaks.

Минимальный report: TASK; approved plan version; base/result revision + dirty/digests; result; reason; checked scope; required/actual coverage/completion; commands/seeds/durations/environment; assertions/negative reasons; errors/warnings/leaks/timeouts; E-level evidence/N/A; artifact paths; known failures/limitations; tests changed/reclassified + approval reference. Нет утверждения «100% game works» из task PASS.

### 10.3. `slow-cycle-review`

**Trigger:** независимый critical review полученных approved ExecPlan + resulting diff + verification report. Назначается отдельным reviewer в свежем контексте, либо независимым человеком. Skill body в той же implementation session сам по себе не доказывает независимость.

**Non-trigger:** feature implementation/debugging, замена verification report, переопределение product/test authority, согласование расширения scope за человека. Отсутствующие обязательные входы/независимость не превращать в PASS.

Metadata:

```yaml
---
name: slow-cycle-review
description: Independently critique an approved Slow Cycle plan, resulting diff and verification report. Return PASS or REJECT even when tests are green; excludes implementation fixes and replacing verification.
---
```

Body ориентировочно 30–50 строк:

1. Проверить три обязательных входа/version/diff identity, scope approval и свежесть verification; предъявить reviewer identity/context. Роль read-only: не править feature/tests/approved scope и не подгонять отчёт под автора.
2. Scope creep/unrelated cleanup, duplicated responsibilities, hidden coupling, God Objects, public contract breaches, wrong dependency direction, scene-tree access в domain/worker logic.
3. Hidden fallback, silent object deletion, stale legacy assumptions, needless compatibility layers, road-relative world authority, unsupported renderer-owned data.
4. Test gaming/skips/suppression/test-only hooks, fake coverage, unexecuted assertions/completion, weakened thresholds/mandatory gates, reclassification без human approval, missing negative tests.
5. Unbounded allocations/caches, shared mutable state, main-thread heavy work без profiling/обоснования, unsupported optimization claims, nondeterminism/global RNG/unstable identity risks.
6. Claims vs evidence: Vulkan/physics/runtime/performance/human evidence соответствуют задаче? Known failures, limitations и measured coverage не скрыты? Green legacy tests не сертифицируют target region/world, docs-only PASS не закрывает runtime INCOMPLETE.
7. Report с result **PASS или REJECT**, reason/evidence и actionable findings (source/file/line/plan item, impact, required correction). Missing approved plan/verification/required evidence или отсутствие независимости → REJECT с причиной; не вводить третьего verdict. PASS означает отсутствие blocking findings в declared scope, не approval новой фазы.
8. Verification FAIL/INCOMPLETE блокирует final acceptance независимо от reviewer. Review вправе REJECT при verification PASS. После fix: fresh verify + independent review на новый diff; author не объявляет собственный review PASS.

Честная независимость обеспечивается процессом, не файлами: после D1 approval человек/уполномоченный coordinator передаёт immutable plan/diff/report в отдельный read-only context. Не создавать постоянного review agent/нового skill. Сейчас независимый review этого плана принадлежит человеку; выполнение будущих ролей не начато.

## 11. Trigger strategy, duplication и instruction bloat

| Где хранить | Что именно | Что исключить |
|---|---|---|
| Root AGENTS | Authority pointers, gate triggers, scope/Git, protected neighbors, universal ownership/determinism/integrity/evidence, scoped/skill routing | Полные technical/product specs, весь phase plan, команды всех tests |
| Scoped AGENTS | Локальные domain/runtime/player/test restrictions и сохранённые legacy road gates | Product manifesto, task-by-task reports, новые suite categories |
| Skills | Выполняемые workflow своей роли, минимальные triggers/non-triggers | Общий planning skill, весь Blueprint, task approval, постоянный runner/framework |
| Blueprint/Master/current derived docs | Product/phase/world responsibilities и evidence definitions | Инструкция перечитывать всё для каждого typo fix |
| Конкретный ExecPlan | Нынешние contracts/decisions/files/seeds/checks/budgets/migration/rollback/acceptance | История всех задач и постоянная handbook-копия |

При small worldgen request session: root + world scoped + worldgen body, релевантные authority sections; PLANS body лишь если gate triggers. Player/test scoped — только если затрагиваются/проверяются эти boundaries, root защита действует всегда. Verify/review body загружаются на своём этапе, не все три одновременно в каждый prompt.

Допустимое повторение: в root короткая граница, в scoped её техническое применение, в skill шаг проверки. Полный rule text/таблица E0–E7 принадлежат одному owner; другие ссылаются. Non-trigger descriptions предотвращают broad implicit activation. World-first фраза повторяется кратко как invariant, pipeline/spec не копируется целиком.

Общий ориентир: root ≤6 KiB, root+world ≤11 KiB, каждая skill body ≤6 KiB, PLANS ≤8 KiB. Это не Codex setting и не performance доказательство. Измерить UTF-8 bytes, не только line count; root+любой scoped chain должен оставаться существенно ниже standard discovery cap. Не менять global config/лимиты, чтобы маскировать bloat.

Длинная D1 детализация находится здесь для review; после реализации не вставлять этот план в AGENTS/SKILL. Если бюджет не достигается без потери gates, сначала убрать дубли и общие объяснения; не выбрасывать guards и не создавать четвёртый skill.

## 12. Conflict analysis и сохранение существующих guarantees

| Источник / конфликт | Решение после approval D1 |
|---|---|
| Master §III `.codex/skills`, four skills/plan skill; §VIII four skills | Точечно привести к `.agents/skills`, трём skills и native planning/root+PLANS. Пользователь явно уточнил Master; сейчас Master остаётся неизменным. |
| Master §IV test scoped «вводим классификацию» и §V категории | В governance формулировке отделить запрет автоматической product-authority от future Q0 category assignment. Definitions §V сохраняются; дописать, что existing suite classification только Q0. Ни одной category assignment в D1. |
| Root Rule 11 любой multi-file feature/sprint/refactor; план small-fix | Сохранить triggers; добавить architecture/multi-system/migration/long-running критерии. Small local non-feature fix не становится automatic loophole. Explicit user gate всегда действует. |
| Root Rules 1/4/9 stable Bicycle/public APIs/camera | Root universal protection + player scoped details; не ослаблять world-upright/presentation separation/public telemetry/recovery. No controller/camera/settings diff. |
| Root Rule 5 «100% deterministic» | Сохранить same effective seed/config requirement; clarify session-seed boundary по observed WorldManager. Не объявлять cross-platform floating-point guarantee без contract/evidence. |
| Root Rule 6 geometry/fallback/R≥19 против code R=18 | Полный meaningful requirement перенести в world legacy guard; сохранить pending conflict. Никаких изменений чисел/порогов или новых project-wide geometry specs. |
| Root Rule 7 обязательные Watchdogs/Vulkan/zero errors/leaks | Root evidence pointer + полный scoped generation gate; никаких отказов от mandatory проверки в пределах её нынешней области. D1 docs-only acceptance отдельно от runtime. |
| Root Rule 10 chunk MultiMesh vs spatial target | Сохранить current local culling/partition until approved migration; spatial cell/type target остаётся architecture responsibility. |
| Root Rules 2/3/8/12 | Minimal changes/no unnecessary dependencies/no gameplay creep/autonomy after approval сохраняются краткими root правилами. |
| Старый task template | Один компактный task header/ExecPlan/report format в PLANS; не размножать его в root и skill-plan. |
| D0-specific root status и current state «D1 ещё не начат» | Обновить только после D1 acceptance; не трогать D0 archive или датированные runtime claims. |

### 12.1. Frozen `.antigravity/rules/test-integrity.md`

Точные конфликты:

- §1.1 универсальные tests-as-source-of-truth и §1.2 «реализация ВСЕГДА подгоняется под тесты» могут навязать future RegionRouteGraph legacy DAG, против Blueprint §15/Master topology. §3.5 уже требует escalation при architecture/test conflict — это сохраняемый безопасный путь, не право менять tests.
- §3.3 разрешает remediation только application paths; verify skill по собственной роли read-only и не делает remediation вообще. Реализацию исправляет implementation owner после report, в approved scope.
- §4 допускает syntax-only test fixes без отдельного approval и новые tests для feature; настоящий запрос устанавливает human gate для mutation/reclassification. Scoped/root применяют более строгий local gate и требуют явного разрешения конкретного test scope.
- §5 последняя checkbox «зелёный статус … 100% … работоспособность» шире фактического declared coverage. Report фиксирует limited scope и INCOMPLETE вместо декларативной глобальной галочки. No test execution → NOT_RUN, никакого выдуманного green status.

**Решение D1: frozen-файл не менять, предложение его редактировать в данный whitelist не включать.** Уже принятая D0 authority distinction + root routing/conflict rule + test scoped не дают legacy tests переписать product target, одновременно сохраняют assertions/gates и escalation. Для Codex это достаточно как governance: файл `.antigravity` не объявляется автоматически обнаруживаемым native AGENTS/skill, его читать по root pointer; отсутствие autoload не является разрешением игнорировать integrity.

Недостаточность scoped-only: test instructions из `scripts/test` не загрузятся автоматически для world-only CWD и не управляют сторонним AntiGravity harness. Поэтому root содержит общую authority/test-mutation границу. Если другой tool independently always-applies frozen rule и возникает конкретный неразрешимый конфликт, остановить затронутую работу и предложить **отдельный** минимальный amendment: ограничить §1 authority согласованным owner/contract, сохранить §2 anti-gaming и §3.5 escalation, убрать implicit syntax-mutation permission, связать §5 вывод с declared coverage. Это условный будущий proposal, не требование переписать файл сейчас. Перед отдельным approval показать точный tool conflict и почему root+scoped не решают его; D1 не угадывает такой conflict заранее.

## 13. Migration path после approval

1. Повторить Git preflight, base/status/dirty и сравнить D0/current fingerprints; подтвердить D1 branch, согласованную approval version и отсутствие незамеченного master/base drift. Сохранить чужие изменения. Не возвращать историю назад.
2. Составить preservation checklist старых Rules 1–12 → root/scoped/PLANS пункт и убедиться, что Rule 6/7/10 не ослаблены; подготовить все инструкции внутри whitelist.
3. Создать четыре scoped/plan documents и три skill manifests, заменить root компактным routing protocol. Не менять code/tests/config и не устанавливать skills globally.
4. Точечно исправить Master governance contradictions в указанных sections; не менять product/phase order. Current state пока отражает D1 IN_PROGRESS, runtime INCOMPLETE/known failures сохранены.
5. Выполнить documentation/scope/preservation/metadata checks и реальные read-only discovery probes по §14. Не запускать игру или full suite для Markdown-only diff и не объявлять runtime проверенным.
6. Передать approved plan + resulting diff/digests + verification report независимому reviewer. FAIL/INCOMPLETE/REJECT блокируют completion; исправления только в D1 whitelist, затем fresh verification/review. Независимый reviewer доступен через separate authorized session/human; если недоступен, acceptance остаётся INCOMPLETE, а не self-review PASS.
7. Только после PASS verify + PASS independent review архивировать approved plan/reports в completed D1, обновить current state и plan slot. Проверить финальный archival/navigation diff; substantive late changes требуют fresh review. Перед Git handoff окончательный diff scope/count/digests, без unrelated staging.

KEEP: stable game/runtime/tests/assertions/frozen rule/Blueprint/target docs/history. ADAPT: root protocol и Master governance navigation. REPLACE: длинная структура постоянного root/task-template размещения компактным routing+scoped+PLANS. RETIRE: рекомендация отдельного `slow-cycle-plan` и старого `.codex/skills` route в current Master, но не реальные gameplay systems. EXTEND: три scoped instructions/три workflows. DEFER: Q0 classification, Q1 launcher, Q2 baseline/leaks, все R algorithms/schemas.

## 14. Verification plan и negative verification D1

### 14.1. Static/documentation checks

- Compare base/current tracked hashes: все пути вне 12-file whitelist побайтово неизменны; отдельно test code, production `.gd/.uid`, scenes/resources/project, frozen rule. Include untracked/new files и staged diff; `git diff --check` плюс exact path audit. Hash equality frozen соответствует §2.
- Paths/relative links из root/scoped/skills/PLANS/current/master/plan resolve корректно от своей папки. Future links отсутствующих инструкций в PLAN_ONLY различать от ошибок active D1 docs; после implementation все active links должны существовать.
- Skill manifest metadata: ровно три unique names, корректное YAML name/description и narrow triggers; `slow-cycle-plan` folder/manifest отсутствует. Нет duplicate manifests в `.codex/skills` или globally созданных копий. Упоминание retired recommendation в history не считать четвёртым installed skill.
- Rule-preservation matrix закрывает Rules 1–12, scope boundaries, требование independent review и Q0 separation. Master changes ограничены утверждёнными governance sections; никакого изменения Q/R product/evidence requirements.
- Измерить UTF-8 sizes/root+scoped chain; не просто заявить «short». Проверить отсутствие долгих копий Blueprint/Master и каталогов прошлых reports в instruction bodies.

### 14.2. Проверка реального instruction discovery после реализации

Провести свежие **read-only sessions**, не унаследованный текущий контекст. В report сохранить CWD, branch/HEAD/source digest, native mode, фактически discovered file paths/skill names, ответы и limitations. Никаких test/runtime fixtures в repo для этих probes.

| Probe | Ожидаемое поведение |
|---|---|
| Start repo root: «назови active instructions и подготовь подход к маленькой worldgen задаче; ничего не пиши» | Root найден; world scoped явно открыт перед анализом; worldgen skill body прочитан по trigger; релевантные authority sections, не весь history. |
| Start `scripts/world`: такой же запрос | Native root→world chain подтверждён, три repo skills доступны через root `.agents/skills`; PLANS читается только при ExecPlan trigger. |
| Start `scripts/player`: локальная диагностика без правок | Root→player, stable/public boundaries; worldgen body не запускается на player-only request. |
| Start `scripts/test`: проверка предлагаемого result | Root→test, anti-gaming/mutation approval/Q0 boundary; нет существующим suites новых категорий. |
| Root-start cross-system scenario world + camera | Root protection срабатывает для `scripts/camera` вне player subtree; предложенный worldgen scope не включает camera fix. |
| Explicit `$slow-cycle-verify` / `$slow-cycle-review` | Соответствующий skill реально discovered и body loaded; роль read-only, result vocabulary/reason/evidence корректны. |
| Native Plan Mode dry-run | У significant task есть ExecPlan outline с ownership/contracts/whitelist/negative verification и STOP до approval; run не материализует future schemas/code и не начинает R0. |

Единственная ссылка на [официальный AGENTS discovery workflow](https://learn.chatgpt.com/docs/agent-configuration/agents-md) достаточна для protocol; documented expected behavior проверяется actual session. «Файл существует» или «сессия пересказала текст prompt» не подтверждают discovery. Native loaded-path/session evidence предпочтительнее самоотчёта; если harness его не предоставляет, явно зафиксировать limitation, не называть автоматическое discovery proven.

### 14.3. Negative governance probes (без реализации мира/тестов)

В read-only session дать hypothetical request/diff/report; не записывать запрещённые изменения:

1. «Упростить camera/player physics ради worldgen» → plan фиксирует forbidden stable neighbors, measured-defect/player-task gate; никакого code change.
2. «RoadGraph tests требуют DAG, поэтому запретим loops будущему региону» → authority conflict/escalation, target не переопределён, current DAG/assertions не изменены.
3. «Снизить threshold/skip failure, пометить текущий suite historical» → отказ от silent mutation/reclassification, требуется отдельный human decision/Q0; gates остаются.
4. Result report только `exit 0`/expected assertion budget либо без completion/captures → verify INCOMPLETE с missing evidence; никакого fake PASS или launcher fix.
5. Verification PASS, hypothetical diff содержит renderer-owned world state/hidden fallback/unbounded cache/main-thread work без evidence → reviewer REJECT с точным finding даже при зелёных tests.
6. Significant architectural task без approval/за пределами whitelist → PLAN_ONLY/STOP; небольшой локальный prose fix без architecture/gate не требует бюрократического полного ExecPlan.
7. Same HEAD, но feature diff изменён после report → digests mismatch, fresh verify/review; stale PASS не используется.
8. D1 acceptance completed → предлагается только отдельная подготовка Q0; TEST_MATRIX/harness/RegionPlan не создаются автоматически.

Это проверки instruction behavior на гипотезах, а не E1 domain tests и не Q0 classification. Не создавать новые gameplay/world types для демонстрации. Не присваивать текущим tests categories даже в probe answer.

### 14.4. Runtime / physics / Vulkan / performance

Для D1 instruction-only diff: Godot parse/runtime/physical rider/Vulkan capture/soak **NOT_RUN / NOT_APPLICABLE**, причина — отсутствуют engine/feature/generation изменения. Это не waiver существующих generation gates для будущей feature. Runtime общая acceptance остаётся INCOMPLETE; known failures не закрыты. Performance evidence D1 — измеренный размер instruction context и scope discovery, без FPS/CPU/«ускорение generation» claims.

## 15. Риски, mitigation и rollback boundary

| Риск | Mitigation / stop |
|---|---|
| D0 не находится в GitHub master | Использовать явно recorded completed D0 tip для plan; не выдавать за master. Если merge-master обязателен, согласовать актуальную базу до реализации. |
| Scoped files не загрузились при root CWD | Root explicit routing + actual fresh-session probes; INCOMPLETE до доказательства. |
| `.agent`/`.agents`/`.codex` перепутаны | Exact paths, manifests count, explicit skill discovery; no duplicate copies или global config fix. |
| Simplification стирает legacy Rule 6/7 | Preservation matrix, scoped legacy guard, literal mandatory names/limits, independent diff review. |
| Native Plan Mode принят за approval | Header/status/version + explicit human approval конкретного saved scope; no approval inferred from mode alone. |
| Frozen rule конфликтует с product authority | D0 distinction + root/test escalation; no frozen edit/gate waiver. Tool-specific unresolved conflict — отдельный proposal. |
| Verification незаметно исправляет feature | Read-only role и before/after source digest; findings возвращаются owner, fresh evidence после fix. |
| Независимость review существует только в названии skill | Отдельный reviewer/context/immutable inputs; отсутствие reviewer блокирует completion. |
| Instruction bloat / broad activation | Byte budgets, owner-based deduplication, narrow metadata/non-triggers, bodies on demand; не raising limits. |
| Documentation PASS превращается в runtime PASS | Report явно scope D1, E0–E7 not-run/N/A; dated known failures и INCOMPLETE сохраняются. |

**Rollback:** изменение Markdown/instruction behavior обратимо, игрового state/API/data migration нет. Сейчас восстановим только `implementation_plan.md` из D0 base при желании пользователя, сохранив review-копию; branch/history не переписываются.

После implementation D1, если instructions ухудшили discovery/поведение: отдельный revert D1 instruction/doc commits либо восстановление **только собственных whitelist edits** по recorded base, удаление лишь созданных D1 instruction files с сохранением approval/reports в Git history. Не применять `reset --hard`, `git clean` или broad checkout к чужим changes; не стирать старый D0, production/test files или runtime evidence. Сначала проверить новые user edits и exact targets. Failed D1 не архивируется как completed, scope gate остаётся активным.

## 16. Acceptance criteria / Definition of Done будущего D1

- [ ] Explicit human approval этой версии D1 plan и согласованная recorded база; отдельная D1 branch, status/dirty/evidence identity известны.
- [ ] Diff ровно в approved 12-path whitelist; production/runtime/tests/assertions/thresholds/gates/frozen rule не изменены; hash/scope evidence приложено.
- [ ] Root короткий, scoped только области; все старые meaningful protections сохранены, camera/controls вне player subtree защищены.
- [ ] `.agent/PLANS.md` включает все обязательные поля §9 и proportional small-fix path; significant task действительно останавливается до approval.
- [ ] Ровно три repo-scoped instruction-only skills, no `slow-cycle-plan`, actual discoverability/explicit activation проверены; body scopes/result vocabulary соблюдены.
- [ ] Current Master governance соответствует user уточнению; phase order/definitions/categories остаются, suite assignments только Q0 и сейчас отсутствуют.
- [ ] Fresh-session позитивные/negative probes показывают минимальное релевантное чтение, architectural boundary, scope gate, честный verify и critical review rejection при green tests.
- [ ] Verification PASS с reason, diff/source identity, completion/coverage и actual artifacts; никакого декларативного PASS/runner budgets вместо evidence.
- [ ] Independent reviewer получил approved plan+diff+verification report, выдал PASS с traceable findings/reason; self-review автора не считается независимым.
- [ ] Documentation отражает реальное завершение только governance; current runtime INCOMPLETE/known failures сохранены; completed D1 существует лишь после принятой проверки, root slot один.
- [ ] Следующая работа — только отдельно запрашиваемая подготовка Q0. Q0/Q1/Q2/R0 и новые schemas/code не начаты.

Acceptance philosophy: успех — свежий session умеет принять маленькое конкретное worldgen задание, загрузить нужные rules, различить legacy/target/domain/runtime, при необходимости подготовить правильный ExecPlan и остановиться до approval, сохранить stable neighbors, затем провести доказательную verification и независимый review. Число Markdown-файлов не является критерием качества.

## 17. Состояние подготовки и handoff человеку

Подготовка: required sources/boundaries прочитаны, стартовый Git snapshot зафиксирован, отдельная D1 branch от завершённого D0 создана, этот PLAN_ONLY файл подготовлен. **Implementation approval отсутствует.**

Сейчас создан/изменён только `implementation_plan.md` и идентичный outputs artifact. AGENTS/PLANS/skills/Master/test-integrity/runtime/tests не изменены. Godot/tests/physics/Vulkan/performance suite не запускались; независимый review плана предстоит человеку.

**STOP после проверки one-file diff и представления плана.** Не выполнять пункты реализации §13, не отмечать D1 COMPLETE, не создавать completed D1, не запускать Q0, не делать commit/push/PR без дальнейшего поручения. Для реализации требуется отдельное явное approval этого конкретного плана; замечания review сначала вносятся в этот же plan slot.

Test integrity подготовки: test code не менялся; skips/suppression/fake PASS не добавлены; tests NOT_RUN; никакой общей работоспособности игры не заявлено.
