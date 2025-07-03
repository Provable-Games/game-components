#[cfg(test)]
mod tests {
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_token::libs::lifecycle::LifecycleTrait;

    #[test]
    fn test_token_metadata_default() {
        let metadata = TokenMetadata {
            game_id: 0,
            minted_at: 1000,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 100,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };

        assert!(metadata.game_id == 0, "Default game_id should be 0");
        assert!(metadata.minted_at == 1000, "Minted_at should be set correctly");
        assert!(metadata.settings_id == 0, "Default settings_id should be 0");
        assert!(!metadata.soulbound, "Default should not be soulbound");
        assert!(!metadata.game_over, "Game should not be over initially");
        assert!(!metadata.completed_all_objectives, "Objectives should not be completed initially");
        assert!(!metadata.has_context, "Should not have context initially");
        assert!(metadata.objectives_count == 0, "Default objectives count should be 0");
    }

    #[test]
    fn test_token_metadata_soulbound() {
        let metadata = TokenMetadata {
            game_id: 1,
            minted_at: 2000,
            settings_id: 5,
            lifecycle: Lifecycle { start: 1000, end: 3000 },
            minted_by: 200,
            soulbound: true,
            game_over: false,
            completed_all_objectives: false,
            has_context: true,
            objectives_count: 3,
        };

        assert!(metadata.soulbound, "Should be marked as soulbound");
        assert!(metadata.has_context, "Should have context");
        assert!(metadata.objectives_count == 3, "Should have 3 objectives");
        assert!(metadata.game_id == 1, "Game ID should be 1");
        assert!(metadata.settings_id == 5, "Settings ID should be 5");
    }

    #[test]
    fn test_token_metadata_completed_game() {
        let metadata = TokenMetadata {
            game_id: 1,
            minted_at: 1500,
            settings_id: 1,
            lifecycle: Lifecycle { start: 1000, end: 2000 },
            minted_by: 300,
            soulbound: false,
            game_over: true,
            completed_all_objectives: true,
            has_context: false,
            objectives_count: 5,
        };

        assert!(metadata.game_over, "Game should be over");
        assert!(metadata.completed_all_objectives, "All objectives should be completed");
        assert!(metadata.objectives_count == 5, "Should have 5 objectives");
    }

    #[test]
    fn test_lifecycle_edge_cases() {
        // Test edge case: start and end are the same
        let lifecycle_same = Lifecycle { start: 1000, end: 1000 };
        assert!(!lifecycle_same.is_playable(1000), "Should not be playable when start == end");
        assert!(lifecycle_same.has_expired(1000), "Should be expired when current time == end");
        assert!(lifecycle_same.can_start(1000), "Should be able to start when current time == start");

        // Test edge case: start > end (invalid lifecycle)
        let lifecycle_invalid = Lifecycle { start: 2000, end: 1000 };
        assert!(!lifecycle_invalid.is_playable(1500), "Invalid lifecycle should not be playable");
        assert!(lifecycle_invalid.has_expired(1500), "Invalid lifecycle should be expired");
        assert!(!lifecycle_invalid.can_start(500), "Invalid lifecycle should not start early");

        // Test edge case: start == 0, end == 0 (no lifecycle restrictions)
        let lifecycle_unrestricted = Lifecycle { start: 0, end: 0 };
        assert!(lifecycle_unrestricted.is_playable(0), "Unrestricted lifecycle should be playable at 0");
        assert!(lifecycle_unrestricted.is_playable(1000), "Unrestricted lifecycle should be playable at any time");
        assert!(lifecycle_unrestricted.is_playable(999999), "Unrestricted lifecycle should be playable at large times");
        assert!(lifecycle_unrestricted.can_start(0), "Unrestricted lifecycle can start at 0");
        assert!(!lifecycle_unrestricted.has_expired(999999), "Unrestricted lifecycle should never expire");
    }

    #[test]
    fn test_lifecycle_boundary_conditions() {
        let lifecycle = Lifecycle { start: 100, end: 200 };
        
        // Test exact boundary conditions
        assert!(!lifecycle.is_playable(99), "Should not be playable just before start");
        assert!(lifecycle.is_playable(100), "Should be playable exactly at start");
        assert!(lifecycle.is_playable(150), "Should be playable in the middle");
        assert!(lifecycle.is_playable(199), "Should be playable just before end");
        assert!(!lifecycle.is_playable(200), "Should not be playable exactly at end");
        assert!(!lifecycle.is_playable(201), "Should not be playable after end");

        // Test can_start boundary conditions
        assert!(!lifecycle.can_start(99), "Should not be able to start before start time");
        assert!(lifecycle.can_start(100), "Should be able to start exactly at start time");
        assert!(lifecycle.can_start(150), "Should be able to start after start time");

        // Test has_expired boundary conditions
        assert!(!lifecycle.has_expired(199), "Should not be expired just before end");
        assert!(lifecycle.has_expired(200), "Should be expired exactly at end time");
        assert!(lifecycle.has_expired(201), "Should be expired after end time");
    }

    #[test]
    fn test_metadata_field_combinations() {
        // Test metadata with various field combinations
        
        // Case 1: Soulbound + completed objectives + game over
        let metadata1 = TokenMetadata {
            game_id: 10,
            minted_at: 5000,
            settings_id: 15,
            lifecycle: Lifecycle { start: 4000, end: 6000 },
            minted_by: 500,
            soulbound: true,
            game_over: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: 10,
        };

        assert!(metadata1.soulbound && metadata1.game_over && metadata1.completed_all_objectives, 
                "Should be soulbound, game over, and objectives completed");
        assert!(metadata1.has_context && metadata1.objectives_count == 10, 
                "Should have context and 10 objectives");

        // Case 2: Non-soulbound + incomplete objectives + ongoing game
        let metadata2 = TokenMetadata {
            game_id: 20,
            minted_at: 3000,
            settings_id: 0,
            lifecycle: Lifecycle { start: 2000, end: 8000 },
            minted_by: 600,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 3,
        };

        assert!(!metadata2.soulbound && !metadata2.game_over && !metadata2.completed_all_objectives,
                "Should not be soulbound, game not over, objectives not completed");
        assert!(!metadata2.has_context && metadata2.objectives_count == 3,
                "Should not have context but have 3 objectives");
    }

    #[test]
    fn test_large_values() {
        // Test with large numeric values
        let max_u64 = 18446744073709551615_u64; // 2^64 - 1
        let large_u32 = 4294967295_u32; // 2^32 - 1
        let max_u8 = 255_u8; // 2^8 - 1
        
        let metadata = TokenMetadata {
            game_id: max_u64,
            minted_at: max_u64,
            settings_id: large_u32,
            lifecycle: Lifecycle { start: max_u64 - 1000, end: max_u64 },
            minted_by: max_u64,
            soulbound: true,
            game_over: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: max_u8,
        };

        assert!(metadata.game_id == max_u64, "Should handle max u64 for game_id");
        assert!(metadata.minted_at == max_u64, "Should handle max u64 for minted_at");
        assert!(metadata.settings_id == large_u32, "Should handle max u32 for settings_id");
        assert!(metadata.objectives_count == max_u8, "Should handle max u8 for objectives_count");
        assert!(metadata.lifecycle.end == max_u64, "Should handle max u64 for lifecycle end");
    }

    #[test]
    fn test_zero_values() {
        // Test with zero values
        let metadata = TokenMetadata {
            game_id: 0,
            minted_at: 0,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 0,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };

        assert!(metadata.game_id == 0, "Should handle zero game_id");
        assert!(metadata.minted_at == 0, "Should handle zero minted_at");
        assert!(metadata.settings_id == 0, "Should handle zero settings_id");
        assert!(metadata.objectives_count == 0, "Should handle zero objectives_count");
        assert!(metadata.lifecycle.start == 0 && metadata.lifecycle.end == 0, "Should handle zero lifecycle");
    }

    #[test]
    fn test_objective_count_consistency() {
        // Test that objectives_count accurately reflects the game state
        
        // No objectives case
        let metadata_none = TokenMetadata {
            game_id: 1,
            minted_at: 1000,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 100,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false, // Should be false when count is 0
            has_context: false,
            objectives_count: 0,
        };

        assert!(!metadata_none.completed_all_objectives, "Should not complete objectives when count is 0");

        // Multiple objectives case  
        let metadata_multi = TokenMetadata {
            game_id: 1,
            minted_at: 1000,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 100,
            soulbound: false,
            game_over: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: 7,
        };

        assert!(metadata_multi.completed_all_objectives && metadata_multi.objectives_count > 0,
                "Should complete all objectives when count > 0 and marked as completed");
    }
}