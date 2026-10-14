---
name: slow-cycle-worldgen
description: Design or implement Slow Cycle world generation, route/road/surface ownership and seed contracts. Excludes player, UI, governance-only tasks and verification-only work.
---

# World generation

Use for generation design/implementation/migration, terrain/hydrology/biomes, route/road synthesis, surface/placement ownership or seed/spatial identity contracts. Do not activate only because a prose report mentions world; player/camera/UI/audio-only, governance-only and verification-only work use their own workflow.

1. Read root/world AGENTS and relevant architecture/migration/Blueprint sections. For another task, read only the active-plan header before the first `---` (max 12 lines); no whole-file reads/searches. Read its full plan only for that approved task's execution. A new phase/subsystem/architectural change uses a compact ExecPlan and STOPs until approved; a small feature or a sprint inside an approved phase uses a sprint card (`.agent/PLANS.md`). This skill grants no implementation permission.
2. Enforce **WORLD FIRST → ROUTE SECOND → ROAD THIRD**. World-space geography precedes roads; road-relative samples and renderer state do not own the world.
3. Use a deterministic effective seed/configuration/stable identity with explicit local seed derivation; no global RNG, time, allocation IDs or materialization-order dependence. Record a chosen session seed before generation. Exact hash/salt schemas belong to the approved domain task, not this skill.
4. Keep pure planning data independent of scene tree, Nodes, mesh instances and physics objects. Name one owner/lifetime per state; public contracts flow domain → adapter with no circular dependencies or cross-system mutable arrays.
5. Route planner consumes world information; road synthesis consumes RouteCorridor; runtime render/collision/vegetation/water/world-query consumers eventually consume FinalSurface. These are target responsibilities: do not invent their schemas or claim them implemented because their names exist.
6. Local road coordinates are valid for road geometry/deformation with an explicit world-space boundary. No road-relative ownership of geography/biomes/ecology and no renderer-owned world state. Do not adjust player physics/camera/controls to hide worldgen defects.
7. Distinguish legacy from target and phase order: RoadGraph DAG, RoutePlan-from-road, road-relative TerrainCarver and chunk streamer are not regional owners by name or RefCounted type. Fundamentally wrong ownership calls for isolated approved replacement; do not require later landmarks/vistas before their phase or jump Q/R phases.
8. Report diagnosed REJECT / REPLAN / DEGRADE_EXPLICITLY / FAIL with reasons, without hidden fallback/object deletion. Iterate with FAST (parse + directly related fast tests), then PLAYTEST in a ready region with 3–5 placement captures and a launch command for the Director ([Test Strategy §0](../../../docs/TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)); fix critical defects first, log the rest in the short backlog. Escalate to DEEP (G gates, seeds, holdout, `slow-cycle-verify`, independent `slow-cycle-review`) only on a Director decision, a named confirmed risk (nondeterminism, corrupt cache/data, changed shared contract) or a release milestone. Preserve scoped legacy geometry limits.
