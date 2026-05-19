// Gas benchmark for leaderboard overwrite operations
// Verifies O(1) insertion regardless of position or leaderboard size

use game_components_metagame::leaderboard::interface::{
    ILeaderboardAdminDispatcher, ILeaderboardAdminDispatcherTrait,
};
use game_components_metagame::leaderboard::leaderboard::leaderboard::LeaderboardResult;
use game_components_test_common::mocks::mock_leaderboard_contract::{
    IMockLeaderboardTestDispatcher, IMockLeaderboardTestDispatcherTrait,
};
use game_components_testing::constants::OWNER;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
use starknet::ContractAddress;
use super::mocks::mock_game_details::{
    IMockGameDetailsAdminDispatcher, IMockGameDetailsAdminDispatcherTrait,
};

fn deploy() -> (
    IMockLeaderboardTestDispatcher,
    ILeaderboardAdminDispatcher,
    ContractAddress,
    IMockGameDetailsAdminDispatcher,
) {
    let contract = declare("MockLeaderboardContract").unwrap().contract_class();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    let (addr, _) = contract.deploy(@calldata).unwrap();

    let game_contract = declare("MockGameDetails").unwrap().contract_class();
    let (game_addr, _) = game_contract.deploy(@array![]).unwrap();

    (
        IMockLeaderboardTestDispatcher { contract_address: addr },
        ILeaderboardAdminDispatcher { contract_address: addr },
        game_addr,
        IMockGameDetailsAdminDispatcher { contract_address: game_addr },
    )
}

/// Fill a leaderboard to `size` entries sequentially.
fn fill_leaderboard(
    lb: IMockLeaderboardTestDispatcher,
    admin: ILeaderboardAdminDispatcher,
    game_addr: ContractAddress,
    game_admin: IMockGameDetailsAdminDispatcher,
    size: u32,
) {
    start_cheat_caller_address(admin.contract_address, OWNER());
    admin.configure(1, size + 1, false, game_addr);
    stop_cheat_caller_address(admin.contract_address);

    let mut i: u32 = 1;
    while i <= size {
        let token_id: felt252 = i.into();
        let score: u64 = (size - i + 1).into();
        game_admin.set_score(token_id, score);
        let result = lb.submit_score(1, token_id, score, i);
        match result {
            LeaderboardResult::Success => {},
            _ => panic!("Fill failed at position {}", i),
        }
        i += 1;
    };
}

// ==========================================================================
// BASELINE: fill only (no final overwrite)
// ==========================================================================

#[test]
fn test_baseline_fill_100() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 100);
}

#[test]
fn test_baseline_fill_500() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 500);
}

// ==========================================================================
// OVERWRITE AT POSITION 1 (was worst-case with shifting, now O(1))
// ==========================================================================

#[test]
fn test_overwrite_first_100() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 100);

    let token_id: felt252 = 999;
    let score: u64 = 9999;
    game_admin.set_score(token_id, score);
    let result = lb.submit_score(1, token_id, score, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Overwrite at #1 failed"),
    }
}

#[test]
fn test_overwrite_first_500() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 500);

    let token_id: felt252 = 999;
    let score: u64 = 9999;
    game_admin.set_score(token_id, score);
    let result = lb.submit_score(1, token_id, score, 1);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Overwrite at #1 failed"),
    }
}

// ==========================================================================
// APPEND AT LAST POSITION
// ==========================================================================

#[test]
fn test_append_last_100() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 100);

    let token_id: felt252 = 999;
    let score: u64 = 0;
    game_admin.set_score(token_id, score);
    let result = lb.submit_score(1, token_id, score, 101);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Append at last failed"),
    }
}

#[test]
fn test_append_last_500() {
    let (lb, admin, game_addr, game_admin) = deploy();
    fill_leaderboard(lb, admin, game_addr, game_admin, 500);

    let token_id: felt252 = 999;
    let score: u64 = 0;
    game_admin.set_score(token_id, score);
    let result = lb.submit_score(1, token_id, score, 501);
    match result {
        LeaderboardResult::Success => {},
        _ => panic!("Append at last failed"),
    }
}
