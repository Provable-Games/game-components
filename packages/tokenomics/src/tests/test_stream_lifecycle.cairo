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
use game_components_tokenomics::IStreamTokenDispatcherTrait;
use game_components_tokenomics::stream::StreamComponent;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, start_mock_call,
    stop_cheat_caller_address, stop_mock_call,
};
use super::fixtures::constants::TREASURY;
use super::helpers::deployment::deploy_stream_token;

// ============================================================================
// Full Lifecycle Tests with Mocked Ekubo
// ============================================================================

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

    stop_mock_call(mock_core, selector!("initialize_pool"));
    stop_mock_call(mock_positions, selector!("mint_and_deposit_and_clear_both"));
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
}
