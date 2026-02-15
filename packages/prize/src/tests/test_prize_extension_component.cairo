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
    fn on_deposit(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        sponsor: starknet::ContractAddress,
        token_address: starknet::ContractAddress,
        amount_or_token_id: u128,
        is_erc721: bool,
        config: Span<felt252>,
    );
    fn validate_claim(
        self: @TContractState,
        context_id: u64,
        prize_id: u64,
        claimer: starknet::ContractAddress,
        position: Option<u32>,
        config: Span<felt252>,
    ) -> bool;
    fn before_payout(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        recipient: starknet::ContractAddress,
        amount: u128,
        config: Span<felt252>,
    ) -> (bool, u128);
    fn after_payout(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        recipient: starknet::ContractAddress,
        amount: u128,
        config: Span<felt252>,
    );
    fn generate_erc721_prize(
        ref self: TContractState,
        context_id: u64,
        prize_id: u64,
        recipient: starknet::ContractAddress,
        base_token_id: u128,
        config: Span<felt252>,
    ) -> u128;
    fn add_config(ref self: TContractState, context_id: u64, config: Span<felt252>);
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
// Delegation tests (trait methods called via component)
// ============================================================================

#[test]
fn test_validate_claim_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let claimer = make_address(0x1234);
    let config: Array<felt252> = array![];
    // Our mock always returns true
    assert!(
        mock.validate_claim(1, 1, claimer, Option::Some(1), config.span()) == true,
        "validate_claim should return true",
    );
}

#[test]
fn test_before_payout_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);
    let config: Array<felt252> = array![];

    start_cheat_caller_address(mock.contract_address, owner);
    let (should_proceed, adjusted_amount) = mock
        .before_payout(1, 1, recipient, 1000, config.span());
    stop_cheat_caller_address(mock.contract_address);
    // Our mock returns (true, amount)
    assert!(should_proceed == true, "should_proceed should be true");
    assert!(adjusted_amount == 1000, "adjusted_amount should be 1000");
}

#[test]
fn test_generate_erc721_prize_delegates_to_trait() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);
    let config: Array<felt252> = array![];

    start_cheat_caller_address(mock.contract_address, owner);
    let token_id = mock.generate_erc721_prize(1, 1, recipient, 42, config.span());
    stop_cheat_caller_address(mock.contract_address);
    // Our mock returns base_token_id unchanged
    assert!(token_id == 42, "token_id should be 42");
}

// ============================================================================
// Owner-only function tests
// ============================================================================

#[test]
fn test_on_deposit_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let sponsor = make_address(0x1234);
    let token = make_address(0xAAAA);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![];
    mock.on_deposit(1, 1, sponsor, token, 1000, false, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_on_deposit_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let sponsor = make_address(0x1234);
    let token = make_address(0xAAAA);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.on_deposit(1, 1, sponsor, token, 1000, false, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_after_payout_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![];
    mock.after_payout(1, 1, recipient, 1000, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_after_payout_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.after_payout(1, 1, recipient, 1000, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_before_payout_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.before_payout(1, 1, recipient, 1000, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_generate_erc721_prize_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);
    let recipient = make_address(0x1234);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.generate_erc721_prize(1, 1, recipient, 42, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
fn test_add_config_only_owner() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    start_cheat_caller_address(mock.contract_address, owner);
    let config: Array<felt252> = array![10, 20];
    mock.add_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}

#[test]
#[should_panic(expected: "Prize Extension: Only owner can call")]
fn test_add_config_non_owner_panics() {
    let owner = make_address(0xBEEF);
    let mock = deploy_prize_extension_mock(owner);

    let non_owner = make_address(0xBAD);
    start_cheat_caller_address(mock.contract_address, non_owner);
    let config: Array<felt252> = array![];
    mock.add_config(1, config.span());
    stop_cheat_caller_address(mock.contract_address);
}
