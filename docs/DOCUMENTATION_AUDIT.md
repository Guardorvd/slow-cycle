# D0 — Documentation Audit and Disposition

STATUS: CURRENT

Дата: 02.10.2026. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`. Инвентаризация до D0: 29 tracked Markdown; link existence baseline: 182 occurrences, 28 absolute/nonportable links. Read-only migration checks не являются runtime baseline. Authority: [Blueprint](TARGET_GAME_BLUEPRINT.md), [Master](MASTER_IMPLEMENTATION_PLAN.md); [index](README.md), [accepted decision](DECISIONS/D0-001-documentation-authority.md), [completed D0](plans/completed/D0.md).

## Статусы и выполненные dispositions

CURRENT — действует только в указанной области, не runtime PASS. HISTORICAL — dated snapshot/evidence. SUPERSEDED — заменённая normative role с retained technical body. CONTRADICTORY — конфликт старой authority/claim. REDUNDANT — дублирующая current role, не отсутствие полезной истории.

Таблица из approved audit сохраняет один основной before-status и согласованное действие. Все разрешённые D0 dispositions выполнены; after-role в последней колонке — новая область. Frozen test-integrity остаётся зарегистрированным governance conflict; его semantics не менялись. Прежний implementation journal archived, новый D0 plan completed, root slot NO_ACTIVE_PLAN. Ни один suite не переклассифицирован.


| Документ | До D0 | Основание и действие после согласования | После D0 |
|---|---|---|---|
| `docs/TARGET_GAME_BLUEPRINT.md` | CURRENT | Product North Star; §§5,15,18,26,28–36 задают region-first, сеть, свободу и human acceptance. Уже создан; сохранить байт-в-байт. | CURRENT: продукт |
| `docs/MASTER_IMPLEMENTATION_PLAN.md` | CURRENT | Стратегия pivot; §VII D0 и §XVIII задают D0→D1→Q0→Q1→Q2→R0. Уже создан; сохранить байт-в-байт. | CURRENT: стратегия и порядок фаз |
| `AGENTS.md` | CONTRADICTORY | Planning gate и защита player полезны. Rules 6/10 закрепляют детали road-first; root не называет новые authorities. Добавить минимальный блок полномочий/области legacy rules; не делать D1-переписывание правил. | CURRENT: рабочие ограничения; legacy scope явно ограничен |
| `README.md` | CONTRADICTORY | Статус и навигатор ведут к WORLD-01/C05, DEVELOPMENT_ROADMAP назван главным планом. Сохранить снимок; обновить точку входа и ссылки, оставить инструкции запуска/управления. | CURRENT: вход и запуск |
| `VISION.md` | CONTRADICTORY | Цикл описывает изменяющуюся дорожную ленту; ссылка на старый сквозной roadmap. Сохранить снимок; заменить коротким резюме Blueprint без второго самостоятельного дизайна. | CURRENT: краткое производное продукта |
| `ARCHITECTURE.md` | CONTRADICTORY | Смешаны current runtime, старая target-схема и Sprint 6–7: biome от MountainProfile, terrain от дороги, Zero-Post. Сохранить полный снимок; оставить проверяемое as-is описание и ссылку на новый target. | CURRENT: только as-is runtime |
| `docs/CURRENT_PROJECT_STATE.md` | CONTRADICTORY | Технические ограничения полезны, но authority map и WORLD-01/C05 устарели. Сохранить снимок; обновить hierarchy/phase, не объявлять runtime исправленным. | CURRENT: датированное состояние |
| `docs/WORLD_GENERATION_GLOBAL_PLAN.md` | SUPERSEDED | Уже содержит terrain-first идеи, но иная WORLD-цепочка, предпочтение сохранения RoadGraph и early ride до новых R-слоёв. Добавить SUPERSEDED и точные замены; тело сохранить на месте. | SUPERSEDED: прежняя стратегия |
| прежний `implementation_plan.md` | SUPERSEDED | Завершённые WORLD-00 и старые P/B планы смешаны; старый next task больше не действует. Сейчас заменить одним D0 ExecPlan; после одобрения перенести оригинал целиком в plan history. | CURRENT: один D0 ExecPlan; прежнее тело HISTORICAL |
| `DEVELOPMENT_ROADMAP.md` | SUPERSEDED | Старый A–H/release путь; содержит одновременно C01–C02, WORLD-01 и B5 как следующие задачи. Обновить только статус/навигацию, сохранить тело. | SUPERSEDED: прежний roadmap |
| `ROADMAP.md` | SUPERSEDED | История спринтов содержит DAG, road-driven biomes, Zero-Post и широкие claims готовности. Не является новой стратегией. Статус/ссылки; тело сохранить. | SUPERSEDED: старый roadmap/история |
| `BACKLOG.md` | SUPERSEDED | Старые FEAT-задачи/галочки и будущие визуальные работы не равны новой фазовой программе. Статус/ссылки; IDs и критерии не стирать. | SUPERSEDED: legacy task catalogue |
| `MTB_WORLD_GENERATION_HANDOFF.md` | REDUNDANT | Повторяет current state/next task и старые prompts; уникальные P0/P1/P2 измерения полезны. Заменить актуальную вводную явной historical-навигацией; тело сохранить. | HISTORICAL: handoff и измерения |
| `ROAD_GENERATION.md` | CONTRADICTORY | Полезные RoadPathData/геометрия, но смешаны world authority, старые ограничения и WORLD next steps; 18/19 м не согласованы. Статус SUPERSEDED как world spec, сохранить локальные сведения и явно указать pending mismatches. | SUPERSEDED: legacy geometry reference |
| `TEST_PLAN.md` | CONTRADICTORY | Команды/результаты полезны, но старые next tasks и широкие «100% PASS» не определяют новую acceptance. Статус SUPERSEDED как стратегия; команды/результаты сохранить. | SUPERSEDED: legacy commands/evidence |
| `docs/TEST_COVERAGE_AND_REPLAY.md` | SUPERSEDED | WORLD-00B карта 59 файлов — датированный снимок, не будущая TEST_MATRIX; C05–C08 schedule заменён Master. Статус/ссылки; содержимое сохранить. | SUPERSEDED: legacy coverage/replay reference |
| `.antigravity/rules/test-integrity.md` | CONTRADICTORY | §§1,3 объявляют все tests вечной спецификацией и требуют подгонять код под них; Master §§IV–V вводит разные роли. Файл полностью заморожен в D0; конфликт явно зарегистрировать для D1/Q0. | CONTRADICTORY: известный governance conflict, отложен |
| `CURRENT_STATE_AUDIT.md` | HISTORICAL | Датированный аудит 23.09, старые runtime/performance claims. Добавить формальный historical header/замены, тело сохранить. | HISTORICAL |
| `TECHNICAL_AUDIT_AND_ROADMAP.md` | HISTORICAL | Sprint 5 дефекты D-21…D-26 и прежний remediation. Сохранить дефекты/измерения; статус и ссылки. | HISTORICAL |
| `branch_generation_review.md` | HISTORICAL | Снимок 25.09 до graph-backed runtime; старые числа/строки не равны текущему поведению. Статус/ссылки; тело сохранить. | HISTORICAL |
| `docs/TODAY_CHANGES_2026_10_01.md` | HISTORICAL | Сводка конкретного дня; её «дальше WORLD-01» относится к 01.10. Добавить historical header без переписывания результатов. | HISTORICAL |
| `docs/sprints/sprint_4m_validation_report.md` | HISTORICAL | Результаты 23.09 и human claims принадлежат тому запуску, не новому slice. Только статус/навигация. | HISTORICAL |
| `docs/sprints/stage_b_validation_report.md` | HISTORICAL | Stage B claims и следующий Stage C относятся к старому milestone; file:// ссылки непереносимы. Статус/ссылки, исходные вердикты сохранить как claims отчёта. | HISTORICAL |
| `docs/sprints/sprint_6_v4_completion_report.md` | HISTORICAL | Road-first biomes/camera/watchdogs 29.09 не подтверждают новый region layer. Только статус/навигация. | HISTORICAL |
| `docs/sprints/world_00a_documentation_report.md` | HISTORICAL | Предыдущий documentation reset с другой authority map; выполненная работа не отменяется. Только статус/ссылки. | HISTORICAL |
| `docs/sprints/world_00b_verification_report.md` | HISTORICAL | Четыре ограниченных baseline, lifecycle probe и карта 59 инструментов. Только статус/ссылки. | HISTORICAL |
| `docs/sprints/world_00_c01_c02_verification_report.md` | HISTORICAL | 27 checks/19 PNG — происхождение captures, не quality/world acceptance. Только статус/ссылки. | HISTORICAL |
| `docs/sprints/world_00_logs_verification_report.md` | HISTORICAL | 37 checks и geometry replay, не физический replay; INCOMPLETE сохранить. Только статус/ссылки. | HISTORICAL |
| `docs/sprints/world_00_c03_c04_verification_report.md` | HISTORICAL | 168 checks/333 contacts/21 PNG в узком scope; полный мир не реализован. Только статус/ссылки. | HISTORICAL |


## Конфликты и границы решения


| ID | Источники/конфликт | Решение D0 | Последующая граница |
|---|---|---|---|
| D0-C01 | README navigator; ARCHITECTURE §1; state authority map; несколько roadmap объявляют себя текущими | Единственный authority map по §4; старые стратегии SUPERSEDED | Не выбирать roadmap по удобству |
| D0-C02 | WORLD-01/C05, B5/B6, Sprint 6/7 и C01–C02 как конкурирующие next steps | В current документах только D0; после принятого D0 ближайшая допустимая подготовка D1 | Исторические next steps сохраняются только в отмеченном прошлом |
| D0-C03 | TerrainCarver road-relative полосы против Blueprint §5/FinalSurface | As-is описывает полосы; target описывает независимый terrain и локальную деформацию дороги | R1–R7, никакого переписывания carver в D0 |
| D0-C04 | RoadGraph DAG (ROADMAP:177, BACKLOG:347; road_graph.gd:263) против loops/merges/cross-connections | RegionRouteGraph — будущая замена topology, старый DAG не ограничивает продукт | R5; старый граф/tests остаются неизменны |
| D0-C05 | MountainProfile как «single source of biome weight» (ARCHITECTURE §12), высота от arc-distance | Region geography/hydrology → BiomeField; одна мировая высотная опора | R1/R3/R4/R6/R7; не менять RNG/формулы |
| D0-C06 | RoadGrammar/streamer выбирают направление и ритм мира | RoutePlanner планирует corridor; road synthesis исполняет; JourneyDirector предлагает intents | R5/R6/R16; grammar — локальный vocabulary |
| D0-C07 | Per-chunk placement и Rule 10 как универсальная форма мира | Current per-chunk groups сохраняются; target MultiMesh per spatial cell + type | R10/R11; culling/locality сохраняются, chunk identity не вечна |
| D0-C08 | Zero-Post/запрет всех указателей (ARCHITECTURE §2.1; WORLD-03) против Blueprint §26 human traces | Историческое ограничение не переносится в продукт; безопасность road clearance сохраняется | R12; знаки/props сейчас не возвращать |
| D0-C09 | Бесконечная лента/early release/LOD против region slice 20–30 мин и continuation R21 | Отличать первый slice, зрелый region 40–70 мин и долгосрочное продолжение | Не перескакивать к R19–R21 |
| D0-C10 | «Тесты — неприкосновенный source of truth» против Master test categories | Разделить authority продукта и неизменность текущих assertions; зарегистрировать нерешённый governance conflict | D1 меняет инструкции; Q0 строит TEST_MATRIX. В D0 ни один suite не переклассифицируется |
| D0-C11 | 18 м в code/ROAD_GENERATION против 19 м AGENTS; широкая fatal fallback; landing +10° | Записать три отдельных pending legacy mismatches; различать observed value и нормативное требование | Позднейший узкий одобренный plan; не «исправить» docs переписыванием чисел под код |
| D0-C12 | 125 expected checks, old 100% PASS, teleported fork, geometry replay трактуются как готовность мира | Evidence с revision/coverage/limitations; E3/E4/E5/E7 не выводятся из E1/E2 | Q0–Q2 и соответствующие R-фазы; новых runtime PASS нет |
| D0-C13 | Blueprint показывает полную world pipeline; Master вводит landmarks/vistas/director поздними фазами | Различать целевую композицию и поэтапную миграцию; future input не выдавать за существующий контракт | Не переставлять фазы и не создавать новые schema/API в D0 |

### 3.1. Открытые технические сведения, которые обязательно сохраняются

Датированное состояние фиксирует: нет world-covering XZ terrain, terrain-aware дороги, полного physics replay и подтверждения нового human ride; ObjectDB warning о 6 instances не устранён; route failures=9/routes=4 и fixed-seed junction/envelope failure наблюдались ранее; commit benchmark нестабилен. Rider 355.9/500 м проходил прежний 70% порог. Valley boundary jump 4.5 м, радиус 18/19 м, fallback и landing mismatch не исправлялись документацией.

В D0 эти записи переносятся со ссылкой на исходный отчёт/ревизию как **известные на предыдущей проверке**, а не как заново воспроизведённые дефекты. Даже чистый documentation diff не делает общую runtime acceptance PASS. Старые подтверждения C01–C04/LOG не аннулируются, но ограничены своим coverage.


## Actual resolution

D0-C01/C02: current entries используют одинаковую authority и D1 как следующую подготовку. D0-C03…C09/C13: target и as-is разделены, ownership/migration отражены без code edits. D0-C12: evidence границы заданы, legacy claims окружены historical notice.

D0-C10: продуктовая precedence решена в AGENTS/strategy/decision в пользу Blueprint/Master; переписывание frozen rule и per-suite reclassification **не выполнены** (D1/Q0). D0-C11: радиус/fallback/landing limits **не согласованы заново и не исправлены**; нужны отдельные измеренные/approved tasks. ObjectDB/valley/route/performance findings также сохраняются.

## Сохранность и ссылочные исключения

29 baseline документов = 26 изменённых путей + неизменные Blueprint, Master и test-integrity. Добавлены ровно 15 согласованных документов; raw mixed journal сохраняется byte-for-byte, остальные четыре snapshots сохраняют body кроме metadata/link corrections. [History catalogue](history/README.md) содержит original hashes; [plan-history map](plans/history/README.md) разрешает raw links с original root base.

15 непереносимых repo-code hyperlink occurrences исправлены относительными targets; 13 остальных baseline absolute links указывают на внешние local evidence и остаются сохранёнными ссылочными исключениями. Исторические source-line номера сохранены как текст с revision, не претендуют на текущую строку. Absolute paths на внешние evidence (Codex outputs/logs/PNG/ZIP/JSON и старый external Antigravity plan) сохранены как исторические location references; перенос и доступность не проверялись. HTTP URL неизменны и сетью не проверялись.

Исключение link base применяется только к `docs/plans/history/IMPLEMENTATION_PLAN_PRE_D0_ed7d132.md`, SHA256 `6DC2F9963254BA40C6A5537872081EF519E27E0AB9CBAE1D2FAD1842707D642C`. Внешние local evidence и raw old links — explicit exceptions, не освобождение текущей navigation/anchors от проверки.

New derived документы CURRENT в своей области: docs index, target architecture, migration matrix, test strategy, audit, decisions index/record, history и plan-history indexes. Четыре snapshots и raw old journal HISTORICAL; completed D0 — завершённый accepted docs task, не active authorization. Список всех resulting files и checks находится в completed D0 и отдельном post-commit report.


## Exact external hyperlink exception register

Исключения относятся только к сохранению внешней ссылки; existence/contents не использованы как новые D0 evidence. Никакие current internal paths этим исключением не покрываются.

| Source | Original external location | Verification boundary |
|---|---|---|
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/artifact-verification.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/session-test-17368.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/replay-negatives-summary.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-vulkan-contact-sheet.jpg` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-42-17368-93022bf3ba2e74a6/manifest.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-46-17368-c86b9377cb5fa751/manifest.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-11-47-17368-091a69caf0e71a57/manifest.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/2026-10-01T16-21-29-22812-92ea6b87e49d11f2/manifest.json` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/replay-final-2-console.log` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-branch-console.log` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/baseline-route-elevated-console.log` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/gate-branch-fixed-console.log` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |
| `docs/sprints/world_00_logs_verification_report.md` | `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/outputs/world00-logs/baseline-branch-fixed-console.log` | HISTORICAL external evidence; доступность/содержимое в D0 UNVERIFIED |

## Exact whitespace preservation exception

Три inherited Markdown hard breaks сохранены в новых snapshots: `docs/history/README_PRE_D0.md` строки 15 и 50, `docs/history/VISION_PRE_D0.md` строка 18. Строки взяты из original body и проверены archival comparison; новые authored docs trailing whitespace не вводят. Обычный staged diff checker указывает эти три строки; task-local `git -c core.whitespace=-blank-at-eol diff --cached --check` проходит при независимой проверке authored whitespace. Ни repo/global Git config, ни attributes не изменялись.
