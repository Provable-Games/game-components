//! Unit tests for src/escape.cairo
//!
//! Tests XML/HTML escaping, JSON string escaping, and URI percent-encoding.

use graffiti::escape::{escape_html, escape_json_string, escape_uri, escape_xml};

// ============================================================================
// escape_xml tests
// ============================================================================

#[test]
fn test_escape_xml_empty() {
    let result = escape_xml("");
    assert!(result == "", "empty string should return empty");
}

#[test]
fn test_escape_xml_no_escaping_needed() {
    let result = escape_xml("hello world");
    assert!(result == "hello world", "plain text should pass through unchanged");
}

#[test]
fn test_escape_xml_lt() {
    let result = escape_xml("<");
    assert!(result == "&lt;", "< should become &lt;");
}

#[test]
fn test_escape_xml_gt() {
    let result = escape_xml(">");
    assert!(result == "&gt;", "> should become &gt;");
}

#[test]
fn test_escape_xml_lt_gt() {
    let result = escape_xml("<tag>");
    assert!(result == "&lt;tag&gt;", "<tag> should be escaped");
}

#[test]
fn test_escape_xml_ampersand() {
    let result = escape_xml("&");
    assert!(result == "&amp;", "& should become &amp;");
}

#[test]
fn test_escape_xml_double_quote() {
    let result = escape_xml("\"");
    assert!(result == "&quot;", "double quote should become &quot;");
}

#[test]
fn test_escape_xml_single_quote() {
    let result = escape_xml("'");
    assert!(result == "&#39;", "single quote should become &#39;");
}

#[test]
fn test_escape_xml_consecutive_special_chars() {
    let result = escape_xml("<<>>");
    assert!(result == "&lt;&lt;&gt;&gt;", "consecutive special chars should all be escaped");
}

#[test]
fn test_escape_xml_mixed() {
    let result = escape_xml("<a href=\"url\">Tom & Jerry's</a>");
    assert!(
        result == "&lt;a href=&quot;url&quot;&gt;Tom &amp; Jerry&#39;s&lt;/a&gt;",
        "mixed special chars should all be escaped",
    );
}

#[test]
fn test_escape_xml_ampersand_in_middle() {
    let result = escape_xml("a&b&c");
    assert!(result == "a&amp;b&amp;c", "multiple ampersands should all be escaped");
}

#[test]
fn test_escape_xml_xss_prevention() {
    let result = escape_xml("<script>alert('xss')</script>");
    assert!(
        result == "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;",
        "XSS attempt should be escaped",
    );
}

// ============================================================================
// escape_html tests (alias for escape_xml)
// ============================================================================

#[test]
fn test_escape_html_same_as_xml() {
    let input: ByteArray = "<div class=\"test\">Hello & goodbye</div>";
    assert!(
        escape_html(input.clone()) == escape_xml(input), "escape_html should be same as escape_xml",
    );
}

// ============================================================================
// escape_json_string tests
// ============================================================================

#[test]
fn test_escape_json_string_empty() {
    let result = escape_json_string("");
    assert!(result == "", "empty string should return empty");
}

#[test]
fn test_escape_json_string_no_escaping_needed() {
    let result = escape_json_string("hello world");
    assert!(result == "hello world", "plain text should pass through unchanged");
}

#[test]
fn test_escape_json_string_backslash() {
    let result = escape_json_string("\\");
    assert!(result == "\\\\", "backslash should be escaped");
}

#[test]
fn test_escape_json_string_quote() {
    let result = escape_json_string("\"");
    assert!(result == "\\\"", "double quote should be escaped");
}

#[test]
fn test_escape_json_string_newline() {
    let result = escape_json_string("\n");
    assert!(result == "\\n", "newline should be escaped");
}

#[test]
fn test_escape_json_string_tab() {
    let result = escape_json_string("\t");
    assert!(result == "\\t", "tab should be escaped");
}

#[test]
fn test_escape_json_string_carriage_return() {
    let result = escape_json_string("\r");
    assert!(result == "\\r", "carriage return should be escaped");
}

#[test]
fn test_escape_json_string_backspace() {
    // Backspace is 0x08
    let mut input: ByteArray = Default::default();
    input.append_byte(0x08);
    let result = escape_json_string(input);
    assert!(result == "\\b", "backspace should become \\b");
}

#[test]
fn test_escape_json_string_formfeed() {
    // Form feed is 0x0C
    let mut input: ByteArray = Default::default();
    input.append_byte(0x0C);
    let result = escape_json_string(input);
    assert!(result == "\\f", "form feed should become \\f");
}

#[test]
fn test_escape_json_string_null_byte() {
    // Null byte is 0x00
    let mut input: ByteArray = Default::default();
    input.append_byte(0x00);
    let result = escape_json_string(input);
    assert!(result == "\\u0000", "null byte should become \\u0000");
}

#[test]
fn test_escape_json_string_control_char_0x01() {
    // Control char 0x01 (SOH)
    let mut input: ByteArray = Default::default();
    input.append_byte(0x01);
    let result = escape_json_string(input);
    assert!(result == "\\u0001", "0x01 should become \\u0001");
}

#[test]
fn test_escape_json_string_control_char_0x07() {
    // Control char 0x07 (BEL)
    let mut input: ByteArray = Default::default();
    input.append_byte(0x07);
    let result = escape_json_string(input);
    assert!(result == "\\u0007", "0x07 should become \\u0007");
}

#[test]
fn test_escape_json_string_control_char_0x0E() {
    // Control char 0x0E (SO)
    let mut input: ByteArray = Default::default();
    input.append_byte(0x0E);
    let result = escape_json_string(input);
    assert!(result == "\\u000E", "0x0E should become \\u000E");
}

#[test]
fn test_escape_json_string_control_char_0x1F() {
    // Control char 0x1F (US)
    let mut input: ByteArray = Default::default();
    input.append_byte(0x1F);
    let result = escape_json_string(input);
    assert!(result == "\\u001F", "0x1F should become \\u001F");
}

#[test]
fn test_escape_json_string_multiple_control_chars() {
    // Mix of control chars
    let mut input: ByteArray = Default::default();
    input.append_byte(0x00); // null
    input.append_byte(0x08); // backspace
    input.append_byte(0x0C); // form feed
    let result = escape_json_string(input);
    assert!(result == "\\u0000\\b\\f", "multiple control chars should all be escaped");
}

#[test]
fn test_escape_json_string_mixed_content() {
    let result = escape_json_string("say \"hello\"\nworld");
    assert!(result == "say \\\"hello\\\"\\nworld", "mixed escaping should work");
}

// ============================================================================
// escape_uri tests
// ============================================================================

#[test]
fn test_escape_uri_empty() {
    let result = escape_uri("");
    assert!(result == "", "empty string should return empty");
}

#[test]
fn test_escape_uri_unreserved_passthrough() {
    // Unreserved chars: A-Z, a-z, 0-9, -, _, ., ~
    let result = escape_uri("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~");
    assert!(
        result == "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~",
        "unreserved chars should pass through",
    );
}

#[test]
fn test_escape_uri_space() {
    let result = escape_uri(" ");
    assert!(result == "%20", "space should become %20");
}

#[test]
fn test_escape_uri_percent() {
    let result = escape_uri("%");
    assert!(result == "%25", "percent should become %25");
}

#[test]
fn test_escape_uri_question_mark() {
    let result = escape_uri("?");
    assert!(result == "%3F", "? should become %3F");
}

#[test]
fn test_escape_uri_ampersand() {
    let result = escape_uri("&");
    assert!(result == "%26", "& should become %26");
}

#[test]
fn test_escape_uri_equals() {
    let result = escape_uri("=");
    assert!(result == "%3D", "= should become %3D");
}

#[test]
fn test_escape_uri_hash() {
    let result = escape_uri("#");
    assert!(result == "%23", "# should become %23");
}

#[test]
fn test_escape_uri_reserved_chars() {
    let result = escape_uri("a=b&c=d");
    assert!(result == "a%3Db%26c%3Dd", "reserved chars in query string should be encoded");
}

#[test]
fn test_escape_uri_high_byte() {
    // Test a high byte (non-ASCII)
    let mut input: ByteArray = Default::default();
    input.append_byte(0xC3);
    let result = escape_uri(input);
    assert!(result == "%C3", "high byte should be percent-encoded");
}

#[test]
fn test_escape_uri_all_ff() {
    // Test 0xFF byte
    let mut input: ByteArray = Default::default();
    input.append_byte(0xFF);
    let result = escape_uri(input);
    assert!(result == "%FF", "0xFF should become %FF");
}

#[test]
fn test_escape_uri_mixed() {
    let result = escape_uri("hello world?name=test&value=42");
    assert!(
        result == "hello%20world%3Fname%3Dtest%26value%3D42",
        "mixed content should be properly encoded",
    );
}

#[test]
fn test_escape_uri_path_with_spaces() {
    let result = escape_uri("path/to/my file.txt");
    assert!(result == "path%2Fto%2Fmy%20file.txt", "path with spaces should be encoded");
}

#[test]
fn test_escape_uri_multiple_high_bytes() {
    // Test multiple non-ASCII bytes
    let mut input: ByteArray = Default::default();
    input.append_byte(0xE2);
    input.append_byte(0x9C);
    input.append_byte(0x93);
    let result = escape_uri(input);
    assert!(result == "%E2%9C%93", "multiple high bytes should all be encoded");
}
