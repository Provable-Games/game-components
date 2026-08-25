use ekubo::interfaces::extensions::twamm::OrderKey;
use starknet::ContractAddress;

/// Global configuration defaults that apply when no per-token override exists
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub struct GlobalBuybackConfig {
    /// Default token to acquire (can be overridden per sell token)
    pub default_buy_token: ContractAddress,
    /// Default treasury address where proceeds are sent
    pub default_treasury: ContractAddress,
    /// Default minimum balance required to start a buyback
    pub default_minimum_amount: u128,
    /// Default minimum delay before order can start (0 = can start immediately)
    pub default_min_delay: u64,
    /// Default maximum delay before order can start (0 = no maximum limit)
    pub default_max_delay: u64,
    /// Default minimum duration of the buyback order
    pub default_min_duration: u64,
    /// Default maximum duration of the buyback order
    pub default_max_duration: u64,
    /// Default fee tier for the buyback pool
    pub default_fee: u128,
}

/// Per-token configuration for buyback orders
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub struct TokenBuybackConfig {
    /// Token to acquire through buybacks
    pub buy_token: ContractAddress,
    /// Where proceeds are sent
    pub treasury: ContractAddress,
    /// Minimum balance required to start a buyback (prevents spam/griefing)
    pub minimum_amount: u128,
    /// Minimum delay before order can start
    pub min_delay: u64,
    /// Maximum delay before order can start (0 = no maximum limit)
    pub max_delay: u64,
    /// Minimum duration of the buyback order
    pub min_duration: u64,
    /// Maximum duration of the buyback order
    pub max_duration: u64,
    /// Fee tier for the buyback pool
    pub fee: u128,
}

/// Parameters for creating a buyback order
#[derive(Copy, Drop, Serde)]
pub struct BuybackParams {
    /// The token to sell
    pub sell_token: ContractAddress,
    /// When the order should start (0 = start immediately)
    pub start_time: u64,
    /// When the DCA order should complete
    pub end_time: u64,
}

/// Packed order information stored per order (fits in single storage slot)
#[derive(Copy, Drop, Serde, starknet::Store, PartialEq, Debug)]
pub struct PackedOrderInfo {
    /// When the order started (for Ekubo OrderKey reconstruction)
    pub start_time: u64,
    /// When the order ends
    pub end_time: u64,
    /// Amount of sell token in the order
    pub amount: u128,
}

/// Full information about a specific buyback order (returned by view functions)
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct OrderInfo {
    /// When the order started
    pub start_time: u64,
    /// When the order ends
    pub end_time: u64,
    /// Amount of sell token in the order
    pub amount: u128,
    /// Token being acquired (from sell_token config)
    pub buy_token: ContractAddress,
    /// Pool fee tier (from sell_token config)
    pub fee: u128,
}

/// Permissionless interface for the Autonomous Buyback component
#[starknet::interface]
pub trait IBuyback<TContractState> {
    /// Execute a buyback using all tokens of `sell_token` in the contract
    fn buy_back(ref self: TContractState, params: BuybackParams);

    /// Claim proceeds from completed buyback orders and send to treasury
    fn claim_buyback_proceeds(
        ref self: TContractState, sell_token: ContractAddress, limit: u16,
    ) -> u128;

    /// Sweep any accumulated buy tokens directly to treasury
    fn sweep_buy_token_to_treasury(ref self: TContractState) -> u256;

    /// Get the global configuration defaults
    fn get_global_config(self: @TContractState) -> GlobalBuybackConfig;

    /// Get the per-token configuration (None if not set)
    fn get_token_config(
        self: @TContractState, sell_token: ContractAddress,
    ) -> Option<TokenBuybackConfig>;

    /// Get the effective configuration for a sell token
    fn get_effective_config(
        self: @TContractState, sell_token: ContractAddress,
    ) -> TokenBuybackConfig;

    /// Get the Ekubo positions contract address
    fn get_positions_address(self: @TContractState) -> ContractAddress;

    /// Get the TWAMM extension address
    fn get_extension_address(self: @TContractState) -> ContractAddress;

    /// Get the position token ID for a sell token (0 if not created)
    fn get_position_token_id(self: @TContractState, sell_token: ContractAddress) -> u64;

    /// Get the number of orders created for a sell token
    fn get_order_count(self: @TContractState, sell_token: ContractAddress) -> u128;

    /// Get the bookmark (next order to claim) for a sell token
    fn get_order_bookmark(self: @TContractState, sell_token: ContractAddress) -> u128;

    /// Get the number of unclaimed orders for a sell token
    fn get_unclaimed_orders_count(self: @TContractState, sell_token: ContractAddress) -> u128;

    /// Get information about a specific order
    fn get_order_info(self: @TContractState, sell_token: ContractAddress, index: u128) -> OrderInfo;

    /// Construct an OrderKey for a specific order index
    fn get_order_key(self: @TContractState, sell_token: ContractAddress, index: u128) -> OrderKey;

    /// Get the active buy token for a sell token
    fn get_active_buy_token(self: @TContractState, sell_token: ContractAddress) -> ContractAddress;

    /// Get the active fee for a sell token
    fn get_active_fee(self: @TContractState, sell_token: ContractAddress) -> u128;
}

/// Admin interface for the Autonomous Buyback component
#[starknet::interface]
pub trait IBuybackAdmin<TContractState> {
    /// Set the global configuration defaults
    fn set_global_config(ref self: TContractState, config: GlobalBuybackConfig);

    /// Toggle strict per-token config mode. When enabled, tokens WITHOUT an
    /// explicit per-token config revert (`'No config for token'`) instead of
    /// falling back to the global defaults — governance decides which tokens
    /// are tradeable. Off by default (global fallback, the historic behavior).
    fn set_require_token_config(ref self: TContractState, required: bool);

    /// Set or clear per-token configuration
    fn set_token_config(
        ref self: TContractState, sell_token: ContractAddress, config: Option<TokenBuybackConfig>,
    );
}
