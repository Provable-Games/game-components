#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
scarb --version
snforge --version
snforge test -p game_components_erc721 --dev --ignored bench_erc721 \
  --gas-report --tracked-resource sierra-gas --detailed-resources --color never
