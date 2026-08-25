pub use game_components_interfaces::structs::metagame::GameContextDetails;

// Re-export structs from interfaces for backward compatibility
pub use game_components_interfaces::structs::token::{
    Lifecycle, MintBatchRecipient, MintParams, PlayerNameUpdate, TokenFullState, TokenMetadata,
    TokenMutableState,
};
use starknet::storage_access::StorePacking;

/// u128-aligned StorePacking for Lifecycle.
///
/// Bit layout (128 bits total, fits in single u128 — no u256 needed):
///   start(64) | end(64)
///
/// Uses a single DivRem to extract both fields via u128_safe_divmod.
pub impl LifecycleStorePacking of StorePacking<Lifecycle, felt252> {
    fn pack(value: Lifecycle) -> felt252 {
        let packed: u128 = value.start.into() + value.end.into() * 0x10000000000000000_u128;
        packed.into()
    }

    fn unpack(value: felt252) -> Lifecycle {
        let packed: u128 = value.try_into().unwrap();
        let (end, start) = DivRem::div_rem(packed, 0x10000000000000000_u128.try_into().unwrap());
        Lifecycle { start: start.try_into().unwrap(), end: end.try_into().unwrap() }
    }
}

// ==============================================================================
// PACKED TOKEN ID - Embeds immutable data directly in the token_id (felt252)
// ==============================================================================
//
// u128-aligned bit layout (251 bits, no field straddles the u128 boundary):
//
// Low u128 (128 bits):
// | Bits      | Field            | Size     | Max Value                      |
// |-----------|------------------|----------|--------------------------------|
// | 0-29      | game_id          | 30 bits  | 1,073,741,823 games            |
// | 30-69     | minted_by        | 40 bits  | 1,099,511,627,775 minters      |
// | 70-99     | settings_id      | 30 bits  | 1,073,741,823 settings         |
// | 100-124   | start_delay      | 25 bits  | 33,554,431 seconds (~388 days) |
// | 125       | soulbound        | 1 bit    | bool                           |
// | 126       | has_context      | 1 bit    | bool                           |
// | 127       | paymaster        | 1 bit    | bool                           |
//
// High u128 (123 bits):
// | Bits      | Field            | Size     | Max Value                      |
// |-----------|------------------|----------|--------------------------------|
// | 0-34      | minted_at        | 35 bits  | Unix timestamp (~1000 years)   |
// | 35-59     | end_delay        | 25 bits  | 33,554,431 seconds (~388 days) |
// | 60-89     | objective_id     | 30 bits  | 1,073,741,823 objectives       |
// | 90-99     | tx_hash          | 10 bits  | 1,024 unique per second        |
// | 100-109   | salt             | 10 bits  | 1,024 tokens per tx (multicall)|
// | 110-122   | metadata         | 13 bits  | 8,191 (reserved for future)    |
// Total: 128 + 123 = 251 bits (max for felt252)
//
// Max value: (2^123 - 1) * 2^128 + (2^128 - 1) = 2^251 - 1 < P (Stark prime)
//
// BREAKING CHANGE: Field order differs from previous layout. All existing
// packed token IDs will decode incorrectly with this new layout.
//
// COLLISION PROTECTION:
// - tx_hash: Last 10 bits of starknet transaction hash. Since tx_hash includes
//   the sender's nonce (unique per tx), different transactions have different
//   hashes. This protects against same-block collisions.
// - salt: Client-provided value for multicall scenarios. Client must increment
//   salt for each mint within the same transaction to avoid collisions.
//
// All DivRem operations use native u128_safe_divmod Sierra hints for ~64% gas
// savings compared to u256 mask+divide unpacking.

/// Data structure representing the packed token ID fields (for convenience)
#[derive(Copy, Drop, Serde)]
pub struct PackedTokenId {
    pub game_id: u32, // 30 bits
    pub minted_by: u64, // 40 bits
    pub settings_id: u32, // 30 bits
    pub minted_at: u64, // 35 bits
    pub start_delay: u32, // 25 bits
    pub end_delay: u32, // 25 bits
    pub objective_id: u32, // 30 bits
    pub soulbound: bool, // 1 bit
    pub has_context: bool, // 1 bit
    pub paymaster: bool, // 1 bit
    pub tx_hash: u16, // 10 bits - last 10 bits of transaction hash for collision protection
    pub salt: u16, // 10 bits - client-provided salt for multicall collision protection
    pub metadata: u16 // 13 bits - reserved for future use
}

/// StorePacking implementation for TokenMutableState
/// Packs 2 boolean fields + completed_at timestamp into a single felt252
/// Layout: game_over(1) | completed_objective(1) | completed_at(32) = 34 bits
pub impl TokenMutableStateStorePacking of StorePacking<TokenMutableState, felt252> {
    fn pack(value: TokenMutableState) -> felt252 {
        let mut packed: u128 = 0;
        if value.game_over {
            packed = packed | 0x1; // bit 0
        }
        if value.completed_objective {
            packed = packed | 0x2; // bit 1
        }
        packed = packed + Into::<u32, u128>::into(value.completed_at) * 0x4; // shift 2
        packed.into()
    }

    fn unpack(value: felt252) -> TokenMutableState {
        let packed: u128 = value.try_into().unwrap();
        let (hi, flags) = DivRem::div_rem(packed, 0x4); // extract 2 flag bits
        let flags_u8: u8 = flags.try_into().unwrap();
        TokenMutableState {
            game_over: (flags_u8 & 0x1) != 0,
            completed_objective: (flags_u8 & 0x2) != 0,
            completed_at: hi.try_into().unwrap(),
        }
    }
}

/// NonZero<u128> constants for DivRem-based unpacking.
/// Each constant is a power of 2 matching a field width.
/// DivRem extracts field (remainder) and shifts (quotient) in one operation.
mod nz128 {
    pub const TWO_POW_10: NonZero<u128> = 0x400;
    pub const TWO_POW_25: NonZero<u128> = 0x2000000;
    pub const TWO_POW_30: NonZero<u128> = 0x40000000;
    pub const TWO_POW_35: NonZero<u128> = 0x800000000;
    pub const TWO_POW_40: NonZero<u128> = 0x10000000000;
}

/// Packs token metadata into a felt252 token_id using u128-aligned layout.
/// This is a pure function - no storage access needed.
///
/// Low u128: game_id(30) | minted_by(40) | settings_id(30) | start_delay(25)
///           | soulbound(1) | has_context(1) | paymaster(1) = 128 bits
/// High u128: minted_at(35) | end_delay(25) | objective_id(30)
///            | tx_hash(10) | salt(10) | metadata(13) = 123 bits
#[inline(always)]
pub fn pack_token_id(
    game_id: u32,
    minted_by: u64,
    settings_id: u32,
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    objective_id: u32,
    soulbound: bool,
    has_context: bool,
    paymaster: bool,
    tx_hash: u16,
    salt: u16,
    metadata: u16,
) -> felt252 {
    // Validate all fields fit within their bit allocations
    assert!(game_id <= 0x3FFFFFFF, "PackedTokenId: game_id exceeds 30-bit limit");
    assert!(minted_by <= 0xFFFFFFFFFF, "PackedTokenId: minted_by exceeds 40-bit limit");
    assert!(settings_id <= 0x3FFFFFFF, "PackedTokenId: settings_id exceeds 30-bit limit");
    assert!(minted_at <= 0x7FFFFFFFF, "PackedTokenId: minted_at exceeds 35-bit limit");
    assert!(start_delay <= 0x1FFFFFF, "PackedTokenId: start_delay exceeds 25-bit limit");
    assert!(end_delay <= 0x1FFFFFF, "PackedTokenId: end_delay exceeds 25-bit limit");
    assert!(objective_id <= 0x3FFFFFFF, "PackedTokenId: objective_id exceeds 30-bit limit");

    // Low u128: game_id(30) + minted_by(40) + settings_id(30) + start_delay(25)
    //           + soulbound(1) + has_context(1) + paymaster(1) = 128 bits
    let soulbound_u128: u128 = if soulbound {
        1
    } else {
        0
    };
    let has_context_u128: u128 = if has_context {
        1
    } else {
        0
    };
    let paymaster_u128: u128 = if paymaster {
        1
    } else {
        0
    };

    let low: u128 = game_id.into()
        + Into::<u64, u128>::into(minted_by) * 0x40000000_u128 // shift 30
        + Into::<u32, u128>::into(settings_id) * 0x400000000000000000_u128 // shift 70
        + Into::<u32, u128>::into(start_delay) * 0x10000000000000000000000000_u128 // shift 100
        + soulbound_u128 * 0x20000000000000000000000000000000_u128 // shift 125
        + has_context_u128 * 0x40000000000000000000000000000000_u128 // shift 126
        + paymaster_u128 * 0x80000000000000000000000000000000_u128; // shift 127

    // High u128: minted_at(35) + end_delay(25) + objective_id(30)
    //            + tx_hash(10) + salt(10) + metadata(13) = 123 bits
    let high: u128 = Into::<u64, u128>::into(minted_at)
        + Into::<u32, u128>::into(end_delay) * 0x800000000_u128 // shift 35
        + Into::<u32, u128>::into(objective_id) * 0x1000000000000000_u128 // shift 60
        + Into::<u16, u128>::into(tx_hash & 0x3FF) * 0x40000000000000000000000_u128 // shift 90
        + Into::<u16, u128>::into(salt & 0x3FF) * 0x10000000000000000000000000_u128 // shift 100
        + Into::<u16, u128>::into(metadata & 0x1FFF)
            * 0x4000000000000000000000000000_u128; // shift 110

    let packed = u256 { low, high };
    packed.try_into().unwrap()
}

/// Unpacks a token_id into its component fields using DivRem chains on each u128 half.
#[inline(always)]
pub fn unpack_token_id(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();
    let low = packed.low;
    let high = packed.high;

    // Unpack low u128: game_id(30) | minted_by(40) | settings_id(30) | start_delay(25)
    //                  | soulbound(1) | has_context(1) | paymaster(1)
    let (hi, game_id) = DivRem::div_rem(low, nz128::TWO_POW_30);
    let (hi, minted_by) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (hi, settings_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, start_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, soulbound_u128) = DivRem::div_rem(hi, 2);
    let (paymaster_u128, has_context_u128) = DivRem::div_rem(hi, 2);

    // Unpack high u128: minted_at(35) | end_delay(25) | objective_id(30)
    //                   | tx_hash(10) | salt(10) | metadata(13)
    let (hi, minted_at) = DivRem::div_rem(high, nz128::TWO_POW_35);
    let (hi, end_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, objective_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, tx_hash) = DivRem::div_rem(hi, nz128::TWO_POW_10);
    let (metadata, salt) = DivRem::div_rem(hi, nz128::TWO_POW_10);

    PackedTokenId {
        game_id: game_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_at: minted_at.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        objective_id: objective_id.try_into().unwrap(),
        soulbound: soulbound_u128 == 1,
        has_context: has_context_u128 == 1,
        paymaster: paymaster_u128 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        metadata: metadata.try_into().unwrap(),
    }
}

/// Helper to unpack just game_id from token_id (most common lookup)
#[inline(always)]
pub fn unpack_game_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (_, game_id) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    game_id.try_into().unwrap()
}

/// Helper to unpack just minted_by from token_id
#[inline(always)]
pub fn unpack_minted_by(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (_, minted_by) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    minted_by.try_into().unwrap()
}

/// Helper to unpack just settings_id from token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (_, settings_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    settings_id.try_into().unwrap()
}

/// Helper to unpack just minted_at from token_id
#[inline(always)]
pub fn unpack_minted_at(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (_, minted_at) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    minted_at.try_into().unwrap()
}

/// Helper to unpack start_delay from token_id
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (_, start_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    start_delay.try_into().unwrap()
}

/// Helper to unpack end_delay from token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    let (_, end_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    end_delay.try_into().unwrap()
}

/// Helper to unpack objective_id from token_id
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, objective_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    objective_id.try_into().unwrap()
}

/// Helper to unpack soulbound flag from token_id
#[inline(always)]
pub fn unpack_soulbound(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, soulbound_u128) = DivRem::div_rem(hi, 2);
    soulbound_u128 == 1
}

/// Helper to unpack has_context flag from token_id
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, 2); // skip soulbound
    let (_, has_context_u128) = DivRem::div_rem(hi, 2);
    has_context_u128 == 1
}

/// Helper to unpack paymaster flag from token_id
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_40);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, 2); // skip soulbound
    let (paymaster_u128, _) = DivRem::div_rem(hi, 2); // skip has_context
    paymaster_u128 == 1
}

/// Helper to unpack tx_hash from token_id (last 10 bits of transaction hash)
#[inline(always)]
pub fn unpack_tx_hash(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (_, tx_hash) = DivRem::div_rem(hi, nz128::TWO_POW_10);
    tx_hash.try_into().unwrap()
}

/// Helper to unpack salt from token_id (client-provided collision protection)
#[inline(always)]
pub fn unpack_salt(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_10); // skip tx_hash
    let (_, salt) = DivRem::div_rem(hi, nz128::TWO_POW_10);
    salt.try_into().unwrap()
}

/// Helper to unpack metadata from token_id (reserved for future use)
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_10); // skip tx_hash
    let (metadata, _) = DivRem::div_rem(hi, nz128::TWO_POW_10); // skip salt
    metadata.try_into().unwrap()
}

/// Helper to extract the last 10 bits from a transaction hash for use in pack_token_id
#[inline(always)]
pub fn extract_tx_hash_bits(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    (hash_u256 & 0x3FF_u256).try_into().unwrap()
}

/// Convert PackedTokenId + TokenMutableState to TokenMetadata
#[inline(always)]
pub fn to_token_metadata(packed: PackedTokenId, mutable_state: TokenMutableState) -> TokenMetadata {
    TokenMetadata {
        game_id: packed.game_id.into(),
        minted_at: packed.minted_at.into(),
        settings_id: packed.settings_id.into(),
        lifecycle: Lifecycle {
            start: packed.minted_at + packed.start_delay.into(),
            end: if packed.end_delay > 0 {
                packed.minted_at + packed.start_delay.into() + packed.end_delay.into()
            } else {
                0
            },
        },
        minted_by: packed.minted_by.into(),
        soulbound: packed.soulbound,
        game_over: mutable_state.game_over,
        completed_objective: mutable_state.completed_objective,
        completed_at: mutable_state.completed_at,
        has_context: packed.has_context,
        objective_id: packed.objective_id,
        paymaster: packed.paymaster,
        metadata: packed.metadata,
    }
}
