// ============================================================================
// COMPONENT COVERAGE TESTS
// ============================================================================
// Tests to improve coverage for components:
// - CoreTokenComponent functions
// - SettingsComponent validation
// - ObjectivesComponent validation

use core::num::traits::Zero;
use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::token_legacy::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_mock::IMinigameMockDispatcherTrait;
use super::mocks::mock_game::IMockGameDispatcherTrait;
use super::setup::{
    ALICE, BOB, CURRENT_TIME, FAR_FUTURE_TIME, PAST_TIME, RENDERER_ADDRESS, deploy_basic_mock_game,
    deploy_mock_game, deploy_optimized_token_with_game, setup, setup_multi_game,
};

// ============================================================================
// CORE TOKEN - GAME ADDRESS RESOLUTION TESTS
// ============================================================================

#[test]
fn test_game_address_from_single_game_token() {
    let (minigame_dispatcher, _, _) = deploy_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Verify game_address returns the single game address
    let game_address = token_dispatcher.game_address();
    assert!(
        game_address == minigame_dispatcher.contract_address, "Should return single game address",
    );
}

#[test]
fn test_game_registry_address_single_game() {
    let (minigame_dispatcher, _, _) = deploy_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    // Single game tokens have zero registry address
    let registry_address = token_dispatcher.game_registry_address();
    assert!(registry_address.is_zero(), "Single game should have zero registry");
}

// ============================================================================
// CORE TOKEN - TRANSFER TESTS (NON-SOULBOUND)
// ============================================================================

#[test]
fn test_transfer_non_soulbound_token() {
    let test_contracts = setup();

    // Mint a NON-soulbound token to ALICE
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('TransferPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false, // NOT soulbound
            false,
            0,
            0,
        );

    // Verify initial owner
    assert!(test_contracts.erc721.owner_of(token_id.into()) == ALICE(), "ALICE should own token");

    // Transfer to BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.erc721.transfer_from(ALICE(), BOB(), token_id.into());

    // Verify new owner
    assert!(test_contracts.erc721.owner_of(token_id.into()) == BOB(), "BOB should now own token");
}

#[test]
#[should_panic]
fn test_transfer_soulbound_token_fails() {
    let test_contracts = setup();

    // Mint a SOULBOUND token to ALICE
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('SoulboundPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true, // SOULBOUND
            false,
            0,
            0,
        );

    // Try to transfer soulbound token - should fail
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.erc721.transfer_from(ALICE(), BOB(), token_id.into());
}


// Note: Token URI tests require renderer setup - covered by test_renderer.cairo

// ============================================================================
// LIFECYCLE EDGE CASES
// ============================================================================

#[test]
fn test_playability_with_zero_start_time() {
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Token with start=0 should be immediately playable
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(0), // start = 0
            Option::Some(FAR_FUTURE_TIME), // end
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
        test_contracts.test_token.is_playable(token_id), "Token with start=0 should be playable",
    );

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_playability_with_zero_end_time() {
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Token with end=0 should never expire
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(PAST_TIME), // start
            Option::Some(0), // end = 0 (no expiry)
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

    assert!(test_contracts.test_token.is_playable(token_id), "Token with end=0 should be playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

// ============================================================================
// MINTER TRACKING EDGE CASES
// ============================================================================

#[test]
fn test_same_minter_multiple_tokens() {
    let test_contracts = setup();

    // Mint multiple tokens from same minter
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(3),
    );

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
            false,
            false,
            1,
            0,
        );

    let token_id3 = test_contracts
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
            2,
            0,
        );

    // All tokens should have same minter ID
    let minter_id1 = test_contracts.test_token.minted_by(token_id1);
    let minter_id2 = test_contracts.test_token.minted_by(token_id2);
    let minter_id3 = test_contracts.test_token.minted_by(token_id3);

    assert!(minter_id1 == minter_id2, "Same minter should have same ID");
    assert!(minter_id2 == minter_id3, "Same minter should have same ID");
}

// ============================================================================
// MULTI-GAME TOKEN EDGE CASES
// ============================================================================

#[test]
fn test_multi_game_token_game_id_resolution() {
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

    // In multi-game mode, game_id should be non-zero
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.game_id > 0, "Multi-game token should have game_id > 0");
}

// ============================================================================
// ERC721 STANDARD COMPLIANCE TESTS
// ============================================================================

#[test]
fn test_erc721_name() {
    let test_contracts = setup();
    let name = test_contracts.erc721.name();
    assert!(name == "TestToken", "Name should match");
}

#[test]
fn test_erc721_symbol() {
    let test_contracts = setup();
    let symbol = test_contracts.erc721.symbol();
    assert!(symbol == "TT", "Symbol should match");
}

#[test]
fn test_erc721_balance_of_after_mint() {
    let test_contracts = setup();

    let initial_balance = test_contracts.erc721.balance_of(ALICE());

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

    let final_balance = test_contracts.erc721.balance_of(ALICE());
    assert!(final_balance == initial_balance + 1, "Balance should increase by 1");
}

// ============================================================================
// SRC5 INTERFACE DETECTION TESTS
// ============================================================================

#[test]
fn test_supports_minigame_token_interface() {
    let test_contracts = setup();
    use crate::token_legacy::interface::IMINIGAME_TOKEN_LEGACY_ID;
    let supports = test_contracts.src5.supports_interface(IMINIGAME_TOKEN_LEGACY_ID);
    assert!(supports, "Should support IMinigameTokenLegacy interface");
}

// ============================================================================
// GAME UPDATE EDGE CASES
// ============================================================================

#[test]
fn test_update_game_no_state_change() {
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
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

    // Get initial state
    let metadata_before = token_dispatcher.token_metadata(token_id);

    // Update game without any state change
    token_dispatcher.update_game(token_id);

    // State should be same
    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(metadata_before.game_over == metadata_after.game_over, "Game over should not change");
    assert!(
        metadata_before.completed_objective == metadata_after.completed_objective,
        "Objective should not change",
    );
}

#[test]
fn test_update_game_with_score_change() {
    let (minigame_dispatcher, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
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

    // Set score via mock
    mock_game.set_score(token_id, 500);

    // Update game
    token_dispatcher.update_game(token_id);

    // Score update doesn't change metadata directly
    // but triggers MetadataUpdate event
    let metadata_after = token_dispatcher.token_metadata(token_id);
    assert!(!metadata_after.game_over, "Game should not be over from score alone");
}

// ============================================================================
// RENDERER EXTENSION TESTS
// ============================================================================

// Note: renderer_address tests with mock games are covered by test_renderer.cairo

#[test]
fn test_renderer_address_custom() {
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
            Option::None, // custom renderer
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // With custom renderer, should have custom renderer or check has_custom_renderer
    let has_custom = test_contracts.test_token.has_custom_renderer(token_id);
    assert!(has_custom, "Token should have custom renderer");
}

#[test]
fn test_get_renderer() {
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let renderer = test_contracts.test_token.get_renderer(token_id);
    assert!(renderer == RENDERER_ADDRESS(), "Renderer should be set");
}

// ============================================================================
// BATCH RENDERER OPERATIONS
// ============================================================================

#[test]
fn test_get_renderer_batch() {
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
            Option::Some(RENDERER_ADDRESS()),
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    let token_ids: Array<felt252> = array![token_id1, token_id2];
    let renderers = test_contracts.test_token.get_renderer_batch(token_ids.span());

    assert!(renderers.len() == 2, "Should return 2 renderer addresses");
}

// ============================================================================
// PLAYER NAME TESTS
// ============================================================================

#[test]
fn test_player_name_initial() {
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 'TestPlayer', "Player name should match");
}

#[test]
fn test_player_name_no_name() {
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None, // No name
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

    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 0, "Player name should be 0 (empty)");
}

// ============================================================================
// OBJECTIVE ID TESTS
// ============================================================================

#[test]
fn test_objective_id_initial() {
    let test_contracts = setup();

    // Create an objective first
    test_contracts.mock_minigame.create_objective_score(100);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1), // objective_id = 1
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

    let obj_id = test_contracts.test_token.objective_id(token_id);
    assert!(obj_id == 1, "Objective ID should be 1");
}

#[test]
fn test_objective_id_zero() {
    let test_contracts = setup();

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

    let obj_id = test_contracts.test_token.objective_id(token_id);
    assert!(obj_id == 0, "Objective ID should be 0");
}
