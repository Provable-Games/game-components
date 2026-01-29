// Tests to improve core_token coverage
use starknet::ContractAddress;

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}
use game_components_registry::interface::IMinigameRegistryDispatcherTrait;
use snforge_std::{
    CheatSpan, cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
use crate::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_starknet_mock::IMinigameStarknetMockDispatcherTrait;
use super::setup::{
    ALICE, BOB, CHARLIE, MAX_LIFECYCLE_TIMESTAMP, deploy_basic_mock_game,
    deploy_optimized_token_with_game, setup, setup_multi_game,
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
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('MaxPlayer'),
            Option::None,
            Option::Some(0),
            Option::Some(MAX_LIFECYCLE_TIMESTAMP),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.end == MAX_LIFECYCLE_TIMESTAMP, "Max end time should be set");
}

#[test]
fn test_core_token_batch_operations() {
    let test_contracts = setup();

    // Batch mint tokens
    let batch_size: u32 = 5;
    let mut token_ids: Array<u64> = array![];
    let mut i: u32 = 0;

    while i < batch_size {
        let token_id = test_contracts
            .test_token
            .mint(
                Option::Some(test_contracts.minigame.contract_address),
                Option::Some('BatchPlayer'),
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
        token_ids.append(token_id);
        i += 1;
    }

    // Verify sequential IDs
    let mut j = 0;
    let token_ids_len: usize = token_ids.len();
    while j < token_ids_len - 1 {
        let current = *token_ids.at(j);
        let next = *token_ids.at(j + 1);
        assert!(next == current + 1, "Token IDs should be sequential");
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
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(current_time + 1000),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Zero end time (no expiry)
    let token_id2 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(current_time),
            Option::Some(0),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
        );

    // Both zero (always playable)
    let token_id3 = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::Some(0),
            Option::Some(0),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
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
                Option::Some(test_contracts.minigame.contract_address),
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
            );

        // Verify minter is tracked
        assert!(
            test_contracts.test_token.minter_exists(address),
            "Edge address should be tracked as minter",
        );

        let minter_id = test_contracts.test_token.minted_by(token_id);
        assert!(minter_id > 0, "Should have valid minter ID");

        let retrieved_address = test_contracts.test_token.get_minter_address(minter_id);
        assert!(retrieved_address == address, "Retrieved address should match");

        i += 1;
    };
}

#[test]
#[should_panic]
fn test_set_token_metadata_invalid_caller_should_panic() {
    let test_contracts = setup();

    // Mint a blank token with ALICE as caller
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );

    let token_id = test_contracts
        .test_token
        .mint(
            Option::None, // No game - blank token
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

    // Try to set metadata with BOB as caller (different from minter ALICE)
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );

    // This should panic because BOB is not the minter of the token
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
#[should_panic(expected: "MinigameToken: Game address is zero")]
fn test_mint_with_zero_game_address_should_panic() {
    let test_contracts = setup();

    // Try to mint with zero game address - this should trigger validation
    let zero_address = addr(0);

    test_contracts
        .test_token
        .mint(
            Option::Some(zero_address),
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
#[should_panic(expected: "MinigameToken: Token 999 does not exist")]
fn test_update_game_nonexistent_token_should_panic() {
    let test_contracts = setup();

    // Try to update game for a non-existent token
    test_contracts.test_token.update_game(999);
}

#[test]
#[should_panic(expected: "MinigameToken: Token id 999 not minted")]
fn test_set_token_metadata_nonexistent_token_should_panic() {
    let test_contracts = setup();

    // Try to set metadata on a non-existent token
    test_contracts
        .test_token
        .set_token_metadata(
            999, // Non-existent token
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );
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
            Option::Some(test_contracts.minigame.contract_address),
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
            Option::Some(test_contracts.minigame.contract_address),
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
            Option::Some(test_contracts.minigame.contract_address),
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
            Option::Some(test_contracts.minigame.contract_address),
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
            Option::Some(test_contracts.minigame.contract_address),
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
