# Cairo 2.20 coverage adapter

This directory pins cairo-coverage 0.6.0 at the revision in `upstream.json`,
its Cairo 2.20 compatibility patch, and its complete Cargo dependency lock.
The original adapter and build script were carried over from the validated
Provable-Games/game-token coverage setup (build key
`722441cb2e15c6f5f127d739e815282b350ff9b23b5783819fc5ab1c521bbd10`).
Upstream source is fetched from software-mansion/cairo-coverage and retains
its upstream license. `scripts/setup_coverage.sh` verifies the source revision,
patch, lock, compiler version, and cached binary version before use.

Coverage output is package-local: `packages/*/coverage/coverage.lcov`.
Line coverage does not prove branch coverage. Compiler and instrumentation
changes can alter executable-line mappings; compare coverage alongside tests.

The encoding transfer extends the adapter to filter Sierra statements only after
its existing category filter: a statement must emit a nonempty CASM bytecode span
(`start_offset < end_offset`) to contribute an executable line. The exact pinned
compiler supplies these spans. Empty spans have no VM program counter and cannot
receive a trace hit; newer no-op casts and bounded arithmetic were absent from
0.6.0's existing libfunc-name heuristic. All actual bytecode spans remain eligible,
including unexecuted spans. No source-line or libfunc-name exceptions are added.
Complete debug-info inventory and valid ordered spans are asserted; missing or
reversed spans fail closed. Three focused Rust tests run when building the adapter.

For the unchanged encoding source and identical 841-case oracle traces, the old
mapping reported 224/249 (89.96%). The corrected executable-line mapping is
recorded in `packages/encoding/README.md`. This is an instrumentation correction,
not additional input coverage or a reduction in the 90% requirement.
