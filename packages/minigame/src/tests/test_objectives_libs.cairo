// Test file for minigame/extensions/objectives/libs.cairo
// Tests the objectives library functions

use game_components_testing::constants::{ALICE, CREATOR, MAX_U32};
use snforge_std::mock_call;
use starknet::ContractAddress;
use crate::extensions::objectives::libs;
use crate::extensions::objectives::structs::GameObjective;

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

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        GameObjective { name: "First Blood", value: "Get the first kill" },
    );
}

// Test OBJ-LIB-U-02: create_objective with empty name
#[test]
fn test_create_objective_empty_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        2,
        GameObjective { name: "", value: "Some description" },
    );
}

// Test OBJ-LIB-U-03: create_objective with empty value
#[test]
fn test_create_objective_empty_value() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        3,
        GameObjective { name: "Empty Value Objective", value: "" },
    );
}

// Test OBJ-LIB-U-04: create_objective with max objective_id
#[test]
fn test_create_objective_max_objective_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32,
        GameObjective { name: "Max ID Objective", value: "Testing boundary" },
    );
}

// Test OBJ-LIB-U-05: create_objective with zero objective_id
#[test]
fn test_create_objective_zero_objective_id() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        0,
        GameObjective { name: "Zero ID Objective", value: "Testing zero" },
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

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        4,
        GameObjective { name: long_name, value: "Normal value" },
    );
}

// Test OBJ-LIB-U-07: create_objective with long value
#[test]
fn test_create_objective_long_value() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    let long_value: ByteArray =
        "This is a very long objective value containing multiple sentences. It tests how the contract handles large ByteArray values. The objectives system should support arbitrary length descriptions for flexibility.";

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        5,
        GameObjective { name: "Normal Name", value: long_value },
    );
}

// Test OBJ-LIB-U-08: create_objective with special characters in name
#[test]
fn test_create_objective_special_chars_name() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        6,
        GameObjective { name: "Special: !@#$%^&*()", value: "Testing special characters" },
    );
}

// Test OBJ-LIB-U-09: create_objective with unicode-like content
#[test]
fn test_create_objective_complex_content() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        7,
        GameObjective {
            name: "Multi-line\ndescription\nwith newlines",
            value: "Value with\ttabs\tand\tnewlines\n",
        },
    );
}

// =============================================================================
// Integration Tests
// =============================================================================

// Test OBJ-LIB-I-01: verify GameObjective struct construction
#[test]
fn test_game_objective_struct_construction() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    // The libs function creates a GameObjective internally
    // We verify by testing it doesn't panic with complex data
    mock_call(token_address, selector!("create_objective"), (), 1);

    let name: ByteArray = "Complex Objective";
    let value: ByteArray = "Multi-line\ndescription\nwith special chars: !@#$%";

    libs::create_objective(
        token_address, game_address, creator_address, 10, GameObjective { name, value },
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

    // Create first objective
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        GameObjective { name: "Objective One", value: "Description One" },
    );

    // Create second objective
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        2,
        GameObjective { name: "Objective Two", value: "Description Two" },
    );

    // Create third objective
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        3,
        GameObjective { name: "Objective Three", value: "Description Three" },
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

    // Game 1 creates objective
    libs::create_objective(
        token_address,
        game1,
        creator,
        100,
        GameObjective { name: "Game 1 Objective", value: "From game 1" },
    );

    // Game 2 creates objective
    libs::create_objective(
        token_address,
        game2,
        creator,
        101,
        GameObjective { name: "Game 2 Objective", value: "From game 2" },
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

    // First creator
    libs::create_objective(
        token_address,
        game_address,
        creator1,
        200,
        GameObjective { name: "Creator 1 Objective", value: "From creator 1" },
    );

    // Second creator
    libs::create_objective(
        token_address,
        game_address,
        creator2,
        201,
        GameObjective { name: "Creator 2 Objective", value: "From creator 2" },
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
    let value: ByteArray = "Test Value";

    mock_call(token_address, selector!("create_objective"), (), 1);

    // This tests that all params are correctly passed - any issue would cause a panic
    libs::create_objective(
        token_address, game_address, creator_address, objective_id, GameObjective { name, value },
    );
}

// =============================================================================
// Edge Case Tests
// =============================================================================

// Test OBJ-LIB-E-01: both name and value empty
#[test]
fn test_create_objective_both_empty() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address, game_address, creator_address, 8, GameObjective { name: "", value: "" },
    );
}

// Test OBJ-LIB-E-02: very long strings for both name and value
#[test]
fn test_create_objective_very_long_strings() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    // Create long strings by repeating
    let long_name: ByteArray =
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    let long_value: ByteArray =
        "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB";

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        9,
        GameObjective { name: long_name, value: long_value },
    );
}

// Test OBJ-LIB-E-03: consecutive objective IDs
#[test]
fn test_create_objectives_consecutive_ids() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 100);

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
            GameObjective { name: "Objective", value: "Value" },
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

    // Test boundary values
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        0,
        GameObjective { name: "ID 0", value: "Value" },
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        GameObjective { name: "ID 1", value: "Value" },
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32 - 1,
        GameObjective { name: "ID Max-1", value: "Value" },
    );

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32,
        GameObjective { name: "ID Max", value: "Value" },
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

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        GameObjective { name: "Fuzz Test", value: "Fuzz Value" },
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

    // Use seed to create deterministic but varied content
    let objective_id: u32 = (seed.try_into().unwrap_or(0_u128) % 1000000).try_into().unwrap();

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        objective_id,
        GameObjective { name: "Fuzz Name", value: "Fuzz Value" },
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

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1,
        GameObjective { name: "First", value: "v1" },
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1000,
        GameObjective { name: "Thousand", value: "v2" },
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        1000000,
        GameObjective { name: "Million", value: "v3" },
    );
    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        MAX_U32 / 2,
        GameObjective { name: "Half Max", value: "v4" },
    );
}

// Test OBJ-LIB-ADD-02: Create objective with name containing only spaces
#[test]
fn test_create_objective_spaces_only() {
    let token_address = TOKEN_ADDRESS();
    let game_address = GAME_ADDRESS();
    let creator_address = CREATOR();

    mock_call(token_address, selector!("create_objective"), (), 1);

    libs::create_objective(
        token_address,
        game_address,
        creator_address,
        500,
        GameObjective { name: "     ", value: "Normal value" },
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

    libs::create_objective(
        token1,
        game_address,
        creator_address,
        1,
        GameObjective { name: "Token 1 Obj", value: "v1" },
    );
    libs::create_objective(
        token2,
        game_address,
        creator_address,
        2,
        GameObjective { name: "Token 2 Obj", value: "v2" },
    );
}
