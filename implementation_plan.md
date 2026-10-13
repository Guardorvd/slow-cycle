TASK: BC1 — первая природная тропа Slow Cycle; ExecPlan v1.0
DATE: 2026-10-13
STATUS: M4 IN PROGRESS — P2 ACCEPTED (Director, 2026-10-13); formal L2, G, VERIFY and independent REVIEW authorized; no further trail shape changes without a confirmed defect
BRANCH: bc1-natural-trail; BASE: final BC0 2a43bc092b503987a9a2845232a3791b0ad69e21
HEAD AT PLAN DRAFT: a8414ac0a6becc989fef24d060cff40bc8ceb149 (factual errata); submission HEAD/digests in planning manifest
BASELINE: source/new checkout clean (staged/unstaged/untracked 0/0/0); docs-only planning changes
APPROVAL: BC1 ExecPlan v1.0 APPROVED by the Director 2026-10-13 at 48d2cea with conditions 1–3 (network integration, NATURAL geometry integrity, Playable First); local commits only, no push/merge
PREVIOUS: [BC0 COMPLETE](docs/plans/completed/BC0.md); [PR1 SUSPENDED](docs/plans/suspended/PR1.md); roadmap ACCEPTED
EVIDENCE: C:/Users/Luisa/Documents/Codex/2026-10-13/slow-cycle-bc0-accepted-bc1-planning/outputs/bc1-evidence/ (durable, outside repo)

---

## Goal and target behaviour

Первая короткая проезжаемая SINGLETRACK-тропа в регионе 184729 (0,0): дорога → природная тропа → возврат в сеть. NATURAL → человеческий плейтест → оценка скорости итераций → одна локальная операция SHAPED → второй плейтест → формальная проверка.

Reuse region/scene/bake/cache/bicycle. Explicit opt-in; default unchanged. No PR1/N4/Vertical Slice acceptance or pre-playtest dev-cache. Algorithms/storage/grids stay open within these contracts.

Read authority: [roadmap §§3,6,7](docs/ROADMAP_B_C_ROUTE_REALIZATION.md), Master XII-B, Blueprint §§17/35, Target Architecture §8, Migration Matrix B+C, Test Strategy §§7–8, scoped AGENTS/worldgen skill. Native Plan Mode unavailable; execution stopped.

## Observed current state

- BC0 2a43bc0 descends from PR1 beacc9c; scripts/scenes/resources/assets/tools/project.godot are identical. Original checkout remains on bc0-architecture-migration.
- RegionBake already publishes a network, FinalSurface tile arrays shared by render/collision, water, vegetation and spawn; RegionWorld/Streamer load them with the existing bicycle.
- FinalSurface queries evaluate natural/deformer heights, while tile normals derive from triangles. Off-road query/triangle parity is unproven: measure the prototype area before choosing the smallest sufficient solution.
- RealizedRoadNetwork consumes R6 intents. Add a complete trail to the same published network without pretending it is an R6 piece. Existing dead-end/fixed-point rules stay unchanged until BC2.
- PR1 test_region_network/surface/runtime and handoff replacement never existed. Existing ride/capture entries execute network rules but do not assert them. R7 technical LIMITED ALPHA is complete; Director acceptance remains pending.
- Evidence read: BC0 §§1–8, PR1 §§1–7, R7 status; PR1 raw m1_envelope_all_final, m6_head_r6_regions_184729 (365 checks/10 failures), m9_bake_184729/2. First bake has hash errors; current guard/second empty stderr do not certify HEAD. All historical L0/L1 only; full 1-vs-N bake/GPU/L2/VERIFY/REVIEW/E7 unproven, baseline cache key unconfirmed.

## Disposition, ownership and dependency direction

KEEP geography/R0–R4, R5/R6 for ENGINEERED, roads/bridges/fords, player/camera/controls. ADAPT shared surface, network publication, bake/cache, vegetation and recovery for this trail. EXTEND one pure trail-realization owner. REPLACE/RETIRE: none. DEFER procedural network/rules to BC2, broad environment/off-road to BC3.

Flow: world → prototype input → pure trail realization → FinalSurface validation → published network/bake → adapters. Owners: trail=line/mode/reason/operation; FinalSurface=geometry/final queries; RealizedRoadNetwork=connectivity; Bake=products; Cache=I/O; Streamer=render/physics lifetime; RegionWorld=composition/recovery. Renderer consumes height. Workers prepare data, main thread commits physics; no new threading.

## Public contracts

1. Input: seed/region/config identity, existing surface, two network nodes, reproducible line with natural purpose (e.g. terrace passage). Manual prototype data allowed; production seed special-casing forbidden.
2. Output: complete connection, physical joins, directed rideability/return, material/footprint/diagnostics. Atomic publication; rejection preserves roads. Class ≠ mode; no half-loop/hidden deletion.
3. NATURAL preserves shape; new vertices lie on the pre-trail surface. Only trace/material/vegetation change. Common collision, existing gravel/rough/grass layers; no collision ribbon.
4. Final queries/recovery/vegetation agree with published height/normal/material; distinguish design queries. Retain P2 tolerances and fresh/cache equality; bridge deck ≠ ground.
5. SHAPED: one local smoothing of a short ride-identified hazard. Declare boundary/max displacement/budget; outside geometry bit-identical. Record measured budgets/tolerances/rationale before implementation, never enlarge them to pass tests. Another operation needs amendment.
6. Cache identity includes trail config/content; incompatible products get new schema. Key not weakened. Prototype-off preserves geometry/network/R7 fixture hashes (metadata version may differ).

## Allowed files

Exact post-approval whitelist; no deletions:

| Action | Paths | Responsibility |
|---|---|---|
| CREATE | scripts/world/region/trail_realization.gd; resources/regions/bc1_trail_184729.json | Pure realization and explicit line/mode/budget data |
| MODIFY | scripts/world/region/realized_road_network.gd; scripts/world/region/region_bake.gd | Additive complete connection and bake products; unchanged road rules |
| MODIFY | scripts/world/region/final_surface.gd; scripts/world/region/road_terrain_deformer.gd; scripts/world/region/final_surface_tile_renderer.gd | Mask, one operation, query/triangle parity; ENGINEERED parity |
| MODIFY | scripts/world/region/region_vegetation_planner.gd; scripts/world/region_bake_cache.gd | Trail exclusion/contact, identity, serialization |
| MODIFY | scripts/world/region_world.gd; scripts/world/region_streamer.gd; assets/shaders/region_road.gdshader | Opt-in, recovery, publication/material; no player parameter changes |
| CREATE | scripts/test/test_bc1_trail.gd | Compact additive domain/integration/runtime/negative/capture/performance entry using real production and existing bot helper |
| MODIFY | implementation_plan.md; docs/CURRENT_PROJECT_STATE.md; docs/PLAYTEST_MOUNTAIN_RIVER_VALLEY.md | Progress, current facts and human ride instructions |
| CREATE | docs/plans/completed/BC1.md | Only after acceptance, then clear active slot |

Sidecars: only scripts/world/region/trail_realization.gd.uid and scripts/test/test_bc1_trail.gd.uid. Evidence/scratch outside repo. Roadmap errata separately authorized.

Forbidden: all other files; player/scene exports/input/camera/project.godot, R5/R6, existing tests/helpers/fixtures/tools, TEST_MATRIX/governance/skills/authority docs, completed records/PR1 verbatim. Expansion requires approved amendment.

## Migration path and playtest checkpoints

| Step | Work and stop condition |
|---|---|
| M0 | Launch baseline; select short line between two nodes away from crossings/S3. Record coordinates/purpose/directions, query mismatch/riding limits; prototype-off control. |
| M1 | Integrate NATURAL: trace/material/vegetation, joins/recovery/cache; pass L0/L1. Repeated failure prompts a simpler in-scope method. |
| P1 | PLAYABLE package: fixed source, command/seed/region/map/known issues. Human rides road→trail→road, return/off-road; assesses enjoyment/readability/control/desire to continue. **Actual human ride + feedback required before SHAPED**; wait if absent. |
| M2 | Measure edit→READY/cold/cache. Keep cycle if sufficient; data tuning/optional entry spawn allowed after P1. New cache/snapshot/incremental framework requires measured necessity + amendment. |
| M3/P2 | One bounded smoothing; log footprint/budget/SHAPED fraction/volume/attempts/reasons. Check locality/water exclusion/parity; second human ride+feedback. If no useful defect exists, agree its purpose first. |
| M4 | Feedback fixes → final L1 → frozen candidate manifest → one L2 → explicitly invoke slow-cycle-verify → slow-cycle-review in a fresh independent context. Fixes return to author; fresh reports cover changed impact. Missing independence = INCOMPLETE. |
| M5 | Director acceptance and DoD, archive BC1/clear slot. Keep BC0 closed and PR1 suspended. Local sequential commits only; no push/merge or automatic BC2. |

## Minimum first PLAYABLE

One new entry suffices; three full suites are not prerequisites. L0/L1 touched contracts finish without unexpected errors/leaks.

| Property | Evidence before P1 |
|---|---|
| Shape/material | NATURAL shape equality against prototype-off over footprint/boundary; new vertices on original surface; shared render/collision triangles; query/layer material agreement |
| Connection | Both existing nodes and physical joins; Input-driven complete line and return with current bicycle, no teleport during ride; vegetation colliders clear |
| Physics/recovery | 0 ray misses; P2 ≤1 cm road, ≤5 cm ground, ≤1 cm bridge joint if touched; seams ≤1 mm; recovery to loaded rideable surface |
| Data/baseline | One live fresh bake/cache reload with equal geometry/network/layers/vegetation/recovery; on/off/content identity; default baseline smoke without regression |
| Negatives/visual | Invalid input/identity/join and stale cache cases below; saved/read Vulkan views from bicycle at both joins, middle and boundary |

Crash/hang, falling/collision gap on the line, unrecoverable trap, corrupt/inconsistent data, cache≠fresh or baseline regression block P1/P2. Noncritical roughness/visuals/line quality get reproducible coordinates and human evaluation. G/L2 are not automatic playtest prerequisites. PLAYABLE is not phase PASS or E7; only a human declares E7.

## Verification plan and PR1 obligation allocation

| Owner/coverage | BC1 L2 on exact final candidate | Remaining OPEN responsibility |
|---|---|---|
| Trail/network | NATURAL+SHAPED contracts, complete publication/rejection, both directions, off-road ≥150 m and back, recovery | BC2: procedural N1–N6/N4, full network rules/test_region_network, descent-preferred return |
| Handoff gap | Consumed ENGINEERED pieces: graph signature, READY, band, barrier, water body/channel order, seams and oracle path contract; additive assertions, existing oracle unchanged | BC2: remaining full handoff transfer; never silently drop it |
| Surface gap | Queries/geometry/material/locality/cache; unchanged R7 fixture contracts/surface/collision; D10 T2.5 | BC2: general query solution before acceptance; BC3: broad water/environment contact; test_region_surface coverage follows these owners |
| Runtime gap | Touched streaming/collision lifecycle, P1–P4 on scope, stale/corrupt cache, deep-water recovery if reached | BC3: broad freedom/streaming/recovery, test_region_runtime coverage; L3 never absorbs touched L2 |
| Regression | E0; R0/R5/R6 contracts and R7 fixture by impact audit. Reuse/non-impact requires Test Strategy §7.2 proof; doubt means run. R6 regions 184729/2024/int64 if their closure/behaviour is affected | Untouched unrun PR1 region rows remain BC2; S3 below |
| G | Q1 seed_diversity, monotony, virtual_rider, capture_visual_vulkan mandatory; audit includes PR1 mode_select→region, not just BC1 diff | Mandatory before future master merge too |
| Determinism | Two fresh processes and full bake 1 vs 8 threads on 184729; on/off/content identity; default-off 2024 vs baseline, different seeds differ | Full procedural battery BC2 |
| Holdout | Default-off 3628391 at (3,-2), a disclosed PR1/R5 regression case held out from BC1 tuning; all additional declared suite rows reached by shared changes run under §7 | No claim of procedural trail robustness from one configured line |
| Mutants | Scratch-only shape movement, split collision, stale config, out-of-footprint SHAPED and partial publication must be caught; PR1 feedback-off/deck-flooding/v1-limits run if impacted, otherwise record proof and BC2/BC3 owner | No old mutant certified by unrelated coverage |
| E5/E6 | ~12 useful Vulkan/diagnostic views of both modes/joins/off-road/materials; isolated GPU 20-min ride, memory/ObjectDB/create-release | C10/C12 OPEN, whole-game INCOMPLETE; L3 after BC2/BC5/R19 |

Retain touched-runtime PR1 performance gates: cold bake ≤10 min, cache ≤20 s; GPU max frame ≤100 ms, p99 ≤33 ms, p50 ≥60 FPS, memory growth ≤5%, no leaks. Compare baseline/candidate under equivalent workload, engine/GPU/driver/concurrency. Fixed-fps headless is not GPU evidence. No speedup claim without measurements.

S3's ten curvature failures remain **OPEN / KNOWN FAILURE** (Director 2026-10-13), distinct from FinalSurface principle S3. No old-R6 repair campaign. Compare failed piece IDs against chosen joins/ride; prove no safety/mandatory-scope impact. If implicated, stop dependent acceptance and escalate concrete evidence. A mandatory check's FAIL blocks formal PASS; historical FAIL never becomes PASS/waiver. Assess S3 with relevant geometry and formal BC2 acceptance.

## Negative verification, commands and evidence

New proposed reasons: invalid/nonfinite/out-of-bounds → ERR_TRAIL_INPUT; wrong world identity → ERR_TRAIL_IDENTITY; absent join/return → ERR_TRAIL_CONNECTION; unsafe line → ERR_TRAIL_UNRIDEABLE; footprint/budget violation → ERR_TRAIL_BUDGET. Each real rejection preserves the original network with no partial trail. Water/deck intersection is rejected as unsafe: new crossings are out of scope. Stale/corrupt cache → existing ERR_BAKE_STALE and rebuild. Wrong reason/crash/timeout is not negative PASS.

`<G>` is the found Godot 4.7.2 stable mono console under Downloads/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64/. `<repo>` is this checkout; `<E>` a fresh EVIDENCE run directory. Execute only after approval:

```text
<G> --headless --path <repo> --editor --quit
<G> --path <repo> res://scenes/region/region_world.tscn -- --seed=184729 --region=0,0 --bake-threads=8
<G> --path <repo> res://scenes/region/region_world.tscn -- --seed=184729 --region=0,0 --bake-threads=8 --trail-config=res://resources/regions/bc1_trail_184729.json
<G> --headless --path <repo> --script res://scripts/test/test_bc1_trail.gd -- --group=domain --seed=184729 --out=<E>
<G> --headless --path <repo> --script res://scripts/test/test_bc1_trail.gd -- --group=integration --seed=184729 --out=<E>
<G> --path <repo> --script res://scripts/test/test_bc1_trail.gd -- --group=runtime --seed=184729 --out=<E>
<G> --headless --path <repo> --script res://scripts/test/test_final_surface.gd -- --source=fixture --group=contracts
python tools/verify/sc_verify.py run --suite seed_diversity,monotony,virtual_rider,capture_visual_vulkan --godot <G> --output-root <E>
```

trail-config and test_bc1_trail are proposed interfaces, absent today. Repeat R7 for surface/collision. Other existing suites use their original CLI unchanged. New groups cover on/off/NATURAL/SHAPED, negatives, cache and performance; declare named expected assertions before runs, record actual counts/coverage/completion afterwards. Counts and exit 0 alone prove nothing.

Timeouts: E0 120 s, new domain 120 s, integration 1200 s/case, runtime 2400 s including cold load + 20-min ride, R7 600 s/group. Other existing suites retain approved limits; G uses Q1 240/240/240/180 s. Runs sequential, one Vulkan, isolated timings. Timeout → INCOMPLETE, never waived. Keep raw logs, argv, engine hash/GPU/driver, seeds/config, plan/source/diff hashes, duration, expected/actual assertions, artifacts, errors/leaks. Reuse only with closure proof and original verdict. L2 target ≤5 h including G; L1 ≤1 h/milestone, VERIFY ≤2 h, REVIEW ≤1.5 h. Overrun never removes checks.

## Risks, rollback and legacy impact

Query/triangle drift → measure published geometry; R6-only payload → additive trail publication, no fake intents; stale cache → content/on-off negatives; poor riding → early human; solver growth → one bounded operation; S3 → piece-level applicability. Choose first line away from complex crossings.

Rollback: disable opt-in or return to an earlier branch commit, preserving history/user cache. pr1-suspended-baseline remains beacc9c4258c4abfaec58443cf6e6a25b7b7140d; use a separate checkout and default launch above, engine/seed/config from [PR1 §6](docs/plans/suspended/PR1.md). Cold bake reproduces baseline; cache key remains unconfirmed. Keep historical failures/evidence. L3 is a separate post-BC2 (R8+R13), BC5 and R19 task.

## Definition of Done, approval and ledger

Both human rides and feedback; complete NATURAL+one SHAPED connection; baseline intact; required L2 coverage/E0–E6, VERIFY PASS, independent REVIEW PASS, Director acceptance; current docs, limitations and durable evidence. Only then archive/clear slot. E7 overall region remains human/BC5. Today runtime/tests NOT_RUN, implementation NOT_STARTED.

Approve **BC1 ExecPlan v1.0** including whitelist, one new additive test entry, obligation allocation and the one post-P1 operation. Existing B+C/PR1/G/S3 decisions need no repeat approval. Local line/algorithm/parameters are developer choices within measured contracts. Separate approval only for actual scope/protected test/player/gate expansion, another operation, necessary new dev-cache or a serious product compromise.

STOP: [.agent/PLANS.md](.agent/PLANS.md) requires “save one reviewable plan ... and STOP for explicit human approval”; [slow-cycle-worldgen §1](.agents/skills/slow-cycle-worldgen/SKILL.md) requires “STOP until their concrete plan is approved”. No production changes before approval.

Ledger (wall / aggregate hours, ±0.25 h): planning in submission manifest; Implementation/L0/L1/L2/VERIFY/REVIEW/Closeout NOT_STARTED. On execution maintain separate rows and both verification-overhead ratios per Test Strategy §7.6.

## Amendment A1 — P1 feedback, line character and the one SHAPED operation (Director 2026-10-13)

Authority: Director decision "BC1 — P1 Human Feedback Accepted / Proceed to SHAPED", 2026-10-13. It replaces only the content of the one SHAPED operation (contract 5, step M3/P2). Files, contracts, gates and the rest of the plan are unchanged.

**P1 control.**
- Tag `bc1-p1` = `0f635f7`.
- Configuration copy and published line dump: `outputs/bc1-evidence/p1_control/`.

**Line (data only, same purpose, same joins).** `trail:bc1_meadow` keeps nodes 5/4 and pieces edge:4/edge:7.
- It now runs from the valley road south-west to the creek ravine terrace, along the ravine's east bank, out at the creek's bend, and east up the terrace to the loop road.
- Measured on the 0.5 m relief before implementation (`outputs/bc1-evidence/p2/`):
  - ~470 m; +14 m / −3 m; grade ≤ 9.3 %; minimum radius ≈ 20 m (P1: 34 m).
  - Water ≥ 5.4 m from the centre line.
  - Side slope 0.34–0.35 on ~35 m of bank (beyond NATURAL's 0.35 screening), ≤ 0.14 elsewhere.
- No other relief within reach is more expressive: the area is a smooth 3–15 % slope from the river (323 m) to the south-east (348 m); the ravine is the only natural feature. Broader landscape expressiveness is a product observation for BC3–BC5, not BC1 work.

**NATURAL screening limits (provisional).**
- Radius: 8 m, the BicycleController's full-lock radius at 8 m/s (mirrored from the controller's exported steering defaults, as the bot helper does). It replaces R6's 19 m, which no longer binds NATURAL.
- Grade 10° and side slope 0.35 stay as screening values.
- Real rideability is the Input ride.

**The one SHAPED operation: BENCH (local traverse bench).** Where the trail traverses the creek bank, the band is levelled across: the uphill edge is cut and the downhill edge filled by the natural cross slope. This is the classic benched trail on a side slope; it exists only where the bank does.
- **Displacement.** At station s and lateral t, with c(s) the design cross slope at the centre line and f(s) a smoothstep taper over `taper_m` at both ends:
  - in the band (|t| ≤ hw): d = −c·f·t;
  - in the daylight (hw < |t| ≤ hw + daylight): d = −c·f·sign(t)·hw·(hw + daylight − |t|)/daylight;
  - elsewhere 0.
  - The centre line keeps its height.
- **Configuration.** `operations: [{kind: BENCH, from: [x, z], to: [x, z], daylight_m, taper_m}]`; from/to are projected onto the line.
- **Implementation.**
  - TrailRealization owns the operation: interval, c(s), budgets, reasons.
  - FinalSurface evaluates d.
  - The tile renderer refines the footprint and moves its vertices before band clipping.
  - Render, collision, final queries, recovery heights and vegetation follow from the same published triangles.
- **Budgets, fixed before implementation** (ERR_TRAIL_BUDGET; never enlarged to pass):
  - one operation per trail;
  - interval length ≤ 60 m;
  - daylight 0.5–2.0 m, taper 2–8 m;
  - |d| ≤ 0.30 m;
  - earthwork |cut| + |fill| ≤ 30 m³;
  - published band side slope inside the interval ≤ 0.06;
  - footprint + 1.5 m: no water, no road plane, ≥ 2 m from every tile border;
  - inside the trail interior (between the joins' leave stations).
- **Locality (tests).**
  - Every published vertex with d = 0 lies on the prototype-off triangles (≤ 1 mm).
  - Every vertex inside the footprint is its off height + d (≤ 1 mm).
  - Tiles, vegetation and network outside the trail are unchanged.
- **Logged.** Footprint length, SHAPED fraction, volume, max |d|, cross slope before/after, attempts, reasons.
- **Out of scope.** Other operations, jumps, obstacles, a general sculpting tool. Changing files, protected contracts or adding operations needs separate approval.

**Product observations (for BC3–BC5, no BC1 work).** Landscape variety, visual content and overall expressiveness of the region; the meadow terrain is smooth.

## Director decision after P2 (2026-10-13)

- **P2 ACCEPTED** as PLAYABLE / REVIEWABLE (human: more interesting, SHAPED natural, climb comfortable, gully natural). NATURAL and the one SHAPED operation are sufficient for BC1. The trail's shape stays frozen unless a defect is confirmed. P1/P2 are kept as controls (tags `bc1-p1`, `bc1-p2`).
- **M4 authorized:** L2, applicable G gates, performance, determinism, runtime, cache, regression and negatives under the existing Test Strategy and scope, then independent VERIFY and REVIEW. Blocking defects are fixed within scope and re-verified; non-blocking findings are recorded as known limitations or later-phase work. S3 stays OPEN / KNOWN FAILURE. A mandatory FAIL on the candidate forbids a formal PASS until its impact is separated from BC1.
- **BC2 architectural risk (research requirement for BC2, no BC1 work).** The off-road published surface (16 m cells) can differ from the natural height field by up to 3.6 m (184729 creek gully, BC1 P2), although the human ride found the gully natural. Procedural route search must evaluate lines on geometry consistent with the final physical surface. At the start of BC2 planning:
  - measure how common significant discrepancies are on characteristic terrain;
  - determine when they affect rideability, the relief profile and line choice;
  - check whether search can use the published geometry or a consistent surface representation;
  - if needed, propose a minimal local refinement;
  - no global terrain rework without proven product or technical grounds.

## Progress P2 (2026-10-13, amendment A1)

Status: **P2 PLAYABLE / REVIEWABLE. Waiting for the Director's second ride; L2/VERIFY/REVIEW not started.** Evidence: `outputs/bc1-evidence/p2/` (comparison page `bc1_p1_p2_comparison.html`), P1 control `outputs/bc1-evidence/p1_control/`.

- **Relief study.**
  - The meadow is a smooth 3–15 % slope; the creek gully is the only nearby feature.
  - The analytic gully (3 m deep, 35 % banks) is published by the off-road 16 m cells as a ~16 m-wide V trench on its straight N–S stretch and as a staircase on its diagonal stretch.
  - Published vs analytic heights differ by up to 3.6 m there (`p2/pub_*`). The line was designed on the published heights and the bench placed on the straight stretch.
  - Product observation for BC2/BC3.
- **Line (data).** 453 m; +14.6 / −3.6 m; grade ≤ 12.7 %; R_min 26.8 m (P1 34 m); water ≥ 7 m from the centre line; same joins (edge:4 / edge:7), one tile (4,5).
- **SHAPED BENCH.**
  - Interval s 126–183 m (57 m, 12.6 %).
  - Band side slope (fit) 19.5 % → 0.24 %; max |d| 12.7 cm; earthwork 14.1 m³.
  - Daylight 1.5 m, taper 4 m; water/road/border clearances held.
- **Implementation within the whitelist.**
  - TrailRealization: RADIUS_MIN_M 8; BENCH parse, budgets, `shape()` on the published pre-bench surface; the bench side slope uses the band fit, with tapers on the NATURAL limit.
  - FinalSurface: `trail_displacement`, `trail_bench_gap`.
  - Renderer: footprint refinement, vertex displacement, clip points at off height + d.
  - Bake: shaping on the published off surface, operation metrics in the report.
  - Config: new control points and the operation.
- **P2 evidence (L1; all stderr free of errors/warnings/leaks).**
  - **integration 52/0** (`runs/p2_integration2`):
    - off bake equals baseline;
    - off vertices kept and new vertices on the off triangles, each moved exactly by d (≤ 1 mm);
    - displacement only in the dry footprint, off tile borders; bench budgets;
    - seams, layers (band-edge tolerance 1 mm + chord sagitta 1.2 mm), final queries, vegetation, cache reload, stale cache, key identity, atomic rejection.
  - **domain 25/0** (`runs/p2_domain2`): 18 negatives with their reasons, including 5 ERR_TRAIL_BUDGET bench cases.
  - **runtime 24/0** (`runs/p2_runtime`, Vulkan):
    - Input rides both ways: 0 stalls, grounded;
    - lateral ≤ 0.39 / 0.86 m; rough share 100 / 99.2 %; climb minimum 1.78 m/s;
    - P2 rays 1365, 0 misses, ≤ 0.04 mm; recovery on the trail;
    - 5 views including the bench.
  - **Baseline smoke:** `test_region_ride --target=region` (`runs/p2_baseline_smoke`).
- **Fixture corrections in the new BC1 entry (not protected tests).**
  - Water and bench-near-water lines.
  - Cache-identity edit.
  - Band-edge tolerance derived from the chord sagitta of curved band edges.
- **Cost.** Region vertices 1,381,359 → 1,406,273 (+1.80 %), triangles +1.81 %; trails step ~45 s.

## Progress (2026-10-13)

Status: **P1 PLAYABLE / REVIEWABLE. Waiting for the Director's ride and feedback; SHAPED not started.** Evidence: `outputs/bc1-evidence/` (runs/, m0/, m1/); dev tooling in `work/bc1/`, outside the repo. The Director's clarification of 2026-10-13 (four points) is answered below.

**M0.**
- Prototype-off baseline rebaked: `c94451cf…` / `183eef0c…`, equal to the PR1 expected values.
- Line `trail:bc1_meadow`, NATURAL, purpose MEADOW_PASSAGE. It leaves edge:4 (valley BACKBONE, 137 m east of junction 5) and joins edge:7 (SECONDARY loop, 158 m south of junction 4).
- Measured query/triangle drift on the band: up to 10.8 cm (> 5 cm P2 ground). Resolved by final queries from the published triangles in trail zones; general off-road parity → BC2.

**M1 implementation.**
- `trail_realization.gd`: pure realize/finalize with reasons INPUT / IDENTITY / CONNECTION / UNRIDEABLE.
- `realized_road_network.with_trails` (own list, schema /2).
- FinalSurface trail index and `with_published`.
- Exact tile refinement: longest-edge bisection, band clipping, trail UV, border agreement in the bake.
- Atomic `RegionBake._trails`.
- Vegetation clearance, cache key, RegionWorld opt-in, recovery lines, end posts, shader.
- `scripts/test/test_bc1_trail.gd` (new, additive).

**P1 evidence (L1; candidate = this commit's sources; all stderr free of errors/warnings/leaks).**
- **integration 55/0** (`runs/m1_integration2`, 824 s):
  - fresh off bake equals baseline tiles/network/vegetation;
  - fresh on bake publishes one trail; roads unchanged (on network minus trail == off network);
  - only tiles (4,5),(4,6) change; their new vertices lie on the off triangles (≤ 0.05 mm) and no off vertex is lost; 8/8 seams with neighbours equal;
  - band layer agrees with the material query (19 probes ≤ 1 mm from the band edge counted as float32 rounding);
  - final queries equal the published triangles (≤ 0.05 mm); vegetation changes only in the trail tiles, closest clearance 1.3 m;
  - cache reload equals fresh (on and off); stale cache reads ERR_BAKE_STALE; content/seed key identity; atomic rejection keeps the off products.
- **domain 18/0** (`runs/m1_domain2`): determinism; 13 negatives each with the declared reason, water stopping at water.
- **runtime 23/0** (`runs/m1_runtime4`, Vulkan, cache load 1.9 s):
  - Input rides road→trail→road both ways: finished, 0 stalls, wheels always grounded;
  - lateral ≤ 0.31 m forward / 0.75 m reverse; rough collider under wheels 100 % / 99.4 %;
  - P2: 1011 rays, 0 misses, ≤ 0.04 mm (mouth rule: road or trail within 2 m of a join);
  - recovery lands on the trail line, 0.45 m above loaded ground;
  - 4 bicycle-camera views saved and read (`m1/runtime/bc1_view_*.png`).
- **Default baseline smoke:** existing `test_region_ride --target=region --tour-m=1500` 7/0, cache, no trail (`runs/m1_baseline_smoke`).
- **Launch** in this worktree from cache with the trail: `runs/m1_launch_worktree`.

**Director clarification (2026-10-13).**
1. **Limits.** 10° grade and 19 m radius are PROVISIONAL screening values reused from SINGLETRACK/R6, marked as such in code. NATURAL norms → BC2. The line itself stays far below them (8.5 %, 34 m). Two-way rideability is shown by the Input rides with the real BicycleController. Observed: on the 8.5 % section of the rough layer the bot slows to 1.7 m/s (2 sprint taps), a question for the human ride.
2. **Cost.** Region vertices 1,381,359 → 1,399,547 (+18,188, +1.32 %); triangles 2,750,439 → 2,786,755 (+1.32 %).
   - Per tile: (4,5) +9.9 % vertices, (4,6) +16.7 %.
   - Bake +30 s (trails step) of 409 s.
   - Cause: the band zone (half width + 1 m, ~1,100 m²) is refined to 0.5 m edges so the band edge, layer and shading follow the line exactly. That is ~54 vertices per trail metre, plus grading back to the 16 m cells and the clip points.
   - Runtime GPU/memory cost not measured (L2). No optimisation started.
3. **Layer probes.** All 19 disagreements lie ≤ 0.3 mm from the band edge on clip slivers (float32). Recorded as an explicit ≤ 1 mm edge tolerance in the test; no algorithm growth; P2 and other mandatory checks unchanged.
4. **Geography.** See the playtest instruction, section BC1 P1: a meadow shortcut from the valley road by the river to the SECONDARY loop toward the southern range, bypassing junction 4. Gentle and short: a first technical segment whose interest is to be judged by the ride.

**NOT RUN (L2/acceptance, after the playtests).** G suite, GPU 20-min ride, 1-vs-N bake determinism, holdout, mutants, P3 off-road ≥ 150 m, R6/R7 regression subset, VERIFY, REVIEW. S3 untouched (OPEN / KNOWN FAILURE).

Ledger (wall, ±0.25 h): implementation + L0/L1 ≈ 4 h, M0 included; L2/VERIFY/REVIEW/Closeout NOT_STARTED.
