/// Stream module re-exports
pub mod stream;

// Re-export interfaces from game_components_interfaces
pub use game_components_interfaces::tokenomics::stream::{
    CreateTokenParams, DistributionOrder, IStreamToken, IStreamTokenDispatcher,
    IStreamTokenDispatcherTrait, IStreamTokenFactory, IStreamTokenFactoryAdmin,
    IStreamTokenFactoryAdminDispatcher, IStreamTokenFactoryAdminDispatcherTrait,
    IStreamTokenFactoryDispatcher, IStreamTokenFactoryDispatcherTrait, IStreamTokenSetup,
    IStreamTokenSetupDispatcher, IStreamTokenSetupDispatcherTrait, LiquidityConfig,
    PremintAllocation, StoredDistributionOrder,
};

pub use stream::StreamComponent;
