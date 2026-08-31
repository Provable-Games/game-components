/// Tests for tokenomics constants
///
/// Verifies that all error constants and TWAMM-related constants have the expected values.
/// These tests ensure error messages remain stable for downstream integrations.

use core::num::traits::Pow;
use game_components_economy::tokenomics::constants::{
    ERC20_DECIMALS, ERC20_UNIT, Errors, TWAMM_BOUNDS, TWAMM_TICK_SPACING,
};

// ============================================================================
// Buyback Initialization Error Constants
// ============================================================================

#[test]
fn test_error_invalid_buy_token() {
    assert!(Errors::INVALID_BUY_TOKEN == 'Invalid buy token', "Error message mismatch");
}

#[test]
fn test_error_invalid_treasury() {
    assert!(Errors::INVALID_TREASURY == 'Invalid treasury address', "Error message mismatch");
}

#[test]
fn test_error_invalid_positions_address() {
    assert!(
        Errors::INVALID_POSITIONS_ADDRESS == 'Invalid positions address', "Error message mismatch",
    );
}

#[test]
fn test_error_invalid_extension_address() {
    assert!(
        Errors::INVALID_EXTENSION_ADDRESS == 'Invalid extension address', "Error message mismatch",
    );
}

#[test]
fn test_error_already_initialized() {
    assert!(Errors::ALREADY_INITIALIZED == 'Already initialized', "Error message mismatch");
}

#[test]
fn test_error_not_initialized() {
    assert!(Errors::NOT_INITIALIZED == 'Not initialized', "Error message mismatch");
}

// ============================================================================
// Buy Back Error Constants
// ============================================================================

#[test]
fn test_error_invalid_sell_token() {
    assert!(Errors::INVALID_SELL_TOKEN == 'Invalid sell token', "Error message mismatch");
}

#[test]
fn test_error_sell_token_is_buy_token() {
    assert!(Errors::SELL_TOKEN_IS_BUY_TOKEN == 'Sell token is buy token', "Error message mismatch");
}

#[test]
fn test_error_no_balance_to_buyback() {
    assert!(Errors::NO_BALANCE_TO_BUYBACK == 'No balance to buyback', "Error message mismatch");
}

#[test]
fn test_error_amount_below_minimum() {
    assert!(Errors::AMOUNT_BELOW_MINIMUM == 'Amount below minimum', "Error message mismatch");
}

#[test]
fn test_error_balance_overflow() {
    assert!(Errors::BALANCE_OVERFLOW == 'Balance overflow', "Error message mismatch");
}

// ============================================================================
// Timing Error Constants
// ============================================================================

#[test]
fn test_error_end_time_in_past() {
    assert!(Errors::END_TIME_IN_PAST == 'End time must be in future', "Error message mismatch");
}

#[test]
fn test_error_end_time_invalid() {
    assert!(Errors::END_TIME_INVALID == 'End time must be after start', "Error message mismatch");
}

#[test]
fn test_error_duration_too_short() {
    assert!(Errors::DURATION_TOO_SHORT == 'Duration too short', "Error message mismatch");
}

#[test]
fn test_error_duration_too_long() {
    assert!(Errors::DURATION_TOO_LONG == 'Duration too long', "Error message mismatch");
}

#[test]
fn test_error_start_time_too_soon() {
    assert!(Errors::START_TIME_TOO_SOON == 'Start time too soon', "Error message mismatch");
}

#[test]
fn test_error_delay_too_short() {
    assert!(Errors::DELAY_TOO_SHORT == 'Delay too short', "Error message mismatch");
}

#[test]
fn test_error_delay_too_long() {
    assert!(Errors::DELAY_TOO_LONG == 'Delay too long', "Error message mismatch");
}

// ============================================================================
// Claim Error Constants
// ============================================================================

#[test]
fn test_error_no_orders_to_claim() {
    assert!(Errors::NO_ORDERS_TO_CLAIM == 'No orders to claim', "Error message mismatch");
}

#[test]
fn test_error_no_completed_orders() {
    assert!(Errors::NO_COMPLETED_ORDERS == 'No completed orders', "Error message mismatch");
}

#[test]
fn test_error_position_not_initialized() {
    assert!(
        Errors::POSITION_NOT_INITIALIZED == 'Position not initialized', "Error message mismatch",
    );
}

// ============================================================================
// Sweep Error Constants
// ============================================================================

#[test]
fn test_error_no_buy_token_to_sweep() {
    assert!(Errors::NO_BUY_TOKEN_TO_SWEEP == 'No buy token to sweep', "Error message mismatch");
}

// ============================================================================
// Config Consistency Error Constants
// ============================================================================

#[test]
fn test_error_min_delay_gt_max_delay() {
    assert!(Errors::MIN_DELAY_GT_MAX_DELAY == 'min_delay > max_delay', "Error message mismatch");
}

#[test]
fn test_error_min_duration_gt_max_duration() {
    assert!(
        Errors::MIN_DURATION_GT_MAX_DURATION == 'min_duration > max_duration',
        "Error message mismatch",
    );
}

// ============================================================================
// Stream Component Error Constants
// ============================================================================

#[test]
fn test_error_stream_invalid_factory() {
    assert!(Errors::STREAM_INVALID_FACTORY == 'Invalid factory address', "Error message mismatch");
}

#[test]
fn test_error_stream_invalid_core() {
    assert!(Errors::STREAM_INVALID_CORE == 'Invalid core address', "Error message mismatch");
}

#[test]
fn test_error_stream_invalid_registry() {
    assert!(
        Errors::STREAM_INVALID_REGISTRY == 'Invalid registry address', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_invalid_paired_token() {
    assert!(
        Errors::STREAM_INVALID_PAIRED_TOKEN == 'Invalid paired token', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_invalid_stream_amount() {
    assert!(
        Errors::STREAM_INVALID_STREAM_AMOUNT == 'Invalid stream token amount',
        "Error message mismatch",
    );
}

#[test]
fn test_error_stream_invalid_paired_amount() {
    assert!(
        Errors::STREAM_INVALID_PAIRED_AMOUNT == 'Invalid paired token amount',
        "Error message mismatch",
    );
}

#[test]
fn test_error_stream_no_orders() {
    assert!(Errors::STREAM_NO_ORDERS == 'No distribution orders', "Error message mismatch");
}

#[test]
fn test_error_stream_too_many_orders() {
    assert!(Errors::STREAM_TOO_MANY_ORDERS == 'Too many orders (max 10)', "Error message mismatch");
}

#[test]
fn test_error_stream_invalid_buy_token() {
    assert!(Errors::STREAM_INVALID_BUY_TOKEN == 'Invalid buy token', "Error message mismatch");
}

#[test]
fn test_error_stream_invalid_order_amount() {
    assert!(
        Errors::STREAM_INVALID_ORDER_AMOUNT == 'Invalid order amount', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_invalid_recipient() {
    assert!(
        Errors::STREAM_INVALID_RECIPIENT == 'Invalid proceeds recipient', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_only_factory() {
    assert!(Errors::STREAM_ONLY_FACTORY == 'Only factory can call', "Error message mismatch");
}

#[test]
fn test_error_stream_already_initialized() {
    assert!(Errors::STREAM_ALREADY_INITIALIZED == 'Already initialized', "Error message mismatch");
}

#[test]
fn test_error_stream_liquidity_not_provided() {
    assert!(
        Errors::STREAM_LIQUIDITY_NOT_PROVIDED == 'Liquidity not provided', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_distributions_not_started() {
    assert!(
        Errors::STREAM_DISTRIBUTIONS_NOT_STARTED == 'Distributions not started',
        "Error message mismatch",
    );
}

#[test]
fn test_error_stream_invalid_order_index() {
    assert!(Errors::STREAM_INVALID_ORDER_INDEX == 'Invalid order index', "Error message mismatch");
}

#[test]
fn test_error_stream_position_not_found() {
    assert!(Errors::STREAM_POSITION_NOT_FOUND == 'Position not found', "Error message mismatch");
}

// ============================================================================
// Factory Error Constants
// ============================================================================

#[test]
fn test_error_stream_invalid_total_supply() {
    assert!(
        Errors::STREAM_INVALID_TOTAL_SUPPLY == 'Invalid total supply', "Error message mismatch",
    );
}

#[test]
fn test_error_stream_supply_too_low() {
    assert!(Errors::STREAM_SUPPLY_TOO_LOW == 'Supply too low for config', "Error message mismatch");
}

// ============================================================================
// TWAMM Tick Spacing Constant
// ============================================================================

#[test]
fn test_twamm_tick_spacing_value() {
    // TWAMM_TICK_SPACING is the maximum tick spacing allowed by Ekubo TWAMM
    assert!(TWAMM_TICK_SPACING == 354892, "TWAMM tick spacing mismatch");
}

// ============================================================================
// ERC20 Constants
// ============================================================================

#[test]
fn test_erc20_decimals_value() {
    // Standard ERC20 decimals should be 18
    assert!(ERC20_DECIMALS == 18, "ERC20 decimals mismatch");
}

#[test]
fn test_erc20_unit_value() {
    // ERC20_UNIT should be 10^18 (1 token with 18 decimals)
    assert!(ERC20_UNIT == 1000000000000000000, "ERC20 unit mismatch");
    // Also verify the relationship: ERC20_UNIT == 10^ERC20_DECIMALS
    assert!(ERC20_UNIT == 10_u128.pow(ERC20_DECIMALS), "ERC20 unit should equal 10^decimals");
}

#[test]
fn test_erc20_unit_fits_in_u128() {
    // Verify ERC20_UNIT does not overflow
    let unit: u128 = ERC20_UNIT;
    assert!(unit > 0, "ERC20_UNIT should be positive");
    // Verify it can be used in calculations without overflow
    let doubled = unit * 2;
    assert!(doubled == 2000000000000000000, "Should be able to double");
}

// ============================================================================
// TWAMM Bounds Constant
// ============================================================================

#[test]
fn test_twamm_bounds_symmetric() {
    // TWAMM_BOUNDS should have symmetric lower and upper bounds
    // Lower bound: -88368108 (sign: true means negative)
    // Upper bound: +88368108 (sign: false means positive)
    assert!(TWAMM_BOUNDS.lower.mag == 88368108, "Lower bound magnitude mismatch");
    assert!(TWAMM_BOUNDS.lower.sign == true, "Lower bound should be negative");
    assert!(TWAMM_BOUNDS.upper.mag == 88368108, "Upper bound magnitude mismatch");
    assert!(TWAMM_BOUNDS.upper.sign == false, "Upper bound should be positive");
    // Verify symmetry
    assert!(TWAMM_BOUNDS.lower.mag == TWAMM_BOUNDS.upper.mag, "Bounds should be symmetric");
}

#[test]
fn test_twamm_bounds_nonzero() {
    // Bounds should be non-zero for meaningful liquidity ranges
    assert!(TWAMM_BOUNDS.lower.mag > 0, "Lower bound magnitude should be non-zero");
    assert!(TWAMM_BOUNDS.upper.mag > 0, "Upper bound magnitude should be non-zero");
}

#[test]
fn test_error_config_epochs_exhausted() {
    assert!(Errors::CONFIG_EPOCHS_EXHAUSTED == 'Config epochs exhausted', "Error message mismatch");
}
