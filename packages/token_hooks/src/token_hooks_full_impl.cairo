// Full implementation of TokenHooks trait with all standard validations
// This provides the same functionality as full_hooks_token.cairo but as a reusable trait

use starknet::ContractAddress;
use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry};
use crate::token::TokenComponent;
use crate::libs::validation::validation;
use crate::extensions::minter::minter::MinterComponent;
use crate::extensions::minter::minter::MinterComponent::InternalTrait as MinterInternalTrait;
use crate::extensions::objectives::objectives::TokenObjectivesComponent;
use crate::extensions::objectives::objectives::TokenObjectivesComponent::InternalTrait as TokenObjectivesInternalTrait;
use crate::extensions::objectives::structs::TokenObjective;
use crate::extensions::multi_game::interface::{IMINIGAME_TOKEN_MULTIGAME_ID, IMinigameTokenMultiGame};
use crate::extensions::multi_game::multi_game::MultiGameComponent;
use crate::libs::objectives_update::objectives_update;
use crate::libs::multi_game_update::multi_game_update;
use openzeppelin_introspection::src5::SRC5Component;

pub impl TokenHooksFullImpl<
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
                // Use validation library for all checks
                validation::validate_game_address(game_addr);
                
                // Use multi_game_update library to resolve game ID
                let contract = self.get_contract();
                let game_id = multi_game_update::resolve_game_id_for_mint(
                    contract,
                    game_addr,
                    self.game_address.read()
                );
                
                let validated_settings_id = validation::validate_settings(
                    game_addr, settings_id, true // assume settings supported
                );
                
                let objectives_count = validation::validate_objectives(
                    game_addr, objective_ids, true // assume objectives supported
                );
                
                (game_id, validated_settings_id, objectives_count)
            },
            Option::None => {
                // Blank NFT support - assuming settings are supported
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
        // Get contract state to access components
        let mut contract = self.get_contract_mut();
        
        // For the full implementation, we always register the minter
        // since we require MinterComponent to be present
        let mut minter = MinterComponent::HasComponent::<TContractState>::get_component_mut(ref contract);
        minter.add_minter(caller_address);

        match game_address {
            Option::Some(game_addr) => {
                objectives_update::process_token_objectives(
                    ref contract,
                    token_id,
                    game_addr,
                    token_metadata.objectives_count.into()
                );
            },
            Option::None => {
                // Blank NFT - No objectives to store
            },
        }
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