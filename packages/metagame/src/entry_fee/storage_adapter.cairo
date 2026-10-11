// SPDX-License-Identifier: BUSL-1.1
//! Optional adapter retaining the original component storage maps.
use game_components_utilities::distribution::packed_shares::CustomShares;
use game_components_utilities::distribution::structs::PackedDistribution;
use starknet::ContractAddress;
use crate::entry_fee::entry_fee_component::EntryFeeComponent;
use crate::entry_fee::store::Store;
use crate::entry_fee::structs::PackedAdditionalShares;

pub impl ComponentStore<T, +EntryFeeComponent::HasComponent<T>, +Drop<T>> of Store<T> {
    fn get_token(self: @T, context_id: u64) -> ContractAddress {
        Store::get_token(EntryFeeComponent::HasComponent::get_component(self), context_id)
    }
    fn set_token(ref self: T, context_id: u64, token: ContractAddress) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_token(ref component, context_id, token);
    }
    fn get_data_raw(self: @T, context_id: u64) -> felt252 {
        Store::get_data_raw(EntryFeeComponent::HasComponent::get_component(self), context_id)
    }
    fn set_data_raw(ref self: T, context_id: u64, data: felt252) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_data_raw(ref component, context_id, data);
    }
    fn get_additional_recipient(self: @T, context_id: u64, index: u8) -> ContractAddress {
        Store::get_additional_recipient(
            EntryFeeComponent::HasComponent::get_component(self), context_id, index,
        )
    }
    fn set_additional_recipient(
        ref self: T, context_id: u64, index: u8, recipient: ContractAddress,
    ) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_additional_recipient(ref component, context_id, index, recipient);
    }
    fn get_packed_shares(self: @T, context_id: u64, slot: u8) -> PackedAdditionalShares {
        Store::get_packed_shares(
            EntryFeeComponent::HasComponent::get_component(self), context_id, slot,
        )
    }
    fn set_packed_shares(ref self: T, context_id: u64, slot: u8, shares: PackedAdditionalShares) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_packed_shares(ref component, context_id, slot, shares);
    }
    fn get_refund_claimed(self: @T, context_id: u64, token_id: felt252) -> bool {
        Store::get_refund_claimed(
            EntryFeeComponent::HasComponent::get_component(self), context_id, token_id,
        )
    }
    fn set_refund_claimed(ref self: T, context_id: u64, token_id: felt252, claimed: bool) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_refund_claimed(ref component, context_id, token_id, claimed);
    }
    fn get_position_claimed(self: @T, context_id: u64, position: u32) -> bool {
        Store::get_position_claimed(
            EntryFeeComponent::HasComponent::get_component(self), context_id, position,
        )
    }
    fn set_position_claimed(ref self: T, context_id: u64, position: u32, claimed: bool) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_position_claimed(ref component, context_id, position, claimed);
    }
    fn get_extension_address(self: @T, context_id: u64) -> ContractAddress {
        Store::get_extension_address(
            EntryFeeComponent::HasComponent::get_component(self), context_id,
        )
    }
    fn set_extension_address(ref self: T, context_id: u64, address: ContractAddress) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_extension_address(ref component, context_id, address);
    }
    fn get_distribution_shares_packed(self: @T, context_id: u64, slot: u8) -> CustomShares {
        Store::get_distribution_shares_packed(
            EntryFeeComponent::HasComponent::get_component(self), context_id, slot,
        )
    }
    fn set_distribution_shares_packed(
        ref self: T, context_id: u64, slot: u8, shares: CustomShares,
    ) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_distribution_shares_packed(ref component, context_id, slot, shares);
    }
    fn get_distribution(self: @T, context_id: u64) -> PackedDistribution {
        Store::get_distribution(EntryFeeComponent::HasComponent::get_component(self), context_id)
    }
    fn set_distribution(ref self: T, context_id: u64, distribution: PackedDistribution) {
        let mut component = EntryFeeComponent::HasComponent::get_component_mut(ref self);
        Store::set_distribution(ref component, context_id, distribution);
    }
}
