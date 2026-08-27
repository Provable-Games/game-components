/// Storage-packed structs for the registration component.
use starknet::storage_access::StorePacking;

// ----------------------------------------------------------------------------
// RegistrationEntryData
// Legacy struct kept for the test_models suite. Production storage uses
// TokenState below.
// ----------------------------------------------------------------------------

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

// ----------------------------------------------------------------------------
// TokenState — per-token packed state
//
// Replaces the previous separate `Registration_flags` and
// `Registration_token_context` storage maps with a single packed slot per
// token, halving the SSTOREs at registration time and letting consumers
// resolve `(context, flags)` in a single SLOAD.
//
// Bit layout in the packed felt252 (low → high):
//   bits  0..63: context_id (u64)  — 0 means "not registered"
//   bit   64:    has_submitted
//   bit   65:    is_banned
//   bits 66..:  reserved (0)
// ----------------------------------------------------------------------------

const CONTEXT_ID_MASK: u128 = 0xFFFFFFFFFFFFFFFF; // low 64 bits
const HAS_SUBMITTED_BIT: u128 = 0x10000000000000000; // bit 64
const IS_BANNED_BIT: u128 = 0x20000000000000000; // bit 65

#[derive(Copy, Drop, Serde)]
pub struct TokenState {
    pub context_id: u64,
    pub has_submitted: bool,
    pub is_banned: bool,
}

pub impl TokenStateStorePacking of StorePacking<TokenState, felt252> {
    fn pack(value: TokenState) -> felt252 {
        let mut packed: u128 = value.context_id.into();
        if value.has_submitted {
            packed = packed | HAS_SUBMITTED_BIT;
        }
        if value.is_banned {
            packed = packed | IS_BANNED_BIT;
        }
        packed.into()
    }

    fn unpack(value: felt252) -> TokenState {
        let packed: u128 = value.try_into().unwrap();
        let context_id: u64 = (packed & CONTEXT_ID_MASK).try_into().unwrap();
        let has_submitted = (packed & HAS_SUBMITTED_BIT) != 0;
        let is_banned = (packed & IS_BANNED_BIT) != 0;
        TokenState { context_id, has_submitted, is_banned }
    }
}

/// Extract only context_id from a packed TokenState felt252.
/// Avoids full unpack when only the context lookup is needed.
pub fn unpack_token_context_id(packed: felt252) -> u64 {
    let packed: u128 = packed.try_into().unwrap();
    (packed & CONTEXT_ID_MASK).try_into().unwrap()
}

/// Extract only has_submitted from a packed TokenState felt252.
/// Avoids full unpack when only the flag is needed.
pub fn unpack_token_has_submitted(packed: felt252) -> bool {
    let packed: u128 = packed.try_into().unwrap();
    (packed & HAS_SUBMITTED_BIT) != 0
}

/// Extract only is_banned from a packed TokenState felt252.
/// Avoids full unpack when only the flag is needed.
pub fn unpack_token_is_banned(packed: felt252) -> bool {
    let packed: u128 = packed.try_into().unwrap();
    (packed & IS_BANNED_BIT) != 0
}

// ----------------------------------------------------------------------------
// LastContext: the display-only reverse index, token_id -> context.
//
//   bits  0..63: context_id (u64)
//   bit   64:    is_ambiguous — the id was seen in more than one context
//
// Same shape as TokenState above: a u64 in the low bits, flags on top. The
// ambiguous flag lives outside the u64 range, so no real context_id can be
// mistaken for it.
// ----------------------------------------------------------------------------

const IS_AMBIGUOUS_BIT: u128 = 0x10000000000000000; // bit 64

#[derive(Copy, Drop, Serde, PartialEq)]
pub struct LastContext {
    pub context_id: u64,
    /// Set once the id appears in a second context. Never cleared: ambiguity
    /// is monotonic, so a read surface can only get less certain over time.
    pub is_ambiguous: bool,
}

pub impl LastContextStorePacking of StorePacking<LastContext, felt252> {
    fn pack(value: LastContext) -> felt252 {
        let mut packed: u128 = value.context_id.into();
        if value.is_ambiguous {
            packed = packed | IS_AMBIGUOUS_BIT;
        }
        packed.into()
    }

    fn unpack(value: felt252) -> LastContext {
        let packed: u128 = value.try_into().unwrap();
        LastContext {
            context_id: (packed & CONTEXT_ID_MASK).try_into().unwrap(),
            is_ambiguous: (packed & IS_AMBIGUOUS_BIT) != 0,
        }
    }
}
