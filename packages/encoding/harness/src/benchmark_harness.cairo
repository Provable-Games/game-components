use core::byte_array::ByteArray;

#[starknet::interface]
pub trait IBase64Benchmark<TContractState> {
    fn input_len_0(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_1(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_2(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_3(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_4(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_5(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_6(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_7(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_8(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_9(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_10(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_11(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_30(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_31(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_32(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_33(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_61(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_62(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_63(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_64(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_127(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_128(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_129(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_255(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_256(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_257(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_511(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_512(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_513(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_1023(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_1024(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_1025(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_2048(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_4095(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_4096(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_4097(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_8191(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_8192(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_8193(ref self: TContractState, input: ByteArray) -> usize;
    fn input_len_16384(ref self: TContractState, input: ByteArray) -> usize;
    fn encode_0(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_1(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_2(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_3(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_4(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_5(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_6(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_7(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_8(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_9(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_10(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_11(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_30(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_31(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_32(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_33(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_61(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_62(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_63(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_64(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_127(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_128(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_129(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_255(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_256(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_257(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_511(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_512(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_513(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_1023(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_1024(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_1025(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_2048(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_4095(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_4096(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_4097(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_8191(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_8192(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_8193(ref self: TContractState, input: ByteArray) -> ByteArray;
    fn encode_16384(ref self: TContractState, input: ByteArray) -> ByteArray;
}

#[starknet::contract]
pub mod BenchmarkHarness {
    use core::byte_array::ByteArray;
    use game_components_encoding::encoding::bytes_base64_encode;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl Base64BenchmarkImpl of super::IBase64Benchmark<ContractState> {
        fn input_len_0(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_1(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_2(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_3(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_4(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_5(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_6(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_7(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_8(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_9(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_10(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_11(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_30(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_31(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_32(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_33(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_61(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_62(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_63(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_64(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_127(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_128(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_129(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_255(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_256(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_257(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_511(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_512(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_513(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_1023(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_1024(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_1025(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_2048(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_4095(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_4096(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_4097(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_8191(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_8192(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_8193(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn input_len_16384(ref self: ContractState, input: ByteArray) -> usize {
            input.len()
        }
        fn encode_0(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_1(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_2(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_3(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_4(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_5(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_6(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_7(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_8(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_9(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_10(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_11(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_30(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_31(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_32(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_33(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_61(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_62(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_63(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_64(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_127(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_128(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_129(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_255(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_256(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_257(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_511(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_512(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_513(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_1023(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_1024(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_1025(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_2048(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_4095(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_4096(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_4097(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_8191(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_8192(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_8193(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
        fn encode_16384(ref self: ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
    }
}
