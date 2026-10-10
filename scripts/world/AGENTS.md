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

- Verify each feature in Godot with headless and runtime checks: zero parse errors and zero leak warnings. Gate G = `test_seed_diversity_matrix`, `test_monotony_profiler`, `test_virtual_rider_bot` on real physics and Vulkan `capture_visual_audit.gd`, run unchanged through Q1. G is required at L2 for every change reaching the legacy runtime generation closure and at every L3 checkpoint ([Test Strategy §7](../../docs/TEST_STRATEGY.md)). Pure-domain or isolated-preview code with a recorded zero-reference audit does not trigger G per change; an inconclusive audit counts as reaching it. Pure math tests alone never certify runtime generation.
- Task-specific domain/negative checks supplement G. Changing gate content, assertions or applicability beyond this rule needs an explicit approved amendment; never silently waive/reclassify. Markdown-only validation is not runtime or generation PASS.
- Preserve current chunk/type-local MultiMesh culling until approved migration; never combine infinite foliage into one monolithic MultiMesh. The target partition is spatial cell + type in [target architecture](../../docs/TARGET_ARCHITECTURE.md).
