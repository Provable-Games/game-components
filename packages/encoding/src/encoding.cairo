use core::byte_array::ByteArrayTrait;
#[feature("corelib-get-trait")]
use core::byte_array::ByteSpanTrait;
#[feature("byte-span")]
use core::byte_array::ToByteSpanTrait;
#[feature("bounded-int-utils")]
use core::internal::bounded_int::{
    self, AddHelper, BoundedInt, DivRemHelper, MulHelper, UnitInt, upcast,
};
use core::serde::Serde;

type Sextet = BoundedInt<0, 63>;
type TwoBits = BoundedInt<0, 3>;
type FourBits = BoundedInt<0, 15>;
type TripletCount = BoundedInt<0, 0x55555555>;
type TailRemainder = BoundedInt<0, 2>;

impl DivRemBytesLenBy3 of DivRemHelper<usize, UnitInt<3>> {
    type DivT = TripletCount;
    type RemT = TailRemainder;
}

impl DivBy4 of DivRemHelper<u8, UnitInt<4>> {
    type DivT = Sextet;
    type RemT = TwoBits;
}

impl DivBy16 of DivRemHelper<u8, UnitInt<16>> {
    type DivT = FourBits;
    type RemT = FourBits;
}

impl DivBy64 of DivRemHelper<u8, UnitInt<64>> {
    type DivT = TwoBits;
    type RemT = Sextet;
}

impl MulTwoBitsBy16 of MulHelper<TwoBits, UnitInt<16>> {
    type Result = BoundedInt<0, 48>;
}

impl AddSextetPart of AddHelper<BoundedInt<0, 48>, FourBits> {
    type Result = Sextet;
}

impl MulFourBitsBy4 of MulHelper<FourBits, UnitInt<4>> {
    type Result = BoundedInt<0, 60>;
}

impl AddSextetPart4 of AddHelper<BoundedInt<0, 60>, TwoBits> {
    type Result = Sextet;
}

type RawWord = BoundedInt<0, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff>;
type WordHigh = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
type WordLow = BoundedInt<0, 0xffffffffffffffffffffffffffffff>;
impl SplitWord15 of DivRemHelper<RawWord, UnitInt<0x1000000000000000000000000000000>> {
    type DivT = BoundedInt<0, 0xffffffffffffffffffffffffffffffff>;
    type RemT = BoundedInt<0, 0xffffffffffffffffffffffffffffff>;
}
impl DivRemU128TopByte of DivRemHelper<u128, UnitInt<0x1000000000000000000000000000000>> {
    type DivT = BoundedInt<0, 255>;
    type RemT = BoundedInt<0, 0xffffffffffffffffffffffffffffff>;
}
impl ShiftRemainingBytes of MulHelper<
    BoundedInt<0, 0xffffffffffffffffffffffffffffff>, UnitInt<256>,
> {
    type Result = BoundedInt<0, 0xffffffffffffffffffffffffffffff00>;
}

#[derive(Drop)]
struct InputCursor {
    limbs: Array<(u128, usize)>,
    current_value: u128,
    current_len: usize,
    remaining: usize,
}

impl InputCursorIterator of core::iter::Iterator<InputCursor> {
    type Item = u8;

    fn next(ref self: InputCursor) -> Option<u8> {
        if self.remaining == 0 {
            return None;
        }
        if self.current_len == 0 {
            let (value, len) = self.limbs.pop_front().unwrap();
            self.current_value = value;
            self.current_len = len;
        }
        let (quotient, remainder) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000000000000000>,
        >(self.current_value, 0x1000000000000000000000000000000);
        self.current_value = upcast(bounded_int::mul::<_, UnitInt<256>>(remainder, 256));
        self.current_len -= 1;
        self.remaining -= 1;
        Some(upcast(quotient))
    }
}

fn append_cached_limb(ref limbs: Array<(u128, usize)>, value: u128, len: usize) {
    if len == 0 {
        return;
    }
    let mut shift: felt252 = 1;
    let mut padding = 16 - len;
    loop {
        if padding == 0 {
            break;
        }
        shift *= 256;
        padding -= 1;
    }
    let aligned: u128 = (value.into() * shift).try_into().unwrap();
    limbs.append((aligned, len));
}

fn split_word15(word: bytes31) -> (WordHigh, WordLow) {
    let raw: RawWord = upcast(word);
    bounded_int::div_rem::<
        _, UnitInt<0x1000000000000000000000000000000>,
    >(raw, 0x1000000000000000000000000000000)
}

fn into_input_cursor(input: ByteArray, remaining: usize) -> InputCursor {
    let mut serialized = array![];
    input.serialize(ref serialized);
    let mut serialized = serialized.span();
    let word_count: usize = (*serialized.pop_front().unwrap()).try_into().unwrap();
    let mut limbs: Array<(u128, usize)> = array![];
    let mut word_index = 0;
    loop {
        if word_index == word_count {
            break;
        }
        let serialized_word = *serialized.pop_front().unwrap();
        let word: bytes31 = serialized_word.try_into().unwrap();
        let (high, low) = split_word15(word);
        append_cached_limb(ref limbs, upcast(high), 16);
        append_cached_limb(ref limbs, upcast(low), 15);
        word_index += 1;
    }
    let pending_word: bytes31 = (*serialized.pop_front().unwrap()).try_into().unwrap();
    let pending_len: usize = (*serialized.pop_front().unwrap()).try_into().unwrap();
    if pending_len > 15 {
        let (high, low) = split_word15(pending_word);
        append_cached_limb(ref limbs, upcast(high), pending_len - 15);
        append_cached_limb(ref limbs, upcast(low), 15);
    } else {
        let (_, low) = split_word15(pending_word);
        append_cached_limb(ref limbs, upcast(low), pending_len);
    }
    InputCursor { limbs, current_value: 0, current_len: 0, remaining }
}

#[inline(always)]
fn get_base64_char_set() -> Span<u8> {
    let result: [u8; 64] = [
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
        'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
        'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z', '0', '1',
        '2', '3', '4', '5', '6', '7', '8', '9', '+', '/',
    ];
    result.span()
}

pub fn bytes_base64_encode(_bytes: ByteArray) -> ByteArray {
    let bytes_len = _bytes.len();
    if bytes_len == 0 {
        return _bytes;
    }
    let base64_chars = get_base64_char_set();
    if bytes_len <= 5 {
        return encode_bytes(_bytes, bytes_len, base64_chars);
    }
    if bytes_len < 93 {
        return encode_bytes_cached(_bytes, bytes_len, base64_chars);
    }
    encode_bytes_blocked(_bytes, bytes_len, base64_chars)
}


fn encode_bytes_blocked(bytes: ByteArray, bytes_len: usize, base64_chars: Span<u8>) -> ByteArray {
    let (mut result, processed_len, tail_len) = block_engine::encode_full_blocks(
        @bytes, bytes_len, base64_chars,
    );
    if tail_len == 0 {
        return result;
    }
    let input_span = bytes.span();
    let tail_range: core::ops::Range<usize> = processed_len..bytes_len;
    let tail_span = ByteSpanTrait::get(@input_span, tail_range).unwrap();
    let tail_bytes = ByteSpanTrait::to_byte_array(tail_span);
    let mut tail_result = encode_bytes_cached(tail_bytes, tail_len, base64_chars);
    ByteArrayTrait::append(ref result, @tail_result);
    result
}

fn encode_bytes(bytes: ByteArray, bytes_len: usize, base64_chars: Span<u8>) -> ByteArray {
    let mut result: ByteArray = "";
    let (triplet_count, tail_len) = bounded_int::div_rem::<_, UnitInt<3>>(bytes_len, 3);
    let triplet_count: usize = upcast(triplet_count);
    let mut bytes_iter = bytes.into_iter();
    let mut triplets_remaining: felt252 = upcast(triplet_count);
    loop {
        if triplets_remaining == 0 {
            break;
        }
        triplets_remaining -= 1;
        let b0 = bytes_iter.next().unwrap();
        let b1 = bytes_iter.next().unwrap();
        let b2 = bytes_iter.next().unwrap();
        // The custom DivRemHelper results encode the exact ranges of every byte split.
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let (b1_high, b1_low) = bounded_int::div_rem::<_, UnitInt<16>>(b1, 16);
        let (b2_high, e4) = bounded_int::div_rem::<_, UnitInt<64>>(b2, 64);
        let e2 = bounded_int::add(bounded_int::mul::<_, UnitInt<16>>(b0_low, 16), b1_high);
        let e3 = bounded_int::add(bounded_int::mul::<_, UnitInt<4>>(b1_low, 4), b2_high);

        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte(*base64_chars[upcast(e3)]);
        result.append_byte(*base64_chars[upcast(e4)]);
    }

    if tail_len == 1 {
        let b0 = bytes_iter.next().unwrap();
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let e2 = bounded_int::mul::<_, UnitInt<16>>(b0_low, 16);
        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte('=');
        result.append_byte('=');
    } else if tail_len == 2 {
        let b0 = bytes_iter.next().unwrap();
        let b1 = bytes_iter.next().unwrap();
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let (b1_high, b1_low) = bounded_int::div_rem::<_, UnitInt<16>>(b1, 16);
        let e2 = bounded_int::add(bounded_int::mul::<_, UnitInt<16>>(b0_low, 16), b1_high);
        let e3 = bounded_int::mul::<_, UnitInt<4>>(b1_low, 4);
        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte(*base64_chars[upcast(e3)]);
        result.append_byte('=');
    }

    result
}

fn encode_bytes_cached(bytes: ByteArray, bytes_len: usize, base64_chars: Span<u8>) -> ByteArray {
    let mut result: ByteArray = "";
    let (triplet_count, tail_len) = bounded_int::div_rem::<_, UnitInt<3>>(bytes_len, 3);
    let triplet_count: usize = upcast(triplet_count);
    let mut bytes_iter = into_input_cursor(bytes, bytes_len);
    let mut triplets_remaining: felt252 = upcast(triplet_count);
    loop {
        if triplets_remaining == 0 {
            break;
        }
        triplets_remaining -= 1;
        let b0 = bytes_iter.next().unwrap();
        let b1 = bytes_iter.next().unwrap();
        let b2 = bytes_iter.next().unwrap();
        // The custom DivRemHelper results encode the exact ranges of every byte split.
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let (b1_high, b1_low) = bounded_int::div_rem::<_, UnitInt<16>>(b1, 16);
        let (b2_high, e4) = bounded_int::div_rem::<_, UnitInt<64>>(b2, 64);
        let e2 = bounded_int::add(bounded_int::mul::<_, UnitInt<16>>(b0_low, 16), b1_high);
        let e3 = bounded_int::add(bounded_int::mul::<_, UnitInt<4>>(b1_low, 4), b2_high);

        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte(*base64_chars[upcast(e3)]);
        result.append_byte(*base64_chars[upcast(e4)]);
    }

    if tail_len == 1 {
        let b0 = bytes_iter.next().unwrap();
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let e2 = bounded_int::mul::<_, UnitInt<16>>(b0_low, 16);
        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte('=');
        result.append_byte('=');
    } else if tail_len == 2 {
        let b0 = bytes_iter.next().unwrap();
        let b1 = bytes_iter.next().unwrap();
        let (e1, b0_low) = bounded_int::div_rem::<_, UnitInt<4>>(b0, 4);
        let (b1_high, b1_low) = bounded_int::div_rem::<_, UnitInt<16>>(b1, 16);
        let e2 = bounded_int::add(bounded_int::mul::<_, UnitInt<16>>(b0_low, 16), b1_high);
        let e3 = bounded_int::mul::<_, UnitInt<4>>(b1_low, 4);
        result.append_byte(*base64_chars[upcast(e1)]);
        result.append_byte(*base64_chars[upcast(e2)]);
        result.append_byte(*base64_chars[upcast(e3)]);
        result.append_byte('=');
    }

    result
}

mod block_engine {
    use core::array::Span;
    use core::byte_array::{ByteArray, ByteArrayTrait};
    #[feature("bounded-int-utils")]
    use core::internal::bounded_int::{
        self, AddHelper, BoundedInt, DivRemHelper, MulHelper, UnitInt, upcast,
    };
    use super::{WordHigh, WordLow, split_word15};

    type B128 = WordHigh;
    type B120 = WordLow;
    type B136 = BoundedInt<0, 0xffffffffffffffffffffffffffffffffff>;
    type B144 = BoundedInt<0, 0xffffffffffffffffffffffffffffffffffff>;
    type B112 = BoundedInt<0, 0xffffffffffffffffffffffffffff>;
    type B104 = BoundedInt<0, 0xffffffffffffffffffffffffff>;
    type B96 = BoundedInt<0, 0xffffffffffffffffffffffff>;
    type B88 = BoundedInt<0, 0xffffffffffffffffffffff>;
    type B80 = BoundedInt<0, 0xffffffffffffffffffff>;
    type B72 = BoundedInt<0, 0xffffffffffffffffff>;
    type B64 = BoundedInt<0, 0xffffffffffffffff>;
    type B56 = BoundedInt<0, 0xffffffffffffff>;
    type B48 = BoundedInt<0, 0xffffffffffff>;
    type B40 = BoundedInt<0, 0xffffffffff>;
    type B32 = BoundedInt<0, 0xffffffff>;
    type B24 = BoundedInt<0, 0xffffff>;
    type B16 = BoundedInt<0, 0xffff>;
    type B12 = BoundedInt<0, 0xfff>;
    type B8 = BoundedInt<0, 0xff>;
    type B6 = BoundedInt<0, 0x3f>;

    type FullBlockCount = BoundedInt<0, 0x2c0b02c>;
    type FullBlockTailLength = BoundedInt<0, 92>;
    type ProcessedFullBlockLength = BoundedInt<0, 0xfffffffc>;

    // ByteArray.len() is usize (u32), so the quotient and exact result bounds follow directly.
    impl DivRemInputLengthBy93 of DivRemHelper<usize, UnitInt<93>> {
        type DivT = FullBlockCount;
        type RemT = FullBlockTailLength;
    }
    impl MulFullBlockCountBy93 of MulHelper<FullBlockCount, UnitInt<93>> {
        type Result = ProcessedFullBlockLength;
    }

    type Prefix8At120Range = BoundedInt<0, 0xff000000000000000000000000000000>;
    impl MulPrefix8At120 of MulHelper<B8, UnitInt<0x1000000000000000000000000000000>> {
        type Result = Prefix8At120Range;
    }
    impl AddPrefix8At120 of AddHelper<Prefix8At120Range, B120> {
        type Result = B128;
    }

    type Prefix8At128Range = BoundedInt<0, 0xff00000000000000000000000000000000>;
    impl MulPrefix8At128 of MulHelper<B8, UnitInt<0x100000000000000000000000000000000>> {
        type Result = Prefix8At128Range;
    }
    impl AddPrefix8At128 of AddHelper<Prefix8At128Range, B128> {
        type Result = B136;
    }

    type Prefix16At120Range = BoundedInt<0, 0xffff000000000000000000000000000000>;
    impl MulPrefix16At120 of MulHelper<B16, UnitInt<0x1000000000000000000000000000000>> {
        type Result = Prefix16At120Range;
    }
    impl AddPrefix16At120 of AddHelper<Prefix16At120Range, B120> {
        type Result = B136;
    }

    type Prefix16At128Range = BoundedInt<0, 0xffff00000000000000000000000000000000>;
    impl MulPrefix16At128 of MulHelper<B16, UnitInt<0x100000000000000000000000000000000>> {
        type Result = Prefix16At128Range;
    }
    impl AddPrefix16At128 of AddHelper<Prefix16At128Range, B128> {
        type Result = B144;
    }

    impl DivRem128By104 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffffffffff>, UnitInt<0x100000000000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffffffffff>;
    }
    impl DivRem104By80 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffff>, UnitInt<0x100000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffff>;
    }
    impl DivRem80By56 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffff>, UnitInt<0x100000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffff>;
    }
    impl DivRem56By32 of DivRemHelper<BoundedInt<0, 0xffffffffffffff>, UnitInt<0x100000000>> {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffff>;
    }
    impl DivRem32By8 of DivRemHelper<BoundedInt<0, 0xffffffff>, UnitInt<0x100>> {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xff>;
    }
    impl DivRem136By112 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffffffffffff>,
        UnitInt<0x10000000000000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffffffffffff>;
    }
    impl DivRem112By88 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffffff>, UnitInt<0x10000000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffffff>;
    }
    impl DivRem88By64 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffff>, UnitInt<0x10000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffff>;
    }
    impl DivRem64By40 of DivRemHelper<BoundedInt<0, 0xffffffffffffffff>, UnitInt<0x10000000000>> {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffff>;
    }
    impl DivRem40By16 of DivRemHelper<BoundedInt<0, 0xffffffffff>, UnitInt<0x10000>> {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffff>;
    }
    impl DivRem144By120 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffffffffffffff>,
        UnitInt<0x1000000000000000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffffffffffffff>;
    }
    impl DivRem120By96 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffffffffff>, UnitInt<0x1000000000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffffffffff>;
    }
    impl DivRem96By72 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffffffffff>, UnitInt<0x1000000000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffffffffff>;
    }
    impl DivRem72By48 of DivRemHelper<
        BoundedInt<0, 0xffffffffffffffffff>, UnitInt<0x1000000000000>,
    > {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffffffffff>;
    }
    impl DivRem48By24 of DivRemHelper<BoundedInt<0, 0xffffffffffff>, UnitInt<0x1000000>> {
        type DivT = BoundedInt<0, 0xffffff>;
        type RemT = BoundedInt<0, 0xffffff>;
    }

    fn peel16(value: B128) -> (B24, B24, B24, B24, B24, B8) {
        let (g0, r0) = bounded_int::div_rem::<
            _, UnitInt<0x100000000000000000000000000>,
        >(value, 0x100000000000000000000000000);
        let (g1, r1) = bounded_int::div_rem::<
            _, UnitInt<0x100000000000000000000>,
        >(r0, 0x100000000000000000000);
        let (g2, r2) = bounded_int::div_rem::<_, UnitInt<0x100000000000000>>(r1, 0x100000000000000);
        let (g3, r3) = bounded_int::div_rem::<_, UnitInt<0x100000000>>(r2, 0x100000000);
        let (g4, r4) = bounded_int::div_rem::<_, UnitInt<0x100>>(r3, 0x100);
        (g0, g1, g2, g3, g4, r4)
    }

    fn peel17(value: B136) -> (B24, B24, B24, B24, B24, B16) {
        let (g0, r0) = bounded_int::div_rem::<
            _, UnitInt<0x10000000000000000000000000000>,
        >(value, 0x10000000000000000000000000000);
        let (g1, r1) = bounded_int::div_rem::<
            _, UnitInt<0x10000000000000000000000>,
        >(r0, 0x10000000000000000000000);
        let (g2, r2) = bounded_int::div_rem::<
            _, UnitInt<0x10000000000000000>,
        >(r1, 0x10000000000000000);
        let (g3, r3) = bounded_int::div_rem::<_, UnitInt<0x10000000000>>(r2, 0x10000000000);
        let (g4, r4) = bounded_int::div_rem::<_, UnitInt<0x10000>>(r3, 0x10000);
        (g0, g1, g2, g3, g4, r4)
    }

    fn peel18(value: B144) -> (B24, B24, B24, B24, B24, B24) {
        let (g0, r0) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000000000000000>,
        >(value, 0x1000000000000000000000000000000);
        let (g1, r1) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000000000>,
        >(r0, 0x1000000000000000000000000);
        let (g2, r2) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000>,
        >(r1, 0x1000000000000000000);
        let (g3, r3) = bounded_int::div_rem::<_, UnitInt<0x1000000000000>>(r2, 0x1000000000000);
        let (g4, r4) = bounded_int::div_rem::<_, UnitInt<0x1000000>>(r3, 0x1000000);
        (g0, g1, g2, g3, g4, r4)
    }

    fn peel15(value: B120) -> (B24, B24, B24, B24, B24) {
        let (g0, r0) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000000000>,
        >(value, 0x1000000000000000000000000);
        let (g1, r1) = bounded_int::div_rem::<
            _, UnitInt<0x1000000000000000000>,
        >(r0, 0x1000000000000000000);
        let (g2, r2) = bounded_int::div_rem::<_, UnitInt<0x1000000000000>>(r1, 0x1000000000000);
        let (g3, r3) = bounded_int::div_rem::<_, UnitInt<0x1000000>>(r2, 0x1000000);
        (g0, g1, g2, g3, r3)
    }

    impl SplitGroup24 of DivRemHelper<B24, UnitInt<0x1000>> {
        type DivT = B12;
        type RemT = B12;
    }
    impl SplitGroup12 of DivRemHelper<B12, UnitInt<0x40>> {
        type DivT = B6;
        type RemT = B6;
    }

    fn encode_group(value: B24, chars: Span<u8>) -> (u8, u8, u8, u8) {
        let (high12, low12) = bounded_int::div_rem::<_, UnitInt<0x1000>>(value, 0x1000);
        let (s0, s1) = bounded_int::div_rem::<_, UnitInt<0x40>>(high12, 0x40);
        let (s2, s3) = bounded_int::div_rem::<_, UnitInt<0x40>>(low12, 0x40);
        (*chars[upcast(s0)], *chars[upcast(s1)], *chars[upcast(s2)], *chars[upcast(s3)])
    }

    fn encode_groups5(
        g0: B24, g1: B24, g2: B24, g3: B24, g4: B24, chars: Span<u8>,
    ) -> (
        (u8, u8, u8, u8), (u8, u8, u8, u8), (u8, u8, u8, u8), (u8, u8, u8, u8), (u8, u8, u8, u8),
    ) {
        (
            encode_group(g0, chars),
            encode_group(g1, chars),
            encode_group(g2, chars),
            encode_group(g3, chars),
            encode_group(g4, chars),
        )
    }

    #[inline(always)]
    fn encode_groups6(
        g0: B24, g1: B24, g2: B24, g3: B24, g4: B24, g5: B24, chars: Span<u8>,
    ) -> (
        (u8, u8, u8, u8),
        (u8, u8, u8, u8),
        (u8, u8, u8, u8),
        (u8, u8, u8, u8),
        (u8, u8, u8, u8),
        (u8, u8, u8, u8),
    ) {
        (
            encode_group(g0, chars),
            encode_group(g1, chars),
            encode_group(g2, chars),
            encode_group(g3, chars),
            encode_group(g4, chars),
            encode_group(g5, chars),
        )
    }

    fn pack4(chars: (u8, u8, u8, u8)) -> felt252 {
        let (c0, c1, c2, c3) = chars;
        upcast(c0) * 0x1000000 + upcast(c1) * 0x10000 + upcast(c2) * 0x100 + upcast(c3)
    }

    fn pack3(c0: u8, c1: u8, c2: u8) -> felt252 {
        upcast(c0) * 0x10000 + upcast(c1) * 0x100 + upcast(c2)
    }

    fn pack2(c0: u8, c1: u8) -> felt252 {
        upcast(c0) * 0x100 + upcast(c1)
    }

    fn encode_block(ref output: ByteArray, wa: bytes31, wb: bytes31, wc: bytes31, chars: Span<u8>) {
        let (a_high, a_low) = split_word15(wa);
        let (b_high, b_low) = split_word15(wb);
        let (c_high, c_low) = split_word15(wc);
        let (g0, g1, g2, g3, g4, c0) = peel16(a_high);
        let (e0, e1, e2, e3, e4) = encode_groups5(g0, g1, g2, g3, g4, chars);
        let carry0 = bounded_int::mul::<
            _, UnitInt<0x1000000000000000000000000000000>,
        >(c0, 0x1000000000000000000000000000000);
        let x = bounded_int::add(carry0, a_low);
        let (g5, g6, g7, g8, g9, c1) = peel16(x);
        let (e5, e6, e7, e8, e9) = encode_groups5(g5, g6, g7, g8, g9, chars);
        let carry1 = bounded_int::mul::<
            _, UnitInt<0x100000000000000000000000000000000>,
        >(c1, 0x100000000000000000000000000000000);
        let y = bounded_int::add(carry1, b_high);
        let (g10, g11, g12, g13, g14, c2) = peel17(y);
        let (e10, e11, e12, e13, e14) = encode_groups5(g10, g11, g12, g13, g14, chars);
        let carry2 = bounded_int::mul::<
            _, UnitInt<0x1000000000000000000000000000000>,
        >(c2, 0x1000000000000000000000000000000);
        let z = bounded_int::add(carry2, b_low);
        let (g15, g16, g17, g18, g19, c3) = peel17(z);
        let (e15, e16, e17, e18, e19) = encode_groups5(g15, g16, g17, g18, g19, chars);
        let carry3 = bounded_int::mul::<
            _, UnitInt<0x100000000000000000000000000000000>,
        >(c3, 0x100000000000000000000000000000000);
        let u = bounded_int::add(carry3, c_high);
        let (g20, g21, g22, g23, g24, g25) = peel18(u);
        let (e20, e21, e22, e23, e24, e25) = encode_groups6(g20, g21, g22, g23, g24, g25, chars);
        let (g26, g27, g28, g29, g30) = peel15(c_low);
        let (e26, e27, e28, e29, e30) = encode_groups5(g26, g27, g28, g29, g30, chars);
        let (e7_0, e7_1, e7_2, e7_3) = e7;
        let (e15_0, e15_1, e15_2, e15_3) = e15;
        let (e23_0, e23_1, e23_2, e23_3) = e23;
        let word0: felt252 = pack4(e0) * 0x1000000000000000000000000000000000000000000000000000000
            + pack4(e1) * 0x10000000000000000000000000000000000000000000000
            + pack4(e2) * 0x100000000000000000000000000000000000000
            + pack4(e3) * 0x1000000000000000000000000000000
            + pack4(e4) * 0x10000000000000000000000
            + pack4(e5) * 0x100000000000000
            + pack4(e6) * 0x1000000
            + pack3(e7_0, e7_1, e7_2);
        let word1: felt252 = upcast(e7_3)
            * 0x1000000000000000000000000000000000000000000000000000000000000
            + pack4(e8) * 0x10000000000000000000000000000000000000000000000000000
            + pack4(e9) * 0x100000000000000000000000000000000000000000000
            + pack4(e10) * 0x1000000000000000000000000000000000000
            + pack4(e11) * 0x10000000000000000000000000000
            + pack4(e12) * 0x100000000000000000000
            + pack4(e13) * 0x1000000000000
            + pack4(e14) * 0x10000
            + pack2(e15_0, e15_1);
        let word2: felt252 = pack2(e15_2, e15_3)
            * 0x10000000000000000000000000000000000000000000000000000000000
            + pack4(e16) * 0x100000000000000000000000000000000000000000000000000
            + pack4(e17) * 0x1000000000000000000000000000000000000000000
            + pack4(e18) * 0x10000000000000000000000000000000000
            + pack4(e19) * 0x100000000000000000000000000
            + pack4(e20) * 0x1000000000000000000
            + pack4(e21) * 0x10000000000
            + pack4(e22) * 0x100
            + upcast(e23_0);
        let word3: felt252 = pack3(e23_1, e23_2, e23_3)
            * 0x100000000000000000000000000000000000000000000000000000000
            + pack4(e24) * 0x1000000000000000000000000000000000000000000000000
            + pack4(e25) * 0x10000000000000000000000000000000000000000
            + pack4(e26) * 0x100000000000000000000000000000000
            + pack4(e27) * 0x1000000000000000000000000
            + pack4(e28) * 0x10000000000000000
            + pack4(e29) * 0x100000000
            + pack4(e30) * 0x1;
        // Each word contains exactly 31 ASCII bytes and is below 2^248.
        output.append_word(word0, 31);
        output.append_word(word1, 31);
        output.append_word(word2, 31);
        output.append_word(word3, 31);
    }

    pub(crate) fn encode_full_blocks(
        bytes: @ByteArray, bytes_len: usize, chars: Span<u8>,
    ) -> (ByteArray, usize, usize) {
        let mut serialized = array![];
        bytes.serialize(ref serialized);
        let mut serialized = serialized.span();
        let _word_count = *serialized.pop_front().unwrap();
        let (block_count, tail_len) = bounded_int::div_rem::<_, UnitInt<93>>(bytes_len, 93);
        let mut output: ByteArray = "";
        let mut blocks_remaining: felt252 = upcast(block_count);
        loop {
            if blocks_remaining == 0 {
                break;
            }
            blocks_remaining -= 1;
            let wa_serialized = *serialized.pop_front().unwrap();
            let wa: bytes31 = wa_serialized.try_into().unwrap();
            let wb_serialized = *serialized.pop_front().unwrap();
            let wb: bytes31 = wb_serialized.try_into().unwrap();
            let wc_serialized = *serialized.pop_front().unwrap();
            let wc: bytes31 = wc_serialized.try_into().unwrap();
            encode_block(ref output, wa, wb, wc, chars);
        }
        let processed_len: usize = upcast(bounded_int::mul::<_, UnitInt<93>>(block_count, 93));
        (output, processed_len, upcast(tail_len))
    }
}
