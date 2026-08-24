// ==============================================================================
// PACKED TOKEN ID - Embeds immutable data directly in the token_id (felt252)
// ==============================================================================
//
// Standard u128-aligned bit layout (251 bits, no field straddles the u128
// boundary). This layout is OWNED by the standard token and is deliberately NOT the
// legacy token's `token_legacy::structs::pack_token_id` layout — the legacy layout serves
// legacy denshokan and keeps its bit positions untouched; the standard token drops
// the fields it never writes (game_id) and widens the ones it uses beyond the
// legacy token's widths (settings_id 16, salt 16, metadata 65).
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
// | 26        | paymaster        | 1 bit    | bool                           |
// | 27        | has_context      | 1 bit    | bool                           |
// | 28-57     | objective_id     | 30 bits  | 1,073,741,823 objectives       |
// | 58-122    | metadata         | 65 bits  | game-interpreted inert data    |
// Total: 128 + 123 = 251 bits (max for felt252)
//
// Max value: (2^123 - 1) * 2^128 + (2^128 - 1) = 2^251 - 1 < P (Stark prime)
//
// The high half is fully allocated — there is no reserved region: every spare
// bit was merged into the single writable `metadata` field, in line with the
// original layout's single-field design. A future protocol-owned field would
// require a new contract generation (accepted trade-off).
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
// Shared with the legacy token: extracting the last 10 bits of the tx hash is
// layout-independent.
pub use crate::token_legacy::structs::extract_tx_hash_bits;

/// Data structure representing the packed token ID fields (for convenience).
#[derive(Copy, Drop, Serde)]
pub struct PackedTokenId {
    pub minted_at: u64, // 35 bits
    pub start_delay: u32, // 25 bits
    pub end_delay: u32, // 25 bits
    pub settings_id: u32, // 16 bits
    pub minted_by: u64, // 26 bits
    pub soulbound: bool, // 1 bit
    pub tx_hash: u16, // 10 bits - last 10 bits of transaction hash for collision protection
    pub salt: u16, // 16 bits - client-provided salt for multicall collision protection
    pub paymaster: bool, // 1 bit
    pub has_context: bool, // 1 bit - context data itself is NOT stored (legacy-token parity)
    pub objective_id: u32, // 30 bits - inert data the game interprets
    pub metadata: u128 // 65 bits - inert data the game interprets
}

/// NonZero<u128> constants for DivRem-based unpacking.
/// Each constant is a power of 2 matching a field width.
/// DivRem extracts field (remainder) and shifts (quotient) in one operation.
mod nz128 {
    pub const TWO_POW_1: NonZero<u128> = 0x2;
    pub const TWO_POW_10: NonZero<u128> = 0x400;
    pub const TWO_POW_16: NonZero<u128> = 0x10000;
    pub const TWO_POW_25: NonZero<u128> = 0x2000000;
    pub const TWO_POW_26: NonZero<u128> = 0x4000000;
    pub const TWO_POW_30: NonZero<u128> = 0x40000000;
    pub const TWO_POW_35: NonZero<u128> = 0x800000000;
}

/// Packs token metadata into a felt252 token_id using the standard
/// u128-aligned layout. This is a pure function - no storage access needed.
///
/// Low u128: minted_at(35) | start_delay(25) | end_delay(25) | settings_id(16)
///           | minted_by(26) | soulbound(1) = 128 bits
/// High u128: tx_hash(10) | salt(16) | paymaster(1) | has_context(1)
///            | objective_id(30) | metadata(65) = 123 bits (fully allocated)
#[inline(always)]
pub fn pack_token_id(
    minted_at: u64,
    start_delay: u32,
    end_delay: u32,
    settings_id: u32,
    minted_by: u64,
    soulbound: bool,
    tx_hash: u16,
    salt: u16,
    paymaster: bool,
    has_context: bool,
    objective_id: u32,
    metadata: u128,
) -> felt252 {
    // Validate all fields fit within their bit allocations
    assert!(minted_at <= 0x7FFFFFFFF, "PackedTokenId: minted_at exceeds 35-bit limit");
    assert!(start_delay <= 0x1FFFFFF, "PackedTokenId: start_delay exceeds 25-bit limit");
    assert!(end_delay <= 0x1FFFFFF, "PackedTokenId: end_delay exceeds 25-bit limit");
    assert!(settings_id <= 0xFFFF, "PackedTokenId: settings_id exceeds 16-bit limit");
    assert!(minted_by <= 0x3FFFFFF, "PackedTokenId: minted_by exceeds 26-bit limit");
    assert!(objective_id <= 0x3FFFFFFF, "PackedTokenId: objective_id exceeds 30-bit limit");
    assert!(metadata <= 0x1FFFFFFFFFFFFFFFF, "PackedTokenId: metadata exceeds 65-bit limit");

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

    // High u128: tx_hash(10) + salt(16) + paymaster(1) + has_context(1)
    //            + objective_id(30) + metadata(65) = 123 bits — fully
    //            allocated, no reserved region. salt is a u16 written into a
    //            16-bit field, so unlike the legacy token's 10-bit salt it
    //            needs no mask.
    let paymaster_u128: u128 = if paymaster {
        1
    } else {
        0
    };
    let has_context_u128: u128 = if has_context {
        1
    } else {
        0
    };

    let high: u128 = Into::<u16, u128>::into(tx_hash & 0x3FF)
        + Into::<u16, u128>::into(salt) * 0x400_u128 // shift 10
        + paymaster_u128 * 0x4000000_u128 // shift 26
        + has_context_u128 * 0x8000000_u128 // shift 27
        + Into::<u32, u128>::into(objective_id) * 0x10000000_u128 // shift 28
        + metadata * 0x400000000000000_u128; // shift 58

    let packed = u256 { low, high };
    packed.try_into().unwrap()
}

/// Unpacks a token_id into its component fields using DivRem chains on
/// each u128 half. metadata is the topmost high field, so it falls out as the
/// final quotient.
#[inline(always)]
pub fn unpack_token_id(token_id: felt252) -> PackedTokenId {
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

    // Unpack high u128: tx_hash(10) | salt(16) | paymaster(1) | has_context(1)
    //                   | objective_id(30) | metadata(65, final quotient)
    let (hi, tx_hash) = DivRem::div_rem(high, nz128::TWO_POW_10);
    let (hi, salt) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (hi, paymaster_u128) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (hi, has_context_u128) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (metadata, objective_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);

    PackedTokenId {
        minted_at: minted_at.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        soulbound: soulbound_u128 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: paymaster_u128 == 1,
        has_context: has_context_u128 == 1,
        objective_id: objective_id.try_into().unwrap(),
        metadata,
    }
}

/// Helper to unpack just minted_at from a token_id
#[inline(always)]
pub fn unpack_minted_at(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (_, minted_at) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    minted_at.try_into().unwrap()
}

/// Helper to unpack just start_delay from a token_id
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (_, start_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    start_delay.try_into().unwrap()
}

/// Helper to unpack just end_delay from a token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, end_delay) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    end_delay.try_into().unwrap()
}

/// Helper to unpack just settings_id from a token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_25);
    let (_, settings_id) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    settings_id.try_into().unwrap()
}

/// Helper to unpack just minted_by from a token_id
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

/// Helper to unpack the soulbound flag from a token_id
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

/// Helper to unpack tx_hash from a token_id (last 10 bits of transaction hash)
#[inline(always)]
pub fn unpack_tx_hash(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (_, tx_hash) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    tx_hash.try_into().unwrap()
}

/// Helper to unpack salt from a token_id (client-provided collision protection)
#[inline(always)]
pub fn unpack_salt(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (_, salt) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    salt.try_into().unwrap()
}

/// Helper to unpack the paymaster flag from a token_id
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (_, paymaster_u128) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    paymaster_u128 == 1
}

/// Helper to unpack the has_context flag from a token_id. The context
/// data itself is NOT stored on the token (legacy-token parity) — only this bit
/// records that context was supplied at mint.
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (_, has_context_u128) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    has_context_u128 == 1
}

/// Helper to unpack objective_id from a token_id (inert data the game
/// interprets — the standard token has no completion machinery)
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (_, objective_id) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    objective_id.try_into().unwrap()
}

/// Helper to unpack the 65-bit metadata field from a token_id (inert
/// data the game interprets). Topmost high field — the final quotient.
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u128 {
    let packed: u256 = token_id.into();
    let (hi, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_16);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (hi, _) = DivRem::div_rem(hi, nz128::TWO_POW_1);
    let (metadata, _) = DivRem::div_rem(hi, nz128::TWO_POW_30);
    metadata
}

/// Convert PackedTokenId to the shared TokenMetadata struct.
///
/// The standard token has no mutable state and never resolves a game id, so
/// `game_id`, `game_over`, `completed_objective` and `completed_at` are all
/// zeroed (the game contract is authoritative — `completed_objective` stays
/// always-false even when an objective_id is packed). The lifecycle is
/// reconstructed from minted_at + delays with the same rule as the legacy
/// token: end_delay == 0 means "no expiration" (end == 0).
///
/// `metadata` is 0 here, NOT a truncation of the packed value: the shared
/// struct's `metadata` field is `u16` (the deployed legacy token's ABI, which
/// cannot change), while the id packs 65 bits. Read the real value via
/// `IMinigameToken::mint_metadata` / `unpack_metadata`.
#[inline(always)]
pub fn to_token_metadata(packed: PackedTokenId) -> TokenMetadata {
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
        has_context: packed.has_context,
        objective_id: packed.objective_id,
        paymaster: packed.paymaster,
        metadata: 0,
    }
}
