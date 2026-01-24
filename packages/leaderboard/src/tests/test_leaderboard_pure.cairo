// ==============================================================================
// LEADERBOARD PURE LIBRARY TESTS
// ==============================================================================
// Tests for the pure Cairo leaderboard library functions without storage dependencies.
// These tests cover the core leaderboard operations, score comparisons, and utilities.

use game_components_leaderboard::leaderboard::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardOperationsImpl, LeaderboardResult,
    LeaderboardUtilsImpl, ScoreComparatorImpl,
};
use game_components_testing::constants::{MAX_U32, MAX_U64};

// ==============================================================================
// EMPTY LEADERBOARD TESTS
// ==============================================================================

#[test]
fn test_empty_leaderboard_insertion() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let entries = LeaderboardUtilsImpl::new();
    let new_entry = LeaderboardEntry { id: 1, score: 100 };

    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Should insert at position 0 in empty leaderboard");

    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 0,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert into empty leaderboard"),
    }
    assert!(updated.len() == 1, "Leaderboard should have 1 entry");
    assert!(*updated.at(0).id == 1, "Entry should have correct ID");
}

#[test]
fn test_new_leaderboard_is_empty() {
    let entries = LeaderboardUtilsImpl::new();
    assert!(entries.len() == 0, "New leaderboard should be empty");
}

// ==============================================================================
// ORDERING TESTS (DESCENDING - HIGHER IS BETTER)
// ==============================================================================

#[test]
fn test_leaderboard_ordering_descending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    let new_entry = LeaderboardEntry { id: 4, score: 90 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "Should insert at position 1");

    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 1,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert"),
    }
    assert!(*updated.at(0).score == 100, "First should be 100");
    assert!(*updated.at(1).score == 90, "Second should be 90");
    assert!(*updated.at(2).score == 80, "Third should be 80");
    assert!(*updated.at(3).score == 60, "Fourth should be 60");
}

#[test]
fn test_insert_at_beginning_descending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    let new_entry = LeaderboardEntry { id: 3, score: 150 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Should insert at position 0 (highest score)");

    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 0);
    assert!(*updated.at(0).score == 150, "First should be 150");
    assert!(*updated.at(1).score == 100, "Second should be 100");
    assert!(*updated.at(2).score == 80, "Third should be 80");
}

#[test]
fn test_insert_at_end_descending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    let new_entry = LeaderboardEntry { id: 3, score: 50 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(2), "Should insert at position 2 (end)");

    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 2);
    assert!(*updated.at(0).score == 100, "First should be 100");
    assert!(*updated.at(1).score == 80, "Second should be 80");
    assert!(*updated.at(2).score == 50, "Third should be 50");
}

// ==============================================================================
// ORDERING TESTS (ASCENDING - LOWER IS BETTER)
// ==============================================================================

#[test]
fn test_leaderboard_ordering_ascending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });
    entries.append(LeaderboardEntry { id: 3, score: 30 });

    let new_entry = LeaderboardEntry { id: 4, score: 15 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "Should insert at position 1");

    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 1,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert"),
    }
    assert!(*updated.at(0).score == 10, "First should be 10");
    assert!(*updated.at(1).score == 15, "Second should be 15");
    assert!(*updated.at(2).score == 20, "Third should be 20");
    assert!(*updated.at(3).score == 30, "Fourth should be 30");
}

#[test]
fn test_insert_at_beginning_ascending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    let new_entry = LeaderboardEntry { id: 3, score: 5 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Should insert at position 0 (lowest score)");

    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 0);
    assert!(*updated.at(0).score == 5, "First should be 5");
    assert!(*updated.at(1).score == 10, "Second should be 10");
    assert!(*updated.at(2).score == 20, "Third should be 20");
}

// ==============================================================================
// MAX ENTRIES TESTS
// ==============================================================================

#[test]
fn test_leaderboard_max_entries() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Try to insert a low score - should fail
    let new_entry = LeaderboardEntry { id: 4, score: 50 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 3);
    match result {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should return LeaderboardFull"),
    }

    // Insert a high score - should succeed and drop lowest
    let high_entry = LeaderboardEntry { id: 5, score: 90 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @high_entry, 1,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert high score"),
    }
    assert!(updated.len() == 3, "Should maintain max entries");
    assert!(*updated.at(2).score == 80, "Lowest score should be 80 (60 was dropped)");
}

#[test]
fn test_leaderboard_exactly_at_max() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Add third entry to reach max
    let third_entry = LeaderboardEntry { id: 3, score: 60 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @third_entry, 2,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert third entry"),
    }
    assert!(updated.len() == 3, "Should have exactly 3 entries");
}

// ==============================================================================
// TIE BREAKING TESTS
// ==============================================================================

#[test]
fn test_tie_breaking() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 2, score: 100 });

    let new_entry = LeaderboardEntry { id: 1, score: 100 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Lower ID should win tie");

    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 0);
    assert!(*updated.at(0).id == 1, "ID 1 should be first");
    assert!(*updated.at(1).id == 2, "ID 2 should be second");
}

#[test]
fn test_tie_breaking_higher_id_loses() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    // ID 2 with same score should go after ID 1
    let new_entry = LeaderboardEntry { id: 2, score: 100 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "Higher ID should lose tie");

    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 1);
    assert!(*updated.at(0).id == 1, "ID 1 should be first");
    assert!(*updated.at(1).id == 2, "ID 2 should be second");
}

// ==============================================================================
// DUPLICATE ENTRY TESTS
// ==============================================================================

#[test]
fn test_duplicate_entry_prevention() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    let duplicate = LeaderboardEntry { id: 1, score: 200 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @duplicate, 0);
    match result {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Should prevent duplicate entries"),
    }
}

#[test]
fn test_contains_entry() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    assert!(LeaderboardOperationsImpl::contains_entry(@entries, 1), "Should contain ID 1");
    assert!(LeaderboardOperationsImpl::contains_entry(@entries, 2), "Should contain ID 2");
    assert!(!LeaderboardOperationsImpl::contains_entry(@entries, 3), "Should not contain ID 3");
}

// ==============================================================================
// POSITION VALIDATION TESTS
// ==============================================================================

#[test]
fn test_position_validation() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // Try to insert at invalid position (gap)
    let new_entry = LeaderboardEntry { id: 3, score: 75 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 3);
    match result {
        LeaderboardResult::InvalidPosition => {},
        _ => panic!("Should return InvalidPosition for gap"),
    }

    // Try to insert with wrong score for position
    let wrong_score = LeaderboardEntry { id: 4, score: 40 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @wrong_score, 0);
    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Should return ScoreTooLow"),
    }
}

#[test]
fn test_score_too_high_validation() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // Try to insert a score that's too high for position 2 (should be before position 1)
    let new_entry = LeaderboardEntry { id: 3, score: 120 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 2);
    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Should return ScoreTooHigh"),
    }
}

// ==============================================================================
// UTILITY FUNCTION TESTS
// ==============================================================================

#[test]
fn test_utils_functions() {
    // Test position/index conversion
    assert!(
        LeaderboardUtilsImpl::position_to_index(1) == Option::Some(0),
        "Position 1 should be index 0",
    );
    assert!(
        LeaderboardUtilsImpl::position_to_index(0) == Option::None, "Position 0 should be None",
    );
    assert!(
        LeaderboardUtilsImpl::index_to_position(0) == Option::Some(1),
        "Index 0 should be position 1",
    );
    assert!(
        LeaderboardUtilsImpl::index_to_position(254) == Option::Some(255),
        "Index 254 should be position 255",
    );
    assert!(
        LeaderboardUtilsImpl::index_to_position(255) == Option::None,
        "Index 255 should be None (overflow)",
    );

    // Test get_top_n
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    let top_2 = LeaderboardUtilsImpl::get_top_n(@entries, 2);
    assert!(top_2.len() == 2, "Should return 2 entries");
    assert!(*top_2.at(0).score == 100, "First should be 100");
    assert!(*top_2.at(1).score == 80, "Second should be 80");
}

#[test]
fn test_get_range() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 90 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });
    entries.append(LeaderboardEntry { id: 4, score: 70 });
    entries.append(LeaderboardEntry { id: 5, score: 60 });

    // Get middle range
    let range = LeaderboardUtilsImpl::get_range(@entries, 1, 3);
    assert!(range.len() == 3, "Should return 3 entries");
    assert!(*range.at(0).id == 2, "First should be ID 2");
    assert!(*range.at(1).id == 3, "Second should be ID 3");
    assert!(*range.at(2).id == 4, "Third should be ID 4");

    // Get range beyond end
    let range_end = LeaderboardUtilsImpl::get_range(@entries, 3, 10);
    assert!(range_end.len() == 2, "Should return only 2 entries (4 and 5)");
}

#[test]
fn test_is_full() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    assert!(!LeaderboardUtilsImpl::is_full(@config, @entries), "Should not be full with 2 entries");

    entries.append(LeaderboardEntry { id: 3, score: 60 });
    assert!(LeaderboardUtilsImpl::is_full(@config, @entries), "Should be full with 3 entries");
}

#[test]
fn test_get_qualifying_score() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Not full - any score qualifies
    let qualifying = LeaderboardUtilsImpl::get_qualifying_score(@config, @entries);
    assert!(qualifying == Option::None, "Should return None when not full");

    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Full - need to beat last entry
    let qualifying = LeaderboardUtilsImpl::get_qualifying_score(@config, @entries);
    assert!(qualifying == Option::Some(60), "Should return 60 as qualifying score");
}

#[test]
fn test_get_entry_position() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    let pos1 = LeaderboardOperationsImpl::get_entry_position(@entries, 1);
    assert!(pos1 == Option::Some(0), "ID 1 should be at position 0");

    let pos2 = LeaderboardOperationsImpl::get_entry_position(@entries, 2);
    assert!(pos2 == Option::Some(1), "ID 2 should be at position 1");

    let pos3 = LeaderboardOperationsImpl::get_entry_position(@entries, 3);
    assert!(pos3 == Option::Some(2), "ID 3 should be at position 2");

    let pos_none = LeaderboardOperationsImpl::get_entry_position(@entries, 999);
    assert!(pos_none == Option::None, "Non-existent ID should return None");
}

#[test]
fn test_qualifies_for_leaderboard() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Not full - any score qualifies
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 10),
        "Any score qualifies when not full",
    );

    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Full - need to beat last entry
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 70),
        "70 should qualify (beats 60)",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 50),
        "50 should not qualify (less than 60)",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 60),
        "60 should not qualify (equal, not better)",
    );
}

// ==============================================================================
// SCORE COMPARATOR TESTS
// ==============================================================================

#[test]
fn test_is_better_score_descending() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };

    assert!(config.is_better_score(100, 50), "100 should be better than 50 (descending)");
    assert!(!config.is_better_score(50, 100), "50 should not be better than 100 (descending)");
    assert!(!config.is_better_score(100, 100), "Equal scores - not better");
}

#[test]
fn test_is_better_score_ascending() {
    let config = LeaderboardConfig { max_entries: 10, ascending: true, allow_ties: true };

    assert!(config.is_better_score(50, 100), "50 should be better than 100 (ascending)");
    assert!(!config.is_better_score(100, 50), "100 should not be better than 50 (ascending)");
    assert!(!config.is_better_score(100, 100), "Equal scores - not better");
}

#[test]
fn test_is_equal_score() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };

    assert!(config.is_equal_score(100, 100), "100 should equal 100");
    assert!(!config.is_equal_score(100, 50), "100 should not equal 50");
}

// ==============================================================================
// LARGE LEADERBOARD TEST
// ==============================================================================

#[test]
fn test_50_player_leaderboard() {
    let config = LeaderboardConfig { max_entries: 50, ascending: false, allow_ties: true };
    let mut entries = LeaderboardUtilsImpl::new();

    // Insert 50 players with descending scores (player 1 = score 50, player 50 = score 1)
    let mut i: u32 = 1;
    loop {
        if i > 50 {
            break;
        }

        let score = 51 - i; // Score from 50 down to 1
        let new_entry = LeaderboardEntry { id: i.into(), score };

        // Find correct position and insert
        let position = LeaderboardOperationsImpl::find_insert_position(
            @config, @entries, @new_entry,
        );

        let pos_idx = match position {
            Option::Some(p) => p,
            Option::None => panic!("Should find a valid position"),
        };

        let (updated, result) = LeaderboardOperationsImpl::insert_entry(
            @config, @entries, @new_entry, pos_idx,
        );

        match result {
            LeaderboardResult::Success => {},
            _ => panic!("Should successfully insert entry"),
        }

        entries = updated;
        i += 1;
    }

    // Verify leaderboard has 50 entries
    assert!(entries.len() == 50, "Leaderboard should have 50 entries");

    // Verify first place has highest score (50)
    let first_entry = entries.at(0);
    assert!(*first_entry.score == 50, "First place should have score 50");
    assert!(*first_entry.id == 1, "First place should have ID 1");

    // Verify last place has lowest score (1)
    let last_entry = entries.at(49);
    assert!(*last_entry.score == 1, "Last place (position 50) should have score 1");
    assert!(*last_entry.id == 50, "Last place should have ID 50");

    // Verify middle entry (position 25)
    let middle_entry = entries.at(24);
    assert!(*middle_entry.score == 26, "Position 25 should have score 26");
    assert!(*middle_entry.id == 25, "Position 25 should have ID 25");

    // Verify ordering is correct throughout
    let mut j: u32 = 0;
    loop {
        if j >= 49 {
            break;
        }
        let current = entries.at(j);
        let next = entries.at(j + 1);
        assert!(*current.score >= *next.score, "Scores should be in descending order");
        j += 1;
    };
}

// ==============================================================================
// ADDITIONAL SCORE COMPARATOR TESTS
// ==============================================================================

#[test]
fn test_is_equal_score_first_lower() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };

    assert!(!config.is_equal_score(50, 100), "50 should not equal 100");
}

#[test]
fn test_break_tie_same_id() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };

    let entry1 = LeaderboardEntry { id: 1, score: 100 };
    let entry2 = LeaderboardEntry { id: 1, score: 100 };

    // Same ID should not win against itself
    assert!(!config.break_tie(@entry1, @entry2), "Same ID should not win tiebreaker");
}

#[test]
fn test_break_tie_large_id_difference() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };

    let entry1 = LeaderboardEntry { id: 1, score: 100 };
    let entry2 = LeaderboardEntry { id: MAX_U64, score: 100 };

    assert!(config.break_tie(@entry1, @entry2), "Lower ID (1) should win against MAX_U64");
    assert!(!config.break_tie(@entry2, @entry1), "MAX_U64 should lose against lower ID");
}

// ==============================================================================
// ADDITIONAL ASCENDING MODE TESTS
// ==============================================================================

#[test]
fn test_ascending_insert_at_end_worst() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    // In ascending mode, higher score is worse
    let new_entry = LeaderboardEntry { id: 3, score: 30 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(2), "Worst score should insert at end");
}

#[test]
fn test_ascending_qualifies_lower_score() {
    let config = LeaderboardConfig { max_entries: 3, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });
    entries.append(LeaderboardEntry { id: 3, score: 30 });

    // In ascending mode, lower than last (30) qualifies
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 25),
        "25 should qualify (lower than 30)",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 35),
        "35 should not qualify (higher than 30)",
    );
}

// ==============================================================================
// CONTAINS ENTRY EDGE CASES
// ==============================================================================

#[test]
fn test_contains_entry_middle() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 5, score: 80 });
    entries.append(LeaderboardEntry { id: 10, score: 60 });

    assert!(LeaderboardOperationsImpl::contains_entry(@entries, 5), "Should contain ID 5 (middle)");
}

#[test]
fn test_contains_entry_last() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 999, score: 60 });

    assert!(
        LeaderboardOperationsImpl::contains_entry(@entries, 999), "Should contain ID 999 (last)",
    );
}

#[test]
fn test_contains_entry_empty() {
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    assert!(
        !LeaderboardOperationsImpl::contains_entry(@entries, 1), "Empty should not contain any",
    );
}

// ==============================================================================
// GET ENTRY POSITION EDGE CASES
// ==============================================================================

#[test]
fn test_get_entry_position_empty_leaderboard() {
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    let pos = LeaderboardOperationsImpl::get_entry_position(@entries, 1);
    assert!(pos == Option::None, "Empty leaderboard should return None");
}

// ==============================================================================
// UTILITY FUNCTION EDGE CASES
// ==============================================================================

#[test]
fn test_position_to_index_max() {
    // Position 255 (max u8) should be index 254
    assert!(
        LeaderboardUtilsImpl::position_to_index(255) == Option::Some(254),
        "Position 255 should be index 254",
    );
}

#[test]
fn test_position_to_index_middle() {
    assert!(
        LeaderboardUtilsImpl::position_to_index(128) == Option::Some(127),
        "Position 128 should be index 127",
    );
}

#[test]
fn test_index_to_position_large() {
    // Index 1000 should return None (overflow)
    assert!(
        LeaderboardUtilsImpl::index_to_position(1000) == Option::None,
        "Index 1000 should return None",
    );
}

#[test]
fn test_get_range_from_beginning() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 90 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });
    entries.append(LeaderboardEntry { id: 4, score: 70 });

    let range = LeaderboardUtilsImpl::get_range(@entries, 0, 3);
    assert!(range.len() == 3, "Should return 3 entries");
    assert!(*range.at(0).id == 1, "First should be ID 1");
    assert!(*range.at(2).id == 3, "Third should be ID 3");
}

#[test]
fn test_get_range_start_beyond_length() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    let range = LeaderboardUtilsImpl::get_range(@entries, 100, 5);
    assert!(range.len() == 0, "Start beyond length should return empty");
}

#[test]
fn test_get_range_count_zero() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    let range = LeaderboardUtilsImpl::get_range(@entries, 0, 0);
    assert!(range.len() == 0, "Count 0 should return empty");
}

#[test]
fn test_get_top_n_more_than_available() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    let top = LeaderboardUtilsImpl::get_top_n(@entries, 100);
    assert!(top.len() == 2, "Should return all available entries");
}

#[test]
fn test_get_top_n_zero() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    let top = LeaderboardUtilsImpl::get_top_n(@entries, 0);
    assert!(top.len() == 0, "Top 0 should return empty");
}

#[test]
fn test_get_top_n_one() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    let top = LeaderboardUtilsImpl::get_top_n(@entries, 1);
    assert!(top.len() == 1, "Top 1 should return 1 entry");
    assert!(*top.at(0).score == 100, "Should be highest score");
}

#[test]
fn test_is_full_empty() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    assert!(!LeaderboardUtilsImpl::is_full(@config, @entries), "Empty should not be full");
}

#[test]
fn test_is_full_over_capacity() {
    let config = LeaderboardConfig { max_entries: 2, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 90 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });
    entries.append(LeaderboardEntry { id: 4, score: 70 });

    assert!(LeaderboardUtilsImpl::is_full(@config, @entries), "Over capacity should be full");
}

#[test]
fn test_get_qualifying_score_single_entry_full() {
    let config = LeaderboardConfig { max_entries: 1, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    let qualifying = LeaderboardUtilsImpl::get_qualifying_score(@config, @entries);
    assert!(qualifying == Option::Some(100), "Should return the single entry's score");
}

// ==============================================================================
// BOUNDARY VALUE TESTS
// ==============================================================================

#[test]
fn test_max_score_value() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: MAX_U32 });

    let new_entry = LeaderboardEntry { id: 2, score: MAX_U32 - 1 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "Should insert after MAX_U32 score");
}

#[test]
fn test_max_token_id() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    let new_entry = LeaderboardEntry { id: MAX_U64, score: 100 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 0,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert MAX_U64 id"),
    }
    assert!(*updated.at(0).id == MAX_U64, "Should store MAX_U64 id");
}

#[test]
fn test_single_entry_leaderboard() {
    let config = LeaderboardConfig { max_entries: 1, ascending: false, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    // Insert first
    let entry1 = LeaderboardEntry { id: 1, score: 100 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @entry1, 0);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("First insert should succeed"),
    }
    assert!(updated.len() == 1, "Should have 1 entry");

    // Try to insert lower score - should fail
    let entry2 = LeaderboardEntry { id: 2, score: 50 };
    let (_, result2) = LeaderboardOperationsImpl::insert_entry(@config, @updated, @entry2, 1);
    match result2 {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should be LeaderboardFull for low score"),
    }

    // Insert higher score - should succeed and replace
    let entry3 = LeaderboardEntry { id: 3, score: 200 };
    let (final_board, result3) = LeaderboardOperationsImpl::insert_entry(
        @config, @updated, @entry3, 0,
    );
    match result3 {
        LeaderboardResult::Success => {},
        _ => panic!("Higher score should succeed"),
    }
    assert!(final_board.len() == 1, "Should maintain size 1");
    assert!(*final_board.at(0).id == 3, "Should be the new higher scorer");
}

// ==============================================================================
// VALIDATION TESTS
// ==============================================================================

#[test]
fn test_validate_tie_wins_tiebreaker() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 2, score: 100 });

    // Entry with lower ID (1) at same score should win tiebreaker at position 0
    let new_entry = LeaderboardEntry { id: 1, score: 100 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 0);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Lower ID should win tiebreaker"),
    }
}

#[test]
fn test_validate_tie_loses_tiebreaker() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });

    // Entry with higher ID (2) at same score should lose tiebreaker at position 0
    let new_entry = LeaderboardEntry { id: 2, score: 100 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 0);
    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Higher ID should lose tiebreaker"),
    }
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

#[test]
#[fuzzer]
fn test_fuzz_insert_random_score(score: u32, id_seed: u64) {
    // Ensure non-zero ID
    let id = if id_seed == 0 {
        1
    } else {
        id_seed
    };

    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    let new_entry = LeaderboardEntry { id, score };

    // Empty leaderboard - should always find position 0
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Empty leaderboard should give position 0");

    // Insert should succeed
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 0,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Insert into empty should succeed"),
    }
    assert!(updated.len() == 1, "Should have 1 entry after insert");
}

#[test]
#[fuzzer]
fn test_fuzz_is_better_score_transitivity(a: u32, b: u32, c: u32) {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };

    // If a > b and b > c, then a > c (transitivity in descending mode)
    if config.is_better_score(a, b) && config.is_better_score(b, c) {
        assert!(config.is_better_score(a, c), "Score comparison should be transitive");
    }
}

#[test]
#[fuzzer]
fn test_fuzz_position_index_roundtrip(position: u8) {
    // Skip position 0 (invalid)
    if position == 0 {
        return;
    }

    // Convert position to index
    match LeaderboardUtilsImpl::position_to_index(position) {
        Option::Some(index) => {
            // Convert back to position
            match LeaderboardUtilsImpl::index_to_position(index) {
                Option::Some(back_position) => {
                    assert!(back_position == position, "Roundtrip should preserve position");
                },
                Option::None => { panic!("Should convert back to position"); },
            }
        },
        Option::None => { panic!("Valid position should convert to index"); },
    }
}

#[test]
#[fuzzer]
fn test_fuzz_find_position_validity(score: u32) {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    let new_entry = LeaderboardEntry { id: 100, score };

    match LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry) {
        Option::Some(pos) => {
            // Position should be <= entries.len()
            assert!(pos <= entries.len(), "Position should be valid");
        },
        Option::None => { panic!("Should always find a position"); },
    }
}

#[test]
#[fuzzer]
fn test_fuzz_qualifies_consistency(score: u32) {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    let qualifies = LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, score);

    // If qualifies is true, score must be > 60
    if qualifies {
        assert!(score > 60, "If qualifies, score must beat last entry");
    } else {
        assert!(score <= 60, "If not qualifies, score must not beat last entry");
    }
}

// ==============================================================================
// ADDITIONAL VALIDATION TESTS
// ==============================================================================

#[test]
fn test_validate_position_score_too_high_vs_above() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // Try to insert score 120 at position 1 (between 100 and 50)
    // But 120 > 100, so it should be at position 0, not 1
    let new_entry = LeaderboardEntry { id: 3, score: 120 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 1);
    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Should return ScoreTooHigh when score beats entry above"),
    }
}

#[test]
fn test_validate_position_equal_score_tiebreaker_above() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 5, score: 100 });

    // Entry with lower ID at same score trying to go to position 1 (after position 0)
    // Lower ID should be ahead, so this is "too high" for position 1
    let new_entry = LeaderboardEntry { id: 1, score: 100 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 1);
    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Lower ID with same score should be ScoreTooHigh at position 1"),
    }
}

#[test]
fn test_validate_position_success_at_end() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Insert at position 2 (end) with score lower than last
    let new_entry = LeaderboardEntry { id: 3, score: 60 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 2);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed inserting lower score at end"),
    }
}

#[test]
fn test_insert_entry_failure_returns_cloned_array() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Invalid insertion (duplicate)
    let duplicate = LeaderboardEntry { id: 1, score: 150 };
    let (returned_entries, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @duplicate, 0,
    );

    match result {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Should return DuplicateEntry"),
    }

    // Returned array should be a clone of original
    assert!(returned_entries.len() == 2, "Should return original array length");
    assert!(*returned_entries.at(0).id == 1, "First entry should be preserved");
    assert!(*returned_entries.at(1).id == 2, "Second entry should be preserved");
}

#[test]
fn test_find_insert_position_middle_of_list() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });
    entries.append(LeaderboardEntry { id: 4, score: 40 });

    // Find position for score 70 (between 80 and 60)
    let new_entry = LeaderboardEntry { id: 5, score: 70 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(2), "Should insert at position 2");
}

#[test]
fn test_find_insert_position_with_ties_throughout() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 3, score: 100 });
    entries.append(LeaderboardEntry { id: 5, score: 100 });

    // ID 2 with same score should go after ID 1, before ID 3
    let new_entry = LeaderboardEntry { id: 2, score: 100 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "ID 2 should be at position 1");

    // ID 4 with same score should go after ID 3, before ID 5
    let new_entry2 = LeaderboardEntry { id: 4, score: 100 };
    let position2 = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry2);
    assert!(position2 == Option::Some(2), "ID 4 should be at position 2");
}

#[test]
fn test_ascending_validate_position_score_too_low() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    // In ascending mode, try to insert score 25 at position 0
    // Score 25 is worse than 10, so it shouldn't be at position 0
    let new_entry = LeaderboardEntry { id: 3, score: 25 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 0);
    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("In ascending mode, higher score at position 0 should be ScoreTooLow"),
    }
}

#[test]
fn test_ascending_validate_position_score_too_high() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    // In ascending mode, try to insert score 5 at position 2
    // Score 5 is better than 20, so it should be higher, not at position 2
    let new_entry = LeaderboardEntry { id: 3, score: 5 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 2);
    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("In ascending mode, lower score at end should be ScoreTooHigh"),
    }
}

#[test]
fn test_insert_at_max_capacity_drops_last() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Insert at position 1, should drop entry at position 2
    let new_entry = LeaderboardEntry { id: 4, score: 90 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 1,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    assert!(updated.len() == 3, "Should maintain max entries");
    assert!(*updated.at(0).id == 1, "First should be ID 1");
    assert!(*updated.at(1).id == 4, "Second should be ID 4 (new)");
    assert!(*updated.at(2).id == 2, "Third should be ID 2 (ID 3 dropped)");
}

#[test]
fn test_qualifies_ascending_full() {
    let config = LeaderboardConfig { max_entries: 3, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });
    entries.append(LeaderboardEntry { id: 3, score: 30 });

    // In ascending, need to beat 30 (have lower score)
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 25),
        "25 should qualify (< 30)",
    );
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 1),
        "1 should qualify (< 30)",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 30),
        "30 should not qualify (= 30)",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 40),
        "40 should not qualify (> 30)",
    );
}

#[test]
fn test_get_qualifying_score_ascending() {
    let config = LeaderboardConfig { max_entries: 3, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });
    entries.append(LeaderboardEntry { id: 3, score: 30 });

    let qualifying = LeaderboardUtilsImpl::get_qualifying_score(@config, @entries);
    assert!(qualifying == Option::Some(30), "Qualifying score should be 30 (last entry)");
}

#[test]
fn test_contains_entry_first_element() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 42, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    assert!(LeaderboardOperationsImpl::contains_entry(@entries, 42), "Should find first element");
}

#[test]
fn test_get_entry_position_first() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 42, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    let pos = LeaderboardOperationsImpl::get_entry_position(@entries, 42);
    assert!(pos == Option::Some(0), "First entry should be at index 0");
}

#[test]
fn test_get_entry_position_last() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 42, score: 60 });

    let pos = LeaderboardOperationsImpl::get_entry_position(@entries, 42);
    assert!(pos == Option::Some(2), "Last entry should be at index 2");
}

#[test]
fn test_insert_preserves_order_complex() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 90 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });
    entries.append(LeaderboardEntry { id: 4, score: 70 });

    // Insert at position 2
    let new_entry = LeaderboardEntry { id: 5, score: 85 };
    let (updated, _) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 2);

    assert!(updated.len() == 5, "Should have 5 entries");
    assert!(*updated.at(0).score == 100, "Position 0: 100");
    assert!(*updated.at(1).score == 90, "Position 1: 90");
    assert!(*updated.at(2).score == 85, "Position 2: 85 (new)");
    assert!(*updated.at(3).score == 80, "Position 3: 80");
    assert!(*updated.at(4).score == 70, "Position 4: 70");
}

#[test]
fn test_zero_score_handling() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // Insert zero score at end
    let new_entry = LeaderboardEntry { id: 3, score: 0 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 2,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Zero score should be valid"),
    }

    assert!(*updated.at(2).score == 0, "Zero score should be stored");
}

#[test]
fn test_ascending_zero_score_is_best() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    // In ascending mode, 0 is the best possible score
    let new_entry = LeaderboardEntry { id: 1, score: 0 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Zero should be at position 0 in empty ascending");
}

#[test]
fn test_multiple_insertions_maintain_invariant() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries: Array<LeaderboardEntry> = ArrayTrait::new();

    // Insert in random order
    let new1 = LeaderboardEntry { id: 3, score: 50 };
    let pos1 = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new1);
    let (updated1, _) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new1, pos1.unwrap(),
    );
    entries = updated1;

    let new2 = LeaderboardEntry { id: 1, score: 100 };
    let pos2 = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new2);
    let (updated2, _) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new2, pos2.unwrap(),
    );
    entries = updated2;

    let new3 = LeaderboardEntry { id: 2, score: 75 };
    let pos3 = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new3);
    let (updated3, _) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new3, pos3.unwrap(),
    );
    entries = updated3;

    // Verify sorted order maintained
    assert!(*entries.at(0).score == 100, "First should be 100");
    assert!(*entries.at(1).score == 75, "Second should be 75");
    assert!(*entries.at(2).score == 50, "Third should be 50");
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS
// ==============================================================================

#[test]
fn test_validate_position_at_beginning_with_entries() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Valid insertion at position 0 with highest score
    let new_entry = LeaderboardEntry { id: 3, score: 120 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 0);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed inserting highest score at position 0"),
    }
}

#[test]
fn test_validate_position_equal_score_same_position() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 2, score: 100 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });

    // Insert with same score as position 0, lower ID wins
    let new_entry = LeaderboardEntry { id: 1, score: 100 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 0);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Lower ID should win tiebreaker at position 0"),
    }
}

#[test]
fn test_find_position_ascending_best_score() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });
    entries.append(LeaderboardEntry { id: 3, score: 30 });

    // Score 5 is best in ascending (lowest)
    let new_entry = LeaderboardEntry { id: 4, score: 5 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Best ascending score should go to position 0");
}

#[test]
fn test_find_position_ascending_worst_score() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    // Score 100 is worst in ascending (highest)
    let new_entry = LeaderboardEntry { id: 3, score: 100 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(2), "Worst ascending score should go to end");
}

#[test]
fn test_insert_truncates_at_max() {
    let config = LeaderboardConfig { max_entries: 2, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Insert at position 0, should truncate last
    let new_entry = LeaderboardEntry { id: 3, score: 150 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 0,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    assert!(updated.len() == 2, "Should maintain max 2");
    assert!(*updated.at(0).id == 3, "New entry at 0");
    assert!(*updated.at(1).id == 1, "Old first now at 1");
    // ID 2 should be dropped
}

#[test]
fn test_insert_copy_loop_boundary() {
    let config = LeaderboardConfig { max_entries: 4, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Insert at last position
    let new_entry = LeaderboardEntry { id: 4, score: 40 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 3,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed inserting at end"),
    }

    assert!(updated.len() == 4, "Should have 4 entries");
    assert!(*updated.at(3).id == 4, "New entry at last position");
}

#[test]
fn test_qualifies_empty_leaderboard() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    // Any score qualifies for empty leaderboard
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 0),
        "0 qualifies for empty",
    );
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, MAX_U32),
        "MAX qualifies for empty",
    );
}

#[test]
fn test_get_range_partial_at_end() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 90 });
    entries.append(LeaderboardEntry { id: 3, score: 80 });

    // Get range starting near end
    let range = LeaderboardUtilsImpl::get_range(@entries, 2, 10);
    assert!(range.len() == 1, "Should return only 1 entry at end");
    assert!(*range.at(0).id == 3, "Should be last entry");
}

#[test]
fn test_get_top_n_empty() {
    let entries: Array<LeaderboardEntry> = ArrayTrait::new();

    let top = LeaderboardUtilsImpl::get_top_n(@entries, 5);
    assert!(top.len() == 0, "Empty should return empty");
}

#[test]
fn test_is_full_exactly_max() {
    let config = LeaderboardConfig { max_entries: 2, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    assert!(LeaderboardUtilsImpl::is_full(@config, @entries), "Should be full at exactly max");
}

#[test]
fn test_position_to_index_boundary() {
    // Test various position values
    assert!(LeaderboardUtilsImpl::position_to_index(1) == Option::Some(0), "Pos 1 -> idx 0");
    assert!(LeaderboardUtilsImpl::position_to_index(2) == Option::Some(1), "Pos 2 -> idx 1");
    assert!(LeaderboardUtilsImpl::position_to_index(100) == Option::Some(99), "Pos 100 -> idx 99");
}

#[test]
fn test_index_to_position_boundary() {
    assert!(LeaderboardUtilsImpl::index_to_position(0) == Option::Some(1), "Idx 0 -> pos 1");
    assert!(LeaderboardUtilsImpl::index_to_position(99) == Option::Some(100), "Idx 99 -> pos 100");
    assert!(
        LeaderboardUtilsImpl::index_to_position(253) == Option::Some(254), "Idx 253 -> pos 254",
    );
}

#[test]
fn test_validate_leaderboard_full_beyond_max() {
    let config = LeaderboardConfig { max_entries: 2, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Try to insert at position >= max_entries
    let new_entry = LeaderboardEntry { id: 3, score: 50 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 2);
    match result {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should return LeaderboardFull when inserting at max position"),
    }
}

#[test]
fn test_ascending_ties_tiebreaker() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // In ascending mode, ID 1 (lower) with same score should go first
    let new_entry = LeaderboardEntry { id: 1, score: 50 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(0), "Lower ID wins tiebreaker in ascending too");
}

#[test]
fn test_get_qualifying_score_one_entry() {
    let config = LeaderboardConfig { max_entries: 1, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 50 });

    let qual = LeaderboardUtilsImpl::get_qualifying_score(@config, @entries);
    assert!(qual == Option::Some(50), "Qualifying score should be 50");
}

#[test]
fn test_insert_middle_position_shift() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 60 });
    entries.append(LeaderboardEntry { id: 3, score: 40 });

    // Insert at middle position
    let new_entry = LeaderboardEntry { id: 4, score: 80 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 1,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed at middle"),
    }

    assert!(updated.len() == 4, "Should have 4 entries");
    assert!(*updated.at(0).score == 100, "First unchanged");
    assert!(*updated.at(1).score == 80, "New entry at 1");
    assert!(*updated.at(2).score == 60, "Old 1 shifted to 2");
    assert!(*updated.at(3).score == 40, "Old 2 shifted to 3");
}

#[test]
fn test_contains_entry_single() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 42, score: 100 });

    assert!(LeaderboardOperationsImpl::contains_entry(@entries, 42), "Should find single entry");
    assert!(!LeaderboardOperationsImpl::contains_entry(@entries, 1), "Should not find other");
}

#[test]
fn test_find_position_all_same_scores_descending() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 50 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });
    entries.append(LeaderboardEntry { id: 4, score: 50 });

    // ID 3 should go between ID 2 and ID 4
    let new_entry = LeaderboardEntry { id: 3, score: 50 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(2), "ID 3 should be at position 2 (between 2 and 4)");
}

#[test]
fn test_validate_duplicate_in_middle() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 5, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Try to insert duplicate of middle entry
    let new_entry = LeaderboardEntry { id: 5, score: 90 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 1);
    match result {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Should detect duplicate even in middle"),
    }
}

#[test]
fn test_validate_duplicate_at_end() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    // Try to insert duplicate of last entry
    let new_entry = LeaderboardEntry { id: 2, score: 50 };
    let result = LeaderboardOperationsImpl::validate_position(@config, @entries, @new_entry, 2);
    match result {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Should detect duplicate at end"),
    }
}

#[test]
#[fuzzer]
fn test_fuzz_is_full_consistency(max_entries: u32, num_entries: u32) {
    // Limit entries to reasonable size
    let bounded_max = if max_entries > 100 {
        max_entries % 100 + 1
    } else if max_entries == 0 {
        1
    } else {
        max_entries
    };
    let bounded_num = num_entries % 101;

    let config = LeaderboardConfig { max_entries: bounded_max, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();

    let mut i: u32 = 0;
    loop {
        if i >= bounded_num {
            break;
        }
        entries.append(LeaderboardEntry { id: i.into(), score: 100 - i });
        i += 1;
    }

    let is_full = LeaderboardUtilsImpl::is_full(@config, @entries);

    if entries.len() >= bounded_max {
        assert!(is_full, "Should be full when entries >= max");
    } else {
        assert!(!is_full, "Should not be full when entries < max");
    }
}

#[test]
#[fuzzer]
fn test_fuzz_get_top_n_bounds(n: u32) {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    let top = LeaderboardUtilsImpl::get_top_n(@entries, n);

    // Result should never exceed original length
    assert!(top.len() <= entries.len(), "Top N should not exceed entries");
    // Result should be min(n, entries.len())
    if n <= entries.len() {
        assert!(top.len() == n, "Should return n entries");
    } else {
        assert!(top.len() == entries.len(), "Should return all entries");
    }
}
