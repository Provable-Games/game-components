//! Unit tests for src/utils.cairo
//!
//! Tests utility functions and constants.

use graffiti::utils::{constants, starts_with_bracket};

// ============================================================================
// starts_with_bracket tests
// ============================================================================

#[test]
fn test_starts_with_square_bracket() {
    assert!(starts_with_bracket(@"[1, 2, 3]"), "should detect square bracket");
}

#[test]
fn test_starts_with_curly_bracket() {
    assert!(starts_with_bracket(@"{\"key\": \"value\"}"), "should detect curly bracket");
}

#[test]
fn test_starts_with_no_bracket() {
    assert!(!starts_with_bracket(@"hello"), "should not detect non-bracket");
}

#[test]
fn test_starts_with_empty_string() {
    assert!(!starts_with_bracket(@""), "empty string should return false");
}

#[test]
fn test_starts_with_number() {
    assert!(!starts_with_bracket(@"123"), "number should not be detected as bracket");
}

#[test]
fn test_starts_with_space_before_bracket() {
    assert!(!starts_with_bracket(@" [1, 2]"), "space before bracket should return false");
}

#[test]
fn test_starts_with_nested_brackets() {
    assert!(starts_with_bracket(@"[[nested]]"), "nested square brackets");
    assert!(starts_with_bracket(@"{{nested}}"), "nested curly brackets");
}

// ============================================================================
// constants tests
// ============================================================================

#[test]
fn test_constants_bracket_open() {
    assert!(constants::BRACKET_OPEN == '{', "BRACKET_OPEN should be curly brace");
}

#[test]
fn test_constants_bracket_close() {
    assert!(constants::BRACKET_CLOSE == '}', "BRACKET_CLOSE should be curly brace");
}

#[test]
fn test_constants_square_bracket_open() {
    assert!(constants::SQUARE_BRACKET_OPEN == '[', "SQUARE_BRACKET_OPEN should be square bracket");
}

#[test]
fn test_constants_square_bracket_close() {
    assert!(
        constants::SQUARE_BRACKET_CLOSE == ']', "SQUARE_BRACKET_CLOSE should be square bracket",
    );
}

#[test]
fn test_constants_quote() {
    assert!(constants::QUOTE == '"', "QUOTE should be double quote");
}

#[test]
fn test_constants_colon() {
    assert!(constants::COLON == ':', "COLON should be colon");
}

#[test]
fn test_constants_comma() {
    assert!(constants::COMMA == ',', "COMMA should be comma");
}

#[test]
fn test_constants_name() {
    assert!(constants::NAME == 'name', "NAME should be name");
}

#[test]
fn test_constants_description() {
    assert!(constants::DESCRIPTION == 'description', "DESCRIPTION should be description");
}

#[test]
fn test_constants_image() {
    assert!(constants::IMAGE == 'image', "IMAGE should be image");
}

#[test]
fn test_constants_attributes() {
    assert!(constants::ATTRIBUTES == 'attributes', "ATTRIBUTES should be attributes");
}

#[test]
fn test_constants_trait_type() {
    assert!(constants::TRAIT_TYPE == 'trait_type', "TRAIT_TYPE should be trait_type");
}

#[test]
fn test_constants_value() {
    assert!(constants::VALUE == 'value', "VALUE should be value");
}
