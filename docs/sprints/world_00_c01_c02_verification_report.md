# Documentation status — D0

STATUS: HISTORICAL

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](../TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](../MASTER_IMPLEMENTATION_PLAN.md).

Current state: [CURRENT_PROJECT_STATE](../CURRENT_PROJECT_STATE.md); navigation: [docs index](../README.md); historical catalogue: [history](../history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

---

# WORLD-00 / C01–C02 — отчёт о достоверности снимков

> Отчёт отдельного завершённого этапа; HEAD/dirty tree и «следующий шаг» ниже относятся к моменту этого запуска. Последующий C03–C04 выполнен, текущая передача — [статус](../CURRENT_PROJECT_STATE.md) и [сводка дня](../TODAY_CHANGES_2026_10_01.md). Прежние результаты/ошибки сохранены.

Дата: 01.10.2026. Репозиторий: `C:/Users/Luisa/Documents/antigravity/goofy-chandrasekhar`. HEAD: `7c33004ee5c383eb304cfb7fdc9fdad0a3a5f6a2`, рабочая копия изменена; новый коммит не создавался. Пользователь согласовал план: «делай - потом отчет и кратко что дальше».

## Результат и граница приёмки

**C01–C02 реализованы и проверены в их области:** seed устанавливается до генерации; каждый сохранённый кадр имеет подтверждённые seed, участок, фактическую точку и камеру, читаемый PNG и metadata. Проверены 19 PNG окончательного кода: 8 видов visual audit, 9 кадров трёх seed, повтор и CLI override. Negative fixtures распознают ожидаемые ошибки.

**Общая чистая приёмка по AGENTS остаётся INCOMPLETE.** Неизменённый physical rider получил свой PASS, но в первом запуске выдал предупреждение об утечке 6 ObjectDB instances; диагностический повтор с verbose прошёл без предупреждения. Причина непостоянного предупреждения не установлена и не считается исправленной. Кроме того, реально пройдено 355.9 м из 500 м: runner принимает старый порог 70%. Это не подтверждает полный маршрут.

Полноценная земля не создавалась. В достоверных кадрах видны пустоты, тонкие полосы и фрагменты земли, декор без видимой опоры. Сохранение кадра не является одобрением качества мира. Геометрия, физическая поездка и человеческая оценка остаются отдельными проверками.

## Что изменено

- `capture_seed_audit.gd`: seed и отключение рандомизации до add_child; настоящая seed battery, подтверждение start/100m/fork; старт честно подписан 2.5 м; отсутствующая развилка не заменяется «успешным» corridor.
- `capture_visual_audit.gd`: сохранены 8 запросов fp/tp/drone. Настройка до add_child сделана явной; аналогичная seed-ошибка его прежнего `_init` **не объявлена подтверждённой**. Для возвращения к ранним точкам после pruning создаётся новая сцена с тем же seed.
- Новый `capture_audit_support.gd`: общий код этих двух инструментов, guards seed/path/committed triangles/camera/Image/PNG/metadata, движение малыми шагами, уникальная run directory и ограничение времени. Sample indices чанков не используются как доказательство coverage после pruning: проверяются реальные committed road triangles и сохранённый диапазон пути. Наличие terrain mesh не выдаётся за отсутствие дыр или правильный winding.
- Новый `test_capture_audit_contract.gd`: 27 focused checks и три end-to-end negative режима через тот же capture helper. Реальный WorldManager/RoadLogic/main, реальные Image и файловая система; production не подменяется.
- Метаданные содержат revision/dirty state, список и SHA256 исходников (включая shader), digest, runtime renderer/Godot, default/override/effective и branch seed, generation parameters, range/sample/branch/chunk/fork, sample/bike/camera transforms, FOV, route choices, размеры viewport/PNG и проверенную повторную загрузку.
- Только в capture-инструменте остановлена физика экземпляра велосипеда и удерживается его поза. Контроллер/камера/управление и настройки игры не изменены. Перед выходом capture даёт движку два кадра на освобождение сцены.

Production, сцены, ресурсы, logger, старые assertions и остальные тесты не изменены. WORLD-00A/00B не повторялись. C03–C08 и создание поверхности не начаты.

## Проверки окончательного кода

Godot `4.7.2.stable.mono.official.ed1daf0bf`. GPU: Vulkan 1.3.289, Forward+, NVIDIA GeForce GTX 1650 SUPER. PNG: 1280×720. В каждом launcher JSON сохранена точная команда, exit, время, summary и сообщения движка; отдельно console/engine logs. Лимит процесса 60 с, внутренний capture deadline 55 с.

| Проверка / артефакт | Фактический результат | Граница вывода |
|---|---|---|
| `contract-final-02` | 27 checks, failures=0, exit 0 | Seed, ranges, реальная опора capture на mesh, обе fork arm, camera, null/empty/wrong-size Image, запись/reload/overwrite/corrupt PNG, metadata I/O, deadline. Ошибки и WARNING повреждённого PNG специально вызваны fixture; это не «запуск без всех ERROR». |
| `visual-final` | 8/8 PNG + JSON, exit 0, 7.141 с | Реальные fp/tp/drone на requested s 0/100/220/220/300/520/100/250. Без engine errors/leaks. Имена «switchback» сохранены как прежние имена запросов; тип дорожного события отдельно не сертифицирован. |
| `seeds-final` | 9/9 PNG + JSON, exit 0, 8.296 с | Seed 184729/42/77777: старт 2.5 м, 100 м и реальная первая развилка. Без engine errors/leaks. |
| `repeat-final` | 1/1, exit 0 | Новый run_id; у seed 184729 точные checkpoint signature 0–100 м, sample, s и pose велосипеда совпали с батареей. Побитовая идентичность GPU/физики не заявляется. |
| `cli-visual-final` | 1/1, exit 0, effective seed=42 | Default configured 184729, CLI override 42, manager/generator/streamer 42. Signature совпала с seed 42 батареи. |
| `e2e-seed-final` | exit 1, `INCOMPLETE/SEED_MISMATCH`, 0/1 | Намеренно неверное ожидание на границе capture; реальный генератор не менялся. Нет CAPTURED/success marker. |
| `e2e-target-final` | exit 1, `TARGET_OUTSIDE_PATH`, 0/1 | Точка за концом настоящего path не превращается в снимок крайнего sample. |
| `e2e-save-final` | exit 1, `PNG_SAVE_FAILED:7`, 0/1 | Файл вместо директории только внутри fixture; права пользователя не менялись. Ожидаемая save ERROR зарегистрирована. |
| `timeout-final` | exit 1, `TIMEOUT`, 0/8 | Искусственно малый budget 0.01 с; нет ложного успеха или внешнего kill. |
| `session-seed-final` | 7 checks, failures=0, exit 0 | Неизменённые требования выбора/CLI seed; не replay всего мира. |
| `diversity-final` | exit 0, собственный PASS, без engine errors/leaks | Старые итоговые условия X-spread на 50/100/200 м и обе стороны на 300 м; не terrain/render diversity. |
| `monotony-final` | exit 0, 0 violations, без engine errors/leaks | Три seed; минимальный relief горных окон 1.31/2.48/1.23 м. Это метрики дороги. |
| `rider-final` | exit 0, PASS; 355.9/500 м, lateral 1.30 м, 6 roll events | **WARNING 6 ObjectDB instances leaked. Чистый gate не закрыт.** Ни порог, ни assertions не менялись. |
| `rider-leak-probe` | exit 0, те же 355.9 м, без ERROR/leak warning | Один диагностический verbose повтор. Непостоянное предупреждение предыдущего запуска остаётся открытым. |

Независимая `artifact-verification.json` проверила размеры/читаемость всех 19 PNG, seed/range/actual s/coverage, metadata, уникальность четырёх run_id, одинаковый checkpoint и три различающиеся подписи seed; отдельно подтвердила точные причины четырёх negative результатов. Все окончательные capture metadata имеют один source digest:

`c748f803bade7a4a10025f49d88c933b3bce34193379af701cb3dd48b38ec474`.

| Seed | Origin первой развилки, local s | Реальная точка кадра, local s |
|---|---:|---:|
| 184729 | 599.833984 | 577.833959 |
| 42 | 449.957336 | 427.957333 |
| 77777 | 400.256256 | 378.256254 |

Область развилки подтверждена непустыми committed road/terrain mesh обеих arm. Физическая проходимость этих arm не проверялась этим capture.

## Просмотр и открытые вопросы

Просмотрены обзорные листы всех 17 основных кадров и полные drone/fork PNG. Рендер настоящий; видны дорога и велосипед, но рядом большие пустые области и отрывочные грани/декор. По этим кадрам нельзя выбрать одну причину всех дефектов: winding, поверхность, side masks и сцены требуют следующего воспроизведения. Туман, материалы, culling и камера в этом этапе не менялись.

Остаются неизвестными: причина непостоянного ObjectDB warning; устойчивость долгого завершения/стриминга; полноценная поверхность горы; мировой replay при pruning/interleaving; обе ветки на настоящей физике; полная поездка 1–2 км и человеческое ощущение. Старые PASS не закрывают эти вопросы.

## Промежуточные сбои сохранены

- `baseline-console.log`: старый seed capture реально попросил 184729, настроенное свойство 184729, actual generator 2058349745. Это независимое воспроизведение C01. Там же certificate store ERROR; baseline не считается чистым игровым запуском.
- `contract-01`: три parse errors типизации новых переменных. Исправлены явным типом helper; окончательные scripts компилируются и исполняются без этих ошибок.
- `contract-final`: промежуточный ObjectDB warning 6 instances; verbose probe не повторил его. У capture добавлено ожидание disposal; последующие финальные capture/contract не выдали leak warning. Причинная связь этим не доказана.
- Первое отображение launcher summary старых watchdogs в консоли Python столкнулось с cp1251/символом галочки. Godot уже завершился, JSON и raw logs были сохранены. Исправлен только вывод launcher; результаты взяты из сохранённых exit/log/summary, не придуманы по отсутствующему выводу.

## Где артефакты и как повторить

Корень всех данных: `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-c01-c02/`.

- Visual: `2026-10-01T15-28-34-28356-84b76d9306cfeada/` — 8 PNG, 8 JSON, manifest.
- Seed battery: `2026-10-01T15-29-24-11796-e704b1444462ced4/` — 9 PNG, 9 JSON, manifest.
- Repeat: `2026-10-01T15-29-32-24020-4518015b41c8714e/`; CLI: `2026-10-01T15-29-36-18980-4b6974cbd3aa9afd/`.
- `visual-final-contact-sheet.jpg`, `seeds-final-contact-sheet.jpg`: обзорные листы, оригинальные PNG сохранены отдельно.
- `artifact-verification.json`: независимые фактические сверки, включая не закрытую общую приёмку.
- `runtime-source-snapshot.zip`: источники с проверенными SHA256, соответствующие dirty-tree captures; восстановление не зависит только от HEAD.
- `<label>-launch.json`, `<label>-console.log`, `<label>-engine.log`: команды и полный вывод каждого успешного, отрицательного и промежуточного запуска.

Повтор: запускать Godot `--path <repo> --script res://scripts/test/capture_seed_audit.gd --rendering-driver vulkan --resolution 1280x720 -- --seed=42 --audit-frame=start --audit-output-root=<new-root>`. Без seed выполняется исходная батарея; multi filter — `all/start/100m/fork`. У visual filter — `all` или номер `01`…`08`. `--audit-timeout=N` ограничен 55 с; для полноценного GPU capture не использовать headless. Новый run directory создаётся автоматически.

## Следующая небольшая задача

Отдельный план: минимальные session/replay логи и воспроизведение ошибок. Сохранять effective seed, версию, маршрут/позицию и причину дефекта при начале, ошибке и выходе; включить этот ObjectDB warning как открытый случай завершения. Без потока каждого кадра и общего QA framework. Затем отдельно — необходимые corrections поверхности/её проверок; граница долины исправляется вместе с полем WORLD-01. Сейчас следующий этап не начат.

## Test Integrity Verification

- [x] Новые проверки вызывают реальный production код, реальные meshes/Image/I/O. Negative input и I/O fixtures не подменяют генератор; фактическое покрытие ограничено таблицей.
- [x] Файлы тестов изменены по явному одобрению: только два capture согласно C01–C02; новый focused runner добавлен для новой функциональности (test-integrity §4.1). Остальные существующие assertions неизменны.
- [x] `@ts-ignore`, `as any`, skip/todo, закомментированные/подавленные проверки не добавлялись. Ожидаемое падение проверено по точной причине/exit/summary.
- [ ] Зелёный статус доказывает всю игру: **нет**. Scope capture подтверждён; чистая общая приёмка INCOMPLETE, поверхность/полная поездка/человеческая оценка не закрыты.
