#!/usr/bin/env bash
# Build the pinned 0.6.0 coverage source with a locked Cairo 2.20 compatibility adapter.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
coverage_root="$PWD"
coverage_pin=$(awk '$1 == "cairo-coverage" { print $2 }' .tool-versions)
read -r coverage_version coverage_revision coverage_cairo coverage_rust < <(
  python3 - <<'PY'
import json
p=json.load(open('tools/coverage/upstream.json'))
print(p['version'],p['revision'],p['cairo_version'],p['rust_version'])
PY
)
[[ "$coverage_pin" == "$coverage_version" ]] || { echo "Coverage adapter must be reviewed for the new pin" >&2; exit 1; }
[[ "$(scarb --version | awk '$1 == "cairo:" { print $2 }')" == "$coverage_cairo" ]] || { echo "Coverage compiler must match Scarb's Cairo compiler" >&2; exit 1; }
coverage_key=$(cat tools/coverage/upstream.json tools/coverage/cairo-2.20.patch tools/coverage/Cargo.lock scripts/setup_coverage.sh | sha256sum | cut -d' ' -f1)
coverage_bin="$coverage_root/.validation-tools/bin"
if [[ -f "$coverage_bin/coverage-build-key" && -x "$coverage_bin/cairo-coverage" ]] &&
   [[ "$(cat "$coverage_bin/coverage-build-key")" == "$coverage_key" ]]; then
  test "$("$coverage_bin/cairo-coverage" --version)" = "cairo-coverage $coverage_version"
  exit 0
fi
coverage_source="$coverage_root/.validation-tools/coverage-$coverage_key"
echo "Building cairo-coverage $coverage_version + Cairo $coverage_cairo compatibility adapter" >&2
# This directory is managed only by this build script. Failed builds can be resumed.
if [[ ! -d "$coverage_source/.git" ]]; then
  mkdir -p "$coverage_source"
  git -C "$coverage_source" init --quiet
  git -C "$coverage_source" remote add origin https://github.com/software-mansion/cairo-coverage.git
  git -C "$coverage_source" fetch --quiet --depth 1 origin "$coverage_revision"
  git -C "$coverage_source" -c advice.detachedHead=false checkout --quiet --detach FETCH_HEAD
  git -C "$coverage_source" apply --unidiff-zero "$coverage_root/tools/coverage/cairo-2.20.patch"
  cp tools/coverage/Cargo.lock "$coverage_source/Cargo.lock"
fi
test "$(git -C "$coverage_source" rev-parse HEAD)" = "$coverage_revision"
# Verify resumed work directories too: only the committed adapter and lock may differ.
cmp tools/coverage/Cargo.lock "$coverage_source/Cargo.lock"
git -C "$coverage_source" diff --no-ext-diff --no-color --unified=0 HEAD -- . ':!Cargo.lock' | cmp - tools/coverage/cairo-2.20.patch
rustup toolchain install "$coverage_rust" --profile minimal
cargo +"$coverage_rust" build --locked --release --manifest-path "$coverage_source/Cargo.toml" -p cairo-coverage
mkdir -p "$coverage_bin"
cp "$coverage_source/target/release/cairo-coverage" "$coverage_bin/cairo-coverage"
test "$("$coverage_bin/cairo-coverage" --version)" = "cairo-coverage $coverage_version"
printf '%s\n' "$coverage_key" > "$coverage_bin/coverage-build-key"
