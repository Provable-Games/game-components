# Encoder provenance

The production source is byte-identical to the verified compact `base64-cairo`
`baseline-v7`, implementation `fc882db8e31dc98e4c8e14d26741c1da85ca7d24`,
promotion `f3c47c4cc57a48ca7715c1cd907446a966dc55e6`.
SHA-256: `e7f8bfaa75c13c0e8d051ad82c4639f27be0c262978fc4dc67c9a1d86af35350`.
The source project's original encoder came from the Beast NFT project; this
transfer preserves that attribution and asserts no separate license grant.

V7 changes only bounded full-block quotient/remainder bookkeeping, a guarded
felt block countdown and `#[inline(always)]` on `encode_groups6`. For a successful
u32 input length n=31w+p, 0<=p<=30, floor(n/93)=floor(w/3), so every countdown
iteration has three complete words available. The quotient is at most
`0x2c0b02c`, its product with 93 at most `0xfffffffc`, and the tail is 0..92.
The zero check precedes decrement. Prefix length plus the exact remainder equals
n, and the prefix is divisible by three, preserving suffix grouping and padding.
Alphabet, packing, tiny-input and cached-suffix paths are unchanged. No partial
prefix or broader inlining variant is included. Pinned Cairo 2.20.0 corelib and
compiler APIs were inspected because Context7 was unavailable.

The three committed fixture manifests preserve the original golden hashes.
Fixture data is reproduced deterministically by independent Python generators,
checked against those hashes and kept outside Git. The complete accuracy gate,
coverage enforcement and 21 compiled semantic-fault checks remain available.
Gas captures accept an explicit compatible external reference; historical reports
are not part of this package. The production manifest remains dependency-free.
