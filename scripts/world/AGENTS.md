# World — domain and runtime boundaries

These instructions specialize the root protocol; they do not authorize a phase or player/test change.

- Keep planning/math in pure data or RefCounted where possible, without scene-tree access, Nodes, renderer state or collision objects in planning results. A RefCounted label alone does not establish purity or thread safety.
- Domain results flow to Godot adapters through public inputs/outputs/queries. Name one owner for each state/lifetime; no circular dependencies or cross-system shared mutable arrays. WorldManager composes systems rather than owning their generation math.
- Workers may prepare math, plans and arrays; main thread owns scene-tree/physics registration and runtime commit. Add threading only after a measured stall and an approved scope; specify synchronization for shared state.
- World systems consume public player telemetry/query/collision boundaries. Do not change BicycleController, camera, controls or physics to mask world geometry/collision defects.
- Use effective seed/configuration plus stable identity/world coordinates for explicit local seed derivation. No global RNG, time or allocation/materialization-order keys in generation. Session seed selection is a recorded runtime boundary before generation.
- Target geography/biomes/placement have world-space ownership. Local road coordinates are valid for road geometry/deformation with an explicit world-space boundary, not ownership of the entire world.
- Load `slow-cycle-worldgen` for generation design/implementation. Legacy RoadGraph DAG, RoutePlan-from-road and TerrainCarver are as-is systems, not implemented regional owners. A fundamentally wrong owner is replaced in an isolated approved migration, not patched with exceptions; do not invent future schemas here.

## Retained legacy road guard

- C1 continuity is mandatory; C2 is desirable where applicable. Wheel raycasts must not hide tears, normal flips or height steps.
- Straight fallback (`_generate_conservative_safe_chunk`) remains prohibited by the current requirement. Smooth Soft-Repair/clothoid adjustment preserves curve intent with R ≥ 19.0 m. Fatal fallback is permitted only for seam Δp > 1 mm or NaN/Inf, with mandatory `[GEOM]` logging.
- Observed code radius 18 m, broader fallback and landing mismatches remain unresolved legacy findings. Do not change limits, tests or code under a documentation task, or impose these legacy numbers as newly designed regional schemas.

## Retained generation and locality gates

- Each world feature gets FAST (zero parse errors in changed scripts + directly related fast tests) and a PLAYTEST in a ready region ([Test Strategy §0](../../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)). Pure math tests alone never certify runtime generation; a placement screenshot is not a ride check.
- Gate G = `test_seed_diversity_matrix`, `test_monotony_profiler`, `test_virtual_rider_bot` on real physics and Vulkan `capture_visual_audit.gd`, run unchanged through Q1. G is a **DEEP** check: it runs when a DEEP campaign is scheduled (Director decision, confirmed risk such as nondeterminism or corrupt data in generation, release milestone, L3), on changes reaching the legacy runtime generation closure ([Test Strategy §7.1](../../docs/TEST_STRATEGY.md)). G not run is recorded as NOT RUN in the backlog, never as PASS.
- Changing gate content or assertions needs explicit approval; never silently waive/reclassify. Markdown-only validation is not runtime or generation PASS.
- Preserve current chunk/type-local MultiMesh culling until approved migration; never combine infinite foliage into one monolithic MultiMesh. The target partition is spatial cell + type in [target architecture](../../docs/TARGET_ARCHITECTURE.md).
