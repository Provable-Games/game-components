pub mod interface;
pub mod lifecycle;
pub mod minigame_token_component;
pub mod packing;

// The deployable merged game+token mock (StandardGameMock) lives in the
// test_common package so downstream consumers can declare it via
// build-external-contracts.
#[cfg(test)]
mod tests;
