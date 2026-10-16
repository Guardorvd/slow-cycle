# GEN2-1 — single-trail tool and stage cost (record)

STATUS: IMPLEMENTED, awaiting the Director's check of the tool (2026-10-16). Branch `gen2-1-trail-tool` on master `d2ad73f`. Plan: Generator V2 plan GEN2-1 (project files `generator-v2/GENERATOR_V2_PLAN.md`), approved with the Director's clarifications of 2026-10-16 (existing publication mechanism first, preview and exact with different criteria, exact compared with a full publication of the same trail set, success and refusal checks, V1 snapshot kept locally).

## What changed

- `scripts/world/region/region_bake_trails.gd`: `report.publication` — counters and wall-clock seconds of every publication attempt (shape, tile refinement with seam passes, finalize, network join, trap check). Measurement only: the cold bake below produced the same network, tile and vegetation digests as V1.
- `tools/dev/trail_probe.gd` (new dev tool, never a production path), on the ground stage of `RegionStageCache` (built and stored once when missing):
  - `--mode=planner` lists the V1 planner's proposals; `--pick=` writes their BC1 configurations;
  - `--mode=preview` — line, profile (height, grade, side slope, radius, road/water flags), planned operations and a top-down map on the design surface; screening only, publishes nothing, not a ride check;
  - `--mode=exact` — the existing publication (`RegionBakeTrails.publish`) on the cached ground, tiles outside the dependency set must keep their off arrays, products saved to the dev cache under the runtime key of the configuration, launch command printed; `--verify-full` runs a cold full bake with the same configuration and compares digests;
  - `--mode=check` — suitable examples must publish, unsuitable variants must be refused with the expected reason and stage, tiles unchanged;
  - `--mode=slopes` — candidate hillside tops by drop band with straight-line measures (data for choosing the GEN2-2 slope, not a feasibility check).
- One addition beyond the existing publication, with its dependency: `RegionBake.finish` plans vegetation for all 64 tiles (122–141 s here), which alone would put every exact run above two minutes. Exact therefore keeps the off vegetation of the same ground (computed once, ~125 s, stored under `user://trail_probe/off_vegetation/` keyed by the ground key and the vegetation planner's source closure) and plans the changed tiles and their 8 neighbours again — the method `fast_trail.gd` already used. Equality with the full path is checked by `--verify-full`.

## Commands

`G` = the Godot 4.7.2 console binary (Windows: `Godot_v4.7.2-stable_mono_win64_console.exe`), run from the checkout (`--path .`). Outputs go to `user://trail_probe/<name>/` (summary JSON, profile CSV, PNG map); the first run on a seed builds and stores its ground stage (a cold R5–R7 + tiles run, minutes), later runs reuse it.

```
G --headless --path . --script res://tools/dev/trail_probe.gd -- --seed=184729 --region=0,0 --mode=planner --pick=selected --name=v1_selected
G --headless --path . --script res://tools/dev/trail_probe.gd -- --seed=184729 --region=0,0 --mode=preview --config=res://resources/regions/bc1_trail_184729.json
G --headless --path . --script res://tools/dev/trail_probe.gd -- --seed=184729 --region=0,0 --mode=exact --config=res://resources/regions/bc1_trail_184729.json [--verify-full]
G --path . --script res://tools/dev/ride_trail.gd -- --seed=184729 --region=0,0 --trail-config=res://resources/regions/bc1_trail_184729.json --dev-cache --trail=trail:bc1_meadow
G --headless --path . --script res://tools/dev/trail_probe.gd -- --seed=184729 --region=0,0 --mode=check
G --headless --path . --script res://tools/dev/trail_probe.gd -- --seed=184729 --region=0,0 --mode=slopes
```

The ride command is printed by exact (`PROBE_LAUNCH`) with the configuration it published; `--config=` accepts `user://` paths (the planner writes `user://trail_probe/<name>.json`).

## Measurements (Linux, 4 vCPU Xeon 2.8 GHz, Godot 4.7.2 standard build, GDScript terrain kernel, 4 threads; one run each)

| Run | Wall | Main parts |
|---|---|---|
| V1 cold bake 184729 (`bake_region.gd`, master `d2ad73f`) | 533 s, peak RSS 1164 MB | network 106, deformer 11.6, tiles 193, trails 92, vegetation 122 |
| New code cold bake 184729 (`dev_bake.gd --rebuild=ground`) | 597 s, peak RSS 1319 MB | network 114 (R5 39.6 + 25.7, R6 23.4 + 25.2), deformer 13.3, tiles 212, trails 101.4, vegetation 141, save 3 |
| Trail stage of that bake | 101.4 s | published-ground raster 5.2, planner 16.3, publication 79.8: refinement 73.5 (8 tiles, 2 seam passes, 16 tile refinements, 160 border points), shape 2.5, finalize 3.7 |
| Preview, one trail, fresh process | 24 s | upstream 2.3, ground load 13.4 (of which R7 deformer rebuild ~11.7, read + hashes ~1.3, measured separately), realization + profile 0.8, map 5.1 (first version 32 s with a whole-region map) |
| Exact, one trail (1 tile), fresh process | 65 s | upstream 2.1, ground load 14.2, publish 19.6 (one tile refinement ~17 s), vegetation 9 tiles 19, save 2.4, map 4.9; first run on a ground +125 s to store the off vegetation |
| Preview inside one process (check mode), per trail | 3–5.5 s | realization, profile, map |
| Exact inside one process (check mode), per trail | 36–82 s | refinement 12.6–40.4 s for 1–8 tiles; vegetation 9–16 tiles 18–33 s; a refused trail ~1 s |

The two cold bakes of the same products differ by ~12 % in every stage (machine noise between runs is that large here). The historical 246 s (PERF_FIRST) was another machine and build and is not comparable. Working targets preview ≤ 10 s and exact ≤ 60 s are not met in a fresh process; the costs are named above (R7 deformer rebuild on load, whole-tile refinement, 3 × 3 vegetation ring).

## Checks actually run

- FAST: parse of both changed scripts; `test_bc2_trails --group=domain` 31 checks, 0 failures; `test_perf_dev_cache` 42 checks, 0 failures, 1 NOT_RUN (C# kernel parity, no .NET build here).
- Products unchanged by the counters: new-code cold bake digests = V1 = PERF_FIRST record (network `aa564a9a`, tiles `fb2dc758`, vegetation `7a9f336c`).
- Exact vs full publication, BC1 trail of 184729: exact on the cached ground (partial vegetation) and a cold full bake with the same configuration — network, tiles and vegetation digests MATCH; the one changed tile is the one dependency tile.
- Check mode on 184729 (final run, `--mode=check`, 375 s): 10 of 10. Suitable: the BC1 trail and the four trails the V1 planner selects each pass preview and publish in exact (1–4 tiles changed, all inside the dependency set). Unsuitable, each refused in preview and exact with the expected reason and stage, no tile changed: other seed (`ERR_TRAIL_IDENTITY` seed/region), end off the road (`ERR_TRAIL_CONNECTION` ends on road), zigzag (`ERR_TRAIL_UNRIDEABLE` radius), detour through water (`ERR_TRAIL_UNRIDEABLE` water), reversed TECHNICAL descent (`ERR_TRAIL_UNRIDEABLE` direction). The first run checked only reason codes and its water case was refused for radius, not water; the check now also requires the stage, and the water fixture is chosen as the first gentle detour whose screening meets water first.
- Launch: `ride_trail.gd --dev-cache` on the exact products of the BC1 trail (headless) — region loaded from the dev cache in 2.8 s, bike placed on the trail. Not a ride and not a capture.

## NOT RUN / open

- Vulkan placement captures and a ride on the exact products (no GPU here) — Director's machine.
- Exact vs full on more than one trail set; exact with several trails at once; other seeds; Windows/.NET timings.
- Determinism across thread counts of the new tool (it calls the same publication code; D-9 still applies).
