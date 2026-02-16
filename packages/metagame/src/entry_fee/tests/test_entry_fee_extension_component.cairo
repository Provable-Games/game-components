use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};

fn make_address(value: felt252) -> starknet::ContractAddress {
    value.try_into().unwrap()
}

#[starknet::interface]
trait IEntryFeeExtensionMock<TContractState> {
    fn owner_address(self: @TContractState) -> starknet::ContractAddress;
    fn set_entry_fee_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
    fn pay_entry_fee(ref self: TContractState, context_id: u64, pay_params: Span<felt252>);
    fn claim_entry_fee(ref self: TContractState, context_id: u64, claim_params: Span<felt252>);
    // SRC5
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}

fn deploy_entry_fee_extension_mock(
    owner: starknet::ContractAddress,
) -> IEntryFeeExtensionMockDispatcher {
    let contract_class = declare("EntryFeeExtensionMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class
        .deploy(@array![owner.into()])
        .expect('deploy failed');
    IEntryFeeExtensionMockDispatcher { contract_address }
}

// ============================================================================
// Initializer tests
// ============================================================================

#[test]
fn test_initializer_sets_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    assert!(mock.owner_address() == owner, "owner_address mismatch");
}

// ============================================================================
// SRC5 interface registration tests
// ============================================================================

#[test]
fn test_supports_entry_fee_extension_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let ientry_fee_extension_id: felt252 =
        0x03b4fbddbe815d9d8839a14cde7e0b500d2ed7e6fa0a0b1f324d477e12819327;
    assert!(
        mock.supports_interface(ientry_fee_extension_id) == true,
        "should support IEntryFeeExtension interface",
    );
}

#[test]
fn test_does_not_support_random_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    assert!(mock.supports_interface(0x12345678) == false, "should not support random interface");
}

// ============================================================================
// Owner-only function tests
// ============================================================================

#[test]
fn test_set_entry_fee_config_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.set_entry_fee_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_set_entry_fee_config_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.set_entry_fee_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_pay_entry_fee_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.pay_entry_fee(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_pay_entry_fee_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.pay_entry_fee(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_claim_entry_fee_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.claim_entry_fee(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_claim_entry_fee_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.claim_entry_fee(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}
