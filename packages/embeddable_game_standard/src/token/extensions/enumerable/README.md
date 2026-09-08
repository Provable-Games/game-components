# Enumerable Lite

An optional ERC721 extension for discovering a wallet's tokens through RPC.
Import `EnumerableComponent` from
`game_components_embeddable_game_standard::token::extensions::enumerable::enumerable`.
It stores owner indexes and token IDs as `felt252`, and exposes
`token_of_owner_by_index(owner: ContractAddress, index: u256) -> u256`.

This is owner enumeration only: there is no `total_supply` or global
`token_by_index`. The initializer registers `IENUMERABLE_OWNER_ID`
(`0x312c74a3a4f7aaf9aa3e80ddea171f958139ef0c3dbea524e0763682b7d57dd`),
not OpenZeppelin's full `IERC721_ENUMERABLE_ID`.

## Integration

Embed ERC721, SRC5 and Enumerable components, expose
`EnumerableComponent::EnumerableImpl<ContractState>`, and call
`enumerable.initializer()` during construction. The extension is optional;
the standard token does not embed or pay for it by default.

Call enumeration **inside `ERC721HooksTrait::before_update`**, before ERC721
changes ownership or balances, on every mint, transfer and burn path:

```cairo
let mut contract = self.get_contract_mut();
contract.enumerable.before_update(to, token_id);
```

For a hook that already reads the current owner (for example, the standard
minigame token's soulbound guard), reuse that read:

```cairo
let previous_owner = self._owner_of(token_id);
if !previous_owner.is_zero() && !to.is_zero() {
    // The standard token's soulbound bit differs from the retired generation.
    assert!(
        !unpack_soulbound(token_id.try_into().unwrap()),
        "Token is soulbound and cannot be transferred",
    );
}
let id = token_id.try_into().expect(EnumerableComponent::Errors::TOKEN_ID_OUT_OF_RANGE);
let mut contract = self.get_contract_mut();
contract.enumerable.before_update_with_owner(to, id, previous_owner);
```

Import `unpack_soulbound` from `token::packing`, `core::num::traits::Zero`,
and the component internal traits as in the
[test embedders](../../tests/enumerable_fixtures.cairo). The supplied owner must
be the current trusted ERC721 owner, read with **no intervening external call**.
Use exactly one enumeration hook per update. Neither hook authorizes minting,
transfers or burns: keep the embedder's access controls and soulbound rules.
The test embedders have unrestricted mint entrypoints and are not presets.

All mint paths must use IDs representable as `felt252` (`0 <= id < P`). Both
zero and `P - 1` are supported; the generic hook rejects wider `u256` values.
This includes direct/internal ERC721 calls, not just the public game mint ABI.

## Invariants and optimizations

Each owner's live indexes occupy `[0, balance_of(owner))`. Removal swaps the
last token into a removed middle slot, updates its reverse index and clears
the old tail. Self-transfers preserve ordering. Burned tokens have a zero
reverse index, so reminting the same ID is safe.

- A mint into an empty wallet skips writing its already-zero reverse index.
- A transfer writes the reverse index only at the destination; there is no
  external call between removal and insertion. It **must** write even when the
  destination index is zero.
- A burn clears a nonzero reverse index. Retaining that cleanup is necessary
  for the mint optimization and safe reminting.
- Removal reuses storage entries for read/write operations.
- The optional owner-aware hook avoids repeating the embedder's owner read.

The storage names and types match the former owner-enumeration extension.
Adding enumeration to a **populated non-enumerable** collection still requires
a separately designed index backfill before enabling these hooks and
registering the interface. Class replacement and initialization do not create
indexes for existing tokens. Integrate from the first mint of a new or empty
collection; this component does not implement migration.

## RPC discovery

Read `balance_of(owner)`, then `token_of_owner_by_index(owner, i)` for each
index below that balance, using the **same block ID** for all calls. Transfer
and burn use swap-and-pop, so ordering is unstable across blocks. Batch calls
at the RPC client if supported. This discovers a known owner's holdings in
one collection, including expired game tokens; decode lifecycle fields to
filter them. It does not discover all owners or collections.

`all_tokens_of_owner` is an internal convenience helper with a checked `u64`
balance conversion and an unbounded loop. Prefer the indexed ABI for large
wallets rather than exposing that helper as an unrestricted batch RPC call.

## Validation and gas measurements

```sh
snforge test -p game_components_embeddable_game_standard '::token::tests::test_enumerable::' --fuzzer-runs 256
python3 scripts/bench_enumerable.py --output /tmp/enumerable-gas
```

The benchmark runs twice and requires exact agreement. It reports isolated
probe execution, an ABI-matched no-op floor, and their difference. Setup and
assertions are outside the measured call; fixtures use nonzero token-ID high
limbs. The reference is the former implementation at `17558e939ab807776c785181551b5737699d443f`,
kept under `#[cfg(test)]`. Reference and optimized embedders both enforce the
same soulbound check; the optimized one shares that check's owner read. The
generic embedder exercises the convenience hook without a soulbound guard.
The reference rejects burns, so there is no reference burn comparison.

Measurements use this repository's pinned Cairo/OZ versions and its dev
profile (including `inlining-strategy = "avoid"`). They measure execution gas,
not transaction fees, storage data availability gas or current STRK/USD cost.
No mainnet deployment is needed to run the harness.
