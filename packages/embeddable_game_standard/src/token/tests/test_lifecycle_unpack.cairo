// ==============================================================================
// LIFECYCLE PATH — behaviour conservation suite
// ==============================================================================
//
// `unpack_lifecycle` replaces `to_token_metadata(unpack_token_id(id)).lifecycle`
// on the `is_lifecycle_open` / `assert_lifecycle_open` path. It must be
// indistinguishable from what it replaced, for EVERY token id — including ids
// that are not well-formed packs.
//
// Three references, as in `test_packing.cairo`:
//   * `lifecycle_arms::lifecycle_before` — the pre-change path built on the
//     frozen v2.7.0 codec: the exact code that shipped
//   * `packing::to_token_metadata(packing::unpack_token_id(..))` — the shipped
//     full unpack, which `token_metadata()` still uses and which therefore must
//     not diverge from the new shortcut
//   * a naive oracle reconstruction from `packing_oracle::field`, computed from
//     absolute bit offsets with no shared constant
//
// The failure mode being hunted is an off-by-one at the window edges and a
// mishandled `end_delay == 0` sentinel, so both are tested directly rather than
// only through fuzzing.

use game_components_interfaces::structs::token::Lifecycle;
use openzeppelin_interfaces::erc721::ERC721ABIDispatcher;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp};
use starknet::ContractAddress;
use crate::token::interface::{IMinigameTokenDispatcher, IMinigameTokenDispatcherTrait};
use crate::token::lifecycle::LifecycleTrait;
use crate::token::packing;
use super::{lifecycle_arms, packing_oracle as oracle, packing_v270 as v270};

const MAX_MINTED_AT: u64 = 0x7FFFFFFFF; // 35 bits
const MAX_DELAY: u32 = 0x1FFFFFF; // 25 bits

/// Independent reconstruction of the window from absolute bit offsets, using
/// only the naive oracle's field extractor. Mirrors `to_token_metadata`'s rule,
/// sentinel included, but shares no constant with the code under test.
///
/// * `token_id` — any felt252.
/// Returns the expected `(start, end)`.
fn oracle_lifecycle(token_id: felt252) -> Lifecycle {
    let minted_at: u64 = oracle::field(token_id, oracle::MINTED_AT).try_into().unwrap();
    let start_delay: u64 = oracle::field(token_id, oracle::START_DELAY).try_into().unwrap();
    let end_delay: u64 = oracle::field(token_id, oracle::END_DELAY).try_into().unwrap();
    let start = minted_at + start_delay;
    Lifecycle { start, end: if end_delay > 0 {
        start + end_delay
    } else {
        0
    } }
}

/// Asserts the shipped shortcut is indistinguishable from every reference on
/// `token_id`, and that `LifecycleTrait::is_open` agrees with the old path at EVERY
/// interesting instant around the window: one second before it opens, exactly
/// at open, mid-window, one before close, exactly at close, one after, plus the
/// extremes 0 and u64 max.
///
/// * `token_id` — any felt252; no well-formedness precondition.
fn assert_lifecycle_paths_agree(token_id: felt252) {
    let shipped = packing::unpack_lifecycle(token_id);
    let before = lifecycle_arms::lifecycle_before(token_id);
    let via_full = packing::to_token_metadata(packing::unpack_token_id(token_id)).lifecycle;
    let expected = oracle_lifecycle(token_id);

    assert!(shipped.start == before.start, "start diverged from the pre-change path");
    assert!(shipped.end == before.end, "end diverged from the pre-change path");
    assert!(shipped.start == via_full.start, "start diverged from the shipped full unpack");
    assert!(shipped.end == via_full.end, "end diverged from the shipped full unpack");
    assert!(shipped.start == expected.start, "start diverged from the oracle");
    assert!(shipped.end == expected.end, "end diverged from the oracle");

    // Edge sweep. `start` and `end` are both < 2^36, so these never wrap.
    let mut probes: Array<u64> = array![
        0, 1, shipped.start, shipped.start + 1, shipped.end, shipped.end + 1, 0xFFFFFFFFFFFFFFFF,
    ];
    if shipped.start > 0 {
        probes.append(shipped.start - 1);
    }
    if shipped.end > 0 {
        probes.append(shipped.end - 1);
        // mid-window, when there is one
        if shipped.end > shipped.start {
            probes.append(shipped.start + (shipped.end - shipped.start) / 2);
        }
    }
    for t in probes {
        assert!(
            shipped.is_open(t) == before.is_open(t),
            "is_open diverged at t={} (start={}, end={})",
            t,
            shipped.start,
            shipped.end,
        );
        assert!(shipped.can_start(t) == before.can_start(t), "can_start diverged at t={}", t);
        assert!(shipped.has_expired(t) == before.has_expired(t), "has_expired diverged at t={}", t);
    }
}

/// Packs a lifecycle-only id (every other field zero) and runs the full
/// agreement check on it.
fn check(minted_at: u64, start_delay: u32, end_delay: u32) {
    let id = packing::pack_token_id(
        minted_at, start_delay, end_delay, 0, 0, false, 0, 0, false, false, 0, 0,
    );
    assert_lifecycle_paths_agree(id);
}

// ==============================================================================
// THE SENTINEL — end_delay == 0 must keep producing end == 0 ("no expiration")
// ==============================================================================

#[test]
fn test_sentinel_end_delay_zero_means_no_expiry() {
    check(0, 0, 0);
    check(1000, 0, 0);
    check(1000, 500, 0);
    check(MAX_MINTED_AT, MAX_DELAY, 0);

    // Stated explicitly, not just differentially: end must be the 0 sentinel,
    // and the token must stay playable arbitrarily far in the future.
    let id = packing::pack_token_id(
        1000, 500, 0, 0xBEEF, 0x3ADCBA9, true, 0x2AD, 0xCAFE, true, true, 0x2FEDCBA9, 0x1234,
    );
    let life = packing::unpack_lifecycle(id);
    assert!(life.start == 1500, "start must be minted_at + start_delay");
    assert!(life.end == 0, "end_delay == 0 must produce the end == 0 sentinel");
    assert!(!life.has_expired(0xFFFFFFFFFFFFFFFF), "sentinel token must never expire");
    assert!(life.is_open(0xFFFFFFFFFFFFFFFF), "sentinel token's window never closes");
}

/// end_delay == 1 is the smallest NON-sentinel value; it must not be confused
/// with the sentinel.
#[test]
fn test_smallest_non_sentinel_end_delay() {
    check(1000, 500, 1);
    let id = packing::pack_token_id(1000, 500, 1, 0, 0, false, 0, 0, false, false, 0, 0);
    let life = packing::unpack_lifecycle(id);
    assert!(life.end == 1501, "end must be start + end_delay");
    assert!(life.is_open(1500), "open at start");
    assert!(!life.is_open(1501), "expired exactly at end");
}

// ==============================================================================
// BOUNDARIES
// ==============================================================================

#[test]
fn test_boundary_end_delay_max() {
    check(0, 0, MAX_DELAY);
    check(1000, 500, MAX_DELAY);
    check(MAX_MINTED_AT, MAX_DELAY, MAX_DELAY);
}

#[test]
fn test_boundary_start_delay_zero() {
    check(0, 0, 0);
    check(1000, 0, 5000);
    check(MAX_MINTED_AT, 0, MAX_DELAY);
}

#[test]
fn test_boundary_start_delay_max() {
    check(0, MAX_DELAY, 0);
    check(1000, MAX_DELAY, 1);
    check(MAX_MINTED_AT, MAX_DELAY, 1);
}

#[test]
fn test_boundary_minted_at_zero() {
    check(0, 0, 0);
    check(0, 1, 1);
    check(0, MAX_DELAY, MAX_DELAY);
}

#[test]
fn test_boundary_minted_at_max() {
    check(MAX_MINTED_AT, 0, 0);
    check(MAX_MINTED_AT, 1, 1);
    check(MAX_MINTED_AT, MAX_DELAY, MAX_DELAY);
    // The saturated window is the largest value the reconstruction can produce.
    let id = packing::pack_token_id(
        MAX_MINTED_AT, MAX_DELAY, MAX_DELAY, 0, 0, false, 0, 0, false, false, 0, 0,
    );
    let life = packing::unpack_lifecycle(id);
    assert!(life.start == MAX_MINTED_AT + MAX_DELAY.into(), "saturated start");
    assert!(life.end == MAX_MINTED_AT + MAX_DELAY.into() + MAX_DELAY.into(), "saturated end");
}

/// The three lifecycle fields must not read anything from the nine fields above
/// them: saturate everything else and require the window to be unchanged.
#[test]
fn test_neighbouring_fields_do_not_bleed_into_the_window() {
    let quiet = packing::pack_token_id(1000, 500, 2000, 0, 0, false, 0, 0, false, false, 0, 0);
    let loud = packing::pack_token_id(
        1000,
        500,
        2000,
        0xFFFF,
        0x3FFFFFF,
        true,
        0x3FF,
        0xFFFF,
        true,
        true,
        0x3FFFFFFF,
        0x1FFFFFFFFFFFFFFFF,
    );
    let a = packing::unpack_lifecycle(quiet);
    let b = packing::unpack_lifecycle(loud);
    assert!(a.start == b.start, "start moved when neighbours were saturated");
    assert!(a.end == b.end, "end moved when neighbours were saturated");
    assert_lifecycle_paths_agree(loud);
}

// ==============================================================================
// FUZZ — pinned seed, both well-formed packs and arbitrary bit patterns
// ==============================================================================

#[test]
#[fuzzer(runs: 256, seed: 20260906)]
fn test_fuzz_lifecycle_well_formed(a: u128, b: u128) {
    let minted_at: u64 = (a % 0x800000000).try_into().unwrap();
    let start_delay: u32 = ((a / 0x800000000) % 0x2000000).try_into().unwrap();
    // Half the draws hit the end_delay == 0 sentinel on purpose.
    let end_delay: u32 = if b % 2 == 0 {
        0
    } else {
        ((b / 2) % 0x2000000).try_into().unwrap()
    };
    check(minted_at, start_delay, end_delay);
}

#[test]
#[fuzzer(runs: 256, seed: 20260906)]
fn test_fuzz_lifecycle_arbitrary_id(low: u128, high: u128) {
    let high = high % 0x800000000000000000000000000000; // 2^123
    let id: felt252 = low.into() + high.into() * 0x100000000000000000000000000000000;
    assert_lifecycle_paths_agree(id);
}

// ==============================================================================
// COMPONENT LEVEL — the rewired `is_lifecycle_open` entrypoint through the deployed
// mock, at every edge of the window.
// ==============================================================================

fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn deploy_mock() -> IMinigameTokenDispatcher {
    let contract = declare("StandardGameMock").unwrap().contract_class();
    let mut calldata: Array<felt252> = array![];
    let name: ByteArray = "StandardToken";
    let symbol: ByteArray = "STD";
    let base_uri: ByteArray = "https://token.test/";
    name.serialize(ref calldata);
    symbol.serialize(ref calldata);
    base_uri.serialize(ref calldata);
    addr('FEE_RECIPIENT').serialize(ref calldata);
    addr('OWNER').serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    let _ = ERC721ABIDispatcher { contract_address };
    IMinigameTokenDispatcher { contract_address }
}

/// Mints a token whose window is [2000, 3000) and walks the entrypoint across
/// before-start / at-start / mid / one-before-end / at-end / after-end. The
/// expected answers come from the pre-change path computed on the same id, so
/// this is a differential test of the deployed entrypoint, not a restatement of
/// the implementation.
#[test]
fn test_component_is_lifecycle_open_across_the_window() {
    let token = deploy_mock();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = token
        .mint(
            Option::None,
            Option::None,
            Option::Some(2000),
            Option::Some(3000),
            Option::None,
            Option::None,
            Option::None,
            addr('ALICE'),
            false,
            false,
            0,
            0,
        );

    let reference = lifecycle_arms::lifecycle_before(token_id);
    assert!(reference.start == 2000, "window start");
    assert!(reference.end == 3000, "window end");

    let instants: Array<u64> = array![0, 1, 1999, 2000, 2001, 2500, 2999, 3000, 3001, 99999999];
    for t in instants {
        start_cheat_block_timestamp(token.contract_address, t);
        assert!(
            token.is_lifecycle_open(token_id) == reference.is_open(t),
            "entrypoint is_lifecycle_open diverged at t={}",
            t,
        );
    }
}

/// Same walk for a token with no expiration, where the sentinel decides.
#[test]
fn test_component_is_lifecycle_open_immortal_across_the_window() {
    let token = deploy_mock();
    start_cheat_block_timestamp(token.contract_address, 1000);
    let token_id = token
        .mint(
            Option::None,
            Option::None,
            Option::Some(2000),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            addr('ALICE'),
            false,
            false,
            0,
            0,
        );
    let reference = lifecycle_arms::lifecycle_before(token_id);
    assert!(reference.end == 0, "immortal token must carry the end == 0 sentinel");

    let instants: Array<u64> = array![0, 1999, 2000, 2001, 0xFFFFFFFFFFFFFFFF];
    for t in instants {
        start_cheat_block_timestamp(token.contract_address, t);
        assert!(
            token.is_lifecycle_open(token_id) == reference.is_open(t),
            "entrypoint is_lifecycle_open diverged at t={} for the immortal token",
            t,
        );
    }
}

/// `token_metadata()` still returns the full struct and its lifecycle must
/// remain identical to the shortcut's — they are two readers of one layout.
#[test]
fn test_token_metadata_lifecycle_still_matches_the_shortcut() {
    let id = v270::pack_token_id(
        0x7EDCBA987,
        0x1ECBA98,
        0x1DBA987,
        0xBEEF,
        0x3ADCBA9,
        true,
        0x2AD,
        0xCAFE,
        true,
        true,
        0x2FEDCBA9,
        0x1DEADBEEFCAFEF00D,
    );
    let full = packing::to_token_metadata(packing::unpack_token_id(id)).lifecycle;
    let short = packing::unpack_lifecycle(id);
    assert!(full.start == short.start, "token_metadata start");
    assert!(full.end == short.end, "token_metadata end");
}
