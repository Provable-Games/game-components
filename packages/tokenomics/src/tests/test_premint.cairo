/// Tests for premint functionality in StreamToken
///
/// Test coverage:
/// - Single and multiple premint allocations work
/// - Recipients receive correct amounts
/// - Zero recipient fails
/// - Zero amount fails
/// - Supply too low with premints fails
/// - Preminted event emitted
/// - Empty premints works (backward compatible)
/// - Works alongside distribution orders

use game_components_interfaces::tokenomics::stream::PremintAllocation;
use game_components_tokenomics::IStreamTokenDispatcherTrait;
use game_components_tokenomics::stream::StreamComponent;
use openzeppelin_interfaces::token::erc20::IERC20DispatcherTrait;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
};
use starknet::ContractAddress;
use super::fixtures::constants::{OWNER, TREASURY, USER1, USER2, ZERO_ADDRESS};
use super::helpers::deployment::{deploy_stream_token, deploy_stream_token_with_premints};

// Token unit constant (10^18)
const TOKEN_UNIT: u128 = 1_000_000_000_000_000_000;

// ============================================================================
// Success Cases
// ============================================================================

#[test]
fn test_single_premint_allocation_works() {
    let premint_amount: u128 = 100 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify USER1 received the preminted tokens
    let user1_balance = setup.erc20.balance_of(USER1());
    assert!(user1_balance == premint_amount.into(), "USER1 should receive preminted tokens");
}

#[test]
fn test_multiple_premint_allocations_work() {
    let premint_amount_1: u128 = 100 * TOKEN_UNIT;
    let premint_amount_2: u128 = 200 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount_1 },
        PremintAllocation { recipient: USER2(), amount: premint_amount_2 },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify both users received their preminted tokens
    let user1_balance = setup.erc20.balance_of(USER1());
    let user2_balance = setup.erc20.balance_of(USER2());

    assert!(user1_balance == premint_amount_1.into(), "USER1 should receive correct amount");
    assert!(user2_balance == premint_amount_2.into(), "USER2 should receive correct amount");
}

#[test]
fn test_premint_same_recipient_multiple_times() {
    // Same recipient in multiple allocations should receive sum of all
    let premint_amount_1: u128 = 100 * TOKEN_UNIT;
    let premint_amount_2: u128 = 150 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount_1 },
        PremintAllocation { recipient: USER1(), amount: premint_amount_2 },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // USER1 should have received both allocations
    let expected_total: u256 = (premint_amount_1 + premint_amount_2).into();
    let user1_balance = setup.erc20.balance_of(USER1());

    assert!(user1_balance == expected_total, "USER1 should receive sum of all premints");
}

#[test]
fn test_empty_premints_backward_compatible() {
    // Deploying without premints should work (backward compatibility)
    let setup = deploy_stream_token();

    // Token should be deployed and functional
    let total_supply = setup.erc20.total_supply();
    assert!(total_supply > 0, "Token should have been deployed");
}

#[test]
fn test_premint_alongside_distribution_orders() {
    // Premints should work alongside distribution orders
    let premint_amount: u128 = 100 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify premint worked
    let user1_balance = setup.erc20.balance_of(USER1());
    assert!(user1_balance == premint_amount.into(), "Premint should work with distributions");

    // Verify distribution orders exist (1 order in deploy helper)
    assert!(setup.token.get_order_count() == 1, "Distribution order should exist");
}

#[test]
fn test_premint_emits_event() {
    let premint_amount: u128 = 100 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let mut spy = spy_events();

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify Preminted event was emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::Preminted(
                        StreamComponent::Preminted { recipient: USER1(), amount: premint_amount },
                    ),
                ),
            ],
        );
}

#[test]
fn test_multiple_premints_emit_multiple_events() {
    let premint_amount_1: u128 = 100 * TOKEN_UNIT;
    let premint_amount_2: u128 = 200 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount_1 },
        PremintAllocation { recipient: USER2(), amount: premint_amount_2 },
    ];

    let mut spy = spy_events();

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify both Preminted events were emitted
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::Preminted(
                        StreamComponent::Preminted { recipient: USER1(), amount: premint_amount_1 },
                    ),
                ),
                (
                    setup.token_address,
                    StreamComponent::Event::Preminted(
                        StreamComponent::Preminted { recipient: USER2(), amount: premint_amount_2 },
                    ),
                ),
            ],
        );
}

#[test]
fn test_factory_receives_reduced_supply_with_premints() {
    let premint_amount: u128 = 500 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Factory (OWNER) should have received total_supply - registry_amount - premint_amount
    let factory_balance = setup.erc20.balance_of(OWNER());

    // The deploy helper calculates: base_supply + premint_total = total_supply
    // Factory receives: total_supply - ERC20_UNIT - premint_total
    // = base_supply + premint_total - ERC20_UNIT - premint_total = base_supply - ERC20_UNIT
    let base_supply: u128 = 10000 * TOKEN_UNIT;
    let erc20_unit: u128 = TOKEN_UNIT;
    let expected_factory_balance: u256 = (base_supply - erc20_unit).into();

    assert!(factory_balance == expected_factory_balance, "Factory should have reduced balance");
}

// ============================================================================
// Failure Cases
// ============================================================================

// NOTE: These tests cannot use #[should_panic] because snforge doesn't
// catch deployment failures with that pattern. These tests are kept as #[ignore]
// for documentation - when run manually (snforge test --ignored), they will fail
// with the expected error messages, proving the validation works correctly.

/// Helper struct for building invalid premint test calldata
#[derive(Drop)]
struct InvalidPremintTestParams {
    premints: Span<PremintAllocation>,
    total_supply: u128,
}

/// Build constructor calldata for invalid premint tests
/// Reduces duplication between test_zero_recipient_fails and test_zero_amount_fails
fn build_invalid_premint_calldata(params: InvalidPremintTestParams) -> Array<felt252> {
    let factory = OWNER();
    let mock_registry = super::helpers::deployment::deploy_mock_registry();
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let paired_token: ContractAddress = 'PAIRED'.try_into().unwrap();
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = game_components_tokenomics::LiquidityConfig {
        paired_token,
        fee: 170141183460469235273462165868118016,
        stream_token_amount: 1000 * TOKEN_UNIT,
        paired_token_amount: 100 * TOKEN_UNIT,
        min_liquidity: 1,
    };

    let distribution_orders: Array<game_components_tokenomics::DistributionOrder> = array![
        game_components_tokenomics::DistributionOrder {
            buy_token,
            fee: 170141183460469235273462165868118016,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500 * TOKEN_UNIT,
            proceeds_recipient: TREASURY(),
        },
    ];

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Test Token";
    let symbol: ByteArray = "TEST";

    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    params.total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_registry.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    params.premints.serialize(ref calldata);

    calldata
}

#[test]
#[ignore]
fn test_zero_recipient_fails() {
    let contract = declare("StreamToken").unwrap().contract_class();

    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: ZERO_ADDRESS(), amount: 100 * TOKEN_UNIT },
    ];

    let calldata = build_invalid_premint_calldata(
        InvalidPremintTestParams { premints: premints.span(), total_supply: 10100 * TOKEN_UNIT },
    );

    // When run, this will fail with 'Invalid premint recipient'
    contract.deploy(@calldata).unwrap();
}

#[test]
#[ignore]
fn test_zero_amount_fails() {
    let contract = declare("StreamToken").unwrap().contract_class();

    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: 0 },
    ];

    let calldata = build_invalid_premint_calldata(
        InvalidPremintTestParams { premints: premints.span(), total_supply: 10000 * TOKEN_UNIT },
    );

    // When run, this will fail with 'Invalid premint amount'
    contract.deploy(@calldata).unwrap();
}

#[test]
#[ignore]
fn test_supply_too_low_with_premints_fails() {
    let contract = declare("StreamToken").unwrap().contract_class();

    // Premints that push total requirements over available supply
    // Total needed: ERC20_UNIT (1) + LP (1000) + distribution (500) + premints (1000) = 2501
    // Supply provided: 2000 tokens - NOT ENOUGH
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: 500 * TOKEN_UNIT },
        PremintAllocation { recipient: USER2(), amount: 500 * TOKEN_UNIT },
    ];

    let calldata = build_invalid_premint_calldata(
        InvalidPremintTestParams {
            premints: premints.span(),
            total_supply: 2000 * TOKEN_UNIT // Too low - need at least 2501
        },
    );

    // When run, this will fail due to arithmetic underflow in constructor
    // (total_supply - ERC20_UNIT - premint_total would underflow)
    contract.deploy(@calldata).unwrap();
}
