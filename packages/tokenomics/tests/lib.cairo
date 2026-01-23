pub mod fixtures;

// Public modules for cross-test access
pub mod helpers;
mod integration;
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
mod unit;
