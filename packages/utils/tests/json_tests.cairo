#[cfg(test)]
mod json_tests {
    use game_components_utils::json::{
        create_settings_json, create_objectives_json, create_context_json, create_json_array
    };
    use game_components_minigame::extensions::settings::structs::GameSetting;
    use game_components_minigame::extensions::objectives::structs::GameObjective;
    use game_components_metagame::extensions::context::structs::GameContext;
    use super::super::test_helpers::contains;

    #[test]
    fn test_create_settings_json_empty() {
        let settings: Span<GameSetting> = array![].span();
        let result = create_settings_json("", "", settings);
        assert!(result.len() > 0);
        assert!(contains(@result, @"Name"));
        assert!(contains(@result, @"Description"));
        assert!(contains(@result, @"Settings"));
    }

    #[test]
    fn test_create_settings_json_normal() {
        let settings = array![
            GameSetting { name: "difficulty", value: "hard" },
            GameSetting { name: "max_players", value: "4" },
        ].span();
        let result = create_settings_json("Test Game", "A test game", settings);
        assert!(contains(@result, @"Test Game"));
        assert!(contains(@result, @"A test game"));
        assert!(contains(@result, @"difficulty"));
        assert!(contains(@result, @"hard"));
        assert!(contains(@result, @"max_players"));
        assert!(contains(@result, @"4"));
    }

    #[test]
    fn test_create_settings_json_special_chars() {
        let settings = array![
            GameSetting { name: "quote\"test", value: "value\"with\"quotes" },
        ].span();
        let result = create_settings_json("Name\"Quote", "Desc\"Quote", settings);
        assert!(result.len() > 0);
        // Should contain escaped quotes
        assert!(contains(@result, @"\""));
    }

    #[test]
    fn test_create_objectives_json_empty() {
        let objectives: Span<GameObjective> = array![].span();
        let result = create_objectives_json(objectives);
        assert!(result == "{}");
    }

    #[test]
    fn test_create_objectives_json_multiple() {
        let objectives = array![
            GameObjective { name: "Score 100", value: "100" },
            GameObjective { name: "Complete Level", value: "1" },
            GameObjective { name: "Collect Items", value: "50" },
        ].span();
        let result = create_objectives_json(objectives);
        assert!(contains(@result, @"Score 100"));
        assert!(contains(@result, @"100"));
        assert!(contains(@result, @"Complete Level"));
        assert!(contains(@result, @"1"));
        assert!(contains(@result, @"Collect Items"));
        assert!(contains(@result, @"50"));
    }

    #[test]
    fn test_create_objectives_json_duplicate_names() {
        let objectives = array![
            GameObjective { name: "Score", value: "100" },
            GameObjective { name: "Score", value: "200" },
        ].span();
        let result = create_objectives_json(objectives);
        // Last value should win
        assert!(contains(@result, @"200"));
    }

    #[test]
    fn test_create_context_json_none_id() {
        let contexts = array![
            GameContext { name: "World", value: "Earth" },
        ].span();
        let result = create_context_json("Game", "Description", Option::None, contexts);
        assert!(contains(@result, @"Game"));
        assert!(contains(@result, @"Description"));
        assert!(contains(@result, @"World"));
        assert!(contains(@result, @"Earth"));
        // Should not contain Context Id
        assert!(!contains(@result, @"Context Id"));
    }

    #[test]
    fn test_create_context_json_some_zero() {
        let contexts = array![].span();
        let result = create_context_json("Game", "Desc", Option::Some(0), contexts);
        assert!(contains(@result, @"Context Id"));
        assert!(contains(@result, @"0"));
    }

    #[test]
    fn test_create_context_json_some_max() {
        let contexts = array![].span();
        let result = create_context_json("Game", "Desc", Option::Some(4294967295), contexts);
        assert!(contains(@result, @"Context Id"));
        assert!(contains(@result, @"4294967295"));
    }

    #[test]
    fn test_create_json_array_empty() {
        let values: Span<ByteArray> = array![].span();
        let result = create_json_array(values);
        assert!(result == "[]");
    }

    #[test]
    fn test_create_json_array_single() {
        let values = array!["value"].span();
        let result = create_json_array(values);
        assert!(result == "[\"value\"]");
    }

    #[test]
    fn test_create_json_array_multiple() {
        let values = array!["first", "second", "third"].span();
        let result = create_json_array(values);
        assert!(result == "[\"first\",\"second\",\"third\"]");
    }

    #[test]
    fn test_create_json_array_with_quotes() {
        let values = array!["has\"quote", "normal", "also\"has\"quotes"].span();
        let result = create_json_array(values);
        assert!(contains(@result, @"has\"quote"));
        assert!(contains(@result, @"normal"));
        assert!(contains(@result, @"also\"has\"quotes"));
        // Should have proper comma separation
        assert!(contains(@result, @","));
    }

    // Fuzz tests for JSON properties
    #[test]
    #[fuzzer(runs: 50)]
    fn fuzz_json_array_structure(size: u8) {
        // Create array of random size (limited for performance)
        let actual_size = size % 20; // Limit to 20 elements
        let mut values = ArrayTrait::new();
        let mut i = 0;
        loop {
            if i >= actual_size {
                break;
            }
            values.append(format!("value_{}", i));
            i += 1;
        };
        
        let result = create_json_array(values.span());
        
        // Property: Always starts with [ and ends with ]
        if actual_size == 0 {
            assert!(result == "[]");
        } else {
            assert!(result.len() >= 2);
            assert!(result[0] == '[');
            assert!(result[result.len() - 1] == ']');
            
            // Property: Has correct number of commas
            let mut comma_count = 0;
            let mut j = 0;
            loop {
                if j >= result.len() {
                    break;
                }
                if result[j] == ',' {
                    comma_count += 1;
                }
                j += 1;
            };
            assert!(comma_count == if actual_size > 0 { actual_size - 1 } else { 0 });
        }
    }

    #[test]
    #[fuzzer(runs: 50)]
    fn fuzz_context_id_presence(id: u32) {
        let contexts: Span<GameContext> = array![].span();
        
        // Test with Some(id)
        let result_some = create_context_json("Test", "Desc", Option::Some(id), contexts);
        assert!(contains(@result_some, @"Context Id"));
        assert!(contains(@result_some, @format!("{}", id)));
        
        // Test with None
        let result_none = create_context_json("Test", "Desc", Option::None, contexts);
        assert!(!contains(@result_none, @"Context Id"));
    }

    #[test]
    #[fuzzer(runs: 30)]
    fn fuzz_special_chars_escaping(seed: felt252) {
        // Generate strings with potential special characters
        let chars = array!['"', '\\', '\n', '\t', '\r'];
        let seed_u256: u256 = seed.into();
        let idx = (seed_u256 % 5_u256).try_into().unwrap();
        let special_char = if idx < chars.len() { *chars[idx] } else { '"' };
        
        let name = format!("Name{}Special", special_char);
        let value = format!("Value{}Test", special_char);
        
        let settings = array![
            GameSetting { name: name.clone(), value: value.clone() }
        ].span();
        
        let result = create_settings_json("Game", "Desc", settings);
        
        // Property: Result should be valid JSON (contains expected structure)
        assert!(contains(@result, @"Name"));
        assert!(contains(@result, @"Description"));
        assert!(contains(@result, @"Settings"));
        
        // Should handle special characters without breaking JSON structure
        assert!(result.len() > 0);
    }
}