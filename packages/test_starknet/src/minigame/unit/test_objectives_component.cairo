use game_components_minigame::extensions::objectives::interface::{
    IMinigameObjectives, IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    IMinigameObjectivesSVG, IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait,
    IMINIGAME_OBJECTIVES_ID,
};
use game_components_minigame::extensions::objectives::structs::GameObjective;
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use starknet::{contract_address_const, get_caller_address};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use core::to_byte_array::FormatAsByteArray;
use game_components_test_starknet::token::setup::deploy_mock_objectives_contract;
use game_components_test_starknet::minigame::mocks::mock_objectives_contract::{
    IObjectivesSetterDispatcher, IObjectivesSetterDispatcherTrait,
};

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
        src5_dispatcher.supports_interface(openzeppelin_introspection::interface::ISRC5_ID),
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

// Test OBJ-U-05: Get objectives for token
#[test]
fn test_get_objectives_for_token() {
    let contract_address = deploy_mock_objectives_contract();

    let objectives_dispatcher = IMinigameObjectivesDispatcher { contract_address };
    let setter = IObjectivesSetterDispatcher { contract_address };

    // Complete some objectives
    setter.complete_objective(10, 1);
    setter.complete_objective(10, 3);

    // Get objectives
    let objectives = objectives_dispatcher.objectives(10);

    assert!(objectives.len() == 3, "Should have 3 objectives");

    // Check first objective
    let obj1 = objectives.at(0);
    assert!(obj1.name == "First Blood", "First objective name mismatch");
    assert!(obj1.value == "completed", "First objective should be completed");

    // Check second objective
    let obj2 = objectives.at(1);
    assert!(obj2.name == "Double Kill", "Second objective name mismatch");
    assert!(obj2.value == "pending", "Second objective should not be completed");

    // Check third objective
    let obj3 = objectives.at(2);
    assert!(obj3.name == "Ace", "Third objective name mismatch");
    assert!(obj3.value == "completed", "Third objective should be completed");
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

// Test OBJ-U-08: Get_objective_ids from token
#[test]
fn test_get_objective_ids() {
    let contract_address = deploy_mock_objectives_contract();

    let setter = IObjectivesSetterDispatcher { contract_address };
    let objective_ids = setter.get_objective_ids(1);

    assert!(objective_ids.len() == 3, "Should have 3 objective IDs");
    assert!(*objective_ids.at(0) == 1, "First ID should be 1");
    assert!(*objective_ids.at(1) == 2, "Second ID should be 2");
    assert!(*objective_ids.at(2) == 3, "Third ID should be 3");
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
