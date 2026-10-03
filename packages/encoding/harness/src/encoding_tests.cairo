#[cfg(test)]
mod tests {
    use core::byte_array::ByteArray;
    use game_components_encoding::encoding::bytes_base64_encode;

    #[test]
    fn test_empty_input() {
        assert(bytes_base64_encode("") == "", 'empty input');
    }

    #[test]
    fn test_rfc4648_text_vectors_and_padding() {
        assert(bytes_base64_encode("f") == "Zg==", 'one byte padding');
        assert(bytes_base64_encode("fo") == "Zm8=", 'two byte padding');
        assert(bytes_base64_encode("foo") == "Zm9v", 'three byte block');
        assert(bytes_base64_encode("foob") == "Zm9vYg==", 'four byte input');
        assert(bytes_base64_encode("fooba") == "Zm9vYmE=", 'five byte input');
        assert(bytes_base64_encode("foobar") == "Zm9vYmFy", 'six byte input');
    }

    #[test]
    fn test_binary_values() {
        let mut one_byte: ByteArray = "";
        one_byte.append_byte(0_u8);
        assert(bytes_base64_encode(one_byte) == "AA==", 'zero byte');

        let mut two_bytes: ByteArray = "";
        two_bytes.append_byte(0xff_u8);
        two_bytes.append_byte(0_u8);
        assert(bytes_base64_encode(two_bytes) == "/wA=", 'binary two byte input');

        let mut three_bytes: ByteArray = "";
        three_bytes.append_byte(0xfb_u8);
        three_bytes.append_byte(0xff_u8);
        three_bytes.append_byte(0xff_u8);
        assert(bytes_base64_encode(three_bytes) == "+///", 'binary three byte input');
    }

    #[test]
    fn test_crosses_byte_array_word_boundary() {
        let mut input: ByteArray = "";
        let mut i: usize = 0;
        loop {
            if i == 32 {
                break;
            }
            input.append_byte(0xa5_u8);
            i += 1;
        }
        let output = bytes_base64_encode(input);
        assert(output.len() == 44, '32-byte output length');
        assert(output.at(42).unwrap() != '=', '32-byte final data character');
        assert(output.at(43).unwrap() == '=', '32-byte padding');
    }
}
