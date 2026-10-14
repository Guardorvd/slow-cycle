# Slow Cycle — short active backlog

STATUS: CURRENT (D3 Fast Cycle, 2026-10-14). One line per item; remove an item when it is done (note the commit). Older history stays in its records; the root `BACKLOG.md` is superseded legacy.

## Non-critical defects (found in FAST / PLAYTEST)

| ID | Where (seed, region, coordinates) | Defect | Found |
|---|---|---|---|
| — | | none recorded yet | |

## DEEP checks NOT RUN (owed, never PASS)

Run at the next DEEP trigger, release milestone or Director decision ([Test Strategy §0](TEST_STRATEGY.md#0-fast-cycle-fast--playtest--deep-d3)).

| ID | Check | Scope | Source |
|---|---|---|---|
| D-1 | G gates (seed_diversity, monotony, virtual_rider, capture_visual_vulkan) | BC1 diff + PR1 `mode_select` change | [BC1 §3–4](plans/completed/BC1.md) |
| D-2 | 20-min soak trail on/off (E6 frame-time distribution, memory growth) | region runtime | [BC1 §3–4](plans/completed/BC1.md) |
| D-3 | Re-run `capture_region_world --target=r7_fixture` after the closeout fix | capture tool | [BC1 §3](plans/completed/BC1.md) |
| D-4 | VERIFY + independent REVIEW of the region runtime | PR1/BC1 runtime | [BC1 §4](plans/completed/BC1.md), [PR1](plans/suspended/PR1.md) |

## Known failures (visible, not waived)

- S3: `test_road_synthesis --group=regions` 184729, 10 × `oracle_path_move:*` curvature — OPEN, awaiting a Director decision.
- C10 / C12 OPEN; whole-game runtime acceptance INCOMPLETE.

## Playtest tooling (proposals, not implemented)

| ID | Proposal | Why |
|---|---|---|
| T1 | `capture_region_world.gd --mode=placement`: after the cached region is ready, for each of 3–5 points (overview, trail entry, trail middle/SHAPED bench, trail exit, a road point) call `scene.streamer.ensure_around(p)`, place the camera (or `spawn_bike` + settle ~30 physics frames), capture; receipt tagged `"mode": "placement"` | Today it rides the bot up to 3000 m (≈ 400 s of physics plus load) for 5 shots; placement needs only the cache load plus seconds per view. Not ride evidence. |
| T2 | Move the BC1 dev probe `fast_trail.gd` (outside the repo, `work/bc1/tools/`; runs `RegionBake._trails` on cached prototype-off products: 51 s vs ≈ 500 s, digests equal to a fresh bake in the BC1 probe) into `tools/dev/`, saving under a **dev key** marked `dev_fast_path`; let the region scene load it via an explicit dev-only argument | Any edit under `scripts/world` changes `RegionBakeCache.source_digest()` and forces a 6–8 min cold bake. Writing fast-path products under the production key would poison the cache, so a small explicit dev argument in `region_world.gd` is needed — runtime change, needs its own sprint card approval. Valid only while the edit does not change upstream/network/tile code; parity with a fresh bake is a DEEP check. |
| T3 | `test_bc1_trail --group=domain`: optional `--off-key=` for an explicitly named prototype-off cache | The group needs a prototype-off cache with the current source digest, so after a world edit it cannot be a FAST check without a 400 s integration bake. A setup argument only; assertions unchanged. |
