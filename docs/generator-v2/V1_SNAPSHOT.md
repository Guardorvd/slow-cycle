# Generator V1 — local snapshot

Made 2026-10-16 for Generator V2 (GEN2-1). Kept in the project folder only; nothing here is pushed or published. Purpose: a control world to compare V2 against, without keeping a second generator alive.

## Code

- Commit `d2ad73fcb7f95f046677c7381c690f8fe35f6e90` (master, "Merge PERFORMANCE FIRST (perf-first) into master", 2026-10-16), already on GitHub `Guardorvd/slow-cycle` master.
- Local tag `generator-v1` on that commit in the cloud checkout (not pushed; push only on the Director's word).
- `source_d2ad73f.tar.gz` — `git archive` of that commit (18 MB), so the code survives even without the repository.

## Configuration used by the bakes

All in `resources/regions/` of that commit (SHA-256):

| File | SHA-256 |
|---|---|
| `trail_network.json` (default procedural trails, used by every bake below) | `cc09fc414b034dcc639a0093f2f2171f255af1c856ab556a11411dcaaa9bde5d` |
| `bc1_trail_184729.json` | `2a7874d469a745cf440908f883c1d16a6674580db6c4c9f01845c40c259d9ebf` |
| `bc2_trails.json` | `fcf69de3f50ec2293e7a80cb9f7e11682afb5d0a9e362f5ad99375d6c671f7bb` |
| `bc2_c1_trails.json` | `5ea64aa60ffc3dd0bd9502aca8ae42d660e998e4584c49dc12ae21b07e1e264f` |
| `project.godot` | `e79950b90dfff5d31a32b7eb37effedaa21262481d1acbb04fef168981fa4d82` |

Bake options: default ROADS stop rule, `max_replans` 2, 4 threads.

## Environment

- Linux 6.18 x86_64, Ubuntu 24.04.5, Intel Xeon 2.80 GHz, 4 vCPU, 15 GB RAM (cloud session).
- Godot 4.7.2 stable official standard build (`ed1daf0bf`), binary SHA-256 `8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`. No .NET SDK: the GDScript terrain kernel (`terrain_kernel: gdscript` in each manifest).
- The cache key includes the engine version string and the digest of every file under `scripts/world`, `scripts/core`, `resources` plus `project.godot`. A different build (for example the .NET build on Windows) or any changed file gives another key; that is why the products themselves are kept here.

## Products

Each archive is the cache folder `user://regions/<key>/` (manifest.json, network.bin, tile_0..63.bin, extras.bin), made by `tools/dev/bake_region.gd` on `d2ad73f`. The bake summaries (`bake_summaries/*.json`, from `--out`) hold the manifest with digests and timings.

| Seed (region) | Archive | Network / tiles / vegetation digest | Published | Wall, peak RSS |
|---|---|---|---|---|
| 184729 (0,0) | `products/184729_0_0_cdbf1ccace62.tar` (44 MB) | `aa564a9a` / `fb2dc758` / `7a9f336c` — same as the PERF_FIRST record | roads BACKBONE 7 / SECONDARY 5, 9.39 km; TECHNICAL 2 + SINGLETRACK 2 | 533 s, 1164 MB |
| 3628391 (3,−2) | `products/3628391_3_-2_f93bbe80b86d.tar` (35 MB) | `875ace7c` / `4e48f989` / `70b9b36a` — tiles and vegetation as in PERF_FIRST | TECHNICAL 2 (349 m, 276 m) | 1131 s, 1035 MB |
| 2024 (0,0) | `products/2024_0_0_3cf0ed993e6d.tar` (15 MB) | `e93f7a66` / `f0def8c8` / `ce624265` | **defect N-7 reproduced on Linux**: no continuous backbone, a 1.79 km fragment (SECONDARY 2, SINGLETRACK 1), one SINGLETRACK trail 697 m. Kept as the V1 result, not as a good world | 823 s, 660 MB |

Windows (.NET build) caches: not made. Optional, when the Director's machine is available; not needed for GEN2-1.

## How to open

1. Check out `d2ad73f` (or unpack `source_d2ad73f.tar.gz`) and open it once in Godot 4.7.2 (standard build gives the same key as above).
2. Unpack an archive into the Godot user folder `regions/` (Linux: `~/.local/share/godot/app_userdata/Slow Cycle/regions/`; Windows: `%APPDATA%\Godot\app_userdata\Slow Cycle\regions\`).
3. Launch the region: `godot --path . res://scenes/region/region_world.tscn -- --seed=184729 --region=0,0` (3628391: `--seed=3628391 --region=3,-2`). If the key matches, the log says the region came from the cache; if not (other build or files), the game bakes it again and the archive is still the reference to compare against (digests above).
