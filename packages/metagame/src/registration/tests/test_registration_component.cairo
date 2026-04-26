use game_components_interfaces::registration::Registration;
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};

#[starknet::interface]
trait IRegistrationMock<TContractState> {
    // From IRegistration (component embedded)
    fn get_entry(self: @TContractState, context_id: u64, entry_id: u32) -> Registration;
    fn entry_exists(self: @TContractState, context_id: u64, entry_id: u32) -> bool;
    fn is_token_banned(self: @TContractState, token_id: felt252) -> bool;
    fn get_entry_count(self: @TContractState, context_id: u64) -> u32;
    // From mock externals (exposing internal trait for tests)
    fn set_entry(ref self: TContractState, registration: Registration);
    fn increment_entry_count(ref self: TContractState, context_id: u64) -> u32;
    fn mark_token_submitted(ref self: TContractState, token_id: felt252);
    fn ban_token(ref self: TContractState, token_id: felt252);
    fn assert_valid_for_submission(
        self: @TContractState, registration: Registration, context_id: u64,
    );
    fn get_token_context(self: @TContractState, token_id: felt252) -> u64;
    fn is_token_submitted(self: @TContractState, token_id: felt252) -> bool;
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
// is_token_banned
// ============================================================================

#[test]
fn test_is_token_banned_default_false() {
    let mock = deploy_mock();
    let banned = mock.is_token_banned(0xDEAD);
    assert!(!banned, "default is_banned should be false");
}

#[test]
fn test_ban_token() {
    let mock = deploy_mock();
    let context_id: u64 = 10;
    let entry_id: u32 = 1;
    let token_id: felt252 = 0xBBBB;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    assert!(!mock.is_token_banned(token_id), "should not be banned initially");

    mock.ban_token(token_id);

    assert!(mock.is_token_banned(token_id), "should be banned after ban call");

    // Verify other fields are preserved (round-trip via get_entry)
    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.game_token_id == token_id, "game_token_id should be preserved after ban");
    assert!(!retrieved.has_submitted, "has_submitted should be preserved after ban");
    assert!(retrieved.is_banned, "is_banned should reflect through get_entry");
}

// ============================================================================
// mark_token_submitted
// ============================================================================

#[test]
fn test_mark_token_submitted() {
    let mock = deploy_mock();
    let context_id: u64 = 20;
    let entry_id: u32 = 2;
    let token_id: felt252 = 0xCCCC;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    assert!(!mock.is_token_submitted(token_id), "should not be submitted initially");

    mock.mark_token_submitted(token_id);

    assert!(mock.is_token_submitted(token_id), "should be submitted after mark");

    // Verify other fields are preserved (round-trip via get_entry)
    let after = mock.get_entry(context_id, entry_id);
    assert!(after.has_submitted, "has_submitted should reflect through get_entry");
    assert!(after.game_token_id == token_id, "game_token_id should be preserved");
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

    // New token resolves to the slot via the reverse index.
    assert!(mock.get_token_context(0x8888) == context_id, "new token context");
    // Previous token's reverse mapping must be cleared so it no longer claims the slot.
    assert!(mock.get_token_context(0x7777) == 0, "old token context should be cleared");
}

// ============================================================================
// Edge case: ban then mark submitted (both flags set)
// ============================================================================

#[test]
fn test_ban_then_mark_submitted() {
    let mock = deploy_mock();
    let context_id: u64 = 50;
    let entry_id: u32 = 1;
    let token_id: felt252 = 0x9999;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    mock.ban_token(token_id);
    mock.mark_token_submitted(token_id);

    let retrieved = mock.get_entry(context_id, entry_id);
    assert!(retrieved.is_banned, "should be banned");
    assert!(retrieved.has_submitted, "should be submitted");
    assert!(retrieved.game_token_id == token_id, "game_token_id should be preserved");
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
// Reverse lookup: token_id -> context_id
// ============================================================================

#[test]
fn test_token_reverse_lookup_default_zero() {
    let mock = deploy_mock();
    assert!(mock.get_token_context(0xDEAD) == 0, "default token_context should be 0");
}

#[test]
fn test_token_reverse_lookup_after_set_entry() {
    let mock = deploy_mock();
    let context_id: u64 = 7;
    let entry_id: u32 = 3;
    let token_id: felt252 = 0xCAFE;

    let reg = make_registration(context_id, entry_id, token_id, false, false);
    mock.set_entry(reg);

    assert!(mock.get_token_context(token_id) == context_id, "token_context mismatch");
}

#[test]
fn test_token_reverse_lookup_independent_tokens() {
    let mock = deploy_mock();

    let reg_a = make_registration(1, 1, 0xAAA, false, false);
    let reg_b = make_registration(2, 5, 0xBBB, false, false);
    mock.set_entry(reg_a);
    mock.set_entry(reg_b);

    assert!(mock.get_token_context(0xAAA) == 1, "token A context");
    assert!(mock.get_token_context(0xBBB) == 2, "token B context");
}

// ============================================================================
// Token-keyed flag isolation: flags are scoped to token, not context+entry
// ============================================================================

#[test]
fn test_token_flags_are_independent_per_token() {
    // Two different tokens at the same (context, entry_id) coords across two
    // distinct contexts should not bleed flags into each other.
    let mock = deploy_mock();

    let reg_a = make_registration(1, 1, 0xA, false, false);
    let reg_b = make_registration(2, 1, 0xB, false, false);
    mock.set_entry(reg_a);
    mock.set_entry(reg_b);

    mock.mark_token_submitted(0xA);
    mock.ban_token(0xB);

    assert!(mock.is_token_submitted(0xA), "A submitted");
    assert!(!mock.is_token_banned(0xA), "A not banned");
    assert!(!mock.is_token_submitted(0xB), "B not submitted");
    assert!(mock.is_token_banned(0xB), "B banned");
}
