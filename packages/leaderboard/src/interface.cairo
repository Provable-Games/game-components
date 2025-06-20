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

#[starknet::interface]
pub trait ILeaderboard<TState> {
    /// Initialize the leaderboard with configuration
    fn initialize(
        ref self: TState,
        owner: ContractAddress,
        tournament_id: u64,
        max_entries: u8,
        ascending: bool,
        game_address: ContractAddress
    );
    
    /// Submit a score to the leaderboard
    fn submit_score(
        ref self: TState,
        token_id: u64,
        score: u32,
        position: u8
    ) -> LeaderboardResult;
    
    /// Get all leaderboard entries with scores
    fn get_entries(self: @TState) -> Array<LeaderboardEntry>;
    
    /// Get top N entries
    fn get_top_entries(self: @TState, count: u32) -> Array<LeaderboardEntry>;
    
    /// Get the position of a specific token
    fn get_position(self: @TState, token_id: u64) -> Option<u8>;
    
    /// Check if a score qualifies for the leaderboard
    fn qualifies(self: @TState, score: u32) -> bool;
    
    /// Check if the leaderboard is full
    fn is_full(self: @TState) -> bool;
    
    /// Get leaderboard configuration
    fn get_config(self: @TState) -> LeaderboardStoreConfig;
    
    /// Get tournament ID
    fn tournament_id(self: @TState) -> u64;
}

#[starknet::interface]
pub trait ILeaderboardAdmin<TState> {
    /// Update the leaderboard configuration (admin only)
    fn update_config(
        ref self: TState,
        max_entries: u8,
        ascending: bool,
        game_address: ContractAddress
    );
    
    /// Clear the leaderboard (admin only)
    fn clear_leaderboard(ref self: TState);
    
    /// Get the admin/owner address
    fn owner(self: @TState) -> ContractAddress;
    
    /// Transfer ownership
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
}