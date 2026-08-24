// ==============================================================================
// LITE PACKED TOKEN ID - Embeds immutable data directly in the token_id (felt252)
// ==============================================================================
//
// Lite-native u128-aligned bit layout (251 bits, no field straddles the u128
// boundary). This layout is OWNED by the lite token and is deliberately NOT the
// full token's `token::structs::pack_token_id` layout — the full layout serves
// legacy denshokan and keeps its bit positions untouched; the lite token drops
// the fields it never writes (game_id, objective_id, has_context, paymaster,
// metadata) and widens the ones it actually uses (settings_id, salt).
// Indexers must branch their decoder by contract generation.
//
// Low u128 (128 bits):
// | Bits      | Field            | Size     | Max Value                      |
// |-----------|------------------|----------|--------------------------------|
// | 0-34      | minted_at        | 35 bits  | Unix timestamp (~1000 years)   |
// | 35-59     | start_delay      | 25 bits  | 33,554,431 seconds (~388 days) |
// | 60-84     | end_delay        | 25 bits  | 33,554,431 seconds (~388 days) |
// | 85-100    | settings_id      | 16 bits  | 65,535 settings                |
// | 101-126   | minted_by        | 26 bits  | 67,108,863 minters             |
// | 127       | soulbound        | 1 bit    | bool                           |
//
// High u128 (123 bits):
// | Bits      | Field            | Size     | Max Value                      |
// |-----------|------------------|----------|--------------------------------|
// | 0-9       | tx_hash          | 10 bits  | last 10 bits of tx hash        |
// | 10-25     | salt             | 16 bits  | 65,536 tokens per tx (multicall)|
// | 26-122    | reserved         | 97 bits  | component-owned, ALWAYS zero   |
// Total: 128 + 123 = 251 bits (max for felt252)
//
// Max value: (2^123 - 1) * 2^128 + (2^128 - 1) = 2^251 - 1 < P (Stark prime)
//
// RESERVED REGION CONTRACT: bits [26-122] of the high half are owned by the
// component and are ALWAYS packed as zero — there is no pack parameter and no
// public unpack accessor for them. Future fields (protocol- or game-facing)
// are carved from this region later; because every id minted under this layout
// provably decodes the region as 0, any future field decodes as 0 ("absent")
// on all existing ids, making such carve-outs non-breaking by construction.
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

use game_components_interfaces::structs::token::{Lifecycle, TokenMetadata};
// Shared with the full token: extracting the last 10 bits of the tx hash is
// layout-independent.
pub use crate::token::structs::extract_tx_hash_bits;

/// Data structure representing the lite packed token ID fields (for convenience).
/// The reserved region (high bits 26-122) is deliberately absent — it is
/// component-owned, always zero, and has no accessor.
#[derive(Copy, Drop, Serde)]
pub struct LitePackedTokenId {
    pub minted_at: u64, // 35 bits
    pub start_delay: u32, // 25 bits
    pub end_delay: u32, // 25 bits
    pub settings_id: u32, // 16 bits
    pub minted_by: u64, // 26 bits
    pub soulbound: bool, // 1 bit
    pub tx_hash: u16, // 10 bits - last 10 bits of transaction hash for collision protection
    pub salt: u16 // 16 bits - client-provided salt for multicall collision protection
}

/// NonZero<u128> constants for DivRem-based unpacking.
/// Each constant is a power of 2 matching a field width.
/// DivRem extracts field (remainder) and shifts (quotient) in one operation.
mod nz128 {
    pub const TWO_POW_10: NonZero<u128> = 0x400;
    pub const TWO_POW_16: NonZero<u128> = 0x10000;
    pub const TWO_POW_25: NonZero<u128> = 0x2000000;
    pub const TWO_POW_26: NonZero<u128> = 0x4000000;
    pub const TWO_POW_35: NonZero<u128> = 0x800000000;
}

/// Packs lite token metadata into a felt252 token_id using the lite-native
/// u128-aligned layout. This is a pure function - no storage access needed.
///
/// Low u128: minted_at(35) | start_delay(25) | end_delay(25) | settings_id(16)
///           | minted_by(26) | soulbound(1) = 128 bits
/// High u128: tx_hash(10) | salt(16) | reserved(97, always zero) = 123 bits
#[inline(always)]
pub fn pack_lite_token_id(
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    settings_id: u32,
    minted_by: u64,
    soulbound: bool,
    tx_hash: u16,
    salt: u16,
) -> felt252 {
    // Validate all fields fit within their bit allocations
    assert!(minted_at <= 0x7FFFFFFFF, "LitePackedTokenId: minted_at exceeds 35-bit limit");
    assert!(start_delay <= 0x1FFFFFF, "LitePackedTokenId: start_delay exceeds 25-bit limit");
    assert!(end_delay <= 0x1FFFFFF, "LitePackedTokenId: end_delay exceeds 25-bit limit");
    assert!(settings_id <= 0xFFFF, "LitePackedTokenId: settings_id exceeds 16-bit limit");
    assert!(minted_by <= 0x3FFFFFF, "LitePackedTokenId: minted_by exceeds 26-bit limit");

    // Low u128: minted_at(35) + start_delay(25) + end_delay(25) + settings_id(16)
    //           + minted_by(26) + soulbound(1) = 128 bits
    let soulbound_u128: u128 = if soulbound {
        1
    } else {
        0
    };

    let low: u128 = Into::<u64, u128>::into(minted_at)
        + Into::<u32, u128>::into(start_delay) * 0x800000000_u128 // shift 35
        + Into::<u32, u128>::into(end_delay) * 0x1000000000000000_u128 // shift 60
        + Into::<u32, u128>::into(settings_id) * 0x2000000000000000000000_u128 // shift 85
        + Into::<u64, u128>::into(minted_by) * 0x20000000000000000000000000_u128 // shift 101
        + soulbound_u128 * 0x80000000000000000000000000000000_u128; // shift 127

    // High u128: tx_hash(10) + salt(16) = 26 bits; bits 26-122 (reserved) are
    // never written — always zero. salt is a u16 written into a 16-bit field,
    // so unlike the full token's 10-bit salt it needs no mask.
    let high: u128 = Into::<u16, u128>::into(tx_hash & 0x3FF)
        + Into::<u16, u128>::into(salt) * 0x400_u128; // shift 10

    let packed = u256 { low, high };
    packed.try_into().unwrap()
}

/// Unpacks a lite token_id into its component fields using DivRem chains on each
/// u128 half. The reserved region (high quotient past salt) is discarded.
#[inline(always)]
pub fn unpack_lite_token_id(token_id: felt252) -> LitePackedTokenId {
    let packed: u256 = token_id.into();
    let low = packed.low;
    let high = packed.high;

    // Unpack low u128: minted_at(35) | start_delay(25) | end_delay(25)
    //                  | settings_id(16) | minted_by(26) | soulbound(1)
    let (hi, minted_at) = DivRem::div_rem(low, nz128::TWO_POW_35);
    let (hi, start_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, end_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, settings_id) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (soulbound_u128, minted_by) = DivRem::div_rem(hi, nz128::TWO_POW_26);

    // Unpack high u128: tx_hash(10) | salt(16) | reserved(97, dropped)
    let (hi, tx_hash) = DivRem::div_rem(high, nz128::TWO_POW_10);
    let (_, salt) = DivRem::div_rem(hi, nz128::TWO_POW_16);

    LitePackedTokenId {
        minted_at: minted_at.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        soulbound: soulbound_u128 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
    }
}

/// Helper to unpack just minted_at from a lite token_id
#[inline(always)]
pub fn unpack_minted_at(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (_, minted_at) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    minted_at.try_into().unwrap()
}

/// Helper to unpack just start_delay from a lite token_id
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (_, start_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    start_delay.try_into().unwrap()
}

/// Helper to unpack just end_delay from a lite token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, end_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    end_delay.try_into().unwrap()
}

/// Helper to unpack just settings_id from a lite token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, settings_id) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    settings_id.try_into().unwrap()
}

/// Helper to unpack just minted_by from a lite token_id
#[inline(always)]
pub fn unpack_minted_by(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (_, minted_by) = DivRem::div_rem(hi, nz128::TWO_POW_26);
    minted_by.try_into().unwrap()
}

/// Helper to unpack the soulbound flag from a lite token_id
#[inline(always)]
pub fn unpack_soulbound(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (soulbound_u128, _) = DivRem::div_rem(hi, nz128::TWO_POW_26);
    soulbound_u128 == 1
}

/// Helper to unpack tx_hash from a lite token_id (last 10 bits of transaction hash)
#[inline(always)]
pub fn unpack_tx_hash(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (_, tx_hash) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    tx_hash.try_into().unwrap()
}

/// Helper to unpack salt from a lite token_id (client-provided collision protection)
#[inline(always)]
pub fn unpack_salt(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (_, salt) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    salt.try_into().unwrap()
}

/// Convert LitePackedTokenId to the shared TokenMetadata struct.
///
/// The lite token has no mutable state and never writes the full token's
/// extension fields, so `game_id`, `objective_id`, `has_context`, `paymaster`,
/// `metadata`, `game_over`, `completed_objective` and `completed_at` are all
/// zeroed. The lifecycle is reconstructed from minted_at + delays with the same
/// rule as the full token: end_delay == 0 means "no expiration" (end == 0).
#[inline(always)]
pub fn to_token_metadata(packed: LitePackedTokenId) -> TokenMetadata {
    TokenMetadata {
        game_id: 0,
        minted_at: packed.minted_at,
        settings_id: packed.settings_id,
        lifecycle: Lifecycle {
            start: packed.minted_at + packed.start_delay.into(),
            end: if packed.end_delay > 0 {
                packed.minted_at + packed.start_delay.into() + packed.end_delay.into()
            } else {
                0
            },
        },
        minted_by: packed.minted_by,
        soulbound: packed.soulbound,
        game_over: false,
        completed_objective: false,
        completed_at: 0,
        has_context: false,
        objective_id: 0,
        paymaster: false,
        metadata: 0,
    }
}
