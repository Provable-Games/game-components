// SPDX-License-Identifier: BUSL-1.1

use game_components_leaderboard::models::Leaderboard;

/// Generic store trait for leaderboard operations
pub trait Store<T> {
    fn get_leaderboard(self: @T, tournament_id: u64) -> Span<u64>;
    fn set_leaderboard(ref self: T, leaderboard: @Leaderboard);
}