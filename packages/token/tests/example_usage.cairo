#[cfg(test)]
mod example_usage {
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait
    };
    use game_components_minigame::interface::{
        IMinigameDispatcher, IMinigameDispatcherTrait,
        IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait
    };
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait
    };
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait
    };
    use starknet::ContractAddress;

    // Example test using mocks for token minting with game integration
    #[test]
    fn test_token_mint_with_game() {
        // 1. Setup mock game with settings and objectives
        let (mock_game, _, settings_addr, objectives_addr) = setup_mock_minigame();
        let mock_settings = setup_mock_settings();
        let mock_objectives = setup_mock_objectives();
        
        // 2. Configure game behavior
        mock_game.mock_score(1, 0);  // New token starts with score 0
        mock_game.mock_game_over(1, false);  // Game is not over
        
        // 3. Configure settings
        mock_settings.mock_settings_exist(1, true);
        
        // 4. Configure objectives
        let objective_ids = array![1_u32, 2_u32, 3_u32].span();
        mock_objectives.mock_objectives_exist(objective_ids, true);
        
        // In actual token mint test:
        // - Pass mock_game.contract_address as the game_address
        // - Pass settings_id = 1
        // - Pass objective_ids = [1, 2, 3]
        // The token component should validate against these mocks
    }

    // Example test for token update_game functionality
    #[test]
    fn test_token_update_game() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        let mock_objectives = setup_mock_objectives();
        
        // Setup initial state
        mock_game.mock_score(1, 100);
        mock_game.mock_game_over(1, false);
        
        // Mock objective completion status
        mock_objectives.mock_completed_objective(1, 1, true);
        mock_objectives.mock_completed_objective(1, 2, true);
        mock_objectives.mock_completed_objective(1, 3, false);
        
        // In actual token update test:
        // - Call token.update_game(1)
        // - Verify token metadata is updated with score and completion status
        
        // Later, simulate game completion
        mock_game.mock_game_over(1, true);
        mock_objectives.mock_completed_objective(1, 3, true);
        
        // Call update_game again and verify final state
    }

    // Example of mocking multiple tokens with different states
    #[test]
    fn test_multiple_tokens() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        
        // Token 1: In progress
        mock_game.mock_score(1, 50);
        mock_game.mock_game_over(1, false);
        
        // Token 2: Completed
        mock_game.mock_score(2, 1000);
        mock_game.mock_game_over(2, true);
        
        // Token 3: Just started
        mock_game.mock_score(3, 0);
        mock_game.mock_game_over(3, false);
        
        // Test different token states in your token contract tests
    }

    // Example of testing error conditions
    #[test]
    fn test_invalid_settings() {
        let mock_settings = setup_mock_settings();
        
        // Mock that settings ID 999 doesn't exist
        mock_settings.mock_settings_exist(999, false);
        
        // In actual token mint test:
        // - Try to mint with settings_id = 999
        // - Should fail with "Settings id not registered" error
    }

    // Example of cleaning up mocks
    #[test]
    fn test_mock_cleanup() {
        let (mock_game, _, _, _) = setup_mock_minigame();
        
        // Set up some mocks
        mock_game.mock_score(1, 100);
        
        // Use the mocks in tests...
        
        // Clean up specific mock
        mock_game.stop_mock("score");
        
        // Or clean up all mocks
        mock_game.stop_all_mocks();
    }
}