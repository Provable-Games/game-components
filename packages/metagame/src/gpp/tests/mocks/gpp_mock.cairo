// SPDX-License-Identifier: BUSL-1.1

/// Mock embedding GppComponent, exposing the internal slot/prize lifecycle so
/// tests can drive it directly.
#[starknet::contract]
pub mod GppMock {
    use game_components_interfaces::gpp::GppERC721Prize;
    use openzeppelin_introspection::src5::SRC5Component;
    use starknet::ContractAddress;
    use crate::gpp::gpp_component::{GppComponent, GppHooksEmptyImpl};
    use crate::gpp::store::Store;

    component!(path: GppComponent, storage: gpp, event: GppEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[abi(embed_v0)]
    impl GppImpl = GppComponent::GppImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    impl GppInternalImpl = GppComponent::GppInternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        gpp: GppComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GppEvent: GppComponent::Event,
        SRC5Event: SRC5Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.gpp.initializer();
    }

    #[abi(per_item)]
    #[generate_trait]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn configure(ref self: ContractState, context_id: u64, capacity: u32, game_lifetime: u32) {
            self.gpp._configure(context_id, capacity, game_lifetime);
        }

        #[external(v0)]
        fn fund_erc721(
            ref self: ContractState,
            context_id: u64,
            sponsor: ContractAddress,
            token_address: ContractAddress,
            nft_id: u128,
        ) {
            self
                .gpp
                ._fund_erc721(
                    context_id, sponsor, token_address, GppERC721Prize { token_id: nft_id },
                );
        }

        #[external(v0)]
        fn reserve_slot(ref self: ContractState, context_id: u64, game_token_id: felt252) {
            self.gpp._reserve_slot(context_id, game_token_id);
        }

        #[external(v0)]
        fn release_slot(ref self: ContractState, context_id: u64, game_token_id: felt252) {
            self.gpp._release_slot(context_id, game_token_id);
        }

        #[external(v0)]
        fn claim_prize(
            ref self: ContractState,
            context_id: u64,
            game_token_id: felt252,
            recipient: ContractAddress,
        ) {
            self.gpp._claim_prize(context_id, game_token_id, recipient);
        }

        /// Which NFT is reserved for this (context, token) pair.
        #[external(v0)]
        fn reserved_nft(self: @ContractState, context_id: u64, game_token_id: felt252) -> u128 {
            Store::get_token_nft(self.gpp, context_id, game_token_id)
        }

        /// Read a slot of a context's NFT stack.
        #[external(v0)]
        fn nft_at(self: @ContractState, context_id: u64, index: u32) -> u128 {
            Store::get_nft_at(self.gpp, context_id, index)
        }

        #[external(v0)]
        fn nft_top(self: @ContractState, context_id: u64) -> u32 {
            Store::get_pool(self.gpp, context_id).nft_top
        }
    }
}
