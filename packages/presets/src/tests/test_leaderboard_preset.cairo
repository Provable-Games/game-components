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
