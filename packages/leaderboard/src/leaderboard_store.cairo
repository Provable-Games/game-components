// SPDX-License-Identifier: BUSL-1.1

/// Leaderboard Store Helper Module
/// This module provides helper functions to integrate the pure leaderboard library with Dojo's
/// store. It replaces the component approach with direct store operations

use starknet::ContractAddress;

use game_components_leaderboard::leaderboard::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardOperationsImpl,
    LeaderboardUtilsImpl,
};
use game_components_leaderboard::models::{Leaderboard};
use game_components_leaderboard::store::{Store};
use game_components_leaderboard::interface::{IGameDetailsDispatcher, IGameDetailsDispatcherTrait};

/// Configuration for leaderboard behavior
#[derive(Drop, Serde, Copy)]
pub struct LeaderboardStoreConfig {
    /// Maximum number of entries allowed
    pub max_entries: u8,
    /// Whether lower scores are better (true) or higher scores are better (false)
    pub ascending: bool,
    /// Game contract address for score retrieval
    pub game_address: ContractAddress,
}

/// Main trait for leaderboard store operations
pub trait LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores
    fn get_leaderboard_entries(
        self: @T, tournament_id: u64, game_address: ContractAddress
    ) -> Array<LeaderboardEntry>;

    /// Submit a score to the leaderboard
    fn submit_score_to_leaderboard(
        ref self: T,
        tournament_id: u64,
        token_id: u64,
        score: u32,
        position: u8,
        config: LeaderboardStoreConfig
    ) -> LeaderboardResult;

    /// Get the position of an entry in the leaderboard (1-based)
    fn get_entry_position(self: @T, tournament_id: u64, token_id: u64) -> Option<u8>;

    /// Check if a score qualifies for the leaderboard
    fn qualifies_for_leaderboard(
        self: @T, tournament_id: u64, score: u32, config: LeaderboardStoreConfig
    ) -> bool;
}

/// Implementation of LeaderboardStoreTrait
pub impl LeaderboardStoreImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores
    fn get_leaderboard_entries(
        self: @T, tournament_id: u64, game_address: ContractAddress
    ) -> Array<LeaderboardEntry> {
        let token_ids = self.get_leaderboard(tournament_id);

        // Convert token IDs to LeaderboardEntry structs
        let mut entries = ArrayTrait::new();
        let mut i = 0_u32;

        loop {
            if i >= token_ids.len() {
                break;
            }

            let token_id = *token_ids.at(i);
            let score = get_score_for_token(game_address, token_id);
            entries.append(LeaderboardEntry { id: token_id, score });
            i += 1;
        };

        entries
    }

    /// Submit a score to the leaderboard
    fn submit_score_to_leaderboard(
        ref self: T,
        tournament_id: u64,
        token_id: u64,
        score: u32,
        position: u8,
        config: LeaderboardStoreConfig
    ) -> LeaderboardResult {
        // Get current leaderboard entries
        let current_entries = self.get_leaderboard_entries(tournament_id, config.game_address);
        
        // Create leaderboard config
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries,
            ascending: config.ascending,
            allow_ties: true,
        };

        // Create new entry
        let new_entry = LeaderboardEntry { id: token_id, score };

        // Convert 1-based position to 0-based index
        let position_index = match LeaderboardUtilsImpl::position_to_index(position) {
            Option::Some(idx) => idx,
            Option::None => { return LeaderboardResult::InvalidPosition; },
        };

        // Validate and insert
        let (updated_entries, result) = LeaderboardOperationsImpl::insert_entry(
            @lb_config, @current_entries, @new_entry, position_index,
        );

        match result {
            LeaderboardResult::Success => {
                // Convert back to token IDs array for storage
                let mut token_ids = ArrayTrait::new();
                let mut i = 0_u32;
                loop {
                    if i >= updated_entries.len() {
                        break;
                    }
                    token_ids.append(*updated_entries.at(i).id);
                    i += 1;
                };

                // Save updated leaderboard
                self.set_leaderboard(@Leaderboard { tournament_id, token_ids });

                LeaderboardResult::Success
            },
            _ => result,
        }
    }

    /// Get the position of an entry in the leaderboard (1-based)
    fn get_entry_position(self: @T, tournament_id: u64, token_id: u64) -> Option<u8> {
        let token_ids = self.get_leaderboard(tournament_id);
        
        let mut i = 0_u32;
        loop {
            if i >= token_ids.len() {
                break Option::None;
            }
            if *token_ids.at(i) == token_id {
                break LeaderboardUtilsImpl::index_to_position(i);
            }
            i += 1;
        }
    }

    /// Check if a score qualifies for the leaderboard
    fn qualifies_for_leaderboard(
        self: @T, tournament_id: u64, score: u32, config: LeaderboardStoreConfig
    ) -> bool {
        let entries = self.get_leaderboard_entries(tournament_id, config.game_address);
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries,
            ascending: config.ascending,
            allow_ties: true,
        };

        LeaderboardOperationsImpl::qualifies_for_leaderboard(@lb_config, @entries, score)
    }
}

/// Additional helper functions for leaderboard operations
pub trait LeaderboardStoreHelpersTrait<T> {
    /// Get top N winners from the leaderboard
    fn get_top_winners(self: @T, tournament_id: u64, count: u32) -> Array<u64>;

    /// Check if the leaderboard is full
    fn is_leaderboard_full(self: @T, tournament_id: u64, max_entries: u8) -> bool;

    /// Get the minimum qualifying score for the leaderboard
    fn get_minimum_qualifying_score(
        self: @T, tournament_id: u64, config: LeaderboardStoreConfig
    ) -> Option<u32>;

    /// Get a range of leaderboard entries (for pagination)
    fn get_leaderboard_range(
        self: @T,
        tournament_id: u64,
        start: u32,
        count: u32,
        game_address: ContractAddress
    ) -> Array<LeaderboardEntry>;

    /// Find the position where a score would be inserted
    fn find_score_position(
        self: @T, tournament_id: u64, score: u32, config: LeaderboardStoreConfig
    ) -> Option<u32>;
}

/// Implementation of additional helper functions
pub impl LeaderboardStoreHelpersImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreHelpersTrait<T> {
    /// Get top N winners from the leaderboard
    fn get_top_winners(self: @T, tournament_id: u64, count: u32) -> Array<u64> {
        let token_ids = self.get_leaderboard(tournament_id);
        
        // Take first N entries
        let mut result = ArrayTrait::new();
        let mut i = 0_u32;
        let limit = core::cmp::min(count, token_ids.len());
        
        loop {
            if i >= limit {
                break;
            }
            result.append(*token_ids.at(i));
            i += 1;
        };
        
        result
    }

    /// Check if the leaderboard is full
    fn is_leaderboard_full(self: @T, tournament_id: u64, max_entries: u8) -> bool {
        let token_ids = self.get_leaderboard(tournament_id);
        token_ids.len() >= max_entries.into()
    }

    /// Get the minimum qualifying score for the leaderboard
    fn get_minimum_qualifying_score(
        self: @T, tournament_id: u64, config: LeaderboardStoreConfig
    ) -> Option<u32> {
        let entries = self.get_leaderboard_entries(tournament_id, config.game_address);
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries,
            ascending: config.ascending,
            allow_ties: true,
        };

        LeaderboardUtilsImpl::get_qualifying_score(@lb_config, @entries)
    }

    /// Get a range of leaderboard entries (for pagination)
    fn get_leaderboard_range(
        self: @T,
        tournament_id: u64,
        start: u32,
        count: u32,
        game_address: ContractAddress
    ) -> Array<LeaderboardEntry> {
        let entries = self.get_leaderboard_entries(tournament_id, game_address);
        LeaderboardUtilsImpl::get_range(@entries, start, count)
    }

    /// Find the position where a score would be inserted
    fn find_score_position(
        self: @T, tournament_id: u64, score: u32, config: LeaderboardStoreConfig
    ) -> Option<u32> {
        let entries = self.get_leaderboard_entries(tournament_id, config.game_address);
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries,
            ascending: config.ascending,
            allow_ties: true,
        };

        // Create a temporary entry to find position
        let temp_entry = LeaderboardEntry { id: 0, score };

        LeaderboardOperationsImpl::find_insert_position(@lb_config, @entries, @temp_entry)
    }
}

/// Internal helper functions
/// Get score for a token from the game contract
fn get_score_for_token(game_address: ContractAddress, token_id: u64) -> u32 {
    let game_dispatcher = IGameDetailsDispatcher { contract_address: game_address };
    game_dispatcher.score(token_id)
}