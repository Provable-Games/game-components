// Pure Cairo library for lifecycle management
// Contains logic for validating and checking lifecycle constraints

use crate::structs::Lifecycle;

pub trait LifecycleTrait {
    fn has_expired(self: @Lifecycle, current_time: u64) -> bool;
    fn can_start(self: @Lifecycle, current_time: u64) -> bool;
    fn is_playable(self: @Lifecycle, current_time: u64) -> bool;
    fn validate(self: @Lifecycle);
}

pub impl LifecycleImpl of LifecycleTrait {
    /// Checks if the lifecycle has expired (current time >= end time)
    /// Returns false if end is 0 (no expiration)
    fn has_expired(self: @Lifecycle, current_time: u64) -> bool {
        if *self.end == 0 {
            false
        } else {
            current_time >= *self.end
        }
    }

    /// Checks if the lifecycle can start (current time >= start time)
    /// Returns true if start is 0 (no start constraint)
    fn can_start(self: @Lifecycle, current_time: u64) -> bool {
        if *self.start == 0 {
            true
        } else {
            current_time >= *self.start
        }
    }

    /// Checks if the lifecycle is currently playable
    /// Must have started and not expired
    fn is_playable(self: @Lifecycle, current_time: u64) -> bool {
        self.can_start(current_time) && !self.has_expired(current_time)
    }

    /// Validates the lifecycle configuration
    /// Panics if start > end (when end != 0)
    fn validate(self: @Lifecycle) {
        if *self.end != 0 && *self.start > *self.end {
            panic!("Lifecycle: Start time cannot be greater than end time");
        }
    }
}
