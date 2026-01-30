use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;
use crate::extensions::objectives::interface::{
    IMINIGAME_OBJECTIVES_ID, IMinigameObjectivesDetailsDispatcher,
    IMinigameObjectivesDetailsDispatcherTrait, IMinigameObjectivesDispatcher,
    IMinigameObjectivesDispatcherTrait, IMinigameObjectivesSVGDispatcher,
    IMinigameObjectivesSVGDispatcherTrait,
};
use super::mocks::mock_objectives_contract::{
    IObjectivesSetterDispatcher, IObjectivesSetterDispatcherTrait,
};

// Deploy mock objectives contract
fn deploy_mock_objectives_contract() -> ContractAddress {
    let contract = declare("MockObjectivesContract").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    contract_address
}

// Test OBJ-U-01: Initialize objectives component
#[test]
fn test_initialize_objectives_component() {
    let contract_address = deploy_mock_objectives_contract();

    // Verify SRC5 interface is registered
    let src5_dispatcher = ISRC5Dispatcher { contract_address };
    assert!(
        src5_dispatcher.supports_interface(IMINIGAME_OBJECTIVES_ID),
        "Should support IMinigameObjectives",
    );
    assert!(
        src5_dispatcher.supports_interface(openzeppelin_interfaces::introspection::ISRC5_ID),
        "Should support ISRC5",
    );
}

// Test OBJ-U-02: Check objective_exists for valid ID
#[test]
fn test_objective_exists_valid_id() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    assert!(objectives_dispatcher.objective_exists(1), "Objective 1 should exist");
    assert!(objectives_dispatcher.objective_exists(2), "Objective 2 should exist");
    assert!(objectives_dispatcher.objective_exists(3), "Objective 3 should exist");
    assert!(objectives_dispatcher.objective_exists(100), "Objective 100 should exist");
}

// Test OBJ-U-03: Check objective_exists for invalid ID
#[test]
fn test_objective_exists_invalid_id() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    assert!(!objectives_dispatcher.objective_exists(999), "Objective 999 should not exist");
    assert!(!objectives_dispatcher.objective_exists(0), "Objective 0 should not exist");
    assert!(!objectives_dispatcher.objective_exists(50), "Objective 50 should not exist");
}

// Test OBJ-U-04: Check completed_objective
#[test]
fn test_completed_objective() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Initially not completed
    assert!(!objectives_dispatcher.completed_objective(1, 1), "Should not be completed initially");

    // Complete the objective
    setter.complete_objective(1, 1);

    // Now should be completed
    assert!(objectives_dispatcher.completed_objective(1, 1), "Should be completed after marking");

    // Other objectives should still be incomplete
    assert!(
        !objectives_dispatcher.completed_objective(1, 2), "Objective 2 should not be completed",
    );
}

// Test OBJ-U-05: Get objectives details for token
#[test]
fn test_get_objectives_details_for_token() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete some objectives
    setter.complete_objective(10, 1);
    setter.complete_objective(10, 3);

    // Get objectives details
    let objectives = objectives_details_dispatcher.objectives_details(10);

    assert!(objectives.len() == 3, "Should have 3 objectives");

    // Check first objective
    let obj1 = objectives.at(0);
    let expected_name1: ByteArray = "First Blood";
    let expected_value_completed: ByteArray = "completed";
    let expected_value_pending: ByteArray = "pending";
    assert!(obj1.name == @expected_name1, "First objective name mismatch");
    assert!(obj1.value == @expected_value_completed, "First objective should be completed");

    // Check second objective
    let obj2 = objectives.at(1);
    let expected_name2: ByteArray = "Double Kill";
    assert!(obj2.name == @expected_name2, "Second objective name mismatch");
    assert!(obj2.value == @expected_value_pending, "Second objective should not be completed");

    // Check third objective
    let obj3 = objectives.at(2);
    let expected_name3: ByteArray = "Ace";
    assert!(obj3.name == @expected_name3, "Third objective name mismatch");
    assert!(obj3.value == @expected_value_completed, "Third objective should be completed");
}

// Test OBJ-U-06: Create objective with valid data
#[test]
fn test_create_objective_valid_data() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Create new objective
    setter
        .create_objective(
            1, // game_id
            200, // objective_id
            75, // points
            "Speed Run",
            "Complete level in under 60 seconds",
            false // not required
        );

    // Verify objective was created
    assert!(objectives_dispatcher.objective_exists(200), "New objective should exist");
}

// Test OBJ-U-07: Create duplicate objective ID
#[test]
#[should_panic]
fn test_create_duplicate_objective() {
    let contract_address = deploy_mock_objectives_contract();

    let setter = IObjectivesSetterDispatcher { contract_address };

    // Try to create objective with existing ID
    setter
        .create_objective(
            1, // game_id
            1, // objective_id (already exists)
            50,
            "Duplicate",
            "This should fail",
            true,
        );
}

// Test OBJ-U-08: Get/Set objective_id for token
#[test]
fn test_get_set_objective_id() {
    let contract_address = deploy_mock_objectives_contract();

    let setter = IObjectivesSetterDispatcher { contract_address };

    // Set objective_id for token 1
    setter.set_token_objective(1, 42);

    // Get and verify
    let objective_id = setter.get_objective_id(1);
    assert!(objective_id == 42, "Objective ID should be 42");

    // Set different objective for another token
    setter.set_token_objective(2, 100);
    assert!(setter.get_objective_id(2) == 100, "Token 2 should have objective_id 100");

    // Token 1's objective should be unchanged
    assert!(setter.get_objective_id(1) == 42, "Token 1 should still have objective_id 42");
}

// Test OBJ-U-09: Objectives with 0 points
#[test]
fn test_objective_with_zero_points() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Create objective with 0 points
    setter
        .create_objective(
            1, 300, 0, // 0 points
            "Participation Trophy", "Just for showing up", false,
        );

    assert!(objectives_dispatcher.objective_exists(300), "Zero-point objective should exist");
}

// Test OBJ-U-10: Objectives_svg implementation
#[test]
fn test_objectives_svg() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_svg_dispatcher = IMinigameObjectivesSVGDispatcher { contract_address };

    let svg = objectives_svg_dispatcher.objectives_svg(42);
    assert!(svg == "<svg><text>Objectives for token 42</text></svg>", "SVG content mismatch");
}

// =============================================================================
// Batch Operation Tests
// =============================================================================

// Test OBJ-U-11: objective_exists_batch with multiple IDs
#[test]
fn test_objective_exists_batch() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    let objective_ids: Array<u32> = array![1, 2, 3, 50, 100];
    let results = objectives_dispatcher.objective_exists_batch(objective_ids.span());

    assert!(results.len() == 5, "Should return 5 results");
    assert!(*results.at(0) == true, "Objective 1 should exist");
    assert!(*results.at(1) == true, "Objective 2 should exist");
    assert!(*results.at(2) == true, "Objective 3 should exist");
    assert!(*results.at(3) == false, "Objective 50 should not exist");
    assert!(*results.at(4) == true, "Objective 100 should exist");
}

// Test OBJ-U-12: objective_exists_batch with empty array
#[test]
fn test_objective_exists_batch_empty() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    let empty_ids: Array<u32> = array![];
    let results = objectives_dispatcher.objective_exists_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// Test OBJ-U-13: objective_exists_batch with single item
#[test]
fn test_objective_exists_batch_single() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    let single_id: Array<u32> = array![1];
    let results = objectives_dispatcher.objective_exists_batch(single_id.span());

    assert!(results.len() == 1, "Should return 1 result");
    assert!(*results.at(0) == true, "Objective 1 should exist");
}

// Test OBJ-U-14: objectives_details_batch with multiple IDs
#[test]
fn test_objectives_details_batch() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete some objectives for different tokens
    setter.complete_objective(1, 1);
    setter.complete_objective(2, 2);

    let token_ids: Array<felt252> = array![1, 2, 3];
    let results = objectives_details_dispatcher.objectives_details_batch(token_ids.span());

    assert!(results.len() == 3, "Should return 3 results");

    // Check each token has objectives
    let objectives1 = results.at(0);
    assert!(objectives1.len() == 3, "Token 1 should have 3 objectives");

    let objectives2 = results.at(1);
    assert!(objectives2.len() == 3, "Token 2 should have 3 objectives");
}

// Test OBJ-U-15: objectives_details_batch with empty array
#[test]
fn test_objectives_details_batch_empty() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };

    let empty_ids: Array<felt252> = array![];
    let results = objectives_details_dispatcher.objectives_details_batch(empty_ids.span());

    assert!(results.len() == 0, "Should return empty array");
}

// Test OBJ-U-16: objectives_details_batch with single item
#[test]
fn test_objectives_details_batch_single() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };

    let single_id: Array<felt252> = array![1];
    let results = objectives_details_dispatcher.objectives_details_batch(single_id.span());

    assert!(results.len() == 1, "Should return 1 result");

    let objectives = results.at(0);
    assert!(objectives.len() == 3, "Token 1 should have 3 objectives");
}

// =============================================================================
// Edge Case Tests
// =============================================================================

// Test OBJ-E-01: Create objective with long name
#[test]
fn test_create_objective_long_name() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    let long_name: ByteArray =
        "This is a very long objective name that tests the limits of ByteArray storage and handling";

    setter.create_objective(1, 500, 100, long_name, "Normal description", false);

    assert!(objectives_dispatcher.objective_exists(500), "Long name objective should exist");
}

// Test OBJ-E-02: Create objective with long description
#[test]
fn test_create_objective_long_description() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    let long_desc: ByteArray =
        "This is a very long description that contains multiple sentences. It tests the limits of ByteArray storage. The objectives system should support arbitrary length descriptions for flexibility.";

    setter.create_objective(1, 501, 50, "Normal Name", long_desc, true);

    assert!(objectives_dispatcher.objective_exists(501), "Long desc objective should exist");
}

// Test OBJ-E-03: Create objective with special characters
#[test]
fn test_create_objective_special_chars() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    setter.create_objective(1, 502, 25, "Special: !@#$%^&*()", "Tabs\tand\nnewlines", false);

    assert!(objectives_dispatcher.objective_exists(502), "Special chars objective should exist");
}

// Test OBJ-E-04: Complete multiple objectives for same token
#[test]
fn test_complete_multiple_objectives_same_token() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete multiple objectives for token 100
    setter.complete_objective(100, 1);
    setter.complete_objective(100, 2);
    setter.complete_objective(100, 3);

    assert!(objectives_dispatcher.completed_objective(100, 1), "Objective 1 should be completed");
    assert!(objectives_dispatcher.completed_objective(100, 2), "Objective 2 should be completed");
    assert!(objectives_dispatcher.completed_objective(100, 3), "Objective 3 should be completed");
}

// Test OBJ-E-05: Complete same objective for multiple tokens
#[test]
fn test_complete_same_objective_multiple_tokens() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete objective 1 for multiple tokens
    setter.complete_objective(1, 1);
    setter.complete_objective(2, 1);
    setter.complete_objective(3, 1);

    assert!(
        objectives_dispatcher.completed_objective(1, 1), "Token 1, Objective 1 should be completed",
    );
    assert!(
        objectives_dispatcher.completed_objective(2, 1), "Token 2, Objective 1 should be completed",
    );
    assert!(
        objectives_dispatcher.completed_objective(3, 1), "Token 3, Objective 1 should be completed",
    );
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test OBJ-F-01: Fuzz objective_exists with random IDs
#[test]
#[fuzzer]
fn test_objective_exists_fuzz(objective_id: u32) {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    // Should not panic for any objective_id
    let _exists = objectives_dispatcher.objective_exists(objective_id);
}

// Test OBJ-F-02: Fuzz completed_objective with random inputs
#[test]
#[fuzzer]
fn test_completed_objective_fuzz(token_id: felt252, objective_id: u32) {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    // Should not panic for any inputs
    let _completed = objectives_dispatcher.completed_objective(token_id, objective_id);
}

// Test OBJ-F-03: Fuzz objectives_svg with random token_id
#[test]
#[fuzzer]
fn test_objectives_svg_fuzz(token_id: felt252) {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_svg_dispatcher = IMinigameObjectivesSVGDispatcher { contract_address };

    // Should not panic for any token_id
    let svg = objectives_svg_dispatcher.objectives_svg(token_id);
    assert!(svg.len() > 0, "SVG should not be empty");
}

// Test OBJ-F-04: Fuzz objective_exists_batch with random single ID
#[test]
#[fuzzer]
fn test_objective_exists_batch_fuzz(objective_id: u32) {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    let ids: Array<u32> = array![objective_id];
    let results = objectives_dispatcher.objective_exists_batch(ids.span());

    assert!(results.len() == 1, "Should return 1 result");
}

// =============================================================================
// Additional Coverage Tests for Mock Contract
// =============================================================================

// Test OBJ-MOCK-01: Test objective_exists_batch loop iteration
#[test]
fn test_objective_exists_batch_iteration() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };

    // Test with many IDs to cover loop iterations
    let ids: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 100];
    let results = objectives_dispatcher.objective_exists_batch(ids.span());

    assert!(results.len() == 11, "Should return 11 results");
}

// Test OBJ-MOCK-02: Test objectives_details_batch loop iteration
#[test]
fn test_objectives_details_batch_iteration() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };

    // Test with many token IDs
    let token_ids: Array<felt252> = array![1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    let results = objectives_details_dispatcher.objectives_details_batch(token_ids.span());

    assert!(results.len() == 10, "Should return 10 results");
}

// Test OBJ-MOCK-03: Test objectives_details with all completion states
#[test]
fn test_objectives_details_all_completed() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete all objectives for token 50
    setter.complete_objective(50, 1);
    setter.complete_objective(50, 2);
    setter.complete_objective(50, 3);

    let objectives = objectives_details_dispatcher.objectives_details(50);
    assert!(objectives.len() == 3, "Should have 3 objectives");

    // All should be completed
    let obj1 = objectives.at(0);
    let obj2 = objectives.at(1);
    let obj3 = objectives.at(2);

    let expected_value: ByteArray = "completed";
    assert!(obj1.value == @expected_value, "Objective 1 should be completed");
    assert!(obj2.value == @expected_value, "Objective 2 should be completed");
    assert!(obj3.value == @expected_value, "Objective 3 should be completed");
}

// Test OBJ-MOCK-04: Test objectives_details with no completed
#[test]
fn test_objectives_details_none_completed() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };

    // Token 999 has no completed objectives
    let objectives = objectives_details_dispatcher.objectives_details(999);
    assert!(objectives.len() == 3, "Should have 3 objectives");

    // All should be pending
    let obj1 = objectives.at(0);
    let obj2 = objectives.at(1);
    let obj3 = objectives.at(2);

    let expected_value: ByteArray = "pending";
    assert!(obj1.value == @expected_value, "Objective 1 should be pending");
    assert!(obj2.value == @expected_value, "Objective 2 should be pending");
    assert!(obj3.value == @expected_value, "Objective 3 should be pending");
}

// Test OBJ-MOCK-05: Test partial completion
#[test]
fn test_objectives_details_partial_completed() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_details_dispatcher = IMinigameObjectivesDetailsDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete only objective 2 for token 75
    setter.complete_objective(75, 2);

    let objectives = objectives_details_dispatcher.objectives_details(75);

    let completed: ByteArray = "completed";
    let pending: ByteArray = "pending";

    assert!(objectives.at(0).value == @pending, "Objective 1 should be pending");
    assert!(objectives.at(1).value == @completed, "Objective 2 should be completed");
    assert!(objectives.at(2).value == @pending, "Objective 3 should be pending");
}
