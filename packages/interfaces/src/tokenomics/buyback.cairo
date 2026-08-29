use ekubo::interfaces::extensions::twamm::OrderKey;

/// Re-exported because `claim_order` takes one: every consumer of this
/// interface needs the type, and requiring them to add a direct `ekubo`
/// dependency for it would be gratuitous.
pub use ekubo::interfaces::extensions::twamm::OrderKey as BuybackOrderKey;
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
    /// Default maximum delay before order can start (0 = must start immediately)
    pub default_max_delay: u64,
    /// Default minimum duration of the buyback order
    pub default_min_duration: u64,
    /// Default maximum duration of the buyback order (must be non-zero)
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
    /// Maximum delay before order can start (0 = must start immediately)
    pub max_delay: u64,
    /// Minimum duration of the buyback order
    pub min_duration: u64,
    /// Maximum duration of the buyback order (must be non-zero)
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


/// Permissionless interface for the Autonomous Buyback component
#[starknet::interface]
pub trait IBuyback<TContractState> {
    /// Execute a buyback using all tokens of `sell_token` in the contract
    fn buy_back(ref self: TContractState, params: BuybackParams);

    /// Claim proceeds for ONE completed order and send them to the treasury.
    ///
    /// The caller supplies the full `OrderKey`, so orders are independent: any
    /// matured order can be claimed at any time, in any sequence. There is no
    /// queue and therefore no head-of-line blocking.
    ///
    /// The key is emitted in full by `BuybackStarted`. Claiming an order twice
    /// yields 0 rather than reverting, so a keeper sweeping several keys is not
    /// broken by a stale one.
    fn claim_order(ref self: TContractState, order_key: OrderKey) -> u128;

    /// `claim_order` over several keys in one call. Returns total proceeds.
    ///
    /// A convenience only — the keys are still supplied by the caller and are
    /// claimed independently, so this reintroduces no ordering of any kind.
    fn claim_orders(ref self: TContractState, order_keys: Span<OrderKey>) -> u128;

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
}

/// Admin interface for the Autonomous Buyback component
#[starknet::interface]
pub trait IBuybackAdmin<TContractState> {
    /// Set the global configuration defaults
    fn set_global_config(ref self: TContractState, config: GlobalBuybackConfig);

    /// Set or clear per-token configuration
    fn set_token_config(
        ref self: TContractState, sell_token: ContractAddress, config: Option<TokenBuybackConfig>,
    );
}
