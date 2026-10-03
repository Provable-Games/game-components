# Paired downstream v6/v7 validation

These captures use the unchanged game-components wrapper, fixtures and measurement
definitions with Scarb 2.20.1/Cairo 2.20.0, Foundry 0.63.0 and USC 2.10.1 on x86_64.
They start from main `66ce934e750f8162de4f6a377357b2b8f8e5c4c0`; v6 was validated in
a fresh worktree without a lockfile. Checked `scarb fetch` initializes the ignored
workspace lock before hashing. Exact measured lock snapshots are archived.

| Measure | v6 | Compact v7 |
|---|---:|---:|
| Full-output encode gas, 1 KiB (all seven patterns) | 3,638,770 | 3,615,190 |
| Full-output encode gas, 8 KiB (all seven patterns) | 28,401,590 | 28,239,410 |
| Actual wrapper CASM bytecode words | 13,851 | 13,619 |
| Wrapper Sierra program felts | 6,415 | 6,639 |
| Wrapper Sierra artifact JSON bytes | 318,484 | 322,602 |
| Covered/executable production lines | 224/224 | 222/222 |

All 106 frozen cases have complete output assertions. Each selector is called
three times per case, and two independent captures agree on all 318 selector
measurements. The per-call gas reduction is 0.6480% at 1 KiB and 0.5710% at 8 KiB:
58 cases improve, 48 tie, none regress. Gas values are not divided by three.
CASM drops by 232 words (1.6750%). Sierra grows; it is a separate size measure.
These are actual downstream measurements, not labels applied to upstream lab
artifacts or an isolated-library import/deployment-fee estimate.

Both encoders pass all 401 tests with zero failed/ignored/filtered tests, including
71,989 independent supplementary goldens through helper and separately compiled
production, plus 841 legacy oracle cases. V6 ran 45 Python tooling checks; the v7
scoped-mutation regression adds one (46 total). V7 rejects all 21 compiled semantic
faults, including block-countdown truncation; its positive control passes.
Both additional 44-batch oracle coverage runs meet the unchanged 90% executable
production-line threshold at 100% using the same pinned adapter and dev profile.
The full accuracy gate remains unfiltered.

Each generation preserves raw accuracy, gas and coverage reports, compiler
artifacts, encoder snapshot, lock snapshot and hash-bound report. The v6 evidence
is historical: its source-bound accuracy record refers to the then-current v6
source and tools, not the live v7 tree. It is never overwritten or presented as
current-source validation. V7 accuracy evidence remains verifiable against the
current library, tooling, fixture hashes and separately compiled release artifact.
Coverage paths preserve the worktree used when collecting traces. No trace-data
archive or unrelated lab research is imported. The relative `accuracy/gas` link
in v7 points to its same-generation capture without duplicating the evidence.

Run from the repository root:

```sh
python3 packages/encoding/harness/scripts/benchmark.py verify packages/encoding/harness/benchmarks/downstream-v6/gas
python3 packages/encoding/harness/scripts/benchmark.py verify packages/encoding/harness/benchmarks/downstream-v7/gas
python3 packages/encoding/harness/scripts/benchmark.py compare packages/encoding/harness/benchmarks/downstream-v6/gas packages/encoding/harness/benchmarks/downstream-v7/gas
# Build the current release artifact before verifying current-source evidence.
scarb build --release -p game_components_encoding_harness
python3 packages/encoding/harness/scripts/validate-candidate.py verify packages/encoding/harness/benchmarks/downstream-v7/accuracy
universal-sierra-compiler compile-contract --sierra-path packages/encoding/harness/benchmarks/downstream-v7/wrapper.contract_class.json --output-path /tmp/encoding-v7.casm.json
```

A new checkout also needs `scarb fetch` before verifying records that hash the
workspace lock. Reproduce captures with the commands in the package README;
verification binds the exact recorded toolchain. Dependency resolution can change
un-pinned workspace Git packages: use the archived lock for historical replay.
The production encoding package itself has no dependency or dev-dependency entries.
