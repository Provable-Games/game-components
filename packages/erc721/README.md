# Felt-storage ERC721

`game_components_erc721` is a reusable OpenZeppelin Contracts for Cairo 4.0.1
fork for collections whose token IDs and account balances fit in a felt252.
It retains the standard ERC721 public u256 ABI, camel-case aliases, events,
receiver callbacks, hooks, custom ownership traits, and optional extensions.

```toml
[dependencies]
starknet = "2.20.0"
game_components_erc721 = { git = "https://github.com/Provable-Games/game-components", rev = "<reviewed-commit>" }
openzeppelin_introspection = "=4.0.1"
```

```cairo
use game_components_erc721::{
    ERC721Component, ERC721HooksEmptyImpl,
    ERC721OwnerOfDefaultImpl, ERC721TokenURIDefaultImpl,
};
```

Embed the component, its ERC721 mixin, and SRC5 as with OpenZeppelin 4.0.1.
Use the default owner and URI implementations or provide the corresponding
custom traits. The root `game_components` package also reexports this package
as `game_components::erc721`.

## Storage and supported values

Let `P = 2^251 + 17 * 2^192 + 1`, the Cairo field modulus.

| Storage | This package | Upstream 4.0.1 |
| --- | --- | --- |
| `ERC721_owners` key | felt252 | u256 |
| `ERC721_token_approvals` key | felt252 | u256 |
| `ERC721_balances` value | felt252 | u256 |

Owner and token-approval **values remain ContractAddress**. Operator approvals,
name, symbol, and base URI keep their upstream representations. The optional
URIStorage and enumerable extensions retain their upstream u256 token keys,
values, counts, and indices. Royalty token IDs, prices, and fractions also retain
their upstream types. Consecutive minting retains its u64 ID and batch bounds.

Token IDs 0 through P−1 are supported, including IDs with a nonzero u128 high
limb. IDs P, P+1, and u256::MAX cannot alias smaller IDs. Core ownership lookup
returns nonexistent for out-of-domain IDs even when a custom owner trait claims
them. Public ownership, approval, URI, and transfer operations then retain their
normal nonexistent-token errors where applicable. Internal map accesses use a
checked conversion and reject invalid IDs with `ERC721: invalid token ID`.

Balances range from 0 through P−1. A decrement from zero rejects with the pinned
Cairo u256 subtraction payload `u256_sub Overflow`; an increment to P rejects
with `ERC721: balance overflow`. `increase_balance(account, value: u128)` retains
its signature and accepts totals above u128::MAX, checking that the mathematical
sum remains below P. Its wrap check is sound because the sum is below 2P and any
wrapped result is less than `value`, hence representable as u128. Self-transfers
decrement before incrementing, so a self-transfer at balance P−1 succeeds.

These storage changes require a new storage layout. u256 map keys serialize as
two field elements; felt keys serialize as one, changing storage addresses.
Balances occupy one felt rather than the previous two-limb value. Existing OZ
storage cannot be upgraded to this layout without an explicit migration design.

## Internal API and integration responsibilities

The ordinary internal `mint(to, token_id: u256)` remains available. The additive
`mint_felt(to, token_id: felt252)` entrypoint forwards into it. That adapter
preserves hooks, events, authorization, and the complete update path; it does
not by itself remove every u256 conversion. Hooks and custom ownership/URI
traits retain their upstream u256 signatures. Every representable ownership
lookup still delegates to the configured owner trait.

The before-update hook runs before ownership lookup, authorization, and storage
updates, preserving upstream ordering. Receiver callbacks may reenter the host;
this component adds no reentrancy policy. Hosts must choose their own minting,
burning, access-control, and hook policy. `increase_balance` remains an unsafe
internal extension hook: the host must provide matching ownership semantics.
Optional enumerable and URIStorage hooks must be wired as documented upstream.
Independent royalty configuration may refer to u256 IDs outside the ERC721
domain, as in the unchanged royalty component.

## Provenance and maintenance

The MIT-licensed source comes from OpenZeppelin's published 4.0.1 package VCS
revision `cfb5ceefa2875bd5ae6ae646150bbee60453803f`. Its Cairo source and tests
match release tag v4.0.1 at `87e32f3d1269c80970201e086f3362d4b707368e`;
the release changes package version annotations. `upstream.json` records the
source revision, original test file hashes, retained test identities, and port
adaptations. Preserve upstream SPDX headers and this package's LICENSE.

The production delta is limited to checked core token-key/balance storage,
the felt mint adapter, and consistent domain handling for default, custom, and
consecutive ownership. Optional extension and royalty algorithms retain their
upstream behavior. Review future upstream fixes against this recorded revision.

## Validation

```sh
snforge test -p game_components_erc721 --features fuzzing --fuzzer-runs 256
python3 scripts/check_erc721_upstream.py
scripts/setup_coverage.sh
rm -f packages/erc721/coverage/coverage.lcov
PATH="$PWD/.validation-tools/bin:$PATH" snforge test -p game_components_erc721 --features fuzzing --coverage --fuzzer-runs 64
python3 scripts/check_erc721_coverage.py
```

The selected upstream scope contains all 193 ERC721 and 82 royalty tests under
`src/tests`, plus one inline royalty configuration test: 276 upstream identities.
All six feature-gated enumerable fuzzers execute. The three upstream ignored
nonreceiver tests retain their identities and intent, using deployed safe
dispatchers to check complete nested panic payloads and transaction rollback.
Required mocks are explicitly wired to this fork. Only the upstream dual-case
account mock is included for account receiver tests; unrelated token standards
and account suites are outside this package.

Additional tests cover full-domain IDs, checked arithmetic against a u256 oracle,
virtual ownership, consecutive minting, public aliases, hook ordering, nested
minting, adversarial receiver reentry, and extension rollback. A pristine OZ4
host serves as a differential state/error/event oracle on the shared valid
domain. CI requires at least 90% executable production-line coverage. This is
line coverage and regression testing, not a formal correctness proof.
