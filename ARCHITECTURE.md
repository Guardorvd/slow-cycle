# Slow Cycle — System Architecture

## 1. High-Level System Hierarchy

```text
Main Game Scene (res://scenes/main.tscn)
│
├── WorldManager (Seed, Chunk streaming coordinator)
│    ├── RoadGenerator (Deterministic spline math & mood logic)
│    ├── ChunkStreamer (Active chunk window [N-1 ... N+5])
│    ├── [Active RoadChunks]
│    │     ├── RoadMesh (ArrayMesh: asphalt + stripes)
│    │     ├── RoadCollision (Concave/Convex CollisionShape3D on layer "Road")
│    │     ├── StripTerrain (Roadside shoulders, verges, embankments)
│    │     └── ChunkFoliage (Local MultiMeshInstance3D for pines, birches, grass)
│    └── [Planned] DayNightCycle (Sprint 4A: sun rotation, sky gradients, fog)
│
├── Bicycle (CharacterBody3D, layer "Player", masks "Road" & "Default")
│    ├── 2-Point Raycast Suspension (Pitch calculation & ground adhesion)
│    ├── Kinematic Model (Lean-to-Steer, slope gravity, coasting, banking)
│    ├── HandlebarCockpit (Mesh, grips, bell, steering pivot)
│    ├── CameraRig (Stabilized 1st-person & 3rd-person spring-arm)
│    ├── AudioController (Procedural bell, freewheel ratchet, wind, gravel)
│    └── [Planned] Headlight SpotLight3D (Sprint 4A: auto-on at dusk)
│
├── UI Layer (CanvasLayer)
│    ├── MinimalHUD (Speed km/h, distance traveled)
│    ├── DebugHUD (F3 toggle: Seed, Chunk ID, FPS, Slope, Curvature, Memory)
│    ├── [Planned] PauseMenu (Sprint 4B: Esc overlay with settings)
│    └── [Planned] MainMenu (Sprint 4B: title screen with seed selection)
│
└── [Planned] Autoloads
     ├── GameState (Sprint 4A: enum RIDING/PAUSED/PHOTO_MODE)
     └── SettingsManager (Sprint 4B: ConfigFile persistence)
```

---

## 2. Communication Rules (Zero Spaghetti)

1. **WorldManager $\rightarrow$ RoadChunks**:
   - `WorldManager` owns the `WorldSeed` and computes global road segment data (`RoadSegmentData`).
   - `RoadChunk` is a dumb renderer: it receives mathematical slice parameters and generates its local `ArrayMesh`, `CollisionShape3D`, roadside strip terrain, and local `MultiMesh` trees. It never invents world data independently.
2. **Bicycle $\rightarrow$ World**:
   - The bicycle is completely agnostic to how the road was made.
   - It only queries physics raycasts against Collision Layer 2 (`Road`).
3. **Bicycle $\rightarrow$ UI & Audio**:
   - The bicycle emits clean typed signals (`speed_changed(kmh)`, `coasting_state(is_coasting)`, `bell_rung`).
   - UI and Audio listen to these signals passively without modifying bicycle state.
