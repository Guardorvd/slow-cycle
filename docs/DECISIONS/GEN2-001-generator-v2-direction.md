# GEN2-001 — Generator V2 direction and V1 snapshot

STATUS: ACCEPTED (Game Director, 2026-10-16)

Source: Director messages of 2026-10-16 in the project thread "Generator V2" (decisions G1–G3, GEN2-1 clarifications, GEN2-1 accepted). Documents: [Generator V2](../generator-v2/README.md).

## Decision

- G1: Generator V2 replaces the NT1 proposal; order of game results: GEN2-1 single-trail tool and stage costs → GEN2-2 one mountain loop (climb + switchback descent) on V1 ground → GEN2-3 faster publication, R5/R6 for roads only → GEN2-4 diverse geography, ride-opportunity map, access → GEN2-5 trail network with forks, loops and return.
- G2: the world may change (road networks may re-roll). V1 is kept as a product snapshot (code, configuration, environment, baked caches), not as a second generator; Git tag + configuration switch alone is not promised to reproduce it.
- G3: at-grade crossings, fords, trail forks/merges, ground shaping, platforms / profiled turns and speed-dependent radius are allowed; the numbers in the plan are starting hypotheses to justify, not rules.
- Bike physics, camera and controls stay unchanged. Each GEN2 stage needs its own approval; nothing is merged to master without the Director's decision.

## Consequences

The V1 snapshot exists ([record](../generator-v2/V1_SNAPSHOT.md)); archives stay outside Git. Master / Target Architecture amendments proposed in the report (§11) are not made by this record; they come with the stage that changes those owners.
