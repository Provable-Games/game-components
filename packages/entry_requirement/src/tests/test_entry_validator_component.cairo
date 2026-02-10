use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};

fn make_address(value: felt252) -> starknet::ContractAddress {
    value.try_into().unwrap()
}

#[starknet::interface]
trait IEntryValidatorMock<TContractState> {
    fn owner_address(self: @TContractState) -> starknet::ContractAddress;
    fn registration_only(self: @TContractState) -> bool;
    fn valid_entry(
        self: @TContractState,
        context_id: u64,
        player_address: starknet::ContractAddress,
        qualification: Span<felt252>,
    ) -> bool;
    fn should_ban(
        self: @TContractState,
        context_id: u64,
        game_token_id: u64,
        current_owner: starknet::ContractAddress,
        qualification: Span<felt252>,
    ) -> bool;
    fn entries_left(
        self: @TContractState,
        context_id: u64,
        player_address: starknet::ContractAddress,
        qualification: Span<felt252>,
    ) -> Option<u8>;
    fn add_config(
        ref self: TContractState, context_id: u64, entry_limit: u8, config: Span<felt252>,
    );
    fn add_entry(
        ref self: TContractState,
        context_id: u64,
        game_token_id: u64,
        player_address: starknet::ContractAddress,
        qualification: Span<felt252>,
    );
    fn remove_entry(
        ref self: TContractState,
        context_id: u64,
        game_token_id: u64,
        player_address: starknet::ContractAddress,
        qualification: Span<felt252>,
    );
    // SRC5
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}

fn deploy_entry_validator_mock(
    owner: starknet::ContractAddress, registration_only: bool,
) -> IEntryValidatorMockDispatcher {
    let contract_class = declare("EntryValidatorMock").expect('declare failed').contract_class();
    let reg_felt: felt252 = if registration_only {
        1
    } else {
        0
    };
    let (contract_address, _) = contract_class
        .deploy(@array![owner.into(), reg_felt])
        .expect('deploy failed');
    IEntryValidatorMockDispatcher { contract_address }
}

// ============================================================================
// Initializer tests
// ============================================================================

#[test]
fn test_initializer_sets_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    assert!(mock.owner_address() == owner, "owner_address mismatch");
}

#[test]
fn test_initializer_sets_registration_only_true() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    assert!(mock.registration_only() == true, "registration_only should be true");
}

#[test]
fn test_initializer_sets_registration_only_false() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, false);
    assert!(mock.registration_only() == false, "registration_only should be false");
}

// ============================================================================
// SRC5 interface registration tests
// ============================================================================

#[test]
fn test_supports_entry_validator_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let ientry_validator_id: felt252 =
        0x01158754d5cc62137c4de2cbd0e65cbd163990af29f0182006f26fe0cac00bb6;
    assert!(
        mock.supports_interface(ientry_validator_id) == true,
        "should support IEntryValidator interface",
    );
}

#[test]
fn test_does_not_support_random_interface() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    assert!(mock.supports_interface(0x12345678) == false, "should not support random interface");
}

// ============================================================================
// Delegation tests (trait methods called via component)
// ============================================================================

#[test]
fn test_valid_entry_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);
    let qualification: Array<felt252> = array![1, 2, 3];
    // Our mock always returns true
    assert!(
        mock.valid_entry(1, player, qualification.span()) == true, "valid_entry should return true",
    );
}

#[test]
fn test_should_ban_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let current_owner = make_address(0x1234);
    let qualification: Array<felt252> = array![];
    // Our mock always returns false
    assert!(
        mock.should_ban(1, 100, current_owner, qualification.span()) == false,
        "should_ban should return false",
    );
}

#[test]
fn test_entries_left_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);
    let qualification: Array<felt252> = array![];
    // Our mock returns None (unlimited)
    let result = mock.entries_left(1, player, qualification.span());
    assert!(result.is_none(), "entries_left should return None");
}

// ============================================================================
// Owner-only function tests
// ============================================================================

#[test]
fn test_add_config_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.add_config(1, 5, config.span());
    stop_cheat_caller_address(mock.contract_address);
    // No panic means success
}

#[test]
#[should_panic(expected: "Entry Validator: Only owner can call")]
fn test_add_config_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.add_config(1, 5, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_add_entry_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);

    start_cheat_caller_address(mock.contract_address, owner);
    let qualification: Array<felt252> = array![];
    mock.add_entry(1, 100, player, qualification.span());
    stop_cheat_caller_address(mock.contract_address);
    // No panic means success
}

#[test]
#[should_panic(expected: "Entry Validator: Only owner can call")]
fn test_add_entry_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let qualification: Array<felt252> = array![];
    mock.add_entry(1, 100, player, qualification.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_remove_entry_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);

    start_cheat_caller_address(mock.contract_address, owner);
    let qualification: Array<felt252> = array![];
    mock.remove_entry(1, 100, player, qualification.span());
    stop_cheat_caller_address(mock.contract_address);
    // No panic means success
}

#[test]
#[should_panic(expected: "Entry Validator: Only owner can call")]
fn test_remove_entry_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_entry_validator_mock(owner, true);
    let player = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let qualification: Array<felt252> = array![];
    mock.remove_entry(1, 100, player, qualification.span());
    stop_cheat_caller_address(mock.contract_address);
}
