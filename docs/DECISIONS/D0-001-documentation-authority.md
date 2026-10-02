# D0-001 — Documentation authority reset

STATUS: ACCEPTED

Дата: 02.10.2026. Scope: только Documentation Authority Reset. Sources: [Blueprint](../TARGET_GAME_BLUEPRINT.md), [Master Phase D0](../MASTER_IMPLEMENTATION_PLAN.md), [approved D0 ExecPlan](../plans/completed/D0.md). Прямое разрешение пользователя: «приступай к реализации по implementation плану … Сделай коммит на Git и отчёт по реализации».

## Context и decision

Старые README/roadmaps/handoff/architecture/test docs смешивали implemented road-first, различные следующие tasks и target. Новые первоисточники задают region-first place/exploration/network; existing code — migration context.

Blueprint владеет продуктом, Master — стратегией и фазами. Derived target/migration/test strategy не отменяют их. AGENTS/approved single task plan владеют процессом и scope. ARCHITECTURE/current state/code — as-is; legacy documents и reports — история/evidence. [Navigator](../README.md) — единый маршрут чтения, не новый roadmap.

Target authority конфликтов решена в пользу Blueprint/Master: DAG/road-first terrain/road-driven biome/per-chunk topology/Zero-Post не являются вечными product constraints. Stable physics/camera/API, determinism, integrity и безопасная migration остаются защищены. Старые suites/thresholds не меняются и не становятся автоматически retired.

## Consequences и supersedes

Superseded normative roles: WORLD_GENERATION_GLOBAL_PLAN, DEVELOPMENT_ROADMAP, ROADMAP, BACKLOG, ROAD_GENERATION как world spec, TEST_PLAN как стратегия, WORLD-00B coverage как current map. MTB handoff/аудиты/сводка/sprint reports historical. Bodies/evidence сохранены; source/hash map в [audit](../DOCUMENTATION_AUDIT.md) и [history](../history/README.md).

Root plan содержит один task; old mixed journal archived; завершённый D0 сохранён отдельно. Никаких production/test GDScript/scenes/resources изменений, Q/R/D1 implementation или runtime PASS в D0 нет. User отдельно разрешил один local docs commit; push/merge не поручены.

## Deferred work

D1 переписывает governance/scoped rules/skills по отдельному plan. Q0 назначает test authority categories с human approval; Q1 harness; Q2 baseline и ObjectDB investigation. Test-integrity frozen file противоречит новой hierarchy формулировкой, но не получает product veto. 18/19 м, fallback, landing/valley/route/performance findings остаются открытыми. Следующая фаза не начинается автоматически.

## Verification и rollback

[Completed D0](../plans/completed/D0.md) фиксирует links/anchors, preservation, whitelist/hash checks; raw journal exact SHA; primary/frozen files unchanged. Rollback только D0 docs paths, без `reset --hard`/массового clean/отката чужих изменений. Этот decision не аннулирует исторические runtime findings.
