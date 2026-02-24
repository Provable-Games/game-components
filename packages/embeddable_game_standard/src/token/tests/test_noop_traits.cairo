// Test file for token/core/noop_traits.cairo
// Tests no-operation implementations of optional token features
//
// NoOp traits are tested through the MinimalOptimizedContract which uses:
// - NoOpObjectives
// - NoOpSettings
// - NoOpContext
// - NoOpSoulbound
// - NoOpRenderer
//
// The MinimalOptimizedContract has these features DISABLED:
// - SETTINGS_ENABLED = false
// - RENDERER_ENABLED = false
// - OBJECTIVES_ENABLED = false
// - CONTEXT_ENABLED = false
// - SOULBOUND_ENABLED = false
//
// Therefore, we test that:
// 1. Minting works even with params for disabled features
// 2. Transfers work (soulbound is disabled = always transferable)
// 3. Token metadata is correctly set for enabled features

use openzeppelin_interfaces::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use snforge_std::{CheatSpan, cheat_caller_address};
use starknet::ContractAddress;
use crate::token::interface::{IMinigameTokenMixinDispatcher, IMinigameTokenMixinDispatcherTrait};

// Import setup helpers
use super::setup::{ALICE, BOB, deploy_basic_mock_game, deploy_minimal_optimized_contract};

// =============================================================================
// TEST HELPERS
// =============================================================================

/// Deploy minimal optimized contract for NoOp testing
fn deploy_noop_test_contract() -> (
    IMinigameTokenMixinDispatcher, ERC721ABIDispatcher, ContractAddress,
) {
    let (minigame_dispatcher, _) = deploy_basic_mock_game();
    let game_addr = minigame_dispatcher.contract_address;
    let (token, erc721) = deploy_minimal_optimized_contract(
        "NoOpTestToken",
        "NOOP",
        "https://noop.test/",
        Option::Some(game_addr),
        Option::Some(game_addr),
    );
    (token, erc721, game_addr)
}

/// Mint a token for testing using the correct mint signature:
/// mint(game_address, player_name, settings_id, start, end, objective_id, context, client_url,
/// renderer_address, to, soulbound)
fn mint_test_token(
    token: IMinigameTokenMixinDispatcher, game_addr: ContractAddress, to: ContractAddress,
) -> felt252 {
    token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            to,
            false, // soulbound
            false,
            0,
            0,
        )
}

// =============================================================================
// NOOP SOULBOUND TESTS
// =============================================================================

// NoOpSoulbound::check_transfer_allowed should always return true
// This means all transfers are allowed when soulbound feature is disabled

#[test]
fn test_noop_soulbound_transfer_always_allowed() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    // Mint a token
    let token_id = mint_test_token(token, game_addr, ALICE());

    // Transfer should work because NoOpSoulbound::check_transfer_allowed returns true
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());

    assert!(erc721.owner_of(token_id.into()) == BOB(), "Transfer should succeed with NoOp");
}

#[test]
fn test_noop_soulbound_mint_with_soulbound_flag_still_transferable() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    // Mint a token with soulbound=true, but NoOpSoulbound ignores this
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            true, // soulbound flag - ignored by NoOp
            false,
            0,
            0,
        );

    // Transfer should still work because NoOpSoulbound always returns true
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());

    assert!(
        erc721.owner_of(token_id.into()) == BOB(),
        "Transfer should succeed even with soulbound flag",
    );
}

#[test]
fn test_noop_soulbound_multiple_transfers() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    let token_id = mint_test_token(token, game_addr, ALICE());

    // First transfer
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());

    // Second transfer
    cheat_caller_address(token.contract_address, BOB(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(BOB(), ALICE(), token_id.into());

    assert!(erc721.owner_of(token_id.into()) == ALICE(), "Multiple transfers should work");
}

// =============================================================================
// NOOP OBJECTIVES TESTS
// =============================================================================

// NoOpObjectives::validate_objective should be a no-op (never panics)
// Minting with any objective_id should succeed

#[test]
fn test_noop_objectives_mint_with_any_objective_id() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint with an arbitrary objective_id - NoOp should not validate it
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::Some(999_u32), // objective_id - not validated by NoOp
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Token should be minted successfully
    assert!(token_id != 0, "Token should be minted despite invalid objective_id");
}

#[test]
fn test_noop_objectives_completed_returns_false() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    let token_id = mint_test_token(token, game_addr, ALICE());

    // Check metadata - completed_objective should be false
    let metadata = token.token_metadata(token_id);
    assert!(!metadata.completed_objective, "NoOp should never mark objectives complete");
}

#[test]
fn test_noop_objectives_mint_with_max_objective_id() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint with max 30-bit objective_id - NoOp should not validate
    // objective_id is packed into 30 bits in PackedTokenId
    let max_30_bit: u32 = 0x3FFFFFFF;
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::None, // settings_id
            Option::None, // start
            Option::None, // end
            Option::Some(max_30_bit), // max objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token should be minted with max objective_id");
}

// =============================================================================
// NOOP SETTINGS TESTS
// =============================================================================

// NoOpSettings::validate_settings should be a no-op (never panics)
// Minting with any settings_id should succeed

#[test]
fn test_noop_settings_mint_with_any_settings_id() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint with an arbitrary settings_id - NoOp should not validate it
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::Some(999_u32), // settings_id - not validated by NoOp
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Token should be minted successfully
    assert!(token_id != 0, "Token should be minted despite invalid settings_id");
}

#[test]
fn test_noop_settings_mint_with_max_settings_id() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint with max 30-bit settings_id - NoOp should not validate
    // settings_id is packed into 30 bits in PackedTokenId
    let max_30_bit: u32 = 0x3FFFFFFF;
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::Some(max_30_bit), // max settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token should be minted with max settings_id");
}

#[test]
fn test_noop_settings_mint_with_zero_settings_id() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint with zero settings_id
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::Some(0_u32), // zero settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(token_id != 0, "Token should be minted with zero settings_id");
}

// =============================================================================
// NOOP CONTEXT TESTS
// =============================================================================

// NoOpContext::emit_context should be a no-op (no event emitted, no panic)

#[test]
fn test_noop_context_mint_without_context() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    // Mint without context
    let token_id = mint_test_token(token, game_addr, ALICE());

    // Verify has_context is false
    let metadata = token.token_metadata(token_id);
    assert!(!metadata.has_context, "Should not have context");
}

#[test]
fn test_noop_context_token_metadata_has_context_false() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    let token_id = mint_test_token(token, game_addr, ALICE());

    // has_context should always be false with NoOp
    let metadata = token.token_metadata(token_id);
    assert!(!metadata.has_context, "NoOp should always have has_context=false");
}

// =============================================================================
// NOOP COMBINATION TESTS
// =============================================================================

#[test]
fn test_noop_all_features_mint_full_params() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    // Mint with all optional parameters that would normally require feature validation
    let renderer_addr: ContractAddress = 'RENDERER'.try_into().unwrap();
    let token_id = token
        .mint(
            game_addr, // game_address
            Option::Some('TestPlayer'), // player_name
            Option::Some(12345_u32), // settings_id - not validated by NoOp
            Option::Some(100_u64), // start
            Option::Some(1000_u64), // end
            Option::Some(67890_u32), // objective_id - not validated by NoOp
            Option::None, // context
            Option::None, // client_url
            Option::Some(renderer_addr), // renderer_address - not validated by NoOp
            ALICE(),
            true, // soulbound - not enforced by NoOp
            false,
            0,
            0,
        );

    // Verify token was minted
    assert!(token_id != 0, "Token should be minted with all NoOp features");
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "ALICE should own the token");

    // Verify metadata (only fields that are always set)
    let metadata = token.token_metadata(token_id);
    assert!(!metadata.has_context, "Context should be false (NoOp)");
    assert!(!metadata.completed_objective, "completed_objective should be false (NoOp)");

    // Transfer should work (NoOpSoulbound allows all transfers)
    cheat_caller_address(token.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    erc721.transfer_from(ALICE(), BOB(), token_id.into());
    assert!(
        erc721.owner_of(token_id.into()) == BOB(), "Transfer should work despite soulbound flag",
    );
}

#[test]
fn test_noop_multiple_tokens_different_configs() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    // Mint tokens with different configurations
    let token_id1 = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::Some(1_u32), // settings_id
            Option::None, // start
            Option::None, // end
            Option::None, // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = token
        .mint(
            game_addr, // game_address
            Option::None, // player_name
            Option::Some(2_u32), // settings_id
            Option::None, // start
            Option::None, // end
            Option::Some(100_u32), // objective_id
            Option::None, // context
            Option::None, // client_url
            Option::None, // renderer_address
            BOB(),
            true,
            false,
            1,
            0,
        );

    // Both should succeed
    assert!(token_id1 != 0, "Token 1 should be minted");
    assert!(token_id2 != token_id1, "Token 2 should have different ID");

    // Verify ownership
    assert!(erc721.owner_of(token_id1.into()) == ALICE(), "ALICE should own token 1");
    assert!(erc721.owner_of(token_id2.into()) == BOB(), "BOB should own token 2");
}

// =============================================================================
// NOOP DEFAULT BEHAVIOR TESTS
// =============================================================================

#[test]
fn test_noop_returns_expected_defaults() {
    let (token, _, game_addr) = deploy_noop_test_contract();

    let token_id = mint_test_token(token, game_addr, ALICE());

    let metadata = token.token_metadata(token_id);

    // NoOp defaults:
    // - Soulbound: check_transfer_allowed returns true (transfers allowed)
    // - Objectives: is_objective_completed returns false
    // - Context: emit_context is no-op (no event)

    assert!(!metadata.has_context, "NoOpContext: has_context should be false");
    assert!(!metadata.completed_objective, "NoOpObjectives: completed_objective should be false");
}

#[test]
fn test_noop_mint_basic() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    let token_id = mint_test_token(token, game_addr, ALICE());

    // Verify basic functionality
    assert!(token_id != 0, "First token should not be ID 0");
    assert!(erc721.owner_of(token_id.into()) == ALICE(), "ALICE should own the token");
    assert!(erc721.balance_of(ALICE()) == 1, "Balance should be 1");
}

#[test]
fn test_noop_mint_multiple() {
    let (token, erc721, game_addr) = deploy_noop_test_contract();

    let token_id1 = token
        .mint(
            game_addr,
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
    let token_id2 = token
        .mint(
            game_addr,
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
    let token_id3 = token
        .mint(
            game_addr,
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

    // Verify non-zero and unique IDs
    assert!(token_id1 != 0, "First token ID should not be 0");
    assert!(token_id2 != 0, "Second token ID should not be 0");
    assert!(token_id3 != 0, "Third token ID should not be 0");
    assert!(token_id1 != token_id2, "Token IDs should be unique");
    assert!(token_id2 != token_id3, "Token IDs should be unique");
    assert!(token_id1 != token_id3, "Token IDs should be unique");

    // Verify ownership
    assert!(erc721.owner_of(token_id1.into()) == ALICE(), "ALICE should own token 1");
    assert!(erc721.owner_of(token_id2.into()) == BOB(), "BOB should own token 2");
    assert!(erc721.owner_of(token_id3.into()) == ALICE(), "ALICE should own token 3");

    // Verify balances
    assert!(erc721.balance_of(ALICE()) == 2, "ALICE balance should be 2");
    assert!(erc721.balance_of(BOB()) == 1, "BOB balance should be 1");
}
