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
use game_components_metagame::leaderboard::store::Store;
use starknet::ContractAddress;

/// Main trait for leaderboard store operations
pub trait LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores
    fn get_leaderboard_entries(
        self: @T, context_id: u64, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry>;

    /// Submit a score to the leaderboard at a specific position
    fn submit_score_to_leaderboard(
        ref self: T,
        context_id: u64,
        token_id: felt252,
        score: u64,
        position: u32,
        config: LeaderboardStoreConfig,
    ) -> LeaderboardResult;

    /// Submit a score, automatically finding the correct position
    fn submit_score_auto(
        ref self: T, context_id: u64, token_id: felt252, score: u64, config: LeaderboardStoreConfig,
    ) -> (LeaderboardResult, u32);

    /// Get the position of an entry in the leaderboard (1-based)
    fn get_entry_position(self: @T, context_id: u64, token_id: felt252) -> Option<u32>;

    /// Check if a score qualifies for the leaderboard
    fn qualifies_for_leaderboard(
        self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig,
    ) -> bool;
}

/// Implementation of LeaderboardStoreTrait
/// Uses direct storage access for O(k) insertion instead of loading the full array.
pub impl LeaderboardStoreImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreTrait<T> {
    /// Get leaderboard entries with scores from stored data
    fn get_leaderboard_entries(
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
    /// Operates directly on storage — only shifts entries that need moving.
    /// Position is 1-based (1 = first place).
    fn submit_score_to_leaderboard(
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

        // Determine new count (cap at max_entries, evicting last if needed)
        let new_count = if count < config.max_entries {
            count + 1
        } else {
            config.max_entries
        };

        // If at max and evicting, clear the last entry's token_position
        if count >= config.max_entries {
            let evicted_token = self.get_entry_at(context_id, count - 1);
            self.set_token_position(context_id, evicted_token, 0);
        }

        // Shift entries from index to end, one position forward (backwards to avoid overwrite)
        let shift_end = if count < config.max_entries {
            count
        } else {
            config.max_entries - 1
        };
        let mut i = shift_end;
        while i > index {
            let prev_token = self.get_entry_at(context_id, i - 1);
            let prev_score = self.get_score_at(context_id, i - 1);
            self.set_entry_at(context_id, i, prev_token);
            self.set_score_at(context_id, i, prev_score);
            self.set_token_position(context_id, prev_token, i + 1);
            i -= 1;
        }

        // Write new entry at index
        self.set_entry_at(context_id, index, token_id);
        self.set_score_at(context_id, index, score);
        self.set_token_position(context_id, token_id, index + 1);

        // Update count
        self.set_count(context_id, new_count);

        LeaderboardResult::Success
    }

    /// Submit a score, automatically finding the correct position.
    /// Uses binary search on stored scores for O(log n) position finding.
    fn submit_score_auto(
        ref self: T, context_id: u64, token_id: felt252, score: u64, config: LeaderboardStoreConfig,
    ) -> (LeaderboardResult, u32) {
        let count = self.get_count(context_id);

        // Binary search for leftmost position with this score
        let mut lo: u32 = 0;
        let mut hi: u32 = count;

        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            let mid_score = self.get_score_at(context_id, mid);

            let go_left = if config.ascending {
                score <= mid_score
            } else {
                score >= mid_score
            };

            if go_left {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }

        // Scan forward through equal-score entries for tie-break position
        // (lower token_id wins — should be placed before higher token_ids)
        while lo < count {
            let entry_score = self.get_score_at(context_id, lo);
            if entry_score != score {
                break;
            }
            let entry_token = self.get_entry_at(context_id, lo);
            if leaderboard::wins_tiebreak(token_id, entry_token) {
                break;
            }
            lo += 1;
        }

        // Convert 0-based index to 1-based position
        let position = lo + 1;
        let result = self
            .submit_score_to_leaderboard(context_id, token_id, score, position, config);
        (result, position)
    }

    /// Get the position of an entry in the leaderboard (1-based).
    /// O(1) via token_positions map.
    fn get_entry_position(self: @T, context_id: u64, token_id: felt252) -> Option<u32> {
        let stored = self.get_token_position(context_id, token_id);
        if stored == 0 {
            Option::None
        } else {
            Option::Some(stored) // already 1-based
        }
    }

    /// Check if a score qualifies for the leaderboard
    fn qualifies_for_leaderboard(
        self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig,
    ) -> bool {
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
    /// Get top N winners from the leaderboard
    fn get_top_winners(self: @T, context_id: u64, count: u32) -> Array<felt252>;

    /// Check if the leaderboard is full
    fn is_leaderboard_full(self: @T, context_id: u64, max_entries: u32) -> bool;

    /// Get the minimum qualifying score for the leaderboard
    fn get_minimum_qualifying_score(
        self: @T, context_id: u64, config: LeaderboardStoreConfig,
    ) -> Option<u64>;

    /// Get a range of leaderboard entries (for pagination)
    fn get_leaderboard_range(
        self: @T, context_id: u64, start: u32, count: u32, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry>;

    /// Find the position where a score would be inserted
    fn find_score_position(
        self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig,
    ) -> Option<u32>;
}

/// Implementation of additional helper functions
pub impl LeaderboardStoreHelpersImpl<T, +Store<T>, +Drop<T>> of LeaderboardStoreHelpersTrait<T> {
    /// Get top N winners from the leaderboard (reads only N entries, not all)
    fn get_top_winners(self: @T, context_id: u64, count: u32) -> Array<felt252> {
        let total = self.get_count(context_id);
        let limit = if count < total {
            count
        } else {
            total
        };
        let mut result = ArrayTrait::new();
        let mut i = 0_u32;

        while i < limit {
            result.append(self.get_entry_at(context_id, i));
            i += 1;
        }

        result
    }

    /// Check if the leaderboard is full — O(1)
    fn is_leaderboard_full(self: @T, context_id: u64, max_entries: u32) -> bool {
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
    fn get_leaderboard_range(
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
    fn find_score_position(
        self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig,
    ) -> Option<u32> {
        let count = self.get_count(context_id);
        let mut lo: u32 = 0;
        let mut hi: u32 = count;

        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            let mid_score = self.get_score_at(context_id, mid);
            let go_left = if config.ascending {
                score <= mid_score
            } else {
                score >= mid_score
            };
            if go_left {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }

        Option::Some(lo)
    }
}

/// Internal helper functions
/// Get score for a token from the game contract
fn get_score_for_token(game_address: ContractAddress, token_id: felt252) -> u64 {
    let game_dispatcher = IGameDetailsDispatcher { contract_address: game_address };
    game_dispatcher.score(token_id)
}
