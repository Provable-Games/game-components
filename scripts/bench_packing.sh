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
#   scripts/bench_packing.sh steps              # same accessors under cairo-steps
#   scripts/bench_packing.sh baseline <commit>  # same harness on an older tree
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
FIXTURES=(
    "$TESTS_DIR/bench_packing.cairo"
    "$TESTS_DIR/bench_primitives.cairo"
    "$TESTS_DIR/packing_arms.cairo"
    "$TESTS_DIR/packing_oracle.cairo"
    "$TESTS_DIR/packing_v270.cairo"
    "$TESTS_DIR/test_packing.cairo"
    "packages/embeddable_game_standard/src/token/tests.cairo"
)

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
        | awk '/Contract \|/ { name = $2 } /^\| run / { printf "%-34s %s\n", name, $4 }' \
        | sort -u
}

MODE="${1:-accessors}"
case "$MODE" in
    accessors)  run_bench gas_acc_  sierra-gas ;;
    primitives) run_bench gas_prim_ sierra-gas ;;
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
        mkdir -p "$WORKTREE/scripts"
        cp "$REPO_ROOT/scripts/bench_packing.sh" "$WORKTREE/scripts/bench_packing.sh"
        echo "baseline worktree: $WORKTREE (at $COMMIT)" >&2
        echo "clean up with: git worktree remove --force $WORKTREE" >&2
        exec bash "$WORKTREE/scripts/bench_packing.sh" accessors
        ;;
    *) echo "usage: $0 [accessors|primitives|steps|baseline <commit>]" >&2; exit 2 ;;
esac
