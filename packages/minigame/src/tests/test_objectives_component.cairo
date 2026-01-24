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
