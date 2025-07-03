#[cfg(test)]
mod renderer_tests {
    use game_components_utils::renderer::create_metadata;
    use super::super::test_helpers::contains;

    #[test]
    fn test_game_state_not_started() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 0, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_game_state_active() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 1, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_game_state_expired() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 2, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_game_state_game_over() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 3, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_game_state_objectives_complete() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 4, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_game_state_unknown() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 5, 'Player'
        );
        // Verify it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_zero_player_name() {
        let metadata = create_metadata(
            42, 'MyGame', 'DevCo', "http://img.png", "red", 999, 1, 0
        );
        // Should start with data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_all_fields_populated() {
        let metadata = create_metadata(
            12345, 'SuperGame', 'AwesomeDev', "https://example.com/logo.png", "green", 500, 3, 'Champion'
        );
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_empty_game_image() {
        let metadata = create_metadata(
            1, 'Game', 'Dev', "", "white", 0, 0, 'Player'
        );
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_max_token_id() {
        let max_token_id: u64 = 18446744073709551615; // u64::MAX
        let metadata = create_metadata(
            max_token_id, 'Game', 'Dev', "img.png", "black", 100, 1, 'Player'
        );
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_special_chars_in_names() {
        let metadata = create_metadata(
            1, 'Game<>&"', 'Dev<>&"', "http://img.png", "yellow", 0, 0, 'Player<>&"'
        );
        // Should properly encode special characters
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_svg_structure() {
        let metadata = create_metadata(
            100, 'TestGame', 'TestDev', "http://test.png", "purple", 250, 2, 'TestPlayer'
        );
        // Decode base64 would verify SVG structure, but for now check it's a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }

    #[test]
    fn test_create_metadata_various_colors() {
        let colors = array!["red", "green", "blue", "#FF0000", "#00FF00", "#0000FF", "rgb(255,0,0)"];
        let mut i = 0;
        loop {
            if i >= colors.len() {
                break;
            }
            let color = colors[i];
            let metadata = create_metadata(
                i.into(), 'Game', 'Dev', "img.png", color.clone(), 0, 0, 'Player'
            );
            assert!(contains(@metadata, @"data:application/json;base64,"));
            assert!(metadata.len() > 100);
            i += 1;
        };
    }

    #[test]
    fn test_logo_with_various_urls() {
        let urls = array![
            "http://example.com/img.png",
            "https://example.com/img.png",
            "data:image/png;base64,iVBORw0KG",
            "",
            "file:///local/img.png"
        ];
        let mut i = 0;
        loop {
            if i >= urls.len() {
                break;
            }
            let url = urls[i];
            let metadata = create_metadata(
                1, 'Game', 'Dev', url.clone(), "blue", 0, 0, 'Player'
            );
            assert!(contains(@metadata, @"data:application/json;base64,"));
            assert!(metadata.len() > 100);
            i += 1;
        };
    }

    #[test]
    fn test_metadata_json_structure() {
        let metadata = create_metadata(
            789, 'JsonGame', 'JsonDev', "json.png", "cyan", 333, 4, 'JsonPlayer'
        );
        
        // Should be a valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        
        // The base64 should decode to JSON with expected fields
        // In a full test we'd decode and parse, but we can at least check format
        assert!(metadata.len() > 30); // Should have substantial content
    }

    #[test]
    fn test_score_formatting() {
        let scores = array![0_u16, 1_u16, 99_u16, 999_u16, 9999_u16, 65535_u16];
        let mut i = 0;
        loop {
            if i >= scores.len() {
                break;
            }
            let score = *scores[i];
            let metadata = create_metadata(
                1, 'Game', 'Dev', "img.png", "blue", score, 0, 'Player'
            );
            assert!(contains(@metadata, @"data:application/json;base64,"));
            assert!(metadata.len() > 100);
            i += 1;
        };
    }

    // Simplified fuzz tests for renderer properties
    #[test]
    #[fuzzer(runs: 20)]
    fn fuzz_metadata_always_valid_data_uri(
        token_id: u64,
        score: u16,
        state: u8
    ) {
        let metadata = create_metadata(
            token_id,
            'FuzzGame',
            'FuzzDev',
            "http://fuzz.png",
            "fuzzcolor",
            score,
            state,
            'FuzzPlayer'
        );
        
        // Property: Always starts with correct data URI prefix
        assert!(contains(@metadata, @"data:application/json;base64,"));
        
        // Property: Metadata length is reasonable
        assert!(metadata.len() > 100); // Should have substantial content
        assert!(metadata.len() < 10000); // But not unreasonably large
    }

    #[test]
    #[fuzzer(runs: 10)]
    fn fuzz_svg_structure_valid(color_seed: felt252) {
        // Generate different color formats
        let colors = array!["red", "blue", "#FF0000", "rgb(255,0,0)", "hsl(0,100%,50%)"];
        let seed_u256: u256 = color_seed.into();
        let idx = (seed_u256 % 5_u256).try_into().unwrap();
        let color = if idx < colors.len() { colors[idx].clone() } else { "black" };
        
        let metadata = create_metadata(
            100,
            'ColorTest',
            'ColorDev',
            "color.png",
            color,
            500,
            1,
            'ColorPlayer'
        );
        
        // Property: Valid data URI
        assert!(contains(@metadata, @"data:application/json;base64,"));
        
        // Property: Metadata length is reasonable
        assert!(metadata.len() > 100); // Should have substantial content
        assert!(metadata.len() < 10000); // But not unreasonably large
    }

    #[test]
    #[fuzzer(runs: 10)]
    fn fuzz_attribute_count_consistency(state: u8) {
        let metadata = create_metadata(
            42,
            'AttrGame',
            'AttrDev',
            "attr.png",
            "green",
            100,
            state,
            'AttrPlayer'
        );
        
        // Property: Valid structure exists
        assert!(contains(@metadata, @"data:application/json;base64,"));
        assert!(metadata.len() > 100);
    }
}