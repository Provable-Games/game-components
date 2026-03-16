//! Unit tests for src/format.cairo
//!
//! Tests number-to-string conversion functions for all integer types.

use graffiti::format::{
    felt252_to_string, i128_to_string, i64_to_string, u128_to_string, u16_to_string, u256_to_string,
    u32_to_string, u64_to_string, u8_to_string,
};

// ============================================================================
// u8_to_string tests
// ============================================================================

#[test]
fn test_u8_to_string_zero() {
    assert!(u8_to_string(0) == "0", "u8 zero");
}

#[test]
fn test_u8_to_string_one() {
    assert!(u8_to_string(1) == "1", "u8 one");
}

#[test]
fn test_u8_to_string_typical() {
    assert!(u8_to_string(42) == "42", "u8 typical value");
    assert!(u8_to_string(100) == "100", "u8 hundred");
}

#[test]
fn test_u8_to_string_max() {
    assert!(u8_to_string(255) == "255", "u8 max value");
}

// ============================================================================
// u16_to_string tests
// ============================================================================

#[test]
fn test_u16_to_string_zero() {
    assert!(u16_to_string(0) == "0", "u16 zero");
}

#[test]
fn test_u16_to_string_typical() {
    assert!(u16_to_string(1000) == "1000", "u16 thousand");
    assert!(u16_to_string(12345) == "12345", "u16 typical");
}

#[test]
fn test_u16_to_string_max() {
    assert!(u16_to_string(65535) == "65535", "u16 max value");
}

// ============================================================================
// u32_to_string tests
// ============================================================================

#[test]
fn test_u32_to_string_zero() {
    assert!(u32_to_string(0) == "0", "u32 zero");
}

#[test]
fn test_u32_to_string_typical() {
    assert!(u32_to_string(123456) == "123456", "u32 typical");
    assert!(u32_to_string(1000000) == "1000000", "u32 million");
}

#[test]
fn test_u32_to_string_max() {
    assert!(u32_to_string(4294967295) == "4294967295", "u32 max value");
}

// ============================================================================
// u64_to_string tests
// ============================================================================

#[test]
fn test_u64_to_string_zero() {
    assert!(u64_to_string(0) == "0", "u64 zero");
}

#[test]
fn test_u64_to_string_typical() {
    assert!(u64_to_string(9876543210) == "9876543210", "u64 large value");
}

#[test]
fn test_u64_to_string_max() {
    assert!(u64_to_string(18446744073709551615) == "18446744073709551615", "u64 max value");
}

// ============================================================================
// u128_to_string tests
// ============================================================================

#[test]
fn test_u128_to_string_zero() {
    assert!(u128_to_string(0) == "0", "u128 zero");
}

#[test]
fn test_u128_to_string_typical() {
    assert!(
        u128_to_string(123456789012345678901234567890) == "123456789012345678901234567890",
        "u128 large value",
    );
}

#[test]
fn test_u128_to_string_one() {
    assert!(u128_to_string(1) == "1", "u128 one");
}

// ============================================================================
// u256_to_string tests
// ============================================================================

#[test]
fn test_u256_to_string_zero() {
    assert!(u256_to_string(0) == "0", "u256 zero");
}

#[test]
fn test_u256_to_string_one() {
    assert!(u256_to_string(1) == "1", "u256 one");
}

#[test]
fn test_u256_to_string_typical() {
    assert!(u256_to_string(999999999999999999) == "999999999999999999", "u256 large value");
}

#[test]
fn test_u256_to_string_powers_of_ten() {
    assert!(u256_to_string(10) == "10", "u256 ten");
    assert!(u256_to_string(100) == "100", "u256 hundred");
    assert!(u256_to_string(1000) == "1000", "u256 thousand");
}

// ============================================================================
// felt252_to_string tests
// ============================================================================

#[test]
fn test_felt252_to_string_zero() {
    assert!(felt252_to_string(0) == "0", "felt252 zero");
}

#[test]
fn test_felt252_to_string_typical() {
    assert!(felt252_to_string(42) == "42", "felt252 42");
    assert!(felt252_to_string(1234567890) == "1234567890", "felt252 large");
}

#[test]
fn test_felt252_to_string_one() {
    assert!(felt252_to_string(1) == "1", "felt252 one");
}

// ============================================================================
// i64_to_string tests
// ============================================================================

#[test]
fn test_i64_to_string_zero() {
    assert!(i64_to_string(0) == "0", "i64 zero");
}

#[test]
fn test_i64_to_string_positive() {
    assert!(i64_to_string(42) == "42", "i64 positive");
    assert!(i64_to_string(1000) == "1000", "i64 thousand");
}

#[test]
fn test_i64_to_string_negative() {
    assert!(i64_to_string(-42) == "-42", "i64 negative");
    assert!(i64_to_string(-1) == "-1", "i64 negative one");
    assert!(i64_to_string(-1000) == "-1000", "i64 negative thousand");
}

#[test]
fn test_i64_to_string_max() {
    assert!(i64_to_string(9223372036854775807) == "9223372036854775807", "i64 max");
}

#[test]
fn test_i64_to_string_min() {
    assert!(i64_to_string(-9223372036854775808) == "-9223372036854775808", "i64 min");
}

// ============================================================================
// i128_to_string tests
// ============================================================================

#[test]
fn test_i128_to_string_zero() {
    assert!(i128_to_string(0) == "0", "i128 zero");
}

#[test]
fn test_i128_to_string_positive() {
    assert!(i128_to_string(42) == "42", "i128 positive");
}

#[test]
fn test_i128_to_string_negative() {
    assert!(i128_to_string(-42) == "-42", "i128 negative");
    assert!(i128_to_string(-1) == "-1", "i128 negative one");
}

#[test]
fn test_i128_to_string_large_positive() {
    assert!(
        i128_to_string(
            170141183460469231731687303715884105727,
        ) == "170141183460469231731687303715884105727",
        "i128 max",
    );
}

#[test]
fn test_i128_to_string_large_negative() {
    assert!(
        i128_to_string(
            -170141183460469231731687303715884105728,
        ) == "-170141183460469231731687303715884105728",
        "i128 min",
    );
}
