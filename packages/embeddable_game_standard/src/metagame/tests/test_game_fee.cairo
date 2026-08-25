// ==============================================================================
// GAME FEE CALCULATION TESTS
// ==============================================================================
// Tests for the calculate_game_fee pure function in the metagame library.

use game_components_embeddable_game_standard::metagame::metagame::calculate_game_fee;
use game_components_interfaces::token::game_fee::{DEFAULT_GAME_FEE_BPS, FEE_DENOMINATOR};

// ==============================================================================
// BASIC CALCULATION
// ==============================================================================

#[test]
fn test_calculate_game_fee_default_5_percent() {
    // 5% of 10000 = 500
    let fee = calculate_game_fee(10000, DEFAULT_GAME_FEE_BPS);
    assert!(fee == 500, "5% of 10000 should be 500");
}

#[test]
fn test_calculate_game_fee_10_percent() {
    // 10% of 10000 = 1000
    let fee = calculate_game_fee(10000, 1000);
    assert!(fee == 1000, "10% of 10000 should be 1000");
}

#[test]
fn test_calculate_game_fee_1_percent() {
    let fee = calculate_game_fee(10000, 100);
    assert!(fee == 100, "1% of 10000 should be 100");
}

#[test]
fn test_calculate_game_fee_100_percent() {
    let fee = calculate_game_fee(10000, FEE_DENOMINATOR);
    assert!(fee == 10000, "100% of 10000 should be 10000");
}

// ==============================================================================
// EDGE CASES
// ==============================================================================

#[test]
fn test_calculate_game_fee_zero_revenue() {
    let fee = calculate_game_fee(0, DEFAULT_GAME_FEE_BPS);
    assert!(fee == 0, "Fee on zero revenue should be 0");
}

#[test]
fn test_calculate_game_fee_zero_numerator() {
    let fee = calculate_game_fee(10000, 0);
    assert!(fee == 0, "Fee with zero numerator should be 0");
}

#[test]
fn test_calculate_game_fee_both_zero() {
    let fee = calculate_game_fee(0, 0);
    assert!(fee == 0, "Both zero should return 0");
}

#[test]
fn test_calculate_game_fee_small_revenue() {
    // 5% of 10 = 0 (integer division rounds down)
    let fee = calculate_game_fee(10, DEFAULT_GAME_FEE_BPS);
    assert!(fee == 0, "5% of 10 should be 0 due to integer division");
}

#[test]
fn test_calculate_game_fee_rounding_down() {
    // 5% of 199 = 9.95 -> 9
    let fee = calculate_game_fee(199, DEFAULT_GAME_FEE_BPS);
    assert!(fee == 9, "Should round down to 9");
}

#[test]
fn test_calculate_game_fee_1_basis_point() {
    // 0.01% of 1000000 = 100
    let fee = calculate_game_fee(1000000, 1);
    assert!(fee == 100, "1 bps of 1000000 should be 100");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 256)]
fn test_fuzz_calculate_game_fee_never_exceeds_revenue(revenue: u128, fee_bps: u16) {
    if fee_bps > FEE_DENOMINATOR {
        return;
    }
    let fee = calculate_game_fee(revenue, fee_bps);
    assert!(fee <= revenue, "Fee should never exceed revenue");
}

#[test]
#[fuzzer(runs: 256)]
fn test_fuzz_calculate_game_fee_proportional(revenue: u128) {
    if revenue > 0xFFFFFFFFFFFFFFFF {
        return; // Avoid overflow
    }
    // fee at 100% should equal revenue
    let fee_full = calculate_game_fee(revenue, FEE_DENOMINATOR);
    assert!(fee_full == revenue, "100% fee should equal revenue");

    // fee at 0% should be 0
    let fee_zero = calculate_game_fee(revenue, 0);
    assert!(fee_zero == 0, "0% fee should be 0");
}
