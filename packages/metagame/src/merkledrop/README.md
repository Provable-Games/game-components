# Merkle Drop

Single-use merkle-drop component for distributing on-chain access / assets, with two interchangeable claim paths sharing one nullifier and one callback.

## Features

- **On-chain tree building** (`alexandria_merkle_tree` Poseidon) — operator submits raw leaf data, contract computes the root, stores it, emits per-leaf proof events for off-chain pipelines to consume.
- **Two claim paths**:
  1. `claim` — arcade-style, gated by an implementor-defined `get_recipient(data)`. Used for NFT-ownership, allowlists, etc.
  2. `claim_with_eth_signature` — bearer credential. Leaf's `data[0]` is an EVM address; the caller submits a secp256k1 personal_sign signature over `receiver`. Used for QR-code drops.
- **Single-use nullifier** per `(root, leaf_hash)` regardless of claim path.
- **Configurable expiry** per tree.
- **Callback hook** `on_merkledrop_claim(root, leaf, receiver, data)` for the implementing contract to mint / transfer / grant.

## Architecture

| Module | Purpose |
|---|---|
| `merkledrop_component.cairo` | Starknet component with storage, register + two claim entrypoints, hook trait |
| `signature.cairo` | EIP-191 personal_sign helpers for the bearer path |
| `interfaces.cairo` | Minimal `IERC721Read` so the NFT-ownership pattern can call `owner_of` without pulling `openzeppelin_token` |

## Interface

### `MerkledropTrait` (implementor)

| Method | Purpose |
|---|---|
| `get_recipient(data) -> ContractAddress` | Decode `data` and return who is allowed to call `claim`. Implementations decide the binding (NFT owner, hardcoded address, multisig, …). |
| `on_merkledrop_claim(root, leaf, receiver, data)` | Distribute the asset / access after verification succeeds. Same hook for both claim paths. |

### `InternalImpl` (component)

| Method | Purpose |
|---|---|
| `register(data, end) -> felt252` | Build the tree from `data: Span<Span<felt252>>`, store root, emit events. Returns the root. |
| `claim(root, proofs, data, receiver)` | Arcade-style claim path. Asserts `caller == get_recipient(data)`. |
| `claim_with_eth_signature(root, proofs, data, receiver, sig)` | Bearer claim path. `data[0]` is the EVM address; `sig` must verify over `receiver`. |
| `is_consumed(root, leaf_hash) -> bool` | Read the nullifier. |
| `tree_expiry(root) -> u64` | Read a tree's expiry (0 if not registered). |

## Leaf data conventions

Leaf data is `Span<felt252>` — the contract treats it opaquely except for the first few slots needed by the claim path:

- **Bearer path** (`claim_with_eth_signature`):
  ```
  [eth_address, ...payload]
  ```
  `data[0]` must be the EVM address. Remaining slots are the implementor's payload (e.g. asset id, amount).

- **Arcade path** (`claim`):
  Layout is fully determined by the implementor's `get_recipient`. Common shape for NFT-gating:
  ```
  [collection, token_id_low, token_id_high, ...payload]
  ```
  `get_recipient` reads these and returns `ERC721.owner_of(token_id)` on `collection`.

A common convention is to put implementor-specific payload (e.g. `dungeon_id`) at the **end** of `data`, so both layouts can be read with `data[data.len() - 1]` without branching.

## Off-chain pipeline

The `register` call emits one `LeafRegistered` event per leaf containing the merkle proof. Off-chain code (e.g. a QR-generation tool) reads the tx receipt and assembles per-leaf claim URLs. See [cartridge-gg/qr-drops](https://github.com/Provable-Games/qr-drops) for a working pipeline.

## Example

```cairo
use game_components_metagame::merkledrop::merkledrop_component::MerkledropComponent;
use game_components_metagame::merkledrop::interfaces::{
    IERC721ReadDispatcher, IERC721ReadDispatcherTrait,
};

#[starknet::contract]
mod MyDungeon {
    use super::*;

    component!(path: MerkledropComponent, storage: merkledrop, event: MerkledropEvent);
    impl MerkledropInternalImpl = MerkledropComponent::InternalImpl<ContractState>;

    impl MerkledropImpl of MerkledropComponent::MerkledropTrait<ContractState> {
        fn get_recipient(
            self: @MerkledropComponent::ComponentState<ContractState>,
            data: Span<felt252>,
        ) -> starknet::ContractAddress {
            let collection: starknet::ContractAddress = (*data.at(0)).try_into().unwrap();
            let lo: u128 = (*data.at(1)).try_into().unwrap();
            let hi: u128 = (*data.at(2)).try_into().unwrap();
            IERC721ReadDispatcher { contract_address: collection }
                .owner_of(u256 { low: lo, high: hi })
        }

        fn on_merkledrop_claim(
            ref self: MerkledropComponent::ComponentState<ContractState>,
            root: felt252,
            leaf: felt252,
            receiver: starknet::ContractAddress,
            data: Span<felt252>,
        ) {
            // Mint / transfer / grant whatever to `receiver`.
        }
    }
}
```
