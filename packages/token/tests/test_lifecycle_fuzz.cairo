#[cfg(test)]
mod tests {
    use game_components_token::structs::Lifecycle;
    use game_components_token::libs::lifecycle::LifecycleTrait;
    use core::num::traits::Bounded;

    #[test]
    #[fuzzer(runs: 100)]
    fn test_lifecycle_can_start_fuzz(start: u64, current_time: u64) {
        let lifecycle = Lifecycle { start, end: 0 };
        let can_start = lifecycle.can_start(current_time);
        
        if start == 0 {
            assert!(can_start, "Should always start when start time is 0");
        } else if current_time >= start {
            assert!(can_start, "Should start when current time >= start time");
        } else {
            assert!(!can_start, "Should not start when current time < start time");
        }
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn test_lifecycle_has_expired_fuzz(end: u64, current_time: u64) {
        let lifecycle = Lifecycle { start: 0, end };
        let has_expired = lifecycle.has_expired(current_time);
        
        if end == 0 {
            assert!(!has_expired, "Should never expire when end time is 0");
        } else if current_time >= end {
            assert!(has_expired, "Should expire when current time >= end time");
        } else {
            assert!(!has_expired, "Should not expire when current time < end time");
        }
    }

    #[test]
    #[fuzzer(runs: 100)]
    fn test_lifecycle_is_playable_fuzz(start: u64, end: u64, current_time: u64) {
        let lifecycle = Lifecycle { start, end };
        let is_playable = lifecycle.is_playable(current_time);
        
        let can_start = if start == 0 { true } else { current_time >= start };
        let not_expired = if end == 0 { true } else { current_time < end };
        
        assert!(is_playable == (can_start && not_expired), "Playability should match start and expiry conditions");
    }

    #[test]
    #[fuzzer(runs: 50)]
    fn test_lifecycle_boundary_values(value: u64) {
        // Test with max values
        if value > Bounded::<u64>::MAX / 2 {
            let max_start = Lifecycle { start: Bounded::<u64>::MAX, end: 0 };
            assert!(!max_start.can_start(Bounded::<u64>::MAX - 1), "Should not start before max");
            assert!(max_start.can_start(Bounded::<u64>::MAX), "Should start at max");
            
            let max_end = Lifecycle { start: 0, end: Bounded::<u64>::MAX };
            assert!(!max_end.has_expired(Bounded::<u64>::MAX - 1), "Should not expire before max");
            assert!(max_end.has_expired(Bounded::<u64>::MAX), "Should expire at max");
        }
        
        // Test with zero values
        if value < Bounded::<u64>::MAX / 2 {
            let zero_lifecycle = Lifecycle { start: 0, end: 0 };
            assert!(zero_lifecycle.can_start(value), "Should always start with zero start time");
            assert!(!zero_lifecycle.has_expired(value), "Should never expire with zero end time");
            assert!(zero_lifecycle.is_playable(value), "Should always be playable with no restrictions");
        }
    }
}