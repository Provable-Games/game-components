// Test file for token/libs/token_state.cairo
// Tests pure token state management functions

use core::num::traits::Bounded;
use crate::token_legacy::structs::{Lifecycle, TokenMetadata};
use crate::token_legacy::token::LifecycleTrait;
use crate::token_legacy::token::token_state::{
    create_game_token_metadata, create_lifecycle_with_defaults, ensure_game_over_transition,
    ensure_objectives_completion_transition, is_multi_game_token, is_single_game_token,
    is_token_playable,
};

// =============================================================================
// TEST HELPERS
// =============================================================================

fn create_test_metadata(
    game_over: bool, completed_objective: bool, lifecycle: Lifecycle,
) -> TokenMetadata {
    TokenMetadata {
        game_id: 0,
        minted_at: 0,
        settings_id: 0,
        lifecycle,
        minted_by: 0,
        soulbound: false,
        game_over,
        completed_objective,
        completed_at: 0,
        has_context: false,
        objective_id: 0,
        paymaster: false,
        metadata: 0,
    }
}

// =============================================================================
// IS_TOKEN_PLAYABLE TESTS (UT-TS-TP-*)
// =============================================================================

#[test]
fn test_is_token_playable_game_is_over() {
    // TP-001: Game is over
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_test_metadata(true, false, lifecycle);
    assert!(!is_token_playable(@metadata, 100), "Should not be playable when game is over");
}

#[test]
fn test_is_token_playable_objectives_completed() {
    // TP-002: Objectives completed
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_test_metadata(false, true, lifecycle);
    assert!(!is_token_playable(@metadata, 100), "Should not be playable when objectives completed");
}

#[test]
fn test_is_token_playable_both_game_over_and_completed() {
    // TP-003: Both game_over and completed
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_test_metadata(true, true, lifecycle);
    assert!(!is_token_playable(@metadata, 100), "Should not be playable when both flags true");
}

#[test]
fn test_is_token_playable_no_constraints() {
    // TP-004: Playable - no constraints
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(is_token_playable(@metadata, 100), "Should be playable with no constraints");
}

#[test]
fn test_is_token_playable_not_started_yet() {
    // TP-005: Not started yet
    let lifecycle = Lifecycle { start: 200, end: 300 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(!is_token_playable(@metadata, 100), "Should not be playable before start time");
}

#[test]
fn test_is_token_playable_at_start_time() {
    // TP-006: At start time
    let lifecycle = Lifecycle { start: 100, end: 300 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(is_token_playable(@metadata, 100), "Should be playable at start time");
}

#[test]
fn test_is_token_playable_in_valid_range() {
    // TP-007: In valid range
    let lifecycle = Lifecycle { start: 100, end: 300 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(is_token_playable(@metadata, 200), "Should be playable within range");
}

#[test]
fn test_is_token_playable_at_end_time() {
    // TP-008: At end time (expired)
    let lifecycle = Lifecycle { start: 100, end: 200 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(!is_token_playable(@metadata, 200), "Should not be playable at end time");
}

#[test]
fn test_is_token_playable_after_end_time() {
    // TP-009: After end time
    let lifecycle = Lifecycle { start: 100, end: 200 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(!is_token_playable(@metadata, 300), "Should not be playable after end time");
}

#[test]
fn test_is_token_playable_only_start_constraint() {
    // TP-010: Only start constraint
    let lifecycle = Lifecycle { start: 100, end: 0 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(is_token_playable(@metadata, 200), "Should be playable after start with no end");
}

#[test]
fn test_is_token_playable_only_end_constraint() {
    // TP-011: Only end constraint
    let lifecycle = Lifecycle { start: 0, end: 200 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(is_token_playable(@metadata, 100), "Should be playable before end with no start");
}

#[test]
fn test_is_token_playable_at_max_u64() {
    // TP-012: Time at u64::MAX
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_test_metadata(false, false, lifecycle);
    assert!(
        is_token_playable(@metadata, Bounded::<u64>::MAX),
        "Should be playable at u64::MAX with no constraints",
    );
}

// =============================================================================
// ENSURE_GAME_OVER_TRANSITION TESTS (UT-TS-GO-*)
// =============================================================================

#[test]
fn test_game_over_transition_false_to_false() {
    // GO-001: Initial false, stay false
    let result = ensure_game_over_transition(false, false);
    assert!(!result, "Should stay false when both are false");
}

#[test]
fn test_game_over_transition_false_to_true() {
    // GO-002: Initial false, transition to true
    let result = ensure_game_over_transition(false, true);
    assert!(result, "Should transition to true");
}

#[test]
fn test_game_over_transition_true_to_true() {
    // GO-003: Already true, stay true
    let result = ensure_game_over_transition(true, true);
    assert!(result, "Should stay true");
}

#[test]
fn test_game_over_transition_true_to_false_blocked() {
    // GO-004: Already true, attempt revert (blocked)
    let result = ensure_game_over_transition(true, false);
    assert!(result, "Should block transition back to false");
}

// =============================================================================
// ENSURE_OBJECTIVES_COMPLETION_TRANSITION TESTS (UT-TS-OC-*)
// =============================================================================

#[test]
fn test_objectives_completion_transition_false_to_false() {
    // OC-001: Initial false, stay false
    let result = ensure_objectives_completion_transition(false, false);
    assert!(!result, "Should stay false when both are false");
}

#[test]
fn test_objectives_completion_transition_false_to_true() {
    // OC-002: Initial false, transition to true
    let result = ensure_objectives_completion_transition(false, true);
    assert!(result, "Should transition to true");
}

#[test]
fn test_objectives_completion_transition_true_to_true() {
    // OC-003: Already true, stay true
    let result = ensure_objectives_completion_transition(true, true);
    assert!(result, "Should stay true");
}

#[test]
fn test_objectives_completion_transition_true_to_false_blocked() {
    // OC-004: Already true, attempt revert (blocked)
    let result = ensure_objectives_completion_transition(true, false);
    assert!(result, "Should block transition back to false");
}

// =============================================================================
// CREATE_GAME_TOKEN_METADATA TESTS (UT-TS-GT-*)
// =============================================================================

#[test]
fn test_create_game_token_single_game() {
    // GT-001: Single game token (game_id=0)
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_game_token_metadata(0, 1, lifecycle, 1, false, false, 0, 1000);

    assert!(metadata.game_id == 0, "game_id should be 0");
    assert!(metadata.settings_id == 1, "settings_id should match");
    assert!(!metadata.game_over, "game_over should be false");
    assert!(!metadata.completed_objective, "completed_objective should be false");
}

#[test]
fn test_create_game_token_multi_game() {
    // GT-002: Multi-game token
    let lifecycle = Lifecycle { start: 100, end: 500 };
    let metadata = create_game_token_metadata(5, 10, lifecycle, 42, true, true, 3, 100);

    assert!(metadata.game_id == 5, "game_id should match");
    assert!(metadata.settings_id == 10, "settings_id should match");
    assert!(metadata.has_context, "has_context should be true");
    assert!(metadata.objective_id == 3, "objective_id should match");
    assert!(metadata.soulbound, "soulbound should be true");
    assert!(metadata.lifecycle.start == 100, "lifecycle start should match");
    assert!(metadata.lifecycle.end == 500, "lifecycle end should match");
}

#[test]
fn test_create_game_token_max_values() {
    // GT-003: Maximum values
    let max_u64 = Bounded::<u64>::MAX;
    let max_u32 = Bounded::<u32>::MAX;
    let lifecycle = Lifecycle { start: max_u64, end: max_u64 };
    let metadata = create_game_token_metadata(
        max_u64, max_u32, lifecycle, max_u64, true, true, max_u32, max_u64,
    );

    assert!(metadata.game_id == max_u64, "game_id should handle max value");
    assert!(metadata.settings_id == max_u32, "settings_id should handle max value");
    assert!(metadata.minted_by == max_u64, "minted_by should handle max value");
    assert!(metadata.objective_id == max_u32, "objective_id should handle max value");
    assert!(metadata.minted_at == max_u64, "minted_at should handle max value");
}

#[test]
fn test_create_game_token_zero_values() {
    // GT-004: Zero values
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_game_token_metadata(0, 0, lifecycle, 0, false, false, 0, 0);

    assert!(metadata.game_id == 0, "game_id should be 0");
    assert!(metadata.settings_id == 0, "settings_id should be 0");
    assert!(metadata.minted_by == 0, "minted_by should be 0");
    assert!(metadata.objective_id == 0, "objective_id should be 0");
    assert!(metadata.minted_at == 0, "minted_at should be 0");
    assert!(!metadata.soulbound, "soulbound should be false");
    assert!(!metadata.has_context, "has_context should be false");
}

// =============================================================================
// CREATE_LIFECYCLE_WITH_DEFAULTS TESTS (UT-TS-LC-*)
// =============================================================================

#[test]
fn test_create_lifecycle_both_none() {
    // LC-001: Both None
    let lifecycle = create_lifecycle_with_defaults(Option::None, Option::None);
    assert!(lifecycle.start == 0, "start should default to 0");
    assert!(lifecycle.end == 0, "end should default to 0");
}

#[test]
fn test_create_lifecycle_only_start_provided() {
    // LC-002: Only start provided
    let lifecycle = create_lifecycle_with_defaults(Option::Some(100), Option::None);
    assert!(lifecycle.start == 100, "start should be 100");
    assert!(lifecycle.end == 0, "end should default to 0");
}

#[test]
fn test_create_lifecycle_only_end_provided() {
    // LC-003: Only end provided
    let lifecycle = create_lifecycle_with_defaults(Option::None, Option::Some(200));
    assert!(lifecycle.start == 0, "start should default to 0");
    assert!(lifecycle.end == 200, "end should be 200");
}

#[test]
fn test_create_lifecycle_both_provided() {
    // LC-004: Both provided
    let lifecycle = create_lifecycle_with_defaults(Option::Some(100), Option::Some(200));
    assert!(lifecycle.start == 100, "start should be 100");
    assert!(lifecycle.end == 200, "end should be 200");
}

// =============================================================================
// IS_MULTI_GAME_TOKEN TESTS (UT-TS-MG-*)
// =============================================================================

#[test]
fn test_is_multi_game_token_zero() {
    // MG-001: Single game (game_id=0)
    assert!(!is_multi_game_token(0), "game_id 0 should not be multi-game");
}

#[test]
fn test_is_multi_game_token_one() {
    // MG-002: Multi game (game_id=1)
    assert!(is_multi_game_token(1), "game_id 1 should be multi-game");
}

#[test]
fn test_is_multi_game_token_max() {
    // MG-003: Multi game (max value)
    assert!(is_multi_game_token(Bounded::<u64>::MAX), "max game_id should be multi-game");
}

// =============================================================================
// IS_SINGLE_GAME_TOKEN TESTS (UT-TS-SG-*)
// =============================================================================

#[test]
fn test_is_single_game_token_zero() {
    // SG-001: Single game (game_id=0)
    assert!(is_single_game_token(0), "game_id 0 should be single-game");
}

#[test]
fn test_is_single_game_token_one() {
    // SG-002: Multi game (game_id=1)
    assert!(!is_single_game_token(1), "game_id 1 should not be single-game");
}

#[test]
fn test_is_single_game_token_max() {
    // SG-003: Multi game (max value)
    assert!(!is_single_game_token(Bounded::<u64>::MAX), "max game_id should not be single-game");
}

// =============================================================================
// FUZZ TESTS
// =============================================================================

#[test]
#[fuzzer]
fn test_fuzz_is_token_playable(game_over: bool, completed_objective: bool, start: u64, end: u64) {
    // Skip invalid lifecycles
    if end != 0 && start > end {
        return;
    }

    let lifecycle = Lifecycle { start, end };
    let metadata = create_test_metadata(game_over, completed_objective, lifecycle);

    // Test at a time in the middle (or use start+1 if no end)
    let current_time = if end == 0 && start == 0 {
        100
    } else if end == 0 {
        start + 1
    } else {
        start
    };

    let result = is_token_playable(@metadata, current_time);

    if game_over {
        assert!(!result, "Should not be playable when game is over");
    } else if completed_objective {
        assert!(!result, "Should not be playable when objectives completed");
    } else {
        assert!(
            result == lifecycle.is_playable(current_time), "Should match lifecycle playability",
        );
    }
}

#[test]
#[fuzzer]
fn test_fuzz_game_over_transition(old_state: bool, new_state: bool) {
    let result = ensure_game_over_transition(old_state, new_state);

    if old_state {
        assert!(result, "Once true, must stay true");
    } else {
        assert!(result == new_state, "When false, should accept new state");
    }
}

#[test]
#[fuzzer]
fn test_fuzz_objectives_completion_transition(old_state: bool, new_state: bool) {
    let result = ensure_objectives_completion_transition(old_state, new_state);

    if old_state {
        assert!(result, "Once true, must stay true");
    } else {
        assert!(result == new_state, "When false, should accept new state");
    }
}

#[test]
#[fuzzer]
fn test_fuzz_game_type_inverse(game_id: u64) {
    let is_multi = is_multi_game_token(game_id);
    let is_single = is_single_game_token(game_id);

    // Must be exactly one or the other
    assert!(is_multi != is_single, "Must be either multi or single, not both/neither");
    assert!(is_multi == (game_id != 0), "Multi-game should be game_id != 0");
    assert!(is_single == (game_id == 0), "Single-game should be game_id == 0");
}

#[test]
#[fuzzer]
fn test_fuzz_create_game_token(
    game_id: u64,
    settings_id: u32,
    minted_by: u64,
    soulbound: bool,
    has_context: bool,
    objective_id: u32,
    current_time: u64,
) {
    let lifecycle = Lifecycle { start: 0, end: 0 };
    let metadata = create_game_token_metadata(
        game_id,
        settings_id,
        lifecycle,
        minted_by,
        soulbound,
        has_context,
        objective_id,
        current_time,
    );

    // Verify game token invariants
    assert!(!metadata.game_over, "New game token must not be game_over");
    assert!(!metadata.completed_objective, "New game token must not have completed_objective");
    assert!(metadata.game_id == game_id, "game_id must match input");
    assert!(metadata.settings_id == settings_id, "settings_id must match input");
    assert!(metadata.minted_at == current_time, "minted_at must match current_time");
    assert!(metadata.minted_by == minted_by, "minted_by must match input");
    assert!(metadata.soulbound == soulbound, "soulbound must match input");
    assert!(metadata.has_context == has_context, "has_context must match input");
    assert!(metadata.objective_id == objective_id, "objective_id must match input");
}
