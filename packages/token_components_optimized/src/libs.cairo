use crate::structs::Lifecycle;

#[generate_trait]
pub impl LifecycleImpl of LifecycleTrait {
    /// @title Has Expired
    /// @notice Whether the game has expired
    /// @dev If end time is 0, the game will never expire
    /// @return True if the game has expired, false otherwise
    #[inline(always)]
    fn has_expired(self: @Lifecycle, current_time: u64) -> bool {
        if *self.end == 0 {
            false
        } else {
            current_time >= *self.end
        }
    }

    /// @title Can Start
    /// @notice Whether the game can be started
    /// @dev If start time is 0, the game can be started immediately
    /// @return True if the game can be started, false otherwise
    #[inline(always)]
    fn can_start(self: @Lifecycle, current_time: u64) -> bool {
        if *self.start == 0 {
            true
        } else {
            current_time >= *self.start
        }
    }

    /// @title Is Available
    /// @notice Whether the game is available to be played
    /// @dev If no delay or time limit is set, the game is available to be played immediately
    /// @return True if the game is available to be played, false otherwise
    #[inline(always)]
    fn is_playable(self: @Lifecycle, current_time: u64) -> bool {
        self.can_start(current_time) && !self.has_expired(current_time)
    }
}

#[generate_trait]
pub impl LifecycleAssertionsImpl of LifecycleAssertionsTrait {
    #[inline(always)]
    fn assert_not_expired(self: @Lifecycle, game_id: u64, current_time: u64) {
        assert!(!self.has_expired(current_time), "Game {} expired at {}", game_id, *self.end);
    }

    #[inline(always)]
    fn assert_can_start(self: @Lifecycle, game_id: u64, current_time: u64) {
        assert!(
            self.can_start(current_time), "Game {} cannot start until {}", game_id, *self.start,
        );
    }

    #[inline(always)]
    fn assert_is_playable(self: @Lifecycle, game_id: u64, current_time: u64) {
        self.assert_can_start(game_id, current_time);
        self.assert_not_expired(game_id, current_time);
    }
}

#[cfg(test)]
mod tests {
    use super::{LifecycleTrait, LifecycleAssertionsTrait};
    use crate::structs::Lifecycle;
    use core::num::traits::Bounded;

    #[test]
    fn can_start() {
        // Case 1: With explicit start time
        let lifecycle = @Lifecycle { start: 120, end: 0 };
        assert!(!lifecycle.can_start(119), "Should not start before time");
        assert!(lifecycle.can_start(120), "Should start at exact time");
        assert!(lifecycle.can_start(121), "Should start after time");

        // Case 2: No start time (immediate start)
        let no_delay = @Lifecycle { start: 0, end: 0 };
        assert!(no_delay.can_start(100), "Should start immediately");
    }

    #[test]
    fn has_expired() {
        // Case 1: With end time
        let lifecycle = @Lifecycle { start: 0, end: 150 };
        assert!(!lifecycle.has_expired(149), "Should not be expired before time");
        assert!(lifecycle.has_expired(150), "Should be expired at exact time");
        assert!(lifecycle.has_expired(151), "Should be expired after time");

        // Case 2: No end time (never expires)
        let no_limit = @Lifecycle { start: 0, end: 0 };
        assert!(!no_limit.has_expired(Bounded::MAX - 1), "Should never expire");
    }

    #[test]
    fn is_playable() {
        // Case 1: No restrictions
        let no_restrictions = @Lifecycle { start: 0, end: 0 };
        assert!(no_restrictions.is_playable(150), "Should be playable without restrictions");

        // Case 2: Before start time
        let not_started = @Lifecycle { start: 200, end: 0 };
        assert!(!not_started.is_playable(150), "Should not be playable before start");

        // Case 3: After end time
        let expired = @Lifecycle { start: 0, end: 140 };
        assert!(!expired.is_playable(150), "Should not be playable after expiry");

        // Case 4: Within valid window
        let valid = @Lifecycle { start: 120, end: 160 };
        assert!(!valid.is_playable(110), "Should not be playable before start");
        assert!(valid.is_playable(130), "Should be playable in valid window");
        assert!(!valid.is_playable(170), "Should not be playable after end");
    }

    #[test]
    #[should_panic(expected: "Game 1 cannot start until 120")]
    fn assert_can_start() {
        let lifecycle = @Lifecycle { start: 120, end: 0 };
        lifecycle.assert_can_start(1, 110);
    }

    #[test]
    #[should_panic(expected: "Game 1 expired at 150")]
    fn assert_not_expired() {
        let lifecycle = @Lifecycle { start: 0, end: 150 };
        lifecycle.assert_not_expired(1, 151);
    }

    #[test]
    #[should_panic(expected: "Game 1 cannot start until 120")]
    fn assert_is_playable() {
        let lifecycle = @Lifecycle { start: 120, end: 150 };
        lifecycle.assert_is_playable(1, 110);
    }

    #[test]
    fn boundary_conditions() {
        // Test u64 boundaries
        let max_time = @Lifecycle { start: Bounded::MAX, end: 0 };
        assert!(!max_time.can_start(Bounded::MAX - 1), "Should not start before max time");
        assert!(max_time.can_start(Bounded::MAX), "Should start at max time");

        // Test end time at max
        let max_end = @Lifecycle { start: 0, end: Bounded::MAX };
        assert!(
            max_end.is_playable(Bounded::MAX - 1), "Should be playable at one sec before max time",
        );
        assert!(!max_end.is_playable(Bounded::MAX), "Should not be playable at max time");
    }
}
