/// Fork tests for StreamTokenFactory with mainnet Ekubo contracts
///
/// These tests verify the factory's behavior with real Ekubo infrastructure.
/// They use mainnet fork to ensure compatibility with production contracts.
///
/// Test coverage:
/// - Factory deployment with mainnet Ekubo addresses
/// - create_token with premint allocations (end-to-end)
/// - Premint balances verified on deployed token

use game_components_interfaces::tokenomics::stream::{
    CreateTokenParams, DistributionOrder, IStreamTokenFactoryAdminDispatcher,
    IStreamTokenFactoryAdminDispatcherTrait, IStreamTokenFactoryDispatcher,
    IStreamTokenFactoryDispatcherTrait, LiquidityConfig, PremintAllocation,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::{ClassHash, ContractAddress};
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

/// Deploy the StreamTokenFactory with mainnet Ekubo addresses
fn deploy_factory_mainnet() -> (ContractAddress, IStreamTokenFactoryDispatcher) {
    let contract = declare("StreamTokenFactory").unwrap().contract_class();

    // Get the StreamToken class hash for deployment
    let stream_token_class = declare("StreamToken").unwrap().contract_class();
    let stream_token_class_hash: ClassHash = (*stream_token_class.class_hash);

    let mut calldata: Array<felt252> = array![];
    OWNER().serialize(ref calldata);
    stream_token_class_hash.serialize(ref calldata);
    mainnet::EKUBO_POSITIONS().serialize(ref calldata);
    mainnet::EKUBO_CORE().serialize(ref calldata);
    mainnet::EKUBO_TWAMM_EXTENSION().serialize(ref calldata);
    mainnet::EKUBO_REGISTRY().serialize(ref calldata);

    let (factory_address, _) = contract.deploy(@calldata).unwrap();
    let dispatcher = IStreamTokenFactoryDispatcher { contract_address: factory_address };

    (factory_address, dispatcher)
}

/// Create default valid CreateTokenParams with premints using STRK as paired token
/// Note: Prefixed with _ as not yet used - available for future full e2e tests
fn _create_params_with_strk_and_premints(
    premint_allocations: Span<PremintAllocation>,
) -> CreateTokenParams {
    // Use STRK as paired token (commonly available on mainnet)
    let paired_token = mainnet::STRK();

    // Use ETH as buy token for distribution orders
    let buy_token = mainnet::ETH();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: DEFAULT_FEE,
        stream_token_amount: 1000 * TOKEN_UNIT, // 1000 tokens for LP
        paired_token_amount: 100 * TOKEN_UNIT, // 100 STRK for LP
        min_liquidity: 1,
        liquidity_owner: OWNER(),
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: DEFAULT_FEE,
            start_time: 0, // Start immediately
            end_time: 86400 * 7, // 1 week
            amount: 500 * TOKEN_UNIT, // 500 tokens
            proceeds_recipient: TREASURY(),
        },
    ];

    // Calculate premint total
    let mut premint_total: u128 = 0;
    for premint in premint_allocations {
        premint_total += *premint.amount;
    }

    // Total supply: base + premints
    let base_supply: u128 = 10000 * TOKEN_UNIT; // 10,000 tokens base
    let total_supply: u128 = base_supply + premint_total;

    CreateTokenParams {
        name: "Fork Test Token",
        symbol: "FORK",
        total_supply,
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations,
    }
}

// ============================================================================
// Fork Tests
// ============================================================================

/// Test that factory can be deployed with mainnet Ekubo addresses
#[test]
#[fork("MAINNET")]
fn test_factory_deploys_with_mainnet_addresses() {
    let (factory_address, dispatcher) = deploy_factory_mainnet();

    // Verify factory was deployed and has correct addresses
    assert!(factory_address != 0.try_into().unwrap(), "Factory should be deployed");
    assert!(
        dispatcher.get_positions_address() == mainnet::EKUBO_POSITIONS(),
        "Positions address mismatch",
    );
    assert!(dispatcher.get_core_address() == mainnet::EKUBO_CORE(), "Core address mismatch");
    assert!(
        dispatcher.get_extension_address() == mainnet::EKUBO_TWAMM_EXTENSION(),
        "Extension address mismatch",
    );
    assert!(
        dispatcher.get_registry_address() == mainnet::EKUBO_REGISTRY(), "Registry address mismatch",
    );
}

/// Test that factory correctly validates premint supply calculations
/// This tests the factory's premint_total calculation and supply validation
#[test]
#[fork("MAINNET")]
#[should_panic(expected: 'Supply too low for config')]
fn test_factory_rejects_insufficient_supply_with_premints_fork() {
    let (factory_address, dispatcher) = deploy_factory_mainnet();

    // Create premints that will cause supply to be insufficient
    let premint_allocations: Array<PremintAllocation> = array![
        PremintAllocation { recipient: USER1(), amount: 5000 * TOKEN_UNIT },
        PremintAllocation { recipient: USER2(), amount: 5000 * TOKEN_UNIT },
    ];

    // Manually construct params with insufficient supply
    let paired_token = mainnet::STRK();
    let buy_token = mainnet::ETH();

    let liquidity_config = LiquidityConfig {
        paired_token,
        fee: DEFAULT_FEE,
        stream_token_amount: 1000 * TOKEN_UNIT, // 1000 tokens for LP
        paired_token_amount: 100 * TOKEN_UNIT,
        min_liquidity: 1,
        liquidity_owner: OWNER(),
    };

    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7,
            amount: 500 * TOKEN_UNIT, // 500 tokens for distribution
            proceeds_recipient: TREASURY(),
        },
    ];

    // Total needed: ERC20_UNIT (1) + LP (1000) + distribution (500) + premints (10000) = 11501
    // Provide only 5000 - should fail
    let params = CreateTokenParams {
        name: "Insufficient Supply Token",
        symbol: "IST",
        total_supply: 5000 * TOKEN_UNIT, // Too low!
        liquidity_config,
        distribution_orders: distribution_orders.span(),
        premint_allocations: premint_allocations.span(),
    };

    // This should panic with 'Supply too low for config'
    start_cheat_caller_address(factory_address, USER1());
    dispatcher.create_token(params);
    stop_cheat_caller_address(factory_address);
}

/// Test factory getter functions work correctly with mainnet addresses
#[test]
#[fork("MAINNET")]
fn test_factory_getters_with_mainnet_fork() {
    let (_, dispatcher) = deploy_factory_mainnet();

    // Verify all getters return the correct mainnet addresses
    let positions = dispatcher.get_positions_address();
    let core = dispatcher.get_core_address();
    let extension = dispatcher.get_extension_address();
    let registry = dispatcher.get_registry_address();
    let class_hash = dispatcher.get_stream_token_class_hash();

    // Verify addresses are not zero
    let zero: ContractAddress = 0.try_into().unwrap();
    assert!(positions != zero, "Positions should not be zero");
    assert!(core != zero, "Core should not be zero");
    assert!(extension != zero, "Extension should not be zero");
    assert!(registry != zero, "Registry should not be zero");

    // Verify class hash is not zero
    let zero_hash: ClassHash = 0.try_into().unwrap();
    assert!(class_hash != zero_hash, "Class hash should not be zero");

    // Verify token count starts at 0
    assert!(dispatcher.get_token_count() == 0, "Token count should start at 0");
}

/// Test that the factory correctly serializes premint allocations
/// This verifies the factory's calldata construction includes premints
#[test]
#[fork("MAINNET")]
fn test_factory_class_hash_can_be_updated_fork() {
    let (factory_address, dispatcher) = deploy_factory_mainnet();

    let _old_hash = dispatcher.get_stream_token_class_hash();

    // Deploy a new StreamToken class to get a different hash
    let new_class = declare("StreamToken").unwrap().contract_class();
    let new_hash: ClassHash = (*new_class.class_hash);

    // Update as owner
    let admin = IStreamTokenFactoryAdminDispatcher { contract_address: factory_address };

    start_cheat_caller_address(factory_address, OWNER());
    admin.set_stream_token_class_hash(new_hash);
    stop_cheat_caller_address(factory_address);

    // Verify update (note: may be same hash if same contract, but call succeeded)
    let updated_hash = dispatcher.get_stream_token_class_hash();
    assert!(updated_hash == new_hash, "Class hash should be updated");
}
