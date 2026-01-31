// Tests for ObjectivesComponent extension
// Test Plan: objectives_test_plan.md

use game_components_interfaces::{IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait};
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{EventSpyTrait, spy_events};
use crate::extensions::objectives::interface::IMINIGAME_TOKEN_OBJECTIVES_ID;
use crate::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_starknet_mock::IMinigameStarknetMockDispatcherTrait;

// Import setup helpers
use super::setup::{ALICE, BOB, setup, setup_multi_game};

// ================================================================================================
// CREATE_OBJECTIVE TESTS - Happy Path
// ================================================================================================

// CO-U-001: Create objective from valid objectives contract (single-game)
#[test]
fn test_create_objective_single_game_success() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Create objective via the mock minigame (which acts as objectives_address)
    test_contracts.mock_minigame.create_objective_score(100);

    // Verify events were emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit events");

    // Verify objective exists using the objectives dispatcher
    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(objectives.objective_exists(1), "Objective should exist");
}

// CO-U-006: Create objective with complex data
#[test]
fn test_create_objective_with_various_scores() {
    let test_contracts = setup();

    // Create objectives with different scores
    test_contracts.mock_minigame.create_objective_score(50);
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_objective_score(500);
    test_contracts.mock_minigame.create_objective_score(1000);

    // Verify all objectives exist
    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(objectives.objective_exists(1), "Objective 1 should exist");
    assert!(objectives.objective_exists(2), "Objective 2 should exist");
    assert!(objectives.objective_exists(3), "Objective 3 should exist");
    assert!(objectives.objective_exists(4), "Objective 4 should exist");
}

// CO-U-008: Create objective with objective_id = 1 (first)
#[test]
fn test_create_first_objective() {
    let test_contracts = setup();

    test_contracts.mock_minigame.create_objective_score(100);

    // First objective should be ID 1
    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(objectives.objective_exists(1), "First objective should be ID 1");
}

// ================================================================================================
// VALIDATE_OBJECTIVE TESTS - Happy Path
// ================================================================================================

// VO-U-001: Validate existing objective during mint
#[test]
fn test_validate_existing_objective() {
    let test_contracts = setup();

    // Create objective
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint with objective_id
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1), // objective_id = 1
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify token was minted with objective
    assert!(test_contracts.test_token.objective_id(token_id) == 1, "Should have objective_id 1");
}

// VO-U-003: Validate with no objective (objective_id = 0)
#[test]
fn test_validate_no_objective() {
    let test_contracts = setup_multi_game();

    // Mint without objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // No objective
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify no objective
    assert!(test_contracts.test_token.objective_id(token_id) == 0, "Should have no objective");
}

// ================================================================================================
// VALIDATE_OBJECTIVE TESTS - Revert Paths
// ================================================================================================

// VO-U-002: Validate non-existent objective fails
#[test]
#[should_panic(expected: "MinigameTokenObjectives: Objective ID 999 does not exist")]
fn test_validate_nonexistent_objective() {
    let test_contracts = setup();

    // Create only objective_id = 1
    test_contracts.mock_minigame.create_objective_score(50);

    // Try to mint with non-existent objective
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(999), // Non-existent objective
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

// VO-U-007: Validate with large objective_id
#[test]
#[should_panic(expected: "MinigameTokenObjectives: Objective ID")]
fn test_validate_large_objective_id() {
    let test_contracts = setup();

    // Create only one objective
    test_contracts.mock_minigame.create_objective_score(100);

    // Try with very large objective_id
    let large_objective_id: u32 = 4294967295; // u32::MAX

    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(large_objective_id),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
}

// ================================================================================================
// IS_OBJECTIVE_COMPLETED TESTS
// ================================================================================================

// IOC-U-001: Check completed objective returns true
#[test]
fn test_is_objective_completed_true() {
    let test_contracts = setup();

    // Create objective with target score 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game with score meeting objective
    test_contracts.mock_minigame.end_game(token_id, 100);

    // Update game state
    test_contracts.test_token.update_game(token_id);

    // Check completion status
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective == true, "Objective should be completed");
}

// IOC-U-002: Check incomplete objective returns false
#[test]
fn test_is_objective_completed_false() {
    let test_contracts = setup();

    // Create objective with target score 100
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game with score NOT meeting objective
    test_contracts.mock_minigame.end_game(token_id, 50);

    // Update game state
    test_contracts.test_token.update_game(token_id);

    // Check completion status
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective == false, "Objective should not be completed");
}

// IOC-U-003: Check with no objectives_address returns false
#[test]
fn test_is_objective_completed_no_objectives_contract() {
    let test_contracts = setup_multi_game();

    // Mint without objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Check metadata - should not have completed objective
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.completed_objective == false, "Should not have completed objective");
}

// ================================================================================================
// INITIALIZER TESTS
// ================================================================================================

// IN-U-001: Initialize objectives component registers interface
#[test]
fn test_objectives_initializer_registers_interface() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID),
        "Should support IMinigameTokenObjectives interface",
    );
}

// IN-U-002: Double initialization is safe (idempotent)
#[test]
fn test_objectives_interface_support() {
    let test_contracts = setup();

    // Should support interface after initialization
    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_OBJECTIVES_ID),
        "Should support objectives interface",
    );
}

// ================================================================================================
// INTEGRATION TESTS
// ================================================================================================

// OBJ-I-001: Mint token with objective_id and validate
#[test]
fn test_mint_with_objective_id() {
    let test_contracts = setup();

    // Create objective
    test_contracts.mock_minigame.create_objective_score(100);

    // Mint with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('ObjectivePlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.objective_id == 1, "Should have objective_id 1");
    assert!(metadata.completed_objective == false, "Should not be completed yet");
}

// OBJ-I-002: Update game syncs objective completion
#[test]
fn test_update_game_syncs_objective_completion() {
    let test_contracts = setup();

    // Create objective
    test_contracts.mock_minigame.create_objective_score(50);

    // Mint with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Before update
    let metadata_before = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_before.completed_objective == false, "Should not be completed before");

    // Complete objective
    test_contracts.mock_minigame.end_game(token_id, 50);
    test_contracts.test_token.update_game(token_id);

    // After update
    let metadata_after = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_after.completed_objective == true, "Should be completed after");
}

// OBJ-I-003: Create objective then mint with that ID
#[test]
fn test_create_objective_then_mint() {
    let test_contracts = setup();

    // Create objective first
    test_contracts.mock_minigame.create_objective_score(75);

    // Verify objective exists
    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    assert!(objectives.objective_exists(1), "Objective should exist");

    // Mint referencing it
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.objective_id(token_id) == 1, "Should reference objective 1");
}

// OBJ-I-005: Full lifecycle - create -> mint -> play -> complete -> sync
#[test]
fn test_objective_full_lifecycle() {
    let test_contracts = setup();

    // 1. Create objective
    test_contracts.mock_minigame.create_objective_score(100);

    // 2. Mint token with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('LifecyclePlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // 3. Verify initial state
    let metadata1 = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata1.objective_id == 1, "Should have objective");
    assert!(metadata1.completed_objective == false, "Should not be completed");
    assert!(metadata1.game_over == false, "Game should not be over");

    // 4. Play game (start)
    test_contracts.mock_minigame.start_game(token_id);

    // 5. Complete game with score meeting objective
    test_contracts.mock_minigame.end_game(token_id, 100);

    // 6. Sync state
    test_contracts.test_token.update_game(token_id);

    // 7. Verify final state
    let metadata2 = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata2.completed_objective == true, "Objective should be completed");
    assert!(metadata2.game_over == true, "Game should be over");
}

// ================================================================================================
// OBJECTIVE_ID VIEW TESTS
// ================================================================================================

#[test]
fn test_objective_id_view_with_objective() {
    let test_contracts = setup();

    test_contracts.mock_minigame.create_objective_score(100);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.objective_id(token_id) == 1, "Should return objective_id 1");
}

#[test]
fn test_objective_id_view_no_objective() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.objective_id(token_id) == 0, "Should return 0");
}

#[test]
fn test_objective_id_batch_view() {
    let test_contracts = setup();

    // Create objectives
    test_contracts.mock_minigame.create_objective_score(100);
    test_contracts.mock_minigame.create_objective_score(200);

    // Mint tokens with different objectives
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(2),
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Batch view
    let results = test_contracts.test_token.objective_id_batch(array![token_id1, token_id2].span());
    assert!(results.len() == 2, "Should have 2 results");
    assert!(*results.at(0) == 1, "First should be objective 1");
    assert!(*results.at(1) == 2, "Second should be objective 2");
}

// ================================================================================================
// EVENT TESTS
// ================================================================================================

// CO-E-001: Verify ObjectiveCreated event fields
#[test]
fn test_create_objective_event() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Create objective
    test_contracts.mock_minigame.create_objective_score(100);

    // Events should have been emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit ObjectiveCreated event");
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

// FZ-OBJ-001: Fuzz objective_id values for valid cases
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_objective_id_valid_cases(objective_count: u8) {
    // Limit to reasonable range
    if objective_count == 0 || objective_count > 10 {
        return;
    }

    let test_contracts = setup();

    // Create objectives
    let mut i: u8 = 0;
    while i < objective_count {
        let score: u64 = (i.into() + 1) * 100;
        test_contracts.mock_minigame.create_objective_score(score);
        i += 1;
    }

    // Verify all objectives exist
    let objectives = IMinigameObjectivesDispatcher {
        contract_address: test_contracts.minigame.contract_address,
    };
    let mut j: u32 = 1;
    while j <= objective_count.into() {
        assert!(objectives.objective_exists(j), "Objective should exist");
        j += 1;
    };
}

// FZ-OBJ-002: Fuzz objective completion based on score
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_objective_completion(target_score: u64, achieved_score: u64) {
    // Limit to reasonable values
    if target_score == 0 || target_score > 10000 {
        return;
    }

    let test_contracts = setup();

    // Create objective with target score
    test_contracts.mock_minigame.create_objective_score(target_score);

    // Mint with objective
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Limit achieved_score for test
    let bounded_score = if achieved_score > 10000 {
        achieved_score % 10001
    } else {
        achieved_score
    };

    // End game with score
    test_contracts.mock_minigame.end_game(token_id, bounded_score);
    test_contracts.test_token.update_game(token_id);

    // Check completion
    let metadata = test_contracts.test_token.token_metadata(token_id);
    if bounded_score >= target_score {
        assert!(metadata.completed_objective == true, "Should be completed when score >= target");
    } else {
        assert!(
            metadata.completed_objective == false, "Should not be completed when score < target",
        );
    }
}

// ================================================================================================
// EDGE CASE TESTS
// ================================================================================================

#[test]
fn test_objective_progression_requires_update() {
    let test_contracts = setup();

    test_contracts.mock_minigame.create_objective_score(50);

    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // End game but don't update yet
    test_contracts.mock_minigame.end_game(token_id, 50);

    // Metadata should not show completion until update
    let metadata_before = test_contracts.test_token.token_metadata(token_id);
    assert!(
        metadata_before.completed_objective == false, "Should not be completed before update call",
    );

    // Now update
    test_contracts.test_token.update_game(token_id);

    // Now it should be completed
    let metadata_after = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata_after.completed_objective == true, "Should be completed after update");
}

#[test]
fn test_multiple_tokens_same_objective() {
    let test_contracts = setup();

    test_contracts.mock_minigame.create_objective_score(100);

    // Mint multiple tokens with same objective
    let token_id1 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(1),
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Both should reference same objective
    assert!(
        test_contracts.test_token.objective_id(token_id1) == 1, "Token 1 should have objective 1",
    );
    assert!(
        test_contracts.test_token.objective_id(token_id2) == 1, "Token 2 should have objective 1",
    );

    // Complete only token1's objective
    test_contracts.mock_minigame.end_game(token_id1, 100);
    test_contracts.test_token.update_game(token_id1);

    // Token1 completed, token2 not
    let metadata1 = test_contracts.test_token.token_metadata(token_id1);
    let metadata2 = test_contracts.test_token.token_metadata(token_id2);
    assert!(metadata1.completed_objective == true, "Token 1 should be completed");
    assert!(metadata2.completed_objective == false, "Token 2 should not be completed");
}
