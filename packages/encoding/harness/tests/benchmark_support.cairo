use core::byte_array::ByteArray;
use core::serde::Serde;
use game_components_encoding::encoding::bytes_base64_encode;
use game_components_encoding_harness::lab_benchmark_harness::{
    ILabBenchmarkDispatcher, ILabBenchmarkDispatcherTrait,
};
use snforge_std::fs::{FileTrait, read_txt};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[derive(Drop, Serde)]
struct Fixture {
    input: ByteArray,
    expected: ByteArray,
}

pub fn benchmark_case(path: ByteArray, input_len: usize) {
    // Fixtures and assertions execute in the test runner, outside measured contract selectors.
    let file = FileTrait::new(path);
    let data = read_txt(@file);
    let mut serialized = data.span();
    let fixture = Serde::<Fixture>::deserialize(ref serialized).expect('invalid fixture');
    assert(serialized.is_empty(), 'trailing fixture data');
    assert(fixture.input.len() == input_len, 'fixture input length');
    assert(fixture.expected.len() == ((input_len + 2) / 3) * 4, 'fixture output length');

    let class = declare("LabBenchmarkHarness").unwrap().contract_class();
    let (contract_address, _) = class.deploy(@array![]).unwrap();
    let dispatcher = ILabBenchmarkDispatcher { contract_address };
    // Three calls to each selector let the report verify deterministic per-call min/max costs.
    for _ in 0_u32..3_u32 {
        let control = dispatcher.input_len(fixture.input.clone());
        assert(control == input_len, 'input length control');
        let encoded_len = dispatcher.encode_len(fixture.input.clone());
        assert(encoded_len == fixture.expected.len(), 'encoded length control');
        let output = dispatcher.encode(fixture.input.clone());
        assert(output == fixture.expected, 'full Base64 output mismatch');
    }
}

pub fn oracle_batch(path: ByteArray, expected_cases: usize) {
    let file = FileTrait::new(path);
    let data = read_txt(@file);
    let mut serialized = data.span();
    let cases = Serde::<usize>::deserialize(ref serialized).expect('missing case count');
    assert(cases == expected_cases, 'oracle case count');
    for _ in 0..cases {
        let fixture = Serde::<Fixture>::deserialize(ref serialized)
            .expect('invalid oracle fixture');
        let output = bytes_base64_encode(fixture.input);
        assert(output == fixture.expected, 'Python Base64 oracle mismatch');
    }
    assert(serialized.is_empty(), 'trailing oracle data');
}
