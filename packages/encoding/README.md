# Encoding

Dependency-free standard RFC 4648 Base64 for Cairo `ByteArray` values, using the
`+`/`/` alphabet and canonical `=` padding. Empty input returns an empty array.

```cairo
use game_components_encoding::bytes_base64_encode;

let encoded = bytes_base64_encode("foobar"); // "Zm9vYmFy"
```

The aggregate package also exposes `game_components::encoding`.
The library manifest contains no dependencies or dev dependencies. All test-only
Starknet/Foundry dependencies and benchmark contracts live in the separate
`game_components_encoding_harness` workspace package under `harness/`.
Existing utility encoders and their callers are unchanged.

Run from the repository root with the versions in `.tool-versions`:

```sh
scarb build -p game_components_encoding -p game_components_encoding_harness
scarb fmt --check --workspace
python3 packages/encoding/harness/scripts/validate-candidate.py run --output /tmp/encoding-validation
python3 packages/encoding/harness/scripts/validate-candidate.py verify /tmp/encoding-validation
python3 packages/encoding/harness/scripts/mutation-audit.py --output /tmp/encoding-mutations
```

The complete gate requires all 401 Cairo tests with no ignored/filtered tests:
4 unit tests, 40 legacy gas tests, 44 legacy oracle batches (841 cases),
106 frozen gas cases with complete output assertions, and 207 accuracy batches
(71,989 independent Python goldens through both the helper and a separately
compiled production contract). Coverage includes all two-byte inputs, every
single-byte value, sextet positions, four random seeds, sparse/zero words,
word/block/tail boundaries and nested SVG/JSON through 16,385 bytes.
The gate also runs 45 Python integrity, portability, CI-routing and coverage checks.
CI separately collects helper oracle traces and enforces at least 90% executable
production-line coverage. The pinned adapter's compiler-derived CASM span filter
reports 224/224 (100%) for the same source and 841-case oracle run; its previous
mapping reported 224/249 (89.96%) by counting zero-bytecode Sierra annotations.
Only statements emitting bytecode can receive a VM trace hit. This correction
adds no source-line exclusions, keeps the original category filter and fails
closed on missing/reversed compiler spans. Three focused Rust tests validate it.
Run locally after installing the pinned adapter:

```sh
scripts/setup_coverage.sh
(cd packages/encoding/harness && snforge clean trace coverage)
PATH="$PWD/.validation-tools/bin:$PATH" snforge test -p game_components_encoding_harness oracle_correctness --max-threads 2 --coverage
python3 packages/encoding/harness/scripts/check-coverage.py
```

The coverage run is an additional filtered trace run; it does not replace the
complete 401-test correctness gate above.
The semantic fault audit requires 20 compiled mutations to fail the expected
production output assertion, with a passing positive control.

```sh
python3 packages/encoding/harness/scripts/benchmark.py capture --output /tmp/encoding-gas
python3 packages/encoding/harness/scripts/benchmark.py compare /tmp/reference-gas /tmp/encoding-gas
```

Gas captures require two identical complete 106-case runs, three selectors and
three calls per selector per case. Reported selector gas is already per call;
do not divide by three. Comparisons require identical toolchains, harnesses,
fixtures and definitions. Lab captures used Foundry 0.64.0; this workspace uses
0.63.0 and its own compiler profile. Old lab gas figures are provenance only,
not a performance parity claim. Rebaseline both encoders under the same target
harness/toolchain before making a comparison. The validation gate accepts an
explicit `--reference` when `--capture` is requested; correctness alone needs
no historical capture or local source repository.

The transferred v6 implementation processes 93 bytes into four 31-byte output
words, retaining its tiny-input iterator and cached suffix paths. It uses only
corelib, including unstable `bounded-int-utils`, `byte-span` and
`corelib-get-trait`. Toolchain upgrades require fresh correctness, range review
and gas validation. Whole-input serialization uses temporary memory proportional
to input size; large-length allocation behavior is not an exhaustive proof.
See [PROVENANCE.md](PROVENANCE.md) for source attribution and hashes.
