use core::num::traits::{Bounded, Zero};

#[inline(always)]
fn get_base64_char_set() -> Span<u8> {
    let mut result = array![
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
        'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
        'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1',
        '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
    ];
    result.span()
}

pub fn bytes_base64_encode(_bytes: ByteArray) -> ByteArray {
    encode_bytes(_bytes, get_base64_char_set())
}


fn encode_bytes(mut bytes: ByteArray, base64_chars: Span<u8>) -> ByteArray {
    let mut result: ByteArray = "";
    if bytes.len() == 0 {
        return result;
    }
    let mut p: u8 = 0;
    let c = bytes.len() % 3;
    if c == 1 {
        p = 2;
        bytes.append_byte(0_u8);
        bytes.append_byte(0_u8);
    } else if c == 2 {
        p = 1;
        bytes.append_byte(0_u8);
    }

    let mut i = 0;
    let bytes_len = bytes.len();
    let last_iteration = bytes_len - 3;
    loop {
        if i == bytes_len {
            break;
        }
        let n: u32 = (bytes.at(i).unwrap()).into()
            * 65536 | (bytes.at(i + 1).unwrap()).into()
            * 256 | (bytes.at(i + 2).unwrap()).into();
        let e1 = (n / 262144) & 63;
        let e2 = (n / 4096) & 63;
        let e3 = (n / 64) & 63;
        let e4 = n & 63;

        if i == last_iteration {
            if p == 2 {
                result.append_byte(*base64_chars[e1]);
                result.append_byte(*base64_chars[e2]);
                result.append_byte('=');
                result.append_byte('=');
            } else if p == 1 {
                result.append_byte(*base64_chars[e1]);
                result.append_byte(*base64_chars[e2]);
                result.append_byte(*base64_chars[e3]);
                result.append_byte('=');
            } else {
                result.append_byte(*base64_chars[e1]);
                result.append_byte(*base64_chars[e2]);
                result.append_byte(*base64_chars[e3]);
                result.append_byte(*base64_chars[e4]);
            }
        } else {
            result.append_byte(*base64_chars[e1]);
            result.append_byte(*base64_chars[e2]);
            result.append_byte(*base64_chars[e3]);
            result.append_byte(*base64_chars[e4]);
        }

        i += 3;
    }
    result
}

trait BytesUsedTrait<T> {
    /// Returns the number of bytes used to represent a `T` value.
    /// # Arguments
    /// * `self` - The value to check.
    /// # Returns
    /// The number of bytes used to represent the value.
    fn bytes_used(self: T) -> u8;
}

impl U8BytesUsedTraitImpl of BytesUsedTrait<u8> {
    fn bytes_used(self: u8) -> u8 {
        if self == 0 {
            return 0;
        }

        return 1;
    }
}

impl USizeBytesUsedTraitImpl of BytesUsedTrait<usize> {
    fn bytes_used(self: usize) -> u8 {
        if self < 0x10000 { // 256^2
            if self < 0x100 { // 256^1
                if self == 0 {
                    return 0;
                } else {
                    return 1;
                };
            }
            return 2;
        } else {
            if self < 0x1000000 { // 256^3
                return 3;
            }
            return 4;
        }
    }
}

impl U64BytesUsedTraitImpl of BytesUsedTrait<u64> {
    fn bytes_used(self: u64) -> u8 {
        if self <= Bounded::<u32>::MAX.into() { // 256^4
            return BytesUsedTrait::<u32>::bytes_used(self.try_into().unwrap());
        } else {
            if self < 0x1000000000000 { // 256^6
                if self < 0x10000000000 { // 256^5
                    if self < 0x100000000 { // 256^4
                        return 4;
                    }
                    return 5;
                }
                return 6;
            } else {
                if self < 0x100000000000000 { // 256^7
                    return 7;
                } else {
                    return 8;
                }
            }
        }
    }
}


impl U128BytesUsedTraitImpl of BytesUsedTrait<u128> {
    fn bytes_used(self: u128) -> u8 {
        if self <= Bounded::<u64>::MAX.into() { // 256^8
            return BytesUsedTrait::<u64>::bytes_used(self.try_into().unwrap());
        } else {
            if self < 0x1000000000000000000000000 { // 256^12
                if self < 0x100000000000000000000 { // 256^10
                    if self < 0x1000000000000000000 { // 256^9
                        return 9;
                    }
                    return 10;
                }
                if self < 0x10000000000000000000000 { // 256^11
                    return 11;
                }
                return 12;
            } else {
                if self < 0x10000000000000000000000000000 { // 256^14
                    if self < 0x100000000000000000000000000 { // 256^13
                        return 13;
                    }
                    return 14;
                } else {
                    if self < 0x1000000000000000000000000000000 { // 256^15
                        return 15;
                    }
                    return 16;
                }
            }
        }
    }
}

pub impl U256BytesUsedTraitImpl of BytesUsedTrait<u256> {
    fn bytes_used(self: u256) -> u8 {
        if self.high == 0 {
            return BytesUsedTrait::<u128>::bytes_used(self.low.try_into().unwrap());
        } else {
            return BytesUsedTrait::<u128>::bytes_used(self.high.try_into().unwrap()) + 16;
        }
    }
}

pub fn felt252_to_byte_array(value: felt252) -> ByteArray {
    let mut result: ByteArray = Default::default();
    if value.is_non_zero() {
        result.append_word(value, U256BytesUsedTraitImpl::bytes_used(value.into()).into());
    }
    result
}

/// Converts a u128 number to its ASCII decimal representation packed into a felt252.
/// For example: 42 -> 0x3432 ('42'), 1000 -> 0x31303030 ('1000').
/// Maximum felt252 can hold 31 bytes, so numbers up to 31 digits are supported.
/// Panics if the number exceeds 31 digits.
pub fn u128_to_ascii_felt(mut value: u128) -> felt252 {
    if value == 0 {
        return '0';
    }

    // Build digits in reverse order
    let mut digits: Array<u8> = array![];
    loop {
        if value == 0 {
            break;
        }
        let digit: u8 = (value % 10).try_into().unwrap();
        digits.append(digit + '0');
        value /= 10;
    }

    assert!(digits.len() <= 31, "Number exceeds 31 digits, cannot fit in felt252");

    // Pack digits into felt252 in correct order (reverse of how we collected them)
    let len = digits.len();
    let mut result: felt252 = 0;
    let mut i = len;
    loop {
        if i == 0 {
            break;
        }
        i -= 1;
        result = result * 256 + (*digits.at(i)).into();
    }
    result
}
