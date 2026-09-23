# Slow Cycle — System Architecture

## 1. High-Level System Hierarchy

```text
Main Game Scene (res://scenes/main.tscn)
│
├── WorldManager (Seed, Chunk streaming coordinator)
│    ├── RoadPathData (Core spline & surface state data contract)
│    ├── RoadGenerationContract (Mathematical envelopes, derivatives by Δs, seam limits)
│    ├── RoadAirborneContract (SurfaceContactMode FSM: GROUNDED, MICRO_DROP, AIRBORNE, LANDING)
│    ├── RoadValidityValidator (Algorithmic C0/C1, curvature, slope & sight distance inspector)
│    ├── RoadLogic / [Planned Phase 2] RoadGrammar (Deterministic MTB descent pacing & FSM)
│    ├── ChunkStreamer (Active chunk window [N-1 ... N+5])
│    └── [Active RoadChunks]
│          ├── RoadMesh (ArrayMesh: gravel road with micro-texture)
│          ├── RoadCollision (Concave CollisionShape3D on Layer 2 "Road" / Layer 5 "RoughRoad")
│          ├── StripTerrain (Roadside shoulders, verges on Layer 3 "Grass")
│          └── ChunkFoliage (Local MultiMeshInstance3D for pines, birches, grass)
│
├── Bicycle (CharacterBody3D, layer "Player", bit 8; collision mask 7)
│    ├── 2-Point Raycast Suspension (Pitch calculation, mask 22 = Road | Grass | RoughRoad)
│    ├── Kinematic Model (Lean-to-Steer, slope gravity, coasting, banking)
│    ├── VisualsRoot (Decoupled Node3D: visual pitch, banking, dive, suspension compliance)
│    ├── HandlebarCockpit (Mesh, grips, bell, steering pivot)
│    ├── CameraRig (Stabilized 1st-person & 3rd-person spring-arm with 35% VOR limit)
│    └── AudioController (Procedural bell, freewheel ratchet, wind, gravel, skid)
│
├── UI Layer (CanvasLayer)
│    ├── MinimalHUD (Speed km/h, distance traveled)
│    ├── DebugHUD (F3 toggle: Seed, Chunk ID, FPS, Slope, Curvature, Memory)
│    ├── ModeSelect (Start screen: Zen Endless Road vs Riding Feel Test Track)
│    └── [Planned] PauseMenu & MainMenu (Sprint 7: Esc overlay, settings, persistence)
│
└── [Planned] Autoloads
     ├── GameState (Sprint 6: enum RIDING/PAUSED/PHOTO_MODE)
     └── SettingsManager (Sprint 7: ConfigFile persistence)
```

---

## 2. Collision Layer Structure

| Layer | Mask Bit | Name | Purpose |
|---|---|---|---|
| 1 | 1 | Default | Static environment & default collisions |
| 2 | 2 | Road | Packed gravel road surface (rolling res: 0.125) |
| 3 | 4 | Grass | Soft grass verges & off-road runoffs (rolling res: 0.45) |
| 4 | 8 | Player | Bicycle CharacterBody3D kinematic collider |
| 5 | 16 | RoughRoad | Stony / washboard rough gravel sections (rolling res: 0.22) |

---

## 3. Communication Rules (Zero Spaghetti)

1. **WorldManager $\rightarrow$ RoadChunks**:
   - `WorldManager` owns the `WorldSeed` and computes global road segment data (`RoadSegmentData`).
   - `RoadChunk` is a dumb renderer: it receives mathematical slice parameters and generates its local `ArrayMesh`, `CollisionShape3D`, roadside strip terrain, and local `MultiMesh` trees. It never invents world data independently.
2. **Bicycle $\rightarrow$ World**:
   - The bicycle is completely agnostic to how the road was made.
   - It queries physics raycasts against Layer 2 (`Road`), Layer 3 (`Grass`), and Layer 5 (`RoughRoad`) with collision mask 22 (`2 | 4 | 16`).
3. **Bicycle $\rightarrow$ Presentation Decoupling**:
   - The root `CharacterBody3D` stays strictly upright in world space (`Basis.Y = (0, 1, 0)`), handling only horizontal translation, slope velocity, and yaw rotation.
   - All visual lean (`current_bank`), terrain slope smoothing (`visual_pitch`), braking dive (`brake_dive_pitch`), and vertical compliance (`suspension_compression`) are isolated inside `VisualsRoot`.
4. **Bicycle $\rightarrow$ UI & Audio**:
   - The bicycle emits clean typed signals:
     - `telemetry_updated(speed_kmh: float, cadence_pct: float, is_coasting: bool)`
     - `bell_rung()`
   - UI (`HUD`, `DebugHUD`) and Audio (`BikeAudioManager`) listen to these signals passively without modifying bicycle state.
