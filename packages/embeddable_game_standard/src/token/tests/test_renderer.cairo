// Tests for RendererComponent extension
// Test Plan: renderer_test_plan.md

use core::num::traits::Zero;
use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{
    EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;
use crate::token::extensions::renderer::interface::IMINIGAME_TOKEN_RENDERER_ID;
use crate::token::extensions::renderer::renderer::RendererComponent;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;

// Import setup helpers
use super::setup::{ALICE, BOB, RENDERER_ADDRESS, ZERO_ADDRESS, setup_multi_game};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// Custom renderer addresses for testing
fn CUSTOM_RENDERER() -> ContractAddress {
    addr(0x123456)
}

fn CUSTOM_RENDERER_2() -> ContractAddress {
    addr(0x789abc)
}

// ================================================================================================
// GET_RENDERER TESTS
// ================================================================================================

#[test]
fn test_get_renderer_with_custom_renderer() {
    let test_contracts = setup_multi_game();

    // Mint with custom renderer
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        test_contracts.test_token.get_renderer(token_id) == CUSTOM_RENDERER(),
        "Should return custom renderer",
    );
}

#[test]
fn test_get_renderer_no_custom_renderer() {
    let test_contracts = setup_multi_game();

    // Mint without renderer
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        test_contracts.test_token.get_renderer(token_id).is_zero(), "Should return zero address",
    );
}

#[test]
fn test_get_renderer_after_reset() {
    let test_contracts = setup_multi_game();

    // Mint with renderer
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset as owner
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        test_contracts.test_token.get_renderer(token_id).is_zero(),
        "Should return zero after reset",
    );
}

// ================================================================================================
// HAS_CUSTOM_RENDERER TESTS
// ================================================================================================

#[test]
fn test_has_custom_renderer_true() {
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
            Option::Some(RENDERER_ADDRESS()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(test_contracts.test_token.has_custom_renderer(token_id), "Should have custom renderer");
}

#[test]
fn test_has_custom_renderer_false() {
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        !test_contracts.test_token.has_custom_renderer(token_id), "Should not have custom renderer",
    );
}

#[test]
fn test_has_custom_renderer_zero_address_renderer() {
    let test_contracts = setup_multi_game();

    // Mint with zero address explicitly as renderer
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
            Option::Some(ZERO_ADDRESS()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    assert!(
        !test_contracts.test_token.has_custom_renderer(token_id),
        "Zero address should not be custom renderer",
    );
}

#[test]
fn test_has_custom_renderer_after_reset() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        !test_contracts.test_token.has_custom_renderer(token_id),
        "Should not have custom renderer after reset",
    );
}

// ================================================================================================
// RESET_TOKEN_RENDERER TESTS
// ================================================================================================

#[test]
fn test_reset_token_renderer_as_owner() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify renderer is set
    assert!(test_contracts.test_token.has_custom_renderer(token_id), "Should have custom renderer");

    // Reset as owner
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Verify reset
    assert!(
        !test_contracts.test_token.has_custom_renderer(token_id),
        "Should not have custom renderer after reset",
    );
    assert!(
        test_contracts.test_token.get_renderer(token_id).is_zero(),
        "Renderer should be zero after reset",
    );
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_reset_token_renderer_unauthorized() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try to reset as BOB (not owner)
    start_cheat_caller_address(test_contracts.test_token.contract_address, BOB());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);
}

#[test]
fn test_reset_token_renderer_already_zero() {
    let test_contracts = setup_multi_game();

    // Mint without renderer
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset even though already zero
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Should still be zero
    assert!(
        test_contracts.test_token.get_renderer(token_id).is_zero(),
        "Should remain zero after reset",
    );
}

// ================================================================================================
// RESET_TOKEN_RENDERER_BATCH TESTS
// ================================================================================================

#[test]
fn test_reset_token_renderer_batch_single() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset batch with single token
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer_batch(array![token_id].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    assert!(
        test_contracts.test_token.get_renderer(token_id).is_zero(),
        "Should be reset after batch reset",
    );
}

#[test]
fn test_reset_token_renderer_batch_multiple() {
    let test_contracts = setup_multi_game();

    // Mint multiple tokens with renderers
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
            Option::Some(CUSTOM_RENDERER()),
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
            Option::Some(CUSTOM_RENDERER_2()),
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
            Option::Some(RENDERER_ADDRESS()),
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
        .reset_token_renderer_batch(array![token_id1, token_id2, token_id3].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Verify all reset
    assert!(test_contracts.test_token.get_renderer(token_id1).is_zero(), "Token 1 should be reset");
    assert!(test_contracts.test_token.get_renderer(token_id2).is_zero(), "Token 2 should be reset");
    assert!(test_contracts.test_token.get_renderer(token_id3).is_zero(), "Token 3 should be reset");
}

#[test]
fn test_reset_token_renderer_batch_empty() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Reset with empty batch - should be no-op
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer_batch(array![].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Token should be unchanged
    assert!(
        test_contracts.test_token.get_renderer(token_id) == CUSTOM_RENDERER(),
        "Renderer should be unchanged",
    );
}

#[test]
fn test_reset_token_renderer_batch_mixed_renderers() {
    let test_contracts = setup_multi_game();

    // Token with renderer
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Token without renderer
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
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    // Reset both
    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer_batch(array![token_id1, token_id2].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Both should be zero
    assert!(test_contracts.test_token.get_renderer(token_id1).is_zero(), "Token 1 should be zero");
    assert!(test_contracts.test_token.get_renderer(token_id2).is_zero(), "Token 2 should be zero");
}

#[test]
#[should_panic(expected: "MinigameToken: Caller is not owner of token")]
fn test_reset_token_renderer_batch_unauthorized_fails() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Try batch reset as BOB
    start_cheat_caller_address(test_contracts.test_token.contract_address, BOB());
    test_contracts.test_token.reset_token_renderer_batch(array![token_id].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);
}

// ================================================================================================
// GET_RENDERER_BATCH TESTS
// ================================================================================================

#[test]
fn test_get_renderer_batch_single() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let results = test_contracts.test_token.get_renderer_batch(array![token_id].span());
    assert!(results.len() == 1, "Should have 1 result");
    assert!(*results.at(0) == CUSTOM_RENDERER(), "Should match renderer");
}

#[test]
fn test_get_renderer_batch_multiple() {
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
            Option::Some(CUSTOM_RENDERER()),
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
            Option::Some(CUSTOM_RENDERER_2()),
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let results = test_contracts.test_token.get_renderer_batch(array![token_id1, token_id2].span());
    assert!(results.len() == 2, "Should have 2 results");
    assert!(*results.at(0) == CUSTOM_RENDERER(), "First should match");
    assert!(*results.at(1) == CUSTOM_RENDERER_2(), "Second should match");
}

#[test]
fn test_get_renderer_batch_empty() {
    let test_contracts = setup_multi_game();

    let results = test_contracts.test_token.get_renderer_batch(array![].span());
    assert!(results.len() == 0, "Should have empty results");
}

#[test]
fn test_get_renderer_batch_mixed() {
    let test_contracts = setup_multi_game();

    // With renderer
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Without renderer
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
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let results = test_contracts.test_token.get_renderer_batch(array![token_id1, token_id2].span());
    assert!(*results.at(0) == CUSTOM_RENDERER(), "First should have renderer");
    assert!((*results.at(1)).is_zero(), "Second should be zero");
}

#[test]
fn test_get_renderer_batch_matches_individual() {
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
            Option::Some(CUSTOM_RENDERER()),
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
            Option::None,
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let token_ids = array![token_id1, token_id2];
    let batch_results = test_contracts.test_token.get_renderer_batch(token_ids.span());

    // Verify batch results match individual calls
    assert!(
        *batch_results.at(0) == test_contracts.test_token.get_renderer(token_id1),
        "First should match individual",
    );
    assert!(
        *batch_results.at(1) == test_contracts.test_token.get_renderer(token_id2),
        "Second should match individual",
    );
}

// ================================================================================================
// EVENT TESTS
// ================================================================================================

#[test]
fn test_reset_token_renderer_emits_event() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    let mut spy = spy_events();

    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer(token_id);
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Check for TokenRendererUpdate event
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    RendererComponent::Event::TokenRendererUpdate(
                        RendererComponent::TokenRendererUpdate {
                            token_id: token_id, renderer: Zero::zero(),
                        },
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
            Option::Some(CUSTOM_RENDERER()),
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
            Option::Some(CUSTOM_RENDERER_2()),
            ALICE(),
            false,
            false,
            1,
            0,
        );

    let mut spy = spy_events();

    start_cheat_caller_address(test_contracts.test_token.contract_address, ALICE());
    test_contracts.test_token.reset_token_renderer_batch(array![token_id1, token_id2].span());
    stop_cheat_caller_address(test_contracts.test_token.contract_address);

    // Both events should be emitted
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    RendererComponent::Event::TokenRendererUpdate(
                        RendererComponent::TokenRendererUpdate {
                            token_id: token_id1, renderer: Zero::zero(),
                        },
                    ),
                ),
                (
                    test_contracts.test_token.contract_address,
                    RendererComponent::Event::TokenRendererUpdate(
                        RendererComponent::TokenRendererUpdate {
                            token_id: token_id2, renderer: Zero::zero(),
                        },
                    ),
                ),
            ],
        );
}

#[test]
fn test_mint_with_renderer_emits_event() {
    let test_contracts = setup_multi_game();
    let mut spy = spy_events();

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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Check for TokenRendererUpdate event during mint
    spy
        .assert_emitted(
            @array![
                (
                    test_contracts.test_token.contract_address,
                    RendererComponent::Event::TokenRendererUpdate(
                        RendererComponent::TokenRendererUpdate {
                            token_id: token_id, renderer: CUSTOM_RENDERER(),
                        },
                    ),
                ),
            ],
        );
}

// ================================================================================================
// SRC5 INTERFACE TESTS
// ================================================================================================

#[test]
fn test_supports_renderer_interface() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_RENDERER_ID),
        "Should support IMinigameTokenRenderer interface",
    );
}

#[test]
fn test_renderer_interface_id_value() {
    assert!(
        IMINIGAME_TOKEN_RENDERER_ID == 0x8f54cc9eac088fdd5b0e849eef269b521a434b60ff8f2d8ae60cac2fbcc33e,
        "Interface ID should match expected value",
    );
}

// ================================================================================================
// INTEGRATION TESTS
// ================================================================================================

#[test]
fn test_renderer_persists_after_game_updates() {
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
            Option::Some(CUSTOM_RENDERER()),
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Update game
    test_contracts.test_token.update_game(token_id);

    // Renderer should still be set
    assert!(
        test_contracts.test_token.get_renderer(token_id) == CUSTOM_RENDERER(),
        "Renderer should persist after update",
    );
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_renderer_storage_consistency(token_offset: u8, renderer_felt: felt252) {
    // Skip zero felt as it converts to zero address
    if renderer_felt == 0 || token_offset > 5 {
        return;
    }

    let test_contracts = setup_multi_game();

    // Mint tokens up to offset
    let mut i: u8 = 0;
    let mut last_token_id: felt252 = 0;

    while i <= token_offset {
        let renderer_opt = if i == token_offset {
            let renderer: ContractAddress = renderer_felt.try_into().unwrap();
            Option::Some(renderer)
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
                renderer_opt,
                ALICE(),
                false,
                false,
                i.into(),
                0,
            );
        i += 1;
    }

    // Verify consistency
    let stored = test_contracts.test_token.get_renderer(last_token_id);
    let expected: ContractAddress = renderer_felt.try_into().unwrap();
    assert!(stored == expected, "Stored renderer should match set value");

    let has_custom = test_contracts.test_token.has_custom_renderer(last_token_id);
    assert!(has_custom == !stored.is_zero(), "has_custom_renderer should match address check");
}
