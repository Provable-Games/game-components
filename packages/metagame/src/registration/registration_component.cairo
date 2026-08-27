// SPDX-License-Identifier: BUSL-1.1

/// RegistrationComponent handles registration storage and logic for any context.
/// Entries are keyed by (context_id, entry_id) for direct enumeration.
///
/// Storage layout:
///   - Registration_token_ids: (context_id, entry_id) -> felt252  (game token ID)
///   - Registration_entry_counts: context_id -> u32  (next entry_id is count + 1)
///   - Registration_token_state: (context_id, token_id) -> packed TokenState
///   - Registration_token_last_context: token_id -> packed LastContext
///     (display only)
///
/// See structs.cairo for both packed layouts.
///
/// context_id is expected to be >= 1: `_get_token_context` treats 0 as "not
/// registered". entry_id is always >= 1 by construction.
///
/// Token state is keyed by the PAIR (context_id, token_id) because a token id
/// is unique only within the contract that minted it — identity is (game, id),
/// never id alone. Keying on token_id was safe only while every entry came
/// from one shared token contract.
///
/// UPGRADE HAZARD: that re-keying moved every slot, and there is no migration.
/// A class upgraded in place over storage written by v2.1.1 or earlier reads
/// the new keys, finds them empty, and strands every existing entry. Deploy
/// fresh. Cairo cannot make the contract refuse, so this note is the only
/// guard. How it surfaces depends on the consumer: one that gates on
/// `get_token_context(ctx, id) == ctx` before trusting the flags fails CLOSED
/// (entries locked out of submitting); one that reads `is_token_banned`
/// without proving registration fails OPEN (a banned token reads clean).
/// Neither is visible at upgrade time.
///
/// Registration_token_last_context is a DISPLAY-ONLY reverse index for callers
/// handed a bare token_id and no game. Never authorize against it: it reports
/// ambiguous once an id appears in two contexts, because a bare id genuinely
/// cannot name one. Carrying the game address in the interface is the real fix.
#[starknet::component]
pub mod RegistrationComponent {
    use game_components_interfaces::registration::{IRegistration, Registration};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::registration::registration::registration::RegistrationValidationImpl;
    use crate::registration::registration_store::{RegistrationStoreImpl, RegistrationStoreTrait};
    use crate::registration::store::Store;
    use crate::registration::structs::LastContextStorePacking;

    #[storage]
    pub struct Storage {
        /// Game token ID keyed by (context_id, entry_id)
        Registration_token_ids: Map<(u64, u32), felt252>,
        /// Entry count per context
        Registration_entry_counts: Map<u64, u32>,
        /// Per-(context, token) packed state. See structs.cairo
        /// TokenStateStorePacking for layout.
        Registration_token_state: Map<(u64, felt252), felt252>,
        /// Display-only reverse index. NEVER authorize against this.
        Registration_token_last_context: Map<felt252, felt252>,
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

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.Registration_entry_counts.entry(context_id).read()
        }

        fn set_entry_count(ref self: ComponentState<TContractState>, context_id: u64, count: u32) {
            self.Registration_entry_counts.entry(context_id).write(count);
        }

        fn get_token_state_raw(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> felt252 {
            self.Registration_token_state.entry((context_id, token_id)).read()
        }

        fn set_token_state_raw(
            ref self: ComponentState<TContractState>,
            context_id: u64,
            token_id: felt252,
            state: felt252,
        ) {
            self.Registration_token_state.entry((context_id, token_id)).write(state);
        }

        fn get_token_last_context(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> felt252 {
            self.Registration_token_last_context.entry(token_id).read()
        }

        fn set_token_last_context(
            ref self: ComponentState<TContractState>, token_id: felt252, packed: felt252,
        ) {
            self.Registration_token_last_context.entry(token_id).write(packed);
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

        fn is_token_banned(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            RegistrationStoreTrait::is_token_banned(self, context_id, token_id)
        }

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            Store::get_entry_count(self, context_id)
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

        fn mark_token_submitted(
            ref self: ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) {
            RegistrationStoreTrait::mark_token_submitted(ref self, context_id, token_id);
        }

        fn ban_token(ref self: ComponentState<TContractState>, context_id: u64, token_id: felt252) {
            RegistrationStoreTrait::ban_token(ref self, context_id, token_id);
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
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> u64 {
            RegistrationStoreTrait::get_token_context(self, context_id, token_id)
        }

        fn _is_token_submitted(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            RegistrationStoreTrait::is_token_submitted(self, context_id, token_id)
        }

        fn _is_token_banned(
            self: @ComponentState<TContractState>, context_id: u64, token_id: felt252,
        ) -> bool {
            RegistrationStoreTrait::is_token_banned(self, context_id, token_id)
        }

        /// Display-only. See the module docs -- never authorize against this.
        ///
        /// Reports 0 both for "never registered" and for "registered in more
        /// than one context, so I cannot say which". Callers that treat
        /// unknown as absent are already correct; callers that need certainty
        /// must use `_get_token_context`, which takes the context.
        fn _get_token_last_context(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u64 {
            let last = LastContextStorePacking::unpack(
                Store::get_token_last_context(self, token_id),
            );
            if last.is_ambiguous {
                0
            } else {
                last.context_id
            }
        }
    }
}
