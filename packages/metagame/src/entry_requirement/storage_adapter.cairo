// SPDX-License-Identifier: BUSL-1.1
//! Optional adapter retaining the standard component storage maps.
use starknet::ContractAddress;
use crate::entry_requirement::entry_requirement_component::EntryRequirementComponent;
use crate::entry_requirement::store::Store;
use crate::entry_requirement::structs::EntryRequirementMeta;

/// The host chooses where requirement metadata is stored.
pub trait Metadata<T> {
    fn requirement_meta(self: @T, context_id: u64) -> EntryRequirementMeta;
    fn set_requirement_meta(ref self: T, context_id: u64, meta: EntryRequirementMeta);
}

pub impl ComponentStore<
    T, +EntryRequirementComponent::HasComponent<T>, impl Meta: Metadata<T>, +Drop<T>,
> of Store<T> {
    fn get_meta(self: @T, context_id: u64) -> EntryRequirementMeta {
        Meta::requirement_meta(self, context_id)
    }
    fn set_meta(ref self: T, context_id: u64, meta: EntryRequirementMeta) {
        Meta::set_requirement_meta(ref self, context_id, meta)
    }
    fn get_token(self: @T, context_id: u64) -> ContractAddress {
        Store::get_token(EntryRequirementComponent::HasComponent::get_component(self), context_id)
    }
    fn set_token(ref self: T, context_id: u64, token: ContractAddress) {
        let mut component = EntryRequirementComponent::HasComponent::get_component_mut(ref self);
        Store::set_token(ref component, context_id, token);
    }
    fn get_extension_address(self: @T, context_id: u64) -> ContractAddress {
        Store::get_extension_address(
            EntryRequirementComponent::HasComponent::get_component(self), context_id,
        )
    }
    fn set_extension_address(ref self: T, context_id: u64, address: ContractAddress) {
        let mut component = EntryRequirementComponent::HasComponent::get_component_mut(ref self);
        Store::set_extension_address(ref component, context_id, address);
    }
    fn get_qualification_entries(self: @T, context_id: u64, hash: felt252) -> u32 {
        Store::get_qualification_entries(
            EntryRequirementComponent::HasComponent::get_component(self), context_id, hash,
        )
    }
    fn set_qualification_entries(ref self: T, context_id: u64, hash: felt252, count: u32) {
        let mut component = EntryRequirementComponent::HasComponent::get_component_mut(ref self);
        Store::set_qualification_entries(ref component, context_id, hash, count);
    }
}

/// Original metadata storage for applications that do not customize it.
pub impl ComponentMetadata<
    T, +EntryRequirementComponent::HasComponent<T>, +Drop<T>,
> of Metadata<T> {
    fn requirement_meta(self: @T, context_id: u64) -> EntryRequirementMeta {
        Store::get_meta(EntryRequirementComponent::HasComponent::get_component(self), context_id)
    }
    fn set_requirement_meta(ref self: T, context_id: u64, meta: EntryRequirementMeta) {
        let mut component = EntryRequirementComponent::HasComponent::get_component_mut(ref self);
        Store::set_meta(ref component, context_id, meta);
    }
}
