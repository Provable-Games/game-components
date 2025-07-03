#[cfg(test)]
mod tests {
    use starknet::{ContractAddress};
    use snforge_std::{
        declare, ContractClassTrait, DeclareResultTrait, ContractClass,
        start_cheat_caller_address, stop_cheat_caller_address,
    };
    use game_components_token::interface::{IMinigameToken, IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
    use game_components_token::extensions::objectives::interface::{
        IMinigameTokenObjectives, IMinigameTokenObjectivesDispatcher, IMinigameTokenObjectivesDispatcherTrait
    };
    use game_components_token::extensions::multi_game::interface::{
        IMinigameTokenMultiGame, IMinigameTokenMultiGameDispatcher, IMinigameTokenMultiGameDispatcherTrait
    };
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_metagame::extensions::context::structs::GameContextDetails;
    use super::super::test_contracts::{BasicTokenContract, MultiGameTokenContract};
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait
    };
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

    // Helper function to deploy multi-game token contract
    fn deploy_multi_game_token() -> (IMinigameTokenDispatcher, IMinigameTokenObjectivesDispatcher, IMinigameTokenMultiGameDispatcher) {
        let contract = declare("MultiGameTokenContract").unwrap().contract_class();
        let mut calldata = array![];
        calldata.append('MultiGameToken');
        calldata.append('MGT');
        calldata.append('https://test.com/');
        
        let (contract_address, _) = contract.deploy(@calldata).unwrap();
        (
            IMinigameTokenDispatcher { contract_address },
            IMinigameTokenObjectivesDispatcher { contract_address },
            IMinigameTokenMultiGameDispatcher { contract_address }
        )
    }

    #[test]
    fn test_mint_with_objectives() {
        let (mock_game, _, _, objectives_addr) = setup_mock_minigame();
        let mock_objectives = setup_mock_objectives();
        let (token, token_objectives, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register game in multi-game system
        multi_game.add_game(mock_game.contract_address);
        
        // Mock objectives exist
        let objective_ids = array![1_u32, 2_u32, 3_u32];
        mock_objectives.mock_objectives_exist(objective_ids.span(), true);
        
        // Mint token with objectives
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Verify objectives were registered
        let metadata = token.token_metadata(token_id);
        assert!(metadata.objectives_count == 3, "Should have 3 objectives");
        
        // Verify individual objectives
        let obj1 = token_objectives.get_objective(token_id, 0);
        assert!(obj1.objective_id == 1, "First objective ID should be 1");
        assert!(!obj1.completed, "First objective should not be completed");
        
        let obj2 = token_objectives.get_objective(token_id, 1);
        assert!(obj2.objective_id == 2, "Second objective ID should be 2");
        assert!(!obj2.completed, "Second objective should not be completed");
        
        let obj3 = token_objectives.get_objective(token_id, 2);
        assert!(obj3.objective_id == 3, "Third objective ID should be 3");
        assert!(!obj3.completed, "Third objective should not be completed");
    }

    #[test]
    fn test_update_game_with_objectives() {
        let (mock_game, _, _, objectives_addr) = setup_mock_minigame();
        let mock_objectives = setup_mock_objectives();
        let (token, token_objectives, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register game
        multi_game.add_game(mock_game.contract_address);
        
        // Mock objectives exist
        let objective_ids = array![1_u32, 2_u32];
        mock_objectives.mock_objectives_exist(objective_ids.span(), true);
        
        // Mint token with objectives
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Mock objective completion
        mock_objectives.mock_completed_objective(token_id, 1, true);
        mock_objectives.mock_completed_objective(token_id, 2, false);
        
        // Update game
        token.update_game(token_id);
        
        // Verify objectives updated
        let obj1 = token_objectives.get_objective(token_id, 0);
        assert!(obj1.completed, "First objective should be completed");
        
        let obj2 = token_objectives.get_objective(token_id, 1);
        assert!(!obj2.completed, "Second objective should not be completed");
        
        // Complete all objectives
        mock_objectives.mock_completed_objective(token_id, 2, true);
        token.update_game(token_id);
        
        // Verify all objectives completed
        let metadata = token.token_metadata(token_id);
        assert!(metadata.completed_all_objectives, "Should have completed all objectives");
    }

    #[test]
    fn test_is_playable_with_completed_objectives() {
        let (mock_game, _, _, objectives_addr) = setup_mock_minigame();
        let mock_objectives = setup_mock_objectives();
        let (token, _, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register game
        multi_game.add_game(mock_game.contract_address);
        
        // Mock objectives exist
        let objective_ids = array![1_u32];
        mock_objectives.mock_objectives_exist(objective_ids.span(), true);
        
        // Mint token with objectives
        let token_id = token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Token should be playable initially
        assert!(token.is_playable(token_id), "Token should be playable with incomplete objectives");
        
        // Complete objectives
        mock_objectives.mock_completed_objective(token_id, 1, true);
        token.update_game(token_id);
        
        // Token should not be playable after completing all objectives
        assert!(!token.is_playable(token_id), "Token should not be playable after completing all objectives");
    }

    #[test]
    fn test_multi_game_token_minting() {
        let (mock_game1, _, _, _) = setup_mock_minigame();
        let game2_addr = starknet::contract_address_const::<'GAME2'>();
        let (token, _, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register multiple games
        multi_game.add_game(mock_game1.contract_address);
        multi_game.add_game(game2_addr);
        
        // Mint token for first game
        let token_id1 = token.mint(
            Option::Some(mock_game1.contract_address),
            Option::Some("Game1Player"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Mint token for second game
        let token_id2 = token.mint(
            Option::Some(game2_addr),
            Option::Some("Game2Player"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Verify different game IDs
        let metadata1 = token.token_metadata(token_id1);
        let metadata2 = token.token_metadata(token_id2);
        assert!(metadata1.game_id == 1, "First token should have game ID 1");
        assert!(metadata2.game_id == 2, "Second token should have game ID 2");
        
        // Verify game addresses
        let game1_retrieved = multi_game.get_game_address_from_id(1);
        let game2_retrieved = multi_game.get_game_address_from_id(2);
        assert!(game1_retrieved == mock_game1.contract_address, "Game 1 address should match");
        assert!(game2_retrieved == game2_addr, "Game 2 address should match");
    }

    #[test]
    #[should_panic(expected: "MinigameToken: Objectives contract does not support IMinigameObjectives")]
    fn test_mint_with_invalid_objectives_contract() {
        let game_addr = starknet::contract_address_const::<'GAME'>();
        let (token, _, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register game without proper objectives support
        multi_game.add_game(game_addr);
        
        // Try to mint with objectives (should fail)
        let objective_ids = array![1_u32];
        token.mint(
            Option::Some(game_addr),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
    }

    #[test]
    #[should_panic(expected: "Denshokan: Objective id 999 not registered")]
    fn test_mint_with_nonexistent_objective() {
        let (mock_game, _, _, objectives_addr) = setup_mock_minigame();
        let mock_objectives = setup_mock_objectives();
        let (token, _, multi_game) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Register game
        multi_game.add_game(mock_game.contract_address);
        
        // Mock that objective 999 doesn't exist
        let objective_ids = array![999_u32];
        mock_objectives.mock_objectives_exist(objective_ids.span(), false);
        
        // Try to mint with non-existent objective
        token.mint(
            Option::Some(mock_game.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids.span()),
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
    }

    #[test]
    fn test_blank_token_minting() {
        let (token, _, _) = deploy_multi_game_token();
        let recipient = starknet::contract_address_const::<'RECIPIENT'>();
        
        // Mint blank token (no game address)
        let token_id = token.mint(
            Option::None, // No game address
            Option::Some("BlankPlayer"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            recipient,
            false,
        );
        
        // Verify blank token metadata
        let metadata = token.token_metadata(token_id);
        assert!(metadata.game_id == 0, "Blank token should have game ID 0");
        assert!(metadata.settings_id == 0, "Blank token should have settings ID 0");
        assert!(metadata.objectives_count == 0, "Blank token should have 0 objectives");
    }
}