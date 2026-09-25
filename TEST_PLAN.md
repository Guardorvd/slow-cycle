# Slow Cycle — Verification & Testing Protocol

## 1. The 10-Minute "Ride Test" (Core Milestone Verification)
The ultimate quality gate for Slow Cycle is the uninterrupted continuous **Ride Test**.

```text
Run fixed Seed -> Ride for 10 minutes continuously -> Measure telemetry and performance
```

### Acceptance Checklist:
- [ ] **Endless Road**: Road continuously generates ahead; never runs out or dead-ends.
- [ ] **No Seam Snagging**: Zero collision hitches, vertical steps, or wheel catching at chunk boundaries.
- [ ] **Zero Stutter / Hitching**: Chunk spawning in front and deletion behind occurs without frame drops (stable frame time $\le 16.6\text{ ms}$).
- [ ] **No Memory Leak**: RAM and VRAM footprint remains completely flat after 500+ spawned chunks.
- [ ] **Physical Stability**: Bicycle never launches into the air, falls through ground, or reports `NaN` / `Inf` coordinates.
- [ ] **Comfortable Dynamics**: Speed remains naturally bounded between $0\text{ km/h}$ and $48\text{ km/h}$ via air drag.

---

## 2. Fixed Test Seed Battery
All procedural updates must be tested against 5 deterministic seeds:

| Seed ID | Seed Value | Profile Character | Primary Test Focus |
| :--- | :--- | :--- | :--- |
| **SEED_001** | `10101` | **Normal / Balanced** | Baseline balance of forest paths, sunny clearings, and gentle hills. |
| **SEED_002** | `20202` | **Curvy / Winding** | High density of sweeping S-curves to test dynamic banking and steering smoothness. |
| **SEED_003** | `30303` | **Hilly / Rolling** | Frequent elevation changes to verify uphill deceleration and downhill coasting. |
| **SEED_004** | `40404` | **Scenic Straights** | Long straightaways through dense pine forests to verify sense of cruising speed. |
| **SEED_005** | `50505` | **Boundary Stress** | Maximum permitted slope ($-6.5^\circ$) and tightest radius ($35\text{m}$) to verify constraint clamps. |

---

## 3. The 3-Track Testing Tier (Sprint 4G–4M Hierarchy)
Testing is structured across three distinct track levels with strictly defined roles:

| Track / Scene | Scale | Role & Focus | Mode Access |
| :--- | :---: | :--- | :--- |
| **4K — Riding Lab 2.0** (`riding_lab_track.tscn`) | ~300–600 m | **Technical Geometry**: Tight corners, switchbacks, berms/slopes (if spike succeeds), steep climbs/descents, rollers, crests, compressions. | Mode Select (`[3]`) |
| **4L — Gravel Training Loop** (`gravel_training_loop.tscn`) | ~800–1500 m | **Riding Rhythm & Zen Flow**: Natural cycle of pedaling, coasting, sweeping turns, gentle slopes, surface changes. | Mode Select (`[4]`) |
| **4G — Regression / Endurance Track** (`riding_feel_test_track.tscn`) | ~2.8 km | **Long-Form Stability**: 18 calibrated sections, C1 seam continuity, 56 chunks, memory stability, automated telemetry soak tests. | Mode Select (`[2]`) |

*Note: 4G is no longer the primary manual feel evaluation track; that role is now served by 4L (flow) and 4K (technical).*

---

## 4. 12-Point Behavioral KPI Gate (Sprint 4H / 4M Protocol)
Every physics change in 4H–4M must be measured against the 12 KPI baseline:

1. **0 → 20 km/h acceleration**: Muscle ramp duration ($4.8–6.5\text{ s}$).
2. **20 → 25 km/h acceleration**: Transition into cruise regime ($sustain\_thrust$).
3. **25 → 40 km/h sprint**: Diminishing returns ramp and 44 km/h hard cadence ceiling.
4. **25 → 0 km/h coasting**: Free roll duration on flat ($25–35\text{ s}$).
5. **Braking distance**: Rapid bite, quadratic ramp ($0.15\text{ s}$), dive pitch $-1.44^\circ$.
6. **Bank entry time**: Responsive roll onset without lag.
7. **Maximum bank**: Physical clamp ($\le 24.1^\circ$).
8. **Bank recovery**: Self-righting speed returning to vertical.
9. **Steering return (Caster Trail)**: Return to neutral after input release ($0.52\text{ s} \le 0.75\text{ s}$).
10. **Cornering Scrub onset**: Strictly $0.0\text{ m/s}^2$ for $a_{\text{lat}} \le 1.8\text{ m/s}^2$.
11. **Cornering Scrub magnitude**: Proportional deceleration under excess lateral load ($0.22 \times \Delta a_{\text{lat}}$).
12. **Crest / Dip pitch response**: Single/dual-ray adherence, zero pitch collapse on crests.

---

## 5. Automated Verification Suite & Engine Contracts
Automated headless checks run using the Godot console (no CI workflow is configured in the repository):

```powershell
# Unified master validation suite (Godot 4.7+, 7 tiers)
godot --headless --path . --script scripts/test/test_sprint_4m_master.gd
```

- **Most recent run: 25.09.2026, Godot 4.7.2 mono (headless); 125 expected checks across 7 tiers all PASS**:
  - `Tier 1`: 68 numbered core verifications in `scripts/test/test_diagnostics.gd` (#1–#68).
  - `Tier 2A/2B`: 4G Test Track Baseline (6 geometry verification + 8 live ride simulation assertions).
  - `Tier 3`: 4K Technical Riding Lab (15 geometry & structure contracts).
  - `Tier 4`: 4L Gravel Training Loop (16 rhythm & Zen Flow contracts).
  - `Tier 5`: 4K T10 Ballistic Airborne & Landing Invariant Fixture (6 invariants: detachment, flight duration, ballistic curve, recontact, continuous path, suspension compression).
  - `Tier 6`: 5-Seed Procedural Determinism Battery (5 seeds match within $\Delta p \le 10^{-6}$ m; tangents and curvature use the same tolerance).
  - `Tier 7`: Multi-Scene Switching Memory Soak (7 transitions, 0 dangling nodes).
  - The runner attributes a tier's expected count when its subprocess exits with code 0; it does not collect individual assertion events from subprocess output. Treat 125 as an expected assertion budget, not a dynamically measured count.
- **Leak Gate**: The documented acceptance criterion is 0 ObjectDB leaks on exit across all runners.
- **Human Perception Gate**: 15 observed gameplay points conducted without F3 HUD, 3x repetition for critical mechanics, and Blind Human Perception Pass. Full report in `docs/sprints/sprint_4m_validation_report.md`.

---

## 5.1. Sprint 5 Mountain World & Road Contract Suites

**Latest world-generation run:** `test_fork_decision.gd` 212/212; `test_fork_geometry_verification.gd` 15/15; `test_branch_streaming.gd` 49/49; `test_road_graph.gd` 61/61; `test_road_grammar.gd` passed 5 seeds × 1000 chunks; `test_mountain_validation.gd` 12/12 across 60 traversed forks. RAM delta was +19.7–20.9MB across those 3 seeds (below the 25MB gate). Branch integration additionally verifies edge/centerline mapping, both route transitions and DAG continuity.

### C. Test Directory Map and Determinism Scope

- `test_sprint_4m_master.gd`: aggregate regression entry point; launches the core, 4G, 4K, and 4L suites and runs airborne, determinism, and scene-switch fixtures.
- `test_diagnostics.gd`: numbered system contracts #1–#68. It is a legacy, broad contract script, not a small unit-test file.
- `test_track_verification.gd`, `test_track_ride.gd`, `test_riding_lab.gd`, `test_gravel_loop.gd`: geometry and gameplay checks for fixed tracks.
- `test_road_contract.gd`, `test_road_grammar.gd`, `test_road_graph.gd`, `test_fork_decision.gd`, `test_fork_geometry_verification.gd`, `test_branch_streaming.gd`, `test_terrain_carver.gd`, `test_mountain_validation.gd`: targeted world-generation/branching suites; run individually when changing those systems.
- `test_airborne_empirical_gate.gd`, `test_airborne_calibration_gate.gd`: empirical physics calibration gates. `test_soak_run.gd` and `test_procedural_run.gd` are longer soak/procedural runs. `capture_*.gd` scripts capture screenshots; `test_*_generator.gd` and the `*_generator.gd` files provide test fixtures/generators.

**Determinism guarantee currently exercised:** in the same Godot runtime and with the same seed and same ordered sequence of chunk-generation calls, two independent `RoadLogic` instances are compared over 15 chunks for equal sample counts and position/tangent/curvature deltas no greater than `1e-6`. This does not establish cross-version bit identity or order-independent generation across branches. Foliage derives its RNG seed from world noise seed and chunk id; fork child seeds derive from parent seed, fork id, and branch index.

### A. Airborne Empirical Physics Gate (`scripts/test/test_airborne_empirical_gate.gd`)
Measures existing `BicycleController` dynamics over varied drop geometries without modifying bicycle kinematics:
* Measures air time, flight distance, touchdown vertical velocity $v_y$, and suspension deflection across heights $0.2 \dots 1.2$ m.
* Calibrates safety envelopes for `RoadAirborneContract`: `MICRO_DROP_MAX_HEIGHT = 0.35m`, `AIRBORNE_MAX_HEIGHT = 1.20m`.

### B. Road Contract & Validator Suite (`scripts/test/test_road_contract.gd`)
Runs full geometric validation against `RoadGenerationContract` (v5.1.0) and `RoadAirborneContract`:
```powershell
godot --headless --path . --script scripts/test/test_road_contract.gd
```
* **Synthetic Battery T01–T16**:
  * T01–T08 (Valid cases): straight, constant downhill $-6^\circ$, switchback $R=19$m, micro-drop, short airborne with landing, full airborne chain, downhill with crest drop, downhill with recovery straight.
  * T09–T16 (Invalid / Injected defects): uncontrolled gap (airborne without landing), excessive airborne length $>6$m, excessive drop height $>1.2$m, uphill landing, sharp landing curvature $R=18$m, missing landing FSM violation, sightline occlusion, and seam coordinate tear 5mm.
* **Procedural Multi-Seed Validation**: 15 chunks across 5 deterministic seeds (10101–50505) verified 100% compliant.
* **Micro-Benchmark**: 100 chunks (2500 samples, 5.0 km) validated in $\approx 7.6$ ms ($< 0.08$ ms per chunk).


---

## 6. Developer Debug HUD (F3 Key)
A developer overlay displaying live generation and bicycle telemetry:

```text
=== SLOW CYCLE DEBUG ===
Seed: 10101 | Chunk: #14 (Total generated: 42)
Active Chunks in Tree: 7
Speed: 23.4 km/h | Slope: -3.2° (Downhill) | Curve Radius: 58.2m
FPS: 84 | Frame Time: 11.9ms | Chunk Gen Time: 0.8ms
Memory: Static 48MB | VRAM 182MB
Surface: GRAVEL | Rough: 16% | Susp: -2mm | Mode: [CRUISE]
Lat Accel: 1.2 m/s² | Scrub: 0.0 m/s² [FLOW]
Road: CONTINUOUS [OK] | Raycasts: GROUNDED [OK]
========================
```
