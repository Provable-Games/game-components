use game_components_interfaces::registration::Registration;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

#[starknet::interface]
trait IRegistrationMock<TContractState> {
    // From IRegistration (component embedded)
    fn get_registration(
        self: @TContractState, game_address: ContractAddress, token_id: u64,
    ) -> Registration;
    fn is_registration_banned(
        self: @TContractState, game_address: ContractAddress, token_id: u64,
    ) -> bool;
    fn get_context_id_for_token(
        self: @TContractState, game_address: ContractAddress, token_id: u64,
    ) -> u64;
    fn get_entry_count(self: @TContractState, context_id: u64) -> u32;
    fn registration_exists(
        self: @TContractState, game_address: ContractAddress, token_id: u64,
    ) -> bool;
    // From mock externals
    fn set_registration(ref self: TContractState, registration: Registration);
    fn increment_entry_count(ref self: TContractState, context_id: u64) -> u32;
    fn mark_score_submitted(ref self: TContractState, game_address: ContractAddress, token_id: u64);
    fn ban_registration(ref self: TContractState, game_address: ContractAddress, token_id: u64);
    fn assert_valid_for_submission(
        self: @TContractState, registration: Registration, context_id: u64,
    );
}

fn deploy_mock() -> IRegistrationMockDispatcher {
    let contract_class = declare("RegistrationMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IRegistrationMockDispatcher { contract_address }
}

fn make_address(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

fn make_registration(
    game_address: ContractAddress,
    token_id: u64,
    context_id: u64,
    entry_number: u32,
    has_submitted: bool,
    is_banned: bool,
) -> Registration {
    Registration {
        game_address, game_token_id: token_id, context_id, entry_number, has_submitted, is_banned,
    }
}

// ============================================================================
// set_registration / get_registration roundtrip
// ============================================================================

#[test]
fn test_set_and_get_registration() {
    let mock = deploy_mock();
    let game_addr = make_address(0x1234);
    let token_id: u64 = 10;

    let reg = make_registration(game_addr, token_id, 42, 1, false, false);
    mock.set_registration(reg);

    let retrieved = mock.get_registration(game_addr, token_id);
    assert!(retrieved.game_address == game_addr, "game_address mismatch");
    assert!(retrieved.game_token_id == token_id, "game_token_id mismatch");
    assert!(retrieved.context_id == 42, "context_id mismatch");
    assert!(retrieved.entry_number == 1, "entry_number mismatch");
    assert!(!retrieved.has_submitted, "has_submitted should be false");
    assert!(!retrieved.is_banned, "is_banned should be false");
}

// ============================================================================
// registration_exists
// ============================================================================

#[test]
fn test_registration_exists_false_by_default() {
    let mock = deploy_mock();
    let game_addr = make_address(0xABCD);
    let exists = mock.registration_exists(game_addr, 99);
    assert!(!exists, "registration should not exist by default");
}

#[test]
fn test_registration_exists_true_after_set() {
    let mock = deploy_mock();
    let game_addr = make_address(0x1234);
    let token_id: u64 = 5;

    // Set registration with entry_number > 0
    let reg = make_registration(game_addr, token_id, 1, 1, false, false);
    mock.set_registration(reg);

    let exists = mock.registration_exists(game_addr, token_id);
    assert!(exists, "registration should exist after set with entry_number > 0");
}

#[test]
fn test_registration_exists_false_with_zero_entry_number() {
    let mock = deploy_mock();
    let game_addr = make_address(0x1234);
    let token_id: u64 = 5;

    // Set registration with entry_number == 0 (existence check uses entry_number != 0)
    let reg = make_registration(game_addr, token_id, 1, 0, false, false);
    mock.set_registration(reg);

    let exists = mock.registration_exists(game_addr, token_id);
    assert!(!exists, "registration with entry_number=0 should not be considered existing");
}

// ============================================================================
// get_context_id_for_token
// ============================================================================

#[test]
fn test_get_context_id_for_token() {
    let mock = deploy_mock();
    let game_addr = make_address(0x5678);
    let token_id: u64 = 20;
    let context_id: u64 = 777;

    let reg = make_registration(game_addr, token_id, context_id, 1, false, false);
    mock.set_registration(reg);

    let result = mock.get_context_id_for_token(game_addr, token_id);
    assert!(result == context_id, "context_id mismatch");
}

#[test]
fn test_get_context_id_for_token_default_zero() {
    let mock = deploy_mock();
    let game_addr = make_address(0x9999);
    let result = mock.get_context_id_for_token(game_addr, 1);
    assert!(result == 0, "default context_id should be 0");
}

// ============================================================================
// is_registration_banned
// ============================================================================

#[test]
fn test_is_registration_banned_default_false() {
    let mock = deploy_mock();
    let game_addr = make_address(0xAAAA);
    let banned = mock.is_registration_banned(game_addr, 1);
    assert!(!banned, "default is_banned should be false");
}

#[test]
fn test_ban_registration() {
    let mock = deploy_mock();
    let game_addr = make_address(0xBBBB);
    let token_id: u64 = 15;

    // Set registration first
    let reg = make_registration(game_addr, token_id, 10, 1, false, false);
    mock.set_registration(reg);

    assert!(!mock.is_registration_banned(game_addr, token_id), "should not be banned initially");

    // Ban the registration
    mock.ban_registration(game_addr, token_id);

    assert!(mock.is_registration_banned(game_addr, token_id), "should be banned after ban call");

    // Verify other fields are preserved
    let retrieved = mock.get_registration(game_addr, token_id);
    assert!(retrieved.context_id == 10, "context_id should be preserved after ban");
    assert!(retrieved.entry_number == 1, "entry_number should be preserved after ban");
    assert!(!retrieved.has_submitted, "has_submitted should be preserved after ban");
}

// ============================================================================
// mark_score_submitted
// ============================================================================

#[test]
fn test_mark_score_submitted() {
    let mock = deploy_mock();
    let game_addr = make_address(0xCCCC);
    let token_id: u64 = 25;

    // Set registration
    let reg = make_registration(game_addr, token_id, 20, 2, false, false);
    mock.set_registration(reg);

    let before = mock.get_registration(game_addr, token_id);
    assert!(!before.has_submitted, "should not be submitted initially");

    // Mark as submitted
    mock.mark_score_submitted(game_addr, token_id);

    let after = mock.get_registration(game_addr, token_id);
    assert!(after.has_submitted, "should be submitted after mark");

    // Verify other fields are preserved
    assert!(after.context_id == 20, "context_id should be preserved");
    assert!(after.entry_number == 2, "entry_number should be preserved");
    assert!(!after.is_banned, "is_banned should be preserved");
}

// ============================================================================
// increment_entry_count
// ============================================================================

#[test]
fn test_increment_entry_count() {
    let mock = deploy_mock();
    let context_id: u64 = 42;

    // Initial count should be 0
    assert!(mock.get_entry_count(context_id) == 0, "initial count should be 0");

    // Increment 3 times
    let count1 = mock.increment_entry_count(context_id);
    assert!(count1 == 1, "first increment should return 1");

    let count2 = mock.increment_entry_count(context_id);
    assert!(count2 == 2, "second increment should return 2");

    let count3 = mock.increment_entry_count(context_id);
    assert!(count3 == 3, "third increment should return 3");

    // Verify via getter
    assert!(mock.get_entry_count(context_id) == 3, "get_entry_count should return 3");
}

#[test]
fn test_increment_entry_count_independent_contexts() {
    let mock = deploy_mock();

    mock.increment_entry_count(1);
    mock.increment_entry_count(1);
    mock.increment_entry_count(2);

    assert!(mock.get_entry_count(1) == 2, "context 1 should have 2");
    assert!(mock.get_entry_count(2) == 1, "context 2 should have 1");
    assert!(mock.get_entry_count(3) == 0, "context 3 should have 0");
}

// ============================================================================
// assert_valid_for_submission
// ============================================================================

#[test]
fn test_assert_valid_for_submission_succeeds() {
    let mock = deploy_mock();
    let game_addr = make_address(0xDDDD);
    let context_id: u64 = 50;

    let reg = make_registration(game_addr, 1, context_id, 1, false, false);

    // Should not panic - valid registration for this context
    mock.assert_valid_for_submission(reg, context_id);
}

#[test]
#[should_panic(expected: "Registration: Token not registered for context")]
fn test_assert_valid_wrong_context() {
    let mock = deploy_mock();
    let game_addr = make_address(0xEEEE);

    // Registration is for context 10, but we assert for context 99
    let reg = make_registration(game_addr, 1, 10, 1, false, false);
    mock.assert_valid_for_submission(reg, 99);
}

#[test]
#[should_panic(expected: "Registration: Score already submitted")]
fn test_assert_valid_already_submitted() {
    let mock = deploy_mock();
    let game_addr = make_address(0x1111);
    let context_id: u64 = 30;

    let reg = make_registration(game_addr, 1, context_id, 1, true, false);
    mock.assert_valid_for_submission(reg, context_id);
}

#[test]
#[should_panic(expected: "Registration: Game ID is banned")]
fn test_assert_valid_banned() {
    let mock = deploy_mock();
    let game_addr = make_address(0x2222);
    let context_id: u64 = 40;

    let reg = make_registration(game_addr, 1, context_id, 1, false, true);
    mock.assert_valid_for_submission(reg, context_id);
}

// ============================================================================
// Multiple registrations (different keys)
// ============================================================================

#[test]
fn test_multiple_registrations_different_tokens() {
    let mock = deploy_mock();
    let game_addr = make_address(0x3333);

    let reg1 = make_registration(game_addr, 1, 100, 1, false, false);
    let reg2 = make_registration(game_addr, 2, 200, 2, true, false);

    mock.set_registration(reg1);
    mock.set_registration(reg2);

    let r1 = mock.get_registration(game_addr, 1);
    assert!(r1.context_id == 100, "token 1 context_id mismatch");
    assert!(r1.entry_number == 1, "token 1 entry_number mismatch");
    assert!(!r1.has_submitted, "token 1 should not be submitted");

    let r2 = mock.get_registration(game_addr, 2);
    assert!(r2.context_id == 200, "token 2 context_id mismatch");
    assert!(r2.entry_number == 2, "token 2 entry_number mismatch");
    assert!(r2.has_submitted, "token 2 should be submitted");
}

#[test]
fn test_multiple_registrations_different_games() {
    let mock = deploy_mock();
    let game1 = make_address(0x4444);
    let game2 = make_address(0x5555);
    let token_id: u64 = 1;

    let reg1 = make_registration(game1, token_id, 10, 1, false, false);
    let reg2 = make_registration(game2, token_id, 20, 2, false, true);

    mock.set_registration(reg1);
    mock.set_registration(reg2);

    let r1 = mock.get_registration(game1, token_id);
    assert!(r1.context_id == 10, "game1 context_id mismatch");
    assert!(!r1.is_banned, "game1 should not be banned");

    let r2 = mock.get_registration(game2, token_id);
    assert!(r2.context_id == 20, "game2 context_id mismatch");
    assert!(r2.is_banned, "game2 should be banned");
}

// ============================================================================
// Overwrite registration
// ============================================================================

#[test]
fn test_overwrite_registration() {
    let mock = deploy_mock();
    let game_addr = make_address(0x6666);
    let token_id: u64 = 7;

    // Set initial registration
    let reg1 = make_registration(game_addr, token_id, 10, 1, false, false);
    mock.set_registration(reg1);

    // Overwrite with new data
    let reg2 = make_registration(game_addr, token_id, 20, 5, true, true);
    mock.set_registration(reg2);

    let retrieved = mock.get_registration(game_addr, token_id);
    assert!(retrieved.context_id == 20, "context_id should be overwritten");
    assert!(retrieved.entry_number == 5, "entry_number should be overwritten");
    assert!(retrieved.has_submitted, "has_submitted should be overwritten");
    assert!(retrieved.is_banned, "is_banned should be overwritten");
}

// ============================================================================
// Edge case: ban then mark submitted (both flags set)
// ============================================================================

#[test]
fn test_ban_then_mark_submitted() {
    let mock = deploy_mock();
    let game_addr = make_address(0x7777);
    let token_id: u64 = 3;

    let reg = make_registration(game_addr, token_id, 50, 1, false, false);
    mock.set_registration(reg);

    mock.ban_registration(game_addr, token_id);
    mock.mark_score_submitted(game_addr, token_id);

    let retrieved = mock.get_registration(game_addr, token_id);
    assert!(retrieved.is_banned, "should be banned");
    assert!(retrieved.has_submitted, "should be submitted");
    assert!(retrieved.context_id == 50, "context_id should be preserved");
    assert!(retrieved.entry_number == 1, "entry_number should be preserved");
}

// ============================================================================
// Edge case: assert_valid checks priority (context mismatch checked first)
// ============================================================================

#[test]
#[should_panic(expected: "Registration: Token not registered for context")]
fn test_assert_valid_wrong_context_even_if_submitted_and_banned() {
    let mock = deploy_mock();
    let game_addr = make_address(0x8888);

    // All flags set + wrong context -- context mismatch is the first assert
    let reg = make_registration(game_addr, 1, 10, 1, true, true);
    mock.assert_valid_for_submission(reg, 99);
}

#[test]
#[should_panic(expected: "Registration: Score already submitted")]
fn test_assert_valid_submitted_checked_before_banned() {
    let mock = deploy_mock();
    let game_addr = make_address(0x9ABC);
    let context_id: u64 = 10;

    // Correct context, but submitted + banned. Submitted is checked before banned.
    let reg = make_registration(game_addr, 1, context_id, 1, true, true);
    mock.assert_valid_for_submission(reg, context_id);
}
