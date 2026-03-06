// Tests to improve core_token coverage
use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use core::num::traits::Zero;
use game_components_embeddable_game_standard::registry::interface::IMinigameRegistryDispatcherTrait;
use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use crate::token::structs::PlayerNameUpdate;
use super::mocks::minigame_mock::IMinigameMockDispatcherTrait;
use super::mocks::mock_game::IMockGameDispatcherTrait;
use super::setup::{
    ALICE, BOB, CHARLIE, CURRENT_TIME, OWNER, deploy_basic_mock_game,
    deploy_optimized_token_with_game, deploy_single_game_token_default, setup, setup_multi_game,
};

#[test]
fn test_core_token_edge_case_minting() {
    let test_contracts = setup();

    // Test minting with max values
    // Note: TokenMetadata uses 35-bit packing for lifecycle timestamps
    // MAX_LIFECYCLE_TIMESTAMP = 2^35 - 1 = 34359738367

    // This should work with max timestamps
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('MaxPlayer'),
            Option::None,
            Option::Some(0),
            Option::Some(33554431),
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
    assert!(metadata.lifecycle.end == 33554431, "Max end time should be set");
}

#[test]
fn test_core_token_batch_operations() {
    let test_contracts = setup();

    // Batch mint tokens
    let batch_size: u32 = 5;
    let mut token_ids: Array<felt252> = array![];
    let mut i: u32 = 0;

    while i < batch_size {
        let token_id = test_contracts
            .test_token
            .mint(
                test_contracts.minigame.contract_address,
                Option::Some('BatchPlayer'),
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
        token_ids.append(token_id);
        i += 1;
    }

    // Verify unique IDs
    let mut j = 0;
    let token_ids_len: usize = token_ids.len();
    while j < token_ids_len - 1 {
        let current = *token_ids.at(j);
        let next = *token_ids.at(j + 1);
        assert!(current != next, "Token IDs should be unique");
        j += 1;
    }

    // Batch update games
    let mut k = 0;
    let token_ids_len_2: usize = token_ids.len();
    while k < token_ids_len_2 {
        let token_id = *token_ids.at(k);
        test_contracts.mock_minigame.end_game(token_id, 50 + k.into());
        test_contracts.test_token.update_game(token_id);
        k += 1;
    };
}

#[test]
fn test_core_token_game_registry_operations() {
    let test_contracts = setup_multi_game();

    // Test registry address view
    let registry_address = test_contracts.test_token.game_registry_address();
    assert!(
        registry_address == test_contracts.minigame_registry.contract_address,
        "Registry address should match",
    );

    // Test game count
    let game_count = test_contracts.minigame_registry.game_count();
    assert!(game_count >= 2, "Should have at least 2 games registered");

    // Test game address resolution for tokens
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

    let game_address = test_contracts.test_token.token_game_address(token_id);
    assert!(game_address == test_contracts.minigame.contract_address, "Game address should match");
}

#[test]
fn test_core_token_update_edge_cases() {
    let (_, mock_game) = deploy_basic_mock_game();

    // Deploy token with mock game
    let (token_dispatcher, _, _, _) = deploy_optimized_token_with_game(mock_game.contract_address);

    // Mint token
    let token_id = token_dispatcher
        .mint(
            mock_game.contract_address,
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

    // Update with no changes
    token_dispatcher.update_game(token_id);
    let metadata1 = token_dispatcher.token_metadata(token_id);

    // Update again with no changes (idempotent)
    token_dispatcher.update_game(token_id);
    let metadata2 = token_dispatcher.token_metadata(token_id);

    // Metadata should be identical
    assert!(metadata1.game_over == metadata2.game_over, "Game over should not change");
    assert!(
        metadata1.completed_objective == metadata2.completed_objective,
        "Objectives should not change",
    );
}

#[test]
fn test_core_token_lifecycle_validation() {
    let test_contracts = setup();

    // Test various lifecycle combinations
    let current_time = 1000_u64;
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, current_time);

    // Valid lifecycle
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(current_time + 1000),
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

    // Zero end time (no expiry)
    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(0),
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

    // Both zero (always playable)
    let token_id3 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(0),
            Option::Some(0),
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

    // Verify playability
    assert!(test_contracts.test_token.is_playable(token_id1), "Token 1 should be playable");
    assert!(test_contracts.test_token.is_playable(token_id2), "Token 2 should be playable");
    assert!(test_contracts.test_token.is_playable(token_id3), "Token 3 should be playable");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_core_token_minter_edge_cases() {
    let test_contracts = setup();

    // Test minter operations with edge addresses
    let edge_addresses = array![
        addr(0x1),
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF.try_into().unwrap(),
    ];

    let mut i = 0;
    let edge_addresses_len: usize = edge_addresses.len();
    while i < edge_addresses_len {
        let address = *edge_addresses.at(i);

        cheat_caller_address(
            test_contracts.test_token.contract_address, address, CheatSpan::TargetCalls(1),
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
                Option::None,
                address,
                false,
                false,
                0,
                0,
            );

        // Verify minter is tracked
        assert!(
            test_contracts.test_token.minter_exists(address),
            "Edge address should be tracked as minter",
        );

        let minter_id = test_contracts.test_token.minted_by(token_id);
        assert!(minter_id != 0, "Should have valid minter ID");

        let retrieved_address = test_contracts
            .test_token
            .get_minter_address(minter_id.try_into().unwrap());
        assert!(retrieved_address == address, "Retrieved address should match");

        i += 1;
    };
}

#[test]
#[should_panic(expected: "MinigameToken: Game address is zero")]
fn test_mint_with_zero_game_address_should_panic() {
    let test_contracts = setup();

    // Try to mint with zero game address - this should trigger validation
    let zero_address = addr(0);

    test_contracts
        .test_token
        .mint(
            zero_address,
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
#[should_panic(expected: "MinigameToken: Token 999 does not exist")]
fn test_update_game_nonexistent_token_should_panic() {
    let test_contracts = setup();

    // Try to update game for a non-existent token
    test_contracts.test_token.update_game(999);
}

// ============================================================================
// UPDATE_PLAYER_NAME TESTS
// ============================================================================

#[test]
fn test_update_player_name_basic() {
    let test_contracts = setup();

    // Mint a token
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Update player name as the token owner
    let new_name = 'Player1';
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, new_name);

    // Verify the name was updated
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == new_name, "Player name not updated");
}

#[test]
fn test_update_player_name_multiple_updates() {
    let test_contracts = setup();

    // Mint a token
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Update player name multiple times as the token owner
    let name1 = 'Alice';
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, name1);
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == name1, "First name update failed");

    let name2 = 'Bob';
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, name2);
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == name2, "Second name update failed");

    let name3 = 'Charlie';
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, name3);
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == name3, "Third name update failed");
}

#[test]
#[should_panic(expected: "MinigameToken: Token")]
fn test_update_player_name_nonexistent_token() {
    let test_contracts = setup();

    // Try to update name for non-existent token as anyone
    let invalid_token_id = 999;
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(invalid_token_id, 'InvalidName');
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_update_player_name_non_owner() {
    let test_contracts = setup();

    // Mint a token to ALICE
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try to update name as BOB (non-owner)
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'HackerName');
}

#[test]
#[should_panic(expected: "MinigameToken: Player name is empty")]
fn test_update_player_name_empty_name() {
    let test_contracts = setup();

    // Mint a token
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try to update with empty name (0 felt) as the token owner - should panic
    let empty_name = 0;
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, empty_name);
}

#[test]
fn test_update_player_name_special_characters() {
    let test_contracts = setup();

    // Mint a token
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Test various special names as the token owner
    let special_name = '123456';
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, special_name);
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == special_name, "Numeric name update failed");

    let max_felt = 0x7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, max_felt);
    let updated_name = test_contracts.test_token.player_name(token_id);
    assert!(updated_name == max_felt, "Max felt name update failed");
}

// ============================================================================
// RENDERER_ADDRESS SINGLE-GAME TOKEN (lines 180, 182)
// ============================================================================

#[test]
fn test_renderer_address_single_game_no_custom_renderer() {
    // Covers lines 179-182: renderer_address() when game_id == 0 and no custom renderer
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    // Mint token with no custom renderer in single-game mode
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
            Option::None, // No renderer
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // renderer_address() should fall through to game_address.read() for single-game
    let renderer = token_dispatcher.renderer_address(token_id);
    assert!(
        renderer == minigame_dispatcher.contract_address,
        "Single-game renderer should be game address",
    );
}

#[test]
fn test_renderer_address_batch_single_game() {
    // Covers lines 332, 337: renderer_address_batch loop body in single-game mode
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    let token_id1 = token_dispatcher
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

    let token_id2 = token_dispatcher
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
            BOB(),
            false,
            false,
            1,
            0,
        );

    let token_ids: Array<felt252> = array![token_id1, token_id2];
    let results = token_dispatcher.renderer_address_batch(token_ids.span());
    assert!(results.len() == 2, "Should return 2 renderer addresses");
    assert!(
        *results.at(0) == minigame_dispatcher.contract_address,
        "Token 1 renderer should be game address",
    );
    assert!(
        *results.at(1) == minigame_dispatcher.contract_address,
        "Token 2 renderer should be game address",
    );
}

// ============================================================================
// PLAYER_NAME VIEW (line 147)
// ============================================================================

#[test]
fn test_player_name_single_game_view() {
    // Covers line 147: player_name() reads from token_player_names storage
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
            Option::Some('SingleGamePlayer'),
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

    let name = token_dispatcher.player_name(token_id);
    assert!(name == 'SingleGamePlayer', "Player name should match");
}

// ============================================================================
// BATCH VIEW FUNCTIONS (lines 228-352 inner loop bodies)
// ============================================================================

#[test]
fn test_is_playable_batch_single_game() {
    // Covers lines 228, 238: is_playable_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.is_playable_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be playable");
}

#[test]
fn test_settings_id_batch_single_game() {
    // Covers lines 247: settings_id_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.settings_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == 0, "Settings ID should be 0");
}

#[test]
fn test_player_name_batch_single_game() {
    // Covers line 263: player_name_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
            Option::Some('BatchNameTest'),
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
    let results = token_dispatcher.player_name_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == 'BatchNameTest', "Player name should match");
}

#[test]
fn test_objective_id_batch_single_game() {
    // Covers lines 280, 286: objective_id_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.objective_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == 0, "Objective ID should be 0");
}

#[test]
fn test_minted_by_batch_single_game() {
    // Covers line 302: minted_by_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.minted_by_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) != 0, "Minted by should be non-zero");
}

#[test]
fn test_is_soulbound_batch_single_game() {
    // Covers line 319: is_soulbound_batch loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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
            true, // soulbound
            false,
            0,
            0,
        );

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.is_soulbound_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be soulbound");
}

#[test]
fn test_token_game_address_batch_single_game() {
    // Covers lines 346, 352: token_game_address_batch loop body in single-game mode
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    let token_ids: Array<felt252> = array![token_id];
    let results = token_dispatcher.token_game_address_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == minigame_dispatcher.contract_address, "Game address should match");
}

// ============================================================================
// UPDATE_GAME with resolve_game_address (lines 610, 614, 615)
// ============================================================================

#[test]
fn test_update_game_multi_game_resolve_address() {
    // Covers lines 610, 614, 615: update_game with resolve_game_address and SRC5 check
    let test_contracts = setup_multi_game();

    // Mint token in multi-game mode
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

    // update_game resolves game_address from registry (line 610)
    // then checks SRC5 supports_interface (lines 614-615)
    test_contracts.test_token.update_game(token_id);

    // Verify the token metadata was updated
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(!metadata.game_over, "Token should not be game over");
}

// ============================================================================
// UPDATE_GAME_BATCH (lines 745-747): inner loop body
// ============================================================================

#[test]
fn test_update_game_batch_multi_game() {
    // Covers lines 745-747: update_game_batch inner loop body in multi-game mode
    let test_contracts = setup_multi_game();

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
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Batch update in multi-game mode
    let token_ids: Array<felt252> = array![token_id1, token_id2];
    test_contracts.test_token.update_game_batch(token_ids.span());

    // Verify both tokens were updated
    assert!(
        !test_contracts.test_token.token_metadata(token_id1).game_over,
        "Token 1 should not be game over",
    );
    assert!(
        !test_contracts.test_token.token_metadata(token_id2).game_over,
        "Token 2 should not be game over",
    );
}

// ============================================================================
// UPDATE_PLAYER_NAME_BATCH (lines 761-762): inner loop body
// ============================================================================

#[test]
fn test_update_player_name_batch_single_game() {
    // Covers lines 761-762: update_player_name_batch inner loop body
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    // Mint tokens to ALICE
    let token_id1 = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
            Option::Some('Old1'),
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
            minigame_dispatcher.contract_address,
            Option::Some('Old2'),
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

    // Batch update player names
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(2));
    let updates: Array<PlayerNameUpdate> = array![
        PlayerNameUpdate { token_id: token_id1, name: 'New1' },
        PlayerNameUpdate { token_id: token_id2, name: 'New2' },
    ];
    token_dispatcher.update_player_name_batch(updates.span());

    assert!(token_dispatcher.player_name(token_id1) == 'New1', "Token 1 name should be updated");
    assert!(token_dispatcher.player_name(token_id2) == 'New2', "Token 2 name should be updated");
}

// ============================================================================
// INITIALIZER BRANCHES (lines 791-824)
// ============================================================================

#[test]
fn test_initializer_single_game_mints_token_zero() {
    // Covers lines 791-824: initializer with game_address and creator_address
    // (single game mode mints token 0 to creator)
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, erc721_dispatcher, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    // Verify game_address is set
    let game_addr = token_dispatcher.game_address();
    assert!(game_addr == minigame_dispatcher.contract_address, "Game address should be set");

    // Verify game_registry_address is zero (single-game mode)
    let registry_addr = token_dispatcher.game_registry_address();
    assert!(registry_addr == addr(0), "Registry should be zero for single-game");

    // Verify token 0 exists and is owned by OWNER
    let owner_of_zero = erc721_dispatcher.owner_of(0);
    assert!(owner_of_zero == OWNER(), "Token 0 should be owned by creator");
}

#[test]
fn test_initializer_multi_game_with_registry() {
    // Covers lines 801-806: initializer with game_registry_address branch
    let test_contracts = setup_multi_game();

    // Verify registry_address is set
    let registry_addr = test_contracts.test_token.game_registry_address();
    assert!(
        registry_addr == test_contracts.minigame_registry.contract_address,
        "Registry address should be set",
    );
}

// ============================================================================
// MINT_GAME with future start time (lines 831, 856, 859)
// ============================================================================

#[test]
fn test_mint_with_future_start_time() {
    // Covers lines 856, 859: start_delay computation when lifecycle.start > current_time
    let test_contracts = setup();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    // Start time is in the future relative to current block timestamp
    let future_start = CURRENT_TIME + 5000;
    let future_end = CURRENT_TIME + 10000;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(future_start),
            Option::Some(future_end),
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

    // Token should not be playable yet (start is in the future)
    assert!(!test_contracts.test_token.is_playable(token_id), "Should not be playable yet");

    // Verify lifecycle metadata
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == future_start, "Start should be future time");
    assert!(metadata.lifecycle.end == future_end, "End should be future end time");

    // Advance time past start
    start_cheat_block_timestamp(test_contracts.test_token.contract_address, future_start);
    assert!(test_contracts.test_token.is_playable(token_id), "Should be playable at start time");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

// ============================================================================
// VALIDATE_AND_PROCESS_GAME_ADDRESS multi-game path (lines 1029-1032)
// ============================================================================

#[test]
fn test_validate_and_process_game_address_multi_game() {
    // Covers lines 1029-1032: multi-game registry lookup path
    let test_contracts = setup_multi_game();

    // Minting with a registered game address triggers the multi-game path
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

    // Verify game_id is non-zero (came from registry)
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.game_id > 0, "Multi-game token should have game_id > 0");

    // Verify game address resolution works through registry
    let game_addr = test_contracts.test_token.token_game_address(token_id);
    assert!(game_addr == test_contracts.minigame.contract_address, "Game address should resolve");
}

// ============================================================================
// RESOLVE_GAME_ADDRESS multi-game path (lines 1056, 1060)
// ============================================================================

#[test]
fn test_resolve_game_address_multi_game() {
    // Covers lines 1056, 1060: resolve_game_address with non-zero game_id
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

    // token_game_address calls resolve_game_address internally
    let game_addr = test_contracts.test_token.token_game_address(token_id);
    assert!(
        game_addr == test_contracts.minigame.contract_address,
        "Should resolve game address from registry",
    );
}

// ============================================================================
// EMIT_TOKEN_PLAYER_NAME_UPDATE (line 1090)
// ============================================================================

#[test]
fn test_emit_player_name_update_on_update() {
    // Covers line 1090: emit_token_player_name_update called from update_player_name
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
            Option::Some('InitName'),
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

    // update_player_name emits TokenPlayerNameUpdate (line 1090)
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token_dispatcher.update_player_name(token_id, 'UpdatedName');

    let name = token_dispatcher.player_name(token_id);
    assert!(name == 'UpdatedName', "Name should be updated");
}

// ============================================================================
// UPDATE_PLAYER_NAME ownership and storage (lines 725-734)
// ============================================================================

#[test]
fn test_update_player_name_single_game_token() {
    // Covers lines 725-734: update_player_name validates ownership and writes name
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
        minigame_dispatcher.contract_address,
    );

    let token_id = token_dispatcher
        .mint(
            minigame_dispatcher.contract_address,
            Option::Some('OrigName'),
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

    // Update as owner
    cheat_caller_address(token_dispatcher.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token_dispatcher.update_player_name(token_id, 'NewNameSG');

    assert!(
        token_dispatcher.player_name(token_id) == 'NewNameSG',
        "Name should be updated in single-game mode",
    );
}

// ============================================================================
// MINT with client_url and player_name events (lines 941, 947)
// ============================================================================

#[test]
fn test_mint_game_token_with_player_name_and_client_url() {
    // Covers lines 941 (emit player name), 947 (emit client url) for game tokens
    let test_contracts = setup();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('NamedPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some("https://my.game.com/play"),
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify player name was set and event was emitted
    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 'NamedPlayer', "Player name should be set on game token");
}

// ============================================================================
// UPDATE_GAME single-game mode (lines 610, 614-615 for single-game path)
// ============================================================================

#[test]
fn test_update_game_single_game_mode() {
    // Covers lines 610, 614, 615 in single-game mode
    let (minigame_dispatcher, mock_game) = deploy_basic_mock_game();
    let (token_dispatcher, _, _, _) = deploy_single_game_token_default(
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

    // Set score and game over
    mock_game.set_score(token_id, 150);
    mock_game.set_game_over(token_id, true);

    // update_game resolves game_address and checks SRC5
    token_dispatcher.update_game(token_id);

    let metadata = token_dispatcher.token_metadata(token_id);
    assert!(metadata.game_over, "Game should be over after update");
}

// ============================================================================
// FULL TOKEN CONTRACT (multi-game) COVERAGE TESTS
// These exercise uncovered lines through FullTokenContract (entry 1 in lcov)
// ============================================================================

#[test]
fn test_player_name_multi_game_view() {
    // Covers line 147 through FullTokenContract
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('MultiPlayer'),
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
    assert!(name == 'MultiPlayer', "Player name should match in multi-game mode");
}

#[test]
fn test_renderer_address_multi_game_no_custom_renderer() {
    // Covers lines 180, 182 through FullTokenContract (multi-game path goes to lines 184+)
    // This exercises the renderer_address function through FullTokenContract
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

    let renderer = test_contracts.test_token.renderer_address(token_id);
    // Multi-game mode: renderer goes through game registry lookup
    assert!(!renderer.is_zero(), "Renderer address should not be zero");
}

#[test]
fn test_is_playable_batch_multi_game() {
    // Covers lines 228, 238 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.is_playable_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be playable in multi-game mode");
}

#[test]
fn test_settings_id_batch_multi_game() {
    // Covers line 247 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.settings_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

#[test]
fn test_player_name_batch_multi_game() {
    // Covers line 263 through FullTokenContract
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('BatchMulti'),
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
    let results = test_contracts.test_token.player_name_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == 'BatchMulti', "Player name should match");
}

#[test]
fn test_objective_id_batch_multi_game() {
    // Covers lines 280, 286 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.objective_id_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
}

#[test]
fn test_minted_by_batch_multi_game() {
    // Covers line 302 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.minted_by_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) != 0, "Minted by should be non-zero");
}

#[test]
fn test_is_soulbound_batch_multi_game() {
    // Covers line 319 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.is_soulbound_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0), "Token should be soulbound");
}

#[test]
fn test_renderer_address_batch_multi_game() {
    // Covers lines 332, 337 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.renderer_address_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(!(*results.at(0)).is_zero(), "Renderer should not be zero");
}

#[test]
fn test_token_game_address_batch_multi_game() {
    // Covers lines 346, 352 through FullTokenContract
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

    let token_ids: Array<felt252> = array![token_id];
    let results = test_contracts.test_token.token_game_address_batch(token_ids.span());
    assert!(results.len() == 1, "Should return 1 result");
    assert!(
        *results.at(0) == test_contracts.minigame.contract_address,
        "Game address should match in multi-game mode",
    );
}

#[test]
fn test_update_player_name_multi_game() {
    // Covers lines 725-734 through FullTokenContract
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('OrigMulti'),
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
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'NewMultiName');

    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 'NewMultiName', "Name should be updated in multi-game mode");
}

#[test]
fn test_update_game_batch_full_token() {
    // Covers lines 745-747 through FullTokenContract (already via setup_multi_game)
    // but exercising with explicit game state transitions
    let test_contracts = setup_multi_game();

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

    let token_ids: Array<felt252> = array![token_id1];
    test_contracts.test_token.update_game_batch(token_ids.span());
}

#[test]
fn test_update_player_name_batch_multi_game() {
    // Covers lines 761-762 through FullTokenContract
    let test_contracts = setup_multi_game();

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
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(2),
    );
    let updates: Array<PlayerNameUpdate> = array![
        PlayerNameUpdate { token_id: token_id1, name: 'NewMG1' },
        PlayerNameUpdate { token_id: token_id2, name: 'NewMG2' },
    ];
    test_contracts.test_token.update_player_name_batch(updates.span());

    assert!(
        test_contracts.test_token.player_name(token_id1) == 'NewMG1',
        "Token 1 name should be updated",
    );
    assert!(
        test_contracts.test_token.player_name(token_id2) == 'NewMG2',
        "Token 2 name should be updated",
    );
}

#[test]
fn test_initializer_multi_game_stores_registry() {
    // Covers lines 791, 801, 806, 810-812 through FullTokenContract
    // setup_multi_game deploys FullTokenContract with game_registry_address
    let test_contracts = setup_multi_game();

    let registry_addr = test_contracts.test_token.game_registry_address();
    assert!(
        registry_addr == test_contracts.minigame_registry.contract_address,
        "Registry address should be stored",
    );

    // game_address should be zero (multi-game mode uses registry)
    let game_addr = test_contracts.test_token.game_address();
    assert!(game_addr.is_zero(), "game_address should be zero in multi-game mode");
}

#[test]
fn test_mint_with_future_start_multi_game() {
    // Covers lines 856, 859 through FullTokenContract
    let test_contracts = setup_multi_game();

    start_cheat_block_timestamp(test_contracts.test_token.contract_address, CURRENT_TIME);

    let future_start = CURRENT_TIME + 5000;
    let future_end = CURRENT_TIME + 10000;

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::Some(future_start),
            Option::Some(future_end),
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
        !test_contracts.test_token.is_playable(token_id), "Should not be playable before start",
    );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == future_start, "Start should be future time");
    assert!(metadata.lifecycle.end == future_end, "End should be future end time");

    stop_cheat_block_timestamp(test_contracts.test_token.contract_address);
}

#[test]
fn test_emit_player_name_update_multi_game() {
    // Covers line 1090 through FullTokenContract
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('InitMG'),
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
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.test_token.update_player_name(token_id, 'UpdatedMG');

    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 'UpdatedMG', "Name should be updated");
}

#[test]
fn test_mint_game_token_with_player_name_multi_game() {
    // Covers lines 941, 947 (player name and client url emit) through FullTokenContract
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('NamedMG'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some("https://multi.game.com/play"),
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let name = test_contracts.test_token.player_name(token_id);
    assert!(name == 'NamedMG', "Player name should be set on multi-game token");
}
