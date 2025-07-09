// Multi-game hooks implementation that accesses MultiGameComponent storage
// This shows how to access multi-game storage from hooks when your contract has it

use starknet::{ContractAddress, get_caller_address};
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
use crate::token::TokenComponent;
use crate::token::TokenComponent::InternalTrait;
use crate::libs::validation::validation;
use crate::libs::objectives_update::objectives_update;
use crate::libs::multi_game_update::multi_game_update;
use crate::extensions::objectives::objectives::TokenObjectivesComponent;
use crate::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
use crate::extensions::minter::minter::MinterComponent;
use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;
use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
use crate::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
use crate::extensions::multi_game::interface::{IMINIGAME_TOKEN_MULTIGAME_ID, IMinigameTokenMultiGame};
use crate::extensions::multi_game::multi_game::MultiGameComponent;
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use openzeppelin_introspection::src5::SRC5Component;
use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
use game_components_minigame::interface::{
    IMINIGAME_ID, IMinigameDispatcher, IMinigameDispatcherTrait,
};

// This implementation shows how to access MultiGameComponent from hooks
// Note: Your contract must have MultiGameComponent in its storage
pub impl TokenHooksMultiGameAccessImpl<
    TContractState,
    +TokenComponent::HasComponent<TContractState>,
    +SRC5Component::HasComponent<TContractState>,
    +MinterComponent::HasComponent<TContractState>,
    +MultiGameComponent::HasComponent<TContractState>,
    +TokenObjectivesComponent::HasComponent<TContractState>,
    +IMinigameTokenMultiGame<TContractState>,
    +Drop<TContractState>
> of TokenComponent::TokenHooksTrait<TContractState> {
    fn before_mint(
        ref self: TokenComponent::ComponentState<TContractState>,
        to: ContractAddress,
        game_address: Option<ContractAddress>,
        settings_id: Option<u32>,
        objective_ids: Option<Span<u32>>,
    ) -> (u64, u32, u32) {
        match game_address {
            Option::Some(game_addr) => {
                // Validate game supports IMinigame
                validation::validate_game_address(game_addr);
                
                // Use multi_game_update library to resolve game ID
                let contract = self.get_contract();
                let game_id = multi_game_update::resolve_game_id_for_mint(
                    contract,
                    game_addr,
                    self.game_address.read()
                );
                
                // Validate settings and objectives
                let validated_settings_id = validation::validate_settings(
                    game_addr, settings_id, true // Assume settings supported for multi-game
                );
                let objectives_count = validation::validate_objectives(
                    game_addr, objective_ids, true // Assume objectives supported for multi-game
                );
                
                (game_id, validated_settings_id, objectives_count)
            },
            Option::None => {
                // Blank NFT support - assume settings are supported for multi-game tokens
                (0, 0, 0)
            },
        }
    }
    
    fn after_mint(
        ref self: TokenComponent::ComponentState<TContractState>,
        to: ContractAddress,
        token_id: u64,
        caller_address: ContractAddress,
        game_address: Option<ContractAddress>,
        token_metadata: crate::structs::TokenMetadata,
    ) {
        let mut contract = self.get_contract_mut();
        // Always add minter since we require MinterComponent
        let mut minter = MinterComponent::HasComponent::<TContractState>::get_component_mut(ref contract);
        minter.add_minter(caller_address);
    }
    
    fn before_update_game(
        ref self: TokenComponent::ComponentState<TContractState>,
        token_id: u64,
        token_metadata: crate::structs::TokenMetadata,
    ) -> ContractAddress {
        // Get the correct game address based on token's game_id
        if token_metadata.game_id > 0 {
            // Multi-game token - get address from component
            let contract = self.get_contract();
            contract.game_address_from_id(token_metadata.game_id)
        } else {
            // Single game token - use default
            self.game_address.read()
        }
    }
    
    fn after_update_game(
        ref self: TokenComponent::ComponentState<TContractState>,
        token_id: u64,
    ) -> bool {
        // Get token metadata to check objectives
        let token_metadata = self.token_metadata.entry(token_id).read();
        
        if token_metadata.objectives_count > 0 {
            // Get the game address (already determined in before_update_game)
            let game_address = if token_metadata.game_id > 0 {
                let contract = self.get_contract();
                contract.game_address_from_id(token_metadata.game_id)
            } else {
                self.game_address.read()
            };
            
            // Process objectives using the library
            let mut contract = self.get_contract_mut();
            let all_completed = objectives_update::process_token_objectives(
                ref contract,
                token_id,
                game_address,
                token_metadata.objectives_count.into()
            );

            all_completed
        } else {
            false
        }
    }
}