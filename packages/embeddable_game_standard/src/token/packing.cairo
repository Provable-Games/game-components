// ==============================================================================
// PACKED TOKEN ID — schema v1. Embeds immutable mint data in the id (felt252).
// ==============================================================================
//
// The token id is a felt252. Decode it as a u256 and treat `low` and `high`
// as two u128 halves. Bit numbers below are relative to their half. No field
// straddles the u128 boundary. This layout is OWNED by the standard token;
// the retired registry generation (`v2.0.0` and earlier) used a different
// layout, and indexers must branch their decoder by contract generation —
// `schema_version` (low bits 0-4) identifies this one.
//
// Low u128 (bits 0-127, fully allocated). "Zero" is what a zero value means.
// | Bits    | Field                  | W  | Type | Meaning                        | Zero          |
// |---------|------------------------|----|------|--------------------------------|---------------|
// | 0-4     | schema_version         | 5  | u8   | layout version; this writes 1  | never written |
// | 5       | has_context            | 1  | bool | context supplied (not stored)  | no context    |
// | 6       | soulbound              | 1  | bool | non-transferable               | transferable  |
// | 7       | paymaster              | 1  | bool | mint was sponsored             | not sponsored |
// | 8-23    | tx_hash                | 16 | u16  | low 16 bits of mint tx hash    | n/a           |
// | 24-31   | tx_nonce               | 8  | u8   | 0 for mint; position in batch  | single/first  |
// | 32-63   | minted_at_block_number | 32 | u32  | block number at mint           | n/a           |
// | 64-90   | minted_at_timestamp    | 27 | u32  | mint block timestamp, floored  | n/a           |
// |         |                        |    |      | to whole minutes since epoch   |               |
// | 91-108  | start_delay            | 18 | u32  | minutes after minted_at_ts     | playable at   |
// |         |                        |    |      | when play may begin            | mint          |
// | 109-127 | end_delay              | 19 | u32  | minutes after start when the   | never expires |
// |         |                        |    |      | token expires                  |               |
//
// High u128 (bits 0-122 used; bits 123-127 must be zero so the id stays
// below the Stark prime):
// | Bits   | Field        | W  | Type | Meaning                                 | Zero         |
// |--------|--------------|----|------|-----------------------------------------|--------------|
// | 0-19   | settings_id  | 20 | u32  | game-interpreted                        | no settings  |
// | 20-39  | objective_id | 20 | u32  | game-interpreted                        | no objective |
// | 40-63  | minted_by    | 24 | u32  | minter registry id (add_minter), from 1 | n/a          |
// | 64-122 | metadata     | 59 | u128 | minter-writable, uninterpreted; no      | no metadata  |
// |        |              |    |      | built-in on- or off-chain reader        |              |
//
// Maximum values: schema_version 31, tx_hash 65,535, tx_nonce 255, block
// 4,294,967,295, minted_at_timestamp 134,217,727, start_delay 262,143,
// end_delay 524,287, settings_id and objective_id 1,048,575, minted_by
// 16,777,215, metadata 2^59 - 1. `pack_token_id` asserts every ceiling
// (tx_hash, tx_nonce and the block number are bounded by their types).
//
// TIME SEMANTICS (the public `Lifecycle` stays in u64 seconds):
// - minted_at_timestamp = block_timestamp / 60 (floor).
// - Requested start (seconds, 0 = now) is clamped:
//   effective_start = max(start, block_timestamp).
// - start_delay = ceil_div(effective_start - minted_at_timestamp * 60, 60).
// - reconstructed_start = (minted_at_timestamp + start_delay) * 60.
// - Requested end (seconds, 0 = never): a non-zero end must satisfy
//   end > block_timestamp and end > effective_start.
//   end_delay = 0 when end == 0; 1 when end <= reconstructed_start (the
//   start's own round-up overtook a sub-minute window); otherwise
//   ceil_div(end - reconstructed_start, 60). So a non-zero requested end
//   always yields end_delay >= 1 — a sub-minute window never collapses into
//   an immortal token.
// - reconstructed_end = (minted_at_timestamp + start_delay + end_delay) * 60,
//   or 0 when end_delay == 0.
// - Reconstructed times are never earlier than requested. minted_at and
//   start are at most 59 seconds later than requested; end is at most 59
//   seconds later unless the window is shorter than the start's round-up
//   (end <= reconstructed_start), in which case end = reconstructed_start +
//   60. `TokenMetadata.minted_at` equals minted_at_timestamp * 60.
//
// TX_NONCE SEMANTICS:
// tx_nonce is never a parameter of any public or internal mint function.
// `mint` packs 0. `mint_batch_recipients` numbers its tokens 0, 1, 2, …
// across all recipients (every other field is shared by the batch), and
// rejects more than 256 tokens up front. Nothing consults storage to pick a
// nonce: uniqueness within a transaction comes from the tx hash bits plus
// this position, so several tokens in one transaction must go through
// `mint_batch_recipients`. Two mints with identical fields in one
// transaction, or in one block with the same low 16 tx-hash bits, produce
// the same id and the second one reverts in the ERC721 mint.
//
// CODEC:
// - PACK is pure felt252 arithmetic: a valid id occupies at most 251 bits,
//   so every term and partial sum is below the Stark prime and native felt
//   add/mul is exact — no u128 multiplications, no u256 assembly.
// - UNPACK splits each u128 half ONCE at bit 64 so the resulting words fit
//   u64, then extracts every field with cheap u64 DivRem:
//   * low splits into low_bottom (version, flags, tx_hash, tx_nonce, block)
//     and low_top (timestamp, start_delay, end_delay);
//   * high splits into high_bottom (settings, objective, minted_by) and the
//     metadata quotient (59 bits, returned as u128).
//   Full unpack: 2 u128 + 10 u64 DivRems.

use game_components_interfaces::structs::token::{Lifecycle, TokenMetadata};

/// The layout version this codec writes into low bits 0-4.
pub const SCHEMA_VERSION: u8 = 1;

/// Low 16 bits of a transaction hash, for the id's collision-protection
/// field.
#[inline(always)]
pub fn extract_tx_hash_bits(tx_hash: felt252) -> u16 {
    let hash_u256: u256 = tx_hash.into();
    (hash_u256 & 0xFFFF_u256).try_into().unwrap()
}

/// The packed token id fields, in layout order.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct PackedTokenId {
    pub schema_version: u8, // 5 bits
    pub has_context: bool, // 1 bit — the context data itself is NOT stored
    pub soulbound: bool, // 1 bit
    pub paymaster: bool, // 1 bit
    pub tx_hash: u16, // 16 bits — low 16 bits of the mint tx hash
    pub tx_nonce: u8, // 8 bits — 0 for mint, position in the batch for batch mints
    pub minted_at_block_number: u32, // 32 bits
    pub minted_at_timestamp: u32, // 27 bits — whole minutes since the Unix epoch
    pub start_delay: u32, // 18 bits — minutes after minted_at_timestamp
    pub end_delay: u32, // 19 bits — minutes after start; 0 = never expires
    pub settings_id: u32, // 20 bits
    pub objective_id: u32, // 20 bits
    pub minted_by: u32, // 24 bits — minter registry id
    pub metadata: u128 // 59 bits — minter-writable, uninterpreted
}

/// Block number and minute-floored timestamp captured at mint.
#[derive(Copy, Drop, Serde, PartialEq, Debug)]
pub struct MintContext {
    pub minted_at_block_number: u32,
    pub minted_at_timestamp: u32,
}

/// NonZero<u128> constants — used only for the per-half word splits.
mod nz128 {
    pub const TWO_POW_64: NonZero<u128> = 0x10000000000000000;
}

/// NonZero<u64> constants — every field extraction after the word splits runs
/// on u64 operands (u64 DivRem is markedly cheaper than u128 DivRem).
mod nz64 {
    pub const TWO_POW_1: NonZero<u64> = 0x2;
    pub const TWO_POW_5: NonZero<u64> = 0x20;
    pub const TWO_POW_8: NonZero<u64> = 0x100;
    pub const TWO_POW_16: NonZero<u64> = 0x10000;
    pub const TWO_POW_18: NonZero<u64> = 0x40000;
    pub const TWO_POW_20: NonZero<u64> = 0x100000;
    pub const TWO_POW_24: NonZero<u64> = 0x1000000;
    pub const TWO_POW_27: NonZero<u64> = 0x8000000;
    pub const TWO_POW_32: NonZero<u64> = 0x100000000;
    pub const TWO_POW_40: NonZero<u64> = 0x10000000000;
}

/// felt252 shift constants for the pure-felt pack. Low-half fields shift by
/// their bit offset; high-half fields shift by their offset WITHIN the high
/// word and the assembled high word shifts by SHIFT_128 at the end.
mod felt_shift {
    // Low half offsets
    pub const SHIFT_5: felt252 = 0x20; // has_context
    pub const SHIFT_6: felt252 = 0x40; // soulbound
    pub const SHIFT_7: felt252 = 0x80; // paymaster
    pub const SHIFT_8: felt252 = 0x100; // tx_hash
    pub const SHIFT_24: felt252 = 0x1000000; // tx_nonce
    pub const SHIFT_32: felt252 = 0x100000000; // minted_at_block_number
    pub const SHIFT_64: felt252 = 0x10000000000000000; // minted_at_timestamp / metadata
    pub const SHIFT_91: felt252 = 0x80000000000000000000000; // start_delay
    pub const SHIFT_109: felt252 = 0x2000000000000000000000000000; // end_delay
    // High half offsets (within the high word); metadata reuses SHIFT_64
    pub const SHIFT_20: felt252 = 0x100000; // objective_id
    pub const SHIFT_40: felt252 = 0x10000000000; // minted_by
    // Low/high boundary
    pub const SHIFT_128: felt252 = 0x100000000000000000000000000000000;
}

#[inline(always)]
fn bool_felt(b: bool) -> felt252 {
    if b {
        1
    } else {
        0
    }
}

/// Packs the fields into a felt252 token id (schema v1). Pure function.
///
/// Asserts every field ceiling from the layout table. `schema_version` is
/// only required to fit 5 bits (tests pack other versions); the component
/// always writes `SCHEMA_VERSION`.
#[inline(always)]
pub fn pack_token_id(fields: PackedTokenId) -> felt252 {
    // tx_hash (u16), tx_nonce (u8) and minted_at_block_number (u32) are
    // bounded by their types; every other field is narrower than its type.
    assert!(fields.schema_version <= 0x1F, "PackedTokenId: schema_version exceeds 5-bit limit");
    assert!(
        fields.minted_at_timestamp <= 0x7FFFFFF,
        "PackedTokenId: minted_at_timestamp exceeds 27-bit limit",
    );
    assert!(fields.start_delay <= 0x3FFFF, "PackedTokenId: start_delay exceeds 18-bit limit");
    assert!(fields.end_delay <= 0x7FFFF, "PackedTokenId: end_delay exceeds 19-bit limit");
    assert!(fields.settings_id <= 0xFFFFF, "PackedTokenId: settings_id exceeds 20-bit limit");
    assert!(fields.objective_id <= 0xFFFFF, "PackedTokenId: objective_id exceeds 20-bit limit");
    assert!(fields.minted_by <= 0xFFFFFF, "PackedTokenId: minted_by exceeds 24-bit limit");
    assert!(fields.metadata <= 0x7FFFFFFFFFFFFFF, "PackedTokenId: metadata exceeds 59-bit limit");

    // Pure felt252 packing: the asserts above bound every field, so the total
    // occupies at most 251 bits and every term and partial sum is below the
    // Stark field prime — native felt arithmetic is exact.
    let low: felt252 = fields.schema_version.into()
        + bool_felt(fields.has_context) * felt_shift::SHIFT_5
        + bool_felt(fields.soulbound) * felt_shift::SHIFT_6
        + bool_felt(fields.paymaster) * felt_shift::SHIFT_7
        + fields.tx_hash.into() * felt_shift::SHIFT_8
        + fields.tx_nonce.into() * felt_shift::SHIFT_24
        + fields.minted_at_block_number.into() * felt_shift::SHIFT_32
        + fields.minted_at_timestamp.into() * felt_shift::SHIFT_64
        + fields.start_delay.into() * felt_shift::SHIFT_91
        + fields.end_delay.into() * felt_shift::SHIFT_109;

    let high: felt252 = fields.settings_id.into()
        + fields.objective_id.into() * felt_shift::SHIFT_20
        + fields.minted_by.into() * felt_shift::SHIFT_40
        + fields.metadata.into() * felt_shift::SHIFT_64;

    low + high * felt_shift::SHIFT_128
}

/// Unpacks a token id into its fields: each u128 half is split once at bit
/// 64 so the resulting words fit u64, and every field extraction runs as a
/// cheap u64 DivRem.
#[inline(always)]
pub fn unpack_token_id(token_id: felt252) -> PackedTokenId {
    let packed: u256 = token_id.into();

    // Low half: low_bottom = version | flags | tx_hash | tx_nonce | block,
    // low_top = minted_at_timestamp | start_delay | end_delay.
    let (low_top, low_bottom) = DivRem::div_rem(packed.low, nz128::TWO_POW_64);
    let low_bottom: u64 = low_bottom.try_into().unwrap();
    let low_top: u64 = low_top.try_into().unwrap();
    let (rest, schema_version) = DivRem::div_rem(low_bottom, nz64::TWO_POW_5);
    let (rest, has_context_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (rest, soulbound_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (rest, paymaster_u64) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (rest, tx_hash) = DivRem::div_rem(rest, nz64::TWO_POW_16);
    let (minted_at_block_number, tx_nonce) = DivRem::div_rem(rest, nz64::TWO_POW_8);
    let (rest, minted_at_timestamp) = DivRem::div_rem(low_top, nz64::TWO_POW_27);
    let (end_delay, start_delay) = DivRem::div_rem(rest, nz64::TWO_POW_18);

    // High half: high_bottom = settings_id | objective_id | minted_by, and
    // metadata is the quotient (stays u128 — it is returned as u128 anyway).
    let (metadata, high_bottom) = DivRem::div_rem(packed.high, nz128::TWO_POW_64);
    let high_bottom: u64 = high_bottom.try_into().unwrap();
    let (rest, settings_id) = DivRem::div_rem(high_bottom, nz64::TWO_POW_20);
    let (minted_by, objective_id) = DivRem::div_rem(rest, nz64::TWO_POW_20);

    PackedTokenId {
        schema_version: schema_version.try_into().unwrap(),
        has_context: has_context_u64 == 1,
        soulbound: soulbound_u64 == 1,
        paymaster: paymaster_u64 == 1,
        tx_hash: tx_hash.try_into().unwrap(),
        tx_nonce: tx_nonce.try_into().unwrap(),
        minted_at_block_number: minted_at_block_number.try_into().unwrap(),
        minted_at_timestamp: minted_at_timestamp.try_into().unwrap(),
        start_delay: start_delay.try_into().unwrap(),
        end_delay: end_delay.try_into().unwrap(),
        settings_id: settings_id.try_into().unwrap(),
        objective_id: objective_id.try_into().unwrap(),
        minted_by: minted_by.try_into().unwrap(),
        metadata,
    }
}

// ------------------------------------------------------------------------------
// Word accessors — one u128 DivRem each; every single-field decoder below
// reaches its word with exactly one of these and finishes with u64 DivRems.
// ------------------------------------------------------------------------------

/// Low bits 0-63: version | has_context | soulbound | paymaster | tx_hash |
/// tx_nonce | minted_at_block_number.
#[inline(always)]
fn low_bottom_word(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (_, word) = DivRem::div_rem(packed.low, nz128::TWO_POW_64);
    word.try_into().unwrap()
}

/// Low bits 64-127: minted_at_timestamp | start_delay | end_delay.
#[inline(always)]
fn low_top_word(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (word, _) = DivRem::div_rem(packed.low, nz128::TWO_POW_64);
    word.try_into().unwrap()
}

/// High bits 0-63: settings_id | objective_id | minted_by.
#[inline(always)]
fn high_bottom_word(token_id: felt252) -> u64 {
    let packed: u256 = token_id.into();
    let (_, word) = DivRem::div_rem(packed.high, nz128::TWO_POW_64);
    word.try_into().unwrap()
}

/// Low bits 0-4.
#[inline(always)]
pub fn unpack_schema_version(token_id: felt252) -> u8 {
    let (_, version) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_5);
    version.try_into().unwrap()
}

/// Low bit 5. The context data itself is NOT stored on the token — only
/// this bit records that a context was supplied at mint.
#[inline(always)]
pub fn unpack_has_context(token_id: felt252) -> bool {
    let (rest, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_5);
    let (_, bit) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    bit == 1
}

/// Low bit 6.
#[inline(always)]
pub fn unpack_soulbound(token_id: felt252) -> bool {
    let (rest, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_5);
    let (rest, _) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (_, bit) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    bit == 1
}

/// Low bit 7.
#[inline(always)]
pub fn unpack_paymaster(token_id: felt252) -> bool {
    let (rest, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_5);
    let (rest, _) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (rest, _) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    let (_, bit) = DivRem::div_rem(rest, nz64::TWO_POW_1);
    bit == 1
}

/// Low bits 8-23: low 16 bits of the mint transaction hash.
#[inline(always)]
pub fn unpack_tx_hash(token_id: felt252) -> u16 {
    let (rest, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_8);
    let (_, tx_hash) = DivRem::div_rem(rest, nz64::TWO_POW_16);
    tx_hash.try_into().unwrap()
}

/// Low bits 24-31: 0 for `mint`, the token's position for a batch mint.
#[inline(always)]
pub fn unpack_tx_nonce(token_id: felt252) -> u8 {
    let (rest, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_24);
    let (_, tx_nonce) = DivRem::div_rem(rest, nz64::TWO_POW_8);
    tx_nonce.try_into().unwrap()
}

/// Low bits 32-63.
#[inline(always)]
pub fn unpack_minted_at_block_number(token_id: felt252) -> u32 {
    let (block_number, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_32);
    block_number.try_into().unwrap()
}

/// Low bits 64-90: whole minutes since the Unix epoch.
#[inline(always)]
pub fn unpack_minted_at_timestamp(token_id: felt252) -> u32 {
    let (_, minted_at_timestamp) = DivRem::div_rem(low_top_word(token_id), nz64::TWO_POW_27);
    minted_at_timestamp.try_into().unwrap()
}

/// Low bits 91-108: minutes after minted_at_timestamp.
#[inline(always)]
pub fn unpack_start_delay(token_id: felt252) -> u32 {
    let (rest, _) = DivRem::div_rem(low_top_word(token_id), nz64::TWO_POW_27);
    let (_, start_delay) = DivRem::div_rem(rest, nz64::TWO_POW_18);
    start_delay.try_into().unwrap()
}

/// Low bits 109-127: minutes after start; 0 = never expires.
#[inline(always)]
pub fn unpack_end_delay(token_id: felt252) -> u32 {
    let (rest, _) = DivRem::div_rem(low_top_word(token_id), nz64::TWO_POW_27);
    let (end_delay, _) = DivRem::div_rem(rest, nz64::TWO_POW_18);
    end_delay.try_into().unwrap()
}

/// High bits 0-19.
#[inline(always)]
pub fn unpack_settings_id(token_id: felt252) -> u32 {
    let (_, settings_id) = DivRem::div_rem(high_bottom_word(token_id), nz64::TWO_POW_20);
    settings_id.try_into().unwrap()
}

/// High bits 20-39: inert data the game interprets.
#[inline(always)]
pub fn unpack_objective_id(token_id: felt252) -> u32 {
    let (rest, _) = DivRem::div_rem(high_bottom_word(token_id), nz64::TWO_POW_20);
    let (_, objective_id) = DivRem::div_rem(rest, nz64::TWO_POW_20);
    objective_id.try_into().unwrap()
}

/// High bits 40-63: the minter registry id.
#[inline(always)]
pub fn unpack_minted_by(token_id: felt252) -> u32 {
    let (minted_by, _) = DivRem::div_rem(high_bottom_word(token_id), nz64::TWO_POW_40);
    minted_by.try_into().unwrap()
}

/// High bits 64-122: the 59-bit minter-writable metadata. Topmost high
/// field — a single quotient.
#[inline(always)]
pub fn unpack_metadata(token_id: felt252) -> u128 {
    let packed: u256 = token_id.into();
    let (metadata, _) = DivRem::div_rem(packed.high, nz128::TWO_POW_64);
    metadata
}

/// Block number and minute-floored timestamp at mint.
#[inline(always)]
pub fn unpack_mint_context(token_id: felt252) -> MintContext {
    let (block_number, _) = DivRem::div_rem(low_bottom_word(token_id), nz64::TWO_POW_32);
    let (_, minted_at_timestamp) = DivRem::div_rem(low_top_word(token_id), nz64::TWO_POW_27);
    MintContext {
        minted_at_block_number: block_number.try_into().unwrap(),
        minted_at_timestamp: minted_at_timestamp.try_into().unwrap(),
    }
}

/// Decode only the lifecycle (in seconds). Hot path for
/// `assert_lifecycle_open`: one u128 DivRem plus two u64 DivRems. The
/// minute-to-second reconstruction runs in felt252 (exact: the operands are
/// at most 28 bits, the products at most 35) so it costs one range-checked
/// conversion per value instead of checked u64 adds and multiplies.
#[inline(always)]
pub fn unpack_lifecycle(token_id: felt252) -> Lifecycle {
    let (rest, minted_at_timestamp) = DivRem::div_rem(low_top_word(token_id), nz64::TWO_POW_27);
    let (end_delay, start_delay) = DivRem::div_rem(rest, nz64::TWO_POW_18);
    let start_f: felt252 = (minted_at_timestamp.into() + start_delay.into()) * 60;
    let start: u64 = start_f.try_into().unwrap();
    Lifecycle {
        start,
        end: if end_delay == 0 {
            0
        } else {
            let end_f: felt252 = start_f + end_delay.into() * 60;
            end_f.try_into().unwrap()
        },
    }
}

// ------------------------------------------------------------------------------
// Pure time helpers (seconds <-> whole minutes), used by the component and
// exposed for fuzzing.
// ------------------------------------------------------------------------------

/// `seconds / 60`, floored. Panics if the minute count does not fit u32.
#[inline(always)]
pub fn minutes_floor(seconds: u64) -> u32 {
    (seconds / 60).try_into().expect('minutes_floor: overflow')
}

/// `ceil((to_seconds - from_seconds) / 60)`. Asserts `to >= from`. Panics if
/// the minute count does not fit u32.
#[inline(always)]
pub fn minutes_ceil_delay(from_seconds: u64, to_seconds: u64) -> u32 {
    assert!(to_seconds >= from_seconds, "minutes_ceil_delay: to precedes from");
    ((to_seconds - from_seconds + 59) / 60).try_into().expect('minutes_ceil_delay: overflow')
}

/// `m * 60`.
#[inline(always)]
pub fn minutes_to_seconds(m: u64) -> u64 {
    m * 60
}

/// Convert PackedTokenId to the shared TokenMetadata struct (seconds).
///
/// `game_over`, `completed_objective` and `completed_at` are zeroed: the
/// standard token holds no mutable state and the game contract is
/// authoritative, so `completed_objective` stays always-false even when an
/// objective_id is packed. The lifecycle is reconstructed from the
/// minute-floored mint time plus the minute delays: end_delay == 0 means
/// "no expiration" (end == 0).
#[inline(always)]
pub fn to_token_metadata(packed: PackedTokenId) -> TokenMetadata {
    let minted_at = minutes_to_seconds(packed.minted_at_timestamp.into());
    let start = minted_at + minutes_to_seconds(packed.start_delay.into());
    let end = if packed.end_delay > 0 {
        start + minutes_to_seconds(packed.end_delay.into())
    } else {
        0
    };
    TokenMetadata {
        minted_at,
        minted_at_block_number: packed.minted_at_block_number,
        schema_version: packed.schema_version,
        settings_id: packed.settings_id,
        lifecycle: Lifecycle { start, end },
        minted_by: packed.minted_by.into(),
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
