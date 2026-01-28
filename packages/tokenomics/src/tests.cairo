pub mod fixtures;
pub mod helpers;
pub mod mocks;
/// Test suite for the Autonomous Buyback library
///
/// Test categories:
/// - unit: Direct component tests without contract deployment
/// - integration: Full contract deployment and interaction tests
///
/// Test utilities:
/// - helpers: Deployment and setup utilities
/// - mocks: Mock contracts for isolated testing
/// - fixtures: Test constants and configurations
mod test_buyback;
mod test_constants;
mod test_factory;
mod test_factory_fork;
mod test_premint;
mod test_preset;
mod test_stream;
mod test_stream_burn;
mod test_stream_fork;
mod test_stream_lifecycle;
