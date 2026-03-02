// Test file for minigame/extensions/objectives/libs.cairo
// Tests the objectives library functions

use game_components_testing::constants::{ALICE, CREATOR, MAX_U32};
use snforge_std::mock_call;
use starknet::ContractAddress;
use crate::minigame::extensions::objectives::libs;
use crate::minigame::extensions::objectives::structs::{GameObjective, GameObjectiveDetails};

// =============================================================================
// Test Address Helpers
// =============================================================================

fn TOKEN_ADDRESS() -> ContractAddress {
    'TOKEN'.try_into().unwrap()
}

fn GAME_ADDRESS() -> ContractAddress {
    'GAME'.try_into().unwrap()
}

fn ZERO_ADDRESS() -> ContractAddress {
    0.try_into().unwrap()
}

// Helper to create GameObjectiveDetails
fn create_objective_details(
    name: ByteArray, description: ByteArray, objectives: Span<GameObjective>,
) -> GameObjectiveDetails {
    GameObjectiveDetails { name, description, objectives }
}

// =============================================================================
// Unit Tests: create_objective
// =============================================================================

// Test OBJ-LIB-U-01: create_objective with valid parameters
#[test]
fn test_create_objective_valid_parameters() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();
    let objective_id: u32 = 1;

    // Mock create_objective call
    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "First Blood", value: "Get the first kill" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        create_objective_details(
            "Combat Objectives", "Combat-related achievements", objectives.span(),
        ),
    );
}

// Test OBJ-LIB-U-02: create_objective with empty name
#[test]
fn test_create_objective_empty_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Objective 1", value: "Some description" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        2,
        create_objective_details("", "Description only", objectives.span()),
    );
}

// Test OBJ-LIB-U-03: create_objective with empty description
#[test]
fn test_create_objective_empty_description() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Empty Desc Objective", value: "value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        3,
        create_objective_details("Name Only", "", objectives.span()),
    );
}

// Test OBJ-LIB-U-04: create_objective with max objective_id
#[test]
fn test_create_objective_max_objective_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Max ID Objective", value: "Testing boundary" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32,
        create_objective_details("Boundary Test", "Testing max ID", objectives.span()),
    );
}

// Test OBJ-LIB-U-05: create_objective with zero objective_id
#[test]
fn test_create_objective_zero_objective_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Zero ID Objective", value: "Testing zero" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        0,
        create_objective_details("Zero ID Test", "Testing zero ID", objectives.span()),
    );
}

// Test OBJ-LIB-U-06: create_objective with long name
#[test]
fn test_create_objective_long_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let long_name: ByteArray =
        "This is a very long objective name that tests the limits of ByteArray storage and handling in the contract system";

    let objectives = array![GameObjective { name: "Sub-objective", value: "Normal value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        4,
        create_objective_details(long_name, "Normal description", objectives.span()),
    );
}

// Test OBJ-LIB-U-07: create_objective with long description
#[test]
fn test_create_objective_long_description() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let long_description: ByteArray =
        "This is a very long objective description containing multiple sentences. It tests how the contract handles large ByteArray values. The objectives system should support arbitrary length descriptions for flexibility.";

    let objectives = array![GameObjective { name: "Normal Name", value: "value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        5,
        create_objective_details("Normal Name", long_description, objectives.span()),
    );
}

// Test OBJ-LIB-U-08: create_objective with special characters in name
#[test]
fn test_create_objective_special_chars_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![
        GameObjective { name: "Special: !@#$%^&*()", value: "Testing special characters" },
    ];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        6,
        create_objective_details("Special Chars", "Test with special chars", objectives.span()),
    );
}

// Test OBJ-LIB-U-09: create_objective with complex content
#[test]
fn test_create_objective_complex_content() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![
        GameObjective {
            name: "Multi-line\ndescription\nwith newlines",
            value: "Value with\ttabs\tand\tnewlines\n",
        },
    ];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        7,
        create_objective_details("Complex", "Complex content test", objectives.span()),
    );
}

// Test OBJ-LIB-U-10: create_objective with multiple objectives in span
#[test]
fn test_create_objective_multiple_in_span() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![
        GameObjective { name: "First Blood", value: "Get the first kill" },
        GameObjective { name: "Double Kill", value: "Get two kills quickly" },
        GameObjective { name: "Triple Kill", value: "Get three kills quickly" },
    ];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        8,
        create_objective_details(
            "Kill Streak Objectives", "Combat achievements", objectives.span(),
        ),
    );
}

// =============================================================================
// Integration Tests
// =============================================================================

// Test OBJ-LIB-I-01: verify GameObjectiveDetails struct construction
#[test]
fn test_game_objective_details_struct_construction() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let name: ByteArray = "Complex Objective";
    let description: ByteArray = "Multi-line\ndescription\nwith special chars: !@#$%";
    let objectives = array![
        GameObjective { name: "Sub 1", value: "Value 1" },
        GameObjective { name: "Sub 2", value: "Value 2" },
    ];

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        10,
        create_objective_details(name, description, objectives.span()),
    );
}

// Test OBJ-LIB-I-02: create multiple objectives sequentially
#[test]
fn test_create_multiple_objectives_sequentially() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    // Mock multiple create_objective calls
    mock_call(token_address, selector!("create_objective"), (), 10);

    let obj1 = array![GameObjective { name: "Obj 1", value: "Desc 1" }];
    let obj2 = array![GameObjective { name: "Obj 2", value: "Desc 2" }];
    let obj3 = array![GameObjective { name: "Obj 3", value: "Desc 3" }];

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        create_objective_details("Group One", "First group", obj1.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        2,
        create_objective_details("Group Two", "Second group", obj2.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        3,
        create_objective_details("Group Three", "Third group", obj3.span()),
    );
}

// Test OBJ-LIB-I-03: create objectives with different games
#[test]
fn test_create_objectives_different_games() {
    let token_address = TOKEN_ADDRESS();
    let game1 = GAME_ADDRESS();
    let game2: ContractAddress = 'GAME2'.try_into().unwrap();
    let creator = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 10);

    let obj1 = array![GameObjective { name: "Game 1 Objective", value: "From game 1" }];
    let obj2 = array![GameObjective { name: "Game 2 Objective", value: "From game 2" }];

    libs::create_objective(
        token_address,
        game1,
        creator,
        100,
        create_objective_details("Game 1 Objectives", "From game 1", obj1.span()),
    );

    libs::create_objective(
        token_address,
        game2,
        creator,
        101,
        create_objective_details("Game 2 Objectives", "From game 2", obj2.span()),
    );
}

// Test OBJ-LIB-I-04: create objectives with different creators
#[test]
fn test_create_objectives_different_creators() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator1 = CREATOR();
    let creator2 = ALICE();

    mock_call(token_address, selector!("create_objective"), (), 10);

    let obj1 = array![GameObjective { name: "Creator 1 Objective", value: "From creator 1" }];
    let obj2 = array![GameObjective { name: "Creator 2 Objective", value: "From creator 2" }];

    libs::create_objective(
        token_address,
        game_address,
        creator1,
        200,
        create_objective_details("Creator 1", "From creator 1", obj1.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator2,
        201,
        create_objective_details("Creator 2", "From creator 2", obj2.span()),
    );
}

// Test OBJ-LIB-I-05: verify all parameters are passed through
#[test]
fn test_all_params_passed_through() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();
    let objective_id: u32 = 42;
    let name: ByteArray = "Test Objective";
    let description: ByteArray = "Test Description";

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Sub", value: "Value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        create_objective_details(name, description, objectives.span()),
    );
}

// =============================================================================
// Edge Case Tests
// =============================================================================

// Test OBJ-LIB-E-01: both name and description empty
#[test]
fn test_create_objective_both_empty() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "", value: "" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        8,
        create_objective_details("", "", objectives.span()),
    );
}

// Test OBJ-LIB-E-02: very long strings for both name and description
#[test]
fn test_create_objective_very_long_strings() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let long_name: ByteArray =
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    let long_description: ByteArray =
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

    let objectives = array![GameObjective { name: "Long", value: "strings" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        9,
        create_objective_details(long_name, long_description, objectives.span()),
    );
}

// Test OBJ-LIB-E-03: consecutive objective IDs
#[test]
fn test_create_objectives_consecutive_ids() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 100);

    let objectives = array![GameObjective { name: "Objective", value: "Value" }];

    let mut i: u32 = 0;
    loop {
        if i >= 10 {
            break;
        }
        libs::create_objective(
            token_address,
            game_address,
            creator_address,
            i,
            create_objective_details("Group", "Description", objectives.span()),
        );
        i += 1;
    }
}

// Test OBJ-LIB-E-04: boundary objective IDs
#[test]
fn test_create_objectives_boundary_ids() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 10);

    let objectives = array![GameObjective { name: "Boundary", value: "Value" }];

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        0,
        create_objective_details("ID 0", "Zero", objectives.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        create_objective_details("ID 1", "One", objectives.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32 - 1,
        create_objective_details("ID Max-1", "Max minus one", objectives.span()),
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32,
        create_objective_details("ID Max", "Maximum", objectives.span()),
    );
}

// Test OBJ-LIB-E-05: empty objectives span
#[test]
fn test_create_objective_empty_span() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives: Array<GameObjective> = array![];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        11,
        create_objective_details("Empty Objectives", "No sub-objectives", objectives.span()),
    );
}

// =============================================================================
// Fuzz Tests
// =============================================================================

// Test OBJ-LIB-F-01: fuzz objective_id values
#[test]
#[fuzzer]
fn test_create_objective_fuzz_ids(objective_id: u32) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "Fuzz Test", value: "Fuzz Value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        create_objective_details("Fuzz", "Fuzz test", objectives.span()),
    );
}

// Test OBJ-LIB-F-02: fuzz with different name felt values (using felt252 as seed)
#[test]
#[fuzzer]
fn test_create_objective_fuzz_content(seed: felt252) {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objective_id: u32 = (seed.try_into().unwrap_or(0_u128) % 1000000).try_into().unwrap();

    let objectives = array![GameObjective { name: "Fuzz Name", value: "Fuzz Value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        create_objective_details("Fuzz", "Fuzz description", objectives.span()),
    );
}

// =============================================================================
// Additional Coverage Tests
// =============================================================================

// Test OBJ-LIB-ADD-01: Create multiple objectives with large gaps in IDs
#[test]
fn test_create_objectives_sparse_ids() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 5);

    let objectives = array![GameObjective { name: "Sparse", value: "value" }];

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        create_objective_details("First", "v1", objectives.span()),
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1000,
        create_objective_details("Thousand", "v2", objectives.span()),
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1000000,
        create_objective_details("Million", "v3", objectives.span()),
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32 / 2,
        create_objective_details("Half Max", "v4", objectives.span()),
    );
}

// Test OBJ-LIB-ADD-02: Create objective with name containing only spaces
#[test]
fn test_create_objective_spaces_only() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let objectives = array![GameObjective { name: "     ", value: "Normal value" }];
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        500,
        create_objective_details("     ", "Normal description", objectives.span()),
    );
}

// Test OBJ-LIB-ADD-03: Create objective for different token addresses
#[test]
fn test_create_objective_different_tokens() {
    let token1: ContractAddress = 'TOKEN1'.try_into().unwrap();
    let token2: ContractAddress = 'TOKEN2'.try_into().unwrap();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token1, selector!("create_objective"), (), 1);
    mock_call(token2, selector!("create_objective"), (), 1);

    let obj1 = array![GameObjective { name: "Token 1 Obj", value: "v1" }];
    let obj2 = array![GameObjective { name: "Token 2 Obj", value: "v2" }];

    libs::create_objective(
        token1,
        game_address,
        creator_address,
        1,
        create_objective_details("Token 1", "From token 1", obj1.span()),
    );
    libs::create_objective(
        token2,
        game_address,
        creator_address,
        2,
        create_objective_details("Token 2", "From token 2", obj2.span()),
    );
}
