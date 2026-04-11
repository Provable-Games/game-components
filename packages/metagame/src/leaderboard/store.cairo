// SPDX-License-Identifier: BUSL-1.1

use game_components_metagame::leaderboard::structs::Leaderboard;

/// Generic store trait for leaderboard operations
pub trait Store<T> {
    fn get_leaderboard(self: @T, context_id: u64) -> Span<felt252>;
    fn set_leaderboard(ref self: T, leaderboard: @Leaderboard);

    // Direct storage accessors for optimized insertion
    fn get_count(self: @T, context_id: u64) -> u32;
    fn set_count(ref self: T, context_id: u64, count: u32);
    fn get_entry_at(self: @T, context_id: u64, position: u32) -> felt252;
    fn set_entry_at(ref self: T, context_id: u64, position: u32, token_id: felt252);
    fn get_score_at(self: @T, context_id: u64, position: u32) -> u64;
    fn set_score_at(ref self: T, context_id: u64, position: u32, score: u64);
    fn get_token_position(self: @T, context_id: u64, token_id: felt252) -> u32;
    fn set_token_position(ref self: T, context_id: u64, token_id: felt252, position: u32);
}
