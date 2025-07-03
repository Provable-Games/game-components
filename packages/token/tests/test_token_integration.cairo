#[cfg(test)]
mod tests {
    use snforge_std::start_cheat_block_timestamp_global;
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_token::libs::lifecycle::LifecycleTrait;

    #[test]
    fn test_token_lifecycle_integration() {
        // Test token lifecycle with time progression
        let block_time = 1000_u64;
        start_cheat_block_timestamp_global(block_time);
        
        let lifecycle = Lifecycle {
            start: block_time + 100,
            end: block_time + 500
        };
        
        // Test before start
        assert!(!lifecycle.is_playable(block_time), "Should not be playable before start");
        
        // Test at start
        assert!(lifecycle.is_playable(block_time + 100), "Should be playable at start");
        
        // Test during window
        assert!(lifecycle.is_playable(block_time + 300), "Should be playable during window");
        
        // Test at end
        assert!(!lifecycle.is_playable(block_time + 500), "Should not be playable at end");
    }

    #[test]
    fn test_metadata_state_transitions() {
        // Test how metadata changes through game lifecycle
        let mut metadata = TokenMetadata {
            game_id: 1,
            minted_at: 500,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 100,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };
        
        // Initial state
        assert!(!metadata.game_over, "Game should not be over initially");
        assert!(!metadata.completed_all_objectives, "Objectives should not be completed initially");
        
        // Simulate objectives completion
        metadata.completed_all_objectives = true;
        assert!(metadata.completed_all_objectives, "Objectives should be marked as completed");
        
        // Simulate game over
        metadata.game_over = true;
        assert!(metadata.game_over, "Game should be marked as over");
    }

    #[test]
    #[fuzzer(runs: 20)]
    fn test_game_state_fuzz(
        game_id: u64,
        minted_at: u64,
        minted_by: u64,
        objectives_count: u8
    ) {
        // Test various game state combinations
        let metadata = TokenMetadata {
            game_id,
            minted_at,
            settings_id: 0,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count,
        };
        
        // Verify fields are stored correctly
        assert!(metadata.game_id == game_id, "Game ID mismatch");
        assert!(metadata.minted_at == minted_at, "Minted at mismatch");
        assert!(metadata.minted_by == minted_by, "Minted by mismatch");
        assert!(metadata.objectives_count == objectives_count, "Objectives count mismatch");
    }

    #[test]
    fn test_edge_case_values() {
        // Test with maximum values
        let max_metadata = TokenMetadata {
            game_id: core::num::traits::Bounded::<u64>::MAX,
            minted_at: core::num::traits::Bounded::<u64>::MAX,
            settings_id: core::num::traits::Bounded::<u32>::MAX,
            lifecycle: Lifecycle { 
                start: core::num::traits::Bounded::<u64>::MAX,
                end: core::num::traits::Bounded::<u64>::MAX
            },
            minted_by: core::num::traits::Bounded::<u64>::MAX,
            soulbound: true,
            game_over: true,
            completed_all_objectives: true,
            has_context: true,
            objectives_count: core::num::traits::Bounded::<u8>::MAX,
        };
        
        assert!(max_metadata.game_id == core::num::traits::Bounded::<u64>::MAX, "Max game ID");
        assert!(max_metadata.objectives_count == 255, "Max objectives count should be 255");
        
        // Test with zero values
        let zero_metadata = TokenMetadata {
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
        
        assert!(zero_metadata.game_id == 0, "Zero game ID");
        assert!(zero_metadata.objectives_count == 0, "Zero objectives count");
        
        // Verify lifecycle with no restrictions
        assert!(zero_metadata.lifecycle.is_playable(12345), "Should be playable with no restrictions");
    }
}