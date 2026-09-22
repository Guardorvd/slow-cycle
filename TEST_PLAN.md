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
Automated CI checks run headlessly using Godot console:

```powershell
& "Godot_v4.7.2-stable_mono_win64_console.exe" --headless --script scripts/test/test_diagnostics.gd
& "Godot_v4.7.2-stable_mono_win64_console.exe" --headless --script scripts/test/test_track_verification.gd
& "Godot_v4.7.2-stable_mono_win64_console.exe" --headless --script scripts/test/test_track_ride.gd
```

- **Core Contracts**: 59 deterministic verifications in `test_diagnostics.gd` (100% PASS requirement).
- **Leak Gate**: Zero ObjectDB leaks on exit (`WARNING: 0 ObjectDB instances leaked`).

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
