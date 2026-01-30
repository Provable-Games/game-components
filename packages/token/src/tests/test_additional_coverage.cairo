// ============================================================================
// ADDITIONAL COVERAGE TESTS
// ============================================================================
// Tests to improve coverage for:
// - settings/settings.cairo
// - objectives/objectives.cairo
// - core/core_token.cairo edge cases

use game_components_interfaces::{
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait, IMinigameSettingsDispatcher,
    IMinigameSettingsDispatcherTrait,
};
use snforge_std::{
    CheatSpan, EventSpyTrait, cheat_caller_address, mock_call, spy_events,
    start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_starknet_mock::IMinigameStarknetMockDispatcherTrait;
use super::mocks::mock_game::IMockGameDispatcherTrait;
use super::setup::{
    ALICE, BOB, CHARLIE, CURRENT_TIME, FAR_FUTURE_TIME, FUTURE_TIME, PAST_TIME, RENDERER_ADDRESS,
    deploy_basic_mock_game, deploy_optimized_token_with_game, setup, setup_multi_game,
};

// ============================================================================
// SETTINGS COMPONENT COVERAGE TESTS
// ============================================================================

#[test]
fn test_settings_create_multiple_sequential() {
    let test_contracts = setup();

    // Create multiple settings sequentially
    test_contracts.mock_minigame.create_settings_difficulty("Easy", "Easy mode", 1);
    test_contracts.mock_minigame.create_settings_difficulty("Medium", "Medium mode", 2);
    test_contracts.mock_minigame.create_settings_difficulty("Hard", "Hard mode", 3);
    test_contracts.mock_minigame.create_settings_difficulty("Expert", "Expert mode", 4);

    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };

    // Verify all settings exist
    assert!(settings.settings_exist(1), "Settings 1 should exist");
    assert!(settings.settings_exist(2), "Settings 2 should exist");
    assert!(settings.settings_exist(3), "Settings 3 should exist");
    assert!(settings.settings_exist(4), "Settings 4 should exist");

    // Verify non-existent settings return false
    assert!(!settings.settings_exist(5), "Settings 5 should not exist");
    assert!(!settings.settings_exist(100), "Settings 100 should not exist");
}

#[test]
fn test_settings_exist_variations() {
    let test_contracts = setup();

    // Create settings with specific data
    test_contracts
        .mock_minigame
        .create_settings_difficulty("TestMode", "A test mode description", 5);

    let settings = IMinigameSettingsDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };

    // Verify settings exist
    assert!(settings.settings_exist(1), "Settings should exist");

    // Batch check
    let settings_ids: Array<u32> = array![1, 2, 3];
    let batch_result = settings.settings_exist_batch(settings_ids.span());
    assert!(batch_result.len() == 3, "Batch should return 3 results");
    assert!(*batch_result.at(0), "First settings should exist");
    assert!(!*batch_result.at(1), "Second settings should not exist");
    assert!(!*batch_result.at(2), "Third settings should not exist");
}

#[test]
fn test_settings_mint_with_valid_settings() {
    let test_contracts = setup();

    // Create settings first
    test_contracts.mock_minigame.create_settings_difficulty("Standard", "Standard difficulty", 1);

    // Mock the supports_interface and settings_exist calls for validation
    mock_call(test_contracts.minigame.contract_address, selector!("supports_interface"), true, 10);
    mock_call(test_contracts.minigame.contract_address, selector!("settings_exist"), true, 5);

    // Mint with the created settings_id
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('SettingsPlayer'),
            Option::Some(1), // Use created settings_id
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

    // Verify token metadata
    assert!(test_contracts.test_token.settings_id(token_id) == 1, "Settings ID should be 1");
}

#[test]
fn test_settings_with_zero_settings_id() {
    let test_contracts = setup();

    // Mint with settings_id = 0 (no settings validation needed)
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('NoSettingsPlayer'),
            Option::None, // No settings_id means 0
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

    assert!(test_contracts.test_token.settings_id(token_id) == 0, "Settings ID should be 0");
}

// ============================================================================
// OBJECTIVES COMPONENT COVERAGE TESTS
// ============================================================================

#[test]
fn test_objectives_create_multiple() {
    let test_contracts = setup();

    // Create multiple objectives with different scores
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_objective_score(500);
    test_contracts.mock_minigame.create_objective_score(1000);
    test_contracts.mock_minigame.create_objective_score(5000);

    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };

    // Verify all objectives exist
    assert!(objectives.objective_exists(1), "Objective 1 should exist");
    assert!(objectives.objective_exists(2), "Objective 2 should exist");
    assert!(objectives.objective_exists(3), "Objective 3 should exist");
    assert!(objectives.objective_exists(4), "Objective 4 should exist");

    // Verify non-existent objectives return false
    assert!(!objectives.objective_exists(5), "Objective 5 should not exist");
    assert!(!objectives.objective_exists(100), "Objective 100 should not exist");
}

#[test]
fn test_objectives_completion_lifecycle() {
    let test_contracts = setup();

    // Create objective with target score 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint token with objective
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('ObjectivePlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1), // objective_id = 1
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify initial state
    let metadata_before = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_before.objective_id == 1, "Should have objective_id 1");
    assert!(!metadata_before.completed_objective, "Should not be completed initially");
    assert!(!metadata_before.game_over, "Game should not be over initially");

    // Start the game
    test_contracts.mock_minigame.start_game(token_id);

    // End game with score below objective
    test_contracts.mock_minigame.end_game(token_id, 50);
    test_contracts.test_token.update_game(token_id);

    let metadata_partial = test_contracts.test_token.token_metadata(token_id);
    assert!(!metadata_partial.completed_objective, "Should not be completed with low score");
    assert!(metadata_partial.game_over, "Game should be over");
    // Note: Once game_over is true, it cannot be reset, so we can't test completion
// with higher score on the same token. Testing the score comparison logic
// would require a separate token.
}

#[test]
fn test_objectives_completion_exceeds_target() {
    let test_contracts = setup();

    // Create objective with target score 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint token with objective
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game with score exceeding objective
    test_contracts.mock_minigame.end_game(token_id, 500);
    test_contracts.test_token.update_game(token_id);

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective, "Should be completed when score exceeds target");
    assert!(metadata.game_over, "Game should be over");
}

#[test]
fn test_objectives_completion_exact_match() {
    let test_contracts = setup();

    // Create objective with target score 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint token with objective
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game with exact target score
    test_contracts.mock_minigame.end_game(token_id, 100);
    test_contracts.test_token.update_game(token_id);

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective, "Should be completed when score equals target");
}

#[test]
fn test_objectives_multiple_tokens_same_objective() {
    let test_contracts = setup();

    // Create objective
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint multiple tokens with same objective
    let token_id1 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player1'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
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
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player2'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player3'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
            false,
            2,
            0,
        );

    // All should reference same objective
    assert!(test_contracts.test_token.objective_id(token_id1) == 1, "Token 1 objective");
    assert!(test_contracts.test_token.objective_id(token_id2) == 1, "Token 2 objective");
    assert!(test_contracts.test_token.objective_id(token_id3) == 1, "Token 3 objective");

    // Complete objectives for some tokens
    test_contracts.mock_minigame.end_game(token_id1, 100); // Completes
    test_contracts.test_token.update_game(token_id1);

    test_contracts.mock_minigame.end_game(token_id2, 50); // Does not complete
    test_contracts.test_token.update_game(token_id2);

    // Token 3 not ended yet

    // Verify independent completion status
    assert!(
        test_contracts.test_token.token_metadata(token_id1).completed_objective,
        "Token 1 should be completed",
    );
    assert!(
        !test_contracts.test_token.token_metadata(token_id2).completed_objective,
        "Token 2 should not be completed",
    );
    assert!(
        !test_contracts.test_token.token_metadata(token_id3).completed_objective,
        "Token 3 should not be completed",
    );
}

// ============================================================================
// CORE TOKEN EDGE CASE TESTS
// ============================================================================

#[test]
fn test_core_token_client_url_with_mint() {
    let test_contracts = setup();

    // Mint with client_url
    let client_url: ByteArray = "https://game.example.com/play";
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('UrlPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(client_url.clone()),
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Token should be minted successfully
    assert!(token_id != 0, "Token should be minted");
}

#[test]
fn test_core_token_renderer_address_with_mint() {
    let test_contracts = setup();

    // Mint with custom renderer_address
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('RendererPlayer'),
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

    // Token should be minted successfully with renderer
    assert!(token_id != 0, "Token should be minted");
}

#[test]
fn test_core_token_full_params_mint() {
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Create objective first
    test_contracts.mock_minigame.create_objective_score(1000);

    // Mint with parameters (skip settings_id due to packing limitations)
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('FullParamsPlayer'),
            Option::None, // settings_id - skip to avoid packing issues
            Option::Some(CURRENT_TIME), // start
            Option::Some(FAR_FUTURE_TIME), // end
            Option::Some(1), // objective_id
            Option::None, // context
            Option::Some("https://game.com"), // client_url
            Option::Some(RENDERER_ADDRESS()), // renderer_address
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    // Verify metadata
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound, "Should be soulbound");
    assert!(metadata.lifecycle.start == CURRENT_TIME, "Start should match");
    assert!(metadata.lifecycle.end == FAR_FUTURE_TIME, "End should match");
    assert!(metadata.objective_id == 1, "Objective should be 1");

    // Verify playability
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_core_token_batch_update_game() {
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

    // Mint multiple tokens
    let token_id1 = token_dispatcher
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
            false,
            0,
            0,
        );

    let token_id2 = token_dispatcher
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
            false,
            1,
            0,
        );

    let token_id3 = token_dispatcher
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
            false,
            2,
            0,
        );

    // Set different game states
    mock_game.set_game_over(token_id1, true);
    mock_game.set_score(token_id2, 100);
    mock_game.set_score(token_id3, 200);

    // Batch update
    let token_ids: Array<felt252> = array![token_id1, token_id2, token_id3];
    token_dispatcher.update_game_batch(token_ids.span());

    // Verify states
    assert!(token_dispatcher.token_metadata(token_id1).game_over, "Token 1 should be game over");
    assert!(!token_dispatcher.token_metadata(token_id2).game_over, "Token 2 should not be over");
    assert!(!token_dispatcher.token_metadata(token_id3).game_over, "Token 3 should not be over");
}

#[test]
fn test_core_token_playability_with_lifecycle() {
    let test_contracts = setup();

    // Test various lifecycle scenarios
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Token that starts in the future
    let future_token = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(FUTURE_TIME),
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

    // Token that ends soon after current time (to test expiry)
    // end_delay = end - start = (PAST_TIME + 1) - PAST_TIME = 1
    // lifecycle.end = minted_at + start_delay + end_delay = CURRENT_TIME + 0 + 1 = CURRENT_TIME + 1
    let expiring_token = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(PAST_TIME),
            Option::Some(PAST_TIME + 1), // end_delay = 1 second (end - start)
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

    // Token currently active
    let active_token = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(PAST_TIME),
            Option::Some(FAR_FUTURE_TIME),
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

    // Verify playability at CURRENT_TIME
    assert!(!test_contracts.test_token.is_playable(future_token), "Future token not playable yet");
    // expiring_token: start_delay=0 (PAST_TIME < CURRENT_TIME), end_delay=1 (end - start)
    // lifecycle.start = minted_at + start_delay = CURRENT_TIME + 0 = CURRENT_TIME
    // lifecycle.end = minted_at + start_delay + end_delay = CURRENT_TIME + 0 + 1 = CURRENT_TIME + 1
    // At CURRENT_TIME: playable (start <= now < end)
    assert!(
        test_contracts.test_token.is_playable(expiring_token),
        "Expiring token should be playable now",
    );
    assert!(test_contracts.test_token.is_playable(active_token), "Active token should be playable");

    // Advance time past the expiring token's end
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME + 1);
    assert!(
        !test_contracts.test_token.is_playable(expiring_token),
        "Expiring token should no longer be playable",
    );
    assert!(test_contracts.test_token.is_playable(active_token), "Active token still playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_core_token_soulbound_verification() {
    let test_contracts = setup();

    // Mint soulbound token
    let soulbound_token = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('SoulboundPlayer'),
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

    // Mint normal token
    let normal_token = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('NormalPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false, // not soulbound
            false,
            1,
            0,
        );

    // Verify soulbound flags
    assert!(test_contracts.test_token.is_soulbound(soulbound_token), "Should be soulbound");
    assert!(!test_contracts.test_token.is_soulbound(normal_token), "Should not be soulbound");

    // Verify via metadata
    let soulbound_metadata = test_contracts.test_token.token_metadata(soulbound_token);
    let normal_metadata = test_contracts.test_token.token_metadata(normal_token);

    assert!(soulbound_metadata.soulbound, "Metadata should show soulbound");
    assert!(!normal_metadata.soulbound, "Metadata should show not soulbound");
}

#[test]
fn test_core_token_minter_tracking() {
    let test_contracts = setup();

    // Get initial minter count
    let initial_minters = test_contracts.test_token.total_minters();

    // Mint as ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
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
            false,
            0,
            0,
        );

    // Verify ALICE is tracked
    assert!(test_contracts.test_token.minter_exists(ALICE()), "ALICE should be tracked");

    // Mint as BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
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
            false,
            1,
            0,
        );

    // Verify BOB is tracked
    assert!(test_contracts.test_token.minter_exists(BOB()), "BOB should be tracked");

    // Verify CHARLIE is not tracked yet
    assert!(!test_contracts.test_token.minter_exists(CHARLIE()), "CHARLIE should not be tracked");

    // Verify minter count increased
    let final_minters = test_contracts.test_token.total_minters();
    assert!(final_minters >= initial_minters + 2, "Should have at least 2 more minters");

    // Verify minter IDs are retrievable
    let minted_by1 = test_contracts.test_token.minted_by(token_id1);
    let minted_by2 = test_contracts.test_token.minted_by(token_id2);

    let minter_addr1 = test_contracts.test_token.get_minter_address(minted_by1.try_into().unwrap());
    let minter_addr2 = test_contracts.test_token.get_minter_address(minted_by2.try_into().unwrap());

    assert!(minter_addr1 == ALICE(), "Token 1 minter should be ALICE");
    assert!(minter_addr2 == BOB(), "Token 2 minter should be BOB");
}

#[test]
fn test_core_token_game_over_irreversible() {
    let (minigame, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

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
            false,
            0,
            0,
        );

    // Set game over
    mock_game.set_game_over(token_id, true);
    token_dispatcher.update_game(token_id);

    assert!(token_dispatcher.token_metadata(token_id).game_over, "Should be game over");

    // Try to unset game over (mock returns false)
    mock_game.set_game_over(token_id, false);
    token_dispatcher.update_game(token_id);

    // Should still be game over (irreversible)
    assert!(
        token_dispatcher.token_metadata(token_id).game_over, "Game over should be irreversible",
    );
}

#[test]
fn test_core_token_metadata_batch_mixed() {
    let test_contracts = setup();

    // Mint tokens with different properties
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
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player2'),
            Option::None,
            Option::Some(1000),
            Option::Some(2000),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            true, // soulbound
            false,
            1,
            0,
        );

    // Batch query all views
    let token_ids: Array<felt252> = array![token_id1, token_id2];

    let metadata_batch = test_contracts.test_token.token_metadata_batch(token_ids.span());
    let playable_batch = test_contracts.test_token.is_playable_batch(token_ids.span());
    let soulbound_batch = test_contracts.test_token.is_soulbound_batch(token_ids.span());
    let player_names_batch = test_contracts.test_token.player_name_batch(token_ids.span());
    let minted_by_batch = test_contracts.test_token.minted_by_batch(token_ids.span());
    let game_addresses_batch = test_contracts.test_token.token_game_address_batch(token_ids.span());

    // Verify batch results
    assert!(metadata_batch.len() == 2, "Should have 2 metadata results");
    assert!(playable_batch.len() == 2, "Should have 2 playable results");
    assert!(soulbound_batch.len() == 2, "Should have 2 soulbound results");
    assert!(player_names_batch.len() == 2, "Should have 2 player name results");
    assert!(minted_by_batch.len() == 2, "Should have 2 minted_by results");
    assert!(game_addresses_batch.len() == 2, "Should have 2 game address results");

    // Verify specific values
    assert!(!*soulbound_batch.at(0), "Token 1 should not be soulbound");
    assert!(*soulbound_batch.at(1), "Token 2 should be soulbound");
    assert!(*player_names_batch.at(0) == 'Player1', "Token 1 name");
    assert!(*player_names_batch.at(1) == 'Player2', "Token 2 name");
}

// ============================================================================
// MULTI-GAME MODE TESTS
// ============================================================================

#[test]
fn test_multi_game_mint_and_resolution() {
    let test_contracts = setup_multi_game();

    // Mint token for registered game
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('MultiGamePlayer'),
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

    // Verify game address resolution
    let resolved_address = test_contracts.test_token.token_game_address(token_id);
    assert!(
        resolved_address == test_contracts.minigame.contract_address,
        "Should resolve to correct game",
    );

    // Verify metadata has non-zero game_id (multi-game mode)
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.game_id > 0, "Multi-game token should have non-zero game_id");
}

#[test]
fn test_multi_game_registry_integration() {
    let test_contracts = setup_multi_game();

    // Verify registry address is set
    let registry_address = test_contracts.test_token.game_registry_address();
    assert!(
        registry_address == test_contracts.minigame_registry.contract_address,
        "Registry should be set",
    );
}

// ============================================================================
// EVENT EMISSION TESTS
// ============================================================================

#[test]
fn test_event_emission_on_mint() {
    let test_contracts = setup();
    let mut spy = spy_events();

    let _token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('EventPlayer'),
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

    // Verify events were emitted
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit events on mint");
}

#[test]
fn test_event_emission_on_update_game() {
    let (minigame, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(minigame.contract_address);

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
            false,
            0,
            0,
        );

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate event
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit MetadataUpdate event");
}

#[test]
fn test_event_emission_on_player_name_update() {
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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

    // Should emit TokenPlayerNameUpdate event
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit player name update event");
}
