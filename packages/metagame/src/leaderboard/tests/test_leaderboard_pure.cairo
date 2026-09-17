// Pure leaderboard library tests
use game_components_embeddable_game_standard::token::packing::{
    PackedTokenId, SCHEMA_VERSION, pack_token_id,
};
use game_components_interfaces::leaderboard::LeaderboardResult;
use game_components_metagame::leaderboard::leaderboard::leaderboard;

/// Packed token id with a specific minute-floored mint time and collision
/// counter; every other field neutral.
fn make_token_with_nonce(minted_at_timestamp: u32, tx_nonce: u8) -> felt252 {
    pack_token_id(
        PackedTokenId {
            schema_version: SCHEMA_VERSION,
            has_context: false,
            soulbound: false,
            paymaster: false,
            tx_hash: 0,
            tx_nonce,
            minted_at_block_number: 0,
            minted_at_timestamp,
            start_delay: 0,
            end_delay: 0,
            settings_id: 0,
            objective_id: 0,
            minted_by: 1,
            metadata: 0,
        },
    )
}

/// Packed token id with a specific minute-floored mint time.
fn make_token(minted_at_timestamp: u32) -> felt252 {
    make_token_with_nonce(minted_at_timestamp, 0)
}

// ── is_better_score ──

#[test]
fn test_is_better_score_descending() {
    assert!(leaderboard::is_better_score(100, 50, false)); // 100 > 50
    assert!(!leaderboard::is_better_score(50, 100, false)); // 50 < 100
    assert!(!leaderboard::is_better_score(50, 50, false)); // equal
}

#[test]
fn test_is_better_score_ascending() {
    assert!(leaderboard::is_better_score(50, 100, true)); // 50 < 100
    assert!(!leaderboard::is_better_score(100, 50, true)); // 100 > 50
    assert!(!leaderboard::is_better_score(50, 50, true)); // equal
}

// ── wins_tiebreak ──

#[test]
fn test_wins_tiebreak_earlier_minted_wins() {
    let early = make_token(1000);
    let late = make_token(2000);
    assert!(leaderboard::wins_tiebreak(early, late)); // earlier wins
    assert!(!leaderboard::wins_tiebreak(late, early)); // later loses
}

/// The tiebreak reads the id's `minted_at_timestamp` field: a later mint
/// with a numerically smaller id (a lower collision counter, say) still
/// loses to the earlier mint.
#[test]
fn test_wins_tiebreak_reads_mint_time_not_raw_id() {
    let early_high_nonce = make_token_with_nonce(1000, 200);
    let late_low_nonce = make_token_with_nonce(2000, 0);
    let a: u256 = early_high_nonce.into();
    let b: u256 = late_low_nonce.into();
    assert!(a < b, "fixture: the later mint must have the larger raw id");
    assert!(leaderboard::wins_tiebreak(early_high_nonce, late_low_nonce));
    assert!(!leaderboard::wins_tiebreak(late_low_nonce, early_high_nonce));
}

#[test]
fn test_wins_tiebreak_same_mint_time_falls_back_to_token_id() {
    let a = make_token_with_nonce(1000, 1);
    let b = make_token_with_nonce(1000, 2);
    // Same minted_at_timestamp — falls back to the lower token id.
    assert!(leaderboard::wins_tiebreak(a, b), "lower id wins on equal mint time");
    assert!(!leaderboard::wins_tiebreak(b, a), "higher id loses on equal mint time");
    assert!(!leaderboard::wins_tiebreak(a, a)); // equal — no winner
}

// ── position_to_index ──

#[test]
fn test_position_to_index() {
    assert!(leaderboard::position_to_index(0).is_none());
    assert!(leaderboard::position_to_index(1) == Option::Some(0));
    assert!(leaderboard::position_to_index(5) == Option::Some(4));
}

// ── validate_insertion ──

#[test]
fn test_validate_insertion_empty_board() {
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 0,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 0,
        token_at_index: 0,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::Success);
}

#[test]
fn test_validate_insertion_displace_lower_score() {
    // Descending: inserting score 100 at position 0, displacing score 50
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 1,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 50,
        token_at_index: 2,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::Success);
}

#[test]
fn test_validate_insertion_duplicate_rejected() {
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 1,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: true,
        score_at_index: 50,
        token_at_index: 2,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::DuplicateEntry);
}

#[test]
fn test_validate_insertion_invalid_position() {
    let result = leaderboard::validate_insertion(
        index: 5,
        count: 2,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 0,
        token_at_index: 0,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::InvalidPosition);
}

#[test]
fn test_validate_insertion_full_board_rejected() {
    // Board full (count=3, max=3), inserting at index 3 (beyond max)
    let result = leaderboard::validate_insertion(
        index: 3,
        count: 3,
        max_entries: 3,
        ascending: false,
        score: 10,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 0,
        token_at_index: 0,
        score_above: 20,
        token_above: 2,
    );
    assert!(result == LeaderboardResult::LeaderboardFull);
}

#[test]
fn test_validate_insertion_score_too_low_descending() {
    // Descending: trying to insert score 30 at index 0, but score at index is 50
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 1,
        max_entries: 10,
        ascending: false,
        score: 30,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 50,
        token_at_index: 2,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::ScoreTooLow);
}

#[test]
fn test_validate_insertion_score_too_high_descending() {
    // Descending: trying to insert score 200 at index 1, but entry above has score 100
    let result = leaderboard::validate_insertion(
        index: 1,
        count: 2,
        max_entries: 10,
        ascending: false,
        score: 200,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 50,
        token_at_index: 3,
        score_above: 100,
        token_above: 2,
    );
    assert!(result == LeaderboardResult::ScoreTooHigh);
}

#[test]
fn test_validate_insertion_tiebreak_lower_id_wins() {
    // Descending: same score, new token ID (1) < existing (2) → wins tiebreak → Success
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 1,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 100,
        token_at_index: 2,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::Success);
}

#[test]
fn test_validate_insertion_tiebreak_higher_id_loses() {
    // Descending: same score, new token ID (3) > existing (2) → loses tiebreak → ScoreTooLow
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 1,
        max_entries: 10,
        ascending: false,
        score: 100,
        token_id: 3,
        is_duplicate: false,
        score_at_index: 100,
        token_at_index: 2,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::ScoreTooLow);
}

// ── qualifies ──

#[test]
fn test_qualifies_not_full() {
    assert!(leaderboard::qualifies(1, 0, 2, 10, false)); // not full → always qualifies
}

#[test]
fn test_qualifies_full_better_score_descending() {
    assert!(leaderboard::qualifies(100, 50, 3, 3, false)); // 100 > 50 → qualifies
}

#[test]
fn test_qualifies_full_worse_score_descending() {
    assert!(!leaderboard::qualifies(30, 50, 3, 3, false)); // 30 < 50 → doesn't qualify
}

#[test]
fn test_qualifies_full_equal_score_does_not_qualify() {
    assert!(!leaderboard::qualifies(50, 50, 3, 3, false)); // equal → doesn't qualify
}

#[test]
fn test_qualifies_ascending() {
    assert!(leaderboard::qualifies(30, 50, 3, 3, true)); // 30 < 50 → qualifies (ascending)
    assert!(!leaderboard::qualifies(100, 50, 3, 3, true)); // 100 > 50 → doesn't qualify
}

#[test]
fn test_qualifies_zero_capacity() {
    assert!(!leaderboard::qualifies(100, 0, 0, 0, false)); // zero capacity → never qualifies
    assert!(!leaderboard::qualifies(1, 0, 0, 0, true)); // zero capacity ascending
}

#[test]
fn test_validate_insertion_zero_capacity() {
    let result = leaderboard::validate_insertion(
        index: 0,
        count: 0,
        max_entries: 0,
        ascending: false,
        score: 100,
        token_id: 1,
        is_duplicate: false,
        score_at_index: 0,
        token_at_index: 0,
        score_above: 0,
        token_above: 0,
    );
    assert!(result == LeaderboardResult::LeaderboardFull);
}
