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
- Code/geometry changes потом требуют соответствующих targeted/negative/integration/determinism checks; generation gates AGENTS действуют в своей области, applicability — по §7 (D2), дальнейшие изменения только через явный approval.
- Collision/ride tasks требуют real physics, visual world tasks — настоящий Vulkan capture, product slice — E7. Новая surface не «принимается» контрольной регрессией старой main.

## 6. Что проверено в D0

D0 проверяет только links/anchors, authority consistency, archival preservation, whitelist и hashes. Godot/E0–E7: NOT_RUN / NOT_APPLICABLE к docs-only diff; это не новый exemption для feature/generation задач. Старый runtime INCOMPLETE и known failures сохраняются. Test files/semantics/categories unchanged.

## 7. Verification levels L0–L3 and impact selection (D2)

Introduced by D2 under the Game Director's approval with conditions C1–C7 (2026-10-10); implementation additions are disclosed in the [completed record](plans/completed/D2.md). This section decides **when and how often** checks run. It changes no test, assertion, threshold, Q0 category, TEST_MATRIX row, Q1 suite, frozen test-integrity rule, E-level definition or product requirement. It applies to plans approved after the D2 merge; an already approved plan adopts it only through its own approved amendment.

| Level | When | Content |
|---|---|---|
| **L0** developer feedback | continuously during implementation | E0 parse of changed scripts, changed-component tests, directly relevant regression rows and negatives; targeted cases and limited regression subsets; source-bound fixtures allowed |
| **L1** milestone | end of each plan milestone | representative **live** real-integration cases (typically 1–3 plus a boundary), negatives of touched contracts, concise visual evidence only when the milestone question is visual |
| **L2** phase acceptance | once, on the exact final candidate | one coherent campaign: impact-selected suites, declared holdout, mutants for high-risk logic, required determinism, visual/physics/performance evidence, human review package; then independent VERIFY and fresh REVIEW |
| **L3** integration checkpoint | after R8, R13, R18 (vertical slice), R19 and when the Director schedules one | own plan: meaningful cross-system campaign — G gates, region suites, Q2A-comparable runtime subset, physics, performance/soak, lifecycle/ObjectDB, Vulkan, E7 human ride |

L3 never absorbs an L2 obligation of a touched contract and never replaces a phase's independent VERIFY/REVIEW. An L3 failure opens an attributable issue (BLOCKER or DEBT, owner phase named in the L3 report) and blocks dependent work when genuinely critical; it does not automatically invalidate a completed phase's historical acceptance.

### 7.1 Selection by dependency impact

Impact = transitive closure of the changed paths. **Reference audit:** for each changed path search its `class_name`, `res://` and `uid://` references and `preload`/`load` strings in `*.gd`, `*.tscn`, `*.tres`, `*.gdshader`, `project.godot` (including autoloads) and data files read at runtime, transitively from the main scene and from every relevant check entry point (G entry scripts as listed in `tools/verify/suites.json`); record command and result. An unresolvable computed/concatenated load path or any other inconclusive result counts as reaching the closure. VERIFY re-runs the audit.

| Change class | L0/L1 | L2 adds | G gates |
|---|---|---|---|
| Markdown only (no `.gd/.tscn/.tres/.gdshader/project.godot/tools/**`) | links, scope, hashes | no engine | no |
| New pure-domain or isolated-preview code with zero references from the legacy runtime closure | parse, new tests, negatives | new suite (twice where determinism is declared), declared battery/holdout, mutants, Vulkan if visual/world | no; L3 |
| Edit of an existing shared domain file | + consumers' fast rows | consumer suites whose behaviour the edit can change, by call-graph and behavioural-impact analysis; a suite is skipped only with a non-impact proof (§7.2); twice only if its determinism/signature contract changed | only if the closure reaches the runtime |
| Legacy runtime generation closure (main scene, WorldManager, streaming, road/terrain/foliage generation, their scenes/resources/shaders/settings, G entry points) | + affected legacy suites (TEST_MATRIX triggers) | **G gates** + affected suites | **yes** |
| Player, physics, collision, camera | separate player plan | E4 real physics + player regression | yes |
| New computationally expensive system | — | isolated performance sanity check (§7.4) | per closure |
| Hot path, threading, streaming, caching, memory ownership or a performance claim | — | E6 protocol, isolated | per closure |
| Q1/baseline tooling | `selftest`, probes | `check-manifest`, probes | no |

### 7.2 Evidence reuse

Evidence from run R on source S counts for candidate C only if (a) every file in the check's closure is byte-identical between S and C, the S→C diff is unreachable from the check by the §7.1 audit, or a non-impact proof (below) holds; (b) engine binary/version, arguments, seeds and configuration match (Vulkan/performance also driver and GPU); (c) R completed with raw logs retained and its verdict is carried unchanged — a reused FAIL stays FAIL; (d) the report labels it `REUSED <run id> <closure proof>`. A **closure proof** is one of: byte identity, audit unreachability or a non-impact proof (below). Evidence of G gates, Vulkan captures and real-physics checks is reused only by byte identity or audit unreachability, never by a non-impact proof alone. Performance and memory/lifecycle (E6, ObjectDB/leak, create/release) evidence is reused only with byte-identical relevant dependencies or a proven unreachable change, under equivalent execution conditions (machine, engine, driver/GPU, build, workload, concurrency); historical benchmark results are never presented as fresh measurements of a changed workload. Reuse never upgrades an E-level, never certifies a check that never ran and never certifies an altered algorithm with stale results. An algorithm is **altered** for a check when changed production code executes on that check's declared inputs and is not shown output-identical by a non-impact proof.

**Non-impact proof** (the defensible proof required by D2-C6; recorded per check): (1) the changed symbols/hunks; (2) the call path from the check's entry point to each changed symbol, with reference-audit command and result; (3) for every reached changed symbol, why outputs for the check's declared inputs are identical (e.g. the executed function bodies are byte-identical and only unreferenced additions changed); (4) a cheap equality probe where one exists (e.g. unchanged existing seed preimages/signatures, or a fast suite row compared with stored output). Any gap, assumption or doubt is uncertain impact (§7.3) and the check runs. VERIFY audits every non-impact proof as a critical result.

### 7.3 Escalation

A local failure triggers focused diagnosis and its relevant dependent checks, not the whole campaign. Verification broadens immediately for: a changed shared contract, schema, signature or existing seed purpose; an unexplained cross-system failure; nondeterminism; uncertain impact; a demonstrated critical defect; an engine/driver change (no Vulkan/performance reuse). A holdout failure is fixed at its cause and the exposing case becomes a disclosed regression row. Known failures stay visible with their classification. No budget overrides these triggers.

### 7.4 Campaign hygiene

- **Holdout:** not used for tuning. L2 requires complete declared holdout coverage on the exact final candidate whenever changed algorithms — the phase's own or shared ones — can affect those cases; earlier results count only under §7.2. No full rerun after every local edit during implementation.
- **Fixtures:** for L0, and L1 when the upstream closure is unchanged, a serialized real-region upstream snapshot is allowed if it records the upstream closure digest, seed, region and configuration and is discarded on any upstream change. Optional and whitelisted per plan; L2 builds the declared real cases live.
- **Visual:** about 12 human-review images (maps, profiles, Vulkan) is the recommended compact package, not a ceiling. Provide enough representative actual Vulkan and diagnostic evidence to answer the named product questions; extra captures investigate concrete defects; avoid redundant views.
- **Performance:** a new computationally expensive system gets an isolated L2 sanity check (one timed run per representative case and one create/release object-count check). Repeated benchmarks, soak and detailed profiling follow the §7.1 performance trigger, risk or L3.
- **Concurrency:** at most 4 concurrent Godot processes, at most 1 Vulkan; timings only from isolated runs; record concurrency.
- **L3 launch sets:** deduplicate overlapping Q1 sets so no G gate runs twice for the same identity.
- **Documents:** phase plan target ≤ 15 KB, small fix ≤ 3 KB. Completed records keep identities, verdicts, findings, DEBT, the ledger and a short summary of each VERIFY/REVIEW report; full reports are kept permanently in a durable evidence root (never a temporary directory) and cited by SHA-256, or embedded in the record.
- **Docs-only closeout:** edits that only transcribe already-verified results (identities, verdicts, findings, ledger, navigation, status established by the reports) into the completed record, root plan slot, `docs/CURRENT_PROJECT_STATE.md` or status text of `TEST_PLAN.md`/`ARCHITECTURE.md`, with the verified code manifest unchanged, need link, scope and hash checks only. A new claim, a changed known-failure classification or C10/C12 status, or any edit to governance or authority documents (AGENTS, skills, PLANS, this strategy, TEST_MATRIX, test-integrity, Blueprint, Master, target architecture, migration matrix) needs verification of its impact set.

### 7.5 Independence

VERIFY audits identities, scope and the authentic stored raw evidence (harness run records or raw logs bound to source identity), re-runs reference audits, audits every non-impact proof, and independently challenges the relevant critical results; for engine tasks it re-executes at least E0 and the suites owning the phase's main new or changed contracts on the final candidate plus any check whose evidence is missing, inconsistent or doubtful. REVIEW focuses on architecture, risks and evidence integrity and does not repeat the campaign; at most one focused probe settles a specific doubtful claim (read-only inspection such as hashes, grep or diff is not a probe), otherwise the question returns to the verifier. After fixes, fresh VERIFY/REVIEW cover the changed diff's impact set.

### 7.6 Budget and time ledger

| Task class | L1 per milestone | L2 campaign (engine wall) | VERIFY | REVIEW |
|---|---|---|---|---|
| Docs/governance | — | ≤ 0.5 h, no engine | ≤ 1 h | ≤ 1 h |
| Pure-domain R-phase | ≤ 0.5 h | ≤ 3 h | ≤ 1.5 h | ≤ 1 h |
| Runtime/physics integration (R8+) | ≤ 1 h | ≤ 5 h including G | ≤ 2 h | ≤ 1.5 h |
| L3 checkpoint | own plan and budget | | | |

Budgets are targets: an overrun is recorded with its cause, never removes a required check and never changes a verdict; a critical failure stays FAIL/INCOMPLETE. Two consecutive overruns lead to a process proposal to the Director.

Each execution record keeps one ledger table (±0.25 h) with rows Implementation, L0, L1, L2, VERIFY, REVIEW (Planning and Closeout shown separately) and two columns: elapsed wall-clock hours and aggregate agent/process hours (they differ when work overlaps). Verification overhead = (L0 + L1 + L2 + VERIFY + REVIEW) / (Implementation + those), reported for both columns. Target ≤ 20 % rolling over three phases; no tracking tool.
