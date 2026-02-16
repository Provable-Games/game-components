/// Tests for StreamComponent burn functions
///
/// Verifies that:
/// - Users can burn their own tokens
/// - Users cannot burn more than their balance
/// - Users can burn tokens from approved accounts (burn_from)
/// - Users cannot burn from accounts without approval
/// - Allowance is correctly deducted after burn_from
/// - Transfer event is emitted correctly (to zero address)

use game_components_economy::tokenomics::IStreamTokenDispatcherTrait;
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use openzeppelin_token::erc20::ERC20Component;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::fixtures::constants::{USER1, USER2, ZERO_ADDRESS, amounts};
use super::helpers::deployment::{StreamTokenSetup, deploy_stream_token};

/// Helper to get user balance from ERC20
fn get_balance(erc20: IERC20Dispatcher, account: ContractAddress) -> u256 {
    erc20.balance_of(account)
}

/// Helper to transfer tokens from factory to a user for testing
fn setup_user_with_tokens(
    setup: @StreamTokenSetup, user: ContractAddress, amount: u256,
) -> IERC20Dispatcher {
    let erc20 = *setup.erc20;
    let factory = *setup.factory;

    // Factory transfers tokens to user
    start_cheat_caller_address(erc20.contract_address, factory);
    erc20.transfer(user, amount);
    stop_cheat_caller_address(erc20.contract_address);

    erc20
}

// ============================================================================
// burn() tests - burning own tokens
// ============================================================================

#[test]
fn test_burn_reduces_caller_balance() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount * 2);
    let initial_balance = get_balance(erc20, USER1());

    // USER1 burns tokens
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = get_balance(erc20, USER1());
    assert!(
        final_balance == initial_balance - burn_amount, "Balance should decrease by burn amount",
    );
}

#[test]
fn test_burn_reduces_total_supply() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    setup_user_with_tokens(@setup, USER1(), burn_amount);
    let initial_supply = setup.erc20.total_supply();

    // USER1 burns tokens
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let final_supply = setup.erc20.total_supply();
    assert!(
        final_supply == initial_supply - burn_amount, "Total supply should decrease by burn amount",
    );
}

#[test]
fn test_burn_emits_transfer_event_to_zero() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    setup_user_with_tokens(@setup, USER1(), burn_amount);

    let mut spy = spy_events();

    // USER1 burns tokens
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(burn_amount);
    stop_cheat_caller_address(setup.token_address);

    // Verify Transfer event emitted with `to` = zero address
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: USER1(), to: ZERO_ADDRESS(), value: burn_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_burn_entire_balance() {
    let setup = deploy_stream_token();
    let balance = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    setup_user_with_tokens(@setup, USER1(), balance);

    // USER1 burns entire balance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(balance);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = get_balance(setup.erc20, USER1());
    assert!(final_balance == 0, "Balance should be zero after burning entire balance");
}

#[test]
fn test_burn_zero_amount_succeeds() {
    let setup = deploy_stream_token();

    // Give USER1 some tokens
    setup_user_with_tokens(@setup, USER1(), amounts::HUNDRED_TOKENS);
    let initial_balance = get_balance(setup.erc20, USER1());

    // USER1 burns zero tokens (should succeed, no-op)
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(0);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = get_balance(setup.erc20, USER1());
    assert!(final_balance == initial_balance, "Balance should remain unchanged when burning zero");
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_burn_fails_with_insufficient_balance() {
    let setup = deploy_stream_token();
    let balance = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    setup_user_with_tokens(@setup, USER1(), balance);

    // USER1 tries to burn more than balance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(balance + 1);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_burn_fails_with_no_balance() {
    let setup = deploy_stream_token();

    // USER2 has no tokens, tries to burn
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn(amounts::ONE_TOKEN);
    stop_cheat_caller_address(setup.token_address);
}

// ============================================================================
// burn_from() tests - burning from approved accounts
// ============================================================================

#[test]
fn test_burn_from_with_approval_succeeds() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount * 2);

    // USER1 approves USER2 to spend tokens
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let initial_balance = get_balance(erc20, USER1());

    // USER2 burns from USER1's account
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = get_balance(erc20, USER1());
    assert!(
        final_balance == initial_balance - burn_amount,
        "USER1 balance should decrease by burn amount",
    );
}

#[test]
fn test_burn_from_reduces_total_supply() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount);

    // USER1 approves USER2
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let initial_supply = erc20.total_supply();

    // USER2 burns from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let final_supply = erc20.total_supply();
    assert!(final_supply == initial_supply - burn_amount, "Total supply should decrease");
}

#[test]
fn test_burn_from_deducts_allowance() {
    let setup = deploy_stream_token();
    let approval_amount = amounts::HUNDRED_TOKENS * 2;
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), approval_amount);

    // USER1 approves USER2 for more than burn amount
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), approval_amount);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns some tokens from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let remaining_allowance = erc20.allowance(USER1(), USER2());
    assert!(
        remaining_allowance == approval_amount - burn_amount,
        "Allowance should decrease by burn amount",
    );
}

#[test]
fn test_burn_from_emits_transfer_event() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens and approve USER2
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount);
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let mut spy = spy_events();

    // USER2 burns from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    // Verify Transfer event with from=USER1, to=zero
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: USER1(), to: ZERO_ADDRESS(), value: burn_amount,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_burn_from_fails_without_approval() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens (no approval given to USER2)
    setup_user_with_tokens(@setup, USER1(), burn_amount);

    // USER2 tries to burn from USER1 without approval
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_burn_from_fails_with_insufficient_approval() {
    let setup = deploy_stream_token();
    let approval_amount = amounts::HUNDRED_TOKENS;
    let burn_amount = approval_amount + 1;

    // Give USER1 enough tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount * 2);

    // USER1 approves USER2 for less than burn amount
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), approval_amount);
    stop_cheat_caller_address(setup.token_address);

    // USER2 tries to burn more than approved
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_burn_from_fails_when_account_has_insufficient_balance() {
    let setup = deploy_stream_token();
    let balance = amounts::HUNDRED_TOKENS;
    let burn_amount = balance + 1;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), balance);

    // USER1 approves USER2 for more than their balance
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), burn_amount * 2);
    stop_cheat_caller_address(setup.token_address);

    // USER2 tries to burn more than USER1's balance (but within allowance)
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_burn_from_with_max_approval_does_not_decrease_allowance() {
    let setup = deploy_stream_token();
    let burn_amount = amounts::HUNDRED_TOKENS;
    let max_u256: u256 = core::num::traits::Bounded::MAX;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), burn_amount * 2);

    // USER1 approves USER2 with max value (infinite approval)
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), max_u256);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), burn_amount);
    stop_cheat_caller_address(setup.token_address);

    // Allowance should remain at max (infinite approval pattern)
    let remaining_allowance = erc20.allowance(USER1(), USER2());
    assert!(remaining_allowance == max_u256, "Max allowance should not decrease");
}

#[test]
fn test_burn_from_zero_amount_succeeds() {
    let setup = deploy_stream_token();
    let approval_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 some tokens
    let erc20 = setup_user_with_tokens(@setup, USER1(), approval_amount);

    // USER1 approves USER2
    start_cheat_caller_address(setup.token_address, USER1());
    erc20.approve(USER2(), approval_amount);
    stop_cheat_caller_address(setup.token_address);

    let initial_balance = get_balance(erc20, USER1());

    // USER2 burns zero from USER1 (should succeed, no-op)
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), 0);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = get_balance(erc20, USER1());
    assert!(final_balance == initial_balance, "Balance should remain unchanged when burning zero");
}

#[test]
fn test_consecutive_burns_track_correctly() {
    let setup = deploy_stream_token();
    let total_tokens = amounts::THOUSAND_TOKENS;
    let burn_amount = amounts::HUNDRED_TOKENS;

    // Give USER1 tokens
    setup_user_with_tokens(@setup, USER1(), total_tokens);

    // Burn multiple times
    start_cheat_caller_address(setup.token_address, USER1());

    setup.token.burn(burn_amount);
    assert!(
        get_balance(setup.erc20, USER1()) == total_tokens - burn_amount, "Balance after first burn",
    );

    setup.token.burn(burn_amount);
    assert!(
        get_balance(setup.erc20, USER1()) == total_tokens - (burn_amount * 2),
        "Balance after second burn",
    );

    setup.token.burn(burn_amount);
    assert!(
        get_balance(setup.erc20, USER1()) == total_tokens - (burn_amount * 3),
        "Balance after third burn",
    );

    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_multiple_users_can_burn_independently() {
    let setup = deploy_stream_token();
    let user1_tokens = amounts::HUNDRED_TOKENS * 2;
    let user2_tokens = amounts::HUNDRED_TOKENS * 3;

    // Give both users tokens
    setup_user_with_tokens(@setup, USER1(), user1_tokens);

    // Transfer to USER2 from factory
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup.erc20.transfer(USER2(), user2_tokens);
    stop_cheat_caller_address(setup.token_address);

    // USER1 burns
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(amounts::HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn(amounts::HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        get_balance(setup.erc20, USER1()) == user1_tokens - amounts::HUNDRED_TOKENS,
        "USER1 balance incorrect",
    );
    assert!(
        get_balance(setup.erc20, USER2()) == user2_tokens - (amounts::HUNDRED_TOKENS * 2),
        "USER2 balance incorrect",
    );
}
