TASK: R1 РІР‚вЂќ Macro Geography
STATUS: IMPLEMENTING
VERSION: v1.2 + approved A1 + approved A2 revision 2
DATE: 2026-10-04
BRANCH: r1-macro-geography
BASE/HEAD: d94a80ccfe3939761d97369c994b9e5af8be555f (= origin/master, re-verified with git ls-remote 2026-10-04)
BASELINE AT PLAN START: staged none; unstaged none; untracked none
APPROVAL: human 2026-10-04; v1.2 SHA-256 a689b10ae96be0a9c7974701cb351b83add3195536b47e403c43c5b3bd5cd734; H1РІР‚вЂњH8, Р’§19a, Р’§19b F1РІР‚вЂњF4 and approval notes 1РІР‚вЂњ10.
SCOPE NOTE: R1 v1.2 + approved A1 implementation resumed. Original plan/defect evidence preserved; every further contract conflict requires STOP. No R2.

---

# R1 РІР‚вЂќ Macro Geography РІР‚вЂќ ExecPlan v1.1

## 0. Version history and prior-slot context

- **v1.0** (SHA-256 `3d93b9c43d98436d91b334dc37febcb1983a6633e79dcccce4d747fa2f5e5268`): NOT APPROVED. Human accepted the architectural direction and returned decisions H1РІР‚вЂњH8 with amendments.
- **v1.1** (SHA-256 `7d04e81a57dec48792eb0ae0f21e5e9fff55e72da2c4bcf0a69dd622fecc7832`): NOT APPROVED (contains the numeric conflicts listed in Р’§19b). Header normalized to one active-plan header; H1РІР‚вЂњH8 rulings incorporated verbatim in substance (Р’§19); E2/E3 reclassified N/A and replaced by the task-specific `PREVIEW_RUNTIME` gate; noise uses the 63-bit `macro_noise` seed directly in integer hash math; golden-freeze sequencing made explicit; every additional numeric design/test value enumerated for approval in Р’§19a.
- **v1.2** (this version): minimal numeric-contract amendment only РІР‚вЂќ the four human-requested changes (D8+D13, D17+T2, D12+T4, D15a+D15b), the explicit closed sampling boundary, the T9/T10 labels, and the coupled corrections that the feasibility arithmetic for those changes forced (Р’§19b, items F1РІР‚вЂњF4). Everything else is unchanged from v1.1.
- Note on the header: v1.0 already started with a single `TASK: R1` header (the former `TASK: NONE / NO_ACTIVE_PLAN` text had been fully replaced). v1.1 adopts the exact requested header layout. Prior-slot context preserved here: R0 РІР‚вЂќ Region Domain Skeleton is COMPLETE ([completed record](docs/plans/completed/R0.md)); FINAL VERIFY PASS (E1 under R0-only A3), independent Review PASS, human G3; R0 committed as `d94a80c`, merged and remote master verified; C10/C12 OPEN; whole-game runtime acceptance INCOMPLETE; certificate-store diagnostic not globally waived.

Source of requirements: the human R1 request of 2026-10-04 ("request Р’§N"), the human v1.0 review of 2026-10-04 (H1РІР‚вЂњH8), [Blueprint](docs/TARGET_GAME_BLUEPRINT.md) Mountain River Valley sections, [Master](docs/MASTER_IMPLEMENTATION_PLAN.md) PHASE R1, [target architecture](docs/TARGET_ARCHITECTURE.md) (RegionGenerator owns RegionPlan/MacroTerrainPlan for R0РІР‚вЂњR1), [migration matrix](docs/LEGACY_MIGRATION_MATRIX.md) (MountainMassifField = DEFER, reference only), [test strategy](docs/TEST_STRATEGY.md), and [R0 Р’§8 handoff](docs/plans/completed/R0.md). Read scopes: root, `scripts/world`, `scripts/test`, `scripts/player` (player untouched), frozen test-integrity rule, `slow-cycle-worldgen` skill.

## 1. Goal

Turn the R0 region identity into a real, deterministic, pure-domain macro geography for archetype `MOUNTAIN_RIVER_VALLEY` РІР‚вЂќ one major valley crossing the region, 2РІР‚вЂњ3 mountain masses, 2РІР‚вЂњ4 ridges, РІ‰Тђ1 intentional saddle, 1РІР‚вЂњ2 benches, РІ‰Тђ1 basin, coherent slopes and bounded noise РІР‚вЂќ following **STRUCTURE + NOISE**, never NOISE = WORLD. Add the isolated `region_preview.tscn` (8Р“—8 uniform `ArrayMesh` tiles) required by Master R1 so the geography can be inspected with real Vulkan captures. No main-game integration.

## 2. Observed current state

| Item | Fact (read at HEAD `d94a80c`) |
|---|---|
| Region namespace | `scripts/world/region/`: 6 RefCounted scripts + 6 `.gd.uid`. No production consumer; only `scripts/test/test_region_domain_skeleton.gd` references it (grep of `*.gd/*.tscn/project.godot`). |
| `RegionSeedDerivation` | `slow_cycle.seed/1`; one public purpose `region_seed`; private `_preimage(purpose, PackedInt64Array)` and `_seed_from_preimage` (SHA-256, `digest[0]&0x7F` + 7 bytes РІвЂ вЂ™ `[0, 2^63-1]`). NB4: private framing has no runtime grammar/count guard. |
| `MacroTerrainPlan` | Stub; `get_state()` РІвЂ вЂ™ `"DEFERRED_R1"`. |
| `RegionPlan` | Constructor `_init(world_seed, coordinate)` builds its own identity/bounds/macro; schema `slow_cycle.region_plan/1`, 10-line canonical text; `validate()` codes `ERR_REGION_PART_MISSING`, `ERR_REGION_SEED_MISMATCH`, `ERR_REGION_BOUNDS_MISMATCH`, `ERR_MACRO_TERRAIN_STATE`. Private fields `_identity`, `_bounds`, `_macro_terrain` are tampered by R0 T10. |
| `RegionGenerator` | `static build(world_seed, coordinate) -> RegionPlan` = `Plan.new(...)`; total. |
| R0 test | 145 checks, T1РІР‚вЂњT11 = 30/1/6/6/23/5/50/8/12/3/1; self-asserts `checks == 145`. T3 holds 5 `/1` signature goldens + `P2_TEXT`; T9 asserts `"DEFERRED_R1"`; T10 expects *exact* single-code lists; T8 expects `{"is_valid": true, "reason_codes": []}` at int64 seed and int32 coordinate extremes; T5 needs 75 distinct grid signatures; T6 builds ~150 plans and checks global RNG. |
| Preview | `scenes/world/` has only tree scenes; no `region_preview`. |
| Legacy gates | Harness suite IDs `seed_diversity`, `monotony`, `virtual_rider`, `capture_visual_vulkan` (`tools/verify/suites.json`). Q2A frozen baseline: product aggregate FAIL (39 FAIL of 166 attempts), route failure (9/4), junction/envelope failure, intermittent ObjectDB; runtime acceptance INCOMPLETE; C10/C12 OPEN. |
| Engine | Q2A/Q2B/R0: `Godot_v4.7.2-stable_mono_win64_console.exe`, `4.7.2.stable.mono.official.ed1daf0bf`, SHA256 `2445d009a5e0474fc7064b9767100e9d2c09521890ac5625476bfb81cf03f2d4`. Main scene `res://scenes/mode_select.tscn`. |
| Environment | R0 runs emitted `ERROR: Failed to read the root certificate store.`; R0 A3 was R0-only (R1 handling: H1). R0 VERIFY #1 failed because an in-repo `--import` mutated 3 protected files and created 121 paths (R1 handling: H5). |
| Unknowns | Real GDScript evaluator cost per sample; whether headless dummy storage round-trips `ArrayMesh` arrays (avoided: preview checks run with the real renderer); visual quality РІР‚вЂќ only provable by E5 + human review. |

## 3. Target behaviour

```text
world_seed + region_coordinate
  -> RegionIdentity -> RegionBounds                     (R0, unchanged)
  -> MacroGeographyGenerator.generate(identity, bounds) (NEW, pure domain)
  -> MacroTerrainPlan  (data, schema slow_cycle.macro_terrain/1, state GENERATED_R1)
  -> RegionPlan(identity, bounds, macro_plan)           (schema slow_cycle.region_plan/2)
        РІвЂќвЂќРІвЂќР‚РІвЂќР‚ MacroTerrainEvaluator (NEW, stateless math over a plan)
                  -> region_preview (NEW, isolated presentation adapter)
```

Exclusions (request Р’§25): no `TerrainField`, `sample_height/gradient/normal`, `get_height`, TerrainTileRenderer contract, HydrologyPlan/river/water/creeks, BiomeField, RideabilityField, routes/roads/RoadLogic/RoadGraph/TerrainCarver/FinalSurface, ChunkStreamer/WorldStreamer/ChunkFoliage, MountainMassifField, WorldManager/main.tscn wiring, player/camera/controls/audio/HUD, collision/physics, vegetation, LOD, streaming, threading, caching framework, neighbour API, cross-region continuity, speculative Result/error framework. No legacy owner retired. No gameplay mechanic.

## 4. KEEP / ADAPT / REPLACE / RETIRE

| Owner | Decision |
|---|---|
| RegionIdentity, RegionBounds | KEEP byte-unchanged. |
| RegionSeedDerivation | EXTEND: two registered child purposes (Р’§6.1). `region_seed` contract unchanged. |
| MacroTerrainPlan | REPLACE stub with generated immutable-style data (Р’§6.2). Remains RefCounted, keeps `get_state()`. |
| RegionPlan | ADAPT: receives parts by injection; schema `/2`; validation delegates to macro plan. Keeps private field names (R0 T10). |
| RegionGenerator | ADAPT: becomes the sole composition route (Р’§6.4). |
| MountainMassifField | DEFER (unchanged; reference reading only; production dependency count from R1 = 0). |
| Legacy road/world runtime | KEEP untouched; nothing retired. |

## 5. System ownership

| State / lifecycle | Single owner |
|---|---|
| Child seed derivation | `RegionSeedDerivation` (static, stateless) |
| Macro structural + noise descriptors (generation) | `MacroGeographyGenerator` (static, stateless; one local RNG instance) |
| Macro descriptor data, canonical text, signature, descriptor validation | `MacroTerrainPlan` (immutable after construction; deep-copies inputs, returns deep copies) |
| Region aggregate, `/2` canonical text, composite validation | `RegionPlan` (does **not** generate) |
| Composition / producer-boundary validation | `RegionGenerator` |
| Elevation math (structure-only, structure+noise) | `MacroTerrainEvaluator` (static, stateless; reads a plan; never generates or caches into it) |
| Preview nodes, meshes, camera, light, material, metrics | `region_preview.gd` (presentation only; never generates geography; never patches seams) |

## 6. Public contracts

### 6.1 Seed contracts (resolves R0-NB4 by explicit registration, not a generic API)

New constants `PURPOSE_MACRO_STRUCTURE := "macro_structure"`, `PURPOSE_MACRO_NOISE := "macro_noise"`. New static functions (no generic arbitrary-purpose public function, no `macro_noise_seed32`):

```text
macro_structure_seed_preimage(region_seed: int) -> String
macro_structure_seed(region_seed: int) -> int
macro_noise_seed_preimage(region_seed: int) -> String
macro_noise_seed(region_seed: int) -> int
```

Framing per R0 handoff (root region seed as `v0`), existing private `_preimage`/`_seed_from_preimage`:

```text
slow_cycle.seed/1
purpose=macro_structure        (or macro_noise)
count=1
v0=<signed decimal region_seed>
```

Proposed independent goldens (computed with Python `hashlib`, outside Godot; region seeds match R0 T1 goldens where both exist):

| world_seed, coordinate | region_seed | macro_structure (digest[0]) | macro_noise (digest[0]) |
|---|---|---|---|
| 184729, (0,0) | 1944063217383134986 | 8254910480733202536 (0xf2) | 6288223437005019402 (0x57) |
| 42, (0,0) | 8498422420403868873 | 7155498265729271401 (0xe3) | 7290266214267829223 (0xe5) |
| 77777, (0,0) | 749671650299037083 | 2877886576196208939 (0x27) | 3566983675252739633 (0x31) |
| 184729, (-1,-1) | 5466766008934095593 | 1891129689569849483 (0x9a) | 7842700507623563724 (0xec) |
| 0, (0,0) | 1495971027060834261 | 2946979697831959287 (0x28) | 6944007839919045961 (0x60) |
| I64MIN, (I32MAX, I32MIN) | 6780184215550171328 | 4247225128377747827 (0xba) | 5428703941766576889 (0xcb) |
| I64MAX, (I32MIN, I32MAX) | 3908217619317152525 | 8726502944955122418 (0xf9) | 6416079127949548725 (0x59) |

`macro_structure` seeds the generator's single local `RandomNumberGenerator`. `macro_noise` is **not** fed to any RNG: the full 63-bit value is consumed directly by the evaluator's integer lattice hash (Р’§6.6, H4). No narrowing, no cast.

### 6.2 `MacroTerrainPlan` v1 (`slow_cycle.macro_terrain/1`)

- `STATE_GENERATED_R1 := "GENERATED_R1"`; `get_state()` retained. `ARCHETYPE_MOUNTAIN_RIVER_VALLEY := "MOUNTAIN_RIVER_VALLEY"`.
- Constructed from one value Dictionary by the generator; the constructor deep-copies it. Getters return deep copies (`duplicate(true)`) or scalars; no caller-owned collection is retained or exposed.
- All stored values are integers: positions in region-local metres `[0, 4096]` (`local_x_m`, `local_z_m`; world = int64 `RegionBounds` min + local), elevations/heights/depths/amplitude in **centimetres**, widths/radii/lengths in metres, orientations in integer degrees `[0,180)`, strengths/weights in per-mille, counts and seeds as integers. Floats exist only inside the evaluator.
- Fields (fixed order in canonical text; collections in deterministic generation order):

```text
archetype, structure_seed, noise_seed, domain_size_m (=4096)
base: floor_elevation_cm (valley exit), floor_drop_cm (entryРІв‚¬вЂ™exit), shoulder_rise_cm (both sides), piedmont_rise_cm (mountain side)
valley: 4 axis points (p0 on one boundary edge, p3 on the opposite edge, p1/p2 interior),
        floor_half_width_m, shoulder_width_m, mountain_side (РІв‚¬вЂ™1/+1)
masses[2..3]: cx, cz, radius_major_m, radius_minor_m, orientation_deg, peak_cm
ridges[2..4]: ax, az, bx, bz, half_width_m, crest_cm
saddles[>=1]: high_a(x,z), high_b(x,z), col_crest_cm, col_half_width_m, saddle(x,z), depth_cm, radius_m
benches[1..2]: ax, az, bx, bz (centreline), half_width_m, flatten_permille
basins[>=1]: cx, cz, radius_m, depth_cm, rim_sample_count
noise: algorithm "slow_cycle.lattice_value_noise/1", amplitude_cm, octave_count,
       wavelengths_m[], weights_permille[], attenuation_permille: valley_floor, bench_core, basin_core
derived (stored, integer): relief_cm = max designed summit РІв‚¬вЂ™ valley floor minimum
```

- Canonical text: LF-terminated `key=value` lines, header `slow_cycle.macro_terrain/1`, then `state=GENERATED_R1`, `archetype=РІР‚В¦`, scalar lines, `<collection>.count=N`, then `<collection>.<i>=<comma-separated ints>`. No floats, no Dictionary stringification. `signature()` = SHA-256 hex of canonical text.
- `validate() -> {"is_valid": bool, "reason_codes": Array[String]}`; diagnostic only, never mutates/clamps/repairs. Fixed check order, each code at most once:

| Code | Condition |
|---|---|
| `ERR_MACRO_SCHEMA` | state РІ‰В  GENERATED_R1 or `domain_size_m` РІ‰В  4096 |
| `ERR_MACRO_ARCHETYPE` | archetype РІ‰В  MOUNTAIN_RIVER_VALLEY |
| `ERR_MACRO_VALLEY` | valley missing / РІ‰В  4 points / p0,p3 not on opposite edges / p0,p3 tangential or p1,p2 lateral coordinate outside the interior band (Р’§19a D1) / mountain_side РІв‚¬‰ {РІв‚¬вЂ™1,+1} |
| `ERR_MACRO_MOUNTAIN_COUNT` | masses РІв‚¬‰ [2,3] |
| `ERR_MACRO_RIDGE_COUNT` | ridges РІв‚¬‰ [2,4] |
| `ERR_MACRO_SADDLE_COUNT` | saddles < 1 |
| `ERR_MACRO_BENCH_COUNT` | benches РІв‚¬‰ [1,2] |
| `ERR_MACRO_BASIN_COUNT` | basins < 1 |
| `ERR_MACRO_FEATURE_BOUNDS` | any anchor outside `[0, 4096]Р’Р†`; interior features outside the general anchor box (Р’§19a D17); any feature-specific probe-containment box (Р’§6.5a) outside `[0, 4096]Р’Р†` |
| `ERR_MACRO_FEATURE_SHAPE` | non-positive dimension, or a value outside the approved Р’§19a design ranges, ridge length < ridge ratio (D11), saddle clearance rule violated (D12) |
| `ERR_MACRO_NOISE_BUDGET` | `100 Р“— amplitude_cm > 6 Р“— relief_cm` (integer arithmetic, approved 6 % cap); amplitude outside the D15a interval; relief_cm РІ‰В¤ 0; noise-margin rule D15b violated; weights РІ‰В  1000 РІР‚° |

Validation is descriptor-level only; it never calls the evaluator (no planРІвЂ вЂ™evaluator dependency). Where one tamper legitimately implies a second breach (e.g. zero masses РІвЂЎвЂ™ relief 0 РІвЂЎвЂ™ noise budget), the test declares the exact multi-code list. In-range descriptor tampering is detectable by signature anchors, not by `validate()` (explicit limitation, like R0-NB2).

### 6.3 `RegionPlan` (`slow_cycle.region_plan/2`)

- `_init(identity, bounds, macro_terrain)`; stores the producer's instances. Getters unchanged.
- Canonical text = the R0 lines with tag `/2`, line `macro_terrain.state=GENERATED_R1`, plus `macro_terrain.signature=<64 hex>` (11 lines, each LF-terminated). No sampled heights.
- `validate()`: R0 checks unchanged in order and semantics; then `ERR_MACRO_TERRAIN_STATE` if state РІ‰В  GENERATED_R1; then new `ERR_MACRO_SEED_MISMATCH` if macro `structure_seed`/`noise_seed` РІ‰В  derivations of the **recomputed** `region_seed(world_seed, coordinate)` (so R0 T10's identity-seed tamper still yields exactly `["ERR_REGION_SEED_MISMATCH"]`); then the macro plan's own reason codes appended. A null macro part yields only `ERR_REGION_PART_MISSING` (R0 T10 unchanged).

### 6.4 `RegionGenerator.build(world_seed, coordinate) -> RegionPlan` (H3)

Builds identity, bounds, `MacroGeographyGenerator.generate(identity, bounds)`, then `RegionPlan.new(...)`, then validates the composite at the producer boundary. Only if the internally generated plan fails producer-boundary validation: `push_error("REGION_GENERATION_FAIL " + <exact reason codes>)` and return `null`. For the entire valid declared input domain (any int64 `world_seed`, any int32 `Vector2i` coordinate) generation must remain total and return a valid RegionPlan; the generator ranges guarantee this by construction. No fallback, no repair, no alternate archetype, no Result/error framework.

### 6.5 `MacroGeographyGenerator.generate(identity, bounds) -> MacroTerrainPlan`

Static, stateless. One local `RandomNumberGenerator` seeded with `macro_structure_seed`; **integer draws only** (`randi_range`), so descriptors are integer-exact. No global RNG, time, allocation IDs, scene tree or call-order input. The `noise_seed` field is stored verbatim from `macro_noise_seed`. Generation happens in a canonical valley frame (u = along-axis 0РІвЂ вЂ™4096, v = across) with integer arithmetic, then is mapped by one of 8 exact integer symmetries (4 rotations Р“— mirror) to local (x, z); orientations map exactly in integer degrees. All numeric ranges are enumerated in Р’§19a (D1РІР‚вЂњD19) and need approval. If implementation shows a range cannot satisfy the approved morphology contract, the change is proposed as an amendment РІР‚вЂќ tests/thresholds are not relaxed and ranges are not silently changed.

### 6.5a Construction order and feasibility (v1.2)

Every parameter is drawn from an interval computed from the parameters already drawn ("feasible interval"), never drawn freely and clamped afterwards. Each interval below is non-empty for every combination of the approved ranges (worst cases checked arithmetically; minimum slack in Р’§19b). Canonical frame: valley along u, mountain side = +v (the 8 symmetries map it). Effective ellipse radius of a mass in direction Рџв‚¬: `r(Рџв‚¬) = aР’·b / sqrt((bР’·cos РћС‘)Р’Р† + (aР’·sin РћС‘)Р’Р†)`, РћС‘ = Рџв‚¬ РІв‚¬вЂ™ orientation; `r_lat` = support half-extent along v, `r_dir` along a given direction; computed in float64 and ceiled to whole metres (+1 m).

1. Valley widths: floor half-width `fh` (D6), shoulder `sh` (D7); bench half-width `bhw` (D13) РІвЂЎвЂ™ `bench_required_gap = 4Р’·bhw + 50`.
2. Valley lateral interval `[L, U]` for all four axis points: `L = fh + sh + 2Р’·220 + 250 + 30` (room for a minimum-radius far-side basin with T1-probe clearance and rim containment), `U = 4096 РІв‚¬вЂ™ (fh + sh + gap + 451 + 527)` (room for a minimum-r_lat mass plus its probe ring). Worst case `U РІв‚¬вЂ™ L = 88` (РІ‰Тђ 0). p0, p3 drawn in `[L, U]`; p1/p2 in `[max(L, chord РІв‚¬вЂ™ 400), min(U, chord + 400)]`. In local coordinates this always lies inside D1 `[1024, 3072]`.
3. Zoning lines (constant v, referenced to `v_max` = largest axis-point v): shoulder end `P0 = v_max + fh + sh`; piedmont/bench zone `[P0, P1]`, `P1 = P0 + gap`; mass clearance line `P1`.
4. Masses: each centre satisfies `v_c РІ‰Тђ P1 + r_lat` (D8 as amended) and lies so that its whole T2 probe ring (1.10Р’·r(Рџв‚¬) + 30) is inside `[0, 4096]Р’Р†`. Draw order per mass: minor `b`, orientation (feasible set of integer degrees), major `a`, then position РІР‚вЂќ each from its feasible interval. The minimum configuration (`r_lat = b = 450`) is feasible by construction of `U`.
5. Saddle pair A, B (the two highest masses): along-col radii `r_dir РІ‰В¤ 900`; centre separation `d_AB РІ‰Тђ r_A,dir + r_B,dir + 100`, so the saddle point S (midpoint of the support gap) is РІ‰Тђ 50 m outside both supports; worst-case packing with probe rings needs 3940 РІ‰В¤ 4096. A third mass (count 3 only when a feasible placement exists in the drawn order) may overlap A or B but its support must exclude S (+50 m). Consequence: with mass count 2 the two masses are joined by the col, not by overlapping supports.
6. Ridges (D11): in the mass zone; segments end РІ‰Тђ `P1 + half-width`; S РІ‰Тђ half-width + 50 m from every ridge segment; ridges combine by `max` (no stacking); count drawn from the feasible set (РІ‰Тђ 2 always feasible: one per saddle-pair mass toward the valley, length РІ‰Тђ r_lat РІ‰Тђ 450, half-width drawn in `[110, min(220, length/2.5)]`).
7. Saddle (D12 as amended): depth `D РІв‚¬в‚¬ [70, 120]`, then net col height `s = col_crest РІв‚¬вЂ™ D РІв‚¬в‚¬ [max(20, 180 РІв‚¬вЂ™ D), min(P_min РІв‚¬вЂ™ 70 РІв‚¬вЂ™ drop, P_min РІв‚¬вЂ™ 20 РІв‚¬вЂ™ D)]` (P_min = lower peak of A/B; non-empty for all approved ranges). Col crest profile is 0 at A and B. Because S is outside every mass/ridge/bench/basin/valley influence and the mountain-side base there is РІ‰Тђ F + shoulder_rise + piedmont_rise РІв‚¬вЂ™ drop РІ‰Тђ F + 80, this guarantees by construction `structure(S) РІ‰Тђ F + 100` (F = nearest valley-floor elevation) and `structure(S) РІ‰В¤ min(structure(A), structure(B)) РІв‚¬вЂ™ 70`.
8. Bench (D13 as amended): centreline at `v = P0 + 25 + 2Р’·bhw`; flatten band `[P0 + 25 + bhw, P0 + 25 + 3Р’·bhw]` with full-strength plateau `|РћвЂќv| РІ‰В¤ bhw/2`; T5 windows `[P0 + 25, P0 + 25 + bhw]` and `[P0 + 25 + 3Р’·bhw, P0 + 25 + 4Р’·bhw]`. The piedmont rise (D5b) is linear over `[P0, P1]` with 25 m C1 end blends, so both windows and the core lie on its constant-gradient part and nothing else (valley, masses, ridges, basin, saddle) reaches the zone.
9. Basin (D14 as amended): far side; radius from `[220, min(380, РІРЉР‰(v_min РІв‚¬вЂ™ fh РІв‚¬вЂ™ sh РІв‚¬вЂ™ 280)/2РІРЉвЂ№)]` (non-empty by `L`); centre v in `[r + 30, v_min РІв‚¬вЂ™ fh РІв‚¬вЂ™ sh РІв‚¬вЂ™ r РІв‚¬вЂ™ 250]`; depth `[70, 100]`.
10. Relief (stored, conservative): `relief = (floor at the dominant mass РІв‚¬вЂ™ floor_min) + shoulder_rise + piedmont_rise + max peak` (РІ‰В¤ 780 m). Noise amplitude (D15a as amended) drawn last from `[0.035Р’·relief, min(0.055Р’·relief, (m РІв‚¬вЂ™ 10)/2)]`, `m = min(saddle depth, basin depth, ridge crests, 70 m saddle-below-highs construction margin) РІ‰Тђ 70` РІвЂЎвЂ™ upper РІ‰Тђ 30 m РІ‰Тђ 0.035Р’·780 = 27.3 m: non-empty by construction. An empty interval would be a generation contract defect (explicit `REGION_GENERATION_FAIL`), never a silent reduction below 3.5 %.

Construction proves descriptor validity (hence H3 totality) and the T1, T4, T5 (structure) and T6 structural margins. T2, T3, T7 and T10 depend on overlap/orientation interactions and are verified by the fixture tests, not claimed as construction-proven; a failure there is a generation defect for amendment, not a reason to change thresholds.

### 6.6 `MacroTerrainEvaluator` (transitional macro-domain contract; R2 owns the final `TerrainField`)

```text
static evaluate_structure_elevation_m(plan, local_x_m: float, local_z_m: float) -> Dictionary
static evaluate_elevation_m(plan, local_x_m: float, local_z_m: float) -> Dictionary
  -> {"is_valid": bool, "elevation_m": float, "reason_code": String}   ("" when valid)
```

Boundary contract: **region ownership `[0, 4096)`** (R0 `RegionBounds`, half-open, unchanged); **R1 evaluator sampling support `[0, 4096]` inclusive** on both axes (the shared geometric boundary at 4096 is evaluable for preview edge vertices; no neighbour API, no continuity claim); **out of domain: x or z < 0 or > 4096**. Invalid input is an explicit result, never terrain: `ERR_EVAL_PLAN_MISSING` (null plan or state РІ‰В  GENERATED_R1), `ERR_EVAL_NONFINITE_INPUT` (NaN/Р’±INF in either coordinate), `ERR_EVAL_OUT_OF_DOMAIN`; `elevation_m = NAN` with `is_valid=false`. Precondition: a plan that passed producer validation (no per-call re-validation). Composition order (request Р’§8), each stage C0-continuous (smoothstep/quintic/compact `(1РІв‚¬вЂ™rР’Р†)Р’С–` kernels; no hard cuts):

1. base surface (floor elevation interpolated along the valley axis + shoulder rise on both sides, completed at the shoulder end + mountain-side piedmont ramp over `[P0, P1]`, Р’§6.5a);
2. + mountain masses (anisotropic compact kernels) + ridges (segment-distance profile Р“— end taper; ridges combined by `max`);
3. major-valley shaping: lerp toward along-axis floor elevation by `1 РІв‚¬вЂ™ smoothstep((d РІв‚¬вЂ™ floor_hw)/shoulder_w)`, `d` = distance to the axis polyline;
4. saddle shaping: col ridge between high_a/high_b minus a smooth depression at the saddle point;
5. bench shaping: within a smooth band mask (full-strength plateau `|РћвЂќv| РІ‰В¤ bhw/2`, falling to 0 at `|РћвЂќv| = bhw`), pull elevation toward the stages-1РІР‚вЂњ4 elevation at the nearest centreline point by `flattenРІР‚°` (nested evaluation inside the band only; continuous at the band edge);
6. basin shaping: inside the radius, blend toward `basin_floor + bowl(r)` where `basin_floor = min(stages-1РІР‚вЂњ5 elevation at the rim sample points) РІв‚¬вЂ™ depth` (a plan-derived constant РІвЂЎвЂ™ continuous);
7. noise (final only): `amplitude Р“— attenuation_mask Р“— РћР€ w_oР’·v_o`, value noise in `[РІв‚¬вЂ™1,1]`, quintic interpolation, РћР€w = 1 РІвЂЎвЂ™ `|final РІв‚¬вЂ™ structure| РІ‰В¤ amplitude` by construction.

Noise hash (H4): the 63-bit `noise_seed` is consumed whole as two lanes, `lo = noise_seed & 0x7FFFFFFF` and `hi = noise_seed >> 31` (< 2^32), mixed with octave index and integer lattice coordinates through 31/32-bit-masked multiplyРІР‚вЂњxorshift steps whose products stay < 2^63 (no reliance on signed overflow, no cast, no RNG). `evaluate_structure_elevation_m` = stages 1РІР‚вЂњ6. No `MountainMassifField` import/call. Determinism claim: same engine build/platform only; no cross-platform bit-identical claim.

### 6.7 `region_preview` (presentation adapter)

- `scripts/world/region_preview.gd` (`extends Node3D`, no `class_name`), `scenes/world/region_preview.tscn` (hand-authored text scene: root Node3D + script, `Camera3D`, `DirectionalLight3D`, `WorldEnvironment` with neutral sky, no fog). Exports `world_seed = 184729`, `region_coordinate = Vector2i(0, 0)`; CLI user args `--seed=<int>` `--region=<x>,<y>` override; malformed CLI values РІвЂ вЂ™ explicit error, no default substitution.
- Build: `RegionGenerator.build` (single generation route) РІвЂ вЂ™ if null/invalid: explicit error, no mesh. Then 8Р“—8 tiles, 512 m, 32 quads/side, 16 m spacing, 33Р“—33 vertices; vertex positions relative to the tile origin; each `MeshInstance3D` at its tile origin in region-local space (not absolute world space). Every height comes from `evaluate_elevation_m` at exact integer-metre coordinates `tile*512 + i*16`, so shared edges query identical positions. Shading normals are presentation-only central differences of evaluator samples at Р’±16 m (one-sided at the region boundary), so neighbouring tiles get identical edge normals. No stitch geometry, skirts, seam correction, LOD, streaming, collision, vegetation, water, roads, player.
- Material: neutral grey + diagnostic contour lines (Р’§19a P1) in an inline `ShaderMaterial`; no biome colouring.
- Exposes read-only `get_plan_signature()`, `get_tile_count()`, `get_tile_arrays(index)` (copies of the arrays committed to that tile's `ArrayMesh`), `get_metrics()`; prints `REGION_PREVIEW_METRICS` (macro generation ms, mesh build ms, tiles, vertices, triangles, approximate committed bytes).
- Winding: Godot clockwise front faces viewed from +Y; declared and tested per triangle.

## 7. Dependency direction

`RegionSeedDerivation РІвЂ С’ MacroGeographyGenerator РІвЂ вЂ™ MacroTerrainPlan РІвЂ С’ RegionPlan РІвЂ С’ RegionGenerator`; `MacroTerrainEvaluator РІвЂ вЂ™ MacroTerrainPlan` (read-only); `region_preview РІвЂ вЂ™ RegionGenerator, MacroTerrainEvaluator`. `RegionPlan` references neither generator nor evaluator; `MacroTerrainPlan` references neither; nothing in `scripts/world/region/` references the preview, scene tree, renderer or physics. No production script/scene references the preview or region namespace.

## 8. Allowed files (exact whitelist)

| Path | Action | Responsibility |
|---|---|---|
| `scripts/world/region/region_seed_derivation.gd` | modify | two registered child purposes |
| `scripts/world/region/macro_terrain_plan.gd` | modify (replace stub) | v1 data, canonical text, signature, validate |
| `scripts/world/region/region_plan.gd` | modify | injection, `/2`, delegated validation |
| `scripts/world/region/region_generator.gd` | modify | composition + producer-boundary validation |
| `scripts/world/region/macro_geography_generator.gd` (+ `.gd.uid`) | create | descriptor generation |
| `scripts/world/region/macro_terrain_evaluator.gd` (+ `.gd.uid`) | create | elevation math |
| `scripts/world/region_preview.gd` (+ `.gd.uid`) | create | preview adapter |
| `scenes/world/region_preview.tscn` | create | isolated preview scene |
| `scripts/test/test_region_domain_skeleton.gd` | modify РІР‚вЂќ **only** H6 lines | R0 schema transition |
| `scripts/test/test_macro_geography.gd` (+ `.gd.uid`) | create | E1 domain suite |
| `scripts/test/test_region_preview.gd` (+ `.gd.uid`) | create | preview topology / `PREVIEW_RUNTIME` suite |
| `scripts/test/capture_region_preview.gd` (+ `.gd.uid`) | create | E5 capture runner |
| `implementation_plan.md` | modify | active plan/progress |
| Closeout only: `docs/CURRENT_PROJECT_STATE.md`, `ARCHITECTURE.md`, `docs/plans/completed/R1.md`, `implementation_plan.md` | modify/create | after VERIFY PASS + REVIEW PASS |

The six new `.gd.uid` sidecars are transferred once, byte-for-byte, from a disposable-copy scan (H5); afterwards they are candidate source and part of every VERIFY/review identity. Nothing else.

## 9. Forbidden files

Everything not in Р’§8, specifically: `region_identity.gd`, `region_bounds.gd` and the six existing `.gd.uid`; all other `scripts/test/*` (helpers and the four retained gates byte-unchanged); `tools/verify/**` (incl. `suites.json`); `docs/TEST_MATRIX.md`, Master, Target Architecture, Blueprint, Migration Matrix, Test Strategy; `AGENTS.md`, `scripts/*/AGENTS.md`, `.agent/PLANS.md`, `.agents/skills/**`, `.antigravity/**`; `project.godot`, `default_bus_layout.tres`, `*.import`, `icon.svg`, `scenes/` except the new preview, `scripts/player/**`, camera/controls/audio/UI, legacy `scripts/world/*` (incl. `mountain_massif_field.gd`), main/mode-select scenes, `assets/**`. Any discovered need РІвЂ вЂ™ STOP and request an amendment.

## 10. Migration path (milestones and stop points)

| Step | Work | Gate / STOP |
|---|---|---|
| R1.1 | Re-record branch/HEAD/status/staged/unstaged/untracked; hash every Р’§8 modify-target and the four gate scripts; confirm HEAD = `origin/master` = `d94a80c`. | Mismatch РІвЂ вЂ™ STOP and reconcile. |
| R1.2 | Seed contracts (Р’§6.1) + test group G1. No geography. | Goldens must equal the Р’§6.1 table. |
| R1.3 | `MacroTerrainPlan` v1 schema/validation/canonical identity. | РІР‚вЂќ |
| R1.4 | `MacroGeographyGenerator` (no renderer, no scene tree). | РІР‚вЂќ |
| R1.5 | `MacroTerrainEvaluator`; run `test_macro_geography.gd` (all groups except the G3 anchors, which do not exist yet). | Any morphology/budget/determinism failure РІвЂ вЂ™ fix at generator/evaluator owner within approved ranges; if the approved contract cannot be met РІвЂ вЂ™ STOP for amendment; never move the problem to rendering. |
| R1.6 | `RegionPlan` injection + `/2`; generator composition; H6 T9 edit. Interim R0 run: the 6 T3 checks are **expected to fail** until anchors are frozen (old `/1` literals); this interim state is recorded honestly and is not evidence. All other 139 checks must pass. | Any other R0 failure or need for another R0 change РІвЂ вЂ™ STOP. |
| R1.7 | Preview scene/script. | РІР‚вЂќ |
| R1.8 | `test_region_preview.gd`. | Seam/topology defects fixed at owner, not by renderer patches. |
| R1.9a | Three-seed Vulkan captures + author inspection; captures and context handed to human. | Weak/noise-like geography = R1 defect even if green. |
| R1.9b | **Human visual review** of the structural result. | Rejection РІвЂ вЂ™ back to R1.4/R1.5 within scope. |
| R1.9c | Freeze anchors (H7) only after morphology PASS + E5 captures complete + human acceptance: add G3 literals to the new test; replace T3 `/2` literals + `P2_TEXT` (H6); independent Python re-hash of all anchors. R0 suite now 145/145. | Any anchor change after this point requires fresh captures/review. |
| R1.10 | Retained gates + Q1 selftest/check-manifest + isolation/scope scans. | New regression attributable to R1 blocks completion. |
| R1.11 | Fresh `slow-cycle-verify` (read-only). | PASS required. |
| R1.12 | Fresh independent `slow-cycle-review` (approved plan + exact diff + verify report + identities). | PASS required. |
| R1.13 | Closeout docs; root slot РІвЂ вЂ™ NO_ACTIVE_PLAN; commit only under normal human authorization. | Do not start R2. |

## 11. Risks

| Risk | Mitigation |
|---|---|
| A РІР‚вЂќ R1 becomes R2 | No TerrainField/sample_* APIs; evaluator documented as transitional; R0 T9 negative assertions retained. |
| B РІР‚вЂќ RegionPlan god object | Generation in generator, math in evaluator; RegionPlan references neither (scan). |
| C РІР‚вЂќ noise becomes geography | Structure-only evaluator; descriptor-level budget (РІ‰В¤ 6 % relief) and noise-margin rule; classification must hold with and without noise. |
| D РІР‚вЂќ float instability at extreme coordinates | Descriptors region-local ints; preview in region-local space; RegionBounds int64 untouched. |
| E РІР‚вЂќ schema evolution invalidates R0 evidence silently | Intentional `/2`, H6 literal replacements only, 145 checks retained, honest interim-failure record. |
| F РІР‚вЂќ renderer hides domain defects | Domain tests precede preview; no skirts/stitching; edge normals from the evaluator. |
| G РІР‚вЂќ MountainMassifField leakage | Zero-reference scan over all R1 files. |
| H РІР‚вЂќ seed variation is merely noise variation | Structural-descriptor distinctness (G4) plus human visual review. |
| I РІР‚вЂќ GDScript evaluator cost | ~70 k preview samples + nested bench/basin evaluation; observational metrics only; no optimization/threading/caching without amendment. |
| J РІР‚вЂќ engine RNG / libm drift | Descriptors depend only on PCG32 integer draws; float evaluation claims same engine/platform only. |
| K РІР‚вЂќ distance-to-polyline crease at axis vertices | C0 guaranteed; bend bounded (D2); Lipschitz check (T9). |
| L РІР‚вЂќ Godot runs mutate repository files | All Godot runs in disposable copies (H5); post-run `git status` audit of the working repo. |
| M РІР‚вЂќ certificate-store diagnostic | H1 conditional exception only after exact reproduction; otherwise FAIL/INCOMPLETE. |
| N РІР‚вЂќ frozen anchors mistaken for correctness proof | H7: anchors are regression anchors only; correctness = morphology/invariants/validation/E5. |

## 12. Verification plan

All Godot executions (E0, E1, `PREVIEW_RUNTIME`, E5, and any harness gate run) happen only in disposable project copies (H5); no `--import` in the working repository. Each run records engine identity (expected the Q2A/R0 executable; any difference recorded), one process at a time, bounded time limit (Р’§19a V1), raw stdout/stderr kept outside the repo, checked for parse/script/runtime errors, ObjectDB/leak warnings, unknown engine messages, completion marker and exact coverage. Certificate diagnostic handling: H1 only.

| Level / gate | Evidence | Command shape |
|---|---|---|
| E0 REQUIRED | Every changed/new script and the scene parse/load with zero errors (all runs below plus explicit `load()` of each in the E1 suite). | РІР‚вЂќ |
| E1 REQUIRED | `test_macro_geography.gd` Р“—2 independent processes, byte-identical stdout; `test_region_domain_skeleton.gd` Р“—2 (145/145 after R1.9c). | `--headless --script res://scripts/test/<file>.gd` |
| E2 N/A | R1 does not integrate with neighbouring production systems. | РІР‚вЂќ |
| E3 N/A | `region_preview` is neither Main nor a production-equivalent runtime scene. | РІР‚вЂќ |
| `PREVIEW_RUNTIME` REQUIRED (task-specific gate, not an Evidence Ladder level, not E3) | `test_region_preview.gd` instantiates `region_preview.tscn` in a real scene tree with the real Vulkan renderer (not `--headless`), builds all 64 tiles, and runs the Р’§14 topology/adapter checks incl. `ArrayMesh` round-trip. | `--rendering-driver vulkan --script res://scripts/test/test_region_preview.gd` |
| E4 N/A | No physics/collision/player integration. | РІР‚вЂќ |
| E5 REQUIRED | `capture_region_preview.gd` for seeds 184729, 42, 77777 at `(0,0)`, real Forward+ Vulkan, fixed camera identity (Р’§19a P2), PNG saved outside the repo, reloaded and checked (size, non-uniform pixels); log seed, coordinate, RegionPlan + macro signatures, source identity, camera identity, path, PNG SHA-256. Human visual review required (R1.9b). | `--rendering-driver vulkan --script РІР‚В¦ -- --seed=РІР‚В¦ --region=0,0 --out=<outside repo>` |
| E6 N/A as acceptance level | Timings/memory recorded observationally only (Р’§15). | РІР‚вЂќ |
| E7 N/A | Not a playable ride. | РІР‚вЂќ |
| Retained gates | Harness `run --suite seed_diversity,monotony,virtual_rider,capture_visual_vulkan` against a disposable copy; `selftest`; `check-manifest`. Compare outcomes and reasons to Q2A frozen results; pre-existing failures stay FAIL; new attributable regression blocks. Not R1 coverage. | `python tools/verify/sc_verify.py РІР‚В¦`, output root outside repo |
| Isolation | No reference to `region_preview`/`scripts/world/region` from any production script/scene/`project.godot`; zero `MountainMassifField` references in R1 files; RegionPlan references neither generator nor evaluator; no scene-tree/Node/renderer API in `scripts/world/region/`. | read-only scan |
| Scope | Full name-status diff + untracked set == Р’§8; forbidden-file hashes unchanged; R0 test diff limited to H6 lines. | read-only |

## 13. `test_macro_geography.gd` groups (new; additive; exact own check count fixed at implementation, self-asserted like R0, reported)

All numeric probe/threshold values referenced here are enumerated in Р’§19a (T1РІР‚вЂњT12) and need approval.

| Group | Content |
|---|---|
| G1 Seed contract | Literal preimages + seeds + digest[0] for both purposes on all 7 Р’§6.1 rows; token grammar `^[a-z][a-z0-9_]{0,63}$` (R0 T2 grammar) for each registered constant; purposes distinct; child РІ‰В  parent seed. |
| G2 Same input | Same-input fixtures (T11) Р“—3 builds: identical macro canonical text and signature; separately owned instances. |
| G3 Regression anchors (added at R1.9c only) | Exact macro canonical text for 184729/(0,0) and macro + RegionPlan signatures for 184729, 42, 77777 at (0,0) and 184729/(РІв‚¬вЂ™1,РІв‚¬вЂ™1). Regression anchors per H7, not correctness proof; SHA-256 and canonical serialization independently re-checked with Python; never computed by asking production for its expected value inside the test. |
| G4 Different seeds | 184729/42/77777 pairwise: distinct signatures **and** materially distinct structure per T10. |
| G5 Order / global RNG / processes | Order fixture set (T11) forward, reverse, interleaved РІвЂ вЂ™ identical per-region signatures; `seed()`/`randomize()`/`randi()` before and between builds leave output byte-identical; builds consume no global RNG (R0 T6 pattern). Two fresh processes РІвЂ вЂ™ byte-identical stdout, including SHA-256 over centimetre-quantized structure/final samples of the determinism grid (T11). |
| G6 Finite domain | Finite-grid fixtures (T11): every structure/final result valid and finite. |
| G7 Morphology (structure **and** final; probes derived from descriptors) | Valley cross-sections (T1), mass high ground (T2), ridge crest (T3), saddle (T4), bench (T5: structure; final per T5), basin (T6), slopes (T7); final evaluation must preserve the T1РІР‚вЂњT4 and T6 orderings with the noisy margin (T8). All probes inside `[0, 4096]Р’Р†` by construction. Applied to the morphology fixture set (T11). |
| G8 Structure + noise / continuity | `|final РІв‚¬вЂ™ structure| РІ‰В¤ amplitude` on the finite grids; `100Р’·amp РІ‰В¤ 6Р’·relief` from descriptors; attenuation verified at valley floor/basin centre; Lipschitz continuity (T9). |
| G9 Purity / API | All new domain scripts extend RefCounted; plan and macro plan lack `sample_height/sample_gradient/sample_normal/get_height`; getter results are copies (mutating them leaves signatures unchanged). |
| G10 Negative (exact reason lists) | invalid archetype; missing valley; valley endpoint off-edge; zero masses; zero ridges; zero saddles; zero benches; zero basins; anchor outside local bounds; noise amplitude above 6 %; macro part swapped from another region РІвЂ вЂ™ `ERR_MACRO_SEED_MISMATCH`; tampered descriptor РІвЂ вЂ™ signature differs from anchor; state tamper РІвЂ вЂ™ `ERR_MACRO_SCHEMA` / `ERR_MACRO_TERRAIN_STATE`; evaluator NaN/+INF/РІв‚¬вЂ™INF on x and z РІвЂ вЂ™ `ERR_EVAL_NONFINITE_INPUT`; out-of-domain probes (T12) РІвЂ вЂ™ `ERR_EVAL_OUT_OF_DOMAIN`; null plan РІвЂ вЂ™ `ERR_EVAL_PLAN_MISSING`. Private-state tampering only inside these fixtures; crash/parse error/timeout is never a negative PASS. |
| G11 Producer boundary | Every fixture used in G2РІР‚вЂњG10 plus R0 T8 extremes builds non-null and valid; `REGION_GENERATION_FAIL` never emitted. |

## 14. `test_region_preview.gd` checks (new; additive; `PREVIEW_RUNTIME` gate)

Exactly 64 tiles; per tile 1089 vertices / 6144 indices / 2048 triangles (total 69 696 / 131 072) РІР‚вЂќ all derived from the approved topology; every vertex finite; every index in range; no degenerate triangle (XZ area exactly 128 mР’Р†, derived from 16 m spacing); consistent declared winding and vertex normals agreeing with face orientation; shared tile borders have bit-identical X/Z (region space) and identical elevation, both equal to a fresh evaluator sample; no missing tile; coverage exactly `[0, 4096]Р’Р†`; `ArrayMesh.surface_get_arrays` equals the committed arrays; plan and macro signatures identical before/after build and equal to an independent `RegionGenerator.build`; scene not referenced by production. Exact check count self-asserted.

## 14a. Negative verification (summary)

All request Р’§27 cases are in G10 with exact expected reasons. Not exercised: producer-boundary `REGION_GENERATION_FAIL` (unreachable for valid typed inputs without a test hook; test hooks are forbidden РІР‚вЂќ retained limitation, analogous to R0-NB2); invalid plan passed to the preview (no injection path; explicit-error branch reviewed by source). Exercised additionally: one malformed `--seed` preview/capture run must exit non-zero with the declared message and produce no capture.

## 15. Runtime / visual / physics requirements and performance evidence

- Runtime: isolated scene only (`PREVIEW_RUNTIME`); no main.tscn/WorldManager/ChunkStreamer/RoadLogic/player. Physics/collision: N/A.
- Visual (E5): three real Forward+ Vulkan captures; human review must confirm visibly different mountain composition, valley geometry, ridge layout and slope/open-space composition, each recognisably the same archetype; and absence of holes, tile seams, height discontinuities, inverted faces, NaN spikes and single-noise-field appearance. Headless image claims are insufficient.
- Performance (observational, no thresholds): macro generation ms, preview mesh-build ms, tile/vertex/triangle counts, approximate committed mesh bytes; per seed, same machine, reported as a future reference. No optimization, threading, worker queue, LOD or caching.

## 16. Rollback boundary

Additive/isolated except the R0 seed-derivation extension, MacroTerrainPlan replacement, RegionPlan `/2`, RegionGenerator composition and the H6 R0 literal edits. No production consumer depends on the region domain, so rollback = revert the task commit(s) on this branch. No rewrite of published R0 history or unrelated commits; other people's edits preserved.

## 17. Legacy impact

Legacy runtime untouched; retained gates are run as non-regression evidence and compared with Q2A (known route/junction failures, intermittent ObjectDB, rider partial distance remain as-is). C10/C12 stay OPEN; whole-game runtime acceptance stays INCOMPLETE. MountainMassifField remains DEFER. Next dependency: R2 (TerrainField / tile contract) РІР‚вЂќ not started.

## 18. Documentation changes (closeout only)

`docs/CURRENT_PROJECT_STATE.md` (R1 status, proven vs deferred, known failures), `ARCHITECTURE.md` (short factual as-is note: generator/plan/evaluator/preview ownership), `docs/plans/completed/R1.md` (approved plan, approvals, progress, evidence, reports, limitations), root slot РІвЂ вЂ™ `NO_ACTIVE_PLAN` linking the record. No other document.

## 19. Human rulings on v1.0 (2026-10-04), incorporated

| ID | Ruling | Incorporated as |
|---|---|---|
| H1 | APPROVED WITH CONDITION: `CERT_STORE_ENV_EXCEPTION_R1_VERIFY_ONLY`, equivalent to R0 A3, R1 only, all nine A3 conditions. Not active in advance: the exact diagnostic `ERROR: Failed to read the root certificate store.` must first actually reproduce. Any differing diagnostic/environment/condition voids it РІвЂ вЂ™ ordinary FAIL/INCOMPLETE. Not a global allowlist; not carried into R2. | Р’§12; Risk M. Nine conditions: exact stderr text; Godot SHA-256 `2445d009РІР‚В¦f2d4` and version `4.7.2.stable.mono.official.ed1daf0bf`; same environment class; raw stderr preserved; no suppression/filter/allowlist; no other unexpected engine error; no parse/script/runtime error; no ObjectDB/leak warning; A2 evidence available and unchanged. |
| H2 | AMEND: E0 REQ, E1 REQ, E2 N/A, E3 N/A, E4 N/A, E5 REQ, E6 N/A (observational timings/memory allowed), E7 N/A. `region_preview` start + correct build = mandatory task-specific `PREVIEW_RUNTIME` gate; not a new ladder level, not E3 PASS. | Р’§12, Р’§14, Р’§15. |
| H3 | APPROVED WITH CONSTRAINT: `null` + exact `REGION_GENERATION_FAIL` only for producer-boundary validation failure of the internally generated plan; total and valid for the whole declared input domain; no fallback/repair/alternate archetype/Result framework. | Р’§6.4. |
| H4 | APPROVED: pure-GDScript deterministic noise; no FastNoiseLite; no `macro_noise_seed32`; registered 63-bit `macro_noise` seed used directly in integer/lattice hash math; no global RNG/time/allocation/order dependence; no cross-platform bit-identical claim. | Р’§6.1, Р’§6.6. |
| H5 | APPROVED: all Godot execution/import/verification runs only in disposable copies; no `--import` in the repo; new `.gd.uid` sidecars transferred back once byte-for-byte and thereafter part of candidate source identity for all VERIFY/review. | Р’§8, Р’§12. |
| H6 | APPROVED: only T3 (5 `/2` signature literals + exact `P2_TEXT`) and T9 (`DEFERRED_R1` РІвЂ вЂ™ `GENERATED_R1`); T1РІР‚вЂњT11 structure and exactly 145 checks retained; nothing else changed. | Р’§8, Р’§10 R1.6/R1.9c. |
| H7 | APPROVED WITH QUALIFICATION: freeze only after (1) morphology/invariant tests PASS, (2) three-seed E5 captures complete, (3) human visual review accepts. Frozen values are regression anchors, not proof of initial correctness; correctness = morphology/invariants/validation/E5; SHA-256/canonical serialization re-checked independently. | Р’§10 R1.9aРІР‚вЂњc, Р’§13 G3. |
| H8 | PARTIALLY APPROVED: one major valley; 2РІР‚вЂњ3 masses; 2РІР‚вЂњ4 ridges; РІ‰Тђ1 saddle; 1РІР‚вЂњ2 benches; РІ‰Тђ1 basin; noise РІ‰В¤ 6 % of major macro relief; preview 8Р“—8 tiles, 512 m, 32 quads/side, 16 m spacing. All other numeric values require explicit approval РІвЂ вЂ™ Р’§19a. | Р’§19a. |

## 19a. H8 remainder РІР‚вЂќ every additional numeric value requiring approval

Values derived purely from approved values (4096 m region; 33Р“—33 = 1089 vertices, 6144 indices, 2048 triangles per tile; 69 696 / 131 072 totals; 128 mР’Р† triangle area; 6 % cap; count ranges) are not listed again. Everything below is new and NOT approved until v1.1 approval.

**Generator design ranges (Р’§6.5)** РІР‚вЂќ lengths in metres:

| ID | Value |
|---|---|
| D1 | Valley interior band: p0/p3 tangential coordinate and p1/p2 lateral coordinate in `[1024, 3072]`; p0 at u = 0, p3 at u = 4096; p1/p2 at u РІ‰в‚¬ 1365 / 2731 (integer thirds); actual draw interval `[L, U]` РІР‰вЂљ band per Р’§6.5a step 2 |
| D2 | p1/p2 lateral offset from the p0РІР‚вЂњp3 chord РІ‰В¤ 400 |
| D3 | Valley floor elevation at exit 150РІР‚вЂњ300 |
| D4 | Along-axis floor drop (entry РІв‚¬вЂ™ exit) 20РІР‚вЂњ60 |
| D5 | Valley shoulder rise 80РІР‚вЂњ160 on **both** sides, completed at the shoulder end (v1.1 "far-side rise over 1200РІР‚вЂњ2000" removed РІР‚вЂќ F2) |
| D5b | Mountain-side piedmont rise 60РІР‚вЂњ140, linear over the bench zone `[P0, P1]` with 25 m C1 end blends (new РІР‚вЂќ F3) |
| D6 | Valley floor half-width 90РІР‚вЂњ160 |
| D7 | Valley shoulder width 380РІР‚вЂњ650 |
| D8 | Mass centre lateral clearance from the valley axis (`v_max`) РІ‰Тђ floor half-width + shoulder + effective lateral radius `r_lat` + `bench_required_gap`, `bench_required_gap = 4 Р“— bench half-width + 50` (human formula; gap size forced by the T5 windows РІР‚вЂќ F3); parameters drawn from feasible intervals (Р’§6.5a), never post-clamped |
| D9 | Mass radius major 650РІР‚вЂњ1100, minor 450РІР‚вЂњ800; orientation integer degrees `[0,180)` |
| D10 | Mass peak 240РІР‚вЂњ420 above the base surface |
| D11 | Ridge half-width 110РІР‚вЂњ220; crest 70РІР‚вЂњ160; length РІ‰Тђ 2.5 Р“— half-width; РІ‰Тђ 1 ridge directed toward the valley; ridges in the mass zone ending РІ‰Тђ P1 + half-width; РІ‰Тђ half-width + 50 from S; combined by `max` |
| D12 | Saddle: exactly 1 in v1; col ridge between the two highest mass summits A, B (crest profile 0 at A and B); col crest РІ‰Тђ 180; col half-width 110РІР‚вЂњ220; S = midpoint of the gap between the A/B supports (replaces "40РІР‚вЂњ60 % along" РІР‚вЂќ F4); `d_AB РІ‰Тђ r_A,dir + r_B,dir + 100`, `r_dir РІ‰В¤ 900`; depth **70РІР‚вЂњ120** (min raised from 60 РІР‚вЂќ F1); radius 180РІР‚вЂњ300; net col height `s` from the Р’§6.5a step-7 interval. **Construction invariant (human): evaluated structure saddle elevation РІ‰Тђ nearest valley-floor elevation + 100**; plus structure saddle РІ‰В¤ min(highs) РІв‚¬вЂ™ 70 (F4) |
| D13 | Bench centreline at constant v = P0 + 25 + 2 Р“— half-width (between shoulder end and mass clearance line); length 600РІР‚вЂњ1200; half-width 90РІР‚вЂњ160; flatten 700РІР‚вЂњ850 РІР‚°; full-strength plateau = central half-width |
| D14 | Basin: exactly 1 in v1; far side; lateral clearance from valley axis РІ‰Тђ floor half-width + shoulder + radius + **250** (keeps T1 shoulder probes outside the basin РІР‚вЂќ F2); radius 220РІР‚вЂњ380 drawn from the Р’§6.5a step-9 feasible interval; depth **70РІР‚вЂњ100** (v1.1: 55РІР‚вЂњ90 РІР‚вЂќ F1) |
| D15a | Generator first builds all structural dimensions, then draws amplitude from `[0.035 Р“— relief, min(0.055 Р“— relief, (min_feature_margin РІв‚¬вЂ™ 10)/2)]`; non-empty by construction (relief РІ‰В¤ 780 m, min_feature_margin РІ‰Тђ 70 m РІвЂЎвЂ™ 27.3 РІ‰В¤ 30); empty = generation contract defect, never a silent reduction below 3.5 %; 3 octaves; wavelengths 512 / 256 / 128; weights 550 / 300 / 150 РІР‚° |
| D15b | Noise-margin rule: `2 Р“— amplitude + 10 m РІ‰В¤ min_feature_margin = min(saddle depth, basin depth, ridge crest, 70 m saddle-below-highs margin)`; enforced through the D15a interval (not repair); `validate()` reports violation as `ERR_MACRO_NOISE_BUDGET` |
| D16 | Noise attenuation: valley floor 350 РІР‚°, bench core **250 РІР‚°** (v1.1: 500 РІР‚° РІР‚вЂќ F3), basin core 350 РІР‚° |
| D17 | General interior anchor minimum `[128, 3968]Р’Р†` (valley endpoints exempt). Not a substitute for feature-specific probe containment (Р’§6.5a), which every mandatory morphology probe must satisfy inside `[0, 4096]Р’Р†` |
| D18 | Basin rim sample count 16 (evaluator basin_floor and test T6 use the same 16 points) |
| D19 | 8 integer frame symmetries (4 rotations Р“— mirror) |

**Preview presentation (Р’§6.7, E5)**:

| ID | Value |
|---|---|
| P1 | Contour lines every 25 m (minor) and 100 m (major) |
| P2 | Oblique camera: target region centre at mean evaluated elevation, azimuth 225Р’°, elevation angle 35Р’°, distance 5600, FOV 50Р’°, far plane 20 000; second framing: top-down orthographic covering `[0, 4096]Р’Р†` |

**Test thresholds and probes (Р’§13)** РІР‚вЂќ apply to structure and final unless stated:

| ID | Value |
|---|---|
| T1 | Valley: cross-sections at axis fractions 0.20 / 0.35 / 0.50 / 0.65 / 0.80; shoulder probes at Р’± (floor half-width + shoulder + 200); centre РІ‰Тђ 60 below each shoulder (structure) |
| T2 | Mass: centre РІ‰Тђ mean of 8 ring samples + 60, ring at **1.10 Р“— effective ellipse radius r(Рџв‚¬) + 30** in each of 8 directions (near the actual support boundary; v1.1 "1.6 Р“— major radius" removed); dominant summit РІ‰Тђ valley floor + 0.5 Р“— relief |
| T3 | Ridge: crest at ridge midpoint РІ‰Тђ lateral samples at Р’± 2 Р“— half-width + 30 |
| T4 | Saddle: РІ‰В¤ min(high_a, high_b) РІв‚¬вЂ™ 40 and РІ‰Тђ nearest valley-floor elevation + 100 |
| T5 | Bench (structure): core macro cross-gradient over the full-strength plateau (width = half-width, centred) РІ‰В¤ 0.5 Р“— each adjacent uphill/downhill macro gradient over windows of the same width immediately outside the band (v1.1 "full bench width" is non-discriminating: band edges are unflattened by continuity РІР‚вЂќ F3). Final: `|final РІв‚¬вЂ™ structure| РІ‰В¤ 0.25 Р“— amplitude` across the core (noise cannot be construction-bounded below the piedmont gradient РІР‚вЂќ F3) |
| T6 | Basin: centre РІ‰Тђ 20 below every one of the 16 rim samples |
| T7 | Slopes: valley-centre РІвЂ вЂ™ dominant-summit profile rises РІ‰Тђ 0.6 Р“— relief; РІ‰Тђ 85 % of 64 m steps non-decreasing (structure only); РІ‰Тђ one 256 m segment with mean gradient РІ‰Тђ 0.15 |
| T8 | Noisy margin: every T1РІР‚вЂњT4 and T6 ordering `X РІ‰Тђ Y + РћС‘` must hold in the final evaluation as `X РІ‰Тђ Y + 10` (T5 final per T5) |
| T9 | Spike/discontinuity safety bound (not a terrain-gradient, smoothness or rideability requirement): `|РћвЂќh| РІ‰В¤ 2.0 m` per 1 m step along 8 full-length dense lines (4 along X, 4 along Z at 512 / 1536 / 2560 / 3584) |
| T10 | Diversity acceptance battery for exactly 184729 / 42 / 77777 (not a claim about arbitrary seed pairs), each pair: valley РІР‚вЂќ different symmetry or max matched axis-point displacement РІ‰Тђ 256; masses РІР‚вЂќ different count or a matched centre moved РІ‰Тђ 384; ridges РІР‚вЂќ different count or a matched endpoint moved РІ‰Тђ 256; all three classes must differ |
| T11 | Fixture sets: same-input РІ‰Тђ 6 fixtures Р“— 3 builds; order set 15 fixtures (3 named seeds Р“— 5 coordinates); morphology set 16 fixtures (3 named seeds Р“— {(0,0), (1,0), (РІв‚¬вЂ™1,РІв‚¬вЂ™1), (3,РІв‚¬вЂ™2)} + seed 0, seed РІв‚¬вЂ™1, I64MIN/(I32MAX,I32MIN), I64MAX/(I32MIN,I32MAX)); finite grid 129 Р“— 129 (32 m, edges included) on 6 fixtures incl. the two extremes; determinism grid 65 Р“— 65 on 3 fixtures |
| T12 | Out-of-domain evaluator probes РІв‚¬вЂ™0.001 and 4096.001 (on each axis) |

**Run limits (Р’§12)**:

| ID | Value |
|---|---|
| V1 | Process time limits: `test_macro_geography` 180 s; `test_region_domain_skeleton` 120 s; `test_region_preview` 300 s; each capture 300 s |

## 19b. Human review of v1.1 (2026-10-04) and v1.2 change log

Human verdict on v1.1: NOT APPROVED; four conflicts to fix; D1РІР‚вЂњD7, D9РІР‚вЂњD11, D13РІР‚вЂњD16 (after clarification), D18РІР‚вЂњD19, T1РІР‚вЂњT8, T9 (as safety bound), T10 (as named-seed battery), T11, V1 otherwise acceptable; explicit closed sampling boundary required.

| # | Source | Change in v1.2 |
|---|---|---|
| R1 | Human (D8 + D13) | D8 clearance includes effective lateral radius and `bench_required_gap`; feasible-interval draws (Р’§6.5a steps 1РІР‚вЂњ4). |
| R2 | Human (D17 + T2) | T2 ring at 1.10 Р“— r(Рџв‚¬) + 30; feature-specific containment for every mandatory probe; D17 only a general minimum. |
| R3 | Human (D12 + T4) | Construction invariant structure(S) РІ‰Тђ F + 100 via dependent net col height (Р’§6.5a step 7). |
| R4 | Human (D15a + D15b) | Amplitude interval `[0.035R, min(0.055R, (m РІв‚¬вЂ™ 10)/2)]`, non-empty by construction. |
| R5 | Human | Boundary contract: ownership `[0, 4096)`, sampling `[0, 4096]`, out of domain `< 0` or `> 4096` (Р’§6.6). |
| R6 | Human | T9 labelled spike/discontinuity safety bound; T10 scoped to the named seeds. |
| F1 | Forced by R4 | With relief up to 780 m, `0.035 Р“— relief` reaches 27.3 m, so `(m РІв‚¬вЂ™ 10)/2` needs `m РІ‰Тђ 65`: saddle depth min 60 РІвЂ вЂ™ 70; basin depth 55РІР‚вЂњ90 РІвЂ вЂ™ 70РІР‚вЂњ100 (ridge crest min already 70); relief defined conservatively (no ridge/overlap stacking). |
| F2 | Forced by R2 containment + D14 | v1.1 far-side basin was infeasible at valley v = 1024 (needs РІ‰Тђ 1060 m far-side room even at minimum widths). Valley lateral interval `[L, U]` now derived from drawn widths; basin clearance +150 РІвЂ вЂ™ +250 so T1 shoulder probes never sit inside the basin. v1.1 D5 "rise over 1200РІР‚вЂњ2000 m" left only about half the rise at the T1 probe (60 m margin not guaranteed) РІвЂ вЂ™ shoulder rise completed at the shoulder end, both sides. |
| F3 | Forced by R1 + T5 | T5 over the full band width cannot detect a bench (band edges are unflattened) and the v1.1 bench zone had no guaranteed slope (shoulder top and mass foot are flat). Added piedmont rise D5b; core = plateau; gap = 4 Р“— half-width + 50 (the example 2 Р“— half-width + 50 leaves no room for the T5 windows); T5 binding on structure, final checked as a noise bound (РІ‰В¤ 30 m amplitude over РІ‰Тђ 90 m windows can exceed any guaranteed piedmont gradient); bench-core attenuation 500 РІвЂ вЂ™ 250 РІР‚°. |
| F4 | Forced by R3 + T4/T8 | With overlapping saddle masses, "saddle РІ‰В¤ highs РІв‚¬вЂ™ 40" (and its T8 final margin) is not guaranteed for any depth РІ‰В¤ 120. Saddle masses are now separated along the col so S lies outside every support; S = support-gap midpoint (replaces 40РІР‚вЂњ60 %); construction margin 70 m below highs. With mass count 2 the masses are joined by the col rather than overlapping. |

F1РІР‚вЂњF4 are arithmetic consequences of R1РІР‚вЂњR4, not new design scope; each needs explicit human approval with v1.2. Feasibility was checked by Python arithmetic over the range extremes (minimum slack under approved A1: valley lateral interval 88 m at fh 160 / sh 650 / bench half-width 160; saddle interval a single value at depth 70 / P_min 240 / drop 60; amplitude interval 2.7 m at relief 780).

## 20. Definition of Done

Request Р’§30 items 1РІР‚вЂњ22 all true, specifically: valid deterministic `MOUNTAIN_RIVER_VALLEY` plan from `RegionGenerator` for the whole declared input domain; structure-driven geography with every form demonstrated by G7; noise within budget (G8); byte/signature determinism across repeat, reorder and fresh processes (same engine/platform); global RNG neither consumed nor consulted; RegionPlan `/2`; R0 suite 145/145 with only H6 changes; all G10 negatives exact; `PREVIEW_RUNTIME` gate PASS with 64 tiles and zero topology/border defects; three real Vulkan captures accepted in human review; anchors frozen only per H7; zero MountainMassifField and zero production references; no player/road/hydrology/biome/streaming/physics change; retained gates executed and reported unaltered against Q2A; no unexpected parse/script/runtime errors, leaks or unapproved generated files (H1 governs only the exact certificate diagnostic, conditionally); E0/E1/E5 complete, E2/E3/E4/E6/E7 N/A as stated; fresh `slow-cycle-verify` PASS; fresh independent `slow-cycle-review` PASS; documentation states what R1 proves and defers; R2 not started.

## 21. Progress

- 2026-10-04 РІР‚вЂќ v1.0 drafted; baseline recorded. Human review: NOT APPROVED; direction accepted; H1РІР‚вЂњH8 rulings returned.
- 2026-10-04 РІР‚вЂќ v1.1 drafted incorporating H1РІР‚вЂњH8 and the Р’§19a enumeration. Human review: NOT APPROVED; four numeric/contract conflicts + boundary wording returned.
- 2026-10-04 РІР‚вЂќ v1.2 drafted: minimal numeric-contract amendment (Р’§19b R1РІР‚вЂњR6, F1РІР‚вЂњF4). Read-only work only. STOP for approval of v1.2 bound to its SHA-256.

## 22. Execution record РІР‚вЂќ 2026-10-04 approval and contract STOP

Human approved v1.2 by exact SHA-256 `a689b10ae96be0a9c7974701cb351b83add3195536b47e403c43c5b3bd5cd734`, branch `r1-macro-geography`, base `d94a80ccfe3939761d97369c994b9e5af8be555f`; complete H1РІР‚вЂњH8, Р’§19a and Р’§19b F1РІР‚вЂњF4 plus notes 1РІР‚вЂњ10. This approval supersedes the historical PLAN_ONLY/no-approval language retained in the original version history. All architecture, ranges, protected tests/gates and allowed-file limits remain as approved.

R1.1 PASS: branch/HEAD/origin/master and live remote master equal approved base, only plan dirty; full tracked hashes and approved plan bytes recorded. R1.2 seed implementation prepared in an isolated staging copy; G1 in a disposable project passed 61 checks (all seven approved rows for both purposes). Exact certificate diagnostic reproduced; raw channels preserved using approved engine SHA-256. This is a milestone observation, not final E1 acceptance. No code or UID has yet been transferred to this repository. R1.3/R1.4 staging drafts are incomplete.

STOP: Р’§6.5a step-2/step-4 minimum configuration ignores the specified ceil-plus-1-m clearance. fh=160, sh=650, bhw=160 gives L=1530,U=1621,gap=690. Four axis points at v=1621 are declared admissible. P1=3121. Every allowed ellipse has lateral support and radial extent at least 450 m. Rounded support clearance is at least 451 m, so centre v>=3572. Even the smaller unrounded T2 probe requires centre v<=3571. Interval [3572,3571] is empty; at the minimum centre the probe reaches v=4097. No particular RNG seed is claimed to have reproduced this draw combination. Independent arithmetic reproduction is retained. No feasible interval/range/test/domain change, clamp or fallback was made.

Evidence root: `C:/Users/Luisa/Documents/Codex/2026-10-04/r1-execplan-v1-2-approved-approved/outputs/r1-evidence/`. Files: approved_plan_v1.2.md, approval.txt, preflight.json, r1-2-seeds/{stdout.txt,stderr.txt,process.json,engine.log}, mass_interval_defect.json, contract-defect.md, fresh-contract-verification.md when available.

Remaining: human contract amendment before dependent implementation; full morphology/preview/captures; required human visual acceptance before H7 anchor freeze; final R0 145/145; retained verification campaign; fresh final VERIFY; separate independent Opus REVIEW after final VERIFY PASS (Opus not available in current agent model list); closeout only after both acceptance gates. No completed record/commit or R2.

## 23. Approved A1 resume РІР‚вЂќ 2026-10-04

Human approved exact amendment A1 SHA-256 `8e1fb0daf35c5923a81fb0bdeb3787d836b9657dcccce860551e17af0d2a52fd`, parent approved v1.2 SHA-256 `a689b10ae96be0a9c7974701cb351b83add3195536b47e403c43c5b3bd5cd734`. Original approved bytes, original defect, raw seed milestone and fresh stop-verification report remain preserved. This approval corrects the minimum mass/probe feasibility contradiction; it is not VERIFY/REVIEW evidence.

Step-2 reservation is now 451+527=978 m: minimum clearance radius ceil(450)+1=451; integer minimum probe extent ceil(1.10*(ceil(450)+1)+30)=527; U=4096-(fh+sh+gap+451+527). Worst-case slack is 88 m. Accepted minimum: fh160/sh650/bhw160/gap690, L1530/U1618, centre3569, T2 positive probe4095.1, upper centre3569. T2 formula and all other ranges/thresholds/gates remain unchanged. The prior Р’§22 STOP is historical and resolved only by this exact A1.

Execution resumes at staged R1.3/R1.4; actual feasible bounds will be recorded before every RNG draw. No retry/clamp/repair/fallback/seed-special case. Any other empty interval or material conflict requires STOP and separately approved amendment. Human visual acceptance precedes anchor freeze; final declared campaign, fresh read-only VERIFY and separate independent Opus REVIEW remain required; no R2.

## 24. Pre-visual implementation milestone РІР‚вЂќ 2026-10-04

R1 v1.2 + approved A1 remains the only authorization. R1.2 seed contracts: 61/61 checks. R1.3РІР‚вЂњR1.5 descriptors/generator/evaluator implemented; the first complete successful direct-domain run executed 729873 checks, zero assertion failures. Shape defects observed in earlier runs were corrected at their generator/evaluator owners within approved ranges, without changing the approved morphology probes or thresholds. Floor interpolation now blends straight-section projections continuously at bends; col shaping uses continuous end/lateral blends and a feasible width drawn within 110РІР‚вЂњ220 m; optional third-mass placement reserves the existing T3 probes. No clamp/repair/retry/fallback geography was introduced. Every actual RNG interval is logged before its draw.

R1.6 composition/injection and `/2` implemented. H6 T9 changes only the approved state literal; all other R0 bytes are preserved. Interim bounded R0 run (`a1-interim-r0-bounded`, 120 s cap): all 145 checks completed, exactly six old T3 anchors failed, all other 139 checks passed. This is an implementation-state observation, not acceptance evidence. The earlier interim run used an erroneous wrapper cap of 180 s (actual 21.109 s); it is retained as a historical observation and replaced by the correctly bounded run. T3 literals and P2_TEXT remain unchanged until H7.

R1.7/R1.8 isolated preview and tests implemented. Expanded pre-anchor macro suite: 730287 checks per fresh process, zero assertion failures; stdout byte-identical for `a1-previsual-macro-A` and `-B` (SHA-256 ce9af31911da99e7ce421092a69d9f2b9c1cebfccef3784dd5cfb21a61f52dc9). B uses current source; A differs only in the R0 T9 line terminator subsequently restored to the original CRLF bytes. Both explicitly loaded all 12 changed/new script/scene resources. G3 remains absent pending human acceptance; these runs do not replace the post-freeze E1 campaign. The real Forward+ Vulkan preview run `a1-preview-counted` completed 867522 checks with zero failures, no engine errors/leaks; 64 tiles, 69696 vertices, 131072 triangles, bit-identical borders, face/normal/coverage/round-trip/isolation checks. Timings and approximately 3245568 committed mesh bytes are observational only.

R1.9a: six original PNGs (oblique and top-down for each of 184729/42/77777 at (0,0)) saved and reloaded, dimensions 1280Р“—720 checked, non-uniform pixels checked, actual Forward+ Vulkan / NVIDIA GTX 1650 SUPER recorded. Camera, source, plan/macro and PNG identities are logged. Author inspected all six; no visible holes or tile seams observed. Human comparison is in the external evidence `visual-review.html`. Malformed `--seed=not_an_integer` exercised the real preview path, exited 1 with ERR_PREVIEW_CLI_SEED, and created no capture.

All engine executions/imports ran only in disposable copies. The first sandboxed editor import failed to write normal host editor caches; raw diagnostics are retained and it is not acceptance evidence. The succeeding import with normal cache access had zero engine diagnostics and generated the six new UID sidecars; these alone were copied byte-for-byte into the candidate. The report wrapper initially failed to print localized import text, after the complete raw logs/process record were already saved; the wrapper encoding was corrected. Neither import report is substituted for E0's explicit resource loads.

Headless macro runs reproduce only the exact H1 certificate-store diagnostic; raw stderr is preserved. No suppression/filter/allowlist was added. H1 remains conditional on all nine conditions including immutable historical A2 evidence, and does not waive any product failure. Vulkan preview/capture runs have empty unexpected-diagnostic channels. Historical domain failures and the original v1.2 feasibility defect remain preserved, not relabelled PASS.

Candidate implementation/test/UID identity (18 paths, sorted compact JSON map of raw-byte SHA-256 hashes, excluding this evolving plan): `6146d19d6571af901ab644b6ab11a22401b9199377ab9e19fac4006b6d28c874`. Manifest is external `candidate-code-identity.json`; full protected-file/source/diff audits and raw evidence are external. No commit/push or closeout documentation change.

Current gate: **R1.9b WAITING_FOR_HUMAN_VISUAL_ACCEPTANCE**. H7 requires explicit human acceptance before R1.9c anchor freeze; no acceptance has yet been received. Final R0 145/145, G3 literals/independent Python hashes, the retained/Q1 campaign, fresh read-only slow-cycle-verify and separate independent Opus slow-cycle-review remain pending. This implementation milestone is not VERIFY/REVIEW evidence. No Opus launcher/model is available in the current session; no substitute or author self-certification is authorized. Keep the active plan; no R2.

## 25. H7 accepted; R1.9c anchor freeze РІР‚вЂќ 2026-10-04

Human explicitly accepted the six Vulkan captures: "Accept the structural result and permit H7 anchor freeze". Supersedes the waiting state at the end of Р’§24. Freeze follows morphology PASS and completed E5; approval is not VERIFY/REVIEW evidence. Added literal G3 macro canonical text and four macro/RegionPlan signature pairs; changed only H6 five R0 T3 signature literals and P2_TEXT, preserving all other original R0 bytes (plus the already-approved T9 literal). Independent Python reserialization from fixed field order, seed framing and integer bounds matched all six Godot canonical texts/signatures. Final macro own count is 730296 (nine G3 checks added); R0 remains 145. Frozen geometry/generator/evaluator/preview/capture/UID source remains unchanged from accepted E5 captures. Final campaign now proceeds; no R2.

## 26. Final campaign complete; independent verification pending РІР‚вЂќ 2026-10-04

Final frozen-source macro suite: 730296 checks per process Р“—2, zero failures, byte-identical stdout. Final restored R0: 145/145 Р“—2, zero failures, byte-identical stdout. The 867522-check real Vulkan preview suite and six H7-accepted captures remain bound to unchanged final runtime source; the only post-capture code changes were the explicitly approved test anchors. Malformed-seed fixture exits1 with exact ERR_PREVIEW_CLI_SEED and no capture.

Retained Q1 campaign run 20261004T174151Z-6c86415c: seed_diversity PASS, monotony PASS, virtual_rider PASS, capture_visual_vulkan PASS; raw logs/artifacts preserved. Rider actual355.9m meets the unchanged350m gate, not full500m/E7 acceptance. Frozen Q2A aggregate SHA-256 57bf601dab4b8b93607d3018eb10a6900a8c615177442168249ddfdd9af3574c was checked; 39 original product FAILs remain FAIL, not repaired/reinterpreted. C10/C12 OPEN, whole-game runtime acceptance INCOMPLETE. No new attributable regression observed in these four retained checks.

Q1 selftest49/49 PASS with normal Windows process access; the preceding sandbox timeout remains INCOMPLETE. Manifest66 suites /209 accepted matrix rows PASS. Disposable retained import changed only default_bus_layout.tres and the two screenshot .import files inside the copy; all three were restored to exact candidate/protected bytes before the retained campaign. No imported cache or other generated source was transferred into the working repository.

Scope audit: exact19-path whitelist,312 protected files match original raw-byte hashes, H6-only R0 bytes, six UID sidecars unchanged, no production reference or reverse dependency introduced. Candidate code identity (18 paths, excluding evolving plan) 4ea8d4bbf47e461ca8daebe700d55da8a329200951bc9ac3a4b1aa83e69a43ca. Final raw-process/coverage/determinism/H1/A2/baseline bindings are in external final-campaign-observations.json; source/diff bindings in final-scope-audit.json and final-candidate.patch. The historical A2 manifest was independently rehashed, with every entry unchanged; H1 classification remains R1-only and conditional on the nine approved conditions.

These are author observations, not self-certified VERIFY or REVIEW evidence. Next: fresh read-only slow-cycle-verify; only after VERIFY PASS, separate fresh independent Opus slow-cycle-review. No callable Opus model/tool or installed Claude launcher was found in the current environment, including the normal signed-in-user environment; no alternate reviewer or author review is authorized. Closeout documents, archive/clear, commit/push and R2 have not been performed.

## 27. Fresh verification FAIL; owner correction restarted — 2026-10-04

The independent slow-cycle-verify report rejected the frozen candidate: lattice hashing discarded noise-seed bit62, and structural frame symmetry was drawn after amplitude contrary to the approved last-draw contract. These are implementation defects; no new empty interval or approved numeric conflict was demonstrated. The failed candidate source, exact diff, raw campaign and H7 acceptance are preserved. Neither this FAIL nor the earlier green author campaign establishes acceptance.

Owner corrections fold the complete high lane before its existing masked multiply/xorshift and draw symmetry before the amplitude, which is now the final RNG call. No seed derivation, schema, numeric range, threshold, protected test or allowed path is expanded. Every RNG call still logs its actual feasible interval first. Reopened R1.5 with the previously approved pre-anchor test stage (730287 checks); the nine G3 checks will return only after fresh morphology PASS, captures and human H7 acceptance. The former H7 acceptance applies only to the preserved former captures; it does not authorize re-freezing changed anchors. Existing R0 anchor literals remain as historical interim expected failures until the new H7 freeze; all other139 checks remain required.

Fresh domain, preview, Vulkan and retained campaign evidence is being recorded under correction-1. Original v1.2 and A1 bytes, original975m defect and all historical failed observations remain unchanged. No R2; independent review still requires fresh VERIFY PASS and a separate fresh Opus context.

## 28. Human-requested pause for today — 2026-10-04

Human requested: “закончи на сегодня . завтра продолим”. Work stopped at this explicit request; no automatic continuation, review or R2. The previous H7 acceptance remains bound only to the old captures. The independent verification FAIL and failed candidate are preserved.

The two owner corrections exist in work/stage only (full high seed-lane fold and symmetry before the final amplitude draw). Corrected pre-anchor macro730287/0 completed in136.203s under180s. Supplemental actual GDScript seed diagnostic189 cases matched Python, every63 seed bits affects samples. Interim R0 has exactly six expected stale T3 failures and139 other checks pass. Corrected real Vulkan preview867522/0 completed in65.141s under300s. Seed184729 oblique/top-down captures saved/reloaded with clean stderr in63.875s; seeds42/77777 captures and all-six author inspection/human H7 review are still pending. No corrected anchor freeze has occurred.

Repository code remains the previous frozen candidate; only the execution record has been published since its FAIL. Corrected source has not yet been published. No active Godot process or verifier remains. Resume from correction-1: finish two seed captures, inspect all six, present fresh H7 decision, then independently freeze anchors only upon human acceptance; rerun final macro×2/R0×2 and retained campaign, publish exact guarded allowed files, produce fresh source/diff/evidence bindings and fresh read-only slow-cycle-verify. Only after VERIFY PASS may separate fresh Opus slow-cycle-review start; no Opus tool/model/launcher is currently available. Closeout/archive/root-slot clear require both PASS; no commit/push/R2 occurred.

## 29. Human resumed R1 — 2026-10-05

Human instructed “продолжай”, ending the pause in §28. Stage/published/protected raw hashes, exact dirty scope, branch/HEAD, original v1.2/A1 digests and engine identity all match the pause checkpoint. Resume within v1.2 + A1 from the remaining corrected E5 captures and renewed H7; no amendment or next phase is inferred. No R2.

### 29a. Corrected E5 complete; renewed H7 pending — 2026-10-05

Completed corrected seed42 and77777 captures (61.562s and67.015s under300s), each with two real Forward+ Vulkan PNGs saved/reloaded and clean stderr. Together with184729 this is the complete six-frame package. All six original frames opened individually for author inspection; visibly different valley/mass/col composition, continuous contour bands and no visible holes/seams/inverted faces/spikes. Author observations are not human H7 approval. Runtime source and camera/plan/macro/PNG identities verified; renewed human decision requested with correction-1/visual-review.html. No new anchors frozen while approval is pending.

Malformed preview CLI fixture: exit1 with exact ERR_PREVIEW_CLI_SEED and no captures; raw stdout/stderr retained. The external comparison/helper display encoding and exact existing plan punctuation were restored to UTF-8; all numeric tokens, runtime bytes, immutable original approvals and failed evidence remain unchanged. Final macro/R0 campaign and retained runs await the approved post-visual freeze sequence. No R2.


## 30. Approved A2 revision 2; descriptor milestone complete - 2026-10-05

Human approved exact A2 SHA-256 ecb3d8f95362cb41b754de1a3654f26c8aeb719ed50de975f642f6b7a596edaa and C1, with the explicit condition that old-candidate parity checks be self-contained in the repository/test fixture. The original proposed A2, revision1 conflict, revision2 approved bytes and all prior evidence remain immutable. H7 has VISUAL CORRECTIONS REQUIRED for the previous corrected captures; no current anchor freeze or final VERIFY is authorized before a new accepted six-PNG package.

Before feature implementation, completed the descriptor-level coupled outer-col milestone: fixed original production-W blend, conservative floor/noise derivative budgets, bend/narrowing sum guards, support/bench/probe guards and positive production domains. Global capacity lower bound2.9347566664911167 proves at least bend1m+narrow1m feasible for every approved generated case; the calculated canonical positive sign set preserves ridge side-probe ordering. No evaluator/terrain sampling or trial geography was used. This author construction milestone is not final VERIFY/REVIEW evidence. Detailed proof, source hashes and approval conditions are retained externally under A2-execution.

Implementation is staged only in the approved original owners. The original RNG stream retains every invocation, including the reference col-width advance; one direct production W draw on the private organic stream is the sole emitted descriptor exception. D6/D7 envelopes and every other original descriptor remain fixed. Pre-anchor tests/captures and fresh human H7 are still pending. Empty positive intervals remain a STOP, never repaired. No R2.

## 31. A2 H7 rejected; A3 read-only investigation; STOP - 2026-10-05

Human H7 verdict on the six A2 Vulkan PNGs: VISUAL CORRECTIONS REQUIRED (mountain masses read as elliptical/concentric primitives; the col between the dominant masses reads as a synthetic narrow connector; valley variation sufficient; bench not a blocker). Anchors remain unfrozen; no final VERIFY or review; no R2.

Reconstructed state: branch r1-macro-geography, HEAD d94a80c, nothing staged. The repository working tree holds the earlier frozen candidate that failed VERIFY (generator ee8723b4, evaluator 3bbb274e, test b05f0a56, plan b6fbc096), NOT the correction-1 or A2 code. The corrected pre-A2 stage (generator b48b0173) and the A2 stage (generator 242da72e, evaluator ee8a715a, plan 3bea3e2b, test 9d793eab) exist only externally (A2-execution/pre-A2-source, work/disposable/A2, pre-H7-A2-candidate.patch). Digests re-hashed from preserved files: v1.2 a689b10a, A1 8e1fb0da, A2 revision 2 ecb3d8f9. Raw A2 logs: pre-anchor 732144/0 (161.5 s), Vulkan preview 867522/0 twice, interim R0 145 checks with exactly six expected T3 failures; these were read, not re-run.

Investigation result (read-only; scratchpad analysis, no repository code changed): a numeric-only A3 (minima raised, ceilings kept) cannot fix either form. Col: in 80% of 4003 production seeds the whole A2 bend/narrowing arm lies under the mass support; visible bend/narrowing on the three rejected seeds is 0.0 m; the visible gap between supports has median 253 m and is covered ~100% by the unchanged protected interval. Masses: footprint deviation from a best-fit ellipse is 1.5-2.0% on the rejected masses and at most 2.6% at the A2 ceilings; widening the q-family is limited by the T9 budget to about 2x. Full report, scripts, data and non-evidence prototype renders: external A3-investigation/A3-investigation-report.md.

Gate: STOP for a human decision on the A3 direction (options M-a/M-b/M-c and C-a/C-b/C-c in the report). No amendment text is approved; no A3 implementation exists. The repository code will be brought to the A2 stage by the guarded publish route only after an A3 amendment is approved. No R2.

## 32. A3 direction decided; prototype gate (scratch only) - 2026-10-05

Human decision for A3: masses M-b, col C-a; M-a is not to be proposed. No production code, test or anchor was changed; the repository still holds the earlier frozen candidate, not A2 (see section 31). Before any A3 implementation the exact accepted A2 stage must be published into the repo by a guarded, hash-checked route, then the approved A3 delta applied on top; nothing is rebuilt from memory.

Prototype results (scratch copies of the A2 stage; design evidence only, not H7/VERIFY/acceptance/anchors): M-b (height-dependent core deformation inside the unchanged A2 footprint; A2 contour self-similarity metric D=0.000 exactly, prototype median 0.28) and C-a (S-curve + flare over the visible support gap, depression coupled to the shifted centreline, minimum visible gap 500 m; 0 generation failures in 3000 seeds, gap min 502) render for the three named seeds. Slope budget is binding for both (M-b strength must be derived per mass; C-a kappa about 0.12). Author judgement: mass cue removed; col cue reduced but not clearly removed (steep narrow cross-section remains). Therefore no A3 amendment text has been drafted. STOP for human review of the six prototype PNGs: external A3-investigation/prototype-A3-NOT-EVIDENCE/comparison.html (v5) and report addendum section 6. No R2.

## 33. A3 pass 2 prototype gate (scratch only) - 2026-10-05

Human follow-up: M-b accepted with analytically derived per-mass strength; col allowed a wider/gentler visible cross-section (local, derived); minimum visible gap accepted as a principle, value to be derived. No production code, test or anchor changed; the repository still holds the earlier frozen candidate (section 31). Results (external A3-investigation report section 7): the per-mass slope bound is closed-form in s with a 720-point sweep in phi (measured/bound <= 0.94); the minimum gap derives to 2R+482 per saddle (842-1082 m, not 500), non-empty by a worst-case orientation argument (margin 108 m), 0 generation failures in 3000 seeds; arms-only col shaping is provable, interior shaping is not (no analytic base bound exists), only constant interior widening is monotone-safe; plan-view bend is curvature-limited to a few metres at 240 m arms. Author visual judgement of the six pass-2 PNGs: both H7 cues reduced, not clearly removed (masses still moderately nested at the analytic cap; col still straight in the interior). Therefore no A3 amendment text was drafted. STOP for human decision on MU_CAP (0.418 vs 0.60), the interior widening policy f, and whether to accept empirically verified (not analytic) interior shaping. No R2.

## 34. A3 amendment prepared - 2026-10-06

Human A3 decisions (MU_CAP 0.60 as a maximum with per-mass analytic strength; interior half-width 220 m; no extra interior deformation; visible gap 2R+482 with a formal feasibility derivation; guarded publication of the accepted A2 candidate before any A3 code; stop for approval of the exact A3 SHA) were turned into the exact amendment text, external to the repository: A3-amendment/proposed-amendment-A3.md, SHA-256 87a47dc4ab5892e8a194d8436bd0989ebde21857822408c244d2ca2e0834b341 (parents: v1.2 a689b10a, A1 8e1fb0da, A2 revision 2 ecb3d8f9). Status: PROPOSED / NOT APPROVED. Repository code, tests, anchors and UIDs are unchanged by this preparation; the repository still holds the earlier frozen candidate in four paths (generator, evaluator, plan, test_macro_geography), which section 2 of the amendment replaces byte-for-byte with the accepted A2 stage only after approval. Scratch reference implementation and evidence are external (adapted protected macro suite 730298 checks, 0 failures with the proposed T7 tolerance, 1 strict float-tie failure; 6000 seeds 0 generation failures; T3 dominance 0 violations in 1200 probe pairs; preview 867522/0; R0 interim 145 with the six expected stale anchors). Separate explicit approvals are requested for T-A (retire/replace A2-only checks), T-C (T7 comparator tolerance 1e-4) and the optional S-1 scan test. STOP for human approval; no publication, implementation, anchor freeze, VERIFY, REVIEW or R2.
