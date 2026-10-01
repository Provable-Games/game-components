// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for leaderboard logic.
/// All functions are stateless — they take inputs and return results.
/// Storage interaction is handled by the store layer (leaderboard_store.cairo).
pub mod leaderboard {
    pub use game_components_interfaces::leaderboard::{LeaderboardConfig, LeaderboardResult};

    /// Check if score_a is strictly better than score_b.
    /// Ascending: lower is better. Descending: higher is better.
    pub fn is_better_score(score_a: u64, score_b: u64, ascending: bool) -> bool {
        if ascending {
            score_a < score_b
        } else {
            score_a > score_b
        }
    }

    /// Schema-1 game-token stores its mint block in low-half bits 32..63.
    fn unpack_mint_block(token_id: felt252) -> u64 {
        let packed: u256 = token_id.into();
        ((packed.low / 0x100000000) & 0xffffffff).try_into().unwrap()
    }

    /// Equal scores prefer the earlier mint block, then the lower token ID.
    /// Token IDs must use the schema-1 game-token layout.
    pub fn wins_tiebreak(token_a: felt252, token_b: felt252) -> bool {
        let block_a = unpack_mint_block(token_a);
        let block_b = unpack_mint_block(token_b);
        if block_a != block_b {
            block_a < block_b
        } else {
            // Same mint block — fall back to lower token ID for determinism
            let a: u256 = token_a.into();
            let b: u256 = token_b.into();
            a < b
        }
    }

    /// Convert 1-based position to 0-based index. Returns None for position 0.
    pub fn position_to_index(position: u32) -> Option<u32> {
        if position == 0 {
            Option::None
        } else {
            Option::Some(position - 1)
        }
    }

    /// Validate that a new entry can be inserted at the given index.
    /// Pure function — takes pre-read values, no storage access.
    ///
    /// Parameters:
    /// - index: 0-based insertion point
    /// - count: current number of entries
    /// - max_entries: configured maximum
    /// - ascending: sort order
    /// - score: new entry's score
    /// - token_id: new entry's token ID
    /// - is_duplicate: whether this token_id is already on the leaderboard
    /// - score_at_index: score of the entry currently at `index` (if index < count)
    /// - token_at_index: token_id of the entry currently at `index` (if index < count)
    /// - score_above: score of the entry at `index - 1` (if index > 0)
    /// - token_above: token_id of the entry at `index - 1` (if index > 0)
    pub fn validate_insertion(
        index: u32,
        count: u32,
        max_entries: u32,
        ascending: bool,
        score: u64,
        token_id: felt252,
        is_duplicate: bool,
        score_at_index: u64,
        token_at_index: felt252,
        score_above: u64,
        token_above: felt252,
    ) -> LeaderboardResult {
        // Duplicate check
        if is_duplicate {
            return LeaderboardResult::DuplicateEntry;
        }

        // Position bounds: can append (index == count) or overwrite (index < count)
        if index > count {
            return LeaderboardResult::InvalidPosition;
        }

        // Full leaderboard — can only overwrite existing positions, not append
        if count >= max_entries && index >= count {
            return LeaderboardResult::LeaderboardFull;
        }

        // Validate against entry at insertion point (being displaced)
        if index < count {
            if is_better_score(score_at_index, score, ascending) {
                return LeaderboardResult::ScoreTooLow;
            }
            // Equal score — tie-break by mint block, then token ID
            if score == score_at_index && !wins_tiebreak(token_id, token_at_index) {
                return LeaderboardResult::ScoreTooLow;
            }
        }

        // Validate against entry above (must not be better than it)
        if index > 0 {
            if is_better_score(score, score_above, ascending) {
                return LeaderboardResult::ScoreTooHigh;
            }
            // Equal score above — must lose tie-break (i.e., entry above should stay above)
            if score == score_above && wins_tiebreak(token_id, token_above) {
                return LeaderboardResult::ScoreTooHigh;
            }
        }

        LeaderboardResult::Success
    }

    /// Check if a score qualifies for a leaderboard.
    /// Pure function — takes pre-read values.
    pub fn qualifies(
        score: u64, last_score: u64, count: u32, max_entries: u32, ascending: bool,
    ) -> bool {
        if max_entries == 0 {
            return false;
        }
        if count < max_entries {
            return true;
        }
        is_better_score(score, last_score, ascending)
    }
}
