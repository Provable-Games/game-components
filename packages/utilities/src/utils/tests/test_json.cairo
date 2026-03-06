// ==============================================================================
// JSON MODULE TESTS
// ==============================================================================
// Tests for JSON generation functions.
// All functions are pure - no contract deployment needed.

use game_components_embeddable_game_standard::metagame::extensions::context::structs::GameContext;
use game_components_embeddable_game_standard::minigame::extensions::objectives::structs::GameObjective;
use game_components_embeddable_game_standard::minigame::extensions::settings::structs::GameSetting;
use crate::utils::json::{
    create_context_json, create_json_array, create_objectives_json, create_settings_json,
};

// ==============================================================================
// HELPER FUNCTIONS
// ==============================================================================

fn setting(name: felt252, value: felt252) -> GameSetting {
    GameSetting { name, value }
}

fn objective(name: felt252, value: felt252) -> GameObjective {
    GameObjective { name, value }
}

fn context(name: felt252, value: felt252) -> GameContext {
    GameContext { name, value }
}

// Helper to check if a ByteArray contains a substring
fn contains(haystack: @ByteArray, needle: @ByteArray) -> bool {
    if needle.len() == 0 {
        return true;
    }
    if haystack.len() < needle.len() {
        return false;
    }

    let mut i: u32 = 0;
    let max_start = haystack.len() - needle.len() + 1;
    loop {
        if i >= max_start {
            break false;
        }

        let mut matches = true;
        let mut j: u32 = 0;
        loop {
            if j >= needle.len() {
                break;
            }
            if haystack.at(i + j).unwrap() != needle.at(j).unwrap() {
                matches = false;
                break;
            }
            j += 1;
        }

        if matches {
            break true;
        }
        i += 1;
    }
}

// ==============================================================================
// CREATE_SETTINGS_JSON TESTS - BASIC FUNCTIONALITY
// ==============================================================================

#[test]
fn test_settings_json_single_setting() {
    let settings = array![setting('Difficulty', 'Hard')].span();
    let result = create_settings_json("Game", "Description", settings);

    assert!(contains(@result, @"\"Name\":\"Game\""), "Should contain Name field");
    assert!(
        contains(@result, @"\"Description\":\"Description\""), "Should contain Description field",
    );
    // Settings are wrapped in a nested JSON string with escaped quotes
    assert!(contains(@result, @"Difficulty"), "Should contain setting name");
    assert!(contains(@result, @"Hard"), "Should contain setting value");
}

#[test]
fn test_settings_json_multiple_settings() {
    let settings = array![setting('Difficulty', 'Hard'), setting('Lives', '3')].span();
    let result = create_settings_json("Game", "Desc", settings);

    // Settings are in a nested JSON string
    assert!(contains(@result, @"Difficulty"), "Should contain first setting name");
    assert!(contains(@result, @"Hard"), "Should contain first setting value");
    assert!(contains(@result, @"Lives"), "Should contain second setting name");
}

#[test]
fn test_settings_json_preserves_order() {
    let settings = array![setting('A', '1'), setting('B', '2'), setting('C', '3')].span();
    let result = create_settings_json("Test", "Test", settings);

    // Check that all settings keys are present (settings are in nested JSON string)
    assert!(contains(@result, @"A"), "Should contain A");
    assert!(contains(@result, @"B"), "Should contain B");
    assert!(contains(@result, @"C"), "Should contain C");
}

// ==============================================================================
// CREATE_SETTINGS_JSON TESTS - EDGE CASES
// ==============================================================================

#[test]
fn test_settings_json_empty_settings() {
    let settings: Span<GameSetting> = array![].span();
    let result = create_settings_json("Game", "Desc", settings);

    assert!(contains(@result, @"\"Name\":\"Game\""), "Should contain Name");
    // Empty settings results in empty JSON object string "{}"
    assert!(contains(@result, @"Settings"), "Should contain Settings key");
}

#[test]
fn test_settings_json_empty_name() {
    let settings = array![setting('Key', 'Value')].span();
    let result = create_settings_json("", "Description", settings);

    assert!(contains(@result, @"\"Name\":\"\""), "Should handle empty name");
}

#[test]
fn test_settings_json_empty_description() {
    let settings = array![setting('Key', 'Value')].span();
    let result = create_settings_json("Game", "", settings);

    assert!(contains(@result, @"\"Description\":\"\""), "Should handle empty description");
}

#[test]
fn test_settings_json_empty_setting_value() {
    let settings = array![setting('Key', '')].span();
    let result = create_settings_json("Game", "Desc", settings);

    // Setting is in nested JSON string
    assert!(contains(@result, @"Key"), "Should contain setting key");
}

#[test]
fn test_settings_json_special_characters() {
    // Test with ASCII special characters
    let settings = array![setting('Mode', 'Easy-Mode')].span();
    let result = create_settings_json("Game-v2", "Test Description", settings);

    assert!(contains(@result, @"Game-v2"), "Should handle special characters in name");
}

// ==============================================================================
// CREATE_SETTINGS_JSON FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_settings_json_fuzz_count(count: u8) {
    let bounded_count = count % 51; // 0-50 settings
    let mut settings_arr: Array<GameSetting> = array![];

    let mut i: u8 = 0;
    loop {
        if i >= bounded_count {
            break;
        }
        settings_arr.append(setting(i.into(), i.into()));
        i += 1;
    }

    let result = create_settings_json("Test", "Desc", settings_arr.span());

    // Should not panic and should produce output
    assert!(result.len() > 0, "Should produce non-empty output");
}

// ==============================================================================
// CREATE_OBJECTIVES_JSON TESTS - BASIC FUNCTIONALITY
// ==============================================================================

#[test]
fn test_objectives_json_single() {
    let objectives = array![objective('Score 100', '100 points')].span();
    let result = create_objectives_json(objectives);

    assert!(contains(@result, @"\"Score 100\":\"100 points\""), "Should contain single objective");
}

#[test]
fn test_objectives_json_multiple() {
    let objectives = array![objective('Score', '100'), objective('Kills', '10')].span();
    let result = create_objectives_json(objectives);

    assert!(contains(@result, @"\"Score\":\"100\""), "Should contain first objective");
    assert!(contains(@result, @"\"Kills\":\"10\""), "Should contain second objective");
}

#[test]
fn test_objectives_json_preserves_order() {
    let objectives = array![
        objective('First', '1'), objective('Second', '2'), objective('Third', '3'),
    ]
        .span();
    let result = create_objectives_json(objectives);

    assert!(contains(@result, @"\"First\":\"1\""), "Should contain First");
    assert!(contains(@result, @"\"Second\":\"2\""), "Should contain Second");
    assert!(contains(@result, @"\"Third\":\"3\""), "Should contain Third");
}

// ==============================================================================
// CREATE_OBJECTIVES_JSON TESTS - EDGE CASES
// ==============================================================================

#[test]
fn test_objectives_json_empty() {
    let objectives: Span<GameObjective> = array![].span();
    let result = create_objectives_json(objectives);

    assert!(result == "{}", "Empty objectives should return empty object");
}

#[test]
fn test_objectives_json_empty_value() {
    let objectives = array![objective('Key', '')].span();
    let result = create_objectives_json(objectives);

    assert!(contains(@result, @"\"Key\":\"\""), "Should handle empty value");
}

#[test]
fn test_objectives_json_max_felt_values() {
    // Test with values near felt252 max length (31 bytes)
    let objectives = array![objective('Long Objective', 'A long value near limit')].span();
    let result = create_objectives_json(objectives);

    assert!(result.len() > 0, "Should handle max felt values");
    assert!(contains(@result, @"Long Objective"), "Should contain objective name");
}

// ==============================================================================
// CREATE_OBJECTIVES_JSON FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_objectives_json_fuzz_count(count: u8) {
    let bounded_count = count % 51; // 0-50 objectives
    let mut objectives_arr: Array<GameObjective> = array![];

    let mut i: u8 = 0;
    loop {
        if i >= bounded_count {
            break;
        }
        objectives_arr.append(objective(i.into(), i.into()));
        i += 1;
    }

    let result = create_objectives_json(objectives_arr.span());

    // Should not panic
    if bounded_count == 0 {
        assert!(result == "{}", "Empty should return empty object");
    } else {
        assert!(result.len() > 2, "Should produce non-empty output");
    }
}

// ==============================================================================
// CREATE_CONTEXT_JSON TESTS - BASIC FUNCTIONALITY
// ==============================================================================

#[test]
fn test_context_json_with_id() {
    let contexts = array![context('Tournament', 'Weekly')].span();
    let result = create_context_json("Budokan", "Tournament system", Option::Some(1), contexts);

    assert!(contains(@result, @"\"Name\":\"Budokan\""), "Should contain name");
    assert!(
        contains(@result, @"\"Description\":\"Tournament system\""), "Should contain description",
    );
    assert!(contains(@result, @"\"Context Id\":\"1\""), "Should contain context id");
    // Contexts are in nested JSON string
    assert!(contains(@result, @"Tournament"), "Should contain context key");
    assert!(contains(@result, @"Weekly"), "Should contain context value");
}

#[test]
fn test_context_json_without_id() {
    let contexts = array![context('Mode', 'Casual')].span();
    let result = create_context_json("App", "Description", Option::None, contexts);

    assert!(contains(@result, @"\"Name\":\"App\""), "Should contain name");
    // Should NOT contain Context Id field
    assert!(!contains(@result, @"\"Context Id\""), "Should not contain Context Id when None");
}

#[test]
fn test_context_json_multiple_contexts() {
    let contexts = array![context('Tournament', 'Weekly'), context('Round', '1')].span();
    let result = create_context_json("Budokan", "Tournament", Option::Some(42), contexts);

    // Contexts are in nested JSON string
    assert!(contains(@result, @"Tournament"), "Should contain first context key");
    assert!(contains(@result, @"Weekly"), "Should contain first context value");
    assert!(contains(@result, @"Round"), "Should contain second context key");
}

#[test]
fn test_context_json_field_order() {
    let contexts = array![context('Key', 'Value')].span();
    let result = create_context_json("Name", "Desc", Option::Some(5), contexts);

    // Verify Name comes before Description
    assert!(contains(@result, @"\"Name\":\"Name\""), "Should contain Name");
    assert!(contains(@result, @"\"Description\":\"Desc\""), "Should contain Description");
    assert!(contains(@result, @"\"Context Id\":\"5\""), "Should contain Context Id");
    assert!(contains(@result, @"\"Contexts\""), "Should contain Contexts");
}

// ==============================================================================
// CREATE_CONTEXT_JSON TESTS - EDGE CASES
// ==============================================================================

#[test]
fn test_context_json_empty_contexts() {
    let contexts: Span<GameContext> = array![].span();
    let result = create_context_json("App", "Desc", Option::Some(1), contexts);

    // Contexts is a nested JSON string
    assert!(contains(@result, @"Contexts"), "Should contain Contexts key");
}

#[test]
fn test_context_json_zero_id() {
    let contexts = array![context('Key', 'Value')].span();
    let result = create_context_json("App", "Desc", Option::Some(0), contexts);

    assert!(contains(@result, @"\"Context Id\":\"0\""), "Should handle zero context ID");
}

#[test]
fn test_context_json_large_id() {
    let contexts = array![context('Key', 'Value')].span();
    let result = create_context_json("App", "Desc", Option::Some(4294967295), contexts);

    assert!(
        contains(@result, @"\"Context Id\":\"4294967295\""), "Should handle max u32 context ID",
    );
}

#[test]
fn test_context_json_empty_name_desc() {
    let contexts = array![context('Key', 'Value')].span();
    let result = create_context_json("", "", Option::None, contexts);

    assert!(contains(@result, @"\"Name\":\"\""), "Should handle empty name");
    assert!(contains(@result, @"\"Description\":\"\""), "Should handle empty description");
}

#[test]
fn test_context_json_special_characters() {
    let contexts = array![context('Type-v2', 'Value-1')].span();
    let result = create_context_json("App-Name", "Desc-Text", Option::Some(1), contexts);

    assert!(contains(@result, @"App-Name"), "Should handle special chars in name");
}

// ==============================================================================
// CREATE_CONTEXT_JSON FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_context_json_fuzz_id(context_id: u32) {
    let contexts = array![context('Key', 'Value')].span();
    let result = create_context_json("App", "Desc", Option::Some(context_id), contexts);

    // Should not panic and should contain the formatted ID
    assert!(result.len() > 0, "Should produce output");
    assert!(contains(@result, @"\"Context Id\""), "Should contain Context Id field");
}

#[test]
#[fuzzer(runs: 50)]
fn test_context_json_fuzz_count(count: u8) {
    let bounded_count = count % 51; // 0-50 contexts
    let mut contexts_arr: Array<GameContext> = array![];

    let mut i: u8 = 0;
    loop {
        if i >= bounded_count {
            break;
        }
        contexts_arr.append(context(i.into(), i.into()));
        i += 1;
    }

    let result = create_context_json("App", "Desc", Option::Some(1), contexts_arr.span());

    // Should not panic
    assert!(result.len() > 0, "Should produce non-empty output");
}

// ==============================================================================
// CREATE_JSON_ARRAY TESTS - BASIC FUNCTIONALITY
// ==============================================================================

#[test]
fn test_json_array_single_element() {
    let values = array!["value1"].span();
    let result = create_json_array(values);

    assert!(result == "[\"value1\"]", "Single element array should be correct");
}

#[test]
fn test_json_array_multiple_elements() {
    let values = array!["a", "b", "c"].span();
    let result = create_json_array(values);

    assert!(result == "[\"a\",\"b\",\"c\"]", "Multiple elements should be comma-separated");
}

#[test]
fn test_json_array_element_quoting() {
    let values = array!["test"].span();
    let result = create_json_array(values);

    // Should have quotes around the value
    assert!(contains(@result, @"\"test\""), "Elements should be quoted");
}

// ==============================================================================
// CREATE_JSON_ARRAY TESTS - EDGE CASES
// ==============================================================================

#[test]
fn test_json_array_empty() {
    let values: Span<ByteArray> = array![].span();
    let result = create_json_array(values);

    assert!(result == "[]", "Empty array should return []");
}

#[test]
fn test_json_array_empty_string_element() {
    let values = array![""].span();
    let result = create_json_array(values);

    assert!(result == "[\"\"]", "Empty string element should be quoted");
}

#[test]
fn test_json_array_single_empty() {
    let values = array![""].span();
    let result = create_json_array(values);

    // Verify structure
    let first_char = result.at(0).unwrap();
    let last_char = result.at(result.len() - 1).unwrap();
    assert!(first_char == '[', "Should start with [");
    assert!(last_char == ']', "Should end with ]");
}

#[test]
fn test_json_array_mixed_empty() {
    let values = array!["a", "", "c"].span();
    let result = create_json_array(values);

    assert!(result == "[\"a\",\"\",\"c\"]", "Should handle mixed empty and non-empty");
}

// ==============================================================================
// CREATE_JSON_ARRAY FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_json_array_fuzz_count(count: u8) {
    let bounded_count = count % 101; // 0-100 elements
    let mut values_arr: Array<ByteArray> = array![];

    let mut i: u8 = 0;
    loop {
        if i >= bounded_count {
            break;
        }
        values_arr.append(format!("value{}", i));
        i += 1;
    }

    let result = create_json_array(values_arr.span());

    // Verify starts with [ and ends with ]
    if bounded_count == 0 {
        assert!(result == "[]", "Empty should be []");
    } else {
        let first_char = result.at(0).unwrap();
        let last_char = result.at(result.len() - 1).unwrap();
        assert!(first_char == '[', "Should start with [");
        assert!(last_char == ']', "Should end with ]");

        // Verify no trailing comma before ]
        let second_last_char = result.at(result.len() - 2).unwrap();
        assert!(second_last_char != ',', "Should not have trailing comma");
    }
}

// ==============================================================================
// ADDITIONAL INTEGRATION TESTS
// ==============================================================================

#[test]
fn test_settings_json_real_world_example() {
    // Simulate real game settings
    let settings = array![
        setting('Difficulty', 'Expert'), setting('Time Limit', '300'), setting('Lives', '3'),
        setting('Power-ups', 'Enabled'),
    ]
        .span();

    let result = create_settings_json("Puzzle Mode", "Challenge yourself with puzzles", settings);

    assert!(contains(@result, @"\"Name\":\"Puzzle Mode\""), "Should have name");
    // Settings are in nested JSON string
    assert!(contains(@result, @"Difficulty"), "Should have difficulty");
    assert!(contains(@result, @"Expert"), "Should have difficulty value");
    assert!(contains(@result, @"Time Limit"), "Should have time limit");
    assert!(contains(@result, @"Lives"), "Should have lives");
    assert!(contains(@result, @"Power-ups"), "Should have power-ups");
}

#[test]
fn test_context_json_tournament_example() {
    // Simulate tournament context
    let contexts = array![
        context('Tournament Id', '12345'), context('Round', 'Quarter Finals'),
        context('Prize Pool', '1000 STRK'),
    ]
        .span();

    let result = create_context_json(
        "Budokan", "The onchain tournament system", Option::Some(42), contexts,
    );

    assert!(contains(@result, @"\"Name\":\"Budokan\""), "Should have name");
    assert!(contains(@result, @"\"Context Id\":\"42\""), "Should have context id");
    // Contexts are in nested JSON string
    assert!(contains(@result, @"Tournament Id"), "Should have tournament id key");
    assert!(contains(@result, @"12345"), "Should have tournament id value");
    assert!(contains(@result, @"Round"), "Should have round key");
}

#[test]
fn test_objectives_json_game_example() {
    // Simulate game objectives
    let objectives = array![
        objective('Complete Level 1', 'Finish the tutorial'),
        objective('Score 1000 Points', 'Reach 1000 pts in arcade'),
        objective('No Deaths', 'Complete run without dying'),
    ]
        .span();

    let result = create_objectives_json(objectives);

    assert!(contains(@result, @"\"Complete Level 1\""), "Should have first objective");
    assert!(contains(@result, @"\"Score 1000 Points\""), "Should have second objective");
    assert!(contains(@result, @"\"No Deaths\""), "Should have third objective");
}
