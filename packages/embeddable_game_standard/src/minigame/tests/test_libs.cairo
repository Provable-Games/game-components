// Test file for minigame/libs.cairo
// Tests the library functions used by the MinigameComponent

use game_components_interfaces::structs::metagame::{GameContext, GameContextDetails};
use game_components_testing::constants::{
    ALICE, BOB, CREATOR, CURRENT_TIME, FUTURE_TIME, MAX_U64, USER1, USER2,
};
use snforge_std::{mock_call, start_cheat_caller_address};
use starknet::ContractAddress;
use crate::minigame::minigame as libs;
use crate::minigame::structs::MintGameParams;

// =============================================================================
// Test Address Helpers
// =============================================================================

fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

fn GAME_ADDRESS() -> ContractAddress {
    'GAME'.try_into().unwrap()
}

fn REGISTRY_ADDRESS() -> ContractAddress {
    'REGISTRY'.try_into().unwrap()
}

// =============================================================================
// Unit Tests: pre_action
// =============================================================================

// Test LIB-U-01: pre_action with playable token
#[test]
fn test_pre_action_playable_token() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // Mock is_playable to return true
    mock_call(token_address, selector!("assert_is_playable"), (), 1);

    // Should not panic
    libs::pre_action(token_address, token_id);
}

// Test LIB-U-02: pre_action with non-playable token
#[test]
#[should_panic]
fn test_pre_action_non_playable_token() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // Mock is_playable to return false
    // No mock — dispatcher call to non-deployed contract will panic

    // Should panic
    libs::pre_action(token_address, token_id);
}

// Test LIB-U-03: pre_action with different token ids
#[test]
fn test_pre_action_multiple_tokens() {
    let token_address = TOKEN_ADDRESS();

    // Mock multiple is_playable calls
    mock_call(token_address, selector!("assert_is_playable"), (), 10);

    libs::pre_action(token_address, 1);
    libs::pre_action(token_address, 2);
    libs::pre_action(token_address, 100);
}

// =============================================================================
// Unit Tests: post_action
// =============================================================================

// Test LIB-U-04: post_action calls update_game
#[test]
fn test_post_action_updates_game() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // Mock update_game call (returns unit)
    mock_call(token_address, selector!("update_game"), (), 1);

    // Should not panic
    libs::post_action(token_address, token_id);
}

// Test LIB-U-05: post_action with multiple tokens
#[test]
fn test_post_action_multiple_tokens() {
    let token_address = TOKEN_ADDRESS();

    // Mock multiple update_game calls
    mock_call(token_address, selector!("update_game"), (), 10);

    libs::post_action(token_address, 1);
    libs::post_action(token_address, 2);
    libs::post_action(token_address, MAX_U64.into());
}

// =============================================================================
// Unit Tests: require_owned_token
// =============================================================================

// Test LIB-U-06: require_owned_token succeeds for owned token
#[test]
fn test_require_owned_token_success() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let owner = ALICE();

    // Mock owner_of to return non-zero address
    mock_call(token_address, selector!("owner_of"), owner, 1);

    // Should not panic
    libs::require_owned_token(token_address, token_id);
}

// Test LIB-U-07: require_owned_token fails for zero owner
#[test]
#[should_panic(expected: "Token 1 does not exist or is not owned by anyone")]
fn test_require_owned_token_zero_owner() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let zero_address: ContractAddress = 0.try_into().unwrap();

    // Mock owner_of to return zero address
    mock_call(token_address, selector!("owner_of"), zero_address, 1);

    // Should panic
    libs::require_owned_token(token_address, token_id);
}

// Test LIB-U-08: require_owned_token with multiple tokens
#[test]
fn test_require_owned_token_multiple() {
    let token_address = TOKEN_ADDRESS();
    let owner = ALICE();

    // Mock multiple owner_of calls
    mock_call(token_address, selector!("owner_of"), owner, 10);

    libs::require_owned_token(token_address, 1);
    libs::require_owned_token(token_address, 2);
    libs::require_owned_token(token_address, 100);
}

// =============================================================================
// Unit Tests: assert_token_ownership
// =============================================================================

// Test LIB-U-09: assert_token_ownership succeeds when caller is owner
#[test]
fn test_assert_token_ownership_caller_is_owner() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // In test context, get_caller_address() returns the test runner address
    // We need to mock owner_of to return that same address
    let test_caller = starknet::get_caller_address();

    // Mock owner_of to return the test caller address
    mock_call(token_address, selector!("owner_of"), test_caller, 1);

    // Should not panic since owner_of returns the same as get_caller_address
    libs::assert_token_ownership(token_address, token_id);
}

// Test LIB-U-10: assert_token_ownership fails when caller is not owner
#[test]
#[should_panic(expected: "Caller is not owner of token 1")]
fn test_assert_token_ownership_caller_not_owner() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let owner = ALICE();
    let non_owner = BOB();

    // Mock owner_of to return the owner address
    mock_call(token_address, selector!("owner_of"), owner, 1);

    // Cheat caller to be someone else
    start_cheat_caller_address(token_address, non_owner);

    // Should panic
    libs::assert_token_ownership(token_address, token_id);
}

// Test LIB-U-11: assert_token_ownership with different token ids
#[test]
#[should_panic(expected: "Caller is not owner of token 999")]
fn test_assert_token_ownership_different_token_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 999;
    let owner = ALICE();
    let non_owner = BOB();

    mock_call(token_address, selector!("owner_of"), owner, 1);
    start_cheat_caller_address(token_address, non_owner);

    libs::assert_token_ownership(token_address, token_id);
}

// =============================================================================
// Unit Tests: assert_game_token_playable
// =============================================================================

// Test LIB-U-12: assert_game_token_playable succeeds
#[test]
fn test_assert_game_token_playable_success() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // Mock assert_is_playable to return successfully (no panic)
    mock_call(token_address, selector!("assert_is_playable"), (), 1);

    // Should not panic
    libs::assert_game_token_playable(token_address, token_id);
}

// Test LIB-U-13: assert_game_token_playable fails when not playable
#[test]
#[should_panic]
fn test_assert_game_token_playable_not_playable() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    // No mock — dispatcher call to non-deployed contract will panic
    libs::assert_game_token_playable(token_address, token_id);
}

// =============================================================================
// Unit Tests: register_game
// =============================================================================

// Test LIB-U-14: register_game with required params only
#[test]
fn test_register_game_required_params() {
    let token_address = TOKEN_ADDRESS();
    let creator = CREATOR();

    // Mock register_game call - returns game_id (u64)
    mock_call(token_address, selector!("register_game"), 1_u64, 1);

    libs::register_game(
        token_address,
        creator,
        "Test Game",
        "A test game description",
        "Test Developer",
        "Test Publisher",
        "Puzzle",
        "https://example.com/image.png",
        Option::None, // color
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None, // royalty_fraction
        Option::None,
        1,
        Option::None,
        Option::None,
    );
}

// Test LIB-U-15: register_game with all params
#[test]
fn test_register_game_all_params() {
    let token_address = TOKEN_ADDRESS();
    let creator = CREATOR();
    let renderer = 'RENDERER'.try_into().unwrap();

    // Mock register_game call - returns game_id (u64)
    mock_call(token_address, selector!("register_game"), 2_u64, 1);

    libs::register_game(
        token_address,
        creator,
        "Full Game",
        "Full description",
        "Full Developer",
        "Full Publisher",
        "Action",
        "https://example.com/full.png",
        Option::Some("blue"),
        Option::Some("https://client.example.com"),
        Option::Some(renderer),
        Option::Some(500_u128), // 5% royalty
        Option::None,
        1,
        Option::None,
        Option::None,
    );
}

// Test LIB-U-16: register_game with partial optional params
#[test]
fn test_register_game_partial_optional() {
    let token_address = TOKEN_ADDRESS();
    let creator = CREATOR();

    // Mock register_game call - returns game_id (u64)
    mock_call(token_address, selector!("register_game"), 3_u64, 1);

    libs::register_game(
        token_address,
        creator,
        "Partial Game",
        "Partial description",
        "Partial Dev",
        "Partial Pub",
        "RPG",
        "https://example.com/partial.png",
        Option::Some("red"),
        Option::None,
        Option::None,
        Option::Some(250_u128),
        Option::None,
        1,
        Option::None,
        Option::None,
    );
}

// Test LIB-U-17: register_game with empty strings
#[test]
fn test_register_game_empty_strings() {
    let token_address = TOKEN_ADDRESS();
    let creator = CREATOR();

    // Mock register_game call - returns game_id (u64)
    mock_call(token_address, selector!("register_game"), 4_u64, 1);

    libs::register_game(
        token_address,
        creator,
        "",
        "",
        "",
        "",
        "",
        "",
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        1,
        Option::None,
        Option::None,
    );
}

// =============================================================================
// Unit Tests: mint
// =============================================================================

// Test LIB-U-18: mint with minimal params
#[test]
fn test_mint_minimal_params() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    // Mock mint call to return token_id
    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None, // player_name
        Option::None, // settings_id
        Option::None, // start
        Option::None, // end
        Option::None, // objective_id
        Option::None, // context
        Option::None, // client_url
        Option::None, // renderer_address
        Option::None,
        to,
        false, // soulbound
        false, // paymaster
        0, // salt
        0 // metadata
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-U-19: mint with all params
#[test]
fn test_mint_all_params() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let renderer = 'RENDERER'.try_into().unwrap();
    let expected_token_id: felt252 = 42;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::Some('Player1'),
        Option::Some(1_u32),
        Option::Some(CURRENT_TIME),
        Option::Some(FUTURE_TIME),
        Option::Some(5_u32),
        Option::None, // context - would need GameContextDetails
        Option::Some("https://client.url"),
        Option::Some(renderer),
        Option::None,
        to,
        true, // soulbound
        false, // paymaster
        0, // salt
        0 // metadata
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-U-20: mint soulbound token
#[test]
fn test_mint_soulbound_token() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 100;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        true, // soulbound
        false, // paymaster
        0, // salt
        0 // metadata
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-U-21: mint with settings and objective
#[test]
fn test_mint_with_settings_and_objective() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = BOB();
    let expected_token_id: felt252 = 50;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::Some('Bob'),
        Option::Some(3_u32), // settings_id
        Option::None,
        Option::None,
        Option::Some(10_u32), // objective_id
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0, // salt
        0 // metadata
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-U-22: mint with lifecycle
#[test]
fn test_mint_with_lifecycle() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = USER1();
    let expected_token_id: felt252 = 75;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::Some(100_u64), // start
        Option::Some(200_u64), // end
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0, // salt
        0 // metadata
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// =============================================================================
// Unit Tests: mint_batch
// =============================================================================

// Test LIB-U-23: mint_batch with empty array
#[test]
fn test_mint_batch_empty_array() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let mints: Array<MintGameParams> = array![];

    // No mock needed: the helper makes zero `mint` calls when the input is empty.
    let result = libs::mint_batch(token_address, game_address, mints);

    assert!(result.len() == 0, "Should return empty array");
}

// Test LIB-U-24: mint_batch with single mint
#[test]
fn test_mint_batch_single_mint() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let mint_params = MintGameParams {
        player_name: Option::Some('Player1'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let result = libs::mint_batch(token_address, game_address, array![mint_params]);

    assert!(result.len() == 1, "Should return 1 token");
    assert!(*result.at(0) == 1, "First token should be 1");
}

// Test LIB-U-25: mint_batch with multiple mints
#[test]
fn test_mint_batch_multiple_mints() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let mint1 = MintGameParams {
        player_name: Option::Some('Player1'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint2 = MintGameParams {
        player_name: Option::Some('Player2'),
        settings_id: Option::Some(1_u32),
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: BOB(),
        soulbound: true,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint3 = MintGameParams {
        player_name: Option::None,
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::Some(5_u32),
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: USER1(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    // The helper now loops `mint()` per element; mock_call returns the same
    // value each call so we just assert length.
    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 3);

    let result = libs::mint_batch(token_address, game_address, array![mint1, mint2, mint3]);

    assert!(result.len() == 3, "Should return 3 tokens");
}

// Test LIB-U-26: mint_batch with varied params
#[test]
fn test_mint_batch_varied_params() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let renderer = 'RENDERER'.try_into().unwrap();

    let mint1 = MintGameParams {
        player_name: Option::Some('Alice'),
        settings_id: Option::Some(1_u32),
        start: Option::Some(100_u64),
        end: Option::Some(200_u64),
        objective_id: Option::Some(1_u32),
        context: Option::None,
        client_url: Option::Some("https://client1.url"),
        renderer_address: Option::Some(renderer),
        skills_address: Option::None,
        to: ALICE(),
        soulbound: true,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint2 = MintGameParams {
        player_name: Option::None,
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: BOB(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 10;
    mock_call(token_address, selector!("mint"), expected_token_id, 2);

    let result = libs::mint_batch(token_address, game_address, array![mint1, mint2]);

    assert!(result.len() == 2, "Should return 2 tokens");
}

// Test LIB-U-27: mint_batch to multiple recipients
#[test]
fn test_mint_batch_multiple_recipients() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let recipients = array![ALICE(), BOB(), USER1(), USER2()];
    let mut mints: Array<MintGameParams> = array![];

    let mut i: u32 = 0;
    loop {
        if i >= recipients.len() {
            break;
        }
        mints
            .append(
                MintGameParams {
                    player_name: Option::None,
                    settings_id: Option::None,
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    skills_address: Option::None,
                    to: *recipients.at(i),
                    soulbound: false,
                    paymaster: false,
                    salt: 0,
                    metadata: 0,
                },
            );
        i += 1;
    }

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 4);

    let result = libs::mint_batch(token_address, game_address, mints);

    assert!(result.len() == 4, "Should return 4 tokens");
}

// =============================================================================
// Unit Tests: get_player_name
// =============================================================================

// Test LIB-U-28: get_player_name returns name
#[test]
fn test_get_player_name_exists() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let expected_name: felt252 = 'Alice';

    mock_call(token_address, selector!("player_name"), expected_name, 1);

    let name = libs::get_player_name(token_address, token_id);

    assert!(name == expected_name, "Player name mismatch");
}

// Test LIB-U-29: get_player_name returns empty
#[test]
fn test_get_player_name_empty() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;
    let expected_name: felt252 = 0;

    mock_call(token_address, selector!("player_name"), expected_name, 1);

    let name = libs::get_player_name(token_address, token_id);

    assert!(name == 0, "Player name should be zero");
}

// Test LIB-U-30: get_player_name for different tokens
#[test]
fn test_get_player_name_different_tokens() {
    let token_address = TOKEN_ADDRESS();
    let name1: felt252 = 'Player1';
    let name2: felt252 = 'Player2';

    // Mock first call
    mock_call(token_address, selector!("player_name"), name1, 1);
    let result1 = libs::get_player_name(token_address, 1);
    assert!(result1 == name1, "First player name mismatch");

    // Mock second call
    mock_call(token_address, selector!("player_name"), name2, 1);
    let result2 = libs::get_player_name(token_address, 2);
    assert!(result2 == name2, "Second player name mismatch");
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test LIB-F-01: Fuzz settings_id in mint
#[test]
#[fuzzer]
fn test_mint_fuzz_settings_id(settings_id: u32) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::Some(settings_id),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-F-02: Fuzz objective_id in mint
#[test]
#[fuzzer]
fn test_mint_fuzz_objective_id(objective_id: u32) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(objective_id),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-F-03: Fuzz token_id for ownership check
#[test]
#[fuzzer]
fn test_require_owned_token_fuzz(token_id: felt252) {
    let token_address = TOKEN_ADDRESS();
    let owner = ALICE();

    mock_call(token_address, selector!("owner_of"), owner, 1);

    libs::require_owned_token(token_address, token_id);
}

// Test LIB-F-04: Fuzz player_name in mint
#[test]
#[fuzzer]
fn test_mint_fuzz_player_name(player_name: felt252) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::Some(player_name),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-F-05: Fuzz player_name retrieval
#[test]
#[fuzzer]
fn test_get_player_name_fuzz(expected_name: felt252) {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = 1;

    mock_call(token_address, selector!("player_name"), expected_name, 1);

    let name = libs::get_player_name(token_address, token_id);

    assert!(name == expected_name, "Player name mismatch");
}

// =============================================================================
// Additional Edge Case Tests
// =============================================================================

// Test LIB-E-01: mint_batch with large batch
#[test]
fn test_mint_batch_large_batch() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    // Create array with 10 mints
    let mut mints: Array<MintGameParams> = array![];

    let mut i: u32 = 0;
    loop {
        if i >= 10 {
            break;
        }
        mints
            .append(
                MintGameParams {
                    player_name: Option::None,
                    settings_id: Option::None,
                    start: Option::None,
                    end: Option::None,
                    objective_id: Option::None,
                    context: Option::None,
                    client_url: Option::None,
                    renderer_address: Option::None,
                    skills_address: Option::None,
                    to: ALICE(),
                    soulbound: false,
                    paymaster: false,
                    salt: 0,
                    metadata: 0,
                },
            );
        i += 1;
    }

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 10);

    let result = libs::mint_batch(token_address, game_address, mints);

    assert!(result.len() == 10, "Should return 10 tokens");
}

// Test LIB-E-02: mint_batch with client_url in some entries
#[test]
fn test_mint_batch_with_client_url() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let mint1 = MintGameParams {
        player_name: Option::None,
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::Some("https://client1.example.com"),
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint2 = MintGameParams {
        player_name: Option::None,
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None,
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: BOB(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 2);

    let result = libs::mint_batch(token_address, game_address, array![mint1, mint2]);

    assert!(result.len() == 2, "Should return 2 tokens");
}

// Test LIB-E-03: mint with client_url
#[test]
fn test_mint_with_client_url() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some("https://game-client.example.com"),
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-E-04: mint with renderer_address
#[test]
fn test_mint_with_renderer_address() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let renderer_address: starknet::ContractAddress = 'RENDERER'.try_into().unwrap();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(renderer_address),
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-E-05: assert_game_token_playable with max token_id
#[test]
fn test_assert_game_token_playable_max_token_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = MAX_U64.into();

    mock_call(token_address, selector!("assert_is_playable"), (), 1);

    libs::assert_game_token_playable(token_address, token_id);
}

// Test LIB-E-06: register_game with max royalty_fraction
#[test]
fn test_register_game_max_royalty() {
    let token_address = TOKEN_ADDRESS();
    let creator = CREATOR();

    mock_call(token_address, selector!("register_game"), 1_u64, 1);

    libs::register_game(
        token_address,
        creator,
        "Test Game",
        "Test Description",
        "Developer",
        "Publisher",
        "Genre",
        "https://image.url",
        Option::None,
        Option::None,
        Option::None,
        Option::Some(10000_u128), // 100% royalty
        Option::None,
        1,
        Option::None,
        Option::None,
    );
}

// Test LIB-E-07: pre_action with max token_id
#[test]
fn test_pre_action_max_token_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = MAX_U64.into();

    mock_call(token_address, selector!("assert_is_playable"), (), 1);

    libs::pre_action(token_address, token_id);
}

// Test LIB-E-08: post_action with max token_id
#[test]
fn test_post_action_max_token_id() {
    let token_address = TOKEN_ADDRESS();
    let token_id: felt252 = MAX_U64.into();

    mock_call(token_address, selector!("update_game"), (), 1);

    libs::post_action(token_address, token_id);
}

// =============================================================================
// Additional Fuzz Tests
// =============================================================================

// Test LIB-F-06: Fuzz pre_action with random token_id
#[test]
#[fuzzer]
fn test_pre_action_fuzz(token_id: felt252) {
    let token_address = TOKEN_ADDRESS();

    mock_call(token_address, selector!("assert_is_playable"), (), 1);

    libs::pre_action(token_address, token_id);
}

// Test LIB-F-07: Fuzz post_action with random token_id
#[test]
#[fuzzer]
fn test_post_action_fuzz(token_id: felt252) {
    let token_address = TOKEN_ADDRESS();

    mock_call(token_address, selector!("update_game"), (), 1);

    libs::post_action(token_address, token_id);
}

// Test LIB-F-08: Fuzz mint with random start/end times
#[test]
#[fuzzer]
fn test_mint_fuzz_lifecycle(start: u64, end: u64) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::Some(start),
        Option::Some(end),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-F-09: Fuzz mint with random soulbound flag
#[test]
#[fuzzer]
fn test_mint_fuzz_soulbound(soulbound: bool) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        to,
        soulbound,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// =============================================================================
// Tests with GameContextDetails
// =============================================================================

// Test LIB-CTX-01: mint with context
#[test]
fn test_mint_with_context() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    let context = GameContextDetails {
        name: "Test Context",
        description: "A test context",
        id: Option::Some(1_u32),
        context: array![GameContext { name: 'key1', value: 'value1' }].span(),
    };

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::Some('Player1'),
        Option::None,
        Option::None,
        Option::None,
        Option::None,
        Option::Some(context),
        Option::None,
        Option::None,
        Option::None,
        to,
        false,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-CTX-02: mint_batch with context in entries
#[test]
fn test_mint_batch_with_context() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let context1 = GameContextDetails {
        name: "Context 1",
        description: "First context",
        id: Option::Some(1_u32),
        context: array![
            GameContext { name: 'level', value: '1' }, GameContext { name: 'mode', value: 'easy' },
        ]
            .span(),
    };

    let context2 = GameContextDetails {
        name: "Context 2",
        description: "Second context",
        id: Option::None,
        context: array![GameContext { name: 'level', value: '5' }].span(),
    };

    let mint1 = MintGameParams {
        player_name: Option::Some('Player1'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::Some(context1),
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint2 = MintGameParams {
        player_name: Option::Some('Player2'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::Some(context2),
        client_url: Option::Some("https://client.url"),
        renderer_address: Option::None,
        skills_address: Option::None,
        to: BOB(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 2);

    let result = libs::mint_batch(token_address, game_address, array![mint1, mint2]);

    assert!(result.len() == 2, "Should return 2 tokens");
}

// Test LIB-CTX-03: mint_batch with mixed context (some with, some without)
#[test]
fn test_mint_batch_mixed_context() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let context = GameContextDetails {
        name: "Mixed Context",
        description: "A mixed batch context",
        id: Option::Some(42_u32),
        context: array![GameContext { name: 'test', value: 'mixed' }].span(),
    };

    let mint1 = MintGameParams {
        player_name: Option::Some('Player1'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::Some(context),
        client_url: Option::Some("https://url1.com"),
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint2 = MintGameParams {
        player_name: Option::Some('Player2'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::None, // No context
        client_url: Option::None, // No client_url
        renderer_address: Option::None,
        skills_address: Option::None,
        to: BOB(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let mint3 = MintGameParams {
        player_name: Option::None,
        settings_id: Option::Some(5_u32),
        start: Option::Some(100_u64),
        end: Option::Some(200_u64),
        objective_id: Option::Some(10_u32),
        context: Option::None,
        client_url: Option::Some("https://url3.com"),
        renderer_address: Option::None,
        skills_address: Option::None,
        to: USER1(),
        soulbound: true,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 3);

    let result = libs::mint_batch(token_address, game_address, array![mint1, mint2, mint3]);

    assert!(result.len() == 3, "Should return 3 tokens");
}

// Test LIB-CTX-04: mint with context and all other optional params
#[test]
fn test_mint_with_context_and_all_params() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let renderer = 'RENDERER'.try_into().unwrap();
    let to = ALICE();
    let expected_token_id: felt252 = 1;

    let context = GameContextDetails {
        name: "Full Context",
        description: "A fully specified context",
        id: Option::Some(100_u32),
        context: array![
            GameContext { name: 'difficulty', value: 'hard' },
            GameContext { name: 'multiplayer', value: 'true' },
            GameContext { name: 'max_players', value: '4' },
        ]
            .span(),
    };

    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let token_id = libs::mint(
        token_address,
        game_address,
        Option::Some('FullPlayer'),
        Option::Some(3_u32),
        Option::Some(CURRENT_TIME),
        Option::Some(FUTURE_TIME),
        Option::Some(7_u32),
        Option::Some(context),
        Option::Some("https://full-client.example.com"),
        Option::Some(renderer),
        Option::None,
        to,
        true,
        false,
        0,
        0,
    );

    assert!(token_id == expected_token_id, "Token ID mismatch");
}

// Test LIB-CTX-05: mint_batch with empty context span
#[test]
fn test_mint_batch_with_empty_context_span() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();

    let empty_context = GameContextDetails {
        name: "Empty Context",
        description: "Context with empty span",
        id: Option::None,
        context: array![].span() // Empty context span
    };

    let mint = MintGameParams {
        player_name: Option::Some('Player1'),
        settings_id: Option::None,
        start: Option::None,
        end: Option::None,
        objective_id: Option::None,
        context: Option::Some(empty_context),
        client_url: Option::None,
        renderer_address: Option::None,
        skills_address: Option::None,
        to: ALICE(),
        soulbound: false,
        paymaster: false,
        salt: 0,
        metadata: 0,
    };

    let expected_token_id: felt252 = 1;
    mock_call(token_address, selector!("mint"), expected_token_id, 1);

    let result = libs::mint_batch(token_address, game_address, array![mint]);

    assert!(result.len() == 1, "Should return 1 token");
}
