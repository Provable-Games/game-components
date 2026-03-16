//! String manipulation utilities.
//!
//! Provides common string operations for building markup documents.

/// Concatenates multiple ByteArrays into one.
pub fn concat(mut parts: Span<ByteArray>) -> ByteArray {
    let mut result: ByteArray = Default::default();
    while let Option::Some(part) = parts.pop_front() {
        result.append(part);
    }
    result
}

/// Repeats a string a given number of times.
pub fn repeat(text: ByteArray, count: u32) -> ByteArray {
    let mut result: ByteArray = Default::default();
    let mut i: u32 = 0;
    while i < count {
        result.append(@text);
        i += 1;
    }
    result
}

/// Pads a string on the left to reach the desired length.
pub fn pad_left(text: ByteArray, length: u32, pad_char: u8) -> ByteArray {
    let text_len = text.len();
    if text_len >= length {
        return text;
    }

    let mut result: ByteArray = Default::default();
    let padding_needed = length - text_len;
    let mut i: u32 = 0;
    while i < padding_needed {
        result.append_byte(pad_char);
        i += 1;
    }
    result.append(@text);
    result
}

/// Pads a string on the right to reach the desired length.
pub fn pad_right(text: ByteArray, length: u32, pad_char: u8) -> ByteArray {
    let text_len = text.len();
    if text_len >= length {
        return text;
    }

    let mut result: ByteArray = text;
    let padding_needed = length - text_len;
    let mut i: u32 = 0;
    while i < padding_needed {
        result.append_byte(pad_char);
        i += 1;
    }
    result
}

/// Truncates a string to the specified length, optionally adding a suffix.
pub fn truncate(text: ByteArray, max_length: u32, suffix: ByteArray) -> ByteArray {
    let text_len = text.len();
    if text_len <= max_length {
        return text;
    }

    let suffix_len = suffix.len();
    if max_length <= suffix_len {
        // If max_length is too small to fit suffix, just truncate without suffix
        let mut result: ByteArray = Default::default();
        let mut i: u32 = 0;
        while i < max_length {
            result.append_byte(text.at(i).unwrap());
            i += 1;
        }
        return result;
    }

    let content_length = max_length - suffix_len;
    let mut result: ByteArray = Default::default();
    let mut i: u32 = 0;
    while i < content_length {
        result.append_byte(text.at(i).unwrap());
        i += 1;
    }
    result.append(@suffix);
    result
}

/// Checks if a string starts with the given prefix.
pub fn starts_with(text: @ByteArray, prefix: @ByteArray) -> bool {
    let text_len = text.len();
    let prefix_len = prefix.len();

    if prefix_len > text_len {
        return false;
    }

    let mut i: u32 = 0;
    while i < prefix_len {
        if text.at(i).unwrap() != prefix.at(i).unwrap() {
            return false;
        }
        i += 1;
    }

    true
}

/// Checks if a string ends with the given suffix.
pub fn ends_with(text: @ByteArray, suffix: @ByteArray) -> bool {
    let text_len = text.len();
    let suffix_len = suffix.len();

    if suffix_len > text_len {
        return false;
    }

    let offset = text_len - suffix_len;
    let mut i: u32 = 0;
    while i < suffix_len {
        if text.at(offset + i).unwrap() != suffix.at(i).unwrap() {
            return false;
        }
        i += 1;
    }

    true
}

/// Checks if a string contains the given substring.
pub fn contains(haystack: @ByteArray, needle: @ByteArray) -> bool {
    let haystack_len = haystack.len();
    let needle_len = needle.len();

    if needle_len == 0 {
        return true;
    }
    if needle_len > haystack_len {
        return false;
    }

    let max_start = haystack_len - needle_len;
    let mut start: u32 = 0;

    while start <= max_start {
        let mut matches = true;
        let mut i: u32 = 0;
        while i < needle_len {
            if haystack.at(start + i).unwrap() != needle.at(i).unwrap() {
                matches = false;
                break;
            }
            i += 1;
        }
        if matches {
            return true;
        }
        start += 1;
    }

    false
}

/// Checks if a string is empty.
pub fn is_empty(text: @ByteArray) -> bool {
    text.len() == 0
}

/// Joins an array of strings with a separator.
pub fn join(mut parts: Span<ByteArray>, separator: ByteArray) -> ByteArray {
    let mut result: ByteArray = Default::default();
    let mut first = true;
    while let Option::Some(part) = parts.pop_front() {
        if !first {
            result.append(@separator);
        }
        first = false;
        result.append(part);
    }
    result
}

/// Returns a substring from start index to end index (exclusive).
pub fn substring(text: @ByteArray, start: u32, end: u32) -> ByteArray {
    let text_len = text.len();
    let actual_end = if end > text_len {
        text_len
    } else {
        end
    };
    let actual_start = if start > actual_end {
        actual_end
    } else {
        start
    };

    let mut result: ByteArray = Default::default();
    let mut i = actual_start;
    while i < actual_end {
        result.append_byte(text.at(i).unwrap());
        i += 1;
    }
    result
}


#[cfg(test)]
mod tests {
    use super::{
        concat, contains, ends_with, is_empty, join, pad_left, pad_right, repeat, starts_with,
        substring, truncate,
    };

    #[test]
    fn test_concat() {
        let parts = array!["Hello", ", ", "World", "!"];
        assert!(concat(parts.span()) == "Hello, World!", "concat");
    }

    #[test]
    fn test_concat_empty() {
        let parts: Array<ByteArray> = array![];
        assert!(concat(parts.span()) == "", "concat empty");
    }

    #[test]
    fn test_repeat() {
        assert!(repeat("ab", 3) == "ababab", "repeat 3");
        assert!(repeat("x", 5) == "xxxxx", "repeat 5");
        assert!(repeat("test", 0) == "", "repeat 0");
        assert!(repeat("test", 1) == "test", "repeat 1");
    }

    #[test]
    fn test_pad_left() {
        assert!(pad_left("42", 5, '0') == "00042", "pad left with zeros");
        assert!(pad_left("hello", 10, ' ') == "     hello", "pad left with spaces");
        assert!(pad_left("long", 2, 'x') == "long", "no padding needed");
    }

    #[test]
    fn test_pad_right() {
        assert!(pad_right("42", 5, '0') == "42000", "pad right with zeros");
        assert!(pad_right("hello", 10, ' ') == "hello     ", "pad right with spaces");
        assert!(pad_right("long", 2, 'x') == "long", "no padding needed");
    }

    #[test]
    fn test_truncate() {
        assert!(truncate("Hello, World!", 5, "...") == "He...", "truncate with ellipsis");
        assert!(truncate("Hi", 10, "...") == "Hi", "no truncation needed");
        assert!(truncate("Hello", 5, "") == "Hello", "exact length");
        assert!(truncate("Hello", 3, "") == "Hel", "truncate without suffix");
    }

    #[test]
    fn test_truncate_small_max() {
        assert!(truncate("Hello", 2, "...") == "He", "max smaller than suffix");
    }

    #[test]
    fn test_starts_with() {
        assert!(starts_with(@"Hello, World!", @"Hello"), "starts with Hello");
        assert!(starts_with(@"Hello", @"Hello"), "exact match");
        assert!(starts_with(@"Hello", @""), "empty prefix");
        assert!(!starts_with(@"Hello", @"World"), "does not start with");
        assert!(!starts_with(@"Hi", @"Hello"), "prefix longer than text");
    }

    #[test]
    fn test_ends_with() {
        assert!(ends_with(@"Hello, World!", @"World!"), "ends with World!");
        assert!(ends_with(@"Hello", @"Hello"), "exact match");
        assert!(ends_with(@"Hello", @""), "empty suffix");
        assert!(!ends_with(@"Hello", @"World"), "does not end with");
        assert!(!ends_with(@"Hi", @"Hello"), "suffix longer than text");
    }

    #[test]
    fn test_contains() {
        assert!(contains(@"Hello, World!", @"World"), "contains World");
        assert!(contains(@"Hello, World!", @"Hello"), "contains Hello");
        assert!(contains(@"Hello, World!", @", "), "contains comma space");
        assert!(contains(@"Hello", @""), "contains empty");
        assert!(contains(@"Hello", @"Hello"), "contains exact");
        assert!(!contains(@"Hello", @"World"), "does not contain");
        assert!(!contains(@"Hi", @"Hello"), "needle longer than haystack");
    }

    #[test]
    fn test_is_empty() {
        assert!(is_empty(@""), "empty string");
        assert!(!is_empty(@"x"), "non-empty string");
        assert!(!is_empty(@"Hello"), "longer string");
    }

    #[test]
    fn test_join() {
        let parts = array!["a", "b", "c"];
        assert!(join(parts.span(), ", ") == "a, b, c", "join with comma");

        let parts2 = array!["one"];
        assert!(join(parts2.span(), "-") == "one", "join single");

        let parts3: Array<ByteArray> = array![];
        assert!(join(parts3.span(), ",") == "", "join empty");
    }

    #[test]
    fn test_substring() {
        assert!(substring(@"Hello, World!", 0, 5) == "Hello", "first word");
        assert!(substring(@"Hello, World!", 7, 12) == "World", "second word");
        assert!(substring(@"Hello", 0, 100) == "Hello", "end beyond length");
        assert!(substring(@"Hello", 10, 20) == "", "start beyond length");
        assert!(substring(@"Hello", 2, 2) == "", "empty range");
    }
}
