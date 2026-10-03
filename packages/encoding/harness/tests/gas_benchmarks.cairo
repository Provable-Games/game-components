use core::byte_array::ByteArray;
use game_components_encoding_harness::benchmark_harness::{
    IBase64BenchmarkDispatcher, IBase64BenchmarkDispatcherTrait,
};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

fn setup() -> IBase64BenchmarkDispatcher {
    let class = declare("BenchmarkHarness").unwrap().contract_class();
    let (contract_address, _) = class.deploy(@array![]).unwrap();
    IBase64BenchmarkDispatcher { contract_address }
}

fn make_payload(size: usize) -> ByteArray {
    let mut bytes: ByteArray = "";
    let mut i: usize = 0;
    loop {
        if i == size {
            break;
        }
        bytes.append_byte(0xa5_u8);
        i += 1;
    }
    bytes
}

fn expected_output_len(size: usize) -> usize {
    ((size + 2) / 3) * 4
}

#[test]
fn gas_input_0() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_0(make_payload(0));
    assert(decoded_len == 0, 'input length control');
    let output = dispatcher.encode_0(make_payload(0));
    assert(output.len() == expected_output_len(0), 'encoded length');
}

#[test]
fn gas_input_1() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_1(make_payload(1));
    assert(decoded_len == 1, 'input length control');
    let output = dispatcher.encode_1(make_payload(1));
    assert(output.len() == expected_output_len(1), 'encoded length');
}

#[test]
fn gas_input_2() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_2(make_payload(2));
    assert(decoded_len == 2, 'input length control');
    let output = dispatcher.encode_2(make_payload(2));
    assert(output.len() == expected_output_len(2), 'encoded length');
}

#[test]
fn gas_input_3() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_3(make_payload(3));
    assert(decoded_len == 3, 'input length control');
    let output = dispatcher.encode_3(make_payload(3));
    assert(output.len() == expected_output_len(3), 'encoded length');
}

#[test]
fn gas_input_4() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_4(make_payload(4));
    assert(decoded_len == 4, 'input length control');
    let output = dispatcher.encode_4(make_payload(4));
    assert(output.len() == expected_output_len(4), 'encoded length');
}

#[test]
fn gas_input_5() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_5(make_payload(5));
    assert(decoded_len == 5, 'input length control');
    let output = dispatcher.encode_5(make_payload(5));
    assert(output.len() == expected_output_len(5), 'encoded length');
}

#[test]
fn gas_input_6() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_6(make_payload(6));
    assert(decoded_len == 6, 'input length control');
    let output = dispatcher.encode_6(make_payload(6));
    assert(output.len() == expected_output_len(6), 'encoded length');
}

#[test]
fn gas_input_7() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_7(make_payload(7));
    assert(decoded_len == 7, 'input length control');
    let output = dispatcher.encode_7(make_payload(7));
    assert(output.len() == expected_output_len(7), 'encoded length');
}

#[test]
fn gas_input_8() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_8(make_payload(8));
    assert(decoded_len == 8, 'input length control');
    let output = dispatcher.encode_8(make_payload(8));
    assert(output.len() == expected_output_len(8), 'encoded length');
}

#[test]
fn gas_input_9() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_9(make_payload(9));
    assert(decoded_len == 9, 'input length control');
    let output = dispatcher.encode_9(make_payload(9));
    assert(output.len() == expected_output_len(9), 'encoded length');
}

#[test]
fn gas_input_10() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_10(make_payload(10));
    assert(decoded_len == 10, 'input length control');
    let output = dispatcher.encode_10(make_payload(10));
    assert(output.len() == expected_output_len(10), 'encoded length');
}

#[test]
fn gas_input_11() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_11(make_payload(11));
    assert(decoded_len == 11, 'input length control');
    let output = dispatcher.encode_11(make_payload(11));
    assert(output.len() == expected_output_len(11), 'encoded length');
}

#[test]
fn gas_input_30() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_30(make_payload(30));
    assert(decoded_len == 30, 'input length control');
    let output = dispatcher.encode_30(make_payload(30));
    assert(output.len() == expected_output_len(30), 'encoded length');
}

#[test]
fn gas_input_31() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_31(make_payload(31));
    assert(decoded_len == 31, 'input length control');
    let output = dispatcher.encode_31(make_payload(31));
    assert(output.len() == expected_output_len(31), 'encoded length');
}

#[test]
fn gas_input_32() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_32(make_payload(32));
    assert(decoded_len == 32, 'input length control');
    let output = dispatcher.encode_32(make_payload(32));
    assert(output.len() == expected_output_len(32), 'encoded length');
}

#[test]
fn gas_input_33() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_33(make_payload(33));
    assert(decoded_len == 33, 'input length control');
    let output = dispatcher.encode_33(make_payload(33));
    assert(output.len() == expected_output_len(33), 'encoded length');
}

#[test]
fn gas_input_61() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_61(make_payload(61));
    assert(decoded_len == 61, 'input length control');
    let output = dispatcher.encode_61(make_payload(61));
    assert(output.len() == expected_output_len(61), 'encoded length');
}

#[test]
fn gas_input_62() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_62(make_payload(62));
    assert(decoded_len == 62, 'input length control');
    let output = dispatcher.encode_62(make_payload(62));
    assert(output.len() == expected_output_len(62), 'encoded length');
}

#[test]
fn gas_input_63() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_63(make_payload(63));
    assert(decoded_len == 63, 'input length control');
    let output = dispatcher.encode_63(make_payload(63));
    assert(output.len() == expected_output_len(63), 'encoded length');
}

#[test]
fn gas_input_64() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_64(make_payload(64));
    assert(decoded_len == 64, 'input length control');
    let output = dispatcher.encode_64(make_payload(64));
    assert(output.len() == expected_output_len(64), 'encoded length');
}

#[test]
fn gas_input_127() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_127(make_payload(127));
    assert(decoded_len == 127, 'input length control');
    let output = dispatcher.encode_127(make_payload(127));
    assert(output.len() == expected_output_len(127), 'encoded length');
}

#[test]
fn gas_input_128() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_128(make_payload(128));
    assert(decoded_len == 128, 'input length control');
    let output = dispatcher.encode_128(make_payload(128));
    assert(output.len() == expected_output_len(128), 'encoded length');
}

#[test]
fn gas_input_129() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_129(make_payload(129));
    assert(decoded_len == 129, 'input length control');
    let output = dispatcher.encode_129(make_payload(129));
    assert(output.len() == expected_output_len(129), 'encoded length');
}

#[test]
fn gas_input_255() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_255(make_payload(255));
    assert(decoded_len == 255, 'input length control');
    let output = dispatcher.encode_255(make_payload(255));
    assert(output.len() == expected_output_len(255), 'encoded length');
}

#[test]
fn gas_input_256() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_256(make_payload(256));
    assert(decoded_len == 256, 'input length control');
    let output = dispatcher.encode_256(make_payload(256));
    assert(output.len() == expected_output_len(256), 'encoded length');
}

#[test]
fn gas_input_257() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_257(make_payload(257));
    assert(decoded_len == 257, 'input length control');
    let output = dispatcher.encode_257(make_payload(257));
    assert(output.len() == expected_output_len(257), 'encoded length');
}

#[test]
fn gas_input_511() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_511(make_payload(511));
    assert(decoded_len == 511, 'input length control');
    let output = dispatcher.encode_511(make_payload(511));
    assert(output.len() == expected_output_len(511), 'encoded length');
}

#[test]
fn gas_input_512() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_512(make_payload(512));
    assert(decoded_len == 512, 'input length control');
    let output = dispatcher.encode_512(make_payload(512));
    assert(output.len() == expected_output_len(512), 'encoded length');
}

#[test]
fn gas_input_513() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_513(make_payload(513));
    assert(decoded_len == 513, 'input length control');
    let output = dispatcher.encode_513(make_payload(513));
    assert(output.len() == expected_output_len(513), 'encoded length');
}

#[test]
fn gas_input_1023() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_1023(make_payload(1023));
    assert(decoded_len == 1023, 'input length control');
    let output = dispatcher.encode_1023(make_payload(1023));
    assert(output.len() == expected_output_len(1023), 'encoded length');
}

#[test]
fn gas_input_1024() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_1024(make_payload(1024));
    assert(decoded_len == 1024, 'input length control');
    let output = dispatcher.encode_1024(make_payload(1024));
    assert(output.len() == expected_output_len(1024), 'encoded length');
}

#[test]
fn gas_input_1025() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_1025(make_payload(1025));
    assert(decoded_len == 1025, 'input length control');
    let output = dispatcher.encode_1025(make_payload(1025));
    assert(output.len() == expected_output_len(1025), 'encoded length');
}

#[test]
fn gas_input_2048() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_2048(make_payload(2048));
    assert(decoded_len == 2048, 'input length control');
    let output = dispatcher.encode_2048(make_payload(2048));
    assert(output.len() == expected_output_len(2048), 'encoded length');
}

#[test]
fn gas_input_4095() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_4095(make_payload(4095));
    assert(decoded_len == 4095, 'input length control');
    let output = dispatcher.encode_4095(make_payload(4095));
    assert(output.len() == expected_output_len(4095), 'encoded length');
}

#[test]
fn gas_input_4096() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_4096(make_payload(4096));
    assert(decoded_len == 4096, 'input length control');
    let output = dispatcher.encode_4096(make_payload(4096));
    assert(output.len() == expected_output_len(4096), 'encoded length');
}

#[test]
fn gas_input_4097() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_4097(make_payload(4097));
    assert(decoded_len == 4097, 'input length control');
    let output = dispatcher.encode_4097(make_payload(4097));
    assert(output.len() == expected_output_len(4097), 'encoded length');
}

#[test]
fn gas_input_8191() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_8191(make_payload(8191));
    assert(decoded_len == 8191, 'input length control');
    let output = dispatcher.encode_8191(make_payload(8191));
    assert(output.len() == expected_output_len(8191), 'encoded length');
}

#[test]
fn gas_input_8192() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_8192(make_payload(8192));
    assert(decoded_len == 8192, 'input length control');
    let output = dispatcher.encode_8192(make_payload(8192));
    assert(output.len() == expected_output_len(8192), 'encoded length');
}

#[test]
fn gas_input_8193() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_8193(make_payload(8193));
    assert(decoded_len == 8193, 'input length control');
    let output = dispatcher.encode_8193(make_payload(8193));
    assert(output.len() == expected_output_len(8193), 'encoded length');
}

#[test]
fn gas_input_16384() {
    let dispatcher = setup();
    let decoded_len = dispatcher.input_len_16384(make_payload(16384));
    assert(decoded_len == 16384, 'input length control');
    let output = dispatcher.encode_16384(make_payload(16384));
    assert(output.len() == expected_output_len(16384), 'encoded length');
}
