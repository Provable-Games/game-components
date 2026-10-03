use core::byte_array::ByteArray;
use core::serde::Serde;
use game_components_encoding::encoding::bytes_base64_encode;
use game_components_encoding_harness::lab_benchmark_harness::{
    ILabBenchmarkDispatcher, ILabBenchmarkDispatcherTrait,
};
use snforge_std::fs::{FileTrait, read_txt};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[derive(Drop, Serde)]
struct AccuracyFixture {
    input: ByteArray,
    expected: ByteArray,
}

pub fn accuracy_batch(path: ByteArray, expected_cases: usize) {
    let file = FileTrait::new(path);
    let data = read_txt(@file);
    let mut serialized = data.span();
    let cases = Serde::<usize>::deserialize(ref serialized).expect('missing accuracy count');
    assert(cases == expected_cases, 'accuracy case count');
    let class = declare("LabBenchmarkHarness").unwrap().contract_class();
    let (contract_address, _) = class.deploy(@array![]).unwrap();
    let dispatcher = ILabBenchmarkDispatcher { contract_address };
    for _ in 0..cases {
        let fixture = Serde::<AccuracyFixture>::deserialize(ref serialized)
            .expect('invalid accuracy fixture');
        let input_len = fixture.input.len();
        assert(fixture.expected.len() == ((input_len + 2) / 3) * 4, 'accuracy output length');
        let output = dispatcher.encode(fixture.input.clone());
        assert(output == fixture.expected, 'production Base64 mismatch');
        let helper_output = bytes_base64_encode(fixture.input);
        assert(helper_output == fixture.expected, 'helper Base64 mismatch');
    }
    assert(serialized.is_empty(), 'trailing accuracy data');
}
