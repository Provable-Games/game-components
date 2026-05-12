//! Mock dungeon contract for merkledrop integration tests.
//!
//! Implements both `MerkledropTrait` methods:
//!   - `get_recipient`: returns `owner_of` on the NFT (collection, token_id)
//!     committed in `data[0..3]`.
//!   - `on_merkledrop_claim`: stores a boolean access flag keyed by
//!     `(receiver, dungeon_id)` where `dungeon_id` is the last data element.

use starknet::ContractAddress;
use crate::merkledrop::signature::EthereumSignature;

#[starknet::interface]
pub trait IMockDungeon<T> {
    fn register_drop(ref self: T, data: Span<Span<felt252>>, end: u64) -> felt252;
    fn register_drop_root(ref self: T, root: felt252, end: u64) -> felt252;
    fn claim(
        ref self: T,
        root: felt252,
        proofs: Span<felt252>,
        data: Span<felt252>,
        receiver: ContractAddress,
    );
    fn claim_with_eth_signature(
        ref self: T,
        root: felt252,
        proofs: Span<felt252>,
        data: Span<felt252>,
        receiver: ContractAddress,
        signature: EthereumSignature,
    );
    fn has_access(self: @T, account: ContractAddress, dungeon_id: u32) -> bool;
    fn is_consumed(self: @T, root: felt252, leaf_hash: felt252) -> bool;
    fn tree_expiry(self: @T, root: felt252) -> u64;
}

#[starknet::contract]
pub mod MockDungeon {
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::merkledrop::interfaces::{IERC721ReadDispatcher, IERC721ReadDispatcherTrait};
    use crate::merkledrop::merkledrop_component::MerkledropComponent;
    use crate::merkledrop::merkledrop_component::MerkledropComponent::InternalTrait;
    use crate::merkledrop::signature::EthereumSignature;

    component!(path: MerkledropComponent, storage: merkledrop, event: MerkledropEvent);

    impl MerkledropInternalImpl = MerkledropComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        access: Map<(ContractAddress, u32), bool>,
        #[substorage(v0)]
        merkledrop: MerkledropComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MerkledropEvent: MerkledropComponent::Event,
    }

    #[abi(embed_v0)]
    impl MockDungeonImpl of super::IMockDungeon<ContractState> {
        fn register_drop(ref self: ContractState, data: Span<Span<felt252>>, end: u64) -> felt252 {
            self.merkledrop.register(data, end)
        }

        fn register_drop_root(ref self: ContractState, root: felt252, end: u64) -> felt252 {
            self.merkledrop.register_root(root, end)
        }

        fn claim(
            ref self: ContractState,
            root: felt252,
            proofs: Span<felt252>,
            data: Span<felt252>,
            receiver: ContractAddress,
        ) {
            self.merkledrop.claim(root, proofs, data, receiver);
        }

        fn claim_with_eth_signature(
            ref self: ContractState,
            root: felt252,
            proofs: Span<felt252>,
            data: Span<felt252>,
            receiver: ContractAddress,
            signature: EthereumSignature,
        ) {
            self.merkledrop.claim_with_eth_signature(root, proofs, data, receiver, signature);
        }

        fn has_access(self: @ContractState, account: ContractAddress, dungeon_id: u32) -> bool {
            self.access.entry((account, dungeon_id)).read()
        }
        fn is_consumed(self: @ContractState, root: felt252, leaf_hash: felt252) -> bool {
            self.merkledrop.is_consumed(root, leaf_hash)
        }
        fn tree_expiry(self: @ContractState, root: felt252) -> u64 {
            self.merkledrop.tree_expiry(root)
        }
    }

    impl MerkledropImpl of MerkledropComponent::MerkledropTrait<ContractState> {
        fn get_recipient(
            self: @MerkledropComponent::ComponentState<ContractState>, data: Span<felt252>,
        ) -> ContractAddress {
            assert!(data.len() >= 3, "MockDungeon: leaf missing nft binding");
            let collection: ContractAddress = (*data.at(0)).try_into().unwrap();
            let lo: u128 = (*data.at(1)).try_into().unwrap();
            let hi: u128 = (*data.at(2)).try_into().unwrap();
            let token_id = u256 { low: lo, high: hi };
            IERC721ReadDispatcher { contract_address: collection }.owner_of(token_id)
        }

        fn on_merkledrop_claim(
            ref self: MerkledropComponent::ComponentState<ContractState>,
            root: felt252,
            leaf: felt252,
            receiver: ContractAddress,
            data: Span<felt252>,
        ) {
            let _ = (root, leaf);
            assert!(data.len() >= 2, "MockDungeon: leaf missing dungeon_id");
            let dungeon_id: u32 = (*data.at(data.len() - 1)).try_into().unwrap();
            let mut contract = self.get_contract_mut();
            contract.access.entry((receiver, dungeon_id)).write(true);
        }
    }
}
