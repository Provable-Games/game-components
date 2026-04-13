// SPDX-License-Identifier: BUSL-1.1

// Import types and interfaces from interfaces package
// Re-export LeaderboardStoreConfig for backward compatibility
/// Leaderboard Store Helper Module
/// This module provides helper functions to integrate the pure leaderboard library with store
/// operations.

use core::num::traits::Zero;
pub use game_components_interfaces::leaderboard::{
    IGameDetailsDispatcher, IGameDetailsDispatcherTrait, LeaderboardEntry, LeaderboardResult,
    LeaderboardStoreConfig,
};
use game_components_metagame::leaderboard::leaderboard::leaderboard;
use game_components_metagame::leaderboard::leaderboard::leaderboard::wins_tiebreak;
use game_components_metagame::leaderboard::store::Store;
use starknet::ContractAddress;

/// Main trait for leaderboard store operations
pub trait LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores
    fn get_entries(
        self: @T, context_id: u64, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry>;

    /// Submit a score at a specific position (1-based). O(1) — overwrites displaced entry.
    fn submit_score(
        ref self: T,
        context_id: u64,
        token_id: felt252,
        score: u64,
        position: u32,
        config: LeaderboardStoreConfig,
    ) -> LeaderboardResult;

    /// Get the position of an entry (1-based). O(1).
    fn get_position(self: @T, context_id: u64, token_id: felt252) -> Option<u32>;

    /// Check if a score qualifies for the leaderboard. O(1).
    fn qualifies(self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig) -> bool;
}

/// Implementation of LeaderboardStoreTrait
/// Uses direct storage access for O(1) insertion — overwrites displaced entry, no shifting.
pub impl LeaderboardStoreImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores from stored data
    fn get_entries(
        self: @T, context_id: u64, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry> {
        let count = self.get_count(context_id);
        let mut entries = ArrayTrait::new();
        let mut i = 0_u32;

        loop {
            if i >= count {
                break;
            }
            let token_id = self.get_entry_at(context_id, i);
            let score = if !game_address.is_zero() {
                get_score_for_token(game_address, token_id)
            } else {
                self.get_score_at(context_id, i)
            };
            entries.append(LeaderboardEntry { id: token_id, score });
            i += 1;
        }

        entries
    }

    /// Submit a score to the leaderboard at a specific position.
    /// O(1) — validates against neighbors, overwrites the position, evicts displaced entry.
    /// Position is 1-based (1 = first place).
    fn submit_score(
        ref self: T,
        context_id: u64,
        token_id: felt252,
        score: u64,
        position: u32,
        config: LeaderboardStoreConfig,
    ) -> LeaderboardResult {
        // Convert 1-based position to 0-based index
        let index = match leaderboard::position_to_index(position) {
            Option::Some(idx) => idx,
            Option::None => { return LeaderboardResult::InvalidPosition; },
        };

        let count = self.get_count(context_id);
        let is_duplicate = self.get_token_position(context_id, token_id) != 0;

        // Read neighbor data for pure validation
        let (score_at_index, token_at_index) = if index < count {
            (self.get_score_at(context_id, index), self.get_entry_at(context_id, index))
        } else {
            (0_u64, 0)
        };
        let (score_above, token_above) = if index > 0 {
            (self.get_score_at(context_id, index - 1), self.get_entry_at(context_id, index - 1))
        } else {
            (0_u64, 0)
        };

        // Pure validation — no storage access
        let result = leaderboard::validate_insertion(
            index,
            count,
            config.max_entries,
            config.ascending,
            score,
            token_id,
            is_duplicate,
            score_at_index,
            token_at_index,
            score_above,
            token_above,
        );
        match result {
            LeaderboardResult::Success => {},
            _ => { return result; },
        }

        // Evict displaced entry or increment count for append
        if index < count {
            // Overwriting existing position — evict the displaced entry
            let evicted_token = self.get_entry_at(context_id, index);
            self.set_token_position(context_id, evicted_token, 0);
        } else {
            // Appending to end — increment count
            self.set_count(context_id, count + 1);
        }

        // Write new entry at index
        self.set_entry_at(context_id, index, token_id);
        self.set_score_at(context_id, index, score);
        self.set_token_position(context_id, token_id, index + 1);

        LeaderboardResult::Success
    }

    /// Get the position of an entry in the leaderboard (1-based).
    /// O(1) via token_positions map.
    fn get_position(self: @T, context_id: u64, token_id: felt252) -> Option<u32> {
        let stored = self.get_token_position(context_id, token_id);
        if stored == 0 {
            Option::None
        } else {
            Option::Some(stored) // already 1-based
        }
    }

    /// Check if a score qualifies for the leaderboard
    fn qualifies(self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig) -> bool {
        let count = self.get_count(context_id);
        let last_score = if count > 0 {
            self.get_score_at(context_id, count - 1)
        } else {
            0
        };
        leaderboard::qualifies(score, last_score, count, config.max_entries, config.ascending)
    }
}

/// Additional helper functions for leaderboard operations
pub trait LeaderboardStoreHelpersTrait<T> {
    /// Check if the leaderboard is full — O(1)
    fn is_full(self: @T, context_id: u64, max_entries: u32) -> bool;

    /// Get the minimum qualifying score — O(1)
    fn get_minimum_qualifying_score(
        self: @T, context_id: u64, config: LeaderboardStoreConfig,
    ) -> Option<u64>;

    /// Get a range of leaderboard entries (for pagination)
    fn get_range(
        self: @T, context_id: u64, start: u32, count: u32, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry>;

    /// Find the position where a score would be inserted (1-based) — O(log n) view function
    /// Accounts for token_id tiebreaking so the returned position is always valid for
    /// submit_score without further adjustment.
    fn find_position(
        self: @T, context_id: u64, score: u64, token_id: felt252, config: LeaderboardStoreConfig,
    ) -> Option<u32>;
}

/// Implementation of additional helper functions
pub impl LeaderboardStoreHelpersImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreHelpersTrait<T> {
    /// Check if the leaderboard is full — O(1)
    fn is_full(self: @T, context_id: u64, max_entries: u32) -> bool {
        self.get_count(context_id) >= max_entries
    }

    /// Get the minimum qualifying score — O(1), reads last entry's score
    fn get_minimum_qualifying_score(
        self: @T, context_id: u64, config: LeaderboardStoreConfig,
    ) -> Option<u64> {
        if config.max_entries == 0 {
            return Option::None;
        }
        let count = self.get_count(context_id);
        if count < config.max_entries {
            Option::None // Not full — any score qualifies
        } else {
            Option::Some(self.get_score_at(context_id, count - 1))
        }
    }

    /// Get a range of leaderboard entries — reads only the requested range
    fn get_range(
        self: @T, context_id: u64, start: u32, count: u32, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry> {
        let total = self.get_count(context_id);
        let end = if start + count < total {
            start + count
        } else {
            total
        };
        let mut entries = ArrayTrait::new();
        let mut i = start;
        while i < end {
            let token_id = self.get_entry_at(context_id, i);
            let score = if !game_address.is_zero() {
                get_score_for_token(game_address, token_id)
            } else {
                self.get_score_at(context_id, i)
            };
            entries.append(LeaderboardEntry { id: token_id, score });
            i += 1;
        }
        entries
    }

    /// Find the position where a score would be inserted — O(log n) binary search
    /// Uses token_id for deterministic tiebreaking on equal scores (lower token_id wins).
    fn find_position(
        self: @T, context_id: u64, score: u64, token_id: felt252, config: LeaderboardStoreConfig,
    ) -> Option<u32> {
        let count = self.get_count(context_id);
        let mut lo: u32 = 0;
        let mut hi: u32 = count;

        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            let mid_score = self.get_score_at(context_id, mid);
            let go_left = if score == mid_score {
                let mid_token = self.get_entry_at(context_id, mid);
                wins_tiebreak(token_id, mid_token)
            } else if config.ascending {
                score < mid_score
            } else {
                score > mid_score
            };
            if go_left {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }

        Option::Some(lo + 1) // convert to 1-based position
    }
}

/// Internal helper functions
/// Get score for a token from the game contract
fn get_score_for_token(game_address: ContractAddress, token_id: felt252) -> u64 {
    let game_dispatcher = IGameDetailsDispatcher { contract_address: game_address };
    game_dispatcher.score(token_id)
}
