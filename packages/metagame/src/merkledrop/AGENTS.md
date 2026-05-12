## Merkle Drop Module

The `merkledrop` module provides a reusable Starknet component for issuing single-use claims against a merkle-tree commitment, supporting two interchangeable credential paths.

### Features

- On-chain tree construction via alexandria Poseidon merkle tree (operator submits raw leaf data; component computes root, stores it, emits per-leaf proof events).
- Single-use nullifier per `(root, leaf_hash)` shared across both claim paths.
- Configurable tree expiry timestamp.
- Two claim paths via the same component:
  1. `claim` (arcade-style, implementor-defined recipient binding).
  2. `claim_with_eth_signature` (bearer credential, EIP-191 personal_sign).
- `on_merkledrop_claim` callback for the implementing contract to mint / transfer / grant.

### Architecture

- **MerkledropComponent** (`merkledrop_component.cairo`): Starknet component with storage, register entrypoint, two claim entrypoints, hook trait, and view helpers.
- **Signature helpers** (`signature.cairo`): EIP-191 personal_sign verification with the message format `"Claim on starknet with: 0x{recipient:x}"` (matches `viem.signMessage` output and `cartridge-gg/merkle_drop` upstream).
- **Interfaces** (`interfaces.cairo`): Minimal `IERC721Read` so NFT-ownership bindings can call `owner_of` without dragging in `openzeppelin_token`.

### Implementor contract (`MerkledropTrait`)

| Method | Purpose |
|---|---|
| `get_recipient(data)` | Called by `claim` to decode `data` and return the address allowed to claim. NFT-gating: `ERC721.owner_of(token_id)` on the collection at `data[0]`. |
| `on_merkledrop_claim(root, leaf, receiver, data)` | Distribute the asset/access. Same hook for both claim paths. |

### Leaf data conventions

`data` is `Span<felt252>` and the component treats it opaquely except for path-specific prefixes:

- Bearer path: `[eth_address, ...payload]`
- Arcade path (NFT-gating example): `[collection, token_id_low, token_id_high, ...payload]`

A common convention is to keep payload at the end so the hook can extract it via `data[data.len() - 1]` without branching on the path.

### Testing

Unit tests live in `tests/test_merkledrop.cairo` and use snforge's `mock_call` to fake `owner_of` for the NFT path. The bearer path uses the same canonical test vector (`pk=0x420`, recipient `0x07db9cc...`, `v=28, r=0x8a..., s=0x20b6...`) as `cartridge-gg/merkle_drop`.

Run: `snforge test merkledrop`.
