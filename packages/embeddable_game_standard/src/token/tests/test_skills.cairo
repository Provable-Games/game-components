// Tests for SkillsComponent extension
// Mirrors test_renderer.cairo structure

use core::num::traits::Zero;
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::token::extensions::skills::interface::IMINIGAME_TOKEN_SKILLS_ID;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use crate::token::token_component::CoreTokenComponent;

// Import setup helpers
use super::setup::{ALICE, BOB, setup_multi_game};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// Custom skills addresses for testing
fn CUSTOM_SKILLS() -> ContractAddress {
    addr(0x5C1115)
}

fn CUSTOM_SKILLS_2() -> ContractAddress {
    addr(0x5C1152)
}

fn ZERO_ADDRESS() -> ContractAddress {
    addr(0)
}

// ================================================================================================
// GET_SKILLS_ADDRESS TESTS
// ================================================================================================

#[test]
fn test_get_skills_address_with_custom_skills() {
    let test_contracts = setup_multi_game();

    // Mint with custom skills
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        test_contracts.test_token.get_skills_address(token_id) == CUSTOM_SKILLS(),
        "Should return custom skills address",
    );
}

#[test]
fn test_get_skills_address_no_custom_skills() {
    let test_contracts = setup_multi_game();

    // Mint without skills
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(),
        "Should return zero address",
    );
}

#[test]
fn test_get_skills_address_after_reset() {
    let test_contracts = setup_multi_game();

    // Mint with skills
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset as owner
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(),
        "Should return zero after reset",
    );
}

// ================================================================================================
// HAS_CUSTOM_SKILLS TESTS
// ================================================================================================

#[test]
fn test_has_custom_skills_true() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.has_custom_skills(token_id), "Should have custom skills");
}

#[test]
fn test_has_custom_skills_false() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        !test_contracts.test_token.has_custom_skills(token_id), "Should not have custom skills",
    );
}

#[test]
fn test_has_custom_skills_zero_address() {
    let test_contracts = setup_multi_game();

    // Mint with zero address explicitly as skills
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(ZERO_ADDRESS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        !test_contracts.test_token.has_custom_skills(token_id),
        "Zero address should not be custom skills",
    );
}

#[test]
fn test_has_custom_skills_after_reset() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        !test_contracts.test_token.has_custom_skills(token_id),
        "Should not have custom skills after reset",
    );
}

// ================================================================================================
// RESET_TOKEN_SKILLS TESTS
// ================================================================================================

#[test]
fn test_reset_token_skills_as_owner() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify skills is set
    assert!(test_contracts.test_token.has_custom_skills(token_id), "Should have custom skills");

    // Reset as owner
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Verify reset
    assert!(
        !test_contracts.test_token.has_custom_skills(token_id),
        "Should not have custom skills after reset",
    );
    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(),
        "Skills should be zero after reset",
    );
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_reset_token_skills_unauthorized() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try to reset as BOB (not owner)
    start_cheat_caller_address(test_contracts.test_token.contract_address, BOB());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);
}

#[test]
fn test_reset_token_skills_already_zero() {
    let test_contracts = setup_multi_game();

    // Mint without skills
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset even though already zero
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Should still be zero
    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(),
        "Should remain zero after reset",
    );
}

// ================================================================================================
// RESET_TOKEN_SKILLS_BATCH TESTS
// ================================================================================================

#[test]
fn test_reset_token_skills_batch_single() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset batch with single token
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills_batch(array![token_id].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(),
        "Should be reset after batch reset",
    );
}

#[test]
fn test_reset_token_skills_batch_multiple() {
    let test_contracts = setup_multi_game();

    // Mint multiple tokens with skills
    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS_2()), // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let token_id3 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            2,
            0,
        );

    // Reset batch
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts
        .test_token
        .reset_token_skills_batch(array![token_id1, token_id2, token_id3].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Verify all reset
    assert!(
        test_contracts.test_token.get_skills_address(token_id1).is_zero(),
        "Token 1 should be reset",
    );
    assert!(
        test_contracts.test_token.get_skills_address(token_id2).is_zero(),
        "Token 2 should be reset",
    );
    assert!(
        test_contracts.test_token.get_skills_address(token_id3).is_zero(),
        "Token 3 should be reset",
    );
}

#[test]
fn test_reset_token_skills_batch_empty() {
    let test_contracts = setup_multi_game();

    // Mint a token
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset with empty batch - should be no-op
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills_batch(array![].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Token should be unchanged
    assert!(
        test_contracts.test_token.get_skills_address(token_id) == CUSTOM_SKILLS(),
        "Skills should be unchanged",
    );
}

#[test]
fn test_reset_token_skills_batch_mixed() {
    let test_contracts = setup_multi_game();

    // Token with skills
    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Token without skills
    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    // Reset both
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills_batch(array![token_id1, token_id2].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Both should be zero
    assert!(
        test_contracts.test_token.get_skills_address(token_id1).is_zero(), "Token 1 should be zero",
    );
    assert!(
        test_contracts.test_token.get_skills_address(token_id2).is_zero(), "Token 2 should be zero",
    );
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_reset_token_skills_batch_unauthorized_fails() {
    let test_contracts = setup_multi_game();

    // Mint token to ALICE
    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try batch reset as BOB
    start_cheat_caller_address(test_contracts.test_token.contract_address, BOB());
    test_contracts.test_token.reset_token_skills_batch(array![token_id].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);
}

// ================================================================================================
// GET_SKILLS_ADDRESS_BATCH TESTS
// ================================================================================================

#[test]
fn test_get_skills_address_batch_single() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let results = test_contracts.test_token.get_skills_address_batch(array![token_id].span());
    assert!(results.len() == 1, "Should have 1 result");
    assert!(*results.at(0) == CUSTOM_SKILLS(), "Should match skills address");
}

#[test]
fn test_get_skills_address_batch_multiple() {
    let test_contracts = setup_multi_game();

    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS_2()), // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let results = test_contracts
        .test_token
        .get_skills_address_batch(array![token_id1, token_id2].span());
    assert!(results.len() == 2, "Should have 2 results");
    assert!(*results.at(0) == CUSTOM_SKILLS(), "First should match");
    assert!(*results.at(1) == CUSTOM_SKILLS_2(), "Second should match");
}

#[test]
fn test_get_skills_address_batch_empty() {
    let test_contracts = setup_multi_game();

    let results = test_contracts.test_token.get_skills_address_batch(array![].span());
    assert!(results.len() == 0, "Should have empty results");
}

#[test]
fn test_get_skills_address_batch_mixed() {
    let test_contracts = setup_multi_game();

    // With skills
    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Without skills
    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let results = test_contracts
        .test_token
        .get_skills_address_batch(array![token_id1, token_id2].span());
    assert!(*results.at(0) == CUSTOM_SKILLS(), "First should have skills");
    assert!((*results.at(1)).is_zero(), "Second should be zero");
}

#[test]
fn test_get_skills_address_batch_matches_individual() {
    let test_contracts = setup_multi_game();

    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::None, // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let token_ids = array![token_id1, token_id2];
    let batch_results = test_contracts.test_token.get_skills_address_batch(token_ids.span());

    // Verify batch results match individual calls
    assert!(
        *batch_results.at(0) == test_contracts.test_token.get_skills_address(token_id1),
        "First should match individual",
    );
    assert!(
        *batch_results.at(1) == test_contracts.test_token.get_skills_address(token_id2),
        "Second should match individual",
    );
}

// ================================================================================================
// EVENT TESTS
// ================================================================================================

#[test]
fn test_reset_token_skills_emits_event() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let mut spy = spy_events();

    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Check for MetadataUpdate event
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    CoreTokenComponent::Event::MetadataUpdate(
                        CoreTokenComponent::MetadataUpdate { token_id: token_id.into() },
                    ),
                ),
            ],
        );
}

#[test]
fn test_batch_reset_emits_multiple_events() {
    let test_contracts = setup_multi_game();

    let token_id1 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let token_id2 = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS_2()), // skills_address
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let mut spy = spy_events();

    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills_batch(array![token_id1, token_id2].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Both events should be emitted
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    CoreTokenComponent::Event::MetadataUpdate(
                        CoreTokenComponent::MetadataUpdate { token_id: token_id1.into() },
                    ),
                ),
                (
                    test_contracts.test_token.contract_address,
                    CoreTokenComponent::Event::MetadataUpdate(
                        CoreTokenComponent::MetadataUpdate { token_id: token_id2.into() },
                    ),
                ),
            ],
        );
}

// ================================================================================================
// SRC5 INTERFACE TESTS
// ================================================================================================

#[test]
fn test_supports_skills_interface() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_SKILLS_ID),
        "Should support IMinigameTokenSkills interface",
    );
}

// ================================================================================================
// INTEGRATION TESTS
// ================================================================================================

#[test]
fn test_skills_persists_after_game_updates() {
    let test_contracts = setup_multi_game();

    let token_id = test_contracts
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
            Option::None, // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Update game
    test_contracts.test_token.update_game(token_id);

    // Skills should still be set
    assert!(
        test_contracts.test_token.get_skills_address(token_id) == CUSTOM_SKILLS(),
        "Skills should persist after update",
    );
}

#[test]
fn test_skills_and_renderer_independent() {
    let test_contracts = setup_multi_game();

    let renderer_addr: ContractAddress = 0xDE2E2.try_into().unwrap();

    // Mint with both renderer and skills
    let token_id = test_contracts
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
            Option::Some(renderer_addr), // renderer_address
            Option::Some(CUSTOM_SKILLS()), // skills_address
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify both are set independently
    assert!(
        test_contracts.test_token.get_renderer(token_id) == renderer_addr, "Renderer should be set",
    );
    assert!(
        test_contracts.test_token.get_skills_address(token_id) == CUSTOM_SKILLS(),
        "Skills should be set",
    );

    // Reset only skills
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_skills(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Skills reset, renderer unchanged
    assert!(
        test_contracts.test_token.get_skills_address(token_id).is_zero(), "Skills should be reset",
    );
    assert!(
        test_contracts.test_token.get_renderer(token_id) == renderer_addr,
        "Renderer should be unchanged",
    );
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_skills_storage_consistency(token_offset: u8, skills_felt: felt252) {
    // Skip zero felt as it converts to zero address
    if skills_felt == 0 || token_offset > 5 {
        return;
    }

    let test_contracts = setup_multi_game();

    // Mint tokens up to offset
    let mut i: u8 = 0;
    let mut last_token_id: felt252 = 0;

    while i <= token_offset {
        let skills_opt = if i == token_offset {
            let skills: ContractAddress = skills_felt.try_into().unwrap();
            Option::Some(skills)
        } else {
            Option::None
        };

        last_token_id = test_contracts
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
                Option::None, // renderer_address
                skills_opt, // skills_address
                ALICE(),
                false,
                false,
                i.into(),
                0,
            );
        i += 1;
    }

    // Verify consistency
    let stored = test_contracts.test_token.get_skills_address(last_token_id);
    let expected: ContractAddress = skills_felt.try_into().unwrap();
    assert!(stored == expected, "Stored skills should match set value");

    let has_custom = test_contracts.test_token.has_custom_skills(last_token_id);
    assert!(has_custom == !stored.is_zero(), "has_custom_skills should match address check");
}
