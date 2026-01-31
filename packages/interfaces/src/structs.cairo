// Struct definitions for game components interfaces

pub mod leaderboard;
pub mod metagame;
pub mod minigame;
pub mod registry;
pub mod token;
pub use leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig,
};

// Re-export commonly used structs at top level
pub use metagame::{GameContext, GameContextDetails};
pub use minigame::{GameDetail, GameObjective, GameSetting, GameSettingDetails, MintGameParams};
pub use registry::GameMetadata;
pub use token::{Lifecycle, MintParams, PlayerNameUpdate, TokenMetadata};
