#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

printf 'Scarb: '
scarb --version
printf 'Starknet Foundry: '
snforge --version

export SNFORGE_DETERMINISTIC_OUTPUT=true

exec snforge test -p game_components_encoding_harness --release --tracked-resource sierra-gas --max-n-steps 4294967295 --gas-report --detailed-resources "$@"
