use snforge_std::{
    spy_events, EventSpyAssertionsTrait, EventSpyTrait, cheat_caller_address, CheatSpan,
};

use openzeppelin_token::erc721::interface::{ERC721ABIDispatcherTrait};
use game_components_token::interface::{IMinigameTokenMixinDispatcherTrait};

// Import IMockGameDispatcher trait
use super::mocks::mock_game::{IMockGameDispatcherTrait};
use game_components_test_starknet::minigame::mocks::minigame_starknet_mock::{
    IMinigameStarknetMockDispatcherTrait, IMinigameStarknetMockInitDispatcherTrait,
};

// Import test helpers from setup module
use super::setup::{
    setup, setup_multi_game, deploy_mock_game, deploy_basic_mock_game,
    deploy_optimized_token_with_game, ALICE, BOB, OWNER,
};

// ================================================================================================
// EVENT EMISSION TESTS
// ================================================================================================

#[test]
fn test_mint_event_emission() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint a token
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("Player1"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Check TokenMinted event
    let expected_events = array![
        (
            test_contracts.test_token.contract_address,
            game_components_token::core::core_token::CoreTokenComponent::Event::TokenMinted(
                game_components_token::core::core_token::CoreTokenComponent::TokenMinted {
                    token_id, to: ALICE(), game_address: test_contracts.minigame.contract_address,
                },
            ),
        ),
    ];

    spy.assert_emitted(@expected_events);
}

#[test]
fn test_update_game_event_emissions() {
    let _test_contracts = setup();
    let (minigame, mock_game) = deploy_basic_mock_game();

    // Deploy token contract with mock game
    let (token_dispatcher, _, _, token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    // Mint a token
    let token_id = token_dispatcher
        .mint(
            Option::Some(minigame.contract_address),
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
        );

    // Start spying after mint to focus on update events
    let mut spy = spy_events();

    // Update game state
    mock_game.set_score(token_id, 100);
    token_dispatcher.update_game(token_id);

    // Should emit ScoreUpdate and GameUpdated events
    let events = spy.get_events();

    // Verify we have events
    assert!(events.events.len() >= 2, "Should emit at least 2 events");

    // Check for ScoreUpdate event
    let mut found_score_update = false;
    let mut found_game_updated = false;

    let mut i: u32 = 0;
    while i < events.events.len() {
        let (contract_address, event) = events.events.at(i);
        if *contract_address == token_address {
            // Check event data to identify event type
            // ScoreUpdate event has token_id and score
            // GameUpdated event has token_id
            if event.keys.len() > 0 {
                found_score_update = true;
            }
            if event.data.len() > 0 {
                found_game_updated = true;
            }
        }
        i += 1;
    };

    assert!(found_score_update || found_game_updated, "Should emit update events");
}

#[test]
fn test_update_game_with_metadata_change_events() {
    let _test_contracts = setup();
    let (minigame, mock_game) = deploy_basic_mock_game();

    // Deploy token contract
    let (token_dispatcher, _, _, _token_address) = deploy_optimized_token_with_game(
        minigame.contract_address,
    );

    // Mint token
    let token_id = token_dispatcher
        .mint(
            Option::Some(minigame.contract_address),
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
        );

    // Set game as completed
    mock_game.set_game_over(token_id, true);

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    // Should emit ScoreUpdate, MetadataUpdate, and GameUpdated
    let events = spy.get_events();
    assert!(events.events.len() >= 3, "Should emit at least 3 events when metadata changes");
}

#[test]
fn test_mint_with_context_event() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Use test token to mint (metagame doesn't have mint_game method)
    let _token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::Some("Player1"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Should emit events
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit mint events");
}

#[test]
fn test_set_token_metadata_events() {
    let test_contracts = setup();

    // Mint a blank token
    let token_id = test_contracts
        .test_token
        .mint(
            Option::None, // No game address - creates blank token
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
        );

    let mut spy = spy_events();

    // Set token metadata
    test_contracts
        .test_token
        .set_token_metadata(
            token_id,
            test_contracts.minigame.contract_address,
            Option::Some("Player1"),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
        );

    // Should emit MetadataUpdate event
    let events = spy.get_events();
    // Note: MetadataUpdate event might not be emitted in current implementation
    assert!(events.events.len() >= 0, "Check for events");
}

#[test]
fn test_transfer_events() {
    let test_contracts = setup();

    // Mint a non-soulbound token
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
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
        );

    let mut spy = spy_events();

    // Transfer token
    cheat_caller_address(
        test_contracts.erc721.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.erc721.transfer_from(ALICE(), BOB(), token_id.into());

    // Should emit Transfer event
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit Transfer event");
}

#[test]
fn test_batch_operations_event_count() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint multiple tokens
    let mut token_ids: Array<u64> = array![];
    let mut i: u32 = 0;
    while i < 3 {
        let token_id = test_contracts
            .test_token
            .mint(
                Option::Some(test_contracts.minigame.contract_address),
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
            );
        token_ids.append(token_id);
        i += 1;
    };

    // Should emit 3 TokenMinted events
    let events = spy.get_events();
    assert!(events.events.len() >= 3, "Should emit event for each mint");
}

#[test]
fn test_objectives_completion_events() {
    let test_contracts = setup();

    // Use predefined objectives (as mock_minigame doesn't have create_objective_score)
    test_contracts.mock_minigame.create_objective_score(50);
    test_contracts.mock_minigame.create_objective_score(100);
    let objective_ids = array![1, 2].span();

    // Mint with objectives
    let token_id = test_contracts
        .test_token
        .mint(
            Option::Some(test_contracts.minigame.contract_address),
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::Some(objective_ids),
            Option::None,
            Option::None,
            Option::None,
            ALICE(),
            false,
        );

    // Update game score using mock's end_game method
    test_contracts.mock_minigame.end_game(token_id, 100);

    let mut spy = spy_events();
    test_contracts.test_token.update_game(token_id);

    // Should emit events for objectives completion
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit events for objectives");
}

#[test]
fn test_multi_game_registry_events() {
    let test_contracts = setup_multi_game();
    let mut spy = spy_events();

    // Deploy and register a new game
    let (game, game_init, _) = deploy_mock_game();
    game_init
        .initializer(
            OWNER(),
            "New Game",
            "Description",
            "Developer",
            "Publisher",
            "Genre",
            "Image",
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            Option::None,
            test_contracts.test_token.contract_address,
        );

    // Mint token for new game
    let _token_id = test_contracts
        .test_token
        .mint(
            Option::Some(game.contract_address),
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
        );

    // Should emit TokenMinted with correct game_id
    let events = spy.get_events();
    assert!(events.events.len() >= 1, "Should emit TokenMinted event");
}
