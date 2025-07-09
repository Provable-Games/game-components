// Validation library for token mint operations
pub mod validation {
    use starknet::ContractAddress;
    use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
    use game_components_minigame::interface::{
        IMINIGAME_ID, IMinigameDispatcher, IMinigameDispatcherTrait,
    };
    use game_components_minigame::extensions::settings::interface::{
        IMINIGAME_SETTINGS_ID, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
    };
    use game_components_minigame::extensions::objectives::interface::{
        IMINIGAME_OBJECTIVES_ID, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    };

    /// Validates that a game address supports the IMinigame interface
    pub fn validate_game_address(game_address: ContractAddress) {
        let game_src5 = ISRC5Dispatcher { contract_address: game_address };
        assert!(
            game_src5.supports_interface(IMINIGAME_ID),
            "MinigameToken: Game does not support IMinigame"
        );
    }

    /// Validates and returns the settings ID if the game supports settings
    pub fn validate_settings(
        game_address: ContractAddress,
        settings_id: Option<u32>,
        token_supports_settings: bool
    ) -> u32 {
        match settings_id {
            Option::Some(id) => {
                assert!(token_supports_settings, "MinigameToken: Settings not supported");
                
                let minigame = IMinigameDispatcher { contract_address: game_address };
                let settings_address = minigame.settings_address();
                
                let settings_src5 = ISRC5Dispatcher { contract_address: settings_address };
                assert!(
                    settings_src5.supports_interface(IMINIGAME_SETTINGS_ID),
                    "MinigameToken: Settings contract invalid"
                );
                
                let settings = IMinigameSettingsDispatcher { contract_address: settings_address };
                assert!(
                    settings.settings_exist(id),
                    "MinigameToken: Settings not found"
                );
                id
            },
            Option::None => 0,
        }
    }

    /// Validates objectives and returns the count
    pub fn validate_objectives(
        game_address: ContractAddress,
        objective_ids: Option<Span<u32>>,
        token_supports_objectives: bool
    ) -> u32 {
        match objective_ids {
            Option::Some(obj_ids) => {
                assert!(token_supports_objectives, "MinigameToken: Objectives not supported");
                
                let minigame = IMinigameDispatcher { contract_address: game_address };
                let objectives_address = minigame.objectives_address();
                
                let objectives_src5 = ISRC5Dispatcher { contract_address: objectives_address };
                assert!(
                    objectives_src5.supports_interface(IMINIGAME_OBJECTIVES_ID),
                    "MinigameToken: Objectives contract invalid"
                );
                
                let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
                
                let mut i: u32 = 0;
                loop {
                    if i == obj_ids.len() {
                        break;
                    }
                    let objective_id = *obj_ids.at(i);
                    assert!(
                        objectives.objective_exists(objective_id),
                        "MinigameToken: Objective not found"
                    );
                    i += 1;
                };
                i
            },
            Option::None => 0,
        }
    }
}