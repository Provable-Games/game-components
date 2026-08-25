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
// CODEC (shared with SDM next-death-mountain's model packing — same method):
// - PACK is pure felt252 arithmetic: a valid token id occupies at most 251
//   bits, so every term and partial sum is below the Stark prime and native
//   felt add/mul is exact — no u128 multiplications, no u256 assembly.
// - UNPACK splits each u128 half ONCE at a field-aligned boundary so that the
//   resulting words fit u64, then extracts every field with cheap u64 DivRem:
//   * low splits at bit 60 (start_delay|end_delay boundary): the bottom word
//     (minted_at + start_delay) fits u64; one more u128 DivRem at end_delay
//     brings the 43-bit top (settings_id + minted_by + soulbound) into u64.
//   * high splits at bit 58: metadata (65 bits) is the quotient and stays
//     u128 (it is returned as u128 anyway); the 58-bit remainder word
//     (tx_hash + salt + paymaster + has_context + objective_id) fits u64.
//   Full unpack: 3 u128 + 6 u64 DivRems (was 10 u128 DivRems).

use game_components_interfaces::structs::token::{Lifecycle, TokenMetadata};

/// Last 10 bits of a transaction hash, for the id's collision-protection
/// field. Layout-independent — it was shared with the legacy token before that
/// generation was retired.
#[inline(always)]
pub fn extract_tx_hash_bits(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    (hash_u256 & 0x3FF_u256).try_into().unwrap()
}

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

/// NonZero<u128> constants — used only for the per-half word splits and the
/// helpers that shift a field to the bottom of a u128 in one DivRem.
mod nz128 {
    pub const TWO_POW_10: NonZero<u128> = 0x400;
    pub const TWO_POW_25: NonZero<u128> = 0x2000000;
    pub const TWO_POW_35: NonZero<u128> = 0x800000000;
    pub const TWO_POW_58: NonZero<u128> = 0x400000000000000;
    pub const TWO_POW_60: NonZero<u128> = 0x1000000000000000;
    pub const TWO_POW_85: NonZero<u128> = 0x2000000000000000000000;
    pub const TWO_POW_101: NonZero<u128> = 0x20000000000000000000000000;
    pub const TWO_POW_127: NonZero<u128> = 0x80000000000000000000000000000000;
}

/// NonZero<u64> constants — every field extraction after the word splits runs
/// on u64 operands (u64 DivRem is markedly cheaper than u128 DivRem).
mod nz64 {
    pub const TWO_POW_1: NonZero<u64> = 0x2;
    pub const TWO_POW_10: NonZero<u64> = 0x400;
    pub const TWO_POW_16: NonZero<u64> = 0x10000;
    pub const TWO_POW_26: NonZero<u64> = 0x4000000;
    pub const TWO_POW_27: NonZero<u64> = 0x8000000;
    pub const TWO_POW_28: NonZero<u64> = 0x10000000;
    pub const TWO_POW_35: NonZero<u64> = 0x800000000;
}

/// felt252 shift constants for the pure-felt pack. Low-half fields shift by
/// their bit offset; high-half fields shift by their offset WITHIN the high
/// word and the assembled high word shifts by SHIFT_128 at the end.
mod felt_shift {
    // Low half offsets
    pub const SHIFT_35: felt252 = 0x800000000; // start_delay
    pub const SHIFT_60: felt252 = 0x1000000000000000; // end_delay
    pub const SHIFT_85: felt252 = 0x2000000000000000000000; // settings_id
    pub const SHIFT_101: felt252 = 0x20000000000000000000000000; // minted_by
    pub const SHIFT_127: felt252 = 0x80000000000000000000000000000000; // soulbound
    // High half offsets (within the high word)
    pub const SHIFT_10: felt252 = 0x400; // salt
    pub const SHIFT_26: felt252 = 0x4000000; // paymaster
    pub const SHIFT_27: felt252 = 0x8000000; // has_context
    pub const SHIFT_28: felt252 = 0x10000000; // objective_id
    pub const SHIFT_58: felt252 = 0x400000000000000; // metadata
    // Low/high boundary
    pub const SHIFT_128: felt252 = 0x100000000000000000000000000000000;
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

    // Pure felt252 packing (SDM method): the asserts above bound every field,
    // so the total occupies at most 251 bits and every term and partial sum
    // is below the Stark field prime — native felt arithmetic is exact.
    let soulbound_f: felt252 = if soulbound {
        1
    } else {
        0
    };
    let paymaster_f: felt252 = if paymaster {
        1
    } else {
        0
    };
    let has_context_f: felt252 = if has_context {
        1
    } else {
        0
    };

    // Low u128: minted_at(35) + start_delay(25) + end_delay(25) + settings_id(16)
    //           + minted_by(26) + soulbound(1) = 128 bits
    let low: felt252 = minted_at.into()
        + start_delay.into() * felt_shift::SHIFT_35
        + end_delay.into() * felt_shift::SHIFT_60
        + settings_id.into() * felt_shift::SHIFT_85
        + minted_by.into() * felt_shift::SHIFT_101
        + soulbound_f * felt_shift::SHIFT_127;

    // High u128: tx_hash(10) + salt(16) + paymaster(1) + has_context(1)
    //            + objective_id(30) + metadata(65) = 123 bits — fully
    //            allocated, no reserved region. salt is a u16 written into a
    //            16-bit field, so unlike the legacy token's 10-bit salt it
    //            needs no mask.
    let high: felt252 = Into::<u16, felt252>::into(tx_hash & 0x3FF)
        + salt.into() * felt_shift::SHIFT_10
        + paymaster_f * felt_shift::SHIFT_26
        + has_context_f * felt_shift::SHIFT_27
        + objective_id.into() * felt_shift::SHIFT_28
        + metadata.into() * felt_shift::SHIFT_58;

    low + high * felt_shift::SHIFT_128
}

/// Unpacks a token_id into its component fields (SDM word-split method):
/// each u128 half is split once at a field-aligned boundary so the resulting
/// words fit u64, and every field extraction runs as a cheap u64 DivRem.
#[inline(always)]
pub fn unpack_token_id(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();

    // Low half — split at bit 60 (the start_delay|end_delay boundary): the
    // bottom word (minted_at + start_delay, 60 bits) fits u64; one more u128
    // DivRem peels end_delay and leaves a 43-bit top word
    // (settings_id + minted_by + soulbound) that also fits u64.
    let (low_rest, low_word) = DivRem::div_rem(packed.low, nz128::TWO_POW_60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::TWO_POW_35);
    let (low_top, end_delay) = DivRem::div_rem(low_rest, nz128::TWO_POW_25);
    let low_top: u64 = low_top.try_into().unwrap();
    let (rest, settings_id) = DivRem::div_rem(low_top, nz64::TWO_POW_16);
    let (soulbound_u64, minted_by) = DivRem::div_rem(rest, nz64::TWO_POW_26);

    // High half — split at bit 58: metadata (65 bits) is the quotient and
    // stays u128; the 58-bit remainder word
    // (tx_hash + salt + paymaster + has_context + objective_id) fits u64.
    let (metadata, high_word) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (rest, tx_hash) = DivRem::div_rem(high_word, nz64::TWO_POW_10);
    let (rest, salt) = DivRem::div_rem(rest, nz64::TWO_POW_16);
    let (rest, paymaster_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (objective_id, has_context_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);

    PackedTokenId {
        minted_at,
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        minted_by,
        soulbound: soulbound_u64 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        salt: salt.try_into().unwrap(),
        paymaster: paymaster_u64 == 1,
        has_context: has_context_u64 == 1,
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
    // Bottom word (60 bits) fits u64; start_delay is its quotient at bit 35.
    let (_, low_word) = DivRem::div_rem(packed.low, nz128::TWO_POW_60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, _) = DivRem::div_rem(low_word, nz64::TWO_POW_35);
    start_delay.try_into().unwrap()
}

/// Helper to unpack just end_delay from a token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // end_delay sits at bits 60-84: shift to bottom, then take 25 bits.
    let (rest, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_60);
    let (_, end_delay) = DivRem::div_rem(rest, nz128::TWO_POW_25);
    end_delay.try_into().unwrap()
}

/// Helper to unpack just settings_id from a token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // Everything above bit 85 is 43 bits — fits u64; settings_id is its
    // bottom 16 bits.
    let (top, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_85);
    let top: u64 = top.try_into().unwrap();
    let (_, settings_id) = DivRem::div_rem(top, nz64::TWO_POW_16);
    settings_id.try_into().unwrap()
}

/// Helper to unpack just minted_by from a token_id
#[inline(always)]
pub fn unpack_minted_by(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    // Everything above bit 101 is 27 bits — fits u64; minted_by is its
    // bottom 26 bits.
    let (top, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_101);
    let top: u64 = top.try_into().unwrap();
    let (_, minted_by) = DivRem::div_rem(top, nz64::TWO_POW_26);
    minted_by
}

/// Helper to unpack the soulbound flag from a token_id
#[inline(always)]
pub fn unpack_soulbound(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    // soulbound is the top bit of the low half — a single quotient.
    let (soulbound_u128, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_127);
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
    // The 58-bit high word fits u64; salt sits above tx_hash's 10 bits.
    let (_, high_word) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (rest, _) = DivRem::div_rem(high_word, nz64::TWO_POW_10);
    let (_, salt) = DivRem::div_rem(rest, nz64::TWO_POW_16);
    salt.try_into().unwrap()
}

/// Helper to unpack the paymaster flag from a token_id
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (_, high_word) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (rest, _) = DivRem::div_rem(high_word, nz64::TWO_POW_26);
    let (_, paymaster_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    paymaster_u64 == 1
}

/// Helper to unpack the has_context flag from a token_id. The context
/// data itself is NOT stored on the token (legacy-token parity) — only this bit
/// records that context was supplied at mint.
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    let (_, high_word) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (rest, _) = DivRem::div_rem(high_word, nz64::TWO_POW_27);
    let (_, has_context_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    has_context_u64 == 1
}

/// Helper to unpack objective_id from a token_id (inert data the game
/// interprets — the standard token has no completion machinery)
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // objective_id is the top field of the 58-bit high word — a quotient.
    let (_, high_word) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    let high_word: u64 = high_word.try_into().unwrap();
    let (objective_id, _) = DivRem::div_rem(high_word, nz64::TWO_POW_28);
    objective_id.try_into().unwrap()
}

/// Helper to unpack the 65-bit metadata field from a token_id (inert
/// data the game interprets). Topmost high field — a single quotient.
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u128 {
    let packed: u256 = token_id.into();
    let (metadata, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
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
