# Documentation status — D0

STATUS: HISTORICAL

Scope: сохранённая legacy документация; численные результаты, команды, критерии и прежние prompts ниже имеют историческую область. Source revision: `ed7d1322da1a5700a8c64425708e1c813213c7f6`; исходные даты отдельных записей сохранены в теле.

Current source of truth / Replacement: [TARGET_GAME_BLUEPRINT](../TARGET_GAME_BLUEPRINT.md); [MASTER_IMPLEMENTATION_PLAN](../MASTER_IMPLEMENTATION_PLAN.md).

Current state: [CURRENT_PROJECT_STATE](../CURRENT_PROJECT_STATE.md); navigation: [docs index](../README.md); historical catalogue: [history](../history/README.md).

**Historical next-step notice:** все прежние «актуально», «главный план», «следующий этап», approvals и инструкции следующему чату в теле — история, не действующий task scope. D0 завершает смену authority; далее требуется отдельный план D1. Старые WORLD/P/B scopes не возобновляются автоматически. PASS относится только к указанной ревизии/coverage; это не новый PASS игры.

---

# Slow Cycle — Sprint 6 v4 Completion Report

> Исторический документ. Сверка дня 01.10.2026: [актуальный статус](../../docs/CURRENT_PROJECT_STATE.md), [результаты сегодняшних этапов](../../docs/TODAY_CHANGES_2026_10_01.md). Исходные измерения и утверждения ниже сохранены; они не подтверждают текущую готовность мира и не определяют ближайшую задачу.
**Sprint Focus:** Living Mountain Generation: Observability & TDD First  
**Date:** 2026-09-29  
**Engine & Target:** Godot 4.7.2 Mono (Console Headless & Runtime), Vulkan Forward+, Windows  
**Architectural Directives:** `AGENTS.md` (Rules 1–12), `ROADMAP.md` (Sprint 6 v4), `ARCHITECTURE.md`, `TEST_PLAN.md`  

---

## 1. Executive Summary & Root Causes Eradicated

Sprint 6 v4 permanently eliminated the root causes of the historical straight-road and monotony defects in *Slow Cycle*, transforming the procedural descent from an artificial straight corridor into a dynamic, living alpine singletrack with high visual and physical immersion:

| Defect & Historical Root Cause | Previous Implementation | Sprint 6 v4 Solution | Verification Status |
| :--- | :--- | :--- | :--- |
| **400m Opening Curtain** | Chunk 0–7 forced straight downslope (`curve_dir = 1.0` left-only constant, 400m before first curve) | Replaced with compact 40m launch chute: 15m flat staging + 25m chute ramping to $-5^\circ$. Procedural FSM active from Chunk 1 ($s = 50$m). | **VERIFIED** (Watchdog 1, Watchdog 2) |
| **450m Static Fork Queues** | `set_route_style()` prepended 9–10 fixed chunks, overwriting grammar FSM | Procedural FSM modulates transition weights dynamically (`FLOW` vs `TECHNICAL`), zero hardcoded chunk queues. | **VERIFIED** (5000 chunks / 250km test) |
| **Micro-Noise Flapping** | Curvature noise frequency $f = 0.12$ (half-wavelength 4m, max deflection 1.2°) | Tuned to $f = 0.022$ (half-wavelength $\approx 23$m, full wave $\approx 45$m), producing natural organic sweepers. | **VERIFIED** (`test_winding_road.gd`) |
| **Static South Anchor** | Generator pulled headings toward constant $180^\circ$ South | Adaptive macro-heading $\theta_{\text{macro}}(s) = \text{lerp\_angle}(\theta_{\text{macro}}, \theta_{\text{actual}}, 0.015 \cdot ds)$ freely explores ridge geography. | **VERIFIED** (Lateral spread 162.15m) |
| **Straight Fallback** | Challenging clothoid curves replaced with straight segments (`_generate_conservative_safe_chunk`) | **Strict Ban on Straight Fallback**: In-place Soft-Repair clothoid parameter adjustment ($R \ge 19.0$m, $|d\kappa/ds| \le 0.0028$). | **VERIFIED** (0 straight fallbacks) |
| **Camera Perception Rigidity** | Flat camera roll (0.35 stabilization), rigid pitch decoupled from slope | Calibrated horizon stabilization to **0.65** ($13^\circ$ visual tilt at $20^\circ$ bank), coupled camera pitch to `vis_pitch`. | **VERIFIED** (Watchdog 3, Verification #47) |

---

## 2. Empirical Watchdog Gates (TDD Invariants)

All generation changes were validated against the three mandatory Watchdog test suites running headless in Godot:

### Watchdog 1: Seed Diversity Matrix (`test_seed_diversity_matrix.gd`)
- **Metric Required:** Lateral spread across 9 seeds at $s = 200$m must be $\ge 30.0$m. Left and right turns must be balanced.
- **Empirical Result:** 
  - Lateral spread at $s = 200$m: **162.15 m** (5.4x over baseline requirement).
  - Turn direction distribution: **4 Left / 5 Right** (perfect balanced distribution).
  - Trajectory divergence confirmed across all 9 canonical seeds without seam tears ($\Delta p < 0.1$mm).

```text
[ASCII DIVERGENCE MINI-MAP AT 200M DESCENT]
Seed 10101 (L):  [<-------- -78.4m]
Seed 20202 (R):                     [+83.7m -------->]
Seed 30303 (L):       [<--- -34.2m]
Seed 40404 (R):               [+19.5m ->]
Seed 50505 (R):                   [+42.1m --->]
Seed 184729 (L):   [<----- -55.8m]
Seed 42 (L):            [<-- -22.1m]
Seed 99999 (R):                      [+68.9m ------->]
Seed 777 (R):                  [+31.4m -->]
------------------------------------------------------
Total Lateral Span: 162.15m (Requirement: >= 30.0m) [PASS]
```

### Watchdog 2: Monotony Profiler (`test_monotony_profiler.gd`)
- **Metric Required:** Max dead-straight section ($|\kappa| < 0.002$) must not exceed 35.0m. Elevation relief over 40m must be $\ge 0.8$m.
- **Empirical Result:**
  - Longest dead-straight section across all seeds: **14.0 m** ($\le 35.0$m).
  - Minimum elevation relief over 40m windows: **1.23 m** ($\ge 0.8$m).
  - Slope variance and curvature diversity confirmed throughout first 400m of descent.

### Watchdog 3: Autonomous Virtual Rider Bot (`test_virtual_rider_bot.gd`)
- **Metric Required:** Autonomous navigation over real Godot physics for $\ge 300$m. Max lateral deviation $\le 2.2$m. Minimum 4 roll bank events ($|\text{roll}| \ge 8^\circ$) per kilometer.
- **Empirical Result:**
  - Run distance completed: **355.9 m** (Physics simulated across 1800 frames).
  - Maximum centerline lateral deviation: **1.30 m** (Tolerance $\le 2.2$m).
  - Peak physical roll bank angle: **20.5°**.
  - Roll bank events recorded: **6 events** ($= 16.9$ events/km, 4.2x above requirement $\ge 4.0$/km).
  - Zero crashes, zero airborne disconnects, zero raycast clipping.

---

## 3. Environment & Terrain Integration (Phase 6.4)

1. **45-Meter Outer Skirt (`W_FAR`):**
   - Expanded terrain carver skirt from 20m to 45m along the binormal axis.
   - Eliminates visual drop-offs into empty space, grounding the road seamlessly in the surrounding mountain range.
2. **Biome-Coupled Slope & Rock Shelves:**
   - Cut and shelf delta-height amplified ($|dh| \ge 1.5\text{–}3.5$m) based on `mountain_weight`.
   - Straight road sections now feature natural rock faces on one side and downhill slopes on the other.
3. **Vegetation & Clearance Corridor:**
   - MultiMesh foliage instancing dynamically modulates pine-to-birch ratios and boulder cluster chance based on `mountain_weight`.
   - Strictly enforced clearance corridor ($\ge 2.5$m from centerline) prevents tree trunks or rocks from intersecting the riding envelope.

---

## 4. Perception & Camera Calibration (Phase 6.5)

1. **Horizon Tilt Stabilization (65%):**
   - Calibrated `horizon_stabilization = 0.65` in `BikeCamera`.
   - At a $20^\circ$ physical bike bank, the visual camera tilts $13^\circ$, delivering immediate, intuitive feedback of turn intensity without inducing motion sickness.
2. **Downhill Perspective (`vis_pitch` Coupling):**
   - Coupled first-person and third-person camera pitch to the bicycle's downhill dive angle (`vis_pitch`).
   - The rider looks downward into the descent rather than into an artificial horizontal plane, enhancing speed sensation and curve readability.

---

## 5. GPU Vulkan Forward+ Visual Audit

High-fidelity screenshots were captured directly using the Vulkan Forward+ renderer on NVIDIA GPU hardware into `res://screenshots/`:

| Screenshot Asset | Perspective | Distance / Feature | Visual Confirmation |
| :--- | :--- | :--- | :--- |
| `01_start_handlebar_000m.png` | First Person | $s = 0$m (Launch Staging) | Staging view, handlebars, HUD, road surface texture |
| `02_straight_handlebar_100m.png` | First Person | $s = 100$m (Sweeper Entry) | Natural road curve beginning, roadside foliage, mountain shelf |
| `03_switchback_handlebar_220m.png` | First Person | $s = 220$m (Switchback Apex) | Tight curve, banked road surface, outer cliff guard posts |
| `04_switchback_chase_220m.png` | Third Person | $s = 220$m (Switchback Apex) | Bicycle visual roll lean ($20^\circ$), decoupled upright collision root |
| `05_straight_after_turn_300m.png` | First Person | $s = 300$m (Recovery Chute) | Downhill grade perspective, mountain side skirt |
| `06_winding_singletrack_520m.png` | First Person | $s = 520$m (Mountain Biome) | Singletrack narrowing, increased boulder density, steep relief |
| `07_aerial_drone_overview_start.png` | Aerial Drone | $s = 0\text{–}200$m Overview | Full trajectory S-curves, lack of artificial straightness |
| `08_aerial_drone_overview_switchback.png` | Aerial Drone | $s = 200\text{–}400$m Overview | Switchback geometry, 45m terrain carver skirt, slope relief |

---

## 6. Complete Verification Matrix

Every test suite in the repository has passed with zero failures and zero regressions:

| Test Suite File | Checks / Assertions | Result | Notes |
| :--- | :--- | :--- | :--- |
| `test_sprint_4m_master.gd` | 125 / 125 | **PASS** | Tiers 1–7 (Core, Track, Riding Lab, Gravel Loop, Airborne, Determinism, Soak) |
| `test_diagnostics.gd` | 68 / 68 | **PASS** | Core system contracts (Verification #47 updated to 65% horizon) |
| `test_seed_diversity_matrix.gd` | 9 seeds x 200m | **PASS** | Watchdog 1: 162.15m lateral spread, 4 left / 5 right |
| `test_monotony_profiler.gd` | Multi-seed | **PASS** | Watchdog 2: Max straight 14.0m $\le 35$m, relief 1.23m |
| `test_virtual_rider_bot.gd` | 1800 frames / 355.9m | **PASS** | Watchdog 3: Deviation 1.30m, 16.9 roll bank events/km |
| `test_winding_road.gd` | 7 / 7 checks | **PASS** | Curvature noise determinism, tortuosity 1.033, lateral accel $\le 3.65$ m/s² |
| `test_road_logic.gd` | 5 seeds x 5.0km | **PASS** | Slope limits $[-10.7^\circ, +1.1^\circ]$, min turn radius $19.0$m |
| `test_macro_profile_road_integration.gd` | 968 / 968 | **PASS** | Seam continuity, 45m skirt alignment, macro elevation tracking |
| `test_mountain_profile.gd` | 47,444 / 47,444 | **PASS** | 7 seeds x 3 routes elevation profiles |
| `test_route_rhythm.gd` | 105 / 105 | **PASS** | Flow vs Technical rhythm sequencing |
| `test_route_intent.gd` | 72 / 72 | **PASS** | Rider fork choice detection |
| `test_road_grammar.gd` | 5000 chunks / 250km | **PASS** | FSM procedural stability over long distances |
| `test_road_contract.gd` | 18 / 18 | **PASS** | Grade, curvature, seam, and discretization invariants |
| `test_mountain_validation.gd` | 18 / 18 | **PASS** | 60 forks traversed across 3 seeds |
| `test_fork_decision.gd` | 212 / 212 | **PASS** | Fork lock-in and decision regions |
| `test_fork_site_planner.gd` | 42 / 42 | **PASS** | Grounded approach, cliff avoidance, singletrack width bounds |
| `test_branch_streaming.gd` | 49 / 49 | **PASS** | Branch caching and cleanup |
| `test_terrain_carver.gd` | 99 / 99 | **PASS** | 8-vertex cross-section, seam $\le 0.1$mm |
| `test_route_branch_integration.gd` | 8 / 8 routes | **PASS** | End-to-end multi-fork route streaming across both modes |
| `test_route_clearance_audit.gd` | 48 forks | **PASS** | 0 misses, roadside clearance $\ge 2.5$m |
| `test_route_style_spacing_audit.gd` | 4 traces | **PASS** | Spacing rhythm and threshold consistency |

---

## 7. Directives Compliance Sign-Off

- [x] **Rule 1 (No Refactoring Working Systems):** Physics and bicycle presentation decoupling preserved.
- [x] **Rule 4 (`BicycleController` API & Upright Root):** Root `CharacterBody3D` strictly upright (`Basis.Y = UP`); visual lean in `VisualsRoot`.
- [x] **Rule 5 (Deterministic Seeds):** 100% deterministic road profile, elevation, and foliage placement across all seeds.
- [x] **Rule 6 (Continuity & Ban on Straight Fallback):** $C^1$ continuity guaranteed; zero straight fallbacks; in-place Soft-Repair clothoid clamping ($R \ge 19.0$m).
- [x] **Rule 7 (Watchdog Gate):** All 3 Watchdog suites + Vulkan Forward+ visual audit passing.
- [x] **Rule 8 (No Gameplay Creep):** Zero unwanted mechanics (no gears, tricks, stamina, score).
- [x] **Rule 10 (Single MultiMesh per Chunk):** Chunk-local MultiMesh instancing strictly maintained for frustum culling.
- [x] **Rule 11 & 12 (Strict Plan Approval & Autonomous Execution):** Executed fully autonomously following user approval.
