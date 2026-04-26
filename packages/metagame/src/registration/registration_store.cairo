// SPDX-License-Identifier: BUSL-1.1

use game_components_interfaces::registration::Registration;
use game_components_metagame::registration::registration::registration::{
    RegistrationOperationsImpl, RegistrationValidationImpl,
};
use game_components_metagame::registration::store::Store;

/// Store bridge: composes Store<T> reads with pure lib operations
pub trait RegistrationStoreTrait<T> {
    /// Get a full registration entry
    fn get_entry(self: @T, context_id: u64, entry_id: u32) -> Registration;
    /// Write a registration entry to storage
    fn set_entry(ref self: T, registration: @Registration);
    /// Check if an entry exists (token_id != 0)
    fn entry_exists(self: @T, context_id: u64, entry_id: u32) -> bool;
    /// Check if an entry is banned (flags-only read)
    fn is_entry_banned(self: @T, context_id: u64, entry_id: u32) -> bool;
    /// Mark an entry as having submitted a score (flags-only read/write)
    fn mark_entry_submitted(ref self: T, context_id: u64, entry_id: u32);
    /// Ban an entry (flags-only read/write)
    fn ban_entry(ref self: T, context_id: u64, entry_id: u32);
    /// Increment entry count and return new count
    fn increment_entry_count(ref self: T, context_id: u64) -> u32;
    /// Validate registration for score submission
    fn validate_for_submission(self: @T, context_id: u64, entry_id: u32);
}

pub impl RegistrationStoreImpl<T, +Store<T>, +Drop<T>> of RegistrationStoreTrait<T> {
    fn get_entry(self: @T, context_id: u64, entry_id: u32) -> Registration {
        let game_token_id = self.get_token_id(context_id, entry_id);
        let flags = self.get_flags(context_id, entry_id);
        let (has_submitted, is_banned) = RegistrationOperationsImpl::unpack_flags(flags);
        Registration { context_id, entry_id, game_token_id, has_submitted, is_banned }
    }

    fn set_entry(ref self: T, registration: @Registration) {
        RegistrationValidationImpl::assert_valid_token_id(*registration.game_token_id);
        // If this slot was previously held by a different token, clear its reverse
        // mappings so the displaced token no longer claims this slot via the index.
        let prev_token = self.get_token_id(*registration.context_id, *registration.entry_id);
        if prev_token != 0 && prev_token != *registration.game_token_id {
            self.set_token_context(prev_token, 0);
            self.set_token_entry_id(prev_token, 0);
        }
        self
            .set_token_id(
                *registration.context_id, *registration.entry_id, *registration.game_token_id,
            );
        let flags = RegistrationOperationsImpl::pack_flags(
            *registration.has_submitted, *registration.is_banned,
        );
        self.set_flags(*registration.context_id, *registration.entry_id, flags);
        self.set_token_context(*registration.game_token_id, *registration.context_id);
        self.set_token_entry_id(*registration.game_token_id, *registration.entry_id);
    }

    fn entry_exists(self: @T, context_id: u64, entry_id: u32) -> bool {
        self.get_token_id(context_id, entry_id) != 0
    }

    fn is_entry_banned(self: @T, context_id: u64, entry_id: u32) -> bool {
        let flags = self.get_flags(context_id, entry_id);
        RegistrationOperationsImpl::is_banned(flags)
    }

    fn mark_entry_submitted(ref self: T, context_id: u64, entry_id: u32) {
        let flags = self.get_flags(context_id, entry_id);
        self.set_flags(context_id, entry_id, RegistrationOperationsImpl::set_submitted(flags));
    }

    fn ban_entry(ref self: T, context_id: u64, entry_id: u32) {
        let flags = self.get_flags(context_id, entry_id);
        self.set_flags(context_id, entry_id, RegistrationOperationsImpl::set_banned(flags));
    }

    fn increment_entry_count(ref self: T, context_id: u64) -> u32 {
        let current = self.get_entry_count(context_id);
        let new_count = current + 1;
        self.set_entry_count(context_id, new_count);
        new_count
    }

    fn validate_for_submission(self: @T, context_id: u64, entry_id: u32) {
        let entry = self.get_entry(context_id, entry_id);
        RegistrationValidationImpl::assert_valid_for_submission(@entry, context_id);
    }
}
