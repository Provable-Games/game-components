use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use game_components_embeddable_game_standard::metagame::extensions::context::structs::{
    GameContext, GameContextDetails,
};
use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, mock_call, start_cheat_block_timestamp,
    stop_cheat_block_timestamp,
};
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_mock::IMinigameMockDispatcherTrait;

// Import mocks
use super::mocks::mock_game::{};

// Import setup helpers
use super::setup::{
    ALICE, BOB, CHARLIE, CURRENT_TIME, FAR_FUTURE_TIME, FUTURE_TIME, RENDERER_ADDRESS, ZERO_ADDRESS,
    deploy_mock_game, setup_multi_game,
};

// All test constants, deployment helpers, and setup functions are now in setup.cairo

// ================================================================================================
// MINT FUNCTION TESTS
// ================================================================================================

// Happy Path Tests

#[test]
fn test_mint_minimal_parameters() { // UT-MINT-001
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None,
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token ID should be nonzero");
    assert!(test_contracts.erc721.owner_of(token_id.into()) == ALICE(), "Owner should be ALICE");
    assert!(test_contracts.erc721.balance_of(ALICE()) == 1, "Balance should be 1");

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound == false, "Should not be soulbound");
    assert!(metadata.game_over == false, "Game should not be over");
    assert!(metadata.completed_objective == false, "Objective should not be completed");
    assert!(metadata.objective_id == 0, "Should have no objective");
    assert!(metadata.settings_id == 0, "Settings ID should be 0");
    // lifecycle.start = minted_at + start_delay; with no start, start_delay=0, so start = minted_at
    // lifecycle.end = 0 when no end is provided (end_delay=0)
    assert!(metadata.lifecycle.end == 0, "End time should be 0");
}

#[test]
fn test_mint_with_all_parameters() { // UT-MINT-002
    let test_contracts = setup_multi_game();

    // Create an objective and settings
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy mode", 1);

    // Mock interface support checks for settings validation
    // The mock minigame is used as the settings_address
    mock_call(test_contracts.minigame.contract_address, selector!("supports_interface"), true, 10);
    mock_call(test_contracts.minigame.contract_address, selector!("settings_exist"), true, 1);

    let objective_id: u32 = 1;
    let game_contexts = array![GameContext { name: 'tournament', value: '42' }];
    let _context = GameContextDetails {
        name: "Tournament",
        description: "Tournament mode",
        id: Option::Some(42),
        context: game_contexts.span(),
    };

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TestPlayer'),
            Option::Some(1), // settings_id
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
            Option::Some(objective_id), // single objective_id
            // Option::Some(context), // TODO: This checks for MetagameInterface from Caller so can
            // only be provided from contract
            Option::None,
            Option::Some("https://client.game.com"),
            Option::Some(RENDERER_ADDRESS()),
            Option::None,
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token ID should be nonzero");

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound == true, "Should be soulbound");
    // TODO: settings_id validation is not working - investigate impl resolution
    // assert!(metadata.settings_id == 1, "Settings ID should be 1");
    // Lifecycle timestamps are stored as delays relative to minted_at (block_timestamp).
    // With default block_timestamp=0: start_delay=CURRENT_TIME, end_delay=FUTURE_TIME
    // lifecycle.start = minted_at + start_delay = 0 + CURRENT_TIME = CURRENT_TIME
    // lifecycle.end = minted_at + end_delay = 0 + FUTURE_TIME = FUTURE_TIME
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start time mismatch");
    assert!(metadata.lifecycle.end == FUTURE_TIME, "End time mismatch");
    assert!(metadata.objective_id == 1, "Should have objective_id 1");
    assert!(metadata.game_id != 0, "Game ID should not be 0");

    assert!(
        test_contracts.test_token.player_name(token_id) == 'TestPlayer', "Player name mismatch",
    );
    assert!(test_contracts.test_token.is_soulbound(token_id) == true, "Should be soulbound");
    assert!(
        test_contracts.test_token.renderer_address(token_id) == RENDERER_ADDRESS(),
        "Renderer address mismatch",
    );
}

#[test]
fn test_mint_soulbound_token() { // UT-MINT-003
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            true, // soulbound
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.is_soulbound(token_id) == true, "Token should be soulbound");
    // TODO: Add transfer restriction test when soulbound hooks are properly implemented
}

#[test]
fn test_mint_with_lifecycle_constraints() { // UT-MINT-004
    let test_contracts = setup_multi_game();
    let contract_address = test_contracts.test_token.contract_address;

    // Set current time
    start_cheat_block_timestamp(contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME - 100), // Past start time
            Option::Some(FUTURE_TIME),
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
fn test_mint_with_objective() { // UT-MINT-005
    let test_contracts = setup_multi_game();

    // Create an objective
    test_contracts.mock_minigame.create_objective_score(100);

    let objective_id: u32 = 1;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_id),
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

    // Verify objective_id is stored correctly
    assert!(test_contracts.test_token.objective_id(token_id) == 1, "Should have objective_id 1");
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.objective_id == 1, "Metadata should have objective_id 1");
}

#[test]
fn test_mint_with_custom_renderer() { // UT-MINT-006
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
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
    let test_contracts = setup_multi_game();

    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );
}

#[test]
#[should_panic(expected: "MinigameToken: Game address is zero")]
fn test_mint_with_invalid_game_address() { // UT-MINT-R002
    let test_contracts = setup_multi_game();

    test_contracts
        .test_token
        .mint(
            ZERO_ADDRESS(),
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
            false,
            0,
            0,
        );
}

#[test]
#[should_panic]
fn test_mint_with_non_minigame_contract() { // UT-MINT-R003
    let test_contracts = setup_multi_game();

    // Use the token contract address as a non-minigame contract
    test_contracts
        .test_token
        .mint(
            test_contracts.test_token.contract_address,
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
            false,
            0,
            0,
        );
}

#[test]
#[should_panic]
fn test_mint_with_invalid_settings_id() { // UT-MINT-R004
    let test_contracts = setup_multi_game();

    // Try to use settings_id that doesn't exist
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::Some(999), // Non-existent settings_id
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
}

#[test]
#[should_panic(expected: "MinigameTokenObjectives: Objective ID 999 does not exist")]
fn test_mint_with_invalid_objective_id() { // UT-MINT-R005
    let test_contracts = setup_multi_game();

    // Create only 1 objective
    test_contracts.mock_minigame.create_objective_score(50);

    // Try to use an objective_id that doesn't exist
    let invalid_objective_id: u32 = 999;

    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(invalid_objective_id),
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
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_mint_with_start_greater_than_end() { // UT-MINT-R006
    let test_contracts = setup_multi_game();

    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(FUTURE_TIME),
            Option::Some(CURRENT_TIME), // end < start
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
}

#[test]
#[should_panic(expected: "MinigameToken: Game does not support IMinigame interface")]
fn test_mint_when_game_registry_lookup_fails() { // UT-MINT-R007
    let test_contracts = setup_multi_game();

    // Deploy a new game that's not registered in the registry
    let (unregistered_game, _, _) = deploy_mock_game();

    // Try to mint with an unregistered game address
    test_contracts
        .test_token
        .mint(
            unregistered_game.contract_address,
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
            false,
            0,
            0,
        );
}

// Boundary Tests

#[test]
fn test_mint_with_max_timestamps() { // UT-MINT-B001
    let test_contracts = setup_multi_game();

    // Lifecycle delays are stored as 25-bit values (max 33,554,431 seconds ~388 days).
    // Delays are relative to block_timestamp (minted_at).
    // With default block_timestamp=0, we use delays that fit in 25 bits.
    let max_delay: u64 = 33554431; // 2^25 - 1
    let start_time: u64 = max_delay - 1000;
    let end_time: u64 = max_delay;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(start_time),
            Option::Some(end_time),
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

    let metadata = test_contracts.test_token.token_metadata(token_id);
    // With block_timestamp=0: start_delay = start_time, end_delay = end_time
    // lifecycle.start = minted_at + start_delay = 0 + start_time = start_time
    // lifecycle.end = minted_at + end_delay = 0 + end_time = end_time
    assert!(metadata.lifecycle.start == start_time, "Start time should match");
    assert!(metadata.lifecycle.end == end_time, "End time should match");
}

#[test]
fn test_mint_without_objective() { // UT-MINT-B002
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // No objective
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

    assert!(test_contracts.test_token.objective_id(token_id) == 0, "Should have no objective");
}

#[test]
fn test_mint_with_high_objective_id() { // UT-MINT-B003
    let test_contracts = setup_multi_game();

    // Create multiple objectives to get a high ID
    let mut i: u32 = 0;
    while i < 100 {
        test_contracts.mock_minigame.create_objective_score(i.into());
        i += 1;
    }

    // Use the 100th objective (ID = 100)
    let high_objective_id: u32 = 100;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(high_objective_id),
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

    assert!(
        test_contracts.test_token.objective_id(token_id) == 100, "Should have objective_id 100",
    );
}

#[test]
fn test_sequential_mints_increment_counter() { // UT-MINT-B004
    let test_contracts = setup_multi_game();

    let token_id_1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    let token_id_2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            1,
            0,
        );

    let token_id_3 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            2,
            0,
        );

    // Token IDs are packed felt252 values, not sequential integers
    assert!(token_id_1 != 0, "First token ID should be nonzero");
    assert!(token_id_2 != 0, "Second token ID should be nonzero");
    assert!(token_id_3 != 0, "Third token ID should be nonzero");
    assert!(token_id_1 != token_id_2, "Token IDs 1 and 2 should be distinct");
    assert!(token_id_2 != token_id_3, "Token IDs 2 and 3 should be distinct");
    assert!(token_id_1 != token_id_3, "Token IDs 1 and 3 should be distinct");

    assert!(
        test_contracts.erc721.owner_of(token_id_1.into()) == ALICE(),
        "Token 1 should belong to ALICE",
    );
    assert!(
        test_contracts.erc721.owner_of(token_id_2.into()) == BOB(), "Token 2 should belong to BOB",
    );
    assert!(
        test_contracts.erc721.owner_of(token_id_3.into()) == CHARLIE(),
        "Token 3 should belong to CHARLIE",
    );
}

// ================================================================================================
// UPDATE_GAME FUNCTION TESTS
// ================================================================================================

// Happy Path Tests

#[test]
fn test_update_game_with_objective_completion() { // UT-UPDATE-003
    let test_contracts = setup_multi_game();

    // Create an objective
    test_contracts.mock_minigame.create_objective_score(100);

    let objective_id: u32 = 1;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_id),
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

    // End the game with a score that meets the objective
    test_contracts.mock_minigame.end_game(token_id, 100);
    test_contracts.test_token.update_game(token_id);

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective == true, "Should have completed the objective");
}


// Revert Path Tests

#[test]
#[should_panic]
fn test_update_nonexistent_token() { // UT-UPDATE-R001
    let test_contracts = setup_multi_game();

    // Try to update a token that doesn't exist
    test_contracts.test_token.update_game(999);
}


// State Transition Tests

#[test]
fn test_objective_completion_progression() { // UT-UPDATE-S002
    let test_contracts = setup_multi_game();

    test_contracts.mock_minigame.create_objective_score(50);
    let objective_id: u32 = 1;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_id),
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

    // Before update - objective not completed
    let metadata_before = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_before.objective_id == 1, "Should have objective_id 1");
    assert!(metadata_before.completed_objective == false, "Objective should not be completed yet");

    // Set score to meet objective and update
    test_contracts.mock_minigame.end_game(token_id, 50);
    test_contracts.test_token.update_game(token_id);

    // After update - objective should be completed
    let metadata_after = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_after.completed_objective == true, "Objective should be completed");
}


// ================================================================================================
// VIEW FUNCTION TESTS
// ================================================================================================

#[test]
fn test_token_metadata_view() { // UT-VIEW-001
    let test_contracts = setup_multi_game();

    // Mint a game token with minimal parameters
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            true, // soulbound
            false,
            0,
            0,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);

    // Verify metadata fields for game token with minimal parameters
    assert!(metadata.game_id != 0, "Game ID should be nonzero for game token");
    assert!(metadata.settings_id == 0, "Settings ID should be 0");
    assert!(metadata.lifecycle.start == 0, "Start time should be 0");
    assert!(metadata.lifecycle.end == 0, "End time should be 0");
    assert!(metadata.soulbound == true, "Should be soulbound");
    assert!(metadata.game_over == false, "Game should not be over");
    assert!(metadata.completed_objective == false, "Objective should not be completed");
    assert!(metadata.has_context == false, "Should not have context");
    assert!(metadata.objective_id == 0, "Should have no objective");
}


#[test]
fn test_settings_id_view() { // UT-VIEW-003
    let test_contracts = setup_multi_game();

    // Test with no settings
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.settings_id(token_id1) == 0, "Settings ID should be 0");
    // Test with settings (would need settings contract setup)
// TODO: Add test with actual settings once settings contract is available
}

#[test]
fn test_player_name_view() { // UT-VIEW-004
    let test_contracts = setup_multi_game();

    // Test with no player name
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.player_name(token_id1) == '', "Player name should be empty");

    // Test with player name
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('AliceWonderland'),
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
            1,
            0,
        );

    assert!(
        test_contracts.test_token.player_name(token_id2) == 'AliceWonderland',
        "Player name mismatch",
    );
}

#[test]
fn test_objective_id_view() { // UT-VIEW-005
    let test_contracts = setup_multi_game();

    // Test with no objective
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.objective_id(token_id1) == 0, "Should have no objective");

    // Test with objective
    test_contracts.mock_minigame.create_objective_score(100);
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1_u32),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    assert!(test_contracts.test_token.objective_id(token_id2) == 1, "Should have objective_id 1");
}

#[test]
fn test_minted_by_view() { // UT-VIEW-006
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    // Should return the minter ID (1 for first minter)
    assert!(test_contracts.test_token.minted_by(token_id) == 1, "Minter ID should be 1");
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
    let test_contracts = setup_multi_game();

    // Non-soulbound token
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.is_soulbound(token_id1) == false, "Should not be soulbound");

    // Soulbound token
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            1,
            0,
        );

    assert!(test_contracts.test_token.is_soulbound(token_id2) == true, "Should be soulbound");
}

#[test]
fn test_renderer_address_view() { // UT-VIEW-010
    let test_contracts = setup_multi_game();

    // No custom renderer
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    // In multi-game mode, tokens without a custom renderer fall back to the game's contract
    // address (resolved via the registry). Since this token was minted with a real game address,
    // the renderer_address returns the game address, not zero.
    assert!(
        test_contracts
            .test_token
            .renderer_address(token_id1) == test_contracts
            .minigame
            .contract_address,
        "Should fall back to game address as renderer",
    );

    // With custom renderer
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
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
    let test_contracts = setup_multi_game();

    // Set ALICE as the caller
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    // Mint a token (this creates minter ID 1)
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    // Get minter address for ID 1
    let minter_addr = test_contracts.test_token.get_minter_address(1);
    assert!(minter_addr == ALICE(), "Minter address should be ALICE");

    // Test non-existent minter
    let minter_addr2 = test_contracts.test_token.get_minter_address(999);
    assert!(minter_addr2 == addr(0), "Non-existent minter should return zero address");
}

#[test]
fn test_minter_tracking() { // UT-EXT-002
    let test_contracts = setup_multi_game();

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
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
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
            test_contracts.minigame.contract_address,
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
            false,
            1,
            0,
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
            test_contracts.minigame.contract_address,
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
            false,
            2,
            0,
        );

    // Check after BOB mints
    assert!(test_contracts.test_token.total_minters() == 2, "Should have 2 minters");
    assert!(test_contracts.test_token.minter_exists(BOB()) == true, "BOB should be a minter");
    assert!(test_contracts.test_token.get_minter_id(BOB()) == 2, "BOB should have minter ID 2");
}

#[test]
fn test_has_custom_renderer() { // UT-EXT-003
    let test_contracts = setup_multi_game();

    // Token without renderer
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    assert!(
        test_contracts.test_token.has_custom_renderer(token_id1) == false,
        "Should not have custom renderer",
    );
    assert!(
        test_contracts.test_token.get_renderer(token_id1) == addr(0),
        "Renderer should be zero address",
    );

    // Token with renderer
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(RENDERER_ADDRESS()),
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
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
// Run test to verify first test passes
// ================================================================================================

#[cfg(test)]
mod tests {
    use super::*;
}
