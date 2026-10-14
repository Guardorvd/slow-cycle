TASK: BC2 — Procedural Natural Trail Network; ExecPlan v1.0
DATE: 2026-10-14
STATUS: APPROVED — checkpoints 1–2 ACCEPTED; checkpoint 3 (NETWORK) PLAYABLE on 184729 / 3628391, SINGLETRACK gap on 2 seeds — Director decision D-C3 pending
BRANCH: bc2-procedural-trails; BASE/HEAD: 36bf54f085b95be46b91a86d01e30f32dd4821d6 (D3)
WORKTREE: work/slow-cycle (текущий чат)
APPROVAL: v1.0 APPROVED by the Game Director 2026-10-14, conditions 1–6 (Progress §); autonomous until the first full game checkpoint.

---

## Исходное состояние

Несколько процедурных SINGLETRACK, ≥1 TECHNICAL, развилки, альтернативы и возврат; причина тропы — география, конфигурация зависит от seed.

Master чистый. Создан BC2 worktree, fast-forward 5ab4276 → 36bf54f; исходно staged/unstaged/untracked 0/0/0. Production не изменён; другие worktree сохранены; без push/merge в master.

BC1: ручная ST, без общей достижимости; triangle queries лишь возле тропы. 3,6 м расхождения и fast_trail 51 с/~500 с — исторические замеры. Cold-cache suites не FAST.

## Решение

- KEEP R0–R4/ENGINEERED. Чистый TrailNetworkPlanner: география/примыкания/seed → purpose/class/endpoints/directions, ID/отказ. Локальный A*, уточнение и перепроверка; стоимость: уклоны/вода/повороты/ценность альтернативы. Локальный seed, стабильный порядок, бюджет работы; метод уточняется по результату.
- Owners: TrailRealization=line/operations; FinalSurface=geometry; RealizedRoadNetwork=connectivity; Bake/Cache=products → runtime. До поиска дать запрос исходных опубликованных тайлов отдельно от analytic design. Полосу, примыкания, швы и результат SHAPED проверять по опубликованной поверхности; без покрытия — явный отказ. Recovery/контакт окружения используют её же. NATURAL уточняет исходные треугольники без изменения формы.
- SHAPED: существующий BENCH, одна операция/тропа, ≤60 м, |d|≤0,30 м, ≤30 м³; остальные бюджеты BC1 сохранить, вне footprint форма неизменна. Новая операция — поправка плана. Профили — по измерениям/плейтесту, без подгонки ради PASS.
- TECHNICAL: короткий природный спуск/траверс, связанные повороты и смена продольного/поперечного профиля требуют торможения и выбора линии. Спокойные вход/выход, лёгкий возврат. Ширины/материала недостаточно.
- ADAPT T3: реальные порты piece+station + дорожные movements → общий направленный граф. Связь принимается целиком с crossings/примыканиями/возвратом; классы/циклы считаются после публикации. Тупик только запланированный, с целью и обратным проездом. Отказ связи сохраняет сеть; сломанная петля не становится тупиком. PR1 fixed-point не переносится на объединённую сеть; физические дорожные проверки сохраняются.
- К NETWORK NATURAL/SHAPED — default ST/TECH без дубля R6; road score отделён от полноты сети. R5/R6: только выбор ENGINEERED. BC1/off оставить явным воспроизведением. Cache identity включает seed/region/config/algorithm; несовместимые продукты версионировать. Fresh/cache должны совпадать, production key не ослаблять.

## Файлы и исключения

scripts/world/region/: CREATE trail_network_planner.gd, trail_policy.gd; ADAPT trail_realization.gd, realized_road_network.gd, region_network_builder.gd, region_bake.gd, final_surface.gd, final_surface_tile_renderer.gd, region_vegetation_planner.gd; route_planner.gd/road_synthesizer.gd — только выбор backend.
scripts/world/: region_bake_cache.gd, region_world.gd, region_streamer.gd — продукты/запросы/recovery/dev-load.
CREATE scripts/test/{test_bc2_trails,test_region_network}.gd, tools/dev/{fast_trail,capture_bc2}.gd, resources/regions/bc2_trails.json и .uid. test_bc1_trail.gd — только --off-key, assertions неизменны.
Docs: этот план, docs/{BACKLOG_ACTIVE,CURRENT_PROJECT_STATE}.md, итоговый docs/plans/completed/BC2.md.

Защищены player/камера/controls и настройки, старые assertions/oracles/категории, BC1-config. BC3–BC6, landmarks/vistas/Journey, общий микрорельеф/растительность и новый streaming вне scope.

## Checkpoint

1. **SINGLETRACK — 184729 (0,0).** Автоматическая связь дорога–природный участок–дорога: осмысленный объезд → готовый регион/плейтест. FAST: parse + детерминизм, целая связь/отказ по воде на малых данных. T1: placement; T3: проверенный --off-key.
2. **TECHNICAL — 184729.** Техническая альтернатива с лёгким возвратом. FAST: parse + направления/ловушка, профиль/BENCH. Оценить T2 в этом sprint: snapshot с upstream digest, отдельным dev-ключом, dev_fast_path и явным dev-load; несовместимость отклонять. Только dev-key; ускорение не задерживает плейтест.
3. **NETWORK.** Несколько ST, ≥1 TECH, развилки, cross-connections и петли/возврат на 184729 (0,0), 2024 (0,0), 3628391 (3,−2). FAST: parse + достижимость/атомарный отказ/serialization identity. Проверить публикацию/различия seed, записать отказы/стоимость. Нет класса — не готово. Финальный плейтест BC2.

Пакет: 3–5 сохранённых/просмотренных Vulkan placement-снимков (обзор, вход/развилка, характерный участок, выход); лог без критических ошибок; revision/digest, seed/region, cache key, known issues и команда запуска у маршрута. Placement не доказательство езды; cold bake — подготовка, не FAST.

## Проверки и завершение

FAST: parse + 1–3 теста production-логики, цель 10–15 с; записать время/ошибки. Критические дефекты исправить, прочее — backlog.

Риски: поверхность/возврат/пересечения/стоимость/cache. Подтверждённый nondeterminism/cache mismatch/изменение схемы: назвать риск и узкий DEEP-набор. L2/L3, G, мутанты, soak, VERIFY/REVIEW автоматически не запускать. S3 (10 curvature failures) OPEN; D-1–D-4 DEEP NOT RUN. D3 выше исторической обязательной L2 BC2.

После approval — автономно до плейтеста/расширения scope. Done: три плейтеста приняты, классы/связи на dev-seed, без критических дефектов, backlog обновлён. COMPLETE (playtest-accepted), не FORMALLY ACCEPTED.

## Progress

**Approval (Game Director, 2026-10-14).** v1.0 approved with conditions: (1) the local A*/trail planner must not grow into a second R6 — on repeated problems revise the method, not add exceptions; (2) SINGLETRACK/TECHNICAL join the one published network, ENGINEERED keeps working, R5/R6 change only on proven need, composition at network level; (3) several seeds are required; repeated refusals are recorded and brought to the Director, never tuned per seed or hidden; (4) use the fast dev cycle / fast_trail where safe, T1–T3 are not a separate infrastructure phase, the production cache stays correct; (5) D3: after each checkpoint FAST, 3–5 real Vulkan captures and a launch for the Director; no automatic L2/VERIFY/REVIEW/long rides — a confirmed serious risk gets a proposed narrow check first; (6) no BC3–BC6 work. First wanted result: an automatically created, physically connected SINGLETRACK in 184729 that the Director can ride.

**Checkpoint 1 (SINGLETRACK), implementation.**
- `trail_policy.gd` (planning values, separate from R6) and `trail_network_planner.gd` (pure): ports on edge pieces near nodes → port pairs that are a real road detour → A* (4 m lattice, 16 neighbours, work budget) on the **published ground** (`FinalSurface.published_ground`, the off tile triangles; analytic design is not used for the search) → simplified / corner-cut control points with an oblique road exit → raster screen → exact `TrailRealization.realize` on the published triangles of the line's zone. Stable order; seed only as a derived tie-break.
- `region_bake.gd`: a configuration with schema `slow_cycle.trail_network/1` goes to the planner; the BC1 publication loop is unchanged (factored as `_publish_trails`); a proposal rejected at publication gives way to the next (≤ 3). BC1 configurations take the old path unchanged.
- `resources/regions/bc2_trails.json` (seed-independent, `max_trails: 1`); runtime HUD shows class and reason; `tools/dev/fast_trail.gd` (T3: verified `--off-key`, writes no cache), `tools/dev/capture_bc2.gd` (placement captures).
- Off products of 184729 at the BC2 base equal the BC1 baseline (tiles `c94451cf…`, network `183eef0c…`, vegetation `35212949…`; fresh bake 408 s).
- Fast path on the verified off key: 189 ports, 30 pairs, 3 searches → 3 proposals pass the exact check (planner 10 s, publication 60 s, total 94 s). Published: `trail:st_6_9_e9_45R_e9_1550R`, MEADOW_SHORTCUT across the neck of the edge:9 loop between junctions 6 and 9, 536 m instead of 1505 m by road, +17.0/−0.8 m, grade ≤ 11.5 %, side slope ≤ 0.29, R ≥ 10.3 m, design/published parity 0.04 mm. Alternates: `st_3_8` (354 m, HILLSIDE_CUT), `st_4_8` (501 m).
- Method revisions so far (measured, not per seed): perpendicular road exits failed the 8 m radius at s ≈ 5 m on 15/30 pairs → one straight oblique exit + lead-out and adaptive corner cutting (0 radius refusals afterwards).
- FAST: parse 12/12; `test_bc2_trails --group=domain` 21/21 in 5.2 s (found and fixed a raster corner-index bug in `ground_height`).
- Production bake (cold, 8 threads, `bake_probe --trail-config=res://resources/regions/bc2_trails.json`): 470 s (network 218 s, tiles 105 s, trails 62 s incl. planner 11.5 s + ground 6.4 s, vegetation 70 s); same trail, published on the first attempt. Digests tiles `11a6c0e5…`, network `10cf2f8b…`, vegetation `7735052e…` — **equal to the fast path** (one case; general parity / 1-vs-N threads = DEEP D-5, NOT RUN).
- PLAYTEST package (checkpoint 1): launch from this worktree hits the cache (`REGION_READY source=cache seconds=2.091`, key `aa78f20a…`). 5/5 Vulkan PLACEMENT captures, stderr empty: `outputs/bc2-evidence/c1/captures/` (overview, join from the road, steepest point 9 %, middle, towards the second join) — not ride evidence. Input rides both ways NOT RUN (D-6): the Director rides.
- Known (non-critical, backlog): the line is gentle and fairly straight — the cost model prefers the easiest ground; character (linked turns, profile changes) is the TECHNICAL checkpoint's work. HUD text cut at 1280 px. The capture tool's bike views stayed first-person.
- STOP: Director playtest of checkpoint 1.

**Checkpoint 1 — ACCEPTED (PLAYTEST), Game Director 2026-10-14** (commits `979192d`, dev spawn launcher `aea8288`). Ride notes: joins to the road network convenient; the trail looks natural; riding is fine but not especially interesting; relief is hardly felt; sometimes there is a wish to take the trail instead of the road. Accepted at this stage; this trail is not to be reworked for a higher subjective score. Flat relief on SINGLETRACK is a known limitation of the current region, not a blocker for TECHNICAL.

**Checkpoint 2 (TECHNICAL) — Director brief 2026-10-14.** A genuinely different riding character (not width, surface or formal limits): find the most suitable place in the existing region, use real relief, turns, longitudinal and side slopes and natural features; rideable entry/exit, accessible return, calm Slow Cycle character, no bike park. If geography limits quality, use the best existing place; no global terrain rework, no BC3 work — evidence and options if the main task cannot be met.

**Checkpoint 2 (TECHNICAL), implementation.**
- Where: the region's relief next to roads was surveyed (road-to-road pairs, published ground). The strongest place is a SW–NE **terrace scarp** inside the edge:9 loop: ~22–25 m over ~70 m, core 25–30 %; every other road-side slope is ≤ 14 %. Flat ground elsewhere is the known limit of this region (Director: not a blocker).
- Character from the bicycle, not from R6: `TrailRealization.limits()` — TECHNICAL is a **descent** from its first node to its second (directions FORWARD only; the road is the way back up), grade ≤ 15° (`RoadSynthesisPolicy` TECHNICAL, measured descent hold), forward climbs ≤ 0.095 (measured sustained rough climb 5.6°), turns ≥ 6 m (comfortable lateral 2.45 m/s² at 13.8 km/h after braking; full lock there ~3 m). A configuration without `class` is realized exactly as before (BC1 / SINGLETRACK unchanged: same ids, metrics, digests).
- Planner: classes in configuration order (`classes: [SINGLETRACK, TECHNICAL]`, `max_trails` per class); a selected trail blocks 10 m around it for later searches. TECHNICAL: ports along whole edges (join to an incident node of the edge, `join_max_m`), high→low pairs with a real drop (≥ 12 m, ≥ 9 % along the straight) and a longer way back by road; directed A* around a 15 % target descent; **linked turns**: sine offsets of the corridor (7 shapes, R ≈ 7–15 m) screened, the most technical passing one kept; ranking by mean descent, steep share, turns per 100 m (measured revision: by raw turns a 6 % slope with 15 wiggles won — artificial; fixed in the method, not per seed).
- 184729 result: `trail:tech_9_6_e9_1070R_e9_110R`, SLOPE_DESCENT from the upper terrace road (edge:9 s≈1070) down the scarp to the valley road near junction 6 (≈ 65 m along the road from the checkpoint 1 trail), 224 m, −24.9 m, max grade 23.4 %, descent ≥ 10 % on 61 % / ≥ 15 % on 38 % / ≥ 20 % on 17 % of the off-road line, 7 linked turns, R ≥ 8.4 m, side slope ≤ 0.23, way back by road 960 m. SINGLETRACK: 0 % of its line descends ≥ 10 %, R ≥ 10.3 m. Placement observation (not a ride check): a bike placed at rest on the 23 % pitch rolls to 15–20 km/h within 1.5 s.
- Alternates: `st_3_8`, `st_4_8`, `tech_8_4` (240 m on edge:7). Refusals: 2 × no path.
- Runtime: TECHNICAL ends have dark red boards, the lower (exit) one with a white bar; HUD shows the class; `tools/dev/ride_trail.gd --class=TECHNICAL` spawns at the top (one-way guard).
- FAST: parse 15/15; `test_bc2_trails --group=domain` 31/31 in 8.9 s (TECHNICAL on an analytic scarp: one-way, descends, limits, turns, entry/exit on the road and a way back; 24.5 % fall line TECHNICAL yes / SINGLETRACK no; climbing and unknown-class lines refused).
- Bakes: fast path 144 s; fresh production bake 490 s (trails 112 s); both trails published first attempt; digests tiles `92ecb9bf…`, network `dcf12436…`, vegetation `72a8c863…` **equal** fast path vs fresh (second case).
- PLAYTEST package: cache key `f5356229…`, load 2.0 s from the worktree; 5/5 Vulkan PLACEMENT captures `outputs/bc2-evidence/c2/captures2/` (overview, top join from the road, steepest 23 %, middle, towards the exit), stderr empty — not ride evidence. Input rides NOT RUN (D-6).
- STOP: Director playtest of checkpoint 2. T2 (dev-key snapshot) not built: the fast path + unchanged production bake kept iteration at ~2.5 min / ~8 min without a runtime dev-load; recorded as not needed so far.

**Checkpoint 2 — ACCEPTED (PLAYTEST), Game Director 2026-10-14** (commit `6cb6856`, tag `bc2-c2`). Ride notes: TECHNICAL really demands control, braking and line choice — yes; riding interest already better than SINGLETRACK; naturalness more or less, acceptable at this stage; road visibility good, nothing blocking. This descent is not to be reworked for visual perfection; non-critical remarks go to the backlog of their future phases.

**Checkpoint 3 (NETWORK) — Director brief 2026-10-14.** A finished procedural network, not single good routes: SINGLETRACK and TECHNICAL integrated with BACKBONE/SECONDARY — real forks, alternatives, loops, accessible return, directed passability, no traps — on 184729, 2024, 3628391; generation from world data only, no per-seed tuning. Judge variety over the network as a whole (not every SINGLETRACK hard, not every TECHNICAL extreme). The procedural network becomes standard game functionality, not a dev configuration; the accepted BC1 / BC2 checkpoints stay reproducible for diagnostics. D3; repeated generation refusals: find the concrete cause, evaluate options, bring an architectural obstacle to the Director as a short decision. After checkpoint 3 BC2 should be closable (next: BC3).

**Checkpoint 3 (NETWORK), implementation.**
- Standard functionality: `region_world` bakes `res://resources/regions/trail_network.json` by default (TECHNICAL first, then SINGLETRACK; `max_trails` TECHNICAL 2, SINGLETRACK 3); `--trails=off` = the prototype-off region; `--trail-config=` = any configuration (BC1 `bc1_trail_184729.json`; `bc2_c1_trails.json`, `bc2_trails.json` for the checkpoint configurations — exact checkpoint code at tags `bc2-c1`, `bc2-c2`). HUD: one network line (classes, km, new loops, forks; full width — N-1 fixed).
- Network graph `RealizedRoadNetwork.trail_graph` (pure, not stored): road edges split at joins (both ways), trails FORWARD / both ways by class, trail crossings as fork vertices; strong connectivity (traps), road vs total cycles, forks, per-trail road alternative and way back from the exit. The bake refuses a trail that would make a trap (ERR_TRAIL_TRAP, atomic) and reports the graph.
- Planner: classes in order; a selected trail's 10 m band may be crossed at >= 45 deg (search) / 40 deg (screen), never followed, at most 2 crossings; whole selection published at once, a failed one replaced by an alternate of its class; TECHNICAL ports along whole edges; SINGLETRACK pairs must be climbable at the measured sustained rough climb (5.6 deg) on the straight line, face each other and not cross a road; destinations (lookouts: knoll tops / terrace rims within 420 m and <= 40 m above a port) as a fallback with its own search budget (16); A* caches the ground gradient per node. Method revisions from measured refusals (not per seed): ports along whole edges for SINGLETRACK were tried and reverted (40 searches / 1 trail vs 8 / 3 near junctions); water on the straight line is a recorded diagnostic, not a filter (it hid valid creek detours).
- Results (fresh production bakes, 5 threads, default configuration; fast path agreed on 184729 / 3628391):

| seed / region | road loops | trails published | new loops | forks | traps | bake s | tiles / network / vegetation |
|---|---|---|---|---|---|---|---|
| 184729 (0,0) | 3 | TECHNICAL 2 (scarp descent 240 m, slope descent 240 m), SINGLETRACK 2 (meadow shortcut 538 m = accepted c1 line, hillside cut 356 m) | 4 | 8 | 0 | 593 | `7e520772…` / `c5d5ae47…` / `7a9f336c…` |
| 3628391 (3,−2) | 1 | TECHNICAL 2 (349 m, 276 m; 19–20 % pitches) | 2 | 4 | 0 | 1035 | `1e882298…` / `2bb0500b…` / `70b9b36a…` |
| 2024 (0,0) | 0 | none (products = prototype-off, atomic) | 0 | 0 | 0 | 808 | `a13d40f3…` / `8ad10669…` / `41a7dd30…` |

  Way back from every one-way exit by road: 184729 1004 m / 280 m, 3628391 825 m / 465 m; SINGLETRACK alternatives 2.5–4x shorter than the road.
- Evidence for the gap (ground 30–300 m beside the roads, published): share <= 10 % slope 184729 51 %, 3628391 42 %, 2024 37 %; road loops 3 / 1 / 0; edges 12 / 9 / 6. Cause: the SINGLETRACK rule (a natural alternative between two road points) needs road loops or comparable road levels; 2024 is one straight valley road (no detour, no drop), 3628391's loop arms run 40–80 m above the valley road (pairs fail the climb limit). Destination lookouts were unreachable at the SINGLETRACK limits (beyond 0.30–0.34 slope bands) or gave no pair.
- **Director decision D-C3 (pending):** A accept (trails where road topology gives a reason; variety via BC3 / road generator); B "nature loop" SINGLETRACK when a region has no alternatives (leave a road and rejoin it 300–800 m on through gentle ground >= 100 m from the road; bounded, reuses the two-leg search; weaker natural reason); C planned dead-end spurs to a destination (plan-allowed; TrailRealization / graph one-ended trails; medium architecture; 3628391 reachability limits remain). Recommendation: B for BC2 closure, C considered with BC3 environment work.
- Regression: BC1 configuration on the fast path reproduces BC1 byte-for-byte (tiles `7802b697…`, network `c89164f2…`, vegetation `896ee72f…` = BC1 L2 record).
- FAST: parse 0 failures; `test_region_network --group=domain` 14/14 (~1 s); `test_bc2_trails --group=domain` 31/31, 4.7 s.
- PLAYTEST package: default launch from the worktree hits the cache on all three seeds (1.3–2.0 s); Vulkan PLACEMENT captures `outputs/bc2-evidence/c3/captures/` (184729: 4 trail overviews + spawn with HUD; 3628391: 2 overviews + 2 steepest; 2024: spawn with HUD), stderr empty; top-down maps `outputs/bc2-evidence/c3/net_*.png`, `map_2024.png`. Input rides NOT RUN (D-6).
