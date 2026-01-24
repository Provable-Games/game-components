// Leaderboard struct re-exports
// Note: Interface traits remain in game_components_leaderboard::interface
// because they use internal struct types from the pure leaderboard library

pub use crate::structs::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig,
};

// Interface ID constant
pub const ILEADERBOARD_ID: felt252 =
    0x03c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499705;
