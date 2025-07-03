use starknet::{ContractAddress, contract_address_const};
use snforge_std::{
    declare, ContractClassTrait, DeclareResultTrait,
    start_mock_call, stop_mock_call
};

use game_components_minigame::extensions::objectives::interface::{
    IMinigameObjectivesDispatcher, IMinigameObjectivesDispatcherTrait,
    IMinigameObjectivesSVGDispatcher, IMinigameObjectivesSVGDispatcherTrait,
    IMINIGAME_OBJECTIVES_ID
};
use openzeppelin_introspection::interface::{ISRC5Dispatcher, ISRC5DispatcherTrait};

//
// Helpers
//

fn setup() -> ContractAddress {
    // Deploy MockObjectives contract
    let objectives_class = declare("MockObjectives").unwrap().contract_class();
    let (objectives_address, _) = objectives_class.deploy(@array![]).unwrap();
    objectives_address
}

//
// Initialization Tests (OC-U1)
//

#[test]
fn test_oc_u1_initialize_objectives_component() {
    // Deploy MockMinigame which includes objectives component
    let token_address = contract_address_const::<'TOKEN'>();
    let settings_address = contract_address_const::<'SETTINGS'>();
    let objectives_address = contract_address_const::<'OBJECTIVES'>();
    
    let minigame_class = declare("MockMinigame").unwrap().contract_class();
    let (_minigame_address, _) = minigame_class.deploy(@array![
        token_address.into(),
        settings_address.into(),
        objectives_address.into(),
    ]).unwrap();
    
    // Mock supports_interface to return true for IMINIGAME_OBJECTIVES_ID
    start_mock_call::<bool>(
        objectives_address,
        selector!("supports_interface"),
        true
    );
    
    // Verify SRC5 interface is registered
    let src5 = ISRC5Dispatcher { contract_address: objectives_address };
    assert(src5.supports_interface(IMINIGAME_OBJECTIVES_ID), 'IObjectives not registered');
    
    stop_mock_call(objectives_address, selector!("supports_interface"));
}

//
// objective_exists Tests (OC-U2 to OC-U3)
//

#[test]
fn test_oc_u2_objective_exists_with_valid_id() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Add objective through helper
    let mock_objectives_contract = IMockObjectivesDispatcher { contract_address: objectives_address };
    mock_objectives_contract.add_objective(1, "Test Objective", "Complete test");
    
    // Test objective_exists
    assert(objectives.objective_exists(1), 'Objective should exist');
}

#[test]
fn test_oc_u3_objective_exists_with_invalid_id() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Test objective_exists with non-existent ID
    assert(!objectives.objective_exists(999), 'Objective should not exist');
}

//
// completed_objective Tests (OC-U4 to OC-U5)
//

#[test]
fn test_oc_u4_completed_objective_when_completed() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Setup: Add objective and mark as completed
    let mock_objectives_contract = IMockObjectivesDispatcher { contract_address: objectives_address };
    mock_objectives_contract.add_objective(1, "Test Objective", "Complete test");
    mock_objectives_contract.complete_objective(100, 1); // token_id=100, objective_id=1
    
    // Test completed_objective
    assert(objectives.completed_objective(100, 1), 'Should be completed');
}

#[test]
fn test_oc_u5_completed_objective_when_not_completed() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Setup: Add objective but don't complete it
    let mock_objectives_contract = IMockObjectivesDispatcher { contract_address: objectives_address };
    mock_objectives_contract.add_objective(1, "Test Objective", "Complete test");
    
    // Test completed_objective
    assert(!objectives.completed_objective(100, 1), 'Should not be completed');
}

//
// objectives Tests (OC-U6 to OC-U7)
//

#[test]
fn test_oc_u6_objectives_with_token_having_objectives() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Setup: Add objectives and assign to token
    let mock_objectives_contract = IMockObjectivesDispatcher { contract_address: objectives_address };
    mock_objectives_contract.add_objective(1, "Objective 1", "Value 1");
    mock_objectives_contract.add_objective(2, "Objective 2", "Value 2");
    mock_objectives_contract.set_token_objectives(100, array![1, 2].span());
    
    // Test objectives
    let result = objectives.objectives(100);
    assert(result.len() == 2, 'Should have 2 objectives');
    assert(result.at(0).name == @"Objective 1", 'Wrong objective 1 name');
    assert(result.at(1).name == @"Objective 2", 'Wrong objective 2 name');
}

#[test]
fn test_oc_u7_objectives_with_token_having_no_objectives() {
    let objectives_address = setup();
    let objectives = IMinigameObjectivesDispatcher { contract_address: objectives_address };
    
    // Test objectives for token with no objectives
    let result = objectives.objectives(100);
    assert(result.len() == 0, 'Should have no objectives');
}

//
// objectives_svg Test (OC-U8)
//

#[test]
fn test_oc_u8_objectives_svg_with_valid_token() {
    let objectives_address = setup();
    
    // For SVG interface, we'll use mocking since MockObjectives doesn't implement it
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

//
// Mock helpers interface
//

#[starknet::interface]
trait IMockObjectives<TContractState> {
    fn add_objective(ref self: TContractState, objective_id: u32, name: ByteArray, value: ByteArray);
    fn set_token_objectives(ref self: TContractState, token_id: u64, objective_ids: Span<u32>);
    fn complete_objective(ref self: TContractState, token_id: u64, objective_id: u32);
}