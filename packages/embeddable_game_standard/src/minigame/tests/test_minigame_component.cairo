use game_components_interfaces::structs::metagame::{GameContext, GameContextDetails};
use game_components_testing::constants::{
    ALICE, BOB, CREATOR, CURRENT_TIME, FUTURE_TIME, USER1, USER2,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::minigame::extensions::objectives::interface::{
    IMinigameObjectivesDetailsDispatcher, IMinigameObjectivesDetailsDispatcherTrait,
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
};
use crate::minigame::extensions::settings::interface::{
    IMinigameSettingsDetailsDispatcher, IMinigameSettingsDetailsDispatcherTrait,
    IMinigameSettingsDispatcher, IMinigameSettingsDispatcherTrait,
};
use crate::minigame::interface::{
    IMINIGAME_ID, IMinigameDetailsDispatcher, IMinigameDetailsDispatcherTrait, IMinigameDispatcher,
    IMinigameDispatcherTrait, IMinigameTokenDataDispatcher, IMinigameTokenDataDispatcherTrait,
};
use crate::minigame::structs::MintGameParams;
use super::mocks::mock_minigame_contract::{
    IMockMinigameInitDispatcher, IMockMinigameInitDispatcherTrait,
};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// Deploy mock minigame contract
fn deploy_mock_game() -> (IMinigameDispatcher, IMockMinigameInitDispatcher) {
    let contract = declare("MockMinigameContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let minigame_dispatcher = IMinigameDispatcher { contract_address };
    let minigame_init_dispatcher = IMockMinigameInitDispatcher { contract_address };
    (minigame_dispatcher, minigame_init_dispatcher)
}

// Test MN-U-01: Initialize with all addresses
#[test]
fn test_initialize_with_all_addresses() {
    let token_address = addr(0x123);
    let settings_address = addr(0x456);
    let objectives_address = addr(0x789);

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = addr(0x0);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    // Initialize the minigame mock
    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(settings_address),
            Option::Some(objectives_address),
            token_address,
            Option::None // royalty_fraction
        );

    // Verify addresses are stored correctly
    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
    assert!(
        minigame_dispatcher.settings_address() == settings_address, "Settings address mismatch",
    );
    assert!(
        minigame_dispatcher.objectives_address() == objectives_address,
        "Objectives address mismatch",
    );

    // Verify SRC5 interface registration
    let src5_dispatcher = ISRC5Dispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };
    assert!(src5_dispatcher.supports_interface(IMINIGAME_ID), "Should support IMinigame interface");
}


// Test MN-U-03: Get token_address
#[test]
fn test_get_token_address() {
    let token_address = addr(0x111);

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = addr(0x0);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None // royalty_fraction
        );

    // Verify token_address returns correct value
    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// Test MN-U-04: Get settings_address
#[test]
fn test_get_settings_address() {
    let token_address = addr(0x111);
    let settings_address = addr(0x222);

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = addr(0x0);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(settings_address),
            Option::None,
            token_address,
            Option::None // royalty_fraction
        );

    // Verify settings_address returns correct value
    assert!(
        minigame_dispatcher.settings_address() == settings_address, "Settings address mismatch",
    );
}

// Test MN-U-05: Get objectives_address
#[test]
fn test_get_objectives_address() {
    let token_address = addr(0x111);
    let objectives_address = addr(0x333);

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = addr(0x0);
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objectives_address),
            token_address,
            Option::None // royalty_fraction
        );

    // Verify objectives_address returns correct value
    assert!(
        minigame_dispatcher.objectives_address() == objectives_address,
        "Objectives address mismatch",
    );
}

// =============================================================================
// Additional Initialization Tests
// =============================================================================

// Test MN-U-02: Initialize with no optional addresses
#[test]
fn test_initialize_with_no_optional_addresses() {
    let token_address = addr(0x123);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None, // color
            Option::None, // client_url
            Option::None, // renderer_address
            Option::None, // settings_address - will default to contract address in mock
            Option::None, // objectives_address - will default to contract address in mock
            token_address,
            Option::None // royalty_fraction
        );

    // Verify token_address is stored
    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// Test MN-U-03: Initialize with invalid token (missing IMINIGAME_TOKEN_ID)
#[test]
#[should_panic(expected: "Minigame: Token does not support IMINIGAME_TOKEN_ID")]
fn test_initialize_with_invalid_token() {
    let token_address = addr(0x123);

    // Mock supports_interface to return false
    mock_call(token_address, selector!("supports_interface"), false, 100);

    let (_, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );
}

// Test MN-U-07: Initialize verifies SRC5 interface registration
#[test]
fn test_initialize_verifies_src5_interface() {
    let token_address = addr(0x123);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let src5_dispatcher = ISRC5Dispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };
    assert!(src5_dispatcher.supports_interface(IMINIGAME_ID), "Should support IMinigame interface");
}

// Test MN-U-08: Initialize with all optional metadata
#[test]
fn test_initialize_with_all_optional_metadata() {
    let token_address = addr(0x123);
    let renderer_address = addr(0x999);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            CREATOR(),
            "Full Game",
            "Full Description",
            "Full Developer",
            "Full Publisher",
            "Action",
            "https://example.com/image.png",
            Option::Some("blue"),
            Option::Some("https://client.example.com"),
            Option::Some(renderer_address),
            Option::None,
            Option::None,
            token_address,
            Option::Some(500_u128) // 5% royalty
        );

    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// Test MN-U-10: Initialize with only settings_address
#[test]
fn test_initialize_with_only_settings_address() {
    let token_address = addr(0x123);
    let settings_address = addr(0x456);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(settings_address),
            Option::None, // no objectives
            token_address,
            Option::None,
        );

    assert!(
        minigame_dispatcher.settings_address() == settings_address, "Settings address mismatch",
    );
}

// =============================================================================
// Address Getter Edge Cases
// =============================================================================

// Test MN-U-12: Get token_address before initialization returns zero
#[test]
fn test_get_token_address_before_init() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    // Before initialization, token_address should be zero
    // Note: Mock contract always initializes settings/objectives, so we just check it doesn't panic
    let token_addr = minigame_dispatcher.token_address();
    // Address will be zero if not set
    assert!(token_addr == addr(0x0), "Uninitialized token_address should be zero");
}

// Test MN-U-14: Get settings_address when not set
#[test]
fn test_get_settings_address_when_not_set() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    // Before initialization
    let settings_addr = minigame_dispatcher.settings_address();
    assert!(settings_addr == addr(0x0), "Uninitialized settings_address should be zero");
}

// Test MN-U-16: Get objectives_address when not set
#[test]
fn test_get_objectives_address_when_not_set() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    // Before initialization
    let objectives_addr = minigame_dispatcher.objectives_address();
    assert!(objectives_addr == addr(0x0), "Uninitialized objectives_address should be zero");
}

// =============================================================================
// Mint Game Tests
// =============================================================================

// Test MN-U-17: Mint game with all parameters
#[test]
fn test_mint_game_with_all_parameters() {
    let token_address = addr(0x123);
    let renderer_address = addr(0x999);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some('Player1'),
            Option::Some(1_u32),
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
            Option::Some(5_u32),
            Option::None, // context
            Option::Some("https://client.url"),
            Option::Some(renderer_address),
            ALICE(),
            true, // soulbound
            false, // paymaster
            0, // salt
            0 // metadata
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-U-18: Mint game with minimal parameters
#[test]
fn test_mint_game_with_minimal_parameters() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
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

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-U-19: Mint game as soulbound
#[test]
fn test_mint_game_as_soulbound() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true, // soulbound
            false, // paymaster
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-U-20: Mint game as transferable
#[test]
fn test_mint_game_as_transferable() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false, // not soulbound
            false, // paymaster
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-U-21: Mint game with player_name
#[test]
fn test_mint_game_with_player_name() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some('SuperPlayer'),
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

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-U-23: Mint game with time bounds
#[test]
fn test_mint_game_with_time_bounds() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
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

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// =============================================================================
// Mint Game Batch Tests
// =============================================================================

// Test MN-U-25: Batch mint multiple games
#[test]
fn test_mint_game_batch_multiple() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![1, 2, 3];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let mints = array![
        MintGameParams {
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::Some('Player2'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::Some('Player3'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: USER1(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 3, "Should return 3 token IDs");
}

// Test MN-U-26: Batch mint with empty array
#[test]
fn test_mint_game_batch_empty() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let result = minigame_dispatcher.mint_game_batch(array![]);

    assert!(result.len() == 0, "Should return empty array");
}

// Test MN-U-27: Batch mint with single item
#[test]
fn test_mint_game_batch_single() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![1];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let mints = array![
        MintGameParams {
            player_name: Option::Some('SinglePlayer'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 1, "Should return 1 token ID");
}

// Test MN-U-28: Batch mint with mixed parameters
#[test]
fn test_mint_game_batch_mixed_params() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![1, 2];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let mints = array![
        MintGameParams {
            player_name: Option::Some('Player1'),
            settings_id: Option::Some(1_u32),
            start: Option::Some(100_u64),
            end: Option::Some(200_u64),
            objective_id: Option::Some(5_u32),
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: true, // soulbound
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::None, // no player name
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false, // not soulbound
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 2, "Should return 2 token IDs");
}

// Test MN-U-30: Batch mint to multiple recipients
#[test]
fn test_mint_game_batch_multiple_recipients() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![1, 2, 3, 4];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let mints = array![
        MintGameParams {
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: USER1(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: USER2(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 4, "Should return 4 token IDs");
}

// =============================================================================
// IMinigameTokenData Tests
// =============================================================================

// Test MN-TD-01: score returns correct value
#[test]
fn test_minigame_token_data_score() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    // Mock contract defaults to 0 score
    let score = token_data_dispatcher.score(1);
    assert!(score == 0, "Default score should be 0");
}

// Test MN-TD-02: game_over returns correct value
#[test]
fn test_minigame_token_data_game_over() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    // Mock contract defaults to false game_over
    let game_over = token_data_dispatcher.game_over(1);
    assert!(!game_over, "Default game_over should be false");
}

// Test MN-TD-03: score_batch returns correct values
#[test]
fn test_minigame_token_data_score_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3];
    let scores = token_data_dispatcher.score_batch(token_ids.span());

    assert!(scores.len() == 3, "Should return 3 scores");
    assert!(*scores.at(0) == 0, "Score 1 should be 0");
    assert!(*scores.at(1) == 0, "Score 2 should be 0");
    assert!(*scores.at(2) == 0, "Score 3 should be 0");
}

// Test MN-TD-04: game_over_batch returns correct values
#[test]
fn test_minigame_token_data_game_over_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3];
    let game_overs = token_data_dispatcher.game_over_batch(token_ids.span());

    assert!(game_overs.len() == 3, "Should return 3 game_over values");
    assert!(!*game_overs.at(0), "Game over 1 should be false");
    assert!(!*game_overs.at(1), "Game over 2 should be false");
    assert!(!*game_overs.at(2), "Game over 3 should be false");
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test MN-F-01: Fuzz mint_game with random player_name
#[test]
#[fuzzer]
fn test_mint_game_fuzz_player_name(player_name: felt252) {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some(player_name),
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

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-F-02: Fuzz mint_game with random settings_id
#[test]
#[fuzzer]
fn test_mint_game_fuzz_settings_id(settings_id: u32) {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::Some(settings_id),
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

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// =============================================================================
// IMinigameDetails Tests
// =============================================================================

// Test MN-DET-01: token_name returns correct value
#[test]
fn test_minigame_details_token_name() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let name = details_dispatcher.token_name(1);
    assert!(name == "Test Token", "Token name mismatch");
}

// Test MN-DET-02: token_description returns correct value
#[test]
fn test_minigame_details_token_description() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let description = details_dispatcher.token_description(42);
    assert!(description == "Test Token Description for token 42", "Token description mismatch");
}

// Test MN-DET-03: game_details returns correct value
#[test]
fn test_minigame_details_game_details() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let details = details_dispatcher.game_details(5);
    assert!(details.len() == 1, "Should have 1 game detail");

    let detail = details.at(0);
    assert!(detail.name == @"Test Game Detail", "Game detail name mismatch");
}

// Test MN-DET-04: token_name_batch returns correct values
#[test]
fn test_minigame_details_token_name_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3];
    let names = details_dispatcher.token_name_batch(token_ids.span());

    assert!(names.len() == 3, "Should return 3 names");
    assert!(names.at(0) == @"Test Token", "Name 1 mismatch");
    assert!(names.at(1) == @"Test Token", "Name 2 mismatch");
    assert!(names.at(2) == @"Test Token", "Name 3 mismatch");
}

// Test MN-DET-05: token_description_batch returns correct values
#[test]
fn test_minigame_details_token_description_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2];
    let descriptions = details_dispatcher.token_description_batch(token_ids.span());

    assert!(descriptions.len() == 2, "Should return 2 descriptions");
    assert!(descriptions.at(0) == @"Test Token Description for token 1", "Description 1 mismatch");
    assert!(descriptions.at(1) == @"Test Token Description for token 2", "Description 2 mismatch");
}

// Test MN-DET-06: game_details_batch returns correct values
#[test]
fn test_minigame_details_game_details_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4];
    let details_batch = details_dispatcher.game_details_batch(token_ids.span());

    assert!(details_batch.len() == 4, "Should return 4 detail arrays");

    // Check first token's details
    let details1 = details_batch.at(0);
    assert!(details1.len() == 1, "Token 1 should have 1 detail");
}

// Test MN-DET-07: empty batch operations
#[test]
fn test_minigame_details_empty_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let empty_ids: Array<felt252> = array![];

    let names = details_dispatcher.token_name_batch(empty_ids.span());
    assert!(names.len() == 0, "Should return empty array for names");

    let descriptions = details_dispatcher.token_description_batch(empty_ids.span());
    assert!(descriptions.len() == 0, "Should return empty array for descriptions");

    let details = details_dispatcher.game_details_batch(empty_ids.span());
    assert!(details.len() == 0, "Should return empty array for details");
}

// =============================================================================
// Settings Batch Tests
// =============================================================================

// Test MN-SET-01: settings_exist_batch returns correct values
#[test]
fn test_settings_exist_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let settings_dispatcher = IMinigameSettingsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let settings_ids: Array<u32> = array![1, 5, 10, 11, 15];
    let results = settings_dispatcher.settings_exist_batch(settings_ids.span());

    assert!(results.len() == 5, "Should return 5 results");
    assert!(*results.at(0) == true, "Settings 1 should exist");
    assert!(*results.at(1) == true, "Settings 5 should exist");
    assert!(*results.at(2) == true, "Settings 10 should exist");
    assert!(*results.at(3) == false, "Settings 11 should not exist");
    assert!(*results.at(4) == false, "Settings 15 should not exist");
}

// Test MN-SET-02: settings_exist_batch with empty array
#[test]
fn test_settings_exist_batch_empty() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let settings_dispatcher = IMinigameSettingsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let empty_ids: Array<u32> = array![];
    let results = settings_dispatcher.settings_exist_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// Test MN-SET-03: settings_details_batch returns correct values
#[test]
fn test_settings_details_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let settings_ids: Array<u32> = array![1, 5];
    let results = settings_details_dispatcher.settings_details_batch(settings_ids.span());

    assert!(results.len() == 2, "Should return 2 settings");

    let settings1 = results.at(0);
    assert!(settings1.name == @"Mock Settings", "Settings 1 name mismatch");
}

// =============================================================================
// Objectives Batch Tests
// =============================================================================

// Test MN-OBJ-01: objective_exists_batch returns correct values
#[test]
fn test_objective_exists_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_dispatcher = IMinigameObjectivesDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let objective_ids: Array<u32> = array![1, 5, 10, 11, 15];
    let results = objectives_dispatcher.objective_exists_batch(objective_ids.span());

    assert!(results.len() == 5, "Should return 5 results");
    assert!(*results.at(0) == true, "Objective 1 should exist");
    assert!(*results.at(1) == true, "Objective 5 should exist");
    assert!(*results.at(2) == true, "Objective 10 should exist");
    assert!(*results.at(3) == false, "Objective 11 should not exist");
    assert!(*results.at(4) == false, "Objective 15 should not exist");
}

// Test MN-OBJ-02: objective_exists_batch with empty array
#[test]
fn test_objective_exists_batch_empty() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_dispatcher = IMinigameObjectivesDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let empty_ids: Array<u32> = array![];
    let results = objectives_dispatcher.objective_exists_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// Test MN-OBJ-03: objectives_details_batch returns correct values
#[test]
fn test_objectives_details_batch() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let objective_ids: Array<u32> = array![1, 2, 3];
    let results = objectives_details_dispatcher.objectives_details_batch(objective_ids.span());

    assert!(results.len() == 3, "Should return 3 objectives detail results");

    // Check first objective's details
    let details1 = results.at(0);
    assert!(details1.objectives.len() == 1, "Objective 1 should have 1 property");
}

// Test MN-OBJ-04: objectives_details_batch with empty array
#[test]
fn test_objectives_details_batch_empty() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let empty_ids: Array<u32> = array![];
    let results = objectives_details_dispatcher.objectives_details_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// =============================================================================
// Initialize with Registry Tests
// =============================================================================

// Test MN-REG-01: Initialize with registry that supports interface
#[test]
fn test_initialize_with_registry_supports_interface() {
    let token_address = addr(0x123);
    let registry_address = addr(0x456);

    // Mock token supports interface
    mock_call(token_address, selector!("supports_interface"), true, 100);
    // Mock token returns registry address
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);
    // Mock registry supports interface
    mock_call(registry_address, selector!("supports_interface"), true, 100);
    // Mock registry register_game call
    mock_call(registry_address, selector!("register_game"), 1_u64, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            CREATOR(),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::Some("blue"),
            Option::Some("https://client.url"),
            Option::Some(addr(0x999)),
            Option::None,
            Option::None,
            token_address,
            Option::Some(500_u128),
        );

    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// Test MN-REG-02: Initialize with registry that does not support interface
#[test]
fn test_initialize_with_registry_no_support() {
    let token_address = addr(0x123);
    let registry_address = addr(0x456);

    // Mock token supports interface
    mock_call(token_address, selector!("supports_interface"), true, 100);
    // Mock token returns registry address
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);
    // Mock registry does NOT support interface
    mock_call(registry_address, selector!("supports_interface"), false, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    // Should not panic - registry doesn't support interface, so register_game is not called
    minigame_init_dispatcher
        .initializer(
            CREATOR(),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// =============================================================================
// Additional Fuzz Tests
// =============================================================================

// Test MN-F-03: Fuzz score with random token_id
#[test]
#[fuzzer]
fn test_minigame_token_data_score_fuzz(token_id: felt252) {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    // Mock contract always returns 0 for any token
    let score = token_data_dispatcher.score(token_id);
    assert!(score == 0, "Default score should be 0");
}

// Test MN-F-04: Fuzz game_over with random token_id
#[test]
#[fuzzer]
fn test_minigame_token_data_game_over_fuzz(token_id: felt252) {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let game_over = token_data_dispatcher.game_over(token_id);
    assert!(!game_over, "Default game_over should be false");
}

// Test MN-F-05: Fuzz mint_game with random objective_id
#[test]
#[fuzzer]
fn test_mint_game_fuzz_objective_id(objective_id: u32) {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_id),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// =============================================================================
// Tests with GameContextDetails
// =============================================================================

// Test MN-CTX-01: mint_game with context
#[test]
fn test_mint_game_with_context() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let context = GameContextDetails {
        name: "Test Context",
        description: "A test context for minting",
        id: Option::Some(1_u32),
        context: array![
            GameContext { name: "level", value: "1" },
            GameContext { name: "difficulty", value: "easy" },
        ]
            .span(),
    };

    let token_id = minigame_dispatcher
        .mint_game(
            Option::Some('ContextPlayer'),
            Option::Some(1_u32),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(context),
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-CTX-02: mint_game_batch with context
#[test]
fn test_mint_game_batch_with_context() {
    let token_address = addr(0x123);
    let expected_tokens: Array<felt252> = array![1, 2];

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let context1 = GameContextDetails {
        name: "Context 1",
        description: "First context",
        id: Option::Some(1_u32),
        context: array![GameContext { name: "key", value: "value1" }].span(),
    };

    let context2 = GameContextDetails {
        name: "Context 2",
        description: "Second context",
        id: Option::None,
        context: array![].span(),
    };

    let mints = array![
        MintGameParams {
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::Some(context1),
            client_url: Option::Some("https://url1.com"),
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintGameParams {
            player_name: Option::Some('Player2'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::Some(context2),
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: true,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 2, "Should return 2 token IDs");
}

// =============================================================================
// Additional Mock Contract Coverage Tests
// =============================================================================

// Test MN-MOCK-01: score_batch iteration
#[test]
fn test_score_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let scores = token_data_dispatcher.score_batch(token_ids.span());

    assert!(scores.len() == 10, "Should return 10 scores");
}

// Test MN-MOCK-02: game_over_batch iteration
#[test]
fn test_game_over_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let token_data_dispatcher = IMinigameTokenDataDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let results = token_data_dispatcher.game_over_batch(token_ids.span());

    assert!(results.len() == 10, "Should return 10 results");
}

// Test MN-MOCK-03: token_name_batch iteration
#[test]
fn test_token_name_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let names = details_dispatcher.token_name_batch(token_ids.span());

    assert!(names.len() == 10, "Should return 10 names");
}

// Test MN-MOCK-04: token_description_batch iteration
#[test]
fn test_token_description_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let descriptions = details_dispatcher.token_description_batch(token_ids.span());

    assert!(descriptions.len() == 10, "Should return 10 descriptions");
}

// Test MN-MOCK-05: game_details_batch iteration
#[test]
fn test_game_details_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let details_dispatcher = IMinigameDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let details = details_dispatcher.game_details_batch(token_ids.span());

    assert!(details.len() == 10, "Should return 10 detail arrays");
}

// Test MN-MOCK-06: settings_exist_batch iteration
#[test]
fn test_mock_settings_exist_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let settings_dispatcher = IMinigameSettingsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let settings_ids: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    let results = settings_dispatcher.settings_exist_batch(settings_ids.span());

    assert!(results.len() == 11, "Should return 11 results");
}

// Test MN-MOCK-07: settings_details_batch iteration
#[test]
fn test_mock_settings_details_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let settings_details_dispatcher = IMinigameSettingsDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let settings_ids: Array<u32> = array![1, 2, 3, 4, 5];
    let results = settings_details_dispatcher.settings_details_batch(settings_ids.span());

    assert!(results.len() == 5, "Should return 5 settings");
}

// Test MN-MOCK-08: objective_exists_batch iteration
#[test]
fn test_mock_objective_exists_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_dispatcher = IMinigameObjectivesDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let objective_ids: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    let results = objectives_dispatcher.objective_exists_batch(objective_ids.span());

    assert!(results.len() == 11, "Should return 11 results");
}

// Test MN-MOCK-09: objectives_details_batch iteration
#[test]
fn test_mock_objectives_details_batch_iteration() {
    let (minigame_dispatcher, _) = deploy_mock_game();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher {
        contract_address: minigame_dispatcher.contract_address,
    };

    let objective_ids: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let results = objectives_details_dispatcher.objectives_details_batch(objective_ids.span());

    assert!(results.len() == 10, "Should return 10 objectives detail results");
}

// =============================================================================
// Additional Coverage Tests
// =============================================================================

// Test MN-ADD-01: Initialize with all optional parameters
#[test]
fn test_initialize_with_all_optional_params() {
    let token_address = addr(0x123);
    let settings_address = addr(0x456);
    let objectives_address = addr(0x789);
    let renderer_address = addr(0xabc);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            CREATOR(),
            "Full Game",
            "Full Description",
            "Full Developer",
            "Full Publisher",
            "Full Genre",
            "https://full-image.url",
            Option::Some("custom-color"),
            Option::Some("https://custom-client.url"),
            Option::Some(renderer_address),
            Option::Some(settings_address),
            Option::Some(objectives_address),
            token_address,
            Option::Some(2500_u128) // 25% royalty
        );

    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
    assert!(
        minigame_dispatcher.settings_address() == settings_address, "Settings address mismatch",
    );
    assert!(
        minigame_dispatcher.objectives_address() == objectives_address,
        "Objectives address mismatch",
    );
}

// Test MN-ADD-02: Initialize with external settings/objectives addresses
#[test]
fn test_initialize_with_external_extension_addresses() {
    let token_address = addr(0x123);
    let external_settings = addr(0xdef);
    let external_objectives = addr(0xfed);

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            CREATOR(),
            "External Game",
            "External Description",
            "External Developer",
            "External Publisher",
            "External Genre",
            "https://external-image.url",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(external_settings),
            Option::Some(external_objectives),
            token_address,
            Option::None,
        );

    // When external addresses provided, they should be used
    assert!(
        minigame_dispatcher.settings_address() == external_settings,
        "External settings address should be used",
    );
    assert!(
        minigame_dispatcher.objectives_address() == external_objectives,
        "External objectives address should be used",
    );
}

// Test MN-ADD-03: mint_game_batch with large batch
#[test]
fn test_mint_game_batch_large() {
    let token_address = addr(0x123);
    let mut expected_tokens: Array<felt252> = array![];
    let mut mints: Array<MintGameParams> = array![];

    // Create 10 mints
    let mut i: u64 = 0;
    loop {
        if i >= 10 {
            break;
        }
        expected_tokens.append((i + 1).into());
        mints
            .append(
                MintGameParams {
                    player_name: Option::None,
                    settings_id: Option::None,
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    to: ALICE(),
                    soulbound: false,
                    paymaster: false,
                    salt: 0,
                    metadata: 0,
                },
            );
        i += 1;
    }

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint_batch"), expected_tokens.clone(), 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let result = minigame_dispatcher.mint_game_batch(mints);

    assert!(result.len() == 10, "Should return 10 token IDs");
}

// Test MN-ADD-04: mint_game with soulbound true
#[test]
fn test_mint_game_soulbound() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true, // soulbound
            false, // paymaster
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-ADD-05: mint_game with client_url
#[test]
fn test_mint_game_with_client_url() {
    let token_address = addr(0x123);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some("https://custom-client.example.com"),
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test MN-ADD-06: mint_game with renderer_address
#[test]
fn test_mint_game_with_renderer_address() {
    let token_address = addr(0x123);
    let renderer_address = addr(0x999);
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("supports_interface"), true, 100);
    mock_call(token_address, selector!("game_registry_address"), addr(0x0), 100);
    mock_call(token_address, selector!("mint"), expected_token_id, 100);

    let (minigame_dispatcher, minigame_init_dispatcher) = deploy_mock_game();

    minigame_init_dispatcher
        .initializer(
            addr(0x0),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            token_address,
            Option::None,
        );

    let token_id = minigame_dispatcher
        .mint_game(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(renderer_address),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}
