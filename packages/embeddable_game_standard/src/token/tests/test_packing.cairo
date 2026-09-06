// ==============================================================================
// PACKED TOKEN ID — bit-format conservation suite
// ==============================================================================
//
// The accessor rewrite in `token/packing.cairo` is a pure implementation
// change: the same bits come out of the same positions. These tests are what
// makes that a proven claim rather than an asserted one. Every case checks
// THREE independent implementations against each other:
//
//   1. `crate::token::packing`            — the shipped code
//   2. `super::packing_v270`              — frozen verbatim copy of v2.7.0,
//                                           i.e. the code that minted the ids
//                                           already on chain
//   3. `super::packing_oracle`            — a naive whole-u256 shift-and-modulo
//                                           decoder addressing fields by
//                                           absolute bit offset, sharing no
//                                           constant with either of the above
//
// Agreement between (1) and (2) is the non-breaking proof. Agreement with (3)
// is what stops (1) and (2) from being wrong together.

use crate::token::packing;
use super::{packing_oracle as oracle, packing_v270 as v270};

/// Field ranges, straight from the layout table.
const MAX_MINTED_AT: u64 = 0x7FFFFFFFF; // 35 bits
const MAX_START_DELAY: u32 = 0x1FFFFFF; // 25 bits
const MAX_END_DELAY: u32 = 0x1FFFFFF; // 25 bits
const MAX_SETTINGS_ID: u32 = 0xFFFF; // 16 bits
const MAX_MINTED_BY: u64 = 0x3FFFFFF; // 26 bits
const MAX_TX_HASH: u16 = 0x3FF; // 10 bits
const MAX_SALT: u16 = 0xFFFF; // 16 bits
const MAX_OBJECTIVE_ID: u32 = 0x3FFFFFFF; // 30 bits
const MAX_METADATA: u128 = 0x1FFFFFFFFFFFFFFFF; // 65 bits

// ==============================================================================
// The core assertion: for an arbitrary token id, all three decoders agree on
// every field, and the shipped bulk unpack agrees with the shipped accessors.
// ==============================================================================

/// The core assertion of this suite: all three decoders agree on every field of
/// `token_id`, and the shipped bulk unpack agrees with the shipped accessors.
///
/// * `token_id` — ANY felt252. There is no well-formedness precondition: an
///   arbitrary bit pattern is valid input and is exercised deliberately by
///   `test_fuzz_arbitrary_id_decoders_agree`.
///
/// Returns nothing; panics naming the first field that diverges.
fn assert_decoders_agree(token_id: felt252) {
    // --- shipped vs frozen v2.7.0 (the non-breaking claim) --------------------
    assert!(
        packing::unpack_minted_at(token_id) == v270::unpack_minted_at(token_id),
        "packing::unpack_minted_at(token_id) mismatch",
    );
    assert!(
        packing::unpack_start_delay(token_id) == v270::unpack_start_delay(token_id),
        "packing::unpack_start_delay(token_id) mismatch",
    );
    assert!(
        packing::unpack_end_delay(token_id) == v270::unpack_end_delay(token_id),
        "packing::unpack_end_delay(token_id) mismatch",
    );
    assert!(
        packing::unpack_settings_id(token_id) == v270::unpack_settings_id(token_id),
        "packing::unpack_settings_id(token_id) mismatch",
    );
    assert!(
        packing::unpack_minted_by(token_id) == v270::unpack_minted_by(token_id),
        "packing::unpack_minted_by(token_id) mismatch",
    );
    assert!(
        packing::unpack_soulbound(token_id) == v270::unpack_soulbound(token_id),
        "packing::unpack_soulbound(token_id) mismatch",
    );
    assert!(
        packing::unpack_tx_hash(token_id) == v270::unpack_tx_hash(token_id),
        "packing::unpack_tx_hash(token_id) mismatch",
    );
    assert!(
        packing::unpack_salt(token_id) == v270::unpack_salt(token_id),
        "packing::unpack_salt(token_id) mismatch",
    );
    assert!(
        packing::unpack_paymaster(token_id) == v270::unpack_paymaster(token_id),
        "packing::unpack_paymaster(token_id) mismatch",
    );
    assert!(
        packing::unpack_has_context(token_id) == v270::unpack_has_context(token_id),
        "packing::unpack_has_context(token_id) mismatch",
    );
    assert!(
        packing::unpack_objective_id(token_id) == v270::unpack_objective_id(token_id),
        "packing::unpack_objective_id(token_id) mismatch",
    );
    assert!(
        packing::unpack_metadata(token_id) == v270::unpack_metadata(token_id),
        "packing::unpack_metadata(token_id) mismatch",
    );

    // --- shipped vs naive oracle (the not-wrong-together claim) ---------------
    let expect_minted_at: u64 = oracle::field(token_id, oracle::MINTED_AT).try_into().unwrap();
    let expect_start_delay: u32 = oracle::field(token_id, oracle::START_DELAY).try_into().unwrap();
    let expect_end_delay: u32 = oracle::field(token_id, oracle::END_DELAY).try_into().unwrap();
    let expect_settings_id: u32 = oracle::field(token_id, oracle::SETTINGS_ID).try_into().unwrap();
    let expect_minted_by: u64 = oracle::field(token_id, oracle::MINTED_BY).try_into().unwrap();
    let expect_tx_hash: u16 = oracle::field(token_id, oracle::TX_HASH).try_into().unwrap();
    let expect_salt: u16 = oracle::field(token_id, oracle::SALT).try_into().unwrap();
    let expect_objective_id: u32 = oracle::field(token_id, oracle::OBJECTIVE_ID)
        .try_into()
        .unwrap();
    let expect_metadata: u128 = oracle::field(token_id, oracle::METADATA).try_into().unwrap();

    assert!(packing::unpack_minted_at(token_id) == expect_minted_at, "minted_at vs oracle");
    assert!(packing::unpack_start_delay(token_id) == expect_start_delay, "start_delay vs oracle");
    assert!(packing::unpack_end_delay(token_id) == expect_end_delay, "end_delay vs oracle");
    assert!(packing::unpack_settings_id(token_id) == expect_settings_id, "settings_id vs oracle");
    assert!(packing::unpack_minted_by(token_id) == expect_minted_by, "minted_by vs oracle");
    assert!(
        packing::unpack_soulbound(token_id) == oracle::flag(token_id, oracle::SOULBOUND),
        "soulbound vs oracle",
    );
    assert!(packing::unpack_tx_hash(token_id) == expect_tx_hash, "tx_hash vs oracle");
    assert!(packing::unpack_salt(token_id) == expect_salt, "salt vs oracle");
    assert!(
        packing::unpack_paymaster(token_id) == oracle::flag(token_id, oracle::PAYMASTER),
        "paymaster vs oracle",
    );
    assert!(
        packing::unpack_has_context(token_id) == oracle::flag(token_id, oracle::HAS_CONTEXT),
        "has_context vs oracle",
    );
    assert!(
        packing::unpack_objective_id(token_id) == expect_objective_id, "objective_id vs oracle",
    );
    assert!(packing::unpack_metadata(token_id) == expect_metadata, "metadata vs oracle");

    // --- bulk unpack vs the accessors ---------------------------------------
    let all = packing::unpack_token_id(token_id);
    assert!(all.minted_at == expect_minted_at, "bulk minted_at");
    assert!(all.start_delay == expect_start_delay, "bulk start_delay");
    assert!(all.end_delay == expect_end_delay, "bulk end_delay");
    assert!(all.settings_id == expect_settings_id, "bulk settings_id");
    assert!(all.minted_by == expect_minted_by, "bulk minted_by");
    assert!(all.soulbound == oracle::flag(token_id, oracle::SOULBOUND), "bulk soulbound");
    assert!(all.tx_hash == expect_tx_hash, "bulk tx_hash");
    assert!(all.salt == expect_salt, "bulk salt");
    assert!(all.paymaster == oracle::flag(token_id, oracle::PAYMASTER), "bulk paymaster");
    assert!(all.has_context == oracle::flag(token_id, oracle::HAS_CONTEXT), "bulk has_context");
    assert!(all.objective_id == expect_objective_id, "bulk objective_id");
    assert!(all.metadata == expect_metadata, "bulk metadata");
}

// ==============================================================================
// PACK — the produced id must be bit-identical to v2.7.0's and to the oracle's
// ==============================================================================

/// Packs one field vector three ways and asserts the three ids are the SAME
/// felt252 — this is the non-breaking claim in its most direct form.
///
/// Every parameter must fit its field width (see the layout table); the shipped
/// packer asserts on all of them except `tx_hash`, which it masks, so callers
/// must keep `tx_hash` <= 0x3FF for the naive packer to agree.
///
/// Returns the packed token id, so callers can go on to decode it.
fn assert_pack_identical(
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
    let shipped = packing::pack_token_id(
        minted_at,
        start_delay,
        end_delay,
        settings_id,
        minted_by,
        soulbound,
        tx_hash,
        salt,
        paymaster,
        has_context,
        objective_id,
        metadata,
    );
    let frozen = v270::pack_token_id(
        minted_at,
        start_delay,
        end_delay,
        settings_id,
        minted_by,
        soulbound,
        tx_hash,
        salt,
        paymaster,
        has_context,
        objective_id,
        metadata,
    );
    let naive = oracle::pack(
        minted_at,
        start_delay,
        end_delay,
        settings_id,
        minted_by,
        soulbound,
        tx_hash,
        salt,
        paymaster,
        has_context,
        objective_id,
        metadata,
    );
    assert!(shipped == frozen, "packed id moved vs v2.7.0");
    assert!(shipped == naive, "packed id disagrees with oracle");
    shipped
}

/// Pack, prove the id is bit-identical to v2.7.0's and the oracle's, prove all
/// three decoders agree on it, then prove every accessor reads back EXACTLY the
/// value that went in.
///
/// Same parameter constraints as `assert_pack_identical`. Returns nothing;
/// panics naming the first field that fails to survive the round trip.
fn assert_round_trip(
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
) {
    let id = assert_pack_identical(
        minted_at,
        start_delay,
        end_delay,
        settings_id,
        minted_by,
        soulbound,
        tx_hash,
        salt,
        paymaster,
        has_context,
        objective_id,
        metadata,
    );
    assert_decoders_agree(id);

    assert!(packing::unpack_minted_at(id) == minted_at, "minted_at round-trip");
    assert!(packing::unpack_start_delay(id) == start_delay, "start_delay round-trip");
    assert!(packing::unpack_end_delay(id) == end_delay, "end_delay round-trip");
    assert!(packing::unpack_settings_id(id) == settings_id, "settings_id round-trip");
    assert!(packing::unpack_minted_by(id) == minted_by, "minted_by round-trip");
    assert!(packing::unpack_soulbound(id) == soulbound, "soulbound round-trip");
    assert!(packing::unpack_tx_hash(id) == tx_hash, "tx_hash round-trip");
    assert!(packing::unpack_salt(id) == salt, "salt round-trip");
    assert!(packing::unpack_paymaster(id) == paymaster, "paymaster round-trip");
    assert!(packing::unpack_has_context(id) == has_context, "has_context round-trip");
    assert!(packing::unpack_objective_id(id) == objective_id, "objective_id round-trip");
    assert!(packing::unpack_metadata(id) == metadata, "metadata round-trip");
}

// ==============================================================================
// ALL-ZERO
// ==============================================================================

#[test]
fn test_round_trip_all_zero() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_decoders_agree(0);
}

// ==============================================================================
// PER-FIELD MAXIMUM — every field simultaneously saturated (id == 2^251 - 1)
// ==============================================================================

#[test]
fn test_round_trip_all_max() {
    assert_round_trip(
        MAX_MINTED_AT,
        MAX_START_DELAY,
        MAX_END_DELAY,
        MAX_SETTINGS_ID,
        MAX_MINTED_BY,
        true,
        MAX_TX_HASH,
        MAX_SALT,
        true,
        true,
        MAX_OBJECTIVE_ID,
        MAX_METADATA,
    );
}

#[test]
fn test_all_max_is_2_pow_251_minus_1() {
    // The layout is fully allocated across 251 bits, so saturating every field
    // must produce exactly 2^251 - 1. Anything else means a field moved.
    let id = packing::pack_token_id(
        MAX_MINTED_AT,
        MAX_START_DELAY,
        MAX_END_DELAY,
        MAX_SETTINGS_ID,
        MAX_MINTED_BY,
        true,
        MAX_TX_HASH,
        MAX_SALT,
        true,
        true,
        MAX_OBJECTIVE_ID,
        MAX_METADATA,
    );
    let expected: felt252 = (oracle::two_pow(251) - 1).try_into().unwrap();
    assert!(id == expected, "saturated layout is not 2^251 - 1");
}

// ==============================================================================
// PER-FIELD ISOLATION — one field set, everything else zero.
// This is the case that catches an offset or mask error; a full vector can
// hide one behind its neighbours.
// ==============================================================================

#[test]
fn test_isolation_minted_at() {
    assert_round_trip(MAX_MINTED_AT, 0, 0, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(1, 0, 0, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0x5AA55AA5, 0, 0, 0, 0, false, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_start_delay() {
    assert_round_trip(0, MAX_START_DELAY, 0, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 1, 0, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0x1555555, 0, 0, 0, false, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_end_delay() {
    assert_round_trip(0, 0, MAX_END_DELAY, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 1, 0, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0x1AAAAAA, 0, 0, false, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_settings_id() {
    assert_round_trip(0, 0, 0, MAX_SETTINGS_ID, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 1, 0, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0xA55A, 0, false, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_minted_by() {
    assert_round_trip(0, 0, 0, 0, MAX_MINTED_BY, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 1, false, 0, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 0x2555555, false, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_soulbound() {
    assert_round_trip(0, 0, 0, 0, 0, true, 0, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_tx_hash() {
    assert_round_trip(0, 0, 0, 0, 0, false, MAX_TX_HASH, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 1, 0, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 0x2A5, 0, false, false, 0, 0);
}

#[test]
fn test_isolation_salt() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, MAX_SALT, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 1, false, false, 0, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0x5AA5, false, false, 0, 0);
}

#[test]
fn test_isolation_paymaster() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, true, false, 0, 0);
}

#[test]
fn test_isolation_has_context() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, true, 0, 0);
}

#[test]
fn test_isolation_objective_id() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, MAX_OBJECTIVE_ID, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 1, 0);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 0x2AAAAAAA, 0);
}

#[test]
fn test_isolation_metadata() {
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 0, MAX_METADATA);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 0, 1);
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, false, false, 0, 0x1DEADBEEFCAFEF00D);
}

/// The two adjacent single-bit flags are the easiest pair to swap. Set each
/// alone and confirm the other stays clear.
#[test]
fn test_isolation_adjacent_flags_do_not_bleed() {
    let only_paymaster = packing::pack_token_id(0, 0, 0, 0, 0, false, 0, 0, true, false, 0, 0);
    assert!(packing::unpack_paymaster(only_paymaster), "paymaster not set");
    assert!(!packing::unpack_has_context(only_paymaster), "has_context bled from paymaster");

    let only_has_context = packing::pack_token_id(0, 0, 0, 0, 0, false, 0, 0, false, true, 0, 0);
    assert!(!packing::unpack_paymaster(only_has_context), "paymaster bled from has_context");
    assert!(packing::unpack_has_context(only_has_context), "has_context not set");

    // ...and that neither is confused with soulbound, the third flag.
    let only_soulbound = packing::pack_token_id(0, 0, 0, 0, 0, true, 0, 0, false, false, 0, 0);
    assert!(packing::unpack_soulbound(only_soulbound), "soulbound not set");
    assert!(!packing::unpack_paymaster(only_soulbound), "paymaster bled from soulbound");
    assert!(!packing::unpack_has_context(only_soulbound), "has_context bled from soulbound");
}

// ==============================================================================
// ADVERSARIAL FIXED VECTORS — neighbours saturated around a zero field, so a
// mask that is one bit too wide reads a 1 where a 0 belongs.
// ==============================================================================

#[test]
fn test_neighbours_saturated_around_each_zero_field() {
    // start_delay zero, its neighbours full
    assert_round_trip(MAX_MINTED_AT, 0, MAX_END_DELAY, 0, 0, false, 0, 0, false, false, 0, 0);
    // end_delay zero, its neighbours full
    assert_round_trip(0, MAX_START_DELAY, 0, MAX_SETTINGS_ID, 0, false, 0, 0, false, false, 0, 0);
    // settings_id zero, its neighbours full
    assert_round_trip(0, 0, MAX_END_DELAY, 0, MAX_MINTED_BY, false, 0, 0, false, false, 0, 0);
    // minted_by zero, its neighbours full (soulbound is the field above it)
    assert_round_trip(0, 0, 0, MAX_SETTINGS_ID, 0, true, 0, 0, false, false, 0, 0);
    // salt zero, its neighbours full
    assert_round_trip(0, 0, 0, 0, 0, false, MAX_TX_HASH, 0, true, true, 0, 0);
    // objective_id zero, its neighbours full
    assert_round_trip(0, 0, 0, 0, 0, false, 0, 0, true, true, 0, MAX_METADATA);
    // tx_hash zero, salt full (the pair the u256 mask used to conflate)
    assert_round_trip(0, 0, 0, 0, 0, false, 0, MAX_SALT, false, false, 0, 0);
}

// ==============================================================================
// FUZZ — pinned seed so a failure reproduces exactly.
//
//   snforge test test_fuzz_ -p game_components_embeddable_game_standard \
//     --fuzzer-seed 20260906
// ==============================================================================

/// Arbitrary bit patterns, not just well-formed packs: compose a 251-bit felt
/// from two fuzzed halves and require all three decoders to agree on it.
#[test]
#[fuzzer(runs: 256, seed: 20260906)]
fn test_fuzz_arbitrary_id_decoders_agree(low: u128, high: u128) {
    // Keep the value below 2^251 so it is a representable token id.
    let high = high % 0x800000000000000000000000000000; // 2^123
    let id: felt252 = low.into() + high.into() * 0x100000000000000000000000000000000;
    assert_decoders_agree(id);
}

/// Well-formed packs over fuzzed field values: bit-identical id vs v2.7.0 and
/// vs the oracle, then an exact round-trip of every field.
#[test]
#[fuzzer(runs: 256, seed: 20260906)]
fn test_fuzz_round_trip(a: u128, b: u128, c: u128, flags: u8) {
    let minted_at: u64 = (a % 0x800000000).try_into().unwrap();
    let start_delay: u32 = ((a / 0x800000000) % 0x2000000).try_into().unwrap();
    let end_delay: u32 = ((a / 0x1000000000000000) % 0x2000000).try_into().unwrap();
    let settings_id: u32 = (b % 0x10000).try_into().unwrap();
    let minted_by: u64 = ((b / 0x10000) % 0x4000000).try_into().unwrap();
    let tx_hash: u16 = ((b / 0x40000000000) % 0x400).try_into().unwrap();
    let salt: u16 = ((b / 0x10000000000000) % 0x10000).try_into().unwrap();
    let objective_id: u32 = (c % 0x40000000).try_into().unwrap();
    let metadata: u128 = (c / 0x40000000) % 0x20000000000000000;

    assert_round_trip(
        minted_at,
        start_delay,
        end_delay,
        settings_id,
        minted_by,
        (flags / 1) % 2 == 1,
        tx_hash,
        salt,
        (flags / 2) % 2 == 1,
        (flags / 4) % 2 == 1,
        objective_id,
        metadata,
    );
}

// ==============================================================================
// extract_tx_hash_bits — rewritten from a u256 AND to a low-limb AND
// ==============================================================================

#[test]
#[fuzzer(runs: 256, seed: 20260906)]
fn test_fuzz_extract_tx_hash_bits_matches_v270(hash: felt252) {
    assert!(
        packing::extract_tx_hash_bits(hash) == v270::extract_tx_hash_bits(hash),
        "packing::extract_tx_hash_bits(hash) mismatch",
    );
}

#[test]
fn test_extract_tx_hash_bits_fixed_vectors() {
    let cases: Array<felt252> = array![
        0, 1, 0x3FF, 0x400, 0x401, 0x7FF, 0xFFFFFFFFFFFFFFFF,
        0x100000000000000000000000000000000, // exactly 2^128: low limb is zero
        0x100000000000000000000000000000001, 0x1000000000000000000000000000003FF,
        0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, -1,
    ];
    for case in cases {
        assert!(
            packing::extract_tx_hash_bits(case) == v270::extract_tx_hash_bits(case),
            "extract_tx_hash_bits diverged",
        );
    }
}

// ==============================================================================
// NOTED, NOT FIXED: pack_token_id truncates tx_hash silently.
//
// Every other over-wide field is rejected by an assert; tx_hash is masked with
// `& 0x3FF` instead. It is currently benign because the only caller feeds it
// `extract_tx_hash_bits`, which already masks upstream, so no reachable path
// can pass a value the mask would change. This test pins the CURRENT behaviour
// so that turning the mask into an assert later is a deliberate, visible
// change rather than a silent one.
// ==============================================================================

#[test]
fn test_pack_token_id_masks_oversized_tx_hash_silently() {
    let masked = packing::pack_token_id(0, 0, 0, 0, 0, false, 0x7FF, 0, false, false, 0, 0);
    let equivalent = packing::pack_token_id(0, 0, 0, 0, 0, false, 0x3FF, 0, false, false, 0, 0);
    assert!(masked == equivalent, "tx_hash is no longer silently masked");
    assert!(packing::unpack_tx_hash(masked) == 0x3FF, "packing::unpack_tx_hash(masked) mismatch");
    // Unchanged from v2.7.0 — this behaviour is inherited, not introduced.
    assert!(
        masked == v270::pack_token_id(0, 0, 0, 0, 0, false, 0x7FF, 0, false, false, 0, 0),
        "masked mismatch",
    );
}

// ==============================================================================
// to_token_metadata — unchanged, but it consumes the rewritten unpack
// ==============================================================================

#[test]
fn test_to_token_metadata_matches_v270() {
    let id = packing::pack_token_id(
        1_000_000, 3_600, 86_400, 7, 42, true, 0x1AB, 0x99, true, true, 12_345, 0xABCDEF0123456789,
    );
    let shipped = packing::to_token_metadata(packing::unpack_token_id(id));
    let frozen = v270::to_token_metadata(v270::unpack_token_id(id));
    assert!(shipped.minted_at == frozen.minted_at, "shipped.minted_at mismatch");
    assert!(shipped.settings_id == frozen.settings_id, "shipped.settings_id mismatch");
    assert!(shipped.lifecycle.start == frozen.lifecycle.start, "shipped.lifecycle.start mismatch");
    assert!(shipped.lifecycle.end == frozen.lifecycle.end, "shipped.lifecycle.end mismatch");
    assert!(shipped.minted_by == frozen.minted_by, "shipped.minted_by mismatch");
    assert!(shipped.soulbound == frozen.soulbound, "shipped.soulbound mismatch");
    assert!(shipped.has_context == frozen.has_context, "shipped.has_context mismatch");
    assert!(shipped.objective_id == frozen.objective_id, "shipped.objective_id mismatch");
    assert!(shipped.paymaster == frozen.paymaster, "shipped.paymaster mismatch");
    assert!(shipped.metadata == frozen.metadata, "shipped.metadata mismatch");
}
