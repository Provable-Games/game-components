//! Minter Token Contract Example
//!
//! This contract demonstrates the component-level approach for token functionality
//! with minter tracking. It uses MinterTokenComponent which provides core features
//! plus minter tracking functionality.

use starknet::ContractAddress;
use game_components_token_components::components::MinterTokenComponent;
use game_components_token_components::interface::{IMinigameToken, IMinterToken};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod MinterTokenContract {
    use super::*;

    // ✨ COMPONENT SELECTION - Choose the component variant you need!
    // MinterTokenComponent = Basic functionality + minter tracking
    component!(path: MinterTokenComponent, storage: token, event: TokenEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: MinterTokenComponent::Storage,
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
        TokenEvent: MinterTokenComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // 🎯 DIRECT EMBEDDING - Multiple interfaces from one component!
    #[abi(embed_v0)]
    impl TokenImpl = MinterTokenComponent::MinigameTokenImpl<ContractState>;
    
    // ✨ NEW! The component provides minter tracking interface too!
    #[abi(embed_v0)]
    impl MinterImpl = MinterTokenComponent::MinterTokenImpl<ContractState>;

    // Standard component implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // Internal implementations
    impl TokenInternalImpl = MinterTokenComponent::InternalImpl<ContractState>;
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
        
        // Initialize token component (includes minter tracking setup)
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
// USAGE NOTES - Component-Level Feature Composition
//================================================================================================

// ✅ This demonstrates feature addition through component selection!
// 
// 📊 Features in this contract:
// - ✅ Basic ERC721 functionality
// - ✅ Minigame token functionality (settings, objectives, game address)
// - ✅ Minter tracking: INCLUDED (component provides this automatically)
// - ❌ Multi-game support: NOT AVAILABLE (component doesn't include it)
// - ❌ Objectives tracking: NOT AVAILABLE (component doesn't include it)

//================================================================================================
// INTERFACE COMPARISON
//================================================================================================

// 🆚 CALLBACK APPROACH (original):
// - One TokenComponent with callback interfaces for optional features
// - Enable features by implementing callback traits
// - All features available, selectively enabled at contract level
//
// 🎯 COMPONENT APPROACH (this example):
// - Multiple component variants, each with different feature sets
// - Enable features by choosing the right component variant
// - Only chosen features available, enabled at component level

//================================================================================================
// COMPONENT SELECTION GUIDE
//================================================================================================

// 🔄 When to use each component variant:
//
// CoreTokenComponent:
// - ✅ Basic tokens with minimal features
// - ✅ Simple game mechanics
// - ✅ Performance-critical applications
//
// MinterTokenComponent (this example):
// - ✅ Need to track who minted each token
// - ✅ Analytics and attribution
// - ✅ Creator royalties or recognition
//
// FullFeaturedTokenComponent:
// - ✅ Complex gaming platforms
// - ✅ Need all features
// - ✅ Rapid prototyping 