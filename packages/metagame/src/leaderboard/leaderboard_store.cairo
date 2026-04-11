// SPDX-License-Identifier: BUSL-1.1

// Import types and interfaces from interfaces package
// Re-export LeaderboardStoreConfig for backward compatibility
/// Leaderboard Store Helper Module
/// This module provides helper functions to integrate the pure leaderboard library with store
/// operations.

use core::num::traits::Zero;
pub use game_components_interfaces::leaderboard::{
    IGameDetailsDispatcher, IGameDetailsDispatcherTrait, LeaderboardConfig, LeaderboardEntry,
    LeaderboardResult, LeaderboardStoreConfig,
};
use game_components_metagame::leaderboard::leaderboard::leaderboard::{
    LeaderboardOperationsImpl, LeaderboardUtilsImpl,
};
use game_components_metagame::leaderboard::store::Store;
use game_components_metagame::leaderboard::structs::Leaderboard;
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
        let index = match LeaderboardUtilsImpl::position_to_index(position) {
            Option::Some(idx) => idx,
            Option::None => { return LeaderboardResult::InvalidPosition; },
        };

        let count = self.get_count(context_id);

        // Duplicate check — O(1) via token_positions map
        if self.get_token_position(context_id, token_id) != 0 {
            return LeaderboardResult::DuplicateEntry;
        }

        // Position bounds check
        if index > count {
            return LeaderboardResult::InvalidPosition;
        }

        // Check if leaderboard is full and insertion would be beyond max
        if count >= config.max_entries && index >= config.max_entries {
            return LeaderboardResult::LeaderboardFull;
        }

        // Validate score against neighbor at position (entry being displaced)
        if index < count {
            let score_at_pos = self.get_score_at(context_id, index);
            if config.ascending {
                if score > score_at_pos {
                    return LeaderboardResult::ScoreTooLow;
                }
                // Tie-break: equal score — lower token ID wins
                if score == score_at_pos {
                    let existing_id: u256 = self.get_entry_at(context_id, index).into();
                    let new_id: u256 = token_id.into();
                    if new_id >= existing_id {
                        return LeaderboardResult::ScoreTooLow;
                    }
                }
            } else {
                if score < score_at_pos {
                    return LeaderboardResult::ScoreTooLow;
                }
                if score == score_at_pos {
                    let existing_id: u256 = self.get_entry_at(context_id, index).into();
                    let new_id: u256 = token_id.into();
                    if new_id >= existing_id {
                        return LeaderboardResult::ScoreTooLow;
                    }
                }
            }
        }

        // Validate score against entry above (if exists)
        if index > 0 {
            let score_above = self.get_score_at(context_id, index - 1);
            if config.ascending {
                if score < score_above {
                    return LeaderboardResult::ScoreTooHigh;
                }
                // Tie-break: equal score — lower token ID should be above
                if score == score_above {
                    let above_id: u256 = self.get_entry_at(context_id, index - 1).into();
                    let new_id: u256 = token_id.into();
                    if new_id < above_id {
                        return LeaderboardResult::ScoreTooHigh;
                    }
                }
            } else {
                if score > score_above {
                    return LeaderboardResult::ScoreTooHigh;
                }
                if score == score_above {
                    let above_id: u256 = self.get_entry_at(context_id, index - 1).into();
                    let new_id: u256 = token_id.into();
                    if new_id < above_id {
                        return LeaderboardResult::ScoreTooHigh;
                    }
                }
            }
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
            // Update shifted entry's token_position (stored as position+1)
            self.set_token_position(context_id, prev_token, i + 1);
            i -= 1;
        }

        // Write new entry at index
        self.set_entry_at(context_id, index, token_id);
        self.set_score_at(context_id, index, score);
        self.set_token_position(context_id, token_id, index + 1); // 1-indexed

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

        // Binary search for insert position on stored scores
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
        if count < config.max_entries {
            return true; // Not full — any score qualifies
        }
        // Full — check against last entry's score
        let last_score = self.get_score_at(context_id, count - 1);
        if config.ascending {
            score < last_score
        } else {
            score > last_score
        }
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

    /// Get the minimum qualifying score for the leaderboard
    fn get_minimum_qualifying_score(
        self: @T, context_id: u64, config: LeaderboardStoreConfig,
    ) -> Option<u64> {
        let entries = self.get_leaderboard_entries(context_id, config.game_address);
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries, ascending: config.ascending, allow_ties: true,
        };

        LeaderboardUtilsImpl::get_qualifying_score(@lb_config, @entries)
    }

    /// Get a range of leaderboard entries (for pagination)
    fn get_leaderboard_range(
        self: @T, context_id: u64, start: u32, count: u32, game_address: ContractAddress,
    ) -> Array<LeaderboardEntry> {
        let entries = self.get_leaderboard_entries(context_id, game_address);
        LeaderboardUtilsImpl::get_range(@entries, start, count)
    }

    /// Find the position where a score would be inserted
    fn find_score_position(
        self: @T, context_id: u64, score: u64, config: LeaderboardStoreConfig,
    ) -> Option<u32> {
        let entries = self.get_leaderboard_entries(context_id, config.game_address);
        let lb_config = LeaderboardConfig {
            max_entries: config.max_entries, ascending: config.ascending, allow_ties: true,
        };

        // Create a temporary entry to find position
        let temp_entry = LeaderboardEntry { id: 0, score };

        LeaderboardOperationsImpl::find_insert_position(@lb_config, @entries, @temp_entry)
    }
}

/// Internal helper functions
/// Get score for a token from the game contract
fn get_score_for_token(game_address: ContractAddress, token_id: felt252) -> u64 {
    let game_dispatcher = IGameDetailsDispatcher { contract_address: game_address };
    game_dispatcher.score(token_id)
}
