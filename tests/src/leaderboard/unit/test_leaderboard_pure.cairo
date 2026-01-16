// ==============================================================================
// LEADERBOARD PURE LIBRARY TESTS
// ==============================================================================
// Tests for the pure Cairo leaderboard library functions without storage dependencies.
// These tests cover the core leaderboard operations, score comparisons, and utilities.

use game_components_leaderboard::leaderboard::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardOperationsImpl, LeaderboardResult,
    LeaderboardUtilsImpl, ScoreComparatorImpl,
};

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
