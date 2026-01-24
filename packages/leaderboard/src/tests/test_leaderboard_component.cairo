// ==============================================================================
// LEADERBOARD COMPONENT TESTS
// ==============================================================================
// Tests for the LeaderboardComponent which manages tournament leaderboards
// with score submission, ranking, and administrative controls.

use game_components_leaderboard::interface::{
    ILEADERBOARD_ID, ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait,
    ILeaderboardDispatcher, ILeaderboardDispatcherTrait,
};
use game_components_leaderboard::leaderboard::leaderboard::LeaderboardResult;
use game_components_testing::constants::{OWNER, USER1, USER2};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::mock_game_details::{
    IMockGameDetailsAdminDispatcher, IMockGameDetailsAdminDispatcherTrait,
};

// ==============================================================================
// TEST CONSTANTS
// ==============================================================================

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// Tournament IDs for testing
const TOURNAMENT_1: u64 = 1;
const TOURNAMENT_2: u64 = 2;

// ==============================================================================
// DEPLOYMENT HELPERS
// ==============================================================================

/// Deploy the mock leaderboard contract
fn deploy_mock_leaderboard() -> (ILeaderboardDispatcher, ILeaderboardAdminDispatcher) {
    let contract = declare("MockLeaderboardContract").unwrap().contract_class();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let leaderboard = ILeaderboardDispatcher { contract_address };
    let admin = ILeaderboardAdminDispatcher { contract_address };
    (leaderboard, admin)
}

/// Deploy the mock game details contract for score tracking
fn deploy_mock_game_details() -> (ContractAddress, IMockGameDetailsAdminDispatcher) {
    let contract = declare("MockGameDetails").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();

    let admin = IMockGameDetailsAdminDispatcher { contract_address };
    (contract_address, admin)
}

/// Configure a tournament with game
fn configure_tournament_with_game(
    admin: ILeaderboardAdminDispatcher,
    tournament_id: u64,
    max_entries: u32,
    ascending: bool,
    game_address: ContractAddress,
) {
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(tournament_id, max_entries, ascending, game_address);
    stop_cheat_caller_address(admin.contract_address);
}

// ==============================================================================
// INITIALIZATION TESTS
// ==============================================================================

// Test LB-U-01: Leaderboard initializes with owner
#[test]
fn test_leaderboard_initializes_with_owner() {
    let (_, admin) = deploy_mock_leaderboard();

    assert!(admin.owner() == OWNER(), "Owner should be set correctly");
}

// Test LB-U-02: Leaderboard supports ILEADERBOARD_ID interface
#[test]
fn test_leaderboard_supports_src5_interface() {
    let (leaderboard, _) = deploy_mock_leaderboard();
    let src5 = ISRC5Dispatcher { contract_address: leaderboard.contract_address };

    assert!(src5.supports_interface(ILEADERBOARD_ID), "Should support ILeaderboard interface");
}

// Test LB-U-03: Empty tournament returns zero length
#[test]
fn test_empty_tournament_returns_zero_length() {
    let (leaderboard, _) = deploy_mock_leaderboard();

    assert!(
        leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0,
        "Empty tournament should have zero length",
    );
}

// ==============================================================================
// CONFIGURATION TESTS
// ==============================================================================

// Test LB-U-04: Configure tournament sets correct values
#[test]
fn test_configure_tournament_sets_values() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 100, false, game_address);

    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == 100, "Max entries should be 100");
    assert!(config.ascending == false, "Ascending should be false");
    assert!(config.game_address == game_address, "Game address mismatch");
}

// Test LB-U-05: Configure tournament emits event
#[test]
fn test_configure_tournament_emits_event() {
    let (_, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    let mut spy = spy_events();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(TOURNAMENT_1, 50, true, game_address);
    stop_cheat_caller_address(admin.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::TournamentConfigured(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::TournamentConfigured {
                            tournament_id: TOURNAMENT_1,
                            max_entries: 50,
                            ascending: true,
                            game_address: game_address,
                        },
                    ),
                ),
            ],
        );
}

// Test LB-U-06: Only owner can configure tournament
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_configure_tournament_only_owner() {
    let (_, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.configure_tournament(TOURNAMENT_1, 50, false, game_address);
    stop_cheat_caller_address(admin.contract_address);
}

// ==============================================================================
// SCORE SUBMISSION TESTS
// ==============================================================================

// Test LB-U-07: Submit score to empty leaderboard
#[test]
fn test_submit_score_to_empty_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure tournament
    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    // Set score for token
    game_admin.set_score(1, 100);

    // Submit score (position 1 = first place)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should successfully submit score"),
    }

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry");
}

// Test LB-U-08: Submit score emits event
#[test]
fn test_submit_score_emits_event() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    let mut spy = spy_events();

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    spy
        .assert_emitted(
            @array![
                (
                    leaderboard.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::ScoreSubmitted(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::ScoreSubmitted {
                            tournament_id: TOURNAMENT_1, token_id: 1, score: 100, position: 1,
                        },
                    ),
                ),
            ],
        );
}

// Test LB-U-09: Submit multiple scores maintains order
#[test]
fn test_submit_multiple_scores_maintains_order() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    // Set scores
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 90);

    // Submit in order
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 90, 2); // Insert between

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 3, "Should have 3 entries");
    assert!(*entries.at(0).score == 100, "First should be 100");
    assert!(*entries.at(1).score == 90, "Second should be 90");
    assert!(*entries.at(2).score == 80, "Third should be 80");
}

// Test LB-U-10: Submit duplicate entry fails
#[test]
fn test_submit_duplicate_entry_fails() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    // First submission
    let result1 = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    match result1 {
        LeaderboardResult::Success => {},
        _ => panic!("First submission should succeed"),
    }

    // Duplicate submission
    let result2 = leaderboard.submit_score(TOURNAMENT_1, 1, 150, 1);
    match result2 {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Duplicate submission should fail"),
    }
}

// Test LB-U-11: Submit with invalid position fails
#[test]
fn test_submit_invalid_position_fails() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    // Position 0 is invalid (1-based)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 0);
    match result {
        LeaderboardResult::InvalidPosition => {},
        _ => panic!("Position 0 should be invalid"),
    }
}

// ==============================================================================
// QUERY TESTS
// ==============================================================================

// Test LB-U-12: Get entries returns correct data
#[test]
fn test_get_entries_returns_correct_data() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 2, "Should have 2 entries");
    assert!(*entries.at(0).id == 1, "First entry should be ID 1");
    assert!(*entries.at(1).id == 2, "Second entry should be ID 2");
}

// Test LB-U-13: Get top entries returns correct count
#[test]
fn test_get_top_entries_returns_correct_count() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 90, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 80, 3);

    let top_2 = leaderboard.get_top_entries(TOURNAMENT_1, 2);
    assert!(top_2.len() == 2, "Should return 2 entries");
    assert!(*top_2.at(0).score == 100, "First should be 100");
    assert!(*top_2.at(1).score == 90, "Second should be 90");
}

// Test LB-U-14: Get position returns correct value
#[test]
fn test_get_position_returns_correct_value() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    let pos1 = leaderboard.get_position(TOURNAMENT_1, 1);
    assert!(pos1 == Option::Some(1), "Token 1 should be at position 1");

    let pos2 = leaderboard.get_position(TOURNAMENT_1, 2);
    assert!(pos2 == Option::Some(2), "Token 2 should be at position 2");

    let pos_none = leaderboard.get_position(TOURNAMENT_1, 999);
    assert!(pos_none == Option::None, "Non-existent token should return None");
}

// Test LB-U-15: Qualifies returns correct boolean
#[test]
fn test_qualifies_returns_correct_value() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure with max 2 entries
    configure_tournament_with_game(admin, TOURNAMENT_1, 2, false, game_address);

    // Not full - any score qualifies
    assert!(leaderboard.qualifies(TOURNAMENT_1, 10), "Any score should qualify when not full");

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Full - need to beat last entry
    assert!(leaderboard.qualifies(TOURNAMENT_1, 90), "90 should qualify (beats 80)");
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 70), "70 should not qualify (less than 80)");
}

// Test LB-U-16: Is full returns correct value
#[test]
fn test_is_full_returns_correct_value() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 2, false, game_address);

    assert!(!leaderboard.is_full(TOURNAMENT_1), "Should not be full initially");

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    assert!(!leaderboard.is_full(TOURNAMENT_1), "Should not be full with 1 entry");

    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    assert!(leaderboard.is_full(TOURNAMENT_1), "Should be full with 2 entries");
}

// ==============================================================================
// ADMIN TESTS
// ==============================================================================

// Test LB-U-17: Clear leaderboard removes all entries
#[test]
fn test_clear_leaderboard_removes_entries() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry");

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should have 0 entries");
}

// Test LB-U-18: Clear leaderboard emits event
#[test]
fn test_clear_leaderboard_emits_event() {
    let (_, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    let mut spy = spy_events();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardCleared(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardCleared {
                            tournament_id: TOURNAMENT_1,
                        },
                    ),
                ),
            ],
        );
}

// Test LB-U-19: Only owner can clear leaderboard
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_clear_leaderboard_only_owner() {
    let (_, admin) = deploy_mock_leaderboard();

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);
}

// Test LB-U-20: Transfer ownership changes owner
#[test]
fn test_transfer_ownership_changes_owner() {
    let (_, admin) = deploy_mock_leaderboard();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(USER1());
    stop_cheat_caller_address(admin.contract_address);

    assert!(admin.owner() == USER1(), "Owner should be USER1 after transfer");
}

// Test LB-U-21: Transfer ownership emits event
#[test]
fn test_transfer_ownership_emits_event() {
    let (_, admin) = deploy_mock_leaderboard();

    let mut spy = spy_events();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(USER1());
    stop_cheat_caller_address(admin.contract_address);

    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardOwnershipTransferred(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardOwnershipTransferred {
                            previous_owner: OWNER(), new_owner: USER1(),
                        },
                    ),
                ),
            ],
        );
}

// Test LB-U-22: Only owner can transfer ownership
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_transfer_ownership_only_owner() {
    let (_, admin) = deploy_mock_leaderboard();

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.transfer_ownership(USER2());
    stop_cheat_caller_address(admin.contract_address);
}

// ==============================================================================
// MULTI-TOURNAMENT TESTS
// ==============================================================================

// Test LB-U-23: Multiple tournaments are independent
#[test]
fn test_multiple_tournaments_independent() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure two tournaments
    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    configure_tournament_with_game(admin, TOURNAMENT_2, 5, true, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);

    // Submit to tournament 1
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    // Submit to tournament 2
    let _ = leaderboard.submit_score(TOURNAMENT_2, 2, 50, 1);

    // Verify independence
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Tournament 1 should have 1");
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_2) == 1, "Tournament 2 should have 1");

    let entries1 = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries1.at(0).id == 1, "Tournament 1 should have token 1");

    let entries2 = leaderboard.get_entries(TOURNAMENT_2);
    assert!(*entries2.at(0).id == 2, "Tournament 2 should have token 2");
}

// Test LB-U-24: Same token can be in multiple tournaments
#[test]
fn test_same_token_multiple_tournaments() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    configure_tournament_with_game(admin, TOURNAMENT_2, 10, false, game_address);

    game_admin.set_score(1, 100);

    // Submit same token to both tournaments
    let result1 = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let result2 = leaderboard.submit_score(TOURNAMENT_2, 1, 100, 1);

    match result1 {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed in tournament 1"),
    }

    match result2 {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed in tournament 2"),
    }

    // Verify token is in both
    let pos1 = leaderboard.get_position(TOURNAMENT_1, 1);
    let pos2 = leaderboard.get_position(TOURNAMENT_2, 1);

    assert!(pos1 == Option::Some(1), "Token should be position 1 in tournament 1");
    assert!(pos2 == Option::Some(1), "Token should be position 1 in tournament 2");
}

// ==============================================================================
// ASCENDING ORDER TESTS
// ==============================================================================

// Test LB-U-25: Ascending leaderboard orders correctly
#[test]
fn test_ascending_leaderboard_order() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure ascending (lower is better, like time trials)
    configure_tournament_with_game(admin, TOURNAMENT_1, 10, true, game_address);

    game_admin.set_score(1, 100); // Slowest
    game_admin.set_score(2, 50); // Fastest
    game_admin.set_score(3, 75); // Middle

    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 50, 1); // First (fastest)
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 2); // Second (slowest)
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 75, 2); // Insert between

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == 50, "First should be 50 (fastest)");
    assert!(*entries.at(1).score == 75, "Second should be 75");
    assert!(*entries.at(2).score == 100, "Third should be 100 (slowest)");
}
