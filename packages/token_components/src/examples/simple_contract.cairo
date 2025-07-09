//! Simple Token Contract Example
//!
//! This contract demonstrates the component-level approach for basic token functionality.
//! It uses CoreTokenComponent which provides only the essential features.

use starknet::ContractAddress;
use game_components_token_components::components::CoreTokenComponent;
use game_components_token_components::interface::IMinigameToken;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod SimpleTokenContract {
    use super::*;

    // ✨ COMPONENT SELECTION - Choose the component variant you need!
    // CoreTokenComponent = Basic ERC721 + minigame token functionality (no optional features)
    component!(path: CoreTokenComponent, storage: token, event: TokenEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: CoreTokenComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
    }

    // Events
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        TokenEvent: CoreTokenComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // 🎯 DIRECT EMBEDDING - The component provides everything you need!
    #[abi(embed_v0)]
    impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;

    // Standard component implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // Internal implementations
    impl TokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        game_address: Option<ContractAddress>,
    ) {
        // Initialize ERC721
        self.erc721.initializer(name, symbol, base_uri);
        
        // Initialize token component
        self.token.initializer(game_address);
    }

    // ERC721 Hooks implementation
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {}
    }
}

//================================================================================================
// USAGE NOTES - Component-Level Feature Selection
//================================================================================================

// ✅ This demonstrates the component-level approach!
// 
// 📊 Features in this contract:
// - ✅ Basic ERC721 functionality
// - ✅ Minigame token functionality (settings, objectives, game address)
// - ❌ Minter tracking: NOT AVAILABLE (component doesn't include it)
// - ❌ Multi-game support: NOT AVAILABLE (component doesn't include it)
// - ❌ Objectives tracking: NOT AVAILABLE (component doesn't include it)

//================================================================================================
// COMPONENT SELECTION PHILOSOPHY
//================================================================================================

// 🎯 Instead of enabling/disabling features with callbacks, you select the component variant:
//
// Want minter tracking? → Use MinterTokenComponent
// Want multi-game support? → Use MultiGameTokenComponent  
// Want all features? → Use FullFeaturedTokenComponent
//
// This approach has different trade-offs:
// 
// ✅ BENEFITS:
// - Compile-time feature selection (no runtime overhead)
// - Clear component boundaries
// - Each component is self-contained
// - No callback complexity
// - Interface segregation (only expose what you need)
//
// ❌ DRAWBACKS:
// - More component variants to maintain
// - Code duplication between components
// - Less flexible than callback approach
// - Harder to combine arbitrary feature sets 