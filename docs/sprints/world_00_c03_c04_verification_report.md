# Documentation status — D0

STATUS: HISTORICAL

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](../TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](../MASTER_IMPLEMENTATION_PLAN.md).

Current state: [CURRENT_PROJECT_STATE](../CURRENT_PROJECT_STATE.md); navigation: [docs index](../README.md); historical catalogue: [history](../history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

---

# WORLD-00 C03–C04 — поверхность и проверка опоры

Дата: 01.10.2026. Исходный HEAD `7c33004ee5c383eb304cfb7fdc9fdad0a3a5f6a2`. План был представлен до кода; на вопрос о двух точных mutations пользователь ответил «я не знаю — я не инженер. сделай как лучше». Выполнен согласованный полный scope, численные пороги сохранены. Локальный коммит объединяет C01–C02, LOG и этот этап; точный SHA/status вынесен в commit-verification.json после коммита.

## Что изменилось

Земля вдоль дороги была обращена обратной стороной. RoadChunk теперь выдаёт обычные strip и splitter wedge indices по CW вместе с соответствующими collision faces. Вершины/траектория/seed RNG не менялись. Culling не отключался. Независимая спецификация: [Godot ArrayMesh 4.7](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html).

PreparedChunkData хранит фактический диапазон wedge; старый magic offset 240 удалён из watchdog. Topology считает наружную нормаль через отрицательный cross и отвергает пустой mesh/отсутствующий ожидаемый wedge. Contact считает missing_ground, checked_contacts и непустую ожидаемую выборку. Floating >+0.05 м, buried <−0.35 м и остальные старые геометрические пороги сохранены.

Добавлены surface_audit_support.gd, test_surface_audit_contract.gd и capture_surface_culling_audit.gd: настоящая подготовка/commit, физический ray, реальные обе arm/MultiMesh, независимый GPU верх/низ. ChunkFoliage менять не понадобилось. Велосипед/камера/управление, field/valley/route/fallback/radius и материалы не менялись. Отключение bike physics применяется только в новом teleport coverage; обязательный старый rider использует настоящую физику.

## Проверки и точное покрытие

| Запуск | Фактический результат | Граница |
|---|---|---|
| focused-final, Vulkan | 168 checks, 0 failures, clean | 6 реальных arm на seed 184729/42/77777; 36 committed chunks, 16830 triangles, 333/333 prop contacts; отсутствующих/перевёрнутых/floating/buried — 0 |
| topology-final, headless | 23400 vertices, 37500 triangles и отдельно 288 wedge triangles; все defects 0; clean | Prepared arrays, 5 seed × 15 chunks и 3 объявленные synthetic fork fixtures; GPU отдельно |
| contact-final, headless | 350/350 prop contacts; floating/buried/missing ground/terrain — 0; clean | Prepared pine/birch/boulder, 3 seed × 12 chunks; травинки не покрыты |
| culling-final, Vulkan | 4/4 PNG, terrain >500 pixels сверху, 0 снизу; clean | Реальный generated ordinary/wedge mesh, fixture camera/material CULL_BACK; synthetic wedge не объявляется реальной fork |
| negative fixtures в focused-final | Корректный generated mesh/опора проходит; пустой/reversed mesh, отсутствующий wedge, удалённые faces, неожиданные empty props и +0.06/−0.36 м отвергнуты | Входы проверок, без production special cases; явно barren fixture разрешён отдельно |
| negative-headless | exit 1, точный INCOMPLETE reason=REAL_MULTIMESH_RENDERER_REQUIRED; clean | Dummy renderer не подтверждает настоящие MultiMesh transforms |
| AGENTS diversity/monotony | Оба exit 0, clean | Неизменённое покрытие старых suites |
| AGENTS physical rider | exit 0, clean; 355.9/500 м, max lateral 1.30 м, roll 20.5°, 6 events | Старый 70% PASS; не весь маршрут и не обе arm |
| AGENTS visual + seed captures | 8/8 + 9/9 PNG; actual seed/position/committed target/Image/save/reload/metadata; clean | 3 фиксированных seed; реальный рендер, не human ride |
| Неизменённые соседние checks | carver 97/97, review 25/25, event seams 96/96, verge/clearance exit 0; clean | Прежние sample coverage; их сообщения «100%» не расширяют это покрытие |
| logger-final | 37 checks, 0 failures; намеренный I/O engine ERROR/DIRECTORY_UNAVAILABLE | Expected negative fixture, не clean engine run |
| replay-final-1/2/3 | Каждый 3 checkpoints/1 choice совпал | В первом warning 6 ObjectDB instances; второй/третий clean. Геометрический teleport replay, не физический input replay |

48 runtime source hashes сверены с текущими файлами и сохранёнными source copies. Digest: `9e1769261762282897ad8cdf8c598f8f8c7366763b8ba0b1e3c1e6a9574cf466`. Подписи 51 opening samples на 0–100 м всех трёх seed совпали с C01–C02 до логов и этой правки; это ограниченная проверка сохранности дороги. Digest ранних снимков фиксирует их реальные исходники; финальные culling сняты повторно после правки комментария/guard.

PNG независимо открыты Pillow: 17 world frames 1280×720 и 4 culling frames 256×256, seed metadata и red-pixel counts проверены. Сравнение before/after одной точки seed 184729/100 м и sheets просмотрены: существующие полосы стали видны; за пределами них полноценного мира нет.

## Неудачные попытки и открытые вопросы

Все ранние logs сохранены: focused-01/culling-01 выявили parse/type defects новых runners, исправлены без ослабления predicates. focused-02 headless получил 42/168 failures: dummy MultiMesh отдавал неподходящие transforms. GPU повтор того же реального coverage прошёл, headless теперь явно отвергается. Эти попытки не переименованы в PASS.

Непостоянный warning 6 ObjectDB снова возник в replay-final-1. Причина не устранена. Старые route failures=9/routes=4 и fixed junction/envelope failures ранее воспроизведены на исходном HEAD, вариация benchmark тоже открыта; здесь их не ремонтировали и не объявляли закрытыми. Общая чистая приёмка **INCOMPLETE** по обязательному требованию zero leaks. Финальные surface/watchdog/generation gates сами чистые.

Математическое поле/скачок 4.5 м на границе долины не исправлены. Не доказаны полный terrain-only мир, все seed/ветви/streaming cadences, физический проезд 1–2 км, длительные FPS/memory budgets и человеческая оценка. Физический луч относится к локальной committed fixture, не ко всем 36 runtime chunks. Runtime contacts — геометрическая проверка настоящих committed transforms/faces.

## Документация и артефакты

Сверен другой сегодняшний чат «Изучить архитектуру проекта»: WORLD-00A/00B были только documentation/audit и вошли в 7c33004. Обновлены CURRENT_PROJECT_STATE, coverage, global plan, README, ARCHITECTURE, TEST_PLAN, ROAD_GENERATION, roadmaps/BACKLOG/handoff, active implementation_plan и сводка дня. Старые отчёты/измерения сохранены и помечены историей; AGENTS/test-integrity не менялись. Последующие этапы не начаты.

Корень артефактов: `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-surface/`. Для каждого процесса `*-launch.json` хранит точную команду/exit/duration/messages, рядом console/engine logs. Внешний timeout 60 с; новый runner watchdog 55 с. Команды используют Godot 4.7.2, `--path` репозитория, `--script res://scripts/test/<runner>`, GPU `--rendering-driver vulkan` либо `--headless`, затем output-root/diagnostics-root. Точные replay manifests записаны в launch JSON.

- `surface-contract-27744.json`, `artifact-verification.json` — actual coverage и независимая проверка.
- `2026-10-01T17-06-13-4916-169b55945b30c928/` — окончательный culling, Image/PNG и metadata.
- `2026-10-01T16-58-08-19008-24fcbe0fed783441/` — 8 visual frames.
- `2026-10-01T16-58-16-30624-2f43c51a6c9abb07/` — 9 seed frames.
- `session-test-22268.json` и recordings `2026-10-01T16-59-05-22268-465d3e712ef3bad3`, `16-59-08-22268-11698f0d4bbb989c`, `16-59-09-22268-697b8af7b5a6576e` (последние два с префиксом `2026-10-01T`) — manifest/events/source copies.
- `before-after-surface.jpg`, `culling-contact-sheet.jpg`, `seeds-contact-sheet.jpg` — просмотренные сравнения.
- `documentation/`, `source-and-doc-snapshot.zip`, `repository-review.json`, `commit-verification.json` — передача и проверенный локальный коммит; большие assets/logs вне Git.

Предыдущие результаты/неудачи остаются в соседних outputs/world00-c01-c02 и world00-logs, не затираются.

## Следующая небольшая задача

Отдельно согласовать WORLD-01/C05: terrain-only участок на 184729/42/77777 с цельной сеткой земли; границу долины исправить вместе с полем и boundary checks. Сначала местность без новой дороги. Затем одна дорога примерно 1–2 км и настоящий проезд. Велосипед/камера/управление сохраняются; развилки/декор/бесконечность/оптимизация позже.

## Test Integrity Verification

- [x] Проверки используют настоящие RoadLogic/TerrainCarver/RoadChunk/main/MultiMesh/collision/render; отрицательные входы меняются только в fixture, без заглушек математического ядра.
- [x] Старые topology/contact predicates изменены по показанному и согласованному плану (§4.2); численные пороги сохранены. Новые tests — функциональность (§4.1), их syntax/type fixes — §4.3. Прочие старые assertions не менялись в C03–C04.
- [x] Подавления ошибок, skip, закомментированных проверок и ослабления порогов — НЕТ. Все failures/warnings сохранены.
- [ ] 100% работоспособность игры не подтверждена. PASS отражает только описанное покрытие; общая чистая приёмка INCOMPLETE из-за открытого replay warning и ограничений.
