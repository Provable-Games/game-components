use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};

fn make_address(value: felt252) -> starknet::ContractAddress {
    value.try_into().unwrap()
}

#[starknet::interface]
trait IPrizeExtensionMock<TContractState> {
    fn owner_address(self: @TContractState) -> starknet::ContractAddress;
    fn add_prize(ref self: TContractState, context_id: u64, prize_id: u64, config: Span<felt252>);
    fn claim_prize(ref self: TContractState, context_id: u64, claim_params: Span<felt252>);
    // SRC5
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}

fn deploy_prize_extension_mock(owner: starknet::ContractAddress) -> IPrizeExtensionMockDispatcher {
    let contract_class = declare("PrizeExtensionMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![owner.into()])
        .expect('deploy failed');
    IPrizeExtensionMockDispatcher { contract_address }
}

// ============================================================================
// Initializer tests
// ============================================================================

#[test]
fn test_initializer_sets_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    assert!(mock.owner_address() == owner, "owner_address mismatch");
}

// ============================================================================
// SRC5 interface registration tests
// ============================================================================

#[test]
fn test_supports_prize_extension_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let iprize_extension_id: felt252 =
        0x008dad9d5fe3760c1acdf89c280a08b4979bf656f595f75bc26f39cf12732ee4;
    assert!(
        mock.supports_interface(iprize_extension_id) == true,
        "should support IPrizeExtension interface",
    );
}

#[test]
fn test_does_not_support_random_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    assert!(mock.supports_interface(0x12345678) == false, "should not support random interface");
}

// ============================================================================
// Owner-only function tests
// ============================================================================

#[test]
fn test_add_prize_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.add_prize(1, 1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_add_prize_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.add_prize(1, 1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_claim_prize_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.claim_prize(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_claim_prize_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.claim_prize(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}
