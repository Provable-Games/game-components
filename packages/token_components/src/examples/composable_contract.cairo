//! Composable Token Contract Example
//!
//! This contract demonstrates TRUE component composition where individual
//! feature components are mixed and matched to create exactly the token
//! functionality you need.
//!
//! Features can be enabled by simply including the component and embedding its interface.

use starknet::ContractAddress;
use game_components_token_components::components::{CoreTokenComponent, MinterComponent};
use game_components_token_components::interface::{IMinigameToken, IMinterToken};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod ComposableTokenContract {
    use super::*;

    // ✨ COMPONENT COMPOSITION - Mix and match the features you need!
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // 🎯 Want more features? Just add more components:
    // component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    // component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        core_token: CoreTokenComponent::Storage,
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
        CoreTokenEvent: CoreTokenComponent::Event,
        #[flat]
        MinterEvent: MinterComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // 🎯 SELECTIVE INTERFACE EMBEDDING - Only expose what you've included!
    #[abi(embed_v0)]
    impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;

    // Standard component implementations
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;

    // Internal implementations
    impl CoreTokenInternalImpl = CoreTokenComponent::InternalImpl<ContractState>;
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
        
        // Initialize core token component
        self.core_token.initializer(game_address);
        
        // Initialize optional components that are included
        self.minter.initializer();
    }

    // 🔗 COMPONENT ORCHESTRATION - Coordinate between components
    // Override the core mint function to orchestrate between components
    #[abi(per_item)]
    #[generate_trait]
    impl CustomMintImpl of CustomMintTrait {
        #[external(v0)]
        fn mint_with_composition(
            ref self: ContractState,
            to: ContractAddress,
            game_address: ContractAddress,
            settings_id: u32,
            objectives: Array<u32>,
        ) -> u64 {
            // 1. Mint using core component
            let token_id = self.core_token.mint(to, game_address, settings_id, objectives);
            
            // 2. If minter component is present, register the minter
            let minter_id = self.minter.register_minter(starknet::get_caller_address());
            self.minter.set_token_minter(token_id, minter_id);
            
            // 3. If other components were present, we'd coordinate with them here too
            // self.multi_game.handle_mint(token_id, game_address);
            // self.objectives.setup_objectives(token_id, objectives);
            
            token_id
        }
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
// COMPOSABILITY PATTERNS
//================================================================================================

// ✅ This demonstrates TRUE component composition!
// 
// 🎯 How to compose different feature sets:
//
// BASIC TOKEN (minimal features):
// component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
//
// BASIC + MINTER TRACKING:
// component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
// component!(path: MinterComponent, storage: minter, event: MinterEvent);
//
// BASIC + MULTI-GAME + OBJECTIVES:
// component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
// component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
// component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
//
// ALL FEATURES:
// component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
// component!(path: MinterComponent, storage: minter, event: MinterEvent);
// component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
// component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);

//================================================================================================
// BENEFITS OF TRUE COMPOSITION
//================================================================================================

// ✅ COMPOSABILITY:
// - Any combination of features possible
// - Add/remove features by including/excluding components
// - No pre-built variants needed

// ✅ MAINTAINABILITY:
// - Each feature is its own component
// - Features can be updated independently
// - Clear separation of concerns

// ✅ REUSABILITY:
// - Components can be used across different token types
// - Features are decoupled from each other
// - Easy to test individual features

// ✅ INTERFACE CLARITY:
// - Only interfaces for included features are exposed
// - No callback complexity
// - Direct component method calls

//================================================================================================
// ORCHESTRATION PATTERN
//================================================================================================

// 🎼 The key insight is ORCHESTRATION:
//
// Instead of callbacks, the contract coordinates between components:
//
// 1. Core component handles the base functionality
// 2. Contract orchestrates calls to optional components
// 3. Each component focuses on its specific feature
// 4. Contract composition determines which features are active

// This provides:
// ✅ Full composability (any feature combination)
// ✅ No callback complexity (direct method calls)
// ✅ Clear component boundaries (single responsibility)
// ✅ Compile-time optimization (only included features)

//================================================================================================
// COMPARISON: CALLBACK vs COMPOSITION
//================================================================================================

// 🆚 CALLBACK APPROACH:
// - One component with optional callbacks
// - Runtime feature enabling via trait implementation
// - All features compiled, selectively enabled
//
// 🎯 COMPOSITION APPROACH:
// - Multiple focused components
// - Compile-time feature selection via component inclusion
// - Only included features compiled
// - Contract orchestrates between components

// Both achieve the same goal (selective features) with different trade-offs! 