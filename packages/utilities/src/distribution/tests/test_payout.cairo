// SPDX-License-Identifier: BUSL-1.1

//! Correctness for exact token-unit payouts.
//!
//! The properties worth holding onto, in order of how much money they move:
//!
//! 1. payouts never exceed the pool, and the shortfall is under `n` units;
//! 2. no position is paid 0 for any realistic pool — the failure that makes
//!    a position unclaimable under the basis-point path;
//! 3. the curve is monotonically non-increasing;
//! 4. the ratios match the basis-point path (which is the same mathematics
//!    computed less precisely), so the shape does not change.

use crate::distribution::calculator::calculate_share;
use crate::distribution::payout::{
    MAX_EXACT_EXPONENT, calculate_payout, max_geometric_payouts, payout_weight, payout_weight_sum,
    supports_exact_payout,
};
use crate::distribution::structs::{BASIS_POINTS, Distribution, TieredConfig};

/// 1000 tokens at 18 decimals — an ordinary prize pool.
const POOL: u256 = 1000_000000000000000000;

fn sum_payouts(dist: Distribution, n: u32, amount: u256) -> u256 {
    let mut total: u256 = 0;
    let mut p: u32 = 1;
    while p <= n {
        total += calculate_payout(dist, p, n, amount);
        p += 1;
    }
    total
}

// ==========================================================================
// CONSERVATION — never overpay, and lose at most n units to truncation
// ==========================================================================

#[test]
fn test_payouts_never_exceed_the_pool() {
    let dists = array![
        Distribution::Linear(10), Distribution::Linear(25), Distribution::Exponential(10),
        Distribution::Exponential(20), Distribution::Exponential(30), Distribution::Uniform,
    ];
    for dist in dists {
        let mut n: u32 = 1;
        while n <= 40 {
            let paid = sum_payouts(dist, n, POOL);
            assert!(paid <= POOL, "overpaid at n={}", n);
            assert!(POOL - paid < n.into(), "lost more than n units at n={}", n);
            n += 1;
        }
    };
}

// ==========================================================================
// NO DEAD POSITIONS — the whole point of working in token units
// ==========================================================================

/// The basis-point path gives late positions exactly 0 on a steep 100-place
/// curve, which Budokan rejects with `prize_amount > 0`. Same curve, same
/// pool, computed in token units: everyone is paid.
#[test]
fn test_no_zero_payouts_where_basis_points_die() {
    let dist = Distribution::Exponential(30); // k = 3, steep
    let n: u32 = 100;

    let mut zero_shares: u32 = 0;
    let mut p: u32 = 1;
    while p <= n {
        if calculate_share(dist, p, n, BASIS_POINTS) == 0 {
            zero_shares += 1;
        }
        assert!(calculate_payout(dist, p, n, POOL) > 0, "position {} paid nothing", p);
        p += 1;
    }

    // Guard the premise: if this curve ever stops starving the basis-point
    // path, the test above stops proving anything.
    assert!(zero_shares > 0, "expected the bps path to zero out some positions");
}

#[test]
fn test_no_zero_payouts_at_one_thousand_places() {
    let dist = Distribution::Linear(10);
    let n: u32 = 1000;
    let mut p: u32 = 1;
    while p <= n {
        assert!(calculate_payout(dist, p, n, POOL) > 0, "position {} paid nothing", p);
        p += 1;
    }
}

// ==========================================================================
// SHAPE — non-increasing, and matching the basis-point curve
// ==========================================================================

#[test]
fn test_payouts_are_monotonically_non_increasing() {
    let dists = array![
        Distribution::Linear(10), Distribution::Linear(50), Distribution::Exponential(10),
        Distribution::Exponential(20), Distribution::Exponential(50),
    ];
    for dist in dists {
        let n: u32 = 50;
        let mut previous = calculate_payout(dist, 1, n, POOL);
        let mut p: u32 = 2;
        while p <= n {
            let current = calculate_payout(dist, p, n, POOL);
            assert!(current <= previous, "payout rose at position {}", p);
            previous = current;
            p += 1;
        }
    };
}

/// Same curve as the basis-point path: scaling a payout back into basis
/// points reproduces `calculate_share` to within the 1 bps that the fixed
/// point implementation loses to rounding.
#[test]
fn test_matches_the_basis_point_curve() {
    let dists = array![
        Distribution::Linear(10), Distribution::Linear(25), Distribution::Exponential(10),
        Distribution::Exponential(20),
    ];
    for dist in dists {
        let mut n: u32 = 1;
        while n <= 30 {
            let mut p: u32 = 1;
            while p <= n {
                let bps = calculate_share(dist, p, n, BASIS_POINTS);
                // Payout of a 10000-unit pool IS the basis-point share.
                let payout = calculate_payout(dist, p, n, 10000);
                let payout_u16: u16 = payout.try_into().unwrap();
                let diff = if payout_u16 > bps {
                    payout_u16 - bps
                } else {
                    bps - payout_u16
                };
                assert!(diff <= 1, "curve moved at n={} p={}: {} vs {}", n, p, bps, payout_u16);
                p += 1;
            }
            n += 1;
        }
    };
}

// ==========================================================================
// EXACTNESS — hand-checkable values
// ==========================================================================

#[test]
fn test_uniform_splits_exactly() {
    let dist = Distribution::Uniform;
    let mut p: u32 = 1;
    while p <= 4 {
        assert!(calculate_payout(dist, p, 4, 1000) == 250, "quarter each");
        p += 1;
    }
}

/// Linear weight 1.0 over 4 places: weights 4:3:2:1, sum 10.
#[test]
fn test_linear_weights_are_exact() {
    let dist = Distribution::Linear(10);
    assert!(payout_weight_sum(dist, 4) == 100, "sum of 40+30+20+10");
    assert!(payout_weight(dist, 1, 4) == 40, "first");
    assert!(payout_weight(dist, 4, 4) == 10, "last");
    assert!(calculate_payout(dist, 1, 4, 1000) == 400, "first takes 4/10");
    assert!(calculate_payout(dist, 4, 4, 1000) == 100, "last takes 1/10");
}

/// Exponential k=2 over 3 places: weights 9:4:1, sum 14 = Faulhaber(2, 3).
#[test]
fn test_exponential_weights_are_exact() {
    let dist = Distribution::Exponential(20);
    assert!(payout_weight_sum(dist, 3) == 14, "1 + 4 + 9");
    assert!(payout_weight(dist, 1, 3) == 9, "first");
    assert!(payout_weight(dist, 2, 3) == 4, "second");
    assert!(payout_weight(dist, 3, 3) == 1, "third");
    assert!(calculate_payout(dist, 1, 3, 1400) == 900, "9/14");
    assert!(calculate_payout(dist, 2, 3, 1400) == 400, "4/14");
    assert!(calculate_payout(dist, 3, 3, 1400) == 100, "1/14");
}

/// Every Faulhaber branch against a directly summed reference.
#[test]
fn test_power_sums_match_direct_summation() {
    let mut k: u32 = 1;
    while k <= MAX_EXACT_EXPONENT {
        let weight: u16 = (k * 10).try_into().unwrap();
        let dist = Distribution::Exponential(weight);
        let mut n: u32 = 1;
        while n <= 25 {
            let mut reference: u256 = 0;
            let mut p: u32 = 1;
            while p <= n {
                reference += payout_weight(dist, p, n);
                p += 1;
            }
            assert!(payout_weight_sum(dist, n) == reference, "power sum k={} n={} wrong", k, n);
            n += 1;
        }
        k += 1;
    }
}

// ==========================================================================
// GUARDS
// ==========================================================================

#[test]
fn test_fractional_exponents_are_rejected_not_approximated() {
    assert!(!supports_exact_payout(Distribution::Exponential(15)), "1.5 has no closed form");
    assert!(!supports_exact_payout(Distribution::Exponential(25)), "2.5 has no closed form");
    assert!(supports_exact_payout(Distribution::Exponential(30)), "3.0 does");
    assert!(supports_exact_payout(Distribution::Linear(15)), "linear is exact at any weight");
    assert!(supports_exact_payout(Distribution::Uniform), "uniform is exact");
}

#[test]
#[should_panic(expected: "Distribution: weight has no exact payout form; use the basis-point path")]
fn test_fractional_exponent_payout_panics() {
    calculate_payout(Distribution::Exponential(15), 1, 10, POOL);
}

#[test]
fn test_exponent_above_the_supported_range_is_rejected() {
    let too_steep: u16 = ((MAX_EXACT_EXPONENT + 1) * 10).try_into().unwrap();
    assert!(!supports_exact_payout(Distribution::Exponential(too_steep)), "beyond the cap");
}

#[test]
fn test_out_of_range_and_empty_inputs() {
    let dist = Distribution::Linear(10);
    assert!(calculate_payout(dist, 0, 10, POOL) == 0, "index 0");
    assert!(calculate_payout(dist, 11, 10, POOL) == 0, "index past the end");
    assert!(calculate_payout(dist, 1, 0, POOL) == 0, "no places");
    assert!(calculate_payout(dist, 1, 10, 0) == 0, "empty pool");
    assert!(payout_weight_sum(dist, 0) == 0, "no places, no weight");
}

#[test]
fn test_custom_uses_its_explicit_shares() {
    let shares: Array<u16> = array![5000, 3000, 2000];
    let dist = Distribution::Custom(shares.span());
    assert!(payout_weight_sum(dist, 3) == 10000, "sums the array");
    assert!(calculate_payout(dist, 1, 3, 1000) == 500, "half");
    assert!(calculate_payout(dist, 2, 3, 1000) == 300, "three tenths");
    assert!(calculate_payout(dist, 3, 3, 1000) == 200, "one fifth");
}

/// Paying fewer places than the stored curve describes must not strand funds.
///
/// `payout_weight` yields 0 past `total_payouts`, so the denominator has to
/// stop there too. Summing the whole array instead would leave the truncated
/// tail's weight in the denominator — here 2000 of 10000, silently shrinking
/// every payout by a fifth and stranding that fifth of the pool.
#[test]
fn test_custom_truncated_to_fewer_places_still_pays_the_whole_pool() {
    let shares: Array<u16> = array![5000, 3000, 2000];
    let dist = Distribution::Custom(shares.span());

    assert!(payout_weight_sum(dist, 2) == 8000, "denominator covers only paid places");

    let first = calculate_payout(dist, 1, 2, 1000);
    let second = calculate_payout(dist, 2, 2, 1000);
    assert!(first == 625, "5000/8000 of the pool, got {}", first);
    assert!(second == 375, "3000/8000 of the pool, got {}", second);
    assert!(calculate_payout(dist, 3, 2, 1000) == 0, "position past total_payouts pays nothing");

    // Conservation: the shortfall is rounding, not a truncated tail.
    assert!(first + second <= 1000, "never overpays");
    assert!(1000 - (first + second) < 2, "shortfall under one unit per paid place");
}

// ==================== Geometric ====================
//
// The property that motivates the variant: a geometric curve's shape does not
// depend on the size of the field. `Exponential` cannot do this — as a power
// law its winner share falls off as roughly (k+1)/n.

#[test]
fn test_geometric_ratio_holds_between_adjacent_positions() {
    let dist = Distribution::Geometric((10, 7));
    let pool: u256 = 1_000_000_000_000_000_000;
    let first = calculate_payout(dist, 1, 10, pool);
    let second = calculate_payout(dist, 2, 10, pool);
    assert!(first == 308720592627384808, "winner share, got {}", first);
    assert!(second == 216104414839169366, "runner-up share, got {}", second);
    // Each place takes 7/10 of the one above. Both sides are independently
    // truncated from the exact ratio, so they can differ by a unit — comparing
    // `second` against `first * 7 / 10` re-truncates an already-truncated
    // value and is off by one here.
    let expected = first * 7 / 10;
    let drift = if second > expected {
        second - expected
    } else {
        expected - second
    };
    assert!(drift <= 1, "adjacent ratio is b/a to within a unit, drifted {}", drift);
}

#[test]
fn test_geometric_winner_share_is_independent_of_field_size() {
    let dist = Distribution::Geometric((10, 7));
    let pool: u256 = 1_000_000_000_000_000_000;
    // 1 - b/a = 30%, whether the field is 10 places or 39.
    let small = calculate_payout(dist, 1, 10, pool);
    let large = calculate_payout(dist, 1, 39, pool);
    assert!(small > 308_000_000_000_000_000 && small < 309_000_000_000_000_000, "~30.9% at n=10");
    assert!(large > 299_000_000_000_000_000 && large < 301_000_000_000_000_000, "~30.0% at n=39");
}

#[test]
fn test_geometric_conserves_the_pool() {
    let dist = Distribution::Geometric((3, 2));
    let pool: u256 = 1_000_000_000_000_000_000;
    let n: u32 = 50;
    let mut total: u256 = 0;
    let mut p: u32 = 1;
    while p <= n {
        let amount = calculate_payout(dist, p, n, pool);
        assert!(amount > 0, "position {} must be payable", p);
        total += amount;
        p += 1;
    }
    assert!(total <= pool, "never overpays");
    assert!(pool - total < n.into(), "shortfall under one unit per position");
}

#[test]
fn test_max_geometric_payouts_matches_the_documented_reach() {
    assert!(max_geometric_payouts(2) == 129, "50% decay reaches 129 places");
    assert!(max_geometric_payouts(3) == 81, "2/3 decay reaches 81");
    assert!(max_geometric_payouts(7) == 46, "5/7 decay reaches 46");
    assert!(max_geometric_payouts(10) == 39, "7/10 decay reaches 39");
}

#[test]
#[should_panic(expected: "geometric ratio reaches at most 39 places")]
fn test_geometric_beyond_reach_is_refused_not_overflowed() {
    let dist = Distribution::Geometric((10, 7));
    calculate_payout(dist, 1, 40, 1_000_000_000_000_000_000);
}

#[test]
fn test_geometric_shape_guards() {
    // b must be under a (otherwise the curve is flat or inverted), non-zero,
    // and both must survive the single-u16 packed param slot.
    assert!(supports_exact_payout(Distribution::Geometric((10, 7))), "valid ratio");
    assert!(!supports_exact_payout(Distribution::Geometric((7, 10))), "inverted");
    assert!(!supports_exact_payout(Distribution::Geometric((10, 10))), "flat");
    assert!(!supports_exact_payout(Distribution::Geometric((10, 0))), "zero tail");
    assert!(!supports_exact_payout(Distribution::Geometric((256, 7))), "exceeds the u8 slot");
}

// Cost: flat, like every other exact curve.
#[test]
fn bench_payout_geometric_n39_pos1() {
    let dist = Distribution::Geometric((10, 7));
    let share = calculate_payout(dist, 1, 39, 1_000_000_000_000_000_000);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_payout_geometric_n39_pos_last() {
    let dist = Distribution::Geometric((10, 7));
    let share = calculate_payout(dist, 39, 39, 1_000_000_000_000_000_000);
    assert!(share > 0, "last-place share");
}

// ==================== Tiered ====================
//
// The variant that exists for very large fields: a geometric head with a real
// first prize, and a flat tail that still pays every remaining place. No
// single curve can do both — steep enough for the head zeroes the tail, flat
// enough for the tail erases the head.

fn flagship_tiered() -> Distribution {
    // Top 39 places on a 70% geometric decay take 80% of the pool; the other
    // places split 20% evenly.
    Distribution::Tiered(TieredConfig { head_ratio: (10, 7), head_count: 39, head_share_bps: 8000 })
}

#[test]
fn test_tiered_pays_a_headline_first_prize_over_ten_thousand_places() {
    let pool: u256 = 1_000_000_000_000_000_000;
    let n: u32 = 10000;
    let dist = flagship_tiered();

    // First place takes 24% of the whole pool — a single curve tops out at
    // ~0.06% (Exponential k=5) over the same field.
    assert!(calculate_payout(dist, 1, n, pool) == 240000218290681776, "first place");
    assert!(calculate_payout(dist, 2, n, pool) == 168000152803477243, "second place");
    // The last head place still clears its geometric slice...
    assert!(calculate_payout(dist, 39, n, pool) == 311843831108, "head boundary");
    // ...and every tail place gets an identical, non-zero share of the rest.
    let tail = calculate_payout(dist, 40, n, pool);
    assert!(tail == 20078305391024, "first tail place");
    assert!(calculate_payout(dist, 10000, n, pool) == tail, "last place matches");
}

#[test]
fn test_tiered_conserves_the_pool() {
    let pool: u256 = 1_000_000_000_000_000_000;
    let n: u32 = 10000;
    let dist = flagship_tiered();

    // Head positions summed directly; the identical tail slices multiplied.
    let mut total: u256 = 0;
    let mut p: u32 = 1;
    while p <= 39 {
        total += calculate_payout(dist, p, n, pool);
        p += 1;
    }
    total += calculate_payout(dist, 40, n, pool) * (n - 39).into();

    assert!(total <= pool, "never overpays");
    assert!(pool - total < n.into(), "shortfall under one unit per position, got {}", pool - total);
}

#[test]
fn test_tiered_shape_guards() {
    // The head follows Geometric's ratio rules; the share must leave both
    // tiers something to pay.
    let ok = TieredConfig { head_ratio: (10, 7), head_count: 39, head_share_bps: 8000 };
    assert!(supports_exact_payout(Distribution::Tiered(ok)), "valid config");

    let inverted = TieredConfig { head_ratio: (7, 10), head_count: 10, head_share_bps: 8000 };
    assert!(!supports_exact_payout(Distribution::Tiered(inverted)), "inverted ratio");

    let all_to_head = TieredConfig { head_ratio: (10, 7), head_count: 10, head_share_bps: 10000 };
    assert!(!supports_exact_payout(Distribution::Tiered(all_to_head)), "tail would be zero");

    let nothing_to_head = TieredConfig { head_ratio: (10, 7), head_count: 10, head_share_bps: 0 };
    assert!(!supports_exact_payout(Distribution::Tiered(nothing_to_head)), "head would be zero");

    let empty_head = TieredConfig { head_ratio: (10, 7), head_count: 0, head_share_bps: 8000 };
    assert!(!supports_exact_payout(Distribution::Tiered(empty_head)), "headless");
}

#[test]
#[should_panic(expected: "tiered head reaches at most 39 places")]
fn test_tiered_head_beyond_geometric_reach_is_refused() {
    let dist = Distribution::Tiered(
        TieredConfig { head_ratio: (10, 7), head_count: 40, head_share_bps: 8000 },
    );
    calculate_payout(dist, 1, 10000, 1_000_000_000_000_000_000);
}

#[test]
#[should_panic(expected: "tiered needs more paid places than its head covers")]
fn test_tiered_field_must_extend_past_the_head() {
    let dist = Distribution::Tiered(
        TieredConfig { head_ratio: (10, 7), head_count: 39, head_share_bps: 8000 },
    );
    calculate_payout(dist, 1, 39, 1_000_000_000_000_000_000);
}

#[test]
fn test_tiered_small_field_hand_check() {
    // n=10, head = top 3 on (2,1) with 60% of a 10,000 pool.
    // Head weights 4/2/1 of 7: 6000*4/7=3428, 6000*2/7=1714, 6000*1/7=857.
    // Tail: 4000 / 7 places = 571 each.
    let dist = Distribution::Tiered(
        TieredConfig { head_ratio: (2, 1), head_count: 3, head_share_bps: 6000 },
    );
    assert!(calculate_payout(dist, 1, 10, 10000) == 3428, "p1");
    assert!(calculate_payout(dist, 2, 10, 10000) == 1714, "p2");
    assert!(calculate_payout(dist, 3, 10, 10000) == 857, "p3");
    assert!(calculate_payout(dist, 4, 10, 10000) == 571, "p4");
    assert!(calculate_payout(dist, 10, 10, 10000) == 571, "p10");
    assert!(calculate_payout(dist, 11, 10, 10000) == 0, "out of range");
}

// Cost: two O(1) tiers.
#[test]
fn bench_payout_tiered_n10000_pos1() {
    let share = calculate_payout(flagship_tiered(), 1, 10000, 1_000_000_000_000_000_000);
    assert!(share > 0, "winner share");
}

#[test]
fn bench_payout_tiered_n10000_pos_last() {
    let share = calculate_payout(flagship_tiered(), 10000, 10000, 1_000_000_000_000_000_000);
    assert!(share > 0, "last-place share");
}
