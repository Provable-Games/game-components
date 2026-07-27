// SPDX-License-Identifier: BUSL-1.1

//! Gas benchmark for distribution share computation.
//!
//! These tests assert nothing about *values* — the correctness suite in
//! `calculator.cairo` owns that. They exist so `snforge test gas_benchmark`
//! reports a comparable `l2_gas` figure per shape, making the cost curve of
//! `calculate_share` / `calculate_share_with_dust` visible in CI.
//!
//! Read the numbers as: cost(bench_X) - cost(bench_baseline_overhead).
//!
//! The shapes that matter, and why:
//!
//! * `pos1` vs `pos_last` — payout index 1 additionally pays for
//!   `calculate_dust`, which sums *every* position's share. Winners are the
//!   expensive claim; everyone else is cheap.
//! * `w10` vs `w15` — `FixedTrait::pow` short-circuits to `pow_int` when the
//!   exponent is a whole number. Weight 10 (= 1.0) takes that fast path;
//!   weight 15 (= 1.5) falls through to `exp(y * ln(x))`, which is roughly an
//!   order of magnitude dearer per call.
//! * growing `n` — the per-share normalization loop is O(n), so a winner's
//!   claim that re-derives it per position is O(n^2).
//!
//! `exp_w10_n10_pos1` is the live shape behind Budokan tournament 26
//! (Exponential weight 10, 10 paid places, single entrant claiming 1st).
//!
//! Precision note, relevant to the large-`n` benchmarks: shares are u16 basis
//! points, so a position whose normalized weight is below 1/10000 of the pool
//! truncates to 0. For Linear weight 10 that starts around 140 places (the
//! weights sum to n(n+1)/2, so the last place gets 10000 * 1 / 20100 = 0 at
//! n=200); Exponential tails off sooner still. This is a property of the
//! basis-point representation, not of any particular implementation — but it
//! means a sufficiently large weighted prize has positions that can never be
//! claimed, because Budokan asserts `prize_amount > 0`. Hence the relaxed
//! assertions on the `n200`/`n1000` tail benchmarks.

use crate::distribution::calculator::{calculate_share, calculate_share_with_dust};
use crate::distribution::structs::{BASIS_POINTS, Distribution};

// ==========================================================================
// BASELINE — harness overhead with no share computation
// ==========================================================================

#[test]
fn bench_baseline_overhead() {
    let dist = Distribution::Uniform;
    let share = calculate_share(dist, 1, 1, BASIS_POINTS);
    assert!(share == BASIS_POINTS, "single uniform payout takes everything");
}

// ==========================================================================
// EXPONENTIAL, WEIGHT 10 (1.0 — integer exponent, pow_int fast path)
// ==========================================================================

#[test]
fn bench_exp_w10_n10_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 10, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n10_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 10, 10, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

#[test]
fn bench_exp_w10_n25_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 25, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n50_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 50, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n50_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 50, 50, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

// ==========================================================================
// EXPONENTIAL, WEIGHT 15 (1.5 — fractional exponent, exp(y * ln(x)) path)
// ==========================================================================

#[test]
fn bench_exp_w15_n10_pos1() {
    let dist = Distribution::Exponential(15);
    let share = calculate_share_with_dust(dist, 1, 10, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w15_n10_pos_last() {
    let dist = Distribution::Exponential(15);
    let share = calculate_share_with_dust(dist, 10, 10, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

#[test]
fn bench_exp_w15_n25_pos1() {
    let dist = Distribution::Exponential(15);
    let share = calculate_share_with_dust(dist, 1, 25, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

// ==========================================================================
// ALLOCATION CROSSOVER
//
// The weight vector is materialized into an `Array<Fixed>`, which the
// per-position implementation never did. That allocation buys nothing on
// paths that were not quadratic to begin with:
//
//   * non-winner positions — they never summed every share, so they pay
//     append + read cost against no saving;
//   * very small `n` — n^2 and n are the same order when n is 1 or 2.
//
// These benchmarks bracket both, so the crossover is measured rather than
// assumed. Compare against the same shapes on the pre-hoist implementation.
// ==========================================================================

#[test]
fn bench_exp_w10_n1_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 1, BASIS_POINTS);
    assert!(share > 0, "sole payout");
}

#[test]
fn bench_exp_w10_n2_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 2, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n3_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 3, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n3_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 3, 3, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

#[test]
fn bench_exp_w10_n100_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 100, 100, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

#[test]
fn bench_exp_w10_n200_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 200, 200, BASIS_POINTS);
    // The tail rounds to 0 bps at this size — see the precision note above.
    assert!(share <= BASIS_POINTS, "share must stay within basis points");
}

#[test]
fn bench_linear_w10_n200_pos_last() {
    let dist = Distribution::Linear(10);
    let share = calculate_share_with_dust(dist, 200, 200, BASIS_POINTS);
    // The tail rounds to 0 bps at this size — see the precision note above.
    assert!(share <= BASIS_POINTS, "share must stay within basis points");
}

// ==========================================================================
// CEILING — very large paid-place counts
//
// `distribution_count` is a u32, so nothing in the type system stops a
// 1000-place prize. These pin what the winner's claim actually costs there,
// which is the number to check a transaction budget against before allowing
// a tournament to be created with that shape.
// ==========================================================================

#[test]
fn bench_exp_w10_n500_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 500, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n1000_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 1000, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n1000_pos_last() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1000, 1000, BASIS_POINTS);
    // The tail rounds to 0 bps at this size — see the precision note above.
    assert!(share <= BASIS_POINTS, "share must stay within basis points");
}

#[test]
fn bench_custom_n1000_pos1() {
    // Custom is the O(1) comparison point: an explicit shares array, no
    // normalization, no pow — what a 1000-place prize costs when the curve
    // is precomputed off-chain instead of derived on-chain.
    let mut shares: Array<u16> = array![];
    let mut i: u32 = 0;
    while i < 1000 {
        shares.append(10);
        i += 1;
    }
    let dist = Distribution::Custom(shares.span());
    let share = calculate_share_with_dust(dist, 1, 1000, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

// ==========================================================================
// LINEAR (fixed-point multiplies, no pow)
// ==========================================================================

#[test]
fn bench_linear_w10_n10_pos1() {
    let dist = Distribution::Linear(10);
    let share = calculate_share_with_dust(dist, 1, 10, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_linear_w10_n10_pos_last() {
    let dist = Distribution::Linear(10);
    let share = calculate_share_with_dust(dist, 10, 10, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}

#[test]
fn bench_linear_w10_n50_pos1() {
    let dist = Distribution::Linear(10);
    let share = calculate_share_with_dust(dist, 1, 50, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

// ==========================================================================
// UNIFORM / CUSTOM — the O(1) distributions, for scale
// ==========================================================================

#[test]
fn bench_uniform_n50_pos1() {
    let dist = Distribution::Uniform;
    let share = calculate_share_with_dust(dist, 1, 50, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_custom_n10_pos1() {
    let shares: Array<u16> = array![5000, 2000, 1000, 500, 500, 250, 250, 250, 150, 100];
    let dist = Distribution::Custom(shares.span());
    let share = calculate_share_with_dust(dist, 1, 10, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_exp_w10_n100_pos1() {
    let dist = Distribution::Exponential(10);
    let share = calculate_share_with_dust(dist, 1, 100, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_custom_n100_pos1() {
    let mut shares: Array<u16> = array![];
    let mut i: u32 = 0;
    while i < 100 {
        shares.append(100);
        i += 1;
    }
    let dist = Distribution::Custom(shares.span());
    let share = calculate_share_with_dust(dist, 1, 100, BASIS_POINTS);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_custom_n100_pos_last() {
    let mut shares: Array<u16> = array![];
    let mut i: u32 = 0;
    while i < 100 {
        shares.append(100);
        i += 1;
    }
    let dist = Distribution::Custom(shares.span());
    let share = calculate_share_with_dust(dist, 100, 100, BASIS_POINTS);
    assert!(share > 0, "last-place share");
}
