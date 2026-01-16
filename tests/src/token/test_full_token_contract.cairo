use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use game_components_metagame::extensions::context::structs::{GameContext, GameContextDetails};
use game_components_tests::minigame::mocks::minigame_starknet_mock::IMinigameStarknetMockDispatcherTrait;
use game_components_token::interface::IMinigameTokenMixinDispatcherTrait;
use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};

// Import mocks
use super::mocks::mock_game::{};

// Import setup helpers
use super::setup::{
    ALICE, BOB, CHARLIE, CURRENT_TIME, FAR_FUTURE_TIME, FUTURE_TIME, MAX_U64, RENDERER_ADDRESS,
    ZERO_ADDRESS, deploy_mock_game, setup_multi_game,
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
            Option::None, // game_address - will use default
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
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
    assert!(metadata.completed_objective == false, "Objective should not be completed");
    assert!(metadata.objective_id == 0, "Should have no objective");
    assert!(metadata.settings_id == 0, "Settings ID should be 0");
    assert!(metadata.lifecycle.start == 0, "Start time should be 0");
    assert!(metadata.lifecycle.end == 0, "End time should be 0");
}

#[test]
// #[ignore] // TODO: Fix ENTRYPOINT_NOT_FOUND error with objectives/settings
fn test_mint_with_all_parameters() { // UT-MINT-002
    let test_contracts = setup_multi_game();

    // Create an objective and settings
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy mode", 1);

    let objective_id: u32 = 1;
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
            ALICE(),
            true // soulbound
        );

    assert!(token_id == 1, "Token ID should be 1");

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound == true, "Should be soulbound");
    assert!(metadata.settings_id == 1, "Settings ID should be 1");
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
    let test_contracts = setup_multi_game();
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
fn test_mint_with_objective() { // UT-MINT-005
    let test_contracts = setup_multi_game();

    // Create an objective
    test_contracts.mock_minigame.create_objective_score(100);

    let objective_id: u32 = 1;

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
    let test_contracts = setup_multi_game();

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
#[should_panic(expected: "MinigameToken: Game address is zero")]
fn test_mint_with_invalid_game_address() { // UT-MINT-R002
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
fn test_mint_with_invalid_objective_id() { // UT-MINT-R005
    let test_contracts = setup_multi_game();

    // Create only 1 objective
    test_contracts.mock_minigame.create_objective_score(50);

    // Try to use an objective_id that doesn't exist
    let invalid_objective_id: u32 = 999;

    test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(invalid_objective_id),
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
    let test_contracts = setup_multi_game();

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
#[should_panic(expected: "MinigameToken: Game does not support IMinigame interface")]
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
    let test_contracts = setup_multi_game();

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
fn test_mint_without_objective() { // UT-MINT-B002
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // No objective
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(test_contracts.test_token.objective_id(token_id) == 0, "Should have no objective");
}

#[test]
fn test_mint_with_high_objective_id() { // UT-MINT-B003
    let test_contracts = setup_multi_game();

    // Create multiple objectives to get a high ID
    let mut i: u32 = 0;
    while i < 100 {
        test_contracts.mock_minigame.create_objective_score(i);
        i += 1;
    }

    // Use the 100th objective (ID = 100)
    let high_objective_id: u32 = 100;

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(high_objective_id),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
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
fn test_update_game_with_objective_completion() { // UT-UPDATE-003
    let test_contracts = setup_multi_game();

    // Create an objective
    test_contracts.mock_minigame.create_objective_score(100);

    let objective_id: u32 = 1;

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
            Option::Some(test_contracts.minigame.contract_address),
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
    assert!(metadata.completed_objective == false, "Objective should not be completed");
    assert!(metadata.has_context == false, "Should not have context");
    assert!(metadata.objective_id == 0, "Should have no objective");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}


#[test]
fn test_settings_id_view() { // UT-VIEW-003
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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

    assert!(test_contracts.test_token.player_name(token_id1) == '', "Player name should be empty");

    // Test with player name
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::None,
            Option::Some('AliceWonderland'),
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

    assert!(test_contracts.test_token.objective_id(token_id1) == 0, "Should have no objective");

    // Test with objective
    test_contracts.mock_minigame.create_objective_score(100);
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1_u32),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    assert!(test_contracts.test_token.objective_id(token_id2) == 1, "Should have objective_id 1");
}

#[test]
fn test_minted_by_view() { // UT-VIEW-006
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
        test_contracts.test_token.renderer_address(token_id1) == addr(0), "Should have no renderer",
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
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
        test_contracts.test_token.get_renderer(token_id1) == addr(0),
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
    let test_contracts = setup_multi_game();

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
            Option::Some('Player1'),
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
        test_contracts.test_token.player_name(token_id) == 'Player1', "Player name should be set",
    );
}

#[test]
#[should_panic(expected: "Token id 1 not minted")]
fn test_set_token_metadata_nonexistent_token() {
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
    let test_contracts = setup_multi_game();

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
            Option::Some('TimedPlayer'),
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
    let test_contracts = setup_multi_game();

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
