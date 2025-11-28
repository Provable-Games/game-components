use game_components_token::structs::Lifecycle;
use game_components_token::libs::LifecycleTrait;
use core::num::traits::Bounded;

// ================================================================================================
// LIFECYCLE TESTS (UT-LIFE-*)
// ================================================================================================

#[test]
fn test_has_expired_with_various_timestamps() { // UT-LIFE-001
    // Test with no end time (never expires)
    let lifecycle1 = Lifecycle { start: 0, end: 0 };
    assert!(!lifecycle1.has_expired(100), "Should not expire when end is 0");
    assert!(!lifecycle1.has_expired(Bounded::<u64>::MAX), "Should not expire when end is 0");

    // Test with future end time
    let lifecycle2 = Lifecycle { start: 100, end: 200 };
    assert!(!lifecycle2.has_expired(100), "Should not expire at start time");
    assert!(!lifecycle2.has_expired(150), "Should not expire before end");
    assert!(!lifecycle2.has_expired(199), "Should not expire one second before end");

    // Test at exact end time
    assert!(lifecycle2.has_expired(200), "Should expire at exact end time");

    // Test after end time
    assert!(lifecycle2.has_expired(201), "Should expire after end time");
    assert!(lifecycle2.has_expired(1000), "Should expire well after end time");

    // Test with Bounded::<u64>::MAX
    let lifecycle3 = Lifecycle { start: 0, end: Bounded::<u64>::MAX };
    assert!(
        !lifecycle3.has_expired(Bounded::<u64>::MAX - 1),
        "Should not expire before Bounded::<u64>::MAX",
    );
    assert!(lifecycle3.has_expired(Bounded::<u64>::MAX), "Should expire at Bounded::<u64>::MAX");
}

#[test]
fn test_can_start_with_various_timestamps() { // UT-LIFE-002
    // Test with no start time (can always start)
    let lifecycle1 = Lifecycle { start: 0, end: 0 };
    assert!(lifecycle1.can_start(0), "Should start when start is 0");
    assert!(lifecycle1.can_start(100), "Should start when start is 0");
    assert!(lifecycle1.can_start(Bounded::<u64>::MAX), "Should start when start is 0");

    // Test with future start time
    let lifecycle2 = Lifecycle { start: 100, end: 200 };
    assert!(!lifecycle2.can_start(50), "Should not start before start time");
    assert!(!lifecycle2.can_start(99), "Should not start one second before start");

    // Test at exact start time
    assert!(lifecycle2.can_start(100), "Should start at exact start time");

    // Test after start time
    assert!(lifecycle2.can_start(101), "Should start after start time");
    assert!(lifecycle2.can_start(150), "Should start well after start time");
    assert!(lifecycle2.can_start(200), "Should start even at end time");

    // Test with Bounded::<u64>::MAX
    let lifecycle3 = Lifecycle { start: Bounded::<u64>::MAX, end: 0 };
    assert!(
        !lifecycle3.can_start(Bounded::<u64>::MAX - 1),
        "Should not start before Bounded::<u64>::MAX",
    );
    assert!(lifecycle3.can_start(Bounded::<u64>::MAX), "Should start at Bounded::<u64>::MAX");
}

#[test]
fn test_is_playable_combinations() { // UT-LIFE-003
    // No constraints - always playable
    let lifecycle1 = Lifecycle { start: 0, end: 0 };
    assert!(lifecycle1.is_playable(0), "Should be playable with no constraints");
    assert!(lifecycle1.is_playable(100), "Should be playable with no constraints");
    assert!(lifecycle1.is_playable(Bounded::<u64>::MAX), "Should be playable with no constraints");

    // Only start constraint
    let lifecycle2 = Lifecycle { start: 100, end: 0 };
    assert!(!lifecycle2.is_playable(50), "Should not be playable before start");
    assert!(lifecycle2.is_playable(100), "Should be playable at start");
    assert!(lifecycle2.is_playable(200), "Should be playable after start");

    // Only end constraint
    let lifecycle3 = Lifecycle { start: 0, end: 100 };
    assert!(lifecycle3.is_playable(50), "Should be playable before end");
    assert!(!lifecycle3.is_playable(100), "Should not be playable at end");
    assert!(!lifecycle3.is_playable(200), "Should not be playable after end");

    // Both constraints
    let lifecycle4 = Lifecycle { start: 100, end: 200 };
    assert!(!lifecycle4.is_playable(50), "Should not be playable before start");
    assert!(lifecycle4.is_playable(100), "Should be playable at start");
    assert!(lifecycle4.is_playable(150), "Should be playable in range");
    assert!(!lifecycle4.is_playable(200), "Should not be playable at end");
    assert!(!lifecycle4.is_playable(250), "Should not be playable after end");

    // Edge case: start == end
    let lifecycle5 = Lifecycle { start: 100, end: 100 };
    assert!(!lifecycle5.is_playable(99), "Should not be playable before");
    assert!(!lifecycle5.is_playable(100), "Should not be playable when start==end");
    assert!(!lifecycle5.is_playable(101), "Should not be playable after");
}

#[test]
fn test_boundary_conditions() { // UT-LIFE-004
    // Test Bounded::<u64>::MAX boundaries
    let lifecycle1 = Lifecycle { start: Bounded::<u64>::MAX, end: Bounded::<u64>::MAX };
    assert!(
        !lifecycle1.is_playable(Bounded::<u64>::MAX - 1),
        "Should not be playable before Bounded::<u64>::MAX",
    );
    assert!(
        !lifecycle1.is_playable(Bounded::<u64>::MAX),
        "Should not be playable at Bounded::<u64>::MAX when start==end",
    );

    // Test zero boundaries
    let lifecycle2 = Lifecycle { start: 0, end: 1 };
    assert!(lifecycle2.is_playable(0), "Should be playable at 0");
    assert!(!lifecycle2.is_playable(1), "Should not be playable at 1");

    // Test Bounded::<u64>::MAX - 1 boundaries
    let lifecycle3 = Lifecycle { start: Bounded::<u64>::MAX - 1, end: Bounded::<u64>::MAX };
    assert!(
        !lifecycle3.is_playable(Bounded::<u64>::MAX - 2), "Should not be playable before start",
    );
    assert!(lifecycle3.is_playable(Bounded::<u64>::MAX - 1), "Should be playable at start");
    assert!(!lifecycle3.is_playable(Bounded::<u64>::MAX), "Should not be playable at end");

    // Test large ranges
    let lifecycle4 = Lifecycle { start: 1, end: Bounded::<u64>::MAX - 1 };
    assert!(!lifecycle4.is_playable(0), "Should not be playable before start");
    assert!(lifecycle4.is_playable(1), "Should be playable at start");
    assert!(lifecycle4.is_playable(Bounded::<u64>::MAX / 2), "Should be playable in middle");
    assert!(lifecycle4.is_playable(Bounded::<u64>::MAX - 2), "Should be playable near end");
    assert!(!lifecycle4.is_playable(Bounded::<u64>::MAX - 1), "Should not be playable at end");
}

#[test]
fn test_lifecycle_validate() { // UT-LIFE-005
    // Valid lifecycle - no constraints
    let lifecycle1 = Lifecycle { start: 0, end: 0 };
    lifecycle1.validate(); // Should not panic

    // Valid lifecycle - only start
    let lifecycle2 = Lifecycle { start: 100, end: 0 };
    lifecycle2.validate(); // Should not panic

    // Valid lifecycle - only end
    let lifecycle3 = Lifecycle { start: 0, end: 100 };
    lifecycle3.validate(); // Should not panic

    // Valid lifecycle - start before end
    let lifecycle4 = Lifecycle { start: 100, end: 200 };
    lifecycle4.validate(); // Should not panic

    // Valid lifecycle - start equals end
    let lifecycle5 = Lifecycle { start: 100, end: 100 };
    lifecycle5.validate(); // Should not panic

    // Valid lifecycle - Bounded::<u64>::MAX values
    let lifecycle6 = Lifecycle { start: Bounded::<u64>::MAX - 1, end: Bounded::<u64>::MAX };
    lifecycle6.validate(); // Should not panic
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_lifecycle_validate_invalid() {
    // Invalid lifecycle - start after end
    let lifecycle = Lifecycle { start: 200, end: 100 };
    lifecycle.validate(); // Should panic
}

#[test]
#[should_panic(expected: "Lifecycle: Start time cannot be greater than end time")]
fn test_lifecycle_validate_invalid_edge_case() {
    // Invalid lifecycle - edge case with Bounded::<u64>::MAX
    let lifecycle = Lifecycle { start: Bounded::<u64>::MAX, end: Bounded::<u64>::MAX - 1 };
    lifecycle.validate(); // Should panic
}
