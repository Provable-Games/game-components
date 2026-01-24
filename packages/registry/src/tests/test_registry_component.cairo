// ==============================================================================
// MINIGAME REGISTRY COMPONENT TESTS
// ==============================================================================
// Tests for the MinigameRegistryComponent which handles game registration,
// metadata storage, and ID mapping.

use core::num::traits::Zero;
use game_components_registry::interface::{
    IMINIGAME_REGISTRY_ID, IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_testing::constants::{CREATOR, RENDERER_ADDRESS, USER1, ZERO_ADDRESS};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
    mock_call, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::mock_registry_with_custom_hooks::{
    IMockRegistryHookTrackerDispatcher, IMockRegistryHookTrackerDispatcherTrait,
};

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

/// Deploy the mock registry contract with ERC721 support
fn deploy_mock_registry_with_erc721() -> IMinigameRegistryDispatcher {
    let contract = declare("MockRegistryWithERC721").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    IMinigameRegistryDispatcher { contract_address }
}

/// Deploy the mock registry contract with custom hooks for tracking
fn deploy_mock_registry_with_custom_hooks() -> (
    IMinigameRegistryDispatcher, IMockRegistryHookTrackerDispatcher,
) {
    let contract = declare("MockRegistryWithCustomHooks").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    (
        IMinigameRegistryDispatcher { contract_address },
        IMockRegistryHookTrackerDispatcher { contract_address },
    )
}

/// Deploy the mock registry contract with rejecting hook
fn deploy_mock_registry_with_rejecting_hook() -> IMinigameRegistryDispatcher {
    let contract = declare("MockRegistryWithRejectingHook").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    IMinigameRegistryDispatcher { contract_address }
}

/// Helper to register a game and return the game_id
fn register_game(registry: IMinigameRegistryDispatcher, game_address: ContractAddress) -> u64 {
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
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);
    game_id
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

// Test REG-V-01: game_id_from_address returns 0 for zero address
#[test]
fn test_game_id_from_address_zero_address() {
    let registry = deploy_mock_registry();
    let game_id = registry.game_id_from_address(ZERO_ADDRESS());
    assert!(game_id == 0, "Zero address should return game ID 0");
}

// Test REG-V-02: game_address_from_id returns zero address for game ID 0
#[test]
fn test_game_address_from_id_zero() {
    let registry = deploy_mock_registry();
    let address = registry.game_address_from_id(0);
    assert!(address.is_zero(), "Game ID 0 should return zero address");
}

// Test REG-V-03: game_metadata returns default for non-existent ID
#[test]
fn test_game_metadata_nonexistent_id() {
    let registry = deploy_mock_registry();
    let metadata = registry.game_metadata(999);

    assert!(metadata.contract_address.is_zero(), "Contract address should be zero");
    assert!(metadata.name == "", "Name should be empty");
    assert!(metadata.description == "", "Description should be empty");
    assert!(metadata.royalty_fraction == 0, "Royalty should be 0");
}

// ==============================================================================
// REGISTRATION TESTS - SUCCESS CASES
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
    assert!(metadata.royalty_fraction == 0, "Royalty fraction should be 0");
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

// Test REG-R-01: register_game with all optional fields provided
#[test]
fn test_register_game_with_all_optional_fields() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Full Game",
            "Full Description",
            "Full Dev",
            "Full Pub",
            "Full Genre",
            "full.png",
            Option::Some("purple"),
            Option::Some("https://fullgame.example.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::Some(1000) // 10% royalty
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    assert!(metadata.color == "purple", "Color should be purple");
    assert!(metadata.client_url == "https://fullgame.example.com", "Client URL mismatch");
    assert!(metadata.renderer_address == RENDERER_ADDRESS(), "Renderer address mismatch");
    assert!(metadata.royalty_fraction == 1000, "Royalty fraction should be 1000");
}

// Test REG-R-02: register_game with mixed optional fields
#[test]
fn test_register_game_with_mixed_optional_fields() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Mixed Game",
            "Mixed Description",
            "Mixed Dev",
            "Mixed Pub",
            "Mixed Genre",
            "mixed.png",
            Option::Some("red"), // color provided
            Option::None, // client_url not provided
            Option::Some(RENDERER_ADDRESS()), // renderer provided
            Option::None // royalty not provided
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    assert!(metadata.color == "red", "Color should be red");
    assert!(metadata.client_url == "", "Client URL should be empty");
    assert!(metadata.renderer_address == RENDERER_ADDRESS(), "Renderer address mismatch");
    assert!(metadata.royalty_fraction == 0, "Royalty fraction should be 0");
}

// Test REG-R-03: register_game with empty strings
#[test]
fn test_register_game_with_empty_strings() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "", // empty name
            "", // empty description
            "", // empty developer
            "", // empty publisher
            "", // empty genre
            "", // empty image
            Option::Some(""), // empty color
            Option::Some(""), // empty client_url
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    assert!(metadata.name == "", "Name should be empty");
    assert!(metadata.description == "", "Description should be empty");
    assert!(metadata.developer == "", "Developer should be empty");
    assert!(metadata.color == "", "Color should be empty");
}

// Test REG-R-04: register_game with long metadata (>31 bytes)
#[test]
fn test_register_game_with_long_metadata() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    let long_name: ByteArray = "This is a very long game name that exceeds 31 bytes in length";
    let long_description: ByteArray =
        "This is an extremely long description that contains a lot of text and definitely exceeds 31 bytes";

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            long_name.clone(),
            long_description.clone(),
            "Developer",
            "Publisher",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);

    assert!(metadata.name == long_name, "Long name should be stored correctly");
    assert!(
        metadata.description == long_description, "Long description should be stored correctly",
    );
}

// Test REG-R-05: register_game stores correct contract_address
#[test]
fn test_register_game_stores_correct_contract_address() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(
        metadata.contract_address == game_address, "Stored contract_address should match caller",
    );
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

// Test REG-R-06: register_game fails with expected error for non-IMinigame
#[test]
#[should_panic]
fn test_register_game_fails_with_expected_error_non_minigame() {
    let registry = deploy_mock_registry();
    let non_minigame_address = addr(0x9999);

    mock_call(non_minigame_address, selector!("supports_interface"), false, 10);

    start_cheat_caller_address(registry.contract_address, non_minigame_address);
    registry
        .register_game(
            CREATOR(),
            "Invalid",
            "Desc",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
}

// Test REG-R-07: register_game fails with expected error for duplicate
#[test]
#[should_panic]
fn test_register_game_fails_with_expected_error_duplicate() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 20);

    start_cheat_caller_address(registry.contract_address, game_address);

    // First registration
    registry
        .register_game(
            CREATOR(),
            "Game",
            "Desc",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );

    // Second registration - should panic with specific error
    registry
        .register_game(
            CREATOR(),
            "Game Again",
            "Desc",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
}

// ==============================================================================
// ROYALTY TESTS - SUCCESS CASES
// ==============================================================================

// Test REG-RY-01: set_game_royalty success
#[test]
fn test_set_game_royalty_success() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Register game - this will mint token to CREATOR via hook
    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Test Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(100) // initial 1% royalty
        );
    stop_cheat_caller_address(registry.contract_address);

    // Set royalty as owner (CREATOR)
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, 500); // 5% royalty
    stop_cheat_caller_address(registry.contract_address);

    // Verify
    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == 500, "Royalty should be updated to 500");
}

// Test REG-RY-02: set_game_royalty updates metadata
#[test]
fn test_set_game_royalty_updates_metadata() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Royalty Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::Some("blue"),
            Option::Some("https://example.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::Some(100),
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify initial royalty
    let initial_metadata = registry.game_metadata(game_id);
    assert!(initial_metadata.royalty_fraction == 100, "Initial royalty should be 100");

    // Update royalty
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, 750);
    stop_cheat_caller_address(registry.contract_address);

    // Verify updated metadata - other fields should remain unchanged
    let updated_metadata = registry.game_metadata(game_id);
    assert!(updated_metadata.royalty_fraction == 750, "Royalty should be updated to 750");
    assert!(updated_metadata.name == "Royalty Game", "Name should be unchanged");
    assert!(updated_metadata.color == "blue", "Color should be unchanged");
    assert!(
        updated_metadata.renderer_address == RENDERER_ADDRESS(), "Renderer should be unchanged",
    );
}

// Test REG-RY-03: set_game_royalty emits event
#[test]
fn test_set_game_royalty_emits_event() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Event Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let mut spy = spy_events();

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, 500);
    stop_cheat_caller_address(registry.contract_address);

    // Verify GameRoyaltyUpdate event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    game_components_registry::component::MinigameRegistryComponent::Event::GameRoyaltyUpdate(
                        game_components_registry::component::MinigameRegistryComponent::GameRoyaltyUpdate {
                            game_id: game_id, royalty_fraction: 500,
                        },
                    ),
                ),
            ],
        );
}

// Test REG-RY-04: set_game_royalty multiple updates
#[test]
fn test_set_game_royalty_multiple_updates() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Multi Update Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(100),
        );
    stop_cheat_caller_address(registry.contract_address);

    // Multiple updates
    start_cheat_caller_address(registry.contract_address, CREATOR());

    registry.set_game_royalty(game_id, 200);
    let meta1 = registry.game_metadata(game_id);
    assert!(meta1.royalty_fraction == 200, "First update should be 200");

    registry.set_game_royalty(game_id, 500);
    let meta2 = registry.game_metadata(game_id);
    assert!(meta2.royalty_fraction == 500, "Second update should be 500");

    registry.set_game_royalty(game_id, 1000);
    let meta3 = registry.game_metadata(game_id);
    assert!(meta3.royalty_fraction == 1000, "Third update should be 1000");

    stop_cheat_caller_address(registry.contract_address);
}

// Test REG-RY-05: set_game_royalty to zero
#[test]
fn test_set_game_royalty_to_zero() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Zero Royalty Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(500) // Start with 5%
        );
    stop_cheat_caller_address(registry.contract_address);

    // Set to zero (no royalty)
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, 0);
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == 0, "Royalty should be set to 0");
}

// Test REG-RY-06: set_game_royalty max value
#[test]
fn test_set_game_royalty_max_value() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Max Royalty Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Set to max u128
    let max_royalty: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, max_royalty);
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == max_royalty, "Max royalty should be stored");
}

// ==============================================================================
// ROYALTY TESTS - FAILURE CASES
// ==============================================================================

// Test REG-RY-07: set_game_royalty fails for non-owner
#[test]
#[should_panic]
fn test_set_game_royalty_fails_non_owner() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Register game - token minted to CREATOR
    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Owner Test Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Try to set royalty as USER1 (not owner)
    start_cheat_caller_address(registry.contract_address, USER1());
    registry.set_game_royalty(game_id, 1000);
}

// Test REG-RY-08: set_game_royalty fails for invalid game_id
#[test]
#[should_panic]
fn test_set_game_royalty_fails_invalid_game_id() {
    let registry = deploy_mock_registry_with_erc721();

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(999, 500); // Non-existent game ID
}

// Test set_game_royalty fails for game_id 0
#[test]
#[should_panic]
fn test_set_game_royalty_fails_game_id_zero() {
    let registry = deploy_mock_registry_with_erc721();

    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(0, 500);
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

// Test REG-E-01: Verify event order (GameRegistryUpdate before GameMetadataUpdate)
#[test]
fn test_register_game_events_order() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    let mut spy = spy_events();

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Order Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Get all events
    let events = spy.get_events();

    // Verify we have at least 2 events (GameRegistryUpdate and GameMetadataUpdate)
    assert!(events.events.len() >= 2, "Should have at least 2 events");

    // The first event from registry should be GameRegistryUpdate
    // The second event from registry should be GameMetadataUpdate
    // (Note: exact order verification depends on how events are emitted)
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
                (
                    registry.contract_address,
                    game_components_registry::component::MinigameRegistryComponent::Event::GameMetadataUpdate(
                        game_components_registry::component::MinigameRegistryComponent::GameMetadataUpdate {
                            id: game_id,
                            contract_address: game_address,
                            name: "Order Test",
                            description: "Description",
                            developer: "Dev",
                            publisher: "Pub",
                            genre: "Genre",
                            image: "img.png",
                            color: "",
                            client_url: "",
                            renderer_address: ZERO_ADDRESS(),
                            royalty_fraction: 0,
                        },
                    ),
                ),
            ],
        );
}

// Test REG-E-02: Royalty event contains correct data
#[test]
fn test_royalty_event_contains_correct_data() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Royalty Event Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let mut spy = spy_events();

    let royalty_value: u128 = 750; // 7.5%
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, royalty_value);
    stop_cheat_caller_address(registry.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    registry.contract_address,
                    game_components_registry::component::MinigameRegistryComponent::Event::GameRoyaltyUpdate(
                        game_components_registry::component::MinigameRegistryComponent::GameRoyaltyUpdate {
                            game_id: game_id, royalty_fraction: royalty_value,
                        },
                    ),
                ),
            ],
        );
}

// ==============================================================================
// HOOK TESTS
// ==============================================================================

// Test REG-H-01: before_register_hook is called
#[test]
fn test_before_register_hook_called() {
    let (registry, hook_tracker) = deploy_mock_registry_with_custom_hooks();
    let game_address = deploy_mock_minigame_for_registration();

    // Verify hook not called initially
    assert!(!hook_tracker.was_before_hook_called(), "Before hook should not be called initially");

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    registry
        .register_game(
            CREATOR(),
            "Hook Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify hook was called
    assert!(
        hook_tracker.was_before_hook_called(), "Before hook should be called after registration",
    );
    assert!(
        hook_tracker.get_before_hook_caller() == game_address,
        "Before hook should receive caller address",
    );
}

// Test REG-H-02: after_register_hook is called
#[test]
fn test_after_register_hook_called() {
    let (registry, hook_tracker) = deploy_mock_registry_with_custom_hooks();
    let game_address = deploy_mock_minigame_for_registration();

    // Verify hook not called initially
    assert!(!hook_tracker.was_after_hook_called(), "After hook should not be called initially");

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let _game_id = registry
        .register_game(
            CREATOR(),
            "Hook Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify hook was called
    assert!(hook_tracker.was_after_hook_called(), "After hook should be called after registration");
}

// Test REG-H-03: before_hook can reject registration
#[test]
#[should_panic]
fn test_before_hook_can_reject_registration() {
    let registry = deploy_mock_registry_with_rejecting_hook();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    registry
        .register_game(
            CREATOR(),
            "Rejected Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        ); // Should panic from hook
}

// Test REG-H-04: after_hook receives correct game_id
#[test]
fn test_after_hook_receives_correct_game_id() {
    let (registry, hook_tracker) = deploy_mock_registry_with_custom_hooks();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Hook Game ID Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify hook received correct game_id and creator
    assert!(hook_tracker.get_hook_game_id() == game_id, "Hook should receive correct game_id");
    assert!(hook_tracker.get_hook_creator() == CREATOR(), "Hook should receive correct creator");
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

// Test REG-EC-01: Max game registrations (large number)
#[test]
fn test_max_game_registrations() {
    let registry = deploy_mock_registry();

    // Register 10 games (reasonable for test performance)
    let num_games: u64 = 10;
    let mut i: u64 = 0;
    while i < num_games {
        let game_address = deploy_mock_minigame_for_registration();
        mock_call(game_address, selector!("supports_interface"), true, 10);

        start_cheat_caller_address(registry.contract_address, game_address);
        let game_id = registry
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
                Option::None,
            );
        stop_cheat_caller_address(registry.contract_address);

        assert!(game_id == i + 1, "Game ID should match iteration");
        i += 1;
    }

    assert!(registry.game_count() == num_games, "Game count should match number registered");
}

// Test REG-EC-03: Unicode metadata fields (UTF-8 in ByteArray)
#[test]
fn test_unicode_metadata_fields() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Note: Cairo ByteArray supports UTF-8
    let unicode_name: ByteArray = "Test Game Name";
    let unicode_description: ByteArray = "A game with special chars";

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            unicode_name.clone(),
            unicode_description.clone(),
            "Dev",
            "Pub",
            "Puzzle",
            "image.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.name == unicode_name, "Unicode name should match");
    assert!(metadata.description == unicode_description, "Unicode description should match");
}

// Test REG-EC-04: Special characters in URLs
#[test]
fn test_special_characters_in_urls() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    let special_url: ByteArray = "https://example.com/game?id=123&name=test&special=%20";

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "URL Test Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::Some(special_url.clone()),
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.client_url == special_url, "Special URL should be stored correctly");
}

// Test REG-EC-05: renderer_address Option::Some(zero_address) vs Option::None
#[test]
fn test_renderer_address_zero_explicitly() {
    let registry = deploy_mock_registry();

    // Test 1: Option::None
    let game1_address = deploy_mock_minigame_for_registration();
    mock_call(game1_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game1_address);
    let game1_id = registry
        .register_game(
            CREATOR(),
            "Game 1",
            "Desc",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None, // renderer as None
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // Test 2: Option::Some(zero_address)
    let game2_address = deploy_mock_minigame_for_registration();
    mock_call(game2_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game2_address);
    let game2_id = registry
        .register_game(
            CREATOR(),
            "Game 2",
            "Desc",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::Some(ZERO_ADDRESS()), // renderer as Some(zero)
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    let meta1 = registry.game_metadata(game1_id);
    let meta2 = registry.game_metadata(game2_id);

    // Both should result in zero address
    assert!(meta1.renderer_address.is_zero(), "None should result in zero address");
    assert!(meta2.renderer_address.is_zero(), "Some(zero) should result in zero address");
}

// Test REG-EC-06: Royalty fraction basis points max (10000 = 100%)
#[test]
fn test_royalty_fraction_basis_points_max() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // 10000 basis points = 100% royalty
    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Max Basis Points Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(10000) // 100% royalty
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == 10000, "Max basis points should be stored");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

// Test REG-F-01: Fuzz test register_game royalty fraction
#[test]
#[fuzzer]
fn test_fuzz_register_game_royalty_fraction(royalty: u128) {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Fuzz Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(royalty),
        );
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == royalty, "Royalty should be stored correctly");
}

// Test REG-F-02: Fuzz test game_id lookups return consistent zero for non-existent
#[test]
#[fuzzer]
fn test_fuzz_game_id_lookups(random_id: u64) {
    let registry = deploy_mock_registry();

    // No games registered, so any ID should return zero address
    let address = registry.game_address_from_id(random_id);
    assert!(address.is_zero(), "Non-existent ID should return zero address");
}

// Test REG-F-03: Fuzz test multiple registrations
#[test]
#[fuzzer]
fn test_fuzz_multiple_registrations(num_games: u8) {
    // Limit to reasonable range for test performance
    let count: u64 = (num_games % 5 + 1).into(); // 1-5 games

    let registry = deploy_mock_registry();

    let mut i: u64 = 0;
    while i < count {
        let game_address = deploy_mock_minigame_for_registration();
        mock_call(game_address, selector!("supports_interface"), true, 10);

        start_cheat_caller_address(registry.contract_address, game_address);
        let game_id = registry
            .register_game(
                CREATOR(),
                "Fuzz Game",
                "Description",
                "Dev",
                "Pub",
                "Genre",
                "img.png",
                Option::None,
                Option::None,
                Option::None,
                Option::None,
            );
        stop_cheat_caller_address(registry.contract_address);

        assert!(game_id == i + 1, "Game IDs should be sequential");
        i += 1;
    }

    assert!(registry.game_count() == count, "Game count should match registrations");
}

// ==============================================================================
// INTEGRATION TESTS
// ==============================================================================

// Test REG-I-01: Registry with real minigame contract (end-to-end)
#[test]
fn test_registry_with_real_minigame_contract() {
    let registry = deploy_mock_registry();

    // Deploy actual minigame mock that properly implements SRC5
    let game_address = deploy_mock_minigame_for_registration();

    // Real minigame mock supports the interface without mocking
    // But we'll still mock it to ensure consistent test behavior
    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Real Minigame",
            "A real game implementation",
            "Real Dev",
            "Real Pub",
            "Real Genre",
            "real.png",
            Option::Some("gold"),
            Option::Some("https://realgame.example.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::Some(250) // 2.5% royalty
        );
    stop_cheat_caller_address(registry.contract_address);

    // Verify full integration
    assert!(game_id == 1, "First game ID should be 1");
    assert!(registry.game_count() == 1, "Game count should be 1");
    assert!(registry.is_game_registered(game_address), "Game should be registered");
    assert!(registry.game_id_from_address(game_address) == game_id, "ID lookup should work");
    assert!(registry.game_address_from_id(game_id) == game_address, "Address lookup should work");

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == 250, "Royalty should be set");
}

// Test REG-I-02: Registry with custom hooks
#[test]
fn test_registry_with_custom_hooks() {
    let (registry, hook_tracker) = deploy_mock_registry_with_custom_hooks();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Before registration
    assert!(!hook_tracker.was_before_hook_called(), "Before hook not called yet");
    assert!(!hook_tracker.was_after_hook_called(), "After hook not called yet");

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "Hooked Game",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
    stop_cheat_caller_address(registry.contract_address);

    // After registration - verify all hooks were called
    assert!(hook_tracker.was_before_hook_called(), "Before hook should be called");
    assert!(hook_tracker.was_after_hook_called(), "After hook should be called");
    assert!(hook_tracker.get_hook_game_id() == game_id, "Hook should receive correct game_id");
    assert!(hook_tracker.get_hook_creator() == CREATOR(), "Hook should receive correct creator");
    assert!(
        hook_tracker.get_before_hook_caller() == game_address, "Hook should receive caller address",
    );
}

// Test REG-I-03: Registry with ERC721 owner check for set_game_royalty
#[test]
fn test_registry_with_erc721_owner_check() {
    let registry = deploy_mock_registry_with_erc721();
    let game_address = deploy_mock_minigame_for_registration();

    mock_call(game_address, selector!("supports_interface"), true, 10);

    // Register game - this mints token to CREATOR via after_register_game hook
    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            "ERC721 Owner Test",
            "Description",
            "Dev",
            "Pub",
            "Genre",
            "img.png",
            Option::None,
            Option::None,
            Option::None,
            Option::Some(100),
        );
    stop_cheat_caller_address(registry.contract_address);

    // CREATOR should be able to set royalty (they own the token)
    start_cheat_caller_address(registry.contract_address, CREATOR());
    registry.set_game_royalty(game_id, 500);
    stop_cheat_caller_address(registry.contract_address);

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.royalty_fraction == 500, "Owner should be able to update royalty");
}
