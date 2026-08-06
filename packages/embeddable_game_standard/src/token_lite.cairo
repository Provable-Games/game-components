pub mod interface;

// The deployable example (TokenLiteContract) lives in the test_common package
// so downstream consumers can declare it via build-external-contracts.
#[cfg(test)]
mod tests;
pub mod token_lite_component;
