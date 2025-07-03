use starknet::ContractAddress;
use game_components_minigame::extensions::settings::interface::{IMinigameSettings, IMinigameSettingsSVG};
use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
use snforge_std::{start_mock_call, stop_mock_call, mock_call};

#[derive(Drop, Copy)]
pub struct MockSettingsContract {
    pub contract_address: ContractAddress,
}

pub impl MockSettingsContractImpl of MockSettingsContractTrait {
    fn new(address: ContractAddress) -> MockSettingsContract {
        MockSettingsContract {
            contract_address: address,
        }
    }

    // IMinigameSettings interface mocks
    fn mock_settings_exist(self: @MockSettingsContract, settings_id: u32, exists: bool) {
        let selector = selector!("settings_exist");
        let mut calldata = array![];
        settings_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, exists);
    }

    fn mock_settings(self: @MockSettingsContract, settings_id: u32, settings: GameSettingDetails) {
        let selector = selector!("settings");
        let mut calldata = array![];
        settings_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, settings);
    }

    // IMinigameSettingsSVG interface mocks
    fn mock_settings_svg(self: @MockSettingsContract, settings_id: u32, svg: ByteArray) {
        let selector = selector!("settings_svg");
        let mut calldata = array![];
        settings_id.serialize(ref calldata);
        start_mock_call(*self.contract_address, selector, svg);
    }

    // Stop specific mock
    fn stop_settings_exist_mock(self: @MockSettingsContract) {
        stop_mock_call(*self.contract_address, selector!("settings_exist"));
    }

    // Stop all mocks
    fn stop_all_mocks(self: @MockSettingsContract) {
        stop_mock_call(*self.contract_address, selector!("settings_exist"));
        stop_mock_call(*self.contract_address, selector!("settings"));
        stop_mock_call(*self.contract_address, selector!("settings_svg"));
    }
}

pub trait MockSettingsContractTrait {
    fn new(address: ContractAddress) -> MockSettingsContract;
    
    // IMinigameSettings interface mocks
    fn mock_settings_exist(self: @MockSettingsContract, settings_id: u32, exists: bool);
    fn mock_settings(self: @MockSettingsContract, settings_id: u32, settings: GameSettingDetails);
    
    // IMinigameSettingsSVG interface mocks
    fn mock_settings_svg(self: @MockSettingsContract, settings_id: u32, svg: ByteArray);
    
    // Control methods
    fn stop_settings_exist_mock(self: @MockSettingsContract);
    fn stop_all_mocks(self: @MockSettingsContract);
}

// Helper function to create default game settings
pub fn create_default_settings(settings_id: u32) -> GameSettingDetails {
    GameSettingDetails {
        name: format!("Settings {}", settings_id),
        description: "Default test settings",
        settings: array![
            GameSetting {
                name: "difficulty",
                value: "normal"
            },
            GameSetting {
                name: "max_score",
                value: "1000"
            }
        ].span()
    }
}

// Helper function to setup a mock settings contract with common defaults
pub fn setup_mock_settings() -> MockSettingsContract {
    let address = starknet::contract_address_const::<'SETTINGS'>();
    let mock = MockSettingsContractImpl::new(address);
    
    // Mock some default settings
    mock.mock_settings_exist(1, true);
    mock.mock_settings(1, create_default_settings(1));
    mock.mock_settings_svg(1, "<svg>Settings 1</svg>");
    
    mock
}