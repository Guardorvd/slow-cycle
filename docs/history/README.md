# Slow Cycle — historical documentation catalogue

STATUS: CURRENT

Scope: каталог истории, не текущая стратегия. [Current navigator](../README.md), [Blueprint](../TARGET_GAME_BLUEPRINT.md), [Master](../MASTER_IMPLEMENTATION_PLAN.md), [audit](../DOCUMENTATION_AUDIT.md).

Source revision для pre-D0: `ed7d1322da1a5700a8c64425708e1c813213c7f6`. Original dates внутри документов неизменны. Historic PASS/next tasks относятся к своим revisions и coverage; replacement product/strategy — Blueprint/Master, as-is — ARCHITECTURE/current state, evidence strategy — TEST_STRATEGY.

## Содержательно заменённые документы

| Original path | Snapshot (HISTORICAL) | Original SHA256 |
|---|---|---|
| `README.md` | [README_PRE_D0.md](README_PRE_D0.md) | `EA4128E933D3D428CD296874E9A1DCC587CEEE6B1D3590073A8C2DB128A4C976` |
| `VISION.md` | [VISION_PRE_D0.md](VISION_PRE_D0.md) | `9B9FAB37BA6AB6D151F9041F2E3EE0569083E505BECB6D58776AACEE8E6E3C0A` |
| `ARCHITECTURE.md` | [ARCHITECTURE_PRE_D0.md](ARCHITECTURE_PRE_D0.md) | `91F242EFEB2FB55ADFAC44EA426506637F69F120ADF83B70D1B8540C3831957A` |
| `docs/CURRENT_PROJECT_STATE.md` | [CURRENT_PROJECT_STATE_PRE_D0.md](CURRENT_PROJECT_STATE_PRE_D0.md) | `C225A04C6280E0C218CC77520290297C050257B3206058E9975B82607F242216` |

Snapshots сохраняют полное прежнее содержание: изменения только enclosing historical metadata и relative link corrections. Исторические line numbers сохранены с original revision. Полные исходные bytes доступны через Git по source path и `ed7d132`. Current replacement остаётся по original path.

## Сохранены на прежних путях

| Документ | Статус | Provenance / scope |
|---|---|---|
| [docs/WORLD_GENERATION_GLOBAL_PLAN.md](../WORLD_GENERATION_GLOBAL_PLAN.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [DEVELOPMENT_ROADMAP.md](../../DEVELOPMENT_ROADMAP.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [ROADMAP.md](../../ROADMAP.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [BACKLOG.md](../../BACKLOG.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [ROAD_GENERATION.md](../../ROAD_GENERATION.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [TEST_PLAN.md](../../TEST_PLAN.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/TEST_COVERAGE_AND_REPLAY.md](../TEST_COVERAGE_AND_REPLAY.md) | SUPERSEDED | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [MTB_WORLD_GENERATION_HANDOFF.md](../../MTB_WORLD_GENERATION_HANDOFF.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [CURRENT_STATE_AUDIT.md](../../CURRENT_STATE_AUDIT.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [TECHNICAL_AUDIT_AND_ROADMAP.md](../../TECHNICAL_AUDIT_AND_ROADMAP.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [branch_generation_review.md](../../branch_generation_review.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/TODAY_CHANGES_2026_10_01.md](../TODAY_CHANGES_2026_10_01.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/sprint_4m_validation_report.md](../sprints/sprint_4m_validation_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/sprint_6_v4_completion_report.md](../sprints/sprint_6_v4_completion_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/stage_b_validation_report.md](../sprints/stage_b_validation_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/world_00_c01_c02_verification_report.md](../sprints/world_00_c01_c02_verification_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/world_00_c03_c04_verification_report.md](../sprints/world_00_c03_c04_verification_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/world_00_logs_verification_report.md](../sprints/world_00_logs_verification_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/world_00a_documentation_report.md](../sprints/world_00a_documentation_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |
| [docs/sprints/world_00b_verification_report.md](../sprints/world_00b_verification_report.md) | HISTORICAL | Original path retained; source `ed7d132`; original body/dated evidence preserved |

## История ExecPlans и полезная техника

[Mixed journal index](../plans/history/README.md) сохраняет old implementation_plan, task IDs, duplicates/incomplete proposals, approvals и outcomes. [Completed D0](../plans/completed/D0.md) — отдельный документационный task; approval будущего task не наследуется из истории.

Contracts/geometry math — retained ROAD_GENERATION и ARCHITECTURE snapshot; test commands/results/coverage — retained TEST_PLAN, coverage/replay и reports; defect IDs/measurements — audits/backlog; historical player settings/calibration — snapshot/reports. Ни одна из этих технических деталей не удалена как «неудобная».

External evidence paths к Codex outputs, Antigravity brain, user:// logs, PNG/ZIP/JSON сохранены с dates/run IDs. Файлы вне репозитория не копировались/не изменялись, их текущая доступность не подтверждена. Original report verdict — исторический claim, не новый docs/runtime PASS.
