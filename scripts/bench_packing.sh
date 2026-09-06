#!/usr/bin/env bash
# Per-accessor gas benchmark for the packed token id codec.
#
# Both arms — the shipped `token::packing` and the frozen v2.7.0 copy in
# `token::tests::packing_v270` — are compiled into the SAME crate and measured
# in ONE snforge run, so compiler, profile and invocation are identical across
# arms and cross-run noise cannot leak into a delta.
#
# READ THE PROBE ROW, NOT THE TEST TOTAL. Each `gas_acc_*` test declares,
# deploys and calls a single-entrypoint probe contract; only the contract's
# `run` row in the `--gas-report` table is the accessor's cost. The test total
# is dominated by deployment.
#
# `PbNoop` is the ABI floor: the same felt252-in / felt252-out entrypoint with
# no codec call. Everything above it is calldata deserialization, selector
# dispatch and return serialization, which no accessor can avoid.
#
# Boundary: these are isolated entrypoint execution measurements. They are not
# transaction costs and say nothing about calldata, storage or settlement.
#
# Toolchain is pinned in .tool-versions (scarb 2.16.1, starknet-foundry 0.58.1).
#
# Usage:
#   scripts/bench_packing.sh                    # accessors (default)
#   scripts/bench_packing.sh primitives         # per-libfunc costs the rewrite trades
#   scripts/bench_packing.sh lifecycle          # unpack_lifecycle + is_playable body
#   scripts/bench_packing.sh guard              # StandardGameMock ENTRYPOINT rows
#   scripts/bench_packing.sh steps              # same accessors under cairo-steps
#   scripts/bench_packing.sh baseline <commit>  # same harness on an older tree
#
# `guard` reads per-selector rows off the deployed StandardGameMock rather than
# a synthetic probe, so it is the realistic per-action figure. Those tests use
# only the public dispatcher API, so the mode runs unchanged on a pre-change
# tree — which is how the guard before/after pair is produced.
#
# `baseline` builds a throwaway worktree of <commit>, copies this harness into
# it (the fixtures and this script; nothing else), and runs the accessor bench
# there. In such a worktree `token::packing` is the OLD codec, so every
# `Pb*New` row must equal its `Pb*V270` row — that equality is what proves the
# frozen arm is a faithful copy of the baseline, and the `*V270` values are the
# "before" column.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
REPO_ROOT="$PWD"

TESTS_DIR="packages/embeddable_game_standard/src/token/tests"
# Copied verbatim into a baseline worktree. Every one of these compiles against
# a pre-change tree: none names a symbol this branch introduced.
# `bench_lifecycle.cairo` and `lifecycle_arms.cairo` are deliberately NOT here —
# the first names `packing::unpack_lifecycle`, which by construction does not
# exist before this change. Their two arms coexist in one crate instead, so they
# never needed a baseline worktree.
FIXTURES=(
    "$TESTS_DIR/bench_packing.cairo"
    "$TESTS_DIR/bench_primitives.cairo"
    "$TESTS_DIR/packing_arms.cairo"
    "$TESTS_DIR/packing_oracle.cairo"
    "$TESTS_DIR/packing_v270.cairo"
    "$TESTS_DIR/test_packing.cairo"
    "$TESTS_DIR/test_gas_bench.cairo"
)
# Module declarations the fixtures need. Appended to the baseline tree's own
# tests.cairo rather than overwriting it, so the baseline keeps whatever else it
# declares and this list stays independent of what this branch declares.
FIXTURE_MODS=(bench_packing bench_primitives packing_arms packing_oracle packing_v270 test_packing)

run_bench() {
    local filter="$1" resource="$2"
    SCARB_UI_VERBOSITY=no-warnings snforge test "$filter" \
        --package game_components_embeddable_game_standard \
        --gas-report \
        --tracked-resource "$resource" \
        --detailed-resources \
        --color never \
        --max-threads 1 \
        | tee /dev/stderr \
        | awk '
            /Contract \|/           { contract = $2; next }
            /^\| Function Name/      { next }
            /^\| [A-Za-z_][A-Za-z0-9_]* +\|/ {
                                      printf "%-30s %-30s %s\n", contract, $2, $4 }' \
        | sort -u
}

MODE="${1:-accessors}"
case "$MODE" in
    accessors)  run_bench gas_acc_  sierra-gas ;;
    primitives) run_bench gas_prim_ sierra-gas ;;
    lifecycle)  run_bench gas_life_ sierra-gas ;;
    guard)      run_bench bench_standard_ sierra-gas ;;
    steps)      run_bench gas_acc_  cairo-steps ;;
    baseline)
        COMMIT="${2:-}"
        [ -n "$COMMIT" ] || { echo "usage: $0 baseline <commit> [worktree-dir]" >&2; exit 2; }
        WORKTREE="${3:-${TMPDIR:-/tmp}/gc-bench-baseline}"
        if [ -e "$WORKTREE" ]; then
            echo "error: $WORKTREE already exists; remove it or pass another path" >&2
            echo "       (git worktree remove --force '$WORKTREE')" >&2
            exit 2
        fi
        git worktree add --detach "$WORKTREE" "$COMMIT"
        for f in "${FIXTURES[@]}"; do
            mkdir -p "$WORKTREE/$(dirname "$f")"
            cp "$REPO_ROOT/$f" "$WORKTREE/$f"
        done
        TESTS_MANIFEST="$WORKTREE/packages/embeddable_game_standard/src/token/tests.cairo"
        for m in "${FIXTURE_MODS[@]}"; do
            grep -q "^mod ${m};" "$TESTS_MANIFEST" || echo "mod ${m};" >> "$TESTS_MANIFEST"
        done
        mkdir -p "$WORKTREE/scripts"
        cp "$REPO_ROOT/scripts/bench_packing.sh" "$WORKTREE/scripts/bench_packing.sh"
        echo "baseline worktree: $WORKTREE (at $COMMIT)" >&2
        echo "clean up with: git worktree remove --force $WORKTREE" >&2
        bash "$WORKTREE/scripts/bench_packing.sh" accessors
        echo >&2
        echo "=== baseline guard entrypoint rows ===" >&2
        exec bash "$WORKTREE/scripts/bench_packing.sh" guard
        ;;
    *)
        echo "usage: $0 [accessors|primitives|lifecycle|guard|steps|baseline <commit>]" >&2
        exit 2
        ;;
esac
