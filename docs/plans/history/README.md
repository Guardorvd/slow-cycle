# Slow Cycle — pre-D0 implementation journal

STATUS: CURRENT

Scope: history index/resolution map; содержимое журнала HISTORICAL/SUPERSEDED как active plan. [Raw snapshot](IMPLEMENTATION_PLAN_PRE_D0_ed7d132.md), [current plan slot](../../../implementation_plan.md), [completed D0](../completed/D0.md), [current authority index](../../README.md).

Original path: `/implementation_plan.md`; source revision `ed7d1322da1a5700a8c64425708e1c813213c7f6`; exact bytes 220294; SHA256 `6DC2F9963254BA40C6A5537872081EF519E27E0AB9CBAE1D2FAD1842707D642C`. Snapshot побайтовый: metadata/header и link rewriting внутрь не добавлены. Его title/старые «следующие задачи» не являются текущим поручением.

## Mixed statuses и структура

Журнал содержит completed WORLD-00A/00B, C01–C02, LOG, C03–C04, разные P/B планы/outcomes, повтор P2.1d, unconfirmed diagnostics и future proposals. Индекс headings сохраняет названия/исходные строки; не объявляет все sections выполненными. Старые approvals относятся только к своему scope. Current future sequence — Master, не этот журнал.

| Original line | Heading |
|---|---|
| 1 | # WORLD-00 C03–C04 и сверка документации за 01.10.2026 |
| 9 | ### TASK: [WORLD-00-C03-C04] Видимость существующей земли и честная проверка опоры |
| 36 | # WORLD-00-LOG — минимальные логи и повторение ошибки |
| 42 | ### TASK: [WORLD-00-LOG] Сохранить контекст сессии и проверить ограниченный геометрический replay |
| 82 | # Реализация WORLD-00 / C01–C02 — достоверные визуальные снимки |
| 88 | ### TASK: [WORLD-00-C01-C02] Сделать происхождение и сохранение каждого кадра проверяемыми |
| 160 | # Выполненный этап: WORLD-00B — карта проверок и минимальные логи |
| 166 | ### TASK: [WORLD-00B] Разобрать проверки и определить минимальный replay/log contract |
| 186 | # Выполненный этап: WORLD-00A — актуальное состояние документации |
| 192 | ### TASK: [WORLD-00A] Согласовать документацию и текущий статус |
| 218 | ## История прежних планов и результатов |
| 222 | # План: процедурная MTB-сеть и правдоподобные развилки |
| 224 | # Этап B — подробный план надёжной MTB-трассы |
| 226 | ## Порядок работ |
| 242 | ## B3a — измеримый каталог текущих MTB-событий |
| 244 | ### TASK: [B3a] Зафиксировать production-форму существующих элементов трассы |
| 263 | ### Проверка плана |
| 272 | ### Итог B3a — baseline геометрии |
| 287 | ## B3b — согласовать микросброс с фактической высотой |
| 289 | ### TASK: [B3b] Ограничить production crest/micro-drop измеренными 35 см |
| 308 | ### Проверка плана B3b |
| 318 | ### Итог B3b — ограниченная высота micro-drop |
| 331 | ## B4a — стык RoadChunk на production-геометрии событий |
| 333 | ### TASK: [B4a] Проверить непрерывность дороги и roadside terrain на границах mesh/collision чанков |
| 352 | ### Проверка плана B4a |
| 361 | ### Итог B4a |
| 376 | ### TASK: [B1] Проверка пути MTB-события до дорожного меша и коллизии |
| 395 | ### Плановая проверка B1 до реализации |
| 402 | ### Отчёт B1 |
| 413 | ## B2 — seed-управляемый ритм поездки |
| 417 | ### TASK: [B2] Seeded long-range MTB event rhythm |
| 439 | ### Проверка плана до реализации |
| 448 | ### Отчёт B2 |
| 463 | ## P2.1d — Измеримый детерминированный fork pacing |
| 467 | ### Реализация |
| 473 | ### Проверка результата |
| 481 | ### Следующая точка |
| 485 | ## P2.1d — Измеримый детерминированный fork pacing |
| 489 | #### TASK: [P2.1d] Deterministic fork candidate pacing and trace |
| 510 | ### Проверка плана |
| 520 | ## P2.1c — Парный предварительный просмотр коридоров развилки |
| 524 | ### Задача |
| 526 | #### TASK: [P2.1c] Deterministic paired fork corridor preview |
| 547 | ### Граница доказательства |
| 551 | ### Итог P2.1c |
| 559 | ## P2.1 — Детерминированный terrain-aware выбор fork site |
| 563 | ### Цель |
| 569 | ### План реализации |
| 571 | #### TASK: [P2.1] Deterministic terrain-aware fork-site planner |
| 616 | ### Самопроверка плана до исполнения |
| 627 | ### Отчёт P2.1a — выполнено |
| 641 | ## Следующий шаг — P0: интеграционная проверка обеих ветвей |
| 645 | ### Цель |
| 649 | ### Объём работ |
| 659 | ### Не входит |
| 665 | ### Файлы |
| 672 | ### Критерии приёмки |
| 680 | ### Проверка |
| 686 | ### Gate |
| 698 | ### Дальнейшие шаги |
| 705 | ## P0.1 — Аудит стиля и задержки следующего fork — выполнено 2026-09-26 |
| 707 | ### Наблюдение и рабочая гипотеза |
| 711 | ### Итоги |
| 723 | ### Объём |
| 732 | ### Вне scope |
| 738 | ### Файлы |
| 744 | ### Критерии завершения |
| 752 | ### Проверки и целостность тестов |
| 758 | ## P0.2 — Исправить измерение fork-to-fork — выполнено 2026-09-26 |
| 766 | ## P0.3 — Сверка расписания и предложенный pacing contract — выполнено 2026-09-26 |
| 776 | ## Следующий план — P0.4: воспроизвести и расставить приоритеты по проблемам заезда |
| 780 | ### Цель и шаги |
| 792 | ### Файлы и gate |
| 796 | ### P0.4 follow-up — collision-hole isolation (выполнено, defect not confirmed) |
| 802 | ## Цель |
| 806 | ## Принципы решения |
| 814 | ## Этап 0 — Зафиксировать опыт поездки и критерии |
| 822 | ## Этап 1 — Сделать сеть единым источником правды |
| 831 | ## Этап 2 — Генерировать форму спуска и композицию маршрута |
| 841 | ## Этап 3 — Строить реальную непрерывную геометрию |
| 851 | ## Этап 4 — Проверять поездку, не только наличие развилки |
| 861 | ## Предварительно ожидаемые файлы |
| 869 | ## Порядок и риск |
| 873 | ## Результат реализации (25.09.2026) |
| 881 | ## Исходный Gate |
| 885 | ## P0.4 follow-up — collision-hole isolation (completed 26.09.2026; defect unconfirmed) |
| 901 | ## Следующий этап — P1: seeded macro elevation profile |
| 903 | ### TASK: P1.0 Детерминированный макропрофиль спуска |
| 930 | ### TASK: P1.1 Интеграция макропрофиля в road centerline и terrain |
| 964 | ### TASK: REVIEW-FIX-01 Исправления дефектов code review мира и runtime |
| 999 | ### TASK: P2.0 Различимый детерминированный intent FLOW / TECHNICAL |
| 1036 | ### TASK: P2.1b Контракт RouteIntent / RoutePlan |

## Original-base resolution map

Все relative links raw файла разрешаются от **root original path**, а не от каталога snapshot. Это точечное исключение по пути/hash, не waiver для других archives/current docs. Таблица даёт живые navigation ссылки; links в raw snapshot проверяются с original base. HTTP URL/absolute external evidence сохраняются как original references и не проверяются сетью/переносом.

| Raw link | Original root target / live reference |
|---|---|
| `docs/CURRENT_PROJECT_STATE.md` | [docs/CURRENT_PROJECT_STATE.md](../../CURRENT_PROJECT_STATE.md) |
| `docs/sprints/world_00_c01_c02_verification_report.md` | [docs/sprints/world_00_c01_c02_verification_report.md](../../sprints/world_00_c01_c02_verification_report.md) |
| `docs/sprints/world_00_c03_c04_verification_report.md` | [docs/sprints/world_00_c03_c04_verification_report.md](../../sprints/world_00_c03_c04_verification_report.md) |

Архивы plan lifecycle дальше: только фактически завершённый approved task → `docs/plans/completed/<TASK-ID>.md`; root slot очищается под следующий **отдельно утверждённый** plan. Незавершённые historical proposals не переносить туда как completed.
