# Slow Cycle — short active backlog

STATUS: CURRENT (D3 Fast Cycle, 2026-10-14). One line per item; remove an item when it is done (note the commit). Older history stays in its records; the root `BACKLOG.md` is superseded legacy.

## Non-critical defects (found in FAST / PLAYTEST)

| ID | Where (seed, region, coordinates) | Defect | Found |
|---|---|---|---|
| N-1 | 184729 (0,0), region HUD | The top summary label is cut at the right edge at 1280 × 720 (long trail id makes it longer) | BC2 c1 captures |
| N-4 | player presentation, 184729 TECHNICAL 23 % pitch | In the first-person view on a steep descent a dark slab (bike body) fills the lower screen; observed in placement captures only — owner: player, not changed | BC2 c2 captures |
| N-3 | 184729 `trail:st_6_9_…` | Procedural SINGLETRACK rides fine but is not especially interesting, relief hardly felt (Director ride, c1 ACCEPTED); known limit of the region's valley floor — not to be tuned per trail | BC2 c1 playtest |

## DEEP checks NOT RUN (owed, never PASS)

Run at the next DEEP trigger, release milestone or Director decision ([Test Strategy §0](TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)).

| ID | Check | Scope | Source |
|---|---|---|---|
| D-1 | G gates (seed_diversity, monotony, virtual_rider, capture_visual_vulkan) | BC1 diff + PR1 `mode_select` change | [BC1 §3–4](plans/completed/BC1.md) |
| D-2 | 20-min soak trail on/off (E6 frame-time distribution, memory growth) | region runtime | [BC1 §3–4](plans/completed/BC1.md) |
| D-3 | Re-run `capture_region_world --target=r7_fixture` after the closeout fix | capture tool | [BC1 §3](plans/completed/BC1.md) |
| D-4 | VERIFY + independent REVIEW of the region runtime | PR1/BC1 runtime | [BC1 §4](plans/completed/BC1.md), [PR1](plans/suspended/PR1.md) |
| D-5 | Procedural trail bake determinism 1 vs N threads; fast path (`tools/dev/fast_trail.gd`) vs fresh bake parity beyond the one 184729 comparison | BC2 checkpoint 1 planner + `_procedural_trails` | [BC2 plan](../implementation_plan.md) |
| D-6 | Input rides of the procedural SINGLETRACK both ways and the TECHNICAL descent (existing BC1 runtime harness) — the checkpoints rely on the Director's rides | BC2 checkpoints 1–2 | [BC2 plan](../implementation_plan.md) |

## Known failures (visible, not waived)

- S3: `test_road_synthesis --group=regions` 184729, 10 × `oracle_path_move:*` curvature — OPEN, awaiting a Director decision.
- C10 / C12 OPEN; whole-game runtime acceptance INCOMPLETE.

## Playtest tooling

| ID | State | Note |
|---|---|---|
| T1 | IMPLEMENTED as dev tool `tools/dev/capture_bc2.gd` (BC2 checkpoint 1) | Placement captures of every published trail (overview, join from the road, steepest point, middle, towards the second join); receipts tagged `PLACEMENT`. Not ride evidence. `capture_region_world.gd` unchanged. |
| T2 | NOT BUILT (evaluated in BC2 c2: fast path ~2.5 min + production bake ~8 min sufficed; parity shown twice) | Dev-key snapshot of fast-path products + explicit dev-load in the region scene; production key never written by the fast path. |
| T3 | IMPLEMENTED as `tools/dev/fast_trail.gd --off-key=` (verified: off bake, same seed/region, region + hydrology signatures recomputed) | `test_bc1_trail.gd` untouched. Older-closure off products are valid only for edits that do not reach upstream/network/tiles — printed as `FAST_OFF_KEY current_closure=false`. |
