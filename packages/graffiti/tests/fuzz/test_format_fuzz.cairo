//! Fuzz tests for src/format.cairo

use graffiti::format::{i64_to_string, u256_to_string, u64_to_string};

#[test]
fn test_u64_zero() {
    assert!(u64_to_string(0) == "0", "zero should be '0'");
}

#[test]
fn test_u64_max_length() {
    // u64 max = 18446744073709551615 (20 digits)
    let result = u64_to_string(18446744073709551615);
    assert!(result.len() == 20, "u64 max should have 20 digits");
}

#[test]
#[fuzzer]
fn test_u64_to_string_non_empty_fuzz(value: u64) {
    let result = u64_to_string(value);
    // Result should never be empty
    assert!(result.len() >= 1, "result should never be empty");

    // First char should be a digit
    let first = result.at(0).unwrap();
    assert!(first >= '0' && first <= '9', "first char should be digit");
}

#[test]
#[fuzzer]
fn test_u64_length_increases_fuzz(value: u64) {
    // Larger values should have equal or more digits
    let result = u64_to_string(value);
    if value == 0 {
        assert!(result.len() == 1, "zero should have 1 digit");
    } else if value < 10 {
        assert!(result.len() == 1, "single digit");
    } else if value < 100 {
        assert!(result.len() == 2, "two digits");
    } else if value < 1000 {
        assert!(result.len() == 3, "three digits");
    }
    // Just verify it doesn't crash for larger values
}

#[test]
fn test_i64_zero() {
    assert!(i64_to_string(0) == "0", "i64 zero");
}

#[test]
fn test_i64_max_value() {
    let result = i64_to_string(9223372036854775807);
    assert!(result.len() == 19, "i64 max should have 19 digits");
}

#[test]
fn test_i64_min_value() {
    let result = i64_to_string(-9223372036854775808);
    // Should be "-9223372036854775808" (20 chars including minus)
    assert!(result.len() == 20, "i64 min should have 20 chars");
    assert!(result.at(0).unwrap() == '-', "should start with minus");
}

#[test]
fn test_u256_zero() {
    assert!(u256_to_string(0) == "0", "u256 zero");
}

#[test]
#[fuzzer]
fn test_u256_low_only_fuzz(low: u128) {
    let value = u256 { low, high: 0 };
    let result = u256_to_string(value);
    // Should never be empty
    assert!(result.len() >= 1, "result should not be empty");
}

#[test]
#[fuzzer]
fn test_u256_high_only_fuzz(high: u128) {
    if high > 0 {
        let value = u256 { low: 0, high };
        let result = u256_to_string(value);
        // Should never be empty, and high != 0 means at least 39 digits
        assert!(result.len() >= 39, "u256 with high > 0 should have many digits");
    }
}

#[test]
#[fuzzer]
fn test_u256_to_string_random_fuzz(low: u128, high: u128) {
    let value = u256 { low, high };
    let result = u256_to_string(value);
    // Just verify it doesn't crash and produces valid output
    assert!(result.len() >= 1, "result should not be empty");
}
