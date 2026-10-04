# Q2A Frozen Baseline

Q2 aggregates observations from the unchanged Q1 CLI. Every suite verdict, reason code and reason list is copied from Q1 result.json. Product failures remain evidence. Runtime acceptance stays INCOMPLETE; C10/C12 remain OPEN. ObjectDB work records occurrence only. Q2B and R0 are separate tasks.

Use the existing Python executable with `-B`:

```
python -B tools/baseline/sc_baseline.py selftest
python -B tools/baseline/sc_baseline.py freeze-check --working
python -B tools/baseline/sc_baseline.py calibrate --godot <console-exe> --output-root <external-root>
python -B tools/baseline/sc_baseline.py calibrate --observer-validation --godot <console-exe> --output-root <external-root>
python -B tools/baseline/sc_baseline.py run --freeze <F-SHA> --freeze-receipt <external-receipt.json> --godot <console-exe> --output-root <external-root>
python -B tools/baseline/sc_baseline.py reconcile --root <baseline-directory>
python -B tools/baseline/sc_baseline.py aggregate --root <baseline-directory>
```

The frozen matrix has 29 harness invocations / 188 declared attempts. Calibration is external and excluded. Timing runs keep the memory observer OFF. Memory polling is 250 ms, only in M2/P5, with separate wrapper/main processes, retained handles and explicit post-exit query outcomes. `sampled_peak_*` are sampled maxima; `os_peak_*_until_last_query` may not include final lifetime peaks.

An unresolved required Q1 INCOMPLETE or Q2 evidence gap produces AWAITING_HUMAN_GAP_DECISION and stops. A changed revision/source, dirty boundary, digest/engine mismatch, failed probes or broken chain produces INVALID. Evidence is never deleted or selected for nicer results. Single-suite retries require the approved infrastructure reason; replay cannot be retried alone with an identical same-invocation prerequisite and therefore stops for a gap decision.

RI-OPEN covers formatted samples of the first 100 m only. RI-RIDE/RI-ROUTE report repeatability observations. Random effective seed runs remain excluded from equality. No cross-platform determinism, E5 human acceptance or E7 claim is made. Frame/GPU timing is the accepted D4 gap.

Heavy raw evidence remains external. Durable artifact identities use baseline_id, relative POSIX path, byte size and SHA-256. Under approved A1, the payload index excludes itself, SHA256SUMS, baseline.json and the repository closure index. Its raw-byte digest is the payload evidence digest; the repository index separately records closure-file digests without hashing itself. Create the canonical external receipt with campaign.receipt immediately after F, before invocation; run validates/copies it and binds its identity into CAMPAIGN_START and the baseline. Repository documentation remains unchanged during the campaign.

Approved A2 measures exact console/main executable paths with verified parent links. Helpers remain diagnostic inventory with role-labelled access errors; required target failures remain incomplete. Raw exit events are authoritative and summary exit time is reconciled from them. Live/unknown exit time is null. Calibration 1/2 and the one separate two-suite observer validation remain excluded from baseline statistics. This tooling alone is not a completed/verified baseline.

Approved A3 corrects derived reports from the existing campaign only. `representation: full-external/1` retains the complete external report; `compact-repository/1` retains every attempt/result/seed/configuration/directory binding and summaries, with explicit JSON-pointer references bound to the full report's relative path, bytes and SHA-256. `compact_record`, `repository_index` and `check_repository_budget` produce/check the durable package; total Q2A directory budget remains 1,000,000 bytes. The measured F and ledger remain unchanged; reporting source hashes identify A3 separately.

Wall durations retain every recorded value and are stratified by suite/configuration/observer/workload role. P4 measured timing remains distinct from excluded warm-up and P5 memory evidence. RI-CAP resolves already-produced per-frame metadata, retaining producer signatures, relative source/SHA, seed/config and attempt bindings; missing or ambiguous metadata cannot yield a fabricated signature. Historical env files remain unchanged: derived `mtime_us` renames their mislabeled microsecond `mtime_ns` values without scaling or greater precision. Artifact identity uses path/bytes/SHA rather than mtime. Preliminary failed reports remain historical evidence. No new Godot or harness runtime execution is part of A3.

Approved A4 corrects RI-SESSION after accepted independent R1 REJECT. Its hash consumes emitted opening/selected_arm checkpoint signatures plus the explicit decision whitelist `fork_id`, `choice`, `selected_branch_id`, `selected_seed`. No whole route-choice object or geometry recomputation is allowed. `physics_tick` remains in a separate `session_timing` REPEATABILITY_OBSERVATION with no deterministic equality claim. Full road_identity retains checkpoint/decision components, attempt/run identity, source relative path and SHA; compact road_identity and session_timing explicitly reference those full sections. Historical A3 extraction/full report and closure metadata remain under `aggregate/superseded/A3`, bound by a receipt and labelled SUPERSEDED_BY_A4 (65 false mismatches, physics_tick included). F/campaign/ledger/raw data remain unchanged. R1 NB1–NB5 are recorded without fixes; no runtime execution or Q2B/R0 is authorized.
