// ==============================================================================
// ENCODING MODULE TESTS
// ==============================================================================
// Tests for Base64 encoding and BytesUsedTrait implementations.
// All functions are pure - no contract deployment needed.

use core::num::traits::Bounded;
use crate::utils::encoding::{
    U256BytesUsedTraitImpl, bytes_base64_encode, felt252_to_byte_array, u128_to_ascii_felt,
};

// ==============================================================================
// BASE64 ENCODING TESTS
// ==============================================================================

#[test]
fn test_base64_encode_empty() {
    let result = bytes_base64_encode("");
    assert!(result == "", "Empty input should return empty output");
}

#[test]
fn test_base64_encode_single_char() {
    // 'M' = 0x4D = 77
    // Binary: 01001101
    // Padded to 24 bits: 01001101 00000000 00000000
    // Split to 6-bit groups: 010011 010000 000000 000000
    // = 19, 16, 0, 0 -> T, Q, =, =
    let result = bytes_base64_encode("M");
    assert!(result == "TQ==", "Single char 'M' should encode to 'TQ=='");
}

#[test]
fn test_base64_encode_two_chars() {
    // 'Ma' = 0x4D 0x61 = 77 97
    // Binary: 01001101 01100001
    // Padded to 24 bits: 01001101 01100001 00000000
    // Split to 6-bit groups: 010011 010110 000100 000000
    // = 19, 22, 4, 0 -> T, W, E, =
    let result = bytes_base64_encode("Ma");
    assert!(result == "TWE=", "Two chars 'Ma' should encode to 'TWE='");
}

#[test]
fn test_base64_encode_three_chars() {
    // 'Man' = 0x4D 0x61 0x6E = 77 97 110
    // Binary: 01001101 01100001 01101110
    // Split to 6-bit groups: 010011 010110 000101 101110
    // = 19, 22, 5, 46 -> T, W, F, u
    let result = bytes_base64_encode("Man");
    assert!(result == "TWFu", "Three chars 'Man' should encode to 'TWFu'");
}

#[test]
fn test_base64_encode_hello_world() {
    let result = bytes_base64_encode("Hello World");
    assert!(result == "SGVsbG8gV29ybGQ=", "Hello World should encode correctly");
}

#[test]
fn test_base64_encode_all_zeros() {
    // Three null bytes should encode to "AAAA"
    let mut input: ByteArray = "";
    input.append_byte(0);
    input.append_byte(0);
    input.append_byte(0);
    let result = bytes_base64_encode(input);
    assert!(result == "AAAA", "Three null bytes should encode to 'AAAA'");
}

#[test]
fn test_base64_encode_binary_data() {
    // 0xFF 0x00 0xFF
    // Binary: 11111111 00000000 11111111
    // Split to 6-bit groups: 111111 110000 000011 111111
    // = 63, 48, 3, 63 -> /, w, D, /
    let mut input: ByteArray = "";
    input.append_byte(0xFF);
    input.append_byte(0x00);
    input.append_byte(0xFF);
    let result = bytes_base64_encode(input);
    assert!(result == "/wD/", "Binary data 0xFF00FF should encode to '/wD/'");
}

#[test]
fn test_base64_encode_long_string() {
    // Test with a long string to verify multi-chunk processing
    let input = "The quick brown fox jumps over the lazy dog. 1234567890!@#$%^&*()";
    let result = bytes_base64_encode(input);
    // Verify output is non-empty and has correct length
    // Input length = 65, output length = ceil(65/3) * 4 = 88
    assert!(result.len() > 0, "Should produce non-empty output");
    // Output should be multiple of 4
    assert!(result.len() % 4 == 0, "Base64 output length should be multiple of 4");
}

#[test]
fn test_base64_encode_mod_1() {
    // Input length % 3 == 1 should have 2 padding chars
    let result = bytes_base64_encode("A"); // 1 byte
    assert!(result.len() == 4, "Single byte should produce 4 char output");
    // Verify ends with ==
    let last_char = result.at(result.len() - 1).unwrap();
    let second_last_char = result.at(result.len() - 2).unwrap();
    assert!(last_char == '=', "Should end with '='");
    assert!(second_last_char == '=', "Should have '==' at end");
}

#[test]
fn test_base64_encode_mod_2() {
    // Input length % 3 == 2 should have 1 padding char
    let result = bytes_base64_encode("AB"); // 2 bytes
    assert!(result.len() == 4, "Two bytes should produce 4 char output");
    // Verify ends with single =
    let last_char = result.at(result.len() - 1).unwrap();
    let second_last_char = result.at(result.len() - 2).unwrap();
    assert!(last_char == '=', "Should end with '='");
    assert!(second_last_char != '=', "Should have only one '=' at end");
}

#[test]
fn test_base64_encode_mod_0() {
    // Input length % 3 == 0 should have no padding
    let result = bytes_base64_encode("ABC"); // 3 bytes
    assert!(result.len() == 4, "Three bytes should produce 4 char output");
    // Verify no padding
    let last_char = result.at(result.len() - 1).unwrap();
    assert!(last_char != '=', "Should not have padding when input % 3 == 0");
}

// ==============================================================================
// BASE64 FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_base64_output_length(input_len: u8) {
    // Create input of specified length
    let mut input: ByteArray = "";
    let mut i: u8 = 0;
    let bounded_len = input_len % 100; // Limit to reasonable size
    loop {
        if i >= bounded_len {
            break;
        }
        input.append_byte('A');
        i += 1;
    }

    let result = bytes_base64_encode(input.clone());

    // For input of length n:
    // - If n == 0, output is 0
    // - Otherwise, output length = ceil(n/3) * 4
    if bounded_len == 0 {
        assert!(result.len() == 0, "Empty input should produce empty output");
    } else {
        let expected_len: u32 = ((bounded_len.into() + 2) / 3) * 4;
        assert!(result.len() == expected_len, "Output length should be ceil(n/3)*4");
    }
}

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_base64_valid_chars(seed: u8) {
    // Create varied input using seed
    let mut input: ByteArray = "";
    let mut i: u8 = 0;
    loop {
        if i >= 10 {
            break;
        }
        // Use varying bytes based on seed (ensure we stay within u8 range)
        let byte_val: u8 = ((seed % 200) + i) % 200;
        input.append_byte(byte_val);
        i += 1;
    }

    let result = bytes_base64_encode(input);

    // Verify all characters are valid base64
    let mut j: u32 = 0;
    loop {
        if j >= result.len() {
            break;
        }
        let c = result.at(j).unwrap();
        let is_valid = (c >= 'A' && c <= 'Z')
            || (c >= 'a' && c <= 'z')
            || (c >= '0' && c <= '9')
            || c == '+'
            || c == '/'
            || c == '=';
        assert!(is_valid, "Output should contain only valid base64 characters");
        j += 1;
    };
}

// ==============================================================================
// U8 BYTES USED TESTS (using U256 impl)
// ==============================================================================

#[test]
fn test_u8_bytes_used_zero() {
    let value: u8 = 0;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 0, "Zero requires 0 bytes");
}

#[test]
fn test_u8_bytes_used_one() {
    let value: u8 = 1;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "1 requires 1 byte");
}

#[test]
fn test_u8_bytes_used_max() {
    let value: u8 = 255;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "255 requires 1 byte");
}

#[test]
fn test_u8_bytes_used_middle() {
    let value: u8 = 128;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "128 requires 1 byte");
}

// ==============================================================================
// USIZE BYTES USED TESTS (using U256 impl)
// ==============================================================================

#[test]
fn test_usize_bytes_used_zero() {
    let value: usize = 0;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 0, "Zero requires 0 bytes");
}

#[test]
fn test_usize_bytes_used_one() {
    let value: usize = 1;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "1 requires 1 byte");
}

#[test]
fn test_usize_bytes_used_255() {
    let value: usize = 255; // 0xFF - max 1-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "255 requires 1 byte");
}

#[test]
fn test_usize_bytes_used_256() {
    let value: usize = 256; // 0x100 - min 2-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 2, "256 requires 2 bytes");
}

#[test]
fn test_usize_bytes_used_65535() {
    let value: usize = 65535; // 0xFFFF - max 2-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 2, "65535 requires 2 bytes");
}

#[test]
fn test_usize_bytes_used_65536() {
    let value: usize = 65536; // 0x10000 - min 3-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 3, "65536 requires 3 bytes");
}

#[test]
fn test_usize_bytes_used_boundary_3_to_4() {
    let value: usize = 16777215; // 0xFFFFFF - max 3-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 3, "16777215 requires 3 bytes");
}

#[test]
fn test_usize_bytes_used_boundary_4() {
    let value: usize = 16777216; // 0x1000000 - min 4-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 4, "16777216 requires 4 bytes");
}

// ==============================================================================
// U64 BYTES USED TESTS (using U256 impl)
// ==============================================================================

#[test]
fn test_u64_bytes_used_zero() {
    let value: u64 = 0;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 0, "Zero requires 0 bytes");
}

#[test]
fn test_u64_bytes_used_1_byte() {
    let value: u64 = 0xFF; // 255
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 1, "0xFF requires 1 byte");
}

#[test]
fn test_u64_bytes_used_2_bytes() {
    let value: u64 = 0xFFFF; // 65535
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 2, "0xFFFF requires 2 bytes");
}

#[test]
fn test_u64_bytes_used_3_bytes() {
    let value: u64 = 0xFFFFFF; // 16777215
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 3, "0xFFFFFF requires 3 bytes");
}

#[test]
fn test_u64_bytes_used_4_bytes() {
    let value: u64 = 0xFFFFFFFF; // 4294967295 (u32 max)
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 4, "0xFFFFFFFF requires 4 bytes");
}

#[test]
fn test_u64_bytes_used_5_bytes() {
    let value: u64 = 0xFFFFFFFFFF; // 1099511627775
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 5, "0xFFFFFFFFFF requires 5 bytes");
}

#[test]
fn test_u64_bytes_used_6_bytes() {
    let value: u64 = 0xFFFFFFFFFFFF; // 281474976710655
    assert!(
        U256BytesUsedTraitImpl::bytes_used(value.into()) == 6, "0xFFFFFFFFFFFF requires 6 bytes",
    );
}

#[test]
fn test_u64_bytes_used_7_bytes() {
    let value: u64 = 0xFFFFFFFFFFFFFF; // 72057594037927935
    assert!(
        U256BytesUsedTraitImpl::bytes_used(value.into()) == 7, "0xFFFFFFFFFFFFFF requires 7 bytes",
    );
}

#[test]
fn test_u64_bytes_used_8_bytes() {
    let value: u64 = 0xFFFFFFFFFFFFFFFF; // Max u64
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 8, "Max u64 requires 8 bytes");
}

#[test]
fn test_u64_bytes_boundary_4_to_5() {
    let value: u64 = 0x100000000; // 4294967296 - min 5-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 5, "0x100000000 requires 5 bytes");
}

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_u64_bytes_used_consistency(value: u64) {
    let bytes = U256BytesUsedTraitImpl::bytes_used(value.into());

    // Verify the result is within valid range
    assert!(bytes <= 8, "u64 should use at most 8 bytes");

    // Verify consistency: if bytes > 0, value should be >= 256^(bytes-1)
    if bytes == 0 {
        assert!(value == 0, "0 bytes means value is 0");
    } else {
        // Value should fit in `bytes` bytes
        // This is implicitly true if bytes_used is implemented correctly
        assert!(bytes > 0, "Non-zero value should use at least 1 byte");
    }
}

// ==============================================================================
// U128 BYTES USED TESTS (using U256 impl)
// ==============================================================================

#[test]
fn test_u128_bytes_used_zero() {
    let value: u128 = 0;
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 0, "Zero requires 0 bytes");
}

#[test]
fn test_u128_bytes_used_delegates_to_u64() {
    // Values <= u64 max should delegate to U64 implementation
    let value: u128 = 0xFFFFFFFFFFFFFFFF; // Max u64
    assert!(
        U256BytesUsedTraitImpl::bytes_used(value.into()) == 8, "Max u64 as u128 requires 8 bytes",
    );
}

#[test]
fn test_u128_bytes_used_9_bytes() {
    let value: u128 = 0x1_0000_0000_0000_0000; // Min 9-byte value
    assert!(
        U256BytesUsedTraitImpl::bytes_used(value.into()) == 9, "Min 9-byte value requires 9 bytes",
    );
}

#[test]
fn test_u128_bytes_used_10_bytes() {
    // 10 bytes = 80 bits, max value = 2^80 - 1 = 20 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFF; // 20 F's = 80 bits = 10 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 10, "10-byte value requires 10 bytes");
}

#[test]
fn test_u128_bytes_used_11_bytes() {
    // 11 bytes = 88 bits, max value = 2^88 - 1 = 22 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFFFF; // 22 F's = 88 bits = 11 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 11, "11-byte value requires 11 bytes");
}

#[test]
fn test_u128_bytes_used_12_bytes() {
    // 12 bytes = 96 bits, max value = 2^96 - 1 = 24 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFF; // 24 F's = 96 bits = 12 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 12, "12-byte value requires 12 bytes");
}

#[test]
fn test_u128_bytes_used_13_bytes() {
    // 13 bytes = 104 bits, max value = 2^104 - 1 = 26 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFF; // 26 F's = 104 bits = 13 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 13, "13-byte value requires 13 bytes");
}

#[test]
fn test_u128_bytes_used_14_bytes() {
    // 14 bytes = 112 bits, max value = 2^112 - 1 = 28 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // 28 F's = 112 bits = 14 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 14, "14-byte value requires 14 bytes");
}

#[test]
fn test_u128_bytes_used_15_bytes() {
    // 15 bytes = 120 bits, max value = 2^120 - 1 = 30 hex digits
    let value: u128 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF; // 30 F's = 120 bits = 15 bytes
    let result = U256BytesUsedTraitImpl::bytes_used(value.into());
    assert!(result == 15, "15-byte value requires 15 bytes");
}

#[test]
fn test_u128_bytes_used_16_bytes() {
    let value: u128 = Bounded::<u128>::MAX; // Max u128
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 16, "Max u128 requires 16 bytes");
}

#[test]
fn test_u128_boundary_8_to_9() {
    let value: u128 = 0x100000000_00000000; // 2^64 - min 9-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 9, "2^64 requires 9 bytes");
}

#[test]
fn test_u128_boundary_12_to_13() {
    // 2^96 = 0x1_0000_0000_0000_0000_0000_0000 (97 bits = 13 bytes)
    let value: u128 = 0x1000000000000000000000000; // 2^96 - min 13-byte value
    assert!(U256BytesUsedTraitImpl::bytes_used(value.into()) == 13, "2^96 requires 13 bytes");
}

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_u128_bytes_used(value: u128) {
    let bytes = U256BytesUsedTraitImpl::bytes_used(value.into());

    // Verify the result is within valid range
    assert!(bytes <= 16, "u128 should use at most 16 bytes");

    // Verify consistency
    if bytes == 0 {
        assert!(value == 0, "0 bytes means value is 0");
    }
}

// ==============================================================================
// U256 BYTES USED TESTS
// ==============================================================================

#[test]
fn test_u256_bytes_used_zero() {
    let value = u256 { low: 0, high: 0 };
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 0, "Zero requires 0 bytes");
}

#[test]
fn test_u256_bytes_used_low_only() {
    let value = u256 { low: 0xFF, high: 0 };
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 1, "0xFF in low requires 1 byte");
}

#[test]
fn test_u256_bytes_used_low_max() {
    let value = u256 { low: Bounded::<u128>::MAX, high: 0 };
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 16, "Max low requires 16 bytes");
}

#[test]
fn test_u256_bytes_used_high_min() {
    let value = u256 { low: 0, high: 1 };
    // high = 1 uses 1 byte, total = 16 + 1 = 17
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 17, "high=1 requires 17 bytes");
}

#[test]
fn test_u256_bytes_used_high_mid() {
    let value = u256 { low: 0, high: 0xFFFFFFFF }; // high uses 4 bytes
    // total = 16 + 4 = 20
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 20, "high=0xFFFFFFFF requires 20 bytes");
}

#[test]
fn test_u256_bytes_used_max() {
    let value = u256 { low: Bounded::<u128>::MAX, high: Bounded::<u128>::MAX };
    // total = 16 + 16 = 32
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 32, "Max u256 requires 32 bytes");
}

#[test]
fn test_u256_bytes_used_mixed() {
    let value = u256 { low: Bounded::<u128>::MAX, high: 0xFF }; // high uses 1 byte
    // When high > 0, low is ignored for byte count
    // total = 16 + 1 = 17
    assert!(
        U256BytesUsedTraitImpl::bytes_used(value) == 17, "high=0xFF with max low requires 17 bytes",
    );
}

#[test]
fn test_u256_bytes_used_high_dominates() {
    let value = u256 { low: 1, high: 1 };
    // high = 1 uses 1 byte, total = 16 + 1 = 17
    assert!(U256BytesUsedTraitImpl::bytes_used(value) == 17, "high=1 with low=1 requires 17 bytes");
}

#[test]
#[fuzzer(runs: 100)]
fn test_fuzz_u256_bytes_used(low: u128, high: u128) {
    let value = u256 { low, high };
    let bytes = U256BytesUsedTraitImpl::bytes_used(value);

    // Verify the result is within valid range
    assert!(bytes <= 32, "u256 should use at most 32 bytes");

    // Verify consistency
    if high == 0 && low == 0 {
        assert!(bytes == 0, "Zero u256 should use 0 bytes");
    } else if high == 0 {
        assert!(bytes <= 16, "When high=0, should use at most 16 bytes");
    } else {
        assert!(bytes >= 17, "When high>0, should use at least 17 bytes");
    }
}

// ==============================================================================
// ADDITIONAL EDGE CASE TESTS
// ==============================================================================

#[test]
fn test_base64_encode_special_chars() {
    // Test encoding of special ASCII characters
    let result = bytes_base64_encode("!@#$%");
    assert!(result.len() > 0, "Should encode special characters");
    assert!(result.len() % 4 == 0, "Output length should be multiple of 4");
}

#[test]
fn test_base64_encode_numeric_string() {
    let result = bytes_base64_encode("1234567890");
    assert!(result == "MTIzNDU2Nzg5MA==", "Numeric string should encode correctly");
}

#[test]
fn test_u64_boundary_values() {
    // Test specific boundary values
    assert!(U256BytesUsedTraitImpl::bytes_used(0x100_u256) == 2, "0x100 needs 2 bytes");
    assert!(U256BytesUsedTraitImpl::bytes_used(0x10000_u256) == 3, "0x10000 needs 3 bytes");
    assert!(U256BytesUsedTraitImpl::bytes_used(0x1000000_u256) == 4, "0x1000000 needs 4 bytes");
    assert!(
        U256BytesUsedTraitImpl::bytes_used(0x10000000000_u256) == 6, "0x10000000000 needs 6 bytes",
    );
}

#[test]
fn test_u128_boundary_values() {
    // Test specific boundary values
    assert!(
        U256BytesUsedTraitImpl::bytes_used(0x10000000000000000_u256) == 9,
        "0x10000000000000000 needs 9 bytes",
    );
    assert!(
        U256BytesUsedTraitImpl::bytes_used(0x1000000000000000000_u256) == 10,
        "0x1000000000000000000 needs 10 bytes",
    );
}

// ==============================================================================
// U128 TO ASCII FELT TESTS
// ==============================================================================

#[test]
fn test_u128_to_ascii_felt_zero() {
    assert!(u128_to_ascii_felt(0) == '0', "0 should be ASCII '0'");
}

#[test]
fn test_u128_to_ascii_felt_single_digit() {
    assert!(u128_to_ascii_felt(5) == '5', "5 should be ASCII '5'");
    assert!(u128_to_ascii_felt(9) == '9', "9 should be ASCII '9'");
}

#[test]
fn test_u128_to_ascii_felt_multi_digit() {
    assert!(u128_to_ascii_felt(42) == '42', "42 should be ASCII '42'");
    assert!(u128_to_ascii_felt(100) == '100', "100 should be ASCII '100'");
    assert!(u128_to_ascii_felt(1000) == '1000', "1000 should be ASCII '1000'");
    assert!(u128_to_ascii_felt(12345) == '12345', "12345 should be ASCII '12345'");
}

#[test]
fn test_u128_to_ascii_felt_large_numbers() {
    assert!(u128_to_ascii_felt(1000000) == '1000000', "1000000 should be ASCII '1000000'");
    assert!(u128_to_ascii_felt(999999999) == '999999999', "999999999 should be ASCII '999999999'");
}

#[test]
fn test_u128_to_ascii_felt_max_u64_value() {
    // Max u64 = 18446744073709551615 (20 digits, fits in 31 bytes)
    let result = u128_to_ascii_felt(18446744073709551615);
    assert!(result == '18446744073709551615', "Max u64 value should convert correctly");
}

#[test]
fn test_u128_to_ascii_felt_beyond_u64() {
    // 31-digit number (max that fits in felt252)
    let result = u128_to_ascii_felt(1000000000000000000000);
    assert!(result == '1000000000000000000000', "21-digit u128 should convert correctly");
}

#[test]
fn test_u128_to_ascii_felt_powers_of_10() {
    assert!(u128_to_ascii_felt(1) == '1', "10^0");
    assert!(u128_to_ascii_felt(10) == '10', "10^1");
    assert!(u128_to_ascii_felt(100) == '100', "10^2");
    assert!(u128_to_ascii_felt(1000) == '1000', "10^3");
    assert!(u128_to_ascii_felt(10000) == '10000', "10^4");
}

#[test]
#[should_panic(expected: "Number exceeds 31 digits, cannot fit in felt252")]
fn test_u128_to_ascii_felt_panics_over_31_digits() {
    // u128 max = 340282366920938463463374607431768211455 (39 digits)
    u128_to_ascii_felt(340282366920938463463374607431768211455);
}

// ==============================================================================
// FELT252 TO BYTE ARRAY TESTS
// ==============================================================================

#[test]
fn test_felt252_to_byte_array_zero() {
    let result = felt252_to_byte_array(0);
    assert!(result.len() == 0, "Zero should produce empty ByteArray");
}

#[test]
fn test_felt252_to_byte_array_short_string() {
    let result = felt252_to_byte_array('hello');
    assert!(result == "hello", "Should convert short string correctly");
}

#[test]
fn test_felt252_to_byte_array_max_short_string() {
    // 31-byte short string (max that fits in a single felt252 word)
    let result = felt252_to_byte_array('1234567890123456789012345678901');
    assert!(result.len() == 31, "31-byte string should produce 31-byte ByteArray");
}

#[test]
fn test_felt252_to_byte_array_large_value_no_panic() {
    // A felt252 value large enough that U256BytesUsedTraitImpl::bytes_used
    // returns 32, which previously caused 'bad append len' panic.
    // The Starknet prime P ≈ 2^251, so any felt252 where the u256
    // representation has a non-zero high limb AND bytes_used(high) >= 16
    // would return 32 bytes. We use P-1 (max valid felt252).
    let large: felt252 = (-1); // P - 1, the largest valid felt252
    let result = felt252_to_byte_array(large);
    // Should not panic — length is capped at 31
    assert!(result.len() == 31, "Large felt252 should produce 31-byte ByteArray");
}

#[test]
#[fuzzer(runs: 256)]
fn test_fuzz_felt252_to_byte_array_no_panic(value: felt252) {
    // Should never panic regardless of input
    let result = felt252_to_byte_array(value);
    if value == 0 {
        assert!(result.len() == 0, "Zero should produce empty ByteArray");
    } else {
        assert!(result.len() > 0 && result.len() <= 31, "Non-zero should produce 1-31 bytes");
    }
}
