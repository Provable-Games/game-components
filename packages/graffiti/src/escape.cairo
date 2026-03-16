//! String escaping utilities for XML, HTML, JSON, and URIs.
//!
//! These functions ensure proper escaping of special characters to prevent
//! XSS vulnerabilities and malformed output.

/// Escapes special XML/HTML characters in text.
///
/// Converts:
/// - `<` to `&lt;`
/// - `>` to `&gt;`
/// - `&` to `&amp;`
/// - `"` to `&quot;`
/// - `'` to `&#39;`
pub fn escape_xml(text: ByteArray) -> ByteArray {
    let mut result: ByteArray = Default::default();
    let len = text.len();
    let mut i: u32 = 0;

    while i < len {
        let byte = text.at(i).unwrap();
        if byte == '<' {
            result.append(@"&lt;");
        } else if byte == '>' {
            result.append(@"&gt;");
        } else if byte == '&' {
            result.append(@"&amp;");
        } else if byte == '"' {
            result.append(@"&quot;");
        } else if byte == '\'' {
            result.append(@"&#39;");
        } else {
            result.append_byte(byte);
        }
        i += 1;
    }

    result
}

/// Alias for escape_xml - HTML uses the same escaping rules.
pub fn escape_html(text: ByteArray) -> ByteArray {
    escape_xml(text)
}

/// Escapes special characters for JSON string values.
///
/// Converts:
/// - `"` to `\"`
/// - `\` to `\\`
/// - newline to `\n`
/// - carriage return to `\r`
/// - tab to `\t`
/// - backspace to `\b`
/// - form feed to `\f`
pub fn escape_json_string(text: ByteArray) -> ByteArray {
    let mut result: ByteArray = Default::default();
    let len = text.len();
    let mut i: u32 = 0;

    while i < len {
        let byte = text.at(i).unwrap();
        if byte == '"' {
            result.append_byte('\\');
            result.append_byte('"');
        } else if byte == '\\' {
            result.append_byte('\\');
            result.append_byte('\\');
        } else if byte == '\n' {
            result.append_byte('\\');
            result.append_byte('n');
        } else if byte == '\r' {
            result.append_byte('\\');
            result.append_byte('r');
        } else if byte == '\t' {
            result.append_byte('\\');
            result.append_byte('t');
        } else if byte == 0x08 {
            // Backspace
            result.append_byte('\\');
            result.append_byte('b');
        } else if byte == 0x0C {
            // Form feed
            result.append_byte('\\');
            result.append_byte('f');
        } else if byte < 0x20 {
            // Other control characters: use \u00XX format
            result.append(@"\\u00");
            result.append_byte(hex_digit(byte / 16));
            result.append_byte(hex_digit(byte % 16));
        } else {
            result.append_byte(byte);
        }
        i += 1;
    }

    result
}

/// Escapes a string for use in a URI using percent-encoding.
///
/// Unreserved characters (A-Z, a-z, 0-9, -, _, ., ~) are not encoded.
/// All other characters are percent-encoded.
pub fn escape_uri(text: ByteArray) -> ByteArray {
    let mut result: ByteArray = Default::default();
    let len = text.len();
    let mut i: u32 = 0;

    while i < len {
        let byte = text.at(i).unwrap();
        if is_uri_unreserved(byte) {
            result.append_byte(byte);
        } else {
            result.append_byte('%');
            result.append_byte(hex_digit(byte / 16));
            result.append_byte(hex_digit(byte % 16));
        }
        i += 1;
    }

    result
}

/// Checks if a byte is an unreserved URI character.
fn is_uri_unreserved(byte: u8) -> bool {
    // A-Z
    if byte >= 'A' && byte <= 'Z' {
        return true;
    }
    // a-z
    if byte >= 'a' && byte <= 'z' {
        return true;
    }
    // 0-9
    if byte >= '0' && byte <= '9' {
        return true;
    }
    // - _ . ~
    byte == '-' || byte == '_' || byte == '.' || byte == '~'
}

/// Converts a nibble (0-15) to its hex character.
fn hex_digit(nibble: u8) -> u8 {
    if nibble < 10 {
        '0' + nibble
    } else {
        'A' + nibble - 10
    }
}

#[cfg(test)]
mod tests {
    use super::{escape_html, escape_json_string, escape_uri, escape_xml};

    #[test]
    fn test_escape_xml_basic() {
        assert!(escape_xml("hello") == "hello", "no escaping needed");
        assert!(escape_xml("") == "", "empty string");
    }

    #[test]
    fn test_escape_xml_angle_brackets() {
        assert!(escape_xml("<script>") == "&lt;script&gt;", "script tag");
        assert!(escape_xml("a < b > c") == "a &lt; b &gt; c", "comparison");
    }

    #[test]
    fn test_escape_xml_ampersand() {
        assert!(escape_xml("a & b") == "a &amp; b", "ampersand");
        assert!(escape_xml("Tom & Jerry") == "Tom &amp; Jerry", "names with ampersand");
    }

    #[test]
    fn test_escape_xml_quotes() {
        assert!(escape_xml("\"quoted\"") == "&quot;quoted&quot;", "double quotes");
        assert!(escape_xml("it's") == "it&#39;s", "apostrophe");
    }

    #[test]
    fn test_escape_xml_combined() {
        assert!(
            escape_xml(
                "<a href=\"test\">Tom & Jerry's</a>",
            ) == "&lt;a href=&quot;test&quot;&gt;Tom &amp; Jerry&#39;s&lt;/a&gt;",
            "combined escaping",
        );
    }

    #[test]
    fn test_escape_html_same_as_xml() {
        assert!(escape_html("<div>") == escape_xml("<div>"), "html equals xml");
    }

    #[test]
    fn test_escape_json_string_basic() {
        assert!(escape_json_string("hello") == "hello", "no escaping needed");
        assert!(escape_json_string("") == "", "empty string");
    }

    #[test]
    fn test_escape_json_string_quotes() {
        assert!(escape_json_string("say \"hello\"") == "say \\\"hello\\\"", "double quotes");
    }

    #[test]
    fn test_escape_json_string_backslash() {
        assert!(escape_json_string("path\\to\\file") == "path\\\\to\\\\file", "backslashes");
    }

    #[test]
    fn test_escape_json_string_control_chars() {
        assert!(escape_json_string("line1\nline2") == "line1\\nline2", "newline");
        assert!(escape_json_string("col1\tcol2") == "col1\\tcol2", "tab");
        assert!(escape_json_string("text\rmore") == "text\\rmore", "carriage return");
    }

    #[test]
    fn test_escape_uri_basic() {
        assert!(escape_uri("hello") == "hello", "no escaping needed");
        assert!(escape_uri("test-file_name.txt") == "test-file_name.txt", "unreserved chars");
    }

    #[test]
    fn test_escape_uri_spaces() {
        assert!(escape_uri("hello world") == "hello%20world", "space");
    }

    #[test]
    fn test_escape_uri_special() {
        assert!(escape_uri("a=b&c=d") == "a%3Db%26c%3Dd", "query string chars");
        assert!(escape_uri("100%") == "100%25", "percent sign");
    }

    #[test]
    fn test_escape_uri_unicode_byte() {
        // Test a non-ASCII byte
        let mut input: ByteArray = Default::default();
        input.append_byte(0xC3); // First byte of UTF-8 encoded character
        let result = escape_uri(input);
        assert!(result == "%C3", "high byte");
    }
}
