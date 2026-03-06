// Minimal Optimized Token Contract Example
// This demonstrates the optimal configurable direct components architecture

// Import the optimal components - use actual package paths
use openzeppelin_interfaces::erc2981::IERC2981;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::common::erc2981::erc2981::{DefaultConfig, ERC2981Component};
use openzeppelin_token::erc721::ERC721Component;
use starknet::ContractAddress;
use crate::token::extensions::minter::minter::MinterComponent;
use crate::token::noop_traits::{
    NoOpContext, NoOpObjectives, NoOpRenderer, NoOpSettings, NoOpSkills, NoOpSoulbound,
};
use crate::token::token_component::CoreTokenComponent;

#[starknet::contract]
pub mod MinimalOptimizedContract {
    use core::num::traits::Zero;
    use openzeppelin_token::erc721::ERC721HooksEmptyImpl;
    use super::*;

    // Only include enabled components
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC2981Component, storage: erc2981, event: ERC2981Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    // No other components needed!

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc2981: ERC2981Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        core_token: CoreTokenComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        // Only ~25% of full contract storage!
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC2981Event: ERC2981Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        CoreTokenEvent: CoreTokenComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        // Only ~25% of full contract events!
    }

    // Implementations
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981InfoImpl = ERC2981Component::ERC2981InfoImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;

    // Simple ERC2981 implementation using default royalty
    #[abi(embed_v0)]
    impl ERC2981Impl of IERC2981<ContractState> {
        fn royalty_info(
            self: @ContractState, token_id: u256, sale_price: u256,
        ) -> (ContractAddress, u256) {
            let (receiver, _, royalty_fraction) = self.erc2981.default_royalty();
            let royalty_amount = if royalty_fraction > 0 && !receiver.is_zero() {
                (sale_price * royalty_fraction.into()) / 10000
            } else {
                0
            };
            (receiver, royalty_amount)
        }
    }

    // Internal implementations
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl ERC2981InternalImpl = ERC2981Component::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;

    // Optional trait implementations
    impl MinterOptionalImpl = MinterComponent::MinterOptionalImpl<ContractState>;
    impl ObjectivesOptionalImpl = NoOpObjectives<ContractState>; // Zero-cost NoOp
    impl SettingsOptionalImpl = NoOpSettings<ContractState>; // Zero-cost NoOp
    impl ContextOptionalImpl = NoOpContext<ContractState>; // Zero-cost NoOp
    impl SoulboundOptionalImpl = NoOpSoulbound<ContractState>; // Zero-cost NoOp
    impl RendererOptionalImpl = NoOpRenderer<ContractState>; // Zero-cost NoOp
    impl SkillsOptionalImpl = NoOpSkills<ContractState>; // Zero-cost NoOp

    // ERC721 hooks
    impl ERC721HooksImpl = ERC721HooksEmptyImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
        creator_address: Option<ContractAddress>,
    ) {
        // Initialize core components
        self.erc721.initializer(name, symbol, base_uri);
        // Initialize ERC2981 with creator as royalty receiver (500 = 5% default)
        let royalty_receiver = match creator_address {
            Option::Some(addr) => addr,
            Option::None => starknet::get_caller_address(),
        };
        self.erc2981.initializer(royalty_receiver, 500);
        self.core_token.initializer(game_address, creator_address, Option::None);

        // Initialize minter
        self.minter.initializer();
    }
}
