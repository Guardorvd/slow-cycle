# Slow Cycle — documentation authority and navigation

STATUS: CURRENT

Scope: навигация после D0. Решение: [D0-001](DECISIONS/D0-001-documentation-authority.md). Этот индекс не является самостоятельным roadmap.

## Authority

Текущие явные решения пользователя определяют scope и approval. [Target Blueprint](TARGET_GAME_BLUEPRINT.md) определяет продукт и region-first цель; [Master Plan](MASTER_IMPLEMENTATION_PLAN.md) определяет стратегию и порядок перехода. Производные TARGET_ARCHITECTURE, LEGACY_MIGRATION_MATRIX и TEST_STRATEGY не вправе отменять их. Рабочие правила/ExecPlan определяют разрешённое действие, as-is документы и код — факты и миграционные риски, история — датированное свидетельство.

| Вопрос | Источник | Полномочие |
|---|---|---|
| Какую игру строим? | [TARGET_GAME_BLUEPRINT](TARGET_GAME_BLUEPRINT.md) | Product North Star, freedom, region-first, human acceptance |
| В каком порядке переходим? | [MASTER_IMPLEMENTATION_PLAN](MASTER_IMPLEMENTATION_PLAN.md) | D0 → D1 → Q0 → Q1 → Q2 → R0…R21 |
| Какие target владельцы и границы? | [TARGET_ARCHITECTURE](TARGET_ARCHITECTURE.md) | Производная будущая архитектура |
| Что сохраняем/адаптируем/заменяем? | [LEGACY_MIGRATION_MATRIX](LEGACY_MIGRATION_MATRIX.md) | Future migration decisions и parity gates |
| Какие доказательства нужны? | [TEST_STRATEGY](TEST_STRATEGY.md) | Категории/уровни evidence; без reclassification suites в D0 |
| Что фактически работает сейчас? | [CURRENT_PROJECT_STATE](CURRENT_PROJECT_STATE.md), [ARCHITECTURE](../ARCHITECTURE.md) | Датированное состояние/as-is runtime |
| Что разрешено выполнять? | [AGENTS](../AGENTS.md), [active-plan slot](../implementation_plan.md) | Ограничения и явное approval одного task |
| Что стало историей и почему? | [DOCUMENTATION_AUDIT](DOCUMENTATION_AUDIT.md), [history](history/README.md) | Статусы/конфликты/source traceability |
| Как запустить текущую игру? | [README](../README.md) | Существующие инструкции и controls |

## Порядок чтения и scope

Новый task: Blueprint → Master → AGENTS → current state → target/matrix/strategy по области → один утверждённый ExecPlan. Код читать для safe migration, не для выбора иной цели.

D0 завершён; [согласованный план и документационный отчёт](plans/completed/D0.md) сохранены. Активного task plan нет. Следующая допустимая работа — подготовка D1 по Master, после отдельного согласования. D1/Q/R не реализованы в D0.

## История и evidence

[Каталог](history/README.md) перечисляет retained-in-place roadmaps/backlog/geometry/tests/audits и [sprint reports](sprints/). [История планов](plans/history/README.md) сохраняет прежний смешанный журнал целиком; [completed D0](plans/completed/D0.md) относится только к документации.

Исторические next steps не действуют; прежний PASS не заменяет сегодняшние runtime/physics/Vulkan/human проверки. Governance conflict frozen test-integrity и технические mismatches записаны в [audit](DOCUMENTATION_AUDIT.md) и [strategy](TEST_STRATEGY.md).
