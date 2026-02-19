use game_components_economy::tokenomics::stream::StreamComponent;
use game_components_economy::tokenomics::{
    DistributionOrder, IStreamTokenDispatcherTrait, LiquidityConfig, PremintAllocation,
};
/// Tests for StreamToken full lifecycle using snforge mock_call
///
/// These tests exercise the complete token lifecycle:
/// - provide_initial_liquidity (mocking Ekubo Core/Positions calls)
/// - start_distributions (mocking Ekubo Positions calls)
/// - claim_distribution_proceeds (mocking Ekubo Positions calls)
///
/// Uses snforge's start_mock_call to simulate Ekubo contract responses.

use game_components_interfaces::tokenomics::stream::{
    IStreamTokenSetupDispatcher, IStreamTokenSetupDispatcherTrait,
};
use openzeppelin_interfaces::erc20::IERC20Dispatcher;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, start_mock_call, stop_cheat_caller_address, stop_mock_call,
};
use starknet::ContractAddress;
use super::fixtures::constants::{OWNER, TREASURY, defaults};
use super::helpers::deployment::{StreamTokenSetup, deploy_mock_registry, deploy_stream_token};

// ============================================================================
// Helper for Multiple Orders Test
// ============================================================================

/// Deploy a stream token with multiple distribution orders (same buy_token/fee)
/// This tests the `increase_sell_amount` branch in start_distributions
fn deploy_stream_token_with_multiple_orders() -> StreamTokenSetup {
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
        liquidity_owner: OWNER(),
    };

    // Create 2 orders with SAME buy_token and fee to trigger increase_sell_amount
    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 100_u128 * 1_000_000_000_000_000_000,
            proceeds_recipient: TREASURY(),
        },
        DistributionOrder {
            buy_token, // Same buy_token
            fee: defaults::DEFAULT_FEE, // Same fee
            start_time: 0,
            end_time: 86400 * 14, // Different end time
            amount: 100_u128 * 1_000_000_000_000_000_000,
            proceeds_recipient: TREASURY(),
        },
    ];

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
        token: game_components_economy::tokenomics::IStreamTokenDispatcher {
            contract_address: token_address,
        },
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
    }
}

// ============================================================================
// Full Lifecycle Tests with Mocked Ekubo
// ============================================================================

// Mock NFT address returned by get_nft_address
fn MOCK_NFT() -> starknet::ContractAddress {
    'MOCK_NFT'.try_into().unwrap()
}

/// Set up mocks for the LP NFT transfer (get_nft_address + transfer_from)
fn mock_nft_transfer(mock_positions: starknet::ContractAddress) {
    start_mock_call(mock_positions, selector!("get_nft_address"), MOCK_NFT());
    start_mock_call(mock_positions, selector!("transfer_from"), ());
    start_mock_call(MOCK_NFT(), selector!("transferFrom"), ());
    start_mock_call(MOCK_NFT(), selector!("transfer_from"), ());
}

fn stop_mock_nft_transfer(mock_positions: starknet::ContractAddress) {
    stop_mock_call(mock_positions, selector!("get_nft_address"));
    stop_mock_call(mock_positions, selector!("transfer_from"));
    stop_mock_call(MOCK_NFT(), selector!("transferFrom"));
    stop_mock_call(MOCK_NFT(), selector!("transfer_from"));
}

/// Test provide_initial_liquidity succeeds with mocked Ekubo calls
#[test]
fn test_provide_initial_liquidity_with_mocks() {
    let setup = deploy_stream_token();

    // Mock addresses used in deployment
    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mock Ekubo Core initialize_pool to return pool_id = 1
    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);

    // Mock Ekubo Positions mint_and_deposit_and_clear_both
    // Returns: (position_id: u64, liquidity: u128, token0_cleared: u256, token1_cleared: u256)
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );

    // Mock NFT transfer (get_nft_address + transfer_from)
    mock_nft_transfer(mock_positions);

    // Verify initial state
    assert!(setup.token.get_deployment_state() == 0, "Should be state 0 after construction");

    // Call provide_initial_liquidity as factory
    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    start_cheat_caller_address(setup.token_address, setup.factory);
    let (position_id, liquidity, token0_cleared, token1_cleared) = setup_dispatcher
        .provide_initial_liquidity();
    stop_cheat_caller_address(setup.token_address);

    // Verify results from mock
    assert!(position_id == 1, "Position ID should be 1");
    assert!(liquidity == 1000, "Liquidity should be 1000");
    assert!(token0_cleared == 500, "Token0 cleared should be 500");
    assert!(token1_cleared == 500, "Token1 cleared should be 500");

    // Verify state transition
    assert!(setup.token.get_deployment_state() == 1, "Should be state 1 after liquidity");
    assert!(setup.token.get_liquidity_position_id() == 1, "Position ID should be stored");
    assert!(setup.token.get_pool_id() == 1, "Pool ID should be set");

    // Clean up mocks
    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test full lifecycle: provide_initial_liquidity -> start_distributions
#[test]
fn test_start_distributions_with_mocks() {
    let setup = deploy_stream_token();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mock Ekubo calls for provide_initial_liquidity
    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    mock_nft_transfer(mock_positions);

    // Mock Ekubo Positions mint_and_increase_sell_amount for start_distributions
    // Returns: (position_id: u64, sale_rate: u128)
    start_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128));

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // Provide liquidity first
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();

    assert!(setup.token.get_deployment_state() == 1, "Should be state 1 after liquidity");

    // Start distributions
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);

    // Verify state transition
    assert!(setup.token.get_deployment_state() == 2, "Should be state 2 after distributions");
    assert!(setup.token.is_initialized(), "Should be initialized");

    // Verify position was created for distribution order
    let order = setup.token.get_order(0);
    let position_id = setup.token.get_position_id(order.buy_token, order.fee);
    assert!(position_id == 2, "Position ID should be set for distribution order");

    // Clean up
    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test claim_distribution_proceeds with mocks
#[test]
fn test_claim_distribution_proceeds_with_mocks() {
    let setup = deploy_stream_token();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mock all Ekubo calls for full initialization
    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    start_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128));
    mock_nft_transfer(mock_positions);

    // Mock withdraw_proceeds_from_sale_to to return proceeds
    start_mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 250_u128);

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // Complete full initialization
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);

    assert!(setup.token.is_initialized(), "Token should be initialized");

    // Claim proceeds (permissionless)
    let proceeds = setup.token.claim_distribution_proceeds(0);

    // Verify proceeds from mock
    assert!(proceeds == 250, "Should receive mocked proceeds");

    // Clean up
    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"));
    stop_mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test lifecycle emits correct events
#[test]
fn test_lifecycle_events_with_mocks() {
    let setup = deploy_stream_token();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    mock_nft_transfer(mock_positions);

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    let mut spy = spy_events();

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();
    stop_cheat_caller_address(setup.token_address);

    // Verify LiquidityProvided event
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::LiquidityProvided(
                        StreamComponent::LiquidityProvided {
                            position_id: 1, liquidity: 1000, token0_amount: 500, token1_amount: 500,
                        },
                    ),
                ),
            ],
        );

    // Verify LiquidityPositionTransferred event
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::LiquidityPositionTransferred(
                        StreamComponent::LiquidityPositionTransferred {
                            position_id: 1, owner: OWNER(),
                        },
                    ),
                ),
            ],
        );

    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test DistributionStarted event
#[test]
fn test_distribution_started_event_with_mocks() {
    let setup = deploy_stream_token();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    start_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128));
    mock_nft_transfer(mock_positions);

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();
    stop_cheat_caller_address(setup.token_address);

    let mut spy = spy_events();

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);

    let order = setup.token.get_order(0);

    // Verify DistributionStarted event
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::DistributionStarted(
                        StreamComponent::DistributionStarted {
                            order_index: 0,
                            buy_token: order.buy_token,
                            amount: order.amount,
                            end_time: order.end_time,
                            proceeds_recipient: TREASURY(),
                            position_id: 2,
                            sale_rate: 100,
                        },
                    ),
                ),
            ],
        );

    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test ProceedsClaimed event
#[test]
fn test_proceeds_claimed_event_with_mocks() {
    let setup = deploy_stream_token();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    start_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128));
    start_mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 250_u128);
    mock_nft_transfer(mock_positions);

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);

    let mut spy = spy_events();

    setup.token.claim_distribution_proceeds(0);

    // Verify ProceedsClaimed event
    spy
        .assert_emitted(
            @array![
                (
                    setup.token_address,
                    StreamComponent::Event::ProceedsClaimed(
                        StreamComponent::ProceedsClaimed {
                            order_index: 0, amount: 250, recipient: TREASURY(),
                        },
                    ),
                ),
            ],
        );

    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"));
    stop_mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"));
    stop_mock_nft_transfer(mock_positions);
}

/// Test start_distributions with multiple orders sharing same buy_token/fee
/// This exercises the `increase_sell_amount` branch (else case)
#[test]
fn test_start_distributions_multiple_orders_same_pool() {
    let setup = deploy_stream_token_with_multiple_orders();

    let mock_core: starknet::ContractAddress = 'CORE'.try_into().unwrap();
    let mock_positions: starknet::ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mock Ekubo calls for provide_initial_liquidity
    start_mock_call(mock_core, selector!("initialize_pool"), 1_u256);
    start_mock_call(
        mock_positions,
        selector!("mint_and_deposit_and_clear_both"),
        (1_u64, 1000_u128, 500_u256, 500_u256),
    );
    mock_nft_transfer(mock_positions);

    // Mock mint_and_increase_sell_amount for FIRST order (creates new position)
    // Returns: (position_id: u64, sale_rate: u128)
    start_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128));

    // Mock increase_sell_amount for SECOND order (reuses existing position)
    // This is the else branch we want to cover - returns just sale_rate: u128
    start_mock_call(mock_positions, selector!("increase_sell_amount"), 150_u128);

    let setup_dispatcher = IStreamTokenSetupDispatcher { contract_address: setup.token_address };

    // Provide liquidity first
    start_cheat_caller_address(setup.token_address, setup.factory);
    setup_dispatcher.provide_initial_liquidity();

    assert!(setup.token.get_deployment_state() == 1, "Should be state 1 after liquidity");

    // Start distributions - this should:
    // 1. First order: call mint_and_increase_sell_amount (position_id=0, creates new)
    // 2. Second order: call increase_sell_amount (position_id=2 exists for same pool)
    setup_dispatcher.start_distributions();
    stop_cheat_caller_address(setup.token_address);

    // Verify state transition
    assert!(setup.token.get_deployment_state() == 2, "Should be state 2 after distributions");
    assert!(setup.token.is_initialized(), "Should be initialized");

    // Both orders should share the same position ID since they have same buy_token/fee
    let order0 = setup.token.get_order(0);
    let order1 = setup.token.get_order(1);
    let position_id_0 = setup.token.get_position_id(order0.buy_token, order0.fee);
    let position_id_1 = setup.token.get_position_id(order1.buy_token, order1.fee);

    assert!(position_id_0 == 2, "First order position ID should be 2");
    assert!(position_id_1 == 2, "Second order should share same position ID");

    // Clean up
    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
    stop_mock_call(mock_positions, selector!("mint_and_increase_sell_amount"));
    stop_mock_call(mock_positions, selector!("increase_sell_amount"));
    stop_mock_nft_transfer(mock_positions);
}
