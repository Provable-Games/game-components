use ekubo::interfaces::extensions::twamm::OrderKey;
use ekubo::types::i129::i129;
use starknet::ContractAddress;

/// Configuration for a single distribution order
/// Each order sells stream tokens for a specific buy token over time
#[derive(Copy, Drop, Serde)]
pub struct DistributionOrder {
    /// Token to receive from sales (e.g., USDC, ETH)
    pub buy_token: ContractAddress,
    /// Pool fee tier (0.128 format - e.g., 170141183460469231731687303715884105728 for 0.5%)
    pub fee: u128,
    /// Order start time (0 = start immediately when distributions begin)
    pub start_time: u64,
    /// When distribution ends (must be TWAMM-aligned)
    pub end_time: u64,
    /// Amount of stream tokens to distribute
    pub amount: u128,
    /// Address where sale proceeds are sent (e.g., buyback contract, treasury)
    pub proceeds_recipient: ContractAddress,
}

/// Stored version of distribution order with additional tracking data
#[derive(Copy, Drop, Serde, starknet::Store)]
pub struct StoredDistributionOrder {
    /// Token to receive from sales
    pub buy_token: ContractAddress,
    /// Pool fee tier
    pub fee: u128,
    /// Order start time
    pub start_time: u64,
    /// Order end time
    pub end_time: u64,
    /// Amount of stream tokens to distribute
    pub amount: u128,
    /// Address where sale proceeds are sent
    pub proceeds_recipient: ContractAddress,
}

/// Initial liquidity configuration for the primary pool
#[derive(Copy, Drop, Serde)]
pub struct LiquidityConfig {
    /// Token to pair with stream token for liquidity
    pub paired_token: ContractAddress,
    /// Pool fee tier
    pub fee: u128,
    /// Initial price tick for the pool
    pub initial_tick: i129,
    /// Amount of stream tokens for initial liquidity
    pub stream_token_amount: u128,
    /// Amount of paired tokens for initial liquidity
    pub paired_token_amount: u128,
    /// Minimum liquidity to accept (slippage protection)
    pub min_liquidity: u128,
}

/// Parameters for creating a new stream token
#[derive(Drop, Serde)]
pub struct CreateTokenParams {
    /// Token name
    pub name: ByteArray,
    /// Token symbol
    pub symbol: ByteArray,
    /// Total supply of tokens to mint
    pub total_supply: u128,
    /// Initial liquidity configuration
    pub liquidity_config: LiquidityConfig,
    /// Distribution orders to create
    pub distribution_orders: Span<DistributionOrder>,
}

/// Permissionless interface for StreamToken
/// All functions can be called by anyone
#[starknet::interface]
pub trait IStreamToken<TContractState> {
    /// Burn tokens from the caller's balance
    ///
    /// # Arguments
    /// * `amount` - Amount of tokens to burn
    fn burn(ref self: TContractState, amount: u256);

    /// Burn tokens from an account using the caller's allowance
    ///
    /// # Arguments
    /// * `account` - Account to burn tokens from
    /// * `amount` - Amount of tokens to burn
    ///
    /// # Requirements
    /// - Caller must have allowance for `account`'s tokens of at least `amount`
    fn burn_from(ref self: TContractState, account: ContractAddress, amount: u256);

    /// Claim proceeds from a completed distribution order and send to recipient
    ///
    /// # Arguments
    /// * `order_index` - Index of the order to claim (0-based)
    ///
    /// # Returns
    /// Amount of buy tokens claimed
    fn claim_distribution_proceeds(ref self: TContractState, order_index: u32) -> u128;

    /// Get the total number of distribution orders
    fn get_order_count(self: @TContractState) -> u32;

    /// Get a specific distribution order by index
    fn get_order(self: @TContractState, order_index: u32) -> StoredDistributionOrder;

    /// Get the position ID for a specific buy token and fee combination
    fn get_position_id(self: @TContractState, buy_token: ContractAddress, fee: u128) -> u64;

    /// Construct an OrderKey for a specific distribution order
    fn get_order_key(self: @TContractState, order_index: u32) -> OrderKey;

    /// Check if the token has completed initialization
    fn is_initialized(self: @TContractState) -> bool;

    /// Get the Ekubo positions contract address
    fn get_positions_address(self: @TContractState) -> ContractAddress;

    /// Get the Ekubo core contract address
    fn get_core_address(self: @TContractState) -> ContractAddress;

    /// Get the TWAMM extension address
    fn get_extension_address(self: @TContractState) -> ContractAddress;

    /// Get the liquidity position ID
    fn get_liquidity_position_id(self: @TContractState) -> u64;

    /// Get the primary pool ID (for the liquidity pool)
    fn get_pool_id(self: @TContractState) -> u256;

    /// Get the deployment state
    /// 0 = constructed, 1 = liquidity_provided, 2 = distributions_started
    fn get_deployment_state(self: @TContractState) -> u8;
}

/// Factory-only interface for StreamToken setup
/// These functions should only be callable by the factory during deployment
#[starknet::interface]
pub trait IStreamTokenSetup<TContractState> {
    /// Provide initial liquidity to the primary pool
    ///
    /// # Returns
    /// (position_id, liquidity, token0_amount, token1_amount)
    fn provide_initial_liquidity(ref self: TContractState) -> (u64, u128, u256, u256);

    /// Start all distribution orders
    fn start_distributions(ref self: TContractState);
}

/// Interface for the StreamToken Factory
#[starknet::interface]
pub trait IStreamTokenFactory<TContractState> {
    /// Create a new stream token with distribution orders
    ///
    /// # Arguments
    /// * `params` - Token creation parameters
    ///
    /// # Returns
    /// Address of the newly created token
    fn create_token(ref self: TContractState, params: CreateTokenParams) -> ContractAddress;

    /// Check if an address is a valid token created by this factory
    fn is_valid_token(self: @TContractState, token: ContractAddress) -> bool;

    /// Get the total number of tokens created by this factory
    fn get_token_count(self: @TContractState) -> u64;

    /// Get the class hash used for deploying stream tokens
    fn get_stream_token_class_hash(self: @TContractState) -> starknet::ClassHash;

    /// Get the Ekubo positions contract address
    fn get_positions_address(self: @TContractState) -> ContractAddress;

    /// Get the Ekubo core contract address
    fn get_core_address(self: @TContractState) -> ContractAddress;

    /// Get the TWAMM extension address
    fn get_extension_address(self: @TContractState) -> ContractAddress;

    /// Get the token registry address
    fn get_registry_address(self: @TContractState) -> ContractAddress;
}

/// Admin interface for the StreamToken Factory
#[starknet::interface]
pub trait IStreamTokenFactoryAdmin<TContractState> {
    /// Update the class hash used for deploying stream tokens
    fn set_stream_token_class_hash(ref self: TContractState, class_hash: starknet::ClassHash);
}
