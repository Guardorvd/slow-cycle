# Documentation status — D0

STATUS: HISTORICAL

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](../TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](../MASTER_IMPLEMENTATION_PLAN.md).

Current state: [CURRENT_PROJECT_STATE](../CURRENT_PROJECT_STATE.md); navigation: [docs index](../README.md); historical catalogue: [history](../history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

---

# WORLD-00B — отчёт о проверках и логах

Дата: 01.10.2026. HEAD: `b6a5ff4`; рабочая копия содержит документационные изменения WORLD-00A/00B. Пользователь разрешил отдельный WORLD-00B: «делай — потом отчет». Код проекта, тесты, сцены, настройки и правила не менялись.

## Результат

Создана [карта покрытия и минимальных логов](../TEST_COVERAGE_AND_REPLAY.md). В ней учтены все 59 GDScript-файлов scripts/test: обязательные gates, проверки затронутой системы, лабораторные/исторические инструменты и helpers. Критические suites разобраны до реально вызываемого кода; полная честность каждого assertion всех файлов не сертифицирована.

Определены 8 конкретных будущих corrections с отрицательными сценариями. Mandatory suites сохранены. Ни одна проверка не удалена, не отключена и не ослаблена. Логирование ограничено manifest с effective seed/версией/настройками/решениями маршрута, редкими событиями и snapshot при ошибке; поток телеметрии каждого кадра не предлагается.

## Что выяснено

1. **Multi-seed кадры могут быть подписаны чужим seed.** `capture_seed_audit` меняет seed после готовности генератора; mismatch подтверждён lifecycle probe в Godot. Подписанный seed и seed RoadLogic расходятся.
2. **У визуального audit диагноз другой.** В `capture_visual_audit._init` ready отложен: текущий seed успевает установиться до генерации. Прежнее предположение о такой же ошибке исправлено. Здесь остаются непроверенный результат save_png, продвижение очереди без Image и отсутствие подтверждения actual capture point/coverage.
3. **Terrain watchdog не подтверждает видимость земли.** Проверяется prepared array без render; ориентация граней согласована с текущим генератором, но противоречит CW-конвенции [Godot ArrayMesh](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html). Headless PASS не снимает этот вопрос.
4. **Foliage contact не считает отсутствие земли ошибкой.** Из общего числа объектов неизвестно, сколько реально получили поверхность. Нулевые floating/buried counters не доказывают контакт всех объектов.
5. **Тест поля гор не обнаруживает известный разрыв формулы долины.** Его текущие сетки/gradient checks проходят; проверка warped границы отсутствует.
6. **Часть доказательств езды — лаборатория или телепорты.** Real virtual rider полезен, но принимает 70% дистанции и имеет branch/absolute-Y ограничения. Fork-часть dynamic rideability отключает физику и выбирает LEFT программно.
7. **Сводные числа не заменяют покрытие.** Master учитывает expected assertion budget, не включает новые suites; его scene soak не измеряет ObjectDB самостоятельно. Логи обычной игры пока не обеспечивают полной записи для replay.

## Фактические запуски

Движок: `Godot Engine v4.7.2.stable.mono.official.ed1daf0bf`. Четыре существующих runner запущены последовательно, без изменения исходников. Команда:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path . --script res://scripts/test/<runner>.gd --quit-after 600 --log-file <temporary-engine-log>
```

`--quit-after 600` — ограничитель незавершённого процесса, не признак успеха. В каждом фактическом выводе найден собственный итог runner. Консоль и engine logs сохранены отдельно в `C:/Users/Luisa/AppData/Local/Temp/slow-cycle-world00b-87c33a04`.

| Runner | Exit / фактический итог | Что этим не подтверждено |
|---|---|---|
| `test_world_session_seed.gd` | 0; `checks=7 failures=0` | Replay геометрии, foliage и физики |
| `test_mountain_massif_field.gd` | 0; same-seed delta 0; 104 отличающихся points; gradient error 0.1333; собственный финальный marker | Непрерывность на границе долины, готовность видимой горы |
| `test_terrain_topology_watchdog.gd` | 0; 23400 vertices, 37500 triangles, 288 wedge triangles; все собственные defect counters 0 | Правильность CW/culling, committed rendering, отсутствие пропущенного terrain |
| `test_foliage_contact_watchdog.gd` | 0; 350 props; floating=0, buried=0 | Contact всех 350: missing_ground не учитывается |

Во всех четырёх выводах есть `ERROR: Failed to read the root certificate store.` Это отдельное сообщение окружения; сами runners завершились и напечатали итоги, но **чистый запуск без ошибок не заявляется**. Parse/assertion/ObjectDB leak сообщений в этих четырёх выводах не обнаружено; это не вывод об отсутствии всех утечек проекта.

Дополнительно создан временный `seed_lifecycle_probe.gd` **в системном temp**, без добавления/изменения теста в репозитории. Он сравнил одинаковый порядок add_child/назначения seed в `_init` и `_process`. Exit 0, marker `SEED_LIFECYCLE_PROBE_COMPLETE`; то же сообщение certificate store, без parse/leak сообщений. Фактические строки:

```text
INIT_AFTER_ADD ready=false logic_exists=false
INIT_AT_FIRST_PROCESS world_seed=184729 logic_seed=184729
PROCESS_AFTER_ADD ready=true world_seed=1099242821 logic_seed=1099242821
PROCESS_AFTER_SEED_SET world_seed=42 logic_seed=1099242821 mismatch=true
```

Это эмпирическое подтверждение разницы lifecycle, не запуск самих capture runners или GPU-аудит. Случайный seed приведён как фактическое значение этого запуска; повторный probe может выбрать другой случайный seed.

## Ближайшая техническая задача

**C01–C02: достоверные визуальные captures.** Исправить порядок seed в multi-seed инструменте; в двух актуальных captures проверять effective seed генератора, покрытие точки, Image и сохранение PNG; сохранять метаданные и отдельный run_id; подтвердить отрицательные сценарии. Это отдельная небольшая задача с планом до изменения кода.

Затем — минимальные session/replay логи и необходимые surface corrections, после чего terrain-прототип. Не ремонтировать всю историческую QA-инфраструктуру перед первой горой. C05 (граница долины) выполнить вместе с полем WORLD-01; real rider corrections нужны до полного проезда WORLD-02.

## Test Integrity Verification

- [ ] Все проверки честно доказывают реальные требования? **Нет полного подтверждения**; известные слепые зоны перечислены. Четыре runner вызывают реальные классы, но их широкий PASS ограничен картой покрытия.
- [x] Изменялись ли файлы тестов проекта? **Нет**. Временный lifecycle probe служит независимой диагностикой вне репозитория.
- [x] Добавлены ли подавления, `.skip`, `test.todo()` или закомментированные assertions? **Нет**.
- [ ] Зелёный статус подтверждает полную работоспособность? **Нет**: exit 0 отдельных runner не является PASS игры; GPU, manual ride и negative fixtures не выполнены.

## Проверка артефактов

Инвентаризация автоматически сверена с scripts/test: 59 реальных файлов = 59 записей, без пропусков/лишних/дубликатов.

- Проверены 14 изменённых/новых Markdown-документов рабочей копии, включая сохранённые изменения WORLD-00A; 107 локальных ссылок, все цели существуют.
- `git diff --check`: exit 0; новые документы отдельно проверены на trailing whitespace, финальную новую строку и повреждённые символы кодировки.
- Изменения production/test/scenes/assets/settings/AGENTS/test-integrity: **0**. HEAD остался `b6a5ff4`, коммит не создавался.
- Пять console logs просмотрены отдельно: по одному certificate store ERROR в каждом, прочих ERROR/parse/assert/leak сообщений не найдено.
- WORLD-00B завершён. Отрицательные fixtures corrections, GPU и manual ride не запускались; следующий технический этап не начат.
