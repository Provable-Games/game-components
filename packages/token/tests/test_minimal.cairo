#[cfg(test)]
mod tests {
    use game_components_token::structs::Lifecycle;
    use game_components_token::libs::lifecycle::LifecycleTrait;

    #[test]
    fn test_lifecycle_trait() {
        let lifecycle = Lifecycle { start: 100, end: 200 };
        
        // Test can_start
        assert!(!lifecycle.can_start(50), "Should not start before time");
        assert!(lifecycle.can_start(100), "Should start at time");
        assert!(lifecycle.can_start(150), "Should start after time");
        
        // Test has_expired
        assert!(!lifecycle.has_expired(150), "Should not be expired before end");
        assert!(lifecycle.has_expired(200), "Should be expired at end");
        assert!(lifecycle.has_expired(250), "Should be expired after end");
        
        // Test is_playable
        assert!(!lifecycle.is_playable(50), "Should not be playable before start");
        assert!(lifecycle.is_playable(150), "Should be playable in window");
        assert!(!lifecycle.is_playable(250), "Should not be playable after end");
    }
}