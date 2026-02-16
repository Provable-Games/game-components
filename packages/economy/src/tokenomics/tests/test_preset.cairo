/// Integration tests for the AutonomousBuyback preset contract v2
///
/// These tests verify the complete contract behavior including:
/// - Component embedding and initialization
/// - Owner access control via OwnableComponent
/// - Per-token configuration management
/// - End-to-end buyback flow (where possible without real Ekubo)
use game_components_economy::tokenomics::{
    IBuybackAdminDispatcher, IBuybackAdminDispatcherTrait, IBuybackDispatcher,
    IBuybackDispatcherTrait, TokenBuybackConfig,
};
use openzeppelin_interfaces::access::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{start_cheat_caller_address, stop_cheat_caller_address};
use starknet::ContractAddress;
use super::fixtures::constants::{OWNER, TREASURY, USER1, USER2, amounts, defaults};
use super::helpers::deployment::{deploy_autonomous_buyback, deploy_mock_erc20};
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

/// Helper to deploy a buyback contract with default config
fn setup_buyback_contract(buyback_token: ContractAddress) -> ContractAddress {
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    let global_config = defaults::global_config_with(buyback_token, TREASURY());
    deploy_autonomous_buyback(OWNER(), global_config, mock_positions, mock_extension)
}

// ============================================================================
// Ownable Integration Tests
// ============================================================================

#[test]
fn test_owner_is_set_correctly() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);

    let ownable = IOwnableDispatcher { contract_address: contract };
    assert(ownable.owner() == OWNER(), 'Wrong owner');
}

#[test]
fn test_owner_can_transfer_ownership() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);

    let ownable = IOwnableDispatcher { contract_address: contract };

    start_cheat_caller_address(contract, OWNER());
    ownable.transfer_ownership(USER1());
    stop_cheat_caller_address(contract);

    assert(ownable.owner() == USER1(), 'Ownership not transferred');
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_global_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);

    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Call as non-owner - should panic
    start_cheat_caller_address(contract, USER1());

    let new_config = defaults::global_config_with(buyback_token, USER2());

    // This should panic because USER1 is not the owner
    admin_dispatcher.set_global_config(new_config);
    stop_cheat_caller_address(contract);
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_set_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);

    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Call as non-owner - should panic
    start_cheat_caller_address(contract, USER1());
    admin_dispatcher.set_token_config(sell_token, Option::Some(defaults::default_token_config()));
    stop_cheat_caller_address(contract);
}

// ============================================================================
// Component Function Integration Tests
// ============================================================================

#[test]
fn test_buyback_dispatcher_works() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Test global config view functions work through dispatcher
    let config = dispatcher.get_global_config();
    assert(config.default_buy_token == buyback_token, 'Wrong buyback token');
    assert(config.default_treasury == TREASURY(), 'Wrong treasury');
}

#[test]
fn test_anyone_can_view_state() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Any user should be able to call view functions
    start_cheat_caller_address(contract, USER1());

    let _ = dispatcher.get_global_config();
    let _ = dispatcher.get_token_config(sell_token);
    let _ = dispatcher.get_effective_config(sell_token);
    let _ = dispatcher.get_positions_address();
    let _ = dispatcher.get_extension_address();
    let _ = dispatcher.get_order_count(sell_token);
    let _ = dispatcher.get_order_bookmark(sell_token);
    let _ = dispatcher.get_unclaimed_orders_count(sell_token);
    let _ = dispatcher.get_position_token_id(sell_token);

    stop_cheat_caller_address(contract);
}

// ============================================================================
// ERC20 Integration Tests
// ============================================================================

#[test]
fn test_contract_can_receive_tokens() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);

    let sell_token_dispatcher = IERC20Dispatcher { contract_address: sell_token };
    let mock_erc20 = IMockERC20Dispatcher { contract_address: sell_token };

    // Mint tokens to a user
    let deposit_amount: u256 = amounts::THOUSAND_TOKENS;
    mock_erc20.mint(USER1(), deposit_amount);

    // User transfers to contract
    start_cheat_caller_address(sell_token, USER1());
    sell_token_dispatcher.transfer(contract, deposit_amount);
    stop_cheat_caller_address(sell_token);

    // Verify contract received tokens
    assert(
        sell_token_dispatcher.balance_of(contract) == deposit_amount, 'Contract should have tokens',
    );
}

// Note: test_emergency_withdraw_works_e2e removed - v2 has no emergency functions (append-only
// design)

// ============================================================================
// Multiple Token Tests
// ============================================================================

#[test]
fn test_can_track_multiple_sell_tokens() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token_1 = deploy_mock_erc20("Sell1", "SELL1");
    let sell_token_2 = deploy_mock_erc20("Sell2", "SELL2");
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };

    // Each sell token should have independent state
    assert(dispatcher.get_order_count(sell_token_1) == 0, 'Token1 count should be 0');
    assert(dispatcher.get_order_count(sell_token_2) == 0, 'Token2 count should be 0');
    assert(dispatcher.get_position_token_id(sell_token_1) == 0, 'Token1 pos should be 0');
    assert(dispatcher.get_position_token_id(sell_token_2) == 0, 'Token2 pos should be 0');
}

// ============================================================================
// Configuration Tests
// ============================================================================

#[test]
fn test_global_config_update() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Update global config
    let new_config = defaults::global_config_with(buyback_token, new_treasury);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_global_config(new_config);
    stop_cheat_caller_address(contract);

    let updated = dispatcher.get_global_config();
    assert(updated.default_treasury == new_treasury, 'Treasury not updated');
}

#[test]
fn test_token_config_override() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Check no per-token config initially
    assert(dispatcher.get_token_config(sell_token).is_none(), 'Should be None initially');

    // Set per-token config
    let token_config = defaults::token_config_with_minimum(1000);

    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(token_config));
    stop_cheat_caller_address(contract);

    // Verify per-token config is set
    let retrieved = dispatcher.get_token_config(sell_token);
    assert(retrieved.is_some(), 'Should have config');

    let config = retrieved.unwrap();
    assert(config.minimum_amount == 1000, 'Wrong minimum amount');
}

#[test]
fn test_effective_config_uses_override() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let new_treasury: ContractAddress = 'NEW_TREASURY'.try_into().unwrap();
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Effective config should use global defaults initially
    let initial_effective = dispatcher.get_effective_config(sell_token);
    assert(initial_effective.treasury == TREASURY(), 'Should use global treasury');

    // Set per-token config with different treasury
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

    // Effective config should now use override
    let effective = dispatcher.get_effective_config(sell_token);
    assert(effective.treasury == new_treasury, 'Should use override treasury');
    assert(effective.minimum_amount == 500, 'Should use override min amount');
}

#[test]
fn test_clear_token_config() {
    let buyback_token = deploy_mock_erc20("Buyback", "BUY");
    let sell_token = deploy_mock_erc20("Sell", "SELL");
    let contract = setup_buyback_contract(buyback_token);

    let dispatcher = IBuybackDispatcher { contract_address: contract };
    let admin_dispatcher = IBuybackAdminDispatcher { contract_address: contract };

    // Set then clear per-token config
    start_cheat_caller_address(contract, OWNER());
    admin_dispatcher.set_token_config(sell_token, Option::Some(defaults::default_token_config()));
    admin_dispatcher.set_token_config(sell_token, Option::None);
    stop_cheat_caller_address(contract);

    // Should be None again
    assert(dispatcher.get_token_config(sell_token).is_none(), 'Should be None after clear');
}

// ============================================================================
// Per-Token Config Isolation Tests
// ============================================================================

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
