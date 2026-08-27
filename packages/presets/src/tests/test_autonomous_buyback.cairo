// ==============================================================================
// AUTONOMOUS BUYBACK PRESET CONTRACT TESTS
// ==============================================================================
// Tests for the ready-to-deploy AutonomousBuyback contract that provides
// permissionless buyback execution via Ekubo TWAMM with owner-only configuration.
//
// These tests cover the gaps identified in the test plan:
// - Ownership transfer edge cases
// - Permissionless function verification
// - Token config validation
// - Multi-token isolation
// - Event emissions

use core::num::traits::Zero;
use game_components_interfaces::tokenomics::buyback::{
    BuybackParams, GlobalBuybackConfig, IBuybackAdminDispatcher, IBuybackAdminDispatcherTrait,
    IBuybackDispatcher, IBuybackDispatcherTrait, TokenBuybackConfig,
};
use game_components_testing::constants::{NEW_OWNER, OWNER, USER1, USER2};
use openzeppelin_interfaces::access::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyTrait, declare, mock_call, spy_events,
    start_cheat_block_timestamp_global, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

// ==============================================================================
// CONSTANTS
// ==============================================================================

fn TREASURY() -> ContractAddress {
    'TREASURY'.try_into().unwrap()
}

fn ZERO_ADDRESS() -> ContractAddress {
    Zero::zero()
}

/// Default fee (0.3% = 3000 basis points)
const DEFAULT_FEE: u128 = 170141183460469235273462165868118016;

/// Default minimum duration (1 hour)
const MIN_DURATION: u64 = 3600;

/// Default maximum duration (30 days)
const MAX_DURATION: u64 = 2592000;

/// 100 tokens with 18 decimals
const HUNDRED_TOKENS: u256 = 100000000000000000000;

/// 1000 tokens with 18 decimals
const THOUSAND_TOKENS: u256 = 1000000000000000000000;

// ==============================================================================
// DEPLOYMENT HELPERS
// ==============================================================================

fn deploy_mock_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn default_global_config(buy_token: ContractAddress) -> GlobalBuybackConfig {
    GlobalBuybackConfig {
        default_buy_token: buy_token,
        default_treasury: TREASURY(),
        default_minimum_amount: 0,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    }
}

fn default_token_config(buy_token: ContractAddress) -> TokenBuybackConfig {
    TokenBuybackConfig {
        buy_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    }
}

fn deploy_autonomous_buyback(
    owner: ContractAddress,
    global_config: GlobalBuybackConfig,
    positions_address: ContractAddress,
    extension_address: ContractAddress,
) -> ContractAddress {
    let contract = declare("AutonomousBuyback").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    owner.serialize(ref calldata);
    global_config.serialize(ref calldata);
    positions_address.serialize(ref calldata);
    extension_address.serialize(ref calldata);
    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

fn setup_buyback_contract(buyback_token: ContractAddress) -> ContractAddress {
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let global_config = default_global_config(buyback_token);
    deploy_autonomous_buyback(OWNER(), global_config, mock_positions, mock_extension)
}

// ==============================================================================
// CONSTRUCTOR TESTS
// ==============================================================================

#[test]
fn test_constructor_initializes_owner_correctly() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    assert!(ownable.owner() == OWNER(), "Owner should be set from constructor");
}

#[test]
fn test_constructor_initializes_global_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_global_config();
    assert!(config.default_buy_token == buyback_token, "Buy token mismatch");
    assert!(config.default_treasury == TREASURY(), "Treasury mismatch");
}

#[test]
fn test_constructor_initializes_positions_address() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    assert!(dispatcher.get_positions_address() == mock_positions, "Positions address mismatch");
}

#[test]
fn test_constructor_initializes_extension_address() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    assert!(dispatcher.get_extension_address() == mock_extension, "Extension address mismatch");
}

// ==============================================================================
// OWNERSHIP TESTS
// ==============================================================================

#[test]
fn test_owner_returns_correct_owner() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    assert!(ownable.owner() == OWNER(), "Owner mismatch");
}

#[test]
fn test_transfer_ownership_success() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    ownable.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(contract);

    assert!(ownable.owner() == NEW_OWNER(), "Owner should be NEW_OWNER after transfer");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_transfer_ownership_rejects_non_owner() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, USER1());
    ownable.transfer_ownership(USER2());
    stop_cheat_caller_address(contract);
}

#[test]
fn test_new_owner_can_perform_admin_actions() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Transfer ownership
    start_cheat_caller_address(contract, OWNER());
    ownable.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(contract);

    // New owner should be able to update global config
    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let new_config = GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: new_treasury,
        default_minimum_amount: 0,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, NEW_OWNER());
    admin.set_global_config(new_config);
    stop_cheat_caller_address(contract);

    let config = dispatcher.get_global_config();
    assert!(config.default_treasury == new_treasury, "New owner should update config");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_old_owner_cannot_perform_admin_actions_after_transfer() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    // Transfer ownership
    start_cheat_caller_address(contract, OWNER());
    ownable.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(contract);

    // Old owner should not be able to update config
    let new_config = default_global_config(buyback_token);
    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(new_config);
    stop_cheat_caller_address(contract);
}

#[test]
fn test_renounce_ownership() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    ownable.renounce_ownership();
    stop_cheat_caller_address(contract);

    assert!(ownable.owner() == ZERO_ADDRESS(), "Owner should be zero after renounce");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_admin_actions_fail_after_renounce() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    // Renounce ownership
    start_cheat_caller_address(contract, OWNER());
    ownable.renounce_ownership();
    stop_cheat_caller_address(contract);

    // Try to update config (should fail - no owner)
    let new_config = default_global_config(buyback_token);
    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(new_config);
    stop_cheat_caller_address(contract);
}

// ==============================================================================
// PERMISSIONLESS FUNCTION TESTS
// ==============================================================================

#[test]
fn test_buy_back_is_permissionless() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Mint tokens to contract
    mock_erc20.mint(contract, THOUSAND_TOKENS);

    // Set timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock positions contract
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Call as random user (not owner)
    start_cheat_caller_address(contract, USER1());
    let params = BuybackParams { sell_token, start_time: 0, end_time: 1000 + MIN_DURATION + 100 };
    dispatcher.buy_back(params);
    stop_cheat_caller_address(contract);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Buy back should work for any user");
}

#[test]
fn test_claim_proceeds_is_permissionless() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Mint tokens and create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Fast forward past end time
    start_cheat_block_timestamp_global(end_time + 1);

    // Mock claim
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);

    // Claim as random user
    start_cheat_caller_address(contract, USER2());
    let proceeds = dispatcher.claim_buyback_proceeds(sell_token, 0);
    stop_cheat_caller_address(contract);

    assert!(proceeds > 0, "Claim should work for any user");
}

#[test]
fn test_sweep_is_permissionless() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to contract
    mock_erc20.mint(contract, HUNDRED_TOKENS);

    // Sweep as random user
    start_cheat_caller_address(contract, USER1());
    let swept = dispatcher.sweep_buy_token_to_treasury();
    stop_cheat_caller_address(contract);

    assert!(swept == HUNDRED_TOKENS, "Sweep should work for any user");
}

// ==============================================================================
// TOKEN CONFIG VALIDATION TESTS
// ==============================================================================

#[test]
#[should_panic(expected: 'Invalid buy token')]
fn test_set_token_config_rejects_zero_buy_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: ZERO_ADDRESS(),
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'Invalid treasury address')]
fn test_set_token_config_rejects_zero_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: ZERO_ADDRESS(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_delay > max_delay')]
fn test_set_token_config_rejects_invalid_delay() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 1000, // min > max
        max_delay: 500,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_duration > max_duration')]
fn test_set_token_config_rejects_invalid_duration() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: 100000, // min > max
        max_duration: 50000,
        fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

// ==============================================================================
// CLAIM PROCEEDS EDGE CASES
// ==============================================================================

// This test is skipped because after claiming all orders, the position is reset
// and subsequent claims fail with 'Position not initialized' rather than 'No orders to claim'
// This is expected behavior - the contract clears position state after all orders claimed.
#[test]
#[should_panic(expected: 'Position not initialized')]
fn test_claim_proceeds_rejects_when_all_claimed() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Fast forward past end time
    start_cheat_block_timestamp_global(end_time + 1);

    // Claim all orders
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);
    dispatcher.claim_buyback_proceeds(sell_token, 0);

    // Try to claim again - should fail
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

#[test]
#[should_panic(expected: 'No completed orders')]
fn test_claim_proceeds_rejects_when_orders_not_ended() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Try to claim before order ends (timestamp still at 1000)
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

// Note: Complex claim_with_limit test with multiple orders is tested in the tokenomics package.
// Here we just verify the basic API exists and can be called.
#[test]
fn test_claim_with_limit_api_exists() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Should have 1 order");
    assert!(dispatcher.get_unclaimed_orders_count(sell_token) == 1, "Should have 1 unclaimed");

    // Fast forward past order
    start_cheat_block_timestamp_global(end_time + 1);

    // Claim with limit=0 (claim all)
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);
    dispatcher.claim_buyback_proceeds(sell_token, 0);

    // All orders should now be claimed (position is reset)
    assert!(
        dispatcher.get_unclaimed_orders_count(sell_token) == 0, "Should have 0 unclaimed orders",
    );
}

// ==============================================================================
// MULTI-TOKEN ISOLATION TESTS
// ==============================================================================

#[test]
fn test_claiming_one_token_does_not_affect_another() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token_1 = deploy_mock_erc20("Sell1", "SELL1");
    let sell_token_2 = deploy_mock_erc20("Sell2", "SELL2");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20_1 = IMockERC20Dispatcher { contract_address: sell_token_1 };
    let mock_erc20_2 = IMockERC20Dispatcher { contract_address: sell_token_2 };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token configs
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token_1, Option::Some(default_token_config(buyback_token)));
    admin.set_token_config(sell_token_2, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    start_cheat_block_timestamp_global(1000);

    // Create order for token 1
    mock_erc20_1.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);
    let end_time1 = 1000 + MIN_DURATION + 100;
    let params1 = BuybackParams { sell_token: sell_token_1, start_time: 0, end_time: end_time1 };
    dispatcher.buy_back(params1);

    // Create order for token 2
    mock_erc20_2.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (2_u64, 100_u128), 1);
    let end_time2 = 1000 + MIN_DURATION + 200;
    let params2 = BuybackParams { sell_token: sell_token_2, start_time: 0, end_time: end_time2 };
    dispatcher.buy_back(params2);

    // Verify both tokens have orders
    assert!(dispatcher.get_order_count(sell_token_1) == 1, "Token1 should have 1 order");
    assert!(dispatcher.get_order_count(sell_token_2) == 1, "Token2 should have 1 order");

    // Fast forward past first order
    start_cheat_block_timestamp_global(end_time1 + 1);

    // Claim token 1
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);
    dispatcher.claim_buyback_proceeds(sell_token_1, 0);

    // Token 1 should be fully claimed
    assert!(dispatcher.get_unclaimed_orders_count(sell_token_1) == 0, "Token1 should be claimed");

    // Token 2 should still have unclaimed order
    assert!(
        dispatcher.get_unclaimed_orders_count(sell_token_2) == 1, "Token2 should still be pending",
    );
}

// ==============================================================================
// VIEW FUNCTION TESTS
// ==============================================================================

#[test]
fn test_get_order_info_returns_correct_data() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    // Use start_time = 0 which means "start immediately"
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Query order info
    let info = dispatcher.get_order_info(sell_token, 0);
    // Note: start_time is stored as the raw param value (0 = start immediately)
    // The contract stores params.start_time directly for OrderKey reconstruction
    assert!(info.start_time == 0, "Start time should be 0 (immediate start)");
    assert!(info.end_time == end_time, "End time mismatch");
    assert!(info.buy_token == buyback_token, "Buy token mismatch");
    assert!(info.fee == DEFAULT_FEE, "Fee mismatch");
}

#[test]
fn test_get_order_key_returns_valid_key() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup token config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Get order key
    let key = dispatcher.get_order_key(sell_token, 0);
    assert!(key.sell_token == sell_token, "OrderKey sell_token mismatch");
    assert!(key.buy_token == buyback_token, "OrderKey buy_token mismatch");
    assert!(key.fee == DEFAULT_FEE, "OrderKey fee mismatch");
}

// ==============================================================================
// EVENT TESTS
// ==============================================================================

#[test]
fn test_ownership_transferred_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let ownable = IOwnableDispatcher { contract_address: contract };

    let mut spy = spy_events();

    start_cheat_caller_address(contract, OWNER());
    ownable.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(contract);

    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit ownership transfer event");
}

#[test]
fn test_buyback_started_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let mut spy = spy_events();

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit BuybackStarted event");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_buy_back_with_valid_durations(duration_offset: u64) {
    // Constrain fuzz input to valid range
    if duration_offset > MAX_DURATION - MIN_DURATION {
        return;
    }

    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let duration = MIN_DURATION + duration_offset;
    let end_time = 1000 + duration;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Order should be created");
}

#[test]
#[fuzzer]
fn test_fuzz_minimum_amount_validation(amount_raw: u128) {
    // Skip zero to avoid underflow
    if amount_raw == 0 || amount_raw > 1000000 {
        return;
    }

    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    let minimum_amount = amount_raw;

    // Setup token config with minimum
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    // Mint exactly the minimum amount
    let amount: u256 = minimum_amount.into();
    mock_erc20.mint(contract, amount);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Order should be created at minimum");
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Delay Validation
// ==============================================================================

#[test]
#[should_panic(expected: 'Start time too soon')]
fn test_buy_back_fails_when_start_time_too_soon_with_min_delay() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Setup config with min_delay
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 3600, // 1 hour delay required
        max_delay: 7200,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // start_time = 0 means immediate start, but min_delay requires future start
    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Delay too short')]
fn test_buy_back_fails_when_delay_too_short() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Setup config with min_delay
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 3600, // 1 hour delay required
        max_delay: 7200,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // start_time in future but not enough delay (only 1800 seconds, need 3600)
    let start_time = 1000 + 1800;
    let end_time = start_time + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Delay too long')]
fn test_buy_back_fails_when_delay_too_long() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Setup config with max_delay
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 3600, // Max 1 hour delay
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // start_time too far in future (7200 seconds, max 3600)
    let start_time = 1000 + 7200;
    let end_time = start_time + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Duration too short')]
fn test_buy_back_fails_when_duration_too_short() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // Duration too short (less than MIN_DURATION)
    let end_time = 1000 + MIN_DURATION - 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Duration too long')]
fn test_buy_back_fails_when_duration_too_long() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // Duration too long (more than MAX_DURATION)
    let end_time = 1000 + MAX_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'End time must be after start')]
fn test_buy_back_fails_when_end_time_before_start() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(10000);

    // End time before start (current time is 10000, end_time is 500)
    let params = BuybackParams { sell_token, start_time: 0, end_time: 500 };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'No balance to buyback')]
fn test_buy_back_fails_with_no_balance() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    start_cheat_block_timestamp_global(1000);

    // No tokens minted - should fail
    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Amount below minimum')]
fn test_buy_back_fails_when_amount_below_minimum() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Setup config with high minimum
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 1000000000000000000000, // 1000 tokens
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    // Mint less than minimum
    mock_erc20.mint(contract, HUNDRED_TOKENS);
    start_cheat_block_timestamp_global(1000);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Invalid sell token')]
fn test_buy_back_fails_with_zero_sell_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    start_cheat_block_timestamp_global(1000);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token: ZERO_ADDRESS(), start_time: 0, end_time };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Sell token is buy token')]
fn test_buy_back_fails_when_sell_token_equals_buy_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };

    // Setup config for buyback_token
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(buyback_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);

    // Try to sell the buy_token
    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token: buyback_token, start_time: 0, end_time };
    dispatcher.buy_back(params);
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Multiple Orders and Position Reuse
// ==============================================================================

#[test]
fn test_multiple_orders_reuse_position() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    start_cheat_block_timestamp_global(1000);

    // First order - creates position
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time1 = 1000 + MIN_DURATION + 100;
    let params1 = BuybackParams { sell_token, start_time: 0, end_time: end_time1 };
    dispatcher.buy_back(params1);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Should have 1 order");
    let position_id = dispatcher.get_position_token_id(sell_token);
    assert!(position_id == 1, "Position ID should be 1");

    // Second order - reuses position
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 200_u128, 1);

    let end_time2 = 1000 + MIN_DURATION + 200;
    let params2 = BuybackParams { sell_token, start_time: 0, end_time: end_time2 };
    dispatcher.buy_back(params2);

    assert!(dispatcher.get_order_count(sell_token) == 2, "Should have 2 orders");
    // Position ID should remain the same
    assert!(dispatcher.get_position_token_id(sell_token) == 1, "Position ID should still be 1");
}

#[test]
fn test_get_active_buy_token_and_fee() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Before any orders, active buy token should be zero
    assert!(dispatcher.get_active_buy_token(sell_token) == ZERO_ADDRESS(), "Should be zero before");
    assert!(dispatcher.get_active_fee(sell_token) == 0, "Fee should be zero before");

    // Create order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // After order, active buy token and fee should be set
    assert!(dispatcher.get_active_buy_token(sell_token) == buyback_token, "Buy token mismatch");
    assert!(dispatcher.get_active_fee(sell_token) == DEFAULT_FEE, "Fee mismatch");
}

#[test]
fn test_get_order_bookmark() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Bookmark should be 0 initially
    assert!(dispatcher.get_order_bookmark(sell_token) == 0, "Bookmark should start at 0");
}

#[test]
fn test_get_token_config_returns_none_when_not_set() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_token_config(sell_token);
    assert!(config.is_none(), "Should return None when not set");
}

#[test]
fn test_get_effective_config_uses_global_defaults() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // No token config set - should use global defaults
    let config = dispatcher.get_effective_config(sell_token);
    assert!(config.buy_token == buyback_token, "Should use global buy_token");
    assert!(config.treasury == TREASURY(), "Should use global treasury");
}

#[test]
fn test_clear_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    // Set config
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    assert!(dispatcher.get_token_config(sell_token).is_some(), "Config should be set");

    // Clear config by setting None
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::None);
    stop_cheat_caller_address(contract);

    assert!(dispatcher.get_token_config(sell_token).is_none(), "Config should be cleared");
}

#[test]
fn test_global_config_updated_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let mut spy = spy_events();

    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let new_config = GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: new_treasury,
        default_minimum_amount: 100,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(new_config);
    stop_cheat_caller_address(contract);

    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit GlobalConfigUpdated event");
}

#[test]
fn test_token_config_updated_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let mut spy = spy_events();

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit TokenConfigUpdated event");
}

#[test]
#[should_panic(expected: 'No buy token to sweep')]
fn test_sweep_fails_with_no_balance() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // No buy tokens - should fail
    dispatcher.sweep_buy_token_to_treasury();
}

#[test]
#[should_panic(expected: 'Position not initialized')]
fn test_claim_fails_when_no_position() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // No orders created - position not initialized
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

#[test]
fn test_valid_delay_with_min_and_max() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup config with both min and max delay
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 3600, // 1 hour min
        max_delay: 7200, // 2 hours max
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // start_time within valid delay range (5000 seconds from now, between 3600 and 7200)
    let start_time = 1000 + 5000;
    let end_time = start_time + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Order should be created");
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Admin Config Validation
// ==============================================================================

#[test]
#[should_panic(expected: 'Invalid buy token')]
fn test_set_global_config_rejects_zero_buy_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let config = GlobalBuybackConfig {
        default_buy_token: ZERO_ADDRESS(),
        default_treasury: TREASURY(),
        default_minimum_amount: 0,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(config);
}

#[test]
#[should_panic(expected: 'Invalid treasury address')]
fn test_set_global_config_rejects_zero_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let config = GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: ZERO_ADDRESS(),
        default_minimum_amount: 0,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(config);
}

#[test]
#[should_panic(expected: 'min_delay > max_delay')]
fn test_set_global_config_rejects_invalid_delays() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let config = GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: 0,
        default_min_delay: 7200,
        default_max_delay: 3600, // Less than min_delay
        default_min_duration: MIN_DURATION,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(config);
}

#[test]
#[should_panic(expected: 'min_duration > max_duration')]
fn test_set_global_config_rejects_invalid_durations() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin = IBuybackAdminDispatcher { contract_address: contract };

    let config = GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: 0,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: MAX_DURATION + 1000,
        default_max_duration: MAX_DURATION,
        default_fee: DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(config);
}

#[test]
fn test_max_delay_zero_means_no_limit() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Config with max_delay = 0 (no limit)
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0, // No limit
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Very large delay should work when max_delay is 0
    let start_time = 1000 + 1000000; // 1M seconds delay
    let end_time = start_time + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Should accept any delay when max=0");
}

#[test]
fn test_max_duration_zero_means_no_limit() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // The global config is a BOUND: a per-token "no maximum" (max_duration = 0)
    // is only a legal refinement when the global ceiling is also open, so
    // open the global envelope first.
    let mut open_global = default_global_config(buyback_token);
    open_global.default_max_duration = 0;
    // Config with max_duration = 0 (no limit)
    let config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: 0, // No limit
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_global_config(open_global);
    admin.set_token_config(sell_token, Option::Some(config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Very long duration should work when max_duration is 0
    let end_time = 1000 + MIN_DURATION + 1000000; // Long duration
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_order_count(sell_token) == 1, "Should accept any duration when max=0");
}

#[test]
fn test_get_unclaimed_orders_count() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Initially no orders
    assert!(dispatcher.get_unclaimed_orders_count(sell_token) == 0, "Should be 0 initially");

    // Create an order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    assert!(dispatcher.get_unclaimed_orders_count(sell_token) == 1, "Should have 1 unclaimed");
}

#[test]
#[should_panic(expected: 'No completed orders')]
fn test_claim_fails_when_no_completed_orders() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create order so position exists
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time = 1000 + MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Order not completed yet (end_time is 1000 + MIN_DURATION + 100 which is in the future)
    // Current time is still 1000 - but we need the order to not be completed
    // This should fail because there are no completed orders (end_time > current_time)
    dispatcher.claim_buyback_proceeds(sell_token, 1);
}

#[test]
fn test_sweep_buy_token_success() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };
    let erc20 = IERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to the contract
    mock_erc20.mint(contract, THOUSAND_TOKENS);

    // Sweep should transfer to treasury
    let swept = dispatcher.sweep_buy_token_to_treasury();
    assert!(swept == THOUSAND_TOKENS, "Should sweep all tokens");
    assert!(erc20.balance_of(TREASURY()) == THOUSAND_TOKENS, "Treasury should receive tokens");
}

#[test]
#[should_panic(expected: 'Buy token mismatch')]
fn test_buy_back_fails_when_buy_token_changed_with_existing_orders() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let new_buy_token = deploy_mock_erc20("NewBuy", "NBUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup with original buy token
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create first order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time1 = 1000 + MIN_DURATION + 100;
    let params1 = BuybackParams { sell_token, start_time: 0, end_time: end_time1 };
    dispatcher.buy_back(params1);

    // Change config to use new buy token
    let new_config = TokenBuybackConfig {
        buy_token: new_buy_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(new_config));
    stop_cheat_caller_address(contract);

    // Try to create second order - should fail because active buy_token is locked
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 200_u128, 1);

    let end_time2 = 1000 + MIN_DURATION + 200;
    let params2 = BuybackParams { sell_token, start_time: 0, end_time: end_time2 };
    dispatcher.buy_back(params2);
}

#[test]
#[should_panic(expected: 'Fee mismatch')]
fn test_buy_back_fails_when_fee_changed_with_existing_orders() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Setup with original fee
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(default_token_config(buyback_token)));
    stop_cheat_caller_address(contract);

    // Create first order
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    let end_time1 = 1000 + MIN_DURATION + 100;
    let params1 = BuybackParams { sell_token, start_time: 0, end_time: end_time1 };
    dispatcher.buy_back(params1);

    // Change config to use different fee
    let new_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: 0,
        min_delay: 0,
        max_delay: 0,
        min_duration: MIN_DURATION,
        max_duration: MAX_DURATION,
        fee: DEFAULT_FEE + 1000 // Different fee
    };
    start_cheat_caller_address(contract, OWNER());
    admin.set_token_config(sell_token, Option::Some(new_config));
    stop_cheat_caller_address(contract);

    // Try to create second order - should fail because active fee is locked
    mock_erc20.mint(contract, THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 200_u128, 1);

    let end_time2 = 1000 + MIN_DURATION + 200;
    let params2 = BuybackParams { sell_token, start_time: 0, end_time: end_time2 };
    dispatcher.buy_back(params2);
}
