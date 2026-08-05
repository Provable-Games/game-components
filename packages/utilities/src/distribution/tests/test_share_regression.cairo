// SPDX-License-Identifier: BUSL-1.1

//! Locked share values for the weighted distributions.
//!
//! These are real payout splits — a live tournament's prize is divided by
//! exactly these basis points. The correctness tests elsewhere assert
//! *ranges* ("~50%"), which is the right shape for "is the curve sane" but
//! would not catch a refactor that shifts a share by a few bps. This file
//! pins the exact fixed-point output.
//!
//! If a change here fails, that is not a test to update — it means payouts
//! moved. Existing tournaments were created against these numbers, so a
//! deliberate change needs a migration story, not a new expected value.
//!
//! Values verified identical before and after the O(n^2) -> O(n) hoist in
//! `calculator.cairo` by sweeping the old and new implementations against each
//! other across every payout index of every size 1..=12, for Linear (weights
//! 10/25/7), Exponential (weights 10/15/25/100) and Uniform, at both full and
//! partial `available_share`.

use crate::distribution::calculator::{calculate_share, calculate_share_with_dust, calculate_total};
use crate::distribution::structs::{BASIS_POINTS, Distribution};

/// Exponential weight 10 over 10 places — the shape used by live Budokan
/// tournaments (and the one benchmarked in `test_gas_benchmark`).
#[test]
fn test_exponential_w10_n10_exact_shares() {
    let dist = Distribution::Exponential(10);
    let expected = array![1818_u16, 1636, 1454, 1272, 1090, 909, 727, 545, 363, 181];

    let mut p: u32 = 1;
    for e in expected {
        assert!(
            calculate_share(dist, p, 10, BASIS_POINTS) == e,
            "exp w10 n10 position {} share changed",
            p,
        );
        p += 1;
    }

    // Truncation leaves 5 bps unallocated; the winner absorbs it.
    assert!(calculate_total(dist, 10, BASIS_POINTS) == 9995, "exp w10 n10 total");
    assert!(
        calculate_share_with_dust(dist, 1, 10, BASIS_POINTS) == 1823, "exp w10 n10 winner + dust",
    );
}

/// Fractional weight — exercises the `exp(y * ln(x))` branch of `pow`.
#[test]
fn test_exponential_w15_n5_exact_shares() {
    let dist = Distribution::Exponential(15);
    let expected = array![3964_u16, 2836, 1842, 1002, 354];

    let mut p: u32 = 1;
    for e in expected {
        assert!(
            calculate_share(dist, p, 5, BASIS_POINTS) == e,
            "exp w15 n5 position {} share changed",
            p,
        );
        p += 1;
    }

    assert!(calculate_total(dist, 5, BASIS_POINTS) == 9998, "exp w15 n5 total");
    assert!(
        calculate_share_with_dust(dist, 1, 5, BASIS_POINTS) == 3966, "exp w15 n5 winner + dust",
    );
}

#[test]
fn test_linear_w10_n5_exact_shares() {
    let dist = Distribution::Linear(10);
    let expected = array![3333_u16, 2666, 1999, 1333, 666];

    let mut p: u32 = 1;
    for e in expected {
        assert!(
            calculate_share(dist, p, 5, BASIS_POINTS) == e,
            "linear w10 n5 position {} share changed",
            p,
        );
        p += 1;
    }

    assert!(calculate_total(dist, 5, BASIS_POINTS) == 9997, "linear w10 n5 total");
    assert!(
        calculate_share_with_dust(dist, 1, 5, BASIS_POINTS) == 3336, "linear w10 n5 winner + dust",
    );
}

#[test]
fn test_linear_w25_n4_exact_shares() {
    let dist = Distribution::Linear(25);
    let expected = array![4473_u16, 3157, 1842, 526];

    let mut p: u32 = 1;
    for e in expected {
        assert!(
            calculate_share(dist, p, 4, BASIS_POINTS) == e,
            "linear w25 n4 position {} share changed",
            p,
        );
        p += 1;
    }

    assert!(calculate_total(dist, 4, BASIS_POINTS) == 9998, "linear w25 n4 total");
    assert!(
        calculate_share_with_dust(dist, 1, 4, BASIS_POINTS) == 4475, "linear w25 n4 winner + dust",
    );
}

/// Dust is only ever added to payout index 1, and always closes the gap to
/// `available_share` exactly.
#[test]
fn test_dust_closes_the_gap_exactly() {
    let dists = array![
        Distribution::Linear(10), Distribution::Linear(25), Distribution::Exponential(10),
        Distribution::Exponential(15),
    ];

    for dist in dists {
        let mut n: u32 = 1;
        while n <= 8 {
            let mut paid: u16 = calculate_share_with_dust(dist, 1, n, BASIS_POINTS);
            let mut p: u32 = 2;
            while p <= n {
                paid += calculate_share_with_dust(dist, p, n, BASIS_POINTS);
                p += 1;
            }
            assert!(paid == BASIS_POINTS, "shares + dust must total 100% at n={}", n);
            n += 1;
        }
    };
}

/// A zero-position distribution hands the whole share to payout index 1 as
/// dust. Preserved deliberately from the pre-hoist implementation — callers
/// (Budokan's `_claim_distributed_prize`) can reach this with an empty
/// leaderboard and no configured `distribution_count`.
#[test]
fn test_zero_payouts_gives_everything_to_index_one_as_dust() {
    let dists = array![Distribution::Linear(10), Distribution::Exponential(10)];
    for dist in dists {
        assert!(
            calculate_share(dist, 1, 0, BASIS_POINTS) == 0, "no share when there are no places",
        );
        assert!(calculate_total(dist, 0, BASIS_POINTS) == 0, "no total when there are no places");
        assert!(
            calculate_share_with_dust(dist, 1, 0, BASIS_POINTS) == BASIS_POINTS,
            "index 1 absorbs the full share as dust",
        );
    };
}
