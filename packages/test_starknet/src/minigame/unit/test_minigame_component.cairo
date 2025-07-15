use game_components_minigame::interface::{IMinigameDispatcherTrait, IMINIGAME_ID};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{contract_address_const, get_caller_address};
use core::num::traits::Zero;
use snforge_std::{
    start_cheat_caller_address, stop_cheat_caller_address, mock_call,
    start_cheat_block_timestamp_global,
};
use crate::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockInitDispatcherTrait, IMinigameStarknetMockDispatcherTrait,
};
use game_components_token::interface::{IMinigameTokenMixinDispatcherTrait};
use crate::token::setup::{deploy_mock_game, deploy_optimized_token_with_game};

// Test MN-U-01: Initialize with all addresses
#[test]
fn test_initialize_with_all_addresses() {
    let token_address = contract_address_const::<0x123>();
    let settings_address = contract_address_const::<0x456>();
    let objectives_address = contract_address_const::<0x789>();

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = contract_address_const::<0x0>();
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Initialize the minigame mock
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x0>(),
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

// Test MN-U-02: Initialize with optional addresses = 0
#[test]
fn test_initialize_with_optional_zero() {
    let token_address = contract_address_const::<0xABC>();

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = contract_address_const::<0x0>();
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Initialize with zero addresses for optional fields
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x0>(),
            "TestGame",
            "TestDescription",
            "TestDeveloper",
            "TestPublisher",
            "TestGenre",
            "TestImage",
            Option::None,
            Option::None,
            Option::None,
            Option::None, // Zero settings address
            Option::None, // Zero objectives address
            token_address,
        );

    // Verify addresses
    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
    assert!(minigame_dispatcher.settings_address().is_zero(), "Settings address should be zero");
    assert!(
        minigame_dispatcher.objectives_address().is_zero(), "Objectives address should be zero",
    );
}

// Test MN-U-03: Get token_address
#[test]
fn test_get_token_address() {
    let token_address = contract_address_const::<0x111>();

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = contract_address_const::<0x0>();
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x0>(),
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
        );

    // Verify token_address returns correct value
    assert!(minigame_dispatcher.token_address() == token_address, "Token address mismatch");
}

// Test MN-U-04: Get settings_address
#[test]
fn test_get_settings_address() {
    let token_address = contract_address_const::<0x111>();
    let settings_address = contract_address_const::<0x222>();

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = contract_address_const::<0x0>();
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x0>(),
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
        );

    // Verify settings_address returns correct value
    assert!(
        minigame_dispatcher.settings_address() == settings_address, "Settings address mismatch",
    );
}

// Test MN-U-05: Get objectives_address
#[test]
fn test_get_objectives_address() {
    let token_address = contract_address_const::<0x111>();
    let objectives_address = contract_address_const::<0x333>();

    // Mock the supports_interface call for the token address
    mock_call(token_address, selector!("supports_interface"), true, 100);

    // Mock the game_registry_address call to return a dummy registry address
    let registry_address = contract_address_const::<0x0>();
    mock_call(token_address, selector!("game_registry_address"), registry_address, 100);

    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Initialize
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x0>(),
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
        );

    // Verify objectives_address returns correct value
    assert!(
        minigame_dispatcher.objectives_address() == objectives_address,
        "Objectives address mismatch",
    );
}

// Test MN-U-06: pre_action with owned token
#[test]
fn test_pre_action_with_owned_token() {
    // Deploy mock game first
    let (minigame_dispatcher, minigame_init_dispatcher, mock_dispatcher) = deploy_mock_game();

    // Deploy token contract with the game address
    let (_, _, _, token_address) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Initialize minigame with token address
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x1>(), // game_creator
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
        );

    // Mint a token to the current caller
    let owner_address = get_caller_address();
    let token_id = mock_dispatcher
        .mint(
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start_time
            Option::None, // end_time
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            owner_address,
            false // soulbound
        );

    // Use libs::pre_action to test the internal function
    game_components_minigame::libs::pre_action(token_address, token_id);
}

// Test MN-U-07: pre_action with valid playable token (no ownership check in pre_action)
#[test]
fn test_pre_action_with_unowned_but_playable_token() {
    // Deploy mock game first
    let (minigame_dispatcher, minigame_init_dispatcher, mock_dispatcher) = deploy_mock_game();

    // Deploy token contract with the game address
    let (_, _, _, token_address) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Initialize minigame with token address
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x1>(), // game_creator
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
        );

    // Mint a token to a different owner
    let other_owner = contract_address_const::<0x888>();
    let token_id = mock_dispatcher
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            other_owner,
            false,
        );

    // pre_action only checks playability, not ownership - should succeed
    let different_caller = contract_address_const::<0x777>();
    start_cheat_caller_address(token_address, different_caller);
    game_components_minigame::libs::pre_action(token_address, token_id);
    stop_cheat_caller_address(token_address);
}

// Test MN-U-08: pre_action with expired token
#[test]
#[should_panic(expected: "Game is not playable")]
fn test_pre_action_with_expired_token() {
    // Deploy mock game first
    let (minigame_dispatcher, minigame_init_dispatcher, _) = deploy_mock_game();

    // Deploy token contract with the game address
    let (token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Initialize minigame with token address
    minigame_init_dispatcher
        .initializer(
            contract_address_const::<0x1>(), // game_creator
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
        );

    // Mint a token with an expired timestamp through the token contract
    let owner_address = contract_address_const::<0x1234>(); // Use a fixed address instead of caller
    let past_time: u64 = 100;
    let expired_time: u64 = 200; // Expired in the past

    let token_id = token_dispatcher
        .mint(
            Option::Some(minigame_dispatcher.contract_address), // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::Some(past_time), // start time
            Option::Some(expired_time), // End time in the past
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            owner_address,
            false // soulbound
        );

    // Warp to a time after the token has expired
    start_cheat_block_timestamp_global(300);

    // Should panic because token is not playable (expired)
    game_components_minigame::libs::pre_action(token_address, token_id);
}
// // Test MN-U-09: pre_action with game_over token
// #[test]
// #[should_panic(expected: ('Game is not playable',))]
// fn test_pre_action_with_game_over_token() {
//     // This would require a token with game_over = true
//     // Similar setup to expired token test

//     // Deploy mock token contract
//     let token_contract = declare("MockMinigameTokenGameOver").unwrap().contract_class();
//     let (token_address, _) = token_contract.deploy(@array![]).unwrap();

//     // Deploy minigame contract
//     let minigame_contract = declare("MockMinigameContract").unwrap().contract_class();
//     let mut calldata = array![];
//     calldata.append(token_address.into());
//     calldata.append(contract_address_const::<0x0>().into());
//     calldata.append(contract_address_const::<0x0>().into());

//     let (minigame_address, _) = minigame_contract.deploy(@calldata).unwrap();
//     let mock_dispatcher = IMockMinigameDispatcher { contract_address: minigame_address };

//     // Mint a token first - the MockMinigameTokenGameOver has game_over = true
//     let token_dispatcher = IMinigameTokenDispatcher { contract_address: token_address };
//     let owner_address = get_caller_address();
//     token_dispatcher
//         .mint(
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             Option::None,
//             owner_address,
//             false,
//         );

//     // Should panic because game is over
//     mock_dispatcher.pre_action(1);
// }

// // Test MN-U-10: post_action triggers update
// #[test]
// fn test_post_action_triggers_update() {
//     // Deploy mock token contract
//     let token_contract = declare("MockMinigameToken").unwrap().contract_class();
//     let (token_address, _) = token_contract.deploy(@array![]).unwrap();

//     // Deploy minigame contract
//     let minigame_contract = declare("MockMinigameContract").unwrap().contract_class();
//     let mut calldata = array![];
//     calldata.append(token_address.into());
//     calldata.append(contract_address_const::<0x0>().into());
//     calldata.append(contract_address_const::<0x0>().into());

//     let (minigame_address, _) = minigame_contract.deploy(@calldata).unwrap();
//     let mock_dispatcher = IMockMinigameDispatcher { contract_address: minigame_address };

//     // Call post_action - should trigger update_game on token
//     mock_dispatcher.post_action(1);
//     // In a real test, we would verify that update_game was called
// // For now, just verify no panic
// }

// // Test MN-U-11: get_player_name
// #[test]
// fn test_get_player_name() {
//     // Deploy mock token contract
//     let token_contract = declare("MockMinigameToken").unwrap().contract_class();
//     let (token_address, _) = token_contract.deploy(@array![]).unwrap();

//     // Deploy minigame contract
//     let minigame_contract = declare("MockMinigameContract").unwrap().contract_class();
//     let mut calldata = array![];
//     calldata.append(token_address.into());
//     calldata.append(contract_address_const::<0x0>().into());
//     calldata.append(contract_address_const::<0x0>().into());

//     let (minigame_address, _) = minigame_contract.deploy(@calldata).unwrap();
//     let mock_dispatcher = IMockMinigameDispatcher { contract_address: minigame_address };

//     // Get player name for token
//     let name = mock_dispatcher.get_player_name(1);

//     // MockMinigameToken returns empty string
//     assert!(name == "", "Player name should be empty");
// }

// // Test IMinigameTokenData implementation
// #[test]
// fn test_minigame_token_data_score() {
//     // Deploy minigame contract with score tracking
//     let minigame_contract = declare("MockMinigameContractWithScore").unwrap().contract_class();
//     let mut calldata = array![];
//     calldata.append(contract_address_const::<0x111>().into());
//     calldata.append(contract_address_const::<0x0>().into());
//     calldata.append(contract_address_const::<0x0>().into());

//     let (minigame_address, _) = minigame_contract.deploy(@calldata).unwrap();
//     let token_data_dispatcher = IMinigameTokenDataDispatcher { contract_address: minigame_address
//     };

//     // Check score
//     let score = token_data_dispatcher.score(1);
//     assert!(score == 0, "Initial score should be 0");
// }

// #[test]
// fn test_minigame_token_data_game_over() {
//     // Deploy minigame contract
//     let minigame_contract = declare("MockMinigameContractWithScore").unwrap().contract_class();
//     let mut calldata = array![];
//     calldata.append(contract_address_const::<0x111>().into());
//     calldata.append(contract_address_const::<0x0>().into());
//     calldata.append(contract_address_const::<0x0>().into());

//     let (minigame_address, _) = minigame_contract.deploy(@calldata).unwrap();
//     let token_data_dispatcher = IMinigameTokenDataDispatcher { contract_address: minigame_address
//     };

//     // Check game over status
//     let game_over = token_data_dispatcher.game_over(1);
//     assert!(!game_over, "Initial game_over should be false");
// }


