#[cfg(test)]
mod encoding_tests {
    use game_components_utils::encoding::{bytes_base64_encode, BytesUsedTrait};
    use core::num::traits::Bounded;

    #[test]
    fn test_bytes_base64_encode_empty() {
        let input: ByteArray = "";
        let result = bytes_base64_encode(input);
        assert!(result == "");
    }

    #[test]
    fn test_bytes_base64_encode_single_byte() {
        let input: ByteArray = "M";
        let result = bytes_base64_encode(input);
        assert!(result == "TQ==");
    }

    #[test]
    fn test_bytes_base64_encode_two_bytes() {
        let input: ByteArray = "Ma";
        let result = bytes_base64_encode(input);
        assert!(result == "TWE=");
    }

    #[test]
    fn test_bytes_base64_encode_three_bytes() {
        let input: ByteArray = "Man";
        let result = bytes_base64_encode(input);
        assert!(result == "TWFu");
    }

    #[test]
    fn test_bytes_base64_encode_hello_world() {
        let input: ByteArray = "Hello World";
        let result = bytes_base64_encode(input);
        assert!(result == "SGVsbG8gV29ybGQ=");
    }

    #[test]
    fn test_bytes_base64_encode_long_string() {
        let mut input: ByteArray = "";
        let mut i = 0;
        loop {
            if i == 255 {
                break;
            }
            input += "A";
            i += 1;
        };
        let result = bytes_base64_encode(input);
        assert!(result.len() > 0);
        assert!(result.len() == 340); // ceil(255 * 4/3) = 340
    }

    #[test]
    fn test_bytes_used_u8_zero() {
        let result = BytesUsedTrait::<u8>::bytes_used(0);
        assert!(result == 0);
    }

    #[test]
    fn test_bytes_used_u8_one() {
        let result = BytesUsedTrait::<u8>::bytes_used(1);
        assert!(result == 1);
    }

    #[test]
    fn test_bytes_used_u8_max() {
        let result = BytesUsedTrait::<u8>::bytes_used(255);
        assert!(result == 1);
    }

    #[test]
    fn test_bytes_used_u64_zero() {
        let result = BytesUsedTrait::<u64>::bytes_used(0);
        assert!(result == 0);
    }

    #[test]
    fn test_bytes_used_u64_255() {
        let result = BytesUsedTrait::<u64>::bytes_used(255);
        assert!(result == 1);
    }

    #[test]
    fn test_bytes_used_u64_256() {
        let result = BytesUsedTrait::<u64>::bytes_used(256);
        assert!(result == 2);
    }

    #[test]
    fn test_bytes_used_u64_65535() {
        let result = BytesUsedTrait::<u64>::bytes_used(65535);
        assert!(result == 2);
    }

    #[test]
    fn test_bytes_used_u64_65536() {
        let result = BytesUsedTrait::<u64>::bytes_used(65536);
        assert!(result == 3);
    }

    #[test]
    fn test_bytes_used_u64_max() {
        let result = BytesUsedTrait::<u64>::bytes_used(Bounded::<u64>::MAX);
        assert!(result == 8);
    }

    #[test]
    fn test_bytes_used_u128_u64_max_plus_one() {
        let value: u128 = Bounded::<u64>::MAX.into() + 1;
        let result = BytesUsedTrait::<u128>::bytes_used(value);
        assert!(result == 9);
    }

    #[test]
    fn test_bytes_used_u128_max() {
        let result = BytesUsedTrait::<u128>::bytes_used(Bounded::<u128>::MAX);
        assert!(result == 16);
    }

    #[test]
    fn test_bytes_used_u256_zero() {
        let value = u256 { low: 0, high: 0 };
        let result = BytesUsedTrait::<u256>::bytes_used(value);
        assert!(result == 0);
    }

    #[test]
    fn test_bytes_used_u256_low_only() {
        let value = u256 { low: Bounded::<u128>::MAX, high: 0 };
        let result = BytesUsedTrait::<u256>::bytes_used(value);
        assert!(result == 16);
    }

    #[test]
    fn test_bytes_used_u256_high_one() {
        let value = u256 { low: 0, high: 1 };
        let result = BytesUsedTrait::<u256>::bytes_used(value);
        assert!(result == 17);
    }

    #[test]
    fn test_bytes_used_u256_max() {
        let value = u256 { low: Bounded::<u128>::MAX, high: Bounded::<u128>::MAX };
        let result = BytesUsedTrait::<u256>::bytes_used(value);
        assert!(result == 32);
    }

    #[test]
    fn test_bytes_used_u32_zero() {
        let result = BytesUsedTrait::<u32>::bytes_used(0);
        assert!(result == 0);
    }

    #[test]
    fn test_bytes_used_u32_powers_of_256() {
        assert!(BytesUsedTrait::<u32>::bytes_used(255) == 1);
        assert!(BytesUsedTrait::<u32>::bytes_used(256) == 2);
        assert!(BytesUsedTrait::<u32>::bytes_used(65535) == 2);
        assert!(BytesUsedTrait::<u32>::bytes_used(65536) == 3);
        assert!(BytesUsedTrait::<u32>::bytes_used(16777215) == 3);
        assert!(BytesUsedTrait::<u32>::bytes_used(16777216) == 4);
    }

    // Fuzz tests for encoding properties
    #[test]
    #[fuzzer(runs: 100)]
    fn fuzz_base64_encode_length_property(input: felt252) {
        // Convert felt252 to ByteArray for testing
        let mut bytes: ByteArray = "";
        let mut remaining = input;
        let mut count: u8 = 0;
        
        // Limit to reasonable size for testing
        let mut remaining_u256: u256 = remaining.into();
        loop {
            if count >= 10 {
                break;
            }
            if remaining_u256 == 0 {
                break;
            }
            // Convert felt252 to u256 for modulo operation
            let byte = (remaining_u256 % 256_u256).try_into().unwrap();
            bytes.append_byte(byte);
            remaining_u256 = remaining_u256 / 256_u256;
            count += 1;
        };
        
        let encoded = bytes_base64_encode(bytes.clone());
        
        // Property: base64 encoding should produce valid length
        // For base64: every 3 input bytes become 4 output bytes
        // With padding, the formula is: 4 * ceil(input_len / 3)
        let expected_len = if bytes.len() == 0 {
            0
        } else {
            // Calculate 4 * ceil(len / 3) = 4 * ((len + 2) / 3)
            4 * ((bytes.len() + 2) / 3)
        };
        
        assert!(encoded.len() == expected_len);
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn fuzz_bytes_used_monotonic_u64(n: u64) {
        let bytes_n = BytesUsedTrait::<u64>::bytes_used(n);
        
        // Property: bytes_used(n) <= bytes_used(n+1) when n < MAX
        if n < Bounded::<u64>::MAX {
            let bytes_n_plus_1 = BytesUsedTrait::<u64>::bytes_used(n + 1);
            assert!(bytes_n <= bytes_n_plus_1);
        }
        
        // Property: bytes_used(n) <= 8 for all u64
        assert!(bytes_n <= 8);
        
        // Property: if n == 0 then bytes_used(n) == 0
        if n == 0 {
            assert!(bytes_n == 0);
        } else {
            assert!(bytes_n >= 1);
        }
    }

    #[test]
    #[fuzzer(runs: 50)]
    fn fuzz_bytes_used_powers_of_256(k: u8) {
        // Test powers of 256 up to reasonable limits
        if k <= 7 { // For u64, max is 256^8 - 1
            let mut power: u64 = 1;
            let mut i = 0;
            loop {
                if i >= k {
                    break;
                }
                power = power * 256;
                i += 1;
            };
            
            // Property: bytes_used(256^k - 1) = k
            if power > 1 {
                let bytes_before = BytesUsedTrait::<u64>::bytes_used(power - 1);
                assert!(bytes_before == k);
            }
            
            // Property: bytes_used(256^k) = k + 1
            if k < 7 { // Avoid overflow
                let bytes_at = BytesUsedTrait::<u64>::bytes_used(power);
                assert!(bytes_at == k + 1);
            }
        }
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn fuzz_base64_charset_validation(input: felt252) {
        // Create random ByteArray from felt252
        let mut bytes: ByteArray = "";
        let mut remaining = input;
        let mut count: u8 = 0;
        
        let mut remaining_u256: u256 = remaining.into();
        loop {
            if count >= 20 {
                break;
            }
            if remaining_u256 == 0 {
                break;
            }
            // Convert felt252 to u256 for modulo operation
            let byte = (remaining_u256 % 256_u256).try_into().unwrap();
            bytes.append_byte(byte);
            remaining_u256 = remaining_u256 / 256_u256;
            count += 1;
        };
        
        let encoded = bytes_base64_encode(bytes);
        
        // Property: All characters in output must be valid base64
        let mut i = 0;
        loop {
            if i >= encoded.len() {
                break;
            }
            let c = encoded[i];
            let is_valid = (c >= 'A' && c <= 'Z') ||
                          (c >= 'a' && c <= 'z') ||
                          (c >= '0' && c <= '9') ||
                          c == '+' || c == '/' || c == '=';
            assert!(is_valid);
            i += 1;
        };
        
        // Property: Padding only at end
        if encoded.len() > 0 {
            let mut found_padding = false;
            let mut j = 0;
            loop {
                if j >= encoded.len() {
                    break;
                }
                if encoded[j] == '=' {
                    found_padding = true;
                } else if found_padding {
                    // Should not have non-padding after padding
                    assert!(false);
                }
                j += 1;
            };
        }
    }

    #[test]
    #[fuzzer(runs: 50)]
    fn fuzz_bytes_used_consistency_u128(high: u64, low: u64) {
        let value: u128 = (high.into() * 0x10000000000000000) + low.into();
        let bytes = BytesUsedTrait::<u128>::bytes_used(value);
        
        // Property: Result is in valid range
        assert!(bytes <= 16);
        
        // Property: Consistency with value magnitude
        if value == 0 {
            assert!(bytes == 0);
        } else if value <= Bounded::<u8>::MAX.into() {
            assert!(bytes == 1);
        } else if value <= Bounded::<u16>::MAX.into() {
            assert!(bytes <= 2);
        } else if value <= Bounded::<u32>::MAX.into() {
            assert!(bytes <= 4);
        } else if value <= Bounded::<u64>::MAX.into() {
            assert!(bytes <= 8);
        }
    }
}