//! Simple Token Contract Example
//!
//! This demonstrates the most basic usage of TokenComponent with direct embedding.
//! The callback pattern is used, but all callbacks are set to default implementations.
//!
//! Features enabled: NONE (all callbacks are default/OFF)
//! Dependencies: Only TokenComponent + ERC721 + SRC5

use starknet::ContractAddress;

// Import token component and interfaces
use game_components_token::token::TokenComponent;
use game_components_token::interface::IMinigameToken;
use game_components_token::callbacks::{
    DefaultTokenMinterCallback, DefaultTokenContextCallback,
    DefaultTokenSoulboundCallback, DefaultTokenRendererCallback,
    DefaultTokenMultiGameCallback, DefaultTokenObjectivesCallback
};

// OpenZeppelin imports
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

/// Simple Token Contract - Direct Embedding with Default Callbacks
/// 
/// This contract shows how to directly embed TokenComponent::TokenImpl
/// while using the callback pattern with default implementations.
#[starknet::contract]
pub mod SimpleTokenContract {
    use super::*;

    // Component declarations
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
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
        TokenEvent: TokenComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // ✨ DIRECT EMBEDDING - The key is matching the trait bound names!
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;

    // 🔑 CALLBACK IMPLEMENTATIONS - Names must match trait bounds in TokenComponent::TokenImpl
    // The trait bounds are:
    // impl MinterCallback: TokenMinterCallback<TContractState>,
    // impl ContextCallback: TokenContextCallback<TContractState>,
    // impl SoulboundCallback: TokenSoulboundCallback<TContractState>,
    // impl RendererCallback: TokenRendererCallback<TContractState>,
    // impl MultiGameCallback: TokenMultiGameCallback<TContractState>,
    // impl ObjectivesCallback: TokenObjectivesCallback<TContractState>,

    impl MinterCallback = DefaultTokenMinterCallback<ContractState>;
    impl ContextCallback = DefaultTokenContextCallback<ContractState>;
    impl SoulboundCallback = DefaultTokenSoulboundCallback<ContractState>;
    impl RendererCallback = DefaultTokenRendererCallback<ContractState>;
    impl MultiGameCallback = DefaultTokenMultiGameCallback<ContractState>;
    impl ObjectivesCallback = DefaultTokenObjectivesCallback<ContractState>;

    // Standard component implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // Internal implementations
    impl TokenInternalImpl = TokenComponent::InternalImpl<ContractState>;
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
        ) {
            // No additional validation needed for simple token
        }

        fn after_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // No additional post-transfer logic needed
        }
    }
}

//================================================================================================
// USAGE NOTES - Direct Embedding with Callback Pattern
//================================================================================================

// ✅ This is the pattern you wanted! You can now:
// 1. Embed TokenComponent::TokenImpl directly
// 2. Use the callback pattern for flexibility
// 3. Switch features ON/OFF by changing callback implementations

// 🔑 THE KEY: Implementation names must match trait bound names in TokenComponent::TokenImpl

// From TokenComponent::TokenImpl trait bounds:
// impl MinterCallback: TokenMinterCallback<TContractState>,        ← Your impl name must be "MinterCallback"
// impl ContextCallback: TokenContextCallback<TContractState>,      ← Your impl name must be "ContextCallback"
// impl SoulboundCallback: TokenSoulboundCallback<TContractState>,  ← Your impl name must be "SoulboundCallback"
// impl RendererCallback: TokenRendererCallback<TContractState>,    ← Your impl name must be "RendererCallback"
// impl MultiGameCallback: TokenMultiGameCallback<TContractState>,  ← Your impl name must be "MultiGameCallback"
// impl ObjectivesCallback: TokenObjectivesCallback<TContractState>, ← Your impl name must be "ObjectivesCallback"

//================================================================================================
// SWITCHING FEATURES ON/OFF
//================================================================================================

// 🔄 To enable minter tracking:
// impl MinterCallback = DefaultTokenMinterCallback<ContractState>;     ← OFF (default)
// impl MinterCallback = ComponentTokenMinterCallback<ContractState>;   ← ON (uses MinterComponent)

// 🔄 To enable multi-game support:
// impl MultiGameCallback = DefaultTokenMultiGameCallback<ContractState>;     ← OFF (default)
// impl MultiGameCallback = ComponentTokenMultiGameCallback<ContractState>;   ← ON (uses MultiGameComponent)

// 🔄 To enable token objectives:
// impl ObjectivesCallback = DefaultTokenObjectivesCallback<ContractState>;     ← OFF (default)
// impl ObjectivesCallback = ComponentTokenObjectivesCallback<ContractState>;   ← ON (uses ObjectivesComponent)

//================================================================================================
// EXAMPLE: Adding Minter Tracking
//================================================================================================

// 1. Add MinterComponent to your contract:
// component!(path: MinterComponent, storage: minter, event: MinterEvent);

// 2. Add MinterComponent to storage:
// #[storage]
// struct Storage {
//     #[substorage(v0)]
//     minter: MinterComponent::Storage,
//     // ... other storage
// }

// 3. Add MinterComponent to events:
// #[event]
// #[derive(Drop, starknet::Event)]
// enum Event {
//     #[flat]
//     MinterEvent: MinterComponent::Event,
//     // ... other events
// }

// 4. Change the callback implementation:
// impl MinterCallback = ComponentTokenMinterCallback<ContractState>;

// 5. Initialize the component:
// fn constructor(ref self: ContractState, /* ... */) {
//     self.minter.initializer();
//     // ... other initializations
// }

//================================================================================================
// BENEFITS OF THIS APPROACH
//================================================================================================

// ✅ Direct embedding like you wanted
// ✅ Clean, minimal code
// ✅ Callback pattern for flexibility
// ✅ Easy to switch features ON/OFF
// ✅ No need to rewrite interface methods
// ✅ Type-safe feature management
// ✅ Extensible architecture 