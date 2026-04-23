/// Tests for packed-storage custom distribution shares on EntryFeeComponent.
///
/// Validates that `store_distribution_shares` / `get_distribution_shares`
/// round-trip arrays correctly, including across slot boundaries (>15 shares).
/// Callers pass the share count to `get_distribution_shares`; there is no
/// separate count storage — in production the count is sourced from the
/// sibling `PackedDistribution.positions`.

use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[starknet::interface]
trait IEntryFeeDistShares<TContractState> {
    fn store_distribution_shares(ref self: TContractState, context_id: u64, shares: Span<u16>);
    fn get_distribution_shares(self: @TContractState, context_id: u64, count: u32) -> Array<u16>;
}

fn deploy_mock() -> IEntryFeeDistSharesDispatcher {
    let contract_class = declare("EntryFeeMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IEntryFeeDistSharesDispatcher { contract_address }
}

#[test]
fn test_distribution_shares_empty_by_default() {
    let mock = deploy_mock();
    let shares = mock.get_distribution_shares(42, 0);
    assert!(shares.len() == 0, "Default shares should be empty");
}

#[test]
fn test_distribution_shares_single_slot_roundtrip() {
    let mock = deploy_mock();

    let input = array![6000_u16, 3000_u16, 1000_u16];
    mock.store_distribution_shares(1, input.span());

    let out = mock.get_distribution_shares(1, 3);
    assert!(out.len() == 3, "Length");
    assert!(*out.at(0) == 6000, "Share 0");
    assert!(*out.at(1) == 3000, "Share 1");
    assert!(*out.at(2) == 1000, "Share 2");
}

#[test]
fn test_distribution_shares_full_slot_roundtrip() {
    let mock = deploy_mock();

    // Exactly 15 shares = 1 slot
    let input = array![
        1_u16, 2_u16, 3_u16, 4_u16, 5_u16, 6_u16, 7_u16, 8_u16, 9_u16, 10_u16, 11_u16, 12_u16,
        13_u16, 14_u16, 15_u16,
    ];
    mock.store_distribution_shares(2, input.span());

    let out = mock.get_distribution_shares(2, 15);
    assert!(out.len() == 15, "Length");
    let mut i: u32 = 0;
    while i < 15 {
        let expected: u16 = (i + 1).try_into().unwrap();
        assert!(*out.at(i) == expected, "Share mismatch");
        i += 1;
    }
}

#[test]
fn test_distribution_shares_multi_slot_roundtrip() {
    let mock = deploy_mock();

    // 50 shares = ceil(50/15) = 4 slots
    let mut input: Array<u16> = ArrayTrait::new();
    let mut i: u16 = 0;
    while i < 50 {
        input.append(100 + i);
        i += 1;
    }
    mock.store_distribution_shares(3, input.span());

    let out = mock.get_distribution_shares(3, 50);
    assert!(out.len() == 50, "Length");
    let mut j: u32 = 0;
    while j < 50 {
        let expected: u16 = (100 + j).try_into().unwrap();
        assert!(*out.at(j) == expected, "Share mismatch");
        j += 1;
    }
}

#[test]
fn test_distribution_shares_isolated_per_context() {
    let mock = deploy_mock();

    mock.store_distribution_shares(10, array![5000_u16, 3000_u16, 2000_u16].span());
    mock.store_distribution_shares(11, array![7000_u16, 3000_u16].span());

    let a = mock.get_distribution_shares(10, 3);
    let b = mock.get_distribution_shares(11, 2);

    assert!(a.len() == 3, "Context 10 length");
    assert!(*a.at(0) == 5000 && *a.at(1) == 3000 && *a.at(2) == 2000, "Context 10 values");

    assert!(b.len() == 2, "Context 11 length");
    assert!(*b.at(0) == 7000 && *b.at(1) == 3000, "Context 11 values");
}
