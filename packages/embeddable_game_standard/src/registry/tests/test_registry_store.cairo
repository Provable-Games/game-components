// ==============================================================================
// REGISTRY STORE & PURE LIBRARY TESTS
// ==============================================================================
// Tests targeting coverage for:
//   - registry.cairo: apply_metadata_defaults pure function and Errors constants
//   - registry_store.cairo: RegistryStoreImpl (is_game_registered, batch, paginated)
//   - registry_component.cairo: ComponentStore impl and embeddable delegations
//
// These tests complement test_registry_component.cairo and test_batch_views.cairo
// by explicitly exercising the extracted store bridge layer and pure library code.

use core::num::traits::Zero;
use game_components_embeddable_game_standard::registry::interface::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_embeddable_game_standard::registry::registry::registry::{
    Errors, apply_metadata_defaults,
};
use game_components_testing::constants::{CREATOR, RENDERER_ADDRESS, ZERO_ADDRESS};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, mock_call, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;

// ==============================================================================
// HELPER FUNCTIONS
// ==============================================================================

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn deploy_mock_registry() -> IMinigameRegistryDispatcher {
    let contract = declare("MockRegistryContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    IMinigameRegistryDispatcher { contract_address }
}

fn deploy_mock_minigame_for_registration() -> ContractAddress {
    let contract = declare("registry_minigame_mock").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

/// Register a game with full metadata control, including optional fields.
fn register_game_full(
    registry: IMinigameRegistryDispatcher,
    game_address: ContractAddress,
    name: ByteArray,
    developer: ByteArray,
    publisher: ByteArray,
    genre: ByteArray,
    color: Option<ByteArray>,
    client_url: Option<ByteArray>,
    renderer_address: Option<ContractAddress>,
    royalty_fraction: Option<u128>,
) -> u64 {
    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            name,
            "Description",
            developer,
            publisher,
            genre,
            "Image",
            color,
            client_url,
            renderer_address,
            royalty_fraction,
        );
    stop_cheat_caller_address(registry.contract_address);
    game_id
}

/// Convenience: register with metadata fields and all-None optional fields.
fn register_game_with_metadata(
    registry: IMinigameRegistryDispatcher,
    game_address: ContractAddress,
    name: ByteArray,
    developer: ByteArray,
    publisher: ByteArray,
    genre: ByteArray,
) -> u64 {
    register_game_full(
        registry,
        game_address,
        name,
        developer,
        publisher,
        genre,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    )
}

// ==============================================================================
// PURE LIBRARY TESTS: apply_metadata_defaults
// ==============================================================================

#[test]
fn test_apply_metadata_defaults_all_some() {
    let renderer: ContractAddress = RENDERER_ADDRESS();
    let (color, client_url, renderer_addr, royalty) = apply_metadata_defaults(
        Option::Some("blue"),
        Option::Some("https://example.com"),
        Option::Some(renderer),
        Option::Some(500),
    );

    assert!(color == "blue", "Color should be 'blue'");
    assert!(client_url == "https://example.com", "Client URL should match");
    assert!(renderer_addr == renderer, "Renderer address should match");
    assert!(royalty == 500, "Royalty should be 500");
}

#[test]
fn test_apply_metadata_defaults_all_none() {
    let (color, client_url, renderer_addr, royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::None, Option::None,
    );

    assert!(color == "", "Color should default to empty string");
    assert!(client_url == "", "Client URL should default to empty string");
    assert!(renderer_addr.is_zero(), "Renderer address should default to zero");
    assert!(royalty == 0, "Royalty should default to 0");
}

#[test]
fn test_apply_metadata_defaults_mixed_color_some_rest_none() {
    let (color, client_url, renderer_addr, royalty) = apply_metadata_defaults(
        Option::Some("red"), Option::None, Option::None, Option::None,
    );

    assert!(color == "red", "Color should be 'red'");
    assert!(client_url == "", "Client URL should default to empty string");
    assert!(renderer_addr.is_zero(), "Renderer address should default to zero");
    assert!(royalty == 0, "Royalty should default to 0");
}

#[test]
fn test_apply_metadata_defaults_mixed_url_and_royalty_some() {
    let (color, client_url, renderer_addr, royalty) = apply_metadata_defaults(
        Option::None, Option::Some("https://game.io"), Option::None, Option::Some(1000),
    );

    assert!(color == "", "Color should default to empty string");
    assert!(client_url == "https://game.io", "Client URL should match");
    assert!(renderer_addr.is_zero(), "Renderer address should default to zero");
    assert!(royalty == 1000, "Royalty should be 1000");
}

#[test]
fn test_apply_metadata_defaults_mixed_renderer_some_rest_none() {
    let renderer: ContractAddress = addr(0xABC);
    let (color, client_url, renderer_addr, royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::Some(renderer), Option::None,
    );

    assert!(color == "", "Color should default to empty string");
    assert!(client_url == "", "Client URL should default to empty string");
    assert!(renderer_addr == renderer, "Renderer address should match provided");
    assert!(royalty == 0, "Royalty should default to 0");
}

#[test]
fn test_apply_metadata_defaults_empty_string_for_color() {
    let (color, _client_url, _renderer_addr, _royalty) = apply_metadata_defaults(
        Option::Some(""), Option::None, Option::None, Option::None,
    );

    assert!(color == "", "Explicit empty string should remain empty");
}

#[test]
fn test_apply_metadata_defaults_empty_string_for_client_url() {
    let (_color, client_url, _renderer_addr, _royalty) = apply_metadata_defaults(
        Option::None, Option::Some(""), Option::None, Option::None,
    );

    assert!(client_url == "", "Explicit empty client_url should remain empty");
}

#[test]
fn test_apply_metadata_defaults_zero_renderer_address() {
    let (_color, _client_url, renderer_addr, _royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::Some(ZERO_ADDRESS()), Option::None,
    );

    assert!(renderer_addr.is_zero(), "Explicit zero address should be zero");
}

#[test]
fn test_apply_metadata_defaults_zero_royalty_explicit() {
    let (_color, _client_url, _renderer_addr, royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::None, Option::Some(0),
    );

    assert!(royalty == 0, "Explicit zero royalty should be 0");
}

#[test]
fn test_apply_metadata_defaults_max_royalty() {
    let max: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
    let (_color, _client_url, _renderer_addr, royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::None, Option::Some(max),
    );

    assert!(royalty == max, "Max u128 royalty should be stored");
}

#[test]
fn test_apply_metadata_defaults_long_strings() {
    let long_color: ByteArray = "a very long color name that definitely exceeds 31 bytes boundary";
    let long_url: ByteArray =
        "https://example.com/very/long/path/that/exceeds/31/bytes/and/keeps/going?param=value";
    let (color, client_url, _renderer_addr, _royalty) = apply_metadata_defaults(
        Option::Some(long_color.clone()),
        Option::Some(long_url.clone()),
        Option::None,
        Option::None,
    );

    assert!(color == long_color, "Long color string should be preserved");
    assert!(client_url == long_url, "Long client_url string should be preserved");
}

// ==============================================================================
// ERROR CONSTANTS TESTS
// ==============================================================================

#[test]
fn test_error_constants_are_non_zero() {
    assert!(Errors::CALLER_NOT_MINIGAME != 0, "CALLER_NOT_MINIGAME should be non-zero");
    assert!(Errors::GAME_ALREADY_REGISTERED != 0, "GAME_ALREADY_REGISTERED should be non-zero");
    assert!(Errors::NOT_GAME_OWNER != 0, "NOT_GAME_OWNER should be non-zero");
    assert!(Errors::INVALID_GAME_ID != 0, "INVALID_GAME_ID should be non-zero");
    assert!(Errors::GAME_IDS_EMPTY != 0, "GAME_IDS_EMPTY should be non-zero");
    assert!(Errors::ADDRESSES_EMPTY != 0, "ADDRESSES_EMPTY should be non-zero");
}

#[test]
fn test_error_constants_are_distinct() {
    assert!(
        Errors::CALLER_NOT_MINIGAME != Errors::GAME_ALREADY_REGISTERED,
        "CALLER_NOT_MINIGAME should differ from GAME_ALREADY_REGISTERED",
    );
    assert!(
        Errors::CALLER_NOT_MINIGAME != Errors::NOT_GAME_OWNER,
        "CALLER_NOT_MINIGAME should differ from NOT_GAME_OWNER",
    );
    assert!(
        Errors::CALLER_NOT_MINIGAME != Errors::INVALID_GAME_ID,
        "CALLER_NOT_MINIGAME should differ from INVALID_GAME_ID",
    );
    assert!(
        Errors::GAME_IDS_EMPTY != Errors::ADDRESSES_EMPTY,
        "GAME_IDS_EMPTY should differ from ADDRESSES_EMPTY",
    );
}

// ==============================================================================
// REGISTER_GAME WITH OPTIONAL PARAMS (exercises apply_metadata_defaults via
// the component path: registry_component -> apply_metadata_defaults -> store)
// ==============================================================================

#[test]
fn test_register_game_all_some_optional_params() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let renderer = RENDERER_ADDRESS();
    let game_id = register_game_full(
        registry,
        game_address,
        "Full Options Game",
        "DevCo",
        "PubCo",
        "RPG",
        Option::Some("gold"),
        Option::Some("https://mygame.example.com"),
        Option::Some(renderer),
        Option::Some(750),
    );

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.color == "gold", "Color should be 'gold'");
    assert!(metadata.client_url == "https://mygame.example.com", "Client URL should match");
    assert!(metadata.renderer_address == renderer, "Renderer address should match");
    assert!(metadata.royalty_fraction == 750, "Royalty should be 750");
    assert!(metadata.developer == "DevCo", "Developer should match");
    assert!(metadata.publisher == "PubCo", "Publisher should match");
    assert!(metadata.genre == "RPG", "Genre should match");
}

#[test]
fn test_register_game_all_none_optional_params() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_full(
        registry,
        game_address,
        "Minimal Game",
        "Dev",
        "Pub",
        "Action",
        Option::None,
        Option::None,
        Option::None,
        Option::None,
    );

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.color == "", "Color should default to empty");
    assert!(metadata.client_url == "", "Client URL should default to empty");
    assert!(metadata.renderer_address.is_zero(), "Renderer should default to zero");
    assert!(metadata.royalty_fraction == 0, "Royalty should default to 0");
}

#[test]
fn test_register_game_mixed_color_and_renderer_some() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();
    let renderer = RENDERER_ADDRESS();

    let game_id = register_game_full(
        registry,
        game_address,
        "Partial Game",
        "Dev",
        "Pub",
        "Puzzle",
        Option::Some("cyan"),
        Option::None,
        Option::Some(renderer),
        Option::None,
    );

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.color == "cyan", "Color should be 'cyan'");
    assert!(metadata.client_url == "", "Client URL should default to empty");
    assert!(metadata.renderer_address == renderer, "Renderer should match");
    assert!(metadata.royalty_fraction == 0, "Royalty should default to 0");
}

#[test]
fn test_register_game_mixed_url_and_royalty_some() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_full(
        registry,
        game_address,
        "Mixed Game 2",
        "Dev",
        "Pub",
        "Strategy",
        Option::None,
        Option::Some("https://strategy.io"),
        Option::None,
        Option::Some(250),
    );

    let metadata = registry.game_metadata(game_id);
    assert!(metadata.color == "", "Color should default to empty");
    assert!(metadata.client_url == "https://strategy.io", "Client URL should match");
    assert!(metadata.renderer_address.is_zero(), "Renderer should default to zero");
    assert!(metadata.royalty_fraction == 250, "Royalty should be 250");
}

// ==============================================================================
// STORE BRIDGE: is_game_registered
// ==============================================================================

#[test]
fn test_is_game_registered_via_store_bridge() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    // Before registration
    assert!(!registry.is_game_registered(game_address), "Should not be registered initially");
    assert!(!registry.is_game_registered(ZERO_ADDRESS()), "Zero address should not be registered");
    assert!(!registry.is_game_registered(addr(0xDEAD)), "Random address should not be registered");

    // Register
    register_game_with_metadata(registry, game_address, "Game", "Dev", "Pub", "Genre");

    // After registration
    assert!(registry.is_game_registered(game_address), "Should be registered after register_game");
    assert!(
        !registry.is_game_registered(addr(0xDEAD)),
        "Unrelated address should still not be registered",
    );
}

// ==============================================================================
// STORE BRIDGE: game_metadata_batch
// ==============================================================================

#[test]
fn test_game_metadata_batch_single_with_optional_fields() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_full(
        registry,
        game_address,
        "Batch Game",
        "BatchDev",
        "BatchPub",
        "Adventure",
        Option::Some("green"),
        Option::Some("https://batch.io"),
        Option::Some(RENDERER_ADDRESS()),
        Option::Some(300),
    );

    let game_ids: Array<u64> = array![game_id];
    let results = registry.game_metadata_batch(game_ids.span());

    assert!(results.len() == 1, "Should return one result");
    let meta = results.at(0);
    assert!(meta.color == @"green", "Color should match");
    assert!(meta.client_url == @"https://batch.io", "Client URL should match");
    assert!(meta.renderer_address == @RENDERER_ADDRESS(), "Renderer should match");
    assert!(meta.royalty_fraction == @300, "Royalty should match");
}

#[test]
#[should_panic]
fn test_game_metadata_batch_empty_panics_with_error() {
    let registry = deploy_mock_registry();
    let game_ids: Array<u64> = array![];
    registry.game_metadata_batch(game_ids.span());
}

// ==============================================================================
// STORE BRIDGE: games_registered_batch
// ==============================================================================

#[test]
fn test_games_registered_batch_all_registered() {
    let registry = deploy_mock_registry();

    let game1 = deploy_mock_minigame_for_registration();
    let game2 = deploy_mock_minigame_for_registration();
    let game3 = deploy_mock_minigame_for_registration();

    register_game_with_metadata(registry, game1, "G1", "Dev", "Pub", "Action");
    register_game_with_metadata(registry, game2, "G2", "Dev", "Pub", "Action");
    register_game_with_metadata(registry, game3, "G3", "Dev", "Pub", "Action");

    let addresses: Array<ContractAddress> = array![game1, game2, game3];
    let results = registry.games_registered_batch(addresses.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(*results.at(0), "Game 1 should be registered");
    assert!(*results.at(1), "Game 2 should be registered");
    assert!(*results.at(2), "Game 3 should be registered");
}

#[test]
fn test_games_registered_batch_none_registered() {
    let registry = deploy_mock_registry();

    let addresses: Array<ContractAddress> = array![addr(0x111), addr(0x222), addr(0x333)];
    let results = registry.games_registered_batch(addresses.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(!*results.at(0), "Address 1 should not be registered");
    assert!(!*results.at(1), "Address 2 should not be registered");
    assert!(!*results.at(2), "Address 3 should not be registered");
}

#[test]
#[should_panic]
fn test_games_registered_batch_empty_panics_with_error() {
    let registry = deploy_mock_registry();
    let addresses: Array<ContractAddress> = array![];
    registry.games_registered_batch(addresses.span());
}

// ==============================================================================
// STORE BRIDGE: get_games pagination edge cases
// ==============================================================================

#[test]
fn test_get_games_count_zero_with_registered_games() {
    let registry = deploy_mock_registry();

    let game1 = deploy_mock_minigame_for_registration();
    let game2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1, "G1", "Dev", "Pub", "Action");
    register_game_with_metadata(registry, game2, "G2", "Dev", "Pub", "Action");

    let results = registry.get_games(1, 0);
    assert!(results.len() == 0, "Count 0 should return empty even with registered games");
}

#[test]
fn test_get_games_start_zero_returns_empty() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "Pub", "Action");

    let results = registry.get_games(0, 10);
    assert!(results.len() == 0, "Start 0 should return empty (1-indexed)");
}

#[test]
fn test_get_games_start_exceeds_count_returns_empty() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "Pub", "Action");

    let results = registry.get_games(5, 10);
    assert!(results.len() == 0, "Start beyond count should return empty");
}

#[test]
fn test_get_games_partial_last_page() {
    let registry = deploy_mock_registry();

    // Register 3 games
    let mut i: u32 = 0;
    loop {
        if i >= 3 {
            break;
        }
        let game = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game, "Game", "Dev", "Pub", "Genre");
        i += 1;
    }

    // Start at 2, request 5 -- should get 2 games (IDs 2 and 3)
    let results = registry.get_games(2, 5);
    assert!(results.len() == 2, "Should return only 2 games from position 2");
}

#[test]
fn test_get_games_exact_boundaries() {
    let registry = deploy_mock_registry();

    // Register 3 games
    let game1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1, "First", "Dev", "Pub", "Genre");
    let game2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2, "Second", "Dev", "Pub", "Genre");
    let game3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3, "Third", "Dev", "Pub", "Genre");

    // Exactly the last element
    let results = registry.get_games(3, 1);
    assert!(results.len() == 1, "Should return exactly one game");
    assert!(results.at(0).name == @"Third", "Should be the third game");

    // One past the end
    let results_empty = registry.get_games(4, 1);
    assert!(results_empty.len() == 0, "Start at 4 with 3 games should return empty");
}

// ==============================================================================
// STORE BRIDGE: get_games_by_developer pagination edge cases
// ==============================================================================

#[test]
fn test_get_games_by_developer_skip_exceeds_matches() {
    let registry = deploy_mock_registry();

    // Register 3 games, 2 from "DevA"
    let game1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1, "G1", "DevA", "Pub", "Action");
    let game2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2, "G2", "DevB", "Pub", "Puzzle");
    let game3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3, "G3", "DevA", "Pub", "RPG");

    // Skip 10 -- more than the 2 matching games
    let results = registry.get_games_by_developer("DevA", 10, 5);
    assert!(results.len() == 0, "Skip exceeding matches should return empty");
}

#[test]
fn test_get_games_by_developer_count_zero() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "DevA", "Pub", "Action");

    let results = registry.get_games_by_developer("DevA", 0, 0);
    assert!(results.len() == 0, "Count 0 should return empty");
}

#[test]
fn test_get_games_by_developer_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_developer("AnyDev", 0, 10);
    assert!(results.len() == 0, "Empty registry should return empty");
}

#[test]
fn test_get_games_by_developer_skip_partial() {
    let registry = deploy_mock_registry();

    // Register 4 games from "DevA"
    let mut i: u32 = 0;
    loop {
        if i >= 4 {
            break;
        }
        let game = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game, "Game", "DevA", "Pub", "Genre");
        i += 1;
    }

    // Skip 3, request 5 -- only 1 remaining match
    let results = registry.get_games_by_developer("DevA", 3, 5);
    assert!(results.len() == 1, "Should return 1 remaining match after skipping 3");
}

// ==============================================================================
// STORE BRIDGE: get_games_by_publisher pagination edge cases
// ==============================================================================

#[test]
fn test_get_games_by_publisher_count_zero() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "PubA", "Action");

    let results = registry.get_games_by_publisher("PubA", 0, 0);
    assert!(results.len() == 0, "Count 0 should return empty");
}

#[test]
fn test_get_games_by_publisher_skip_exceeds_matches() {
    let registry = deploy_mock_registry();

    let game1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1, "G1", "Dev", "PubA", "Action");
    let game2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2, "G2", "Dev", "PubB", "Puzzle");
    let game3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3, "G3", "Dev", "PubA", "RPG");

    // Skip 10 -- more than the 2 matching games
    let results = registry.get_games_by_publisher("PubA", 10, 5);
    assert!(results.len() == 0, "Skip exceeding matches should return empty");
}

#[test]
fn test_get_games_by_publisher_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_publisher("AnyPub", 0, 10);
    assert!(results.len() == 0, "Empty registry should return empty");
}

#[test]
fn test_get_games_by_publisher_skip_partial() {
    let registry = deploy_mock_registry();

    // Register 5 games from "PubA"
    let mut i: u32 = 0;
    loop {
        if i >= 5 {
            break;
        }
        let game = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game, "Game", "Dev", "PubA", "Genre");
        i += 1;
    }

    // Skip 4, request 10 -- only 1 remaining match
    let results = registry.get_games_by_publisher("PubA", 4, 10);
    assert!(results.len() == 1, "Should return 1 remaining match after skipping 4");
}

#[test]
fn test_get_games_by_publisher_no_matches() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "PubA", "Action");

    let results = registry.get_games_by_publisher("NonExistentPub", 0, 10);
    assert!(results.len() == 0, "Non-matching publisher should return empty");
}

// ==============================================================================
// STORE BRIDGE: get_games_by_genre pagination edge cases
// ==============================================================================

#[test]
fn test_get_games_by_genre_count_zero() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "Pub", "Action");

    let results = registry.get_games_by_genre("Action", 0, 0);
    assert!(results.len() == 0, "Count 0 should return empty");
}

#[test]
fn test_get_games_by_genre_skip_exceeds_matches() {
    let registry = deploy_mock_registry();

    let game1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1, "G1", "Dev", "Pub", "Action");
    let game2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2, "G2", "Dev", "Pub", "Puzzle");
    let game3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3, "G3", "Dev", "Pub", "Action");

    // Skip 10 -- more than the 2 matching games
    let results = registry.get_games_by_genre("Action", 10, 5);
    assert!(results.len() == 0, "Skip exceeding matches should return empty");
}

#[test]
fn test_get_games_by_genre_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_genre("AnyGenre", 0, 10);
    assert!(results.len() == 0, "Empty registry should return empty");
}

#[test]
fn test_get_games_by_genre_skip_partial() {
    let registry = deploy_mock_registry();

    // Register 6 Action games interspersed with other genres
    let mut i: u32 = 0;
    loop {
        if i >= 6 {
            break;
        }
        let game = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game, "Action Game", "Dev", "Pub", "Action");

        // Register a non-matching game in between
        let other = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, other, "Other", "Dev", "Pub", "Puzzle");

        i += 1;
    }

    // Skip 5, request 10 -- only 1 remaining Action match
    let results = registry.get_games_by_genre("Action", 5, 10);
    assert!(results.len() == 1, "Should return 1 remaining match after skipping 5");
}

#[test]
fn test_get_games_by_genre_no_matches() {
    let registry = deploy_mock_registry();

    let game = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game, "G1", "Dev", "Pub", "Action");

    let results = registry.get_games_by_genre("Horror", 0, 10);
    assert!(results.len() == 0, "Non-matching genre should return empty");
}

// ==============================================================================
// STORE BRIDGE: filtered views with exact pagination
// ==============================================================================

#[test]
fn test_get_games_by_developer_pagination_correctness() {
    let registry = deploy_mock_registry();

    // Register: DevA, DevB, DevA, DevB, DevA
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "A1", "DevA", "Pub", "Genre");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "B1", "DevB", "Pub", "Genre");
    let g3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g3, "A2", "DevA", "Pub", "Genre");
    let g4 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g4, "B2", "DevB", "Pub", "Genre");
    let g5 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g5, "A3", "DevA", "Pub", "Genre");

    // DevA has 3 games: A1, A2, A3
    // Page 1: skip 0, count 2 -> A1, A2
    let page1 = registry.get_games_by_developer("DevA", 0, 2);
    assert!(page1.len() == 2, "Page 1 should have 2 games");
    assert!(page1.at(0).name == @"A1", "First should be A1");
    assert!(page1.at(1).name == @"A2", "Second should be A2");

    // Page 2: skip 2, count 2 -> A3
    let page2 = registry.get_games_by_developer("DevA", 2, 2);
    assert!(page2.len() == 1, "Page 2 should have 1 game");
    assert!(page2.at(0).name == @"A3", "Should be A3");

    // Page 3: skip 3, count 2 -> empty
    let page3 = registry.get_games_by_developer("DevA", 3, 2);
    assert!(page3.len() == 0, "Page 3 should be empty");
}

#[test]
fn test_get_games_by_publisher_pagination_correctness() {
    let registry = deploy_mock_registry();

    // Register: PubX, PubY, PubX, PubY, PubX
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "X1", "Dev", "PubX", "Genre");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "Y1", "Dev", "PubY", "Genre");
    let g3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g3, "X2", "Dev", "PubX", "Genre");
    let g4 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g4, "Y2", "Dev", "PubY", "Genre");
    let g5 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g5, "X3", "Dev", "PubX", "Genre");

    // PubX has 3 games: X1, X2, X3
    let page1 = registry.get_games_by_publisher("PubX", 0, 2);
    assert!(page1.len() == 2, "Page 1 should have 2 games");
    assert!(page1.at(0).name == @"X1", "First should be X1");
    assert!(page1.at(1).name == @"X2", "Second should be X2");

    let page2 = registry.get_games_by_publisher("PubX", 2, 2);
    assert!(page2.len() == 1, "Page 2 should have 1 game");
    assert!(page2.at(0).name == @"X3", "Should be X3");
}

#[test]
fn test_get_games_by_genre_pagination_correctness() {
    let registry = deploy_mock_registry();

    // Register mixed genres
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "P1", "Dev", "Pub", "Puzzle");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "A1", "Dev", "Pub", "Action");
    let g3 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g3, "P2", "Dev", "Pub", "Puzzle");
    let g4 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g4, "A2", "Dev", "Pub", "Action");
    let g5 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g5, "P3", "Dev", "Pub", "Puzzle");

    // Puzzle has 3 games: P1, P2, P3
    let page1 = registry.get_games_by_genre("Puzzle", 0, 2);
    assert!(page1.len() == 2, "Page 1 should have 2 games");
    assert!(page1.at(0).name == @"P1", "First should be P1");
    assert!(page1.at(1).name == @"P2", "Second should be P2");

    let page2 = registry.get_games_by_genre("Puzzle", 2, 2);
    assert!(page2.len() == 1, "Page 2 should have 1 game");
    assert!(page2.at(0).name == @"P3", "Should be P3");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_apply_metadata_defaults_royalty(royalty: u128) {
    let (_color, _client_url, _renderer_addr, result_royalty) = apply_metadata_defaults(
        Option::None, Option::None, Option::None, Option::Some(royalty),
    );
    assert!(result_royalty == royalty, "Royalty should always be preserved");
}

#[test]
#[fuzzer]
fn test_fuzz_get_games_by_developer_never_panics(start: u64, count: u64) {
    let registry = deploy_mock_registry();

    // Register 2 games from same developer
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "G1", "FuzzDev", "Pub", "Genre");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "G2", "FuzzDev", "Pub", "Genre");

    // Should never panic regardless of start/count values
    let results = registry.get_games_by_developer("FuzzDev", start, count);
    assert!(results.len() <= 2, "Should never return more than total matching games");
}

#[test]
#[fuzzer]
fn test_fuzz_get_games_by_publisher_never_panics(start: u64, count: u64) {
    let registry = deploy_mock_registry();

    // Register 2 games from same publisher
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "G1", "Dev", "FuzzPub", "Genre");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "G2", "Dev", "FuzzPub", "Genre");

    let results = registry.get_games_by_publisher("FuzzPub", start, count);
    assert!(results.len() <= 2, "Should never return more than total matching games");
}

#[test]
#[fuzzer]
fn test_fuzz_get_games_by_genre_never_panics(start: u64, count: u64) {
    let registry = deploy_mock_registry();

    // Register 2 Action games
    let g1 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g1, "G1", "Dev", "Pub", "FuzzGenre");
    let g2 = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, g2, "G2", "Dev", "Pub", "FuzzGenre");

    let results = registry.get_games_by_genre("FuzzGenre", start, count);
    assert!(results.len() <= 2, "Should never return more than total matching games");
}
