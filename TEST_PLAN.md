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

## 3. Developer Debug HUD (F3 Key)
A developer overlay displaying live generation telemetry:

```text
=== SLOW CYCLE DEBUG ===
Seed: 10101 | Chunk: #14 (Total generated: 42)
Active Chunks in Tree: 7
Speed: 23.4 km/h | Slope: -3.2° (Downhill) | Curve Radius: 58.2m
FPS: 84 | Frame Time: 11.9ms | Chunk Gen Time: 0.8ms
Memory: Static 48MB | VRAM 182MB
Road: CONTINUOUS [OK] | Raycasts: GROUNDED [OK]
========================
```
