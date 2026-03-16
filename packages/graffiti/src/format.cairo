//! Number-to-string conversion utilities for all integer types.
//!
//! These functions convert numeric types to their string representation
//! for use in JSON, SVG attributes, and other markup generation.

/// Converts a u8 to its decimal string representation.
pub fn u8_to_string(value: u8) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_unsigned(value.into())
}

/// Converts a u16 to its decimal string representation.
pub fn u16_to_string(value: u16) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_unsigned(value.into())
}

/// Converts a u32 to its decimal string representation.
pub fn u32_to_string(value: u32) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_unsigned(value.into())
}

/// Converts a u64 to its decimal string representation.
pub fn u64_to_string(value: u64) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_unsigned(value.into())
}

/// Converts a u128 to its decimal string representation.
pub fn u128_to_string(value: u128) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_unsigned(value.into())
}

/// Converts a u256 to its decimal string representation.
pub fn u256_to_string(value: u256) -> ByteArray {
    if value == 0 {
        return "0";
    }
    format_u256(value)
}

/// Converts a felt252 to its decimal string representation.
pub fn felt252_to_string(value: felt252) -> ByteArray {
    if value == 0 {
        return "0";
    }
    let as_u256: u256 = value.into();
    format_u256(as_u256)
}

/// Converts an i64 to its decimal string representation (handles negative numbers).
pub fn i64_to_string(value: i64) -> ByteArray {
    if value == 0 {
        return "0";
    }
    if value < 0 {
        let mut result: ByteArray = "-";
        // Get absolute value safely
        let abs_value: u64 = if value == -9223372036854775808_i64 {
            // Special case: i64::MIN
            9223372036854775808_u64
        } else {
            let neg: i64 = -value;
            neg.try_into().unwrap()
        };
        result.append(@format_unsigned(abs_value.into()));
        result
    } else {
        let pos: u64 = value.try_into().unwrap();
        format_unsigned(pos.into())
    }
}

/// Converts an i128 to its decimal string representation (handles negative numbers).
pub fn i128_to_string(value: i128) -> ByteArray {
    if value == 0 {
        return "0";
    }
    if value < 0 {
        let mut result: ByteArray = "-";
        // Get absolute value safely
        let abs_value: u128 = if value == -170141183460469231731687303715884105728_i128 {
            // Special case: i128::MIN
            170141183460469231731687303715884105728_u128
        } else {
            let neg: i128 = -value;
            neg.try_into().unwrap()
        };
        result.append(@format_unsigned(abs_value.into()));
        result
    } else {
        let pos: u128 = value.try_into().unwrap();
        format_unsigned(pos.into())
    }
}

/// Internal helper to format unsigned values up to u128 range.
fn format_unsigned(mut value: u128) -> ByteArray {
    // Build digits in reverse order
    let mut digits: Array<u8> = array![];

    while value > 0 {
        let digit: u8 = (value % 10).try_into().unwrap();
        digits.append(digit + '0');
        value = value / 10;
    }

    // Reverse and build result
    let mut result: ByteArray = Default::default();
    let len = digits.len();
    let mut i = len;
    while i > 0 {
        i -= 1;
        result.append_byte(*digits.at(i));
    }

    result
}

/// Internal helper to format u256 values.
fn format_u256(mut value: u256) -> ByteArray {
    // Build digits in reverse order
    let mut digits: Array<u8> = array![];

    while value > 0 {
        let digit: u8 = (value % 10).try_into().unwrap();
        digits.append(digit + '0');
        value = value / 10;
    }

    // Reverse and build result
    let mut result: ByteArray = Default::default();
    let len = digits.len();
    let mut i = len;
    while i > 0 {
        i -= 1;
        result.append_byte(*digits.at(i));
    }

    result
}

#[cfg(test)]
mod tests {
    use super::{
        felt252_to_string, i128_to_string, i64_to_string, u128_to_string, u16_to_string,
        u256_to_string, u32_to_string, u64_to_string, u8_to_string,
    };

    #[test]
    fn test_u8_to_string() {
        assert!(u8_to_string(0) == "0", "u8 zero");
        assert!(u8_to_string(1) == "1", "u8 one");
        assert!(u8_to_string(42) == "42", "u8 42");
        assert!(u8_to_string(255) == "255", "u8 max");
    }

    #[test]
    fn test_u16_to_string() {
        assert!(u16_to_string(0) == "0", "u16 zero");
        assert!(u16_to_string(1000) == "1000", "u16 1000");
        assert!(u16_to_string(65535) == "65535", "u16 max");
    }

    #[test]
    fn test_u32_to_string() {
        assert!(u32_to_string(0) == "0", "u32 zero");
        assert!(u32_to_string(123456) == "123456", "u32 123456");
        assert!(u32_to_string(4294967295) == "4294967295", "u32 max");
    }

    #[test]
    fn test_u64_to_string() {
        assert!(u64_to_string(0) == "0", "u64 zero");
        assert!(u64_to_string(9876543210) == "9876543210", "u64 large");
        assert!(u64_to_string(18446744073709551615) == "18446744073709551615", "u64 max");
    }

    #[test]
    fn test_u128_to_string() {
        assert!(u128_to_string(0) == "0", "u128 zero");
        assert!(
            u128_to_string(123456789012345678901234567890) == "123456789012345678901234567890",
            "u128 large",
        );
    }

    #[test]
    fn test_u256_to_string() {
        assert!(u256_to_string(0) == "0", "u256 zero");
        assert!(u256_to_string(1) == "1", "u256 one");
        assert!(u256_to_string(999999999999999999) == "999999999999999999", "u256 large");
    }

    #[test]
    fn test_felt252_to_string() {
        assert!(felt252_to_string(0) == "0", "felt252 zero");
        assert!(felt252_to_string(42) == "42", "felt252 42");
        assert!(felt252_to_string(1234567890) == "1234567890", "felt252 large");
    }

    #[test]
    fn test_i64_to_string() {
        assert!(i64_to_string(0) == "0", "i64 zero");
        assert!(i64_to_string(42) == "42", "i64 positive");
        assert!(i64_to_string(-42) == "-42", "i64 negative");
        assert!(i64_to_string(-1) == "-1", "i64 neg one");
        assert!(i64_to_string(9223372036854775807) == "9223372036854775807", "i64 max");
        assert!(i64_to_string(-9223372036854775808) == "-9223372036854775808", "i64 min");
    }

    #[test]
    fn test_i128_to_string() {
        assert!(i128_to_string(0) == "0", "i128 zero");
        assert!(i128_to_string(42) == "42", "i128 positive");
        assert!(i128_to_string(-42) == "-42", "i128 negative");
        assert!(i128_to_string(-1) == "-1", "i128 neg one");
    }
}
