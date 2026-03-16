//! Encoding utilities for Base64 and data URIs.
//!
//! Provides Base64 encoding and helpers for generating data URIs
//! commonly used in NFT metadata (SVG images, JSON metadata).

/// Returns the Base64 character set as a span of bytes.
pub fn get_base64_charset() -> Span<u8> {
    array![
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
        'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
        'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1',
        '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
    ]
        .span()
}

/// Encodes a ByteArray to Base64.
///
/// # Arguments
/// * `data` - The data to encode
///
/// # Returns
/// Base64 encoded string
pub fn base64_encode(data: ByteArray) -> ByteArray {
    let charset = get_base64_charset();
    let mut result: ByteArray = Default::default();
    let len = data.len();

    if len == 0 {
        return result;
    }

    let mut i: u32 = 0;

    // Process 3 bytes at a time
    while i + 3 <= len {
        let b0: u32 = data.at(i).unwrap().into();
        let b1: u32 = data.at(i + 1).unwrap().into();
        let b2: u32 = data.at(i + 2).unwrap().into();

        // Combine 3 bytes into 24 bits
        let triple: u32 = (b0 * 0x10000) + (b1 * 0x100) + b2;

        // Extract 4 6-bit groups
        let c0: u32 = (triple / 0x40000) & 0x3F;
        let c1: u32 = (triple / 0x1000) & 0x3F;
        let c2: u32 = (triple / 0x40) & 0x3F;
        let c3: u32 = triple & 0x3F;

        result.append_byte(*charset.at(c0));
        result.append_byte(*charset.at(c1));
        result.append_byte(*charset.at(c2));
        result.append_byte(*charset.at(c3));

        i += 3;
    }

    // Handle remaining bytes
    let remaining = len - i;

    if remaining == 1 {
        let b0: u32 = data.at(i).unwrap().into();

        let c0: u32 = (b0 / 4) & 0x3F;
        let c1: u32 = (b0 * 16) & 0x3F;

        result.append_byte(*charset.at(c0));
        result.append_byte(*charset.at(c1));
        result.append_byte('=');
        result.append_byte('=');
    } else if remaining == 2 {
        let b0: u32 = data.at(i).unwrap().into();
        let b1: u32 = data.at(i + 1).unwrap().into();

        let double: u32 = (b0 * 0x100) + b1;

        let c0: u32 = (double / 0x400) & 0x3F;
        let c1: u32 = (double / 0x10) & 0x3F;
        let c2: u32 = (double * 4) & 0x3F;

        result.append_byte(*charset.at(c0));
        result.append_byte(*charset.at(c1));
        result.append_byte(*charset.at(c2));
        result.append_byte('=');
    }

    result
}

/// Creates a data URI for SVG content.
///
/// # Arguments
/// * `svg` - The SVG content
///
/// # Returns
/// A data URI string: `data:image/svg+xml;base64,{encoded}`
pub fn to_svg_data_uri(svg: ByteArray) -> ByteArray {
    let mut result: ByteArray = "data:image/svg+xml;base64,";
    result.append(@base64_encode(svg));
    result
}

/// Creates a data URI for JSON content.
///
/// # Arguments
/// * `json` - The JSON content
///
/// # Returns
/// A data URI string: `data:application/json;base64,{encoded}`
pub fn to_json_data_uri(json: ByteArray) -> ByteArray {
    let mut result: ByteArray = "data:application/json;base64,";
    result.append(@base64_encode(json));
    result
}

/// Creates a data URI for PNG image data.
///
/// # Arguments
/// * `png_bytes` - The raw PNG bytes
///
/// # Returns
/// A data URI string: `data:image/png;base64,{encoded}`
pub fn to_png_data_uri(png_bytes: ByteArray) -> ByteArray {
    let mut result: ByteArray = "data:image/png;base64,";
    result.append(@base64_encode(png_bytes));
    result
}

/// Creates a data URI with a custom MIME type.
///
/// # Arguments
/// * `mime_type` - The MIME type (e.g., "text/plain", "image/gif")
/// * `data` - The content to encode
///
/// # Returns
/// A data URI string: `data:{mime_type};base64,{encoded}`
pub fn to_data_uri(mime_type: ByteArray, data: ByteArray) -> ByteArray {
    let mut result: ByteArray = "data:";
    result.append(@mime_type);
    result.append(@";base64,");
    result.append(@base64_encode(data));
    result
}

#[cfg(test)]
mod tests {
    use super::{base64_encode, to_data_uri, to_json_data_uri, to_svg_data_uri};

    #[test]
    fn test_base64_encode_empty() {
        assert!(base64_encode("") == "", "empty string");
    }

    #[test]
    fn test_base64_encode_single_char() {
        // 'M' = 77 = 01001101
        // Split into: 010011 01xxxx -> 19, 16 -> 'T', 'Q' + '=='
        assert!(base64_encode("M") == "TQ==", "single char M");
    }

    #[test]
    fn test_base64_encode_two_chars() {
        // 'Ma' = 77, 97
        // 01001101 01100001
        // 010011 010110 0001xx -> 19, 22, 4 -> 'T', 'W', 'E' + '='
        assert!(base64_encode("Ma") == "TWE=", "two chars Ma");
    }

    #[test]
    fn test_base64_encode_three_chars() {
        // 'Man' = 77, 97, 110
        // No padding needed
        assert!(base64_encode("Man") == "TWFu", "three chars Man");
    }

    #[test]
    fn test_base64_encode_hello() {
        assert!(base64_encode("Hello") == "SGVsbG8=", "Hello");
    }

    #[test]
    fn test_base64_encode_hello_world() {
        assert!(base64_encode("Hello, World!") == "SGVsbG8sIFdvcmxkIQ==", "Hello, World!");
    }

    #[test]
    fn test_base64_encode_longer_string() {
        assert!(
            base64_encode(
                "The quick brown fox jumps over the lazy dog",
            ) == "VGhlIHF1aWNrIGJyb3duIGZveCBqdW1wcyBvdmVyIHRoZSBsYXp5IGRvZw==",
            "pangram",
        );
    }

    #[test]
    fn test_base64_encode_binary_data() {
        let mut data: ByteArray = Default::default();
        data.append_byte(0);
        data.append_byte(1);
        data.append_byte(2);
        assert!(base64_encode(data) == "AAEC", "binary 0,1,2");
    }

    #[test]
    fn test_base64_encode_all_chars() {
        // Test boundary characters
        assert!(base64_encode("ABC") == "QUJD", "ABC");
        assert!(base64_encode("abc") == "YWJj", "abc");
        assert!(base64_encode("123") == "MTIz", "123");
    }

    #[test]
    fn test_to_svg_data_uri() {
        let svg = "<svg/>";
        let result = to_svg_data_uri(svg);
        assert!(result == "data:image/svg+xml;base64,PHN2Zy8+", "svg data uri");
    }

    #[test]
    fn test_to_json_data_uri() {
        let json = "{}";
        let result = to_json_data_uri(json);
        assert!(result == "data:application/json;base64,e30=", "json data uri");
    }

    #[test]
    fn test_to_data_uri_custom() {
        let result = to_data_uri("text/plain", "hello");
        assert!(result == "data:text/plain;base64,aGVsbG8=", "custom mime type");
    }

    #[test]
    fn test_svg_data_uri_realistic() {
        let svg =
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"100\" height=\"100\"><rect fill=\"red\"/></svg>";
        let result = to_svg_data_uri(svg);
        // Verify it starts with the correct prefix
        assert!(
            result == "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAiIGhlaWdodD0iMTAwIj48cmVjdCBmaWxsPSJyZWQiLz48L3N2Zz4=",
            "realistic svg",
        );
    }
}
