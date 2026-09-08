//! Ignored, isolated entrypoint measurements. See scripts/bench_enumerable.py.
use snforge_std::start_cheat_caller_address;
use super::enumerable_fixtures::{
    IEnumerationFixtureDispatcher, IEnumerationFixtureDispatcherTrait, IEnumerationProbeDispatcher,
    IEnumerationProbeDispatcherTrait,
};
use super::test_enumerable::{addr, deploy};

fn measure(name: ByteArray, operation: u32) {
    let address = deploy(name);
    let fixture = IEnumerationFixtureDispatcher { contract_address: address };
    let probe = IEnumerationProbeDispatcher { contract_address: deploy("EnumerationGasProbe") };
    let base: u256 = 0x100000000000000000000000000000001;
    if operation != 0 {
        for offset in 0_u32..3 {
            fixture.mint(addr(201), base + offset.into());
        }
    }
    start_cheat_caller_address(address, addr(201));
    let mut calldata = array![];
    let entrypoint = if operation < 2 {
        addr(201).serialize(ref calldata);
        (base + 3).serialize(ref calldata);
        selector!("mint")
    } else if operation < 5 {
        addr(201).serialize(ref calldata);
        (if operation == 4 {
            addr(201)
        } else {
            addr(202)
        }).serialize(ref calldata);
        (base + if operation == 2 {
            2
        } else {
            1
        }).serialize(ref calldata);
        selector!("transfer_from")
    } else {
        (base + if operation == 5 {
            2
        } else {
            1
        }).serialize(ref calldata);
        selector!("burn")
    };
    probe.floor(address, entrypoint, calldata.span());
    probe.measure(address, entrypoint, calldata.span());
    let expected: Span<u256> = if operation == 0 {
        array![base + 3].span()
    } else if operation == 1 {
        array![base, base + 1, base + 2, base + 3].span()
    } else if operation == 2 || operation == 5 {
        array![base, base + 1].span()
    } else if operation == 4 {
        array![base, base + 1, base + 2].span()
    } else {
        array![base, base + 2].span()
    };
    assert!(fixture.all_tokens(addr(201)) == expected, "Enumeration mismatch");
}

#[test]
#[ignore]
fn enumgas_reference_mint_first() {
    measure("EnumerableReferenceMock", 0);
}

#[test]
#[ignore]
fn enumgas_reference_mint_repeat() {
    measure("EnumerableReferenceMock", 1);
}

#[test]
#[ignore]
fn enumgas_reference_transfer_last() {
    measure("EnumerableReferenceMock", 2);
}

#[test]
#[ignore]
fn enumgas_reference_transfer_middle() {
    measure("EnumerableReferenceMock", 3);
}

#[test]
#[ignore]
fn enumgas_reference_transfer_self() {
    measure("EnumerableReferenceMock", 4);
}

#[test]
#[ignore]
fn enumgas_optimized_mint_first() {
    measure("EnumerableOwnerMock", 0);
}

#[test]
#[ignore]
fn enumgas_optimized_mint_repeat() {
    measure("EnumerableOwnerMock", 1);
}

#[test]
#[ignore]
fn enumgas_optimized_transfer_last() {
    measure("EnumerableOwnerMock", 2);
}

#[test]
#[ignore]
fn enumgas_optimized_transfer_middle() {
    measure("EnumerableOwnerMock", 3);
}

#[test]
#[ignore]
fn enumgas_optimized_transfer_self() {
    measure("EnumerableOwnerMock", 4);
}

#[test]
#[ignore]
fn enumgas_optimized_burn_last() {
    measure("EnumerableOwnerMock", 5);
}

#[test]
#[ignore]
fn enumgas_optimized_burn_middle() {
    measure("EnumerableOwnerMock", 6);
}

#[test]
#[ignore]
fn enumgas_generic_mint_first() {
    measure("EnumerableGenericMock", 0);
}

#[test]
#[ignore]
fn enumgas_generic_mint_repeat() {
    measure("EnumerableGenericMock", 1);
}

#[test]
#[ignore]
fn enumgas_generic_transfer_last() {
    measure("EnumerableGenericMock", 2);
}

#[test]
#[ignore]
fn enumgas_generic_transfer_middle() {
    measure("EnumerableGenericMock", 3);
}

#[test]
#[ignore]
fn enumgas_generic_transfer_self() {
    measure("EnumerableGenericMock", 4);
}

#[test]
#[ignore]
fn enumgas_generic_burn_last() {
    measure("EnumerableGenericMock", 5);
}

#[test]
#[ignore]
fn enumgas_generic_burn_middle() {
    measure("EnumerableGenericMock", 6);
}
