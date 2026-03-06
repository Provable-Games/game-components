// ==============================================================================
// BATCH VIEW FUNCTION TESTS
// ==============================================================================
// Tests for batch view functions in MinigameRegistryComponent

use core::num::traits::Zero;
use game_components_embeddable_game_standard::registry::interface::{
    IMinigameRegistryDispatcher, IMinigameRegistryDispatcherTrait,
};
use game_components_testing::constants::CREATOR;
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

fn register_game_with_name(
    registry: IMinigameRegistryDispatcher, game_address: ContractAddress, name: ByteArray,
) -> u64 {
    mock_call(game_address, selector!("supports_interface"), true, 10);

    start_cheat_caller_address(registry.contract_address, game_address);
    let game_id = registry
        .register_game(
            CREATOR(),
            name,
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            1,
        );
    stop_cheat_caller_address(registry.contract_address);
    game_id
}

// ==============================================================================
// GAME_METADATA_BATCH TESTS
// ==============================================================================

#[test]
#[should_panic]
fn test_game_metadata_batch_empty_panics() {
    let registry = deploy_mock_registry();

    let game_ids: Array<u64> = array![];
    registry.game_metadata_batch(game_ids.span());
}

#[test]
fn test_game_metadata_batch_single() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_with_name(registry, game_address, "Test Game");

    let game_ids: Array<u64> = array![game_id];
    let results = registry.game_metadata_batch(game_ids.span());

    assert!(results.len() == 1, "Should return one result");
    let metadata = results.at(0);
    assert!(metadata.name == @"Test Game", "Name should match");
    assert!(metadata.contract_address == @game_address, "Address should match");
}

#[test]
fn test_game_metadata_batch_multiple() {
    let registry = deploy_mock_registry();

    // Register multiple games
    let game1_address = deploy_mock_minigame_for_registration();
    let game1_id = register_game_with_name(registry, game1_address, "Game One");

    let game2_address = deploy_mock_minigame_for_registration();
    let game2_id = register_game_with_name(registry, game2_address, "Game Two");

    let game3_address = deploy_mock_minigame_for_registration();
    let game3_id = register_game_with_name(registry, game3_address, "Game Three");

    let game_ids: Array<u64> = array![game1_id, game2_id, game3_id];
    let results = registry.game_metadata_batch(game_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(results.at(0).name == @"Game One", "Game 1 name should match");
    assert!(results.at(1).name == @"Game Two", "Game 2 name should match");
    assert!(results.at(2).name == @"Game Three", "Game 3 name should match");
}

#[test]
fn test_game_metadata_batch_nonexistent() {
    let registry = deploy_mock_registry();

    // Query non-existent game IDs - should return default/zero values
    let game_ids: Array<u64> = array![999, 1000, 1001];
    let results = registry.game_metadata_batch(game_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(results.at(0).contract_address.is_zero(), "Non-existent game should have zero address");
    assert!(results.at(0).name == @"", "Non-existent game should have empty name");
}

#[test]
fn test_game_metadata_batch_mixed_existent_nonexistent() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_with_name(registry, game_address, "Real Game");

    // Mix of existent and non-existent IDs
    let game_ids: Array<u64> = array![game_id, 999, game_id];
    let results = registry.game_metadata_batch(game_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(results.at(0).name == @"Real Game", "First should be real game");
    assert!(results.at(1).contract_address.is_zero(), "Second should be non-existent");
    assert!(results.at(2).name == @"Real Game", "Third should be real game");
}

#[test]
fn test_game_metadata_batch_consistency_with_individual() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    let game_id = register_game_with_name(registry, game_address, "Consistency Test");

    // Get individual result
    let individual_metadata = registry.game_metadata(game_id);

    // Get batch result
    let game_ids: Array<u64> = array![game_id];
    let batch_results = registry.game_metadata_batch(game_ids.span());

    // Verify consistency
    let batch_metadata = batch_results.at(0);
    assert!(batch_metadata.name == @individual_metadata.name, "Names should match");
    assert!(
        batch_metadata.contract_address == @individual_metadata.contract_address,
        "Addresses should match",
    );
    assert!(
        batch_metadata.description == @individual_metadata.description, "Descriptions should match",
    );
}

// ==============================================================================
// GAMES_REGISTERED_BATCH TESTS
// ==============================================================================

#[test]
#[should_panic]
fn test_games_registered_batch_empty_panics() {
    let registry = deploy_mock_registry();

    let addresses: Array<ContractAddress> = array![];
    registry.games_registered_batch(addresses.span());
}

#[test]
fn test_games_registered_batch_single() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    // Before registration
    let addresses: Array<ContractAddress> = array![game_address];
    let results_before = registry.games_registered_batch(addresses.span());
    assert!(!*results_before.at(0), "Should not be registered initially");

    // Register
    register_game_with_name(registry, game_address, "Test Game");

    // After registration
    let results_after = registry.games_registered_batch(addresses.span());
    assert!(*results_after.at(0), "Should be registered after register_game");
}

#[test]
fn test_games_registered_batch_multiple() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    let game2_address = deploy_mock_minigame_for_registration();
    let unregistered_address = addr(0xABCDEF);

    // Register only game1
    register_game_with_name(registry, game1_address, "Registered Game");

    let addresses: Array<ContractAddress> = array![
        game1_address, game2_address, unregistered_address,
    ];
    let results = registry.games_registered_batch(addresses.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(*results.at(0), "Game 1 should be registered");
    assert!(!*results.at(1), "Game 2 should not be registered");
    assert!(!*results.at(2), "Random address should not be registered");
}

#[test]
fn test_games_registered_batch_consistency_with_individual() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    let game2_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game1_address, "Registered");

    // Get individual results
    let individual1 = registry.is_game_registered(game1_address);
    let individual2 = registry.is_game_registered(game2_address);

    // Get batch results
    let addresses: Array<ContractAddress> = array![game1_address, game2_address];
    let batch_results = registry.games_registered_batch(addresses.span());

    // Verify consistency
    assert!(*batch_results.at(0) == individual1, "First result should match individual");
    assert!(*batch_results.at(1) == individual2, "Second result should match individual");
}

// ==============================================================================
// GET_GAMES TESTS
// ==============================================================================

#[test]
fn test_get_games_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games(1, 10);
    assert!(results.len() == 0, "Should return empty array for empty registry");
}

#[test]
fn test_get_games_single() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game_address, "Only Game");

    let results = registry.get_games(1, 10);
    assert!(results.len() == 1, "Should return one game");
    assert!(results.at(0).name == @"Only Game", "Game name should match");
}

#[test]
fn test_get_games_pagination_first_page() {
    let registry = deploy_mock_registry();

    // Register 5 games
    let mut i: u32 = 0;
    loop {
        if i >= 5 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_name(registry, game_address, "Game");
        i += 1;
    }

    // Get first 3
    let results = registry.get_games(1, 3);
    assert!(results.len() == 3, "Should return 3 games");
}

#[test]
fn test_get_games_pagination_second_page() {
    let registry = deploy_mock_registry();

    // Register 5 games
    let mut i: u32 = 0;
    loop {
        if i >= 5 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_name(registry, game_address, "Game");
        i += 1;
    }

    // Get games 4-5 (start at 4, count 3 but only 2 exist)
    let results = registry.get_games(4, 3);
    assert!(results.len() == 2, "Should return 2 games");
}

#[test]
fn test_get_games_start_zero() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game_address, "Game");

    // Start at 0 should return empty (game IDs are 1-indexed)
    let results = registry.get_games(0, 10);
    assert!(results.len() == 0, "Start 0 should return empty array");
}

#[test]
fn test_get_games_start_beyond_count() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game_address, "Game");

    // Start beyond game count should return empty
    let results = registry.get_games(100, 10);
    assert!(results.len() == 0, "Start beyond count should return empty array");
}

#[test]
fn test_get_games_count_zero() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game_address, "Game");

    // Count 0 should return empty
    let results = registry.get_games(1, 0);
    assert!(results.len() == 0, "Count 0 should return empty array");
}

#[test]
fn test_get_games_exact_range() {
    let registry = deploy_mock_registry();

    // Register 3 games
    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game1_address, "Game 1");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game2_address, "Game 2");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game3_address, "Game 3");

    // Get all 3
    let results = registry.get_games(1, 3);
    assert!(results.len() == 3, "Should return all 3 games");
    assert!(results.at(0).name == @"Game 1", "First game name");
    assert!(results.at(1).name == @"Game 2", "Second game name");
    assert!(results.at(2).name == @"Game 3", "Third game name");
}

#[test]
fn test_get_games_count_exceeds_available() {
    let registry = deploy_mock_registry();
    let game_address = deploy_mock_minigame_for_registration();

    register_game_with_name(registry, game_address, "Only Game");

    // Request more than available
    let results = registry.get_games(1, 100);
    assert!(results.len() == 1, "Should return only available games");
}

#[test]
fn test_get_games_order_preserved() {
    let registry = deploy_mock_registry();

    // Register games in specific order
    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game1_address, "First");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game2_address, "Second");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_name(registry, game3_address, "Third");

    let results = registry.get_games(1, 10);

    // Verify order is preserved
    assert!(results.at(0).name == @"First", "First game should be first");
    assert!(results.at(1).name == @"Second", "Second game should be second");
    assert!(results.at(2).name == @"Third", "Third game should be third");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_get_games_pagination(start: u64, count: u64) {
    let registry = deploy_mock_registry();

    // Register 3 games
    let mut i: u32 = 0;
    loop {
        if i >= 3 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_name(registry, game_address, "Game");
        i += 1;
    }

    // Should never panic
    let results = registry.get_games(start, count);

    // Results should be at most 3 (total games registered)
    assert!(results.len() <= 3, "Should never return more than total games");
}

// ==============================================================================
// HELPER FOR FILTERED TESTS
// ==============================================================================

fn register_game_with_metadata(
    registry: IMinigameRegistryDispatcher,
    game_address: ContractAddress,
    name: ByteArray,
    developer: ByteArray,
    publisher: ByteArray,
    genre: ByteArray,
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
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            1,
        );
    stop_cheat_caller_address(registry.contract_address);
    game_id
}

// ==============================================================================
// GET_GAMES_BY_DEVELOPER TESTS
// ==============================================================================

#[test]
fn test_get_games_by_developer_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_developer("DevStudio", 0, 10);
    assert!(results.len() == 0, "Should return empty for empty registry");
}

#[test]
fn test_get_games_by_developer_no_matches() {
    let registry = deploy_mock_registry();

    let game_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game_address, "Game 1", "DevA", "PubA", "Action");

    let results = registry.get_games_by_developer("NonExistent", 0, 10);
    assert!(results.len() == 0, "Should return empty when no developer matches");
}

#[test]
fn test_get_games_by_developer_single_match() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1_address, "Game 1", "DevA", "PubA", "Action");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2_address, "Game 2", "DevB", "PubB", "Puzzle");

    let results = registry.get_games_by_developer("DevA", 0, 10);
    assert!(results.len() == 1, "Should return one match");
    assert!(results.at(0).name == @"Game 1", "Should return correct game");
}

#[test]
fn test_get_games_by_developer_multiple_matches() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1_address, "Game 1", "StudioX", "PubA", "Action");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2_address, "Game 2", "StudioY", "PubB", "Puzzle");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3_address, "Game 3", "StudioX", "PubC", "RPG");

    let results = registry.get_games_by_developer("StudioX", 0, 10);
    assert!(results.len() == 2, "Should return two matches");
    assert!(results.at(0).name == @"Game 1", "First match");
    assert!(results.at(1).name == @"Game 3", "Second match");
}

#[test]
fn test_get_games_by_developer_pagination() {
    let registry = deploy_mock_registry();

    // Register 5 games from same developer
    let mut i: u32 = 0;
    loop {
        if i >= 5 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game_address, "Game", "SameDev", "Pub", "Genre");
        i += 1;
    }

    // Get first 2
    let page1 = registry.get_games_by_developer("SameDev", 0, 2);
    assert!(page1.len() == 2, "First page should have 2 games");

    // Get next 2 (skip 2)
    let page2 = registry.get_games_by_developer("SameDev", 2, 2);
    assert!(page2.len() == 2, "Second page should have 2 games");

    // Get last 1 (skip 4)
    let page3 = registry.get_games_by_developer("SameDev", 4, 2);
    assert!(page3.len() == 1, "Third page should have 1 game");
}

#[test]
fn test_get_games_by_developer_count_zero() {
    let registry = deploy_mock_registry();

    let game_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game_address, "Game 1", "DevA", "PubA", "Action");

    let results = registry.get_games_by_developer("DevA", 0, 0);
    assert!(results.len() == 0, "Count 0 should return empty");
}

// ==============================================================================
// GET_GAMES_BY_PUBLISHER TESTS
// ==============================================================================

#[test]
fn test_get_games_by_publisher_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_publisher("BigPublisher", 0, 10);
    assert!(results.len() == 0, "Should return empty for empty registry");
}

#[test]
fn test_get_games_by_publisher_no_matches() {
    let registry = deploy_mock_registry();

    let game_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game_address, "Game 1", "DevA", "PubA", "Action");

    let results = registry.get_games_by_publisher("NonExistent", 0, 10);
    assert!(results.len() == 0, "Should return empty when no publisher matches");
}

#[test]
fn test_get_games_by_publisher_multiple_matches() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1_address, "Game 1", "DevA", "MegaCorp", "Action");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2_address, "Game 2", "DevB", "IndiePub", "Puzzle");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3_address, "Game 3", "DevC", "MegaCorp", "RPG");

    let results = registry.get_games_by_publisher("MegaCorp", 0, 10);
    assert!(results.len() == 2, "Should return two matches");
    assert!(results.at(0).name == @"Game 1", "First match");
    assert!(results.at(1).name == @"Game 3", "Second match");
}

#[test]
fn test_get_games_by_publisher_pagination() {
    let registry = deploy_mock_registry();

    // Register 4 games from same publisher
    let mut i: u32 = 0;
    loop {
        if i >= 4 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game_address, "Game", "Dev", "SamePub", "Genre");
        i += 1;
    }

    // Get first 2
    let page1 = registry.get_games_by_publisher("SamePub", 0, 2);
    assert!(page1.len() == 2, "First page should have 2 games");

    // Skip first 2, get next 2
    let page2 = registry.get_games_by_publisher("SamePub", 2, 2);
    assert!(page2.len() == 2, "Second page should have 2 games");
}

// ==============================================================================
// GET_GAMES_BY_GENRE TESTS
// ==============================================================================

#[test]
fn test_get_games_by_genre_empty_registry() {
    let registry = deploy_mock_registry();

    let results = registry.get_games_by_genre("Action", 0, 10);
    assert!(results.len() == 0, "Should return empty for empty registry");
}

#[test]
fn test_get_games_by_genre_no_matches() {
    let registry = deploy_mock_registry();

    let game_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game_address, "Game 1", "DevA", "PubA", "Action");

    let results = registry.get_games_by_genre("Horror", 0, 10);
    assert!(results.len() == 0, "Should return empty when no genre matches");
}

#[test]
fn test_get_games_by_genre_multiple_matches() {
    let registry = deploy_mock_registry();

    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1_address, "Game 1", "DevA", "PubA", "Puzzle");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2_address, "Game 2", "DevB", "PubB", "Action");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3_address, "Game 3", "DevC", "PubC", "Puzzle");

    let game4_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game4_address, "Game 4", "DevD", "PubD", "Puzzle");

    let results = registry.get_games_by_genre("Puzzle", 0, 10);
    assert!(results.len() == 3, "Should return three puzzle games");
    assert!(results.at(0).name == @"Game 1", "First match");
    assert!(results.at(1).name == @"Game 3", "Second match");
    assert!(results.at(2).name == @"Game 4", "Third match");
}

#[test]
fn test_get_games_by_genre_pagination() {
    let registry = deploy_mock_registry();

    // Register 6 action games
    let mut i: u32 = 0;
    loop {
        if i >= 6 {
            break;
        }
        let game_address = deploy_mock_minigame_for_registration();
        register_game_with_metadata(registry, game_address, "Game", "Dev", "Pub", "Action");
        i += 1;
    }

    // Get first 3
    let page1 = registry.get_games_by_genre("Action", 0, 3);
    assert!(page1.len() == 3, "First page should have 3 games");

    // Skip 3, get next 3
    let page2 = registry.get_games_by_genre("Action", 3, 3);
    assert!(page2.len() == 3, "Second page should have 3 games");

    // Skip 6, should be empty
    let page3 = registry.get_games_by_genre("Action", 6, 3);
    assert!(page3.len() == 0, "Third page should be empty");
}

#[test]
fn test_get_games_by_genre_mixed_with_other_genres() {
    let registry = deploy_mock_registry();

    // Mix of genres
    let game1_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game1_address, "RPG Game 1", "Dev", "Pub", "RPG");

    let game2_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game2_address, "Action Game", "Dev", "Pub", "Action");

    let game3_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game3_address, "RPG Game 2", "Dev", "Pub", "RPG");

    let game4_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game4_address, "Puzzle Game", "Dev", "Pub", "Puzzle");

    let game5_address = deploy_mock_minigame_for_registration();
    register_game_with_metadata(registry, game5_address, "RPG Game 3", "Dev", "Pub", "RPG");

    // Should only get RPG games
    let results = registry.get_games_by_genre("RPG", 0, 10);
    assert!(results.len() == 3, "Should return 3 RPG games");
    assert!(results.at(0).name == @"RPG Game 1", "First RPG");
    assert!(results.at(1).name == @"RPG Game 2", "Second RPG");
    assert!(results.at(2).name == @"RPG Game 3", "Third RPG");
}
