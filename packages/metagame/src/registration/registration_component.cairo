// SPDX-License-Identifier: BUSL-1.1

/// RegistrationComponent handles registration storage and logic for any context.
/// Entries are keyed by (context_id, entry_id) for direct enumeration.
/// Per-token state (context_id + has_submitted + is_banned) lives in a single
/// packed felt252 keyed by token_id, giving consumers O(1) state access from a
/// token without intermediate lookups.
///
/// Storage layout:
///   - Registration_token_ids: (context_id, entry_id) -> felt252  (game token ID)
///   - Registration_entry_counts: context_id -> u32  (next entry_id is count + 1)
///   - Registration_token_state: (context_id, token_id) -> packed felt252
///       bits  0..63: context_id (u64) — 0 means "not registered HERE"
///       bit   64:    has_submitted
///       bit   65:    is_banned
///   - Registration_token_last_context: token_id -> context_id (display only)
///
/// Conventions:
///   - context_id is expected to be >= 1. `_get_token_context` treats 0 as
///     "not registered", so a caller using context_id == 0 cannot
///     distinguish a real context-zero registration from an unknown
///     token via the reverse index. entry_id is always >= 1 by
///     construction (see `increment_entry_count`).
///
/// # Token ids are only unique within one game
///
/// Token state is keyed by the PAIR `(context_id, token_id)`, because a token
/// id is unique only within the contract that minted it -- identity is
/// `(game, id)`, never `id` alone. Keying on `token_id` was safe only while
/// every entry came from a single shared token contract.
///
/// Ids are packed felts, not counters, so two games do not collide by default:
/// a collision needs two ids that pack byte-identically. Reachable by accident
/// (one multicall minting into two games with the same params and salt in one
/// block) and, more to the point, on purpose -- an attacker controls their own
/// game contract and every packed field except `minted_at`, a block timestamp
/// they need only match to the second.
///
/// `set_entry` wrote the state slot unconditionally, so the later registration
/// overwrote the earlier token's context and cleared its flags, locking that
/// player out of the context they had registered and paid for. A targeted
/// grief, for the price of one entry on a game the attacker controls.
///
/// `Registration_token_last_context` is a DISPLAY-ONLY reverse index for
/// `has_context`-style read surfaces that are handed a bare `token_id` and no
/// game. Last writer wins across games, and it is deliberately not consulted
/// by anything that authorizes: a reverse lookup from a bare token id is
/// fundamentally ambiguous once ids are not globally unique, and the only
/// real fix is to carry the game address in that interface.

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
        /// Entry count per context
        Registration_entry_counts: Map<u64, u32>,
        /// Per-(context, token) packed state. See structs.cairo
        /// TokenStateStorePacking for layout.
        Registration_token_state: Map<(u64, felt252), felt252>,
        /// Display-only reverse index. NEVER authorize against this.
        Registration_token_last_context: Map<felt252, u64>,
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

        fn get_token_last_context(self: @ComponentState<TContractState>, token_id: felt252) -> u64 {
            self.Registration_token_last_context.entry(token_id).read()
        }

        fn set_token_last_context(
            ref self: ComponentState<TContractState>, token_id: felt252, context_id: u64,
        ) {
            self.Registration_token_last_context.entry(token_id).write(context_id);
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

        /// Display-only. See the module docs: last writer wins across games,
        /// so never authorize against this.
        fn _get_token_last_context(
            self: @ComponentState<TContractState>, token_id: felt252,
        ) -> u64 {
            Store::get_token_last_context(self, token_id)
        }
    }
}
