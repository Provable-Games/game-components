use ekubo::types::i129::i129;
use game_components_tokenomics::{
    DistributionOrder, GlobalBuybackConfig, IStreamTokenDispatcher, LiquidityConfig,
    PremintAllocation,
};
use openzeppelin_interfaces::erc20::IERC20Dispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use super::super::fixtures::constants::{OWNER, TREASURY, defaults};
use super::super::mocks::{IMockERC20Dispatcher, IMockERC20DispatcherTrait};

/// Deploy a mock ERC20 token
pub fn deploy_mock_erc20(name: ByteArray, symbol: ByteArray) -> ContractAddress {
    let contract = declare("MockERC20").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];

    // Serialize name and symbol
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);

    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

/// Deploy the AutonomousBuyback preset contract
pub fn deploy_autonomous_buyback(
    owner: ContractAddress,
    global_config: GlobalBuybackConfig,
    positions_address: ContractAddress,
    extension_address: ContractAddress,
) -> ContractAddress {
    let contract = declare("AutonomousBuyback").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];

    // Serialize constructor arguments
    owner.serialize(ref calldata);
    global_config.serialize(ref calldata);
    positions_address.serialize(ref calldata);
    extension_address.serialize(ref calldata);

    let (address, _) = contract.deploy(@calldata).unwrap();
    address
}

/// Deploy a mock ERC20 and mint tokens to a recipient
pub fn deploy_and_mint_token(
    name: ByteArray, symbol: ByteArray, recipient: ContractAddress, amount: u256,
) -> ContractAddress {
    let token_address = deploy_mock_erc20(name, symbol);
    let token = IMockERC20Dispatcher { contract_address: token_address };
    token.mint(recipient, amount);
    token_address
}

/// Helper struct for test setup
#[derive(Drop)]
pub struct TestSetup {
    pub buyback_contract: ContractAddress,
    pub buyback_token: ContractAddress,
    pub sell_token: ContractAddress,
}

/// Deploy a complete test setup with buyback contract and tokens
/// Uses mock addresses for Ekubo contracts (for unit testing)
pub fn deploy_test_setup_mock() -> TestSetup {
    // Deploy mock tokens
    let buyback_token = deploy_mock_erc20("Buyback Token", "BUY");
    let sell_token = deploy_mock_erc20("Sell Token", "SELL");

    // Mock Ekubo addresses (not real contracts - for unit testing only)
    let mock_positions: ContractAddress = 'POSITIONS'.try_into().unwrap();
    let mock_extension: ContractAddress = 'EXTENSION'.try_into().unwrap();

    // Deploy buyback contract with global config
    let global_config = defaults::global_config_with(buyback_token, TREASURY());
    let buyback_contract = deploy_autonomous_buyback(
        OWNER(), global_config, mock_positions, mock_extension,
    );

    TestSetup { buyback_contract, buyback_token, sell_token }
}

/// Helper struct for stream token test setup
#[derive(Drop)]
pub struct StreamTokenSetup {
    pub token_address: ContractAddress,
    pub token: IStreamTokenDispatcher,
    pub erc20: IERC20Dispatcher,
    pub factory: ContractAddress,
}

/// Deploy the mock token registry
pub fn deploy_mock_registry() -> ContractAddress {
    let contract = declare("MockTokenRegistry").unwrap().contract_class();
    let (address, _) = contract.deploy(@array![]).unwrap();
    address
}

/// Deploy a StreamToken for testing
/// Uses mock Ekubo addresses (for unit testing only)
pub fn deploy_stream_token() -> StreamTokenSetup {
    let contract = declare("StreamToken").unwrap().contract_class();

    // Factory is the caller/deployer - use OWNER for tests
    let factory = OWNER();

    // Deploy mock registry (real deployed contract to accept register_token call)
    let mock_registry = deploy_mock_registry();

    // Mock Ekubo addresses (not real contracts - for unit testing only)
    // These are not called during constructor, only later during setup
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
        fee: defaults::DEFAULT_FEE,
        initial_tick: i129 { mag: 0, sign: false },
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000, // 1000 tokens
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000, // 100 tokens
        min_liquidity: 1,
    };

    // Distribution order - sells stream tokens for buy_token
    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7, // 1 week
            amount: 500_u128 * 1_000_000_000_000_000_000, // 500 tokens
            proceeds_recipient: TREASURY(),
        },
    ];

    // Total supply needs to cover:
    // - 1 token for registry
    // - 1000 tokens for liquidity
    // - 500 tokens for distribution
    // Plus extra for testing (give users some tokens)
    let total_supply: u128 = 10000_u128 * 1_000_000_000_000_000_000; // 10,000 tokens

    let mut calldata: Array<felt252> = array![];

    // Serialize constructor arguments
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

/// Deploy a StreamToken with premint allocations for testing
/// Uses mock Ekubo addresses (for unit testing only)
pub fn deploy_stream_token_with_premints(
    premint_allocations: Span<PremintAllocation>,
) -> StreamTokenSetup {
    let contract = declare("StreamToken").unwrap().contract_class();

    // Factory is the caller/deployer - use OWNER for tests
    let factory = OWNER();

    // Deploy mock registry (real deployed contract to accept register_token call)
    let mock_registry = deploy_mock_registry();

    // Mock Ekubo addresses (not real contracts - for unit testing only)
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
        fee: defaults::DEFAULT_FEE,
        initial_tick: i129 { mag: 0, sign: false },
        stream_token_amount: 1000_u128 * 1_000_000_000_000_000_000, // 1000 tokens
        paired_token_amount: 100_u128 * 1_000_000_000_000_000_000, // 100 tokens
        min_liquidity: 1,
    };

    // Distribution order - sells stream tokens for buy_token
    let distribution_orders: Array<DistributionOrder> = array![
        DistributionOrder {
            buy_token,
            fee: defaults::DEFAULT_FEE,
            start_time: 0,
            end_time: 86400 * 7, // 1 week
            amount: 500_u128 * 1_000_000_000_000_000_000, // 500 tokens
            proceeds_recipient: TREASURY(),
        },
    ];

    // Calculate premint total for supply calculation
    let mut premint_total: u128 = 0;
    for premint in premint_allocations {
        premint_total += *premint.amount;
    }

    // Total supply needs to cover:
    // - 1 token for registry
    // - 1000 tokens for liquidity
    // - 500 tokens for distribution
    // - premint_total tokens for premints
    // Plus extra for testing
    let base_supply: u128 = 10000_u128 * 1_000_000_000_000_000_000;
    let total_supply: u128 = base_supply + premint_total;

    let mut calldata: Array<felt252> = array![];

    // Serialize constructor arguments
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
    premint_allocations.serialize(ref calldata);

    let (token_address, _) = contract.deploy(@calldata).unwrap();

    StreamTokenSetup {
        token_address,
        token: IStreamTokenDispatcher { contract_address: token_address },
        erc20: IERC20Dispatcher { contract_address: token_address },
        factory,
    }
}
