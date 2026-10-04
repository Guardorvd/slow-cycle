# Slow Cycle — documentation authority and navigation

STATUS: CURRENT

Scope: навигация после D0/D1 и Q0 authority approval. Решение: [D0-001](DECISIONS/D0-001-documentation-authority.md). Этот индекс не является самостоятельным roadmap.

## Authority

Текущие явные решения пользователя определяют scope и approval. [Target Blueprint](TARGET_GAME_BLUEPRINT.md) определяет продукт и region-first цель; [Master Plan](MASTER_IMPLEMENTATION_PLAN.md) определяет стратегию и порядок перехода. Производные TARGET_ARCHITECTURE, LEGACY_MIGRATION_MATRIX и TEST_STRATEGY не вправе отменять их. Рабочие правила/ExecPlan определяют разрешённое действие, as-is документы и код — факты и миграционные риски, история — датированное свидетельство.

| Вопрос | Источник | Полномочие |
|---|---|---|
| Какую игру строим? | [TARGET_GAME_BLUEPRINT](TARGET_GAME_BLUEPRINT.md) | Product North Star, freedom, region-first, human acceptance |
| В каком порядке переходим? | [MASTER_IMPLEMENTATION_PLAN](MASTER_IMPLEMENTATION_PLAN.md) | D0 → D1 → Q0 → Q1 → Q2 → R0…R21 |
| Какие target владельцы и границы? | [TARGET_ARCHITECTURE](TARGET_ARCHITECTURE.md) | Производная будущая архитектура |
| Что сохраняем/адаптируем/заменяем? | [LEGACY_MIGRATION_MATRIX](LEGACY_MIGRATION_MATRIX.md) | Future migration decisions и parity gates |
| Какие доказательства нужны? | [TEST_STRATEGY](TEST_STRATEGY.md) | Категории/уровни evidence; без reclassification suites в D0 |
| Что реально проверяет каждый test/tool? | [TEST_MATRIX](TEST_MATRIX.md) | Accepted Q0 authority/capability map; C10/C12 OPEN, runtime NOT_RUN |
| Чем bounded-запускать существующие tests и получать PASS/FAIL/INCOMPLETE? | [tools/verify](../tools/verify/README.md) | Q1 harness (COMPLETE: VERIFY PASS + independent REVIEW PASS); pilot-результаты не являются baseline, acceptance или Q2 |
| Что фактически работает сейчас? | [CURRENT_PROJECT_STATE](CURRENT_PROJECT_STATE.md), [ARCHITECTURE](../ARCHITECTURE.md) | Датированное состояние/as-is runtime |
| Что разрешено выполнять? | [AGENTS](../AGENTS.md), [active-plan slot](../implementation_plan.md) | Ограничения и явное approval одного task |
| Что стало историей и почему? | [DOCUMENTATION_AUDIT](DOCUMENTATION_AUDIT.md), [history](history/README.md) | Статусы/конфликты/source traceability |
| Как запустить текущую игру? | [README](../README.md) | Существующие инструкции и controls |

## Порядок чтения и scope

Новый task: Blueprint → Master → AGENTS → current state → target/matrix/strategy по области → один утверждённый ExecPlan. Код читать для safe migration, не для выбора иной цели.

D0 завершён; [согласованный план и документационный отчёт](plans/completed/D0.md) сохранены. D1 завершён: [completed record](plans/completed/D1.md). Q0 [authority map](TEST_MATRIX.md) принята digest-bound checkpoint B; Q0 COMPLETE после documentary VERIFY PASS и fresh independent REVIEW PASS; [completed Q0](plans/completed/Q0.md), [root NO_ACTIVE_PLAN](../implementation_plan.md). Это не runtime acceptance: C10/C12 OPEN, gates сохранены. Q1 Bounded Verification Harness COMPLETE: fresh VERIFY PASS и fresh independent REVIEW PASS (R1 REJECT исправлен, R2 PASS); [completed record](plans/completed/Q1.md). Q1 подтверждает механизм верификации, а не whole-game runtime acceptance: runtime/game acceptance остаётся INCOMPLETE; `route_branch_integration` — известный текущий failure pilot Q1 (failures=9 routes=4); ObjectDB leak был непостоянным в evidence Q1; причина диагностирована в Q2B; C10 и C12 OPEN. Q2A: frozen campaign captured (29 invocations / 188 attempts; 127 PASS / 39 FAIL / 0 INCOMPLETE in 166 baseline attempts), Q2A COMPLETE — frozen baseline captured and accepted after fresh A4 VERIFY PASS (V1–V15) and independent R2 PASS; R1 REJECT retained, R1-F1 corrected by A4. R1 NB1–NB5 and R2-NB1 deferred; R2-NB1 is tooling hardening with no effect on frozen data. [Durable baseline](baselines/Q2A/README.md); [completed Q2A record](plans/completed/Q2A.md). Q2B COMPLETE — ObjectDB / Lifecycle Root-Cause Investigation: diagnosis A = PROVEN (BikeAudioManager causally responsible for the measured six-object warning signature), B = PROVEN (3 × AudioStreamWAV + 3 × AudioStreamPlaybackWAV, Wind/Gravel/Skid), C = STRONGLY_SUPPORTED (process-exit / delayed audio-resource teardown, not accumulating world-streaming retention on the exercised path), D = NOT_PROVEN (exact Godot AudioServer mechanism); bounded 250 ms test-teardown settle in two test entry points, Stage F 120/120 (LEGACY 11/30 vs FIXED 0/30 target warnings), production audio/game/world unchanged; Stage D VERIFY PASS (original FAIL retained, A1) + independent R1 PASS, Stage F VERIFY PASS + independent R2 PASS, human G3 accepted. [Durable investigation](investigations/Q2B/README.md); [completed Q2B record](plans/completed/Q2B.md). Route/macro/soak остаются документированным residual. Runtime acceptance INCOMPLETE, C10/C12 OPEN; R0 NOT STARTED; R0 не начинать, пока Q2B не merged и не verified на master. Q2B/R0 требуют отдельных планов/approval.

## История и evidence

[Каталог](history/README.md) перечисляет retained-in-place roadmaps/backlog/geometry/tests/audits и [sprint reports](sprints/). [История планов](plans/history/README.md) сохраняет прежний смешанный журнал целиком; [completed D0](plans/completed/D0.md) относится только к документации.

Исторические next steps не действуют; прежний PASS не заменяет сегодняшние runtime/physics/Vulkan/human проверки. Governance conflict frozen test-integrity и технические mismatches записаны в [audit](DOCUMENTATION_AUDIT.md) и [strategy](TEST_STRATEGY.md).
