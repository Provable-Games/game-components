// Pure codec tests for token id schema v1: round trips, field ceilings, the
// prime bound, and the minute-granularity time semantics. Nothing here
// deploys a contract — the component-level behaviour (collision counter,
// batch cap, views) lives in test_token.cairo.
use crate::token::packing::{
    MintContext, PackedTokenId, SCHEMA_VERSION, extract_tx_hash_bits, minutes_ceil_delay,
    minutes_floor, minutes_to_seconds, pack_token_id, to_token_metadata, unpack_end_delay,
    unpack_has_context, unpack_lifecycle, unpack_metadata, unpack_mint_context,
    unpack_minted_at_block_number, unpack_minted_at_timestamp, unpack_minted_by,
    unpack_objective_id, unpack_paymaster, unpack_schema_version, unpack_settings_id,
    unpack_soulbound, unpack_start_delay, unpack_token_id, unpack_tx_hash, unpack_tx_nonce,
};

const MAX_SCHEMA_VERSION: u8 = 0x1F;
const MAX_MINTED_AT_TIMESTAMP: u32 = 0x7FFFFFF;
const MAX_START_DELAY: u32 = 0x3FFFF;
const MAX_END_DELAY: u32 = 0x7FFFF;
const MAX_SETTINGS_ID: u32 = 0xFFFFF;
const MAX_OBJECTIVE_ID: u32 = 0xFFFFF;
const MAX_MINTED_BY: u32 = 0xFFFFFF;
const MAX_METADATA: u128 = 0x7FFFFFFFFFFFFFF;

/// Every field at its ceiling.
fn all_max() -> PackedTokenId {
    PackedTokenId {
        schema_version: MAX_SCHEMA_VERSION,
        has_context: true,
        soulbound: true,
        paymaster: true,
        tx_hash: 0xFFFF,
        tx_nonce: 0xFF,
        minted_at_block_number: 0xFFFFFFFF,
        minted_at_timestamp: MAX_MINTED_AT_TIMESTAMP,
        start_delay: MAX_START_DELAY,
        end_delay: MAX_END_DELAY,
        settings_id: MAX_SETTINGS_ID,
        objective_id: MAX_OBJECTIVE_ID,
        minted_by: MAX_MINTED_BY,
        metadata: MAX_METADATA,
    }
}

/// Every field at zero (schema_version 0 is "never written" but packs).
fn all_zero() -> PackedTokenId {
    PackedTokenId {
        schema_version: 0,
        has_context: false,
        soulbound: false,
        paymaster: false,
        tx_hash: 0,
        tx_nonce: 0,
        minted_at_block_number: 0,
        minted_at_timestamp: 0,
        start_delay: 0,
        end_delay: 0,
        settings_id: 0,
        objective_id: 0,
        minted_by: 0,
        metadata: 0,
    }
}

fn assert_single_field_decoders_agree(id: felt252, expected: PackedTokenId) {
    assert!(unpack_schema_version(id) == expected.schema_version, "schema_version decoder");
    assert!(unpack_has_context(id) == expected.has_context, "has_context decoder");
    assert!(unpack_soulbound(id) == expected.soulbound, "soulbound decoder");
    assert!(unpack_paymaster(id) == expected.paymaster, "paymaster decoder");
    assert!(unpack_tx_hash(id) == expected.tx_hash, "tx_hash decoder");
    assert!(unpack_tx_nonce(id) == expected.tx_nonce, "tx_nonce decoder");
    assert!(
        unpack_minted_at_block_number(id) == expected.minted_at_block_number,
        "minted_at_block_number decoder",
    );
    assert!(
        unpack_minted_at_timestamp(id) == expected.minted_at_timestamp,
        "minted_at_timestamp decoder",
    );
    assert!(unpack_start_delay(id) == expected.start_delay, "start_delay decoder");
    assert!(unpack_end_delay(id) == expected.end_delay, "end_delay decoder");
    assert!(unpack_settings_id(id) == expected.settings_id, "settings_id decoder");
    assert!(unpack_objective_id(id) == expected.objective_id, "objective_id decoder");
    assert!(unpack_minted_by(id) == expected.minted_by, "minted_by decoder");
    assert!(unpack_metadata(id) == expected.metadata, "metadata decoder");
    assert!(
        unpack_mint_context(
            id,
        ) == MintContext {
            minted_at_block_number: expected.minted_at_block_number,
            minted_at_timestamp: expected.minted_at_timestamp,
        },
        "mint_context decoder",
    );
}

// ================================================================================================
// ROUND TRIP
// ================================================================================================

/// Every field fuzzed within its range: pack, unpack, whole-struct equality,
/// and every single-field decoder agrees with the full decode.
#[test]
#[fuzzer(runs: 64)]
fn test_fuzz_round_trip(
    schema_version: u8,
    flags: u8,
    tx_hash: u16,
    tx_nonce: u8,
    minted_at_block_number: u32,
    minted_at_timestamp: u32,
    start_delay: u32,
    end_delay: u32,
    settings_id: u32,
    objective_id: u32,
    minted_by: u32,
    metadata: u128,
) {
    let fields = PackedTokenId {
        schema_version: schema_version % (MAX_SCHEMA_VERSION + 1),
        has_context: flags % 2 == 1,
        soulbound: (flags / 2) % 2 == 1,
        paymaster: (flags / 4) % 2 == 1,
        tx_hash,
        tx_nonce,
        minted_at_block_number,
        minted_at_timestamp: minted_at_timestamp % (MAX_MINTED_AT_TIMESTAMP + 1),
        start_delay: start_delay % (MAX_START_DELAY + 1),
        end_delay: end_delay % (MAX_END_DELAY + 1),
        settings_id: settings_id % (MAX_SETTINGS_ID + 1),
        objective_id: objective_id % (MAX_OBJECTIVE_ID + 1),
        minted_by: minted_by % (MAX_MINTED_BY + 1),
        metadata: metadata % (MAX_METADATA + 1),
    };
    let id = pack_token_id(fields);
    let decoded = unpack_token_id(id);
    assert!(decoded == fields, "round trip must reproduce every field");
    assert_single_field_decoders_agree(id, fields);
}

#[test]
fn test_round_trip_all_zero_and_all_max() {
    let zero_id = pack_token_id(all_zero());
    assert!(zero_id == 0, "all-zero fields pack to id 0");
    assert!(unpack_token_id(zero_id) == all_zero(), "all-zero round trip");
    assert_single_field_decoders_agree(zero_id, all_zero());

    let max_id = pack_token_id(all_max());
    assert!(unpack_token_id(max_id) == all_max(), "all-max round trip");
    assert_single_field_decoders_agree(max_id, all_max());
}

// ================================================================================================
// PRIME BOUND / RAW LAYOUT
// ================================================================================================

/// The all-max id uses low bits 0-127 and high bits 0-122 exactly:
/// 2^251 - 1 as a u256, below the Stark prime, and it round-trips.
#[test]
fn test_all_max_id_is_below_the_stark_prime() {
    let id = pack_token_id(all_max());
    let raw: u256 = id.into();
    assert!(raw.low == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "low half fully set");
    assert!(raw.high == 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "high bits 0-122 set, 123-127 clear");
    // felt252 -> u256 -> felt252 is lossless only below the prime.
    let back: felt252 = raw.try_into().expect('above the prime');
    assert!(back == id, "id survives the u256 round trip");
    assert!(unpack_token_id(id) == all_max(), "decodes after the round trip");
}

/// schema_version is the raw low 5 bits of the id.
#[test]
#[fuzzer(runs: 32)]
fn test_fuzz_schema_version_is_low_five_bits(version: u8, metadata: u128) {
    let mut fields = all_max();
    fields.schema_version = version % (MAX_SCHEMA_VERSION + 1);
    fields.metadata = metadata % (MAX_METADATA + 1);
    let id = pack_token_id(fields);
    let raw: u256 = id.into();
    let low_five: u8 = (raw.low & 31).try_into().unwrap();
    assert!(low_five == fields.schema_version, "raw mask must equal schema_version");
    assert!(unpack_schema_version(id) == low_five, "decoder agrees with the raw mask");
}

/// Hand-packed layout check: every field's bit offset matches the table.
#[test]
fn test_layout_bit_positions_exact() {
    let fields = PackedTokenId {
        schema_version: 1,
        has_context: true,
        soulbound: true,
        paymaster: true,
        tx_hash: 0xCDEF,
        tx_nonce: 0xAB,
        minted_at_block_number: 0xDEADBEEF,
        minted_at_timestamp: 0x7ABCDEF,
        start_delay: 0x3ABCD,
        end_delay: 0x7ABCD,
        settings_id: 0xABCDE,
        objective_id: 0x1ABCD,
        minted_by: 0xFEDCBA,
        metadata: 0x123456789ABCD,
    };
    let expected_low: u128 = 1
        + 0x20 // has_context << 5
        + 0x40 // soulbound << 6
        + 0x80 // paymaster << 7
        + 0xCDEF * 0x100 // tx_hash << 8
        + 0xAB * 0x1000000 // tx_nonce << 24
        + 0xDEADBEEF * 0x100000000 // block << 32
        + 0x7ABCDEF * 0x10000000000000000 // minted_at_timestamp << 64
        + 0x3ABCD * 0x80000000000000000000000 // start_delay << 91
        + 0x7ABCD * 0x2000000000000000000000000000; // end_delay << 109
    let expected_high: u128 = 0xABCDE
        + 0x1ABCD * 0x100000 // objective_id << 20
        + 0xFEDCBA * 0x10000000000 // minted_by << 40
        + 0x123456789ABCD * 0x10000000000000000; // metadata << 64
    let expected: felt252 = u256 { low: expected_low, high: expected_high }.try_into().unwrap();
    assert!(pack_token_id(fields) == expected, "bit positions must match the documented table");
}

#[test]
fn test_extract_tx_hash_bits_keeps_low_16() {
    assert!(extract_tx_hash_bits(0x123456789abcdef) == 0xcdef, "low 16 bits of the hash");
    assert!(extract_tx_hash_bits(0xFFFF) == 0xFFFF, "16 ones");
    assert!(extract_tx_hash_bits(0x10000) == 0, "bit 16 is dropped");
}

// ================================================================================================
// FIELD CEILINGS — max packs, max + 1 panics with the field's message
// ================================================================================================

#[test]
#[should_panic(expected: "PackedTokenId: schema_version exceeds 5-bit limit")]
fn test_schema_version_over_5_bits_panics() {
    let mut fields = all_max();
    fields.schema_version = MAX_SCHEMA_VERSION + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: minted_at_timestamp exceeds 27-bit limit")]
fn test_minted_at_timestamp_over_27_bits_panics() {
    let mut fields = all_max();
    fields.minted_at_timestamp = MAX_MINTED_AT_TIMESTAMP + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: start_delay exceeds 18-bit limit")]
fn test_start_delay_over_18_bits_panics() {
    let mut fields = all_max();
    fields.start_delay = MAX_START_DELAY + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: end_delay exceeds 19-bit limit")]
fn test_end_delay_over_19_bits_panics() {
    let mut fields = all_max();
    fields.end_delay = MAX_END_DELAY + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: settings_id exceeds 20-bit limit")]
fn test_settings_id_over_20_bits_panics() {
    let mut fields = all_max();
    fields.settings_id = MAX_SETTINGS_ID + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: objective_id exceeds 20-bit limit")]
fn test_objective_id_over_20_bits_panics() {
    let mut fields = all_max();
    fields.objective_id = MAX_OBJECTIVE_ID + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: minted_by exceeds 24-bit limit")]
fn test_minted_by_over_24_bits_panics() {
    let mut fields = all_max();
    fields.minted_by = MAX_MINTED_BY + 1;
    pack_token_id(fields);
}

#[test]
#[should_panic(expected: "PackedTokenId: metadata exceeds 59-bit limit")]
fn test_metadata_over_59_bits_panics() {
    let mut fields = all_max();
    fields.metadata = MAX_METADATA + 1;
    pack_token_id(fields);
}

// ================================================================================================
// TIME SEMANTICS
// ================================================================================================

/// The component's projection of a requested window onto the id's minute
/// fields (mirrors `MinigameTokenComponent::mint_fields`). Returns
/// (minted_at_timestamp, start_delay, end_delay).
fn project(now: u64, start: u64, end: u64) -> (u32, u32, u32) {
    let effective_start = if start > now {
        start
    } else {
        now
    };
    let minted_at_timestamp = minutes_floor(now);
    let minted_at_seconds = minutes_to_seconds(minted_at_timestamp.into());
    let start_delay = minutes_ceil_delay(minted_at_seconds, effective_start);
    let reconstructed_start = minted_at_seconds + minutes_to_seconds(start_delay.into());
    let end_delay = if end == 0 {
        0
    } else if end <= reconstructed_start {
        1
    } else {
        minutes_ceil_delay(reconstructed_start, end)
    };
    (minted_at_timestamp, start_delay, end_delay)
}

fn pack_window(minted_at_timestamp: u32, start_delay: u32, end_delay: u32) -> felt252 {
    let mut fields = all_zero();
    fields.schema_version = SCHEMA_VERSION;
    fields.minted_at_timestamp = minted_at_timestamp;
    fields.start_delay = start_delay;
    fields.end_delay = end_delay;
    pack_token_id(fields)
}

#[test]
fn test_minutes_helpers() {
    assert!(minutes_floor(0) == 0, "floor 0");
    assert!(minutes_floor(59) == 0, "floor 59");
    assert!(minutes_floor(60) == 1, "floor 60");
    assert!(minutes_floor(1_000_000_059) == 16_666_667, "floor example");
    assert!(minutes_ceil_delay(0, 0) == 0, "ceil 0");
    assert!(minutes_ceil_delay(0, 1) == 1, "ceil 1");
    assert!(minutes_ceil_delay(0, 60) == 1, "ceil 60");
    assert!(minutes_ceil_delay(0, 61) == 2, "ceil 61");
    assert!(minutes_ceil_delay(1_000_000_020, 1_000_000_061) == 1, "ceil example");
    assert!(minutes_to_seconds(16_666_667) == 1_000_000_020, "to seconds");
}

#[test]
#[should_panic(expected: "minutes_ceil_delay: to precedes from")]
fn test_minutes_ceil_delay_rejects_reversed_range() {
    minutes_ceil_delay(61, 60);
}

/// Mint at 1_000_000_059: minted_at_timestamp == 16_666_667 and the
/// reconstructed minted_at == 1_000_000_020.
#[test]
fn test_time_floor_example() {
    let (ts, start_delay, end_delay) = project(1_000_000_059, 0, 0);
    assert!(ts == 16_666_667, "timestamp floors");
    assert!(start_delay == 1 && end_delay == 0, "start clamps to now, ceils; no end");
    let md = to_token_metadata(unpack_token_id(pack_window(ts, start_delay, end_delay)));
    assert!(md.minted_at == 1_000_000_020, "minted_at reconstructs to the floored minute");
    assert!(md.lifecycle.start == 1_000_000_080, "start is the next whole minute");
    assert!(md.lifecycle.end == 0, "immortal");
}

/// Mint at 1_000_000_059 with start 1_000_000_061: start_delay == 1 and
/// start reconstructs to 1_000_000_080; with end 1_000_000_062, end_delay
/// == 1.
#[test]
fn test_delay_ceil_example() {
    let (ts, start_delay, end_delay) = project(1_000_000_059, 1_000_000_061, 1_000_000_062);
    assert!(start_delay == 1, "start_delay ceils to 1");
    assert!(end_delay == 1, "end_delay ceils to 1");
    let lifecycle = unpack_lifecycle(pack_window(ts, start_delay, end_delay));
    assert!(lifecycle.start == 1_000_000_080, "reconstructed start");
    assert!(lifecycle.end == 1_000_000_140, "reconstructed end");
}

/// A sub-minute end never becomes immortal: for any now and any end in
/// now+1..now+59, end_delay >= 1.
#[test]
#[fuzzer(runs: 64)]
fn test_fuzz_sub_minute_end_never_immortal(now_raw: u32, offset_raw: u8) {
    let now: u64 = now_raw.into();
    let offset: u64 = (offset_raw % 59).into() + 1;
    let end = now + offset;
    let (ts, start_delay, end_delay) = project(now, 0, end);
    assert!(end_delay >= 1, "non-zero requested end must yield end_delay >= 1");
    let lifecycle = unpack_lifecycle(pack_window(ts, start_delay, end_delay));
    assert!(lifecycle.end != 0, "reconstructed end must not be immortal");
    assert!(lifecycle.end >= end, "reconstructed end never earlier than requested");
}

/// Reconstructed start and end are never earlier than requested and at
/// most 59 seconds later.
#[test]
#[fuzzer(runs: 64)]
fn test_fuzz_reconstruction_never_earlier_at_most_59_later(
    now_raw: u32, start_offset: u16, end_offset: u16,
) {
    let now: u64 = now_raw.into();
    let start = now + start_offset.into();
    let end = start + end_offset.into() + 1;
    let (ts, start_delay, end_delay) = project(now, start, end);
    let lifecycle = unpack_lifecycle(pack_window(ts, start_delay, end_delay));
    let minted_at = minutes_to_seconds(ts.into());
    assert!(minted_at <= now && now - minted_at <= 59, "minted_at floors within a minute");
    assert!(lifecycle.start >= start, "start never earlier than requested");
    assert!(lifecycle.start - start <= 59, "start at most 59 s later");
    assert!(lifecycle.end >= end, "end never earlier than requested");
    if end > lifecycle.start {
        assert!(lifecycle.end - end <= 59, "end at most 59 s later");
    } else {
        // The start's round-up overtook the requested end: the window
        // clamps to one minute after the reconstructed start.
        assert!(lifecycle.end == lifecycle.start + 60, "sub-minute straddle clamps to 1 min");
    }
    // The lifecycle projection and the full decode agree.
    let md = to_token_metadata(unpack_token_id(pack_window(ts, start_delay, end_delay)));
    assert!(md.lifecycle.start == lifecycle.start && md.lifecycle.end == lifecycle.end, "agree");
    assert!(md.minted_at == minted_at, "minted_at agrees");
}

/// A past start clamps to now, so the reconstructed start is never before
/// the mint time and at most 59 seconds after it.
#[test]
#[fuzzer(runs: 32)]
fn test_fuzz_past_start_clamps_to_now(now_raw: u32, back: u16) {
    let now: u64 = now_raw.into();
    let start = if now > back.into() {
        now - back.into()
    } else {
        0
    };
    let (ts, start_delay, end_delay) = project(now, start, 0);
    let lifecycle = unpack_lifecycle(pack_window(ts, start_delay, end_delay));
    assert!(lifecycle.start >= now, "clamped start never before now");
    assert!(lifecycle.start - now <= 59, "clamped start at most 59 s after now");
    assert!(lifecycle.end == 0, "no end requested");
}
