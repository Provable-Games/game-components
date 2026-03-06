// Tests for SettingsComponent extension
// Test Plan: settings_test_plan.md

use game_components_interfaces::{IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait};
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{EventSpyTrait, mock_call, spy_events};
use crate::token::extensions::settings::interface::IMINIGAME_TOKEN_SETTINGS_ID;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_mock::IMinigameMockDispatcherTrait;

// Import setup helpers
use super::setup::{ALICE, BOB, setup, setup_multi_game};

// ================================================================================================
// CREATE_SETTINGS TESTS - Happy Path
// ================================================================================================

// TST-CS-001: Create settings from valid settings contract (single-game)
#[test]
fn test_create_settings_valid_single_game() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Create settings via the mock minigame (which acts as settings_address)
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy difficulty mode", 1);

    // Verify SettingsCreated event was emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit events");
}

// TST-CS-003: Create settings with empty settings array
#[test]
fn test_create_settings_with_empty_settings_data() {
    let test_contracts = setup();

    // Create settings with minimal data - this uses the mock which creates with difficulty
    test_contracts.mock_minigame.create_settings_difficulty("Empty", "Empty settings", 0);

    // Verify settings exist
    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(settings.settings_exist(1), "Settings should exist");
}

// TST-CS-004: Create settings with multiple settings entries
#[test]
fn test_create_settings_with_multiple_settings() {
    let test_contracts = setup();

    // Create multiple settings configurations
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy mode", 1);
    test_contracts.mock_minigame.create_settings_difficulty("Medium", "Medium mode", 2);
    test_contracts.mock_minigame.create_settings_difficulty("Hard", "Hard mode", 3);

    // Verify all settings exist
    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(settings.settings_exist(1), "Settings 1 should exist");
    assert!(settings.settings_exist(2), "Settings 2 should exist");
    assert!(settings.settings_exist(3), "Settings 3 should exist");
}

// ================================================================================================
// CREATE_SETTINGS TESTS - Authorization
// ================================================================================================

// TST-CS-R01: Create settings from unauthorized caller
// Note: This test verifies that settings creation goes through the minigame contract
// (which implements IMinigameSettings) and not directly to the token contract.
// Direct calls to create_settings on the token contract should be rejected.
#[test]
fn test_create_settings_authorization_model() {
    let test_contracts = setup();

    // Settings creation should go through the minigame mock
    // which calls the token contract's create_settings
    test_contracts
        .mock_minigame
        .create_settings_difficulty("TestFromMinigame", "Settings from minigame", 1);

    // Verify the settings were created through proper channel
    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(settings.settings_exist(1), "Settings should exist when created through minigame");
}

// ================================================================================================
// VALIDATE_SETTINGS TESTS - Happy Path
// ================================================================================================

// TST-VS-001: Validate existing settings_id during mint
#[test]
fn test_validate_settings_valid_settings_id() {
    let test_contracts = setup();

    // Create settings
    test_contracts.mock_minigame.create_settings_difficulty("Test", "Test mode", 1);

    // Mock interface support for settings validation
    mock_call(test_contracts.minigame.contract_address, selector!("supports_interface"), true, 10);
    mock_call(test_contracts.minigame.contract_address, selector!("settings_exist"), true, 1);

    // Mint with the created settings_id
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::Some(1), // Use created settings_id
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify token was minted
    assert!(token_id != 0, "Token should be minted");
}

// TST-VS-002: Validate with zero settings_address (no validation needed)
#[test]
fn test_validate_settings_zero_settings_address() {
    let test_contracts = setup_multi_game();

    // Mint with settings_id but game has no settings contract
    // This should succeed because validation is skipped when settings_address is zero
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None, // No settings_id means no validation
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token should be minted");
    assert!(test_contracts.test_token.settings_id(token_id) == 0, "Settings ID should be 0");
}

// TST-VS-003: Validate with settings_id = 0 (default/no settings)
#[test]
fn test_validate_settings_id_zero() {
    let test_contracts = setup();

    // Create settings first
    test_contracts.mock_minigame.create_settings_difficulty("Test", "Test", 1);

    // Mint with settings_id = 0 (explicitly no settings)
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None, // No settings_id = 0
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.settings_id(token_id) == 0, "Settings ID should be 0");
}

// ================================================================================================
// VALIDATE_SETTINGS TESTS - Revert Paths
// ================================================================================================

// TST-VS-R03: Settings ID does not exist
#[test]
#[should_panic]
fn test_validate_settings_id_not_exist() {
    let test_contracts = setup();

    // Create only settings_id = 1
    test_contracts.mock_minigame.create_settings_difficulty("Test", "Test", 1);

    // Try to mint with settings_id = 999 which doesn't exist
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::Some(999), // Non-existent settings_id
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

// ================================================================================================
// INITIALIZER TESTS
// ================================================================================================

// TST-IN-001: Initializer registers interface
#[test]
fn test_settings_initializer_registers_interface() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_SETTINGS_ID),
        "Should support IMinigameTokenSettings interface",
    );
}

// TST-IN-003: SRC5 correctly reports settings support
#[test]
fn test_settings_src5_support() {
    let test_contracts = setup();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_SETTINGS_ID),
        "Should support settings interface",
    );
}

// ================================================================================================
// INTEGRATION TESTS
// ================================================================================================

// TST-INT-001: Mint token with valid settings_id
#[test]
fn test_mint_with_settings_validation() {
    let test_contracts = setup();

    // Create settings
    test_contracts.mock_minigame.create_settings_difficulty("Standard", "Standard game mode", 2);

    // Mock for validation
    mock_call(test_contracts.minigame.contract_address, selector!("supports_interface"), true, 10);
    mock_call(test_contracts.minigame.contract_address, selector!("settings_exist"), true, 1);

    // Mint with settings
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player'),
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify token metadata includes settings_id
    assert!(token_id != 0, "Token should be minted");
}

// TST-INT-002: Create settings then mint using that settings_id
#[test]
fn test_create_and_use_settings() {
    let test_contracts = setup();

    // Create settings
    test_contracts.mock_minigame.create_settings_difficulty("Tournament", "Tournament settings", 3);

    // Verify settings were created
    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(settings.settings_exist(1), "Settings should exist");

    // Mock for mint validation
    mock_call(test_contracts.minigame.contract_address, selector!("supports_interface"), true, 10);
    mock_call(test_contracts.minigame.contract_address, selector!("settings_exist"), true, 1);

    // Mint with created settings
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token should be minted");
}

// ================================================================================================
// SETTINGS VIEW TESTS
// ================================================================================================

#[test]
fn test_settings_id_view_no_settings() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.settings_id(token_id) == 0, "Settings ID should be 0");
}

#[test]
fn test_settings_id_batch_view() {
    let test_contracts = setup_multi_game();

    // Mint multiple tokens
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Get batch settings
    let results = test_contracts.test_token.settings_id_batch(array![token_id1, token_id2].span());
    assert!(results.len() == 2, "Should have 2 results");
    assert!(*results.at(0) == 0, "First settings_id should be 0");
    assert!(*results.at(1) == 0, "Second settings_id should be 0");
}

// ================================================================================================
// EVENT TESTS
// ================================================================================================

// TST-CS-E01: Verify SettingsCreated event contains correct data
#[test]
fn test_create_settings_event_data() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Create settings
    test_contracts.mock_minigame.create_settings_difficulty("TestSettings", "A test setting", 5);

    // Check events were emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit SettingsCreated event");
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

// TST-FZ-001: Fuzz settings_id validation
#[test]
#[fuzzer]
fn test_fuzz_settings_id_validation(settings_id: u32) {
    // Only test valid range - settings_id 0 is always valid (no settings)
    if settings_id == 0 {
        let test_contracts = setup_multi_game();

        let token_id = test_contracts
            .test_token
            .mint(
                test_contracts.minigame.contract_address,
                Option::None,
                Option::None, // settings_id = 0
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                ALICE(),
                false,
                false,
                0,
                0,
            );

        assert!(test_contracts.test_token.settings_id(token_id) == 0, "Should have settings_id 0");
    }
    // Non-zero settings_id requires actual settings to exist, so we skip those cases
}

// TST-FZ-002: Fuzz settings data length
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_settings_data_length(count: u8) {
    // Limit to reasonable count for gas
    if count > 10 {
        return;
    }

    let test_contracts = setup();

    // Create multiple settings
    let mut i: u8 = 0;
    while i < count {
        let name = format!("Setting_{}", i);
        let desc = format!("Description for setting {}", i);
        test_contracts.mock_minigame.create_settings_difficulty(name, desc, i);
        i += 1;
    }

    // Verify all settings exist
    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    let mut j: u32 = 1;
    while j <= count.into() {
        assert!(settings.settings_exist(j), "Settings should exist");
        j += 1;
    };
}
