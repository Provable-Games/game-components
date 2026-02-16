// ==============================================================================
// LEADERBOARD COMPONENT TESTS
// ==============================================================================
// Tests for the LeaderboardComponent which manages tournament leaderboards
// with score submission, ranking, and administrative controls.

use game_components_metagame::leaderboard::interface::{
    ILEADERBOARD_ID, ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait,
    ILeaderboardDispatcher, ILeaderboardDispatcherTrait,
};
use game_components_metagame::leaderboard::leaderboard::leaderboard::LeaderboardResult;
use game_components_testing::constants::{
    MAX_U32, MAX_U64, NEW_OWNER, OWNER, USER1, USER2, ZERO_ADDRESS,
};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait, ISRC5_ID};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, EventSpyTrait, declare,
    spy_events, start_cheat_caller_address, stop_cheat_caller_address,
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
                    game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::Event::TournamentConfigured(
                        game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::TournamentConfigured {
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
                    game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::Event::ScoreSubmitted(
                        game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::ScoreSubmitted {
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
                    game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardCleared(
                        game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardCleared {
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
                    game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardOwnershipTransferred(
                        game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardOwnershipTransferred {
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

// ==============================================================================
// ADDITIONAL INITIALIZATION TESTS
// ==============================================================================

// Test LB-INIT-03: SRC5 interface registered correctly
#[test]
fn test_src5_interface_registered() {
    let (leaderboard, _) = deploy_mock_leaderboard();
    let src5 = ISRC5Dispatcher { contract_address: leaderboard.contract_address };

    assert!(src5.supports_interface(ILEADERBOARD_ID), "Should support ILeaderboard interface");
    assert!(src5.supports_interface(ISRC5_ID), "Should support ISRC5 interface");
}

// ==============================================================================
// ADDITIONAL CONFIGURATION TESTS
// ==============================================================================

// Test LB-CFG-01: Configure tournament with zero max_entries
#[test]
fn test_configure_tournament_zero_max_entries() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 0, false, game_address);

    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == 0, "Max entries should be 0");
}

// Test LB-CFG-02: Configure tournament with max u32 max_entries
#[test]
fn test_configure_tournament_max_entries() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, MAX_U32, false, game_address);

    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == MAX_U32, "Max entries should be MAX_U32");
}

// Test LB-CFG-03: Configure tournament with zero game_address
#[test]
fn test_configure_tournament_zero_game_address() {
    let (leaderboard, admin) = deploy_mock_leaderboard();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, ZERO_ADDRESS());

    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.game_address == ZERO_ADDRESS(), "Game address should be zero");
}

// Test LB-CFG-04: Reconfigure existing tournament
#[test]
fn test_reconfigure_existing_tournament() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    // First configuration
    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    let config1 = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config1.max_entries == 10, "First config should have 10 max entries");
    assert!(config1.ascending == false, "First config should not be ascending");

    // Reconfigure with different values
    configure_tournament_with_game(admin, TOURNAMENT_1, 50, true, game_address);

    let config2 = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config2.max_entries == 50, "Second config should have 50 max entries");
    assert!(config2.ascending == true, "Second config should be ascending");
}

// ==============================================================================
// ADDITIONAL SCORE SUBMISSION TESTS
// ==============================================================================

// Test LB-SUB-02: Submit score when leaderboard full (displaces last)
#[test]
fn test_submit_score_full_displaces_last() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure with max 3 entries
    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);
    game_admin.set_score(4, 90);

    // Fill the leaderboard
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);

    assert!(leaderboard.is_full(TOURNAMENT_1), "Leaderboard should be full");

    // Submit better score
    let result = leaderboard.submit_score(TOURNAMENT_1, 4, 90, 2);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed and displace last"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 3, "Should still have 3 entries");
    assert!(*entries.at(0).score == 100, "First should be 100");
    assert!(*entries.at(1).score == 90, "Second should be 90");
    assert!(*entries.at(2).score == 80, "Third should be 80 (60 dropped)");

    // Token 3 should no longer be in leaderboard
    let pos3 = leaderboard.get_position(TOURNAMENT_1, 3);
    assert!(pos3 == Option::None, "Token 3 should have been dropped");
}

// Test LB-SUB-03: Submit score when leaderboard full (score too low)
#[test]
fn test_submit_score_full_too_low() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);
    game_admin.set_score(4, 50);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);

    // Try to submit lower score
    let result = leaderboard.submit_score(TOURNAMENT_1, 4, 50, 4);

    match result {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should return LeaderboardFull for low score"),
    }
}

// Test LB-SUB-04: Submit with position beyond current length
#[test]
fn test_submit_position_beyond_length() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    // Empty leaderboard, submit at position 5 (invalid - only position 1 is valid)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 5);

    match result {
        LeaderboardResult::InvalidPosition => {},
        _ => panic!("Should return InvalidPosition"),
    }
}

// Test LB-SUB-07: No event emitted on failure
#[test]
fn test_submit_no_event_on_failure() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    // First submission
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    // Start spying AFTER successful submission
    let mut spy = spy_events();

    // Duplicate submission (should fail)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 150, 1);

    match result {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Should return DuplicateEntry"),
    }

    // Verify no ScoreSubmitted event was emitted
    let events = spy.get_events();
    assert!(events.events.len() == 0, "Should not emit event on failure");
}

// ==============================================================================
// ADDITIONAL QUERY TESTS
// ==============================================================================

// Test LB-QRY-01: Get entries on empty tournament
#[test]
fn test_get_entries_empty_tournament() {
    let (leaderboard, _) = deploy_mock_leaderboard();

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 0, "Empty tournament should return empty array");
}

// Test LB-QRY-02: Get top entries more than available
#[test]
fn test_get_top_entries_more_than_available() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    let top = leaderboard.get_top_entries(TOURNAMENT_1, 10);
    assert!(top.len() == 2, "Should return only available entries");
}

// Test LB-QRY-03: Get top entries with count=0
#[test]
fn test_get_top_entries_count_zero() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    let top = leaderboard.get_top_entries(TOURNAMENT_1, 0);
    assert!(top.len() == 0, "Count 0 should return empty");
}

// Test LB-QRY-04: Get position returns 1-based
#[test]
fn test_get_position_is_one_based() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 100);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    let pos = leaderboard.get_position(TOURNAMENT_1, 1);
    assert!(pos == Option::Some(1), "First entry should be position 1, not 0");
}

// Test LB-QRY-05: Qualifies with ascending=true
#[test]
fn test_qualifies_ascending() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure ascending (lower is better, max 3)
    configure_tournament_with_game(admin, TOURNAMENT_1, 3, true, game_address);

    game_admin.set_score(1, 10);
    game_admin.set_score(2, 20);
    game_admin.set_score(3, 30);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 10, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 20, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 30, 3);

    // 15 is lower than 30, so it qualifies in ascending mode
    assert!(leaderboard.qualifies(TOURNAMENT_1, 15), "15 should qualify (beats 30 in ascending)");
    // 35 is higher than 30, so it doesn't qualify
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 35), "35 should not qualify (worse than 30)");
}

// Test LB-QRY-06: Get tournament config for unconfigured
#[test]
fn test_get_config_unconfigured_tournament() {
    let (leaderboard, _) = deploy_mock_leaderboard();

    let config = leaderboard.get_tournament_config(999);

    assert!(config.max_entries == 0, "Unconfigured should have 0 max_entries");
    assert!(config.ascending == false, "Unconfigured should have ascending=false");
    assert!(config.game_address == ZERO_ADDRESS(), "Unconfigured should have zero game_address");
}

// ==============================================================================
// ADDITIONAL ADMIN TESTS
// ==============================================================================

// Test LB-ADM-01: Clear empty leaderboard
#[test]
fn test_clear_empty_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    let mut spy = spy_events();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    // Should succeed and emit event even for empty
    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardCleared(
                        game_components_metagame::leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardCleared {
                            tournament_id: TOURNAMENT_1,
                        },
                    ),
                ),
            ],
        );

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should still be 0");
}

// Test LB-ADM-02: Transfer ownership to zero address
#[test]
fn test_transfer_ownership_to_zero() {
    let (_, admin) = deploy_mock_leaderboard();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(ZERO_ADDRESS());
    stop_cheat_caller_address(admin.contract_address);

    assert!(admin.owner() == ZERO_ADDRESS(), "Owner should be zero (renounced)");
}

// Test LB-ADM-03: New owner can perform admin actions
#[test]
fn test_new_owner_can_admin() {
    let (_, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    // Transfer to NEW_OWNER
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // NEW_OWNER configures tournament
    start_cheat_caller_address(admin.contract_address, NEW_OWNER());
    admin.configure_tournament(TOURNAMENT_1, 100, false, game_address);
    stop_cheat_caller_address(admin.contract_address);
    // Should succeed (no panic)
}

// Test LB-ADM-04: Previous owner cannot perform admin actions
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_previous_owner_cannot_admin() {
    let (_, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    // Transfer to NEW_OWNER
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // Previous OWNER tries to configure
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(TOURNAMENT_1, 100, false, game_address);
    stop_cheat_caller_address(admin.contract_address);
}

// ==============================================================================
// ADDITIONAL MULTI-TOURNAMENT TESTS
// ==============================================================================

// Test LB-MT-01: Clear one tournament doesn't affect others
#[test]
fn test_clear_tournament_independence() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    configure_tournament_with_game(admin, TOURNAMENT_2, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_2, 2, 80, 1);

    // Clear tournament 1
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Tournament 1 should be empty");
    assert!(
        leaderboard.get_leaderboard_length(TOURNAMENT_2) == 1, "Tournament 2 should be unchanged",
    );
}

// Test LB-MT-02: Configure one tournament doesn't affect others
#[test]
fn test_configure_tournament_independence() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    configure_tournament_with_game(admin, TOURNAMENT_2, 5, true, game_address);

    // Reconfigure tournament 1
    configure_tournament_with_game(admin, TOURNAMENT_1, 100, true, game_address);

    // Tournament 2 should be unchanged
    let config2 = leaderboard.get_tournament_config(TOURNAMENT_2);
    assert!(config2.max_entries == 5, "Tournament 2 max_entries should be unchanged");
    assert!(config2.ascending == true, "Tournament 2 ascending should be unchanged");
}

// Test LB-MT-03: Large tournament ID
#[test]
fn test_large_tournament_id() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, MAX_U64, 10, false, game_address);
    game_admin.set_score(1, 100);

    let result = leaderboard.submit_score(MAX_U64, 1, 100, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should work with MAX_U64 tournament ID"),
    }

    assert!(leaderboard.get_leaderboard_length(MAX_U64) == 1, "Should have 1 entry");
}

// ==============================================================================
// ADDITIONAL ASCENDING ORDER TESTS
// ==============================================================================

// Test LB-ASC-01: Ascending qualifies lower scores
#[test]
fn test_ascending_qualifies_lower_scores() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, true, game_address);

    game_admin.set_score(1, 10);
    game_admin.set_score(2, 20);
    game_admin.set_score(3, 30);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 10, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 20, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 30, 3);

    // In ascending mode, lower (better) scores qualify
    assert!(leaderboard.qualifies(TOURNAMENT_1, 25), "25 should qualify (< 30)");
    assert!(leaderboard.qualifies(TOURNAMENT_1, 5), "5 should qualify (< 30)");
}

// Test LB-ASC-02: Ascending rejects higher scores when full
#[test]
fn test_ascending_rejects_higher_scores() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, true, game_address);

    game_admin.set_score(1, 10);
    game_admin.set_score(2, 20);
    game_admin.set_score(3, 30);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 10, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 20, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 30, 3);

    // In ascending mode, higher (worse) scores don't qualify
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 50), "50 should not qualify (> 30)");
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 30), "30 should not qualify (= 30, not better)");
}

// ==============================================================================
// EDGE CASE TESTS
// ==============================================================================

// Test LB-EDGE-01: Submit with max u64 score
#[test]
fn test_submit_max_score() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, MAX_U64);

    let result = leaderboard.submit_score(TOURNAMENT_1, 1, MAX_U64, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed with MAX_U64 score"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == MAX_U64, "Score should be MAX_U64");
}

// Test LB-EDGE-02: Submit with score = 0
#[test]
fn test_submit_zero_score() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    game_admin.set_score(1, 0);

    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 0, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed with 0 score"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == 0, "Score should be 0");
}

// Test LB-EDGE-03: Submit with max u64 token_id
#[test]
fn test_submit_max_token_id() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);
    let max_token_id: felt252 = MAX_U64.into();
    game_admin.set_score(max_token_id, 100);

    let result = leaderboard.submit_score(TOURNAMENT_1, max_token_id, 100, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed with MAX_U64 token_id"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == max_token_id, "Token ID should be MAX_U64");
}

// Test LB-EDGE-05: Leaderboard with max_entries = 1
#[test]
fn test_single_entry_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 1, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 200);

    // First submission
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry");

    // Higher score should replace
    let result = leaderboard.submit_score(TOURNAMENT_1, 2, 200, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Higher score should succeed"),
    }

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should still have 1 entry");

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 2, "Entry should be token 2 (higher score)");
}

// ==============================================================================
// INTEGRATION TESTS
// ==============================================================================

// Test LB-INT-01: Full lifecycle test
#[test]
fn test_full_lifecycle() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // 1. Configure tournament
    configure_tournament_with_game(admin, TOURNAMENT_1, 5, false, game_address);
    assert!(leaderboard.get_tournament_config(TOURNAMENT_1).max_entries == 5, "Config set");

    // 2. Submit multiple scores
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 90);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 90, 2);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 3, "Should have 3 entries");

    // 3. Query entries
    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == 100, "First 100");
    assert!(*entries.at(1).score == 90, "Second 90");
    assert!(*entries.at(2).score == 80, "Third 80");

    // 4. Clear leaderboard
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should be empty");

    // 5. Re-submit after clear
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry again");
}

// Test LB-INT-02: Multiple admins via ownership transfer
#[test]
fn test_multiple_admins_via_transfer() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Owner configures first tournament
    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    // Transfer to NEW_OWNER
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // NEW_OWNER modifies
    start_cheat_caller_address(admin.contract_address, NEW_OWNER());
    admin.configure_tournament(TOURNAMENT_2, 20, true, game_address);
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "NEW_OWNER cleared T1");
    assert!(
        leaderboard.get_tournament_config(TOURNAMENT_2).max_entries == 20,
        "NEW_OWNER configured T2",
    );
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

// Test LB-FUZZ-01: Random score submissions
#[test]
#[fuzzer]
fn test_fuzz_random_score_submission(score: u64, token_seed: u64) {
    let token_id_u64 = if token_seed == 0 {
        1_u64
    } else {
        token_seed
    };
    let token_id: felt252 = token_id_u64.into();

    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 100, false, game_address);
    game_admin.set_score(token_id, score);

    let result = leaderboard.submit_score(TOURNAMENT_1, token_id, score, 1);

    // Should succeed into empty leaderboard
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("First submission should always succeed"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 1, "Should have 1 entry");
    assert!(*entries.at(0).score == score, "Score should match");
}

// Test LB-FUZZ-02: Random tournament configurations
#[test]
#[fuzzer]
fn test_fuzz_tournament_config(max_entries: u32) {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    // Test with various max_entries
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(TOURNAMENT_1, max_entries, false, game_address);
    stop_cheat_caller_address(admin.contract_address);

    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == max_entries, "Config should store any max_entries value");
}

// Test LB-FUZZ-06: Score qualification boundary
#[test]
#[fuzzer]
fn test_fuzz_qualification_boundary(score: u64) {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);

    let qualifies = leaderboard.qualifies(TOURNAMENT_1, score);

    // Score must be > 60 to qualify (descending mode)
    if score > 60 {
        assert!(qualifies, "Score > 60 should qualify");
    } else {
        assert!(!qualifies, "Score <= 60 should not qualify");
    }
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS
// ==============================================================================

// Test submitting score at position that creates a gap (ScoreTooHigh validation)
#[test]
fn test_submit_score_too_high_for_position() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    game_admin.set_score(3, 120);

    // Submit first two entries
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 50, 2);

    // Try to submit score 120 at position 3 (should be position 1, but we're putting at wrong
    // place)
    // Score 120 is better than score at position 2 (50), so it's "too high" for position 3
    let result = leaderboard.submit_score(TOURNAMENT_1, 3, 120, 3);

    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Should return ScoreTooHigh when score should be higher in leaderboard"),
    }
}

// Test submitting with tie where entry loses tiebreaker (higher ID)
#[test]
fn test_submit_tie_loses_tiebreaker() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(5, 100); // Same score, higher ID

    // Submit ID 1 first
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    // Try to submit ID 5 at position 1 (same score but higher ID should lose tiebreaker)
    let result = leaderboard.submit_score(TOURNAMENT_1, 5, 100, 1);

    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Higher ID should lose tiebreaker at same position"),
    }
}

// Test submitting with tie where entry wins tiebreaker (lower ID)
#[test]
fn test_submit_tie_wins_tiebreaker() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(5, 100);
    game_admin.set_score(1, 100); // Same score, lower ID

    // Submit ID 5 first
    let _ = leaderboard.submit_score(TOURNAMENT_1, 5, 100, 1);

    // Submit ID 1 at position 1 (same score but lower ID should win tiebreaker)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Lower ID should win tiebreaker"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 1, "ID 1 should be first (won tiebreaker)");
    assert!(*entries.at(1).id == 5, "ID 5 should be second");
}

// Test submitting score equal to entry above (should fail with ScoreTooHigh if tiebreaker wins)
#[test]
fn test_submit_equal_score_to_entry_above_wins_tiebreaker() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(5, 100);
    game_admin.set_score(1, 100);

    // Submit ID 5 at position 1
    let _ = leaderboard.submit_score(TOURNAMENT_1, 5, 100, 1);

    // Try to submit ID 1 (lower) at position 2 with same score
    // Since ID 1 < ID 5 and same score, ID 1 should be ranked higher, so position 2 is too low
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 2);

    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Should return ScoreTooHigh when lower ID at same score should be higher"),
    }
}

// Test get_position for non-existent token in populated leaderboard
#[test]
fn test_get_position_nonexistent_in_populated() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);

    // Token 4 doesn't exist
    let pos = leaderboard.get_position(TOURNAMENT_1, 4);
    assert!(pos == Option::None, "Non-existent token should return None");

    // Token 999 doesn't exist
    let pos2 = leaderboard.get_position(TOURNAMENT_1, 999);
    assert!(pos2 == Option::None, "Token 999 should return None");
}

// Test qualifies when leaderboard is exactly at capacity minus one
#[test]
fn test_qualifies_one_below_capacity() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Leaderboard has 2 entries, max is 3, so any score qualifies
    assert!(leaderboard.qualifies(TOURNAMENT_1, 1), "Any score qualifies when not full");
    assert!(leaderboard.qualifies(TOURNAMENT_1, 0), "Even 0 qualifies when not full");
}

// Test ascending mode with equal scores (tiebreaker)
#[test]
fn test_ascending_tie_breaking() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, true, game_address);

    game_admin.set_score(5, 50);
    game_admin.set_score(1, 50);

    // Submit ID 5 first
    let _ = leaderboard.submit_score(TOURNAMENT_1, 5, 50, 1);

    // Submit ID 1 at position 1 (same score, lower ID wins tiebreaker even in ascending)
    let result = leaderboard.submit_score(TOURNAMENT_1, 1, 50, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed - lower ID wins tiebreaker"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 1, "ID 1 should be first");
    assert!(*entries.at(1).id == 5, "ID 5 should be second");
}

// Test clearing a leaderboard with multiple entries
#[test]
fn test_clear_leaderboard_multiple_entries() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);
    game_admin.set_score(4, 70);
    game_admin.set_score(5, 60);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 90, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 80, 3);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 4, 70, 4);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 5, 60, 5);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 5, "Should have 5 entries");

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should be empty after clear");

    // Verify we can submit again after clearing
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    assert!(
        leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1,
        "Should have 1 entry after re-submit",
    );
}

// Test submitting when score doesn't qualify (descending full leaderboard)
#[test]
fn test_submit_doesnt_qualify_descending() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);
    game_admin.set_score(4, 60); // Lower than last

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 90, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 80, 3);

    // Check qualification before submitting
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 60), "60 should not qualify");
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 80), "80 equal to last should not qualify");
    assert!(leaderboard.qualifies(TOURNAMENT_1, 85), "85 should qualify");
}

// Test re-submitting after entry was displaced
#[test]
fn test_resubmit_after_displacement() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 2, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 90);

    // Fill leaderboard
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Token 3 displaces token 2
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 90, 2);

    // Token 2 is no longer in leaderboard
    let pos = leaderboard.get_position(TOURNAMENT_1, 2);
    assert!(pos == Option::None, "Token 2 should be displaced");

    // Token 2 can now re-enter if it has a qualifying score
    game_admin.set_score(2, 95);
    let result = leaderboard.submit_score(TOURNAMENT_1, 2, 95, 2);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Token 2 should be able to re-enter"),
    }
}

// Test with max_entries = 0 (edge case - no entries allowed)
// Note: With max_entries=0, the leaderboard reports as full immediately
#[test]
fn test_max_entries_zero_is_full() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, _) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 0, false, game_address);

    // Empty leaderboard with max=0 should report as full
    assert!(leaderboard.is_full(TOURNAMENT_1), "Should be full when max_entries is 0");
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should have no entries");
}

// Test multiple score submissions building up the leaderboard
#[test]
fn test_incremental_leaderboard_buildup() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    // Submit entries one by one and verify order
    game_admin.set_score(1, 50);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 50, 1);
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry");

    game_admin.set_score(2, 100);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 100, 1); // Goes to first
    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 2, "ID 2 should be first");
    assert!(*entries.at(1).id == 1, "ID 1 should be second");

    game_admin.set_score(3, 75);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 75, 2); // Goes to middle
    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 2, "ID 2 should be first");
    assert!(*entries.at(1).id == 3, "ID 3 should be second");
    assert!(*entries.at(2).id == 1, "ID 1 should be third");
}

// Test get_entries returns scores from game contract
#[test]
fn test_get_entries_fetches_scores() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Update scores in game contract
    game_admin.set_score(1, 150);
    game_admin.set_score(2, 200);

    // get_entries should fetch current scores from game
    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == 150, "Should fetch updated score for ID 1");
    assert!(*entries.at(1).score == 200, "Should fetch updated score for ID 2");
}

// ==============================================================================
// ADDITIONAL EDGE CASE TESTS FOR COVERAGE
// ==============================================================================

// Test getting entries from a tournament with many entries
#[test]
fn test_get_entries_large_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 20, false, game_address);

    // Add 10 entries
    let mut i: u64 = 1;
    loop {
        if i > 10 {
            break;
        }
        let score: u64 = 110 - i * 10;
        let token_id: felt252 = i.into();
        game_admin.set_score(token_id, score);
        let _ = leaderboard.submit_score(TOURNAMENT_1, token_id, score, i.try_into().unwrap());
        i += 1;
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 10, "Should have 10 entries");
    assert!(*entries.at(0).score == 100, "First should be 100");
    assert!(*entries.at(9).score == 10, "Last should be 10");
}

// Test get_top_entries with exact count match
#[test]
fn test_get_top_entries_exact_count() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 90, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 80, 3);

    let top = leaderboard.get_top_entries(TOURNAMENT_1, 3);
    assert!(top.len() == 3, "Should return exactly 3 entries");
}

// Test ScoreTooLow when trying to insert score equal to below entry
#[test]
fn test_score_too_low_equal_to_below() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    game_admin.set_score(3, 50); // Same as entry at position 2

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 50, 2);

    // Try to insert at position 1 with score 50 (equal to entry at position 2)
    // This should fail because 50 is not better than 50 at position 2
    let result = leaderboard.submit_score(TOURNAMENT_1, 3, 50, 1);

    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Should return ScoreTooLow when score doesn't beat current at position"),
    }
}

// Test multiple qualifying scores in sequence
#[test]
fn test_multiple_qualifying_scores_fill_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 5, false, game_address);

    // Submit 5 entries to fill
    let mut i: u64 = 1;
    loop {
        if i > 5 {
            break;
        }
        let score: u64 = 60 - i * 10;
        let token_id: felt252 = i.into();
        game_admin.set_score(token_id, score);
        let _ = leaderboard.submit_score(TOURNAMENT_1, token_id, score, i.try_into().unwrap());
        i += 1;
    }

    assert!(leaderboard.is_full(TOURNAMENT_1), "Should be full with 5 entries");

    // Check all positions are correct
    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).score == 50, "First should be 50");
    assert!(*entries.at(1).score == 40, "Second should be 40");
    assert!(*entries.at(2).score == 30, "Third should be 30");
    assert!(*entries.at(3).score == 20, "Fourth should be 20");
    assert!(*entries.at(4).score == 10, "Fifth should be 10");
}

// Test position boundaries with full leaderboard
#[test]
fn test_position_boundaries_full_leaderboard() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);

    // Verify positions
    let pos1 = leaderboard.get_position(TOURNAMENT_1, 1);
    let pos2 = leaderboard.get_position(TOURNAMENT_1, 2);
    let pos3 = leaderboard.get_position(TOURNAMENT_1, 3);

    assert!(pos1 == Option::Some(1), "Token 1 at position 1");
    assert!(pos2 == Option::Some(2), "Token 2 at position 2");
    assert!(pos3 == Option::Some(3), "Token 3 at position 3");
}

// Test that clearing doesn't affect config
#[test]
fn test_clear_preserves_config() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, true, game_address);

    game_admin.set_score(1, 50);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 50, 1);

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    // Config should be preserved
    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == 10, "Max entries preserved");
    assert!(config.ascending == true, "Ascending preserved");
    assert!(config.game_address == game_address, "Game address preserved");
}

// Test ascending mode displacement
#[test]
fn test_ascending_displacement() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 3, true, game_address);

    game_admin.set_score(1, 10);
    game_admin.set_score(2, 20);
    game_admin.set_score(3, 30);
    game_admin.set_score(4, 15);

    // Fill with 10, 20, 30
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 10, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 20, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 30, 3);

    // Insert 15 which displaces 30
    let result = leaderboard.submit_score(TOURNAMENT_1, 4, 15, 2);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed in ascending displacement"),
    }

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 3, "Should have 3 entries");
    assert!(*entries.at(0).score == 10, "First should be 10");
    assert!(*entries.at(1).score == 15, "Second should be 15");
    assert!(*entries.at(2).score == 20, "Third should be 20 (30 displaced)");
}

// Test fuzz with both ascending and descending
#[test]
#[fuzzer]
fn test_fuzz_ascending_descending_consistency(score: u64, ascending_seed: u8) {
    let ascending = ascending_seed % 2 == 0;
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, ascending, game_address);
    game_admin.set_score(1, score);

    let result = leaderboard.submit_score(TOURNAMENT_1, 1, score, 1);

    match result {
        LeaderboardResult::Success => {},
        _ => panic!("First submission should always succeed"),
    }

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should have 1 entry");
}

// Test multiple tournaments with different configs
#[test]
fn test_multiple_tournaments_different_configs() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Tournament 1: descending, max 5
    configure_tournament_with_game(admin, TOURNAMENT_1, 5, false, game_address);
    // Tournament 2: ascending, max 3
    configure_tournament_with_game(admin, TOURNAMENT_2, 3, true, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);

    // Submit to both tournaments
    let r1 = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let r2 = leaderboard.submit_score(TOURNAMENT_2, 2, 50, 1);

    match r1 {
        LeaderboardResult::Success => {},
        _ => panic!("T1 should succeed"),
    }
    match r2 {
        LeaderboardResult::Success => {},
        _ => panic!("T2 should succeed"),
    }

    // Verify configs are independent
    let config1 = leaderboard.get_tournament_config(TOURNAMENT_1);
    let config2 = leaderboard.get_tournament_config(TOURNAMENT_2);

    assert!(config1.max_entries == 5, "T1 max_entries");
    assert!(config1.ascending == false, "T1 descending");
    assert!(config2.max_entries == 3, "T2 max_entries");
    assert!(config2.ascending == true, "T2 ascending");
}

// Test getting position after clear and resubmit
#[test]
fn test_position_after_clear_resubmit() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Clear
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    // Positions should be None
    assert!(
        leaderboard.get_position(TOURNAMENT_1, 1) == Option::None, "Should be None after clear",
    );
    assert!(
        leaderboard.get_position(TOURNAMENT_1, 2) == Option::None, "Should be None after clear",
    );

    // Resubmit
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 1); // Now token 2 is first

    assert!(leaderboard.get_position(TOURNAMENT_1, 2) == Option::Some(1), "Token 2 should be at 1");
    assert!(leaderboard.get_position(TOURNAMENT_1, 1) == Option::None, "Token 1 not submitted yet");
}

// Test sequential submissions building leaderboard
#[test]
fn test_sequential_insertion_order() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 100);
    game_admin.set_score(3, 100);

    // All same score, so tiebreaker (lower ID first)
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 100, 1); // First
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1); // ID 1 < 3, goes first
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 100, 2); // ID 2 between 1 and 3

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(*entries.at(0).id == 1, "ID 1 should be first (lowest)");
    assert!(*entries.at(1).id == 2, "ID 2 should be second");
    assert!(*entries.at(2).id == 3, "ID 3 should be third");
}

// ==============================================================================
// ADDITIONAL COMPONENT COVERAGE TESTS
// ==============================================================================

// Test getting entries after some are displaced
#[test]
fn test_get_entries_after_displacement() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 2, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 90);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 90, 2); // Displaces 2

    let entries = leaderboard.get_entries(TOURNAMENT_1);
    assert!(entries.len() == 2, "Should have 2 entries");
    assert!(*entries.at(0).id == 1, "First should be 1");
    assert!(*entries.at(1).id == 3, "Second should be 3 (displaced 2)");
}

// Test get_top_entries on ascending leaderboard
#[test]
fn test_get_top_entries_ascending() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, true, game_address);

    game_admin.set_score(1, 10);
    game_admin.set_score(2, 20);
    game_admin.set_score(3, 30);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 10, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 20, 2);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 30, 3);

    let top = leaderboard.get_top_entries(TOURNAMENT_1, 2);
    assert!(top.len() == 2, "Should have 2 entries");
    assert!(*top.at(0).score == 10, "First should be 10 (best in ascending)");
    assert!(*top.at(1).score == 20, "Second should be 20");
}

// Test qualifies edge case: equal to minimum
#[test]
fn test_qualifies_equal_to_minimum() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 2, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Equal to minimum should NOT qualify (need to beat it)
    assert!(!leaderboard.qualifies(TOURNAMENT_1, 80), "Equal to min should not qualify");
    assert!(leaderboard.qualifies(TOURNAMENT_1, 81), "One above min should qualify");
}

// Test is_full with varying tournament configs
#[test]
fn test_is_full_various_configs() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 1, false, game_address);
    configure_tournament_with_game(admin, TOURNAMENT_2, 100, false, game_address);

    game_admin.set_score(1, 100);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);

    assert!(leaderboard.is_full(TOURNAMENT_1), "T1 with max=1 should be full");
    assert!(!leaderboard.is_full(TOURNAMENT_2), "T2 with max=100 should not be full");
}

// Test get_position after reordering
#[test]
fn test_get_position_after_reorder() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 5, false, game_address);

    game_admin.set_score(1, 50);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 90);

    // Submit in different order than final ranking
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 50, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 3, 90, 1);

    // Final order: 3(90), 2(80), 1(50)
    assert!(leaderboard.get_position(TOURNAMENT_1, 3) == Option::Some(1), "ID 3 at pos 1");
    assert!(leaderboard.get_position(TOURNAMENT_1, 2) == Option::Some(2), "ID 2 at pos 2");
    assert!(leaderboard.get_position(TOURNAMENT_1, 1) == Option::Some(3), "ID 1 at pos 3");
}

// Test tournament length tracking
#[test]
fn test_length_tracking_accuracy() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should start at 0");

    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 1, "Should be 1");

    game_admin.set_score(2, 80);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 2, "Should be 2");

    // Clear
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(TOURNAMENT_1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 0, "Should be 0 after clear");
}

// Test submitting to multiple tournaments simultaneously
#[test]
fn test_submit_to_many_tournaments() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    // Configure 5 tournaments
    let mut t: u64 = 1;
    loop {
        if t > 5 {
            break;
        }
        configure_tournament_with_game(admin, t, 10, false, game_address);
        t += 1;
    }

    game_admin.set_score(1, 100);

    // Submit same token to all tournaments
    let mut t: u64 = 1;
    loop {
        if t > 5 {
            break;
        }
        let result = leaderboard.submit_score(t, 1, 100, 1);
        match result {
            LeaderboardResult::Success => {},
            _ => panic!("Should succeed in all tournaments"),
        }
        t += 1;
    }

    // Verify all have 1 entry
    let mut t: u64 = 1;
    loop {
        if t > 5 {
            break;
        }
        assert!(leaderboard.get_leaderboard_length(t) == 1, "Each tournament should have 1 entry");
        t += 1;
    };
}

// Test submitting with position exactly at end
#[test]
fn test_submit_at_exact_end() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 10, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    game_admin.set_score(3, 60);

    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Submit at position 3 (exact end)
    let result = leaderboard.submit_score(TOURNAMENT_1, 3, 60, 3);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed at exact end"),
    }

    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 3, "Should have 3 entries");
}

// Test reconfigure during active tournament
#[test]
fn test_reconfigure_with_entries() {
    let (leaderboard, admin) = deploy_mock_leaderboard();
    let (game_address, game_admin) = deploy_mock_game_details();

    configure_tournament_with_game(admin, TOURNAMENT_1, 5, false, game_address);

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 1, 100, 1);
    let _ = leaderboard.submit_score(TOURNAMENT_1, 2, 80, 2);

    // Reconfigure to smaller size (entries remain, but new max is smaller)
    configure_tournament_with_game(admin, TOURNAMENT_1, 2, true, game_address);

    // Entries still exist
    assert!(leaderboard.get_leaderboard_length(TOURNAMENT_1) == 2, "Entries should remain");

    // New config should be reflected
    let config = leaderboard.get_tournament_config(TOURNAMENT_1);
    assert!(config.max_entries == 2, "Max entries should be updated");
    assert!(config.ascending == true, "Ascending should be updated");
}
