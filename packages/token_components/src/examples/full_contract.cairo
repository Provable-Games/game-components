//! Full-Featured Token Contract - All Components Composed
//!
//! This contract demonstrates the maximum composition: all available individual
//! components working together with contract-level orchestration.
//!
//! Features included:
//! - Core Token: ERC721 + basic minigame token functionality
//! - Minter: Minter tracking and analytics
//! - Multi-Game: Support for multiple games per token
//! - Objectives: Objectives and achievements tracking

use starknet::ContractAddress;
use game_components_token_components::components::{
    CoreTokenComponent, MinterComponent, MultiGameComponent, ObjectivesComponent
};
use game_components_token_components::interface::{
    IMinigameToken, IMinterToken, IMultiGameToken, IObjectivesToken
};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_token::erc721::ERC721Component;

#[starknet::contract]
pub mod FullFeaturedTokenContract {
    use super::*;

    // 🎯 ALL COMPONENTS COMPOSED - This is the maximum configuration!
    component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
    component!(path: MinterComponent, storage: minter, event: MinterEvent);
    component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
    component!(path: ObjectivesComponent, storage: objectives, event: ObjectivesEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);

    // Storage
    #[storage]
    struct Storage {
        #[substorage(v0)]
        core_token: CoreTokenComponent::Storage,
        #[substorage(v0)]
        minter: MinterComponent::Storage,
        #[substorage(v0)]
        multi_game: MultiGameComponent::Storage,
        #[substorage(v0)]
        objectives: ObjectivesComponent::Storage,
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
        MultiGameEvent: MultiGameComponent::Event,
        #[flat]
        ObjectivesEvent: ObjectivesComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        ERC721Event: ERC721Component::Event,
    }

    // 🎯 ALL INTERFACES EMBEDDED - Full API surface!
    #[abi(embed_v0)]
    impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MinterImpl = MinterComponent::MinterImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
    
    #[abi(embed_v0)]
    impl ObjectivesImpl = ObjectivesComponent::ObjectivesImpl<ContractState>;

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
    impl MultiGameInternalImpl = MultiGameComponent::InternalImpl<ContractState>;
    impl ObjectivesInternalImpl = ObjectivesComponent::InternalImpl<ContractState>;
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
        // Initialize base components
        self.erc721.initializer(name, symbol, base_uri);
        self.core_token.initializer(game_address);
        
        // Initialize all feature components
        self.minter.initializer();
        self.multi_game.initializer();
        self.objectives.initializer();
    }

    // 🎼 FULL ORCHESTRATION - All components working together!
    #[abi(per_item)]
    #[generate_trait]
    impl FullOrchestrationImpl of FullOrchestrationTrait {
        #[external(v0)]
        fn mint_full_featured(
            ref self: ContractState,
            to: ContractAddress,
            game_address: ContractAddress,
            settings_id: u32,
            objectives: Array<u32>,
            additional_games: Array<ContractAddress>,
        ) -> u64 {
            // 1. Core minting
            let token_id = self.core_token.mint(to, game_address, settings_id, objectives);
            
            // 2. Minter tracking
            let minter_id = self.minter.register_minter(starknet::get_caller_address());
            self.minter.set_token_minter(token_id, minter_id);
            
            // 3. Multi-game support
            let primary_game_id = self.multi_game.register_game(game_address);
            self.multi_game.associate_token_with_game(token_id, primary_game_id);
            
            // Associate with additional games
            let mut i = 0;
            while i < additional_games.len() {
                let game_id = self.multi_game.register_game(*additional_games.at(i));
                self.multi_game.associate_token_with_game(token_id, game_id);
                i += 1;
            };
            
            // 4. Objectives setup
            self.objectives.setup_objectives(token_id, objectives);
            
            token_id
        }

        #[external(v0)]
        fn complete_objective_with_rewards(
            ref self: ContractState,
            token_id: u64,
            objective_id: u32,
            reward_game: ContractAddress,
        ) {
            // 1. Complete the objective
            self.objectives.complete_objective(token_id, objective_id);
            
            // 2. As a reward, associate token with new game
            let game_id = self.multi_game.register_game(reward_game);
            self.multi_game.associate_token_with_game(token_id, game_id);
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
// FULL FEATURE ORCHESTRATION
//================================================================================================

// 🎼 This contract demonstrates the power of true component composition!
//
// Each component focuses on its specific responsibility:
// - CoreTokenComponent: Basic token functionality
// - MinterComponent: Tracks who minted what
// - MultiGameComponent: Associates tokens with multiple games
// - ObjectivesComponent: Manages objectives and achievements
//
// The contract orchestrates between them to create complex behaviors:
// 1. mint_full_featured(): Uses all components to create a fully-featured token
// 2. complete_objective_with_rewards(): Coordinates between objectives and multi-game
//
// This shows how composition enables emergent behaviors through orchestration!

//================================================================================================
// BENEFITS DEMONSTRATED
//================================================================================================

// ✅ SINGLE RESPONSIBILITY:
// - Each component has one clear job
// - Changes to one feature don't affect others
// - Easy to test individual components

// ✅ COMPOSABILITY:
// - Any combination of components possible
// - Contract determines which features to use
// - Runtime coordination between components

// ✅ INTERFACE SEGREGATION:
// - Each component exposes only its interface
// - Clients only see what they need
// - No interface pollution

// ✅ EXTENSIBILITY:
// - New components can be added without changing existing ones
// - New orchestration patterns can be created
// - Components can be reused across different contracts

//================================================================================================
// REAL-WORLD USAGE PATTERNS
//================================================================================================

// 🎯 GAMING PLATFORM TOKEN:
// - Core token for identity
// - Minter tracking for analytics
// - Multi-game for platform integration
// - Objectives for progression system

// 🎯 ACHIEVEMENT SYSTEM:
// - Core token for achievements
// - Objectives for tracking progress
// - Multi-game for cross-game achievements
// - Minter tracking for attribution

// 🎯 NFT MARKETPLACE:
// - Core token for NFT functionality
// - Minter tracking for royalties
// - Multi-game for interoperability
// - Objectives for rarity systems

// This full composition provides maximum flexibility while maintaining clear boundaries! 