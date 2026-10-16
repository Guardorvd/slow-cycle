# Post-BC2 generation performance: ENGINEERED-only experiment (B)

STATUS: RECORD (2026-10-15). Experiment, not adopted. Code: branch `bc2-perf-experiment` commit `e784d80` (opt-in `route_classes`, production default unchanged). Counters: commit `2bb6a5f` (B1, in production; digests unchanged).

## Conditions

Linux container, 4 cores, Godot 4.7.2 (official Linux build), `RegionBake.bake` with the default trail configuration (`trail_network.json`), 4 bake threads, one bake at a time, no cache writes. One bake per cell, so each timing has run-to-run noise: two identical 184729 bakes took 388 s and 406 s (±5 %). Digests on this machine differ from the Windows BC2 records for 184729 network/tiles (vegetation equal); every comparison below is same-machine.

Neutrality: master `e7730ca`, the A commit and the instrumented baseline give identical 184729 products (network `5b85df16`, tiles `fb2dc758`, vegetation `7a9f336c`).

## Variants

- **ALL** — production.
- **ENGINEERED** — R5 has no SINGLETRACK / TECHNICAL rounds; the builder stops on `complete_engineered()` (N1–N6 without the natural class demands; length, loops, SECONDARY and blocked/dead-end rules unchanged). No R6 limit, radius, oracle or budget touched.
- **R6_ENGINEERED** — R5 plans every class as today (same layout rules, same junction splits); R6 does not design SINGLETRACK / TECHNICAL edges; same completeness rule.

## Results

| seed / region | variant | bake s | network s | tiles s | trails s | veg s | road km | road loops | chosen classes (edges) | R7 excluded | trails published | trail loops / forks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 184729 (0,0) | ALL | 375 | 98 | 117 | 63 | 90 | 9.39 | 3 | BB 7, SEC 5 | – | TECH 2, ST 2 | 4 / 8 |
| | ENGINEERED | 279 (−26 %) | 58 | 118 | 16 | 84 | 9.51 | 3 | BB 9, SEC 3 | – | TECH 1 | 1 / 2 |
| | R6_ENGINEERED | 356 (−5 %) | 103 | 115 | 40 | 92 | 8.85 | 3 | BB 10, SEC 4 | – | TECH 1, ST 1 | 2 / 4 |
| 2024 (0,0) | ALL | 502 | 317 | 34 | 51 | 87 | **1.79** | 1 | SEC 2, ST 1 — **no backbone** | edge:0 (BACKBONE, ERR_R7_FORD_CHANNEL) | ST 1 (on the fragment) | 1 / 2 |
| | ENGINEERED | 277 (−45 %) | 128 | 55 | 4 | 80 | 4.23 | 0 | BB 4 | – | – | 0 / 0 |
| | R6_ENGINEERED | 352 (−30 %) | 179 | 84 | 5 | 84 | 6.43 | 1 | BB 5, SEC 3 | – | – | 0 / 0 |
| 3628391 (3,−2) | ALL | 664 | 345 | 187 | 37 | 89 | 7.44 | 1 | BB 7, SEC 2 | edge:9 | TECH 2 (349, 276 m) | 2 / 4 |
| | ENGINEERED | 391 (−41 %) | 129 | 151 | 10 | 94 | 5.63 | 1 | BB 6, SEC 1 | edge:7 | – | 0 / 0 |
| | R6_ENGINEERED | 480 (−28 %) | 153 | 192 | 37 | 92 | 7.44 | 1 | BB 6, SEC 2 | edge:8 | TECH 2 (349, 276 m) | 2 / 4 |

No variant left a trap; every one-way exit kept a way back by road.

## Where the R5/R6 time goes (ALL, B1 counters, all three rounds)

| seed | SINGLETRACK edges: worker CPU s (failed share) | TECHNICAL | SECONDARY | heaviest single edge |
|---|---|---|---|---|
| 184729 | 7 (100 %) | 0 | 75 (32 %) | SECONDARY 22 s |
| 2024 | 377 (93 %) | 4 (100 %) | 208 (78 %) | SINGLETRACK 65 s (CORRIDOR_CLEARANCE) |
| 3628391 | 426 (94 %) | 90 (100 %) | 145 (52 %) | SINGLETRACK 69 s (GRADE) |

- `complete()` was never true in any of the 9 bakes: it demands an R6 TECHNICAL edge, so every region runs all three R5/R6 rounds.
- No chosen production network contains a READY SINGLETRACK or TECHNICAL road edge (2024's single ST edge sits on a fragment). Natural classes in the published world come from the BC2 trail planner. The R6 natural edges are almost pure failed work on 2024 / 3628391 — but they still shape the layout: they split SECONDARY edges at their junctions, occupy R5 nodes, and their failures feed the next round's hints and junction closures.
- Network is not the whole bake: tiles (115–190 s) and vegetation (80–95 s) together cost more than R5/R6 on 184729.

## Answer

The main avoidable cost is R6 design of SINGLETRACK / TECHNICAL edges that fail, multiplied by the third round that `complete()` always forces. Removing them is 26–45 % faster, but the R5/R6 feedback loop is sensitive: any change reshuffles the road layout, and the trail planner's opportunities depend on that layout. On the accepted 184729 both variants lose trails (4 → 1 or 2, trail loops 4 → 1 or 2); ENGINEERED also loses both TECHNICAL descents on 3628391. R6_ENGINEERED keeps 3628391 functionally identical (same roads, same two descents) and repairs 2024, but still breaks 184729. **Not adopted** (B5): a speed-up that silently re-rolls accepted regions is a topology regression. A production candidate would have to change the road model on purpose (e.g. replace the feedback rounds) together with a trail-opportunity measure — a BC3 / road-generator decision, not a performance patch.

## Found on the way

- 2024 on this machine (ALL): every round loses the backbone (rounds 0–1: R7 isolation drops BACKBONE `edge:0`, ford channel; round 2: an R6 BACKBONE edge fails), and the bake still publishes the best of them: a 1.8 km fragment without a continuous backbone (score `[0,1,2,1,1788]`). Nothing refuses a region whose chosen network has no continuous backbone. Both experimental variants avoid it on this seed by chance of layout. Backlog N-7.

## NOT RUN

B6 (vegetation candidates parallel to R5): not run. Vegetation is already per-tile threaded (80–95 s); overlapping it with single-threaded R5 (≈ 11–25 s per round) bounds the gain at roughly 35–60 s wall, minus contention with R6's thread pool. Speculative parallel ladder, tile reuse, cache-closure changes: not attempted (out of scope). Repeat runs per cell, other seeds, thread-count determinism: NOT RUN.
