// SPDX-License-Identifier: BUSL-1.1

//! Exact payout computation in token units.
//!
//! `calculator` derives a basis-point share and leaves the caller to multiply
//! it by the pool. That costs precision twice over: the share is computed in
//! 32.32 fixed point (Cubit `pow`, `exp`, `ln`), and it is then truncated into
//! a u16 whose resolution is 1/10000 of the pool.
//!
//! This module computes the payout directly:
//!
//!     payout(p) = total_amount * W(p) / sum(W)
//!
//! in u256 integer arithmetic, where `W` is an exact integer weight and
//! `sum(W)` has a closed form. Three consequences:
//!
//! 1. **O(1), independent of the number of paid places.** No per-position
//!    loop, no allocation, no `pow`. A 1000-place prize costs the same as a
//!    2-place one.
//! 2. **No unclaimable positions.** The smallest payout is 1 wei rather than
//!    1 basis point, so a tail position only rounds away when its true share
//!    is under one indivisible unit of the token. Under the basis-point path,
//!    a steep 100-place curve silently gives late positions exactly 0 — and
//!    Budokan asserts `prize_amount > 0`, so those players cannot claim at
//!    all.
//! 3. **Dust stops mattering.** Basis-point truncation strands up to
//!    `n / 10000` of the pool (0.5% of a 100-place prize), which is why
//!    `calculate_share_with_dust` exists and why payout index 1 has to sum
//!    every position. Here the truncation remainder is under `n` wei, so
//!    there is nothing worth redistributing and every position — winner
//!    included — is a flat O(1) computation.
//!
//! ## Weight definitions
//!
//! Weights only ever appear as the ratio `W(p) / sum(W)`, so any common
//! scale factor cancels and they can be kept as small integers.
//!
//! | Distribution      | W(p)                | sum(W)                       |
//! | ----------------- | ------------------- | ---------------------------- |
//! | `Linear(w)`       | `10 + (n - p) * w`  | `10n + w * n(n-1)/2`         |
//! | `Exponential(w)`  | `(n - p + 1)^k`     | `sum_{j=1..n} j^k` (Faulhaber)|
//! | `Uniform`         | `1`                 | `n`                          |
//! | `Custom(shares)`  | `shares[p-1]`       | `sum(shares[0..n])`          |
//!
//! `Custom`'s sum is bounded by the paid-place count, not the array length —
//! a caller may pay fewer places than the stored curve describes, and weight
//! for positions that never pay must not sit in the denominator.
//!
//! `w` is the weight scaled by 10 (so `10` = 1.0), matching `calculator`.
//! `k = w / 10` — see `supports_exact_payout` for which weights qualify.
//!
//! ## Naming note
//!
//! `Exponential` is a power law, not an exponential: `W(p)` is polynomial in
//! the position, `(n-p+1)^k`, not `r^p`. That is a happy accident — a power
//! law has an exact closed-form sum (Faulhaber) in integers, whereas a true
//! geometric decay needs `r^n` in rationals and overflows or needs fixed
//! point. The existing curve shape is the one that computes cheaply.

use crate::distribution::structs::Distribution;

/// Highest supported integer exponent for `Exponential`.
///
/// Faulhaber closed forms are enumerated up to this power. Prize curves in
/// practice sit at k = 1..3 (a k=3 curve over 100 places already pays first
/// place a million times last place); the cap keeps `W(p) * total_amount`
/// clear of u256 overflow for any realistic pool.
pub const MAX_EXACT_EXPONENT: u32 = 5;

/// Whether `calculate_payout` can compute this distribution exactly.
///
/// `Exponential` qualifies when its weight is a whole multiple of 10 (an
/// integer exponent) no greater than `MAX_EXACT_EXPONENT`. Fractional
/// exponents such as 1.5 have no closed-form power sum, so they stay on the
/// `calculator` path. `Linear`, `Uniform` and `Custom` always qualify.
pub fn supports_exact_payout(distribution: Distribution) -> bool {
    match distribution {
        Distribution::Exponential(weight) => {
            let w: u32 = weight.into();
            w % 10 == 0 && w != 0 && (w / 10) <= MAX_EXACT_EXPONENT
        },
        _ => true,
    }
}

/// sum_{j=1..n} j^k for k in 1..=MAX_EXACT_EXPONENT (Faulhaber).
///
/// Every expression below is an integer identity, so multiplying before
/// dividing is exact — the numerators are divisible by the constants shown.
fn power_sum(k: u32, n: u256) -> u256 {
    let n1 = n + 1;
    if k == 1 {
        n * n1 / 2
    } else if k == 2 {
        n * n1 * (2 * n + 1) / 6
    } else if k == 3 {
        n * n * n1 * n1 / 4
    } else if k == 4 {
        n * n1 * (2 * n + 1) * (3 * n * n + 3 * n - 1) / 30
    } else if k == 5 {
        n * n * n1 * n1 * (2 * n * n + 2 * n - 1) / 12
    } else {
        panic!("Distribution: exponent {} exceeds the exact payout range", k)
    }
}

fn int_pow(base: u256, exponent: u32) -> u256 {
    let mut acc: u256 = 1;
    let mut i: u32 = 0;
    while i < exponent {
        acc = acc * base;
        i += 1;
    }
    acc
}

/// The unnormalized integer weight of one payout position, 1-indexed.
/// Returns 0 when `payout_index` falls outside 1..=total_payouts.
pub(crate) fn payout_weight(
    distribution: Distribution, payout_index: u32, total_payouts: u32,
) -> u256 {
    if payout_index == 0 || payout_index > total_payouts {
        return 0;
    }

    match distribution {
        Distribution::Linear(weight) => {
            let w: u256 = weight.into();
            10 + (total_payouts - payout_index).into() * w
        },
        Distribution::Exponential(weight) => {
            let k: u32 = weight.into() / 10;
            int_pow((total_payouts - payout_index + 1).into(), k)
        },
        Distribution::Uniform => 1,
        Distribution::Custom(shares) => {
            let index: u32 = payout_index - 1;
            if index >= shares.len() {
                0
            } else {
                let share: u16 = *shares.at(index);
                share.into()
            }
        },
    }
}

/// The sum of every position's weight — the normalization denominator.
///
/// Crate-internal: unlike `calculate_payout` this does not gate on
/// `supports_exact_payout`, and `Exponential` truncates `k = weight / 10`. An
/// external caller passing a fractional weight would silently receive the k=1
/// curve rather than a panic, so the gated entry point stays the only public
/// way in.
///
/// Closed form for `Linear`, `Exponential` and `Uniform`, so this is O(1).
/// `Custom` sums its explicit array, which is inherent to the variant.
pub(crate) fn payout_weight_sum(distribution: Distribution, total_payouts: u32) -> u256 {
    if total_payouts == 0 {
        return 0;
    }
    let n: u256 = total_payouts.into();

    match distribution {
        Distribution::Linear(weight) => {
            // sum_{p=1..n} [10 + (n - p) * w] = 10n + w * n(n-1)/2
            let w: u256 = weight.into();
            10 * n + w * (n * (n - 1) / 2)
        },
        Distribution::Exponential(weight) => {
            // sum_{p=1..n} (n - p + 1)^k = sum_{j=1..n} j^k
            let k: u32 = weight.into() / 10;
            power_sum(k, n)
        },
        Distribution::Uniform => n,
        Distribution::Custom(shares) => {
            // Sum only the positions that actually get paid. `payout_weight`
            // returns 0 for an index past `total_payouts` (and past the array),
            // so counting the whole array here would put weight for unpaid
            // positions into the denominator and shrink every payout — the
            // shortfall being the truncated tail's full weight, not the
            // sub-`n`-unit rounding this module otherwise guarantees.
            //
            // The two parameters are independent: a caller may pay fewer places
            // than the stored curve describes.
            let mut total: u256 = 0;
            let mut i: u32 = 0;
            let len = if shares.len() < total_payouts {
                shares.len()
            } else {
                total_payouts
            };
            while i < len {
                let share: u16 = *shares.at(i);
                total += share.into();
                i += 1;
            }
            total
        },
    }
}

/// The payout for one position, in token units.
///
/// `payout_index` is 1-indexed; `total_amount` is the whole pool being
/// distributed across `total_payouts` positions. Returns 0 for an
/// out-of-range index.
///
/// Truncation is downward, so the payouts sum to at most `total_amount`; the
/// shortfall is under `total_payouts` indivisible units and is deliberately
/// not redistributed (see the module docs on dust).
///
/// Panics for a distribution `supports_exact_payout` rejects — callers must
/// check first rather than silently receiving a different curve.
///
/// ## Overflow envelope
///
/// The largest intermediate is `total_amount * W(1) = total_amount * n^k`, so
/// `Exponential` has a ceiling in `(total_payouts, k, total_amount)` past which
/// this reverts rather than returning a wrong number. Against a pool of 10^27
/// (a billion tokens at 18 decimals), which is far beyond any realistic
/// tournament:
///
/// | `total_payouts` | highest safe `k` |
/// | --------------- | ---------------- |
/// | 100             | 18 (i.e. any k)  |
/// | 1,000           | 15               |
/// | 10,000          | 13               |
///
/// `MAX_EXACT_EXPONENT` is 5, so every accepted curve sits well inside this at
/// any field size the leaderboard can hold. The bound only becomes reachable if
/// that cap is raised, which is why it is written down here.
pub fn calculate_payout(
    distribution: Distribution, payout_index: u32, total_payouts: u32, total_amount: u256,
) -> u256 {
    assert!(
        supports_exact_payout(distribution),
        "Distribution: weight has no exact payout form; use the basis-point path",
    );

    if payout_index == 0 || payout_index > total_payouts || total_amount == 0 {
        return 0;
    }

    let denominator = payout_weight_sum(distribution, total_payouts);
    if denominator == 0 {
        return 0;
    }

    let weight = payout_weight(distribution, payout_index, total_payouts);
    total_amount * weight / denominator
}
