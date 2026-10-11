// SPDX-License-Identifier: BUSL-1.1
//! Storage-independent APIs. The host supplies Store and enforces access control,
//! lifecycle eligibility and reentrancy protection before internal mutations.
use game_components_interfaces::registration::{IRegistration, Registration};
use crate::registration::registration::registration::RegistrationValidationImpl;
use crate::registration::registration_store::{RegistrationStoreImpl, RegistrationStoreTrait};
use crate::registration::store::Store;


#[starknet::embeddable]
pub impl RegistrationImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of IRegistration<TContractState> {
    fn get_entry(self: @TContractState, context_id: u64, entry_id: u32) -> Registration {
        RegistrationStoreTrait::get_entry(self, context_id, entry_id)
    }

    fn entry_exists(self: @TContractState, context_id: u64, entry_id: u32) -> bool {
        RegistrationStoreTrait::entry_exists(self, context_id, entry_id)
    }

    fn is_token_banned(self: @TContractState, context_id: u64, token_id: felt252) -> bool {
        RegistrationStoreTrait::is_token_banned(self, context_id, token_id)
    }

    fn get_entry_count(self: @TContractState, context_id: u64) -> u32 {
        Store::get_entry_count(self, context_id)
    }
}

#[generate_trait]
pub impl RegistrationInternalImpl<
    TContractState, +Store<TContractState>, +Drop<TContractState>,
> of RegistrationInternalTrait<TContractState> {
    fn _get_entry(self: @TContractState, context_id: u64, entry_id: u32) -> Registration {
        RegistrationStoreTrait::get_entry(self, context_id, entry_id)
    }

    fn set_entry(ref self: TContractState, registration: @Registration) {
        RegistrationStoreTrait::set_entry(ref self, registration);
    }

    fn _get_entry_count(self: @TContractState, context_id: u64) -> u32 {
        Store::get_entry_count(self, context_id)
    }

    fn increment_entry_count(ref self: TContractState, context_id: u64) -> u32 {
        RegistrationStoreTrait::increment_entry_count(ref self, context_id)
    }

    fn mark_token_submitted(ref self: TContractState, context_id: u64, token_id: felt252) {
        RegistrationStoreTrait::mark_token_submitted(ref self, context_id, token_id);
    }

    fn ban_token(ref self: TContractState, context_id: u64, token_id: felt252) {
        RegistrationStoreTrait::ban_token(ref self, context_id, token_id);
    }

    fn _entry_exists(self: @TContractState, context_id: u64, entry_id: u32) -> bool {
        RegistrationStoreTrait::entry_exists(self, context_id, entry_id)
    }

    fn assert_valid_for_submission(
        self: @TContractState, registration: @Registration, context_id: u64,
    ) {
        RegistrationValidationImpl::assert_valid_for_submission(registration, context_id);
    }

    fn _get_token_context(self: @TContractState, context_id: u64, token_id: felt252) -> u64 {
        RegistrationStoreTrait::get_token_context(self, context_id, token_id)
    }

    fn _is_token_submitted(self: @TContractState, context_id: u64, token_id: felt252) -> bool {
        RegistrationStoreTrait::is_token_submitted(self, context_id, token_id)
    }

    fn _is_token_banned(self: @TContractState, context_id: u64, token_id: felt252) -> bool {
        RegistrationStoreTrait::is_token_banned(self, context_id, token_id)
    }
}
