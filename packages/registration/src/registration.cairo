/// RegistrationComponent handles registration storage and logic for any context.
/// Entries are keyed by (context_id, entry_id) for direct enumeration.

#[starknet::component]
pub mod RegistrationComponent {
    use game_components_interfaces::registration::{IRegistration, Registration};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use crate::models::RegistrationEntryData;

    #[storage]
    pub struct Storage {
        /// Entry data keyed by (context_id, entry_id)
        Registration_entries: Map<(u64, u32), RegistrationEntryData>,
        /// Entry count per context
        Registration_entry_counts: Map<u64, u32>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(RegistrationImpl)]
    impl RegistrationComponentImpl<
        TContractState, +HasComponent<TContractState>,
    > of IRegistration<ComponentState<TContractState>> {
        fn get_entry(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> Registration {
            self._get_entry(context_id, entry_id)
        }

        fn entry_exists(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            self._entry_exists(context_id, entry_id)
        }

        fn is_entry_banned(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            self.Registration_entries.entry((context_id, entry_id)).read().is_banned
        }

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self._get_entry_count(context_id)
        }
    }

    #[generate_trait]
    pub impl RegistrationInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of RegistrationInternalTrait<TContractState> {
        /// Get entry by (context_id, entry_id)
        fn _get_entry(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> Registration {
            let data = self.Registration_entries.entry((context_id, entry_id)).read();
            Registration {
                context_id,
                entry_id,
                game_token_id: data.game_token_id,
                has_submitted: data.has_submitted,
                is_banned: data.is_banned,
            }
        }

        /// Write an entry to storage
        fn set_entry(ref self: ComponentState<TContractState>, registration: @Registration) {
            assert(*registration.game_token_id != 0, 'Invalid token id');
            let data = RegistrationEntryData {
                game_token_id: *registration.game_token_id,
                has_submitted: *registration.has_submitted,
                is_banned: *registration.is_banned,
            };
            self
                .Registration_entries
                .entry((*registration.context_id, *registration.entry_id))
                .write(data);
        }

        /// Get entry count for a context (internal)
        fn _get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self.Registration_entry_counts.entry(context_id).read()
        }

        /// Increment entry count for a context and return new count
        fn increment_entry_count(ref self: ComponentState<TContractState>, context_id: u64) -> u32 {
            let current = self.Registration_entry_counts.entry(context_id).read();
            let new_count = current + 1;
            self.Registration_entry_counts.entry(context_id).write(new_count);
            new_count
        }

        /// Mark an entry as having submitted a score
        fn mark_entry_submitted(
            ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) {
            let data = self.Registration_entries.entry((context_id, entry_id)).read();
            let updated = RegistrationEntryData { has_submitted: true, ..data };
            self.Registration_entries.entry((context_id, entry_id)).write(updated);
        }

        /// Ban an entry
        fn ban_entry(ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32) {
            let data = self.Registration_entries.entry((context_id, entry_id)).read();
            let updated = RegistrationEntryData { is_banned: true, ..data };
            self.Registration_entries.entry((context_id, entry_id)).write(updated);
        }

        /// Check if an entry exists (game_token_id != 0)
        fn _entry_exists(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            self.Registration_entries.entry((context_id, entry_id)).read().game_token_id != 0
        }

        /// Validate registration for score submission
        fn assert_valid_for_submission(
            self: @ComponentState<TContractState>, registration: @Registration, context_id: u64,
        ) {
            // Validate provided token is registered for the specified context
            assert!(
                *registration.context_id == context_id,
                "Registration: Token not registered for context",
            );

            // Score can only be submitted once
            assert!(!*registration.has_submitted, "Registration: Score already submitted");

            // Banned game IDs cannot submit scores
            assert!(!*registration.is_banned, "Registration: Game ID is banned");
        }
    }
}
