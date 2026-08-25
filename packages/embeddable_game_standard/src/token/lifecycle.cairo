// Lifecycle validation for the standard token.
//
// Pure functions over `Lifecycle` — no storage, no syscalls. The standard
// token's `is_playable` and `assert_lifecycle_open` are built entirely on
// these, which is what makes them zero-storage-read: the window is unpacked
// from the token id and checked here.
//
// This logic lived in `token_legacy::token` until the legacy generation was
// retired. It was never legacy-specific — a lifecycle window means the same
// thing in both generations — it simply had not been brought across during
// the rename. Names are unchanged; only the module path moved.

use game_components_interfaces::structs::token::Lifecycle;

pub trait LifecycleTrait {
    fn has_expired(self: @Lifecycle, current_time: u64) -> bool;
    fn can_start(self: @Lifecycle, current_time: u64) -> bool;
    fn is_playable(self: @Lifecycle, current_time: u64) -> bool;
    fn validate(self: @Lifecycle);
}

pub impl LifecycleImpl of LifecycleTrait {
    /// Expired when current time has reached the end. `end == 0` means the
    /// token never expires.
    fn has_expired(self: @Lifecycle, current_time: u64) -> bool {
        if *self.end == 0 {
            false
        } else {
            current_time >= *self.end
        }
    }

    /// Startable when current time has reached the start. `start == 0` means
    /// there is no start constraint.
    fn can_start(self: @Lifecycle, current_time: u64) -> bool {
        if *self.start == 0 {
            true
        } else {
            current_time >= *self.start
        }
    }

    /// Playable when the window has opened and not yet closed.
    fn is_playable(self: @Lifecycle, current_time: u64) -> bool {
        self.can_start(current_time) && !self.has_expired(current_time)
    }

    /// A window that ends before it starts is not a window.
    fn validate(self: @Lifecycle) {
        if *self.end != 0 && *self.start > *self.end {
            panic!("Lifecycle: Start time cannot be greater than end time");
        }
    }
}

/// Builds a lifecycle from the optional mint parameters, where absent means
/// unconstrained on that end: no start delay, or no expiration.
#[inline(always)]
pub fn create_lifecycle_with_defaults(start: Option<u64>, end: Option<u64>) -> Lifecycle {
    Lifecycle { start: start.unwrap_or(0), end: end.unwrap_or(0) }
}
