// Tests for ContextComponent extension
// Test Plan: context_test_plan.md

use openzeppelin_interfaces::introspection::ISRC5DispatcherTrait;
use snforge_std::{EventSpyTrait, spy_events};
use starknet::ContractAddress;
use crate::token::extensions::context::interface::IMINIGAME_TOKEN_CONTEXT_ID;
use crate::token::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::metagame_mock::IMetagameMockDispatcherTrait;
use super::mocks::minigame_mock::IMinigameMockDispatcherTrait;

// Import setup helpers
use super::setup::{ALICE, BOB, RENDERER_ADDRESS, setup, setup_multi_game};

// Helper function for creating contract addresses from felt252 values
fn addr(value: felt252) -> ContractAddress {
    value.try_into().unwrap()
}

// ================================================================================================
// CONTEXT THROUGH METAGAME TESTS
// ================================================================================================

// CTX-INT01: Full flow - metagame mints token with context
#[test]
fn test_context_through_metagame_mint() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint through metagame which supports context
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('ContextPlayer'),
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

    // Verify token has context flag set
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Token minted through metagame should have context");

    // Verify events were emitted
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should emit events including context");
}

// CTX-U02: Context without metagame results in no context flag
#[test]
fn test_mint_without_context() {
    let test_contracts = setup();

    // Mint directly (not through metagame)
    let token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('DirectPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None, // No context
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify no context flag
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(!metadata.has_context, "Direct mint should not have context");
}

// ================================================================================================
// CONTEXT WITH OTHER FEATURES TESTS
// ================================================================================================

// CTX-INT04: Context with lifecycle timestamps
#[test]
fn test_context_with_lifecycle_combination() {
    let test_contracts = setup();

    let start_time: u64 = 5000;
    let end_time: u64 = 10000;

    // Mint through metagame with lifecycle
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('TimedContextPlayer'),
            Option::None,
            Option::Some(start_time),
            Option::Some(end_time),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Verify both lifecycle and context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.lifecycle.start == start_time, "Start time should match");
    assert!(metadata.lifecycle.end == end_time, "End time should match");
    assert!(metadata.has_context, "Should have context");
}

// CTX-INT05: Context with soulbound token
#[test]
fn test_context_with_soulbound_combination() {
    let test_contracts = setup();

    // Mint soulbound token through metagame
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('SoulboundContextPlayer'),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            true, // soulbound
            false,
            0,
            0,
        );

    // Verify both soulbound and context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.soulbound, "Should be soulbound");
    assert!(metadata.has_context, "Should have context");
    assert!(test_contracts.test_token.is_soulbound(token_id), "is_soulbound should return true");
}

// Context with renderer combination
#[test]
fn test_context_with_renderer_combination() {
    let test_contracts = setup();

    // Mint through metagame with renderer
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('RendererContextPlayer'),
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

    // Verify both renderer and context
    assert!(
        test_contracts.test_token.renderer_address(token_id) == RENDERER_ADDRESS(),
        "Should have renderer",
    );
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Should have context");
}

// ================================================================================================
// BATCH CONTEXT TESTS
// ================================================================================================

// CTX-INT06: Batch mint with context events
#[test]
fn test_batch_mint_with_context() {
    let test_contracts = setup();

    // Mint multiple tokens through metagame
    let token_id1 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player1'),
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

    let token_id2 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Player2'),
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

    // Verify all tokens have context
    let metadata1 = test_contracts.test_token.token_metadata(token_id1);
    let metadata2 = test_contracts.test_token.token_metadata(token_id2);

    assert!(metadata1.has_context, "Token 1 should have context");
    assert!(metadata2.has_context, "Token 2 should have context");
}

// ================================================================================================
// INITIALIZER TESTS
// ================================================================================================

// CTX-I01: Initializer registers IMINIGAME_TOKEN_CONTEXT_ID
#[test]
fn test_context_initializer_registers_interface() {
    let test_contracts = setup_multi_game();

    assert!(
        test_contracts.src5.supports_interface(IMINIGAME_TOKEN_CONTEXT_ID),
        "Should support IMinigameTokenContext interface",
    );
}

// CTX-I03: Interface ID constant is correct
#[test]
fn test_context_interface_id_correct_value() {
    assert!(
        IMINIGAME_TOKEN_CONTEXT_ID == 0x02b329e82f6f6b94f8949b36c5dc95acf86c6083b08d99bc81e399b4b0e8d19a,
        "Interface ID should match expected value",
    );
}

// ================================================================================================
// EDGE CASE TESTS
// ================================================================================================

// CTX-U05: Context with empty player name
#[test]
fn test_context_with_empty_player_name() {
    let test_contracts = setup();

    // Mint with no player name
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None, // No player name
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

    // Should still have context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Should have context even with no player name");
    assert!(test_contracts.test_token.player_name(token_id) == '', "Player name should be empty");
}

// CTX-U08: Context with all parameters set
#[test]
fn test_context_with_all_parameters() {
    let test_contracts = setup();

    // Create objective for the test
    test_contracts.mock_minigame.create_objective_score(100);

    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('FullPlayer'),
            Option::None, // settings
            Option::Some(1000), // start
            Option::Some(2000), // end
            Option::Some(1), // objective
            Option::Some("https://client.url"),
            Option::Some(RENDERER_ADDRESS()),
            BOB(),
            true, // soulbound
            false,
            0,
            0,
        );

    // Verify all fields
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Should have context");
    assert!(metadata.soulbound, "Should be soulbound");
    assert!(metadata.lifecycle.start == 1000, "Start should match");
    assert!(metadata.lifecycle.end == 2000, "End should match");
    assert!(metadata.objective_id == 1, "Should have objective");
    assert!(test_contracts.test_token.player_name(token_id) == 'FullPlayer', "Player name match");
    assert!(
        test_contracts.test_token.renderer_address(token_id) == RENDERER_ADDRESS(),
        "Renderer match",
    );
}

// ================================================================================================
// TOKEN METADATA HAS_CONTEXT VIEW TESTS
// ================================================================================================

#[test]
fn test_has_context_flag_in_metadata() {
    let test_contracts = setup();

    // Direct mint - no context
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
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Metagame mint - has context
    let token_id2 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
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

    let metadata1 = test_contracts.test_token.token_metadata(token_id1);
    let metadata2 = test_contracts.test_token.token_metadata(token_id2);

    assert!(!metadata1.has_context, "Direct mint should not have context");
    assert!(metadata2.has_context, "Metagame mint should have context");
}

// ================================================================================================
// CONTEXT EVENT TESTS
// ================================================================================================

// CTX-E03: Event spy captures context events
#[test]
fn test_event_spy_captures_context_events() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint through metagame
    let _token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('EventTestPlayer'),
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

    // Verify events were captured
    let events = spy.get_events();
    assert!(events.events.len() > 0, "Should capture events from metagame mint");
}

// ================================================================================================
// FUZZ TESTS
// ================================================================================================

// CTX-F01: Fuzz emit_context token_ids
#[test]
#[fuzzer(runs: 50)]
fn test_fuzz_context_with_various_token_ids(mint_count: u8) {
    // Limit count
    if mint_count == 0 || mint_count > 10 {
        return;
    }

    let test_contracts = setup();

    let mut i: u8 = 0;
    while i < mint_count {
        let token_id = test_contracts
            .metagame_mock
            .mint_game(
                Option::Some(test_contracts.minigame.contract_address),
                Option::Some('FuzzPlayer'),
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                Option::None,
                ALICE(),
                false,
                false,
                i.into(),
                0,
            );

        // Verify context flag is set for each
        let metadata = test_contracts.test_token.token_metadata(token_id);
        assert!(metadata.has_context, "Each token should have context");

        i += 1;
    };
}

// ================================================================================================
// CONTEXT WITH GAME REGISTRY TESTS
// ================================================================================================

// CTX-INT03: Context works with registered game
#[test]
fn test_context_with_registry_game() {
    let test_contracts = setup();

    // Mint through metagame - game should be in registry
    let token_id = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('RegistryPlayer'),
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

    // Verify context - game_id may be 0 if game is not registered with game_id
    // The key assertion is that minting through metagame creates context
    let metadata = test_contracts.test_token.token_metadata(token_id);
    assert!(metadata.has_context, "Should have context for game minted through metagame");
}

// ================================================================================================
// ADDITIONAL COVERAGE TESTS
// ================================================================================================

// Multiple context mints preserve unique data
#[test]
fn test_multiple_context_mints_unique_data() {
    let test_contracts = setup();

    // Mint first token
    let token_id1 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Alice'),
            Option::None,
            Option::Some(100),
            Option::Some(200),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
            false,
            0,
            0,
        );

    // Mint second token with different data
    let token_id2 = test_contracts
        .metagame_mock
        .mint_game(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some('Bob'),
            Option::None,
            Option::Some(300),
            Option::Some(400),
            Option::None,
            Option::None,
            Option::None,
            BOB(),
            true,
            false,
            1,
            0,
        );

    // Verify each token has unique metadata
    let metadata1 = test_contracts.test_token.token_metadata(token_id1);
    let metadata2 = test_contracts.test_token.token_metadata(token_id2);

    assert!(metadata1.has_context, "Token 1 has context");
    assert!(metadata2.has_context, "Token 2 has context");
    assert!(metadata1.lifecycle.start == 100, "Token 1 start");
    assert!(metadata2.lifecycle.start == 300, "Token 2 start");
    assert!(!metadata1.soulbound, "Token 1 not soulbound");
    assert!(metadata2.soulbound, "Token 2 soulbound");
    assert!(test_contracts.test_token.player_name(token_id1) == 'Alice', "Token 1 name");
    assert!(test_contracts.test_token.player_name(token_id2) == 'Bob', "Token 2 name");
}
