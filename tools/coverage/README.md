# Cairo 2.20 coverage adapter

This directory pins cairo-coverage 0.6.0 at the revision in `upstream.json`,
its Cairo 2.20 compatibility patch, and its complete Cargo dependency lock.
The adapter and build script are carried over unchanged from the validated
Provable-Games/game-token coverage setup (build key
`722441cb2e15c6f5f127d739e815282b350ff9b23b5783819fc5ab1c521bbd10`).
Upstream source is fetched from software-mansion/cairo-coverage and retains
its upstream license. `scripts/setup_coverage.sh` verifies the source revision,
patch, lock, compiler version, and cached binary version before use.

Coverage output is package-local: `packages/*/coverage/coverage.lcov`.
Line coverage does not prove branch coverage. Compiler and instrumentation
changes can alter executable-line mappings; compare coverage alongside tests.
