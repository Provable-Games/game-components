use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, mock_call};
use starknet::ContractAddress;
use crate::interface::{IMINIGAME_ID, IMinigameDispatcher, IMinigameDispatcherTrait};
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
