use starknet::contract_address_const;
use snforge_std::{
    start_cheat_block_timestamp, stop_cheat_block_timestamp, cheat_caller_address, CheatSpan,
};

use openzeppelin_token::erc721::interface::ERC721ABIDispatcherTrait;
use game_components_token::interface::IMinigameTokenMixinDispatcherTrait;
use game_components_metagame::extensions::context::structs::{GameContextDetails, GameContext};
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcherTrait,
};

// Import mocks
use super::mocks::mock_game::{IMockGameDispatcherTrait};

// Import setup helpers
use super::setup::{
    setup, setup_multi_game, deploy_mock_game, deploy_basic_mock_game,
    deploy_test_token_contract_with_game, deploy_test_token_contract, ALICE, BOB, CHARLIE,
    ZERO_ADDRESS, RENDERER_ADDRESS, MAX_U64, PAST_TIME, CURRENT_TIME, FUTURE_TIME, FAR_FUTURE_TIME,
};

// All test constants, deployment helpers, and setup functions are now in setup.cairo

// ================================================================================================
// MINT FUNCTION TESTS
// ================================================================================================

// Happy Path Tests

#[test]
fn test_mint_minimal_parameters() { // UT-MINT-001
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None, // game_address - will use default
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_ids
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
        );

    assert!(token_id == 1, "Token ID should be 1");
    assert!(test_contracts.erc721.owner_of(token_id.into()) == ALICE(), "Owner should be ALICE");
    assert!(test_contracts.erc721.balance_of(ALICE()) == 1, "Balance should be 1");

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound == false, "Should not be soulbound");
    assert!(metadata.game_over == false, "Game should not be over");
    assert!(metadata.completed_all_objectives == false, "Objectives should not be completed");
    assert!(metadata.objectives_count == 0, "Should have no objectives");
    assert!(metadata.settings_id == 0, "Settings ID should be 0");
    assert!(metadata.lifecycle.start == 0, "Start time should be 0");
    assert!(metadata.lifecycle.end == 0, "End time should be 0");
}

#[test]
// #[ignore] // TODO: Fix ENTRYPOINT_NOT_FOUND error with objectives/settings
fn test_mint_with_all_parameters() { // UT-MINT-002
    let test_contracts = setup();

    // TODO: Fix objective creation - currently causing ENTRYPOINT_NOT_FOUND
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_objective_score(200);
    test_contracts.mock_minigame.create_objective_score(300);
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy mode", 1);

    let objective_ids = array![1, 2, 3].span();
    let game_contexts = array![GameContext { name: "tournament", value: "42" }];
    let _context = GameContextDetails {
        name: "Tournament",
        description: "Tournament mode",
        id: Option::Some(42),
        context: game_contexts.span(),
    };

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("TestPlayer"),
            Option::Some(1), // Option::Some(1), // settings_id - disabled for now
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
            Option::Some(objective_ids), // Option::Some(objective_ids), - disabled for now
            // Option::Some(context), // TODO: This checks for MetagameInterface from Caller so can
            // only be provided from contract
            Option::None,
            Option::Some("https://client.game.com"),
            Option::Some(RENDERER_ADDRESS()),
            ALICE(),
            true // soulbound
        );

    assert!(token_id == 1, "Token ID should be 1");

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound == true, "Should be soulbound");
    assert!(metadata.settings_id == 1, "Settings ID should be 1");
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start time mismatch");
    assert!(metadata.lifecycle.end == FUTURE_TIME, "End time mismatch");
    assert!(metadata.objectives_count == 3, "Should have 3 objectives");
    assert!(metadata.game_id != 0, "Game ID should not be 0");

    assert!(
        test_contracts.test_token.player_name(token_id) == "TestPlayer", "Player name mismatch",
    );
    assert!(
        test_contracts
            .test_token
            .game_address() == test_contracts
            .minigame
            .contract_address,
        "Game address mismatch",
    );
    assert!(test_contracts.test_token.is_soulbound(token_id) == true, "Should be soulbound");
    assert!(
        test_contracts.test_token.renderer_address(token_id) == RENDERER_ADDRESS(),
        "Renderer address mismatch",
    );
}

#[test]
fn test_mint_soulbound_token() { // UT-MINT-003
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
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
            true // soulbound
        );

    assert!(test_contracts.test_token.is_soulbound(token_id) == true, "Token should be soulbound");
    // TODO: Add transfer restriction test when soulbound hooks are properly implemented
}

#[test]
fn test_mint_with_lifecycle_constraints() { // UT-MINT-004
    let test_contracts = setup();
    let contract_address = test_contracts.test_token.contract_address;

    // Set current time
    start_cheat_block_timestamp(contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME - 100), // Past start time
            Option::Some(FUTURE_TIME),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Token should be playable
    assert!(test_contracts.test_token.is_playable(token_id) == true, "Token should be playable");

    // Move to future
    start_cheat_block_timestamp(contract_address, FAR_FUTURE_TIME);
    assert!(
        test_contracts.test_token.is_playable(token_id) == false,
        "Token should not be playable after end time",
    );

    stop_cheat_block_timestamp(contract_address);
}

#[test]
fn test_mint_with_objectives() { // UT-MINT-005
    let test_contracts = setup();

    // Create objectives
    test_contracts.mock_minigame.create_objective_score(50);
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_objective_score(150);
    test_contracts.mock_minigame.create_objective_score(200);
    test_contracts.mock_minigame.create_objective_score(250);

    let objective_ids = array![1, 2, 3, 4, 5].span();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(test_contracts.test_token.objectives_count(token_id) == 5, "Should have 5 objectives");

    let objectives = test_contracts.test_token.objectives(token_id);
    assert!(objectives.len() == 5, "Should return 5 objectives");

    let obj_ids = test_contracts.test_token.objective_ids(token_id);
    assert!(obj_ids.len() == 5, "Should return 5 objective IDs");
    assert!(*obj_ids.at(0) == 1, "First objective ID should be 1");
    assert!(*obj_ids.at(4) == 5, "Last objective ID should be 5");
}

#[test]
fn test_mint_with_custom_renderer() { // UT-MINT-006
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            ALICE(),
            false,
        );

    assert!(
        test_contracts.test_token.renderer_address(token_id) == RENDERER_ADDRESS(),
        "Renderer address mismatch",
    );
    assert!(
        test_contracts.test_token.has_custom_renderer(token_id) == true,
        "Should have custom renderer",
    );
}

// Revert Path Tests

#[test]
#[should_panic]
fn test_mint_to_zero_address() { // UT-MINT-R001
    let test_contracts = setup();

    test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ZERO_ADDRESS(),
            false,
        );
}

#[test]
#[should_panic(expected: "CoreToken: Game address is zero")]
fn test_mint_with_invalid_game_address() { // UT-MINT-R002
    let test_contracts = setup();

    test_contracts
        .test_token
        .mint(
            Option::Some(ZERO_ADDRESS()),
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
}

#[test]
#[should_panic]
fn test_mint_with_non_minigame_contract() { // UT-MINT-R003
    let test_contracts = setup();

    // Use the token contract address as a non-minigame contract
    test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.test_token.contract_address),
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
}

#[test]
#[should_panic]
fn test_mint_with_invalid_settings_id() { // UT-MINT-R004
    let test_contracts = setup();

    // Try to use settings_id that doesn't exist
    test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::Some(999), // Non-existent settings_id
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );
}

#[test]
#[should_panic(expected: "MinigameTokenObjectives: Objective ID does not exist")]
fn test_mint_with_invalid_objective_ids() { // UT-MINT-R005
    let test_contracts = setup();

    // Create only 2 objectives
    test_contracts.mock_minigame.create_objective_score(50);
    test_contracts.mock_minigame.create_objective_score(100);

    // Try to use objective IDs that don't exist
    let objective_ids = array![1, 2, 3, 4].span(); // 3 and 4 don't exist

    test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_mint_with_start_greater_than_end() { // UT-MINT-R006
    let test_contracts = setup();

    test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(FUTURE_TIME),
            Option::Some(CURRENT_TIME), // end < start
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );
}

#[test]
#[should_panic(expected: "CoreToken: Game address does not support IMinigame interface")]
fn test_mint_when_game_registry_lookup_fails() { // UT-MINT-R007
    let test_contracts = setup_multi_game();

    // Deploy a new game that's not registered in the registry
    let (unregistered_game, _, _) = deploy_mock_game();

    // Try to mint with an unregistered game address
    test_contracts
        .test_token
        .mint(
            Option::Some(unregistered_game.contract_address),
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
}

// Boundary Tests

#[test]
fn test_mint_with_max_timestamps() { // UT-MINT-B001
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(MAX_U64 - 1000),
            Option::Some(MAX_U64),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == MAX_U64 - 1000, "Start time should be MAX_U64 - 1000");
    assert!(metadata.lifecycle.end == MAX_U64, "End time should be MAX_U64");
}

#[test]
fn test_mint_with_empty_objective_array() { // UT-MINT-B002
    let test_contracts = setup();

    let empty_objectives = array![].span();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(empty_objectives),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(test_contracts.test_token.objectives_count(token_id) == 0, "Should have 0 objectives");
}

#[test]
// #[ignore] // TODO: Fix objective creation
fn test_mint_with_maximum_objectives() { // UT-MINT-B003
    let test_contracts = setup();

    // Create 100 objectives
    let mut i: u32 = 0;
    while i < 100 {
        test_contracts.mock_minigame.create_objective_score(i);
        i += 1;
    };

    // Create array with 100 objective IDs
    let mut objectives = array![];
    let mut j: u32 = 1;
    while j <= 100 {
        objectives.append(j);
        j += 1;
    };

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objectives.span()),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(
        test_contracts.test_token.objectives_count(token_id) == 100, "Should have 100 objectives",
    );
}

#[test]
fn test_sequential_mints_increment_counter() { // UT-MINT-B004
    let test_contracts = setup();

    let token_id_1 = test_contracts
        .test_token
        .mint(
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
        );

    let token_id_2 = test_contracts
        .test_token
        .mint(
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
        );

    let token_id_3 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
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

    assert!(token_id_1 == 1, "First token ID should be 1");
    assert!(token_id_2 == 2, "Second token ID should be 2");
    assert!(token_id_3 == 3, "Third token ID should be 3");

    assert!(test_contracts.erc721.owner_of(1) == ALICE(), "Token 1 should belong to ALICE");
    assert!(test_contracts.erc721.owner_of(2) == BOB(), "Token 2 should belong to BOB");
    assert!(test_contracts.erc721.owner_of(3) == CHARLIE(), "Token 3 should belong to CHARLIE");
}

// ================================================================================================
// UPDATE_GAME FUNCTION TESTS
// ================================================================================================

// Happy Path Tests

#[test]
fn test_update_game_with_state_changes() { // UT-UPDATE-001
    let (_, mock_game) = deploy_basic_mock_game();

    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id = token_dispatcher
        .mint(
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
        );

    // Set game state
    mock_game.set_score(token_id, 100);
    mock_game.set_game_over(token_id, true);

    // Update token
    token_dispatcher.update_game(token_id);

    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_over == true, "Game should be over");
    // Score is stored in the game contract, not in token metadata
}

#[test]
fn test_update_game_without_state_changes() { // UT-UPDATE-002
    let (_, mock_game) = deploy_basic_mock_game();

    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id = token_dispatcher
        .mint(
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
        );

    // Update without changing state
    token_dispatcher.update_game(token_id);

    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_over == false, "Game should not be over");
    // Score verification would be on the game contract side
}

#[test]
fn test_update_game_with_objectives_completion() { // UT-UPDATE-003
    let test_contracts = setup();

    // Create objectives
    test_contracts.mock_minigame.create_objective_score(50);
    test_contracts.mock_minigame.create_objective_score(100);

    let objective_ids = array![1, 2].span();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // TODO: Set objectives as completed once objective completion logic is implemented
    test_contracts.mock_minigame.end_game(token_id, 100);
    // For now, just verify update doesn't fail
    test_contracts.test_token.update_game(token_id);

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_all_objectives == true, "Should have completed all objectives");
}

#[test]
fn test_update_game_with_game_over_transition() { // UT-UPDATE-004
    let (_, mock_game) = deploy_basic_mock_game();

    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id = token_dispatcher
        .mint(
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
        );

    // Verify initial state
    let metadata_before = token_dispatcher.token_metadata(token_id);
    assert!(metadata_before.game_over == false, "Game should not be over initially");

    // Set game as over
    mock_game.set_game_over(token_id, true);
    mock_game.set_score(token_id, 42);

    // Update token
    token_dispatcher.update_game(token_id);

    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(metadata_after.game_over == true, "Game should be over");
    // Score verification would be on the game contract side
}

// Revert Path Tests

#[test]
#[should_panic]
fn test_update_nonexistent_token() { // UT-UPDATE-R001
    let test_contracts = setup();

    // Try to update a token that doesn't exist
    test_contracts.test_token.update_game(999);
}

#[ignore]
#[test]
#[should_panic]
fn test_update_game_with_blank_token() {
    // Deploy a token contract without any game address
    let (token_dispatcher, _, _, _) = deploy_test_token_contract();

    // Mint a blank token (no game address specified in mint either)
    let token_id = token_dispatcher
        .mint(
            Option::None, // No game address
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

    // This should panic because there's no game address set
    token_dispatcher.update_game(token_id);
}

// State Transition Tests

#[test]
fn test_game_over_false_to_true_transition() { // UT-UPDATE-S001
    let (_, mock_game) = deploy_basic_mock_game();

    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id = token_dispatcher
        .mint(
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
        );

    // Initial state
    let metadata1 = token_dispatcher.token_metadata(token_id);
    assert!(metadata1.game_over == false, "Game should not be over initially");

    // Set game over
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    let metadata2 = token_dispatcher.token_metadata(token_id);
    assert!(metadata2.game_over == true, "Game should be over");

    // Try to set back to false (should still be true - invariant)
    mock_game.set_game_over(token_id, false);
    token_dispatcher.update_game(token_id);

    let metadata3 = token_dispatcher.token_metadata(token_id);
    assert!(metadata3.game_over == true, "Game should still be over - state can't revert");
}

#[test]
// #[ignore] // TODO: Fix objective creation
fn test_objectives_completion_progression() { // UT-UPDATE-S002
    // TODO: Implement once objective completion logic is available
    // For now, just verify update doesn't break with objectives
    let test_contracts = setup();

    test_contracts.mock_minigame.create_objective_score(50);
    let objective_ids = array![1].span();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    test_contracts.test_token.update_game(token_id);

    let objectives = test_contracts.test_token.objectives(token_id);
    assert!(objectives.len() == 1, "Should have 1 objective");
}

#[test]
fn test_idempotent_updates() { // UT-UPDATE-S003
    let (_, mock_game) = deploy_basic_mock_game();

    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id = token_dispatcher
        .mint(
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
        );

    // Set state
    mock_game.set_score(token_id, 75);
    mock_game.set_game_over(token_id, true);

    // First update
    token_dispatcher.update_game(token_id);
    let metadata1 = token_dispatcher.token_metadata(token_id);

    // Second update (idempotent)
    token_dispatcher.update_game(token_id);
    let metadata2 = token_dispatcher.token_metadata(token_id);

    // Third update (idempotent)
    token_dispatcher.update_game(token_id);
    let metadata3 = token_dispatcher.token_metadata(token_id);

    // All metadata should be identical
    assert!(metadata1.game_over == metadata2.game_over, "Game over state should be identical");
    assert!(metadata2.game_over == metadata3.game_over, "Game over state should be identical");
    // Score comparison would be on the game contract side
}

// ================================================================================================
// VIEW FUNCTION TESTS
// ================================================================================================

#[test]
fn test_token_metadata_view() { // UT-VIEW-001
    let test_contracts = setup();

    // Set a timestamp so minted_at has a value
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true // soulbound
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);

    // Verify all metadata fields
    assert!(metadata.game_id == 0, "Game ID should be 0 for single game");
    assert!(metadata.minted_at == CURRENT_TIME, "Minted at should be set to current time");
    assert!(metadata.settings_id == 0, "Settings ID should be 0");
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start time mismatch");
    assert!(metadata.lifecycle.end == FUTURE_TIME, "End time mismatch");
    assert!(metadata.soulbound == true, "Should be soulbound");
    assert!(metadata.game_over == false, "Game should not be over");
    assert!(metadata.completed_all_objectives == false, "Objectives should not be completed");
    assert!(metadata.has_context == false, "Should not have context");
    assert!(metadata.objectives_count == 0, "Should have 0 objectives");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_view() { // UT-VIEW-002
    let test_contracts = setup();

    // Test case 1: Token with no lifecycle constraints
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.is_playable(token_id1) == true, "Token should be playable");

    // Test case 2: Token with active lifecycle
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::Some(PAST_TIME),
            Option::Some(FUTURE_TIME),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(
        test_contracts.test_token.is_playable(token_id2) == true,
        "Token should be playable within time window",
    );

    // Test case 3: Token that's game over
    let (_, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_test_token_contract_with_game(
        Option::Some(mock_game.contract_address), Option::None, Option::None,
    );

    let token_id3 = token_dispatcher
        .mint(
            Option::Some(mock_game.contract_address),
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

    mock_game.set_game_over(token_id3, true);
    token_dispatcher.update_game(token_id3);

    assert!(
        token_dispatcher.is_playable(token_id3) == false,
        "Token should not be playable when game over",
    );

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_settings_id_view() { // UT-VIEW-003
    let test_contracts = setup();

    // Test with no settings
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.settings_id(token_id1) == 0, "Settings ID should be 0");
    // Test with settings (would need settings contract setup)
// TODO: Add test with actual settings once settings contract is available
}

#[test]
fn test_player_name_view() { // UT-VIEW-004
    let test_contracts = setup();

    // Test with no player name
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.player_name(token_id1) == "", "Player name should be empty");

    // Test with player name
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::Some("AliceWonderland"),
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

    assert!(
        test_contracts.test_token.player_name(token_id2) == "AliceWonderland",
        "Player name mismatch",
    );
}

#[test]
fn test_objectives_count_view() { // UT-VIEW-005
    let test_contracts = setup();

    // Test with no objectives
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.objectives_count(token_id1) == 0, "Should have 0 objectives");
    // Test with objectives would require objective setup
// TODO: Add test with actual objectives once objective creation is fixed
}

#[test]
fn test_minted_by_view() { // UT-VIEW-006
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
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
        );

    // Should return the minter ID (1 for first minter)
    assert!(test_contracts.test_token.minted_by(token_id) == 1, "Minter ID should be 1");
}

#[test]
fn test_game_address_view() { // UT-VIEW-007
    let test_contracts = setup();

    // Single game token
    let token_id = test_contracts
        .test_token
        .mint(
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
        );

    let game_addr = test_contracts.test_token.game_address();
    assert!(game_addr == test_contracts.minigame.contract_address, "Game address mismatch");
    // Multi-game token would be tested with registry
// TODO: Add multi-game test once registry is set up
}

#[test]
fn test_game_registry_address_view() { // UT-VIEW-008
    let test_contracts = setup_multi_game();

    let registry_addr = test_contracts.test_token.game_registry_address();
    assert!(
        registry_addr == test_contracts.minigame_registry.contract_address,
        "Registry address mismatch",
    );
}

#[test]
fn test_is_soulbound_view() { // UT-VIEW-009
    let test_contracts = setup();

    // Non-soulbound token
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.is_soulbound(token_id1) == false, "Should not be soulbound");

    // Soulbound token
    let token_id2 = test_contracts
        .test_token
        .mint(
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
            true,
        );

    assert!(test_contracts.test_token.is_soulbound(token_id2) == true, "Should be soulbound");
}

#[test]
fn test_renderer_address_view() { // UT-VIEW-010
    let test_contracts = setup();

    // No custom renderer
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(
        test_contracts.test_token.renderer_address(token_id1) == contract_address_const::<0>(),
        "Should have no renderer",
    );

    // With custom renderer
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            ALICE(),
            false,
        );

    assert!(
        test_contracts.test_token.renderer_address(token_id2) == RENDERER_ADDRESS(),
        "Renderer address mismatch",
    );
}

// ================================================================================================
// EXTENSION VIEW FUNCTION TESTS
// ================================================================================================

#[test]
fn test_get_minter_address() { // UT-EXT-001
    let test_contracts = setup();

    // Set ALICE as the caller
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    // Mint a token (this creates minter ID 1)
    test_contracts
        .test_token
        .mint(
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
        );

    // Get minter address for ID 1
    let minter_addr = test_contracts.test_token.get_minter_address(1);
    assert!(minter_addr == ALICE(), "Minter address should be ALICE");

    // Test non-existent minter
    let minter_addr2 = test_contracts.test_token.get_minter_address(999);
    assert!(
        minter_addr2 == contract_address_const::<0>(),
        "Non-existent minter should return zero address",
    );
}

#[test]
fn test_minter_tracking() { // UT-EXT-002
    let test_contracts = setup();

    // Check initial state
    assert!(test_contracts.test_token.total_minters() == 0, "Should have 0 minters initially");
    assert!(
        test_contracts.test_token.minter_exists(ALICE()) == false,
        "ALICE should not be a minter yet",
    );

    // Set ALICE as the caller
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    // Mint from ALICE
    test_contracts
        .test_token
        .mint(
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
        );

    // Check after first mint
    assert!(test_contracts.test_token.total_minters() == 1, "Should have 1 minter");
    assert!(test_contracts.test_token.minter_exists(ALICE()) == true, "ALICE should be a minter");
    assert!(test_contracts.test_token.get_minter_id(ALICE()) == 1, "ALICE should have minter ID 1");

    // Set ALICE as caller again
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    // Mint again from ALICE (should not create new minter)
    test_contracts
        .test_token
        .mint(
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
        );

    assert!(test_contracts.test_token.total_minters() == 1, "Should still have 1 minter");

    // Set BOB as the caller
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );

    // Mint from BOB
    test_contracts
        .test_token
        .mint(
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
        );

    // Check after BOB mints
    assert!(test_contracts.test_token.total_minters() == 2, "Should have 2 minters");
    assert!(test_contracts.test_token.minter_exists(BOB()) == true, "BOB should be a minter");
    assert!(test_contracts.test_token.get_minter_id(BOB()) == 2, "BOB should have minter ID 2");
}

#[test]
fn test_has_custom_renderer() { // UT-EXT-003
    let test_contracts = setup();

    // Token without renderer
    let token_id1 = test_contracts
        .test_token
        .mint(
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
        );

    assert!(
        test_contracts.test_token.has_custom_renderer(token_id1) == false,
        "Should not have custom renderer",
    );
    assert!(
        test_contracts.test_token.get_renderer(token_id1) == contract_address_const::<0>(),
        "Renderer should be zero address",
    );

    // Token with renderer
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            ALICE(),
            false,
        );

    assert!(
        test_contracts.test_token.has_custom_renderer(token_id2) == true,
        "Should have custom renderer",
    );
    assert!(
        test_contracts.test_token.get_renderer(token_id2) == RENDERER_ADDRESS(),
        "Renderer address mismatch",
    );
}

// ================================================================================================
// SET TOKEN METADATA TESTS
// ================================================================================================

#[test]
fn test_set_token_metadata_basic() {
    let test_contracts = setup();

    // First mint a blank token (no game address)
    let token_id = test_contracts
        .test_token
        .mint(
            Option::None, // No game address - creates blank token
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

    // Verify token is blank
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.game_id == 0, "Token should be blank");

    // Set token metadata
    test_contracts
        .test_token
        .set_token_metadata(
            token_id,
            test_contracts.minigame.contract_address,
            Option::Some("Player1"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );

    // Verify metadata was set
    let updated_metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(updated_metadata.game_id == 1, "Game ID should be set");
    assert!(
        test_contracts.test_token.player_name(token_id) == "Player1", "Player name should be set",
    );
}

#[test]
#[should_panic(expected: "Token id 1 not minted")]
fn test_set_token_metadata_nonexistent_token() {
    let test_contracts = setup();

    // Try to set metadata on non-existent token
    test_contracts
        .test_token
        .set_token_metadata(
            1, // Non-existent token
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
}

#[test]
#[should_panic(expected: "Token id 1 not blank")]
fn test_set_token_metadata_already_set() {
    let test_contracts = setup();

    // Mint a token with game address
    let token_id = test_contracts
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

    // Try to set metadata on already set token
    test_contracts
        .test_token
        .set_token_metadata(
            token_id,
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
}

#[test]
fn test_set_token_metadata_with_lifecycle() {
    let test_contracts = setup();

    // Mint blank token
    let token_id = test_contracts
        .test_token
        .mint(
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
        );

    // Set metadata with lifecycle
    test_contracts
        .test_token
        .set_token_metadata(
            token_id,
            test_contracts.minigame.contract_address,
            Option::Some("TimedPlayer"),
            Option::None,
            Option::Some(1000),
            Option::Some(2000),
            Option::None,
            Option::None,
        );

    // Verify lifecycle was set
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == 1000, "Start time should be set");
    assert!(metadata.lifecycle.end == 2000, "End time should be set");
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_set_token_metadata_invalid_lifecycle() {
    let test_contracts = setup();

    // Mint blank token
    let token_id = test_contracts
        .test_token
        .mint(
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
        );

    // Try to set metadata with invalid lifecycle
    test_contracts
        .test_token
        .set_token_metadata(
            token_id,
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(2000), // Start after end
            Option::Some(1000),
            Option::None,
            Option::None,
        );
}

// ================================================================================================
// Run test to verify first test passes
// ================================================================================================

#[cfg(test)]
mod tests {
    use super::*;
}
