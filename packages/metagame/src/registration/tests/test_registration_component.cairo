use game_components_interfaces::registration::Registration;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[starknet::interface]
trait IRegistrationMock<TContractState> {
    // From IRegistration (component embedded)
    fn get_entry(self: @TContractState, context_id: u64, entry_id: u32) -> Registration;
    fn entry_exists(self: @TContractState, context_id: u64, entry_id: u32) -> bool;
    fn is_entry_banned(self: @TContractState, context_id: u64, entry_id: u32) -> bool;
    fn get_entry_count(self: @TContractState, context_id: u64) -> u32;
    fn get_token_context(self: @TContractState, token_id: felt252) -> u64;
    fn get_entry_id_for_token(self: @TContractState, token_id: felt252) -> u32;
    fn get_entry_by_token(self: @TContractState, token_id: felt252) -> Registration;
    // From mock externals
    fn set_entry(ref self: TContractState, registration: Registration);
    fn increment_entry_count(ref self: TContractState, context_id: u64) -> u32;
    fn mark_entry_submitted(ref self: TContractState, context_id: u64, entry_id: u32);
    fn ban_entry(ref self: TContractState, context_id: u64, entry_id: u32);
    fn assert_valid_for_submission(
        self: @TContractState, registration: Registration, context_id: u64,
    );
}

fn deploy_mock() -> IRegistrationMockDispatcher {
    let contract_class = declare("RegistrationMock").expect('declare failed').contract_class();
    let (contract_address, _) = contract_class.deploy(@array![]).expect('deploy failed');
    IRegistrationMockDispatcher { contract_address }
}

fn make_registration(
    context_id: u64, entry_id: u32, game_token_id: felt252, has_submitted: bool, is_banned: bool,
) -> Registration {
    Registration { context_id, entry_id, game_token_id, has_submitted, is_banned }
}

// ============================================================================
// set_entry / get_entry roundtrip
// ============================================================================

#[test]
fn test_set_and_get_entry() {
    let mock = deploy_mock();
    let context_id: u64 = 42;
    let entry_id: u32 = 1;

    let reg = make_registration(context_id, entry_id, 0x1234, false, false);
    mock.set_entry(reg);

    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.context_id == context_id, "context_id mismatch");
    assert!(retrieved.entry_id == entry_id, "entry_id mismatch");
    assert!(retrieved.game_token_id == 0x1234, "game_token_id mismatch");
    assert!(!retrieved.has_submitted, "has_submitted should be false");
    assert!(!retrieved.is_banned, "is_banned should be false");
}

// ============================================================================
// entry_exists
// ============================================================================

#[test]
fn test_entry_exists_false_by_default() {
    let mock = deploy_mock();
    let exists = mock.entry_exists(1, 1);
    assert!(!exists, "entry should not exist by default");
}

#[test]
fn test_entry_exists_true_after_set() {
    let mock = deploy_mock();

    let reg = make_registration(1, 1, 0xABC, false, false);
    mock.set_entry(reg);

    let exists = mock.entry_exists(1, 1);
    assert!(exists, "entry should exist after set with non-zero game_token_id");
}

#[test]
#[should_panic(expected: 'Invalid token id')]
fn test_set_entry_zero_token_id_panics() {
    let mock = deploy_mock();

    // game_token_id == 0 is invalid, should panic
    let reg = make_registration(1, 1, 0, false, false);
    mock.set_entry(reg);
}

// ============================================================================
// is_entry_banned
// ============================================================================

#[test]
fn test_is_entry_banned_default_false() {
    let mock = deploy_mock();
    let banned = mock.is_entry_banned(1, 1);
    assert!(!banned, "default is_banned should be false");
}

#[test]
fn test_ban_entry() {
    let mock = deploy_mock();
    let context_id: u64 = 10;
    let entry_id: u32 = 1;

    let reg = make_registration(context_id, entry_id, 0xBBBB, false, false);
    mock.set_entry(reg);

    assert!(!mock.is_entry_banned(context_id, entry_id), "should not be banned initially");

    mock.ban_entry(context_id, entry_id);

    assert!(mock.is_entry_banned(context_id, entry_id), "should be banned after ban call");

    // Verify other fields are preserved
    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.game_token_id == 0xBBBB, "game_token_id should be preserved after ban");
    assert!(!retrieved.has_submitted, "has_submitted should be preserved after ban");
}

// ============================================================================
// mark_entry_submitted
// ============================================================================

#[test]
fn test_mark_entry_submitted() {
    let mock = deploy_mock();
    let context_id: u64 = 20;
    let entry_id: u32 = 2;

    let reg = make_registration(context_id, entry_id, 0xCCCC, false, false);
    mock.set_entry(reg);

    let before = mock.get_entry(context_id, entry_id);
    assert!(!before.has_submitted, "should not be submitted initially");

    mock.mark_entry_submitted(context_id, entry_id);

    let after = mock.get_entry(context_id, entry_id);
    assert!(after.has_submitted, "should be submitted after mark");

    // Verify other fields are preserved
    assert!(after.game_token_id == 0xCCCC, "game_token_id should be preserved");
    assert!(!after.is_banned, "is_banned should be preserved");
}

// ============================================================================
// increment_entry_count
// ============================================================================

#[test]
fn test_increment_entry_count() {
    let mock = deploy_mock();
    let context_id: u64 = 42;

    assert!(mock.get_entry_count(context_id) == 0, "initial count should be 0");

    let count1 = mock.increment_entry_count(context_id);
    assert!(count1 == 1, "first increment should return 1");

    let count2 = mock.increment_entry_count(context_id);
    assert!(count2 == 2, "second increment should return 2");

    let count3 = mock.increment_entry_count(context_id);
    assert!(count3 == 3, "third increment should return 3");

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
    let context_id: u64 = 50;

    let reg = make_registration(context_id, 1, 0xDDDD, false, false);

    // Should not panic - valid registration for this context
    mock.assert_valid_for_submission(reg, context_id);
}

#[test]
#[should_panic(expected: "Registration: Token not registered for context")]
fn test_assert_valid_wrong_context() {
    let mock = deploy_mock();

    // Registration is for context 10, but we assert for context 99
    let reg = make_registration(10, 1, 0xEEEE, false, false);
    mock.assert_valid_for_submission(reg, 99);
}

#[test]
#[should_panic(expected: "Registration: Score already submitted")]
fn test_assert_valid_already_submitted() {
    let mock = deploy_mock();
    let context_id: u64 = 30;

    let reg = make_registration(context_id, 1, 0x1111, true, false);
    mock.assert_valid_for_submission(reg, context_id);
}

#[test]
#[should_panic(expected: "Registration: Game ID is banned")]
fn test_assert_valid_banned() {
    let mock = deploy_mock();
    let context_id: u64 = 40;

    let reg = make_registration(context_id, 1, 0x2222, false, true);
    mock.assert_valid_for_submission(reg, context_id);
}

// ============================================================================
// Multiple entries (same context, different entry_ids)
// ============================================================================

#[test]
fn test_multiple_entries_same_context() {
    let mock = deploy_mock();
    let context_id: u64 = 100;

    let reg1 = make_registration(context_id, 1, 0x3333, false, false);
    let reg2 = make_registration(context_id, 2, 0x4444, true, false);

    mock.set_entry(reg1);
    mock.set_entry(reg2);

    let r1 = mock.get_entry(context_id, 1);
    assert!(r1.game_token_id == 0x3333, "entry 1 token_id mismatch");
    assert!(!r1.has_submitted, "entry 1 should not be submitted");

    let r2 = mock.get_entry(context_id, 2);
    assert!(r2.game_token_id == 0x4444, "entry 2 token_id mismatch");
    assert!(r2.has_submitted, "entry 2 should be submitted");
}

#[test]
fn test_multiple_entries_different_contexts() {
    let mock = deploy_mock();

    let reg1 = make_registration(10, 1, 0x5555, false, false);
    let reg2 = make_registration(20, 1, 0x6666, false, true);

    mock.set_entry(reg1);
    mock.set_entry(reg2);

    let r1 = mock.get_entry(10, 1);
    assert!(r1.game_token_id == 0x5555, "context 10 token_id mismatch");
    assert!(!r1.is_banned, "context 10 should not be banned");

    let r2 = mock.get_entry(20, 1);
    assert!(r2.game_token_id == 0x6666, "context 20 token_id mismatch");
    assert!(r2.is_banned, "context 20 should be banned");
}

// ============================================================================
// Overwrite entry
// ============================================================================

#[test]
fn test_overwrite_entry() {
    let mock = deploy_mock();
    let context_id: u64 = 10;
    let entry_id: u32 = 1;

    let reg1 = make_registration(context_id, entry_id, 0x7777, false, false);
    mock.set_entry(reg1);

    let reg2 = make_registration(context_id, entry_id, 0x8888, true, true);
    mock.set_entry(reg2);

    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.game_token_id == 0x8888, "game_token_id should be overwritten");
    assert!(retrieved.has_submitted, "has_submitted should be overwritten");
    assert!(retrieved.is_banned, "is_banned should be overwritten");
}

// ============================================================================
// Edge case: ban then mark submitted (both flags set)
// ============================================================================

#[test]
fn test_ban_then_mark_submitted() {
    let mock = deploy_mock();
    let context_id: u64 = 50;
    let entry_id: u32 = 1;

    let reg = make_registration(context_id, entry_id, 0x9999, false, false);
    mock.set_entry(reg);

    mock.ban_entry(context_id, entry_id);
    mock.mark_entry_submitted(context_id, entry_id);

    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.is_banned, "should be banned");
    assert!(retrieved.has_submitted, "should be submitted");
    assert!(retrieved.game_token_id == 0x9999, "game_token_id should be preserved");
}

// ============================================================================
// Edge case: assert_valid checks priority (context mismatch checked first)
// ============================================================================

#[test]
#[should_panic(expected: "Registration: Token not registered for context")]
fn test_assert_valid_wrong_context_even_if_submitted_and_banned() {
    let mock = deploy_mock();

    let reg = make_registration(10, 1, 0xAAAA, true, true);
    mock.assert_valid_for_submission(reg, 99);
}

#[test]
#[should_panic(expected: "Registration: Score already submitted")]
fn test_assert_valid_submitted_checked_before_banned() {
    let mock = deploy_mock();
    let context_id: u64 = 10;

    let reg = make_registration(context_id, 1, 0xBBBB, true, true);
    mock.assert_valid_for_submission(reg, context_id);
}

// ============================================================================
// Enumerate entries 1..count for a context
// ============================================================================

#[test]
fn test_enumerate_entries() {
    let mock = deploy_mock();
    let context_id: u64 = 77;

    // Simulate 3 entries being added with sequential entry_ids
    let count1 = mock.increment_entry_count(context_id);
    let reg1 = make_registration(context_id, count1, 0x100, false, false);
    mock.set_entry(reg1);

    let count2 = mock.increment_entry_count(context_id);
    let reg2 = make_registration(context_id, count2, 0x200, false, false);
    mock.set_entry(reg2);

    let count3 = mock.increment_entry_count(context_id);
    let reg3 = make_registration(context_id, count3, 0x300, false, false);
    mock.set_entry(reg3);

    // Enumerate 1..count
    let total = mock.get_entry_count(context_id);
    assert!(total == 3, "should have 3 entries");

    let mut i: u32 = 1;
    let mut token_sum: felt252 = 0;
    while i <= total {
        let entry = mock.get_entry(context_id, i);
        assert!(entry.context_id == context_id, "context should match");
        assert!(entry.entry_id == i, "entry_id should match iterator");
        assert!(mock.entry_exists(context_id, i), "entry should exist");
        token_sum += entry.game_token_id;
        i += 1;
    }

    // 0x100 + 0x200 + 0x300 = 0x600
    assert!(token_sum == 0x600, "token sum mismatch");
}

// ============================================================================
// Reverse lookups: token_id -> context_id / entry_id
// ============================================================================

#[test]
fn test_token_reverse_lookups_default_zero() {
    let mock = deploy_mock();
    assert!(mock.get_token_context(0xDEAD) == 0, "default token_context should be 0");
    assert!(mock.get_entry_id_for_token(0xDEAD) == 0, "default entry_id_for_token should be 0");
}

#[test]
fn test_token_reverse_lookups_after_set_entry() {
    let mock = deploy_mock();
    let context_id: u64 = 7;
    let entry_id: u32 = 3;
    let token_id: felt252 = 0xCAFE;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    assert!(mock.get_token_context(token_id) == context_id, "token_context mismatch");
    assert!(mock.get_entry_id_for_token(token_id) == entry_id, "entry_id_for_token mismatch");

    let by_token = mock.get_entry_by_token(token_id);
    assert!(by_token.context_id == context_id, "by_token context_id mismatch");
    assert!(by_token.entry_id == entry_id, "by_token entry_id mismatch");
    assert!(by_token.game_token_id == token_id, "by_token game_token_id mismatch");
    assert!(!by_token.has_submitted, "by_token has_submitted should be false");
    assert!(!by_token.is_banned, "by_token is_banned should be false");
}

#[test]
fn test_get_entry_by_token_reflects_flag_updates() {
    let mock = deploy_mock();
    let context_id: u64 = 9;
    let entry_id: u32 = 1;
    let token_id: felt252 = 0xBEEF;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    mock.mark_entry_submitted(context_id, entry_id);
    mock.ban_entry(context_id, entry_id);

    let by_token = mock.get_entry_by_token(token_id);
    assert!(by_token.has_submitted, "should reflect submitted flag");
    assert!(by_token.is_banned, "should reflect banned flag");
}

#[test]
fn test_token_reverse_lookups_independent_tokens() {
    let mock = deploy_mock();

    let reg_a = make_registration(1, 1, 0xAAA, false, false);
    let reg_b = make_registration(2, 5, 0xBBB, false, false);
    mock.set_entry(reg_a);
    mock.set_entry(reg_b);

    assert!(mock.get_token_context(0xAAA) == 1, "token A context");
    assert!(mock.get_entry_id_for_token(0xAAA) == 1, "token A entry_id");
    assert!(mock.get_token_context(0xBBB) == 2, "token B context");
    assert!(mock.get_entry_id_for_token(0xBBB) == 5, "token B entry_id");
}
