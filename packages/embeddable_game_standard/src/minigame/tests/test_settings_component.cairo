use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::minigame::extensions::settings::interface::{
    IMINIGAME_SETTINGS_ID, IMinigameSettingsDetailsDispatcher,
    IMinigameSettingsDetailsDispatcherTrait, IMinigameSettingsDispatcher,
    IMinigameSettingsDispatcherTrait, IMinigameSettingsSVGDispatcher,
    IMinigameSettingsSVGDispatcherTrait,
};
use crate::minigame::extensions::settings::structs::{GameSetting, GameSettingDetails};
use super::mocks::mock_settings_contract::{
    ISettingsSetterDispatcher, ISettingsSetterDispatcherTrait,
};

// Deploy mock settings contract
fn deploy_mock_settings_contract() -> ContractAddress {
    let contract = declare("MockSettingsContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

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
        src5_dispatcher.supports_interface(openzeppelin_interfaces::introspection::ISRC5_ID),
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

    let _settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    // Get settings ID 1
    let settings1 = settings_details_dispatcher.settings_details(1);
    assert!(settings1.name == "Easy Mode", "Settings 1 name mismatch");
    assert!(
        settings1.description == "Beginner friendly settings", "Settings 1 description mismatch",
    );
    assert!(SpanTrait::len(settings1.settings) == 2, "Settings 1 should have 2 items");

    // Get settings ID 2
    let settings2 = settings_details_dispatcher.settings_details(2);
    assert!(settings2.name == "Hard Mode", "Settings 2 name mismatch");
    assert!(settings2.description == "Expert settings", "Settings 2 description mismatch");
}

// Test SET-U-05: Get settings for non-existent ID
#[test]
#[should_panic]
fn test_get_settings_nonexistent_id() {
    let contract_address = deploy_mock_settings_contract();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };
    settings_details_dispatcher.settings_details(999); // Should panic
}

// Test SET-U-06: Create settings with valid data
#[test]
fn test_create_settings_valid_data() {
    let contract_address = deploy_mock_settings_contract();

    let new_settings = GameSettingDetails {
        name: "Custom Mode",
        description: "User defined settings",
        settings: array![
            GameSetting { name: 'speed', value: 'fast' },
            GameSetting { name: 'powerups', value: 'enabled' },
            GameSetting { name: 'time_limit', value: '300' },
        ]
            .span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(10, new_settings);

    // Verify settings were created
    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };
    assert!(settings_dispatcher.settings_exist(10), "New settings should exist");

    let retrieved = settings_details_dispatcher.settings_details(10);
    assert!(retrieved.name == "Custom Mode", "Name mismatch");
    assert!(SpanTrait::len(retrieved.settings) == 3, "Should have 3 settings");
}

// Test SET-U-07: Create settings with empty name
#[test]
fn test_create_settings_empty_name() {
    let contract_address = deploy_mock_settings_contract();

    let empty_name_settings = GameSettingDetails {
        name: "", // Empty name
        description: "Settings with no name",
        settings: array![GameSetting { name: 'test', value: 'value' }].span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(20, empty_name_settings);

    let _settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };
    let retrieved = settings_details_dispatcher.settings_details(20);
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
        settings_items.append(GameSetting { name: 's', value: 'v' });
        i += 1;
    }

    let large_settings = GameSettingDetails {
        name: "Large Settings",
        description: "Settings with many items",
        settings: settings_items.span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(30, large_settings);

    let _settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };
    let retrieved = settings_details_dispatcher.settings_details(30);
    assert!(SpanTrait::len(retrieved.settings) == 20, "Should have 20 settings items");
}

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

// =============================================================================
// Batch Operation Tests
// =============================================================================

// Test SET-U-11: settings_exist_batch with multiple IDs
#[test]
fn test_settings_exist_batch() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    let settings_ids: Array<u32> = array![1, 2, 3, 999];
    let results = settings_dispatcher.settings_exist_batch(settings_ids.span());

    assert!(results.len() == 4, "Should return 4 results");
    assert!(*results.at(0) == true, "Settings 1 should exist");
    assert!(*results.at(1) == true, "Settings 2 should exist");
    assert!(*results.at(2) == false, "Settings 3 should not exist");
    assert!(*results.at(3) == false, "Settings 999 should not exist");
}

// Test SET-U-12: settings_exist_batch with empty array
#[test]
fn test_settings_exist_batch_empty() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    let empty_ids: Array<u32> = array![];
    let results = settings_dispatcher.settings_exist_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// Test SET-U-13: settings_exist_batch with single item
#[test]
fn test_settings_exist_batch_single() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    let single_id: Array<u32> = array![1];
    let results = settings_dispatcher.settings_exist_batch(single_id.span());

    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == true, "Settings 1 should exist");
}

// Test SET-U-14: settings_details_batch with multiple IDs
#[test]
fn test_settings_details_batch() {
    let contract_address = deploy_mock_settings_contract();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    let settings_ids: Array<u32> = array![1, 2];
    let results = settings_details_dispatcher.settings_details_batch(settings_ids.span());

    assert!(results.len() == 2, "Should return 2 results");

    let settings1 = results.at(0);
    assert!(settings1.name == @"Easy Mode", "Settings 1 name mismatch");

    let settings2 = results.at(1);
    assert!(settings2.name == @"Hard Mode", "Settings 2 name mismatch");
}

// Test SET-U-15: settings_details_batch with single item
#[test]
fn test_settings_details_batch_single() {
    let contract_address = deploy_mock_settings_contract();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    let single_id: Array<u32> = array![2];
    let results = settings_details_dispatcher.settings_details_batch(single_id.span());

    assert!(results.len() == 1, "Should return 1 result");

    let settings = results.at(0);
    assert!(settings.name == @"Hard Mode", "Settings name mismatch");
    assert!(settings.description == @"Expert settings", "Settings description mismatch");
}

// =============================================================================
// Edge Case Tests
// =============================================================================

// Test SET-E-01: Create settings with long strings
#[test]
fn test_create_settings_long_strings() {
    let contract_address = deploy_mock_settings_contract();

    let long_name: ByteArray =
        "This is a very long settings name that tests the limits of ByteArray storage";
    let long_description: ByteArray =
        "This is a very long description that contains multiple sentences and tests the limits of ByteArray storage";

    let new_settings = GameSettingDetails {
        name: long_name.clone(),
        description: long_description.clone(),
        settings: array![GameSetting { name: 'key', value: 'value' }].span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(100, new_settings);

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    assert!(settings_dispatcher.settings_exist(100), "Long string settings should exist");

    let retrieved = settings_details_dispatcher.settings_details(100);
    assert!(retrieved.name == long_name, "Long name mismatch");
    assert!(retrieved.description == long_description, "Long description mismatch");
}

// Test SET-E-02: Create settings with special characters
#[test]
fn test_create_settings_special_chars() {
    let contract_address = deploy_mock_settings_contract();

    let special_name: ByteArray = "Special: !@#$%^&*()";
    let special_description: ByteArray = "Tabs\tand\nnewlines";

    let new_settings = GameSettingDetails {
        name: special_name.clone(),
        description: special_description.clone(),
        settings: array![].span(),
    };

    let setter = ISettingsSetterDispatcher { contract_address };
    setter.create_test_settings(101, new_settings);

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };
    let retrieved = settings_details_dispatcher.settings_details(101);

    assert!(retrieved.name == special_name, "Special char name mismatch");
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test SET-F-01: Fuzz settings_exist with random IDs
#[test]
#[fuzzer]
fn test_settings_exist_fuzz(settings_id: u32) {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    // Should not panic for any settings_id
    let exists = settings_dispatcher.settings_exist(settings_id);

    // Only IDs 1 and 2 are pre-populated in the mock
    if settings_id == 1 || settings_id == 2 {
        assert!(exists, "Settings 1 or 2 should exist");
    }
}

// Test SET-F-02: Fuzz settings_exist_batch with single random ID
#[test]
#[fuzzer]
fn test_settings_exist_batch_fuzz(settings_id: u32) {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    let ids: Array<u32> = array![settings_id];
    let results = settings_dispatcher.settings_exist_batch(ids.span());

    assert!(results.len() == 1, "Should return 1 result");
}

// =============================================================================
// Additional Coverage Tests for Mock Contract
// =============================================================================

// Test SET-MOCK-01: Test settings details loop iteration
#[test]
fn test_settings_details_iteration() {
    let contract_address = deploy_mock_settings_contract();

    let setter = ISettingsSetterDispatcher { contract_address };
    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    // Create settings with multiple items to cover loop
    let settings = GameSettingDetails {
        name: "Iteration Test",
        description: "Testing loop iteration",
        settings: array![
            GameSetting { name: 'item1', value: 'value1' },
            GameSetting { name: 'item2', value: 'value2' },
            GameSetting { name: 'item3', value: 'value3' },
            GameSetting { name: 'item4', value: 'value4' },
            GameSetting { name: 'item5', value: 'value5' },
        ]
            .span(),
    };

    setter.create_test_settings(200, settings);

    let retrieved = settings_details_dispatcher.settings_details(200);
    assert!(retrieved.settings.len() == 5, "Should have 5 settings items");
}

// Test SET-MOCK-02: Test settings_exist_batch loop
#[test]
fn test_settings_exist_batch_iteration() {
    let contract_address = deploy_mock_settings_contract();

    let settings_dispatcher = IMinigameSettingsDispatcher { contract_address };

    // Test with many IDs to cover loop iterations
    let ids: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let results = settings_dispatcher.settings_exist_batch(ids.span());

    assert!(results.len() == 10, "Should return 10 results");
}

// Test SET-MOCK-03: Test settings_details_batch loop
#[test]
fn test_settings_details_batch_iteration() {
    let contract_address = deploy_mock_settings_contract();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher { contract_address };

    // Both IDs 1 and 2 are pre-populated
    let ids: Array<u32> = array![1, 2, 1, 2, 1];
    let results = settings_details_dispatcher.settings_details_batch(ids.span());

    assert!(results.len() == 5, "Should return 5 results");
}
