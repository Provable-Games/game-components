// SPDX-License-Identifier: BUSL-1.1
//! Optional adapter retaining the standard component storage maps.
use crate::leaderboard::leaderboard_component::LeaderboardComponent;
use crate::leaderboard::store::Store;

pub impl ComponentStore<T, +LeaderboardComponent::HasComponent<T>, +Drop<T>> of Store<T> {
    fn get_leaderboard(self: @T, context_id: u64) -> Span<felt252> {
        Store::get_leaderboard(LeaderboardComponent::HasComponent::get_component(self), context_id)
    }
    fn get_count(self: @T, context_id: u64) -> u32 {
        Store::get_count(LeaderboardComponent::HasComponent::get_component(self), context_id)
    }
    fn set_count(ref self: T, context_id: u64, count: u32) {
        let mut component = LeaderboardComponent::HasComponent::get_component_mut(ref self);
        Store::set_count(ref component, context_id, count);
    }
    fn get_entry_at(self: @T, context_id: u64, position: u32) -> felt252 {
        Store::get_entry_at(
            LeaderboardComponent::HasComponent::get_component(self), context_id, position,
        )
    }
    fn set_entry_at(ref self: T, context_id: u64, position: u32, token_id: felt252) {
        let mut component = LeaderboardComponent::HasComponent::get_component_mut(ref self);
        Store::set_entry_at(ref component, context_id, position, token_id);
    }
    fn get_score_at(self: @T, context_id: u64, position: u32) -> u64 {
        Store::get_score_at(
            LeaderboardComponent::HasComponent::get_component(self), context_id, position,
        )
    }
    fn set_score_at(ref self: T, context_id: u64, position: u32, score: u64) {
        let mut component = LeaderboardComponent::HasComponent::get_component_mut(ref self);
        Store::set_score_at(ref component, context_id, position, score);
    }
    fn get_token_position(self: @T, context_id: u64, token_id: felt252) -> u32 {
        Store::get_token_position(
            LeaderboardComponent::HasComponent::get_component(self), context_id, token_id,
        )
    }
    fn set_token_position(ref self: T, context_id: u64, token_id: felt252, position: u32) {
        let mut component = LeaderboardComponent::HasComponent::get_component_mut(ref self);
        Store::set_token_position(ref component, context_id, token_id, position);
    }
}
