// SPDX-License-Identifier: BUSL-1.1
//! Optional adapter retaining the original component storage maps.
use starknet::ContractAddress;
use crate::prize::prize_component::PrizeComponent;
use crate::prize::store::Store;
use crate::prize::structs::{CustomShares, StoredPrize};

pub impl ComponentStore<T, +PrizeComponent::HasComponent<T>, +Drop<T>> of Store<T> {
    fn get_prize(self: @T, prize_id: u64) -> StoredPrize {
        Store::get_prize(PrizeComponent::HasComponent::get_component(self), prize_id)
    }
    fn set_prize(ref self: T, prize_id: u64, prize: StoredPrize) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_prize(ref component, prize_id, prize);
    }
    fn get_claim(self: @T, context_id: u64, hash: felt252) -> bool {
        Store::get_claim(PrizeComponent::HasComponent::get_component(self), context_id, hash)
    }
    fn set_claim(ref self: T, context_id: u64, hash: felt252, claimed: bool) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_claim(ref component, context_id, hash, claimed);
    }
    fn get_total_prizes(self: @T) -> u64 {
        Store::get_total_prizes(PrizeComponent::HasComponent::get_component(self))
    }
    fn set_total_prizes(ref self: T, count: u64) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_total_prizes(ref component, count);
    }
    fn get_custom_shares_count(self: @T, prize_id: u64) -> u32 {
        Store::get_custom_shares_count(PrizeComponent::HasComponent::get_component(self), prize_id)
    }
    fn set_custom_shares_count(ref self: T, prize_id: u64, count: u32) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_custom_shares_count(ref component, prize_id, count);
    }
    fn get_custom_shares_packed(self: @T, prize_id: u64, slot: u8) -> CustomShares {
        Store::get_custom_shares_packed(
            PrizeComponent::HasComponent::get_component(self), prize_id, slot,
        )
    }
    fn set_custom_shares_packed(ref self: T, prize_id: u64, slot: u8, shares: CustomShares) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_custom_shares_packed(ref component, prize_id, slot, shares);
    }
    fn get_extension_address(self: @T, context_id: u64, prize_id: u64) -> ContractAddress {
        Store::get_extension_address(
            PrizeComponent::HasComponent::get_component(self), context_id, prize_id,
        )
    }
    fn set_extension_address(ref self: T, context_id: u64, prize_id: u64, addr: ContractAddress) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_extension_address(ref component, context_id, prize_id, addr);
    }
    fn get_extension_prize_context(self: @T, prize_id: u64) -> u64 {
        Store::get_extension_prize_context(
            PrizeComponent::HasComponent::get_component(self), prize_id,
        )
    }
    fn set_extension_prize_context(ref self: T, prize_id: u64, context_id: u64) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_extension_prize_context(ref component, prize_id, context_id);
    }
    fn get_extension_prize_sponsor(self: @T, prize_id: u64) -> ContractAddress {
        Store::get_extension_prize_sponsor(
            PrizeComponent::HasComponent::get_component(self), prize_id,
        )
    }
    fn set_extension_prize_sponsor(ref self: T, prize_id: u64, sponsor: ContractAddress) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_extension_prize_sponsor(ref component, prize_id, sponsor);
    }
    fn get_payout_position(self: @T, prize_id: u64) -> u32 {
        Store::get_payout_position(PrizeComponent::HasComponent::get_component(self), prize_id)
    }
    fn set_payout_position(ref self: T, prize_id: u64, position: u32) {
        let mut component = PrizeComponent::HasComponent::get_component_mut(ref self);
        Store::set_payout_position(ref component, prize_id, position);
    }
}
