// ==============================================================================
// MINIGAME REGISTRY COMPONENT TESTS
// ==============================================================================
// Tests for the MinigameRegistryComponent which handles game registration,
// metadata storage, and ID mapping.

use core::num::traits::Zero;
use game_components_registry::interface::{
    IMINIGAME_REGISTRY_ID, IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_testing::constants::{CREATOR, RENDERER_ADDRESS, USER1};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, mock_call, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

// ==============================================================================
// HELPER FUNCTIONS
// ==============================================================================

/// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// ==============================================================================
// DEPLOYMENT HELPERS
// ==============================================================================

/// Deploy the mock registry contract
fn deploy_mock_registry() -> IMinigameRegistryDispatcher {
    let contract = declare("MockRegistryContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    IMinigameRegistryDispatcher { contract_address }
}

/// Deploy a mock minigame contract for registration testing
fn deploy_mock_minigame_for_registration() -> ContractAddress {
    let contract = declare("minigame_starknet_mock").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

// ==============================================================================
// INITIALIZATION TESTS
// ==============================================================================

// Test REG-U-01: Registry initializes with zero game count
#[test]
fn test_registry_initializes_with_zero_count() {
    let registry = deploy_mock_registry();

    assert!(registry.game_count() == 0, "Initial game count should be 0");
}

// Test REG-U-02: Registry supports IMINIGAME_REGISTRY_ID interface
#[test]
fn test_registry_supports_src5_interface() {
    let registry = deploy_mock_registry();
    let src5 = ISRC5Dispatcher { contract_address: registry.contract_address };

    assert!(
        src5.supports_interface(IMINIGAME_REGISTRY_ID),
        "Should support IMinigameRegistry interface",
    );
}

// ==============================================================================
// VIEW FUNCTION TESTS
// ==============================================================================

// Test REG-U-03: game_count returns correct value after registration
#[test]
fn test_game_count_increments_after_registration() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    // Mock the IMinigame interface support
    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Register the game
    start_cheat_caller_address(registry.contract_address, game_address);
    registry
        .register_game(
            CREATOR(),
            "Test Game",
            "A test game",
            "Test Dev",
            "Test Pub",
            "Puzzle",
            "game.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    assert!(registry.game_count() == 1, "Game count should be 1 after registration");
}

// Test REG-U-04: game_id_from_address returns correct ID
#[test]
fn test_game_id_from_address_returns_correct_id() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    let retrieved_id = registry.game_id_from_address(game_address);
    assert!(retrieved_id == game_id, "Retrieved ID should match registered ID");
    assert!(retrieved_id == 1, "First game ID should be 1");
}

// Test REG-U-05: game_address_from_id returns correct address
#[test]
fn test_game_address_from_id_returns_correct_address() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    let retrieved_address = registry.game_address_from_id(game_id);
    assert!(retrieved_address == game_address, "Retrieved address should match game address");
}

// Test REG-U-06: is_game_registered returns true for registered games
#[test]
fn test_is_game_registered_returns_true_for_registered() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    // Before registration
    assert!(!registry.is_game_registered(game_address), "Game should not be registered initially");

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    // After registration
    assert!(registry.is_game_registered(game_address), "Game should be registered after register");
}

// Test REG-U-07: is_game_registered returns false for unregistered games
#[test]
fn test_is_game_registered_returns_false_for_unregistered() {
    let registry = deploy_mock_registry();
    let random_address = addr(0x12345);

    assert!(
        !registry.is_game_registered(random_address), "Random address should not be registered",
    );
}

// Test REG-U-08: game_metadata returns correct metadata
#[test]
fn test_game_metadata_returns_correct_data() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "My Game",
            "A great game",
            "Awesome Dev",
            "Cool Publisher",
            "Action",
            "awesome.png",
            Option::Some("blue"),
            Option::Some("https://game.example.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    assert!(metadata.contract_address == game_address, "Contract address mismatch");
    assert!(metadata.name == "My Game", "Name mismatch");
    assert!(metadata.description == "A great game", "Description mismatch");
    assert!(metadata.developer == "Awesome Dev", "Developer mismatch");
    assert!(metadata.publisher == "Cool Publisher", "Publisher mismatch");
    assert!(metadata.genre == "Action", "Genre mismatch");
    assert!(metadata.image == "awesome.png", "Image mismatch");
    assert!(metadata.color == "blue", "Color mismatch");
    assert!(metadata.client_url == "https://game.example.com", "Client URL mismatch");
    assert!(metadata.renderer_address == RENDERER_ADDRESS(), "Renderer address mismatch");
}

// ==============================================================================
// REGISTRATION TESTS
// ==============================================================================

// Test REG-U-09: register_game with all optional fields as None
#[test]
fn test_register_game_with_none_optional_fields() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Minimal Game",
            "Minimal Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None, // color
            Option::None, // client_url
            Option::None, // renderer_address
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    // Verify optional fields are set to defaults
    assert!(metadata.color == "", "Color should be empty string");
    assert!(metadata.client_url == "", "Client URL should be empty string");
    assert!(metadata.renderer_address.is_zero(), "Renderer address should be zero");
}

// Test REG-U-10: register_game returns incremental IDs
#[test]
fn test_register_game_returns_incremental_ids() {
    let registry = deploy_mock_registry();

    // Register first game
    let game1_address = deploy_mock_minigame_for_registration();
    mock_call(game1_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game1_address);
    let game1_id = registry
        .register_game(
            CREATOR(),
            "Game 1",
            "Desc 1",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    // Register second game
    let game2_address = deploy_mock_minigame_for_registration();
    mock_call(game2_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game2_address);
    let game2_id = registry
        .register_game(
            CREATOR(),
            "Game 2",
            "Desc 2",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    assert!(game1_id == 1, "First game ID should be 1");
    assert!(game2_id == 2, "Second game ID should be 2");
    assert!(registry.game_count() == 2, "Game count should be 2");
}

// ==============================================================================
// FAILURE TESTS
// ==============================================================================

// Test REG-U-11: register_game fails for non-IMinigame contract
#[test]
#[should_panic]
fn test_register_game_fails_for_non_minigame() {
    let registry = deploy_mock_registry();

    // Use a contract that doesn't support IMinigame
    let non_minigame_address = addr(0x9999);

    // Mock to return false for supports_interface
    mock_call(non_minigame_address, selector!("supports_interface"), false, 10);

    start_cheat_caller_address(registry.contract_address, non_minigame_address);
    registry
        .register_game(
            CREATOR(),
            "Invalid Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);
}

// Test REG-U-12: register_game fails for already registered game
#[test]
#[should_panic]
fn test_register_game_fails_for_duplicate() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 20);

    start_cheat_caller_address(registry.contract_address, game_address);

    // First registration - should succeed
    registry
        .register_game(
            CREATOR(),
            "Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );

    // Second registration - should panic
    registry
        .register_game(
            CREATOR(),
            "Game Again",
            "Different Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );

    stop_cheat_caller_address(registry.contract_address);
}

// ==============================================================================
// EVENT TESTS
// ==============================================================================

// Test REG-U-13: register_game emits GameRegistryUpdate event
#[test]
fn test_register_game_emits_registry_update_event() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    let mut spy = spy_events();

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Event Test Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify GameRegistryUpdate event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    game_components_registry::component::MinigameRegistryComponent::Event::GameRegistryUpdate(
                        game_components_registry::component::MinigameRegistryComponent::GameRegistryUpdate {
                            id: game_id, contract_address: game_address,
                        },
                    ),
                ),
            ],
        );
}

// Test REG-U-14: register_game emits GameMetadataUpdate event
#[test]
fn test_register_game_emits_metadata_update_event() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    let mut spy = spy_events();

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Metadata Event Game",
            "Test Description",
            "Developer",
            "Publisher",
            "Action",
            "image.png",
            Option::Some("red"),
            Option::Some("https://example.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::Some(500) // 5% royalty
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify GameMetadataUpdate event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    game_components_registry::component::MinigameRegistryComponent::Event::GameMetadataUpdate(
                        game_components_registry::component::MinigameRegistryComponent::GameMetadataUpdate {
                            id: game_id,
                            contract_address: game_address,
                            name: "Metadata Event Game",
                            description: "Test Description",
                            developer: "Developer",
                            publisher: "Publisher",
                            genre: "Action",
                            image: "image.png",
                            color: "red",
                            client_url: "https://example.com",
                            renderer_address: RENDERER_ADDRESS(),
                            royalty_fraction: 500,
                        },
                    ),
                ),
            ],
        );
}

// ==============================================================================
// EDGE CASE TESTS
// ==============================================================================

// Test REG-U-15: game_id_from_address returns 0 for unregistered address
#[test]
fn test_game_id_from_address_returns_zero_for_unregistered() {
    let registry = deploy_mock_registry();
    let unregistered_address = addr(0xABCDEF);

    let game_id = registry.game_id_from_address(unregistered_address);
    assert!(game_id == 0, "Unregistered address should return game ID 0");
}

// Test REG-U-16: game_address_from_id returns zero for non-existent ID
#[test]
fn test_game_address_from_id_returns_zero_for_nonexistent() {
    let registry = deploy_mock_registry();

    let address = registry.game_address_from_id(999);
    assert!(address.is_zero(), "Non-existent ID should return zero address");
}

// Test REG-U-17: Multiple games can be registered with different metadata
#[test]
fn test_multiple_games_with_different_metadata() {
    let registry = deploy_mock_registry();

    // Game 1
    let game1_address = deploy_mock_minigame_for_registration();
    mock_call(game1_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game1_address);
    let game1_id = registry
        .register_game(
            CREATOR(),
            "Puzzle Master",
            "A puzzle game",
            "Puzzle Dev",
            "Puzzle Pub",
            "Puzzle",
            "puzzle.png",
            Option::Some("green"),
            Option::Some("https://puzzle.com"),
            Option::None,
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    // Game 2
    let game2_address = deploy_mock_minigame_for_registration();
    mock_call(game2_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game2_address);
    let game2_id = registry
        .register_game(
            USER1(),
            "Action Hero",
            "An action game",
            "Action Dev",
            "Action Pub",
            "Action",
            "action.png",
            Option::Some("red"),
            Option::Some("https://action.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::None // royalty_fraction
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify game 1 metadata
    let meta1 = registry.game_metadata(game1_id);
    assert!(meta1.name == "Puzzle Master", "Game 1 name mismatch");
    assert!(meta1.genre == "Puzzle", "Game 1 genre mismatch");
    assert!(meta1.color == "green", "Game 1 color mismatch");

    // Verify game 2 metadata
    let meta2 = registry.game_metadata(game2_id);
    assert!(meta2.name == "Action Hero", "Game 2 name mismatch");
    assert!(meta2.genre == "Action", "Game 2 genre mismatch");
    assert!(meta2.color == "red", "Game 2 color mismatch");
    assert!(meta2.renderer_address == RENDERER_ADDRESS(), "Game 2 renderer mismatch");

    // Verify both are registered
    assert!(registry.is_game_registered(game1_address), "Game 1 should be registered");
    assert!(registry.is_game_registered(game2_address), "Game 2 should be registered");
    assert!(registry.game_count() == 2, "Total game count should be 2");
}
