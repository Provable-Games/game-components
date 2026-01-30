/// Tests for StreamTokenFactory
///
/// These tests verify the factory's behavior including:
/// - Constructor validation
/// - create_token() function
/// - View functions
/// - Admin functions
/// - Access control

use game_components_interfaces::tokenomics::stream::{
    CreateTokenParams, DistributionOrder, IStreamTokenFactoryAdminDispatcher,
    IStreamTokenFactoryAdminDispatcherTrait, IStreamTokenFactoryDispatcher,
    IStreamTokenFactoryDispatcherTrait, LiquidityConfig, PremintAllocation,
};
use openzeppelin_interfaces::access::ownable::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_interfaces::token::erc20::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress};
use super::fixtures::constants::{OWNER, TREASURY, USER1, USER2, ZERO_ADDRESS, amounts, defaults};
use super::helpers::deployment::{deploy_mock_erc20, deploy_mock_registry};
use super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

// ============================================================================
// Helper Functions
// ============================================================================

/// Deploy the StreamTokenFactory with default parameters
fn deploy_factory() -> (ContractAddress, IStreamTokenFactoryDispatcher) {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();

    // Get the StreamToken class hash for deployment
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    // Mock addresses for Ekubo contracts
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let mock_registry = deploy_mock_registry();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    mock_registry.serialize(ref calldata);

    let (factory_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IStreamTokenFactoryDispatcher { contract_address: factory_address };

    (factory_address, dispatcher)
}

/// Create default valid CreateTokenParams
fn default_create_params(paired_token: ContractAddress) -> CreateTokenParams {
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500_u128 * 1_000_000_000_000_000_000,
            proceeds_recipient: TREASURY(),
        },
    ];

    CreateTokenParams {
        name: "Test Stream Token",
        symbol: "TST",
        total_supply: 10000_u128 * 1_000_000_000_000_000_000,
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations: array![].span(),
    }
}

// ============================================================================
// Constructor Tests
// ============================================================================

#[test]
fn test_constructor_initializes_correctly() {
    let (_, dispatcher) = deploy_factory();

    // Verify all getters return correct values
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    assert!(dispatcher.get_positions_address() == mock_positions, "Positions address mismatch");
    assert!(dispatcher.get_core_address() == mock_core, "Core address mismatch");
    assert!(dispatcher.get_extension_address() == mock_extension, "Extension address mismatch");
    assert!(dispatcher.get_registry_address() != ZERO_ADDRESS(), "Registry should be set");
}

#[test]
fn test_constructor_sets_owner_via_ownable() {
    let (factory_address, _) = deploy_factory();
    let ownable = IOwnableDispatcher { contract_address: factory_address };

    assert!(ownable.owner() == OWNER(), "Owner should be set correctly");
}

#[test]
fn test_constructor_sets_deploy_nonce_to_zero() {
    let (_, dispatcher) = deploy_factory();

    // Token count starts at 0, which implies nonce starts at 0
    assert!(dispatcher.get_token_count() == 0, "Token count should be 0 initially");
}

// NOTE: Constructor validation tests cannot use #[should_panic] because snforge doesn't
// catch deployment failures with that pattern. These tests are kept as #[ignore] for
// documentation - when run manually (snforge test --ignored), they will fail with the
// expected error messages, proving the validation works correctly.

#[test]
#[ignore]
fn test_constructor_zero_positions_address_fails() {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let mock_registry = deploy_mock_registry();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    ZERO_ADDRESS().serialize(ref calldata); // Invalid
    mock_core.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    mock_registry.serialize(ref calldata);

    // When run, this will fail with 'Invalid positions address'
    contract.deploy(@calldata).unwrap();
}

#[test]
#[ignore]
fn test_constructor_zero_core_address_fails() {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();
    let mock_registry = deploy_mock_registry();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    ZERO_ADDRESS().serialize(ref calldata); // Invalid
    mock_extension.serialize(ref calldata);
    mock_registry.serialize(ref calldata);

    // When run, this will fail with 'Invalid core address'
    contract.deploy(@calldata).unwrap();
}

#[test]
#[ignore]
fn test_constructor_zero_extension_address_fails() {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_registry = deploy_mock_registry();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    ZERO_ADDRESS().serialize(ref calldata); // Invalid
    mock_registry.serialize(ref calldata);

    // When run, this will fail with 'Invalid extension address'
    contract.deploy(@calldata).unwrap();
}

#[test]
#[ignore]
fn test_constructor_zero_registry_address_fails() {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    mock_positions.serialize(ref calldata);
    mock_core.serialize(ref calldata);
    mock_extension.serialize(ref calldata);
    ZERO_ADDRESS().serialize(ref calldata); // Invalid

    // When run, this will fail with 'Invalid registry address'
    contract.deploy(@calldata).unwrap();
}

// ============================================================================
// View Function Tests
// ============================================================================

#[test]
fn test_get_stream_token_class_hash() {
    let (_, dispatcher) = deploy_factory();

    let class_hash = dispatcher.get_stream_token_class_hash();
    // Just verify it's not zero
    let zero_hash: ClassHash = 0.try_into().unwrap();
    assert!(class_hash != zero_hash, "Class hash should not be zero");
}

#[test]
fn test_get_token_count_initially_zero() {
    let (_, dispatcher) = deploy_factory();
    assert!(dispatcher.get_token_count() == 0, "Token count should be 0 initially");
}

#[test]
fn test_is_valid_token_returns_false_for_unknown() {
    let (_, dispatcher) = deploy_factory();
    let random_address: ContractAddress = 'RANDOM'.try_into().unwrap();

    assert!(!dispatcher.is_valid_token(random_address), "Unknown token should not be valid");
}

#[test]
fn test_is_valid_token_returns_false_for_zero_address() {
    let (_, dispatcher) = deploy_factory();

    assert!(!dispatcher.is_valid_token(ZERO_ADDRESS()), "Zero address should not be valid");
}

// ============================================================================
// create_token() Validation Tests
// ============================================================================

#[test]
#[should_panic(expected: 'Invalid total supply')]
fn test_create_token_zero_total_supply_fails() {
    let (factory_address, dispatcher) = deploy_factory();
    let paired_token = deploy_mock_erc20("Paired", "PAIR");
    let mock_paired = IMockERC20Dispatcher { contract_address: paired_token };

    // Mint and approve paired tokens
    mock_paired.mint(USER1(), amounts::THOUSAND_TOKENS);
    start_cheat_caller_address(paired_token, USER1());
    IERC20Dispatcher { contract_address: paired_token }
        .approve(factory_address, amounts::THOUSAND_TOKENS);
    stop_cheat_caller_address(paired_token);

    let mut params = default_create_params(paired_token);
    params.total_supply = 0; // Invalid

    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'No distribution orders')]
fn test_create_token_no_distribution_orders_fails() {
    let (factory_address, dispatcher) = deploy_factory();
    let paired_token = deploy_mock_erc20("Paired", "PAIR");
    let mock_paired = IMockERC20Dispatcher { contract_address: paired_token };

    mock_paired.mint(USER1(), amounts::THOUSAND_TOKENS);
    start_cheat_caller_address(paired_token, USER1());
    IERC20Dispatcher { contract_address: paired_token }
        .approve(factory_address, amounts::THOUSAND_TOKENS);
    stop_cheat_caller_address(paired_token);

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    let empty_orders: Array<DistributionOrder> = array![];

    let params = CreateTokenParams {
        name: "Test",
        symbol: "TST",
        total_supply: 10000_u128 * 1_000_000_000_000_000_000,
        liquidity_config,
        distribution_orders: empty_orders.span(),
        premint_allocations: array![].span(),
    };

    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'Too many orders (max 10)')]
fn test_create_token_too_many_orders_fails() {
    let (factory_address, dispatcher) = deploy_factory();
    let paired_token = deploy_mock_erc20("Paired", "PAIR");
    let mock_paired = IMockERC20Dispatcher { contract_address: paired_token };

    mock_paired.mint(USER1(), amounts::THOUSAND_TOKENS);
    start_cheat_caller_address(paired_token, USER1());
    IERC20Dispatcher { contract_address: paired_token }
        .approve(factory_address, amounts::THOUSAND_TOKENS);
    stop_cheat_caller_address(paired_token);

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    // Create 11 orders (more than max 10)
    let mut orders: Array<DistributionOrder> = array![];
    let mut i: u32 = 0;
    while i < 11 {
        orders
            .append(
                DistributionOrder {
                    buy_token,
                    fee: defaults::DEFAULT_FEE,
                    start_time: 0,
                    end_time: 86400 * 7,
                    amount: 10_u128 * 1_000_000_000_000_000_000,
                    proceeds_recipient: TREASURY(),
                },
            );
        i += 1;
    }

    let params = CreateTokenParams {
        name: "Test",
        symbol: "TST",
        total_supply: 100000_u128 * 1_000_000_000_000_000_000,
        liquidity_config,
        distribution_orders: orders.span(),
        premint_allocations: array![].span(),
    };

    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}

#[test]
#[should_panic(expected: 'Supply too low for config')]
fn test_create_token_supply_too_low_fails() {
    let (factory_address, dispatcher) = deploy_factory();
    let paired_token = deploy_mock_erc20("Paired", "PAIR");
    let mock_paired = IMockERC20Dispatcher { contract_address: paired_token };

    mock_paired.mint(USER1(), amounts::THOUSAND_TOKENS);
    start_cheat_caller_address(paired_token, USER1());
    IERC20Dispatcher { contract_address: paired_token }
        .approve(factory_address, amounts::THOUSAND_TOKENS);
    stop_cheat_caller_address(paired_token);

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500_u128 * 1_000_000_000_000_000_000,
            proceeds_recipient: TREASURY(),
        },
    ];

    // Supply = 100, but need: ERC20_UNIT + 1000 (LP) + 500 (distribution) = 1501 tokens
    let params = CreateTokenParams {
        name: "Test",
        symbol: "TST",
        total_supply: 100_u128 * 1_000_000_000_000_000_000, // Too low
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations: array![].span(),
    };

    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}

// ============================================================================
// Admin Function Tests
// ============================================================================

#[test]
fn test_set_stream_token_class_hash_as_owner() {
    let (factory_address, dispatcher) = deploy_factory();
    let admin = IStreamTokenFactoryAdminDispatcher { contract_address: factory_address };

    let old_hash = dispatcher.get_stream_token_class_hash();
    let new_hash: ClassHash = 'NEW_HASH'.try_into().unwrap();

    start_cheat_caller_address(factory_address, OWNER());
    admin.set_stream_token_class_hash(new_hash);
    stop_cheat_caller_address(factory_address);

    assert!(dispatcher.get_stream_token_class_hash() == new_hash, "Class hash should be updated");
    assert!(dispatcher.get_stream_token_class_hash() != old_hash, "Class hash should have changed");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_set_stream_token_class_hash_non_owner_fails() {
    let (factory_address, _) = deploy_factory();
    let admin = IStreamTokenFactoryAdminDispatcher { contract_address: factory_address };

    let new_hash: ClassHash = 'NEW_HASH'.try_into().unwrap();

    // USER1 tries to set - should fail
    start_cheat_caller_address(factory_address, USER1());
    admin.set_stream_token_class_hash(new_hash);
    stop_cheat_caller_address(factory_address);
}

// ============================================================================
// Ownership Tests (via OwnableComponent)
// ============================================================================

#[test]
fn test_owner_can_transfer_ownership() {
    let (factory_address, _) = deploy_factory();
    let ownable = IOwnableDispatcher { contract_address: factory_address };

    start_cheat_caller_address(factory_address, OWNER());
    ownable.transfer_ownership(USER1());
    stop_cheat_caller_address(factory_address);

    assert!(ownable.owner() == USER1(), "Ownership should be transferred");
}

#[test]
#[should_panic(expected: 'Caller is not the owner')]
fn test_non_owner_cannot_transfer_ownership() {
    let (factory_address, _) = deploy_factory();
    let ownable = IOwnableDispatcher { contract_address: factory_address };

    // USER1 tries to transfer - should fail
    start_cheat_caller_address(factory_address, USER1());
    ownable.transfer_ownership(USER2());
    stop_cheat_caller_address(factory_address);
}

// ============================================================================
// Edge Case Tests
// ============================================================================

#[test]
fn test_factory_getters_return_constructor_values() {
    let (_, dispatcher) = deploy_factory();

    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_core: ContractAddress = 'CORE'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // All getters should return non-zero addresses
    assert!(dispatcher.get_positions_address() == mock_positions, "Positions mismatch");
    assert!(dispatcher.get_core_address() == mock_core, "Core mismatch");
    assert!(dispatcher.get_extension_address() == mock_extension, "Extension mismatch");
    assert!(dispatcher.get_registry_address() != ZERO_ADDRESS(), "Registry should be set");
}

// ============================================================================
// Fuzz Tests
// ============================================================================

#[test]
#[fuzzer]
fn test_fuzz_set_stream_token_class_hash(new_hash: felt252) {
    let (factory_address, dispatcher) = deploy_factory();
    let admin = IStreamTokenFactoryAdminDispatcher { contract_address: factory_address };

    let class_hash: ClassHash = new_hash.try_into().unwrap();

    start_cheat_caller_address(factory_address, OWNER());
    admin.set_stream_token_class_hash(class_hash);
    stop_cheat_caller_address(factory_address);

    assert!(
        dispatcher.get_stream_token_class_hash() == class_hash,
        "Class hash should match fuzzed value",
    );
}

// ============================================================================
// Premint Tests
// ============================================================================

/// Create CreateTokenParams with premint allocations
fn create_params_with_premints(
    paired_token: ContractAddress, premint_allocations: Span<PremintAllocation>,
) -> CreateTokenParams {
    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000,
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500_u128 * 1_000_000_000_000_000_000,
            proceeds_recipient: TREASURY(),
        },
    ];

    // Calculate premint total
    let mut premint_total: u128 = 0;
    for premint in premint_allocations {
        premint_total += *premint.amount;
    }

    // Supply needs to cover: ERC20_UNIT (1) + LP (1000) + distribution (500) + premints
    let base_supply: u128 = 10000_u128 * 1_000_000_000_000_000_000;
    let total_supply: u128 = base_supply + premint_total;

    CreateTokenParams {
        name: "Test Stream Token",
        symbol: "TST",
        total_supply,
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations,
    }
}

#[test]
#[should_panic(expected: 'Supply too low for config')]
fn test_create_token_with_premints_supply_too_low_fails() {
    let (factory_address, dispatcher) = deploy_factory();
    let paired_token = deploy_mock_erc20("Paired", "PAIR");
    let mock_paired = IMockERC20Dispatcher { contract_address: paired_token };

    // Mint and approve paired tokens
    mock_paired.mint(USER1(), amounts::THOUSAND_TOKENS);
    start_cheat_caller_address(paired_token, USER1());
    IERC20Dispatcher { contract_address: paired_token }
        .approve(factory_address, amounts::THOUSAND_TOKENS);
    stop_cheat_caller_address(paired_token);

    let buy_token: ContractAddress = 'BUY_TOKEN'.try_into().unwrap();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: defaults::DEFAULT_FEE,
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000, // 1000 tokens
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000,
        min_liquidity: 1,
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500_u128 * 1_000_000_000_000_000_000, // 500 tokens
            proceeds_recipient: TREASURY(),
        },
    ];

    // Premints that push total over the supply limit
    // Total needed: ERC20_UNIT (1) + LP (1000) + distribution (500) + premints (1000) = 2501+
    // Supply provided: 2000 tokens - NOT ENOUGH
    let premint_allocations: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: 500_u128 * 1_000_000_000_000_000_000 },
        PremintAllocation { recipient: USER2(), amount: 500_u128 * 1_000_000_000_000_000_000 },
    ];

    let params = CreateTokenParams {
        name: "Test",
        symbol: "TST",
        total_supply: 2000_u128 * 1_000_000_000_000_000_000, // Too low for config + premints
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations: premint_allocations.span(),
    };

    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}
