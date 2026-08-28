// Struct definitions for game components interfaces

pub mod leaderboard;
pub mod metagame;
pub mod minigame;
pub mod token;
pub use leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig,
};

// Re-export commonly used structs at top level
pub use metagame::{GameContext, GameContextDetails};
pub use minigame::{
    GameDetail, GameObjective, GameObjectiveDetails, GameSetting, GameSettingDetails,
};
pub use token::{GameFeeTerms, Lifecycle, MintBatchRecipient, TokenMetadata};
