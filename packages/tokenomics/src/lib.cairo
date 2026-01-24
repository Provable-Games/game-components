/// Game Components Tokenomics
///
/// A Cairo library providing reusable components for executing autonomous
/// token buybacks and distributions via Ekubo's TWAMM (Time-Weighted Average Market Maker).
///
/// # Features
/// - Permissionless buyback execution
/// - Per-token configuration with global defaults
/// - Delayed start support for scheduled orders
/// - Minimum amount threshold for spam prevention
/// - Autonomous token distribution with multiple concurrent orders
/// - Support for any ERC20 token
/// - Multiple concurrent DCA orders per token
/// - Configurable order duration and fee parameters
/// - Treasury/recipient destination for acquired tokens
/// - Append-only design: no emergency functions
///
/// # Usage
/// ```cairo
/// // For buyback functionality
/// use game_components_tokenomics::buyback::BuybackComponent;
/// component!(path: BuybackComponent, storage: buyback, event: BuybackEvent);
///
/// // For stream token distribution
/// use game_components_tokenomics::stream::StreamComponent;
/// component!(path: StreamComponent, storage: stream, event: StreamEvent);
/// ```
pub mod buyback;
pub mod constants;
pub mod factory;
pub mod stream;

// Re-exports for convenience - Buyback
pub use buyback::{
    BuybackComponent, BuybackParams, GlobalBuybackConfig, IBuyback, IBuybackAdmin,
    IBuybackAdminDispatcher, IBuybackAdminDispatcherTrait, IBuybackDispatcher,
    IBuybackDispatcherTrait, OrderInfo, PackedOrderInfo, TokenBuybackConfig,
};

// Re-exports for convenience - Constants
pub use constants::{ERC20_UNIT, Errors};

// Re-exports for convenience - Factory
pub use factory::StreamTokenFactory;

// Re-exports for convenience - Stream
pub use stream::{
    CreateTokenParams, DistributionOrder, IStreamToken, IStreamTokenDispatcher,
    IStreamTokenDispatcherTrait, IStreamTokenFactory, IStreamTokenFactoryDispatcher,
    IStreamTokenFactoryDispatcherTrait, LiquidityConfig, StoredDistributionOrder, StreamComponent,
};

#[cfg(test)]
mod tests;
