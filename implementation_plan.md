TASK: BC1 — первая природная тропа Slow Cycle; ExecPlan v1.0
DATE: 2026-10-13
STATUS: PLAN_ONLY — STOP at explicit Game Director approval; implementation NOT_STARTED
BRANCH: bc1-natural-trail; BASE: final BC0 2a43bc092b503987a9a2845232a3791b0ad69e21
HEAD AT PLAN DRAFT: a8414ac0a6becc989fef24d060cff40bc8ceb149 (factual errata); submission HEAD/digests in planning manifest
BASELINE: source/new checkout clean (staged/unstaged/untracked 0/0/0); docs-only planning changes
APPROVAL: none for BC1 v1.0; Director 2026-10-13 authorizes planning, branch and factual errata only
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
