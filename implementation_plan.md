# Slow Cycle — active plan slot

TASK: Q1 — Bounded Verification Harness (ExecPlan v1.0)
STATUS: APPROVED — implementation authorized (ExecPlan v1.0 + amendments A1–A7, §A); реализация M0–M9 ещё не начата
DATE: 2026-10-03 (Asia/Qyzylorda)
BRANCH / BASE / HEAD: `q1-verification-harness` / `master` = `origin/master` / `8977813ce4d3e7488cf1652a4848125522b1abeb` (все три ref совпадают)
BASELINE: staged=[] · unstaged=[] · untracked=[] (метод и оговорка — §0)
APPROVAL: 2026-10-03 — human approval ExecPlan v1.0 с поправками A1–A7 (§A), дано в чате; закреплено commit «docs: approve Q1 verification harness plan». Решения D1–D4 закрыты в §18. Поправки §A переопределяют конфликтующие детали ниже
LAST_COMPLETED: Q0 — [accepted plan, reports, limitations](docs/plans/completed/Q0.md)
SCOPE GUARD: tests / thresholds / production / player / camera / world / gates не меняются; Q2 и R0 не начинаются

---

## A. Human approval и обязательные поправки (2026-10-03)

Человек одобрил ExecPlan v1.0 при условии поправок A1–A7. При конфликте с §§3–18 действует §A. Весь остальной scope (whitelist §9, forbidden §10, запрет Q2/R0, неизменность тестов/thresholds/production/gates) сохраняется.

**A1. FAIL vs INCOMPLETE.** Результат ровно `PASS` / `FAIL` / `INCOMPLETE`. `FAIL` — только при надёжном доказательстве нарушения реального product/test/gate-контракта (исполненный assert упал; явный contract-предикат; parse/runtime error, относимый к проверяемому источнику; expected-negative с неверной причиной; неожиданное ObjectDB/leak-предупреждение после нормально завершённого запуска, где требуется zero unexpected leaks). `INCOMPLETE` — обязательное evidence не установлено: timeout без независимо показанного product-сбоя, нет completion marker, нет обязательного coverage/логов/artifact, сбой launcher/окружения, нет executable, недоступен Vulkan, необъяснённое завершение процесса. Shutdown-шум, порождённый принудительным kill (timeout/process tree), НЕ превращает timeout в `FAIL`: сообщения после kill классифицируются отдельно и не считаются evidence нарушения контракта. Это уточняет строки «Unexpected engine error / leak / parse error» §6.5: они дают FAIL только в нормально завершённом (не убитом) процессе.

**A2. Exit code не равен FAIL.** `exit_code` сохраняется независимо. Ненулевой exit + доказанный assert/contract/project error → `FAIL`; ненулевой exit + инфраструктура/окружение/неизвестное завершение → `INCOMPLETE`. Product failure не выводится из одного числа.

**A3. Политика warning/error/leak.** Нет правила «any warning = FAIL» и нового глобального zero-warning gate. Захватываются и сохраняются все сообщения. Машиночитаемый результат различает минимум `project_errors`, `warnings`, `objectdb_or_leak_warnings`, `expected_environment_messages`, `unknown_engine_messages` (поля §6.4 `engine.*` реализуют это разбиение). PASS требует нуля неожиданных сообщений, нарушающих политику применимого принятого suite/gate (TEST_MATRIX / AGENTS остаются авторитетом).

**A4. Allowlist сообщений окружения.** Механизм разрешён, но: точное узкое сопоставление, привязка к окружению, обоснование (rationale) в записи; исходное сообщение остаётся в raw logs и в structured result; allowlist никогда не скрывает отсутствие обязательного evidence. Запрещены широкие regex (вроде `.*permission.*`). Сообщение `user://logs` permission НЕ allowlist-ится глобально: в pilot-запусках фиксируется точный текст, место появления и влияние на обязательное evidence; если из-за него не создан требуемый log/output/artifact → `INCOMPLETE`. Глобальный список `environment_noise` §6.7 заменяется этим механизмом.

**A5. Virtual rider.** Существующий gate `350 / 500` сохраняется как есть (не меняется на 500 / 500). Результат раздельно содержит `declared_target`, `existing_pass_threshold`, `actual_progress`, `measurement_semantics`, `limitation`. Текущий PASS по порогу 350 м не может быть назван «full 500 m route accepted»; сохраняется задокументированное в TEST_MATRIX ограничение branch-local distance.

**A6. Технология.** Одобрены Python standard library (без сторонних пакетов, pytest, внешних process/JSON-библиотек, менеджеров зависимостей, pip) и изолированный harness-owned probe-проект Godot (`tools/verify/fixtures/probe_project`, отрезан `.gdignore`; не часть production, не меняет существующие тесты). Probe-результаты никогда не выдаются за gameplay/test PASS.

**A7. Canonical source identity.** Каноничны Git-данные: `HEAD`, tree/blob identity где нужно, staged / unstaged / untracked состояние. Raw SHA256 рабочего дерева — дополнительное поле. LF/CRLF-нормализованные хеши допустимы только как явно помеченные compatibility-расчёты для ранее записанных документальных хешей и никогда не скрывают отличие рабочего дерева (dirty файл остаётся dirty). Это уточняет `source_digest` §6.4.

Дополнительно для реализации: M0 повторно проверяет baseline реальными командами (branch/HEAD/status/python/Godot); минимальный probe-набор P1–P14 (genuine PASS; assertion FAIL; project nonzero FAIL; infra nonzero INCOMPLETE; timeout INCOMPLETE без выживших процессов; exit 0 без marker; missing coverage; missing artifact; stale artifact; expected-negative неверная причина FAIL; parse/runtime error FAIL; leak после нормального завершения FAIL; Vulkan недоступен INCOMPLETE; malformed output INCOMPLETE); virtual rider/master-children/Vulkan — только по pilot-списку §7; evidence не повышается (teleport PASS ≠ E4; PNG saved ≠ E5).

## 0. Baseline и предел investigation

| Факт | Значение | Как получено |
|---|---|---|
| Branch | `q1-verification-harness` | `.git/HEAD` → `ref: refs/heads/q1-verification-harness` |
| HEAD | `8977813ce4d3e7488cf1652a4848125522b1abeb` «docs: complete Q0 test authority map», parent `c452aad` | ref + commit object; reflog: checkout `master → q1-verification-harness` |
| Staged | пусто | tree индекса `89d2a47e8149d0e0314f318b5976fc3258d5d8e8` = tree HEAD |
| Unstaged | пусто по содержимому | 178 tracked text/resource files: blob-hash совпал с индексом (104 из них — только после CRLF→LF); 31 PNG и 4 отчёта `docs/sprints` — только совпадение размера с индексом |
| Untracked | не обнаружено | перечисление каталогов против 213 записей индекса; `.godot/` игнорируется; `scratch/`, `export_templates/`, `feature_profiles/`, `script_templates/`, `text_editor_themes/` пусты |

**Оговорка метода.** В этой сессии не было shell на машине пользователя: `git` и Godot **не запускались**. Состояние выведено чтением `.git` и хешированием рабочих файлов. 104 текстовых файла лежат на диске с CRLF при LF-blob в индексе — это согласуется с `core.autocrlf=true`, но глобальный git config не читался. Первый шаг реализации (M0) обязан подтвердить baseline настоящими `git status --porcelain=v1 --untracked-files=all` и `git diff --cached --name-status`; расхождение → STOP.

Прочитано: root `AGENTS.md`; scoped `scripts/{test,world,player}/AGENTS.md`; `.agent/PLANS.md`; Master §§V, VI, IX–XI, XVI–XVIII; `docs/TEST_STRATEGY.md`; `docs/CURRENT_PROJECT_STATE.md`; `docs/TEST_MATRIX.md` (§§1–6, 8, 9, 12–15 полностью; §7 — все file contexts и строки pilot-наборов); `docs/plans/completed/Q0.md` (итог, whitelist, исходный ExecPlan §§10–14); оба skill `slow-cycle-verify` / `slow-cycle-review`; `.antigravity/rules/test-integrity.md`. Исходники: `test_sprint_4m_master.gd` целиком; `capture_audit_support.gd`, `capture_visual_audit.gd`, `test_capture_audit_contract.gd`, `test_session_diagnostics.gd`; exit points всех runners (поиск `quit(`/deadline/assert по 66 файлам) и entry/summary участки pilot-набора; `WorldManager._resolve_session_seed`; отчёты WORLD-00 (launch pattern, ObjectDB, environment messages).

Не сделано и не заявляется: ни одного запуска Godot; внешние исторические launchers (`…/Codex/2026-10-01/…/work/*.py`) лежат вне подключённой папки и не читались — использованы только их описания в отчётах и TEST_MATRIX §12.

## 1. Goal

Небольшой внешний launcher, который запускает **существующие** entry points Slow Cycle и для каждого запуска выдаёт machine-readable запись с результатом ровно `PASS` / `FAIL` / `INCOMPLETE` и причиной. `PASS` выдаётся только когда доказаны completion, declared coverage и отсутствие неожиданных engine errors/leaks. Exit code 0 сам по себе ничего не доказывает.

Q1 решает механизм доказательства выполнения. Он не чинит тесты, не меняет их oracle и не создаёт baseline.

## 2. Observed current state (forensic audit)

### 2.1 Что реально возвращают runners

| # | Факт | Источник | Последствие для harness |
|---|---|---|---|
| F1 | Master запускает 5 children через `OS.execute(exe, ["--headless","--script", rel_path], output, true)`; при `res == 0` зачисляет fixed budget (68/6/8/15/16) и **выбрасывает вывод child**. Вывод печатается только при ненулевом exit, и то последние 1000 символов | `test_sprint_4m_master.gd` L86–98 | Через master нельзя сертифицировать ни completion, ни actual checks child. «125» — expected budget (matrix C02) |
| F2 | `OS.execute` блокирующий, timeout отсутствует. Зависший child вешает master навсегда | там же L89 | Нужен внешний timeout + kill всего дерева процессов |
| F3 | Child запускается без `--path`: зависит от cwd master | там же | Harness обязан задавать cwd = repo root |
| F4 | Tier 7 печатает «PASS (0 Leaks)» без какого-либо ObjectDB/memory oracle | L242–272; matrix MASTER-SCENE | Leak evidence берётся только из engine output процесса |
| F5 | Runners с измеряемым счётчиком: `TOTAL ASSERTIONS / PASSED / FAILED` (`test_road_graph`, `test_terrain_carver`), `…_SUMMARY checks=N failures=M` (`test_session_diagnostics`, `test_capture_audit_contract`, `test_surface_audit_contract`, `test_world_session_seed`), `ROUTE_INTEGRATION_SUMMARY failures= routes=` | исходники | Actual count можно прочитать из stdout: это measured |
| F6 | Runners с fixed label вместо счётчика: `test_diagnostics` («68/68» — константа в строке, один `all_ok`), `test_gravel_loop` («ALL 16»), `test_riding_lab`, `test_track_verification`, `test_track_ride` | исходники; matrix C02 | Fixed label — не measured count. Измеримо только число **наблюдённых** меток в stdout (`[VERIFICATION #n]` — 68 различных; `[PASS G1]…[PASS A3]` — 16) |
| F7 | `assert()`-runners без счётчика: `test_mode_select_gamepad` (10 assert), `test_mountain_massif_field` (7) | исходники | Actual assertions не измеримы. Поведение проваленного assert в `--script` режиме — UNKNOWN (вероятен hang до внешнего timeout); калибруется в M1 |
| F8 | Внутренний watchdog 55 с есть только у capture helper, replay, session diagnostics, surface contract. У большинства остальных runners и у master внешнего deadline нет | grep `quit(`/deadline | Внешний timeout обязателен для всех |
| F9 | Ранний `quit(1)` при неготовой сцене и обычный assertion-fail дают один и тот же exit 1 (rider L43/49, monotony L39, track_ride ×8) | исходники | Exit code не различает FAIL и «не дошёл»; различает только marker/summary |
| F10 | Runtime error в `_init`/`_run` до `quit()` оставляет процесс жить (SceneTree main loop) | структура runners | Класс «hang после SCRIPT ERROR»: timeout + разбор engine output |
| F11 | Любой runner, инстанцирующий Main, стартует session logger в `user://slow_cycle_sessions`, если не передан `--diagnostics-root`; capture пишет в `user://capture_audits` без `--audit-output-root`; summary-файлы именуются по PID | `world_manager.gd` L23–41; logger L50; `test_session_diagnostics` L117; surface contract L166 | Без явных roots старый файл прошлого запуска неотличим от нового. Harness всегда передаёт roots внутри уникального run directory |
| F12 | Effective seed ≠ requested у runners, не отключающих `randomize_world_seed_on_start` (soak, clearance, style, branch streaming); CLI `--seed=` перекрывает всё | matrix C08; `world_manager.gd` L45–56 | Harness **никогда** не передаёт `--seed=` сам; seed coverage подтверждается только наблюдённым effective seed (session manifest), иначе не сертифицируется |
| F13 | Capture helper отвергает headless (`RENDERER_UNAVAILABLE`), но не проверяет, что driver именно Vulkan; manifest пишет фактические `driver`/`renderer`/`display_server` | helper L67–68, L378; matrix C05 | Harness сам проверяет `manifest.driver == "vulkan"`; иначе E5 claim INCOMPLETE |
| F14 | Rider PASS при ≥ 70 % от 500 м; печатает `Distance Covered: X / 500` | rider L149, L164; matrix PARTIAL_ROUTE | Harness не ужесточает gate, но обязан записать фактическую дистанцию и limitation |
| F15 | 7 старых captures и 5 helpers/generators не имеют oracle | matrix §2, N/A rows | Не запускаются как checks; попытка → `NOT_A_CHECK` |

### 2.2 Среда и история

- Исторически использовался `C:\Users\Luisa\Downloads\Godot_v4.7.2-stable_mono_win64\…\Godot_v4.7.2-stable_mono_win64_console.exe` (4.7.2.stable.mono), `--headless --path <repo> --script res://scripts/test/<x>.gd`; Vulkan: `--rendering-driver vulkan --resolution 1280x720`, GTX 1650 SUPER. Текущая доступность — UNKNOWN.
- Исторические внешние launchers были на Python, с лимитом 60 с, сохраняли `*-launch.json`, `*-console.log`, `*-engine.log`. Один launcher падал на cp1251 при печати «✅» — урок: raw bytes сохранять как есть, декодировать UTF-8 с `errors="replace"`, собственный stdout harness — только ASCII.
- WORLD-00B применял `--quit-after 600` как ограничитель. Этот флаг завершает процесс с exit 0 без completion — ровно тот ложный успех, который Q1 обязан ловить. Harness его не использует.
- Известные environment-сообщения в каждом историческом запуске: `ERROR: Failed to read the root certificate store.` и ошибка записи `user://logs/godot.log`. Без явного решения они делают любой «zero unexpected errors» недостижимым (решение D2).
- ObjectDB: «6 ObjectDB instances leaked» наблюдался непостоянно (replay RIGHT, rider, route-plan); причина не найдена. Это задача Q2; Q1 обязан его только надёжно фиксировать.
- TEST_MATRIX accepted digest `7aa5b5b6…e54d2` воспроизводится **только на LF-содержимом**; рабочая копия с CRLF даёт `92d3f50b…`. Identity считается по git blob / LF-нормализованным байтам, не по сырым файлам рабочего дерева.

### 2.3 Unknown (не угадывается, калибруется в M1 на реальном выводе)

Точный текст leak/parse/script-error строк Godot 4.7.2; поведение проваленного `assert()` и runtime error без debugger; сбрасывается ли stdout при принудительном kill; длительности runners; наличие Python на машине; доступность GPU/display для Vulkan.

## 3. Target behaviour

```
python tools/verify/sc_verify.py run --suite <id>[,<id>…] | --set pilot  --godot <exe> --output-root <dir outside repo>
python tools/verify/sc_verify.py list | check-manifest | selftest
```

Поток: `harness → существующий --script entry point → реальные production systems`. Harness не содержит игровой математики, не дублирует oracle тестов и не импортируется игрой.

Exit code harness: `0` — все выбранные checks PASS; `1` — есть FAIL; `2` — FAIL нет, есть INCOMPLETE; `3` — ошибка самого harness (тоже не PASS).

Исключено из Q1: поддержка всех 204 rows; параллельный запуск; retry (повтор «до зелёного» запрещён — каждый повтор есть новый run_id); CI-конфигурация; чтение/оценка PNG по содержанию; E7; baseline-сравнения; ObjectDB root cause.

## 4. Technology decision

| Критерий | Python 3 stdlib | PowerShell | Godot/GDScript orchestrator |
|---|---|---|---|
| Timeout + kill дерева | `subprocess` + Windows Job Object через `ctypes` (KILL_ON_JOB_CLOSE), POSIX `killpg`; fallback `taskkill /T /F` | `Start-Process`/`Wait-Process` есть; kill дерева — вручную через CIM, хрупко | `OS.execute` блокирует без timeout; `create_process` не даёт stdout — это и есть источник проблемы F1/F2 |
| stdout/stderr раздельно, raw bytes | да, потоковая запись в файлы | перенаправление меняет кодировку (UTF-16/OEM), ErrorRecord-обёртки stderr | нет раздельного захвата |
| JSON / SHA256 / PNG header | stdlib | есть, но 5.1 и 7 различаются | есть |
| Windows + будущий CI (Linux runner) | один код | 5.1 только Windows; `pwsh` — отдельная установка | переносимо, но п.1 |
| Новые зависимости | интерпретатор (уже применялся историческими launchers), 0 пакетов | 0 на Windows | 0 |
| Независимость от проверяемого | полная | полная | harness падает вместе с движком; parse error проекта ломает сам launcher |
| Поддержка Codex | высокая | средняя | низкая для process control |

**Выбор: Python ≥ 3.10, только stdlib.** Решающие причины: надёжный kill дерева процессов, побайтный захват потоков, независимость от движка, один код для Windows и CI. Риск: Python на машине не подтверждён — M0 проверяет `python --version`; при отсутствии → STOP и human decision (PowerShell — запасной вариант, требует amendment).

## 5. KEEP / ADAPT / REPLACE / RETIRE

| Объект | Решение | Обоснование |
|---|---|---|
| Все 66 `.gd` в `scripts/test`, assertions, thresholds, seeds | KEEP, байты не меняются | test integrity; Q1 — внешний слой |
| `test_sprint_4m_master.gd` как orchestrator | KEEP как есть; **ADAPT на уровне harness**: master запускается ради native tiers 5–7, а 5 children harness запускает напрямую отдельными checks | F1–F3: child evidence через master недостижимо без изменения master |
| Внутренние 55-с watchdogs и reason-коды (`AUDIT_COMPLETE`, `REPLAY_DIAGNOSTIC_SUMMARY`, `SESSION_LOG_TEST_SUMMARY`, `SURFACE_CONTRACT_SUMMARY`) | KEEP, используются как completion markers | уже дают status/reason |
| Manifest capture helper / session logger | KEEP, читаются как artifact evidence | содержат effective seed, driver, frames |
| Командный шаблон matrix §3 | KEEP; harness добавляет только `--log-file` и user-args roots | никаких семантических флагов |
| Ручной запуск + чтение консоли как acceptance | REPLACE harness-записью для поддержанных suites | Master Q1 |
| Исторические внешние launchers | не переносятся; REFERENCE по описаниям | вне repo, hardcoded paths |
| `--quit-after` как ограничитель | RETIRE для verification-запусков | даёт exit 0 без completion |
| TEST_MATRIX categories / E-capabilities | KEEP; harness ссылается, не меняет | Q0 authority; C10/C12 остаются OPEN |

## 6. Architecture, ownership, contracts

### 6.1 File layout (весь harness — в одном каталоге вне `res://` scan)

```
tools/verify/
  .gdignore                 Godot не сканирует и не импортирует каталог
  .gitignore                __pycache__/
  README.md                 запуск, exit codes, reason codes, как добавить adapter
  sc_verify.py              CLI: run | list | check-manifest | selftest
  harness/
    process.py              spawn, timeout, kill дерева, orphan check, raw capture
    identity.py             revision/dirty/source digest, engine identity, run_id
    evidence.py             разбор engine output, markers, counters, artifacts
    classify.py             единственное место, где выводится PASS/FAIL/INCOMPLETE
    manifest.py             загрузка/валидация suites.json, сверка с TEST_MATRIX
    report.py               result.json / run.json, schema validation
  suites.json               coverage manifest поддержанных checks
  schema/result.schema.json, schema/run.schema.json
  selftest/                 unittest: classify по записанным log samples, process control
  fixtures/probe_project/   отдельный мини-проект Godot: project.godot + probes/*.gd
```

`classify.py` — единственный владелец результата; adapters только извлекают факты. Adapters — данные в `suites.json` (regex, пути, счётчики), а не код на каждый suite: один общий extractor с 4 видами evidence (stdout regex, counter regex, JSON-файл, набор меток).

### 6.2 Dependency direction

`sc_verify.py → harness/* → OS process (Godot) → scripts/test/* → production`. Обратных зависимостей нет: ни один `.gd`, сцена или `project.godot` не знает о harness. `suites.json` ссылается на matrix row IDs; matrix на harness не ссылается.

### 6.3 Coverage manifest (`suites.json`), одна запись

```
id, entry (res://…​.gd), kind: check | expected_negative | probe
matrix: { rows:[ID…], categories:{ID:cat}, role, e_capability:[…], limitations:[C02,…] }
launch: { mode: headless | vulkan, user_args:[…], timeout_s, cwd: repo }
completion: [ { kind: stdout_regex | json_file, pattern | path+field+equals } ]
coverage.expected: [ { id, kind: label_set | counter_min | frames | seeds | distance, … , basis } ]
assertions: { expected: n|null, expected_basis, actual_from: counter_regex | label_count | null }
fail_markers: [regex]          explicit assertion/contract violation
expected_negative: { exit: nonzero, reason_regex, expected_engine_messages:[regex] }
artifacts.required: [ { glob, min_count, checks:[exists, fresh, png_header, json_field] } ]
engine_policy: { errors: zero_unexpected, leaks: zero_unexpected, expected:[regex] }
evidence_gate: { E5: { requires:[driver_vulkan, frames_saved], human_review: required } }
```

`check-manifest` проверяет: каждая row ID существует в TEST_MATRIX с той же category; LF-digest matrix равен зафиксированному в manifest; entry-файл существует; N/A-artifact не объявлен check. Несовпадение → harness отказывается запускать (`MANIFEST_MATRIX_MISMATCH`). Так изменение matrix не может пройти незамеченным, а harness не может «переклассифицировать».

### 6.4 Result schema `slow-cycle.verify.result/1` (per check)

| Группа | Поля |
|---|---|
| identity | `schema`, `run_id`, `check_id`, `attempt` (всегда 1), `kind` |
| revision | `head`, `branch`, `dirty`, `status_porcelain`, `tracked_diff_sha256`, `source_digest` (LF-нормализованные tracked files `scripts/`, `scenes/`, `assets/`, `project.godot`), `harness_digest`, `manifest_digest`, `matrix_digest` |
| matrix | `rows`, `categories`, `role`, `e_capability`, `limitations` — копия из manifest |
| config | `seed_policy`, `requested_seeds`, `effective_seeds_observed`, `effective_seed_basis` (`session_manifest` / `stdout` / `not_observable`) |
| command | `argv`, `cwd`, `env_overrides`, `engine: {path, sha256, version_output}`, `platform` |
| timing | `start_utc`, `end_utc`, `duration_s`, `timeout_s`, `timed_out`, `kill: {method, tree_terminated, survivors}` |
| process | `spawned`, `exit_code` (null при kill), `signal` |
| completion | `required[]`, `observed[]`, `satisfied` |
| coverage | `expected[]`, `actual[]`, `missing[]`, `satisfied` |
| assertions | `expected {value, basis}`, `actual {value, basis}`, `failed`; `basis ∈ runner_counter / stdout_label_count / not_measurable`. При `not_measurable` значение `null` — число не выдумывается |
| engine | `parse_errors[]`, `script_errors[]`, `errors[]`, `warnings[]`, `leaks {objectdb, resources, other}[]`, `expected_matched[]`, `environment_noise[]`, `unexpected[]`, `log_complete` |
| artifacts | `[{path, role, bytes, sha256, mtime_utc, fresh, checks}]`, `required_missing[]`, `stale[]` |
| evidence | `levels_supported[]`, `levels_blocked[{level, reason}]`, `human_review_pending[]` |
| verdict | `result`, `reason` (primary code), `reasons[]` (все), `notes` |

`run.json` (aggregate): run identity, список checks с result/reason, счётчики PASS/FAIL/INCOMPLETE, выбранный set, checks из set, которые не были запущены (сам факт → run INCOMPLETE), `overall`. Schema расширяется добавлением полей; смена смысла существующего поля требует `/2`.

### 6.5 Classification (детерминированный порядок)

1. Harness не может доверять собственным входам (manifest invalid, unknown suite, schema violation результата, малформный summary) → `INCOMPLETE` c `HARNESS_*` / `MALFORMED_RESULT`. Неизвестное состояние никогда не становится PASS.
2. Собрать **все** FAIL-evidence и **все** INCOMPLETE-evidence. Есть хотя бы одно FAIL → `FAIL`, недостающее coverage перечислено в `reasons` (правило `.agent/PLANS.md`: при обоих — FAIL).
3. Иначе есть INCOMPLETE-evidence → `INCOMPLETE`.
4. Иначе `PASS`. Обязательны одновременно: process spawned и завершился сам; exit code ожидаемый; все completion markers; coverage satisfied; required artifacts свежие и валидные; `engine.unexpected` пусто; log complete.

| Наблюдение | Result | Reason |
|---|---|---|
| Runner summary с failures > 0 / fail marker / `Assertion failed` | FAIL | `ASSERTION_FAILED` |
| Expected-negative: неверная причина, либо принят (exit 0) | FAIL | `NEGATIVE_WRONG_REASON` / `NEGATIVE_ACCEPTED` |
| Unexpected engine error / script error при `zero_unexpected` | FAIL | `UNEXPECTED_ENGINE_ERROR` |
| ObjectDB / resource leak warning при `zero_unexpected` | FAIL | `UNEXPECTED_LEAK` |
| Parse error проекта или entry | FAIL | `ENGINE_PARSE_ERROR` |
| Exit 0, completion marker отсутствует | INCOMPLETE | `COMPLETION_NOT_PROVEN` |
| Exit ≠ 0 без fail-evidence (crash, ранний quit) | INCOMPLETE | `NONZERO_EXIT_UNEXPLAINED` |
| External timeout (kill) | INCOMPLETE | `TIMEOUT` (+ FAIL-причина, если в выводе уже есть assertion failure) |
| Внутренний watchdog runner: `status=INCOMPLETE reason=TIMEOUT` | INCOMPLETE | `RUNNER_TIMEOUT` |
| Coverage ниже declared (frames, seeds, labels, routes) | INCOMPLETE | `COVERAGE_MISSING` |
| Required artifact отсутствует / невалиден | INCOMPLETE | `ARTIFACT_MISSING` / `ARTIFACT_INVALID` |
| Artifact старше старта процесса или вне run dir | INCOMPLETE | `ARTIFACT_STALE` |
| Effective seed не наблюдаем либо ≠ requested, когда coverage требует seed | INCOMPLETE | `SEED_NOT_CERTIFIED` |
| Vulkan evidence отсутствует (driver ≠ vulkan, headless) | INCOMPLETE для E5 claim | `VULKAN_EVIDENCE_MISSING` |
| Expected-negative упал произвольным crash/timeout | INCOMPLETE | `NEGATIVE_NOT_EXERCISED` |
| Engine не найден / не стартовал / log обрезан | INCOMPLETE | `ENGINE_UNAVAILABLE` / `LOG_INCOMPLETE` |
| Остались живые дочерние процессы после kill | INCOMPLETE | `ORPHAN_PROCESS` |
| Нет adapter (generic `--script` запуск) | максимум INCOMPLETE | `NO_ADAPTER_COMPLETION_UNPROVEN` |

Строки про engine error / leak / parse error отнесены к FAIL как продемонстрированное нарушение zero-error gate (world AGENTS G). Это предложение — решение D1.

Assertions: `expected` заполняется только когда число действительно известно из исходника (с `basis`); `actual` — только из вывода процесса. Expected budget master никогда не копируется в `actual`.

### 6.6 Process lifecycle и timeout policy

1. Preflight: engine существует, `--version` записан; repo root; manifest валиден; output root вне repo и доступен на запись.
2. Run directory: `<output-root>/<UTC>-<8 hex>/`; создаётся с `exist_ok=False`, коллизия → отказ. Внутри `checks/<check_id>/{stdout.log, stderr.log, engine.log, diag/, audit/, result.json}` и `run.json` в корне. Harness никогда не пишет в repo и не удаляет чужие каталоги.
3. Запуск: `<godot> [--headless | --rendering-driver vulkan --resolution 1280x720] --path <repo> --log-file <engine.log> --script <entry> -- --diagnostics-root=<diag> --audit-output-root=<audit> [declared user_args]`. cwd = repo. Env: копия окружения без изменений. `--seed=` не передаётся никогда, кроме явного `user_args` конкретной записи manifest.
4. Потоки пишутся на диск по мере поступления сырыми байтами; разбор — после завершения.
5. Timeout на check из manifest. Правило: внутренний deadline runner + запас (55 с → 90 с); для остальных — измеренная в M1 длительность × 3, округлённая вверх, минимум 60 с. Таймер один, монотонный; продления нет.
6. По timeout: завершить всё дерево (Job Object / `killpg`), подождать, проверить отсутствие выживших; результат kill записан. Master с children покрывается тем же механизмом.
7. Artifact freshness: файл принимается только если лежит внутри каталога этого check **и** `mtime ≥ start`. Старые файлы в `user://` не ищутся вовсе.
8. Запись `result.json` атомарная (temp + rename). Прерывание harness оставляет run без `run.json` → такой run не является результатом.
9. Cleanup: только собственные дочерние процессы. Run directories не удаляются автоматически.

### 6.7 Engine output policy

Разбираются `stdout`, `stderr`, `engine.log`. Категории: parse error, script error, `ERROR:`, `WARNING:`, leak (ObjectDB / resources in use / orphan). Регулярные выражения фиксируются в M1 по **реальному** выводу 4.7.2 и хранятся в одном месте с примерами в `selftest/`.

Три списка, все видны в результате, ничего не подавляется (в редакции §A3/§A4):

- `expected` — объявлены в записи manifest (например, ERROR от намеренно битого PNG в capture contract; diagnostics самого expected-negative). Сверяются по точному regex.
- `environment_noise` — только точные, узкие, документированные записи с rationale и привязкой к окружению (§A4); `user://logs` permission глобально не allowlist-ится; оригинал остаётся в raw logs и в result.
- `unexpected` — всё остальное. Непусто → не PASS.

## 7. Initial supported suites (Q1 acceptance set)

Критерий отбора — потребности Q2 (G-gates, rider, fork behaviour, Vulkan captures, ObjectDB наблюдение, master) и по одному представителю каждого класса runner. Запуски bounded, по одному разу, и **не являются Q2 baseline**.

| Класс | Check (entry) | Matrix rows | Completion / measured evidence | Ограничение, сохраняемое в результате |
|---|---|---|---|---|
| Domain | `test_road_graph.gd` | GRAPH-* | `OVERALL VERDICT` + `TOTAL/PASSED/FAILED` counters | DAG rows — LEGACY (C01) |
| Domain, G | `test_seed_diversity_matrix.gd` | DIVERSITY | `SEED DIVERSITY WATCHDOG PASSED/FAILED` + 4 criteria lines | aggregate boolean (C04) |
| Domain, G | `test_monotony_profiler.gd` | MONOTONY | `Watchdog Summary: N violations … 3 seeds` | «No mountain sections» = vacuous coverage, пишется в `coverage.missing` (C04) |
| Mixed / subprocess | `test_sprint_4m_master.gd` | MASTER-AIR/SEED/SCENE; MASTER-SUB | `MASTER_VERIFICATION_PASS` + 6 invariant lines + 5 seed lines; MASTER-SUB: `actual = null`, сертифицируется только прямыми запусками children | 125 = expected budget (C02) |
| ↳ children | `test_diagnostics.gd`, `test_track_verification.gd`, `test_track_ride.gd`, `test_riding_lab.gd`, `test_gravel_loop.gd` | DIAG-*, TRACK-*, LAB-*, GRAVEL-* | final success line + **число наблюдённых меток** (`[VERIFICATION #1..68]`, `[PASS G1…A3]`) как `stdout_label_count` | optional-node skips не детектируются (C02/C07) |
| Real physical rider, G | `test_virtual_rider_bot.gd` | RIDER | `VIRTUAL PHYSICAL RIDER BOT COMPLETED` + `Distance Covered` | gate 70 % не меняется; дистанция и `PARTIAL_ROUTE` записываются (D3) |
| Teleport / proxy | `test_route_branch_integration.gd` | ROUTE-LOCK, ROUTE-SPACE | `ROUTE_INTEGRATION_SUMMARY failures= routes=`; expected routes = 8 | не physical ride (C03); исторически failures=9/routes=4 — ожидается честный FAIL/INCOMPLETE |
| Diagnostics / logger | `test_session_diagnostics.gd` | LOG-RUNTIME, LOG-UNIT | `SESSION_LOG_TEST_SUMMARY checks= failures=` + summary JSON + 3 manifests с effective seeds 184729/42/77777 | намеренные I/O errors — `expected` |
| Replay | `replay_session_diagnostic.gd` | REPLAY | `REPLAY_DIAGNOSTIC_SUMMARY status=PASS checkpoints= choices=`; manifest берётся из свежего output предыдущего check **того же run** | geometry-only (C06) |
| Vulkan / capture, G | `capture_visual_audit.gd` (vulkan) | CAP-VIS | `AUDIT_COMPLETE status=CAPTURE_COMPLETE frames=8/8`; manifest `driver=vulkan`; 8 PNG: существуют, свежие, PNG header 1280×720, sha256 | E5 остаётся `human_review_pending`; teleport (C05) |
| Existing negatives | `test_capture_audit_contract.gd -- --audit-case=seed_mismatch \| missing_target \| save_failure`; `capture_visual_audit.gd -- --audit-timeout=0.01`; `-- --audit-frame=zz`; `replay_session_diagnostic.gd` без manifest | CAP-CONTRACT, CAP-VIS, REPLAY | exit ≠ 0 и точная причина: `SEED_MISMATCH`, `COMMITTED_TARGET_MISSING`/`TARGET_OUTSIDE_PATH` (уточнить в M1), `PNG_SAVE_FAILED:`, `TIMEOUT`, `UNKNOWN_FRAME_FILTER`, `MANIFEST_MISSING` | это проверка чувствительности через реальные существующие пути, тесты не меняются |

Итого 14 positive entries + 6 existing negative invocations. Остальные runners получают только generic envelope (потолок INCOMPLETE) до появления adapter. Отложены с причиной: `test_soak_run` (25 км × 3, длительность неизвестна, C08), `test_surface_audit_contract`, `capture_seed_audit`, clearance/style audits (C08) — кандидаты первой волны расширения в Q2-плане.

## 8. Compatibility gaps (изменения тестов в Q1 НЕ предлагаются)

| Gap | Суть | Что делает Q1 | Минимальное возможное изменение теста (отдельное approval, вне Q1) |
|---|---|---|---|
| CG1 | Master не передаёт вывод/timeout/`--path` children | прямой запуск children; MASTER-SUB `actual=null` | master печатает вывод child всегда — не предлагается |
| CG2 | Fixed labels вместо счётчиков (diagnostics, gravel, lab, track ×2) | `stdout_label_count` + limitation | единая строка `…_SUMMARY checks= failures=` |
| CG3 | `assert()`-runners без счётчика и marker | completion = exit 0 + отсутствие script error; `assertions.actual=null` | финальная marker-строка |
| CG4 | C08: effective seed неизвестен | seed coverage сертифицируется только по session manifest; иначе `SEED_NOT_CERTIFIED` | отключение randomization в runner — решение world/test owner |
| CG5 | Rider gate 70 % | фиксируется факт + limitation | вне Q1 (C03) |
| CG6 | Children master не принимают user-args → их output roots не изолируются | только при запуске через master; прямые запуски изолированы | — |

## 9. Allowed files (exact whitelist будущей реализации)

| Операция / path | Responsibility |
|---|---|
| CREATE `tools/verify/.gdignore`, `tools/verify/.gitignore` | изоляция от Godot scan; игнор `__pycache__` |
| CREATE `tools/verify/README.md` | usage, exit/reason codes |
| CREATE `tools/verify/sc_verify.py` | CLI |
| CREATE `tools/verify/harness/__init__.py`, `process.py`, `identity.py`, `evidence.py`, `classify.py`, `manifest.py`, `report.py` | см. §6.1 |
| CREATE `tools/verify/suites.json` | coverage manifest pilot-набора |
| CREATE `tools/verify/schema/result.schema.json`, `tools/verify/schema/run.schema.json` | schema v1 |
| CREATE `tools/verify/selftest/test_classify.py`, `test_process.py`, `test_manifest.py`, `selftest/samples/*.log` | unit self-tests и записанные образцы вывода |
| CREATE `tools/verify/fixtures/probe_project/project.godot`, `probes/*.gd` (11 probes, §11) | **новые negative fixtures harness** — явный пункт для approval по `scripts/test/AGENTS.md` |
| MODIFY `implementation_plan.md` | approval, progress, reports; затем NO_ACTIVE_PLAN |
| MODIFY `docs/TEST_STRATEGY.md`, `docs/CURRENT_PROJECT_STATE.md`, `docs/README.md` | только статус/навигация Q1 |
| CREATE `docs/plans/completed/Q1.md` | только после VERIFY PASS + independent REVIEW PASS |

DELETE: none. Run outputs — вне repo, не tracked.

## 10. Forbidden files

Все `scripts/test/**` (включая helpers, `.uid`, AGENTS); `scripts/{player,camera,world,core,ui,audio}/**`; `scenes/**`, `assets/**`, `project.godot`, `default_bus_layout.tres`; root/scoped `AGENTS.md`, `.agent/PLANS.md`, `.agents/skills/**`, `.antigravity/rules/test-integrity.md`; `docs/TEST_MATRIX.md` (байты неизменны), Blueprint, Master, Target Architecture, Legacy Migration Matrix, sprint/history docs; root `.gitignore`. Probe-проект не подключает и не копирует игровые скрипты. Никаких test-only hooks в production.

## 11. Verification и negative verification Q1

Три слоя; ожидаемая классификация зафиксирована **до** запуска.

**A. Self-tests (`sc_verify.py selftest`, без Godot):** classify на записанных образцах; schema validation; manifest↔matrix; process control на дочерних python-процессах (timeout, дерево из двух поколений, orphan check, не-UTF-8 байты).

**B. Probe matrix (реальный Godot, мини-проект `fixtures/probe_project`):**

| # | Probe | Ожидаемо | Reason |
|---|---|---|---|
| 1 | печатает marker + counter, `quit(0)` | PASS | — |
| 2 | печатает summary failures=1, `quit(1)` | FAIL | `ASSERTION_FAILED` |
| 3 | `quit(3)` без вывода | INCOMPLETE | `NONZERO_EXIT_UNEXPLAINED` |
| 4 | бесконечный цикл кадров | INCOMPLETE | `TIMEOUT`; дерево убито, выживших нет |
| 5 | `quit(0)` без marker (аналог `--quit-after`) | INCOMPLETE | `COMPLETION_NOT_PROVEN` |
| 6 | marker есть, но 2 из 3 declared coverage items | INCOMPLETE | `COVERAGE_MISSING` |
| 7 | marker есть, required file не создан; вариант: файл подложен заранее со старым mtime | INCOMPLETE | `ARTIFACT_MISSING` / `ARTIFACT_STALE` |
| 8 | expected-negative печатает другую причину; вариант: завершается exit 0 | FAIL | `NEGATIVE_WRONG_REASON` / `NEGATIVE_ACCEPTED` |
| 9 | entry с синтаксической ошибкой; вариант: runtime error до `quit` | FAIL | `ENGINE_PARSE_ERROR` / `UNEXPECTED_ENGINE_ERROR` |
| 10 | создаёт Node без free, marker, `quit(0)` | FAIL | `UNEXPECTED_LEAK` |
| 11 | запускает внука-процесс и зависает | INCOMPLETE | `TIMEOUT`, `survivors=[]` |
| 12 | малформный summary (`checks=abc`) / неизвестный suite id / битый manifest | INCOMPLETE | `MALFORMED_RESULT` / `HARNESS_UNKNOWN_SUITE` / `HARNESS_MANIFEST_INVALID` |
| 13 | vulkan-check, запущенный headless | INCOMPLETE | `VULKAN_EVIDENCE_MISSING` |

Probes проверяют **harness**, а не игру; они не являются тестами Slow Cycle и не получают matrix category.

**C. Pilot (реальные entry points §7), по одному bounded запуску.** Acceptance — не «всё зелёное», а совпадение записи harness с независимым ручным чтением raw logs каждого запуска: marker, counters, exit, engine messages, artifacts. Честный FAIL/INCOMPLETE pilot-suite (route integration, ObjectDB у rider) — допустимый и ожидаемый исход; он записывается как known failure, не ремонтируется. Existing negatives должны дать точные причины.

Определимость: probes 1–13 и self-tests выполняются дважды; `result` и `reason` идентичны.

E-levels задачи Q1: E0 — фиксируется для каждого запуска как факт; E1–E6 — только как свойство pilot-запусков, не как acceptance игры; E5 — artifact-проверка без visual review; E7 — N/A (harness не ездит). Performance evidence: N/A — оптимизаций нет; длительности записываются как наблюдение.

## 12. Migration path (milestones; stop points)

- **M0 Preflight.** Реальные `git status`; `python --version`; путь и `--version` Godot; GPU/display. Любое расхождение с §0 → STOP.
- **M1 Calibration (read-only запуски).** По одному ручному запуску: probe 10, probe 9, один headless runner, один vulkan capture. Записать точные строки engine output, поведение assert/hang, длительности. Результат — `selftest/samples/` и regex-таблица. Если формат противоречит допущениям §6.5 → amendment до продолжения.
- **M2 Envelope.** `process`, `identity`, `report`, schema, run directory. Probes 1, 3, 4, 5, 11.
- **M3 Evidence + classify.** Engine policy, artifacts, expected-negative. Probes 2, 6–10, 12, 13.
- **M4 Manifest + matrix check.** `suites.json` pilot-набора; `check-manifest`.
- **M5 Pilot.** §7, сверка с ручным чтением; known failures записаны.
- **M6 Docs.** README; три navigation-правки.
- **M7 VERIFY** (`slow-cycle-verify`), **M8 independent REVIEW** (`slow-cycle-review`, свежий контекст), **M9 archive** → STOP. Q2 не начинается.

## 13. Risks

| Риск | Митигация |
|---|---|
| Harness сам выдаёт ложный PASS | один владелец verdict; default = INCOMPLETE; probe matrix с заранее объявленными ожиданиями; independent review читает `classify.py` целиком |
| Regex пропускает leak/error нового формата | калибровка по реальному выводу; неизвестная строка с `ERROR`/`WARNING`/`leak` считается unexpected; образцы в selftest |
| Environment noise делает PASS недостижимым или allowlist превращается в подавление | allowlist короткий, точные regex, human-approved, всегда печатается |
| stdout теряется при kill | параллельный `--log-file`; `log_complete=false` → INCOMPLETE, не PASS |
| Процесс-сирота держит GPU/файлы | Job Object; orphan check; `ORPHAN_PROCESS` |
| Scope creep в framework | adapters = данные; запрет retry/параллелизма/плагинов; лимит ~1000 строк Python (превышение → amendment) |
| Harness незаметно ужесточает/ослабляет gate | verdict следует oracle runner; дополнительные требования только evidence-типа (completion/coverage/leaks), перечислены в §6.5 и утверждаются |
| CRLF искажает digests | LF-нормализация / git blob identity |
| Vulkan-окно недоступно в сессии агента | check честно INCOMPLETE; Q1 acceptance требует хотя бы одного реального vulkan-запуска, иначе Q1 INCOMPLETE |
| Pilot принят за baseline | каждый `run.json` несёт `purpose: "q1-harness-pilot"`; в docs — явный запрет ссылаться как на Q2 |

## 14. Rollback boundary

Удаление каталога `tools/verify/` и Q1-hunks в четырёх Markdown возвращает repo к HEAD `8977813`. Игра, тесты, сцены, ресурсы и governance не затронуты; данных/API миграции нет. Run directories вне repo. Без `reset --hard`, без переписывания истории, чужие изменения сохраняются.

## 15. Legacy impact и следующий dependency

Все существующие gates, known failures и runtime INCOMPLETE сохраняются. C10 и C12 остаются OPEN. Harness делает видимыми C02/C08-пробелы, не закрывая их. Следующий шаг после принятого Q1 — отдельно спланированный Q2 (Frozen Baseline + ObjectDB investigation); этот план его не разрешает.

## 16. Documentation changes

`tools/verify/README.md` (новый владелец описания harness); `docs/TEST_STRATEGY.md` §4–5 — ссылка и статус Q1; `docs/CURRENT_PROJECT_STATE.md` — статус Q1, runtime INCOMPLETE сохранён; `docs/README.md` — навигация; `docs/plans/completed/Q1.md` после обеих PASS. TEST_MATRIX, AGENTS, skills не меняются. Упоминание harness в skill `slow-cycle-verify` — отдельное governance-решение, вне Q1.

## 17. Definition of Done

- Approved ExecPlan (version/digest) и решения D1–D4.
- Diff строго в whitelist §9; forbidden bytes неизменны (проверка хешами).
- Self-tests и probe matrix 1–13: фактическая классификация = объявленной, дважды.
- Pilot §7 выполнен; каждая запись сверена с raw logs; existing negatives дали точные причины; хотя бы один реальный Vulkan-запуск.
- Ни один результат не содержит выдуманного actual count; exit 0 без marker нигде не дал PASS.
- `check-manifest` подтверждает соответствие TEST_MATRIX accepted digest.
- Known failures и limitations перечислены; pilot не назван baseline.
- `slow-cycle-verify` PASS и свежий независимый `slow-cycle-review` PASS; archive; STOP.

## 18. Решения, требуемые от человека

| ID | Вопрос | Предложение |
|---|---|---|
| D1 | Unexpected engine error / leak / parse error — FAIL или INCOMPLETE? | РЕШЕНО (A1/A3): FAIL при нормальном завершении и применимом zero-unexpected gate; shutdown-шум после kill не даёт FAIL; log недоступен → INCOMPLETE |
| D2 | Allowlist environment noise | РЕШЕНО (A4): механизм разрешён, exact/narrow; `user://logs` permission не allowlist-ится глобально; зависимость evidence → INCOMPLETE |
| D3 | Rider: harness следует gate 70 % и лишь фиксирует `PARTIAL_ROUTE` | РЕШЕНО (A5): gate 350/500 сохранён; target/threshold/progress/semantics/limitation раздельно |
| D4 | Новые probe-fixtures в `tools/verify/fixtures/probe_project` и Python как технология | РЕШЕНО (A6): обе позиции одобрены |

## 19. Handoff

- [x] Branch/HEAD/baseline зафиксированы (с оговоркой метода §0).
- [x] Governance, Master Q1, Strategy, Matrix, Q0 record, skills, frozen rule прочитаны; forensic audit launch-путей выполнен по исходникам.
- [x] Architecture, schema, classification, layout, whitelist, pilot set, negatives, risks, rollback, DoD определены.
- [x] Изменён только `implementation_plan.md`. Код, тесты, thresholds, gates, production не тронуты; Godot и harness не запускались.
- [x] Human approval ExecPlan v1.0 + D1–D4 + поправки A1–A7 — получено 2026-10-03 (§A).
- [ ] M0–M9 — не начаты.

### Test Integrity Verification
- [x] Тесты проверяют реальный код? — Q1 не добавляет игровых тестов; harness запускает существующие entry points без моков.
- [x] Изменялись ли файлы тестов? — НЕТ.
- [x] Добавлены ли skip / todo / suppression / type hacks / закомментированные проверки? — НЕТ.
- [ ] Отражает ли зелёный статус 100 % работоспособность? — зелёный статус не заявлен; runtime acceptance остаётся INCOMPLETE.

**План одобрен. Реализация M0–M9 не начата; начинается отдельным шагом по явному указанию человека.**
