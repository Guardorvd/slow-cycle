TASK: R6 — Road Synthesis Adapter (Alpha)
DATE / VERSION: 2026-10-09 / ExecPlan v1.0 + Director conditions C1–C5 (§0)
STATUS: ALPHA IMPLEMENTED, FROZEN CANDIDATE RETURNED TO DIRECTOR — independent VERIFY/REVIEW NOT run (see section 17 final record)
REPOSITORY / BRANCH: Guardorvd/slow-cycle / r6-road-synthesis-adapter (observed)
BASE / HEAD: f268dfec7021e7437d25cadd6664f470cb60610b — R5 COMPLETE
BASELINE: at approval: unstaged implementation_plan.md (this plan) only; staged none; untracked none
APPROVAL: Game Director 2026-10-09 — APPROVED WITH CONDITIONS, A1–A5; approved v1.0 SHA-256 76bb517c…291df (snapshot kept externally)
RESULT IDENTITY: record source/diff digests externally at each freeze, not in this content
NEXT: Director decision on the technical-category amendment and on the deferred verification sprint; commit/push only on the user command; no R7 or R8
D2 INTEGRATION: 2026-10-10 — D2 (published origin/master ee94d667423fee0fd70626b4e261748297d78ec4) merged locally into this branch; D2 is NOT adopted for R6 until the Game Director approves R6-VA1 (section 18, DRAFT). Until then this plan's own verification text (sections 12, 15, 17) governs. Local WIP checkpoint e6cb304 (not acceptance, not pushed).

---

# R6 ExecPlan v1.0 — Road Synthesis Adapter

## 0. Approval record and binding conditions (Game Director, 2026-10-09)

Decision: **APPROVED WITH CONDITIONS — PROCEED TO IMPLEMENTATION.** A1–A5 approved with the refinements below. No v1.1 is prepared; where a condition refines a v1.0 clause, the condition governs and the original text is kept for traceability.

| Condition | Binding refinement and the v1.0 clauses it governs |
|---|---|
| C1 — junction scope (§7, §8 READY, §13 junction negatives) | Keep shared junction ownership, common ports, valid geometric seams and explicit movement feasibility. One geometrically infeasible, nonessential turn movement does not block otherwise usable connected edge geometry: edges and their ports remain usable, the movement is reported unavailable with its reason. Every movement is READY or explicitly unavailable with a reason; a junction or whole graph is never declared fully READY while a required movement is unavailable (plan stays PARTIAL). Priority: continuity of actual R5 route traversals and useful connected alternatives; full network gameplay/unrestricted junction navigation is R13. The shared patch may be a gently graded plane where terrain/continuity require it (no forced flat platform on a slope); §7 "unbanked, planar" is read as: one shared graded plane, no added superelevation; each movement's crossfall is the plane's cross-slope along it. |
| C2 — crossing flexibility (§8 water 1–3, §13 crossing negatives) | The R5 crossing point is the preferred geographic anchor, not an immutable coordinate. A small bounded local adjustment within the approved corridor is permitted where needed for alignment, banking, grades or bridge approaches. Preserve watercourse identity, crossing purpose, route topology, corridor bounds and one-to-one ordered crossing accounting. Record original R5 pin, actual R6 crossing, displacement, justification and independent hydrology validation. No river relocation, invented crossing, hidden topology change or corridor widening. Envelope, fixed before implementation: actual crossing must lie on the **same channel** (same `channel_id`, independent segment-intersection re-derivation), within **≤ 12 m** (horizontal) of the R5 pin, and within the R5 corridor band; displacement > 2 cm is recorded with its reason. A crossing outside this envelope is `ERR_R6_CROSSING_DISPLACED`; wrong channel/extra/missing remain their v1.0 reasons. |
| C3 — R6/R7 boundary (§6, §9) | R6 produces feasible geometry and bounded construction/support intent only: no terrain deformer, physical bridge structures, collision or final surface. Prefer a minimal sufficient roadbed-intent contract; every supported earthwork/bridge intent has explicit limits; unsupported structures stay diagnosed. |
| C4 — product-led implementation (§5, §11 M1/M2) | First substantive milestone demonstrates real measured road geometry on a real R5 corridor. By M2, representative examples of: sustained natural sweeping turns; connected flowing turns; a meaningful terrain-led elevation change; a calm stretch that stays calm; an explicitly diagnosed infeasible alignment — shown as actual final geometry and profiles, never labels/spline validity/control points. Quintic fitting and the coordinate-adjustment optimizer are acceptable choices, not goals: if evidence shows a simpler bounded fitting method meets the same contracts and quality, propose that focused adjustment instead of extra machinery. Independent geometry certification and safety boundaries are preserved. |
| C5 — Alpha completion philosophy (§12, §15) | Prioritise a useful connected R6 foundation for R7/R8. Keep approved real-region coverage, regression protection, independent verification/review. Inspect whole-route and network geometry, not only closeups; measure unrealised features, straightness, curvature distribution, calm intervals and rejection frequency. No fabricated features or weakened certification. Do not hold R6 open to perfect every optional corridor/movement when coherent representative geometry and honestly diagnosed limits satisfy Alpha. Classify findings BLOCKER / DEBT / ENHANCEMENT; only demonstrated blockers stop acceptance. Ordinary tuning/diagnostic improvement is autonomous; protected legacy code, existing tests, physics, player configuration and R5 contracts need a separate amendment. **Before final independent VERIFY/REVIEW, return to the Director:** frozen candidate, real generated maps and profiles, representative Vulkan views, realised-feature evidence, complete failure inventory, performance and remaining debt. Do not start R7. |

Core requirement restated by the Director: R6 is not a spline smoother; it is a terrain-aware bicycle-road designer producing geographically believable, technically feasible, enjoyable geometry, without the legacy generator's excessive straightness.

Execution progress, decisions and evidence for this task are recorded in §17.

## 1. Outcome and approval boundary

Build one deterministic, terrain-aware road designer that turns the actual R5 corridor network into connected, inspectable bicycle geometry, with bounded roadbed and crossing intent for R7. The geometry must support calm cruising, sustained sweeping turns, connected turns, terrain-led climbs/descents, crests/compressions and optional technical sections. Mathematical validity is necessary but cannot certify riding character.

Recommended implementation: an isolated `RoadSynthesizer` with shared junction planning, a small set of terrain-led alignment candidates, bounded local fitting of continuous curves and elevation, independent geometric certification, and an immutable regional result containing compatible `RoadPathData` views. Replace the legacy 50 m composition algorithm for this pipeline. Keep its runtime and public data/mathematics intact until a later migration.

The Game Director's single implementation review must explicitly accept or amend:

| Approval | Concrete decision requested |
|---|---|
| A1 — composition | REWRITE regional composition rather than wrap the RoadGrammar FSM; use the bounded alignment/fitting design in §5, preserving legacy code and extracting useful mathematics. Grounded geometry only in R6; intentional gaps, drops and airborne event scheduling are deferred. |
| A2 — regional policy | Approve the separate R6 policy in §6: reversible, class-specific grade envelopes, R ≥ 19 m, retained continuity/derivative/bank ceilings, explicit roadbed and crossing bounds. This is an explicit regional applicability decision, not a change to existing validators, tests, physics or their thresholds. In particular +8/+10/+12° regional climbs are proposed geometry limits, not proven bicycle performance. |
| A3 — boundaries/contracts | Approve local-frame RoadPathData envelopes, single-owned junction patches/connectors, exact crossing pins, finite search failures and R7 intent schema in §§4–8. No topology editing, corridor widening, alternate world-height owner or main-game wiring. |
| A4 — specific verification scope | Approve creation of the four new diagnostic/test entry points and the independent oracle/helper in §10, including R5 barrier recertification and disposable-copy mutation checks. Existing test files, harness manifest, assertions, categories and gates stay unchanged. |
| A5 — Alpha acceptance | Approve the real-region coverage, distinction between usable connected outputs and diagnosed rejected corridors, observational performance targets, visual judgement and retained gates in §§12–15. No requirement that every R5 corridor succeed, and no acceptance based only on selected successful pictures. |

Approval of A1–A5 authorizes ordinary parameter tuning, local corrections and visual iteration within the whitelist and hard bounds. It does not authorize changing those hard bounds, weakening tests, changing an input/output contract, adding a new owner, altering protected neighbors or entering another phase. Such a material change needs a concrete amendment. User authorization for this turn is planning only.

## 2. Observed state and authority

Read the root/world/player/test AGENTS, `.agent/PLANS.md`, `.agents/skills/slow-cycle-worldgen/SKILL.md` and frozen test-integrity rule. Authority consulted: Blueprint §§4.1, 5, 15–23, regional composition; Master §§I–II and R5–R8/R13/R16–R17; Target Architecture; Legacy Migration Matrix; Test Strategy; Current Project State; completed R1–R5 contracts, outcomes and debt. Code audit includes R5 graph, builder, search, planner; R2 terrain, R3 hydrology, R4 rideability; RoadPathData, RoadMath, RoadLogic, RoadGrammar, generation/airborne contracts, validator, kinematic model; RoadChunk, ChunkStreamer, WorldManager/recovery, RoutePlan and relevant tests.

Repository status and HEAD were read directly: the requested branch already exists at the exact requested baseline. No branch creation or checkout is needed. The root plan slot was `NO_ACTIVE_PLAN`, last completed R5. Planning is in Default mode because no mode-switching tool is available; that does not authorize implementation.

| Evidence at this baseline | Consequence |
|---|---|
| R5 completed record: 2,235 checks ×2, 16 development maps, 32 regression regions, 28 Vulkan captures, independent VERIFY/REVIEW and Director visual acceptance. The 32-region set was used for repairs and is no longer blind. | These establish an accepted route planner, not road feasibility or riding quality. Historical results have not been rerun during this planning turn. |
| R5 `RouteSearch.PROFILES`: grade preferences/maxima are ratios .06/.10, .09/.15, .14/.22, .22/.38; every class allows development. Development overhead 1.1 deliberately favors a direct steep corridor over fake 32 m switchbacks. | Do not copy its grades as road limits or smooth its reference line and claim completion. R6 must find actual length/turning room or diagnose failure. |
| R5 builder: 20 m Douglas–Peucker simplification; stations ≤32 m; half-widths 8–120 m; coarse lateral probes 16 m; exact reference-line certification ≤8 m. | Bands are design freedom, not certified swept roadbed. The minimum 8 m width is a floor even near barriers; actual terrain must be checked again. |
| `RegionRouteGraph`: undirected edges, loops, degree 3–4 junctions, 96 m junction zones, ≥30° reference arrival separation, ≥200 m between adjacent junctions. Different bands may overlap. | Shared physical junctions and collision/overlap checks cannot be delegated to independent edge builders. Reference angles do not prove road connection feasibility. |
| R1 geography offers benches, shoulders, valleys and passes; some descriptor passes are buried. R2 has a 16 m natural-gradient stencil. | Sample the public natural surface; descriptors are hints. R6 cannot claim real trees, rocks or fine terrain obstacles that have no authoritative field yet. |
| R3 `HydrologySurface` is base + hydrology before roads; R4 uses that basis. R4 BLOCKED means deep water ≥.35 m or natural slope grade ≥1.0. Dense cover/wetness are costs/flags, not placed obstacles. | Use this natural pre-road world consistently. Road engineering may explain a crossing or a bounded shelf, but may not rewrite R4's natural answer. |
| R5 accepted DEBT-3: no independent real-graph natural BLOCKED recertification; graph validation relies on planner certification/defect counts. Crossing audit shares the builder's query. | R6 must supply independent evidence on input corridors and final geometry, including a builder-certification mutant (§8/§13). |
| R5 isolated 184729 planning ~43–45 s, raster ~17 s; R4 point sampling ~0.8 ms and full lattice ~21 s in accepted records. | Avoid repeated whole-region regeneration and unbounded optimizer queries. These are historical measurements, not R6 performance promises. |

Blueprint's 3–10 s / 20–60 s / 2–5 min scales motivate local geometry, connected sequences and long calm stretches; they are not fixed-distance event triggers. R6 supplies local design capabilities. R16 journey pacing, R17 the full situation library, and claims about actual pleasurable bicycle handling remain outside this phase.

## 3. Legacy audit and disposition

The following are source-established mechanisms at the baseline, not measured occurrence rates. No new engine experiment or test was run for this plan. Overall rejection/repair/fallback frequency, under actual streamed routes and MountainProfile, remains NOT_MEASURED. M1 explicitly measures it before any R6 implementation conclusion is presented as empirical.

| Component / source evidence | Finding and decision |
|---|---|
| `road_logic.gd:22–24`, `road_grammar.gd` PhaseSpec and `advance_phase` | Composition is 50 m/25 samples per phase. Several preparations/recoveries add another full 50 m; eight quiet phases trigger a crest by clearing the queue. This couples riding form to chunk size and a forced ~400 m feature gap. **REWRITE** this composition in R6; **RETIRE its authority in the new pipeline**, not its current runtime files. No periodic wiggle/feature rule. |
| `road_logic.gd:489–515`, `765–825` | Cruise yaw ±5°, fast descent ±3°, braking ±1°, recovery ±2.5° per 50 m favor small heading changes. Hermite's endpoint and derivatives are useful, but these policy choices are not a proven experience model. **EXTRACT/KEEP** Hermite/frame mathematics; **REWRITE** endpoint selection and span lengths. |
| `road_logic.gd:286–359` | Switchback has 18 m ramp-in, 14 m plateau, 18 m ramp-out at R=19–21 m. Integrated heading is 32/R radians, approximately 87–97°, rather than the entire advertised 90–120° range. It resets curvature at its end. A label does not prove a hairpin of the requested angle. **EXTRACT** curvature-ramp reasoning; variable-length terrain-led turning geometry replaces fixed-length phase construction. |
| `road_logic.gd:588–763` | Winding/forest noise combines heading mean reversion with curvature rate limiting. At an exit/fork the target curvature becomes zero from sample 15 (s=30 m) through the end: 11 of 25 target samples are damped. Each isolated winding phase therefore loses much of its sustaining length; this is a conditional source fact, not a global frequency. **REWRITE** macro heading/noise composition. Retain explicit derivative limits and gentle entry/exit where geometry requires them. |
| `road_logic.gd:829–959` | Soft repair replaces winding/forest with one signed trapezoidal curvature lobe, retaining those segment labels. Crest/airborne repair becomes grounded CRUISE_DOWNHILL. Intent can be weakened or removed even if the repaired path validates. **RETIRE** this recovery policy from R6; every repair must be remeasured against its geometric intent and disclosed. |
| `road_logic.gd:145–180`, `962–999` | After a second failed validation the code calls conservative fallback without testing specifically for NaN/Inf or a >1 mm tear. It advances along a constant tangent while stored curvature decays. This conflicts with the narrower retained world guard and can make metadata differ from actual straight geometry. `last_chunk_passed=false` remains, but `_spawn_chunk_sync` and fork-widening dispatch still prepare/commit the path. **KEEP legacy untouched / DEBT**; R6 returns no consumable failed geometry and has no straight emergency fallback. |
| `road_logic.gd:200–260`, `mountain_profile.gd` | Three iterations of 0.35-scaled road-distance elevation offset happen after local synthesis and again after repair; tangent/grade are adjusted afterward. There is no world-corridor fit. **RETIRE MountainProfile as R6 height/biome authority**, keep legacy runtime. No parallel elevation oscillator over natural terrain. |
| `road_math.gd` | Cubic Hermite position/tangent, orthonormal banked frame and smooth width transition math have independent value. Radius helper is an approximate tangent-angle measurement with supplied arc length; it is not a final curvature oracle. **KEEP** unchanged; use frame math and Hermite where appropriate. **EXTRACT/ADAPT** derivative/arc-length math in the regional module with geometric verification. Do not call legacy slope clamping. |
| `road_path_data.gd` | Useful packed sample format, clone/slice/query and continuity helpers. It is mutable, float32 and assumes a common coordinate frame; branch metadata describes a legacy tree. `REQUIRE_CONTINUITY` checks C0, not all seam invariants; normal error is reported but does not invalidate `validate_continuity_with`. **KEEP** bytes/API; **ADAPT** through an immutable owning envelope, explicit origin and a complete R6 validator. No new enums or misleading tree identities. |
| `road_generation_contract.gd`, `road_validity_validator.gd` | Limits: +5/−14°, R=18 m vs world guard 19 m, |dgrade/ds|=1.2°/m, |dk/ds|=.003/m², ≤2.5 m sampling, seam .001 m/.2°/.1°/.5°, bank 8°. Validator uses stored slopes/curvatures and differences of curvature magnitudes; it does not independently establish signed curvature, tangent-position agreement, all finite/unit data or corridor fit. **KEEP** legacy validator/contract unchanged. **ADAPT** applicable invariants into a separately approved regional policy; new checks measure actual curves and packed samples. |
| `road_airborne_contract.gd`; crest builder | Contact vocabulary and calibrated landing constraints are useful. Landing comparison allows `MAX_DELTA_GRADE +10°`; crest builder marks two 2 m samples versus stated 2 m micro-drop span. These unresolved findings do not justify extending jumps now. **KEEP** enum/legacy behavior; **DEFER** intentional airborne synthesis and correction of those protected contracts. R6 crests/compressions are continuous surfaces and remain GROUNDED. |
| `road_kinematic_model.gd` | Slope-aware braking returns explicit insufficiency, and radius-to-speed helpers can evaluate candidate approaches. **KEEP/EXTRACT by calling** pure helpers, without changing coefficients or claiming physics simulation. |
| `terrain_carver.gd`, `road_chunk.gd` | Cross-section/width/frame concepts are useful; 38 m roadside terrain strips and CUT/FILL profiles own legacy ground. RoadChunk combines mesh, roadside and collision preparation. **DEFER** carver extraction to R7; do not reuse its whole preparation path in R6 preview. A simple diagnostic ribbon consumes R6 samples only. |
| `chunk_streamer.gd`, `world_manager.gd`, `route_plan.gd`, recovery/HUD/foliage consumers | Live consumers assume branch/chunk lifecycle and often world-space Vector3, local searches, tree metadata, road-relative ground and signs. **KEEP** untouched. A regional origin envelope is not automatically plug-compatible with these callers. Migration remains R7/R8/R10/R13 as appropriate. |

Test audit: `test_route_rhythm.gd` measures FSM history and checks that requested types/contact markers exist in production samples, which is stronger than queues alone but does not measure winding amplitude or realised switchback angle. `test_road_event_chunk_seams.gd` covers requested markers, seams, rows and prepared collision faces; retain it. `test_road_logic.gd` primarily checks determinism and envelopes. `test_monotony_profiler.gd` scans 600 m on three legacy seeds and calls a segment dead only when both curvature <.005 and vertical rate <.005. A straight descending road can pass that watchdog. Its mountain relief test also cannot judge lateral flow. Preserve every existing test and supplement with new geometry measurements, not revised quotas.

## 4. Exact boundaries, identities and ownership

### Existing input: do not invent a different RouteCorridor API

Call `graph.get_corridor(edge_index)` for each edge, using the graph's existing index/ID relation after `validate()`. Its dictionary schema is `slow_cycle.route_corridor/1`:

- Scalars: `edge_id`, `route_id`, `class`, `class_name`, `a`, `b`, `length_m`, `climb_m`, `descent_m`, `reasons`, `junction_zone_m`, `station_count`.
- PackedFloat64Array fields: world `x_m`, `z_m`, absolute `elevation_m`; ratio `grade`, `cross_slope`; `half_left_m`, `half_right_m`, `cost`. `biome`, `flags` are copied enum arrays.
- `anchors_passed` is the existing packed anchor/station pair list, not a list of world positions. Resolve anchors through graph accessors. Corridor elevations/grades/costs are evidence about the reference, not constraints on the final road's exact elevation.
- `crossings` retains integer `station`, `water_kind`, `channel_id`, local `x_cm`, `z_cm`, `width_cm`, `depth_cm`, `angle_deg`, `hint`; the view adds world `x_m`, `z_m`, `hint_name`, `water_kind_name`. It does **not** replace width/depth with metre keys. `station` is the nearest reference station; the exact crossing point is a separate pin.
- Read node positions and incident edges with `get_route_node`, `edges_at`, `get_edge`; the corridor view itself has no graph signature/origin. Obtain scalar int64 origin with `get_origin_x_m/z_m` and snapshot signatures separately.

### Proposed R6 public API (new, pending A3)

`RoadSynthesizer.synthesize(region_plan, terrain_field, hydrology_plan, graph, settings = {}) -> Dictionary` returns:

`{schema: "slow_cycle.road_synthesis_result/1", status, is_valid, plan, reason_code, diagnostics}`.

It validates input types, graph validation, region/hydrology/rideability signatures, origin and bounds. Like RoutePlanner, it composes matching HydrologyField, HydrologySurface, EnvironmentContext, BiomeField and RideabilityField through their existing `create` APIs; it does not accept unrelated mutable field dictionaries. `settings` admits only versioned policy fields, recognized keys and finite in-range values; invalid settings reject. No scene objects enter this API.

`RoadSynthesisPlan` owns immutable `slow_cycle.road_synthesis_plan/1` data and exposes `get_edge(edge_id)`, `get_junction(node_id)`, `get_crossing(crossing_id)`, `get_diagnostics()`, `get_path(piece_id, reversed=false)`, `canonical_bytes()` and `signature()`. Accessors return deep copies; path access returns a clone. A piece is an edge interior or a junction movement connector, identified by a stable string. It is never synthesized again on reverse traversal or request order.

Plan header contains graph/region/hydrology/rideability signatures, synthesis policy/config digest, algorithm version, effective seed, int64 `origin_x_m`, `origin_z_m`, scalar `origin_y_m=0`, and sorted edge/junction/crossing result records. Every R5 edge has an outcome; failed edges are not dropped. Edge records contain `edge_id`, `route_id`, `class`, endpoint port IDs, `status`, reason codes, `path_piece_id` when valid, measured feature records, roadbed records and crossing references. Junction records contain node identity, shared support patch, ports, and every distinct incident-edge movement outcome. Topology remains the R5 topology.

`get_path` returns `{piece_id, origin_x_m, origin_y_m, origin_z_m, path: RoadPathData, policy_id, direction}`. `points` are in this region-local frame; `slopes` are degrees, curvature is nonnegative horizontal magnitude in 1/m, widths are full riding widths in metres, distance is 3D chord-accumulated metres starting at zero. All existing parallel arrays are populated. `macro_elevation_offsets=0`; contact states GROUNDED. Branch/fork/parent IDs stay UNASSIGNED/−1, with true regional IDs in the envelope. Existing segment types are conservative compatibility descriptions; richer geometry intent lives in separate records, never a fabricated airborne label. `sight_distances` stores measured centreline visibility, with terrain-aware directional measurements and their limitations in the envelope.

Canonical synthesis uses scalar float64/local coordinates and derivative coefficients, not world Vector3. Subtract integer origins in scalar float64 before any Vector2/Vector3 conversion; add origins only at field-query boundaries. Pack local float32 RoadPathData only at export and revalidate it. At extreme int32 region indices world double resolution is ~millimetres: preserve the local integer crossing pin and account for query round-trip error separately; never relax the local 1 mm seam requirement. Use exact shared exported endpoint objects/values for all seams. No global floating origin runtime is added.

Reversal: reverse point order, negate tangents/binormals and signed curvature, keep physical normals, negate grade and signed banking, rebuild cumulative distances, swap directional sight/approach metadata and roadbed sides. Reverse interval [s0,s1] to [L−s1,L−s0]. Reclassify direction-dependent compatibility labels from geometry. Two reversals reproduce canonical geometry within serialization precision; generating from either request direction must use the same underlying piece.

Determinism: add one `road_synthesis` seed-purpose accessor to RegionSeedDerivation without changing any old preimage. Local candidate tie keys use SHA-256 over explicit UTF-8 schema/config/graph/edge-or-node/feature/candidate identities with delimiters; no global RNG, time, object IDs or request-order cache. Store sorted canonical keys and typed arrays, with explicit little-endian numeric encoding and lengths; reject NaN/Inf before encoding. Include unquantized float64 design and packed export bytes in same-engine/platform signatures; exclude timings and camera data. No cross-platform determinism claim.

### One owner per state

| Owner | State/lifetime |
|---|---|
| R0–R4 owners | Geography, base terrain, hydrology, natural biome/rideability remain unchanged and pre-road. |
| R5 RoutePlanner / RegionRouteGraph | Topology, route roles, geographic anchors, bands and crossing intentions. |
| RoadSynthesizer | One synthesis invocation; candidate workspaces, query cache and diagnostics, released at completion. |
| RoadJunctionPlanner | Shared port/patch decisions inside that invocation; cannot mutate the graph. |
| RoadSynthesisPlan | Immutable validated geometry, feature measurements, handoff intents and diagnosed failures. |
| Road synthesis preview | Nodes, diagnostic ribbons, cameras, overlays; never a height query authority. |
| Future R7 | Resolve approved roadbed intents into final surface/deformation, render/collision agreement and support integration. |

Dependencies flow R0–R5 inputs → pure R6 planning/math → result → diagnostic Godot adapter / future R7. No production dependency returns from R7/renderer/player to R6. Do not alter WorldManager as a composition root in this phase.

## 5. Chosen Alpha geometry algorithm

Use a finite candidate-and-fit pipeline, implemented as one coherent system. Do not build a general optimizer, procedural-language framework or situation director.

1. **Snapshot and certify the search space.** Validate inputs; build a continuous band from ordered reference stations and linearly interpolated asymmetric half-widths. For each segment use left normal (−dz,+dx), matching R5 builder convention. Use the union of adjacent tapered segment strips with capped joins at station corners, clipped to region bounds. Preserve longitudinal segment identity through overlaps; nearest projection alone must not jump to a distant loop segment. This explicit interpolation is the R6 interpretation of existing bands. Check centreline, riding ribbon, shoulders and deformation support, not just control points. Junction permission is described in §7.
2. **Plan junctions and exact crossing constraints first.** Solve shared junction port positions/heights and reserve approach spans. Water points and geographic endpoint/anchor neighborhoods delimit candidate spans. A feature may span several 32 m stations and multiple internal fitting spans. Neither 32 m nor 50 m is a riding rhythm.
3. **Find terrain opportunities.** Sample natural height, signed along/across gradients, available band width and R4 cover/wetness. Locate coherent contour benches, slope transitions, crest/compression neighborhoods and broad turn space. Anchor/flag information guides evaluation but never substitutes for these samples. Form variable-length spans around changes in terrain and constraints. Retain a calm continuation candidate whenever geography supports it.
4. **Generate a small bounded candidate set.** For each span consider a direct feasible alignment, left/right contour-following alternatives, a sustained sweep, a linked opposite-turn pair where terrain supports both, and a length-developing traverse/return turn for a flagged steep section. At most 12 candidates per span. Waypoint offsets and span lengths follow terrain opportunities and actual heading/elevation needs; no sine wave at fixed intervals. A developing candidate may reverse progress along the reference locally, so monotone station-offset fitting is not the only allowed form. It must still stay inside the actual approved band and avoid self-intersection. If there is no room for the needed return turn, report it.
5. **Fit continuous geometry.** Fit piecewise quintic Hermite curves in plan and an elevation profile over horizontal arc length. Share position/first/second derivatives at internal knots; use analytical derivative evaluation and an adaptive arc-length table. Quintic is chosen to carry curvature through joins without forcing it to zero. Keep the implementation local to RegionalRoadMath; reuse RoadMath's orthonormal-frame and applicable interpolation utilities unchanged. Cubic Hermite can seed candidates, but C2-compatible final fitting is not implied by merely calling its normalized-tangent helper. Search over waypoint offsets, tangent magnitudes and elevation knots by deterministic bounded coordinate adjustments; use at most three sweeps of six fit iterations per span. Failed convergence is a bounded-search diagnosis, not proof no mathematical solution exists.
6. **Fit height and footprint together.** Evaluate the real natural surface along each candidate and cross section. Adjust height/control points to meet grade/vertical-transition limits and cut/fill bounds; reject candidate cuts, fills or lateral influence that exceed §6. Route length can solve an elevation change; clipping sampled heights or slopes cannot. Include both-direction braking/visibility diagnostics. A terrain crest may remain a meaningful rounded crest; minimizing vertical error is not permission to flatten it away.
7. **Select feasible, character-preserving geometry.** Hard constraints precede scores. Compare remaining candidates by terrain plausibility, amount of roadbed work, fidelity to the selected local geometric intent, class character, and route directness. A modest positive cost for curvature is allowed, but never an unbounded straightness/smoothing objective. Once a sweep/linked-turn/crest intent is selected, preserve its geometric envelope through final fitting or explicitly reject it. Record alternatives and the reason a calm candidate won; do not disguise loss of an intended feature as successful realization.
8. **Sample, measure, certify and publish.** Adaptively sample at ≤2 m nominal, ≤2.5 m maximum; subdivide further at narrow clearance, strong curvature/vertical transitions and crossings. Certify continuous spans using polynomial derivative bounds/subdivision, not endpoints alone; bound curve-to-chord error ≤1 cm and tighten subdivision if clearance requires it. Minimum subdivision scale .125 m with a finite evaluation cap; inability to resolve a boundary safely is `ERR_R6_CERTIFICATION_UNRESOLVED`, not acceptance. Validate exported float32 samples independently. Only validated pieces enter consumable output.

Initial global safety limits: 200,000 candidate fit evaluations and 2,000,000 natural point queries per region, 250,000 final samples, 12 candidates per span and the iteration limits above. Count and record these. Work exhaustion yields REPLAN_REQUIRED with `ERR_R6_SEARCH_BUDGET`; wall-clock timeout is an evidence/launcher failure, never a deterministic geometry outcome. Tuning can reduce workload and adjust scoring/soft targets within these ceilings. Raising ceilings or changing algorithm family requires an amendment if needed to make Alpha feasible.

This approach trades search completeness for understandable geometry, useful failure diagnostics and a finishable Alpha. Difficult corridor failures are expected and visible. It avoids both inheriting a descent FSM and an open-ended global optimal-control research project.

## 6. Regional geometry and engineering policy — A2

Create `RoadSynthesisPolicy` (`regional_road/1`), leaving RoadGenerationContract, RoadAirborneContract, RoadValidityValidator and existing tests byte-unchanged. Both travel directions must be valid under the new regional policy. A legacy compatibility report may run the old validator unchanged on each direction, but reports its actual failures; it is never relabeled PASS or used as the R6 certificate.

| Class | Preferred absolute grade (ratio; soft) | Hard absolute grade (degrees) | Preferred radius / hard radius | Nominal full width / allowed width |
|---|---:|---:|---|---|
| BACKBONE | .04–.06 | 5° | ≥80 m / ≥35 m | 3.6 m / 3.0–4.5 m |
| SECONDARY | .06–.09 | 8° | ≥45 m / ≥25 m | 2.8 m / 2.2–3.6 m |
| SINGLETRACK | .08–.14 | 10° | ≥28 m / ≥19 m | 1.8 m / 1.3–2.0 m |
| TECHNICAL | .10–.18 | 12° | ≥22 m / ≥19 m | 1.5 m / 1.3–1.8 m |

These are proposed stylized Alpha design limits, not civil standards or evidence that the existing bicycle can comfortably climb them. The directional +5/−14° legacy rule cannot simultaneously describe an undirected route with meaningful steeper descents. A2 makes that conflict reviewable without altering player physics. R8 must assess actual handling; a measured incompatibility returns to road design or a separately approved player task. If A2 is declined, revise the plan before implementation; do not silently substitute ±5° or violate the old limit.

Retain hard |dgrade/ds|≤1.2°/m, |d signed horizontal curvature/ds|≤.003/m², bank≤8°, sample≤2.5 m and seam position≤1 mm, tangent≤.2°, grade≤.1°, normal≤.5°. Use softer grade/curvature transitions when room permits. Frame must be finite, unit, orthogonal, upward and free of flips; validate width/bank interpolation and road-edge Jacobian/no folding. C1 is mandatory at every traversable join. C2 at fitted internal knots and connector joins is the normal construction goal; any non-C2 exported transition must still pass the derivative/continuity bounds and be reported.

Keep bank continuous and bring it to zero at shared patches/crossing decks with sufficient approach length, not a sample clamp. Use RoadKinematicModel unchanged for conservative both-direction approach/braking calculations at documented design speeds (initial 30/28/24/20 km/h by class). A speed value is design metadata, not a control command. Check available approach length and terrain-aware line of sight to hazards using natural surface plus intended road sections; do not call a supplied constant a measured sight distance. Full vegetation visibility and final-surface visibility remain R7/R11 work. Braking insufficiency is a candidate rejection, not an arbitrarily lowered speed hiding an unsafe approach.

Proposed bounded earthwork: backbone/secondary max cut 3 m, max fill 2 m; singletrack/technical max cut 1.5 m, max fill 1 m. These apply across the riding surface and shoulders, not just centreline. Initial shoulders .75/.5/.3/.25 m respectively; daylight tie-in must fit within an additional 12/10/6/5 m per side and the corridor. Allow at most 1 vertical:1 horizontal cut and 1:2 fill side slopes as stylized upper bounds. A shelf is asymmetric bounded earthwork, not a retaining-wall or tunnel license. Require a tie-in to the unmodified natural height and zero displacement outside the footprint. Unsupported retaining walls, cliff-hanging fills, tunnels and large earthmoving reject.

No intentional airborne/drop geometry in R6. Natural crests/compressions are supported through continuous elevation and vertical-curvature measurements. GROUNDED means continuous designed surface, not a promise the bicycle's wheels never unload. Technical character comes from narrower line, stronger terrain response, connected turns and grade rhythm, and remains optional under the original R5 hierarchy.

## 7. Edge, junction, loop and precision continuity

Plan all incident edges together in stable node/edge order before publishing individual edges. A junction cannot be one point with a single tangent shared by three incompatible approaches.

For each degree 3/4 junction, construct one small common, unbanked, planar support patch and one port per incident edge within the existing 96 m node neighborhood. The allowed junction domain is the union of incident corridor bands intersected with that neighborhood and natural constraints; the 96 m radius is not permission to expand outside all bands. Choose a shared height and gentle plane fitting terrain/cut-fill constraints, plus port headings following approach opportunities. Solve all approach elevations jointly. A failed shared solution blocks all dependent pieces rather than moving the node separately for each edge.

Create one canonical connector curve for every unordered pair of distinct incident ports; reversal provides the opposite travel direction. At degree four this is six movements, finite and feasible to inspect. In the common patch, connector surfaces use the same plane; overlapping movement curves describe one surface, not stacked ribbons. Match port position, tangent, grade, curvature and normal to edge interiors, easing geometry before the port. Choose the movement's geometric limits from the stricter incident class; no easy route depends on a technical maneuver. Preserve all R5 connectivity and RELIES_ON semantics. A movement that cannot fit is an explicit `ERR_R6_JUNCTION_MOVEMENT` and prevents that junction being marked ready. No U-turn gameplay requirement is introduced.

R7 handoff has one node-owned patch plus clipped edge strips, no duplicate roadbed writes. Preview renders the patch once and connector centrelines as diagnostic lines. Clip interiors at ports; logical boundary rows may be repeated in read views for seam checks, but ownership keys/half-open intervals deduplicate output surface primitives. Graph loops are composed from existing pieces plus connector movements; no loop-triggered road regeneration or duplicated edges. Check return seams and orientation around each tested loop.

Away from approved junction patches, detect road-road/self overlaps of full riding ribbons and incompatible deformation footprints, not just close centreline samples. R5 permits band overlap but does not authorize an unplanned at-grade crossing. Reject an unconnected intersection or competing-height overlapping earthwork; R6 does not add a new graph node or overpass. Resolve candidate conflicts in stable order (class, then edge ID) with bounded alternatives; report any unsolved conflict and affected connectivity. No order-dependent first-request wins.

Gateway/terminus endpoints preserve node location and terrain-feasible elevation/approach. Cross-region continuation is deferred to R21; export endpoint position/heading/grade/frame constraints, but do not claim neighboring region gateways connect. Test local coordinates at ordinary offsets and the existing int32-extreme R5 fixture without world-space float32 packing.

## 8. Feasibility, water and R5 debt closure

Outcome vocabulary:

- `READY`: all requested graph edges and junction movements have valid road geometry and bounded intents. `is_valid=true`, plan present. This is R6 geometry readiness, not a built surface or a physical-ride certificate.
- `PARTIAL`: plan contains every edge/junction outcome, but one or more are unavailable; `is_valid=false`. Valid connected components are inspectable individually. Never feed the whole partial plan to R7 as a complete network.
- `REPLAN_REQUIRED`: finite local alternatives were exhausted or required work is outside allowed scope. Return span, measured violation, attempted candidates and the constraint that needs reconsideration. No graph edit is performed.
- `REJECT`: invalid/mismatched inputs or invalid configuration; plan null.
- `FAIL`: internal invariant/consistency error; plan null and detailed diagnostics. Non-finite geometry is not patched into a straight path.

Each piece carries status/reasons. Plan-level PARTIAL aggregates valid/failed pieces without converting failed edges into successes. A separately inspectable failure record can use REPLAN_REQUIRED. Distinguish a necessary impossibility certificate (e.g. endpoint rise exceeds maximum grade times all permitted length under a proven bound) from ordinary search exhaustion; most Alpha failures will be the latter.

Independent natural checks run on both the input reference line and the final swept design. At ≤4 m along the input, with extra barrier/water transition samples, resample real R4 public queries without consulting builder defects or STEEP_PINCH flags. Record mismatches even if a new alignment avoids them. EXCESSIVE_SLOPE is allowed only where a concrete bounded engineered footprint solves it; flags alone never excuse it. Re-check final centreline, both road edges, shoulders and tie-in footprint at adaptive spatial resolution, using public natural height/gradient/rideability. Existing coarse fields cannot certify individual rocks/trees; disclose this boundary.

Water handling:

1. Treat each R5 crossing as a required pin at the supplied local centimetre position, channel identity and sequence. Original rounding permits ≤2 cm intersection matching tolerance; seam tolerance is separate. A movement to another crossing site, adding/removing a channel crossing, or changing topology is outside R6 scope.
2. Re-derive channel intersections along the actual final curve using adaptively subdivided chords and `sample_segment_crossings` (query segments ≤256 m). Check all query validity results. This query excludes collinear overlaps and detects bodies by sampled lattice cells, so additionally check water occupancy/overlaps using `sample_water` and body geometry. Canal-following/collinear travel must not evade certification.
3. Require a one-to-one ordered match, including channel ID, with recorded pins. Deduplicate shared-vertex hits geometrically, not by dropping repeated channel IDs (a road may cross the same channel twice at different pins). Reject phantom, omitted, additional, unsupported or out-of-order crossings. Required crossing positions remain fixed through every fit/repair.
4. A FORD hint is not permission to drive through deep water. Permit a continuous ford only when exact depth <.35 m, bed/width/approach grade and footprint pass without changing the watercourse. Otherwise refine to a bridge intent if allowed by the existing class/hint compatibility and geometric bounds; record the changed engineering interpretation explicitly.
5. Bridge intent requires an actual continuous deck alignment, banks/abutment locations, deck underside ≥1 m above sampled water surface, width, full wet-span coverage plus ≥2 m dry bearing at each bank, approaches and feasible bounded earthwork. Initial unsupported clear span ceiling 80 m (small bridge 12 m); allow .5 m structural depth, so the riding surface is ≥1.5 m above water. No pillars, structural simulation, river filling, dams or flood prediction. A technical edge cannot silently adopt a BRIDGE hint forbidden by R5. If constraints fail, `ERR_R6_CROSSING_APPROACH` or `ERR_R6_CROSSING_SUPPORT`.
6. Preserve hydrology and natural terrain under a bridge. Road surface over water is support intent, not an earthwork fill to the bed. Mark `requires_support=true`, with all geometric obligations specified, and `physical_support_built=false`. R7 must resolve the final road surface/support interface; full bridge asset/environment work belongs to R12. R6 does not claim physical water crossing readiness.

R5 DEBT-3 evidence: new `test_road_synthesis.gd` invokes an independent oracle over real graphs; the oracle uses public R4 samples and independently intersects public HydrologyPlan channels/body cells, not `RouteCorridorBuilder.audit_crossings` or the builder's defect counter. It classifies naturally blocked input spans as requiring specific R6 engineering or avoidance, rather than requiring every R5 reference line to be naturally passable. Disposable mutation runs (never repository edits) disable the builder's excessive-slope/pinch certification and separately suppress deep-water certification; the oracle must expose the lost flag/certification wherever exercised. Also disable R6 barrier rejection and omit a required crossing in separate mutants; final checks must fail for the exact expected reason. If a listed real seed does not exercise the changed branch, find and record the first matching region by deterministic scan and retain it as a disclosed regression fixture; a surviving or unexercised mutant is not a PASS. Existing R5 tests and production builder stay untouched.

## 9. R6 → R7 roadbed intent contract

Roadbed intent is data describing an admissible local surface and support obligation. It is not `FinalSurface.sample`, a mesh/collider, or another final-height owner. R4/R5 continue sampling the natural pre-road world.

Each `slow_cycle.roadbed_intent/1` piece contains stable piece/edge/node ID, origin, natural-input and policy signatures, station interval and final centreline/frame reference; per-station full width, left/right shoulder and tie-in extents, target edge heights/crossfall, cut/fill maxima and actual sampled required depths; footprint boundary, support kind (`EARTHWORK`, `FORD`, `BRIDGE_DECK`, `JUNCTION_PATCH`), local bounds and crossing reference; support/engineering reasons and quality status. Side designation is canonical edge a→b. Store sampled natural heights and measured deltas for reproducible review, but R7 must recheck the signatures and its own final construction.

Earthwork influence tapers to zero displacement and zero added slope at its outer boundary; the proposed profile and finite extents are explicit. Emit no unbounded deformation request. Resolve compatible overlap into a single node patch; conflicting nonjunction intent rejects in R6. One record per physical support area, indexed by stable IDs, independent of how many routes reference it. Water exclusions and deck-underlying-terrain preservation are explicit constraints.

R7 owns the deformation algorithm, blend with hydrology, surface sampling, meshes, collision and final support realization. It must accept or diagnose these intents; it must not silently move the R6 centreline or remove its features. R6 completion demonstrates bounded constructible intent under the stated stylized model, not actual R7 surface continuity/collision. Landmarks are not present yet. No promised R7 callable API is implemented in R6.

## 10. Exact file scope

Only `implementation_plan.md` is changed in this planning turn. The copy delivered outside the repository is byte-identical review material, not a second active plan.

After A1–A5 approval, create these domain files under `scripts/world/region/`:

| File | Responsibility |
|---|---|
| `road_synthesis_policy.gd` | Versioned settings, hard bounds, reason/status definitions. |
| `road_synthesis_plan.gd` | Immutable owning envelope, clones/reversal, stable serialization/signatures. |
| `road_synthesizer.gd` | Input composition, finite stage orchestration, complete outcomes. |
| `road_corridor_geometry.gd` | Band interpolation, ordered projection, swept footprint and precision boundary. |
| `road_alignment_designer.gd` | Terrain opportunities, finite candidates and bounded curve/elevation fitting. |
| `regional_road_math.gd` | Local polynomial derivatives, arc length and export math; reuse legacy helpers where valid. |
| `road_junction_planner.gd` | Shared patch/ports/connector geometry and deterministic boundaries. |
| `road_feasibility_validator.gd` | Read-only validation of geometry, terrain, water, feature realization and engineering. No repair. |
| `roadbed_intent.gd` | Bounded roadbed/crossing records and schema validation. |

Modify only `scripts/world/region/region_seed_derivation.gd` for the additive road-synthesis seed purpose; previous outputs/preimages remain unchanged.

Create `scripts/test/road_synthesis_preview.gd` and `scenes/test/road_synthesis_preview.tscn`: isolated diagnostic composition and ribbon/patch drawing over the existing natural terrain renderer. No BicycleController, collision or production scene edits. This is an actual diagnostic-only adapter, not a production system concealed in tests. `test_region_preview.gd:22–33` excludes directories named `region` and `test`, permits only the existing world preview outside them, and fixes its assertion count at 867,597. Therefore this new diagnostic scene belongs in the existing test scope; adding it beside the world preview would break protected isolation/count assertions. Its capture entry point must load the real new scene and R6 domain code. Existing preview behavior, test code and scan expectations remain unchanged.

Explicit new test/diagnostic creation scope (A4):

- `scripts/test/test_road_synthesis.gd`: real production integration, structural/determinism/negative/feature and independent R5 recertification checks.
- `scripts/test/road_synthesis_oracle.gd`: independent sample/curve/water/band measurements; no use of the production final validator as its own oracle.
- `scripts/test/audit_legacy_road_realization.gd`: observational legacy study with actual paths, phase intent, repairs and before/after geometry; no changed legacy thresholds.
- `scripts/test/capture_road_synthesis_map.gd`: full-network maps, profiles, candidate/rejection reports, deterministic battery and benchmark CLI.
- `scripts/test/capture_road_synthesis_preview.gd`: actual Vulkan capture of the isolated preview, saved/reloaded image and provenance checks.

Allow exactly the corresponding `.gd.uid` sidecars for the 15 newly created `.gd` scripts above; do not stage unrelated engine-generated UIDs/import files. The preview scene references its script by path; no other scene/resource file is allowed.

Owned documentation after approval: `implementation_plan.md`, `ARCHITECTURE.md`, `TEST_PLAN.md`, `docs/CURRENT_PROJECT_STATE.md`, `docs/TARGET_ARCHITECTURE.md`, `docs/LEGACY_MIGRATION_MATRIX.md`; create `docs/plans/completed/R6.md` only at approved completion. Amend the migration descriptions to reflect A1/A2 and preserve historical evidence. Do not rewrite Blueprint/Master or completed R1–R5 records. No existing file deletion.

Everything else is forbidden, explicitly including all existing tests/helpers/captures, `tools/verify/**` and `suites.json`, TEST_MATRIX/categories, AGENTS/skills/rules, `project.godot`, `default_bus_layout.tres`, player/camera/controls/audio/UI, RoadPathData/RoadMath/legacy validators/contracts/generators, TerrainCarver, RoadGraph/ForkDecisionModel/ChunkStreamer/WorldManager, existing region planners/terrain/hydrology/biome/rideability and all existing scenes. Temporary launchers/mutants/logs belong in the task workspace `work/` or external evidence outputs, never staged in the repo.

## 11. Milestones and rollback

| Milestone | End-to-end result and stop criterion |
|---|---|
| M0 — approval and source freeze | Record explicit v1.0/A1–A5 approval, exact branch/HEAD/status, source manifest and protected-file digests. Preserve approved plan snapshot externally. If baseline moved, investigate relevant diff before execution. |
| M1 — audited vertical slice | Measure legacy realization on §12 seeds/styles; inventory actual R5 corridor flags/crossings. Implement contracts, local-frame export and one real calm R5 edge through synthesis → validation → ribbon/profile diagnostics. No synthetic-only milestone acceptance. |
| M2 — useful local design | Real secondary/singletrack and mountain development candidates, elevation/earthwork fitting, intent measurements and explicit failure outcomes. Demonstrate a sustained sweep, linked turns and a terrain elevation transition in final geometry, plus a narrow infeasible span correctly diagnosed. |
| M3 — connected geometry and crossings | Shared junction patches/ports/all pair movements; loop/reversal/dedup; required crossing with both approaches; full graph outcome map and barrier recertification. No partial edge geometry masquerading as a complete network. |
| M4 — Alpha character and bounded performance | Execute full development/regression battery, inspect top-down/3D/profile evidence, tune within approved bounds. Freeze coefficients; run the fresh holdout. Preserve every rejected result, fallback count and repair history. Complete performance/release evidence. |
| M5 — independent acceptance evidence | Explicitly invoke slow-cycle-verify on frozen result, then slow-cycle-review in a fresh independent context with plan + diff + verification. Fix within scope and obtain fresh reports after changes. Missing evidence is INCOMPLETE; demonstrated violations FAIL. Independent review is PASS/REJECT. Prepare Director visual evaluation package. |
| M6 — closeout only | After required VERIFY PASS, independent REVIEW PASS and documented human visual judgement of character, archive R6 record, clear root slot to NO_ACTIVE_PLAN and update owned navigation. Stop. Commit/push/merge and R7 need separate user authorization. |

Each milestone is reviewable without committing. No coefficient-by-coefficient human checkpoint. An unrelated legacy failure stays recorded and classified under existing Test Strategy; a required failing gate is not waived by this plan. An unanticipated protected-system defect returns a precise amendment, not compensating player changes.

Rollback is removal of the new isolated R6 files and reversal of only the additive seed accessor and owned documentation, preserving this task's plan/evidence externally. Existing runtime behavior and serialized R0–R5 signatures remain intact. No save migration is introduced; synthesis schema is versioned before any later persistence consumer. Never reset another person's edits or rewrite published history.

## 12. Real-region evaluation and feature realization

Development set: `(184729,0,0)`, `(42,0,0)`, `(77777,0,0)`, `(3,0,0)` (body-heavy natural world), `(10007,3,-2)`, `(2024,-1,-1)`. Include existing R5 regression cases `(3628391,3,-2)` (junction geometry), `(3942578,-1,-1)` (crossing precision), `(5513513,0,0)` and `(5932429,0,0)` (crossing record defects), `(6037158,-1,-1)` (gateway), and the R5 int64-min seed/int32-extreme-region row for precision. Reuse unchanged real R5 graph generation per case within each run, record its signature, and synthesize every edge; no fixture-specific generator branches.

Before tuning, inventory all these graphs and deterministically select representative edge/node/crossing IDs by class, reason, flags and geography. Persist the selection manifest with graph signatures; do not invent IDs in this plan. For a missing category, scan the existing R5 32-region regression set in its published order, selecting the first appropriate case and recording why. A category that cannot be produced is missing coverage, not silently N/A.

Required successful diagnostic cases across at least three generated regions:

| Case | What must be visibly and geometrically demonstrated |
|---|---|
| Calm valley backbone | Sustained spacious line, appropriate directness and long calm intervals; no periodic imposed weaving. Show the entire backbone, not one cropped corner. |
| Flowing secondary | Longer sweeps and a connected turn sequence explained by contours/cover transitions, surviving fitting and export. |
| Winding singletrack | Smaller-scale direction changes and narrower line than backbone, with measured signed curvature and terrain relation; no marker-only winding. |
| Mountain traverse/climb-descent | Real height gain/loss and viable developed length where needed, footprint against hillside, valid in reverse; show cut/fill and rejected too-direct alternatives. |
| Optional technical | A connected optional route with stronger but bounded geometry, an easier R5 alternative still available and no mandatory technical dependency. No stunt requirement. |
| Junction/merge/loop | All incident ports and movements, both traversal directions, equal shared rows, one support patch and loop return without tearing/duplication. |
| Required water crossing | Actual final crossing point, wet span, deck/ford profile and both approach grades; show why the R5 hint was retained/refined/rejected. |

Alpha usefulness requires a continuous valid backbone and at least one connected valid loop/alternative on each of three selected real regions, plus all seven categories above. This is scope coverage, not an aesthetic frequency quota. If entire graphs are PARTIAL, show every failed edge/movement and what connectivity was lost. Do not accept empty output with good rejection diagnostics. Broader corpus success rate is reported by edge, kilometres, class, junction and reason, with no invented universal success percentage. Expected R5-limited failures may be DEBT if the usable slice and evidence above are achieved; a systematic failure that prevents them is a BLOCKER.

Fresh holdout after coefficient freeze: eight seeds `9000011 + 104729*i` for i=0..7, region coordinates cycling `(0,0)`, `(3,-2)`, `(-1,-1)`, `(2,1)`. Process all graphs/edges, retain every outcome, compare reproducibility and failure categories, then inspect selected successes and failures. If used to repair code, call it a regression set thereafter; rerun the complete set and do not describe it as blind. Broaden only to diagnose a concrete uncovered failure, not an endless seed hunt.

Feature records have `feature_id`, kind, class, geographic reason/opportunity, requested s-range and quantitative geometric envelope, selected candidate, final s-range, requested/measured turn angle, curvature sign/lobe/run lengths, vertical rise/fall and grade transitions, status (`REALIZED`, `REJECTED`, `REPLACED_EXPLICITLY`) and reasons. Intent envelopes are set when selecting candidates, before final validation; no relabeling based only on output to fake realization. Feature realization tests derive geometry independently from actual final points/derivatives. A winding claim needs the intended signed sequence; a sustained sweep needs the intended cumulative heading/arc extent; a crest/compression needs its vertical-rate transition/prominence relative to its local baseline, not necessarily a world-space summit.

Report curvature/grade distributions, signed-turn run lengths, total absolute versus net turning, straight and calm intervals, vertical curvature and elevation rhythm, width, cut/fill and design-speed time views at Blueprint timescales. Show overlapping windows as diagnostics, not demands that every window contain a feature. Present requested → generated → repaired → final realization counts with denominators and lengths per class/seed. Repaired geometry losing an intent cannot stay REALIZED. A deliberate calm replacement is explicitly recorded, retains valid geometry and remains subject to human character judgement.

Legacy study (M1): 184729/42/77777 × BALANCED/FLOW/TECHNICAL × 150 chunks, both without and with the production MountainProfile setup; replay each exact configuration. Use the new observational entry point calling unmodified real RoadLogic and read its normal GEOM logs. Per seed/style/config report requested phases, rejected candidates, successful repairs, fatal fallbacks, actual curvature/heading/elevation/contact realization and final invalid chunks. Include forced crest/drop/switchback sequences as separate labeled probes, not prevalence data. Count log occurrences by unique chunk/phase, inspect full result, and record source hashes. This resolves the frequency question without changing old tests. It is not an R6-versus-legacy speed benchmark or a same-geography comparison.

## 13. Verification and negative cases

All engine work after approval uses disposable source copies; editor import may otherwise rewrite bus layouts and generate UIDs. Record engine executable/version/hash, source manifest including new files, config/seed/graph identities, full command, output logs, duration, actual assertions and completion, unexpected errors/warnings/leaks and evidence paths. Planned assertion counts below are intentionally not fabricated; final reports must list measured counts and coverage for each group. No new test has run in this planning turn.

E0: clean disposable import/parse, all new scripts and the new preview load, zero parse errors. E1: production math/contracts, independent geometry oracle and negatives. E2: actual R0–R5 → R6 → exported paths/intents, including copies/reversal and arbitrary edge retrieval order. E3: isolated diagnostic scene only, not main game. E5: real Vulkan saved/read captures. E6: bounded performance/lifecycle measurements. New R6 E4/E7 are N/A because collision/player integration belongs to R7/R8; the existing required virtual-rider gate still runs real legacy physics and is reported as such.

Required checks:

1. Every exported parallel array valid, finite and correctly sized; no duplicate/zero-distance samples; cumulative distance agrees with geometry; tangent/grade/curvature/frame agree with analytical curves and independent point estimates; signed curvature derivative, grade transitions, width/bank, road-edge folding and both-direction approach checks pass.
2. Adaptive curve/ribbon/footprint conformance between samples; water bijection/pins; natural barrier checks and cut/fill/tie-in constraints; no hidden height owner. Validate all final successful pieces, not a prefix.
3. Edge-port-connector continuity, shared node height/patch consistency, loop closure, reversal and one-copy ownership; road-road intersections outside nodes fail. Explicitly test independent lookup order, repeated result construction, immutable-copy mutation, and two reversals.
4. Multiple seeded layouts differ in measured geometry beyond rigid translation/rotation or labels; same effective inputs reproduce canonical bytes twice. Different request/iteration order does not change output. Exact old seed derivation/signatures remain unchanged.
5. Independent real-graph R5 recertification and builder/R6/crossing mutations (§8). New analytic/synthetic tracks may isolate interpolation or impossible geometry, but do not replace any real-region coverage.
6. Existing R0–R5 suites run unchanged on the candidate. Existing RoadMath/PathData/contract/event seams/rhythm suites relevant to reuse run unchanged, with explicit baseline comparison if a legacy failure appears. No retroactive reclassification.
7. Retained gates: `seed_diversity`, `monotony`, `virtual_rider`, `capture_visual_vulkan` through the current Q1 harness; zero unexpected errors/leak warnings under their existing rules. Those four passes are regression evidence for the old runtime, not new-region riding coverage.

| Negative / boundary fixture | Exact primary expected reason or result |
|---|---|
| Null/wrong-type dependency; foreign graph/terrain/hydro/rideability signature | `ERR_R6_INPUT_MISSING`, `ERR_R6_INPUT_INVALID`, `ERR_R6_INPUT_MISMATCH` respectively; null plan. |
| Unknown schema/key, non-finite/out-of-range policy | `ERR_R6_SCHEMA` or `ERR_R6_CONFIG`; no silent default. |
| NaN/Inf coordinate, zero tangent, inconsistent path arrays/export | `ERR_R6_NONFINITE`, `ERR_R6_FRAME`, `ERR_R6_PATH_STRUCTURE`; FAIL/REJECT at the owning boundary. |
| Narrow band, spline overshoot between valid knots, off-edge shoulder/tie-in | `ERR_R6_CORRIDOR_CLEARANCE`; no clamping to boundary. |
| Required grade impossible in tested candidate, sharp/signed-reversal curvature, vertical kink | `ERR_R6_GRADE`, `ERR_R6_CURVATURE`, `ERR_R6_GRADE_TRANSITION`; candidate unavailable. |
| Terrain cliff/barrier overlooked by R5 or missing pinch flag | input discrepancy recorded; final blocked geometry `ERR_R6_NATURAL_BARRIER` unless independently certified permitted engineering. |
| Excess cut/fill, no daylight tie-in, unsupported cliff shelf | `ERR_R6_EARTHWORK`; no invented retaining wall. |
| Missing/phantom/additional crossing, same-channel multiple pins | `ERR_R6_CROSSING_MISSING`, `ERR_R6_CROSSING_PHANTOM`, `ERR_R6_CROSSING_EXTRA`; correct same-channel multiplicity accepted. |
| Deep ford, collinear wet path, lake/body, infeasible deck approach/unsupported span | `ERR_R6_WATER_OCCUPANCY`, `ERR_R6_WATER_BODY`, `ERR_R6_CROSSING_APPROACH` or `ERR_R6_CROSSING_SUPPORT` as isolated by fixture. |
| Conflicting junction elevations/ports, one failed movement, non-node road crossing | `ERR_R6_JUNCTION_HEIGHT`, `ERR_R6_JUNCTION_MOVEMENT`, `ERR_R6_UNPLANNED_INTERSECTION`; dependent network not READY. |
| Tiny intentional seam tear >1 mm, tangent/normal flip, duplicate ownership | `ERR_R6_SEAM`, `ERR_R6_FRAME`, `ERR_R6_DUPLICATE_PIECE`; no fallback. |
| Valid label but straight points, erased lobe/crest after fitting | `ERR_R6_FEATURE_UNREALIZED`; cannot retain REALIZED. |
| Inadequate approach/braking/terrain sightline in either direction | `ERR_R6_APPROACH`; retained as rejected candidate with measured distance. |
| Deterministic budget exhaustion or unresolved adaptive boundary | `ERR_R6_SEARCH_BUDGET`, `ERR_R6_CERTIFICATION_UNRESOLVED`; distinguish from proof of impossibility. |
| Reverse/repeated access, extreme region coordinates, exact shared endpoints | Valid canonical identity, consistent local geometry and seam precision; otherwise `ERR_R6_PRECISION` with measured round-trip/export error. |

Negative fixtures isolate their intended rule; a crash or another earlier failure does not count. Oracle mutation sensitivity must be demonstrated on actual modified production logic in disposable copies. No production behavior branches on fixtures/seeds.

## 14. Commands, captures and performance protocol

Run in a disposable checkout at the frozen source identity. Resolve `$R6Godot` and `$R6Python` to verified installed executables; `$R6Copy` and `$R6Evidence` are absolute external directories. A bounded external PowerShell/Python launcher in `work/` captures raw streams and kills the entire child tree on timeout. Do not modify the existing harness to accommodate new tests.

Existing commands (unchanged interface):

```powershell
& $R6Python tools/verify/sc_verify.py check-manifest
& $R6Python tools/verify/sc_verify.py selftest
& $R6Python tools/verify/sc_verify.py run --suite seed_diversity,monotony,virtual_rider,capture_visual_vulkan --godot $R6Godot --output-root $R6Evidence
```

Proposed new entry-point interfaces to implement under A4:

```powershell
& $R6Godot --headless --path $R6Copy --script res://scripts/test/test_road_synthesis.gd -- --group=contracts --out=$R6Evidence
& $R6Godot --headless --path $R6Copy --script res://scripts/test/test_road_synthesis.gd -- --group=regions --case=184729,0,0 --out=$R6Evidence
& $R6Godot --headless --path $R6Copy --script res://scripts/test/audit_legacy_road_realization.gd -- --seed=184729 --chunks=150 --out=$R6Evidence
& $R6Godot --headless --path $R6Copy --script res://scripts/test/capture_road_synthesis_map.gd -- --case=184729,0,0 --out=$R6Evidence
& $R6Godot --path $R6Copy --rendering-method forward_plus --rendering-driver vulkan --script res://scripts/test/capture_road_synthesis_preview.gd -- --case=184729,0,0 --selection=$R6Selection --out=$R6Evidence
& $R6Godot --headless --path $R6Copy --script res://scripts/test/capture_road_synthesis_map.gd -- --benchmark --case=184729,0,0 --out=$R6Evidence
```

Every run gets a unique output subdirectory. New summaries include attempted/completed cases, edges/pieces/movements, actual checks/failures, source/config/graph hashes and `R6_*_SUMMARY` completion markers. Parse malformed CLI arguments as `ERR_R6_CLI_ARGUMENT` before generation. Read full logs, not just markers. Initial process limits: import 180 s; contracts 180 s; each real region integration/map 900 s; each Vulkan capture process 900 s; legacy audit per seed 300 s; benchmark per case 3600 s (observed asynchronously, not one blocking wait). Existing harness limits remain unchanged. Timeout means INCOMPLETE, not an automatically extended pass.

Top-down maps show natural terrain/contours/water/barriers, faint R5 reference/band, strongly distinguished final R6 centreline and ribbon, ports/patches/crossing pins, feature intervals, failed spans and candidate alternatives. Never use the R5 line as a visual substitute for final geometry. Profile panels share arc distance for signed curvature, grade, elevation/natural elevation, widths and cut/fill, with intended versus final overlays. Include whole-route/network context and closeups of difficult spans.

Capture real Vulkan views of each of the seven selected cases, at least one terrain-aware oblique and one near-road view, plus region overview and representative failures. The preview may show translucent engineering envelopes and deck ribbons, clearly labeled as intent over unchanged natural terrain. It must not hide floating/cutting requirements through terrain deformation or infer collision readiness. Capture provenance includes renderer/device, view transform, effective seed/region, edge/node IDs, policy/graph/result/source signatures, image dimensions, saved/reloaded pixel check and raw logs. Actually open/read every selected image. Human review records class differentiation, flowing geometry, geographic plausibility, adequate calm space and remaining concerns; profiles support judgement but do not replace it.

Performance is measured without concurrent engine workloads on the current Windows/Godot/Vulkan host. Baseline: unchanged R5 graph generation and natural-preview construction on the same machine/build/source, then R6 on those graphs. Warm up once, measure three complete repeats for 184729 and body-heavy seed 3, plus the development case with the most work. Measure stages separately: upstream R5, R6 opportunities/junctions/candidates/fits/certification/export, scene build and capture. Report p50/p95/max per-edge/per-fit durations and query counts; with only three full-region repeats report each value/min/median/max rather than pretending to estimate a reliable p95.

Observational starting targets: R6 additional synthesis ≤120 s per 4 km region, ≤256 MiB additional working set, diagnostic scene frame p95≤33 ms after loading on the previously used GTX 1650 SUPER. These are not established budgets or automatic quality gates. Record before/after maximum main-thread blocking operation and frame stalls separately from post-load steady frames; synchronous diagnostic startup is acceptable if disclosed. Run ten construct/release cycles with the same inputs, clearing invocation caches/results; report object counts, static/process memory trends and leaks. Continuing growth or nontermination is a BLOCKER; a bounded target miss with honest evidence may be DEBT. No thread pool, streaming redesign or unsupported optimization claim. A new performance architecture needs an amendment.

## 15. Risks, classifications and Definition of Done

| Finding/risk | Classification and action |
|---|---|
| A1–A5 not approved | BLOCKER to implementation, not to delivering this plan. |
| Silent invalid success, missing crossing, corridor escape, seam tear, field mismatch, frame flip, hidden fallback, changed protected test/player behavior | BLOCKER; fix within scope or amend before proceeding. |
| R5 reference/band lacks room for a particular road | Expected diagnosed limitation; DEBT if useful connected coverage survives, BLOCKER if representative coherent output cannot be achieved. R5 replanning requires another approved scope; never auto-widen. |
| Quintic overshoot, coarse field gradients, finite-search incompleteness | Mitigate with adaptive geometry/footprint certification, direct height samples, finite diagnostics and independent oracle. Unresolved certified boundary is a rejection. More complete search is ENHANCEMENT. |
| Regional grade policy may exceed current bicycle's comfortable climbing | Explicit A2 design decision; physical validation deferred to R8. No claim of ride-tested safety; R6 can tune geometry inside bounds, not player physics. |
| Final natural surface detail/vegetation, bridge construction, global surface blends | DEBT/future ownership R7/R8/R11/R12. R6 must still provide explicit bounded intent; unsupported geometry is not excused by a future phase. |
| Legacy fallback breadth, 18/19 m conflict, +10° landing tolerance, stale C10/C12, known runtime failures | Existing DEBT preserved, no silent fix/waiver. R6 excludes legacy composition and uses the approved policy; required legacy gate failures still follow integrity rules. |
| Same-platform signatures, no cross-region connection proof, synchronous preview | Accepted proposed Alpha DEBT with measured limits; revisit before cross-platform persistence/R21/runtime streaming. |
| Smaller-radius technical turns, airborne vocabulary, richer local obstacle/visibility modeling, more candidate families | ENHANCEMENT/later phase, not Alpha blockers if the required character/coverage succeeds. |

R6 implementation is done only when the whitelist/contracts are satisfied; all seven real-corridor cases and useful connected coverage are demonstrated; every exported successful piece is certified and every failed piece remains visible; independent natural-barrier/crossing checks and mutants prove sensitivity; determinism/reversal/precision, relevant regressions and retained gates have actual complete evidence; Vulkan captures are saved/read with geometry profiles and human character judgement; performance/release results and all DEBT are recorded; slow-cycle-verify returns PASS and fresh independent slow-cycle-review returns PASS for the exact final source/diff identity; owned docs accurately state remaining limits.

Do not call geometry acceptance a physical ride, E7, whole-game acceptance, R7 completion or proof all R5 corridors are feasible. Do not implement a Journey Director, full Ride Situation Library, route-choice gameplay, new player mechanics, streaming, final terrain, collision, vegetation or bridge assets. Ordinary tuning is autonomous after approval; only genuine blockers delay Alpha, and accepted debt is not reopened without cause.

## 16. Planning-turn result and integrity record

Completed now: read-only repository/authority/source audit and this implementation-ready plan. NOT_RUN: engine tests, legacy prevalence study, new geometry generation, Vulkan, performance, implementation VERIFY/REVIEW. Those are explicit post-approval work, not missing claims disguised as passes.

Test integrity: existing and new test files were not edited or created in this planning turn; no assertion/threshold/category/gate was weakened; no skip, stub, type bypass or test-specific production behavior was introduced; no runtime green status is claimed. The new tests proposed above must call real production code with independent measurements. No production source, scene, resource or project setting was changed. No commit or push is authorized or performed.

STOP here for Game Director review of v1.0 and A1–A5. Open choices are the explicit approval decisions, not an undecided algorithm menu. Defaults are fully specified; exact candidate scoring coefficients and selected real graph IDs are implementation measurements/tuning within the approved design, not reasons to require another preliminary planning phase.

## 17. Execution log, implementation decisions and evidence (post-approval)

Status: IMPLEMENTING (M0–M4). Engine runs only in disposable copies under the external workspace `C:/Users/Luisa/Documents/Codex/2026-10-09/r6-road-synthesis/` (`work/run.py`, `work/sync.py`, raw runs under `outputs/evidence/runs/`); nothing there is staged.

M0: approved v1.0 snapshot SHA-256 76bb517c…291df kept externally; baseline HEAD f268dfe, branch r6-road-synthesis-adapter, only this plan unstaged.

M1 inventory (6 development regions, real R5): 16–26 edges per region; backbones are flat valley edges with creek fords / small bridges / major-river bridges; singletrack and technical edges climb 70–300 m with R5 reference grades up to 0.56–0.74 and bands of only ±25–35 m (R5 technical g_max .38 vs R6 hard 12° = .213). Natural queries cost ~120 µs (height) and ~0.7 ms (R4 sample), which fixed the search/certification split below.

Implementation decisions inside the approved design (recorded for review; none changes a hard bound, contract owner or protected file):
- Candidate families (§5 step 4) are realised as bounded corridor-lattice dynamic programmes (stations along a smoothed axis, lateral slots certified inside the band) under three terrain weight profiles DIRECT / TERRAIN / FLOW — finite, deterministic, ≤3 candidates per edge; development emerges from the grade cost and wide lateral steps in steep stations (traverses up to ~80° off the axis), not from a pattern. Not a general optimiser: one exact shortest path per profile on a fixed finite lattice.
- Fitting: discrete fairing with per-row smoothing escalated only where curvature fails, then the approved G2 quintic plan spline (C4: quintic kept; no simpler method proposed yet). Profile: grade-limited (Lipschitz) feasible band between hard bounds, then bounded slab projections; quintic interpolant on 2 m samples re-certified at 0.5 m; bounded attempt ladder drops comfort/jerk shaping (never the retained hard limits) where infeasible next to pinned port grades.
- Search uses a lazily filled 8 m natural height lattice and the R4 16 m cost lattice; every final certification uses exact public R3/R4 point queries.
- C1: per-edge port radii grown greedily from PORT_RADII_M (14–64 m, inside the 96 m zone) while an essential movement fails; patch plane graded up to the stricter class's preferred grade (≤10 %); patch earthwork is measured on the connector ribbons; a movement over its limits is unavailable, not the junction's edges.
- C2: envelope fixed before implementation (§0). A pin on a channel tip is aimed 6 m into the same channel (degenerate R5 record), still inside the envelope.
- Crossing semantics: unmatched pin whose channel exists at the pin = MISSING, no channel there = PHANTOM; an additional real crossing = EXTRA; same channel beyond 12 m = DISPLACED.

Evidence so far (not final; candidate not frozen): contracts group 72/72 checks, regions group 184729 351/351 checks (oracle path, reversal, seams, band, crossings, barriers, determinism, C1–C3). First 12-region battery: backbones 44/49 edges READY, secondaries 26/55, singletrack 1/35, technical 0/7 — the singletrack/technical result was classified BLOCKER (required categories) and drove the development/lattice/profile fixes now being evaluated. Legacy audit (unmodified RoadLogic, 3 seeds × 3 styles × 2 profile configs × 150 chunks, replays identical): 0 rejections / repairs / fallbacks observed; 57–65 % of length with |k| < 1/1000; forced switchbacks realise ~90° (not 90–120°); one forced winding phase realised 7°.

### Resume point (paused by the user, 2026-10-09)

Nothing committed; all R6 files are untracked/modified in the working tree on `r6-road-synthesis-adapter`. New: 9 domain files under `scripts/world/region/` (policy, plan, synthesizer, corridor geometry, alignment designer, regional math, junction planner, feasibility validator, roadbed intent), additive seed purpose in `region_seed_derivation.gd`, `scripts/test/{test_road_synthesis, road_synthesis_oracle, audit_legacy_road_realization, capture_road_synthesis_map, capture_road_synthesis_preview, road_synthesis_preview}.gd`, `scenes/test/road_synthesis_preview.tscn`. `.gd.uid` sidecars not yet created in the repo (copy from the imported disposable copy at closeout).

In flight at pause: iteration 3 battery (runs `i3A/i3B/i3C`: 184729, 77777, 2024, 10007, 42, 3) testing the fillet-bound lattice curvature, local grade-escalation retries and the diagnostics sanitiser (2024 previously FAILed on a non-finite diagnostic); R5 STEEP_PINCH scan (`scan_pinch`) for the R5-pinch mutant.

Next steps: (1) aggregate i3 (`work/aggregate.py i3A i3B i3C`) against b1; keep backbone continuity, raise singletrack/technical READY counts (BLOCKER: required categories); (2) rerun contracts + regions test groups; (3) mutants (`work/mutants.py runtime3 "<cases>"`); (4) full development + regression battery with close-ups, Vulkan captures for ≥3 regions, holdout (`--holdout`), benchmark (`--benchmark`); (5) retained Q1 gates and R0–R5 suites unchanged; (6) owned docs; (7) return the frozen candidate package to the Director before final VERIFY/REVIEW. Do not start R7.

Iteration 3 result (finished after the pause; 6 regions): backbones 43/43 READY and continuous in all 6 (b1: broken in several); region 2024 no longer FAILs (non-finite diagnostic sanitised). Secondaries 23/51 (lower than b1 26/55 on more regions: new FRAME ×5 certification mismatches and GRADE_TRANSITION ×5 to investigate). Singletrack 0/23 and technical 0/6 remain the BLOCKER. R6 time rose to 90–430 s per region (2024: 432 s — over the 120 s observational target; wide development lattice). R5-pinch mutant region found by deterministic scan of the R5 regression order: seed 3104746 region (-1,-1) (k=1, 4 STEEP_PINCH stations).

### Iteration 4 (2026-10-10; session ended by the user at end of day — nothing committed)

Changes (all inside the whitelist, no hard bound / contract / protected file touched):
- `regional_road_math.gd`: new exact vertical-profile solver `solve_profile` (forward reachability polygons in the (height, grade) state, exact feasibility, backward target tracking). `road_alignment_designer.gd` `_profile`: up to 300 least-movement projection sweeps now only prepare the tracking reference; feasibility is decided by the exact solver (first infeasible sample reported). Start/end grade pins are states (no more pinned samples 1 / n-1). Margin shrinks on sections narrower than 15 cm; deck lower bound +2 cm. Policy ALGORITHM tag updated (`reachability_profile`).
- Adaptive export sampling (`_refine_positions`): intervals subdivided where chord heading / chord slope / turn rate disagree with stored derivatives (cause of the FRAME failures was vertical-curvature jerk at 2 m sampling; the validator tolerance is unchanged).
- Search work: sparse lateral step offsets (`_step_offsets`), refinement stops when it makes no progress (`refinement_hopeless`), exact heights in `_grade_reach`, `_reach_context` adds measured lateral room / crossing window / required length ratio to GRADE failures. Port curvature ramp in the DP (`PORT_RAMP_SHARE`), DP curvature cut-off 1.2 x k_hard, fit escalation caps, `first_attempt` detail on plan-fit failures.
- Crossings: wet span of a crossing is measured on centre and both riding edges (`_wet_extent`), not only the oblique-line estimate (fixed WATER_OCCUPANCY at 77777 e9).

Measured (quick cycle, no close-ups, runs `q1a/b/c` after the solver; `q2*` after wet-extent): FRAME ×0 and GRADE_TRANSITION ×0 (were 5 + 5 over six regions); 184729 13/16 edges (was 11/16), 77777 10-11/16, 2024 14/26 (was 11/26); backbones continuous everywhere; first READY singletrack edge (calm, 0.29 km). DP work per steep edge roughly halved (e13 18 s -> 9 s); region time 64-183 s with 3-11 engine processes running in parallel (not a clean benchmark).
Category scan (free-end pre-screen with the pre-ramp code, R5 regression regions k=0..31, `scan_a0..7`, 161 steep edges): singletrack 37/127 valid (21 of 32 regions have at least one), technical 0/34 (GRADE 20, CORRIDOR_CLEARANCE 8, CURVATURE 3, EARTHWORK 2, GRADE_TRANSITION 1). Winding singletrack is therefore obtainable from regression regions (e.g. k=0, 7, 15, 28, 31); optional technical is NOT yet demonstrated - R5 technical corridors climb up to g .38 vs R6 hard 12 deg (.213) and bands are narrow; if no READY technical edge appears after the remaining robustness work, a concrete amendment must be prepared for the Director (candidates: technical hard grade / a development allowance; no change made).
Known remaining failures: secondary GRADE (2024 e7, e12, e15: development shortage 7-14 m excess, e15 port-pinned heights), plan-fit CURVATURE (2024 e13, e22: DP corner near the limit, fit diverges), singletrack GRADE near crossing windows (lattice cannot weave there, e.g. 3104746 e21), `ERR_R6_CROSSING_SUPPORT` at 77777 e11 (deck lower bound, fixed by the +2 cm margin, not yet re-measured).

### Resume point (end of 2026-10-10 session)

Nothing committed. Unaggregated runs (check first): `q3a/q3b/q3c` (184729 / 2024 / 77777 with the latest code: ramp, 1.2 k_hard, caps, deck margin, reach context) and `tc3` (contracts group on the latest code) under `outputs/evidence/runs/`; aggregate with `work/aggregate.py q3a q3b q3c`, read `tc3/stdout.log` (`R6_TEST FAIL` lines). `work/runtime2` holds the latest code (probes in `runtime2/probe/`: smoke2, scan_steep, dpexp*, edge_map3, fitdbg; `work/dbg_patch.py` + `runtime4` = instrumented copy).
Next: (1) read q3/tc3; fix regressions; (2) remaining secondary failures (GRADE development, plan-fit CURVATURE); (3) rerun the singletrack/technical scan with the latest code and run full synthesis on regression regions with READY singletrack candidates (take the winding-singletrack category from them); decide technical (found / amendment); (4) performance <= 120 s per region on a quiet machine; (5) test groups contracts + regions, then freeze and run the full battery, holdout, mutants, Vulkan, benchmark, legacy audit, retained gates; (6) docs + `.gd.uid` sidecars; (7) C5 package to the Director before VERIFY/REVIEW. No R7.

### Final record of the implementation turn (2026-10-10) - frozen candidate returned to the Director (C5)

Frozen candidate: file manifest `outputs/evidence/freeze2_manifest.json` (17 R6 source/test files), manifest digest `ea7d3ef12ecf002f6e11e86f6fbee454ab5fc47670bb8373892ba39ed04409f9`; engine Godot 4.7.2 mono; evidence in the external workspace `outputs/evidence/runs/g_*` (battery, holdout, tests), `outputs/evidence/mutants/*_final`. Changes after iteration 4: search ladder (`SEARCH_ATTEMPTS`: curvature cut-off 1.2/1.6 x hard, extra band clearance 0/3/7 m; retried only for clearance / curvature / bridge-approach / grade-transition / earthwork failures), development stage (`_develop`: bounded length reward on a failing steep stretch, with a probe of the longest buildable lattice line), blocked-node reasons in lattice failures, `.gd.uid` sidecars for the 15 new scripts.

Tests (frozen candidate): contracts 72/72; regions 184729 411/411, 2024 638/638, int64-min seed @ int32-extreme region 624/624; zero failures. Mutants (disposable copies): r5_pinch_flag killed (3104746, `r5_recert_steep_flagged`); r5_deep_water killed (77777, also 3628391 and 6037158, `r5_recert_deep_water_recorded`); r6_omit_crossing killed (184729, `crossing_records_complete`, `oracle_crossings_11`); r6_barrier NOT killed and not exercised in 24 regions (search never picks barrier geometry even with guards removed) - recorded as DEBT, not PASS.

Battery, 12 development + regression regions (close-ups, maps and profiles under `g_d*`, `g_r*`): backbone 84/86, secondary 86/112, singletrack 15/61 (13.6 km), technical 0/15; every region PARTIAL; backbones continuous in 10 of 12 (3942578 e6 footprint clearance -7.8 m, 5513513 e3 crossing displaced 13-17 m > 12 m envelope: R5-regression regions, disclosed). Realised features (READY edges): backbone CALM 78/78, LINKED_TURNS 25/25, SWEEP 46/46; secondary SWEEP 148/148, SWITCHBACK 18/18, CLIMB 22/22, DESCENT 25/25, COMPRESSION 2/25 (23 explicitly unrealised), LINKED_TURNS 47/48; singletrack SWEEP 21/21, LINKED_TURNS 7/7, DESCENT 5/5, CLIMB 2/2, SWITCHBACK 1/1. Holdout (8 fresh seeds, not used for tuning): 7 regions synthesised (backbone 47/48, secondary 42/62, singletrack 7/23), seed 9628385 @ (-1,-1) is R5-invalid (`ERR_ROUTE_GRAPH_INVALID`, upstream).

Failure inventory (12 regions): secondary GRADE 12 / CLEARANCE 5 / CROSSING_MISSING 3 / GRADE_TRANSITION 2 / others 1; singletrack GRADE 26 / CLEARANCE 9 / GRADE_TRANSITION 5 / others; technical GRADE 11 / others 4; junction movements 92 unavailable (57 essential). GRADE failures are measured lattice limits (longest buildable lattice line on the steep stretch shorter than required; room, ratio and crossing window recorded in the summaries). Category scan on the 32 R5 regression regions (free-end pre-screen): singletrack 43/127 valid, technical 0/34; what-if with technical hard grade 15/18/21 deg: 0/1/1 of 34 - limiting factors are cross-slope earthwork bounds and cliffs/narrow bands, not grade alone.

Classification. BLOCKER (required category): optional technical route not demonstrated - needs a Director amendment (options: R5 follow-up so technical corridors follow buildable terrain; or an explicit technical development/earthwork allowance in policy A2). DEBT: secondary/singletrack development shortages (hairpin geometry beyond the monotone lattice), plan-fit curvature failures, unavailable junction movements, r6_barrier fixture, crossing precision on two R5 regions, R5-invalid holdout seed, COMPRESSION realisation, performance not benchmarked. ENHANCEMENT: switchback/hairpin generator, more candidate families.

Deferred by explicit human decision (user message 2026-10-10: "Benchmark, R0-R5, Vulkan ... gates Q1 - отказаться, прописать в документации, один спринт после R8 чтобы всё проверить"): Q1 gates (seed_diversity, monotony, virtual_rider, capture_visual_vulkan), existing R0-R5 suites on the candidate, Vulkan captures, benchmark/performance protocol. These are NOT passed and NOT waived by this plan; the verification sprint must run them. Legacy audit was not re-run (observational, legacy code unchanged; earlier evidence `legacy1/legacy2`). Independent slow-cycle-verify and slow-cycle-review were not run; per AGENTS.md completion needs both. No commit, push or R7.
