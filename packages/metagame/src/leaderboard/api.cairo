// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent leaderboard API. Hosts implement Store and Configuration;
//! the standard component remains an optional storage implementation.
use core::num::traits::Zero;
use game_components_interfaces::leaderboard::{
    IGameDetailsDispatcher, IGameDetailsDispatcherTrait, ILeaderboard, LeaderboardEntry,
    LeaderboardResult, LeaderboardStoreConfig,
};
use starknet::ContractAddress;
use crate::leaderboard::hooks::LeaderboardHooksTrait;
use crate::leaderboard::leaderboard_store::{
    LeaderboardStoreHelpersImpl, LeaderboardStoreHelpersTrait, LeaderboardStoreImpl,
    LeaderboardStoreTrait,
};
use crate::leaderboard::store::Store;

pub trait Configuration<T> {
    fn leaderboard_config(self: @T, context_id: u64) -> LeaderboardStoreConfig;
    /// Override when reading the full configuration would fetch unused storage slots.
    fn leaderboard_game_address(
        self: @T, context_id: u64,
    ) -> ContractAddress {
        Self::leaderboard_config(self, context_id).game_address
    }
    fn leaderboard_max_entries(
        self: @T, context_id: u64,
    ) -> u32 {
        Self::leaderboard_config(self, context_id).max_entries
    }
}

#[starknet::embeddable]
pub impl LeaderboardImpl<
    TContractState, +Store<TContractState>, +Configuration<TContractState>, +Drop<TContractState>,
> of ILeaderboard<TContractState> {
    fn get_config(self: @TContractState, context_id: u64) -> LeaderboardStoreConfig {
        self.leaderboard_config(context_id)
    }
    fn get_leaderboard_entries(self: @TContractState, context_id: u64) -> Array<LeaderboardEntry> {
        LeaderboardStoreTrait::get_entries(
            self, context_id, self.leaderboard_game_address(context_id),
        )
    }
    fn get_leaderboard_entry(
        self: @TContractState, context_id: u64, position: u32,
    ) -> LeaderboardEntry {
        assert!(position > 0, "Leaderboard: position must be 1-indexed");
        assert!(
            position <= self.get_count(context_id),
            "Leaderboard: position {} out of range",
            position,
        );
        let index = position - 1;
        let token_id = self.get_entry_at(context_id, index);
        let game_address = self.leaderboard_game_address(context_id);
        let score = if !game_address.is_zero() {
            IGameDetailsDispatcher { contract_address: game_address }.score(token_id)
        } else {
            self.get_score_at(context_id, index)
        };
        LeaderboardEntry { id: token_id, score }
    }
    fn get_top_leaderboard_entries(
        self: @TContractState, context_id: u64, count: u32,
    ) -> Array<LeaderboardEntry> {
        LeaderboardStoreHelpersTrait::get_range(
            self, context_id, 0, count, self.leaderboard_game_address(context_id),
        )
    }
    fn get_position(self: @TContractState, context_id: u64, token_id: felt252) -> Option<u32> {
        LeaderboardStoreTrait::get_position(self, context_id, token_id)
    }
    fn qualifies(self: @TContractState, context_id: u64, score: u64) -> bool {
        LeaderboardStoreTrait::qualifies(
            self, context_id, score, self.leaderboard_config(context_id),
        )
    }
    fn is_full(self: @TContractState, context_id: u64) -> bool {
        LeaderboardStoreHelpersTrait::is_full(
            self, context_id, self.leaderboard_max_entries(context_id),
        )
    }
    fn get_leaderboard_length(self: @TContractState, context_id: u64) -> u32 {
        self.get_count(context_id)
    }
    fn find_position(
        self: @TContractState, context_id: u64, score: u64, token_id: felt252,
    ) -> Option<u32> {
        LeaderboardStoreHelpersTrait::find_position(
            self, context_id, score, token_id, self.leaderboard_config(context_id),
        )
    }
}

/// Internal only: the host must validate authorization, eligibility and phase.
#[generate_trait]
pub impl LeaderboardInternalImpl<
    T, +Store<T>, +Configuration<T>, +LeaderboardHooksTrait<T>, +Drop<T>,
> of LeaderboardInternalTrait<T> {
    fn submit_score(
        ref self: T, context_id: u64, token_id: felt252, score: u64, position: u32,
    ) -> LeaderboardResult {
        let config = self.leaderboard_config(context_id);
        let result = LeaderboardStoreTrait::submit_score(
            ref self, context_id, token_id, score, position, config,
        );
        if result == LeaderboardResult::Success {
            LeaderboardHooksTrait::on_score_submitted(
                ref self, context_id, token_id, score, position,
            );
        }
        result
    }
}
