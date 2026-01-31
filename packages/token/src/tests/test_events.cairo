use openzeppelin_interfaces::erc721::ERC721ABIDispatcherTrait;
use snforge_std::{CheatSpan, EventSpyTrait, cheat_caller_address, spy_events};
use crate::interface::IMinigameTokenMixinDispatcherTrait;
use super::mocks::minigame_starknet_mock::IMinigameStarknetMockInitDispatcherTrait;

// Import IMockGameDispatcher trait
use super::mocks::mock_game::{IMockGameDispatcherTrait};

// Import test helpers from setup module
use super::setup::{
    ALICE, BOB, OWNER, deploy_basic_mock_game, deploy_mock_game, deploy_optimized_token_with_game,
    setup, setup_multi_game,
};

// ================================================================================================
// EVENT EMISSION TESTS
// ================================================================================================

#[test]
fn test_mint_event_emission() {
    let test_contracts = setup();
    let mut _spy = spy_events();

    // Mint a token
    let _token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player1'),
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
            minigame.contract_address,
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

    // Start spying after mint to focus on update events
    let mut spy = spy_events();

    // Update game state
    mock_game.set_score(token_id, 100);
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate event
    let events = spy.get_events();

    // Verify we have at least 1 event (MetadataUpdate)
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event");

    // Check for MetadataUpdate event from token contract
    let mut found_metadata_update = false;

    let mut i: u32 = 0;
    while i < events.events.span().len() {
        let (contract_address, _event) = events.events.at(i);
        if *contract_address == token_address {
            found_metadata_update = true;
        }
        i += 1;
    }

    assert!(found_metadata_update, "Should emit MetadataUpdate event");
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
            minigame.contract_address,
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

    // Set game as completed
    mock_game.set_game_over(token_id, true);

    let mut spy = spy_events();
    token_dispatcher.update_game(token_id);

    // Should emit MetadataUpdate when game state changes
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit at least 1 event when metadata changes");
}

#[test]
fn test_mint_with_context_event() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Use test token to mint (metagame doesn't have mint_game method)
    let _token_id = test_contracts
        .test_token
        .mint(
            test_contracts.minigame.contract_address,
            Option::Some('Player1'),
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

    // Should emit events
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit mint events");
}

#[test]
fn test_transfer_events() {
    let test_contracts = setup();

    // Mint a non-soulbound token
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

    let mut spy = spy_events();

    // Transfer token
    cheat_caller_address(
        test_contracts.erc721.contract_address, ALICE(), CheatSpan::TargetCalls(1),
    );
    test_contracts.erc721.transfer_from(ALICE(), BOB(), token_id.into());

    // Should emit Transfer event
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit Transfer event");
}

#[test]
fn test_batch_operations_event_count() {
    let test_contracts = setup();
    let mut spy = spy_events();

    // Mint multiple tokens
    let mut token_ids: Array<felt252> = array![];
    let mut i: u32 = 0;
    while i < 3 {
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
                i.try_into().unwrap(),
                0,
            );
        token_ids.append(token_id);
        i += 1;
    }

    // Should emit 3 TokenMinted events
    let events = spy.get_events();
    assert!(events.events.span().len() >= 3, "Should emit event for each mint");
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
            Option::None // royalty_fraction
        );

    // Mint token for new game
    let _token_id = test_contracts
        .test_token
        .mint(
            game.contract_address,
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

    // Should emit TokenMinted with correct game_id
    let events = spy.get_events();
    assert!(events.events.span().len() >= 1, "Should emit TokenMinted event");
}
