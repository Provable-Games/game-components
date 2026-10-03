use core::byte_array::ByteArray;

#[starknet::interface]
pub trait ILabBenchmark<TContractState> {
    fn input_len(self: @TContractState, input: ByteArray) -> usize;
    fn encode_len(self: @TContractState, input: ByteArray) -> usize;
    fn encode(self: @TContractState, input: ByteArray) -> ByteArray;
}

#[starknet::contract]
pub mod LabBenchmarkHarness {
    use core::byte_array::ByteArray;
    use game_components_encoding::encoding::bytes_base64_encode;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl LabBenchmarkImpl of super::ILabBenchmark<ContractState> {
        fn input_len(self: @ContractState, input: ByteArray) -> usize {
            input.len()
        }

        fn encode_len(self: @ContractState, input: ByteArray) -> usize {
            bytes_base64_encode(input).len()
        }

        fn encode(self: @ContractState, input: ByteArray) -> ByteArray {
            bytes_base64_encode(input)
        }
    }
}
