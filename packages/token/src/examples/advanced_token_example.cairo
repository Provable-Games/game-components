//! Advanced Token Contract Example
//!
//! This demonstrates how to enable selective features using direct embedding.
//! Shows minter tracking enabled while other features remain OFF.

use starknet::ContractAddress;
use game_components_token::token::TokenComponent;
use game_components_token::interface::IMinigameToken;
use game_components_token::callbacks::{
    DefaultTokenContextCallback, DefaultTokenSoulboundCallback,
    DefaultTokenRendererCallback, DefaultTokenMultiGameCallback,
    DefaultTokenObjectivesCallback
};
use game_components_token::extensions::minter::minter::MinterComponent;
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod AdvancedTokenContract {
    use super::*;

    // Component declarations
    component!(path: TokenComponent, storage: token, event: TokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        token: TokenComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
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
        MinterEvent: MinterComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // ✨ DIRECT EMBEDDING with selective feature enablement
    #[abi(embed_v0)]
    impl TokenImpl = TokenComponent::TokenImpl<ContractState>;

    // 🔑 CALLBACK IMPLEMENTATIONS - Names must match trait bounds
    // ✅ MinterCallback: ENABLED (uses MinterComponent)
    impl MinterCallback of game_components_token::interface::TokenMinterCallback<ContractState> {
        fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
            self.minter.add_minter(minter_address)
        }
    }

    // ❌ All other callbacks: DISABLED (use defaults)
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
    impl MinterInternalImpl = MinterComponent::InternalImpl<ContractState>;
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
        
        // Initialize minter component (enables minter tracking)
        self.minter.initializer();
    }

    // ERC721 Hooks implementation
    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress,
        ) {
            // No additional validation needed
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
// USAGE NOTES - Selective Feature Enablement
//================================================================================================

// ✅ This demonstrates the power of the callback pattern with direct embedding!
// 
// 📊 Features in this example:
// - ✅ Minter tracking: ENABLED (custom implementation using MinterComponent)
// - ❌ Context: DISABLED (default implementation)
// - ❌ Soulbound: DISABLED (default implementation)
// - ❌ Renderer: DISABLED (default implementation)
// - ❌ Multi-game: DISABLED (default implementation)
// - ❌ Objectives: DISABLED (default implementation)

//================================================================================================
// PATTERN COMPARISON
//================================================================================================

// 🆚 OLD WAY (before direct embedding):
// impl MinterCallbackImpl of game_components_token::interface::TokenMinterCallback<ContractState> {
//     fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
//         self.minter.add_minter(minter_address)
//     }
// }
// 
// #[abi(embed_v0)]
// impl TokenImpl of IMinigameToken<ContractState> {
//     fn mint(ref self: ContractState, /* ... */) -> u64 { self.token.mint(/* ... */) }
//     fn settings_id(self: @ContractState, token_id: u64) -> u32 { self.token.settings_id(token_id) }
//     // ... repeat all interface methods
// }

// ✅ NEW WAY (with direct embedding):
// impl MinterCallback of game_components_token::interface::TokenMinterCallback<ContractState> {
//     fn on_mint_with_minter(ref self: ContractState, minter_address: ContractAddress) -> u64 {
//         self.minter.add_minter(minter_address)
//     }
// }
// 
// #[abi(embed_v0)]
// impl TokenImpl = TokenComponent::TokenImpl<ContractState>;  // ✨ Direct embedding!

//================================================================================================
// SWITCHING MORE FEATURES ON
//================================================================================================

// 🔄 To enable objectives tracking:
// 1. Add ObjectivesComponent:
//    component!(path: TokenObjectivesComponent, storage: objectives, event: ObjectivesEvent);
// 
// 2. Replace the default callback:
//    impl ObjectivesCallback of game_components_token::interface::TokenObjectivesCallback<ContractState> {
//        fn get_objective(ref self: ContractState, token_id: u64, objective_index: u32) -> TokenObjective {
//            self.objectives.get_objective(token_id, objective_index)
//        }
//        fn set_objective(ref self: ContractState, token_id: u64, objective_index: u32, objective: TokenObjective) {
//            self.objectives.set_objective(token_id, objective_index, objective)
//        }
//    }
// 
// 3. Initialize the component:
//    self.objectives.initializer();

//================================================================================================
// BENEFITS
//================================================================================================

// ✅ Direct embedding like you wanted
// ✅ Clean, readable code
// ✅ Selective feature enablement
// ✅ No interface method duplication
// ✅ Type-safe callback switching
// ✅ Easy to add/remove features
// ✅ Modular architecture
// ✅ Automatic SRC5 interface registration 