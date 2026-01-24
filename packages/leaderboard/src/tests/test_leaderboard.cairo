use game_components_leaderboard::leaderboard::leaderboard::{
    LeaderboardConfig, LeaderboardEntry, LeaderboardOperationsImpl, LeaderboardResult,
    LeaderboardUtilsImpl, ScoreComparatorImpl,
};

#[test]
fn test_empty_leaderboard_insertion() {
    let config = LeaderboardConfig { max_entries: 10, ascending: false, allow_ties: true };
    let mut entries = LeaderboardUtilsImpl::new();
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
fn test_leaderboard_max_entries() {
    let config = LeaderboardConfig { max_entries: 3, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });

    // Try to insert a low score
    let new_entry = LeaderboardEntry { id: 4, score: 50 };
    let (_, result) = LeaderboardOperationsImpl::insert_entry(@config, @entries, @new_entry, 3);
    match result {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should return LeaderboardFull"),
    }

    // Insert a high score
    let high_entry = LeaderboardEntry { id: 5, score: 90 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @high_entry, 1,
    );
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully insert high score"),
    }
    assert!(updated.len() == 3, "Should maintain max entries");
    assert!(*updated.at(2).score == 80, "Lowest score should be 80");
}

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
// ASCENDING ORDER TESTS
// ==============================================================================

#[test]
fn test_ascending_leaderboard_insertion() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 30 });

    // Insert score 20 (middle)
    let new_entry = LeaderboardEntry { id: 3, score: 20 };
    let position = LeaderboardOperationsImpl::find_insert_position(@config, @entries, @new_entry);
    assert!(position == Option::Some(1), "Should insert at position 1 in ascending");

    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @new_entry, 1,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    assert!(*updated.at(0).score == 10, "First should be 10");
    assert!(*updated.at(1).score == 20, "Second should be 20");
    assert!(*updated.at(2).score == 30, "Third should be 30");
}

#[test]
fn test_ascending_full_leaderboard_replacement() {
    let config = LeaderboardConfig { max_entries: 2, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 20 });

    // Check that bad score doesn't qualify
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 30),
        "Score 30 shouldn't qualify",
    );

    // Insert a better score (lower in ascending)
    let good_entry = LeaderboardEntry { id: 4, score: 15 };
    let (updated, result) = LeaderboardOperationsImpl::insert_entry(
        @config, @entries, @good_entry, 1,
    );

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    assert!(updated.len() == 2, "Should have 2 entries");
    assert!(*updated.at(0).score == 10, "First should be 10");
    assert!(*updated.at(1).score == 15, "Second should be 15 (20 displaced)");
}

#[test]
fn test_qualifies_descending_full() {
    let config = LeaderboardConfig { max_entries: 2, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 50 });

    // Must beat 50 to qualify
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 60), "60 qualifies",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 50),
        "50 doesn't qualify",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 40),
        "40 doesn't qualify",
    );
}

#[test]
fn test_qualifies_ascending_full() {
    let config = LeaderboardConfig { max_entries: 2, ascending: true, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 10 });
    entries.append(LeaderboardEntry { id: 2, score: 30 });

    // Must beat 30 (be lower) to qualify
    assert!(
        LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 20), "20 qualifies",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 30),
        "30 doesn't qualify",
    );
    assert!(
        !LeaderboardOperationsImpl::qualifies_for_leaderboard(@config, @entries, 40),
        "40 doesn't qualify",
    );
}

#[test]
fn test_is_better_score_descending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };

    assert!(ScoreComparatorImpl::is_better_score(@config, 100, 50), "100 > 50 in descending");
    assert!(!ScoreComparatorImpl::is_better_score(@config, 50, 100), "50 < 100 in descending");
}

#[test]
fn test_is_better_score_ascending() {
    let config = LeaderboardConfig { max_entries: 5, ascending: true, allow_ties: true };

    assert!(ScoreComparatorImpl::is_better_score(@config, 10, 50), "10 < 50 in ascending (better)");
    assert!(!ScoreComparatorImpl::is_better_score(@config, 50, 10), "50 > 10 in ascending (worse)");
}

#[test]
fn test_break_tie() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let lower_id = LeaderboardEntry { id: 1, score: 100 };
    let higher_id = LeaderboardEntry { id: 5, score: 100 };

    assert!(ScoreComparatorImpl::break_tie(@config, @lower_id, @higher_id), "Lower ID wins");
    assert!(!ScoreComparatorImpl::break_tie(@config, @higher_id, @lower_id), "Higher ID loses");
}

#[test]
fn test_new_creates_empty() {
    let entries = LeaderboardUtilsImpl::new();
    assert!(entries.len() == 0, "New should create empty array");
}

#[test]
fn test_is_full_partial() {
    let config = LeaderboardConfig { max_entries: 5, ascending: false, allow_ties: true };
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });

    assert!(!LeaderboardUtilsImpl::is_full(@config, @entries), "2/5 should not be full");
}

#[test]
fn test_get_range_middle() {
    let mut entries = ArrayTrait::new();
    entries.append(LeaderboardEntry { id: 1, score: 100 });
    entries.append(LeaderboardEntry { id: 2, score: 80 });
    entries.append(LeaderboardEntry { id: 3, score: 60 });
    entries.append(LeaderboardEntry { id: 4, score: 40 });

    let range = LeaderboardUtilsImpl::get_range(@entries, 1, 2);
    assert!(range.len() == 2, "Should return 2 entries");
    assert!(*range.at(0).id == 2, "First should be ID 2");
    assert!(*range.at(1).id == 3, "Second should be ID 3");
}
