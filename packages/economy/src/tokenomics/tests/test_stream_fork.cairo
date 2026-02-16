/// Fork tests for StreamToken with mainnet Ekubo contracts
///
/// These tests verify StreamToken's behavior with real Ekubo infrastructure.
/// They use mainnet fork to ensure compatibility with production contracts.
///
/// Test coverage:
/// - Token deployment with mainnet Ekubo addresses
/// - Token registration with Ekubo registry
/// - Address getter functions return correct values
/// - Premint functionality with mainnet infrastructure
/// - Order configuration storage and retrieval

use game_components_economy::tokenomics::{
    DistributionOrder, IStreamTokenDispatcher, IStreamTokenDispatcherTrait, LiquidityConfig,
    PremintAllocation,
};
use openzeppelin_interfaces::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use super::fixtures::constants::{OWNER, TREASURY, USER1, USER2, mainnet};

// Token unit constant (10^18)
const TOKEN_UNIT: u128 = 1_000_000_000_000_000_000;

// Total supply for test token
const TEST_TOTAL_SUPPLY: u128 = 100_000_000_000_000_000_000_000; // 100,000 tokens

// Default pool fee (0.3%)
const DEFAULT_FEE: u128 = 170141183460469235273462165868118016;

// ============================================================================
// Helper Functions
// ============================================================================

/// Deploy a StreamToken with mainnet Ekubo addresses
fn deploy_stream_token_mainnet() -> (ContractAddress, IStreamTokenDispatcher, IERC20Dispatcher) {
    let contract = declare("StreamToken").unwrap().contract_class();

    let factory = OWNER();

    // Use mainnet registry for token registration
    let registry = mainnet::EKUBO_REGISTRY();

    let liquidity_config = LiquidityConfig {
        paired_token: mainnet::STRK(),
        fee: DEFAULT_FEE,
        stream_token_amount: 1000 * TOKEN_UNIT,
        paired_token_amount: 100 * TOKEN_UNIT,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token: mainnet::ETH(),
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7, // 1 week
            amount: 500 * TOKEN_UNIT,
            proceeds_recipient: TREASURY(),
        },
    ];

    let total_supply: u128 = 10000 * TOKEN_UNIT;

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Fork Test Stream Token";
    let symbol: ByteArray = "FSTREAM";

    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mainnet::EKUBO_POSITIONS().serialize(ref calldata);
    mainnet::EKUBO_CORE().serialize(ref calldata);
    registry.serialize(ref calldata);
    mainnet::EKUBO_TWAMM_EXTENSION().serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    let empty_premints: Array<PremintAllocation> = array![];
    empty_premints.span().serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    (
        token_address,
        IStreamTokenDispatcher { contract_address: token_address },
        IERC20Dispatcher { contract_address: token_address },
    )
}

/// Deploy a StreamToken with premints using mainnet Ekubo addresses
fn deploy_stream_token_mainnet_with_premints(
    premint_allocations: Span<PremintAllocation>,
) -> (ContractAddress, IStreamTokenDispatcher, IERC20Dispatcher) {
    let contract = declare("StreamToken").unwrap().contract_class();

    let factory = OWNER();
    let registry = mainnet::EKUBO_REGISTRY();

    let liquidity_config = LiquidityConfig {
        paired_token: mainnet::STRK(),
        fee: DEFAULT_FEE,
        stream_token_amount: 1000 * TOKEN_UNIT,
        paired_token_amount: 100 * TOKEN_UNIT,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token: mainnet::ETH(),
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500 * TOKEN_UNIT,
            proceeds_recipient: TREASURY(),
        },
    ];

    // Calculate premint total
    let mut premint_total: u128 = 0;
    for premint in premint_allocations {
        premint_total += *premint.amount;
    }

    let base_supply: u128 = 10000 * TOKEN_UNIT;
    let total_supply: u128 = base_supply + premint_total;

    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "Fork Test Stream Token";
    let symbol: ByteArray = "FSTREAM";

    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    total_supply.serialize(ref calldata);
    factory.serialize(ref calldata);
    mainnet::EKUBO_POSITIONS().serialize(ref calldata);
    mainnet::EKUBO_CORE().serialize(ref calldata);
    registry.serialize(ref calldata);
    mainnet::EKUBO_TWAMM_EXTENSION().serialize(ref calldata);
    liquidity_config.serialize(ref calldata);
    distribution_orders.span().serialize(ref calldata);
    premint_allocations.serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    (
        token_address,
        IStreamTokenDispatcher { contract_address: token_address },
        IERC20Dispatcher { contract_address: token_address },
    )
}

// ============================================================================
// Fork Tests - Deployment
// ============================================================================

/// Test that StreamToken can be deployed with mainnet Ekubo addresses
#[test]
#[fork("MAINNET")]
fn test_stream_token_deploys_with_mainnet_addresses() {
    let (token_address, dispatcher, _erc20) = deploy_stream_token_mainnet();

    // Verify token was deployed
    let zero: ContractAddress = 0.try_into().unwrap();
    assert!(token_address != zero, "Token should be deployed");

    // Verify Ekubo addresses are correctly stored
    assert!(
        dispatcher.get_positions_address() == mainnet::EKUBO_POSITIONS(),
        "Positions address mismatch",
    );
    assert!(dispatcher.get_core_address() == mainnet::EKUBO_CORE(), "Core address mismatch");
    assert!(
        dispatcher.get_extension_address() == mainnet::EKUBO_TWAMM_EXTENSION(),
        "Extension address mismatch",
    );
}

/// Test that StreamToken correctly stores mainnet addresses
#[test]
#[fork("MAINNET")]
fn test_stream_token_getters_with_mainnet_fork() {
    let (_token_address, dispatcher, erc20) = deploy_stream_token_mainnet();

    // Verify all address getters return non-zero
    let zero: ContractAddress = 0.try_into().unwrap();
    assert!(dispatcher.get_positions_address() != zero, "Positions should not be zero");
    assert!(dispatcher.get_core_address() != zero, "Core should not be zero");
    assert!(dispatcher.get_extension_address() != zero, "Extension should not be zero");

    // Verify ERC20 metadata
    assert!(erc20.total_supply() > 0, "Total supply should be positive");

    // Verify deployment state
    assert!(dispatcher.get_deployment_state() == 0, "Should be in initial state");
    assert!(!dispatcher.is_initialized(), "Should not be initialized yet");
}

// ============================================================================
// Fork Tests - Order Management
// ============================================================================

/// Test that distribution orders are stored correctly with mainnet addresses
#[test]
#[fork("MAINNET")]
fn test_stream_token_orders_stored_correctly_fork() {
    let (_token_address, dispatcher, _erc20) = deploy_stream_token_mainnet();

    // Verify order count
    assert!(dispatcher.get_order_count() == 1, "Should have 1 order");

    // Get the order
    let order = dispatcher.get_order(0);

    // Verify order data
    assert!(order.buy_token == mainnet::ETH(), "Buy token should be ETH");
    assert!(order.fee == DEFAULT_FEE, "Fee should match");
    assert!(order.amount == 500 * TOKEN_UNIT, "Amount should be 500 tokens");
    assert!(order.proceeds_recipient == TREASURY(), "Recipient should be treasury");
    assert!(order.end_time == 86400 * 7, "End time should be 1 week");
}

/// Test that order key is correctly constructed with mainnet addresses
#[test]
#[fork("MAINNET")]
fn test_stream_token_order_key_construction_fork() {
    let (token_address, dispatcher, _erc20) = deploy_stream_token_mainnet();

    let order_key = dispatcher.get_order_key(0);

    // Verify OrderKey fields
    assert!(order_key.sell_token == token_address, "sell_token should be token address");
    assert!(order_key.buy_token == mainnet::ETH(), "buy_token should be ETH");
    assert!(order_key.fee == DEFAULT_FEE, "fee should match");
}

// ============================================================================
// Fork Tests - Premint Functionality
// ============================================================================

/// Test that premints work correctly with mainnet infrastructure
#[test]
#[fork("MAINNET")]
fn test_stream_token_premints_with_mainnet_fork() {
    let premint_amount: u128 = 100 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount },
    ];

    let (_token_address, _dispatcher, erc20) = deploy_stream_token_mainnet_with_premints(
        premints.span(),
    );

    // Verify USER1 received preminted tokens
    let user1_balance = erc20.balance_of(USER1());
    assert!(user1_balance == premint_amount.into(), "USER1 should receive preminted tokens");
}

/// Test multiple premints with mainnet infrastructure
#[test]
#[fork("MAINNET")]
fn test_stream_token_multiple_premints_with_mainnet_fork() {
    let premint_amount_1: u128 = 100 * TOKEN_UNIT;
    let premint_amount_2: u128 = 200 * TOKEN_UNIT;
    let premints: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: premint_amount_1 },
        PremintAllocation { recipient: USER2(), amount: premint_amount_2 },
    ];

    let (_token_address, _dispatcher, erc20) = deploy_stream_token_mainnet_with_premints(
        premints.span(),
    );

    // Verify both users received preminted tokens
    let user1_balance = erc20.balance_of(USER1());
    let user2_balance = erc20.balance_of(USER2());

    assert!(user1_balance == premint_amount_1.into(), "USER1 should receive correct amount");
    assert!(user2_balance == premint_amount_2.into(), "USER2 should receive correct amount");
}

// ============================================================================
// Fork Tests - Position and Pool State
// ============================================================================

/// Test that position IDs start at zero before initialization
#[test]
#[fork("MAINNET")]
fn test_stream_token_position_id_zero_before_init_fork() {
    let (_token_address, dispatcher, _erc20) = deploy_stream_token_mainnet();

    // Before distributions start, position_id should be 0
    let position_id = dispatcher.get_position_id(mainnet::ETH(), DEFAULT_FEE);
    assert!(position_id == 0, "Position ID should be 0 before distributions");

    // Liquidity position should also be 0
    assert!(
        dispatcher.get_liquidity_position_id() == 0, "Liquidity position should be 0 before init",
    );

    // Pool ID should be 0
    assert!(dispatcher.get_pool_id() == 0, "Pool ID should be 0 before init");
}

/// Test deployment state transitions correctly
#[test]
#[fork("MAINNET")]
fn test_stream_token_deployment_state_fork() {
    let (_token_address, dispatcher, _erc20) = deploy_stream_token_mainnet();

    // After construction, state should be 0
    assert!(dispatcher.get_deployment_state() == 0, "State should be 0 after construction");

    // is_initialized should be false (requires state == 2)
    assert!(!dispatcher.is_initialized(), "Should not be initialized");
}

// ============================================================================
// Fork Tests - ERC20 Integration
// ============================================================================

/// Test that ERC20 functions work correctly with mainnet infrastructure
#[test]
#[fork("MAINNET")]
fn test_stream_token_erc20_integration_fork() {
    let (_token_address, _dispatcher, erc20) = deploy_stream_token_mainnet();

    // Verify total supply
    let total_supply = erc20.total_supply();
    let expected_supply: u256 = (10000 * TOKEN_UNIT).into();
    assert!(total_supply == expected_supply, "Total supply should match");

    // Factory (OWNER) should have tokens after registry takes ERC20_UNIT
    let factory_balance = erc20.balance_of(OWNER());
    assert!(factory_balance > 0, "Factory should have tokens");
}

/// Test token burn functionality with mainnet infrastructure
#[test]
#[fork("MAINNET")]
fn test_stream_token_burn_with_mainnet_fork() {
    let (token_address, dispatcher, erc20) = deploy_stream_token_mainnet();

    // Factory has tokens, transfer some to USER1
    let transfer_amount: u256 = 100 * TOKEN_UNIT.into();

    // Get initial balances
    let initial_supply = erc20.total_supply();
    let _initial_factory = erc20.balance_of(OWNER());

    // Transfer to USER1 (as factory/OWNER)
    snforge_std::start_cheat_caller_address(token_address, OWNER());
    erc20.transfer(USER1(), transfer_amount);
    snforge_std::stop_cheat_caller_address(token_address);

    // USER1 burns tokens
    let burn_amount: u256 = 50 * TOKEN_UNIT.into();
    snforge_std::start_cheat_caller_address(token_address, USER1());
    dispatcher.burn(burn_amount);
    snforge_std::stop_cheat_caller_address(token_address);

    // Verify burn
    let new_supply = erc20.total_supply();
    assert!(new_supply == initial_supply - burn_amount, "Supply should decrease");

    let user1_balance = erc20.balance_of(USER1());
    assert!(user1_balance == transfer_amount - burn_amount, "USER1 balance should decrease");
}
