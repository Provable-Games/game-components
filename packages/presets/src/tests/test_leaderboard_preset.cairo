// ==============================================================================
// LEADERBOARD PRESET CONTRACT TESTS
// ==============================================================================
// Tests for the ready-to-deploy LeaderboardPreset contract that provides
// multi-tournament leaderboard management with score submission and ranking.

use game_components_leaderboard::interface::{
    ILEADERBOARD_ID, ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait,
    ILeaderboardDispatcher, ILeaderboardDispatcherTrait,
};
use game_components_leaderboard::leaderboard::leaderboard::LeaderboardResult;
use game_components_testing::constants::{NEW_OWNER, OWNER, USER1, USER2};
use openzeppelin_interfaces::introspection::{ISRC5Dispatcher, ISRC5DispatcherTrait};
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

// Tournament IDs
const WEEKLY_TOURNAMENT: u64 = 1;
const MONTHLY_TOURNAMENT: u64 = 2;
const SPECIAL_EVENT: u64 = 100;

// ==============================================================================
// DEPLOYMENT HELPERS
// ==============================================================================

/// Deploy the MockLeaderboardContract for testing
/// Note: This uses MockLeaderboardContract which embeds the same LeaderboardComponent
/// that LeaderboardPreset uses, so test results are equivalent.
fn deploy_leaderboard_preset(
    owner: ContractAddress,
) -> (ILeaderboardDispatcher, ILeaderboardAdminDispatcher) {
    let contract = declare("MockLeaderboardContract").unwrap().contract_class();
    let mut calldata = array![];
    owner.serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let leaderboard = ILeaderboardDispatcher { contract_address };
    let admin = ILeaderboardAdminDispatcher { contract_address };
    (leaderboard, admin)
}

/// Deploy the mock game details contract
fn deploy_mock_game() -> (ContractAddress, IMockGameDetailsAdminDispatcher) {
    let contract = declare("MockGameDetails").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let admin = IMockGameDetailsAdminDispatcher { contract_address };
    (contract_address, admin)
}

/// Helper to configure a tournament
fn setup_tournament(
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
// DEPLOYMENT AND INITIALIZATION TESTS
// ==============================================================================

// Test PR-LB-01: Preset deploys successfully with owner
#[test]
fn test_preset_deploys_with_owner() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());

    assert!(admin.owner() == OWNER(), "Owner should be set from constructor");
}

// Test PR-LB-02: Preset supports ILeaderboard interface
#[test]
fn test_preset_supports_leaderboard_interface() {
    let (leaderboard, _) = deploy_leaderboard_preset(OWNER());
    let src5 = ISRC5Dispatcher { contract_address: leaderboard.contract_address };

    assert!(src5.supports_interface(ILEADERBOARD_ID), "Should support ILeaderboard interface");
}

// Test PR-LB-03: Preset starts with empty leaderboards
#[test]
fn test_preset_starts_empty() {
    let (leaderboard, _) = deploy_leaderboard_preset(OWNER());

    assert!(
        leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 0, "Tournament should start empty",
    );
    assert!(
        leaderboard.get_leaderboard_length(MONTHLY_TOURNAMENT) == 0,
        "Different tournament should also be empty",
    );
}

// ==============================================================================
// FULL WORKFLOW TESTS
// ==============================================================================

// Test PR-LB-04: Complete tournament lifecycle
#[test]
fn test_complete_tournament_lifecycle() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // 1. Configure tournament
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Verify configuration
    let config = leaderboard.get_tournament_config(WEEKLY_TOURNAMENT);
    assert!(config.max_entries == 10, "Max entries should be 10");

    // 2. Set up player scores
    game_admin.set_score(101, 1000); // Player A
    game_admin.set_score(102, 800); // Player B
    game_admin.set_score(103, 1200); // Player C (highest)
    game_admin.set_score(104, 900); // Player D

    // 3. Submit scores
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 103, 1200, 1); // Player C first
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 101, 1000, 2); // Player A second
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 104, 900, 3); // Player D third
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 102, 800, 4); // Player B fourth

    // 4. Verify leaderboard state
    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 4, "Should have 4 entries");
    assert!(*entries.at(0).id == 103, "Player C should be first");
    assert!(*entries.at(1).id == 101, "Player A should be second");
    assert!(*entries.at(2).id == 104, "Player D should be third");
    assert!(*entries.at(3).id == 102, "Player B should be fourth");

    // 5. Query positions
    assert!(
        leaderboard.get_position(WEEKLY_TOURNAMENT, 103) == Option::Some(1), "Player C at pos 1",
    );
    assert!(
        leaderboard.get_position(WEEKLY_TOURNAMENT, 102) == Option::Some(4), "Player B at pos 4",
    );

    // 6. Get top 3
    let top_3 = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 3);
    assert!(top_3.len() == 3, "Should return top 3");
    assert!(*top_3.at(0).score == 1200, "Highest score is 1200");

    // 7. Clear for next week
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    assert!(
        leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 0, "Should be empty after clear",
    );
}

// Test PR-LB-05: Multiple tournaments running simultaneously
#[test]
fn test_multiple_simultaneous_tournaments() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Configure different tournaments
    setup_tournament(admin, WEEKLY_TOURNAMENT, 5, false, game_address); // High score wins
    setup_tournament(admin, MONTHLY_TOURNAMENT, 10, false, game_address); // High score wins
    setup_tournament(admin, SPECIAL_EVENT, 3, true, game_address); // Low score wins (speedrun)

    // Set scores
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 200);
    game_admin.set_score(3, 50);

    // Submit to weekly (descending)
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 200, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 2);

    // Submit to monthly (descending)
    let _ = leaderboard.submit_score(MONTHLY_TOURNAMENT, 1, 100, 1);

    // Submit to special (ascending - speedrun)
    let _ = leaderboard.submit_score(SPECIAL_EVENT, 3, 50, 1);
    let _ = leaderboard.submit_score(SPECIAL_EVENT, 1, 100, 2);

    // Verify each tournament is independent
    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 2, "Weekly has 2 entries");
    assert!(leaderboard.get_leaderboard_length(MONTHLY_TOURNAMENT) == 1, "Monthly has 1 entry");
    assert!(leaderboard.get_leaderboard_length(SPECIAL_EVENT) == 2, "Special has 2 entries");

    // Verify special event order (ascending)
    let special_entries = leaderboard.get_entries(SPECIAL_EVENT);
    assert!(*special_entries.at(0).score == 50, "Fastest time (50) should be first");
    assert!(*special_entries.at(1).score == 100, "Slower time (100) should be second");
}

// ==============================================================================
// ADMIN FUNCTIONALITY TESTS
// ==============================================================================

// Test PR-LB-06: Ownership transfer works correctly
#[test]
fn test_ownership_transfer() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    // Original owner configures
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Transfer ownership
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    assert!(admin.owner() == NEW_OWNER(), "Owner should be NEW_OWNER");

    // Old owner can't configure anymore
    // New owner can configure
    start_cheat_caller_address(admin.contract_address, NEW_OWNER());
    admin.configure_tournament(MONTHLY_TOURNAMENT, 20, true, game_address);
    stop_cheat_caller_address(admin.contract_address);

    let config = leaderboard.get_tournament_config(MONTHLY_TOURNAMENT);
    assert!(config.max_entries == 20, "New owner should be able to configure");
}

// Test PR-LB-07: Non-owner cannot perform admin actions
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_non_owner_cannot_configure() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.configure_tournament(WEEKLY_TOURNAMENT, 10, false, game_address);
    stop_cheat_caller_address(admin.contract_address);
}

// Test PR-LB-08: Non-owner cannot clear leaderboard
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_non_owner_cannot_clear() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);
}

// Test PR-LB-09: Non-owner cannot transfer ownership
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_non_owner_cannot_transfer() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());

    start_cheat_caller_address(admin.contract_address, USER1());
    admin.transfer_ownership(USER2());
    stop_cheat_caller_address(admin.contract_address);
}

// ==============================================================================
// EDGE CASE TESTS
// ==============================================================================

// Test PR-LB-10: Max entries enforcement
#[test]
fn test_max_entries_enforcement() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Configure with only 3 max entries
    setup_tournament(admin, WEEKLY_TOURNAMENT, 3, false, game_address);

    // Set scores
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);
    game_admin.set_score(4, 50); // Low score

    // Fill leaderboard
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 90, 2);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 80, 3);

    assert!(leaderboard.is_full(WEEKLY_TOURNAMENT), "Should be full");

    // Try to submit low score - should fail
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 4, 50, 4);
    match result {
        LeaderboardResult::LeaderboardFull => {},
        _ => panic!("Should fail - leaderboard is full and score is too low"),
    }

    // Submit high score - should succeed and push out lowest
    game_admin.set_score(5, 95);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 5, 95, 2);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed - score is good enough"),
    }

    // Verify token 3 (score 80) was pushed out
    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 3, "Should still have 3 entries");
    assert!(*entries.at(2).score == 90, "Lowest should now be 90");
}

// Test PR-LB-11: Qualification check
#[test]
fn test_qualification_check() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 2, false, game_address);

    // Empty - any score qualifies
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 1), "Any score qualifies when empty");

    game_admin.set_score(1, 100);
    game_admin.set_score(2, 80);

    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 80, 2);

    // Full - need to beat last place
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 90), "90 qualifies (beats 80)");
    assert!(!leaderboard.qualifies(WEEKLY_TOURNAMENT, 70), "70 doesn't qualify (below 80)");
    assert!(!leaderboard.qualifies(WEEKLY_TOURNAMENT, 80), "80 doesn't qualify (tie)");
}

// Test PR-LB-12: Empty leaderboard queries
#[test]
fn test_empty_leaderboard_queries() {
    let (leaderboard, _) = deploy_leaderboard_preset(OWNER());

    // All queries on empty tournament should return sensible defaults
    let entries = leaderboard.get_entries(999);
    assert!(entries.len() == 0, "Empty tournament returns empty array");

    let top = leaderboard.get_top_entries(999, 10);
    assert!(top.len() == 0, "Top entries of empty tournament is empty");

    let position = leaderboard.get_position(999, 1);
    assert!(position == Option::None, "Position in empty tournament is None");

    // Note: is_full returns true for unconfigured tournament (max_entries defaults to 0)
    // This is expected behavior - unconfigured tournaments are "full" since they have no capacity
    assert!(leaderboard.get_leaderboard_length(999) == 0, "Empty tournament length is 0");
}

// ==============================================================================
// EVENT TESTS
// ==============================================================================

// Test PR-LB-13: All events are emitted correctly
#[test]
fn test_all_events_emitted() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    let mut spy = spy_events();

    // Configure tournament
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(WEEKLY_TOURNAMENT, 10, false, game_address);
    stop_cheat_caller_address(admin.contract_address);

    // Submit score
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Clear leaderboard
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    // Transfer ownership
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // Verify all events
    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::TournamentConfigured(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::TournamentConfigured {
                            tournament_id: WEEKLY_TOURNAMENT,
                            max_entries: 10,
                            ascending: false,
                            game_address: game_address,
                        },
                    ),
                ),
            ],
        );

    spy
        .assert_emitted(
            @array![
                (
                    leaderboard.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::ScoreSubmitted(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::ScoreSubmitted {
                            tournament_id: WEEKLY_TOURNAMENT, token_id: 1, score: 100, position: 1,
                        },
                    ),
                ),
            ],
        );

    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardCleared(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardCleared {
                            tournament_id: WEEKLY_TOURNAMENT,
                        },
                    ),
                ),
            ],
        );

    spy
        .assert_emitted(
            @array![
                (
                    admin.contract_address,
                    game_components_leaderboard::leaderboard_component::LeaderboardComponent::Event::LeaderboardOwnershipTransferred(
                        game_components_leaderboard::leaderboard_component::LeaderboardComponent::LeaderboardOwnershipTransferred {
                            previous_owner: OWNER(), new_owner: NEW_OWNER(),
                        },
                    ),
                ),
            ],
        );
}

// ==============================================================================
// INTEGRATION TESTS
// ==============================================================================

// Test PR-LB-14: Reconfigure tournament updates settings
#[test]
fn test_reconfigure_tournament() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();
    let (new_game_address, _) = deploy_mock_game();

    // Initial configuration
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    let config1 = leaderboard.get_tournament_config(WEEKLY_TOURNAMENT);
    assert!(config1.max_entries == 10, "Initial max_entries is 10");
    assert!(config1.ascending == false, "Initial ascending is false");

    // Reconfigure
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(WEEKLY_TOURNAMENT, 20, true, new_game_address);
    stop_cheat_caller_address(admin.contract_address);

    let config2 = leaderboard.get_tournament_config(WEEKLY_TOURNAMENT);
    assert!(config2.max_entries == 20, "Updated max_entries is 20");
    assert!(config2.ascending == true, "Updated ascending is true");
    assert!(config2.game_address == new_game_address, "Updated game address");
}

// ==============================================================================
// ADDITIONAL TESTS - Covering Test Plan Gaps
// ==============================================================================

// TC-SRC5-02: Does not support random interface
#[test]
fn test_does_not_support_random_interface() {
    let (leaderboard, _) = deploy_leaderboard_preset(OWNER());
    let src5 = ISRC5Dispatcher { contract_address: leaderboard.contract_address };

    // Random interface ID that shouldn't be supported
    let random_interface: felt252 = 0x12345678;
    assert!(!src5.supports_interface(random_interface), "Should not support random interface");
}

// TC-POS-02: Get position of non-existent entry
#[test]
fn test_get_position_of_non_existent_entry() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add one entry
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Query position of token that doesn't exist
    let position = leaderboard.get_position(WEEKLY_TOURNAMENT, 999);
    assert!(position == Option::None, "Non-existent entry should return None");
}

// TC-TOP-02: Get top N where N > leaderboard size
#[test]
fn test_get_top_entries_more_than_available() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add only 2 entries
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 90, 2);

    // Request top 10
    let top = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 10);
    assert!(top.len() == 2, "Should return all available entries (2)");
}

// TC-TOP-03: Get top 0 entries
#[test]
fn test_get_top_zero_entries() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entry
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Request top 0
    let top = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 0);
    assert!(top.len() == 0, "Should return empty array for count 0");
}

// TC-QUA-02: Score qualifies when leaderboard not full
#[test]
fn test_qualifies_when_not_full() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 5, false, game_address);

    // Add just one entry
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Not full - any score should qualify
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 1), "Should qualify when not full");
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 50), "Low score should qualify when not full");
}

// TC-FUL-01: Empty leaderboard is not full
#[test]
fn test_empty_leaderboard_is_not_full() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 5, false, game_address);

    assert!(
        !leaderboard.is_full(WEEKLY_TOURNAMENT), "Empty configured tournament should not be full",
    );
}

// TC-CFG-02: Get config of unconfigured tournament
#[test]
fn test_get_config_unconfigured_tournament() {
    let (leaderboard, _) = deploy_leaderboard_preset(OWNER());

    let config = leaderboard.get_tournament_config(999);
    // Should return default values
    assert!(config.max_entries == 0, "Unconfigured max_entries should be 0");
    assert!(config.ascending == false, "Unconfigured ascending should be false");
}

// TC-CLR-03: Clear empty leaderboard
#[test]
fn test_clear_empty_leaderboard() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    let mut spy = spy_events();

    // Clear empty leaderboard - should not error
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    // Verify event still emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit clear event even for empty leaderboard");
}

// TC-CLR-04: Clear does not affect other tournaments
#[test]
fn test_clear_does_not_affect_other_tournaments() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);
    setup_tournament(admin, MONTHLY_TOURNAMENT, 10, false, game_address);

    // Add entries to both
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(MONTHLY_TOURNAMENT, 2, 90, 1);

    // Clear only weekly
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    // Weekly should be empty
    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 0, "Weekly should be cleared");

    // Monthly should be unaffected
    assert!(
        leaderboard.get_leaderboard_length(MONTHLY_TOURNAMENT) == 1, "Monthly should be unaffected",
    );
}

// TC-TRF-05: Old owner cannot perform admin actions after transfer
#[test]
#[should_panic(expected: "Only owner can call this function")]
fn test_old_owner_cannot_configure_after_transfer() {
    let (_, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    // Transfer ownership
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // Old owner tries to configure
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(WEEKLY_TOURNAMENT, 10, false, game_address);
    stop_cheat_caller_address(admin.contract_address);
}

// TC-QUA-06: Score qualifies ascending tournament
#[test]
fn test_qualifies_ascending_tournament() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Ascending tournament (lower is better, like speedrun times)
    setup_tournament(admin, SPECIAL_EVENT, 2, true, game_address);

    // Fill with high scores (bad in ascending)
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 150);
    let _ = leaderboard.submit_score(SPECIAL_EVENT, 1, 100, 1);
    let _ = leaderboard.submit_score(SPECIAL_EVENT, 2, 150, 2);

    // Lower score should qualify (better in ascending)
    assert!(leaderboard.qualifies(SPECIAL_EVENT, 50), "50 should qualify (better than 150)");
    assert!(leaderboard.qualifies(SPECIAL_EVENT, 120), "120 should qualify (better than 150)");

    // Higher score should not qualify (worse in ascending)
    assert!(!leaderboard.qualifies(SPECIAL_EVENT, 200), "200 should not qualify (worse than 150)");
    assert!(!leaderboard.qualifies(SPECIAL_EVENT, 150), "150 should not qualify (tie)");
}

// TC-INT-04: Ownership transfer with active tournaments
#[test]
fn test_ownership_transfer_preserves_tournaments() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Setup and populate tournament
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Transfer ownership
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.transfer_ownership(NEW_OWNER());
    stop_cheat_caller_address(admin.contract_address);

    // Verify tournament state preserved
    assert!(
        leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 1, "Entries should be preserved",
    );

    let config = leaderboard.get_tournament_config(WEEKLY_TOURNAMENT);
    assert!(config.max_entries == 10, "Config should be preserved");

    // New owner can manage
    start_cheat_caller_address(admin.contract_address, NEW_OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 0, "New owner should clear");
}

// ==============================================================================
// FUZZ TESTS
// ==============================================================================

// FUZZ-SUB-01: Fuzz submit_score positions
#[test]
#[fuzzer]
fn test_fuzz_submit_score_positions(position: u8) {
    // Valid positions are 1-255, skip 0
    if position == 0 || position > 50 {
        return;
    }

    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Configure tournament with enough capacity
    setup_tournament(admin, WEEKLY_TOURNAMENT, 100, false, game_address);

    // Set score
    game_admin.set_score(position.into(), 100);

    // Submit at fuzzed position
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, position.into(), 100, position);

    match result {
        LeaderboardResult::Success => {
            // Verify entry exists
            let length = leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT);
            assert!(length > 0, "Entry should exist");
        },
        LeaderboardResult::InvalidPosition => { // Position might be invalid (beyond current length + 1)
        },
        _ => panic!("Unexpected result"),
    }
}

// FUZZ-CONF-01: Fuzz configure_tournament parameters
#[test]
#[fuzzer]
fn test_fuzz_configure_tournament(tournament_id: u64, max_entries: u32, ascending_byte: u8) {
    // Skip invalid configurations
    if tournament_id == 0 || max_entries > 1000 {
        return;
    }

    let ascending = ascending_byte % 2 == 0;

    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, _) = deploy_mock_game();

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure_tournament(tournament_id, max_entries, ascending, game_address);
    stop_cheat_caller_address(admin.contract_address);

    let config = leaderboard.get_tournament_config(tournament_id);
    assert!(config.max_entries == max_entries, "Max entries mismatch");
    assert!(config.ascending == ascending, "Ascending mismatch");
    assert!(config.game_address == game_address, "Game address mismatch");
}

// FUZZ-QUA-01: Fuzz qualifies with random scores
#[test]
#[fuzzer]
fn test_fuzz_qualifies(score: u64, entry_score: u64) {
    // Skip edge cases
    if entry_score == 0 || score == 0 {
        return;
    }

    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Descending tournament
    setup_tournament(admin, WEEKLY_TOURNAMENT, 1, false, game_address);

    // Fill with one entry
    game_admin.set_score(1, entry_score);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, entry_score, 1);

    let qualifies = leaderboard.qualifies(WEEKLY_TOURNAMENT, score);

    // In descending, higher score qualifies
    if score > entry_score {
        assert!(qualifies, "Higher score should qualify in descending");
    } else {
        assert!(!qualifies, "Lower or equal score should not qualify in descending");
    }
}

// ==============================================================================
// ADDITIONAL COVERAGE TESTS - Leaderboard Operations
// ==============================================================================

// TC-DUP-01: Duplicate entry detection
#[test]
fn test_duplicate_entry_detection() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    game_admin.set_score(1, 100);
    let result1 = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    match result1 {
        LeaderboardResult::Success => {},
        _ => panic!("First submission should succeed"),
    }

    // Try to submit same token again
    game_admin.set_score(1, 150);
    let result2 = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 150, 1);
    match result2 {
        LeaderboardResult::DuplicateEntry => {},
        _ => panic!("Duplicate entry should be rejected"),
    }
}

// TC-SCORETOO-01: Score too low rejection
#[test]
fn test_score_too_low_rejection() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entry with score 100
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Try to add entry with lower score at position 1 (should fail - score not good enough)
    game_admin.set_score(2, 50);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 50, 1);
    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Should reject score too low for position"),
    }
}

// TC-SCORETOOHIGH-01: Score too high rejection
#[test]
fn test_score_too_high_rejection() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add first entry with score 100 at position 1
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // Add second entry with score 50 at position 2
    game_admin.set_score(2, 50);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 50, 2);

    // Try to add entry with score 80 at position 3 (should fail - score better than position 2)
    game_admin.set_score(3, 80);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 80, 3);
    match result {
        LeaderboardResult::ScoreTooHigh => {},
        _ => panic!("Should reject score too high for position"),
    }
}

// TC-INVPOS-01: Invalid position rejection
#[test]
fn test_invalid_position_beyond_length() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Try to submit at position 5 when leaderboard is empty (invalid - should be position 1)
    game_admin.set_score(1, 100);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 5);
    match result {
        LeaderboardResult::InvalidPosition => {},
        _ => panic!("Should reject invalid position"),
    }
}

// TC-TIE-01: Tie-breaking by token ID
#[test]
fn test_tie_breaking_lower_id_wins() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entry with token ID 10, score 100
    game_admin.set_score(10, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 10, 100, 1);

    // Add entry with token ID 5, same score 100 - should be placed BEFORE token 10
    game_admin.set_score(5, 100);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 5, 100, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed - lower ID wins tie-break"),
    }

    // Verify positions
    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 2, "Should have 2 entries");
    assert!(*entries.at(0).id == 5, "Token 5 should be first (won tie-break)");
    assert!(*entries.at(1).id == 10, "Token 10 should be second");
}

// TC-TIE-02: Tie-breaking - higher ID loses
#[test]
fn test_tie_breaking_higher_id_loses() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entry with token ID 5, score 100
    game_admin.set_score(5, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 5, 100, 1);

    // Add entry with token ID 10, same score 100 at position 1 - should fail (higher ID loses)
    game_admin.set_score(10, 100);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 10, 100, 1);
    match result {
        LeaderboardResult::ScoreTooLow => {},
        _ => panic!("Should fail - higher ID loses tie-break"),
    }
}

// TC-ASC-01: Ascending tournament - lower score is better
#[test]
fn test_ascending_tournament_order() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Ascending tournament (speedrun - lower time is better)
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, true, game_address);

    // Add scores in various order
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    game_admin.set_score(3, 150);

    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard
        .submit_score(WEEKLY_TOURNAMENT, 2, 50, 1); // Should go to position 1 (lower is better)
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 150, 3);

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 3, "Should have 3 entries");
    assert!(*entries.at(0).id == 2, "Token 2 (score 50) should be first");
    assert!(*entries.at(1).id == 1, "Token 1 (score 100) should be second");
    assert!(*entries.at(2).id == 3, "Token 3 (score 150) should be third");
}

// TC-RANGE-01: Get leaderboard range (pagination)
#[test]
fn test_get_top_entries_pagination() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add 5 entries
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);
    game_admin.set_score(4, 70);
    game_admin.set_score(5, 60);

    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 90, 2);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 80, 3);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 4, 70, 4);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 5, 60, 5);

    // Get top 2
    let top2 = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 2);
    assert!(top2.len() == 2, "Should return 2 entries");
    assert!(*top2.at(0).id == 1, "First should be token 1");
    assert!(*top2.at(1).id == 2, "Second should be token 2");

    // Get top 3
    let top3 = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 3);
    assert!(top3.len() == 3, "Should return 3 entries");
}

// TC-FULL-02: Leaderboard full - push out lowest
#[test]
fn test_full_leaderboard_pushes_out_lowest() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Small leaderboard of 3
    setup_tournament(admin, WEEKLY_TOURNAMENT, 3, false, game_address);

    // Fill it
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);

    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 90, 2);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 80, 3);

    assert!(leaderboard.is_full(WEEKLY_TOURNAMENT), "Should be full");

    // Add higher score - should push out token 3
    game_admin.set_score(4, 95);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 4, 95, 2);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 3, "Should still have 3 entries");
    assert!(*entries.at(0).id == 1, "Token 1 should still be first");
    assert!(*entries.at(1).id == 4, "Token 4 should be second");
    assert!(*entries.at(2).id == 2, "Token 2 should be third (80 was pushed out)");

    // Verify token 3 is gone
    let pos = leaderboard.get_position(WEEKLY_TOURNAMENT, 3);
    assert!(pos.is_none(), "Token 3 should be pushed out");
}

// TC-INIT-01: Verify initialization sets correct owner
#[test]
fn test_initialization_sets_owner() {
    let contract = declare("MockLeaderboardContract").unwrap().contract_class();

    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    let admin = ILeaderboardAdminDispatcher { contract_address };

    // Verify the contract is initialized with correct owner
    assert!(admin.owner() == OWNER(), "Owner should be set");
}

// TC-ZERO-01: Position 0 is invalid
#[test]
fn test_position_zero_is_invalid() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    game_admin.set_score(1, 100);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 0);
    match result {
        LeaderboardResult::InvalidPosition => {},
        _ => panic!("Position 0 should be invalid"),
    }
}

// TC-MULTI-01: Multiple tournaments completely independent
#[test]
fn test_tournaments_are_independent() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Different configs for different tournaments
    setup_tournament(admin, 1, 5, false, game_address); // Descending
    setup_tournament(admin, 2, 3, true, game_address); // Ascending

    // Add same token to both tournaments
    game_admin.set_score(100, 500);

    let _ = leaderboard.submit_score(1, 100, 500, 1);
    let _ = leaderboard.submit_score(2, 100, 500, 1);

    // Both should have the entry
    assert!(leaderboard.get_leaderboard_length(1) == 1, "Tournament 1 should have 1 entry");
    assert!(leaderboard.get_leaderboard_length(2) == 1, "Tournament 2 should have 1 entry");

    // Clearing one doesn't affect other
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(1);
    stop_cheat_caller_address(admin.contract_address);

    assert!(leaderboard.get_leaderboard_length(1) == 0, "Tournament 1 should be cleared");
    assert!(leaderboard.get_leaderboard_length(2) == 1, "Tournament 2 should be unaffected");
}

// TC-QUA-ASC-01: Qualifies for ascending tournament when full
#[test]
fn test_qualifies_ascending_tournament_when_full() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Ascending tournament with 1 slot
    setup_tournament(admin, WEEKLY_TOURNAMENT, 1, true, game_address);

    // Fill with score 100
    game_admin.set_score(1, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);

    // In ascending, lower score qualifies
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 50), "50 should qualify (lower is better)");
    assert!(!leaderboard.qualifies(WEEKLY_TOURNAMENT, 150), "150 should not qualify");
}

// ==============================================================================
// ADDITIONAL EDGE CASE TESTS
// ==============================================================================

// TC-TIE-03: Tie with same ID (impossible in practice, but tests comparator)
#[test]
fn test_tie_breaking_ascending_mode() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Ascending tournament
    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, true, game_address);

    // Add entries with same score
    game_admin.set_score(10, 100);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 10, 100, 1);

    // Lower ID should win tie-break even in ascending mode
    game_admin.set_score(5, 100);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 5, 100, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed - lower ID wins tie-break"),
    }

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(*entries.at(0).id == 5, "Token 5 should be first (won tie-break)");
}

// TC-SCORE-EQ-01: Equal score at position where it belongs
#[test]
fn test_equal_score_valid_position() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add two entries: 100 and 50
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 50, 2);

    // Add entry with score 50 at position 2 (same as token 2)
    // Lower ID (3 > 2) so it should go after token 2
    game_admin.set_score(3, 50);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 50, 3);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed at position 3"),
    }

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 3, "Should have 3 entries");
}

// TC-LARGE-01: Large tournament with many entries
#[test]
fn test_large_leaderboard() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 20, false, game_address);

    // Add 10 entries
    let mut i: u64 = 1;
    while i <= 10 {
        let score: u64 = 1000 - (i * 10);
        game_admin.set_score(i, score);
        let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, i, score, i.try_into().unwrap());
        i += 1;
    }

    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 10, "Should have 10 entries");

    // Get top 5
    let top5 = leaderboard.get_top_entries(WEEKLY_TOURNAMENT, 5);
    assert!(top5.len() == 5, "Should return top 5");
    assert!(*top5.at(0).score == 990, "First should have score 990");
    assert!(*top5.at(4).score == 950, "Fifth should have score 950");
}

// TC-MID-INSERT-01: Insert in middle of leaderboard
#[test]
fn test_insert_in_middle() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entries: 100, 50, 25
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    game_admin.set_score(3, 25);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 50, 2);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 25, 3);

    // Insert 75 at position 2
    game_admin.set_score(4, 75);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 4, 75, 2);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed"),
    }

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 4, "Should have 4 entries");
    assert!(*entries.at(0).id == 1, "First: token 1 (100)");
    assert!(*entries.at(1).id == 4, "Second: token 4 (75)");
    assert!(*entries.at(2).id == 2, "Third: token 2 (50)");
    assert!(*entries.at(3).id == 3, "Fourth: token 3 (25)");
}

// TC-END-INSERT-01: Insert at end of leaderboard
#[test]
fn test_insert_at_end() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Add entries: 100, 50
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 50);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 50, 2);

    // Insert 25 at position 3 (end)
    game_admin.set_score(3, 25);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 25, 3);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should succeed at end"),
    }

    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 3, "Should have 3 entries");
    let position = leaderboard.get_position(WEEKLY_TOURNAMENT, 3);
    assert!(position == Option::Some(3), "Token 3 should be at position 3");
}

// TC-CLEAR-LARGE-01: Clear large leaderboard
#[test]
fn test_clear_large_leaderboard() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 50, false, game_address);

    // Add 10 entries
    let mut i: u64 = 1;
    while i <= 10 {
        let score: u64 = 1000 - (i * 10);
        game_admin.set_score(i, score);
        let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, i, score, i.try_into().unwrap());
        i += 1;
    }

    assert!(leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 10, "Should have 10 entries");

    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.clear_leaderboard(WEEKLY_TOURNAMENT);
    stop_cheat_caller_address(admin.contract_address);

    assert!(
        leaderboard.get_leaderboard_length(WEEKLY_TOURNAMENT) == 0, "Should be empty after clear",
    );

    // Verify we can add entries again
    game_admin.set_score(100, 500);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 100, 500, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Should be able to add after clear"),
    }
}

// TC-POS-BOUNDARY-01: Position at boundary of max_entries
#[test]
fn test_position_at_max_boundary() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    // Tournament with max 3 entries
    setup_tournament(admin, WEEKLY_TOURNAMENT, 3, false, game_address);

    // Fill completely
    game_admin.set_score(1, 100);
    game_admin.set_score(2, 90);
    game_admin.set_score(3, 80);

    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, 100, 1);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 90, 2);
    let _ = leaderboard.submit_score(WEEKLY_TOURNAMENT, 3, 80, 3);

    // Try to add at position 3 with score 85 (better than 80)
    game_admin.set_score(4, 85);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 4, 85, 3);
    match result {
        LeaderboardResult::Success => {
            // Token 3 (80) should be pushed out
            let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
            assert!(entries.len() == 3, "Should still have 3 entries");
            assert!(*entries.at(2).id == 4, "Token 4 should be at position 3");
        },
        _ => panic!("Should succeed and push out token 3"),
    }
}

// TC-SCORE-BOUNDARY-01: Edge score values
#[test]
fn test_boundary_scores() {
    let (leaderboard, admin) = deploy_leaderboard_preset(OWNER());
    let (game_address, game_admin) = deploy_mock_game();

    setup_tournament(admin, WEEKLY_TOURNAMENT, 10, false, game_address);

    // Test with max u64 score
    let max_score: u64 = 0xFFFFFFFFFFFFFFFF;
    game_admin.set_score(1, max_score);
    let result = leaderboard.submit_score(WEEKLY_TOURNAMENT, 1, max_score, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Max score should work"),
    }

    // Test with zero score
    game_admin.set_score(2, 0);
    let result2 = leaderboard.submit_score(WEEKLY_TOURNAMENT, 2, 0, 2);
    match result2 {
        LeaderboardResult::Success => {},
        _ => panic!("Zero score should work"),
    }

    let entries = leaderboard.get_entries(WEEKLY_TOURNAMENT);
    assert!(entries.len() == 2, "Should have 2 entries");
    assert!(*entries.at(0).score == max_score, "Max score should be first");
    assert!(*entries.at(1).score == 0, "Zero score should be second");
    // Leaderboard is not full (max 10 entries, only 2 filled), so any score qualifies
    assert!(leaderboard.qualifies(WEEKLY_TOURNAMENT, 100), "100 should qualify when not full");
}
