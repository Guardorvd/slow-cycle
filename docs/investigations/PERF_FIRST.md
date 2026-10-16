# Performance First: dev bake and cold-bake acceleration

STATUS: RECORD (2026-10-15). Branch `perf-first` (from `bc2-stabilization-perf` `ab5083f`), merged to master 2026-10-16 (Director decision card «Влить»); sprint closed. Director sprint "Slow Cycle — PERFORMANCE FIRST".

## Conditions

Linux container, 4 cores, Godot 4.7.2 official builds: baseline = old code (`ab5083f`, worktree) on the standard build; candidate = this branch on the .NET build (same engine version) with the C# kernel built (`dotnet build SlowCycle.csproj`). 4 bake threads, one bake at a time, cold (no stage or product cache). One run per cell; run-to-run noise on this machine is about ±5 % (two identical dev bakes: 300 s and 308 s). Old and new code timed on the same machine in the same session.

## Results

| seed / region | run | total s | network | deformer | tiles | trails | vegetation | network / tiles / vegetation digests |
|---|---|---|---|---|---|---|---|---|
| 184729 (0,0) | baseline `ab5083f` | 470.6 | 142.7 | 8.6 | 143.6 | 78.1 | 95.6 | `5b85df16` / `fb2dc758` / `7a9f336c` |
| | neutral changes (old stop rule) | 285.3 (−39 %) | 108.7 | 7.4 | 76.9 | 61.4 | 24.5 | identical |
| | + ROADS stop rule (candidate) | 246.4 (−48 %) | 62.0 | 8.6 | 79.3 | 64.1 | 24.6 | network data identical except the model tag (`aa564a9a`); tiles, vegetation identical |
| 3628391 (3,−2) | baseline `ab5083f` | 790.6 | 413.6 | 4.9 | 227.6 | 47.3 | 95.3 | `4809c0e2` / `4e48f989` / `70b9b36a` |
| | neutral changes (old stop rule) | 553.5 (−30 %) | 347.2 | 5.1 | 132.9 | 38.6 | 26.0 | identical |
| | + ROADS stop rule (candidate) | 571.2 (−28 %) | 356.4 | 4.6 | 135.0 | 42.4 | 27.6 | network data identical except the model tag (`875ace7c`); tiles, vegetation identical (all rounds still run: noise vs the row above) |

Totals of the new runs include stage save (≈ 2 s) and key computation (≈ 0.3 s); the baseline total is `RegionBake.bake` wall time.

Published result, every run of a seed: 184729 — roads BACKBONE 7 / SECONDARY 5, 9.39 km, 3 road loops, trails TECHNICAL 2 + SINGLETRACK 2 (same ids, lengths), trail graph strongly connected; 3628391 — roads BACKBONE 7 / SECONDARY 2, 7.44 km (R7 drops `edge:9`, ford channel), TECHNICAL 2 (349 m, 276 m). Nothing about the published world changed, so no FPS, memory or collision difference is possible from these changes (same arrays, same instances).

### Dev iteration (184729, stage reuse, `tools/dev/dev_bake.gd`)

| change | stages | wall s |
|---|---|---|
| vegetation planner (or bridges, water, spawn, manifest) | ground + trails reused, finish rebuilt | 41–43 |
| trail planning / publication (`--rebuild=trails` or a trail-closure source change) | ground reused, trails + finish rebuilt | 111 (before the trail refinement work; trails 72 → 61 s since) |
| anything in the ground closure (R0–R7, tiles, renderer) | full | = cold bake |

Baseline for every change: a full cold bake (470.6 s).

## What changed (C: removed or cheaper work)

1. **Stage reuse for development** (`RegionBakeGround`, `RegionBakeTrails`, `RegionStageCache`, `tools/dev/dev_bake.gd`). RegionBake split into ground (R5/R6/R7 + tiles), trails (BC2 planning + publication) and finish (bridges, water, vegetation, spawn, manifest) stages with identical products. Each stage is keyed by SHA-256 of its source closure (every file the stage entry can reach through preload / load / res:// literals / global class names, comments ignored, plus `project.godot`), seed, region, options, and for trails the ground key and trail configuration digest. Loading re-checks file hash, identity, current upstream signatures, network digest and every tile hash; anything else is a refusal and the stage is rebuilt (FAST test P3). Dev products go to `user://regions_dev/` with a `dev_stage_reuse` manifest marker; the production loader refuses marked products and the dev loader refuses unmarked ones (P4). The runtime reads them only with `--dev-cache`. `tools/dev/fast_trail.gd` stays as it was (it remains the fastest trail-only probe; the stage cache is the general path).
2. **C# terrain height kernel** (`MacroTerrainKernel.cs`, used by `MacroTerrainEvaluator` when the .NET build and the built assembly are present; otherwise the GDScript kernel). Exact port: float32 rounding wherever Godot uses Vector2/Vector3, Godot's MIN/MAX/CLAMP/LERP definitions. Parity: 300 000 points over 184729, 2024, 3628391, both noise modes, 0 mismatches (`tools/dev/kernel_parity.gd`; FAST P5 checks 6 000). 4.3 µs vs 51.7 µs per sample. Every terrain height query of every stage gets cheaper: tiles −45 %, vegetation −74 %, R5 rounds −10 to −38 %.
3. **R6 edge dispatch order**: the edge job pool starts the heaviest jobs first (class, then band length); completion order unchanged, so outcomes are identical. Removes the long-pole wait of one heavy edge started last (184729 round edges 13.5 → 11.4 s).
4. **Vegetation rock prefilter**: a rock whose keep roll is above the largest possible keep threshold (0.54) is rejected before its environment query (exact).
5. **Trail tile refinement**: exact allocation-free band test (`FinalSurface.trail_inside`, same candidates and arithmetic as `trail_near`), per-vertex band state in the clipping pass, a block prefilter before triangle–trail gap queries, largest tiles first, and seam passes reuse a tile whose border points did not change (no effect on 184729, where every refined tile receives new border points). Trail stage 72 → 61 s on 184729.
6. **Network replan stop rule ROADS** (candidate, the one product-affecting change, see below).

Rejected or not pursued: seam-pass reuse gives no gain on 184729 (kept, exact and cheap); deeper renderer work (LEPP splitting itself ≈ 4 s per heavy tile) — diminishing returns; persistent signal memo for vegetation — not needed after the kernel (vegetation 26 s).

## Part 2: the cause of the R5/R6 cost

Measured (B1 counters, this branch):

- `complete()` demanded READY SINGLETRACK and TECHNICAL road edges. R6 practically never makes them READY (no chosen production network has one; natural classes are BC2 trails, roadmap T4), so every region ran all three R5/R6 rounds. On 184729 the third round (≈ 50 s) is never chosen.
- **ROADS stop rule** (default on this branch): the rounds end at the first road network meeting N1–N6 without natural road classes (continuous backbone, ≥ 8 km, ≥ 2 loops, SECONDARY, no blocked node, no stray dead end). The old rule stays available as `stop_rule = ALL_CLASSES` (`--stop-rule=ALL_CLASSES` in the dev tools) for comparison. Effect: 184729 stops after round 1, the round the old rule chose anyway: same network, −47 s. 3628391: only round 2 meets N1–N6, so all rounds still run: same result, no gain. 2024: no round has a continuous backbone (N-7), unchanged.
- Remaining cost on 3628391 / 2024: R6 design of natural edges that fail (≈ 70–100 s of R6 per round on 3628391). Removing it changes the layout feedback (the earlier R6_ENGINEERED experiment re-rolled 184729 and lost two trails), so it is a restructuring of R5 → R6 → BC2 interaction: proposed as ExecPlan PERF-P2 in [implementation_plan.md](../../implementation_plan.md), not implemented.

## PERF-P2 result

Approved 2026-10-16, implemented on branch `perf-p2-experiment`, **not adopted** (plan S3). One seed baked, by Director instruction: 184729 (0,0), cold, same machine.

| 184729 | total s | network s | trails s | roads | road loops | trails |
|---|---|---|---|---|---|---|
| `perf-first` (ROADS) | 246.4 | 62.0 | 64.1 | BB 7 / SEC 5, 9.39 km | 3 | TECHNICAL 2 + SINGLETRACK 2 |
| PERF-P2 | 239.9 | 89.6 | 36.9 | BB 10 / SEC 4, 8.85 km | 3 | TECHNICAL 1 + SINGLETRACK 1 (trail graph strongly connected) |

- Without R6's natural-edge designs the round hints change, round 1 no longer reaches 8 km, a third round runs and the chosen layout is the one the R6_ENGINEERED experiment produced. No time gain on 184729 (natural designs were cheap there; the extra round eats the saving).
- No R5 intent became a trail: the three natural routes (1.1–2.4 km) end at natural-only junctions away from the roads; the TECHNICAL corridor passes no road port within 160 m, the SINGLETRACK ones have road ports only near one end. Intents as R5 plans them are not trail-shaped.
- So the coupling, not the cost, decides: the R6 natural designs on 184729 matter only through the hints they feed. A future road model change (BC3 D4) would need R5 itself to plan natural routes as road-to-road stretches; not attempted here.

## How to use

- Once per checkout on the .NET build: `dotnet build SlowCycle.csproj` (Godot.NET.Sdk 4.7.2 from NuGet). Without it everything works on the GDScript kernel with identical results, only slower; the manifest records `terrain_kernel`.
- Production launch (unchanged): `<Godot 4.7.2 mono console> --path <repo> res://scenes/region/region_world.tscn -- --seed=184729`. First launch bakes cold and caches as before.
- Dev loop: `<godot> --headless --path <repo> --script res://tools/dev/dev_bake.gd -- --seed=184729 --region=0,0`, then launch with `-- --seed=184729 --dev-cache` (production cache first, then the dev cache; the overlay says which). `--rebuild=ground|trails` forces a stage; `--stop-rule=ALL_CLASSES` compares with the old rule (not saved as final products).
- Cold bake with timings: `tools/dev/bake_region.gd -- --seed=S --region=X,Z [--no-save] [--out=ABS.json]`. Kernel parity: `tools/dev/kernel_parity.gd` (.NET build).

## Not run

L2/L3, VERIFY/REVIEW, long rides, thread-count determinism (1 vs N), Windows timing, 2024 bake on this branch (by construction unchanged: no round completes, both rules run every round), repeat runs per cell. Runtime FPS/memory not measured (products identical).
