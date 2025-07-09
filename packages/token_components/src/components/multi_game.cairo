//! Multi-Game Component - Pure Multi-Game Support Functionality
//!
//! This component provides only multi-game support functionality and can be
//! composed with any other token component to add multi-game capabilities.
//!
//! ## Composition Example
//! ```cairo
//! component!(path: CoreTokenComponent, storage: core_token, event: CoreTokenEvent);
//! component!(path: MultiGameComponent, storage: multi_game, event: MultiGameEvent);
//! 
//! // Embed both interfaces
//! #[abi(embed_v0)]
//! impl TokenImpl = CoreTokenComponent::MinigameTokenImpl<ContractState>;
//! #[abi(embed_v0)]
//! impl MultiGameImpl = MultiGameComponent::MultiGameImpl<ContractState>;
//! ```

use starknet::ContractAddress;
use starknet::storage::{
    StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Map,
};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::InternalTrait as SRC5InternalTrait;
use crate::interface::IMultiGameToken;

#[starknet::component]
pub mod MultiGameComponent {
    use super::*;

    #[storage]
    pub struct Storage {
        game_registry: Map<ContractAddress, u64>, // game_address -> game_id
        game_registry_id: Map<u64, ContractAddress>, // game_id -> game_address
        game_count: u64,
        // Track which games a token is associated with
        token_games: Map<u64, Map<u64, bool>>, // token_id -> game_id -> is_associated
        // Track tokens per game
        game_tokens: Map<u64, Map<u64, bool>>, // game_id -> token_id -> exists
        game_token_counts: Map<u64, u64>, // game_id -> token_count
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        GameRegistered: GameRegistered,
        TokenGameAssociation: TokenGameAssociation,
    }

    #[derive(Drop, starknet::Event)]
    pub struct GameRegistered {
        pub game_id: u64,
        pub game_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenGameAssociation {
        pub token_id: u64,
        pub game_id: u64,
        pub associated: bool,
    }

    #[embeddable_as(MultiGameImpl)]
    impl MultiGame<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IMultiGameToken<ComponentState<TContractState>> {
        fn game_address(self: @ComponentState<TContractState>, game_id: u64) -> ContractAddress {
            self.game_registry_id.entry(game_id).read()
        }

        fn game_count(self: @ComponentState<TContractState>) -> u64 {
            self.game_count.read()
        }

        fn is_token_associated_with_game(self: @ComponentState<TContractState>, token_id: u64, game_id: u64) -> bool {
            self.token_games.entry(token_id).entry(game_id).read()
        }

        fn game_token_count(self: @ComponentState<TContractState>, game_id: u64) -> u64 {
            self.game_token_counts.entry(game_id).read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        impl SRC5: SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // Register the IMultiGameToken interface
            let mut src5_component = get_dep_component_mut!(ref self, SRC5);
            src5_component.register_interface(0x123456789abcdef0); // IMultiGameToken interface ID
        }

        /// Register a game and return its ID
        /// This is called when a token is minted for a new game
        fn register_game(ref self: ComponentState<TContractState>, game_address: ContractAddress) -> u64 {
            let game_count = self.game_count.read();
            let game_id = self.game_registry.entry(game_address).read();

            let mut registered_game_id: u64 = 0;

            // If game is not registered, register it
            if game_id == 0 {
                registered_game_id = game_count + 1;
                self.game_registry.entry(game_address).write(registered_game_id);
                self.game_registry_id.entry(registered_game_id).write(game_address);
                self.game_count.write(registered_game_id);
                
                self.emit(GameRegistered { game_id: registered_game_id, game_address });
            } else {
                registered_game_id = game_id;
            }

            registered_game_id
        }

        /// Associate a token with a game
        /// Called by the core token component or orchestration layer
        fn associate_token_with_game(ref self: ComponentState<TContractState>, token_id: u64, game_id: u64) {
            // Check if already associated
            if self.token_games.entry(token_id).entry(game_id).read() {
                return;
            }

            // Associate token with game
            self.token_games.entry(token_id).entry(game_id).write(true);
            self.game_tokens.entry(game_id).entry(token_id).write(true);
            
            // Update game token count
            let current_count = self.game_token_counts.entry(game_id).read();
            self.game_token_counts.entry(game_id).write(current_count + 1);
            
            self.emit(TokenGameAssociation { token_id, game_id, associated: true });
        }

        /// Disassociate a token from a game
        /// Called when a token is no longer associated with a game
        fn disassociate_token_from_game(ref self: ComponentState<TContractState>, token_id: u64, game_id: u64) {
            // Check if actually associated
            if !self.token_games.entry(token_id).entry(game_id).read() {
                return;
            }

            // Disassociate token from game
            self.token_games.entry(token_id).entry(game_id).write(false);
            self.game_tokens.entry(game_id).entry(token_id).write(false);
            
            // Update game token count
            let current_count = self.game_token_counts.entry(game_id).read();
            if current_count > 0 {
                self.game_token_counts.entry(game_id).write(current_count - 1);
            }
            
            self.emit(TokenGameAssociation { token_id, game_id, associated: false });
        }
    }
} 