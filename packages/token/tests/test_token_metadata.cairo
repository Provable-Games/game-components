#[cfg(test)]
mod tests {
    use game_components_token::structs::{TokenMetadata, Lifecycle};
    use game_components_token::libs::lifecycle::LifecycleTrait;

    #[test]
    fn test_token_metadata_default() {
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
        
        assert!(metadata.game_id == 0, "Game ID should be 0");
        assert!(!metadata.game_over, "Game should not be over");
        assert!(!metadata.completed_all_objectives, "Objectives should not be completed");
        assert!(!metadata.soulbound, "Should not be soulbound");
        assert!(metadata.objectives_count == 0, "Should have 0 objectives");
    }

    #[test]
    #[fuzzer(runs: 50)]
    fn test_token_metadata_fuzz(
        game_id: u64,
        minted_at: u64,
        settings_id: u32,
        start: u64,
        end: u64,
        minted_by: u64,
        objectives_count: u8
    ) {
        let metadata = TokenMetadata {
            game_id,
            minted_at,
            settings_id,
            lifecycle: Lifecycle { start, end },
            minted_by,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count,
        };
        
        // Test metadata fields retain their values
        assert!(metadata.game_id == game_id, "Game ID mismatch");
        assert!(metadata.minted_at == minted_at, "Minted at mismatch");
        assert!(metadata.settings_id == settings_id, "Settings ID mismatch");
        assert!(metadata.lifecycle.start == start, "Start time mismatch");
        assert!(metadata.lifecycle.end == end, "End time mismatch");
        assert!(metadata.minted_by == minted_by, "Minted by mismatch");
        assert!(metadata.objectives_count == objectives_count, "Objectives count mismatch");
    }

    #[test]
    fn test_metadata_with_lifecycle() {
        let lifecycle = Lifecycle { start: 1000, end: 2000 };
        
        let metadata = TokenMetadata {
            game_id: 42,
            minted_at: 999,
            settings_id: 5,
            lifecycle,
            minted_by: 123,
            soulbound: true,
            game_over: false,
            completed_all_objectives: false,
            has_context: true,
            objectives_count: 3,
        };
        
        // Verify lifecycle is properly stored
        assert!(metadata.lifecycle.start == 1000, "Start time should be 1000");
        assert!(metadata.lifecycle.end == 2000, "End time should be 2000");
        
        // Test playability at different times
        assert!(!metadata.lifecycle.is_playable(999), "Should not be playable before start");
        assert!(metadata.lifecycle.is_playable(1500), "Should be playable in window");
        assert!(!metadata.lifecycle.is_playable(2001), "Should not be playable after end");
    }

    #[test]
    fn test_soulbound_metadata() {
        let soulbound_token = TokenMetadata {
            game_id: 1,
            minted_at: 100,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 456,
            soulbound: true,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };
        
        assert!(soulbound_token.soulbound, "Token should be soulbound");
        
        let regular_token = TokenMetadata {
            game_id: 2,
            minted_at: 200,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 789,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };
        
        assert!(!regular_token.soulbound, "Token should not be soulbound");
    }

    #[test]
    fn test_objectives_metadata() {
        // Test with no objectives
        let no_objectives = TokenMetadata {
            game_id: 1,
            minted_at: 100,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 111,
            soulbound: false,
            game_over: false,
            completed_all_objectives: false,
            has_context: false,
            objectives_count: 0,
        };
        
        assert!(no_objectives.objectives_count == 0, "Should have no objectives");
        assert!(!no_objectives.completed_all_objectives, "Should not have completed objectives");
        
        // Test with objectives
        let with_objectives = TokenMetadata {
            game_id: 2,
            minted_at: 200,
            settings_id: 1,
            lifecycle: Lifecycle { start: 0, end: 0 },
            minted_by: 222,
            soulbound: false,
            game_over: false,
            completed_all_objectives: true,
            has_context: false,
            objectives_count: 5,
        };
        
        assert!(with_objectives.objectives_count == 5, "Should have 5 objectives");
        assert!(with_objectives.completed_all_objectives, "Should have completed all objectives");
    }
}