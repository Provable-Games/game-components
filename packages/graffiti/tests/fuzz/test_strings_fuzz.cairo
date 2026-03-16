//! Fuzz tests for src/strings.cairo

use graffiti::strings::{contains, substring};

#[test]
#[fuzzer]
fn test_contains_empty_needle_fuzz(b0: u8, b1: u8, b2: u8, b3: u8, b4: u8) {
    // Build a random haystack
    let mut haystack: ByteArray = Default::default();
    haystack.append_byte(b0);
    haystack.append_byte(b1);
    haystack.append_byte(b2);
    haystack.append_byte(b3);
    haystack.append_byte(b4);

    // Empty needle should always be found
    assert!(contains(@haystack, @""), "empty needle should always be found");
}

#[test]
#[fuzzer]
fn test_contains_exact_match_fuzz(b0: u8, b1: u8, b2: u8, b3: u8, b4: u8) {
    // Build a random string
    let mut text: ByteArray = Default::default();
    text.append_byte(b0);
    text.append_byte(b1);
    text.append_byte(b2);
    text.append_byte(b3);
    text.append_byte(b4);

    // String should always contain itself
    assert!(contains(@text, @text), "string should contain itself");
}

#[test]
#[fuzzer]
fn test_contains_repeated_chars_fuzz(char_val: u8, count: u8) {
    // Build a string of repeated characters
    let repeat_count = (count % 10) + 1; // 1-10 chars
    let mut text: ByteArray = Default::default();
    let mut i: u8 = 0;
    while i < repeat_count {
        text.append_byte(char_val);
        i += 1;
    }

    // Single char needle should be found
    let mut needle: ByteArray = Default::default();
    needle.append_byte(char_val);
    assert!(contains(@text, @needle), "single char should be found in repeated string");
}

#[test]
#[fuzzer]
fn test_substring_empty_range_fuzz(b0: u8, b1: u8, b2: u8, start: u32) {
    // Build a random string
    let mut text: ByteArray = Default::default();
    text.append_byte(b0);
    text.append_byte(b1);
    text.append_byte(b2);

    // Same start and end should produce empty string
    let result = substring(@text, start, start);
    assert!(result.len() == 0, "same start and end should produce empty string");
}

#[test]
#[fuzzer]
fn test_substring_no_panic_fuzz(b0: u8, b1: u8, b2: u8, b3: u8, b4: u8, start: u32, end: u32) {
    // Build a random string
    let mut text: ByteArray = Default::default();
    text.append_byte(b0);
    text.append_byte(b1);
    text.append_byte(b2);
    text.append_byte(b3);
    text.append_byte(b4);

    // Should never panic, regardless of start/end values
    let _result = substring(@text, start, end);
    // If we get here, test passed (no panic)
    assert!(true, "substring should not panic");
}
