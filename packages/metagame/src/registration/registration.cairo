// SPDX-License-Identifier: BUSL-1.1

/// Pure Cairo library for registration operations.
/// This library provides core registration functionality without storage dependencies.
pub mod registration {
    use game_components_interfaces::registration::Registration;

    /// Flag bit constants
    pub const FLAG_HAS_SUBMITTED: u8 = 1; // bit 0
    pub const FLAG_IS_BANNED: u8 = 2; // bit 1

    /// Pure operations for packing/unpacking registration flags
    pub trait RegistrationOperations {
        fn pack_flags(has_submitted: bool, is_banned: bool) -> u8;
        fn unpack_flags(flags: u8) -> (bool, bool);
        fn is_submitted(flags: u8) -> bool;
        fn is_banned(flags: u8) -> bool;
        fn set_submitted(flags: u8) -> u8;
        fn set_banned(flags: u8) -> u8;
    }

    pub impl RegistrationOperationsImpl of RegistrationOperations {
        fn pack_flags(has_submitted: bool, is_banned: bool) -> u8 {
            let mut flags: u8 = 0;
            if has_submitted {
                flags = flags | FLAG_HAS_SUBMITTED;
            }
            if is_banned {
                flags = flags | FLAG_IS_BANNED;
            }
            flags
        }

        fn unpack_flags(flags: u8) -> (bool, bool) {
            let has_submitted = (flags & FLAG_HAS_SUBMITTED) != 0;
            let is_banned = (flags & FLAG_IS_BANNED) != 0;
            (has_submitted, is_banned)
        }

        fn is_submitted(flags: u8) -> bool {
            (flags & FLAG_HAS_SUBMITTED) != 0
        }

        fn is_banned(flags: u8) -> bool {
            (flags & FLAG_IS_BANNED) != 0
        }

        fn set_submitted(flags: u8) -> u8 {
            flags | FLAG_HAS_SUBMITTED
        }

        fn set_banned(flags: u8) -> u8 {
            flags | FLAG_IS_BANNED
        }
    }

    /// Pure validation functions for registration
    pub trait RegistrationValidation {
        fn assert_valid_for_submission(registration: @Registration, context_id: u64);
        fn assert_valid_token_id(token_id: felt252);
    }

    pub impl RegistrationValidationImpl of RegistrationValidation {
        fn assert_valid_for_submission(registration: @Registration, context_id: u64) {
            assert!(
                *registration.context_id == context_id,
                "Registration: Token not registered for context",
            );
            assert!(!*registration.has_submitted, "Registration: Score already submitted");
            assert!(!*registration.is_banned, "Registration: Game ID is banned");
        }

        fn assert_valid_token_id(token_id: felt252) {
            assert(token_id != 0, 'Invalid token id');
        }
    }
}
