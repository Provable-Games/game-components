// Library for handling multi-game updates in token hooks
pub mod multi_game_update {
    use starknet::ContractAddress;
    use crate::extensions::multi_game::multi_game::MultiGameComponent;
    use crate::extensions::multi_game::multi_game::MultiGameComponent::MultiGameImpl;
    use crate::extensions::multi_game::interface::IMINIGAME_TOKEN_MULTIGAME_ID;
    use crate::extensions::multi_game::structs::GameMetadata;
    use openzeppelin_introspection::src5::SRC5Component;
    use openzeppelin_introspection::src5::SRC5Component::SRC5Impl;
    use game_components_minigame::interface::IMinigameDispatcher;
    
    /// Gets the correct game address for a token, handling both single and multi-game tokens
    /// 
    /// Returns the game address to use for update_game calls
    pub fn get_game_address_for_token<
        TContractState,
        +SRC5Component::HasComponent<TContractState>,
        +MultiGameComponent::HasComponent<TContractState>,
        +crate::token::TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    >(
        contract: @TContractState,
        token_id: u64,
        game_id: u64,
        default_game_address: ContractAddress,
    ) -> ContractAddress {
        // Check if this contract supports multi-game
        let src5 = SRC5Component::HasComponent::<TContractState>::get_component(contract);
        let supports_multigame = src5.supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
        
        if supports_multigame && game_id != 0 {
            // Multi-game token - get game address from registry
            let multi_game = MultiGameComponent::HasComponent::<TContractState>::get_component(contract);
            multi_game.game_address_from_id(game_id)
        } else {
            // Single game token - use default
            default_game_address
        }
    }
    
    /// Gets game metadata for multi-game tokens
    /// 
    /// Returns None for single-game tokens
    pub fn get_game_metadata<
        TContractState,
        +SRC5Component::HasComponent<TContractState>,
        +MultiGameComponent::HasComponent<TContractState>,
        +crate::token::TokenComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    >(
        contract: @TContractState,
        game_id: u64,
    ) -> Option<GameMetadata> {
        let src5 = SRC5Component::HasComponent::<TContractState>::get_component(contract);
        let supports_multigame = src5.supports_interface(IMINIGAME_TOKEN_MULTIGAME_ID);
        
        if supports_multigame && game_id != 0 {
            let multi_game = MultiGameComponent::HasComponent::<TContractState>::get_component(contract);
            Option::Some(multi_game.game_metadata(game_id))
        } else {
            Option::None
        }
    }
    
    /// Simplified game address resolver for contracts without MultiGameComponent
    /// 
    /// Always returns the default game address
    pub fn get_game_address_simple(
        game_id: u64,
        default_game_address: ContractAddress,
    ) -> ContractAddress {
        // For contracts without multi-game support, always use default
        default_game_address
    }
    
    /// Helper to create appropriate game dispatcher based on resolved address
    pub fn create_game_dispatcher(
        game_address: ContractAddress
    ) -> IMinigameDispatcher {
        IMinigameDispatcher { contract_address: game_address }
    }
    
    /// Resolves game ID for minting, handling both single and multi-game tokens
    /// 
    /// For multi-game tokens: Returns the game ID from registry (must be registered)
    /// For single-game tokens: Validates address matches and returns 0
    pub fn resolve_game_id_for_mint<
        TContractState,
        +crate::extensions::multi_game::interface::IMinigameTokenMultiGame<TContractState>,
        +Drop<TContractState>
    >(
        contract: @TContractState,
        game_address: ContractAddress,
        default_game_address: ContractAddress,
    ) -> u64 {
        // Get game_id from multi-game registry
        let game_id = contract.game_id_from_address(game_address);
        
        if game_id == 0 {
            // Game not registered in multi-game registry
            // For single-game tokens, verify it matches the default
            assert!(
                game_address == default_game_address,
                "MinigameToken: Game address mismatch"
            );
            0
        } else {
            // Multi-game token with registered game
            game_id
        }
    }
}