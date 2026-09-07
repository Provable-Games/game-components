// LIFECYCLE ARMS — candidate shapes for a combined `(start, end)` accessor,
// measured against the pre-change path. Test-only.
//
// `is_lifecycle_open` and `assert_lifecycle_open` need three fields — minted_at
// (bits 0-34), start_delay (35-59) and end_delay (60-84) — which are the
// bottom 85 bits of the low u128. The pre-change path reached them through a
// full twelve-field unpack plus a `TokenMetadata` struct build.
//
// Every arm must reproduce `to_token_metadata`'s reconstruction EXACTLY,
// sentinel included:
//     start = minted_at + start_delay
//     end   = if end_delay > 0 { minted_at + start_delay + end_delay } else { 0 }
//
// This file is deliberately NOT part of the set copied by
// `scripts/bench_packing.sh baseline`: it names `crate::token::packing::
// unpack_lifecycle`, which by construction does not exist on a pre-change
// tree. The pre-change arm below is self-contained, so both arms still
// coexist in one crate and one snforge run.

use game_components_interfaces::structs::token::Lifecycle;
use super::packing_v270;

/// Overflow note, shared by every arm: the three fields are bounded by their
/// masks at 35, 25 and 25 bits, so `minted_at + start_delay + end_delay` is
/// always below 2^36 and fits u64 with room to spare. That holds for arbitrary
/// token ids, not just well-formed packs, which is why the u128 and u64
/// arithmetic variants below cannot disagree.
mod nz {
    pub const P25: NonZero<u128> = 0x2000000;
    pub const P35: NonZero<u128> = 0x800000000;
    pub const P60: NonZero<u128> = 0x1000000000000000;
}

mod nz64 {
    pub const P35: NonZero<u64> = 0x800000000;
}

const M25: u128 = 0x1FFFFFF;

/// PRE-CHANGE PATH: full twelve-field unpack, `TokenMetadata` build, then take
/// the lifecycle out of it. This is exactly what `is_lifecycle_open` (then
/// named `is_playable`) and `assert_lifecycle_open` did before this change.
///
/// * `token_id` — any felt252.
/// Returns the reconstructed `(start, end)` window.
#[inline(always)]
pub fn lifecycle_before(token_id: felt252) -> Lifecycle {
    packing_v270::to_token_metadata(packing_v270::unpack_token_id(token_id)).lifecycle
}

/// Arm A: two u128 DivRems and a mask; the reconstruction arithmetic stays in
/// u128 so only `start` and `end` are downcast (two checked downcasts, not
/// three).
#[inline(always)]
pub fn lifecycle_a(token_id: felt252) -> Lifecycle {
    let packed: u256 = token_id.into();
    let (rest, minted_at) = DivRem::div_rem(packed.low, nz::P35);
    let (rest, start_delay) = DivRem::div_rem(rest, nz::P25);
    let end_delay = rest & M25;
    let start = minted_at + start_delay;
    let end = if end_delay > 0 {
        start + end_delay
    } else {
        0
    };
    Lifecycle { start: start.try_into().unwrap(), end: end.try_into().unwrap() }
}

/// Arm B: as A, but each field is downcast to u64 first and the reconstruction
/// runs in u64 (three checked downcasts).
#[inline(always)]
pub fn lifecycle_b(token_id: felt252) -> Lifecycle {
    let packed: u256 = token_id.into();
    let (rest, minted_at) = DivRem::div_rem(packed.low, nz::P35);
    let (rest, start_delay) = DivRem::div_rem(rest, nz::P25);
    let minted_at: u64 = minted_at.try_into().unwrap();
    let start_delay: u64 = start_delay.try_into().unwrap();
    let end_delay: u64 = (rest & M25).try_into().unwrap();
    let start = minted_at + start_delay;
    let end = if end_delay > 0 {
        start + end_delay
    } else {
        0
    };
    Lifecycle { start, end }
}

/// Arm C: the narrowing pays HERE, unlike in the single-field accessors —
/// splitting at bit 60 yields a 60-bit word holding minted_at AND start_delay,
/// so ONE u64 DivRem produces two fields already in the return type. end_delay
/// is masked out of the u128 remainder.
#[inline(always)]
pub fn lifecycle_c(token_id: felt252) -> Lifecycle {
    let packed: u256 = token_id.into();
    let (rest, low_word) = DivRem::div_rem(packed.low, nz::P60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::P35);
    let end_delay: u64 = (rest & M25).try_into().unwrap();
    let start = minted_at + start_delay;
    let end = if end_delay > 0 {
        start + end_delay
    } else {
        0
    };
    Lifecycle { start, end }
}

/// Arm D: as C, but the end_delay downcast is moved inside the non-sentinel
/// branch, so a token with no expiration never pays for it. Gas becomes
/// input-dependent, which is why it is measured on both shapes.
#[inline(always)]
pub fn lifecycle_d(token_id: felt252) -> Lifecycle {
    let packed: u256 = token_id.into();
    let (rest, low_word) = DivRem::div_rem(packed.low, nz::P60);
    let low_word: u64 = low_word.try_into().unwrap();
    let (start_delay, minted_at) = DivRem::div_rem(low_word, nz64::P35);
    let end_delay = rest & M25;
    let start = minted_at + start_delay;
    let end = if end_delay > 0 {
        let end_delay: u64 = end_delay.try_into().unwrap();
        start + end_delay
    } else {
        0
    };
    Lifecycle { start, end }
}
