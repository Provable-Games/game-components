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
#   scripts/bench_packing.sh              # accessors (default)
#   scripts/bench_packing.sh primitives   # per-libfunc costs the rewrite trades
#   scripts/bench_packing.sh steps        # same accessors under cairo-steps
#
# To measure a baseline, run the identical harness in a worktree of the
# baseline commit:
#   git worktree add /tmp/gc-baseline <commit>
#   cp packages/embeddable_game_standard/src/token/tests/{bench_packing,\
# bench_primitives,packing_arms,packing_v270,packing_oracle,test_packing}.cairo \
#      packages/embeddable_game_standard/src/token/tests.cairo \
#      /tmp/gc-baseline/packages/embeddable_game_standard/src/token/...
#   cd /tmp/gc-baseline && scripts/bench_packing.sh
# In such a worktree the `*New` and `*V270` rows must match exactly; that is
# what proves the frozen arm is a faithful copy of the baseline.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

MODE="${1:-accessors}"
case "$MODE" in
    accessors)  FILTER=gas_acc_  RESOURCE=sierra-gas ;;
    primitives) FILTER=gas_prim_ RESOURCE=sierra-gas ;;
    steps)      FILTER=gas_acc_  RESOURCE=cairo-steps ;;
    *) echo "usage: $0 [accessors|primitives|steps]" >&2; exit 2 ;;
esac

SCARB_UI_VERBOSITY=no-warnings snforge test "$FILTER" \
    --package game_components_embeddable_game_standard \
    --gas-report \
    --tracked-resource "$RESOURCE" \
    --detailed-resources \
    --color never \
    --max-threads 1 \
    | tee /dev/stderr \
    | awk '/Contract \|/ { name = $2 } /^\| run / { printf "%-34s %s\n", name, $4 }' \
    | sort -u
