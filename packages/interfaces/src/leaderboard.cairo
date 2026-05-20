// Leaderboard interfaces and types
// All leaderboard-related types and traits are defined here as single source of truth

use starknet::ContractAddress;

// Re-export struct types from structs module
pub use crate::structs::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardResult, LeaderboardStoreConfig,
};

/// SNIP-5 interface ID derived via src5_rs: XOR of extended function selectors
/// - get_leaderboard_entries, get_leaderboard_entry,
///   get_top_leaderboard_entries, get_leaderboard_length, get_position,
///   qualifies, is_full, get_config, find_position
///
/// All read-only accessors use the `get_leaderboard_*` prefix so
/// selectors don't collide with sibling component interfaces (e.g.
/// `IRegistration::get_entry`, `IRegistration::get_entry_count`) on
/// hosts that implement multiple component traits.
///
/// NOTE: `submit_score` is INTENTIONALLY NOT on the public interface.
/// Score submission requires host-side validation (phase, eligibility,
/// banning, qualification proofs, etc.) — leaving it as a public method
/// on the component would let any caller bypass that. Hosts (budokan,
/// etc.) call `LeaderboardInternalTrait::submit_score` from their own
/// validated entrypoint.
pub const ILEADERBOARD_ID: felt252 =
    0x38e08ed38655566cb7dbf84dd9e3e0005f7edb8fc245876cb0ee79aa965a829;

/// Interface for retrieving game scores
/// Implemented by game contracts to provide score data for leaderboard entries
#[starknet::interface]
pub trait IGameDetails<TState> {
    fn score(self: @TState, token_id: felt252) -> u64;
}

/// Multi-context leaderboard interface (read-only).
///
/// Score submission is intentionally NOT here — see the module docstring
/// on `ILEADERBOARD_ID`. Hosts wrap `LeaderboardInternalTrait::submit_score`
/// in their own validated entrypoint.
#[starknet::interface]
pub trait ILeaderboard<TState> {
    /// Get all leaderboard entries with scores for a context
    fn get_leaderboard_entries(self: @TState, context_id: u64) -> Array<LeaderboardEntry>;

    /// Get a single leaderboard entry by position (1-indexed). O(1) read.
    /// Reverts if `position == 0` or `position > get_leaderboard_length(context_id)`.
    /// Intended for cross-contract callers (notably extension contracts
    /// validating claims against a specific leaderboard slot) that would
    /// otherwise pay for a full `get_leaderboard_entries` array fetch to
    /// read one element.
    fn get_leaderboard_entry(self: @TState, context_id: u64, position: u32) -> LeaderboardEntry;

    /// Get top N entries for a context
    fn get_top_leaderboard_entries(
        self: @TState, context_id: u64, count: u32,
    ) -> Array<LeaderboardEntry>;

    /// Get the position of a specific token in a context
    fn get_position(self: @TState, context_id: u64, token_id: felt252) -> Option<u32>;

    /// Check if a score qualifies for a context's leaderboard
    fn qualifies(self: @TState, context_id: u64, score: u64) -> bool;

    /// Check if a context's leaderboard is full
    fn is_full(self: @TState, context_id: u64) -> bool;

    /// Get the number of entries in a context's leaderboard
    fn get_leaderboard_length(self: @TState, context_id: u64) -> u32;

    /// Get the configuration for a context's leaderboard
    fn get_config(self: @TState, context_id: u64) -> LeaderboardStoreConfig;

    /// Find the position where a score would be inserted (1-based).
    /// O(log n) binary search — use as a view function for off-chain position calculation.
    fn find_position(self: @TState, context_id: u64, score: u64, token_id: felt252) -> Option<u32>;
}

/// Admin interface for leaderboard management
#[starknet::interface]
pub trait ILeaderboardAdmin<TState> {
    /// Configure a context's leaderboard settings (admin only)
    fn configure(
        ref self: TState,
        context_id: u64,
        max_entries: u32,
        ascending: bool,
        game_address: ContractAddress,
    );

    /// Clear a context's leaderboard (admin only)
    fn clear(ref self: TState, context_id: u64);

    /// Get the admin/owner address
    fn owner(self: @TState) -> ContractAddress;

    /// Transfer ownership
    fn transfer_ownership(ref self: TState, new_owner: ContractAddress);
}
