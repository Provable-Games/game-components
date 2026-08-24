/// Unit tests for the BuybackComponent v2
///
/// These tests verify the component's behavior in isolation using mock contracts
/// and direct component state testing where possible.
use game_components_economy::tokenomics::{
    BuybackParams, IBuybackAdminDispatcher, IBuybackAdminDispatcherTrait, IBuybackDispatcher,
    IBuybackDispatcherTrait, TokenBuybackConfig,
};
use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    EventSpyTrait, mock_call, spy_events, start_cheat_block_timestamp_global,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::fixtures::constants::{
    BUYBACK_TOKEN, OWNER, TREASURY, USER1, ZERO_ADDRESS, amounts, defaults,
};
use super::helpers::deployment::{deploy_autonomous_buyback, deploy_mock_erc20};
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

/// Helper to deploy a buyback contract with default config
fn setup_buyback_contract(buyback_token: ContractAddress) -> ContractAddress {
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    let global_config = defaults::global_config_with(buyback_token, TREASURY());
    deploy_autonomous_buyback(OWNER(), global_config, mock_positions, mock_extension)
}

/// Helper to setup a buyback contract with default token config for a sell token
/// This is needed for tests that require duration validation
fn setup_buyback_with_token_config(
    buyback_token: ContractAddress, sell_token: ContractAddress,
) -> ContractAddress {
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Set default token config with proper duration limits
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(defaults::default_token_config()));
    stop_cheat_caller_address(contract);

    contract
}

// ============================================================================
// Initialization Tests
// ============================================================================

#[test]
fn test_initialization_sets_buyback_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_global_config();
    assert(config.default_buy_token == buyback_token, 'Wrong buyback token');
}

#[test]
fn test_initialization_sets_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_global_config();
    assert(config.default_treasury == TREASURY(), 'Wrong treasury');
}

#[test]
fn test_initialization_sets_positions_address() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    assert(dispatcher.get_positions_address() == mock_positions, 'Wrong positions address');
}

#[test]
fn test_initialization_sets_extension_address() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    assert(dispatcher.get_extension_address() == mock_extension, 'Wrong extension address');
}

#[test]
fn test_initial_order_count_is_zero() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    assert(dispatcher.get_order_count(sell_token) == 0, 'Order count should be 0');
    assert(dispatcher.get_order_bookmark(sell_token) == 0, 'Bookmark should be 0');
    assert(dispatcher.get_position_token_id(sell_token) == 0, 'Position ID should be 0');
}

#[test]
fn test_initial_token_config_is_none() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    assert(dispatcher.get_token_config(sell_token).is_none(), 'Should have no token config');
}

// NOTE: Initializer validation is tested indirectly via set_global_config tests which use
// the same validation logic. Direct initializer tests cannot use #[should_panic] because
// snforge doesn't catch deployment failures with that pattern. The following tests are
// kept as #[ignore] for documentation - when run manually, they will fail with the expected
// error messages ('min_delay > max_delay' and 'min_duration > max_duration'), proving the
// validation works correctly.

#[test]
#[ignore]
fn test_initialization_rejects_min_delay_gt_max_delay() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // Create config with min_delay > max_delay (both non-zero)
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 1000, // min > max
        default_max_delay: 500,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    // This panics during deployment with 'min_delay > max_delay'
    // Validation is tested via test_set_global_config_rejects_min_delay_gt_max_delay
    deploy_autonomous_buyback(OWNER(), invalid_config, mock_positions, mock_extension);
}

#[test]
#[ignore]
fn test_initialization_rejects_min_duration_gt_max_duration() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // Create config with min_duration > max_duration (both non-zero)
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: 100000, // min > max
        default_max_duration: 50000,
        default_fee: defaults::DEFAULT_FEE,
    };

    // This panics during deployment with 'min_duration > max_duration'
    // Validation is tested via test_set_global_config_rejects_min_duration_gt_max_duration
    deploy_autonomous_buyback(OWNER(), invalid_config, mock_positions, mock_extension);
}

#[test]
fn test_initialization_allows_max_delay_zero() {
    // max_delay = 0 means "no maximum limit", so min_delay > 0 is valid
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    let valid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 1000, // min_delay > 0 with max_delay = 0 (no limit) is valid
        default_max_delay: 0,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    let contract = deploy_autonomous_buyback(OWNER(), valid_config, mock_positions, mock_extension);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_global_config();
    assert(config.default_min_delay == 1000, 'min_delay should be 1000');
    assert(config.default_max_delay == 0, 'max_delay should be 0');
}

#[test]
fn test_initialization_allows_max_duration_zero() {
    // max_duration = 0 means "no maximum limit", so min_duration > 0 is valid
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    let valid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: 1000, // min_duration > 0 with max_duration = 0 (no limit) is valid
        default_max_duration: 0,
        default_fee: defaults::DEFAULT_FEE,
    };

    let contract = deploy_autonomous_buyback(OWNER(), valid_config, mock_positions, mock_extension);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let config = dispatcher.get_global_config();
    assert(config.default_min_duration == 1000, 'min_duration should be 1000');
    assert(config.default_max_duration == 0, 'max_duration should be 0');
}

// ============================================================================
// Global Configuration Tests
// ============================================================================

#[test]
fn test_owner_can_update_global_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let new_config = defaults::global_config_with(buyback_token, new_treasury);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(new_config);
    stop_cheat_caller_address(contract);

    let updated_config = dispatcher.get_global_config();
    assert(updated_config.default_treasury == new_treasury, 'Treasury not updated');
}

#[test]
fn test_global_config_update_emits_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let mut spy = spy_events();

    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let new_config = defaults::global_config_with(buyback_token, new_treasury);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(new_config);
    stop_cheat_caller_address(contract);

    let events = spy.get_events();
    assert(events.events.len() > 0, 'Should emit event');
}

#[test]
#[should_panic(expected: 'Invalid buy token')]
fn test_set_global_config_rejects_zero_buy_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Create config with zero buy_token
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: ZERO_ADDRESS(),
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(invalid_config);
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'Invalid treasury address')]
fn test_set_global_config_rejects_zero_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Create config with zero treasury
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: ZERO_ADDRESS(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(invalid_config);
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_delay > max_delay')]
fn test_set_global_config_rejects_min_delay_gt_max_delay() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Create config with min_delay > max_delay (both non-zero)
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 1000, // min > max
        default_max_delay: 500,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(invalid_config);
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_duration > max_duration')]
fn test_set_global_config_rejects_min_duration_gt_max_duration() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Create config with min_duration > max_duration (both non-zero)
    let invalid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: 100000, // min > max
        default_max_duration: 50000,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(invalid_config);
    stop_cheat_caller_address(contract);
}

#[test]
fn test_set_global_config_allows_max_delay_zero() {
    // max_delay = 0 means "no maximum limit", so min_delay > 0 is valid
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let valid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 1000, // min_delay > 0 with max_delay = 0 (no limit) is valid
        default_max_delay: 0,
        default_min_duration: defaults::MIN_DURATION,
        default_max_duration: defaults::MAX_DURATION,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(valid_config);
    stop_cheat_caller_address(contract);

    let config = dispatcher.get_global_config();
    assert(config.default_min_delay == 1000, 'min_delay should be 1000');
    assert(config.default_max_delay == 0, 'max_delay should be 0');
}

#[test]
fn test_set_global_config_allows_max_duration_zero() {
    // max_duration = 0 means "no maximum limit", so min_duration > 0 is valid
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let valid_config = game_components_economy::tokenomics::GlobalBuybackConfig {
        default_buy_token: buyback_token,
        default_treasury: TREASURY(),
        default_minimum_amount: defaults::MIN_AMOUNT,
        default_min_delay: 0,
        default_max_delay: 0,
        default_min_duration: 1000, // min_duration > 0 with max_duration = 0 (no limit) is valid
        default_max_duration: 0,
        default_fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(valid_config);
    stop_cheat_caller_address(contract);

    let config = dispatcher.get_global_config();
    assert(config.default_min_duration == 1000, 'min_duration should be 1000');
    assert(config.default_max_duration == 0, 'max_duration should be 0');
}

// ============================================================================
// Per-Token Configuration Tests
// ============================================================================

#[test]
fn test_owner_can_set_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let token_config = defaults::token_config_with_minimum(1000);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    let retrieved = dispatcher.get_token_config(sell_token);
    assert(retrieved.is_some(), 'Should have token config');

    let config = retrieved.unwrap();
    assert(config.minimum_amount == 1000, 'Wrong minimum amount');
}

#[test]
fn test_owner_can_clear_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Set then clear
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(defaults::default_token_config()));
    admin_dispatcher.set_token_config(sell_token, Option::None);
    stop_cheat_caller_address(contract);

    assert(dispatcher.get_token_config(sell_token).is_none(), 'Should be None after clear');
}

#[test]
fn test_token_config_update_emits_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let mut spy = spy_events();

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(defaults::default_token_config()));
    stop_cheat_caller_address(contract);

    let events = spy.get_events();
    assert(events.events.len() > 0, 'Should emit event');
}

// ============================================================================
// Effective Configuration Tests
// ============================================================================

#[test]
fn test_effective_config_uses_global_defaults() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    let effective = dispatcher.get_effective_config(sell_token);

    // Should use global defaults
    assert(effective.buy_token == buyback_token, 'Should use global buy token');
    assert(effective.treasury == TREASURY(), 'Should use global treasury');
}

#[test]
fn test_effective_config_uses_override_when_set() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Set per-token override
    let token_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: new_treasury,
        minimum_amount: 500,
        min_delay: 0,
        max_delay: 0,
        min_duration: 3600,
        max_duration: 86400,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    let effective = dispatcher.get_effective_config(sell_token);

    // Should use override
    assert(effective.treasury == new_treasury, 'Should use override treasury');
    assert(effective.minimum_amount == 500, 'Should use override minimum');
}

// ============================================================================
// View Function Tests
// ============================================================================

#[test]
fn test_get_unclaimed_orders_count() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Initially should be 0
    assert(dispatcher.get_unclaimed_orders_count(sell_token) == 0, 'Should be 0 unclaimed');
}

// ============================================================================
// Buy Back Validation Tests (using BuybackParams)
// ============================================================================

#[test]
#[should_panic(expected: 'Invalid sell token')]
fn test_buy_back_rejects_zero_sell_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    let params = BuybackParams {
        sell_token: ZERO_ADDRESS(), start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Sell token is buy token')]
fn test_buy_back_rejects_same_tokens() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    let params = BuybackParams {
        sell_token: buyback_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    // Try to use buyback_token as sell_token (should fail)
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'End time must be after start')]
fn test_buy_back_rejects_past_end_time() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp to 2000
    start_cheat_block_timestamp_global(2000);

    // Try with end_time in the past (end_time <= actual_start)
    let params = BuybackParams { sell_token, start_time: 0, end_time: 1000 };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Duration too short')]
fn test_buy_back_rejects_duration_too_short() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // End time that creates duration less than min_duration
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION - 1,
    };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Duration too long')]
fn test_buy_back_rejects_duration_too_long() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // End time that creates duration more than max_duration
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MAX_DURATION + 1,
    };
    dispatcher.buy_back(params);
}

#[test]
fn test_buy_back_allows_any_duration_when_max_duration_is_zero() {
    // max_duration = 0 means "no maximum limit"
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Set token config with max_duration = 0 (no limit)
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher
        .set_token_config(sell_token, Option::Some(defaults::token_config_with_no_max_duration()));
    stop_cheat_caller_address(contract);

    // Mint tokens for buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock the positions contract
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Create buyback with duration 10x longer than default MAX_DURATION
    // This would fail with "Duration too long" if max_duration was enforced
    let very_long_duration = defaults::MAX_DURATION * 10;
    let params = BuybackParams { sell_token, start_time: 0, end_time: 1000 + very_long_duration };
    dispatcher.buy_back(params);

    // Verify order was created successfully
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
}

#[test]
#[should_panic(expected: 'No balance to buyback')]
fn test_buy_back_rejects_zero_balance() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Valid end time but no balance
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Amount below minimum')]
fn test_buy_back_rejects_amount_below_minimum() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Set a minimum amount requirement
    let token_config = defaults::token_config_with_minimum(1000);
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    // Mint less than minimum
    mock_erc20.mint(contract, 500);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Should fail due to amount below minimum
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

// ============================================================================
// Delayed Start Validation Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Start time too soon')]
fn test_buy_back_rejects_start_too_soon_when_min_delay_set() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Set a min_delay requirement
    let token_config = defaults::token_config_with_delay(100, 1000);
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    // Mint tokens
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Try to start immediately (start_time = 0) when min_delay is set
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Delay too short')]
fn test_buy_back_rejects_delay_too_short() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Set a min_delay requirement of 100 seconds
    let token_config = defaults::token_config_with_delay(100, 1000);
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    // Mint tokens
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Try to start with only 50 second delay (less than min_delay of 100)
    let params = BuybackParams {
        sell_token,
        start_time: 1050, // only 50 seconds in future
        end_time: 1050 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

#[test]
#[should_panic(expected: 'Delay too long')]
fn test_buy_back_rejects_delay_too_long() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Set a max_delay requirement of 1000 seconds
    let token_config = defaults::token_config_with_delay(100, 1000);
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    // Mint tokens
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Try to start with 2000 second delay (more than max_delay of 1000)
    let params = BuybackParams {
        sell_token,
        start_time: 3000, // 2000 seconds in future
        end_time: 3000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);
}

// ============================================================================
// Claim Proceeds Validation Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Position not initialized')]
fn test_claim_proceeds_rejects_uninitialized_position() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Try to claim without any buyback orders
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

// ============================================================================
// Multiple Token Isolation Tests
// ============================================================================

#[test]
fn test_different_tokens_have_separate_order_counts() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token_1 = deploy_mock_erc20("Sell1", "SELL1");
    let sell_token_2 = deploy_mock_erc20("Sell2", "SELL2");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Each sell token should have independent counters
    assert(dispatcher.get_order_count(sell_token_1) == 0, 'Token1 count should be 0');
    assert(dispatcher.get_order_count(sell_token_2) == 0, 'Token2 count should be 0');
    assert(dispatcher.get_order_bookmark(sell_token_1) == 0, 'Token1 bookmark should be 0');
    assert(dispatcher.get_order_bookmark(sell_token_2) == 0, 'Token2 bookmark should be 0');
}

#[test]
fn test_different_tokens_can_have_different_configs() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token_1 = deploy_mock_erc20("Sell1", "SELL1");
    let sell_token_2 = deploy_mock_erc20("Sell2", "SELL2");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Set different configs for each token
    let config_1 = defaults::token_config_with_minimum(100);
    let config_2 = defaults::token_config_with_minimum(500);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token_1, Option::Some(config_1));
    admin_dispatcher.set_token_config(sell_token_2, Option::Some(config_2));
    stop_cheat_caller_address(contract);

    // Verify each token has its own config
    let effective_1 = dispatcher.get_effective_config(sell_token_1);
    let effective_2 = dispatcher.get_effective_config(sell_token_2);

    assert(effective_1.minimum_amount == 100, 'Token1 wrong minimum');
    assert(effective_2.minimum_amount == 500, 'Token2 wrong minimum');
}

// ============================================================================
// Sweep Buy Token Tests
// ============================================================================

#[test]
fn test_sweep_buy_token_transfers_to_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };
    let erc20 = IERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to the contract (simulating royalties or accidental transfer)
    let sweep_amount: u256 = amounts::HUNDRED_TOKENS;
    mock_erc20.mint(contract, sweep_amount);

    // Verify contract has the tokens
    assert(erc20.balance_of(contract) == sweep_amount, 'Contract should have tokens');
    assert(erc20.balance_of(TREASURY()) == 0, 'Treasury should be empty');

    // Sweep the tokens
    let swept = dispatcher.sweep_buy_token_to_treasury();

    // Verify tokens were transferred to treasury
    assert(swept == sweep_amount, 'Wrong swept amount');
    assert(erc20.balance_of(contract) == 0, 'Contract should be empty');
    assert(erc20.balance_of(TREASURY()) == sweep_amount, 'Treasury should have tokens');
}

#[test]
fn test_sweep_buy_token_emits_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to the contract
    let sweep_amount: u256 = amounts::HUNDRED_TOKENS;
    mock_erc20.mint(contract, sweep_amount);

    let mut spy = spy_events();

    // Sweep the tokens
    dispatcher.sweep_buy_token_to_treasury();

    // Verify event was emitted
    let events = spy.get_events();
    assert(events.events.len() > 0, 'Should emit event');
}

#[test]
fn test_sweep_buy_token_is_permissionless() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to the contract
    mock_erc20.mint(contract, amounts::HUNDRED_TOKENS);

    // Call as a random user (not owner) - should succeed
    start_cheat_caller_address(contract, USER1());
    let swept = dispatcher.sweep_buy_token_to_treasury();
    stop_cheat_caller_address(contract);

    assert(swept == amounts::HUNDRED_TOKENS, 'Should sweep as any user');
}

#[test]
#[should_panic(expected: 'No buy token to sweep')]
fn test_sweep_buy_token_fails_with_zero_balance() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Try to sweep with no balance - should fail
    dispatcher.sweep_buy_token_to_treasury();
}

#[test]
fn test_sweep_buy_token_uses_global_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: buyback_token };
    let erc20 = IERC20Dispatcher { contract_address: buyback_token };

    // Mint buy tokens to the contract
    mock_erc20.mint(contract, amounts::HUNDRED_TOKENS);

    // Sweep and verify it uses global config's treasury
    dispatcher.sweep_buy_token_to_treasury();

    // Treasury from global config should receive the tokens
    assert(erc20.balance_of(TREASURY()) == amounts::HUNDRED_TOKENS, 'Should use global treasury');
}

// ============================================================================
// Buy Token / Fee Mismatch Tests (Config Change with Unclaimed Orders)
// ============================================================================

/// Helper to setup a buyback contract with explicit token config for mismatch testing
fn setup_buyback_with_explicit_config(
    buyback_token: ContractAddress, sell_token: ContractAddress,
) -> ContractAddress {
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // Use the actual buyback_token in global config
    let global_config = defaults::global_config_with(buyback_token, TREASURY());
    let contract = deploy_autonomous_buyback(
        OWNER(), global_config, mock_positions, mock_extension,
    );

    // Set token config with the same buyback_token
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let token_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    contract
}

#[test]
#[should_panic(expected: 'Buy token mismatch')]
fn test_buy_back_rejects_buy_token_change_with_unclaimed_orders() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let new_buyback_token = deploy_mock_erc20("NewBuyback", "NBUY");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mint tokens for the first buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock the positions contract's mint_and_increase_sell_amount to return a position ID
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Create first buyback order - this sets active_buy_token and active_fee
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);

    // Verify order was created
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
    assert(dispatcher.get_active_buy_token(sell_token) == buyback_token, 'Active buy token set');

    // Now change the token config to use a different buy_token
    let new_token_config = TokenBuybackConfig {
        buy_token: new_buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: defaults::DEFAULT_FEE,
    };
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(new_token_config));
    stop_cheat_caller_address(contract);

    // Mint more tokens for second buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Mock the positions contract again
    mock_call(mock_positions, selector!("increase_sell_amount"), (), 1);

    // Try to create another buyback - should fail because buy_token changed
    let params2 = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 200,
    };
    dispatcher.buy_back(params2);
}

#[test]
#[should_panic(expected: 'Fee mismatch')]
fn test_buy_back_rejects_fee_change_with_unclaimed_orders() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mint tokens for the first buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock the positions contract's mint_and_increase_sell_amount to return a position ID
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (1_u64, 100_u128), 1);

    // Create first buyback order - this sets active_buy_token and active_fee
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);

    // Verify order was created and active fee is set
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
    let active_fee = dispatcher.get_active_fee(sell_token);
    assert(active_fee == defaults::DEFAULT_FEE, 'Active fee should be set');

    // Now change the token config to use a different fee
    let different_fee: u128 = 999999; // Different from DEFAULT_FEE
    let new_token_config = TokenBuybackConfig {
        buy_token: buyback_token, // Same buy_token, different fee
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: different_fee,
    };
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(new_token_config));
    stop_cheat_caller_address(contract);

    // Mint more tokens for second buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Mock the positions contract again
    mock_call(mock_positions, selector!("increase_sell_amount"), (), 1);

    // Try to create another buyback - should fail because fee changed
    let params2 = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 200,
    };
    dispatcher.buy_back(params2);
}

#[test]
fn test_active_buy_token_cleared_when_no_unclaimed_orders() {
    // This test verifies the storage behavior: active_buy_token should be zero
    // when there are no unclaimed orders (no orders exist yet)
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Before any orders, active_buy_token should be zero
    assert(dispatcher.get_active_buy_token(sell_token) == ZERO_ADDRESS(), 'Should be zero');
    assert(dispatcher.get_active_fee(sell_token) == 0, 'Fee should be zero');
    assert(dispatcher.get_unclaimed_orders_count(sell_token) == 0, 'No unclaimed orders');

    // Config can be changed freely when no unclaimed orders exist
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let new_buyback_token = deploy_mock_erc20("NewBuyback", "NBUY");
    let new_token_config = TokenBuybackConfig {
        buy_token: new_buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: 12345 // Different fee
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(new_token_config));
    stop_cheat_caller_address(contract);

    // Verify config was updated
    let effective = dispatcher.get_effective_config(sell_token);
    assert(effective.buy_token == new_buyback_token, 'Buy token should be updated');
    assert(effective.fee == 12345, 'Fee should be updated');
}

#[test]
fn test_position_id_cleared_after_all_orders_claimed() {
    // This test verifies that position_id is cleared when all orders are claimed,
    // allowing a new position to be minted if config changes
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mint tokens for first buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock mint_and_increase_sell_amount to return position ID 42
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    // Create first buyback order
    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Verify position ID was stored
    assert(dispatcher.get_position_token_id(sell_token) == 42, 'Position ID should be 42');
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');

    // Fast forward past order end time
    start_cheat_block_timestamp_global(end_time + 1);

    // Mock withdraw_proceeds_from_sale_to
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);

    // Claim all orders
    dispatcher.claim_buyback_proceeds(sell_token, 0);

    // Verify position_id, active_buy_token, and active_fee are all cleared
    assert(dispatcher.get_position_token_id(sell_token) == 0, 'Position ID should be cleared');
    assert(dispatcher.get_active_buy_token(sell_token) == ZERO_ADDRESS(), 'Buy token cleared');
    assert(dispatcher.get_active_fee(sell_token) == 0, 'Fee should be cleared');

    // Now change config to use different buy_token
    let new_buyback_token = deploy_mock_erc20("NewBuyback", "NBUY");
    let new_token_config = TokenBuybackConfig {
        buy_token: new_buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: 999999 // Different fee
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(new_token_config));
    stop_cheat_caller_address(contract);

    // Mint more tokens for second batch
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Mock mint_and_increase_sell_amount again - this should be called (not increase_sell_amount)
    // because position_id was cleared, so a NEW position should be minted
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (99_u64, 100_u128), 1);

    // Create second buyback with new config - should succeed and mint NEW position
    let params2 = BuybackParams {
        sell_token, start_time: 0, end_time: end_time + 1 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params2);

    // Verify new position was minted
    assert(dispatcher.get_position_token_id(sell_token) == 99, 'New position ID should be 99');
    assert(dispatcher.get_active_buy_token(sell_token) == new_buyback_token, 'New buy token');
    assert(dispatcher.get_active_fee(sell_token) == 999999, 'New fee');
}

// ============================================================================
// Successful Buyback Flow Tests
// ============================================================================

#[test]
fn test_buy_back_success_first_order_creates_position() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Mint tokens for buyback
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // Mock the positions contract's mint_and_increase_sell_amount to return a position ID
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    // Create first buyback order
    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);

    // Verify order was created
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
    assert(dispatcher.get_position_token_id(sell_token) == 42, 'Position ID should be 42');
    assert(dispatcher.get_active_buy_token(sell_token) == BUYBACK_TOKEN(), 'Active buy token set');
}

#[test]
fn test_buy_back_success_second_order_uses_existing_position() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Set block timestamp
    start_cheat_block_timestamp_global(1000);

    // First order: mint new position
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);
    let params1 = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params1);

    // Verify first order created
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
    assert(dispatcher.get_position_token_id(sell_token) == 42, 'Position ID should be 42');

    // Second order: uses existing position
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 100_u128, 1);
    let params2 = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 200,
    };
    dispatcher.buy_back(params2);

    // Verify second order created with same position
    assert(dispatcher.get_order_count(sell_token) == 2, 'Should have 2 orders');
    assert(dispatcher.get_position_token_id(sell_token) == 42, 'Position ID unchanged');
}

#[test]
fn test_buy_back_emits_buyback_started_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let mut spy = spy_events();

    let params = BuybackParams {
        sell_token, start_time: 0, end_time: 1000 + defaults::MIN_DURATION + 100,
    };
    dispatcher.buy_back(params);

    // Verify event was emitted
    let events = spy.get_events();
    assert(events.events.len() > 0, 'Should emit event');
}

#[test]
fn test_buy_back_with_delayed_start() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Set token config with delay requirements
    let token_config = defaults::token_config_with_delay(100, 1000);
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    // Create order with valid delay (500 seconds in future, min_delay=100, max_delay=1000)
    let start_time = 1500; // 500 seconds delay
    let end_time = start_time + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time, end_time };
    dispatcher.buy_back(params);

    // Verify order was created
    assert(dispatcher.get_order_count(sell_token) == 1, 'Should have 1 order');
}

// ============================================================================
// Claim Proceeds Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Position not initialized')]
fn test_claim_proceeds_fails_when_all_orders_already_claimed() {
    // When all orders are claimed, the position_id is cleared (reset to 0)
    // So attempting to claim again will fail with "Position not initialized"
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Create an order
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Fast forward past order end time
    start_cheat_block_timestamp_global(end_time + 1);

    // Mock withdraw_proceeds_from_sale_to
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);

    // Claim all orders
    dispatcher.claim_buyback_proceeds(sell_token, 0);

    // Try to claim again - should fail with "Position not initialized"
    // because position_id is cleared after all orders are claimed
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

#[test]
#[should_panic(expected: 'No completed orders')]
fn test_claim_proceeds_fails_when_orders_not_completed() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    // Create an order
    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Try to claim before order end time - should fail with "No completed orders"
    dispatcher.claim_buyback_proceeds(sell_token, 0);
}

#[test]
fn test_claim_proceeds_with_limit() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_explicit_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    start_cheat_block_timestamp_global(1000);

    // Create 3 orders with different end times
    let end_time1 = 1000 + defaults::MIN_DURATION + 100;
    let end_time2 = 1000 + defaults::MIN_DURATION + 200;
    let end_time3 = 1000 + defaults::MIN_DURATION + 300;

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);
    dispatcher.buy_back(BuybackParams { sell_token, start_time: 0, end_time: end_time1 });

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 100_u128, 1);
    dispatcher.buy_back(BuybackParams { sell_token, start_time: 0, end_time: end_time2 });

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    mock_call(mock_positions, selector!("increase_sell_amount"), 100_u128, 1);
    dispatcher.buy_back(BuybackParams { sell_token, start_time: 0, end_time: end_time3 });

    assert(dispatcher.get_order_count(sell_token) == 3, 'Should have 3 orders');

    // Fast forward past all orders
    start_cheat_block_timestamp_global(end_time3 + 1);

    // Mock withdraw for each order
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 3);

    // Claim only 2 orders with limit
    let proceeds = dispatcher.claim_buyback_proceeds(sell_token, 2);
    assert(proceeds == 1000, 'Should claim 2 orders proceeds');
    assert(dispatcher.get_order_bookmark(sell_token) == 2, 'Bookmark should be 2');
    assert(dispatcher.get_unclaimed_orders_count(sell_token) == 1, 'Should have 1 unclaimed');

    // Claim remaining order
    let remaining = dispatcher.claim_buyback_proceeds(sell_token, 0);
    assert(remaining == 500, 'Should claim 1 order proceeds');
    assert(dispatcher.get_order_bookmark(sell_token) == 3, 'Bookmark should be 3');
}

#[test]
fn test_claim_proceeds_emits_event() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    // Fast forward past order end time
    start_cheat_block_timestamp_global(end_time + 1);
    mock_call(mock_positions, selector!("withdraw_proceeds_from_sale_to"), 500_u128, 1);

    let mut spy = spy_events();

    dispatcher.claim_buyback_proceeds(sell_token, 0);

    let events = spy.get_events();
    assert(events.events.len() > 0, 'Should emit BuybackProceeds');
}

// ============================================================================
// Order Info and Order Key Tests
// ============================================================================

#[test]
fn test_get_order_info_returns_correct_data() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    let order_info = dispatcher.get_order_info(sell_token, 0);
    assert(order_info.start_time == 0, 'Start time should be 0');
    assert(order_info.end_time == end_time, 'End time should match');
    // Amount should be THOUSAND_TOKENS (1000 * 10^18) as u128
    let expected_amount: u128 = amounts::THOUSAND_TOKENS.try_into().unwrap();
    assert(order_info.amount == expected_amount, 'Amount should match');
    assert(order_info.buy_token == BUYBACK_TOKEN(), 'Buy token should match');
    assert(order_info.fee == defaults::DEFAULT_FEE, 'Fee should match');
}

#[test]
fn test_get_order_key_returns_correct_key() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_with_token_config(buyback_token, sell_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();

    mock_erc20.mint(contract, amounts::THOUSAND_TOKENS);
    start_cheat_block_timestamp_global(1000);
    mock_call(mock_positions, selector!("mint_and_increase_sell_amount"), (42_u64, 100_u128), 1);

    let end_time = 1000 + defaults::MIN_DURATION + 100;
    let params = BuybackParams { sell_token, start_time: 0, end_time };
    dispatcher.buy_back(params);

    let order_key = dispatcher.get_order_key(sell_token, 0);
    assert(order_key.sell_token == sell_token, 'Sell token should match');
    assert(order_key.buy_token == BUYBACK_TOKEN(), 'Buy token should match');
    assert(order_key.fee == defaults::DEFAULT_FEE, 'Fee should match');
    assert(order_key.start_time == 0, 'Start time should be 0');
    assert(order_key.end_time == end_time, 'End time should match');
}

// ============================================================================
// Token Config Validation Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Invalid buy token')]
fn test_set_token_config_rejects_zero_buy_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: ZERO_ADDRESS(),
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'Invalid treasury address')]
fn test_set_token_config_rejects_zero_treasury() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: ZERO_ADDRESS(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_delay > max_delay')]
fn test_set_token_config_rejects_min_delay_gt_max_delay() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 1000, // min > max
        max_delay: 500,
        min_duration: defaults::MIN_DURATION,
        max_duration: defaults::MAX_DURATION,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'min_duration > max_duration')]
fn test_set_token_config_rejects_min_duration_gt_max_duration() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    let invalid_config = TokenBuybackConfig {
        buy_token: buyback_token,
        treasury: TREASURY(),
        minimum_amount: defaults::MIN_AMOUNT,
        min_delay: 0,
        max_delay: 0,
        min_duration: 100000, // min > max
        max_duration: 50000,
        fee: defaults::DEFAULT_FEE,
    };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(invalid_config));
    stop_cheat_caller_address(contract);
}

// ============================================================================
// Strict Per-Token Config Mode (require_token_config)
// ============================================================================

#[test]
#[should_panic(expected: 'No config for token')]
fn test_require_token_config_blocks_unconfigured_token() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_require_token_config(true);
    stop_cheat_caller_address(contract);

    // No per-token config exists: strict mode must refuse the global fallback
    dispatcher.get_effective_config(sell_token);
}

#[test]
fn test_require_token_config_allows_configured_token_and_toggles_off() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let unconfigured = deploy_mock_erc20("Other", "OTH");
    let contract = setup_buyback_contract(buyback_token);
    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_require_token_config(true);
    admin_dispatcher
        .set_token_config(
            sell_token, Option::Some(defaults::token_config_with(buyback_token, TREASURY())),
        );
    stop_cheat_caller_address(contract);

    // Explicitly-configured token trades under strict mode
    let config = dispatcher.get_effective_config(sell_token);
    assert(config.buy_token == buyback_token, 'Wrong buy token');

    // Toggling strict mode off restores the historic global fallback
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_require_token_config(false);
    stop_cheat_caller_address(contract);
    let fallback = dispatcher.get_effective_config(unconfigured);
    assert(fallback.buy_token == buyback_token, 'Fallback should work again');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_require_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, USER1());
    admin_dispatcher.set_require_token_config(true);
}
