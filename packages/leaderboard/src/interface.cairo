// SPDX-License-Identifier: BUSL-1.1

use starknet::ContractAddress;
use crate::leaderboard::leaderboard::{LeaderboardEntry, LeaderboardResult};
use crate::leaderboard_store::LeaderboardStoreConfig;

pub const ILEADERBOARD_ID: felt252 =
    0x03c0f9265d397c10970f24822e4b57cac7d8895f8c449b7c9caaa26910499705;

#[starknet::interface]
pub trait IGameDetails<TState> {
    fn score(self: @TState, token_id: u64) -> u32;
}

/// Multi-tournament leaderboard interface
/// Supports managing leaderboards for multiple tournaments
#[starknet::interface]
pub trait ILeaderboard<TState> {
    /// Submit a score to a tournament's leaderboard
    fn submit_score(
        ref self: TState, tournament_id: u64, token_id: u64, score: u32, position: u8,
    ) -> LeaderboardResult;

    /// Get all leaderboard entries with scores for a tournament
    fn get_entries(self: @TState, tournament_id: u64) -> Array<LeaderboardEntry>;

    /// Get top N entries for a tournament
    fn get_top_entries(self: @TState, tournament_id: u64, count: u32) -> Array<LeaderboardEntry>;

    /// Get the position of a specific token in a tournament
    fn get_position(self: @TState, tournament_id: u64, token_id: u64) -> Option<u8>;

    /// Check if a score qualifies for a tournament's leaderboard
    fn qualifies(self: @TState, tournament_id: u64, score: u32) -> bool;

    /// Check if a tournament's leaderboard is full
    fn is_full(self: @TState, tournament_id: u64) -> bool;

    /// Get the number of entries in a tournament's leaderboard
    fn get_leaderboard_length(self: @TState, tournament_id: u64) -> u32;

    /// Get the configuration for a tournament's leaderboard
    fn get_tournament_config(self: @TState, tournament_id: u64) -> LeaderboardStoreConfig;
}

#[starknet::interface]
pub trait ILeaderboardAdmin<TState> {
    /// Configure a tournament's leaderboard settings (admin only)
    fn configure_tournament(
        ref self: TState,
        tournament_id: u64,
        max_entries: u32,
        ascending: bool,
        game_address: ContractAddress,
    );

    /// Clear a tournament's leaderboard (admin only)
    fn clear_leaderboard(ref self: TState, tournament_id: u64);

    /// Get the admin/owner address
    fn owner(self: @TState) -> ContractAddress;

    /// Transfer ownership
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
}
