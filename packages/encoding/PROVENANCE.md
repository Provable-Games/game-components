# Source provenance

Transferred from `base64-cairo` baseline-v6 at commit
`465d28358afecc1d864cd118161bef613c26b038`; optimized implementation commit
`3e7f14712bec58985db5a1612dc070e10abc9122`.
`src/encoding.cairo` is byte-identical, SHA-256:
`ef6d2fc50e1b5d1d81cd81091d3c34402ad41ebcd670d03e38a2a82b74c13883`.

The original encoder was copied from the Beast NFT project on 2026-10-02,
as recorded by the source project's README and LAB.md. This transfer preserves
that attribution; no separate license grant is asserted. The source repository
has no LICENSE file. No Alexandria dependency or implementation is imported.

All original fixture text and both fixture manifests are preserved byte-for-byte.
`harness/fixtures/source-sha256.json` records their original hashes. Generators
retain the original serialization and Python Base64 oracle and adapt only the
Cairo package import names. Test and contract imports point at the separate
production library. Mutation anchors preserve the v6 audit's twenty faults.
The lab history and old gas captures are intentionally outside this package.

The source review/range proof accompanies this transfer in `review/`.
Context7 was unavailable during transfer. APIs were checked in the exact local
Cairo 2.20.0 corelib `internal/bounded_int.cairo` and `byte_array.cairo`, then
compiled and executed with the repository's Scarb 2.20.1 / Foundry 0.63.0 pins.
