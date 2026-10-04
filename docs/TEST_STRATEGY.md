# Slow Cycle — Test Strategy and Evidence Authority

STATUS: CURRENT

Scope: производная стратегия [Master §§V–VI, Q0–Q2, Definition of Done](MASTER_IMPLEMENTATION_PLAN.md) в пределах [Blueprint human acceptance](TARGET_GAME_BLUEPRINT.md). [Index](README.md), [as-is state](CURRENT_PROJECT_STATE.md), [conflicts](DOCUMENTATION_AUDIT.md). **D0 не запускает suites и не назначает им новые категории.**

Q0 navigation (2026-10-03): [accepted Test Authority Map](TEST_MATRIX.md), Q0-TEST-MATRIX-ACCEPTED-1.2, human checkpoint B bound to draft SHA256 `ef994313228752bac7bb93b448e178e9ea9b45ff8483f9ef39856b77eea41ea8`. Categories: 41 ACTIVE_CONTRACT /125 REGRESSION_GUARD /16 LEGACY_CONTRACT /12 OBSERVATIONAL /10 HISTORICAL; non-check artifacts are N/A, not a sixth category. C10 numeric requirements and C12 stale oracle remain OPEN. Existing gates and runtime INCOMPLETE are retained; no Q1/Q2/R0. Task lifecycle/reports: [root plan slot](../implementation_plan.md).

Q1 navigation (2026-10-03, COMPLETE): внешний [bounded verification harness](../tools/verify/README.md) запускает существующие entry points с timeout, process-tree kill, raw stdout/stderr и версионированным JSON; результат строго PASS / FAIL / INCOMPLETE (ненулевой exit сам по себе не FAIL, exit 0 сам по себе не PASS; warning не fatal глобально). Harness не меняет tests, thresholds, gates и TEST_MATRIX; его pilot-прогоны не являются Q2 baseline и не заменяют runtime acceptance. Q1 получил fresh VERIFY PASS и fresh independent REVIEW PASS ([completed record](plans/completed/Q1.md)); он подтверждает механизм верификации, а не whole-game runtime acceptance, которое остаётся INCOMPLETE (известный текущий failure pilot: `route_branch_integration`; ObjectDB leak непостоянен и не имеет найденной причины; C10/C12 OPEN). Q2A: frozen campaign captured (29 invocations / 188 attempts; 127 PASS / 39 FAIL / 0 INCOMPLETE in 166 baseline attempts), Q2A COMPLETE — frozen baseline captured and accepted after fresh A4 VERIFY PASS (V1–V15) and independent R2 PASS; R1 REJECT retained, R1-F1 corrected by A4. R1 NB1–NB5 and R2-NB1 deferred; R2-NB1 is tooling hardening with no effect on frozen data. [Durable baseline](baselines/Q2A/README.md); [completed Q2A record](plans/completed/Q2A.md). Runtime acceptance INCOMPLETE, C10/C12 OPEN; Q2B NOT STARTED; R0 NOT STARTED and BLOCKED until Q2B completion.

## 1. Product authority и test integrity

Blueprint/Master определяют целевую игру и архитектуру; assertions защищают своё согласованное требование/реализованную систему. Старый DAG test не вправе заставлять будущий RegionRouteGraph отказаться от loops. Это не разрешение менять тест либо игнорировать падение текущего RoadGraph: conflict сначала записывается с requirement/owner/evidence, затем конкретная reclassification/mutation согласуется человеком.

Текущие tests, assertions, thresholds, coverage и mandatory generation gates неизменны. [Frozen test-integrity](../.antigravity/rules/test-integrity.md) не изменён байт-в-байт. Его универсальная test-as-product-source формулировка отмечена D0-C10: целевая authority установлена уже сейчас, полный governance rewrite — D1, suite authority map — Q0. Нельзя считать старые тесты автоматически retired только из-за этой стратегии.

## 2. Категории Master — определения, не выполненная классификация

| Категория | Смысл | Change/acceptance boundary |
|---|---|---|
| ACTIVE_CONTRACT | Текущая спецификация конкретного контракта | Падение блокирует; assertion mutation только с human approval |
| REGRESSION_GUARD | Защита работающей системы от случайной поломки | Падение блокирует, если система входит в scope или могла быть затронута |
| LEGACY_CONTRACT | Проверяет архитектуру, сознательно заменяемую новым approved дизайном | Не переписывать молча; конфликт → evidence + approval reclassification, не возврат target к старому invariant |
| OBSERVATIONAL | Измеряет performance/coverage/monotony/statistics | Нет PASS/FAIL по цифре без согласованного budget |
| HISTORICAL | Сохранённая проверка sprint history | Не входит автоматически в новый acceptance; category требует Q0 decision, а не rename файла |

Q0 создал accepted [TEST_MATRIX](TEST_MATRIX.md) с name/owner/category/E-level/required-for/limitations/status; checkpoint B принимает authority, не runtime PASS. Legacy [coverage/replay map](TEST_COVERAGE_AND_REPLAY.md) — 59-file snapshot WORLD-00B, не новая TEST_MATRIX. D0 не меняет его распределение suites/частоту и не превращает предложения в approval.

## 3. Evidence ladder

| Уровень | Доказательство | Ограничение |
|---|---|---|
| E0 Parse | Engine parse/start без parse errors | Не domain/world correctness |
| E1 Pure Domain | Real math/data contract, где возможно без scene tree | Не integration/render/ride |
| E2 Integration | Соседние реальные production системы | Prepared mesh не live collider |
| E3 Runtime | Main или production-equivalent scene реально содержит систему | Teleport не Input-driven ride |
| E4 Physics | Реальный велосипед/registered collision взаимодействуют | Проверенные seed/дистанция/ветки, не весь мир |
| E5 Vulkan Visual | Настоящий renderer, saved/read PNG + context | Headless/имя файла не substitute |
| E6 Soak/Performance | Продолжительность, frame timings, memory/lifecycle | Average FPS не доказывает отсутствие hitches |
| E7 Human Ride | Человек едет по заявленному scope без debug UI | AI не объявляет E7 PASS самостоятельно |

Уровни обозначают разные требования к evidence; более высокий label не поглощает непроверенные lower contracts. Выбор required levels зависит от task; недостающее обязательное evidence означает INCOMPLETE, не «похоже работает».

## 4. Честный результат

Q1 bounded launcher (реализован, см. Q1 navigation) учитывает revision/dirty/source digest, effective seed и derived identities, choices, expected/actual coverage, фактические assertions, completion marker, timeout, errors/warnings/leaks и result. PASS только при полной declared coverage/completion и отсутствии unexpected errors/leaks. Exit 0 и expected budget master не measured assertion count.

Expected negative fixture проверяет точный failure/reason через реальную логику; произвольный crash не доказывает чувствительность. Нельзя добавлять production hooks для подмены поведения, skips/suppression или fixtures, зеркально повторяющие implementation. Input/physics replay не выводится из geometry checkpoints.

В отчёте отдельно указывать PASS/FAIL/INCOMPLETE и известные environment limitations, без объявления «чистый PASS» по одному subprocess status. Human complaints не отменяются численным PASS: выявить blind spot и проверить независимо.

## 5. Existing evidence и будущие фазы

- [Legacy test commands/results](../TEST_PLAN.md), [sprint reports](history/README.md) сохраняют свои даты/revisions/limitations. Старые 125 expected checks, 70% rider coverage и 100% claims не сертифицируют новый мир.
- D1: согласованные root/scoped instructions/skills/protocol; Q0: authority map; Q1: bounded harness; Q2: frozen runtime baseline и отдельная ObjectDB investigation. Все — отдельные планы.
- Code/geometry changes потом требуют соответствующих targeted/negative/integration/determinism checks; generation gates AGENTS остаются действующими в своей области до явного approval изменения.
- Collision/ride tasks требуют real physics, visual world tasks — настоящий Vulkan capture, product slice — E7. Новая surface не «принимается» контрольной регрессией старой main.

## 6. Что проверено в D0

D0 проверяет только links/anchors, authority consistency, archival preservation, whitelist и hashes. Godot/E0–E7: NOT_RUN / NOT_APPLICABLE к docs-only diff; это не новый exemption для feature/generation задач. Старый runtime INCOMPLETE и known failures сохраняются. Test files/semantics/categories unchanged.
