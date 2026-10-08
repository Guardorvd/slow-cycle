TASK: R4 — Biome + Rideability Fields
DATE: 2026-10-07
STATUS: REVIEWING — R4 Alpha candidate; technical evidence complete; Alpha acceptance/M6 pending
BRANCH: r4-biome-rideability-fields
BASE / HEAD: cab2fb705a274df60bac516bb13ce3fdbddd7858 (R3 complete)
BASELINE: source checkout has only unstaged implementation_plan.md (approved v1.0); staged/untracked none. Isolated local clone at work/candidate preserves that plan.
AUTHORIZATION: human 2026-10-08 explicitly approves R4 ExecPlan v1.0 and implementation through M1–M5.
IMPLEMENTATION APPROVAL: approved in current chat 2026-10-08, including exact additive scope. Four clarifications: blocked is a natural barrier without engineering; coefficients/thresholds are Alpha tuning; autumn must not read as an ellipse; verification proportional, targets observational. No R5.
NEXT: matching independent reports and Game Director R4 Alpha acceptance; no R5 started

---

# R4 ExecPlan v1.0

## 1. Outcome and boundaries

Give the existing Mountain River Valley two reusable world-space answers: what environment belongs at a point, and how naturally traversable that point is before a road exists. R5 can consume these answers without knowing how biomes were generated or reading render data.

Deliver `BiomeField` and `RideabilityField`, a small shared signal context, a bounded hydrology query, additive contract tests, and diagnostic maps/overlays. Keep WORLD FIRST → ROUTE SECOND → ROAD THIRD. R4 does not create a surface, alter heights, or wire the regional pipeline into the game.

Excluded: route planning or graph search, road synthesis, crossing/ford selection, vegetation instances, production graphics/assets, FinalSurface, streaming/LOD, threading, gameplay, collision, bicycle/camera/controls, and general terrain/hydrology polish. Costs are environmental planning information, not bicycle physics limits or a guarantee that a route segment is safe.

This document is the only repository change authorized in the present step. The whitelist below describes the proposed implementation after approval.

## 2. Inspected state and evidence limits

Authority read: root/world/test `AGENTS.md`, `.agent/PLANS.md`, `slow-cycle-worldgen`, frozen test-integrity rule; Blueprint §§7,10,18,30; Master R4/R5 and architectural principles; Target Architecture, migration matrix, Test Strategy and Current Project State. Completed R1/R2/R3 outcomes, contracts, validation history and deferred findings were inspected. Implementation inspection covered the region identity/seed/plan path, TerrainField and renderer, HydrologyGenerator/Plan/Field/Surface, preview/capture tools, terrain/hydrology contract tests and Q1 harness instructions.

| Observed source | Consequence for R4 |
|---|---|
| `TerrainField` is an immutable prepared base-terrain query; closed 4096 m region, world coordinates, 16 m lattice, ±16 m derivative stencil with one-sided edge handling. | Preserve its numerics, schemas, bounds and point/lattice parity. Do not sample the macro evaluator directly. |
| `HydrologySurface` composes base height plus hydrological deformation and uses the same derivative stencil. | Its slopes include existing banks/gullies. Use them for the pre-road environmental sample, through one context boundary. |
| `HydrologyField.sample_water` uses local channel buckets and body-cell membership, then tests water level against composed ground. | Use it as the water authority. Distance zero is not proof of water. Do not reconstruct depth from biome moisture. |
| `sample_proximity` searches expanding 128 m rings, searches twice (all water/major river), and scans all body cells. | Full nearest-feature search is unnecessary for a bounded moisture influence. R3 recorded about 0.6 ms/point, or about 40 s for 256² calls. These are historical measurements, not fresh R4 benchmarks. |
| `sample_proximity().in_floodplain` tests R1 valley-floor membership. `floodplain_reaches` stores major-river station intervals and a wetness flag. | These are different concepts. R4 names its broad signal `valley_floor_weight`; it does not claim reach membership or consume `floodplain_reaches` in Alpha. |
| Drainage has 129² points at 32 m; area is cheap, catchment/terminal identities are discrete. Bodies also use lattice cells. | Smooth only scalar environmental influence. Do not interpolate categorical IDs, water masks or barriers. |
| RegionPlan does not own hydrology; HydrologyPlan returns deep data copies and has its own signature. | Keep R4 products separate from RegionPlan. Snapshot consumed descriptor data once at creation. |
| R3 validator leaves some crafted-plan body-ID/area consistency gaps (R3-D16). | Guard consumed data before constructing the R4 context; do not broaden R3 validation or trust unchecked array indices. |
| Existing domain suites protect R0/R1/R2/R3 and preview source/ownership contracts. | Add tests in a new file. No edits, reclassification or count changes to existing tests. |

Historical accepted evidence: R0 145/0, macro 4269/0, terrain 2178/0, hydrology 299/0; preview 867597/0; R3 independent VERIFY #2 PASS and independent REVIEW PASS. These are reference baselines only. No engine, runtime, performance or visual acceptance tests were run during this planning task. C10/C12 remain OPEN and whole-game runtime acceptance remains INCOMPLETE.

## 3. Architecture, ownership and migration decisions

```text
RegionPlan ──→ TerrainField ───────────────────────────┐
     └───────→ HydrologyGenerator → HydrologyPlan ────┤
                                                     ▼
                                      EnvironmentContext (R4 helper)
                                      owns matching HydroField +
                                      transitional HydroSurface,
                                      immutable derived scalar data
                                          │               │
                                          ▼               │
                                      BiomeField ─────────┤
                                                          ▼
                                                   RideabilityField
                                               (future R5 consumer)

fields → diagnostic maps / preview only
```

The context is a sampling/composition helper, not a new authoritative world layer. It owns no generated terrain/water truth, exposes no height-surface API to renderers, and never returns mutable upstream storage. One context is shared by the two fields for one input identity. Biome does not depend on rideability. Rideability consumes continuous environmental values from biome, not its dominant label.

| Owner | Decision |
|---|---|
| RegionPlan, R1 generation/evaluator, TerrainField | KEEP byte-unchanged. Geography and base-terrain ownership remain intact. |
| HydrologyGenerator, HydrologyPlan, HydrologySurface | KEEP byte-unchanged. No hydrology regeneration, geometry or deformation changes. |
| HydrologyField | EXTEND with a bounded distance query and a derived body proximity index. Existing public methods, results and schema tag remain unchanged. |
| RegionSeedDerivation | EXTEND with the registered `biome` purpose and matching seed/preimage helpers; all existing preimages/results unchanged. |
| EnvironmentContext, BiomeField, RideabilityField | CREATE pure RefCounted query components; immutable after construction, no thread-safety claim. |
| Existing region preview | ADAPT through opt-in environmental display modes only. Existing default and hydrology-only modes remain unchanged. |
| TerrainTileRenderer, legacy runtime, foliage, player | KEEP unchanged. No replacement or retirement in R4. |

### Terrain choice and R7 compatibility

Use the existing HydrologySurface's composed height and gradient for R4 slope/aspect: the pre-road world already contains river banks, floodplain shaping and gullies. Raw TerrainField slope alone would ignore these. The gradient remains the R2 32 m-wide stencil; it is a planning-scale signal and can miss a sub-grid cliff or narrow gully. Exact water queries protect narrow water barriers independently.

Only EnvironmentContext knows how that natural surface is assembled. Record its semantic basis as `BASE_PLUS_HYDROLOGY_PRE_ROAD`, along with the actual terrain/hydrology/surface schema tags. In R7, replace this internal composition with the equivalent natural-terrain sampling path from R7's composition machinery. Do not automatically bind R4 to the road-deformed final surface: R5 → road deformation → R4 → R5 would introduce feedback. Runtime contacts and placement will use FinalSurface under R7/R9/R11; these pre-road planning fields remain environment data. No general surface interface, R7 implementation, or new `BiomeSurface`/`RideabilitySurface` is introduced now.

## 4. Query contracts and failure behaviour

Use the existing Dictionary result convention: `is_valid`, `reason_code`, plus the successful payload. New schema tags are `slow_cycle.environment_context/1`, `slow_cycle.biome_field/1` and `slow_cycle.rideability_field/1`. Creation returns a null product on failure. Failed queries carry no usable success payload; callers must check validity. All successful numeric environmental outputs are finite.

| API | Contract |
|---|---|
| `EnvironmentContext.create(region_plan, terrain_field, hydrology_plan)` | Validate types, plans, bounds and signatures; guard consumed hydrology data; create a matching HydrologyField and HydrologySurface internally. Return `{is_valid, context, reason_code}`. Do not accept unrelated caller-supplied surfaces. |
| `BiomeField.create(context)` | Derive one small biome character and pocket descriptor, then immutable field. Return `{is_valid, field, reason_code}`. |
| `RideabilityField.create(context, biome_field)` | Reject a different context identity/configuration. Return `{is_valid, field, reason_code}`. No independent RNG. |
| `BiomeField.sample(x, z)` | World metres. Return `weights` in fixed order CONIFER/MEADOW/RIPARIAN/AUTUMN, `dominant`, `is_water`, `moisture`, `woody_cover`. Dry weights are finite, nonnegative, sum to one; deterministic enum-order tie break. Water returns `dominant=WATER`, zero land weights, zero woody cover. WATER is a mask/sentinel, not a fifth land biome. |
| `RideabilityField.sample(x, z)` | Return `cost`, `class`, `blocked`, `reason_flags`, `gradient`, `slope_grade`, `is_water`, `water_depth_m`. Cost is finite [1,16], a dimensionless per-distance planning multiplier. `blocked` is authoritative; cost 16 alone never means a barrier. |
| Both fields: `sample_lattice(i0,j0,count_x,count_z)` | Reuse TerrainField's world-anchored 16 m integer indexing, closed-domain limits and row-major order. Packed column arrays with the same named outputs; biome weights flattened point-major, four values per point. Bit-identical to point queries at those positions. Maximum one region (257² points); no arbitrary unbounded batch API. |
| Both fields: bounds / region signature / input signature / field signature accessors | Input identity covers RegionPlan and HydrologyPlan signatures, schemas and semantic surface basis. Field signature also covers versioned model parameters and biome character/pocket descriptor. Signature identifies the recipe, not a claim of cross-platform floating-point equality. |

The context has an internal/shared signal sampling path used by both point and lattice operations. During rideability sampling, get signals once and pass them through the same biome scoring kernel used by BiomeField; do not call the entire biome sampler and then resample terrain/water. This helper is ordinary production logic, not a test injection hook. Lattice sampling uses HydrologySurface.sample_lattice for shared height/gradient work; it does not implement a second derivative formula or retain an unbounded query cache.

Validate before converting world coordinates into local vectors or multiplying lattice indices. World origins/indices stay int64 and scalar float64; subtract the region origin before using Vector2/local spatial noise. Preserve valid extreme-region queries.

Fixed failure reasons:

- Context: `ERR_ENV_INPUT_MISSING`, `ERR_ENV_INPUT_INVALID`, `ERR_ENV_INPUT_MISMATCH`, `ERR_ENV_HYDRO_DATA` (consumed-data guard), `ERR_ENV_DEPENDENCY` with the original dependency reason in diagnostic detail.
- Biome creation: `ERR_BIOME_CONTEXT`; rideability creation: `ERR_RIDEABILITY_CONTEXT` or `ERR_RIDEABILITY_BIOME_MISMATCH`.
- Queries: `ERR_ENV_NONFINITE_INPUT`, `ERR_ENV_OUT_OF_DOMAIN`; lattice counts checked first with `ERR_ENV_GRID_SHAPE`, then integer domain checks. No clamping an invalid query into the region.

The context's hydrology guard checks body IDs equal their array indices, cell indices are in range and have unambiguous membership, valid body kinds, nonnegative drainage areas, finite/valid consumed frame ranges, positive relief and compatible origins/schema/signatures. Validate these consumed representations before HydrologyField construction. This is local consumer validation, not a replacement HydrologyPlan validator. Catchment semantics, outlet validation and floodplain-reach validation stay deferred because R4 does not rely on them.

## 5. Environmental signals and bounded hydrology work

### Bounded distance, not a dense full-proximity raster

Add `HydrologyField.sample_proximity_bounded(x, z, radius_m)` returning `{is_valid, distance_to_water_m, is_capped, reason_code}`. The radius is finite and in (0,256] m; invalid radius returns `ERR_HYDRO_PROXIMITY_RADIUS` after the existing coordinate validation. R4 uses 160 m. Distance is `min(nearest geometric water-edge distance, radius)`; `is_capped=true` when no smaller distance exists. There is no nearest feature identity or separate major-river search.

Reuse existing channel segment projection/width interpolation. Visit only spatial buckets overlapping the radius expanded by the maximum channel half-width, including segments crossing bucket boundaries. A separate fixed 128 m body-cell index created during `_build` supplies nearby body cells; search the radius expanded by 16 m and retain R3's existing body proximity approximation (distance to cell centre minus 16 m, clamped to zero). Keep `_nearest`, `sample_proximity`, `sample_water` and deformation semantics unchanged. Stable index traversal and local/per-call deduplication must not mutate shared query state.

The bounded result must equal `min(old sample_proximity.distance_to_water_m, radius)` within numeric tolerance on an independently selected point set. The index is derived from HydrologyPlan; it neither creates water nor changes its extent. Proximity describes recorded channel/body geometry, including places where the exact water predicate may be dry. It is suitable for environmental influence, not collision or wet-mask truth.

This avoids expanding to far-away river buckets and scanning every body cell for every point. It is bounded geographically, not a promise of constant candidate count for arbitrarily dense plans. Record candidate density and timings on body-heavy regions. No new global distance cache, distance-transform framework or asynchronous job system is needed.

### Broad environmental inputs

- Natural height/gradient: HydrologySurface, sampled once per point or shared lattice block. `slope_grade = length(gradient)`; aspect derives from downslope direction with a smooth fade to neutral on almost-flat ground. Fix world north to -Z; do not rotate north with the valley frame.
- Relative elevation: natural height above the local fitted valley-floor elevation from the copied R3 river frame, divided by positive R1 relief. This measures land position within this region, not a simulated global climate lapse rate.
- Valley context: continuous weight that fades across a band around the R1 floor edges using the existing frame helpers. It is named valley context, never floodplain-reach membership.
- Moisture: a bounded blend of water influence, a weak valley-floor bias and contributing-area influence. Precompute `log1p(area_m2)` once from the 32 m lattice, apply one small fixed separable smoothing pass, normalize using model constants, and bilinearly interpolate the scalar. Do not derive moisture from categorical catchment/terminal IDs or call full proximity across that lattice.
- Water: exact `sample_water` per requested point, unchanged. Copy `is_water` and finite depth; do not expose its dry `water_surface_m=NAN` as a valid R4 scalar.

The drainage grid contributes weak broad moisture only. The riparian band is evaluated continuously from bounded segment/body proximity at the actual point. The 32 m lattice therefore does not set visible biome borders. It still limits the accepted body-water geometry; do not hide that inherited R3 limitation by smoothing barriers.

## 6. Biome model: four blended land identities

Use a small continuous scoring kernel and a compact seed-derived character, not an ecological simulation or independent random draws per query.

1. Conifer is the default wooded environment on lower/middle slopes, strengthened by shaded aspect and moderate moisture.
2. Meadow/open grassland gains affinity on upper terrain, gentle open ground and warmer/drier aspects. Smooth ecological preferences must not make all valley floors meadow or all slopes forest.
3. Riparian vegetation gains a local continuous influence near channel/body edges, modulated by gentle terrain and moisture. Water itself remains the separate mask.
4. Autumn woodland is a localized transfer from suitable woodland affinity. It is a coherent pocket with a smooth border, not scattered noise pixels or a season simulator.

Compute nonnegative raw affinities and normalize once, with a positive background conifer/meadow contribution so dry samples never have an all-zero vector. Woody cover is a continuous *potential cover/resistance* estimate from the mixture and moisture, attenuated on very steep exposed ground. It does not assert that a tree or rock instance exists. The dominant biome is diagnostic; rideability consumes the continuous values.

Derive a `biome` child seed from region identity, then choose a modest forest/open balance and pocket size/shape. Use deterministic low-frequency world-position variation (roughly 300–800 m wavelengths, small amplitude) to break broad boundaries. No per-query RNG, global seed, timer, traversal-order or allocation-ID dependency. Keep integer seed/preimage provenance and quantized descriptor values in the signature. Float noise is only claimed deterministic on the same engine/platform, consistent with R1–R3.

Locate one autumn pocket using a fixed 256 m interior candidate lattice. Rank dry, gentle-to-moderate, lower/middle, woodland-suitable sites by geography and a bounded seed-derived tie preference. Anchor an ellipse in the existing valley frame, with initial radii about 150–350 m and a 60–120 m feather. Sample actual signals for eligibility; do not assume descriptor pass/basin markers guarantee suitable topography. If no suitable candidate exists, record `NO_SUITABLE_AUTUMN_SITE` and keep the field valid with no fabricated pocket. Repeated absence across the validation battery is a model defect; an isolated geographically justified absence is recorded for Alpha review.

Starting tuning ranges: water moisture influence fades to zero at 160 m; riparian affinity transitions mainly over the first 10–60 m; elevation-driven meadow preference transitions broadly through relative elevation 0.45–0.8. These are Alpha model parameters, not test or ecology laws. Tune within this model using the full seed battery and record final values/digest before verification. Do not add classes, new terrain owners or special seed branches while tuning.

## 7. Rideability model: continuous cost plus explicit barriers

Use one transparent, monotone cost model. Let S be slope resistance, C continuous woody-cover resistance and M saturated/wet-ground resistance, each in [0,1]. Initial dry-land cost is `clamp(1 + 4*S + 3*C + 2*M, 1, 16)`, with S smoothly increasing from grade 0.05 to 1.0. No random rideability multiplier and no lookup table keyed only by the winning biome.

Initial classes: OPEN for cost <2, RIDEABLE for cost <4, otherwise DIFFICULT. Explicit barrier rules override class and set `blocked=true`, class BLOCKED and cost 16:

- water depth >=0.35 m → `DEEP_WATER`;
- natural slope grade >=1.0 (45°) → `EXCESSIVE_SLOPE`.

Any positive-depth water sets `WATER_PRESENT`; shallower water is at least DIFFICULT with cost at least 8. High woody cover and moisture expose `DENSE_COVER`/`WET_GROUND` contribution flags; dense woods incur difficulty, but absent tree placement cannot certify exact impassable gaps. Flags explain successful world classification and are distinct from invalid-query reason codes.

These are conservative Alpha natural-travel preferences, not new limits imposed on RoadLogic or BicycleController. Tune coefficients/thresholds on geographic evidence before freezing the implementation; protect relationships rather than arbitrary biome coverage percentages. Deep-water blocking does not depend on R3 channel depth being monotone downstream. A narrow river remains visible to a point query even between lattice nodes.

Return the signed terrain gradient so R5 can later consider travel direction. R4 does not calculate directional route cost, segment clearance, connectivity, crossing permission or slope along a planned route. R5 must sample between endpoints and handle water/crossings explicitly: two rideable points do not certify a rideable connecting edge. R7/R9 later supply actual surface/contact detail.

## 8. Proposed exact file scope

Paths in this section are repository-relative. `.uid` sidecars are allowed only for the six new GDScript files listed below. No deletions.

| Action / file | Responsibility |
|---|---|
| CREATE `scripts/world/region/environment_context.gd` | Input identity, consumed-data validation, matching natural-surface composition and shared scalar/point/lattice signals. |
| CREATE `scripts/world/region/biome_field.gd` | Character, pocket, continuous biome kernel and queries. |
| CREATE `scripts/world/region/rideability_field.gd` | Cost, classes, barrier/reason flags and queries. |
| MODIFY `scripts/world/region/region_seed_derivation.gd` | Add biome purpose/preimage/seed functions only. |
| MODIFY `scripts/world/region/hydrology_field.gd` | Add bounded proximity and derived local body index only. Preserve old answers and schemas. |
| MODIFY `scripts/world/region_preview.gd` | Opt-in `--environment=biome|rideability`; default off. Automatically compose hydrology in these modes; add presentation-only colors/legend/metrics. |
| CREATE `scripts/test/test_environment_fields.gd` | New R4 positive, negative, integration and determinism tests, including bounded proximity parity. |
| CREATE `scripts/test/capture_environment_map.gd` | Headless maps, transects, deterministic diversity sweep and observational benchmark mode. Strict CLI grammar. |
| CREATE `scripts/test/capture_environment_preview.gd` | Real Vulkan captures through opt-in preview, complete source/diff provenance and output validation. |
| MODIFY `implementation_plan.md` | Approval, progress, decisions, evidence and findings; root-slot closeout after acceptance. |
| MODIFY `ARCHITECTURE.md` §5, `docs/CURRENT_PROJECT_STATE.md`, `TEST_PLAN.md` | Delivered field contracts/ownership, current status, new entry points and honest evidence. No rewriting historical results. |
| CREATE `docs/plans/completed/R4.md` | Only at accepted closeout; preserve approved plan, amendments, evidence and deferred findings. |

Forbidden: all existing test/capture/helper files, counts/assertions/gates; all other R0–R3 domain code, renderer, scenes/resources/project settings; `tools/verify/**`, TEST_MATRIX, Blueprint/Master/Target Architecture, AGENTS/skills/rules; legacy runtime, road/route/foliage/player/camera/audio. No existing test mutation is requested. If an unforeseen protected-test conflict appears, document the exact issue; do not weaken tests or silently widen scope.

Preview colors may use a derived texture or color arrays assembled from existing renderer outputs; the preview remains presentation only. It never computes biome/cost formulas. New code consumes public field queries; changing renderer height/normal APIs is unnecessary. Existing preview source-ownership checks must continue to pass.

## 9. Implementation milestones and stop conditions

| Milestone | Work and concrete exit evidence |
|---|---|
| M1 — Boundary and hydrology cost | Record approval; implement seed purpose, bounded query, context and new validation fixtures. Verify old R0–R3 signatures/queries unchanged, bounded-vs-full proximity parity, input mismatch rejection, extreme coordinates. Measure bounded work before dense visualization. |
| M2 — Biome | Implement scoring, character and pocket. Generate signal/weight maps and transects for the 12-seed battery. Fix coherence and geography response within R4; record parameter decisions. This is an internal iteration checkpoint, not a new approval loop. |
| M3 — Rideability | Implement the shared signal/biome path, monotone cost, water/slope barriers, classes, point/lattice parity and reason overlays. Show meadow/forest/slope/water differences without route search. |
| M4 — Diagnostic integration | Opt-in preview plus new map/Vulkan capture tools; existing preview remains identical with options off. Review 2D overview and closeups so narrow bands, pocket edges and lattice artifacts are visible. |
| M5 — Candidate and acceptance evidence | Run fresh determinism/regression/generation gates, geographic sweep, timings and scope audit on the frozen candidate; update owned docs. Invoke independent `slow-cycle-verify`, then `slow-cycle-review` in a fresh independent context, using the exact plan/diff/evidence identities. |
| M6 — Closeout | Resolve only genuine blockers inside scope; fresh verification/review for changed results. Obtain Alpha geographic acceptance, archive R4 and clear root slot. R5 requires its own task; do not start it. |

Stop dependent work for a genuine contract/ownership blocker, unexplained R0–R3 regression, missing required evidence, or material file/contract/gate expansion. Do not stop for an ordinary parameter adjustment or accepted visual debt. A Game Director approval of v1.0 is the implementation checkpoint; this task ends after writing the plan, as requested.

## 10. Validation and debug strategy

### New durable contract checks

| Group | Behaviour protected |
|---|---|
| V1 Ownership/identity | Same inputs/config reproduce signatures; context snapshots are not affected by later copies being mutated. Different hydrology/region inputs cannot be paired. No Node/renderer/route/player dependency in domain fields and no new height owner. |
| V2 Valid queries | Finite/ranged weights, cover, moisture, cost, gradient and water depth; dry normalization, water sentinel, fixed tie rules. Corners, exact closed edges, negative regions, int64 seeds/int32-extreme region coordinates. |
| V3 Determinism/parity | Fresh independent contexts, reordered query/block requests, global RNG disturbance and two engine processes give identical outputs on the same build/platform. Point/lattice parity and shared block edges include water boundaries and off-origin regions. |
| V4 Hydrology adapter | Bounded distance agrees with capped old proximity at channel vertices, segment interiors, width changes, bucket edges, body cells and far dry points; multiple radii including the cap. Actual water equals HydrologyField, including ponds/CLOSED bodies and narrow creeks. Invalid radius rejected exactly. |
| V5 Geography response | Exercise the real scoring/cost kernels with controlled valid signal values: increasing slope cannot reduce cost with other signals held fixed; increased cover/wetness cannot improve cost; deep water and excessive slope always block; dry flat open land is lower cost. Flat aspect is neutral, shaded/warm slopes alter affinities, and riparian influence decays with distance. No substitute implementations/mocks of the kernel. |
| V6 Spatial coherence | Controlled smooth-input transects through real kernels have continuous weights/cost outside explicit water/barrier/class boundaries. Actual-world subcell transects check continuous influences around drainage nodes, pocket feathers, 16/32/128 m boundaries and block seams. Numerical tolerances derive from arithmetic and signal continuity, not a maximum number of pixels allowed to change color. |
| V7 Diversity | On nonreference seeds, compare sampled weight/cover distributions and spatial maps, not just identity hashes. Require nonconstant environmental outputs and several distinct character/pocket layouts; exact shares and connected-component counts are observational. No branch keyed to a familiar seed. |
| V8 Negative paths | Null/wrong-type inputs, mismatched signatures/bounds, malformed consumed body/area/frame data, nonfinite/outside queries and invalid/overflowing lattice requests produce the declared reason, not a crash, alias or fallback. New CLI rejects malformed seeds/regions/modes/output location with explicit reasons. |

Implement the mathematical kernels as actual production helpers so controlled-signal fixtures exercise real behaviour without fake terrain implementations. Also run the complete real RegionGenerator → terrain → hydrology → context → biome → rideability chain; kernel checks alone cannot prove source wiring. Use independent geometric examples for bounded-query edge cases, plus old-query parity; old-query parity alone is not independent evidence that geometry is correct.

For negative fixtures, change one consumed invariant at a time and assert the specific reason. Mutation spot checks in disposable copies should catch at least ignored water blocking, reversed slope response and omitted proximity buckets. No production test hooks. Record the actual new-suite assertion count and completion markers at implementation; do not invent a planned PASS/count.

### Seed coverage and geographic inspection

Development maps: 184729, 42, 77777, 1, 2, 3, 7, 11, 99, 555, 2024, 10007 at (0,0). Include offset (-1,-1) and (3,-2), plus int64/int32 extremes for query precision. Use seed 3/body-heavy cases to exercise ponds, not just main-river queries.

Freeze tuning, then run a holdout sweep of 64 seeds `1000003 + 7919*k`, k=0..63, alternating (0,0), (-1,-1), (3,-2), (1,2). Sample a coarse full-region lattice and local channel/pocket transects, recording failures and absence reasons. Do not select only successful seeds or retune per seed. If tuning changes, rerun the full fixed battery and disclose that the holdout informed the revision.

Maps show blended and dominant biomes, continuous cost/classes, slope, moisture, woody cover, exact water, valley-floor context and barrier reasons. Include scales/legends, seed/region, model/schema/source identities and timing. Display raw weights separately from dominant colors to reveal whether apparent borders are only a label tie. Plot both sides of water/pocket edges. No tree spawning or production materials.

Use the new lattice batch path for whole-region maps (257² samples, then presentation upscaling). Overlay authoritative channel/body geometry and label sampling resolution: a raster can miss narrow water. Use actual point queries for 1–4 m local transects/closeups. Do not pretend an interpolated picture is query evidence or run millions of full-proximity calls for a 1024² image.

Geographic judgement belongs to map/Vulkan inspection: broad conifer/meadow areas, legible riparian association, a coherent autumn pocket, meaningful layout differences, plausible easy valley/open areas and difficult slopes/water. No hard aesthetic percentages for every seed. At least six seeds receive saved/read Vulkan views: three reference plus 3, 2024 and 10007, with top-down and oblique biome/rideability modes and representative local closeups. Human evaluation of these maps is Alpha field acceptance, not E7 riding.

### Commands, regression gates and evidence levels

Run engines only in a disposable copy of the exact candidate, outside the source repository, as in R1–R3. Record engine executable/version/hash, OS/GPU, source manifest, tracked/untracked diff identities, command, seed, duration, raw stdout/stderr, completion counts and artifacts. Import the copy before runtime gates. Use a bounded launcher; a timeout/process-tree kill is INCOMPLETE, not PASS.

Command templates (`<copy>`, `<godot>` and `<evidence>` resolved during execution):

```text
<godot> --headless --editor --path <copy> --quit
<godot> --headless --path <copy> --script res://scripts/test/test_environment_fields.gd
<godot> --headless --path <copy> --script res://scripts/test/capture_environment_map.gd -- --seeds=184729,42,77777,1,2,3,7,11,99,555,2024,10007 --out=<evidence>
<godot> --headless --path <copy> --script res://scripts/test/capture_environment_map.gd -- --sweep=64 --out=<evidence>
<godot> --path <copy> --rendering-method forward_plus --rendering-driver vulkan --script res://scripts/test/capture_environment_preview.gd -- --seed=10007 --environment=biome --out=<evidence>
python tools/verify/sc_verify.py run --suite seed_diversity,monotony,virtual_rider,capture_visual_vulkan --godot <godot> --output-root <evidence>
```

Initial outer limits: import 180 s; new suite 600 s/process, twice; each unchanged domain suite 600 s; map battery and sweep 900 s each; each new Vulkan invocation 240 s. Q1 gates retain their existing harness timeouts/coverage and settings. A timeout may be rerun with a justified recorded limit; retain the original incomplete evidence.

Run unedited `test_region_domain_skeleton.gd`, `test_macro_geography.gd`, `test_terrain_tile_contract.gd`, `test_hydrology_contract.gd` twice and compare reference signatures/counts/deterministic output, excluding only explicitly separate timing logs. Run `test_region_preview.gd` in its existing Vulkan mode. Recreate nine default preview captures and representative existing hydrology-only captures against a fresh base copy on the same engine/render settings; investigate any difference. Capture scripts' historical incomplete source lists are supplemented by the candidate manifest, not silently edited.

E0: actual parse/import, zero parse errors. E1: new and unchanged domain suites. E2: real adjacent field pipeline and preview adapter. E5: saved/read Forward+ Vulkan captures, plus headless maps explicitly labelled diagnostic rather than E5. E6: bounded observational timings/memory below. R4 main-game E3, new ride/collision E4 and E7 are N/A because these fields do not enter gameplay or physics. The retained legacy virtual-rider real-physics and visual gates still run; their evidence does not certify riding on R4 data. No global gate waiver/reclassification and no reuse of the R0-only certificate-store exception.

Required evidence must complete without unexpected engine errors/leak warnings. Read logs, not just exit codes. Existing unrelated baseline failures are reported with identity/coverage and their applicability resolved under repository policy; they are not silently turned into a PASS or an R4 terrain-polish task.

## 11. Performance and lifecycle evidence

Before claiming readiness, measure separately: base hydrology generation, context setup, pocket search, 10,000 deterministic scattered combined biome/rideability samples, a full 257² combined lattice, map construction and preview startup. Measure bounded vs full proximity on the same independent point set, including dry uplands and body-heavy regions. Run one warm-up and three measured repetitions; report median/p95 point latency and total durations, candidate counts, packed-array/index memory and process memory across ten build/query/release cycles.

No full-proximity calls belong in normal R4 point/lattice paths. No repeated plan copying or model regeneration per query. Context drainage storage is fixed at 129² scalar samples; proximity storage is bounded by the actual region's segments/body cells. Release context/field references after use; no static region cache.

Initial engineering targets on the recorded R3-class desktop: bounded proximity materially below the recorded 0.6 ms/point (target at least 3× faster on mixed points), combined point p95 below 1 ms, and full combined 257² field evaluation below 20 s excluding R3 generation and mesh commit. These are benchmark targets, not new brittle timed assertions or a claimed result. A missed target triggers profiling and a written practical R5 workload assessment. An unusable repeated-query path is a BLOCKER; a modest target miss with bounded work and usable workload is documented DEBT. First optimize duplicate sampling/allocation inside this scope; a raster cache, threads or a different surface contract needs a concrete amendment.

## 12. Findings, risks and deliberate deferrals

**BLOCKER — none established by source inspection.** No R2/R3 redesign is needed to start R4. Potential implementation blockers are input-identity mixing, invalid/missing query values, narrow-water barriers disappearing from point queries, full-proximity amplification making the field unusable, new dependency cycles, and R0–R3 regressions. The plan directly tests these. No claim of runtime readiness is made before implementation evidence.

| Classification | Finding / mitigation / revisit |
|---|---|
| DEBT, addressed locally in R4 | R3-D9 full proximity cost: bounded query/index. Preserve the existing full query for consumers that need global nearest distance. |
| DEBT, guarded in R4 | R3-D16 crafted-plan gaps: validate only consumed data in context; broad validator/catchment/outlet/reach hardening remains separate. |
| DEBT, preserved | R3-D18 naming: R4 explicitly calls the signal valley-floor context; no rename of the protected R3 API. Actual floodplain-reach ecology is deferred until a consumer requires it. |
| DEBT, accepted | 32 m body cells and approximate body proximity; 16 m derivative scale can miss sub-grid ground detail. Keep exact current water semantics, label resolution; R7/R9/R12 own finer contacts/water treatment. |
| DEBT, deferred | R1 faceted flanks, buried pass markers, basin rims, rounded hills; R3 grid-like creeks, enclosed hollows, wall-trough streams, regular meanders, water above banks and deformation clamp. R4 describes current geography; it does not repair it. |
| DEBT, by design | HydrologySurface transition ends in R7. Natural planning signals must not acquire road feedback when that happens. |
| DEBT, accepted | Same-engine/platform determinism, no cross-region ecology continuity and no thread-safety guarantee. Follow established precision boundaries; revisit saves/R10/R19. |
| DEBT, model limitation | Woody cover and wetness are suitability proxies, not placed obstacles, soil simulation or measured bicycle traction. R11/R9 will add concrete consumers. |
| ENHANCEMENT | Seasonal/climate/soil simulation, additional archetypes, exposed-rock biome, directional energy cost, fine roughness/curvature, distance rasters, analytic gradients, LOD and parallel generation. Add only when measured consumer needs justify them. |

Do not carry unrelated accepted debt as a reason to keep R4 open. Conversely, missing required verification or a genuine field-foundation defect is not relabelled DEBT to close the phase.

## 13. Completion, rollback and current record

R4 implementation is done when the approved file/contract scope is delivered, both fields are independently queryable and usable by a later planner, broad environmental variation/coherence is evidenced, exact water and declared slope barriers work, required regression/runtime/visual checks complete, performance is measured, owned documentation is current, and independent VERIFY PASS plus fresh-context REVIEW PASS bind to the exact candidate. The Game Director judges Alpha geography from diagnostic evidence. Only blockers require corrective work before closeout.

Rollback is limited to the R4-owned additions and edits from the clean recorded base; preserve later unrelated changes and published history. No data migrations, saved-world formats or runtime deployment exist in this scope. No commit, push or merge is requested in this planning step.

Planning record (2026-10-07): repository and relevant records/code/tests inspected; clean branch/HEAD confirmed; v1.0 written. Production code/tests/scenes/resources unchanged. E0–E7 NOT_RUN for this plan-only task; no independent implementation VERIFY/REVIEW claimed. Approval and execution evidence remain pending. Next action after one Game Director review: implement the approved R4 scope.


## R4 execution record — 2026-10-08

Human approval and the four clarifications in the current chat govern v1.0; no v1.1 created. Original source HEAD cab2fb705a274df60bac516bb13ce3fdbddd7858, branch r4-biome-rideability-fields, only implementation_plan.md dirty. Work is isolated in this chat's work/candidate checkout; engine runs only in work/runtime disposable copy. Source remains preserved until the audited result is transferred.

M1–M4 implemented within the whitelist. Context has guarded snapshots and pre-road natural signals; bounded proximity retains all old methods/schema. Biome uses continuous affinities, seed character, 256 m ranked pocket sites, bounded 95 m coordinate warp plus 0.20 broad radial modulation, suitability and feathering. Rideability retains approved Alpha coefficients and thresholds; barriers are explicitly natural, without forbidding future dedicated crossing solutions. Combined production helpers return both fields from one signal set and diagnostic tools use those helpers. No new subsystem/height surface, R5 planning, road, vegetation placement or player change. Numeric enums accompany public enum/name constants.

Development evidence retained under outputs/evidence: initial launcher argument/access error; adapter frame-order error; negative geometric fixture precision and out-of-domain pocket-edge errors; preview native-class name collision. All corrected in approved new code/fixtures; no existing test edited. Domain development rerun: 22093 checks, 0 failures, eight fixtures. First map and saved/read Vulkan views show a geography-shaped irregular woodland pocket, upland meadow patches, riparian association and geometry-sensitive barriers. No aesthetic percentages were imposed. Initial full lattice about 21 s and point p95 about 1.13 ms are modest engineering-target misses, subject to isolated final measurements and documented R5 workload debt.

M2 full 12-seed map battery is running. After inspecting it, freeze tuning and run the fixed 64-region holdout without seed selection. Final suites, regressions, unchanged-preview comparisons, retained gates, isolated timings, mutation checks, source/diff audit and independent verify/review are pending. R4 remains active; no completed record/phase transition claimed.


## Final M1–M5 candidate evidence — 2026-10-08

R4 Alpha candidate is implemented within approved ExecPlan v1.0. No architecture amendment or v1.1, no R5. Code manifest SHA-256 `eaaed3d19eb3440d9d0bc194ff96a9c69c9b0e08107132e343b0ce6a7bdfd88b`; code diff SHA-256 `5fa14d9ad0b4f45ad7d4e408f1ec8530d8202284fab4ccd3e7298c3c9633d3fd`. The full owned-document/source/diff identity is in the external evidence `provenance.json`, avoiding a self-referential plan digest. Base remains cab2fb705a274df60bac516bb13ce3fdbddd7858, branch r4-biome-rideability-fields. Exact scope: 19 paths, including six new scripts and their six permitted UIDs. All existing tests and protected neighbors preserve HEAD blobs.

| Evidence | Actual result |
|---|---|
| E0 disposable import | Complete, no unexpected parse/runtime diagnostics |
| Final R4 E1/E2 suite | 29791 checks / 0 failures ×2; eight real fixtures; identical stdout SHA-256 e0157d9db43bd4f44309b169b8b19662e179ad0a524d1bbd1319b7df69db20e7 |
| Unchanged R0/R1/R2/R3 suites | 145 / 4269 / 2178 / 299 checks, all 0 failures, each ×2; outputs byte-identical both between repeats and to accepted R3 rev2 logs |
| Unchanged Vulkan preview contract | 867597 checks / 0 failures |
| Base/candidate image regression | Default 9/9 and hydrology-only 10/10 PNGs byte-identical to fresh same-engine base |
| Retained Q1 gates | 20261008T021241Z-2d997869 PASS 4 / FAIL 0 / INCOMPLETE 0; seed_diversity, monotony, real-physics virtual_rider (355.9 m), capture_visual_vulkan. Selftest49/49; manifest66 suites /209 rows |
| Development geography | Exact twelve prescribed seeds, 792588 full-region 16 m lattice points, 9192 saved local point-transect samples; 12 distinct descriptors/distributions, no missing autumn pocket; completed554.75 s |
| Fixed holdout | Exact64 seeds1000003+7919*k and four alternating regions, 270400 coarse64 m points plus49656 local point-transect samples; 64 distinct descriptors/distributions, no missing pocket or invalid/range/barrier saved sample; completed440.27 s; no holdout-driven tuning |
| E5 Vulkan | Six required seeds, biome+rideability, top-down/oblique/valley/pocket =48 saved/reloaded/nonuniform views; all read directly or through labeled full-resolution composites. Independent verifier also saved/read four seed10007 views |
| Mutation sensitivity | Three disposable mutations caught: ignored deep-water threshold58 failures; reversed slope752; omitted proximity buckets1055. These use prior22116-check additive-fixture revision; production bytes and original assertions remain identical in final strengthened29791 suite. No mutant result is called a final-suite PASS |

Production formulas/parameters were frozen before the holdout. Independent verification requested stronger explicit V4 segment interiors/width transitions/bucket edges/POND+CLOSED examples and all-weight/cover V6 continuity checks. Only the approved new suite was strengthened; the new map tool was also adjusted to time hydrology generation separately from Region/Terrain setup. Final suite reruns and independent reruns pass, with unchanged environmental output digest b080c5f43c3d30817a498663d79d1ab32b39816f1af76f34dc8c592506201d91. Development maps/Vulkan retain their original exact manifests; every production source/config hash matches final. The two additive test/timing-file differences are explicitly documented rather than relabeling old snapshots as final-source runs.

Architecture as delivered: EnvironmentContext is a derived composition/sampling helper; no authoritative height/world layer. BiomeField and RideabilityField remain separate derived fields. Signals use HydrologySurface natural pre-road geometry and exact HydrologyField water, a bounded160 m geometric proximity query, smoothed scalar drainage, fixed world-north aspect and relative elevation. The registered biome seed chooses modest forest balance and a 256 m geography-ranked pocket. Its descriptor is warped95 m, broadly modulated0.20, feathered and suitability-shaped. Maps show irregular localized woodland, not an oval template. Rideability uses continuous cover/moisture/grade with explicit deep-water/excessive-slope flags. Approved4/3/2 coefficients, 2/4 classes,0.35 m water and grade1.0 barriers remain Alpha starting values. Natural blocked does not prohibit future dedicated crossings or engineering.

No architecture deviations. Implementation details: enum outputs have public name constants; combined point/block helpers reuse one signal set; public field lattice outputs remain packed while context/diagnostics use bounded transient signal dictionaries. Whole-region images are enlarged16 m query rasters,4 m local closeups and1/4 m actual transects. Authoritative channel/body geometry overlays,500 m scales, north and legends were assembled as presentation-only outputs from exported geometry; they do not assert wet-mask truth. Map construction is observed across the twelve-seed battery and independently repeated on seed 184729 with one warm-up + three measured invocations. Query/setup/proximity and preview benchmarks likewise use one warm-up + three repetitions.

**Measured E6 (Godot4.7.2 stable mono ed1daf0bf, Windows11, NVIDIA GTX1650 SUPER, Vulkan1.3.289).** Engine SHA-2562445d009a5e0474fc7064b9767100e9d2c09521890ac5625476bfb81cf03f2d4. Final query benchmarks ran with no other verification engines active. Values below are medians of three repetitions (point p95 is the median of per-run p95 values).

| Seed | Hydro only | Context | Pocket | 10000 combined points | Point median / p95 | Full257² combined lattice | Bounded/full1000 proximity |
|---|---:|---:|---:|---:|---:|---:|---:|
| 184729 | 2.315s | 259.7ms | 186.5ms | 8.444s | 0.847/1.137ms | 21.232s | 62.4/1170.7ms |
| 3 | 1.968s | 190.4ms | 153.8ms | 7.209s | 0.712/0.954ms | 17.689s | 45.1/1170.3ms |

Vulkan environmental preview startup (184729/biome), one warm-up+three isolated repetitions: 33.499s, 33.455s, 33.364s, median33.455s. Twelve-seed map lattice queries range18.02–25.32s; presentation+local point transects/closeups range is in each raw record. Bounded proximity is about18–26× faster on the measured mixed points. Candidate means43.138 (184729) and38.725 (3); drainage storage133128 packed bytes/context, additional body index 2996/5416 packed bytes,1089 fixed bucket containers. Context also retains matching R3-derived adapters; container/upstream storage is not falsely included in those packed-only figures. Ten fresh build/query/release cycles measured Godot static memory and actual process working sets: reference 137.482–137.548 MB, body-heavy 143.761–144.101 MB, plateau after early allocator settling. Static growth about5KB is the retained measurement records; no accumulating region cache or leak diagnostic. Process peak is unavailable(-1), no peak claim.

**BLOCKER: none established by completed technical evidence.** Independent VERIFY/REVIEW results are authoritative in the external reports linked below; their identities must match this frozen source before technical acceptance. Alpha geographic acceptance and M6 archival remain Game Director decisions.

**DEBT:** reference point p95~1.14 ms and lattice~21.2 s modestly miss1 ms/20 s targets. Practical later-R5 workload: roughly1000 scattered combined queries~0.8 s,10000~8.4 s, full16 m field~21 s excluding upstream generation. Coarse64 m coverage is about3–5 s on observed regions. This is usable offline Alpha planning data, not a per-frame dense-query budget; a future planner should bound/refine queries and reuse returned data locally. No R5 planner/cache/threading was introduced. Bodies retain32 m geometry/proximity approximation, gradient retains32 m-wide stencil, narrow water needs exact point sampling/geometry overlays. Inherited R1 faceting and R3 grid-like channels/closed hollows/water rendering, limited ecology proxies, no cross-region continuity and same-platform-only determinism remain accepted debt. Some pockets meet region edges or are split by local water/suitability; their localized irregular field is evidenced, not hidden by a template. E3/E4/E7 R4 gameplay/ride are N/A because no gameplay integration; legacy rider gate does not certify R4 riding. C10/C12 and whole-game runtime acceptance remain open/incomplete.

**ENHANCEMENT:** seasonal/soil detail, exact placed vegetation resistance, directional route effort, finer surface/contact data, distance rasters, analytic gradients/LOD/parallelism if measured consumers justify them. None started.

Evidence root: `C:/Users/Luisa/Documents/Codex/2026-10-08/r4-execplan-v1-0-is-approved/outputs/evidence`. Candidate report/gallery/patch and geometry/biome/moisture/rideability figures live in that chat's outputs directory. Independent reports: `outputs/evidence/verify/REPORT.md` and `outputs/evidence/review/REPORT.md`. Full source/diff identity: `outputs/evidence/provenance.json`; commands/durations/raw stdout/stderr/completion in runs and gates, plus final performance_summary.json/audit.json. No canonical engine run; editor import reserializes default_bus_layout.tres and creates UID/import metadata only in disposable copies. Those generated copy changes are distinguished from protected canonical source and Q1 recorded its actual dirty state. No new R4 production references outside isolated region namespace/preview, no player/camera/physics/test-gate mutation.

Test integrity: real production kernels/pipeline, no mocks or fixture-specific production behavior; only expressly approved new suite/tools created and refined, existing tests byte-preserved; no skips/suppression/type bypass/weakened assertions; PASS claims confined to completed declared checks and exact evidence. Initial development failures, forced termination and expected negative/mutant diagnostics remain retained, not silently called PASS. All final positive acceptance invocations completed without unexpected errors/leaks.

Recommendation subject to the matching independent reports: ACCEPT R4 ALPHA → MOVE TO R5. This is a recommendation only; R5 has not started. Root slot remains active for Game Director Alpha acceptance/M6; no completed R4 archive or automatic phase transition.



Focused independent map-construction benchmark completed: one warm-up plus measured A/B/C, each with the same 66049-point 16 m region, both 401-point pocket/river transects and 16 PNGs. Presentation plus real local closeup/transect work: 23.127351 / 23.197384 / 23.542760 s; median 23.197384 s, excluding the separately measured full-lattice query (median 21.416887 s). Total invocation median 48.902592 s. Every PNG is byte-identical across warm-up and all three runs, with no stderr/timeout. Raw evidence and summary: outputs/evidence/verify/map_construction_* and map_construction_performance.json. This closes the initially documented repetition-method gap without changing code or parameters.

