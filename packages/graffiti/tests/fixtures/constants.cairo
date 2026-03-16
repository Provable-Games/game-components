//! Test constants and fixtures for the Graffiti library.
//!
//! Since ByteArray is not supported as const in Cairo, we use functions to return test data.

// Common test strings
pub fn empty_string() -> ByteArray {
    ""
}

pub fn simple_text() -> ByteArray {
    "hello"
}

// XML/HTML special characters
pub fn lt_char() -> ByteArray {
    "<"
}

pub fn gt_char() -> ByteArray {
    ">"
}

pub fn amp_char() -> ByteArray {
    "&"
}

pub fn quot_char() -> ByteArray {
    "\""
}

pub fn apos_char() -> ByteArray {
    "'"
}

// JSON special characters
pub fn backslash() -> ByteArray {
    "\\"
}

pub fn newline() -> ByteArray {
    "\n"
}

pub fn tab() -> ByteArray {
    "\t"
}

pub fn carriage_return() -> ByteArray {
    "\r"
}

// Base64 test vectors (RFC 4648)
pub fn base64_input_empty() -> ByteArray {
    ""
}

pub fn base64_output_empty() -> ByteArray {
    ""
}

pub fn base64_input_f() -> ByteArray {
    "f"
}

pub fn base64_output_f() -> ByteArray {
    "Zg=="
}

pub fn base64_input_fo() -> ByteArray {
    "fo"
}

pub fn base64_output_fo() -> ByteArray {
    "Zm8="
}

pub fn base64_input_foo() -> ByteArray {
    "foo"
}

pub fn base64_output_foo() -> ByteArray {
    "Zm9v"
}

pub fn base64_input_foob() -> ByteArray {
    "foob"
}

pub fn base64_output_foob() -> ByteArray {
    "Zm9vYg=="
}

pub fn base64_input_fooba() -> ByteArray {
    "fooba"
}

pub fn base64_output_fooba() -> ByteArray {
    "Zm9vYmE="
}

pub fn base64_input_foobar() -> ByteArray {
    "foobar"
}

pub fn base64_output_foobar() -> ByteArray {
    "Zm9vYmFy"
}

// Data URI prefixes
pub fn svg_data_uri_prefix() -> ByteArray {
    "data:image/svg+xml;base64,"
}

pub fn json_data_uri_prefix() -> ByteArray {
    "data:application/json;base64,"
}

pub fn png_data_uri_prefix() -> ByteArray {
    "data:image/png;base64,"
}

// Sample content
pub fn sample_svg() -> ByteArray {
    "<svg/>"
}

pub fn sample_json() -> ByteArray {
    "{}"
}
