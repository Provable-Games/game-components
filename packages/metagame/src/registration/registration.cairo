/// RegistrationComponent handles registration storage and logic for any context.
/// Entries are keyed by (context_id, entry_id) for direct enumeration.
///
/// Storage is split into two Maps for gas efficiency:
///   - Registration_token_ids: (context_id, entry_id) -> felt252  (game token ID)
///   - Registration_flags: (context_id, entry_id) -> u8  (bit 0 = has_submitted, bit 1 = is_banned)
///
/// Functions that only need flags (is_entry_banned, mark_entry_submitted, ban_entry)
/// save 1 SLOAD by not reading the token_id slot. Similarly, _entry_exists only
/// reads the token_id slot.

#[starknet::component]
pub mod RegistrationComponent {
    use game_components_interfaces::registration::{IRegistration, Registration};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };

    /// Flag bit constants
    const FLAG_HAS_SUBMITTED: u8 = 1; // bit 0
    const FLAG_IS_BANNED: u8 = 2; // bit 1

    #[storage]
    pub struct Storage {
        /// Game token ID keyed by (context_id, entry_id)
        Registration_token_ids: Map<(u64, u32), felt252>,
        /// Flags keyed by (context_id, entry_id): bit 0 = has_submitted, bit 1 = is_banned
        Registration_flags: Map<(u64, u32), u8>,
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
            // Only reads flags slot (1 SLOAD instead of 2)
            let flags = self.Registration_flags.entry((context_id, entry_id)).read();
            (flags & FLAG_IS_BANNED) != 0
        }

        fn get_entry_count(self: @ComponentState<TContractState>, context_id: u64) -> u32 {
            self._get_entry_count(context_id)
        }
    }

    #[generate_trait]
    pub impl RegistrationInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of RegistrationInternalTrait<TContractState> {
        /// Get entry by (context_id, entry_id) — reads both slots
        fn _get_entry(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> Registration {
            let key = (context_id, entry_id);
            let game_token_id = self.Registration_token_ids.entry(key).read();
            let flags = self.Registration_flags.entry(key).read();
            Registration {
                context_id,
                entry_id,
                game_token_id,
                has_submitted: (flags & FLAG_HAS_SUBMITTED) != 0,
                is_banned: (flags & FLAG_IS_BANNED) != 0,
            }
        }

        /// Write an entry to storage — writes both slots
        fn set_entry(ref self: ComponentState<TContractState>, registration: @Registration) {
            assert(*registration.game_token_id != 0, 'Invalid token id');
            let key = (*registration.context_id, *registration.entry_id);

            self.Registration_token_ids.entry(key).write(*registration.game_token_id);

            let mut flags: u8 = 0;
            if *registration.has_submitted {
                flags = flags | FLAG_HAS_SUBMITTED;
            }
            if *registration.is_banned {
                flags = flags | FLAG_IS_BANNED;
            }
            self.Registration_flags.entry(key).write(flags);
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

        /// Mark an entry as having submitted a score — flags only (1 SLOAD + 1 SSTORE)
        fn mark_entry_submitted(
            ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) {
            let key = (context_id, entry_id);
            let flags = self.Registration_flags.entry(key).read();
            self.Registration_flags.entry(key).write(flags | FLAG_HAS_SUBMITTED);
        }

        /// Ban an entry — flags only (1 SLOAD + 1 SSTORE)
        fn ban_entry(ref self: ComponentState<TContractState>, context_id: u64, entry_id: u32) {
            let key = (context_id, entry_id);
            let flags = self.Registration_flags.entry(key).read();
            self.Registration_flags.entry(key).write(flags | FLAG_IS_BANNED);
        }

        /// Check if an entry exists (game_token_id != 0) — token_id only (1 SLOAD)
        fn _entry_exists(
            self: @ComponentState<TContractState>, context_id: u64, entry_id: u32,
        ) -> bool {
            self.Registration_token_ids.entry((context_id, entry_id)).read() != 0
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
