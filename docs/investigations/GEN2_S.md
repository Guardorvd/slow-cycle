# GEN2-S — surface block prototype (record)

STATUS: IMPLEMENTING (S1, S3 done; S2 headless checks done, Vulkan captures pending on the Director's machine; S4 ride next). Plan: [GEN2_SURFACE_PLAN.md](../generator-v2/GEN2_SURFACE_PLAN.md), approved by the Game Director 2026-10-17. Branch `gen2-s-surface-block` on master `92e01e1`. Dev-only: the production bake, caches, runtime and player are unchanged.

## S1 — block data and operations (2026-10-17)

Code: `scripts/world/surface/surface_ops.gd` (one operation list over the design FinalSurface: road plane > PLATFORM > BENCH > TRAIL), `scripts/world/surface/surface_block.gd` (128 m block, 0.5 m grid, 257 x 257 heights + cover, SHA-256 digest), `tools/dev/surface_block_probe.gd`.

Command: `G --headless --path . --script res://tools/dev/surface_block_probe.gd -- --seed=184729 --region=0,0` (BC1 trail config, blocks 17..19 x 21..23, 4 threads). Evidence: [gen2-s/s1_summary_184729.json](../generator-v2/gen2-s/s1_summary_184729.json), [map](../generator-v2/gen2-s/s1_map_184729.png).

Window 384 x 384 m: valley road, junction 4, BC1 trail (NATURAL with its BENCH) and one SHAPED platform (r 3.5 m + taper 3 m) at the sharpest bend outside the bench, (2229.5, 3000.0) — only a 10 degree bend on this gentle trail.

| Check | Result |
|---|---|
| determinism (4 threads vs 1) | PASS, equal digests |
| seams (12 shared edges) | PASS, 0 mismatched samples |
| composition (53 404 samples off operations / on road) | PASS, max 0.0 m |
| incremental (platform moved 4 m) | PASS: 1 block rebuilt in 4.7 s, equals a full rebuild |
| grid error at cell centres, trail limit 0.02 m (preliminary) | **FAIL**: trail band edge at the bench crease 0.035 m (p99 0.035), trail end at the road shoulder 0.055 m; bench interior 0.013, platform 0.006, plain trail p99 0.0001. Road shoulder 0.127 m (p99 0.095), grass max 0.06 (p99 0.006) |

Cause of the grid error: creases (bench daylight edge, road shoulder) not aligned to a regular 0.5 m grid are smoothed by bilinear interpolation; the current tiles put vertices on these edges. Render and collision of a block come from the same grid, so this is a difference from the analytic design surface, not a render/collision mismatch. Game Director decision 2026-10-17 (card "Оставить"): the softened creases are accepted; the preliminary 0.02 m limit is withdrawn and the grid error is reported only; the ride judges the edges.

Cost (Linux, GDScript kernel): 4.7 s per block on one thread (≈ 72 us per sample; natural ground 39–47 us, road deformer +16–120 us near roads), 27 s for 9 blocks on 4 threads. Per 512 m of area that is ≈ 75 s of thread time against ≈ 13 s for today's tile build — a uniform 0.5 m grid everywhere is slower for a full bake; it pays only as local detail (near the rider and the operations) with a coarse grid elsewhere, and with the C# kernel (12x per natural sample, PERF_FIRST) on the Director's build. A changed trail costs 4.7 s (1 block) against 12–17 s per 512 m tile today.

## S2 — render, collision, cover (2026-10-17)

Code: `scripts/world/surface_block_streamer.gd` (adapter: one mesh per block with the bake's terrain shader; HeightMapShape3D per block on the terrain layer; road / trail cells as ConcavePolygonShape3D strips on their layers, heightfield sunk 0.3 m under strip interiors; cells split on the same diagonal as HeightMapShape3D — measured), `scripts/world/surface/surface_section.gd` (shared setup), `tools/dev/surface_block_ride.gd` (section in the region world scene, same bicycle, camera, light; recovery to the trail at the section edge).

Cover without changing the bicycle: holes in HeightMapShape3D (NaN) were tried first and rejected — the ray misses the four cells around the sample and the physics server warns on every query. The strip method keeps the bicycle's existing rule (collision layer under the wheel).

Headless check (`--check`, Linux): the bike placed on trail, platform, road and grass, 90 physics frames each — wheel layers 18 / 18 / 2 / 4 as expected, no drift, rests on the ground; pedal 3 s on the trail: moved 3.9 m on layer 18. PASS. Time to ride 37 s in a fresh process (ground stage load 9.3 s, 9 blocks 24.9 s on 4 threads, nodes 2.7 s).

## S3 — vegetation in two steps (2026-10-17)

Code: `scripts/world/surface/surface_block_vegetation.gd` (candidates from the natural fields with the RegionVegetationPlanner rules and seeded hash, no roads / trails / heights; placement on the final blocks: clearance from road / trail / platform cover, the planner's distances, centre + 8 points; height from the block), streamer `add_flora` (same meshes, ranges, colliders as RegionStreamer). Evidence: same summary JSON (vegetation checks), [map with vegetation](../generator-v2/gen2-s/s3_map_184729.png).

| Check | Result |
|---|---|
| determinism (4 threads vs 1, candidates and placement) | PASS |
| clear of the riding band, platform and road planes (independent: realized trail lines + design road owner, trunk / rock radius) | PASS, 1365 checked, 0 violations |
| incremental (platform moved 4 m; candidates reused, 1 block re-placed) | PASS, equal to a full re-placement, 0.02 s |
| against today's planner tile (trails surface), window only | REPORTED: 1364 of 1365 at the same positions, 1 only here, 3 only in the planner (clearance checked on the 0.5 m cover instead of exact distance); heights differ up to 0.026 m (block grid vs tile triangles) |

Cost: candidates 0.63 s + placement 0.02 s for the 9 blocks (4 threads); the planner's tile for the same ground 2.5 s. A trail change re-places vegetation in 0.02 s, against 17–19 s for the 3 x 3 tile ring in GEN2-1's exact mode. The ride check with vegetation: PASS (same places; 1365 plants, 1286 trunk / rock colliders); ready to ride in 41.8 s (blocks 28.4 s).

## NOT RUN

- Windows / C# kernel timings; other seeds; a real switchback (BC1 has no sharp turn).
- Vulkan captures (no GPU here; requested on the Director's machine); a human ride.
