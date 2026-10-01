# WORLD-00-LOG — минимальные логи и ограниченное воспроизведение

> Отчёт отдельного завершённого этапа; HEAD/dirty tree и «следующий шаг» ниже относятся к моменту этого запуска. Последующий C03–C04 выполнен, текущая передача — [статус](../CURRENT_PROJECT_STATE.md) и [сводка дня](../TODAY_CHANGES_2026_10_01.md). Прежние результаты/ошибки сохранены.

Дата: 01.10.2026. Репозиторий: `C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar`. HEAD до/после — `7c33004ee5c383eb304cfb7fdc9fdad0a3a5f6a2`; коммит не создавался. Сохранены изменения предыдущего C01–C02. План записан перед кодом; пользователь прямо поручил подготовить и реализовать этот небольшой этап. История плана сохранена в `implementation_plan.md`.

**Результат:** реализована запись сессии и проверено повторение ограниченных точек геометрии на настоящем генераторе. Общая чистая приёмка **INCOMPLETE**: один непостоянный ObjectDB warning, два старых branch suites с failures и нестабильный commit benchmark. Это не доказательство готовности игры, цельной земли или полного физического replay.

## Что изменилось

- `SlowCycleLogger` получил один Node owner под WorldManager. Начало сессии — после разрешения seed, до генерации. Старые статические log/flush вызовы сохранены; новый ring также ограничен 5000 строками.
- Каждая сессия имеет новый `run_id`, `manifest.json`, `events.jsonl`, `diagnostics.log` и каталог `sources/`. Requested/effective seed, версия/dirty tree, SHA256 исходников, конфигурация, движок/фактический renderer, редкие события, решения маршрута и контрольные точки записываются отдельно от ring. Проверены 48 копий runtime-файлов в каждом из трёх основных recordings. Digest не включает весь архив assets или тесты: это конкретный список `source_hashes`, а не сертификат полного проекта.
- Работает авто-flush раз в 2 с, сохранение при checkpoint/problem и завершении сцены. Закрытие окна подключено к тому же finish API; отдельного ручного испытания закрытия окна не проводилось. `SESSION_CLOSED` означает завершение записи, а не исправность мира. Hard kill может не оставить SESSION_END; полный crash recorder не создавался.
- WorldManager предоставляет наблюдаемый snapshot: позу/скорость игрока, active branch/seed, route origin, доступный path range, ближайший sample и активные чанки. `nearest_sample_s` приблизителен; это не точная накопленная дуга физической поездки. `surface_checked=false` явно сохраняется. Последний доступный live snapshot остаётся после teardown. В обычной main автоматически сохраняется открывающий checkpoint 0–100 м.
- ChunkStreamer записывает фактически созданную развилку и подтверждённый LEFT/RIGHT с origin, seeds, местом и tick. RoadLogic сохраняет исходный rejection до перезаписи отчёта, реальные violations/stats/limits для repair/fallback. Алгоритмы и условия генерации не изменялись. Новые GEOM записи подключены; реальные fatal fallback в этих коротких recordings не вызваны, их end-to-end покрытие не заявляется.
- Ошибка I/O даёт явный код/путь в stderr и INCOMPLETE. NaN/Inf сохраняются явными строками. Replay inputs ограничены 128 шагами; потеря полноты помечается, не выдаётся за успех.
- Добавлены `test_session_diagnostics.gd` и `replay_session_diagnostic.gd`. Replay сверяет источник, конфигурацию, фактический seed, fork origin/seed и подписи непустых диапазонов. Велосипед в этих двух инструментах телепортируется с отключённой физикой. Production-велосипед, камера, управление, поле и поверхность не менялись. C01–C02 scripts побайтово совпадают с сохранённым архивом предыдущего этапа.

## Проверки и фактический результат

Каждый процесс ограничен внутренним watchdog и/или внешним launcher до 60 с. Команды, длительность, exit code и исходные engine сообщения сохранены в `*-launch.json` и `*-console.log`; ранние неудачные запуски также оставлены.

| Запуск | Результат и граница |
|---|---|
| `logging-05` | 37 checks, failures=0, exit 0. Три реальные main-сессии: 184729 LEFT, 42 RIGHT, 77777 LEFT; авто-checkpoint, выбор/arm, overflow 5101 строк, изоляция сессий, problem pose/+Inf, реальный авто-flush, teardown, журнал. Намеренный файл вместо output directory вызывает один ожидаемый engine mkdir ERROR и DIAGNOSTIC_IO_ERROR; это не clean run без ошибок. |
| `replay-final-1/2/3` | Все exit 0, каждый сравнил 3 checkpoints и 1 choice. Проверены 0–100 м дважды и 40 м выбранной arm. В `replay-final-2` — warning об утечке 6 ObjectDB instances. PASS marker относится к сравнениям, этот процесс не считается чистым. |
| `replay-right-verbose` | Один диагностический повтор правой ветки: те же 3 checkpoints/1 choice, warning не повторился. Причина не найдена; прежний warning не закрыт повторным PASS. |
| `negative-*` | 13/13 точных ожидаемых nonzero/INCOMPLETE, без неожиданных engine errors и внешних timeout. Подробности ниже. |
| `gate-session-seed` | Неизменённый runner: 7 checks, failures=0, без engine errors/leaks. |
| `gate-diversity`, `gate-monotony` | Обязательные AGENTS gates прошли без engine errors/leaks; покрытие остаётся описанным в карте проверок. |
| `gate-rider` | Настоящая Input-driven физика, seed 184729: 355,9/500 м, max lateral 1,30 м, 6 cornering events; прежний PASS по 70% порогу. Без engine errors/leaks в этом запуске. Не доказывает полные 500 м или человеческую оценку езды. |
| `gate-vulkan` | 8/8 PNG, Vulkan Forward+, 1280×720, seed 184729; Image/save/reload/metadata подтверждены. Без engine errors/leaks. Кадры просмотрены: прежние белые пустоты/неполная земля остаются. |
| `gate-branch` | Неизменённый route integration: exit 1, failures=9, routes=4; у 184729 не получены обе graph edges, у 42 получены 4 route rows. |
| `baseline-route-elevated` | Отдельная копия точного HEAD через git archive: те же failures=9/routes=4 и те же ошибки 184729. Это подтверждённый прежний результат, не исправлен в logging scope. |
| `gate-branch-streaming` | 44/45, exit 1, нарушение junction tangent/envelope. Manifest обнаружил effective seed 1465212956 вместо requested 184729: старый runner оставляет randomize включённым. Assertions не менялись. |
| `baseline-branch-fixed`, `gate-branch-fixed` | С одинаковым CLI `--seed=184729` нарушение junction/envelope присутствует на HEAD и в новой версии. Новая версия также получила max commit 1,308 мс и avg 0,861 мс выше порогов 1,0/0,85; в первом новом запуске benchmark был 0,795/0,687, в fixed baseline — 0,721/0,664. В измеряемом RoadChunk.commit новый logger не вызывается, его код не изменён. Вариация сохранена; причина/влияние не доказаны, performance gate не объявляется закрытым. |

Случайный baseline branch launch был 45/45, но его effective seed не записан старым logger: это не сравнение с фиксированным seed. Первый sandbox import/route baseline содержал ошибки доступа к editor directories/certificate store; не считается чистым запуском. Elevated route baseline повторил те же route failures без этих сообщений окружения. Источники тестов в baseline и текущем репозитории совпадают.

**Отрицательный replay:** отсутствующий manifest → MANIFEST_MISSING; неверный тип seed → SEED_INPUT_INVALID; отсутствующая config → CONFIG_INVALID; иной digest → SOURCE_MISMATCH; incomplete inputs → REPLAY_INPUTS_INCOMPLETE; пустые checkpoints → CHECKPOINTS_MISSING; >128 шагов → REPLAY_STEP_BUDGET; choice=3 → CHOICE_INVALID; изменённая подпись → CHECKPOINT_MISMATCH; другая config → CONFIG_MISMATCH; другая fork origin → FORK_MISMATCH; фактический CLI seed отличается → SEED_MISMATCH; короткий watchdog → TIMEOUT. Fixtures — отдельные копии входных manifest в `replay-negative-inputs/`; recordings не переписывались. Проверено именно ожидаемое основание отказа, а не произвольный exit 1.

В `artifact-verification.json` независимо проверены readable JSONL и lifecycle, исходники/копии/hash, live snapshot, PNG и seed. Открывающая geometry signature 0–100 м на **всех трёх seed совпадает с C01–C02 до добавления логов**. Это доказательство этих диапазонов, не всего мира или interleaving/pruning.

Ранние `logging-01/02` выявили конфликт имени Logger и чтение global_transform при teardown; устранены import alias/guard действительного игрока. `logging-04` выявил ожидание автоматического checkpoint в новом тестовом helper до его реального выполнения: helper теперь ждёт завершённый production checkpoint, проверка наличия осталась прежней. Ранние replay отказы выявили отличие JSON numeric float от enum int; проверка теперь принимает ровно числа 0/1, диапазон выбора не расширен. Старые assertions и thresholds не менялись.

## Артефакты и повторение

Все перечисленные файлы находятся рядом с этим отчётом, в `outputs/world00-logs/` текущего чата:

- [Проверка артефактов](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/artifact-verification.json), [focused summary](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/session-test-17368.json), [13 negative результатов](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/replay-negatives-summary.json), [просмотр 8 Vulkan кадров](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-vulkan-contact-sheet.jpg).
- [184729 LEFT manifest](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-42-17368-93022bf3ba2e74a6/manifest.json), [42 RIGHT manifest](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-46-17368-c86b9377cb5fa751/manifest.json), [77777 LEFT manifest](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-47-17368-091a69caf0e71a57/manifest.json). В каждой директории — sources, diagnostics и events. Runtime digest: `46d6b7de107f306720cf4a1503695dc8831dd16eeb90bd28115610df5f74d9d0`.
- [Vulkan manifest и оригинальные PNG](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-21-29-22812-92ea6b87e49d11f2/manifest.json), [warning правого replay](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/replay-final-2-console.log), [старый route failure](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-branch-console.log), [сравнение route на HEAD](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/baseline-route-elevated-console.log), [fixed branch failures](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-branch-fixed-console.log), [fixed branch baseline](C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/baseline-branch-fixed-console.log).
- `source-and-doc-snapshot.zip` сохраняет текущие 48 runtime files, новые runners, прежние capture и актуальную документацию. Копия отчёта и статуса лежит также в репозитории. В `work/` — временные launchers/fixtures tools и git archive baseline, они не добавлены в проект.

Обычная main пишет в `user://slow_cycle_sessions/<run_id>/`; `--diagnostics-root=<directory>` меняет только место артефактов. Для geometry replay с теми же runtime-исходниками:

```powershell
& 'C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path 'C:\Users\Luisa\Documents\antigravity\goofy-chandrasekhar' --script res://scripts/test/replay_session_diagnostic.gd -- --replay-manifest='C:\Users\Luisa\Documents\Codex\2026-10-01\slow-cycle-c-users-luisa-documents\outputs\world00-logs\2026-10-01T16-11-46-17368-c86b9377cb5fa751\manifest.json'
```

Пустые/неподтверждённые inputs дают INCOMPLETE. Runner не восстанавливает исходники автоматически: другой runtime digest честно отвергается. `report_diagnostic_problem(code, details)` сохраняет явный problem snapshot; перехват всех push_error движка или автоматическая диагностика отсутствующей поверхности не добавлялись. Внешний engine log нужен отдельно. Полный input/physics replay, все seed×обе arm, long soak, crash recovery, оптимизация I/O и реальная человеческая поездка не проверены.

## Следующая небольшая задача

Этот этап реализации остановлен на отчёте; следующий автоматически не начинается. Подготовить отдельный ограниченный план **C03–C04**: обнаруживать пустую землю/неправильное winding и отсутствие опоры в текущих terrain/contact checks, согласовать точные изменения существующих assertions, исправить подтверждённую поверхность и проверить реальным Vulkan кадром. Сначала короткие repro на сохранённых точках; не создавать сразу весь мир и не ремонтировать все branch tests. Открытые branch/leak/performance результаты сохранить при передаче. После этого — terrain-only срез на трёх seed и исправление границы долины вместе с полем; затем одна дорога 1–2 км и настоящий проезд.

## Test Integrity Verification

- [x] Проверки работают с настоящими main/генератором/ветками; I/O и replay-input fixtures меняют внешние входы, не подменяют математическое ядро.
- [x] Добавлены два runner для новой функциональности (§4.1), исправлены их import/helper/type defects без ослабления assertions (§4.3). Старые tests/assertions в этом этапе не менялись; C01–C02 сохранены побайтово.
- [x] Подавления ошибок, skip, закомментированных проверок и ослабления порогов — НЕТ. Все обнаруженные failures/warnings сохранены.
- [ ] 100% работоспособность игры не подтверждена. Зелёный результат относится к указанным logger/replay checks; общая чистая приёмка INCOMPLETE, поверхность ещё не исправлена.
