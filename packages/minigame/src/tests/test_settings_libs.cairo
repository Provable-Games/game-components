// Test file for minigame/extensions/settings/libs.cairo
// Tests the settings library functions

use game_components_testing::constants::{CREATOR, MAX_U32};
use snforge_std::mock_call;
use starknet::ContractAddress;
use crate::extensions::settings::libs;
use crate::extensions::settings::structs::GameSetting;

// =============================================================================
// Test Address Helpers
// =============================================================================

fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

fn GAME_ADDRESS() -> ContractAddress {
    'GAME'.try_into().unwrap()
}

fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

// =============================================================================
// Unit Tests: get_settings_id
// =============================================================================

// Test SLIB-U-01: get_settings_id for valid token with settings
#[test]
fn test_get_settings_id_valid_token() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let expected_settings_id: u32 = 5;

    // Mock settings_id call
    mock_call(token_address, selector!("settings_id"), expected_settings_id, 1);

    let settings_id = libs::get_settings_id(token_address, token_id);

    assert!(settings_id == expected_settings_id, "Settings ID mismatch");
}

// Test SLIB-U-02: get_settings_id for token with default settings (0)
#[test]
fn test_get_settings_id_default_settings() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let expected_settings_id: u32 = 0;

    mock_call(token_address, selector!("settings_id"), expected_settings_id, 1);

    let settings_id = libs::get_settings_id(token_address, token_id);

    assert!(settings_id == 0, "Default settings ID should be 0");
}

// Test SLIB-U-03: get_settings_id for different tokens have different settings
#[test]
fn test_get_settings_id_different_tokens() {
    let token_address = TOKEN_ADDRESS();

    // First token has settings_id 1
    mock_call(token_address, selector!("settings_id"), 1_u32, 1);
    let settings_1 = libs::get_settings_id(token_address, 1);
    assert!(settings_1 == 1, "Token 1 settings mismatch");

    // Second token has settings_id 2
    mock_call(token_address, selector!("settings_id"), 2_u32, 1);
    let settings_2 = libs::get_settings_id(token_address, 2);
    assert!(settings_2 == 2, "Token 2 settings mismatch");

    // Third token has settings_id 10
    mock_call(token_address, selector!("settings_id"), 10_u32, 1);
    let settings_3 = libs::get_settings_id(token_address, 3);
    assert!(settings_3 == 10, "Token 3 settings mismatch");
}

// Test SLIB-U-04: get_settings_id with max token_id
#[test]
fn test_get_settings_id_max_token_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 18446744073709551615; // u64::MAX as felt252

    mock_call(token_address, selector!("settings_id"), 42_u32, 1);

    let settings_id = libs::get_settings_id(token_address, token_id);

    assert!(settings_id == 42, "Settings ID mismatch for max token_id");
}

// Test SLIB-U-05: get_settings_id with max settings_id
#[test]
fn test_get_settings_id_max_settings_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    mock_call(token_address, selector!("settings_id"), MAX_U32, 1);

    let settings_id = libs::get_settings_id(token_address, token_id);

    assert!(settings_id == MAX_U32, "Max settings ID mismatch");
}

// =============================================================================
// Unit Tests: create_settings
// =============================================================================

// Test SLIB-U-06: create_settings with basic valid data
#[test]
fn test_create_settings_basic() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();
    let settings_id: u32 = 1;

    // Mock create_settings call (returns unit)
    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        settings_id,
        "Test Settings",
        "A test",
        array![].span(),
    );
}

// Test SLIB-U-07: create_settings with settings data
#[test]
fn test_create_settings_with_settings_data() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    let settings = array![GameSetting { name: "speed", value: "fast" }].span();

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        1,
        "Speed Settings",
        "Settings for speed mode",
        settings,
    );
}

// Test SLIB-U-08: create_settings with multiple GameSetting items
#[test]
fn test_create_settings_multiple_settings() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    let settings = array![
        GameSetting { name: "difficulty", value: "hard" },
        GameSetting { name: "lives", value: "3" }, GameSetting { name: "time_limit", value: "300" },
    ]
        .span();

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        2,
        "Complex Settings",
        "Multiple options",
        settings,
    );
}

// Test SLIB-U-09: create_settings with empty name
#[test]
fn test_create_settings_empty_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        3,
        "", // empty name
        "Settings with no name",
        array![].span(),
    );
}

// Test SLIB-U-10: create_settings with empty description
#[test]
fn test_create_settings_empty_description() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        4,
        "Settings Name",
        "", // empty description
        array![].span(),
    );
}

// Test SLIB-U-11: create_settings with long name
#[test]
fn test_create_settings_long_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    let long_name: ByteArray =
        "This is a very long settings name that tests the limits of ByteArray storage and handling in the contract";

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        5,
        long_name,
        "Normal description",
        array![].span(),
    );
}

// Test SLIB-U-12: create_settings with long description
#[test]
fn test_create_settings_long_description() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    let long_desc: ByteArray =
        "This is a very long description that contains multiple sentences. It should test the limits of the ByteArray type and ensure that long strings are handled properly. The settings system needs to support arbitrary length descriptions.";

    libs::create_settings(
        token_address, game_address, creator_address, 6, "Normal Name", long_desc, array![].span(),
    );
}

// Test SLIB-U-13: create_settings with max settings_id
#[test]
fn test_create_settings_max_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        MAX_U32, // max u32
        "Max ID Settings",
        "Testing max ID",
        array![].span(),
    );
}

// Test SLIB-U-14: create_settings with zero settings_id
#[test]
fn test_create_settings_zero_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        0,
        "Zero ID Settings",
        "Testing zero ID",
        array![].span(),
    );
}

// Test SLIB-U-15: create_settings with many settings items
#[test]
fn test_create_settings_many_items() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    // Create 20 settings items
    let mut settings_items: Array<GameSetting> = array![];
    let mut i: u32 = 0;
    loop {
        if i >= 20 {
            break;
        }
        settings_items.append(GameSetting { name: "s", value: "v" });
        i += 1;
    }

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        7,
        "Many Settings",
        "Contains 20 items",
        settings_items.span(),
    );
}

// =============================================================================
// Integration Tests
// =============================================================================

// Test SLIB-I-01: create settings and verify retrieval
#[test]
fn test_create_then_get_settings() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();
    let settings_id: u32 = 10;

    // Mock create_settings call
    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        settings_id,
        "Integration Test",
        "Testing create then get",
        array![GameSetting { name: "test", value: "value" }].span(),
    );

    // Mock get settings_id call to return the same ID for a token
    mock_call(token_address, selector!("settings_id"), settings_id, 1);

    let retrieved = libs::get_settings_id(token_address, 1);
    assert!(retrieved == settings_id, "Settings ID should match after create");
}

// Test SLIB-I-02: multiple games creating settings
#[test]
fn test_multiple_games_settings() {
    let token_address = TOKEN_ADDRESS();
    let game1 = GAME_ADDRESS();
    let game2: ContractAddress = 'GAME2'.try_into().unwrap();
    let creator = CREATOR();

    // Mock multiple create_settings calls
    mock_call(token_address, selector!("create_settings"), (), 10);

    // Game 1 creates settings
    libs::create_settings(
        token_address, game1, creator, 1, "Game 1 Settings", "From game 1", array![].span(),
    );

    // Game 2 creates settings
    libs::create_settings(
        token_address, game2, creator, 2, "Game 2 Settings", "From game 2", array![].span(),
    );
    // Both should succeed (tested by no panic)
}

// Test SLIB-I-03: settings persistence across calls
#[test]
fn test_settings_persistence() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let settings_id: u32 = 42;

    // Mock multiple settings_id calls returning same value
    mock_call(token_address, selector!("settings_id"), settings_id, 5);

    // Query multiple times - should be consistent
    let result1 = libs::get_settings_id(token_address, token_id);
    let result2 = libs::get_settings_id(token_address, token_id);
    let result3 = libs::get_settings_id(token_address, token_id);

    assert!(result1 == settings_id, "First query mismatch");
    assert!(result2 == settings_id, "Second query mismatch");
    assert!(result3 == settings_id, "Third query mismatch");
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test SLIB-F-01: fuzz get_settings_id with random token_ids
#[test]
#[fuzzer]
fn test_get_settings_id_fuzz_token_id(token_id: felt252) {
    let token_address = TOKEN_ADDRESS();
    let expected: u32 = 1;

    mock_call(token_address, selector!("settings_id"), expected, 1);

    let result = libs::get_settings_id(token_address, token_id);
    assert!(result == expected, "Settings ID mismatch in fuzz test");
}

// Test SLIB-F-02: fuzz create_settings with random settings_id
#[test]
#[fuzzer]
fn test_create_settings_fuzz_id(settings_id: u32) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_settings"), (), 1);

    libs::create_settings(
        token_address,
        game_address,
        creator_address,
        settings_id,
        "Fuzz Test",
        "Fuzz description",
        array![].span(),
    );
}

// Test SLIB-F-03: fuzz get_settings_id with random return values
#[test]
#[fuzzer]
fn test_get_settings_id_fuzz_return_value(expected_settings_id: u32) {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    mock_call(token_address, selector!("settings_id"), expected_settings_id, 1);

    let result = libs::get_settings_id(token_address, token_id);
    assert!(result == expected_settings_id, "Fuzzed settings ID mismatch");
}
