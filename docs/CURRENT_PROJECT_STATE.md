# Slow Cycle — current project state after D1 / Q0 authority approval

STATUS: CURRENT

Дата governance: 03.10.2026. Scope: D0 documentation reset + завершённая локальная D1 governance implementation; runtime/source baseline `ed7d1322da1a5700a8c64425708e1c813213c7f6`, никаких игровых изменений в D0. Runtime evidence ниже датировано 01.10 или ранее и в D0 заново не запускалось. Точную текущую docs revision/branch определять через `git log -1`/`git status`; это не новый runtime baseline Q2.

## 1. Authority и ближайшая работа

[Blueprint](TARGET_GAME_BLUEPRINT.md) — продукт; [Master](MASTER_IMPLEMENTATION_PLAN.md) — стратегия/pivot и порядок фаз. [Target architecture](TARGET_ARCHITECTURE.md), [migration matrix](LEGACY_MIGRATION_MATRIX.md), [test strategy](TEST_STRATEGY.md) — производные. [AGENTS](../AGENTS.md)/[plan slot](../implementation_plan.md) регулируют разрешённое действие; [as-is architecture](../ARCHITECTURE.md) и код — факты/миграционный контекст. [Index](README.md), [audit](DOCUMENTATION_AUDIT.md), [decision](DECISIONS/D0-001-documentation-authority.md).

D0 завершён как документационная фаза; [approved ExecPlan и отчёт](plans/completed/D0.md). D1 COMPLETE: компактный root/scoped AGENTS, `.agent/PLANS.md`, ровно три repo skills, actual instruction-discovery probes, VERIFY PASS и fresh independent REVIEW PASS; [approved plan, отчёты и ограничения](plans/completed/D1.md). [Root plan slot](../implementation_plan.md) содержит статус текущей задачи или ссылку на completed record. Пользователь принял local master `83bcbfe` как базу и разрешил локальный коммит. Push/credentials/branch cleanup не выполнялись. Q0 authority map [TEST_MATRIX](TEST_MATRIX.md) принята checkpoint B для draft digest `ef994313228752bac7bb93b448e178e9ea9b45ff8483f9ef39856b77eea41ea8`; 204 категории accepted, N/A applicability не шестая категория. C10 numeric requirements и C12 stale oracle остаются OPEN; no failure waiver. Q0 COMPLETE как документационная задача после VERIFY PASS и fresh independent REVIEW PASS: [accepted plan, reports и ограничения](plans/completed/Q0.md); runtime acceptance остаётся INCOMPLETE. Q1 Bounded Verification Harness COMPLETE: fresh VERIFY PASS и fresh independent REVIEW PASS (R1 REJECT исправлен, R2 PASS); [completed record](plans/completed/Q1.md). Q1 подтверждает механизм верификации, а не whole-game runtime acceptance: runtime/game acceptance остаётся INCOMPLETE; `route_branch_integration` — известный текущий failure pilot Q1 (failures=9 routes=4); ObjectDB leak был непостоянным в evidence Q1; причина диагностирована в Q2B; C10 и C12 OPEN. Q2A: frozen campaign captured (29 invocations / 188 attempts; 127 PASS / 39 FAIL / 0 INCOMPLETE in 166 baseline attempts), Q2A COMPLETE — frozen baseline captured and accepted after fresh A4 VERIFY PASS (V1–V15) and independent R2 PASS; R1 REJECT retained, R1-F1 corrected by A4. R1 NB1–NB5 and R2-NB1 deferred; R2-NB1 is tooling hardening with no effect on frozen data. [Durable baseline](baselines/Q2A/README.md); [completed Q2A record](plans/completed/Q2A.md). Q2B COMPLETE — ObjectDB / Lifecycle Root-Cause Investigation: diagnosis A = PROVEN (BikeAudioManager causally responsible for the measured six-object warning signature), B = PROVEN (3 × AudioStreamWAV + 3 × AudioStreamPlaybackWAV, Wind/Gravel/Skid), C = STRONGLY_SUPPORTED (process-exit / delayed audio-resource teardown, not accumulating world-streaming retention on the exercised path), D = NOT_PROVEN (exact Godot AudioServer mechanism); bounded 250 ms test-teardown settle in two test entry points, Stage F 120/120 (LEGACY 11/30 vs FIXED 0/30 target warnings), production audio/game/world unchanged; Stage D VERIFY PASS (original FAIL retained, A1) + independent R1 PASS, Stage F VERIFY PASS + independent R2 PASS, human G3 accepted. [Durable investigation](investigations/Q2B/README.md); [completed Q2B record](plans/completed/Q2B.md). Route/macro/soak остаются документированным residual. Runtime acceptance INCOMPLETE, C10/C12 OPEN; R0 COMPLETE locally after FINAL VERIFY PASS, independent Review R1 PASS and human G3 closeout approval; [completed R0 record](plans/completed/R0.md). R1 — Macro Geography COMPLETE (Alpha accepted 2026-10-06) after VERIFY #3 PASS and independent REVIEW PASS; [completed R1 record](plans/completed/R1.md). R2 NOT STARTED. Harness: [tools/verify](../tools/verify/README.md); pilot Q1 — не Q2 baseline. Новая задача требует отдельного запроса, конкретного ExecPlan и approval. WORLD-01/C05 и старые B/P/sprint next steps SUPERSEDED. D1 подтверждает только governance; runtime acceptance остаётся INCOMPLETE.

## R0 local completion (2026-10-04)

**R0 COMPLETE locally** after FINAL VERIFY PASS, independent Review R1 PASS (`blocking_findings = none`) and human G3 closeout approval. [Completed record](plans/completed/R0.md) retains VERIFY #1 FAIL → A1 restoration (3 protected files / 121 unexpected paths / 7 retained UIDs) → VERIFY #2 FAIL → A2 ENVIRONMENT_CONFIRMED (Controls A/B reproduced; C INCOMPLETE) → narrow human A3 → FINAL FRESH VERIFY PASS → independent R1 PASS, all R1-NB1–NB6 and future-R1 risks.

R0 is an isolated pure-domain identity/bounds/schema foundation: six RefCounted domain scripts, one additive direct domain test and seven approved UID sidecars. RegionGenerator is the intended producer; MacroTerrainPlan remains DEFERRED_R1. No geography or runtime/WorldManager integration; production references = 0; MountainMassifField dependency = NONE. E0 PASS; E1 PASS under human A3; E2–E7 N/A for R0. Both final domain runs passed 145/145; Q1 selftests 49/49 PASS; manifest 66 suites / 209 rows PASS; H2 isolation PASS. The human-approved disposable-copy verification procedure replaced original plan §19 V7 without weakening R0 contract coverage; all seven candidate scripts loaded, with seven zero-error per-file parse checks already preserved from the first verification.

The exact `ERROR: Failed to read the root certificate store.` remains an unresolved host/environment issue. CERT_STORE_ENV_EXCEPTION_R0_VERIFY_ONLY applies solely under its recorded A3 conditions; it is not globally waived. No TLS/network/certificate/environment health is claimed. C10 OPEN; C12 OPEN; whole-game runtime acceptance INCOMPLETE. R0-only H2 applicability does not reclassify TEST_MATRIX or waive retained gates globally. Existing legacy failures remain unchanged.

**(Historical, at R0 closeout) R1 NOT STARTED.** It must not begin until the R0 completion commit exists, the branch is pushed, the remote branch is independently verified, R0 is merged to master, remote master is independently verified, and a separate R1 ExecPlan is created and approved. This local closeout performs no push or merge and does not approve R1. The [root plan slot](../implementation_plan.md) is NO_ACTIVE_PLAN.

## R1 completion (2026-10-06)

**R1 — Macro Geography COMPLETE; R1 Alpha ACCEPTED** by the human (Game Director verdict "ACCEPT R1 ALPHA → MOVE TO R2"). Approved ExecPlan v2.0 (Alpha restart: ridge-network construction) with T-1 and T-2. VERIFY #1 INCOMPLETE (missing G9 fixture, fixed) → VERIFY #2 PASS with V2-F1 (fixture fixed) → VERIFY #3 PASS; independent REVIEW PASS with no blocking findings. [Completed record](plans/completed/R1.md) holds identities, evidence, history and the deferred backlog.

Delivered: deterministic `MOUNTAIN_RIVER_VALLEY` macro geography (`slow_cycle.macro_terrain/2`) — dominant valley with narrows, floodplain basin, varying walls and terraces; one connected main range of summits and passes; summit/shoulder spurs with branches and side valleys; lower far side; upland meadow basin; bounded noise; compositional seed variation (valley form × range form × crest shape × far side × 8 symmetries). Transitional `MacroTerrainEvaluator` (point + `sample_grid`); isolated `region_preview.tscn` (shared-grid 8×8 ArrayMesh tiles, Vulkan captures). R0 contracts unchanged; R0 suite 145/145.

Evidence (disposable copies, Godot 4.7.2 mono, Vulkan Forward+): macro suite 4269/0 ×2 byte-identical; R0 145/0 ×2; Vulkan preview 867 597/0; 9 E5 captures for 184729/42/77777; Q1 retained gates seed_diversity, monotony, virtual_rider (355.9 m = Q2A), capture_visual_vulkan PASS 4/0/0; review sweep 252 000 regions, 0 invalid. No production integration: production references to the region namespace = 0. Determinism claim: same engine build/platform.

Deferred (accepted, do not reopen R1): faceted flanks, ~2 % buried passes, ~1 % basin rims, rounded far hills, same-platform determinism, per-call evaluator context cost, and review N1–N6 (far-offset interval inversion, `sample_grid` float32 bounds/cap, partial `validate()` coverage, triplicated wall geometry, spur-less far ridges, clamped G6 probes) — each with its revisit phase in the record; N1, N2 and N4 should be resolved before R2 reuses those paths. C10/C12 OPEN; whole-game runtime acceptance INCOMPLETE.

**R2 — Terrain Tile Contract NOT STARTED.** It requires its own ExecPlan and human approval. The [root plan slot](../implementation_plan.md) is NO_ACTIVE_PLAN.

## 2. Что фактически есть

| Часть | Implemented legacy scope | Ограничение |
|---|---|---|
| Player/camera/controls/audio/HUD/recovery | Существующие stable controllers и public telemetry | D0 не меняет параметры и не выполняет новый ride |
| Road | Seeded RoadGrammar/RoadLogic, RoadPathData, MountainProfile, локальные MTB events | Не region terrain-aware corridor planning |
| Fork/streaming | RoadGraph strict DAG + actual centerlines/choices; ChunkStreamer branch/chunk lifecycle | Нет loop/merge региональной сети; spatial streaming не создан |
| Terrain | MountainMassifField math + road-relative TerrainCarver/RoadChunk strip/wedge | W_FAR 38 м, нет world-covering independent terrain и FinalSurface |
| Vegetation/collision | Local MultiMesh/type/chunk; whole terrain faces collider | Нет regional ecology fields и near-only terrain patches |
| Region domain (R0–R1) | RegionIdentity, exact 4096 m RegionBounds, deterministic RegionPlan, RegionGenerator; R1 MOUNTAIN_RIVER_VALLEY macro geography, transitional MacroTerrainEvaluator, isolated region_preview | No TerrainField (R2), hydrology, biomes, routes or runtime/WorldManager integration; no cross-region continuity |
| Capture/diagnostics | C01–C02 provenance guards, LOG session observer/checkpoints, C03–C04 CW/contact checks | Geometry replay не input/physics replay; ограниченный seed/arm/point coverage |

Исходники/ownership: [ARCHITECTURE](../ARCHITECTURE.md). Future owners не реализованы только потому, что их имена появились в D0 docs.

## 3. Датированные свидетельства

Последний основной runtime commit предыдущего дня: `ce3b175c95d85664a110031161ebbc10c5486720`; отчёты исходных запусков содержат `7c33004` плюс dirty changes. После него были documentation commits, включая authority bootstrap `ed7d132`. Эти revisions нельзя выдавать за новые D0 запусковые evidence.

| Этап | Сохранённый результат | Что не доказано |
|---|---|---|
| [C01–C02](sprints/world_00_c01_c02_verification_report.md) | 27 checks, 19 PNG с effective seed/местом/camera/Image/save/reload/metadata | Beauty/whole-world terrain/physical ride |
| [WORLD-00-LOG](sprints/world_00_logs_verification_report.md) | 37 checks, три seed × 3 checkpoints/1 choice, 13 expected negative результатов | Полный deterministic input/physics replay; crash recovery |
| [C03–C04](sprints/world_00_c03_c04_verification_report.md) | 168 checks, 6 arms, 333 contacts, 21 PNG в declared scope | Цельная земля за road strips/все routes/все seed |
| [WORLD-00B](sprints/world_00b_verification_report.md) | Карта 59 tools и четыре bounded baseline/lifecycle probe | Fresh full regression/visual/human acceptance |

Сводка дня: [TODAY_CHANGES_2026_10_01](TODAY_CHANGES_2026_10_01.md). Полная передача прежнего состояния: [snapshot](history/CURRENT_PROJECT_STATE_PRE_D0.md). Evidence files по абсолютным внешним локальным путям сохраняются; их доступность в D0 не перепроверялась.

## 4. Known failures и границы доказанного

**Последняя общая чистая runtime acceptance: INCOMPLETE; D0 её не закрывает.**

- ObjectDB warning о 6 unresolved instances: диагностирован в Q2B (audio streams/playbacks Wind/Gravel/Skid, process-exit teardown; механизм AudioServer NOT_PROVEN); для двух затронутых test entry points применён bounded 250 ms settle (Stage F: LEGACY 11/30 vs FIXED 0/30). Route/macro/soak не менялись и могут предупреждать периодически. Чистый повтор не является исправлением; это не runtime acceptance.
- Route failures=9/routes=4 и fixed-seed junction/envelope failure ранее воспроизводились также на исходном HEAD; commit benchmark варьировал.
- Rider PASS покрывал 355.9/500 м по прежнему 70% порогу; это не полный route acceptance или E7.
- Valley boundary jump 4.5 м, code radius 18 м против 19 м AGENTS, широкий fatal fallback и landing +10° зарегистрированы как legacy findings. D0 их не ремонтирует и не меняет limits.
- Full streaming-order determinism, отсутствие всех holes/leaks, продолжительный FPS/memory, проезд всех alternatives и качество нового region не подтверждены D0 запуском.

Это сохранённые наблюдения/claims прошлых проверок, не freshly reproduced findings. Sources: dated reports и [audit](DOCUMENTATION_AUDIT.md); future Q2 должен зафиксировать настоящий frozen baseline и ObjectDB investigation.

## 5. Продуктовая цель и запреты

Mountain River Valley slice 20–30 минут: настоящее место, choices/change plan, спокойная/интересная езда, off-road, loop, biomes/reveal/human traces — по Blueprint и E7. Зрелый region/continuation позже. Legacy implementation не отменяет эту цель.

Worldgen не меняет bicycle/camera/controls без отдельного approved player scope. Старые tests сохраняются; suite authority/reclassification — Q0 с human approval, governance rewrite — D1. Никакое documentation acceptance не даёт зелёный runtime статус и не разрешает следующую фазу автоматически.
