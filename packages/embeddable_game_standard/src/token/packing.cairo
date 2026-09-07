// ==============================================================================
// PACKED TOKEN ID - Embeds immutable data directly in the token_id (felt252)
// ==============================================================================
//
// Standard u128-aligned bit layout (251 bits, no field straddles the u128
// boundary). This layout is OWNED by the standard token and is deliberately NOT the
// legacy token's `token_legacy::structs::pack_token_id` layout — the legacy layout serves
// legacy denshokan and keeps its bit positions untouched; the standard token drops
// the fields it never writes and widens the ones it uses beyond the
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
// - FULL UNPACK splits each u128 half ONCE at a field-aligned boundary so that
//   the resulting words fit u64, then extracts every field with cheap u64
//   DivRem:
//   * low splits at bit 60 (start_delay|end_delay boundary): the bottom word
//     (minted_at + start_delay) fits u64; one more u128 DivRem at end_delay
//     brings the 43-bit top (settings_id + minted_by + soulbound) into u64.
//   * high splits at bit 58: metadata (65 bits) is the quotient and stays
//     u128 (it is returned as u128 anyway); the 58-bit remainder word
//     (tx_hash + salt + paymaster + has_context + objective_id) fits u64.
//   Full unpack: 3 u128 + 6 u64 DivRems. Every DivRem there yields two used
//   values, so the chain has no waste and the narrowing amortises across it.
// - SINGLE-FIELD ACCESSORS do NOT narrow. Measured on scarb 2.16.1 /
//   snforge 0.58.1 (see token/tests/bench_packing.cairo), the marginal cost of
//   a u128 -> u64 checked downcast (1,470) plus a u64 DivRem (1,710) exceeds a
//   u128 DivRem (2,180), so narrowing only pays once ~3.6 u64 DivRems follow
//   it. An accessor that extracts one field performs one or two, so it stays
//   in u128 and pays the wider op instead of the downcast.
//   Within u128, `x & MASK` (1,083) is cheaper than DivRem (2,180) and yields
//   the same low bits, so an accessor shifts its field down with ONE DivRem
//   and then trims the field width with a mask, rather than spending a second
//   DivRem whose quotient is discarded. A flag is a bare mask and no DivRem.
//   Two accessors are excluded by measurement, not by principle:
//   `unpack_minted_by` (its u64 return makes the narrowing free, so the u64
//   DivRem beats mask + downcast) and `unpack_soulbound` (a DivRem at bit 127
//   already produces 0/1 directly, so masking adds a comparison against a
//   128-bit constant and costs more). Both keep the narrowing form.
// - `unpack_lifecycle` is the one COMBINED accessor: minted_at, start_delay and
//   end_delay are the bottom 85 bits, and the guard path
//   (`is_lifecycle_open`, `assert_lifecycle_open`) needs all three and
//   nothing else. It narrows —
//   splitting at bit 60 puts minted_at AND start_delay in one u64 word, so a
//   single u64 DivRem yields two fields already in the return type — which is
//   the amortisation the single-field accessors never get.

use game_components_interfaces::structs::token::{Lifecycle, TokenMetadata};

/// Last 10 bits of a transaction hash, for the id's collision-protection
/// field. Layout-independent — it was shared with the legacy token before that
/// generation was retired.
#[inline(always)]
pub fn extract_tx_hash_bits(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    // 0x3FF < 2^128, so the mask only ever touches the low limb: masking
    // `hash_u256.low` is bit-identical to masking the whole u256 and skips the
    // second limb's AND and the u256 -> u16 two-limb check.
    (hash_u256.low & mask::LOW_10).try_into().unwrap()
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

/// NonZero<u128> constants — the per-half word splits of the full unpack, and
/// the single DivRem each accessor uses to shift its field down to bit 0.
mod nz128 {
    pub const TWO_POW_10: NonZero<u128> = 0x400;
    pub const TWO_POW_25: NonZero<u128> = 0x2000000;
    pub const TWO_POW_28: NonZero<u128> = 0x10000000;
    pub const TWO_POW_35: NonZero<u128> = 0x800000000;
    pub const TWO_POW_58: NonZero<u128> = 0x400000000000000;
    pub const TWO_POW_60: NonZero<u128> = 0x1000000000000000;
    pub const TWO_POW_85: NonZero<u128> = 0x2000000000000000000000;
    pub const TWO_POW_101: NonZero<u128> = 0x20000000000000000000000000;
    pub const TWO_POW_127: NonZero<u128> = 0x80000000000000000000000000000000;
}

/// NonZero<u64> constants — the full unpack narrows once per half and then
/// runs its remaining extractions on u64 operands, where the narrowing has
/// enough following DivRems to amortise (see the CODEC note above).
mod nz64 {
    pub const TWO_POW_1: NonZero<u64> = 0x2;
    pub const TWO_POW_10: NonZero<u64> = 0x400;
    pub const TWO_POW_16: NonZero<u64> = 0x10000;
    pub const TWO_POW_26: NonZero<u64> = 0x4000000;
    pub const TWO_POW_35: NonZero<u64> = 0x800000000;
}

/// Field-width masks, applied AFTER a field has been shifted to bit 0, to trim
/// the bits above it. `x & MASK` costs less than the DivRem whose quotient
/// would otherwise be discarded. `BIT_*` are single-bit flag masks used in
/// place of any DivRem at all.
///
/// Each mask is `2^width - 1` for the field it names, so it is derived from the
/// same layout table as the shifts above and cannot drift from it silently:
/// `test_masks_match_layout` asserts every mask against its declared width.
mod mask {
    pub const LOW_10: u128 = 0x3FF; // tx_hash
    pub const LOW_16: u128 = 0xFFFF; // settings_id, salt
    pub const LOW_25: u128 = 0x1FFFFFF; // start_delay, end_delay
    pub const LOW_30: u128 = 0x3FFFFFFF; // objective_id
    pub const LOW_35: u128 = 0x7FFFFFFFF; // minted_at
    pub const BIT_26: u128 = 0x4000000; // paymaster
    pub const BIT_27: u128 = 0x8000000; // has_context
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
    // Already at bit 0 — trim to 35 bits with a mask, no shift needed.
    (packed.low & mask::LOW_35).try_into().unwrap()
}

/// Helper to unpack just start_delay from a token_id
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // Shift bits 35+ down, then trim to start_delay's 25 bits.
    let (rest, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_35);
    (rest & mask::LOW_25).try_into().unwrap()
}

/// Helper to unpack just end_delay from a token_id
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // end_delay sits at bits 60-84: shift to bottom, then trim to 25 bits.
    let (rest, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_60);
    (rest & mask::LOW_25).try_into().unwrap()
}

/// Helper to unpack just settings_id from a token_id
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // Shift bits 85+ down; settings_id is the bottom 16 bits of that.
    let (top, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_85);
    (top & mask::LOW_16).try_into().unwrap()
}

/// Helper to unpack just minted_by from a token_id
///
/// Keeps the narrowing form deliberately: minted_by is returned as u64, so the
/// u128 -> u64 downcast has to happen either way and doing it BEFORE the
/// extraction makes that extraction a u64 op. Measured, this beats both the
/// all-u128 DivRem form and the mask form (18,130 vs 19,883 / 20,080).
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
///
/// The one flag that is NOT a mask: at bit 127 the DivRem quotient is already
/// 0 or 1, whereas `low & 2^127` has to be compared against a 128-bit
/// constant. Measured, the DivRem wins (15,830 vs 16,333).
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
    // Already at bit 0 of the high half — trim to 10 bits with a mask.
    (packed.high & mask::LOW_10).try_into().unwrap()
}

/// Helper to unpack salt from a token_id (client-provided collision protection)
#[inline(always)]
pub fn unpack_salt(token_id: felt252) -> u16 {
    let packed: u256 = token_id.into();
    // Shift tx_hash's 10 bits off, then trim to salt's 16 bits.
    let (rest, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_10);
    (rest & mask::LOW_16).try_into().unwrap()
}

/// Helper to unpack the paymaster flag from a token_id
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    // Single bit — test it in place, no shift and no DivRem.
    (packed.high & mask::BIT_26) != 0
}

/// Helper to unpack the has_context flag from a token_id. The context
/// data itself is NOT stored on the token (legacy-token parity) — only this bit
/// records that context was supplied at mint.
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let packed: u256 = token_id.into();
    // Single bit — test it in place, no shift and no DivRem.
    (packed.high & mask::BIT_27) != 0
}

/// Helper to unpack objective_id from a token_id (inert data the game
/// interprets — the standard token has no completion machinery)
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let packed: u256 = token_id.into();
    // Shift bits 28+ down, then trim to objective_id's 30 bits.
    let (rest, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_28);
    (rest & mask::LOW_30).try_into().unwrap()
}

/// Helper to unpack the 65-bit metadata field from a token_id (inert
/// data the game interprets). Topmost high field — a single quotient.
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u128 {
    let packed: u256 = token_id.into();
    let (metadata, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_58);
    metadata
}

/// Unpacks ONLY the lifecycle window from a token_id.
///
/// `is_lifecycle_open` and the `assert_lifecycle_open` guard need three of the twelve
/// packed fields — minted_at (bits 0-34), start_delay (35-59) and end_delay
/// (60-84), the bottom 85 bits of the low half. Going through
/// `to_token_metadata(unpack_token_id(id))` to reach them decodes all twelve
/// and builds a `TokenMetadata` that is then thrown away.
///
/// The reconstruction is IDENTICAL to `to_token_metadata`'s, sentinel included:
///
///     start = minted_at + start_delay
///     end   = if end_delay > 0 { minted_at + start_delay + end_delay } else { 0 }
///
/// `end_delay == 0` means "no expiration" and must keep producing `end == 0`;
/// `LifecycleTrait::has_expired` reads `end == 0` as never-expires.
///
/// This is the one place the u64 narrowing DOES pay, unlike the single-field
/// accessors: splitting the low half at bit 60 yields a 60-bit word holding
/// minted_at AND start_delay, so a single u64 DivRem produces two fields
/// already in the return type. end_delay is then masked out of the u128
/// remainder rather than costing a second DivRem.
///
/// * `token_id` — any felt252; arbitrary bit patterns are valid input.
///
/// Returns the same `Lifecycle` that
/// `to_token_metadata(unpack_token_id(token_id)).lifecycle` returns, for every
/// input. Cannot overflow: the three fields are bounded by their masks at 35,
/// 25 and 25 bits, so the sum is always below 2^36.
#[inline(always)]
pub fn unpack_lifecycle(token_id: felt252) -> Lifecycle {
    let packed: u256 = token_id.into();
    // Bottom word (bits 0-59) fits u64 and holds two fields; one u64 DivRem
    // separates them.
    let (rest, low_word) = DivRem::div_rem(packed.low, nz128::TWO_POW_60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::TWO_POW_35);
    // end_delay is the bottom 25 bits of what is left above bit 60.
    let end_delay: u64 = (rest & mask::LOW_25).try_into().unwrap();

    let start = minted_at + start_delay;
    // end_delay == 0 is the "no expiration" sentinel and must stay end == 0;
    // LifecycleTrait::has_expired reads end == 0 as never-expires.
    let end = if end_delay > 0 {
        start + end_delay
    } else {
        0
    };
    Lifecycle { start, end }
}

/// Convert PackedTokenId to the shared TokenMetadata struct.
///
/// Every packed field round-trips exactly, `metadata` included — the struct
/// field is 65 bits wide, matching the id layout, so what is read back is
/// what was minted.
///
/// `game_over`, `completed_objective` and `completed_at` are zeroed: the
/// standard token holds no mutable state and the game contract is
/// authoritative, so `completed_objective` stays always-false even when an
/// objective_id is packed. The lifecycle is reconstructed from minted_at +
/// delays: end_delay == 0 means "no expiration" (end == 0).
#[inline(always)]
pub fn to_token_metadata(packed: PackedTokenId) -> TokenMetadata {
    TokenMetadata {
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
        metadata: packed.metadata,
    }
}

#[cfg(test)]
mod layout_invariants {
    use super::mask;

    /// `2^n` built by repeated multiplication, so the expected value is derived
    /// here rather than copied from the constant it is checking.
    ///
    /// * `n` — exponent; must be < 128, or the u128 multiply overflows and
    ///   panics. Every call site passes a literal field width from the layout
    ///   table, all of which are <= 35.
    ///
    /// Returns `2^n` as a u128.
    fn two_pow(n: u32) -> u128 {
        let mut result: u128 = 1;
        let mut i: u32 = 0;
        while i < n {
            result = result * 2;
            i += 1;
        }
        result
    }

    /// Every mask must be exactly `2^width - 1` for the field it trims (and
    /// every flag mask exactly `2^bit`), matching the layout table at the top
    /// of this file. A mask one bit too wide reads a neighbour's low bit; one
    /// bit too narrow silently truncates. Neither shows up in a full-vector
    /// round-trip, so pin them directly.
    #[test]
    fn test_masks_match_layout() {
        assert!(mask::LOW_10 == two_pow(10) - 1, "tx_hash mask is not 10 bits");
        assert!(mask::LOW_16 == two_pow(16) - 1, "settings_id/salt mask is not 16 bits");
        assert!(mask::LOW_25 == two_pow(25) - 1, "start_delay/end_delay mask is not 25 bits");
        assert!(mask::LOW_30 == two_pow(30) - 1, "objective_id mask is not 30 bits");
        assert!(mask::LOW_35 == two_pow(35) - 1, "minted_at mask is not 35 bits");
        assert!(mask::BIT_26 == two_pow(26), "paymaster flag is not bit 26");
        assert!(mask::BIT_27 == two_pow(27), "has_context flag is not bit 27");
    }
}
