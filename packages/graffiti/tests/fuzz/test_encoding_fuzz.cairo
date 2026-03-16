//! Fuzz tests for src/encoding.cairo

use graffiti::encoding::base64_encode;

#[test]
fn test_base64_empty() {
    let result = base64_encode("");
    assert!(result == "", "empty string should produce empty output");
}

#[test]
#[fuzzer]
fn test_base64_three_bytes_produces_four_chars_fuzz(b0: u8, b1: u8, b2: u8) {
    let mut data: ByteArray = Default::default();
    data.append_byte(b0);
    data.append_byte(b1);
    data.append_byte(b2);
    let result = base64_encode(data);
    // 3 bytes should always produce exactly 4 base64 chars (no padding)
    assert!(result.len() == 4, "3 bytes should produce 4 chars");
}

#[test]
#[fuzzer]
fn test_base64_no_padding_fuzz(b0: u8, b1: u8, b2: u8) {
    let mut data: ByteArray = Default::default();
    data.append_byte(b0);
    data.append_byte(b1);
    data.append_byte(b2);
    let result = base64_encode(data);
    // Result should not contain '=' (no padding needed for 3 bytes)
    let len = result.len();
    if len > 0 {
        assert!(result.at(len - 1).unwrap() != '=', "3 bytes should not need padding");
    }
}

#[test]
#[fuzzer]
fn test_base64_six_bytes_fuzz(b0: u8, b1: u8, b2: u8, b3: u8, b4: u8, b5: u8) {
    let mut data: ByteArray = Default::default();
    data.append_byte(b0);
    data.append_byte(b1);
    data.append_byte(b2);
    data.append_byte(b3);
    data.append_byte(b4);
    data.append_byte(b5);
    let result = base64_encode(data);
    // 6 bytes should always produce exactly 8 base64 chars (no padding)
    assert!(result.len() == 8, "6 bytes should produce 8 chars");
}

#[test]
#[fuzzer]
fn test_base64_output_length_formula_fuzz(len: u8) {
    // Test that output length follows the formula: 4 * ceil(n/3)
    let mut data: ByteArray = Default::default();
    let mut i: u8 = 0;
    while i < len {
        data.append_byte(i);
        i += 1;
    }
    let result = base64_encode(data);

    if len == 0 {
        assert!(result.len() == 0, "empty input should produce empty output");
    } else {
        // Output length should be 4 * ceil(len/3)
        let len_u32: u32 = len.into();
        let expected_len = ((len_u32 + 2) / 3) * 4;
        assert!(result.len() == expected_len, "output length should match formula");
    }
}
