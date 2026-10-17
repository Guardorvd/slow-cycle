# GEN2-S — surface block prototype (record)

STATUS: IMPLEMENTING (S1 done, S2 next). Plan: [GEN2_SURFACE_PLAN.md](../generator-v2/GEN2_SURFACE_PLAN.md), approved by the Game Director 2026-10-17. Branch `gen2-s-surface-block` on master `92e01e1`. Dev-only: the production bake, caches, runtime and player are unchanged.

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

Cause of the grid error: creases (bench daylight edge, road shoulder) not aligned to a regular 0.5 m grid are smoothed by bilinear interpolation; the current tiles put vertices on these edges. Render and collision of a block come from the same grid, so this is a difference from the analytic design surface, not a render/collision mismatch. Threshold not changed; decision asked of the Director.

Cost (Linux, GDScript kernel): 4.7 s per block on one thread (≈ 72 us per sample; natural ground 39–47 us, road deformer +16–120 us near roads), 27 s for 9 blocks on 4 threads. Per 512 m of area that is ≈ 75 s of thread time against ≈ 13 s for today's tile build — a uniform 0.5 m grid everywhere is slower for a full bake; it pays only as local detail (near the rider and the operations) with a coarse grid elsewhere, and with the C# kernel (12x per natural sample, PERF_FIRST) on the Director's build. A changed trail costs 4.7 s (1 block) against 12–17 s per 512 m tile today.

## NOT RUN

- Windows / C# kernel timings; other seeds; a real switchback (BC1 has no sharp turn).
