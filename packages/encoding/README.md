# Encoding

A dependency-free Cairo library for encoding `ByteArray` values as standard
RFC 4648 Base64. Use it to encode text or binary data, including JSON and SVG
payloads for on-chain metadata.

## Installation

Add the package to your project's `Scarb.toml`:

```toml
[dependencies]
game_components_encoding = { git = "https://github.com/Provable-Games/game-components.git" }
```

Pin a `rev` or `tag` for reproducible builds. For a local checkout, use a path
dependency pointing to `packages/encoding` instead.

The library uses only Cairo corelib and targets Cairo 2.20.0. It does not require
Starknet or Foundry dependencies. If you already depend on the aggregate
`game_components` package, the same API is available through
`game_components::encoding`.

## Usage

Import `bytes_base64_encode` and pass the bytes to encode:

```cairo
use game_components_encoding::bytes_base64_encode;

let encoded = bytes_base64_encode("foobar"); // "Zm9vYmFy"
```

The function takes a `ByteArray` by value and returns a new `ByteArray`. It
accepts arbitrary bytes, including zero bytes, without requiring valid UTF-8.

- Uses the standard `A–Z`, `a–z`, `0–9`, `+`, `/` alphabet.
- Adds canonical `=` padding: `"f"` becomes `"Zg=="`, and `"fo"` becomes `"Zm8="`.
- Returns an empty array for empty input.
- Produces `4 * ceil(input_length / 3)` output bytes without line breaks.

This package provides encoding only. It has no decoder or URL-safe Base64 API.
For a data URI, prepend the appropriate media type and `;base64,` to the encoded
result.

Encoding allocates temporary memory proportional to input size in addition to
the output. Account for execution cost when encoding large payloads on-chain.

## Development and validation

Tests and benchmark contracts live in the separate
[`game_components_encoding_harness`](harness/Scarb.toml) package, keeping the
production library dependency-free. Use the tool versions pinned in the
repository's [`.tool-versions`](../../.tool-versions).

Run these commands from the repository root:

```sh
scarb build -p game_components_encoding -p game_components_encoding_harness
scarb fmt --workspace
scarb fmt --check --workspace
snforge test -p game_components_encoding_harness
```

The harness build hook automatically generates all 313 ignored fixture text
files using independent Python Base64 oracles. Preparation verifies the frozen
hash authority, both committed manifests and generated Cairo test declarations
before writing missing data; corrupted existing files fail validation. Python 3
is required for harness builds and tests. The production library has no hook.

Every encoding change runs all 401 tests in CI, including 71,989 supplemental
goldens and 841 legacy cases through the helper and separately compiled
production contract. Coverage includes every two-byte input, all single bytes,
word and block boundaries, zero and sparse words, four random seeds per length,
large payloads and nested SVG/JSON. Run the complete correctness and
harness-integrity gate and verify its report:

```sh
python3 packages/encoding/harness/scripts/validate-candidate.py run --output /tmp/encoding-validation
python3 packages/encoding/harness/scripts/validate-candidate.py verify /tmp/encoding-validation
```

CI also enforces at least 90% executable production-line coverage. To collect
coverage locally with the repository's pinned adapter:

```sh
scripts/setup_coverage.sh
(cd packages/encoding/harness && snforge clean trace coverage)
PATH="$PWD/.validation-tools/bin:$PATH" snforge test -p game_components_encoding_harness oracle_correctness --max-threads 2 --coverage
python3 packages/encoding/harness/scripts/check-coverage.py
```

The filtered coverage run supplements the full test suite. To check that the
suite detects semantic faults in the encoder:

```sh
python3 packages/encoding/harness/scripts/mutation-audit.py --output /tmp/encoding-mutations
```

## Gas benchmarks

Capture gas measurements and compare them with a compatible reference capture:

```sh
python3 packages/encoding/harness/scripts/benchmark.py capture --output /tmp/encoding-gas
python3 packages/encoding/harness/scripts/benchmark.py compare /tmp/reference-gas /tmp/encoding-gas
```

Captures require two identical complete runs. Compare captures produced with
the same toolchain, harness, fixtures, and benchmark definitions. Reported
selector gas is already per call. Re-run correctness, coverage, and gas checks
when upgrading the toolchain: the encoder uses unstable corelib features.

The current verified compact v7 encoder reduces full-output selector gas by
0.6480% at 1 KiB and 0.5710% at 8 KiB, and the same benchmark wrapper's CASM by
232 words, against v6 in a previously verified paired downstream measurement. All 106
cases improved or tied, using Scarb 2.20.1/Cairo 2.20.0, Foundry 0.63.0 and USC
2.10.1. The upstream lab used Foundry 0.64.0. Captures are generated on demand;
no archived reports or benchmark reference is required for correctness.
See [source provenance](PROVENANCE.md) for attribution and the exact source hash.
