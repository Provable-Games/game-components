//! Unit tests for src/strings.cairo
//!
//! Tests string manipulation utilities.

use graffiti::strings::{
    concat, contains, ends_with, is_empty, join, pad_left, pad_right, repeat, starts_with,
    substring, truncate,
};

// ============================================================================
// concat tests
// ============================================================================

#[test]
fn test_concat_multiple_parts() {
    let parts = array!["Hello", ", ", "World", "!"];
    assert!(concat(parts.span()) == "Hello, World!", "concat multiple parts");
}

#[test]
fn test_concat_empty_array() {
    let parts: Array<ByteArray> = array![];
    assert!(concat(parts.span()) == "", "concat empty array");
}

#[test]
fn test_concat_single_part() {
    let parts = array!["single"];
    assert!(concat(parts.span()) == "single", "concat single part");
}

#[test]
fn test_concat_with_empty_strings() {
    let parts = array!["a", "", "b", "", "c"];
    assert!(concat(parts.span()) == "abc", "concat with empty strings");
}

// ============================================================================
// repeat tests
// ============================================================================

#[test]
fn test_repeat_multiple_times() {
    assert!(repeat("ab", 3) == "ababab", "repeat 3 times");
}

#[test]
fn test_repeat_single_char() {
    assert!(repeat("x", 5) == "xxxxx", "repeat single char 5 times");
}

#[test]
fn test_repeat_zero_times() {
    assert!(repeat("test", 0) == "", "repeat 0 times");
}

#[test]
fn test_repeat_once() {
    assert!(repeat("test", 1) == "test", "repeat once");
}

#[test]
fn test_repeat_empty_string() {
    assert!(repeat("", 5) == "", "repeat empty string");
}

// ============================================================================
// pad_left tests
// ============================================================================

#[test]
fn test_pad_left_with_zeros() {
    assert!(pad_left("42", 5, '0') == "00042", "pad left with zeros");
}

#[test]
fn test_pad_left_with_spaces() {
    assert!(pad_left("hello", 10, ' ') == "     hello", "pad left with spaces");
}

#[test]
fn test_pad_left_no_padding_needed() {
    assert!(pad_left("long", 2, 'x') == "long", "no padding when string is longer");
}

#[test]
fn test_pad_left_exact_length() {
    assert!(pad_left("test", 4, 'x') == "test", "no padding when exact length");
}

// ============================================================================
// pad_right tests
// ============================================================================

#[test]
fn test_pad_right_with_zeros() {
    assert!(pad_right("42", 5, '0') == "42000", "pad right with zeros");
}

#[test]
fn test_pad_right_with_spaces() {
    assert!(pad_right("hello", 10, ' ') == "hello     ", "pad right with spaces");
}

#[test]
fn test_pad_right_no_padding_needed() {
    assert!(pad_right("long", 2, 'x') == "long", "no padding when string is longer");
}

#[test]
fn test_pad_right_exact_length() {
    assert!(pad_right("test", 4, 'x') == "test", "no padding when exact length");
}

// ============================================================================
// truncate tests
// ============================================================================

#[test]
fn test_truncate_with_ellipsis() {
    assert!(truncate("Hello, World!", 5, "...") == "He...", "truncate with ellipsis");
}

#[test]
fn test_truncate_no_truncation_needed() {
    assert!(truncate("Hi", 10, "...") == "Hi", "no truncation when string is shorter");
}

#[test]
fn test_truncate_exact_length() {
    assert!(truncate("Hello", 5, "") == "Hello", "exact length no truncation");
}

#[test]
fn test_truncate_without_suffix() {
    assert!(truncate("Hello", 3, "") == "Hel", "truncate without suffix");
}

#[test]
fn test_truncate_max_smaller_than_suffix() {
    assert!(truncate("Hello", 2, "...") == "He", "max smaller than suffix");
}

#[test]
fn test_truncate_to_zero() {
    assert!(truncate("Hello", 0, "...") == "", "truncate to zero");
}

// ============================================================================
// starts_with tests
// ============================================================================

#[test]
fn test_starts_with_true() {
    assert!(starts_with(@"Hello, World!", @"Hello"), "starts with Hello");
}

#[test]
fn test_starts_with_exact_match() {
    assert!(starts_with(@"Hello", @"Hello"), "exact match starts with");
}

#[test]
fn test_starts_with_empty_prefix() {
    assert!(starts_with(@"Hello", @""), "empty prefix always matches");
}

#[test]
fn test_starts_with_false() {
    assert!(!starts_with(@"Hello", @"World"), "does not start with World");
}

#[test]
fn test_starts_with_prefix_longer() {
    assert!(!starts_with(@"Hi", @"Hello"), "prefix longer than text");
}

#[test]
fn test_starts_with_empty_text() {
    assert!(!starts_with(@"", @"Hello"), "empty text does not start with anything");
}

// ============================================================================
// ends_with tests
// ============================================================================

#[test]
fn test_ends_with_true() {
    assert!(ends_with(@"Hello, World!", @"World!"), "ends with World!");
}

#[test]
fn test_ends_with_exact_match() {
    assert!(ends_with(@"Hello", @"Hello"), "exact match ends with");
}

#[test]
fn test_ends_with_empty_suffix() {
    assert!(ends_with(@"Hello", @""), "empty suffix always matches");
}

#[test]
fn test_ends_with_false() {
    assert!(!ends_with(@"Hello", @"World"), "does not end with World");
}

#[test]
fn test_ends_with_suffix_longer() {
    assert!(!ends_with(@"Hi", @"Hello"), "suffix longer than text");
}

#[test]
fn test_ends_with_empty_text() {
    assert!(!ends_with(@"", @"Hello"), "empty text does not end with anything");
}

// ============================================================================
// contains tests
// ============================================================================

#[test]
fn test_contains_middle() {
    assert!(contains(@"Hello, World!", @"World"), "contains World in middle");
}

#[test]
fn test_contains_start() {
    assert!(contains(@"Hello, World!", @"Hello"), "contains Hello at start");
}

#[test]
fn test_contains_punctuation() {
    assert!(contains(@"Hello, World!", @", "), "contains comma space");
}

#[test]
fn test_contains_empty_needle() {
    assert!(contains(@"Hello", @""), "empty needle always found");
}

#[test]
fn test_contains_exact_match() {
    assert!(contains(@"Hello", @"Hello"), "contains exact match");
}

#[test]
fn test_contains_not_found() {
    assert!(!contains(@"Hello", @"World"), "does not contain World");
}

#[test]
fn test_contains_needle_longer() {
    assert!(!contains(@"Hi", @"Hello"), "needle longer than haystack");
}

#[test]
fn test_contains_single_char() {
    assert!(contains(@"Hello", @"e"), "contains single char");
}

// ============================================================================
// is_empty tests
// ============================================================================

#[test]
fn test_is_empty_true() {
    assert!(is_empty(@""), "empty string is empty");
}

#[test]
fn test_is_empty_single_char() {
    assert!(!is_empty(@"x"), "single char is not empty");
}

#[test]
fn test_is_empty_longer_string() {
    assert!(!is_empty(@"Hello"), "longer string is not empty");
}

// ============================================================================
// join tests
// ============================================================================

#[test]
fn test_join_with_comma() {
    let parts = array!["a", "b", "c"];
    assert!(join(parts.span(), ", ") == "a, b, c", "join with comma");
}

#[test]
fn test_join_single_element() {
    let parts = array!["one"];
    assert!(join(parts.span(), "-") == "one", "join single element");
}

#[test]
fn test_join_empty_array() {
    let parts: Array<ByteArray> = array![];
    assert!(join(parts.span(), ",") == "", "join empty array");
}

#[test]
fn test_join_with_empty_separator() {
    let parts = array!["a", "b", "c"];
    assert!(join(parts.span(), "") == "abc", "join with empty separator");
}

#[test]
fn test_join_with_longer_separator() {
    let parts = array!["1", "2", "3"];
    assert!(join(parts.span(), " -> ") == "1 -> 2 -> 3", "join with arrow separator");
}

// ============================================================================
// substring tests
// ============================================================================

#[test]
fn test_substring_first_word() {
    assert!(substring(@"Hello, World!", 0, 5) == "Hello", "substring first word");
}

#[test]
fn test_substring_second_word() {
    assert!(substring(@"Hello, World!", 7, 12) == "World", "substring second word");
}

#[test]
fn test_substring_end_beyond_length() {
    assert!(substring(@"Hello", 0, 100) == "Hello", "end beyond length");
}

#[test]
fn test_substring_start_beyond_length() {
    assert!(substring(@"Hello", 10, 20) == "", "start beyond length");
}

#[test]
fn test_substring_empty_range() {
    assert!(substring(@"Hello", 2, 2) == "", "empty range");
}

#[test]
fn test_substring_full_string() {
    assert!(substring(@"Hello", 0, 5) == "Hello", "full string");
}

#[test]
fn test_substring_single_char() {
    assert!(substring(@"Hello", 1, 2) == "e", "single char");
}

#[test]
fn test_substring_start_greater_than_end() {
    assert!(substring(@"Hello", 5, 2) == "", "start greater than end");
}
