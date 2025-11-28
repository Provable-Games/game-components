// Minimal Optimized Token Contract Example
// This demonstrates the optimal configurable direct components architecture

use starknet::ContractAddress;
use openzeppelin_token::erc721::ERC721Component;
use openzeppelin_introspection::src5::SRC5Component;

// Import the optimal components
use crate::core::core_token::CoreTokenComponent;
use crate::extensions::minter::minter::MinterComponent;
use crate::core::noop_traits::{
    NoOpObjectives, NoOpContext, NoOpSoulbound, NoOpRenderer, NoOpSettings,
};

// Override default configuration for minimal contract
mod config {
    pub const MINTER_ENABLED: bool = true; // Only enable minter
    pub const MULTI_GAME_ENABLED: bool = false; // Disable multi-game
    pub const OBJECTIVES_ENABLED: bool = false; // Disable objectives
    pub const SETTINGS_ENABLED: bool = false; // Disable settings
    pub const SOULBOUND_ENABLED: bool = false; // Disable soulbound
    pub const CONTEXT_ENABLED: bool = false; // Disable context
    pub const RENDERER_ENABLED: bool = false; // Disable renderer
}

#[starknet::contract]
mod MinimalOptimizedContract {
    use super::*;
    use openzeppelin_token::erc721::ERC721HooksEmptyImpl;

    // Only include enabled components
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    // No other components needed!

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
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
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl CoreTokenImpl = CoreTokenComponent::CoreTokenImpl<ContractState>;
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;

    // Internal implementations
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
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
        self.core_token.initializer(game_address, creator_address, Option::None, Option::None);

        // Only initialize enabled components
        if config::MINTER_ENABLED {
            self.minter.initializer();
        }
        // All other components are disabled - no initialization needed!
    }
}
