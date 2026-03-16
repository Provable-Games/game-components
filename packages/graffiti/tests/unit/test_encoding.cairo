//! Unit tests for src/encoding.cairo
//!
//! Tests Base64 encoding and data URI generation functions.

use graffiti::encoding::{
    base64_encode, to_data_uri, to_json_data_uri, to_png_data_uri, to_svg_data_uri,
};

// ============================================================================
// base64_encode tests
// ============================================================================

#[test]
fn test_base64_encode_empty() {
    let result = base64_encode("");
    assert!(result == "", "empty input should produce empty output");
}

#[test]
fn test_base64_encode_1_byte_double_padding() {
    // 1 byte input should produce 4 chars with == padding
    // 'M' = 77 = 0b01001101
    // Split: 010011 01xxxx -> 19, 16 -> 'T', 'Q' + '=='
    let result = base64_encode("M");
    assert!(result == "TQ==", "1 byte should have == padding");
}

#[test]
fn test_base64_encode_2_bytes_single_padding() {
    // 2 byte input should produce 4 chars with = padding
    // 'Ma' = 77, 97 = 0b01001101 0b01100001
    // Split: 010011 010110 0001xx -> 19, 22, 4 -> 'T', 'W', 'E' + '='
    let result = base64_encode("Ma");
    assert!(result == "TWE=", "2 bytes should have = padding");
}

#[test]
fn test_base64_encode_3_bytes_no_padding() {
    // 3 byte input should produce 4 chars with no padding
    // 'Man' = 77, 97, 110
    let result = base64_encode("Man");
    assert!(result == "TWFu", "3 bytes should have no padding");
}

// RFC 4648 test vectors
#[test]
fn test_base64_rfc4648_empty() {
    assert!(base64_encode("") == "", "RFC 4648: empty");
}

#[test]
fn test_base64_rfc4648_f() {
    assert!(base64_encode("f") == "Zg==", "RFC 4648: f");
}

#[test]
fn test_base64_rfc4648_fo() {
    assert!(base64_encode("fo") == "Zm8=", "RFC 4648: fo");
}

#[test]
fn test_base64_rfc4648_foo() {
    assert!(base64_encode("foo") == "Zm9v", "RFC 4648: foo");
}

#[test]
fn test_base64_rfc4648_foob() {
    assert!(base64_encode("foob") == "Zm9vYg==", "RFC 4648: foob");
}

#[test]
fn test_base64_rfc4648_fooba() {
    assert!(base64_encode("fooba") == "Zm9vYmE=", "RFC 4648: fooba");
}

#[test]
fn test_base64_rfc4648_foobar() {
    assert!(base64_encode("foobar") == "Zm9vYmFy", "RFC 4648: foobar");
}

#[test]
fn test_base64_encode_hello() {
    let result = base64_encode("Hello");
    assert!(result == "SGVsbG8=", "Hello should encode correctly");
}

#[test]
fn test_base64_encode_hello_world() {
    let result = base64_encode("Hello, World!");
    assert!(result == "SGVsbG8sIFdvcmxkIQ==", "Hello, World! should encode correctly");
}

#[test]
fn test_base64_encode_all_zeros() {
    // 3 null bytes should encode to AAAA
    let mut data: ByteArray = Default::default();
    data.append_byte(0);
    data.append_byte(0);
    data.append_byte(0);
    let result = base64_encode(data);
    assert!(result == "AAAA", "3 zero bytes should encode to AAAA");
}

#[test]
fn test_base64_encode_single_zero() {
    // Single null byte
    let mut data: ByteArray = Default::default();
    data.append_byte(0);
    let result = base64_encode(data);
    assert!(result == "AA==", "single zero byte should encode to AA==");
}

#[test]
fn test_base64_encode_all_ff() {
    // 3 0xFF bytes should encode to ////
    let mut data: ByteArray = Default::default();
    data.append_byte(0xFF);
    data.append_byte(0xFF);
    data.append_byte(0xFF);
    let result = base64_encode(data);
    assert!(result == "////", "3 0xFF bytes should encode to ////");
}

#[test]
fn test_base64_encode_single_ff() {
    // Single 0xFF byte
    let mut data: ByteArray = Default::default();
    data.append_byte(0xFF);
    let result = base64_encode(data);
    assert!(result == "/w==", "single 0xFF byte should encode to /w==");
}

#[test]
fn test_base64_encode_binary_sequence() {
    // Binary sequence 0, 1, 2
    let mut data: ByteArray = Default::default();
    data.append_byte(0);
    data.append_byte(1);
    data.append_byte(2);
    let result = base64_encode(data);
    assert!(result == "AAEC", "binary 0,1,2 should encode to AAEC");
}

#[test]
fn test_base64_encode_longer_string() {
    let result = base64_encode("The quick brown fox jumps over the lazy dog");
    assert!(
        result == "VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZw==",
        "pangram should encode correctly",
    );
}

#[test]
fn test_base64_encode_abc() {
    let result = base64_encode("ABC");
    assert!(result == "QUJD", "ABC should encode to QUJD");
}

#[test]
fn test_base64_encode_lowercase_abc() {
    let result = base64_encode("abc");
    assert!(result == "YWJj", "abc should encode to YWJj");
}

#[test]
fn test_base64_encode_digits() {
    let result = base64_encode("123");
    assert!(result == "MTIz", "123 should encode to MTIz");
}

#[test]
fn test_base64_encode_4_bytes() {
    // 4 bytes to test 1 remaining byte after full triplets
    let result = base64_encode("test");
    assert!(result == "dGVzdA==", "test should encode to dGVzdA==");
}

#[test]
fn test_base64_encode_5_bytes() {
    // 5 bytes to test 2 remaining bytes after full triplets
    let result = base64_encode("tests");
    assert!(result == "dGVzdHM=", "tests should encode to dGVzdHM=");
}

#[test]
fn test_base64_encode_6_bytes() {
    // 6 bytes for exact multiple of 3
    let result = base64_encode("tested");
    assert!(result == "dGVzdGVk", "tested should encode to dGVzdGVk");
}

// ============================================================================
// to_svg_data_uri tests
// ============================================================================

#[test]
fn test_to_svg_data_uri_correct_prefix() {
    let result = to_svg_data_uri("<svg/>");
    // Check that it starts with the correct prefix
    let expected_prefix: ByteArray = "data:image/svg+xml;base64,";
    let mut matches_prefix = true;
    let prefix_len = expected_prefix.len();
    let mut i: u32 = 0;
    while i < prefix_len {
        if result.at(i).unwrap() != expected_prefix.at(i).unwrap() {
            matches_prefix = false;
            break;
        }
        i += 1;
    }
    assert!(matches_prefix, "should start with data:image/svg+xml;base64,");
}

#[test]
fn test_to_svg_data_uri_simple() {
    let result = to_svg_data_uri("<svg/>");
    assert!(result == "data:image/svg+xml;base64,PHN2Zy8+", "simple svg data uri");
}

#[test]
fn test_to_svg_data_uri_empty() {
    let result = to_svg_data_uri("");
    assert!(result == "data:image/svg+xml;base64,", "empty svg should have prefix only");
}

#[test]
fn test_to_svg_data_uri_realistic() {
    let svg =
        "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><rect fill=\"red\"/></svg>";
    let result = to_svg_data_uri(svg);
    assert!(
        result == "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIj48cmVjdCBmaWxsPSJyZWQiLz48L3N2Zz4=",
        "realistic svg data uri",
    );
}

// ============================================================================
// to_json_data_uri tests
// ============================================================================

#[test]
fn test_to_json_data_uri_correct_prefix() {
    let result = to_json_data_uri("{}");
    // Check that it starts with the correct prefix
    let expected_prefix: ByteArray = "data:application/json;base64,";
    let mut matches_prefix = true;
    let prefix_len = expected_prefix.len();
    let mut i: u32 = 0;
    while i < prefix_len {
        if result.at(i).unwrap() != expected_prefix.at(i).unwrap() {
            matches_prefix = false;
            break;
        }
        i += 1;
    }
    assert!(matches_prefix, "should start with data:application/json;base64,");
}

#[test]
fn test_to_json_data_uri_simple() {
    let result = to_json_data_uri("{}");
    assert!(result == "data:application/json;base64,e30=", "simple json data uri");
}

#[test]
fn test_to_json_data_uri_empty() {
    let result = to_json_data_uri("");
    assert!(result == "data:application/json;base64,", "empty json should have prefix only");
}

#[test]
fn test_to_json_data_uri_with_content() {
    let json = "{\"name\":\"test\"}";
    let result = to_json_data_uri(json);
    assert!(
        result == "data:application/json;base64,eyJuYW1lIjoidGVzdCJ9", "json with content data uri",
    );
}

// ============================================================================
// to_png_data_uri tests
// ============================================================================

#[test]
fn test_to_png_data_uri_correct_prefix() {
    let mut png_data: ByteArray = Default::default();
    png_data.append_byte(0x89);
    png_data.append_byte(0x50);
    png_data.append_byte(0x4E);
    png_data.append_byte(0x47);
    let result = to_png_data_uri(png_data);

    // Check that it starts with the correct prefix
    let expected_prefix: ByteArray = "data:image/png;base64,";
    let mut matches_prefix = true;
    let prefix_len = expected_prefix.len();
    let mut i: u32 = 0;
    while i < prefix_len {
        if result.at(i).unwrap() != expected_prefix.at(i).unwrap() {
            matches_prefix = false;
            break;
        }
        i += 1;
    }
    assert!(matches_prefix, "should start with data:image/png;base64,");
}

#[test]
fn test_to_png_data_uri_empty() {
    let result = to_png_data_uri("");
    assert!(result == "data:image/png;base64,", "empty png should have prefix only");
}

#[test]
fn test_to_png_data_uri_binary_data() {
    // Test with PNG magic bytes: 0x89 0x50 0x4E 0x47
    let mut png_header: ByteArray = Default::default();
    png_header.append_byte(0x89);
    png_header.append_byte(0x50);
    png_header.append_byte(0x4E);
    png_header.append_byte(0x47);
    let result = to_png_data_uri(png_header);
    assert!(result == "data:image/png;base64,iVBORw==", "png header should encode correctly");
}

// ============================================================================
// to_data_uri tests (custom MIME type)
// ============================================================================

#[test]
fn test_to_data_uri_custom_mime() {
    let result = to_data_uri("text/plain", "hello");
    assert!(result == "data:text/plain;base64,aGVsbG8=", "custom mime type data uri");
}

#[test]
fn test_to_data_uri_gif() {
    let result = to_data_uri("image/gif", "GIF89a");
    assert!(result == "data:image/gif;base64,R0lGODlh", "gif data uri");
}

#[test]
fn test_to_data_uri_empty_content() {
    let result = to_data_uri("text/html", "");
    assert!(result == "data:text/html;base64,", "empty content with custom mime");
}
