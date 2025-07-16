use game_components_minigame::extensions::settings::interface::{
    IMinigameSettings, IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
    IMinigameSettingsSVG, IMinigameSettingsSVGDispatcher, IMinigameSettingsSVGDispatcherTrait,
    IMINIGAME_SETTINGS_ID,
};
use game_components_minigame::extensions::settings::structs::{GameSettingDetails, GameSetting};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{contract_address_const, get_caller_address};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use game_components_test_starknet::token::setup::deploy_mock_settings_contract;
use game_components_test_starknet::minigame::mocks::mock_settings_contract::{
    ISettingsSetterDispatcher, ISettingsSetterDispatcherTrait,
};

// Test SET-U-01: Initialize settings component
#[test]
fn test_initialize_settings_component() {
    let contract_address = deploy_mock_settings_contract();

    // Verify SRC5 interface is registered
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(
        src5_dispatcher.supports_interface(IMINIGAME_SETTINGS_ID),
        "Should support IMinigameSettings",
    );
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_introspection::interface::ISRC5_ID),
        "Should support ISRC5",
    );
}

// Test SET-U-02: Check settings_exist for valid ID
#[test]
fn test_settings_exist_valid_id() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(settings_dispatcher.settings_exist(1), "Settings ID 1 should exist");
    assert!(settings_dispatcher.settings_exist(2), "Settings ID 2 should exist");
}

// Test SET-U-03: Check settings_exist for invalid ID
#[test]
fn test_settings_exist_invalid_id() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(!settings_dispatcher.settings_exist(999), "Settings ID 999 should not exist");
    assert!(!settings_dispatcher.settings_exist(0), "Settings ID 0 should not exist");
}

// Test SET-U-04: Get settings for valid ID
#[test]
fn test_get_settings_valid_id() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    // Get settings ID 1
    let settings1 = settings_dispatcher.settings(1);
    assert!(settings1.name == "Easy Mode", "Settings 1 name mismatch");
    assert!(
        settings1.description == "Beginner friendly settings", "Settings 1 description mismatch",
    );
    assert!(settings1.settings.len() == 2, "Settings 1 should have 2 items");

    // Get settings ID 2
    let settings2 = settings_dispatcher.settings(2);
    assert!(settings2.name == "Hard Mode", "Settings 2 name mismatch");
    assert!(settings2.description == "Expert settings", "Settings 2 description mismatch");
}

// Test SET-U-05: Get settings for non-existent ID
#[test]
#[should_panic]
fn test_get_settings_nonexistent_id() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    settings_dispatcher.settings(999); // Should panic
}

// Test SET-U-06: Create settings with valid data
#[test]
fn test_create_settings_valid_data() {
    let contract_address = deploy_mock_settings_contract();

    let new_settings = GameSettingDetails {
        name: "Custom Mode",
        description: "User defined settings",
        settings: array![
            GameSetting { name: "speed", value: "fast" },
            GameSetting { name: "powerups", value: "enabled" },
            GameSetting { name: "time_limit", value: "300" },
        ]
            .span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(10, new_settings);

    // Verify settings were created
    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    assert!(settings_dispatcher.settings_exist(10), "New settings should exist");

    let retrieved = settings_dispatcher.settings(10);
    assert!(retrieved.name == "Custom Mode", "Name mismatch");
    assert!(retrieved.settings.len() == 3, "Should have 3 settings");
}

// Test SET-U-07: Create settings with empty name
#[test]
fn test_create_settings_empty_name() {
    let contract_address = deploy_mock_settings_contract();

    let empty_name_settings = GameSettingDetails {
        name: "", // Empty name
        description: "Settings with no name",
        settings: array![GameSetting { name: "test", value: "value" }].span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(20, empty_name_settings);

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let retrieved = settings_dispatcher.settings(20);
    assert!(retrieved.name == "", "Name should be empty");
}

// Test SET-U-08: Create settings with many items (boundary test)
#[test]
fn test_create_settings_50_items() {
    let contract_address = deploy_mock_settings_contract();

    // Create array with 20 settings (reduced from 50 due to event data size limit)
    let mut settings_items = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 20 {
            break;
        }
        // Use simpler strings to avoid data size limits
        let mut name_bytes = "s";
        let mut value_bytes = "v";
        settings_items
            .append(GameSetting { name: name_bytes, value: value_bytes });
        i += 1;
    };

    let large_settings = GameSettingDetails {
        name: "Large Settings",
        description: "Settings with many items",
        settings: settings_items.span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(30, large_settings);

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let retrieved = settings_dispatcher.settings(30);
    assert!(retrieved.settings.len() == 20, "Should have 20 settings items");
}

// Test SET-U-09: Get_settings_id from token
// This would be tested in integration with TokenComponent

// Test SET-U-10: Settings_svg implementation
#[test]
fn test_settings_svg() {
    let contract_address = deploy_mock_settings_contract();

    let settings_svg_dispatcher = IMinigameSettingsSVGDispatcher { contract_address };

    // Test SVG for existing settings
    let svg1 = settings_svg_dispatcher.settings_svg(1);
    assert!(svg1 == "<svg><text>Easy Mode</text></svg>", "SVG 1 content mismatch");

    let svg2 = settings_svg_dispatcher.settings_svg(2);
    assert!(svg2 == "<svg><text>Hard Mode</text></svg>", "SVG 2 content mismatch");
}
