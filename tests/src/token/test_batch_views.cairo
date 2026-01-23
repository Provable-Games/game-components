// Tests for batch view functions in CoreTokenComponent
use game_components_token::interface::IMinigameTokenMixinDispatcherTrait;
use crate::token::setup::{ALICE, BOB, CHARLIE, setup};

// ============================================================================
// TOKEN_METADATA_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_token_metadata_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.token_metadata_batch(token_ids.span());
}

#[test]
fn test_token_metadata_batch_single() {
    let test_contracts = setup();

    // Mint a token
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_ids: Array<u64> = array![token_id];
    let results = test_contracts.test_token.token_metadata_batch(token_ids.span());

    assert!(results.len() == 1, "Should return one result");
    let metadata = results.at(0);
    assert!(!*metadata.soulbound, "Token should not be soulbound");
}

#[test]
fn test_token_metadata_batch_multiple() {
    let test_contracts = setup();

    // Mint multiple tokens
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player2'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            true,
        );

    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player3'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
        );

    let token_ids: Array<u64> = array![token_id1, token_id2, token_id3];
    let results = test_contracts.test_token.token_metadata_batch(token_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(!*results.at(0).soulbound, "Token 1 should not be soulbound");
    assert!(*results.at(1).soulbound, "Token 2 should be soulbound");
    assert!(!*results.at(2).soulbound, "Token 3 should not be soulbound");
}

#[test]
fn test_token_metadata_batch_nonexistent() {
    let test_contracts = setup();

    // Query non-existent token IDs - should return default/zero values
    let token_ids: Array<u64> = array![999, 1000, 1001];
    let results = test_contracts.test_token.token_metadata_batch(token_ids.span());

    assert!(results.len() == 3, "Should return three results");
    // Non-existent tokens should have default metadata (all zeros)
    assert!(*results.at(0).game_id == 0, "Non-existent token should have zero game_id");
}

// ============================================================================
// IS_PLAYABLE_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_is_playable_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.is_playable_batch(token_ids.span());
}

#[test]
fn test_is_playable_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];
    let results = test_contracts.test_token.is_playable_batch(token_ids.span());

    assert!(results.len() == 2, "Should return two results");
    assert!(*results.at(0), "Token 1 should be playable");
    assert!(*results.at(1), "Token 2 should be playable");
}

// ============================================================================
// SETTINGS_ID_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_settings_id_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.settings_id_batch(token_ids.span());
}

#[test]
fn test_settings_id_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens without settings_id (default to 0)
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];
    let results = test_contracts.test_token.settings_id_batch(token_ids.span());

    assert!(results.len() == 2, "Should return two results");
    assert!(*results.at(0) == 0, "Token 1 settings_id should be 0");
    assert!(*results.at(1) == 0, "Token 2 settings_id should be 0");
}

// ============================================================================
// PLAYER_NAME_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_player_name_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.player_name_batch(token_ids.span());
}

#[test]
fn test_player_name_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens with player names
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Alice'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Bob'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
        );

    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None, // No name
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
        );

    let token_ids: Array<u64> = array![token_id1, token_id2, token_id3];
    let results = test_contracts.test_token.player_name_batch(token_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(*results.at(0) == 'Alice', "Token 1 should have name Alice");
    assert!(*results.at(1) == 'Bob', "Token 2 should have name Bob");
    assert!(*results.at(2) == 0, "Token 3 should have empty name");
}

// ============================================================================
// OBJECTIVE_ID_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_objective_id_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.objective_id_batch(token_ids.span());
}

#[test]
fn test_objective_id_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens without objectives (default to 0)
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];
    let results = test_contracts.test_token.objective_id_batch(token_ids.span());

    assert!(results.len() == 2, "Should return two results");
    assert!(*results.at(0) == 0, "Token 1 objective_id should be 0");
    assert!(*results.at(1) == 0, "Token 2 objective_id should be 0");
}

// ============================================================================
// MINTED_BY_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_minted_by_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.minted_by_batch(token_ids.span());
}

#[test]
fn test_minted_by_batch_multiple() {
    let test_contracts = setup();

    // Mint multiple tokens
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];
    let results = test_contracts.test_token.minted_by_batch(token_ids.span());

    assert!(results.len() == 2, "Should return two results");
    // Both minted by the same caller, so should have minter IDs
    assert!(*results.at(0) > 0, "Token 1 should have valid minter ID");
    assert!(*results.at(1) > 0, "Token 2 should have valid minter ID");
}

// ============================================================================
// IS_SOULBOUND_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_is_soulbound_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.is_soulbound_batch(token_ids.span());
}

#[test]
fn test_is_soulbound_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens with different soulbound settings
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false // Not soulbound
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            true // Soulbound
        );

    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false // Not soulbound
        );

    let token_ids: Array<u64> = array![token_id1, token_id2, token_id3];
    let results = test_contracts.test_token.is_soulbound_batch(token_ids.span());

    assert!(results.len() == 3, "Should return three results");
    assert!(!*results.at(0), "Token 1 should not be soulbound");
    assert!(*results.at(1), "Token 2 should be soulbound");
    assert!(!*results.at(2), "Token 3 should not be soulbound");
}

// ============================================================================
// RENDERER_ADDRESS_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_renderer_address_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.renderer_address_batch(token_ids.span());
}

// Note: renderer_address_batch with actual tokens requires a fully initialized game registry
// because renderer_address() makes external calls to query game metadata.

// ============================================================================
// TOKEN_GAME_ADDRESS_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_token_game_address_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.token_game_address_batch(token_ids.span());
}

#[test]
fn test_token_game_address_batch_multiple() {
    let test_contracts = setup();

    // Mint tokens for the same game
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];
    let results = test_contracts.test_token.token_game_address_batch(token_ids.span());

    assert!(results.len() == 2, "Should return two results");
    // Both tokens are for the same game
    assert!(
        *results.at(0) == test_contracts.minigame.contract_address,
        "Token 1 should point to minigame",
    );
    assert!(
        *results.at(1) == test_contracts.minigame.contract_address,
        "Token 2 should point to minigame",
    );
}

// ============================================================================
// BATCH CONSISTENCY TESTS
// ============================================================================

#[test]
fn test_batch_matches_individual_calls() {
    let test_contracts = setup();

    // Mint tokens
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Alice'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Bob'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            true,
        );

    let token_ids: Array<u64> = array![token_id1, token_id2];

    // Get batch results
    let player_names_batch = test_contracts.test_token.player_name_batch(token_ids.span());
    let is_soulbound_batch = test_contracts.test_token.is_soulbound_batch(token_ids.span());

    // Get individual results
    let player_name1 = test_contracts.test_token.player_name(token_id1);
    let player_name2 = test_contracts.test_token.player_name(token_id2);
    let is_soulbound1 = test_contracts.test_token.is_soulbound(token_id1);
    let is_soulbound2 = test_contracts.test_token.is_soulbound(token_id2);

    // Verify consistency
    assert!(*player_names_batch.at(0) == player_name1, "Player name 1 should match");
    assert!(*player_names_batch.at(1) == player_name2, "Player name 2 should match");
    assert!(*is_soulbound_batch.at(0) == is_soulbound1, "Soulbound 1 should match");
    assert!(*is_soulbound_batch.at(1) == is_soulbound2, "Soulbound 2 should match");
}

// ============================================================================
// BATCH WRITE FUNCTION TESTS
// ============================================================================

use game_components_token::structs::{MintParams, PlayerNameUpdate, SetTokenMetadataParams};

#[test]
#[should_panic(expected: "MinigameToken: mints array cannot be empty")]
fn test_mint_batch_empty_panics() {
    let test_contracts = setup();

    let mints: Array<MintParams> = array![];
    test_contracts.test_token.mint_batch(mints);
}

#[test]
fn test_mint_batch_single() {
    let test_contracts = setup();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::Some('Alice'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);

    assert!(token_ids.len() == 1, "Should return one token_id");
    let token_id = *token_ids.at(0);
    assert!(test_contracts.test_token.player_name(token_id) == 'Alice', "Player name should match");
    assert!(!test_contracts.test_token.is_soulbound(token_id), "Should not be soulbound");
}

#[test]
fn test_mint_batch_multiple() {
    let test_contracts = setup();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::Some('Alice'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
        },
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::Some('Bob'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: true,
        },
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: CHARLIE(),
            soulbound: false,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);

    assert!(token_ids.len() == 3, "Should return three token_ids");

    // Verify each token
    let token_id1 = *token_ids.at(0);
    let token_id2 = *token_ids.at(1);
    let token_id3 = *token_ids.at(2);

    assert!(test_contracts.test_token.player_name(token_id1) == 'Alice', "Token 1 name");
    assert!(test_contracts.test_token.player_name(token_id2) == 'Bob', "Token 2 name");
    assert!(test_contracts.test_token.player_name(token_id3) == 0, "Token 3 should have no name");

    assert!(!test_contracts.test_token.is_soulbound(token_id1), "Token 1 not soulbound");
    assert!(test_contracts.test_token.is_soulbound(token_id2), "Token 2 soulbound");
    assert!(!test_contracts.test_token.is_soulbound(token_id3), "Token 3 not soulbound");
}

#[test]
fn test_mint_batch_different_settings() {
    let test_contracts = setup();

    // Test minting with different settings per token
    let mints: Array<MintParams> = array![
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::Some(1000),
            end: Option::Some(2000),
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
        },
        MintParams {
            game_address: Option::Some(test_contracts.minigame.contract_address),
            player_name: Option::Some('Player2'),
            settings_id: Option::None,
            start: Option::Some(3000),
            end: Option::Some(4000),
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: true,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);

    assert!(token_ids.len() == 2, "Should return two token_ids");

    let token_id1 = *token_ids.at(0);
    let token_id2 = *token_ids.at(1);

    // Verify tokens have different properties
    assert!(test_contracts.test_token.player_name(token_id1) == 'Player1', "Token 1 name");
    assert!(test_contracts.test_token.player_name(token_id2) == 'Player2', "Token 2 name");
    assert!(!test_contracts.test_token.is_soulbound(token_id1), "Token 1 not soulbound");
    assert!(test_contracts.test_token.is_soulbound(token_id2), "Token 2 soulbound");
}

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_update_game_batch_empty_panics() {
    let test_contracts = setup();

    let token_ids: Array<u64> = array![];
    test_contracts.test_token.update_game_batch(token_ids.span());
}

#[test]
#[should_panic(expected: "MinigameToken: updates array cannot be empty")]
fn test_update_player_name_batch_empty_panics() {
    let test_contracts = setup();

    let updates: Array<PlayerNameUpdate> = array![];
    test_contracts.test_token.update_player_name_batch(updates.span());
}

#[test]
fn test_update_player_name_batch_multiple() {
    let test_contracts = setup();

    // Mint both tokens to ALICE so she can update them in batch
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('OldName1'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('OldName2'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(), // Changed from BOB() to ALICE() so same owner can update batch
            false,
        );

    // Verify old names
    assert!(test_contracts.test_token.player_name(token_id1) == 'OldName1', "Initial name 1");
    assert!(test_contracts.test_token.player_name(token_id2) == 'OldName2', "Initial name 2");

    // Update names in batch - ALICE is the owner and caller
    snforge_std::start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    let updates: Array<PlayerNameUpdate> = array![
        PlayerNameUpdate { token_id: token_id1, name: 'NewName1' },
        PlayerNameUpdate { token_id: token_id2, name: 'NewName2' },
    ];
    test_contracts.test_token.update_player_name_batch(updates.span());
    snforge_std::stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Verify new names
    assert!(test_contracts.test_token.player_name(token_id1) == 'NewName1', "Updated name 1");
    assert!(test_contracts.test_token.player_name(token_id2) == 'NewName2', "Updated name 2");
}

#[test]
#[should_panic(expected: "MinigameToken: updates array cannot be empty")]
fn test_set_token_metadata_batch_empty_panics() {
    let test_contracts = setup();

    let updates: Array<SetTokenMetadataParams> = array![];
    test_contracts.test_token.set_token_metadata_batch(updates);
}
