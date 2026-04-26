// SPDX-License-Identifier: BUSL-1.1

/// RegistrationComponent handles registration storage and logic for any context.
/// Entries are keyed by (context_id, entry_id) for direct enumeration. Reverse
/// indexes keyed by token_id support O(1) token-to-entry lookups, since each
/// token belongs to exactly one context within a component instance.
///
/// Storage layout:
///   - Registration_token_ids: (context_id, entry_id) -> felt252  (game token ID)
///   - Registration_flags: (context_id, entry_id) -> u8  (bit 0 = has_submitted, bit 1 = is_banned)
///   - Registration_entry_counts: context_id -> u32  (next entry_id is count + 1)
///   - Registration_token_context: token_id -> u64  (reverse: which context owns this token)
///   - Registration_token_entry_id: token_id -> u32  (reverse: token's slot within its context)

#[starknet::component]
pub mod RegistrationComponent {
    use game_components_interfaces::registration::{IRegistration, Registration};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::registration::registration::registration::RegistrationValidationImpl;
    use crate::registration::registration_store::{RegistrationStoreImpl, RegistrationStoreTrait};
    use crate::registration::store::Store;

    #[storage]
    pub struct Storage {
        /// Game token ID keyed by (context_id, entry_id)
        Registration_token_ids: Map<(u64, u32), felt252>,
        /// Flags keyed by (context_id, entry_id): bit 0 = has_submitted, bit 1 = is_banned
        Registration_flags: Map<(u64, u32), u8>,
        /// Entry count per context
        Registration_entry_counts: Map<u64, u32>,
        /// Reverse: token_id -> context_id (0 if not registered)
        Registration_token_context: Map<felt252, u64>,
        /// Reverse: token_id -> entry_id within its context (0 if not registered)
        Registration_token_entry_id: Map<felt252, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    // Implement the Store trait for this component
    impl ComponentStore<
        TContractState, +HasComponent<TContractState>,
    > of Store<ComponentState<TContractState>> {
        fn get_token_id(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> felt252 {
            self.Registration_token_ids.entry((context_id, entry_id)).read()
        }

        fn set_token_id(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            entry_id: u32,
            token_id: felt252,
        ) {
            self.Registration_token_ids.entry((context_id, entry_id)).write(token_id);
        }

        fn get_flags(self: @ComponentState<TContractState>, context_id: u64, entry_id: u32) -> u8 {
            self.Registration_flags.entry((context_id, entry_id)).read()
        }

        fn set_flags(
            ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32, flags: u8,
        ) {
            self.Registration_flags.entry((context_id, entry_id)).write(flags);
        }

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.Registration_entry_counts.entry(context_id).read()
        }

        fn set_entry_count(ref self: ComponentState<TContractState>, context_id: u64, count: u32) {
            self.Registration_entry_counts.entry(context_id).write(count);
        }

        fn get_token_context(self: @ComponentState<TContractState>, token_id: felt252) -> u64 {
            self.Registration_token_context.entry(token_id).read()
        }

        fn set_token_context(
            ref self: ComponentState<TContractState>, token_id: felt252, context_id: u64,
        ) {
            self.Registration_token_context.entry(token_id).write(context_id);
        }

        fn get_token_entry_id(self: @ComponentState<TContractState>, token_id: felt252) -> u32 {
            self.Registration_token_entry_id.entry(token_id).read()
        }

        fn set_token_entry_id(
            ref self: ComponentState<TContractState>, token_id: felt252, entry_id: u32,
        ) {
            self.Registration_token_entry_id.entry(token_id).write(entry_id);
        }
    }

    #[embeddable_as(RegistrationImpl)]
    impl RegistrationComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IRegistration<ComponentState<TContractState>> {
        fn get_entry(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> Registration {
            RegistrationStoreTrait::get_entry(self, context_id, entry_id)
        }

        fn entry_exists(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            RegistrationStoreTrait::entry_exists(self, context_id, entry_id)
        }

        fn is_entry_banned(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            RegistrationStoreTrait::is_entry_banned(self, context_id, entry_id)
        }

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            Store::get_entry_count(self, context_id)
        }

        fn get_token_context(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u64 {
            Store::get_token_context(self, token_id)
        }

        fn get_entry_id_for_token(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u32 {
            Store::get_token_entry_id(self, token_id)
        }

        fn get_entry_by_token(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> Registration {
            RegistrationStoreTrait::get_entry_by_token(self, token_id)
        }
    }

    #[generate_trait]
    pub impl RegistrationInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of RegistrationInternalTrait<TContractState> {
        fn _get_entry(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> Registration {
            RegistrationStoreTrait::get_entry(self, context_id, entry_id)
        }

        fn set_entry(ref self: ComponentState<TContractState>, registration: @Registration) {
            RegistrationStoreTrait::set_entry(ref self, registration);
        }

        fn _get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            Store::get_entry_count(self, context_id)
        }

        fn increment_entry_count(ref self: ComponentState<TContractState>, context_id: u64) -> u32 {
            RegistrationStoreTrait::increment_entry_count(ref self, context_id)
        }

        fn mark_entry_submitted(
            ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) {
            RegistrationStoreTrait::mark_entry_submitted(ref self, context_id, entry_id);
        }

        fn ban_entry(ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32) {
            RegistrationStoreTrait::ban_entry(ref self, context_id, entry_id);
        }

        fn _entry_exists(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            RegistrationStoreTrait::entry_exists(self, context_id, entry_id)
        }

        fn assert_valid_for_submission(
            self: @ComponentState<TContractState>, registration: @Registration, context_id: u64,
        ) {
            RegistrationValidationImpl::assert_valid_for_submission(registration, context_id);
        }

        fn _get_token_context(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u64 {
            Store::get_token_context(self, token_id)
        }

        fn _get_entry_id_for_token(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u32 {
            Store::get_token_entry_id(self, token_id)
        }

        fn _get_entry_by_token(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> Registration {
            RegistrationStoreTrait::get_entry_by_token(self, token_id)
        }
    }
}
