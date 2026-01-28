// ==============================================================================
// STREAM TOKEN PRESET CONTRACT TESTS
// ==============================================================================
// Tests for the ready-to-deploy StreamToken contract that provides
// ERC20 functionality with built-in TWAMM distribution capabilities.
//
// These tests cover:
// - Constructor initialization
// - ERC20 standard functions
// - Burn functionality
// - Distribution order queries
// - Deployment state machine
// - Factory-only setup functions

use ekubo::types::i129::i129;
use game_components_interfaces::tokenomics::stream::{
    DistributionOrder, IStreamTokenDispatcher, IStreamTokenDispatcherTrait,
    IStreamTokenSetupDispatcher, IStreamTokenSetupDispatcherTrait, LiquidityConfig,
    PremintAllocation,
};
use game_components_testing::constants::{OWNER, USER1, USER2};
use openzeppelin_interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use openzeppelin_token::erc20::ERC20Component;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::{IMockTokenRegistryDispatcher, IMockTokenRegistryDispatcherTrait};

// ==============================================================================
// CONSTANTS
// ==============================================================================

fn TREASURY() -> ContractAddress {
    'TREASURY'.try_into().unwrap()
}

fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

/// Default fee (0.3%)
const DEFAULT_FEE: u128 = 170141183460469235273462165868118016;

/// 1 token with 18 decimals
const ONE_TOKEN: u256 = 1000000000000000000;

/// 100 tokens with 18 decimals
const HUNDRED_TOKENS: u256 = 100000000000000000000;

/// 1000 tokens with 18 decimals
const THOUSAND_TOKENS: u256 = 1000000000000000000000;

/// ERC20 unit (1 token = 10^18)
const ERC20_UNIT: u128 = 1000000000000000000;

// ==============================================================================
// DEPLOYMENT HELPERS
// ==============================================================================

fn deploy_mock_registry() -> ContractAddress {
    let contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

#[derive(Drop)]
struct StreamTokenSetup {
    token_address: ContractAddress,
    token: IStreamTokenDispatcher,
    setup: IStreamTokenSetupDispatcher,
    erc20: IERC20Dispatcher,
    factory: ContractAddress,
    registry: ContractAddress,
}

fn deploy_stream_token() -> StreamTokenSetup {
    let contract = declare("StreamToken").unwrap().contract_class();

    // Factory is the caller/deployer
    let factory = OWNER();
    let mock_registry = deploy_mock_registry();

    // Mock Ekubo addresses
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // Paired token for liquidity
    let paired_token: ContractAddress = 'PAIRED'.try_into().unwrap();

    // Buy token for distribution
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    // Liquidity config
    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: DEFAULT_FEE,
        initial_tick: i129 { mag: 0, sign: false },
        stream_token_amount: 1000_u128 * ERC20_UNIT,
        paired_token_amount: 100_u128 * ERC20_UNIT,
        min_liquidity: 1,
    };

    // Distribution orders
    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7, // 1 week
            amount: 500_u128 * ERC20_UNIT,
            proceeds_recipient: TREASURY(),
        },
    ];

    // Total supply
    let total_supply: u128 = 10000_u128 * ERC20_UNIT;

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Stream Token";
    let symbol: ByteArray = "STREAM";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_registry.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    let empty_premints: Array<PremintAllocation> = array![];
    empty_premints.span().serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    StreamTokenSetup {
        token_address,
        token: IStreamTokenDispatcher { contract_address: token_address },
        setup: IStreamTokenSetupDispatcher { contract_address: token_address },
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
        registry: mock_registry,
    }
}

fn deploy_stream_token_with_multiple_orders() -> StreamTokenSetup {
    let contract = declare("StreamToken").unwrap().contract_class();

    let factory = OWNER();
    let mock_registry = deploy_mock_registry();
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let paired_token: ContractAddress = 'PAIRED'.try_into().unwrap();
    let buy_token_1: ContractAddress = 'BUY_TOKEN1'.try_into().unwrap();
    let buy_token_2: ContractAddress = 'BUY_TOKEN2'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: DEFAULT_FEE,
        initial_tick: i129 { mag: 0, sign: false },
        stream_token_amount: 1000_u128 * ERC20_UNIT,
        paired_token_amount: 100_u128 * ERC20_UNIT,
        min_liquidity: 1,
    };

    // Multiple distribution orders
    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token: buy_token_1,
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 300_u128 * ERC20_UNIT,
            proceeds_recipient: TREASURY(),
        },
        DistributionOrder {
            buy_token: buy_token_2,
            fee: DEFAULT_FEE,
            start_time: 86400,
            end_time: 86400 * 14,
            amount: 200_u128 * ERC20_UNIT,
            proceeds_recipient: USER1(),
        },
        DistributionOrder {
            buy_token: buy_token_1, // Same as first
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 30,
            amount: 100_u128 * ERC20_UNIT,
            proceeds_recipient: USER2(),
        },
    ];

    let total_supply: u128 = 10000_u128 * ERC20_UNIT;

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Multi Order Token";
    let symbol: ByteArray = "MULTI";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_registry.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    let empty_premints: Array<PremintAllocation> = array![];
    empty_premints.span().serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    StreamTokenSetup {
        token_address,
        token: IStreamTokenDispatcher { contract_address: token_address },
        setup: IStreamTokenSetupDispatcher { contract_address: token_address },
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
        registry: mock_registry,
    }
}

// ==============================================================================
// CONSTRUCTOR TESTS
// ==============================================================================

#[test]
fn test_constructor_initializes_name_and_symbol() {
    let setup = deploy_stream_token();
    let metadata = IERC20MetadataDispatcher { contract_address: setup.token_address };

    assert!(metadata.name() == "Stream Token", "Name mismatch");
    assert!(metadata.symbol() == "STREAM", "Symbol mismatch");
}

#[test]
fn test_constructor_sets_decimals_to_18() {
    let setup = deploy_stream_token();
    let metadata = IERC20MetadataDispatcher { contract_address: setup.token_address };

    assert!(metadata.decimals() == 18, "Decimals should be 18");
}

#[test]
fn test_constructor_mints_one_token_to_registry() {
    let setup = deploy_stream_token();

    let registry_balance = setup.erc20.balance_of(setup.registry);
    assert!(registry_balance == ONE_TOKEN, "Registry should have 1 token");
}

#[test]
fn test_constructor_mints_remaining_supply_to_factory() {
    let setup = deploy_stream_token();

    // Total supply is 10000 tokens, registry gets 1
    let expected_factory_balance: u256 = (10000_u128 * ERC20_UNIT - ERC20_UNIT).into();
    let factory_balance = setup.erc20.balance_of(setup.factory);
    assert!(factory_balance == expected_factory_balance, "Factory balance mismatch");
}

#[test]
fn test_constructor_stores_distribution_orders() {
    let setup = deploy_stream_token();

    assert!(setup.token.get_order_count() == 1, "Should have 1 order");

    let order = setup.token.get_order(0);
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();
    assert!(order.buy_token == buy_token, "Order buy_token mismatch");
    assert!(order.amount == 500_u128 * ERC20_UNIT, "Order amount mismatch");
    assert!(order.proceeds_recipient == TREASURY(), "Order recipient mismatch");
}

#[test]
fn test_constructor_registers_token_with_registry() {
    let setup = deploy_stream_token();

    let registry = IMockTokenRegistryDispatcher { contract_address: setup.registry };
    assert!(registry.get_registered_count() == 1, "Token should be registered");
}

#[test]
fn test_constructor_sets_deployment_state_to_zero() {
    let setup = deploy_stream_token();

    assert!(setup.token.get_deployment_state() == 0, "Initial state should be 0");
    assert!(!setup.token.is_initialized(), "Should not be initialized");
}

// ==============================================================================
// ERC20 STANDARD FUNCTION TESTS
// ==============================================================================

#[test]
fn test_total_supply() {
    let setup = deploy_stream_token();

    let total_supply = setup.erc20.total_supply();
    let expected: u256 = (10000_u128 * ERC20_UNIT).into();
    assert!(total_supply == expected, "Total supply mismatch");
}

#[test]
fn test_balance_of() {
    let setup = deploy_stream_token();

    let balance = setup.erc20.balance_of(setup.factory);
    assert!(balance > 0, "Factory should have balance");
}

#[test]
fn test_transfer_succeeds_with_sufficient_balance() {
    let setup = deploy_stream_token();

    // Factory transfers to USER1
    start_cheat_caller_address(setup.token_address, setup.factory);
    let result = setup.erc20.transfer(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(result, "Transfer should return true");
    assert!(setup.erc20.balance_of(USER1()) == HUNDRED_TOKENS, "USER1 balance mismatch");
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_transfer_fails_with_insufficient_balance() {
    let setup = deploy_stream_token();

    // USER1 has no tokens
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_approve_sets_allowance() {
    let setup = deploy_stream_token();

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup.erc20.approve(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    let allowance = setup.erc20.allowance(setup.factory, USER1());
    assert!(allowance == HUNDRED_TOKENS, "Allowance mismatch");
}

#[test]
fn test_transfer_from_with_approval_succeeds() {
    let setup = deploy_stream_token();

    // Factory approves USER1
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup.erc20.approve(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // USER1 transfers from factory to USER2
    start_cheat_caller_address(setup.token_address, USER1());
    let result = setup.erc20.transfer_from(setup.factory, USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(result, "Transfer from should return true");
    assert!(setup.erc20.balance_of(USER2()) == HUNDRED_TOKENS, "USER2 balance mismatch");
}

// ==============================================================================
// BURN FUNCTION TESTS
// ==============================================================================

fn setup_user_with_tokens(
    setup: @StreamTokenSetup, user: ContractAddress, amount: u256,
) -> IERC20Dispatcher {
    let erc20 = *setup.erc20;
    let factory = *setup.factory;

    start_cheat_caller_address(*setup.token_address, factory);
    erc20.transfer(user, amount);
    stop_cheat_caller_address(*setup.token_address);

    erc20
}

#[test]
fn test_burn_reduces_caller_balance() {
    let setup = deploy_stream_token();

    // Give USER1 tokens
    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 2);
    let initial_balance = setup.erc20.balance_of(USER1());

    // USER1 burns
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    let final_balance = setup.erc20.balance_of(USER1());
    assert!(final_balance == initial_balance - HUNDRED_TOKENS, "Balance should decrease");
}

#[test]
fn test_burn_reduces_total_supply() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);
    let initial_supply = setup.erc20.total_supply();

    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    let final_supply = setup.erc20.total_supply();
    assert!(final_supply == initial_supply - HUNDRED_TOKENS, "Supply should decrease");
}

#[test]
fn test_burn_emits_transfer_to_zero_event() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    let mut spy = spy_events();

    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    ERC20Component::Event::Transfer(
                        ERC20Component::Transfer {
                            from: USER1(), to: ZERO_ADDRESS(), value: HUNDRED_TOKENS,
                        },
                    ),
                ),
            ],
        );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_burn_fails_insufficient_balance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS + 1);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_burn_from_with_approval_succeeds() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 2);

    // USER1 approves USER2
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    let initial_balance = setup.erc20.balance_of(USER1());

    // USER2 burns from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        setup.erc20.balance_of(USER1()) == initial_balance - HUNDRED_TOKENS,
        "USER1 balance should decrease",
    );
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_burn_from_fails_without_approval() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);
}

// ==============================================================================
// DISTRIBUTION ORDER QUERY TESTS
// ==============================================================================

#[test]
fn test_get_order_count_returns_correct_count() {
    let setup = deploy_stream_token_with_multiple_orders();

    assert!(setup.token.get_order_count() == 3, "Should have 3 orders");
}

#[test]
fn test_get_order_returns_correct_data() {
    let setup = deploy_stream_token_with_multiple_orders();

    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    let buy_token_1: ContractAddress = 'BUY_TOKEN1'.try_into().unwrap();
    let buy_token_2: ContractAddress = 'BUY_TOKEN2'.try_into().unwrap();

    assert!(order0.buy_token == buy_token_1, "Order 0 buy_token mismatch");
    assert!(order0.amount == 300_u128 * ERC20_UNIT, "Order 0 amount mismatch");
    assert!(order0.proceeds_recipient == TREASURY(), "Order 0 recipient mismatch");

    assert!(order1.buy_token == buy_token_2, "Order 1 buy_token mismatch");
    assert!(order1.amount == 200_u128 * ERC20_UNIT, "Order 1 amount mismatch");
    assert!(order1.proceeds_recipient == USER1(), "Order 1 recipient mismatch");

    assert!(order2.buy_token == buy_token_1, "Order 2 buy_token mismatch");
    assert!(order2.amount == 100_u128 * ERC20_UNIT, "Order 2 amount mismatch");
    assert!(order2.proceeds_recipient == USER2(), "Order 2 recipient mismatch");
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_fails_with_invalid_index() {
    let setup = deploy_stream_token();

    // Only 1 order exists
    setup.token.get_order(1);
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_key_fails_with_invalid_index() {
    let setup = deploy_stream_token();

    setup.token.get_order_key(5);
}

// ==============================================================================
// POSITION AND ADDRESS QUERY TESTS
// ==============================================================================

#[test]
fn test_get_position_id_returns_zero_before_distributions() {
    let setup = deploy_stream_token();

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();
    let pos_id = setup.token.get_position_id(buy_token, DEFAULT_FEE);
    assert!(pos_id == 0, "Position ID should be 0 before distributions");
}

#[test]
fn test_get_positions_address_returns_configured() {
    let setup = deploy_stream_token();

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    assert!(setup.token.get_positions_address() == mock_positions, "Positions address mismatch");
}

#[test]
fn test_get_core_address_returns_configured() {
    let setup = deploy_stream_token();

    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    assert!(setup.token.get_core_address() == mock_core, "Core address mismatch");
}

#[test]
fn test_get_extension_address_returns_configured() {
    let setup = deploy_stream_token();

    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    assert!(setup.token.get_extension_address() == mock_extension, "Extension address mismatch");
}

// ==============================================================================
// DEPLOYMENT STATE TESTS
// ==============================================================================

#[test]
fn test_is_initialized_returns_false_at_construction() {
    let setup = deploy_stream_token();

    assert!(!setup.token.is_initialized(), "Should not be initialized");
    assert!(setup.token.get_deployment_state() == 0, "State should be 0");
}

#[test]
fn test_get_liquidity_position_id_returns_zero_before_liquidity() {
    let setup = deploy_stream_token();

    assert!(setup.token.get_liquidity_position_id() == 0, "Liquidity position should be 0");
}

#[test]
fn test_get_pool_id_returns_zero_before_liquidity() {
    let setup = deploy_stream_token();

    assert!(setup.token.get_pool_id() == 0, "Pool ID should be 0");
}

// ==============================================================================
// FACTORY SETUP FUNCTION TESTS
// ==============================================================================

#[test]
#[should_panic(expected: 'Only factory can call')]
fn test_provide_initial_liquidity_only_callable_by_factory() {
    let setup = deploy_stream_token();

    // Non-factory calls
    start_cheat_caller_address(setup.token_address, USER1());
    setup.setup.provide_initial_liquidity();
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'Only factory can call')]
fn test_start_distributions_only_callable_by_factory() {
    let setup = deploy_stream_token();

    start_cheat_caller_address(setup.token_address, USER1());
    setup.setup.start_distributions();
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'Liquidity not provided')]
fn test_start_distributions_fails_without_liquidity() {
    let setup = deploy_stream_token();

    // Factory tries to start distributions without providing liquidity first
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup.setup.start_distributions();
    stop_cheat_caller_address(setup.token_address);
}

// ==============================================================================
// INTEGRATION TESTS
// ==============================================================================

#[test]
fn test_multiple_users_can_burn_independently() {
    let setup = deploy_stream_token();

    let user1_tokens = HUNDRED_TOKENS * 2;
    let user2_tokens = HUNDRED_TOKENS * 3;

    // Give both users tokens
    setup_user_with_tokens(@setup, USER1(), user1_tokens);

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup.erc20.transfer(USER2(), user2_tokens);
    stop_cheat_caller_address(setup.token_address);

    // USER1 burns
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn(HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        setup.erc20.balance_of(USER1()) == user1_tokens - HUNDRED_TOKENS, "USER1 balance incorrect",
    );
    assert!(
        setup.erc20.balance_of(USER2()) == user2_tokens - HUNDRED_TOKENS * 2,
        "USER2 balance incorrect",
    );
}

#[test]
fn test_burn_from_deducts_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 2);

    // USER1 approves USER2 for more than burn amount
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns some
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    let remaining_allowance = setup.erc20.allowance(USER1(), USER2());
    assert!(remaining_allowance == HUNDRED_TOKENS, "Allowance should decrease");
}

#[test]
fn test_consecutive_burns_track_correctly() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), THOUSAND_TOKENS);

    start_cheat_caller_address(setup.token_address, USER1());

    setup.token.burn(HUNDRED_TOKENS);
    assert!(
        setup.erc20.balance_of(USER1()) == THOUSAND_TOKENS - HUNDRED_TOKENS,
        "Balance after first burn",
    );

    setup.token.burn(HUNDRED_TOKENS);
    assert!(
        setup.erc20.balance_of(USER1()) == THOUSAND_TOKENS - HUNDRED_TOKENS * 2,
        "Balance after second burn",
    );

    setup.token.burn(HUNDRED_TOKENS);
    assert!(
        setup.erc20.balance_of(USER1()) == THOUSAND_TOKENS - HUNDRED_TOKENS * 3,
        "Balance after third burn",
    );

    stop_cheat_caller_address(setup.token_address);
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_burn_amount(burn_pct: u8) {
    // Constrain to valid percentage (0-100)
    if burn_pct > 100 {
        return;
    }

    let setup = deploy_stream_token();
    let total = THOUSAND_TOKENS;

    setup_user_with_tokens(@setup, USER1(), total);

    let burn_amount = (total * burn_pct.into()) / 100;

    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(burn_amount);
    stop_cheat_caller_address(setup.token_address);

    let expected_balance = total - burn_amount;
    assert!(setup.erc20.balance_of(USER1()) == expected_balance, "Balance after burn incorrect");
}

#[test]
#[fuzzer]
fn test_fuzz_transfer_amount(transfer_pct: u8) {
    // Constrain to valid percentage (0-100)
    if transfer_pct > 100 {
        return;
    }

    let setup = deploy_stream_token();
    let initial = THOUSAND_TOKENS;

    setup_user_with_tokens(@setup, USER1(), initial);

    let transfer_amount = (initial * transfer_pct.into()) / 100;

    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER2(), transfer_amount);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.balance_of(USER1()) == initial - transfer_amount, "USER1 balance");
    assert!(setup.erc20.balance_of(USER2()) == transfer_amount, "USER2 balance");
}

#[test]
#[fuzzer]
fn test_fuzz_total_supply_consistency_after_burns(num_burns: u8) {
    // Limit number of burns to avoid running too long
    if num_burns > 10 {
        return;
    }

    let setup = deploy_stream_token();
    let initial_supply = setup.erc20.total_supply();

    // Give USER1 enough tokens
    let tokens_per_burn = HUNDRED_TOKENS;
    let total_needed = tokens_per_burn * (num_burns.into() + 1);

    if total_needed > setup.erc20.balance_of(setup.factory) {
        return;
    }

    setup_user_with_tokens(@setup, USER1(), total_needed);

    let mut total_burned: u256 = 0;

    start_cheat_caller_address(setup.token_address, USER1());
    let mut i: u8 = 0;
    while i < num_burns {
        setup.token.burn(tokens_per_burn);
        total_burned += tokens_per_burn;
        i += 1;
    }
    stop_cheat_caller_address(setup.token_address);

    let final_supply = setup.erc20.total_supply();
    assert!(final_supply == initial_supply - total_burned, "Supply consistency violated");
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Stream Token
// ==============================================================================

#[test]
fn test_burn_zero_amount() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);
    let initial_balance = setup.erc20.balance_of(USER1());

    // Burn zero - should work (no-op)
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(0);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.balance_of(USER1()) == initial_balance, "Balance should be unchanged");
}

#[test]
fn test_transfer_to_self() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);
    let initial_balance = setup.erc20.balance_of(USER1());

    // Transfer to self
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        setup.erc20.balance_of(USER1()) == initial_balance, "Balance unchanged after self-transfer",
    );
}

#[test]
fn test_allowance_tracking() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 3);

    // Initial allowance is 0
    assert!(setup.erc20.allowance(USER1(), USER2()) == 0, "Initial allowance should be 0");

    // Set allowance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS * 2, "Allowance mismatch");

    // Use some allowance via transfer_from
    start_cheat_caller_address(setup.token_address, USER2());
    setup.erc20.transfer_from(USER1(), USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS, "Allowance should decrease");
}

#[test]
fn test_multiple_orders_different_recipients() {
    let setup = deploy_stream_token_with_multiple_orders();

    // Verify 3 orders with different recipients
    assert!(setup.token.get_order_count() == 3, "Should have 3 orders");

    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    assert!(order0.proceeds_recipient == TREASURY(), "Order 0 recipient should be TREASURY");
    assert!(order1.proceeds_recipient == USER1(), "Order 1 recipient should be USER1");
    assert!(order2.proceeds_recipient == USER2(), "Order 2 recipient should be USER2");
}

#[test]
fn test_order_time_configuration() {
    let setup = deploy_stream_token_with_multiple_orders();

    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    // Order 0: starts at 0, ends at 7 days
    assert!(order0.start_time == 0, "Order 0 start_time");
    assert!(order0.end_time == 86400 * 7, "Order 0 end_time");

    // Order 1: starts at 1 day, ends at 14 days
    assert!(order1.start_time == 86400, "Order 1 start_time");
    assert!(order1.end_time == 86400 * 14, "Order 1 end_time");

    // Order 2: starts at 0, ends at 30 days
    assert!(order2.start_time == 0, "Order 2 start_time");
    assert!(order2.end_time == 86400 * 30, "Order 2 end_time");
}

#[test]
fn test_order_amounts() {
    let setup = deploy_stream_token_with_multiple_orders();

    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    assert!(order0.amount == 300_u128 * ERC20_UNIT, "Order 0 amount");
    assert!(order1.amount == 200_u128 * ERC20_UNIT, "Order 1 amount");
    assert!(order2.amount == 100_u128 * ERC20_UNIT, "Order 2 amount");
}

#[test]
#[should_panic(expected: 'Distributions not started')]
fn test_claim_proceeds_fails_before_initialization() {
    let setup = deploy_stream_token();

    // Try to claim without starting distributions
    setup.token.claim_distribution_proceeds(0);
}

#[test]
fn test_get_order_key_valid_index() {
    let setup = deploy_stream_token();

    let order_key = setup.token.get_order_key(0);

    // Verify order key structure
    assert!(order_key.sell_token == setup.token_address, "Sell token should be this contract");

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();
    assert!(order_key.buy_token == buy_token, "Buy token mismatch");
}

#[test]
fn test_transfer_from_reduces_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 2);

    // Approve USER2
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    // Transfer from using half allowance
    start_cheat_caller_address(setup.token_address, USER2());
    setup.erc20.transfer_from(USER1(), USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // Verify allowance reduced
    let remaining = setup.erc20.allowance(USER1(), USER2());
    assert!(remaining == HUNDRED_TOKENS, "Allowance should be halved");
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_transfer_from_fails_without_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Try transfer_from without approval
    start_cheat_caller_address(setup.token_address, USER2());
    setup.erc20.transfer_from(USER1(), USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_balance_of_zero_address() {
    let setup = deploy_stream_token();

    // Balance of zero address should be 0
    let balance = setup.erc20.balance_of(ZERO_ADDRESS());
    assert!(balance == 0, "Zero address balance should be 0");
}

#[test]
fn test_transfer_zero_amount() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Transfer zero amount - should succeed
    start_cheat_caller_address(setup.token_address, USER1());
    let result = setup.erc20.transfer(USER2(), 0);
    stop_cheat_caller_address(setup.token_address);

    assert!(result, "Zero transfer should return true");
    assert!(setup.erc20.balance_of(USER2()) == 0, "USER2 should still have 0");
}

#[test]
fn test_overwrite_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Set initial allowance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS, "Initial allowance");

    // Overwrite with different amount
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS / 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS / 2,
        "Allowance should be overwritten",
    );
}

#[test]
fn test_burn_entire_balance() {
    let setup = deploy_stream_token();

    let initial_balance = HUNDRED_TOKENS;
    setup_user_with_tokens(@setup, USER1(), initial_balance);

    // Burn entire balance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(initial_balance);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.balance_of(USER1()) == 0, "Balance should be 0 after burning all");
}

#[test]
fn test_burn_from_entire_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Approve exact amount
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // Burn entire allowance
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // Allowance should be 0
    assert!(setup.erc20.allowance(USER1(), USER2()) == 0, "Allowance should be exhausted");
    assert!(setup.erc20.balance_of(USER1()) == 0, "Balance should be 0");
}

#[test]
#[should_panic(expected: 'ERC20: insufficient allowance')]
fn test_burn_from_exceeds_allowance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS * 2);

    // Approve less than burn amount
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // Try to burn more than allowance
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS + 1);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_order_fee_configuration() {
    let setup = deploy_stream_token();

    let order = setup.token.get_order(0);
    assert!(order.fee == DEFAULT_FEE, "Order fee should match default");
}

#[test]
fn test_multiple_approvals_different_spenders() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), THOUSAND_TOKENS);

    // Approve different amounts to different spenders
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS);
    setup.erc20.approve(TREASURY(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS, "USER2 allowance");
    assert!(setup.erc20.allowance(USER1(), TREASURY()) == HUNDRED_TOKENS * 2, "TREASURY allowance");

    // Allowances are independent
    start_cheat_caller_address(setup.token_address, USER2());
    setup.erc20.transfer_from(USER1(), USER2(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // USER2's allowance is 0, TREASURY's is unchanged
    assert!(setup.erc20.allowance(USER1(), USER2()) == 0, "USER2 allowance should be 0");
    assert!(
        setup.erc20.allowance(USER1(), TREASURY()) == HUNDRED_TOKENS * 2,
        "TREASURY allowance unchanged",
    );
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Stream Component
// ==============================================================================

#[test]
fn test_get_position_id_returns_zero_before_start() {
    let setup = deploy_stream_token();

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    // Before start_distributions, position_id should be 0
    let position_id = setup.token.get_position_id(buy_token, DEFAULT_FEE);
    assert!(position_id == 0, "Position ID should be 0 before distributions start");
}

#[test]
fn test_get_extension_address() {
    let setup = deploy_stream_token();

    let extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let stored = setup.token.get_extension_address();
    assert!(stored == extension, "Extension address should match");
}

#[test]
fn test_get_core_address() {
    let setup = deploy_stream_token();

    let core: ContractAddress = 'CORE'.try_into().unwrap();
    let stored = setup.token.get_core_address();
    assert!(stored == core, "Core address should match");
}

#[test]
fn test_is_initialized_returns_false_initially() {
    let setup = deploy_stream_token();

    assert!(!setup.token.is_initialized(), "Should not be initialized until deployment complete");
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_key_panics_on_out_of_bounds() {
    let setup = deploy_stream_token();

    // Order count is 1, so index 10 should panic
    setup.token.get_order_key(10);
}

#[test]
fn test_chain_of_transfers() {
    let setup = deploy_stream_token();

    // Setup chain: factory -> USER1 -> USER2 -> TREASURY
    setup_user_with_tokens(@setup, USER1(), THOUSAND_TOKENS);

    // USER1 -> USER2
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER2(), HUNDRED_TOKENS * 5);
    stop_cheat_caller_address(setup.token_address);

    // USER2 -> TREASURY
    start_cheat_caller_address(setup.token_address, USER2());
    setup.erc20.transfer(TREASURY(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    // Verify balances
    assert!(
        setup.erc20.balance_of(USER1()) == THOUSAND_TOKENS - HUNDRED_TOKENS * 5, "USER1 balance",
    );
    assert!(setup.erc20.balance_of(USER2()) == HUNDRED_TOKENS * 3, "USER2 balance");
    assert!(setup.erc20.balance_of(TREASURY()) == HUNDRED_TOKENS * 2, "TREASURY balance");
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_transfer_exceeds_balance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Try to transfer more than balance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER2(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn test_burn_exceeds_balance() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Try to burn more than balance
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'ERC20: approve to 0')]
fn test_approve_to_zero_address_fails() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);

    // Approve zero address should fail
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(ZERO_ADDRESS(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);
}

#[test]
fn test_total_supply_after_multiple_operations() {
    let setup = deploy_stream_token();
    let initial_supply = setup.erc20.total_supply();

    // Transfer doesn't change supply
    setup_user_with_tokens(@setup, USER1(), HUNDRED_TOKENS);
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.transfer(USER2(), HUNDRED_TOKENS / 2);
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.erc20.total_supply() == initial_supply, "Transfer shouldn't change supply");

    // Burn reduces supply
    start_cheat_caller_address(setup.token_address, USER1());
    setup.token.burn(HUNDRED_TOKENS / 4);
    stop_cheat_caller_address(setup.token_address);

    assert!(
        setup.erc20.total_supply() == initial_supply - HUNDRED_TOKENS / 4,
        "Burn should reduce supply",
    );
}

#[test]
fn test_multiple_users_burn_from_same_user() {
    let setup = deploy_stream_token();

    setup_user_with_tokens(@setup, USER1(), THOUSAND_TOKENS);

    // USER1 approves both USER2 and TREASURY
    start_cheat_caller_address(setup.token_address, USER1());
    setup.erc20.approve(USER2(), HUNDRED_TOKENS * 3);
    setup.erc20.approve(TREASURY(), HUNDRED_TOKENS * 2);
    stop_cheat_caller_address(setup.token_address);

    // USER2 burns from USER1
    start_cheat_caller_address(setup.token_address, USER2());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // TREASURY burns from USER1
    start_cheat_caller_address(setup.token_address, TREASURY());
    setup.token.burn_from(USER1(), HUNDRED_TOKENS);
    stop_cheat_caller_address(setup.token_address);

    // Verify USER1 lost 200 tokens total
    assert!(
        setup.erc20.balance_of(USER1()) == THOUSAND_TOKENS - HUNDRED_TOKENS * 2,
        "USER1 balance after burns",
    );
    // Allowances should be reduced
    assert!(
        setup.erc20.allowance(USER1(), USER2()) == HUNDRED_TOKENS * 2, "USER2 allowance reduced",
    );
    assert!(
        setup.erc20.allowance(USER1(), TREASURY()) == HUNDRED_TOKENS, "TREASURY allowance reduced",
    );
}

#[test]
fn test_deployment_state_starts_at_zero() {
    let setup = deploy_stream_token();

    let state = setup.token.get_deployment_state();
    assert!(state == 0, "Deployment state should be 0 initially");
}

// ==============================================================================
// PREMINT FUNCTIONALITY TESTS
// ==============================================================================

fn deploy_stream_token_with_premints(
    premint_allocations: Span<PremintAllocation>,
) -> StreamTokenSetup {
    let contract = declare("StreamToken").unwrap().contract_class();

    let factory = OWNER();
    let mock_registry = deploy_mock_registry();
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let paired_token: ContractAddress = 'PAIRED'.try_into().unwrap();
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: DEFAULT_FEE,
        initial_tick: i129 { mag: 0, sign: false },
        stream_token_amount: 1000_u128 * ERC20_UNIT,
        paired_token_amount: 100_u128 * ERC20_UNIT,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500_u128 * ERC20_UNIT,
            proceeds_recipient: TREASURY(),
        },
    ];

    // Calculate premint total for supply adjustment
    let mut premint_total: u128 = 0;
    for premint in premint_allocations {
        premint_total += *premint.amount;
    }

    // Ensure supply is enough for all allocations
    let base_supply: u128 = 10000_u128 * ERC20_UNIT;
    let total_supply: u128 = base_supply + premint_total;

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Premint Token";
    let symbol: ByteArray = "PREMINT";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_registry.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    premint_allocations.serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    StreamTokenSetup {
        token_address,
        token: IStreamTokenDispatcher { contract_address: token_address },
        setup: IStreamTokenSetupDispatcher { contract_address: token_address },
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
        registry: mock_registry,
    }
}

#[test]
fn test_premint_single_allocation() {
    let premint_amount: u128 = 100 * ERC20_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Verify USER1 received the preminted tokens
    let user1_balance = setup.erc20.balance_of(USER1());
    assert!(user1_balance == premint_amount.into(), "USER1 should receive preminted tokens");
}

#[test]
fn test_premint_multiple_allocations() {
    let premint_amount_1: u128 = 100 * ERC20_UNIT;
    let premint_amount_2: u128 = 200 * ERC20_UNIT;
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
fn test_premint_factory_receives_reduced_supply() {
    let premint_amount: u128 = 500 * ERC20_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let setup = deploy_stream_token_with_premints(premints.span());

    // Factory should have: base_supply - ERC20_UNIT (for registry)
    // The premint tokens go to recipients, not factory
    let base_supply: u128 = 10000 * ERC20_UNIT;
    let expected_factory_balance: u256 = (base_supply - ERC20_UNIT).into();
    let factory_balance = setup.erc20.balance_of(setup.factory);

    assert!(factory_balance == expected_factory_balance, "Factory should have reduced balance");
}

#[test]
fn test_premint_emits_event() {
    use game_components_tokenomics::stream::StreamComponent;

    let premint_amount: u128 = 100 * ERC20_UNIT;
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
fn test_premint_same_recipient_multiple_times() {
    let premint_amount_1: u128 = 100 * ERC20_UNIT;
    let premint_amount_2: u128 = 150 * ERC20_UNIT;
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
