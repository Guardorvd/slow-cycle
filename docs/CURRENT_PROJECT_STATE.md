# Slow Cycle — актуальное состояние и точка входа

Дата: 01.10.2026. Исходная передача WORLD-00A/00B — `7c33004`. Код сегодняшних C01–C02, WORLD-00-LOG и C03–C04 сохранён коммитом `ce3b175c95d85664a110031161ebbc10c5486720` (`main`); после него рабочая копия проверена и была чистой. Закрытие дня меняет только документацию отдельным коммитом; в новом чате проверить фактический HEAD/status. Проверка основного коммита — `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-surface/commit-verification.json`; проверка закрытия дня — `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-surface/day-close-verification.json`. [Сводка дня](TODAY_CHANGES_2026_10_01.md).

C01–C02: seed до инициализации; фактический генератор/участок/позиция/камера/Image/save/reload/metadata/run_id. 27 checks и 19 достоверных PNG. Аналогичный прежний seed дефект visual `_init` не подтверждён. [Отчёт captures](sprints/world_00_c01_c02_verification_report.md).

WORLD-00-LOG: manifest/events/ring/48 source copies, auto-flush, реальные choices и ограниченные geometry checkpoints. 37 checks, три seed × 3 checkpoints/1 choice, 13 expected negative результатов; geometry replay не записывает физический ввод. [Отчёт логов](sprints/world_00_logs_verification_report.md).

**C03–C04 реализованы и проверены в ограниченном scope:** исправлен порядок terrain strip/wedge indices и collision faces; существующая земля видна сверху. 168 focused checks, шесть настоящих fork arms на 184729/42/77777, 333/333 контакта объектов, физический луч сверху и Vulkan culling сверху/снизу подтверждены. Пороги старых watchdog сохранены, пустые mesh/ground/props больше не считаются успехом. ChunkFoliage менять не понадобилось. 21 окончательный PNG прочитан и проверен. [Отчёт C03–C04](sprints/world_00_c03_c04_verification_report.md).

**Общая чистая приёмка: INCOMPLETE.** Финальные surface/watchdog/AGENTS diversity/monotony/rider/Vulkan запуски чистые, но replay-final-1 снова дал warning о 6 ObjectDB instances; причина не устранена. Старые route failures=9/routes=4 и fixed-seed junction/envelope failure ранее воспроизведены на исходном HEAD; вариация commit benchmark остаётся открытой. Эти suites не ремонтировались. Rider PASS относится к 355,9/500 м по прежнему 70% порогу. Ранние parse/headless неудачи сохранены в отчёте; намеренная logger I/O fixture даёт ожидаемый engine ERROR и не называется чистым запуском. Цельной местности, полного physics replay и человеческой оценки поездки ещё нет.

## Цель и ближайший игровой результат

Seed создаёт цельную природную местность: гору, долины, хребты и склоны. По ней прокладывается велосипедная дорога с естественными развилками и выбором спокойной или технической линии. Игрок получает приятную аркадную поездку и разнообразные виды. Итоговая цель — бесконечное продолжение этого мира без добавления гонок, инвентаря, усталости или прокачки.

Первый видимый срез ограничен: цельная местность на трёх seed, затем одна дорога длиной примерно 1–2 км и настоящий проезд существующего велосипеда. Сначала проверяем эту связку; развилки, декор и масштабирование следуют за ней.

## Какие документы читать и чему доверять

| Источник | Назначение и статус |
|---|---|
| Этот документ | Единственная краткая точка актуального состояния. Не сертификат работоспособности. |
| [VISION](../VISION.md) | Продуктовая цель и ограничения механик; уточнения пользователя отражены выше. |
| [AGENTS](../AGENTS.md), [test-integrity](../.antigravity/rules/test-integrity.md) | Действующие правила работы, согласования и честности проверок. Не изменены. |
| [Глобальный план](WORLD_GENERATION_GLOBAL_PLAN.md) | Согласованное направление и последовательность WORLD-00A → WORLD-00B → WORLD-00 → WORLD-01 → WORLD-02 и далее. Каждая задача выполняется отдельно. |
| [implementation_plan](../implementation_plan.md) | Ограниченный план текущей задачи в начале файла; ниже сохранена история. |
| [ARCHITECTURE](../ARCHITECTURE.md) | Описание систем. Текущие границы уточнены этим этапом; старые измерения и обещания требуют отдельной проверки. |
| [ROAD_GENERATION](../ROAD_GENERATION.md) | Геометрические требования и прежние решения. Есть расхождения с кодом/AGENTS; не считать требования доказанными без сверки. |
| [TEST_PLAN](../TEST_PLAN.md), [карта покрытия и replay](TEST_COVERAGE_AND_REPLAY.md) | Исторические команды/результаты и актуальные границы критических проверок, частота, предлагаемые corrections и минимальные логи. |
| [ROADMAP](../ROADMAP.md), [DEVELOPMENT_ROADMAP](../DEVELOPMENT_ROADMAP.md) | Сохранённые спринты и прежний стратегический порядок. Их «завершено» и «следующий этап» не отменяют текущую последовательность. |
| [Handoff](../MTB_WORLD_GENERATION_HANDOFF.md) | Передача контекста; актуальный блок расположен в начале, прежние записи — история. |
| [Аудит 23.09](../CURRENT_STATE_AUDIT.md), [аудит Sprint 5](../TECHNICAL_AUDIT_AND_ROADMAP.md), [отчёты спринтов](sprints/) | Исторические снимки. PASS относится только к описанным там запускам и покрытию. |

## Что фактически есть в коде

| Часть | Текущее устройство и ограничение | Источник |
|---|---|---|
| Запуск и seed | Старт через меню; основная сцена запрашивает случайный session seed. `--seed=N` разрешается до создания генератора. Это порядок инициализации, а не подтверждение полного replay мира. | [project.godot](../project.godot), [main.tscn](../scenes/main.tscn), [WorldManager](../scripts/world/world_manager.gd) |
| Велосипед и камера | Существующие контроллер, VisualsRoot, сигналы, камера, аудио и recovery переиспользуются. Настройки сейчас не меняются. FOV кокпита 78–83°, третьего лица 68–72°; `high_speed_steer_limit = 0.045`. | [BicycleController](../scripts/player/bicycle_controller.gd), [BikeCamera](../scripts/camera/bike_camera.gd) |
| Дорога | Seeded grammar, локальные события и гладкая геометрия записываются в RoadPathData. MountainProfile добавляет продольный профиль. Прямого terrain-aware выбора пути по MountainMassifField в RoadLogic нет. | [RoadLogic](../scripts/world/road_logic.gd), [RoadPathData](../scripts/world/road_path_data.gd), [MountainProfile](../scripts/world/mountain_profile.gd) |
| Земля | MountainMassifField существует как математическое поле. TerrainCarver использует разницу высот поля между центром дороги и флангом; вершины привязаны к высоте дороги. Внешний фланг ограничен `W_FAR = 38м`, внутренний сжимается на повороте. C03 исправил лицевую ориентацию и соответствующие collision faces. Отдельной сетки земли, покрывающей мир в XZ, нет. | [MountainMassifField](../scripts/world/mountain_massif_field.gd), [TerrainCarver](../scripts/world/terrain_carver.gd), [RoadChunk](../scripts/world/road_chunk.gd) |
| Стриминг и развилки | ChunkStreamer управляет ветками и жизненным циклом чанков, RoadGraph — топологией/выбором. Окно активной ветки 350м впереди и 65м позади. Подготовка и commit чанка синхронные; один чанк за кадр не доказывает отсутствие задержек. | [ChunkStreamer](../scripts/world/chunk_streamer.gd), [RoadGraph](../scripts/world/road_graph.gd) |
| Коллизия и декор | RoadChunk передаёт весь `terrain_faces` в коллайдер земли с битовой маской 4. Отдельного сокращённого near-only terrain collider нет. MultiMesh размещены локально по чанку и типу объекта. | [RoadChunk](../scripts/world/road_chunk.gd), [ChunkFoliage](../scripts/world/chunk_foliage.gd) |
| Логи | Node owner под WorldManager после разрешения seed и до генерации; отдельные run_id/manifest/events/ring/source copies, авто-flush 2 с и выход. Редкие fork/GEOM события и явный problem API; live snapshot помечает surface_checked=false. Replay ограничен geometry checkpoints и 128 шагами, не записывает input/физику или весь бесконечный мир. | [SlowCycleLogger](../scripts/core/slow_cycle_logger.gd), [отчёт WORLD-00-LOG](sprints/world_00_logs_verification_report.md) |

Целевая цепочка «земля → путь по земле → локальная выемка/насыпь → итоговая поверхность → декор и поездка» ещё не реализована целиком. Наличие отдельных классов и исторических PASS не означает готовность этой цепочки.

## Что известно и что пока не доказано

- **Установлено чтением кода:** master при успешном subprocess учитывает ожидаемый бюджет assertions, а не собирает их фактическое число; C04 contact watchdog считает отсутствие земли нарушением и проверяет полноту contacts; прежняя поздняя установка seed screenshot-runner исправлена C01–C02; metadata и effective seed теперь проверяются. Источники: [master](../scripts/test/test_sprint_4m_master.gd), [foliage watchdog](../scripts/test/test_foliage_contact_watchdog.gd), [seed capture](../scripts/test/capture_seed_audit.gd).
- **Установлено чтением формул/ветвлений:** профиль долины имеет скачок 4,5м на границе дна; fatal fallback вызывается после любой неуспешной повторной валидации, без проверки причины; в коде `MIN_RADIUS = 18м`, в AGENTS — 19м; посадочный допуск расширен на 10°. Эти противоречия не исправлены документационным этапом. Источники: [massif](../scripts/world/mountain_massif_field.gd), [RoadLogic](../scripts/world/road_logic.gd), [road contract](../scripts/world/road_generation_contract.gd), [airborne contract](../scripts/world/road_airborne_contract.gd).
- **Подтверждено C03–C04:** обычные полосы и splitter wedge были обращены обратной стороной; CW indices исправлены вместе с collider faces, при сохранённом culling. Верх/низ проверены Vulkan и физическим лучом. Реальные committed pine/birch/boulder contacts обеих arm на трёх seed проверены; это ограниченные чанки, не все поверхности/объекты/маршруты. За пределами дорожных полос земли по-прежнему нет.
- **Не подтверждено текущим запуском:** полная детерминированность при разных сценариях стриминга, проезд обеих веток на реальной физике, отсутствие дыр/утечек, качество горы и дороги, FPS/память длительной поездки. Старые результаты сохраняются как ограниченные исторические свидетельства.

**Уточнение WORLD-00B и C01–C02:** прежний mismatch в `capture_seed_audit._process` воспроизведён и исправлен установкой до add_child. В прежнем `capture_visual_audit._init` аналогичный дефект не подтверждён; порядок настройки сделан явным. Оба инструмента проверяют реальный seed, committed участок, позу/камеру, Image/PNG и metadata. Исторические certificate store сообщения WORLD-00B/baseline сохраняются в отчётах, не переносятся автоматически на чистые окончательные captures. C01–C02 не исправлял поверхность; последующий C03 исправил обратные грани существующих полос. Полноценное покрытие мира ещё не создано.

## Порядок ближайших задач

1. **WORLD-00A:** этот статус, ссылки и отделение истории. Отчёт: [world_00a_documentation_report](sprints/world_00a_documentation_report.md).
2. **WORLD-00B завершён:** [карта проверок и replay/log contract](TEST_COVERAGE_AND_REPLAY.md), [отчёт и baseline](sprints/world_00b_verification_report.md). Никакие существующие assertions не переписывались.
3. **WORLD-00:** только необходимые исправления воспроизводимости/проверок/поверхности для первого опыта. C01–C02 реализованы и проверены в scope captures; общая чистая приёмка INCOMPLETE по замечанию выше. Минимальные логи/replay реализованы; общая чистая приёмка остаётся INCOMPLETE. C03–C04 реализованы и проверены в описанном выше scope; чистая приёмка INCOMPLETE. Следующий отдельный scope — WORLD-01: terrain-only на трёх seed и C05, граница долины вместе с полем.
4. **WORLD-01, затем WORLD-02:** показать цельную местность, проложить одну дорогу, выполнить настоящий проезд и оценить вид с велосипеда.

Дальнейшие задачи описаны в глобальном плане. После каждой задачи фиксируются результат, оставшиеся ограничения и область следующего изменения. Для технических изменений требуется отдельный `implementation_plan.md` и согласование по AGENTS. Изменения семантики существующих тестов также согласуются по test-integrity; обязательные gates из AGENTS сохраняются.

## Передача следующему исполнителю

Прочитать этот статус, AGENTS, test-integrity, активный блок implementation_plan, глобальный план и карту покрытия. Проверить HEAD/git status; перечитать код своей задачи. Не начинать весь backlog сразу. Не менять велосипед/камеру при работе с миром. Не принимать исторический PASS за текущую игровую готовность. C03–C04 завершён в ограниченном scope; изменения topology/contact predicates были согласованы пользователем («сделай как лучше») при сохранении порогов. Следующий scope — отдельный план WORLD-01/C05 до кода; новые изменения старых assertions согласовать. Использовать достоверные captures и WORLD-00-LOG recordings. Сохранить открытые ObjectDB/branch/performance результаты; не ремонтировать весь QA. Затем terrain-only на трёх seed и граница долины вместе с полем, одна дорога 1–2 км и настоящий проезд.
