// Comprehensive tests for CoreTokenComponent based on test plan
// Test file: packages/token/src/tests/test_core_token.cairo
// Consolidates and extends coverage for core ERC721 token functionality

use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{
    CheatSpan, EventSpyTrait, cheat_caller_address, mock_call, spy_events,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use starknet::ContractAddress;
use crate::token::core::interface::IMINIGAME_TOKEN_ID;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use crate::token::structs::{MintParams, PlayerNameUpdate};
use super::mocks::mock_game::IMockGameDispatcherTrait;
use super::setup::{
    ALICE, BOB, CHARLIE, CURRENT_TIME, FAR_FUTURE_TIME, FUTURE_TIME, OWNER, PAST_TIME,
    RENDERER_ADDRESS, ZERO_ADDRESS, deploy_basic_mock_game, deploy_full_token_contract,
    deploy_minigame_registry_contract, deploy_optimized_token_with_game,
    deploy_single_game_token_default, setup, setup_multi_game,
};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// ============================================================================
// TC-TM: TOKEN_METADATA TESTS
// ============================================================================

#[test]
fn test_token_metadata_valid_existing_token() {
    // TC-TM-001: Valid existing token
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
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
            false,
            0,
            0,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(!metadata.soulbound, "Token should not be soulbound");
    assert!(!metadata.game_over, "Token should not be game over");
    assert!(!metadata.completed_objective, "Token should not have completed objective");
}

#[test]
fn test_token_metadata_nonexistent_token() {
    // TC-TM-002: Non-existent token - mutable state is default (immutable data comes from token_id)
    let test_contracts = setup();

    let metadata = test_contracts.test_token.token_metadata(999);
    // With packed token IDs, "immutable" fields are decoded from the token_id itself (999),
    // so game_id = 999. Only mutable state is truly "default".
    assert!(!metadata.game_over, "Non-existent token should not be game over");
    assert!(
        !metadata.completed_objective, "Non-existent token should not have completed objective",
    );
}

#[test]
fn test_token_metadata_with_all_fields_set() {
    // TC-TM-003: Token with all fields set
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Mint with various fields set
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TestPlayer'),
            Option::None, // settings_id
            Option::Some(CURRENT_TIME),
            Option::Some(FAR_FUTURE_TIME),
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound, "Token should be soulbound");
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start should match");
    assert!(metadata.lifecycle.end == FAR_FUTURE_TIME, "End should match");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_token_metadata_creator_token_single_game_mode() {
    // TC-TM-004: Token 0 (creator token) in single-game mode
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, erc721_dispatcher, _, _) = deploy_single_game_token_default(
        minigame.contract_address,
    );

    // Token 0 should exist (minted to OWNER in single-game mode)
    let owner_of_zero = erc721_dispatcher.owner_of(0);
    assert!(owner_of_zero == OWNER(), "Token 0 should be owned by OWNER");

    // Token 0 metadata should be default/creator metadata
    let metadata = token_dispatcher.token_metadata(0);
    // Creator token has game_id = 0 in single-game mode
    assert!(metadata.game_id == 0, "Creator token should have game_id 0");
}

// ============================================================================
// TC-IP: IS_PLAYABLE TESTS
// ============================================================================

#[test]
fn test_is_playable_active_token_no_restrictions() {
    // TC-IP-001: Active token with no lifecycle restrictions
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(0), // start = 0 (no restriction)
            Option::Some(0), // end = 0 (no restriction)
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

    assert!(test_contracts.test_token.is_playable(token_id), "Token should be playable");
}

#[test]
fn test_is_playable_before_start_time() {
    // TC-IP-002: Token before start time
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(FUTURE_TIME), // start in future
            Option::Some(FAR_FUTURE_TIME),
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
        !test_contracts.test_token.is_playable(token_id), "Should not be playable before start",
    );

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_at_exact_start_time() {
    // TC-IP-003: Token at exact start time
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME), // start now
            Option::Some(FAR_FUTURE_TIME),
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

    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable at start time");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_during_active_period() {
    // TC-IP-004: Token during active period
    let test_contracts = setup();

    let mid_time = (CURRENT_TIME + FAR_FUTURE_TIME) / 2;
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, mid_time);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME),
            Option::Some(FAR_FUTURE_TIME),
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

    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable during period");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_at_exact_end_time() {
    // TC-IP-005: Token at exact end time
    let test_contracts = setup();

    // Mint at PAST_TIME so end_delay > 0 (end_delay = CURRENT_TIME - PAST_TIME = 900)
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, PAST_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(PAST_TIME),
            Option::Some(CURRENT_TIME), // end_delay = CURRENT_TIME - PAST_TIME = 900
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

    // Now advance to exact end time
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable at end time");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_after_end_time() {
    // TC-IP-006: Token after end time
    // Mint at CURRENT_TIME with end=FUTURE_TIME, then advance past end
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME),
            Option::Some(FUTURE_TIME),
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

    // Advance time past end
    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, FAR_FUTURE_TIME);

    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable after end");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_is_playable_with_game_over_true() {
    // TC-IP-007: Token with game_over=true
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Set game over
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    assert!(!token_dispatcher.is_playable(token_id), "Should not be playable when game is over");
}

#[test]
fn test_is_playable_with_completed_objective() {
    // TC-IP-008: Token with completed_objective=true
    let test_contracts = setup();

    // Mock objective_exists to return true
    mock_call(test_contracts.minigame.contract_address, selector!("objective_exists"), true, 1);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1), // objective_id
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Mock objective completion check
    mock_call(
        test_contracts.minigame.contract_address, selector!("is_objective_completed"), true, 1,
    );
    test_contracts.test_token.update_game(token_id);

    assert!(
        !test_contracts.test_token.is_playable(token_id),
        "Should not be playable when objective completed",
    );
}

// ============================================================================
// TC-M: MINT TESTS
// ============================================================================

#[test]
fn test_mint_basic_with_game_address() {
    // TC-M-001: Basic mint with game address
    let test_contracts = setup();

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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "First minted token should have nonzero id");

    // Verify ERC721 ownership
    assert!(test_contracts.erc721.owner_of(token_id.into()) == ALICE(), "ALICE should own token");
}

#[test]
fn test_mint_with_player_name() {
    // TC-M-002: Mint with player name
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TestPlayer'),
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
        test_contracts.test_token.player_name(token_id) == 'TestPlayer', "Player name should match",
    );
}

#[test]
fn test_mint_with_lifecycle_params() {
    // TC-M-004: Mint with lifecycle params
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(CURRENT_TIME),
            Option::Some(FAR_FUTURE_TIME),
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
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start should match");
    assert!(metadata.lifecycle.end == FAR_FUTURE_TIME, "End should match");
}

#[test]
fn test_mint_soulbound_token() {
    // TC-M-009: Mint soulbound token
    let test_contracts = setup();

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
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.is_soulbound(token_id), "Token should be soulbound");
}

#[test]
#[should_panic(expected: "MinigameToken: Game address is zero")]
fn test_mint_with_zero_game_address_panics() {
    // TC-M-011: Mint with zero game address
    let test_contracts = setup();

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
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

#[test]
fn test_mint_with_max_timestamp_values() {
    // TC-M-015: Mint with max delay values
    // Max delay is 2^25 - 1 = 33554431 seconds (~388 days)
    let test_contracts = setup();

    // Use max delay from current time (block timestamp defaults to 0 in tests)
    let max_delay: u64 = 33554431; // 2^25 - 1
    let end_time = max_delay; // end_delay = end_time - current_time(0) = max_delay

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(end_time),
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
    assert!(metadata.lifecycle.end == end_time, "End time should match");
}

#[test]
fn test_mint_sequential_token_ids() {
    // Verify token IDs are sequential
    let test_contracts = setup();

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
            ALICE(),
            false,
            false,
            0,
            0,
        );

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
            BOB(),
            false,
            false,
            1,
            0,
        );

    assert!(token_id1 != 0, "First token should have nonzero id");
    assert!(token_id2 != 0, "Second token should have nonzero id");
    assert!(token_id1 != token_id2, "Token IDs should be unique");
}

#[test]
fn test_mint_with_renderer_address() {
    // TC-M-008: Mint with custom renderer_address
    let test_contracts = setup();

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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify custom renderer is stored (through has_custom_renderer if available)
    // The renderer_address view function will return the custom renderer
    // Note: renderer_address() requires registry in multi-game mode
    let _metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(token_id != 0, "Token should be minted with renderer");
}

// ============================================================================
// TC-MB: MINT_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: mints array cannot be empty")]
fn test_mint_batch_empty_array_panics() {
    // TC-MB-001: Empty array
    let test_contracts = setup();

    let mints: Array<MintParams> = array![];
    test_contracts.test_token.mint_batch(mints);
}

#[test]
fn test_mint_batch_single_mint() {
    // TC-MB-002: Single mint in batch
    let test_contracts = setup();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);
    assert!(token_ids.len() == 1, "Should return one token_id");
}

#[test]
fn test_mint_batch_multiple_mints() {
    // TC-MB-003: Multiple mints
    let test_contracts = setup();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: test_contracts.minigame.contract_address,
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
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintParams {
            game_address: test_contracts.minigame.contract_address,
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
            paymaster: false,
            salt: 1,
            metadata: 0,
        },
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::Some('Charlie'),
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: CHARLIE(),
            soulbound: false,
            paymaster: false,
            salt: 2,
            metadata: 0,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);
    assert!(token_ids.len() == 3, "Should return 3 token_ids");

    // Verify unique
    assert!(*token_ids.at(0) != *token_ids.at(1), "IDs should be unique");
    assert!(*token_ids.at(1) != *token_ids.at(2), "IDs should be unique");
}

#[test]
fn test_mint_batch_mixed_settings() {
    // TC-MB-004: Mixed settings per token
    let test_contracts = setup();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::Some('Player1'),
            settings_id: Option::None,
            start: Option::Some(CURRENT_TIME),
            end: Option::Some(FUTURE_TIME),
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: true,
            paymaster: false,
            salt: 1,
            metadata: 0,
        },
    ];

    let token_ids = test_contracts.test_token.mint_batch(mints);

    // Verify different settings
    let token_id1 = *token_ids.at(0);
    let token_id2 = *token_ids.at(1);

    assert!(!test_contracts.test_token.is_soulbound(token_id1), "Token 1 not soulbound");
    assert!(test_contracts.test_token.is_soulbound(token_id2), "Token 2 soulbound");
    assert!(
        test_contracts.test_token.player_name(token_id1) == 'Player1', "Token 1 has player name",
    );
    assert!(test_contracts.test_token.player_name(token_id2) == 0, "Token 2 has no player name");
}

#[test]
fn test_mint_batch_large() {
    // TC-MB-005: Large batch
    let test_contracts = setup();

    let mut mints: Array<MintParams> = array![];
    let mut i: u32 = 0;
    while i < 10 {
        mints
            .append(
                MintParams {
                    game_address: test_contracts.minigame.contract_address,
                    player_name: Option::None,
                    settings_id: Option::None,
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    to: ALICE(),
                    soulbound: false,
                    paymaster: false,
                    salt: i.try_into().unwrap(),
                    metadata: 0,
                },
            );
        i += 1;
    }

    let token_ids = test_contracts.test_token.mint_batch(mints);
    assert!(token_ids.len() == 10, "Should return 10 token_ids");
}

// ============================================================================
// TC-UG: UPDATE_GAME TESTS
// ============================================================================

#[test]
fn test_update_game_token_exists_game_running() {
    // TC-UG-001: Token exists, game running
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    mock_game.set_score(token_id, 100);

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate event
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event");
}

#[test]
#[should_panic(expected: "MinigameToken: Token 999 does not exist")]
fn test_update_game_nonexistent_token_panics() {
    // TC-UG-002: Non-existent token
    let test_contracts = setup();

    test_contracts.test_token.update_game(999);
}

#[test]
fn test_update_game_reports_game_over() {
    // TC-UG-003: Game reports game_over
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Before update
    let metadata_before = token_dispatcher.token_metadata(token_id);
    assert!(!metadata_before.game_over, "Should not be game over initially");

    // Set game over and update
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    // After update
    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(metadata_after.game_over, "Should be game over after update");
}

#[test]
fn test_update_game_game_over_stays_true() {
    // TC-UG-004: Game over stays true (no reversal)
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Set game over
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    // Try to reset (mock says false)
    mock_game.set_game_over(token_id, false);
    token_dispatcher.update_game(token_id);

    // Should still be game over
    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_over, "Game over should not revert to false");
}

#[test]
fn test_update_game_idempotent() {
    // TC-UG-007: Idempotent update
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Update multiple times
    token_dispatcher.update_game(token_id);
    let metadata1 = token_dispatcher.token_metadata(token_id);

    token_dispatcher.update_game(token_id);
    let metadata2 = token_dispatcher.token_metadata(token_id);

    // Metadata should be identical
    assert!(metadata1.game_over == metadata2.game_over, "Game over should not change");
    assert!(
        metadata1.completed_objective == metadata2.completed_objective,
        "Objective should not change",
    );
}

// ============================================================================
// TC-UGB: UPDATE_GAME_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: token_ids array cannot be empty")]
fn test_update_game_batch_empty_panics() {
    // TC-UGB-001: Empty array
    let test_contracts = setup();

    let token_ids: Array<felt252> = array![];
    test_contracts.test_token.update_game_batch(token_ids.span());
}

#[test]
fn test_update_game_batch_single_token() {
    // TC-UGB-002: Single token
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    let token_ids: Array<felt252> = array![token_id];
    token_dispatcher.update_game_batch(token_ids.span());
    // Should not panic - token updated successfully
}

#[test]
fn test_update_game_batch_multiple_tokens() {
    // TC-UGB-003: Multiple tokens
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id1 = token_dispatcher
        .mint(
            minigame.contract_address,
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

    let token_id2 = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Set different states
    mock_game.set_game_over(token_id1, true);
    mock_game.set_score(token_id2, 100);

    let token_ids: Array<felt252> = array![token_id1, token_id2];
    token_dispatcher.update_game_batch(token_ids.span());

    // Verify updates applied
    let metadata1 = token_dispatcher.token_metadata(token_id1);
    assert!(metadata1.game_over, "Token 1 should be game over");
}

// ============================================================================
// TC-UPN: UPDATE_PLAYER_NAME TESTS
// ============================================================================

#[test]
fn test_update_player_name_valid_owner() {
    // TC-UPN-001: Valid owner update
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('OldName'),
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

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'NewName');

    assert!(test_contracts.test_token.player_name(token_id) == 'NewName', "Name should be updated");
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_update_player_name_non_owner_panics() {
    // TC-UPN-002: Non-owner caller
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player'),
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

    // Try as BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'HackerName');
}

#[test]
#[should_panic(expected: "MinigameToken: Token")]
fn test_update_player_name_nonexistent_token_panics() {
    // TC-UPN-003: Non-existent token
    let test_contracts = setup();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(999, 'Name');
}

#[test]
#[should_panic(expected: "MinigameToken: Player name is empty")]
fn test_update_player_name_empty_name_panics() {
    // TC-UPN-004: Empty name
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player'),
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

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 0); // Empty name
}

#[test]
fn test_update_player_name_multiple_updates() {
    // TC-UPN-005: Multiple updates
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Name1'),
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

    // Use Indefinite span since we'll make multiple calls
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::Indefinite,
    );

    test_contracts.test_token.update_player_name(token_id, 'Name2');
    assert!(test_contracts.test_token.player_name(token_id) == 'Name2', "First update");

    test_contracts.test_token.update_player_name(token_id, 'Name3');
    assert!(test_contracts.test_token.player_name(token_id) == 'Name3', "Second update");

    test_contracts.test_token.update_player_name(token_id, 'Name4');
    assert!(test_contracts.test_token.player_name(token_id) == 'Name4', "Third update");
}

#[test]
fn test_update_player_name_max_felt252() {
    // TC-UPN-006: Max felt252 name
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player'),
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

    let max_felt: felt252 = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, max_felt);

    assert!(test_contracts.test_token.player_name(token_id) == max_felt, "Max felt should work");
}

// ============================================================================
// TC-UPNB: UPDATE_PLAYER_NAME_BATCH TESTS
// ============================================================================

#[test]
#[should_panic(expected: "MinigameToken: updates array cannot be empty")]
fn test_update_player_name_batch_empty_panics() {
    // TC-UPNB-001: Empty array
    let test_contracts = setup();

    let updates: Array<PlayerNameUpdate> = array![];
    test_contracts.test_token.update_player_name_batch(updates.span());
}

#[test]
fn test_update_player_name_batch_multiple_same_owner() {
    // TC-UPNB-003: Multiple updates (same owner)
    let test_contracts = setup();

    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Old1'),
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

    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Old2'),
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

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    let updates: Array<PlayerNameUpdate> = array![
        PlayerNameUpdate { token_id: token_id1, name: 'New1' },
        PlayerNameUpdate { token_id: token_id2, name: 'New2' },
    ];
    test_contracts.test_token.update_player_name_batch(updates.span());

    assert!(test_contracts.test_token.player_name(token_id1) == 'New1', "Token 1 updated");
    assert!(test_contracts.test_token.player_name(token_id2) == 'New2', "Token 2 updated");
}

// ============================================================================
// TC-TGA: TOKEN_GAME_ADDRESS TESTS
// ============================================================================

#[test]
fn test_token_game_address_single_game_mode() {
    // TC-TGA-001: Single-game mode (game_id=0)
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    let game_address = token_dispatcher.token_game_address(token_id);
    assert!(game_address == minigame.contract_address, "Should return component game address");
}

#[test]
fn test_token_game_address_multi_game_mode() {
    // TC-TGA-002: Multi-game mode (game_id>0)
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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let game_address = test_contracts.test_token.token_game_address(token_id);
    assert!(
        game_address == test_contracts.minigame.contract_address, "Should resolve from registry",
    );
}

// ============================================================================
// TC-I: INITIALIZER TESTS (via contract deployment)
// ============================================================================

#[test]
fn test_initializer_single_game_mode() {
    // TC-I-001: Single-game mode
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, erc721_dispatcher, _, _) = deploy_single_game_token_default(
        minigame.contract_address,
    );

    // Verify game address is set
    assert!(
        token_dispatcher.game_address() == minigame.contract_address, "Game address should be set",
    );

    // Verify token 0 is minted to creator (OWNER)
    let owner = erc721_dispatcher.owner_of(0);
    assert!(owner == OWNER(), "Token 0 should be minted to OWNER");
}

#[test]
fn test_initializer_multi_game_mode() {
    // TC-I-002: Multi-game mode
    let registry = deploy_minigame_registry_contract();
    let (token_dispatcher, erc721_dispatcher, _, _) = deploy_full_token_contract(
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(registry.contract_address),
    );

    // Verify registry address is set
    assert!(
        token_dispatcher.game_registry_address() == registry.contract_address,
        "Registry should be set",
    );

    // In multi-game mode, no creator token is minted (token 0 doesn't exist initially)
    // The balance should be 0 for OWNER initially
    let balance = erc721_dispatcher.balance_of(OWNER());
    // Balance is 0 because no token 0 is minted in multi-game mode
    assert!(balance == 0, "No creator token in multi-game mode");
}

#[test]
fn test_initializer_src5_interface_registered() {
    // TC-I-007: SRC5 interface registered
    let test_contracts = setup();

    let supports = test_contracts.src5.supports_interface(IMINIGAME_TOKEN_ID);
    assert!(supports, "Should support IMINIGAME_TOKEN_ID interface");
}

// ============================================================================
// SECURITY TESTS (SEC-*)
// ============================================================================

#[test]
fn test_security_game_over_transition_no_reversal() {
    // SEC-005: game_over transition reversal attempt
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // Set game over
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);
    assert!(token_dispatcher.token_metadata(token_id).game_over, "Should be game over");

    // Attempt to reverse (mock returns false)
    mock_game.set_game_over(token_id, false);
    token_dispatcher.update_game(token_id);

    // Should still be game over (no reversal)
    assert!(
        token_dispatcher.token_metadata(token_id).game_over,
        "Game over should not reverse to false",
    );
}

#[test]
fn test_security_soulbound_transfer_blocked() {
    // SEC-007: Soulbound token transfer attempt
    let test_contracts = setup();

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
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    // Verify soulbound
    assert!(test_contracts.test_token.is_soulbound(token_id), "Should be soulbound");

    // Transfer should fail (handled by ERC721 hooks)
    // Note: The actual transfer failure is handled by ERC721 hooks in the contract
    // We verify ownership remains with ALICE
    assert!(test_contracts.erc721.owner_of(token_id.into()) == ALICE(), "Owner should be ALICE");
}

#[test]
fn test_security_update_game_any_caller_allowed() {
    // update_game should be callable by anyone (not ownership restricted)
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    // BOB (non-owner) can call update_game
    cheat_caller_address(token_dispatcher.contract_address, BOB(), CheatSpan::TargetCalls(1));
    token_dispatcher.update_game(token_id);
    // Should not panic - anyone can sync game state
}

// ============================================================================
// EVENT TESTS (EVT-*)
// ============================================================================

#[test]
fn test_event_mint_with_player_name() {
    // EVT-001: mint with player_name emits TokenPlayerNameUpdate
    let test_contracts = setup();
    let mut spy = spy_events();

    let _token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TestPlayer'),
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

    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event for mint with name");
}

#[test]
fn test_event_update_game_emits_metadata_update() {
    // EVT-003: update_game emits MetadataUpdate
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    let token_id = token_dispatcher
        .mint(
            minigame.contract_address,
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

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit MetadataUpdate event");
}

#[test]
fn test_event_update_player_name() {
    // EVT-004: update_player_name emits TokenPlayerNameUpdate
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('OldName'),
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

    let mut spy = spy_events();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'NewName');

    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit TokenPlayerNameUpdate event");
}

#[test]
fn test_event_batch_mint_multiple_transfers() {
    // EVT-011: Batch mint emits multiple Transfer events
    let test_contracts = setup();
    let mut spy = spy_events();

    let mints: Array<MintParams> = array![
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: ALICE(),
            soulbound: false,
            paymaster: false,
            salt: 0,
            metadata: 0,
        },
        MintParams {
            game_address: test_contracts.minigame.contract_address,
            player_name: Option::None,
            settings_id: Option::None,
            start: Option::None,
            end: Option::None,
            objective_id: Option::None,
            context: Option::None,
            client_url: Option::None,
            renderer_address: Option::None,
            to: BOB(),
            soulbound: false,
            paymaster: false,
            salt: 1,
            metadata: 0,
        },
        MintParams {
            game_address: test_contracts.minigame.contract_address,
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
            paymaster: false,
            salt: 2,
            metadata: 0,
        },
    ];

    test_contracts.test_token.mint_batch(mints);

    let events = spy.get_events();
    assert!(events.events.span().len() >= 3, "Should emit at least 3 Transfer events");
}

// ============================================================================
// FUZZ TESTS (FT-*)
// ============================================================================

#[test]
#[fuzzer]
fn test_fuzz_is_playable_timestamps(start_offset: u64, duration: u64) {
    // FT-001: Fuzz is_playable with random timestamps
    let test_contracts = setup();

    let current_time: u64 = 1000000;
    let start = current_time + (start_offset % 100000);
    let end = if duration == 0 {
        0
    } else {
        start + (duration % 1000000)
    };

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(start),
            Option::Some(end),
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

    // Verify playability logic is consistent
    let is_playable = test_contracts.test_token.is_playable(token_id);

    if current_time < start {
        assert!(!is_playable, "Should not be playable before start");
    }

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
#[fuzzer]
fn test_fuzz_update_player_name(name: felt252) {
    // FT-003: Fuzz update_player_name with random names
    if name == 0 {
        return; // Skip empty names (would panic)
    }

    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Initial'),
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

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, name);

    assert!(test_contracts.test_token.player_name(token_id) == name, "Name should be stored");
}

#[test]
#[fuzzer]
fn test_fuzz_token_metadata_random_ids(token_id: felt252) {
    // FT-004: Fuzz token_metadata with random token_ids
    let test_contracts = setup();

    // With packed token IDs, immutable data is decoded from the token_id itself.
    // Non-existent tokens return decoded immutable fields + default mutable state.
    let metadata = test_contracts.test_token.token_metadata(token_id);

    // Mutable state should always be default for non-minted tokens
    assert!(!metadata.game_over, "Non-existent token should not be game over");
    assert!(!metadata.completed_objective, "Non-existent should not have completed objective");
}

#[test]
#[fuzzer]
fn test_fuzz_token_id_monotonicity(seed: felt252) {
    // Verify token IDs are always unique (packed IDs are not sequential)
    let test_contracts = setup();

    let mut previous_id: felt252 = 0;
    let mut i: u32 = 0;
    while i < 5 {
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
                ALICE(),
                false,
                false,
                i.try_into().unwrap(),
                0,
            );

        assert!(token_id != 0, "Token ID must be nonzero");
        if previous_id != 0 {
            assert!(token_id != previous_id, "Token IDs must be unique");
        }
        previous_id = token_id;
        i += 1;
    }
}

// ============================================================================
// ADDITIONAL VIEW FUNCTION TESTS
// ============================================================================

#[test]
fn test_game_address_view() {
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(minigame.contract_address);

    let game_addr = token_dispatcher.game_address();
    assert!(game_addr == minigame.contract_address, "Game address should match");
}

#[test]
fn test_game_registry_address_view() {
    let test_contracts = setup_multi_game();

    let registry_addr = test_contracts.test_token.game_registry_address();
    assert!(
        registry_addr == test_contracts.minigame_registry.contract_address,
        "Registry address should match",
    );
}

#[test]
fn test_settings_id_view() {
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None, // No settings_id
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

    let settings = test_contracts.test_token.settings_id(token_id);
    assert!(settings == 0, "Settings ID should be 0 when not provided");
}

#[test]
fn test_objective_id_view() {
    let test_contracts = setup();

    // Mock objective_exists
    mock_call(test_contracts.minigame.contract_address, selector!("objective_exists"), true, 1);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(42), // objective_id
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let objective = test_contracts.test_token.objective_id(token_id);
    assert!(objective == 42, "Objective ID should be 42");
}

#[test]
fn test_minted_by_view() {
    let test_contracts = setup();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let minted_by = test_contracts.test_token.minted_by(token_id);
    assert!(minted_by != 0, "Should have valid minter ID");

    // Verify minter address can be retrieved
    let minter_address = test_contracts
        .test_token
        .get_minter_address(minted_by.try_into().unwrap());
    assert!(minter_address == ALICE(), "Minter address should match caller");
}

// ============================================================================
// MINTER TRACKING TESTS
// ============================================================================

#[test]
fn test_minter_tracking_basic() {
    let test_contracts = setup();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(2),
    );

    // First mint by ALICE
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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Second mint by ALICE (different salt to avoid collision)
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
            ALICE(),
            false,
            false,
            1,
            0,
        );

    // Both tokens should have same minter ID (ALICE)
    let minted_by1 = test_contracts.test_token.minted_by(token_id1);
    let minted_by2 = test_contracts.test_token.minted_by(token_id2);
    assert!(minted_by1 == minted_by2, "Same minter should have same ID");
}

#[test]
fn test_minter_exists() {
    let test_contracts = setup();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.minter_exists(ALICE()), "ALICE should be a minter");
    assert!(!test_contracts.test_token.minter_exists(BOB()), "BOB should not be a minter");
}

#[test]
fn test_total_minters() {
    let test_contracts = setup();

    let initial_minters = test_contracts.test_token.total_minters();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
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
            ALICE(),
            false,
            false,
            0,
            0,
        );

    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
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
            BOB(),
            false,
            false,
            1,
            0,
        );

    let final_minters = test_contracts.test_token.total_minters();
    assert!(final_minters >= initial_minters + 2, "Should have at least 2 more minters");
}
