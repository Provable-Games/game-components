/// Tests for StreamComponent
///
/// These tests verify the stream token component's behavior including:
/// - View functions (get_order_count, get_order, is_initialized, etc.)
/// - Deployment state transitions
/// - Access control (factory-only functions)
/// - Order management
///
/// Note: burn() and burn_from() tests are in test_stream_burn.cairo

use game_components_interfaces::tokenomics::stream::{
    IStreamTokenSetupDispatcher, IStreamTokenSetupDispatcherTrait,
};
use game_components_tokenomics::{
    DistributionOrder, IStreamTokenDispatcher, IStreamTokenDispatcherTrait, LiquidityConfig,
    PremintAllocation,
};
use openzeppelin_interfaces::erc20::{
    IERC20Dispatcher, IERC20DispatcherTrait, IERC20MetadataDispatcher,
    IERC20MetadataDispatcherTrait,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::fixtures::constants::{OWNER, TREASURY, USER1, ZERO_ADDRESS, defaults};
use super::helpers::deployment::{StreamTokenSetup, deploy_mock_registry, deploy_stream_token};

// ============================================================================
// Helper Functions
// ============================================================================

/// Deploy a stream token with custom number of distribution orders
fn deploy_stream_token_with_orders(order_count: u32) -> StreamTokenSetup {
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
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    // Create the specified number of orders
    let mut distribution_orders: Array<DistributionOrder> = array![];
    let mut i: u32 = 0;
    while i < order_count {
        distribution_orders
            .append(
                DistributionOrder {
                    buy_token,
                    fee: defaults::DEFAULT_FEE,
                    start_time: 0,
                    end_time: 86400 * 7 + i.into(), // Slightly different end times
                    amount: 100_u128 * 1_000_000_000_000_000_000,
                    proceeds_recipient: TREASURY(),
                },
            );
        i += 1;
    }

    let total_supply: u128 = 10000_u128 * 1_000_000_000_000_000_000;

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
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
    }
}

// ============================================================================
// get_order_count() Tests
// ============================================================================

#[test]
fn test_get_order_count_returns_correct_count_single_order() {
    let setup = deploy_stream_token();
    assert!(setup.token.get_order_count() == 1, "Should have 1 order");
}

#[test]
fn test_get_order_count_returns_correct_count_multiple_orders() {
    let setup = deploy_stream_token_with_orders(5);
    assert!(setup.token.get_order_count() == 5, "Should have 5 orders");
}

#[test]
fn test_get_order_count_maximum_orders() {
    let setup = deploy_stream_token_with_orders(10);
    assert!(setup.token.get_order_count() == 10, "Should have 10 orders (maximum)");
}

// ============================================================================
// get_order() Tests
// ============================================================================

#[test]
fn test_get_order_returns_first_order() {
    let setup = deploy_stream_token();
    let order = setup.token.get_order(0);

    // Verify order data matches what was set in deployment
    assert!(order.buy_token != ZERO_ADDRESS(), "Buy token should be set");
    assert!(order.fee == defaults::DEFAULT_FEE, "Fee should match");
    assert!(order.amount == 500_u128 * 1_000_000_000_000_000_000, "Amount should be 500 tokens");
    assert!(order.proceeds_recipient == TREASURY(), "Recipient should be treasury");
}

#[test]
fn test_get_order_returns_correct_order_for_multiple() {
    let setup = deploy_stream_token_with_orders(3);

    // Each order has a slightly different end_time
    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    // Verify different end times (set in deploy_stream_token_with_orders)
    assert!(order0.end_time == 86400 * 7, "Order 0 end time");
    assert!(order1.end_time == 86400 * 7 + 1, "Order 1 end time");
    assert!(order2.end_time == 86400 * 7 + 2, "Order 2 end time");
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_panics_on_invalid_index() {
    let setup = deploy_stream_token();
    setup.token.get_order(99); // Out of bounds
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_panics_on_boundary_index() {
    let setup = deploy_stream_token();
    // Order count is 1, so index 1 is out of bounds
    setup.token.get_order(1);
}

// ============================================================================
// get_position_id() Tests
// ============================================================================

#[test]
fn test_get_position_id_returns_zero_before_distributions() {
    let setup = deploy_stream_token();
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    // Before distributions start, position_id should be 0
    let position_id = setup.token.get_position_id(buy_token, defaults::DEFAULT_FEE);
    assert!(position_id == 0, "Position ID should be 0 before distributions");
}

#[test]
fn test_get_position_id_returns_zero_for_unknown_token() {
    let setup = deploy_stream_token();
    let unknown_token: ContractAddress = 'UNKNOWN'.try_into().unwrap();

    let position_id = setup.token.get_position_id(unknown_token, defaults::DEFAULT_FEE);
    assert!(position_id == 0, "Position ID should be 0 for unknown token");
}

// ============================================================================
// get_order_key() Tests
// ============================================================================

#[test]
fn test_get_order_key_returns_correct_key() {
    let setup = deploy_stream_token();
    let order_key = setup.token.get_order_key(0);

    // Verify OrderKey fields
    assert!(order_key.sell_token == setup.token_address, "sell_token should be contract address");
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();
    assert!(order_key.buy_token == buy_token, "buy_token should match order");
    assert!(order_key.fee == defaults::DEFAULT_FEE, "fee should match order");
}

#[test]
fn test_get_order_key_sell_token_is_contract_address() {
    let setup = deploy_stream_token();
    let order_key = setup.token.get_order_key(0);

    // The sell_token in OrderKey should always be the contract address
    assert!(
        order_key.sell_token == setup.token_address,
        "sell_token must be the stream token contract address",
    );
}

#[test]
#[should_panic(expected: 'Invalid order index')]
fn test_get_order_key_panics_on_invalid_index() {
    let setup = deploy_stream_token();
    setup.token.get_order_key(99);
}

// ============================================================================
// is_initialized() Tests
// ============================================================================

#[test]
fn test_is_initialized_returns_false_after_construction() {
    let setup = deploy_stream_token();
    // After construction, deployment_state = 0, so is_initialized = false
    assert!(!setup.token.is_initialized(), "Should not be initialized after construction");
}

// ============================================================================
// get_deployment_state() Tests
// ============================================================================

#[test]
fn test_get_deployment_state_returns_0_after_construction() {
    let setup = deploy_stream_token();
    assert!(
        setup.token.get_deployment_state() == 0, "Deployment state should be 0 after construction",
    );
}

// ============================================================================
// Address Getter Tests
// ============================================================================

#[test]
fn test_get_positions_address_returns_correct_address() {
    let setup = deploy_stream_token();
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    assert!(setup.token.get_positions_address() == mock_positions, "Positions address mismatch");
}

#[test]
fn test_get_core_address_returns_correct_address() {
    let setup = deploy_stream_token();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    assert!(setup.token.get_core_address() == mock_core, "Core address mismatch");
}

#[test]
fn test_get_extension_address_returns_correct_address() {
    let setup = deploy_stream_token();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    assert!(setup.token.get_extension_address() == mock_extension, "Extension address mismatch");
}

// ============================================================================
// get_liquidity_position_id() Tests
// ============================================================================

#[test]
fn test_get_liquidity_position_id_returns_zero_before_liquidity() {
    let setup = deploy_stream_token();
    assert!(
        setup.token.get_liquidity_position_id() == 0,
        "Liquidity position ID should be 0 before liquidity provided",
    );
}

// ============================================================================
// get_pool_id() Tests
// ============================================================================

#[test]
fn test_get_pool_id_returns_zero_before_liquidity() {
    let setup = deploy_stream_token();
    assert!(setup.token.get_pool_id() == 0, "Pool ID should be 0 before liquidity provided");
}

// ============================================================================
// Factory-Only Access Control Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Only factory can call')]
fn test_provide_initial_liquidity_only_factory_can_call() {
    let setup = deploy_stream_token();

    // IStreamTokenSetup interface
    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // USER1 tries to call - should fail
    start_cheat_caller_address(setup.token_address, USER1());
    setup_dispatcher.provide_initial_liquidity();
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'Only factory can call')]
fn test_start_distributions_only_factory_can_call() {
    let setup = deploy_stream_token();

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // USER1 tries to call - should fail
    start_cheat_caller_address(setup.token_address, USER1());
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);
}

#[test]
#[should_panic(expected: 'Liquidity not provided')]
fn test_start_distributions_fails_if_liquidity_not_provided() {
    let setup = deploy_stream_token();

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // Factory calls start_distributions before provide_initial_liquidity
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);
}

// ============================================================================
// claim_distribution_proceeds() Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Distributions not started')]
fn test_claim_proceeds_fails_before_distributions_started() {
    let setup = deploy_stream_token();

    // Try to claim before distributions started (deployment_state != 2)
    setup.token.claim_distribution_proceeds(0);
}

#[test]
#[should_panic(expected: 'Distributions not started')]
fn test_claim_proceeds_fails_with_invalid_order_index() {
    let setup = deploy_stream_token();

    // Even with invalid index, it should fail on distribution check first
    setup.token.claim_distribution_proceeds(99);
}

// ============================================================================
// Order Storage Correctness Tests
// ============================================================================

#[test]
fn test_order_data_stored_correctly() {
    let setup = deploy_stream_token();
    let order = setup.token.get_order(0);

    // Verify all fields are correctly stored
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();
    assert!(order.buy_token == buy_token, "buy_token mismatch");
    assert!(order.fee == defaults::DEFAULT_FEE, "fee mismatch");
    assert!(order.start_time == 0, "start_time should be 0 for immediate start");
    assert!(order.end_time == 86400 * 7, "end_time should be 1 week");
    assert!(order.amount == 500_u128 * 1_000_000_000_000_000_000, "amount should be 500 tokens");
    assert!(order.proceeds_recipient == TREASURY(), "proceeds_recipient mismatch");
}

#[test]
fn test_multiple_orders_stored_independently() {
    let setup = deploy_stream_token_with_orders(3);

    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let order2 = setup.token.get_order(2);

    // Each order should have unique end times
    assert!(order0.end_time != order1.end_time, "Orders should have different end times");
    assert!(order1.end_time != order2.end_time, "Orders should have different end times");

    // But same recipient
    assert!(
        order0.proceeds_recipient == order1.proceeds_recipient, "Recipients should be the same",
    );
}

// ============================================================================
// ERC20 Integration Tests
// ============================================================================

#[test]
fn test_stream_token_has_erc20_functionality() {
    let setup = deploy_stream_token();
    let erc20_metadata = IERC20MetadataDispatcher { contract_address: setup.token_address };

    // Verify basic ERC20 functions work
    let name = erc20_metadata.name();
    let symbol = erc20_metadata.symbol();
    let total_supply = setup.erc20.total_supply();

    assert!(name == "Stream Token", "Name mismatch");
    assert!(symbol == "STREAM", "Symbol mismatch");
    assert!(total_supply > 0, "Total supply should be positive");
}

#[test]
fn test_stream_token_mints_to_factory() {
    let setup = deploy_stream_token();

    // Factory should have remaining supply after registry gets ERC20_UNIT
    let factory_balance = setup.erc20.balance_of(setup.factory);
    assert!(factory_balance > 0, "Factory should have tokens");
}

// ============================================================================
// Fuzz Tests
// ============================================================================

#[test]
#[fuzzer]
fn test_fuzz_get_order_valid_indices(index: u32) {
    let setup = deploy_stream_token_with_orders(5);

    // Only test valid indices
    if index < 5 {
        let order = setup.token.get_order(index);
        // Just verify it returns without panic
        assert!(order.amount > 0, "Order amount should be positive");
    }
}

#[test]
#[fuzzer]
fn test_fuzz_order_count_matches_deployment(order_count: u8) {
    // Limit to valid range 1-10
    let count: u32 = if order_count == 0 {
        1
    } else if order_count > 10 {
        10
    } else {
        order_count.into()
    };

    let setup = deploy_stream_token_with_orders(count);
    assert!(setup.token.get_order_count() == count, "Order count should match deployment");
}
