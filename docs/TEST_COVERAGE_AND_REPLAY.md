Q0 navigation (2026-10-03): [accepted Test Authority Map](TEST_MATRIX.md), Q0-TEST-MATRIX-ACCEPTED-1.2, human checkpoint B bound to draft SHA256 `ef994313228752bac7bb93b448e178e9ea9b45ff8483f9ef39856b77eea41ea8`. Categories: 41 ACTIVE_CONTRACT /125 REGRESSION_GUARD /16 LEGACY_CONTRACT /12 OBSERVATIONAL /10 HISTORICAL; non-check artifacts are N/A, not a sixth category. C10 numeric requirements and C12 stale oracle remain OPEN. Existing gates and runtime INCOMPLETE are retained; no Q1/Q2/R0. Task lifecycle/reports: [root plan slot](../implementation_plan.md).

# Documentation status — D0

STATUS: SUPERSEDED

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](MASTER_IMPLEMENTATION_PLAN.md); [TEST_STRATEGY](TEST_STRATEGY.md).

Current state: [CURRENT_PROJECT_STATE](CURRENT_PROJECT_STATE.md); navigation: [docs index](README.md); historical catalogue: [history](history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

D0 не меняет команды исполнения, assertions, thresholds, suite categories или mandatory gates. Это legacy reference; future test authority map создаётся только в Q0.

---

# WORLD-00B — карта проверок и минимальный replay/log contract

Дата: 01.10.2026. Исходники: `b6a5ff4`. Статический разбор, четыре headless baseline и временный seed lifecycle probe; отчёт запусков: [WORLD-00B](sprints/world_00b_verification_report.md). Код проекта и assertions не менялись. Эта карта определяет область следующего исправления, а не объявляет игру проверенной.

**Обновление C01–C02, 01.10.2026 / HEAD `7c33004` + dirty tree:** два capture исправлены по явному согласованию; новый общий helper и focused test добавлены. 27 checks, 19 verified PNG, effective seed/actual s/камера/PNG metadata и четыре ожидаемых nonzero negative результата подтверждены. [Отчёт](sprints/world_00_c01_c02_verification_report.md). Общая чистая приёмка INCOMPLETE: непостоянный ObjectDB warning неизменённого rider; повтор diagnostic clean не считается исправлением причины. Исходная инвентаризация 59 файлов ниже — исторический снимок WORLD-00B, не повторный аудит новых файлов.

**Обновление WORLD-00-LOG, 01.10.2026:** минимальная запись сессии/replay реализована; 37 checks, три seed × 3 checkpoints/1 choice, 13 ожидаемых negative отказов и 8 Vulkan PNG. [Отчёт](sprints/world_00_logs_verification_report.md). Общая приёмка INCOMPLETE: replay leak warning, прежние branch failures и текущая вариация benchmark сохранены. Старые assertions не менялись.

**Обновление C03–C04, 01.10.2026:** два watchdog изменены по согласованному плану, прежние численные пороги сохранены. CW/missing-ground/непустое покрытие усилены; 168 checks, 333/333 реальных prop contacts, 21 окончательный PNG и обязательные AGENTS gates. [Отчёт](sprints/world_00_c03_c04_verification_report.md). Replay warning 6 ObjectDB остаётся открытым. Старые blind spots в таблице ниже описывают исходный WORLD-00B; для topology/contact актуальное покрытие уточнено здесь. Новые surface runners требуют настоящего Vulkan для MultiMesh и верх/низ; headless возвращает INCOMPLETE.

## 1. Как читать результат

- **Обязательный gate:** прямо требуется AGENTS; остаётся обязательным даже при обнаруженных слепых зонах. Менять правило или тест можно только по соответствующему согласованию.
- **Проверка системы:** запускать при изменении её входов, реализации или интеграции. Приёмка должна включать проверки затронутых соседей.
- **Исторический/лабораторный инструмент:** сохраняется для соответствующей регрессии; не служит доказательством качества процедурного мира. Категория не означает удаление или отключение.
- **Ненадёжное доказательство:** exit 0 относится к фактическим условиям runner, но не подтверждает требование, которое runner пропускает или проверяет неверно.

Результат запуска: `PASS` только для названного требования и покрытого диапазона; `FAIL` — нарушение проверенного требования; `NOT_RUN` — не запускалось; `BLOCKED_ENV` — не удалось выполнить из-за окружения; `INCOMPLETE` — отсутствует требуемое покрытие/артефакт. Это предложенный формат будущих отчётов, пока не внедрённый общий runner.

Отдельно записываются ошибки движка и утечки. Exit 0 с сообщением ERROR не превращается в «чистый запуск». Сохранение кадра не означает, что кадр просмотрен и одобрен. Предполагаемое число assertions не становится фактическим счётчиком.

## 2. Критические проверки: требование → реальный путь → ограничения → запуск

Все пути runners находятся в `scripts/test/`; ссылки ведут в исходники. Подробно проверены критические suites ниже. Остальные файлы инвентаризированы по назначению/entry points/dependencies в разделе 3; их каждый assertion не сертифицирован этим аудитом.

| Проверка / требование | Фактический production path и покрытие | Слепая зона / допустимый вывод | Когда запускать |
|---|---|---|---|
| [test_world_session_seed.gd](../scripts/test/test_world_session_seed.gd): выбор и override seed | `WorldManager._resolve_session_seed`; отдельно instantiate main без добавления в дерево; 7 checks | Не запускает генерацию мира и не сравнивает geometry/foliage. Проверка разных случайных seed теоретически допускает редкую коллизию. | При изменении запуска/seed/capture |
| [test_seed_diversity_matrix.gd](../scripts/test/test_seed_diversity_matrix.gd): разнообразие старта; **AGENTS gate** | RoadLogic → RoadPathData, 10 seed × 10 чанков, checkpoints до 500м | Итог проверяет X-spread на 50/100/200м и обе стороны на 300м. Табличные статусы 400/500м не участвуют в итоговом boolean; отсутствие достаточной длины отдельно не проверяется. Нет terrain, render, forks или физики. | Все изменения генерации по AGENTS; не выдавать за разнообразие всего мира |
| [test_monotony_profiler.gd](../scripts/test/test_monotony_profiler.gd): отсутствие длинных однообразных участков; **AGENTS gate** | RoadLogic, 3 seed × 12 чанков; кривизна и изменение Y дороги; 40м окна при mountain_weight > 0.65 | Если горных окон нет, пишет note и не проверяет relief. Прямой постоянный спуск не считается dead corridor, т.к. условие требует ещё почти нулевого уклона. Землю и субъективную скуку не измеряет. | Все изменения генерации; дополнить просмотром мира и ride |
| [test_virtual_rider_bot.gd](../scripts/test/test_virtual_rider_bot.gd): настоящая езда; **AGENTS gate** | Main scene, seed задаётся до add_child, Input-driven BicycleController, до 2500 physics frames; один seed 184729 | Цель 500м, PASS допускает 350м; дистанция равна локальному s активной ветки и может сбрасываться; PITFALL — абсолютный Y < −30; «lateral» — расстояние в XZ до ближайшего sample, не перпендикуляр до линии. Не доказывает обе ветки и все seed. | Все изменения генерации; физический результат отдельно от телепорт-аудитов |
| [capture_visual_audit.gd](../scripts/test/capture_visual_audit.gd): настоящий GPU-вид; **AGENTS gate** | Main, конфигурация до add_child, реальный seed, 8 запросов fp/tp/drone; guards committed range/meshes/pose/camera/Image/PNG/reload/metadata; backward views через новую same-seed сцену | C01–C02: 8/8 Vulkan PNG подтверждены. Прежняя seed-ошибка `_init` не подтверждена probe. Capture доказывает происхождение и сохранение кадра, не качество поверхности, физику или семантику имени «switchback». | Vulkan audit по AGENTS; смотреть кадры и metadata |
| [capture_seed_audit.gd](../scripts/test/capture_seed_audit.gd): multi-seed кадры | Main, seed до add_child, сравнение generator/manager/streamer, 3 seed × start 2.5м/100м/fork; обе committed arm; unique run_id | C01–C02: 9/9 Vulkan PNG, CLI и повтор checkpoint подтверждены. Missing target/fork/Image/PNG не становится успехом. Это teleport capture, не физическая поездка и не whole-world replay. | Seed battery первого видимого среза |
| [test_terrain_topology_watchdog.gd](../scripts/test/test_terrain_topology_watchdog.gd): грани/ширина/складки | RoadLogic → TerrainCarver → `RoadChunk.prepare_geometry_data`; 5 seed × 15 чанков; prepared visual arrays; отдельно 3 искусственных fork contexts | Реального commit/render нет. Положительный cross относительно верхней нормали принят за лицевую сторону; это противоположно CW-конвенции Godot. Пустой terrain пропускается. Wedge выбирается по жёсткому offset 240 faces; не сравниваются все реальные пары fork meshes. | При изменении terrain/indices/carver/forks; после correction, совместно с Vulkan |
| [test_foliage_contact_watchdog.gd](../scripts/test/test_foliage_contact_watchdog.gd): опора объектов | Prepared terrain_faces и pine/birch/boulder transforms, 3 seed × 12 чанков; barycentric XZ-height | **Нет найденного треугольника → нет нарушения.** Объект входит в total_props, но не в проверенный contact. Выбирается ближайшая по Y из возможных поверхностей. Реальные fork side masks и травинки не покрыты. | При изменении поверхности/foliage/fork masks; после missing-ground correction |
| [test_road_clearance_watchdog.gd](../scripts/test/test_road_clearance_watchdog.gd): свободная дорога | Prepared geometry/props, 5 seed × 15 чанков; синтетическое widening на чанках 4/9; nearest sample + binormal | Проверяет центры объектов, не габариты мешей/коллизии. Margin в коде 0.50м, прежние docs описывают другие значения. Нет полноценной второй arm/соседних tiles. Пустой props-набор сам по себе не провалит тест. | При изменении ширины дороги, декора или fork geometry |
| [test_road_verge_seam_watchdog.gd](../scripts/test/test_road_verge_seam_watchdog.gd): фаска | RoadLogic → cross sections TerrainCarver; 3 seed × 10 чанков, разница Y road edge и verts[5/6] | Проверяет нижнюю границу step; верхняя 5см из описания не является assertion. Не проверяет rendered/committed road edge, rough bump, collision seam или весь junction. | При изменении road/verge surface; совместно с event seams и render |
| [test_mountain_massif_field.gd](../scripts/test/test_mountain_massif_field.gd): математика поля | Same-seed instances, сравнение с 99999, сетки точек, gradient/contour, steepness | Нет проверки C0 на границе abs_dx=85. Gradient в production численный, не аналитический; consistency сверяет по X две конечные разности, не независимое решение по X/Z. Contour строится из того же gradient: полезная проверка API, не доказательство гладкости всей земли. | При изменении поля; до terrain-прототипа добавить boundary coverage |
| [test_dynamic_rideability.gd](../scripts/test/test_dynamic_rideability.gd): контакт/flight/landing/turn | Первые три эпизода — реальный BicycleController на авторской lab scene; procedural forks — main/streamer и ray hits | Fork-часть отключает bike physics, телепортирует по sample и фиксирует LEFT. Общий PASS не подтверждает физическую поездку по двум процедурным веткам. | При изменении event/surface integration; явно разделять lab physics и teleported fork coverage |
| [test_route_branch_integration.gd](../scripts/test/test_route_branch_integration.gd), [test_route_clearance_audit.gd](../scripts/test/test_route_clearance_audit.gd) | Main, RoadGraph/streamer, seed 184729/42, заданные branch choices, коллизии/centerlines | Отключён bike physics; настоящая проверка интеграции и clearance, но не rideability. Измеренный набор маршрутов не доказывает весь возможный graph. | При изменении fork/topology/streamer и перед paired-route срезом |
| [test_review_fix.gd](../scripts/test/test_review_fix.gd), [test_terrain_carver.gd](../scripts/test/test_terrain_carver.gd): replay/опора | Foliage с одинаковым logical key и разными chunk ids; две carver instances на фиксированном контексте | Не сравнивают реальный pruning, interleaving разных веток и mutable mountain_weight. Равенство hash/key не доказывает равенство всех transforms в игре. | При изменении context/seed/pruning/foliage |
| [test_sprint_4m_master.gd](../scripts/test/test_sprint_4m_master.gd): старая регрессия | 5 subprocess tiers + lab airborne + paired RoadLogic + смена 7 сцен | Приписывает successful subprocess ожидаемое число checks; новые terrain/watchdog suites не включены. Scene soak возвращает PASS после переходов без самостоятельного измерения ObjectDB/памяти; leak warnings нужно анализировать снаружи. Не называть бюджет 125 «125 фактически собранными assertions». | Контрольная регрессия после интеграции/release; не запускать после каждого Markdown/локального math изменения |
| [test_soak_run.gd](../scripts/test/test_soak_run.gd): lifecycle/память | 3 seed × 500 чанков; main и телепорты; OS.get_static_memory_usage | Статическая память CPU, не GPU/весь процесс; нет измерения плавности кадров и человеческой поездки. Длинный headless soak не подтверждает Vulkan RAM/FPS. | При изменении streaming/LOD/unload; после работоспособного малого среза |

Для winding независимая спецификация — [Godot 4.7 ArrayMesh](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html): лицевые треугольники обходятся по часовой стрелке. Исходное противоречие production/topology исправлено C03; отдельные Vulkan верх/низ и физический луч подтвердили лицевую сторону. Полнота мира этим не доказывается. Не исправлять проблему отключением culling всего terrain.

## 3. Полная инвентаризация и частота

Найдено **59 GDScript-файлов** в scripts/test. Таблица перечисляет каждый файл один раз. Это инвентаризация инструментов, а не число выполненных тестов. Существующие обязательства AGENTS имеют приоритет над предложенной частотой.

| Категория / применение | Файлы | Что не следует из успеха |
|---|---|---|
| Обязательные AGENTS gates при генерации | `test_seed_diversity_matrix.gd`, `test_monotony_profiler.gd`, `test_virtual_rider_bot.gd`, `capture_visual_audit.gd` | Полная готовность игры одним boolean; ограничения — раздел 2 |
| Seed/высотная опора; при изменении соответствующего источника | `test_world_session_seed.gd`, `test_mountain_massif_field.gd`, `test_mountain_profile.gd`, `test_macro_profile_road_integration.gd` | Whole-world replay, terrain-aware route и гладкость вне проверенных точек |
| Дорожные контракты/математика; при изменении path/validator | `test_road_contract.gd`, `test_road_logic.gd`, `test_road_grammar.gd`, `test_winding_road.gd` | Исполнение требований AGENTS при их расхождении с константами теста/кода; рендер земли |
| Event pipeline/ритм; при изменении grammar/events | `test_mtb_event_pipeline.gd`, `test_mtb_event_geometry_catalog.gd`, `test_route_rhythm.gd`, `test_route_intent.gd`, `test_route_plan_contract.gd` | Естественность дороги в ещё не построенной местности |
| Surface/seams/props; при изменении поверхности | `test_terrain_carver.gd`, `test_terrain_topology_watchdog.gd`, `test_road_event_chunk_seams.gd`, `test_road_verge_seam_watchdog.gd`, `test_foliage_contact_watchdog.gd`, `test_road_clearance_watchdog.gd` | Полный GPU/physics PASS при слепых зонах; пустое покрытие |
| Планировщики развилок; при изменении соответствующей логики | `test_fork_site_planner.gd`, `test_fork_pacing_planner.gd`, `test_fork_corridor_preview.gd`, `test_fork_biome_pacing.gd` | Безопасность всей длинной пары маршрутов или реальная поездка |
| Topology/branch integration; при graph/fork/streaming изменениях | `test_road_graph.gd`, `test_fork_decision.gd`, `test_branch_streaming.gd`, `test_fork_geometry_verification.gd`, `test_route_branch_integration.gd`, `test_route_clearance_audit.gd`, `test_route_style_spacing_audit.gd` | Physical ride обеих альтернатив из проверки телепортами |
| Регрессия конкретных исправлений; при затрагивании их систем | `test_review_fix.gd` | Полный replay при pruning/context changes |
| Main-сцена, короткая physics/recovery integration | `test_procedural_run.gd`, `test_dynamic_rideability.gd` | Все seed/ветки; lab-эпизоды отделять от main coverage |
| Длинные lifecycle/нагрузочные кампании; после integration/streaming changes | `test_mountain_validation.gd`, `test_soak_run.gd` | Плавность GPU-кадра и субъективное качество мира |
| Core/UI; при изменении стабильных систем или контрольном integration gate | `test_diagnostics.gd`, `test_mode_select_gamepad.gd` | Готовность нового terrain; код стабильных систем не менять ради terrain |
| Сводный исторический runner; контрольная регрессия | `test_sprint_4m_master.gd` | Включение всех новых suites, измеренные 125 assertions или измеренное отсутствие leaks |
| Лабораторная физика; при surface/physics regression, сохранить | `test_airborne_calibration_gate.gd`, `test_airborne_empirical_gate.gd`, `test_track_ride.gd` | Проезд generated mountain route |
| Лабораторная геометрия; при изменении этих сцен, сохранить | `test_track_verification.gd`, `test_riding_lab.gd`, `test_gravel_loop.gd` | Качество нового production мира |
| Старые sandbox/manual инструменты; запускать по необходимости | `test_ride.gd`, `capture_screenshot.gd`, `capture_third_person.gd` | Автоматическое доказательство корректности |
| Исторические captures/main screenshot tools; по необходимости после сверки | `capture_screenshot_ride.gd`, `capture_sprint3a.gd`, `capture_sprint3c.gd`, `test_screenshot.gd` | Effective seed, проверка PNG, visual acceptance без просмотра |
| Multi-seed capture для нового среза; после correction | `capture_seed_audit.gd` | Детерминированные подписи кадров в текущем виде |
| Генераторы авторских испытательных сцен, не отдельные suites | `test_track_generator.gd`, `riding_lab_generator.gd`, `gravel_loop_generator.gd` | Отдельный PASS: это helpers, а не runners |

Историческая категория не отменяет нужную соседнюю регрессию. Если новый terrain используется старым лабораторным runner, он становится проверкой затронутой системы. Не суммировать assertions всех файлов и не запускать все инструменты подряд по умолчанию.

## 4. Минимальный набор до первого видимого среза

**Подготовка завершена в ограниченном scope:** C01–C02 captures, WORLD-00-LOG и C03–C04 winding/missing-ground реализованы; общая чистая приёмка INCOMPLETE. До terrain-only опыта дополнить massif проверкой границы долины и исправить сам разрыв.

**Локальная проверка после изменения:** parser/runtime + только suite затронутой системы и отрицательные fixtures её исправления. Считать ожидание результата и непустое покрытие частью проверки, а не только exit code.

**Приёмка генерационного изменения:** обязательная батарея AGENTS (seed diversity, monotony, real virtual rider, Vulkan capture), surface/field suites по scope; 3 фиксированных seed `[184729, 42, 77777]` в preview; проверенные кадры с метаданными. Если terrain-only срез ещё не подключён к main, старые gates проверяют сохранность старой main, а не готовность новой поверхности. Preview проверяется отдельно.

**WORLD-02, первая дорога:** добавляются настоящий physical ride по полной заявленной длине и подтверждённые terrain/road collision seams. **WORLD-03, развилки:** оба реальных выбора, их joining/separation/clearance; телепорт-аудит сохраняется как дополнительная проверка. Длинный soak/LOD/perf — при изменении streaming и после малого среза, не раньше.

Не расширять WORLD-00 до исправления всех старых тестов. Старые пороги diversity/monotony/радиуса/landing не менять молча ради нового дизайна. Если они противоречат согласованному продукту, оформлять конкретное решение и согласование отдельно.

## 5. Corrections: C01–C04 выполнены в scope; C05/C06/C08 впереди

Каждое изменение семантики существующего теста ниже требует одобрения по test-integrity. Добавлять отрицательные fixtures в отдельный тест или в явно согласованный runner, не портя production-код и не подавляя FAIL. Положительный сценарий обязан подтвердить, что корректное поведение тоже принимается.

| ID / приоритет | Файлы и минимальная правка | Отрицательный сценарий и требуемый исход |
|---|---|---|
| C01 / до любого нового визуального доказательства | `capture_seed_audit.gd`: исправить подтверждённую позднюю смену seed, задать параметры **до** add_child. В обоих captures сравнить requested и фактический seed генератора после ready и писать metadata revision/seed/route/camera/actual position. Установка до add_child в visual — явная граница конфигурации, не исправление доказанного дефекта его `_init` | Повтор одного seed даёт одинаковую geometry signature; намеренное несовпадение effective seed → FAIL без подписи «успешно»; CLI override явно учтён, не скрыто принят |
| C02 / вместе с C01 | Те же captures: проверить Image, размер, return save_png, наличие/читаемость PNG; проверить покрытие requested distance; ограничить ожидание; сохранять новый run_id, не перетирать чужие кадры | Null/пустой Image, отсутствующий target path, неверный save path или timeout → nonzero/INCOMPLETE. Для проверки ошибки записи использовать фиктивный запрещённый путь внутри тестовой fixture, не менять права пользователя |
| C03 / реализован, scope report выше | `test_terrain_topology_watchdog.gd` + `road_chunk.gd` в одной согласованной задаче: независимая CW-спецификация; обе стороны плоскости с backface culling; fixtures ordinary/fork; непустое покрытие; wedge индексы по реальным данным вместо magic offset | Перевёрнутый индексный порядок → FAIL; корректный CW → PASS; пустой mesh/отсутствующий ожидаемый wedge → INCOMPLETE/FAIL. Подтвердить Vulkan верх/низ. Не менять материалы на CULL_DISABLED ради обхода |
| C04 / реализован, scope report выше | `test_foliage_contact_watchdog.gd`: считать missing_ground, checked_contacts, expected props; учитывать реальные fork contexts и отсутствие поверхности | Объект над пустотой или полностью удалённые terrain faces → FAIL; объект +0.06м и объект −0.36м от реальной поверхности → FAIL при прежних порогах. Нормальная опора → PASS. Нулевой объектный набор допустим только в заранее объявленном barren fixture; иначе INCOMPLETE |
| C05 / до рендера massif | `test_mountain_massif_field.gd` + `mountain_massif_field.gd`: добавить C0-проверку по обе стороны настоящей warped границы долины и анализ X/Z gradient; исправить production стык | Поле со ступенькой 4.5м должно провалить boundary test даже если старые сетки проходят; непрерывное поле проходит при уменьшающемся шаге. Не объявлять глобальный C1 без требований к ridge/abs noise |
| C06 / до использования real rider как полного route gate | `test_virtual_rider_bot.gd`: полная заявленная дистанция, branch-aware пройденная дуга, падение относительно локальной поверхности/валидной зоны; заявленные LEFT/RIGHT coverage | 350м из цели 500м → FAIL/INCOMPLETE; смена ветки не сбрасывает итог; нормальный спуск ниже −30м не считается провалом только по абсолютному Y; потеря опоры/выход из допустимого коридора → FAIL. Изменять критерии только после одобрения |
| C07 / до заявления «чистый запуск» | Будущий bounded launcher/репорт, сначала без нового framework: exit + completion marker + errors/leaks + actual coverage; master оставить контрольной регрессией | Exit 0 без summary, с parse/runtime/assertion error или с ObjectDB warning не становится чистым PASS. Не превращать expected budget master в measured checks |
| C08 / при первой интеграции новых fork/surfaces | `test_dynamic_rideability.gd`: отдельные результаты lab physics и teleported fork; настоящий Input-driven paired ride в отдельном согласованном сценарии | Teleport-only ветка не закрывает physical gate; одна пропущенная альтернатива → INCOMPLETE |

**Очередность узких задач WORLD-00:** C01–C02 (реализованы; отчёт выше, общий clean gate INCOMPLETE) → минимальные session/replay логи и C07 → C03–C04 при reuse старой поверхности → C05 в начале WORLD-01 → C06 до приёмки WORLD-02 → C08 при WORLD-03. Это границы будущих задач, а не разрешение выполнить их все сразу. Логи/replay и C03–C04 уже реализованы. C07 используется как ограниченная внешняя оценка completion/exit/errors/coverage, старый master не переписан. Следующий scope — WORLD-01/C05: terrain-only на трёх seed и граница долины вместе с полем.

Дополнительные слепые зоны (clearance габаритов, upper step limit, полнота monotony/diversity окон, scene-leak измерения) записаны в разделе 2. Их устранять при затрагивании соответствующей системы; не включать автоматически в первую подготовительную правку.

## 6. Минимальные логи для повторения ошибки

**Реализованный ограниченный контракт WORLD-00-LOG:** `test_session_diagnostics.gd` проверяет реальные main-сессии, ring overflow/изоляцию/auto-flush/scene exit, poses, journal и внешний I/O отказ (37 checks). `replay_session_diagnostic.gd` проверяет source/config/actual seed, fork identity и подписи непустых диапазонов, с watchdog; 128 шагов максимум. На 184729 LEFT, 42 RIGHT, 77777 LEFT совпали три checkpoints/один choice; 13 отрицательных входов отвергнуты по точной причине. Подробные logs/commands в отчёте.

Обычная main создаёт автоматический checkpoint 0–100 м. Sources: 48 файлов из указанного в manifest списка, а не весь assets/project archive. Редкие GEOM/fork events подключены; surface/missing-ground detector и перехват всех engine ошибок ещё отсутствуют. Явный `report_diagnostic_problem` сохраняет реальные доступные данные, surface_checked=false. События GEOM в журнале имеют type GEOM, исходный message и emitter violations; прежняя таблица ниже описывает также будущие расширения. Полного input/physics replay, всех seed×обе ветки, prefix бесконечной сессии, автоматического crash recovery и полной C07 инфраструктуры нет. Ни один INCOMPLETE/warning не закрывается зелёным marker.


### Что сохранить постоянно

Одна запись session manifest вне вытесняемого ring buffer:

```json
{
  "schema": 1,
  "run_id": "unique-session-id",
  "revision": "b6a5ff4",
  "working_tree_dirty": true,
  "source_digest": "sha256-of-relevant-runtime-files",
  "godot_version": "4.7.2.stable.mono.official.ed1daf0bf",
  "scene": "res://scenes/main.tscn",
  "effective_seed": 184729,
  "requested_seed": 184729,
  "renderer": "actual-runtime-renderer",
  "generation_config": "snapshot-of-parameters-affecting-world",
  "route_choices": [],
  "replay_complete": true
}
```

Пример задаёт поля, не является фактическим manifest этого аудита. Один commit недостаточен для dirty tree: digest + доступный diff/копия исходников нужны, чтобы восстановить конкретную версию. Renderer получать из процесса, не из имени команды или старого отчёта. Requested/effective seed различать при CLI override.

`route_choices` содержит стабильную идентичность родительской ветки/fork, выбор LEFT/RIGHT, local s, накопленную маршрутную дугу и frame/tick. Не полагаться только на изменяемый номер чанка или индекс sample после pruning. Для первого конечного среза список небольшой и сохраняется целиком. Если в будущей бесконечной сессии prefix решений утерян, `replay_complete=false`; hash prefix сам по себе не позволяет восстановить решения.

### Какие события писать

| Событие | Минимальные поля | Частота |
|---|---|---|
| SESSION_START | manifest, effective seed, scene/config | Один раз до первой генерации |
| FORK_COMMIT / FORK_CHOICE | stable route/fork identity, origin s, LEFT/RIGHT seed/style, выбор игрока | Только при создании/выборе |
| GEOM_REJECT / SOFT_REPAIR / FATAL_FALLBACK | error code, actual violations/limits, branch, interval, world position, phase, geometry signature, generation context | Только событие; повторяющиеся одинаковые ошибки агрегировать с количеством и первой/последней точкой |
| SURFACE_ERROR / NO_GROUND / SAVE_ERROR | revision/run/branch, interval/position, requested/effective seed, filename/return code, actual sample/triangle/context | Только дефект |
| CHECKPOINT / SESSION_END | covered distance, branch choices, replay_complete, counters, выход/причина, путь артефактов | Контрольные точки проверки и конец |

Постоянный поток BIKE/TERRAIN каждого кадра не нужен. При дефекте сохраняется ограниченный recent snapshot: bike pose/speed, local surface/hit/mask, active branch, generation horizon и mutable mountain_weight, последнее событие. Дополнительный verbose режим включается лишь для расследования.

### Как подключить и проверить

Переиспользовать SlowCycleLogger. Его реальный Node owner должен жить в мировой сессии, получать manifest **после разрешения seed, до генерации**, сохранять header/route choices независимо от 5000 строк, flush в контрольной точке, при ошибке и выходе. Logger наблюдает существующие события; не управляет велосипедом/генератором. Не вводить потоки и внешние библиотеки.

В обычном режиме достаточно header + редких событий + итогового snapshot. Не обещать полный архив бесконечной сессии существующим flush, который перезаписывает ring. Ошибка открытия/записи выдаёт одно понятное сообщение stderr с путём/кодом и отмечает диагностический результат INCOMPLETE; не молчать и не делать вид, что лог сохранён.

Проверки исходного logging contract (теперь реализован в WORLD-00-LOG; точное покрытие в отчёте): свежая сессия не содержит предыдущий run; после >5000 diagnostic lines manifest/необходимые choices сохранены; quit/failure сохраняет итог; read-only/неверный путь записи отмечается явно; повтор seed+choices+config воспроизводит geometry signature на проверенных checkpoints. Стабильность стриминга при pruning/interleaving — отдельная проверка; текущая mutable-context архитектура её не гарантирует.

Seed и выборы достаточны для проверки геометрического replay только после доказательства детерминизма. Для воспроизведения физического поведения дополнительно нужны input actions по physics tick и начальное состояние велосипеда; manifest не обещает побитово одинаковую физику автоматически.

## 7. Граница завершения WORLD-00B

Карта, baseline и предлагаемые corrections готовы. Mandatory gates не отменены, тесты не изменены, новый framework не создан. В исходном WORLD-00B чувствительность negative fixtures не проверялась. C01–C04 позже подтвердили свои отрицательные сценарии; будущие C05/C06/C08 ещё не проверены. На момент WORLD-00B следующим был C01–C02. Теперь его реализация/проверки завершены в scope captures (см. обновление/отчёт выше); общая чистая приёмка INCOMPLETE. Минимальные логи/replay теперь реализованы в ограниченном WORLD-00-LOG (см. обновление); общая чистая приёмка INCOMPLETE. C03–C04 также завершён в ограниченном scope: 168 checks, реальные обе arm/3 seed, negative fixtures, GPU/collision отдельно. Следующий отдельный scope — WORLD-01/C05: цельная местность на трёх seed и граница долины вместе с полем.
