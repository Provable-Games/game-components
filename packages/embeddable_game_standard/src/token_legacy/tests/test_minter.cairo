// Tests for MinterComponent extension
// Test Plan: minter_test_plan.md

use core::num::traits::Zero;
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{
    CheatSpan, EventSpyAssertionsTrait, EventSpyTrait, cheat_caller_address, spy_events,
};
use starknet::ContractAddress;
use crate::token_legacy::extensions::minter::interface::IMINIGAME_TOKEN_MINTER_ID;
use crate::token_legacy::extensions::minter::minter::MinterComponent;
use crate::token_legacy::interface::IMinigameTokenMixinDispatcherTrait;

// Import setup helpers
use super::setup::{
    ALICE, BOB, CHARLIE, OWNER, ZERO_ADDRESS, deploy_mock_game_standalone,
    deploy_single_game_token_contract, setup_multi_game,
};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// ================================================================================================
// GET_MINTER_ADDRESS TESTS
// ================================================================================================

// GMA-001: Valid minter ID returns registered address
#[test]
fn test_get_minter_address_valid_id() {
    let test_contracts = setup_multi_game();

    // Mint from ALICE to register as minter
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Get minter address for ID 1
    let minter_addr = test_contracts.test_token.get_minter_address(1);
    assert!(minter_addr == ALICE(), "Minter address should be ALICE");
}

// GMA-002: Non-existent minter ID returns zero address
#[test]
fn test_get_minter_address_nonexistent_id() {
    let test_contracts = setup_multi_game();

    let minter_addr = test_contracts.test_token.get_minter_address(999);
    assert!(minter_addr.is_zero(), "Non-existent minter should return zero address");
}

// GMA-003: Zero minter ID returns zero address
#[test]
fn test_get_minter_address_zero_id() {
    let test_contracts = setup_multi_game();

    let minter_addr = test_contracts.test_token.get_minter_address(0);
    assert!(minter_addr.is_zero(), "ID 0 should return zero address");
}

// GMA-004: First minter gets ID 1
#[test]
fn test_get_minter_address_first_minter() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            0,
            0,
        );

    // First minter should be ID 1
    let minter_addr = test_contracts.test_token.get_minter_address(1);
    assert!(minter_addr == BOB(), "First minter should be at ID 1");
}

// GMA-005: Multiple minters have correct addresses
#[test]
fn test_get_minter_address_multiple_minters() {
    let test_contracts = setup_multi_game();

    // Mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Mint from BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    // Mint from CHARLIE
    cheat_caller_address(
        test_contracts.test_token.contract_address, CHARLIE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
            false,
            2,
            0,
        );

    // Verify addresses
    assert!(test_contracts.test_token.get_minter_address(1) == ALICE(), "ID 1 should be ALICE");
    assert!(test_contracts.test_token.get_minter_address(2) == BOB(), "ID 2 should be BOB");
    assert!(test_contracts.test_token.get_minter_address(3) == CHARLIE(), "ID 3 should be CHARLIE");
}

// GMA-006: Max u64 minter ID returns zero address
#[test]
fn test_get_minter_address_max_id() {
    let test_contracts = setup_multi_game();

    let max_id: u64 = 0xFFFFFFFFFFFFFFFF;
    let minter_addr = test_contracts.test_token.get_minter_address(max_id);
    assert!(minter_addr.is_zero(), "Max ID should return zero address");
}

// ================================================================================================
// GET_MINTER_ID TESTS
// ================================================================================================

// GMI-001: Registered minter returns correct ID
#[test]
fn test_get_minter_id_registered() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let minter_id = test_contracts.test_token.get_minter_id(ALICE());
    assert!(minter_id == 1, "ALICE should have minter ID 1");
}

// GMI-002: Non-registered address returns 0
#[test]
fn test_get_minter_id_not_registered() {
    let test_contracts = setup_multi_game();

    let minter_id = test_contracts.test_token.get_minter_id(BOB());
    assert!(minter_id == 0, "Non-registered address should return 0");
}

// GMI-003: Zero address returns 0
#[test]
fn test_get_minter_id_zero_address() {
    let test_contracts = setup_multi_game();

    let minter_id = test_contracts.test_token.get_minter_id(ZERO_ADDRESS());
    assert!(minter_id == 0, "Zero address should return 0");
}

// GMI-004 & GMI-005: Multiple minters have sequential IDs
#[test]
fn test_get_minter_id_sequential() {
    let test_contracts = setup_multi_game();

    // Mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Mint from BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    assert!(test_contracts.test_token.get_minter_id(ALICE()) == 1, "ALICE should be ID 1");
    assert!(test_contracts.test_token.get_minter_id(BOB()) == 2, "BOB should be ID 2");
}

// ================================================================================================
// MINTER_EXISTS TESTS
// ================================================================================================

// ME-001: Non-existent before any mints
#[test]
fn test_minter_exists_before_mint() {
    let test_contracts = setup_multi_game();

    assert!(!test_contracts.test_token.minter_exists(ALICE()), "ALICE should not exist yet");
}

// ME-002: Exists after mint
#[test]
fn test_minter_exists_after_mint() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.minter_exists(ALICE()), "ALICE should exist after mint");
}

// ME-003: Other addresses don't exist
#[test]
fn test_minter_exists_other_address() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(!test_contracts.test_token.minter_exists(BOB()), "BOB should not exist");
}

// ME-004: Zero address does not exist
#[test]
fn test_minter_exists_zero_address() {
    let test_contracts = setup_multi_game();

    assert!(
        !test_contracts.test_token.minter_exists(ZERO_ADDRESS()), "Zero address should not exist",
    );
}

// ================================================================================================
// TOTAL_MINTERS TESTS
// ================================================================================================

// TM-001: Initial state has 0 minters
#[test]
fn test_total_minters_initial() {
    let test_contracts = setup_multi_game();

    assert!(test_contracts.test_token.total_minters() == 0, "Should have 0 minters initially");
}

// TM-002: After first minter, count is 1
#[test]
fn test_total_minters_after_first() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.total_minters() == 1, "Should have 1 minter");
}

// TM-003: Duplicate mints from same address don't increase count
#[test]
fn test_total_minters_duplicate_mint() {
    let test_contracts = setup_multi_game();

    // First mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.total_minters() == 1, "Should have 1 minter");

    // Second mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    assert!(test_contracts.test_token.total_minters() == 1, "Should still have 1 minter");
}

// TM-004: After second unique minter, count is 2
#[test]
fn test_total_minters_after_second() {
    let test_contracts = setup_multi_game();

    // Mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Mint from BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );

    assert!(test_contracts.test_token.total_minters() == 2, "Should have 2 minters");
}

// ================================================================================================
// SEQUENTIAL IDS AND CONSISTENCY TESTS
// ================================================================================================

// AM-008: Sequential IDs test
#[test]
fn test_minter_sequential_ids() {
    let test_contracts = setup_multi_game();

    // Mint from ALICE
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );
    assert!(test_contracts.test_token.get_minter_id(ALICE()) == 1, "ALICE should be ID 1");

    // Mint from BOB
    cheat_caller_address(
        test_contracts.test_token.contract_address, BOB(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            false,
            false,
            1,
            0,
        );
    assert!(test_contracts.test_token.get_minter_id(BOB()) == 2, "BOB should be ID 2");

    // Mint from CHARLIE
    cheat_caller_address(
        test_contracts.test_token.contract_address, CHARLIE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            CHARLIE(),
            false,
            false,
            2,
            0,
        );
    assert!(test_contracts.test_token.get_minter_id(CHARLIE()) == 3, "CHARLIE should be ID 3");
}

// Bidirectional mapping consistency test
#[test]
fn test_minter_bidirectional_mapping_consistency() {
    let test_contracts = setup_multi_game();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Get ID from address
    let id = test_contracts.test_token.get_minter_id(ALICE());
    // Get address from ID
    let retrieved_addr = test_contracts.test_token.get_minter_address(id);

    assert!(retrieved_addr == ALICE(), "Bidirectional mapping should be consistent");
}

// ================================================================================================
// EVENT TESTS
// ================================================================================================

// AM-007: MinterRegistryUpdate event emitted on registration
#[test]
fn test_minter_registry_update_event() {
    let test_contracts = setup_multi_game();
    let mut spy = spy_events();

    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Check for MinterRegistryUpdate event
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    MinterComponent::Event::MinterRegistryUpdate(
                        MinterComponent::MinterRegistryUpdate {
                            minter_id: 1, minter_address: ALICE(),
                        },
                    ),
                ),
            ],
        );
}

// Event not emitted on duplicate registration
#[test]
fn test_minter_no_event_on_duplicate_registration() {
    let test_contracts = setup_multi_game();

    // First mint (registers minter)
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Start spy after first mint
    let mut spy = spy_events();

    // Second mint from same address
    cheat_caller_address(
        test_contracts.test_token.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    // Verify no MinterRegistryUpdate event
    let events = spy.get_events();
    let mut has_minter_event = false;
    let mut i = 0;
    while i < events.events.len() {
        let (_, event) = events.events.at(i);
        // Check if any event is MinterRegistryUpdate by checking selector
        // The selector for MinterRegistryUpdate would be in the keys
        if event.keys.len() > 0 {
            let selector = *event.keys.at(0);
            // This is a rough check - in practice we'd need the exact selector
            if selector == selector!("MinterRegistryUpdate") {
                has_minter_event = true;
                break;
            }
        }
        i += 1;
    }

    assert!(!has_minter_event, "Should not emit MinterRegistryUpdate on duplicate registration");
}

// ================================================================================================
// SRC5 INTERFACE TESTS
// ================================================================================================

// INIT-001: Verify SRC5 interface registration
#[test]
fn test_minter_src5_interface_support() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_MINTER_ID),
        "Should support IMinigameTokenMinter interface",
    );
}

// INIT-002: Verify correct interface ID constant
#[test]
fn test_minter_interface_id_value() {
    assert!(
        IMINIGAME_TOKEN_MINTER_ID == 0x2198424b9ee68499f53f33ad952598acbd6d141af6c6863c9c56b117063acca,
        "Interface ID should match expected value",
    );
}

// ================================================================================================
// ISOLATION TESTS
// ================================================================================================

// Minter tracking is isolated per token contract
#[test]
fn test_minter_multiple_contracts_isolation() {
    // Deploy a mock game that supports IMinigame interface
    let game_address = deploy_mock_game_standalone();

    // Deploy first contract (single-game token with the mock game)
    let (token1, _, src5_1, _) = deploy_single_game_token_contract(
        Option::Some("Token1"),
        Option::Some("T1"),
        Option::Some(""),
        Option::None,
        game_address,
        OWNER(),
    );

    // Deploy second contract (single-game token with the mock game)
    let (token2, _, _, _) = deploy_single_game_token_contract(
        Option::Some("Token2"),
        Option::Some("T2"),
        Option::Some(""),
        Option::None,
        game_address,
        OWNER(),
    );

    // Mint from ALICE on token1
    cheat_caller_address(token1.contract_address, ALICE(), CheatSpan::TargetCalls(1));
    token1
        .mint(
            game_address,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // ALICE should be minter on token1 but not token2
    assert!(token1.minter_exists(ALICE()), "ALICE should be minter on token1");
    assert!(!token2.minter_exists(ALICE()), "ALICE should NOT be minter on token2");

    // Verify interface support
    assert!(
        src5_1.supports_interface(IMINIGAME_TOKEN_MINTER_ID),
        "Token1 should support minter interface",
    );
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

// FZ-MINT-002: Non-existent IDs return zero
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_minter_non_existent_id(id: u64) {
    let test_contracts = setup_multi_game();

    // Only test IDs > 0 (no minters registered)
    if id == 0 {
        return;
    }

    let addr_result = test_contracts.test_token.get_minter_address(id);
    assert!(addr_result.is_zero(), "Non-existent ID should return zero");
}

// FZ-MINT-003: Random addresses don't exist as minters initially
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_minter_exists_false_for_random_address(addr_seed: felt252) {
    let test_contracts = setup_multi_game();

    // Skip zero address as it's a special case
    if addr_seed == 0 {
        return;
    }

    let random_addr: ContractAddress = addr_seed.try_into().unwrap();
    assert!(
        !test_contracts.test_token.minter_exists(random_addr),
        "Random address should not be minter",
    );
}
