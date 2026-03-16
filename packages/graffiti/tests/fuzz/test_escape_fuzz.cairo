//! Fuzz tests for src/escape.cairo

use graffiti::escape::{escape_json_string, escape_uri};

#[test]
#[fuzzer]
fn test_json_escape_any_byte_fuzz(byte: u8) {
    let mut input: ByteArray = Default::default();
    input.append_byte(byte);
    let result = escape_json_string(input);
    // Result should never be empty (escape produces at least 1 char per input)
    assert!(result.len() >= 1, "escape should produce at least 1 char");
}

#[test]
#[fuzzer]
fn test_json_escape_control_chars_fuzz(byte: u8) {
    // Focus on control characters (0x00-0x1F)
    if byte < 0x20 {
        let mut input: ByteArray = Default::default();
        input.append_byte(byte);
        let result = escape_json_string(input);
        // Control chars should be escaped (result length > 1)
        assert!(result.len() >= 2, "control chars should be escaped");
    }
}

#[test]
#[fuzzer]
fn test_json_printable_ascii_fuzz(byte: u8) {
    // Test printable ASCII (0x20-0x7E) excluding special chars
    if byte >= 0x20 && byte <= 0x7E && byte != '"' && byte != '\\' {
        let mut input: ByteArray = Default::default();
        input.append_byte(byte);
        let result = escape_json_string(input);
        // Printable ASCII (except " and \) should pass through unchanged
        assert!(result.len() == 1, "printable ASCII should not be escaped");
        assert!(result.at(0).unwrap() == byte, "printable ASCII should be unchanged");
    }
}

#[test]
#[fuzzer]
fn test_uri_escape_all_bytes_fuzz(byte: u8) {
    let mut input: ByteArray = Default::default();
    input.append_byte(byte);
    let result = escape_uri(input);
    // Result should never be empty
    assert!(result.len() >= 1, "URI escape should produce at least 1 char");
}

#[test]
#[fuzzer]
fn test_uri_unreserved_chars_fuzz(byte: u8) {
    // Unreserved chars should pass through unchanged
    let is_unreserved = (byte >= 'A' && byte <= 'Z')
        || (byte >= 'a' && byte <= 'z')
        || (byte >= '0' && byte <= '9')
        || byte == '-'
        || byte == '_'
        || byte == '.'
        || byte == '~';

    let mut input: ByteArray = Default::default();
    input.append_byte(byte);
    let result = escape_uri(input);

    if is_unreserved {
        assert!(result.len() == 1, "unreserved chars should not be escaped");
        assert!(result.at(0).unwrap() == byte, "unreserved chars should be unchanged");
    } else {
        assert!(result.len() == 3, "reserved/special chars should be percent-encoded");
        assert!(result.at(0).unwrap() == '%', "should start with %");
    }
}
