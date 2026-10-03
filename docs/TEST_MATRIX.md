# Slow Cycle — Q0 Test Authority Map

STATUS: CURRENT — AUTHORITY_ACCEPTED; runtime NOT_RUN
VERSION: Q0-TEST-MATRIX-ACCEPTED-1.2
DATE: 2026-10-03
BRANCH: q0-test-authority-map
AUDITED_HEAD: c452aad6148683090326b18ce86b247a27ceebbe
CATEGORY_APPROVAL: HUMAN CHECKPOINT B — 204 accepted assignments, 0 pending categories
RUNTIME_RESULT: NOT_RUN (Q0 documentary/source audit); existing game acceptance remains INCOMPLETE

## 1. Authority и граница решения

Human checkpoint B APPROVED on 2026-10-03 for **Q0-TEST-MATRIX-DRAFT-1.0**, raw-byte SHA256 `ef994313228752bac7bb93b448e178e9ea9b45ff8483f9ef39856b77eea41ea8`. All 204 authority assignments and N/A applicability records from that exact draft are accepted. Edition1.0 promoted approval/status/navigation. Edition1.1 corrects seven documentary finding groups from fresh independent review (§14): oracle descriptions, coverage, units, fixture ownership, historical scope and effective-seed prerequisites. All204 approved IDs/categories and E-capability assignments are preserved; corrected descriptions do not change tests, thresholds or requirements. Full-row text is intentionally no longer identical to the draft. Human approval binds category decisions, not incorrect factual descriptions. The final edition digest is recorded externally to avoid self-hash. Approval of the draft does not extend to later changed category content.

C01, C07 and C14 are approved with their documented limitations; C10 receives **category approval only**, with numeric requirements OPEN; C12 accepts MACRO-TERR as REGRESSION_GUARD with its stale oracle OPEN. C02–C06, C08, C09, C11 and C13 are acknowledged factual limitations. No failure waiver, threshold resolution, evidence upgrade, test repair or gate removal is granted. Existing owners remain protected; legacy DAG/zero-post/profile/pacing/layout/style expectations MUST NOT constrain the approved conflicting RegionRouteGraph/region-first target. No current runtime PASS, historical reproduction or E4/E5/E6/E7 evidence is inferred. Q1/Q2/R0 are not authorized. The approval and completion workflow are recorded in the [task plan slot](../implementation_plan.md).

Authority: [root AGENTS](../AGENTS.md), [test AGENTS](../scripts/test/AGENTS.md), [world AGENTS](../scripts/world/AGENTS.md), [player AGENTS](../scripts/player/AGENTS.md), [PLANS](../.agent/PLANS.md), [frozen test-integrity](../.antigravity/rules/test-integrity.md), [Strategy](TEST_STRATEGY.md), [Blueprint](TARGET_GAME_BLUEPRINT.md), [Master Q0](MASTER_IMPLEMENTATION_PLAN.md), [target architecture](TARGET_ARCHITECTURE.md), [legacy migration](LEGACY_MIGRATION_MATRIX.md), [as-is](CURRENT_PROJECT_STATE.md). Blueprint/Master задают target product; current tests защищают фактически проверяемый existing owner. Несогласованное изменение теста или возврат нового дизайна к старому DAG недопустимы.

## 2. Inventory methodology и completeness

1. Зафиксированы branch/HEAD/staged/unstaged/untracked. До plan v1.0 tree был clean; перед реализацией A изменён только implementation_plan.md. HEAD не менялся. Protected baseline: 210 tracked files, исключая active plan; digest `3f563fb1589ea65f88a61d425b7272281064983425f6b5d19e03b925f8a5019e`.
2. Сверены disk enumeration, tracked tree и repository-wide references. В scripts/test **70 paths: 66 .gd +3 UID + AGENTS**; иных test files в этой папке не обнаружено. Полностью прочитаны реализации **всех 66 .gd**, включая три больших generators и 2109 строк diagnostics. Regex/function lists служили навигацией, не заменяли чтение.
3. Для каждого executable прослежены entry/calls, real production vs inline formula/source-text/stub, условия failure/quit, loops/bounds, setup order/seed override, coverage/skip, печатаемые и asserted budgets. Mixed файлы разложены на meaningful subrows; фрагменты без собственного check не получают category. Все source hashes/line locations привязаны к этому snapshot (§10).
4. Production closure прослежена по вызываемым API и relevant implementations: contracts/validator/path/math, grammar/logic/profile/field, graph/FSM/site/preview/pacing/arm/streamer, prepare/commit/carver/foliage, WorldManager seed/recovery/logger, player/camera/audio/UI и scenes/resources. Это trace вызываемых путей, **не заявление полного чтения каждого большого production файла**. Hash index closure в §11 задаёт идентичность зависимостей.
5. Master вызывает только пять child runners (§7); scene fixtures реально доступны через ModeSelect. Standalone scripts запускаются командой --script; отсутствие в master не делает их orphaned. Документальные ссылки найдены на все66; это discovery evidence, не доказательство регулярного запуска. Tracked CI/shell/Python test launcher не обнаружен. UID — metadata, AGENTS — governance, не suites.
6. Прочитаны исторические Sprint4/5/6/StageB/WORLD commands/reports и 59-file coverage snapshot с addenda; 59+7 новые источники дают66. Проверены доступность report-linked external WORLD roots, implementations семи launch/transport tools, восьми artifact/scope/commit check tools и seed_baseline_probe, relevant saved summaries/raw warning/failure logs. Historical source copies/baseline archives/results не считаются новыми current suites. Их артефакты не re-certified и PNG не пересматривались в Q0.
7. Exact duplicate .gd byte hashes не обнаружены. Semantic overlaps зафиксированы в §9, без удаления. Исторические имена test_airborne_pipeline.gd/test_boundary_seams.gd из StageB не существуют в текущем tree: aliases/rename не подтверждены. Temporary seed_lifecycle_probe.gd из WORLD-00B не tracked и исходник не найден в текущем repo; report alone не executable suite.

Далее **204 check rows** (194 current source subrows +8 external historical checks +2 historical manual protocols); это количество documentary groups, **не assertions/tests passed**. **15 current non-check records**: 12 целых .gd artifacts (5 helper/generator/support +7 unchecked captures) и3 unchecked fragments. Остальные .gd —54 файло-контейнера check rows; одна категория на mixed container не навязывается. Ещё4 metadata/governance artifacts и30 external source/snapshot/launcher artifacts имеют N/A. Discovery counts не включают сотни generated JSON/events/PNG как suites.

## 3. Schema, roles, prerequisites и migration blocking

Обязательные поля row: stable ID, source/line/hash (§10/11/external index), role, actual checked production owner/path, oracle/completion, seed/workload/prerequisites, conditional E-capability, approved Authority/rationale, limitations/proxy/unknown, trigger, blocking policy, conflict, approval/runtime status. Поля setup/role/owner/completion/trigger наследуются только от **своего file context** в §7. Category/evidence не наследуются от parent/master. Line locator — начало relevant group/function, не обещание одной строки с полным oracle. Пять категорий используются только для executable/meaningful check rows.

`Authority: N/A — NON_CHECK_ARTIFACT` означает **отсутствие applicability**, не шестую category. Helper/fixture/generator/module/launcher или output fragment без independent oracle не suite. Их consumers несут category. Исполняемый capture без save/result oracle тоже может быть non-check artifact; полезность сохранённых кадров при этом не отрицается.

Roles: **runner** организует checks и завершение; **helper/support** вызывается consumers; **fixture/generator** создаёт данные/сцену; **capture** создаёт изображение (может иметь integrity oracle); **audit** измеряет/объясняет bounded observations (может отдельно проверять completion). Role и category независимы. Исторический документ/JSON — evidence artifact, не runner.

Prerequisites:
- **Domain**: project imported/resources/classes доступны, Godot совместим со snapshot (project features4.7; historical engine4.7.2 mono). Built-in assert scripts требуют enabled assertions/debug-compatible run; arbitrary release exit0 не substitutes. Exact executable/environment — future run manifest, здесь UNKNOWN/NOT_RUN.
- **Integration/runtime**: нужные real scenes/resources/shared materials, правильный tree lifecycle, registered physics space/frame waits там, где реально нужны. Assign seed до add_child недостаточно при randomize_on_start=true; CLI --seed overrides требуют actual effective identity, а не filename.
- **Physical**: реальные BicycleController/collision и actual physics frames; initial fixture pose допустим, per-step pose/progress forcing ограничивает ride claim. Input-driven ride обозначен отдельно от direct-method stepping и rays.
- **Vulkan/capture**: real display/driver=vulkan, actual renderer/GPU, writable unique output, PNG saved/read with context, просмотр кадра/metadata. Headless/имя файла/PNG print не E5. Tool guards не заменяют missing artifact/environment proof.
- **Performance**: workload, hardware/build/environment/timing method и actual budget нужны отдельно; static Godot CPU memory не process/GPU RAM; instrumentation defaults/empty coverage сохраняются как gaps.
- **Replay/log**: valid manifest, matching runtime sources/config/effective seeds/ordered bounded steps, writable roots. Runtime source digest logger исключает test tools; их hash здесь отдельно.

Scheduling/blocking (unchanged by B): действуют прежние требования, новые triggers ниже — документальные scope recommendations, не новые mandatory gates. **G** в context — уже действующий world AGENTS gate: seed diversity + monotony + real physical rider + Vulkan visual audit и parse/runtime/error/leak requirements. Ни REGRESSION/OBSERVATIONAL/HISTORICAL label, ни Q0 docs acceptance не отменяют G.

Blocking после принятия categories:
- ACTIVE_CONTRACT: failure конкретного согласованного current contract блокирует затрагивающую migration; менять oracle/threshold лишь отдельным human approval.
- REGRESSION_GUARD: блокирует, если protected working owner входит в scope/мог быть затронут. Weak oracle не permission игнорировать failure; missing real coverage делает evidence INCOMPLETE.
- LEGACY_CONTRACT: сохраняет защиту old owner/consumers. Failure текущей системы блокирует impacted change; target conflict направляется человеку для scoped parity/adapter/transition decision. Не требует навязать target старый architecture invariant. Категория **не** означает waiver/retirement.
- OBSERVATIONAL: нет нового PASS/FAIL по числу без согласованного budget. Уже asserted budgets/mandatory gates сохраняются; observation о safety или complaint требует triage и может блокировать acceptance из-за missing required evidence.
- HISTORICAL: датированная проверка не автоматический gate новой игры; отсутствие новых claims/waivers обязательно. Если current governance явно требует её, retained requirement имеет приоритет до отдельного решения. Historical defect evidence не стирается.
- N/A artifact: собственного failure gate нет; его поломка может провалить consumers. Пропуск prerequisite/completion/required evidence означает INCOMPLETE, не PASS.

Не назван персональный technical owner из отсутствующего ownership registry: Owner в context — **защищаемая production responsibility**, migration/category conflict owner — human reviewer и implementation owner данного future approved task. Назначение людей UNKNOWN; не выдумывается.

### Reproduction command и exact seed bindings

Command template для current SceneTree check containers (не запуск Q0): `<Godot-console> --headless --path <repo> --script res://scripts/test/<file.gd>`; для реального Vulkan capture/surface admission заменить headless на `--rendering-driver vulkan --windowed --resolution 1280x720`. Culling fixture создаёт свои256²targets. При diagnostics/replay/capture добавить явно выбранные writable `--diagnostics-root` / `--audit-output-root` после `--`, replay требует `--replay-manifest=<matching manifest>`. Exact executable/build/launch duration фиксируется future evidence, не guessed here. Helpers/generators/unchecked captures не предлагаются standalone suites. Matrix не создаёт launcher.

| Binding | Files / groups |
| --- | --- |
| 10101,20202,30303,40404,50505 | MASTER-SEED; ROAD-GEN; LOGIC-LIMIT; GRAMMAR battery; WIND-GEO |
| 184729,42,99999,10101,77777,12345,54321,999,31415,27182 | DIVERSITY10 |
| 184729,42,77777 | MONOTONY; FOLIAGE-CONTACT; VERGE; SURFACE-LIVE; LOG-RUNTIME; CAP-SEED default (CLI mayreduce to1) |
| 184729,42,77777,99999,12345 | TOPO-SAFE and PROP-CLEAR |
| 184729,42,7319,900001 | INTENT/PLAN/GEO-EVENT-PIPE/EVENT-SEAM; FIX-VALID airborne; RHYTHM-GEO |
| previous4 +10101,20202,30303,40404,50505,60606,70707,80808 | EVENT-CAT12 |
| 184729,42,7319,900001,10101,20202,30303,40404 | RHYTHM-DET/BUDGET8 |
| 184729,42 | ROUTE/MACRO/DYNAMIC-FORK; BIOME-WIRE. CLEAR/STYLE: requested labels only, effectiveUNKNOWN_CURRENT (C08; randomization/CLI retained) |
| 184729,42,99999 | SITE-SEED; MOUNTAIN-STATE/RESOURCE |
| 184729,42,99999,12345,77777 | BIOME-FREQ5 |
| 10101,20202,30303,40404,50505,184729,42 × main/route-left/route-right | PROFILE battery; zones use10101,20202,30303,184729,42 |
| 184729,10101,99999 requested labels only; effectiveUNKNOWN_CURRENT (C08) | SOAK3: randomization/CLI retained; not guaranteed controlled3-seed battery |
| 184729 | RIDER; CAP-VIS default (CLI override checked); FORK-APPROACH/ARM, PREVIEW realterrain; GRAPH/DIAG fixtures where seeded |
| 184729 vs99999 | MASSIFdiversity; FORK-MASK left/right |
| 741923,88123,99341,62145,19482; terminal50000+t×37 for t0..14 | WIND per-group determinant/tortuosity/ratio/straight/lateral/fork |
| 184729,987654,424242,777123 | CARVER seam/class/determinism contexts |
| 4000 / 4004 / 42 | authored LAB / GRAVEL / TRACK fixtures; no world-seed guarantee inferred |
| not controlled / runtime effectiveUNKNOWN | PROC-RIDE; branch suite, SOAK/CLEAR/STYLE unless matching actualseedmanifest; CLI may override all loop labels; unchecked oldcaptures where assignmentlate/default |
| N/A (synthetic pure data or no world generation) | graphmath/path/model, localreference/text/config diagnostics, syntheticAIRladder, invalidcontractfixtures, MENU-PAD; SESSION-SEED explicitlytests resolver withoutgeneratingworld |

Controller/fixture-only checks do not need a worldseed to prove their named local contract. Command overrides can alter seed batteries: completeness must record actual intended/visited configurations. These commands/bindings document existing entry points; new mandatory schedules are not created.


## 4. Правила пяти authority categories

ACTIVE_CONTRACT — фактический oracle вызывает real current math/data/public contract, есть requirement/protected invariant и он остаётся нужен (например finite/nonempty/contact integrity, C0/C1, deterministic identity, convex weights, braking insufficiency). Точные старые representation constants не автоматически становятся вечными target requirements.

REGRESSION_GUARD — real behavior/config текущего работающего subsystem или действующий согласованный watchdog budget; product target не объявлен этим тестом. Узкие/source-text/reference checks сохраняются с ORACLE_PATH_GAP, а их intended стабильный invariant не списывается из-за слабого теста.

LEGACY_CONTRACT — конкретная expectation прикреплена к архитектуре/representation, заменяемой approved target: strict RoadGraph DAG, old zero-post policy, monotonically descending harmonic corridor, old chunk-phase pacing/layout. Mixed stable safety checks вынесены отдельно. Старый runtime всё ещё защищён.

OBSERVATIONAL — meaningful measurement/proxy trace, который не доказывает заявленный production behavioral contract; scope/units/completion явно записаны. Не использовать label для снятия реального budget. Local-reference subrows отделены от real-method checks и спорны C07.

HISTORICAL — связь с конкретным sprint/report/run/source version и отсутствующим current acceptance wiring доказана; используется для archived external check scripts/manual protocols, а не для каждого файла со Sprint в имени. Например master и diagnostics остаются regression/contract, fixtures доступны в menu; их не списываем по возрасту.

Каждое назначение обосновано actual oracle/owner в row, decision rule и conflict entry. Все 204 assignments приняты конкретным checkpoint B; unresolved requirements/defects остаются открытыми и не скрываются accepted category.

## 5. E0–E7: capability ≠ уже полученный evidence

| E | Что допускает | Что запрещено выводить |
| --- | --- | --- |
| E0 | Engine parse/start без parse errors при фактическом run | Source reading/exit0 не recordedE0. Q0 engineNOT_RUN. |
| E1 | Real math/data production contract; pure fixture inputs допустимы | Inline formula/text check не proof production behavior; local-only отдельно. |
| E2 | Real соседние production systems и bounded collaborator fixtures | Prepared mesh/faces/layer property не live collider/bike. |
| E3 | Main/production-equivalent или явно named actual fixture scene содержит систему | Teleported state не continuous ride; authored fixture не new world. |
| E4 | Real bike/registered collision interaction; narrow rays отдельно | Manual state stepping ≠ actual motion; rays ≠ wheel ride; initialpos ≠ fullroute. |
| E5 | Real Vulkan renderer + saved/read PNG/context + visual review | Headless/driverunknown/uncheckedsave/fixturePNG не wholeworld visualacceptance. |
| E6 | Measured bounded timing/workload/memory/lifecycle with environment | No all-frame/GPU/leak/hitch guarantee from CPUavg/staticmem/scenequeue_free. |
| E7 | Named human physically rides declared slice withoutdebugUI and recordsfeedback | No AI/automation E7PASS; archived oldhuman report ≠ currentacceptance. |

Capabilities записаны множеством независимых требований; не линейный maximum и не автоматическое поглощение lower levels. `conditional` требует перечисленных prerequisites/artifacts; это не PASS. `local reference/text/config only` умышленно не upgraded в real E1 domain behavior. E0 относится к process parse evidence, не присваивается строкам автоматически. Для всех current rows actual run identity/assertions/duration/errors/warnings/leaks: **NOT_RUN / UNKNOWN_CURRENT**, old results отдельно §6. No automatic E7 row.

## 6. Historical evidence ledger (не новая baseline)

| Источник | Identity/scope и прочитанные факты | Ограничение |
| --- | --- | --- |
| [TEST_PLAN](../TEST_PLAN.md) | D0HISTORICAL wrapper, ed7d132; Sprint5 commands/current filenames;10min/12KPI protocols;125expected master budget | Не нормализует mandatory новый game; старые1500m rider/terrainmonotony claims не current source. |
| [Sprint4M](sprints/sprint_4m_validation_report.md) | 2026-09-23; wrappered7d132;121claim/64core and15human perception records | Currentmaster125/diagnostics68; leak/automaticcount claims не measured authority. |
| [Sprint6v4](sprints/sprint_6_v4_completion_report.md) | 2026-09-29; ed7d132historical wrapper; diversity/monotony/rider/19m claims | Source thresholds/seedcounts отличаются; старыйPASS ограничен старойversion. |
| [StageB](sprints/stage_b_validation_report.md) | 2026-09-27; ed7d132wrapper; event/seam/physics narratives | Missingtest_airborne_pipeline/test_boundary_seams aliases unverified; proceduralLEFTteleport не asserted liveboth. |
| [WORLD00A](sprints/world_00a_documentation_report.md) | Documentation-only audit | No engine tests; old nextstep not scope. |
| [WORLD00B](sprints/world_00b_verification_report.md) | 2026-10-01/b6a5ff4;4boundedrun reports;temporary lifecycleprobe;59files | Probe nottracked; originalseedbug claim correctedlater; not currentcapability authority. |
| [C01C02](sprints/world_00_c01_c02_verification_report.md) | 7c33004dirty;digestc748f803bade7a4a10025f49d88c933b3bce34193379af701cb3dd48b38ec474;27checks,19PNG,4exactnegative reports | Rider355.9/500, intermittentObjectDB6; cleanrepeat doesn't closecause. Artifacts available, notre-certifiedQ0. |
| [LOG](sprints/world_00_logs_verification_report.md) | 7c33004dirty;digest46d6b7de107f306720cf4a1503695dc8831dd16eeb90bd28115610df5f74d9d0;37checks/3sessions/13exactnegatives;8PNG | Geometryonly. Saved replayRIGHT summaryPASS +ObjectDB6 warning inspected; routefailures9/routes4 and fixedjunctionfail remain. |
| [C03C04](sprints/world_00_c03_c04_verification_report.md) | 7c33004dirty;digest9e1769261762282897ad8cdf8c598f8f8c7366763b8ba0b1e3c1e6a9574cf466;168checks/6arms/36chunks/333contacts/21PNG | Corrected CW/nonempty/missing-ground source. No current fullworld/physicsreplay/human ride. |
| [Coverage snapshot](TEST_COVERAGE_AND_REPLAY.md) | 59-file inventory +7 source addenda; historicalbody preserved | Old topology/missingground blindspots superseded by current sources, not copied as current. |
| [Today changes](TODAY_CHANGES_2026_10_01.md) | D0historical; stageclosurece3b175 and artifactlocations | NextWORLD/C05instructions historical; Q0 notresuming. |

Saved LOG failure excerpts remain: route-integration `failures=9 routes=4`; replay RIGHT `status=PASS checkpoints=3 choices=1` followed by `6 ObjectDB instances leaked`; fixed branch `Avg=.861ms Max=1.308ms` vs unchanged .85/1.0budgets (3failures incljunction); old fixed baseline samejunctionfailure but .664/.721timingpass. These are **dated historical observations**, not runs of Q0HEAD. Unknown current reproducibility/cause remains explicit. Massif abs_dx=85 boundaryjump4.5m and radius18/19 conflict remain source/current-state gaps, not fixed.

External root actually found: `C:/Users/Luisa/Documents/Codex/2026-10-01/slow-cycle-c-users-luisa-documents/`. Three output roots world00-c01-c02/world00-logs/world00-surface contain launchJSON/console/engine logs, manifests, sourcecopies, PNG, verificationJSON. Artifacts do not acquire suite category. Q0 read selected metadata/summaries and failure excerpts; did not rerun verifiers, rehash every historical archive or review every saved image. A historical report's runtime claim remains attributed to that report/run, not to Q0.

## 7. Current check rows и file contexts

Все строки этого раздела: Authority **ACCEPTED_BY_B**, Approval **HUMAN / exact draft digest above**, actual result **NOT_RUN**. Trigger и migration blocking наследуются из своего context и §3; current G остаётся mandatory. Несколько rows могут указывать одну функцию, если checks внутри неё защищают разные requirements. Ни parent file, ни total204 не является suite assertion counter.

### capture_audit_support.gd

Source: [capture_audit_support.gd](../scripts/test/capture_audit_support.gd) — 456 lines; SHA256 в §10.

Role: helper. Protected owner/path: consumer contract rows above.

Prerequisites/workload: loaded by scene/helper consumer; no standalone suite. Trigger: consumer affected changes; do not launch helper as suite. Completion/reporting: N/A — no independent oracle/check.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| NC-capture_audit_support · L1 | N/A — NON_CHECK_ARTIFACT | helper; capture_visual_audit/capture_seed_audit/capture_surface_culling_audit/test_capture_audit_contract/test_surface_audit_contract | 456lines; provenance/all scripts hash;55s deadlines;actual seed/pose/mesh/camera/image guards; not independently launched suite. |

### capture_screenshot_ride.gd

Source: [capture_screenshot_ride.gd](../scripts/test/capture_screenshot_ride.gd) — 62 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: Main forcedpositions0..600,seed assigned after add_child;real display forPNG;fixedoutputnames/writablepath. Trigger: historical screenshot scenario; no new mandatory gate inferred. Completion/reporting: quit0 only after six image attempts (target index advances outside nonnull-image guard) advance all targets; waits for scene/path readiness with no internal timeout; null images still advance target index; save return/reload/artifact integrity not verified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-capture_screenshot_ride · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | Main forcedpositions0..600,seed assigned after add_child; quit only after six image attempts (target index advances outside nonnull-image guard) advance targets, no internal timeout; readiness waits may remain incomplete (not reproduced Q0). No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### capture_screenshot.gd

Source: [capture_screenshot.gd](../scripts/test/capture_screenshot.gd) — 16 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: sandbox15process frames, single screenshot;real display forPNG;fixedoutputnames/writablepath. Trigger: reproduce old overview; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-capture_screenshot · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | sandbox15process frames, single screenshot. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### capture_seed_audit.gd

Source: [capture_seed_audit.gd](../scripts/test/capture_seed_audit.gd) — 69 lines; SHA256 в §10.

Role: capture/check runner. Protected owner/path: CaptureAuditSupport → Main/streamer/camera/GPU.

Prerequisites/workload: real display, Vulkan command+recorded driver; imports; writable unique --audit-output-root; effective CLI seed; 55s helper deadline. Trigger: capture/seed changes; seed battery for visible slice. Completion/reporting: AUDIT_COMPLETE status + actual frame list/save/reload/metadata; external logs + visual review still required.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CAP-SEED · L15 | OBSERVATIONAL | E3; conditional E5 | 3 seeds184729/42/77777 ×3 points (start2.5m/100m/fork) =9 requested frames; actual both committed arms/seed identities | Per-point teleport with bike physics disabled; PNG identity/completion is checked, visual quality is human review; helper rejects headless but does not alone enforce driver Vulkan; no E4 ride/E7. | C05 |

### capture_sprint3a.gd

Source: [capture_sprint3a.gd](../scripts/test/capture_sprint3a.gd) — 40 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: Main pedal/steer/brake scripted180 process frames and conditional PNG;real display forPNG;fixedoutputnames/writablepath. Trigger: reproduce Sprint3A visuals; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-capture_sprint3a · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | Main pedal/steer/brake scripted180 process frames and conditional PNG. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### capture_sprint3c.gd

Source: [capture_sprint3c.gd](../scripts/test/capture_sprint3c.gd) — 40 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: Main pedal/steer scripted240 process frames and conditional PNG;real display forPNG;fixedoutputnames/writablepath. Trigger: reproduce Sprint3C visuals; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-capture_sprint3c · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | Main pedal/steer scripted240 process frames and conditional PNG. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### capture_surface_culling_audit.gd

Source: [capture_surface_culling_audit.gd](../scripts/test/capture_surface_culling_audit.gd) — 89 lines; SHA256 в §10.

Role: capture/check runner. Protected owner/path: RoadChunk surface winding → Vulkan.

Prerequisites/workload: explicit Vulkan, fixture ordinary+synthetic wedge; 4×256²PNG; output root. Trigger: surface winding/culling/indices changes. Completion/reporting: 4 captures + top/bottom pixel oracle + status.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CAP-CULL · L22 | REGRESSION_GUARD | E2; conditional E5 | Prepared ordinary/wedge fixture, top red pixels>500, bottom=0, saved/reloaded4PNG | Synthetic prepared→committed local renderer, actual_fork=false; does not prove real paired fork visibility, materials or whole-world holes. | — |

### capture_third_person.gd

Source: [capture_third_person.gd](../scripts/test/capture_third_person.gd) — 22 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: sandbox TP simulation snapshot;real display forPNG;fixedoutputnames/writablepath. Trigger: camera incident reproduction; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-capture_third_person · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | sandbox TP simulation snapshot. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### capture_visual_audit.gd

Source: [capture_visual_audit.gd](../scripts/test/capture_visual_audit.gd) — 46 lines; SHA256 в §10.

Role: capture/check runner. Protected owner/path: CaptureAuditSupport → Main/streamer/camera/GPU.

Prerequisites/workload: real display, Vulkan command+recorded driver; imports; writable unique --audit-output-root; effective CLI seed; 55s helper deadline. Trigger: G: every world-generation visual audit. Completion/reporting: AUDIT_COMPLETE status + actual frame list/save/reload/metadata; external logs + visual review still required.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CAP-VIS · L25 | OBSERVATIONAL | E3; conditional E5 | 8 requested FP/TP/drone views; helper provenance, actual committed mesh/path/pose/camera/PNG guards | Per-point teleport with bike physics disabled; PNG identity/completion is checked, visual quality is human review; helper rejects headless but does not alone enforce driver Vulkan; no E4 ride/E7. | C05 |

### gravel_loop_generator.gd

Source: [gravel_loop_generator.gd](../scripts/test/gravel_loop_generator.gd) — 794 lines; SHA256 в §10.

Role: scene generator/fixture. Protected owner/path: consumer contract rows above.

Prerequisites/workload: loaded by scene/helper consumer; no standalone suite. Trigger: consumer affected changes; do not launch helper as suite. Completion/reporting: N/A — no independent oracle/check.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| NC-gravel_loop_generator · L1 | N/A — NON_CHECK_ARTIFACT | scene generator/fixture; gravel_training_loop.tscn; GRAVEL-*; master; mode select | 794lines;1220.43m/611samples/25chunks/11sections,seed4004;own meshes/layers/recovery/signage. |

### replay_session_diagnostic.gd

Source: [replay_session_diagnostic.gd](../scripts/test/replay_session_diagnostic.gd) — 176 lines; SHA256 в §10.

Role: runner/geometry replay. Protected owner/path: logger manifest → Main/streamer → checkpoints/FSM.

Prerequisites/workload: --replay-manifest; matching runtime source digest/config/effective seed; complete bounded≤128 steps; writable logger root; ≤55s. Trigger: logger/replay/seed/fork/checkpoint changes; reproduce incident. Completion/reporting: REPLAY_DIAGNOSTIC_SUMMARY reason/status + nonzero on invalid/incomplete.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| REPLAY · L80 | ACTIVE_CONTRACT | E2,E3 | Validate input/source/config/seed, walk by teleport, select recorded choices, compare checkpoint signatures; exact failure reasons | Bike processing disabled; no recorded Input/physics timing/contact replay. Logger digest excludes scripts/test; replay-tool hash separately in source index. Partial/corrupt inputs are INCOMPLETE. | C06 |

### riding_lab_generator.gd

Source: [riding_lab_generator.gd](../scripts/test/riding_lab_generator.gd) — 863 lines; SHA256 в §10.

Role: scene generator/fixture. Protected owner/path: consumer contract rows above.

Prerequisites/workload: loaded by scene/helper consumer; no standalone suite. Trigger: consumer affected changes; do not launch helper as suite. Completion/reporting: N/A — no independent oracle/check.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| NC-riding_lab_generator · L1 | N/A — NON_CHECK_ARTIFACT | scene generator/fixture; riding_lab_track.tscn; LAB-*/AIR-*/DYNAMIC-*/master; mode select | 863lines;420.29m/212samples/9chunks/13sections,seed4000;own meshes,bank/drop/roughsections,recovery. |

### surface_audit_support.gd

Source: [surface_audit_support.gd](../scripts/test/surface_audit_support.gd) — 82 lines; SHA256 в §10.

Role: support module. Protected owner/path: consumer contract rows above.

Prerequisites/workload: loaded by scene/helper consumer; no standalone suite. Trigger: consumer affected changes; do not launch helper as suite. Completion/reporting: N/A — no independent oracle/check.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| NC-surface_audit_support · L1 | N/A — NON_CHECK_ARTIFACT | support module; surface/topology/foliage/culling contract rows | 82lines; pure winding/contact evaluation; no SceneTree entry/oracle. |

### test_airborne_calibration_gate.gd

Source: [test_airborne_calibration_gate.gd](../scripts/test/test_airborne_calibration_gate.gd) — 145 lines; SHA256 в §10.

Role: runner/physical calibration. Protected owner/path: BicycleController on synthetic collision.

Prerequisites/workload: 6 local synthetic heights.2..1.2m, preset speeds7..9.5; 120frames each. Trigger: airborne/landing physics changes. Completion/reporting: six is_stable booleans; nonzero if any unstable.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| AIR-CAL · L64 | REGRESSION_GUARD | E3,E4 | Registered table/drop/ramp; landed with≥2 airborne frames, abs landingVy<6.5, compression<.041m | target_gap field unused: no six target gap distances asserted; 60Hz assumed airtime; no production-generated landing. | — |

### test_airborne_empirical_gate.gd

Source: [test_airborne_empirical_gate.gd](../scripts/test/test_airborne_empirical_gate.gd) — 262 lines; SHA256 в §10.

Role: runner/physical calibration. Protected owner/path: BicycleController; riding lab; synthetic drops.

Prerequisites/workload: T10,T6 +3 synthetic heights.35/.6/1.2, frame-based episodes. Trigger: airborne/landing/ground contact changes. Completion/reporting: four guarded result predicates +unconditional T6true marker; nonzero on guarded instability (old unconditional-exit claim stale).

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| AIR-EMP-T10 · L65 | REGRESSION_GUARD | E3,E4 | Actual lab T10 120-frame episode: landing after≥4airborne frames and abs landingVy<6.0 gate success | Flight distance/suspension reported, not gated; no production-generated landing or whole-world ride. | — |
| AIR-EMP-T6 · L120 | OBSERVATIONAL | E3; E4 measured lab episode, no stability gate | Actual T6 one-or-both wheel unweight frames, minVy and compression measured; result is_stable always true | Printed stable/calibration success cannot prove T6 stability. Reported air distance=unweighted_frames×1/60×7.5, not measured displacement; no failure envelope. | C02 |
| AIR-EMP-SYN · L180 | REGRESSION_GUARD | E3,E4 | 3 synthetic registered drops (.35/.6/1.2): landing after≥2airframes and abs landingVy<6.5 gate success | Flight distance/suspension measured only; no requested gap or compression-bound predicate; real collision episodes, not full Input ride. | — |

### test_branch_streaming.gd

Source: [test_branch_streaming.gd](../scripts/test/test_branch_streaming.gd) — 341 lines; SHA256 в §10.

Role: mixed runner. Protected owner/path: WorldManager resources → ChunkStreamer → RoadGraph/RoadChunk.

Prerequisites/workload: resources; Main runtime for FSM; configured seed may randomize unless CLI overrides; benchmark10 chunks after2warmup. Trigger: streamer/branch/dressing/collision changes. Completion/reporting: incremented assertion counters; final failed count; E6 timing hardware-specific.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| BRANCH-MESH · L73 | REGRESSION_GUARD | E2 | Real greybox boulder mesh nonempty and bounds .5..3m; shared resource presence | Does not prove visual readability. | — |
| BRANCH-NOPOST · L73 | LEGACY_CONTRACT | E2 | Absence marker/directional/guard post resources/nodes | Zero-post old architecture/style requirement conflicts with Blueprint human traces; applies current system until explicit scoped transition. | C01 |
| BRANCH-SEED · L100 | OBSERVATIONAL | local reference math only | Inline hash derivation repeated/stable/different children | Does not call production _stable_seed; cannot certify actual child-seed wiring. | C07 |
| BRANCH-FSM · L122 | REGRESSION_GUARD | E2,E3 | Manual LEFT/RIGHT production selection, active/dormant/retained-solid chunks, graph/centerline continuity, unloading at5000m | Bike teleport/manual state; not physical ride; world_seed assigned but randomization not disabled; requested seed not assured. | C08 |
| BRANCH-DAG · L122 | LEGACY_CONTRACT | E1,E3 | Graph remains strict DAG during branch lifecycle | Protects current RoadGraph; cannot forbid target RegionRouteGraph loops/merges. | C01 |
| BRANCH-DRESS · L228 | REGRESSION_GUARD | E2,E3 | Real boulder MultiMesh registration/custom AABB and non-physical decor/layer properties | No whole GPU culling quality; headless bounds may not prove rendering. | — |
| BRANCH-NOPOST2 · L228 | LEGACY_CONTRACT | E2,E3 | Zero marker/directional/guard dressing nodes | Same old mandate; no retirement by file age. | C01 |
| BRANCH-PERF · L288 | REGRESSION_GUARD | E6 narrow | 10 warmed prepared-chunk commit timings: max≤1ms, mean≤.85ms | Missing t_total defaults0; excludes prepare, full frame hitch/GPU; variable historic failures remain budget failures. | C09 |

### test_capture_audit_contract.gd

Source: [test_capture_audit_contract.gd](../scripts/test/test_capture_audit_contract.gd) — 128 lines; SHA256 в §10.

Role: runner/negative contract. Protected owner/path: CaptureAuditSupport provenance/guards.

Prerequisites/workload: imports; writable output; CLI negative --audit-negative options; actual scenes for end-to-end. Trigger: capture/helper/seed/provenance changes. Completion/reporting: incremented checks/failures + CAPTURE_CONTRACT_COMPLETE; exact negative reasons separately.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CAP-CONTRACT · L23 | ACTIVE_CONTRACT | E1,E2,E3 bounded | Real helper contracts reject bad target/seed/coverage/image/path and end-to-end guards; provenance/run identity; exact rejection paths | Focused checks ≠ every external negative scenario or actual Vulkan image review; per-case environment/fixture scope required. | — |

### test_diagnostics.gd

Source: [test_diagnostics.gd](../scripts/test/test_diagnostics.gd) — 2109 lines; SHA256 в §10.

Role: mixed runner / 68 numbered groups. Protected owner/path: RoadChunk/PathData; BicycleController/BikeCameraRig/BikeAudioManager; HUD/Fader.

Prerequisites/workload: headless/imports; assertions enabled; real resources/source reads; direct production-method calls plus local reference simulations; actual audio buses/scene nodes. Trigger: affected player/camera/audio/UI/path/geometry changes; master integration regression. Completion/reporting: single all_ok bool; final fixed68/68 text; missing optional node branches can skip; no actual assertion/skip counter.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| DIAG-01 · L7 | REGRESSION_GUARD | E2 | Real adjacent RoadChunk road/terrain ArrayMesh shared-edge≤.001 | Prepared/built resources, not moving-bike collision or rendered seam. | — |
| DIAG-02 · L68 | REGRESSION_GUARD | E6 narrow | 100-chunk PathData nearest-index calls with cache <60µs | No returned-index correctness oracle; hardware budget only. | C09 |
| DIAG-03 · L85 | REGRESSION_GUARD | local reference math | Downhill adhesion inequality computed inline from parameters | No production ground/motion call; cannot certify actual adhesion. | C07 |
| DIAG-04 · L101 | REGRESSION_GUARD | text/config only | HUD source absence reload_current_scene | Text substring can miss equivalent behavior or fail harmless refactor. | C07 |
| DIAG-05 · L110 | REGRESSION_GUARD | text/config only | Foliage source contains noise/t_factor | Presence does not prove actual spawn coordinates/contact. | C07 |
| DIAG-06 · L119 | REGRESSION_GUARD | E2 config | Real bicycle scene collision layer8/mask7 | Properties, not registered collision coverage. | — |
| DIAG-07 · L128 | REGRESSION_GUARD | E2 + text | No current_gear; telemetry signal arity3 + HUD source signature | Current signal API, not emitted-event/hud update correctness. | C07 |
| DIAG-08 · L151 | REGRESSION_GUARD | text/config only | RoadChunk strict noise assert and absence1337 fallback | Exact strings, not execution of all missing-noise paths. | C07 |
| DIAG-09 · L161 | REGRESSION_GUARD | text/config only | Foliage source world-position noise sampling strings | Equivalent implementation changes can break text oracle; not actual transform test. | C07 |
| DIAG-10 · L172 | REGRESSION_GUARD | local reference math + config | Exports + inline equilibrium/coast (−2°,17..21km/h;road25..35s,grass<12s) | Does not step real controller. | C07 |
| DIAG-11 · L199 | REGRESSION_GUARD | E2 config | Pitch fields and exported attack14/decay7 | Config presence, not actual ray dropout/pitch coupling. | — |
| DIAG-12 · L210 | REGRESSION_GUARD | local reference math + config | Inline turn radius from exports≥25m,max steer≥.48 | No actual trajectory. | C07 |
| DIAG-13 · L225 | REGRESSION_GUARD | E2 config | Brake attack.12..20s and dive≤1.7 fields | No real stopping/brake bite measurement. | — |
| DIAG-14 · L235 | REGRESSION_GUARD | E2 config | Pedal attack.30..65s/power field | No actual Input acceleration here. | — |
| DIAG-15 · L244 | REGRESSION_GUARD | E2 config | Scrub threshold1.5 or1.8/coefficient>.10 | No actual scrub onset here. | — |
| DIAG-16 · L253 | REGRESSION_GUARD | E2 config | Camera noise5..10Hz,amp≤.003,grass multiplier≥1.4 | No rendered motion/perception. | — |
| DIAG-17 · L267 | REGRESSION_GUARD | E2 | Actual steering method both signs after30/60steps | Assigned controller state; no registered road trajectory. | — |
| DIAG-18 · L294 | REGRESSION_GUARD | E2 | Actual visual axle isolation delta<.0001, wheel spin>.01 | Scene transforms, not rendered artifact. | — |
| DIAG-19 · L311 | REGRESSION_GUARD | E2 | Actual audio ready/process loop WAV + wind/gravel state | Volumes/pitch properties, no audible human listening. | — |
| DIAG-20 · L347 | REGRESSION_GUARD | E2 | FP actual FOV>82 and exact FP78/83,TP68/72 exports | TP runtime FOV not tested. | — |
| DIAG-21 · L368 | REGRESSION_GUARD | E2 | Actual steering signs and visual clamp bands20..24/15..18/10..14 | Current player presentation numbers, not new world authority. | — |
| DIAG-22 · L407 | REGRESSION_GUARD | E2 | Actual16°visual steer axle X-axis alignment/wheel spin | Transform geometry, not visual human perceptibility. | — |
| DIAG-23 · L428 | REGRESSION_GUARD | local reference math | Inline600frame acceleration0→20 within4.8..6.5s,exports1.2..1.4 | No production forward dynamics call. | C07 |
| DIAG-24 · L453 | REGRESSION_GUARD | E2 | Actual audio at3speeds within dB corridors | Missing audio manager skips own group failure; no listening. | C07 |
| DIAG-25 · L484 | ACTIVE_CONTRACT | E2 | Actual WorldManager recovery on synthetic downhill path gives horizontal basis | No real runtime surface ray or collision-safe spawn guarantee. | — |
| DIAG-26 · L505 | REGRESSION_GUARD | E2 config | Grass material CULL_DISABLED | Not Vulkan pixels/winding visibility. | — |
| DIAG-27 · L520 | REGRESSION_GUARD | E2 | Real generated PCM endpoints normalized jump<.25 | Missing audio manager skips own group failure; not listening/spectrum. | C07 |
| DIAG-28 · L540 | REGRESSION_GUARD | E2 | Actual ScreenFader twice, is_fading remains true | Callback call_count is never asserted: true reentrancy completion unproved. | C07 |
| DIAG-29 · L557 | REGRESSION_GUARD | E2 config | Actual SpringArm collision mask6 | No camera collision sweep. | — |
| DIAG-30 · L570 | REGRESSION_GUARD | E2 config | Actual audio player bus assignments | Missing manager skips own group; bus names not audible routing proof. | C07 |
| DIAG-31 · L584 | REGRESSION_GUARD | local reference math | Inline flat coast Euler25km/h→stop25..35s | No production forward dynamics call. | C07 |
| DIAG-32 · L602 | REGRESSION_GUARD | local reference math + config | Inline ten-tap min-clamp and sprint export11.5..13m/s | Reference clamps itself, not actual input accumulation. | C07 |
| DIAG-33 · L620 | REGRESSION_GUARD | local reference math | Inline gravity/equilibria across3slopes,uphill coast≤9s | No physical hill ride. | C07 |
| DIAG-34 · L646 | REGRESSION_GUARD | E2 | Actual caster steering return≤.75s, no overshoot, initial>.1 | Direct method steps, not free-riding turn. | — |
| DIAG-35 · L674 | REGRESSION_GUARD | E2 | Actual40km/h full-steer radius≥25,a_lat≤5.2,bank clamp | Radius derived from state; no swept real trajectory. | — |
| DIAG-36 · L692 | REGRESSION_GUARD | E2 | Actual steering+forward-method scrub cases/balance residual<.01 | Manually assigned velocity/bank/surface; no road interaction. | — |
| DIAG-37 · L744 | REGRESSION_GUARD | local reference math + config | Local normal atan2 pitch ±5.5°within.05 + front/rear field presence | Does not cause production ray dropout. | C07 |
| DIAG-38 · L771 | REGRESSION_GUARD | local reference math | Local .7/.5 weights normalized by test itself; convex/bounded resistance | Does not call _blend_surface_weights; intended invariant still protected by FIX-WEIGHTS. | C07 |
| DIAG-39 · L805 | REGRESSION_GUARD | local reference math + config | Assigned physics_pitch, local visual lerp60frames maxstep<.85°,suspensionexport.04 | No actual crest/dip contact/pitch evolution. | C07 |
| DIAG-40 · L839 | REGRESSION_GUARD | local reference math | Local roughness-dot/slope/chatter algebra | No production contact classifier/surface dynamics. | C07 |
| DIAG-41 · L871 | REGRESSION_GUARD | E2 + local math | Actual visual wheel update44km/h; spoke/node/local Nyquist ratio | Rendered aliasing not observed. | C07 |
| DIAG-42 · L903 | REGRESSION_GUARD | E2 | Actual visuals brake.4/1→skid0/1 rear10%ratiowithin.01 | Manual speed/brake; not physical wheel lock. | — |
| DIAG-43 · L940 | REGRESSION_GUARD | E2 | Actual crank cadence25km/h≈75,coast level<4°,pedal counterrotation | No full-chain Input/physical cadence. | — |
| DIAG-44 · L985 | ACTIVE_CONTRACT | E2 | Actual VisualsRoot bank24,pitch6+dive1.7,suspension.04; root remains UP | Real transform invariant, not terrain passage. | — |
| DIAG-45 · L1017 | REGRESSION_GUARD | E2 | Actual camera standstill<.0001,noise exists,roughmag>1.3baseline | Does not test same-seed noise determinism despite title. | C07 |
| DIAG-46 · L1059 | REGRESSION_GUARD | E2 | Actual camera surge +2.5/−7/0 bounds | Direct process calls; no captured/human comfort. | — |
| DIAG-47 · L1099 | REGRESSION_GUARD | E2 | Actual camera dive bounds and bank20→roll12..13.1° | Current65%horizon follow; older report35% is stale. | — |
| DIAG-48 · L1135 | ACTIVE_CONTRACT | E2 | Actual camera reset state/baseposition | Dirty current_look_yaw not asserted. | C07 |
| DIAG-49 · L1170 | REGRESSION_GUARD | E2 actual subcheck only | Actual stopped/pedal audio timer gating; real click duration vs local speed-interval formula | Actual cadence at each10/25/44speed not measured; split subrow below. | C07 |
| DIAG-50 · L1221 | REGRESSION_GUARD | E2 | Actual audio rough/scrub/skid dynamics: base−34..−25,roughdelta>.5≤3.2,peak≤−19.9,skid>−35 | Printed3dB/−20 not exact predicates; scrub volume printed without direct comparison. | — |
| DIAG-51 · L1279 | REGRESSION_GUARD | E2 | Actual wind WAV duration≥4.4 and pitch1±.05 across4speeds | No progressive bandwidth spectral analysis. | — |
| DIAG-52 · L1317 | REGRESSION_GUARD | E2 | Actual bell duration≥1.5,PCMpeak≤.95,master limiter exists | No harmonic FFT or effective/enabled limiter test. | — |
| DIAG-53 · L1360 | REGRESSION_GUARD | E2 actual subcheck only | Actual ROUGH_GRAVEL chunk flag/layer18/metadata | Bike identification computed by test flags, not bike ray classification; split below. | C07 |
| DIAG-54 · L1400 | ACTIVE_CONTRACT | E2 | Actual forward method braking resets boost; tap C0 at43.95/44.05;airborne drag | Manually assigned state; not Input/full ride. | — |
| DIAG-55 · L1444 | REGRESSION_GUARD | E2 actual subcheck only | Local kinematic trajectory/radius; actual steer gain1/3.5/10 leaves yaw/a_lat/scrub same | Local trajectory does not integrate production motion; split below. | C07 |
| DIAG-56 · L1524 | REGRESSION_GUARD | E2 | Actual forward method15airborne+1landed state,deltaV<.04 | Manually switches contact flags; no registered touchdown. | — |
| DIAG-57 · L1567 | REGRESSION_GUARD | E2 | Actual forward method launch4.8..6.5,cruise24,time delta1.5..5,sprint/downhill2.5..7.5 | Continuous boost topups/manual state, not Input taps; printed4.5minimum not predicate. | — |
| DIAG-58 · L1645 | REGRESSION_GUARD | E2 + local math | Actual forward coast25..stop25..35;inline initialdrag/rolling decomposition | No road hill/input/frame performance. | C07 |
| DIAG-59 · L1679 | REGRESSION_GUARD | E2 actual subcheck only | Actual straight steering zero scrub; local1.4/3.6 load/threshold math | Assigned scrub and local math not actual turning dynamics; split below. | C07 |
| DIAG-60 · L1723 | REGRESSION_GUARD | E2 | Actual visual steer gain/clamp,axle/wheel/crank/pedal decoupling | Scene transforms only. | — |
| DIAG-61 · L1770 | REGRESSION_GUARD | E2 | Actual controller/camera sign,root-UP vs visual bank | Nullcamera defaults roll check true; no GPU. | C07 |
| DIAG-62 · L1824 | REGRESSION_GUARD | local reference math | Local filter30/60/144steps at.5s within.0001 | No actual camera/full-app FPS runs. | C07 |
| DIAG-63 · L1870 | ACTIVE_CONTRACT | E2 | Actual bike recovery teleport with constant mockWorld spawn; speed3/reset all states | Mock cannot prove real safe spawn; optionalcamera/audio absent can pass. | C07 |
| DIAG-64 · L1943 | REGRESSION_GUARD | E2 config | Actual Master/SFX/Ambient/Music buses/limiter/player routing | Existence ≠ enabled/audible correctness. | — |
| DIAG-65 · L1989 | REGRESSION_GUARD | E2 conditional | Actual camera pedal-release twoframes swaypeak>.0002,maxstep<.0015,post>0 | Missing camera has no independent group failure; vacuity risk. | C07 |
| DIAG-66 · L2022 | ACTIVE_CONTRACT | E2 | Actual visual1200steps/20s manually angle wrap≤PI+.001 | Not real20s ride or timing budget. | — |
| DIAG-67 · L2052 | REGRESSION_GUARD | E2 conditional + config | Actual rough surface camera/audio process;exportamp2.4,pitch≥.99 | Camera amplitude is config,not measured shake; missing modules can pass. | C07 |
| DIAG-68 · L2083 | ACTIVE_CONTRACT | E1 | Actual PathData nearest-index synthetic250points,target110 with cached0 | Boundary search regression, not global arbitrary topology nearest solution. | — |
| DIAG-49-REF · L1170 | OBSERVATIONAL | local reference math only | Local ratchet interval formula at10/25/44km/h compared to generated PCM duration | Actual gating belongs DIAG-49; localinterval not actual speed-driven cadence. | C07 |
| DIAG-53-REF · L1360 | OBSERVATIONAL | local reference math only | Reference chooses surface from chunk flag and computes expected ROUGH identity | Actual bike surface detection untested here; DIAG-53 only realchunk contract. | C07 |
| DIAG-55-REF · L1444 | OBSERVATIONAL | local reference math only | Inline2s circular trajectory radius within1% | Actual gain-isolation belongs DIAG-55; formula proof not production trajectory. | C07 |
| DIAG-59-REF · L1679 | OBSERVATIONAL | local reference math only | Inline load1.4/3.6 threshold balance | Actual straightzero scrub belongs DIAG-59; turning scrub unproved here. | C07 |

### test_dynamic_rideability.gd

Source: [test_dynamic_rideability.gd](../scripts/test/test_dynamic_rideability.gd) — 331 lines; SHA256 в §10.

Role: mixed physical runner + teleport integration. Protected owner/path: BicycleController/lab → Main/streamer.

Prerequisites/workload: lab; real bike/registered collision; then2 procedural seeds with bike disabled. Trigger: event/surface/physics/fork integration changes. Completion/reporting: incremented checks; per-episode results; final failures.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| DYNAMIC-CREST · L79 | REGRESSION_GUARD | E3,E4 | 90 frames T6: unweight≤.30s, pitch−18..+10°, recovered contact, lateral≤1.2m | Short lab episode; no full procedural crest battery. | — |
| DYNAMIC-DROP · L142 | REGRESSION_GUARD | E3,E4 | 120 frames T10: ≥4 flight frames, recontact, suspension15..120mm, absVy≤6.5, finite Y and Y≥−100 | Single authored drop; no full swept collision/tunneling measurement. | — |
| DYNAMIC-TURN · L201 | REGRESSION_GUARD | E3,E4 | 80 frames hairpin, initial64m/speed5.5, manually assigned current_steer; min observed speed≥3, roll≤28°, lateral≤1.2 | Printed exit-speed is minimum sampled speed; no endpoint-arrival proof; not Input-driven whole ride. | C03 |
| DYNAMIC-FORK · L257 | REGRESSION_GUARD | E3; E4 ray interaction only | 2 seeds ×250 steps; bike physics disabled; teleported centerline, road-layer rays zero misses; fixed LEFT fork reached | RIGHT/brakes/wedge header claims exceed oracle. Must not be counted as physical fork ride. | C03 |

### test_foliage_contact_watchdog.gd

Source: [test_foliage_contact_watchdog.gd](../scripts/test/test_foliage_contact_watchdog.gd) — 142 lines; SHA256 в §10.

Role: surface/contact watchdog runner. Protected owner/path: ChunkFoliage prepared transforms → RoadChunk terrainfaces.

Prerequisites/workload: 3seeds×12chunks;pine/birch/boulder; nonempty coverage. Trigger: foliage/contact/terrain/forkmask changes. Completion/reporting: violations + missing-ground/empty checks, correctedC03/C04.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| FOLIAGE-CONTACT · L19 | ACTIVE_CONTRACT | E2 | Prepared real prop root/barycentric terrain height, floating/buried bounds; missing triangle now fails | Nearest-Y surface selection; grass untested; normal chunks not full realforkmask; no physics interaction. | — |

### test_fork_biome_pacing.gd

Source: [test_fork_biome_pacing.gd](../scripts/test/test_fork_biome_pacing.gd) — 271 lines; SHA256 в §10.

Role: mixed domain/integration runner. Protected owner/path: ForkPacing/Site/Corridor planners → ChunkStreamer.

Prerequisites/workload: 5seeds arithmetic1.5km;2seeds40streamerupdates; terrain stubs. Trigger: biome/pacing/cliff eligibility changes. Completion/reporting: incremented _check;5groups.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| BIOME-PACE · L69 | LEGACY_CONTRACT | E1 | Interpolation/clamp old biome spacing/delay and site/preview one-cliff relax vs two-side danger | Cliff safety policy tied to current fork design; not new biome road difficulty specification. | C01 |
| BIOME-FREQ · L169 | LEGACY_CONTRACT | E1 | 5seeds synthetic1.5km, mountain≥4forks, forest2..3; maxdelay≤500actual | Empirical frequency is planner arithmetic at candidate=target, delay0; header200m notpredicate; no actual streamed1.5km. | C04 |
| BIOME-WIRE · L214 | REGRESSION_GUARD | E2 | 2seed streamer biome weights/targets/fork creation after≤40updates | No Main frames/ride; not memory/leak measurement. | — |

### test_fork_corridor_preview.gd

Source: [test_fork_corridor_preview.gd](../scripts/test/test_fork_corridor_preview.gd) — 63 lines; SHA256 в §10.

Role: domain/integration runner. Protected owner/path: ForkCorridorPreviewPlanner → ForkArmGeometry/TerrainCarver.

Prerequisites/workload: 26samples/~50m perarm; seed184729; real +stub terrain contexts. Trigger: preview/arm/terrain eligibility changes. Completion/reporting: _check counters;15 checks historical expectation only until run.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PREVIEW · L21 | ACTIVE_CONTRACT | E1,E2 | Actual paired arm builder, C0/style/repeat; per-side danger, same-style, steep/null evaluator negatives | Limited preview50m; no committed meshes/ride or following grammar legs. | — |

### test_fork_decision.gd

Source: [test_fork_decision.gd](../scripts/test/test_fork_decision.gd) — 395 lines; SHA256 в §10.

Role: domain/integration runner. Protected owner/path: RoadMath/PathData → ForkDecisionModel/RoadGraph.

Prerequisites/workload: synthetic fork centerlines; repeated trajectories/synthetic model updates at30/60/120 samples per second, velocities, mirrors. Trigger: decision FSM/geometry/lateral conventions changes. Completion/reporting: incremented assertions;7 meaningful groups.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| FORK-WIDTH · L67 | REGRESSION_GUARD | E1,E2 | Production width and path-data width helper consistency | Fixture scalar/arrays; no actual bike/terrain. | — |
| FORK-SIGN · L129 | ACTIVE_CONTRACT | E1 | Signed lateral factors/model conventions | Geometric convention survives storage migration; not physical steering proof. | — |
| FORK-FSM · L166 | REGRESSION_GUARD | E1,E2 | APPROACH/PREVIEW reversal, COMMIT lock, dead-center fallback, stationary guard, speed/timestep invariance, mirror symmetry | Synthetic model updates; no whole-engine FPS run at30/60/120. | — |

### test_fork_geometry_verification.gd

Source: [test_fork_geometry_verification.gd](../scripts/test/test_fork_geometry_verification.gd) — 193 lines; SHA256 в §10.

Role: integration runner. Protected owner/path: ChunkStreamer → RoadChunk/ForkArmGeometry/PathData.

Prerequisites/workload: seed184729 production resources, manually invoke fork construction; side-mask fixture seed99999. Trigger: fork width/arm/wedge/terrain masks changes. Completion/reporting: 15 incremented checks; no physical runner.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| FORK-APPROACH · L67 | REGRESSION_GUARD | E2 | 3.6±.05 endwidth, braking type, sight≥45m, mild−5..+2grade, startwidth≤1.81 | Header3.2→6.5 obsolete; metadata sight not rendered occlusion. | C10 |
| FORK-ARM · L95 | ACTIVE_CONTRACT | E2 | Real arm chunks present; separation>10m at50m, inner apex gap≤.001; road2 terrain4 layer properties | Header26°/>18m and wedge crown/C1 claims not separate predicates; registered ray/bike interaction unproved. | C07 |
| FORK-MASK · L151 | REGRESSION_GUARD | E2 | Prepared terrain faces forside1/2 satisfy world-X halfspace±.5 | Not overlap-volume test; curved path measured against global X, empty faces vacuously pass; not whole real pair overlap. | C07 |

### test_fork_pacing_planner.gd

Source: [test_fork_pacing_planner.gd](../scripts/test/test_fork_pacing_planner.gd) — 90 lines; SHA256 в §10.

Role: mixed domain runner. Protected owner/path: ForkPacingPlanner → streamer trace ring.

Prerequisites/workload: eligible/unsafe/overrun synthetic distances;70records ring64. Trigger: pacing/eligibility/trace changes. Completion/reporting: incremented _check counters.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PACING-SAFE · L13 | ACTIVE_CONTRACT | E1 | Wait/defer/first safe candidate; overrun never safety bypass; NaN/INF/negative rejection/determinism | Safety math retained, independent of selected game pacing. | — |
| PACING-BAND · L13 | LEGACY_CONTRACT | E1 | Exact200m deferral and subsequent550..900m legacy bands | Different biome-specific scheduler/new region design; retain old checks for present consumer. | C01 |
| PACING-RING · L65 | REGRESSION_GUARD | E2 | 70 writes retain64 records, first ordinal7 | Current instrumentation ring, not durable full history. | — |

### test_fork_site_planner.gd

Source: [test_fork_site_planner.gd](../scripts/test/test_fork_site_planner.gd) — 234 lines; SHA256 в §10.

Role: mixed unit/integration runner. Protected owner/path: ForkSitePlanner → terrain evaluator/ChunkStreamer.

Prerequisites/workload: stub terrain unit boundary;3 production seeds repeated endpoint search≤41chunks; forced rejection seams. Trigger: site/terrain eligibility/fallback changes. Completion/reporting: incremented checks/reasons, final failure summary.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| SITE-UNIT · L49 | ACTIVE_CONTRACT | E1,E2 | Real evaluator rejects invalid preceding chunk,44.9/INF sight, missing/danger terrain, width/grade/curve/contact/array/nonfinite/index cases; repeat/nonmutation | Terrain stub explicit collaborator fixture, not production terrain coverage. | — |
| SITE-SEED · L120 | REGRESSION_GUARD | E2 | Repeated production RoadLogic + planner endpoint searches on3 seeds | No Main/collider/physical run; accepted early sites don't prove terrain-driven deferral. | — |
| SITE-FALLBACK · L133 | REGRESSION_GUARD | E2 | Forced site/preview reject through real streamer ordinary-chunk fallback without fork/widening | Forced seams test wiring only; not real planner finding unsafe runtime site. | — |

### test_gravel_loop.gd

Source: [test_gravel_loop.gd](../scripts/test/test_gravel_loop.gd) — 263 lines; SHA256 в §10.

Role: authored track runner. Protected owner/path: 4L generator → custom meshes/colliders/signage/recovery.

Prerequisites/workload: 4Lscene/tree/imports; defaultscene seed. Trigger: authored fixture/scene/custom recovery changes; master integration. Completion/reporting: fail-fast; fixed-labelled6/15/16 success strings not dynamically collected count.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| GRAVEL-GEO · L32 | REGRESSION_GUARD | E2,E3 | 611samples,length1150..1300,seam5mm/vector.010,step≤3,rates.018/.06,grade−2.75..2.5,11contiguoussections | Current authoredgeometry regression, not requirement for allnewroutes. | — |
| GRAVEL-STRUCT · L32 | REGRESSION_GUARD | E2,E3 | ≥24alllayerchunks,roughpresent,MEADOW≥50,recoverybasis/distance,sign==11 | MEADOWprinted>50 but≥50 actual; no fullride. | — |
| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| GRAVEL-LEAK · L32 | N/A — NON_CHECK_ARTIFACT | unchecked output/cleanup fragment; sibling check rows in same file | queue_free then printed0leaks. No leakcountoracle. |

### test_macro_profile_road_integration.gd

Source: [test_macro_profile_road_integration.gd](../scripts/test/test_macro_profile_road_integration.gd) — 120 lines; SHA256 в §10.

Role: integration runner. Protected owner/path: Main/streamer → MountainProfile/RoadLogic → TerrainCarver.

Prerequisites/workload: 2seeds repeated, both manually spawned arms. Trigger: macro profile/fork/shared terrain changes. Completion/reporting: _check counters; source-stale oracle explicit, runtime NOT_RUN.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MACRO-ROAD · L24 | ACTIVE_CONTRACT | E2,E3 | Sharedprofile blend.35, routeoriginjunction_s+.9, innerseam≤.001, macrograde delta≤.003 and tangentgrade≤.001,repeat | Current blend/origin constants are representation-dependent; not claim entire profile physically ridden. | — |
| MACRO-TERR · L95 | REGRESSION_GUARD | E1,E2 | Intended road/terrain anchoring checks demand exactly8vertices,index3/4 | Current TerrainCarver outputs12,index5/6 and verge−.035. Provable source mismatch; candidate protection retained, oracle unresolved; no fix/category downgrade to get green. | C12 |

### test_mode_select_gamepad.gd

Source: [test_mode_select_gamepad.gd](../scripts/test/test_mode_select_gamepad.gd) — 73 lines; SHA256 в §10.

Role: runtime UI runner. Protected owner/path: ModeSelect and mode_select scene.

Prerequisites/workload: tree1frame;synthetic joy events/buttonfocus;assertionsenabled. Trigger: mode menu/gamepad/UI resource changes. Completion/reporting: built-in asserts, flagis_changing_scene thenquit.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MENU-PAD · L5 | REGRESSION_GUARD | E2,E3 | Fourbuttons,initialfocus,DPADdown/up,stickdown,A sets scene-change flag | Does not verify finished destinationload,realhardwareor seedgeneration despiteheader. | — |

### test_monotony_profiler.gd

Source: [test_monotony_profiler.gd](../scripts/test/test_monotony_profiler.gd) — 123 lines; SHA256 в §10.

Role: runner/statistical watchdog. Protected owner/path: RoadLogic path; mountain weights.

Prerequisites/workload: 3 fixed seeds ×12 chunks; nominal600m; mountain40m windows. Trigger: G: every world-generation change. Completion/reporting: dead/flat violation count.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MONOTONY · L18 | REGRESSION_GUARD | E1 | Dead segment when curvature<.005 AND grade<.005; max100m; mountain weight>.65 then road-Y relief≥1m/40m | Road Y, not terrain/foliage; no mountain windows→NOTE and no relief assertion; does not measure calm/boring human feel. | C04 |

### test_mountain_massif_field.gd

Source: [test_mountain_massif_field.gd](../scripts/test/test_mountain_massif_field.gd) — 81 lines; SHA256 в §10.

Role: domain runner. Protected owner/path: MountainMassifField.

Prerequisites/workload: seed184729 pair vs99999; grids;height/gradient/contour/steepness. Trigger: terrain field/seed/math changes. Completion/reporting: built-in assert with enabled assertions; quit0 after allblocks.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MASSIF · L5 | ACTIVE_CONTRACT | E1 | Finite/deterministic elevations; >40points differ>1m; gradient-contourdot<.001;Xfinite-differenceerror<.25;steepness0..85 | Numerical gradient, not analytical despite print; contour derived samegradient; no C0 check abs_dx85 valley border, known4.5mjump unprotected. | C13 |

### test_mountain_profile.gd

Source: [test_mountain_profile.gd](../scripts/test/test_mountain_profile.gd) — 187 lines; SHA256 в §10.

Role: mixed domain runner. Protected owner/path: MountainProfile analytic height/grade/biome weights.

Prerequisites/workload: 7seeds×3routeIDs;12km/20m queries;40nominal300m boundaries;5seed biome5km/10m. Trigger: profile/seed/biome API changes. Completion/reporting: actual _check counters; deterministic finite selected queries.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PROFILE-DET · L23 | ACTIVE_CONTRACT | E1 | Repeated/reversed random access, C0<.00016,C1grade/rate<.0001 at boundary±.001, diversity; weights finite/clamped/repeat/transition | Sampled points/boundaries, not every terrain tile or numeric derivative analytic proof. | — |
| PROFILE-DESCENT · L54 | LEGACY_CONTRACT | E1 | Grade−8.01..−2.49,strict every20m descent,12km drop1000..1160 | Old infinite-downhill envelope; cannot impose monotonic descent on target bounded regions. | C01 |
| PROFILE-ZONES · L132 | LEGACY_CONTRACT | E1 | 5km≥4switches,mountainratio.30..85,forest.08..60,transition≥.05,zone≥50m | Current harmonic biome-weight representation; not target biome catalog. | C01 |

### test_mountain_validation.gd

Source: [test_mountain_validation.gd](../scripts/test/test_mountain_validation.gd) — 200 lines; SHA256 в §10.

Role: teleport stress/budget runner. Protected owner/path: Main/streamer → branch resources.

Prerequisites/workload: 3seeds×20fork=60 manuallyalternating; artificialfork100m,safety25;≤4000steps. Trigger: streaming/fork/unload/resource changes. Completion/reporting: actual assertion counters + target forks, bounded resources.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MOUNTAIN-STATE · L62 | REGRESSION_GUARD | E3 | Forktarget,recovery,bike position/sample widths1..3.6/grade−14.5..5.5; trace64seed/decision/acceptedcount | No physics wait inside progressionloop; poseforcing; XYZNaN check notINF; headerswidth1.8..6.5/grades differ; maxdelay only printed. | C03 |
| MOUNTAIN-RESOURCE · L62 | REGRESSION_GUARD | E6 narrow | OS static-memory peakdelta<25MB, activechunks≤15,branches≤3 | CPU Godot staticmem not processRAM/VRAM/ObjectDB; loop stress not continuousride; no framehitch guarantee. | C09 |

### test_mtb_event_geometry_catalog.gd

Source: [test_mtb_event_geometry_catalog.gd](../scripts/test/test_mtb_event_geometry_catalog.gd) — 143 lines; SHA256 в §10.

Role: domain/integration runner. Protected owner/path: RoadLogic forced event builders → validator.

Prerequisites/workload: 12seeds×4forcedphases repeated=48contexts. Trigger: event geometry/metadata/fallback changes. Completion/reporting: actual _check counters; intended event accepted/notfallback.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| EVENT-CAT · L57 | ACTIVE_CONTRACT | E1,E2 | Requested event/contact present, finite/signature repeat, no safe fallback; actual positive crest height≤.351, microdrop contacts | Other grade/chord/curvature envelope metrics printed, not all asserted; no committedcollider/ride. | — |

### test_mtb_event_pipeline.gd

Source: [test_mtb_event_pipeline.gd](../scripts/test/test_mtb_event_pipeline.gd) — 141 lines; SHA256 в §10.

Role: integration runner. Protected owner/path: RoadLogic airborne+recovery → RoadChunk prepare.

Prerequisites/workload: 4fixedseeds,repeats;11event intervals; prepared actual face data. Trigger: event/contact/mesh-collision preparation changes. Completion/reporting: actual _check counts + pipeline summary.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| EVENT-PIPE · L35 | ACTIVE_CONTRACT | E2 | Accepted AIRBORNE/LANDING/RECOVERY + finite/nonempty prepared mesh/faces; centerline midpoints inside road collision triangles | CPU prepared collision ≠ registeredPhysicsServer or bicycle passage. | — |

### test_procedural_run.gd

Source: [test_procedural_run.gd](../scripts/test/test_procedural_run.gd) — 87 lines; SHA256 в §10.

Role: physical episode runner + unchecked capture. Protected owner/path: Main/BicycleController/recovery.

Prerequisites/workload: effective seed not explicitly fixed; pedal180frames+steer180+recovery60; imports. Trigger: procedural bike/surface/recovery changes. Completion/reporting: is_on_grass failure, recoverygrass/Yfailure; no measured assertions.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PROC-RIDE · L9 | REGRESSION_GUARD | E3,E4 | Real Input pedal/steeroffroad thenInput recovery; grass true→false and recoveredY≥−10 | AbsoluteYnotterrainheight; nofork/allseeds/fullroute; deliberate recoveryteleport is feature, not physicalprogress spoof. | — |
| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| PROC-PNG · L9 | N/A — NON_CHECK_ARTIFACT | unchecked output/cleanup fragment; sibling check rows in same file | Optional2 screenshots. Headless skips; save_png return/reload/metadata notchecked; no self-certifiedPNG or visualquality. |

### test_review_fix.gd

Source: [test_review_fix.gd](../scripts/test/test_review_fix.gd) — 144 lines; SHA256 в §10.

Role: regression/negative runner. Protected owner/path: RoadGraph/path; ChunkFoliage; validator/RoadLogic; BicycleController.

Prerequisites/workload: five selected fixes;imports,bicycle instantiation;logical foliage keys. Trigger: affected graph/pruning/seed/validator/airborne/surface blending changes. Completion/reporting: actual _check counters (25historical; Q0NOT_RUN).

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| FIX-GRAPH · L33 | ACTIVE_CONTRACT | E1 | Real history pruning/adjacency and pathdata coherence | Finite selected history, not longruntimeleaks. | — |
| FIX-FOLIAGE · L58 | ACTIVE_CONTRACT | E2 | Actual transforms stable for logicalkey despite differentchunkids | No actual multi-branch scheduling/prune replay. | — |
| FIX-VALID · L80 | ACTIVE_CONTRACT | E1,E2 | Real malformedpath/sightline reasons and generatedforcedairborne survives realvalidator | Selected negatives; generateddata notphysicalride. | — |
| FIX-WEIGHTS · L127 | ACTIVE_CONTRACT | E2 | Production _blend_surface_weights afterhitch maintainsconvex bounds | This calls actual blend, unlike diagnostics#38 local normalization. | — |

### test_ride.gd

Source: [test_ride.gd](../scripts/test/test_ride.gd) — 32 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: sandbox Input pedal over120 process frames; steer_left pressed atframe60, released atframe100; conditional PNG;real display forPNG;fixedoutputnames/writablepath. Trigger: historical ride screenshot; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-test_ride · L9 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | sandbox Input pedal over120 process frames; steer_left pressed atframe60, released atframe100; conditional PNG. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### test_riding_lab.gd

Source: [test_riding_lab.gd](../scripts/test/test_riding_lab.gd) — 288 lines; SHA256 в §10.

Role: authored track runner. Protected owner/path: 4K generator → custom meshes/colliders/signage/recovery.

Prerequisites/workload: 4Kscene/tree/imports; defaultscene seed. Trigger: authored fixture/scene/custom recovery changes; master integration. Completion/reporting: fail-fast; fixed-labelled6/15/16 success strings not dynamically collected count.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| LAB-GEO · L32 | REGRESSION_GUARD | E2,E3 | 212samples,length400..440,seam5mm/vector.010,step≤3,horizontalrate≤.08/3Drate≤.18,grade±16,T6±7.5,T10≤−13,T2bank≥4 | Authored fixture intentionally tighter/steeper than world contract; no procedural safety exemption. | — |
| LAB-STRUCT · L32 | REGRESSION_GUARD | E2,E3 | ≥13contiguoussections,all≥8chunkroad/terrain layers,roughpresent,recoveryup≤.05/dist≤1.5,sign≥13 | All declared track regions only; no continuousride. | — |
| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| LAB-LEAK · L32 | N/A — NON_CHECK_ARTIFACT | unchecked output/cleanup fragment; sibling check rows in same file | queue_free then printed0leaks. No ObjectDB/memorymeasurement; leak claim unproved. |

### test_road_clearance_watchdog.gd

Source: [test_road_clearance_watchdog.gd](../scripts/test/test_road_clearance_watchdog.gd) — 131 lines; SHA256 в §10.

Role: geometry watchdog runner. Protected owner/path: RoadChunk/ChunkFoliage → PathData lateral clearance.

Prerequisites/workload: 5seeds×15chunks;syntheticwiden4/9. Trigger: roadwidth/decor/forksurface changes. Completion/reporting: intrusion count; empty props not fail.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PROP-CLEAR · L18 | REGRESSION_GUARD | E2 | Object center nearestsample/binormal outside roadhalfwidth+.50m,oldpost exceptions .15 | Centers, not full mesh/collider extents; emptyset passes; obsolete exception keys not active decor; not whole pairedfork. | — |

### test_road_contract.gd

Source: [test_road_contract.gd](../scripts/test/test_road_contract.gd) — 375 lines; SHA256 в §10.

Role: domain + benchmark runner. Protected owner/path: RoadValidityValidator/RoadGenerationContract/RoadAirborneContract → RoadLogic.

Prerequisites/workload: T01..T16 synthetic paths;5seeds×15 chunks;100chunk validator workload. Trigger: validator/road/airborne/seam changes. Completion/reporting: 18 named result groups; source pass/fail counters, not master expected events.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| ROAD-VALID · L95 | ACTIVE_CONTRACT | E1 | T01..T08 accepted grounded/microdrop/airborne+landing/recovery, T09 exact uncontrolled-gap status; T10..14 invalid; T15 visibility; T16 5mm seam tear | Most invalid cases assert not-is-valid, not specific reason; T16 position fault does not test independent C1 fault. Landing production tolerance actually delta-grade+10 (14°), not header4°. | C10 |
| ROAD-GEN · L341 | REGRESSION_GUARD | E1,E2 | 5seeds×15 real chunks through validator | Selected battery; accepted candidate may be safe fallback; not all seeds/E4. | — |
| ROAD-PERF · L361 | REGRESSION_GUARD | E6 narrow | 100 chunks validated, valid report and <10ms total | Not full generation or frame budget; no GPU. | C09 |

### test_road_event_chunk_seams.gd

Source: [test_road_event_chunk_seams.gd](../scripts/test/test_road_event_chunk_seams.gd) — 215 lines; SHA256 в §10.

Role: integration runner. Protected owner/path: RoadLogic → validator.validate_seam → RoadChunk/TerrainCarver.

Prerequisites/workload: 4seeds×4sequences,36boundaries repeated. Trigger: event/surface/chunk seam changes. Completion/reporting: actual _check counts + boundaries/signatures.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| EVENT-SEAM · L50 | ACTIVE_CONTRACT | E2 | Requested events, seamC0/C1/slope/normal, actual prepared shared vertices/faces, finite/nondegenerate, repeat; all12terraincolumns nearest≤1e-6 | Strict road6/terrain60face vertices perinterval tied to current topology; no livebike/GPU. | — |
| EVENT-LAYOUT · L50 | LEGACY_CONTRACT | E2 | Exact prepared terrain12column/face-count layout | Representation-specific geometry contract; retain independent continuity/nonempty invariants in EVENT-SEAM during migration. | C01 |

### test_road_grammar.gd

Source: [test_road_grammar.gd](../scripts/test/test_road_grammar.gd) — 278 lines; SHA256 в §10.

Role: domain/budget runner. Protected owner/path: RoadGrammar → RoadLogic → validator.

Prerequisites/workload: seed184729;5×1000chunks;200chunk benchmark; biome battery. Trigger: grammar/event/biome/road changes. Completion/reporting: final boolean; reported timing/distribution not all asserted.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| GRAMMAR-DET · L60 | ACTIVE_CONTRACT | E1 | Same-seed size equality and all generated path points after30 chunks per path; max point delta<1e-6 | Not every generated channel or interleaved scheduling; compares all path points, not only30 selected points. | — |
| GRAMMAR-SAFE · L85 | REGRESSION_GUARD | E1,E2 | 5×1000chunk validation and forbidden AIRBORNE→GROUNDED transition | Seam error count copied from segment reports, no independent validate_seam; replacement fallback can mask intended feature absence. | C07 |
| GRAMMAR-PERF · L152 | REGRESSION_GUARD | E6 narrow | 200chunks; validator avg≤.08ms actual predicate | Printed generation.20ms/validator.05ms are not actual gates; generation timing has no failure predicate. | C09 |
| GRAMMAR-BIOME · L184 | LEGACY_CONTRACT | E1,E2 | Mountain WINDING≥25%, major events≤5 per rolling12 phases; forest FOREST_CRUISE≥35%, major events≤3 per rolling12 phases; exact legacy grammar distribution | Old phase/biome architecture, not new region pacing; budgets still apply current generator. | C01 |

### test_road_graph.gd

Source: [test_road_graph.gd](../scripts/test/test_road_graph.gd) — 354 lines; SHA256 в §10.

Role: mixed domain/benchmark runner. Protected owner/path: RoadKinematicModel/RoadPathData/RoadGraph.

Prerequisites/workload: headless/imports; synthetic paths/forks; benchmark sizes10k graph,32×100clone/slice. Trigger: math/path/graph consumer changes. Completion/reporting: incremented assertions; actual benchmark values; no runtime rider.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| GRAPH-KIN · L65 | ACTIVE_CONTRACT | E1 | Real braking regimes2.2/3.5/5.5, gravity9.80665, reaction/zero braking, insufficient braking→INF/status, safe curve speed | Scalar model contract ≠ real bicycle stopping distance. | — |
| GRAPH-PATH · L111 | ACTIVE_CONTRACT | E1 | Real clone/slice/append deep-copy arrays, metadata and seam policy | Test's all-arrays claim omits newer road_width/macro offset cases and incomplete mutation comparisons; not universal array certification. | C07 |
| GRAPH-TOPO · L186 | REGRESSION_GUARD | E1 | Registry/traversal/adjacency/branch identities and continuity APIs | Current graph storage/consumer regression; no new region graph implementation. | — |
| GRAPH-DAG · L186 | LEGACY_CONTRACT | E1 | Reject backward edge/cycle, strict is_dag invariant | Target loops/merges conflict recorded; old graph still protected. | C01 |
| GRAPH-FORK · L231 | REGRESSION_GUARD | E1,E2 | Synthetic 15-point fork: manual C0/C1, divergence10..40° at16m, real graph validation/export/braking | Handbuilt arms ≠ production ForkArmGeometry or committed wedge. | — |
| GRAPH-PERF · L317 | REGRESSION_GUARD | E6 narrow | 10k topology≤200ms;32×100clone/slice≤10ms | CPU operation budget only; graph part also asserts DAG, covered separately; hardware variance. | C09 |

### test_road_logic.gd

Source: [test_road_logic.gd](../scripts/test/test_road_logic.gd) — 91 lines; SHA256 в §10.

Role: domain runner. Protected owner/path: RoadLogic path generation.

Prerequisites/workload: paired determinism and5seed×100chunks. Trigger: RoadLogic/seed/geometry changes. Completion/reporting: actual condition counters/quit; prints looser/other threshold labels.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| LOGIC-DET · L31 | ACTIVE_CONTRACT | E1 | Same-seed path sample deterministic comparison | Ordered calls; not scheduling/interleaving. | — |
| LOGIC-LIMIT · L55 | REGRESSION_GUARD | E1 | Actual positive curvature radius≥17.5m, grade−14.51..+5.51 | Prints18m and−14/+5; doesn't cover signed negative curvature; governance19 vs production18 unresolved. | C10 |

### test_road_verge_seam_watchdog.gd

Source: [test_road_verge_seam_watchdog.gd](../scripts/test/test_road_verge_seam_watchdog.gd) — 110 lines; SHA256 в §10.

Role: geometry watchdog runner. Protected owner/path: RoadLogic → TerrainCarver.

Prerequisites/workload: 3seeds×10chunks;cross-section edges5/6. Trigger: roadedge/verge changes. Completion/reporting: coplanar/lower-step violations.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| VERGE · L18 | REGRESSION_GUARD | E1,E2 | Road edge vs terrainY step fails<.015m | Upper2..5cm printed notasserted; preparedcrosssection not committed roughseam/collision/GPU Zfighting. | C10 |

### test_route_branch_integration.gd

Source: [test_route_branch_integration.gd](../scripts/test/test_route_branch_integration.gd) — 347 lines; SHA256 в §10.

Role: runner/teleport integration. Protected owner/path: Main → ForkDecisionModel/RoadGraph/ChunkStreamer.

Prerequisites/workload: 2 modes×2seeds×2choices=8; initialfork100m,safety25;≤1200steps; world/bike processing disabled. Trigger: branch/FSM/route/streaming changes; paired-route slice. Completion/reporting: incremented checks + actual routes/failures; unexecuted Q0.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| ROUTE-LOCK · L36 | REGRESSION_GUARD | E2,E3 | Active edge identity/layer/chunk intervals, sample gap≤2.5,next-fork arrival/outgoing lock both choices | Centerline teleport not wheel/ray swept collision/physical ride; controlled parent fork may pre-exist, not fair interval test; historical9fail/4routes open. | C03 |
| ROUTE-SPACE · L288 | LEGACY_CONTRACT | E3 | Current scheduled550..900band/deferral and role/diversity predicates | Old scheduler metrics not target RegionRouteGraph pacing; runtime failure still blocks impacted present system. | C01 |

### test_route_clearance_audit.gd

Source: [test_route_clearance_audit.gd](../scripts/test/test_route_clearance_audit.gd) — 204 lines; SHA256 в §10.

Role: observational audit + traversal checks. Protected owner/path: Main/streamer/graph → road physics rays.

Prerequisites/workload: 2seeds ×LEFT_ONLY/RIGHT_ONLY×12fork=48choices; disabled bike; rays±5m at offsets−.5/0/.5. Requested/configured seed labels only: randomize_world_seed_on_start remains true in Main; startup resolves CLI/randomization before RoadLogic construction. Effective generated seed UNKNOWN_CURRENT without matching future manifest. Explicit CLI override takes precedence and may repeat one effective seed across nominal loop labels; it cannot prove the whole requested battery. C08. Trigger: crossing/clearance/unload/fork changes; reproduce human incident. Completion/reporting: only failed traversal affects exit; candidates/misses are observations.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CLEAR-TRAVERSE · L26 | REGRESSION_GUARD | E3 | Complete12fork perconfigured route through real FSM/streamer | Physical bike disabled; only4 choice patterns, not arbitrary human route. | C08 |
| CLEAR-MEASURE · L140 | OBSERVATIONAL | E3; E4 ray interaction only | Centerline proximity horizontal3m/vertical2m excludes shared endpoints/forks; before/after real road-rays lateral3probes | Candidate/miss findings not failure predicates; after_results[0] labelled center is−.5offset; not bike volume/height-error bound; human under-fork complaint stays unresolved. | C08,C11 |

### test_route_intent.gd

Source: [test_route_intent.gd](../scripts/test/test_route_intent.gd) — 153 lines; SHA256 в §10.

Role: mixed domain/integration runner. Protected owner/path: RoadGrammar → RoadLogic production opening.

Prerequisites/workload: 4seeds×2styles×2salts×9chunks,repeated. Trigger: intent/opening/grammar/events changes. Completion/reporting: actual _check counters; if empty skip downstream with earlier failure.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| INTENT-DET · L45 | ACTIVE_CONTRACT | E1,E2 | Repeated generated centerline/event signatures and validity, grade−14.01..5.01/absκ≤1/18+.0001/gap≤2.5 | Intent declaration alone insufficient; limited9chunks, no runtime ride. | — |
| INTENT-STYLE · L45 | LEGACY_CONTRACT | E1,E2 | Old FLOW noairborne/switchback;TECHNICAL switchback+recovery/opposite turns; actual noairborne; signatures differ | Current opening queue architecture/labels, not target biome identity/whole journey. | C01 |

### test_route_plan_contract.gd

Source: [test_route_plan_contract.gd](../scripts/test/test_route_plan_contract.gd) — 283 lines; SHA256 в §10.

Role: mixed domain runner + controlled telemetry audit. Protected owner/path: RouteIntent/RoutePlan ← RoadLogic; bike/chunks for telemetry.

Prerequisites/workload: 4seeds×2styles×2salts×9chunks, reversed order;2 telemetry styles seed184729salt101. Trigger: route adapters/intent/metrics changes. Completion/reporting: actual checks; printed geometry_profiles16 EXPECTED; physics_traces actual.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| PLAN-NEG · L71 | ACTIVE_CONTRACT | E1 | Real invalid input reasons: missingintent/phase/startdistance/range/intervals/malformedpath metrics | Not all negative cases assert exact reason; no general serialization/version test. | — |
| PLAN-GEO · L25 | REGRESSION_GUARD | E1,E2 | Real adapters and repeated signatures, measured length/gap, reverse materialization seed order/style distinction | 16 printed profiles not measured completion count; signatures not all physical channels. | C02 |
| PLAN-TELEM-DATA · L163 | ACTIVE_CONTRACT | E2,E3 proxy adapter integration | Real RoutePlan validates telemetry-bearing data, signature repeats, serialized dictionary contains noNodes, measured sample_count>100 | Proxy Input/colliders with forcedprogress, not full physical ride. Collector is cleared by _summarize_telemetry L254; no cross-style contamination inferred. | C03 |
| PLAN-TELEM · L163 | OBSERVATIONAL | E3; E4 bounded interactions, not ride | Realbike/Input telemetry2styles; imposed pose/progress floor7m/s, colliders registered | Proxy forced progress; cannot call full physics route, player experienced speed or completion proof. | C03 |

### test_route_rhythm.gd

Source: [test_route_rhythm.gd](../scripts/test/test_route_rhythm.gd) — 176 lines; SHA256 в §10.

Role: mixed phase/domain/integration runner. Protected owner/path: RoadGrammar → RoadLogic validator.

Prerequisites/workload: 8seeds×3styles×1200phases;4seeds×3styles×150realchunks/repeat. Trigger: grammar/route rhythm/event changes. Completion/reporting: actual incremented checks/failures.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| RHYTHM-DET · L18 | ACTIVE_CONTRACT | E1 | Production grammar phase traces repeat/differ by seed/style | Phase declaration ≠ actual geometry presence. | — |
| RHYTHM-BUDGET · L18 | LEGACY_CONTRACT | E1 | Feature gap≤8phases;rolling12major capFLOW2/BALANCED3/TECH4; density ordering | Old chunk-phase rhythm requirement, not new regions or subjective calm. | C01 |
| RHYTHM-GEO · L114 | REGRESSION_GUARD | E1,E2 | Real150chunk perseed/style validates and retains requested event/contact; geometryrepeat | No physical bike/E7; geometry accepted does not mean perceived difficulty. | — |

### test_route_style_spacing_audit.gd

Source: [test_route_style_spacing_audit.gd](../scripts/test/test_route_style_spacing_audit.gd) — 282 lines; SHA256 в §10.

Role: observational audit + completion checks. Protected owner/path: Main/streamer/grammar branch roles.

Prerequisites/workload: 2seeds×2choices; disables background world/bike;100m override afterchoice; traces4. Requested/configured seed labels only: randomize_world_seed_on_start remains true in Main; startup resolves CLI/randomization before RoadLogic construction. Effective generated seed UNKNOWN_CURRENT without matching future manifest. Explicit CLI override takes precedence and may repeat one effective seed across nominal loop labels; it cannot prove the whole requested battery. C08. Trigger: diagnose style/spacing/cadence; impacted branch changes. Completion/reporting: summary4traces + next_fork_reached; metrics mostly observations.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| STYLE-COMPLETE · L276 | REGRESSION_GUARD | E3 | Four actual traces reach materialized next fork | Materialization not bike arrival; right fork may precede override; rejected/fallback history NOT_EXPOSED. | C08 |
| STYLE-METRIC · L27 | OBSERVATIONAL | E3 | Assigned vs observed interval/branch role/style/chunk events | 100m controlled setup not balanced production comparison; no numeric acceptance from observations. | C08,C11 |

### test_screenshot.gd

Source: [test_screenshot.gd](../scripts/test/test_screenshot.gd) — 27 lines; SHA256 в §10.

Role: capture/observational executable. Protected owner/path: scene/bike/camera viewport (no domain oracle).

Prerequisites/workload: Main single viewport snapshot atframe10;real display forPNG;fixedoutputnames/writablepath. Trigger: incident reproduction; no new mandatory gate inferred. Completion/reporting: defaultquit0 after waits;save return/reload/completionmetadata notverified.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| OLD-test_screenshot · L15 | N/A — NON_CHECK_ARTIFACT | standalone capture without result oracle; manual/external historic screenshot inspection | Main single viewport snapshot atframe10. No independent rideability/capture integrity oracle. PNG print/exit0 not verifiedartifact; no explicit headless skip/admission guard; viewport image attempted; PNG conditional and not independently validated; no automaticE7. Historical capture purpose retained as context; Authority applicability N/A because this executable has no independent result oracle. |

### test_seed_diversity_matrix.gd

Source: [test_seed_diversity_matrix.gd](../scripts/test/test_seed_diversity_matrix.gd) — 140 lines; SHA256 в §10.

Role: runner/statistical watchdog. Protected owner/path: RoadLogic → RoadPathData.

Prerequisites/workload: 10 fixed seeds ×10 chunks; checkpoint queries50..500m. Trigger: G: every world-generation change. Completion/reporting: aggregate boolean, not every printed table PASS.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| DIVERSITY · L21 | REGRESSION_GUARD | E1 | X spread≥3/15/30m at50/100/200m; ≥2 left and ≥2 right at300m | 400/500m table statuses not failure predicates; no explicit range adequacy before clamped query; terrain/forks/world diversity unproved. | C04 |

### test_session_diagnostics.gd

Source: [test_session_diagnostics.gd](../scripts/test/test_session_diagnostics.gd) — 124 lines; SHA256 в §10.

Role: runner/negative + runtime contracts. Protected owner/path: SlowCycleLogger → WorldManager/streamer.

Prerequisites/workload: 3 seeds184729/42/77777; writable --diagnostics-root; Main configured before tree; ≤55s watchdog. Trigger: logging/manifest/provenance/seed/teardown changes. Completion/reporting: actual checks/failures + session summary/manifests.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| LOG-UNIT · L48 | ACTIVE_CONTRACT | E1,E2 | Real ring boundedness, event/JSON/nonfinite serialization, I/O refusal/error state, ownership/lifecycle contract | SESSION_CLOSED means persisted lifecycle, not game quality; hard kill/crash atomic recovery not covered. | — |
| LOG-RUNTIME · L48 | REGRESSION_GUARD | E3 | Three teleported worlds, 3 checkpoints +1 branch choice each, manifests/events/source copies/live snapshots | No E4 physical replay; surfaces explicitly unchecked; warnings/leaks require external logs and remain open. | C06 |

### test_soak_run.gd

Source: [test_soak_run.gd](../scripts/test/test_soak_run.gd) — 131 lines; SHA256 в §10.

Role: teleport soak + observational metrics. Protected owner/path: Main/world streaming lifecycle.

Prerequisites/workload: 3seeds,target500chunks25kmvirtual4msteps. Requested/configured seed labels only: randomize_world_seed_on_start remains true in Main; startup resolves CLI/randomization before RoadLogic construction. Effective generated seed UNKNOWN_CURRENT without matching future manifest. Explicit CLI override takes precedence and may repeat one effective seed across nominal loop labels; it cannot prove the whole requested battery. C08. Trigger: streaming/unload/LOD/lifecycle changes after usableintegration. Completion/reporting: bounded structure predicates + summary; printedmemory notthreshold.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| SOAK-STATE · L32 | REGRESSION_GUARD | E3; E6 narrow duration/workload | Activechunks5..12,spline≤400,graph≤48,recovery displacement10..35m; YNaNINF checks at50-chunk milestones (nominal2.5km virtual progression) | Teleported pathfollowing; targetchunksvirtualbudget notphysical distance; no XZfiniteeveryframe or wholeworld. | C08 |
| SOAK-MEM · L32 | OBSERVATIONAL | E6 measurement only | OS.get_static_memory_usage peak/statistics printed | No memory failure budget; no process/GPU/ObjectDB proof; cannot turn statistic into accepted PASS criterion. | C08,C09 |

### test_sprint_4m_master.gd

Source: [test_sprint_4m_master.gd](../scripts/test/test_sprint_4m_master.gd) — 272 lines; SHA256 в §10.

Role: runner/orchestrator. Protected owner/path: player + authored tracks + RoadLogic.

Prerequisites/workload: headless; executable Godot; child resources/imports; lab T10; 5 seeds; 7 scenes. Trigger: affected player/track integration and release regression; not every docs edit. Completion/reporting: five OS.execute exit statuses + native booleans; 125 is EXPECTED budget.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| MASTER-SUB · L86 | REGRESSION_GUARD | no independent domain evidence | 5 subprocesses: diagnostics 68, track verification 6, track ride 8, lab 15, gravel 16; exit 0 credits each expected budget | Does not parse successful child's completion/actual checks; no child timeout; cannot inherit child's full capability by exit 0. | C02 |
| MASTER-AIR · L100 | REGRESSION_GUARD | E3,E4 narrow | T10 real bicycle: six predicates detach, ≥6 airborne frames, ballistic Vy, recontact, <1m step, suspension compression | One fixed lab episode, initial pose/speed; no procedural terrain or Input route. | — |
| MASTER-SEED · L196 | ACTIVE_CONTRACT | E1 | 5 fixed seeds ×15 chunks, paired production RoadLogic size/positions/tangents/curvature ≤1e-6 | Ordered sequential generation only; not all channels/branch interleaving/cross-version identity. | — |
| MASTER-SCENE · L242 | REGRESSION_GUARD | E3 | Seven scenes load/instantiate/free across frame waits; missing/unloadable scene is a failure | Scene smoke checks real; printed zero leaks has no ObjectDB/memory oracle. No E6 leak-free guarantee; external warnings decisive. | C02 |

### test_surface_audit_contract.gd

Source: [test_surface_audit_contract.gd](../scripts/test/test_surface_audit_contract.gd) — 172 lines; SHA256 в §10.

Role: runner/negative + surface integration. Protected owner/path: SurfaceAuditSupport → RoadChunk/TerrainCarver/committed MultiMesh.

Prerequisites/workload: real renderer required (not headless); local registered collider fixtures; 3 seeds×2 real arms; output root; ≤55s. Trigger: surface/foliage/fork/geometry/commit changes. Completion/reporting: incremented checks + runtime forks/arms/contacts summary.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| SURFACE-NEG · L46 | ACTIVE_CONTRACT | E1,E2; E4 local registered collision only | Empty/reversed/missing wedge/bad normals/visual-collision mismatch, contact float+.06/buried−.36 negatives, local rays up/down | Fixture physics probes; no bicycle ride. Renderer admission not sufficient proof of Vulkan E5. | — |
| SURFACE-LIVE · L95 | REGRESSION_GUARD | E2,E3 | 3 effective seeds ×2 actual committed fork arms: triangle winding/normal/collision faces and real prop transforms vs terrain contact | Renderer-dependent MultiMesh transform access; snapshot coverage, not every route, moving-bike contacts or entire-world terrain. | — |

### test_terrain_carver.gd

Source: [test_terrain_carver.gd](../scripts/test/test_terrain_carver.gd) — 327 lines; SHA256 в §10.

Role: mixed domain/integration/budget runner. Protected owner/path: TerrainCarver → RoadChunk.

Prerequisites/workload: synthetic variablewidth4..8 path; seeds184729/987654/424242/777123; bench2500samples/20meshes. Trigger: carver/profile/layers/mesh changes. Completion/reporting: actual total/passed/failed counters.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| CARVER-LAYOUT · L66 | LEGACY_CONTRACT | E1 | Exactly12vertices, edgeindices5/6 with−.035verge; ordered crosssection | Old road-centric corridor layout; mathematical ordering/anchoring still protected separately; not future terrain topology mandate. | C01 |
| CARVER-ANCHOR · L66 | ACTIVE_CONTRACT | E1 | Variablewidth edges match expected positions≤.0001 and same full context repeated boundary≤.0001 | Boundary function called twice at identical input, not independently generated adjacentchunks. | — |
| CARVER-CLASS · L164 | REGRESSION_GUARD | E1 | Real profile structure,nonzero macrodelta,signed curvature CUT response,CLIFF/CUT scoreclassification; same seed50sections12vertices≤1e-7 | No mutable mountain_weight/interleaved query coverage; danger thresholds are localclassifier policy. | — |
| CARVER-NOPOST · L218 | LEGACY_CONTRACT | E2 | No GuardPostMultiMesh on freshly created empty chunk | Weak absence oracle at constructor, old zero-post mandate; no runtime-dressing guarantee. | C01 |
| CARVER-LAYER · L242 | REGRESSION_GUARD | E2 | Built chunk terrainbody4/mountain_terrain metadata,roadbody2 | Node/layer properties only, no ray/bike. | — |
| CARVER-PERF · L273 | REGRESSION_GUARD | E6 narrow | 2500mathsamples<125ms,20SurfaceToolmeshes<45ms,20trimeshes<20ms | Synthetic extrusion loop not production fullchunk commit; no frame/GPU/lifecycle guarantee. | C09 |

### test_terrain_topology_watchdog.gd

Source: [test_terrain_topology_watchdog.gd](../scripts/test/test_terrain_topology_watchdog.gd) — 287 lines; SHA256 в §10.

Role: geometry watchdog runner. Protected owner/path: RoadLogic/TerrainCarver → RoadChunk prepared arrays.

Prerequisites/workload: 5seeds×15chunks12columns;3synthetic wedge contexts; reversed-index CW negative fixture belongs to separate SURFACE-NEG, not this runner. Trigger: terrain/fork/indices changes. Completion/reporting: nonempty coverage and violation totals; current corrected winding convention.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| TOPO-SAFE · L23 | ACTIVE_CONTRACT | E2 | Actual prepared CW fronts/normal/nondegenerate area≥.0005, no fold forwardprojection>0,lateral≤40.5,innercap≤.70R; nonempty | No realGPU/committedforkpair; area/bounds currentcontract numeric budgets; no own reversed-winding negative fixture. Separate SURFACE-NEG in test_surface_audit_contract._fixtures provides that negative evidence; not universal terrain safety. | — |
| TOPO-WEDGE · L23 | REGRESSION_GUARD | E2 | 3 synthetic fork wedge/side-mask geometry contexts | Prepared wedge only, actual runtime fork not covered by thisrow. | — |

### test_track_generator.gd

Source: [test_track_generator.gd](../scripts/test/test_track_generator.gd) — 827 lines; SHA256 в §10.

Role: scene generator/fixture. Protected owner/path: consumer contract rows above.

Prerequisites/workload: loaded by scene/helper consumer; no standalone suite. Trigger: consumer affected changes; do not launch helper as suite. Completion/reporting: N/A — no independent oracle/check.

| Artifact / locator | Authority | Consumers / роль | Limitation |
| --- | --- | --- | --- |
| NC-test_track_generator · L1 | N/A — NON_CHECK_ARTIFACT | scene generator/fixture; riding_feel_test_track.tscn;TRACK-*/master;mode select | 827lines;2800m/1401samples/56chunks/18sections,seed42;own meshes/recovery/boards;not RoadChunk world generator. |

### test_track_ride.gd

Source: [test_track_ride.gd](../scripts/test/test_track_ride.gd) — 180 lines; SHA256 в §10.

Role: physical episode runner. Protected owner/path: 4G track/BicycleController/UI/recovery.

Prerequisites/workload: actualbike tree,Input pedal/coast/brake; resets toB350/C580/L2120/J1900;recoveryInput50frames. Trigger: bike/controller/authoredsurface/recovery/HUDchanges. Completion/reporting: fail-fast predicates; eight success headings not measured8assertions.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| TRACK-RIDE · L7 | REGRESSION_GUARD | E3,E4 narrow | Pedal4s≥8kmh,coast1s≥5andless;Bpitch≥2;brakeC≤4m/s;Lgrass;J(surface2 OR rough≥.5);Input recoverydistance≤2 | Segments reached byteleport, not continuous2.8kmride; J ORpredicate; pitch/divecoastprintednotallgated. | — |
| TRACK-HUD · L7 | REGRESSION_GUARD | E3 | If HUD/label exists, textcontainsTrackSection | MissingHUD can skip withoutfailure;DebugHUDvisible; cannot E7. | C07 |

### test_track_verification.gd

Source: [test_track_verification.gd](../scripts/test/test_track_verification.gd) — 377 lines; SHA256 в §10.

Role: authored track runner. Protected owner/path: 4G generator → custom meshes/colliders/signage/recovery.

Prerequisites/workload: 4Gscene/tree/imports; defaultscene seed. Trigger: authored fixture/scene/custom recovery changes; master integration. Completion/reporting: fail-fast; fixed-labelled6/15/16 success strings not dynamically collected count.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| TRACK-GEO · L25 | REGRESSION_GUARD | E2,E3 | 4G≥1400samples,length2800±5,seam≤5mm,tangentvector≤.010,18sections and selectedgrade/radius/bumpchecks | Vector difference is not explicit.010rad angle; lastsample forciblycopiedfirst; sectionquery not fullpartitionproof. | — |
| TRACK-STRUCT · L25 | REGRESSION_GUARD | E2,E3 | 56chunks,layers selected0/42,sign18/boards5,recoverydistance≤1.5 | Checks selectedchunks not everycollider/roadgrass; no physics ride/E6. | — |

### test_virtual_rider_bot.gd

Source: [test_virtual_rider_bot.gd](../scripts/test/test_virtual_rider_bot.gd) — 183 lines; SHA256 в §10.

Role: runner/physical bot. Protected owner/path: BicycleController → WorldManager → ChunkStreamer.

Prerequisites/workload: Main; seed184729 before tree; randomization disabled; Input actions; registered collision; ≤2500 physics frames. Trigger: G: every world-generation change. Completion/reporting: boolean failure + ride summary; gate NOT waived by proposal.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| RIDER · L27 | REGRESSION_GUARD | E3,E4 | Real Input-driven pedal/steer; target500m but pass≥350m; XZ distance≤2.2; absolute Y≥−30; roll≥3° events density≥4/km | Distance is active branch local s, can reset; MIN_SPEED unused; not both routes/all seeds/full500m; absolute Y confounds downhill elevation. | C03 |

### test_winding_road.gd

Source: [test_winding_road.gd](../scripts/test/test_winding_road.gd) — 298 lines; SHA256 в §10.

Role: mixed geometry/statistical runner. Protected owner/path: RoadLogic winding builders → validator.

Prerequisites/workload: seed74192350chunks;5×500; per-metric fixed seeds and15 terminal cases. Trigger: winding/road geometry changes. Completion/reporting: named7groups boolean; nonempty holes documented.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| WIND-DET · L75 | ACTIVE_CONTRACT | E1 | Repeat full selected generated centerline | Same call order only. | — |
| WIND-GEO · L105 | REGRESSION_GUARD | E1,E2 | 5×500segment validation, positive-curvature radius≥18.99m | No independent seam validator; dk/ds.003 printed, not independently gated; signed negative curve blind spot. | C10 |
| WIND-METRIC · L147 | REGRESSION_GUARD | E1 | Tortuosity88123/200chunks nonempty avg≥1.03;99341/300 curvature ratio≥3;62145/200 straight gap≤35m;19482/250 v²κ≤5.2 | Tortuosity avg not everychunk; ratio uses .001 fallback for absent cruise; straight/lateral subsets can be empty; straight header12m differs actual35m; analytical no actual ride. | C04 |
| WIND-FORK · L270 | REGRESSION_GUARD | E1 | 15seeds terminal curvature≤.005 before fork | Not abs curvature; no explicit proof WINDING event present in each case. | — |

### test_world_session_seed.gd

Source: [test_world_session_seed.gd](../scripts/test/test_world_session_seed.gd) — 50 lines; SHA256 в §10.

Role: domain/seed lifecycle runner. Protected owner/path: WorldManager._resolve_session_seed.

Prerequisites/workload: instantiateMain without addingtree;CLIcommand/userargs/fixed/randomized cases. Trigger: startup/seed/CLI/capture/replay changes. Completion/reporting: actual7_check calls, no generatedworld.

| ID / locator | Approved Authority | Capability | Actual check/oracle | Blind spots / reporting gap | Conflict |
| --- | --- | --- | --- | --- | --- |
| SESSION-SEED · L11 | ACTIVE_CONTRACT | E1,E2 | Seven checks: fixed configured default; positive signed32 fresh seed; distinct consecutivefresh; user/command precedence; repeated explicit seed; valid seed0; normal-scene randomize flag | Malformed/invalid seed parsing is not checked here; random distinctness can collide; no geometry/foliage or runtime_effectiveseed withoutworldinit. | — |

## 8. Checkpoint B: decisions, conflicts и unknowns

| Approved category | Check rows | Accepted |
| --- | --- | --- |
| REGRESSION_GUARD | 125 | 125 |
| ACTIVE_CONTRACT | 41 | 41 |
| OBSERVATIONAL | 12 | 12 |
| LEGACY_CONTRACT | 16 | 16 |
| HISTORICAL | 10 | 10 |

| ID | Status | Conflict/fact | Source | Resolution owner | Concrete decision / boundary |
| --- | --- | --- | --- | --- | --- |
| C01 | CATEGORY_ACCEPTED_BY_B | 16legacy rows: graphDAG,no-post,oldprofile/pacing/layout/style | Blueprint/Master/target architecture + oldsource expectations | Human migration/implementation owner | Human B accepts all16legacy rows and stable siblings; target RegionRouteGraph/region-first must not inherit conflicting legacy expectations; no currentfailure waiver, no permission to mutate. Separate future transition needed. |
| C02 | FACT_ACKNOWLEDGED_BY_B | master expectedbudgets; fixed countlabels; geometry_profiles16; leakclaims; T6constanttrue | MASTER-SUB/MASTER-SCENE/PLAN-GEO/AIR-EMP-T6/LAB/GRAVEL cleanup | verification owner | Record completion/assertion metricgap. No Q1 work now. |
| C03 | FACT_ACKNOWLEDGED_BY_B | ride vs teleport/forcedprogress,localdistance/partialroute | RIDER/DYNAMIC/ROUTE/PLAN-TELEM/MOUNTAIN | physics/world owner | Accept bounded capabilities. No fullroute/physicalreplay assertion. |
| C04 | FACT_ACKNOWLEDGED_BY_B | vacuous subsets/statisticalstale labels/no terrain measurement | DIVERSITY/MONOTONY/WIND/BIOME-FREQ | world/test owner | Retain mandatory/currentbudgets; missing coverageexplicit; unknown alternativebudgetprovenance not inferred. |
| C05 | FACT_ACKNOWLEDGED_BY_B | helper headlessrefusal ≠ explicitVulkandriver guard | CAP-VIS/CAP-SEED/helper | capture owner | E5conditional on actualdriver/savedreadPNG/review; no freshE5. |
| C06 | FACT_ACKNOWLEDGED_BY_B | geometryreplay,hash scopeexcludes tests,ObjectDB6 | REPLAY/LOG+raw historicalwarning | logging/verification owner | No physicsreplay/fullcleangate; keep toolhash separately. |
| C07 | CATEGORY_ACCEPTED_BY_B | weak source/local/config/vacuous oracle vs stable intendedinvariant;4reference subrows+BRANCH-SEED OBSERVATIONAL proposals | diagnostics rows,GRAPH-PATH/FORK-MASK/GRAMMAR/FIX-* | human/test owner | Human B accepts retainedregression and separated reference-onlyobservation categories without upgrading weak/local/text/config evidence. No deletion/repair; insufficientproductionevidence remains explicit. |
| C08 | FACT_ACKNOWLEDGED_BY_B | branch/soak/clearance/style runners assignrequestedseed without disabling Main randomization | BRANCH-FSM +SOAK/CLEAR/STYLE contexts and subrows +WorldManager._resolve_session_seed | world seed owner | Effective generated seed UNKNOWN_CURRENT without matching actualrun manifest; startup CLI wins and may repeat the same effective seed across requested labels. No manufactured controlled-battery/deterministic claim. |
| C09 | FACT_ACKNOWLEDGED_BY_B | asserted vs printedtiming,historical variance,staticmemory/leaks | perf rows and rawbranchfailures | performance/test owner | Retain thresholds; no observationalbudgetwaiver; no wholeframe/GPU promise. |
| C10 | CATEGORY_ACCEPTED / OPEN_REQUIREMENT_CONFLICT | radius18contract/19governance,actualtolerances vsprintedgrade/visibility/landing limits | RoadGenerationContract/validator/worldAGENTS +LOGIC/WIND/FORK/VERGE | human/world/test owner | Record competing authority; Q0 does not resolve numericcontract/change assertions. Human B accepts the as-is categories only; numeric requirements remain OPEN. No tests/thresholds/AGENTS/contracts/production values are resolved or changed. |
| C11 | FACT_ACKNOWLEDGED_BY_B | centerlabel indexes−.5ray; candidatesnotgate;controlledspacing not fairdefault | CLEAR-MEASURE/STYLE-METRIC +source | audit/world owner | Accept limitedobservations; human crossingcomplaint staysopen. |
| C12 | CATEGORY_ACCEPTED / OPEN_STALE_ORACLE | macro terrain test8verts/index3,4 vsproduction12/index5,6/−.035 | MACRO-TERR L95;TerrainCarver.compute_cross_section L173/276 | human/test +surface owner | Human B accepts REGRESSION_GUARD. Expected8 vertices/indices3,4 vsproduction12/indices5,6/currentverge remains OPEN; no repair/downgrade/failure waiver. |
| C13 | FACT_ACKNOWLEDGED_BY_B | massif finite/determinism tests miss valley C0 abs_dx85 | MASSIF +get_elevation boundaryformula/currentstate | terrain/math owner | Stable fieldcontract remainsACTIVE; boundarycoverage missing; no R0 repair. |
| C14 | CATEGORY_ACCEPTED_BY_B | 10historicalcheckrows vs30external/noncheck artifacts;7uncheckedoldcaptures N/A | external verifiers/manualprotocols,script oracles and D0 historicalreports | human/category reviewer | Human B accepts all10historical checks and N/Aapplicability (not a sixth category). No historicPASS carriedforward/currentgate removed. |

**Checkpoint B decision:** all 204 categories accepted; pending authority assignments=0. C01/C07/C14 accepted, C10 category-only and C12 retained REGRESSION_GUARD with OPEN requirements/stale oracle as above. C02–C06/C08/C09/C11/C13 factual limitations acknowledged without repair or waiver. Conflict tags annotate affected check rows; these are not separate human approvals or automatically newly proven bugs. C08 additionally discloses SOAK/CLEAR/STYLE effective-seed limitations (§14). C10/C12 accurately recorded open state does not block documentary Q0 completion after VERIFY PASS and independent REVIEW PASS.

Conflict-resolution process: записать row/owner/currentoracle+requirement+target requirement+source/evidence → определить fact/unknown/authority conflict → human accepts concrete rowgroup or leavespending → record decision/date/version/digest → only explicitly accepted assignments accepted. Changed content gets new digest; no inferredapproval. Test mutation/retirement/threshold/gate conflict требует **отдельного approved task**, внеQ0. Existing runtimefailure remains failure for impacted oldowner; newtarget invariant cannot be decided by oldDAG. No automatic downgrade on inconvenient result. Pending requirement not guessed from filename/historicalsuccess.

Unknowns не скрыты: current runtime results/errors/leaks, effective seeds in randomizing scripts, historicalbudget approval provenance where absent, true physicalwhole-route/physicsreplay/multibranch scheduling/allterrainvisualcoverage, current E7/humanacceptance, hardware-specific budget validity, future runtime reviewer identities. Q1/Q2 may later measure completion/baseline only after separately approved scope; this map authorizes neither.

## 9. Duplicates, consumers, orphan checks и negative counterexamples

Master child edges exactly: diagnostics,track_verification,track_ride,riding_lab,gravel_loop. Native masterAir/seed/scenes separate. All other --script entry points independently invocable; absence from master does not retire them. Generators connected to real menu scenes, helper imports connected to capture/surface consumers. No proven orphan requiring retirement. Missing StageB filenames are historical unresolved references, not files to delete. External backups/current snapshots are indexed as artifacts, not double-counted suites.

Semantic overlaps: master nativeAir vs AIR-EMP/AIR-CAL/DYNAMIC-DROP (differentphysicalfixtures/predicates); diagnostics localweights vs FIX-WEIGHTS(actualblend); ROAD-GEN/GRAMMAR-SAFE/WIND-GEO (samevalidator with differentworkloads, some noindependentseams); EVENT-PIPE/EVENT-SEAM/FORK-ARM/TOPO/SURFACE-LIVE (differentprepared/runtime/negative/visualscope); scenefixtures geometryrunners vs episode rides; LOG/REREPLAY vs capturecheckpoint signatures (geometryonly); seedrepeat/profile/order independence (differentowners/identities). These are overlap candidates, not equivalence proofs. No tool removed or consolidated.

| Expected rejection reason | Documentary counterexample traced | Audit interpretation |
| --- | --- | --- |
| EXPECTED_NOT_MEASURED | MASTER-SUB credits expected counts onexit0 | Reject actual125 assertion/completion claim; realnative checksseparate. |
| PARTIAL_ROUTE | RIDER350..499m target500 | Codepass unchanged; full500acceptance unproved. |
| BRANCH_LOCAL_DISTANCE | RIDERcur_s branchlocal | Reject globalphysicaldistance inference. |
| PROXY_NOT_CONTINUOUS_RIDE | DYNAMIC-FORK/ROUTE/PLAN-TELEM | Preserve boundedintegration/rays; reject physicalwholeride. |
| GEOMETRY_ONLY_REPLAY | REPLAY/LOG | Reject Input/physicsreplay. |
| ORACLE_PATH_GAP | DIAG3/38/62,BRANCH-SEED,FIX-WEIGHTS | Local/text proof notproductionbehavior; stableinvariant retained. |
| VACUOUS_OR_UNMEASURED_COVERAGE | MONOTONYno mountain,WINDempty,FORK-MASKempty,optionalDIAG | Reject fullcoverage; distinguish corrected nonemptywatchdogs. |
| NO_RUNNER_ORACLE | 5helpers/generators +7uncheckedcaptures | N/Aapplicability; consumercheckrows carry categories. |
| VULKAN_OR_ARTIFACT_EVIDENCE_MISSING | headless/driverunknown/uncheckedPNG | E5conditional; no current E5PASS. |
| FIXTURE_SCOPE_ONLY | CAP-CULL actual_fork=false | Reject fullrealfork/worldvisualclaim. |
| STALE_RUN_IDENTITY | oldSprint/WORLD PASS | No transfer to Q0HEAD/diff. |
| STALE_SOURCE_FACT | C03/C04 currentCW/missingground | Reject old coveragebodydefect as current unchangedfact. |
| OWNER_ARCHITECTURE_CONFLICT | GRAPH-DAG vsRegionRouteGraph loops | Legacyoldowner protected; targetnotrewritten. |
| SURVIVING_INVARIANT_LOST | C0/C1/finite/clone/weights | Reject age-basedretirement; stable siblingrows retained. |
| UNAPPROVED_GATE_CHANGE | Gwatchdogs acceptedcategories | All4worldgen gates+errors/leaks retained. |
| CONSUMER_OR_ORACLE_COMPARISON_MISSING | notinmaster,near-duplicates | No orphan/retirement inference; trace documented. |
| THRESHOLD_SOURCE_MISMATCH | LOGIC17.5/WIND35/GRAMMAR.08/VERGE.015 | Assertedpredicate recorded; print/commentnotgate. |
| METRIC_OR_COMPLETION_GAP | staticmem/scenequeue_free/expectedprofiles | RejectGPU/hitch/zero-leaks/measuredcompletion claim. |
| NEGATIVE_REASON_NOT_PROVEN | ROADT10..14 notis_valid vsT09exact | No claim each specificfailurecause asserted. |
| INDEPENDENCE_OR_APPROVAL_MISSING | author session;digest-bound approvedcategories | Author cannot self-certify independent review. All204 assignments accepted by exact digest-bound human B; independent review is a separate completion gate recorded in the task record. |

Author's documentary counterexample checks:20/20 traced and represented; **не новые tests/fixtures и не engine negative runs**. Formal slow-cycle-verify и independent slow-cycle-review verdicts/identities находятся в task record через root plan slot; эти author checks не заменяют reports и не являются self-certifiedPASS. Reviewer independently recounts sourceindex/rows/roles/claims, reads all assignments' sources (not just sample), checks named conflictgroups, thresholds/consumer paths/gates and20counterexamples. Approval B не заменяет independent review.

## 10. Complete scripts/test source index

Raw-byte SHA256, linecount and consumer membership are documentary identity, не runtime result. Check-container authority находится только в §7 subrows. Source hashes не normalized for line endings.

| Source | Lines | Role / applicability | Rows | SHA256 |
| --- | --- | --- | --- | --- |
| [AGENTS.md](../scripts/test/AGENTS.md) | 11 | metadata/governance; N/A — NON_CHECK_ARTIFACT | non-check | 5762e5360e3e620f6c61d4c73f03872dc5981a1bccead50d741881c8eaeb022f |
| [capture_audit_support.gd](../scripts/test/capture_audit_support.gd) | 456 | helper; N/A — NON_CHECK_ARTIFACT | NC-capture_audit_support | 45b9fe6e6ea939e37d5bed4f3c6939e2aec3af3aa4996009b9d4f14bf21a0242 |
| [capture_screenshot_ride.gd](../scripts/test/capture_screenshot_ride.gd) | 62 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-capture_screenshot_ride | 3a77bf42e02bef3a68c1448f9739e229d128d8c26938cea04e32b6d1e5a76802 |
| [capture_screenshot.gd](../scripts/test/capture_screenshot.gd) | 16 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-capture_screenshot | 060dc397ce345211f04bef4e80a60ebaf0bc3d1686a7878689e3b0a0fb900b46 |
| [capture_screenshot.gd.uid](../scripts/test/capture_screenshot.gd.uid) | 1 | metadata/governance; N/A — NON_CHECK_ARTIFACT | non-check | 6af700c9e779af1a29412afb90d4ee0871b03edc88108a255c81ad882d0ffd34 |
| [capture_seed_audit.gd](../scripts/test/capture_seed_audit.gd) | 69 | capture/check runner; see approved check subrows | CAP-SEED | 447fc9b984dacf56005be9823b1c1e6b428e6e5710f274f180df481d8d4f78a2 |
| [capture_sprint3a.gd](../scripts/test/capture_sprint3a.gd) | 40 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-capture_sprint3a | a729a8d5a41f32636d69d592059e249a00f3b4741414c9388496ed9f11480edd |
| [capture_sprint3c.gd](../scripts/test/capture_sprint3c.gd) | 40 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-capture_sprint3c | 73badc364bac4f25080b257ac13da83dbe579ed88c7796a41b572378098cee00 |
| [capture_surface_culling_audit.gd](../scripts/test/capture_surface_culling_audit.gd) | 89 | capture/check runner; see approved check subrows | CAP-CULL | 60a023d772cf116b7eff9f0b8a991a57bade362b54acacbc5a3eacadf2e673ce |
| [capture_third_person.gd](../scripts/test/capture_third_person.gd) | 22 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-capture_third_person | 755400e7c84164bea1d1abeb1848aabdb21ebcc25d217ce4708024125842e8e4 |
| [capture_third_person.gd.uid](../scripts/test/capture_third_person.gd.uid) | 1 | metadata/governance; N/A — NON_CHECK_ARTIFACT | non-check | 9c5d6d99796c7de066bcf55c687ca459b5792d18e68903b77295b3cb196e92f3 |
| [capture_visual_audit.gd](../scripts/test/capture_visual_audit.gd) | 46 | capture/check runner; see approved check subrows | CAP-VIS | 2e8e32dfddd8df6ab93a6bee6c25dde7287ffbe5f280c79be531eb1e077ca75a |
| [gravel_loop_generator.gd](../scripts/test/gravel_loop_generator.gd) | 794 | scene generator/fixture; N/A — NON_CHECK_ARTIFACT | NC-gravel_loop_generator | ad2a6857f755183f594ff17ea4f329866279e0299618bf49b04ffead0a7db18b |
| [replay_session_diagnostic.gd](../scripts/test/replay_session_diagnostic.gd) | 176 | runner/geometry replay; see approved check subrows | REPLAY | 51f1b5cbf24a6d93c64d3569f58ded67ada126831530a6135d940dfd9ec953b6 |
| [riding_lab_generator.gd](../scripts/test/riding_lab_generator.gd) | 863 | scene generator/fixture; N/A — NON_CHECK_ARTIFACT | NC-riding_lab_generator | a2df0157ade34823448d9cf0705a7409edb5899cef19345c244d2a0ecdb80784 |
| [surface_audit_support.gd](../scripts/test/surface_audit_support.gd) | 82 | support module; N/A — NON_CHECK_ARTIFACT | NC-surface_audit_support | 795387d443ae31239d5b07c95a69b0326dca8818b150491cb2f7f541838da54c |
| [test_airborne_calibration_gate.gd](../scripts/test/test_airborne_calibration_gate.gd) | 145 | runner/physical calibration; see approved check subrows | AIR-CAL | 79e4b4dfa35947cda021e156239df3569bc65ca650b3fb19bbabd7f8f4d2c3fe |
| [test_airborne_empirical_gate.gd](../scripts/test/test_airborne_empirical_gate.gd) | 262 | runner/physical calibration; see approved check subrows | AIR-EMP-T10, AIR-EMP-T6, AIR-EMP-SYN | 2e212b3a8b0d1ef6aee73b1044d7b47aa9b707e28b0b3420c8aa0f488e4b99b4 |
| [test_branch_streaming.gd](../scripts/test/test_branch_streaming.gd) | 341 | mixed runner; see approved check subrows | BRANCH-MESH, BRANCH-NOPOST, BRANCH-SEED, BRANCH-FSM, BRANCH-DAG, BRANCH-DRESS, BRANCH-NOPOST2, BRANCH-PERF | d57c2c03c0140e0795d1a08743eabaeb76db00c7ff004ab6eac99fa4968e2860 |
| [test_capture_audit_contract.gd](../scripts/test/test_capture_audit_contract.gd) | 128 | runner/negative contract; see approved check subrows | CAP-CONTRACT | 89cef5b32362cac7c50ca2db53a38515281c3959b8f2d1370e81054423faced2 |
| [test_diagnostics.gd](../scripts/test/test_diagnostics.gd) | 2109 | mixed runner / 68 numbered groups; see approved check subrows | DIAG-01, DIAG-02, DIAG-03, DIAG-04, DIAG-05, DIAG-06, DIAG-07, DIAG-08, DIAG-09, DIAG-10, DIAG-11, DIAG-12, DIAG-13, DIAG-14, DIAG-15, DIAG-16, DIAG-17, DIAG-18, DIAG-19, DIAG-20, DIAG-21, DIAG-22, DIAG-23, DIAG-24, DIAG-25, DIAG-26, DIAG-27, DIAG-28, DIAG-29, DIAG-30, DIAG-31, DIAG-32, DIAG-33, DIAG-34, DIAG-35, DIAG-36, DIAG-37, DIAG-38, DIAG-39, DIAG-40, DIAG-41, DIAG-42, DIAG-43, DIAG-44, DIAG-45, DIAG-46, DIAG-47, DIAG-48, DIAG-49, DIAG-50, DIAG-51, DIAG-52, DIAG-53, DIAG-54, DIAG-55, DIAG-56, DIAG-57, DIAG-58, DIAG-59, DIAG-60, DIAG-61, DIAG-62, DIAG-63, DIAG-64, DIAG-65, DIAG-66, DIAG-67, DIAG-68, DIAG-49-REF, DIAG-53-REF, DIAG-55-REF, DIAG-59-REF | c3117ae8844efe285e26a6eff24a80fc280f3c848f106b41f50d44b09ee27c88 |
| [test_dynamic_rideability.gd](../scripts/test/test_dynamic_rideability.gd) | 331 | mixed physical runner + teleport integration; see approved check subrows | DYNAMIC-CREST, DYNAMIC-DROP, DYNAMIC-TURN, DYNAMIC-FORK | 65b86641d862bbbe524e4897235c93e5d9d900e9853ee855ae52081968e97404 |
| [test_foliage_contact_watchdog.gd](../scripts/test/test_foliage_contact_watchdog.gd) | 142 | surface/contact watchdog runner; see approved check subrows | FOLIAGE-CONTACT | 61205dff643e6ff5d2f612e43d34c9d49ac991012b91be240a2a6b6a339a41f6 |
| [test_fork_biome_pacing.gd](../scripts/test/test_fork_biome_pacing.gd) | 271 | mixed domain/integration runner; see approved check subrows | BIOME-PACE, BIOME-FREQ, BIOME-WIRE | 15e2e20631c48b71603da53c52219888aa541f37f9ac9ba125afb4eb35da8fff |
| [test_fork_corridor_preview.gd](../scripts/test/test_fork_corridor_preview.gd) | 63 | domain/integration runner; see approved check subrows | PREVIEW | ab68123b3e16b4a4b2d9a151c800dd970353c8a5eea265b64c7b0904f1e6c4e2 |
| [test_fork_decision.gd](../scripts/test/test_fork_decision.gd) | 395 | domain/integration runner; see approved check subrows | FORK-WIDTH, FORK-SIGN, FORK-FSM | 7f3470fa60a648e64448d805a6ee373ed7f92fe59e0ac0f291726e399a8df697 |
| [test_fork_geometry_verification.gd](../scripts/test/test_fork_geometry_verification.gd) | 193 | integration runner; see approved check subrows | FORK-APPROACH, FORK-ARM, FORK-MASK | d2c6fcd123f7842d017a27d6812288fb77d2b9e7825c4a4c20764fedd952a4e3 |
| [test_fork_pacing_planner.gd](../scripts/test/test_fork_pacing_planner.gd) | 90 | mixed domain runner; see approved check subrows | PACING-SAFE, PACING-BAND, PACING-RING | d2bacb289f18f96780d4f8c40835dd6fbf2bbd26ba5f6e94fffd0e36509a05e2 |
| [test_fork_site_planner.gd](../scripts/test/test_fork_site_planner.gd) | 234 | mixed unit/integration runner; see approved check subrows | SITE-UNIT, SITE-SEED, SITE-FALLBACK | c684ed8c5db1df906414f333c2340398f9584738b2a21e97f34ddb697b7c67f3 |
| [test_gravel_loop.gd](../scripts/test/test_gravel_loop.gd) | 263 | authored track runner; see approved check subrows | GRAVEL-GEO, GRAVEL-STRUCT | a0d0591f1ad0ad0fe6aa738ddc29a3738cab219b64c9833115f4c02f62cc75ec |
| [test_macro_profile_road_integration.gd](../scripts/test/test_macro_profile_road_integration.gd) | 120 | integration runner; see approved check subrows | MACRO-ROAD, MACRO-TERR | a6cb5618cdf41992ac609251f8b313b56e4084017c73c204dd30de7d1aebdf60 |
| [test_mode_select_gamepad.gd](../scripts/test/test_mode_select_gamepad.gd) | 73 | runtime UI runner; see approved check subrows | MENU-PAD | 00495e51497e5ea241f873bb5e35cda9b91f8778973dcdd90f373bcdb043bd3a |
| [test_monotony_profiler.gd](../scripts/test/test_monotony_profiler.gd) | 123 | runner/statistical watchdog; see approved check subrows | MONOTONY | 0ee3ffc08cba12f9c3cb1600c402e2dda75c3e4265d36052b3b2fa8ca6530afa |
| [test_mountain_massif_field.gd](../scripts/test/test_mountain_massif_field.gd) | 81 | domain runner; see approved check subrows | MASSIF | d338d3cf17fbc7eb6c9cd856f8e8c5f3b14a42509f529e547c2f5e2849f2149e |
| [test_mountain_profile.gd](../scripts/test/test_mountain_profile.gd) | 187 | mixed domain runner; see approved check subrows | PROFILE-DET, PROFILE-DESCENT, PROFILE-ZONES | bf9dc60925818a81227f9ce6e35d34bac5d40de3f05c1f37391da8d49c334b85 |
| [test_mountain_validation.gd](../scripts/test/test_mountain_validation.gd) | 200 | teleport stress/budget runner; see approved check subrows | MOUNTAIN-STATE, MOUNTAIN-RESOURCE | 99ba678444e177f43422dda830632e3a9d9bd4daeea2bd1cc7d9ee3cb562dbb3 |
| [test_mtb_event_geometry_catalog.gd](../scripts/test/test_mtb_event_geometry_catalog.gd) | 143 | domain/integration runner; see approved check subrows | EVENT-CAT | 283395f55b37fd1fb7544a3ff1d4a6250d3499337b36bf44a92b3729b10e6d4b |
| [test_mtb_event_pipeline.gd](../scripts/test/test_mtb_event_pipeline.gd) | 141 | integration runner; see approved check subrows | EVENT-PIPE | 0885b19b0259e77f60036e58badbd2cc8dae8294fd039678c933cc337eb6eee8 |
| [test_procedural_run.gd](../scripts/test/test_procedural_run.gd) | 87 | physical episode runner + unchecked capture; see approved check subrows | PROC-RIDE | 786a14dbf28f6fb3efa59d2533159bc579f3853270b76f4189681f6ff129591e |
| [test_review_fix.gd](../scripts/test/test_review_fix.gd) | 144 | regression/negative runner; see approved check subrows | FIX-GRAPH, FIX-FOLIAGE, FIX-VALID, FIX-WEIGHTS | 07309f185fb2b57bab0c84bc27211c124e9ee5fcf74a2e0859eb8df3d58308d9 |
| [test_ride.gd](../scripts/test/test_ride.gd) | 32 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-test_ride | 9caaa7fed638f3d2472ef6b384384f3355cf40d45218cb034f3779c25a47283b |
| [test_ride.gd.uid](../scripts/test/test_ride.gd.uid) | 1 | metadata/governance; N/A — NON_CHECK_ARTIFACT | non-check | b24a1c4b41e251868b2a321f8d60c64522da30d6dcbbd97ba81056eabad182e5 |
| [test_riding_lab.gd](../scripts/test/test_riding_lab.gd) | 288 | authored track runner; see approved check subrows | LAB-GEO, LAB-STRUCT | 1be60d3d60b88dd602c97488e6a5fd4320305970e53ac3c952181520fe52fe22 |
| [test_road_clearance_watchdog.gd](../scripts/test/test_road_clearance_watchdog.gd) | 131 | geometry watchdog runner; see approved check subrows | PROP-CLEAR | af2d40fe06b3f09317c25c16cfdce4bdf6787f5863e61613239cd66e703e3425 |
| [test_road_contract.gd](../scripts/test/test_road_contract.gd) | 375 | domain + benchmark runner; see approved check subrows | ROAD-VALID, ROAD-GEN, ROAD-PERF | 027bc0d1cbbc6a3d50129f49accfbec533905644842e8aab95d74af8b922ac8f |
| [test_road_event_chunk_seams.gd](../scripts/test/test_road_event_chunk_seams.gd) | 215 | integration runner; see approved check subrows | EVENT-SEAM, EVENT-LAYOUT | 014369006590ab0741f243256f2797e92961da91ecba3055c14fca5520f9172a |
| [test_road_grammar.gd](../scripts/test/test_road_grammar.gd) | 278 | domain/budget runner; see approved check subrows | GRAMMAR-DET, GRAMMAR-SAFE, GRAMMAR-PERF, GRAMMAR-BIOME | bac48dc746fd72f51bc50f32536879b485521e0f1813965a8ec56f6268786e98 |
| [test_road_graph.gd](../scripts/test/test_road_graph.gd) | 354 | mixed domain/benchmark runner; see approved check subrows | GRAPH-KIN, GRAPH-PATH, GRAPH-TOPO, GRAPH-DAG, GRAPH-FORK, GRAPH-PERF | 522af6d119ac5484eb86b516492ba220c2d7efbbb809f4df6e1272f1ee433bca |
| [test_road_logic.gd](../scripts/test/test_road_logic.gd) | 91 | domain runner; see approved check subrows | LOGIC-DET, LOGIC-LIMIT | 41a94f2e87786f69f3a7f9134a040e1b66bc873a5983d4fcf07c889e6d426bdd |
| [test_road_verge_seam_watchdog.gd](../scripts/test/test_road_verge_seam_watchdog.gd) | 110 | geometry watchdog runner; see approved check subrows | VERGE | f123bd5bbaf801b32612d17d73b089e3c6b5dbbd1042554d34197f51b749c2ae |
| [test_route_branch_integration.gd](../scripts/test/test_route_branch_integration.gd) | 347 | runner/teleport integration; see approved check subrows | ROUTE-LOCK, ROUTE-SPACE | 2534d298949deeb6fd13823cf11b446e5bb2cc96b7062c993e50071bcc924384 |
| [test_route_clearance_audit.gd](../scripts/test/test_route_clearance_audit.gd) | 204 | observational audit + traversal checks; see approved check subrows | CLEAR-TRAVERSE, CLEAR-MEASURE | 13ccb6a3ca19713a47b6d797e0314ca884f773f16151040459c881c62a679111 |
| [test_route_intent.gd](../scripts/test/test_route_intent.gd) | 153 | mixed domain/integration runner; see approved check subrows | INTENT-DET, INTENT-STYLE | 0aa53764d0b534ac309fe44bb2ed7733ffe5b6ef0c2062e5f201d6e04ca7a9e0 |
| [test_route_plan_contract.gd](../scripts/test/test_route_plan_contract.gd) | 283 | mixed domain runner + controlled telemetry audit; see approved check subrows | PLAN-NEG, PLAN-GEO, PLAN-TELEM-DATA, PLAN-TELEM | 07f20b5edbaafe9ce0da0eba474a1ac0b040fe23b9f73eab263f6cc15f73a886 |
| [test_route_rhythm.gd](../scripts/test/test_route_rhythm.gd) | 176 | mixed phase/domain/integration runner; see approved check subrows | RHYTHM-DET, RHYTHM-BUDGET, RHYTHM-GEO | 1a7168bbdf8803bb404b45988af8f1cddb54b742e2afd9246cdd420ee0343397 |
| [test_route_style_spacing_audit.gd](../scripts/test/test_route_style_spacing_audit.gd) | 282 | observational audit + completion checks; see approved check subrows | STYLE-COMPLETE, STYLE-METRIC | 82941889d5de89783793e0f9bf69e382e55cf97bce2823ab5a3ad28195e976b9 |
| [test_screenshot.gd](../scripts/test/test_screenshot.gd) | 27 | capture/observational executable; N/A — NON_CHECK_ARTIFACT | OLD-test_screenshot | fa87de7835004307d0b2dbaaac52eea18a2a22062189d24031a3e25e980669a3 |
| [test_seed_diversity_matrix.gd](../scripts/test/test_seed_diversity_matrix.gd) | 140 | runner/statistical watchdog; see approved check subrows | DIVERSITY | 6358c5a885a80de73adac690c09ff5fed792a54a8e999fa18b70a9d4d20c5085 |
| [test_session_diagnostics.gd](../scripts/test/test_session_diagnostics.gd) | 124 | runner/negative + runtime contracts; see approved check subrows | LOG-UNIT, LOG-RUNTIME | 2033d62069f890d49d438bd3711c58d567aa3a41d5e9e4503ca9814d87b90904 |
| [test_soak_run.gd](../scripts/test/test_soak_run.gd) | 131 | teleport soak + observational metrics; see approved check subrows | SOAK-STATE, SOAK-MEM | e0630f9c8ae95b2f58d24c34fc97da8566c73f84baeb9afcc9cf06b9787b373a |
| [test_sprint_4m_master.gd](../scripts/test/test_sprint_4m_master.gd) | 272 | runner/orchestrator; see approved check subrows | MASTER-SUB, MASTER-AIR, MASTER-SEED, MASTER-SCENE | fa1de56ae222f60e552e984f6bac34c061da1c0ba65c58abee20ec7466d2d934 |
| [test_surface_audit_contract.gd](../scripts/test/test_surface_audit_contract.gd) | 172 | runner/negative + surface integration; see approved check subrows | SURFACE-NEG, SURFACE-LIVE | 0d3e84d174deedaa43ba500f614c94dbb9407c2c06f95b5db2b745307ab26ec6 |
| [test_terrain_carver.gd](../scripts/test/test_terrain_carver.gd) | 327 | mixed domain/integration/budget runner; see approved check subrows | CARVER-LAYOUT, CARVER-ANCHOR, CARVER-CLASS, CARVER-NOPOST, CARVER-LAYER, CARVER-PERF | c89e35e0e5c41dfd640192439ece560e060660eb94ba8d33aac409ae82e3d443 |
| [test_terrain_topology_watchdog.gd](../scripts/test/test_terrain_topology_watchdog.gd) | 287 | geometry watchdog runner; see approved check subrows | TOPO-SAFE, TOPO-WEDGE | 5747be6a7383db038d42e421e92ee4508e262af16aad9010ba824ee459bc56aa |
| [test_track_generator.gd](../scripts/test/test_track_generator.gd) | 827 | scene generator/fixture; N/A — NON_CHECK_ARTIFACT | NC-test_track_generator | b2f8c205be8ff86dee0ac25b966f65ed8b632364877fbc4b861060c1f05ef3d8 |
| [test_track_ride.gd](../scripts/test/test_track_ride.gd) | 180 | physical episode runner; see approved check subrows | TRACK-RIDE, TRACK-HUD | 8028e2a9b27480c33320566eeebc2da027f4531ea3299f6d5401bf6c2272be4a |
| [test_track_verification.gd](../scripts/test/test_track_verification.gd) | 377 | authored track runner; see approved check subrows | TRACK-GEO, TRACK-STRUCT | 6c8f7aa5dea71ec1d790815729acb04711ca07e819f6a58e408a7c615cffb82d |
| [test_virtual_rider_bot.gd](../scripts/test/test_virtual_rider_bot.gd) | 183 | runner/physical bot; see approved check subrows | RIDER | ad798cf76d33b380ae164940a810d6fa6ea3b5d44d4621cf78619540a074a89f |
| [test_winding_road.gd](../scripts/test/test_winding_road.gd) | 298 | mixed geometry/statistical runner; see approved check subrows | WIND-DET, WIND-GEO, WIND-METRIC, WIND-FORK | 6770d91ffd5d1c5cba063ba04a6a9f9335f3a9d5ef28498ed1b0cd84438679b5 |
| [test_world_session_seed.gd](../scripts/test/test_world_session_seed.gd) | 50 | domain/seed lifecycle runner; see approved check subrows | SESSION-SEED | 01db54b59af21c67207d21f5077cc75cf5f2a3d321774e473b7dfa89ab60b9f9 |

## 11. Dependency/evidence source identity index

These are the audited pre-promotion source snapshot hashes, not final Q0 documentation hashes. Q0-owned strategy/current-state/navigation edits are identified separately by result reports; production/test/governance dependencies remain byte-unchanged.

Hashes below bind production/governance/historical dependencies to source snapshot; they do not claim new runs or exhaustive reading of uncalled production code. Historical reports/manuals are evidence artifacts (N/A themselves); meaningful manual check records have distinct approved HISTORICAL rows §12. Scene/script/material API claims in contexts are bounded to the traced calls. Full readonly closure identity is recorded here for independent reconciliation.

| Source | Lines | SHA256 |
| --- | --- | --- |
| [.agent/PLANS.md](../.agent/PLANS.md) | 56 | 5505516ce8bb29efdb33a4f08c547e0b6a618dcc6c5c189d350f9e20c19235b8 |
| [.agents/skills/slow-cycle-review/SKILL.md](../.agents/skills/slow-cycle-review/SKILL.md) | 17 | 028d591de5f06e202a39096f1039780293af106daf9fc5b3d959d071511fcd34 |
| [.agents/skills/slow-cycle-verify/SKILL.md](../.agents/skills/slow-cycle-verify/SKILL.md) | 20 | b83eabb9247f6c4b69b088ed52db6df3c22c5c70e4a8c6dd0d280bbdd608094a |
| [.antigravity/rules/test-integrity.md](../.antigravity/rules/test-integrity.md) | 151 | 4853acf1b4dcd2666bc175cbb8eb932ad89931107b1cca2e06a529a298338733 |
| [AGENTS.md](../AGENTS.md) | 40 | d93df728ca8344e654ec5c13509db5da310306a984a227a5efc22eabb4331345 |
| [docs/CURRENT_PROJECT_STATE.md](../docs/CURRENT_PROJECT_STATE.md) | 55 | 90c83357bca307eb48c8b4eb32d7105737347418e95830e5dba11aee3bec5b2f |
| [docs/LEGACY_MIGRATION_MATRIX.md](../docs/LEGACY_MIGRATION_MATRIX.md) | 49 | a83fdf8f4fe0543aca939f9f3747f8d0611604ee5e8e14f95c33ff7ce1d1bca9 |
| [docs/MASTER_IMPLEMENTATION_PLAN.md](../docs/MASTER_IMPLEMENTATION_PLAN.md) | 1947 | a168522df254703ec4b952363d82d3bf3b0c1b6fb86b3d368a6622204d4915e8 |
| [docs/sprints/sprint_4m_validation_report.md](../docs/sprints/sprint_4m_validation_report.md) | 166 | 2566af944da1c643d3235c0ff65951b128f8672583ce059d35c31a133cf4f7ad |
| [docs/sprints/sprint_6_v4_completion_report.md](../docs/sprints/sprint_6_v4_completion_report.md) | 165 | be50bd73397b7b446d4b5827fbf75b38b105d536b9638c317ccfd4c5f3548ad8 |
| [docs/sprints/stage_b_validation_report.md](../docs/sprints/stage_b_validation_report.md) | 111 | 748c526d9d79d9de84102492b254c9c3662237d66347352e58e6049442b918f5 |
| [docs/sprints/world_00_c01_c02_verification_report.md](../docs/sprints/world_00_c01_c02_verification_report.md) | 109 | 4361d8f56715bb89c9f8b879c877855fd155e337cfb113449a53bd03109271ee |
| [docs/sprints/world_00_c03_c04_verification_report.md](../docs/sprints/world_00_c03_c04_verification_report.md) | 81 | e92e5afc2e596c3b80fc29f649cc506005bf6585503195f4cddf0da7d84e85f6 |
| [docs/sprints/world_00_logs_verification_report.md](../docs/sprints/world_00_logs_verification_report.md) | 86 | e2b0581f453d5bb8e8669cf0a16bf3a7390f17bd9853e35848d261c8534451a2 |
| [docs/sprints/world_00a_documentation_report.md](../docs/sprints/world_00a_documentation_report.md) | 56 | 0b13a68def73d5ff961b99e7598546929d5826016962e8dde6d14d4282d62bfe |
| [docs/sprints/world_00b_verification_report.md](../docs/sprints/world_00b_verification_report.md) | 86 | 1eacf8c9f44b9d2e014c4b33aa6fa05d162332daa8e0b74a40c4a6e5480cb57b |
| [docs/TARGET_ARCHITECTURE.md](../docs/TARGET_ARCHITECTURE.md) | 88 | 36cfc5d5870c0424f6adb012159a6fe0fd1696cf3c9abc6053113fc041d80981 |
| [docs/TARGET_GAME_BLUEPRINT.md](../docs/TARGET_GAME_BLUEPRINT.md) | 1353 | 8d24232ebf631cac4c50050bbf7660698e1de0ea2f25e3203a7829853579a201 |
| [docs/TEST_STRATEGY.md](../docs/TEST_STRATEGY.md) | 57 | c9259de4b3a1b72c2ddbc80e04aa2bb9e18077099e550ea1657ba0ea785bcbe9 |
| [project.godot](../project.godot) | 103 | 6fce921ae6e6942687c2f358d3af63df3696d069a8fbb0c145742903956d1d5c |
| [scenes/environment/forest_env.tres](../scenes/environment/forest_env.tres) | 43 | c42e0e33460b990b05f9f4415fe910e868913d9d9705999fcc6d6bfb6898ec4b |
| [scenes/main.tscn](../scenes/main.tscn) | 41 | b0b9c9bd4063c1e79ed16223170e8b650d4b65c36496a02bb2425add645e3726 |
| [scenes/mode_select.tscn](../scenes/mode_select.tscn) | 135 | 7c4d45fd9f853d50de62947fe289deb33cf934e11e661a5d14db6ee8d74d95c2 |
| [scenes/player/bicycle.tscn](../scenes/player/bicycle.tscn) | 302 | e0e2d256d2440a173b36f09e52b58eacc7ced92ec88f517c2fd5790b86aed479 |
| [scenes/test/gravel_training_loop.tscn](../scenes/test/gravel_training_loop.tscn) | 41 | 4e5eba33b7376c0b2eea04750174f692b6e32d601dbabad57336f273da7c0457 |
| [scenes/test/riding_feel_test_track.tscn](../scenes/test/riding_feel_test_track.tscn) | 41 | 52d61fc27205da13559dbe418c66d89cf63cb2143eca74f8826e3869843ad316 |
| [scenes/test/riding_lab_track.tscn](../scenes/test/riding_lab_track.tscn) | 41 | ee872c72796017e5d6b5955b54974e8cf6c473bc30b6f903916a196bbd790bc1 |
| [scenes/test/sandbox.tscn](../scenes/test/sandbox.tscn) | 162 | 066c3b56b98d3c35978c7a7196cd04061e3d80e5f3a3920dfb980d6102c515c3 |
| [scenes/ui/debug_hud.tscn](../scenes/ui/debug_hud.tscn) | 53 | 9e5d2e25fd3521e8ed837fcae103e663307b012e20b77dd2e82217c0e4edb76c |
| [scenes/ui/hud.tscn](../scenes/ui/hud.tscn) | 162 | 7d2e6645903447ff86d27b5c5d55545e25f7615596923d65fe0f7c1bcf8999f8 |
| [scenes/ui/screen_fader.tscn](../scenes/ui/screen_fader.tscn) | 16 | 41e4d6060f4b7cad0db171d98a3773d4f95637c65ba7a86fa30e2ba8039bc78d |
| [scenes/world/birch_tree.tscn](../scenes/world/birch_tree.tscn) | 47 | 8ce6e60567e8a6a4e65fddd7288615e88abcc36188edd9f6f7808bccbada6929 |
| [scenes/world/pine_tree.tscn](../scenes/world/pine_tree.tscn) | 51 | 94625dc4ff1df0290cc51016e0c333be3f9b1a0760c3bf7f853acf6533bdbe15 |
| [scripts/audio/bike_audio_manager.gd](../scripts/audio/bike_audio_manager.gd) | 422 | 060698d1da97256d64adbc3467bda6eaafd47de8a79b2178c37075d0bcbeaa02 |
| [scripts/camera/bike_camera.gd](../scripts/camera/bike_camera.gd) | 288 | dcf22575fd09fcafa391392f4029ba4220bb79d909bde51e022158698614f4bc |
| [scripts/core/slow_cycle_logger.gd](../scripts/core/slow_cycle_logger.gd) | 357 | af0c5c441c2ffcaccc712be0ed04d41b9b20eaa8efd2ea7ab120a81d16544696 |
| [scripts/player/AGENTS.md](../scripts/player/AGENTS.md) | 7 | 2dde056fb19caf3be1b2d29af9e2b404f100d022e9608264508bd78151902da4 |
| [scripts/player/bicycle_controller.gd](../scripts/player/bicycle_controller.gd) | 622 | 762e8c1a51a041106490de4e6fcca2950ed7407983c81fe007cf9aa5dd5bbdb3 |
| [scripts/ui/debug_hud.gd](../scripts/ui/debug_hud.gd) | 294 | ba9c5c4a76d678002f4a927aa9753db8f08ae940f1bd1bab70e3ed04cf7c0d03 |
| [scripts/ui/hud.gd](../scripts/ui/hud.gd) | 68 | 1be37839d6516279b918e9888b9732f7f4107ff58587fc0ac476118b47e3909d |
| [scripts/ui/mode_select.gd](../scripts/ui/mode_select.gd) | 123 | 5e931876e745aa151c00a72b099f435b26ecf4740bfdef54a81d2f2f4e2b09d0 |
| [scripts/ui/screen_fader.gd](../scripts/ui/screen_fader.gd) | 45 | 0e17fd6d7ceb446b58e331a7203d9f799f943046bce06e66101a974eb5778247 |
| [scripts/world/AGENTS.md](../scripts/world/AGENTS.md) | 23 | cdef7bf55179cba9a374ff90dabfdee43183bc1bffdac3407c0fc7acd18c4d27 |
| [scripts/world/chunk_foliage.gd](../scripts/world/chunk_foliage.gd) | 206 | 7772868ea6df22b6cc607b7fae0127f8c0bc99528973a424862b63a9f7fca408 |
| [scripts/world/chunk_streamer.gd](../scripts/world/chunk_streamer.gd) | 927 | 5c7fafac0d3e3d8817cac2d8487f44c4477035ac1eed58589b47c48fca6c72b8 |
| [scripts/world/fork_arm_geometry.gd](../scripts/world/fork_arm_geometry.gd) | 50 | 34120684a190c2a3020124756266eda3904e039005c6dca8d41bfc24d651b0ed |
| [scripts/world/fork_corridor_preview_planner.gd](../scripts/world/fork_corridor_preview_planner.gd) | 125 | 9df851905686aef08fc55cfdf045e68759bb3b9fb03bff4d91c2b7eb7e881f17 |
| [scripts/world/fork_decision_model.gd](../scripts/world/fork_decision_model.gd) | 289 | d5928c3498fef81500d9556f4cba047b525e040cba930f6a3a29f6627df2ecc7 |
| [scripts/world/fork_pacing_planner.gd](../scripts/world/fork_pacing_planner.gd) | 78 | 4d7557b32d918d3fa1a31a604c4394dfd6265400f789f65710d36d9118fd269a |
| [scripts/world/fork_site_planner.gd](../scripts/world/fork_site_planner.gd) | 175 | ab3c3ddabf7c7dd6b23430716e07e95790ed5e5cd09b0667ac643e48fa3086c7 |
| [scripts/world/mountain_massif_field.gd](../scripts/world/mountain_massif_field.gd) | 129 | f2f9a7f2d710c0585f03e54e6f55f0867c05dc14d4fd7ee071b88564bebe1301 |
| [scripts/world/mountain_profile.gd](../scripts/world/mountain_profile.gd) | 135 | 6f2766d8da1374ecbf4f2f0df1644b0f84b612d113e56c08451ed3828ea1b0dc |
| [scripts/world/road_airborne_contract.gd](../scripts/world/road_airborne_contract.gd) | 84 | e168630d4735fb77534526a78b058a6cac83a67fb890e6ad98ab200569e9ba16 |
| [scripts/world/road_chunk.gd](../scripts/world/road_chunk.gd) | 494 | e171b7ed6c47ba704cd1d7809bc876b126790e37944b075e4e23a33ff6acd01c |
| [scripts/world/road_generation_contract.gd](../scripts/world/road_generation_contract.gd) | 80 | 61b61ad11a88a64e9ea9b9b0265d8823cea0be9a6daaede936d5c872f592bdde |
| [scripts/world/road_grammar.gd](../scripts/world/road_grammar.gd) | 514 | 636e1d51ae8cce63d25475d33fc47ab01d152e4852c2ec8719ea3330a7b5b2fe |
| [scripts/world/road_graph.gd](../scripts/world/road_graph.gd) | 463 | c7a14fb5c6f22f0f0e57fe8284ecf76ec316ab9b82c6b0623386a1e0b246f487 |
| [scripts/world/road_kinematic_model.gd](../scripts/world/road_kinematic_model.gd) | 110 | 44227196555619fe86efe79b6eecbf59119cee9b076fe9ac7070441d9358a382 |
| [scripts/world/road_logic.gd](../scripts/world/road_logic.gd) | 998 | 9a689620198780376b1d590c31815731a1f485c586072e307903dc2e00190731 |
| [scripts/world/road_math.gd](../scripts/world/road_math.gd) | 81 | 1c736ca8219d7b714f28f79995e38ece664e21414d1c3a4cf0696339c26eadbb |
| [scripts/world/road_path_data.gd](../scripts/world/road_path_data.gd) | 419 | eb9e4441250323f60068da6c322fcd8c7c0cc67ed2207ad2f57fcd28e1934470 |
| [scripts/world/road_validity_validator.gd](../scripts/world/road_validity_validator.gd) | 354 | 646537f5a65dea31f2f091899fe10b0586a2e6756cf23d132d2fdb429b95c77f |
| [scripts/world/route_intent.gd](../scripts/world/route_intent.gd) | 100 | 5362ff3609f04703949222c7774c1ddfaa5784e653412aa1d4a1db47f6e18096 |
| [scripts/world/route_plan.gd](../scripts/world/route_plan.gd) | 146 | a2ccad34a42a26103846d3f851d6df3c40fe5fb6554adb2c8d1917f2ceb31a8c |
| [scripts/world/terrain_carver.gd](../scripts/world/terrain_carver.gd) | 338 | fe37fdac28c61969dd3840972ffab776e700ebc8dc57836f665c6bbe293500f3 |
| [scripts/world/world_manager.gd](../scripts/world/world_manager.gd) | 368 | c68b07c351f2076df62d532131180794a74d48aecb27f4eb06aa3ba2742796c7 |
| [TEST_PLAN.md](../TEST_PLAN.md) | 539 | fc30431ae931ee87262bd4d57ccab19411b56224855159288b37fd920bdbebcd |

## 12. External historical checks / manual records

Eight standalone external check scripts were read as source; none executed Q0. Role: historical artifact-verifier/scope-audit (EXT-*), manual check protocol/report (MANUAL-*). Protected path: archived WORLD source/log/PNG/manifest integrity or old authored human ride. Prerequisites: exact hardcoded stage paths/run IDs/source snapshot and, where applicable, compatible Python/PIL/Godot; availability now confirmed, semantic compatibility with current branch not inferred. Trigger: only explicitly requested historical reproduction/investigation; no new mandatory schedule. Blocking: HISTORICAL policy §3; old failure evidence remains relevant to required current safety. Completion: actual asserts/reason conditions in source, rather than launcher's exit0; currentQ0 result NOT_RUN.

| ID / source locator | Approved Authority | Capability/scope | Oracle | Limits / conflict |
| --- | --- | --- | --- | --- |
| EXT-CAP · external/work/inspect_captures.py L1 | HISTORICAL | E3,E5 archived evidence | WORLD C01/C02 manifests/19PNG/seed/path/coverage/reload/source hashes +4 exact negative reasons + gate log summaries | Hardcoded4run labels/revision7c33004/19frames; current repo bytes must match old archive; no fresh engine run; gate exit/markers alone not coverage. C14 |
| EXT-LOG · external/work/verify_logs_artifacts.py L1 | HISTORICAL | E2,E3,E5 archived evidence | 3manifest source copies/events/snapshots/checkpoint51 vs previousstage;8PNG metadata; capture-source archive equality | Fixed17368sessions/path/digests; assumes first replay step checkpoint; no physics replay. C14 |
| EXT-REPLAY-NEG · external/work/verify_replay_negatives.py L1 | HISTORICAL | E3 negative runtime if rerun; archived results only now | 13manifest/input mutations through real replay runner; require exit1,exact INCOMPLETE reason,no external timeout,no engine messages | Creates fixtures and launches processes; historical runner dependencies/paths; not runQ0/not Q1. C14 |
| EXT-SURFACE · external/work/verify_surface_artifacts.py L1 | HISTORICAL | E2,E3,E5 archived evidence | 6actualarms/168checks/333contacts,21PNG incltop>500/bottom0,matching source hashes and exactheadless refusal | Hardcoded run IDs/counts; no human ride; writes contact sheets/results ifexecuted. C14 |
| EXT-SCOPE-LOG · external/work/check_final_logs_scope.py L1 | HISTORICAL | document/source integrity only | 6oldtests normalized bytes +doccopy/HEAD7c33004/diffcheck | Historical stage-specific scope, CRLF normalization not byte-exact acrossallfiles. C14 |
| EXT-SCOPE-CAP · external/work/verify_final_scope.py L1 | HISTORICAL | document/source integrity only | Exact eightchangedpaths (4Markdown +4capture/helper/check sources),HEAD7c33004,markdown whitespace/links,doccopies/runtimezip hashes | Fixed originalstage whitelist, not Q0 verification. C14 |
| EXT-SCOPE-SURF · external/work/review_repository.py L1 | HISTORICAL | document/source integrity only | 38path allowed scope,stableproduction/frozen normalized snapshots,oldtests/capturearchive bytes,links | Historical author self-check script, not independent D1 reviewer; fixedoldHEAD/whitelist. C14 |
| EXT-COMMIT · external/work/verify_commit_and_deliver.py L1 | HISTORICAL | source/artifact integrity only | Committedpath hashes,cleanstatus,parent/stagedmanifest,3capture source snapshots | Also extracts archives/writesdeliveryreport; historical commit/revision only, no productionsemantic suite. C14 |
| MANUAL-10MIN · TEST_PLAN.md L346 | HISTORICAL | E4/E5/E6/E7 only with recorded actual human ride and measurements | Legacy10minute continuous Ride Test checklist: endlessroad,seams,16.6ms,flat RAM/VRAM after500chunks,bikestability,speed0..48 | Protocol/document does not itself supply run evidence; hardware/seed/choice/duration/telemetry unbound; not new Blueprint slice acceptance; preserved D0 historicalscope. C14 |
| MANUAL-4M · docs/sprints/sprint_4m_validation_report.md L123 | HISTORICAL | E7 historical report only, no current E7 | Sprint4M recorded15human perception items/noF3/critical repetition checklist | Dated2026-09-23,oldscene/revision scope; cannot certify current targetgame. Self-documentary PASS not reproducedQ0. C14 |

External work source index:38 files. Eight have check rows above; seven dispatch/transport launchers have no independent domain/check oracle;12 .gd are saved implementation snapshots (11 modules/runners plus seed_baseline_probe logger-only), remaining11 authoring/staging/commit/doc scripts are out-of-scope mutation/provenance artifacts. N/A is applicability, not historical sixthcategory. Saved snapshots refer to original report/run consumers; not silently substituted for current .gd or reexecuted. Mutation scripts' edit guards do not make them production test suites.

| External work file | Role / Authority applicability | SHA256 |
| --- | --- | --- |
| apply_surface_changes.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | b03b78ad5cfb29089a25e3ca4492ad4db2098ec990a69b20393a173b24e1bf6e |
| baseline_check.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | 83a10db3a445d35e07793aec03f003fe8dc59946aadc9b22580bba90d7232638 |
| capture_audit_support.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 1af9f94289e9fdb058ebea3646529ebfe4de5a84fac5e96968f69f594ce920c0 |
| capture_seed_audit.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 75e06ad15f4b824a0cea834e41bb1fdd0e49f552d6916799716650bddde4200b |
| capture_surface_culling_audit.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 365ec7d0796122ac7adb70c646cfd7d38a2d326c5883750819d0e2e04b8a083a |
| capture_visual_audit.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 49321bab5e7f8b4d851ae658393d94ea2d6901772d174bab61b42783423a70a9 |
| check_final_logs_scope.py | check script; HISTORICAL ACCEPTED_BY_B | 849095161ddbbbb2b2e8c59a8c216586b2548d42e2d7287c02c635eb30fc715d |
| close_today_docs.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | f5a29c244f1a283be4fa01d506970c58689dc4fe7d66682c33e907a7af67ddd8 |
| commit_day_close.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 2ed2ff4df841d916c02ca0f35fcef5af47563861c84f775210de22f91f47158a |
| consolidate_today_docs.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | ae8aa5c932bf615fae588a30c270a0dc4989a997b604e8f2398a850937dbde3a |
| finalize_logs_docs.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 939409428d42bef7772c69c648fa280ddd18ed76603ab3711ca37b4c3f6d67cb |
| finalize_surface_docs.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 6f65edb910e13acc8a9b88af4fbdf3672d7fca1791f5036bfef1a3308ebbb27b |
| fix_doc_links.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 998ac8325f44d8b17bd9b8d8c41ea0f002a0591a92b31280f4436658e1112c11 |
| inspect_captures.py | check script; HISTORICAL ACCEPTED_BY_B | fcf0f7aaa3461d6621d41592107590cba0f6eee34e561a2b7097e4b476c43401 |
| integrate_session_logging.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 6a7e38f771b6de19311dd499f8df5a6e79eddecd3d8d5ef8f8dc44b09ed65cd7 |
| refine_capture.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 3ff69e8537a4f2159e55502351a4f2d2afaa74851e681053efbcc430c8a4a269 |
| refine_session_replay.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | 25984c9b59c8b69b532a45774a653c3802a00f78b752b835931f098638d59042 |
| replay_session_diagnostic.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 6b46d4ded1735089324ae48f3bbd7ee7736ef6a2950356df2eb8e0df741ef14b |
| replay_surface_sessions.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | 31fcc437dc1a3cc524a6bc81d890e98470f3c48d2511f358b5f35a2691bee426 |
| review_repository.py | check script; HISTORICAL ACCEPTED_BY_B | 725b73b759526d90de7d52be827315f92ce156aee68a88a9bb2c7b868d6b0f02 |
| run_audit.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | 7acfaf0c22ae80eb03b66ea3a876a6d84872397d59c0ae00d813b3d824ab70ad |
| run_logs.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | 2d66e992c9f575dc5e1825df088ed93c04995fc85a666da6ceea663ebaffc4cd |
| run_route_baseline.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | 46732779da532d2ff6812c7a0cd05ca816ff21ca64d5d0d95f0af2d0f78e2654 |
| run_surface_neighbors.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | d12a6a740ec86bf5416da6d60992e88f0a85dab7d0159912456b5d25cb7e2aa6 |
| run_surface.py | launcher/transport; N/A — NON_CHECK_ARTIFACT | f66aae68f1a0c617343802044ab59719b727ae1add4efd9a4a3f3f8307e2cbea |
| seed_baseline_probe.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | ac1ad98307fe0b728e61bdf46254d1ef0e8f502b08d9d0f69ab4c77f2dcfad58 |
| slow_cycle_logger.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 1402f40d10d54f4fcfc96c32c16ed6c8d542e3adc042d5c68f276c9c4c65cb8b |
| stage_today.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | efa4b124b8d470a4c9764fd7040437af88f875b7ce2324c7afc00df3eba30c23 |
| surface_audit_support.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 795387d443ae31239d5b07c95a69b0326dca8818b150491cb2f7f541838da54c |
| test_capture_audit_contract.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | be1dd200d870d895ec539513f228579afca4d300ce91842febd5a229e51a3758 |
| test_session_diagnostics.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 9567855bf8fed0e3e6803888e3525ce18a067177bc2a737e783694d059dbd0c3 |
| test_surface_audit_contract.gd | saved snapshot/probe output artifact; N/A — NON_CHECK_ARTIFACT | 6d2235e8dc3adea0c40d240e0ffc62e70bdb2dd1fcd66758af589430fa0ba919 |
| update_capture_docs.py | historical authoring/staging/delivery artifact; N/A — NON_CHECK_ARTIFACT | d85cd4b4841e0832fa3b67c63c7e2e76fb89b99cae3f02f12f48bb367177ce4e |
| verify_commit_and_deliver.py | check script; HISTORICAL ACCEPTED_BY_B | 5cba9dd601916715751760dd4fcaf3ecab4808a25dca333e9da365e48a247f24 |
| verify_final_scope.py | check script; HISTORICAL ACCEPTED_BY_B | 3497efcddc936185d3de30ebdfb518879c38702f6343d26d663029a965e5e530 |
| verify_logs_artifacts.py | check script; HISTORICAL ACCEPTED_BY_B | 977e81fc1e8eba04447a62fffcfdbe43dea99b52b7522c800d348d7133f4990c |
| verify_replay_negatives.py | check script; HISTORICAL ACCEPTED_BY_B | f33be6dd386857e30ec74a6824c7e926b41ea3cb4a209babe26680ec29fa3b8f |
| verify_surface_artifacts.py | check script; HISTORICAL ACCEPTED_BY_B | 74d3fde71b256b7dc4da3ac655c631dd49b96202798bd37e00413c458a51c63c |

Historical copies are evidence identity, not an assertion that all authoring scripts/snapshot variants were fully audited for domain semantics. All **current66 .gd** and the distinct16 external test/evidence implementations listed in methodology were read; duplicate/out-of-scope authoring/snapshot files were enumerated/hashed and traced to original consumers. Their snippets/assert guards were discovery-only; no invented current authority. seed_baseline_probe.gd was read: prints requested/configured/generator identity then quits0, no mismatch oracle; original WORLD00B temp probe source remains unavailable.

## 13. Acceptance and rollback boundary

Checkpoint B has accepted every authority assignment for the exact draft digest in §1. Meaningful mixed subrows, N/A roles, bounded evidence capability, limitations and mandatory G remain intact. Open C10 numeric requirements and C12 stale oracle are unresolved future-task findings; they do not invalidate approved categories or documentary Q0 completion.

Final Q0 completion additionally requires explicit slow-cycle-verify PASS and fresh independent slow-cycle-review PASS on approved plan + result + verification identities. The completed task record is published only after both PASS and then reached through the [root plan slot](../implementation_plan.md). Source reading/documentation approval does not certify current runtime, physics, Vulkan, performance or human acceptance.

Exact whitelist: docs/TEST_MATRIX.md; implementation_plan.md; docs/TEST_STRATEGY.md; docs/TEST_COVERAGE_AND_REPLAY.md (navigation addendum only, historical body preserved); docs/CURRENT_PROJECT_STATE.md (Q0 status, runtime INCOMPLETE retained); docs/README.md; docs/plans/completed/Q0.md (only after B + VERIFY + independent REVIEW). Tests/assertions/thresholds/gates/production/scenes/resources/governance/frozen rule remain untouched. No Q1/Q2/R0.

Rollback: only Q0-owned Markdown hunks within whitelist; remove own unaccepted draft safely or revisewithnewdigest, preserve v1.0approval/progress/historicalevidence. No reset--hard, testcleanup, sourcemigration, deletionoflegacytests or overwriting unrelatedchanges. Accepted human decisions later superseded require recorded explicitdecision, not erasedhistory. No runtime/data/APIchange to roll back.

**Boundary: accepted authority is not runtime PASS. Q1/Q2/R0 require separately approved work.**

## 14. Documentary correction history — accepted edition1.1

Fresh independent slow-cycle-review R1 (context /root/q0_independent_review) read all66 .gd bodies (15735lines), all204 assignments and8 external check implementations/2manual records, then returned REJECT for seven factual description groups. Its immutable report SHA256 is `5884ab0ed11adf3661fc91f7db2d230dffad0cb5689e6e2d78f6acfc04921a7f`. User-authorized Q0 Markdown-only corrections below preserve accepted categories/IDs/E-capabilities and every source byte. No numeric requirement was adjudicated and no E-level was upgraded. Old1.0 verification/review are historical inputs, not acceptance of this changed digest. Fresh reports are bound to edition1.1 in the task record.

| Finding | Corrected documentary fact / source | Boundary |
| --- | --- | --- |
| F1 | GRAMMAR-BIOME forest35%/3 per rolling12, mountain25%/5 per rolling12; test_road_grammar L237–267 | LEGACY_CONTRACT unchanged; actual thresholds untouched |
| F2 | GRAMMAR-DET30 chunks per path, size equality, every point, strict delta<1e-6; same file L60–82 | ACTIVE_CONTRACT unchanged; other channels/order not certified |
| F3 | SESSION-SEED seven actual checks include valid zero, not malformed input; test_world_session_seed L11–42 | ACTIVE_CONTRACT unchanged; missing negative coverage explicit |
| F4 | TOPO-SAFE area≥.0005; separate SURFACE-NEG owns reversed-index fixture; topology L179–188 and surface contract L46–60 | ACTIVE_CONTRACT unchanged; no transferred runner coverage |
| F5 | SOAK recovery displacement10..35m; finiteY at50-chunk milestones; test_soak_run L75–123 | REGRESSION_GUARD unchanged; no real ridden-distance claim |
| F6 | EXT-SCOPE-CAP eight historical changed paths (4Markdown+4capture/helper/check); verify_final_scope.py L11–18 | HISTORICAL unchanged; old scope not a Q0 gate |
| F7 | SOAK/CLEAR/STYLE requested labels vs effectiveUNKNOWN_CURRENT; retained Main randomization and CLI priority; corresponding runners L37–39/L29–30/L31–32, main L26, world_manager L23–56 | Both subrows per file retain categories; C08 disclosed; no seed/control fix |

C10 numeric authority and C12 stale oracle remain OPEN exactly as approved. Category approval is not current test PASS or an endorsement of incorrect source descriptions.

## 15. Documentary correction history — accepted edition1.2

Fresh independent R2 (/root/q0_independent_review_r2) read all66 unchanged bodies/15735lines,204rows,8historical check bodies/521lines and2manual sources. F1–F7 closed; R2 REJECT raw SHA256 `564d9b6b3220763b5caed69483224d448261af90fe87f161fbee31625f3ff420` identified six additional description groups F8–F13. User-authorized Markdown corrections preserve categories/IDs/E-capabilities and all sources. Old V2 reports do not certify this changed digest; fresh verification/review is required.

| Finding | Corrected as-is fact | Boundary |
| --- | --- | --- |
| F8 | Sprint3A/C load Main,180/240 process frames; capture_sprint3a/c L4–6/L18 | N/A applicability unchanged; no ride certification |
| F9 | test_ride120 process frames; steer_left frame60..100; L13–22 | N/A; process frames not measured physical duration |
| F10 | ForkDecision synthetic model30/60/120 samples per second; L311–322 | FORK-FSM category/capability unchanged; not whole-engine FPS evidence |
| F11 | DIAG-39 strict maxstep<.85° (diagnostics L832); DYNAMIC-DROP finiteY and Y≥−100 (dynamic L181–194) | As-is predicate descriptions only; C10 authority remains OPEN |
| F12 | Seven unchecked captures have no headless admission/skip guard; conditional viewport PNG attempts | N/A; no reproduced headless crash/hang or E5 inferred |
| F13 | capture_screenshot_ride quits only after six image attempts (target index advances outside nonnull-image guard) advance targets; no internal timeout/readiness deadline; L24–61 | N/A; save/reload integrity unverified, static incomplete possibility not new runtime result |

C10/C12 remain OPEN; no failure waiver/test repair/requirement resolution.

F13 indentation clarification: capture_screenshot_ride L57 has the same nesting as `if img != null` L53, so target advancement is unconditional after each ready image attempt; six attempts may complete even with null images, while missing scene/path readiness has no internal timeout. Parent literal-tab reread corrected the R2 report’s nonnull advancement assumption before final verification/review. No observed runtime result is inferred.
