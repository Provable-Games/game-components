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
    fn calculate_fee(
        self: @TContractState,
        context_id: u64,
        base_amount: u128,
        player: starknet::ContractAddress,
        config: Span<felt252>,
    ) -> u128;
    fn validate_deposit(
        self: @TContractState,
        context_id: u64,
        player: starknet::ContractAddress,
        amount: u128,
        config: Span<felt252>,
    ) -> bool;
    fn on_deposit(
        ref self: TContractState,
        context_id: u64,
        token_address: starknet::ContractAddress,
        amount: u128,
        player: starknet::ContractAddress,
        config: Span<felt252>,
    );
    fn on_claim(
        ref self: TContractState,
        context_id: u64,
        claim_type: Span<felt252>,
        claimer: starknet::ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );
    fn on_refund(
        ref self: TContractState,
        context_id: u64,
        recipient: starknet::ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );
    fn add_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
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
// Delegation tests (trait methods called via component)
// ============================================================================

#[test]
fn test_calculate_fee_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let player = make_address(0x1234);
    let config: Array<felt252> = array![];
    // Our mock returns base_amount unchanged
    assert!(
        mock.calculate_fee(1, 1000, player, config.span()) == 1000,
        "calculate_fee should return base_amount",
    );
}

#[test]
fn test_validate_deposit_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let player = make_address(0x1234);
    let config: Array<felt252> = array![];
    // Our mock always returns true
    assert!(
        mock.validate_deposit(1, player, 1000, config.span()) == true,
        "validate_deposit should return true",
    );
}

// ============================================================================
// Owner-only function tests
// ============================================================================

#[test]
fn test_on_deposit_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let player = make_address(0x1234);
    let token = make_address(0xAAAA);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![];
    mock.on_deposit(1, token, 1000, player, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_on_deposit_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let player = make_address(0x1234);
    let token = make_address(0xAAAA);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.on_deposit(1, token, 1000, player, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_on_claim_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let claimer = make_address(0x1234);

    start_cheat_caller_address(mock.contract_address, owner);
    let claim_type: Array<felt252> = array![1];
    let config: Array<felt252> = array![];
    mock.on_claim(1, claim_type.span(), claimer, 500, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_on_claim_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let claimer = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let claim_type: Array<felt252> = array![1];
    let config: Array<felt252> = array![];
    mock.on_claim(1, claim_type.span(), claimer, 500, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_on_refund_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let recipient = make_address(0x1234);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![];
    mock.on_refund(1, recipient, 500, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_on_refund_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);
    let recipient = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.on_refund(1, recipient, 500, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_add_config_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.add_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Entry Fee Extension: Only owner can call")]
fn test_add_config_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_fee_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.add_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}
