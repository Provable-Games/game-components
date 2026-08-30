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

/// Largest `amount` a single order can hold: 2**120 - 1.
///
/// The record packs start_time(64) + end_time(64) + amount(120) into one
/// felt252, which has ~251 usable bits. 120 bits caps a single order at
/// ~1.3e36 raw units — 1.3e18 tokens at 18 decimals, far beyond any realistic
/// supply. `buy_back` rejects anything larger rather than truncating silently.
pub const MAX_ORDER_AMOUNT: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

/// Order information stored per order. Occupies ONE storage slot.
///
/// The name used to be aspirational: with `#[derive(starknet::Store)]` this
/// took three slots, because the derive lays out one felt PER FIELD regardless
/// of width — a u32 costs as much as a u128. There is no
/// `#[derive(StorePacking)]`; packing has to be written by hand, which is what
/// `PackedOrderInfoStorePacking` below does.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct PackedOrderInfo {
    /// When the order started (for Ekubo OrderKey reconstruction)
    pub start_time: u64,
    /// When the order ends
    pub end_time: u64,
    /// Amount of sell token in the order. Bounded by `MAX_ORDER_AMOUNT`.
    pub amount: u128,
}

const TWO_64: felt252 = 0x10000000000000000;
const TWO_128: felt252 = 0x100000000000000000000000000000000;
const MASK_64: u256 = 0xFFFFFFFFFFFFFFFF;

/// start_time(64) | end_time(64) | amount(120) in a single felt252.
///
/// Note the amount narrowing is what makes one slot reachable at all:
/// 64 + 64 + 128 = 256 bits does NOT fit, 64 + 64 + 120 = 248 does.
pub impl PackedOrderInfoStorePacking of starknet::storage_access::StorePacking<
    PackedOrderInfo, felt252,
> {
    fn pack(value: PackedOrderInfo) -> felt252 {
        // buy_back asserts this first with a clearer error. Repeated here so no
        // other write path can truncate an amount silently.
        assert(value.amount <= MAX_ORDER_AMOUNT, 'Order amount too large');
        value.start_time.into() + value.end_time.into() * TWO_64 + value.amount.into() * TWO_128
    }

    fn unpack(value: felt252) -> PackedOrderInfo {
        let v: u256 = value.into();
        let start_time: u64 = (v & MASK_64).try_into().unwrap();
        let end_time: u64 = ((v / TWO_64.into()) & MASK_64).try_into().unwrap();
        let amount: u128 = (v / TWO_128.into()).try_into().unwrap();
        PackedOrderInfo { start_time, end_time, amount }
    }
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

    /// Set or clear per-token configuration
    fn set_token_config(
        ref self: TContractState, sell_token: ContractAddress, config: Option<TokenBuybackConfig>,
    );
}
