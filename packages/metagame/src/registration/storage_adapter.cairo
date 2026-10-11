// SPDX-License-Identifier: BUSL-1.1
//! Optional adapter retaining the original component storage maps.
use crate::registration::registration_component::RegistrationComponent;
use crate::registration::store::Store;

pub impl ComponentStore<T, +RegistrationComponent::HasComponent<T>, +Drop<T>> of Store<T> {
    fn get_token_id(self: @T, context_id: u64, entry_id: u32) -> felt252 {
        Store::get_token_id(
            RegistrationComponent::HasComponent::get_component(self), context_id, entry_id,
        )
    }
    fn set_token_id(ref self: T, context_id: u64, entry_id: u32, token_id: felt252) {
        let mut component = RegistrationComponent::HasComponent::get_component_mut(ref self);
        Store::set_token_id(ref component, context_id, entry_id, token_id);
    }
    fn get_entry_count(self: @T, context_id: u64) -> u32 {
        Store::get_entry_count(RegistrationComponent::HasComponent::get_component(self), context_id)
    }
    fn set_entry_count(ref self: T, context_id: u64, count: u32) {
        let mut component = RegistrationComponent::HasComponent::get_component_mut(ref self);
        Store::set_entry_count(ref component, context_id, count);
    }
    fn get_token_state_raw(self: @T, context_id: u64, token_id: felt252) -> felt252 {
        Store::get_token_state_raw(
            RegistrationComponent::HasComponent::get_component(self), context_id, token_id,
        )
    }
    fn set_token_state_raw(ref self: T, context_id: u64, token_id: felt252, state: felt252) {
        let mut component = RegistrationComponent::HasComponent::get_component_mut(ref self);
        Store::set_token_state_raw(ref component, context_id, token_id, state);
    }
}
