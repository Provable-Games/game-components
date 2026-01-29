// Leaderboard structs
use starknet::ContractAddress;

/// Configuration for leaderboard behavior
#[derive(Drop, Serde, Copy)]
pub struct LeaderboardConfig {
    /// Maximum number of entries allowed
    pub max_entries: u32,
    /// Whether lower scores are better (true) or higher scores are better (false)
    pub ascending: bool,
    /// Whether to allow ties (same score, different entries)
    pub allow_ties: bool,
}

/// Entry in the leaderboard
#[derive(Drop, Serde, Copy)]
pub struct LeaderboardEntry {
    /// Unique identifier for the entry
    pub id: u64,
    /// Score value
    pub score: u64,
}

/// Result of a leaderboard operation
#[derive(Drop, Serde, Copy)]
pub enum LeaderboardResult {
    Success: (),
    InvalidPosition: (),
    LeaderboardFull: (),
    ScoreTooLow: (),
    ScoreTooHigh: (),
    DuplicateEntry: (),
    InvalidConfig: (),
}

/// Configuration for leaderboard store operations
#[derive(Drop, Serde, Copy)]
pub struct LeaderboardStoreConfig {
    /// Maximum number of entries allowed
    pub max_entries: u32,
    /// Whether lower scores are better (true) or higher scores are better (false)
    pub ascending: bool,
    /// Game contract address for score retrieval
    pub game_address: ContractAddress,
}
