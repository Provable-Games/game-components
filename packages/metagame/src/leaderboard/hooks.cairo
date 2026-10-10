// SPDX-License-Identifier: BUSL-1.1
use starknet::ContractAddress;

pub trait LeaderboardHooksTrait<TContractState> {
    /// Called after a score is successfully submitted
    fn on_score_submitted(
        ref self: TContractState, context_id: u64, token_id: felt252, score: u64, position: u32,
    );

    /// Called after a leaderboard context is configured
    fn on_configured(
        ref self: TContractState,
        context_id: u64,
        max_entries: u32,
        ascending: bool,
        game_address: ContractAddress,
    );

    /// Called after a leaderboard is cleared
    fn on_cleared(ref self: TContractState, context_id: u64);

    /// Called after ownership is transferred
    fn on_ownership_transferred(
        ref self: TContractState, previous_owner: ContractAddress, new_owner: ContractAddress,
    );
}
