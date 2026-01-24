// SPDX-License-Identifier: BUSL-1.1

// Re-export all leaderboard interfaces and types from the interfaces package
// This file provides backward compatibility for existing code that imports from this module

pub use game_components_interfaces::leaderboard::{
    // Interface ID
    ILEADERBOARD_ID, // IGameDetails trait and dispatchers
    IGameDetails, IGameDetailsDispatcher,
    IGameDetailsDispatcherTrait, // ILeaderboard trait and dispatchers
    ILeaderboard, ILeaderboardDispatcher,
    ILeaderboardDispatcherTrait, // ILeaderboardAdmin trait and dispatchers
    ILeaderboardAdmin,
    ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait, // Struct types
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig,
};
