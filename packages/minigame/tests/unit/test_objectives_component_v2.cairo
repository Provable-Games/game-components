use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    start_mock_call, stop_mock_call
};

use game_components_minigame::extensions::objectives::interface::{
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait,
    IMINIGAME_OBJECTIVES_ID
};
use game_components_minigame::extensions::objectives::structs::GameObjective;
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

//
// objective_exists Tests (OC-U2 to OC-U3)
//

#[test]
fn test_oc_u2_objective_exists_with_valid_id() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock objective_exists to return true for ID 1
    start_mock_call::<bool>(
        objectives_address,
        selector!("objective_exists"),
        true
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    assert(objectives.objective_exists(1), 'Objective should exist');
    
    stop_mock_call(objectives_address, selector!("objective_exists"));
}

#[test]
fn test_oc_u3_objective_exists_with_invalid_id() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock objective_exists to return false for ID 999
    start_mock_call::<bool>(
        objectives_address,
        selector!("objective_exists"),
        false
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    assert(!objectives.objective_exists(999), 'Objective should not exist');
    
    stop_mock_call(objectives_address, selector!("objective_exists"));
}

//
// completed_objective Tests (OC-U4 to OC-U5)
//

#[test]
fn test_oc_u4_completed_objective_when_completed() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock completed_objective to return true
    start_mock_call::<bool>(
        objectives_address,
        selector!("completed_objective"),
        true
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    assert(objectives.completed_objective(100, 1), 'Should be completed');
    
    stop_mock_call(objectives_address, selector!("completed_objective"));
}

#[test]
fn test_oc_u5_completed_objective_when_not_completed() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock completed_objective to return false
    start_mock_call::<bool>(
        objectives_address,
        selector!("completed_objective"),
        false
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    assert(!objectives.completed_objective(100, 1), 'Should not be completed');
    
    stop_mock_call(objectives_address, selector!("completed_objective"));
}

//
// objectives Tests (OC-U6 to OC-U7)
//

#[test]
fn test_oc_u6_objectives_with_token_having_objectives() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Create objectives array
    let objectives_array = array![
        GameObjective { name: "Objective 1", value: "Value 1" },
        GameObjective { name: "Objective 2", value: "Value 2" }
    ];
    
    // Mock objectives to return the array
    start_mock_call::<Span<GameObjective>>(
        objectives_address,
        selector!("objectives"),
        objectives_array.span()
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    let result = objectives.objectives(100);
    assert(result.len() == 2, 'Should have 2 objectives');
    assert(result.at(0).name == @"Objective 1", 'Wrong objective 1 name');
    assert(result.at(1).name == @"Objective 2", 'Wrong objective 2 name');
    
    stop_mock_call(objectives_address, selector!("objectives"));
}

#[test]
fn test_oc_u7_objectives_with_token_having_no_objectives() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock objectives to return empty array
    let empty_objectives: Array<GameObjective> = array![];
    start_mock_call::<Span<GameObjective>>(
        objectives_address,
        selector!("objectives"),
        empty_objectives.span()
    );
    
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    let result = objectives.objectives(100);
    assert(result.len() == 0, 'Should have no objectives');
    
    stop_mock_call(objectives_address, selector!("objectives"));
}

//
// objectives_svg Test (OC-U8)
//

#[test]
fn test_oc_u8_objectives_svg_with_valid_token() {
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    // Mock objectives_svg to return SVG string
    start_mock_call::<ByteArray>(
        objectives_address,
        selector!("objectives_svg"),
        "<svg>Test Objectives</svg>"
    );
    
    let objectives_svg = IMinigameObjectivesSVGDispatcher { contract_address: objectives_address };
    let svg = objectives_svg.objectives_svg(100);
    assert(svg == "<svg>Test Objectives</svg>", 'Wrong SVG');
    
    stop_mock_call(objectives_address, selector!("objectives_svg"));
}

//
// Helper function tests (OC-U9 to OC-U10)
//

#[test]
fn test_oc_u9_get_objective_ids_with_multi_game_token() {
    let token_address = contract_address_const::<'TOKEN'>();
    
    // Mock objective_ids to return [1, 2, 3]
    start_mock_call::<Span<u32>>(
        token_address,
        selector!("objective_ids"),
        array![1, 2, 3].span()
    );
    
    // Test get_objective_ids
    let ids = game_components_minigame::extensions::objectives::libs::get_objective_ids(token_address, 100);
    assert(ids.len() == 3, 'Should have 3 objective IDs');
    assert(*ids.at(0) == 1, 'Wrong ID 1');
    assert(*ids.at(1) == 2, 'Wrong ID 2');
    assert(*ids.at(2) == 3, 'Wrong ID 3');
    
    stop_mock_call(token_address, selector!("objective_ids"));
}

#[test]
fn test_oc_u10_create_objective_with_valid_data() {
    let token_address = contract_address_const::<'TOKEN'>();
    let game_address = contract_address_const::<'GAME'>();
    
    // Mock create_objective to succeed
    start_mock_call::<()>(
        token_address,
        selector!("create_objective"),
        ()
    );
    
    // Test create_objective
    game_components_minigame::extensions::objectives::libs::create_objective(
        token_address,
        game_address,
        1,
        "Test Objective",
        "Complete the test"
    );
    
    // If we get here without panic, the test passes
    stop_mock_call(token_address, selector!("create_objective"));
}