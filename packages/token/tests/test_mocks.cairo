#[cfg(test)]
mod tests {
    use super::super::mocks::{
        setup_mock_minigame, setup_mock_settings, setup_mock_objectives,
        MockMinigameContractTrait, MockSettingsContractTrait, MockObjectivesContractTrait,
        create_default_settings, create_default_objectives
    };
    use game_components_minigame::interface::{
        IMinigameDispatcher, IMinigameDispatcherTrait,
        IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
        IMinigameDetailsDispatcher, IMinigameDetailsDispatcherTrait
    };
    use game_components_minigame::extensions::settings::interface::{
        IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait
    };
    use game_components_minigame::extensions::objectives::interface::{
        IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait
    };
    use game_components_minigame::structs::GameDetail;

    #[test]
    fn test_mock_minigame_setup() {
        let (mock, token_addr, settings_addr, objectives_addr) = setup_mock_minigame();
        
        // Test IMinigame interface
        let minigame = IMinigameDispatcher { contract_address: mock.contract_address };
        assert!(minigame.token_address() == token_addr, "Token address mismatch");
        assert!(minigame.settings_address() == settings_addr, "Settings address mismatch");
        assert!(minigame.objectives_address() == objectives_addr, "Objectives address mismatch");
    }

    #[test]
    fn test_mock_minigame_token_data() {
        let (mock, _, _, _) = setup_mock_minigame();
        
        // Mock token data
        mock.mock_score(1, 100);
        mock.mock_game_over(1, true);
        
        // Test IMinigameTokenData interface
        let token_data = IMinigameTokenDataDispatcher { contract_address: mock.contract_address };
        assert!(token_data.score(1) == 100, "Score mismatch");
        assert!(token_data.game_over(1) == true, "Game over mismatch");
    }

    #[test]
    fn test_mock_minigame_details() {
        let (mock, _, _, _) = setup_mock_minigame();
        
        // Mock details
        let description = "Test game token";
        let details = array![
            GameDetail { name: "Level", value: "5" },
            GameDetail { name: "XP", value: "1000" }
        ].span();
        
        mock.mock_token_description(1, description);
        mock.mock_game_details(1, details);
        
        // Test IMinigameDetails interface
        let minigame_details = IMinigameDetailsDispatcher { contract_address: mock.contract_address };
        assert!(minigame_details.token_description(1) == description, "Description mismatch");
        
        let returned_details = minigame_details.game_details(1);
        assert!(returned_details.len() == 2, "Details count mismatch");
        assert!(*returned_details.at(0).name == "Level", "Detail name mismatch");
        assert!(*returned_details.at(0).value == "5", "Detail value mismatch");
    }

    #[test]
    fn test_mock_settings() {
        let mock = setup_mock_settings();
        let settings = IMinigameSettingsDispatcher { contract_address: mock.contract_address };
        
        // Test default settings
        assert!(settings.settings_exist(1) == true, "Settings should exist");
        
        let setting_details = settings.settings(1);
        assert!(setting_details.name == "Settings 1", "Settings name mismatch");
        assert!(setting_details.settings.len() == 2, "Settings count mismatch");
        
        // Test custom settings
        mock.mock_settings_exist(2, true);
        mock.mock_settings(2, create_default_settings(2));
        
        assert!(settings.settings_exist(2) == true, "Custom settings should exist");
        let custom_details = settings.settings(2);
        assert!(custom_details.name == "Settings 2", "Custom settings name mismatch");
    }

    #[test]
    fn test_mock_objectives() {
        let mock = setup_mock_objectives();
        let objectives = IMinigameObjectivesDispatcher { contract_address: mock.contract_address };
        
        // Test default objectives
        assert!(objectives.objective_exists(1) == true, "Objective 1 should exist");
        assert!(objectives.objective_exists(2) == true, "Objective 2 should exist");
        assert!(objectives.objective_exists(3) == true, "Objective 3 should exist");
        
        // Test completion status
        assert!(objectives.completed_objective(1, 1) == false, "Objective should not be completed");
        
        // Mock some completions
        mock.mock_completed_objective(1, 1, true);
        mock.mock_completed_objective(1, 2, true);
        
        assert!(objectives.completed_objective(1, 1) == true, "Objective 1 should be completed");
        assert!(objectives.completed_objective(1, 2) == true, "Objective 2 should be completed");
        assert!(objectives.completed_objective(1, 3) == false, "Objective 3 should not be completed");
    }

    #[test]
    fn test_mock_helpers() {
        let mock_objectives = setup_mock_objectives();
        
        // Test batch mocking of objectives
        let obj_ids = array![10_u32, 11_u32, 12_u32].span();
        mock_objectives.mock_objectives_exist(obj_ids, true);
        
        let objectives = IMinigameObjectivesDispatcher { contract_address: mock_objectives.contract_address };
        assert!(objectives.objective_exists(10) == true, "Objective 10 should exist");
        assert!(objectives.objective_exists(11) == true, "Objective 11 should exist");
        assert!(objectives.objective_exists(12) == true, "Objective 12 should exist");
        
        // Test batch completion mocking
        let completion_status = array![true, false, true].span();
        mock_objectives.mock_objective_completions(2, obj_ids, completion_status);
        
        assert!(objectives.completed_objective(2, 10) == true, "Objective 10 should be completed");
        assert!(objectives.completed_objective(2, 11) == false, "Objective 11 should not be completed");
        assert!(objectives.completed_objective(2, 12) == true, "Objective 12 should be completed");
    }

    #[test]
    fn test_stop_mocks() {
        let (mock, _, _, _) = setup_mock_minigame();
        
        // Mock a value
        mock.mock_score(1, 999);
        let token_data = IMinigameTokenDataDispatcher { contract_address: mock.contract_address };
        assert!(token_data.score(1) == 999, "Score should be mocked");
        
        // Stop the mock
        mock.stop_mock("score");
        
        // Now the call should fail or return default (depending on implementation)
        // This test would need to be adjusted based on actual behavior
    }
}