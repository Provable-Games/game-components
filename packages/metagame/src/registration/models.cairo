/// Entry data stored per (context_id, entry_id).
/// game_token_id != 0 means the entry exists.
///
/// StorePacking layout (2 storage slots instead of 3):
///   Slot 1: game_token_id as felt252 (full 251 bits)
///   Slot 2: flags as u8 — bit 0 = has_submitted, bit 1 = is_banned
use starknet::storage_access::StorePacking;

#[derive(Copy, Drop, Serde)]
pub struct RegistrationEntryData {
    pub game_token_id: felt252,
    pub has_submitted: bool,
    pub is_banned: bool,
}

pub impl RegistrationEntryDataStorePacking of StorePacking<RegistrationEntryData, (felt252, u8)> {
    fn pack(value: RegistrationEntryData) -> (felt252, u8) {
        let mut flags: u8 = 0;
        if value.has_submitted {
            flags = flags | 1; // bit 0
        }
        if value.is_banned {
            flags = flags | 2; // bit 1 (0x2)
        }
        (value.game_token_id, flags)
    }

    fn unpack(value: (felt252, u8)) -> RegistrationEntryData {
        let (game_token_id, flags) = value;
        let has_submitted = (flags & 1) != 0; // bit 0
        let is_banned = (flags & 2) != 0; // bit 1

        RegistrationEntryData { game_token_id, has_submitted, is_banned }
    }
}
