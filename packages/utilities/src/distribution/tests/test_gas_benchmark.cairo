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
